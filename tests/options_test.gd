extends Node
## Opciones: tamaño del texto (100/115/130 %) y remapeo de teclas (Opciones ▸ Controles).
## Guarda y restaura user://settings.json (el test cambia ajustes y Meta los escribe).
## Uso: godot --headless --path . res://tests/options_test.tscn

const SETTINGS := "user://settings.json"
var ok := 0
var fail := 0
var _backup := {}


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		print("ok   ", label)
	else:
		fail += 1
		print("FALLA ", label)


func key(k: int) -> void:
	for p in [true, false]:
		var e := InputEventKey.new()
		e.keycode = k
		e.physical_keycode = k
		e.pressed = p
		Input.parse_input_event(e)
		await wait(0.1)


func overlays() -> int:
	return Main.I.overlay_host.get_child_count()


func top_overlay() -> Node:
	return Main.I.overlay_host.get_child(overlays() - 1) if overlays() > 0 else null


func close_all() -> void:
	for i in range(overlays() - 1, -1, -1):
		var o = Main.I.overlay_host.get_child(i)
		if o is Dlg.Overlay:
			o.close(null)
	await wait(0.3)


func texts(n: Node) -> String:
	var s := ""
	if n is Label:
		s += (n as Label).text + "\n"
	elif n is RichTextLabel:
		s += (n as RichTextLabel).get_parsed_text() + "\n"
	for c in n.get_children():
		s += texts(c)
	return s


func _save_files() -> void:
	for p in [SETTINGS, SETTINGS + ".bak"]:
		_backup[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null


func _restore_files() -> void:
	for p in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_backup[p])
			f.close()


func _ready() -> void:
	_save_files()
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	Meta.settings.text_scale = 1.0
	Meta.settings.keys = {}
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	var G := Eng.new_run("zafiro", {"seed": 42})
	G.map = RunGen.gen_map_game(G)
	Meta.run = G
	await test_scale()
	await test_remap()
	await test_controls_dialog()
	await test_combat_key()
	Main.reset_keys()
	Meta.settings.text_scale = 1.0
	UIK.text_scale = 1.0
	_restore_files()
	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)


# ---------- tamaño del texto ----------
func test_scale() -> void:
	Nav.map()
	await wait(0.6)
	check(UIK.ts(20) == 20, "escala 1.0: el tamaño no cambia")
	Dlg.options()
	await wait(0.4)
	var o := top_overlay()
	var s2: Button = o.find_child("Scale_2", true, false)
	check(s2 != null and o.find_child("Controls", true, false) != null, "opciones: filas «Tamaño del texto» y «Controles»")
	if s2 == null:
		return
	var old_close: Control = o.find_child("Cerrar", true, false)
	s2.emit_signal("pressed")
	await wait(0.4)
	check(is_equal_approx(UIK.text_scale, 1.3) and is_equal_approx(float(Meta.settings.text_scale), 1.3), "130 %: se guarda en Meta.settings y en UIK")
	check(UIK.ts(20) == 26 and UIK.label("x", 20).get_theme_font_size("font_size") == 26, "130 %: una etiqueta de 20 sale a 26")
	check(not is_instance_valid(old_close) or old_close.is_queued_for_deletion(), "130 %: el diálogo se rehace con el texto nuevo")
	var f := get_viewport().gui_get_focus_owner()
	check(f != null and f.name == "Scale_2", "130 %%: el foco se queda en el botón elegido (%s)" % (f.name if f != null else "<sin foco>"))
	var panel: Control = o.find_child("Scale_2", true, false)
	while panel != null and not (panel is PanelContainer):
		panel = panel.get_parent()
	var vr := Rect2(Vector2.ZERO, Vector2(1280, 720))
	check(panel != null and vr.encloses(panel.get_global_rect()), "130 %%: Opciones cabe en 1280×720 (%s)" % (panel.get_global_rect() if panel else "?"))
	# la ayuda (texto más largo) a 130 % tampoco se sale
	Dlg.help()
	await wait(0.5)
	var h := top_overlay()
	var hp: Control = null
	for n in h.find_children("*", "PanelContainer", true, false):
		hp = n
		break
	check(hp != null and vr.encloses(hp.get_global_rect()), "130 %%: la ayuda cabe en pantalla (%s)" % (hp.get_global_rect() if hp else "?"))
	h.close(null)
	await wait(0.3)
	var s0: Button = top_overlay().find_child("Scale_0", true, false)
	s0.emit_signal("pressed")
	await wait(0.3)
	check(is_equal_approx(UIK.text_scale, 1.0) and UIK.ts(20) == 20, "100 %: vuelve al tamaño normal")
	await close_all()


