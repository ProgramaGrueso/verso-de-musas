extends Node
## Auditoría en vivo de la interfaz: recorre TODAS las pantallas (~50 estados) y diálogos (~25) a 1280×720 y
## 1600×900 y con el tamaño de texto al 100 / 115 / 130 % (`UIK.text_scale`), y mide con la fuente real
## (`TextParagraph` con la fuente, el tamaño y el modo de partir línea de cada control) cada Button, Label y
## RichTextLabel visible. Falla si:
##   · el texto de un botón (con su icono) no cabe en la caja interior del botón (se recorta o se sale), o su
##     fuente baja de 12 px;
##   · un Label no cabe en su rect (ancho o alto), oculta líneas o se recorta con «…»;
##   · un RichTextLabel sin scroll tiene más contenido que alto (se corta);
##   · un texto se sale del rect de su padre o de su caja visible (botón, panel, carta…);
##   · un texto visible se sale de la pantalla 1280×720 lógica (lo que recorta un ScrollContainer no cuenta);
##   · el texto de un botón invade el rect de un hermano con el que no comparte espacio.
## Tolerancia 2 px. Cada fallo dice pasada (ventana@escala), pantalla, archivo dueño, control y medida.
##
## Antes de medir nada se comprueba el propio detector («canario»: una pantalla con 6 textos rotos a propósito);
## si alguno no se marca, el test falla (así no puede volver a dar «0 ok, 0 fallan» sin medir nada).
##
## El test juega partidas falsas (historial, logros, rachas, victorias): para no ensuciar el perfil del jugador
## se relanza solo con `XDG_DATA_HOME` apuntando a un perfil temporal vacío (`/tmp/vdm_ui_layout`).
##
## Uso (con ventana mide también 1600×900; sin ventana solo la geometría lógica de 1280×720):
##   godot --path . res://tests/ui_layout_test.tscn
##   godot --headless --path . res://tests/ui_layout_test.tscn
## Opciones tras `--`:  scale 1.3 · window 1600x900 · only <parte de la etiqueta> · shots DIR · verbose · lang en
##   (`lang en` mide la interfaz en inglés; también vale `VDM_LANG=en godot …`)
##   godot --path . res://tests/ui_layout_test.tscn -- scale 1.3 only select shots /tmp/capturas

const TOL := 2.0
const VP := Vector2(1280, 720)
const SCALES := [1.0, 1.15, 1.3]
const WINDOWS := [Vector2i(1280, 720), Vector2i(1600, 900)]
const ISO_DIR := "/tmp/vdm_ui_layout"
const Iso := preload("res://tests/isolated_run.gd")
## Rótulos que son arte (logo de la portada): solo se exige que no se salgan de la pantalla.
const BIG_ART := ["VERSO\nDE MUSAS"]

var oks := 0
var fails := 0
var by_file := {}       # archivo dueño -> fallos únicos
var seen := {}          # firma del fallo -> [ventanas] (cada fallo se imprime una vez por escala)
var bug := ""           # pantalla/diálogo en curso
var pass_tag := ""      # «1280x720@115»
var scale := 1.0
var win := Vector2i(1280, 720)
var shots_dir := ""
var only := ""
var verbose := false
var scales: Array = SCALES
var windows: Array = WINDOWS
var n_screens := 0
var n_dialogs := 0
var _items: Array = []
var _failed_ctrl := {}  # controles que ya han fallado en esta medida (no se repite el mismo fallo por otra regla)
var _canary := {}       # nombre del control roto -> detectado
var _DIGITS := RegEx.create_from_string("\\d+")


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if Iso.needed():
		await Iso.relaunch(self, ISO_DIR)
		return
	Iso.watch_parent(self)
	var i := 0
	while i < args.size():
		match args[i]:
			"shots":
				shots_dir = args[i + 1]
				i += 1
			"scale":
				scales = [float(args[i + 1])]
				i += 1
			"window":
				var p: PackedStringArray = args[i + 1].split("x")
				windows = [Vector2i(int(p[0]), int(p[1]))]
				i += 1
			"only":
				only = args[i + 1]
				i += 1
			"verbose":
				verbose = true
			"lang":
				Loc.set_lang(args[i + 1], {})   # solo esta ejecución: no toca los ajustes guardados
				i += 1
		i += 1
	print("Idioma: %s" % Loc.lang())
	if DisplayServer.get_name() == "headless" and windows.size() > 1:
		windows = [Vector2i(1280, 720)]
		print("(sin ventana: solo la geometría lógica de 1280×720; 1600×900 se mide con ventana)")
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	Meta.settings["calm"] = true   # sin sacudidas ni animaciones: medidas estables
	CombatScreen.test_mode = true
	var bg: Node = load("res://scenes/main.tscn").instantiate()
	add_child(bg)
	await _frames(4)
	await _self_check()
	for s in scales:
		for w in windows:
			await _pass(s, w)
	UIK.text_scale = 1.0
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	print("")
	print("Pasadas: %d (%s × %s) · pantallas medidas: %d · diálogos y avisos medidos: %d" % [scales.size() * windows.size(),
		"/".join(scales.map(func(x): return "%d%%" % roundi(x * 100))), "/".join(windows.map(func(v): return "%dx%d" % [v.x, v.y])), n_screens, n_dialogs])
	if not by_file.is_empty():
		var parts := []
		for k in by_file.keys():
			parts.append("%s %d" % [k, by_file[k]])
		print("Fallos por archivo: " + ", ".join(parts))
	print("RESULTADO: %d ok, %d fallan" % [oks, fails])
	await _clean_exit()
	get_tree().quit(1 if fails > 0 else 0)


