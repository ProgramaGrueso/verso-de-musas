extends SceneTree
## Fase 3: logros, desbloqueo de contenido, Maestría, reto diario con histórico y resúmenes compartibles.
## godot --headless --path . --script tests/progress_test.gd

var fails := 0
var oks := 0


func ok(cond: bool, what: String) -> void:
	if cond:
		oks += 1
	else:
		fails += 1
		print("FALLA: ", what)


func _init() -> void:
	DB.load_all()
	_defs()
	_locks()
	_engine_filters()
	_conditions()
	_mastery()
	_daily()
	_share()
	print("RESULTADO: %d ok, %d fallan" % [oks, fails])
	quit(1 if fails else 0)


func _icon(kind: String, id: String) -> bool:
	return ResourceLoader.exists("res://assets/icons/%s_%s.webp" % [kind, id])


# ---------- Definiciones ----------
func _defs() -> void:
	var achs := Progress.achievements()
	ok(achs.size() >= 30, "hay ~30 logros (%d)" % achs.size())
	var ids := {}
	var cats := {}
	for c in Progress.cats():
		cats[c.id] = true
		var p := str(c.icon).split(":")
		ok(_icon(p[0], p[1]), "icono de categoría " + c.id)
	for a in achs:
		ok(not ids.has(a.id), "id de logro único " + a.id)
		ids[a.id] = true
		ok(cats.has(a.cat), "categoría válida " + a.id)
		ok(ResourceLoader.exists(Progress.art_path(a.art)), "arte del logro %s (%s)" % [a.id, a.art])
		var p := str(a.icon).split(":")
		ok(_icon(p[0], p[1]), "icono del logro " + a.id)
		ok(Progress.target(a) >= 1, "meta positiva " + a.id)
	ok(Progress.groups().size() >= 15, "grupos de desbloqueo (%d)" % Progress.groups().size())
	for g in Progress.groups():
		ok(str(g.get("ch", "")) != "" and int(g.t) >= 1, "condición legible " + g.id)
		for id in g.cards:
			ok(DB.cards.has(id) and not (id in DB.starters.get(g.pool, [])), "carta bloqueable existe y no es inicial: " + id)
		for id in g.relics:
			ok(DB.relics.has(id) and DB.relics[id].rarity != "start", "reliquia bloqueable no inicial: " + id)
		ok(Progress.group_text(g) != "", "texto del grupo " + g.id)
	# las cartas del juego web nunca se bloquean (solo la Oleada 1/2)
	var base: Dictionary = DB._read("cards").pool
	var rbase: Dictionary = DB._read("relics").relics
	for id in Progress.locked_ids({"s": {}}):
		var web := false
		for k in base.keys():
			if id in base[k]:
				web = true
		ok(not web and not rbase.has(id), "solo se bloquea contenido nuevo: " + id)


# ---------- Desbloqueos ----------
func _locks() -> void:
	var data := {"s": {}}
	var lk := Progress.locked_ids(data)
	ok(not lk.is_empty(), "al empezar hay contenido bloqueado")
	# set inicial justo: cada musa conserva cartas de las tres rarezas y hay reliquias de todas las rarezas
	for c in DB.playable():
		var G := {"locked": lk}
		var pl := Eng.unlocked(G, DB.pool[c])
		var rar := {}
		for id in pl:
			rar[DB.cards[id].rarity] = rar.get(DB.cards[id].rarity, 0) + 1
		ok(pl.size() >= 20 and rar.get("common", 0) >= 8 and rar.get("uncommon", 0) >= 8 and rar.get("rare", 0) >= 3,
			"set inicial jugable de %s: %s" % [c, rar])
		var G2 := {"locked": lk, "relics": [], "char": c}
		for r in ["common", "uncommon", "boss"]:
			ok(Eng._relic_candidates(G2, r).size() >= 2, "reliquias %s disponibles al empezar con %s" % [r, c])
		# las 3 raras (Oleada 2) llegan tras 2 jefes: mientras, el sorteo por rarezas cae a poco común
		var G3 := {"locked": lk, "relics": [], "char": c, "rs": 99, "potions": [], "nm": 0}
		var none := 0
		for i in 30:
			if Eng.random_relic_tiered(G3) == null:
				none += 1
		ok(none == 0, "sin raras desbloqueadas siempre sale alguna reliquia con %s" % c)
	ok(Eng.unlocked({"locked": lk}, DB.neutral).size() >= 8, "neutrales comunes disponibles al empezar")
	# una partida con Zafiro desbloquea sus poco comunes y el Estandarte
	var g1 := Progress.lock_group("estandarte")
	ok(g1.get("id", "") == "zafiro_1" and Progress.is_locked(data, "estandarte"), "Estandarte bloqueado por zafiro_1")
	data.s["runs_zafiro"] = 1
	var r := Progress.check(data)
	var got := []
	for g in r.unl:
		got.append(g.id)
	ok(got == ["zafiro_1"], "check desbloquea zafiro_1 (%s)" % [got])
	ok(not Progress.is_locked(data, "estandarte"), "Estandarte disponible tras desbloquear")
	for id in g1.cards:
		ok(not (id in Progress.locked_ids(data)), "carta de zafiro_1 desbloqueada: " + id)
	ok(Progress.check(data).unl.is_empty(), "check no repite desbloqueos")
	# sin contenido ampliado nada se bloquea (paridad de las trazas del web)
	DB.extra = false
	ok(Progress.locked_ids({"s": {}}).is_empty(), "DB.extra=false: locked_ids vacío")
	ok(not Progress.is_locked({"s": {}}, "estandarte"), "DB.extra=false: nada bloqueado")
	DB.extra = true
	# Archivo Completo (t = -1) exige todos los grupos
	var all := {"s": {}, "unl": []}
	for g in Progress.groups():
		all.unl.append(g.id)
	ok(Progress.value(all, {"unlocks": true}) == Progress.target(Progress.find_ach("archivo")), "Archivo Completo cuenta todos los grupos")
	var ra := Progress.check(all)
	ok(Progress.has_ach(all, "archivo"), "Archivo Completo se consigue con todo desbloqueado")
	ok(Progress.locked_ids(all).is_empty(), "con todo desbloqueado no queda nada bloqueado")


