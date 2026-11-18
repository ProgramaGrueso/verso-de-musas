extends Node
## Prueba de guardado/carga: la partida recargada debe ser equivalente (mapa con enlaces, posición, RNG)
## y el guardado debe sobrevivir a un archivo corrupto, a una escritura interrumpida y a un borrado.
## Uso: godot --path . res://tests/save_test.tscn  (redirige los datos: XDG_DATA_HOME=/tmp/x)

var fails := 0


func ok(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FALLA: ", msg)


func dump(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(text)


func _ready() -> void:
	Meta.clear_save()
	var G := Eng.new_run("selene", {"seed": 123})
	G.map = RunGen.gen_map(G)
	G.pos = G.map.rows[0][0]
	G.pos.visited = true
	G.gold = 777
	Eng.add_relic(G, "ancla")
	Meta.save_run(G)
	var H = Meta.load_run()
	var good := H != null
	good = good and H.rs == G.rs and H.gold == 777 and H.deck.size() == G.deck.size() and H.relics == G.relics
	good = good and H.pos.type == G.pos.type and H.pos.r == 0 and H.pos.visited
	for r in G.map.rows.size():
		for i in G.map.rows[r].size():
			var a = G.map.rows[r][i]
			var b = H.map.rows[r][i]
			good = good and a.type == b.type and a.next.size() == b.next.size()
			for k in a.next.size():
				good = good and a.next[k].r == b.next[k].r and a.next[k].c == b.next[k].c and a.next[k].type == b.next[k].type
	# el siguiente número aleatorio debe coincidir
	good = good and Eng.rnd(G) == Eng.rnd(H)
	ok(good, "ida y vuelta del guardado")

	# --- el .bak existe y sirve si el principal se corrompe (cierre a mitad de escritura) ---
	Meta.save_run(G)   # segunda escritura: deja copia del anterior
	ok(FileAccess.file_exists(Meta.SAVE_PATH + ".bak"), "se crea save.json.bak")
	dump(Meta.SAVE_PATH, "{\"char\":\"selene\",\"gold\":12")   # JSON truncado
	var C = Meta.load_run()
	ok(Meta.has_save(), "has_save sobrevive a un save corrupto")
	ok(C != null and C.gold == 777, "load_run cae en el .bak")

	# --- un .tmp huérfano no debe afectar a la carga ---
	Meta.save_run(G)
	dump(Meta.SAVE_PATH + ".tmp", "{\"char\":\"selene\"")   # resto de una escritura muerta
	var D = Meta.load_run()
	ok(D != null and D.gold == 777, ".tmp huérfano ignorado")

	# --- si ambos están corruptos no se rompe: hay que empezar una partida nueva ---
	dump(Meta.SAVE_PATH, "basura")
	dump(Meta.SAVE_PATH + ".bak", "basura")
	ok(not Meta.has_save(), "sin guardado válido -> has_save false")
	ok(Meta.load_run() == null, "sin guardado válido -> load_run null")
	Meta.clear_save()
	ok(not Meta.has_save(), "clear_save borra principal, .bak y .tmp")

	# --- tras limpiar, un guardado nuevo funciona (no queda estado pegado) ---
	Meta.save_run(G)
	var E = Meta.load_run()
	ok(E != null and E.gold == 777, "guardado nuevo tras limpiar")

	Meta.clear_save()
	print("SAVE_TEST ", "OK" if fails == 0 else "FALLO (%d)" % fails)
	get_tree().quit(0 if fails == 0 else 1)
