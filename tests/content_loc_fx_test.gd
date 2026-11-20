extends SceneTree
## Texto vs motor (Fase 5): muestrea que los números que dicen las cartas, reliquias y pociones coinciden con lo
## que hace el motor de verdad. Para cada carta (base y mejorada) la juega en un combate controlado (enemigo con
## 5000 PV, sin reliquias ni estados) y mide daño, Bloqueo, energía, robo, estados y PV; compara con los datos y
## comprueba que el número aparece en el texto. Para reliquias y pociones ejecuta su gancho y exige que cada
## cambio medido (Bloqueo, estados, PV, energía, daño…) aparezca como número en su descripción.
## Uso: godot --headless --path . --script tests/content_loc_fx_test.gd

var fails := 0
var checks := 0
var warns: Array = []
var _rx_bb := RegEx.create_from_string("\\[[^\\]]*\\]")
var _rx_num := RegEx.create_from_string("\\d+")

## Reliquias cuyo cambio medido no es un número del texto (explicado).
const RELIC_OK := {
	"cetro_maremoto": "canaliza 3 orbes nombrados (Ola, Bruma y Perla), no «3»",
}


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		if fails <= 80:
			print("FALLA: ", msg)


func warn(msg: String) -> void:
	warns.append(msg)


func _init() -> void:
	TranslationServer.set_locale("es")
	DB.load_all()
	_cards()
	_supernova()
	_relics()
	_potions()
	_powers()
	if not warns.is_empty():
		print("\nAVISOS (no comprobables automáticamente, %d):" % warns.size())
		for w in warns.slice(0, 60):
			print("  ", w)
	print("RESULTADO: %d comprobaciones, %d fallan" % [checks, fails])
	quit(1 if fails else 0)


# ---------- utilidades ----------
func _plain(s: String) -> String:
	return _rx_bb.sub(s, "", true)


func _nums(s: String) -> Array:
	var out := []
	for m in _rx_num.search_all(_plain(s)):
		out.append(int(m.get_string()))
	return out


func _card_text(d: Dictionary) -> String:
	return _plain(" | ".join(CardText.lines(d).lines))


## Combate controlado: un enemigo con 5000 PV, sin reliquias, mazo de relleno, 10 de energía, sin estados.
func _combat(char: String, relics: Array = []) -> Dictionary:
	var G := Eng.new_run(char, {"seed": 7})
	G.relics = relics.duplicate()
	G.deck = []
	for i in 12:
		G.deck.append(Eng.make_card(G, "wound"))
	var C := Eng.start_combat(G, ["dockrat"])
	_reset(C)
	return C


func _reset(C) -> void:
	C.energy = 10
	C.pl.block = 0
	C.pl.status = {}
	C.attacksThisTurn = 0
	C.playedThisTurn = 0
	C.prompt = null
	C.orbs = []
	C.G.hp = C.G.maxHp - 30
	var e: Dictionary = C.enemies[0]
	e.hp = 5000
	e.maxHp = 5000
	e.block = 0
	e.status = {}


func _m(C) -> Dictionary:
	var m := {"block": C.pl.block, "energy": C.energy, "maxEnergy": C.maxEnergy, "orbMax": C.orbMax, "orbs": C.orbs.size(),
		"hand": C.hand.size(), "hp": C.G.hp, "maxHp": C.G.maxHp, "potSlots": C.G.potions.size(),
		"firstTurnDraw": C.firstTurnDraw, "extraDraw": C.extraDraw, "drawPile": C.draw.size(), "ehp": 0, "eblock": 0}
	for k in C.pl.status.keys():
		m["pl." + k] = int(C.pl.status[k])
	for e in C.enemies:
		m.ehp += e.hp
		m.eblock += e.block
		for k in e.status.keys():
			m["en." + k] = m.get("en." + k, 0) + int(e.status[k])
	if C.osty != null:
		m["osty.max"] = C.osty.max
		m["osty.pow"] = C.osty.pow
	return m


