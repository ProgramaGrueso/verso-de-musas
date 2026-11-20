class_name MuseSprite
extends Control
## Animación de una musa a partir de hojas de sprites en cuadrícula (idle, attack, cast, hurt, die...).
## El idle avanza a IDLE_FPS desde el Timer propio (`_clock`); una acción (attack, cast, hurt, die) corre en
## _process a `fps`. Ninguna de las dos cosas cuesta nada cuando el combate está en reposo.

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
var _frames := {}          # "anim:frame" -> AtlasTexture, reutilizada al volver a ese fotograma
var _last_anim := ""
var _last_f := -1
var _sheets := {}
var _clock: Timer
var h_px := 300.0
const IDLE_FPS := 3.0      # el idle de las hojas tiene 72 fotogramas y es un vaivén: a 24 fps era un temblor
const IDLE_TICK := 0.25    # reloj del idle: no hace falta un _process por fotograma para un vaivén lento
const _CLOCK_GROUP := "muse_idle_clock"


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
	# cada musa lleva su propio Timer de idle (no se reutiliza el de otro combate ya liberado); solo el
	# primero de la escena es quien reparte el tick entre todas (ver `_clock_tick`)
	var clock := Timer.new()
	clock.wait_time = IDLE_TICK
	clock.process_mode = Node.PROCESS_MODE_PAUSABLE
	clock.timeout.connect(_clock_tick)
	add_child(clock)
	add_to_group(_CLOCK_GROUP)
	_clock = clock
	_draw_frame()
	set_process(false)   # en idle no hace falta un _process: lo mueve `_clock` a 3 Hz
	_arm_clock()


func _sheet(a: String) -> Texture2D:
	if not _sheets.has(a):
		_sheets[a] = load("res://assets/sprites/%s_%s.webp" % [muse, a])
	return _sheets[a]


func preload_all() -> void:
	for a in m.anims.keys():
		_sheet(a)


func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED or what == NOTIFICATION_ENTER_TREE or what == NOTIFICATION_EXIT_TREE:
		_update_process()


## Reloj de fotogramas: solo consume tiempo cuando puede cambiar algo. Una animación de acción (attack,
## cast, hurt, die, o una secuencia «dash» del idle) corre en _process a `fps`; el idle, en el Timer compartido.
func _update_process() -> void:
	set_process(is_inside_tree() and is_visible_in_tree() and anim != "idle")
	if is_inside_tree():
		_arm_clock()


## Enciende el reloj del idle si hay que animarlo (y lo apaga si esta musa no lo necesita).
func _arm_clock() -> void:
	if _clock == null:
		return
	var live := _clock.is_inside_tree()
	var need := live and is_inside_tree() and is_visible_in_tree() and anim == "idle" and int(m.anims.get("idle", 0)) > 1
	if need:
		if _clock.is_stopped():
			_clock.start()
	elif live and not _clock.is_stopped():
		# nadie la mueve: se apaga cuando no queda ninguna musa en idle (al cambiar de pantalla también)
		_clock.stop()


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
	acc = 0.0   # no arrastra el resto del intervalo del fotograma anterior
	_draw_frame()
	_update_process()


func _light_frame() -> void:
	if anim == "idle":
		return
	var b := get_tree().current_scene
	if b != null and b.has_method("no_jank"):
		b.no_jank(10, "museo " + anim)


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


## Reloj del idle: avanza a esta musa y a las demás en idle de la escena (un solo Timer hace de reloj).
func _clock_tick() -> void:
	idle_tick()
	var st := get_tree()
	if st == null:
		return
	for n in st.get_nodes_in_group(_CLOCK_GROUP):
		if n is MuseSprite and n != self and n.is_inside_tree() and n._clock != null and n._clock.is_stopped():
			n.idle_tick()


## Fotograma del idle (lo llama el Timer compartido mientras haya musas en idle visibles).
func idle_tick() -> void:
	if dead or anim != "idle" or not is_visible_in_tree():
		return
	acc += IDLE_TICK
	if acc >= 1.0 / IDLE_FPS:
		acc = 0.0
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
		_update_process()
		return
	var n: int = m.anims[anim]
	if anim == "idle":
		if n <= 1:
			return   # hoja de un solo fotograma: nada que avanzar (no se redibuja ni se procesa)
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
	if anim == _last_anim and f == _last_f:
		return
	var t := _sheet(anim)
	if t == null:
		return
	var cols: int = int(m.get("cols", 1000000))
	var w: int = m.w
	var h: int = m.h
	var rect := Rect2((f % cols) * w, (f / cols) * h, w, h)
	var key := "%s:%d" % [anim, f]
	var at: AtlasTexture = _frames.get(key)
	if at == null:
		at = AtlasTexture.new()
		at.atlas = t
		at.region = rect
		_frames[key] = at
	# Al volver a un fotograma ya gastado se reutiliza su AtlasTexture. Cambiar de hoja (idle→attack, die…)
	# con el MISMO AtlasTexture hace que el TextureRect vuelva a cargar la imagen entera (15700x840 en las
	# musas de dos filas) y re-aplane lo que se dibujaba: es el "tirón" al lanzar un golpe. Se monta en su
	# lugar la AtlasTexture de ese fotograma (que solo apunta a su recorte) → no hay recarga salvo la primera vez.
	_tex_rect.texture = at
	_last_anim = anim
	_last_f = f
