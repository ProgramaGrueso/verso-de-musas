class_name CardView
extends Control
## Vista de una carta (arte, coste, nombre, tipo y texto con BBCode). Tamaño base 168×239.

signal pressed(view)
signal hovered(view, on)

const BASE_W := 168.0
const TYPE_COL := {"attack": "#8e2430", "skill": "#25598f", "power": "#7a4bc0", "status": "#555555", "curse": "#555555"}
const RAR_COL := {"uncommon": "#6cb8ff", "rare": "#ffd166", "common": "#9a94ad", "starter": "#9a94ad", "token": "#9a94ad", "special": "#9a94ad"}

var inst: Dictionary
var C = null
var w := BASE_W
var s := 1.0
var show_tip := true
var num_key := 0
var playable := true
var afford := true
var selected := false
var hover_scale := 1.32

var _art: TextureRect
var _ph: Label
var _cost: Label
var _cost_bg: Panel
var _name: Label
var _type_band: Panel
var _type_lbl: Label
var _txt: RichTextLabel
var _txt_box: VBoxContainer
var _frame: Panel
var _kws: Array = []
var _dim: ColorRect
var _num: Label
var _text_sig := ""   # firma de lo que hay pintado en el texto/coste (para no repintar en vano)
var _fit_busy := false   # ajuste de texto en vuelo (se coalescen los repintados que caen en ese fotograma)
var _fit_again := false
var _fit_for := ""        # texto para el que ya se ajustó el cuerpo (mismo texto = no se vuelve a medir)
var _style_key := {}      # panel -> clave del último estilo puesto (poner otro StyleBox notifica cambio de tema y
                          # vuelve a maquetar las etiquetas hijas: solo se cambia si el estilo es otro)
## Ajuste del cuerpo ya medido: «texto|ancho|alto|lo|hi» -> tamaño de fuente. El resultado solo depende de eso
## (las fuentes son fijas), y la mano repite mucho las mismas cartas: así no se crea la sonda otra vez.
static var _fit_cache := {}
## Época de repintado: el tablero de combate la sube cuando avanzan los efectos de las cartas (un estado, daño,
## energía); las cartas que no se vuelven a subir (ni el hover cambia) solo repintan entonces, no en cada mano.
static var card_refresh_epoch := 0


static func create(p_inst: Dictionary, p_C = null, p_w: float = BASE_W, tip: bool = true) -> CardView:
	var v := CardView.new()
	v.inst = p_inst
	v.C = p_C
	v.w = p_w
	v.s = p_w / BASE_W
	v.show_tip = tip
	v._build()
	return v


func _grad(stops: Array) -> GradientTexture2D:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cols := PackedColorArray()
	for st in stops:
		offs.append(st[0])
		cols.append(st[1])
	g.offsets = offs
	g.colors = cols
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill_from = Vector2(0, 0)
	t.fill_to = Vector2(0, 1)
	t.width = 4
	t.height = 64
	return t


