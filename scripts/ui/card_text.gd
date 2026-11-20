class_name CardText
extends RefCounted
## Texto de las cartas (port de cardLines en ui/core.js). Devuelve líneas en BBCode y las palabras clave que aparecen.
## Localización (Fase 5): cada línea es UNA plantilla completa en español (msgid) con marcadores {x} que se
## traduce con DB.tl/DB.tln y luego se rellena con String.format; nunca se pegan trozos de frase. Las palabras
## clave (kws) siguen siendo las españolas (claves de DB.glos); solo su etiqueta visible se traduce.

const KW_COLOR := "#ffe08a"
const TYPE_SRC := {"attack": "Ataque", "skill": "Habilidad", "power": "Poder", "status": "Estado", "curse": "Maldición"}   # loc-strings
## Nombre del tipo en el idioma activo (lo rehace relocalize()).
static var TYPE_ES := TYPE_SRC.duplicate()
const TYPE_EMO := {"attack": "⚔️", "skill": "🛡️", "power": "✨", "status": "🩸", "curse": "👁️"}


static func relocalize() -> void:
	for k in TYPE_SRC.keys():
		TYPE_ES[k] = DB.tl(TYPE_SRC[k])


## Plantilla traducida y rellenada: _f("Obtén {n} de {kw}.", {"n": 3, "kw": "..."}).
static func _f(s: String, args: Dictionary) -> String:
	return DB.tl(s).format(args)


## Ídem con plural según n.
static func _fn(s: String, p: String, n: int, args: Dictionary) -> String:
	return DB.tln(s, p, n).format(args)


static func _kw(kws: Array, w: String, label: String = "") -> String:
	if not (w in kws):
		kws.append(w)
	return "[color=%s][b]%s[/b][/color]" % [KW_COLOR, DB.tl(label if label != "" else w)]


static func _num(base: int, computed) -> String:
	if computed == null or computed == base:
		return str(base)
	var col := "#8dff9d" if computed > base else "#ff8d8d"
	return "[color=%s][b]%d[/b][/color]" % [col, computed]


static func _bolts(n: int) -> String:
	var ic := Icons.bb("ui", "energy", 15)
	return (ic if ic != "" else "⚡").repeat(mini(n, 5))


## Orbe como palabra clave: la clave del glosario es su nombre español; la etiqueta, el traducido.
static func _orb_kw(kws: Array, t: String) -> String:
	var es := DB.es("orb/%s/n" % t)
	return _kw(kws, es if es != "" else DB.orb[t].n, DB.orb[t].n)


