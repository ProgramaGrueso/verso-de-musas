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
static var _watch := {}   # id -> [texto, tamaño]: último estado visto por el vigilante de los botones


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
	b.set_meta("uik", {"kind": kind})
	b.set_meta("fit_min0", b.custom_minimum_size.y)
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
	b.mouse_entered.connect(func(): if not b.disabled: _sfx(b, "select_soft", 0.4))
	b.pressed.connect(func(): _sfx(b, "click"))
	_auto_fit(b)
	return b


## Sonido de interfaz. Se busca el autoload desde el nodo (y no por el identificador `Sfx`) porque al cargar
## esta clase —la primera pantalla se construye durante el arranque— los autoloads aún no están registrados.
static func _sfx(from: Node, name: String, vol: float = 1.0) -> void:
	if from == null or not from.is_inside_tree():
		return
	var s := from.get_node_or_null("/root/Sfx")
	if s != null:
		s.play(name, vol)


static func panel(inner_margin: int = 24, radius: int = 16) -> PanelContainer:
	var p := PanelContainer.new()
	var s := stylebox(Color("#1d1730"), GOLD, 2, radius, 20)
	s.content_margin_left = inner_margin; s.content_margin_right = inner_margin
	s.content_margin_top = inner_margin * 0.8; s.content_margin_bottom = inner_margin * 0.8
	p.add_theme_stylebox_override("panel", s)
	return p


# ---------- Caja de texto de los botones ----------
## Regla: ningún botón debe tener texto (o icono + texto) más grande que su caja. `fit_button` mide el texto con la
## fuente real y, si no cabe en el rect que le deja el layout (contenedores incluidos), baja la fuente paso a paso
## hasta `FIT_MIN`; si ni así entra, lo parte en líneas y, en último caso, lo recorta con «…».
## Los botones de `UIK.button` se reajustan solos: al entrar en el árbol, al cambiar de tamaño y cuando cambia su texto.
const FIT_MIN := 12        # por debajo de esto el texto deja de leerse

static func _auto_fit(b: Button) -> void:
	if b.has_meta("fit_auto"):
		return
	b.set_meta("fit_auto", true)
	b.set_meta("fit_base", int(b.get_theme_font_size("font_size")))
	# El botón no tiene _process propio (el script es de UIK) y NO se le puede poner otro script (Godot lo rechaza
	# y rompería su clase), así que se registra en un vigilante único (WeakRef: no retiene botones muertos).
	_watched.append(weakref(b))
	b.resized.connect(func(): fit_button.call_deferred(b))
	b.tree_entered.connect(func():
		b.set_meta("fit_init", true)
		fit_button.call_deferred(b))


static var _watched: Array = []   # WeakRef a cada botón de UIK.button (el vigilante único los recorre)
static var _watch_tick := 0
const WATCH_EVERY := 3            # se vigila cada 3 fotogramas (~20 veces por segundo a 60 fps)


## Vigilante único: lo llama `_process` de Main cada fotograma; cada WATCH_EVERY fotogramas mira solo los botones
## cuyo texto o tamaño ha cambiado (una comparación de dos valores por botón: barato incluso con cientos).
static func watch_tick() -> void:
	_watch_tick += 1
	if _watch_tick % WATCH_EVERY != 0:
		return
	var keep := []
	for w in _watched:
		var b = w.get_ref()
		if b == null or not is_instance_valid(b):
			continue
		keep.append(w)
		# mirar el texto de un botón que aún no se ha dibujado hace que Godot rasterice su fuente ahí mismo
		# (tirón + RAM en cada cambio de pantalla): solo se vigila lo que está en pantalla de verdad
		if b.is_inside_tree() and b.is_visible_in_tree():
			_watch_fit(b)
	_watched = keep



