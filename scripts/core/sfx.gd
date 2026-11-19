extends Node
## Efectos de sonido sintetizados (mismas recetas que el web) y música con fundido cruzado.

const RATE := 22050
const ZONE := ["underdocks", "overgrowth", "hive"]

var _sounds := {}
var _pool: Array[AudioStreamPlayer] = []
var _pool_i := 0
var _mus: Array[AudioStreamPlayer] = []
var _mus_cur := -1
var _cur_name := ""
var _last_track := ""
var _last_req: Array = []
var _fade_tw: Tween


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in 10:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 2:
		var p := AudioStreamPlayer.new()
		p.volume_db = -80.0
		add_child(p)
		_mus.append(p)
	_build_sounds()
	# alias
	_sounds["select_soft"] = _sounds["select"]


# ---------- Síntesis ----------
## Cada evento: ["t", f0, f1, dur, tipo, vol, delay] o ["n", dur, vol, hp, delay]
func _render(events: Array) -> AudioStreamWAV:
	var total := 0.0
	for e in events:
		total = maxf(total, (e[3] + e[6]) if e[0] == "t" else (e[1] + e[4]))
	total += 0.05
	var n := int(total * RATE)
	var buf := PackedFloat32Array()
	buf.resize(n)
	for e in events:
		if e[0] == "t":
			var f0: float = e[1]
			var f1: float = maxf(20.0, e[2])
			var dur: float = e[3]
			var typ: String = e[4]
			var vol: float = e[5]
			var start := int(e[6] * RATE)
			var cnt := int(dur * RATE)
			var phase := 0.0
			for i in cnt:
				if start + i >= n:
					break
				var t := float(i) / RATE
				var f := f0 * pow(f1 / f0, t / dur)
				phase += f / RATE
				var ph := fposmod(phase, 1.0)
				var s := 0.0
				match typ:
					"sine": s = sin(ph * TAU)
					"triangle": s = 4.0 * absf(ph - 0.5) - 1.0
					"square": s = 1.0 if ph < 0.5 else -1.0
					"sawtooth": s = 2.0 * ph - 1.0
				var env: float
				if t < 0.01:
					env = pow(10.0, lerpf(-4.0, 0.0, t / 0.01))
				else:
					env = pow(10.0, lerpf(0.0, -4.0, (t - 0.01) / maxf(0.001, dur - 0.01)))
				buf[start + i] += s * env * vol * 1.6
		else:
			var dur2: float = e[1]
			var vol2: float = e[2]
			var hp: float = e[3]
			var start2 := int(e[4] * RATE)
			var cnt2 := int(dur2 * RATE)
			var a := exp(-TAU * hp / RATE)   # filtro paso alto de un polo
			var prev_x := 0.0
			var prev_y := 0.0
			var rng := RandomNumberGenerator.new()
			rng.seed = 12345 + start2
			for i in cnt2:
				if start2 + i >= n:
					break
				var x := rng.randf_range(-1.0, 1.0) * (1.0 - float(i) / cnt2)
				var y := a * (prev_y + x - prev_x)
				prev_x = x
				prev_y = y
				buf[start2 + i] += y * vol2 * 1.6
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var v := clampf(buf[i], -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32767.0))
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	w.data = bytes
	return w


func _t(f0: float, f1: float, dur: float, typ: String, vol: float, delay: float = 0.0) -> Array:
	return ["t", f0, f1, dur, typ, vol, delay]


func _n(dur: float, vol: float, hp: float, delay: float = 0.0) -> Array:
	return ["n", dur, vol, hp, delay]