func _delta(a: Dictionary, b: Dictionary) -> Dictionary:
	var d := {}
	for k in a.keys() + b.keys():
		var v: int = int(b.get(k, 0)) - int(a.get(k, 0))
		if v != 0:
			d[k] = v
	return d


# ---------- cartas ----------
func _cards() -> void:
	for id in DB.cards.keys():
		for up in [false, true]:
			var d0 := Eng.card_def({"id": id, "up": up})
			if d0.type in ["status", "curse"] or d0.flags.get("unplayable", false) or (not Eng.is_x(d0.cost) and d0.cost == -1):
				continue
			if up and not Eng.can_upgrade({"id": id, "up": false}):
				continue
			_card(id, up)


func _card(id: String, up: bool) -> void:
	var cd: Dictionary = DB.cards[id]
	var char: String = cd.get("cls", "zafiro")
	if not DB.characters.has(char):
		char = "zafiro"
	var C := _combat(char)
	var inst := Eng.make_card(C.G, id, up)
	var d := Eng.card_def(inst)
	var f: Dictionary = d.fx
	var e: Dictionary = C.enemies[0]
	C.hand.append(inst)
	var tag: String = d.name
	# Engranaje: la carta se repite si queda Cuerda; aquí solo se comprueba su texto
	var eng: bool = not d.get("gear", false)
	if not Eng.can_play(C, inst).ok:
		warn("%s: no se puede jugar en el combate de prueba (%s)" % [tag, Eng.can_play(C, inst).get("why", "")])
		return
	var cost: int = 0 if Eng.is_x(d.cost) else int(Eng.eff_cost(C, d))
	var a := _m(C)
	Eng.play_card(C, inst.uid, e)
	var b := _m(C)
	var dl := _delta(a, b)
	var text := _card_text(d)
	var nums := _nums(text)
	var conf := func(keys: Array) -> bool:
		for k in keys:
			if f.get(k, false):
				return true
		return false
	var X := Eng.is_x(d.cost)
	# daño (datos → motor): (dmg + Fuerza ganada antes) × golpes
	if f.get("dmg", 0) and not X and not d.get("gear", false) and not d.get("dance", false) \
			and not conf.call(["dmgBlock", "dmgPerOrb", "windDmg", "windSpend", "heatDmg", "heatMul", "poisonDbl", "strMul", "x", "ostyHit", "doubleStr", "evoke", "evokeX", "evokeAll", "ch"]):
		var hits: int = f.get("hits", 1)
		var want: int = (int(f.dmg) + int(f.get("str", 0)) + int(f.get("tstr", 0))) * hits
		ok(not eng or -dl.get("ehp", 0) == want, "%s: el texto dice %d de daño%s y el motor hace %d" % [tag, f.dmg, (" ×%d" % hits) if hits > 1 else "", -dl.get("ehp", 0)])
		ok(int(f.dmg) in nums, "%s: el texto no muestra el daño %d: %s" % [tag, f.dmg, text])
		if hits > 1:
			ok(hits in nums, "%s: el texto no muestra los %d golpes: %s" % [tag, hits, text])
	# Bloqueo (la Destreza de la propia carta se aplica antes)
	if f.get("block", 0) and not conf.call(["blockPerOrb", "doubleBlock", "dmgBlock", "evoke", "evokeX", "evokeAll", "ch"]):
		var want_b: int = int(f.block) + int(f.get("dex", 0))
		ok(not eng or dl.get("block", 0) == want_b, "%s: el texto dice %d de Bloqueo y el motor da %d" % [tag, f.block, dl.get("block", 0)])
		ok(int(f.block) in nums, "%s: el texto no muestra el Bloqueo %d: %s" % [tag, f.block, text])
	# energía
	if not X and not conf.call(["energyIfAttack", "energyIfGlow"]):
		ok(not eng or dl.get("energy", 0) == int(f.get("energy", 0)) - cost, "%s: energía %+d, se esperaba %+d (coste %d, +%d)" % [tag, dl.get("energy", 0), int(f.get("energy", 0)) - cost, cost, f.get("energy", 0)])
	# robo
	if f.get("draw", 0) and not conf.call(["add", "discard", "exhaustPick", "stormOfSteel", "drawIfHeat"]):
		ok(not eng or dl.get("hand", 0) == int(f.draw) - 1, "%s: el texto dice robar %d y la mano cambia %+d" % [tag, f.draw, dl.get("hand", 0) + 1])
		ok(int(f.draw) in nums, "%s: el texto no muestra el robo %d: %s" % [tag, f.draw, text])
	# estados al objetivo
	for pair in [["vuln", "vulnerable"], ["weak", "weak"], ["poison", "poison"], ["glow", "glow"]]:
		if f.get(pair[0], 0) and not conf.call(["poisonMul"]):
			ok(not eng or dl.get("en." + pair[1], 0) == int(f[pair[0]]), "%s: el texto dice %d de %s y el motor aplica %d" % [tag, f[pair[0]], pair[1], dl.get("en." + pair[1], 0)])
			ok(int(f[pair[0]]) in nums, "%s: el texto no muestra %d de %s: %s" % [tag, f[pair[0]], pair[1], text])
	# estados propios
	for pair in [["dex", "dexterity"], ["focus", "resonancia"]]:
		if f.get(pair[0], 0):
			ok(not eng or dl.get("pl." + pair[1], 0) == int(f[pair[0]]), "%s: el texto dice %d de %s y el motor da %d" % [tag, f[pair[0]], pair[1], dl.get("pl." + pair[1], 0)])
			ok(int(f[pair[0]]) in nums, "%s: el texto no muestra %d de %s: %s" % [tag, f[pair[0]], pair[1], text])
	if (f.get("str", 0) or f.get("tstr", 0)) and not f.has("pw") and not f.get("doubleStr", false):
		var want_s: int = int(f.get("str", 0)) + int(f.get("tstr", 0))
		ok(not eng or dl.get("pl.strength", 0) == want_s, "%s: Fuerza %+d, se esperaba %+d" % [tag, dl.get("pl.strength", 0), want_s])
	if f.get("heat", 0) and not conf.call(["heatMul", "heatDmg", "heatDouble"]) and not (f.has("pw") and f.pw.has("heat")):
		ok(not eng or dl.get("pl.heat", 0) == int(f.heat), "%s: el texto dice %d de Calor y el motor da %d" % [tag, f.heat, dl.get("pl.heat", 0)])
		ok(int(f.heat) in nums, "%s: el texto no muestra %d de Calor: %s" % [tag, f.heat, text])
	if f.get("wind", 0) and not conf.call(["windSpend", "windDouble"]) and not d.get("gear", false):
		ok(not eng or dl.get("pl.cuerda", 0) == int(f.wind), "%s: el texto dice %d de Cuerda y el motor da %d" % [tag, f.wind, dl.get("pl.cuerda", 0)])
		ok(int(f.wind) in nums, "%s: el texto no muestra %d de Cuerda: %s" % [tag, f.wind, text])
	if f.get("slots", 0):
		ok(not eng or dl.get("orbMax", 0) == int(f.slots), "%s: +%d huecos en el texto y el motor da %d" % [tag, f.slots, dl.get("orbMax", 0)])
	# PV propios
	if (f.get("heal", 0) or f.get("selfdmg", 0)) and not conf.call(["lifesteal", "fatalMax"]):
		var want_h: int = int(f.get("heal", 0)) - int(f.get("selfdmg", 0))
		ok(not eng or dl.get("hp", 0) == want_h, "%s: PV %+d, se esperaba %+d" % [tag, dl.get("hp", 0), want_h])
		for k in ["heal", "selfdmg"]:
			if f.get(k, 0):
				ok(int(f[k]) in nums, "%s: el texto no muestra %d (%s): %s" % [tag, f[k], k, text])
	# poderes: el estado sube lo que dice y el texto (descripción del estado) lleva el número
	if f.has("pw"):
		for k in f.pw.keys():
			var got: int = dl.get("pl." + k, 0)
			if got != int(f.pw[k]):
				warn("%s: el poder %s sube %d (dato %d)" % [tag, k, got, f.pw[k]])
	# daño previsto (lo que muestra la carta en combate) = daño real, con Calor/Cuerda cargados
	if f.get("dmg", 0) or f.get("dmgPerOrb", 0) or f.get("windSpend", 0) or f.get("heatDmg", 0):
		_preview(id, up, char)


