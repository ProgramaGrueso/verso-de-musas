extends Node
## Bot que juega partidas completas a través de la interfaz real para detectar errores en ejecución.
## Uso: godot --path . res://tests/playthrough.tscn -- <personaje> [partidas] [velocidad]

var main: Control
var char := "zafiro"
var god := false
var nm_level := 0
var easy := false
var fixed_seed := 0
var undos := 0
var runs_left := 1
var finished := 0
var stats := {"combats": 0, "wins": 0, "losses": 0, "events": 0, "shops": 0, "rests": 0}
var t_total := 0.0
var last_sig := ""
var stuck_t := 0.0
var rng := RandomNumberGenerator.new()


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	char = args[0] if args.size() > 0 else "zafiro"
	runs_left = int(args[1]) if args.size() > 1 else 1
	var speed: float = float(args[2]) if args.size() > 2 else 8.0
	god = args.size() > 3 and args[3].begins_with("god")
	nm_level = int(args[4]) if args.size() > 4 else 0
	easy = args.size() > 5 and args[5] == "easy"
	fixed_seed = Eng.seed_from_text(args[6]) if args.size() > 6 else 0
	Engine.time_scale = speed
	CombatScreen.test_mode = true
	Meta.settings.fast = true
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	rng.seed = 99
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.5).timeout
	_start_run()


func _start_run() -> void:
	var G := Eng.new_run(char, {"seed": fixed_seed if fixed_seed != 0 else rng.randi() % 100000 + 1, "nm": nm_level, "easy": easy})
	if god:
		G.maxHp = 4000
		G.hp = 4000
	Meta.run = G
	G.map = RunGen.gen_map_game(G)
	Nav.favor()


var _log_t := 0.0
var _last_ov := 0


func _process(dt: float) -> void:
	t_total += dt
	_log_t += dt
	if _log_t > 5.0 * Engine.time_scale and Meta.run != null:
		_log_t = 0.0
		var G = Meta.run
		print("[%.0fs] pantalla=%s acto=%d piso=%d hp=%d/%d oro=%d mazo=%d" % [t_total, Main.I.current, G.act, G.floor, G.hp, G.maxHp, G.gold, G.deck.size()])
	if main == null or Main.I == null:
		return
	# desbloqueo si se queda atascado
	var sig := "%s|%d|%s" % [Main.I.current, Main.I.overlay_host.get_child_count(), str(Meta.run.hp) if Meta.run else ""]
	if Main.I.current == "combat" and Main.I.screen is CombatScreen and not Main.I.screen.C.is_empty():
		var C = Main.I.screen.C
		sig += "|%d|%d|%d" % [C.turn, C.hand.size(), C.energy]
	if sig == last_sig:
		stuck_t += dt
	else:
		stuck_t = 0.0
		last_sig = sig
	if stuck_t > 12.0 * Engine.time_scale:
		print("ATASCADO en ", sig)
		_dump_and_quit()
		return
	if Main.I.overlay_host.get_child_count() > 0:
		if Main.I.overlay_host.get_child_count() != _last_ov:
			print("  overlay abierto, hijos=", Main.I.overlay_host.get_child_count(), " pantalla=", Main.I.current)
		_last_ov = Main.I.overlay_host.get_child_count()
		_auto_overlay(Main.I.overlay_host.get_child(Main.I.overlay_host.get_child_count() - 1))
		return
	_last_ov = 0
	match Main.I.current:
		"map": _bot_map()
		"combat": _bot_combat()
		"reward": _bot_reward()
		"shop": _bot_leave_shop()
		"rest": _bot_rest()
		"favor": _bot_favor()
		"event": _bot_event()
		"end": _bot_end()
		"ending": _bot_ending()


var _act_cd := 0.0


func _cool(dt_s: float = 0.15) -> bool:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _act_cd:
		return false
	_act_cd = now + dt_s / Engine.time_scale
	return true


func _find(n: Node, cls: String, out: Array) -> void:
	for c in n.get_children():
		if c.get_class() == cls or (cls == "CardView" and c is CardView):
			out.append(c)
		_find(c, cls, out)


func _auto_overlay(o: Node) -> void:
	if not _cool(0.2):
		return
	var cards := []
	_find(o, "CardView", cards)
	var btns := []
	_find(o, "Button", btns)
	var ok_btn: Button = null
	for b in btns:
		if not b.disabled and b.is_visible_in_tree():
			ok_btn = b
			break
	# 1) botón de confirmar habilitado (también la comparación de mejora)
	for b in btns:
		if not b.disabled and (b.text.begins_with("Confirmar") or b.text.begins_with("Tomar") or b.text.begins_with("Mejorar") or b.text.begins_with("Eliminar")):
			b.pressed.emit()
			return
	# 2) hay que elegir cartas
	if not cards.is_empty():
		for c in cards:
			if c.selected:
				if o.has_method("close"):
					o.close([])
				return
		cards[0].pressed.emit(cards[0])
		return
	if ok_btn != null:
		ok_btn.pressed.emit()
	elif o.has_method("close"):
		o.close(null)


