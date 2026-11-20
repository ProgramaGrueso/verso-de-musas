extends Node
## Regresión de maquetación de la pantalla de EVENTOS (y su vista de resultado).
## Recorre los 27 eventos, mide CADA cartel de opción, el título y el texto del evento, y
## pulsa la primera opción disponible para medir la pantalla de resultado ("Continuar ➜").
## Uso: godot --path . res://tests/event_layout_test.tscn   (headless también vale)
## Imprime «RESULTADO: N ok, M fallan» y sale con código 1 si algo falla.

## Tolerancia de redondeo/píxeles al medir texto dentro del rect.
const TOL := 2.0
## Margen inferior útil del viewport de 1280x720: nada de contenido puede pasar de aquí.
const SAFE_BOTTOM := 690.0
## Alturas inadmisibles de un cartel con texto de una sola línea (más grande = hueco muerto).
const MAX_SINGLE_LINE_H := 60.0

var ok := 0
var bad := 0
var failures: Array = []
var t0 := 0


func _ready() -> void:
	t0 = Time.get_ticks_msec()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var G = Eng.new_run("lia", {"seed": 7, "nm": 0, "easy": false})
	Meta.run = G
	EventScreen.EvCtx.auto = true   # sin diálogos: el test nunca se queda a la espera
	var ids := DB.events.map(func(e): return String(e.id))
	print("eventos: %d" % ids.size())
	for id: String in ids:
		var ev: Dictionary = DB.events.filter(func(e): return String(e.id) == id)[0]
		G.act = int(ev.get("act", 1))
		G.char = String(ev.get("char", "lia"))
		G.seenEvents = DB.events.filter(func(e): return String(e.id) != id).map(func(e): return String(e.id))
		# ---------- pantalla del evento ----------
		Nav.event()
		var es: EventScreen = await _screen_ready(id)
		if es == null:
			continue
		_measure(es, id, "evento (%s)" % ev.get("title", ""))
		# ---------- vista de resultado ----------
		var target: Button = null
		for c in es._opts.get_children():
			if c is Button and not (c as Button).disabled:
				target = c
				break
		if target == null:
			_check(false, "%s: no hay ninguna opción disponible" % id)
		else:
			target.pressed.emit()
			var got_result := await _wait_result(es, id)
			if got_result:
				_measure(es, id, "resultado (%s)" % ev.get("title", ""))
		EventScreen.EvCtx.auto = true
		Main.I.set_screen(Control.new(), "blank")
		await get_tree().process_frame
		await get_tree().process_frame
	EventScreen.EvCtx.auto = false
	await _others()
	print("RESULTADO: %d ok, %d fallan (%d ms)" % [ok, bad, Time.get_ticks_msec() - t0])
	for f in failures:
		print("  FALLA: ", f)
	# Se sale en el frame siguiente: un quit() inmediato puede cerrar el árbol a mitad de un
	# queue_free/tween de la última pantalla (ese cierre brusco es el que produce core dumps).
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit(1 if bad > 0 else 0)


func _screen_ready(id: String) -> EventScreen:
	for i in 20:
		await get_tree().process_frame
		var s = Main.I.screen
		if s is EventScreen and is_instance_valid(s) and (s as EventScreen)._col != null:
			var es := s as EventScreen
			# la pantalla se auto-ajusta durante dos frames tras entrar; luego debe ser estable
			for k in 3:
				await get_tree().process_frame
			return es
	_check(false, "%s: no se abrió la pantalla de evento" % id)
	return null


func _wait_result(es: EventScreen, id: String) -> bool:
	# la opción puede abrir un cartel de cartas (ya resuelto por EvCtx.auto) o un combate
	for i in 120:
		await get_tree().process_frame
		if not is_instance_valid(es) or not es.is_inside_tree():
			return false
		var btns: Array = es._opts.get_children()
		if btns.size() == 1 and (btns[0] as Button).text == "" and EventScreen._banner_text(btns[0]) != null \
				and (EventScreen._banner_text(btns[0]) as RichTextLabel).text.contains(tr("Continuar ➜")):
			for k in 4:
				await get_tree().process_frame
			return true
		if Main.I.current == "combat":
			# la opción era un combate: no hay vista de resultado que medir
			return false
	if Main.I.current == "combat":
		return false
	_check(false, "%s: la vista de resultado no apareció" % id)
	return false


