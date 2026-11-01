extends SceneTree
## Simulador de equilibrio: juega partidas completas solo con el motor (sin interfaz) con un bot sencillo
## y resume el porcentaje de victorias por musa y nivel de Pesadilla, la dureza de cada jefe/élite y qué
## encuentros acaban con más partidas. Sirve para comparar antes/después de tocar números, no como IA buena.
##
## Uso: godot --headless --path . --script tests/balance.gd -- [partidas_por_musa=40] [pesadilla=0] [musa=todas] [semilla=1]
## Ejemplo: godot --headless --path . --script tests/balance.gd -- 100 0
##          godot --headless --path . --script tests/balance.gd -- 50 5 selene
## Escribe además el resumen en JSON en user://balance.json.

var rng := RandomNumberGenerator.new()
var out := {}          # char -> {runs, wins, floors, acts}
var fights := {}       # "tier:ids" -> {n, lost, hpLost}
var killers := {}      # encuentro -> derrotas
var run_log: Array = []   # {ch, won, relics}
var relic_runs := {}   # reliquia -> {n, wins}
var turn_cap_hits := 0


func _init() -> void:
	Eng.meta_add = Callable()
	Eng.meta_max = Callable()
	Eng.meta_see_relic = Callable()
	var args := OS.get_cmdline_user_args()
	DB.extra = not (args.size() > 4 and args[4] == "base")   # «base»: sin el contenido de la oleada 2
	DB.load_all()
	var n_runs: int = int(args[0]) if args.size() > 0 else 40
	var nm: int = int(args[1]) if args.size() > 1 else 0
	var only: String = args[2] if args.size() > 2 and args[2] != "all" else ""
	rng.seed = int(args[3]) if args.size() > 3 else 1
	var chars: Array = DB.playable() if only == "" else [only]
	var t0 := Time.get_ticks_msec()
	for ch in chars:
		out[ch] = {"runs": 0, "wins": 0, "floors": 0, "acts": [0, 0, 0, 0]}
		for i in n_runs:
			_play_run(ch, nm, rng.randi() % 1000000 + 1)
	_report(nm, Time.get_ticks_msec() - t0)
	quit(0)


# ============================== partida ==============================
func _play_run(ch: String, nm: int, seed_v: int) -> void:
	var G := Eng.new_run(ch, {"seed": seed_v, "nm": nm})
	G["seeded"] = true
	G.map = RunGen.gen_map_game(G)
	_favor(G)
	var won := false
	var guard := 0
	while guard < 200:
		guard += 1
		var opts: Array = RunGen.next_nodes(G)
		var n: Dictionary = _choose_node(G, opts)
		G.pos = n
		n.visited = true
		G.floor += 1
		var alive := true
		match n.type:
			"combat": alive = _fight(G, RunGen.encounter_game(G, "normal"), "normal")
			"elite": alive = _fight(G, RunGen.encounter_game(G, "elite"), "elite")
			"boss": alive = _fight(G, RunGen.encounter_game(G, "boss"), "boss")
			"event": alive = _event(G)
			"shop": _shop(G)
			"rest": _rest(G)
		if not alive:
			break
		if n.type == "boss":
			if G.act >= 3:
				won = true
				break
			G.act += 1
			G.pos = null
			G.rs = Eng.act_seed(G.seed, G.act)
			G.map = RunGen.gen_map_game(G)
			Favors.expire(G)
			G.hp = G.maxHp
			_favor(G)
	var o: Dictionary = out[ch]
	o.runs += 1
	o.floors += G.floor
	o.acts[G.act] += 1
	if won:
		o.wins += 1
	run_log.append({"ch": ch, "won": won, "relics": G.relics.duplicate()})
	for r in G.relics:
		if not relic_runs.has(r):
			relic_runs[r] = {"n": 0, "wins": 0}
		relic_runs[r].n += 1
		if won:
			relic_runs[r].wins += 1


func _favor(G) -> void:
	var offer := Favors.offer(G, rng.randi() % Favors.POOLS.size())
	if not offer.is_empty():
		Favors.choose(G, offer[0])


func _choose_node(G, opts: Array) -> Dictionary:
	var hp_ratio: float = float(G.hp) / G.maxHp
	var best = opts[0]
	var best_s := -1e9
	for n in opts:
		var s := rng.randf()
		match n.type:
			"elite": s += 3.0 if hp_ratio > 0.7 else -3.0
			"rest": s += 3.0 if hp_ratio < 0.5 else 0.5
			"shop": s += 2.0 if G.gold >= 150 else 0.0
			"event": s += 1.0
			"combat": s += 1.5
			"boss": s += 10.0
		if s > best_s:
			best_s = s
			best = n
	return best


