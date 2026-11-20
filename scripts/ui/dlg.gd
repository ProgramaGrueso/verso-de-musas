class_name Dlg
extends RefCounted
## Diálogos modales: elegir cartas, ver cartas, confirmar, mensajes, opciones, ayuda y pausa.


class Overlay extends Control:
	signal done(result)
	var cancel_result = null
	var allow_esc := true
	var lock_below := false   # también apaga el foco de los diálogos de debajo (el mazo abierto sobre otro)
	var _closed := false
	var _prev_focus: Control = null
	var _locked: Array = []   # [control, focus_mode] de lo que queda detrás mientras este diálogo está abierto

	func _enter_tree() -> void:
		var vp := get_viewport()
		if vp != null:
			_prev_focus = vp.gui_get_focus_owner()
		if Main.I != null:
			_lock_behind(Main.I)
			if lock_below:
				# el mazo abierto sobre otro diálogo: lo de ese diálogo tampoco recibe el foco mientras tanto
				for ov in Main.I.overlay_host.get_children():
					if ov != self and ov is Overlay:
						_lock_all(ov)

	## Como _lock_behind, pero bajando también dentro de los diálogos de debajo (solo para lock_below).
	func _lock_all(n: Node) -> void:
		if n is Control and (n as Control).focus_mode != Control.FOCUS_NONE:
			_locked.append([n, (n as Control).focus_mode])
			(n as Control).focus_mode = Control.FOCUS_NONE
		for ch in n.get_children():
			_lock_all(ch)

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
		# quien esperaba este diálogo puede haber abierto ya el siguiente al recibir `done` (hoguera: elegir ➜
		# comparar ➜ «¡Carta mejorada!»). Lo de detrás sigue bloqueado: se le pasa al diálogo nuevo, que lo
		# devolverá al cerrarse, en vez de reactivarlo debajo de él.
		var heir := _live_overlay_above()
		for pair in _locked:
			if not is_instance_valid(pair[0]):
				continue   # la pantalla de detrás ya se liberó (rendirse / guardar y salir): sin esto close() abortaba y el diálogo quedaba colgado
			var c: Control = pair[0]
			# solo se toca lo que este diálogo apagó (y sigue apagado: si otro modal u otro código ya lo
			# reactivó —la pantalla que se reconstruyó mientras estaba abierto— se respeta su valor nuevo)
			if is_instance_valid(c) and not c.is_queued_for_deletion() and c.focus_mode == Control.FOCUS_NONE:
				if heir != null and not heir.is_ancestor_of(c):
					heir._locked.append(pair)
				else:
					c.focus_mode = pair[1]
		_locked.clear()
		# devuelve el foco a lo que lo tenía antes (si no, el mando se queda sin foco al cerrar un diálogo).
		# Se pide un fotograma después y solo si no hay otro diálogo encima que no lo contenga.
		var pf := _prev_focus
		if pf != null and is_instance_valid(pf) and not pf.is_queued_for_deletion() and pf.focus_mode != Control.FOCUS_NONE:
			Dlg._focus_later(pf)
		elif result == null and fallback != null:
			# descartado sin resultado (ESC/B, o un diálogo que solo informa): el mando se queda en el botón
			# del modal. Se pide al final del fotograma, y solo si ese botón sigue vivo y visible.
			Dlg._focus_later(fallback)
		queue_free()

	## El diálogo abierto (y no cerrándose) más alto por encima de éste, o null.
	func _live_overlay_above() -> Overlay:
		var host := get_parent()
		if host == null:
			return null
		for i in range(host.get_child_count() - 1, get_index(), -1):
			var ov := host.get_child(i)
			if ov is Overlay and not (ov as Overlay)._closed and not ov.is_queued_for_deletion():
				return ov
		return null

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


## Da el foco a `c` un fotograma después, si sigue vivo, visible y enfocable, y si no hay un diálogo abierto
## encima que no lo contenga (un cierre encadenado no le roba el foco al diálogo que se acaba de abrir).
static func _focus_later(c: Control) -> void:
	if Main.I == null or not Main.I.is_inside_tree():
		return
	await Main.I.get_tree().process_frame
	if c == null or not is_instance_valid(c) or c.is_queued_for_deletion() or not c.is_inside_tree():
		return
	if not c.is_visible_in_tree() or c.focus_mode == Control.FOCUS_NONE:
		return
	if Main.I == null:
		return
	var host: Control = Main.I.overlay_host
	for i in range(host.get_child_count() - 1, -1, -1):
		var ov := host.get_child(i)
		if ov is Overlay and not (ov as Overlay)._closed and not ov.is_queued_for_deletion():
			if not ov.is_ancestor_of(c):
				return
			break
	c.grab_focus()


