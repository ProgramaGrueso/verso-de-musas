extends Node
## Progreso entre partidas (estadísticas, Galería, Pesadilla), ajustes y guardado de la partida en curso.

signal unlocked(lore)
signal achieved(a)            # logro conseguido (Progress.achievements)
signal content_unlocked(g)    # grupo de cartas/reliquias desbloqueado (Progress.groups)

const META_PATH := "user://meta.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_PATH := "user://save.json"
## Al cambiar este valor se descartan una vez las partidas en curso (el progreso/galería se conserva).
const SAVE_EPOCH := "godot1"

var data := {"s": {}, "relics": [], "gal": [], "nmBy": {}, "seenEnding": false, "lastWinner": ""}
var settings := {"music": 0.5, "sfx": 0.7, "confirm": true, "fast": false, "easy": false, "calm": false, "language": ""}
var run = null   # partida en curso (G) o null
var _queue: Array = []
var _save_timer := 0.0
var _dirty := false


func _ready() -> void:
	DB.load_all()
	Eng.meta_add = add
	Eng.meta_max = max_stat
	Eng.meta_see_relic = see_relic
	Eng.meta_locked = locked_ids
	_load_meta()
	_load_settings()
	_setup_input_map()


func _setup_input_map() -> void:
	_ensure_joy_button("ui_accept", JOY_BUTTON_A)
	_ensure_joy_button("ui_cancel", JOY_BUTTON_B)
	_ensure_joy_button("ui_page_up", JOY_BUTTON_LEFT_SHOULDER)
	_ensure_joy_button("ui_page_down", JOY_BUTTON_RIGHT_SHOULDER)


func _ensure_joy_button(action: String, button: JoyButton) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action)
	for ev in InputMap.action_get_events(action):
		if ev is InputEventJoypadButton and ev.button_index == button:
			return
	var b := InputEventJoypadButton.new()
	b.button_index = button
	b.device = -1
	InputMap.action_add_event(action, b)


func _process(dt: float) -> void:
	if _dirty:
		_save_timer -= dt
		if _save_timer <= 0.0:
			_dirty = false
			_write(META_PATH, data, true)


func _exit_tree() -> void:
	if _dirty:
		_write(META_PATH, data, true)


# ---------- E/S ----------
## Escritura atómica: primero el .tmp, después el rename. Si el proceso muere a mitad, el archivo
## anterior sigue intacto (nunca queda un JSON truncado). Con keep_backup se guarda una copia .bak.
func _write(path: String, d, keep_backup: bool = false) -> void:
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(d))
	f.flush()
	f.close()
	if keep_backup and FileAccess.file_exists(path):
		DirAccess.copy_absolute(ProjectSettings.globalize_path(path), ProjectSettings.globalize_path(path + ".bak"))
	var err := DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))
	if err != OK:
		# último recurso: borrar el destino y reintentar; si falla, el .tmp se ignora al cargar
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path))
		DirAccess.rename_absolute(ProjectSettings.globalize_path(tmp), ProjectSettings.globalize_path(path))


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		return null
	var v = json.data
	return DB._intify(v) if v != null else null


## Lee el archivo y, si está corrupto o truncado, cae en su .bak. Devuelve null si ninguno sirve.
func _read_backup(path: String):
	var v = _read(path)
	if v != null:
		return v
	if FileAccess.file_exists(path):
		push_warning("Archivo corrupto, se usa la copia de seguridad: " + path)
	return _read(path + ".bak")


func _load_meta() -> void:
	var d = _read_backup(META_PATH)
	if d is Dictionary:
		for k in d.keys():
			data[k] = d[k]
	_sanitize_nm()
	_backfill_progress()
	Progress.check(data)   # en silencio: lo ya merecido no llena la pantalla de avisos al arrancar


## La Pesadilla de un personaje no puede superar sus victorias (cada victoria sube un solo nivel).
func _sanitize_nm() -> void:
	for c in data.nmBy.keys():
		var cap: int = int(data.s.get("win_" + c, 0))
		data.nmBy[c] = mini(int(data.nmBy[c]), cap)
	_mark()


