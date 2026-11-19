class_name DailyScreen
extends Control
## Reto diario con histórico: calendario mensual (musa de cada día y resultado), racha, código para
## compartir y revancha de días pasados (cuenta en el calendario, no en la racha ni en los logros).

const MONTHS := ["Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio", "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"]
const WD := ["L", "M", "X", "J", "V", "S", "D"]
const STATE_COL := {"win": Color("#f0cf7a"), "late": Color("#8bf0a4"), "tried": Color("#ff7b85"), "none": Color("#3a3355"), "future": Color("#241f36")}

static var sel := ""        # día elegido (AAAA-MM-DD)
static var ym := Vector2i()  # mes visible

var today := ""
var _cal: Control
var _side: Control


## Confirma y arranca el reto de ese día (lo usan el menú, el calendario y la revancha).
static func start(key: String) -> void:
	var inf := Daily.info(key)
	var m: Dictionary = DB.characters[inf.char]
	var res := Meta.daily_result(key)
	var late := key != Daily.key_today()
	var t: String = "[b][color=#f0cf7a]Reto del %s[/color][/b]\n\nMusa: [b]%s[/b], %s\nModificador: [b][color=#caa5ff]%s[/color][/b] — %s\n[font_size=18]Mismos mapas y la misma semilla para todo el mundo. Sin Pesadilla ni modo fácil.[/font_size]" % [
		_date(key), m.name, m.role, Daily.mod_name(inf.mod), Daily.mod_desc(inf.mod)]
	if late:
		t += "\n[font_size=18][color=#8bf0a4]Día pasado: cuenta en tu calendario, pero no en la racha ni en los logros.[/color][/font_size]"
	if not res.is_empty():
		t += "\n[font_size=18]Intentos: %d · %s[/font_size]" % [res.get("tries", 0), "¡ya lo has superado!" if res.get("win", false) else "mejor piso %d" % res.get("floor", 0)]
	if Meta.has_save():
		t += "\n[font_size=18][color=#ff7b85]Se perderá la partida guardada.[/color][/font_size]"
	if not await Dlg.confirm(t, "Empezar", "Ahora no"):
		return
	var G := Daily.new_run(key)
	Meta.run = G
	Meta.clear_save()
	Meta.daily_started(key, G.char)
	Nav.favor()


static func _date(key: String) -> String:
	var p := key.split("-")
	return "%d de %s de %s" % [int(p[2]), MONTHS[int(p[1]) - 1].to_lower(), p[0]] if p.size() == 3 else key


func _ready() -> void:
	Sfx.music("menu", 1, TitleScreen.last_char if TitleScreen.last_char != "" else "zafiro")
	today = Daily.key_today()
	if sel == "" or sel > today:
		sel = today
	if ym == Vector2i():
		ym = Vector2i(int(today.substr(0, 4)), int(today.substr(5, 2)))
	var d := _days()
	var stk := Daily.streak(d, today)
	var wins := 0
	for k in d.keys():
		if d[k] is Dictionary and d[k].get("win", false):
			wins += 1
	var head := Medal.chrome(self, "ev_poza_lunar", "Reto diario",
		"La misma musa, semilla y modificador para todo el mundo cada día · %d reto%s superado%s" % [wins, "" if wins == 1 else "s", "" if wins == 1 else "s"])
	var sk := _streak_box(stk)
	head.add_child(sk)
	var back := UIK.button("← Volver", "small")
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(on_escape)
	head.add_child(back)
	_cal = Control.new()
	_cal.position = Vector2(40, 104)
	_cal.size = Vector2(620, 600)
	add_child(_cal)
	_side = Control.new()
	_side.position = Vector2(690, 104)
	_side.size = Vector2(550, 600)
	add_child(_side)
	_render()
	UIK.fade_in(self, 0.3)


func on_escape() -> void:
	Nav.title()


func _days() -> Dictionary:
	var d = Meta.data.get("daily", {})
	return d if d is Dictionary else {}


