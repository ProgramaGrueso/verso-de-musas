class_name Eng
extends RefCounted
## Motor de combate y de partida de Verso de Musas (port 1:1 de engine.js). Sin nodos ni interfaz.
## El estado son diccionarios (G = partida, C = combate) para que el código siga el original línea a línea.
## Los efectos visuales/sonoros se emiten con C.fx (Callable(type, datos)).

const DEBUFFS := ["vulnerable", "weak", "frail"]
const WIND_MAX := 10

static var meta_add := Callable()
static var meta_max := Callable()
static var meta_see_relic := Callable()
static var _def_cache := {}


# ---------- Meta (estadísticas entre partidas) ----------
static func _mt(k: String, n: int = 1) -> void:
	if meta_add.is_valid():
		meta_add.call(k, n)

static func _mx(k: String, n: int) -> void:
	if meta_max.is_valid():
		meta_max.call(k, n)

static func _fx(C, type: String, d: Dictionary = {}) -> void:
	if C.fx.is_valid():
		C.fx.call(type, d)


# ---------- Aleatorio con estado serializable (mulberry32, idéntico al web) ----------
static func _i32(x: int) -> int:
	return ((x + 0x80000000) & 0xFFFFFFFF) - 0x80000000

static func rnd(G) -> float:
	G.rs = _i32(G.rs + 0x6d2b79f5)
	var t: int = G.rs
	t = _i32((t ^ ((t & 0xFFFFFFFF) >> 15)) * (t | 1))
	t = t ^ _i32(t + _i32((t ^ ((t & 0xFFFFFFFF) >> 7)) * (t | 61)))
	return float((t ^ ((t & 0xFFFFFFFF) >> 14)) & 0xFFFFFFFF) / 4294967296.0

static func rint(G, a: int, b: int) -> int:
	return a + floori(rnd(G) * (b - a + 1))

static func pick(G, arr: Array):
	return arr[floori(rnd(G) * arr.size())]

static func shuffle(G, arr: Array) -> Array:
	var i := arr.size() - 1
	while i > 0:
		var j := floori(rnd(G) * (i + 1))
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp
		i -= 1
	return arr


# ---------- Estados ----------
static func get_s(c, k: String) -> int:
	return c.status.get(k, 0)

static func st_name(k: String) -> String:
	return DB.st[k].n

static func st_icon(k: String) -> String:
	return DB.st[k].i

static func st_desc(k: String, n: int) -> String:
	var t: String = DB.st[k].d
	if k == "strength":
		t = t.replace("menos", "extra" if n > 0 else "menos")
	return t.replace("{n}", str(n))

static func st_neg(k: String, n: int) -> bool:
	return DB.st[k].negn if n < 0 else DB.st[k].negp

static func add_status(C, c, k: String, n: int) -> void:
	if n == 0:
		return
	if k == "poison" and n > 0 and not is_same(c, C.pl) and has_relic(C.G, "colmillo_vibora"):
		n += 1
	var s: Dictionary = c.status
	s[k] = s.get(k, 0) + n
	if k == "poison" and n > 0 and not is_same(c, C.pl):
		_mt("poison", n)
	if s[k] == 0 or (s[k] < 0 and k != "strength" and k != "dexterity"):
		s.erase(k)
	if is_same(c, C.pl) and C.phase == "enemy" and k in DEBUFFS:
		if not c.has("_fresh"):
			c["_fresh"] = {}
		c["_fresh"][k] = true
	_fx(C, "status", {"who": c, "k": k, "n": n})


# ---------- Cartas ----------
static func make_card(G, id: String, up: bool = false) -> Dictionary:
	G.uid += 1
	return {"uid": G.uid, "id": id, "up": up}

static func card_def(inst: Dictionary) -> Dictionary:
	var key: String = inst.id + ("+" if inst.up else "")
	if _def_cache.has(key):
		return _def_cache[key]
	var b: Dictionary = DB.cards[inst.id]
	var d: Dictionary = b.duplicate()
	d.fx = b.fx.duplicate()
	d.flags = b.flags.duplicate()
	if inst.up and not b.up.is_empty():
		var u: Dictionary = b.up
		if u.has("cost"):
			d.cost = u.cost
		if u.has("fx"):
			d.fx.merge(u.fx, true)
		if u.has("flags"):
			d.flags.merge(u.flags, true)
		d.name = b.name + "+"
	_def_cache[key] = d
	return d

static func can_upgrade(inst: Dictionary) -> bool:
	var b: Dictionary = DB.cards[inst.id]
	return not inst.up and not b.up.is_empty() and not (b.type in ["status", "curse"])

static func needs_target(d: Dictionary) -> bool:
	var f: Dictionary = d.fx
	if f.get("all", false):
		return false
	for k in ["dmg", "dmgBlock", "dmgPerOrb", "windSpend", "ostyHit", "vuln", "weak", "poison", "poisonMul", "glow"]:
		if f.get(k, 0):
			return true
	return false

static func is_x(cost) -> bool:
	return typeof(cost) == TYPE_STRING


# ---------- Cálculo de daño y bloqueo ----------
static func calc_damage(base: int, src: Dictionary, dst, extra_str: int = 1) -> int:
	var d: int = base + src.get("strength", 0) * extra_str
	if src.get("weak", 0) != 0:
		d = floori(d * 0.75)
	if dst != null and dst.get("vulnerable", 0) != 0:
		d = floori(d * 1.5)
	return maxi(0, d)

static func calc_block(C, base: int) -> int:
	var b: int = base + get_s(C.pl, "dexterity")
	if get_s(C.pl, "frail"):
		b = floori(b * 0.75)
	return maxi(0, b)

# vista previa para el texto de las cartas
static func preview_dmg(C, d: Dictionary, target) -> int:
	var f: Dictionary = d.fx
	var base: int = C.pl.block if f.get("dmgBlock", false) else f.get("dmg", 0)
	if f.get("dmgPerOrb", 0):
		base += f.dmgPerOrb * C.orbs.size()
	if f.get("windDmg", 0):
		base += f.windDmg * get_s(C.pl, "cuerda")
	if f.get("windSpend", 0):
		base += f.windSpend * get_s(C.pl, "cuerda")
	if d.get("gear", false):
		base += get_s(C.pl, "precision")
	if f.get("heatDmg", 0):
		base += get_s(C.pl, "heat") * f.heatDmg
	if d.id == "lia_shiv":
		base += get_s(C.pl, "accuracy")
	if f.get("poisonDbl", false) and target != null and get_s(target, "poison"):
		base *= 2
	if f.get("heatMul", 0) and get_s(C.pl, "heat"):
		base = floori(base * f.heatMul)
	return calc_damage(base, C.pl.status, target.status if target != null else null, f.get("strMul", 1))


