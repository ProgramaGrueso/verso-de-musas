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

# ---------- Localización del contenido (Fase 5) ----------
## El español es el idioma fuente: los JSON siguen en español y la clave de cada traducción es el propio texto
## (msgid = español, translations/content_en.po). Tras cargar, los campos de texto de los datos se traducen EN SU
## SITIO (DB.cards[id].name, DB.relics[id].d…), así la interfaz los lee igual que siempre. El español original se
## guarda aparte y relocalize() los vuelve a traducir al cambiar de idioma. Los ids no cambian: las partidas
## guardadas son compatibles. tools/extract_content_loc.py usa la MISMA lista de campos (LOC_FIELDS).
const LOC_FIELDS := {
	"cards": ["*/name"],
	"characters": ["*/name", "*/role", "*/desc"],
	"enemies": ["*/name", "*/moves/*/name", "*/phase2/msg"],
	"acts": ["*/name", "*/sub"],
	"relics": ["*/n", "*/d"],
	"potions": ["*/n", "*/d"],
	"events": ["*/title", "*/text", "*/textBy/*"],
	"lore": ["*/title", "*/ch", "*/text"],
	"nm_texts": ["*"],
	"ending": ["scenes/*/text", "scenes/*/alt/*", "scenes/*/altBoss/*", "nightmare/text", "final"],
	"st": ["*/n", "*/d"],
	"orb": ["*/n", "*/d"],
	"glos": ["*"],
}
const LOC_FIELDS_PROGRESS := ["cats/*/n", "achievements/*/n", "achievements/*/d", "unlocks/*/ch", "mastery/ranks/*/n"]
static var _loc: Array = []       # [contenedor, clave, español] de los datos de DB (se rehace en cada load_all)
static var _loc_ext: Array = []   # ídem de otros módulos (Progress, Favors): sobreviven a una recarga de DB
static var _loc_src := {}         # "raíz/ruta" -> español (p. ej. "orb/ola/n" -> "Ola")
static var _loc_ext_done := false


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
	_loc_collect_all()
	relocalize()


# ---------- Localización ----------
## Traduce un texto en español (msgid) al idioma activo. Con «es» (o sin traducción) devuelve el mismo texto.
static func tl(s: String) -> String:
	if s == "":
		return s
	return String(TranslationServer.translate(s))


## Igual con plural: tln("Roba {n} carta.", "Roba {n} cartas.", n). No sustituye {n}: eso lo hace quien llama.
static func tln(s: String, plural: String, n: int) -> String:
	return String(TranslationServer.translate_plural(s, plural, n))


## Texto español original de un campo localizado ("orb/ola/n" -> "Ola"); "" si no existe.
static func es(path: String) -> String:
	return _loc_src.get(path, "")


## Registra un diccionario de otro módulo para traducirlo en su sitio (lo usan Progress y Favors).
static func loc_register(root: String, obj, fields: Array) -> void:
	for f in fields:
		_loc_walk(_loc_ext, root, obj, String(f).split("/"), 0, root)
	_loc_apply(_loc_ext)


static func _loc_collect_all() -> void:
	_loc = []
	var roots := {"cards": cards, "characters": characters, "enemies": enemies, "acts": acts, "relics": relics,
		"potions": potions, "events": events, "lore": lore, "nm_texts": nm_texts, "ending": ending, "st": st,
		"orb": orb, "glos": glos}
	for r in LOC_FIELDS.keys():
		for f in LOC_FIELDS[r]:
			_loc_walk(_loc, r, roots[r], String(f).split("/"), 0, r)
	if not _loc_ext_done:
		_loc_ext_done = true
		loc_register("favors", Favors.DEFS, ["*/name", "*/desc"])


static func _loc_walk(out: Array, root: String, obj, segs: PackedStringArray, i: int, path: String) -> void:
	var s := segs[i]
	var keys := []
	if obj is Dictionary:
		if s == "*":
			keys = obj.keys()
		elif obj.has(s):
			keys = [s]
	elif obj is Array and s == "*":
		keys = range(obj.size())
	for k in keys:
		var v = obj[k]
		var p := "%s/%s" % [path, str(k)]
		if i == segs.size() - 1:
			if v is String and v != "":
				out.append([obj, k, v])
				_loc_src[p] = v
		else:
			_loc_walk(out, root, v, segs, i + 1, p)


static func _loc_apply(list: Array) -> void:
	for e in list:
		e[0][e[1]] = tl(e[2])


## Vuelve a traducir todo el contenido al idioma activo (lo llama load_all y Sfx al cambiar el locale;
## quien cambie de idioma a mano puede llamarlo también: es idempotente y barato).
static func relocalize() -> void:
	_loc_apply(_loc)
	_loc_apply(_loc_ext)
	Eng.clear_def_cache()
	CardText.relocalize()
	Progress.relocalize()


static func playable() -> Array:
	var out := []
	for id in characters.keys():
		if characters[id].implemented:
			out.append(id)
	return out
