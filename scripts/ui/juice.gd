class_name Juice
extends RefCounted
## Utilidades de "juice" del combate: anillos de impacto y el ajuste «reducir movimiento».
## Con movimiento reducido no hay sacudidas, hitstop, anillos ni partículas; los destellos de color se mantienen.


static func calm() -> bool:
	return bool(Meta.settings.get("calm", false))


## Anillo que se expande y se desvanece (impacto de carta, escudo, orbe, muerte).
static func ring(parent: Node, pos: Vector2, color: Color, r0: float, r1: float, dur: float = 0.35, width: float = 6.0) -> void:
	if calm() or parent == null:
		return
	var r := Ring.new()
	r.position = pos
	r.color = color
	r.width = width
	r.radius = r0
	parent.add_child(r)
	var tw := r.create_tween().set_parallel(true)
	tw.tween_property(r, "radius", r1, dur).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(r, "width", 1.0, dur)
	tw.tween_property(r, "modulate:a", 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(r.queue_free)


## Todos los descendientes ignoran el ratón (vistas previas flotantes que no deben robar el hover).
static func mouse_ignore_all(n: Node) -> void:
	if n is Control:
		(n as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
		(n as Control).focus_mode = Control.FOCUS_NONE
	for c in n.get_children():
		mouse_ignore_all(c)


class Ring extends Control:
	var color := Color.WHITE
	var width := 6.0:
		set(v):
			width = v
			queue_redraw()
	var radius := 10.0:
		set(v):
			radius = v
			queue_redraw()

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, Color(color, color.a * 0.35), width * 2.2, true)
		draw_arc(Vector2.ZERO, radius, 0.0, TAU, 64, color, width, true)
