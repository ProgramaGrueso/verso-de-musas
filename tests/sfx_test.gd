extends Node
## Ningún sonido referenciado se queda mudo: cada nombre que el código pide a Sfx existe y suena.
## Uso: godot --headless --path . res://tests/sfx_test.tscn
##
## 1. Lee todos los .gd de res://scripts y saca los nombres literales que se piden a Sfx
##    (Sfx.play, CombatScreen._play_sfx, UIK._sfx / CardView._sfx, incluidos los ternarios «"a" if x else "b"»).
## 2. Cada nombre debe estar en Sfx._sounds y su onda debe tener pico y energía audibles (no silencio).
## 3. También se comprueban TODOS los efectos sintetizados (cubre llamadas con nombre en variable).
## 4. Música: cada tipo que pide el juego (Sfx.music) encuentra al menos una pista en cada acto, y cada
##    pista candidata que existe se carga, dura más de unos segundos y no es un archivo vacío.

const PEAK_MIN := 0.05    # pico mínimo (fracción de escala completa)
const RMS_MIN := 0.005    # energía mínima
const MUSIC_MIN_S := 5.0
const MUSIC_MIN_BYTES := 20000

var ok := 0
var fail := 0


func check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
	else:
		fail += 1
		print("FALLA ", label)


func _gd_files(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	d.list_dir_begin()
	var f := d.get_next()
	while f != "":
		if d.current_is_dir():
			if not f.begins_with("."):
				_gd_files(dir.path_join(f), out)
		elif f.ends_with(".gd"):
			out.append(dir.path_join(f))
		f = d.get_next()
	d.list_dir_end()


## {nombre: ["archivo:línea", ...]} con cada sonido pedido por su nombre literal.
func referenced_sounds() -> Dictionary:
	var files := []
	_gd_files("res://scripts", files)
	var call_rx := RegEx.new()
	# la llamada y sus argumentos hasta el final de la línea (el primer literal o los de un ternario)
	call_rx.compile("(?:Sfx\\.play|_play_sfx|(?<![A-Za-z_])_sfx)\\((.*)$")
	var lit_rx := RegEx.new()
	lit_rx.compile("\"([A-Za-z_][A-Za-z0-9_]*)\"")
	var out := {}
	var dyn := []
	for path in files:
		var src := FileAccess.get_file_as_string(path)
		var ln := 0
		for line in src.split("\n"):
			ln += 1
			var code := line.strip_edges()
			if code.begins_with("#") or code.begins_with("func ") or code.begins_with("static func "):
				continue
			for m in call_rx.search_all(line):
				var args := split_args(m.get_string(1))
				# el argumento del nombre: el primero, salvo UIK._sfx(nodo, "x"), que lleva el nodo delante
				var arg: String = args[0] if not args.is_empty() else ""
				if not arg.contains("\"") and args.size() > 1:
					arg = args[1]
				# en «"a" if cond else "b"» valen los dos literales
				var names := []
				for lm in lit_rx.search_all(arg):
					names.append(lm.get_string(1))
				if names.is_empty():
					dyn.append("%s:%d" % [path.get_file(), ln])
					continue
				for n in names:
					if not out.has(n):
						out[n] = []
					out[n].append("%s:%d" % [path.get_file(), ln])
	if not dyn.is_empty():
		print("aviso: llamadas con nombre en variable (cubiertas por el repaso de todos los efectos): ", ", ".join(dyn))
	return out


## Argumentos de la llamada (texto tras el paréntesis de apertura) hasta su paréntesis de cierre,
## respetando cadenas y paréntesis anidados.
func split_args(tail: String) -> Array:
	var out := []
	var cur := ""
	var depth := 0
	var in_str := false
	for i in tail.length():
		var ch := tail[i]
		if in_str:
			cur += ch
			if ch == "\"" and (i == 0 or tail[i - 1] != "\\"):
				in_str = false
			continue
		if ch == "\"":
			in_str = true
			cur += ch
		elif ch == "(":
			depth += 1
			cur += ch
		elif ch == ")":
			if depth == 0:
				break
			depth -= 1
			cur += ch
		elif ch == "," and depth == 0:
			out.append(cur.strip_edges())
			cur = ""
		else:
			cur += ch
	out.append(cur.strip_edges())
	return out


func wav_levels(w: AudioStreamWAV) -> Vector2:
	var data := w.data
	var n := data.size() / 2
	if n == 0:
		return Vector2.ZERO
	var peak := 0.0
	var acc := 0.0
	for i in n:
		var v := float(data.decode_s16(i * 2)) / 32768.0
		peak = maxf(peak, absf(v))
		acc += v * v
	return Vector2(peak, sqrt(acc / n))


func _ready() -> void:
	var sfx: Node = get_node_or_null("/root/Sfx")
	check(sfx != null, "el autoload Sfx existe")
	if sfx == null:
		_end()
		return
	var sounds: Dictionary = sfx.get("_sounds")
	check(sounds != null and not sounds.is_empty(), "Sfx sintetizó sus efectos")

	# ---------- 1-2. cada nombre referenciado existe y suena ----------
	var refs := referenced_sounds()
	check(refs.size() >= 20, "se encontraron las llamadas a Sfx en el código (%d nombres)" % refs.size())
	var names := refs.keys()
	names.sort()
	for n in names:
		if not sounds.has(n):
			check(false, "«%s» se pide en %s pero Sfx no lo tiene (sonaría en silencio)" % [n, ", ".join(refs[n])])
			continue
		var lv := wav_levels(sounds[n])
		check(lv.x >= PEAK_MIN and lv.y >= RMS_MIN, "«%s» suena (pico %.3f, rms %.4f) — usado en %s" % [n, lv.x, lv.y, refs[n][0]])
	print("sonidos referenciados: %d (%s)" % [names.size(), ", ".join(names)])

	# ---------- 3. todos los efectos sintetizados suenan ----------
	var mute := []
	for n in sounds.keys():
		var w = sounds[n]
		if not (w is AudioStreamWAV):
			mute.append("%s (no es WAV)" % n)
			continue
		var lv := wav_levels(w)
		if lv.x < PEAK_MIN or lv.y < RMS_MIN:
			mute.append("%s (pico %.3f, rms %.4f)" % [n, lv.x, lv.y])
	check(mute.is_empty(), "ningún efecto sintetizado es silencio: %s" % ", ".join(mute))
	var unused := sounds.keys().filter(func(k): return not refs.has(k))
	if not unused.is_empty():
		print("aviso: efectos que el código no pide por nombre literal: ", ", ".join(unused))

	# ---------- 4. música ----------
	var kinds := ["map", "combat", "elite", "boss", "event", "shop", "rest", "ending", "victory", "nightmare"]
	var all_tracks := {}
	for kind in kinds:
		for act in [1, 2, 3]:
			var c: Dictionary = sfx.call("_candidates", kind, act, "")
			var have := (c.list as Array).filter(func(t): return ResourceLoader.exists("res://assets/music/%s.ogg" % t))
			check(not have.is_empty(), "música «%s» (acto %d) tiene alguna pista: %s" % [kind, act, c.list])
			for t in c.list:
				all_tracks[t] = true
	for ch in DB.characters.keys():
		var c: Dictionary = sfx.call("_candidates", "menu", 1, ch)
		var have := (c.list as Array).filter(func(t): return ResourceLoader.exists("res://assets/music/%s.ogg" % t))
		check(not have.is_empty(), "música de menú de %s tiene pista" % ch)
		check(ResourceLoader.exists("res://assets/music/menu_%s.ogg" % ch), "música propia del menú de %s (menu_%s.ogg)" % [ch, ch])
		for t in c.list:
			all_tracks[t] = true
	var loaded := 0
	for t in all_tracks.keys():
		var path := "res://assets/music/%s.ogg" % t
		if not ResourceLoader.exists(path):
			continue   # candidata de reserva que no existe: la cadena salta a la siguiente
		var st = load(path)
		check(st is AudioStream, "la pista %s se carga" % t)
		if st is AudioStream:
			loaded += 1
			check((st as AudioStream).get_length() >= MUSIC_MIN_S, "la pista %s dura %.1f s" % [t, (st as AudioStream).get_length()])
			var bytes := FileAccess.get_file_as_bytes(path)
			# un .ogg exportado sale del .import; si no hay fuente en res:// se mira el recurso importado
			if bytes.size() > 0:
				check(bytes.size() >= MUSIC_MIN_BYTES, "la pista %s no es un archivo vacío (%d B)" % [t, bytes.size()])
			var gain: float = DB.music_gains.get(t, 1.0)
			check(gain > 0.0, "la pista %s no tiene ganancia 0 en music.json" % t)
	print("pistas de música comprobadas: %d" % loaded)
	_end()


func _end() -> void:
	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)