# ============================== combate ==============================
func _fight(G, ids: Array, tier: String) -> bool:
	var key: String = "%s:%s" % [tier, "+".join(ids)]
	if not fights.has(key):
		fights[key] = {"n": 0, "lost": 0, "hpLost": 0}
	var hp0: int = G.hp
	var C := Eng.start_combat(G, ids, {"tier": tier})
	var turn := 0
	while turn < 60 and C.over == "":
		if turn == 0 and tier != "normal":
			for i in G.potions.size():
				if G.potions[i] != null and C.over == "":
					var lv := Eng.living(C)
					if not lv.is_empty():
						Eng.use_potion(C, i, lv[0])
		var guard := 0
		while guard < 50 and C.over == "":
			guard += 1
			if C.prompt != null:
				_resolve_prompt(C)
				continue
			var inst = _pick_card(C)
			if inst == null:
				break
			var d := Eng.card_def(inst)
			var tgt = _target(C) if Eng.needs_target(d) else null
			if not Eng.play_card(C, inst.uid, tgt):
				break
		if C.over != "":
			break
		Eng.end_player_turn(C)
		if C.over != "":
			break
		Eng.enemy_phase_instant(C)
		turn += 1
	if C.over == "" :
		turn_cap_hits += 1
		C.over = "lose"
	var f: Dictionary = fights[key]
	f.n += 1
	f.hpLost += maxi(0, hp0 - G.hp)
	if C.over == "lose":
		f.lost += 1
		killers[key] = killers.get(key, 0) + 1
		return false
	for id in G.relics:
		Relics.run(id, "onCombatEnd", G)
	Favors.on_combat_end(G)
	G.stats.fights += 1
	if tier == "boss" and G.act >= 3:
		return true
	_take_reward(G, Eng.combat_reward(G, tier))
	return true


func _target(C):
	var lv := Eng.living(C)
	var t = lv[0]
	for e in lv:
		if e.hp < t.hp:
			t = e
	return t


func _pick_card(C):
	var inc := Eng.incoming(C)
	var best = null
	var best_s := -1e9
	for c in C.hand:
		if not Eng.can_play(C, c).ok:
			continue
		var d := Eng.card_def(c)
		var s := 0.0
		if d.type == "power":
			s = 5.0
		elif d.type == "attack":
			s = 2.0 + d.fx.get("dmg", 0) * d.fx.get("hits", 1) * 0.05
		elif d.fx.get("block", 0):
			s = 3.5 if inc.hp > 0 else 0.5
		elif d.type in ["status", "curse"]:
			s = -1.0
		else:
			s = 1.5
		if not Eng.is_x(d.cost):
			s -= Eng.eff_cost(C, d) * 0.1
		if s > best_s:
			best_s = s
			best = c
	return best


func _resolve_prompt(C) -> void:
	var hand: Array = C.hand.duplicate()
	hand.sort_custom(func(a, b): return _junk(a) > _junk(b))
	var uids := []
	for c in hand:
		uids.append(c.uid)
	Eng.resolve_prompt(C, uids)


func _junk(c) -> int:
	var d := Eng.card_def(c)
	if d.type in ["status", "curse"]:
		return 3
	if d.rarity == "starter":
		return 2
	return 0


# ============================== entre combates ==============================
func _take_reward(G, rew: Dictionary) -> void:
	Eng.gain_gold(G, rew.gold)
	if rew.potion != null and G.potions.has(null):
		G.potions[G.potions.find(null)] = rew.potion
	if rew.relic != null:
		Eng.add_relic(G, rew.relic)
	if rew.bossRelics != null and not rew.bossRelics.is_empty():
		Eng.add_relic(G, rew.bossRelics[rng.randi() % rew.bossRelics.size()])
	if G.deck.size() < 28 and not rew.cards.is_empty():
		var order := {"rare": 3, "uncommon": 2, "common": 1}
		var pick: String = rew.cards[0]
		for id in rew.cards:
			if order.get(DB.cards[id].rarity, 0) > order.get(DB.cards[pick].rarity, 0):
				pick = id
		if rng.randf() < 0.85:
			Eng.gain_card(G, pick)


