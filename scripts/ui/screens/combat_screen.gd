class_name CombatScreen
extends Control
## Pantalla de combate: arena, mano de cartas, objetivos, animaciones y flujo de turnos.

const HAND_CX := 635.0
const HAND_W := 970.0
const CARD_W := 168.0
const CARD_H := 238.56
const ARENA_POS := Vector2(0, 52)
const NEW_PER_FRAME := 2       # cartas nuevas que se construyen por frame (evita tirones de la mano)
const BIG_HIT := 15            # daño a partir del cual un golpe es «grande» (hitstop, sacudida, sonido)
const POP_GAP := 0.13           # separación mínima entre números flotantes sobre el mismo objetivo
const POP_FAN := [Vector2(0, 0), Vector2(-66, -26), Vector2(66, -18), Vector2(-36, -60), Vector2(40, -56), Vector2(0, -88)]
const POP_MAX := 14             # cifras simultáneas en pantalla (antes: sin tope; Irene llenaba el lienzo)
const POP_POOL := 26            # etiquetas recicladas que se conservan para el combate
const FX_CAP := 120             # nodos máximos en fx_layer (números + partículas + trazos + bandas)
const BURST_MAX := 18           # emisiones de partículas simultáneas (cada CPUParticles2D cuesta CPU por partícula)
const HALO_TEX := 16
const POP_W := 300.0            # caja de la etiqueta (pivote y abanico se calculan sobre ella)
const POP_H := 80.0
const POP_OUTLINE := 8          # grosor del halo alrededor de la cifra
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
var undo_btn: Button
var incoming_lbl: RichTextLabel
var tipbar: Label
var vignette: TextureRect
var target_line: TargetLine
var lethal_box: PanelContainer
var turn_tint: TextureRect

static var HALO: ImageTexture    # halo radial compartido (partículas y contorno de las cifras)
static var fx_cap_override := 0  # solo para sondas de rendimiento: 0 = usar FX_CAP


var _lethal := false
var _pop_slots := {}            # objetivo -> {ids: Array, t: float}: números vivos y momento del último
var _pop_free: Array[Label] = []
var _pop_live := 0
var _pop_seq := 0
var _banner_tex := {}           # texturas del rótulo de turno (banda y filos): antes, un gradiente nuevo por rótulo
var _chains: Array = []         # números flotantes en vuelo: {"l","key","id","t","y0","punch"}
var _burst_live := 0            # emisiones de partículas encendidas (tope BURST_MAX)
var _fx_cap := FX_CAP
var _running := false           # hay algo animándose que pide fotogramas (si no, _process se apaga)
var _stop_until := 0            # ms hasta el que dura el hitstop actual
var _hold_until := 0            # ms hasta los que el reloj del combate debe seguir corriendo (acción en curso)


var _press_card: CardView = null
var _press_pos := Vector2.ZERO
var _dragging := false
var _drag_view: CardView = null
var _sync_pending := false      # queda mano por crear: se reparte entre frames
var _sync_waiting := false
var _pop_n := 0
var _shake_tw: Tween
var _flash: ColorRect
var _flash_tw: Tween
var _undo := {}               # modo fácil: estado antes de la última carta jugada


func _ready() -> void:
	G = Meta.run
	_fx_cap = fx_cap_override if fx_cap_override > 0 else FX_CAP
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
	turn_tint = TextureRect.new()
	turn_tint.texture = UIK.grad_tex([[0.0, Color(0.32, 0.0, 0.05, 0.55)], [0.3, Color(0.2, 0.0, 0.03, 0.0)], [0.7, Color(0.2, 0.0, 0.03, 0.0)], [1.0, Color(0.32, 0.0, 0.05, 0.6)]])
	turn_tint.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	turn_tint.stretch_mode = TextureRect.STRETCH_SCALE
	UIK.full_rect(turn_tint)
	turn_tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	turn_tint.modulate.a = 0.0
	add_child(turn_tint)
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
	_running = true
	if C.over != "":
		_check_end()


func cleanup() -> void:
	C = {}
	Main.I.on_potion = Callable()


## Todos los efectos de la pantalla pasan por aquí: es el punto único donde se ajusta el sonido del combate.
func _play_sfx(name: String, vol_scale: float = 1.0) -> void:
	Sfx.play(name, vol_scale)


func on_escape() -> void:
	if sel_uid >= 0 or pending != null:
		_cancel_sel()
	else:
		Dlg.pause_menu()


# ============================== construcción ==============================
var _bg_img: TextureRect
var _bg_base := Vector2.ZERO


## Parallax del fondo y, sobre todo, el reloj de las cadenas de números flotantes.
## Se apaga solo cuando no hay nada que mover (combate en reposo sin FX): no hay que recorrer
## la escena entera con un _process por fotograma cuando la musa está quieta en idle.
func _process(_dt: float) -> void:
	if _bg_img != null and not Juice.calm():
		var m := get_viewport().get_mouse_position()
		var off := Vector2((m.x - 640.0) / 640.0, (m.y - 360.0) / 360.0) * Vector2(-14, -6)
		var target := _bg_base + off
		if _bg_img.position.distance_squared_to(target) > 0.01:   # ya asentado: no tocar (permite bajo consumo)
			_bg_img.position = _bg_img.position.lerp(target, 0.08)
		else:
			_bg_img.position = target
	_hit_stop_expired()
	for it in _chains.duplicate():
		_step_chain(it)
	if _chains.is_empty() and _pop_live == 0 and _stop_until == 0 and Time.get_ticks_msec() >= _hold_until:
		set_process(false)


## Vuelve a encender el reloj del combate (lo llaman los popups y los hitstops).
func _wake() -> void:
	if _running and not is_processing():
		set_process(true)


