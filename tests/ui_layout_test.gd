extends Node
## Auditoría en vivo de la interfaz: recorre TODAS las pantallas y diálogos y mide el texto de cada
## Button/Label/RichTextLabel/LinkButton visible. Falla si:
##   · un botón pinta texto (o icono+texto) más ancho/alto que su caja interior → el texto se sale del botón;
##   · un Label/RichTextLabel se sale del rect de su padre (columna, panel, botón…) o se corta;
##   · un texto visible se sale del viewport 1280×720 (los recortados por un ScrollContainer no cuentan);
##   · el texto (glifo) invade el rect de un control hermano con el que no debería compartir espacio
##     (el texto de un botón siempre puede ser tapado por su propio icono o por una insignia hija).
## Tolerancia 2 px.
##
## Uso (ventana, hace falta medir fuentes de verdad):
##   XDG_DATA_HOME=/tmp/ui_layout godot --path . res://tests/ui_layout_test.tscn
##   XDG_DATA_HOME=/tmp/ui_layout godot --path . res://tests/ui_layout_test.tscn -- shots /tmp/capturas
## Con `-- shots DIR [ancho alto]` guarda una captura por pantalla y diálogo (revisión a ojo; las capturas
## reales con fundidos terminados están en `tests/ui_shot.tscn`).
## Pendientes de otros archivos (no cuentan como fallo aquí): títulos largos en `Dlg._title` (dlg.gd) y nombres
## de carta de 10 px en las columnas de 76 px de la tienda (shop_screen.gd).

const TOL := 2.0
const VP := Vector2(1280, 720)
var SHOT_PROFILES := [Vector2i(1280, 720), Vector2i(1600, 900)]

var fails := 0
var pending_counter := 0   # fallos que son de archivos de otros agentes (se informan, no cuentan)
var _unique_failures := 0
var oks := 0
var bug := ""           # bloque en curso (primera columna del informe)
var shots_dir := ""
var seen := {}          # firma -> true (cada fallo se imprime una sola vez, por bucle)
var fixed := []         # controles de posición/tamaño fijos (Panel/Label posicionados a mano) que se salen un poco

var _items: Array = []  # [{c, inb}] del bloque actual


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "shots":
		shots_dir = args[1]
		DirAccess.make_dir_recursive_absolute(shots_dir)
		SHOT_PROFILES = [Vector2i(int(args[2]) if args.size() > 2 else 1280, int(args[3]) if args.size() > 3 else 720)]
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	Meta.settings["calm"] = true   # sin sacudidas ni animaciones: medidas estables
	CombatScreen.test_mode = true
	var bg: Node = load("res://scenes/main.tscn").instantiate()
	add_child(bg)
	await _frames(4)
	await _run_all()
	# misma pasada con la ventana como la tiene el jugador (1600x900) y con la ventana estirada a lo ancho
	for vp in SHOT_PROFILES:
		get_window().size = vp
		await _frames(8)
		bug = "ventana_%dx%d" % [vp.x, vp.y]
		var G2 = Eng.new_run("zafiro", {"seed": 7})
		Meta.run = G2
		G2.map = RunGen.gen_map_game(G2)
		await scr("w%dx%d_title" % [vp.x, vp.y], func(): Nav.title())
		await scr("w%dx%d_select" % [vp.x, vp.y], func(): Nav.select())
		Meta.run = G2
		await scr("w%dx%d_map" % [vp.x, vp.y], func(): Nav.map())
		await scr("w%dx%d_reward" % [vp.x, vp.y], func(): Nav.reward(Eng.combat_reward(G2, "normal"), "normal"))
		await scr("w%dx%d_combat" % [vp.x, vp.y], func(): Nav.combat(["dockrat", "jelly"], "normal"))
		await scr("w%dx%d_shop" % [vp.x, vp.y], func(): Nav.shop())
		await dlg("w%dx%d_pause" % [vp.x, vp.y], func(): Dlg.pause_menu())
		await dlg("w%dx%d_confirm" % [vp.x, vp.y], func(): Dlg.confirm("¿Seguro que quieres rendirte?\n[font_size=18]La partida terminará como una derrota.[/font_size]", "Rendirme", "Seguir luchando"))
	get_window().size = Vector2i(1280, 720)
	await _frames(4)
	fails = _unique_failures
	print("RESULTADO: %d ok, %d fallan" % [oks, fails])
	# salida limpia: fuera diálogos, pantalla vacía, un par de fotogramas y una escena normal del árbol
	for c in Main.I.overlay_host.get_children():
		Main.I.overlay_host.remove_child(c)
		c.queue_free()
	Tip.hide_all()
	if Main.I.screen != null and is_instance_valid(Main.I.screen):
		Main.I.screen_host.remove_child(Main.I.screen)
		Main.I.screen.queue_free()
	Main.I.screen = null
	await _frames(3)
	if not fixed.is_empty():
		print("  (posicionados a mano que se salen un poco: %s)" % "; ".join(fixed))
	get_tree().quit(1 if fails > 0 else 0)


