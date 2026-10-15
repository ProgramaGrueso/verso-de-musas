class_name Icons
extends RefCounted
## Iconos pintados (assets/icons/<tipo>_<id>.webp) que sustituyen a los emojis.
## tipos: relic, potion, node, orb, intent, ui, status

const DIR := "res://assets/icons/"


static func path(kind: String, id: String) -> String:
	return "%s%s_%s.webp" % [DIR, kind, id]


static func has(kind: String, id: String) -> bool:
	return ResourceLoader.exists(path(kind, id))


static func tex(kind: String, id: String) -> Texture2D:
	var p := path(kind, id)
	return load(p) if ResourceLoader.exists(p) else null


## Icono cuadrado simple (sin marco) para usar en layouts.
static func rect(kind: String, id: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = tex(kind, id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size = Vector2(size, size)
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


## Icono del objeto sobre fondo transparente, con una sombra suave (sin marco ni placa).
## Los parámetros border/circle/bw se conservan por compatibilidad y se ignoran.
static func frame(kind: String, id: String, size: float, _border: Color = UIK.GOLD, _circle: bool = false, _bw: int = 2) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(size, size)
	holder.size = Vector2(size, size)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := rect(kind, id, size)
	sh.modulate = Color(0, 0, 0, 0.55)
	sh.position = Vector2(0, size * 0.04)
	holder.add_child(sh)
	holder.add_child(rect(kind, id, size))
	return holder


## Etiqueta BBCode que incrusta el icono en un RichTextLabel.
static func bb(kind: String, id: String, size: int = 20) -> String:
	if not has(kind, id):
		return ""
	return "[img=%dx%d]%s[/img]" % [size, size, path(kind, id)]


## Icono + texto en una fila (para HP, oro...).
static func with_text(kind: String, id: String, text: String, size: float, font_size: int, color: Color, font_kind: String = "bold") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ic := rect(kind, id, size)
	ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(ic)
	var l := UIK.label(text, font_size, color, font_kind)
	l.name = "Text"
	h.add_child(l)
	return h