## El combate está jugando ahora mismo (el usuario lanzó una carta, terminó el turno, murió…):
## deja el reloj encendido para que las cadenas de cifras abandonen en el momento justo su hueco del
## escalonado (con el reloj dormido, la siguiente cifra sobre el mismo objetivo no se cortaría).
func _hold_process(secs: float) -> void:
	if not _running:
		return
	_hold_until = maxi(_hold_until, Time.get_ticks_msec() + int(secs * 1000.0))
	_wake()


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
	if Juice.calm():
		return
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
	incoming_lbl = UIK.rich("", 17, Color.WHITE, "bold")
	incoming_lbl.fit_content = false
	incoming_lbl.position = Vector2(10, 328)
	incoming_lbl.size = Vector2(320, 30)
	incoming_lbl.mouse_filter = Control.MOUSE_FILTER_PASS
	incoming_lbl.add_theme_constant_override("outline_size", 6)
	incoming_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	UIK.tip(incoming_lbl, func(): return _incoming_tip())
	player_box.add_child(incoming_lbl)
	lethal_box = PanelContainer.new()
	var lsb := UIK.stylebox(Color("#5a0812", 0.92), Color("#ff6a74"), 2, 12, 12)
	lsb.shadow_color = Color("#ff2a3a", 0.55)
	lsb.content_margin_left = 10; lsb.content_margin_right = 12; lsb.content_margin_top = 2; lsb.content_margin_bottom = 2
	lethal_box.add_theme_stylebox_override("panel", lsb)
	var lrow := Icons.with_text("ui", "heart_broken", "MUERTE SEGURA", 24, 17, Color.WHITE)
	lrow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	lethal_box.add_child(lrow)
	lethal_box.set_meta("lbl", lrow)
	lethal_box.visible = false
	UIK.tip(lethal_box, func(): return _lethal_tip())
	player_box.add_child(lethal_box)
	var ltw := lethal_box.create_tween().set_loops()
	ltw.tween_property(lethal_box, "modulate", Color(1.35, 1.15, 1.15), 0.45).set_trans(Tween.TRANS_SINE)
	ltw.tween_property(lethal_box, "modulate", Color(0.85, 0.85, 0.85), 0.45).set_trans(Tween.TRANS_SINE)
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
	end_btn.text = "Terminar turno (Y)"
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
	end_btn.pressed.connect(func():
		_play_sfx("click")
		_end_turn())
	ui_layer.add_child(end_btn)
	undo_btn = UIK.button("↶ Deshacer (Z)", "small")
	undo_btn.position = Vector2(1090, 441)
	undo_btn.focus_mode = Control.FOCUS_NONE
	undo_btn.visible = false
	undo_btn.pressed.connect(undo)
	UIK.tip(undo_btn, "[b][color=#f0cf7a]Deshacer[/color][/b]\nModo fácil: devuelve la última carta jugada a tu mano, como si no la hubieras jugado.\nNo se puede si murió algún enemigo.")
	ui_layer.add_child(undo_btn)
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


## Número flotante. Los que caen sobre el mismo objetivo en ráfaga se escalonan en tiempo y posición (abanico).
## Las etiquetas y sus AtlasTexture de halo se reciclan (antes: una etiqueta + textura de halo nuevas por cifra),
## la cadena se anima desde el _process del combate y el conjunto tiene tope (POP_MAX) por objetivo y en pantalla.
func _popup(pos: Vector2, text: String, kind: String) -> void:
	var colors := {"dmg": Color.WHITE, "hurt": Color("#ff4d5a"), "blk": Color("#8ccbff"), "heal": Color("#7ef0a0"), "poison": Color("#b6f05a"), "txt": UIK.GOLD}
	var size := {"dmg": 44, "hurt": 44, "blk": 36, "heal": 44, "poison": 40, "txt": 28}
	var fs: int = size[kind]
	if kind == "dmg" or kind == "hurt":
		fs = clampi(36 + int(absi(text.to_int()) * 0.7), 36, 72)
	# escalonado por objetivo: cada número espera POP_GAP al anterior y ocupa otra posición del abanico
	var now := Time.get_ticks_msec() / 1000.0
	var key := "%d:%d" % [roundi(pos.x / 80.0), roundi(pos.y / 80.0)]
	var s: Dictionary = _pop_slots.get(key, {"ids": [], "t": -999.0})
	if now > s.t + 0.45:
		s.ids.clear()
	var idx: int = s.ids.size()
	s.ids.append(0)
	s.t = now + POP_GAP
	_pop_slots[key] = s
	if _pop_live >= POP_MAX or fx_layer.get_child_count() >= _fx_cap:
		return
	_pop_seq += 1
	s.ids[idx] = _pop_seq
	var off: Vector2 = POP_FAN[idx % POP_FAN.size()] + Vector2(0, -16.0 * floorf(idx / float(POP_FAN.size())))
	var l := _pop_take()
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", colors[kind])
	l.text = text
	l.position = pos - Vector2(POP_W, POP_H) * 0.5 + off
	l.modulate.a = 0.0
	l.rotation = deg_to_rad(randf_range(-6.0, 6.0)) if kind in ["dmg", "hurt"] else 0.0
	l.scale = Vector2(0.5, 0.5) if not Juice.calm() else Vector2.ONE
	l.visible = true
	_pop_live += 1
	var chain := {"l": l, "key": key, "id": _pop_seq, "t": now, "y0": l.position.y, "punch": 1.45 if fs >= 56 else 1.25}
	_chains.append(chain)
	_wake()


func _burst(pos: Vector2, color: Color = Color("#ffd98a"), count: int = 24, rise: bool = false) -> void:
	if Juice.calm() or fx_layer.get_child_count() >= _fx_cap or _burst_live >= BURST_MAX:
		return

	_burst_live += 1
	var p := UIK.embers(color, count)
	p.texture = halo_tex()   # UIK.embers fabrica una Image 16x16 + ImageTexture por cada emisión
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
	p.finished.connect(func():
		_burst_live = maxi(0, _burst_live - 1)
		p.queue_free())


## Etiqueta del número flotante: reuse del reciclaje o una nueva (con su halo ya cacheado a nivel de clase).
func _pop_take() -> Label:
	var l: Label = _pop_free.pop_back() if not _pop_free.is_empty() else null
	if l == null or not is_instance_valid(l):
		var pl := PopLabel.new()
		pl.pivot_offset = Vector2(POP_W, POP_H) * 0.5
		l = pl
		fx_layer.add_child(l)
	l.visible = true
	return l


## Un número terminó su vuelo: vuelve al reciclaje (sin liberar nodo ni cambiar de AtlasTexture).
func _pop_release(l: Label) -> void:
	if not is_instance_valid(l):
		return
	l.visible = false
	_pop_live = maxi(0, _pop_live - 1)
	if _pop_free.size() < POP_POOL:
		_pop_free.append(l)
	else:
		l.queue_free()


## Avanza un número flotante (sustituye al Tween por etiqueta: sin TweenProperty ni LambdaTweener
## por cifra, que en las ráfagas de Irene eran decenas por turno).
func _step_chain(it: Dictionary) -> void:
	var l: Label = it.l
	if not is_instance_valid(l):
		_chains.erase(it)
		return
	# e = tiempo hasta el arranque (negativo mientras espera su turno en el escalonado)
	var e: float = it.t - Time.get_ticks_msec() / 1000.0
	var te := -e   # segundos de vuelo
	if Juice.calm():
		l.modulate.a = 1.0 if te < 0.1 else clampf(1.0 - (te - 0.1) / 0.4, 0.0, 1.0)
		l.position.y = it.y0
		l.scale = Vector2.ONE
	elif te <= 0.0:
		l.modulate.a = clampf((te + 0.06) / 0.06, 0.0, 1.0)
		l.position.y = it.y0
		l.scale = Vector2(0.5, 0.5)
	elif te < 0.26:
		var k: float = te / 0.26
		l.modulate.a = 1.0
		l.position.y = it.y0 - 24.0 * minf(1.0, k * 2.0)
		var p := lerpf(0.5, it.punch, clampf(k * 2.0, 0.0, 1.0))
		if k > 0.5:
			p = lerpf(it.punch, 1.0, (k - 0.5) * 2.0)
		l.scale = Vector2(p, p)
	else:
		var k2 := clampf((te - 0.26) / 0.8, 0.0, 1.0)
		l.position.y = it.y0 - 24.0 - 84.0 * (1.0 - pow(1.0 - k2, 3.0))
		l.scale = Vector2.ONE
		l.modulate.a = 1.0 - clampf(maxf(0.0, te - 0.25) / 0.8, 0.0, 1.0)
	if te > (1.1 if not Juice.calm() else 0.5):
		_chains.erase(it)
		_pop_release(l)
		var slot = _pop_slots.get(it.key)
		if slot != null:
			(slot.ids as Array).erase(it.id)


