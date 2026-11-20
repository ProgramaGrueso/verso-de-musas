extends Node
## Auditoría de mando: en cada pantalla comprueba que haya foco inicial (y el que toca) y que todos los
## controles enfocables visibles se alcancen con el D-Pad (búsqueda en anchura con find_valid_focus_neighbor).
## Además, con pulsaciones de mando de verdad (`Input.parse_input_event`):
##   · selección: avatar ↓ Modo fácil → Semilla → Comenzar (también con Pesadilla, que apaga Modo fácil),
##     ◀/▶ de Pesadilla no pierden el foco y el foco vuelve a «Semilla» al cerrar su diálogo;
##   · B atrás: selección → portada, logros (3 pestañas) → portada, compendio → galería (o mapa en partida).
## Corre con un perfil temporal (no toca el meta.json del jugador) y sale con código 1 si algo falla.
## Uso: godot --headless --path . res://tests/focus_reach.tscn

const Iso := preload("res://tests/isolated_run.gd")

var fails := 0
var oks := 0


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func expect(cond: bool, label: String) -> void:
	if cond:
		oks += 1
	else:
		fails += 1
		print("FALLA ", label)


func tap(i: int) -> void:
	for p in [true, false]:
		var e := InputEventJoypadButton.new()
		e.button_index = i
		e.pressed = p
		e.device = 0
		Input.parse_input_event(e)
		await wait(0.08)


func focus() -> Control:
	var f := get_viewport().gui_get_focus_owner()
	return f if (f != null and is_instance_valid(f)) else null


func ftext(f: Control) -> String:
	if f == null:
		return "(nadie)"
	return "%s «%s»" % [f.get_class(), f.get("text")] if f is BaseButton else "%s %s" % [f.get_class(), f.name]


func focusables(n: Node, out: Array) -> void:
	if n is Control:
		var c := n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and c.size.x > 2 and not c.is_queued_for_deletion():
			if not (c is BaseButton and (c as BaseButton).disabled):
				out.append(c)
	for ch in n.get_children():
		focusables(ch, out)


func check(name: String, root: Node) -> void:
	var all := []
	focusables(root, all)
	var start := focus()
	if all.is_empty():
		print("[%s] sin controles enfocables (puede ser normal)" % name)
		return
	if start == null:
		expect(false, "[%s] sin foco inicial (%d enfocables)" % [name, all.size()])
		return
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var c: Control = q.pop_front()
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var nb := c.find_valid_focus_neighbor(side)
			if nb != null and not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	var miss := all.filter(func(c): return not seen.has(c))
	expect(miss.is_empty(), "[%s] %d de %d no alcanzables con el D-Pad: %s" % [name, miss.size(), all.size(),
		", ".join(miss.slice(0, 4).map(func(c): return "%s @%s" % [ftext(c), c.get_global_rect()]))])
	if miss.is_empty():
		print("[%s] OK (%d enfocables, todos alcanzables)" % [name, all.size()])


func first_focus(name: String, want: String) -> void:
	var f := focus()
	expect(f != null and str(f.get("text")).begins_with(want), "[%s] foco inicial en «%s» (está en %s)" % [name, want, ftext(f)])


func b_goes_to(name: String, screen_name: String) -> void:
	await tap(JOY_BUTTON_B)
	await wait(0.5)
	expect(Main.I.current == screen_name, "[%s] B vuelve a «%s» (está en «%s»)" % [name, screen_name, Main.I.current])


