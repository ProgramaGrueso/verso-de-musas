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
	var b1 := _big_opt("ui:bed", "Descansar", "Recuperas %d PV (%d%%)." % [heal, int(rp * 100 + 0.5)])
	b1.pressed.connect(func():
		Sfx.play("heal")
		G.hp = mini(G.maxHp, G.hp + heal)
		Main.I.toast("Recuperas %d PV." % heal)
		b1.disabled = true
		ref.b2.disabled = true
		await get_tree().create_timer(0.5).timeout
		done.call())
	row.add_child(b1)
	var b2 := _big_opt("ui:anvil", "Mejorar", "Mejora una carta de tu mazo.")
	b2.disabled = not G.deck.any(func(c): return Eng.can_upgrade(c))
	b2.pressed.connect(func():
		var cands: Array = G.deck.filter(func(c): return Eng.can_upgrade(c))
		ref.b1.disabled = true
		ref.b2.disabled = true
		var pick: Array = await Dlg.pick_cards({"title": "Elige una carta para mejorar", "sub": "Al elegir una carta verás cómo queda mejorada.", "upgradePreview": true, "cards": cands, "n": 1, "cancel": "Cancelar", "confirmLabel": "Mejorar"})
		if pick.is_empty():
			ref.b1.disabled = false
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
	b1.grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


static func _big_opt(icon: String, title: String, sub: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 240)
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
	b.add_child(v)
	return b