func _build() -> void:
	var _pt := UIK.prof_t()
	var d := Eng.card_def(inst)
	custom_minimum_size = Vector2(w, w * 1.42)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	var h := size.y
	var bg := Panel.new()
	bg.add_theme_stylebox_override("panel", UIK.stylebox(Color("#1a1424"), Color("#1a1228"), int(3 * s), int(12 * s), 0))
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bg.size = size
	add_child(bg)
	var clip := Control.new()
	clip.clip_contents = true
	clip.size = size
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(clip)
	# arte
	var art_h := h * 0.52
	var art_bg := ColorRect.new()
	art_bg.color = Color("#2a2038")
	art_bg.size = Vector2(w, art_h)
	art_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art_bg)
	var key: String = d.img if d.has("img") else "card_" + d.id
	var t := UIK.tex("res://assets/cards/%s.webp" % key)
	# marcador de posición (emoji del tipo) SOLO si la carta no tiene arte: antes se creaba siempre y se ocultaba,
	# y maquetar una etiqueta de emoji de 56 px cuesta ~4-8 ms (fuente de color de reserva): era casi todo el
	# coste de crear una carta y el tirón de cada reparto (2 cartas por fotograma)
	if t == null:
		_ph = UIK.label(CardText.TYPE_EMO[d.type], int(56 * s), Color(1, 1, 1, 0.85), "sans", HORIZONTAL_ALIGNMENT_CENTER)
		_ph.size = Vector2(w, art_h)
		_ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		clip.add_child(_ph)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.size = Vector2(w, art_h)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if t != null:
		_art.texture = t
	clip.add_child(_art)
	var shade := TextureRect.new()
	shade.texture = _grad([[0.0, Color(0, 0, 0, 0.53)], [0.3, Color(0, 0, 0, 0)], [0.7, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.67)]])
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(w, art_h)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(shade)
	# caja de texto (empieza donde acaba la banda de tipo, así el texto nunca se cuela debajo de ella)
	var title_h := 36 * s
	var band_h := maxf(17 * s, UIK.font("bold").get_height(int(11 * s)) + 2.0)
	var band_top := art_h + title_h - 4 * s
	var box_top := band_top + band_h - 2 * s
	var tbg := TextureRect.new()
	tbg.texture = _grad([[0.0, Color("#2a2238")], [1.0, Color("#1b1526")]])
	tbg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tbg.stretch_mode = TextureRect.STRETCH_SCALE
	tbg.position = Vector2(0, box_top)
	tbg.size = Vector2(w, h - box_top)
	tbg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(tbg)
	_txt_box = VBoxContainer.new()
	_txt_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_txt_box.position = Vector2(7 * s, box_top + 3 * s)
	_txt_box.size = Vector2(w - 14 * s, h - box_top - 6 * (s + 1.0) - (18 * s if h - box_top > 26 * s else 0.0))
	_txt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_txt_box)
	_txt = UIK.rich("", maxi(11, int(13 * s)), Color("#f1ecff"))
	_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_txt.clip_contents = true   # el texto de la carta nunca asoma fuera de su caja
	_txt_box.add_child(_txt)
	# banda de tipo
	_type_band = Panel.new()
	_type_band.position = Vector2(0, band_top)
	_type_band.size = Vector2(w, band_h)
	_type_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_type_band)
	_type_lbl = UIK.label("", maxi(9, int(10 * s)), Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	_type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # la banda manda: nunca se sale de ella
	_type_band.add_child(_type_lbl)
	# nombre
	_name = UIK.label("", maxi(11, int(15 * s)), Color("#f1ecff"), "title", HORIZONTAL_ALIGNMENT_CENTER)
	_name.position = Vector2(30 * s, 5 * s)
	_name.size = Vector2(w - 58 * s, title_h)
	_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	UIK.outlined(_name, int(4 * s))
	clip.add_child(_name)
	# coste
	_cost_bg = Panel.new()
	_cost_bg.position = Vector2(-2 * s, -2 * s)
	_cost_bg.size = Vector2(38 * s, 38 * s)
	_cost_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_cost_bg)
	_cost = UIK.label("", int(22 * s), Color.WHITE, "title", HORIZONTAL_ALIGNMENT_CENTER)
	_cost.size = _cost_bg.size
	_cost.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIK.outlined(_cost, int(5 * s))
	_cost_bg.add_child(_cost)
	# marco de rareza
	_frame = Panel.new()
	_frame.size = size
	_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_frame)
	# atenuado (no jugable)
	_dim = ColorRect.new()
	_dim.color = Color(0, 0, 0, 0.5)
	_dim.size = size
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dim.visible = false
	add_child(_dim)
	_num = UIK.label("", int(14 * s), Color(1, 1, 1, 0.8), "bold", HORIZONTAL_ALIGNMENT_CENTER)
	var num_h := maxf(20 * s, UIK.font("bold").get_height(int(14 * s)) + 2.0)
	_num.position = Vector2(0, h - num_h - 1)
	_num.size = Vector2(w, num_h)
	add_child(_num)
	mouse_entered.connect(func(): hovered.emit(self, true))
	mouse_exited.connect(func(): hovered.emit(self, false))
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	if show_tip:
		UIK.tip(self, func(): return CardText.glossary_tip(_kws))
	refresh(C)
	UIK.prof_add("CardView._build", _pt)


