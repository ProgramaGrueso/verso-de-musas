class_name Dlg
extends RefCounted
## Diálogos modales: elegir cartas, ver cartas, confirmar, mensajes, opciones, ayuda y pausa.


class Overlay extends Control:
	signal done(result)
	var cancel_result = null
	var allow_esc := true
	var _closed := false

	func _init() -> void:
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		mouse_filter = Control.MOUSE_FILTER_STOP
		var dim := ColorRect.new()
		dim.color = Color(0.02, 0.01, 0.05, 0.84)
		dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(dim)
		z_index = 2000

	func close(result = null) -> void:
		if _closed:
			return
		_closed = true
		Tip.hide_all()
		done.emit(result)
		queue_free()

	func _unhandled_input(ev: InputEvent) -> void:
		if not allow_esc:
			return
		var is_esc: bool = ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_ESCAPE
		var is_joy: bool = ev is InputEventJoypadButton and ev.pressed and (ev.button_index in [JOY_BUTTON_B, JOY_BUTTON_BACK])
		if is_esc or is_joy:
			get_viewport().set_input_as_handled()
			close(cancel_result)


static func _overlay() -> Overlay:
	var o := Overlay.new()
	Main.I.overlay_host.add_child(o)
	Tip.hide_all()
	return o


static func _center_col(o: Overlay, sep: int = 14) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	o.add_child(c)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	c.add_child(v)
	return v