static func _overlay(lock_below: bool = false) -> Overlay:
	var o := Overlay.new()
	o.lock_below = lock_below
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


static func _card_grid(cards: Array, C, w: float, on_press: Callable = Callable(), max_h: float = 500.0, max_w: float = 1160.0) -> Control:
	var cols := maxi(1, int(max_w / (w + 14.0)))
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
	if content_h <= max_h:
		var cc := CenterContainer.new()
		cc.add_child(grid)
		return cc
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(max_w + 40.0, max_h)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 20)
	m.add_theme_constant_override("margin_top", 14)
	m.add_child(grid)
	sc.add_child(m)
	return sc


# ---------- Confirmar / mensaje ----------
static func confirm(text: String, yes: String = "", no: String = "") -> bool:
	if yes == "":
		yes = Loc.t("Sí")
	if no == "":
		no = Loc.t("No")
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


static func message(title: String, bbcode: String, btn: String = "", width: int = 760) -> void:
	if btn == "":
		btn = Loc.t("Entendido")
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
	var y := UIK.button(Loc.t("Aceptar"), "green")
	var n := UIK.button(Loc.t("Cancelar"), "red")
	y.pressed.connect(func(): o.close(le.text))
	n.pressed.connect(func(): o.close(null))
	le.text_submitted.connect(func(t: String): o.close(t))
	col.add_child(UIK.button_row([y, n], 16))
	col.custom_minimum_size.x = minf(col.custom_minimum_size.x, TITLE_MAX_W)
	p.add_child(col)
	v.add_child(p)
	le.grab_focus.call_deferred()
	return await o.done


# ---------- Reliquias (Fase 2.3: clic / A en una reliquia) ----------
const RELIC_RARITY := {"start": "Inicial", "common": "Común", "uncommon": "Poco común", "rare": "Rara", "boss": "De jefe"}   # loc


## De dónde sale una reliquia: rareza, en qué salas aparece y si es exclusiva de una musa.
static func relic_origin(id: String) -> String:
	var r: Dictionary = DB.relics[id]
	var rar: String = r.get("rarity", "")
	var parts := []
	if rar == "start":
		var who := ""
		for ch in DB.characters.keys():
			if DB.characters[ch].get("startRelic", "") == id:
				who = DB.characters[ch].name
		parts.append(Loc.t("Reliquia inicial de %s") % who if who != "" else Loc.t("Reliquia inicial"))
	elif rar == "boss":
		parts.append(Loc.t("De jefe · se elige al vencer a un jefe"))
	else:
		parts.append(Loc.t("%s · élites, eventos y tiendas") % (Loc.t(RELIC_RARITY[rar]) if RELIC_RARITY.has(rar) else rar.capitalize()))
	if r.has("char") and DB.characters.has(r.char) and rar != "start":
		parts.append(Loc.t("Exclusiva de %s") % DB.characters[r.char].name)
	return " · ".join(parts)


