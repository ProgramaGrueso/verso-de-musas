class_name MuseSprite
extends Control
## Animación de una musa a partir de hojas de sprites en cuadrícula (idle, attack, cast, hurt, die...).

var muse := ""
var m: Dictionary
var fps := 12.0
var anim := "idle"
var f := 0
var dir := 1
var acc := 0.0
var dead := false
var on_end := Callable()
var seq: Array = []
var si := 0
var _tex_rect: TextureRect
var _atlas: AtlasTexture
var _sheets := {}
var h_px := 300.0


func _init(p_muse: String = "zafiro", height: float = 300.0) -> void:
	muse = p_muse
	h_px = height
	m = DB.sprites[muse]
	fps = float(m.get("fps", 12))
	var w := roundf(float(m.w) / float(m.h) * height)
	custom_minimum_size = Vector2(w, height)
	size = Vector2(w, height)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_atlas = AtlasTexture.new()
	_tex_rect = TextureRect.new()
	_tex_rect.texture = _atlas
	_tex_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_tex_rect.stretch_mode = TextureRect.STRETCH_SCALE
	_tex_rect.size = size
	_tex_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_tex_rect)
	_draw_frame()


func _sheet(a: String) -> Texture2D:
	if not _sheets.has(a):
		_sheets[a] = load("res://assets/sprites/%s_%s.webp" % [muse, a])
	return _sheets[a]


func preload_all() -> void:
	for a in m.anims.keys():
		_sheet(a)


func play(a: String, cb: Callable = Callable()) -> void:
	if dead:
		return
	var n: int = m.anims.get(a, 0)
	if n == 0:
		if cb.is_valid():
			cb.call()
		return
	var dash = m.get("dash", {}).get(a)
	seq = dash.frames.duplicate() if dash != null else []
	si = 0
	if dash != null:
		_lunge(dash)
	anim = a
	f = int(dash.frames[0]) if dash != null else 0
	dir = 1
	on_end = cb
	_draw_frame()


# Desplaza el lienzo hacia los enemigos durante una animación «dash» y lo devuelve a su sitio.
func _lunge(dash: Dictionary) -> void:
	var ms: float = float(dash.frames.size()) / fps
	var dx: float = float(dash.dx) * (h_px / 420.0)
	var tw := _tex_rect.create_tween()
	tw.tween_property(_tex_rect, "position:x", dx, ms * 0.32).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(ms * 0.23)
	tw.tween_property(_tex_rect, "position:x", 0.0, ms * 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _process(dt: float) -> void:
	if dead:
		return
	acc += dt
	var T := 1.0 / fps
	if acc >= T:
		acc = minf(acc - T, T)
		_step()


func _step() -> void:
	if not seq.is_empty():
		si += 1
		if si < seq.size():
			f = int(seq[si])
		else:
			seq = []
			var cb := on_end
			on_end = Callable()
			anim = "idle"
			f = 0
			dir = 1
			if cb.is_valid():
				cb.call()
		_draw_frame()
		return
	var n: int = m.anims[anim]
	if anim == "idle":
		f += dir
		if f >= n - 1:
			f = n - 1
			dir = -1
		elif f <= 0:
			f = 0
			dir = 1
	else:
		if f < n - 1:
			f += 1
		elif anim == "die":
			dead = true
		else:
			var cb2 := on_end
			on_end = Callable()
			anim = "idle"
			f = 0
			dir = 1
			if cb2.is_valid():
				cb2.call()
	_draw_frame()


func _draw_frame() -> void:
	var t := _sheet(anim)
	if t == null:
		return
	var cols: int = int(m.get("cols", 1000000))
	var w: int = m.w
	var h: int = m.h
	_atlas.atlas = t
	_atlas.region = Rect2((f % cols) * w, (f / cols) * h, w, h)
