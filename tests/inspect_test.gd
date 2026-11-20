extends Node
## Fase 2.3 · Inspección: ficha de reliquia (clic y A con R3), filtros de pilas, mazo desde cualquier sala
## (también sobre un diálogo) sin perder el foco del mando, y hoguera «PV 6 ➜ 9».
## Uso: godot --headless --path . res://tests/inspect_test.tscn

var ok := 0
var fail := 0


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		print("ok   ", label)
	else:
		fail += 1
		print("FALLA ", label)


func btn(i: int, pressed: bool = true) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = i
	e.pressed = pressed
	e.device = 0
	Input.parse_input_event(e)
	await wait(0.12)


func tap(i: int) -> void:
	await btn(i, true)
	await btn(i, false)


func key(k: int) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = p
		Input.parse_input_event(e)
		await wait(0.08)


func focus() -> Control:
	var f := get_viewport().gui_get_focus_owner()
	return f if (f != null and is_instance_valid(f)) else null


func fname(f: Control) -> String:
	if f == null:
		return "<sin foco>"
	var s := "%s(%s)" % [f.name, f.get_class()]
	if f is Button:
		s += " '%s'" % (f as Button).text
	return s


func overlays() -> int:
	return Main.I.overlay_host.get_child_count()


func top_overlay() -> Node:
	return Main.I.overlay_host.get_child(overlays() - 1) if overlays() > 0 else null


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func find_named(root: Node, nm: String) -> Node:
	for n in _walk(root):
		if n.name == nm:
			return n
	return null


func card_views(root: Node) -> Array:
	return _walk(root).filter(func(n): return n is CardView and not n.is_queued_for_deletion())


func _ready() -> void:
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var G := Eng.new_run("zafiro", {"seed": 42})
	G.map = RunGen.gen_map_game(G)
	Meta.run = G
	await test_relic(G)
	await test_filters(G)
	await test_deck_rooms(G)
	await test_rest(G)
	await test_combat_piles(G)
	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)


# ---------- 1. reliquia: clic y A (inspección con R3) abren la ficha ----------
func test_relic(G) -> void:
	Nav.map()
	await wait(0.8)
	var icons: Array = Main.I._tb_relics.get_children()
	check(not icons.is_empty(), "reliquia: la barra superior muestra la reliquia inicial")
	if icons.is_empty():
		return
	var icon: Control = icons[0]
	var rid: String = icon.get_meta("relic_id", "")
	var f0 := focus()
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = icon.size / 2.0
	icon.gui_input.emit(ev)
	await wait(0.3)
	var o := top_overlay()
	check(o != null and o.get_meta("relic_info", "") == rid, "reliquia: el clic abre su ficha (%s)" % rid)
	if o != null:
		var org = find_named(o, "Origin")
		var desc = find_named(o, "Desc")
		print("  origen: ", org.get_parsed_text() if org != null else "-")
		check(org != null and org.get_parsed_text().contains("Reliquia inicial de"), "reliquia: la ficha dice su origen")
		check(desc != null and desc.get_parsed_text().strip_edges() != "", "reliquia: la ficha dice su efecto")
		var fb := focus()
		check(fb is Button and o.is_ancestor_of(fb), "reliquia: el foco está en el botón de la ficha")
		icon.gui_input.emit(ev)   # doble clic: no apila otra ficha
		await wait(0.2)
		check(overlays() == 1, "reliquia: un segundo clic no abre otra ficha")
		await tap(JOY_BUTTON_B)
		await wait(0.3)
		check(overlays() == 0, "reliquia: B cierra la ficha")
		check(focus() == f0, "reliquia: el foco vuelve al mapa (%s)" % fname(focus()))
	# mando: R3 → inspeccionar, llevar el marco a la reliquia, A → ficha
	await tap(JOY_BUTTON_RIGHT_STICK)
	await wait(0.1)
	check(Main.I._insp_on, "reliquia: R3 entra en el modo inspeccionar")
	var idx: int = Main.I._insp_list.find(icon)
	check(idx >= 0, "reliquia: la reliquia está entre lo inspeccionable")
	if idx >= 0:
		Main.I._insp_show(idx)
		await wait(0.1)
		await tap(JOY_BUTTON_A)
		await wait(0.3)
		var o2 := top_overlay()
		check(not Main.I._insp_on and o2 != null and o2.get_meta("relic_info", "") == rid, "reliquia: A al inspeccionarla abre la ficha")
		await tap(JOY_BUTTON_B)
		await wait(0.3)
		check(overlays() == 0, "reliquia: B cierra la ficha abierta con A")
	else:
		Main.I._insp_end()
	# A sobre algo que no es reliquia sigue saliendo de inspeccionar sin abrir nada
	await tap(JOY_BUTTON_RIGHT_STICK)
	await wait(0.1)
	var other := -1
	for i in Main.I._insp_list.size():
		if not Main.I._insp_list[i].has_meta("relic_id"):
			other = i
			break
	if other >= 0:
		Main.I._insp_show(other)
		await tap(JOY_BUTTON_A)
		await wait(0.2)
		check(not Main.I._insp_on and overlays() == 0, "reliquia: A sobre otra cosa solo sale de inspeccionar")
	else:
		Main.I._insp_end()
	check(Dlg.relic_origin("brasa_carmesi").contains("Zafiro"), "reliquia: el origen de la inicial nombra a su musa")
	for id in DB.relics.keys():
		if Dlg.relic_origin(id) == "":
			check(false, "reliquia: %s sin origen" % id)


