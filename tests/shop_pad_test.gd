extends Node
## Regresión: comprar en la tienda con MANDO deja la pantalla navegable.
## Uso: godot --headless --path . res://tests/shop_pad_test.tscn
## Mide el foco real (gui_get_focus_owner) antes/después de cada compra y comprueba que el D-Pad,
## el stick y A/B siguen funcionando (navegar entre cartas y salir de la tienda).

var ok := 0
var fail := 0


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		print("ok   ", label)
	else:
		fail += 1
		print("FALLA ", label)


func btn(i: int, pressed: bool = true) -> void:
	var e := InputEventJoypadButton.new()
	e.button_index = i
	e.pressed = pressed
	e.device = 0
	Input.parse_input_event(e)
	await wait(0.12)


func tap(i: int) -> void:
	await btn(i, true)
	await btn(i, false)


func axis(a: int, v: float) -> void:
	var e := InputEventJoypadMotion.new()
	e.axis = a
	e.axis_value = v
	e.device = 0
	Input.parse_input_event(e)
	await wait(0.12)


func stick(a: int, dir: int) -> void:
	await axis(a, 1.0 * dir)
	await axis(a, 0.0)


func focus() -> Control:
	var f := get_viewport().gui_get_focus_owner()
	return f if (f != null and is_instance_valid(f)) else null


func fname(f: Control) -> String:
	if f == null:
		return "<sin foco>"
	var s := "%s(%s)" % [f.name, f.get_class()]
	if f is CardView:
		s += " uid=%s" % str((f as CardView).inst.get("uid", "?"))
	elif f is Button:
		s += " '%s'" % (f as Button).text
	return s


func in_shop(f: Control) -> bool:
	var sh := Main.I.screen
	return sh != null and f != null and is_instance_valid(sh) and sh.is_ancestor_of(f) and f.is_visible_in_tree()


func overlays() -> int:
	return Main.I.overlay_host.get_child_count()


func top_overlay() -> Node:
	return Main.I.overlay_host.get_child(overlays() - 1) if overlays() > 0 else null


func shop_cards() -> Array:
	var out := []
	for n in _walk(Main.I.screen):
		if n is CardView:
			out.append(n)
	return out


func _walk(n: Node) -> Array:
	var out := [n]
	for c in n.get_children():
		out.append_array(_walk(c))
	return out


func leave_btn() -> Button:
	for n in _walk(Main.I.screen):
		if n is Button and (n as Button).text.begins_with("Salir de la tienda"):
			return n
	return null


func first_buyable() -> CardView:
	for cv in shop_cards():
		var c := cv as CardView
		if c.is_queued_for_deletion() or not c.is_visible_in_tree():
			continue
		if c.focus_mode != Control.FOCUS_NONE:
			return c
	return null


## Llega al botón afirmativo del diálogo con el D-Pad (sin tocar el ratón ni adivinar su texto).
func confirm_yes() -> void:
	for i in 3:
		var f := focus() as Button
		if f != null and not f.disabled and not is_cancel_text(f.text):
			return
		await btn(JOY_BUTTON_DPAD_LEFT, true)
		await btn(JOY_BUTTON_DPAD_LEFT, false)


## Cuántos ms le quedan al aviso de Sfx que descarta los efectos de la pantalla anterior (0 = acepta ya).
func sfx_mute_ms() -> int:
	var s: Node = get_node_or_null("/root/Sfx")   # el autoload vivo, no una instancia nueva
	if s == null:
		return -1
	var left = s.get("_stop_until")
	if left == null:
		return -1
	return maxi(0, int(left) - Time.get_ticks_msec())


func is_cancel_text(t: String) -> bool:
	var s := t.to_lower()
	return s.contains("no") or s.contains("cancel") or s.contains("atrás") or s.contains("volver")


