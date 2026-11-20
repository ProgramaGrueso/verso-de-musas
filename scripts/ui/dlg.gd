class_name Dlg
extends RefCounted
## Diálogos modales: elegir cartas, ver cartas, confirmar, mensajes, opciones, ayuda y pausa.


class Overlay extends Control:
	signal done(result)
	var cancel_result = null
	var allow_esc := true
	var _closed := false
	var _prev_focus: Control = null
	var _locked: Array = []   # [control, focus_mode] de lo que queda detrás mientras este diálogo está abierto

	func _enter_tree() -> void:
		var vp := get_viewport()
		if vp != null:
			_prev_focus = vp.gui_get_focus_owner()
		if Main.I != null:
			_lock_behind(Main.I)

	## Modal para el mando: lo de detrás no puede recibir foco (si no, el D-Pad se cuela bajo el diálogo).
	## No se baja dentro de otro Overlay: un diálogo exterior no apaga los focos del interior (cada uno
	## restaura solo lo suyo, así un modal anidado no se pisa ni se queda con todo sin foco).
	func _lock_behind(n: Node) -> void:
		if n == self or n is Overlay:
			return
		if n is Control and (n as Control).focus_mode != Control.FOCUS_NONE:
			_locked.append([n, (n as Control).focus_mode])
			(n as Control).focus_mode = Control.FOCUS_NONE
		for ch in n.get_children():
			_lock_behind(ch)

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
		# de dónde recuperar el foco al descartar: se mira antes de avisar, porque quien espera el diálogo
		# suele reconstruir o cambiar de pantalla en ese mismo momento
		var fallback := _focusable_below(self) if result == null else null
		done.emit(result)
		for pair in _locked:
			var c: Control = pair[0]
			# solo se toca lo que este diálogo apagó (y sigue apagado: si otro modal u otro código ya lo
			# reactivó —la pantalla que se reconstruyó mientras estaba abierto— se respeta su valor nuevo)
			if is_instance_valid(c) and not c.is_queued_for_deletion() and c.focus_mode == Control.FOCUS_NONE:
				c.focus_mode = pair[1]
		_locked.clear()
		# devuelve el foco a lo que lo tenía antes (si no, el mando se queda sin foco al cerrar un diálogo)
		var pf := _prev_focus
		if pf != null and is_instance_valid(pf) and not pf.is_queued_for_deletion() and pf.focus_mode != Control.FOCUS_NONE:
			pf.grab_focus.call_deferred()
		elif result == null and fallback != null:
			# descartado sin resultado (ESC/B, o un diálogo que solo informa): el mando se queda en el botón
			# del modal. Se pide al final del fotograma, y solo si ese botón sigue vivo y visible.
			_reclaim_focus(fallback)
		queue_free()

	## De forma diferida, y comprobando antes: nunca se pide el foco a un control liberado o en cola de borrado.
	func _reclaim_focus(c: Control) -> void:
		_await_focus(c)


	func _await_focus(c: Control) -> void:
		await get_tree().process_frame
		if c != null and is_instance_valid(c) and not c.is_queued_for_deletion() and c.is_inside_tree() and c.is_visible_in_tree() and c.focus_mode != Control.FOCUS_NONE:
			c.grab_focus()

	## Primer control que puede recibir foco dentro de `n`, sin bajar a diálogos anidados.
	func _focusable_below(n: Node) -> Control:
		if n != self and n is Overlay:
			return null
		if n is Control:
			var c := n as Control
			if c.focus_mode != Control.FOCUS_NONE and not c.is_queued_for_deletion() and c.is_visible_in_tree():
				return c
		for ch in n.get_children():
			var f := _focusable_below(ch)
			if f != null:
				return f
		return null

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


const TITLE_MAX_W := 1180.0   # ningún título se lee más ancho que el contenido del juego
const TITLE_MIN_W := 400.0    # caja mínima del título: más estrecho, se parte en líneas

