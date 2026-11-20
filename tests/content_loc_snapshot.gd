extends SceneTree
## Volcado determinista de TODO el texto de contenido que genera el código (cartas, estados, eventos con sus
## resultados, favores, reto diario, logros, resúmenes…) en un archivo, una entrada por línea.
## Sirve para comprobar que el juego en español queda IDÉNTICO tras la localización: se vuelca con el código
## anterior y con el nuevo y se comparan (diff). También vuelca en inglés con VDM_LANG=en para revisar.
## Uso: godot --headless --path . --script tests/content_loc_snapshot.gd -- /ruta/salida.txt [0 = sin DB.extra]

var out: Array = []


class Ctx extends RefCounted:
	var mode := "first"
	var G

	func pick_card(_title: String, filter: Callable, n: int, _up: bool = false) -> Array:
		var cards: Array = G.deck.filter(filter)
		if mode == "cancel" or cards.is_empty():
			return []
		return [cards[0] if mode == "first" else cards[cards.size() - 1]].slice(0, n)

	func choose_new(_title: String, ids: Array) -> Array:
		if mode == "cancel" or ids.is_empty():
			return []
		return [Eng.make_card(G, ids[0] if mode == "first" else ids[ids.size() - 1])]


func put(k: String, v) -> void:
	out.append("%s\t%s" % [k, str(v).replace("\n", "\\n")])