## Textura del halo (partículas y contorno de las cifras): una sola para todo el combate. Antes UIK.embers
## fabricaba una Image 16x16 + ImageTexture por cada ráfaga y UIK.outlined re-rasterizaba cada cifra.
static func halo_tex() -> ImageTexture:
	if HALO == null:
		var px := PackedByteArray()
		px.resize(HALO_TEX * HALO_TEX * 4)
		for y in HALO_TEX:
			for x in HALO_TEX:
				var d := Vector2(x - (HALO_TEX - 1) * 0.5, y - (HALO_TEX - 1) * 0.5).length() / (HALO_TEX * 0.5)
				var a := int(roundf(pow(clampf(1.0 - d, 0.0, 1.0), 1.5) * 255.0))
				var o := (y * HALO_TEX + x) * 4
				px[o] = 255; px[o + 1] = 255; px[o + 2] = 255; px[o + 3] = a
		var img := Image.create_from_data(HALO_TEX, HALO_TEX, false, Image.FORMAT_RGBA8, px)
		HALO = ImageTexture.create_from_image(img)
	return HALO


## Rótulo de turno: banda oscura con filos de color que se abre, texto que entra y subtítulo opcional.
func _banner(text: String, red: bool = false, sub: String = "", hold: float = 0.7) -> void:
	var accent := Color("#ff7078") if red else UIK.GOLD
	var band_col := Color("#2a0610", 0.86) if red else Color("#0c161d", 0.84)
	var h := Control.new()
	h.size = Vector2(1280, 130)
	h.position = Vector2(0, 168)
	h.pivot_offset = Vector2(640, 65)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fx_layer.add_child(h)
	var band := TextureRect.new()
	var bk := "band_r" if red else "band_g"
	if not _banner_tex.has(bk):
		_banner_tex[bk] = UIK.grad_tex([[0.0, Color(band_col, 0.0)], [0.22, band_col], [0.78, band_col], [1.0, Color(band_col, 0.0)]], true)
	band.texture = _banner_tex[bk]
	band.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	band.stretch_mode = TextureRect.STRETCH_SCALE
	band.size = Vector2(1280, 130)
	band.pivot_offset = Vector2(640, 65)
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(band)
	for y in [6.0, 122.0]:
		var edge := TextureRect.new()
		var ek := "edge_r" if red else "edge_g"
		if not _banner_tex.has(ek):
			_banner_tex[ek] = UIK.grad_tex([[0.0, Color(accent, 0.0)], [0.5, accent], [1.0, Color(accent, 0.0)]], true)
		edge.texture = _banner_tex[ek]
		edge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		edge.stretch_mode = TextureRect.STRETCH_SCALE
		edge.size = Vector2(900, 2)
		edge.position = Vector2(190, y)
		edge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		band.add_child(edge)
	var b := UIK.label(text, 60, accent, "title", HORIZONTAL_ALIGNMENT_CENTER)
	b.size = Vector2(1280, 86)
	b.position = Vector2(0, 8 if sub != "" else 20)
	b.pivot_offset = Vector2(640, 43)
	UIK.outlined(b, 12)
	h.add_child(b)
	if sub != "":
		var sl := UIK.label(sub, 20, Color("#e9e2f5"), "bold", HORIZONTAL_ALIGNMENT_CENTER)
		sl.size = Vector2(1280, 28)
		sl.position = Vector2(0, 88)
		UIK.outlined(sl, 5)
		h.add_child(sl)
	h.modulate.a = 0.0
	var tw := h.create_tween()
	if Juice.calm():
		tw.tween_property(h, "modulate:a", 1.0, 0.2)
		tw.tween_interval(hold + 0.15)
		tw.tween_property(h, "modulate:a", 0.0, 0.3)
		tw.tween_callback(h.queue_free)
		return
	band.scale = Vector2(1.0, 0.05)
	b.position.x = -80
	# el rótulo entra creciendo con el TAMAÑO DE FUENTE, no escalando el Control: escalar un Control de
	# 1280 px re-rasteriza su texto cada fotograma (y el de 60 px con contorno de 12 es carísimo)
	_set_banner_fs(81.0, b)
	tw.tween_property(h, "modulate:a", 1.0, 0.12)
	tw.parallel().tween_property(band, "scale", Vector2.ONE, 0.2).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_method(_set_banner_fs.bind(b), 81.0, 60.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(b, "position:x", 0.0, 0.26).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_interval(hold)
	tw.tween_property(h, "modulate:a", 0.0, 0.28)
	tw.parallel().tween_property(b, "position:x", 80.0, 0.28).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(band, "scale", Vector2(1.0, 0.05), 0.28).set_ease(Tween.EASE_IN)
	tw.tween_callback(h.queue_free)


func _set_banner_fs(fs: float, b: Label) -> void:
	if is_instance_valid(b):
		b.add_theme_font_size_override("font_size", roundi(fs))


func _screen_shake(strength: float = 8.0, dur: float = 0.25) -> void:
	if Juice.calm():
		return
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


## Congela la acción unos milisegundos (golpes grandes, muertes). Varias seguidas se encadenan sin cortarse.
## La racha la vigila el reloj propio del combate (en tiempo real, sin un SceneTreeTimer por golpe): así la
## última de la cadena restaura el tiempo justo al vencer y no queda nadie esperando ni conexión pendiente.
func _hit_stop(secs: float) -> void:
	if test_mode or Juice.calm():
		return
	_stop_until = maxi(_stop_until, Time.get_ticks_msec() + int(secs * 1000.0))
	Engine.time_scale = 0.05
	_wake()


## Si la racha de hitstops terminó: tiempo real y cierre (lo llama el _process del combate).
func _hit_stop_expired() -> bool:
	if _stop_until != 0 and Time.get_ticks_msec() >= _stop_until:
		_stop_until = 0
		Engine.time_scale = 1.0
		return true
	return false


func _exit_tree() -> void:
	_running = false
	_stop_until = 0
	_chains.clear()
	if not test_mode:
		Engine.time_scale = 1.0


# ============================== eventos del motor ==============================
func _fx(type: String, d: Dictionary) -> void:
	if type == "relic":   # puede llegar en start_combat (antes de asignar C)
		Main.I.pulse_relic.call_deferred(d.id)
		return
	if C.is_empty():
		return
	match type:
		"bossPhase":   # el jefe entra en fase 2: banda grande + sacudida corta (sin ella en «reducir movimiento»)
			var bv := _enemy_view(d.e)
			var nm: String = str(d.e.get("name", "El jefe"))
			var msg: String = str(d.get("msg", ""))
			_play_sfx("danger")
			_play_sfx("bigHit", 0.6)
			_banner("%s · ¡Fase 2!" % nm, true, msg, 1.2)
			_screen_shake(12.0, 0.3)
			if bv != null:
				bv.flash_hit(0.0, Color(2.4, 0.9, 0.9))
				Juice.ring(self, bv.body_center(), Color("#ff5a5a"), 30.0, 140.0, 0.55, 7.0)
		"enemyHit":
			var ev := _enemy_view(d.e)
			if ev == null:
				return
			if d.get("poison", false):
				_popup(ev.body_center(), "-%d" % d.amt, "poison")
				_burst(ev.body_center(), Color("#7ed957"), 12, true)
				ev.flash_hit(0.0, Color(0.7, 1.7, 0.5))
				_play_sfx("poison")
			elif d.amt > 0:
				var big: bool = d.amt >= BIG_HIT
				_popup(ev.body_center(), "-%d" % d.amt, "dmg")
				ev.flash_hit(1.7 if big else 1.0)
				if not d.get("thorns", false):
					_slash(ev.body_center(), big)
				_play_sfx("bigHit" if big else "hit")
				if d.get("blocked", 0) > 0:
					_play_sfx("blocked", 0.45)
				if big:
					_screen_shake(6.0 + minf(d.amt, 40) * 0.15, 0.3)
					_hit_stop(0.07)
			elif d.blocked:
				_popup(ev.body_center(), "Bloqueado", "blk")
				_ring(ev.body_center(), Color("#8ccbff"), 24.0, 96.0, 0.32, 5.0)
				_play_sfx("blocked")
		"playerHit":
			_hold_process(0.6)   # el reloj sigue despierto mientras duran las cifras de daño
			if d.amt > 0:
				var big: bool = d.amt >= maxi(12, int(G.maxHp * 0.18))
				_popup(_player_center(), "-%d" % d.amt, "hurt")
				_play_sfx("hurt")
				if big:
					_play_sfx("bigHit", 0.7)
				if d.get("blocked", 0) > 0:
					_play_sfx("blocked", 0.45)
				if sprite and not d.get("direct", false):
					sprite.play("hurt")
				_player_flash()
				_player_shake(big)
				_flash_screen(big)
				if big:
					_hit_stop(0.065)
			elif d.blocked:
				_popup(_player_center(), "Bloqueado", "blk")
				_ring(_player_center(), Color("#8ccbff"), 30.0, 120.0, 0.34, 6.0)
				_play_sfx("blocked")
			if d.get("ostyAbs", 0):
				_popup(osty_box.global_position + Vector2(45, 40), "-%d" % d.ostyAbs, "hurt")
		"block":
			_popup(_player_center(), "+%d" % d.n, "blk")
			_burst(_player_center(), Color("#8ccbff"), 18, true)
			_ring(_player_center() + Vector2(0, 40), Color("#8ccbff", 0.8), 40.0, 110.0, 0.4, 4.0)
			_play_sfx("blockUp")
		"enemyBlock":
			var ev2 := _enemy_view(d.e)
			if ev2:
				_popup(ev2.body_center(), "+%d" % d.n, "blk")
				_play_sfx("blockUp", 0.6)
		"heal":
			_popup(_player_center(), "+%d" % d.n, "heal")
			_burst(_player_center(), Color("#7ef0a0"), 16, true)
			_play_sfx("heal")
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
			if d.k == "poison" and d.n > 0:
				_burst(pos, Color("#9be35a"), 16, true)
				_play_sfx("poisonApply")
			else:
				_burst(pos, Color("#ffe08a") if good else Color("#b07cff"), 14, true)
				_play_sfx("buff" if Eng.st_neg(d.k, d.n) == is_p else "debuff")
		"enemyDie":
			var ev4 := _enemy_view(d.e)
			if ev4:
				ev4.die()
				_burst(ev4.body_center())
				_ring(ev4.body_center(), Color("#ffe6a8"), 20.0, 150.0, 0.45, 7.0)
			_play_sfx("die")
			_hit_stop(0.08)
		"enemySpawn":
			_play_sfx("buff")
		"reshuffle":
			Main.I.toast("Se baraja tu descarte…")
		"ostyAttack":
			_play_sfx("hit")
		"orbChannel":
			_play_sfx("orbChannel")
			_update_orbs()
			var pc := _orb_pos(C.orbs.size() - 1)
			_ring(pc, Color("#9fd8ff"), 10.0, 48.0, 0.35, 4.0)
			_burst(pc, Color("#9fd8ff"), 10, true)
		"orbEvoke":
			_play_sfx("orbEvoke")
			var pe := _orb_pos(0)
			_ring(pe, Color("#e8f6ff"), 14.0, 90.0, 0.4, 6.0)
			_burst(pe, Color("#cfe9ff"), 18)
			_update_orbs()
		"orbTick":
			_update_orbs()
		"replay":
			_popup(_player_center() + Vector2(0, -50), "REPETIR ×2", "txt")
			_play_sfx("buff")
		"ostyDown":
			Main.I.toast("Osty está caído: volverá solo al inicio de tu próximo turno.")
			_play_sfx("error")
		"ostyRevive":
			_popup(osty_box.global_position + Vector2(45, 40), "Osty regresa", "heal")
			_play_sfx("heal")
		"handFull":
			Main.I.toast("Tu mano está llena.")
	# las cartas (los números escritos en su texto) se repintan solo cuando algo cambia lo que muestran
	CardView.card_refresh_epoch += 1


## Centro del hueco de orbe i en pantalla (la barra de orbes vive en la arena).
func _orb_pos(i: int) -> Vector2:
	return orb_bar.global_position + Vector2(maxi(0, i) * 50.0 + 22.0, 22.0)


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
	if fx_layer.get_child_count() >= _fx_cap:
		return
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


## Destello rojo-blanco del sprite de la musa al recibir daño (también con movimiento reducido).
func _player_flash() -> void:
	if sprite == null:
		return
	sprite.modulate = Color(2.4, 1.3, 1.3)
	var tw := sprite.create_tween()
	tw.tween_property(sprite, "modulate", Color(1.6, 0.45, 0.45), 0.07)
	tw.tween_property(sprite, "modulate", Color.WHITE, 0.22)


func _player_shake(big: bool = false) -> void:
	if Juice.calm():
		return
	var base := 90.0   # posición de reposo de player_box (no la de mitad de animación)
	var a := 18.0 if big else 12.0
	var tw := player_box.create_tween()
	tw.tween_property(player_box, "position:x", base - a, 0.04)
	tw.tween_property(player_box, "position:x", base + a * 0.8, 0.06)
	tw.tween_property(player_box, "position:x", base - a * 0.5, 0.06)
	tw.tween_property(player_box, "position:x", base, 0.06)
	_screen_shake(9.0 if big else 5.0, 0.3 if big else 0.25)


## Destello rojo de pantalla. Un solo ColorRect reciclado: antes cada golpe encadenado añadía otro a
## fx_layer y los fondos de pantalla completa son lo más caro que se puede apilar en un lienzo 2D.
func _flash_screen(big: bool = false) -> void:
	if _flash == null or not is_instance_valid(_flash):
		_flash = ColorRect.new()
		_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
		UIK.full_rect(_flash)
		_flash.color = Color(1, 0.1, 0.15, 0.0)
		fx_layer.add_child(_flash)
	if _flash_tw and _flash_tw.is_valid():
		_flash_tw.kill()
	_flash.visible = true
	_flash.color.a = (0.42 if big else 0.32) * (0.5 if Juice.calm() else 1.0)
	_flash_tw = _flash.create_tween()
	_flash_tw.tween_property(_flash, "color:a", 0.0, 0.3)
	_flash_tw.tween_callback(func(): if is_instance_valid(_flash): _flash.visible = false)


## Mismo anillo de Juice.ring pero contado contra el tope de fx_layer (los golpes repetidos de Engranaje
## encadenaban anillos sobre un lienzo ya lleno).
func _ring(pos: Vector2, color: Color, r0: float, r1: float, dur: float = 0.35, width: float = 6.0) -> void:
	if fx_layer.get_child_count() >= _fx_cap:
		return
	Juice.ring(fx_layer, pos, color, r0, r1, dur, width)


## Golpe de la carta jugada al llegar a su objetivo: destello, anillo y chispas del color de su tipo.
func _card_impact(pos: Vector2, type: String, heavy: bool) -> void:
	var col: Color = {"attack": Color("#ff9a62"), "skill": Color("#8ccbff"), "power": Color("#ffd36a")}.get(type, UIK.GOLD)
	_ring(pos, col, 30.0, 170.0 if heavy else 110.0, 0.34, 8.0 if heavy else 5.0)
	_burst(pos, col, 22 if heavy else 10)
	if heavy:
		_play_sfx("heavy")
		_screen_shake(5.0, 0.2)


func _is_heavy(d: Dictionary) -> bool:
	return _anim_for(d) == "attack_heavy" or Eng.is_x(d.cost) or d.cost >= 2


## Fin de turno: la mano se apaga y la escena se tiñe mientras actúan los enemigos.
func _enemy_phase_look(on: bool) -> void:
	var t := 0.25
	hand_layer.create_tween().tween_property(hand_layer, "modulate", Color(0.5, 0.48, 0.56) if on else Color.WHITE, t)
	turn_tint.create_tween().tween_property(turn_tint, "modulate:a", 1.0 if on else 0.0, t)


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
	_update_incoming()


## Vista previa: daño total anunciado por los enemigos y cuánto llegaría a tus PV con el Bloqueo actual.
func _update_incoming() -> void:
	if incoming_lbl == null:
		return
	if C.is_empty() or C.over != "" or C.phase != "player":
		incoming_lbl.text = ""
		return
	var inc := Eng.incoming(C)
	if inc.total <= 0:
		incoming_lbl.text = ""
		_set_lethal(false)
		return
	var res: String = "[color=#8bf0a4]todo bloqueado[/color]" if inc.hp <= 0 else "[color=#ff7b85]−%d PV[/color]" % inc.hp
	incoming_lbl.text = "[center]%s %d  ➜  %s[/center]" % [Icons.bb("intent", "attack", 22), inc.total, res]
	_set_lethal(inc.hp >= G.hp and G.hp > 0)


## Muerte segura: el daño anunciado supera PV + Bloqueo (+ Osty). Aviso rojo, viñeta y un latido la primera vez.
func _set_lethal(on: bool) -> void:
	if lethal_box == null:
		return
	if on and not _lethal:
		_play_sfx("danger")
	_lethal = on
	lethal_box.visible = on
	if on:
		var row: Control = lethal_box.get_meta("lbl")
		var pluma: bool = Eng.has_relic(G, "pluma") and not G.get("plumaUsed", false)
		(row.get_child(1) as Label).text = "GOLPE MORTAL · Pluma" if pluma else "MUERTE SEGURA"
		lethal_box.reset_size()
		lethal_box.position = Vector2((340.0 - lethal_box.size.x) / 2.0, 292)
	vignette.visible = on or (float(G.hp) / G.maxHp <= 0.3 and G.hp > 0)


func _lethal_tip() -> String:
	if C.is_empty():
		return ""
	var inc := Eng.incoming(C)
	var osty := (" y Osty (%d)" % inc.osty) if inc.osty > 0 else ""   # antes: el % podía comerse el ternario
	var t := "[b][color=#ff8a94]Muerte segura[/color][/b]\nLos enemigos atacarán por [b]%d[/b]; tu Bloqueo (%d)%s no basta y perderías [b]%d PV[/b] de los [b]%d[/b] que te quedan." % [inc.total, C.pl.block, osty, inc.hp, G.hp]
	if Eng.has_relic(G, "pluma") and not G.get("plumaUsed", false):
		t += "\n[color=#f0cf7a]La Pluma de Fénix te levantaría una vez con el 30 % de tus PV.[/color]"
	t += "\nBloquea, cúrate, debilita o remata al atacante antes de terminar el turno."
	return t


func _incoming_tip() -> String:
	if C.is_empty():
		return ""
	var inc := Eng.incoming(C)
	var t: String = "[b][color=#f0cf7a]Daño entrante[/color][/b]\nSi terminas el turno ahora, los enemigos atacarán por [b]%d[/b] en total." % inc.total
	if C.pl.block > 0:
		t += "\nTu Bloqueo absorbe hasta [b]%d[/b]." % C.pl.block
	if inc.osty > 0:
		t += "\nOsty absorbe [b]%d[/b]." % inc.osty
	t += "\nPerderías [b]%d PV[/b]." % inc.hp
	return t


func _update_osty() -> void:
	if C.osty == null:
		return
	var o: Dictionary = C.osty
	osty_hp.set_values(o.hp, o.max)
	osty_pow.text = ("Poder %d" % o.pow) if o.hp > 0 else "Caído · vuelve en tu turno"
	osty_img.modulate = Color.WHITE if o.hp > 0 else Color(0.35, 0.35, 0.35)


## Recuadros de orbe de Selene. Un panel por hueco, creado una vez; cada repintado solo cambia estilo,
## icono y valor del hueco en lugar de liberar y reconstruir 3-6 paneles (con su estilo, icono, tooltip y
## tween de flotación en bucle) en cada _render_all o tick de orbe.
const ORB_COL := {"ola": "#1c5fa8", "bruma": "#6c8aa8", "abismo": "#0a1030", "perla": "#d9d2c3"}


func _update_orbs() -> void:
	if C.is_empty() or not orb_bar.visible:
		return
	while orb_bar.get_child_count() < C.orbMax:
		orb_bar.add_child(_orb_slot(orb_bar.get_child_count()))
	for i in C.orbMax:
		var p: Panel = orb_bar.get_child(i)
		var has: bool = i < C.orbs.size()
		var t: String = "ola"
		var val := 0
		if has:
			var o: Dictionary = C.orbs[i]
			t = o.t
			val = o.v if o.t == "abismo" else Eng.orb_passive(C, o)
		var cur: Dictionary = p.get_meta("slot", {})
		var empty: bool = cur.get("empty", true)
		var style_changed: bool = cur.get("t", "") != t or empty == has or cur.get("first", false) != (i == 0)
		var val_changed: bool = int(cur.get("v", -1)) != val
		if style_changed:
			if not has:
				p.add_theme_stylebox_override("panel", UIK.stylebox(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.2), 2, 22, 0))
			else:
				var sb := UIK.stylebox(Color(ORB_COL[t]), Color.WHITE if i == 0 else Color(1, 1, 1, 0.4), 2, 22, 8)
				sb.shadow_color = Color(Color(ORB_COL[t]).lightened(0.4), 0.6)
				p.add_theme_stylebox_override("panel", sb)
		var ic: TextureRect = p.get_meta("icon")
		ic.visible = has
		if has and style_changed:
			ic.texture = Icons.tex("orb", t)
		var vl: Label = p.get_meta("val")
		vl.visible = has
		if val_changed or style_changed:
			vl.text = str(val)
		if style_changed or val_changed:
			p.set_meta("slot", {"t": t, "v": val, "empty": not has, "first": i == 0})


