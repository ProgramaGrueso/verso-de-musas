class_name EnemyView
extends Control
## Un enemigo en combate: intención, imagen animada, barra de vida, nombre y estados.

signal clicked(view)

const ENEMY_SCALE := 1.3
## Enemigos cuyo arte mira a la derecha: se voltean para que miren a la musa (izquierda).
const FLIP := ["dockrat", "vinelasher"]
const MV := {"dockrat": "skitter", "minicrab": "skitter", "slime": "slither", "honeyslime": "slither", "crab": "stomp", "crabking": "stomp", "thornbeast": "stomp",
	"mossgolem": "stomp", "chainwarden": "stomp", "beetle": "stomp", "royalguard": "stomp", "stag": "stomp", "ghostpirate": "hover", "jelly": "hover", "wasp": "hover",
	"drone": "hover", "nurse": "hover", "queen": "hover", "hivemind": "hover", "tentacle": "sway", "sporecap": "sway", "vinelasher": "sway", "sprout": "sway",
	"treant": "sway", "rootmother": "sway", "dryad": "sway"}
const EMOJI := {"dockrat": "🐀", "slime": "🟢", "crab": "🦀", "jelly": "🪼", "ghostpirate": "👻", "minicrab": "🦀", "chainwarden": "⛓️", "tentacle": "🐙", "crabking": "🦀",
	"sporecap": "🍄", "vinelasher": "🌿", "thornbeast": "🐗", "mossgolem": "🗿", "dryad": "🌳", "sprout": "🌱", "treant": "🌲", "stag": "🦌", "rootmother": "🌳", "drone": "🐝",
	"wasp": "🐝", "honeyslime": "🍯", "nurse": "🐛", "beetle": "🪲", "royalguard": "🛡️", "hivemind": "🧠", "queen": "👑"}

var e: Dictionary
var eh := 150.0
var img_w := 150.0
var body: Control
var img: Control
var hp_bar: HpBar
var block_badge: Panel
var block_lbl: Label
var name_lbl: Label
var intent_box: Control
var status_box: HFlowContainer
var target_icon: Control
var dying := false
var _idle_tw: Tween
var _bright := 1.0
var rest := Vector2.ZERO   ## posición de reposo del cuerpo: todas las animaciones vuelven a ella (no a la posición de mitad de animación)
var _x_tw: Tween
var _y_tw: Tween