# ---------- Modificadores de Pesadilla ----------
static func nm_mods(n: int) -> Dictionary:
	return {
		"hp": 1 + (0.25 if n >= 7 else 0.1 if n >= 1 else 0.0),
		"dmg": 1 + (0.25 if n >= 9 else 0.1 if n >= 2 else 0.0),
		"gold": 0.75 if n >= 4 else 1.0,
		"rest": 0.2 if n >= 6 else 0.3,
		"doubt": n >= 3,
		"eliteStr": 2 if n >= 5 else 0,
		"wound": n >= 8,
		"allStr": 1 if n >= 10 else 0,
		"bossStr": 4 if n >= 10 else (2 if n >= 5 else 0),
	}

static func nmods(G) -> Dictionary:
	return nm_mods(G.get("nm", 0))


# ---------- Reliquias ----------
static func relic_hook(C, name: String, a = null) -> void:
	for id in C.G.relics:
		Relics.run(id, name, C, a)

static func has_relic(G, id: String) -> bool:
	return id in G.relics


# ---------- Semillas ----------
## Convierte el texto que escribe el jugador en una semilla (los números se usan tal cual).
static func seed_from_text(t: String) -> int:
	t = t.strip_edges()
	if t == "":
		return 0
	if t.is_valid_int() and int(t) > 0:
		return int(t) % 1000000000
	var h := 0
	for ch in t.to_lower().to_utf8_buffer():
		h = (h * 31 + ch) % 999999937
	return maxi(1, h)

## Estado del RNG al empezar cada acto en partidas con semilla fija (no depende de lo jugado antes).
static func act_seed(seed_v: int, act: int) -> int:
	return _i32(seed_v * 7919 + act * 104729 + 1)


# ---------- Nueva partida ----------
static func new_run(char: String, opts: Dictionary = {}) -> Dictionary:
	var seed_v: int = opts.get("seed", 0)
	if seed_v == 0:
		seed_v = randi() % 1000000000
	var G := {
		"char": char, "seed": seed_v, "rs": 0, "uid": 0, "easy": opts.get("easy", false), "hp": 0, "maxHp": 0, "gold": 99,
		"deck": [], "relics": [DB.characters[char].startRelic], "potions": [null, null, null], "act": 1, "floor": 0, "map": null, "pos": null,
		"stats": {"kills": 0, "turns": 0, "fights": 0}, "seenEvents": [], "nm": opts.get("nm", 0), "removed": 0,
	}
	G.rs = seed_v
	G.easy = G.easy and G.nm == 0
	G.maxHp = DB.characters[char].hp + (25 if G.easy else 0)
	G.hp = G.maxHp
	for id in DB.starters[char]:
		G.deck.append(make_card(G, id))
	if G.nm and nmods(G).doubt:
		G.deck.append(make_card(G, "doubt"))
	_mt("runs")
	if meta_see_relic.is_valid():
		meta_see_relic.call(DB.characters[char].startRelic)
	return G


# ---------- Combate ----------
static func spawn_enemy(C, id: String) -> Dictionary:
	var def: Dictionary = DB.enemies[id]
	var G = C.G
	var hp: int = floori(rint(G, def.hp[0], def.hp[1]) * nmods(G).hp + 0.5)
	G.uid += 1
	return {"uid": G.uid, "id": id, "def": def, "name": def.name, "hp": hp, "maxHp": hp, "block": def.get("startBlock", 0),
		"status": {}, "turn": 0, "hist": [], "intent": null, "moveKey": null}

static func start_combat(G, ids: Array, opts: Dictionary = {}) -> Dictionary:
	var C := {
		"G": G, "pl": {"block": 0, "status": {}}, "enemies": [], "draw": [], "hand": [], "discard": [], "exhaust": [], "energy": 0, "maxEnergy": 3,
		"turn": 0, "phase": "player", "prompt": null, "over": "", "osty": null, "orbs": [], "orbMax": 3, "maestroUsed": false,
		"tier": opts.get("tier", "normal"), "playedThisTurn": 0, "attacksThisTurn": 0, "fx": opts.get("fx", Callable()),
		"extraDraw": 0, "firstTurnDraw": 0, "hpLost": 0,
	}
	for id in ids:
		C.enemies.append(spawn_enemy(C, id))
	if G.nm:
		var m := nmods(G)
		for e in C.enemies:
			var st_: int = (m.bossStr if e.def.tier == "boss" else (m.eliteStr if e.def.tier == "elite" else 0)) + m.allStr
			if st_:
				e.status["strength"] = st_
	var cp := []
	for c in G.deck:
		cp.append(c.duplicate())
	C.draw = shuffle(G, cp)
	# innatas arriba
	var inn := []
	var rest := []
	for c in C.draw:
		if card_def(c).flags.get("innate", false):
			inn.append(c)
		else:
			rest.append(c)
	C.draw = rest + inn
	if DB.characters[G.char].has("osty"):
		C.osty = DB.characters[G.char].osty.duplicate()
	relic_hook(C, "onCombatStart")
	Favors.on_combat_start(C)
	apply_perm(C)
	if G.nm and nmods(G).wound:
		add_cards(C, "wound", 1, "draw")
	for e in C.enemies:
		choose_intent(C, e)
	start_turn(C)
	Favors.on_first_turn(C)
	return C

## Bendiciones permanentes de la partida (eventos exclusivos de cada musa): G.perm = {estado: n, ostyMax, ostyPow}.
static func apply_perm(C) -> void:
	var perm = C.G.get("perm")
	if perm == null:
		return
	for k in perm.keys():
		var n: int = perm[k]
		if k == "ostyMax":
			if C.osty != null:
				C.osty.max += n
				C.osty.hp += n
		elif k == "ostyPow":
			if C.osty != null:
				C.osty.pow += n
		else:
			add_status(C, C.pl, k, n)

static func perm_text(G) -> String:
	var perm = G.get("perm")
	if perm == null or perm.is_empty():
		return ""
	var parts := []
	for k in perm.keys():
		if k == "ostyMax":
			parts.append("Osty +%d PV máx." % perm[k])
		elif k == "ostyPow":
			parts.append("Osty +%d de Poder" % perm[k])
		elif DB.st.has(k):
			parts.append("+%d de %s" % [perm[k], st_name(k)])
	return ", ".join(parts)

static func add_perm(G, k: String, n: int) -> void:
	if not G.has("perm") or G.perm == null:
		G["perm"] = {}
	G.perm[k] = G.perm.get(k, 0) + n

static func living(C) -> Array:
	var out := []
	for e in C.enemies:
		if e.hp > 0:
			out.append(e)
	return out

static func draw_cards(C, n: int) -> int:
	var drawn := 0
	for i in n:
		if C.hand.size() >= 10:
			_fx(C, "handFull")
			break
		if C.draw.is_empty():
			if C.discard.is_empty():
				break
			var tmp: Array = C.discard.duplicate()
			C.discard.clear()
			C.draw = shuffle(C.G, tmp)
			_fx(C, "reshuffle")
			relic_hook(C, "onShuffle")
		C.hand.append(C.draw.pop_back())
		drawn += 1
	if drawn:
		_fx(C, "draw", {"n": drawn})
	return drawn

