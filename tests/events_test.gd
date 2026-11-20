extends SceneTree
## Ejecuta cada opción de cada evento con musas y estados distintos, eligiendo en los diálogos y también cancelando.
## Uso: godot --headless --path . --script tests/events_test.gd

var fails := 0
var checks := 0
var runs := 0


class Ctx extends RefCounted:
	var mode := "first"   # first | cancel | last
	var calls := 0
	var G

	func pick_card(_title: String, filter: Callable, n: int, _up: bool = false) -> Array:
		calls += 1
		var cards: Array = G.deck.filter(filter)
		if mode == "cancel" or cards.is_empty():
			return []
		return [cards[0] if mode == "first" else cards[cards.size() - 1]].slice(0, n)

	func choose_new(_title: String, ids: Array) -> Array:
		calls += 1
		if mode == "cancel" or ids.is_empty():
			return []
		var id: String = ids[0] if mode == "first" else ids[ids.size() - 1]
		return [Eng.make_card(G, id)]


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLA: ", msg)


func state_ok(G, ctxt: String) -> void:
	ok(G.hp <= G.maxHp, "%s: PV por encima del máximo (%d/%d)" % [ctxt, G.hp, G.maxHp])
	ok(G.gold >= 0, "%s: oro negativo (%d)" % [ctxt, G.gold])
	for c in G.deck:
		ok(DB.cards.has(c.id), "%s: carta desconocida %s en el mazo" % [ctxt, c.id])
	for r in G.relics:
		ok(DB.relics.has(r), "%s: reliquia desconocida %s" % [ctxt, r])
	for p in G.potions:
		ok(p == null or DB.potions.has(p), "%s: poción desconocida %s" % [ctxt, p])
	var uids := {}
	for c in G.deck:
		ok(not uids.has(c.uid), "%s: uid de carta repetido (%d)" % [ctxt, c.uid])
		uids[c.uid] = true


func _init() -> void:
	DB.load_all()
	for ev in DB.events:
		var id: String = ev.id
		for ch in DB.characters.keys():
			for mode in ["first", "cancel", "last"]:
				for variant in ["normal", "pobre", "herido", "sin_mejoras"]:
					var G := Eng.new_run(ch, {"seed": 777 + runs})
					G.act = 1 + runs % 3
					match variant:
						"pobre":
							G.gold = 0
						"herido":
							G.hp = 3
						"sin_mejoras":
							for c in G.deck:
								c.up = true
							G.potions = [null, null, null]
					var opts: Array = EventsLogic.options(G, id)
					ok(opts.size() >= 1, "%s: sin opciones" % id)
					for i in opts.size():
						var G2 := Eng.new_run(ch, {"seed": 777 + runs})
						G2.act = G.act
						G2.gold = G.gold
						G2.hp = G.hp
						if variant == "sin_mejoras":
							for c in G2.deck:
								c.up = true
							G2.potions = [null, null, null]
						var o: Dictionary = EventsLogic.options(G2, id)[i]
						var label := "%s/%s/%s/%s/op%d" % [id, ch, mode, variant, i]
						runs += 1
						if not o.get("ok", true):
							continue
						if o.has("fight"):
							ok(o.has("fight_ids") or o.fight in ["normal", "elite", "boss"], "%s: combate mal definido" % label)
							continue
						var ctx := Ctx.new()
						ctx.mode = mode
						ctx.G = G2
						var res = await o.run.call(ctx)
						ok(res is String and res != "", "%s: sin texto de resultado (%s)" % [label, str(res)])
						state_ok(G2, label)
	_exclusives()
	_once_events()
	_elite_mechanics()
	print("\nRESULTADO: %d eventos x musas x modos, %d comprobaciones, %d fallan" % [runs, checks, fails])
	quit(1 if fails else 0)


## Los eventos exclusivos de musa dejan G.perm y el combate lo aplica sin errores.
func _exclusives() -> void:
	for ch in DB.characters.keys():
		var G := Eng.new_run(ch, {"seed": 99})
		G["perm"] = {"strength": 1, "dexterity": 1, "ostyMax": 5, "ostyPow": 1}
		var C := Eng.start_combat(G, ["dockrat"])
		ok(C.over == "", "%s: el combate con G.perm falla" % ch)
		ok(C.pl.status.get("strength", 0) >= 1, "%s: G.perm no aplica Fuerza" % ch)


