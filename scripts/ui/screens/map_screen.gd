class_name MapScreen
extends Control
## Mapa de la zona: grafo de salas con camino punteado y desplazamiento vertical.

const MAP_H := 2300
const NODE_NAME := {"combat": "Combate", "elite": "Élite", "event": "Evento", "shop": "Tienda", "rest": "Hoguera", "boss": "Jefe"}
const NODE_DESC := {
	"combat": "Un combate normal. Premio: oro, carta y a veces una poción.",
	"elite": "Un enemigo poderoso. Premio: una reliquia y mejores cartas.",
	"event": "Algo inesperado: puede ser bueno... o no.",
	"shop": "Compra cartas, reliquias y pociones. También puedes eliminar cartas.",
	"rest": "Descansa para curarte o mejora una carta.",
	"boss": "El guardián de la zona. ¡Prepárate!",
}

var announce := false
var _sc: ScrollContainer
var _avail: Array = []
var _G
var _drag := false
var _drag_y := 0.0
var _drag_top := 0


func _node_pos(n: Dictionary) -> Vector2:
	if n.type == "boss":
		return Vector2(640, 190)
	return Vector2(230 + (float(n.c) / 3.0) * 820, MAP_H - 260 - (float(n.r) / (RunGen.ROWS - 1)) * (MAP_H - 760))


