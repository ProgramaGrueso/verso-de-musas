class_name EventScreen
extends Control
## Eventos aleatorios del camino: arte a la izquierda, texto y opciones a la derecha.

var _text: RichTextLabel
var _opts: VBoxContainer


func _ready() -> void:
	var G = Meta.run
	Sfx.music("rest", G.act)
	var ev := RunGen.pick_event(G)
	add_child(UIK.backdrop(G.act))
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.04, 0.06, 0.86)
	UIK.full_rect(dark)
	add_child(dark)
	_build_art(ev)
	var col := VBoxContainer.new()
	col.position = Vector2(700, 96)
	col.size = Vector2(530, 560)
	col.add_theme_constant_override("separation", 14)
	add_child(col)
	var t := UIK.label(ev.title, 36, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t, 6)
	col.add_child(t)
	_text = UIK.rich("[center]%s[/center]" % EventsLogic.text_for(G, ev), 20, Color("#e8e4f4"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_text)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	col.add_child(sp)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 12)
	col.add_child(_opts)
	var ctx := EvCtx.new()
	var first_opt: Button = null
	for o in EventsLogic.options(G, ev.id):
		var b := _banner(o.t, o.hint)
		b.disabled = not o.ok
		if first_opt == null and not b.disabled:
			first_opt = b
		var opt: Dictionary = o
		b.pressed.connect(func():
			if opt.has("fight"):
				Nav.combat(opt.fight_ids if opt.has("fight_ids") else RunGen.encounter_game(G, opt.fight), opt.fight)
				return
			for c in _opts.get_children():
				if c is Button:
					c.disabled = true
			var res: String = await opt.run.call(ctx)
			Main.I.update_top()
			if G.hp <= 0:
				G.hp = 1
			_text.text = "[center]%s[/center]" % EventsLogic.md(res)
			for c in _opts.get_children():
				c.queue_free()
			var cb := _banner("Continuar ➜", "")
			cb.pressed.connect(func(): Nav.node_done(false))
			_opts.add_child(cb)
			cb.grab_focus.call_deferred())
		_opts.add_child(b)
	if first_opt != null:
		first_opt.grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func _build_art(ev: Dictionary) -> void:
	var rect := Rect2(50, 86, 610, 580)
	var tex := UIK.tex("res://assets/bg/ev_%s.webp" % ev.id)
	var holder := Control.new()
	holder.position = rect.position
	holder.size = rect.size
	holder.clip_contents = true
	add_child(holder)
	if tex != null:
		var r := TextureRect.new()
		r.texture = tex
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		r.size = rect.size
		holder.add_child(r)
		# desvanece los bordes hacia el fondo oscuro
		var edge := Color(0.03, 0.04, 0.06, 1.0)
		var clear := Color(edge, 0.0)
		for spec in [["l", true, [[0.0, edge], [1.0, clear]], Vector2(0, 0), Vector2(110, rect.size.y)],
				["r", true, [[0.0, clear], [1.0, edge]], Vector2(rect.size.x - 110, 0), Vector2(110, rect.size.y)],
				["t", false, [[0.0, edge], [1.0, clear]], Vector2(0, 0), Vector2(rect.size.x, 90)],
				["b", false, [[0.0, clear], [1.0, edge]], Vector2(0, rect.size.y - 110), Vector2(rect.size.x, 110)]]:
			var g := TextureRect.new()
			g.texture = UIK.grad_tex(spec[2], spec[1])
			g.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			g.stretch_mode = TextureRect.STRETCH_SCALE
			g.position = spec[3]
			g.size = spec[4]
			holder.add_child(g)
	else:
		holder.add_child(UIK.label(ev.img, 160, Color.WHITE, "sans", HORIZONTAL_ALIGNMENT_CENTER))


## Opción en forma de cartel verde azulado con título dorado y descripción.
static func _banner(title: String, hint: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	b.custom_minimum_size = Vector2(0, 78 if hint != "" else 54)
	var n := UIK.stylebox(Color("#1c3a44"), Color("#52858c"), 2, 16, 6)
	var h := UIK.stylebox(Color("#27505c"), Color("#9fd6dc"), 2, 16, 10)
	var d := UIK.stylebox(Color("#14222a"), Color("#2c444a"), 2, 16, 0)
	for st in [n, h, d]:
		st.content_margin_left = 22
		st.content_margin_right = 22
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play("select_soft", 0.4))
	b.pressed.connect(func(): Sfx.play("click"))
	var r := UIK.rich("[b][color=#f0cf7a]%s[/color][/b]%s" % [title, ("\n" + _tint(hint)) if hint != "" else ""], 19, Color("#e8f2f2"))
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	r.offset_left = 22
	r.offset_right = -22
	r.offset_top = 8
	r.fit_content = false
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(r)
	return b


## Colorea cifras de oro (dorado) y de PV (rojo si se pierden, verde si se ganan).
static func _tint(h: String) -> String:
	var good := h.begins_with("Recuperas") or h.begins_with("+")
	var rx := RegEx.new()
	rx.compile("(\\d+ ?%?)( de oro| PV máx\\.| PV)")
	var out := ""
	var last := 0
	for m in rx.search_all(h):
		out += h.substr(last, m.get_start() - last)
		var unit: String = m.get_string(2)
		var col := "#f0cf7a" if unit.contains("oro") else ("#8bf0a4" if (good or unit.contains("máx")) else "#ff7b85")
		out += "[color=%s]%s%s[/color]" % [col, m.get_string(1), unit]
		last = m.get_end()
	return out + h.substr(last)


class EvCtx extends RefCounted:
	func pick_card(title: String, filter: Callable, n: int, upgrade_preview: bool = false) -> Array:
		var G = Meta.run
		var cards: Array = G.deck.filter(filter)
		return await Dlg.pick_cards({"title": title, "upgradePreview": upgrade_preview, "cards": cards, "n": n, "cancel": "Cancelar"})

	## Elegir 1 carta nueva entre `ids` (no están en el mazo). Devuelve [] si se salta.
	func choose_new(title: String, ids: Array) -> Array:
		var G = Meta.run
		if ids.is_empty():
			return []
		var cards := []
		for id in ids:
			var c := Eng.make_card(G, id)
			if Eng.has_relic(G, "huevo") and Eng.can_upgrade(c):
				c.up = true
			cards.append(c)
		return await Dlg.pick_cards({"title": title, "sub": "Se añadirá a tu mazo.", "cards": cards, "n": 1, "cancel": "Saltar", "big": true, "confirmLabel": "Tomar carta"})
