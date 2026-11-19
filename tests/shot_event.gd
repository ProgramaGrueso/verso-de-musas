extends Node
## Captura la pantalla de un evento forzado y, opcionalmente, su resultado.
## Uso: godot --path . res://tests/shot_event.tscn -- <id_evento|scan> <salida.png> [click]

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var id: String = args[0] if args.size() > 0 else "madriguera"
	var out: String = args[1] if args.size() > 1 else "/tmp/event.png"
	var click := args.size() > 2 and args[2] == "click"
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await get_tree().create_timer(0.4).timeout
	var G = Eng.new_run("lia", {"seed": 7, "nm": 0, "easy": false})
	Meta.run = G
	if id == "scan":
		await _scan()
		get_tree().quit()
		return
	G.seenEvents = DB.events.filter(func(e): return e.id != id).map(func(e): return e.id)
	Nav.event()
	await get_tree().create_timer(0.8).timeout
	_capture(out)
	if click:
		var es: EventScreen = Main.I.screen
		for c in es._opts.get_children():
			if c is Button and not c.disabled:
				c.pressed.emit()
				break
		await get_tree().create_timer(1.2).timeout
		_capture(out.replace(".png", "_result.png"))
	get_tree().quit()


func _scan() -> void:
	var G = Meta.run
	var col: VBoxContainer = null
	for ev in DB.events:
		G.act = int(ev.get("act", 1))
		G.char = String(ev.get("char", "lia"))
		G.seenEvents = DB.events.filter(func(e): return e.id != ev.id).map(func(e): return e.id)
		Nav.event()
		await get_tree().process_frame
		await get_tree().process_frame
		var es: EventScreen = Main.I.screen
		col = _find_col(es)
		var m := _bounds(col, Vector2.ZERO)
		var max_x: float = m.x
		var max_y: float = m.y
		print("%-12s acto=%d ancho=%.0f fin_xy=%.0f,%.0f %s" % [
			ev.id, G.act, col.size.x, max_x, max_y,
			"FUERA" if (max_x > 1230.5 or max_y > 656.5) else "ok"])


func _find_col(n: Node) -> VBoxContainer:
	for c in n.get_children():
		if c is VBoxContainer and (c as Control).position.x == 700.0:
			return c
		var f := _find_col(c)
		if f != null:
			return f
	return null


func _bounds(n: Node, m: Vector2) -> Vector2:
	for c in n.get_children():
		if c is Control:
			var ctl := c as Control
			var r := ctl.get_global_rect()
			if ctl.visible and not (ctl is ColorRect):
				m = Vector2(maxf(m.x, r.end.x), maxf(m.y, r.end.y))
		m = _bounds(c, m)
	return m


func _capture(path: String) -> void:
	var img := get_viewport().get_texture().get_image()
	img.save_png(path)
	print("captura: ", path)