func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://content_snapshot.txt"
	DB.extra = not (args.size() > 1 and args[1] == "0")
	DB.load_all()
	if OS.get_environment("VDM_LANG") != "":
		_load_po_for_test()
	# ---- cartas, sin combate y dentro de uno (vista previa con números)
	var ids: Array = DB.cards.keys()
	ids.sort()
	for id in ids:
		for up in [false, true]:
			var d := Eng.card_def({"id": id, "up": up})
			put("card/%s/%s/name" % [id, up], d.name)
			put("card/%s/%s/lines" % [id, up], " | ".join(CardText.lines(d).lines))
			put("card/%s/%s/kws" % [id, up], ",".join(CardText.lines(d).kws))
			put("card/%s/%s/tip" % [id, up], CardText.glossary_tip(CardText.lines(d).kws))
	for ch in DB.playable():
		var G := Eng.new_run(ch, {"seed": 4242})
		var C := Eng.start_combat(G, ["dockrat"], {})
		for id in ids:
			if DB.cards[id].cls in [ch, "neutral", "x"]:
				for up in [false, true]:
					var d := Eng.card_def({"id": id, "up": up})
					put("cardC/%s/%s/%s" % [ch, id, up], " | ".join(CardText.lines(d, C).lines))
	for t in CardText.TYPE_ES.keys():
		put("type/" + t, CardText.TYPE_ES[t])
	# ---- estados y orbes
	var sk: Array = DB.st.keys()
	sk.sort()
	for k in sk:
		put("st/%s/n" % k, Eng.st_name(k))
		for n in [-2, 1, 3]:
			put("st/%s/%d" % [k, n], Eng.st_desc(k, n))
	for k in DB.orb.keys():
		put("orb/%s" % k, DB.orb[k].n + " · " + DB.orb[k].d)
	var Gp := Eng.new_run("claudia", {"seed": 1})
	Gp["perm"] = {"ostyMax": 5, "ostyPow": 1, "strength": 1, "accuracy": 2, "dexterity": 1, "precision": 2, "resonancia": 1}
	put("perm", Eng.perm_text(Gp))
	# ---- motor: motivos de no poder jugar, aturdido
	var Gc := Eng.new_run("zafiro", {"seed": 9})
	var Cc := Eng.start_combat(Gc, ["dockrat"], {})
	for inst in Cc.hand:
		put("can_play/" + inst.id, Eng.can_play(Cc, inst).get("why", ""))
	Cc.energy = 0
	for inst in Cc.hand:
		put("can_play0/" + inst.id, Eng.can_play(Cc, inst).get("why", ""))
	Cc.phase = "enemy"
	put("can_play_phase", Eng.can_play(Cc, Cc.hand[0]).get("why", ""))
	# ---- eventos: texto por musa, opciones y resultados
	var runs := 0
	for ev in DB.events:
		put("ev/%s/title" % ev.id, ev.title)
		for ch in DB.characters.keys():
			var G := Eng.new_run(ch, {"seed": 99})
			put("ev/%s/%s/text" % [ev.id, ch], EventsLogic.text_for(G, ev))
			for mode in ["first", "cancel", "last"]:
				for variant in ["normal", "pobre", "herido"]:
					var n_opts: int = EventsLogic.options(G, ev.id).size()
					for i in n_opts:
						runs += 1
						var G2 := Eng.new_run(ch, {"seed": 500 + runs})
						match variant:
							"pobre": G2.gold = 0
							"herido": G2.hp = 3
						var o: Dictionary = EventsLogic.options(G2, ev.id)[i]
						var key := "ev/%s/%s/%s/%s/%d" % [ev.id, ch, mode, variant, i]
						put(key + "/t", "%s · %s · %s" % [o.t, o.hint, o.get("ok", true)])
						if o.get("ok", true) and o.has("run"):
							var ctx := Ctx.new()
							ctx.mode = mode
							ctx.G = G2
							put(key + "/res", await o.run.call(ctx))
	# ---- favores
	for id in Favors.DEFS.keys():
		put("favor/%s" % id, "%s · %s" % [Favors.DEFS[id].name, Favors.DEFS[id].desc])
		var Gf := Eng.new_run("selene", {"seed": 31})
		Gf.hp = 20
		put("favor/%s/choose" % id, Favors.choose(Gf, id))
	# ---- reto diario
	for m in Daily.MODS.keys():
		put("daily/%s" % m, "%s · %s" % [Daily.mod_name(m), Daily.mod_desc(m)])
	put("daily/share", Daily.share_text("2026-11-20"))
	put("daily/share_win1", Daily.share_text("2026-11-20", {"win": true, "tries": 1}))
	put("daily/share_win3", Daily.share_text("2026-11-20", {"win": true, "tries": 3}))
	put("daily/share_f1", Daily.share_text("2026-11-20", {"floor": 12, "tries": 1}))
	put("daily/share_f2", Daily.share_text("2026-11-20", {"floor": 12, "tries": 2}))
	# ---- progresión
	for g in Progress.groups():
		put("group/%s" % g.id, Progress.group_text(g))
		put("group/%s/ch" % g.id, g.get("ch", ""))
	for i in range(-1, Progress.ranks().size() + 1):
		put("rank/%d" % i, Progress.rank_name(i))
	for a in Progress.achievements():
		put("ach/%s" % a.id, "%s · %s" % [a.n, a.d])
	for c in Progress.cats():
		put("cat/%s" % c.id, c.n)
	for variant in ["win", "surrender", "death", "death_by", "daily_nm_easy"]:
		var Gs := Eng.new_run("aurora", {"seed": 777})
		Gs.floor = 17
		Gs.act = 2
		Gs["stats"] = {"fights": 9, "kills": 14, "turns": 61}
		match variant:
			"surrender": Gs["surrender"] = true
			"death_by": Gs["deathBy"] = "Rata de Muelle"
			"daily_nm_easy":
				Gs["daily"] = "2026-11-20"
				Gs["dailyMod"] = "rico"
				Gs["nm"] = 4
				Gs["easy"] = true
		put("share/" + variant, Progress.share_text(Gs, variant == "win"))
	# ---- datos traducidos en su sitio (muestra)
	for id in DB.relics.keys():
		put("relic/" + id, DB.relics[id].n + " · " + DB.relics[id].d)
	for id in DB.potions.keys():
		put("potion/" + id, DB.potions[id].n + " · " + DB.potions[id].d)
	for id in DB.enemies.keys():
		var e: Dictionary = DB.enemies[id]
		var mv := []
		for k in e.moves.keys():
			mv.append(e.moves[k].get("name", ""))
		put("enemy/" + id, "%s · %s · %s" % [e.name, ", ".join(mv), e.get("phase2", {}).get("msg", "")])
	for i in DB.nm_texts.size():
		put("nm/%d" % i, DB.nm_texts[i])
	for l in DB.lore:
		put("lore/" + l.id, "%s · %s · %s" % [l.title, l.ch, l.text])
	for i in DB.acts.size():
		put("act/%d" % i, "%s · %s" % [DB.acts[i].name, DB.acts[i].sub])
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string("\n".join(out) + "\n")
	f.close()
	print("volcado: %d entradas -> %s" % [out.size(), path])
	quit(0)


## Con VDM_LANG=xx carga los .po de res://translations a mano (sin depender del arranque del juego).
func _load_po_for_test() -> void:
	var lang := OS.get_environment("VDM_LANG")
	for fn in DirAccess.get_files_at("res://translations"):
		if fn.ends_with(".po"):
			TranslationServer.add_translation(load("res://tests/content_loc_po.gd").parse_file("res://translations/" + fn, lang))
	TranslationServer.set_locale(lang)
	DB.relocalize()
