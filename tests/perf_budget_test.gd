extends Node
## Presupuesto de rendimiento del combate (regresión del «lenteo» de Irene y, en general, del juice).
## Sin GPU no se puede juzgar un fotograma, así que se miden invariantes baratos y deterministas:
##   A) 200 números flotantes + 200 ráfagas + 40 trazos/recargas de golpes de Engranaje simulados en ráfaga:
##      fx_layer nunca pasa de su tope, los números activos se limitan y al cabo de 1,5 s vuelve a ~0;
##      los nodos de fx_layer (reciclados) no crecen entre vueltas (no hay fuga).
##   B) Los nodos totales de la escena vuelven a la cifra de reposo tras la ráfaga (no se acumulan nodos).
##   C) Engine.time_scale vuelve a 1,0 al salir del combate aunque haya habido una cadena de hitstops.
##   D) Una partida real (Eng.play_card, enemigos) no pierde nodos ni cambia time_scale.
## Uso: godot --headless --path . res://tests/perf_budget_test.tscn

const FX_CAP := 120      # = CombatScreen.FX_CAP
const POP_MAX := 14      # = CombatScreen.POP_MAX
const BURST_MAX := 18    # = CombatScreen.BURST_MAX
const EPS := 3           # nodos de margen (~0)

var ok := 0
var fail := 0


func _check(name: String, cond: bool, detail: String = "") -> void:
	if cond:
		ok += 1
		print("ok   ", name, ("  (" + detail + ")") if detail != "" else "")
	else:
		fail += 1
		print("FALLA ", name, ("  (" + detail + ")") if detail != "" else "")


func _frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


## Deja pasar `secs` de tiempo de juego (con Engine.time_scale < 1, en reloj real es 20x: como en el juego).
## En modo sin ventana el SceneTree reparte el delta de cada fotograma entre las esperas y un temporizador
## real cobra menos, así que se espera en tiempo de JUEGO contando fotogramas (el caso de dibujado).
func _wait(secs: float) -> void:
	var game := 0.0
	while game < secs:
		await get_tree().process_frame
		game += get_process_delta_time()


