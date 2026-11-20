extends Node
## Sonda de rendimiento de combate REAL (BUG 2): juega partidas de verdad como una musa y mide
## ms por fotograma (media/p95/p99), nodos vivos, tiempos de escena y qué se acumula con el tiempo.
##
## Uso: godot --path . res://tests/perf_irene.tscn -- <musa> <segundos> [escenario] [idle] [nocap] [--res WxH]
##   musa:      irene | zafiro | lia | claudia | aurora | selene
##   escenario: normal | elite | boss | todo (por defecto normal)
##   idle:      no juega nada (reposo: musa en idle + fondo animado), sirve para comparar con otro pase
##   sfx:       con efectos de sonido (por defecto en silencio)
##   nocap:     sube el tope de fx_layer (sonda: mide cuánto crecería sin el límite de producción)
##   --res WxH: abre la ventana a ese tamaño (con canvas_items el lienzo 1280x720 se re-escala)
##
## Métricas por escenario:
##   - ms de pared por fotograma (Time.get_ticks_usec) y percentiles: media, p50, p95, p99, peor.
##   - ACCIÓN: ms de los fotogramas en los que se pidió dibujar tras jugar una carta (el tirón que ve el jugador).
##   - OBJECT_COUNT y MEMORY_STATIC (Performance.TIME_PROCESS no es fiable en esta máquina: se ignora).
##   - hijos de fx_layer (cuántos son números / partículas / trazos / anillos) y Engine.time_scale al final.
## Con Irene se le dan además Cuerda/resorte al empezar (como trae en partida: dispara los REPETIR de Engranaje).

const ENC := {"normal": ["dockrat", "jelly", "crab"], "elite": ["chainwarden"], "boss": ["crabking"]}

var muse := "irene"
var secs := 8.0
var scenario := "normal"
var idle_mode := false   # combate montado, sin jugar nada (el reposo)
var _turns := 0
var _flags: Array = []   # "nocap": sin tope de fx_layer
var _spikes := 0
var _t_pre := 0    # µs del último frame_pre_draw
var _t_post := 0   # µs del último frame_post_draw


## Volcado de la mano en el fotograma caro (qué nodos ha añadido el reparto).
func _dump_hand(cs) -> void:
	var parts := []
	for v in cs.card_views.values():
		if is_instance_valid(v):
			parts.append("%s(pos=%s a=%s rot=%.2f)" % [v.inst.id, str(v.position.round()), str(snappedf(v.modulate.a, 0.01)), v.rotation])
	print("      mano: ", ", ".join(PackedStringArray(parts)))


## Volcado de la escena cuando aparece un fotograma caro: qué nodos ocupan el lienzo y de qué tipo son.
func _dump(root: Node) -> void:
	var types := {}
	var top := []
	var stack := [[root, ""]]
	while not stack.is_empty():
		var e: Array = stack.pop_back()
		var n: Node = e[0]
		var path: String = e[1]
		types[n.get_class()] = int(types.get(n.get_class(), 0)) + 1
		top.append("%s:%s" % [n.name, n.get_class()])
		for ch in n.get_children():
			stack.append([ch, path + "/" + str(ch.name)])
	var by_count := []
	for k in types.keys():
		by_count.append([types[k], k])
	by_count.sort_custom(func(a2, b2): return a2[0] > b2[0])
	var parts := []
	for i in mini(8, by_count.size()):
		parts.append("%s=%d" % [by_count[i][1], by_count[i][0]])
	print("      tipos: ", ", ".join(parts))
	if root is CombatScreen:
		var cs2 = root
		print("      C.over=%s phase=%s turn=%d · mano=%d · cartas_view=%d · enemigos_view=%d · nodos hand_layer=%d · ui_layer=%d" % [
			cs2.C.over, cs2.C.phase, cs2.C.turn, cs2.C.hand.size(), cs2.card_views.size(), cs2.enemy_views.size(),
			cs2.hand_layer.get_child_count(), cs2.ui_layer.get_child_count()])