func _clean_exit() -> void:
	for c in Main.I.overlay_host.get_children():
		Main.I.overlay_host.remove_child(c)
		c.queue_free()
	Tip.hide_all()
	if Main.I.screen != null and is_instance_valid(Main.I.screen):
		Main.I.screen_host.remove_child(Main.I.screen)
		Main.I.screen.queue_free()
	Main.I.screen = null
	await _frames(3)


func _settle(frames: int = 12) -> void:
	await _frames(frames + (4 if shots_dir != "" else 0))   # sin frame_post_draw: en Wayland puede no llegar nunca


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _wanted(tag: String) -> bool:
	return only == "" or tag.contains(only)


# ============================== autocomprobación ==============================
## Pantalla con textos rotos a propósito: cada uno tiene que salir como fallo. Si no, el detector está roto.
func _self_check() -> void:
	bug = "canario"
	pass_tag = "canario"
	var s := Control.new()
	UIK.full_rect(s)
	var box := PanelContainer.new()   # caja visible de 200 px con un rótulo que no cabe
	box.position = Vector2(60, 60)
	var inner := Control.new()
	inner.custom_minimum_size = Vector2(200, 40)
	box.add_child(inner)
	var l1 := UIK.label("Este rótulo es mucho más ancho que su caja de doscientos píxeles", 20)
	l1.name = "C_label_ancho"
	inner.add_child(l1)
	s.add_child(box)
	var b := Button.new()
	b.name = "C_boton_recortado"
	b.text = "Botón con un texto larguísimo que se recorta"
	b.add_theme_font_override("font", UIK.font("bold"))
	b.add_theme_font_size_override("font_size", 22)
	b.clip_text = true
	b.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	b.position = Vector2(60, 160)
	b.size = Vector2(160, 50)
	s.add_child(b)
	var l2 := UIK.label("Me salgo por la derecha de la pantalla", 20)
	l2.name = "C_fuera_pantalla"
	l2.position = Vector2(1180, 260)
	s.add_child(l2)
	var r := UIK.rich("Primera línea\nSegunda línea\nTercera línea\nCuarta línea", 18)
	r.name = "C_rich_cortado"
	r.fit_content = false
	r.position = Vector2(60, 320)
	r.size = Vector2(300, 30)
	s.add_child(r)
	var l3 := UIK.label("una dos tres cuatro cinco seis siete ocho nueve diez once doce", 18)
	l3.name = "C_lineas_ocultas"
	l3.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l3.max_lines_visible = 1
	l3.position = Vector2(60, 400)
	l3.size = Vector2(160, 30)
	s.add_child(l3)
	var l4 := UIK.label("Nombre muy largo recortado con puntos", 20)
	l4.name = "C_label_elipsis"
	l4.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	l4.position = Vector2(60, 480)
	l4.size = Vector2(120, 30)
	s.add_child(l4)
	for n in ["C_label_ancho", "C_boton_recortado", "C_fuera_pantalla", "C_rich_cortado", "C_lineas_ocultas", "C_label_elipsis"]:
		_canary[n] = false
	Main.I.set_screen(s, "canario")
	await _settle(6)
	await _measure(s)
	var miss := []
	for n in _canary.keys():
		if not _canary[n]:
			miss.append(n)
	if miss.is_empty():
		print("Autocomprobación: el detector marca los %d textos rotos a propósito" % _canary.size())
	else:
		fails += 1
		print("  ✗ [canario] el detector NO marca: %s" % ", ".join(miss))
	_canary.clear()


# ============================== pasadas ==============================
func _pass(s: float, w: Vector2i) -> void:
	scale = s
	win = w
	pass_tag = "%dx%d@%d" % [w.x, w.y, roundi(s * 100)]
	print("== pasada %s" % pass_tag)
	UIK.text_scale = s
	Meta.settings["text_scale"] = s
	get_window().size = w
	await _frames(8)
	if DisplayServer.get_name() != "headless" and get_window().size != w:
		print("  (aviso: la ventana quedó en %s en vez de %s)" % [get_window().size, w])
	seed(1234)
	var G := _new_run("zafiro", 7)
	await _screens(G)
	await _dialogues(G)
	await _extremos(G)
	await _banners()


func _new_run(musa: String, sd: int) -> Dictionary:
	var G := Eng.new_run(musa, {"seed": sd})
	G.map = RunGen.gen_map_game(G)
	Meta.run = G
	return G