static func add_cards(C, id: String, n: int, to: String, up: bool = false) -> void:
	for i in n:
		var c := make_card(C.G, id, up)
		if to == "hand" and C.hand.size() < 10:
			C.hand.append(c)
		elif to == "draw":
			C.draw.insert(floori(rnd(C.G) * (C.draw.size() + 1)), c)
		else:
			C.discard.append(c)
	_fx(C, "addCards", {"id": id, "n": n, "to": to})

static func start_turn(C) -> void:
	C.turn += 1
	C.phase = "player"
	C.playedThisTurn = 0
	C.attacksThisTurn = 0
	C.G.stats.turns += 1
	if not get_s(C.pl, "barricade"):
		C.pl.block = 0
	C.pl.status.erase("tthorns")
	C.pl.status.erase("mirage")
	C.pl.status.erase("reflect")
	C.energy = C.maxEnergy
	C.maestroUsed = false
	var S: Dictionary = C.pl.status
	if S.get("demon", 0):
		add_status(C, C.pl, "strength", S.demon)
	if S.get("incand", 0):
		add_status(C, C.pl, "heat", S.incand)
		for e in living(C):
			add_status(C, e, "glow", 1)
	if S.get("noxious", 0):
		for e in living(C):
			add_status(C, e, "poison", S.noxious)
	if S.get("resorte", 0):
		gain_wind(C, S.resorte)
	if S.get("perpetuum", 0):
		gain_wind(C, S.perpetuum)
		draw_cards(C, S.perpetuum)
	if S.get("marea_alta", 0):
		for i in S.marea_alta:
			channel_orb(C, "ola")
	if S.get("perlera", 0):
		for i in S.perlera:
			channel_orb(C, "perla")
	for o in C.orbs:
		if o.t == "perla":
			C.energy += orb_passive(C, o)
			_fx(C, "orbTick")
	if C.osty != null and C.turn > 1:
		if C.osty.hp <= 0:
			C.osty.hp = 1   # revive solo con 1 PV
			_fx(C, "ostyRevive")
		else:
			osty_heal(C, 1)   # y se cura 1 PV por turno
	if S.get("ostyRegen", 0) and C.osty != null and C.osty.hp > 0:
		osty_heal(C, S.ostyRegen)
	if S.get("regen", 0):
		var rg: int = S.regen
		C.G.hp = mini(C.G.maxHp, C.G.hp + rg)
		_fx(C, "heal", {"n": rg})
		add_status(C, C.pl, "regen", -1)
	relic_hook(C, "onTurnStart")
	draw_cards(C, 5 + C.extraDraw)
	if C.turn == 1 and C.firstTurnDraw:
		draw_cards(C, C.firstTurnDraw)
	_fx(C, "turnStart")

static func lose_hp(C, n: int) -> void:
	var G = C.G
	G.hp -= n
	C.hpLost += n
	_fx(C, "playerHit", {"amt": n, "blocked": 0, "direct": true})
	if G.hp <= 0:
		_player_down(C)

## PV a 0: derrota, salvo que la Pluma de Fénix (una vez por partida) te levante.
static func _player_down(C) -> void:
	var G = C.G
	if has_relic(G, "pluma") and not G.get("plumaUsed", false):
		G["plumaUsed"] = true
		G.hp = maxi(1, ceili(G.maxHp * 0.3))
		_fx(C, "heal", {"n": G.hp})
		return
	G.hp = 0
	C.over = "lose"

# Un Osty caído solo se cura si la carta lo revive explícitamente; si no, vuelve solo al inicio del turno.
static func osty_heal(C, n: int, revive: bool = false) -> void:
	var o = C.osty
	if o == null:
		return
	if o.hp <= 0 and not revive:
		_fx(C, "ostyDown")
		return
	var before: int = o.hp
	o.hp = mini(o.max, maxi(o.hp, 0) + n)
	_fx(C, "ostyHeal", {"n": o.hp - before})

# daño al jugador: bloqueo -> Osty -> PV
static func deal_to_player(C, amt: int, src, no_thorns: bool = false) -> int:
	var blocked: int = mini(C.pl.block, amt)
	C.pl.block -= blocked
	amt -= blocked
	var osty_abs := 0
	if amt > 0 and C.osty != null and C.osty.hp > 0:
		osty_abs = mini(C.osty.hp, amt)
		C.osty.hp -= osty_abs
		amt -= osty_abs
		_fx(C, "ostyHit", {"amt": osty_abs, "dead": C.osty.hp <= 0})
	if amt > 0:
		C.G.hp -= amt
		C.hpLost += amt
		if C.G.hp <= 0:
			_player_down(C)
	if blocked > 0:
		_mt("block", blocked)
	_fx(C, "playerHit", {"amt": amt, "blocked": blocked, "ostyAbs": osty_abs, "src": src})
	if not no_thorns and src != null and src.hp > 0:
		var mir := get_s(C.pl, "mirage")
		if mir:
			C.pl.status.erase("mirage")
			deal_to_enemy(C, src, mir, {"thorns": true})
		if blocked > 0 and get_s(C.pl, "reflect") and src.hp > 0:
			deal_to_enemy(C, src, floori(blocked / 2.0), {"thorns": true})
	if not no_thorns and src != null and src.hp > 0:
		var th := get_s(C.pl, "thorns") + get_s(C.pl, "tthorns")
		if th:
			deal_to_enemy(C, src, th, {"thorns": true})
	return amt

static func deal_to_enemy(C, e, amt: int, o: Dictionary = {}) -> int:
	if e.hp <= 0:
		return 0
	var blocked: int = mini(e.block, amt)
	if not o.get("thorns", false) and not o.get("poison", false) and not o.get("osty", false) and not o.get("noReflect", false):
		_mx("maxHit", amt)
	e.block -= blocked
	amt -= blocked
	e.hp -= amt
	_fx(C, "enemyHit", {"e": e, "amt": amt, "blocked": blocked, "osty": o.get("osty", false), "thorns": o.get("thorns", false)})
	if not o.get("thorns", false) and not o.get("osty", false) and amt + blocked > 0 and get_s(e, "thorns") and not o.get("noReflect", false):
		var t := get_s(e, "thorns")
		C.G.hp -= t
		_fx(C, "playerHit", {"amt": t, "blocked": 0, "direct": true})
		if C.G.hp <= 0:
			_player_down(C)
	if e.hp <= 0:
		kill_enemy(C, e, o)
	return amt