## Ficha de una reliquia: icono grande, nombre, origen y efecto. Se cierra con el botón, Esc o B.
static func relic_info(id: String) -> void:
	if not DB.relics.has(id) or Main.I == null:
		return
	var host: Control = Main.I.overlay_host
	if host.get_child_count() > 0 and host.get_child(host.get_child_count() - 1).get_meta("relic_info", "") == id:
		return   # ya está abierta (doble clic)
	var r: Dictionary = DB.relics[id]
	var o := _overlay()
	o.set_meta("relic_info", id)
	var v := _center_col(o)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(520, 0)
	var ic: Control
	if Icons.has("relic", id):
		ic = Icons.frame("relic", id, 112, UIK.GOLD, true)
	else:
		ic = UIK.label(r.get("i", "?"), 72, Color.WHITE, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(ic)
	col.add_child(_title(r.n, 32))
	var org := UIK.rich("[center][color=#a79fc0]%s[/color][/center]" % relic_origin(id), 17)
	org.name = "Origin"
	org.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	org.custom_minimum_size = Vector2(520, 0)
	col.add_child(org)
	var d := UIK.rich("[center]%s[/center]" % r.d, 22)
	d.name = "Desc"
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(520, 0)
	col.add_child(d)
	var b := UIK.button(Loc.t("Cerrar"))
	b.pressed.connect(func(): o.close(null))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(b)
	p.add_child(col)
	v.add_child(p)
	Sfx.play("relic", 0.5)
	b.grab_focus.call_deferred()
	await o.done


# ---------- Cartas ----------
## Mazo, robo, descarte, agotadas... Con FILTER_MIN cartas o más sale una barra de filtros (tipo, coste y
## mejoradas) que rehace la rejilla sin mover el foco del mando.
## deck = true: es «Tu mazo» (M / Back / botón de la barra); puede abrirse sobre otro diálogo y lo bloquea.
static func view_cards(title: String, cards: Array, C = null, deck: bool = false) -> void:
	var o := _overlay(deck)
	o.set_meta("view_cards", true)
	o.set_meta("deck_view", deck)
	var v := _center_col(o, 12)
	v.add_child(_title(title))
	var b := UIK.button(Loc.t("Cerrar"))
	if cards.is_empty():
		v.add_child(UIK.label(Loc.t("No hay cartas aquí."), 22, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER))
	elif cards.size() < FILTER_MIN:
		v.add_child(_card_grid(cards, C, 158.0))
	else:
		# rejilla de alto fijo: al filtrar, la barra y el botón no saltan de sitio
		var holder := Control.new()
		holder.name = "CardsHolder"
		holder.custom_minimum_size = Vector2(1200, FILTER_GRID_H)
		var bar := _filter_bar(cards, C, holder)
		v.add_child(bar)
		v.add_child(holder)
		_refill(holder, cards, C)
	b.pressed.connect(func(): o.close(null))
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(b)
	var first: Control = b
	if cards.size() >= FILTER_MIN:
		first = v.find_child("Chip_all", true, false)
	first.grab_focus.call_deferred()
	await o.done


const FILTER_MIN := 6          # con menos cartas no hace falta filtrar
const FILTER_GRID_H := 436.0   # alto de la rejilla con barra de filtros (cabe en 720 con título y botón)
const FILTER_TYPES := [["attack", "Ataque"], ["skill", "Habilidad"], ["power", "Poder"], ["other", "Otras"]]   # loc
const FILTER_COSTS := [["0", "0"], ["1", "1"], ["2", "2"], ["3", "3+"], ["X", "X"], ["-", "—"]]


static func _type_key(inst: Dictionary) -> String:
	var t: String = Eng.card_def(inst).type
	return t if t in ["attack", "skill", "power"] else "other"


static func _cost_key(inst: Dictionary, C) -> String:
	var d := Eng.card_def(inst)
	if Eng.is_x(d.cost):
		return "X"
	var c: int = Eng.eff_cost(C, d) if (C != null and C is Dictionary and not C.is_empty()) else d.cost
	if c < 0 or d.flags.get("unplayable", false):
		return "-"
	return str(mini(c, 3))


## Cartas que pasan el filtro {type, cost, up} ("" = sin filtro).
static func filter_cards(cards: Array, C, f: Dictionary) -> Array:
	return cards.filter(func(inst):
		if f.get("type", "") != "" and _type_key(inst) != f.type:
			return false
		if f.get("cost", "") != "" and _cost_key(inst, C) != f.cost:
			return false
		if f.get("up", false) and not inst.get("up", false):
			return false
		return true)


static func _refill(holder: Control, cards: Array, C) -> void:
	for ch in holder.get_children():
		holder.remove_child(ch)
		ch.queue_free()
	var f: Dictionary = holder.get_meta("filter", {})
	var shown := filter_cards(cards, C, f)
	holder.set_meta("shown", shown.size())
	var g: Control
	if shown.is_empty():
		g = CenterContainer.new()
		g.add_child(UIK.label(Loc.t("Ninguna carta con este filtro."), 22, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER))
	else:
		g = _card_grid(shown, C, 158.0, Callable(), FILTER_GRID_H)
	g.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	holder.add_child(g)
	var cnt = holder.get_meta("count_lbl", null)
	if cnt != null and is_instance_valid(cnt):
		(cnt as Label).text = "%d / %d" % [shown.size(), cards.size()]


static func _chip_mark(chip: Button, on: bool) -> void:
	if not chip.has_meta("sb_normal"):
		chip.set_meta("sb_normal", chip.get_theme_stylebox("normal"))
	var sb: StyleBox = chip.get_theme_stylebox("hover") if on else chip.get_meta("sb_normal")
	chip.add_theme_stylebox_override("normal", sb)
	chip.add_theme_color_override("font_color", Color.WHITE if on else UIK.GOLD)
	chip.set_meta("on", on)


static func _filter_bar(cards: Array, C, holder: Control) -> Control:
	var row := _row(8)
	row.name = "FilterBar"
	holder.set_meta("filter", {"type": "", "cost": "", "up": false})
	var chips := {}
	var sync := func():
		var f: Dictionary = holder.get_meta("filter")
		for k in chips.keys():
			var on := false
			if k == "all":
				on = f.type == "" and f.cost == "" and not f.up
			elif k == "up":
				on = f.up
			elif k.begins_with("t:"):
				on = f.type == k.substr(2)
			elif k.begins_with("c:"):
				on = f.cost == k.substr(2)
			_chip_mark(chips[k], on)
	var add_chip := func(key: String, text: String, fn: Callable) -> void:
		var chip := UIK.button(text, "small")
		chip.name = "Chip_" + key.replace(":", "_")
		chip.pressed.connect(func():
			fn.call(holder.get_meta("filter"))
			_refill(holder, cards, C)
			sync.call())
		chips[key] = chip
		row.add_child(chip)
	add_chip.call("all", Loc.t("Todas %d") % cards.size(), func(f: Dictionary):
		f.type = ""; f.cost = ""; f.up = false)
	var tcount := {}
	var ccount := {}
	var ups := 0
	for inst in cards:
		var tk := _type_key(inst)
		tcount[tk] = tcount.get(tk, 0) + 1
		var ck := _cost_key(inst, C)
		ccount[ck] = ccount.get(ck, 0) + 1
		if inst.get("up", false):
			ups += 1
	for pair in FILTER_TYPES:
		var key: String = pair[0]
		if tcount.get(key, 0) > 0:
			add_chip.call("t:" + key, "%s %d" % [Loc.t(pair[1]), tcount[key]], func(f: Dictionary):
				f.type = "" if f.type == key else key)
	var cl := UIK.label(Loc.t("Coste"), 16, UIK.DIM, "bold")
	cl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cl)
	for pair in FILTER_COSTS:
		var key: String = pair[0]
		if ccount.get(key, 0) > 0:
			add_chip.call("c:" + key, pair[1], func(f: Dictionary):
				f.cost = "" if f.cost == key else key)
	if ups > 0:
		add_chip.call("up", Loc.t("Mejoradas %d") % ups, func(f: Dictionary):
			f.up = not f.up)
	var cnt := UIK.label("%d / %d" % [cards.size(), cards.size()], 16, UIK.DIM, "bold")
	cnt.name = "FilterCount"
	cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cnt)
	holder.set_meta("count_lbl", cnt)
	sync.call()
	return row


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
	var ok_label: String = opts.get("confirmLabel", Loc.t("Confirmar"))
	var ok := UIK.button(ok_label, "green")
	ok.disabled = true
	var upd := func():
		ok.disabled = sel.size() != n
		ok.text = ok_label + ((" (%d/%d)" % [sel.size(), n]) if n > 1 else "")
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
	var preview: bool = opts.get("upgradePreview", false)
	# con vista previa la rejilla deja a su derecha un hueco fijo para la carta mejorada: flotando encima
	# tapaba el nombre y el texto de las cartas vecinas (y la ayuda de arriba)
	var grid := _card_grid(opts.cards, opts.get("C", null), w, on_press, 500.0, PEEK_GRID_W if preview else 1160.0)
	for cv in _find_cards(grid):
		views[cv.inst.uid] = cv
	var all_cards := _find_cards(grid)
	if preview:
		var gh := _row(14)
		gh.alignment = BoxContainer.ALIGNMENT_CENTER
		gh.add_child(grid)
		var slot := Control.new()
		slot.custom_minimum_size = PEEK_SLOT
		slot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		gh.add_child(slot)
		v.add_child(gh)
		# hoguera: al pasar el ratón (o el foco) por una carta se ve al lado cómo queda mejorada
		var peek := {"n": null}
		for cv in all_cards:
			cv.hovered.connect(func(view: CardView, on: bool):
				if peek.n != null and is_instance_valid(peek.n):
					peek.n.queue_free()
				peek.n = null
				if on and view.is_inside_tree():
					peek.n = _upgrade_peek(slot, view, opts.get("C", null)))
	else:
		v.add_child(grid)
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
		parts.append(Loc.t("Coste %s ➜ %s") % [str(a.cost), str(b.cost)])
	var la = CardText.lines(a, C).lines.map(_strip)
	var lb = CardText.lines(b, C).lines.map(_strip)
	for l in lb:
		if not (l in la):
			parts.append(l)
	# palabras clave tal como las escribe CardText en el idioma activo (msgid del contenido, content_en.po)
	var kws := [Loc.t("Agotar"), Loc.t("Retener"), Loc.t("Innata")]
	for l in la:
		if not (l in lb) and (l.contains(kws[0]) or l.contains(kws[1]) or l.contains(kws[2])):
			parts.append(Loc.t("Pierde: %s") % l)
	return " · ".join(parts) if not parts.is_empty() else Loc.t("Mejora los valores de la carta.")


