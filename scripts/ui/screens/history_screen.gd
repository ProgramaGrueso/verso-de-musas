class_name HistoryScreen
extends Control
## Historial: estadísticas por musa, cartas más jugadas, retos diarios y las últimas partidas (con su detalle).

var _back: Button


func _ready() -> void:
	Sfx.music("menu", 1, TitleScreen.last_char if TitleScreen.last_char != "" else "zafiro")
	var bg := ColorRect.new()
	bg.color = Color("#0a0814")
	UIK.full_rect(bg)
	add_child(bg)
	var hist: Array = Meta.history()
	# cabecera
	var head := HBoxContainer.new()
	head.position = Vector2(40, 20)
	head.size = Vector2(1200, 70)
	add_child(head)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hv.add_child(UIK.label("Historial", 34, UIK.GOLD, "title"))
	var s: Dictionary = Meta.data.s
	var wins: int = s.get("wins", 0)
	var runs: int = s.get("runs", 0)
	hv.add_child(UIK.label("%d partidas empezadas · %d victorias · %d derrotas · %d enemigos derrotados" % [runs, wins, s.get("deaths", 0), s.get("kills", 0)], 17, UIK.DIM))
	head.add_child(hv)
	_back = UIK.button("← Volver", "small")
	_back.pressed.connect(func(): Nav.title())
	head.add_child(_back)
	# columna izquierda: musas, cartas favoritas y retos diarios
	var left_sc := ScrollContainer.new()
	left_sc.position = Vector2(30, 100)
	left_sc.size = Vector2(600, 610)
	left_sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(left_sc)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 10)
	left.custom_minimum_size = Vector2(580, 0)
	left_sc.add_child(left)
	left.add_child(_section("Por musa"))
	left.add_child(_muse_table())
	left.add_child(_section("Cartas más jugadas"))
	left.add_child(_top_cards())
	left.add_child(_section("Reto diario"))
	left.add_child(_daily_box())
	# columna derecha: últimas partidas
	var right := VBoxContainer.new()
	right.position = Vector2(650, 100)
	right.size = Vector2(600, 610)
	right.add_theme_constant_override("separation", 8)
	add_child(right)
	right.add_child(_section("Últimas partidas"))
	var sc := ScrollContainer.new()
	sc.custom_minimum_size = Vector2(600, 565)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	right.add_child(sc)
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	list.custom_minimum_size = Vector2(580, 0)
	sc.add_child(list)
	if hist.is_empty():
		var e := UIK.label("Todavía no has terminado ninguna partida.\nCuando ganes o caigas, aparecerá aquí.", 18, UIK.DIM)
		list.add_child(e)
	for h in hist:
		list.add_child(_run_row(h))
	_back.grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func on_escape() -> void:
	Nav.title()


func _section(t: String) -> Label:
	var l := UIK.label(t, 22, UIK.GOLD, "bold")
	UIK.outlined(l, 4)
	return l


func _muse_table() -> Control:
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 18)
	grid.add_theme_constant_override("v_separation", 6)
	for t in ["Musa", "Partidas", "Victorias", "%", "Pesadilla", "Mejor piso"]:
		grid.add_child(UIK.label(t, 15, UIK.DIM, "bold"))
	var s: Dictionary = Meta.data.s
	for id in DB.playable():
		var m: Dictionary = DB.characters[id]
		var played: int = s.get("runs_" + id, 0)
		# las partidas anteriores a este historial no tienen recuento por musa: al menos cuentan las victorias
		var won: int = s.get("win_" + id, 0)
		played = maxi(played, won)
		var row_name := HBoxContainer.new()
		row_name.add_theme_constant_override("separation", 8)
		var ic := TextureRect.new()
		ic.texture = UIK.tex("res://assets/ui/%s_icon.png" % id)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		ic.custom_minimum_size = Vector2(30, 30)
		row_name.add_child(ic)
		row_name.add_child(UIK.label(m.name, 17, Color(m.glow).lightened(0.35), "bold"))
		grid.add_child(row_name)
		grid.add_child(UIK.label(str(played), 17))
		grid.add_child(UIK.label(str(won), 17, UIK.GREEN if won > 0 else UIK.TEXT))
		grid.add_child(UIK.label(("%d%%" % roundi(100.0 * won / played)) if played > 0 else "–", 17))
		var nm := Meta.nm_unlocked(id)
		grid.add_child(UIK.label(str(nm) if nm > 0 else "–", 17, Color("#caa5ff")))
		grid.add_child(UIK.label(str(s.get("bestFloor_" + id, 0)) if s.get("bestFloor_" + id, 0) > 0 else "–", 17))
	return grid


func _top_cards() -> Control:
	var cp: Dictionary = Meta.data.get("cardsPlayed", {})
	var ids: Array = cp.keys().filter(func(id): return DB.cards.has(id) and DB.cards[id].rarity in ["common", "uncommon", "rare"])
	ids.sort_custom(func(a, b): return cp[a] > cp[b])
	if ids.is_empty():
		return UIK.label("Juega algunas partidas para ver tus cartas favoritas (sin contar las iniciales).", 16, UIK.DIM)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 30)
	grid.add_theme_constant_override("v_separation", 4)
	for id in ids.slice(0, 10):
		var d: Dictionary = DB.cards[id]
		var col: Color = Color(DB.characters[d.cls].glow).lightened(0.35) if DB.characters.has(d.cls) else UIK.TEXT
		var r := UIK.rich("[color=#%s]%s[/color] [color=#a79fc0]×%d[/color]" % [col.to_html(false), d.name, cp[id]], 16)
		r.custom_minimum_size = Vector2(270, 0)
		grid.add_child(r)
	return grid