static func _title(text: String, size: int = 38) -> Label:
	var l := UIK.label(text, size, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(l, 6)
	return l


static func _row(sep: int = 14) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", sep)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	return r


static func _card_grid(cards: Array, C, w: float, on_press: Callable = Callable()) -> Control:
	var cols := maxi(1, int(1160.0 / (w + 14.0)))
	var rows := ceili(float(cards.size()) / cols)
	var cw := w
	var ch := w * 1.42
	var content_h := rows * (ch + 14) + 30
	var grid := GridContainer.new()
	grid.columns = mini(cols, maxi(1, cards.size()))
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for inst in cards:
		var v := CardView.create(inst, C, cw)
		if on_press.is_valid():
			v.pressed.connect(on_press)
		grid.add_child(v)
	if content_h <= 500:
		var cc := CenterContainer.new()
		cc.add_child(grid)
		return cc
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(1200, 500)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_top", 14)
	m.add_child(grid)
	sc.add_child(m)
	return sc


# ---------- Confirmar / mensaje ----------
static func confirm(text: String, yes: String = "Sí", no: String = "No") -> bool:
	var o := _overlay()
	o.cancel_result = false
	var v := _center_col(o, 20)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	var r := UIK.rich("[center]%s[/center]" % text, 28)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(560, 0)
	col.add_child(r)
	var row := _row(16)
	var y := UIK.button(yes, "green")
	var n := UIK.button(no, "red")
	y.pressed.connect(func(): o.close(true))
	n.pressed.connect(func(): o.close(false))
	row.add_child(y)
	row.add_child(n)
	col.add_child(row)
	p.add_child(col)
	v.add_child(p)
	n.grab_focus.call_deferred()
	return await o.done


static func message(title: String, bbcode: String, btn: String = "Entendido", width: int = 760) -> void:
	var o := _overlay()
	var v := _center_col(o)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(_title(title, 32))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(width, 0)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var r := UIK.rich(bbcode, 19)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sc.add_child(r)
	sc.custom_minimum_size.y = 430
	col.add_child(sc)
	var b := UIK.button(btn)
	b.pressed.connect(func(): o.close(null))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	p.add_child(col)
	v.add_child(p)
	b.grab_focus.call_deferred()
	await o.done


# ---------- Cartas ----------
static func view_cards(title: String, cards: Array, C = null) -> void:
	var o := _overlay()
	var v := _center_col(o, 12)
	v.add_child(_title(title))
	if cards.is_empty():
		v.add_child(UIK.label("No hay cartas aquí.", 22, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER))
	else:
		v.add_child(_card_grid(cards, C, 158.0))
	var b := UIK.button("Cerrar")
	b.pressed.connect(func(): o.close(null))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	b.grab_focus.call_deferred()
	await o.done


## opts: title, sub, cards, n, cancel (texto o ""), big, confirmLabel, upgradePreview, C
static func pick_cards(opts: Dictionary) -> Array:
	var o := _overlay()
	o.cancel_result = []
	o.allow_esc = opts.get("cancel", "") != ""
	var v := _center_col(o, 10)
	v.add_child(_title(opts.title))
	if opts.get("sub", "") != "":
		v.add_child(UIK.label(opts.sub, 20, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER))
	var n: int = opts.get("n", 1)
	var sel: Array = []
	var views := {}
	var ok := UIK.button(opts.get("confirmLabel", "Confirmar"), "green")
	ok.disabled = true
	var upd := func():
		ok.disabled = sel.size() != n
		ok.text = opts.get("confirmLabel", "Confirmar") + ((" (%d/%d)" % [sel.size(), n]) if n > 1 else "")
	var w: float = 230.0 if opts.get("big", false) else 158.0
	var on_press := func(cv: CardView):
		Sfx.play("select")
		var uid: int = cv.inst.uid
		if uid in sel:
			sel.erase(uid)
			cv.set_selected(false)
		else:
			if sel.size() >= n:
				if n == 1:
					for u in sel:
						views[u].set_selected(false)
					sel.clear()
				else:
					return
			sel.append(uid)
			cv.set_selected(true)
		upd.call()
	var grid := _card_grid(opts.cards, opts.get("C", null), w, on_press)
	for cv in _find_cards(grid):
		views[cv.inst.uid] = cv
	v.add_child(grid)
	var all_cards := _find_cards(grid)
	if not all_cards.is_empty():
		all_cards[0].grab_focus.call_deferred()
	var row := _row(16)
	ok.pressed.connect(func():
		var chosen = opts.cards.filter(func(c): return c.uid in sel)
		if opts.get("upgradePreview", false) and chosen.size() == 1:
			if not await upgrade_compare(chosen[0], opts.get("C", null)):
				return
		o.close(chosen))
	row.add_child(ok)
	if opts.get("cancel", "") != "":
		var c := UIK.button(opts.cancel, "red")
		c.pressed.connect(func(): o.close([]))
		row.add_child(c)
	v.add_child(row)
	upd.call()
	return await o.done


static func _find_cards(n: Node) -> Array:
	var out := []
	for c in n.get_children():
		if c is CardView:
			out.append(c)
		else:
			out.append_array(_find_cards(c))
	return out


static func _strip(t: String) -> String:
	var rx := RegEx.new()
	rx.compile("\\[[^\\]]*\\]")
	return rx.sub(t, "", true)


static func upgrade_compare(inst: Dictionary, C = null) -> bool:
	var o := _overlay()
	o.cancel_result = false
	var v := _center_col(o, 14)
	v.add_child(_title("¿Mejorar esta carta?"))
	var row := _row(36)
	var up_inst := inst.duplicate()
	up_inst.up = true
	var a := Eng.card_def(inst)
	var b := Eng.card_def(up_inst)
	var parts := []
	if a.cost != b.cost:
		parts.append("Coste %s ➜ %s" % [str(a.cost), str(b.cost)])
	var la = CardText.lines(a, C).lines.map(_strip)
	var lb = CardText.lines(b, C).lines.map(_strip)
	for l in lb:
		if not (l in la):
			parts.append(l)
	for l in la:
		if not (l in lb) and (l.contains("Agotar") or l.contains("Retener") or l.contains("Innata")):
			parts.append("Pierde: " + l)
	var note := " · ".join(parts) if not parts.is_empty() else "Mejora los valores de la carta."
	for pair in [["Ahora", inst], ["Mejorada", up_inst]]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 8)
		col.add_child(UIK.label(pair[0], 22, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER))
		var cc := CenterContainer.new()
		cc.add_child(CardView.create(pair[1], C, 230.0))
		col.add_child(cc)
		if pair[1].up:
			var nl := UIK.label(note, 18, UIK.GOLD, "sans", HORIZONTAL_ALIGNMENT_CENTER)
			nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			nl.custom_minimum_size = Vector2(300, 0)
			col.add_child(nl)
		row.add_child(col)
		if pair[0] == "Ahora":
			row.add_child(UIK.label("➜", 72, UIK.GOLD, "bold"))
	v.add_child(row)
	var btns := _row(16)
	var yes := UIK.button("Mejorar", "green")
	var no := UIK.button("Cancelar", "red")
	yes.pressed.connect(func(): o.close(true))
	no.pressed.connect(func(): o.close(false))
	btns.add_child(yes)
	btns.add_child(no)
	v.add_child(btns)
	yes.grab_focus.call_deferred()
	return await o.done