static func kill_enemy(C, e, o) -> void:
	e.hp = 0
	C.G.stats.kills += 1
	_mt("kills")
	if e.def.tier == "elite":
		_mt("elites")
		if not (C.hpLost > 0):
			_mt("flawlessElite")
	if e.def.tier == "boss":
		_mt("boss_" + e.id)
	_fx(C, "enemyDie", {"e": e})
	relic_hook(C, "onKill", e)
	if e.def.tier == "boss":
		for x in C.enemies:
			if x.hp > 0 and not is_same(x, e):
				x.hp = 0
				_fx(C, "enemyDie", {"e": x})
	if o != null and o.has("fatal"):
		o.fatal.call(e)
	if living(C).is_empty() and C.over == "":
		C.over = "win"


# ---------- IA de enemigos ----------
static func _ai_key(C, e) -> String:
	var ai: Dictionary = e.def.ai
	match ai.t:
		"fixed":
			return ai.key
		"cyc":
			return ai.seq[e.turn % ai.seq.size()]
		"first_alt":
			return ai.first if e.turn == 0 else (ai.odd if e.turn % 2 == 1 else ai.even)
		"rnd":
			var pool := []
			for i in ai.keys.size():
				pool.append([ai.keys[i], ai.w[i]])
			var h: Array = e.hist
			if h.size() >= 2 and h[h.size() - 1] == h[h.size() - 2]:
				var last = h[h.size() - 1]
				pool = pool.filter(func(p): return p[0] != last)
			var tot := 0
			for p in pool:
				tot += p[1]
			var r := rnd(C.G) * tot
			for p in pool:
				r -= p[1]
				if r < 0:
					return p[0]
			return pool[0][0]
	return _ai_custom(C, e)

static func _ai_custom(C, e) -> String:
	var alive := living(C).size()
	match e.id:
		"rootmother":
			if e.turn == 0:
				return "summon"
			var seq := ["crush", "lash", "root", "harvest"]
			if e.turn % 5 == 0 and alive < 3:
				return "summon"
			return seq[(e.turn - 1) % seq.size()]
		"nurse":
			if e.turn % 3 == 2 and alive < 4:
				return "call"
			return "sting" if e.turn % 3 == 0 else "feed"
		"hivemind":
			var seq2 := ["mind", "swarm", "wave", "strike"]
			return seq2[e.turn % seq2.size()]
		"queen":
			if e.turn == 0:
				return "summon"
			if e.hp < e.maxHp * 0.5 and not e.get("enraged", false):
				e["enraged"] = true
				return "order"
			var seq3 := ["royal", "rain", "ram", "jelly", "summon", "rain"]
			return seq3[(e.turn - 1) % seq3.size()]
		"drowncaptain":
			if e.turn == 0:
				return "abordaje"
			var seq4 := ["canon", "andanada", "ancla", "ron", "abordaje"]
			var k4: String = seq4[(e.turn - 1) % seq4.size()]
			if k4 == "abordaje" and alive >= 3:
				return "canon"
			return k4
		"mycelking":
			if e.turn == 0:
				return "colonia"
			var seq5 := ["aplastar", "esporas", "pudrir", "festin", "colonia"]
			var k5: String = seq5[(e.turn - 1) % seq5.size()]
			if k5 == "colonia" and alive >= 3:
				return "aplastar"
			return k5
		"waxcolossus":
			if e.hp < e.maxHp * 0.5 and not e.get("enraged", false):
				e["enraged"] = true
				return "fundirse"
			var seq6 := ["sello", "aplastar", "goteo", "cera", "endurecer"]
			return seq6[e.turn % seq6.size()]
	push_error("IA desconocida: " + e.id)
	return e.def.moves.keys()[0]

static func choose_intent(C, e) -> void:
	var key := _ai_key(C, e)
	e.moveKey = key
	e.hist.append(key)
	e.intent = e.def.moves[key].duplicate()

static func intent_damage(C, e) -> int:
	var it = e.intent
	if it == null or not it.get("dmg", 0):
		return 0
	var d := calc_damage(it.dmg - (3 if get_s(e, "glow") else 0), e.status, C.pl.status)
	if C.G.easy:
		d = maxi(1, floori(d * 0.8))
	elif C.G.nm:
		d = maxi(1, floori(d * nmods(C.G).dmg + 0.5))
	return d

static func run_enemy_turn(C, e) -> void:
	if e.hp <= 0 or C.over != "":
		return
	e.block = 0
	var p := get_s(e, "poison")
	if p:
		e.hp -= p
		_fx(C, "enemyHit", {"e": e, "amt": p, "blocked": 0, "poison": true})
		add_status(C, e, "poison", -1)
		if e.hp <= 0:
			kill_enemy(C, e, null)
			return
	var it: Dictionary = e.intent
	var glow := get_s(e, "glow")
	if glow and it.get("dmg", 0):
		deal_to_enemy(C, e, glow, {"noReflect": true, "glow": true})
		if get_s(C.pl, "noon"):
			draw_cards(C, 1)
		if e.hp <= 0:
			return
	_fx(C, "enemyAct", {"e": e, "it": it})
	if it.get("block", 0):
		e.block += it.block
		_fx(C, "enemyBlock", {"e": e, "n": it.block})
	if it.get("selfStr", 0):
		add_status(C, e, "strength", it.selfStr)
	if it.get("thorns", 0):
		add_status(C, e, "thorns", it.thorns)
	if it.get("heal", 0):
		e.hp = mini(e.maxHp, e.hp + it.heal)
		_fx(C, "enemyHeal", {"e": e, "n": it.heal})
	if it.get("healAll", 0):
		for x in living(C):
			x.hp = mini(x.maxHp, x.hp + it.healAll)
			_fx(C, "enemyHeal", {"e": x, "n": it.healAll})
	if it.has("summon"):
		var i := 0
		while i < it.summon.n and living(C).size() < 5:
			var ne := spawn_enemy(C, it.summon.id)
			choose_intent(C, ne)
			ne["fresh"] = true
			C.enemies.append(ne)
			_fx(C, "enemySpawn", {"e": ne})
			i += 1
	if it.get("dmg", 0):
		var hits: int = it.get("hits", 1)
		var h := 0
		while h < hits and C.over == "" and e.hp > 0:
			deal_to_player(C, intent_damage(C, e), e)
			h += 1
	if it.has("apply") and C.over == "":
		for k in it.apply.keys():
			add_status(C, C.pl, k, it.apply[k])
	if it.has("add") and C.over == "":
		add_cards(C, it.add.id, it.add.n, it.add.to)
	e.turn += 1

# tras actuar todos los enemigos
static func end_round(C) -> void:
	for e in C.enemies:
		if e.hp <= 0:
			continue
		for k in DEBUFFS + ["glow"]:
			if e.status.get(k, 0):
				e.status[k] -= 1
				if e.status[k] <= 0:
					e.status.erase(k)
		if not e.get("fresh", false):
			choose_intent(C, e)
		else:
			e["fresh"] = false
	var pl = C.pl
	var fresh: Dictionary = pl.get("_fresh", {})
	for k in DEBUFFS:
		if pl.status.get(k, 0) and not fresh.get(k, false):
			pl.status[k] -= 1
			if pl.status[k] <= 0:
				pl.status.erase(k)
	pl["_fresh"] = {}


