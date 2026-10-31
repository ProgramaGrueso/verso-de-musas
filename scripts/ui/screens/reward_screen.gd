class_name RewardScreen
extends Control
## Recompensas tras un combate.

var rew: Dictionary
var tier := "normal"
var _card_taken := false
var _boss_taken := false
var _list: VBoxContainer
var _done_btn: Button


func _ready() -> void:
	var G = Meta.run
	add_child(UIK.backdrop(G.act))
	add_child(UIK.shade(0.35, 0.65))
	Sfx.music("map", G.act)
	_card_taken = rew.cards.is_empty()
	_boss_taken = rew.bossRelics == null
	var col := UIK.center_col(self, 12)
	var t := UIK.label("¡Victoria!", 46, UIK.GOLD, "title", HORIZONTAL_ALIGNMENT_CENTER)
	UIK.outlined(t, 10)
	col.add_child(t)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 10)
	col.add_child(_list)
	_item("ui:gold", "%d de oro" % rew.gold, func(): Eng.gain_gold(G, rew.gold); Sfx.play("coin"))
	if rew.potion != null:
		var p: Dictionary = DB.potions[rew.potion]
		_item("potion:" + rew.potion, "%s\n[font_size=16][color=#a79fc0]%s[/color][/font_size]" % [p.n, p.d], func():
			var i: int = G.potions.find(null)
			if i < 0:
				Main.I.toast("Tienes todas las pociones llenas.")
				return false
			G.potions[i] = rew.potion
			Sfx.play("potion"))
	if rew.relic != null:
		var r: Dictionary = DB.relics[rew.relic]
		_item("relic:" + rew.relic, "%s\n[font_size=16][color=#a79fc0]%s[/color][/font_size]" % [r.n, r.d], func(): Eng.add_relic(G, rew.relic); Sfx.play("buff"))
	if rew.bossRelics != null:
		_item("node:boss", "Elige una reliquia de jefe\n[font_size=16][color=#a79fc0]Obtienes una de tres.[/color][/font_size]", func():
			var o := Dlg._overlay()
			var v := Dlg._center_col(o)
			v.add_child(Dlg._title("Reliquia de jefe"))
			var row := Dlg._row(14)
			var first_b: Button = null
			for id in rew.bossRelics:
				var r: Dictionary = DB.relics[id]
				var b := UIK.button(r.n, "", 24)
				if first_b == null:
					first_b = b
				b.icon = Icons.tex("relic", id)
				if b.icon == null:
					b.text = "%s  %s" % [r.i, r.n]
				b.expand_icon = true
				b.add_theme_constant_override("icon_max_width", 44)
				b.custom_minimum_size = Vector2(300, 0)
				var d := UIK.label(r.d, 16, UIK.DIM)
				d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
				d.custom_minimum_size = Vector2(280, 0)
				var cc := VBoxContainer.new()
				cc.add_theme_constant_override("separation", 8)
				cc.add_child(b)
				cc.add_child(d)
				var rid: String = id
				b.pressed.connect(func(): Eng.add_relic(G, rid); Sfx.play("buff"); o.close(true))
				row.add_child(cc)
			v.add_child(row)
			if first_b != null:
				first_b.grab_focus.call_deferred()
			var res = await o.done
			if res == true:
				_boss_taken = true
				return true
			return false)
	if not rew.cards.is_empty():
		_item("ui:deck", "Añadir una carta a tu mazo\n[font_size=16][color=#a79fc0]Elige 1 de 3.[/color][/font_size]", func():
			var cards := []
			for id in rew.cards:
				var shown := Eng.make_card(G, id)
				if Eng.has_relic(G, "huevo") and Eng.can_upgrade(shown):
					shown.up = true
				cards.append(shown)
			var pick: Array = await Dlg.pick_cards({"title": "Elige una carta", "sub": "Se añadirá a tu mazo.", "cards": cards, "n": 1, "cancel": "Saltar", "big": true, "confirmLabel": "Tomar carta"})
			if pick.is_empty():
				return false
			Eng.gain_card(G, pick[0].id)
			_card_taken = true
			Sfx.play("buff"))
	_done_btn = UIK.button("Continuar ➜", "big")
	_done_btn.pressed.connect(func():
		if not _card_taken and not await Dlg.confirm("¿Seguro que quieres continuar sin elegir una carta?"):
			return
		if not _boss_taken:
			Main.I.toast("Elige una reliquia de jefe primero.")
			return
		Nav.node_done(tier == "boss"))
	_done_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	col.add_child(_done_btn)
	if _list.get_child_count() > 0:
		_list.get_child(0).grab_focus.call_deferred()
	else:
		_done_btn.grab_focus.call_deferred()
	UIK.fade_in(self, 0.3)


func _item(icon: String, bb: String, fn: Callable) -> void:
	var b := Button.new()
	b.custom_minimum_size = Vector2(520, 76)
	b.focus_mode = Control.FOCUS_ALL
	var sb := UIK.stylebox(Color("#2a2140"), Color("#4a3f6b"), 2, 14, 6)
	var sbh := UIK.stylebox(Color("#3a2e5c"), UIK.GOLD, 2, 14, 10)
	var sbd := UIK.stylebox(Color("#16121f"), Color("#2a2540"), 2, 14, 0)
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sbh)
	b.add_theme_stylebox_override("focus", sbh)
	b.add_theme_stylebox_override("pressed", sbh)
	b.add_theme_stylebox_override("disabled", sbd)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 16
	row.offset_right = -16
	row.add_theme_constant_override("separation", 16)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var parts := icon.split(":")
	var ic := Icons.frame(parts[0], parts[1], 56, UIK.GOLD)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(ic)
	var r := UIK.rich(bb, 24)
	r.fit_content = true
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(r)
	b.add_child(row)
	b.pressed.connect(func():
		Sfx.play("click")
		var res = await fn.call()
		if res != false:
			b.disabled = true
			b.modulate = Color(1, 1, 1, 0.6)
			var found_next := false
			for c in _list.get_children():
				if c is Button and not c.disabled:
					c.grab_focus.call_deferred()
					found_next = true
					break
			if not found_next and _done_btn != null:
				_done_btn.grab_focus.call_deferred()
		Main.I.update_top())
	_list.add_child(b)
