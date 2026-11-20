# HANDOFF · Agente A · Fase 2.3 (Inspección + flecos)

Dueño exclusivo de: `scripts/ui/tip.gd`, `scripts/ui/dlg.gd` (vista de cartas / pilas / ficha de reliquia),
`scripts/ui/main.gd` (barra superior con reliquias, mazo), `scripts/ui/screens/rest_screen.gd` (hoguera),
`tests/sfx_test.*`, `tests/inspect_test.*`. Sin commits (los hace el orquestador).

## Hecho

### 4. Hoguera «PV 6 ➜ 9» — HECHO
- `scripts/ui/screens/rest_screen.gd`: la opción Descansar muestra en verde `PV <antes> ➜ <después>`
  (con tope en la vida máxima; con la vida llena, `PV 80 (ya al máximo)`; con Reloj Detenido no se muestra).
  El aviso tras descansar dice lo que de verdad se curó. `_big_opt` gana un 4.º parámetro opcional `note`.

### 5. `tests/sfx_test.gd` (+ `.tscn`) — HECHO
- Lee todos los `.gd` de `res://scripts`, saca los nombres literales pedidos a `Sfx.play`, `_play_sfx`
  y `_sfx` (incluye ternarios) y comprueba que existen en `Sfx._sounds` y que su onda tiene pico ≥ 0,05
  y rms ≥ 0,005. Repasa también todos los efectos sintetizados (cubre la llamada con nombre en variable
  de `combat_screen.gd:208`). Música: cada tipo de `Sfx.music` tiene pista en los 3 actos, cada musa
  tiene `menu_<musa>.ogg`, y cada pista que existe carga, dura ≥ 5 s, pesa ≥ 20 KB y no tiene ganancia 0.
- Resultado: 195 ok, 0 fallan. Mutación comprobada: un `Sfx.play("noexiste_mut")` añadido a mano lo marca.
- Avisos informativos (no fallan): `block` y `fire` existen pero ningún código los pide.

### 1. Clic / A en una reliquia → ficha — HECHO
- `scripts/ui/dlg.gd`: `Dlg.relic_info(id)` (modal: icono grande, nombre, origen, efecto, «Cerrar» con foco)
  y `Dlg.relic_origin(id)` (rareza + dónde sale + «Exclusiva de <musa>»; las iniciales nombran a su musa).
- `scripts/ui/main.gd`: clic izquierdo en una reliquia de la barra abre la ficha; en el modo inspeccionar
  (R3), **A** sobre una reliquia abre la ficha (sobre lo demás sigue saliendo de inspeccionar como antes).
  El tooltip de la reliquia añade «Clic o A (con R3): ficha y origen.». Ayuda (HELP) actualizada.
- Limitación: el juego no guarda dónde se consiguió cada reliquia en la partida; el «origen» es el de
  su rareza (inicial / común… / de jefe). Guardarlo exigiría tocar `engine/` (no es mío).

### 2. Pilas con filtros — HECHO
- `scripts/ui/dlg.gd` `view_cards`: con 6 cartas o más sale una barra de chips: `Todas N`, tipo
  (Ataque / Habilidad / Poder / Otras, solo los que hay), `Coste` 0/1/2/3+/X/— y `Mejoradas N`, más un
  contador `n / total`. Tipo y coste se combinan; repetir un chip quita su filtro; «Todas» lo quita todo.
  La rejilla es de alto fijo (436 px) para que nada salte al filtrar; el foco del mando se queda en el chip.
  En combate usa el coste efectivo (`Eng.eff_cost` con `C`). Vale para mazo, robo, descarte y agotadas
  sin tocar `combat_screen.gd` (que ya llama a `Dlg.view_cards`). Las mejoradas ya se marcaban (nombre
  verde con «+»).
- `_card_grid` gana `max_h` (por defecto 500, como antes).

