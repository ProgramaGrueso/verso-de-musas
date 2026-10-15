class_name CombatScreen
extends Control
## Pantalla de combate: arena, mano de cartas, objetivos, animaciones y flujo de turnos.

const HAND_CX := 635.0
const HAND_W := 970.0
const CARD_W := 168.0
const CARD_H := 238.56
const ARENA_POS := Vector2(0, 52)
const FLOOR := {"underdocks": [1.3, -385.0, "#17130f"], "overgrowth": [1.3, -400.0, "#15130d"], "hive": [1.55, -620.0, "#2a1a08"]}

var ids: Array = []
var tier := "normal"
var C: Dictionary
var G

var busy := true
var over := false
var pending = null            # {kind:"card",uid} | {kind:"potion",slot}
var sel_uid := -1
var t_idx := 0
var hover_uid := -1
var sprite: MuseSprite
var enemy_views := {}         # uid -> EnemyView
var card_views := {}          # uid -> CardView
var seen := {}

var arena: Control
var enemies_layer: Control
var hand_layer: Control
var fx_layer: Control
var ui_layer: Control
var player_box: Control
var player_hp: HpBar
var player_block: Panel
var player_block_lbl: Label
var player_status: HFlowContainer
var osty_box: Control
var osty_hp: HpBar
var osty_pow: Label
var osty_img: TextureRect
var orb_bar: HBoxContainer
var energy_panel: Panel
var energy_lbl: Label
var draw_btn: Button
var discard_btn: Button
var exhaust_btn: Button
var end_btn: Button
var tipbar: Label
var vignette: TextureRect
var target_line: TargetLine

var _press_card: CardView = null
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_view: CardView = null
var _pop_n := 0
var _shake_tw: Tween


func _ready() -> void:
	G = Meta.run
	Sfx.music("boss" if tier == "boss" else ("elite" if tier == "elite" else "combat"), G.act)
	_build_background()
	arena = Control.new()
	arena.position = ARENA_POS
	arena.size = Vector2(1280, 450)
	arena.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(arena)
	var fade := TextureRect.new()
	fade.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.72)]])
	fade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.position = Vector2(0, 330)
	fade.size = Vector2(1280, 120)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(fade)
	var shadow := TextureRect.new()
	var gs := GradientTexture2D.new()
	gs.gradient = Gradient.new()
	gs.gradient.colors = PackedColorArray([Color(0, 0, 0, 0.8), Color(0, 0, 0, 0)])
	gs.fill = GradientTexture2D.FILL_RADIAL
	gs.fill_from = Vector2(0.5, 0.5)
	gs.fill_to = Vector2(1.0, 0.5)
	gs.width = 64
	gs.height = 64
	shadow.texture = gs
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	shadow.position = Vector2(150, 384)
	shadow.size = Vector2(220, 36)
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(shadow)
	_build_player()
	enemies_layer = Control.new()
	enemies_layer.size = Vector2(1280, 450)
	enemies_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(enemies_layer)
	vignette = TextureRect.new()
	var vg := GradientTexture2D.new()
	vg.gradient = Gradient.new()
	vg.gradient.offsets = PackedFloat32Array([0.55, 1.0])
	vg.gradient.colors = PackedColorArray([Color(0.7, 0.0, 0.05, 0.0), Color(0.7, 0.0, 0.05, 0.55)])
	vg.fill = GradientTexture2D.FILL_RADIAL
	vg.fill_from = Vector2(0.5, 0.5)
	vg.fill_to = Vector2(1.0, 0.8)
	vg.width = 128
	vg.height = 128
	vignette.texture = vg
	vignette.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	vignette.stretch_mode = TextureRect.STRETCH_SCALE
	UIK.full_rect(vignette)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.visible = false
	add_child(vignette)
	var vtw := vignette.create_tween().set_loops()
	vtw.tween_property(vignette, "modulate:a", 0.45, 0.55).set_trans(Tween.TRANS_SINE)
	vtw.tween_property(vignette, "modulate:a", 1.0, 0.55).set_trans(Tween.TRANS_SINE)
	hand_layer = Control.new()
	UIK.full_rect(hand_layer)
	hand_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(hand_layer)
	target_line = TargetLine.new()
	target_line.screen = self
	UIK.full_rect(target_line)
	target_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(target_line)
	ui_layer = Control.new()
	UIK.full_rect(ui_layer)
	ui_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ui_layer)
	_build_hud()
	fx_layer = Control.new()
	UIK.full_rect(fx_layer)
	fx_layer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.z_index = 300
	add_child(fx_layer)
	# jugadora y combate
	C = Eng.start_combat(G, ids, {"tier": tier, "fx": _fx})
	over = false
	Main.I.on_potion = _on_potion
	_render_all(true)
	var boss: Dictionary = C.enemies[0]
	_banner(boss.name if tier == "boss" else ("¡Élite!" if tier == "elite" else "Tu turno"), tier != "normal")
	busy = false
	_update_hud()
	_update_tip()
	if C.over != "":
		_check_end()


func cleanup() -> void:
	C = {}
	Main.I.on_potion = Callable()


func on_escape() -> void:
	if sel_uid >= 0 or pending != null:
		_cancel_sel()
	else:
		Dlg.pause_menu()


# ============================== construcción ==============================
var _bg_img: TextureRect
var _bg_base := Vector2.ZERO


func _process(_dt: float) -> void:
	if _bg_img != null:
		var m := get_viewport().get_mouse_position()
		var off := Vector2((m.x - 640.0) / 640.0, (m.y - 360.0) / 360.0) * Vector2(-14, -6)
		_bg_img.position = _bg_img.position.lerp(_bg_base + off, 0.08)


func _build_background() -> void:
	var key: String = UIK.ACT_KEY[G.act - 1]
	var t := UIK.tex("res://assets/bg/%s.webp" % key)
	var f: Array = FLOOR[key]
	var col := ColorRect.new()
	col.color = Color(f[2])
	UIK.full_rect(col)
	add_child(col)
	if t != null:
		var r := TextureRect.new()
		r.texture = t
		r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		r.stretch_mode = TextureRect.STRETCH_SCALE
		var w: float = 1280.0 * f[0]
		var h: float = w * t.get_height() / t.get_width()
		r.size = Vector2(w, h)
		r.position = Vector2((1280.0 - w) / 2.0, f[1])
		r.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(r)
		_bg_img = r
		_bg_base = r.position
	var sh := UIK.shade(0.0, 0.0)
	sh.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0)], [0.55, Color(0, 0, 0, 0)], [0.9, Color(Color(f[2]), 1.0)]])
	add_child(sh)
	var amb := UIK.embers([Color("#8fe8e0"), Color("#d8ff7a"), Color("#ffc65a")][G.act - 1], 26)
	amb.position = Vector2(640, 520)
	amb.emission_rect_extents = Vector2(660, 140)
	amb.lifetime = 12.0
	amb.preprocess = 12.0
	amb.initial_velocity_min = 8.0
	amb.initial_velocity_max = 28.0
	amb.direction = Vector2(0.3, -1)
	amb.spread = 60.0
	amb.scale_amount_min = 0.3
	amb.scale_amount_max = 0.9
	add_child(amb)