static func _title(text: String, size: int = 38) -> Label:
	var l := UIK.label(text, size, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(l, 6)
	# un título largo encoge la fuente y, si aún no cabe, se parte en líneas dentro del diálogo: nunca se sale
	l.custom_minimum_size = Vector2(TITLE_MIN_W, 0)
	UIK.fit_title.call_deferred(l, TITLE_MAX_W, 20)
	UIK.wrap(l, TITLE_MIN_W, 16)
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
	var y := UIK.button(yes, "green")
	var n := UIK.button(no, "red")
	y.pressed.connect(func(): o.close(true))
	n.pressed.connect(func(): o.close(false))
	col.add_child(UIK.button_row([y, n], 16))
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
	col.custom_minimum_size.x = minf(col.custom_minimum_size.x, TITLE_MAX_W)   # un texto largo no ensancha el panel
	var b := UIK.button(btn)
	b.pressed.connect(func(): o.close(null))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	p.add_child(col)
	v.add_child(p)
	b.grab_focus.call_deferred()
	await o.done


## Pide un texto. Devuelve el texto escrito o null si se cancela.
static func text_input(title: String, sub: String = "", initial: String = "", placeholder: String = ""):
	var o := _overlay()
	o.cancel_result = null
	var v := _center_col(o)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 14)
	col.add_child(_title(title, 32))
	if sub != "":
		var r := UIK.rich("[center]%s[/center]" % sub, 18, UIK.DIM)
		r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		r.custom_minimum_size = Vector2(540, 0)
		col.add_child(r)
	var le := LineEdit.new()
	le.text = initial
	le.placeholder_text = placeholder
	le.max_length = 40
	le.custom_minimum_size = Vector2(540, 52)
	le.alignment = HORIZONTAL_ALIGNMENT_CENTER
	le.add_theme_font_override("font", UIK.font("bold"))
	le.add_theme_font_size_override("font_size", 24)
	col.add_child(le)
	var y := UIK.button("Aceptar", "green")
	var n := UIK.button("Cancelar", "red")
	y.pressed.connect(func(): o.close(le.text))
	n.pressed.connect(func(): o.close(null))
	le.text_submitted.connect(func(t: String): o.close(t))
	col.add_child(UIK.button_row([y, n], 16))
	col.custom_minimum_size.x = minf(col.custom_minimum_size.x, TITLE_MAX_W)
	p.add_child(col)
	v.add_child(p)
	le.grab_focus.call_deferred()
	return await o.done


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
	if opts.get("upgradePreview", false):
		# hoguera: al pasar el ratón (o el foco) por una carta se ve al lado cómo queda mejorada
		var peek := {"n": null}
		for cv in all_cards:
			cv.hovered.connect(func(view: CardView, on: bool):
				if peek.n != null and is_instance_valid(peek.n):
					peek.n.queue_free()
				peek.n = null
				if on and view.is_inside_tree():
					peek.n = _upgrade_peek(o, view, opts.get("C", null)))
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


## Qué cambia al mejorar una carta, en una línea («Coste 2 ➜ 1 · Inflige 9 de daño»).
static func upgrade_note(inst: Dictionary, C = null) -> String:
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
	return " · ".join(parts) if not parts.is_empty() else "Mejora los valores de la carta."


## Vista previa flotante de la carta mejorada junto a la carta señalada (no roba el ratón).
static func _upgrade_peek(o: Control, view: CardView, C) -> Control:
	var up_inst: Dictionary = view.inst.duplicate()
	up_inst.up = true
	var box := PanelContainer.new()
	var sb := UIK.stylebox(Color("#0d1a12", 0.96), Color("#7ef0a0"), 2, 14, 14)
	sb.shadow_color = Color("#7ef0a0", 0.35)
	sb.content_margin_left = 12; sb.content_margin_right = 12; sb.content_margin_top = 8; sb.content_margin_bottom = 10
	box.add_theme_stylebox_override("panel", sb)
	box.z_index = 200
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	col.add_child(UIK.label("Mejorada ➜", 18, Color("#8dff9d"), "bold", HORIZONTAL_ALIGNMENT_CENTER))
	var cc := CenterContainer.new()
	cc.add_child(CardView.create(up_inst, C, 200.0, false))
	col.add_child(cc)
	var nl := UIK.label(upgrade_note(view.inst, C), 14, UIK.GOLD, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(200, 0)
	col.add_child(nl)
	box.add_child(col)
	Juice.mouse_ignore_all(box)
	o.add_child(box)
	box.reset_size()
	var r := view.get_global_rect()
	var bw := box.size.x
	var x := r.end.x + 14.0 if r.end.x + 14.0 + bw <= 1274.0 else r.position.x - 14.0 - bw
	var y := clampf(r.get_center().y - box.size.y / 2.0, 6.0, 714.0 - box.size.y)
	box.global_position = Vector2(clampf(x, 6.0, 1274.0 - bw), y)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.12)
	return box