# ---------- Opciones, ayuda y pausa ----------
static func _slider_row(label: String, value: float, on_change: Callable, icon_id: String = "") -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	if icon_id != "":
		r.add_child(Icons.frame("ui", icon_id, 46, UIK.GOLD, true))
	var l := UIK.label(label, 22, UIK.TEXT, "bold")
	l.custom_minimum_size = Vector2(190, 0)
	r.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.value = value * 100.0
	s.custom_minimum_size = Vector2(300, 28)
	s.value_changed.connect(func(x): on_change.call(x / 100.0))
	r.add_child(s)
	return r


static func _toggle_row(label: String, on: bool, text_on: String, text_off: String, on_change: Callable, icon_id: String = "") -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	if icon_id != "":
		r.add_child(Icons.frame("ui", icon_id, 46, UIK.GOLD, true))
	var l := UIK.label(label, 22, UIK.TEXT, "bold")
	l.custom_minimum_size = Vector2(190, 0)
	r.add_child(l)
	var cb := CheckButton.new()
	cb.button_pressed = on
	cb.text = text_on if on else text_off
	cb.add_theme_font_override("font", UIK.font())
	cb.add_theme_font_size_override("font_size", 18)
	cb.toggled.connect(func(p): cb.text = text_on if p else text_off; on_change.call(p))
	r.add_child(cb)
	return r


static func options() -> void:
	var o := _overlay()
	var v := _center_col(o)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(_title("Opciones", 32))
	col.add_child(_slider_row("Música", Meta.settings.music, func(x): Meta.settings.music = x; Sfx.apply_music_volume(); Meta.save_settings(), "music"))
	var sfx_row := _slider_row("Sonidos", Meta.settings.sfx, func(x): Meta.settings.sfx = x; Meta.save_settings(), "sound")
	(sfx_row.get_child(2) as HSlider).drag_ended.connect(func(_c): Sfx.play("hit"))
	col.add_child(sfx_row)
	col.add_child(_toggle_row("Jugar carta", Meta.settings.confirm, "Elegir y confirmar (más seguro)", "Un solo clic", func(x): Meta.settings.confirm = x; Meta.save_settings(), "hand"))
	col.add_child(_toggle_row("Animaciones", Meta.settings.fast, "Rápidas", "Normales", func(x): Meta.settings.fast = x; Meta.save_settings(), "speed"))
	var row := _row(14)
	var mr := UIK.button("Reiniciar música")
	mr.pressed.connect(func(): Sfx.restart_music())
	var fs := UIK.button("Pantalla completa")
	fs.pressed.connect(func(): Main.I._toggle_fullscreen())
	var cl := UIK.button("Cerrar")
	cl.pressed.connect(func(): o.close(null))
	row.add_child(mr)
	row.add_child(fs)
	row.add_child(cl)
	col.add_child(row)
	p.add_child(col)
	v.add_child(p)
	cl.grab_focus.call_deferred()
	await o.done