func _rest(G) -> void:
	if G.hp < G.maxHp * 0.55 and not Eng.has_relic(G, "reloj_roto"):
		G.hp = mini(G.maxHp, G.hp + ceili(G.maxHp * Eng.nmods(G).rest))
		return
	var ups: Array = G.deck.filter(func(c): return Eng.can_upgrade(c))
	if not ups.is_empty():
		ups.sort_custom(func(a, b): return _junk(a) < _junk(b))
		ups[0].up = true


func _shop(G) -> void:
	var sh := RunGen.gen_shop(G)
	var starters: Array = G.deck.filter(func(c): return DB.cards[c.id].rarity == "starter" or DB.cards[c.id].type == "curse")
	if G.gold >= sh.remove.price and not starters.is_empty():
		starters.sort_custom(func(a, b): return _junk(a) > _junk(b))
		var rm = starters[0]
		G.deck = G.deck.filter(func(x): return x.uid != rm.uid)
		G.gold -= sh.remove.price
		G.removed = G.get("removed", 0) + 1
	for it in sh.relics:
		if G.gold >= it.price:
			G.gold -= it.price
			Eng.add_relic(G, it.id)
	for it in sh.cards:
		if G.gold >= it.price and DB.cards[it.id].rarity == "rare" and G.deck.size() < 28:
			G.gold -= it.price
			Eng.gain_card(G, it.id)


class BotCtx extends RefCounted:
	var G
	var rng: RandomNumberGenerator

	func pick_card(_title: String, filter: Callable, n: int, _up: bool = false) -> Array:
		var cands: Array = G.deck.filter(filter)
		cands.sort_custom(func(a, b): return _junk_of(a) > _junk_of(b))
		return cands.slice(0, n)

	func choose_new(_title: String, ids: Array) -> Array:
		if ids.is_empty():
			return []
		return [Eng.make_card(G, ids[0])]

	func _junk_of(c) -> int:
		var d := Eng.card_def(c)
		if d.type in ["status", "curse"]:
			return 3
		if d.rarity == "starter":
			return 2
		return 0


func _event(G) -> bool:
	var ev := RunGen.pick_event(G)
	var opts: Array = EventsLogic.options(G, ev.id).filter(func(o): return o.ok)
	if opts.is_empty():
		return true
	var o: Dictionary = opts[rng.randi() % opts.size()]
	if o.has("fight"):
		var ids: Array = o.fight_ids if o.has("fight_ids") else RunGen.encounter_game(G, o.fight)
		return _fight(G, ids, o.fight)
	var ctx := BotCtx.new()
	ctx.G = G
	ctx.rng = rng
	o.run.call(ctx)   # las opciones con "await ctx.pick_card" no se suspenden con BotCtx
	if G.hp <= 0:
		G.hp = 1
	return true


# ============================== informe ==============================
func _report(nm: int, ms: int) -> void:
	print("\n=== Verso de Musas · equilibrio (Pesadilla %d) · %.1f s ===" % [nm, ms / 1000.0])
	print("%-9s %6s %6s %7s %8s   muertes por acto (I/II/III)" % ["musa", "runs", "wins", "win%", "piso"])
	for ch in out.keys():
		var o: Dictionary = out[ch]
		var wr: float = 100.0 * o.wins / maxi(1, o.runs)
		print("%-9s %6d %6d %6.1f%% %8.1f   %d / %d / %d" % [ch, o.runs, o.wins, wr, float(o.floors) / maxi(1, o.runs), o.acts[1], o.acts[2], o.acts[3] - o.wins])
	print("\n-- Jefes y élites (combates · % derrotas · PV perdidos de media) --")
	var keys: Array = fights.keys().filter(func(k): return not k.begins_with("normal:"))
	keys.sort()
	for k in keys:
		var f: Dictionary = fights[k]
		print("  %-34s %5d  %5.1f%%  %5.1f" % [k, f.n, 100.0 * f.lost / maxi(1, f.n), float(f.hpLost) / maxi(1, f.n)])
	print("\n-- Encuentros que más partidas terminan --")
	var kk: Array = killers.keys()
	kk.sort_custom(func(a, b): return killers[a] > killers[b])
	for k in kk.slice(0, 12):
		print("  %-40s %d" % [k, killers[k]])
	print("\n-- Normales más duros (PV perdidos de media, mín. 10 combates) --")
	var nk: Array = fights.keys().filter(func(k): return k.begins_with("normal:") and fights[k].n >= 10)
	nk.sort_custom(func(a, b): return float(fights[a].hpLost) / fights[a].n > float(fights[b].hpLost) / fights[b].n)
	for k in nk.slice(0, 10):
		print("  %-40s %5.1f PV  (%d)" % [k, float(fights[k].hpLost) / fights[k].n, fights[k].n])
	_easy_vs_hard()
	print("\n-- Reliquias (partidas que la tenían · % victorias), mín. 5 partidas --")
	var rk: Array = relic_runs.keys().filter(func(k): return relic_runs[k].n >= 5)
	rk.sort_custom(func(a, b): return float(relic_runs[a].wins) / relic_runs[a].n > float(relic_runs[b].wins) / relic_runs[b].n)
	for k in rk:
		print("  %-20s %4d  %5.1f%%" % [k, relic_runs[k].n, 100.0 * relic_runs[k].wins / relic_runs[k].n])
	_relic_uplift()
	if turn_cap_hits:
		print("\n(aviso: %d combates llegaron al tope de 60 turnos y se contaron como derrota)" % turn_cap_hits)
	var f2 := FileAccess.open("user://balance.json", FileAccess.WRITE)
	if f2:
		f2.store_string(JSON.stringify({"nm": nm, "chars": out, "fights": fights, "killers": killers, "relics": relic_runs}, " "))
		print("\nResumen JSON: ", ProjectSettings.globalize_path("user://balance.json"))


