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
var _av_row: HBoxContainer
var _bot: HBoxContainer
var _cb: CheckButton
var _sd: Button
var _seed_max := 14      # letras de la semilla que enseña el botón (baja si la fila no cabe)
var _cb_fs := 0          # fuente de «Modo fácil» (0 = la de diseño escalada)
var _sd_fs := 0          # fuente del botón de semilla (0 = la de diseño escalada)
var _placing := false

const AV_Y := 566.0     # fila de avatares (sube si la de abajo crece con el tamaño de texto)
const NM_Y := 470.0     # bloque de Pesadilla (sube si no cabe sobre los avatares)
const BOT_MARGIN := 8.0 # hueco entre la fila de botones y el borde inferior
const BOT_W := 1200.0   # ancho de la fila inferior
const PANEL_Y := 60.0   # ficha de la musa (sube hasta PANEL_MIN_Y si no cabe sobre la Pesadilla)
const PANEL_MIN_Y := 30.0


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
	_panel.position = Vector2(56, PANEL_Y)
	_panel.size = Vector2(640, 400)   # 640 (antes 560): al 130 % la descripción ocupa una o dos líneas menos
	_panel.add_theme_constant_override("separation", 6)
	add_child(_panel)
	_nm_box = VBoxContainer.new()
	_nm_box.position = Vector2(56, NM_Y)
	_nm_box.size = Vector2(700, 100)
	_nm_box.add_theme_constant_override("separation", 6)
	add_child(_nm_box)
	var av := HBoxContainer.new()
	av.position = Vector2(0, AV_Y)
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
	_av_row = av
	var bot := HBoxContainer.new()
	bot.position = Vector2(40, 650)
	bot.size = Vector2(1200, 62)
	bot.add_theme_constant_override("separation", 20)
	add_child(bot)
	_bot = bot
	# al 115/130 % «Comenzar» mide más de 62 px: la fila se apoya en el borde inferior y lo de encima sube
	bot.resized.connect(_place_rows)
	_nm_box.minimum_size_changed.connect(_place_rows.call_deferred)
	_panel.minimum_size_changed.connect(_place_rows.call_deferred)
	var back := UIK.button(tr("← Volver"))
	back.pressed.connect(func(): Nav.title())
	bot.add_child(back)
	_mid = HBoxContainer.new()
	_mid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mid.alignment = BoxContainer.ALIGNMENT_CENTER
	_mid.add_theme_constant_override("separation", 14)
	bot.add_child(_mid)
	_go = UIK.button(tr("Comenzar"), "big green")
	_go.pressed.connect(_start)
	bot.add_child(_go)
	# la fila de abajo nunca se sale de la pantalla: lo que no cabe se parte o se encoge
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
	_place_rows.call_deferred()


## Coloca de abajo arriba: botones a BOT_MARGIN del borde, avatares encima y el bloque de Pesadilla encima de
## los avatares (nunca más abajo de su sitio de diseño a 100 %).
func _place_rows() -> void:
	if _bot == null or _av_row == null or _placing:
		return
	_placing = true
	_fit_bottom()
	_bot.size = Vector2(BOT_W, 0.0)   # vuelve a su mínimo (al 130 % o con la semilla larga pudo crecer)
	_placing = false
	var bh := maxf(_bot.size.y, _bot.get_combined_minimum_size().y)
	_bot.position.y = 720.0 - BOT_MARGIN - bh
	_av_row.position.y = minf(AV_Y, _bot.position.y - _av_row.size.y)
	var nh := _nm_box.get_combined_minimum_size().y
	_nm_box.position.y = minf(NM_Y, _av_row.position.y - 2.0 - nh)
	# la ficha de arriba (rol, nombre, PV, descripción, reliquia) termina antes del bloque de Pesadilla: sube
	# hasta PANEL_MIN_Y y, si aún no cabe (al 130 % con las descripciones largas), cede el nombre decorativo
	var limit := _nm_box.position.y - 6.0
	var ph := _panel.get_combined_minimum_size().y
	var nl := _panel.get_node_or_null("MuseName") as Label
	if nl != null:
		var fs := nl.get_theme_font_size("font_size")
		while fs > 60 and PANEL_MIN_Y + ph > limit:
			fs -= 4
			nl.add_theme_font_size_override("font_size", fs)
			ph = _panel.get_combined_minimum_size().y
	_panel.position.y = clampf(limit - ph, PANEL_MIN_Y, PANEL_Y)
	_panel.size.y = 0.0


