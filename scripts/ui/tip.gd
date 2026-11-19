class_name Tip
extends PanelContainer
## Tooltip global que sigue al ratón. Se crea una vez en Main.

static var I: Tip
var _pinned := false
var _rt: RichTextLabel
var _owner: Control = null


static func show_for(c: Control) -> void:
	if I == null or not c.has_meta("tip"):
		return
	var t = c.get_meta("tip")
	if t is Callable:
		t = t.call()
	if str(t) == "":
		return
	I._owner = c
	I._pinned = false
	I._set_text(str(t))
	I.visible = true
	I._place()


## Igual que show_for pero anclado al control (mando / foco), no al puntero.
static func show_at(c: Control) -> void:
	if I == null or not c.has_meta("tip"):
		return
	var t = c.get_meta("tip")
	if t is Callable:
		t = t.call()
	if str(t) == "":
		return
	I._owner = c
	I._pinned = true
	I._set_text(str(t))
	I.visible = true
	I._place()


static func hide_for(c: Control) -> void:
	if I != null and (I._owner == c or c == null):
		I.visible = false
		I._owner = null


static func hide_all() -> void:
	if I != null:
		I.visible = false
		I._owner = null


func _init() -> void:
	I = self
	visible = false
	set_process(false)   # solo corre mientras el tooltip esta visible
	visibility_changed.connect(func(): set_process(visible))
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 4000
	var s := UIK.stylebox(Color("#120d1d"), UIK.GOLD, 2, 10, 14)
	s.content_margin_left = 14; s.content_margin_right = 14; s.content_margin_top = 10; s.content_margin_bottom = 10
	add_theme_stylebox_override("panel", s)
	_rt = UIK.rich("", 15)
	_rt.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_rt.custom_minimum_size = Vector2(0, 0)
	_rt.fit_content = true
	add_child(_rt)


func _set_text(t: String) -> void:
	_rt.text = t
	# ancho = línea más larga (sin BBCode), entre 120 y 330 px
	var rx := RegEx.new()
	rx.compile("\\[[^\\]]*\\]")
	var plain := rx.sub(t, "", true)
	var f := UIK.font("sans")
	var w := 0.0
	for line in plain.split("\n"):
		w = maxf(w, f.get_string_size(line, HORIZONTAL_ALIGNMENT_LEFT, -1, 15).x)
	_rt.custom_minimum_size = Vector2(clampf(w + 6.0, 120.0, 330.0), 0)
	size = Vector2.ZERO


func _place() -> void:
	reset_size()
	var vs := get_viewport_rect().size
	if _pinned and _owner != null and is_instance_valid(_owner):
		var r := _owner.get_global_rect()
		var q := Vector2(r.position.x + r.size.x / 2.0 - size.x / 2.0, r.end.y + 12)
		if q.y + size.y > vs.y - 6:
			q.y = r.position.y - size.y - 12
		q.x = clampf(q.x, 6.0, maxf(6.0, vs.x - 6 - size.x))
		q.y = clampf(q.y, 6.0, maxf(6.0, vs.y - 6 - size.y))
		position = q
		return
	var m := get_viewport().get_mouse_position()
	var p := m + Vector2(16, 20)
	if p.x + size.x > vs.x - 6:
		p.x = vs.x - 6 - size.x
	if p.y + size.y > vs.y - 6:
		p.y = m.y - size.y - 14
	position = Vector2(maxf(4, p.x), maxf(4, p.y))


func _process(_dt: float) -> void:
	if visible:
		if _owner == null or not is_instance_valid(_owner) or not _owner.is_visible_in_tree():
			visible = false
			return
		_place()
