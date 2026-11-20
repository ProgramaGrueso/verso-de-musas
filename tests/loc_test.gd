extends Node
## Localización de la interfaz (Fase 5): falla si translations/ui_en.po tiene un texto sin traducir o con
## marcadores (%d, %s, {d}…) distintos, si el código usa un tr() que no está en el .po (tools/extract_loc.py
## --check), si el TranslationServer no devuelve lo del .po, o si el cambio de idioma en caliente
## (Opciones ▸ Idioma) no rehace el panel, la portada y la barra superior.
## Guarda y restaura user://settings.json.
## Uso: godot --headless --path . res://tests/loc_test.tscn

const PO := "res://translations/ui_en.po"
const SETTINGS := "user://settings.json"
var ok := 0
var fail := 0
var _backup := {}
var _ph_re := RegEx.create_from_string("%(?:\\d+\\$)?[-+ 0#]*\\d*(?:\\.\\d+)?[sdifxXc%]|\\{[A-Za-z_0-9]+\\}")


func wait(s: float) -> void:
	await get_tree().create_timer(s).timeout


func check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		print("ok   ", label)
	else:
		fail += 1
		print("FALLA ", label)


# ---------- lectura del .po ----------
func _unq(s: String) -> String:
	s = s.strip_edges()
	if s.begins_with("\"") and s.ends_with("\"") and s.length() >= 2:
		s = s.substr(1, s.length() - 2)
	return s.c_unescape()


## [{ctx, id, plural, str: [..]}] (sin la cabecera ni las entradas obsoletas «#~»).
func parse_po(path: String) -> Array:
	var out := []
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return out
	var cur := {}
	var field := ""
	for raw in f.get_as_text().split("\n"):
		var ln := raw.strip_edges()
		if ln == "" or ln.begins_with("#"):
			if ln == "" and cur.has("id"):
				out.append(cur)
				cur = {}
			continue
		if ln.begins_with("\""):
			var v := _unq(ln)
			if field.begins_with("str"):
				cur.str[int(field.substr(3))] += v
			else:
				cur[field] += v
			continue
		var sp := ln.find(" ")
		var kw := ln.substr(0, sp)
		var val := _unq(ln.substr(sp + 1))
		if kw == "msgctxt":
			if cur.has("id"):
				out.append(cur)
			cur = {"ctx": val}
			field = "ctx"
		elif kw == "msgid":
			if cur.has("id"):
				out.append(cur)
				cur = {}
			cur["id"] = val
			cur["str"] = ["", ""]
			field = "id"
		elif kw == "msgid_plural":
			cur["plural"] = val
			field = "plural"
		elif kw == "msgstr":
			cur.str[0] = val
			field = "str0"
		elif kw.begins_with("msgstr["):
			var i := int(kw.substr(7, kw.length() - 8))
			cur.str[i] = val
			field = "str%d" % i
	if cur.has("id"):
		out.append(cur)
	return out.filter(func(e): return e.id != "")


func placeholders(t: String) -> Array:
	var a := []
	for m in _ph_re.search_all(t):
		var p := m.get_string()
		if p != "%%":
			a.append(p.to_lower() if p.begins_with("{") else p)
	a.sort()
	return a


func test_po() -> Array:
	var es := parse_po(PO)
	check(es.size() > 300, "ui_en.po tiene textos (%d)" % es.size())
	var missing := []
	var bad := []
	for e in es:
		var pl: bool = e.has("plural")
		var need := 2 if pl else 1
		for i in need:
			if e.str[i] == "":
				missing.append(e.id)
		if e.str[0] == "":
			continue
		var want := placeholders(e.plural if pl else e.id)
		var last: String = e.str[1] if pl else e.str[0]
		if placeholders(last) != want:
			bad.append("%s -> %s" % [e.id, last])
		# el singular puede omitir el número («One card»), pero no inventar marcadores
		if pl:
			for p in placeholders(e.str[0]):
				if not p in want:
					bad.append("%s -> %s" % [e.id, e.str[0]])
	for m in missing.slice(0, 20):
		print("  SIN TRADUCIR: ", m.replace("\n", "\\n"))
	for b in bad.slice(0, 20):
		print("  MARCADORES: ", b.replace("\n", "\\n"))
	check(missing.is_empty(), "ningún texto sin traducir en ui_en.po (%d)" % missing.size())
	check(bad.is_empty(), "marcadores iguales en ui_en.po (%d distintos)" % bad.size())
	return es


## El código y el .po coinciden: un tr() nuevo sin regenerar ui_en.po haría fallar esto.
func test_extractor() -> void:
	var out := []
	var tool := ProjectSettings.globalize_path("res://tools/extract_loc.py")
	var rc := OS.execute("python3", [tool, "--check"], out, true)
	if rc == -1 or (out.size() > 0 and str(out[0]).contains("No such file")):
		print("aviso: python3 no disponible; se omite extract_loc.py --check")
		return
	var txt := "".join(out)
	for ln in txt.split("\n"):
		if ln.strip_edges() != "":
			print("  ", ln)
	check(rc == 0, "tools/extract_loc.py --check: el código no tiene textos fuera del .po ni sin traducir")