func _check(cond: bool, msg: String) -> void:
	if cond:
		ok += 1
	else:
		bad += 1
		if failures.size() < 60:
			failures.append(msg)


func _src(ctl: Control) -> Rect2:
	return Rect2(ctl.get_global_transform().origin, ctl.size * ctl.get_global_transform().get_scale())


func _measure(es: EventScreen, id: String, tag: String) -> void:
	var where := "%s/%s" % [id, tag]
	var vp := es.get_viewport_rect()   # 1280x720 con stretch canvas_items
	# ---------- columna ----------
	var col := es._col
	_check(col != null, "%s: falta la columna" % where)
	if col == null:
		return
	var cr := _src(col)
	_check(cr.position.x >= 0.0 and cr.position.y >= 0.0, "%s: columna fuera por arriba/izquierda %s" % [where, cr])
	_check(cr.end.x <= vp.size.x, "%s: columna se sale por la derecha (x=%.1f)" % [where, cr.end.x])
	_check(cr.end.y <= SAFE_BOTTOM + TOL, "%s: columna se sale por abajo (y=%.1f > %.0f)" % [where, cr.end.y, SAFE_BOTTOM])
	_check(col.get_combined_minimum_size().y <= EventScreen.COL_SIZE.y * col.scale.y + TOL,
		"%s: contenido (%.1f) más alto que la columna escalada (%.1f)" % [where, col.get_combined_minimum_size().y, EventScreen.COL_SIZE.y * col.scale.y])
	_check(col.scale.y >= 0.9, "%s: columna escalada demasiado (%.2f): revisar textos" % [where, col.scale.y])
	# ---------- título y texto ----------
	var kids: Array = col.get_children()
	_check(kids.size() >= 4, "%s: columna incompleta" % where)
	if kids.size() >= 4:
		var t := kids[0] as Control
		_check(_src(t).end.y <= SAFE_BOTTOM + TOL and _src(t).end.y > 0.0, "%s: título fuera del viewport" % where)
		var th := (t as Label).get_minimum_size().y if t is Label else 0.0
		_check(t.size.y + TOL >= th, "%s: título apretado (size %.1f < mínimo %.1f)" % [where, t.size.y, th])
		_check(t.size.x <= EventScreen.COL_SIZE.x + TOL, "%s: título ensancha la columna (%.1f)" % [where, t.size.x])
		var txt := kids[1] as RichTextLabel
		_check(txt != null, "%s: falta el texto del evento" % where)
		if txt != null:
			_inside(where + " texto", txt, txt.get_parent_control(), txt.get_content_height() + 2.0, SAFE_BOTTOM)
			_check(txt.get_line_count() >= 1, "%s: texto del evento sin líneas" % where)
	# ---------- carteles de opción ----------
	var btns: Array = []
	for c in es._opts.get_children():
		if c is Button:
			btns.append(c)
	_check(btns.size() >= 1, "%s: sin opciones" % where)
	if tag.begins_with("resultado"):
		_check(btns.size() == 1 and (EventScreen._banner_text(btns[0]) as RichTextLabel).text.contains(tr("Continuar ➜")),
			"%s: la vista de resultado debe mostrar solo «Continuar ➜»" % where)
	for b: Button in btns:
		var r := EventScreen._banner_text(b)
		_check(r != null, "%s: cartel sin texto" % where)
		if r == null:
			continue
		var lines := r.get_line_count()
		var need := EventScreen.banner_need(b)
		var inner := b.size.y - 2.0 * EventScreen.BANNER_PAD_Y
		_check(b.size.y + TOL >= need, "%s: cartel apretado (alto %.1f < texto+relleno %.1f)" % [where, b.size.y, need])
		_check(b.size.y <= need, "%s: hueco muerto (alto %.1f > texto+relleno %.1f)" % [where, b.size.y, need])
		_inside(where + " cartel", r, b, r.get_content_height() + 2.0, SAFE_BOTTOM)
		_check(r.get_content_height() <= inner + TOL, "%s: texto se sale por abajo (texto %.1f > caja %.1f)" % [where, r.get_content_height(), inner])
		_check(b.size.y > 0.0, "%s: cartel de altura no positiva" % where)
		if lines <= 1:
			_check(b.size.y <= MAX_SINGLE_LINE_H, "%s: una línea con altura excesiva (%.1f)" % [where, b.size.y])
		var sb := b.get_theme_stylebox("focus")
		_check(sb != null and sb.border_width_top == 2, "%s: el cartel perdió el borde de foco" % where)
		_check(b.custom_minimum_size.y + TOL >= b.size.y, "%s: mínimo del cartel (%.1f) no sostiene su alto (%.1f)" % [where, b.custom_minimum_size.y, b.size.y])


