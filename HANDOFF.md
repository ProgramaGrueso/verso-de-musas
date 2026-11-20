# HANDOFF · Verso de Musas · cierre de orquestación 2026-11-19 (noche)

Proyecto: `/home/juang/projects/IngenieriaInversa/VersoDeMusas-w2` (Godot 4.7.2).
Plan maestro: `ROADMAP.md`. Estado: **jugable de punta a punta** (`./jugar.sh`) y, desde esta sesión,
**sin los 4 bugs que reportó Juan al jugar** (commit `7f8c825`).

## ¿Qué se hace con los handoffs ya completados? (para Juan)

**No se borran.** Se mantienen como historial: explican *por qué* cada número es como es. Lo que sí se hace
cada cierre:
1. **Este HANDOFF.md se reescribe** y pasa a ser el único índice con lo que falta.
2. Los handoffs de fase ya cerrados dejan de actualizarse (solo se corrigen si dicen algo falso).
3. Cuando un handoff se vuelva ruido (p. ej. `HANDOFF_OLEADA2.md`), se puede mover a `docs/historial/` sin
   borrarlo. Decisión de Juan.

---

## Hecho en esta sesión: los 4 bugs de Juan (`7f8c825`)

Se orquestaron 4 subagentes en paralelo con **un dueño por archivo** (tienda, Irene/rendimiento, eventos,
tipografía). Todos los bugs tenían causa raíz identificada, no parches.

| Bug (lo que veía Juan) | Causa raíz | Arreglo | Test de regresión |
|---|---|---|---|
| **Tienda + mando**: al comprar «se bloquea todo, solo puedo salir» | `shop_screen._render()` liberaba la pantalla y pedía el foco antes de que el `Overlay` restaurara los `focus_mode`: el foco caía en la carta vieja (en cola de borrado) y el resto quedaba en `FOCUS_NONE` | `_grab_next/_grab_deferred` (fin de fotograma, nodo revalidado) + `Overlay.close()` restaura solo lo que apagó y no entra en modales anidados | `tests/shop_pad_test` (24/6 → **36/0**) |
| **Lenteo con Irene** (no era RAM/VRAM: idle a 145 fps) | `_popup`/`_burst`/anillos/trazos sin tope (Irene encadena 50–90 cifras por turno de REPETIR), `card_view.refresh` y `_layout_hand` reconstruyendo todo en cada golpe, `AtlasTexture` recargando la hoja, Sfx en ráfaga | PopLabel reciclado (contorno como textura), topes `POP_MAX`/`BURST_MAX`/`FX_CAP`, textura de partículas compartida, hitstop con reloj propio (sin `SceneTreeTimer` por golpe), repintado solo si cambia lo visible, atlas por fotograma en caché, idle a 3 fps, pool Sfx de 16 voces que roba a la más vieja | `tests/perf_budget_test` (5 fallos → **19/0**); sonda `tests/perf_irene` |
| **Eventos**: «los cuadros tienen mal tamaño» | Altura fija 78/54 px ignorando el texto, texto desanclado 2 px, `get_content_height()` leído antes del layout, columna sin límite de alto | Altura = texto + relleno, centrado vertical, columna que se escala si no cabe, vista de resultado igual | `tests/event_layout_test` (27 eventos + resultados: **2261/0**) |
| **Letras más grandes que su botón** | Ninguna pantalla medía el texto contra la caja del botón | `UIK.fit_button` (fuente real → baja hasta 12 px → partir por palabras → letra a letra → «…»), vigilante único `UIK.watch_tick()` desde `Main._process` (WeakRef, sin scripts en botones, nunca mide lo no dibujado), `UIK.wrap/fit_label/fit_title/button_row` + ajustes en título, selección, mapa, favor, cartas, barra superior, toast, tooltips | `tests/ui_layout_test` (42 pantallas + 19 diálogos × 1280×720 y 1600×900: **347 → 0**) |

**Extra de la misma sesión:** `_lethal_tip` ya no pierde líneas sin Osty; arranque sin
«Identifier not found» de autoloads; `Sfx.stop_fx()` solo silencia 320 ms tras cambiar de pantalla;
`reward_screen` crece al texto (no recorta 2 líneas en 76 px); se reimportaron los assets
(`.godot/imported` estaba incompleto: `spectralbosun.webp` fallaba).

### Números de rendimiento (misma máquina, `tests/perf_irene.tscn`)

| métrica | antes | después |
|---|---|---|
| nodos en `fx_layer` (media · pico) | 63,9 · 122 (hasta 182) | ~39 · 60 (tope 120) |
| números flotantes simultáneos | 51–93 | 14 (tope) |
| fotograma de ACCIÓN p95 | 4,64 ms | ~3,6–4,8 ms |
| `perf_budget_test` | 5 fallos | 19 ok |

---

## Estado de los tests (todo verde al cierre, 2026-11-19 noche)

```sh
godot --headless --path . --script tests/run_traces.gd       # 350 ok, 0 fallan
godot --headless --path . --script tests/risk.gd              # 892 comprobaciones, 0 fallan
godot --headless --path . --script tests/progress_test.gd     # 712 ok
godot --headless --path . --script tests/boss_phase_test.gd   # 6/6
godot --headless --path . --script tests/events_test.gd       # 143.302 comprobaciones, 0 fallan
godot --headless --path . --script tests/balance.gd -- 100 0  # victoria global 35-45 %
godot --headless --path . --script tests/save_test.gd
godot --headless --path . res://tests/ui_risk_test.tscn       # OK
godot --headless --path . res://tests/shop_pad_test.tscn      # 36 ok (mando en la tienda)
godot --headless --path . res://tests/perf_budget_test.tscn   # 19 ok (presupuesto de FX)
godot --path . res://tests/event_layout_test.tscn             # 2261 ok (cuadros de eventos)
godot --path . res://tests/ui_layout_test.tscn                # 0 fallan (texto en su caja)
godot --path . res://tests/ui_shot.tscn -- /tmp/ui 1280 720   # capturas a ojo
godot --path . res://tests/perf_irene.tscn -- irene 8 boss    # sonda de rendimiento
godot --path . res://tests/perf_probe.tscn -- irene 5 heavy   # sonda mínima (comparar commits)
```