func _ready() -> void:
	if Iso.needed():
		await Iso.relaunch(self, "/tmp/vdm_focus_reach")
		return
	Iso.watch_parent(self)
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.6)
	# ---------------- portada
	check("title", main)
	first_focus("title", "Nueva partida")
	await tap(JOY_BUTTON_B)   # B en la portada no hace nada (es la raíz): no debe romper el foco
	await wait(0.3)
	expect(Main.I.current == "title" and focus() != null, "[title] B no cambia de pantalla ni pierde el foco")
	# ---------------- selección
	Nav.select()
	await wait(0.8)
	var ss: SelectScreen = main.screen
	check("select", ss)
	expect(focus() == ss._avatars[ss.pick], "[select] foco inicial en el avatar elegido (está en %s)" % ftext(focus()))
	await _walk_bottom(ss, "select", ["Modo fácil", "Semilla", "Comenzar"])
	await _seed_dialog(ss)
	await b_goes_to("select", "title")
	# con Pesadilla desbloqueada: ◀/▶ conservan el foco y «Modo fácil» (apagado) se salta
	for c in DB.playable():
		Meta.data["nmBy"][c] = 3
	Nav.select()
	await wait(0.8)
	ss = main.screen
	check("select_pesadilla", ss)
	var up: Button = null
	for b in ss._nm_box.find_children("*", "Button", true, false):
		if (b as Button).text == "▶":
			up = b
	expect(up != null, "[select_pesadilla] hay botón ▶")
	if up != null:
		up.grab_focus()
		await wait(0.1)
		await tap(JOY_BUTTON_A)
		await wait(0.3)
		expect(ss.nm == 1, "[select_pesadilla] A en ▶ sube a Pesadilla 1 (nm=%d)" % ss.nm)
		expect(focus() != null and focus().get("text") == "▶", "[select_pesadilla] tras A en ▶ el foco sigue en ▶ (está en %s)" % ftext(focus()))
		check("select_pesadilla_nm1", ss)
		ss._avatars[ss.pick].grab_focus()
		await wait(0.1)
		await _walk_bottom(ss, "select_pesadilla_nm1", ["Semilla", "Comenzar"])
	Meta.data["nmBy"] = {}
	await b_goes_to("select_pesadilla", "title")
	# ---------------- logros
	for t in ["ach", "mastery", "unl"]:
		Nav.achievements(t)
		await wait(0.8)
		check("achievements_" + t, main.screen)
		first_focus("achievements_" + t, {"ach": "Logros", "mastery": "Maestría", "unl": "Desbloqueos"}[t])
		await b_goes_to("achievements_" + t, "title")
	# A en una pestaña cambia de pestaña y el foco queda en la pestaña nueva
	Nav.achievements("ach")
	await wait(0.8)
	await tap(JOY_BUTTON_DPAD_RIGHT)
	await tap(JOY_BUTTON_A)
	await wait(0.8)
	expect((main.screen as AchievementsScreen).tab == "mastery", "[achievements] D-Pad → y A abren Maestría")
	first_focus("achievements_tras_A", "Maestría")
	# ---------------- compendio (desde la galería)
	for t in [DB.playable()[0], "neutral", "relics"]:
		CompendiumScreen.tab = t
		Nav.compendium(false)
		await wait(1.0)
		check("compendium_" + t, main.screen)
		var name: String = DB.characters[t].name if DB.characters.has(t) else ("Neutrales" if t == "neutral" else "Reliquias")
		first_focus("compendium_" + t, name)
		await b_goes_to("compendium_" + t, "gallery")
	# ---------------- pantallas de partida y diálogos
	var G := Eng.new_run("zafiro", {"seed": 42})
	Meta.run = G
	G.gold = 400
	G.map = RunGen.gen_map_game(G)
	Nav.map()
	await wait(1.0)
	check("map", main.screen)
	Nav.compendium(true)
	await wait(1.0)
	check("compendium_en_partida", main.screen)
	await b_goes_to("compendium_en_partida", "map")
	for d in [["options", func(): Dlg.options()], ["pausa", func(): Dlg.pause_menu()], ["ayuda", func(): Dlg.help()],
			["mazo", func(): Dlg.view_cards("Mazo", G.deck)]]:
		get_viewport().gui_release_focus()
		d[1].call()
		await wait(0.6)
		check(d[0], Main.I.overlay_host)
		Main.I.overlay_host.get_child(0).close(null)
		await wait(0.3)
	get_viewport().gui_release_focus()
	for s in [["shop", func(): Nav.shop()], ["rest", func(): Nav.rest()], ["event", func(): Nav.event()],
			["reward", func(): Nav.reward(Eng.combat_reward(G, "elite"), "elite")], ["favor", func(): Nav.favor()],
			["history", func(): Nav.history()], ["gallery", func(): Nav.gallery()]]:
		s[1].call()
		await wait(1.0)
		check(s[0], main.screen)
	print("RESULTADO: %d ok, %d fallan" % [oks, fails])
	get_tree().quit(1 if fails > 0 else 0)


## Desde el avatar elegido: ↓ y luego → por la fila de abajo, comprobando cada parada.
func _walk_bottom(ss: SelectScreen, name: String, stops: Array) -> void:
	await tap(JOY_BUTTON_DPAD_DOWN)
	expect(focus() != null and str(focus().get("text")).begins_with(stops[0]), "[%s] ↓ desde el avatar va a «%s» (está en %s)" % [name, stops[0], ftext(focus())])
	for i in range(1, stops.size()):
		await tap(JOY_BUTTON_DPAD_RIGHT)
		expect(focus() != null and str(focus().get("text")).begins_with(stops[i]), "[%s] → llega a «%s» (está en %s)" % [name, stops[i], ftext(focus())])
	await tap(JOY_BUTTON_DPAD_UP)
	expect(focus() == ss._avatars[ss.pick], "[%s] ↑ desde la fila de abajo vuelve al avatar elegido (está en %s)" % [name, ftext(focus())])


## A en «Semilla» abre el diálogo; al aceptar, el botón se rehace con la semilla y el foco vuelve a él.
func _seed_dialog(ss: SelectScreen) -> void:
	ss._sd.grab_focus()
	await wait(0.1)
	await tap(JOY_BUTTON_A)
	await wait(0.5)
	expect(Main.I.overlay_host.get_child_count() > 0, "[select] A en «Semilla» abre el diálogo")
	if Main.I.overlay_host.get_child_count() == 0:
		return
	Main.I.overlay_host.get_child(0).close("abc")
	await wait(0.5)
	expect(ss.seed_txt == "abc", "[select] la semilla queda en «abc» (%s)" % ss.seed_txt)
	expect(focus() == ss._sd and str(ss._sd.text).contains("abc"), "[select] tras el diálogo el foco vuelve a «Semilla: abc» (está en %s)" % ftext(focus()))
