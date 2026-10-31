class_name RunGen
extends RefCounted
## Generación de la partida: mapa, encuentros, tienda y eventos (port de run/*.js).

const ROWS := 6
const COLS := 4
const PRICE := {"common": 50, "uncommon": 78, "rare": 150}
const RELIC_PRICE := {"common": 140, "uncommon": 190, "rare": 255}


static func _same(a, b) -> bool:
	return is_same(a, b)


static func _has_node(arr: Array, n) -> bool:
	for x in arr:
		if is_same(x, n):
			return true
	return false


static func _closest(arr: Array, c: float):
	var best = arr[0]
	for x in arr:
		if absf(x.c - c) < absf(best.c - c):
			best = x
	return best


static func gen_map(G) -> Dictionary:
	var rows := []
	for r in ROWS:
		var n := Eng.rint(G, 2, 4)
		var cols: Array = Eng.shuffle(G, [0, 1, 2, 3]).slice(0, n)
		cols.sort()
		var row := []
		for c in cols:
			row.append({"r": r, "c": c, "type": "combat", "next": [], "visited": false})
		rows.append(row)
	var boss := {"r": ROWS, "c": 1.5, "type": "boss", "next": [], "visited": false}
	# conexiones
	for r in ROWS - 1:
		var A: Array = rows[r]
		var B: Array = rows[r + 1]
		for a in A:
			var near := B.filter(func(b): return absf(b.c - a.c) <= 1)
			var cand: Array = near if not near.is_empty() else [_closest(B, a.c)]
			var k := mini(cand.size(), 2 if Eng.rnd(G) < 0.4 else 1)
			for b in Eng.shuffle(G, cand.duplicate()).slice(0, k):
				if not _has_node(a.next, b):
					a.next.append(b)
		for b in B:
			var linked := false
			for a in A:
				if _has_node(a.next, b):
					linked = true
					break
			if not linked:
				var a2 = _closest(A, b.c)
				a2.next.append(b)
	for a in rows[ROWS - 1]:
		a.next.append(boss)
	# tipos
	for r in rows.size():
		for nd in rows[r]:
			if r == 0: nd.type = "combat"
			elif r == 1: nd.type = _w(G, [["combat", 6], ["event", 3], ["shop", 1]])
			elif r == 2: nd.type = _w(G, [["combat", 5], ["event", 3], ["shop", 2], ["elite", 2]])
			elif r == 3: nd.type = _w(G, [["combat", 4], ["event", 3], ["elite", 3], ["rest", 2]])
			elif r == 4: nd.type = _w(G, [["combat", 4], ["elite", 3], ["event", 2], ["shop", 2], ["rest", 2]])
			else: nd.type = "rest"
	var flat := []
	for row in rows:
		flat.append_array(row)
	for spec in [["shop", [2, 3]], ["elite", [3, 4]], ["event", [1, 2]]]:
		var has := false
		for n in flat:
			if n.type == spec[0]:
				has = true
				break
		if has:
			continue
		var cand2 := flat.filter(func(n): return n.r in spec[1] and n.type == "combat")
		if not cand2.is_empty():
			Eng.pick(G, cand2).type = spec[0]
	return {"rows": rows, "boss": boss}


# ---------- Mapa de juego (más amplio y ordenado que el del web) ----------
## 8 filas de 2-4 salas + jefe. Las conexiones son monótonas (nunca se cruzan) y se garantiza
## 1-2 tiendas, 1-2 élites, 2-3 eventos, una hoguera intermedia y hogueras antes del jefe.
const GROWS := 8


static func gen_map_game(G) -> Dictionary:
	var rows := []
	for r in GROWS:
		var n: int = 3 if r == 0 else Eng.pick(G, [2, 3, 3, 4])
		var cols: Array = Eng.shuffle(G, [0, 1, 2, 3]).slice(0, n)
		cols.sort()
		var row := []
		for c in cols:
			row.append({"r": r, "c": c, "type": "combat", "next": [], "visited": false})
		rows.append(row)
	var boss := {"r": GROWS, "c": 1.5, "type": "boss", "next": [], "visited": false}
	# conexiones monótonas: recorrido en paralelo por ambas filas, sin cruces
	for r in GROWS - 1:
		var A: Array = rows[r]
		var B: Array = rows[r + 1]
		var i := 0
		var j := 0
		A[0].next.append(B[0])
		while i < A.size() - 1 or j < B.size() - 1:
			var can_i := i < A.size() - 1
			var can_j := j < B.size() - 1
			var mv := 0   # 0 = ambos, 1 = solo i, 2 = solo j
			if can_i and can_j:
				var t := Eng.rnd(G)
				mv = 0 if t < 0.34 else (1 if t < 0.67 else 2)
			elif can_i:
				mv = 1
			else:
				mv = 2
			if mv != 2:
				i += 1
			if mv != 1:
				j += 1
			if not _has_node(A[i].next, B[j]):
				A[i].next.append(B[j])
	for a in rows[GROWS - 1]:
		a.next.append(boss)
	_assign_types(G, rows)
	# jefe del acto (con contenido ampliado hay varios por acto): se decide al crear el mapa y se muestra en él
	if DB.extra:
		G["bossId"] = Eng.pick(G, DB.encounters[G.act].boss)[0]
	G["actFights"] = 0
	G["lastEnc"] = ""
	return {"rows": rows, "boss": boss}


