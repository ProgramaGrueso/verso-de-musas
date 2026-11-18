extends Node
## Lee la partida que dejó `crash_writer.tscn` tras un kill -9.
## Uso: XDG_DATA_HOME=/tmp/x godot --path . res://tests/crash_reader.tscn

func _ready() -> void:
	var G = Meta.load_run()
	var ok: bool = G != null and G.char == "irene" and G.get("gold", 0) > 0 and G.map != null
	print("CRASH_SAVE ", "OK" if ok else "FALLO")
	get_tree().quit(0 if ok else 1)
