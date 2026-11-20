# HANDOFF · Verso de Musas · cierre de la noche 2026-11-19/20

Proyecto: `/home/juang/projects/IngenieriaInversa/VersoDeMusas-w2` (Godot 4.7.2), rama `ccr-a7209c0c-soukyo`.
Plan maestro: `ROADMAP.md`. Este archivo es el índice único de lo que falta; los `HANDOFF_AGENTE_A..J.md`
y los `HANDOFF_FASE*.md` son historial (no se actualizan; dicen el porqué de cada cifra).

## Hecho esta noche (commits en orden)

| Commit | Qué |
|---|---|
| `668c51f` | **Bug de Juan**: las cartas no aparecían (alpha 0 eterno en `_layout_hand`, rama `spawned` con `continue`). |
| `aa73661` | Escarabajo Real `shellCap` 10→12 (derrotas 13,8→10,1 %); textura de partículas cacheada; perfil por fotograma opcional (`VDM_PROF=1`). |
| `225bb24` | Auditoría de mando: `focus_audit_test` (34 estados), foco de mapa/recompensa, flecos de layout (`flecos_layout_test`). |
| `4975c30` | Fichas de reliquia, filtros de pilas, mazo desde cualquier sala, hoguera «6→9», escala de texto 100/115/130 %, remapeo de teclado, fuente de reserva DejaVu (flechas ➜). |
| `2fdd618` | **Rendimiento**: fotograma de reparto 18–33 ms → ~7 ms (irene boss ~135 fps). Causa: emoji de reserva oculto en cada carta + re-estilos. |
| `52c8c5d` | `ui_layout_test` rehecho (antes devolvía «0 ok, 0 fallan» sin medir nada), `focus_reach` 56/0, foco de selección. |
| `51c0769` | **Fase 4**: 2 arquetipos viables por musa (≥34 %), pool podado, élites 8,0 %, jefes 19,3 %, victoria global 35,4→41,3 %. |
| `c875df9` | Retratos propios de los 3 élites (spectralbosun, rootwarden, royalbeetle). |
| `c4c9784` | Layout: `ui_layout_test` 12 233 ok / 0 fallan; eventos a 130 %; tooltips que siguen la escala. |
| `ccfb607` | **i18n contenido**: 1327 textos EN; `CardText` por frases; Supernova «+35 %»; Pozo de Vida da +18 (como dice su texto). |
| `cc2be2e` | **i18n UI**: 417 textos, selector ES/EN en Opciones con cambio en caliente, `loc_test`. |

## Tests (todo verde al cierre)
Siempre con `ulimit -c 0` y `XDG_DATA_HOME=$(mktemp -d)` (los tests sin aislar ensuciaron el perfil real, ver «Para Juan»).
```sh
godot --headless --path . res://tests/<x>.tscn     # loc_test 22 · focus_audit_test 484 · focus_reach 56 · shop_pad_test 36
                                                   # flecos_layout_test 66 · event_layout_test 2261 · options_test 31
                                                   # inspect_test 87 · sfx_test 195 · hand_stagger 0 fallan · perf_budget_test 19
godot --headless --path . --script tests/content_loc_test.gd   # 4442 ok (+ content_loc_fx_test 1500)
godot --headless --path . --script tests/events_test.gd        # 143.302 ok
godot --path . res://tests/ui_layout_test.tscn [-- lang en]    # con ventana: 12 233 ok (es), en ~6099
godot --headless --path . --script tests/balance.gd -- 1000 0  # balance (VDM_ARCH=1 / VDM_EXPLORE=1 para stats)
```
`run_traces`, `risk`, `progress_test`, `boss_phase_test`, `save_test` pasaron tras los cambios de datos (agentes C, E, J).

## Para Juan (necesita tu decisión o tus manos)
1. **Perfil real ensuciado**: `~/.local/share/godot/app_userdata/Verso de Musas/` (`meta.json`, `.bak`, `save.json`) puede tener datos falsos (historial inventado, rachas de 120) de tests sin aislar. Nadie lo ha tocado; decide si restaurar de copia o limpiar.
2. **Plantillas Linux 4.7.2** (~1 GB) para exportar el binario; luego probar en ventana y en Deck.
3. **Decisiones abiertas**: Premium vs free-to-play con demo; EN en el lanzamiento o después; reto diario online; Fuerza de fase 2 de jefes.
4. **Validación humana**: 3 partidas por musa, 1 tienda con mando, 3 eventos, 1 jefe con Irene; probar el cambio ES/EN a mano.
5. Confirmar: el tooltip de una ficha de estado ya no se cierra al jugar una carta que no cambia estados; el tooltip de controles bajos va encima; Pozo de Vida +18 (o 25 vía `pozo.hp` en el generador).

## Lo que FALTA (por valor)
1. **Muerte/historial en otro idioma**: `deathBy` guarda el nombre del enemigo, no el id (`scripts/core/meta.gd`). Guardar el id y traducir al mostrar.
2. **Balance**: Engranajes (Irene, 63 %) y Luz (Aurora, 61 %) algo sobre 60 % (exige tocar Precisión/Resplandor en el motor); Hivemind ~2 % de derrotas (cambiar patrón); cartas extremas listadas en `HANDOFF_AGENTE_E.md`.
3. **HUD de combate al 130 %**: `Main.SCREEN_MAX_TEXT_SCALE = {"combat": 1.0}`; rehacer `combat_screen`/`enemy_view` para escalar.
4. **Idioma en caliente** en combate/tienda/evento/recompensa/hoguera/favor: se aplica en la siguiente sala (con aviso); rehacerlas repetiría el reparto.
5. **Origen de la reliquia** (la ficha lo deduce de la rareza; guardar el real exige tocar `engine/`); cartas retiradas ya no salen en el Compendio.
6. **Coste de `_render_all`** tras jugar carta: 3–4,5 ms; `hp_bar.gd` (4 estilos por dibujo), `Main.update_top` ~0,33 ms. Detalle en `HANDOFF_AGENTE_D.md`.
7. **Reliquias/pociones sin test texto-vs-motor** (ídolo, tarjeta, huevo, pluma, cristal, estandarte, guantelete, colmillo_vibora, grimorio, muelle_doble; duplicar, herrero, gambito).
8. **Fase 5 restante**: Steam/nube, demo, pipeline de build reproducible (`tools/build_linux.sh` sin probar de punta a punta), soak de 50 partidas, B en portada sin «¿Salir?».
9. **Arte opcional**: iconos de categoría de logros, ilustración del Compendio.

## Comandos
```sh
godot --path .                       # jugar a mano (./jugar.sh)
godot --headless --path . --import   # si algo «no existe» en res://
python3 tools/make_cards_w1.py && python3 tools/make_content_w2.py   # regenerar datos
python3 tools/extract_content_loc.py --check ; python3 tools/extract_loc.py --check   # traducciones sin hueco
tools/build_linux.sh [release|debug]
```

## Reglas (no romper)
- Contenido/balance nuevo SOLO con `DB.extra=true`; datos base congelados por las 350 trazas. Editar el generador y regenerar, nunca el JSON.
- El español es el idioma fuente: la clave de `tr()` es el texto en español; traducciones en `translations/*.po`. Ids no cambian.
- Ningún texto se sale de su caja (`UIK.fit_*`, vigila `ui_layout_test` en es y en, 100/115/130 %).
- Un dueño por archivo con agentes en paralelo. Nunca `git checkout/restore` desde un agente.
- Tests con `ulimit -c 0`, `timeout` y `XDG_DATA_HOME` temporal. ComfyUI solo con `comfy-start`.