## Los eventos raros no vuelven a entrar en el pool ni cuando seenEvents se reinicia.
func _once_events() -> void:
	var rare: Array = DB.events.filter(func(e): return e.get("once", false))
	ok(rare.size() >= 3, "Fase 4B: faltan eventos raros")
	for act in [1, 2, 3]:
		ok(rare.any(func(e): return int(e.get("act", 0)) == act), "Fase 4B: no hay evento raro en el acto %d" % act)
	for ev in rare:
		var id: String = ev.id
		ok(float(ev.get("weight", 1.0)) < 1.0, "%s: el evento raro no tiene peso bajo" % id)
		var G := Eng.new_run("zafiro", {"seed": 4040})
		G.act = int(ev.act)
		ok(G.onceEvents.is_empty(), "%s: onceEvents no empieza vacío" % id)
		ok(RunGen.event_ok(G, ev), "%s: el evento raro no es elegible en su acto" % id)
		var elig: Array = DB.events.filter(func(e): return RunGen.event_ok(G, e))
		G.seenEvents = elig.filter(func(e): return e.id != id).map(func(e): return e.id)
		var picked := RunGen.pick_event(G)
		ok(picked.id == id, "%s: no se pudo forzar el sorteo del evento raro" % id)
		ok(id in G.onceEvents, "%s: el sorteo no registra el evento como usado" % id)
		ok(not RunGen.event_ok(G, ev), "%s: event_ok admite repetir un evento único" % id)
		G.seenEvents = []
		for i in 40:
			ok(RunGen.pick_event(G).id != id, "%s: reaparece al reiniciar seenEvents (%d)" % [id, i])


## Mecánicas de los tres élites nuevas: ruptura, reducción por Brotes y límite por golpe.
func _elite_mechanics() -> void:
	for spec in [[1, "spectralbosun"], [2, "rootwarden"], [3, "royalbeetle"]]:
		var act: int = spec[0]
		var id: String = spec[1]
		ok(DB.encounters[act].elite.any(func(ids): return id in ids), "%s: falta en el pool de élites" % id)
	# Contramaestre: dos golpes acumulan el umbral y anulan el cañonazo ya anunciado.
	var G1 := Eng.new_run("zafiro", {"seed": 51})
	var C1 := Eng.start_combat(G1, ["spectralbosun"], {"tier": "elite"})
	var bosun: Dictionary = C1.enemies[0]
	bosun.block = 0
	bosun.intent = bosun.def.moves.canon.duplicate()
	bosun["brkDamage"] = 0
	var brk: int = int(bosun.intent.get("brk", 0))
	ok(brk > 1, "Contramaestre: el cañonazo no lleva umbral de ruptura")
	Eng.deal_to_enemy(C1, bosun, brk - 2)
	ok(bosun.intent.get("name", "") != "¡Aturdido!", "Contramaestre: se rompe antes del umbral")
	Eng.deal_to_enemy(C1, bosun, 1)
	ok(bosun.intent.get("name", "") != "¡Aturdido!", "Contramaestre: se rompe con un golpe de menos")
	Eng.deal_to_enemy(C1, bosun, 1)
	ok(bosun.intent.get("name", "") == "¡Aturdido!", "Contramaestre: el umbral no aturde")
	var hp1: int = G1.hp
	Eng.run_enemy_turn(C1, bosun)
	ok(G1.hp == hp1, "Contramaestre: el turno aturdido sigue atacando")
	# Guardiana: el estado sigue a los Brotes vivos y la reducción desaparece con ellos.
	var G2 := Eng.new_run("zafiro", {"seed": 52})
	var C2 := Eng.start_combat(G2, ["rootwarden", "sprout", "sprout"], {"tier": "elite"})
	var root: Dictionary = C2.enemies[0]
	root.block = 0
	ok(Eng.get_s(root, "rootShield") == 2, "Guardiana: el estado no cuenta los dos Brotes")
	var hp2: int = root.hp
	ok(Eng.deal_to_enemy(C2, root, 20) == 10 and root.hp == hp2 - 10, "Guardiana: no reduce el golpe a la mitad")
	Eng.deal_to_enemy(C2, C2.enemies[1], 999)
	ok(Eng.get_s(root, "rootShield") == 1, "Guardiana: el estado no baja al perder un Brote")
	Eng.deal_to_enemy(C2, C2.enemies[2], 999)
	ok(Eng.get_s(root, "rootShield") == 0, "Guardiana: el escudo persiste sin Brotes")
	root.block = 0
	hp2 = root.hp
	ok(Eng.deal_to_enemy(C2, root, 20) == 20 and root.hp == hp2 - 20, "Guardiana: sin Brotes no recibe daño completo")
	# Escarabajo: cada golpe pierde como máximo shellCap PV (dato de make_content_w2.py); los pequeños no se reducen.
	var G3 := Eng.new_run("zafiro", {"seed": 53})
	var C3 := Eng.start_combat(G3, ["royalbeetle"], {"tier": "elite"})
	var beetle: Dictionary = C3.enemies[0]
	var cap := int(beetle.def.get("shellCap", 0))
	beetle.block = 0
	ok(cap >= 8 and Eng.get_s(beetle, "carapace") == cap, "Escarabajo: Coraza no está visible")
	ok(Eng.deal_to_enemy(C3, beetle, 25) == cap, "Escarabajo: un golpe grande supera el límite")
	beetle.block = 0
	ok(Eng.deal_to_enemy(C3, beetle, 6) == 6, "Escarabajo: Coraza altera los golpes pequeños")