# ---------- Motor: lo bloqueado no sale en botín, tiendas, eventos ni favores ----------
func _engine_filters() -> void:
	var data := {"s": {}}
	Eng.meta_locked = func(): return Progress.locked_ids(data)
	var bad := 0
	var bad_rel := 0
	for c in DB.playable():
		for sd in 40:
			var G := Eng.new_run(c, {"seed": 1000 + sd})
			ok(G.has("locked"), "new_run guarda la foto de bloqueos")
			if not G.has("locked"):
				break
			for id in Eng.reward_cards(G, 3):
				if id in G.locked:
					bad += 1
			for i in 3:
				var rl = Eng.random_relic(G)
				if rl != null and rl in G.locked:
					bad_rel += 1
			var shop := RunGen.gen_shop(G)
			for it in shop.get("cards", []):
				var cid: String = it.id if it is Dictionary and it.has("id") else str(it)
				if cid in G.locked:
					bad += 1
	ok(bad == 0, "ninguna carta bloqueada en botín/tienda (%d)" % bad)
	ok(bad_rel == 0, "ninguna reliquia bloqueada en botín (%d)" % bad_rel)
	# el reto diario ignora los bloqueos (igual para todo el mundo) y marca los días pasados
	var D := Daily.new_run(Daily.key_today())
	ok(not D.has("locked") and not D.get("dailyLate", false), "reto de hoy: sin bloqueos y no tardío")
	var P := Daily.new_run(Daily.shift(Daily.key_today(), -3))
	ok(P.get("dailyLate", false), "reto de un día pasado: marcado como revancha tardía")
	# sin contenido ampliado new_run no bloquea nada
	DB.extra = false
	var N := Eng.new_run("zafiro", {"seed": 7})
	ok(not N.has("locked"), "DB.extra=false: la partida no guarda bloqueos")
	DB.extra = true
	Eng.meta_locked = Callable()
	var M := Eng.new_run("zafiro", {"seed": 7})
	ok(not M.has("locked"), "sin Meta (trazas/balance) no hay bloqueos")


# ---------- Condiciones de logros ----------
func _conditions() -> void:
	var d := {"s": {"boss_reina": 1, "boss_kraken": 2, "elites": 4, "runs_zafiro": 3, "runs_lia": 2, "win_zafiro": 1, "wins": 1}}
	ok(Progress.value(d, {"sum": "boss_"}) == 3, "sum de jefes")
	ok(Progress.value(d, {"count": "boss_"}) == 2, "count de jefes distintos")
	ok(Progress.value(d, {"min": ["runs_zafiro", "runs_lia", "runs_x"]}) == 0, "min con stat ausente")
	ok(Progress.value({"relics": ["a", "b"]}, {"relics": true}) == 2, "reliquias vistas")
	var r := Progress.check(d)
	var ids := []
	for a in r.ach:
		ids.append(a.id)
	for want in ["primer_jefe", "primer_elite", "primera_victoria", "voz_zafiro", "cinco_partidas"]:
		ok(want in ids, "logro conseguido: " + want)
	ok(not ("voz_lia" in ids) and not ("nm10" in ids), "no da logros sin cumplirlos")
	ok(d.ach.has("primer_jefe") and int(d.ach.primer_jefe) > 0, "guarda la fecha del logro")
	ok(Progress.ach_count(d) == ids.size(), "ach_count coincide")
	ok(Progress.check(d).ach.is_empty(), "check no repite logros")
	var a := Progress.find_ach("cinco_partidas")
	ok(Progress.ach_progress({"s": {"runs_lia": 2}}, a) == 2, "progreso parcial de un logro")


