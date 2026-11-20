class_name EventScreen
extends Control
## Eventos aleatorios del camino: arte a la izquierda, texto y opciones a la derecha.

## Marca de la columna de contenido (la usan las herramientas de captura y el test de regresión).
## Al 100 % es 700,96 · 530×560. Con el texto más grande (Opciones ▸ Tamaño del texto) la columna gana ancho
## (el arte cede a la izquierda) y alto (hasta SAFE_BOTTOM): `_layout_for_scale()` las fija al construir.
static var COL_POS := Vector2(700, 96)
static var COL_SIZE := Vector2(530, 560)
static var ART_RECT := Rect2(50, 86, 610, 580)
## Relleno interno de los carteles de opción (izq./der.) y arriba/abajo.
const BANNER_PAD_X := 22.0
const BANNER_PAD_Y := 10.0
## Si un cartel mide más que esto (texto desmedido), su texto pasa a desplazarse en vez de desbordar.
const MAX_BANNER_H := 260.0
## Margen inferior del viewport que nunca debe ocupar contenido.
const SAFE_BOTTOM := 690.0

var _text: RichTextLabel
var _opts: VBoxContainer
var _col: VBoxContainer


func _ready() -> void:
	var G = Meta.run
	Sfx.music("rest", G.act)
	var ev := RunGen.pick_event(G)
	add_child(UIK.backdrop(G.act))
	var dark := ColorRect.new()
	dark.color = Color(0.03, 0.04, 0.06, 0.86)
	UIK.full_rect(dark)
	add_child(dark)
	_layout_for_scale()
	_build_art(ev)
	_col = VBoxContainer.new()
	_col.position = COL_POS
	_col.size = COL_SIZE
	_col.add_theme_constant_override("separation", 14)
	add_child(_col)
	var t := UIK.label(ev.title, 36, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t, 6)
	# un título largo no debe ensanchar la columna: se parte en varias líneas
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(t)
	_text = UIK.rich("[center]%s[/center]" % EventsLogic.text_for(G, ev), 20, Color("#e8e4f4"))
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_col.add_child(_text)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	_col.add_child(sp)
	_opts = VBoxContainer.new()
	_opts.add_theme_constant_override("separation", 12)
	_col.add_child(_opts)
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
			# el resultado suele ser corto: las opciones nuevas caben sin más ajustes
			await get_tree().process_frame
			await get_tree().process_frame
			fit_layout()
			cb.grab_focus.call_deferred())
		_opts.add_child(b)
	if first_opt != null:
		first_opt.grab_focus.call_deferred()
	# con el ancho ya resuelto (y la fuente cargada), cada cartel toma la altura justa de su texto
	await get_tree().process_frame
	await get_tree().process_frame
	fit_layout()
	UIK.fade_in(self, 0.3)


## Geometría según la escala de texto con la que se construye la pantalla: 0 al 100 %, 1 al 130 %.
## Al 130 % la columna pasa a 620,96 · 620×594 (pie en SAFE_BOTTOM) y el arte a 50..580; al 100 % nada cambia.
static func _layout_for_scale() -> void:
	var k := clampf((UIK.text_scale - 1.0) / 0.3, 0.0, 1.0)
	COL_POS = Vector2(roundf(700.0 - 80.0 * k), 96.0)
	COL_SIZE = Vector2(roundf(530.0 + 90.0 * k), roundf(560.0 + (SAFE_BOTTOM - 96.0 - 560.0) * k))
	ART_RECT = Rect2(50, 86, roundf(610.0 - 80.0 * k), 580)


## Deja la pantalla consistente: cada cartel con la altura exacta de su texto y la columna
## completa dentro del viewport. Idempotente; la llaman _ready y el test de regresión.
func fit_layout() -> void:
	_fit_banners()
	_fit_column()


## Alto real del texto de un cartel, partido en líneas al ancho que va a tener.
## Se fija el ancho antes de leer get_content_height() porque puede calcularse antes de que el
## nodo tenga su rect: con ancho 1 px el texto se parte en decenas de líneas y el cartel crecería
## al máximo sin motivo (el «desborda con pocas líneas» del informe).
static func content_height(b: Button) -> float:
	var r := _banner_text(b)
	if r == null:
		return 0.0
	var w := text_width(b)
	if b.size.y <= 1.0 or absf(r.size.x - w) > 0.5:
		# aún sin rect: se le da el ancho final y se recalcula el mínimo (el contenedor lo
		# recolocará igual en cuanto pueda; así la medida es la definitiva)
		r.size = Vector2(w, maxf(r.size.y, 1.0))
		b.update_minimum_size()
	return r.get_content_height()


## Ancho útil del texto dentro de un cartel (descontado el relleno de su estilo).
static func text_width(b: Button) -> float:
	var sb := b.get_theme_stylebox("normal")
	var pad := (sb.content_margin_left + sb.content_margin_right) if sb != null else 2.0 * BANNER_PAD_X
	return maxf(b.size.x - pad, 1.0)


## Altura que necesita un cartel: texto partido + relleno vertical.
## Es el ÚNICO número que fija su altura (mínimo del contenedor y size): ni huecos ni recortes.
static func banner_need(b: Button) -> float:
	return ceilf(content_height(b) + 2.0 * BANNER_PAD_Y)


