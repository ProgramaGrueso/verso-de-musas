class_name Favors
extends RefCounted
## Favor de las Musas: bendición elegida al empezar cada acto (1 de 3 opciones aleatorias).
## Los bufos duran el acto; los pactos y regalos se aplican al momento. G.favor = {id, act} guarda el bufo activo.

const DEFS := {
	"fuerza": {"kind": "buff", "name": "Furia de Calíope", "icon": "⚔", "desc": "Este acto: empiezas cada combate con +1 de Fuerza."},
	"egida": {"kind": "buff", "name": "Égida de Clío", "icon": "🛡", "desc": "Este acto: empiezas cada combate con 8 de Bloqueo."},
	"inspiracion": {"kind": "buff", "name": "Inspiración de Erato", "icon": "✦", "desc": "Este acto: robas 2 cartas más en el primer turno de cada combate."},
	"espinas": {"kind": "buff", "name": "Coro de Melpómene", "icon": "✺", "desc": "Este acto: empiezas cada combate con 3 de Espinas."},
	"agilidad": {"kind": "buff", "name": "Danza de Terpsícore", "icon": "❖", "desc": "Este acto: empiezas cada combate con +1 de Destreza."},
	"oro_sangre": {"kind": "trade", "name": "Oro a cambio de sangre", "icon": "◆", "desc": "Ganas 120 de oro. Pierdes 12 PV."},
	"reliquia_duda": {"kind": "trade", "name": "Reliquia a cambio de Duda", "icon": "♛", "desc": "Obtienes una reliquia aleatoria. Añades la maldición Duda a tu mazo."},
	"vida_oro": {"kind": "trade", "name": "Vigor a cambio de oro", "icon": "♥", "desc": "Ganas 12 PV máx. Pierdes 60 de oro (o todo el que tengas)."},
	"carta": {"kind": "card", "name": "Regalo de la Musa", "icon": "🃏", "desc": "Añades a tu mazo una carta mejorada elegida al azar de tu musa."},
}


static func offer(G) -> Array:
	## 3 opciones distintas: siempre al menos un bufo.
	var ids := DEFS.keys()
	var buffs := ids.filter(func(i): return DEFS[i].kind == "buff")
	var out: Array = [Eng.pick(G, buffs)]
	var rest := ids.filter(func(i): return not (i in out))
	for i in Eng.shuffle(G, rest).slice(0, 2):
		out.append(i)
	return Eng.shuffle(G, out)


static func available(G, id: String) -> bool:
	if id == "reliquia_duda":
		return Eng.random_relic(G) != null
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
		"carta":
			var pl: Array = DB.pool[G.char]
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


## Tras robar la mano inicial (start_turn borra el Bloqueo previo).
static func on_first_turn(C) -> void:
	var f = C.G.get("favor")
	if f != null and f.id == "egida" and int(f.act) == C.G.act:
		C.pl.block += 8
