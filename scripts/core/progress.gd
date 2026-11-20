class_name Progress
extends RefCounted
## Progresión a largo plazo (Fase 3): logros, desbloqueo de contenido y Maestría por musa.
## Definiciones en data/progress.json. Todo es estático y recibe el diccionario de Meta.data para poder
## probarlo sin interfaz (tests/progress_test.gd). Las condiciones leen Meta.data.s igual que la Galería.
## Solo se bloquea contenido de la Oleada 1/2 y solo con DB.extra: las trazas del web no ven ningún bloqueo.

static var _defs := {}
static var _groups: Array = []
static var _lock_of := {}   # id de carta/reliquia -> grupo que la desbloquea


static func defs() -> Dictionary:
	if _defs.is_empty():
		DB.load_all()
		_defs = DB._read("progress")
		DB.loc_register("progress", _defs, DB.LOC_FIELDS_PROGRESS)   # nombres/textos traducidos en su sitio
		_build_groups()
	return _defs


## Tras cambiar de idioma (DB.relocalize): los grupos son copias de «unlocks», se rehacen con los textos nuevos.
static func relocalize() -> void:
	if not _defs.is_empty():
		_build_groups()


static func achievements() -> Array:
	return defs().achievements


static func cats() -> Array:
	return defs().cats


static func ranks() -> Array:
	return defs().mastery.ranks


## Grupos de desbloqueo con sus cartas y reliquias resueltas (los que quedan vacíos se descartan).
static func groups() -> Array:
	defs()
	return _groups


static func _build_groups() -> void:
	_groups = []
	_lock_of = {}
	var ex: Dictionary = DB._read("cards_extra").pool
	for g0 in _defs.unlocks:
		var g: Dictionary = g0.duplicate(true)
		var cards := []
		var pool_id: String = g.get("pool", "")
		if pool_id != "" and ex.has(pool_id):
			for id in ex[pool_id]:
				if DB.cards.has(id) and DB.cards[id].rarity in g.rar:
					cards.append(id)
		var rel := []
		for id in g.relics:
			if DB.relics.has(id):
				rel.append(id)
		g["cards"] = cards
		g["relics"] = rel
		if cards.is_empty() and rel.is_empty():
			continue
		_groups.append(g)
		for id in cards + rel:
			_lock_of[id] = g


## Ruta del arte de un logro: "lore:id", "bg:id", "enemy:id" o "muse:id".
static func art_path(spec: String) -> String:
	var p := spec.split(":")
	if p.size() < 2:
		return ""
	match p[0]:
		"lore": return "res://assets/lore/%s.webp" % p[1]
		"bg": return "res://assets/bg/%s.webp" % p[1]
		"enemy": return "res://assets/enemies/%s.webp" % p[1]
		"muse": return "res://assets/ui/%s_icon.png" % p[1]
	return ""


# ---------- Condiciones ----------
static func value(data: Dictionary, v: Dictionary) -> int:
	var s: Dictionary = data.get("s", {})
	if v.has("stat"):
		return int(s.get(v.stat, 0))
	if v.has("min"):
		var m := 1 << 30
		for k in v.min:
			m = mini(m, int(s.get(k, 0)))
		return m
	if v.has("sum"):
		var n := 0
		for k in s.keys():
			if str(k).begins_with(v.sum):
				n += int(s[k])
		return n
	if v.has("count"):
		var n := 0
		for k in s.keys():
			if str(k).begins_with(v.count) and int(s[k]) > 0:
				n += 1
		return n
	if v.has("relics"):
		return data.get("relics", []).size()
	if v.has("unlocks"):
		return unlocked_groups(data).size()
	if v.has("mastery"):
		var best := 0
		for c in DB.playable():
			best = maxi(best, mastery_rank(data, c) + 1)
		return best
	return 0


## Meta de una condición (t = -1 significa «todos los grupos de desbloqueo»).
static func target(a: Dictionary) -> int:
	var t := int(a.t)
	return groups().size() if t < 0 else t