### 3. Mazo desde cualquier sala sin romper el foco — HECHO
- `scripts/ui/main.gd`: `DECK_ROOMS` (mapa, combate, recompensa, tienda, hoguera, evento y favor),
  `can_open_deck()`, `open_deck_dialog()` ahora es un interruptor (M / Back / botón de la barra abren; con
  el mazo arriba, M o Back lo cierran) y **también se abre sobre un diálogo** (elegir carta en recompensa,
  hoguera, evento…). Si al cerrar el control que tenía el foco ya no existe, el foco pasa al primero
  enfocable de lo que quede arriba.
- `scripts/ui/dlg.gd`: `Overlay.lock_below` + `_lock_all`: el mazo abierto sobre otro diálogo apaga el foco
  de ese diálogo mientras está abierto y lo restaura al cerrarse (el D-Pad no se cuela debajo).
  `view_cards(..., deck := true)` lo activa; el resto de diálogos se comporta igual que antes.

### Encargo extra 1 · «¡Carta mejorada!» sin foco (Overlay.close encadenado) — HECHO
- `scripts/ui/dlg.gd` `Overlay.close`: tras `done.emit`, si el que espera abrió otro diálogo encima
  (`_live_overlay_above()`), los pares de `_locked` que no son de ese diálogo **se le pasan** (los restaura él
  al cerrarse) en vez de devolverles el foco ahora; y el foco previo se devuelve con `Dlg._focus_later(c)`
  (un fotograma después y solo si `c` está dentro del diálogo vivo de arriba). Se quitan `_reclaim_focus`/
  `_await_focus`. `focus_audit_test`: 479 ok, 0 fallan, **0 pendientes**.

### Encargo extra 2 · flechas «➜ → ← ↓ ▲ ▼ ✦ ↔ ↶» como recuadro — HECHO
- Noto Sans, Cinzel y NotoColorEmoji no traen esos glifos (salían como recuadro de glifo ausente).
  `assets/fonts/DejaVuSans.ttf` (+ `.LICENSE.txt`, licencia libre de Bitstream Vera/DejaVu) como reserva
  detrás del emoji en `UIK.font()` (`uik.gd`). Captura `06_comparar_mejora`: la «➜» grande ya se ve.

### Encargo extra 3 · Tamaño del texto — HECHO
- `uik.gd`: `UIK.text_scale` (estática) + `UIK.ts(size)`; `label`, `rich` y `button` multiplican su tamaño.
  `TEXT_SCALES = [1.0, 1.15, 1.3]`. `main.gd` `_ready` la copia de `Meta.settings.text_scale` (por defecto 1.0;
  `Meta._load_settings` ya acepta claves nuevas, no hizo falta tocar `meta.gd`).
- `dlg.gd` Opciones: fila «Tamaño del texto» (100 / 115 / 130 %, el elegido en verde). Al cambiarla el
  diálogo se rehace al momento (`_options_fill`) con el foco en el botón pulsado; si se está en la portada,
  al cerrar Opciones se rehace la portada. **El resto de pantallas toma el tamaño nuevo al abrirse**
  (lo ya construido no se reescala en caliente: decisión para no pelear con el auto-ajuste de botones/cartas).
- Las cartas siguen ajustando su texto a la caja (`card_view` encoge si no cabe).

### Encargo extra 4 · Remapeo de teclas — HECHO (teclado; el mando no se remapea)
- `main.gd`: `KEY_ACTIONS` (ver_mazo M, ayuda H, terminar_turno E, pocion_1..4 Q/W/R/T, robo D, descarte S,
  agotadas X, deshacer Z), `KEYS_RESERVED` (flechas, Tab, Enter, Espacio, Esc, 1–9, F1, F11, modificadores),
  `key_of/key_name/set_key/reset_keys`, `rebuild_keymap`. **Capa de traducción en `Main._input`**: la tecla
  elegida se reinyecta como la de defecto (`Input.parse_input_event`, marcada con meta `remapped`) y la de
  defecto que ya no es de nadie se traga. Así `combat_screen.gd` (prohibido) no se toca. No traduce con un
  LineEdit/TextEdit con foco, ni con Ctrl/Alt/Meta, ni dentro de Controles. Asignar una tecla ocupada
  intercambia. Se guardan solo las cambiadas en `Meta.settings.keys`.
