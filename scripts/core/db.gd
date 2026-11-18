class_name DB
extends RefCounted
## Carga de datos (JSON exportado del juego web). Todo en diccionarios, con enteros reales.

## Contenido añadido tras el port (cartas de la Oleada 1). Las trazas de paridad con el web lo desactivan.
static var extra := true
static var neutral: Array = []
static var loaded := false
static var cards := {}
static var pool := {}
static var starters := {}
static var characters := {}
static var sprites := {}
static var enemies := {}
static var encounters := {}
static var acts := []
static var relics := {}
static var potions := {}
static var events := []
static var lore := []
static var nm_texts := []
static var ending := {}
static var st := {}
static var orb := {}
static var glos := {}
static var music_gains := {}
## Ajustes de equilibrio de la Oleada 2 (data/balance_w2.json). Solo con DB.extra: las trazas no los ven.
static var bal := {}


static func _intify(v):
	match typeof(v):
		TYPE_FLOAT:
			if v == floorf(v) and absf(v) < 1e15:
				return int(v)
			return v
		TYPE_ARRAY:
			for i in v.size():
				v[i] = _intify(v[i])
			return v
		TYPE_DICTIONARY:
			for k in v.keys():
				v[k] = _intify(v[k])
			return v
	return v


static func _read(name: String) -> Dictionary:
	var txt := FileAccess.get_file_as_string("res://data/%s.json" % name)
	var d = JSON.parse_string(txt)
	assert(d != null, "JSON inválido: " + name)
	return _intify(d)


## Mezcla recursiva: los ajustes de equilibrio cambian solo las claves que indican (p. ej. un movimiento).
static func _deep(base: Dictionary, over: Dictionary) -> Dictionary:
	for k in over.keys():
		if base.get(k) is Dictionary and over[k] is Dictionary:
			base[k] = _deep(base[k], over[k])
		else:
			base[k] = over[k]
	return base


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var c := _read("cards")
	cards = c.cards; pool = c.pool; starters = c.starters
	var ex := _read("cards_extra")
	cards.merge(ex.cards)
	if extra:
		for k in ex.pool.keys():
			if k == "neutral":
				neutral = ex.pool[k]
			else:
				pool[k] = pool[k] + ex.pool[k]
	var ch := _read("characters")
	characters = ch.characters; sprites = ch.sprites
	var en := _read("enemies")
	enemies = en.enemies; encounters = en.encounters; acts = en.acts
	var rl := _read("relics")
	relics = rl.relics; potions = rl.potions
	events = _read("events").events
	# Oleada 2 (tools/make_content_w2.py): enemigos, encuentros, reliquias, pociones y eventos nuevos
	var en2 := _read("enemies_extra")
	enemies.merge(en2.enemies)   # definiciones: no alteran ningún sorteo por sí solas
	if extra:
		bal = _read("balance_w2")
		for id in bal.get("enemies", {}).keys():
			if enemies.has(id):
				enemies[id] = _deep(enemies[id].duplicate(true), bal.enemies[id])
		for id in bal.get("cards", {}).keys():
			if cards.has(id):
				cards[id] = _deep(cards[id].duplicate(true), bal.cards[id])
		for id in bal.get("chars", {}).keys():
			if characters.has(id):
				characters[id] = _deep(characters[id].duplicate(true), bal.chars[id])
		for id in bal.get("relics", {}).keys():
			if relics.has(id):
				relics[id] = _deep(relics[id].duplicate(true), bal.relics[id])
		for k in en2.encounters.keys():
			var A: Dictionary = encounters[k]
			var X: Dictionary = en2.encounters[k]
			A["easy"] = X.easy
			A["hard"] = X.hard
			A["elite"] = A.elite + X.elite
			A["boss"] = A.boss + X.boss
		var rl2 := _read("relics_extra")
		relics.merge(rl2.relics)
		potions.merge(rl2.potions)
		events = events + _read("events_extra").events
	var lo := _read("lore")
	lore = lo.lore; nm_texts = lo.nm; ending = lo.ending
	if extra and bal.has("nm_texts"):
		nm_texts = bal.nm_texts   # escalera de Pesadilla rediseñada (solo con la Oleada 2)
	var s := _read("states")
	st = s.st; orb = s.orb; glos = s.glos
	st.merge(_read("states_extra").st)
	music_gains = _read("music").gains
	# las claves de encuentros por acto llegan como texto ("1"); el motor las usa como entero
	var enc := {}
	for k in encounters.keys():
		enc[int(k)] = encounters[k]
	encounters = enc


static func playable() -> Array:
	var out := []
	for id in characters.keys():
		if characters[id].implemented:
			out.append(id)
	return out
