class_name Nav
extends RefCounted
## Navegación entre pantallas (equivale a las funciones show()/xxxScreen() del web).

static func title() -> void:
	Main.I.set_screen(TitleScreen.new(), "title")

static func select() -> void:
	Meta.run = null
	Main.I.set_screen(SelectScreen.new(), "select")

static func map(announce: bool = false) -> void:
	var s := MapScreen.new()
	s.announce = announce
	Main.I.set_screen(s, "map")

static func favor() -> void:
	Main.I.set_screen(FavorScreen.new(), "favor")

static func combat(ids: Array, tier: String) -> void:
	var s := CombatScreen.new()
	s.ids = ids
	s.tier = tier
	Main.I.set_screen(s, "combat")

static func reward(rew: Dictionary, tier: String) -> void:
	var s := RewardScreen.new()
	s.rew = rew
	s.tier = tier
	Main.I.set_screen(s, "reward")

static func shop() -> void:
	Main.I.set_screen(ShopScreen.new(), "shop")

static func rest() -> void:
	Main.I.set_screen(RestScreen.new(), "rest")

static func event() -> void:
	Main.I.set_screen(EventScreen.new(), "event")

static func history() -> void:
	Main.I.set_screen(HistoryScreen.new(), "history")

static func achievements(tab: String = "ach") -> void:
	var s := AchievementsScreen.new()
	s.tab = tab
	Main.I.set_screen(s, "achievements")

static func compendium(from_run: bool = false) -> void:
	var s := CompendiumScreen.new()
	s.from_run = from_run
	Main.I.set_screen(s, "compendium")

static func daily() -> void:
	Main.I.set_screen(DailyScreen.new(), "daily")

## Revancha: misma musa, semilla, Pesadilla y modo (el reto diario repite su día).
static func rematch(G) -> void:
	if str(G.get("daily", "")) != "":
		DailyScreen.start(str(G.daily))
		return
	var H := Eng.new_run(G.char, {"easy": G.get("easy", false), "nm": int(G.get("nm", 0)), "seed": int(G.seed)})
	H["seeded"] = true
	Meta.run = H
	Meta.clear_save()
	H.map = RunGen.gen_map_game(H)
	favor()

static func gallery(from_run: bool = false) -> void:
	var s := GalleryScreen.new()
	s.from_run = from_run
	Main.I.set_screen(s, "gallery")

static func game_over() -> void:
	Meta.record_run(Meta.run, false)
	Main.I.set_screen(EndScreen.new(), "end")

static func victory() -> void:
	var G = Meta.run
	Meta.clear_save()
	var new_nm: bool = not G.easy and mini(10, G.get("nm", 0) + 1) > Meta.nm_unlocked(G.char)
	Meta.win_run(G.char, G.get("nm", 0), G.easy)
	Meta.record_run(G, true)
	Meta.data.lastWinner = G.char
	Meta.data.seenEnding = true
	var e := EndingScreen.new()
	e.char = G.char
	e.nm = G.get("nm", 0)
	e.boss = RunGen.boss_id(G)
	e.done = func(): Main.I.set_screen(EndScreen.create_victory(G, new_nm), "end")
	Main.I.set_screen(e, "ending")

static func node_done(was_boss: bool) -> void:
	var G = Meta.run
	if was_boss:
		if G.act >= 3:
			victory()
			return
		G.act += 1
		G.pos = null
		if G.get("seeded", false):
			G.rs = Eng.act_seed(G.seed, G.act)   # misma semilla = mismos mapas en cada acto
		G.map = RunGen.gen_map_game(G)
		Favors.expire(G)
		Meta.max_stat("bestAct_" + G.char, G.act)   # desbloqueos por musa («derrota al jefe del Acto I»)
		Meta.add("act%d" % G.act)   # act2 / act3 (Galería y logros)
		G.hp = G.maxHp   # se recupera por completo entre zonas
		favor()
		return
	map()

static func enter_node(n: Dictionary) -> void:
	var G = Meta.run
	G.pos = n
	n.visited = true
	if n.type == "boss":
		G.map.boss.visited = true
	G.floor += 1
	Meta.add("floors")
	match n.type:
		"combat": combat(RunGen.encounter_game(G, "normal"), "normal")
		"elite": combat(RunGen.encounter_game(G, "elite"), "elite")
		"boss": combat(RunGen.encounter_game(G, "boss"), "boss")
		"event": event()
		"shop": shop()
		"rest": rest()

## Limpia el estado de combate al salir de la partida (guardar y salir / rendirse).
static func leave_run() -> void:
	if Main.I.screen != null and Main.I.screen.has_method("cleanup"):
		Main.I.screen.cleanup()
	Main.I.on_potion = Callable()