const HELP := """[b][color=#f0cf7a]Objetivo[/color][/b]
Sube la torre superando 3 zonas. Elige tu camino en el mapa, derrota enemigos y jefes, y mejora tu mazo de cartas.

[b][color=#f0cf7a]Tu turno[/color][/b]
• Tienes ⚡ energía (3 por turno). Cada carta tiene un coste en la esquina.
• Haz clic en una carta para elegirla y otra vez para jugarla (o arrástrala hacia arriba). Si la carta ataca a un enemigo concreto, haz clic en el enemigo.
• Encima de cada enemigo ves su intención: ⚔️ ataque (con el daño), 🛡️ defensa, ⬇️ te debilita, ⬆️ se fortalece.
• Pulsa Terminar turno cuando acabes. El Bloqueo 🛡️ te protege del daño solo durante un turno.

[b][color=#f0cf7a]Teclado[/color][/b]
← → eligen carta · ↑ ↓ cambian de enemigo · Enter o Espacio juegan · E termina el turno · Esc cancela. También 1–9 para elegir una carta. F11: pantalla completa.

[b][color=#f0cf7a]Mando (Xbox / Gamepad)[/color][/b]
Stick izquierdo / D-Pad: navegar cartas y menús · LB / RB: pasar cartas · A: jugar / confirmar · B: cancelar / volver · Y: terminar turno · X: mazo de robo · LT: poción · RT: descarte · Back / View: ver mazo · Start: menú de pausa.

[b][color=#f0cf7a]Tus personajes[/color][/b]
• [color=#ff8a93]Zafiro[/color]: Fuerza, Bloqueo y fuego. Sacrifica vida para golpear más fuerte.
• [color=#8bf0a4]Lia[/color]: Veneno, Cuchillas y robar cartas. Rápida y letal.
• [color=#caa5ff]Claudia[/color]: invoca a Osty, su mano espectral, que absorbe daño y ataca cada turno.
• [color=#ffc46b]Aurora[/color]: Resplandor y Calor. Ciega a los enemigos y remata con cartas de Danza.
• [color=#ffa6dc]Irene[/color]: acumula Cuerda; con ella, las cartas de Engranaje se repiten.
• [color=#9cc9ff]Selene[/color]: canaliza orbes de agua (Ola, Bruma, Abismo, Perla) que actúan cada turno y se evocan.

[b][color=#f0cf7a]Consejos[/color][/b]
• Pasa el ratón sobre cualquier estado, reliquia o carta para ver qué hace.
• Descansa 🔥 cuando tu vida esté baja. Las tiendas 💰 permiten eliminar cartas malas.
• Si pierdes, ¡vuelve a intentarlo! Cada partida es distinta. El modo fácil da más vida y enemigos más débiles."""


static func help() -> void:
	var h := HELP
	for pair in [["⚔️", "intent:attack"], ["🛡️", "intent:block"], ["⬇️", "intent:debuff"], ["⬆️", "intent:buff"], ["⚡", "ui:energy"], ["🔥", "node:rest"], ["💰", "ui:gold"]]:
		var kv: PackedStringArray = pair[1].split(":")
		h = h.replace(pair[0], Icons.bb(kv[0], kv[1], 20))
	await message("Cómo jugar", h, "¡A jugar!", 820)


static func pause_menu() -> void:
	var G = Meta.run
	if G == null or not (Main.I.current in ["map", "combat", "reward", "shop", "rest", "event"]):
		return
	var o := _overlay()
	var v := _center_col(o)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(340, 0)
	col.add_child(_title("Pausa", 32))
	var first_b: Button = null
	var add := func(t: String, kind: String, fn: Callable) -> Button:
		var b := UIK.button(t, kind)
		b.pressed.connect(fn)
		col.add_child(b)
		if first_b == null:
			first_b = b
		return b
	add.call("Seguir jugando", "green", func(): o.close(null))
	add.call("Opciones", "", func(): Dlg.options())
	add.call("Cómo jugar", "", func(): Dlg.help())
	add.call("Guardar y salir", "", func():
		var where := "Tu partida está guardada en este punto del mapa." if Main.I.current == "map" else "Tu partida se guarda al inicio de esta sala, y la sala se repetirá al continuar."
		if not await confirm("¿Guardar y salir al menú?\n[font_size=18]%s[/font_size]" % where, "Guardar y salir", "Cancelar"):
			return
		o.close(null)
		Nav.leave_run()
		Meta.run = null
		Nav.title()
		Main.I.toast("Partida guardada. Puedes continuar desde el menú."))
	add.call("Rendirse", "red", func():
		if not await confirm("¿Seguro que quieres rendirte?\n[font_size=18]La partida terminará como una derrota.[/font_size]", "Rendirme", "Seguir luchando"):
			return
		o.close(null)
		Nav.leave_run()
		Nav.game_over())
	p.add_child(col)
	v.add_child(p)
	if first_b != null:
		first_b.grab_focus.call_deferred()