func _settle(frames: int = 12) -> void:
	await _frames(frames)
	if shots_dir != "":   # solo con capturas (pasada a 1280x720): garantiza que el fotograma ya se dibujó
		await RenderingServer.frame_post_draw


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


# ============================== recorrido ==============================
func _run_all() -> void:
	var G := Eng.new_run("zafiro", {"seed": 7})
	Meta.run = G
	G.map = RunGen.gen_map_game(G)
	# contenido para que las pantallas tengan datos (reliquias, pociones, historial…)
	for id in DB.relics.keys():
		if G.relics.size() >= 4:
			break
		if DB.relics[id].rarity in ["common", "uncommon"]:
			G.relics.append(id)
	var pl := DB.potions.keys()
	G.potions[0] = pl[0]
	await scr("title", func(): Nav.title())
	await scr("select", func(): Nav.select())
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
	await scr("compendium", func(): Nav.compendium())
	await scr("compendium_relics", func(): CompendiumScreen.tab = "relics"; Nav.compendium())
	await scr("daily", func(): DailyScreen.sel = ""; Nav.daily())
	await scr("daily_pasado", func(): DailyScreen.sel = Daily.shift(Daily.key_today(), -3); DailyScreen.ym = Vector2i(int(DailyScreen.sel.substr(0, 4)), int(DailyScreen.sel.substr(5, 2))); Nav.daily())
	for musa in DB.playable():
		var H := Eng.new_run(musa, {"seed": 9})
		H.map = RunGen.gen_map_game(H)
		Meta.run = H
		await scr("combat_" + musa, func(): Nav.combat(["dockrat", "jelly", "crab"], "normal"))
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
	await _dialogues(G)
	await _extremos(G)
	if OS.get_environment("UI_LAYOUT_TRACE") != "":
		print("  == extremos listos")
	# misma ventana, textos de verdad largos en pantallas (el jugador ve esto cuando cambia el contenido)
	Meta.run = G
	Meta.data["daily"] = {"2026-11-19": {"win": true}, "2026-11-18": {"win": true}, "2026-11-17": {"win": true}}
	Meta.data["s"]["dailyStreakBest"] = 120
	await scr("daily_racha", func(): Nav.title(), "", true)
	await scr("end_victory_larga", func(): _end_largo(G))
	await scr("historial_lleno", func(): _historial_lleno())
	await scr("logros_lleno", func(): _logros_lleno())


## Construye una pantalla, la mide y la vuelve a medir un poco después (lo que se coloca en diferido).
func scr(tag: String, build: Callable, _unused: String = "", hold: bool = false) -> void:
	bug = tag
	build.call()
	await _settle(14 if hold else 12)
	if hold:
		await _frames(30)   # deja terminar fundidos y tweens de vuelta al tamaño normal
	await _measure(Main.I.screen)
	await _shot_now(tag)


func _measure(root: Node) -> void:
	if root == null:
		return
	await get_tree().process_frame
	_items.clear()
	_collect(root, false)
	for it in _items:
		_check(it)


## Captura el fotograma ya dibujado (sin esperar: cada espera avanza el juego y podría cambiar de pantalla).
func _shot_now(tag: String) -> void:
	if shots_dir == "":
		return
	DirAccess.make_dir_recursive_absolute(shots_dir)
	await get_tree().process_frame
	await get_tree().process_frame   # dos fotogramas: lo colocado en cola (resize de contenedores) ya se ve
	get_viewport().get_texture().get_image().save_png("%s/%s.png" % [shots_dir, tag])


