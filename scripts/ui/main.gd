class_name Main
extends Control
## Raíz del juego: contiene la pantalla actual, la barra superior, los diálogos y los avisos.

static var I: Main

var screen_host: Control
var overlay_host: Control
var top: Control
var toast_lbl: Label
var current := ""
var screen: Control = null
var on_potion := Callable()

var _tb_who: HBoxContainer
var _tb_hp: Label
var _tb_gold: Label
var _tb_act: Label
var _tb_deck_n: Label
var _tb_potions: HBoxContainer
var _tb_relics: HFlowContainer
var _tb_relics_key := "-"         # se reconstruyen solo si cambia la lista (así el pulso de una reliquia no se corta)
var _relic_last := {}             # id -> ms del último pulso
var _relic_tags := 0              # rótulos de reliquia visibles a la vez (se apilan)
var _toast_tw: Tween
var _full_btn: Button


func _ready() -> void:
	I = self
	for k in ["sans", "bold", "title"]:   # precarga fuentes (evita tirón en la primera pantalla)
		UIK.font(k)
	UIK.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var bg := ColorRect.new()
	bg.color = UIK.BG
	UIK.full_rect(bg)
	add_child(bg)
	screen_host = Control.new()
	UIK.full_rect(screen_host)
	screen_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(screen_host)
	_build_top()
	overlay_host = Control.new()
	UIK.full_rect(overlay_host)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_host)
	toast_lbl = UIK.label("", 22, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	toast_lbl.position = Vector2(340, 640)
	toast_lbl.size = Vector2(600, 40)
	toast_lbl.modulate.a = 0.0
	toast_lbl.z_index = 3000
	UIK.outlined(toast_lbl, 6)
	add_child(toast_lbl)
	var tip := Tip.new()
	add_child(tip)
	Meta.unlocked.connect(_on_unlock)
	# todo ScrollContainer sigue al control con foco (mando/teclado llegan a lo que queda fuera de vista)
	get_tree().node_added.connect(func(n: Node): if n is ScrollContainer: (n as ScrollContainer).follow_focus = true)
	_insp_frame = Panel.new()
	_insp_frame.visible = false
	_insp_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_insp_frame.z_index = 3500
	_insp_frame.add_theme_stylebox_override("panel", UIK.stylebox(Color(0, 0, 0, 0), UIK.GOLD, 3, 8, 10))
	add_child(_insp_frame)
	Nav.title()


var _stick_h := 0.0
var _stick_v := 0.0
var _trigger_lt := false
var _trigger_rt := false

# ---------- Inspeccionar con mando (R3): lee estados, intenciones, reliquias, pociones... ----------
var _insp_on := false
var _insp_list: Array = []
var _insp_idx := 0
var _insp_ov := 0
var _insp_scr := ""
var _insp_sh := 0.0
var _insp_sv := 0.0
var _insp_frame: Panel


func _insp_collect(n: Node, out: Array) -> void:
	if n == _insp_frame or n is Tip:
		return
	if n is Control:
		var c := n as Control
		if not c.visible:
			return
		if c.has_meta("tip") and c.is_visible_in_tree() and c.size.x > 2 and c.size.y > 2:
			var tv = c.get_meta("tip")
			if tv is Callable:
				tv = tv.call()
			var r := c.get_global_rect()
			if str(tv) != "" and get_viewport_rect().grow(-1).intersects(r):
				out.append(c)
	for ch in n.get_children():
		_insp_collect(ch, out)


func _insp_start() -> void:
	var root: Node = self
	if overlay_host.get_child_count() > 0:
		root = overlay_host.get_child(overlay_host.get_child_count() - 1)
	var l := []
	_insp_collect(root, l)
	if l.is_empty():
		Sfx.play("error")
		toast("No hay nada que inspeccionar aquí.")
		return
	# el primero: el más cercano al centro de la pantalla
	var best := 0
	var bd := INF
	var mid := get_viewport_rect().size / 2.0
	for i in l.size():
		var d: float = (l[i].get_global_rect().get_center() - mid).length()
		if d < bd:
			bd = d
			best = i
	_insp_list = l
	_insp_on = true
	_insp_ov = overlay_host.get_child_count()
	_insp_scr = current
	_insp_stop_input_state()
	_insp_show(best)
	toast("Inspeccionar: D-Pad / Stick mover · B o R3 salir")


func _insp_stop_input_state() -> void:
	_insp_sh = 0.0
	_insp_sv = 0.0


func _insp_show(i: int) -> void:
	_insp_idx = i
	var c: Control = _insp_list[i]
	if not is_instance_valid(c):
		_insp_end()
		return
	var r := c.get_global_rect().grow(5)
	_insp_frame.global_position = r.position
	_insp_frame.size = r.size
	_insp_frame.visible = true
	Tip.show_at(c)
	Sfx.play("select_soft", 0.5)


func _insp_end() -> void:
	_insp_on = false
	_insp_list = []
	_insp_frame.visible = false
	Tip.hide_all()


func _insp_move(dir: Vector2) -> void:
	var cur: Control = _insp_list[_insp_idx]
	var c0 := cur.get_global_rect().get_center()
	var best := -1
	var bs := INF
	for i in _insp_list.size():
		if i == _insp_idx or not is_instance_valid(_insp_list[i]):
			continue
		var d: Vector2 = (_insp_list[i] as Control).get_global_rect().get_center() - c0
		var dist := d.length()
		if dist < 1.0:
			continue
		var cs := d.normalized().dot(dir)
		if cs < 0.35:
			continue
		var sc := dist * (2.2 - cs)
		if sc < bs:
			bs = sc
			best = i
	if best >= 0:
		_insp_show(best)


func _insp_input(ev: InputEvent) -> bool:
	if ev is InputEventJoypadButton:
		if not ev.pressed:
			return true
		match ev.button_index:
			JOY_BUTTON_DPAD_LEFT:
				_insp_move(Vector2.LEFT)
			JOY_BUTTON_DPAD_RIGHT:
				_insp_move(Vector2.RIGHT)
			JOY_BUTTON_DPAD_UP:
				_insp_move(Vector2.UP)
			JOY_BUTTON_DPAD_DOWN:
				_insp_move(Vector2.DOWN)
			JOY_BUTTON_B, JOY_BUTTON_A, JOY_BUTTON_RIGHT_STICK, JOY_BUTTON_START, JOY_BUTTON_BACK:
				_insp_end()
		return true
	if ev is InputEventJoypadMotion:
		if ev.axis == JOY_AXIS_LEFT_X:
			if absf(ev.axis_value) > 0.5 and _insp_sh == 0.0:
				_insp_sh = signf(ev.axis_value)
				_insp_move(Vector2(_insp_sh, 0))
			elif absf(ev.axis_value) < 0.25:
				_insp_sh = 0.0
		elif ev.axis == JOY_AXIS_LEFT_Y:
			if absf(ev.axis_value) > 0.5 and _insp_sv == 0.0:
				_insp_sv = signf(ev.axis_value)
				_insp_move(Vector2(0, _insp_sv))
			elif absf(ev.axis_value) < 0.25:
				_insp_sv = 0.0
		return true
	return false


# ---------- Scroll con el stick derecho ----------
func _find_scrolls(n: Node, out: Array) -> void:
	if n is ScrollContainer and (n as ScrollContainer).is_visible_in_tree():
		out.append(n)
	for ch in n.get_children():
		_find_scrolls(ch, out)


func _process(dt: float) -> void:
	if _insp_on:
		if overlay_host.get_child_count() != _insp_ov or current != _insp_scr:
			_insp_end()
		return
	var ay := Input.get_joy_axis(0, JOY_AXIS_RIGHT_Y)
	var ax := Input.get_joy_axis(0, JOY_AXIS_RIGHT_X)
	if absf(ay) < 0.25 and absf(ax) < 0.25:
		return
	var root: Node = self
	if overlay_host.get_child_count() > 0:
		root = overlay_host.get_child(overlay_host.get_child_count() - 1)
	var l := []
	_find_scrolls(root, l)
	for s in l:
		var sc := s as ScrollContainer
		var vmax := sc.get_v_scroll_bar().max_value - sc.get_v_scroll_bar().page
		var hmax := sc.get_h_scroll_bar().max_value - sc.get_h_scroll_bar().page
		if vmax > 1.0 and absf(ay) >= 0.25:
			sc.scroll_vertical = int(clampf(sc.scroll_vertical + ay * 1100.0 * dt, 0.0, vmax))
			return
		if hmax > 1.0 and absf(ax) >= 0.25:
			sc.scroll_horizontal = int(clampf(sc.scroll_horizontal + ax * 1100.0 * dt, 0.0, hmax))
			return


func _exit_tree() -> void:
	UIK._fonts.clear()   # libera las fuentes cacheadas (evita 'resources still in use' al salir)
	Tip.I = null
	I = null


func _input(ev: InputEvent) -> void:
	if _insp_on:
		if _insp_input(ev):
			get_viewport().set_input_as_handled()
		return
	if ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_RIGHT_STICK:
		_insp_start()
		get_viewport().set_input_as_handled()
		return
	if ev is InputEventJoypadButton and ev.pressed:
		if _handle_joypad_button(ev.button_index):
			get_viewport().set_input_as_handled()
			return
	elif ev is InputEventJoypadMotion:
		if _handle_joypad_motion(ev.axis, ev.axis_value):
			get_viewport().set_input_as_handled()
			return


func _handle_joypad_button(btn: int) -> bool:
	if overlay_host.get_child_count() > 0:
		if btn in [JOY_BUTTON_B, JOY_BUTTON_BACK]:
			var top_overlay = overlay_host.get_child(overlay_host.get_child_count() - 1)
			if top_overlay is Dlg.Overlay and top_overlay.allow_esc:
				top_overlay.close(top_overlay.cancel_result)
				return true
		elif btn == JOY_BUTTON_START:
			var top_overlay = overlay_host.get_child(overlay_host.get_child_count() - 1)
			if top_overlay is Dlg.Overlay and top_overlay.allow_esc:
				top_overlay.close(top_overlay.cancel_result)
				return true
		return false

	if btn == JOY_BUTTON_START:
		if Meta.run != null and current in ["map", "combat", "reward", "shop", "rest", "event"]:
			Dlg.pause_menu()
			return true
	elif btn == JOY_BUTTON_BACK:
		if Meta.run != null and current in ["map", "combat", "reward", "shop", "rest", "event"]:
			open_deck_dialog()
			return true

	if current == "map" and btn == JOY_BUTTON_X and screen != null and screen.has_method("_focus"):
		screen._focus(true)   # X: centrar el mapa en tu posición
		return true

	if current == "combat" and screen is CombatScreen:
		if (screen as CombatScreen).handle_gamepad_button(btn):
			return true

	if btn == JOY_BUTTON_B:
		if screen != null and screen.has_method("on_escape"):
			screen.on_escape()
			return true
		elif Meta.run != null and current in ["map", "reward", "shop", "rest", "event"]:
			Dlg.pause_menu()
			return true

	return false


func _handle_joypad_motion(axis: int, value: float) -> bool:
	if overlay_host.get_child_count() > 0:
		return false

	if current == "combat" and screen is CombatScreen:
		var cs := screen as CombatScreen
		if axis == JOY_AXIS_TRIGGER_LEFT:
			if value > 0.5 and not _trigger_lt:
				_trigger_lt = true
				return cs.handle_gamepad_trigger(true)
			elif value < 0.2:
				_trigger_lt = false
		elif axis == JOY_AXIS_TRIGGER_RIGHT:
			if value > 0.5 and not _trigger_rt:
				_trigger_rt = true
				return cs.handle_gamepad_trigger(false)
			elif value < 0.2:
				_trigger_rt = false
		elif axis == JOY_AXIS_LEFT_X:
			if value > 0.45 and _stick_h <= 0.0:
				_stick_h = 1.0
				cs.cycle_card(1)
				return true
			elif value < -0.45 and _stick_h >= 0.0:
				_stick_h = -1.0
				cs.cycle_card(-1)
				return true
			elif absf(value) < 0.25:
				_stick_h = 0.0
		elif axis == JOY_AXIS_LEFT_Y:
			if value > 0.45 and _stick_v <= 0.0:
				_stick_v = 1.0
				cs.cycle_target(1)
				return true
			elif value < -0.45 and _stick_v >= 0.0:
				_stick_v = -1.0
				cs.cycle_target(-1)
				return true
			elif absf(value) < 0.25:
				_stick_v = 0.0

	return false


func open_deck_dialog() -> void:
	if Meta.run != null:
		Dlg.view_cards("Tu mazo", _sorted_deck())


func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode == KEY_F11:
			_toggle_fullscreen()
		elif ev.keycode == KEY_M and overlay_host.get_child_count() == 0 and Meta.run != null and current in ["map", "combat", "reward", "shop", "rest", "event"]:
			open_deck_dialog()
		elif ev.keycode in [KEY_H, KEY_F1] and overlay_host.get_child_count() == 0 and not (current in ["select"]):
			Dlg.help()
		elif ev.keycode == KEY_ESCAPE:
			if overlay_host.get_child_count() == 0 and screen != null and screen.has_method("on_escape"):
				screen.on_escape()
			elif overlay_host.get_child_count() == 0 and Meta.run != null and current in ["map", "combat", "reward", "shop", "rest", "event"]:
				Dlg.pause_menu()


func _toggle_fullscreen() -> void:
	var w := get_window()
	w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN


# ---------- Pantallas ----------
func set_screen(node: Control, name: String) -> void:
	Tip.hide_all()
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
	screen = node
	current = name
	UIK.full_rect(node)
	screen_host.add_child(node)
	update_top()


func update_top() -> void:
	var G = Meta.run
	var show_top: bool = G != null and not (current in ["title", "select", "gallery", "ending", "end", "history"])
	top.visible = show_top
	if not show_top:
		return
	# retrato
	for c in _tb_who.get_children():
		c.queue_free()
	var pic := Panel.new()
	pic.custom_minimum_size = Vector2(60, 60)
	pic.add_theme_stylebox_override("panel", UIK.stylebox(Color("#14101e"), Color("#c9a24a"), 3, 30, 6))
	pic.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var tr := TextureRect.new()
	tr.texture = UIK.tex("res://assets/ui/%s_icon.png" % G.char)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.size = Vector2(60, 60)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.add_child(tr)
	pic.mouse_filter = Control.MOUSE_FILTER_PASS
	var who_tip: String = "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [DB.characters[G.char].name, DB.characters[G.char].role]
	var perm := Eng.perm_text(G)
	if perm != "":
		who_tip += "\n[color=#8bf0a4]Bendiciones permanentes: %s.[/color]" % perm
	if G.get("daily", "") != "":
		who_tip += "\n[color=#caa5ff]Reto diario %s: %s[/color]" % [G.daily, Daily.mod_name(G.get("dailyMod", ""))]
	UIK.tip(pic, who_tip)
	_tb_who.add_child(pic)
	_tb_hp.text = "%d/%d" % [G.hp, G.maxHp]
	_tb_gold.text = "%d" % G.gold
	var act: Dictionary = DB.acts[G.act - 1]
	_tb_act.text = "%s · %s" % [act.sub, act.name]
	var fv := Favors.active(G)
	if not fv.is_empty():
		_tb_act.text += "  [%s]" % fv.name
	_tb_deck_n.text = str(G.deck.size())
	# reliquias (bajo la cabecera)
	var rkey := ",".join(G.relics)
	if rkey != _tb_relics_key:
		_tb_relics_key = rkey
		for c in _tb_relics.get_children():
			c.queue_free()
		for id in G.relics:
			var r: Dictionary = DB.relics[id]
			var l: Control = Icons.frame("relic", id, 48, Color("#c9a24a"), true) if Icons.has("relic", id) else UIK.label(r.i, 28)
			UIK.tip(l, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [r.n, r.d])
			l.set_meta("relic_id", id)
			_tb_relics.add_child(l)
	# pociones
	for c in _tb_potions.get_children():
		c.queue_free()
	for i in G.potions.size():
		var id = G.potions[i]
		var slot: int = i
		var b := Button.new()
		b.custom_minimum_size = Vector2(46, 46)
		b.focus_mode = Control.FOCUS_NONE
		var sb := UIK.stylebox(Color("#0d1418", 0.9), Color("#2a3d46"), 2, 23, 0)
		if id != null:
			var p: Dictionary = DB.potions[id]
			sb = UIK.stylebox(Color("#0d1418", 0.9), Color(p.c), 2, 23, 0)
			b.expand_icon = true
			b.icon = Icons.tex("potion", id)
			if b.icon == null:
				b.text = p.i   # sin icono pintado todavía: el emoji de la poción
				b.add_theme_font_override("font", UIK.font())
				b.add_theme_font_size_override("font_size", 22)
			b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
			b.add_theme_constant_override("icon_max_width", 40)
			for c in ["icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_normal_color"]:
				b.add_theme_color_override(c, Color.WHITE)
			UIK.tip(b, "[b][color=#f0cf7a]%s[/color][/b]\n%s\n[i]Haz clic para usarla en combate.[/i]" % [p.n, p.d])
			b.pressed.connect(func(): if on_potion.is_valid(): on_potion.call(slot) else: toast("Solo puedes usar pociones en combate."))
		else:
			b.modulate = Color(1, 1, 1, 0.55)
			UIK.tip(b, "[b][color=#f0cf7a]Hueco de poción[/color][/b]\nAquí se guardan las pociones.")
		for st in ["normal", "hover", "pressed", "disabled", "focus"]:
			b.add_theme_stylebox_override(st, sb)
		_tb_potions.add_child(b)


## Botón de icono sin marco (crece al pasar el ratón).
func _icon_btn(icon_id: String, size: float, tip: String, fn: Callable) -> Control:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.pivot_offset = Vector2(size, size) / 2.0
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	var ir: Control = Icons.frame("ui", icon_id, size, Color("#c9a24a"), true, 3)
	if not Icons.has("ui", icon_id):
		b.text = icon_id
	b.add_child(ir)
	b.mouse_entered.connect(func():
		b.create_tween().tween_property(b, "scale", Vector2(1.14, 1.14), 0.1)
		Sfx.play("select_soft", 0.4))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	b.pressed.connect(func(): Sfx.play("click"); fn.call())
	UIK.tip(b, tip)
	return b


func _build_top() -> void:
	top = Control.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_bottom = 120
	top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.z_index = 100
	var sh := TextureRect.new()
	sh.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.78)], [1.0, Color(0, 0, 0, 0)]])
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.size = Vector2(1280, 96)
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(sh)
	var left := HBoxContainer.new()
	left.position = Vector2(14, 6)
	left.add_theme_constant_override("separation", 18)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(left)
	_tb_who = HBoxContainer.new()
	left.add_child(_tb_who)
	var hp_box := _stat_box("hp", Color("#ff5a68"))
	_tb_hp = hp_box.get_node("Text")
	left.add_child(hp_box)
	var gold_box := _stat_box("gold", Color("#f6d56a"))
	_tb_gold = gold_box.get_node("Text")
	left.add_child(gold_box)
	var tray := PanelContainer.new()
	var tsb := UIK.stylebox(Color("#0a161c", 0.88), Color("#294651"), 2, 30, 8)
	tsb.content_margin_left = 10; tsb.content_margin_right = 10; tsb.content_margin_top = 6; tsb.content_margin_bottom = 6
	tray.add_theme_stylebox_override("panel", tsb)
	tray.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_tb_potions = HBoxContainer.new()
	_tb_potions.add_theme_constant_override("separation", 6)
	tray.add_child(_tb_potions)
	left.add_child(tray)
	_tb_relics = HFlowContainer.new()
	_tb_relics.position = Vector2(14, 76)
	_tb_relics.custom_minimum_size = Vector2(380, 0)
	_tb_relics.size = Vector2(380, 44)
	_tb_relics.add_theme_constant_override("h_separation", 6)
	_tb_relics.add_theme_constant_override("v_separation", 6)
	_tb_relics.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(_tb_relics)
	# derecha
	var right := HBoxContainer.new()
	right.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	right.offset_left = -330
	right.offset_right = -14
	right.offset_top = 6
	right.alignment = BoxContainer.ALIGNMENT_END
	right.add_theme_constant_override("separation", 8)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	top.add_child(right)
	right.add_child(_icon_btn("help", 58, "[b][color=#f0cf7a]Cómo jugar[/color][/b]", func(): Dlg.help()))
	right.add_child(_icon_btn("menu", 58, "[b][color=#f0cf7a]Pausa[/color][/b]\nGuardar y salir, rendirse (Esc)", func(): Dlg.pause_menu()))
	var deck_b := _icon_btn("deck", 64, "[b][color=#f0cf7a]Tu mazo[/color][/b]\nMira todas tus cartas.", func(): Dlg.view_cards("Tu mazo", _sorted_deck()))
	_tb_deck_n = UIK.label("0", 20, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	_tb_deck_n.size = Vector2(30, 26)
	_tb_deck_n.position = Vector2(32, 34)
	UIK.outlined(_tb_deck_n, 6)
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", UIK.stylebox(Color("#b3202e"), Color("#ffd2d6"), 2, 13, 0))
	badge.size = Vector2(30, 26)
	badge.position = Vector2(30, 32)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	deck_b.add_child(badge)
	deck_b.add_child(_tb_deck_n)
	right.add_child(deck_b)
	right.add_child(_icon_btn("gear", 58, "[b][color=#f0cf7a]Opciones[/color][/b]\nVolumen y controles.", func(): Dlg.options()))
	_tb_act = UIK.label("", 15, Color("#cfc7e6"), "bold", HORIZONTAL_ALIGNMENT_RIGHT)
	_tb_act.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_tb_act.offset_left = -420
	_tb_act.offset_right = -18
	_tb_act.offset_top = 72
	UIK.outlined(_tb_act, 5)
	top.add_child(_tb_act)
	add_child(top)
	top.visible = false


func _stat_box(icon_id: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic: Control = Icons.frame("ui", icon_id, 50, Color("#c9a24a"), true, 2)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UIK.label("", 30, color, "bold")
	l.name = "Text"
	UIK.outlined(l, 7)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(l)
	return h


func _sorted_deck() -> Array:
	var d: Array = Meta.run.deck.duplicate()
	d.sort_custom(func(a, b): return a.id < b.id)
	return d


# ---------- Avisos ----------
## Una reliquia acaba de hacer algo: su icono late y aparece un rótulo breve con su nombre y efecto.
func pulse_relic(id: String) -> void:
	if _tb_relics == null or not DB.relics.has(id) or not top.visible:
		return
	var now := Time.get_ticks_msec()
	var last: int = _relic_last.get(id, -100000)
	_relic_last[id] = now
	if now - last < 400:   # ráfagas (varios golpes seguidos): un solo pulso
		return
	Sfx.play("relic", 0.8)
	var icon: Control = null
	for c in _tb_relics.get_children():
		if not c.is_queued_for_deletion() and c.get_meta("relic_id", "") == id:
			icon = c
	if icon == null:
		return
	icon.pivot_offset = icon.size / 2.0
	icon.modulate = Color(2.3, 2.0, 1.2)
	var tw := icon.create_tween().set_parallel(true)
	tw.tween_property(icon, "modulate", Color.WHITE, 0.7)
	if not Juice.calm():
		icon.scale = Vector2(1.55, 1.55)
		tw.tween_property(icon, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		Juice.ring(self, icon.global_position + icon.size / 2.0, UIK.GOLD, 16.0, 46.0, 0.45, 3.0)
	# chip compacto (icono + nombre) en una columna a la izquierda, bajo la barra de reliquias;
	# la descripción completa sigue en el tooltip del icono
	var r: Dictionary = DB.relics[id]
	var p := PanelContainer.new()
	var sb := UIK.stylebox(Color("#120d1d", 0.92), UIK.GOLD, 2, 14, 8)
	sb.content_margin_left = 6; sb.content_margin_right = 12; sb.content_margin_top = 3; sb.content_margin_bottom = 3
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.z_index = 3500
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 6)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if Icons.has("relic", id):
		var ic: Control = Icons.rect("relic", id, 24)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hb.add_child(ic)
	var lb := UIK.rich("[b][color=#f0cf7a]%s[/color][/b] [color=#bfb6d6]¡se activa![/color]" % r.n, 14)
	lb.autowrap_mode = TextServer.AUTOWRAP_OFF
	lb.fit_content = true
	lb.custom_minimum_size = Vector2(200, 0)
	lb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(lb)
	p.add_child(hb)
	add_child(p)
	var slot := _relic_tags
	_relic_tags += 1
	p.position = Vector2(10, 128 + slot * 34)
	p.modulate.a = 0.0
	var pt := p.create_tween()
	pt.tween_interval(slot * 0.12)
	pt.tween_property(p, "modulate:a", 1.0, 0.15)
	pt.tween_interval(1.3)
	pt.tween_property(p, "modulate:a", 0.0, 0.35)
	pt.tween_callback(func():
		_relic_tags = maxi(0, _relic_tags - 1)
		p.queue_free())


func toast(msg: String) -> void:
	toast_lbl.text = msg
	if _toast_tw and _toast_tw.is_valid():
		_toast_tw.kill()
	toast_lbl.modulate.a = 1.0
	_toast_tw = create_tween()
	_toast_tw.tween_interval(1.9)
	_toast_tw.tween_property(toast_lbl, "modulate:a", 0.0, 0.4)


var _unlock_free_at := 0.0


func _on_unlock(l: Dictionary) -> void:
	# los avisos de desbloqueo se encolan de 5 en 5 s
	var now := Time.get_ticks_msec() / 1000.0
	var start := maxf(now, _unlock_free_at)
	_unlock_free_at = start + 5.0
	if start > now:
		await get_tree().create_timer(start - now).timeout
	var d := PanelContainer.new()
	d.add_theme_stylebox_override("panel", UIK.stylebox(Color("#120d1d"), UIK.GOLD, 2, 12, 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	d.add_child(row)
	row.add_child(UIK.label(l.ico, 40))
	var col := VBoxContainer.new()
	col.add_child(UIK.label("Nueva imagen en la Galería", 14, UIK.DIM))
	col.add_child(UIK.label(l.title, 20, UIK.GOLD, "bold"))
	row.add_child(col)
	d.position = Vector2(900, 70)
	d.z_index = 3500
	d.modulate.a = 0.0
	add_child(d)
	Sfx.play("win")
	var tw := d.create_tween()
	tw.tween_property(d, "modulate:a", 1.0, 0.3)
	tw.tween_interval(4.0)
	tw.tween_property(d, "modulate:a", 0.0, 0.5)
	tw.tween_callback(d.queue_free)
