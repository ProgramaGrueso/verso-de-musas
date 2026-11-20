class_name TitleScreen
extends Control
## Menú principal.

const COL_W := 500.0   # ancho de la columna del menú (logo, subtítulo y botones comparten eje)
const FIT_MARGIN := 6.0  # aire mínimo arriba y abajo de la columna cuando no cabe holgada

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
	# columna del menú: ancho fijo y alto = pantalla; si el contenido no cabe, la fuente del logo se encoge
	var col := VBoxContainer.new()
	col.name = "Menu"
	col.position = Vector2(70, 0)
	col.size = Vector2(COL_W, 720)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 8 if compact else 16)
	add_child(col)
	var logo_fs := (68 if save else 74) if compact else 86
	var logo := UIK.label("VERSO\nDE MUSAS", logo_fs, UIK.GOLD, "title")   # noloc: marca (logo), igual en todos los idiomas
	logo.add_theme_constant_override("line_spacing", -14)
	logo.add_theme_color_override("font_shadow_color", Color(glow, 0.8))
	logo.add_theme_constant_override("shadow_offset_x", 0)
	logo.add_theme_constant_override("shadow_offset_y", 5)
	UIK.outlined(logo, 8, Color(0.1, 0.05, 0.0))
	logo.set_meta("logo", true)
	col.add_child(logo)
	var sub := UIK.label(tr("MUSAS MÁGICAS DEL VERSO"), 19, Color.WHITE, "bold")
	UIK.outlined(sub, 5)
	col.add_child(sub)
	var menu := VBoxContainer.new()
	menu.add_theme_constant_override("separation", (4 if save else 6) if compact else 10)
	menu.custom_minimum_size = Vector2(COL_W, 0)
	col.add_child(menu)
	var add := func(t: String, kind: String, fn: Callable) -> Button:
		var b := UIK.button(t, kind, 19 if compact else 22)
		if compact and kind.contains("big"):
			b.add_theme_font_size_override("font_size", UIK.ts(26))
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
		first = add.call(tr("Continuar"), "big green", func():
			var g = Meta.load_run()
			if g != null:
				Meta.run = g
				Nav.map()
			else:
				Main.I.toast(tr("No se pudo cargar la partida.")))
	var nueva: Button = add.call(tr("Nueva partida"), "" if save else "big", func(): Nav.select())
	if first == null:
		first = nueva
	var dkey := Daily.key_today()
	var dres := Meta.daily_result(dkey)
	var stk := Meta.daily_streak()
	add.call(tr("Reto diario") + ("  ✔" if dres.get("win", false) else "") + (("  · " + tr("racha %d") % stk.cur) if stk.cur > 1 else ""), "", func(): Nav.daily())
	add.call(tr("Logros  %d/%d") % [Progress.ach_count(Meta.data), Progress.achievements().size()], "", func(): Nav.achievements())
	add.call(tr("Historial"), "", func(): Nav.history())
	add.call(tr("Galería  %d/%d") % [Meta.data.gal.size(), DB.lore.size()], "", func(): Nav.gallery())
	add.call(tr("Cómo jugar"), "", func(): Dlg.help())
	add.call(tr("Opciones"), "", func(): Dlg.options())
	add.call(tr("Salir"), "", func(): get_tree().quit())
	var cred_bottom := 690.0   # pie de la firma de la musa (sube si hay aviso de Pesadilla debajo)
	if Meta.nm_unlocked(ch) > 0:
		cred_bottom = 662.0
		var nml := UIK.label(tr("Modo Pesadilla disponible (hasta nivel %d con %s)") % [Meta.nm_unlocked(ch), m.name], 16, Color("#caa5ff"), "bold")
		nml.position = Vector2(COL_W + 86, 666)   # a la derecha del menú: deja libre la fila de abajo
		add_child(nml)
	var cred := VBoxContainer.new()
	cred.position = Vector2(770, 600)
	cred.size = Vector2(480, 84)
	var nm := UIK.label(m.name, 34, Color.WHITE, "bold", HORIZONTAL_ALIGNMENT_RIGHT)
	UIK.outlined(nm, 6)
	var rl := UIK.label(m.role, 18, UIK.GOLD, "sans", HORIZONTAL_ALIGNMENT_RIGHT)
	UIK.outlined(rl, 4)
	cred.add_child(nm)
	cred.add_child(rl)
	add_child(cred)
	# la firma se apoya en `cred_bottom` y crece hacia arriba: al 130 % el rol caía sobre el aviso de Pesadilla
	var place_cred := func():
		cred.size = Vector2(480, 0)
		cred.position.y = cred_bottom - cred.get_combined_minimum_size().y
	cred.minimum_size_changed.connect(place_cred)
	place_cred.call_deferred()
	var names := []
	for c in chars:
		names.append(DB.characters[c].name)
	var foot := UIK.label(" · ".join(names), 14, UIK.DIM)
	foot.position = Vector2(COL_W + 86, 694)
	foot.size = Vector2(540, 22)
	foot.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(foot)
	_fit_column.call_deferred()
	Sfx.music("menu", 1, ch)
	first.grab_focus.call_deferred()
	UIK.fade_in(self, 0.4)


## Con muchas opciones (partida guardada, pesadilla, racha…) o con el texto al 115/130 % el menú puede pasar
## de 720 px. Cede primero el logo (hasta 40), luego el aire entre botones y por último su relleno vertical,
## para que nunca se salga ni empuje «Salir» fuera de la pantalla. Se compara con 720 fijo: la columna ya ha
## crecido a su mínimo cuando esto corre, así que `col.size.y` no sirve de tope.
func _fit_column() -> void:
	var col: VBoxContainer = get_node_or_null("Menu") as VBoxContainer
	if col == null:
		return
	var room := 720.0 - 2.0 * FIT_MARGIN
	var logo: Label = null
	var menu: VBoxContainer = null
	for c in col.get_children():
		if c is Label and c.has_meta("logo"):
			logo = c
		elif c is VBoxContainer:
			menu = c
	var too_tall := func() -> bool:
		col.update_minimum_size()
		return col.get_combined_minimum_size().y > room
	if logo != null:
		var fs := int(logo.get_theme_font_size("font_size"))
		while fs > 40 and too_tall.call():
			fs -= 2
			logo.add_theme_font_size_override("font_size", fs)
	if menu != null and too_tall.call():
		menu.add_theme_constant_override("separation", 2)
		col.add_theme_constant_override("separation", 4)
	if menu != null:
		var pad := 7
		while pad >= 2 and too_tall.call():
			for b in menu.get_children():
				for st in ["normal", "hover", "pressed", "disabled", "focus"]:
					var sb := (b as Button).get_theme_stylebox(st) as StyleBoxFlat
					if sb != null:
						sb.content_margin_top = pad
						sb.content_margin_bottom = pad
				(b as Button).update_minimum_size()
			pad -= 1
	col.size = Vector2(COL_W, 720)   # vuelve a su alto de diseño (si creció, encoge a lo que pide)
	col.position.y = 0.0


## Reto diario: confirma y arranca el de ese día (el calendario está en DailyScreen).
func _daily(key: String) -> void:
	DailyScreen.start(key)