# ---------- 2. pilas con filtros ----------
func test_filters(G) -> void:
	var cards: Array = G.deck.duplicate()
	var extra := ["golpe", "defensa"]
	for id in DB.cards.keys():
		if cards.size() >= 24:
			break
		var t: String = DB.cards[id].type
		if t in ["attack", "skill", "power", "curse"]:
			cards.append({"id": id, "uid": 9000 + cards.size(), "up": cards.size() % 4 == 0 and Eng.can_upgrade({"id": id, "up": false})})
	Dlg.view_cards("Pila de prueba", cards)
	await wait(0.4)
	var o := top_overlay()
	var bar = find_named(o, "FilterBar") if o != null else null
	var holder = find_named(o, "CardsHolder") if o != null else null
	check(bar != null and holder != null, "filtros: la vista de cartas tiene barra de filtros")
	if bar == null:
		if o != null:
			o.close(null)
		return
	check(focus() != null and focus().name == "Chip_all", "filtros: el foco empieza en «Todas» (%s)" % fname(focus()))
	check(card_views(holder).size() == cards.size(), "filtros: sin filtro se ven todas (%d)" % cards.size())
	var n_att := cards.filter(func(c): return Eng.card_def(c).type == "attack").size()
	var chip_att: Button = find_named(bar, "Chip_t_attack")
	check(chip_att != null, "filtros: hay chip de Ataque")
	if chip_att != null:
		chip_att.grab_focus()
		await wait(0.05)
		await tap(JOY_BUTTON_A)
		await wait(0.2)
		var shown := card_views(holder)
		check(shown.size() == n_att and shown.all(func(v): return Eng.card_def(v.inst).type == "attack"), "filtros: Ataque deja solo ataques (%d de %d)" % [shown.size(), n_att])
		check(focus() == chip_att, "filtros: el foco del mando sigue en el chip tras filtrar")
		check(chip_att.get_meta("on", false) and not (find_named(bar, "Chip_all") as Button).get_meta("on", true), "filtros: el chip activo se marca")
		# coste 1 combinado con ataque
		var chip_c1: Button = find_named(bar, "Chip_c_1")
		if chip_c1 != null:
			chip_c1.emit_signal("pressed")
			await wait(0.2)
			var want := cards.filter(func(c): return Eng.card_def(c).type == "attack" and not Eng.is_x(Eng.card_def(c).cost) and Eng.card_def(c).cost == 1).size()
			check(card_views(holder).size() == want, "filtros: Ataque + coste 1 (%d)" % want)
			chip_c1.emit_signal("pressed")   # segundo toque: quita el filtro de coste
			await wait(0.2)
			check(card_views(holder).size() == n_att, "filtros: repetir el chip quita su filtro")
		var chip_up: Button = find_named(bar, "Chip_up")
		check(chip_up != null, "filtros: hay chip de Mejoradas")
		if chip_up != null:
			(find_named(bar, "Chip_all") as Button).emit_signal("pressed")
			await wait(0.1)
			chip_up.emit_signal("pressed")
			await wait(0.2)
			var ups := cards.filter(func(c): return c.up).size()
			var sv := card_views(holder)
			check(sv.size() == ups and sv.all(func(v): return v.inst.up), "filtros: Mejoradas deja solo las mejoradas (%d)" % ups)
		(find_named(bar, "Chip_all") as Button).emit_signal("pressed")
		await wait(0.2)
		check(card_views(holder).size() == cards.size(), "filtros: «Todas» quita todos los filtros")
	# todo cabe en 1280×720: barra dentro de pantalla y botón Cerrar visible
	var vr := get_viewport().get_visible_rect()
	var close_b: Button = null
	for n in _walk(o):
		if n is Button and (n as Button).text == "Cerrar":
			close_b = n
	check(close_b != null and vr.encloses(close_b.get_global_rect()), "filtros: el botón Cerrar cabe en pantalla")
	check(vr.encloses((bar as Control).get_global_rect()), "filtros: la barra cabe en pantalla (%s)" % (bar as Control).get_global_rect())
	o.close(null)
	await wait(0.3)
	# con pocas cartas no hay barra (p. ej. «¡Carta mejorada!»)
	Dlg.view_cards("Una", [cards[0]])
	await wait(0.3)
	check(find_named(top_overlay(), "FilterBar") == null, "filtros: con 1 carta no sale la barra")
	top_overlay().close(null)
	await wait(0.3)