## La fila inferior (Volver · Modo fácil · Semilla · Comenzar) tiene que caber en 1200 px: con una semilla
## larga o el texto al 130 % pedía hasta 1340 y «Comenzar» se salía por la derecha. Cede primero el texto de la
## semilla (hasta 6 letras + «…»), luego la fuente de «Modo fácil» y la de la semilla (hasta 14).
func _fit_bottom() -> void:
	if _bot == null or _sd == null or not is_instance_valid(_sd) or not is_instance_valid(_cb):
		return
	var guard := 0
	while _bot.get_combined_minimum_size().x > BOT_W and guard < 24:
		guard += 1
		if _seed_max > 6 and (seed_txt.length() > _seed_max):
			_seed_max -= 2
			_sd.text = _seed_label()
		elif _cb.get_theme_font_size("font_size") > 14:
			_cb_fs = _cb.get_theme_font_size("font_size") - 2
			_cb.add_theme_font_size_override("font_size", _cb_fs)
		elif _sd.get_theme_font_size("font_size") > 14:
			_sd_fs = _sd.get_theme_font_size("font_size") - 2
			_sd.set_meta("fit_base", _sd_fs)
			_sd.add_theme_font_size_override("font_size", _sd_fs)
		else:
			break
		_bot.update_minimum_size()


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
	for c in _panel.get_children():   # fuera ya del árbol: si no, la ficha vieja cuenta en el alto de la nueva
		_panel.remove_child(c)
		c.queue_free()
	var glow := Color(m.glow)
	if m.implemented:
		var r: Dictionary = DB.relics[m.startRelic]
		_panel.add_child(UIK.label(m.role, 20, UIK.GOLD))
		var nm_l := UIK.label(m.name, 92, Color.WHITE, "title")
		nm_l.name = "MuseName"
		nm_l.add_theme_font_size_override("font_size", 92)   # rótulo decorativo: no crece con el tamaño de texto
		nm_l.custom_minimum_size = Vector2(520, 0)
		nm_l.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		nm_l.add_theme_color_override("font_shadow_color", Color(glow, 0.6))
		nm_l.add_theme_constant_override("shadow_offset_y", 0)
		UIK.outlined(nm_l, 10, Color(0, 0, 0, 0.7))
		_panel.add_child(nm_l)
		var stats := UIK.rich("%s %s      %s 99" % [Icons.bb("ui", "hp", 24), tr("%d PV") % m.hp, Icons.bb("ui", "gold", 24)], 20, Color("#ffd8da"))
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
		d.custom_minimum_size = Vector2(600, 0)
		pc.add_child(d)
		_panel.add_child(pc)
		var rr := UIK.rich("%s [b][color=#f0cf7a]%s[/color][/b]: %s" % [Icons.bb("relic", m.startRelic, 30), r.n, r.d], 16, UIK.DIM)
		rr.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rr.custom_minimum_size = Vector2(600, 0)
		_panel.add_child(rr)
	else:
		_panel.add_child(UIK.label(tr("Próximamente"), 20, UIK.GOLD))
		var nm2 := UIK.label(m.name, 92, Color.WHITE, "title")
		nm2.add_theme_font_size_override("font_size", 92)
		nm2.custom_minimum_size = Vector2(520, 0)
		_panel.add_child(nm2)
		_panel.add_child(UIK.label(tr("Esta musa aún no está disponible."), 18, Color("#ece6ff")))
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
	var had := _focused_text_in(_nm_box)   # ◀/▶ con el mando: el botón se rehace y el foco no se pierde
	for c in _nm_box.get_children():
		_nm_box.remove_child(c)
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
		var lab := UIK.label(tr("Pesadilla %d") % nm if nm > 0 else tr("Pesadilla: apagada"), 20, Color("#caa5ff"), "bold")
		dn.pressed.connect(func(): nm = maxi(0, nm - 1); _render_nm(); _render_toggle())
		up.pressed.connect(func(): nm = mini(nm_max, nm + 1); _render_nm(); _render_toggle())
		st.add_child(dn)
		st.add_child(lab)
		st.add_child(up)
		_nm_box.add_child(st)
		# ◀ ↔ ▶ (el rótulo de en medio no es enfocable: sin esto ◀ quedaba fuera del alcance del D-Pad) y ↓ a
		# los avatares
		dn.focus_neighbor_right = up.get_path()
		up.focus_neighbor_left = dn.get_path()
		for x in [dn, up]:
			(x as Control).focus_neighbor_bottom = _avatars[pick].get_path()
		var fx := ("[b]%s[/b] %s%s" % [tr("Nv.%d") % nm, DB.nm_texts[nm], (" [i]%s[/i]" % tr("(y los niveles anteriores)")) if nm > 1 else ""]) if nm > 0 else tr("Nivel disponible para %s: hasta %d.") % [m.name, nm_max]
		var r := UIK.rich(fx, 17, Color("#ece6ff"))
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(640, 0)
		_nm_box.add_child(r)
	else:
		var no_nm := UIK.label(tr("Termina el juego con %s para desbloquear su Pesadilla") % m.name, 16, UIK.DIM)
		no_nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		no_nm.custom_minimum_size = Vector2(640, 0)
		_nm_box.add_child(no_nm)
	_refocus_in(_nm_box, had)


