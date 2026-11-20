class_name MapScreen
extends Control
## Mapa de la zona: grafo de salas con camino punteado y desplazamiento vertical.

const MAP_H := 2480
const ROW_GAP := 250.0
const NODE_COL := {"combat": Color("#7f6ab8"), "elite": Color("#d8404c"), "event": Color("#4fa3c7"), "shop": Color("#e0b84a"), "rest": Color("#e08a3c"), "boss": Color("#ff5a6a")}
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
var _avail_btns: Array[Button] = []
var _G
var _drag := false
var _drag_y := 0.0
var _drag_top := 0


func _node_pos(n: Dictionary) -> Vector2:
	if n.type == "boss":
		return Vector2(640, 230)
	# retícula limpia con una mínima variación fija por sala (sin aleatoriedad en pantalla)
	var jx := fposmod(n.c * 37.0 + n.r * 53.0, 28.0) - 14.0
	var jy := fposmod(n.c * 23.0 + n.r * 71.0, 24.0) - 12.0
	return Vector2(255 + float(n.c) * 257.0 + jx, MAP_H - 300.0 - float(n.r) * ROW_GAP + jy)


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
	# velo oscuro + viñeta: el fondo acompaña, los nodos mandan
	var veil := ColorRect.new()
	veil.color = Color(0.02, 0.02, 0.05, 0.62)
	veil.size = Vector2(1280, MAP_H)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_child(veil)
	for side in [0, 1]:
		var vg := TextureRect.new()
		vg.texture = UIK.grad_tex([[0.0, Color(0.02, 0.02, 0.05, 0.85 if side == 0 else 0.0)], [1.0, Color(0.02, 0.02, 0.05, 0.0 if side == 0 else 0.85)]], true)
		vg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		vg.stretch_mode = TextureRect.STRETCH_SCALE
		vg.size = Vector2(260, MAP_H)
		vg.position = Vector2(0 if side == 0 else 1020, 0)
		vg.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(vg)
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
	st.position = Vector2(440, MAP_H - 70)
	st.size = Vector2(400, 30)
	inner.add_child(st)
	var all := []
	for row in G.map.rows:
		all.append_array(row)
	all.append(G.map.boss)
	for n in all:
		_add_node(inner, n)
	# cabecera (con un velo propio para que nunca choque con los caminos)
	var scrim := TextureRect.new()
	scrim.texture = UIK.grad_tex([[0.0, Color(0.02, 0.02, 0.05, 0.92)], [1.0, Color(0.02, 0.02, 0.05, 0.0)]])
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.stretch_mode = TextureRect.STRETCH_SCALE
	scrim.size = Vector2(1280, 150)
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(scrim)
	var act: Dictionary = DB.acts[G.act - 1]
	var head := VBoxContainer.new()
	head.position = Vector2(0, 54)
	head.size = Vector2(1280, 60)
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var t1 := UIK.label("%s: %s%s" % [act.sub, act.name, (" · Pesadilla %d" % G.nm) if G.get("nm", 0) else ""], 32, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	t1.custom_minimum_size = Vector2(1240, 0)
	t1.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	UIK.outlined(t1, 8)
	head.add_child(t1)
	var t2 := UIK.label("Arrastra o usa la rueda / stick derecho / flechas para ver el camino", 15, Color("#d9d2ee"), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	t2.custom_minimum_size = Vector2(1240, 0)
	UIK.outlined(t2, 5)
	head.add_child(t2)
	add_child(head)
	# navegación y leyenda
	var nav := VBoxContainer.new()
	nav.position = Vector2(1206, 280)
	nav.size = Vector2(64, 0)
	nav.mouse_filter = Control.MOUSE_FILTER_PASS
	nav.add_theme_constant_override("separation", 8)
	for spec in [["▲", -380], ["Aquí", 0], ["▼", 380]]:
		var b := UIK.button(spec[0], "small", 18)
		b.custom_minimum_size = Vector2(64, 0)
		b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		var d: int = spec[1]
		b.focus_mode = Control.FOCUS_NONE   # con mando: stick derecho desplaza, X centra
		b.pressed.connect(func(): _scroll_by(d) if d != 0 else _focus(true))
		nav.add_child(b)
	add_child(nav)
	var gh := UIK.label("Mando · X: centrar\nStick der.: desplazar\nR3: inspeccionar", 13, UIK.DIM)
	gh.position = Vector2(940, 410)
	gh.size = Vector2(336, 60)   # ancho para la línea más larga: no se sale ni se recorta
	gh.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(gh)
	# con el texto grande los botones crecen y «▼» bajaba hasta la ayuda: ésta empieza bajo su alto real
	gh.position.y = maxf(410.0, nav.position.y + nav.get_combined_minimum_size().y + 6.0)
	gh.size = Vector2(gh.size.x, maxf(60.0, gh.get_combined_minimum_size().y))
	var leg := VBoxContainer.new()
	leg.position = Vector2(14, 520)
	for k in NODE_NAME.keys():
		var l := Icons.with_text("mapnode", k, NODE_NAME[k], 28, 16, Color.WHITE, "node")
		UIK.outlined(l.get_node("Text"), 5)
		leg.add_child(l)
	add_child(leg)
	_sc.scroll_vertical = MAP_H
	_focus.call_deferred(true)
	if not _avail_btns.is_empty():
		_avail_btns[0].grab_focus.call_deferred()
		for i in _avail_btns.size():
			var prev_btn = _avail_btns[(i - 1 + _avail_btns.size()) % _avail_btns.size()]
			var next_btn = _avail_btns[(i + 1) % _avail_btns.size()]
			_avail_btns[i].focus_neighbor_left = prev_btn.get_path()
			_avail_btns[i].focus_neighbor_right = next_btn.get_path()
			# arriba/abajo desplazan el mapa (ver _input): el foco no salta a otra sala
			_avail_btns[i].focus_neighbor_top = _avail_btns[i].get_path()
			_avail_btns[i].focus_neighbor_bottom = _avail_btns[i].get_path()
	if announce:
		Main.I.toast("%s: %s" % [act.sub, act.name])
	UIK.fade_in(self, 0.3)


func _add_node(inner: Control, n: Dictionary) -> void:
	var G = _G
	var p := _node_pos(n)
	var can := _avail.any(func(x): return is_same(x, n))
	var here: bool = G.pos != null and is_same(G.pos, n)
	var big: bool = n.type == "boss"
	var sz := 112.0 if big else (84.0 if n.type == "elite" else 76.0)
	var half := sz / 2.0
	var b := Button.new()
	b.size = Vector2(sz, sz)
	b.position = p - Vector2(half, half)
	b.pivot_offset = Vector2(half, half)
	b.icon = Icons.tex_or("mapnode", "node", n.type)
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", int(sz * 0.74))
	for k in ["disabled", "hover", "pressed", "focus"]:
		b.add_theme_color_override("icon_%s_color" % k, Color.WHITE)
	# con mando solo se enfocan las salas elegibles: el resto informa con el ratón o con R3 (inspeccionar)
	b.focus_mode = Control.FOCUS_ALL if can else Control.FOCUS_NONE
	var tc: Color = NODE_COL[n.type]
	var fill := Color(tc.darkened(0.78), 0.96)
	var ring := Color("#ffe08a") if can else (Color("#58b868") if n.visited else Color(tc, 0.55))
	var sb := UIK.stylebox(fill, ring, 4 if can else 3, int(half), 16 if can else 5)
	sb.shadow_color = Color(Color("#ffd86a") if can else Color.BLACK, 0.55 if can else 0.6)
	var sbh := UIK.stylebox(fill.lightened(0.18), Color.WHITE, 5, int(half), 22)
	sbh.shadow_color = Color("#ffe9a8", 0.75)
	for st in ["normal", "disabled", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sbh if can else sb)
	if n.visited and not here:
		b.modulate = Color(0.62, 0.7, 0.64)
	elif not can and not here:
		b.modulate = Color(0.86, 0.86, 0.92)
	b.disabled = not can
	if can:
		_avail_btns.append(b)
		b.focus_entered.connect(func():
			var target_y := int(maxf(0.0, p.y - 330.0))
			var tw := create_tween()
			tw.tween_property(_sc, "scroll_vertical", target_y, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		)
		var tw := b.create_tween().set_loops()
		tw.tween_property(b, "scale", Vector2(1.08, 1.08), 0.7).set_trans(Tween.TRANS_SINE)
		tw.tween_property(b, "scale", Vector2.ONE, 0.7).set_trans(Tween.TRANS_SINE)
		b.pressed.connect(func(): Nav.enter_node(n))
	b.mouse_filter = Control.MOUSE_FILTER_STOP
	var node_name: String = NODE_NAME[n.type]
	var node_desc: String = NODE_DESC[n.type]
	if big:
		var bid := RunGen.boss_id(G)
		node_name = DB.enemies[bid].name
		node_desc = "El guardián de la zona. ¡Prepárate!\nPV: %d–%d" % [DB.enemies[bid].hp[0], DB.enemies[bid].hp[1]]
	UIK.tip(b, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [node_name, node_desc])
	inner.add_child(b)
	if big:
		# retrato del jefe tras el nodo
		var bt := UIK.tex("res://assets/enemies/%s.webp" % RunGen.boss_id(G))
		if bt != null:
			var portrait := TextureRect.new()
			portrait.texture = bt
			portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			portrait.size = Vector2(220, 200)
			portrait.position = Vector2(p.x + half + 6, p.y - 120)
			portrait.modulate = Color(1, 1, 1, 0.85)
			portrait.mouse_filter = Control.MOUSE_FILTER_IGNORE
			inner.add_child(portrait)
			inner.move_child(portrait, b.get_index())
	if can or big:
		var lab := UIK.label(node_name, 16, UIK.GOLD if can else Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
		UIK.outlined(lab, 6)
		lab.position = Vector2(p.x - 110, p.y + half + 4)
		lab.size = Vector2(220, 22)
		lab.mouse_filter = Control.MOUSE_FILTER_IGNORE
		inner.add_child(lab)
	if here:
		var you := TextureRect.new()
		you.texture = UIK.tex("res://assets/ui/%s_icon.png" % G.char)
		you.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		you.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		you.size = Vector2(56, 56)
		you.position = p + Vector2(-28, -half - 66)
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
	elif ev is InputEventJoypadMotion:
		if ev.axis == JOY_AXIS_RIGHT_Y and absf(ev.axis_value) > 0.15:
			_sc.scroll_vertical += int(ev.axis_value * 14.0)
	elif ev is InputEventJoypadButton and ev.pressed:
		match ev.button_index:
			JOY_BUTTON_LEFT_SHOULDER: _scroll_by(-280)
			JOY_BUTTON_RIGHT_SHOULDER: _scroll_by(280)
			JOY_BUTTON_DPAD_UP: _scroll_by(-160)
			JOY_BUTTON_DPAD_DOWN: _scroll_by(160)


class MapPaths extends Control:
	var screen
	var G
	var avail: Array = []

	## Bézier cúbica con tangentes verticales (curva en S suave), recortada en el borde de cada sala.
	func _curve(a: Vector2, b: Vector2, ra: float, rb: float) -> PackedVector2Array:
		var dy := (b.y - a.y) * 0.5
		var c1 := Vector2(a.x, a.y + dy)
		var c2 := Vector2(b.x, b.y - dy)
		var pts := PackedVector2Array()
		for i in 41:
			var t := i / 40.0
			var u := 1.0 - t
			var pt := u * u * u * a + 3.0 * u * u * t * c1 + 3.0 * u * t * t * c2 + t * t * t * b
			if pt.distance_to(a) >= ra and pt.distance_to(b) >= rb:
				pts.append(pt)
		return pts

	func _stroke(pts: PackedVector2Array, col: Color, w: float, glow: bool = false) -> void:
		if pts.size() < 2:
			return
		draw_polyline(pts, Color(0, 0, 0, 0.55), w + 7.0, true)
		if glow:
			draw_polyline(pts, Color(col, 0.28), w + 8.0, true)
		draw_polyline(pts, col, w, true)

	func _r(n: Dictionary) -> float:
		return 62.0 if n.type == "boss" else (46.0 if n.type == "elite" else 42.0)

	func _draw() -> void:
		var all := []
		for row in G.map.rows:
			all.append_array(row)
		all.append(G.map.boss)
		var start := Vector2(640, MapScreen.MAP_H - 120)
		for sp in G.map.rows[0]:
			var b: Vector2 = screen._node_pos(sp)
			var open: bool = G.pos == null
			_stroke(_curve(start, b, 8.0, _r(sp)), Color("#fff2b0") if open else Color("#f0cf7a"), 5.0 if open else 4.0, open)
		for n in all:
			for m in n.next:
				var a2: Vector2 = screen._node_pos(n)
				var b2: Vector2 = screen._node_pos(m)
				var used: bool = n.visited and m.visited
				var open: bool = G.pos != null and is_same(G.pos, n) and avail.any(func(x): return is_same(x, m))
				var col := Color("#f0cf7a") if used else (Color("#fff2b0") if open else Color("#c9c0ec", 0.5))
				_stroke(_curve(a2, b2, _r(n), _r(m)), col, 5.0 if (used or open) else 3.0, open)
