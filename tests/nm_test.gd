extends SceneTree
## Valida la escalera de Pesadilla de data/balance_w2.json: 10 niveles, entre 1 y 3 cambios por escalón,
## severidad monótona y sin saltos bruscos en PV/daño. La curva de victorias se mide aparte con
## `balance.gd -- 200 sweep all 1`.

const KEYS := ["hp", "dmg", "gold", "rest", "wound", "doubt", "eliteStr", "bossStr", "allStr", "eliteBlock", "bossBlock", "plHp", "pots"]


func _init() -> void:
	DB.extra = true
	DB.load_all()
	var fails := 0
	var t: Array = DB.bal.get("nm", [])
	if t.size() != 10:
		print("FALLA: la escalera tiene %d niveles (esperado 10)" % t.size())
		fails += 1
	if DB.nm_texts.size() != 11:
		print("FALLA: nm_texts tiene %d entradas (esperado 11)" % DB.nm_texts.size())
		fails += 1
	for n in range(1, 11):
		if str(DB.nm_texts[n] if n < DB.nm_texts.size() else "").strip_edges() == "":
			print("FALLA: el nivel %d no tiene texto" % n)
			fails += 1
	var prev: Dictionary = Eng.nm_mods(0)
	for n in range(1, t.size() + 1):
		var m: Dictionary = Eng.nm_mods(n)
		var changes := []
		for k in KEYS:
			if m.get(k) != prev.get(k):
				changes.append(k)
		if changes.size() < 1 or changes.size() > 3:
			print("FALLA: el nivel %d cambia %d cosas a la vez (debe ser 1-3) (%s)" % [n, changes.size(), ", ".join(changes)])
			fails += 1
		if m.hp < prev.hp or m.dmg < prev.dmg or m.gold > prev.gold or m.rest > prev.rest:
			print("FALLA: el nivel %d no es más difícil que el %d (multiplicadores)" % [n, n - 1])
			fails += 1
		if m.eliteStr < prev.eliteStr or m.bossStr < prev.bossStr or m.allStr < prev.allStr:
			print("FALLA: el nivel %d no es más difícil que el %d (Fuerza)" % [n, n - 1])
			fails += 1
		if m.get("eliteBlock", 0) < prev.get("eliteBlock", 0) or m.get("bossBlock", 0) < prev.get("bossBlock", 0) or m.get("plHp", 1.0) > prev.get("plHp", 1.0) or m.get("pots", 3) > prev.get("pots", 3):
			print("FALLA: el nivel %d no es más difícil que el %d (bloqueo/PV/pociones)" % [n, n - 1])
			fails += 1
		if prev.wound and not m.wound:
			print("FALLA: el nivel %d quita la Herida" % n)
			fails += 1
		if (prev.doubt and not m.doubt):
			print("FALLA: el nivel %d quita la Duda" % n)
			fails += 1
		prev = m
	for n in range(2, t.size() + 1):
		var a: Dictionary = Eng.nm_mods(n - 1)
		var b: Dictionary = Eng.nm_mods(n)
		if b.hp > a.hp + 0.05 or b.dmg > a.dmg + 0.05:
			print("FALLA: el nivel %d sube PV o daño más de 5 puntos de golpe" % n)
			fails += 1
	print("escalera: %d niveles, NM10 = hp x%.2f, dmg x%.2f" % [t.size(), Eng.nm_mods(10).hp, Eng.nm_mods(10).dmg])
	print("RESULTADO: %d fallan" % fails)
	quit(1 if fails else 0)