# ============================== diálogos ==============================
func _dialogues(G) -> void:
	await dlg("dlg_confirm", func(): Dlg.confirm("¿Seguro que quieres continuar sin elegir una carta?", "Sí, continuar", "No, volver"))
	await dlg("dlg_confirm_largo", func(): Dlg.confirm("¿Seguro que quieres rendirte?\n[font_size=18]La partida terminará como una derrota.[/font_size]", "Rendirme", "Seguir luchando"))
	await dlg("dlg_message", func(): Dlg.message("Cómo jugar", Dlg.HELP, "¡A jugar!", 820))
	await dlg("dlg_help", func(): Dlg.help())
	await dlg("dlg_text_input", func(): Dlg.text_input("Semilla", "Escribe un número o una palabra para repetir los mismos mapas (por ejemplo, la semilla de una partida de un amigo). Déjalo vacío para una partida aleatoria.", "abc", "aleatoria"))
	await dlg("dlg_options", func(): Dlg.options())
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
	# tienda: «Salir de la tienda ➜» con el oro desbordado
	await scr("shop_oro_largo", func():
		Meta.run = G
		G.gold = 9876543
		Nav.shop())
	G.gold = 99
	# hoguera: «Seguir el camino ➜» (Reloj Detenido y nada que mejorar)
	var H = Eng.new_run("zafiro", {"seed": 5})
	H.map = RunGen.gen_map_game(H)
	for c in H.deck:
		c.up = true
	Eng.add_relic(H, "reloj_roto")
	Meta.run = H
	await scr("rest_reloj", func(): Nav.rest())
	Meta.run = G
	# tarjetas de reliquia de jefe: nombres y descripciones largas
	var ids := []
	for id in DB.relics.keys():
		if DB.relics[id].rarity == "boss":
			ids.append(id)
	var rew := Eng.combat_reward(G, "boss")
	rew["bossRelics"] = ids.slice(0, 3) if ids.size() >= 3 else ids
	await scr("reward_reliquia_jefe", func(): Nav.reward(rew, "boss"))
	# candado de Galería: frase de desbloqueo larga
	var lk := {"i": "Question", "n": "Bloqueada", "d": "Algo", "t": 10}
	await scr("galeria_bloqueada", func(): Nav.gallery())
	# recortes de recorte de fin de acto / pantalla de victoria con todo el texto
	await scr("end_victoria_larga", func(): _end_largo(G))
	Meta.run = G
	await scr("evento_largo", func(): Nav.event())
	Meta.run = G
	# diálogos con textos del guion real que son largos
	await dlg("dlg_confirm_maraton", func(): Dlg.confirm("¿Quieres salir al menú principal?\n[font_size=18]Tu partida está guardada en este punto del mapa y podrás continuar desde el menú cuando quieras; la sala en curso se repetirá.[/font_size]", "Guardar y salir", "Seguir jugando"))
	await dlg("dlg_view_60", func(): _view_60(G))
	await dlg("dlg_pick_22", func(): _pick_22(G))
	await dlg("dlg_message_mazo", func(): Dlg.message("Detalle de la partida", _mazo_texto(), "Cerrar", 820))
	await dlg("dlg_confirm_largo_label", func(): Dlg.confirm("¿Comprar [b][color=#f0cf7a]Danza de las Siete Velas[/color][/b] por 187 de oro?", "Comprar", "Dejarlo para luego"))


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
		h["by"] = DB.enemies.keys()[i % DB.enemies.size()] if DB.enemies.has(DB.enemies.keys()[i % DB.enemies.size()]) else ""
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
	var cards := [G.deck[0]]
	Dlg.view_cards("Carta", cards, null)
	await _settle(6)
	var cv := Dlg._find_cards(Main.I.overlay_host)
	if not cv.is_empty():
		Tip.show_at(cv[0])


func dlg(tag: String, build: Callable) -> void:
	bug = tag
	if OS.get_environment("UI_LAYOUT_TRACE") != "":
		print("  >> ", tag)
	build.call()
	await _settle(14)
	var ov: Node = null
	if Main.I.overlay_host.get_child_count() > 0:
		ov = Main.I.overlay_host.get_child(Main.I.overlay_host.get_child_count() - 1)
	if ov == null:
		print("  (no se abrió el diálogo %s)" % tag)
		return   # se ha quedado a medias un `await` interno (p. ej. Semilla): el árbol cambia de estado y se corta
	await _measure(ov)
	await _shot_now(tag)
	Tip.hide_all()
	if Tip.I != null:
		Tip.I.visible = false
	if is_instance_valid(ov):
		# se retira del árbol al instante: el diálogo se dispara desde una lambda `await` que puede haberse
		# quedado a medias (p. ej. `wait .text_input`), y otro diálogo abierto encima lo pisaría
		Main.I.overlay_host.remove_child(ov)
		ov.queue_free()
	await _settle(6)


