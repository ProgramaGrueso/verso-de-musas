extends SceneTree
## Localización del contenido (Fase 5): falla si algún texto de datos (carta, reliquia, poción, enemigo y sus
## movimientos, evento, estado, lore, logro, favor…) no tiene traducción EN en translations/content_en.po, si el
## cargador real (Loc) no la aplica, si quedan frases en español en cartas/eventos con el idioma en inglés, o si
## al volver a «es» el español no queda idéntico.
## Uso: godot --headless --path . --script tests/content_loc_test.gd

const PO := "res://translations/content_en.po"
var fails := 0
var checks := 0


func ok(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails += 1
		if fails <= 60:
			print("FALLA: ", msg)


func _init() -> void:
	TranslationServer.set_locale("es")
	DB.load_all()
	Progress.defs()
	var po := {}   # msgid -> msgstr (String) o [singular, plural]; sin los fuzzy
	for e in load("res://tests/content_loc_po.gd").entries(PO):
		if not e.fuzzy:
			po[e.id] = e.str if e.plural != "" else (e.str[0] if e.str.size() > 0 else "")
	# 1) cada texto de datos que DB traduce en su sitio tiene msgstr EN (por categoría)
	var missing := {}
	var es_before := {}
	for list in [DB._loc, DB._loc_ext]:
		for e in list:
			var src: String = e[2]
			es_before[[e[0], e[1]]] = e[0][e[1]]
			var tr = po.get(src)
			var good: bool = tr != null and (tr is String and tr != "" or tr is Array and not tr.has(""))
			if not good:
				var cat := _cat_of(src)
				missing[cat] = missing.get(cat, 0) + 1
			ok(good, "sin traducción EN (%s): %s" % [_cat_of(src), src.left(90)])
	var es_snap := _snapshot()
	# 2) el cargador real del juego (Loc) carga los .po y el contenido cambia a inglés
	var n := Loc.load_translations()
	ok(n >= 1, "Loc.load_translations no cargó ningún .po")
	TranslationServer.set_locale("en")
	DB.relocalize()
	for id in DB.cards.keys():
		var es_name: String = DB.es("cards/%s/name" % id)
		if po.has(es_name) and po[es_name] is String:
			ok(DB.cards[id].name == po[es_name], "carta %s: el nombre no se tradujo (%s)" % [id, DB.cards[id].name])
	var en_snap := _snapshot()
	var same := 0
	for k in es_snap.keys():
		if es_snap[k] == en_snap.get(k) and not _same_ok(k, es_snap[k]):
			same += 1
			ok(false, "sigue en español con locale en: %s = %s" % [k, str(es_snap[k]).left(90)])
	# palabras que delatan español en el texto inglés de cartas y eventos
	var rx := RegEx.create_from_string("[áéíóúñ¡¿]|\\b(Obtén|Inflige|Roba|Aplica|daño|cartas?|Pierdes|Ganas|Recuperas|Elige|Añade)\\b")
	for k in en_snap.keys():
		var v := String(en_snap[k])
		if k.begins_with("deathBy"):
			continue
		ok(rx.search(_strip_bb(v)) == null, "español en el texto inglés: %s = %s" % [k, v.left(90)])
	# 3) de vuelta a «es»: idéntico al de partida
	TranslationServer.set_locale("es")
	DB.relocalize()
	for key in es_before.keys():
		ok(key[0][key[1]] == es_before[key], "no vuelve al español: %s" % es_before[key])
	var back := _snapshot()
	for k in es_snap.keys():
		ok(back.get(k) == es_snap[k], "texto distinto al volver a es: %s" % k)
	print("\nfaltan por categoría: %s" % str(missing))
	print("RESULTADO: %d comprobaciones, %d fallan (msgids EN: %d)" % [checks, fails, po.size()])
	quit(1 if fails else 0)


## Textos generados por código (no solo datos): cartas con sus líneas, estados, eventos, favores, reto, logros.
func _snapshot() -> Dictionary:
	var s := {}
	for id in DB.cards.keys():
		var d := Eng.card_def({"id": id, "up": false})
		var L: Dictionary = CardText.lines(d)
		s["card/" + id] = d.name + " | " + " | ".join(L.lines)
		s["cardtip/" + id] = CardText.glossary_tip(L.kws)
	for t in CardText.TYPE_ES.keys():
		s["type/" + t] = CardText.TYPE_ES[t]
	for k in DB.st.keys():
		s["st/" + k] = Eng.st_name(k) + " · " + Eng.st_desc(k, 2)
	for id in DB.relics.keys():
		s["relic/" + id] = DB.relics[id].n + " · " + DB.relics[id].d
	for id in DB.potions.keys():
		s["potion/" + id] = DB.potions[id].n + " · " + DB.potions[id].d
	for id in DB.enemies.keys():
		var e: Dictionary = DB.enemies[id]
		s["enemy/" + id] = e.name
		for m in e.moves.keys():
			if e.moves[m].has("name"):
				s["move/%s/%s" % [id, m]] = e.moves[m].name
	for ev in DB.events:
		var G := Eng.new_run("zafiro", {"seed": 5})
		s["ev/%s/title" % ev.id] = ev.title
		s["ev/%s/text" % ev.id] = EventsLogic.text_for(G, ev)
		var opts: Array = EventsLogic.options(G, ev.id)
		for i in opts.size():
			s["ev/%s/%d" % [ev.id, i]] = "%s · %s" % [opts[i].t, opts[i].hint]
	for id in Favors.DEFS.keys():
		s["favor/" + id] = Favors.DEFS[id].name + " · " + Favors.DEFS[id].desc
	for m in Daily.MODS.keys():
		s["daily/" + m] = Daily.mod_name(m) + " · " + Daily.mod_desc(m)
	for a in Progress.achievements():
		s["ach/" + a.id] = a.n + " · " + a.d
	for g in Progress.groups():
		s["group/" + g.id] = Progress.group_text(g)
	for l in DB.lore:
		s["lore/" + l.id] = l.title + " · " + l.text
	return s


## Nombres propios que se escriben igual en los dos idiomas.
func _same_ok(_k: String, v) -> bool:
	return String(v) == "" or String(v).trim_suffix("+") in ["Supernova", "Tsunami", "Perpetuum Mobile", "Eclipse", "Vulnerable", "Osty"] \
		or String(v).begins_with("Perpetuum Mobile · ") or String(v).begins_with("Vulnerable · ") \
		or String(v).begins_with("Eclipse · ")


func _strip_bb(v: String) -> String:
	var rx := RegEx.create_from_string("\\[[^\\]]*\\]")
	return rx.sub(v, "", true)


func _cat_of(src: String) -> String:
	for p in DB._loc_src.keys():
		if DB._loc_src[p] == src:
			return p.split("/")[0]
	return "?"
