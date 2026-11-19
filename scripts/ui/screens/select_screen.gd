class_name SelectScreen
extends Control
## Selección de personaje, dificultad y Pesadilla.

var pick := ""
var easy := false
var nm := 0
var seed_txt := ""
var _bg: TextureRect
var _panel: VBoxContainer
var _nm_box: VBoxContainer
var _avatars := {}
var _go: Button
var _mid: HBoxContainer
var _back: Button
var _bottom_first: Control
var _bottom_last: Control
var _glow_rect: ColorRect


func _ready() -> void:
	Meta.run = null
	var chars: Array = DB.characters.values()
	pick = TitleScreen.last_char if TitleScreen.last_char != "" and DB.characters[TitleScreen.last_char].implemented else DB.playable()[0]
	easy = Meta.settings.easy
	_bg = TextureRect.new()
	_bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UIK.full_rect(_bg)
	add_child(_bg)
	var sh := TextureRect.new()
	sh.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.88)], [0.5, Color(0, 0, 0, 0.5)], [1.0, Color(0, 0, 0, 0.05)]], true)
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	UIK.full_rect(sh)
	add_child(sh)
	var sh2 := UIK.shade(0.0, 0.0)
	sh2.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0)], [0.7, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.85)]])
	add_child(sh2)
	_panel = VBoxContainer.new()
	_panel.position = Vector2(56, 60)
	_panel.size = Vector2(560, 400)
	_panel.add_theme_constant_override("separation", 6)
	add_child(_panel)
	_nm_box = VBoxContainer.new()
	_nm_box.position = Vector2(56, 470)
	_nm_box.size = Vector2(700, 100)
	_nm_box.add_theme_constant_override("separation", 6)
	add_child(_nm_box)
	var av := HBoxContainer.new()
	av.position = Vector2(0, 566)
	av.size = Vector2(1280, 80)
	av.alignment = BoxContainer.ALIGNMENT_CENTER
	av.add_theme_constant_override("separation", 14)
	add_child(av)
	for m in chars:
		var b := Button.new()
		b.custom_minimum_size = Vector2(66, 66)
		b.focus_mode = Control.FOCUS_ALL
		b.flat = true
		var t := TextureRect.new()
		t.texture = UIK.tex("res://assets/ui/%s_icon.png" % m.id)
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.size = Vector2(66, 66)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(t)
		if not m.implemented:
			t.modulate = Color(0.4, 0.4, 0.4)
			var lk := Icons.rect("ui", "lock", 22)
			lk.position = Vector2(42, 40)
			b.add_child(lk)
		var sb := UIK.stylebox(Color(0, 0, 0, 0), Color("#4a3f6b"), 3, 10, 0)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb)
		b.pivot_offset = Vector2(33, 33)
		var id: String = m.id
		b.pressed.connect(func(): _choose(id))
		b.focus_entered.connect(func(): _choose(id))
		UIK.tip(b, "[b][color=#f0cf7a]%s[/color][/b]" % m.name)
		av.add_child(b)
		_avatars[m.id] = b
	var bot := HBoxContainer.new()
	bot.position = Vector2(40, 650)
	bot.size = Vector2(1200, 60)
	bot.add_theme_constant_override("separation", 20)
	add_child(bot)
	var back := UIK.button("← Volver")
	back.pressed.connect(func(): Nav.title())
	bot.add_child(back)
	_mid = HBoxContainer.new()
	_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	bot.add_child(_mid)
	_go = UIK.button("Comenzar", "big green")
	_go.pressed.connect(_start)
	bot.add_child(_go)
	_render(false)
	Sfx.music("menu", 1, TitleScreen.last_char if TitleScreen.last_char != "" else "zafiro")
	var order := []
	for m in chars:
		order.append(_avatars[m.id])
	for i in order.size():   # fila de avatares: izquierda/derecha recorren los personajes (no saltan a los ajustes de abajo)
		var btn: Button = order[i]
		btn.focus_neighbor_left = order[(i - 1 + order.size()) % order.size()].get_path()
		btn.focus_neighbor_right = order[(i + 1) % order.size()].get_path()
	_go.focus_neighbor_top = _avatars[pick].get_path()
	_back = back
	_wire_bottom()
	_avatars[pick].grab_focus.call_deferred()


func on_escape() -> void:
	Nav.title()


func _choose(id: String) -> void:
	if id == pick:
		return
	Sfx.play("select")
	pick = id
	nm = 0
	_render(true)


func _start() -> void:
	if not DB.characters[pick].implemented:
		return
	var G := Eng.new_run(pick, {"easy": easy, "nm": nm, "seed": Eng.seed_from_text(seed_txt)})
	G["seeded"] = true   # cada acto arranca de un RNG propio: la misma semilla repite los mismos mapas
	Meta.run = G
	Meta.clear_save()
	G.map = RunGen.gen_map_game(G)
	Nav.favor()


