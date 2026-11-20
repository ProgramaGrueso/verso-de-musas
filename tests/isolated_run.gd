extends RefCounted
## Relanza un test con un perfil de usuario temporal (`XDG_DATA_HOME`): los tests que juegan partidas falsas
## (historial, logros, rachas…) no deben escribir en el `meta.json` / `save.json` del jugador.
## Uso, al principio de `_ready()`:
##   const Iso := preload("res://tests/isolated_run.gd")
##   if Iso.needed():
##       await Iso.relaunch(self, "/tmp/vdm_<test>")
##       return

const FLAG := "VDM_ISOLATED_PROFILE"


static func needed() -> bool:
	return OS.get_environment(FLAG) == ""


## En el hijo: si el padre muere (p. ej. lo mata `timeout`), el hijo sale también en vez de quedarse colgado.
static func watch_parent(node: Node) -> void:
	var ppid := int(OS.get_environment("VDM_ISOLATED_PARENT"))
	if ppid <= 0 or not DirAccess.dir_exists_absolute("/proc/%d" % ppid):
		return   # sin /proc (no Linux) no se vigila: OS.is_process_running solo ve procesos hijos
	var t := Timer.new()
	t.wait_time = 2.0
	t.autostart = true
	t.timeout.connect(func():
		if not DirAccess.dir_exists_absolute("/proc/%d" % ppid):
			print("El proceso padre ya no existe: salgo")
			node.get_tree().quit(3))
	node.add_child(t)


## Lanza el mismo comando con el perfil `dir` (vacío), espera a que acabe y sale con su código de salida.
static func relaunch(node: Node, dir: String) -> void:
	rm_tree(dir)
	DirAccess.make_dir_recursive_absolute(dir)
	OS.set_environment("XDG_DATA_HOME", dir)
	OS.set_environment(FLAG, "1")
	OS.set_environment("VDM_ISOLATED_PARENT", str(OS.get_process_id()))
	var cargs := Array(OS.get_cmdline_args())
	if DisplayServer.get_name() == "headless" and not ("--headless" in cargs):
		cargs.push_front("--headless")   # get_cmdline_args() no trae --headless
	var uargs := OS.get_cmdline_user_args()
	if not uargs.is_empty():
		cargs.append("--")
		cargs.append_array(Array(uargs))
	var pid := OS.create_process(OS.get_executable_path(), PackedStringArray(cargs))
	if pid <= 0:
		print("No se pudo relanzar el test con un perfil aislado")
		node.get_tree().quit(2)
		return
	if DisplayServer.get_name() != "headless":
		node.get_window().mode = Window.MODE_MINIMIZED
	while OS.is_process_running(pid):
		await node.get_tree().create_timer(0.5).timeout
	var code := OS.get_process_exit_code(pid)
	rm_tree(dir)
	node.get_tree().quit(code)


## Borra el perfil temporal (solo rutas bajo /tmp/vdm_).
static func rm_tree(path: String) -> void:
	if not path.begins_with("/tmp/vdm_"):
		return
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		d.remove(f)
	for sub in d.get_directories():
		rm_tree(path + "/" + sub)
	DirAccess.remove_absolute(path)