## Un hueco de orbe (panel vacío listo para repintarse).
func _orb_slot(i: int) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(44, 44)
	p.add_theme_stylebox_override("panel", UIK.stylebox(Color(0, 0, 0, 0.4), Color(1, 1, 1, 0.2), 2, 22, 0))
	p.clip_children = CanvasItem.CLIP_CHILDREN_AND_DRAW
	var ic := Icons.rect("orb", "ola", 44)
	ic.visible = false
	p.add_child(ic)
	var vl := UIK.label("", 13, Color.WHITE, "bold")
	vl.position = Vector2(30, 28)
	UIK.outlined(vl, 4)
	vl.visible = false
	p.add_child(vl)
	p.set_meta("icon", ic)
	p.set_meta("val", vl)
	p.set_meta("slot", {"t": "", "v": -1, "empty": true, "first": false})
	UIK.tip(p, func(): return _orb_tip(i))
	var tw := p.create_tween().set_loops()
	tw.tween_property(p, "position:y", -6.0, 1.2 + i * 0.15).set_trans(Tween.TRANS_SINE)
	tw.tween_property(p, "position:y", 0.0, 1.2 + i * 0.15).set_trans(Tween.TRANS_SINE)
	return p


func _orb_tip(i: int) -> String:
	if C.is_empty() or i >= C.orbs.size():
		return ""
	var o: Dictionary = C.orbs[i]
	return "[b][color=#f0cf7a]%s[/color][/b]\n%s" % [DB.orb[o.t].n, Eng.orb_desc(C, o)]


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
			var vv := v
			UIK.tip(v.body, func(): return "" if (pending != null or _dragging) else vv.tip_text())
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
	end_btn.text = ("Turno enemigo…" if C.phase == "enemy" and C.over == "" else "Terminar turno  %d" % C.turn)
	var any_playable := false
	for c in C.hand:
		if Eng.can_play(C, c).ok:
			any_playable = true
			break
	end_btn.disabled = busy or C.over != ""
	if undo_btn != null:
		undo_btn.visible = G.easy and not _undo.is_empty() and not busy and Eng.can_restore(C, _undo)
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
		t = "Elige enemigo: Stick / D-Pad y A / Enter (B / Esc cancela)" if pending.kind != "potion" else "Elige enemigo para la poción (B / Esc cancela)"
	elif sel_uid >= 0:
		t = "Pulsa A (o Enter) para jugar · Y: Terminar turno · LB/RB: Cartas" if Meta.settings.confirm else "Y: Terminar turno · LB/RB: Cartas"
	else:
		t = "Elige carta con Stick / D-Pad / LB / RB · A: Seleccionar · Y: Terminar turno · R3: Inspeccionar"
	tipbar.text = t
	tipbar.visible = t != ""