func test_server(entries: Array) -> void:
	var want := Loc.forced_lang() if Loc.forced_lang() != "" else "es"
	check(Loc.lang() == want, "arranca en «%s» (español desde el editor/tests salvo VDM_LANG / --lang)" % want)
	if want != "es":
		Loc.set_lang("es", {})   # el resto del test parte del español
	var s := {}
	Loc.set_lang("en", s)
	check(s.get("language") == "en" and TranslationServer.get_locale().begins_with("en"), "set_lang(en) fija el locale y lo apunta en ajustes")
	var wrong := []
	for e in entries:
		var ctx: String = e.get("ctx", "")
		if e.has("plural"):
			if Loc.tn(e.id, e.plural, 1, ctx) != e.str[0] or Loc.tn(e.id, e.plural, 3, ctx) != e.str[1]:
				wrong.append(e.id)
		elif Loc.t(e.id, ctx) != e.str[0]:
			wrong.append("%s (da «%s», el .po dice «%s»)" % [e.id, Loc.t(e.id, ctx), e.str[0]])
	for w in wrong.slice(0, 10):
		print("  NO CARGA: ", w.replace("\n", "\\n"))
	check(wrong.is_empty(), "el TranslationServer devuelve lo del .po para cada texto (%d mal)" % wrong.size())
	check(Loc.t("Idioma") == "Language", "en: Idioma -> Language")
	check(Loc.tn("Racha: %d día", "Racha: %d días", 3) % 3 == "Streak: 3 days", "en: plural Racha 3")
	check(Loc.tn("Racha: %d día", "Racha: %d días", 1) % 1 == "Streak: 1 day", "en: singular Racha 1")
	check(tr("Continuar") == "Continue", "en: tr() de instancia también traduce (auto_translate apagado)")
	Loc.set_lang("es", s)
	check(Loc.t("Idioma") == "Idioma" and tr("Continuar") == "Continuar", "es: devuelve el texto fuente")
	check(Loc.tn("Racha: %d día", "Racha: %d días", 3) % 3 == "Racha: 3 días", "es: plural Racha 3")
	Loc.set_lang("xx", s)
	check(Loc.lang() == "es", "idioma desconocido: no cambia")


func texts(n: Node) -> String:
	var s := ""
	if n is Label:
		s += (n as Label).text + "\n"
	elif n is RichTextLabel:
		s += (n as RichTextLabel).get_parsed_text() + "\n"
	elif n is Button:
		s += (n as Button).text + "\n"
	for c in n.get_children():
		s += texts(c)
	return s


func top_overlay() -> Node:
	var h: Node = Main.I.overlay_host
	return h.get_child(h.get_child_count() - 1) if h.get_child_count() > 0 else null


func _press(o: Node, name: String) -> bool:
	var b := o.find_child(name, true, false) as Button
	if b == null:
		return false
	b.pressed.emit()
	return true


func _close_top() -> void:
	var o := top_overlay()
	if o is Dlg.Overlay:
		o.close(null)
	await wait(0.4)


## Cambio en caliente desde Opciones, sin reiniciar: panel, portada y barra superior.
func test_hot_switch() -> void:
	var main: Control = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	await wait(0.5)
	Nav.title()
	await wait(0.5)
	check(texts(Main.I.screen).contains("Nueva partida"), "portada en español")
	Dlg.options()
	await wait(0.4)
	var o := top_overlay()
	check(o != null and _press(o, "Lang_en"), "Opciones tiene el botón English")
	await wait(0.3)
	check(Loc.lang() == "en" and Meta.settings.get("language") == "en", "Opciones ▸ English cambia el idioma y lo guarda")
	var ot := texts(top_overlay())
	check(ot.contains("Language") and ot.contains("Options") and not ot.contains("Idioma"), "el panel de Opciones se rehace en inglés al momento")
	await _close_top()
	var tt := texts(Main.I.screen)
	check(tt.contains("New run") and not tt.contains("Nueva partida"), "al cerrar Opciones la portada está en inglés")
	Nav.map()
	await wait(0.5)
	check(texts(Main.I.screen).contains("Start of the climb"), "el mapa se construye en inglés")
	Dlg.options()
	await wait(0.4)
	check(_press(top_overlay(), "Lang_es"), "Opciones tiene el botón Español")
	await wait(0.3)
	await _close_top()
	check(Loc.lang() == "es" and texts(Main.I.screen).contains("Inicio del ascenso"), "vuelta a español: el mapa se rehace")
	main.queue_free()
	await wait(0.2)


func _ready() -> void:
	for p in [SETTINGS, SETTINGS + ".bak"]:
		_backup[p] = FileAccess.get_file_as_bytes(p) if FileAccess.file_exists(p) else null
	Meta.settings.music = 0.0
	Meta.settings.sfx = 0.0
	var entries := test_po()
	test_extractor()
	test_server(entries)
	var G := Eng.new_run("zafiro", {"seed": 42})
	G.map = RunGen.gen_map_game(G)
	Meta.run = G
	await test_hot_switch()
	Meta.run = null
	Loc.set_lang("es", Meta.settings)
	for p in _backup:
		if _backup[p] == null:
			if FileAccess.file_exists(p):
				DirAccess.remove_absolute(ProjectSettings.globalize_path(p))
		else:
			var f := FileAccess.open(p, FileAccess.WRITE)
			f.store_buffer(_backup[p])
			f.close()
	print("RESULTADO: %d ok, %d fallan" % [ok, fail])
	get_tree().quit(1 if fail > 0 else 0)
