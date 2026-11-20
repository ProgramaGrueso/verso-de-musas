extends Node
## Capturas de la Fase 2.3 (ficha de reliquia, mazo con filtros, mazo sobre diálogo, hoguera).
## Uso (necesita ventana): godot --path . res://tests/inspect_shot.tscn -- /tmp/insp

var out := "/tmp/insp"


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(nm: String) -> void:
	# frame_post_draw a veces no llega tras cambiar de pantalla en ventana (Wayland); bastan unos fotogramas
	for i in 3:
		await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png(out.path_join(nm + ".png"))
		print("captura ", out.path_join(nm + ".png"))


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	DirAccess.make_dir_recursive_absolute(out)
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var G := Eng.new_run("selene", {"seed": 7})
	G.map = RunGen.gen_map_game(G)
	for id in ["ancla", "vajra"]:
		if DB.relics.has(id):
			Eng.add_relic(G, id)
	var n := 0
	for id in DB.cards.keys():
		if n >= 16:
			break
		if DB.cards[id].get("char", "") in ["", "selene"] and DB.cards[id].type in ["attack", "skill", "power"]:
			G.deck.append({"id": id, "uid": 5000 + n, "up": n % 3 == 0 and Eng.can_upgrade({"id": id, "up": false})})
			n += 1
	Meta.run = G
	G.hp = 31
	Nav.map()
	await wait(0.8)
	Dlg.relic_info(G.relics[0])
	await wait(0.5)
	await shot("01_ficha_reliquia")
	Main.I.overlay_host.get_child(0).close(null)
	await wait(0.3)
	Main.I.open_deck_dialog()
	await wait(0.5)
	await shot("02_mazo_filtros")
	var ov := Main.I.overlay_host.get_child(0)
	var chip = ov.find_child("Chip_t_attack", true, false)
	if chip != null:
		chip.grab_focus()
		chip.emit_signal("pressed")
		await wait(0.4)
		await shot("03_mazo_ataques")
	ov.close(null)
	await wait(0.3)
	Nav.rest()
	await wait(0.8)
	await shot("04_hoguera")
	Dlg.pick_cards({"title": "Elige una carta para mejorar", "cards": G.deck.filter(func(c): return Eng.can_upgrade(c)), "n": 1, "cancel": "Cancelar", "upgradePreview": true})
	await wait(0.4)
	Main.I.open_deck_dialog()
	await wait(0.5)
	await shot("05_mazo_sobre_dialogo")
	for i in range(Main.I.overlay_host.get_child_count() - 1, -1, -1):
		Main.I.overlay_host.get_child(i).close(null)
	await wait(0.4)
	var up: Array = G.deck.filter(func(c): return Eng.can_upgrade(c))
	if not up.is_empty():
		Dlg.upgrade_compare(up[0])   # flecha «➜» grande (fuente de reserva DejaVu)
		await wait(0.5)
		await shot("06_comparar_mejora")
	for i in range(Main.I.overlay_host.get_child_count() - 1, -1, -1):
		Main.I.overlay_host.get_child(i).close(null)
	await wait(0.4)
	# Opciones con el texto al 130 % (en memoria: no se guardan los ajustes) y Controles
	UIK.text_scale = 1.3
	Meta.settings.text_scale = 1.3
	Dlg.options()
	await wait(0.5)
	await shot("07_opciones_130")
	Dlg.controls()
	await wait(0.5)
	await shot("08_controles_130")
	UIK.text_scale = 1.0
	Meta.settings.text_scale = 1.0
	get_tree().quit()