static func _assign_types(G, rows: Array) -> void:
	var last := GROWS - 1
	for nd in rows[last]:
		nd.type = "rest"
	var pick_nodes := func(rr: Array, k: int, t: String, avoid: Array) -> void:
		for _i in k:
			var cand := []
			for r in rr:
				for nd in rows[r]:
					if nd.type == "combat" and _ok_type(rows, nd, t):
						cand.append(nd)
			if not cand.is_empty():
				Eng.pick(G, cand).type = t
	pick_nodes.call([3, 4], 1, "rest", [])
	pick_nodes.call([3, 4, 5, 6], Eng.rint(G, 1, 2), "elite", [])
	_place_shops(G, rows, 2 if Eng.rnd(G) < 0.7 else 1)
	pick_nodes.call([1, 2, 3, 4, 5, 6], Eng.rint(G, 2, 3), "event", [])


## Coloca las tiendas donde más caminos cubren (así casi ningún trayecto se queda sin tienda).
static func _place_shops(G, rows: Array, count: int) -> void:
	for _k in count:
		# caminos que aún NO pasan por ninguna tienda, hasta cada sala y desde cada sala
		var to_boss := {}
		for r in range(GROWS - 1, -1, -1):
			for nd in rows[r]:
				var w := 0
				for m in nd.next:
					w += 1 if m.type == "boss" else to_boss["%d_%d" % [m.r, m.c]]
				to_boss["%d_%d" % [nd.r, nd.c]] = 0 if nd.type == "shop" else w
		var from_start := {}
		for r in GROWS:
			for nd in rows[r]:
				var key := "%d_%d" % [nd.r, nd.c]
				if r == 0:
					from_start[key] = 1
				var f: int = from_start.get(key, 0)
				if nd.type == "shop":
					f = 0
				for m in nd.next:
					if m.type != "boss":
						var mk := "%d_%d" % [m.r, m.c]
						from_start[mk] = from_start.get(mk, 0) + f
		var best := []
		var best_w := -1
		for r in [2, 3, 4, 5]:
			for nd in rows[r]:
				if nd.type != "combat" or not _ok_type(rows, nd, "shop"):
					continue
				var key := "%d_%d" % [nd.r, nd.c]
				var w: int = from_start.get(key, 0) * to_boss[key]
				if w > best_w:
					best_w = w
					best = [nd]
				elif w == best_w:
					best.append(nd)
		if best.is_empty():
			return
		Eng.pick(G, best).type = "shop"


## Un tipo especial no puede repetirse en salas contiguas (ni en la misma fila pegadas).
static func _ok_type(rows: Array, nd: Dictionary, t: String) -> bool:
	if t == "combat":
		return true
	for row in rows:
		for o in row:
			if o.type == t and (_has_node(o.next, nd) or _has_node(nd.next, o)):
				return false
	return true


## Devuelve null si todo camino hasta el jefe pasa por una sala `t`; si no, los nodos de un camino sin ella.
static func _path_without(rows: Array, r: int, t: String):
	var memo := {}
	var walk := func(nd, self_ref) -> Variant:
		if nd.type == "boss":
			return []
		var key := "%d_%d" % [nd.r, nd.c]
		if memo.has(key):
			return memo[key]
		var res = null
		if nd.type != t:
			if nd.next.is_empty():
				res = [nd]
			else:
				for m in nd.next:
					var sub = self_ref.call(m, self_ref)
					if sub != null:
						res = [nd] + sub
						break
		memo[key] = res
		return res
	for nd in rows[r]:
		var p = walk.call(nd, walk)
		if p != null:
			return p
	return null


static func _w(G, table: Array) -> String:
	var tot := 0
	for x in table:
		tot += x[1]
	var t := Eng.rnd(G) * tot
	for x in table:
		t -= x[1]
		if t < 0:
			return x[0]
	return table[0][0]


static func next_nodes(G) -> Array:
	if G.pos == null:
		return G.map.rows[0]
	return G.pos.next


static func encounter_for(G, tier: String) -> Array:
	var t: Array = DB.encounters[G.act][tier]
	return Eng.pick(G, t)


## Jefe de este acto (partidas antiguas sin G.bossId: el jefe original).
static func boss_id(G) -> String:
	var b = G.get("bossId")
	if b != null and b != "" and DB.enemies.has(b) and int(DB.enemies[b].act) == int(G.act):
		return b
	return DB.encounters[G.act].boss[0][0]


