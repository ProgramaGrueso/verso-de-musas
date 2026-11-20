class_name ShopScreen
extends Control
## Tienda del Mercader.

var _shop: Dictionary
var _root: VBoxContainer          # contenido que se reconstruye en cada compra
var _deferred_grab: Control       # control que se queda con el foco en el siguiente proceso (o null)


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


## Doble cambio diferido (fin de proceso): así el foco aterriza DESPUÉS de quien lo pida más tarde
## ese mismo proceso (el Overlay al cerrarse devuelve el foco a «lo de detrás») y sobre un control ya
## asentado en el árbol. En un `call_deferred` que se ejecuta antes del cierre del diálogo, el grab
## quedaría en un nodo que aún está bloqueado por el modal (FOCUS_NONE) y el mando se quedaría sin foco.
func _grab_next(c: Control) -> void:
	if c == null or not is_instance_valid(c) or c.is_queued_for_deletion():
		return
	if _deferred_grab != c:
		_deferred_grab = c
		_grab_deferred()


func _grab_deferred() -> void:
	await get_tree().process_frame
	if not is_inside_tree():
		return
	await get_tree().process_frame
	var c := _deferred_grab
	_deferred_grab = null
	# nunca se pide el foco a algo liberado o en cola de borrado (por ejemplo, la carta vendida)
	if c == null or not is_instance_valid(c) or c.is_queued_for_deletion() or not c.is_visible_in_tree():
		c = _first_focus()
	if c != null:
		c.grab_focus()


## Primer control que puede recibir foco: las cartas en venta y, si no queda ninguna, «Salir de la tienda».
func _first_focus() -> Control:
	for c in _focusables():
		if _is_card(c) and not c.is_queued_for_deletion() and c.focus_mode != Control.FOCUS_NONE:
			return c
	for c in _focusables():
		if c is Button and not (c as Button).disabled and not c.is_queued_for_deletion() and c.focus_mode != Control.FOCUS_NONE:
			if not _is_card(c):
				return c
	return null


func _is_card(c: Control) -> bool:
	return c is CardView


func _focusables() -> Array:
	var out := []
	var stack := [_root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			if ch is Control and (ch as Control).focus_mode != Control.FOCUS_NONE:
				out.append(ch)
			stack.push_back(ch)
	return out


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
	var leave := UIK.button("Salir de la tienda ➜", "big")
	leave.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	leave.pressed.connect(func(): Nav.node_done(false))
	_root.add_child(leave)
	_fit_root(t, leave)
	# Al terminar, el foco vuelve al primer artículo en venta (o a «Salir de la tienda»): tras vender algo
	# el artículo que tenía el foco se reconstruye, y el diálogo cerrado lo deja sin foco. Se pide con
	# `_grab_next`, que espera al final del fotograma (cuando el Overlay ya devolvió el foco) y comprueba
	# que el control sigue siendo válido antes de pedirlo, así nunca se pide el foco a un nodo liberado.
	var first := _first_focus()
	if first != null:
		_grab_next(first)


## Con el texto grande (115-130 %) la columna no cabe en los 720 px y «Salir de la tienda» quedaba por debajo
## del borde. Se mide ya maquetada y, mientras sobre, cede por orden: aire entre bloques, el tamaño «big» del
## botón de salir y el título (decorativo). El rótulo nunca pisa los iconos de reliquias de la barra superior.
const ROOT_BOTTOM := 712.0

func _fit_root(title: Label, leave: Button) -> void:
	UIK.fit_title(title, 860.0, 22)
	for step in 3:
		await get_tree().process_frame
		if not is_instance_valid(title) or not is_instance_valid(leave) or leave.is_queued_for_deletion():
			return
		var need := _root.get_combined_minimum_size().y
		var over := _root.position.y + need - ROOT_BOTTOM
		if over <= 0.0:
			return
		match step:
			0:
				_root.add_theme_constant_override("separation", 4)
			1:
				var fs := UIK.ts(24)
				leave.set_meta("fit_base", fs)
				leave.add_theme_font_size_override("font_size", fs)
				for st in ["normal", "hover", "pressed", "disabled", "focus"]:
					var sb := leave.get_theme_stylebox(st) as StyleBoxFlat
					if sb != null:
						sb.content_margin_top = 10
						sb.content_margin_bottom = 10
						sb.content_margin_left = 28
						sb.content_margin_right = 28
				leave.update_minimum_size()
			2:
				var f := title.get_theme_font("font")
				var fs2 := int(title.get_theme_font_size("font_size"))
				while fs2 > 22 and f.get_height(int(title.get_theme_font_size("font_size"))) - f.get_height(fs2) < over:
					fs2 -= 1
				title.add_theme_font_size_override("font_size", fs2)


## Tras comprar/vender: la tienda se reconstruye (los botones viejos se liberan) y el foco vuelve
## al primer artículo en venta, no a un nodo en cola de borrado.
func _after_purchase() -> void:
	_render()


func _card_item(it: Dictionary, w: float) -> Control:
	var G = Meta.run
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	var shown := Eng.make_card(G, it.id)
	if Eng.has_relic(G, "huevo") and Eng.can_upgrade(shown):
		shown.up = true   # el Huevo de Grifo: se ve como llegará al mazo
	var cv := CardView.create(shown, null, w)
	if it.sold:
		cv.modulate = Color(1, 1, 1, 0.25)
		cv.focus_mode = Control.FOCUS_NONE
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
				Eng.gain_card(G, item.id)
				Sfx.play("coin")
				_after_purchase())
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
		_after_purchase())
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 6)
	sv.add_child(UIK.label("Servicio", 18, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER))
	sv.add_child(rb)
	sv.add_child(_price_tag(rm.price, G.gold))
	mid.add_child(_box_wrap(sv))


func on_escape() -> void:
	Nav.node_done(false)


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
	if b.icon == null:
		b.text = Icons.emoji(parts[0], parts[1])
		b.add_theme_font_override("font", UIK.font())
		b.add_theme_font_size_override("font_size", 38)
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
				_after_purchase())
		col.add_child(b)
		col.add_child(_price_tag(it.price, G.gold))
		out.append(col)
	return out
