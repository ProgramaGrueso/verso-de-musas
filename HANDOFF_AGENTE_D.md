# HANDOFF agente D: rendimiento del combate (2026-11-20)

Archivos tocados (solo míos):
- scripts/ui/screens/combat_screen.gd
- scripts/ui/card_view.gd
- scripts/ui/enemy_view.gd
- scripts/core/sfx.gd
- tests/perf_irene.gd
- tests/perf_cards.gd y tests/perf_cards.tscn (nuevos)

No hay commit ni add.

## Causa del fotograma de ~12 ms

En Hyprland/Wayland a 144 Hz los fotogramas se cuantizan al vblank (~6.9 ms), incluso con `VSYNC_DISABLED`. Cualquier fotograma con más de ~6.9 ms de trabajo pierde el vblank y sale en ~13.8 ms: ese es el "tirón de 12 ms".

El trabajo de GDScript que lo provocaba:

1. **CardView._build creaba siempre el emoji de reserva del arte** (`_ph`, una etiqueta de 56 px), aunque la carta tuviera arte y la etiqueta estuviera oculta.
   - Maquetar un emoji (NotoColorEmoji de reserva) cuesta ~4-8 ms; una etiqueta de texto, ~0.1 ms.
   - Medido con perf_cards (LABEL): el emoji tarda ~4.4 ms frente a 0.11 ms de "A".
   - Con 2 cartas por fotograma en cada reparto, eso era casi todo el pico.
2. **Repintados que re-maquetaban sin cambios.** Cada repintado volvía a poner StyleBox y tamaños de fuente con el mismo valor, y cada override notifica un cambio de tema y re-maqueta las etiquetas hijas. Además recreaba la sonda de ajuste del texto y rehacía todas las fichas de estado de la jugadora y de los enemigos.
3. **Retrato de fase 2 del jefe** cargado con `load()` síncrono en el golpe que abre la fase: ~4 ms en el mismo fotograma del rótulo y la sacudida.

## Arreglos (archivo:línea)

**scripts/ui/card_view.gd**
- `card_view.gd:110`: `_ph` se crea solo si `t == null` (la carta no tiene arte). Visualmente es lo mismo: antes se creaba y se ocultaba cuando había arte.
- `card_view.gd:44`: `static var _fit_cache` (texto + caja → tamaño de fuente; se vacía al pasar de 4000 entradas).
  - `_fit_key` (`:444`) y `_set_body_fs` (`:449`, que solo cambia el override si el tamaño es otro).
  - `_fit_text` (`:379`) consulta la caché antes de crear la sonda.
  - `_refresh_text` (`:242`) no toca el cuerpo si el texto es el mismo y ya está ajustado. Si la caché conoce el tamaño, lo pone directamente sin pasar por el diferido.
- `_style_key` (`:40`): el StyleBox de la banda de tipo (`:268`), del marco (`_apply_frame`, `:291`) y del coste (`_set_cost_style`, `:367`) solo se reasigna si cambia.
  - `_refresh_text` pone ya el estilo de coste vigente (`_unaffordable()`, `:466`). Así desaparece el ida y vuelta "pagable → no pagable" en cada repintado.
- El color del nombre solo se reasigna si es distinto (`:265`).

**scripts/ui/enemy_view.gd**
- `_rebuild_status` (`:251`) solo rehace las fichas si cambia `status_sig()` (`:270`, firma estática `k:v`).
- Retrato de fase 2:
  - `:161-166`: se pide en segundo plano con `load_threaded_request` al montar la vista de un jefe.
  - `_check_phase2` (`:235`) lo recoge con `load_threaded_get`; si no hay petición, recurre a `UIK.tex` como antes.
  - `_exit_tree` (`:169`) recoge la petición si no llegó a usarse, para que el cargador no la retenga.

**scripts/ui/screens/combat_screen.gd**
- `_update_player` (`:1083`, firma en `:98`): las fichas de estado de la jugadora solo se rehacen si cambia la firma.
  - Efecto lateral, para bien: el tooltip abierto de una ficha ya no se cierra al jugar una carta que no cambia estados.
- `:581`: comentario obsoleto de `_burst` corregido. `UIK.embers` ya usa `ember_tex()` en caché.

**Marcas de perfil (UIK.prof_t / prof_add)**, apagadas por defecto y de coste cero (`prof_t()` devuelve 0 y `prof_add` sale enseguida):
- combat_screen: `_process`, `_popup`, `_burst`, `_banner`, `_fx`, `_render_all`, `_update_player`, `_update_enemies`, `_update_hud`, `_sync_hand`, `_layout_hand`.
- card_view: `_build`, `set_text_once`, `_refresh_text`, `set_state`, `set_selected`, `_fit_text`.
- enemy_view: `refresh`, `_rebuild_status`, `_rebuild_intent`.
- sfx: `play`, `_take_player`.

## Mediciones antes / después

**Comparación A/B.**
- "Antes" es una copia de HEAD (4975c30) con el mismo `data/balance_w2.json` y el mismo `tests/perf_irene.gd`; "después" es el árbol actual.
- Las ejecuciones se alternaron (base, actual, base…) para repartir por igual la carga de otros agentes (load average entre 3 y 8).
- Ventana 617×326, 144 Hz, RTX 4070 Ti SUPER.
- La línea TOTAL es la métrica justa: todos los fotogramas del escenario, cada jugada y su asentamiento.

