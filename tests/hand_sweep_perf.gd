extends Node
## Recorre una mano de 12 cartas (foco secuencial, como el mando) y mide ms por fotograma.
## Falla si la media supera el presupuesto. Uso: godot --path . res://tests/hand_sweep_perf.tscn
const BUDGET_MS := 8.0

func _ready() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var G = Eng.new_run("lia", {"seed": 7, "nm": 0, "easy": false})
	Meta.run = G
	G.maxHp = 999
	G.hp = 999
	Nav.combat(["eel"], "normal")
	await get_tree().create_timer(1.0).timeout
	var cs: CombatScreen = Main.I.screen
	for e in cs.C.enemies:
		e.maxHp = 9999
		e.hp = 9999
	cs.C.hand.clear()
	var ids: Array = DB.pool.get("lia", []).slice(0, 12)
	for i in 12:   # directo a la mano (add_cards topa en 10): 12 cartas distintas
		cs.C.hand.append(Eng.make_card(cs.C.G, ids[i % ids.size()] if ids.size() > 0 else "lia_shiv"))
	cs._render_all()
	await get_tree().create_timer(2.0).timeout
	var views: Array = []
	for inst in cs.C.hand:
		views.append(cs.card_views[inst.uid])
	RenderingServer.viewport_set_measure_render_time(get_viewport().get_viewport_rid(), true)
	var fr: Array[float] = []
	var pr: Array[float] = []
	var gp: Array[float] = []
	var cp: Array[float] = []
	var hnd: Array[float] = []
	var tw0 := _tweens(cs)
	var base: Array[float] = []
	for k in 30:
		await get_tree().process_frame
		base.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
	print("TIME_PROCESS reposo %.2f ms" % _mean(base))
	# mando: LB/RB carta a carta (cycle_card) ida y vuelta; ratón: hover entra/sale
	for pass_i in 3:
		for k in 24:
			var t0 := Time.get_ticks_usec()
			cs.cycle_card(1 if k < 12 else -1)
			hnd.append((Time.get_ticks_usec() - t0) / 1000.0)
			var f0 := Time.get_ticks_usec()
			await get_tree().process_frame
			fr.append((Time.get_ticks_usec() - f0) / 1000.0)
			pr.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			var vr := get_viewport().get_viewport_rid()
			gp.append(RenderingServer.viewport_get_measured_render_time_gpu(vr))
			cp.append(RenderingServer.viewport_get_measured_render_time_cpu(vr))
	print("fase mando: foco %.3f ms · proceso %.2f ms" % [_mean(hnd), _mean(pr)])
	var n_pad := hnd.size()
	for pass_i in 3:
		var prev = null
		for v in views:
			var t0 := Time.get_ticks_usec()
			if prev != null:
				prev.mouse_exited.emit()
			v.mouse_entered.emit()
			hnd.append((Time.get_ticks_usec() - t0) / 1000.0)
			prev = v
			var f0 := Time.get_ticks_usec()
			await get_tree().process_frame
			fr.append((Time.get_ticks_usec() - f0) / 1000.0)
			pr.append(Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
			var vr := get_viewport().get_viewport_rid()
			gp.append(RenderingServer.viewport_get_measured_render_time_gpu(vr))
			cp.append(RenderingServer.viewport_get_measured_render_time_cpu(vr))
	print("tweens vivos tras barrer: %d (antes %d)" % [_tweens(cs), tw0])
	print("TIME_PROCESS medio %.2f ms · render cpu %.2f ms · gpu %.2f ms · draw calls %d" % [_mean(pr), _mean(cp), _mean(gp), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)])
	var mf := _mean(fr)
	var mh := _mean(hnd)
	print("barrido 12 cartas: fotograma medio %.2f ms · foco medio %.3f ms · peor foco %.3f" % [mf, mh, _max(hnd)])
	var ok := mh + _mean(pr) <= BUDGET_MS
	print("hand_sweep_perf: %s (presupuesto proceso+foco medio <= %.1f ms)" % ["ok" if ok else "FALLO", BUDGET_MS])
	get_tree().quit(0 if ok else 1)

func _mean(a: Array[float]) -> float:
	var s := 0.0
	for x in a:
		s += x
	return s / maxf(1.0, a.size())

func _max(a: Array[float]) -> float:
	var m := 0.0
	for x in a:
		m = maxf(m, x)
	return m

func _tweens(cs: Node) -> int:
	return get_tree().get_processed_tweens().size() if get_tree().has_method("get_processed_tweens") else Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