func _build_sounds() -> void:
	var defs := {
		"click": [_t(520, 700, 0.07, "triangle", 0.18)],
		"select": [_t(380, 520, 0.08, "sine", 0.2)],
		"card": [_n(0.12, 0.25, 1500), _t(300, 180, 0.1, "triangle", 0.15)],
		"hit": [_n(0.18, 0.5, 400), _t(160, 60, 0.18, "square", 0.25)],
		"bigHit": [_n(0.3, 0.6, 200), _t(110, 40, 0.3, "sawtooth", 0.3)],
		"hurt": [_n(0.2, 0.4, 300), _t(200, 80, 0.25, "sawtooth", 0.25)],
		"block": [_t(900, 500, 0.12, "square", 0.15), _t(1300, 800, 0.1, "triangle", 0.1, 0.03)],
		"heal": [_t(500, 800, 0.15, "sine", 0.2), _t(750, 1100, 0.2, "sine", 0.15, 0.08)],
		"buff": [_t(400, 800, 0.25, "triangle", 0.2), _t(600, 1200, 0.25, "sine", 0.12, 0.05)],
		"debuff": [_t(500, 200, 0.3, "sawtooth", 0.15)],
		"die": [_n(0.4, 0.5, 200), _t(200, 40, 0.5, "sawtooth", 0.3)],
		"end": [_t(300, 220, 0.18, "triangle", 0.2)],
		"coin": [_t(1200, 1600, 0.08, "square", 0.12), _t(1600, 2000, 0.12, "square", 0.1, 0.07)],
		"win": [_t(523, 523, 0.25, "triangle", 0.22, 0.0), _t(659, 659, 0.25, "triangle", 0.22, 0.12), _t(784, 784, 0.25, "triangle", 0.22, 0.24), _t(1047, 1047, 0.25, "triangle", 0.22, 0.36)],
		"lose": [_t(400, 360, 0.4, "sawtooth", 0.2, 0.0), _t(330, 297, 0.4, "sawtooth", 0.2, 0.2), _t(260, 234, 0.4, "sawtooth", 0.2, 0.4), _t(180, 162, 0.4, "sawtooth", 0.2, 0.6)],
		"potion": [_t(300, 900, 0.3, "sine", 0.2), _n(0.15, 0.15, 3000, 0.1)],
		"error": [_t(160, 120, 0.15, "square", 0.15)],
		"fire": [_n(0.35, 0.4, 600), _t(120, 300, 0.3, "sawtooth", 0.15)],
		"poison": [_t(220, 330, 0.25, "sawtooth", 0.12), _n(0.2, 0.15, 2500)],
		# Fase 2.1: un sonido propio para cada acción del combate
		"blockUp": [_t(600, 1200, 0.12, "triangle", 0.18), _t(1800, 1500, 0.24, "sine", 0.13, 0.04), _n(0.08, 0.1, 4000)],
		"blocked": [_n(0.06, 0.45, 2500), _t(2200, 1700, 0.18, "square", 0.07), _t(1400, 1150, 0.3, "triangle", 0.2), _t(120, 70, 0.12, "sine", 0.32)],
		"poisonApply": [_t(300, 620, 0.07, "sine", 0.2), _t(380, 760, 0.07, "sine", 0.17, 0.07), _t(260, 560, 0.08, "sine", 0.17, 0.14), _t(180, 90, 0.3, "sawtooth", 0.06)],
		"orbChannel": [_t(300, 900, 0.28, "sine", 0.22), _t(450, 1350, 0.28, "triangle", 0.1, 0.02), _t(1800, 2400, 0.22, "sine", 0.07, 0.12)],
		"orbEvoke": [_n(0.25, 0.35, 900), _t(1400, 180, 0.35, "sine", 0.26), _t(700, 90, 0.3, "triangle", 0.15, 0.02)],
		"heavy": [_t(90, 38, 0.38, "sine", 0.55), _n(0.22, 0.45, 150), _t(180, 60, 0.18, "square", 0.12)],
		"playerDie": [_n(0.6, 0.32, 120), _t(330, 55, 1.1, "sawtooth", 0.24), _t(220, 40, 1.2, "sine", 0.36, 0.05)],
		"relic": [_t(1568, 1568, 0.35, "sine", 0.14), _t(2093, 2093, 0.45, "sine", 0.12, 0.06), _t(3136, 3136, 0.3, "sine", 0.05, 0.1)],
		"enemyTurn": [_t(110, 70, 0.4, "sawtooth", 0.14), _n(0.3, 0.2, 250), _t(220, 150, 0.3, "triangle", 0.1, 0.12)],
		"turn": [_t(523, 523, 0.12, "triangle", 0.16), _t(784, 784, 0.22, "triangle", 0.16, 0.09)],
		"danger": [_t(70, 45, 0.14, "sine", 0.6), _t(70, 45, 0.16, "sine", 0.5, 0.2), _t(440, 415, 0.4, "square", 0.04)],
	}
	for k in defs.keys():
		_sounds[k] = _render(defs[k])


