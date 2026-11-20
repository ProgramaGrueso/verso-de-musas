class_name Loc
extends RefCounted
## Localización (Fase 5). El español es el idioma FUENTE: la clave de cada texto es el propio texto en español
## (msgid = español). Las traducciones viven en res://translations/*.po (ui_en.po: interfaz; content_en.po:
## cartas, reliquias, enemigos, eventos…) y se cargan TODAS como locale «en» al arrancar (Meta._load_settings).
##
## Uso:
##   - En métodos de instancia (Node/Object): tr("Texto en español") · tr_n("1 carta", "%d cartas", n) % n
##   - En funciones estáticas (no hay self): Loc.t("Texto") · Loc.tn("…", "…", n)
##   - Con datos: tr("Cuesta %d de oro") % precio — nunca concatenar trozos de frase.
## tools/extract_loc.py recoge tr("…"), tr_n("…", "…"), Loc.t("…") y Loc.tn("…", "…") con literales.

const DIR := "res://translations"
const LANGS := [["es", "Español"], ["en", "English"]]   # noloc: el nombre de cada idioma va en su propio idioma

static var _loaded := false
static var _lang := "es"


## Carga los .po (una vez) y aplica el idioma: VDM_LANG / --lang=xx (pruebas, no se guarda) > ajuste guardado
## > idioma del sistema si es inglés > español.
## `had_settings`: ya existía user://settings.json (quien ya jugaba sin elegir idioma sigue en español).
## No se nombra Meta aquí: este script se compila como dependencia del autoload Meta, antes de que exista.
static func setup(settings: Dictionary, had_settings: bool = false) -> void:
	if not _loaded:
		_loaded = true
		load_translations()
	var lang := str(settings.get("language", ""))
	if lang == "":
		# quien ya jugaba (ajustes guardados sin idioma) sigue en español; solo una instalación nueva mira el sistema
		lang = "es" if had_settings else system_default()
		settings["language"] = lang
	var forced := forced_lang()
	_apply(forced if forced != "" else lang)
	# sin traducción automática de Godot en los Label/Button: todo texto pasa por tr()/Loc.t() explícito, así
	# lo que se mide (UIK.fit_*) es exactamente lo que se pinta y un texto sin envolver se nota en inglés
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and tree.root != null:
		tree.root.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED


## Idioma pedido por entorno o línea de órdenes (tests: `VDM_LANG=en godot …` o `godot … -- --lang=en`).
static func forced_lang() -> String:
	var e := OS.get_environment("VDM_LANG")
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--lang="):
			e = a.substr(7)
	return e if _known(e) else ""


## Primer arranque: inglés si el sistema está en inglés, si no español. Solo en el juego exportado: desde el
## editor (`godot --path .`, tests) se arranca en español para que todo sea reproducible; VDM_LANG=en prueba el
## inglés.
static func system_default() -> String:
	if OS.has_feature("template") and OS.get_locale_language() == "en":
		return "en"
	return "es"


static func _known(code: String) -> bool:
	for l in LANGS:
		if l[0] == code:
			return true
	return false


## Carga todos los res://translations/*.po como Translation (su cabecera dice «Language: en»). En un juego
## exportado el directorio puede listar «x.po.import» / «x.po.remap»: ResourceLoader.list_directory devuelve
## el nombre original; si no existiera, se limpia el sufijo a mano. Devuelve cuántos se cargaron.
static func load_translations() -> int:
	var names := ResourceLoader.list_directory(DIR)
	if names.is_empty():
		names = DirAccess.get_files_at(DIR)
	var seen := {}
	var n := 0
	for f in names:
		var name := f.trim_suffix(".remap").trim_suffix(".import")
		if not name.ends_with(".po") or seen.has(name):
			continue
		seen[name] = true
		var t = load(DIR + "/" + name)
		if t is Translation:
			if (t as Translation).locale == "":
				(t as Translation).locale = "en"
			TranslationServer.add_translation(t)
			n += 1
		else:
			push_warning("Loc: no se pudo cargar " + name)
	return n


static func lang() -> String:
	return _lang


static func _apply(code: String) -> void:
	_lang = code if _known(code) else "es"
	TranslationServer.set_locale(_lang)


## Cambia el idioma al momento y lo apunta en `settings` (quien llama guarda: Meta.save_settings()). Lo
## visible lo rehace quien llama (Dlg.options rehace su panel y, al cerrarse, Main.relocalize el resto).
static func set_lang(code: String, settings: Dictionary) -> void:
	if not _known(code):
		return
	settings["language"] = code
	_apply(code)


## Traducción para código estático (Dlg, UIK, Nav…). En instancias, tr() hace lo mismo.
static func t(msg: String, ctx: String = "") -> String:
	return String(TranslationServer.translate(msg, ctx))


static func tn(msg: String, plural: String, n: int, ctx: String = "") -> String:
	return String(TranslationServer.translate_plural(msg, plural, n, ctx))