func _screens(G: Dictionary) -> void:
	for id in DB.relics.keys():
		if G.relics.size() >= 4:
			break
		if DB.relics[id].rarity in ["common", "uncommon"]:
			G.relics.append(id)
	G.potions[0] = DB.potions.keys()[0]
	Meta.data["nmBy"] = {}
	Meta.clear_save()
	await scr("title", func(): Nav.title())
	await scr("select", func(): Nav.select())
	# la ficha de cada musa mide distinto (descripción y reliquia): la selección se mide con todas
	for c in DB.playable():
		await scr("select_" + c, func(): TitleScreen.last_char = c; Nav.select())
	# portada con partida guardada y Pesadilla desbloqueada (menú más largo + rótulo de Pesadilla)
	for c in DB.playable():
		Meta.data["nmBy"][c] = 10
	Meta.save_run(G)
	await scr("title_guardada_pesadilla", func(): Nav.title())
	Meta.clear_save()
	await scr("select_pesadilla", func():
		Nav.select()
		var ss: SelectScreen = Main.I.screen
		ss.nm = 10
		ss.seed_txt = "semilla-de-un-amigo-0123456789"
		ss._render_nm()
		ss._render_toggle())
	for c in DB.playable():
		await scr("select_pesadilla_" + c, func():
			TitleScreen.last_char = c
			Nav.select()
			var ss: SelectScreen = Main.I.screen
			ss.nm = 10
			ss._render_nm()
			ss._render_toggle())
	Meta.run = G
	await scr("favor", func(): Nav.favor())
	await scr("map", func(): Nav.map())
	await scr("combat", func(): Nav.combat(["dockrat", "jelly"], "normal"))
	await scr("combat_elite", func(): Nav.combat([RunGen.encounter_game(G, "elite")[0], "jelly", "crab"], "elite"))
	await scr("combat_boss", func(): Nav.combat([RunGen.boss_id(G)], "boss"))
	await scr("reward", func(): Nav.reward(Eng.combat_reward(G, "normal"), "normal"))
	await scr("reward_boss", func(): Nav.reward(Eng.combat_reward(G, "boss"), "boss"))
	await scr("shop", func(): Nav.shop())
	await scr("event", func(): Nav.event())
	await scr("rest", func(): Nav.rest())
	await scr("history", func(): Nav.history())
	await scr("gallery", func(): Nav.gallery())
	await scr("achievements", func(): Nav.achievements("ach"))
	await scr("mastery", func(): Nav.achievements("mastery"))
	await scr("unlocks", func(): Nav.achievements("unl"))
	var tabs: Array = DB.playable().duplicate()
	tabs.append_array(["neutral", "relics"])
	for t in tabs:
		await scr("compendium_" + t, func(): CompendiumScreen.tab = t; Nav.compendium())
	await scr("daily", func(): DailyScreen.sel = ""; Nav.daily())
	await scr("daily_pasado", func(): DailyScreen.sel = Daily.shift(Daily.key_today(), -3); DailyScreen.ym = Vector2i(int(DailyScreen.sel.substr(0, 4)), int(DailyScreen.sel.substr(5, 2))); Nav.daily())
	for musa in DB.playable():
		var H := _new_run(musa, 9)
		await scr("combat_" + musa, func(): Meta.run = H; Nav.combat(["dockrat", "jelly", "crab"], "normal"))
	Meta.run = G
	G.stats.fights = 9
	G.stats.kills = 33
	G.stats.turns = 41
	await scr("end_defeat", func(): Nav.game_over())
	Meta.run = G
	await scr("end_victory", func(): Main.I.set_screen(EndScreen.create_victory(G, true), "end"))
	Meta.run = G
	await scr("ending", func(): Nav.victory())
	Meta.run = G
	# mismas pantallas con contenido de verdad largo
	Meta.data["daily"] = {"2026-11-19": {"win": true}, "2026-11-18": {"win": true}, "2026-11-17": {"win": true}}
	Meta.data["s"]["dailyStreakBest"] = 120
	await scr("title_racha", func(): Nav.title(), true)
	await scr("end_victory_larga", func(): _end_largo(G))
	await scr("historial_lleno", func(): _historial_lleno())
	await scr("logros_lleno", func(): _logros_lleno())
	await scr("maestria_llena", func(): Nav.achievements("mastery"))
	Meta.run = G


## Construye una pantalla, deja que se coloque lo diferido y la mide (más la barra superior si se ve).
func scr(tag: String, build: Callable, hold: bool = false) -> void:
	if not _wanted(tag):
		return
	bug = tag
	build.call()
	await _settle(14 if hold else 12)
	if hold:
		await _frames(30)   # deja terminar fundidos y tweens de vuelta al tamaño normal
	n_screens += 1
	await _measure(Main.I.screen)
	if Main.I.top != null and Main.I.top.visible:
		_measure_now(Main.I.top)
	await _shot_now(tag)


func _measure(root: Node) -> void:
	if root == null:
		return
	await get_tree().process_frame
	_failed_ctrl.clear()
	_measure_now(root)


func _measure_now(root: Node) -> void:
	_items.clear()
	_collect(root, false)
	if verbose:
		print("  · %s %s: %d textos" % [pass_tag, bug, _items.size()])
	for it in _items:
		_check(it)
	_check_overlaps(root)


## Textos de bloques distintos de la pantalla (cabecera, pestañas, columnas, filas colocadas a mano…) que se
## pisan: cada uno cabe en su caja, pero las cajas se montan (p. ej. un subtítulo que crece al 130 % y cae
## sobre las pestañas). Se compara el rect de la tinta (lo que ocupa el texto), no el del control.
func _check_overlaps(root: Node) -> void:
	var boxes := []
	for it in _items:
		var c: Control = it.c
		if not is_instance_valid(c) or _failed_ctrl.has(c) or it.inb:
			continue
		var g := _group_of(c, root)
		if g == null:
			continue
		var r := _ink_rect(c)
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		r = r.intersection(_visible_clip(c))
		if r.size.x < 1.0 or r.size.y < 1.0:
			continue
		boxes.append([c, g, r])
	for i in boxes.size():
		var a: Array = boxes[i]
		if _failed_ctrl.has(a[0]):
			continue
		for j in range(i + 1, boxes.size()):
			var b: Array = boxes[j]
			if a[1] == b[1]:
				continue
			var ov: Rect2 = (a[2] as Rect2).intersection(b[2])
			if ov.size.x > 3.0 and ov.size.y > 3.0:
				_fail(a[0], "%s «%s» pisa %.0f×%.0f px a %s «%s»" % [a[0].get_class(), _short(_text_of(a[0]), 24), ov.size.x, ov.size.y, b[0].get_class(), _short(_text_of(b[0]), 24)])
				break


## Bloque de la pantalla al que pertenece `c`: su antepasado hijo directo de `root`.
func _group_of(c: Node, root: Node) -> Node:
	var n := c
	while n != null and n.get_parent() != root:
		n = n.get_parent()
	return n


