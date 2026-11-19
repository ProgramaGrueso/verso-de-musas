extends Node
## Verifica el soporte de mando: inspección con R3 y scroll que sigue al foco en diálogos largos.
## Uso: godot --path . res://tests/gamepad_test.tscn -- <dir de capturas>
var out_dir := "/tmp"


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func shot(name: String) -> void:
	await wait(0.4)
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [out_dir, name])


func btn(i: int) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = i
	e.pressed = true
	Input.parse_input_event(e)
	await wait(0.25)


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	out_dir = args[0] if args.size() > 0 else "/tmp"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var G := Eng.new_run("zafiro", {"seed": 42})
	Meta.run = G
	G.map = RunGen.gen_map_game(G)
	Nav.combat(["dockrat", "jelly", "crab"], "normal")
	await wait(2.0)
	var cs: CombatScreen = main.screen
	var fails := 0
	# --- inspección ---
	for e in Eng.living(cs.C):
		e.status["weak"] = 2
		e.status["vuln"] = 1
	cs._render_all()
	await wait(0.4)
	await btn(JOY_BUTTON_RIGHT_STICK)
	if not Main.I._insp_on:
		print("FALLA: R3 no activó la inspección"); fails += 1
	else:
		print("inspección activa, controles: ", Main.I._insp_list.size())
	await shot("g1_inspect")
	var a: int = Main.I._insp_idx
	await btn(JOY_BUTTON_DPAD_RIGHT)
	await btn(JOY_BUTTON_DPAD_DOWN)
	await shot("g2_inspect_moved")
	print("idx ", a, " -> ", Main.I._insp_idx, " tip visible: ", Tip.I.visible)
	if not Tip.I.visible:
		print("FALLA: el tooltip no se ve"); fails += 1
	await btn(JOY_BUTTON_B)
	if Main.I._insp_on or Tip.I.visible:
		print("FALLA: B no cerró la inspección"); fails += 1
	# --- scroll con foco en un diálogo largo ---
	var cards := []
	for i in 40:
		cards.append(Eng.make_card(G, G.deck[i % G.deck.size()].id))
	for i in cards.size():
		cards[i] = cards[i].duplicate()
		cards[i].uid = 9000 + i
	Dlg.pick_cards({"title": "Mejorar", "cards": cards, "n": 1, "cancel": "Cancelar"})
	await wait(0.6)
	var ov: Node = Main.I.overlay_host.get_child(Main.I.overlay_host.get_child_count() - 1)
	var sc: ScrollContainer = null
	var stack := [ov]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is ScrollContainer:
			sc = n
		stack.append_array(n.get_children())
	var last: Control = Dlg._find_cards(ov).back()
	last.grab_focus()
	await wait(0.5)
	print("scroll tras enfocar la última carta: ", sc.scroll_vertical if sc else -1)
	if sc == null or sc.scroll_vertical <= 0:
		print("FALLA: el scroll no sigue al foco"); fails += 1
	await shot("g3_scroll")
	print("RESULTADO: ", "OK" if fails == 0 else "%d fallos" % fails)
	get_tree().quit()
