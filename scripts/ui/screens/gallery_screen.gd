class_name GalleryScreen
extends Control
## Galería de la Aguja: capítulos de historia que se desbloquean con hazañas.

var from_run := false


func _ready() -> void:
	Sfx.music("menu", 1, TitleScreen.last_char if TitleScreen.last_char != "" else "zafiro")
	var bg := ColorRect.new()
	bg.color = Color("#0a0814")
	UIK.full_rect(bg)
	add_child(bg)
	var un := 0
	for l in DB.lore:
		if Meta.is_unlocked(l.id):
			un += 1
	var head := HBoxContainer.new()
	head.position = Vector2(40, 20)
	head.size = Vector2(1200, 70)
	add_child(head)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var title := UIK.label(tr("Galería de la Aguja"), 34, UIK.GOLD, "title")
	hv.add_child(title)
	var sub := UIK.label(tr("La historia del mundo se revela con tus hazañas · %d/%d desbloqueadas") % [un, DB.lore.size()], 17, UIK.DIM)
	hv.add_child(sub)
	head.add_child(hv)
	HistoryScreen.fit_head(title, sub, HistoryScreen.HEAD_MAX_H)
	if Meta.data.get("seenEnding", false):
		var r := UIK.button(tr("Ver el final"), "small")
		r.pressed.connect(func():
			var e := EndingScreen.new()
			e.char = Meta.data.get("lastWinner", "zafiro") if Meta.data.get("lastWinner", "") != "" else "zafiro"
			e.nm = 0
			e.replay = true
			Main.I.set_screen(e, "ending"))
		head.add_child(r)
	var cmp := UIK.button(tr("Compendio"), "small")
	cmp.pressed.connect(func(): Nav.compendium(from_run))
	head.add_child(cmp)
	var lg := UIK.button(tr("Logros"), "small")
	lg.pressed.connect(func(): Nav.achievements())
	lg.visible = not (Meta.run != null and from_run)
	head.add_child(lg)
	var back := UIK.button(tr("← Volver"), "small")
	back.pressed.connect(func(): Nav.map() if (Meta.run != null and from_run) else Nav.title())
	head.add_child(back)
	# título y subtítulo encogen para dejar sitio a los botones (en inglés «Achievements», «Watch the ending»…
	# son más anchos y empujaban «← Volver» fuera de la pantalla)
	var used := 0.0
	for c in head.get_children():
		if c != hv and (c as Control).visible:
			used += (c as Control).get_combined_minimum_size().x + head.get_theme_constant("separation")
	UIK.fit_title(title, head.size.x - used, 20)
	UIK.fit_title(sub, head.size.x - used, 12)
	var sc := ScrollContainer.new()
	sc.position = Vector2(30, 100)
	sc.size = Vector2(1220, 610)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	sc.add_child(grid)
	for i in DB.lore.size():
		grid.add_child(_tile(i))
	back.grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func on_escape() -> void:
	Nav.map() if (Meta.run != null and from_run) else Nav.title()