func _streak_box(stk: Dictionary) -> Control:
	var p := PanelContainer.new()
	var sb := UIK.stylebox(Color("#1a1430", 0.94), Color(UIK.GOLD, 0.7), 1, 12, 0)
	sb.content_margin_left = 12; sb.content_margin_right = 14; sb.content_margin_top = 4; sb.content_margin_bottom = 4
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	p.add_child(row)
	row.add_child(Icons.rect("ui", "burn", 30))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", -2)
	v.add_child(UIK.label("Racha: %d día%s" % [stk.cur, "" if stk.cur == 1 else "s"], 17, Color.WHITE, "bold"))
	v.add_child(UIK.label("Mejor: %d" % maxi(int(stk.best), int(Meta.data.s.get("dailyStreakBest", 0))), 13, UIK.DIM))
	row.add_child(v)
	UIK.tip(p, "Días seguidos superando el reto [b]el mismo día[/b]. Las revanchas de días pasados no cuentan.")
	return p


func _render() -> void:
	for c in _cal.get_children() + _side.get_children():
		c.queue_free()
	_render_calendar()
	_render_side()


# ---------- Calendario ----------
func _render_calendar() -> void:
	var d := _days()
	var bg := Panel.new()
	bg.size = _cal.size
	bg.add_theme_stylebox_override("panel", UIK.stylebox(Color("#0f0b1a", 0.9), Color("#3a3355"), 1, 16, 10))
	_cal.add_child(bg)
	var nav := HBoxContainer.new()
	nav.position = Vector2(20, 14)
	nav.size = Vector2(580, 44)
	nav.add_theme_constant_override("separation", 10)
	_cal.add_child(nav)
	var pv := UIK.button("◀", "small")
	var nx := UIK.button("▶", "small")
	var cur_ym := Vector2i(int(today.substr(0, 4)), int(today.substr(5, 2)))
	nx.disabled = ym >= cur_ym
	pv.pressed.connect(func(): ym = Daily.shift_month(ym, -1); _render())
	nx.pressed.connect(func(): ym = Daily.shift_month(ym, 1); _render())
	var ml := UIK.label("%s %d" % [MONTHS[ym.y - 1], ym.x], 28, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	ml.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nav.add_child(pv)
	nav.add_child(ml)
	nav.add_child(nx)
	var md := Daily.month_days(ym.x, ym.y)
	var grid := GridContainer.new()
	grid.columns = 7
	grid.position = Vector2(20, 66)
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	_cal.add_child(grid)
	for w in WD:
		var l := UIK.label(w, 15, UIK.DIM, "bold", HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(78, 20)
		grid.add_child(l)
	for i in int(md.first_wd):
		var e := Control.new()
		e.custom_minimum_size = Vector2(78, 70)
		grid.add_child(e)
	var first_btn: Button = null
	for k in md.keys:
		var b := _day_cell(k, Daily.day_state(d, k, today))
		grid.add_child(b)
		if k == sel or (first_btn == null and k == today):
			first_btn = b
	var leg := HBoxContainer.new()
	leg.position = Vector2(20, 560)
	leg.add_theme_constant_override("separation", 16)
	_cal.add_child(leg)
	for s in [["win", "Superado"], ["late", "Superado otro día"], ["tried", "Intentado"]]:
		var dot := Panel.new()
		dot.custom_minimum_size = Vector2(14, 14)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		dot.add_theme_stylebox_override("panel", UIK.stylebox(STATE_COL[s[0]], Color(0, 0, 0, 0), 0, 7, 0))
		leg.add_child(dot)
		leg.add_child(UIK.label(s[1], 14, UIK.DIM))
	if first_btn != null:
		first_btn.grab_focus.call_deferred()


func _day_cell(k: String, st: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(78, 70)
	b.focus_mode = Control.FOCUS_ALL
	var col: Color = STATE_COL[st]
	var is_sel := k == sel
	var fill := Color("#1a1430") if st != "future" else Color("#110d1c")
	if st == "win":
		fill = Color("#3a2e12")
	elif st == "late":
		fill = Color("#14301f")
	var sb := UIK.stylebox(fill, Color.WHITE if is_sel else col, 3 if is_sel else (2 if st in ["win", "late", "tried"] else 1), 10, 6 if is_sel else 0)
	var sbh := UIK.stylebox(fill.lightened(0.12), Color.WHITE, 2, 10, 6)
	for s in ["normal", "pressed", "disabled"]:
		b.add_theme_stylebox_override(s, sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	var n := UIK.label(str(int(k.substr(8, 2))), 15, UIK.GOLD if k == today else (UIK.DIM if st == "future" else Color.WHITE), "bold")
	n.position = Vector2(7, 3)
	b.add_child(n)
	if st == "future":
		b.disabled = true
		return b
	var inf := Daily.info(k)
	var ic := Medal.disc("muse:" + str(inf.char), 34, st in ["win", "late"] or k == today, Color(0, 0, 0, 0))
	ic.position = Vector2(38, 30)
	b.add_child(ic)
	if k == today:
		var hl := UIK.label("HOY", 11, UIK.GOLD, "bold")
		hl.position = Vector2(46, 4)
		b.add_child(hl)
	UIK.tip(b, "[b]%s[/b]\n%s · %s" % [_date(k), DB.characters[inf.char].name, Daily.mod_name(inf.mod)])
	b.pressed.connect(func(): sel = k; _render())
	return b


# ---------- Detalle del día ----------
func _render_side() -> void:
	var inf := Daily.info(sel)
	var m: Dictionary = DB.characters[inf.char]
	var res := Meta.daily_result(sel)
	var st := Daily.day_state(_days(), sel, today)
	var card := Panel.new()
	card.size = _side.size
	card.clip_contents = true
	card.add_theme_stylebox_override("panel", UIK.stylebox(Color("#0f0b1a", 0.94), Color(m.glow), 2, 16, 12))
	_side.add_child(card)
	var art := TextureRect.new()
	art.texture = UIK.tex("res://assets/ui/%s_select.webp" % inf.char)
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.position = Vector2(2, 2)
	art.size = Vector2(546, 250)
	card.add_child(art)
	var sh := TextureRect.new()
	sh.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.1)], [0.55, Color(0, 0, 0, 0.3)], [1.0, Color("#0f0b1a")]])
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	sh.position = art.position
	sh.size = art.size
	card.add_child(sh)
	var dl := UIK.label(("Hoy · " if sel == today else "") + _date(sel), 18, UIK.GOLD, "bold")
	UIK.outlined(dl, 4)
	dl.position = Vector2(22, 16)
	card.add_child(dl)
	var v := VBoxContainer.new()
	v.position = Vector2(22, 170)
	v.size = Vector2(506, 420)
	v.add_theme_constant_override("separation", 6)
	card.add_child(v)
	var nl := UIK.label(m.name, 34, Color.WHITE, "bold")
	UIK.outlined(nl, 6)
	v.add_child(nl)
	v.add_child(UIK.label(m.role, 16, Color(m.glow)))
	var mod := UIK.rich("[b][color=#caa5ff]%s[/color][/b] — %s" % [Daily.mod_name(inf.mod), Daily.mod_desc(inf.mod)], 17)
	mod.custom_minimum_size = Vector2(500, 0)
	v.add_child(mod)
	var rt: String
	match st:
		"win": rt = "[color=#f0cf7a]Superado[/color] en %d intento%s" % [int(res.get("tries", 1)), "" if int(res.get("tries", 1)) == 1 else "s"]
		"late": rt = "[color=#8bf0a4]Superado fuera de plazo[/color] · %d intento%s" % [int(res.get("tries", 1)), "" if int(res.get("tries", 1)) == 1 else "s"]
		"tried": rt = "[color=#ff7b85]Sin superar[/color] · mejor piso %d en %d intento%s" % [int(res.get("floor", 0)), int(res.get("tries", 1)), "" if int(res.get("tries", 1)) == 1 else "s"]
		_: rt = "[color=#a79fc0]Aún no lo has intentado[/color]"
	v.add_child(UIK.rich(rt, 17))
	v.add_child(UIK.label("Semilla %d" % int(inf.seed), 14, UIK.DIM))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 8)
	v.add_child(sp)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var play_t := "Jugar el reto de hoy" if sel == today else ("Revancha de este día" if st != "none" else "Jugar este día")
	var play := UIK.button(play_t, "green", 20)
	play.pressed.connect(func(): DailyScreen.start(sel))
	row.add_child(play)
	var cp := UIK.button("Copiar reto", "", 20)
	cp.pressed.connect(func():
		DisplayServer.clipboard_set(Daily.share_text(sel, res))
		Main.I.toast("Reto copiado: compártelo y comparad resultados"))
	UIK.tip(cp, "Copia el día, la musa, el modificador, la semilla y tu resultado.")
	row.add_child(cp)
	if sel != today:
		var note := UIK.label("Los días pasados cuentan en el calendario, no en la racha ni en los logros.", 13, UIK.DIM)
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.custom_minimum_size = Vector2(500, 0)
		v.add_child(note)