static func lines(d: Dictionary, C = null, target = null) -> Dictionary:
	var f: Dictionary = d.fx
	var L: Array = []
	var kws: Array = []
	var all_kw := _kw(kws, "TODOS") if f.get("all", false) else ""
	var tgt = target
	if tgt == null and C != null:
		var live := Eng.living(C)
		if live.size() == 1:
			tgt = live[0]
	if f.get("selfdmg", 0): L.append(_f("Pierdes {n} PV.", {"n": f.selfdmg}))
	if f.get("energy", 0): L.append(_f("Obtén {e}.", {"e": _bolts(f.energy)}))
	if f.get("tstr", 0): L.append(_f("Obtén {n} de {kw} hasta el fin del turno.", {"n": f.tstr, "kw": _kw(kws, "Fuerza")}))
	if f.get("str", 0): L.append(_f("Obtén {n} de {kw}.", {"n": f.str, "kw": _kw(kws, "Fuerza")}))
	if f.get("dex", 0): L.append(_f("Obtén {n} de {kw}.", {"n": f.dex, "kw": _kw(kws, "Destreza")}))
	if f.get("doubleStr", false): L.append(_f("Duplica tu {kw}.", {"kw": _kw(kws, "Fuerza")}))
	if f.get("doubleBlock", false): L.append(_f("Duplica tu {kw}.", {"kw": _kw(kws, "Bloqueo")}))
	if f.get("block", 0):
		L.append(_f("Obtén {n} de {kw}.", {"n": _num(f.block, Eng.calc_block(C, f.block) if C != null else null), "kw": _kw(kws, "Bloqueo")}))
	if f.get("blockPerOrb", 0):
		var extra := (" (%d)" % Eng.calc_block(C, f.blockPerOrb * C.orbs.size())) if C != null else ""
		L.append(_f("Obtén {n} de {kw} por cada {orb}{extra}.", {"n": f.blockPerOrb, "kw": _kw(kws, "Bloqueo"), "orb": _kw(kws, "Orbe"), "extra": extra}))
	if f.get("wind", 0): L.append(_f("Obtén {n} de {kw}.", {"n": f.wind, "kw": _kw(kws, "Cuerda")}))
	if f.get("windDouble", false): L.append(_f("Duplica tu {kw}.", {"kw": _kw(kws, "Cuerda")}))
	if f.get("slots", 0): L.append(_fn("+{n} huecos de {kw}.", "+{n} huecos de {kw}.", f.slots, {"n": f.slots, "kw": _kw(kws, "Orbe")}))
	if f.get("focus", 0): L.append(_f("Obtén {n} de {kw}.", {"n": f.focus, "kw": _kw(kws, "Resonancia")}))
	if f.has("ch"):
		var cnt := {}
		for t in f.ch:
			cnt[t] = cnt.get(t, 0) + 1
		var parts := []
		for t in cnt.keys():
			parts.append("%d %s" % [cnt[t], _orb_kw(kws, t)])
		L.append(_f("{kw} {list}.", {"kw": _kw(kws, "Canalizar"), "list": ", ".join(parts)}))
	if f.get("evoke", 0):
		if f.evoke > 1:
			L.append(_f("{ev} tu {orb} frontal {n} veces.", {"ev": _kw(kws, "Evocar"), "orb": _kw(kws, "Orbe"), "n": f.evoke}))
		else:
			L.append(_f("{ev} tu {orb} frontal.", {"ev": _kw(kws, "Evocar"), "orb": _kw(kws, "Orbe")}))
	if f.get("evokeX", false): L.append(_f("{ev} tu {orb} frontal X veces.", {"ev": _kw(kws, "Evocar"), "orb": _kw(kws, "Orbe")}))
	if f.get("evokeAll", false): L.append(_f("{ev} todos tus {orbs}.", {"ev": _kw(kws, "Evocar"), "orbs": _kw(kws, "Orbe", "orbes")}))
	if f.has("pw"):
		for k in f.pw.keys():
			L.append(Eng.st_desc(k, f.pw[k]))
	if f.get("summon", 0): L.append(_f("{osty} gana +{n} PV máx. y los recupera.", {"osty": _kw(kws, "Osty"), "n": f.summon}))
	if f.get("ostyPow", 0): L.append(_f("{osty} gana +{n} de {kw}.", {"osty": _kw(kws, "Osty"), "n": f.ostyPow, "kw": _kw(kws, "Poder")}))
	if f.get("ostyHeal", 0):
		if f.ostyHeal >= 99:
			if f.get("revive", false):
				L.append(_f("{osty} revive y se cura por completo.", {"osty": _kw(kws, "Osty")}))
			else:
				L.append(_f("{osty} se cura por completo.", {"osty": _kw(kws, "Osty")}))
		else:
			L.append(_f("{osty} recupera {n} PV.", {"osty": _kw(kws, "Osty"), "n": f.ostyHeal}))
	if f.get("dmg", 0) or f.get("dmgBlock", false) or f.get("dmgPerOrb", 0) or f.get("windSpend", 0):
		var v := ""
		if f.get("dmgBlock", false):
			var ex := (" (%d)" % Eng.preview_dmg(C, d, tgt)) if C != null else ""
			v = _f("daño igual a tu {kw}{extra}", {"kw": _kw(kws, "Bloqueo"), "extra": ex})
		elif (f.get("dmgPerOrb", 0) or f.get("windSpend", 0)) and not f.get("dmg", 0):
			var per_kw := _kw(kws, "Orbe") if f.get("dmgPerOrb", 0) else _kw(kws, "Cuerda")
			var ex := (" (%d)" % Eng.preview_dmg(C, d, tgt)) if C != null else ""
			v = _f("{n} de daño por cada {kw}{extra}", {"n": f.get("dmgPerOrb", f.get("windSpend", 0)), "kw": per_kw, "extra": ex})
		else:
			v = _f("{n} de daño", {"n": _num(f.dmg, Eng.preview_dmg(C, d, tgt) if C != null else null)})
		var a := {"v": v, "all": all_kw, "h": f.get("hits", 1)}
		if f.get("x", false):
			L.append(_f("Inflige {v} a {all} los enemigos X veces." if all_kw != "" else "Inflige {v} X veces.", a))
		elif f.get("hits", 1) > 1:
			L.append(_f("Inflige {v} a {all} los enemigos {h} veces." if all_kw != "" else "Inflige {v} {h} veces.", a))
		else:
			L.append(_f("Inflige {v} a {all} los enemigos." if all_kw != "" else "Inflige {v}.", a))
		if f.get("strMul", 1) > 1: L.append(_f("La {kw} se aplica ×{n}.", {"kw": _kw(kws, "Fuerza"), "n": f.strMul}))
		if f.get("loseBlock", false): L.append(DB.tl("Pierdes tu Bloqueo."))
		if f.get("dmgPerOrb", 0) and f.get("dmg", 0): L.append(_f("+{n} por cada {kw}.", {"n": f.dmgPerOrb, "kw": _kw(kws, "Orbe")}))
		if f.get("windDmg", 0): L.append(_f("+{n} por cada {kw}.", {"n": f.windDmg, "kw": _kw(kws, "Cuerda")}))
		if f.get("windSpend", 0) and f.get("dmg", 0): L.append(_f("Consume toda tu {kw}: +{n} de daño por carga.", {"kw": _kw(kws, "Cuerda"), "n": f.windSpend}))
		elif f.get("windSpend", 0): L.append(_f("Consume toda tu {kw}.", {"kw": _kw(kws, "Cuerda")}))
		if f.get("heatDmg", 0): L.append(_f("Consume todo el {kw}: +{n} de daño por carga.", {"kw": _kw(kws, "Calor"), "n": f.heatDmg}))
		# el porcentaje sale del multiplicador real (Supernova: 1,35 -> +35 %; antes el texto decía +50 % fijo)
		if f.get("heatMul", 0): L.append(_f("Consume todo el {kw}: +{p}% de daño.", {"kw": _kw(kws, "Calor"), "p": roundi((float(f.heatMul) - 1.0) * 100.0)}))
		if f.get("lifesteal", false): L.append(DB.tl("Te curas por el daño no bloqueado."))
		if f.get("poisonDbl", false): L.append(_f("Si tiene {kw}, el daño se duplica.", {"kw": _kw(kws, "Veneno")}))
		if f.get("fatalMax", 0): L.append(_f("Si mata, +{n} PV máx.", {"n": f.fatalMax}))
	if f.get("ostyHit", 0):
		var p = C.osty.pow if (C != null and C.osty != null) else null
		var base := "%d" % (f.ostyHit + p) if p != null else "%d+%s" % [f.ostyHit, _kw(kws, "Poder")]
		var osty := _kw(kws, "Osty")
		var a := {"osty": osty, "all": all_kw, "dmg": base + ((" ×%d" % f.hits) if f.get("hits", 1) > 1 else "")}
		L.append(_f("{osty} ataca a {all} los enemigos: {dmg}." if all_kw != "" else "{osty} ataca: {dmg}.", a))
	for st in [["vuln", "Vulnerable"], ["weak", "Débil"], ["poison", "Veneno"], ["glow", "Resplandor"]]:
		if f.get(st[0], 0):
			L.append(_f("Aplica {n} {kw} a {all} los enemigos." if all_kw != "" else "Aplica {n} {kw}.", {"n": f[st[0]], "kw": _kw(kws, st[1]), "all": all_kw}))
	if f.get("heat", 0): L.append(_f("Obtén {n} de {kw}.", {"n": f.heat, "kw": _kw(kws, "Calor")}))
	if f.get("heatDouble", false): L.append(_f("Duplica tu {kw}.", {"kw": _kw(kws, "Calor")}))
	if f.get("mirage", 0): L.append(_f("El próximo ataque que recibas este turno inflige {n} de daño al atacante.", {"n": f.mirage}))
	if f.get("reflect", false): L.append(DB.tl("Devuelves la mitad del daño bloqueado a los atacantes este turno."))
	if f.get("energyIfAttack", 0): L.append(_f("Si jugaste un ataque antes, obtén {e}.", {"e": _bolts(f.energyIfAttack)}))
	if f.get("energyIfGlow", 0): L.append(_f("Si el enemigo tiene {kw}, obtén {e}.", {"kw": _kw(kws, "Resplandor"), "e": _bolts(f.energyIfGlow)}))
	if f.get("drawIfHeat", 0): L.append(_fn("Si tienes {kw}, roba {n} carta.", "Si tienes {kw}, roba {n} cartas.", f.drawIfHeat, {"kw": _kw(kws, "Calor"), "n": f.drawIfHeat}))
	if f.get("poisonMul", 0): L.append(_f("Duplica el {kw} de un enemigo." if f.poisonMul == 2 else "Triplica el {kw} de un enemigo.", {"kw": _kw(kws, "Veneno")}))
	if f.get("heal", 0): L.append(_f("Te curas {n} PV.", {"n": f.heal}))
	if f.get("draw", 0): L.append(_fn("Roba {n} carta.", "Roba {n} cartas.", f.draw, {"n": f.draw}))
	if f.has("add"):
		var nm: String = DB.cards[f.add.id].name
		var what: String = _kw(kws, "Cuchilla", "Cuchillas" if f.add.n > 1 else "Cuchilla") if f.add.id == "lia_shiv" else nm
		L.append(_f("Añade {n} {what} a tu mano." if f.add.to == "hand" else ("Añade {n} {what} a tu mazo." if f.add.to == "draw" else "Añade {n} {what} a tu descarte."), {"n": f.add.n, "what": what}))
	if f.get("stormOfSteel", false): L.append(_f("Descarta tu mano. Añade 1 {kw} por carta descartada.", {"kw": _kw(kws, "Cuchilla")}))
	if f.get("discard", 0): L.append(_fn("Descarta {n} carta.", "Descarta {n} cartas.", f.discard, {"n": f.discard}))
	if f.get("exhaustPick", 0): L.append(_fn("{kw} {n} carta de tu mano.", "{kw} {n} carta de tu mano.", f.exhaustPick, {"kw": _kw(kws, "Agotar"), "n": f.exhaustPick}))
	if d.has("endHand") and d.endHand.get("selfdmg", 0): L.append(_f("Si está en tu mano al final del turno, pierdes {n} PV.", {"n": d.endHand.selfdmg}))
	if d.has("endHand") and d.endHand.get("weakSelf", 0): L.append(_f("Si está en tu mano al final del turno, quedas {kw}.", {"kw": _kw(kws, "Débil")}))
	var unplayable: bool = d.flags.get("unplayable", false) or (not Eng.is_x(d.cost) and d.cost == -1)
	if unplayable: L.append("[i][color=#cdb8ff]%s[/color][/i]" % DB.tl("Injugable."))
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


## Ayuda de las palabras clave: el título es la etiqueta traducida y el texto, DB.glos (ya traducido en su sitio).
static func glossary_tip(kws: Array) -> String:
	var out := []
	for k in kws:
		if DB.glos.has(k):
			out.append("[b][color=#f0cf7a]%s[/color][/b]\n%s" % [DB.tl(k), DB.glos[k]])
	return "\n\n".join(out)