## Rect que ocupa el texto de verdad (alineación incluida), no el del control.
func _ink_rect(c: Control) -> Rect2:
	var gr := c.get_global_rect()
	if c is Button:
		var b := c as Button
		if b.text == "":
			return Rect2()
		var pad := b.get_theme_stylebox("normal").get_minimum_size()
		var need := _text_size(b.text, b.get_theme_font("font"), b.get_theme_font_size("font_size"), b.size.x - pad.x - UIK._icon_w(b), b.autowrap_mode)
		return _glyph_rect(b, need)
	if c is Label:
		var l := c as Label
		var need := _text_size(l.text, l.get_theme_font("font"), l.get_theme_font_size("font_size"), l.size.x, l.autowrap_mode, float(l.get_theme_constant("line_spacing")))
		need = need.min(gr.size)
		var x := gr.position.x
		match l.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x += (gr.size.x - need.x) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				x = gr.end.x - need.x
		var y := gr.position.y
		match l.vertical_alignment:
			VERTICAL_ALIGNMENT_CENTER:
				y += (gr.size.y - need.y) / 2.0
			VERTICAL_ALIGNMENT_BOTTOM:
				y = gr.end.y - need.y
		return Rect2(x, y, need.x, need.y)
	if c is RichTextLabel:
		var r := c as RichTextLabel
		var w := minf(gr.size.x, float(r.get_content_width()))
		var h := minf(gr.size.y, float(r.get_content_height()))
		var x2 := gr.position.x
		match r.horizontal_alignment:
			HORIZONTAL_ALIGNMENT_CENTER:
				x2 += (gr.size.x - w) / 2.0
			HORIZONTAL_ALIGNMENT_RIGHT:
				x2 = gr.end.x - w
		return Rect2(x2, gr.position.y, w, h)
	return Rect2()


func _shot_now(tag: String) -> void:
	if shots_dir == "":
		return
	var dir := "%s/%s" % [shots_dir, pass_tag]
	DirAccess.make_dir_recursive_absolute(dir)
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [dir, tag])


# ============================== diálogos ==============================
func _dialogues(G) -> void:
	await dlg("dlg_confirm", func(): Dlg.confirm("¿Seguro que quieres continuar sin elegir una carta?", "Sí, continuar", "No, volver"))
	await dlg("dlg_confirm_largo", func(): Dlg.confirm("¿Seguro que quieres rendirte?\n[font_size=18]La partida terminará como una derrota.[/font_size]", "Rendirme", "Seguir luchando"))
	await dlg("dlg_message", func(): Dlg.message("Cómo jugar", Dlg.HELP, "¡A jugar!", 820))
	await dlg("dlg_help", func(): Dlg.help())
	await dlg("dlg_text_input", func(): Dlg.text_input("Semilla", "Escribe un número o una palabra para repetir los mismos mapas (por ejemplo, la semilla de una partida de un amigo). Déjalo vacío para una partida aleatoria.", "abc", "aleatoria"))
	await dlg("dlg_options", func(): Dlg.options())
	await dlg("dlg_controls", func(): Dlg.controls())
	var rid := ""
	for id in DB.relics.keys():
		if rid == "" or str(DB.relics[id].d).length() > str(DB.relics[rid].d).length():
			rid = id
	await dlg("dlg_relic_info", func(): Dlg.relic_info(rid))
	Meta.run = G
	Main.I.current = "map"
	await dlg("dlg_pause", func(): Dlg.pause_menu())
	var cards := []
	for i in 9:
		cards.append(G.deck[i % G.deck.size()])
	await dlg("dlg_view_cards", func(): Dlg.view_cards("Tu mazo", cards, null))
	await dlg("dlg_view_cards_vacio", func(): Dlg.view_cards("Tu mazo", []))
	var big := []
	for i in 40:
		var c := Eng.make_card(G, G.deck[i % G.deck.size()].id)
		c.uid = 5000 + i
		big.append(c)
	await dlg("dlg_pick_cards", func(): Dlg.pick_cards({"title": "Elige una carta", "sub": "Se añadirá a tu mazo.", "cards": big.slice(0, 9), "n": 1, "cancel": "Saltar", "big": true, "confirmLabel": "Tomar carta"}))
	await dlg("dlg_pick_muchas", func(): Dlg.pick_cards({"title": "Elige una carta para mejorar", "sub": "Pasa el ratón (o el foco) por una carta para ver al lado cómo queda mejorada.", "upgradePreview": true, "cards": big, "n": 1, "cancel": "Cancelar", "confirmLabel": "Mejorar"}))
	await dlg("dlg_pick_multi", func(): Dlg.pick_cards({"title": "Descarta 2 cartas", "sub": "Elige de tu mano.", "cards": big.slice(0, 6), "n": 2}))
	await dlg("dlg_upgrade_compare", func(): Dlg.upgrade_compare(G.deck[0].duplicate(), null))
	await dlg("dlg_tooltip", func(): _tooltip(G))


