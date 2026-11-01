extends SceneTree
## La misma semilla (texto o número) repite mapa, jefe y encuentros de los tres actos; semillas distintas, no.

func sig(ch: String, seed_v: int) -> String:
	var G := Eng.new_run(ch, {"seed": seed_v})
	var out := []
	for act in [1, 2, 3]:
		G.act = act
		G.rs = Eng.act_seed(G.seed, act)
		G.map = RunGen.gen_map_game(G)
		var types := []
		for row in G.map.rows if G.map is Dictionary and G.map.has("rows") else []:
			for n in row:
				types.append(n.type)
		out.append([act, RunGen.boss_id(G), types, JSON.stringify(G.map).hash()])
		var ids := []
		for i in 6:
			ids.append(RunGen.encounter_game(G, "normal"))
		out.append(ids)
	return JSON.stringify(out)


func _init() -> void:
	DB.load_all()
	var fails := 0
	for ch in DB.characters.keys():
		var a := sig(ch, Eng.seed_from_text("dragon"))
		var b := sig(ch, Eng.seed_from_text("dragon"))
		var c := sig(ch, Eng.seed_from_text("otra"))
		if a != b:
			fails += 1
			print("FALLA: la semilla no repite en ", ch)
		if a == c:
			fails += 1
			print("FALLA: semillas distintas dan lo mismo en ", ch)
	print("seed_from_text: dragon=%d, 12345=%d, ' Dragon '=%d" % [Eng.seed_from_text("dragon"), Eng.seed_from_text("12345"), Eng.seed_from_text(" Dragon ")])
	print("RESULTADO: %d fallan" % fails)
	quit(1 if fails else 0)
