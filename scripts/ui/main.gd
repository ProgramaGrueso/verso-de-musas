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
	Nav.title()


var _stick_h := 0.0
var _stick_v := 0.0
var _trigger_lt := false
var _trigger_rt := false


func _exit_tree() -> void:
	UIK._fonts.clear()   # libera las fuentes cacheadas (evita 'resources still in use' al salir)
	Tip.I = null
	I = null


func _input(ev: InputEvent) -> void:
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
	for c in _tb_relics.get_children():
		c.queue_free()
	for id in G.relics:
		var r: Dictionary = DB.relics[id]
		var l: Control = Icons.frame("relic", id, 48, Color("#c9a24a"), true) if Icons.has("relic", id) else UIK.label(r.i, 28)
		UIK.tip(l, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [r.n, r.d])
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
