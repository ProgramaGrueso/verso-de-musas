class_name EndingScreen
extends Control
## Cinemática del final (imágenes con movimiento lento y texto que se escribe solo).

var char := "zafiro"
var nm := 0
var done := Callable()
var replay := false
var boss := "queen"   # jefe del acto III vencido (cambia el primer texto)

var _scenes: Array = []
var _idx := -1
var _auto := true
var _finished := false
var _img: TextureRect
var _img2: TextureRect
var _front := 0
var _stage: Control
var _text: Label
var _typing := false
var _typed := 0.0
var _hold := 0.0
var _title: Label
var _auto_btn: Button
var _cur_tw: Tween
var _ctrl: HBoxContainer


func _ready() -> void:
	Sfx.music("ending")
	var names := {}
	for id in DB.characters.keys():
		names[id] = DB.characters[id].name
	var others := ["zafiro", "lia", "claudia"].filter(func(c): return c != char)
	var fill := func(t: String) -> String:
		return t.replace("{N}", names[char]).replace("{O1}", names[others[0]] if others.size() > 0 else "").replace("{O2}", names[others[1]] if others.size() > 1 else "")
	for sc in DB.ending.scenes:
		if sc == null:
			continue
		var txt: String = sc.text
		if sc.has("alt") and sc.alt.has(char):
			txt = sc.alt[char]
		if sc.has("altBoss") and sc.altBoss.has(boss):
			txt = sc.altBoss[boss]
		_scenes.append({"img": sc.img.replace("{c}", char), "fx": sc.fx, "text": fill.call(txt)})
	var n: Dictionary = DB.ending.nightmare
	_scenes.append({"img": n.img, "fx": n.fx, "text": n.text, "dark": true})
	var bg := ColorRect.new()
	bg.color = Color.BLACK
	UIK.full_rect(bg)
	add_child(bg)
	_stage = Control.new()
	UIK.full_rect(_stage)
	_stage.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_stage)
	_img = _mk_img()
	_img2 = _mk_img()
	var bars := UIK.shade(0.0, 0.0)
	bars.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.0)], [0.6, Color(0, 0, 0, 0.0)], [1.0, Color(0, 0, 0, 0.85)]])
	add_child(bars)
	_text = UIK.label("", 26, Color.WHITE, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	_text.position = Vector2(140, 540)
	_text.size = Vector2(1000, 120)
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	UIK.outlined(_text, 8)
	add_child(_text)
	_title = UIK.label("", 96, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	_title.position = Vector2(0, 260)
	_title.size = Vector2(1280, 140)
	UIK.outlined(_title, 12)
	add_child(_title)
	# fila de controles pegada a la esquina inferior derecha: crece hacia arriba y a la izquierda con el
	# tamaño del texto (antes empezaba en y=668 con 44 px y los botones, de 58-68 px, se salían por abajo)
	var ctrl := HBoxContainer.new()
	ctrl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	ctrl.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	ctrl.grow_vertical = Control.GROW_DIRECTION_BEGIN
	ctrl.offset_left = -580
	ctrl.offset_right = -20
	ctrl.offset_top = -52
	ctrl.offset_bottom = -8
	ctrl.alignment = BoxContainer.ALIGNMENT_END
	ctrl.add_theme_constant_override("separation", 10)
	add_child(ctrl)
	_ctrl = ctrl
	ctrl.resized.connect(_place_text)
	var skip := UIK.button(tr("Saltar"), "small")
	skip.pressed.connect(_finish)
	_auto_btn = UIK.button(tr("Automático: sí"), "small")
	_auto_btn.pressed.connect(func(): _auto = not _auto; _auto_btn.text = tr("Automático: sí") if _auto else tr("Automático: no"))
	var nxt := UIK.button(tr("Siguiente ▶"))
	nxt.pressed.connect(_next)
	ctrl.add_child(skip)
	ctrl.add_child(_auto_btn)
	ctrl.add_child(nxt)
	_show_scene(0)
	_place_text()


## El texto de la escena termina justo encima de la fila de controles (que crece con el tamaño del texto);
## si una frase no cabe en sus 120 px, la fuente encoge (UIK.fit_label) en vez de meterse bajo los botones.
func _place_text() -> void:
	if _ctrl == null or _text == null:
		return
	var bottom := _ctrl.position.y - 6.0
	var top := minf(540.0, bottom - 120.0)
	var r := Rect2(140, top, 1000, bottom - top)
	if Rect2(_text.position, _text.size) != r:
		_text.position = r.position
		_text.size = r.size
	UIK.fit_label(_text)


func _mk_img() -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	t.size = Vector2(1280, 720)
	t.pivot_offset = Vector2(640, 360)
	t.modulate.a = 0.0
	_stage.add_child(t)
	return t


func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and not ev.echo:
		if ev.keycode in [KEY_SPACE, KEY_ENTER, KEY_RIGHT]:
			get_viewport().set_input_as_handled()
			_next()
		elif ev.keycode == KEY_ESCAPE:
			_finish()
	elif ev is InputEventJoypadButton and ev.pressed:
		if ev.button_index in [JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_START]:
			get_viewport().set_input_as_handled()
			_next()
		elif ev.button_index == JOY_BUTTON_B:
			_finish()


func _finish() -> void:
	if _finished:
		return
	_finished = true
	if replay:
		Nav.title()
	elif done.is_valid():
		done.call()


func _show_scene(i: int) -> void:
	_idx = i
	_hold = 0.0
	if i >= _scenes.size():
		_title.text = tr("FIN")
		_text.text = ""
		_typing = false
		get_tree().create_timer(3.5).timeout.connect(_finish)
		return
	var sc: Dictionary = _scenes[i]
	var path := "res://assets/end/%s.webp" % sc.img
	var tex := UIK.tex(path)
	if tex == null:
		tex = UIK.tex("res://assets/ui/%s_select.webp" % char)
	var back := _img2 if _front == 0 else _img
	var front_node := _img if _front == 0 else _img2
	back.texture = tex
	back.modulate = Color(0.55, 0.45, 0.6, 0.0) if sc.get("dark", false) else Color(1, 1, 1, 0.0)
	# movimiento lento según el efecto
	back.scale = Vector2.ONE
	back.position = Vector2.ZERO
	var fx: String = sc.fx
	var tw := back.create_tween().set_parallel(true)
	var tgt_a := 1.0
	tw.tween_property(back, "modulate:a", tgt_a, 1.2)
	match fx:
		"zoomin":
			back.scale = Vector2(1.0, 1.0)
			tw.tween_property(back, "scale", Vector2(1.12, 1.12), 14.0)
		"zoomout":
			back.scale = Vector2(1.14, 1.14)
			tw.tween_property(back, "scale", Vector2.ONE, 14.0)
		"panup":
			back.scale = Vector2(1.12, 1.12)
			back.position = Vector2(0, 30)
			tw.tween_property(back, "position", Vector2(0, -30), 14.0)
		"panright":
			back.scale = Vector2(1.12, 1.12)
			back.position = Vector2(-40, 0)
			tw.tween_property(back, "position", Vector2(40, 0), 14.0)
	front_node.create_tween().tween_property(front_node, "modulate:a", 0.0, 1.2)
	_stage.move_child(back, _stage.get_child_count() - 1)
	_front = 1 - _front
	_text.text = sc.text
	UIK.fit_label(_text)
	_text.visible_characters = 0
	_typed = 0.0
	_typing = true


func _process(dt: float) -> void:
	if _idx < 0 or _idx >= _scenes.size():
		return
	var total: int = _text.text.length()
	if _typing:
		_typed += dt * 52.0
		_text.visible_characters = int(_typed)
		if _typed >= total:
			_typing = false
			_text.visible_characters = -1
			_hold = 0.0
	elif _auto:
		_hold += dt
		if _hold >= 5.2:
			_hold = -9999.0
			_show_scene(_idx + 1)


func _next() -> void:
	Sfx.play("click")
	if _idx >= 0 and _idx < _scenes.size() and _typing:
		_typing = false
		_text.visible_characters = -1
		_hold = 0.0
		return
	_hold = -9999.0
	_show_scene(_idx + 1)
