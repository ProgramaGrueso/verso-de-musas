extends Node
## Sonda mínima de ms por fotograma en combate (hueco de una musa, para comparar dos commits de un vistazo).
## Para medir en serio (percentiles, fotograma de ACCIÓN, escenarios normal/élite/jefe, fx_layer):
## `tests/perf_irene.tscn`.
##
## Uso: godot --path . res://tests/perf_probe.tscn -- <musa> <segundos> [heavy]
##   heavy = juega el turno del jugador (cartas reales) en bucle para reproducir el uso normal.

var muse := "irene"
var secs := 6.0
var heavy := false


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	muse = args[0] if args.size() > 0 else "irene"
	secs = float(args[1]) if args.size() > 1 else 6.0
	heavy = args.size() > 2 and args[2] == "heavy"
	var t0 := Time.get_ticks_msec()
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	print("arranque de la app: %d ms" % (Time.get_ticks_msec() - t0))
	await get_tree().create_timer(0.3).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	var G = Eng.new_run(muse, {"seed": 11, "nm": 0, "easy": true})
	Meta.run = G
	Meta.settings["calm"] = false   # fuerza todo el juice (el usuario quiere ver el problema a pelo)
	var t1 := Time.get_ticks_msec()
	Nav.combat(["dockrat", "jelly", "crab"], "normal")
	print("armar combate: %d ms" % (Time.get_ticks_msec() - t1))
	var cs = Main.I.screen
	Engine.time_scale = 1.0
	# instrumenta lo que se dibuja por fotograma
	var tex_nodes := 0
	var particles := 0
	var labels := 0
	var stack := [cs]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		stack.append_array(n.get_children())
		if n is TextureRect:
			tex_nodes += 1
		elif n is CPUParticles2D:
			particles += 1
		elif n is Label or n is RichTextLabel:
			labels += 1
	print("nodos: TextureRect=%d CPUParticles2D=%d texto=%d" % [tex_nodes, particles, labels])
	var fps_info := []
	var acc := 0.0
	var frames := 0
	var worst := 0.0
	var worst_at := ""
	var t_start := Time.get_ticks_msec()
	var spin := 0
	var _last_us := Time.get_ticks_usec()
	while (Time.get_ticks_msec() - t_start) / 1000.0 < secs:
		await get_tree().process_frame
		var now_us := Time.get_ticks_usec()
		var dt := (now_us - _last_us) / 1000.0
		_last_us = now_us
		acc += dt
		frames += 1
		if dt > worst:
			worst = dt
			worst_at = "t=%.1fs" % ((Time.get_ticks_msec() - t_start) / 1000.0)
		if heavy and frames % 6 == 0:
			# juega todo lo jugable del turno y termina
			spin += 1
			if spin % 6 == 5:
				if cs.C.phase == "player" and cs.C.over == "":
					Eng.end_player_turn(cs.C)
			else:
				for inst in cs.C.hand.duplicate():
					if Eng.can_play(cs.C, inst).ok:
						Eng.play_card(cs.C, inst.uid)
						cs._render_all()
						break
	print("=== %s %s: %d fotogramas en %.1fs -> %.1f fps | media %.2f ms | peor %.1f ms (%s)" % [
		muse, "heavy" if heavy else "idle", frames, secs, frames / secs, acc / maxf(1.0, frames), worst, worst_at])
	print("draw calls: %d | objetos por fotograma (aprox): %d" % [
		Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
		Performance.get_monitor(Performance.OBJECT_COUNT)])
	print("time_scale tras la prueba: %.2f" % Engine.time_scale)
	get_tree().quit()