func refresh(p_C = null) -> void:
	C = p_C
	_text_sig = ""   # repintado forzado (alta de la carta, hover, cambio de número…)
	set_text_once(p_C)


## Refresca texto y coste SOLO si cambió algo de lo que se ve: el nombre/los números calculados con los
## estados y, sobre todo, la energía (la carta enseña si puedes pagarla). Antes cada repintado de la mano
## (dos por jugada) reconstruía el RichTextLabel y los estilos de las 5-10 cartas: con los golpes encadenados
## de Irene eran decenas de re-rasterizaciones de texto por turno y el fotograma de ~10-20 ms al llenar la mano.
func set_text_once(p_C = null) -> void:
	var _pt := UIK.prof_t()
	if p_C != null:
		C = p_C
	var d: Dictionary = Eng.card_def(inst)
	var cost := 0
	var energy := -1
	if C != null:
		cost = C.energy if Eng.is_x(d.cost) else int(Eng.eff_cost(C, d))
		energy = int(C.energy)
	else:
		cost = int(d.cost)
	var sig := "%s|%d|%d|%d" % [d.name, cost, energy, card_refresh_epoch]
	if sig == _text_sig:
		UIK.prof_add("CardView.set_text_once", _pt)
		return
	_text_sig = sig
	_refresh_text(d, cost)
	UIK.prof_add("CardView.set_text_once", _pt)


## Pinta texto, nombre, tipo y coste con un coste ya calculado.
func _refresh_text(d: Dictionary, cost: int) -> void:
	var _pt := UIK.prof_t()
	var res := CardText.lines(d, C)
	_kws = res.kws
	var body: String = "[center]" + "\n".join(res.lines) + "[/center]"
	# mismo texto ya ajustado: no se toca (antes se volvía a poner el tamaño base y se re-medía, y cada cambio de
	# tamaño de fuente re-maquetaba el RichTextLabel dos veces por repintado aunque no cambiara nada)
	var same_body := body == _txt.text and body == _fit_for and not _fit_busy
	var fit_known := 0
	if not same_body:
		_txt.text = body
		# texto ya medido antes en una caja igual (la carta ya está maquetada): se pone su tamaño directamente
		fit_known = int(_fit_cache.get(_fit_key(body), 0)) if _fit_for != "" and not _fit_busy else 0
		if fit_known > 0:
			_set_body_fs(fit_known)
			_fit_for = body
		else:
			# en cartas estrechas (tienda: 142 y 112 px) el texto baja hasta 9 px sin salirse de la caja de texto
			_set_body_fs(maxi(_fit_lo(), int(13 * s)))   # en cartas de 112 px, 8 px de cuerpo
	if _name.text != d.name:
		_name.text = d.name
		_fit_name()
	var name_col := Color("#8dff9d") if inst.up else Color("#f1ecff")
	if not _name.has_theme_color_override("font_color") or _name.get_theme_color("font_color") != name_col:
		_name.add_theme_color_override("font_color", name_col)
	_type_lbl.text = CardText.TYPE_ES[d.type].to_upper()
	if _style_key.get(_type_band) != d.type:
		_style_key[_type_band] = d.type
		_type_band.add_theme_stylebox_override("panel", UIK.stylebox(Color(TYPE_COL[d.type]), Color(0, 0, 0, 0), 0, 0, 0))
	var cost_txt: String
	if Eng.is_x(d.cost):
		cost_txt = "X"
	elif d.cost == -1:
		cost_txt = "–"
	else:
		cost_txt = str(cost)
	if _cost.text != cost_txt:
		_cost.text = cost_txt
	# el estilo del coste lo fija set_state (en combate se llama justo después); fuera de combate afford es true
	# (= el estilo «se puede pagar» que se ponía aquí siempre). Con el estado vigente no hay un cambio de ida y
	# vuelta del StyleBox (y de la etiqueta del coste) en cada repintado de una carta que no puedes pagar.
	_set_cost_style(_unaffordable())
	_apply_frame()
	_num.text = str(num_key) if num_key > 0 else ""
	if not same_body and fit_known == 0:
		_fit_text.call_deferred()
	UIK.prof_add("CardView._refresh_text", _pt)