static func ach_progress(data: Dictionary, a: Dictionary) -> int:
	return mini(target(a), value(data, a.v))


static func has_ach(data: Dictionary, id: String) -> bool:
	var d = data.get("ach", {})
	return d is Dictionary and d.has(id)


static func ach_count(data: Dictionary) -> int:
	var n := 0
	for a in achievements():
		if has_ach(data, a.id):
			n += 1
	return n


static func find_ach(id: String) -> Dictionary:
	for a in achievements():
		if a.id == id:
			return a
	return {}


static func unlocked_groups(data: Dictionary) -> Array:
	var u = data.get("unl", [])
	return u if u is Array else []


## Revisa grupos y logros. Marca en data los nuevos y los devuelve: {"unl": [grupos], "ach": [logros]}.
## Primero los grupos (el logro «Archivo Completo» depende de ellos).
static func check(data: Dictionary) -> Dictionary:
	if not (data.get("ach") is Dictionary):
		data["ach"] = {}
	if not (data.get("unl") is Array):
		data["unl"] = []
	var out := {"unl": [], "ach": []}
	for g in groups():
		if not (g.id in data.unl) and value(data, g.v) >= int(g.t):
			data.unl.append(g.id)
			out.unl.append(g)
	var now := int(Time.get_unix_time_from_system())
	for a in achievements():
		if not data.ach.has(a.id) and value(data, a.v) >= target(a):
			data.ach[a.id] = now
			out.ach.append(a)
	return out


# ---------- Desbloqueo de contenido ----------
## Cartas y reliquias todavía bloqueadas. Sin contenido ampliado (DB.extra = false) nunca hay bloqueos.
static func locked_ids(data: Dictionary) -> Array:
	if not DB.extra:
		return []
	var out := []
	var u := unlocked_groups(data)
	for g in groups():
		if not (g.id in u):
			out.append_array(g.cards)
			out.append_array(g.relics)
	return out


## Grupo que desbloquea esa carta o reliquia ({} si siempre está disponible).
static func lock_group(id: String) -> Dictionary:
	defs()
	return _lock_of.get(id, {})


static func is_locked(data: Dictionary, id: String) -> bool:
	if not DB.extra:
		return false
	var g := lock_group(id)
	return not g.is_empty() and not (g.id in unlocked_groups(data))


## Texto del contenido de un grupo: «3 cartas poco comunes de Zafiro y Estandarte Acorazado».
static func group_text(g: Dictionary) -> String:
	var parts := []
	if not g.cards.is_empty():
		var rar_n := {"common": "comunes", "uncommon": "poco comunes", "rare": "raras"}   # loc-strings
		var rr := ""
		for r in g.rar:
			var w := DB.tl(rar_n.get(r, r))
			rr = w if rr == "" else _and(rr, w)
		var n: int = g.cards.size()
		if g.pool == "neutral":
			parts.append(DB.tln("{n} cartas {rar} neutrales", "{n} cartas {rar} neutrales", n).format({"n": n, "rar": rr}))
		else:
			parts.append(DB.tln("{n} cartas {rar} de {muse}", "{n} cartas {rar} de {muse}", n).format({"n": n, "rar": rr, "muse": DB.characters[g.pool].name}))
	var names := []
	for id in g.relics:
		names.append(DB.relics[id].n)
	if not names.is_empty():
		parts.append(DB.tln("la reliquia {list}", "las reliquias {list}", names.size()).format({"list": ", ".join(names)}))
	var out := ""
	for p in parts:
		out = p if out == "" else _and(out, p)
	return out


## «A y B» en el idioma activo.
static func _and(a: String, b: String) -> String:
	return DB.tl("{a} y {b}").format({"a": a, "b": b})


## Icono que representa un grupo: [tipo, id] para Icons, o ["muse", id].
static func group_icon(g: Dictionary) -> Array:
	if not g.relics.is_empty():
		return ["relic", g.relics[0]]
	if DB.characters.has(g.pool):
		return ["muse", g.pool]
	return ["ui", "deck"]


