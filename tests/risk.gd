extends SceneTree
## Pruebas de los puntos de riesgo de la oleada 2 (deshacer, Eco, Pluma de Fénix) contra el motor, sin interfaz.
## Uso: godot --headless --path . --script tests/risk.gd

var fails := 0
var checks := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		print("FALLA: ", msg)


## Firma del estado de combate relevante para comparar antes/después de deshacer.
func sig(C) -> String:
	var en := []
	for e in C.enemies:
		en.append([e.uid, e.id, e.hp, e.block, e.status, e.moveKey, e.turn, e.hist])
	var hand: Array = C.hand.map(func(c): return "%d:%s%s" % [c.uid, c.id, "+" if c.up else ""])
	var draw: Array = C.draw.map(func(c): return "%d:%s" % [c.uid, c.id])
	var disc: Array = C.discard.map(func(c): return "%d:%s" % [c.uid, c.id])
	var exh: Array = C.exhaust.map(func(c): return "%d:%s" % [c.uid, c.id])
	var G = C.G
	return JSON.stringify([en, hand, draw, disc, exh, C.energy, C.pl, C.orbs, C.orbMax, C.osty, C.playedThisTurn,
		C.attacksThisTurn, C.get("echoUsed", false), C.get("dupNext", false), G.hp, G.maxHp, G.gold, G.get("plumaUsed", false), G.deck.size(), C.over, C.prompt])


func new_combat(ch: String, relics: Array = [], enemies: Array = ["mossgolem", "mossgolem"]) -> Dictionary:
	var G := Eng.new_run(ch, {"seed": 4242, "easy": true})
	G.relics.append_array(relics)
	var C := Eng.start_combat(G, enemies)
	C.energy = 10
	return C


func hand_with(C, id: String, up: bool) -> Dictionary:
	var inst := Eng.make_card(C.G, id, up)
	C.hand.append(inst)
	# relleno para que las cartas de descartar o agotar tengan elección
	for i in 3:
		C.hand.append(Eng.make_card(C.G, C.G.deck[i].id))
	return inst


func _init() -> void:
	DB.load_all()
	test_undo_all_cards()
	test_echo()
	test_phoenix()
	print("\nRESULTADO: %d comprobaciones, %d fallan" % [checks, fails])
	quit(1 if fails else 0)


# ---------- Deshacer: toda carta de cada musa ----------
func test_undo_all_cards() -> void:
	var n := 0
	var skipped := 0
	var changed := 0
	for ch in DB.characters.keys():
		for id in DB.cards.keys():
			var b: Dictionary = DB.cards[id]
			if b.cls != ch:
				continue
			for up in [false, true]:
				if up and b.up.is_empty():
					continue
				var C := new_combat(ch)
				for e in C.enemies:
					e.hp = 900
					e.maxHp = 900
				var inst := hand_with(C, id, up)
				var d := Eng.card_def(inst)
				if Eng.is_x(d.cost) == false and d.cost > 10:
					continue
				var before := sig(C)
				var snap := Eng.snapshot(C)
				var tgt = C.enemies[0] if Eng.needs_target(d) else null
				var played := Eng.play_card(C, inst.uid, tgt)
				if not played:
					skipped += 1
					continue
				if C.prompt != null:
					# resuelve el diálogo de descartar o agotar con las primeras cartas elegibles
					var uids := []
					for c in C.hand:
						uids.append(c.uid)
					Eng.resolve_prompt(C, uids)
				if sig(C) != before:
					changed += 1
				if Eng.can_restore(C, snap):
					Eng.restore(C, snap)
					var after := sig(C)
					ok(before == after, "deshacer %s%s (%s) no restaura el estado" % [id, "+" if up else "", ch])
					n += 1
				else:
					# no deshacible por reglas (murió o apareció un enemigo): solo se admite si pasó eso
					var alive := Eng.living(C).size()
					ok(alive != snap.alive or C.enemies.size() != snap.n or C.over != "", "%s no se pudo deshacer sin motivo" % id)
	print("deshacer: %d cartas restauradas (%d cambiaban el estado), %d no jugables" % [n, changed, skipped])
	ok(changed > n * 0.9, "el test de deshacer apenas detecta cambios")


