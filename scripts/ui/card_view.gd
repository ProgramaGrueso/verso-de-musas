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
	var d := Eng.card_def(inst)
	custom_minimum_size = Vector2(w, w * 1.42)
	size = custom_minimum_size
	pivot_offset = size / 2.0
	mouse_filter = Control.MOUSE_FILTER_STOP
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
	_ph = UIK.label(CardText.TYPE_EMO[d.type], int(56 * s), Color(1, 1, 1, 0.85), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	_ph.size = Vector2(w, art_h)
	_ph.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	clip.add_child(_ph)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	_art.size = Vector2(w, art_h)
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var key: String = d.img if d.has("img") else "card_" + d.id
	var t := UIK.tex("res://assets/cards/%s.webp" % key)
	if t != null:
		_art.texture = t
		_ph.visible = false
	clip.add_child(_art)
	var shade := TextureRect.new()
	shade.texture = _grad([[0.0, Color(0, 0, 0, 0.53)], [0.3, Color(0, 0, 0, 0)], [0.7, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.67)]])
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.size = Vector2(w, art_h)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(shade)
	# caja de texto
	var box_top := art_h + 9 * s
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
	_txt_box.position = Vector2(7 * s, box_top + 4 * s)
	_txt_box.size = Vector2(w - 14 * s, h - box_top - 8 * s)
	_txt_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_txt_box)
	_txt = UIK.rich("", int(13 * s), Color("#f1ecff"))
	_txt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_txt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_txt_box.add_child(_txt)
	# banda de tipo
	_type_band = Panel.new()
	_type_band.position = Vector2(0, art_h - 9 * s)
	_type_band.size = Vector2(w, 18 * s)
	_type_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(_type_band)
	_type_lbl = UIK.label("", int(11 * s), Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	_type_lbl.size = Vector2(w, 18 * s)
	_type_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_type_band.add_child(_type_lbl)
	# nombre
	_name = UIK.label("", int(15 * s), Color("#f1ecff"), "title", HORIZONTAL_ALIGNMENT_CENTER)
	_name.position = Vector2(36 * s, 5 * s)
	_name.size = Vector2(w - 72 * s, 34 * s)
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
	_num.position = Vector2(0, h - 22 * s)
	_num.size = Vector2(w, 20 * s)
	add_child(_num)
	mouse_entered.connect(func(): hovered.emit(self, true))
	mouse_exited.connect(func(): hovered.emit(self, false))
	if show_tip:
		UIK.tip(self, func(): return CardText.glossary_tip(_kws))
	refresh(C)


func refresh(p_C = null) -> void:
	C = p_C
	var d := Eng.card_def(inst)
	var res := CardText.lines(d, C)
	_kws = res.kws
	_txt.text = "[center]" + "\n".join(res.lines) + "[/center]"
	_txt.add_theme_font_size_override("normal_font_size", int(13 * s))
	_txt.add_theme_font_size_override("bold_font_size", int(13 * s))
	_name.text = d.name
	_fit_name()
	_name.add_theme_color_override("font_color", Color("#8dff9d") if inst.up else Color("#f1ecff"))
	_type_lbl.text = CardText.TYPE_ES[d.type].to_upper()
	_type_band.add_theme_stylebox_override("panel", UIK.stylebox(Color(TYPE_COL[d.type]), Color(0, 0, 0, 0), 0, 0, 0))
	var cost_txt: String
	if Eng.is_x(d.cost):
		cost_txt = "X"
	elif d.cost == -1:
		cost_txt = "–"
	else:
		cost_txt = str(Eng.eff_cost(C, d) if C != null else d.cost)
	_cost.text = cost_txt
	_set_cost_style(false)
	_apply_frame()
	_num.text = str(num_key) if num_key > 0 else ""
	_fit_text.call_deferred()


func _apply_frame() -> void:
	var d := Eng.card_def(inst)
	var rc := Color(RAR_COL.get(d.rarity, "#9a94ad"))
	var fs: StyleBoxFlat
	if selected:
		fs = UIK.stylebox(Color(0, 0, 0, 0), Color.WHITE, int(5 * s), int(10 * s), 0)
	else:
		fs = UIK.stylebox(Color(0, 0, 0, 0), rc, int(3 * s), int(10 * s), 0)
	_frame.add_theme_stylebox_override("panel", fs)


func set_selected(on: bool) -> void:
	selected = on
	_apply_frame()


func _fit_name() -> void:
	# reduce la fuente hasta que la palabra más larga quepa sin partirse
	var avail := _name.size.x
	var f := _name.get_theme_font("font")
	var fs := int(15 * s)
	var longest := 0.0
	for w in _name.text.split(" "):
		longest = maxf(longest, f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	while longest > avail and fs > int(9 * s):
		fs -= 1
		longest = 0.0
		for w in _name.text.split(" "):
			longest = maxf(longest, f.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	_name.add_theme_font_size_override("font_size", fs)


func _set_cost_style(unaffordable: bool) -> void:
	var col := Color("#d97d0f") if not unaffordable else Color("#b01010")
	_cost_bg.add_theme_stylebox_override("panel", UIK.stylebox(col, Color("#fff3c4"), int(3 * s), int(19 * s), 0))


func _fit_text() -> void:
	if not is_inside_tree():
		return
	await get_tree().process_frame
	if not is_instance_valid(_txt):
		return
	var avail := _txt_box.size.y
	var fs := int(13 * s)
	var guard := 0
	while _txt.get_content_height() > avail and fs > int(8 * s) and guard < 6:
		fs -= 1
		guard += 1
		_txt.add_theme_font_size_override("normal_font_size", fs)
		_txt.add_theme_font_size_override("bold_font_size", fs)
		await get_tree().process_frame
		if not is_instance_valid(_txt):
			return


func set_state(p_playable: bool, p_afford: bool) -> void:
	playable = p_playable
	afford = p_afford
	_dim.visible = not playable
	_set_cost_style(not afford and not Eng.is_x(Eng.card_def(inst).cost) and Eng.card_def(inst).cost >= 0)


func _gui_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		pressed.emit(self)
		accept_event()