## Textos largos y estados límite: los botones y columnas del juego tienen que seguir dejando el texto dentro.
func _extremos(G) -> void:
	await scr("shop_oro_largo", func():
		Meta.run = G
		G.gold = 9876543
		Nav.shop())
	G.gold = 99
	var H := _new_run("zafiro", 5)
	for c in H.deck:
		c.up = true
	Eng.add_relic(H, "reloj_roto")
	await scr("rest_reloj", func(): Meta.run = H; Nav.rest())
	Meta.run = G
	var ids := []
	for id in DB.relics.keys():
		if DB.relics[id].rarity == "boss":
			ids.append(id)
	var rew := Eng.combat_reward(G, "boss")
	rew["bossRelics"] = ids.slice(0, 3) if ids.size() >= 3 else ids
	await scr("reward_reliquia_jefe", func(): Nav.reward(rew, "boss"))
	Meta.run = G
	await scr("evento_largo", func(): Nav.event())
	Meta.run = G
	await dlg("dlg_confirm_maraton", func(): Dlg.confirm("¿Quieres salir al menú principal?\n[font_size=18]Tu partida está guardada en este punto del mapa y podrás continuar desde el menú cuando quieras; la sala en curso se repetirá.[/font_size]", "Guardar y salir", "Seguir jugando"))
	await dlg("dlg_view_60", func(): _view_60(G))
	await dlg("dlg_pick_22", func(): _pick_22(G))
	await dlg("dlg_message_mazo", func(): Dlg.message("Detalle de la partida", _mazo_texto(), "Cerrar", 820))
	await dlg("dlg_confirm_largo_label", func(): Dlg.confirm("¿Comprar [b][color=#f0cf7a]Danza de las Siete Velas[/color][/b] por 187 de oro?", "Comprar", "Dejarlo para luego"))


## Avisos de progreso (logro / contenido nuevo / Galería) con los textos más largos del juego.
func _banners() -> void:
	var ub: UnlockBanner = null
	for c in Main.I.get_children():
		if c is UnlockBanner:
			ub = c
	if ub == null:
		return
	var a_long: Dictionary = {}
	for a in Progress.achievements():
		if a_long.is_empty() or (str(a.n) + str(a.d)).length() > (str(a_long.n) + str(a_long.d)).length():
			a_long = a
	var g_long: Dictionary = {}
	for g in Progress.groups():
		if g_long.is_empty() or Progress.group_text(g).length() > Progress.group_text(g_long).length():
			g_long = g
	var lore: Dictionary = {}
	for l in DB.lore:
		if lore.is_empty() or str(l.title).length() > str(lore.title).length():
			lore = l
	var list := [["banner_logro", func(): ub._on_ach(a_long), str(a_long.n)],
		["banner_contenido", func(): ub._on_content(g_long), UnlockBanner._cap(Progress.group_text(g_long))],
		["banner_galeria", func(): ub._on_lore(lore), str(lore.title)]]
	for b in list:
		if not _wanted(b[0]):
			continue
		bug = b[0]
		for ch in ub.get_children():
			ch.queue_free()
		ub._free_at = 0.0
		await _frames(2)
		b[1].call()
		await get_tree().create_timer(0.6).timeout   # la entrada dura 0,38 s
		# los logros que la propia prueba consigue por el camino esperan su turno en la cola del aviso; como aquí
		# se salta la cola (`_free_at = 0`), pueden coincidir en pantalla: se mide solo el aviso pedido
		for ch in ub.get_children():
			var mine := false
			for l in ch.find_children("*", "Label", true, false):
				mine = mine or (l as Label).text == b[2]
			(ch as CanvasItem).visible = mine
		n_dialogs += 1
		await _measure(ub)
		await _shot_now(b[0])
	for ch in ub.get_children():
		ch.queue_free()
	ub._free_at = 0.0


func _end_largo(G) -> void:
	var H = G.duplicate()
	H.nm = 9
	H.relics = DB.relics.keys().slice(0, 14)
	H.ach = ["first_win", "act2", "act3", "kills_100", "nm5", "daily_win", "floors_50", "elite_10", "boss_3"]
	H.unl = ["w2_cards", "w2_relics"]
	H.stats = {"fights": 34, "kills": 412, "turns": 388}
	Meta.run = H
	Main.I.set_screen(EndScreen.create_victory(H, true), "end")


func _historial_lleno() -> void:
	var rows := []
	for i in 14:
		var h := {"char": DB.playable()[i % DB.playable().size()], "win": i % 3 == 0, "act": 1 + i % 3, "floor": 8 + i, "t": 1700000000 + i * 99999,
			"by": "", "nm": i % 4, "easy": i % 5 == 0, "daily": "2024-05-%02d" % (i + 1) if i % 6 == 0 else "", "seed": 1234567 + i,
			"fights": 9, "kills": 40, "turns": 88, "maxHp": 88, "mod": "", "relics": DB.relics.keys().slice(0, 6), "top": [], "deck": ["tajo", "tajo+", "guardia"]}
		h["by"] = DB.enemies.keys()[i % DB.enemies.size()]
		rows.append(h)
	Meta.data["hist"] = rows
	Nav.history()


func _logros_lleno() -> void:
	Meta.data["ach"] = {}
	var k := 0
	for a in Progress.achievements():
		Meta.data["ach"][a.id] = 1700000000
		k += 1
		if k >= 6:
			break
	Meta.data["s"]["runs_zafiro"] = 123
	Meta.data["s"]["win_lia"] = 45
	Meta.data["s"]["win_zafiro"] = 999
	Nav.achievements("ach")


func _view_60(G) -> void:
	var cards := []
	for i in 60:
		var c := Eng.make_card(G, G.deck[i % G.deck.size()].id)
		c.uid = 70 + i
		cards.append(c)
	Dlg.view_cards("Tu mazo completo (60 cartas: 10 de inicio, 30 de recompensa y 20 mejoradas)", cards, null)


func _pick_22(G) -> void:
	var cards := []
	for i in 22:
		var c := Eng.make_card(G, G.deck[i % G.deck.size()].id)
		c.uid = 300 + i
		cards.append(c)
	Dlg.pick_cards({"title": "Elige una carta para eliminar", "sub": "Quita una carta de tu mazo para hacerlo más fuerte.", "cards": cards, "n": 1, "cancel": "Cancelar", "confirmLabel": "Eliminar"})


