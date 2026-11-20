# HANDOFF · Agente F · layout de texto, mando en título/selección/logros/compendio

Dueño exclusivo de: `tests/ui_layout_test.*`, `tests/focus_reach.*`, `tests/ui_shot.*`, `tests/isolated_run.gd` (nuevo),
`scripts/ui/screens/select_screen.gd`, `title_screen.gd`, `achievements_screen.gd`, `compendium_screen.gd`,
`scripts/ui/medal.gd`, `scripts/ui/unlock_banner.gd`. Sin commits. Respaldos previos: `/tmp/agF_bk/*.0045`.

## 1. `ui_layout_test` — HECHO
**Por qué daba «0 ok, 0 fallan»:** el contador `oks` no se incrementaba nunca y `_fail` se tragaba en silencio
los fallos de la tienda, de las etiquetas de diálogos (`dlg_`) y de la portada con racha. Medía, pero no contaba.

**Test nuevo** (`tests/ui_layout_test.gd`, reescrito):
- 6 pasadas: texto 100/115/130 % (`UIK.text_scale`) × ventana 1280×720 y 1600×900 (sin ventana, solo 1280×720).
- ~59 estados de pantalla (incluida la selección con cada musa, con y sin Pesadilla) + 24 diálogos/extremos
  + 3 avisos de desbloqueo. Con ventana: 354 pantallas y 144 diálogos/avisos medidos, ~12 000 comprobaciones.
- Mide con la fuente real (`TextParagraph` con fuente, tamaño y modo de partir línea del control).
- Falla si un texto se sale de la pantalla, de su padre o de su caja visible (botón, panel, carta); si no cabe
  en su botón; si un Label recorta con «…» u oculta líneas; si un RichTextLabel sin scroll se corta; si la
  fuente de un botón baja de 12 px; si el texto de un botón invade a un hermano o la barra superior.
- **Nuevo:** textos de bloques distintos de la pantalla que se pisan (compara la tinta, no el rect). Así salió
  el subtítulo de la cabecera de Logros/Compendio sobre las pestañas al 130 %.
- **Canario:** antes de medir monta una pantalla con 6 textos rotos a propósito; si alguno no se marca, falla.
- **Mutación comprobada:** pie de la portada movido 10 px hacia abajo → 3 fallos «se sale de la pantalla 7 px»
  y salida 1. Quitado: 42 ok, 0 fallan.
- Sale con código 1 si hay fallos. Cada fallo dice: pasada, pantalla, archivo dueño, control y medida.
- **Perfil aislado:** se relanza con `XDG_DATA_HOME=/tmp/vdm_ui_layout`, mediante `tests/isolated_run.gd`.
  Verificado: el `meta.json` de Juan no cambia. Si `timeout` mata al padre, el hijo sale solo, porque vigila
  `/proc/<pid>` del padre.
- Con `shots DIR` ya no espera `frame_post_draw`: en Wayland se colgaba, y un hijo se quedó 3 h colgado. Lo maté.

```sh
cd /home/juang/projects/IngenieriaInversa/VersoDeMusas-w2 && ulimit -c 0
timeout 900 godot --path . res://tests/ui_layout_test.tscn                 # completo con ventana (~80 s)
timeout 600 godot --headless --path . res://tests/ui_layout_test.tscn      # solo 1280x720 (~40 s)
# opciones tras --: scale 1.3 · window 1600x900 · only <etiqueta> · shots DIR · verbose
```

**Arreglado en mis pantallas** (lo que marcaba el test):
- `select_screen.gd`:
  - La fila inferior salía 4/11/16 px por abajo (y hasta 141 px por la derecha con la semilla larga al 130 %).
    Ahora `_place_rows()` coloca de abajo arriba: fila de botones a 8 px del borde, avatares encima y el
    bloque de Pesadilla encima. La ficha de la musa sube (hasta y=30) y, si aún no cabe, encoge el nombre
    decorativo (92 → mín. 60).
  - `_fit_bottom()` encaja la fila en 1200 px: primero acorta la semilla, luego encoge la fuente de
    «Modo fácil» y la de «Semilla» (mín. 14).
  - Ficha a 640 px de ancho (antes 560). El nombre de la musa no crece con el tamaño de texto.
  - «Modo fácil» usa `UIK.ts(20)`.
  - Los hijos viejos se sacan del árbol antes de rehacer, para que no cuenten en el alto.
- `title_screen.gd`:
  - «Salir» salía 28–47 px al 130 %. `_fit_column()` comparaba con `col.size.y`, que ya había crecido, así
    que nunca encogía nada. Ahora compara con 720: cede el logo (hasta 40), luego el aire entre botones y
    luego el relleno vertical de los botones.
  - El botón «big» usa `UIK.ts(26)`.
  - La firma de la musa crece hacia arriba desde su pie: al 130 % pisaba el aviso de Pesadilla.
- `achievements_screen.gd` (Maestría): el bloque de texto de cada musa se apoya abajo y crece hacia arriba.
  El texto de puntos parte en líneas y el nombre y el rango encogen si hace falta. Antes salía 6–72 px del
  panel, que recorta.
- `medal.gd` `chrome()`: título y subtítulo caben en los 70 px de la cabecera. Cede el título, que es
  decorativo; el subtítulo pisaba las pestañas del Compendio al 130 %.
- `unlock_banner.gd`: sin cambios. Lo que marcaba (dos avisos montados) era un artefacto de la prueba, que se
  saltaba la cola; ahora mide solo el aviso pedido.

**Resultado final con ventana (6 pasadas):** 12 020 ok, 75 fallan. **0 en mis archivos.** Los 75 son ajenos;
no los he tocado y van en la tabla siguiente.

