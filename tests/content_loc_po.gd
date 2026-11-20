extends RefCounted
## Lector mínimo de .po para los tests de localización (no depende de que Godot haya importado el .po).
## Soporta msgid/msgstr, msgid_plural/msgstr[n], cadenas en varias líneas y escapes \n \t \" \\.
## Uso: var t: Translation = load("res://tests/content_loc_po.gd").parse_file("res://translations/x.po", "en")


static func _unq(s: String) -> String:
	s = s.strip_edges()
	if s.length() >= 2 and s.begins_with("\"") and s.ends_with("\""):
		s = s.substr(1, s.length() - 2)
	return s.c_unescape()


## Devuelve [{id, plural, str: [..], fuzzy}] (sin la cabecera).
static func entries(path: String) -> Array:
	var out := []
	var cur := {}
	var field := ""
	var fuzzy := false
	for raw in FileAccess.get_file_as_string(path).split("\n"):
		var l := raw.strip_edges()
		if l.begins_with("#,") and "fuzzy" in l:
			fuzzy = true
			continue
		if l == "" or l.begins_with("#"):
			continue
		if l.begins_with("msgid_plural "):
			cur["plural"] = _unq(l.substr(13))
			field = "plural"
		elif l.begins_with("msgid "):
			if cur.has("id"):
				out.append(cur)
			cur = {"id": _unq(l.substr(6)), "plural": "", "str": [], "fuzzy": fuzzy}
			fuzzy = false
			field = "id"
		elif l.begins_with("msgstr["):
			var i := int(l.substr(7, l.find("]") - 7))
			while cur.str.size() <= i:
				cur.str.append("")
			cur.str[i] = _unq(l.substr(l.find("]") + 1))
			field = "str%d" % i
		elif l.begins_with("msgstr "):
			cur.str = [_unq(l.substr(7))]
			field = "str0"
		elif l.begins_with("\""):
			var v := _unq(l)
			if field == "id":
				cur.id += v
			elif field == "plural":
				cur.plural += v
			elif field.begins_with("str"):
				var i := int(field.substr(3))
				cur.str[i] += v
	if cur.has("id"):
		out.append(cur)
	return out.filter(func(e): return e.id != "")


static func parse_file(path: String, locale: String) -> Translation:
	var t := Translation.new()
	t.locale = locale
	for e in entries(path):
		if e.fuzzy or e.str.is_empty() or e.str[0] == "":
			continue
		if e.plural != "":
			t.add_plural_message(e.id, PackedStringArray(e.str))
		else:
			t.add_message(e.id, e.str[0])
	return t
