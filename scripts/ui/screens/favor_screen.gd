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
		if G.get("seeded", false):
			# con semilla fija (partidas con semilla y reto diario) la entidad también es la misma para todos
			n = absi(Eng.act_seed(G.seed, G.act)) % (ENTITY.size() - 1) + 1
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
	fade.texture = UIK.grad_tex([[0.0, Color(0.02, 0.02, 0.05, 0.0)], [0.4, Color(0.02, 0.02, 0.05, 0.0)], [0.58, Color(0.02, 0.02, 0.05, 0.9)], [1.0, Color(0.02, 0.02, 0.05, 1.0)]])
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
	who.position = Vector2(0, 280)
	who.size = Vector2(1280, 34)
	who.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(who)
	var line := UIK.label(ent.line, 20, Color("#e8e4f4"), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(line, 5)
	line.position = Vector2(140, 318)
	line.size = Vector2(1000, 44)   # dos líneas: las frases largas se parten, no se salen
	line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	add_child(line)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.position = Vector2(50, 394)
	row.size = Vector2(1180, 280)
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
	skip.position = Vector2(640 - 150, 680)   # centrado y con su alto natural (texto + márgenes)
	skip.custom_minimum_size = Vector2(300, 0)
	skip.size = skip.get_combined_minimum_size()
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


const CARD := Vector2(372, 280)


## Carta de favor: ilustración a todo el fondo, cinta de tipo, marco dorado y elevación al señalarla.
func _card(id: String) -> Button:
	var d: Dictionary = Favors.DEFS[id]
	var kc: Color = KIND_COLOR[d.kind]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = CARD
	b.pivot_offset = CARD / 2
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	# fondo recortado con esquinas redondeadas
	var clip := Panel.new()
	clip.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	clip.add_theme_stylebox_override("panel", UIK.stylebox(Color("#0b0912"), Color(0, 0, 0, 0), 0, 14, 0))
	clip.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(clip)
	var art := TextureRect.new()
	art.texture = UIK.tex(Favors.icon_path(id))
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(-14, -34)
	art.size = Vector2(CARD.x + 28, CARD.x + 28)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(art)
	var shade := TextureRect.new()
	shade.texture = UIK.grad_tex([[0.0, Color(0.03, 0.02, 0.06, 0.0)], [0.42, Color(0.03, 0.02, 0.06, 0.1)], [0.66, Color(0.03, 0.02, 0.06, 0.9)], [1.0, Color(0.03, 0.02, 0.06, 0.98)]])
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	UIK.full_rect(shade)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip.add_child(shade)
	# cinta de tipo
	var rib := PanelContainer.new()
	var rs := UIK.stylebox(Color(kc.darkened(0.65), 0.92), kc, 1, 8, 0)
	rs.content_margin_left = 12
	rs.content_margin_right = 12
	rs.content_margin_top = 3
	rs.content_margin_bottom = 3
	rib.add_theme_stylebox_override("panel", rs)
	rib.position = Vector2(14, 14)
	rib.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rl := UIK.label(KIND_LABEL[d.kind], 13, kc.lightened(0.35))
	rib.add_child(rl)
	b.add_child(rib)
	# texto
	var v := VBoxContainer.new()
	v.position = Vector2(20, 142)
	v.size = Vector2(CARD.x - 40, 118)
	v.add_theme_constant_override("separation", 4)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	var nm := UIK.label(d.name, 22, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(nm, 6, Color(0, 0, 0, 0.8))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var sep := ColorRect.new()
	sep.color = Color(UIK.GOLD, 0.45)
	sep.custom_minimum_size = Vector2(0, 1)
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(sep)
	var tx := UIK.rich("[center]%s[/center]" % d.desc, 17, Color("#ece6f6"))
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tx)
	# marco dorado (encima de todo)
	var frame := Panel.new()
	frame.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var fn := UIK.stylebox(Color(0, 0, 0, 0), Color("#a98a47"), 2, 14, 0)
	var fh := UIK.stylebox(Color(0, 0, 0, 0), Color("#ffe9a0"), 4, 14, 0)
	frame.add_theme_stylebox_override("panel", fn)
	b.add_child(frame)
	var inner := Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	inner.offset_left = 6
	inner.offset_top = 6
	inner.offset_right = -6
	inner.offset_bottom = -6
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inner.add_theme_stylebox_override("panel", UIK.stylebox(Color(0, 0, 0, 0), Color(UIK.GOLD, 0.25), 1, 10, 0))
	b.add_child(inner)
	var hov := func(on: bool):
		frame.add_theme_stylebox_override("panel", fh if on else fn)
		var tw := b.create_tween().set_parallel(true).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "scale", Vector2.ONE * (1.05 if on else 1.0), 0.18)
		tw.tween_property(art, "position:y", -44.0 if on else -34.0, 0.25)
		b.z_index = 5 if on else 0
	b.mouse_entered.connect(func(): hov.call(true); Sfx.play("select_soft", 0.4))
	b.mouse_exited.connect(func(): if not b.has_focus(): hov.call(false))
	b.focus_entered.connect(func(): hov.call(true))
	b.focus_exited.connect(func(): hov.call(false))
	b.pressed.connect(func(): Sfx.play("click"))
	return b