## Rejilla más estrecha cuando hay vista previa de mejora, y el hueco donde se pinta (cabe la carta de 200 px,
## su rótulo y la nota de lo que cambia).
const PEEK_GRID_W := 916.0
const PEEK_SLOT := Vector2(230, 420)

## Vista previa de la carta mejorada en su hueco junto a la rejilla, a la altura de la carta señalada
## (dentro del hueco) y sin robar el ratón.
static func _upgrade_peek(slot: Control, view: CardView, C) -> Control:
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
	col.add_child(UIK.label(Loc.t("Mejorada ➜"), 18, Color("#8dff9d"), "bold", HORIZONTAL_ALIGNMENT_CENTER))
	var cc := CenterContainer.new()
	cc.add_child(CardView.create(up_inst, C, 200.0, false))
	col.add_child(cc)
	var nl := UIK.label(upgrade_note(view.inst, C), 14, UIK.GOLD, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	nl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	nl.custom_minimum_size = Vector2(200, 0)
	col.add_child(nl)
	box.add_child(col)
	Juice.mouse_ignore_all(box)
	slot.add_child(box)
	box.reset_size()
	var sr := slot.get_global_rect()
	var bw := box.size.x
	var bh := box.size.y
	var top := sr.position.y
	var bottom := maxf(sr.end.y, top + bh)
	var lo := maxf(6.0, top)
	var y := clampf(view.get_global_rect().get_center().y - bh / 2.0, lo, maxf(lo, minf(714.0, bottom) - bh))
	box.global_position = Vector2(sr.position.x + (sr.size.x - bw) / 2.0, y)
	box.modulate.a = 0.0
	box.create_tween().tween_property(box, "modulate:a", 1.0, 0.12)
	return box


static func upgrade_compare(inst: Dictionary, C = null) -> bool:
	var o := _overlay()
	o.cancel_result = false
	var v := _center_col(o, 14)
	v.add_child(_title(Loc.t("¿Mejorar esta carta?")))
	var row := _row(36)
	var up_inst := inst.duplicate()
	up_inst.up = true
	var note := upgrade_note(inst, C)
	for pair in [[Loc.t("Ahora"), inst], [Loc.t("Mejorada"), up_inst]]:
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
		if pair[1] == inst:
			row.add_child(UIK.label("➜", 72, UIK.GOLD, "bold"))
	v.add_child(row)
	var yes := UIK.button(Loc.t("Mejorar"), "green")
	var no := UIK.button(Loc.t("Cancelar"), "red")
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
	cb.add_theme_font_size_override("font_size", UIK.ts(18))
	cb.toggled.connect(func(p): cb.text = text_on if p else text_off; on_change.call(p))
	r.add_child(cb)
	return r


static func options() -> void:
	var o := _overlay()
	o.set_meta("options", true)
	var scale0 := UIK.text_scale
	_options_fill(o, "Cerrar")
	await o.done
	if o.get_meta("lang_changed", false) and Main.I != null:
		Main.I.relocalize()   # idioma nuevo: barra superior, pausa y la pantalla (si se puede rehacer sin perder nada)
	elif not is_equal_approx(scale0, UIK.text_scale) and Main.I != null and Main.I.current == "title" \
			and Main.I.overlay_host.get_child_count() <= 1:
		Nav.title()   # la portada se rehace con el texto nuevo (las demás pantallas, al abrirse)


## Contenido de Opciones. Se rehace entero al cambiar el tamaño del texto, para verlo al momento.
static func _options_fill(o: Overlay, focus_name: String) -> void:
	for ch in o.get_children():
		if ch.has_meta("options_body"):
			o.remove_child(ch)
			ch.queue_free()
	var v := _center_col(o)
	v.get_parent().set_meta("options_body", true)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.add_child(_title(Loc.t("Opciones"), 32))
	col.add_child(_slider_row(Loc.t("Música"), Meta.settings.music, func(x): Meta.settings.music = x; Sfx.apply_music_volume(); Meta.save_settings(), "music"))
	var sfx_row := _slider_row(Loc.t("Sonidos"), Meta.settings.sfx, func(x): Meta.settings.sfx = x; Meta.save_settings(), "sound")
	(sfx_row.get_child(2) as HSlider).drag_ended.connect(func(_c): Sfx.play("hit"))
	col.add_child(sfx_row)
	col.add_child(_toggle_row(Loc.t("Jugar carta"), Meta.settings.confirm, Loc.t("Elegir y confirmar (más seguro)"), Loc.t("Un solo clic"), func(x): Meta.settings.confirm = x; Meta.save_settings(), "hand"))
	col.add_child(_toggle_row(Loc.t("Animaciones"), Meta.settings.fast, Loc.t("Rápidas"), Loc.t("Normales"), func(x): Meta.settings.fast = x; Meta.save_settings(), "speed"))
	var calm_row := _toggle_row(Loc.t("Reducir movimiento"), Meta.settings.get("calm", false), Loc.t("Sí (sin sacudidas ni partículas)"), Loc.t("No"), func(x): Meta.settings.calm = x; Meta.save_settings(), "moon")
	UIK.tip(calm_row.get_child(2), "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [Loc.t("Reducir movimiento"), Loc.t("Apaga las sacudidas de pantalla, el hitstop de los golpes, los anillos y las partículas. Los colores y los sonidos se mantienen.")])
	col.add_child(calm_row)
	# idioma (Fase 5): cada idioma se nombra en su propia lengua; el panel se rehace al momento y, al cerrar
	# Opciones, Main.relocalize rehace la pantalla y la barra superior
	var lr := _opt_head(Loc.t("Idioma"), "menu")
	lr.name = "LangRow"
	for pair in Loc.LANGS:
		var code: String = pair[0]
		var lb := UIK.button(pair[1], "small green" if code == Loc.lang() else "small")
		lb.name = "Lang_" + code
		lb.pressed.connect(func():
			if code == Loc.lang():
				return
			Loc.set_lang(code, Meta.settings)
			Meta.save_settings()
			o.set_meta("lang_changed", true)
			_options_fill(o, "Lang_" + code))
		lr.add_child(lb)
	col.add_child(lr)
	# tamaño del texto: 100 / 115 / 130 %
	var scr := _opt_head(Loc.t("Tamaño del texto"), "help")
	for i in UIK.TEXT_SCALES.size():
		var sc: float = UIK.TEXT_SCALES[i]
		var on := is_equal_approx(sc, UIK.text_scale)
		var sb := UIK.button("%d %%" % int(round(sc * 100)), "small green" if on else "small")
		sb.name = "Scale_%d" % i
		sb.pressed.connect(func():
			if is_equal_approx(sc, UIK.text_scale):
				return
			Meta.settings.text_scale = sc
			Meta.save_settings()
			UIK.text_scale = sc
			_options_fill(o, "Scale_%d" % i))
		scr.add_child(sb)
	UIK.tip(scr.get_child(1), "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [Loc.t("Tamaño del texto"), Loc.t("Agranda las letras de menús, diálogos, cartas y ayudas. Se aplica a cada pantalla al abrirla.")])
	col.add_child(scr)
	var kr := _opt_head(Loc.t("Controles"), "gear")
	var kb := UIK.button(Loc.t("Teclado…"), "small")
	kb.name = "Controls"
	kb.pressed.connect(func(): await controls())
	kr.add_child(kb)
	var kl := UIK.label(Loc.t("Cambia las teclas de las acciones"), 16, UIK.DIM)
	kl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	kr.add_child(kl)
	col.add_child(kr)
	var mr := UIK.button(Loc.t("Reiniciar música"))
	mr.pressed.connect(func(): Sfx.restart_music())
	var fs := UIK.button(Loc.t("Pantalla completa"))
	fs.pressed.connect(func(): Main.I._toggle_fullscreen())
	var cl := UIK.button(Loc.t("Cerrar"))
	cl.name = "Cerrar"
	cl.pressed.connect(func(): o.close(null))
	col.add_child(UIK.button_row([mr, fs, cl], 14))
	p.add_child(col)
	v.add_child(p)
	var f: Control = col.find_child(focus_name, true, false)
	(f if f != null else cl).grab_focus.call_deferred()


## Cabecera de una fila de Opciones (icono + nombre con el mismo ancho que las demás).
static func _opt_head(label: String, icon_id: String) -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 16)
	r.add_child(Icons.frame("ui", icon_id, 46, UIK.GOLD, true))
	var l := UIK.label(label, 22, UIK.TEXT, "bold")
	l.custom_minimum_size = Vector2(190, 0)
	l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.add_child(l)
	return r


## Captura la siguiente tecla para Opciones ▸ Controles (va antes que el resto: Esc no cierra el diálogo).
class KeyCatcher extends Node:
	signal caught(keycode: int)   # KEY_NONE = cancelado (Esc o B del mando)
	var waiting := false
	var _armed_frame := 0

	func arm() -> void:
		waiting = true
		_armed_frame = Engine.get_process_frames()

	func _input(ev: InputEvent) -> void:
		if not waiting or Engine.get_process_frames() == _armed_frame:
			return
		if ev is InputEventKey and ev.pressed and not ev.echo:
			get_viewport().set_input_as_handled()
			waiting = false
			caught.emit(KEY_NONE if ev.keycode == KEY_ESCAPE else int(ev.keycode))
		elif ev is InputEventJoypadButton and ev.pressed and ev.button_index == JOY_BUTTON_B:
			get_viewport().set_input_as_handled()
			waiting = false
			caught.emit(KEY_NONE)


## Opciones ▸ Controles: una tecla por acción; pulsa la acción y luego la tecla nueva.
static func controls() -> void:
	var o := _overlay()
	o.set_meta("controls", true)
	var catcher := KeyCatcher.new()
	o.add_child(catcher)
	var v := _center_col(o)
	var p := UIK.panel(26)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	col.add_child(_title(Loc.t("Controles · teclado"), 30))
	var sub := UIK.label(Loc.t("Pulsa una acción y después la tecla nueva (Esc cancela). Si esa tecla ya era de otra acción, se intercambian. Las flechas, Enter, Espacio, Esc, 1–9, F1 y F11 son fijas; el mando no cambia."), 16, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.wrap(sub, 760, 16)
	col.add_child(sub)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 8)
	var btns := {}
	var msg := UIK.label("", 18, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	msg.name = "Msg"
	var refresh := func():
		for id in btns:
			btns[id].text = Main.key_name(id)
	for a in Main.KEY_ACTIONS:
		var id: String = a[0]
		var l := UIK.label(Loc.t(a[1]), 18, UIK.TEXT)
		l.custom_minimum_size = Vector2(230, 0)
		l.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		grid.add_child(l)
		var b := UIK.button(Main.key_name(id), "small")
		b.name = "Key_" + id
		b.custom_minimum_size = Vector2(110, 0)
		b.pressed.connect(func():
			if catcher.waiting:
				return
			b.text = Loc.t("Pulsa…")
			msg.text = Loc.t("Pulsa la tecla nueva para «%s» (Esc cancela).") % Loc.t(a[1])
			catcher.arm()
			var k: int = await catcher.caught
			if not is_instance_valid(b):
				return
			if k == KEY_NONE:
				msg.text = ""
			else:
				var err := Main.set_key(id, k)
				msg.text = err if err != "" else "«%s»: %s" % [Loc.t(a[1]), OS.get_keycode_string(k)]
				Sfx.play("error" if err != "" else "click")
			refresh.call()
			b.grab_focus())
		btns[id] = b
		grid.add_child(b)
	col.add_child(grid)
	col.add_child(msg)
	var rs := UIK.button(Loc.t("Restablecer"))
	rs.name = "Reset"
	rs.pressed.connect(func():
		Main.reset_keys()
		refresh.call()
		msg.text = Loc.t("Teclas por defecto."))
	var cl := UIK.button(Loc.t("Cerrar"))
	cl.pressed.connect(func(): o.close(null))
	col.add_child(UIK.button_row([rs, cl], 14))
	p.add_child(col)
	v.add_child(p)
	btns[Main.KEY_ACTIONS[0][0]].grab_focus.call_deferred()
	await o.done


# loc
const HELP := """[b][color=#f0cf7a]Objetivo[/color][/b]
Sube la torre superando 3 zonas. Elige tu camino en el mapa, derrota enemigos y jefes, y mejora tu mazo de cartas.

[b][color=#f0cf7a]Tu turno[/color][/b]
• Tienes ⚡ energía (3 por turno). Cada carta tiene un coste en la esquina.
• Haz clic en una carta para elegirla y otra vez para jugarla (o arrástrala hacia arriba). Si la carta ataca a un enemigo concreto, haz clic en el enemigo.
• Encima de cada enemigo ves su intención: ⚔️ ataque (con el daño), 🛡️ defensa, ⬇️ te debilita, ⬆️ se fortalece.
• Sobre tu barra de vida verás el daño total que llega este turno y cuántos PV perderías con tu Bloqueo actual.
• Pulsa Terminar turno cuando acabes. El Bloqueo 🛡️ te protege del daño solo durante un turno.

[b][color=#f0cf7a]Teclado[/color][/b]
← → eligen carta · ↑ ↓ cambian de enemigo · Enter o Espacio juegan · {terminar_turno} termina el turno · Esc cancela. También 1–9 para elegir una carta.
{pocion_1} / {pocion_2} / {pocion_3} / {pocion_4}: usar la poción del hueco 1 / 2 / 3 / 4 · {robo}: mazo de robo · {descarte}: descarte · {agotadas}: agotadas · {deshacer}: deshacer la última carta (modo fácil).
{ver_mazo}: ver tu mazo · {ayuda} o F1: esta ayuda · F11: pantalla completa. Las teclas se cambian en Opciones ▸ Controles.

[b][color=#f0cf7a]Mando (Xbox / Gamepad)[/color][/b]
Stick izquierdo / D-Pad: navegar cartas y menús · LB / RB: pasar cartas · A: jugar / confirmar · B: cancelar / volver · Y: terminar turno · X: mazo de robo · LT: poción · RT: descarte · Back / View: ver mazo · Start: menú de pausa.
R3 (clic del stick derecho): inspeccionar estados, intenciones, reliquias y pociones (D-Pad mueve · A abre la ficha de una reliquia · B sale) · Stick derecho: desplazar listas largas.

[b][color=#f0cf7a]Tus personajes[/color][/b]
• [color=#ff8a93]Zafiro[/color]: Fuerza, Bloqueo y fuego. Sacrifica vida para golpear más fuerte.
• [color=#8bf0a4]Lia[/color]: Veneno, Cuchillas y robar cartas. Rápida y letal.
• [color=#caa5ff]Claudia[/color]: invoca a Osty, su mano espectral, que absorbe daño y ataca cada turno.
• [color=#ffc46b]Aurora[/color]: Resplandor y Calor. Ciega a los enemigos y remata con cartas de Danza.
• [color=#ffa6dc]Irene[/color]: acumula Cuerda; con ella, las cartas de Engranaje se repiten.
• [color=#9cc9ff]Selene[/color]: canaliza orbes de agua (Ola, Bruma, Abismo, Perla) que actúan cada turno y se evocan.

[b][color=#f0cf7a]Consejos[/color][/b]
• Pasa el ratón sobre cualquier estado, reliquia o carta para ver qué hace. Haz clic en una reliquia para ver su ficha.
• Descansa 🔥 cuando tu vida esté baja. Las tiendas 💰 permiten eliminar cartas malas.
• Si pierdes, ¡vuelve a intentarlo! Cada partida es distinta. El modo fácil da más vida, enemigos más débiles y permite deshacer la última carta.
• Cada partida tiene una semilla: escríbela al elegir musa para repetir los mismos mapas, o juega el Reto diario, igual para todo el mundo."""


## Ayuda con las teclas que el jugador tiene asignadas (Opciones ▸ Controles).
static func help_text() -> String:
	var keys := {}
	for a in Main.KEY_ACTIONS:
		keys[a[0]] = Main.key_name(a[0])
	return Loc.t(HELP).format(keys)


static func help() -> void:
	var h := help_text()
	for pair in [["⚔️", "intent:attack"], ["🛡️", "intent:block"], ["⬇️", "intent:debuff"], ["⬆️", "intent:buff"], ["⚡", "ui:energy"], ["🔥", "node:rest"], ["💰", "ui:gold"]]:
		var kv: PackedStringArray = pair[1].split(":")
		h = h.replace(pair[0], Icons.bb(kv[0], kv[1], 20))
	await message(Loc.t("Cómo jugar"), h, Loc.t("¡A jugar!"), 820)


static func pause_menu() -> void:
	var G = Meta.run
	if G == null or not (Main.I.current in ["map", "combat", "reward", "shop", "rest", "event"]):
		return
	var o := _overlay()
	o.set_meta("pause", true)
	var v := _center_col(o)
	var p := UIK.panel(30)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 12)
	col.custom_minimum_size = Vector2(340, 0)
	col.add_child(_title(Loc.t("Pausa"), 32))
	var first_b: Button = null
	var firsts := []   # las lambdas capturan por valor: se acumula en un array
	var add := func(t: String, kind: String, fn: Callable) -> Button:
		var b := UIK.button(t, kind)
		b.pressed.connect(fn)
		col.add_child(b)
		firsts.append(b)
		return b
	add.call(Loc.t("Seguir jugando"), "green", func(): o.close(null))
	add.call(Loc.t("Opciones"), "", func(): Dlg.options())
	add.call(Loc.t("Cómo jugar"), "", func(): Dlg.help())
	add.call(Loc.t("Guardar y salir"), "", func():
		var where := Loc.t("Tu partida está guardada en este punto del mapa.") if Main.I.current == "map" else Loc.t("Tu partida se guarda al inicio de esta sala, y la sala se repetirá al continuar.")
		if not await confirm("%s\n[font_size=18]%s[/font_size]" % [Loc.t("¿Guardar y salir al menú?"), where], Loc.t("Guardar y salir"), Loc.t("Cancelar")):
			return
		o.close(null)
		Nav.leave_run()
		Meta.run = null
		Nav.title()
		Main.I.toast(Loc.t("Partida guardada. Puedes continuar desde el menú.")))
	add.call(Loc.t("Rendirse"), "red", func():
		if not await confirm("%s\n[font_size=18]%s[/font_size]" % [Loc.t("¿Seguro que quieres rendirte?"), Loc.t("La partida terminará como una derrota.")], Loc.t("Rendirme"), Loc.t("Seguir luchando")):
			return
		o.close(null)
		Nav.leave_run()
		G["surrender"] = true
		Nav.game_over())
	var seed_row := _row(10)
	var sl := UIK.label(Loc.t("Semilla: %d") % G.seed, 16, UIK.DIM)
	sl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	seed_row.add_child(sl)
	var cp := UIK.button(Loc.t("Copiar"), "small")
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(str(G.seed))
		Main.I.toast(Loc.t("Semilla copiada: %d") % G.seed))
	seed_row.add_child(cp)
	col.add_child(seed_row)
	p.add_child(col)
	v.add_child(p)
	if not firsts.is_empty():
		firsts[0].grab_focus.call_deferred()