func _ready() -> void:
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var G := Eng.new_run("zafiro", {"seed": 42})
	G.gold = 999
	G.map = RunGen.gen_map_game(G)
	Meta.run = G
	Nav.shop()
	await wait(0.8)
	check(Main.I.current == "shop", "la tienda está abierta")
	var f0 := focus()
	print("foco inicial en la tienda: ", fname(f0))
	check(in_shop(f0), "al abrir, el foco está en un control de la tienda")
	# fotografía (por instance id) de los focos sanos de la tienda recién abierta
	var modes := {}
	for n in _walk(Main.I.screen):
		if n is Control:
			modes[n.get_instance_id()] = (n as Control).focus_mode

	# ---------- comprar 2 cartas seguidas SOLO con el mando: A sobre la carta, D-Pad hasta «Sí», A ----------
	for n in range(1, 3):
		var cv := first_buyable()
		check(cv != null, "compra %d: hay carta comprable con foco" % n)
		if cv == null:
			break
		cv.grab_focus()
		await wait(0.1)
		await tap(JOY_BUTTON_A)
		check(overlays() == 1, "compra %d: A abre el confirm" % n)
		var f := focus()
		print("  foco en el confirm: ", fname(f))
		check(f != null and f is Button, "compra %d: el confirm tiene foco en un botón" % n)
		await confirm_yes()
		var gold0: int = G.gold
		await tap(JOY_BUTTON_A)
		check(overlays() == 0, "compra %d: el confirm se cierra" % n)
		check(G.gold < gold0, "compra %d: se descontó el oro" % n)
		await wait(0.4)
		var fa := focus()
		print("  foco tras comprar: ", fname(fa))
		check(fa != null, "compra %d: hay foco tras comprar" % n)
		check(in_shop(fa), "compra %d: el foco sigue en la tienda" % n)
		var busted := 0
		for c in shop_cards():
			if not c.is_queued_for_deletion() and c.is_visible_in_tree() and c.focus_mode == Control.FOCUS_NONE:
				busted += 1
		check(busted <= n, "compra %d: queda lo vendido sin foco y el resto navegable (sin foco: %d de %d)" % [n, busted, shop_cards().size()])

	# ---------- D-Pad: moverse a la siguiente carta ----------
	var before := focus()
	await btn(JOY_BUTTON_DPAD_RIGHT, true)
	await wait(0.15)
	await btn(JOY_BUTTON_DPAD_RIGHT, false)
	await wait(0.2)
	var moved := focus()
	print("  D-Pad derecha: ", fname(before), " -> ", fname(moved))
	check(moved != null and moved != before and in_shop(moved), "el D-Pad mueve el foco por la tienda")

	# ---------- stick: abajo hasta «Salir de la tienda» ----------
	var reached := false
	for i in 8:
		await stick(JOY_AXIS_LEFT_Y, 1)
		await wait(0.08)
		var lb := leave_btn()
		if focus() != null and focus() == lb:
			reached = true
			break
	print("  stick abajo -> ", fname(focus()))
	check(reached, "el stick lleva el foco a «Salir de la tienda»")

	# ---------- A sobre «Salir» sale de la tienda ----------
	if reached:
		await tap(JOY_BUTTON_A)
		await wait(0.8)
		check(Main.I.current != "shop", "A en «Salir de la tienda» vuelve al mapa")
	else:
		var lb2 := leave_btn()
		if lb2 != null:
			lb2.grab_focus()
			await wait(0.15)
			await tap(JOY_BUTTON_A)
			await wait(0.8)
			check(Main.I.current != "shop", "A en «Salir de la tienda» vuelve al mapa")

	# ---------- B en la tienda también sale ----------
	await wait(0.3)
	Nav.shop()
	await wait(0.8)
	var f2 := focus()
	check(in_shop(f2), "al reabrir la tienda hay foco")
	await tap(JOY_BUTTON_B)
	await wait(0.8)
	check(Main.I.current != "shop", "B sale de la tienda")
	await wait(0.3)

	# ---------- modal anidado: Overlay dentro de Overlay restaura los focos de debajo ----------
	Nav.shop()
	await wait(0.8)
	var card_a := first_buyable()
	check(card_a != null, "modal anidado: hay carta con foco")
	if card_a != null:
		card_a.grab_focus()
		await wait(0.1)
		Dlg.pick_cards({"title": "Prueba", "cards": G.deck.duplicate(), "n": 1, "cancel": "Cancelar"})
		await wait(0.5)
		var inner := top_overlay()
		var f_inner := focus()
		check(inner != null and f_inner != null and inner.is_ancestor_of(f_inner), "modal anidado: foco dentro del diálogo interior")
		Dlg.confirm("¿doble?")   # el diálogo exterior espera a la vez
		await wait(0.5)
		check(overlays() == 2, "modal anidado: dos diálogos abiertos")
		await tap(JOY_BUTTON_B)
		await wait(0.5)
		check(overlays() == 1, "modal anidado: B cierra solo el de arriba")
		await tap(JOY_BUTTON_B)
		await wait(0.6)
		check(overlays() == 0, "modal anidado: B cierra también el interior")
		await wait(0.4)
		var fb := focus()
		print("  foco tras cerrar modales anidados: ", fname(fb))
		check(fb != null and in_shop(fb), "modal anidado: el foco vuelve a la tienda")
		# La "fotografía" es de cuando se abrió la tienda; se compara con la tienda actual. Lo comprado o
		# eliminado cambia a propósito, así que se admite que algún control ya no esté o haya cambiado.
		var now := {}
		for n in _walk(Main.I.screen):
			if n is Control:
				now[n.get_instance_id()] = (n as Control).focus_mode
		var same := 0
		var total := 0
		for id in modes:
			if now.has(id):
				total += 1
				if int(now[id]) == int(modes[id]):
					same += 1
		check(same >= total - 2 and same * 2 >= total, "modal anidado: los focos de la tienda siguen como al abrirla (%d iguales de %d vivos)" % [same, total])

	# ---------- cierre sin resultado (ESC/B): el foco se queda en el botón del modal ----------
	await wait(0.3)
	var card_b := first_buyable()
	check(card_b != null, "descarte: hay carta con foco en la tienda")
	if card_b != null:
		card_b.grab_focus()
		await wait(0.15)
		Dlg.message("Aviso de prueba", "Un mensaje que solo informa y se cierra con B.", "Entendido")
		await wait(0.5)
		var ov_msg := top_overlay()
		var btn_msg := focus()
		check(ov_msg != null and btn_msg is Button and ov_msg.is_ancestor_of(btn_msg), "descarte: el mensaje tiene el foco en su botón")
		await tap(JOY_BUTTON_B)
		await wait(0.5)
		check(overlays() == 0, "descarte: B cierra el mensaje")
		var fb2 := focus()
		print("  foco tras descartar con B: ", fname(fb2))
		check(fb2 != null and is_instance_valid(fb2) and fb2.is_visible_in_tree() and fb2.focus_mode != Control.FOCUS_NONE, "descarte: no se pierde el foco (queda en un control válido y visible)")
		# y la tienda sigue siendo navegable con el mando después del descarte
		var before2 := focus()
		await btn(JOY_BUTTON_DPAD_LEFT, true)
		await btn(JOY_BUTTON_DPAD_LEFT, false)
		await wait(0.2)
		var moved2 := focus()
		check(moved2 != null and in_shop(moved2), "descarte: la tienda sigue respondiendo al D-Pad")
		print("  D-Pad tras descarte: ", fname(before2), " -> ", fname(moved2))

	# ---------- el «chip» de sonido no se queda bloqueado tras cambiar de pantalla ----------
	# Main.set_screen avisa a Sfx para que no siga sonando la pantalla que se deja; ese aviso debe caducar.
	Nav.shop()
	var fell_at := -1
	for i in 40:
		await wait(0.05)
		if sfx_mute_ms() == 0:
			fell_at = int(round(i * 50.0))
			break
	print("  chip de sonido: Sfx vuelve a aceptar efectos %d ms después de cambiar de pantalla" % fell_at)
	check(fell_at >= 0 and fell_at <= 450, "chip de sonido: el aviso caduca (~320 ms) y los efectos vuelven a sonar (%d ms)" % fell_at)

	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)