## Bajo consumo (low_processor_mode): entre fotogramas el árbol NO corre; por eso tras cada acción se dejan
## correr dos fotogramas antes de medir el siguiente, y así los ms de compilación/sombreadores no se atribuyen a él.
func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var rest: Array = []
	var i := 0
	while i < args.size():
		if args[i] == "--res" and i + 1 < args.size():
			var wh: PackedStringArray = str(args[i + 1]).split("x")
			if wh.size() == 2:
				DisplayServer.window_set_size(Vector2i(int(wh[0]), int(wh[1])))
			i += 2
			continue
		if args[i] == "nocap":
			_flags.append("nocap")
			i += 1
			continue
		if args[i] == "sfx":
			_flags.append("sfx")
			i += 1
			continue
		if args[i] == "idle":
			idle_mode = true
			i += 1
			continue
		rest.append(args[i])
		i += 1
	muse = rest[0] if rest.size() > 0 else "irene"
	secs = float(rest[1]) if rest.size() > 1 else 8.0
	scenario = rest[2] if rest.size() > 2 else "normal"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	# tiempo de render del viewport (CPU que gasta el servidor de render en dibujar el lienzo, y GPU):
	# separa el tirón de «dibujar» del de GDScript (UIK.prof marca solo lo segundo)
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	# reparto del fotograma: proceso (hasta frame_pre_draw) · dibujo (hasta frame_post_draw) · resto (swap/espera)
	RenderingServer.frame_pre_draw.connect(_on_pre_draw)
	RenderingServer.frame_post_draw.connect(_on_post_draw)
	Engine.max_fps = 0
	Meta.settings["calm"] = false
	Meta.settings["music"] = 0.0
	Meta.settings["sfx"] = 0.6 if "sfx" in _flags else 0.0   # «sfx»: con sonido (mide Sfx.play/_take_player)
	print("== %s · escenario %s · %.1fs · ventana %s ==" % [muse, scenario, secs, str(DisplayServer.window_get_size())])
	var tiers: Array = ["normal", "elite", "boss"] if scenario == "todo" else [scenario]
	for t in tiers:
		await _run_tier(t)
	# entre combates (como el juego real): suelta la pantalla y deja volver a tiempo real
	if Main.I != null and is_instance_valid(Main.I.screen):
		Main.I.set_screen(Control.new(), "")
		await get_tree().process_frame
	Engine.time_scale = 1.0
	print("time_scale final: %.3f" % Engine.time_scale)
	print("time_scale ANTES: %.3f" % Engine.time_scale)
	var t0 := Time.get_ticks_msec()
	while Engine.time_scale < 0.99 and Time.get_ticks_msec() - t0 < 6000:
		await get_tree().create_timer(0.1, true, false, true).timeout
	print("time_scale FINAL tras esperar %d ms: %.3f" % [Time.get_ticks_msec() - t0, Engine.time_scale])
	# cierre suave (dejaba core dumps al salir): se suelta la pantalla, se para el audio y se difiere el quit
	if Main.I != null and is_instance_valid(Main.I.screen):
		Main.I.set_screen(Control.new(), "")
	Engine.time_scale = 1.0
	Sfx.stop_fx()
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().quit.call_deferred()