func _render(animate: bool) -> void:
	var m: Dictionary = DB.characters[pick]
	_bg.texture = UIK.tex("res://assets/ui/%s_select.webp" % pick)
	for c in _panel.get_children():
		c.queue_free()
	var glow := Color(m.glow)
	if m.implemented:
		var r: Dictionary = DB.relics[m.startRelic]
		_panel.add_child(UIK.label(m.role, 20, UIK.GOLD))
		var nm_l := UIK.label(m.name, 92, Color.WHITE, "title")
		nm_l.add_theme_color_override("font_shadow_color", Color(glow, 0.6))
		nm_l.add_theme_constant_override("shadow_offset_y", 0)
		UIK.outlined(nm_l, 10, Color(0, 0, 0, 0.7))
		_panel.add_child(nm_l)
		var stats := UIK.rich("%s %d PV      %s 99" % [Icons.bb("ui", "hp", 24), m.hp, Icons.bb("ui", "gold", 24)], 20, Color("#ffd8da"))
		stats.fit_content = true
		_panel.add_child(stats)
		var pc := PanelContainer.new()
		var sb := UIK.stylebox(Color(0.04, 0.03, 0.08, 0.6), Color(0, 0, 0, 0), 0, 4, 0)
		sb.border_color = glow
		sb.border_width_left = 3
		sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 10; sb.content_margin_bottom = 10
		pc.add_theme_stylebox_override("panel", sb)
		var d := UIK.rich(m.desc, 18, Color("#ece6ff"))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(520, 0)
		pc.add_child(d)
		_panel.add_child(pc)
		var rr := UIK.rich("%s [b][color=#f0cf7a]%s[/color][/b]: %s" % [Icons.bb("relic", m.startRelic, 30), r.n, r.d], 16, UIK.DIM)
		rr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rr.custom_minimum_size = Vector2(520, 0)
		_panel.add_child(rr)
	else:
		_panel.add_child(UIK.label("Próximamente", 20, UIK.GOLD))
		_panel.add_child(UIK.label(m.name, 92, Color.WHITE, "title"))
		_panel.add_child(UIK.label("Esta musa aún no está disponible.", 18, Color("#ece6ff")))
	_go.disabled = not m.implemented
	for id in _avatars.keys():
		var b: Button = _avatars[id]
		var on: bool = id == pick
		var sb2 := UIK.stylebox(Color(0, 0, 0, 0), UIK.GOLD if on else Color("#4a3f6b"), 3, 10, 0)
		for st in ["normal", "hover", "pressed", "focus", "disabled"]:
			b.add_theme_stylebox_override(st, sb2)
		b.create_tween().tween_property(b, "scale", Vector2(1.14, 1.14) if on else Vector2.ONE, 0.12)
		b.modulate = Color.WHITE if on else Color(0.62, 0.62, 0.62)
	if animate:
		for n in [_bg, _panel]:
			n.modulate.a = 0.0
			n.create_tween().tween_property(n, "modulate:a", 1.0, 0.3)
	_render_nm()
	_render_toggle()


func _render_nm() -> void:
	for c in _nm_box.get_children():
		c.queue_free()
	var m: Dictionary = DB.characters[pick]
	if not m.implemented:
		return
	var nm_max := Meta.nm_unlocked(pick)
	if nm_max > 0:
		var st := HBoxContainer.new()
		st.add_theme_constant_override("separation", 10)
		var dn := UIK.button("◀", "small")
		var up := UIK.button("▶", "small")
		var lab := UIK.label("Pesadilla %d" % nm if nm > 0 else "Pesadilla: apagada", 20, Color("#caa5ff"), "bold")
		dn.pressed.connect(func(): nm = maxi(0, nm - 1); _render_nm(); _render_toggle())
		up.pressed.connect(func(): nm = mini(nm_max, nm + 1); _render_nm(); _render_toggle())
		st.add_child(dn)
		st.add_child(lab)
		st.add_child(up)
		_nm_box.add_child(st)
		var fx := ("[b]Nv.%d[/b] %s%s" % [nm, DB.nm_texts[nm], " [i](y los niveles anteriores)[/i]" if nm > 1 else ""]) if nm > 0 else "Nivel disponible para %s: hasta %d." % [m.name, nm_max]
		var r := UIK.rich(fx, 17, Color("#ece6ff"))
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(640, 0)
		_nm_box.add_child(r)
	else:
		_nm_box.add_child(UIK.label("Termina el juego con %s para desbloquear su Pesadilla" % m.name, 16, UIK.DIM))


func _render_toggle() -> void:
	for c in _mid.get_children():
		c.queue_free()
	var cb := CheckButton.new()
	cb.text = "Modo fácil"
	cb.button_pressed = easy and nm == 0
	cb.disabled = nm > 0
	cb.add_theme_font_override("font", UIK.font("bold"))
	cb.add_theme_font_size_override("font_size", 20)
	cb.toggled.connect(func(p): easy = p; Meta.settings.easy = p; Meta.save_settings(); Sfx.play("select"))
	UIK.tip(cb, "[b][color=#f0cf7a]Modo fácil[/color][/b]\nMás vida, enemigos más débiles y puedes deshacer la última carta jugada. No se combina con la Pesadilla.")
	_mid.add_child(cb)
	var sd := UIK.button("Semilla: " + (seed_txt if seed_txt != "" else "aleatoria"), "small")
	sd.pressed.connect(func():
		var t = await Dlg.text_input("Semilla", "Escribe un número o una palabra para repetir los mismos mapas (por ejemplo, la semilla de una partida de un amigo). Déjalo vacío para una partida aleatoria.", seed_txt, "aleatoria")
		if t != null:
			seed_txt = str(t).strip_edges()
			_render_toggle())
	UIK.tip(sd, "[b][color=#f0cf7a]Semilla[/color][/b]\nLa misma semilla genera los mismos mapas en los tres actos.")
	_mid.add_child(sd)
	_bottom_first = cb
	_bottom_last = sd
	_wire_bottom()


## Fila inferior para el mando: avatares ↓ ajustes ↔ Volver … Comenzar.
func _wire_bottom() -> void:
	if _back == null or _go == null or _bottom_first == null:
		return
	_back.focus_neighbor_right = _bottom_first.get_path()
	_bottom_first.focus_neighbor_left = _back.get_path()
	_bottom_last.focus_neighbor_right = _go.get_path()
	_go.focus_neighbor_left = _bottom_last.get_path()
	for b in _avatars.values():
		(b as Button).focus_neighbor_bottom = _bottom_first.get_path()
