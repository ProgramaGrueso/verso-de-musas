class_name TitleScreen
extends Control
## Menú principal.

static var last_char := ""


func _ready() -> void:
	var chars := DB.playable()
	var ch: String = chars[randi() % chars.size()]
	if ch == last_char:
		ch = chars[(chars.find(ch) + 1 + randi() % (chars.size() - 1)) % chars.size()]
	last_char = ch
	var m: Dictionary = DB.characters[ch]
	var glow := Color(m.glow)
	var bg := TextureRect.new()
	bg.texture = UIK.tex("res://assets/ui/%s_select.webp" % ch)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.size = Vector2(1280, 720) * 1.06
	bg.position = Vector2(-38, -22)
	bg.pivot_offset = bg.size / 2
	add_child(bg)
	var tw := bg.create_tween().set_loops()
	tw.tween_property(bg, "position", Vector2(-10, -10), 14.0).set_trans(Tween.TRANS_SINE)
	tw.tween_property(bg, "position", Vector2(-38, -22), 14.0).set_trans(Tween.TRANS_SINE)
	var sh := TextureRect.new()
	sh.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0.92)], [0.34, Color(0, 0, 0, 0.66)], [0.62, Color(0, 0, 0, 0)]], true)
	sh.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sh.stretch_mode = TextureRect.STRETCH_SCALE
	UIK.full_rect(sh)
	add_child(sh)
	add_child(UIK.shade(0.0, 0.0))
	var sh2 := UIK.shade(0.0, 0.0)
	sh2.texture = UIK.grad_tex([[0.0, Color(0, 0, 0, 0)], [0.6, Color(0, 0, 0, 0)], [1.0, Color(0, 0, 0, 0.8)]])
	add_child(sh2)
	add_child(UIK.embers(glow))
	var save := Meta.has_save()
	var compact := true   # con Reto diario e Historial el menú siempre va compacto para caber en 720 px
	var col := VBoxContainer.new()
	col.position = Vector2(70, 0)
	col.size = Vector2(460, 720)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8 if compact else 16)
	add_child(col)
	var logo := UIK.label("VERSO\nDE MUSAS", (68 if save else 74) if compact else 86, UIK.GOLD, "title")
	logo.add_theme_constant_override("line_spacing", -14)
	logo.add_theme_color_override("font_shadow_color", Color(glow, 0.8))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 5)
	UIK.outlined(logo, 8, Color(0.1, 0.05, 0.0))
	col.add_child(logo)
	var sub := UIK.label("MUSAS MÁGICAS DEL VERSO", 19, Color.WHITE, "bold")
	UIK.outlined(sub, 5)
	col.add_child(sub)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", (4 if save else 6) if compact else 10)
	menu.custom_minimum_size = Vector2(380, 0)
	col.add_child(menu)
	var add := func(t: String, kind: String, fn: Callable) -> Button:
		var b := UIK.button(t, kind, 19 if compact else 22)
		if compact and kind.contains("big"):
			b.add_theme_font_size_override("font_size", 26)
		if compact:
			for st in ["normal", "hover", "pressed", "disabled", "focus"]:
				var sb := b.get_theme_stylebox(st) as StyleBoxFlat
				if sb != null:
					sb.content_margin_top = 8
					sb.content_margin_bottom = 8
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(fn)
		menu.add_child(b)
		return b
	var first: Button = null
	if save:
		first = add.call("Continuar", "big green", func():
			var g = Meta.load_run()
			if g != null:
				Meta.run = g
				Nav.map()
			else:
				Main.I.toast("No se pudo cargar la partida."))
	var nueva: Button = add.call("Nueva partida", "" if save else "big", func(): Nav.select())
	if first == null:
		first = nueva
	var dkey := Daily.key_today()
	var dres := Meta.daily_result(dkey)
	add.call("Reto diario" + ("  ✔" if dres.get("win", false) else ""), "", func(): _daily(dkey))
	add.call("Historial", "", func(): Nav.history())
	add.call("Galería  %d/%d" % [Meta.data.gal.size(), DB.lore.size()], "", func(): Nav.gallery())
	add.call("Cómo jugar", "", func(): Dlg.help())
	add.call("Opciones", "", func(): Dlg.options())
	add.call("Salir", "", func(): get_tree().quit())
	if Meta.nm_unlocked(ch) > 0:
		var nml := UIK.label("Modo Pesadilla disponible (hasta nivel %d con %s)" % [Meta.nm_unlocked(ch), m.name], 16, Color("#caa5ff"), "bold")
		nml.position = Vector2(70, 664)
		add_child(nml)
	var cred := VBoxContainer.new()
	cred.position = Vector2(780, 610)
	cred.size = Vector2(470, 80)
	var nm := UIK.label(m.name, 34, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_RIGHT)
	UIK.outlined(nm, 6)
	var rl := UIK.label(m.role, 18, UIK.GOLD, "sans", HORIZONTAL_ALIGNMENT_RIGHT)
	UIK.outlined(rl, 4)
	cred.add_child(nm)
	cred.add_child(rl)
	add_child(cred)
	var names := []
	for c in chars:
		names.append(DB.characters[c].name)
	var foot := UIK.label(" · ".join(names), 14, UIK.DIM)
	foot.position = Vector2(70, 692)
	add_child(foot)
	Sfx.music("menu", 1, ch)
	first.grab_focus.call_deferred()
	UIK.fade_in(self, 0.4)


## Reto diario: misma musa, semilla y modificador para todo el mundo hoy.
func _daily(key: String) -> void:
	var inf := Daily.info(key)
	var m: Dictionary = DB.characters[inf.char]
	var res := Meta.daily_result(key)
	var t: String = "[b][color=#f0cf7a]Reto del %s[/color][/b]\n\nMusa: [b]%s[/b], %s\nModificador: [b][color=#caa5ff]%s[/color][/b] — %s\n[font_size=18]Mismos mapas y la misma semilla para todo el mundo. Sin Pesadilla ni modo fácil.[/font_size]" % [
		key, m.name, m.role, Daily.mod_name(inf.mod), Daily.mod_desc(inf.mod)]
	if not res.is_empty():
		t += "\n[font_size=18]Intentos: %d · %s[/font_size]" % [res.get("tries", 0), "¡ya lo has superado!" if res.get("win", false) else "mejor piso %d" % res.get("floor", 0)]
	if Meta.has_save():
		t += "\n[font_size=18][color=#ff7b85]Se perderá la partida guardada.[/color][/font_size]"
	if not await Dlg.confirm(t, "Empezar", "Ahora no"):
		return
	var G := Daily.new_run(key)
	Meta.run = G
	Meta.clear_save()
	Meta.daily_started(key, G.char)
	Nav.favor()