### Fallos en archivos ajenos (pantalla · escala · control · medida)
| archivo | pantalla | escala | control y medida |
|---|---|---|---|
| card_view.gd | compendio zafiro/aurora/neutral, shop_oro_largo | 100/115/130 | descripción RichTextLabel se sale 6–13 px por abajo de la carta (148×211 / 142×202), p. ej. «Obtén 12 de Bloqueo. Quien te ataca recibe 4…», «Inflige 9 de daño. Si el enemigo tiene Respl…». Visible en captura: la última línea queda cortada |
| card_view.gd | shop, shop_oro_largo | 130 | rótulo de tipo «HABILIDAD»/«ATAQUE» 4 px más alto que su franja (Panel 112×13) |
| card_view.gd | dlg_pick_cards | 130 | coste «1» 2 px fuera de su Panel 56×54 |
| card_view.gd + dlg.gd | dlg_pick_muchas (comparar mejora) | 100–130 | nombre/tipo/descripción de la carta «antes» pisan a la carta «Mejorada ➜» (6–87 px); la ayuda «Pasa el ratón…» pisa «Mejorada ➜» 5 px (dlg.gd) |
| ending_screen.gd | ending | 100/115/130 | «Saltar», «Automático: sí», «Siguiente ▶» salen 6/11/16 px por abajo (y=668, alto 58–68) |
| shop_screen.gd | shop | 115/130 | «Salir de la tienda ➜» sale 18/41 px por abajo |
| end_screen.gd | end_victory_larga | 130 | «Revancha», «Copiar resumen», «Logros» salen 8 px por abajo |
| gallery_screen.gd | gallery | 115/130 | títulos de los marcos («La Capitana de la Marea Baja», «Capítulo 5») se salen 24–80 px del botón 290×252; «← Volver» sale 12 px por la derecha al 130 % |
| favor_screen.gd | favor | 130 | texto de la opción se sale 4–17 px del botón (372×280 / 392×295); nombre de la entidad pisa la frase 7 px |
| daily_screen.gd | daily_pasado | 130 | el contenido del panel 550×600 se sale 12 px por la derecha |
| history_screen.gd | history | 115/130 | «N partidas empezadas · …» pisa el título «Por musa» 6–15 px |
| map_screen.gd | map | 130 | botón «▼» pisa la ayuda «Mando · X: centrar…» 4 px |

## 2. `focus_reach` — HECHO (0 fallos)
- Causa: en `_wire_bottom()` «Modo fácil» no tenía vecino derecho, así que la búsqueda geométrica subía a los
  avatares y «Semilla» y «Comenzar» no se alcanzaban.
- Ahora la fila va Volver ↔ Modo fácil ↔ Semilla ↔ Comenzar, y ↑ desde cualquiera vuelve al avatar elegido.
- Con Pesadilla, «Modo fácil» está apagado y pasa a `FOCUS_NONE`: se salta.
- ◀ ↔ ▶ de Pesadilla quedan enlazados; antes ◀ era inalcanzable.
- Al pulsar ◀/▶ o cerrar el diálogo de Semilla, el foco no se pierde: los botones se rehacían y el foco
  quedaba en uno ya liberado.
- El test ahora sale con código 1 si falla y corre con perfil aislado (`/tmp/vdm_focus_reach`).

## 3. Mando en título / selección / logros / compendio — HECHO (en `focus_reach`)
Comprueba con pulsaciones de mando reales (`Input.parse_input_event`):
- Foco inicial: portada «Nueva partida», selección en el avatar elegido, logros y compendio en la pestaña activa.
- Alcance con el D-Pad en las 3 pestañas de logros y en 3 del compendio, y en el compendio dentro de partida.
- Selección: recorrido ↓ → → ↑, también con Pesadilla; A en ▶ sube el nivel y conserva el foco; el foco vuelve
  a «Semilla: abc» tras el diálogo.
- B atrás: selección → portada, logros → portada, compendio → galería, compendio en partida → mapa.
- B en la portada no hace nada (es la raíz) y no pierde el foco.
- Resultado: **56 ok, 0 fallan**.

## Verificación final (2026-11-20)
- Arranque `--quit`: sin errores de script; solo «2 resources still in use», que ya salía en HEAD.
- Regresiones:
  - shop_pad_test 36/0
  - focus_audit_test 479/0/0 pendientes
  - flecos_layout_test 66/0
  - event_layout_test 2261/0
  - hand_stagger 0 fallan
  - options_test 31/0
- focus_reach: 56/0.
- ui_layout_test: con ventana, 12 020 ok / 75 fallan; sin ventana, 6007 ok / 69 fallan. Todos los fallos son
  de archivos ajenos (tabla de arriba) y en los dos casos salen con código 1.
- Capturas al 130 % revisadas a ojo: selección con Pesadilla, portada con partida guardada, Maestría y
  Compendio.
- Borrados `tests/_dbg_sel.*`, que eran mi depuración.

## Avisos para Juan
- `tip.gd` (ajeno): al 130 %, el tooltip del avatar enfocado («Aurora») cae encima del botón «Semilla» en la
  selección. Es la colocación del tooltip, no el layout.
- **Perfil ensuciado:** `~/.local/share/godot/app_userdata/Verso de Musas/meta.json` (+ `.bak`) y `save.json`
  tienen datos falsos de pruebas: historial inventado, rachas de 120, `win_*` altos. Venían de
  `ui_layout_test` y de otros tests sin aislar, incluidas 2 ejecuciones mías antes de aislarlo (~00:31).
  No lo he tocado. Hay que decidir si se restaura de una copia propia o se limpia.
- Hoy, a las 04:21, seguían escribiendo en ese `meta.json` los `tests/balance.gd` de otro agente. No es mío.
- Al salir, «2 resources still in use» (pista `menu_*.ogg`): también en HEAD, no es mío.