## Vigilante: solo reajusta si el texto o el tamaño cambiaron respecto al fotograma anterior.
static func _watch_fit(b: Button) -> void:
	if b == null or not is_instance_valid(b):
		return
	var id := b.get_instance_id()
	var key := [b.text, b.size]
	if _watch.get(id, null) == key:
		return
	_watch[id] = key
	if b.get_meta("fit_init", false):
		fit_button(b)


## Reajusta `b` para que su texto quepa en su caja.
static func fit_button(b: Button, preserve_style: bool = false) -> void:
	if b == null or not is_instance_valid(b) or not b.is_inside_tree():
		return
	var base: int = b.get_meta("fit_base", int(b.get_theme_font_size("font_size")))
	var orig_wrap := b.autowrap_mode
	if b.text != "" and _btn_fits(b, int(b.get_theme_font_size("font_size")), orig_wrap) and b.get_theme_font_size("font_size") >= mini(base, FIT_MIN):
		pass   # ya cabe: no hay nada que reajustar (ni que pedir un relayout)
	elif b.text != "":
		var lo: int = base if preserve_style else mini(base, FIT_MIN)
		var fs := int(b.get_theme_font_size("font_size"))
		if fs > base or fs < lo:
			fs = base
		while fs > lo and not _btn_fits(b, fs, orig_wrap):
			fs -= 1
		if not _btn_fits(b, fs, orig_wrap):
			# partir en líneas: por palabras y, si no, letra a letra (solo si el alto lo permite)
			var wrap := orig_wrap
			for mode in [TextServer.AUTOWRAP_WORD_SMART, TextServer.AUTOWRAP_ARBITRARY]:
				if _btn_fits(b, fs, mode):
					wrap = mode
					break
			b.autowrap_mode = wrap
			if wrap == orig_wrap and not _btn_fits(b, fs, orig_wrap) and b.text_overrun_behavior == TextServer.OVERRUN_NO_TRIMMING:
				b.clip_text = true
				b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		else:
			b.autowrap_mode = orig_wrap
		if b.get_theme_font_size("font_size") != fs:
			b.add_theme_font_size_override("font_size", fs)
			b.update_minimum_size()
	# subir el alto mínimo cambia el layout (y eso puede reemitir `resized`): como mucho una vez por fotograma,
	# si no el mensaje de «tamaño mínimo cambiado» puede realimentarse y desbordar la cola de mensajes de Godot
	if _btn_fit_min(b) and b.get_parent() is Container and _once_this_frame(b):
		(b.get_parent() as Container).update_minimum_size()


## ¿El texto de `b` cabe en su caja con la fuente `fs`?
static func _btn_fits(b: Button, fs: int, wrap: int = -1) -> bool:
	var pad := b.get_theme_stylebox("normal").get_minimum_size()
	var w := b.size.x - pad.x - _icon_w(b)
	var h := b.size.y - pad.y
	if w <= 0.0 or h <= 0.0:
		return true   # aún sin layout: se reajusta cuando llegue el tamaño
	var f := b.get_theme_font("font")
	var mode := b.autowrap_mode if wrap < 0 else wrap
	if mode != TextServer.AUTOWRAP_OFF:
		if mode == TextServer.AUTOWRAP_WORD_SMART or mode == TextServer.AUTOWRAP_WORD:
			for word in b.text.split(" "):
				if f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > w:
					return false   # palara que no entra en una línea: AUTOWRAP_WORD no la parte
		return _wrap_lines(f, fs, b.text, w, mode) * f.get_height(fs) <= h
	var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	return tw <= w and b.text.split("\n").size() * f.get_height(fs) <= h


## Ancho que ocupa el icono del botón (incluida la separación con el texto).
static func _icon_w(b: Button) -> float:
	if b.icon == null:
		return 0.0
	var iwc: int = b.get_theme_constant("icon_max_width")
	return float(iwc if iwc > 0 else b.icon.get_width()) + b.get_theme_constant("h_separation")


