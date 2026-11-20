extends Node
## Microbanco de la mano (ventana): cuánto cuesta construir una carta (CardView.create) y sus piezas.
## Uso: godot --path . res://tests/perf_cards.tscn -- [n]
##   Imprime ms por carta (media / p50 / peor) creando n cartas de varias musas, y la etiqueta de emoji
##   suelta para comparar (el marcador de posición del arte usaba un emoji de 56 px aunque la carta tuviera arte).

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var n := int(args[0]) if args.size() > 0 else 40
	await get_tree().create_timer(0.2).timeout
	var G = Eng.new_run("irene", {"seed": 11, "nm": 0, "easy": true})
	Meta.run = G
	var host := Control.new()
	add_child(host)
	# 1) etiquetas sueltas (aisla el coste del texto de emoji frente a texto normal)
	for txt in ["⚔️", "A", "🛡️", "Zafiro"]:
		var ts: Array[float] = []
		for i in 12:
			var t0 := Time.get_ticks_usec()
			var l := UIK.label(txt, 56, Color.WHITE, "sans", HORIZONTAL_ALIGNMENT_CENTER)
			l.size = Vector2(168, 124)
			host.add_child(l)
			ts.append((Time.get_ticks_usec() - t0) / 1000.0)
			l.queue_free()
			await get_tree().process_frame
		print("LABEL %-8s %s" % [txt, _stats(ts)])
	# 2) cartas completas (ids del pool de varias musas)
	var ids: Array = []
	for m in ["irene", "zafiro", "lia", "claudia", "aurora", "selene"]:
		ids.append_array(DB.pool.get(m, []).slice(0, 8))
	var tc: Array[float] = []
	for i in n:
		var inst = Eng.make_card(G, ids[i % ids.size()])
		var t0 := Time.get_ticks_usec()
		var v := CardView.create(inst, null, 168.0)
		host.add_child(v)
		tc.append((Time.get_ticks_usec() - t0) / 1000.0)
		await get_tree().process_frame
		await get_tree().process_frame
		v.queue_free()
	print("CARTA create+add %s" % _stats(tc))
	await get_tree().process_frame
	get_tree().quit()


func _stats(a: Array[float]) -> String:
	var b := a.duplicate()
	b.sort()
	var s := 0.0
	for v in b:
		s += v
	return "media %.3f ms · p50 %.3f · peor %.3f (n=%d)" % [s / b.size(), b[b.size() / 2], b[-1], b.size()]