# ============================== mano ==============================
func _sync_hand(at_idle: bool = false) -> void:
	if C.is_empty():
		return
	_sync_pending = false
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
	# crea nuevas (como mucho NEW_PER_FRAME por frame: 10 Cuchillas de golpe daban un tirón)
	var idx := 0
	var created := 0
	for inst in C.hand:
		var v: CardView = card_views.get(inst.uid)
		if v == null:
			if created >= NEW_PER_FRAME:
				_sync_pending = true
				idx += 1
				continue
			v = CardView.create(inst, C, CARD_W)
			v.focus_mode = Control.FOCUS_NONE
			v.num_key = idx + 1 if idx < 9 else 0
			v.pressed.connect(_on_card_press)
			v.hovered.connect(_on_card_hover)
			hand_layer.add_child(v)
			card_views[inst.uid] = v
			_play_sfx("select_soft", 0.6)
			v.position = Vector2(70, 600)
			v.scale = Vector2(0.4, 0.4)
			v.rotation = deg_to_rad(-30)
			v.modulate.a = 0.0
			seen[inst.uid] = true
			created += 1
		elif v.num_key != (idx + 1 if idx < 9 else 0):
			v.num_key = idx + 1 if idx < 9 else 0
			v.refresh(C)
		else:
			v.set_text_once(C)   # solo repinta si cambió lo que se ve (ver CardView.set_text_once)
		var d := Eng.card_def(inst)
		var can: bool = Eng.can_play(C, inst).ok
		var unaff: bool = not Eng.is_x(d.cost) and Eng.eff_cost(C, d) > C.energy and d.cost >= 0
		v.set_state(can, not unaff)
		v.set_selected(sel_uid == inst.uid)
		idx += 1
	if at_idle:
		# Reparto que ya venía de una espera de fotograma (no lo pidió nadie jugando): el alta de una carta
		# no crea tweens de colocación; se coloca directamente y sin volver a diferir (evita el bucle).
		_layout_hand(false)
	else:
		_layout_hand(true)
	if _sync_pending:
		_sync_hand_next_frame()


