extends Node
## Escribe una partida y se queda vivo para que un `kill -9` la interrumpa (prueba de cierre brusco).
## Uso: XDG_DATA_HOME=/tmp/x godot --path . res://tests/crash_writer.tscn -- 4242

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var gold: int = int(args[0]) if args.size() > 0 else 4242
	var G := Eng.new_run("irene", {"seed": 909})
	G.map = RunGen.gen_map(G)
	G.pos = G.map.rows[0][0]
	G.pos.visited = true
	G.gold = gold
	Meta.save_run(G)
	print("SAVED ", gold)
	# se queda vivo hasta que el proceso externo lo mate
	while true:
		OS.delay_msec(100)