func _tile(i: int) -> Control:
	var l: Dictionary = DB.lore[i]
	var ok := Meta.is_unlocked(l.id)
	var pr := Meta.progress(l)
	var b := Button.new()
	b.custom_minimum_size = Vector2(290, 252)
	b.focus_mode = Control.FOCUS_ALL
	var sb := UIK.stylebox(Color("#161225"), UIK.GOLD if ok else Color("#3a3355"), 2, 12, 4)
	var sbh := UIK.stylebox(Color("#221b3a"), Color.WHITE if ok else Color("#6a5f90"), 2, 12, 8)
	for st in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	var v := VBoxContainer.new()
	UIK.full_rect(v)
	v.add_theme_constant_override("separation", 0)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var art := TextureRect.new()
	art.custom_minimum_size = Vector2(290, 150)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.clip_contents = true
	if ok:
		art.texture = UIK.tex("res://assets/lore/%s.webp" % l.id)
	else:
		art.texture = UIK.grad_tex([[0.0, Color("#2a1d4a")], [1.0, Color("#0b0814")]])
		art.stretch_mode = TextureRect.STRETCH_SCALE
		var ic := UIK.label(l.ico, 54, Color(1, 1, 1, 0.25), "sans", HORIZONTAL_ALIGNMENT_CENTER)
		ic.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)   # sigue al arte si éste cede alto
		ic.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		art.add_child(ic)
		var lk := Icons.rect("ui", "lock", 30)
		lk.position = Vector2(6, 4)
		art.add_child(lk)
	v.add_child(art)
	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 2)
	var m := MarginContainer.new()
	for s in ["left", "right", "top"]:
		m.add_theme_constant_override("margin_" + s, 10)
	m.add_child(info)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(m)
	var tl := UIK.label(l.title if ok else "???", 19, Color.WHITE, "bold")
	UIK.fit_title(tl, 266.0, 13)   # títulos largos («La Capitana de la Marea Baja») no se salen del marco
	info.add_child(tl)
	if ok:
		info.add_child(UIK.label(tr("Capítulo %d") % (i + 1), 15, UIK.DIM))
	else:
		var c := UIK.label(l.ch, 14, UIK.DIM)
		c.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		c.custom_minimum_size = Vector2(266, 0)
		info.add_child(c)
		var pb := ProgressBar.new()
		pb.max_value = l.t
		pb.value = pr
		pb.show_percentage = false
		pb.custom_minimum_size = Vector2(266, 8)
		info.add_child(pb)
		info.add_child(UIK.label("%d / %d" % [mini(pr, l.t), l.t], 13, UIK.DIM))
	b.add_child(v)
	# con el texto al 130 % el bloque de una casilla bloqueada (pista partida en líneas, barra y cuenta) no cabe
	# bajo los 150 px del arte: cede el arte (hasta 96 px), no el texto
	v.minimum_size_changed.connect(func():
		var over := v.get_combined_minimum_size().y - b.custom_minimum_size.y
		if over > 0.5 and art.custom_minimum_size.y > 96.0:
			art.custom_minimum_size.y = maxf(96.0, art.custom_minimum_size.y - ceilf(over)))
	if ok:
		b.pressed.connect(func(): _view(i))
	else:
		b.mouse_default_cursor_shape = Control.CURSOR_ARROW
	return b


func _view(i: int) -> void:
	var list := []
	for k in DB.lore.size():
		if Meta.is_unlocked(DB.lore[k].id):
			list.append(k)
	var at: int = list.find(i)
	var o := Dlg._overlay()
	var holder := Control.new()
	UIK.full_rect(holder)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(holder)
	var render := func(): pass
	render = func():
		for c in holder.get_children():
			c.queue_free()
		var k: int = list[at]
		var l: Dictionary = DB.lore[k]
		var row := HBoxContainer.new()
		row.position = Vector2(60, 60)
		row.size = Vector2(1160, 600)
		row.add_theme_constant_override("separation", 30)
		var art := TextureRect.new()
		art.texture = UIK.tex("res://assets/lore/%s.webp" % l.id)
		art.custom_minimum_size = Vector2(560, 560)
		art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		art.clip_contents = true
		row.add_child(art)
		var body := VBoxContainer.new()
		body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		body.alignment = BoxContainer.ALIGNMENT_CENTER
		body.add_theme_constant_override("separation", 14)
		body.add_child(UIK.label(tr("Capítulo %d de %d") % [k + 1, DB.lore.size()], 17, UIK.DIM))
		body.add_child(UIK.label(l.title, 38, UIK.GOLD, "title"))
		var t := UIK.rich(l.text, 22)
		t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(t)
		var nav := HBoxContainer.new()
		nav.add_theme_constant_override("separation", 10)
		var pv := UIK.button(tr("◀ Anterior"), "small")
		var nx := UIK.button(tr("Siguiente ▶"), "small")
		var cl := UIK.button(tr("Cerrar"), "small red")
		pv.disabled = at == 0
		nx.disabled = at == list.size() - 1
		pv.pressed.connect(func(): at -= 1; render.call())
		nx.pressed.connect(func(): at += 1; render.call())
		cl.pressed.connect(func(): o.close(null))
		nav.add_child(pv)
		nav.add_child(nx)
		nav.add_child(cl)
		body.add_child(nav)
		row.add_child(body)
		holder.add_child(row)
	render.call()
