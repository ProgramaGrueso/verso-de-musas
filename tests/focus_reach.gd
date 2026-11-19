extends Node
## Auditoría de mando: en cada pantalla comprueba que haya foco inicial y que todos los controles
## enfocables visibles se alcancen con el D-Pad (find_valid_focus_neighbor).
## Uso: godot --path . res://tests/focus_reach.tscn


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func focusables(n: Node, out: Array) -> void:
	if n is Control:
		var c := n as Control
		if c.focus_mode == Control.FOCUS_ALL and c.is_visible_in_tree() and c.size.x > 2:
			if not (c is BaseButton and (c as BaseButton).disabled):
				out.append(c)
	for ch in n.get_children():
		focusables(ch, out)


func check(name: String, root: Node) -> int:
	var all := []
	focusables(root, all)
	var start: Control = get_viewport().gui_get_focus_owner()
	if all.is_empty():
		print("[%s] sin controles enfocables (puede ser normal)" % name)
		return 0
	if start == null:
		print("[%s] FALLA: sin foco inicial (%d enfocables)" % [name, all.size()])
		return 1
	var seen := {start: true}
	var q := [start]
	while not q.is_empty():
		var c: Control = q.pop_front()
		for side in [SIDE_LEFT, SIDE_RIGHT, SIDE_TOP, SIDE_BOTTOM]:
			var nb := c.find_valid_focus_neighbor(side)
			if nb != null and not seen.has(nb):
				seen[nb] = true
				q.append(nb)
	var miss := all.filter(func(c): return not seen.has(c))
	if miss.is_empty():
		print("[%s] OK (%d enfocables, todos alcanzables)" % [name, all.size()])
		return 0
	print("[%s] FALLA: %d de %d no alcanzables: %s" % [name, miss.size(), all.size(), ", ".join(miss.slice(0, 4).map(func(c): return "%s '%s' @%s" % [c.get_class(), c.get("text") if c is Button else c.name, c.get_global_rect()]))])
	return 1


func _ready() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.6)
	var fails := 0
	fails += check("title", main)
	Nav.select()
	await wait(0.8)
	fails += check("select", main.screen)
	for b in main.screen._avatars.values():
		print("  avatar ", b.get_global_rect(), " L=", b.find_valid_focus_neighbor(SIDE_LEFT), " R=", b.find_valid_focus_neighbor(SIDE_RIGHT))
	var G := Eng.new_run("zafiro", {"seed": 42})
	Meta.run = G
	G.gold = 400
	G.map = RunGen.gen_map_game(G)
	Nav.map()
	await wait(1.0)
	fails += check("map", main.screen)
	# diálogos
	get_viewport().gui_release_focus()
	Dlg.options()
	await wait(0.6)
	fails += check("options", Main.I.overlay_host)
	Main.I.overlay_host.get_child(0).close(null)
	await wait(0.3)
	get_viewport().gui_release_focus()
	Dlg.pause_menu()
	await wait(0.6)
	var dl := []
	focusables(Main.I.overlay_host, dl)
	for c in dl:
		print("  ", c.get("text"), " ", c.get_global_rect(), " D=", (c.find_valid_focus_neighbor(SIDE_BOTTOM) as Control).get("text") if c.find_valid_focus_neighbor(SIDE_BOTTOM) else "-")
	fails += check("pausa", Main.I.overlay_host)
	Main.I.overlay_host.get_child(0).close(null)
	await wait(0.3)
	get_viewport().gui_release_focus()
	Dlg.help()
	await wait(0.6)
	fails += check("ayuda", Main.I.overlay_host)
	Main.I.overlay_host.get_child(0).close(null)
	await wait(0.3)
	get_viewport().gui_release_focus()
	Dlg.view_cards("Mazo", G.deck)
	await wait(0.6)
	fails += check("mazo", Main.I.overlay_host)
	Main.I.overlay_host.get_child(0).close(null)
	await wait(0.3)
	get_viewport().gui_release_focus()
	Nav.shop()
	await wait(1.0)
	fails += check("shop", main.screen)
	Nav.rest()
	await wait(1.0)
	fails += check("rest", main.screen)
	Nav.event()
	await wait(1.0)
	fails += check("event", main.screen)
	Nav.reward(Eng.combat_reward(G, "elite"), "elite")
	await wait(1.0)
	fails += check("reward", main.screen)
	Nav.favor()
	await wait(1.0)
	fails += check("favor", main.screen)
	Nav.history()
	await wait(1.0)
	fails += check("history", main.screen)
	Nav.gallery()
	await wait(1.0)
	fails += check("gallery", main.screen)
	print("RESULTADO: ", "OK" if fails == 0 else "%d pantallas con fallos" % fails)
	get_tree().quit()