## Encuentro para el juego: los 3 primeros combates normales de cada acto salen de la lista "fácil" y el resto de la
## "difícil"; no se repite el encuentro anterior. Sin contenido ampliado equivale a encounter_for.
static func encounter_game(G, tier: String) -> Array:
	var A: Dictionary = DB.encounters[G.act]
	if not DB.extra or not A.has("easy"):
		return encounter_for(G, tier)
	if tier == "boss":
		return [boss_id(G)]
	var key := tier
	if tier == "normal":
		key = "easy" if int(G.get("actFights", 0)) < 3 else "hard"
		G["actFights"] = int(G.get("actFights", 0)) + 1
	var pool: Array = A[key]
	var last: String = str(G.get("lastEnc", ""))
	var cands := pool.filter(func(x): return "+".join(x) != last)
	if cands.is_empty():
		cands = pool
	var enc: Array = Eng.pick(G, cands)
	G["lastEnc"] = "+".join(enc)
	return enc.duplicate()


static func gen_shop(G) -> Dictionary:
	var disc := 0.5 if Eng.has_relic(G, "tarjeta") else 1.0
	var price := func(n: float) -> int: return maxi(5, floori(n * disc + 0.5))
	var cards := []
	for id in Eng.reward_cards(G, 5, 0.1, 0.0):
		var base: float = PRICE[DB.cards[id].rarity] * (0.9 + Eng.rnd(G) * 0.2)
		cards.append({"id": id, "price": price.call(base), "sold": false})
	# estante fijo de cartas neutrales: 3 sin oro extra, algo más baratas que las de clase
	var neutral := []
	if DB.extra:
		var seen := []
		for rar in ["common", "uncommon", "common"]:
			var cands := DB.neutral.filter(func(id): return DB.cards[id].rarity == rar and not (id in seen))
			if cands.is_empty():
				continue
			var nid: String = Eng.pick(G, cands)
			seen.append(nid)
			neutral.append({"id": nid, "price": price.call(PRICE[rar] * 0.85 * (0.9 + Eng.rnd(G) * 0.2)), "sold": false})
	var relics := []
	if DB.extra:
		# una reliquia común, una poco común y una tercera poco común o rara
		var taken := []
		for spec in [["common", "common"], ["uncommon", "common"], ["rare" if Eng.rnd(G) < 0.45 else "uncommon", "uncommon"]]:
			var rar: String = spec[0]
			var cands: Array = Eng._relic_candidates(G, rar).filter(func(x): return not (x in taken))
			if cands.is_empty():
				rar = spec[1]
				cands = Eng._relic_candidates(G, rar).filter(func(x): return not (x in taken))
			if cands.is_empty():
				continue
			var rid: String = Eng.pick(G, cands)
			taken.append(rid)
			var base: int = RELIC_PRICE[rar]
			relics.append({"id": rid, "price": price.call(base + Eng.rint(G, 0, 40)), "sold": false})
	else:
		var pool := []
		for id in DB.relics.keys():
			var r: Dictionary = DB.relics[id]
			if r.rarity == "common" and not (id in G.relics) and (not r.has("char") or r.char == G.char):
				pool.append(id)
		for id in Eng.shuffle(G, pool).slice(0, 2):
			relics.append({"id": id, "price": price.call(140 + Eng.rint(G, 0, 40)), "sold": false})
	var potions := []
	for id in Eng.shuffle(G, DB.potions.keys()).slice(0, 2):
		potions.append({"id": id, "price": price.call(45), "sold": false})
	return {"cards": cards, "neutral": neutral, "relics": relics, "potions": potions, "remove": {"price": price.call(75 + 25 * G.get("removed", 0)), "used": false}}


## ¿Puede salir este evento ahora? (los eventos ampliados pueden ser de un acto o de una musa concretos)
static func event_ok(G, e: Dictionary) -> bool:
	if e.has("act") and int(e.act) != int(G.act):
		return false
	if e.has("char") and e.char != G.char:
		return false
	return true


static func pick_event(G) -> Dictionary:
	if DB.extra:
		return _pick_event_extra(G)
	var pool := DB.events.filter(func(e): return not (e.id in G.seenEvents))
	var ev: Dictionary = Eng.pick(G, pool if not pool.is_empty() else DB.events)
	G.seenEvents.append(ev.id)
	if G.seenEvents.size() >= DB.events.size():
		G.seenEvents = []
	return ev


## Sorteo con eventos de acto y de musa: los exclusivos de la musa pesan el doble para que se vean a menudo.
static func _pick_event_extra(G) -> Dictionary:
	var elig := DB.events.filter(func(e): return event_ok(G, e))
	var pool := elig.filter(func(e): return not (e.id in G.seenEvents))
	if pool.is_empty():
		for e in elig:
			G.seenEvents.erase(e.id)
		pool = elig
	var weighted := []
	for e in pool:
		weighted.append(e)
		if e.has("char"):
			weighted.append(e)
	var ev: Dictionary = Eng.pick(G, weighted)
	G.seenEvents.append(ev.id)
	return ev
