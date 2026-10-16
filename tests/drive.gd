extends Node
## Conduce el juego real con capturas de pantalla. Uso: godot --path . res://tests/drive.tscn -- <escenario> <dir>
## Escenarios: menu | run | combat

var out_dir := "/tmp"
var main: Control


func shot(name: String) -> void:
	for i in 6:
		await get_tree().process_frame
	await get_tree().create_timer(0.35).timeout
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])
	print("shot ", name)


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var scenario: String = args[0] if args.size() > 0 else "menu"
	out_dir = args[1] if args.size() > 1 else "/tmp"
	if scenario == "menusave":   # menú con partida guardada
		var G0 := Eng.new_run("zafiro", {"seed": 1})
		G0.map = RunGen.gen_map(G0)
		Meta.save_run(G0)
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	await shot("01_title")
	if scenario == "menu" or scenario == "menusave":
		if scenario == "menusave":
			Meta.clear_save()
		get_tree().quit()
		return
	if scenario == "favor":
		var Gf := Eng.new_run("zafiro", {"seed": 42})
		Meta.run = Gf
		Gf.map = RunGen.gen_map(Gf)
		for a in [1, 3]:
			Gf.act = a
			Nav.favor()
			await wait(0.8)
			await shot("favor_%d" % a)
		get_tree().quit()
		return
	if scenario == "keys":
		await keys_test()
		return
	if scenario == "drag":
		await drag_test(args)
		return
	if scenario == "screens":
		await screens()
		return
	Nav.select()
	await wait(0.4)
	await shot("02_select")
	var ch: String = args[2] if args.size() > 2 else "zafiro"
	TitleScreen.last_char = ch
	var G := Eng.new_run(ch, {"seed": 42})
	Meta.run = G
	G.map = RunGen.gen_map(G)
	Nav.map(true)
	await wait(1.2)
	await shot("03_map")
	if scenario == "run":
		get_tree().quit()
		return
	var ids: Array = ["dockrat", "jelly", "crab"] if args.size() <= 3 else args[3].split(",")
	Nav.combat(ids, "normal")
	await wait(2.2)
	await shot("04_combat")
	var cs: CombatScreen = main.screen
	# juega un par de cartas
	for i in 2:
		var inst = null
		for c in cs.C.hand:
			if Eng.can_play(cs.C, c).ok:
				inst = c
				break
		if inst == null:
			break
		var d := Eng.card_def(inst)
		var tgt = Eng.living(cs.C)[0] if Eng.needs_target(d) else null
		cs._play_now(inst, tgt)
		await wait(0.25)
		await shot("05_play%d" % i)
		await wait(1.2)
	await shot("06_after")
	cs._end_turn()
	await wait(1.0)
	await shot("07_enemy")
	await wait(3.0)
	await shot("08_turn2")
	get_tree().quit()


func screens() -> void:
	var G := Eng.new_run("claudia", {"seed": 7})
	Meta.run = G
	TitleScreen.last_char = "claudia"
	G.map = RunGen.gen_map(G)
	G.gold = 400
	G.potions[0] = "fuego"
	G.potions[1] = "escudo"
	Eng.add_relic(G, "ancla")
	Eng.add_relic(G, "vajra")
	G.act = 2
	var rew := Eng.combat_reward(G, "elite")
	rew.bossRelics = Eng.boss_relics(G)
	Nav.reward(rew, "elite")
	await wait(0.6)
	await shot("10_reward")
	Nav.shop()
	await wait(0.6)
	await shot("11_shop")
	Nav.rest()
	await wait(0.6)
	await shot("12_rest")
	for evid in ["altar", "forjador"]:
		G.seenEvents = []
		for e in DB.events:
			if e.id != evid:
				G.seenEvents.append(e.id)
		Nav.event()
		await wait(0.6)
		await shot("13_event_" + evid)
	Nav.gallery()
	await wait(0.6)
	await shot("14_gallery")
	Dlg.help()
	await wait(0.4)
	await shot("15_help")
	Main.I.overlay_host.get_child(0).queue_free()
	Dlg.options()
	await wait(0.4)
	await shot("16_options")
	Main.I.overlay_host.get_child(0).queue_free()
	await wait(0.2)
	Nav.combat(["rootmother"], "boss")
	await wait(2.5)
	await shot("17_boss_claudia")
	var cs: CombatScreen = Main.I.screen
	cs.C.pl.status["strength"] = 3
	cs.C.pl.status["weak"] = 2
	cs.C.pl.block = 12
	cs._render_all()
	await wait(0.5)
	await shot("18_boss_status")
	var e2 := EndingScreen.new()
	e2.char = "irene"
	Main.I.set_screen(e2, "ending")
	await wait(4.0)
	await shot("19_ending")
	G.hp = 0
	Nav.game_over()
	await wait(0.6)
	await shot("20_gameover")
	G.hp = 50
	Main.I.set_screen(EndScreen.create_victory(G, true), "end")
	await wait(0.6)
	await shot("21_victory")
	get_tree().quit()


