class_name UIK
extends RefCounted
## Utilidades de interfaz: fuentes, estilos, botones, etiquetas y tooltips.

const GOLD := Color("#f0cf7a")
const TEXT := Color("#f1ecff")
const DIM := Color("#a79fc0")
const BG := Color("#0c0a12")
const PANEL := Color("#1a1626")
const RED := Color("#ff6b75")
const GREEN := Color("#8bf0a4")

static var _fonts := {}


static func font(kind: String = "sans") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var emoji: Font = load("res://assets/fonts/NotoColorEmoji.ttf")
	var base: Font
	match kind:
		"title":
			var v := FontVariation.new()
			v.base_font = load("res://assets/fonts/Cinzel.ttf")
			v.variation_embolden = 0.9
			base = v
		"bold":
			base = load("res://assets/fonts/NotoSans-Bold.ttf")
		_:
			base = load("res://assets/fonts/NotoSans-Regular.ttf")
	var fv := FontVariation.new()
	fv.base_font = base
	fv.fallbacks = [emoji]
	_fonts[kind] = fv
	return fv


static func stylebox(bg: Color, border: Color = Color(0, 0, 0, 0), bw: int = 0, radius: int = 12, shadow: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = border
	s.set_border_width_all(bw)
	s.set_corner_radius_all(radius)
	if shadow > 0:
		s.shadow_size = shadow
		s.shadow_color = Color(0, 0, 0, 0.6)
		s.shadow_offset = Vector2(0, 3)
	return s


static func label(text: String = "", size: int = 20, color: Color = TEXT, kind: String = "sans", align: int = HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


static func outlined(l: Label, outline: int = 4, color: Color = Color.BLACK) -> Label:
	l.add_theme_constant_override("outline_size", outline)
	l.add_theme_color_override("font_outline_color", color)
	return l


static func rich(bbcode: String, size: int = 18, color: Color = TEXT, kind: String = "sans") -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.scroll_active = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	r.add_theme_font_override("normal_font", font(kind))
	r.add_theme_font_override("bold_font", font("bold"))
	r.add_theme_font_size_override("normal_font_size", size)
	r.add_theme_font_size_override("bold_font_size", size)
	r.add_theme_color_override("default_color", color)
	r.text = bbcode
	return r


## Botón con el estilo del juego. kind: "", "green", "red", "small", "big"
static func button(text: String, kind: String = "", size: int = 24) -> Button:
	var b := Button.new()
	b.text = text
	b.focus_mode = Control.FOCUS_ALL
	b.add_theme_font_override("font", font("bold"))
	var bg := Color("#33284f")
	var bd := GOLD
	var fc := GOLD
	if kind.contains("green"):
		bg = Color("#1f5230"); bd = GREEN; fc = Color("#d5ffe0")
	elif kind.contains("red"):
		bg = Color("#5f1c26"); bd = Color("#ff7b85"); fc = Color("#ffd3d6")
	var fs := size
	var padx := 28
	var pady := 12
	if kind.contains("big"):
		fs = 30; padx = 40; pady = 16
	elif kind.contains("small"):
		fs = 16; padx = 14; pady = 6
	b.add_theme_font_size_override("font_size", fs)
	b.add_theme_color_override("font_color", fc)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(fc, 0.45))
	var bw := 1 if kind.contains("small") else 2
	var n := stylebox(bg, bd, bw, 12, 4)
	var h := stylebox(bg.lightened(0.18), bd.lightened(0.3), bw, 12, 8)
	var p := stylebox(bg.darkened(0.15), bd, bw, 12, 0)
	var d := stylebox(bg.darkened(0.3), Color(bd, 0.4), bw, 12, 0)
	for s in [n, h, p, d]:
		s.content_margin_left = padx; s.content_margin_right = padx
		s.content_margin_top = pady; s.content_margin_bottom = pady
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	b.add_theme_stylebox_override("focus", h)
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play("select_soft", 0.4))
	b.pressed.connect(func(): Sfx.play("click"))
	return b