func _run_tier(tier: String) -> void:
	var G = Eng.new_run(muse, {"seed": 11, "nm": 0, "easy": true})
	Meta.run = G
	# mazo real: cartas iniciales + las de Engranaje/Cuerda de su clase (lo que el usuario va reuniendo)
	if not idle_mode:
		_add_gear_cards(G)
	# lo que trae Irene de verdad: Cuerda acumulada por los poderes de "ariete" (Maquinaria/Tic-Tac/Perpetuum)
	var S: Dictionary = G.get("perm") if G.get("perm") != null else {}
	if muse == "irene":
		S["resorte"] = 2
		S["tictac"] = 3
		G["perm"] = S
	Engine.time_scale = 1.0
	Nav.combat(ENC[tier], tier)
	await get_tree().process_frame
	await get_tree().process_frame
	var cs = Main.I.screen
	if cs == null or not cs.has_method("_render_all"):
		push_error("no hay pantalla de combate")
		return
	cs.busy = false
	# saca la sonda del camino de juego: jugamos jugadas REALES con Eng.play_card
	var dts: Array[float] = []
	var dts_act: Array[float] = []   # acciones que dibujan (carta jugada / golpe): el fotograma que sufrió el usuario
	var act_us := 0
	var proc: Array[float] = []
	var rend: Array[float] = []       # ms de CPU del render del viewport (fotograma anterior)
	var rend_gpu: Array[float] = []   # ms de GPU
	var split_proc: Array[float] = []
	var split_draw: Array[float] = []
	var split_rest: Array[float] = []
	var phys: Array[float] = []
	var objs: Array[int] = []
	var mem: Array[float] = []
	var fxmax := 0
	var fx_sum := 0
	var fx_n := 0
	var worst := 0.0
	var worst_t := 0.0
	var idle := 0
	var t0 := Time.get_ticks_msec()
	var f0 := Engine.get_process_frames()   # TOTAL: todos los fotogramas del escenario, no solo los medidos
	var last := Time.get_ticks_usec()
	var prev_objs := 0
	var k := 0
	var fx_kinds_max := {}
	# con "nocap" se sube el tope de producción para medir cuánto crecía ANTES (sirve de referencia)
	if cs != null and is_instance_valid(cs) and "nocap" in _flags:
		cs.fx_cap_override = 100000
	if idle_mode:
		cs.busy = true   # nadie juega: se queda el turno abierto tal cual
		await get_tree().create_timer(0.6).timeout   # deja asentar aplanados, Fuentes y el pico inicial
	while (Time.get_ticks_msec() - t0) / 1000.0 < secs and idle < maxi(10, int(secs * 12.0)):
		idle += 1
		if not idle_mode:
			var t_act := Time.get_ticks_usec()
			_play_step(cs)
			act_us = Time.get_ticks_usec() - t_act
			await _frames(2)   # deja que el árbol ejecute lo que el paso anterior programó (fuera de la medida)
			if cs == null or not is_instance_valid(cs) or cs.C.is_empty() or cs.C.over != "":
				break
		last = Time.get_ticks_usec()
		var t_start := last
		await get_tree().process_frame
		var now := Time.get_ticks_usec()
		dts.append((now - last) / 1000.0)
		if act_us > 0 and now - last - act_us < 400:
			dts_act.append(act_us / 1000.0 + (now - last - act_us) / 1000.0)
			act_us = 0
		last = now
		# CPU del proceso de escena: el monitor de Godot ya viene en segundos; se mide también
		# el tiempo de pared del cuerpo de este fotograma como control
		var pp: float = Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		proc.append(pp)
		var vrid := get_viewport().get_viewport_rid()
		var rcpu := RenderingServer.viewport_get_measured_render_time_cpu(vrid) + RenderingServer.get_frame_setup_time_cpu()
		var rgpu := RenderingServer.viewport_get_measured_render_time_gpu(vrid)
		rend.append(rcpu)
		rend_gpu.append(rgpu)
		# reparto del intervalo medido [last, now]: proceso → pre_draw → post_draw → resto
		var sp_proc := (_t_pre - t_start) / 1000.0 if _t_pre > t_start else -1.0
		var sp_draw := (_t_post - _t_pre) / 1000.0 if _t_post >= _t_pre and _t_pre > t_start else -1.0
		var sp_rest := (now - _t_post) / 1000.0 if _t_post > t_start else -1.0
		split_proc.append(sp_proc)
		split_draw.append(sp_draw)
		split_rest.append(sp_rest)
		prev_objs = int(Performance.get_monitor(Performance.OBJECT_COUNT))
		objs.append(prev_objs)
		mem.append(Performance.get_monitor(Performance.MEMORY_STATIC) / 1048576.0)
		if dts[-1] > worst:
			worst = dts[-1]
			worst_t = (Time.get_ticks_msec() - t0) / 1000.0
			if dts[-1] > 9.0 and cs != null and is_instance_valid(cs) and _spikes < 6:
				_spikes += 1
				_dump(cs)
				_dump_hand(cs)
				print("    [tirón %.1f ms en t=%.2fs · fotograma %d] nodos %d → %d · fx_layer %d · draw_calls=%d · render CPU %.2f ms GPU %.2f ms · reparto proceso %.2f / dibujo %.2f / resto %.2f ms" % [
					dts[-1], worst_t, Engine.get_process_frames(), prev_objs, objs[-1], cs.fx_layer.get_child_count(),
					int(Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)), rend[-1], rend_gpu[-1], split_proc[-1], split_draw[-1], split_rest[-1]])
		if cs != null and is_instance_valid(cs.fx_layer):
			var n: int = cs.fx_layer.get_child_count()
			fxmax = maxi(fxmax, n)
			fx_sum += n
			fx_n += 1
			if n > int(fx_kinds_max.get("n", 0)):
				fx_kinds_max = _fx_kinds(cs.fx_layer)
		k += 1
	var wall_s := (Time.get_ticks_msec() - t0) / 1000.0
	var frames_all := Engine.get_process_frames() - f0
	# estado final
	var fx_final: int = cs.fx_layer.get_child_count() if cs != null and is_instance_valid(cs) else -1
	var fx_delay := _fx_delay(cs)
	var p := _pct(dts)
	var pa := _pct(dts_act)
	var fps := 1000.0 / maxf(0.001, p.x)
	# UNA línea por escenario (así se compara el antes y el después sin buscar entre varios prints)
	print("FRAME %s/%s: media %.2f ms (%.1f fps) · p50 %.2f · p95 %.2f · p99 %.2f · peor %.1f ms @t=%.1fs · %d fotogramas%s" % [
		muse, tier, p.x, fps, p.y, p.z, p.w, worst, worst_t, k,
		(" · ACCIÓN media %.2f ms p95 %.2f" % [pa.x, pa.z]) if not dts_act.is_empty() else ""])
	# fotogramas que perdieron el vblank (>8 ms a 144 Hz se cuantizan a ~13.8 ms): lo que se nota como tirón
	var missed := 0
	for dt in dts:
		if dt > 8.0: missed += 1
	print("VBLANK %s/%s: %d fotogramas >8 ms de %d (%.1f %%)" % [muse, tier, missed, dts.size(), 100.0 * missed / maxf(1.0, dts.size())])
	# lo que vive la jugadora: el escenario entero (cada jugada + sus 2 fotogramas de asentamiento), no la muestra
	print("TOTAL %s/%s: %d fotogramas en %.2f s de pared · media %.2f ms/fotograma (%.0f fps)" % [
		muse, tier, frames_all, wall_s, 1000.0 * wall_s / maxf(1.0, frames_all), frames_all / maxf(0.001, wall_s)])
	print("COSTE %s/%s: fx_layer media %.1f · pico %d (%s) · al final %d sin liberar · nodos %d→%d (máx %d) · RAM %.1f→%.1f MB · turnos %d · time_scale %.2f" % [
		muse, tier, float(fx_sum) / maxf(1.0, fx_n), fxmax, str(fx_kinds_max), fx_delay,
		objs[0], objs[-1], _maxi(objs), mem[0], mem[-1], _turns, Engine.time_scale])
	var pr := _pct(rend)
	var pg := _pct(rend_gpu)
	var q1 := _pct(split_proc)
	var q2 := _pct(split_draw)
	var q3 := _pct(split_rest)
	print("REPARTO %s/%s: proceso media %.2f p95 %.2f · dibujo media %.2f p95 %.2f · resto (swap/espera) media %.2f p95 %.2f ms" % [
		muse, tier, q1.x, q1.z, q2.x, q2.z, q3.x, q3.z])
	print("RENDER %s/%s: CPU media %.2f · p95 %.2f · peor %.2f ms · GPU media %.2f · p95 %.2f ms" % [
		muse, tier, pr.x, pr.z, _maxf(rend), pg.x, pg.z])
	if "nocap" in _flags:
		print("  (sonda SIN tope de fx_layer: habría llegado a %d nodos)" % fxmax)
	# fugas: tras 2.5 s reales (los efectos ya han terminado) los objetos deberían volver cerca del inicio
	await get_tree().create_timer(2.5, true, false, true).timeout
	print("ASENTADO %s/%s: objetos %d (inicio %d, fin de la medida %d) · fx_layer vivos %d" % [
		muse, tier, int(Performance.get_monitor(Performance.OBJECT_COUNT)), objs[0], objs[-1], _fx_delay(cs)])


