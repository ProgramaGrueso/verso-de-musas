extends SceneTree
## Fase 4 · Jefes con fases: fuerza la fase 2 de cada jefe (DB.extra) bajándole la vida por debajo
## del 50 % y comprueba aviso (fx "bossPhase"), Fuerza ganada y que el intent pasa a la secuencia nueva.
## Uso: godot --headless --path . --script tests/boss_phase_test.gd

const BOSSES := ["crabking", "drowncaptain", "rootmother", "mycelking", "queen", "waxcolossus"]


func _init() -> void:
	DB.extra = true
	DB.load_all()
	var fails := 0
	for id in BOSSES:
		var log_ := []
		var G := Eng.new_run("zafiro", {"seed": 12345, "nm": 0})
		var C := Eng.start_combat(G, [id], {"tier": "boss", "fx": func(t, d): log_.append([t, d])})
		var e: Dictionary = C.enemies[0]
		var P: Dictionary = e.def.get("phase2", {})
		if P.is_empty():
			print("FALLA: %s no tiene phase2" % id)
			fails += 1
			continue
		# a un golpe de cruzar el 50 %: no debe cambiar aún
		e.hp = e.maxHp / 2 + 3
		e.block = 0
		Eng.deal_to_enemy(C, e, 1)
		if int(e.get("phase", 1)) != 1:
			print("FALLA: %s entra en fase 2 antes del umbral" % id)
			fails += 1
		var str0 := Eng.get_s(e, "strength")
		Eng.deal_to_enemy(C, e, 5)
		var msgs := log_.filter(func(x): return x[0] == "bossPhase")
		var ok: bool = int(e.get("phase", 1)) == 2 and msgs.size() == 1 \
			and Eng.get_s(e, "strength") == str0 + int(P.get("str", 0)) \
			and e.moveKey == P.seq[0]
		# un segundo golpe no repite la transición
		Eng.deal_to_enemy(C, e, 1)
		ok = ok and log_.filter(func(x): return x[0] == "bossPhase").size() == 1
		print("%s %-13s fase=%d intent=%s fuerza=%d msg=«%s»" % ["ok  " if ok else "FALLA", id, int(e.get("phase", 1)), e.moveKey, Eng.get_s(e, "strength"), msgs[0][1].msg if msgs.size() else ""])
		if not ok:
			fails += 1
	# sin la oleada 2 el jefe base no tiene fases (paridad con las trazas)
	DB.loaded = false
	DB.extra = false
	DB.load_all()
	if DB.enemies.crabking.has("phase2"):
		print("FALLA: phase2 visible con DB.extra = false")
		fails += 1
	print("\n%d fallan" % fails)
	quit(1 if fails else 0)
