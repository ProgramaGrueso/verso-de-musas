extends SceneTree
## Compara el motor de Godot con las trazas de referencia del motor web (tests/traces.json).
## Uso: godot --headless --path . --script tests/run_traces.gd [-- filtro]

var fxl: Array = []


func _j(o: Dictionary) -> String:
	var keys := o.keys()
	keys.sort()
	var parts := []
	for k in keys:
		parts.append('["%s",%s]' % [k, str(o[k])])
	return "[" + ",".join(parts) + "]"


func _fxsig(type: String, d: Dictionary) -> String:
	var s := type
	if d.has("e") and d.e != null:
		s += "#" + str(d.e.uid)
	if d.has("who") and d.who != null:
		s += "@" + (str(d.who.uid) if d.who.has("uid") else "P")
	if d.has("k"):
		s += ":" + str(d.k)
	for k in ["amt", "blocked", "ostyAbs", "n"]:
		if d.has(k):
			s += "," + k + str(d[k])
	if d.has("t"):
		s += ",t" + str(d.t)
	if d.has("id"):
		s += ",id" + str(d.id)
	if d.has("card"):
		s += ",c" + str(d.card.id)
	return s


func _on_fx(type: String, d: Dictionary) -> void:
	fxl.append(_fxsig(type, d))


func _snap(C, G, tag: String) -> String:
	var en := []
	for e in C.enemies:
		en.append("%s:%d:%d:%s:%s" % [e.id, e.hp, e.block, e.moveKey, _j(e.status)])
	var hand := []
	for c in C.hand:
		hand.append(c.id + ("+" if c.up else ""))
	var os := "-"
	if C.osty != null:
		os = "%d/%d/%d" % [C.osty.hp, C.osty.max, C.osty.pow]
	var orbs := []
	for o in C.orbs:
		orbs.append(o.t + str(o.v))
	var s := "%s T%d hp%d/%d b%d e%d/%d H[%s] d%d x%d X%d |%s| P%s O%s R%s g%d rs%d ov%s fx[%s]" % [
		tag, C.turn, G.hp, G.maxHp, C.pl.block, C.energy, C.maxEnergy, ",".join(hand), C.draw.size(), C.discard.size(), C.exhaust.size(),
		";".join(en), _j(C.pl.status), os, ",".join(orbs), G.gold, G.rs, C.over, " ".join(fxl)]
	fxl = []
	return s


func _run_combat(p: Dictionary) -> Array:
	var G := Eng.new_run(p.char, {"seed": p.seed, "nm": p.get("nm", 0)})
	G.act = p.act
	for i in 3:
		for id in Eng.reward_cards(G, 4, 0.1):
			G.deck.append(Eng.make_card(G, id))
	for c in G.deck:
		if Eng.can_upgrade(c) and Eng.rnd(G) < 0.5:
			c.up = true
	if p.has("relic"):
		Eng.add_relic(G, p.relic)
	if p.has("potion"):
		G.potions[0] = p.potion
	var lines := []
	fxl = []
	var C := Eng.start_combat(G, p.ids, {"tier": p.tier, "fx": _on_fx})
	lines.append(_snap(C, G, "start"))
	var turn := 0
	while turn < 30 and C.over == "":
		if turn == 1 and G.potions[0] != null:
			var lv := Eng.living(C)
			if Eng.use_potion(C, 0, lv[0]):
				lines.append(_snap(C, G, "potion"))
		var guard := 0
		while guard < 40 and C.over == "":
			guard += 1
			if C.prompt != null:
				var kind: String = C.prompt.kind
				var uids := []
				for c in C.hand:
					uids.append(c.uid)
				Eng.resolve_prompt(C, uids)
				lines.append(_snap(C, G, "prompt-" + kind))
				continue
			var inst = null
			for c in C.hand:
				if Eng.can_play(C, c).ok:
					inst = c
					break
			if inst == null:
				break
			var d := Eng.card_def(inst)
			var tgt = Eng.living(C)[0] if Eng.needs_target(d) else null
			var ok := Eng.play_card(C, inst.uid, tgt)
			lines.append(_snap(C, G, "play-" + inst.id + ("+" if inst.up else "")))
			if not ok:
				break
		if C.over != "":
			break
		Eng.end_player_turn(C)
		lines.append(_snap(C, G, "end"))
		if C.over != "":
			break
		Eng.enemy_phase_instant(C)
		lines.append(_snap(C, G, "enemy"))
		turn += 1
	lines.append("final %s hp%d rs%d kills%d" % [C.over if C.over != "" else "timeout", G.hp, G.rs, G.stats.kills])
	return lines