func setup(p_e: Dictionary, k: float) -> void:
	e = p_e
	var cap := 260.0 if e.def.tier == "boss" else (225.0 if e.def.tier == "elite" else 190.0)
	eh = roundf(minf(e.def.h * 0.85, cap) * k * 0.65 * ENEMY_SCALE)
	var tex := UIK.tex("res://assets/enemies/%s.webp" % e.id)
	img_w = eh * 0.9
	if tex != null:
		img_w = eh * tex.get_width() / tex.get_height()
	var w := maxf(190.0, img_w + 20.0)
	custom_minimum_size = Vector2(w, 68 + eh + 4 + 26 + 24 + 34)
	size = custom_minimum_size
	pivot_offset = Vector2(size.x / 2.0, size.y)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# intención (arriba)
	intent_box = Control.new()
	intent_box.position = Vector2(0, 0)
	intent_box.size = Vector2(w, 68)
	intent_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(intent_box)
	# cuerpo
	body = Control.new()
	body.position = Vector2((w - img_w) / 2.0, 72)
	body.size = Vector2(img_w, eh)
	rest = body.position
	body.pivot_offset = Vector2(img_w / 2.0, eh)
	body.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(body)
	var shadow := TextureRect.new()
	shadow.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.8)], [1.0, Color(0, 0, 0, 0)]])
	var gs := GradientTexture2D.new()
	gs.gradient = Gradient.new()
	gs.gradient.colors = PackedColorArray([Color(0, 0, 0, 0.75), Color(0, 0, 0, 0)])
	gs.fill = GradientTexture2D.FILL_RADIAL
	gs.fill_from = Vector2(0.5, 0.5)
	gs.fill_to = Vector2(1.0, 0.5)
	gs.width = 64
	gs.height = 64
	shadow.texture = gs
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.size = Vector2(img_w * 0.9, 22)
	shadow.position = Vector2(img_w * 0.05, eh - 14)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	body.add_child(shadow)
	if tex != null:
		var t := TextureRect.new()
		t.texture = tex
		t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		t.stretch_mode = TextureRect.STRETCH_SCALE
		t.size = Vector2(img_w, eh)
		t.flip_h = e.id in FLIP
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		body.add_child(t)
		img = t
	else:
		var l := UIK.label(EMOJI.get(e.id, "👾"), int(eh * 0.6), Color.WHITE, "sans", HORIZONTAL_ALIGNMENT_CENTER)
		l.size = Vector2(img_w, eh)
		l.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
		body.add_child(l)
		img = l
	body.gui_input.connect(func(ev):
		if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			clicked.emit(self))
	target_icon = Icons.rect("ui", "target", 48)
	target_icon.position = Vector2((img_w - 48) / 2.0, eh * 0.3)
	target_icon.pivot_offset = Vector2(24, 24)
	target_icon.visible = false
	body.add_child(target_icon)
	# barra
	var by := 72.0 + eh + 6.0
	hp_bar = HpBar.new(150, 18)
	hp_bar.position = Vector2((w - 150) / 2.0, by)
	add_child(hp_bar)
	block_badge = Panel.new()
	block_badge.size = Vector2(38, 38)
	block_badge.position = Vector2((w - 150) / 2.0 - 12, by - 12)
	block_badge.add_theme_stylebox_override("panel", _block_style())
	block_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	block_badge.visible = false
	block_lbl = UIK.label("", 19, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	block_lbl.size = Vector2(38, 38)
	block_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIK.outlined(block_lbl, 4)
	block_badge.add_child(block_lbl)
	add_child(block_badge)
	name_lbl = UIK.label(e.name, 15, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	name_lbl.position = Vector2(0, by + 24)
	name_lbl.size = Vector2(w, 22)
	UIK.outlined(name_lbl, 5)
	if e.def.tier == "boss":
		name_lbl.add_theme_color_override("font_color", Color("#ff9aa0"))
	elif e.def.tier == "elite":
		name_lbl.add_theme_color_override("font_color", Color("#ffcf80"))
	add_child(name_lbl)
	status_box = HFlowContainer.new()
	status_box.position = Vector2(0, by + 48)
	status_box.size = Vector2(w, 34)
	status_box.alignment = FlowContainer.ALIGNMENT_CENTER
	status_box.add_theme_constant_override("h_separation", 4)
	status_box.add_theme_constant_override("v_separation", 3)
	status_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(status_box)
	_start_idle()


static func _block_style() -> StyleBoxFlat:
	var s := UIK.stylebox(Color("#3b83d6"), Color("#dff0ff"), 2, 19, 4)
	return s


func _start_idle() -> void:
	var kind: String = MV.get(e.id, "sway")
	if _idle_tw and _idle_tw.is_valid():
		_idle_tw.kill()
	body.rotation = 0.0
	body.scale = Vector2.ONE
	var ph := randf() * 1.5
	_idle_tw = body.create_tween().set_loops()
	match kind:
		"skitter":
			_idle_tw.tween_property(body, "position:y", rest.y - 6, 0.18 + ph * 0.05).set_trans(Tween.TRANS_SINE)
			_idle_tw.tween_property(body, "position:y", rest.y, 0.18).set_trans(Tween.TRANS_SINE)
			_idle_tw.tween_interval(0.35 + ph * 0.3)
		"slither":
			_idle_tw.tween_property(body, "scale", Vector2(1.05, 0.95), 1.2 + ph * 0.2).set_trans(Tween.TRANS_SINE)
			_idle_tw.tween_property(body, "scale", Vector2(0.97, 1.04), 1.2 + ph * 0.2).set_trans(Tween.TRANS_SINE)
		"stomp":
			_idle_tw.tween_property(body, "scale", Vector2(1.02, 0.975), 1.4 + ph * 0.2).set_trans(Tween.TRANS_SINE)
			_idle_tw.tween_property(body, "scale", Vector2(0.99, 1.02), 1.4 + ph * 0.2).set_trans(Tween.TRANS_SINE)
		"hover":
			_idle_tw.tween_property(body, "position:y", rest.y - 12, 1.1 + ph * 0.2).set_trans(Tween.TRANS_SINE)
			_idle_tw.tween_property(body, "position:y", rest.y + 2, 1.1 + ph * 0.2).set_trans(Tween.TRANS_SINE)
		_:
			_idle_tw.tween_property(body, "rotation", deg_to_rad(2.2), 1.5 + ph * 0.3).set_trans(Tween.TRANS_SINE)
			_idle_tw.tween_property(body, "rotation", deg_to_rad(-2.2), 1.5 + ph * 0.3).set_trans(Tween.TRANS_SINE)


func body_center() -> Vector2:
	return body.global_position + Vector2(img_w / 2.0, eh * 0.4)


func refresh(C) -> void:
	if e.hp > 0:
		_rebuild_intent(C)
		block_badge.visible = e.block > 0
		block_lbl.text = str(e.block)
		_rebuild_status()
	else:
		for c in intent_box.get_children():
			c.queue_free()
		for c in status_box.get_children():
			c.queue_free()
		block_badge.visible = false
	hp_bar.set_values(e.hp, e.maxHp)


func _rebuild_status() -> void:
	for c in status_box.get_children():
		c.queue_free()
	for k in e.status.keys():
		var v: int = e.status[k]
		if v == 0 or not DB.st.has(k):
			continue
		status_box.add_child(status_chip(k, v))


static func status_chip(k: String, v: int) -> Control:
	var has_ic := Icons.has("status", k)
	var bad := Eng.st_neg(k, v)
	var p := PanelContainer.new()
	var sb := UIK.stylebox(Color(0, 0, 0, 0.66), Color("#ff6a74", 0.66) if bad else Color("#7ef0a0", 0.66), 1, 14, 0)
	sb.content_margin_left = 6; sb.content_margin_right = 7; sb.content_margin_top = 1; sb.content_margin_bottom = 1
	p.add_theme_stylebox_override("panel", sb)
	var col := Color("#ffb3b9") if bad else Color("#c9ffd8")
	if has_ic:
		var hb := Icons.with_text("status", k, str(v), 22, 15, col)
		p.add_child(hb)
	else:
		p.add_child(UIK.label("%s%d" % [Eng.st_icon(k), v], 15, col, "bold"))
	UIK.tip(p, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [Eng.st_name(k), Eng.st_desc(k, v)])
	return p


func _rebuild_intent(C) -> void:
	for c in intent_box.get_children():
		c.queue_free()
	var it = e.intent
	if it == null:
		return
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 6)
	row.size = Vector2(intent_box.size.x, 64)
	var tips := []
	var parts := 0
	var atk: bool = it.get("dmg", 0) > 0
	if atk:
		var d := Eng.intent_damage(C, e)
		var hits: int = it.get("hits", 1)
		row.add_child(_intent_icon("attack"))
		var n := UIK.label(str(d), 30, Color("#ffb0b6"), "bold")
		UIK.outlined(n, 6)
		row.add_child(n)
		if hits > 1:
			var hl := UIK.label("×%d" % hits, 18, Color("#ffffdd"), "bold")
			UIK.outlined(hl, 5)
			row.add_child(hl)
		tips.append("Atacará por %d%s." % [d, (" (%d veces)" % hits) if hits > 1 else ""])
		parts += 1
	if it.get("block", 0):
		row.add_child(_intent_icon("block"))
		tips.append("Ganará %d de Bloqueo." % it.block)
		parts += 1
	if it.get("selfStr", 0) or it.get("thorns", 0):
		row.add_child(_intent_icon("buff"))
		tips.append(("Ganará %d de Fuerza." % it.selfStr) if it.get("selfStr", 0) else ("Ganará %d de Espinas." % it.thorns))
		parts += 1
	if it.has("apply"):
		row.add_child(_intent_icon("debuff"))
		var ap := []
		for k in it.apply.keys():
			ap.append("%d %s" % [it.apply[k], Eng.st_name(k)])
		tips.append("Te aplicará: " + ", ".join(ap) + ".")
		parts += 1
	if it.has("add"):
		row.add_child(_intent_icon("curse"))
		tips.append("Añadirá %d %s a tu mazo." % [it.add.n, DB.cards[it.add.id].name])
		parts += 1
	if it.get("heal", 0) or it.get("healAll", 0):
		row.add_child(_intent_icon("heal"))
		tips.append("Curará.")
		parts += 1
	if it.has("summon"):
		row.add_child(_intent_icon("summon"))
		tips.append("Invocará aliados.")
		parts += 1
	if parts == 0:
		row.add_child(_intent_icon("unknown"))
	intent_box.add_child(row)
	row.mouse_filter = Control.MOUSE_FILTER_PASS
	UIK.tip(row, "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [it.name, " ".join(tips)])
	# flota suavemente
	row.position.y = 0
	var tw := row.create_tween().set_loops()
	tw.tween_property(row, "position:y", -7.0, 0.9).set_trans(Tween.TRANS_SINE)
	tw.tween_property(row, "position:y", 0.0, 0.9).set_trans(Tween.TRANS_SINE)


func _intent_icon(id: String) -> Control:
	if Icons.has("intent", id):
		return Icons.rect("intent", id, 44)
	return UIK.label("?", 38)


func set_target_ok(on: bool) -> void:
	target_icon.visible = on
	body.modulate = Color(1.25, 1.2, 0.9) if on else Color.WHITE
	if on:
		var tw := target_icon.create_tween().set_loops()
		tw.tween_property(target_icon, "scale", Vector2(1.25, 1.25), 0.4)
		tw.tween_property(target_icon, "scale", Vector2.ONE, 0.4)


func set_target_cur(on: bool) -> void:
	name_lbl.add_theme_color_override("font_color", UIK.GOLD if on else Color.WHITE)
	scale = Vector2(1.06, 1.06) if on else Vector2.ONE


func _kill_x() -> void:
	if _x_tw and _x_tw.is_valid():
		_x_tw.kill()
	body.position.x = rest.x


func flash_hit() -> void:
	var tw := body.create_tween()
	body.modulate = Color(2.6, 2.6, 2.6)
	tw.tween_property(body, "modulate", Color.WHITE, 0.22)
	_kill_x()
	_x_tw = body.create_tween()
	_x_tw.tween_property(body, "position:x", rest.x - 12, 0.04)
	_x_tw.tween_property(body, "position:x", rest.x + 10, 0.06)
	_x_tw.tween_property(body, "position:x", rest.x - 6, 0.06)
	_x_tw.tween_property(body, "position:x", rest.x, 0.06)


func act_attack() -> void:
	_kill_x()
	body.scale = Vector2.ONE
	_x_tw = body.create_tween()
	_x_tw.tween_property(body, "position:x", rest.x - 110, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_x_tw.parallel().tween_property(body, "scale", Vector2(1.12, 1.12), 0.16)
	_x_tw.tween_property(body, "position:x", rest.x, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	_x_tw.parallel().tween_property(body, "scale", Vector2.ONE, 0.28)


func act_buff() -> void:
	if _y_tw and _y_tw.is_valid():
		_y_tw.kill()
	_y_tw = body.create_tween()
	_y_tw.tween_property(body, "position:y", rest.y - 30, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_y_tw.parallel().tween_property(body, "scale", Vector2(1.06, 1.06), 0.2)
	_y_tw.tween_property(body, "position:y", rest.y, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	_y_tw.parallel().tween_property(body, "scale", Vector2.ONE, 0.25)


func die() -> void:
	dying = true
	if _idle_tw and _idle_tw.is_valid():
		_idle_tw.kill()
	for c in intent_box.get_children():
		c.queue_free()
	var tw := create_tween().set_parallel(true)
	tw.tween_property(body, "modulate", Color(0.2, 0.2, 0.2, 0.0), 0.8)
	tw.tween_property(body, "position:y", rest.y + 30, 0.8)
	tw.tween_property(body, "scale", Vector2(0.8, 0.8), 0.8)
	tw.chain().tween_callback(func(): visible = false)


func spawn_in() -> void:
	modulate.a = 0.0
	scale = Vector2(0.3, 0.3)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(self, "modulate:a", 1.0, 0.5)
	tw.tween_property(self, "scale", Vector2.ONE, 0.5).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