## En combate la carta muestra Eng.preview_dmg: debe coincidir con el daño de cada golpe.
func _preview(id: String, up: bool, char: String) -> void:
	var C := _combat(char)
	var inst := Eng.make_card(C.G, id, up)
	var d := Eng.card_def(inst)
	var f: Dictionary = d.fx
	if Eng.is_x(d.cost) or f.get("ostyHit", 0) or f.get("str", 0) or f.get("tstr", 0) or f.get("doubleStr", false) \
			or f.get("evoke", 0) or f.get("evokeAll", false) or f.get("ch", []).size() or d.get("gear", false) or d.get("dance", false) \
			or f.get("vuln", 0) and not f.get("all", false) and f.get("hits", 1) > 1:
		return
	var e: Dictionary = C.enemies[0]
	C.pl.status = {"heat": 3, "cuerda": 3}
	C.hand.append(inst)
	if not Eng.can_play(C, inst).ok:
		return
	var per: int = Eng.preview_dmg(C, d, e)
	var hits: int = f.get("hits", 1)
	var hp0: int = e.hp
	Eng.play_card(C, inst.uid, e)
	var got: int = hp0 - e.hp
	ok(got == per * hits, "%s: en combate (3 Calor, 3 Cuerda) la carta muestra %d%s y el motor hace %d" % [d.name, per, (" ×%d" % hits) if hits > 1 else "", got])