- `dlg.gd`: Opciones ▸ «Controles · Teclado…» abre `Dlg.controls()` (rejilla de 11 acciones, pulsar y luego
  la tecla; Esc o B cancelan la captura sin cerrar; reservadas con aviso; «Restablecer»). La Ayuda (`HELP`
  con `{acción}` y `Dlg.help_text()`) muestra las teclas asignadas.

### Tests nuevos
- `tests/inspect_test.*` (87 checks, puntos 1-4), `tests/sfx_test.*` (punto 5).
- `tests/options_test.*` (31 checks): escala (130 % guarda, etiqueta 20→26, diálogo rehecho con foco, Opciones
  y Ayuda caben en 1280×720), remapeo de punta a punta (V abre el mazo, M libre no, intercambio H/V, ayuda con
  teclas nuevas, reservadas, LineEdit), diálogo Controles (captura G, Esc cancela, 2 rechazada) y combate
  (E libre no termina el turno, G sí). Guarda y restaura `user://settings.json`.
- `tests/scaled_run.*`: corre otro test con otra escala sin guardar ajustes:
  `godot --headless --path . res://tests/scaled_run.tscn -- 1.3 res://tests/flecos_layout_test.tscn`
- `tests/inspect_shot.*` (necesita ventana): capturas 01–08 (ficha, mazo con filtros, hoguera, mejora, Opciones
  y Controles al 130 %). Espera fotogramas en vez de `frame_post_draw` (en Wayland se queda colgado tras
  cambiar de pantalla, también en HEAD limpio).

## Verificación
```sh
cd /home/juang/projects/IngenieriaInversa/VersoDeMusas-w2 && ulimit -c 0
timeout 120 godot --headless --path . --quit                              # arranca sin errores de script
timeout 300 godot --headless --path . res://tests/inspect_test.tscn       # 87 ok, 0 fallan (1-4)
timeout 120 godot --headless --path . res://tests/sfx_test.tscn           # 195 ok, 0 fallan (5)
timeout 300 godot --headless --path . res://tests/options_test.tscn       # 31 ok, 0 fallan (escala + remapeo)
timeout 300 godot --headless --path . res://tests/focus_audit_test.tscn   # 479 ok, 0 fallan, 0 pendientes
timeout 200 godot --headless --path . res://tests/shop_pad_test.tscn      # regresión
timeout 200 godot --headless --path . res://tests/hand_stagger.tscn       # regresión
```

## Resultado de regresión (2026-11-20)
- `--quit`: 0 errores de script. A 1.0: options 31/0, inspect 87/0, sfx 195/0, shop_pad 36/0, hand_stagger 0 fallan,
  focus_audit 479/0/0 pendientes, event_layout 2261/0, flecos 66/0, history OK, save OK.
- Con `scaled_run` a 1.15 y 1.3: flecos 66/0, event_layout 2261/0, inspect 87/0, shop_pad 36/0, focus_audit 479/0.

## Pendiente / decisiones (para Juan)
- **Tope por pantalla** (`Main.SCREEN_MAX_TEXT_SCALE`): el HUD del combate se construye siempre al 100 % (insignias
  de pila, enemigos y orbes son de tamaño fijo: a 1.15 los números se salían, flecos 13 fallos) y los eventos a
  115 % como máximo (a 130 % 8 eventos no cabían en su columna, event_layout 44 fallos). Diálogos, tooltips y
  cartas sí siguen el 130 %. Para quitar el tope habría que rehacer esos HUD (`combat_screen.gd`/`enemy_view.gd`,
  prohibidos, y `event_screen.gd`).
- La hoguera ensancha sus dos opciones con la escala (la nota «PV 6 ➜ 9» a 130 % se salía 18 px).
- El cambio de tamaño se aplica a cada pantalla al abrirse (Opciones y la portada, al momento).
- Previo, no mío: `focus_reach` falla en la pantalla de selección («Semilla»/«Comenzar» inalcanzables) igual en
  HEAD. Al salir, «2 resources still in use» (pista `menu_*.ogg` de `Sfx`): también en HEAD con mis archivos
  revertidos.
- El «origen» de la ficha de reliquia es por rareza: guardar dónde se consiguió exigiría tocar `engine/`.
