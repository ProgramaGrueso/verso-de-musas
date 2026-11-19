class_name Favors
extends RefCounted
## Favor de las Musas: bendición elegida al empezar cada acto (1 de 3 opciones aleatorias).
## Los bufos duran el acto; los pactos y regalos se aplican al momento. G.favor = {id, act} guarda el bufo activo.

const DEFS := {
	"fuerza": {"kind": "buff", "name": "Furia de Calíope", "desc": "Este acto: empiezas cada combate con +1 de Fuerza."},
	"egida": {"kind": "buff", "name": "Égida de Clío", "desc": "Este acto: empiezas cada combate con 8 de Bloqueo."},
	"inspiracion": {"kind": "buff", "name": "Inspiración de Erato", "desc": "Este acto: robas 2 cartas más en el primer turno de cada combate."},
	"espinas": {"kind": "buff", "name": "Coro de Melpómene", "desc": "Este acto: empiezas cada combate con 3 de Espinas."},
	"agilidad": {"kind": "buff", "name": "Danza de Terpsícore", "desc": "Este acto: empiezas cada combate con +1 de Destreza."},
	"regen": {"kind": "buff", "name": "Marea Vital", "desc": "Este acto: al ganar un combate recuperas 5 PV."},
	"mal_de_ojo": {"kind": "buff", "name": "Mal de Ojo", "desc": "Este acto: los enemigos empiezan el combate con 1 de Vulnerable."},
	"oro_botin": {"kind": "buff", "name": "Botín Dorado", "desc": "Este acto: ganas un 50% más de oro en los combates."},
	"furia_pacto": {"kind": "buff", "name": "Furia Encadenada", "desc": "Este acto: empiezas cada combate con +2 de Fuerza y 1 de Débil."},
	"oro_sangre": {"kind": "trade", "name": "Oro a cambio de sangre", "desc": "Ganas 120 de oro. Pierdes 12 PV."},
	"reliquia_duda": {"kind": "trade", "name": "Reliquia a cambio de Duda", "desc": "Obtienes una reliquia aleatoria. Añades la maldición Duda a tu mazo."},
	"vida_oro": {"kind": "trade", "name": "Vigor a cambio de oro", "desc": "Ganas 12 PV máx. Pierdes 60 de oro (o todo el que tengas)."},
	"temple": {"kind": "trade", "name": "Temple a cambio de sangre", "desc": "Mejoras 2 cartas al azar de tu mazo. Pierdes 8 PV."},
	"carta": {"kind": "card", "name": "Regalo de la Musa", "desc": "Añades a tu mazo una carta mejorada elegida al azar de tu musa."},
	"balsamo": {"kind": "card", "name": "Bálsamo Verde", "desc": "Recuperas el 40% de tus PV máx. Solo se ofrece si te faltan PV."},
	"pocion": {"kind": "card", "name": "Alquimia Ofrecida", "desc": "Recibes hasta 2 pociones aleatorias."},
}

## Qué ofrece cada entidad (mismo orden que FavorScreen.ENTITY).
const POOLS := [
	["egida", "regen", "inspiracion", "vida_oro", "balsamo"],           # La Dama de las Mareas: protección y vida
	["espinas", "agilidad", "regen", "balsamo", "carta", "pocion"],      # El Ciervo Antiguo: naturaleza
	["oro_botin", "egida", "fuerza", "carta", "vida_oro"],               # La Reina Dorada: riqueza
	["reliquia_duda", "temple", "oro_sangre", "inspiracion", "mal_de_ojo"],  # El Ángel Caído: pactos y dilemas
	["furia_pacto", "fuerza", "oro_sangre", "reliquia_duda", "temple"],  # El Demonio Cortés: poder a cambio de sangre
	["mal_de_ojo", "inspiracion", "agilidad", "carta", "pocion", "balsamo"],  # El Ente de la Luna: sueño y misterio
]


static func icon_path(id: String) -> String:
	return "res://assets/ui/favor/%s.webp" % id


