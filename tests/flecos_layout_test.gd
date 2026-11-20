extends Node
## Regresión de los «posicionados a mano que se salen un poco» que listaba ui_layout_test:
##   · favor: «Rechazar los favores» dentro de la pantalla y sin pisar las cartas;
##   · enemigo de nombre largo (Contramaestre Espectral): el nombre cabe en el ancho del EnemyView;
##   · Osty: el rótulo «Poder N» / «Caído…» cabe dentro de su caja;
##   · insignias de pila (mazo/descarte/agotadas) con 1, 2 y 3 cifras: el número cabe en la insignia;
##   · valor de orbe de Selene (1 y 2 cifras) dentro de su hueco.
## Mide con la fuente real (sirve en headless). Uso: godot --headless --path . res://tests/flecos_layout_test.tscn

const TOL := 0.5
var ok := 0
var fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		print("ok   ", label)
	else:
		fail += 1
		print("FALLA ", label)


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func inside(a: Rect2, b: Rect2) -> bool:
	return a.position.x >= b.position.x - TOL and a.position.y >= b.position.y - TOL \
			and a.end.x <= b.end.x + TOL and a.end.y <= b.end.y + TOL


func text_w(l: Control, txt: String) -> float:
	var f := l.get_theme_font("font")
	return f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, l.get_theme_font_size("font_size")).x


## Una Label (sin autowrap) cabe: su texto en su ancho y su rect dentro del padre.
func label_fits(l: Label, parent: Control, what: String) -> void:
	var tw := text_w(l, l.text)
	var lr := l.get_global_rect()
	if OS.get_environment("FLECOS_DEBUG") != "":
		print("    min=", l.get_minimum_size(), " size=", l.size, " fs=", l.get_theme_font_size("font_size"), " outline=", l.get_theme_constant("outline_size"), " style=", l.get_theme_stylebox("normal").get_minimum_size())
	var pr := parent.get_global_rect()
	if l.autowrap_mode == TextServer.AUTOWRAP_OFF:
		check(tw <= l.size.x + TOL, "%s: «%s» mide %.0f px y la etiqueta %.0f (fuente %d)" % [what, l.text, tw, l.size.x, l.get_theme_font_size("font_size")])
	else:
		var need := l.get_line_count() * l.get_line_height()
		check(need <= l.size.y + TOL and l.get_visible_line_count() >= l.get_line_count(),
				"%s: «%s» necesita %d líneas (%.0f px) y tiene %.0f px (fuente %d, sin recortar)" % [what, l.text, l.get_line_count(), need, l.size.y, l.get_theme_font_size("font_size")])
		for word in l.text.split(" "):
			check(text_w(l, word) <= l.size.x + TOL, "%s: la palabra «%s» cabe en %.0f px" % [what, word, l.size.x])
	check(inside(lr, pr), "%s: «%s» %s dentro de su padre %s" % [what, l.text, lr, pr])


func _ready() -> void:
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	Meta.settings["calm"] = true
	CombatScreen.test_mode = true
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await frames(6)
	var G := Eng.new_run("zafiro", {"seed": 7})
	G.map = RunGen.gen_map_game(G)
	Meta.run = G

	# ---------- favor: «Rechazar los favores» ----------
	for res in [Vector2i(1280, 720), Vector2i(1600, 900)]:
		get_window().size = res
		G.erase("entity")
		Nav.favor()
		await frames(12)
		var fs := Main.I.screen
		var skip: Button = null
		var cards: Array = []
		for b in fs.find_children("*", "Button", true, false):
			if (b as Button).text == tr("Rechazar los favores"):
				skip = b
			elif (b as Button).text == "" and b.get_parent() is HBoxContainer:
				cards.append(b)
		check(skip != null, "favor: existe «Rechazar los favores»")
		if skip != null:
			var sr := skip.get_global_rect()
			check(inside(sr, fs.get_global_rect()), "favor %s: «Rechazar» %s dentro de la pantalla %s" % [res, sr, fs.get_global_rect()])
			var clash := false
			for c in cards:
				if (c as Control).get_global_rect().intersects(sr):
					clash = true
			check(not clash, "favor %s: «Rechazar» no pisa las cartas de favor" % res)
			check(UIK.button_width(skip) <= skip.size.x + TOL, "favor %s: el texto de «Rechazar» cabe en su botón" % res)
	get_window().size = Vector2i(1280, 720)
	await frames(4)

	# ---------- nombre largo de enemigo ----------
	G.char = "zafiro"
	var cs: CombatScreen
	# el caso de ui_layout_test (3 enemigos: vistas más estrechas) y uno con 2
	for ids in [["spectralbosun", "jelly", "crab"], ["spectralbosun", "jelly"]]:
		Nav.combat(ids, "elite")
		await frames(20)
		cs = Main.I.screen as CombatScreen
		for v in cs.enemy_views.values():
			var ev := v as EnemyView
			label_fits(ev.name_lbl, ev, "enemigo %s (de %d)" % [ev.e.id, ids.size()])

	# ---------- insignias de pila con 1, 2 y 3 cifras ----------
	for n in [7, 12, 99, 120]:
		for b in [cs.draw_btn, cs.discard_btn, cs.exhaust_btn]:
			cs._set_count(b, n)
		await frames(3)
		for b in [cs.draw_btn, cs.discard_btn, cs.exhaust_btn]:
			var l: Label = b.get_meta("count")
			label_fits(l, l.get_parent(), "pila %s con %d" % [b.name, n])

	# ---------- Osty (Claudia) ----------
	G.char = "claudia"
	Nav.combat(["dockrat", "jelly"], "normal")
	await frames(20)
	cs = Main.I.screen as CombatScreen
	if cs.C.get("osty") != null:
		for spec in [[5, 4], [5, 12], [5, 123], [0, 3]]:
			cs.C.osty.hp = spec[0]
			cs.C.osty.pow = spec[1]
			cs._update_osty()
			await frames(3)
			label_fits(cs.osty_pow, cs.osty_box, "Osty")
	else:
		check(false, "Osty: Claudia empieza el combate con Osty")

	# ---------- orbes (Selene) ----------
	G.char = "selene"
	Nav.combat(["dockrat", "jelly"], "normal")
	await frames(20)
	cs = Main.I.screen as CombatScreen
	for val in [3, 12]:
		cs.C.orbs = [{"t": "abismo", "v": val}]
		cs._update_orbs()
		await frames(3)
		var p: Panel = cs.orb_bar.get_child(0)
		label_fits(p.get_meta("val"), p, "orbe con %d" % val)

	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	Main.I.set_screen(Control.new(), "blank")
	await frames(3)
	get_tree().quit(1 if fail > 0 else 0)
