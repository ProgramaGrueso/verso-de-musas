extends Node
## Termina partidas ganando, perdiendo y rindiéndose, y abre el Historial con el detalle de cada una.
## Ejecutar con los datos redirigidos para no tocar tu progreso: XDG_DATA_HOME=/tmp/x godot --path . res://tests/history_test.tscn

var main: Control


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _ready() -> void:
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var before: int = Meta.history().size()
	for kind in ["win", "lose", "surrender", "daily"]:
		var G := Eng.new_run("selene", {"seed": 31337})
		G.map = RunGen.gen_map_game(G)
		G.stats["played"] = {"selene_strike": 7} if DB.cards.has("selene_strike") else {}
		G.act = 2
		G.floor = 11
		Meta.run = G
		match kind:
			"win":
				G.act = 3
				Nav.victory()
				await wait(0.4)
			"lose":
				G["deathBy"] = "Mantis de Espinas"
				Nav.game_over()
				await wait(0.8)
			"surrender":
				G["surrender"] = true
				Nav.game_over()
				await wait(0.8)
			"daily":
				G["daily"] = Daily.key_today()
				G["dailyMod"] = Daily.MODS.keys()[0] if Daily.MODS is Dictionary else ""
				Meta.record_run(G, false)
	var n: int = Meta.history().size() - before
	print("partidas registradas: ", n, " (esperadas 4)")
	Nav.history()
	await wait(0.8)
	var hs = Main.I.screen if "screen" in Main.I else null
	var fails := 0
	if n != 4:
		fails += 1
	for h in Meta.history():
		var scr := HistoryScreen.new()
		add_child(scr)
		await wait(0.1)
		scr._show_detail(h)
		await wait(0.2)
		for c in Main.I.overlay_host.get_children():
			c.queue_free()
		scr.queue_free()
		print("detalle ok: ", h.get("char"), " win=", h.get("win"), " surrender=", h.get("surrender"), " by=", h.get("by"), " daily=", h.get("daily"))
	print("OK" if fails == 0 else "FALLA")
	get_tree().quit()