func _ready() -> void:
	_G = Meta.run
	var G = _G
	Meta.save_run(G)
	Sfx.music("map", G.act)
	_avail = RunGen.next_nodes(G)
	var key: String = UIK.ACT_KEY[G.act - 1]
	var bg := ColorRect.new()
	bg.color = Color("#05040a")
	UIK.full_rect(bg)
	add_child(bg)
	_sc = ScrollContainer.new()
	UIK.full_rect(_sc)
	_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_sc.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_SHOW_NEVER
	add_child(_sc)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(1280, MAP_H)
	_sc.add_child(inner)
	var art := UIK.tex("res://assets/map/%s.webp" % key)
	if art != null:
		var t := TextureRect.new()
		t.texture = art
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		t.size = Vector2(1280, MAP_H)
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(t)
	var paths := MapPaths.new()
	paths.size = Vector2(1280, MAP_H)
	paths.screen = self
	paths.G = G
	paths.avail = _avail
	paths.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(paths)
	# inicio
	var st := UIK.label("Inicio del ascenso", 20, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(st, 6)
	st.position = Vector2(440, MAP_H - 60)
	st.size = Vector2(400, 30)
	inner.add_child(st)
	var all := []
	for row in G.map.rows:
		all.append_array(row)
	all.append(G.map.boss)
	for n in all:
		_add_node(inner, n)
	# cabecera
	var act: Dictionary = DB.acts[G.act - 1]
	var head := VBoxContainer.new()
	head.position = Vector2(0, 54)
	head.size = Vector2(1280, 60)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := UIK.label("%s: %s%s" % [act.sub, act.name, (" · Pesadilla %d" % G.nm) if G.get("nm", 0) else ""], 32, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t1, 8)
	head.add_child(t1)
	var t2 := UIK.label("Arrastra o usa la rueda / las flechas para ver todo el camino", 15, Color("#d9d2ee"), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t2, 5)
	head.add_child(t2)
	add_child(head)
	# navegación y leyenda
	var nav := VBoxContainer.new()
	nav.position = Vector2(1210, 280)
	nav.add_theme_constant_override("separation", 8)
	for spec in [["▲", -380], ["Aquí", 0], ["▼", 380]]:
		var b := UIK.button(spec[0], "small", 22)
		var d: int = spec[1]
		b.pressed.connect(func(): _scroll_by(d) if d != 0 else _focus(true))
		nav.add_child(b)
	add_child(nav)
	var leg := VBoxContainer.new()
	leg.position = Vector2(14, 560)
	for k in NODE_NAME.keys():
		var l := Icons.with_text("node", k, NODE_NAME[k], 24, 16, Color.WHITE)
		UIK.outlined(l.get_node("Text"), 5)
		leg.add_child(l)
	add_child(leg)
	_sc.scroll_vertical = MAP_H
	_focus.call_deferred(true)
	if announce:
		Main.I.toast("%s: %s" % [act.sub, act.name])
	UIK.fade_in(self, 0.3)


func _add_node(inner: Control, n: Dictionary) -> void:
	var G = _G
	var p := _node_pos(n)
	var can := _avail.any(func(x): return is_same(x, n))
	var here: bool = G.pos != null and is_same(G.pos, n)
	var b := Button.new()
	b.size = Vector2(68, 68)
	b.position = p - Vector2(34, 34)
	b.pivot_offset = Vector2(34, 34)
	b.icon = Icons.tex("node", n.type)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 46)
	b.add_theme_color_override("icon_disabled_color", Color.WHITE)
	b.add_theme_color_override("icon_hover_color", Color.WHITE)
	b.add_theme_color_override("icon_pressed_color", Color.WHITE)
	b.add_theme_color_override("icon_focus_color", Color.WHITE)
	b.focus_mode = Control.FOCUS_ALL
	var col: Color = {"combat": Color("#3a2e5c"), "elite": Color("#5c2430"), "event": Color("#2e4a5c"), "shop": Color("#5c4a1e"), "rest": Color("#5c3a1e"), "boss": Color("#6a1f2d")}[n.type]
	var border := UIK.GOLD if can else (Color("#8a7fb0") if not n.visited else Color("#5a8a5a"))
	var sb := UIK.stylebox(col, border, 4, 34, 10 if can else 4)
	var sbh := UIK.stylebox(col.lightened(0.2), Color.WHITE, 4, 34, 14)
	for st in ["normal", "disabled", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sbh if can else sb)
	if n.type == "boss":
		b.size = Vector2(92, 92)
		b.position = p - Vector2(46, 46)
		b.pivot_offset = Vector2(46, 46)
		b.add_theme_constant_override("icon_max_width", 64)
	if n.visited and not here:
		b.modulate = Color(0.6, 0.65, 0.6)
	b.disabled = not can
	if can:
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.1, 1.1), 0.6).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 0.6).set_trans(Tween.TRANS_SINE)
		b.pressed.connect(func(): Nav.enter_node(n))
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	UIK.tip(b, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [NODE_NAME[n.type], NODE_DESC[n.type]])
	inner.add_child(b)
	var lab := UIK.label(NODE_NAME[n.type], 15, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(lab, 5)
	lab.position = Vector2(p.x - 50, p.y + (48 if n.type != "boss" else 58))
	lab.size = Vector2(100, 20)
	inner.add_child(lab)
	if here:
		var you := TextureRect.new()
		you.texture = UIK.tex("res://assets/ui/%s_icon.png" % G.char)
		you.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		you.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		you.size = Vector2(56, 56)
		you.position = p + Vector2(-28, -92)
		you.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var yb := UIK.stylebox(Color(0, 0, 0, 0), UIK.GOLD, 3, 28, 0)
		var fr := Panel.new()
		fr.add_theme_stylebox_override("panel", yb)
		fr.size = you.size
		fr.mouse_filter = Control.MOUSE_FILTER_IGNORE
		you.add_child(fr)
		you.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
		inner.add_child(you)
		var tw2 := you.create_tween().set_loops()
		tw2.tween_property(you, "position:y", you.position.y - 8, 0.7).set_trans(Tween.TRANS_SINE)
		tw2.tween_property(you, "position:y", you.position.y, 0.7).set_trans(Tween.TRANS_SINE)


func _scroll_by(d: int) -> void:
	Sfx.play("click")
	var tw := create_tween()
	tw.tween_property(_sc, "scroll_vertical", clampi(_sc.scroll_vertical + d, 0, MAP_H), 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)


func _focus(smooth: bool) -> void:
	var y := 0.0
	if _avail.size() > 0:
		for n in _avail:
			y += _node_pos(n).y
		y /= _avail.size()
	elif _G.pos != null:
		y = _node_pos(_G.pos).y
	var target := int(maxf(0.0, y - 330.0))
	if smooth:
		var tw := create_tween()
		tw.tween_property(_sc, "scroll_vertical", target, 0.7).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	else:
		_sc.scroll_vertical = target


func _gui_input(ev: InputEvent) -> void:
	pass


func _input(ev: InputEvent) -> void:
	if not is_inside_tree() or Main.I.overlay_host.get_child_count() > 0:
		return
	if ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
		_drag = ev.pressed
		_drag_y = ev.position.y
		_drag_top = _sc.scroll_vertical
	elif ev is InputEventMouseMotion and _drag:
		_sc.scroll_vertical = _drag_top - int(ev.position.y - _drag_y)
	elif ev is InputEventKey and ev.pressed:
		match ev.keycode:
			KEY_UP: _scroll_by(-160)
			KEY_DOWN: _scroll_by(160)
			KEY_PAGEUP: _scroll_by(-520)
			KEY_PAGEDOWN: _scroll_by(520)


class MapPaths extends Control:
	var screen
	var G
	var avail: Array = []

	func _curve(a: Vector2, b: Vector2) -> PackedVector2Array:
		var mx := (a.x + b.x) / 2.0
		var my := (a.y + b.y) / 2.0
		var off := fposmod(a.x * 7.0 + b.y * 3.0, 60.0) - 30.0
		var c := Vector2(mx + off, my)
		var pts := PackedVector2Array()
		for i in 25:
			var t := i / 24.0
			pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
		return pts

	func _stroke(pts: PackedVector2Array, col: Color, dotted: bool, w: float) -> void:
		draw_polyline(pts, Color(0, 0, 0, 0.66), 18.0, true)
		if not dotted:
			draw_polyline(pts, col, w, true)
			return
		# puntos cada ~15 px a lo largo de la curva
		var acc := 0.0
		for i in range(1, pts.size()):
			var seg := pts[i - 1].distance_to(pts[i])
			var steps := maxi(1, int(seg / 4.0))
			for s in steps:
				var p := pts[i - 1].lerp(pts[i], float(s) / steps)
				acc += seg / steps
				if acc >= 15.0:
					acc = 0.0
					draw_circle(p, 4.0, col)

	func _draw() -> void:
		var all := []
		for row in G.map.rows:
			all.append_array(row)
		all.append(G.map.boss)
		for sp in G.map.rows[0]:
			var a := Vector2(640, MapScreen.MAP_H - 70)
			var b: Vector2 = screen._node_pos(sp)
			_stroke(_curve(a, b), Color("#f0cf7a") if G.pos != null else Color("#c9b98a"), G.pos == null, 6.0)
		for n in all:
			for m in n.next:
				var a2: Vector2 = screen._node_pos(n)
				var b2: Vector2 = screen._node_pos(m)
				var used: bool = n.visited and m.visited
				var open: bool = G.pos != null and is_same(G.pos, n) and avail.any(func(x): return is_same(x, m))
				var col := Color("#f0cf7a") if used else (Color("#fff2b0") if open else Color("#a89bd0", 0.75))
				_stroke(_curve(a2, b2), col, not used, 7.0 if used else 6.0)