# ---------- Orbes (Selene) ----------
static func focus_of(C) -> int:
	return get_s(C.pl, "resonancia")

static func orb_passive(C, o: Dictionary) -> int:
	return maxi(0, DB.orb[o.t].pas + (0 if o.t == "perla" else focus_of(C)))

static func orb_evoke(C, o: Dictionary) -> int:
	if o.t == "abismo":
		return o.v
	return maxi(0, DB.orb[o.t].evo + (0 if o.t == "perla" else focus_of(C)))

static func orb_desc(C, o: Dictionary) -> String:
	return DB.orb[o.t].d.replace("{p}", str(orb_passive(C, o))).replace("{e}", str(orb_evoke(C, o)))

static func evoke_one(C, o: Dictionary) -> int:
	var v := orb_evoke(C, o)
	if o.t == "ola":
		var l := living(C)
		if not l.is_empty():
			deal_to_enemy(C, pick(C.G, l), v, {"noReflect": true, "orb": true})
	elif o.t == "bruma":
		C.pl.block += v
		_fx(C, "block", {"n": v})
	elif o.t == "abismo":
		var l2 := living(C)
		if not l2.is_empty():
			var low = l2[0]
			for x in l2:
				if x.hp < low.hp:
					low = x
			deal_to_enemy(C, low, v, {"noReflect": true, "orb": true})
	elif o.t == "perla":
		C.energy += v
	_fx(C, "orbEvoke", {"o": o})
	return v

static func evoke_front(C, times: int) -> void:
	if C.orbs.is_empty():
		return
	var o = C.orbs.pop_front()
	var i := 0
	while i < times and C.over == "":
		evoke_one(C, o)
		i += 1
	_mt("orbEvokes", times)

static func channel_orb(C, t: String) -> void:
	if C.orbs.size() >= C.orbMax:
		evoke_front(C, 1)
	C.orbs.append({"t": t, "v": 6 if t == "abismo" else 0})
	_mt("orbs")
	_fx(C, "orbChannel", {"t": t})
	var cr := get_s(C.pl, "corriente")
	if cr:
		C.pl.block += cr
		_fx(C, "block", {"n": cr})

static func orb_tick(C, o: Dictionary) -> void:
	if o.t == "ola":
		var l := living(C)
		if not l.is_empty():
			deal_to_enemy(C, pick(C.G, l), orb_passive(C, o), {"noReflect": true, "orb": true})
	elif o.t == "bruma":
		var n := orb_passive(C, o)
		C.pl.block += n
		_fx(C, "block", {"n": n})
	elif o.t == "abismo":
		o.v += orb_passive(C, o)

static func orbs_end_turn(C) -> void:
	for o in C.orbs.duplicate():
		if C.over != "":
			return
		orb_tick(C, o)
	var lp := get_s(C.pl, "bucle")
	if lp and not C.orbs.is_empty():
		var i := 0
		while i < lp and C.over == "":
			orb_tick(C, C.orbs[0])
			i += 1
	if not C.orbs.is_empty():
		_fx(C, "orbTick")


# ---------- Cuerda (Irene) ----------
static func gain_wind(C, n: int) -> void:
	var cur := get_s(C.pl, "cuerda")
	var add := mini(n, WIND_MAX - cur)
	if add > 0:
		add_status(C, C.pl, "cuerda", add)

static func spend_wind(C, n: int) -> int:
	n = mini(n, get_s(C.pl, "cuerda"))
	if n <= 0:
		return 0
	add_status(C, C.pl, "cuerda", -n)
	if has_relic(C.G, "muelle_doble"):
		C.pl.block += n
		_fx(C, "block", {"n": n})
	var tt := get_s(C.pl, "tictac")
	if tt:
		for i in n:
			var l := living(C)
			if not l.is_empty():
				deal_to_enemy(C, pick(C.G, l), tt, {"noReflect": true})
	_mt("windSpent", n)
	return n

static func replay_gear(C, d: Dictionary, target, X: int, prev_attack: bool) -> void:
	if C.over != "" or living(C).is_empty():
		return
	var free := false
	if get_s(C.pl, "maestro") and not C.maestroUsed:
		C.maestroUsed = true
		free = true
	if not free and not get_s(C.pl, "cuerda"):
		return
	if not free:
		spend_wind(C, 1)
	if C.over != "" or living(C).is_empty():
		return
	var t = target if (target != null and target.hp > 0) else living(C)[0]
	_fx(C, "replay", {"d": d})
	run_fx(C, d, t, X, prev_attack)


# ---------- Jugar cartas ----------
# coste real de la carta ahora mismo (Solio Supremo vuelve gratis las cartas de Danza)
static func eff_cost(C, d: Dictionary):
	if d.get("dance", false) and C != null and get_s(C.pl, "apoth") and not is_x(d.cost) and d.cost > 0:
		return 0
	return d.cost

static func card_cost(C, inst: Dictionary):
	var d := card_def(inst)
	if is_x(d.cost):
		return C.energy
	return eff_cost(C, d)

static func can_play(C, inst: Dictionary) -> Dictionary:
	if C.over != "" or C.phase != "player" or C.prompt != null:
		return {"ok": false, "why": "No puedes jugar ahora."}
	var d := card_def(inst)
	if d.flags.get("unplayable", false) or (not is_x(d.cost) and d.cost == -1):
		return {"ok": false, "why": "Esta carta no se puede jugar."}
	if not is_x(d.cost) and eff_cost(C, d) > C.energy:
		return {"ok": false, "why": "No tienes suficiente energía."}
	return {"ok": true}

static func play_card(C, uid: int, target = null) -> bool:
	var idx := -1
	for i in C.hand.size():
		if C.hand[i].uid == uid:
			idx = i
			break
	if idx < 0:
		return false
	var inst: Dictionary = C.hand[idx]
	var d := card_def(inst)
	if not can_play(C, inst).ok:
		return false
	if needs_target(d) and (target == null or target.hp <= 0):
		var l := living(C)
		if l.size() == 1:
			target = l[0]
		else:
			return false
	var X := 0
	if is_x(d.cost):
		X = C.energy
		C.energy = 0
	else:
		C.energy -= eff_cost(C, d)
	C.hand.remove_at(idx)
	C.playedThisTurn += 1
	_mt("cards")
	var stt: Dictionary = C.G.stats
	if not stt.has("played"):
		stt["played"] = {}
	stt.played[inst.id] = stt.played.get(inst.id, 0) + 1
	var prev_attack: bool = C.attacksThisTurn > 0
	if d.type == "attack":
		C.attacksThisTurn += 1
	_fx(C, "play", {"card": inst, "d": d, "target": target})
	relic_hook(C, "onCardPlayed", {"inst": inst, "d": d})
	run_fx(C, d, target, X, prev_attack)
	var echoes := 0
	if has_relic(C.G, "cristal") and not C.get("echoUsed", false):
		C["echoUsed"] = true
		echoes += 1
	if C.get("dupNext", false):
		C.erase("dupNext")
		echoes += 1
	for _i in echoes:
		_echo(C, d, target, X, prev_attack)
	if d.get("gear", false):
		replay_gear(C, d, target, X, prev_attack)
	var cuts := get_s(C.pl, "cuts")
	if cuts:
		for e in living(C):
			deal_to_enemy(C, e, cuts, {"noReflect": true})
	if d.type == "power":
		pass   # se consume
	elif d.flags.get("exhaust", false):
		exhaust_card(C, inst, true)
	else:
		C.discard.append(inst)
	if living(C).is_empty() and C.over == "":
		C.over = "win"
	return true

