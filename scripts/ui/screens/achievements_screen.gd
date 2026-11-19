class_name AchievementsScreen
extends Control
## Logros, Maestría por musa y desbloqueos de contenido (Fase 3). Todo se lee de Meta.data vía Progress.

var tab := "ach"   # "ach" | "mastery" | "unl"


func _ready() -> void:
	Sfx.music("menu", 1, TitleScreen.last_char if TitleScreen.last_char != "" else "zafiro")
	var got := Progress.ach_count(Meta.data)
	var total := Progress.achievements().size()
	var head := Medal.chrome(self, "ev_templo_sol", "Logros y Maestría",
		"%d de %d logros · %d de %d desbloqueos de contenido" % [got, total, Progress.unlocked_groups(Meta.data).size(), Progress.groups().size()])
	var first: Button = null
	for t in [["ach", "Logros"], ["mastery", "Maestría"], ["unl", "Desbloqueos"]]:
		var b := Medal.tab_button(t[1], tab == t[0])
		var id: String = t[0]
		b.pressed.connect(func(): Nav.achievements(id))
		head.add_child(b)
		if tab == t[0]:
			first = b
	var back := UIK.button("← Volver", "small")
	back.pressed.connect(on_escape)
	head.add_child(back)
	var sc := ScrollContainer.new()
	sc.position = Vector2(30, 100)
	sc.size = Vector2(1220, 610)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	match tab:
		"mastery": sc.add_child(_mastery())
		"unl": sc.add_child(_unlocks())
		_: sc.add_child(_achievements())
	first.grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func on_escape() -> void:
	Nav.title()


# ---------- Logros ----------
func _achievements() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(1200, 0)
	for c in Progress.cats():
		var list := []
		for a in Progress.achievements():
			if a.cat == c.id:
				list.append(a)
		if list.is_empty():
			continue
		var n := 0
		for a in list:
			if Progress.has_ach(Meta.data, a.id):
				n += 1
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 10)
		var p := str(c.icon).split(":")
		row.add_child(Icons.rect(p[0], p[1], 30))
		row.add_child(UIK.label(c.n, 24, UIK.GOLD, "title"))
		var cnt := UIK.label("%d / %d" % [n, list.size()], 17, UIK.GREEN if n == list.size() else UIK.DIM, "bold")
		cnt.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(cnt)
		v.add_child(row)
		var grid := GridContainer.new()
		grid.columns = 2
		grid.add_theme_constant_override("h_separation", 12)
		grid.add_theme_constant_override("v_separation", 10)
		for a in list:
			grid.add_child(_ach_tile(a))
		v.add_child(grid)
	return v