func _rarity(r: String) -> String:
	return str(DB.relics[r].get("rarity", "starter")) if DB.relics.has(r) else "?"


## Compara cada reliquia con las partidas de la misma musa que tenían otra de su misma rareza
## (así no pesa que las de jefe solo las tengan quienes ya vencieron a un jefe).
func _relic_uplift() -> void:
	var base := {}   # "musa|rareza" -> [n, wins]
	for rl in run_log:
		var seen := {}
		for r in rl.relics:
			var k: String = "%s|%s" % [rl.ch, _rarity(r)]
			if seen.has(k):
				continue
			seen[k] = true
			if not base.has(k):
				base[k] = [0, 0]
			base[k][0] += 1
			if rl.won:
				base[k][1] += 1
	var rows := []
	for r in relic_runs.keys():
		var n: int = relic_runs[r].n
		if n < 15 or _rarity(r) == "starter":
			continue
		var exp: float = 0.0
		for rl in run_log:
			if rl.relics.has(r):
				var b: Array = base["%s|%s" % [rl.ch, _rarity(r)]]
				exp += float(b[1]) / b[0]
		var real: float = 100.0 * relic_runs[r].wins / n
		rows.append([r, n, real, 100.0 * exp / n])
	rows.sort_custom(func(a, b): return a[2] - a[3] > b[2] - b[3])
	print("\n-- Reliquias frente a su grupo (misma musa y rareza), mín. 15 partidas --")
	print("  %-20s %-9s %5s %7s %7s %7s" % ["reliquia", "rareza", "n", "gana%", "grupo%", "delta"])
	for x in rows:
		print("  %-20s %-9s %5d %6.1f%% %6.1f%% %+6.1f" % [x[0], _rarity(x[0]), x[1], x[2], x[3], x[2] - x[3]])


## PV perdidos de media en los encuentros de la lista «fácil» frente a los de la «difícil» (solo con contenido ampliado).
func _easy_vs_hard() -> void:
	if not DB.extra:
		return
	for act in [1, 2, 3]:
		var A: Dictionary = DB.encounters[act]
		if not A.has("easy"):
			continue
		var easy_keys := {}
		var hard_keys := {}
		for e in A.easy:
			easy_keys["normal:" + "+".join(e)] = true
		for e in A.hard:
			hard_keys["normal:" + "+".join(e)] = true
		var res := {}
		for name in ["easy", "hard"]:
			var ks: Dictionary = easy_keys if name == "easy" else hard_keys
			var n := 0
			var lost := 0
			for k in ks.keys():
				if name == "easy" and hard_keys.has(k) or name == "hard" and easy_keys.has(k):
					continue
				if fights.has(k):
					n += fights[k].n
					lost += fights[k].hpLost
			res[name] = [n, float(lost) / maxi(1, n)]
		print("Acto %d: fáciles %.1f PV (%d combates) · difíciles %.1f PV (%d combates)" % [act, res.easy[1], res.easy[0], res.hard[1], res.hard[0]])
