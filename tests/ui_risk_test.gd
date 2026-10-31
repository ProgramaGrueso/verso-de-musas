extends Node
## Hoguera con el Reloj Detenido sin cartas mejorables, y Medallón del Boticario en la barra superior.
## XDG_DATA_HOME=/tmp/x godot --path . res://tests/ui_risk_test.tscn

func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _find_buttons(n: Node, out: Array) -> void:
	if n is Button:
		out.append(n)
	for c in n.get_children():
		_find_buttons(c, out)


func _ready() -> void:
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var fails := 0
	var G := Eng.new_run("zafiro", {"seed": 5})
	G.map = RunGen.gen_map_game(G)
	for c in G.deck:
		c.up = true
	Eng.add_relic(G, "reloj_roto")
	Meta.run = G
	Nav.rest()
	await wait(0.8)
	var bs := []
	_find_buttons(Main.I, bs)
	var skip := bs.filter(func(b): return b.text.contains("Seguir el camino"))
	print("Reloj sin mejoras -> botón 'Seguir el camino': ", skip.size())
	if skip.size() != 1:
		fails += 1
	# con cartas mejorables NO debe aparecer
	G.deck[0].up = false
	Nav.rest()
	await wait(0.8)
	bs.clear()
	_find_buttons(Main.I, bs)
	var skip2 := bs.filter(func(b): return b.text.contains("Seguir el camino"))
	print("Reloj con mejoras posibles -> botón de seguir: ", skip2.size(), " (esperado 0)")
	if skip2.size() != 0:
		fails += 1
	# Medallón
	Eng.add_relic(G, "medallon")
	print("huecos de poción con Medallón: ", G.potions.size())
	if G.potions.size() != 4:
		fails += 1
	Main.I.update_top()
	await wait(0.3)
	var pot_btns := 0
	for c in Main.I._tb_potions.get_children():
		pot_btns += 1
	print("botones de poción en la barra: ", pot_btns)
	if pot_btns != 4:
		fails += 1
	print("OK" if fails == 0 else "FALLA")
	get_tree().quit()