func _apply_frame(focused: bool = false) -> void:
	var d := Eng.card_def(inst)
	var rc := Color(RAR_COL.get(d.rarity, "#9a94ad"))
	var hot: bool = selected or focused or has_focus()
	var key := "hot" if hot else str(rc)
	if _style_key.get(_frame) == key:
		return
	_style_key[_frame] = key
	var fs: StyleBoxFlat
	if hot:
		fs = UIK.stylebox(Color(0, 0, 0, 0), Color.WHITE, int(5 * s), int(10 * s), 0)
	else:
		fs = UIK.stylebox(Color(0, 0, 0, 0), rc, int(3 * s), int(10 * s), 0)
	_frame.add_theme_stylebox_override("panel", fs)


func _on_focus_entered() -> void:
	hovered.emit(self, true)
	_apply_frame(true)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(1.08, 1.08), 0.1).set_trans(Tween.TRANS_SINE)
	z_index = 50
	_is_sfx("select_soft", 0.4)


## Sonido opcional: al cargar la clase (antes de que arranquen los autoloads) `Sfx` aún no existe.
func _is_sfx(name: String, v: float) -> void:
	var s = get_node_or_null("/root/Sfx")
	if s != null:
		s.play(name, v)


func _on_focus_exited() -> void:
	hovered.emit(self, false)
	_apply_frame(false)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.1).set_trans(Tween.TRANS_SINE)
	z_index = 0


func set_selected(on: bool) -> void:
	var _pt := UIK.prof_t()
	selected = on
	_apply_frame()
	UIK.prof_add("CardView.set_selected", _pt)


func _fit_name() -> void:
	# reduce la fuente hasta que el nombre quepa en las dos líneas de la cabecera (sin partirse por letras)
	var avail := _name.size.x
	var f := _name.get_theme_font("font")
	var base := maxi(9, int(15 * s))
	var lo := 9
	var fs := base
	while fs > lo and not _name_fits(f, fs, avail):
		fs -= 1
	if fs != int(_name.get_theme_font_size("font_size")):
		_name.add_theme_font_size_override("font_size", fs)


func _name_fits(f: Font, fs: int, avail: float) -> bool:
	var lines := 1
	var left := avail
	var space := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for word in _name.text.split(" "):
		var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		if ww > avail:
			return false   # una sola palabra más ancha que la columna
		if ww > left:
			lines += 1
			left = avail - ww
		else:
			left -= ww + space
	return lines * f.get_height(fs) <= _name.size.y and lines <= 2


func _set_cost_style(unaffordable: bool) -> void:
	if _style_key.get(_cost_bg) == unaffordable:
		return
	_style_key[_cost_bg] = unaffordable
	var col := Color("#d97d0f") if not unaffordable else Color("#b01010")
	_cost_bg.add_theme_stylebox_override("panel", UIK.stylebox(col, Color("#fff3c4"), int(3 * s), int(19 * s), 0))