# ---------- Eco ----------
func test_echo() -> void:
	# Cristal de Eco: la primera carta de cada combate se juega dos veces
	var C := new_combat("zafiro", ["cristal"])
	for e in C.enemies:
		e.hp = 900
		e.maxHp = 900
	var strike := Eng.make_card(C.G, "zafiro_strike")
	C.hand.append(strike)
	var hp0: int = C.enemies[0].hp
	Eng.play_card(C, strike.uid, C.enemies[0])
	var dealt: int = hp0 - C.enemies[0].hp
	ok(dealt >= 12 and dealt % 2 == 0, "Cristal: Tajo debería pegar el doble (pegó %d)" % dealt)
	var strike2 := Eng.make_card(C.G, "zafiro_strike")
	C.hand.append(strike2)
	var hp1: int = C.enemies[0].hp
	Eng.play_card(C, strike2.uid, C.enemies[0])
	ok(hp1 - C.enemies[0].hp == dealt / 2, "Cristal: la segunda carta no debe repetirse")

	# Objetivo único que muere en la primera pasada: el eco no debe fallar ni repetir contra un cadáver
	var C2 := new_combat("zafiro", ["cristal"], ["dockrat", "mossgolem"])
	C2.enemies[0].hp = 1
	C2.enemies[1].hp = 900
	C2.enemies[1].maxHp = 900
	var s3 := Eng.make_card(C2.G, "zafiro_strike")
	C2.hand.append(s3)
	var played := Eng.play_card(C2, s3.uid, C2.enemies[0])
	ok(played and C2.over == "", "Cristal: eco con el objetivo muerto en la primera pasada")
	ok(C2.enemies[1].hp < 900, "Cristal: el eco pasa al siguiente enemigo vivo")

	# Coste X, Poderes y diálogos con el eco
	for ch in DB.characters.keys():
		for id in DB.cards.keys():
			var b: Dictionary = DB.cards[id]
			if b.cls != ch:
				continue
			var Ce := new_combat(ch, ["cristal"])
			for e in Ce.enemies:
				e.hp = 900
				e.maxHp = 900
			var inst := hand_with(Ce, id, false)
			var d := Eng.card_def(inst)
			var t = Ce.enemies[0] if Eng.needs_target(d) else null
			var res := Eng.play_card(Ce, inst.uid, t)
			if res and Ce.prompt != null:
				var uids := []
				for c in Ce.hand:
					uids.append(c.uid)
				Eng.resolve_prompt(Ce, uids)
			ok(Ce.prompt == null or not res, "Eco con %s deja un diálogo colgado" % id)
			# la carta jugada termina en un solo sitio
			if res:
				var where := 0
				for pile in [Ce.hand, Ce.draw, Ce.discard, Ce.exhaust]:
					for c in pile:
						if c.uid == inst.uid:
							where += 1
				ok(where <= 1, "Eco duplica la carta %s en las pilas (%d)" % [id, where])
	# Destilado de Eco (siguiente carta doble)
	var C4 := new_combat("zafiro")
	for e in C4.enemies:
		e.hp = 900
		e.maxHp = 900
	C4["dupNext"] = true
	var s4 := Eng.make_card(C4.G, "zafiro_strike")
	C4.hand.append(s4)
	var h4: int = C4.enemies[0].hp
	Eng.play_card(C4, s4.uid, C4.enemies[0])
	ok(h4 - C4.enemies[0].hp == 12, "Destilado de Eco: Tajo doble (pegó %d)" % (h4 - C4.enemies[0].hp))
	ok(not C4.has("dupNext"), "Destilado de Eco: debe consumirse")


# ---------- Pluma de Fénix ----------
func test_phoenix() -> void:
	# Muerte por ataque enemigo
	var C := new_combat("zafiro", ["pluma"], ["mossgolem"])
	C.G.hp = 1
	Eng.deal_to_player(C, 50, C.enemies[0])
	ok(C.over == "" and C.G.hp > 1, "Pluma: no salva de un ataque (hp=%d over=%s)" % [C.G.hp, C.over])
	ok(C.G.get("plumaUsed", false), "Pluma: debe marcarse como usada")
	Eng.deal_to_player(C, 500, C.enemies[0])
	ok(C.over == "lose", "Pluma: la segunda muerte sí debe perder")

	# Muerte por daño propio de una carta (selfdmg)
	for id in DB.cards.keys():
		var b: Dictionary = DB.cards[id]
		if b.fx.get("selfdmg", 0) == 0 or b.cls == "":
			continue
		if not DB.characters.has(b.cls):
			continue
		var C2 := new_combat(b.cls, ["pluma"])
		for e in C2.enemies:
			e.hp = 900
			e.maxHp = 900
		C2.G.hp = 1
		var inst := hand_with(C2, id, false)
		var d := Eng.card_def(inst)
		Eng.play_card(C2, inst.uid, C2.enemies[0] if Eng.needs_target(d) else null)
		ok(C2.over == "" and C2.G.hp > 0, "Pluma: no salva del daño propio de %s (hp=%d over=%s)" % [id, C2.G.hp, C2.over])

	# Muerte por Espinas enemigas al atacar
	var C3 := new_combat("zafiro", ["pluma"], ["thornbeast"])
	C3.G.hp = 1
	C3.enemies[0].status["thorns"] = 20
	var st := Eng.make_card(C3.G, "zafiro_strike")
	C3.hand.append(st)
	Eng.play_card(C3, st.uid, C3.enemies[0])
	ok(C3.over == "" and C3.G.hp > 0, "Pluma: no salva de las Espinas (hp=%d over=%s)" % [C3.G.hp, C3.over])

	# Sin la Pluma, esas mismas muertes pierden
	var C5 := new_combat("zafiro", [], ["thornbeast"])
	C5.G.hp = 1
	C5.enemies[0].status["thorns"] = 20
	var st5 := Eng.make_card(C5.G, "zafiro_strike")
	C5.hand.append(st5)
	Eng.play_card(C5, st5.uid, C5.enemies[0])
	ok(C5.over == "lose", "Sin Pluma: las Espinas deberían matar (over=%s)" % C5.over)

	# Deshacer devuelve la Pluma si la carta la gastó
	var C6 := new_combat("zafiro", ["pluma"], ["thornbeast"])
	C6.G.hp = 1
	C6.enemies[0].status["thorns"] = 20
	var st6 := Eng.make_card(C6.G, "zafiro_strike")
	C6.hand.append(st6)
	var snap := Eng.snapshot(C6)
	Eng.play_card(C6, st6.uid, C6.enemies[0])
	ok(C6.G.get("plumaUsed", false), "Pluma: la prueba debía gastarla")
	if Eng.can_restore(C6, snap):
		Eng.restore(C6, snap)
		ok(not C6.G.get("plumaUsed", false) and C6.G.hp == 1, "Deshacer debe devolver la Pluma y los PV (hp=%d)" % C6.G.hp)
