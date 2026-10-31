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