# ---------- remapeo: la tecla nueva hace la acción y la vieja ya no ----------
func test_remap() -> void:
	Nav.map()
	await wait(0.5)
	check(Main.set_key("ver_mazo", KEY_V) == "" and Main.key_of("ver_mazo") == KEY_V, "remapeo: ver_mazo → V")
	await key(KEY_V)
	await wait(0.3)
	check(Main.I._deck_overlay() != null, "remapeo: V abre el mazo en el mapa")
	await close_all()
	await key(KEY_M)
	await wait(0.3)
	check(overlays() == 0, "remapeo: M (ya libre) no abre nada")
	# intercambio: ayuda pasa a V y ver_mazo se queda con la H de ayuda
	check(Main.set_key("ayuda", KEY_V) == "" and Main.key_of("ver_mazo") == KEY_H and Main.key_of("ayuda") == KEY_V,
		"remapeo: asignar una tecla ocupada intercambia (ver_mazo=%s, ayuda=%s)" % [Main.key_name("ver_mazo"), Main.key_name("ayuda")])
	await key(KEY_H)
	await wait(0.3)
	check(Main.I._deck_overlay() != null, "intercambio: H abre el mazo")
	await close_all()
	await key(KEY_V)
	await wait(0.4)
	var t := texts(top_overlay()) if overlays() > 0 else ""
	check(t.contains(tr("Cómo jugar")), "intercambio: V abre la ayuda")
	check((t.contains("V o F1: esta ayuda") or t.contains("V or F1: this help")) and (t.contains("H: ver tu mazo") or t.contains("H: view your deck")) and not t.contains("{"), "ayuda: muestra las teclas asignadas")
	await close_all()
	check(Main.set_key("robo", KEY_1) != "" and Main.key_of("robo") == KEY_D, "reservadas: 1 no se puede asignar")
	check(Main.set_key("robo", KEY_ESCAPE) != "" and Main.key_of("robo") == KEY_D, "reservadas: Esc no se puede asignar")
	# escribiendo en un campo de texto las letras no se traducen
	var le := LineEdit.new()
	Main.I.screen.add_child(le)
	le.grab_focus()
	await wait(0.1)
	var ev := InputEventKey.new()
	ev.keycode = KEY_V
	ev.pressed = true
	check(not Main.I._remap_key(ev), "campo de texto con foco: V se escribe (no se traduce)")
	le.queue_free()
	await wait(0.1)
	var s: Dictionary = Meta.settings.get("keys", {})
	check(s.size() == 2 and int(s.ver_mazo) == KEY_H and int(s.ayuda) == KEY_V, "ajustes: solo se guardan las teclas cambiadas %s" % str(s))
	Main.reset_keys()
	check(Main.key_of("ver_mazo") == KEY_M and Main.I._key_tr.is_empty(), "restablecer: vuelven las de defecto")


# ---------- Opciones ▸ Controles: capturar la tecla ----------
func test_controls_dialog() -> void:
	Dlg.controls()
	await wait(0.4)
	var o := top_overlay()
	check(o != null and o.has_meta("controls"), "controles: el diálogo se abre")
	var f := get_viewport().gui_get_focus_owner()
	check(f != null and f.name == "Key_ver_mazo", "controles: foco en la primera acción")
	var b: Button = o.find_child("Key_terminar_turno", true, false)
	check(b != null and b.text == "E", "controles: Terminar turno muestra E")
	b.emit_signal("pressed")
	await wait(0.1)
	await key(KEY_G)
	await wait(0.2)
	check(Main.key_of("terminar_turno") == KEY_G and b.text == "G", "controles: se captura G para Terminar turno")
	b.emit_signal("pressed")
	await wait(0.1)
	await key(KEY_ESCAPE)
	await wait(0.2)
	check(Main.key_of("terminar_turno") == KEY_G and is_instance_valid(o) and not o.is_queued_for_deletion(), "controles: Esc cancela la captura sin cerrar el diálogo")
	b.emit_signal("pressed")
	await wait(0.1)
	await key(KEY_2)
	await wait(0.2)
	var msg: Label = o.find_child("Msg", true, false)
	check(Main.key_of("terminar_turno") == KEY_G and (msg.text.contains("reservada") or msg.text.contains("reserved")), "controles: una tecla reservada se rechaza con aviso")
	o.close(null)
	await wait(0.3)
	check(overlays() == 0, "controles: se cierra")


# ---------- combate: la tecla elegida termina el turno ----------
func test_combat_key() -> void:
	# terminar_turno sigue en G (del test anterior)
	Meta.run.hp = Meta.run.maxHp
	Nav.combat(["dockrat"], "normal")
	await wait(2.0)
	var cs = Main.I.screen
	check(Main.I.current == "combat", "combate: abierto")
	var t0: int = cs.C.turn
	await key(KEY_E)
	await wait(0.5)
	check(cs.C.turn == t0 and not cs.busy, "combate: E (ya libre) no termina el turno")
	await key(KEY_G)
	await wait(0.3)
	check(cs.busy or cs.C.turn != t0, "combate: G termina el turno")
	await wait(2.5)