## Ajusta la altura de cada cartel al texto ya partido en líneas por el ancho de la columna.
func _fit_banners() -> void:
	for c in _opts.get_children():
		if not (c is Button):
			continue
		var b := c as Button
		var r := _banner_text(b)
		if r == null:
			continue
		var h := banner_need(b)
		var clamps := h > MAX_BANNER_H   # texto desmedido: se desplaza en vez de desbordar el viewport
		r.fit_content = not clamps
		r.scroll_active = clamps
		r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		if clamps:
			h = MAX_BANNER_H
		# el mismo número alimenta el mínimo del contenedor y la altura real: sin huecos ni recortes
		b.custom_minimum_size.y = h
		b.size.y = h
		r.position = Vector2(BANNER_PAD_X, BANNER_PAD_Y)
		r.size = Vector2(maxf(b.size.x - 2.0 * BANNER_PAD_X, 1.0), maxf(b.size.y - 2.0 * BANNER_PAD_Y, 1.0))


## Si título + texto + opciones no caben en la columna, se reparte el sobrante quitando antes
## los espacios decorativos y, si hiciera falta, escalando el bloque para que nunca se salga.
func _fit_column() -> void:
	if _col == null:
		return
	_col.scale = Vector2.ONE
	var need := _col.get_combined_minimum_size().y
	var avail := COL_SIZE.y
	if need > avail and need > 0.0:
		# 0.96 de margen: el alto real de un RichTextLabel puede quedar unas décimas por encima del
		# mínimo declarado y, una vez escalado, ese redondeo no debe volver a recortarlo.
		var k := clampf(avail * 0.96 / need, 0.55, 1.0)
		_col.scale = Vector2(k, k)
	# nada puede quedar empujado fuera del viewport: con el bloque escalado, su centro
	# se recoloca para que el pie quede dentro de SAFE_BOTTOM.
	var end_y := COL_POS.y + need * _col.scale.y
	if end_y > SAFE_BOTTOM:
		_col.position = Vector2(COL_POS.x, SAFE_BOTTOM - need * _col.scale.y)
	else:
		_col.position = COL_POS


static func _banner_text(b: Button) -> RichTextLabel:
	for c in b.get_children():
		if c is RichTextLabel:
			return c
	return null


func _build_art(ev: Dictionary) -> void:
	var rect := ART_RECT
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
## No fija altura: _fit_banners() la calcula a partir del texto una vez partido en líneas.
static func _banner(title: String, hint: String) -> Button:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_ALL
	var n := UIK.stylebox(Color("#1c3a44"), Color("#52858c"), 2, 16, 6)
	var h := UIK.stylebox(Color("#27505c"), Color("#9fd6dc"), 2, 16, 10)
	var d := UIK.stylebox(Color("#14222a"), Color("#2c444a"), 2, 16, 0)
	for st: StyleBoxFlat in [n, h, d]:
		st.content_margin_left = BANNER_PAD_X
		st.content_margin_right = BANNER_PAD_X
		st.content_margin_top = BANNER_PAD_Y
		st.content_margin_bottom = BANNER_PAD_Y
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("focus", h)
	b.add_theme_stylebox_override("pressed", h)
	b.add_theme_stylebox_override("disabled", d)
	b.mouse_entered.connect(func(): if not b.disabled: Sfx.play("select_soft", 0.4))
	b.pressed.connect(func(): Sfx.play("click"))
	var r := UIK.rich("[b][color=#f0cf7a]%s[/color][/b]%s" % [title, ("\n" + _tint(hint)) if hint != "" else ""], 19, Color("#e8f2f2"))
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# el texto no se pega a bordes ni flota lejos de ellos: solo se centra verticalmente si
	# cabe con holgura (el desplazamiento lo fija _fit_banners en coordenadas del panel)
	r.fit_content = false
	r.scroll_active = false
	r.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
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
	## Test headless: sin diálogos que esperen a un humano; elige la primera carta válida.
	static var auto: bool = false

	func pick_card(title: String, filter: Callable, n: int, upgrade_preview: bool = false) -> Array:
		var G = Meta.run
		var cards: Array = G.deck.filter(filter)
		if auto:
			return cards.slice(0, n)
		return await Dlg.pick_cards({"title": title, "upgradePreview": upgrade_preview, "cards": cards, "n": n, "cancel": "Cancelar"})

	## Elegir 1 carta nueva entre `ids` (no están en el mazo). Devuelve [] si se salta.
	func choose_new(title: String, ids: Array) -> Array:
		var G = Meta.run
		if ids.is_empty():
			return []
		if auto:
			return [Eng.make_card(G, ids[0])]
		var cards := []
		for id in ids:
			var c := Eng.make_card(G, id)
			if Eng.has_relic(G, "huevo") and Eng.can_upgrade(c):
				c.up = true
			cards.append(c)
		return await Dlg.pick_cards({"title": title, "sub": "Se añadirá a tu mazo.", "cards": cards, "n": 1, "cancel": "Saltar", "big": true, "confirmLabel": "Tomar carta"})