## Un paso de juego real: juega la primera carta jugable del turno o, si no queda, cierra el turno y
## corre a todos los enemigos (lo que hace la UI, sin sus esperas).
func _play_step(cs) -> void:
	if cs == null or not is_instance_valid(cs) or cs.C.is_empty() or cs.C.over != "":
		return
	if cs.busy or cs.C.phase != "player" or cs.C.prompt != null:
		return
	for inst in cs.C.hand.duplicate():
		if Eng.can_play(cs.C, inst).ok:
			var tgt = null
			var d := Eng.card_def(inst)
			if Eng.needs_target(d):
				var lv: Array = Eng.living(cs.C)
				if lv.is_empty():
					return
				tgt = lv[randi() % lv.size()]
			if Eng.play_card(cs.C, inst.uid, tgt):
				cs._render_all()
			return
	# sin jugadas: termina el turno
	Eng.end_player_turn(cs.C)
	for e in cs.C.enemies.duplicate():
		if cs.C.is_empty() or cs.C.over != "":
			break
		if e.hp > 0:
			Eng.run_enemy_turn(cs.C, e)
	if cs.C.is_empty():
		return
	Eng.end_round(cs.C)
	Eng.start_turn(cs.C)
	cs._render_all()
	_turns += 1


func _add_gear_cards(G) -> void:
	# cartas del pool de la musa con "gear" (las que repiten) + viento/cuerda
	var pool: Array = DB.pool.get(G.char, [])
	var extra := []
	for id in pool:
		if not Eng.meta_locked.is_valid() or not (id in Eng.meta_locked.call()):
			extra.append(id)
	extra.sort()
	for id in extra.slice(0, 8):
		G.deck.append(Eng.make_card(G, id))