## 3 opciones distintas del pool de la entidad `ent`; siempre al menos un bufo.
static func offer(G, ent: int = 0) -> Array:
	var pool: Array = POOLS[ent].filter(func(i): return available(G, i))
	var buffs := pool.filter(func(i): return DEFS[i].kind == "buff")
	var out := []
	if not buffs.is_empty():
		out.append(Eng.pick(G, buffs))
	for i in Eng.shuffle(G, pool.filter(func(i): return not (i in out))):
		if out.size() >= 3:
			break
		out.append(i)
	return Eng.shuffle(G, out)


static func available(G, id: String) -> bool:
	if id == "reliquia_duda":
		return Eng.random_relic(G) != null
	if id == "balsamo":
		return G.hp <= G.maxHp * 0.75   # curar con la vida casi llena no sirve de nada
	if id == "pocion":
		return G.potions.has(null)
	if id == "temple":
		return G.deck.any(func(c): return Eng.can_upgrade(c))
	return true


static func choose(G, id: String) -> String:
	## Aplica el favor; devuelve un texto de resumen para el aviso.
	var d: Dictionary = DEFS[id]
	if d.kind == "buff":
		G["favor"] = {"id": id, "act": G.act}
		return d.name
	match id:
		"oro_sangre":
			Eng.gain_gold(G, 120)
			G.hp = maxi(1, G.hp - 12)
		"reliquia_duda":
			var r = Eng.random_relic(G)
			if r != null:
				Eng.add_relic(G, r)
			G.deck.append(Eng.make_card(G, "doubt"))
		"vida_oro":
			G.maxHp += 12
			G.hp += 12
			G.gold = maxi(0, G.gold - 60)
		"temple":
			var ups: Array = G.deck.filter(func(c): return Eng.can_upgrade(c))
			for c in Eng.shuffle(G, ups).slice(0, 2):
				c.up = true
			G.hp = maxi(1, G.hp - 8)
		"balsamo":
			G.hp = mini(G.maxHp, G.hp + ceili(G.maxHp * 0.4))
		"pocion":
			for i in 2:
				if G.potions.has(null):
					G.potions[G.potions.find(null)] = Eng.pick(G, DB.potions.keys())
		"carta":
			var pl: Array = Eng.unlocked(G, DB.pool[G.char])
			var c := pl.filter(func(x): return DB.cards[x].rarity == "uncommon")
			G.deck.append(Eng.make_card(G, Eng.pick(G, c if not c.is_empty() else pl), true))
	return d.name


## Caduca el bufo cuando termina el acto.
static func expire(G) -> void:
	G.erase("favor")


static func active(G) -> Dictionary:
	var f = G.get("favor")
	if f == null or int(f.act) != G.act:
		return {}
	return DEFS[f.id]


static func on_combat_start(C) -> void:
	var f = C.G.get("favor")
	if f == null or int(f.act) != C.G.act:
		return
	match f.id:
		"fuerza": Eng.add_status(C, C.pl, "strength", 1)
		"inspiracion": C.firstTurnDraw += 2
		"espinas": Eng.add_status(C, C.pl, "thorns", 3)
		"agilidad": Eng.add_status(C, C.pl, "dexterity", 1)
		"mal_de_ojo":
			for e in C.enemies:
				Eng.add_status(C, e, "vulnerable", 1)
		"furia_pacto":
			Eng.add_status(C, C.pl, "strength", 2)
			Eng.add_status(C, C.pl, "weak", 1)


## Tras robar la mano inicial (start_turn borra el Bloqueo previo).
static func on_first_turn(C) -> void:
	var f = C.G.get("favor")
	if f != null and f.id == "egida" and int(f.act) == C.G.act:
		C.pl.block += 8


static func is_active(G, id: String) -> bool:
	var f = G.get("favor")
	return f != null and f.id == id and int(f.act) == G.act


static func on_combat_end(G) -> void:
	if is_active(G, "regen"):
		G.hp = mini(G.maxHp, G.hp + 5)