## Termina de repartir las cartas nuevas en el frame siguiente (sin acumular esperas).
func _sync_hand_next_frame() -> void:
	if _sync_waiting:
		return
	_sync_waiting = true
	await get_tree().process_frame
	_sync_waiting = false
	if is_inside_tree() and not C.is_empty():
		_sync_hand(not is_processing())


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


## Coloca la mano. Cada carta guarda su último destino: si no cambió y ya está en su sitio, no se crea nada
## (crear un Tween de 4 propiedades por carta y por repintado era el coste de fondo de la mano: 3,7 ms cada dos
## fotogramas con Irene, y las cartas ya asentadas se re-encolaban en cada refresco sin moverlas).
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
		var target := Vector4(t.pos.x, t.pos.y, t.rot, t.scale)
		var spawned: bool = v.modulate.a < 1.0
		var fresh: bool = v.get_meta("lay_to", Vector4.INF) != target
		if not animate and not fresh and not spawned:
			continue   # ya está en su sitio (reposicionar sin animar no mueve nada)
		v.set_meta("lay_to", target)
		if v.has_meta("lay_tw"):
			var old = v.get_meta("lay_tw")
			if old is Tween and old.is_valid():
				old.kill()
		var delay := float(i) * 0.06 if spawned else 0.0
		var ttl := 0.2 if animate else 0.01
		if spawned:
			# La carta acaba de entrar (a=0) y su entrada va por su propio tween (crece desde 0.4 abajo).
			# Volver a animar opacity en paralelo la dejaba a medias: el reparto de la mano multiplicado por
			# cada repintado de una jugada de Irene la re-teleportaba al inicio y la desvanecía medio turno
			# (y cada fase combinaba fade + posición/escala/rotación = decenas de nodos de "juice" por carta).
			v.set_meta("lay_to", Vector4.INF)   # la primera colocación animada la hace el alta (abajo)
			continue
		if not animate:
			# sin animación: directo, sin tween
			v.position = t.pos
			v.rotation = t.rot
			v.scale = Vector2(t.scale, t.scale)
			continue
		var tw := v.create_tween().set_parallel(true)
		tw.tween_property(v, "position", t.pos, ttl).set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(v, "rotation", t.rot, ttl).set_delay(delay)
		tw.tween_property(v, "scale", Vector2(t.scale, t.scale), ttl).set_delay(delay)
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
		_play_sfx("select_soft", 0.5)
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
	_play_sfx("select")
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
		_play_sfx("error")
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
	_play_sfx("select")
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
	_undo = {}
	_play_sfx("potion")
	Eng.use_potion(C, slot, target)
	_render_all()
	await _sleep(0.35)
	if await _check_end():
		return
	busy = false
	_render_all()


