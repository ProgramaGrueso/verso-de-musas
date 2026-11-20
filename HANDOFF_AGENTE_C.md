# HANDOFF · Agente C (balance + caché de partículas + propuesta de medición) · 2026-11-19

Dueño exclusivo de: `tools/`, `data/`, `scripts/ui/uik.gd`, `scripts/ui/juice.gd`, `tests/balance.gd` y tests de balance.

## 2 · Caché de la textura de `UIK.embers` — HECHO
- `scripts/ui/uik.gd`: nuevo `static var _ember_tex` + `static func ember_tex()` (misma Image 16×16, misma fórmula);
  `embers()` usa `p.texture = ember_tex()` en vez de fabricar Image + ImageTexture en cada llamada.
- `scripts/ui/juice.gd`: no usa `embers` ni crea Images (solo `ring` con `_draw`): no hubo nada que cambiar.
- Verificado sin cambio visual: script de comprobación (scratchpad, `ember_check.gd`) compara los bytes de la textura
  vieja con `UIK.ember_tex()` → `pixeles identicos: true | misma instancia: true`.
- Propuesta para el dueño de `combat_screen.gd` (no tocado): `_burst` hace `p.texture = halo_tex()` tras `UIK.embers`;
  ahora ya no se paga la Image extra, así que ese comentario («UIK.embers fabrica una Image…») queda obsoleto.
  `halo_tex()` usa otra fórmula (centrado `(N-1)/2`, radio N/2, redondeo propio) que coincide en la práctica con
  `ember_tex()`; podrían unificarse en `UIK.ember_tex()` si se comprueba a ojo.

## 1 · Escarabajo Real — HECHO (`shellCap` 10 → 12)
- **El 18,6 % era ruido de muestra**: salía de `balance.gd -- 100 0` = 11 derrotas en 59 combates (±10 pts).
  Con 4 semillas × 1000 partidas por musa (~2100 combates del Escarabajo) la línea base real era **13,8 %**.
- Medidas (pool de semillas 1–4, `-- 1000 0 all <semilla>`, Pesadilla 0; script en el scratchpad `measure.sh`):

  | cambio | Escarabajo (n) | % derrotas | PV perdidos | victoria global |
  |---|---|---|---|---|
  | base (`shellCap` 10) | 2103 | 13,8 % | 42,4 | 35,5 % |
  | **`shellCap` 12** | 2088 | **10,1 %** | 39,4 | 35,4 % |

  Resto de élites sin cambio apreciable (bosun 11,6→12,4, rootwarden 12,3→12,5: dentro del ruido).
  No se probó 14: 12 ya cae en el centro de la banda 8–12 y 14 la acercaría al borde inferior.
  Referencia con el comando corto del HANDOFF (`-- 100 0`): Escarabajo 10,7 % (56 combates).
- `tools/make_content_w2.py:98` `shellCap` 12 → regenerado `data/enemies_extra.json` (único cambio en `data/`).
- **Desincronía encontrada y corregida**: el generador tenía el Contramaestre Espectral con 90–94 PV y
  «Cañonazo Rompible (15)» 29/brk 15, pero el JSON commiteado (`13e7d0e`) tenía 96–100 PV y (16) 30/brk 16
  (los valores medidos, 10,5–11,6 %). Regenerar los habría cambiado en silencio; se puso en el generador lo que
  ya estaba en el JSON (`tools/make_content_w2.py:38,40`), así regenerar no toca al bosun.
- `tests/events_test.gd:175-181`: la prueba del Escarabajo leía 10 a mano; ahora lee `def.shellCap` (y exige ≥ 8).
- Los datos base (350 trazas) no cambian: `shellCap` solo actúa con `DB.extra`.

## 3 · Fotograma de ~12 ms con Irene — HERRAMIENTA HECHA, MEDICIÓN PENDIENTE (de quien tenga los archivos)
- `scripts/ui/uik.gd`: perfil por fotograma **apagado por defecto**. Se enciende con `VDM_PROF=1` (entorno) o
  `-- --prof`; umbral de impresión `VDM_PROF_MS` (por defecto 9 ms). API: `var t := UIK.prof_t()` …
  `UIK.prof_add("Clase.func", t)`. Con el flag apagado: `prof_t()` devuelve 0 y `prof_add` sale en la 1.ª línea.
  El fotograma se cierra en `UIK.watch_tick()` (Main lo llama en `_process`), e imprime p. ej.
  `[prof] fotograma 812 · 12.40 ms de pared · 7.90 ms marcados · CombatScreen._layout_hand 6.10 ms×1, …`.
  Ya instrumentado: `UIK.watch_tick` (lo único de los sospechosos que es mío).
- Comprobado: `VDM_PROF=1 VDM_PROF_MS=0.001 godot --headless --path . res://tests/perf_budget_test.tscn` imprime
  1435 líneas `[prof]` y el test sigue 19 ok; sin el flag, 0 líneas `[prof]`.
- **Dónde medir (propuesta, archivos de otros agentes; 2 líneas por sitio):**
  - `scripts/ui/screens/combat_screen.gd:1416` `_layout_hand`: `var t := UIK.prof_t()` al entrar y
    `UIK.prof_add("CS._layout_hand", t)` antes de cada `return` y al final.
  - `scripts/ui/card_view.gd:209` `set_text_once` y `:335` `_fit_text` (etiquetas separadas: la 2.ª suele estar
    dentro de la 1.ª; así se ve si el coste es el ajuste de texto o el resto).
  - `scripts/ui/enemy_view.gd:188` `refresh`.
  - `scripts/core/sfx.gd:167` `_take_player` (y, si sale caro, el `play()` que lo sigue: carga de stream).
  - Opcional: `combat_screen._burst` y `_banner` (crean nodos en `fx_layer`).
- Comando de medida: `VDM_PROF=1 godot --path . --print-fps res://tests/perf_irene.tscn -- irene 8 boss`
  (ventana, no headless). Si «ms marcados» queda muy por debajo de «ms de pared» en el fotograma caro, el coste
  está fuera de GDScript (render, rasterizado de fuentes, compilación de shaders): pasar a `--verbose` o al
  profiler del editor.

## Verificación final (todo tras los cambios)
- `godot --headless --path . --quit`: limpio (solo los avisos de fuga al salir, idénticos a HEAD: comprobado
  cambiando temporalmente `uik.gd` por el de HEAD).
- `res://tests/perf_budget_test.tscn` 19 ok, 0 fallan · `res://tests/hand_stagger.tscn` 0 fallan.
- `events_test` 143.302 comprobaciones, 0 fallan · `run_traces` 350 ok · `risk` 892, 0 fallan ·
  `boss_phase_test` 0 fallan · `progress_test` 712 ok · `save_test.tscn` SAVE_TEST OK.
- Nota: el HANDOFF principal lista `--script tests/save_test.gd`, que no compila (necesita los autoloads);
  el modo correcto es `XDG_DATA_HOME=/tmp/x godot --headless --path . res://tests/save_test.tscn`.

## Pendiente
- Ítem 3: añadir las marcas `UIK.prof_t/prof_add` en los 4 sitios propuestos (dueños de esos archivos) y medir.
- (Menor, no tocado) `UIK._watch` nunca borra los ids de botones liberados: crece durante la sesión.