## Pantallas hermanas con «tema de eventos» (fuera de la lista de este bug): solo se MIDEN y
## se informan; si fallan no cuentan como fallo de este test (ver informe para el orquestador).
func _others() -> void:
	var G = Meta.run
	# Recompensas: cada banda mide 76 px fijos para textos de 1, 2 o 3 líneas
	var rew := Eng.combat_reward(G, "boss")
	rew["card_taken"] = true
	rew["boss_taken"] = true
	Nav.reward(rew, "boss")
	for i in 6:
		await get_tree().process_frame
	for b in _find_buttons(Main.I.screen):
		for r: RichTextLabel in b.find_children("*", "RichTextLabel", true, false):
			var need: float = r.get_content_height() + 24.0   # 12 px de relleno arriba y abajo (UIK.button)
			if b.size.y + TOL < need or b.size.y > need + 24.0:
				_sibling("recompensas", b, r, need)
				break
	Main.I.set_screen(Control.new(), "blank")
	await get_tree().process_frame
	# Hoguera: las dos tarjetas comparten 240 px fijos con textos de longitud distinta
	Nav.rest()
	for i in 6:
		await get_tree().process_frame
	if not (Main.I.screen is RestScreen):
		_sibling_info("hoguera", "no disponible con la compilación actual")
		return
	var heights := []
	for b: Button in _find_buttons(Main.I.screen):
		heights.append(b.size.y)
	_sibling_info("hoguera", "alturas de tarjeta: %s (fijas por custom_minimum_size 300x240)" % str(heights))


var _sib_bad := 0


func _sibling(where: String, b: Button, r: RichTextLabel, need: float) -> void:
	_sib_bad += 1
	if _sib_bad <= 4:
		print("  AVISO %s: cartel %.0f px vs texto+relleno %.0f px — «%s» (%d líneas)" % [where, b.size.y, need, r.text.substr(0, 40).replace("\n", " / "), r.get_line_count()])
	if _sib_bad == 5:
		print("  AVISO %s: (más casos omitidos)" % where)


func _sibling_info(where: String, msg: String) -> void:
	print("  INFO %s: %s" % [where, msg])


func _find_buttons(n: Node) -> Array:
	var out: Array = []
	for c in n.get_children():
		if c is Button and c.find_children("*", "RichTextLabel", true, false).size() > 0:
			out.append(c)
		out.append_array(_find_buttons(c))
	return out


## Un control de texto y su caja deben quedar dentro de la caja padre, con el texto sin recortes.
func _inside(label: String, c: Control, box: Control, text_h: float, safe_bottom: float) -> void:
	if box == null:
		_check(false, "%s: sin caja" % label)
		return
	var cc := _src(c)
	var bb := _src(box)
	_check(cc.position.x >= bb.position.x - TOL and cc.end.x <= bb.end.x + TOL, "%s: texto se sale en horizontal %s vs %s" % [label, cc, bb])
	_check(cc.position.y >= bb.position.y - TOL and cc.end.y <= bb.end.y + TOL, "%s: texto se sale en vertical %s vs %s" % [label, cc, bb])
	_check(text_h <= cc.size.y + TOL, "%s: texto (%0.1f) más alto que su rect (%.1f)" % [label, text_h, cc.size.y])
	_check(bb.position.y >= -TOL and bb.end.y <= safe_bottom + TOL, "%s: caja fuera del viewport %s" % [label, bb])
	_check(cc.size.x > 1.0 and cc.size.y > 0.0, "%s: rect sin tamaño %s" % [label, cc])