func _mazo_texto() -> String:
	return "Victoria en La Aguja\n\nCombates ganados: 34 · Enemigos derrotados: 412 · Turnos: 388 · PV máx.: 92\nSemilla: [b]918273645[/b] [i](copiada al portapapeles)[/i]\n\n[b][color=#f0cf7a]Reliquias[/color][/b]\n" \
		+ " · ".join(DB.relics.keys().slice(0, 12)) + "\n\n[b][color=#f0cf7a]Cartas más jugadas[/color][/b]\n" + " · ".join(DB.cards.keys().slice(0, 20)) \
		+ "\n\n[b][color=#f0cf7a]Mazo (60 cartas)[/color][/b]\n" + ", ".join(DB.cards.keys().slice(0, 60))


func _tooltip(G) -> void:
	Dlg.view_cards("Carta", [G.deck[0]], null)
	await _settle(6)
	var cv := Dlg._find_cards(Main.I.overlay_host)
	if not cv.is_empty():
		Tip.show_at(cv[0])


func dlg(tag: String, build: Callable) -> void:
	if not _wanted(tag):
		return
	bug = tag
	build.call()
	await _settle(14)
	var ov: Node = null
	if Main.I.overlay_host.get_child_count() > 0:
		ov = Main.I.overlay_host.get_child(Main.I.overlay_host.get_child_count() - 1)
	if ov == null:
		_fail(null, "no se abrió el diálogo")
		return
	n_dialogs += 1
	await _measure(ov)
	if Tip.I != null and Tip.I.visible:
		_measure_now(Tip.I)
	await _shot_now(tag)
	Tip.hide_all()
	if Tip.I != null:
		Tip.I.visible = false
	for c in Main.I.overlay_host.get_children():
		# fuera del árbol al instante: el diálogo se lanzó desde una lambda con `await` que se queda a medias
		Main.I.overlay_host.remove_child(c)
		c.queue_free()
	await _settle(6)


# ============================== medición ==============================
## Archivo que construye el control: la pantalla, el diálogo, la carta, el enemigo, la barra superior…
func _owner_file(c: Node) -> String:
	var n := c
	while n != null:
		if n is Dlg.Overlay:
			return "dlg.gd"
		if n is Tip:
			return "tip.gd"
		if n is UnlockBanner:
			return "unlock_banner.gd"
		if n is CardView:
			return "card_view.gd"
		if n is EnemyView:
			return "enemy_view.gd"
		if Main.I != null and n == Main.I.top:
			return "main.gd"
		if Main.I != null and n == Main.I.screen:
			var s: Script = n.get_script()
			return s.resource_path.get_file() if s != null else "(prueba)"
		n = n.get_parent()
	return "main.gd"


func _fail(c: Control, what: String) -> void:
	if c != null:
		_failed_ctrl[c] = true
	if bug == "canario":
		if c != null and _canary.has(String(c.name)):
			_canary[String(c.name)] = true
		elif verbose:
			print("  (canario, otro) %s %s" % [_path(c), what])
		return
	var file := _owner_file(c) if c != null else "?"
	var where := _path(c) if c != null else ""
	# sin cifras en la firma: «682 partidas…» y «690 partidas…» son el mismo fallo en dos ventanas
	var k := "%d|%s|%s" % [roundi(scale * 100), bug, _DIGITS.sub(where + "|" + what, "#", true)]
	if seen.has(k):
		if not (win in seen[k]):
			seen[k].append(win)
		return
	seen[k] = [win]
	fails += 1
	by_file[file] = by_file.get(file, 0) + 1
	print("  ✗ [%s · %s] %s :: %s :: %s" % [pass_tag, bug, file, where, what])


func _collect(n: Node, inside_button: bool) -> void:
	if n is Control:
		var c := n as Control
		if not c.is_visible_in_tree() or c.is_queued_for_deletion() or c.modulate.a < 0.05:
			return
		if c is Button or c is Label or c is RichTextLabel:
			if not _is_fx(c):
				_items.append({"c": c, "inb": inside_button})
		var nb: bool = inside_button or c is Button
		for ch in c.get_children():
			_collect(ch, nb)
		return
	for ch in n.get_children():
		_collect(ch, inside_button)


## Cartas que vuelan hacia el objetivo o a la pila, y números flotantes: animaciones de 0,3 s, no layout.
func _is_fx(c: Control) -> bool:
	var n: Node = c
	while n != null:
		if n is CardView and (n as CardView).scale.x < 0.95:
			return true
		if n == Main.I.screen and n.get("fx_layer") != null and n.fx_layer.is_ancestor_of(c):
			return true
		n = n.get_parent()
	return false


## Rect en pantalla de `c` recortado por los ancestros que recortan. Con `scroll_only`, solo por los
## ScrollContainer (recortar texto con un panel `clip_contents` SÍ es un fallo: el texto se ve cortado).
func _visible_clip(c: Control, scroll_only: bool = false) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		if p is ScrollContainer or (not scroll_only and p is Control and (p as Control).clip_contents):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r


func _check(it: Dictionary) -> void:
	var c: Control = it.c
	if not is_instance_valid(c) or _failed_ctrl.has(c):
		return
	var clip := _visible_clip(c)
	if clip.size.x <= 0.5 or clip.size.y <= 0.5:
		return   # fuera de vista (recortado por un scroll o un panel): no se ve
	var txt := _text_of(c)
	if txt.strip_edges() == "":
		return
	var gr := _visible_clip(c, true)
	_check_screen(c, gr, txt)
	var art := c is Label and ((c as Label).text in BIG_ART or c.has_meta("logo"))
	if not art and not _failed_ctrl.has(c):
		_check_parent(c, gr, txt)
	if not art and not _failed_ctrl.has(c):
		if c is Button and not (c is CheckButton):
			_check_button(c as Button)
		elif c is Label:
			_check_label(c as Label)
		elif c is RichTextLabel:
			_check_rich(c as RichTextLabel)
	if not _failed_ctrl.has(c):
		oks += 1