func _build_player() -> void:
	var m: Dictionary = DB.characters[G.char]
	var h_px: float = roundf(300.0 * float(m.get("combatScale", 1.0)))
	sprite = MuseSprite.new(G.char, h_px)
	sprite.preload_all()
	player_box = Control.new()
	player_box.position = Vector2(90, 0)
	player_box.size = Vector2(340, 450)
	player_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	arena.add_child(player_box)
	sprite.position = Vector2((340.0 - sprite.size.x) / 2.0, 360.0 - h_px)
	player_box.add_child(sprite)
	var bx := (340.0 - 230.0) / 2.0
	player_hp = HpBar.new(230, 18)
	player_hp.position = Vector2(bx, 364)
	player_box.add_child(player_hp)
	player_block = Panel.new()
	player_block.size = Vector2(38, 38)
	player_block.position = Vector2(bx - 16, 354)
	player_block.add_theme_stylebox_override("panel", EnemyView._block_style())
	player_block.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_block_lbl = UIK.label("", 19, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	player_block_lbl.size = Vector2(38, 38)
	player_block_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIK.outlined(player_block_lbl, 4)
	player_block.add_child(player_block_lbl)
	player_block.visible = false
	player_box.add_child(player_block)
	player_status = HFlowContainer.new()
	player_status.position = Vector2(40, 386)
	player_status.size = Vector2(260, 34)
	player_status.alignment = FlowContainer.ALIGNMENT_CENTER
	player_status.add_theme_constant_override("h_separation", 4)
	player_status.add_theme_constant_override("v_separation", 3)
	player_status.mouse_filter = Control.MOUSE_FILTER_IGNORE
	player_box.add_child(player_status)
	# Osty (Claudia)
	osty_box = Control.new()
	osty_box.position = Vector2(370, 110)
	osty_box.size = Vector2(90, 150)
	osty_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	osty_box.visible = G.char == "claudia"
	arena.add_child(osty_box)
	osty_img = TextureRect.new()
	osty_img.texture = UIK.tex("res://assets/enemies/osty.webp")
	osty_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	osty_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	osty_img.size = Vector2(84, 84)
	osty_img.position = Vector2(3, 0)
	osty_img.mouse_filter = Control.MOUSE_FILTER_PASS
	osty_box.add_child(osty_img)
	var ot := osty_img.create_tween().set_loops()
	ot.tween_property(osty_img, "position:y", -10.0, 1.1).set_trans(Tween.TRANS_SINE)
	ot.tween_property(osty_img, "position:y", 0.0, 1.1).set_trans(Tween.TRANS_SINE)
	osty_hp = HpBar.new(90, 14)
	osty_hp.font_size = 11
	osty_hp.fill_top = Color("#c79cff")
	osty_hp.fill_bot = Color("#6a35c8")
	osty_hp.position = Vector2(0, 92)
	osty_box.add_child(osty_hp)
	osty_pow = UIK.label("", 14, Color("#e3d1ff"), "bold", HORIZONTAL_ALIGNMENT_CENTER)
	osty_pow.position = Vector2(-10, 110)
	osty_pow.size = Vector2(110, 20)
	UIK.outlined(osty_pow, 4)
	osty_box.add_child(osty_pow)
	UIK.tip(osty_img, func(): return "[b][color=#f0cf7a]Osty[/color][/b]\n%s\nPV %d/%d · Poder %d" % [DB.glos["Osty"], C.osty.hp, C.osty.max, C.osty.pow] if C.has("osty") and C.osty != null else "")
	# orbes (Selene)
	orb_bar = HBoxContainer.new()
	orb_bar.position = Vector2(70, 46)
	orb_bar.add_theme_constant_override("separation", 6)
	orb_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orb_bar.visible = G.char == "selene"
	arena.add_child(orb_bar)


func _build_hud() -> void:
	# energía (arriba del mazo, izquierda)
	energy_panel = Panel.new()
	energy_panel.position = Vector2(22, 512)
	energy_panel.size = Vector2(96, 96)
	energy_panel.add_theme_stylebox_override("panel", UIK.stylebox(Color("#e08a1b"), Color("#fff3c4"), 4, 48, 18))
	energy_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	energy_lbl = UIK.label("3/3", 38, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	energy_lbl.size = Vector2(96, 96)
	energy_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIK.outlined(energy_lbl, 6)
	energy_panel.add_child(energy_lbl)
	energy_panel.pivot_offset = Vector2(48, 48)
	ui_layer.add_child(energy_panel)
	# mazo de robo: esquina inferior izquierda
	draw_btn = _pile_btn("deck", 88, "[b][color=#f0cf7a]Mazo de robo[/color][/b]\nClic para verlo (en orden aleatorio).")
	draw_btn.position = Vector2(14, 618)
	draw_btn.pressed.connect(func():
		var arr: Array = C.draw.duplicate()
		arr.sort_custom(func(a, b): return a.id < b.id)
		Dlg.view_cards("Mazo de robo (en orden aleatorio)", arr, C))
	ui_layer.add_child(draw_btn)
	# descarte: esquina inferior derecha (aquí vuelan las cartas jugadas)
	discard_btn = _pile_btn("discard", 88, "[b][color=#f0cf7a]Descarte[/color][/b]\nLas cartas que juegas vuelan aquí. Clic para verlas.")
	discard_btn.position = Vector2(1178, 618)
	discard_btn.pressed.connect(func(): Dlg.view_cards("Pila de descarte", C.discard, C))
	ui_layer.add_child(discard_btn)
	exhaust_btn = _pile_btn("exhaust", 60, "[b][color=#f0cf7a]Agotadas[/color][/b]\nSalen del combate. Clic para verlas.")
	exhaust_btn.position = Vector2(1206, 548)
	exhaust_btn.pressed.connect(func(): Dlg.view_cards("Cartas agotadas", C.exhaust, C))
	ui_layer.add_child(exhaust_btn)
	end_btn = Button.new()
	end_btn.text = "Terminar turno"
	end_btn.position = Vector2(1050, 480)
	end_btn.custom_minimum_size = Vector2(220, 54)
	end_btn.size = Vector2(220, 54)
	end_btn.add_theme_font_override("font", UIK.font("title"))
	end_btn.add_theme_font_size_override("font_size", 19)
	end_btn.add_theme_color_override("font_color", Color("#f4efe0"))
	end_btn.add_theme_color_override("font_hover_color", Color.WHITE)
	end_btn.add_theme_color_override("font_disabled_color", Color("#7a8c90"))
	var en := UIK.stylebox(Color("#1c3a44"), Color("#6aa0a8"), 3, 12, 8)
	var eh := UIK.stylebox(Color("#27505c"), Color("#b6e4ea"), 3, 12, 12)
	var ed := UIK.stylebox(Color("#141f24"), Color("#33474d"), 3, 12, 0)
	end_btn.add_theme_stylebox_override("normal", en)
	end_btn.add_theme_stylebox_override("hover", eh)
	end_btn.add_theme_stylebox_override("pressed", eh)
	end_btn.add_theme_stylebox_override("focus", eh)
	end_btn.add_theme_stylebox_override("disabled", ed)
	end_btn.pivot_offset = Vector2(110, 27)
	end_btn.pressed.connect(func(): Sfx.play("click"); _end_turn())
	ui_layer.add_child(end_btn)
	tipbar = UIK.label("", 18, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	tipbar.position = Vector2(240, 62)
	tipbar.size = Vector2(800, 34)
	UIK.outlined(tipbar, 6)
	ui_layer.add_child(tipbar)


## Icono de pila (mazo/descarte/agotadas) con insignia de cantidad.
func _pile_btn(icon_id: String, size: float, tip_text: String) -> Button:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(size, size)
	b.size = Vector2(size, size)
	b.pivot_offset = Vector2(size, size) / 2.0
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "disabled", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	var frame := Icons.frame("ui", icon_id, size, Color("#c9a24a"), false, 2)
	b.add_child(frame)
	var badge := Panel.new()
	badge.add_theme_stylebox_override("panel", UIK.stylebox(Color("#b3202e"), Color("#ffd2d6"), 2, 14, 4))
	badge.size = Vector2(34, 28)
	badge.position = Vector2(size - 26, size - 22)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var l := UIK.label("0", 18, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_CENTER)
	l.size = badge.size
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	UIK.outlined(l, 4)
	badge.add_child(l)
	b.add_child(badge)
	b.set_meta("count", l)
	b.mouse_entered.connect(func(): b.create_tween().tween_property(b, "scale", Vector2(1.12, 1.12), 0.1))
	b.mouse_exited.connect(func(): b.create_tween().tween_property(b, "scale", Vector2.ONE, 0.1))
	UIK.tip(b, tip_text)
	return b


func _set_count(b: Button, n: int) -> void:
	var l: Label = b.get_meta("count")
	if l.text != str(n):
		l.text = str(n)
		if is_inside_tree():
			var tw := b.create_tween()
			b.scale = Vector2(1.18, 1.18)
			tw.tween_property(b, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


# ============================== utilidades ==============================
func _living() -> Array:
	return Eng.living(C)


func _sleep(secs: float) -> void:
	await UIK.sleep(self, secs)


func _enemy_view(e) -> EnemyView:
	var v = enemy_views.get(e.uid)
	return v if v != null and is_instance_valid(v) else null


func _player_center() -> Vector2:
	return arena.global_position + player_box.position + sprite.position + sprite.size * Vector2(0.5, 0.35)


func _popup(pos: Vector2, text: String, kind: String) -> void:
	var colors := {"dmg": Color.WHITE, "hurt": Color("#ff4d5a"), "blk": Color("#8ccbff"), "heal": Color("#7ef0a0"), "txt": UIK.GOLD}
	var size := {"dmg": 44, "hurt": 44, "blk": 36, "heal": 44, "txt": 28}
	var fs: int = size[kind]
	if kind == "dmg":
		fs = clampi(36 + int(text.to_int() * -0.7), 36, 72)
	var l := UIK.label(text, fs, colors[kind], "bold", HORIZONTAL_ALIGNMENT_CENTER)
	l.size = Vector2(300, 60)
	UIK.outlined(l, 8, Color("#c1121f") if kind == "dmg" else Color.BLACK)
	l.pivot_offset = Vector2(150, 30)
	l.position = pos - Vector2(150, 30) + Vector2(randf_range(-14, 14), 0)
	l.modulate.a = 0.0
	l.scale = Vector2(0.6, 0.6)
	fx_layer.add_child(l)
	var delay := _pop_n * 0.14
	_pop_n += 1
	_reset_pop_n.call_deferred()
	var tw := l.create_tween()
	tw.tween_interval(delay)
	tw.tween_property(l, "modulate:a", 1.0, 0.08)
	tw.parallel().tween_property(l, "scale", Vector2(1.25, 1.25), 0.15).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "position:y", l.position.y - 24, 0.15)
	tw.tween_property(l, "scale", Vector2.ONE, 0.12)
	tw.tween_property(l, "position:y", l.position.y - 84, 0.8).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.25)
	tw.tween_callback(l.queue_free)


func _reset_pop_n() -> void:
	_pop_n = 0


func _burst(pos: Vector2, color: Color = Color("#ffd98a"), count: int = 24, rise: bool = false) -> void:
	var p := UIK.embers(color, count)
	p.position = pos
	p.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 14.0
	p.direction = Vector2(0, -1)
	p.spread = 25.0 if rise else 180.0
	p.initial_velocity_min = 60.0 if rise else 80.0
	p.initial_velocity_max = 160.0 if rise else 220.0
	p.lifetime = 0.9
	p.preprocess = 0.0
	p.one_shot = true
	p.explosiveness = 0.9
	p.gravity = Vector2(0, -40) if rise else Vector2(0, 260)
	p.scale_amount_min = 0.5
	p.scale_amount_max = 1.2
	fx_layer.add_child(p)
	p.emitting = true
	get_tree().create_timer(1.2).timeout.connect(p.queue_free)


func _banner(text: String, red: bool = false) -> void:
	var b := UIK.label(text, 64, Color("#ff7078") if red else UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	b.size = Vector2(1280, 90)
	b.position = Vector2(0, 190)
	b.pivot_offset = Vector2(640, 45)
	UIK.outlined(b, 12)
	b.modulate.a = 0.0
	b.scale = Vector2(0.6, 0.6)
	fx_layer.add_child(b)
	var tw := b.create_tween()
	tw.tween_property(b, "modulate:a", 1.0, 0.2)
	tw.parallel().tween_property(b, "scale", Vector2(1.1, 1.1), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(b, "scale", Vector2.ONE, 0.1)
	tw.tween_interval(0.7)
	tw.tween_property(b, "modulate:a", 0.0, 0.3)
	tw.parallel().tween_property(b, "scale", Vector2(1.2, 1.2), 0.3)
	tw.tween_callback(b.queue_free)


func _screen_shake(strength: float = 8.0, dur: float = 0.25) -> void:
	if _shake_tw and _shake_tw.is_valid():
		_shake_tw.kill()
	arena.position = ARENA_POS
	_shake_tw = create_tween()
	var n := 6
	for i in n:
		var k := 1.0 - float(i) / n
		_shake_tw.tween_property(arena, "position", ARENA_POS + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * k, dur / n)
	_shake_tw.tween_property(arena, "position", ARENA_POS, 0.03)


static var test_mode := false


func _hit_stop(secs: float) -> void:
	if test_mode:
		return
	Engine.time_scale = 0.06
	get_tree().create_timer(secs, true, false, true).timeout.connect(func(): Engine.time_scale = 1.0)


func _exit_tree() -> void:
	if not test_mode:
		Engine.time_scale = 1.0


# ============================== eventos del motor ==============================
func _fx(type: String, d: Dictionary) -> void:
	if C.is_empty():
		return
	match type:
		"enemyHit":
			var ev := _enemy_view(d.e)
			if ev == null:
				return
			if d.get("poison", false):
				_popup(ev.body_center(), "-%d" % d.amt, "heal")
				_burst(ev.body_center(), Color("#7ed957"), 10, true)
				Sfx.play("poison")
			elif d.amt > 0:
				_popup(ev.body_center(), "-%d" % d.amt, "dmg")
				ev.flash_hit()
				if not d.get("thorns", false):
					_slash(ev.body_center(), d.amt >= 15)
				Sfx.play("bigHit" if d.amt >= 15 else "hit")
				if d.amt >= 15:
					_screen_shake(6.0 + minf(d.amt, 40) * 0.15, 0.3)
					_hit_stop(0.05)
			elif d.blocked:
				_popup(ev.body_center(), "Bloqueado", "blk")
				Sfx.play("block")
		"playerHit":
			if d.amt > 0:
				_popup(_player_center(), "-%d" % d.amt, "hurt")
				Sfx.play("hurt")
				if sprite and not d.get("direct", false):
					sprite.play("hurt")
				_player_shake()
				_flash_screen()
			elif d.blocked:
				_popup(_player_center(), "Bloqueado", "blk")
				Sfx.play("block")
			if d.get("ostyAbs", 0):
				_popup(osty_box.global_position + Vector2(45, 40), "-%d" % d.ostyAbs, "hurt")
		"block":
			_popup(_player_center(), "+%d" % d.n, "blk")
			_burst(_player_center(), Color("#8ccbff"), 18, true)
			Sfx.play("block")
		"enemyBlock":
			var ev2 := _enemy_view(d.e)
			if ev2:
				_popup(ev2.body_center(), "+%d" % d.n, "blk")
		"heal":
			_popup(_player_center(), "+%d" % d.n, "heal")
			_burst(_player_center(), Color("#7ef0a0"), 16, true)
			Sfx.play("heal")
		"enemyHeal":
			var ev3 := _enemy_view(d.e)
			if ev3:
				_popup(ev3.body_center(), "+%d" % d.n, "heal")
		"ostyHeal":
			_popup(osty_box.global_position + Vector2(45, 40), "+%d" % d.n, "heal")
		"maxhp":
			_popup(_player_center(), "+%d PV máx." % d.n, "heal")
		"status":
			if not DB.st.has(d.k):
				return
			var is_p: bool = is_same(d.who, C.pl)
			var pos: Vector2 = _player_center() if is_p else (_enemy_view(d.who).body_center() if _enemy_view(d.who) else Vector2(900, 400))
			_popup(pos + Vector2(0, -50), "%s%d %s" % ["+" if d.n > 0 else "", d.n, Eng.st_name(d.k)], "txt")
			var good: bool = Eng.st_neg(d.k, d.n) == false
			_burst(pos, Color("#ffe08a") if good else Color("#b07cff"), 14, true)
			Sfx.play("buff" if Eng.st_neg(d.k, d.n) == is_p else "debuff")
		"enemyDie":
			var ev4 := _enemy_view(d.e)
			if ev4:
				ev4.die()
				_burst(ev4.body_center())
			Sfx.play("die")
		"enemySpawn":
			Sfx.play("buff")
		"reshuffle":
			Main.I.toast("Se baraja tu descarte…")
		"ostyAttack":
			Sfx.play("hit")
		"orbChannel":
			Sfx.play("buff")
			_update_orbs()
		"orbEvoke":
			Sfx.play("hit")
			_update_orbs()
		"orbTick":
			_update_orbs()
		"replay":
			_popup(_player_center() + Vector2(0, -50), "REPETIR ×2", "txt")
			Sfx.play("buff")
		"ostyDown":
			Main.I.toast("Osty está caído: volverá solo al inicio de tu próximo turno.")
			Sfx.play("error")
		"ostyRevive":
			_popup(osty_box.global_position + Vector2(45, 40), "Osty regresa", "heal")
			Sfx.play("heal")
		"handFull":
			Main.I.toast("Tu mano está llena.")


func _lunge_player(target) -> void:
	if DB.sprites[G.char].get("dash", {}).has("attack"):
		return   # las musas con "dash" ya se desplazan solas
	var base := player_box.position.x
	var dx := 70.0
	var tw := player_box.create_tween()
	tw.tween_property(player_box, "position:x", base + dx, 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.1)
	tw.tween_property(player_box, "position:x", base, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)


func _slash(pos: Vector2, heavy: bool) -> void:
	var l := Line2D.new()
	var len := 90.0 if not heavy else 150.0
	var ang := deg_to_rad(randf_range(-55, -35))
	var d := Vector2(cos(ang), sin(ang)) * len
	l.points = PackedVector2Array([pos - d, pos + d])
	l.width = 4.0
	l.default_color = Color(1, 1, 1, 0.95)
	l.begin_cap_mode = Line2D.LINE_CAP_ROUND
	l.end_cap_mode = Line2D.LINE_CAP_ROUND
	var gr := Gradient.new()
	gr.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	l.gradient = gr
	fx_layer.add_child(l)
	var tw := l.create_tween()
	tw.tween_property(l, "width", 16.0 if heavy else 10.0, 0.06)
	tw.tween_property(l, "width", 0.0, 0.14)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.14)
	tw.tween_callback(l.queue_free)


func _player_shake() -> void:
	var base := player_box.position.x
	var tw := player_box.create_tween()
	tw.tween_property(player_box, "position:x", base - 12, 0.04)
	tw.tween_property(player_box, "position:x", base + 10, 0.06)
	tw.tween_property(player_box, "position:x", base - 6, 0.06)
	tw.tween_property(player_box, "position:x", base, 0.06)
	_screen_shake(5.0, 0.25)


func _flash_screen() -> void:
	var f := ColorRect.new()
	f.color = Color(1, 0.1, 0.15, 0.32)
	UIK.full_rect(f)
	f.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(f)
	var tw := f.create_tween()
	tw.tween_property(f, "color:a", 0.0, 0.3)
	tw.tween_callback(f.queue_free)


# ============================== render ==============================
func _render_all(first: bool = false) -> void:
	if C.is_empty():
		return
	_update_player()
	_update_enemies(first)
	_update_osty()
	_update_orbs()
	_update_hud()
	_sync_hand()
	Main.I.update_top()
	_update_tip()


func _update_player() -> void:
	player_hp.set_values(G.hp, G.maxHp)
	player_block.visible = C.pl.block > 0
	player_block_lbl.text = str(C.pl.block)
	for c in player_status.get_children():
		c.queue_free()
	for k in C.pl.status.keys():
		var v: int = C.pl.status[k]
		if v != 0 and DB.st.has(k):
			player_status.add_child(EnemyView.status_chip(k, v))
	var low: bool = float(G.hp) / G.maxHp <= 0.3 and G.hp > 0
	vignette.visible = low


func _update_osty() -> void:
	if C.osty == null:
		return
	var o: Dictionary = C.osty
	osty_hp.set_values(o.hp, o.max)
	osty_pow.text = ("Poder %d" % o.pow) if o.hp > 0 else "Caído · vuelve en tu turno"
	osty_img.modulate = Color.WHITE if o.hp > 0 else Color(0.35, 0.35, 0.35)


func _update_orbs() -> void:
	if C.is_empty() or not orb_bar.visible:
		return
	for c in orb_bar.get_children():
		c.queue_free()
	var colors := {"ola": Color("#1c5fa8"), "bruma": Color("#6c8aa8"), "abismo": Color("#0a1030"), "perla": Color("#d9d2c3")}
	for i in C.orbMax:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(44, 44)
		if i >= C.orbs.size():
			p.add_theme_stylebox_override("panel", UIK.stylebox(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.2), 2, 22, 0))
		else:
			var o: Dictionary = C.orbs[i]
			var sb := UIK.stylebox(colors[o.t], Color.WHITE if i == 0 else Color(1, 1, 1, 0.4), 2, 22, 8)
			sb.shadow_color = Color(colors[o.t].lightened(0.4), 0.6)
			p.add_theme_stylebox_override("panel", sb)
			p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
			var ic := Icons.rect("orb", o.t, 44)
			p.add_child(ic)
			var val: int = o.v if o.t == "abismo" else Eng.orb_passive(C, o)
			var vl := UIK.label(str(val), 13, Color.WHITE, "bold")
			vl.position = Vector2(30, 28)
			UIK.outlined(vl, 4)
			p.add_child(vl)
			var oo: Dictionary = o
			UIK.tip(p, func(): return "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [DB.orb[oo.t].n, Eng.orb_desc(C, oo)])
			var tw := p.create_tween().set_loops()
			tw.tween_property(p, "position:y", -6.0, 1.2 + i * 0.15).set_trans(Tween.TRANS_SINE)
			tw.tween_property(p, "position:y", 0.0, 1.2 + i * 0.15).set_trans(Tween.TRANS_SINE)
		orb_bar.add_child(p)


func _update_enemies(first: bool) -> void:
	var n := 0
	for e in C.enemies:
		var v := _enemy_view(e)
		if e.hp > 0 or (v != null and not v.dying):
			n += 1
	var k := 0.6 if n >= 5 else (0.72 if n == 4 else (0.88 if n == 3 else 1.05))
	var created := false
	for e in C.enemies:
		var v := _enemy_view(e)
		if v == null:
			v = EnemyView.new()
			v.setup(e, k)
			v.clicked.connect(_on_enemy_click)
			enemies_layer.add_child(v)
			enemy_views[e.uid] = v
			created = true
			if not first:
				v.spawn_in.call_deferred()
		v.refresh(C)
		var ok: bool = pending != null and e.hp > 0
		v.set_target_ok(ok)
	_layout_enemies()


func _layout_enemies() -> void:
	var vis := []
	for e in C.enemies:
		var v := _enemy_view(e)
		if v != null and not (e.hp <= 0 and v.dying and not v.visible):
			vis.append(v)
	var n := vis.size()
	if n == 0:
		return
	var slot := 750.0 / n
	for i in n:
		var v: EnemyView = vis[i]
		var cx := 500.0 + (i + 0.5) * slot
		v.position = Vector2(cx - v.size.x / 2.0, 420.0 - v.size.y)


func _update_hud() -> void:
	if C.is_empty():
		return
	var etxt := "%d/%d" % [C.energy, C.maxEnergy]
	if energy_lbl.text != etxt:
		var tw := energy_panel.create_tween()
		energy_panel.scale = Vector2(1.18, 1.18)
		tw.tween_property(energy_panel, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	energy_lbl.text = etxt
	energy_panel.modulate = Color(0.55, 0.55, 0.55) if C.energy == 0 else Color.WHITE
	_set_count(draw_btn, C.draw.size())
	_set_count(discard_btn, C.discard.size())
	_set_count(exhaust_btn, C.exhaust.size())
	exhaust_btn.visible = C.exhaust.size() > 0
	end_btn.text = "Terminar turno  %d" % C.turn
	var any_playable := false
	for c in C.hand:
		if Eng.can_play(C, c).ok:
			any_playable = true
			break
	end_btn.disabled = busy or C.over != ""
	var glow: bool = not any_playable and not busy and C.over == ""
	if glow and not end_btn.has_meta("glow_tw"):
		var tw := end_btn.create_tween().set_loops()
		tw.tween_property(end_btn, "modulate", Color(1.4, 1.3, 0.9), 0.55)
		tw.tween_property(end_btn, "modulate", Color.WHITE, 0.55)
		end_btn.set_meta("glow_tw", tw)
	elif not glow and end_btn.has_meta("glow_tw"):
		(end_btn.get_meta("glow_tw") as Tween).kill()
		end_btn.remove_meta("glow_tw")
		end_btn.modulate = Color.WHITE


func _update_tip() -> void:
	if tipbar == null:
		return
	var t := ""
	if C.is_empty() or C.over != "" or busy:
		t = ""
	elif pending != null:
		t = "Elige un enemigo para la poción (Esc para cancelar)" if pending.kind == "potion" else "Elige un enemigo: clic, o ←/→ y Enter (Esc para cancelar)"
	elif sel_uid >= 0:
		t = "Haz clic otra vez en la carta para jugarla (Enter)" if Meta.settings.confirm else ""
	else:
		t = "Elige una carta de tu mano o arrástrala · cuesta energía"
	tipbar.text = t
	tipbar.visible = t != ""


# ============================== mano ==============================
func _sync_hand() -> void:
	if C.is_empty():
		return
	# retira las que ya no están
	var live := {}
	for c in C.hand:
		live[c.uid] = true
	for uid in card_views.keys():
		if not live.has(uid):
			var v: CardView = card_views[uid]
			card_views.erase(uid)
			if is_instance_valid(v):
				_discard_anim(v)
	if sel_uid >= 0 and not live.has(sel_uid):
		sel_uid = -1
		pending = null if (pending != null and pending.kind == "card") else pending
	# crea nuevas
	var idx := 0
	for inst in C.hand:
		var v: CardView = card_views.get(inst.uid)
		if v == null:
			v = CardView.create(inst, C, CARD_W)
			v.num_key = idx + 1 if idx < 9 else 0
			v.pressed.connect(_on_card_press)
			v.hovered.connect(_on_card_hover)
			hand_layer.add_child(v)
			card_views[inst.uid] = v
			Sfx.play("select_soft", 0.6)
			v.position = Vector2(70, 600)
			v.scale = Vector2(0.4, 0.4)
			v.rotation = deg_to_rad(-30)
			v.modulate.a = 0.0
			seen[inst.uid] = true
		else:
			v.num_key = idx + 1 if idx < 9 else 0
			v.refresh(C)
		var d := Eng.card_def(inst)
		var can: bool = Eng.can_play(C, inst).ok
		var unaff: bool = not Eng.is_x(d.cost) and Eng.eff_cost(C, d) > C.energy and d.cost >= 0
		v.set_state(can, not unaff)
		v.set_selected(sel_uid == inst.uid)
		idx += 1
	_layout_hand(true)


func _discard_anim(v: CardView) -> void:
	if v == _drag_view:
		_drag_view = null
	var tw := v.create_tween().set_parallel(true)
	var dest := discard_btn.position + discard_btn.size / 2.0 - v.size / 2.0
	tw.tween_property(v, "position", dest, 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(v, "scale", Vector2(0.18, 0.18), 0.28)
	tw.tween_property(v, "modulate:a", 0.0, 0.28)
	tw.chain().tween_callback(v.queue_free)


func _card_target(i: int, n: int, v: CardView) -> Dictionary:
	var off := i - (n - 1) / 2.0
	var step := 0.0
	if n > 1:
		step = minf(CARD_W - 6.0, (HAND_W - CARD_W) / (n - 1))
	var cx := HAND_CX + off * step
	var cy := 720.0 - 6.0 - CARD_H / 2.0 + absf(off) * absf(off) * 1.3
	var rot := deg_to_rad(off * 2.2)
	var scale_v := 1.0
	var z := i
	var hot: bool = v.inst.uid == hover_uid or v.inst.uid == sel_uid
	if hot:
		cy -= 78.0
		rot = 0.0
		scale_v = 1.32
		z = 60
	return {"pos": Vector2(cx, cy) - v.size / 2.0, "rot": rot, "scale": scale_v, "z": z}


func _layout_hand(animate: bool) -> void:
	if C.is_empty():
		return
	var n: int = C.hand.size()
	for i in n:
		var v: CardView = card_views.get(C.hand[i].uid)
		if v == null or v == _drag_view:
			continue
		var t := _card_target(i, n, v)
		v.z_index = t.z
		if v.has_meta("lay_tw"):
			var old = v.get_meta("lay_tw")
			if old is Tween and old.is_valid():
				old.kill()
		var delay := 0.0
		if v.modulate.a < 1.0:
			delay = float(i) * 0.06
		var tw := v.create_tween().set_parallel(true)
		tw.tween_property(v, "position", t.pos, 0.2 if animate else 0.01).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "rotation", t.rot, 0.2 if animate else 0.01).set_delay(delay)
		tw.tween_property(v, "scale", Vector2(t.scale, t.scale), 0.2 if animate else 0.01).set_delay(delay)
		tw.tween_property(v, "modulate:a", 1.0, 0.15).set_delay(delay)
		v.set_meta("lay_tw", tw)


func _on_card_hover(v: CardView, on: bool) -> void:
	if C.is_empty() or not is_instance_valid(v):
		return
	if busy and not on:
		pass
	if _dragging:
		return
	var uid: int = v.inst.uid
	if on:
		hover_uid = uid
		Sfx.play("select_soft", 0.5)
	elif hover_uid == uid:
		hover_uid = -1
	_layout_hand(true)


# ============================== entrada ==============================
func _on_card_press(v: CardView) -> void:
	if busy or C.is_empty() or C.over != "":
		return
	_press_card = v
	_press_pos = get_viewport().get_mouse_position()
	_dragging = false


func _input(ev: InputEvent) -> void:
	if C.is_empty() or Main.I.overlay_host.get_child_count() > 0:
		return
	if ev is InputEventMouseMotion and _press_card != null:
		var mp := get_viewport().get_mouse_position()
		if not _dragging and _press_pos.distance_to(mp) > 14.0 and is_instance_valid(_press_card):
			_begin_drag(_press_card)
		if _dragging and _drag_view != null:
			_drag_view.position = mp - _drag_view.size / 2.0
			var tgt = _enemy_at(mp)
			_highlight_target(tgt)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT and not ev.pressed:
		if _press_card != null:
			var pc := _press_card
			_press_card = null
			if _dragging:
				_end_drag()
			elif is_instance_valid(pc):
				_on_card_click(pc.inst)
	elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
		if _dragging:
			_cancel_drag()
		else:
			_cancel_sel()


func _begin_drag(v: CardView) -> void:
	var can := Eng.can_play(C, v.inst)
	if not can.ok:
		return
	_cancel_sel()
	_dragging = true
	_drag_view = v
	hover_uid = -1
	v.z_index = 200
	v.rotation = 0.0
	v.scale = Vector2(1.15, 1.15)
	if v.has_meta("lay_tw"):
		var old = v.get_meta("lay_tw")
		if old is Tween and old.is_valid():
			old.kill()
	Sfx.play("select")
	var d := Eng.card_def(v.inst)
	if Eng.needs_target(d) and _living().size() > 1:
		for e in _living():
			var ev := _enemy_view(e)
			if ev:
				ev.set_target_ok(true)


func _enemy_at(p: Vector2) -> Variant:
	for e in _living():
		var v := _enemy_view(e)
		if v == null:
			continue
		var r := Rect2(v.body.global_position - Vector2(10, 10), v.body.size + Vector2(20, 20))
		if r.has_point(p):
			return e
	return null


func _highlight_target(e) -> void:
	for x in _living():
		var v := _enemy_view(x)
		if v:
			v.set_target_cur(e != null and is_same(x, e))


func _cancel_drag() -> void:
	if C.is_empty():
		return
	_dragging = false
	_press_card = null
	_drag_view = null
	_highlight_target(null)
	for e in C.enemies:
		var v := _enemy_view(e)
		if v:
			v.set_target_ok(pending != null and e.hp > 0)
	_layout_hand(true)


func _end_drag() -> void:
	if C.is_empty():
		return
	var v := _drag_view
	var mp := get_viewport().get_mouse_position()
	_dragging = false
	_drag_view = null
	_highlight_target(null)
	if v == null or not is_instance_valid(v):
		return
	var inst: Dictionary = v.inst
	var d := Eng.card_def(inst)
	var lv := _living()
	var needs := Eng.needs_target(d)
	var over_play: bool = mp.y < 470.0
	if needs and lv.size() > 1:
		var tgt = _enemy_at(mp)
		if tgt != null:
			for e in C.enemies:
				var ev := _enemy_view(e)
				if ev:
					ev.set_target_ok(false)
			_play_now(inst, tgt)
			return
		if over_play:
			_layout_hand(true)
			_start_targeting({"kind": "card", "uid": inst.uid})
			sel_uid = inst.uid
			_sync_sel_visual()
			return
	elif over_play:
		_play_now(inst, null)
		return
	for e in C.enemies:
		var ev2 := _enemy_view(e)
		if ev2:
			ev2.set_target_ok(pending != null and e.hp > 0)
	_layout_hand(true)


func _sync_sel_visual() -> void:
	for uid in card_views.keys():
		var v: CardView = card_views[uid]
		if is_instance_valid(v):
			v.set_selected(uid == sel_uid)
	_layout_hand(true)


func _cancel_sel() -> void:
	if C.is_empty():
		return
	pending = null
	sel_uid = -1
	for uid in card_views.keys():
		var v: CardView = card_views[uid]
		if is_instance_valid(v):
			v.set_selected(false)
	for e in C.enemies:
		var ev := _enemy_view(e)
		if ev:
			ev.set_target_ok(false)
			ev.set_target_cur(false)
	_layout_hand(true)
	_update_tip()
	target_line.queue_redraw()


func _start_targeting(p: Dictionary) -> void:
	pending = p
	t_idx = 0
	for e in C.enemies:
		var ev := _enemy_view(e)
		if ev:
			ev.set_target_ok(e.hp > 0)
	_hi_target()
	_update_tip()


func _hi_target() -> void:
	for e in C.enemies:
		var ev := _enemy_view(e)
		if ev:
			ev.set_target_cur(false)
	if pending == null:
		return
	var lv := _living()
	if lv.is_empty():
		return
	var ev2 := _enemy_view(lv[t_idx % lv.size()])
	if ev2:
		ev2.set_target_cur(true)


func _on_card_click(inst: Dictionary) -> void:
	if busy or C.is_empty() or C.over != "":
		return
	var ok := Eng.can_play(C, inst)
	if not ok.ok:
		Sfx.play("error")
		Main.I.toast(ok.why)
		return
	var d := Eng.card_def(inst)
	var need_t := Eng.needs_target(d) and _living().size() > 1
	if sel_uid == inst.uid and pending == null:
		if need_t:
			_start_targeting({"kind": "card", "uid": inst.uid})
		else:
			_play_now(inst, null)
		return
	_cancel_sel()
	sel_uid = inst.uid
	Sfx.play("select")
	_sync_sel_visual()
	if need_t:
		_start_targeting({"kind": "card", "uid": inst.uid})
	elif not Meta.settings.confirm:
		_play_now(inst, null)
	else:
		_update_tip()


func _on_enemy_click(v: EnemyView) -> void:
	if C.is_empty() or busy or v.e.hp <= 0:
		return
	if pending == null:
		return
	var p: Dictionary = pending
	pending = null
	if p.kind == "card":
		var inst = null
		for c in C.hand:
			if c.uid == p.uid:
				inst = c
				break
		_cancel_sel()
		if inst != null:
			_play_now(inst, v.e)
	else:
		_cancel_sel()
		_use_potion_now(p.slot, v.e)


func _on_potion(slot: int) -> void:
	if Main.I.current != "combat" or C.is_empty() or busy or C.over != "":
		Main.I.toast("Solo puedes usar pociones en combate.")
		return
	var id = G.potions[slot]
	if id == null:
		return
	var p: Dictionary = DB.potions[id]
	_cancel_sel()
	if p.get("target", false) and _living().size() > 1:
		_start_targeting({"kind": "potion", "slot": slot})
	else:
		_use_potion_now(slot, _living()[0])


func _use_potion_now(slot: int, target) -> void:
	busy = true
	Sfx.play("potion")
	Eng.use_potion(C, slot, target)
	_render_all()
	await _sleep(0.35)
	if await _check_end():
		return
	busy = false
	_render_all()


func _unhandled_key_input(ev: InputEvent) -> void:
	if C.is_empty() or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if Main.I.overlay_host.get_child_count() > 0 or busy or C.over != "":
		return
	var lv := _living()
	var k: int = ev.keycode
	if k >= KEY_1 and k <= KEY_9:
		var idx := k - KEY_1
		if idx < C.hand.size():
			_on_card_click(C.hand[idx])
		get_viewport().set_input_as_handled()
		return
	if pending != null and k in [KEY_RIGHT, KEY_LEFT, KEY_UP, KEY_DOWN, KEY_TAB]:
		if lv.is_empty():
			return
		t_idx = (t_idx + (1 if k in [KEY_RIGHT, KEY_DOWN, KEY_TAB] else -1) + lv.size() * 4) % lv.size()
		_hi_target()
		Sfx.play("select")
		Main.I.toast("Objetivo: " + lv[t_idx].name)
		get_viewport().set_input_as_handled()
		return
	if k == KEY_RIGHT or k == KEY_LEFT:
		var i := -1
		for j in C.hand.size():
			if C.hand[j].uid == sel_uid:
				i = j
		var j2 := mini(C.hand.size() - 1, i + 1) if k == KEY_RIGHT else maxi(0, 0 if i < 0 else i - 1)
		var inst = C.hand[0 if i < 0 else j2] if not C.hand.is_empty() else null
		if inst != null:
			_cancel_sel()
			sel_uid = inst.uid
			Sfx.play("select")
			_sync_sel_visual()
			_update_tip()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_UP or k == KEY_DOWN or k == KEY_TAB:
		if not lv.is_empty():
			t_idx = (t_idx + (-1 if k == KEY_UP else 1) + lv.size() * 4) % lv.size()
			_hi_target()
			Sfx.play("select")
			Main.I.toast("Objetivo: " + lv[t_idx].name)
		get_viewport().set_input_as_handled()
		return
	if k == KEY_ENTER or k == KEY_KP_ENTER or k == KEY_SPACE:
		var inst2 = null
		for c in C.hand:
			if c.uid == sel_uid:
				inst2 = c
		if inst2 == null:
			return
		if not Eng.can_play(C, inst2).ok:
			Sfx.play("error")
			return
		var d := Eng.card_def(inst2)
		var need_t := Eng.needs_target(d) and lv.size() > 1
		if need_t and pending == null:
			_start_targeting({"kind": "card", "uid": inst2.uid})
			get_viewport().set_input_as_handled()
			return
		var t = lv[t_idx % lv.size()] if Eng.needs_target(d) else null
		_cancel_sel()
		_play_now(inst2, t)
		get_viewport().set_input_as_handled()
		return
	if k == KEY_E:
		_end_turn()


# ============================== flujo de turno ==============================
func _anim_for(d: Dictionary) -> String:
	var f: Dictionary = d.fx
	if d.type == "attack" or f.get("ostyHit", 0):
		var big: bool = f.get("dmg", 0) * f.get("hits", 1) >= 14 or (not Eng.is_x(d.cost) and d.cost >= 2) or f.get("x", false)
		return "attack_heavy" if big else "attack"
	return "cast"


func _fly_ghost(uid: int, target = null) -> void:
	var v: CardView = card_views.get(uid)
	if v == null or not is_instance_valid(v):
		return
	var g := CardView.create(v.inst, C, CARD_W, false)
	g.position = v.position
	g.rotation = v.rotation
	g.scale = v.scale
	g.mouse_filter = Control.MOUSE_FILTER_IGNORE
	g.z_index = 250
	fx_layer.add_child(g)
	var mid := Vector2(640, 300)
	if target != null and _enemy_view(target) != null:
		mid = _enemy_view(target).body_center()
	var d := Eng.card_def(v.inst)
	var dest := discard_btn.position + discard_btn.size / 2.0
	var vanish := false
	if d.type == "power":
		vanish = true
	elif d.flags.get("exhaust", false):
		dest = exhaust_btn.position + exhaust_btn.size / 2.0
	var tw := g.create_tween()
	# 1) hacia el objetivo mientras se resuelve el efecto
	tw.tween_property(g, "position", mid - g.size / 2.0, 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(g, "scale", Vector2(0.85, 0.85), 0.28)
	tw.parallel().tween_property(g, "rotation", 0.0, 0.28)
	tw.tween_interval(0.1)
	# 2) a la pila de descarte (o se desvanece si es un poder)
	if vanish:
		tw.tween_property(g, "modulate:a", 0.0, 0.3)
		tw.parallel().tween_property(g, "scale", Vector2(1.15, 1.15), 0.3)
	else:
		tw.tween_property(g, "position", dest - g.size / 2.0, 0.34).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(g, "scale", Vector2(0.18, 0.18), 0.34)
		tw.parallel().tween_property(g, "rotation", deg_to_rad(25), 0.34)
	tw.tween_callback(g.queue_free)
	# la carta real desaparece al instante
	v.visible = false


func _play_now(inst: Dictionary, target) -> void:
	if busy:
		return
	busy = true
	var d := Eng.card_def(inst)
	_cancel_sel()
	_fly_ghost(inst.uid, target)
	Sfx.play("card")
	if d.type == "attack":
		_lunge_player(target)
	sprite.play(_anim_for(d))
	if d.type == "attack" or d.fx.get("ostyHit", 0):
		await _sleep(0.26 if (not Eng.is_x(d.cost) and d.cost >= 2) else 0.18)
	if not Eng.play_card(C, inst.uid, target):
		busy = false
		var v: CardView = card_views.get(inst.uid)
		if v:
			v.visible = true
		_render_all()
		return
	if d.fx.has("pw") or d.type == "power":
		Sfx.play("buff")
	if d.fx.has("add") and d.fx.add.id == "lia_shiv":
		Sfx.play("buff")
	_render_all()
	await _sleep(0.26)
	if C.prompt != null:
		await _handle_prompt()
	if await _check_end():
		return
	busy = false
	_render_all()


func _handle_prompt() -> void:
	var p: Dictionary = C.prompt
	var title := ("Descarta %d carta%s" if p.kind == "discard" else "Agota %d carta%s") % [p.n, "s" if p.n > 1 else ""]
	var sel: Array = await Dlg.pick_cards({"title": title, "sub": "Las cartas agotadas salen del combate." if p.kind == "exhaust" else "Elige de tu mano.", "cards": C.hand.duplicate(), "n": p.n, "C": C})
	var uids := []
	for c in sel:
		uids.append(c.uid)
	Eng.resolve_prompt(C, uids, p)
	_render_all()


func _end_turn() -> void:
	if C.is_empty() or busy or C.over != "" or C.prompt != null:
		return
	_cancel_sel()
	busy = true
	Sfx.play("end")
	Eng.end_player_turn(C)
	_render_all()
	if await _check_end():
		return
	await _sleep(0.45)
	for e in C.enemies.duplicate():
		if C.is_empty():
			return
		if e.hp <= 0 or C.over != "":
			continue
		var ev := _enemy_view(e)
		var it: Dictionary = e.intent
		var atk: bool = it.get("dmg", 0) > 0
		if ev:
			if atk:
				ev.act_attack()
			else:
				ev.act_buff()
		await _sleep(0.28 if atk else 0.2)
		Eng.run_enemy_turn(C, e)
		_render_all()
		await _sleep((it.get("hits", 1) * 0.26 + 0.28) if atk else 0.38)
		if C.over != "":
			break
	if C.is_empty():
		return
	if await _check_end():
		return
	Eng.end_round(C)
	Eng.start_turn(C)
	_render_all()
	if await _check_end():   # p. ej. una Ola de Marea Alta puede matar al último enemigo al empezar el turno
		return
	busy = false
	_render_all()
	_banner("Tu turno")


func _check_end() -> bool:
	if C.is_empty() or C.over == "" or over:
		return C.is_empty() == false and C.over != ""
	over = true
	busy = true
	_render_all()
	if C.over == "win":
		Sfx.play("win")
		_banner("¡Victoria!")
		await _sleep(1.1)
		_finish_win()
	else:
		Sfx.play("lose")
		sprite.play("die")
		await _sleep(2.3)
		Nav.game_over()
	return true


func _finish_win() -> void:
	for id in G.relics:
		Relics.run(id, "onCombatEnd", G)
	G.stats.fights += 1
	var t := tier
	C = {}
	Main.I.on_potion = Callable()
	if t == "boss" and G.act >= 3:
		Nav.victory()   # el jefe final cierra el juego: sin oro, carta ni reliquia
		return
	Nav.reward(Eng.combat_reward(G, t), t)


# ============================== flecha de objetivo ==============================
class TargetLine extends Control:
	var screen

	func _process(_dt: float) -> void:
		if screen != null and screen.pending != null:
			queue_redraw()

	func _draw() -> void:
		if screen == null or screen.pending == null or screen.pending.kind != "card":
			return
		var v = screen.card_views.get(screen.pending.uid)
		if v == null or not is_instance_valid(v):
			return
		var a: Vector2 = v.position + v.size / 2.0 + Vector2(0, -v.size.y * 0.5)
		var b := get_viewport().get_mouse_position()
		var mid := (a + b) / 2.0 + Vector2(0, -90)
		var pts := PackedVector2Array()
		for i in 21:
			var t := i / 20.0
			pts.append(a.lerp(mid, t).lerp(mid.lerp(b, t), t))
		draw_polyline(pts, Color(0, 0, 0, 0.6), 10.0, true)
		draw_polyline(pts, UIK.GOLD, 5.0, true)
		var dir := (pts[20] - pts[18]).normalized()
		var n := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([b, b - dir * 26 + n * 14, b - dir * 26 - n * 14]), UIK.GOLD)
