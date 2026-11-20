class_name UnlockBanner
extends Control
## Avisos emergentes de progreso (arriba a la derecha, en cola): imagen nueva de la Galería, logro conseguido
## y cartas/reliquias desbloqueadas. Se cuelga de Main y escucha las señales de Meta.

const HOLD := 3.0
const GAP := HOLD + 0.95   # entrada + espera + salida: un aviso no se monta sobre el anterior

var _free_at := 0.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 3500
	Meta.unlocked.connect(_on_lore)
	Meta.achieved.connect(_on_ach)
	Meta.content_unlocked.connect(_on_content)


func _on_lore(l: Dictionary) -> void:
	show_banner(Medal.disc("lore:" + str(l.id), 64, true), tr("Nueva imagen en la Galería"), str(l.title), UIK.GOLD)


func _on_ach(a: Dictionary) -> void:
	show_banner(Medal.make(a, 64, true), tr("Logro desbloqueado"), str(a.n), UIK.GOLD, str(a.d))


func _on_content(g: Dictionary) -> void:
	var ic := Progress.group_icon(g)
	var art: Control
	if ic[0] == "muse":
		art = Medal.disc("muse:" + str(ic[1]), 64, true, Color(DB.characters[ic[1]].glow))
	else:
		art = Icons.frame(ic[0], ic[1], 64)
	show_banner(art, tr("Nuevo contenido · desde la próxima partida"), _cap(Progress.group_text(g)), UIK.GREEN)


static func _cap(t: String) -> String:
	return t.substr(0, 1).to_upper() + t.substr(1) if t != "" else t


## Muestra un aviso (se encola si hay otro en pantalla).
func show_banner(art: Control, head: String, title: String, col: Color, sub: String = "") -> void:
	var now := Time.get_ticks_msec() / 1000.0
	var start := maxf(now, _free_at)
	_free_at = start + GAP
	if start > now:
		await get_tree().create_timer(start - now).timeout
	if not is_inside_tree():
		art.free()
		return
	var d := PanelContainer.new()
	var sb := UIK.stylebox(Color("#120d1d", 0.96), col, 2, 14, 14)
	sb.content_margin_left = 12; sb.content_margin_right = 18; sb.content_margin_top = 10; sb.content_margin_bottom = 10
	d.add_theme_stylebox_override("panel", sb)
	d.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	d.add_child(row)
	art.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(art)
	var colv := VBoxContainer.new()
	colv.add_theme_constant_override("separation", 1)
	colv.mouse_filter = Control.MOUSE_FILTER_IGNORE
	colv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	colv.add_child(UIK.label(head.to_upper(), 12, Color(col, 0.9), "bold"))
	var tl := UIK.label(title, 20, UIK.TEXT, "bold")
	tl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tl.custom_minimum_size = Vector2(300, 0)
	colv.add_child(tl)
	if sub != "":
		var sl := UIK.label(sub, 14, UIK.DIM)
		sl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		sl.custom_minimum_size = Vector2(300, 0)
		colv.add_child(sl)
	row.add_child(colv)
	add_child(d)
	d.reset_size()
	var x1 := 1280.0 - d.size.x - 18.0
	d.position = Vector2(1300, 132)
	d.modulate.a = 0.0
	Sfx.play("win" if col == UIK.GOLD else "relic")
	var tw := d.create_tween()
	tw.set_parallel(true)
	tw.tween_property(d, "position:x", x1, 0.38).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(d, "modulate:a", 1.0, 0.25)
	tw.chain().tween_interval(HOLD)
	tw.chain().tween_property(d, "modulate:a", 0.0, 0.45)
	tw.chain().tween_callback(d.queue_free)