func _text_of(c: Control) -> String:
	if c is RichTextLabel:
		return (c as RichTextLabel).get_parsed_text()
	return str(c.get("text"))


static func _path(c: Node) -> String:
	var parts := []
	var n := c
	while n != null and not (n is Main) and not (n is Dlg.Overlay):
		var s: String = n.get_class() if String(n.name).begins_with("@") else String(n.name)
		if n is Button or n is Label:
			if (n as Control).text != "":
				s += "«" + _short((n as Control).text, 26) + "»"
		elif n is RichTextLabel:
			s += "«" + _short((n as RichTextLabel).get_parsed_text(), 26) + "»"
		parts.push_front(s)
		n = n.get_parent()
		if parts.size() >= 3:
			break
	return "/".join(parts)


static func _short(t: String, n: int = 44) -> String:
	var s := t.strip_edges().replace("\n", "⏎")
	return s.left(n) + ("…" if s.length() > n else "")


## Tamaño que ocupa `text` con la fuente real, partido como lo partiría el control (ancho `width`).
static func _text_size(text: String, f: Font, fs: int, width: float, wrap: int, line_spacing: float = 0.0) -> Vector2:
	var p := TextParagraph.new()
	p.add_string(text, f, fs)
	var flags := TextServer.BREAK_MANDATORY
	match wrap:
		TextServer.AUTOWRAP_ARBITRARY:
			flags |= TextServer.BREAK_GRAPHEME_BOUND
		TextServer.AUTOWRAP_WORD:
			flags |= TextServer.BREAK_WORD_BOUND
		TextServer.AUTOWRAP_WORD_SMART:
			flags |= TextServer.BREAK_WORD_BOUND | TextServer.BREAK_ADAPTIVE
	p.break_flags = flags
	if wrap != TextServer.AUTOWRAP_OFF and width > 0.0:
		p.width = width
	var w := 0.0
	var h := 0.0
	var n := p.get_line_count()
	for i in n:
		w = maxf(w, p.get_line_width(i))
		h += p.get_line_size(i).y
	h += line_spacing * maxi(0, n - 1)
	return Vector2(w, h)


## Lo visible del texto se sale de la pantalla lógica 1280×720.
func _check_screen(c: Control, gr: Rect2, txt: String) -> void:
	var out := maxf(maxf(-gr.position.x, -gr.position.y), maxf(gr.end.x - VP.x, gr.end.y - VP.y))
	if out > TOL:
		_fail(c, "%s «%s» se sale de la pantalla %.0f px (está en %.0f,%.0f %.0f×%.0f)" % [c.get_class(), _short(txt), out, gr.position.x, gr.position.y, gr.size.x, gr.size.y])


## El control se sale del rect de su padre (columna, panel, botón…) o de su caja visible más cercana.
func _check_parent(c: Control, gr: Rect2, txt: String) -> void:
	if c is RichTextLabel and (c as RichTextLabel).autowrap_mode != TextServer.AUTOWRAP_OFF:
		gr.size.x = minf(gr.size.x, (c as RichTextLabel).get_content_width())
	# padre con tamaño (un Control vacío de 0×0 que solo sirve para colocar a mano no es una caja)
	var p := c.get_parent()
	while p is Control and not (p is Container) and ((p as Control).size.x < 1.0 or (p as Control).size.y < 1.0):
		p = p.get_parent()
	if p is Control and not (p is ScrollContainer) and p != Main.I.screen_host and p != Main.I.overlay_host and p != Main.I:
		var pr := _visible_clip(p, true)
		var ox := maxf(gr.end.x - pr.end.x, pr.position.x - gr.position.x)
		var oy := maxf(gr.end.y - pr.end.y, pr.position.y - gr.position.y)
		if ox > TOL or oy > TOL:
			_fail(c, "%s «%s» se sale %.0f×%.0f px de su padre %s %s" % [c.get_class(), _short(txt), maxf(ox, 0), maxf(oy, 0), p.get_class(), _size_s(pr.size)])
			return
	# caja visible: el botón, panel o carta que lo contiene (aunque haya contenedores en medio)
	var box := _box_of(c)
	if box != null and box != p:
		var br := _visible_clip(box, true)
		var ox2 := maxf(gr.end.x - br.end.x, br.position.x - gr.position.x)
		var oy2 := maxf(gr.end.y - br.end.y, br.position.y - gr.position.y)
		if ox2 > TOL or oy2 > TOL:
			_fail(c, "%s «%s» se sale %.0f×%.0f px de su caja %s %s" % [c.get_class(), _short(txt), maxf(ox2, 0), maxf(oy2, 0), box.get_class(), _size_s(br.size)])


static func _size_s(v: Vector2) -> String:
	return "(%.0f×%.0f)" % [v.x, v.y]


## Caja visible más cercana: botón, panel o carta (no cuentan los contenedores invisibles).
func _box_of(c: Control) -> Control:
	var n := c.get_parent()
	while n != null and n is Control:
		if n is ScrollContainer:
			return null   # dentro de un scroll manda el scroll
		if n is Button or n is PanelContainer or n is Panel or n is CardView:
			return n
		if n == Main.I.screen or n is Dlg.Overlay or n == Main.I.top:
			return null
		n = n.get_parent()
	return null