## Repite el efecto de una carta ya jugada (sin volver a pagarla).
static func _echo(C, d: Dictionary, target, X: int, prev_attack: bool) -> void:
	if C.over != "" or living(C).is_empty():
		return
	var t = target
	if needs_target(d) and (t == null or t.hp <= 0):
		t = living(C)[0]
	_fx(C, "replay", {"d": d})
	run_fx(C, d, t, X, prev_attack)

static func exhaust_card(C, inst: Dictionary, _played: bool = false) -> void:
	C.exhaust.append(inst)
	_fx(C, "exhaust", {"card": inst})
	var S: Dictionary = C.pl.status
	if S.get("boneDance", 0):
		C.pl.block += calc_block(C, S.boneDance)
		_fx(C, "block", {"n": S.boneDance})
	if S.get("darkEmbrace", 0):
		draw_cards(C, S.darkEmbrace)
	if has_relic(C.G, "grimorio") and not living(C).is_empty():
		deal_to_enemy(C, pick(C.G, living(C)), 3, {"noReflect": true})

static func run_fx(C, d: Dictionary, target, X: int, prev_attack: bool) -> void:
	var f: Dictionary = d.fx
	var pl = C.pl
	var heat_before := get_s(pl, "heat")
	var tgts := []
	if f.get("all", false):
		tgts = living(C)
	elif target != null:
		tgts = [target]
	if f.get("selfdmg", 0):
		lose_hp(C, f.selfdmg)
		if has_relic(C.G, "guantelete") and C.over == "":
			pl.block += 4
			_fx(C, "block", {"n": 4})
	if f.get("energy", 0):
		C.energy += f.energy
	if f.get("str", 0):
		add_status(C, pl, "strength", f.str)
	if f.get("dex", 0):
		add_status(C, pl, "dexterity", f.dex)
	if f.get("tstr", 0):
		add_status(C, pl, "strength", f.tstr)
		add_status(C, pl, "tstr", f.tstr)
	if f.get("doubleStr", false) and get_s(pl, "strength") > 0:
		add_status(C, pl, "strength", get_s(pl, "strength"))
	if f.get("doubleBlock", false):
		var b0: int = pl.block
		pl.block += b0
		_fx(C, "block", {"n": b0})
	if f.get("wind", 0):
		gain_wind(C, f.wind)
	if f.get("windDouble", false):
		gain_wind(C, get_s(pl, "cuerda"))
	if f.get("slots", 0):
		C.orbMax = mini(10, C.orbMax + f.slots)
	if f.get("focus", 0):
		add_status(C, pl, "resonancia", f.focus)
	if f.has("ch"):
		for t in f.ch:
			channel_orb(C, t)
	if f.get("evoke", 0):
		evoke_front(C, f.evoke)
	if f.get("evokeX", false):
		evoke_front(C, X)
	if f.get("evokeAll", false):
		var n: int = C.orbs.size()
		var i := 0
		while i < n and C.over == "":
			evoke_front(C, 1)
			i += 1
	if f.get("block", 0) or f.get("blockPerOrb", 0):
		var b := calc_block(C, f.get("block", 0) + f.get("blockPerOrb", 0) * C.orbs.size())
		pl.block += b
		_fx(C, "block", {"n": b})
		var pr := get_s(pl, "prism")
		if pr and not living(C).is_empty():
			deal_to_enemy(C, pick(C.G, living(C)), pr, {"noReflect": true})
	if f.get("heat", 0):
		add_status(C, pl, "heat", f.heat)
	if f.get("heatDouble", false) and get_s(pl, "heat"):
		add_status(C, pl, "heat", get_s(pl, "heat"))
	if f.get("mirage", 0):
		add_status(C, pl, "mirage", f.mirage)
	if f.get("reflect", false):
		add_status(C, pl, "reflect", 1)
	if f.get("energyIfAttack", 0) and prev_attack:
		C.energy += f.energyIfAttack
	if f.get("energyIfGlow", 0) and target != null and get_s(target, "glow"):
		C.energy += f.energyIfGlow
	if f.has("pw"):
		for k in f.pw.keys():
			add_status(C, pl, k, f.pw[k])
	if f.get("summon", 0) and C.osty != null:
		C.osty.max += f.summon
		if C.osty.hp > 0:
			C.osty.hp += f.summon
			_fx(C, "ostyHeal", {"n": f.summon})
	if f.get("ostyPow", 0) and C.osty != null:
		C.osty.pow += f.ostyPow
		_fx(C, "ostyPow")
	if f.get("ostyHeal", 0) and C.osty != null:
		osty_heal(C, f.ostyHeal, f.get("revive", false))
	if f.get("dmg", 0) or f.get("dmgBlock", false) or f.get("dmgPerOrb", 0) or f.get("windSpend", 0):
		var hits: int = X if f.get("x", false) else f.get("hits", 1)
		var healed := 0
		var heat := get_s(pl, "heat")
		if heat and (f.get("heatDmg", 0) or f.get("heatMul", 0)):
			pl.status.erase("heat")   # el remate consume el Calor
		var block_snap: int = pl.block
		var wind_now := get_s(pl, "cuerda")
		if f.get("windSpend", 0) and wind_now:
			spend_wind(C, wind_now)
		for h in hits:
			for t in tgts:
				if t.hp <= 0:
					continue
				var base: int = block_snap if f.get("dmgBlock", false) else f.get("dmg", 0)
				if f.get("dmgPerOrb", 0):
					base += f.dmgPerOrb * C.orbs.size()
				if f.get("windDmg", 0):
					base += f.windDmg * wind_now
				if f.get("windSpend", 0):
					base += f.windSpend * wind_now
				if d.get("gear", false):
					base += get_s(pl, "precision")
				if f.get("heatDmg", 0):
					base += heat * f.heatDmg
				if f.get("heatMul", 0) and heat:
					base = floori(base * f.heatMul)
				if d.id == "lia_shiv":
					base += get_s(pl, "accuracy")
				if f.get("poisonDbl", false) and get_s(t, "poison"):
					base *= 2
				var amt := calc_damage(base, pl.status, t.status, f.get("strMul", 1))
				var o := {}
				if f.get("fatalMax", 0):
					var fm: int = f.fatalMax
					o["fatal"] = func(_e):
						C.G.maxHp += fm
						C.G.hp += fm
						_fx(C, "maxhp", {"n": fm})
				var loss := deal_to_enemy(C, t, amt, o)
				if f.get("lifesteal", false):
					healed += loss
		if healed:
			C.G.hp = mini(C.G.maxHp, C.G.hp + healed)
			_fx(C, "heal", {"n": healed})
		if f.get("dmgBlock", false) and f.get("loseBlock", false):
			pl.block = 0
	if f.get("ostyHit", 0) and C.osty != null:
		if C.osty.hp <= 0:
			_fx(C, "ostyDown")
		else:
			var cleave: bool = get_s(pl, "ostyCleave") != 0 or f.get("all", false)
			var hits2: int = f.get("hits", 1)
			for h in hits2:
				var ts := []
				if cleave:
					ts = living(C)
				elif target != null and target.hp > 0:
					ts = [target]
				for t in ts:
					deal_to_enemy(C, t, calc_damage(f.ostyHit + C.osty.pow, {}, t.status), {"osty": true})
			_fx(C, "ostyAttack")
			_mt("ostyHits")
	if f.get("vuln", 0):
		for t in tgts:
			if t.hp > 0:
				add_status(C, t, "vulnerable", f.vuln)
	if f.get("weak", 0):
		for t in tgts:
			if t.hp > 0:
				add_status(C, t, "weak", f.weak)
	if f.get("glow", 0):
		for t in tgts:
			if t.hp > 0:
				add_status(C, t, "glow", f.glow)
	if f.get("poison", 0):
		for t in tgts:
			if t.hp > 0:
				add_status(C, t, "poison", f.poison)
	if f.get("poisonMul", 0) and target != null and target.hp > 0 and get_s(target, "poison"):
		add_status(C, target, "poison", get_s(target, "poison") * (f.poisonMul - 1))
	if f.get("heal", 0):
		C.G.hp = mini(C.G.maxHp, C.G.hp + f.heal)
		_fx(C, "heal", {"n": f.heal})
	if f.get("draw", 0):
		draw_cards(C, f.draw)
	if f.get("drawIfHeat", 0) and heat_before:
		draw_cards(C, f.drawIfHeat)
	if f.has("add"):
		add_cards(C, f.add.id, f.add.n, f.add.to)
	if f.get("stormOfSteel", false):
		var n2: int = C.hand.size()
		while not C.hand.is_empty():
			C.discard.append(C.hand.pop_back())
		add_cards(C, "lia_shiv", n2, "hand")
	if f.get("discard", 0) and not C.hand.is_empty():
		ask_prompt(C, "discard", f.discard)
	if f.get("exhaustPick", 0) and not C.hand.is_empty():
		ask_prompt(C, "exhaust", f.exhaustPick)

