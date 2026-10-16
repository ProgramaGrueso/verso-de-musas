class_name ShopScreen
extends Control
## Tienda del Mercader.

var _shop: Dictionary
var _root: VBoxContainer


func _ready() -> void:
	var G = Meta.run
	add_child(UIK.backdrop(G.act))
	add_child(UIK.shade(0.4, 0.7))
	Sfx.music("shop", G.act)
	_shop = RunGen.gen_shop(G)
	_root = VBoxContainer.new()
	_root.position = Vector2(40, 64)
	_root.size = Vector2(1200, 640)
	_root.add_theme_constant_override("separation", 10)
	add_child(_root)
	_render()
	UIK.fade_in(self, 0.3)


func _price_tag(price: int, gold: int) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIK.stylebox(Color(0, 0, 0, 0.65), UIK.GOLD if gold >= price else Color("#ff6b75"), 1, 14, 0))
	var l := Icons.with_text("ui", "gold", "%d" % price, 22, 22, UIK.GOLD if gold >= price else Color("#ff6b75"))
	p.add_child(l)
	p.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return p


func _render() -> void:
	var G = Meta.run
	Main.I.update_top()
	for c in _root.get_children():
		c.queue_free()
	var t := UIK.label("La Tienda del Mercader · tienes %d de oro" % G.gold, 32, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t, 8)
	_root.add_child(t)
	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", 18)
	_root.add_child(cards)
	for it in _shop.cards:
		cards.add_child(_card_item(it, 142.0))
	var mid := HBoxContainer.new()
	mid.alignment = BoxContainer.ALIGNMENT_CENTER
	mid.add_theme_constant_override("separation", 22)
	_root.add_child(mid)
	if not _shop.neutral.is_empty():
		var nrow := HBoxContainer.new()
		nrow.add_theme_constant_override("separation", 12)
		for it in _shop.neutral:
			nrow.add_child(_card_item(it, 112.0))
		var nv := VBoxContainer.new()
		nv.add_theme_constant_override("separation", 6)
		nv.add_child(UIK.label("Cartas neutrales", 18, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER))
		nv.add_child(nrow)
		mid.add_child(_box_wrap(nv))
	mid.add_child(_box("Reliquias", _items(_shop.relics, "relic")))
	mid.add_child(_box("Pociones", _items(_shop.potions, "potion")))
	_render_service(mid)


func _card_item(it: Dictionary, w: float) -> Control:
	var G = Meta.run
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var cv := CardView.create(Eng.make_card(G, it.id), null, w)
	if true:
		if it.sold:
			cv.modulate = Color(1, 1, 1, 0.25)
		else:
			var item: Dictionary = it
			cv.pressed.connect(func(_v):
				if G.gold < item.price:
					Sfx.play("error")
					Main.I.toast("No tienes suficiente oro.")
					return
				if await Dlg.confirm("¿Comprar [b][color=#f0cf7a]%s[/color][/b] por %d de oro?" % [DB.cards[item.id].name, item.price]):
					G.gold -= item.price
					item.sold = true
					G.deck.append(Eng.make_card(G, item.id))
					Sfx.play("coin")
					_render())
	col.add_child(cv)
	col.add_child(_price_tag(it.price, G.gold))
	return col


func _render_service(mid: Control) -> void:
	var G = Meta.run
	var rm: Dictionary = _shop.remove
	var rb := _mini("ui:burn", "[b][color=#f0cf7a]Eliminar una carta[/color][/b]\nQuita una carta de tu mazo para hacerlo más fuerte.")
	if rm.used:
		rb.disabled = true
	rb.pressed.connect(func():
		if G.gold < rm.price:
			Sfx.play("error")
			Main.I.toast("No tienes suficiente oro.")
			return
		var pick: Array = await Dlg.pick_cards({"title": "Elige una carta para eliminar", "cards": G.deck.duplicate(), "n": 1, "cancel": "Cancelar", "confirmLabel": "Eliminar"})
		if pick.is_empty():
			return
		G.deck = G.deck.filter(func(c): return c.uid != pick[0].uid)
		G.gold -= rm.price
		rm.used = true
		G.removed = G.get("removed", 0) + 1
		Sfx.play("coin")
		_render())
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sv.add_child(UIK.label("Servicio", 18, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(rb)
	sv.add_child(_price_tag(rm.price, G.gold))
	mid.add_child(_box_wrap(sv))
	var leave := UIK.button("Salir de la tienda ➜", "big")
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func(): Nav.node_done(false))
	_root.add_child(leave)


func _box_wrap(inner: Control) -> Control:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UIK.stylebox(Color(0.05, 0.04, 0.1, 0.7), Color("#4a3f6b"), 2, 14, 0))
	var m := MarginContainer.new()
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	m.add_child(inner)
	p.add_child(m)
	return p


func _box(title: String, items: Array) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.add_child(UIK.label(title, 18, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	for it in items:
		row.add_child(it)
	v.add_child(row)
	return _box_wrap(v)


func _mini(icon: String, tip_text: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(76, 76)
	var parts := icon.split(":")
	b.icon = Icons.tex(parts[0], parts[1])
	b.expand_icon = true
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.add_theme_constant_override("icon_max_width", 62)
	for c in ["icon_disabled_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color", "icon_normal_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	var sb := UIK.stylebox(Color("#2a2140"), Color("#4a3f6b"), 2, 14, 4)
	var sbh := UIK.stylebox(Color("#3a2e5c"), UIK.GOLD, 2, 14, 8)
	var sbd := UIK.stylebox(Color("#16121f"), Color("#2a2540"), 2, 14, 0)
	for st in ["normal", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	UIK.tip(b, tip_text)
	return b


func _items(list: Array, kind: String) -> Array:
	var G = Meta.run
	var out := []
	for it in list:
		var item: Dictionary = it
		var info: Dictionary = DB.relics[it.id] if kind == "relic" else DB.potions[it.id]
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 6)
		var b := _mini(("relic:" if kind == "relic" else "potion:") + it.id, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [info.n, info.d])
		if it.sold:
			b.disabled = true
		b.pressed.connect(func():
			if G.gold < item.price:
				Sfx.play("error")
				Main.I.toast("No tienes suficiente oro.")
				return
			if kind == "potion" and not G.potions.has(null):
				Main.I.toast("Tienes todas las pociones llenas.")
				return
			var extra := "\n[font_size=16]%s[/font_size]" % info.d if kind == "relic" else ""
			if await Dlg.confirm("¿Comprar [b][color=#f0cf7a]%s[/color][/b] por %d de oro?%s" % [info.n, item.price, extra]):
				G.gold -= item.price
				item.sold = true
				if kind == "relic":
					Eng.add_relic(G, item.id)
				else:
					G.potions[G.potions.find(null)] = item.id
				Sfx.play("coin")
				_render())
		col.add_child(b)
		col.add_child(_price_tag(it.price, G.gold))
		out.append(col)
	return out