## Rect del glifo que un botón pinta (ancho real del texto, alto de sus líneas, según la alineación).
func _glyph_rect(b: Button, need: Vector2) -> Rect2:
	var gr := b.get_global_rect()
	var sb := b.get_theme_stylebox("normal")
	var pad := sb.get_minimum_size()
	var iw := UIK._icon_w(b)
	var x := gr.position.x + sb.get_margin(SIDE_LEFT) + iw
	var room := gr.size.x - pad.x - iw
	match b.alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x += (room - need.x) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = gr.end.x - sb.get_margin(SIDE_RIGHT) - need.x
	var y := gr.position.y + sb.get_margin(SIDE_TOP) + (gr.size.y - pad.y - need.y) / 2.0
	return Rect2(Vector2(x, y), need)


func _check_button(b: Button) -> void:
	if b.text == "":
		return
	var f := b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	var pad := b.get_theme_stylebox("normal").get_minimum_size()
	var room := Vector2(b.size.x - pad.x - UIK._icon_w(b), b.size.y - pad.y)
	var need := _text_size(b.text, f, fs, room.x, b.autowrap_mode)
	var cut := b.clip_text or b.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if need.x > room.x + TOL or need.y > room.y + TOL:
		_fail(b, "«%s» (fuente %d) necesita %.0f×%.0f px y el botón deja %.0f×%.0f%s" % [_short(b.text), fs, need.x, need.y, room.x, room.y, " → se recorta" if cut else " → se sale"])
		return
	if fs < UIK.FIT_MIN:
		_fail(b, "fuente demasiado pequeña (%d px): «%s»" % [fs, _short(b.text)])
		return
	_occlusion(b, _glyph_rect(b, need), "el texto «" + _short(b.text) + "»")


func _check_label(l: Label) -> void:
	if l.visible_characters == 0 or (l.visible_ratio >= 0.0 and l.visible_ratio < 1.0):
		return   # texto a medio escribir (animación)
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var ls := float(l.get_theme_constant("line_spacing"))
	var need := _text_size(l.text, f, fs, l.size.x, l.autowrap_mode, ls)
	var cut := l.clip_text or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	if need.x > l.size.x + TOL:
		_fail(l, "Label «%s» pide %.0f px de ancho y tiene %.0f (fuente %d)%s" % [_short(l.text), need.x, l.size.x, fs, " → se recorta con «…»" if cut else ""])
		return
	if need.y > l.size.y + TOL and (cut or l.max_lines_visible >= 0):
		_fail(l, "Label «%s» pide %.0f px de alto y tiene %.0f (fuente %d)" % [_short(l.text), need.y, l.size.y, fs])
		return
	if l.get_visible_line_count() < l.get_line_count():
		_fail(l, "Label «%s» enseña %d de %d líneas" % [_short(l.text), l.get_visible_line_count(), l.get_line_count()])


func _check_rich(r: RichTextLabel) -> void:
	if r.visible_characters == 0:
		return
	var txt := r.get_parsed_text().strip_edges()
	if r.scroll_active or _in_scroll(r):
		return   # la barra de scroll es para eso
	var ch := r.get_content_height()
	if r.size.y > 0.5 and ch > r.size.y + TOL:
		_fail(r, "RichTextLabel necesita %.0f px de alto y tiene %.0f «%s»" % [ch, r.size.y, _short(txt)])
		return
	if r.autowrap_mode == TextServer.AUTOWRAP_OFF and r.size.x > 0.5 and r.get_content_width() > r.size.x + TOL:
		_fail(r, "RichTextLabel necesita %.0f px de ancho y tiene %.0f «%s»" % [r.get_content_width(), r.size.x, _short(txt)])


## ¿El texto del botón invade un control hermano (mismo padre) con el que no debería compartir espacio?
func _occlusion(owner: Control, inside: Rect2, what: String) -> void:
	var vis := _visible_clip(owner)
	if not vis.intersects(inside) or owner.get_parent() == null:
		return
	for s in owner.get_parent().get_children():
		if not (s is Control) or s == owner:
			continue
		var sc := s as Control
		if not sc.is_visible_in_tree() or _tolerance(sc) > 0.0:
			continue
		if (sc is TextureRect or sc is ColorRect) and sc.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue   # fondo o adorno detrás de todo
		var ov := sc.get_global_rect().intersection(inside)
		if ov.size.x > TOL and ov.size.y > TOL:
			_fail(owner, "%s se mete %.0f×%.0f px en el hermano %s «%s»" % [what, ov.size.x, ov.size.y, sc.get_class(), _short(_text_of(sc) if (sc is Button or sc is Label or sc is RichTextLabel) else "", 20)])
			return
	if Main.I.top.visible and not (owner.is_ancestor_of(Main.I.top) or Main.I.top.is_ancestor_of(owner)):
		for s in Main.I.top.find_children("*", "Control", true, false):
			var sc2 := s as Control
			if not sc2.is_visible_in_tree() or not (sc2 is Button or sc2 is Label):
				continue
			var ov2 := sc2.get_global_rect().intersection(inside)
			if ov2.size.x > TOL and ov2.size.y > TOL:
				_fail(owner, "%s se mete bajo la barra superior (%s)" % [what, sc2.get_class()])
				return


func _in_scroll(c: Node) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


## Controles con un margen propio declarado (insignias y pines sobre el arte) no cuentan como hermano invadido.
func _tolerance(c: Control) -> float:
	var n: Node = c
	var depth := 0
	while n != null and depth < 3:
		if n.has_meta("layout_ok"):
			return float(n.get_meta("layout_ok"))
		n = n.get_parent()
		depth += 1
	return 0.0
