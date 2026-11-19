class_name EndScreen
extends Control
## Derrota y resumen de victoria.

var victory := false
var G
var new_nm := false


static func create_victory(g, p_new_nm: bool) -> EndScreen:
	var e := EndScreen.new()
	e.victory = true
	e.G = g
	e.new_nm = p_new_nm
	return e


func _ready() -> void:
	if G == null:
		G = Meta.run
	var bg := TextureRect.new()
	bg.texture = UIK.tex("res://assets/ui/%s_select.webp" % G.char)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	UIK.full_rect(bg)
	add_child(bg)
	if not victory:
		bg.modulate = Color(0.55, 0.45, 0.5)
	add_child(UIK.shade(0.55, 0.85))
	var col := UIK.center_col(self, 18)
	var st: Dictionary = G.stats
	var name: String = DB.characters[G.char].name
	var title: Label
	var sum: String
	if victory:
		Sfx.music("victory")
		Sfx.play("win")
		title = UIK.label("¡VICTORIA!", 74, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
		var rel := ""
		for r in G.relics:
			rel += (Icons.bb("relic", r, 28) if Icons.has("relic", r) else DB.relics[r].i) + " "
		var nm_txt := "\n¡Has superado la Pesadilla 10! Nada más puede detenerte." if G.get("nm", 0) >= 10 else "\n[b][color=#caa5ff]Pesadilla %d desbloqueada[/color][/b]: enemigos más duros te esperan." % mini(10, G.get("nm", 0) + 1)
		sum = "%s ha conquistado la torre y derrotado a %s.\nCombates ganados: %d · Enemigos derrotados: %d · Turnos: %d\nReliquias: %s · Cartas en el mazo: %d%s%s%s" % [
			name, _boss_name(), st.fights, st.kills, st.turns, rel, G.deck.size(), "\n[i](Modo fácil)[/i]" if G.easy else "", ("\nPesadilla %d" % G.nm) if G.get("nm", 0) else "", nm_txt]
	else:
		Meta.add("deaths")
		Meta.clear_save()
		Sfx.music("menu")
		title = UIK.label("Derrota", 74, UIK.RED, "title", HORIZONTAL_ALIGNMENT_CENTER)
		var by: String = G.get("deathBy", "")
		if G.get("surrender", false):
			by = ""
		sum = "%s cayó en %s%s (piso %d).\nCombates ganados: %d · Enemigos derrotados: %d · Turnos: %d" % [name, DB.acts[G.act - 1].name, (" ante " + by) if by != "" else "", G.floor, st.fights, st.kills, st.turns]
	sum += "\n[font_size=18][color=#a79fc0]Semilla: %d%s[/color][/font_size]" % [G.seed, ("  ·  Reto diario %s (%s)" % [G.daily, Daily.mod_name(G.get("dailyMod", ""))]) if G.get("daily", "") != "" else ""]
	UIK.outlined(title, 12)
	col.add_child(title)
	var r := UIK.rich("[center]%s[/center]" % sum, 24)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(860, 0)
	col.add_child(r)
	var earned := _earned()
	if earned != null:
		col.add_child(earned)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var bk := "" if victory else "big"   # con Galería son cuatro botones: tamaño normal para que quepan
	var a := UIK.button("Jugar de nuevo" if victory else "Intentarlo de nuevo", bk + " green")
	a.pressed.connect(func(): Nav.select())
	row.add_child(a)
	if victory:
		var c := UIK.button("Galería", bk)
		c.pressed.connect(func(): Nav.gallery())
		row.add_child(c)
	var hb := UIK.button("Historial", bk)
	hb.pressed.connect(func(): Meta.run = null; Nav.history())
	row.add_child(hb)
	var b := UIK.button("Menú principal", bk)
	b.pressed.connect(func(): Meta.run = null; Nav.title())
	row.add_child(b)
	# Fase 3: revancha con la misma semilla, resumen para compartir y logros
	var row2 := HBoxContainer.new()
	row2.add_theme_constant_override("separation", 12)
	row2.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row2)
	var rv := UIK.button("Revancha", "small")
	UIK.tip(rv, "Repite la partida con la misma musa, semilla y Pesadilla (el reto diario repite su día).")
	rv.pressed.connect(func(): Nav.rematch(G))
	row2.add_child(rv)
	var cp := UIK.button("Copiar resumen", "small")
	UIK.tip(cp, "Copia la musa, la semilla y el resultado para compartirlos.")
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(Progress.share_text(G, victory))
		Main.I.toast("Resumen copiado: ¡reta a alguien con tu semilla!"))
	row2.add_child(cp)
	var lg := UIK.button("Logros  %d/%d" % [Progress.ach_count(Meta.data), Progress.achievements().size()], "small")
	lg.pressed.connect(func(): Meta.run = null; Nav.achievements())
	row2.add_child(lg)
	a.grab_focus.call_deferred()
	UIK.fade_in(self, 0.5)


## Logros y contenido conseguidos en esta partida (Meta los apunta en G.ach / G.unl) y Maestría al ganar.
func _earned() -> Control:
	var ach: Array = G.get("ach", [])
	var unl: Array = G.get("unl", [])
	var mastery := ""
	if victory and not G.easy:
		var r := Progress.mastery_rank(Meta.data, G.char)
		mastery = "Maestría de %s: [b][color=%s]%s[/color][/b] (%d puntos, +%d)" % [DB.characters[G.char].name, Progress.rank_color(r).to_html(false), Progress.rank_name(r),
			Progress.mastery_points(Meta.data, G.char), Progress.mastery_gain(int(G.get("nm", 0)), false)]
	if ach.is_empty() and unl.is_empty() and mastery == "":
		return null
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	if not ach.is_empty() or not unl.is_empty():
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 8)
		for id in ach.slice(0, 9):
			var a := Progress.find_ach(id)
			if a.is_empty():
				continue
			var md := Medal.make(a, 52, true)
			md.mouse_filter = Control.MOUSE_FILTER_PASS
			UIK.tip(md, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [a.n, a.d])
			row.add_child(md)
		for gid in unl.slice(0, 4):
			for g in Progress.groups():
				if g.id == gid:
					var ic := Progress.group_icon(g)
					var w: Control = Medal.disc("muse:" + str(ic[1]), 52, true, UIK.GREEN) if ic[0] == "muse" else Icons.frame(ic[0], ic[1], 52)
					w.mouse_filter = Control.MOUSE_FILTER_PASS
					UIK.tip(w, "[b][color=#8bf0a4]Nuevo contenido[/color][/b]\n%s" % UnlockBanner._cap(Progress.group_text(g)))
					row.add_child(w)
		v.add_child(row)
		var parts := []
		if not ach.is_empty():
			parts.append("%d logro%s nuevo%s" % [ach.size(), "" if ach.size() == 1 else "s", "" if ach.size() == 1 else "s"])
		if not unl.is_empty():
			parts.append("%d desbloqueo%s de contenido" % [unl.size(), "" if unl.size() == 1 else "s"])
		v.add_child(UIK.rich("[center][color=#f0cf7a]%s[/color] en esta partida[/center]" % " y ".join(parts), 17))
	if mastery != "":
		v.add_child(UIK.rich("[center]%s[/center]" % mastery, 17))
	for c in v.get_children():
		if c is RichTextLabel:
			c.custom_minimum_size = Vector2(860, 0)
	return v


func _boss_name() -> String:
	var bid := RunGen.boss_id(G)
	return DB.enemies[bid].name if DB.enemies.has(bid) else "la Reina de la Colmena"
