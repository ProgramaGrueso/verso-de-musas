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
1. ~~Muerte/historial en otro idioma~~ HECHO (`ad54dc4`): `deathBy` guarda ids, `DB.death_by_text` traduce al mostrar.
2. **Balance** (2026-11-20, `6dd5a58`, `d96ba9d`): Hivemind 3,2→5,3 % de derrotas (ciclo de 6, Golpe 28); Engranajes 63→55 % y Luz 61→59 % (`gear_bonus`/`glow_cut` en `eng.gd`, solo `DB.extra`). Resta: cartas extremas de `HANDOFF_AGENTE_E.md`; Lia|cuchillas (34,6 %) es el arquetipo más justo.
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

## Pendiente para otra sesión (anotado 2026-11-20)
- **Tamaño del export Linux (520 MB de .pck, ~566 MB total).** `tools/build_linux.sh release` ya funciona de punta a punta (plantillas 4.7.2 instaladas). Medido por Haiku: assets/ pesa 105 MB crudos (webp 57 MB, ogg 40 MB, png 30 MB) pero .godot/imported tiene 862 MB de .ctex (BPTC con mipmaps): un webp de 1,6 MB (`zafiro_idle`) da un .ctex de 18,7 MB; los sprites *_idle/_die/_attack_heavy/_hurt/_cast de las 4 musas pesan 12-13 MB cada uno. El preset ya excluye gen/tests/tools/*.md.
  - Experimento propuesto (Sonnet, en copia del proyecto): sprites sin mipmaps y/o compresión con pérdida o menor resolución en el import; medir el .pck y comparar capturas antes/después (regla: premium, sin degradar el arte). Estimación sin medir: 150-250 MB.
  - Opcional: recomprimir los .ogg de música (~15-20 MB menos).
- **Carta de Irene de coste 3 con «texto basura»** que Juan vio jugando: no reproducida; Obra Maestra, Perpetuum Mobile y Autómata Colosal generan texto correcto en ES/EN. Falta nombre/captura/idioma.
- **Hecho hoy:** perfil real reiniciado (copia en ~/automation/backups/verso-perfil-2026-11-20), plantillas Linux instaladas, precio decidido (10 USD, 5 USD el primer mes).


## Balance: escalera de dificultad (2026-11-20)
Juan jugó el normal y lo sintió en ~10/100. Solo con `DB.extra` (trazas intactas). Generador: `tools/make_content_w2.py` (`NM_BASE`, `NM_STEPS`, textos en `NM_TEXTS`).
- **Base (nm0) endurecido**: `nm_base` en balance_w2.json (`nm_mods(0)` lo devuelve con extra): PV enemigos x1.04, daño x1.05, élites +10 % PV. Bots: 41 % -> ~24 % global; todas las musas con algún arquetipo >= 20 %.
- **Escalera nm1..nm10** (acumulativa, 1-3 cambios por paso): daño/PV enemigos, oro -15 %, élites con Fuerza y Bloqueo inicial, 2 ranuras de poción, Herida por combate, hoguera 22 %, Duda, jefes con Fuerza y Bloqueo, PV máx. -2 %, 1 ranura de poción, élites Fuerza 2.
- Claves nuevas en `eng.gd` (`nm_mods`): `eliteHp`, `bossHp`, `eliteBlock`, `bossBlock`, `plHp`, `pots`, `wound` ahora es un número de Heridas.
- Simulador paralelo (bots, N=400/musa): 24 -> 20 -> 17 -> 13 -> 11 -> 9,6 -> 7 -> 4,6 -> 3,2 -> 2 -> 1 %. Con 11 niveles x 6 musas, `godot --headless ... balance.gd -- N <nivel> <musa> <semilla>` en paralelo tarda ~1 min por N=300.
- **La calibración final depende de que Juan pruebe a mano** (un humano gana mucho más que el bot). Si aún es fácil, subir `NM_BASE` (hp/dmg) o eliteStr/bossStr y regenerar.
- UI pendiente (no tocada): el selector de Pesadilla (`select_screen.gd:302`) muestra `DB.nm_texts[nm]` y «(y los niveles anteriores)»; con 1 ranura de poción y PV máx. menores conviene comprobar a mano la barra de pociones.
- `tests/nm_test.gd` ahora admite 1-3 cambios por paso y comprueba las claves nuevas.

## Validación a mano (Juan, 2026-11-20)
- Partida normal (nm0) con la musa de las orbes: «más difícil», ganó con 1 PV. Parte de la dificultad vino de su propia elección de evento (renunciar a curarse en hogueras por un bono) y llegó al jefe golpeado, con el aviso de muerte segura encendido. Base nuevo (PV ×1,04, daño ×1,05, élites +10 % PV) validado en una partida.
- **Siguiente prueba:** una partida normal «limpia» (sin riesgos opcionales) con otra musa (Zafiro es la más débil en bots) y una con Irene. Si sigue cómoda, subir `NM_BASE` o Fuerza de élites/jefes en `tools/make_content_w2.py` y regenerar. Mirar también la barra de pociones con 1-2 ranuras (nm5+) y confirmar que el lag de la mano con muchas cartas desapareció (arreglo `9602edb`, medido solo en headless).
- Tests de foco (`focus_audit_test`, `focus_reach`) dependen de esperas por tiempo: dan falsas alarmas con la máquina cargada. Correrlos con la máquina libre y, si se puede, hacerlos robustos.

