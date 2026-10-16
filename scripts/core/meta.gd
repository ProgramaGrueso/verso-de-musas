extends Node
## Progreso entre partidas (estadísticas, Galería, Pesadilla), ajustes y guardado de la partida en curso.

signal unlocked(lore)

const META_PATH := "user://meta.json"
const SETTINGS_PATH := "user://settings.json"
const SAVE_PATH := "user://save.json"
## Al cambiar este valor se descartan una vez las partidas en curso (el progreso/galería se conserva).
const SAVE_EPOCH := "godot1"

var data := {"s": {}, "relics": [], "gal": [], "nmBy": {}, "seenEnding": false, "lastWinner": ""}
var settings := {"music": 0.5, "sfx": 0.7, "confirm": true, "fast": false, "easy": false}
var run = null   # partida en curso (G) o null
var _queue: Array = []
var _save_timer := 0.0
var _dirty := false


func _ready() -> void:
	DB.load_all()
	Eng.meta_add = add
	Eng.meta_max = max_stat
	Eng.meta_see_relic = see_relic
	_load_meta()
	_load_settings()


func _process(dt: float) -> void:
	if _dirty:
		_save_timer -= dt
		if _save_timer <= 0.0:
			_dirty = false
			_write(META_PATH, data)


func _exit_tree() -> void:
	if _dirty:
		_write(META_PATH, data)


# ---------- E/S ----------
func _write(path: String, d) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))


func _read(path: String):
	if not FileAccess.file_exists(path):
		return null
	var v = JSON.parse_string(FileAccess.get_file_as_string(path))
	return DB._intify(v) if v != null else null


func _load_meta() -> void:
	var d = _read(META_PATH)
	if d is Dictionary:
		for k in d.keys():
			data[k] = d[k]


func _load_settings() -> void:
	var d = _read(SETTINGS_PATH)
	if d is Dictionary:
		for k in d.keys():
			settings[k] = d[k]


func save_settings() -> void:
	_write(SETTINGS_PATH, settings)


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


func win_run(char: String, nm: int) -> void:
	data.s.wins = data.s.get("wins", 0) + 1
	data.s["win_" + char] = data.s.get("win_" + char, 0) + 1
	if nm >= 1:
		data.s.nm = maxi(data.s.get("nm", 0), nm)
	data.nmBy[char] = maxi(data.nmBy.get(char, 0), mini(10, nm + 1))
	_mark()
	_check()


# ---------- Guardado de la partida ----------
func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH) and _read(SAVE_PATH) != null


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
	_write(SAVE_PATH, snap)


func load_run():
	var G = _read(SAVE_PATH)
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
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