## Supernova: «+35 %» en el texto y 1,35 en el motor (antes decía +50 %).
func _supernova() -> void:
	var d := Eng.card_def({"id": "aurora_supernova", "up": false})
	var p := roundi((float(d.fx.heatMul) - 1.0) * 100.0)
	ok(_card_text(d).contains("+%d%%" % p), "Supernova: el texto no dice +%d%%: %s" % [p, _card_text(d)])
	var C := _combat("aurora")
	var inst := Eng.make_card(C.G, "aurora_supernova")
	C.hand.append(inst)
	C.pl.status = {"heat": 2}
	var e: Dictionary = C.enemies[0]
	Eng.play_card(C, inst.uid, e)
	ok(5000 - e.hp == floori(int(d.fx.dmg) * (1.0 + p / 100.0)), "Supernova: con Calor hace %d, el texto promete %d +%d%%" % [5000 - e.hp, d.fx.dmg, p])


# ---------- reliquias ----------
func _relics() -> void:
	for id in DB.relics.keys():
		var r: Dictionary = DB.relics[id]
		var char: String = r.get("char", "claudia" if id in ["sello_osty", "craneo_cristal"] else "zafiro")
		var text: String = r.d
		var nums := _nums(text)
		var changes := []
		# combate: inicio, inicio de turno 1..3, fin de turno, carta (poder) jugada, muerte, barajar
		for hook in ["onCombatStart", "onTurnStart1", "onTurnStart2", "onTurnStart3", "onTurnEnd", "onCardPlayed", "onKill", "onShuffle"]:
			var C := _combat(char)
			var h: String = hook
			if hook.begins_with("onTurnStart"):
				C.turn = int(hook.right(1))
				h = "onTurnStart"
			if hook == "onTurnEnd":
				C.pl.status = {"cuerda": 5}
			if hook == "onCardPlayed":
				C.playedThisTurn = 3
			var a := _m(C)
			Relics.run(id, h, C, {"inst": {}, "d": {"type": "power"}} if h == "onCardPlayed" else null)
			changes.append_array(_relic_changes(id, hook, _delta(a, _m(C))))
		# fuera de combate (G): fin de combate y al recogerla
		for hook in ["onCombatEnd", "onPickup"]:
			var G := Eng.new_run(char, {"seed": 7})
			G.hp = 10
			var a := {"hp": G.hp, "maxHp": G.maxHp, "potSlots": G.potions.size()}
			Relics.run(id, hook, G)
			var b := {"hp": G.hp, "maxHp": G.maxHp, "potSlots": G.potions.size()}
			var dl := _delta(a, b)
			if hook == "onPickup" and dl.get("hp", 0) and dl.get("maxHp", 0) and b.hp == b.maxHp and id == "pozo":
				dl.erase("hp")   # «te curas por completo»
			changes.append_array(_relic_changes(id, hook, dl))
		if changes.is_empty():
			warn("reliquia %s: sin efecto medible con estos ganchos («%s»)" % [id, text])
			continue
		for c in changes:
			if RELIC_OK.has(id) and not (abs(c[1]) in nums):
				continue
			ok(abs(c[1]) in nums, "reliquia %s (%s): el motor cambia %s en %+d y el texto dice «%s»" % [id, c[2], c[0], c[1], text])


