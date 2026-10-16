class_name FavorScreen
extends Control
## Favor de las Musas: al empezar cada acto se elige 1 de 3 bendiciones.

const KIND_LABEL := {"buff": "BENDICIÓN DEL ACTO", "trade": "PACTO", "card": "REGALO"}
const KIND_COLOR := {"buff": Color("#8bf0a4"), "trade": Color("#ff9a6b"), "card": Color("#9fd6dc")}


## Seis entidades. La primera (la del inicio de la partida) es siempre la Dama de las Mareas; el resto se elige al azar.
const ENTITY := [
	{"name": "La Dama de las Mareas", "line": "«Los abismos recuerdan a quien los cruza. Toma mi favor, viajera.»", "color": Color("#4fd0d8")},
	{"name": "El Ciervo Antiguo", "line": "«El bosque da y el bosque cobra. Elige lo que estés dispuesta a pagar.»", "color": Color("#8bf0a4")},
	{"name": "La Reina Dorada", "line": "«Una bendición antes del trono. No la desperdicies.»", "color": Color("#f0cf7a")},
	{"name": "El Ángel Caído", "line": "«Caí por elegir. Te ofrezco lo mismo: elige, y paga.»", "color": Color("#c9c4d8")},
	{"name": "El Demonio Cortés", "line": "«Un trato justo, querida. Yo pongo el poder; tú, el precio.»", "color": Color("#ff6b5a")},
	{"name": "El Ente de la Luna Violeta", "line": "«Sueño con quienes aún no han caído. Acepta mi velo.»", "color": Color("#b58cff")},
]


## Elige la entidad: la primera vez de la partida siempre la 0; después, una al azar distinta a la última.
static func pick_entity(G) -> int:
	if not G.has("entity"):
		G["entity"] = 0
	else:
		var n := randi() % (ENTITY.size() - 1) + 1
		if n == G.entity:
			n = n % (ENTITY.size() - 1) + 1
		G["entity"] = n
	return G.entity


func _ready() -> void:
	var G = Meta.run
	var ei := pick_entity(G)
	var ent: Dictionary = ENTITY[ei]
	Sfx.music("rest", G.act)
	add_child(UIK.backdrop(G.act))
	# arte de la entidad que concede el favor (assets/bg/favor_<acto>.webp); si falta, un emblema luminoso
	var art := UIK.tex("res://assets/bg/favor_%d.webp" % (ei + 1))
	if art != null:
		var t := TextureRect.new()
		t.texture = art
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		UIK.full_rect(t)
		add_child(t)
	else:
		add_child(_emblem(ent.color))
	# degradado oscuro hacia abajo: separa el arte de las opciones
	var fade := TextureRect.new()
	fade.texture = UIK.grad_tex([[0.0, Color(0.02, 0.02, 0.05, 0.0)], [0.5, Color(0.02, 0.02, 0.05, 0.0)], [0.66, Color(0.02, 0.02, 0.05, 0.92)], [1.0, Color(0.02, 0.02, 0.05, 1.0)]])
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	UIK.full_rect(fade)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(fade)
	var title := UIK.label("Favor de las Musas", 30, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT)
	UIK.outlined(title, 8)
	title.position = Vector2(50, 96)
	title.size = Vector2(500, 44)
	add_child(title)
	var who := UIK.label(ent.name, 24, ent.color, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(who, 6)
	who.position = Vector2(0, 340)
	who.size = Vector2(1280, 34)
	add_child(who)
	var line := UIK.label(ent.line, 20, Color("#e8e4f4"), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(line, 5)
	line.position = Vector2(140, 380)
	line.size = Vector2(1000, 32)
	add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(50, 440)
	row.size = Vector2(1180, 200)
	add_child(row)
	var opts := Favors.offer(G, ei)
	var btns := []
	for id in opts:
		var b := _card(id)
		b.pressed.connect(func():
			for x in btns:
				x.disabled = true
			Sfx.play("heal")
			Main.I.toast(Favors.choose(G, id))
			Main.I.update_top()
			await get_tree().create_timer(0.4).timeout
			Nav.map(true))
		btns.append(b)
		row.add_child(b)
	var skip := UIK.button("Rechazar los favores", "", 18)
	skip.position = Vector2(490, 656)
	skip.size = Vector2(300, 46)
	skip.pressed.connect(func(): Nav.map(true))
	add_child(skip)
	if not btns.is_empty():
		btns[0].grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


## Emblema de reserva: halo radial con una silueta alada.
func _emblem(col: Color) -> Control:
	var c := Control.new()
	UIK.full_rect(c)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var g := GradientTexture2D.new()
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(col, 0.55), Color(col, 0.0)])
	g.gradient = gr
	g.fill = GradientTexture2D.FILL_RADIAL
	g.fill_from = Vector2(0.5, 0.5)
	g.fill_to = Vector2(1.0, 0.5)
	var halo := TextureRect.new()
	halo.texture = g
	halo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	halo.position = Vector2(290, 20)
	halo.size = Vector2(700, 520)
	c.add_child(halo)
	var sig := UIK.label("✦", 260, Color(col, 0.9), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	sig.position = Vector2(0, 120)
	sig.size = Vector2(1280, 300)
	c.add_child(sig)
	return c


func _card(id: String) -> Button:
	var d: Dictionary = Favors.DEFS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(370, 200)
	var n := UIK.stylebox(Color("#1c3a44"), Color("#52858c"), 2, 16, 6)
	var h := UIK.stylebox(Color("#27505c"), Color("#f0cf7a"), 3, 16, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.mouse_entered.connect(func(): Sfx.play("select_soft", 0.4))
	b.pressed.connect(func(): Sfx.play("click"))
	var hb := HBoxContainer.new()
	hb.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hb.offset_left = 16
	hb.offset_right = -16
	hb.offset_top = 16
	hb.offset_bottom = -16
	hb.add_theme_constant_override("separation", 14)
	hb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(hb)
	# icono ilustrado
	var frame := Panel.new()
	frame.custom_minimum_size = Vector2(112, 112)
	frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	frame.add_theme_stylebox_override("panel", UIK.stylebox(Color("#0c1418"), KIND_COLOR[d.kind], 2, 14, 0))
	frame.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var tr := TextureRect.new()
	tr.texture = UIK.tex(Favors.icon_path(id))
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.size = Vector2(112, 112)
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(tr)
	hb.add_child(frame)
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 6)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hb.add_child(v)
	v.add_child(UIK.label(KIND_LABEL[d.kind], 14, KIND_COLOR[d.kind], "sans", HORIZONTAL_ALIGNMENT_LEFT))
	var nm := UIK.label(d.name, 22, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_LEFT)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var tx := UIK.rich(d.desc, 17, Color("#e8f2f2"))
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tx)
	return b