static func ask_prompt(C, kind: String, n: int) -> void:
	n = mini(n, C.hand.size())
	if n >= C.hand.size():
		var uids := []
		for c in C.hand:
			uids.append(c.uid)
		resolve_prompt(C, uids, {"kind": kind, "n": n})
		return
	C.prompt = {"kind": kind, "n": n}

static func resolve_prompt(C, uids: Array, p = null) -> void:
	if p == null:
		p = C.prompt
	if p == null:
		return
	C.prompt = null
	for uid in uids.slice(0, p.n):
		var i := -1
		for j in C.hand.size():
			if C.hand[j].uid == uid:
				i = j
				break
		if i < 0:
			continue
		var c: Dictionary = C.hand[i]
		C.hand.remove_at(i)
		if p.kind == "discard":
			C.discard.append(c)
			_fx(C, "discard", {"card": c})
		else:
			exhaust_card(C, c)


# ---------- Fin de turno del jugador ----------
static func end_player_turn(C) -> void:
	if C.over != "" or C.phase != "player" or C.prompt != null:
		return
	C.phase = "enemy"
	var S: Dictionary = C.pl.status
	for c in C.hand.duplicate():
		var d := card_def(c)
		if d.has("endHand"):
			if d.endHand.get("selfdmg", 0):
				deal_to_player(C, d.endHand.selfdmg, null, true)
			if d.endHand.get("weakSelf", 0):
				add_status(C, C.pl, "weak", d.endHand.weakSelf)
	if C.over != "":
		return
	relic_hook(C, "onTurnEnd")
	if S.get("metallicize", 0):
		C.pl.block += S.metallicize
		_fx(C, "block", {"n": S.metallicize})
	if S.get("combust", 0):
		lose_hp(C, 1)
		if C.over == "":
			for e in living(C):
				deal_to_enemy(C, e, S.combust, {"noReflect": true})
	if not C.orbs.is_empty() and C.over == "":
		orbs_end_turn(C)
	if S.get("corona", 0) and C.pl.block > 0 and C.over == "":
		for e in living(C):
			deal_to_enemy(C, e, C.pl.block * S.corona, {"noReflect": true})
	if C.osty != null and C.osty.hp > 0 and C.osty.pow > 0 and not living(C).is_empty() and C.over == "":
		var ts := []
		if S.get("ostyCleave", 0):
			ts = living(C)
		else:
			ts = [pick(C.G, living(C))]
		for t in ts:
			deal_to_enemy(C, t, calc_damage(C.osty.pow, {}, t.status), {"osty": true})
		_fx(C, "ostyAttack")
		_mt("ostyHits")
	# descartar mano
	var kept := []
	var hand: Array = C.hand.duplicate()
	C.hand.clear()
	for c in hand:
		var d2 := card_def(c)
		if d2.flags.get("ethereal", false):
			exhaust_card(C, c)
		elif d2.flags.get("retain", false):
			kept.append(c)
		else:
			C.discard.append(c)
	C.hand.append_array(kept)
	if S.get("tstr", 0):
		add_status(C, C.pl, "strength", -S.tstr)
		S.erase("tstr")
	if living(C).is_empty() and C.over == "":
		C.over = "win"

# Ejecuta toda la fase enemiga de golpe (para pruebas / modo sin animación)
static func enemy_phase_instant(C) -> void:
	for e in C.enemies.duplicate():
		run_enemy_turn(C, e)
	if C.over != "":
		return
	end_round(C)
	start_turn(C)


# ---------- Pociones ----------
static func use_potion(C, slot: int, target = null) -> bool:
	var id = C.G.potions[slot]
	if id == null or C.over != "" or C.phase != "player":
		return false
	var p: Dictionary = DB.potions[id]
	if p.get("target", false) and (target == null or target.hp <= 0):
		var l := living(C)
		if l.size() == 1:
			target = l[0]
		else:
			return false
	C.G.potions[slot] = null
	_mt("potions")
	Relics.use_potion(id, C, target)
	_fx(C, "potion", {"id": id})
	if living(C).is_empty() and C.over == "":
		C.over = "win"
	return true


