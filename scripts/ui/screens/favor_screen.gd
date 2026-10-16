class_name FavorScreen
extends Control
## Favor de las Musas: al empezar cada acto se elige 1 de 3 bendiciones.

const KIND_LABEL := {"buff": "BENDICIÓN DEL ACTO", "trade": "PACTO", "card": "REGALO"}
const KIND_COLOR := {"buff": Color("#8bf0a4"), "trade": Color("#ff9a6b"), "card": Color("#9fd6dc")}


func _ready() -> void:
	var G = Meta.run
	Sfx.music("rest", G.act)
	add_child(UIK.backdrop(G.act))
	add_child(UIK.shade(0.45, 0.8))
	var col := UIK.center_col(self, 18)
	var t := UIK.label("Favor de las Musas", 48, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t, 10)
	col.add_child(t)
	var sub := UIK.label("%s · Elige la bendición que te acompañará." % DB.acts[G.act - 1].name, 22, Color("#dddddd"), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(sub, 5)
	col.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var opts := Favors.offer(G).filter(func(i): return Favors.available(G, i))
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
	var skip := UIK.button("Rechazar los favores", "", 20)
	skip.pressed.connect(func(): Nav.map(true))
	col.add_child(skip)
	if not btns.is_empty():
		btns[0].grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func _card(id: String) -> Button:
	var d: Dictionary = Favors.DEFS[id]
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(320, 300)
	var n := UIK.stylebox(Color("#1c3a44"), Color("#52858c"), 2, 16, 6)
	var h := UIK.stylebox(Color("#27505c"), Color("#f0cf7a"), 3, 16, 12)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.mouse_entered.connect(func(): Sfx.play("select_soft", 0.4))
	b.pressed.connect(func(): Sfx.play("click"))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 20
	v.offset_right = -20
	v.offset_top = 18
	v.offset_bottom = -14
	v.add_theme_constant_override("separation", 10)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(v)
	v.add_child(UIK.label(KIND_LABEL[d.kind], 15, KIND_COLOR[d.kind], "sans", HORIZONTAL_ALIGNMENT_CENTER))
	v.add_child(UIK.label(d.icon, 54, Color.WHITE, "sans", HORIZONTAL_ALIGNMENT_CENTER))
	var nm := UIK.label(d.name, 26, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(nm)
	var tx := UIK.rich("[center]%s[/center]" % d.desc, 19, Color("#e8f2f2"))
	tx.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tx.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tx)
	return b