func _relic_changes(_id: String, hook: String, dl: Dictionary) -> Array:
	var out := []
	for k in dl.keys():
		if k == "hand" and dl.has("firstTurnDraw") or k == "drawPile" and hook != "onCombatStart":
			continue
		out.append([k, dl[k], hook])
	return out


# ---------- pociones ----------
func _potions() -> void:
	for id in DB.potions.keys():
		var p: Dictionary = DB.potions[id]
		var char := "zafiro"
		var C := _combat(char)
		C.G.potions[0] = id
		for i in 4:
			C.discard.append(Eng.make_card(C.G, "zafiro_strike"))
		var a := _m(C)
		var e: Dictionary = C.enemies[0]
		Eng.use_potion(C, 0, e)
		var dl := _delta(a, _m(C))
		var nums := _nums(p.d)
		if dl.is_empty():
			warn("poción %s: sin efecto medible («%s»)" % [id, p.d])
			continue
		for k in dl.keys():
			var v: int = abs(dl[k])
			if p.d.contains("%") and k == "hp":
				var pct: int = nums[0] if not nums.is_empty() else 0
				ok(v == ceili(C.G.maxHp * pct / 100.0), "poción %s: cura %d y el texto dice «%s»" % [id, v, p.d])
				continue
			if k in ["hand", "drawPile"] and (id == "gambito" or id == "memoria" or id == "rapidez" and k == "drawPile"):
				continue   # «descarta tu mano y roba otras tantas» / «recupera 1 carta» no son números del texto
			ok(v in nums, "poción %s: el motor cambia %s en %+d y el texto dice «%s»" % [id, k, dl[k], p.d])


# ---------- estados de poderes ----------
## Cada poder de carta usa Eng.st_desc(k, n): el número de la carta debe salir en el texto.
func _powers() -> void:
	var seen := {}
	for id in DB.cards.keys():
		for up in [false, true]:
			var d := Eng.card_def({"id": id, "up": up})
			if not d.fx.has("pw"):
				continue
			for k in d.fx.pw.keys():
				var n: int = int(d.fx.pw[k])
				var key := "%s/%d" % [k, n]
				if seen.has(key):
					continue
				seen[key] = true
				var t := Eng.st_desc(k, n)
				if n > 1 and not (n in _nums(t)):
					warn("poder %s ×%d (%s): la descripción no muestra el número: %s" % [k, n, d.name, _plain(t)])
