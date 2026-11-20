# HANDOFF · Agente I · localización ES/EN de la interfaz (Fase 5)

Dueño exclusivo de: `project.godot`, `scripts/ui/**` (salvo `scripts/ui/card_text.gd`, del agente J), ajustes de
`scripts/core/meta.gd` (`settings`, `_load_settings`), `translations/ui_en.po`, `tools/extract_loc.py`, `tests/loc_*`.
Sin commits.

## Infraestructura: LISTA (para J)

- **Idioma fuente = español; clave = el texto en español** (`msgid` = español tal cual).
- **Cargador**: `scripts/ui/loc.gd` (`class_name Loc`). `Meta._load_settings()` llama `Loc.setup(settings, …)`, que
  carga **todos** los `res://translations/*.po` (usa `ResourceLoader.list_directory`, que en un juego exportado
  devuelve el nombre original aunque el archivo esté remapeado) y fija el locale. Basta con dejar
  `translations/content_en.po` ahí: no hay que registrarlo en ningún sitio.
  - Cabecera del .po: `"Language: en\n"` y `"Plural-Forms: nplurals=2; plural=(n != 1);\n"` (copia la de `ui_en.po`).
- **Cómo traducir en código**:
  - método de instancia (Node/Object): `tr("Texto")`, `tr("Cuesta %d de oro") % n`, `tr_n("%d carta", "%d cartas", n) % n`
  - función **estática** (no hay `self`, `tr()` no compila): `Loc.t("Texto")`, `Loc.tn("…", "…", n)`
    (son `TranslationServer.translate/translate_plural`; también vale llamarlos directamente).
  - Nunca concatenar trozos de frase: un `%s` por dato y la frase entera en el msgid.
- **Locale**: `es` (sin traducción: devuelve el msgid) o `en`. `project.godot` tiene `locale/fallback="es"`
  (con el «en» por defecto de Godot, el español caería al inglés).
- **Traducción automática de Godot desactivada** en la raíz (`auto_translate_mode = DISABLED`): un `Label.text`
  NO se traduce solo; todo pasa por `tr()`/`Loc.t()`. Así lo que mide `UIK.fit_*` es lo que se pinta.
- **Idioma por defecto**: ajuste guardado `Meta.settings.language`; si no existe: «es» si ya había
  `settings.json` (quien ya jugaba), y en una instalación nueva el del sistema si es inglés **solo en el juego
  exportado** (en el editor/tests siempre «es», reproducible).
- **Forzar idioma en pruebas** (no se guarda): `VDM_LANG=en godot …` o `godot … -- --lang=en`.
- **Cambio en caliente**: Opciones ▸ Idioma → `Loc.set_lang(code, Meta.settings)`; el panel de Opciones se
  rehace al momento y, al cerrarlo, `Main.I.relocalize()` rehace la barra superior, el menú de pausa y la
  pantalla actual si es de las que no tiran dados al construirse (`Main.RELOC_SCREENS`: portada, mapa, selección,
  galería, historial, logros, compendio, diario). En combate/tienda/evento/recompensa/hoguera/favor sale un aviso
  y el idioma nuevo se ve desde la siguiente sala.
  - Si el contenido (cartas, reliquias…) cachea textos ya traducidos, engánchate ahí: `Main.relocalize()` es el
    único punto de entrada. J: si necesitas que llame a algo tuyo (p. ej. `DB.relocalize()`), dímelo aquí y lo añado.
- **Extracción**: `python3 tools/extract_loc.py` (solo `scripts/ui/**` salvo `card_text.gd` → `ui_en.po`).
  `--check` sale con 1 si falta algo; `--candidates` lista literales con pinta de texto visible sin `tr()`.
- **Fuentes**: Noto Sans / Cinzel / DejaVu (respaldo) ya cubren todo el latín de ES y EN.

- **Constantes con texto**: la línea (o una línea `# loc` justo encima) lleva `# loc`; el extractor recoge sus
  literales y el código traduce donde se usan (`tr(NODE_NAME[k])`). `# noloc: motivo` marca texto que se queda igual
  a propósito (nombres de idioma, logo «VERSO DE MUSAS» de la portada).
- **Orden de palabras**: plantillas con `{nombre}` + `.format()`: `Loc.t("{d} de {m} de {y}")` → `"{M} {d}, {y}"`
  (el código pasa `m` en minúscula y `M` capitalizado; el check de marcadores trata `{m}`/`{M}` como el mismo).
  Iniciales de la semana: un único msgid `"L M X J V S D"` partido por espacios.
- **Trucos**: un `%` literal en un texto que pasa por `%` va como `%%`. `"PV %d ➜ %d"` (hoguera) debe conservar
  `" ➜ "` en la traducción (`_note_row` parte por ahí).

## Notas para J (contenido)
- `EventScreen._tint()` colorea cifras con regex bilingüe: espera en inglés `"N gold"`, `"N Max HP"`, `"N HP"`, y
  las opciones de curar que empiecen por `"Heal"`/`"Recover"`.
- Glosario usado en la interfaz: PV→HP, Bloqueo→Block, Fuerza→Strength, Espinas→Thorns, Agotar→Exhaust,
  Retener→Retain, Innata→Innate, Pesadilla→Nightmare, Musa→Muse, Hoguera→Campfire, Reliquia→Relic,
  Mazo de robo→Draw pile, Descarte→Discard pile, Poder→Power, Maestría→Mastery, Reto diario→Daily Challenge.