static func panel(inner_margin: int = 24, radius: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var s := stylebox(Color("#1d1730"), GOLD, 2, radius, 20)
	s.content_margin_left = inner_margin; s.content_margin_right = inner_margin
	s.content_margin_top = inner_margin * 0.8; s.content_margin_bottom = inner_margin * 0.8
	p.add_theme_stylebox_override("panel", s)
	return p


static func tex(path: String) -> Texture2D:
	if ResourceLoader.exists(path):
		return load(path)
	return null


static func asset_exists(rel: String) -> bool:
	return ResourceLoader.exists("res://assets/" + rel)


static func fade_in(c: CanvasItem, t: float = 0.25) -> void:
	c.modulate.a = 0.0
	c.create_tween().tween_property(c, "modulate:a", 1.0, t)


static func full_rect(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


static func sleep(node: Node, secs: float) -> void:
	var f: float = 0.45 if Meta.settings.fast else 1.0
	await node.get_tree().create_timer(secs * f).timeout


# ---------- Tooltips ----------
## Asocia un tooltip (BBCode) a un control; text puede ser String o Callable que devuelve String.
static func tip(c: Control, text) -> void:
	c.set_meta("tip", text)
	if c.has_meta("tip_wired"):
		return
	c.set_meta("tip_wired", true)
	if c.mouse_filter == Control.MOUSE_FILTER_IGNORE:
		c.mouse_filter = Control.MOUSE_FILTER_PASS
	c.mouse_entered.connect(func(): Tip.show_for(c))
	c.mouse_exited.connect(func(): Tip.hide_for(c))
	c.tree_exiting.connect(func(): Tip.hide_for(c))


# ---------- Fondos ----------
const ACT_KEY := ["underdocks", "overgrowth", "hive"]
const ACT_GRAD := [["#0f3a40", "#05090d"], ["#143a1e", "#050a06"], ["#4a3508", "#0d0903"]]


static func grad_tex(stops: Array, horizontal: bool = false) -> GradientTexture2D:
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
	t.fill_to = Vector2(1, 0) if horizontal else Vector2(0, 1)
	t.width = 64 if horizontal else 4
	t.height = 4 if horizontal else 64
	return t


## Fondo de pantalla completa: imagen bg/<key>.webp (cubre) o degradado del acto.
static func backdrop(act: int, key: String = "") -> Control:
	var k: String = key if key != "" else ACT_KEY[clampi(act, 1, 3) - 1]
	var t := tex("res://assets/bg/%s.webp" % k)
	if t != null:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		full_rect(r)
		return r
	var g: Array = ACT_GRAD[clampi(act, 1, 3) - 1]
	var tr := TextureRect.new()
	tr.texture = grad_tex([[0.0, Color(g[0])], [1.0, Color(g[1])]])
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(tr)
	return tr


static func shade(a_top: float = 0.0, a_bot: float = 0.5) -> TextureRect:
	var r := TextureRect.new()
	r.texture = grad_tex([[0.0, Color(0, 0, 0, a_top)], [1.0, Color(0, 0, 0, a_bot)]])
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	full_rect(r)
	return r


static func center_col(parent: Control, sep: int = 16) -> VBoxContainer:
	var c := CenterContainer.new()
	full_rect(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	return v


## Chispas flotantes (brasas) de un color; se usan en título y selección.
static func embers(color: Color, count: int = 40) -> CPUParticles2D:
	var p := CPUParticles2D.new()
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for x in 16:
		for y in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, clampf(1.0 - d, 0.0, 1.0) ** 1.5))
	p.texture = ImageTexture.create_from_image(img)
	p.amount = count
	p.lifetime = 9.0
	p.preprocess = 9.0
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	p.emission_rect_extents = Vector2(660, 4)
	p.position = Vector2(640, 730)
	p.direction = Vector2(0.15, -1)
	p.spread = 14.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 40.0
	p.initial_velocity_max = 110.0
	p.scale_amount_min = 0.2
	p.scale_amount_max = 0.7
	p.color = Color(color, 0.8)
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	ramp.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0.6), Color(1, 1, 1, 0)])
	p.color_ramp = ramp
	return p