# ---------- Maestría por musa ----------
## Puntos que da una victoria: 1, +1 en Pesadilla 4+, +1 en Pesadilla 8+. En modo fácil no suma.
static func mastery_gain(nm: int, easy: bool) -> int:
	if easy:
		return 0
	return 1 + (1 if nm >= 4 else 0) + (1 if nm >= 8 else 0)


static func mastery_points(data: Dictionary, c: String) -> int:
	return int(data.get("s", {}).get("mp_" + c, 0))


## Índice del rango alcanzado (-1 = sin rango).
static func mastery_rank(data: Dictionary, c: String) -> int:
	var p := mastery_points(data, c)
	var r := -1
	var rk := ranks()
	for i in rk.size():
		if p >= int(rk[i].t):
			r = i
	return r


static func rank_name(i: int) -> String:
	return ranks()[i].n if i >= 0 and i < ranks().size() else DB.tl("Sin rango")


static func rank_color(i: int) -> Color:
	return Color(ranks()[i].c) if i >= 0 and i < ranks().size() else Color("#a79fc0")


# ---------- Resumen compartible ----------
## Texto plano para copiar y pegar: musa + semilla + resultado (y el reto diario si lo es).
static func share_text(G, won: bool) -> String:
	var name: String = DB.characters[G.char].name
	var nm := int(G.get("nm", 0))
	var tags := []
	if nm > 0:
		tags.append(DB.tl("Pesadilla {n}").format({"n": nm}))
	if G.get("easy", false):
		tags.append(DB.tl("modo fácil"))
	var head := DB.tl("Verso de Musas · Victoria con {muse}" if won else "Verso de Musas · Derrota con {muse}").format({"muse": name})
	if not tags.is_empty():
		head += " · " + ", ".join(tags)
	var act := clampi(int(G.get("act", 1)), 1, 3)
	var line2: String
	var fl := int(G.floor)
	if won:
		var bid := RunGen.boss_id(G)
		var boss: String = DB.enemies[bid].name if DB.enemies.has(bid) else DB.tl("la Reina")
		line2 = DB.tl("Coronada en la cima ante {boss} (piso {f})").format({"boss": boss, "f": fl})
	elif G.get("surrender", false):
		line2 = DB.tl("Rendida en {act} (piso {f})").format({"act": DB.acts[act - 1].name, "f": fl})
	else:
		var by := DB.death_by_text(str(G.get("deathBy", "")))
		if by != "":
			line2 = DB.tl("Cayó en {act} ante {by} (piso {f})").format({"act": DB.acts[act - 1].name, "by": by, "f": fl})
		else:
			line2 = DB.tl("Cayó en {act} (piso {f})").format({"act": DB.acts[act - 1].name, "f": fl})
	var st: Dictionary = G.get("stats", {})
	var nums := [int(st.get("fights", 0)), int(st.get("kills", 0)), int(st.get("turns", 0)), G.deck.size(), G.relics.size()]
	var line3 := " · ".join([
		DB.tln("{n} combates", "{n} combates", nums[0]).format({"n": nums[0]}),
		DB.tln("{n} enemigos", "{n} enemigos", nums[1]).format({"n": nums[1]}),
		DB.tln("{n} turnos", "{n} turnos", nums[2]).format({"n": nums[2]}),
		DB.tln("mazo de {n} cartas", "mazo de {n} cartas", nums[3]).format({"n": nums[3]}),
		DB.tln("{n} reliquias", "{n} reliquias", nums[4]).format({"n": nums[4]})])
	var lines := [head, line2, line3]
	if str(G.get("daily", "")) != "":
		lines.append(DB.tl("Reto diario {key} ({mod})").format({"key": G.daily, "mod": Daily.mod_name(str(G.get("dailyMod", "")))}))
	lines.append(DB.tl("Semilla: {seed} — ¿la superas?").format({"seed": int(G.seed)}))
	return "\n".join(lines)