## Ajusta el cuerpo del texto a la caja. Mide con la curva completa de una vez (antes bajaba de píxel en
## píxel esperando un fotograma por paso: al llenarse la mano eso caía en cascada sobre el mismo fotograma y
## con las cifras encadenadas de Irene era el pico de ~10-20 ms). La medición usa una copia fuera de pantalla
## (Rect (0,0,0,0)) para no recolocar el texto de verdad.
func _fit_text() -> void:
	if not is_inside_tree():
		return
	if _fit_busy:
		_fit_again = true   # quedó un ajuste en vuelo: al terminar, repite con el texto nuevo
		return
	_fit_busy = true
	await get_tree().process_frame
	while is_instance_valid(_txt):
		var _pt := UIK.prof_t()
		_fit_again = false
		var avail := _txt_box.size.y
		var lo := _fit_lo()
		var hi := maxi(lo, int(13 * s))
		var ck := _fit_key(_txt.text)
		var fs := int(_fit_cache.get(ck, 0))
		if fs == 0:
			var probe := RichTextLabel.new()
			probe.bbcode_enabled = true
			probe.fit_content = true
			probe.scroll_active = false
			probe.autowrap_mode = _txt.autowrap_mode
			probe.clip_contents = true
			probe.size = Vector2(_txt.size.x, 0.0)
			probe.add_theme_font_override("normal_font", _txt.get_theme_font("normal_font"))
			probe.add_theme_font_override("bold_font", _txt.get_theme_font("bold_font"))
			probe.add_theme_font_size_override("normal_font_size", hi)
			probe.add_theme_font_size_override("bold_font_size", hi)
			probe.text = _txt.text
			add_child(probe)
			var fits := func(sz: int) -> bool:
				probe.add_theme_font_size_override("normal_font_size", sz)
				probe.add_theme_font_size_override("bold_font_size", sz)
				return probe.get_content_height() <= avail
			fs = lo
			if fits.call(hi):
				fs = hi
			else:
				var a := lo
				var b := hi
				while b - a > 1:   # bisección: ~4 medidas en vez de hasta 6 fotogramas
					var m := (a + b) / 2
					if fits.call(m):
						a = m
					else:
						b = m
				fs = a
			probe.queue_free()
			if _fit_cache.size() > 4000:
				_fit_cache.clear()
			_fit_cache[ck] = fs
		_set_body_fs(fs)
		_fit_for = _txt.text
		UIK.prof_add("CardView._fit_text", _pt)
		if not _fit_again:
			break
		await get_tree().process_frame
	_fit_busy = false


func _fit_lo() -> int:
	return 8 if w < 130.0 else 9


## Clave del ajuste del cuerpo: el resultado depende solo del texto y de la caja (las fuentes son fijas).
func _fit_key(body: String) -> String:
	return "%s|%.1f|%.1f|%d|%d" % [body, _txt.size.x, _txt_box.size.y, _fit_lo(), maxi(_fit_lo(), int(13 * s))]


## Tamaño del cuerpo (solo si cambia: cada override nuevo vuelve a maquetar el RichTextLabel).
func _set_body_fs(fs: int) -> void:
	if not _txt.has_theme_font_size_override("normal_font_size") or _txt.get_theme_font_size("normal_font_size") != fs:
		_txt.add_theme_font_size_override("normal_font_size", fs)
	if not _txt.has_theme_font_size_override("bold_font_size") or _txt.get_theme_font_size("bold_font_size") != fs:
		_txt.add_theme_font_size_override("bold_font_size", fs)


func set_state(p_playable: bool, p_afford: bool) -> void:
	var _pt := UIK.prof_t()
	playable = p_playable
	afford = p_afford
	_dim.visible = not playable
	_set_cost_style(_unaffordable())
	UIK.prof_add("CardView.set_state", _pt)


## Coste en rojo: no te llega la energía (las de coste X y las injugables «–» nunca).
func _unaffordable() -> bool:
	var d := Eng.card_def(inst)
	return not afford and not Eng.is_x(d.cost) and d.cost >= 0


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton:
		var mb := ev as InputEventMouseButton
		if mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
			pressed.emit(self)
			accept_event()
	elif ev is InputEventJoypadButton:
		var jb := ev as InputEventJoypadButton
		if jb.pressed and jb.button_index == JOY_BUTTON_A:
			pressed.emit(self)
			accept_event()
	elif ev.is_action_pressed("ui_accept"):
		pressed.emit(self)
		accept_event()