func cycle_card(dir: int) -> void:
	if C.is_empty() or busy or C.over != "":
		return
	if pending != null:
		cycle_target(dir)
		return
	if C.hand.is_empty():
		return
	var i := -1
	for j in C.hand.size():
		if C.hand[j].uid == sel_uid:
			i = j
	var j2: int
	if i < 0:
		j2 = 0
	else:
		j2 = clampi(i + dir, 0, C.hand.size() - 1)
	var inst = C.hand[j2]
	if inst != null:
		_cancel_sel()
		sel_uid = inst.uid
		_play_sfx("select")
		_sync_sel_visual()
		_update_tip()


func cycle_target(dir: int) -> void:
	var lv := _living()
	if lv.is_empty():
		return
	t_idx = (t_idx + dir + lv.size() * 4) % lv.size()
	_hi_target()
	_play_sfx("select")
	Main.I.toast("Objetivo: " + lv[t_idx].name)


func confirm_action() -> void:
	if C.is_empty() or busy or C.over != "":
		return
	var lv := _living()
	var inst2 = null
	for c in C.hand:
		if c.uid == sel_uid:
			inst2 = c
	if inst2 == null:
		if not C.hand.is_empty():
			sel_uid = C.hand[0].uid
			_play_sfx("select")
			_sync_sel_visual()
			_update_tip()
		return
	if not Eng.can_play(C, inst2).ok:
		_play_sfx("error")
		return
	var d := Eng.card_def(inst2)
	var need_t := Eng.needs_target(d) and lv.size() > 1
	if need_t and pending == null:
		_start_targeting({"kind": "card", "uid": inst2.uid})
		return
	var t = lv[t_idx % lv.size()] if Eng.needs_target(d) else null
	_cancel_sel()
	_play_now(inst2, t)


func use_potion_shortcut() -> void:
	if busy or C.is_empty() or C.over != "" or pending != null:
		return
	var G = Meta.run
	if G == null:
		return
	for i in G.potions.size():
		if G.potions[i] != null:
			_on_potion(i)
			return
	Main.I.toast("No tienes pociones disponibles.")


func handle_gamepad_button(btn: int) -> bool:
	if busy or C.is_empty() or C.over != "":
		return false
	match btn:
		JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_LEFT_SHOULDER:
			cycle_card(-1)
			return true
		JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_RIGHT_SHOULDER:
			cycle_card(1)
			return true
		JOY_BUTTON_DPAD_UP:
			cycle_target(-1)
			return true
		JOY_BUTTON_DPAD_DOWN:
			cycle_target(1)
			return true
		JOY_BUTTON_A:
			confirm_action()
			return true
		JOY_BUTTON_B:
			on_escape()
			return true
		JOY_BUTTON_Y:
			_end_turn()
			return true
		JOY_BUTTON_X:
			draw_btn.pressed.emit()
			return true
	return false


func handle_gamepad_trigger(is_lt: bool) -> bool:
	if is_lt:
		use_potion_shortcut()
		return true
	else:
		discard_btn.pressed.emit()
		return true


## Modo fácil: vuelve al estado anterior a la última carta jugada.
func undo() -> void:
	if C.is_empty() or busy or _undo.is_empty() or not G.easy:
		return
	if not Eng.can_restore(C, _undo):
		_undo = {}
		Main.I.toast("Ya no se puede deshacer esa jugada.")
		_update_hud()
		return
	_cancel_sel()
	Eng.restore(C, _undo)
	_undo = {}
	# las cartas de la mano se vuelven a crear desde el estado restaurado
	for uid in card_views.keys():
		var v: CardView = card_views[uid]
		if is_instance_valid(v):
			v.queue_free()
	card_views.clear()
	_play_sfx("select")
	_render_all()
	Main.I.toast("Jugada deshecha.")


func _potion_key(slot: int) -> void:
	if slot < G.potions.size() and G.potions[slot] != null:
		_on_potion(slot)
	else:
		_play_sfx("error")


