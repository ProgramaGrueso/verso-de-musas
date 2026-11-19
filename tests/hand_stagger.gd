extends Node
## Comprueba que la mano se crea por tandas (sin tirones) y que Tormenta de Acero deja la mano coherente.
## Uso: godot --path . res://tests/hand_stagger.tscn

var fallos := 0


func _ready() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var G = Eng.new_run("lia", {"seed": 7, "nm": 0, "easy": false})
	Meta.run = G
	G.maxHp = 999
	G.hp = 999
	Nav.combat(["eel"], "normal")
	await get_tree().create_timer(1.0).timeout
	var cs: CombatScreen = Main.I.screen
	if cs.C.is_empty():
		print("sin combate: FALLO")
		get_tree().quit(1)
		return
	for e in cs.C.enemies:
		e.maxHp = 9999
		e.hp = 9999
	cs.C.maxEnergy = 99
	cs.C.energy = 99

	# 1) 10 Cuchillas de golpe: la primera pasada crea como mucho NEW_PER_FRAME
	cs.C.hand.clear()
	cs._render_all()
	await get_tree().create_timer(0.3).timeout
	Eng.add_cards(cs.C, "lia_shiv", 10, "hand")
	cs._render_all()
	var primera: int = cs.card_views.size()
	print("primera tanda: %d vistas (máx %d) %s" % [primera, CombatScreen.NEW_PER_FRAME,
		"ok" if primera <= CombatScreen.NEW_PER_FRAME else "FALLO"])
	if primera > CombatScreen.NEW_PER_FRAME:
		fallos += 1
	await get_tree().create_timer(1.5).timeout
	var faltan := 0
	var en_fade := 0
	for inst in cs.C.hand:
		if not cs.card_views.has(inst.uid):
			faltan += 1
	for uid in cs.card_views:
		var v: CardView = cs.card_views[uid]
		if not is_instance_valid(v) or v.modulate.a < 0.99:
			en_fade += 1
	print("tras la cascada: mano=%d vistas=%d sin_vista=%d en_fade=%d %s" % [
		cs.C.hand.size(), cs.card_views.size(), faltan, en_fade,
		"ok" if faltan == 0 and en_fade == 0 else "FALLO"])
	if faltan or en_fade:
		fallos += 1

	# 2) Tormenta de Acero con la mano llena
	cs.C.hand.clear()
	Eng.add_cards(cs.C, "lia_shiv", 9, "hand")
	Eng.add_cards(cs.C, "lia_storm", 1, "hand")
	cs._render_all()
	await get_tree().create_timer(0.5).timeout
	await cs._play_now(cs.C.hand[9], null)
	await get_tree().create_timer(1.5).timeout
	for inst in cs.C.hand:
		if not cs.card_views.has(inst.uid):
			faltan += 1
	print("tormenta: mano=%d vistas=%d sin_vista=%d %s" % [
		cs.C.hand.size(), cs.card_views.size(), faltan, "ok" if faltan == 0 else "FALLO"])
	if faltan:
		fallos += 1

	print("RESULTADO: %s" % ("0 fallan" if fallos == 0 else "%d fallan" % fallos))
	get_tree().quit(0 if fallos == 0 else 1)