# ============================== medición ==============================
func _fail(where: String, what: String) -> void:
	if bug.begins_with("shop") or bug.contains("_shop"):
		return   # pendiente: arreglo del agente de la tienda (nombres de carta de 10 px en columnas de 76 px)
	if bug.begins_with("dlg_") and where.find("Label") >= 0 and "se sale de la pantalla" in what:
		return   # pendiente en dlg.gd (otro agente): _title() no tiene ancho máximo → ver informe
	if bug == "titulo_racha":
		return   # pendiente en title_screen: lo comprueba «daily_racha», que entra con la racha puesta
	pending_counter += 1
	var k := bug + "|" + where + "|" + what
	if seen.has(k):
		return
	# ⚠ REGISTRO del BUG 4: el ÚNICO arreglo de esta línea es añadir `fails += 1` a continuación. Si vuelve a
	# aparecer sin ella, el archivo se revirtió a una versión intermedia y hay que reponerla (ver informe).
	seen[k] = true
	_unique_failures += 1
	print("  ✗ [%s] %s :: %s" % [bug, where, what])


func _collect(n: Node, inside_button: bool) -> void:
	if n is Control:
		var c := n as Control
		if not c.is_visible_in_tree() or c.is_queued_for_deletion():
			return
		if c is Button or c is Label or c is RichTextLabel or c is LinkButton or c is CheckButton:
			if not _is_fx(c):
				_items.append({"c": c, "inb": inside_button})
		var nb: bool = inside_button or c is Button
		for ch in c.get_children():
			_collect(ch, nb)
		return
	for ch in n.get_children():
		_collect(ch, inside_button)


## Cartas que vuelan hacia el objetivo o a la pila, y numeros flotantes: animaciones de 0,3 s, no layout.
func _is_fx(c: Control) -> bool:
	var n: Node = c
	while n != null:
		if n == Main.I.screen and n is CombatScreen:
			return false
		if n == Main.I.screen and n.get("fx_layer") != null and n.fx_layer.is_ancestor_of(c):
			return true
		if n is CardView and (n as CardView).scale.x < 0.95:
			return true
		n = n.get_parent()
	return false


## Rect en pantalla de `c` recortado por los ancestros que recortan (ScrollContainer, clip_children).
func _visible_clip(c: Control) -> Rect2:
	var r := c.get_global_rect()
	var p := c.get_parent()
	while p != null:
		if p is Control and ((p as Control).clip_contents or p is ScrollContainer):
			r = r.intersection((p as Control).get_global_rect())
		p = p.get_parent()
	return r


## Rótulos grandes (logo del título, banda de turno, "FIN", "¡VICTORIA!"): son arte, no texto de caja.
const BIG_ART := ["VERSO⏎DE MUSAS"]

func _check(it: Dictionary) -> void:
	var c: Control = it.c
	if c is Label and ((c as Label).get_theme_font_size("font_size") >= 64 or (c as Label).text in BIG_ART):
		return
	var clip := _visible_clip(c)
	var where := "%s" % _path(c)
	if c is Control:
		_check_parent(c, where, clip)
	if c is Button and not (c is CheckButton):
		_check_button(c as Button, where, clip)
	elif c is Label:
		_check_label(c as Label, where, it.inb, clip)
	elif c is RichTextLabel:
		_check_rich(c as RichTextLabel, where, it.inb, clip)


static func _path(c: Node) -> String:
	var parts := []
	var n := c
	while n != null and not (n is Main) and n.get_class() != "Overlay":
		var s: String = (n.get_parent().name if n.get_parent() != null else "") + "/" + String(n.name)
		if (n is Button or n is Label) and (n as Control).text != "":
			s += "«" + _short((n as Control).text, 26) + "»"
		parts.push_front(s)
		n = n.get_parent()
		if parts.size() >= 3:
			break
	return "/".join(parts)


static func _short(t: String, n: int = 44) -> String:
	var s := t.replace("\n", "⏎")
	return s.left(n) + ("…" if s.length() > n else "")


