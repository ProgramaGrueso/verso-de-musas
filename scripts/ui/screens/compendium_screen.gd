class_name CompendiumScreen
extends Control
## Compendio: todas las cartas (por musa y neutrales) y reliquias del juego. Lo bloqueado se ve oscurecido,
## con un candado y la condición para desbloquearlo (Progress.lock_group).

const CW := 148.0
const RAR := {"starter": 0, "common": 1, "uncommon": 2, "rare": 3, "special": 4}
const REL_RAR := ["start", "common", "uncommon", "rare", "boss"]
const REL_NAME := {"start": "Iniciales", "common": "Comunes", "uncommon": "Poco comunes", "rare": "Raras", "boss": "De jefe"}   # loc

static var tab := ""   # se recuerda entre visitas: musa, "neutral" o "relics"
var from_run := false


func _ready() -> void:
	Sfx.music("menu", 1, TitleScreen.last_char if TitleScreen.last_char != "" else "zafiro")
	if tab == "":
		tab = DB.playable()[0]
	var lk := Progress.locked_ids(Meta.data)
	var head := Medal.chrome(self, "ev_biblioteca", tr("Compendio"),
		tr("Cartas y reliquias del Verso · %d bloqueadas por descubrir") % lk.size() if not lk.is_empty() else tr("Cartas y reliquias del Verso · todo desbloqueado"))
	var back := UIK.button(tr("← Volver"), "small")
	back.pressed.connect(on_escape)
	head.add_child(back)
	var tabs := HBoxContainer.new()
	tabs.position = Vector2(40, 92)
	tabs.add_theme_constant_override("separation", 6)
	add_child(tabs)
	var first: Button = null
	var ids: Array = DB.playable().duplicate()
	if not DB.neutral.is_empty():
		ids.append("neutral")
	ids.append("relics")
	for id in ids:
		var name: String = DB.characters[id].name if DB.characters.has(id) else (tr("Neutrales") if id == "neutral" else tr("Reliquias"))
		var b := Medal.tab_button(name, tab == id)
		b.pressed.connect(func(): tab = id; Nav.compendium(from_run))
		tabs.add_child(b)
		if tab == id:
			first = b
	var sc := ScrollContainer.new()
	sc.position = Vector2(30, 140)
	sc.size = Vector2(1220, 570)
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(sc)
	var m := MarginContainer.new()
	for s in ["left", "top", "right", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 12)
	sc.add_child(m)
	m.add_child(_relics() if tab == "relics" else _cards(DB.neutral if tab == "neutral" else DB.pool.get(tab, [])))
	(first if first != null else back).grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func on_escape() -> void:
	Nav.map() if (Meta.run != null and from_run) else Nav.gallery()


func _caption(text: String, w: float, col: Color) -> Label:
	var l := UIK.label(text, 13, col, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(w, 0)
	return l


func _lock_overlay(parent: Control, w: float, h: float) -> void:
	var lk := Icons.rect("ui", "lock", w * 0.34)
	lk.position = Vector2((w - lk.size.x) / 2.0, h * 0.36)
	lk.modulate = Color(2.2, 2.1, 2.4)   # compensa el oscurecido del padre
	parent.add_child(lk)


# ---------- Cartas ----------
func _cards(ids: Array) -> Control:
	var list: Array = ids.duplicate()
	list.sort_custom(func(a, b):
		var ra: int = RAR.get(DB.cards[a].rarity, 9)
		var rb: int = RAR.get(DB.cards[b].rarity, 9)
		return ra < rb if ra != rb else str(DB.cards[a].name) < str(DB.cards[b].name))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 22)
	grid.add_theme_constant_override("v_separation", 16)
	for id in list:
		var locked := Progress.is_locked(Meta.data, id)
		var cell := VBoxContainer.new()
		cell.add_theme_constant_override("separation", 4)
		var v := CardView.create({"uid": 0, "id": id, "up": false}, null, CW)
		cell.add_child(v)
		if locked:
			v.modulate = Color(0.42, 0.4, 0.5)
			_lock_overlay(v, CW, CW * 1.42)
			var g := Progress.lock_group(id)
			cell.add_child(_caption(str(g.ch), CW, Color("#caa5ff")))
			UIK.tip(v, tr("[b]Bloqueada[/b]\n%s\n[color=#a79fc0]Progreso: %d / %d[/color]") % [g.ch, mini(int(g.t), Progress.value(Meta.data, g.v)), int(g.t)])
		grid.add_child(cell)
	return grid


# ---------- Reliquias ----------
func _relics() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	for r in REL_RAR:
		var ids := []
		for id in DB.relics.keys():
			if DB.relics[id].rarity == r:
				ids.append(id)
		if ids.is_empty():
			continue
		ids.sort_custom(func(a, b): return str(DB.relics[a].n) < str(DB.relics[b].n))
		v.add_child(UIK.label("%s · %d" % [tr(REL_NAME[r]), ids.size()], 22, UIK.GOLD, "title"))
		var grid := GridContainer.new()
		grid.columns = 3
		grid.add_theme_constant_override("h_separation", 10)
		grid.add_theme_constant_override("v_separation", 10)
		for id in ids:
			grid.add_child(_relic_tile(id))
		v.add_child(grid)
	return v


func _relic_tile(id: String) -> Control:
	var r: Dictionary = DB.relics[id]
	var locked := Progress.is_locked(Meta.data, id)
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(386, 96)
	var sb := UIK.stylebox(Color("#100c1b", 0.9) if locked else Color("#1a1430", 0.94), Color("#2e2846") if locked else Color(UIK.GOLD, 0.55), 1, 12, 0)
	sb.content_margin_left = 10; sb.content_margin_right = 12; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	p.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	p.add_child(row)
	var ic := Icons.frame("relic", id, 60)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	col.add_theme_constant_override("separation", 1)
	var who := ""
	if r.get("char") != null and DB.characters.has(str(r.get("char"))):
		who = " · " + DB.characters[r.char].name
	col.add_child(UIK.label(str(r.n) + who, 17, Color("#c9c2dd") if locked else Color.WHITE, "bold"))
	var d := UIK.rich(str(r.d), 14, UIK.DIM)
	d.custom_minimum_size = Vector2(290, 0)
	col.add_child(d)
	if locked:
		ic.modulate = Color(0.35, 0.33, 0.45)
		_lock_overlay(ic, 60, 46)
		var g := Progress.lock_group(id)
		var ch := UIK.label(tr("Bloqueada · %s") % str(g.ch), 13, Color("#caa5ff"))
		ch.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ch.custom_minimum_size = Vector2(290, 0)
		col.add_child(ch)
	row.add_child(col)
	return p