func _render_toggle() -> void:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	var had_cb := f != null and f == _cb
	var had_sd := f != null and f == _sd
	for c in _mid.get_children():
		_mid.remove_child(c)
		c.queue_free()
	var cb := CheckButton.new()
	cb.text = tr("Modo fácil")
	cb.button_pressed = easy and nm == 0
	cb.disabled = nm > 0
	cb.add_theme_font_override("font", UIK.font("bold"))
	cb.add_theme_font_size_override("font_size", _cb_fs if _cb_fs > 0 else UIK.ts(20))
	if cb.disabled:
		cb.focus_mode = Control.FOCUS_NONE   # con Pesadilla no se puede activar: el mando no se para en él
	cb.toggled.connect(func(p): easy = p; Meta.settings.easy = p; Meta.save_settings(); Sfx.play("select"))
	UIK.tip(cb, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [tr("Modo fácil"), tr("Más vida, enemigos más débiles y puedes deshacer la última carta jugada. No se combina con la Pesadilla.")])
	_mid.add_child(cb)
	var sd := UIK.button(_seed_label(), "small")
	sd.set_meta("fit_base", 16)
	if _sd_fs > 0:   # la fila ya tuvo que encoger esta fuente: el botón nuevo nace igual
		sd.set_meta("fit_base", _sd_fs)
		sd.add_theme_font_size_override("font_size", _sd_fs)
	sd.pressed.connect(func():
		var t = await Dlg.text_input(tr("Semilla"), tr("Escribe un número o una palabra para repetir los mismos mapas (por ejemplo, la semilla de una partida de un amigo). Déjalo vacío para una partida aleatoria."), seed_txt, tr("aleatoria"))
		if t != null:
			seed_txt = str(t).strip_edges()
			_render_toggle()
			_sd.grab_focus.call_deferred())   # el botón viejo (al que el diálogo devolvería el foco) ya no existe
	UIK.tip(sd, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [tr("Semilla"), tr("La misma semilla genera los mismos mapas en los tres actos.")])
	_mid.add_child(sd)
	_cb = cb
	_sd = sd
	_bottom_first = sd if cb.disabled else cb
	_bottom_last = sd
	_wire_bottom()
	_place_rows.call_deferred()
	if had_sd:
		sd.grab_focus()
	elif had_cb:
		(cb if not cb.disabled else sd).grab_focus()


## Texto del botón de `box` que tiene el foco (para recuperarlo tras rehacer `box`); "" si el foco está fuera.
func _focused_text_in(box: Control) -> String:
	var f := get_viewport().gui_get_focus_owner() if is_inside_tree() else null
	return (f as Button).text if f is Button and box.is_ancestor_of(f) else ""


func _refocus_in(box: Control, text: String) -> void:
	if text == "":
		return
	for b in box.find_children("*", "Button", true, false):
		if (b as Button).text == text and (b as Control).focus_mode != Control.FOCUS_NONE:
			(b as Control).grab_focus()
			return


## Texto del botón de semilla: una semilla escrita a mano puede ser larga; se recorta para que el botón siga
## siendo «small» y quepa junto a «Modo fácil» y «Comenzar».
func _seed_label() -> String:
	var s := seed_txt if seed_txt != "" else tr("aleatoria")
	if s.length() > _seed_max:
		s = s.left(_seed_max - 2) + "…"
	return tr("Semilla: %s") % s


## Fila inferior para el mando: avatares ↓ Volver ↔ Modo fácil ↔ Semilla ↔ Comenzar (en ese orden; antes
## «Modo fácil» → derecha no tenía vecino y la búsqueda geométrica subía a los avatares: Semilla y Comenzar
## no se alcanzaban). Con Pesadilla «Modo fácil» está apagado y se salta.
func _wire_bottom() -> void:
	if _back == null or _go == null or _bottom_first == null:
		return
	_back.focus_neighbor_right = _bottom_first.get_path()
	_bottom_first.focus_neighbor_left = _back.get_path()
	if _bottom_first != _bottom_last:
		_bottom_first.focus_neighbor_right = _bottom_last.get_path()
		_bottom_last.focus_neighbor_left = _bottom_first.get_path()
	_bottom_last.focus_neighbor_right = _go.get_path()
	_go.focus_neighbor_left = _bottom_last.get_path()
	for b in [_back, _bottom_first, _bottom_last, _go]:
		(b as Control).focus_neighbor_top = _avatars[pick].get_path()
	for b in _avatars.values():
		(b as Button).focus_neighbor_bottom = _bottom_first.get_path()
