extends Node
## Capturas a ojo de las pantallas y diálogos principales (sin medir nada: para revisar el aspecto).
## Uso: godot --path . res://tests/ui_shot.tscn -- <dir_salida> [ancho alto]
##   Hace una captura por pantalla con el fundido terminado. Las comprobaciones automáticas están en
##   `tests/ui_layout_test.gd`.

var out := "/tmp/ui_shot"
var size := Vector2i(1280, 720)

var main: Control


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out = args[0]
	if args.size() > 2:
		size = Vector2i(int(args[1]), int(args[2]))
	DirAccess.make_dir_recursive_absolute(out)
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	Meta.settings["calm"] = true
	CombatScreen.test_mode = true
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	get_window().size = size
	await wait(0.3)
	var G := Eng.new_run("zafiro", {"seed": 7})
	Meta.run = G
	G.map = RunGen.gen_map_game(G)
	for id in DB.relics.keys():
		if G.relics.size() >= 4:
			break
		if DB.relics[id].rarity in ["common", "uncommon"]:
			G.relics.append(id)
	G.potions[0] = DB.potions.keys()[0]
	await shot("title", func(): Nav.title())
	await shot("select", func(): Nav.select())
	Meta.run = G
	await shot("map", func(): Nav.map())
	await shot("favor", func(): Nav.favor())
	await shot("combat", func(): Nav.combat(["dockrat", "jelly", "crab"], "normal"))
	await wait(2.0)   # que se vea la mano repartida
	await shot("combat_mano", func(): pass)
	await shot("reward", func(): Nav.reward(Eng.combat_reward(G, "normal"), "normal"))
	await shot("shop", func(): Nav.shop())
	await shot("event", func(): Nav.event())
	await shot("rest", func(): Nav.rest())
	await shot("history", func(): Nav.history())
	await shot("daily", func(): Nav.daily())
	await shot("end_defeat", func(): Nav.game_over())
	await dshot("dlg_pause", func(): Dlg.pause_menu())
	await dshot("dlg_help", func(): Dlg.help())
	await dshot("dlg_confirm", func(): Dlg.confirm("¿Seguro que quieres rendirte?\n[font_size=18]La partida terminará como una derrota.[/font_size]", "Rendirme", "Seguir luchando"))
	get_tree().quit()


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(tag: String, build: Callable) -> void:
	build.call()
	await wait(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, tag])
	print("  ", tag)


func dshot(tag: String, build: Callable) -> void:
	build.call()
	await wait(1.0)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out, tag])
	print("  ", tag)
	var ov = main.overlay_host.get_child(main.overlay_host.get_child_count() - 1) if main.overlay_host.get_child_count() > 0 else null
	if ov is Dlg.Overlay:
		ov.close(ov.cancel_result)
	await wait(0.3)