## Ajusta la altura mínima del botón a las líneas que necesita su texto con el ancho disponible.
static func _btn_fit_min(b: Button) -> bool:
	var fs := b.get_theme_font_size("font_size")
	var f := b.get_theme_font("font")
	var pad := b.get_theme_stylebox("normal").get_minimum_size()
	var w := b.size.x - pad.x - _icon_w(b)
	var lines: float = b.text.split("\n").size()
	if b.autowrap_mode != TextServer.AUTOWRAP_OFF and w > 0.0:
		lines = maxf(lines, _wrap_lines(f, fs, b.text, w, b.autowrap_mode))
	var need := ceilf(lines * f.get_height(fs) + pad.y)
	var cur := b.custom_minimum_size.y
	if need > cur:
		b.custom_minimum_size.y = need
		return true
	elif b.has_meta("fit_min0") and need < cur:
		b.custom_minimum_size.y = maxf(b.get_meta("fit_min0"), need)
		return true
	return false


## Líneas que ocupa `text` con el autoajuste `mode` en un ancho `w`.
static func _wrap_lines(f: Font, fs: int, text: String, w: float, mode: int) -> int:
	var lines := 0
	var space := f.get_string_size(" ", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	for para in text.split("\n"):
		var n := 1
		var left := w
		for word in para.split(" "):
			var ww := f.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			if mode == TextServer.AUTOWRAP_ARBITRARY and ww > w:
				n += int(ceil(ww / w)) - 1
				left = w - fposmod(ww, w)
			elif ww > left:
				n += 1
				left = w - ww
			else:
				left -= ww + space
		lines += n
	return lines


## Ancho mínimo real que necesita un botón (texto con la fuente actual + márgenes del estilo + icono).
static func button_width(b: Button, fs: int = 0) -> float:
	var f := b.get_theme_font("font")
	var s := fs if fs > 0 else int(b.get_theme_font_size("font_size"))
	var w := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, s).x + b.get_theme_stylebox("normal").get_minimum_size().x
	return maxf(w + _icon_w(b), b.custom_minimum_size.x)


# ---------- Etiquetas y títulos ----------
## Etiqueta que se parte en líneas dentro de una columna estrecha (`min_px`) y, si aun así no cabe en su alto,
## encoge hasta `min_size`. Su ancho mínimo es `min_px`: nunca ensancha a su contenedor ni invade al de al lado.
static func wrap(label: Label, min_px: float = 0.0, min_size: int = 13) -> Label:
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	if min_px > 0.0:
		label.custom_minimum_size = Vector2(min_px, label.custom_minimum_size.y)
	label.set_meta("wrap_min_size", min_size)
	label.resized.connect(func(): fit_label.call_deferred(label))
	fit_label.call_deferred(label)
	return label


static var _frame_once := {}   # id -> nº de fotograma del último ajuste (evita bucles de relayout)

static func _once_this_frame(c: Control) -> bool:
	var id := c.get_instance_id()
	var f := Engine.get_process_frames()
	if _frame_once.get(id, -1) == f:
		return false
	_frame_once[id] = f
	return true


## Si el texto de una Label con ancho fijo no cabe (ni partido en líneas), baja la fuente hasta `min_size`.
## Como mucho se reajusta una vez por fotograma: cambiar la fuente cambia el mínimo y eso vuelve a emitir
## `resized`, así que sin este freno el layout podía entrar en bucle.
static func fit_label(l: Label, min_size: int = 0) -> void:
	if l == null or not is_instance_valid(l) or l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		return
	if not _once_this_frame(l):
		return
	var base: int = l.get_meta("fit_size", 0)
	if base == 0:
		base = int(l.get_theme_font_size("font_size"))
		l.set_meta("fit_size", base)
	var lo: int = min_size if min_size > 0 else int(l.get_meta("wrap_min_size", mini(base, FIT_MIN)))
	var fs := base
	var f := l.get_theme_font("font")
	var w := l.size.x
	if w <= 0.0:
		return
	while fs > lo and l.size.y > 0.0 and _wrap_lines(f, fs, l.text, w, TextServer.AUTOWRAP_WORD_SMART) * f.get_height(fs) > l.size.y:
		fs -= 1
	if l.get_theme_font_size("font_size") != fs:
		l.add_theme_font_size_override("font_size", fs)
		l.update_minimum_size()
		if l.get_parent() is Container:
			(l.get_parent() as Container).update_minimum_size()