func _load_settings() -> void:
	var d = _read_backup(SETTINGS_PATH)
	if d is Dictionary:
		for k in d.keys():
			settings[k] = d[k]
	Loc.setup(settings, d is Dictionary)   # traducciones (res://translations/*.po) e idioma: settings.language, «es» o el del sistema


func save_settings() -> void:
	_write(SETTINGS_PATH, settings, true)


func _mark() -> void:
	_dirty = true
	_save_timer = 0.25


# ---------- Estadísticas ----------
func add(k: String, n: int = 1) -> void:
	data.s[k] = data.s.get(k, 0) + n
	_mark()
	_check()


func max_stat(k: String, n: int) -> void:
	if n > data.s.get(k, 0):
		data.s[k] = n
		_mark()
		_check()


func see_relic(id: String) -> void:
	if not (id in data.relics):
		data.relics.append(id)
		_mark()
		_check()


func is_unlocked(id: String) -> bool:
	return id in data.gal


func _unlocked_count() -> int:
	var n := 0
	for g in data.gal:
		if g != "ultima":
			n += 1
	return n


func lore_value(l: Dictionary) -> int:
	var v: Dictionary = l.v
	if v.has("stat"):
		return data.s.get(v.stat, 0)
	if v.has("min"):
		var m := 1 << 30
		for k in v.min:
			m = mini(m, data.s.get(k, 0))
		return m
	if v.has("relics"):
		return data.relics.size()
	if v.has("unlocked"):
		return _unlocked_count()
	return 0


func progress(l: Dictionary) -> int:
	return mini(l.t, lore_value(l))


func _check() -> void:
	var fresh := []
	for l in DB.lore:
		if l.id in data.gal:
			continue
		if lore_value(l) >= l.t:
			data.gal.append(l.id)
			fresh.append(l)
	if not fresh.is_empty():
		_mark()
		for l in fresh:
			unlocked.emit(l)
	_check_progress()


# ---------- Logros, desbloqueos y Maestría (Fase 3, ver Progress) ----------
func _check_progress() -> void:
	var r := Progress.check(data)
	if r.unl.is_empty() and r.ach.is_empty():
		return
	_mark()
	if run is Dictionary:   # lo conseguido en esta partida se resume al terminarla
		for a in r.ach:
			run["ach"] = run.get("ach", []) + [a.id]
		for g in r.unl:
			run["unl"] = run.get("unl", []) + [g.id]
	for g in r.unl:
		content_unlocked.emit(g)
	for a in r.ach:
		achieved.emit(a)


## Cartas y reliquias bloqueadas ahora mismo (Eng.new_run las guarda en la partida).
func locked_ids() -> Array:
	return Progress.locked_ids(data)


## Una sola vez: deduce del progreso anterior lo que la Fase 3 necesita (Maestría, actos, hazañas del historial).
func _backfill_progress() -> void:
	if int(data.get("progV", 0)) >= 1:
		return
	data["progV"] = 1
	var s: Dictionary = data.s
	for c in DB.playable():
		var w := int(s.get("win_" + c, 0))
		if w > 0:
			s["mp_" + c] = maxi(int(s.get("mp_" + c, 0)), w)
			s["bestAct_" + c] = 4
	for h in history():
		var c := str(h.get("char", ""))
		var act := 4 if h.get("win", false) else int(h.get("act", 1))
		s["bestAct_" + c] = maxi(int(s.get("bestAct_" + c, 0)), act)
		if act >= 2:
			s["act2"] = maxi(int(s.get("act2", 0)), 1)
		if h.get("win", false) and not h.get("easy", false):
			if int(h.get("nm", 0)) >= 1:
				s["nmWin_" + c] = maxi(int(s.get("nmWin_" + c, 0)), int(h.nm))
			_feats(h.get("deck", []).size(), h.get("relics", []).size(), -1, -1, -1)
	if data.get("daily") is Dictionary:
		s["dailyStreakBest"] = maxi(int(s.get("dailyStreakBest", 0)), Daily.streak(data.daily).best)
	_mark()