static func upgrade_compare(inst: Dictionary, C = null) -> bool:
	var o := _overlay()
	o.cancel_result = false
	var v := _center_col(o, 14)
	v.add_child(_title("¿Mejorar esta carta?"))
	var row := _row(36)
	var up_inst := inst.duplicate()
	up_inst.up = true
	var note := upgrade_note(inst, C)
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
	var yes := UIK.button("Mejorar", "green")
	var no := UIK.button("Cancelar", "red")
	yes.pressed.connect(func(): o.close(true))
	no.pressed.connect(func(): o.close(false))
	v.add_child(UIK.button_row([yes, no], 16))
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
	var calm_row := _toggle_row("Reducir movimiento", Meta.settings.get("calm", false), "Sí (sin sacudidas ni partículas)", "No", func(x): Meta.settings.calm = x; Meta.save_settings(), "moon")
	UIK.tip(calm_row.get_child(2), "[b][color=#f0cf7a]Reducir movimiento[/color][/b]\nApaga las sacudidas de pantalla, el hitstop de los golpes, los anillos y las partículas. Los colores y los sonidos se mantienen.")
	col.add_child(calm_row)
	var mr := UIK.button("Reiniciar música")
	mr.pressed.connect(func(): Sfx.restart_music())
	var fs := UIK.button("Pantalla completa")
	fs.pressed.connect(func(): Main.I._toggle_fullscreen())
	var cl := UIK.button("Cerrar")
	cl.pressed.connect(func(): o.close(null))
	col.add_child(UIK.button_row([mr, fs, cl], 14))
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
• Sobre tu barra de vida verás el daño total que llega este turno y cuántos PV perderías con tu Bloqueo actual.
• Pulsa Terminar turno cuando acabes. El Bloqueo 🛡️ te protege del daño solo durante un turno.

[b][color=#f0cf7a]Teclado[/color][/b]
← → eligen carta · ↑ ↓ cambian de enemigo · Enter o Espacio juegan · E termina el turno · Esc cancela. También 1–9 para elegir una carta.
Q / W / R / T: usar la poción del hueco 1 / 2 / 3 / 4 · D: mazo de robo · S: descarte · X: agotadas · Z: deshacer la última carta (modo fácil).
M: ver tu mazo · H o F1: esta ayuda · F11: pantalla completa.

[b][color=#f0cf7a]Mando (Xbox / Gamepad)[/color][/b]
Stick izquierdo / D-Pad: navegar cartas y menús · LB / RB: pasar cartas · A: jugar / confirmar · B: cancelar / volver · Y: terminar turno · X: mazo de robo · LT: poción · RT: descarte · Back / View: ver mazo · Start: menú de pausa.
R3 (clic del stick derecho): inspeccionar estados, intenciones, reliquias y pociones (D-Pad mueve · B sale) · Stick derecho: desplazar listas largas.

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
• Si pierdes, ¡vuelve a intentarlo! Cada partida es distinta. El modo fácil da más vida, enemigos más débiles y permite deshacer la última carta.
• Cada partida tiene una semilla: escríbela al elegir musa para repetir los mismos mapas, o juega el Reto diario, igual para todo el mundo."""


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
	var firsts := []   # las lambdas capturan por valor: se acumula en un array
	var add := func(t: String, kind: String, fn: Callable) -> Button:
		var b := UIK.button(t, kind)
		b.pressed.connect(fn)
		col.add_child(b)
		firsts.append(b)
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
		G["surrender"] = true
		Nav.game_over())
	var seed_row := _row(10)
	var sl := UIK.label("Semilla: %d" % G.seed, 16, UIK.DIM)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seed_row.add_child(sl)
	var cp := UIK.button("Copiar", "small")
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(str(G.seed))
		Main.I.toast("Semilla copiada: %d" % G.seed))
	seed_row.add_child(cp)
	col.add_child(seed_row)
	p.add_child(col)
	v.add_child(p)
	if not firsts.is_empty():
		firsts[0].grab_focus.call_deferred()
