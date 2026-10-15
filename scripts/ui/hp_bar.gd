class_name HpBar
extends Control
## Barra de vida con relleno animado y texto "hp / max".

var hp := 0
var max_hp := 1
var shown := 1.0          # fracción mostrada (animada)
var trail := 1.0          # estela de daño
var fill_top := Color("#ff6572")
var fill_bot := Color("#b31b2a")
var font_size := 13
var _tw: Tween
var _tw2: Tween


func _init(w: float = 230.0, h: float = 18.0) -> void:
	custom_minimum_size = Vector2(w, h)
	size = Vector2(w, h)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_values(p_hp: int, p_max: int, animate: bool = true) -> void:
	var first := max_hp <= 1 and hp == 0 and shown == 1.0
	hp = p_hp
	max_hp = maxi(1, p_max)
	var target := clampf(float(maxi(0, hp)) / max_hp, 0.0, 1.0)
	if not animate or first or not is_inside_tree():
		shown = target
		trail = target
		queue_redraw()
		return
	if _tw and _tw.is_valid():
		_tw.kill()
	_tw = create_tween()
	_tw.tween_method(func(v): shown = v; queue_redraw(), shown, target, 0.3)
	if _tw2 and _tw2.is_valid():
		_tw2.kill()
	_tw2 = create_tween()
	if target < trail:
		_tw2.tween_interval(0.35)
	_tw2.tween_method(func(v): trail = v; queue_redraw(), trail, target, 0.4)


func _draw() -> void:
	var r := size.y / 2.0
	var bg := UIK.stylebox(Color(0, 0, 0, 0.72), Color.BLACK, 2, int(r), 0)
	draw_style_box(bg, Rect2(Vector2.ZERO, size))
	var inner := Rect2(Vector2(2, 2), size - Vector2(4, 4))
	if trail > shown:
		var tw := inner.size.x * trail
		var tb := UIK.stylebox(Color("#ffd0a0", 0.85), Color(0, 0, 0, 0), 0, int(r) - 2, 0)
		draw_style_box(tb, Rect2(inner.position, Vector2(maxf(tw, 0.0), inner.size.y)))
	var fw := inner.size.x * shown
	if fw > 1.0:
		var h2 := inner.size.y / 2.0
		var fb := UIK.stylebox(fill_bot, Color(0, 0, 0, 0), 0, int(r) - 2, 0)
		draw_style_box(fb, Rect2(inner.position, Vector2(fw, inner.size.y)))
		var ft := UIK.stylebox(fill_top, Color(0, 0, 0, 0), 0, int(r) - 2, 0)
		draw_style_box(ft, Rect2(inner.position, Vector2(fw, h2 + 1)))
	var txt := "%d / %d" % [maxi(0, hp), max_hp]
	var f := UIK.font("bold")
	var ts := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var pos := Vector2((size.x - ts.x) / 2.0, (size.y + ts.y) / 2.0 - f.get_descent(font_size))
	draw_string_outline(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, 4, Color.BLACK)
	draw_string(f, pos, txt, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.WHITE)
