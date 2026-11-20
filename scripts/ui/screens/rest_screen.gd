class_name RestScreen
extends Control
## Hoguera: descansar o mejorar una carta.


func _ready() -> void:
	var G = Meta.run
	add_child(UIK.backdrop(G.act))
	add_child(UIK.shade(0.3, 0.6))
	Sfx.music("rest", G.act)
	var rp: float = Eng.nmods(G).rest
	var heal := ceili(G.maxHp * rp)
	var col := UIK.center_col(self, 16)
	var t := UIK.label("Hoguera", 48, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t, 10)
	col.add_child(t)
	var sub := UIK.label("Una pausa junto al fuego. Elige una opción:", 22, Color("#dddddd"), "sans", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(sub, 5)
	col.add_child(sub)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 24)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(row)
	var done := func():
		Main.I.update_top()
		Nav.node_done(false)
	var ref := {}
	# vida antes ➜ después (Fase 2.3): se ve qué deja el descanso, no solo cuánto cura en teoría
	var hp_after: int = mini(G.maxHp, G.hp + heal)
	var hp_note := "PV %d ➜ %d" % [G.hp, hp_after] if hp_after > G.hp else "PV %d (ya al máximo)" % G.hp
	if Eng.has_relic(G, "reloj_roto"):
		hp_note = ""   # no se puede descansar: no se promete una curación
	var b1 := _big_opt("ui:bed", "Descansar", "Recuperas %d PV (%d%%)." % [heal, int(rp * 100 + 0.5)], hp_note)
	b1.pressed.connect(func():
		Sfx.play("heal")
		var gained: int = mini(G.maxHp, G.hp + heal) - G.hp
		G.hp += gained
		Main.I.toast("Recuperas %d PV." % gained if gained > 0 else "Ya tenías la vida al máximo.")
		b1.disabled = true
		ref.b2.disabled = true
		await get_tree().create_timer(0.5).timeout
		done.call())
	row.add_child(b1)
	if Eng.has_relic(G, "reloj_roto"):
		b1.disabled = true
		UIK.tip(b1, "[b][color=#f0cf7a]Reloj Detenido[/color][/b]\nEl tiempo no corre para ti: no puedes descansar.")
	var b2 := _big_opt("ui:anvil", "Mejorar", "Mejora una carta de tu mazo.")
	b2.disabled = not G.deck.any(func(c): return Eng.can_upgrade(c))
	b2.pressed.connect(func():
		var cands: Array = G.deck.filter(func(c): return Eng.can_upgrade(c))
		ref.b1.disabled = true
		ref.b2.disabled = true
		var pick: Array = await Dlg.pick_cards({"title": "Elige una carta para mejorar", "sub": "Pasa el ratón (o el foco) por una carta para ver al lado cómo queda mejorada.", "upgradePreview": true, "cards": cands, "n": 1, "cancel": "Cancelar", "confirmLabel": "Mejorar"})
		if pick.is_empty():
			ref.b1.disabled = Eng.has_relic(G, "reloj_roto")
			ref.b2.disabled = not G.deck.any(func(c): return Eng.can_upgrade(c))
			return
		var c = G.deck.filter(func(x): return x.uid == pick[0].uid)[0]
		c.up = true
		Sfx.play("buff")
		await Dlg.view_cards("¡Carta mejorada!", [c])
		done.call())
	row.add_child(b2)
	ref.b1 = b1
	ref.b2 = b2
	if b1.disabled and b2.disabled:
		# Reloj Detenido y nada que mejorar: que nunca se quede atascada aquí
		var skip := UIK.button("Seguir el camino", "big")
		skip.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		skip.pressed.connect(func(): done.call())
		col.add_child(skip)
		skip.grab_focus.call_deferred()
	else:
		(b2 if b1.disabled else b1).grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


static func _big_opt(icon: String, title: String, sub: String, note: String = "") -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 240) * maxf(1.0, UIK.text_scale)   # con el texto grande la nota «PV 6 ➜ 9» cabe
	b.focus_mode = Control.FOCUS_ALL
	var sb := UIK.stylebox(Color("#32284c"), UIK.GOLD, 3, 18, 10)
	var sbh := UIK.stylebox(Color("#46386a"), Color.WHITE, 3, 18, 16)
	var sbd := UIK.stylebox(Color("#16121f"), Color("#4a3f6b"), 3, 18, 0)
	for st in ["normal", "pressed"]:
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	var v := VBoxContainer.new()
	UIK.full_rect(v)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := icon.split(":")
	var ir := Icons.rect(parts[0], parts[1], 96)
	ir.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	v.add_child(ir)
	v.add_child(UIK.label(title, 28, UIK.GOLD, "bold", HORIZONTAL_ALIGNMENT_CENTER))
	var s := UIK.label(sub, 16, UIK.DIM, "sans", HORIZONTAL_ALIGNMENT_CENTER)
	s.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(s)
	if note != "":
		v.add_child(_note_row(note))
	b.add_child(v)
	return b


## «PV 6 ➜ 9» en verde. La flecha se dibuja: las fuentes del juego (Noto Sans, Cinzel) no traen «➜» ni «→»
## y saldrían como un recuadro de glifo ausente.
static func _note_row(note: String) -> HBoxContainer:
	var col := Color("#8dff9d")
	var row := HBoxContainer.new()
	row.name = "Note"
	row.set_meta("text", note)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 8)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := note.split(" ➜ ")
	for i in parts.size():
		if i > 0:
			var arr := Control.new()
			arr.custom_minimum_size = Vector2(26, 24)
			arr.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			arr.mouse_filter = Control.MOUSE_FILTER_IGNORE
			arr.draw.connect(func():
				var y := arr.size.y / 2.0
				var shadow := Color(0, 0, 0, 0.85)
				arr.draw_line(Vector2(2, y), Vector2(17, y), shadow, 7.0)
				arr.draw_colored_polygon(PackedVector2Array([Vector2(12, y - 9), Vector2(25, y), Vector2(12, y + 9)]), shadow)
				arr.draw_line(Vector2(3, y), Vector2(16, y), col, 3.5)
				arr.draw_colored_polygon(PackedVector2Array([Vector2(13, y - 7), Vector2(23, y), Vector2(13, y + 7)]), col))
			row.add_child(arr)
		var l := UIK.label(parts[i], 24, col, "bold", HORIZONTAL_ALIGNMENT_CENTER)
		UIK.outlined(l, 5)
		row.add_child(l)
	return row