func _bot_map() -> void:
	if not _cool(0.4):
		return
	var G = Meta.run
	var av: Array = RunGen.next_nodes(G)
	if av.is_empty():
		print("mapa sin nodos disponibles")
		return
	# prioriza hogueras/tiendas si hay vida baja, si no al azar
	var pick: Dictionary = av[rng.randi() % av.size()]
	print("  -> mapa: entra en ", pick.type, " (piso ", G.floor, ")")
	Nav.enter_node(pick)


func _bot_combat() -> void:
	var cs: CombatScreen = Main.I.screen
	if cs.C.is_empty() or cs.busy or cs.over:
		return
	if not _cool(0.12):
		return
	var C = cs.C
	var G = Meta.run
	if not cs.has_meta("counted"):
		cs.set_meta("counted", true)
		stats.combats += 1
	if god and not cs.has_meta("god"):
		cs.set_meta("god", true)
		C.pl.status["strength"] = 25
	# usa pociones útiles
	for i in 3:
		if G.potions[i] != null and rng.randf() < 0.3:
			var tgt = Eng.living(C)[0]
			cs._use_potion_now(i, tgt)
			return
	var cands := []
	for c in C.hand:
		if Eng.can_play(C, c).ok:
			cands.append(c)
	if cands.is_empty():
		cs._end_turn()
		return
	# modo fácil: de vez en cuando deshace la última carta (si se puede)
	if G.easy and cs.undo_btn.visible and rng.randf() < 0.25:
		cs.undo()
		undos += 1
		return
	var inst: Dictionary = cands[rng.randi() % cands.size()]
	var d := Eng.card_def(inst)
	var lv := Eng.living(C)
	var tgt2 = lv[rng.randi() % lv.size()] if Eng.needs_target(d) else null
	cs._play_now(inst, tgt2)


func _bot_reward() -> void:
	if not _cool(0.3):
		return
	var rs: RewardScreen = Main.I.screen
	var btns := []
	_find(rs._list, "Button", btns)
	for b in btns:
		if not b.disabled:
			b.pressed.emit()
			return
	# todo recogido: continuar
	var all := []
	_find(rs, "Button", all)
	for b in all:
		if b.text.begins_with("Continuar"):
			b.pressed.emit()
			return


func _bot_leave_shop() -> void:
	if not _cool(0.5):
		return
	var all := []
	_find(Main.I.screen, "Button", all)
	# compra una carta si puede (primer CardView)
	for b in all:
		if b.text.begins_with("Salir"):
			stats.shops += 1
			b.pressed.emit()
			return


var _rest_id := 0


var _favor_id := 0


func _bot_favor() -> void:
	if not _cool(0.5) or _favor_id == Main.I.screen.get_instance_id():
		return
	_favor_id = Main.I.screen.get_instance_id()
	var all := []
	_find(Main.I.screen, "Button", all)
	var opts: Array = all.filter(func(b): return not b.disabled and b.get_child_count() > 0)
	print("  favor: %d opciones" % opts.size())
	if not opts.is_empty():
		opts[rng.randi() % opts.size()].pressed.emit()


func _bot_rest() -> void:
	if not _cool(0.5):
		return
	if _rest_id == Main.I.screen.get_instance_id():
		return
	_rest_id = Main.I.screen.get_instance_id()
	var all := []
	_find(Main.I.screen, "Button", all)
	stats.rests += 1
	for b in all:
		if not b.disabled and b.get_child_count() > 0:
			b.pressed.emit()
			return


func _bot_event() -> void:
	if not _cool(0.5):
		return
	var es: EventScreen = Main.I.screen
	var all := []
	_find(es._opts, "Button", all)
	for b in all:
		if not b.disabled:
			if b.text.begins_with("Continuar"):
				b.pressed.emit()
				return
	for b in all:
		if not b.disabled:
			stats.events += 1
			b.pressed.emit()
			return


func _bot_end() -> void:
	if not _cool(0.6):
		return
	finished += 1
	if (Main.I.screen as EndScreen).victory:
		stats.wins += 1
	else:
		stats.losses += 1
	print("partida %d terminada (%s). Estado: %s" % [finished, "victoria" if (Main.I.screen as EndScreen).victory else "derrota", JSON.stringify(stats)])
	runs_left -= 1
	if runs_left <= 0:
		print("deshacer usado: ", undos)
		print("OK: tiempo ", snappedf(t_total, 0.1), " s")
		get_tree().quit()
		return
	_start_run()


func _bot_ending() -> void:
	if not _cool(1.0):
		return
	var es: EndingScreen = Main.I.screen
	es._finish()


func _dump_and_quit() -> void:
	if Main.I.current == "combat" and Main.I.screen is CombatScreen:
		var cs: CombatScreen = Main.I.screen
		var C = cs.C
		if not C.is_empty():
			print("ESTADO combate: over=", C.over, " phase=", C.phase, " prompt=", C.prompt, " busy=", cs.busy, " cs.over=", cs.over, " turn=", C.turn)
			for e in C.enemies:
				print("  enemigo ", e.id, " hp=", e.hp, " intent=", e.intent)
			print("  orbs=", C.orbs, " hand=", C.hand.size(), " pl.status=", C.pl.status)
	var img := get_viewport().get_texture().get_image()
	if img != null:
		img.save_png("user://stuck.png")
		print("captura: ", ProjectSettings.globalize_path("user://stuck.png"))
	get_tree().quit(1)
