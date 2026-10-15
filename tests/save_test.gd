extends Node
## Prueba de guardado/carga: la partida recargada debe ser equivalente (mapa con enlaces, posición, RNG).

func _ready() -> void:
	var G := Eng.new_run("selene", {"seed": 123})
	G.map = RunGen.gen_map(G)
	G.pos = G.map.rows[0][0]
	G.pos.visited = true
	G.gold = 777
	Eng.add_relic(G, "ancla")
	Meta.save_run(G)
	var H = Meta.load_run()
	var ok := true
	ok = ok and H != null
	ok = ok and H.rs == G.rs and H.gold == 777 and H.deck.size() == G.deck.size() and H.relics == G.relics
	ok = ok and H.pos.type == G.pos.type and H.pos.r == 0 and H.pos.visited
	for r in G.map.rows.size():
		for i in G.map.rows[r].size():
			var a = G.map.rows[r][i]
			var b = H.map.rows[r][i]
			ok = ok and a.type == b.type and a.next.size() == b.next.size()
			for k in a.next.size():
				ok = ok and a.next[k].r == b.next[k].r and a.next[k].c == b.next[k].c and a.next[k].type == b.next[k].type
	# el siguiente número aleatorio debe coincidir
	ok = ok and Eng.rnd(G) == Eng.rnd(H)
	print("SAVE_TEST ", "OK" if ok else "FALLO")
	Meta.clear_save()
	get_tree().quit(0 if ok else 1)