# ---------- Maestría ----------
func _mastery() -> void:
	ok(Progress.mastery_gain(0, true) == 0, "modo fácil no suma Maestría")
	ok(Progress.mastery_gain(0, false) == 1 and Progress.mastery_gain(4, false) == 2 and Progress.mastery_gain(8, false) == 3, "puntos por Pesadilla")
	ok(Progress.mastery_rank({"s": {}}, "zafiro") == -1, "sin puntos no hay rango")
	ok(Progress.mastery_rank({"s": {"mp_zafiro": 1}}, "zafiro") == 0, "1 punto = Aprendiz")
	ok(Progress.mastery_rank({"s": {"mp_zafiro": 6}}, "zafiro") == 2, "6 puntos = Solista")
	ok(Progress.rank_name(Progress.ranks().size() - 1) == "Leyenda", "rango máximo")
	var d := {"s": {"mp_lia": 15}}
	Progress.check(d)
	ok(Progress.has_ach(d, "leyenda_viva"), "Leyenda Viva con rango Maestra")


# ---------- Reto diario: racha, calendario, revancha ----------
func _daily() -> void:
	ok(Daily.shift("2026-02-28", 1) == "2026-03-01" and Daily.shift("2026-01-01", -1) == "2025-12-31", "shift cruza meses y años")
	var d := {
		"2026-11-15": {"win": true, "tries": 1}, "2026-11-16": {"win": true, "tries": 2}, "2026-11-17": {"win": true, "tries": 1},
		"2026-11-10": {"win": true}, "2026-11-11": {"win": true}, "2026-11-12": {"win": true}, "2026-11-13": {"win": true},
		"2026-11-18": {"win": false, "tries": 3, "floor": 9}, "2026-11-05": {"win": false, "lateWin": true, "tries": 1},
	}
	ok(Daily.streak(d, "2026-11-18").cur == 3, "hoy aún sin superar: la racha llega hasta ayer")
	var s := Daily.streak(d, "2026-11-19")
	ok(s.cur == 0, "racha rota si ayer no se superó (%d)" % s.cur)
	ok(s.best == 4, "mejor racha 4 (10-13) (%d)" % s.best)
	ok(Daily.streak(d, "2026-11-17").cur == 3, "racha viva incluyendo hoy")
	d["2026-11-18"].win = true
	ok(Daily.streak(d, "2026-11-19").cur == 4, "hoy sin jugar: la racha sigue hasta ayer")
	ok(Daily.day_state(d, "2026-11-05", "2026-11-19") == "late", "día superado fuera de plazo")
	ok(Daily.day_state(d, "2026-11-15", "2026-11-19") == "win", "día superado")
	ok(Daily.day_state(d, "2026-11-01", "2026-11-19") == "none", "día sin jugar")
	ok(Daily.day_state(d, "2026-11-25", "2026-11-19") == "future", "día futuro")
	ok(Daily.day_state({"2026-11-02": {"tries": 2, "win": false}}, "2026-11-02", "2026-11-19") == "tried", "día intentado")
	var m := Daily.month_days(2026, 11)
	ok(m.keys.size() == 30 and m.first_wd == 6, "noviembre 2026: 30 días, empieza en domingo (%d, %d)" % [m.keys.size(), m.first_wd])
	var f := Daily.month_days(2028, 2)
	ok(f.keys.size() == 29 and f.keys[28] == "2028-02-29", "febrero bisiesto")
	ok(Daily.shift_month(Vector2i(2026, 1), -1) == Vector2i(2025, 12) and Daily.shift_month(Vector2i(2026, 12), 1) == Vector2i(2027, 1), "cambio de mes en el calendario")


# ---------- Resúmenes compartibles ----------
func _share() -> void:
	var G := Eng.new_run("lia", {"seed": 424242, "nm": 3})
	G.floor = 17
	G.act = 2
	G["deathBy"] = "Matriarca"
	var t := Progress.share_text(G, false)
	ok(t.contains("424242") and t.contains("Lia") and t.contains("Derrota") and t.contains("Pesadilla 3") and t.contains("piso 17"), "resumen de derrota:\n" + t)
	var D := Daily.new_run("2026-11-19")
	var tw := Progress.share_text(D, true)
	ok(tw.contains("Victoria") and tw.contains("Reto diario 2026-11-19") and tw.contains(str(D.seed)), "resumen de victoria del diario:\n" + tw)
	var ds := Daily.share_text("2026-11-19", {"win": true, "tries": 2})
	ok(ds.contains("2026-11-19") and ds.contains("2 intentos") and ds.contains(str(Daily.info("2026-11-19").seed)), "código del reto:\n" + ds)