func play(name: String, vol_scale: float = 1.0) -> void:
	if not _sounds.has(name) or Meta.settings.sfx <= 0.0:
		return
	var p := _pool[_pool_i]
	_pool_i = (_pool_i + 1) % _pool.size()
	p.stream = _sounds[name]
	p.volume_db = linear_to_db(clampf(Meta.settings.sfx * vol_scale * 0.9, 0.001, 2.0))
	p.play()


# ---------- Música ----------
func _candidates(kind: String, act: int, extra: String) -> Dictionary:
	var z: String = ZONE[clampi(act, 1, 3) - 1]
	match kind:
		"menu": return {"list": ["menu_" + extra, "glory_explore", "explore"], "random": false}
		"map": return {"list": [z + "_explore", "travel1", "travel2", "explore"], "random": true}
		"combat": return {"list": ["nightmare", z + "_combat", z + "_combat2", "combat"] if extra != "" else [z + "_combat", z + "_combat2", "combat"], "random": true}
		"elite": return {"list": ["combat", z + "_combat2", z + "_combat", "boss"], "random": true}
		"boss": return {"list": ["boss_" + z, "boss", z + "_combat2"], "random": false}
		"event": return {"list": ["event", z + "_explore", "explore"], "random": false}
		"shop": return {"list": ["shop", z + "_explore", "explore"], "random": false}
		"rest": return {"list": ["rest", z + "_explore", "explore"], "random": false}
		"ending": return {"list": ["ending", "glory_explore", "explore"], "random": false}
		"victory": return {"list": ["glory_combat", "glory_explore", "explore"], "random": false}
		"nightmare": return {"list": ["nightmare", "boss"], "random": false}
	return {"list": ["explore"], "random": false}


func _track_gain(name: String) -> float:
	return clampf(DB.music_gains.get(name, 1.0), 0.5, 4.0)


func _level(name: String) -> float:
	return Meta.settings.music * 1.25 * _track_gain(name)


func music(kind: String, act: int = 1, extra: String = "") -> void:
	var c := _candidates(kind, act, extra)
	var avail := []
	for n in c.list:
		if ResourceLoader.exists("res://assets/music/%s.ogg" % n):
			avail.append(n)
	if avail.is_empty():
		return
	_last_req = [kind, act, extra]
	var name: String
	if c.random:
		var pool := avail.filter(func(n): return n != _cur_name and n != _last_track)
		if pool.is_empty():
			pool = avail
		name = pool[randi() % pool.size()]
	else:
		name = avail[0]
	if name == _cur_name:
		return
	_last_track = _cur_name
	_cur_name = name
	var stream: AudioStream = load("res://assets/music/%s.ogg" % name)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var nxt := 1 - _mus_cur if _mus_cur >= 0 else 0
	var inc := _mus[nxt]
	var out: AudioStreamPlayer = _mus[_mus_cur] if _mus_cur >= 0 else null
	inc.stream = stream
	inc.volume_db = -80.0
	inc.play()
	_mus_cur = nxt
	if _fade_tw and _fade_tw.is_valid():
		_fade_tw.kill()
	_fade_tw = create_tween().set_parallel(true)
	_fade_tw.tween_property(inc, "volume_db", linear_to_db(maxf(0.0001, _level(name))), 1.8)
	if out != null and out.playing:
		_fade_tw.tween_property(out, "volume_db", -80.0, 1.8)
		_fade_tw.chain().tween_callback(out.stop)


func apply_music_volume() -> void:
	if _mus_cur >= 0 and _mus[_mus_cur].playing:
		_mus[_mus_cur].volume_db = linear_to_db(maxf(0.0001, _level(_cur_name)))


func restart_music() -> void:
	_cur_name = ""
	if _last_req.size() == 3:
		music(_last_req[0], _last_req[1], _last_req[2])
