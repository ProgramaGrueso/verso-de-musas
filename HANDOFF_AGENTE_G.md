# HANDOFF · Agente G · layout de texto en cartas, diálogos y pantallas restantes

Dueño exclusivo de: `scripts/ui/card_view.gd`, `dlg.gd`, `tip.gd` y `scripts/ui/screens/` ending, shop, gallery,
daily, history, end, favor, map, event. Sin commits. Respaldos de partida: `/tmp/claude-1000/…/scratchpad/agG_bk/`.

Línea base (`ui_layout_test` con ventana, 6 pasadas): 11 959 ok, 71 fallan (card_view 40, ending 9, daily 5,
shop 4, history 4, end 3, favor 3, dlg 1, map 1, gallery 1).

## Hecho, pantalla a pantalla

### card_view.gd (40 → 0)
- **Causa del cuerpo cortado:** el commit 7f8c825 dejó la banda de tipo `title_h` px por debajo del arte, con una
  franja vacía entre ambos; el cuerpo de una carta de 148 px quedaba en ~32 px (2,5 líneas). Además `_fit_text`
  medía contra `_txt_box.size.y`, que ya había crecido con el texto grande, así que siempre «cabía» y la fuente
  no bajaba.
- Banda otra vez a caballo del borde del arte (como antes de 7f8c825): cuerpo de ~66 px en 148 px.
- `_box_h`: alto de diseño de la caja; `_fit_text` y `_fit_key` miden contra él. `_shrink_box()` devuelve el VBox
  a ese alto cuando la fuente baja (conectado a `minimum_size_changed`). Sin trabajo por fotograma nuevo.
- Rótulo de tipo y coste con tamaño fijo (sin `UIK.text_scale`): la carta es un gráfico fijo; al 130 % se salían
  de su franja / círculo.

### dlg.gd (1 + los «pisa» de card_view en dlg_pick_muchas → 0)
- La vista previa «Mejorada ➜» flotaba sobre las cartas vecinas y la ayuda. Ahora `pick_cards` con
  `upgradePreview` pone la rejilla más estrecha (`PEEK_GRID_W` 916 → 5 columnas) y un hueco fijo
  (`PEEK_SLOT` 230×420) a su derecha; `_upgrade_peek(slot, …)` pinta ahí, a la altura de la carta señalada.
- `_card_grid` acepta `max_w` (por defecto 1160, el valor de siempre).

### ending_screen.gd (9 → 0)
- La fila de controles va anclada abajo a la derecha y crece hacia arriba/izquierda con la escala de texto;
  `_place_text()` (conectado a `resized` de la fila) deja el texto justo encima y `UIK.fit_label` lo encoge si
  la frase no cabe en su caja (antes los botones salían por abajo y pisaban el texto).

### shop_screen.gd (4 → 0)
- `_fit_root()`: el título pasa por `UIK.fit_title(…, 860, 22)` y, si la columna pasa de y=712, cede por pasos
  (un fotograma cada uno): separación 4 → botón «Salir» a `ts(24)` con márgenes 10/28 → título más pequeño.

### history_screen.gd (4 → 0) y gallery_screen.gd (1 → 0)
- `HistoryScreen.fit_head(title, sub, 76)` (estático, lo usa también la galería): el título encoge (mín. 20)
  hasta que título + subtítulo caben en la cabecera, que ya no pisa la lista.
- Galería: títulos de casilla con `fit_title(…, 266, 13)`; en casillas bloqueadas, si pista + barra + cuenta
  no caben, cede el arte (150 → mín. 96 px); el icono del candado sigue centrado en el arte.

### daily_screen.gd (5 → 0)
- «Revancha de este día» + «Copiar reto» (fuente `ts(20)`) ensanchaban la columna de 506 px fuera de la tarjeta
  al 130 %: los dos bajan de fuente a la par (mín. 14, `fit_base` fijado) hasta caber. No se apilan: no hay alto.

### end_screen.gd (3 → 0)
- `_fit_col()`: la columna centrada pasaba de 720 px (resumen largo + logros) y la fila «Revancha / Copiar
  resumen / Logros» salía por abajo. Cede la separación (18 → mín. 8) y luego el titular «¡VICTORIA!» (mín. 40).

### favor_screen.gd (3 → 0)
- Carta: el bloque de texto (118 px) baja la descripción hasta `ts(15)`, luego sube sobre el arte sombreado
  (hasta y=96, sin tapar la cinta) y solo entonces sigue bajando la fuente (mín. `ts(13)`).
- La frase del ente empieza bajo el alto real del nombre (antes lo pisaba 7 px) y `fit_label` si no cabe.

### map_screen.gd (1 → 0)
- La ayuda de mando empieza bajo el alto real de la columna ▲/Aquí/▼ (al 130 % «▼» la pisaba).

### tip.gd (aviso del agente F)
- Fuente según la escala de texto actual (antes medía a 15 px y pintaba a `ts(15)`); ancho máx. 330 px × escala
  (tope 440).
- Parte por palabras; letra a letra solo si una palabra sola no cabe (antes «a vec / es» en cuanto era ancho).
- Anclado a un control de la parte baja (centro > 60 % del alto), el tooltip va encima si cabe: el del avatar
  enfocado ya no tapa «Semilla» (ahora roza el final de «…desbloquear su Pesadilla», texto no interactivo).

### event_screen.gd + main.gd: fuera el tope del 115 % en eventos
- `main.gd:31`: `SCREEN_MAX_TEXT_SCALE` queda `{"combat": 1.0}` (el combate no se ha tocado).
- `EventScreen.COL_POS` / `COL_SIZE` / `ART_RECT` pasan de `const` a `static var` (el test los lee igual) y
  `_layout_for_scale()` los fija al construir: al 100 % nada cambia (700,96 · 530×560, arte 610 px); al 130 %
  columna 620,96 · 620×594 (pie en SAFE_BOTTOM 690) y arte 530 px; interpolado entre medias.
- `event_layout_test` vía `scaled_run`: 1.0, 1.15 y 1.3 → 2261 ok / 0 fallan cada una.

## Verificación final
- `ui_layout_test` completo (6 pasadas, ventana): **12 233 ok, 0 fallan** (línea base 71 fallos).
- focus_reach 56/0 · shop_pad 36/0 · focus_audit 484/0/0 · flecos 66/0 · hand_stagger 0 fallan · options 31/0 ·
  inspect 87/0 · perf_budget 19/0.
- Arranque `--headless --quit`: sin errores de script (solo el ruido de salida «resources still in use», ya en HEAD).

## Pendiente / decisiones para Juan
- Tooltip anclado de la selección: ahora va encima del avatar y roza el final de «…desbloquear su Pesadilla»
  (texto, no botón). Si se prefiere otro sitio (p. ej. a un lado), es `Tip._place()`.
- Favor al 130 %: la descripción de «Vigor a cambio de oro» baja a `ts(15)` y sube un poco sobre el arte.
- Al 130 % el arte del evento estrecha de 610 a 530 px para darle ancho a la columna.
- Sin commits: todo queda en el árbol de trabajo.
