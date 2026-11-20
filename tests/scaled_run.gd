extends Node
## Ejecuta otro test con el tamaño del texto cambiado (Opciones ▸ Tamaño del texto), sin guardar ajustes.
## Uso: godot --headless --path . res://tests/scaled_run.tscn -- 1.3 res://tests/flecos_layout_test.tscn


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() < 2:
		push_error("uso: -- <escala> <res://tests/x.tscn>")
		get_tree().quit(2)
		return
	var sc := float(args[0])
	Meta.settings.text_scale = sc   # solo en memoria: Main._ready lo copia a UIK.text_scale
	UIK.text_scale = sc
	print("ESCALA DEL TEXTO: ", sc)
	get_tree().change_scene_to_file.call_deferred(args[1])