# ---------- Recompensas ----------
static func reward_cards(G, n: int, bonus_rare: float = 0.0, neutral_chance: float = 0.16) -> Array:
	var out := []
	for i in n:
		var r := rnd(G)
		var rar := "common" if r < 0.6 - bonus_rare else ("uncommon" if r < 0.97 - bonus_rare / 2 else "rare")
		var pl: Array = DB.pool[G.char]
		if DB.extra and neutral_chance > 0.0 and rnd(G) < neutral_chance:
			pl = DB.neutral
		var cands := pl.filter(func(id): return DB.cards[id].rarity == rar and not (id in out))
		if cands.is_empty():
			cands = pl.filter(func(id): return not (id in out))
		out.append(pick(G, cands))
	return out

static func combat_reward(G, tier: String) -> Dictionary:
	var gold: int = rint(G, 90, 110) if tier == "boss" else (rint(G, 30, 45) if tier == "elite" else rint(G, 12, 22))
	var rew := {
		"gold": floori(gold * (1.25 if has_relic(G, "idolo_dorado") else 1.0) * nmods(G).gold + 0.5),
		"cards": reward_cards(G, 3, 0.2 if tier == "elite" else 0.0), "relic": null, "potion": null, "bossRelics": null,
	}
	if tier == "elite":
		rew.relic = random_relic(G)
	if tier == "boss":
		rew.bossRelics = boss_relics(G)
	if Favors.is_active(G, "oro_botin"):
		rew.gold = floori(rew.gold * 1.5 + 0.5)
	var roll := rnd(G) < (0.4 if tier == "normal" else 0.6)
	if roll and G.potions.has(null):
		rew.potion = pick(G, DB.potions.keys())
	return rew

static func _relic_candidates(G, rarity: String) -> Array:
	var c := []
	for id in DB.relics.keys():
		var r: Dictionary = DB.relics[id]
		if r.rarity == rarity and not (id in G.relics) and (not r.has("char") or r.char == G.char):
			c.append(id)
	return c

static func random_relic(G):
	if DB.extra:
		return random_relic_tiered(G)
	var c := _relic_candidates(G, "common")
	return pick(G, c) if not c.is_empty() else null

## Con contenido ampliado: 50% común, 33% poco común, 17% rara (si una rareza se agota, se prueba la siguiente).
static func random_relic_tiered(G, bonus: float = 0.0):
	var r := rnd(G)
	var order := ["common", "uncommon", "rare"]
	if r >= 0.83 - bonus:
		order = ["rare", "uncommon", "common"]
	elif r >= 0.5 - bonus:
		order = ["uncommon", "common", "rare"]
	for rar in order:
		var c := _relic_candidates(G, rar)
		if not c.is_empty():
			return pick(G, c)
	return null

static func boss_relics(G) -> Array:
	var c := _relic_candidates(G, "boss")
	return shuffle(G, c).slice(0, 3)

static func gain_gold(G, n: int) -> void:
	G.gold += n
	if n > 0:
		_mt("gold", n)

static func add_relic(G, id: String) -> void:
	G.relics.append(id)
	if meta_see_relic.is_valid():
		meta_see_relic.call(id)
	Relics.run(id, "onPickup", G, null)


## Añade una carta al mazo desde recompensas, tiendas o eventos (el Huevo de Grifo la mejora).
static func gain_card(G, id: String, up: bool = false) -> Dictionary:
	var c := make_card(G, id, up)
	if not c.up and has_relic(G, "huevo") and can_upgrade(c):
		c.up = true
	G.deck.append(c)
	return c


# ---------- Vista previa del daño entrante ----------
## Daño total que harán los ataques anunciados este turno y cuánto llegaría a tus PV tras Bloqueo y Osty.
static func incoming(C) -> Dictionary:
	var total := 0
	for e in living(C):
		var it = e.intent
		if it == null or not it.get("dmg", 0):
			continue
		total += intent_damage(C, e) * int(it.get("hits", 1))
	var after_block := maxi(0, total - int(C.pl.block))
	var osty_abs := 0
	if C.osty != null and C.osty.hp > 0:
		osty_abs = mini(C.osty.hp, after_block)
	return {"total": total, "hp": after_block - osty_abs, "osty": osty_abs}


# ---------- Deshacer (modo fácil) ----------
## Copia del estado de combate antes de jugar una carta. No incluye el mapa (G.map) ni nada fuera del combate.
static func snapshot(C) -> Dictionary:
	var G = C.G
	var fx = C.fx
	C.G = null
	C.fx = Callable()
	var defs := {}
	for e in C.enemies:
		defs[e.uid] = e.def
		e.def = null
	var c2: Dictionary = C.duplicate(true)
	for e in C.enemies:
		e.def = defs[e.uid]
	C.G = G
	C.fx = fx
	var g2 := {}
	for k in ["hp", "maxHp", "gold", "deck", "potions", "uid", "rs", "stats", "plumaUsed"]:
		if G.has(k):
			var v = G[k]
			g2[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	var alive := 0
	for e in C.enemies:
		if e.hp > 0:
			alive += 1
	return {"C": c2, "G": g2, "alive": alive, "n": C.enemies.size()}

## ¿Se puede deshacer? Solo si no ha muerto ningún enemigo ni ha aparecido ninguno y el combate sigue.
static func can_restore(C, snap: Dictionary) -> bool:
	if snap.is_empty() or C.over != "" or C.prompt != null or C.phase != "player":
		return false
	return living(C).size() == snap.alive and C.enemies.size() == snap.n

## Restaura el combate en el mismo diccionario C (la interfaz conserva sus referencias a C y a cada enemigo).
static func restore(C, snap: Dictionary) -> void:
	var src: Dictionary = snap.C
	var by_uid := {}
	for e in src.enemies:
		by_uid[e.uid] = e
	for e in C.enemies:
		var s0 = by_uid.get(e.uid)
		if s0 == null:
			continue
		var d = e.def
		e.clear()
		e.merge(s0.duplicate(true))
		e.def = d
	for k in src.keys():
		if k in ["G", "fx", "enemies"]:
			continue
		var v = src[k]
		C[k] = v.duplicate(true) if (v is Dictionary or v is Array) else v
	for k in C.keys().duplicate():
		if not src.has(k) and not (k in ["G", "fx", "enemies"]):
			C.erase(k)
	var G = C.G
	for k in snap.G.keys():
		var v2 = snap.G[k]
		G[k] = v2.duplicate(true) if (v2 is Dictionary or v2 is Array) else v2
	if not snap.G.has("plumaUsed"):
		G.erase("plumaUsed")
