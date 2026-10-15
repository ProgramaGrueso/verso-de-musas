class_name RunGen
extends RefCounted
## Generación de la partida: mapa, encuentros, tienda y eventos (port de run/*.js).

const ROWS := 6
const COLS := 4
const PRICE := {"common": 50, "uncommon": 78, "rare": 150}


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


static func gen_shop(G) -> Dictionary:
	var disc := 0.5 if Eng.has_relic(G, "tarjeta") else 1.0
	var price := func(n: float) -> int: return maxi(5, floori(n * disc + 0.5))
	var cards := []
	for id in Eng.reward_cards(G, 5, 0.1):
		var base: float = PRICE[DB.cards[id].rarity] * (0.9 + Eng.rnd(G) * 0.2)
		cards.append({"id": id, "price": price.call(base), "sold": false})
	var relics := []
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
	return {"cards": cards, "relics": relics, "potions": potions, "remove": {"price": price.call(75 + 25 * G.get("removed", 0)), "used": false}}


static func pick_event(G) -> Dictionary:
	var pool := DB.events.filter(func(e): return not (e.id in G.seenEvents))
	var ev: Dictionary = Eng.pick(G, pool if not pool.is_empty() else DB.events)
	G.seenEvents.append(ev.id)
	if G.seenEvents.size() >= DB.events.size():
		G.seenEvents = []
	return ev