## Hazañas de una victoria sin modo fácil (los negativos se ignoran: el historial no guarda oro ni PV).
func _feats(deck_n: int, relic_n: int, gold: int, hp: int, max_hp: int) -> void:
	var s: Dictionary = data.s
	if deck_n <= 15:
		s["feat_smallDeck"] = int(s.get("feat_smallDeck", 0)) + 1
	if deck_n >= 40:
		s["feat_bigDeck"] = int(s.get("feat_bigDeck", 0)) + 1
	if relic_n <= 4:
		s["feat_fewRelics"] = int(s.get("feat_fewRelics", 0)) + 1
	if gold >= 500:
		s["feat_rich"] = int(s.get("feat_rich", 0)) + 1
	if max_hp > 0 and hp >= ceili(max_hp * 0.9):
		s["feat_healthy"] = int(s.get("feat_healthy", 0)) + 1


func take_unlocked() -> Array:
	var q := _queue.duplicate()
	_queue.clear()
	return q


## Nivel de Pesadilla desbloqueado por personaje. Sin id: el mejor de todos.
func nm_unlocked(char: String = "") -> int:
	if char != "":
		return data.nmBy.get(char, 0)
	var m := 0
	for v in data.nmBy.values():
		m = maxi(m, v)
	return m


func win_run(char: String, nm: int, easy: bool = false) -> void:
	data.s.wins = data.s.get("wins", 0) + 1
	data.s["win_" + char] = data.s.get("win_" + char, 0) + 1
	if nm >= 1:
		data.s.nm = maxi(data.s.get("nm", 0), nm)
	if not easy:
		data.nmBy[char] = maxi(data.nmBy.get(char, 0), mini(10, nm + 1))
		if nm >= 1:
			data.s["nmWin_" + char] = maxi(int(data.s.get("nmWin_" + char, 0)), nm)
	data.s["mp_" + char] = int(data.s.get("mp_" + char, 0)) + Progress.mastery_gain(nm, easy)
	data.s["bestAct_" + char] = 4
	_mark()
	_check()


# ---------- Historial de partidas y reto diario ----------
const HISTORY_MAX := 60
const DAILY_KEEP := 400


## Guarda un resumen de la partida terminada (victoria, derrota o rendición). Solo una vez por partida.
func record_run(G, won: bool) -> void:
	if G == null or G.get("recorded", false):
		return
	G["recorded"] = true
	var deck := []
	for c in G.deck:
		deck.append(c.id + ("+" if c.up else ""))
	var played: Dictionary = G.stats.get("played", {})
	var ids: Array = played.keys()
	ids.sort_custom(func(a, b): return played[a] > played[b])
	var top := []
	for id in ids.slice(0, 5):
		top.append([id, played[id]])
	var h := {
		"t": int(Time.get_unix_time_from_system()), "char": G.char, "win": won, "nm": int(G.get("nm", 0)), "easy": bool(G.easy),
		"seed": int(G.seed), "daily": str(G.get("daily", "")), "mod": str(G.get("dailyMod", "")), "act": int(G.act), "floor": int(G.floor),
		"by": "" if G.get("surrender", false) else str(G.get("deathBy", "")), "surrender": bool(G.get("surrender", false)),
		"deck": deck, "relics": G.relics.duplicate(), "maxHp": int(G.maxHp),
		"fights": int(G.stats.fights), "kills": int(G.stats.kills), "turns": int(G.stats.turns), "top": top,
	}
	if not data.has("history") or not (data.history is Array):
		data["history"] = []
	data.history.push_front(h)
	if data.history.size() > HISTORY_MAX:
		data.history.resize(HISTORY_MAX)
	# acumulados por musa: no se pierden al recortar el historial
	var st: Dictionary = data.s
	st["runs_" + G.char] = st.get("runs_" + G.char, 0) + 1
	st["bestFloor_" + G.char] = maxi(st.get("bestFloor_" + G.char, 0), int(G.floor))
	if not data.has("cardsPlayed") or not (data.cardsPlayed is Dictionary):
		data["cardsPlayed"] = {}
	for id in played.keys():
		data.cardsPlayed[id] = data.cardsPlayed.get(id, 0) + played[id]
	st["bestAct_" + G.char] = maxi(int(st.get("bestAct_" + G.char, 0)), 4 if won else int(G.act))
	if won and not G.easy:
		_feats(G.deck.size(), G.relics.size(), int(G.gold), int(G.hp), int(G.maxHp))
	if str(G.get("daily", "")) != "":
		_record_daily(G, won)
	_mark()
	_check()