func _daily_box() -> Control:
	var key := Daily.key_today()
	var inf := Daily.info(key)
	var res := Meta.daily_result(key)
	var t: String = "Hoy (%s): [b]%s[/b] con el modificador [b][color=#caa5ff]%s[/color][/b]." % [key, DB.characters[inf.char].name, Daily.mod_name(inf.mod)]
	if res.is_empty():
		t += "\nAún no lo has intentado."
	else:
		t += "\nIntentos: %d · %s" % [res.get("tries", 0), "[color=#8bf0a4]¡Superado![/color]" if res.get("win", false) else "Mejor piso: %d" % res.get("floor", 0)]
	var won_days := 0
	var d = Meta.data.get("daily", {})
	if d is Dictionary:
		for k in d.keys():
			if d[k].get("win", false):
				won_days += 1
	t += "\nRetos superados en los últimos 30 días: %d" % won_days
	var r := UIK.rich(t, 16)
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.custom_minimum_size = Vector2(570, 0)
	return r


func _run_row(h: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(580, 64)
	b.focus_mode = Control.FOCUS_ALL
	var win: bool = h.get("win", false)
	var sb := UIK.stylebox(Color("#1e1830"), Color("#3f8a52") if win else Color("#6b3040"), 2, 12, 4)
	var sbh := UIK.stylebox(Color("#2c2346"), UIK.GOLD, 2, 12, 8)
	for st in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 10
	row.offset_right = -10
	row.add_theme_constant_override("separation", 12)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := TextureRect.new()
	ic.texture = UIK.tex("res://assets/ui/%s_icon.png" % h.get("char", "zafiro"))
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	ic.custom_minimum_size = Vector2(44, 44)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(ic)
	var r := UIK.rich(_row_text(h), 16)
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(r)
	b.add_child(row)
	b.pressed.connect(func(): _show_detail(h))
	return b


func _row_text(h: Dictionary) -> String:
	var mname: String = DB.characters[h.char].name if DB.characters.has(h.get("char", "")) else "?"
	var act: int = clampi(int(h.get("act", 1)), 1, 3)
	var res: String
	if h.get("win", false):
		res = "[color=#8bf0a4][b]Victoria[/b][/color]"
	elif h.get("surrender", false):
		res = "[color=#ff7b85][b]Rendición[/b][/color] en %s" % DB.acts[act - 1].name
	else:
		res = "[color=#ff7b85][b]Derrota[/b][/color] en %s" % DB.acts[act - 1].name
		if str(h.get("by", "")) != "":
			res += " ante %s" % h.by
	var tags := []
	if int(h.get("nm", 0)) > 0:
		tags.append("Pesadilla %d" % h.nm)
	if h.get("easy", false):
		tags.append("fácil")
	if str(h.get("daily", "")) != "":
		tags.append("reto %s" % h.daily)
	var line2: String = "%s · piso %d · %s%s" % [mname, int(h.get("floor", 0)), _date(int(h.get("t", 0))), (" · " + ", ".join(tags)) if not tags.is_empty() else ""]
	return "%s\n[font_size=14][color=#a79fc0]%s[/color][/font_size]" % [res, line2]


static func _date(t: int) -> String:
	if t <= 0:
		return ""
	var bias: int = int(Time.get_time_zone_from_system().get("bias", 0)) * 60
	var d := Time.get_datetime_dict_from_unix_time(t + bias)
	return "%02d/%02d/%04d %02d:%02d" % [d.day, d.month, d.year, d.hour, d.minute]


func _show_detail(h: Dictionary) -> void:
	var t := _row_text(h).replace("[font_size=14]", "").replace("[/font_size]", "") + "\n\n"
	t += "Combates ganados: %d · Enemigos derrotados: %d · Turnos: %d · PV máx.: %d\n" % [int(h.get("fights", 0)), int(h.get("kills", 0)), int(h.get("turns", 0)), int(h.get("maxHp", 0))]
	if str(h.get("mod", "")) != "":
		t += "Modificador del reto: [color=#caa5ff]%s[/color] — %s\n" % [Daily.mod_name(h.mod), Daily.mod_desc(h.mod)]
	t += "Semilla: [b]%d[/b] [i](copiada al portapapeles)[/i]\n\n" % int(h.get("seed", 0))
	DisplayServer.clipboard_set(str(int(h.get("seed", 0))))
	var rel := []
	for id in h.get("relics", []):
		if DB.relics.has(id):
			rel.append("%s %s" % [Icons.bb("relic", id, 22), DB.relics[id].n])
	t += "[b][color=#f0cf7a]Reliquias[/color][/b]\n%s\n\n" % (" · ".join(rel) if not rel.is_empty() else "Ninguna")
	var top := []
	for pair in h.get("top", []):
		if DB.cards.has(pair[0]):
			top.append("%s ×%d" % [DB.cards[pair[0]].name, pair[1]])
	if not top.is_empty():
		t += "[b][color=#f0cf7a]Cartas más jugadas[/color][/b]\n%s\n\n" % " · ".join(top)
	# mazo agrupado
	var counts := {}
	for k in h.get("deck", []):
		counts[k] = counts.get(k, 0) + 1
	var keys: Array = counts.keys()
	keys.sort()
	var deck := []
	for k in keys:
		var base: String = k.trim_suffix("+")
		if not DB.cards.has(base):
			continue
		deck.append("%s%s%s" % [DB.cards[base].name, "+" if k.ends_with("+") else "", (" ×%d" % counts[k]) if counts[k] > 1 else ""])
	t += "[b][color=#f0cf7a]Mazo (%d cartas)[/color][/b]\n%s" % [h.get("deck", []).size(), ", ".join(deck)]
	await Dlg.message("Detalle de la partida", t, "Cerrar", 820)