func _ready() -> void:
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	Meta.settings.calm = false
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.3).timeout
	var G = Eng.new_run("irene", {"seed": 23})
	Meta.run = G
	Engine.time_scale = 1.0
	Nav.combat(["dockrat", "jelly", "crab"], "normal")
	await _frames(3)
	var cs = Main.I.screen
	if cs == null or not cs.has_method("_popup"):
		print("FALLA no hay pantalla de combate")
		get_tree().quit(1)
		return
	cs.busy = true
	await _frames(2)

	# ---------- A) ráfaga de FX estilo Irene ----------
	var peak_fx := 0
	var peak_pop := 0
	var peak_burst := 0
	var ev = cs.enemy_views.values()[0]
	var target: Vector2 = ev.body_center()
	var n1 := 0
	var size_fx: Array = []
	# cada vuelta: 50 números, 50 ráfagas, 10 recargas de Engranaje (popup + anillo + chispas + trazo) = x4
	for round_i in 4:
		for i in 50:
			cs._popup(target, "-%d" % (3 + i), "dmg")
			cs._burst(target, Color("#ffd98a"), 16)
			cs._ring(target, Color("#ff9a62"), 20.0, 90.0, 0.3, 4.0)
			cs.fx_layer.add_child(_slash_like(cs, target))
			n1 += 1
			await get_tree().process_frame
			peak_fx = maxi(peak_fx, cs.fx_layer.get_child_count())
			peak_pop = maxi(peak_pop, cs._pop_live)
			peak_burst = maxi(peak_burst, cs._burst_live)
		await _wait(1.5)
		size_fx.append(cs.fx_layer.get_child_count())
	var active_after: int = cs._pop_live + cs._burst_live + cs._chains.size()
	var slot_nodes: int = cs.fx_layer.get_child_count()
	# en el lienzo solo quedan los nodos que se reciclan (números ocultos, anillo de destello): todo lo demás
	# (partículas, trazos, anillos y bandas) debe haberse liberado
	var leftover: Array = []
	for ch in cs.fx_layer.get_children():
		if not ch is Label and ch is CanvasItem and (ch as CanvasItem).visible:
			leftover.append(ch.get_class())
	_check("A.1 fx_layer nunca supera el tope(%d)" % FX_CAP, peak_fx <= FX_CAP, "pico %d con %d efectos" % [peak_fx, n1])
	_check("A.2 números flotantes limitados (%d)" % POP_MAX, peak_pop <= POP_MAX, "pico %d" % peak_pop)
	_check("A.3 emisiones de partículas limitadas (%d)" % BURST_MAX, peak_burst <= BURST_MAX, "pico %d" % peak_burst)
	_check("A.4 nada activo tras 1,5 s (números, partículas, cadenas)", active_after == 0, "activos %d" % active_after)
	_check("A.5 fx_layer libera partículas/trazos/anillos", leftover.is_empty(), "quedan %s" % str(leftover))
	_check("A.5b los nodos reciclados no crecen entre vueltas", slot_nodes <= 40 and size_fx.max() <= 40, "en pantalla %d · vuelta a vuelta %s" % [slot_nodes, str(size_fx)])
	var total_nodes := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	_check("A.6 pocos nodos nuevos tras 200 ciclos (reciclaje)", total_nodes < 20000, "OBJECT_COUNT %d" % total_nodes)
	var labels: Array = []
	for ch in cs.fx_layer.get_children():
		if ch is Label:
			labels.append(ch)
	_check("A.7 las etiquetas de cifra se reciclan (≤ 40 nodos)", labels.size() <= 40, "%d etiquetas en fx_layer" % labels.size())

	# ---------- B) nodos de escena ----------
	await _wait(1.5)
	var cs_nodes := _count(cs)
	_check("B.1 la escena no acumula nodos tras la ráfaga", cs_nodes < 3000, "nodos en el combate %d" % cs_nodes)

	# ---------- C) hitstops encadenados (los que encadena Irene al repetir Engranaje) ----------
	for i in 4:
		cs._hit_stop(0.06)
		await _frames(1)
	_check("C.1 durante el hitstop el tiempo va a cámara lenta", Engine.time_scale < 0.5, "time_scale %.2f" % Engine.time_scale)
	await _wait(0.4)
	_check("C.2 la cadena de hitstops termina en tiempo real", Engine.time_scale == 1.0, "time_scale %.2f" % Engine.time_scale)
	_check("C.3 el combate sigue vivo tras la cadena", cs.is_inside_tree() and Engine.time_scale == 1.0)

	# ---------- D) partida real y salida ----------
	cs.busy = false
	var played := 0
	for turn in 2:
		for inst in cs.C.hand.duplicate():
			if cs.C.is_empty() or cs.C.over != "":
				break
			if Eng.can_play(cs.C, inst).ok:
				var tgt = null
				if Eng.needs_target(Eng.card_def(inst)):
					tgt = Eng.living(cs.C)[0] if not Eng.living(cs.C).is_empty() else null
				if Eng.play_card(cs.C, inst.uid, tgt):
					played += 1
					cs._render_all()
					await _frames(1)
		if cs.C.is_empty() or cs.C.over != "":
			break
		Eng.end_player_turn(cs.C)
		for e in cs.C.enemies.duplicate():
			if cs.C.is_empty() or cs.C.over != "":
				break
			if e.hp > 0:
				Eng.run_enemy_turn(cs.C, e)
		if not cs.C.is_empty():
			Eng.end_round(cs.C)
			Eng.start_turn(cs.C)
			cs._render_all()
		await _frames(2)
	_check("D.1 se jugaron cartas de verdad", played > 0, "%d cartas" % played)
	# el último golpe de la partida pudo cerrar con un hitstop: se espera a que venza (en el juego son 65-80 ms)
	await _wait(0.2)
	_check("D.2 la partida no deja el tiempo congelado", Engine.time_scale == 1.0, "time_scale %.2f" % Engine.time_scale)
	# salir del combate con el reloj encendido y con un hitstop a punto de vencer
	cs._hit_stop(0.05)
	cs._wake()
	_main_free_screen(cs)
	cs = null
	await _frames(3)
	_check("D.3 time_scale vuelve a 1,0 al salir del combate", Engine.time_scale == 1.0, "time_scale %.2f" % Engine.time_scale)

	# ---------- E) una pantalla nueva arranca limpia ----------
	Nav.combat(["crab"], "normal")
	await _frames(3)
	var cs2 = Main.I.screen
	var zero: bool = cs2 != null and cs2.fx_layer != null and cs2.fx_layer.get_child_count() <= 1
	_check("E.1 un combate nuevo empieza con fx_layer vacío", zero, "hijos %d" % (cs2.fx_layer.get_child_count() if cs2 != null else -1))
	_check("E.2 el sonido del combate anterior no se apila (pool acotado)", Sfx._pool.size() <= 32, "%d voces" % Sfx._pool.size())

	# ---------- F) _lethal_tip no revienta (regresión del ternario dentro del % de formato) ----------
	cs2.busy = true
	var tip: String = cs2._lethal_tip()
	_check("F.1 _lethal_tip devuelve el aviso sin romperse", tip.contains("Muerte segura") and tip.contains("Bloqueo"), tip.substr(0, 40))
	Eng.add_relic(G, "pluma")
	var tip2: String = cs2._lethal_tip()
	_check("F.2 _lethal_tip con la Pluma de Fénix", tip2.contains("Pluma de Fénix"), "aviso ampliado")
	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)


## Trazo de golpe: lo mismo que crea CombatScreen._slash (Line2D + tween), para medir su coste/liberación.
func _slash_like(cs, pos: Vector2) -> Line2D:
	var l := Line2D.new()
	var d := Vector2(cos(deg_to_rad(-45)), sin(deg_to_rad(-45))) * 60.0
	l.points = PackedVector2Array([pos - d, pos + d])
	l.width = 4.0
	l.default_color = Color.WHITE
	var tw := l.create_tween()
	tw.tween_interval(0.2)
	tw.tween_callback(l.queue_free)
	return l


func _main_free_screen(cs) -> void:
	# mismo camino que el juego al terminar el combate: se libera la pantalla (y su _exit_tree)
	if Main.I.screen == cs:
		Main.I.set_screen(Control.new(), "end")


func _count(n: Node) -> int:
	var c := 1
	for ch in n.get_children():
		c += _count(ch)
	return c