func history() -> Array:
	return data.get("history", [])


## Resultado del reto diario de ese día: {tries, win, floor, char}
func daily_result(key: String) -> Dictionary:
	var d = data.get("daily", {})
	if d is Dictionary and d.has(key):
		return d[key]
	return {}


func daily_started(key: String, char: String) -> void:
	if not data.has("daily") or not (data.daily is Dictionary):
		data["daily"] = {}
	var r: Dictionary = data.daily.get(key, {"tries": 0, "win": false, "floor": 0, "char": char})
	r.tries = int(r.get("tries", 0)) + 1
	data.daily[key] = r
	# conserva algo más de un año (calendario mensual y racha); cada día ocupa unos pocos bytes
	var keys: Array = data.daily.keys()
	keys.sort()
	while keys.size() > DAILY_KEEP:
		data.daily.erase(keys.pop_front())
	_mark()


func _record_daily(G, won: bool) -> void:
	var key := str(G.daily)
	if not data.has("daily") or not (data.daily is Dictionary):
		data["daily"] = {}
	var r: Dictionary = data.daily.get(key, {"tries": 1, "win": false, "floor": 0, "char": G.char})
	# fuera de plazo (revancha de un día pasado): cuenta en el calendario, no en la racha ni en los logros
	var late: bool = G.get("dailyLate", false)
	if won and late:
		r["lateWin"] = true
	elif won:
		r.win = true
	r.floor = maxi(int(r.get("floor", 0)), int(G.floor))
	data.daily[key] = r
	if won and not late:
		data.s["dailyStreakBest"] = maxi(int(data.s.get("dailyStreakBest", 0)), Daily.streak(data.daily).best)
		add("dailyWins")


## Racha del reto diario: {cur, best} (días seguidos superados el mismo día).
func daily_streak() -> Dictionary:
	var d = data.get("daily", {})
	return Daily.streak(d if d is Dictionary else {})


# ---------- Guardado de la partida ----------
func has_save() -> bool:
	return _read_backup(SAVE_PATH) != null


func save_run(G) -> void:
	if G == null or G.map == null:
		return
	var m: Dictionary = G.map
	var idx := func(n):
		if n == null:
			return null
		return "B" if n.type == "boss" else m.rows[n.r].find(n)
	var rows := []
	for row in m.rows:
		var cells := []
		for n in row:
			var nx := []
			for x in n.next:
				nx.append("B" if x.type == "boss" else m.rows[x.r].find(x))
			cells.append({"r": n.r, "c": n.c, "type": n.type, "visited": n.visited, "next": nx})
		rows.append(cells)
	var snap: Dictionary = G.duplicate()
	snap.map = {"rows": rows, "boss": {"visited": m.boss.visited}}
	snap.pos = null if G.pos == null else {"r": G.pos.r, "i": idx.call(G.pos)}
	snap["_epoch"] = SAVE_EPOCH
	_write(SAVE_PATH, snap, true)


func load_run():
	var G = _read_backup(SAVE_PATH)
	if G == null or G.get("_epoch", "") != SAVE_EPOCH:
		return null
	var rows := []
	for row in G.map.rows:
		var cells := []
		for n in row:
			cells.append({"r": n.r, "c": n.c, "type": n.type, "visited": n.visited, "next": []})
		rows.append(cells)
	var boss := {"r": G.map.rows.size(), "c": 1.5, "type": "boss", "next": [], "visited": G.map.boss.visited}
	for r in G.map.rows.size():
		for i in G.map.rows[r].size():
			for x in G.map.rows[r][i].next:
				rows[r][i].next.append(boss if str(x) == "B" else rows[r + 1][int(x)])
	G.map = {"rows": rows, "boss": boss}
	if G.pos != null:
		G.pos = boss if str(G.pos.i) == "B" else rows[int(G.pos.r)][int(G.pos.i)]
	G.erase("_epoch")
	return G


func clear_save() -> void:
	for p in [SAVE_PATH, SAVE_PATH + ".bak", SAVE_PATH + ".tmp"]:
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
