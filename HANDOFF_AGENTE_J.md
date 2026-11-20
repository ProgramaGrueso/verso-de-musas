# HANDOFF · Agente J · localización ES/EN del contenido (Fase 5)

Dueño de: `data/`, `tools/` (generadores, `extract_content_loc.py`), `scripts/ui/card_text.gd`, `scripts/engine/`,
`scripts/core/` (salvo ajustes/idioma de I), `translations/content_en.po`, `tests/events_test`, `tests/balance`,
`tests/content_loc_*`. Sin commits.

## Diseño (hecho)
- msgid = español. Los JSON NO cambian. `DB.load_all()` registra los campos de texto (`DB.LOC_FIELDS`,
  `DB.LOC_FIELDS_PROGRESS`) y `DB.relocalize()` los traduce EN SU SITIO (`DB.cards[id].name`, `DB.relics[id].d`…),
  guardando el español aparte (`DB.es("orb/ola/n")`). La UI no necesita cambios para ver nombres traducidos.
- `DB.relocalize()` se llama: al final de `load_all`, en `Sfx._ready` (Meta carga DB y fija el idioma antes) y en
  `Sfx._notification(NOTIFICATION_TRANSLATION_CHANGED)` (cada `TranslationServer.set_locale`). Es idempotente.
- Helpers estáticos: `DB.tl(es)`, `DB.tln(es_sing, es_plural, n)`; plantillas con `{marcadores}` + `String.format`.
- `CardText` reescrito con frases enteras por plantilla; `CardText.TYPE_ES` ahora es `static var` (se rehace al
  cambiar de idioma). `Favors.DEFS` ahora es `static var` (traducido en su sitio).
- Claves del glosario (`DB.glos`) siguen en español (son claves internas); solo se traducen etiqueta y texto.

## Hitos
- [x] Código localizable (db, card_text, eng, events, favors, daily, progress, sfx). **Español IDÉNTICO**:
  `tests/content_loc_snapshot.gd` (11406 entradas con extra, 5116 sin) contra el código de HEAD → única diferencia
  Supernova «+50%» → «+35%» (ahora sale del dato `heatMul`).
- [x] `tools/extract_content_loc.py` + `translations/content_en.po`: 1327 msgids (15 plurales), 100 % traducidos.
  `python3 tools/extract_content_loc.py` regenera/mezcla; `--check` sale con 1 si falta algo, hay marcadores
  ({x}, %s, **, BBCode) que no cuadran, un msgid choca con `ui_en.po` o singular/plural desparejados;
  `--fill X.json` incorpora traducciones `{msgid: "en" | ["sing", "plural"]}`; `--list-missing`.
  Fuentes: campos de `DB.LOC_FIELDS` (leídos de db.gd), balance_w2, claves del glosario, y en código
  `DB.tl/DB.tln/Loc.t/Loc.tn/_f/_fn/_kw/_relic_text`, dicts name/desc de Daily.MODS y Favors.DEFS, y líneas
  con el comentario `# loc-strings`.
- [x] `tests/content_loc_test.gd` (0 fallos / 4442): falla si un texto de datos no tiene EN, si el cargador real
  (`Loc.load_translations`) no lo aplica, si queda español en cartas/eventos/favores… con locale en, o si al volver a
  es el texto no es idéntico. Comprobado que falla (exit 1) al vaciar 3 traducciones.
- [x] Comprobado tras el corte por límite (2026-11-20): `data/` sin cambios (git), `--check` = 0, snapshot es con y
  sin extra contra HEAD → solo Supernova (con extra; sin extra 0 diferencias).
- [x] `tests/content_loc_fx_test.gd` (texto vs motor, 1500 comprobaciones, 0 fallos): juega cada carta (base y
  mejorada) en un combate controlado y compara daño, Bloqueo, energía, robo, estados, PV y daño previsto en combate
  (con Calor/Cuerda cargados) con los datos y con el texto; ejecuta cada gancho de reliquia y cada poción y exige
  que cada cambio medido salga como número en su descripción; Supernova (+35 % y 1,35 real).
  **Encontró 1 discrepancia real, corregida**: Pozo de Vida decía «+18 PV máx.» (balance_w2) pero el motor sumaba
  25 fijo → `scripts/engine/relics.gd:33` lee `DB.relics.pozo.hp` (sin DB.extra sigue en 25: trazas intactas).
  No medibles con ganchos (avisos): ídolo dorado, tarjeta, huevo, pluma, cristal, estandarte, guantelete,
  colmillo_vibora, grimorio, muelle_doble y pociones duplicar/herrero/gambito.
- [x] Batería (2026-11-20, `scratchpad/bat_j.sh`, XDG temporal, timeout): arranque limpio (solo el aviso de
  recursos al salir que ya había en HEAD) · events_test 143302/0 · run_traces 350/0 · risk 891/0 ·
  boss_phase_test 0 fallan · progress_test 708/0 · save_test OK · perf_budget_test 19/0 · content_loc_test 4442/0 ·
  content_loc_fx_test 1500/0 · `extract_content_loc.py --check` 0. (risk/progress cuentan lo mismo que HEAD limpio.)

## Comandos
- Regenerar PO tras cambiar datos/código: `python3 tools/extract_content_loc.py` (luego `--list-missing`,
  traducir en un JSON y `--fill x.json`; `--check` para CI).
- Tests: `godot --headless --path . --script res://tests/content_loc_test.gd` y `.../content_loc_fx_test.gd`.
- Snapshot ES: `... --script tests/content_loc_snapshot.gd -- /ruta/salida.txt [0 = sin DB.extra]`.

## Decisiones para Juan
- Pozo de Vida: ahora da +18 PV máx. como dice su texto (antes daba 25). Si preferías 25, cambia `pozo.hp`
  en `tools/make_content_w2.py` y regenera.
- «Verso de Musas» sin traducir; «Combate» (logros) = «Fight» por coincidir con la UI.
- Errata ES «y pero no queda…» conservada (el español debía quedar idéntico).

## Glosario EN (coherencia)
Fuerza Strength · Destreza Dexterity · Bloqueo Block · Débil Weak · Frágil Frail · Veneno Poison · Resplandor Glow ·
Calor Heat · Cuerda Wind-Up · Engranaje Gear · Danza Dance · Agotar Exhaust · Retener Retain · Innata Innate ·
Etérea Ethereal · Orbe Orb · Canalizar Channel · Evocar Evoke · Resonancia Resonance · Poder Power · Cuchilla Shiv ·
Espinas Thorns · PV HP · PV máx. Max HP · TODOS ALL · Precisión Accuracy · Ola/Bruma/Abismo/Perla Wave/Mist/Abyss/Pearl ·
la Aguja the Spire · Pesadilla Nightmare · Reto diario Daily Challenge · Acorazados Ironclad · musa muse.
Nombres de las musas sin traducir; título «Verso de Musas» sin traducir (como en la UI).
«Combate» (categoría de logros) = «Fight» para no chocar con ui_en.po.

## Notas para el agente I
- `deathBy` / historial guardan el NOMBRE del enemigo (texto) al morir: con idioma cambiado entre partidas sale en
  el idioma de entonces. Ideal: guardar el id y traducir al mostrar (combat_screen es tuyo).
- No hace falta que `Main.relocalize()` llame a `DB.relocalize()`: `Sfx` ya escucha
  NOTIFICATION_TRANSLATION_CHANGED y lo hace (es idempotente, así que llamarlo también no hace daño).
- Export: los `.po` se cargan con `load()`; comprobad en el preset de exportación que `translations/*.po` se
  incluyen (filtro de recursos no importados), o el EN no llegará al build.