# ---------- 3. mazo desde cualquier sala, con el foco intacto ----------
func test_deck_rooms(G) -> void:
	var rooms := {
		"map": func(): Nav.map(),
		"reward": func():
			var rew := Eng.combat_reward(G, "elite")
			Nav.reward(rew, "elite"),
		"rest": func(): Nav.rest(),
		"event": func(): Nav.event(),
		"shop": func(): Nav.shop(),
	}
	for room in rooms.keys():
		G.hp = mini(G.maxHp, G.hp)
		rooms[room].call()
		await wait(0.8)
		check(Main.I.current == room, "%s: la sala está abierta" % room)
		var f0 := focus()
		await tap(JOY_BUTTON_BACK)
		await wait(0.3)
		var o := top_overlay()
		check(o != null and o.get_meta("deck_view", false), "%s: Back abre el mazo" % room)
		var fi := focus()
		check(o != null and fi != null and o.is_ancestor_of(fi), "%s: el foco pasa al mazo (%s)" % [room, fname(fi)])
		await tap(JOY_BUTTON_DPAD_DOWN)
		await wait(0.1)
		check(o != null and focus() != null and o.is_ancestor_of(focus()), "%s: el D-Pad no se escapa del mazo" % room)
		await tap(JOY_BUTTON_BACK)   # Back otra vez lo cierra
		await wait(0.4)
		check(overlays() == 0, "%s: Back cierra el mazo" % room)
		check(focus() == f0, "%s: el foco vuelve a donde estaba (%s)" % [room, fname(focus())])
		await key(KEY_M)
		await wait(0.3)
		check(top_overlay() != null and top_overlay().get_meta("deck_view", false), "%s: M abre el mazo" % room)
		await tap(JOY_BUTTON_B)
		await wait(0.4)
		check(overlays() == 0 and focus() == f0, "%s: B cierra el mazo y devuelve el foco" % room)

	# sobre un diálogo: elegir carta en la hoguera → Back → mazo encima → B → de vuelta a la carta elegida
	Nav.rest()
	await wait(0.8)
	Dlg.pick_cards({"title": "Elige una carta para mejorar", "cards": G.deck.filter(func(c): return Eng.can_upgrade(c)), "n": 1, "cancel": "Cancelar", "upgradePreview": true})
	await wait(0.4)
	var pick := top_overlay()
	await tap(JOY_BUTTON_DPAD_RIGHT)
	await wait(0.1)
	var fp := focus()
	check(pick != null and fp != null and pick.is_ancestor_of(fp), "sobre diálogo: foco en el diálogo de elegir carta (%s)" % fname(fp))
	var modes0 := {}   # foco de cada control del diálogo antes de abrir el mazo encima
	for n in _walk(pick):
		if n is Control:
			modes0[n] = (n as Control).focus_mode
	await tap(JOY_BUTTON_BACK)
	await wait(0.4)
	var dv := top_overlay()
	check(overlays() == 2 and dv.get_meta("deck_view", false), "sobre diálogo: Back abre el mazo encima")
	var leaked := card_views(pick).filter(func(v): return v.focus_mode != Control.FOCUS_NONE).size()
	check(leaked == 0, "sobre diálogo: las cartas del diálogo de debajo no reciben foco (%d)" % leaked)
	for d in [JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_UP]:
		await tap(d)
	check(focus() != null and dv.is_ancestor_of(focus()), "sobre diálogo: el D-Pad se queda en el mazo")
	await tap(JOY_BUTTON_B)
	await wait(0.4)
	check(overlays() == 1 and top_overlay() == pick, "sobre diálogo: B cierra solo el mazo")
	check(focus() == fp, "sobre diálogo: el foco vuelve a la carta (%s)" % fname(focus()))
	var same := 0
	var alive := 0   # la vista previa de la mejora se rehace al mover el foco: se cuentan solo los vivos
	for n in modes0.keys():
		if is_instance_valid(n):
			alive += 1
		if is_instance_valid(n) and (n as Control).focus_mode == modes0[n]:
			same += 1
		elif is_instance_valid(n):
			print("  cambia: %s %s padre=%s antes=%d ahora=%d" % [n.name, n.get_class(), n.get_parent().name, modes0[n], (n as Control).focus_mode])
	check(alive > 0 and same == alive, "sobre diálogo: el diálogo de debajo recupera sus focos (%d de %d vivos)" % [same, alive])
	await tap(JOY_BUTTON_B)
	await wait(0.4)
	check(overlays() == 0, "sobre diálogo: B cierra después el diálogo")