> **En esta máquina** (`ulimit -c unlimited`, venv con 27 GB): los cierres de Godot con pantallas a medio
> construir dejaban core dumps de hasta 4,5 GB. Correr siempre con `ulimit -c 0` y, si el árbol está
> compilándose a la vez, esperar a `run_traces` antes de lanzar tests de ventana.

---

## Lo que FALTA (por valor)

1. **Fotograma de ~12 ms con Irene en el jefe** (`perf_irene`: aparece en 2 de 3 corridas). Se atacaron las
   causas que estaban en ese fotograma (mano, `_fit_text`, `_rebuild_intent`) y `fx_layer` ya no crece, pero
   el pico individual no quedó explicado. Siguiente paso: instrumentación fina por fotograma
   (`Time.get_ticks_usec` en `_layout_hand`, `CardView.set_text_once`, `EnemyView.refresh`, `Sfx._take_player`)
   en una build de ventana con `--print-fps`, para ver **cuál** de los cuatro se come el fotograma.
2. **Caché de la textura de partículas en `UIK.embers`** (hoy cada ráfaga fabrica una `Image` 16×16). Ya es
   redundante para `_burst` (usa `halo_tex()`), pero `Juice` y los emisores de fondo aún la usan.
3. **Ajustar el Escarabajo Real** (18,6 % de derrotas, objetivo 8–12): subir `shellCap` a 14 o bajarle PV en
   `tools/make_content_w2.py` y regenerar. Pequeño.
4. **Fase 2.3 Inspección + flecos de Fase 2**: clic en reliquia → tooltip (hoy solo hover); pilas con filtros;
   mazo consultable desde cualquier sala; hoguera con «6 → 9»; `tests/sfx_test.gd` (ningún sonido en silencio).
5. **Fase 2.4/2.5**: tutoriales por musa (Cuerda, orbes, Osty, Calor), **escala de texto**, remapeo de teclas y
   la **auditoría de mando completa** (la tienda ya está; falta mapa, recompensa, hoguera, eventos y un test
   de foco por pantalla reconstruida).
6. **Flecos de layout que el test marca como «posicionados a mano»** (no fallan, se salen un poco):
   `favor_screen` «Rechazar los favores», `enemy_view` nombre largo del Contramaestre Espectral,
   `combat_screen` rótulo «Poder N» de Osty y la insignia de pilas con 2 dígitos.
7. **Linux**: plantillas 4.7.2 (~1 GB en `~/.local/share/godot/export_templates/4.7.2.stable/`) → decidir y
   descargar Juan; luego probar el binario en ventana y en Deck.
8. **Arte restante (opcional)**: iconos de categoría de logros, ilustración del Compendio y retratos de los
   3 élites nuevos (hoy son copias de otro sprite).
9. **Fase 4 restante**: poda del pool con datos de elección del bot; 2 arquetipos viables por musa.
10. **Fase 5**: localización ES/EN (`tr()`), Steam/nube, demo, pipeline de build reproducible.
11. **Validación humana**: 3 partidas por musa (Fase 1.1), ritmo de desbloqueo y banda de Pesadilla 10 (~8 %).
    **Prioridad alta después de esta sesión**: los 4 bugs dan una lista corta y concreta de partidas que hacer
    a mano (una por musa, una tienda con mando, 3 eventos y un jefe con Irene).

## Decisiones abiertas (de Juan)
- Premium en Steam vs free-to-play con demo.
- ¿Localización EN en el lanzamiento o en una actualización?
- ¿Reto diario con marcador online desde el día uno?
- Fuerza de fase 2 de los jefes: hoy 0 (con Fuerza era un muro, 22 % vs 40 %).
- ¿Mover handoffs cerrados a `docs/historial/` o dejarlos en la raíz?

## Comandos
```sh
godot --path .                       # jugar a mano (./jugar.sh)
godot --headless --path . --import   # SI algo «no existe» en res://: el caché .godot/imported puede estar incompleto
python3 tools/make_content_w2.py     # tras editar contenido
python3 tools/gen_art_w3.py gen && python3 tools/gen_art_w3.py build   # arte (ComfyUI)
tools/build_linux.sh [release|debug]
```

## Reglas (no romper)
- Contenido/balance nuevo SOLO con `DB.extra=true`; los datos base están congelados por las 350 trazas.
- Editar el generador `tools/make_content_w2.py` (y `gen/jobs_art_w3.json` para arte) y regenerar; no tocar
  JSON/artefactos a mano.
- Calidad premium: sin placeholders. **Ningún texto se sale de su caja** (lo garantiza `UIK.fit_button` y lo
  vigila `tests/ui_layout_test`).
- Agentes en paralelo no deben tocar los mismos archivos (**un dueño por archivo**); si dos los necesitan,
  el dueño histórico manda y el otro describe el cambio.
- Nunca `git checkout/restore` desde un agente: hizo perder trabajo de la tarea de tipografía en esta sesión
  (se repuso). Los respaldos van a `/tmp/<tema>_bk_<hora>.*`.
- Tests en ventana y en headless con `ulimit -c 0` (si no, core dumps de GB) y `timeout` siempre.
- ComfyUI: encendido en :8188, compartido; no apagarlo. Solo se descargan **LoRAs** si falta un modelo
  (orden de Juan).
