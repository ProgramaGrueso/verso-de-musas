class_name Medal
extends RefCounted
## Medallón de logro: arte pintado recortado en círculo, aro dorado (o apagado si falta) e icono en una insignia.
## Las rutas de arte van como "lore:id", "bg:id", "enemy:id" o "muse:id"; los iconos como "tipo:id" de Icons.

static var _gray: ShaderMaterial


static func art_path(spec: String) -> String:
	return Progress.art_path(spec)


## Material en escala de grises y algo oscuro para lo que aún está bloqueado.
static func gray() -> ShaderMaterial:
	if _gray == null:
		var sh := Shader.new()
		sh.code = "shader_type canvas_item;\nuniform float dark = 0.55;\nvoid fragment() {\n\tvec4 c = texture(TEXTURE, UV) * COLOR;\n\tfloat l = dot(c.rgb, vec3(0.299, 0.587, 0.114));\n\tCOLOR = vec4(vec3(l) * dark * vec3(0.92, 0.9, 1.05), c.a);\n}"
		_gray = ShaderMaterial.new()
		_gray.shader = sh
	return _gray


## Arte circular sin interacción. ring: color del aro (Color(0,0,0,0) = sin aro).
static func disc(art: String, size: float, lit: bool, ring: Color = UIK.GOLD, ring_w: int = 3) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if lit and ring.a > 0.0:   # halo detrás del disco (la sombra de un aro hueco teñiría el arte)
		var glow := Panel.new()
		var gsb := UIK.stylebox(Color("#140f22"), Color(0, 0, 0, 0), 0, int(size / 2.0), 8)
		gsb.shadow_color = Color(ring, 0.5)
		glow.add_theme_stylebox_override("panel", gsb)
		glow.size = Vector2(size, size)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(glow)
	var clip := Panel.new()
	clip.add_theme_stylebox_override("panel", UIK.stylebox(Color("#140f22"), Color(0, 0, 0, 0), 0, int(size / 2.0), 0))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.size = Vector2(size, size)
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(clip)
	var tr := TextureRect.new()
	tr.texture = UIK.tex(art_path(art))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.size = Vector2(size, size)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if not lit:
		tr.material = gray()
	clip.add_child(tr)
	# viñeta interior para que el aro destaque sobre cualquier arte
	var vg := Panel.new()
	var vsb := UIK.stylebox(Color(0, 0, 0, 0), Color(0, 0, 0, 0.55), maxi(2, int(size * 0.06)), int(size / 2.0), 0)
	vg.add_theme_stylebox_override("panel", vsb)
	vg.size = Vector2(size, size)
	vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(vg)
	if ring.a > 0.0:
		var rg := Panel.new()
		var sb := UIK.stylebox(Color(0, 0, 0, 0), ring if lit else Color("#4a4166"), ring_w, int(size / 2.0), 0)
		rg.add_theme_stylebox_override("panel", sb)
		rg.size = Vector2(size, size)
		rg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.add_child(rg)
	return holder


## Medallón completo de un logro (arte + aro + insignia con icono o candado).
static func make(a: Dictionary, size: float, got: bool) -> Control:
	var holder := disc(str(a.get("art", "")), size, got)
	var bs := roundf(size * 0.42)
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", UIK.stylebox(Color("#120d1d"), UIK.GOLD if got else Color("#4a4166"), 2, int(bs / 2.0), 0))
	badge.size = Vector2(bs, bs)
	badge.position = Vector2(size - bs * 0.86, size - bs * 0.86)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.add_child(badge)
	var ic: TextureRect
	if got:
		var p := str(a.get("icon", "ui:music")).split(":")
		ic = Icons.rect(p[0], p[1], bs * 0.78)
	else:
		ic = Icons.rect("ui", "lock", bs * 0.7)
		ic.modulate = Color(0.85, 0.82, 0.95)
	ic.position = (Vector2(bs, bs) - ic.size) / 2.0
	badge.add_child(ic)
	return holder


## Fondo pintado oscurecido + cabecera (título, subtítulo) común a Logros, Compendio y Reto diario.
## Devuelve la fila de la cabecera para que cada pantalla añada sus botones a la derecha.
static func chrome(parent: Control, bg_key: String, title: String, sub: String) -> HBoxContainer:
	parent.add_child(UIK.backdrop(1, bg_key))
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.02, 0.06, 0.8)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	UIK.full_rect(dim)
	parent.add_child(dim)
	parent.add_child(UIK.shade(0.35, 0.0))
	var head := HBoxContainer.new()
	head.position = Vector2(40, 18)
	head.size = Vector2(1200, 70)
	head.add_theme_constant_override("separation", 8)
	parent.add_child(head)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_theme_constant_override("separation", 0)
	var tl := UIK.label(title, 34, UIK.GOLD, "title")
	UIK.outlined(tl, 4)
	hv.add_child(tl)
	var sl := UIK.label(sub, 17, UIK.DIM)
	hv.add_child(sl)
	head.add_child(hv)
	# título + subtítulo caben en los 70 px de la cabecera (lo de debajo, pestañas o lista, empieza en y≈88): al
	# 115/130 % el que cede es el título, que es decorativo; el subtítulo conserva el tamaño elegido
	var tf := tl.get_theme_font("font")
	var sf := sl.get_theme_font("font")
	var ss := sl.get_theme_font_size("font_size")
	var fs := tl.get_theme_font_size("font_size")
	while fs > 22 and tf.get_height(fs) + sf.get_height(ss) > head.size.y:
		fs -= 1
	if fs != tl.get_theme_font_size("font_size"):
		tl.add_theme_font_size_override("font_size", fs)
	return head


## Botón de pestaña: dorado cuando está activa.
static func tab_button(text: String, active: bool) -> Button:
	var b := UIK.button(text, "small", 16)
	if active:
		var sb := UIK.stylebox(Color("#5a4618"), UIK.GOLD, 2, 12, 6)
		sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 6; sb.content_margin_bottom = 6
		for st in ["normal", "hover", "focus", "pressed"]:
			b.add_theme_stylebox_override(st, sb)
		b.add_theme_color_override("font_color", Color.WHITE)
	return b


## Barra de progreso fina con los colores del juego.
static func bar(value: float, max_value: float, w: float, col: Color = UIK.GOLD) -> ProgressBar:
	var pb := ProgressBar.new()
	pb.max_value = maxf(1.0, max_value)
	pb.value = clampf(value, 0.0, max_value)
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(w, 8)
	pb.add_theme_stylebox_override("background", UIK.stylebox(Color("#0b0814"), Color("#3a3355"), 1, 4, 0))
	pb.add_theme_stylebox_override("fill", UIK.stylebox(col, Color(0, 0, 0, 0), 0, 4, 0))
	pb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return pb
