class_name CardText
extends RefCounted
## Texto de las cartas (port de cardLines en ui/core.js). Devuelve líneas en BBCode y las palabras clave que aparecen.

const KW_COLOR := "#ffe08a"
const TYPE_ES := {"attack": "Ataque", "skill": "Habilidad", "power": "Poder", "status": "Estado", "curse": "Maldición"}
const TYPE_EMO := {"attack": "⚔️", "skill": "🛡️", "power": "✨", "status": "🩸", "curse": "👁️"}


static func _kw(kws: Array, w: String, label: String = "") -> String:
	if not (w in kws):
		kws.append(w)
	return "[color=%s][b]%s[/b][/color]" % [KW_COLOR, label if label != "" else w]


static func _num(base: int, computed) -> String:
	if computed == null or computed == base:
		return str(base)
	var col := "#8dff9d" if computed > base else "#ff8d8d"
	return "[color=%s][b]%d[/b][/color]" % [col, computed]


static func _bolts(n: int) -> String:
	var ic := Icons.bb("ui", "energy", 15)
	return (ic if ic != "" else "⚡").repeat(mini(n, 5))


static func lines(d: Dictionary, C = null, target = null) -> Dictionary:
	var f: Dictionary = d.fx
	var L: Array = []
	var kws: Array = []
	var all := (" a " + _kw(kws, "TODOS") + " los enemigos") if f.get("all", false) else ""
	var tgt = target
	if tgt == null and C != null:
		var live := Eng.living(C)
		if live.size() == 1:
			tgt = live[0]
	if f.get("selfdmg", 0): L.append("Pierdes %d PV." % f.selfdmg)
	if f.get("energy", 0): L.append("Obtén %s." % _bolts(f.energy))
	if f.get("tstr", 0): L.append("Obtén %d de %s hasta el fin del turno." % [f.tstr, _kw(kws, "Fuerza")])
	if f.get("str", 0): L.append("Obtén %d de %s." % [f.str, _kw(kws, "Fuerza")])
	if f.get("dex", 0): L.append("Obtén %d de %s." % [f.dex, _kw(kws, "Destreza")])
	if f.get("doubleStr", false): L.append("Duplica tu %s." % _kw(kws, "Fuerza"))
	if f.get("doubleBlock", false): L.append("Duplica tu %s." % _kw(kws, "Bloqueo"))
	if f.get("block", 0):
		L.append("Obtén %s de %s." % [_num(f.block, Eng.calc_block(C, f.block) if C != null else null), _kw(kws, "Bloqueo")])
	if f.get("blockPerOrb", 0):
		var extra := (" (%d)" % Eng.calc_block(C, f.blockPerOrb * C.orbs.size())) if C != null else ""
		L.append("Obtén %d de %s por cada %s%s." % [f.blockPerOrb, _kw(kws, "Bloqueo"), _kw(kws, "Orbe"), extra])
	if f.get("wind", 0): L.append("Obtén %d de %s." % [f.wind, _kw(kws, "Cuerda")])
	if f.get("windDouble", false): L.append("Duplica tu %s." % _kw(kws, "Cuerda"))
	if f.get("slots", 0): L.append("+%d huecos de %s." % [f.slots, _kw(kws, "Orbe")])
	if f.get("focus", 0): L.append("Obtén %d de %s." % [f.focus, _kw(kws, "Resonancia")])
	if f.has("ch"):
		var cnt := {}
		for t in f.ch:
			cnt[t] = cnt.get(t, 0) + 1
		var parts := []
		for t in cnt.keys():
			parts.append("%s %s" % [str(cnt[t]) if cnt[t] > 1 else "1", _kw(kws, DB.orb[t].n)])
		L.append("%s %s." % [_kw(kws, "Canalizar"), ", ".join(parts)])
	if f.get("evoke", 0):
		L.append("%s tu %s frontal%s." % [_kw(kws, "Evocar"), _kw(kws, "Orbe"), (" %d veces" % f.evoke) if f.evoke > 1 else ""])
	if f.get("evokeX", false): L.append("%s tu %s frontal X veces." % [_kw(kws, "Evocar"), _kw(kws, "Orbe")])
	if f.get("evokeAll", false): L.append("%s todos tus %s." % [_kw(kws, "Evocar"), _kw(kws, "Orbe", "orbes")])
	if f.has("pw"):
		for k in f.pw.keys():
			L.append(Eng.st_desc(k, f.pw[k]))
	if f.get("summon", 0): L.append("%s gana +%d PV máx. y los recupera." % [_kw(kws, "Osty"), f.summon])
	if f.get("ostyPow", 0): L.append("%s gana +%d de %s." % [_kw(kws, "Osty"), f.ostyPow, _kw(kws, "Poder")])
	if f.get("ostyHeal", 0):
		if f.ostyHeal >= 99:
			L.append("%s %sse cura por completo." % [_kw(kws, "Osty"), "revive y " if f.get("revive", false) else ""])
		else:
			L.append("%s recupera %d PV." % [_kw(kws, "Osty"), f.ostyHeal])
	if f.get("dmg", 0) or f.get("dmgBlock", false) or f.get("dmgPerOrb", 0) or f.get("windSpend", 0):
		var v := ""
		if f.get("dmgBlock", false):
			v = "daño igual a tu " + _kw(kws, "Bloqueo")
			if C != null:
				v += " (%d)" % Eng.preview_dmg(C, d, tgt)
		elif (f.get("dmgPerOrb", 0) or f.get("windSpend", 0)) and not f.get("dmg", 0):
			v = "%d de daño por cada %s" % [f.get("dmgPerOrb", f.get("windSpend", 0)), _kw(kws, "Orbe") if f.get("dmgPerOrb", 0) else _kw(kws, "Cuerda")]
			if C != null:
				v += " (%d)" % Eng.preview_dmg(C, d, tgt)
		else:
			v = "%s de daño" % _num(f.dmg, Eng.preview_dmg(C, d, tgt) if C != null else null)
		var t := "Inflige %s%s" % [v, all]
		if f.get("x", false):
			t += " X veces"
		elif f.get("hits", 1) > 1:
			t += " %d veces" % f.hits
		L.append(t + ".")
		if f.get("strMul", 1) > 1: L.append("La %s se aplica ×%d." % [_kw(kws, "Fuerza"), f.strMul])
		if f.get("loseBlock", false): L.append("Pierdes tu Bloqueo.")
		if f.get("dmgPerOrb", 0) and f.get("dmg", 0): L.append("+%d por cada %s." % [f.dmgPerOrb, _kw(kws, "Orbe")])
		if f.get("windDmg", 0): L.append("+%d por cada %s." % [f.windDmg, _kw(kws, "Cuerda")])
		if f.get("windSpend", 0) and f.get("dmg", 0): L.append("Consume toda tu %s: +%d de daño por carga." % [_kw(kws, "Cuerda"), f.windSpend])
		elif f.get("windSpend", 0): L.append("Consume toda tu %s." % _kw(kws, "Cuerda"))
		if f.get("heatDmg", 0): L.append("Consume todo el %s: +%d de daño por carga." % [_kw(kws, "Calor"), f.heatDmg])
		if f.get("heatMul", 0): L.append("Consume todo el %s: +50%% de daño." % _kw(kws, "Calor"))
		if f.get("lifesteal", false): L.append("Te curas por el daño no bloqueado.")
		if f.get("poisonDbl", false): L.append("Si tiene %s, el daño se duplica." % _kw(kws, "Veneno"))
		if f.get("fatalMax", 0): L.append("Si mata, +%d PV máx." % f.fatalMax)
	if f.get("ostyHit", 0):
		var p = C.osty.pow if (C != null and C.osty != null) else null
		var base := "%d" % (f.ostyHit + p) if p != null else "%d+%s" % [f.ostyHit, _kw(kws, "Poder")]
		L.append("%s ataca%s: %s%s." % [_kw(kws, "Osty"), all, base, (" ×%d" % f.hits) if f.get("hits", 1) > 1 else ""])
	if f.get("vuln", 0): L.append("Aplica %d %s%s." % [f.vuln, _kw(kws, "Vulnerable"), all])
	if f.get("weak", 0): L.append("Aplica %d %s%s." % [f.weak, _kw(kws, "Débil"), all])
	if f.get("poison", 0): L.append("Aplica %d %s%s." % [f.poison, _kw(kws, "Veneno"), all])
	if f.get("glow", 0): L.append("Aplica %d %s%s." % [f.glow, _kw(kws, "Resplandor"), all])
	if f.get("heat", 0): L.append("Obtén %d de %s." % [f.heat, _kw(kws, "Calor")])
	if f.get("heatDouble", false): L.append("Duplica tu %s." % _kw(kws, "Calor"))
	if f.get("mirage", 0): L.append("El próximo ataque que recibas este turno inflige %d de daño al atacante." % f.mirage)
	if f.get("reflect", false): L.append("Devuelves la mitad del daño bloqueado a los atacantes este turno.")
	if f.get("energyIfAttack", 0): L.append("Si jugaste un ataque antes, obtén %s." % _bolts(f.energyIfAttack))
	if f.get("energyIfGlow", 0): L.append("Si el enemigo tiene %s, obtén %s." % [_kw(kws, "Resplandor"), _bolts(f.energyIfGlow)])
	if f.get("drawIfHeat", 0): L.append("Si tienes %s, roba %d carta%s." % [_kw(kws, "Calor"), f.drawIfHeat, "s" if f.drawIfHeat > 1 else ""])
	if f.get("poisonMul", 0): L.append("%s el %s de un enemigo." % ["Duplica" if f.poisonMul == 2 else "Triplica", _kw(kws, "Veneno")])
	if f.get("heal", 0): L.append("Te curas %d PV." % f.heal)
	if f.get("draw", 0): L.append("Roba %d carta%s." % [f.draw, "s" if f.draw > 1 else ""])
	if f.has("add"):
		var nm: String = DB.cards[f.add.id].name
		var what: String = _kw(kws, "Cuchilla", "Cuchillas" if f.add.n > 1 else "Cuchilla") if f.add.id == "lia_shiv" else nm
		var where := "tu mano" if f.add.to == "hand" else ("tu mazo" if f.add.to == "draw" else "tu descarte")
		L.append("Añade %d %s a %s." % [f.add.n, what, where])
	if f.get("stormOfSteel", false): L.append("Descarta tu mano. Añade 1 %s por carta descartada." % _kw(kws, "Cuchilla"))
	if f.get("discard", 0): L.append("Descarta %d carta%s." % [f.discard, "s" if f.discard > 1 else ""])
	if f.get("exhaustPick", 0): L.append("%s %d carta de tu mano." % [_kw(kws, "Agotar"), f.exhaustPick])
	if d.has("endHand") and d.endHand.get("selfdmg", 0): L.append("Si está en tu mano al final del turno, pierdes %d PV." % d.endHand.selfdmg)
	if d.has("endHand") and d.endHand.get("weakSelf", 0): L.append("Si está en tu mano al final del turno, quedas %s." % _kw(kws, "Débil"))
	var unplayable: bool = d.flags.get("unplayable", false) or (not Eng.is_x(d.cost) and d.cost == -1)
	if unplayable: L.append("[i][color=#cdb8ff]Injugable.[/color][/i]")
	var fl := []
	if d.flags.get("innate", false): fl.append(_kw(kws, "Innata"))
	if d.flags.get("retain", false): fl.append(_kw(kws, "Retener"))
	if d.get("dance", false): fl.append(_kw(kws, "Danza"))
	if d.get("gear", false): fl.append(_kw(kws, "Engranaje"))
	if d.flags.get("ethereal", false): fl.append(_kw(kws, "Etérea"))
	if d.flags.get("exhaust", false): fl.append(_kw(kws, "Agotar"))
	if not fl.is_empty():
		L.append("[i][color=#cdb8ff]%s[/color][/i]" % " · ".join(fl))
	return {"lines": L, "kws": kws}


static func glossary_tip(kws: Array) -> String:
	var out := []
	for k in kws:
		if DB.glos.has(k):
			out.append("[b][color=#f0cf7a]%s[/color][/b]\n%s" % [k, DB.glos[k]])
	return "\n\n".join(out)
