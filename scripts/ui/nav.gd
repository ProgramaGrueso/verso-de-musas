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

static func gallery(from_run: bool = false) -> void:
	var s := GalleryScreen.new()
	s.from_run = from_run
	Main.I.set_screen(s, "gallery")

static func game_over() -> void:
	Main.I.set_screen(EndScreen.new(), "end")

static func victory() -> void:
	var G = Meta.run
	Meta.clear_save()
	var new_nm: bool = mini(10, G.get("nm", 0) + 1) > Meta.nm_unlocked(G.char)
	Meta.win_run(G.char, G.get("nm", 0))
	Meta.data.lastWinner = G.char
	Meta.data.seenEnding = true
	var e := EndingScreen.new()
	e.char = G.char
	e.nm = G.get("nm", 0)
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
		G.map = RunGen.gen_map(G)
		if G.act == 3:
			Meta.add("act3")
		G.hp = G.maxHp   # se recupera por completo entre zonas
		map(true)
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
		"combat": combat(RunGen.encounter_for(G, "normal"), "normal")
		"elite": combat(RunGen.encounter_for(G, "elite"), "elite")
		"boss": combat(RunGen.encounter_for(G, "boss"), "boss")
		"event": event()
		"shop": shop()
		"rest": rest()

## Limpia el estado de combate al salir de la partida (guardar y salir / rendirse).
static func leave_run() -> void:
	if Main.I.screen != null and Main.I.screen.has_method("cleanup"):
		Main.I.screen.cleanup()
	Main.I.on_potion = Callable()