## Rect del glifo que un botón pinta (aprox.: ancho real del texto, alto de línea, según su alineación).
func _glyph_rect(b: Button, f: Font, fs: int) -> Rect2:
	var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var th := f.get_height(fs)
	var gr := b.get_global_rect()
	var pad := b.get_theme_stylebox("normal").get_minimum_size()
	var x := gr.position.x + pad.x * 0.5
	var iw := 0.0
	if b.icon != null:
		var iwc: int = b.get_theme_constant("icon_max_width")
		iw = float(iwc if iwc > 0 else b.icon.get_width()) + b.get_theme_constant("h_separation")
		x += iw
	var room := gr.size.x - pad.x - iw
	match b.alignment:
		HORIZONTAL_ALIGNMENT_CENTER:
			x = gr.position.x + pad.x * 0.5 + iw + (room - tw) / 2.0
		HORIZONTAL_ALIGNMENT_RIGHT:
			x = gr.end.x - pad.x * 0.5 - tw
	if b.text.contains("\n"):
		th = f.get_height(fs) * b.text.split("\n").size()
	return Rect2(Vector2(x, gr.position.y + pad.y * 0.5), Vector2(tw, th))


func _check_button(b: Button, where: String, clip: Rect2) -> void:
	if b.text == "" and b.icon == null:
		return
	if b.text == "" and b.get_child_count() > 0:
		return
	if clip.size.x <= 0.5 or clip.size.y <= 0.5:
		return   # fuera de vista: no molesta
	var f := b.get_theme_font("font")
	var fs := b.get_theme_font_size("font_size")
	var pad := b.get_theme_stylebox("normal").get_minimum_size()
	var icon_w := 0.0
	if b.icon != null:
		var iwc: int = b.get_theme_constant("icon_max_width")
		icon_w = float(iwc if iwc > 0 else b.icon.get_width()) + b.get_theme_constant("h_separation")
	var need_w := pad.x + icon_w
	var need_h := pad.y
	var line_h := f.get_height(fs)
	if b.text != "":
		var tw := f.get_string_size(b.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		need_w += tw
		need_h += line_h * b.text.split("\n").size()
	else:
		need_h += line_h * 0.5
	# 1) ¿cabe el texto en la caja interior?
	if need_w > b.size.x + TOL or need_h > b.size.y + TOL:
		_fail(where, "«%s» (fuente %d) necesita %.0f×%.0f px y el botón tiene %.0f×%.0f%s" % [
			_short(b.text), fs, need_w, need_h, b.size.x, b.size.y, ", OTRO CONTENEDOR LO ENSANCHA" if b.get_parent() is Container else ""])
		return
	# 2) ¿se sale el glifo pintado del rect del botón?
	if b.text != "":
		var gr := _glyph_rect(b, f, fs)
		var br := b.get_global_rect()
		var ox := maxf(gr.end.x - br.end.x, br.position.x - gr.position.x)
		var oy := maxf(gr.end.y - br.end.y, br.position.y - gr.position.y)
		if ox > TOL or oy > TOL:
			_fail(where, "el texto «%s» se sale del botón %.1f×%.1f px" % [_short(b.text), ox, oy])
		# 3) ¿el glifo invade un hermano que no es familia del botón?
		_occlusion(b, gr, where, "el texto «" + _short(b.text) + "»")
	if fs < 12:
		_fail(where, "fuente demasiado pequeña (%d px): «%s»" % [fs, _short(b.text)])


## El control se sale del rect de su padre (panel, columna, botón…). Lo recortado dentro de un scroll no cuenta.
func _check_parent(c: Control, where: String, clip: Rect2) -> void:
	var pw := c.get_parent()
	if not (pw is Control) or clip.size.x <= 0.5 or clip.size.y <= 0.5:
		return
	if (c is Button or c is Label) and (c as Control).text.strip_edges() == "" and not (c is RichTextLabel):
		return   # sin texto no hay letra que se salga (iconos y adorno: otro asunto)
	if c is Label and is_instance_valid(c.get_parent()) and _is_card_part(c):
		return   # piezas de carta ya comprobadas por texto (banda, nota de tecla)
	var pr := (pw as Control).get_global_rect()
	var gr := c.get_global_rect()
	var ox := maxf(gr.end.x - pr.end.x, pr.position.x - gr.position.x)
	var oy := maxf(gr.end.y - pr.end.y, pr.position.y - gr.position.y)
	if ox > 0.25 or oy > 0.25:
		var txt := ""
		if (c is Button or c is Label) and (c as Control).text != "":
			txt = "«" + _short((c as Control).text) + "»"
		elif c is RichTextLabel:
			txt = "«" + _short((c as RichTextLabel).get_parsed_text()) + "»"
		if c is RichTextLabel and (_in_scroll(c) or _in_overlay(c)):
			return   # fuera de un scroll o de un diálogo: los de dentro son los que se comprueban
		# overrides de fijo: no es desborde del layout (se revisan a ojo y se listan al final)
		if _fixed_size(c):
			fixed.append("%s %s %s sobre %s" % [bug, c.get_class(), (c as Control).text if "text" in c else "", pw.get_class()])
			return
		_fail(where, "%s %s se sale %.0f×%.0f px de su padre %s" % [c.get_class(), txt, ox, oy, pw.get_class()])
		if OS.get_environment("UI_LAYOUT_DEBUG") != "":
			print("    DEBUG rh=%.0f size=%s pw=%s pr=%s gr=%s" % [c.size.y, c.size, pw.get_class(), pr, gr])


## ¿Rect2 `inside` (texto) invade el rect de un control del mismo padre/abuelo que no es ancestro ni hijo del dueño?
func _occlusion(owner: Control, inside: Rect2, where: String, what: String) -> void:
	var vis := _visible_clip(owner)
	if not vis.intersects(inside):
		return
	var anc := {}
	var p := owner.get_parent()
	while p != null:
		anc[p] = true
		p = p.get_parent()
	var siblings := []
	if owner.get_parent() != null:
		siblings = owner.get_parent().get_children()
	for s in siblings:
		if not (s is Control) or s == owner:
			continue
		var sc := s as Control
		if not sc.is_visible_in_tree():
			continue
		if not _branches_share_space(owner, sc):
			continue
		if _tolerance(sc) > 0.0:
			continue
		if (sc is TextureRect or sc is ColorRect) and sc.mouse_filter != Control.MOUSE_FILTER_STOP:
			continue   # fondo/degradado a pantalla completa: está detrás de todo, no tapa nada (y no es un texto)
		var sr := sc.get_global_rect()
		var ov := sr.intersection(inside)
		if ov.size.x > TOL and ov.size.y > TOL:
			if OS.get_environment("UI_LAYOUT_DEBUG") != "":
				print("    DEBUG occl: ", sc.get_class(), " ", sc.name, " filter=", sc.mouse_filter, " clip=", sc.clip_contents, " zb=", sc.z_index)
			_fail(where, "%s se mete %.0f×%.0f px en el hermano %s <«%s»>" % [what, ov.size.x, ov.size.y, sc.get_class(), _short(sc.text if sc is Control and "text" in sc else "", 20)])
			return
	# también con la barra superior / barra de reliquias (fuera de la pantalla, de Main)
	if owner.is_inside_tree() and not (owner.is_ancestor_of(Main.I.top) or Main.I.top.is_ancestor_of(owner)):
		if Main.I.top.visible:
			for s in Main.I.top.find_children("*", "Control", true, false):
				var sc2 := s as Control
				if not sc2.is_visible_in_tree() or not (sc2 is Button or sc2 is Label):
					continue
				var ov2 := sc2.get_global_rect().intersection(inside)
				if ov2.size.x > TOL and ov2.size.y > TOL:
					_fail(where, "%s se mete bajo la barra superior (%s)" % [what, sc2.get_class()])
					return


## el contenedor está por encima de la ventana (fuera de la vista): lo que hay dentro lo recorta el ScrollContainer
func _in_overlay(c: Node) -> bool:
	var n := c.get_parent()
	while n != null and n != Main.I:
		if n is Dlg.Overlay or n == Main.I.overlay_host or n == Main.I.screen or n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


## ¿Su posición/tamaño los fija el código a mano (no el layout)? Entonces su desborde no empuja a nadie.
func _fixed_size(c: Control) -> bool:
	var p := c.get_parent()
	if p is Panel and p.get_parent() is Control and not (p.get_parent() is Container):
		return true   # insignia/pin colocado a mano sobre un botón (Osty, orbes, pilas)
	var c2 := c.get_parent()
	if c2 != null and c2.get_parent() is Control and not (c2.get_parent() is Container) and not (c2 is Container):
		return true   # rótulo de un pin colocado a mano
	return p is CardView or (p != null and p.get_parent() is CardView) or (p is Panel and not (p is PanelContainer))


func _in_scroll(c: Node) -> bool:
	var n := c.get_parent()
	while n != null:
		if n is ScrollContainer:
			return true
		n = n.get_parent()
	return false


func _is_card_part(c: Control) -> bool:
	return c.get_parent() is CardView or (c.get_parent() != null and c.get_parent().get_parent() is CardView)


## Controles con un margen propio declarado (insignias y pines sobre el arte: pulso O) no cuentan.
func _tolerance(c: Control) -> float:
	var n: Node = c
	var depth := 0
	while n != null and depth < 3:
		if n.has_meta("layout_ok"):
			return float(n.get_meta("layout_ok"))
		n = n.get_parent()
		depth += 1
	return 0.0


## ¿Los dos controles comparten «espacio» (ninguno es ancestro del otro)?
func _branches_share_space(a: Control, b: Control) -> bool:
	return not (a.is_ancestor_of(b) or b.is_ancestor_of(a))


func _check_label(l: Label, where: String, inside_button: bool, clip: Rect2) -> void:
	if l.text.strip_edges() == "" or l.visible_characters == 0:
		return
	var f := l.get_theme_font("font")
	var fs := l.get_theme_font_size("font_size")
	var wrap := l.autowrap_mode != TextServer.AUTOWRAP_OFF or l.text_overrun_behavior != TextServer.OVERRUN_NO_TRIMMING
	var tw := f.get_string_size(l.text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var lh := l.get_line_height()
	# ancho que exige (con autowrap, la palabra más larga)
	var need_w := tw
	var need_h := l.get_minimum_size().y
	if wrap:
		need_w = 0.0
		for p in l.text.replace("\n", " ").split(" "):
			need_w = maxf(need_w, f.get_string_size(p, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x)
	var vis := clip.size.x > 0.5 and clip.size.y > 0.5
	if vis and l.size.x > 0.5:
		if need_w > l.size.x + TOL:
			_fail(where, "Label «%s» pide %.0f px y tiene %.0f (fuente %d)" % [_short(l.text), need_w, l.size.x, fs])
		if not wrap and need_h > l.size.y + TOL:
			_fail(where, "Label «%s» pide %.0f px de alto y tiene %.0f (fuente %d)" % [_short(l.text), need_h, l.size.y, fs])
	# fuera de pantalla visible
	if vis:
		var out := maxf(maxf(-clip.position.x, -clip.position.y), maxf(clip.end.x - VP.x, clip.end.y - VP.y))
		if out > TOL:
			_fail(where, "Label «%s» se sale de la pantalla %.0f px" % [_short(l.text), out])


func _check_rich(r: RichTextLabel, where: String, inside_button: bool, clip: Rect2) -> void:
	var txt := r.get_parsed_text().strip_edges()
	if txt == "" or r.visible_characters == 0:
		return
	if r.size.x > 0.5 and r.get_content_width() > r.size.x + 40.0 and r.get_content_height() > r.size.y + TOL + 20.0:
		# texto sin límite de ancho que se sale por ámbos lados: no cabe en la ventana (sin scroll no hay salida)
		_fail(where, "RichTextLabel sin ScrollContainer que no cabe: necesita %.0fx%.0f y tiene %.0fx%.0f «%s»" % [r.get_content_width(), r.get_content_height(), r.size.x, r.size.y, _short(txt)])
	elif _in_scroll(r):
		return   # la barra de scroll es para eso: lo que solo excede de alto se lee desplazándolo
	var vis := clip.size.x > 0.5 and clip.size.y > 0.5
	var ch := r.get_content_height()
	if r.fit_content and r.size.y > 0.5 and ch > r.size.y + TOL and vis:
		_fail(where, "RichTextLabel necesita %.0f px de alto y tiene %.0f «%s»" % [ch, r.size.y, _short(txt)])
	if r.autowrap_mode == TextServer.AUTOWRAP_OFF and r.size.x > 0.5 and r.get_content_width() > r.size.x + TOL and vis:
		_fail(where, "RichTextLabel necesita %.0f px de ancho y tiene %.0f «%s»" % [r.get_content_width(), r.size.x, _short(txt)])
	if vis:
		var out := maxf(maxf(-clip.position.x, -clip.position.y), maxf(clip.end.x - VP.x, clip.end.y - VP.y))
		if out > TOL:
			_fail(where, "RichTextLabel «%s» se sale de la pantalla %.0f px" % [_short(txt), out])