# ---------- 4. hoguera «PV 6 ➜ 9» ----------
func test_rest(G) -> void:
	G.maxHp = 80
	G.hp = 30
	var heal := ceili(G.maxHp * Eng.nmods(G).rest)
	Nav.rest()
	await wait(0.6)
	var note = find_named(Main.I.screen, "Note")
	var want := "PV %d ➜ %d" % [30, mini(80, 30 + heal)]
	check(note != null and note.get_meta("text", "") == want, "hoguera: muestra «%s» (%s)" % [want, note.get_meta("text", "") if note != null else "-"])
	var b1: Button = note.get_parent().get_parent() if note != null else null
	if b1 != null:
		b1.emit_signal("pressed")
		await wait(0.2)
		check(G.hp == mini(80, 30 + heal), "hoguera: descansar deja la vida anunciada (%d)" % G.hp)
	await wait(0.8)
	G.hp = 79
	Nav.rest()
	await wait(0.6)
	note = find_named(Main.I.screen, "Note")
	check(note != null and note.get_meta("text", "") == "PV 79 ➜ 80", "hoguera: no promete más del máximo (%s)" % (note.get_meta("text", "") if note != null else "-"))
	G.hp = 80
	Nav.rest()
	await wait(0.6)
	note = find_named(Main.I.screen, "Note")
	check(note != null and note.get_meta("text", "").contains("máximo"), "hoguera: con la vida llena lo dice (%s)" % (note.get_meta("text", "") if note != null else "-"))
	if note != null:
		var nr := (note as Control).get_global_rect()
		var br := (note.get_parent().get_parent() as Control).get_global_rect()
		check(br.encloses(nr), "hoguera: la nota cabe en su botón (%s en %s)" % [nr, br])
	# la flecha no es un glifo (las fuentes no traen «➜»): ningún Label de la nota la lleva
	G.hp = 30
	Nav.rest()
	await wait(0.6)
	note = find_named(Main.I.screen, "Note")
	var glyph := false
	for n in _walk(note):
		if n is Label and (n as Label).text.contains("➜"):
			glyph = true
	check(note != null and not glyph, "hoguera: la flecha se dibuja (no depende de la fuente)")


# ---------- 2b. pilas del combate (robo / descarte) con el coste efectivo de C ----------
func test_combat_piles(G) -> void:
	G.hp = G.maxHp
	Nav.combat(["dockrat", "jelly", "crab"], "normal")
	await wait(2.0)
	check(Main.I.current == "combat", "combate: abierto")
	var C: Dictionary = Main.I.screen.C
	var pile: Array = C.draw.duplicate()
	pile.append_array(C.hand)
	Dlg.view_cards("Mazo de robo (en orden aleatorio)", pile, C)
	await wait(0.4)
	var o := top_overlay()
	var bar = find_named(o, "FilterBar") if o != null else null
	check(pile.size() < 6 or bar != null, "combate: la pila de robo tiene filtros (%d cartas)" % pile.size())
	if bar != null:
		var holder = find_named(o, "CardsHolder")
		var c1: Button = find_named(bar, "Chip_c_1")
		if c1 != null:
			c1.emit_signal("pressed")
			await wait(0.2)
			var want := pile.filter(func(c): return str(Eng.eff_cost(C, Eng.card_def(c))) == "1").size()
			check(card_views(holder).size() == want, "combate: filtro de coste 1 con el coste efectivo (%d)" % want)
	await tap(JOY_BUTTON_B)
	await wait(0.3)
	check(overlays() == 0, "combate: B cierra la pila")
