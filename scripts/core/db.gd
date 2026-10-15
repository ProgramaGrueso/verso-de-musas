class_name DB
extends RefCounted
## Carga de datos (JSON exportado del juego web). Todo en diccionarios, con enteros reales.

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


static func load_all() -> void:
	if loaded:
		return
	loaded = true
	var c := _read("cards")
	cards = c.cards; pool = c.pool; starters = c.starters
	var ch := _read("characters")
	characters = ch.characters; sprites = ch.sprites
	var en := _read("enemies")
	enemies = en.enemies; encounters = en.encounters; acts = en.acts
	var rl := _read("relics")
	relics = rl.relics; potions = rl.potions
	events = _read("events").events
	var lo := _read("lore")
	lore = lo.lore; nm_texts = lo.nm; ending = lo.ending
	var s := _read("states")
	st = s.st; orb = s.orb; glos = s.glos
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