- Hay 14 msgids comunes a `ui_en.po` y `content_en.po` (Agotar, Retener, Innata, Combate, Pesadilla, Reto
  diario…): van al mismo locale, así que **deben tener la misma traducción**. `tests/loc_test` lo vigila
  (comprueba que el TranslationServer devuelve lo de `ui_en.po` para cada texto).
- Pendiente (J/Juan): `deathBy` y el historial guardan el NOMBRE del enemigo; tras cambiar de idioma se ven en el
  idioma de entonces. Arreglo: guardar el id (`combat_screen.gd` ~2169 es mío; el registro está en `meta.gd`).

## Estado
- [x] Infraestructura (cargador, ajuste, Opciones ▸ Idioma, relocalize, fallback).
- [x] Envolver todos los textos de `scripts/ui/**` en `tr()`/`Loc.t()` (`--candidates` solo deja ruido: nombres
  de nodo, estilos, rutas, claves del glosario).
- [x] `translations/ui_en.po` traducido: 417 textos, 12 con plural, 0 sin traducir (`extract_loc.py --check` rc=0).
  Rehacer: `python3 tools/extract_loc.py` (conserva traducciones) · rellenar en bloque: `--fill x.json`
  (`{msgid: "en" | ["sing", "plural"]}`).
- [x] `tests/loc_test.tscn`: .po completo y con marcadores iguales, `extract_loc --check`, TranslationServer =
  .po, plurales, cambio en caliente desde Opciones (panel, portada, mapa, vuelta a es). 22 ok / 0.
- [x] `tests/ui_layout_test.tscn -- lang en` (o `VDM_LANG=en`) mide la interfaz en inglés.
- [x] Batería **es** (2026-11-20, headless, `XDG_DATA_HOME` temporal, `ulimit -c 0`): arranque limpio rc=0 ·
  loc_test 22/0 · focus_reach 56/0 · shop_pad_test 36/0 · focus_audit_test 484/0 · flecos_layout_test 66/0 ·
  event_layout_test 2261/0 · hand_stagger 0 fallan · options_test 31/0 · inspect_test 87/0 · perf_budget_test 19/0 ·
  ui_layout_test 6110/0. Tras el corte por límite: `--import` rc=0 sin errores de script, arranque limpio rc=0.
- [~] Batería **en** (`VDM_LANG=en`), 1.ª pasada: los fallos eran (a) tests que buscaban texto español literal y
  (b) 8 desbordes reales. Arreglado:
  - tests ahora comparan con `tr(msgid)` o aceptan ambos idiomas (backup en `/tmp/loc_bk_*.gd`):
    `focus_reach.gd` 88/205/208, `shop_pad_test.gd` 98/136, `focus_audit_test.gd` (is_cancel, «Añadir una carta»,
    «Mejorar», «Continuar ➜», «Rechazar los favores»), `flecos_layout_test.gd` 79, `event_layout_test.gd` 93/155,
    `options_test.gd` 167/168/214, `inspect_test.gd` 128/239/340/352/357, `perf_budget_test.gd` 174/177,
    `loc_test.gd` (acepta el idioma forzado).
  - desbordes: `daily_screen.gd` «TODAY» encoge y se alinea a la derecha de la casilla; `map_screen.gd` columna
    ▲/Here/▼ pegada al borde si no cabe; `gallery_screen.gd` título/subtítulo encogen para dejar sitio a los
    botones. En español quedan donde estaban.
  - [x] 2.ª pasada (2026-11-20), **es y en, todo 0 fallos**: arranque rc=0 · loc_test 22 · focus_reach 56 ·
    shop_pad 36 · focus_audit 484 · flecos 66 · event_layout 2261 · hand_stagger 0 fallan · options 31 ·
    inspect 87 · perf_budget 19 · ui_layout 6110 (es) / 6099 (en) ok. (Los «ERROR: … still in use / leaked at
    exit» son del cierre de Godot, ya estaban.)
- [x] Export: `--export-pack Linux` incluye `translations/ui_en.po` y `content_en.po`. Fuentes: comprobado con
  fontTools que Noto Sans (+ emoji/DejaVu de respaldo) cubre todos los caracteres de ambos .po; Cinzel cubre
  todas las letras.

## Decisiones para Juan
- Idioma por defecto: instalación nueva del juego exportado → inglés si el sistema está en inglés; quien ya
  tenía `settings.json` sigue en español.
- En combate/tienda/evento/recompensa/hoguera/favor el cambio de idioma se ve desde la siguiente sala (aviso).
- El logo «VERSO DE MUSAS» de la portada se queda en español en ambos idiomas (`# noloc`, es la marca). El
  subtítulo sí se traduce: «MUSAS MÁGICAS DEL VERSO» → «MAGICAL MUSES OF THE VERSE».
- Español retocado mínimamente: «tu Bloqueo (%d) y Osty (%d) no bastan» (concordancia) y «Tu Pluma de Fénix te
  levantaría…» (el nombre sale del dato).
- Script de batería: `battery.sh es|en` en el scratchpad de la sesión (no es del proyecto).