func _fx_kinds(layer: Node) -> Dictionary:
	var r := {"n": 0, "texto": 0, "particulas": 0, "lineas": 0, "anillos": 0, "tween_control": 0}
	for c in layer.get_children():
		r.n += 1
		if c is Label:
			r.texto += 1
		elif c is CPUParticles2D:
			r.particulas += 1
		elif c is Line2D:
			r.lineas += 1
		elif c is Juice.Ring:
			r.anillos += 1
	return r


func _fx_delay(cs) -> int:
	if cs == null or not is_instance_valid(cs) or cs.fx_layer == null:
		return -1
	var n := 0
	for ch in cs.fx_layer.get_children():
		if not ch.is_queued_for_deletion():
			n += 1
	return n


func _pct(a: Array) -> Vector4:
	var b := a.duplicate()
	b.sort()
	var n := b.size()
	if n == 0:
		return Vector4.ZERO
	var s := 0.0
	for v in b:
		s += v
	return Vector4(s / n, b[int(n * 0.5)], b[mini(n - 1, int(n * 0.95))], b[mini(n - 1, int(n * 0.99))])


func _maxi(a: Array) -> int:
	var m := 0
	for v in a:
		m = maxi(m, int(v))
	return m


func _maxf(a: Array) -> float:
	var m := 0.0
	for v in a:
		m = maxf(m, float(v))
	return m


func _on_pre_draw() -> void:
	_t_pre = Time.get_ticks_usec()


func _on_post_draw() -> void:
	_t_post = Time.get_ticks_usec()