## Título de pantalla: encoge si el texto es más ancho que `max_w` (no se sale ni se lee a medias).
static func fit_title(l: Label, max_w: float, min_size: int = 20) -> void:
	var f := l.get_theme_font("font")
	var fs := int(l.get_theme_font_size("font_size"))
	while fs > min_size and f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x > max_w:
		fs -= 1
	if fs != int(l.get_theme_font_size("font_size")):
		l.add_theme_font_size_override("font_size", fs)


# ---------- Filas de botones ----------
## Fila (o filas) centradas de botones que nunca es más ancha que `max_w`: los que no caben pasan a otra línea,
## como en el móvil. Devuelve el VBox; se reordena sola cada vez que cambia su ancho.
static func button_row(buttons: Array, sep: int = 14, max_w: float = 1180.0) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_PASS
	var row := _flow_row(sep)
	v.add_child(row)
	for b in buttons:
		row.add_child(b)
	v.set_meta("rows", [row])
	v.set_meta("max_w", max_w)
	v.set_meta("sep", sep)
	v.resized.connect(func(): _reflow_buttons.call_deferred(v))
	_reflow_buttons.call_deferred(v)
	return v


static func _flow_row(sep: int) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	r.add_theme_constant_override("separation", sep)
	return r


## Reparte los botones en filas de como mucho `max_w` px, conservando el orden (y el foco de cada botón).
static func _reflow_buttons(v: VBoxContainer) -> void:
	if not is_instance_valid(v) or not v.is_inside_tree():
		return
	var max_w: float = v.get_meta("max_w", 1180.0)
	var sep: int = v.get_meta("sep", 14)
	var btns := []
	for r in v.get_children():
		for b in r.get_children():
			btns.append(b)
	if btns.is_empty():
		return
	for b in btns:
		fit_button(b)
	var lines := []
	var cur := []
	var w := 0.0
	for b in btns:
		var bw := button_width(b)
		if not cur.is_empty() and w + sep + bw > max_w:
			lines.append(cur)
			cur = []
			w = 0.0
		w += bw + (sep if not cur.is_empty() else 0.0)
		cur.append(b)
	if not cur.is_empty():
		lines.append(cur)
	var old: Array = v.get_meta("rows", [])
	if old.size() != lines.size():
		for r in old:
			(r as Node).queue_free()
		var rows := []
		for i in lines.size():
			var r := _flow_row(sep)
			v.add_child(r)
			rows.append(r)
		v.set_meta("rows", rows)
	var rows2: Array = v.get_meta("rows")
	for i in lines.size():
		var target: HBoxContainer = rows2[i]
		var got := target.get_children()
		for j in lines[i].size():
			var b = lines[i][j]
			if j >= got.size() or got[j] != b:
				if b.get_parent() != null:
					b.get_parent().remove_child(b)
				target.add_child(b)
				target.move_child(b, mini(j, target.get_child_count() - 1))


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
	var m := node.get_node_or_null("/root/Meta")   # igual que _sfx: el autoload puede no existir aún
	var fast: bool = bool(m.settings.get("fast", false)) if m != null else false
	var f: float = 0.45 if fast else 1.0
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
	if c.focus_mode != Control.FOCUS_NONE:   # mando / teclado: el tooltip sale con el foco
		c.focus_entered.connect(func(): Tip.show_at(c))
		c.focus_exited.connect(func(): Tip.hide_for(c))


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