| Escenario | Antes: ms/fotograma (fps) | Después: ms/fotograma (fps) |
|---|---|---|
| irene boss, 3 ejecuciones | 32.6 / 18.8 / 18.6 (31 / 53 / 54) | 7.35 / 7.43 / 7.28 (136 / 135 / 137) |
| irene normal | 17.3 (58) | 6.86 (146) |
| irene élite | 17.3 (58) | 6.82 (147) |
| irene boss (dentro de "todo") | 18.2 (55) | 8.19 (122) |
| zafiro normal | 16.3 (61) | 6.82 (147) |
| zafiro élite | 13.5 (74) | 6.86 (146) |
| zafiro boss | — (no se imprimió) | 7.83 (128) |
| selene, los 3 tiers | 6.9-7.2 (139-145) | 6.89-6.95 (144-145) |

Selene no cambia porque apenas reparte cartas en el escenario.

Coste por llamada con `VDM_PROF=1`. Las cifras de "antes" se tomaron con marcas puestas sobre el código antiguo, con carga alta de otro agente.

| Función | Antes | Después |
|---|---|---|
| CardView._build | 7.67 ms | 0.49 ms |
| CS._sync_hand (total del escenario) | 392 ms | 51 ms |
| CS._render_all | 10.7 ms | 2.4 ms |
| CardView._fit_text | 0.88 ms | 0.12 ms |
| CS._update_player | 1.44 ms | 0.47 ms |
| EnemyView.refresh | 0.66 ms | 0.23 ms |

`perf_cards` (create + add, 40 cartas): p50 6.19 ms antes, 1.81 ms después.

**Fugas.** La línea ASENTADO de perf_irene mide los objetos 2.5 s después de cada combate.
- Vuelven a ~+90 sobre el inicio en el árbol actual y a ~+3-27 en la base.
- El arranque entre combates crece igual en los dos (+4, luego +40). No hay acumulación por combate.
- Al final de la medida hay más objetos vivos en el árbol actual (~4800 frente a ~3000), pero es porque el combate entero dura 0.5 s en lugar de 2.4 s y los efectos se solapan. Al asentarse, se liberan.

**Lo que queda.**
- Los fotogramas de acción (justo tras `_play_step`) siguen costando 3-4.5 ms de `_render_all`: `_sync_hand` con 2 `_build` más `_rebuild_intent` cuando cambia el daño.
- Con carga alta todavía saltan 1-3 de 24 fotogramas de >8 ms en irene/boss. Es la línea VBLANK; en la base eran 2-3.
- La sonda juega una carta cada 3 fotogramas, mucho más rápido que una persona.

## Probado y descartado (sin ganancia medible)

- **Degradados de CardView compartidos** (`static` caché de `GradientTexture2D`): perf_cards p50 1.810 → 1.795 ms, ruido. Revertido.
- **Unificar `halo_tex()` con `UIK.ember_tex()`:** las dos ya están en caché, así que el ahorro es una textura de 16×16 una vez por sesión. Además, el alfa puede diferir en 1/255 (redondeo frente a truncado). No se toca.
- **`UIK._watch`:** `watch_tick` ya poda los WeakRef muertos cada 3 fotogramas. No hay fuga.
- **`Sfx._take_player`:** 0.002 ms por llamada. Despreciable.
- **`_layout_hand` con `animate=true`** recrea el tween incluso para cartas ya colocadas: 0.043 ms por llamada. No compensa.

## Para otros dueños (no tocado)

- **`Main.update_top`** (main.gd): ~0.33 ms por repintado.
- **`hp_bar.gd`:**
  - `_draw` crea 4 StyleBoxFlat en cada dibujo.
  - `set_values` mata y recrea 2 tweens en cada llamada, aunque los valores sean iguales. Un `if hp == _hp and max == _max: return` lo evitaría.
- **Emojis en `UIK.label`:** cualquier etiqueta con emoji cuesta ~4 ms de maquetado la primera vez. Conviene evitarlos en lo que se crea a menudo.
- **Cuantización por vblank en Wayland:** a 144 Hz, todo fotograma de más de ~6.9 ms se ve como ~13.8 ms.

## Comandos

```
ulimit -c 0
# escenario con la línea TOTAL / VBLANK / ASENTADO / REPARTO / RENDER (ventana)
godot --path . --print-fps res://tests/perf_irene.tscn -- irene 8 boss      # o: <musa> <segs> todo [sfx] [nocap]
# con perfil por función (imprime los fotogramas de más de VDM_PROF_MS ms)
VDM_PROF=1 VDM_PROF_MS=9 godot --path . res://tests/perf_irene.tscn -- irene 8 boss
# microbanco de creación de cartas y de etiquetas emoji frente a texto
godot --path . res://tests/perf_cards.tscn -- 40
```

`perf_irene` admite estas banderas:
- `sfx`: activa el sonido a 0.6.
- `nocap`: sube el tope de fx.

Novedades de `perf_irene`:
- Líneas TOTAL, VBLANK y ASENTADO.
- Línea REPARTO: proceso, dibujo y swap.
- Línea RENDER: CPU y GPU del render.
- Las líneas de tirón incluyen ahora número de fotograma y reparto.

## Verificación

- `godot --headless --path . --quit`: sin errores de script. Queda "2 resources still in use", que ya estaba en HEAD (según el agente C).
- Tests a 0 fallos:
  - perf_budget_test: 19 ok
  - hand_stagger: 0 fallan
  - shop_pad_test: 36 ok
  - focus_audit_test: 479 ok
  - flecos_layout_test: 66 ok
  - options_test: 31 ok
  - inspect_test: 87 ok
  - event_layout_test (ventana): 2261 ok