func _s(v) -> String:
	return "null" if v == null else str(v)


func _run_structure(p: Dictionary) -> Array:
	var G := Eng.new_run(p.char, {"seed": p.seed})
	var lines := []
	for act in range(1, 4):
		G.act = act
		G.map = RunGen.gen_map(G)
		var rows := []
		for row in G.map.rows:
			var cells := []
			for n in row:
				var nx := ""
				for x in n.next:
					nx += "B" if x.type == "boss" else str(G.map.rows[x.r].find(x))
				cells.append("%d%s>%s" % [n.c, n.type[0], nx])
			rows.append(" ".join(cells))
		lines.append("map%d %s rs%d" % [act, " / ".join(rows), G.rs])
		for tier in ["normal", "elite", "boss"]:
			lines.append("enc%d%s %s rs%d" % [act, tier, "+".join(RunGen.encounter_for(G, tier)), G.rs])
		var sh := RunGen.gen_shop(G)
		var cs := []
		for x in sh.cards: cs.append("%s:%d" % [x.id, x.price])
		var rs := []
		for x in sh.relics: rs.append("%s:%d" % [x.id, x.price])
		var ps := []
		for x in sh.potions: ps.append("%s:%d" % [x.id, x.price])
		lines.append("shop C%s R%s P%s X%d rs%d" % [",".join(cs), ",".join(rs), ",".join(ps), sh.remove.price, G.rs])
		for tier in ["normal", "elite", "boss"]:
			var r := Eng.combat_reward(G, tier)
			lines.append("rew%s g%d c%s r%s p%s b%s rs%d" % [tier, r.gold, ",".join(r.cards), _s(r.relic), _s(r.potion), ",".join(r.bossRelics) if r.bossRelics != null else "", G.rs])
		for i in 3:
			var ev := RunGen.pick_event(G)
			lines.append("event %s rs%d" % [ev.id, G.rs])
		G.nm = 0
	return lines


func _init() -> void:
	DB.load_all()
	var args := OS.get_cmdline_user_args()
	var filt: String = args[0] if args.size() > 0 else ""
	var cases = JSON.parse_string(FileAccess.get_file_as_string("res://tests/traces.json"))
	var ok := 0
	var bad := 0
	var shown := 0
	for cs in cases:
		if filt != "" and not (filt in cs.name):
			continue
		var p = DB._intify(cs.params)
		var got: Array = _run_combat(p) if cs.kind == "combat" else _run_structure(p)
		var want: Array = cs.lines
		var diff := -1
		for i in maxi(got.size(), want.size()):
			if i >= got.size() or i >= want.size() or got[i] != want[i]:
				diff = i
				break
		if diff < 0:
			ok += 1
			if filt != "":
				print(cs.name, " líneas=", got.size(), " última: ", got[got.size() - 1])
		else:
			bad += 1
			if shown < 4:
				shown += 1
				print("✗ ", cs.name, " — línea ", diff)
				print("   esperado: ", want[diff] if diff < want.size() else "(fin)")
				print("   obtenido: ", got[diff] if diff < got.size() else "(fin)")
				if diff > 0:
					print("   previa:   ", want[diff - 1].left(300))
	print("RESULTADO: %d ok, %d fallan de %d" % [ok, bad, ok + bad])
	quit(1 if bad > 0 else 0)
