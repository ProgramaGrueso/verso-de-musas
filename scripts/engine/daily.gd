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
	return DB.tl(MODS[mod].name) if MODS.has(mod) else ""


static func mod_desc(mod: String) -> String:
	return DB.tl(MODS[mod].desc) if MODS.has(mod) else ""


## Crea la partida del reto (con su mapa del acto I).
static func new_run(key: String) -> Dictionary:
	var inf := info(key)
	var G := Eng.new_run(inf.char, {"seed": inf.seed})
	G["seeded"] = true
	G["daily"] = key
	G["dailyMod"] = inf.mod
	G.erase("locked")   # el reto es igual para todo el mundo: todo el contenido disponible
	if key != key_today():
		G["dailyLate"] = true   # revancha de un día pasado: no cuenta para la racha
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


# ---------- Histórico: racha, calendario y código para compartir ----------
## Día siguiente/anterior de una clave AAAA-MM-DD (en UTC, sin husos que la desplacen).
static func shift(key: String, days: int) -> String:
	var u := Time.get_unix_time_from_datetime_string(key + "T12:00:00")
	return Time.get_date_string_from_unix_time(u + days * 86400)


## Racha de retos superados el mismo día. cur: la que sigue viva (hoy o, si hoy aún no, hasta ayer).
static func streak(d: Dictionary, today: String = "") -> Dictionary:
	if today == "":
		today = key_today()
	var won := func(k: String) -> bool: return d.has(k) and d[k] is Dictionary and d[k].get("win", false)
	var cur := 0
	var k := today if won.call(today) else shift(today, -1)
	while won.call(k):
		cur += 1
		k = shift(k, -1)
	var best := 0
	var run := 0
	var prev := ""
	var keys: Array = d.keys()
	keys.sort()
	for key in keys:
		if not won.call(key):
			continue
		run = run + 1 if prev != "" and shift(prev, 1) == key else 1
		prev = key
		best = maxi(best, run)
	return {"cur": cur, "best": maxi(best, cur)}


## Estado de un día para el calendario: "win", "late" (superado fuera de plazo), "tried", "none" o "future".
static func day_state(d: Dictionary, key: String, today: String = "") -> String:
	if today == "":
		today = key_today()
	if key > today:
		return "future"
	var r = d.get(key, {})
	if not (r is Dictionary) or r.is_empty():
		return "none"
	if r.get("win", false):
		return "win"
	if r.get("lateWin", false):
		return "late"
	return "tried" if int(r.get("tries", 0)) > 0 else "none"


## Días del mes (claves AAAA-MM-DD) y el día de la semana del primero (0 = lunes).
static func month_days(year: int, month: int) -> Dictionary:
	var first := "%04d-%02d-01" % [year, month]
	var u := Time.get_unix_time_from_datetime_string(first + "T12:00:00")
	var wd: int = (int(Time.get_datetime_dict_from_unix_time(u).weekday) + 6) % 7
	var keys := []
	var k := first
	while k.begins_with("%04d-%02d" % [year, month]):
		keys.append(k)
		k = shift(k, 1)
	return {"keys": keys, "first_wd": wd}


## Mes anterior/siguiente: Vector2i(año, mes).
static func shift_month(v: Vector2i, n: int) -> Vector2i:
	var m := v.y - 1 + n
	return Vector2i(v.x + floori(m / 12.0), posmod(m, 12) + 1)


## Texto para compartir un reto: cualquiera puede jugar el mismo día desde el calendario.
static func share_text(key: String, res: Dictionary = {}) -> String:
	var inf := info(key)
	var lines := [DB.tl("Verso de Musas · Reto diario {key}").format({"key": key}),
		"%s · %s (%s)" % [DB.characters[inf.char].name, mod_name(inf.mod), mod_desc(inf.mod)],
		DB.tl("Semilla: {seed}").format({"seed": inf.seed})]
	if not res.is_empty():
		var tries := int(res.get("tries", 1))
		if res.get("win", false):
			lines.append(DB.tln("Mi resultado: superado en {n} intento", "Mi resultado: superado en {n} intentos", tries).format({"n": tries}))
		elif int(res.get("floor", 0)) > 0:
			lines.append(DB.tln("Mi resultado: piso {f} en {n} intento", "Mi resultado: piso {f} en {n} intentos", tries).format({"f": int(res.floor), "n": tries}))
	lines.append(DB.tl("¿Lo superas?"))
	return "\n".join(lines)
