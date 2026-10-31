class_name Daily
extends RefCounted
## Reto diario: misma semilla, misma musa y mismo modificador para todo el mundo durante un día.
## La semilla sale de la fecha, así que no hace falta ningún servidor. Con semilla fija cada acto
## arranca de un estado de RNG propio (Eng.act_seed), de modo que los mapas coinciden aunque cada
## jugador tome decisiones distintas.

const MODS := {
	"rico": {"name": "Bolsa Llena", "desc": "Empiezas con 250 de oro."},
	"coleccionista": {"name": "Coleccionista", "desc": "Empiezas con una reliquia aleatoria."},
	"alquimista": {"name": "Alquimista", "desc": "Empiezas con 3 pociones aleatorias."},
	"templado": {"name": "Templado", "desc": "Tus cartas iniciales empiezan mejoradas, pero tienes 15 PV máx. menos."},
	"maldito": {"name": "Pacto Maldito", "desc": "Empiezas con 2 Dudas en el mazo y una reliquia rara."},
	"cristal": {"name": "Cañón de Cristal", "desc": "+2 de Fuerza en cada combate, pero tienes 25 PV máx. menos."},
}


static func key_today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


static func info(key: String) -> Dictionary:
	var seed_v := Eng.seed_from_text("verso-de-musas-" + key)
	var chars := DB.playable()
	var mods: Array = MODS.keys()
	return {"key": key, "seed": seed_v, "char": chars[seed_v % chars.size()], "mod": mods[floori(seed_v / 7.0) % mods.size()]}


static func mod_name(mod: String) -> String:
	return MODS[mod].name if MODS.has(mod) else ""


static func mod_desc(mod: String) -> String:
	return MODS[mod].desc if MODS.has(mod) else ""


## Crea la partida del reto (con su mapa del acto I).
static func new_run(key: String) -> Dictionary:
	var inf := info(key)
	var G := Eng.new_run(inf.char, {"seed": inf.seed})
	G["seeded"] = true
	G["daily"] = key
	G["dailyMod"] = inf.mod
	apply_mod(G, inf.mod)
	G.map = RunGen.gen_map_game(G)
	return G


static func apply_mod(G, mod: String) -> void:
	match mod:
		"rico":
			G.gold = 250
		"coleccionista":
			var r = Eng.random_relic(G)
			if r != null:
				Eng.add_relic(G, r)
		"alquimista":
			for i in 3:
				G.potions[i] = Eng.pick(G, DB.potions.keys())
		"templado":
			for c in G.deck:
				if Eng.can_upgrade(c):
					c.up = true
			G.maxHp -= 15
			G.hp = G.maxHp
		"maldito":
			for i in 2:
				G.deck.append(Eng.make_card(G, "doubt"))
			var c := Eng._relic_candidates(G, "rare")
			if not c.is_empty():
				Eng.add_relic(G, Eng.pick(G, c))
		"cristal":
			Eng.add_perm(G, "strength", 2)
			G.maxHp -= 25
			G.hp = G.maxHp