func _ach_tile(a: Dictionary) -> Control:
	var got := Progress.has_ach(Meta.data, a.id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(590, 104)
	var sb := UIK.stylebox(Color("#1a1430", 0.94) if got else Color("#100c1b", 0.9), Color(UIK.GOLD, 0.8) if got else Color("#2e2846"), 2 if got else 1, 14, 6 if got else 0)
	sb.content_margin_left = 12; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var md := Medal.make(a, 84, got)
	md.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(md)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	col.add_child(UIK.label(a.n, 21, Color.WHITE if got else Color("#c9c2dd"), "bold"))
	var d := UIK.label(a.d, 15, UIK.DIM)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(440, 0)
	col.add_child(d)
	if got:
		var ts := int(Meta.data.ach[a.id])
		var ds := Time.get_date_string_from_unix_time(ts).split("-") if ts > 0 else []
		col.add_child(UIK.label("Conseguido el %s/%s/%s" % [ds[2], ds[1], ds[0]] if ds.size() == 3 else "Conseguido", 14, UIK.GOLD))
	else:
		var t := Progress.target(a)
		if t > 1:
			var pr := HBoxContainer.new()
			pr.add_theme_constant_override("separation", 10)
			var cur := Progress.ach_progress(Meta.data, a)
			var bar := Medal.bar(cur, t, 300, Color("#caa5ff"))
			bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			pr.add_child(bar)
			pr.add_child(UIK.label("%d / %d" % [cur, t], 14, UIK.DIM, "bold"))
			col.add_child(pr)
	row.add_child(col)
	return p


# ---------- Maestría ----------
func _mastery() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.custom_minimum_size = Vector2(1200, 0)
	var rk := Progress.ranks()
	var names := []
	for r in rk:
		names.append("[color=%s]%s[/color] %d" % [r.c, r.n, int(r.t)])
	var info := UIK.rich("Cada victoria suma puntos de Maestría a su musa: 1 por ganar, +1 en Pesadilla 4 o más y +1 en Pesadilla 8 o más (el modo fácil no suma).\nRangos: " + " · ".join(names), 16, UIK.DIM)
	info.custom_minimum_size = Vector2(1180, 0)
	v.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for c in DB.playable():
		grid.add_child(_muse_card(c))
	v.add_child(grid)
	return v


func _muse_card(c: String) -> Control:
	var m: Dictionary = DB.characters[c]
	var glow := Color(m.glow)
	var pts := Progress.mastery_points(Meta.data, c)
	var r := Progress.mastery_rank(Meta.data, c)
	var rk := Progress.ranks()
	var card := Panel.new()
	card.custom_minimum_size = Vector2(390, 262)
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", UIK.stylebox(Color("#120e1f"), Color(Progress.rank_color(r), 0.9) if r >= 0 else Color("#2e2846"), 2, 16, 0))
	var art := TextureRect.new()
	art.texture = UIK.tex("res://assets/ui/%s_select.webp" % c)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(2, 2)
	art.size = Vector2(386, 258)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if r < 0:
		art.material = Medal.gray()
	card.add_child(art)
	var sh := TextureRect.new()
	sh.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.0)], [0.4, Color(0, 0, 0, 0.35)], [1.0, Color(0.02, 0.01, 0.05, 0.95)]])
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.position = art.position
	sh.size = art.size
	sh.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(sh)
	var ic := Medal.disc("muse:" + c, 54, true, glow)
	ic.position = Vector2(14, 14)
	card.add_child(ic)
	var v := VBoxContainer.new()
	v.position = Vector2(18, 128)
	v.size = Vector2(356, 124)
	v.add_theme_constant_override("separation", 2)
	card.add_child(v)
	var nl := UIK.label(m.name, 28, Color.WHITE, "bold")
	UIK.outlined(nl, 5)
	v.add_child(nl)
	var rl := UIK.label(Progress.rank_name(r) if r >= 0 else "Sin rango todavía", 20, Progress.rank_color(r), "title")
	UIK.outlined(rl, 4)
	v.add_child(rl)
	var pips := HBoxContainer.new()
	pips.add_theme_constant_override("separation", 6)
	for i in rk.size():
		var pip := Panel.new()
		pip.custom_minimum_size = Vector2(44, 8)
		pip.add_theme_stylebox_override("panel", UIK.stylebox(Color(rk[i].c) if i <= r else Color(0.1, 0.08, 0.16, 0.9), Color(rk[i].c, 0.7), 1, 4, 0))
		UIK.tip(pip, "[b][color=%s]%s[/color][/b]\n%d puntos" % [rk[i].c, rk[i].n, int(rk[i].t)])
		pips.add_child(pip)
	v.add_child(pips)
	var wins := int(Meta.data.s.get("win_" + c, 0))
	var nx := r + 1
	var t := "%d punto%s · %d victoria%s" % [pts, "" if pts == 1 else "s", wins, "" if wins == 1 else "s"]
	if nx < rk.size():
		t += " · faltan %d para %s" % [int(rk[nx].t) - pts, rk[nx].n]
	else:
		t += " · rango máximo"
	var tl := UIK.label(t, 15, Color("#e4dcf5"))
	UIK.outlined(tl, 3)
	v.add_child(tl)
	return card


# ---------- Desbloqueos de contenido ----------
func _unlocks() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	v.custom_minimum_size = Vector2(1200, 0)
	var msg := "Las cartas y reliquias nuevas entran en el botín, las tiendas y los eventos al alcanzar cada hito (desde la partida siguiente). El reto diario siempre usa todo el contenido."
	if not DB.extra:
		msg = "Contenido ampliado desactivado: no hay nada bloqueado."
	var info := UIK.label(msg, 16, UIK.DIM)
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(1180, 0)
	v.add_child(info)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_theme_constant_override("v_separation", 10)
	var u := Progress.unlocked_groups(Meta.data)
	for g in Progress.groups():
		grid.add_child(_group_tile(g, g.id in u or not DB.extra))
	v.add_child(grid)
	return v


func _group_tile(g: Dictionary, ok: bool) -> Control:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(590, 92)
	var sb := UIK.stylebox(Color("#13201a", 0.94) if ok else Color("#100c1b", 0.9), Color(UIK.GREEN, 0.75) if ok else Color("#2e2846"), 2 if ok else 1, 14, 0)
	sb.content_margin_left = 12; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	p.add_child(row)
	var ic := Progress.group_icon(g)
	var art: Control
	if ic[0] == "muse":
		art = Medal.disc("muse:" + str(ic[1]), 64, ok, Color(DB.characters[ic[1]].glow))
	else:
		art = Icons.frame(ic[0], ic[1], 64)
		if not ok:
			art.modulate = Color(0.45, 0.42, 0.55)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 2)
	var t := UIK.label(UnlockBanner._cap(Progress.group_text(g)), 17, Color.WHITE if ok else Color("#c9c2dd"), "bold")
	t.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	t.custom_minimum_size = Vector2(470, 0)
	col.add_child(t)
	if ok:
		col.add_child(UIK.label("Disponible", 14, UIK.GREEN, "bold"))
	else:
		var ch := UIK.label(str(g.ch), 14, UIK.DIM)
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.custom_minimum_size = Vector2(470, 0)
		col.add_child(ch)
		var pr := HBoxContainer.new()
		pr.add_theme_constant_override("separation", 10)
		var cur := mini(int(g.t), Progress.value(Meta.data, g.v))
		var bar := Medal.bar(cur, int(g.t), 260, UIK.GREEN)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		pr.add_child(bar)
		pr.add_child(UIK.label("%d / %d" % [cur, int(g.t)], 13, UIK.DIM, "bold"))
		col.add_child(pr)
	row.add_child(col)
	return p