func mouse_to(pos: Vector2) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = pos
	ev.global_position = pos
	get_viewport().warp_mouse(pos)
	Input.parse_input_event(ev)


func mouse_btn(pos: Vector2, pressed: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = pos
	ev.global_position = pos
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = pressed
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	Input.parse_input_event(ev)


func drag_test(args: Array) -> void:
	var ch: String = args[2] if args.size() > 2 else "zafiro"
	var G := Eng.new_run(ch, {"seed": 42})
	Meta.run = G
	G.map = RunGen.gen_map(G)
	Nav.combat(["dockrat", "jelly", "crab"], "normal")
	await wait(2.0)
	var cs: CombatScreen = main.screen
	# busca una carta de ataque que necesite objetivo
	var view: CardView = null
	for uid in cs.card_views.keys():
		var v: CardView = cs.card_views[uid]
		if Eng.needs_target(Eng.card_def(v.inst)):
			view = v
			break
	var c0: Vector2 = view.position + view.size / 2.0
	mouse_to(c0)
	await wait(0.3)
	await shot("30_hover")
	mouse_btn(c0, true)
	await wait(0.1)
	var e0 = Eng.living(cs.C)[1]
	var target_pos: Vector2 = cs._enemy_view(e0).body_center()
	for i in 12:
		mouse_to(c0.lerp(target_pos, (i + 1) / 12.0))
		await wait(0.03)
	await shot("31_dragging")
	var hp_before: int = e0.hp
	mouse_btn(target_pos, false)
	await wait(0.3)
	await shot("32_dropped")
	await wait(1.0)
	print("enemigo ", e0.id, " hp ", hp_before, " -> ", e0.hp)
	# click-click: selecciona y juega
	var view2: CardView = null
	for uid in cs.card_views.keys():
		var v2: CardView = cs.card_views[uid]
		if is_instance_valid(v2) and v2.visible and Eng.can_play(cs.C, v2.inst).ok and not Eng.needs_target(Eng.card_def(v2.inst)):
			view2 = v2
			break
	if view2 != null:
		var p2: Vector2 = view2.position + view2.size / 2.0
		mouse_to(p2)
		mouse_btn(p2, true)
		mouse_btn(p2, false)
		await wait(0.3)
		await shot("33_selected")
		mouse_btn(p2, true)
		mouse_btn(p2, false)
		await wait(0.6)
		await shot("34_played")
	get_tree().quit()


func key(k: int) -> void:
	var ev := InputEventKey.new()
	ev.keycode = k
	ev.pressed = true
	Input.parse_input_event(ev)
	await wait(0.15)
	var up := InputEventKey.new()
	up.keycode = k
	up.pressed = false
	Input.parse_input_event(up)
	await wait(0.1)


func keys_test() -> void:
	var G := Eng.new_run("lia", {"seed": 5})
	Meta.run = G
	G.map = RunGen.gen_map(G)
	G.potions[0] = "fuego"
	Nav.combat(["dockrat", "jelly", "crab"], "normal")
	await wait(2.0)
	var cs: CombatScreen = main.screen
	var hp0 := []
	for e in cs.C.enemies:
		hp0.append(e.hp)
	await key(KEY_1)          # elige la carta 1
	print("sel_uid tras 1: ", cs.sel_uid, " mano[0]=", cs.C.hand[0].uid)
	await key(KEY_RIGHT)
	await key(KEY_LEFT)
	await key(KEY_ENTER)      # juega o entra en modo objetivo
	await wait(0.3)
	print("pending: ", cs.pending, " busy=", cs.busy, " energia=", cs.C.energy, " mano=", cs.C.hand.size())
	await key(KEY_DOWN)       # cambia de objetivo
	await key(KEY_ENTER)      # confirma
	await wait(1.0)
	var hp1 := []
	for e in cs.C.enemies:
		hp1.append(e.hp)
	print("hp antes ", hp0, " despues ", hp1, " energia ", cs.C.energy)
	# poción por el botón superior (objetivo)
	cs._on_potion(0)
	await wait(0.2)
	print("pending potion: ", cs.pending)
	await key(KEY_ENTER)
	await wait(0.2)
	await shot("40_keys")
	await key(KEY_E)
	await wait(2.0)
	print("turno ", cs.C.turn, " hand ", cs.C.hand.size())
	get_tree().quit()