func _unhandled_key_input(ev: InputEvent) -> void:
	if C.is_empty() or not (ev is InputEventKey) or not ev.pressed or ev.echo:
		return
	if Main.I.overlay_host.get_child_count() > 0 or busy or C.over != "":
		return
	var k: int = ev.keycode
	if k >= KEY_1 and k <= KEY_9:
		var idx := k - KEY_1
		if idx < C.hand.size():
			_on_card_click(C.hand[idx])
		get_viewport().set_input_as_handled()
		return
	if k == KEY_LEFT:
		cycle_card(-1)
		get_viewport().set_input_as_handled()
		return
	if k == KEY_RIGHT:
		cycle_card(1)
		get_viewport().set_input_as_handled()
		return
	if k in [KEY_UP, KEY_DOWN, KEY_TAB]:
		cycle_target(1 if k in [KEY_DOWN, KEY_TAB] else -1)
		get_viewport().set_input_as_handled()
		return
	if k in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]:
		confirm_action()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_E:
		_end_turn()
		get_viewport().set_input_as_handled()
		return
	var pot_keys := [KEY_Q, KEY_W, KEY_R, KEY_T]
	if k in pot_keys:
		_potion_key(pot_keys.find(k))
		get_viewport().set_input_as_handled()
		return
	if k == KEY_Z:
		undo()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_D:
		draw_btn.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_S:
		discard_btn.pressed.emit()
		get_viewport().set_input_as_handled()
		return
	if k == KEY_X and not C.exhaust.is_empty():
		exhaust_btn.pressed.emit()
		get_viewport().set_input_as_handled()
		return


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
	var heavy := _is_heavy(d)
	var calm := Juice.calm()
	var tw := g.create_tween()
	# 0) se levanta un instante (anticipación)
	if not calm:
		tw.tween_property(g, "scale", v.scale * 1.12, 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	# 1) hacia el objetivo mientras se resuelve el efecto
	tw.tween_property(g, "position", mid - g.size / 2.0, 0.24 if not calm else 0.28).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN if heavy else Tween.EASE_OUT)
	tw.parallel().tween_property(g, "scale", Vector2(0.85, 0.85), 0.24)
	tw.parallel().tween_property(g, "rotation", 0.0, 0.24)
	# 2) slam: golpe de escala + destello del trazo + anillo/chispas del color del tipo
	tw.tween_callback(_card_impact.bind(mid, String(d.type), heavy))
	tw.tween_callback(func(): g.modulate = Color(1.8, 1.7, 1.35))
	if not calm:
		tw.tween_property(g, "scale", Vector2(1.08, 1.08) if heavy else Vector2(0.98, 0.98), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tw.tween_property(g, "scale", Vector2(0.85, 0.85), 0.09)
	tw.parallel().tween_property(g, "modulate", Color.WHITE, 0.16)
	tw.tween_interval(0.06)
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
	_hold_process(2.0)
	_undo = Eng.snapshot(C) if G.easy else {}
	var d := Eng.card_def(inst)
	_cancel_sel()
	_fly_ghost(inst.uid, target)
	_play_sfx("card")
	if d.type == "attack":
		_lunge_player(target)
	sprite.play(_anim_for(d))
	if d.type == "attack" or d.fx.get("ostyHit", 0):
		await _sleep(0.26 if (not Eng.is_x(d.cost) and d.cost >= 2) else 0.18)
	if not Eng.play_card(C, inst.uid, target):
		busy = false
		_undo = {}
		var v: CardView = card_views.get(inst.uid)
		if v:
			v.visible = true
		_render_all()
		return
	if d.fx.has("pw") or d.type == "power":
		_play_sfx("buff")
	if d.fx.has("add") and d.fx.add.id == "lia_shiv":
		_play_sfx("buff")
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
	_hold_process(1.0)
	_undo = {}
	_play_sfx("end")
	Eng.end_player_turn(C)
	_render_all()
	if await _check_end():
		return
	_enemy_phase_look(true)
	_banner("Turno enemigo", true, "", 0.35)
	_play_sfx("enemyTurn")
	await _sleep(0.8)
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
	_enemy_phase_look(false)
	Eng.start_turn(C)
	_render_all()
	if await _check_end():   # p. ej. una Ola de Marea Alta puede matar al último enemigo al empezar el turno
		return
	busy = false
	_render_all()
	_banner("Tu turno", false, "Turno %d" % C.turn)
	_play_sfx("turn")


func _check_end() -> bool:
	if C.is_empty() or C.over == "" or over:
		return C.is_empty() == false and C.over != ""
	over = true
	busy = true
	_render_all()
	if C.over == "win":
		_play_sfx("win")
		_banner("¡Victoria!")
		await _sleep(1.1)
		_finish_win()
	else:
		var names := []
		for e in C.enemies:
			if e.hp > 0 and not (e.name in names):
				names.append(e.name)
		if names.is_empty():
			for e in C.enemies:
				if not (e.name in names):
					names.append(e.name)
		G["deathBy"] = ", ".join(names)
		_set_lethal(false)
		_enemy_phase_look(false)
		_play_sfx("playerDie")
		_player_flash()
		_flash_screen(true)
		_hit_stop(0.08)
		_hold_process(3.0)   # la pantalla de fin se va enseguida: que las cifras terminen su vuelo
		sprite.play("die")
		get_tree().create_timer(0.7).timeout.connect(func():
			if _running:
				_play_sfx("lose"))
		await _sleep(2.3)
		Nav.game_over()
	return true


func _finish_win() -> void:
	for id in G.relics:
		Relics.run(id, "onCombatEnd", G)
	Favors.on_combat_end(G)
	G.stats.fights += 1
	var t := tier
	C = {}
	Main.I.on_potion = Callable()
	if t == "boss" and G.act >= 3:
		Nav.victory()   # el jefe final cierra el juego: sin oro, carta ni reliquia
		return
	Nav.reward(Eng.combat_reward(G, t), t)


## Número flotante: etiqueta de una línea con contorno radial de halo y tamaño de fuente exacto.
## Centrada sobre su pivote (antes: un Label de 300x80 alineado a la izquierda que dejaba la cifra desplazada)
## y con rect mínimo = texto + halo, así cada cambio de tamaño o de texto solo re-rasteriza su propio glifo.
## El contorno es una textura radial de 16x16 compartida en vez del anillo de 8 px de `UIK.outlined`
## (que re-rasterizaba el glifo de 44-72 px en cada etiqueta nueva).
class PopLabel extends Label:
	var _halo_sb := StyleBoxTexture.new()
	var _pad := 2.0     # margen de la textura del contorno: aparte del texto, para que el halo no se recorte

	func _init() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		autowrap_mode = TextServer.AUTOWRAP_OFF
		add_theme_font_override("font", UIK.font("bold"))
		add_theme_font_size_override("font_size", 44)
		add_theme_color_override("font_color", Color.WHITE)
		var sb := _halo_sb
		sb.texture = CombatScreen.halo_tex()
		sb.draw_center = true
		# rectángulo redondeado con el radio del halo: con márgenes verticales 0 el glifo no se estira en vertical
		sb.texture_margin_left = HALO_TEX * 0.5
		sb.texture_margin_right = HALO_TEX * 0.5
		_halo_sb = sb
		add_theme_stylebox_override("outline", sb)

	func _get_minimum_size() -> Vector2:
		var lw := get_theme_font("font").get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, get_theme_font_size("font_size")).x
		return Vector2(lw + _pad * 2.0, get_theme_font("font").get_height(get_theme_font_size("font_size")) + _pad * 2.0)


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
