# HANDOFF agente B — Fase 2.4/2.5 (mando, flecos de layout, accesibilidad)

Dueño exclusivo de: `scripts/ui/nav.gd`, `scripts/ui/screens/map_*`, `reward*`, `event*`, `favor_screen.gd`,
ajustes, `scripts/ui/enemy_view.gd` y en `combat_screen.gd` SOLO el rótulo «Poder N» de Osty y la insignia de pilas.
No toca: `uik.gd`, `juice.gd`, `tip.gd`, `tools/`, `data/`, `rest_screen.gd` (hoguera: otro agente), resto de combat.

## Estado
- [x] 1. Auditoría de mando + `tests/focus_audit_test.gd(.tscn)` — HECHO: 478 ok, 0 fallan, 1 pendiente de otro dueño
  - Test nuevo `tests/focus_audit_test.gd/.tscn`: 34 estados (mapa, favor, recompensa normal/élite/jefe,
    hoguera, tienda, los 27 eventos con su vista de resultado, pausa en cada pantalla). Mide foco válido y
    accionable (no deshabilitado), alcance con D-Pad, que el D-Pad no se escape del diálogo, y que los
    diálogos devuelvan los focus_mode. Antes del arreglo: 15 fallos.
  - `map_screen.gd`: las salas no elegibles ya no reciben foco (D-Pad arriba dejaba el foco en una sala
    deshabilitada); arriba/abajo solo desplazan el mapa (vecinos de foco = la propia sala).
  - `reward_screen.gd`: `_after_take()` — tras tomar un premio con diálogo, el Overlay devolvía el foco
    (diferido) al premio ya tomado (deshabilitado). Ahora se espera a que el diálogo se libere, el premio
    tomado pasa a FOCUS_NONE y el foco va al siguiente o a «Continuar».
  - PENDIENTE (otro dueño, `dlg.gd`): en la hoguera, «¡Carta mejorada!» (view_cards) abre SIN foco porque
    se abre dentro del cierre encadenado comparación→elección; los `pf.grab_focus.call_deferred()` de esos
    cierres se ejecutan después y caen en el diálogo que muere (y el `_locked` de la elección devuelve
    FOCUS_ALL a la hoguera que está detrás del diálogo nuevo). B sí lo cierra. Arreglo propuesto en
    `Overlay.close`: (a) restaurar el foco con `_reclaim_focus(pf)` (comprobando al ejecutarse, no al pedirlo)
    y no hacerlo si hay otro Overlay vivo encima que no contiene a `pf`; (b) si hay un Overlay vivo abierto
    después, pasarle los pares de `_locked` en vez de restaurarlos. El test lo lista como PENDIENTE.
- [x] 2. Flecos de layout — HECHO. `tests/flecos_layout_test.gd/.tscn`: 66 ok, 0 fallan (antes 8 fallos).
  `ui_layout_test` en headless ya no lista «posicionados a mano que se salen» (antes: favor, Contramaestre,
  Poder 4 y «3 sobre Panel»).
  - `favor_screen.gd`: «Rechazar los favores» medía 50 px y empezaba en y=680 (salía a 730). Ahora se mide
    en el árbol y se coloca a 10 px del borde inferior (se recoloca si UIK le cambia el alto); entidad,
    frase y fila de cartas suben 10-26 px para dejarle sitio (cartas 368→648, botón 660→710).
  - `enemy_view.gd`: el nombre baja de fuente con `UIK.fit_title(w-10, mín. 11)` y va anclado a lo ancho
    (con 3 enemigos la vista mide 190 y el nombre pedía 192).
  - `combat_screen.gd` (solo rótulo de Osty): `osty_pow` dentro de su caja (0,110, 90×40), 2 líneas,
    `UIK.fit_label(…, 11)` al cambiar el texto («Caído · vuelve en tu turno» queda en 12 px, 2 líneas).
  - `combat_screen.gd` `_orb_slot`: el «3 sobre Panel» que marcaba el test NO era la insignia de pilas sino
    el valor del orbe de Selene (salía 2-3 px del hueco de 44). Anclado abajo-derecha y creciendo hacia
    dentro. Las insignias de pila (mazo/descarte/agotadas) ya cabían con 1, 2 y 3 cifras: sin cambios.
- [ ] 3. Escala de texto y remapeo — NO HECHO: bloqueado por dueños de archivo (decisión del orquestador).
  - El diálogo de ajustes es `Dlg.options()` en `dlg.gd` (dueño: agente A).
  - Escala de texto real = multiplicar el tamaño en `UIK.label/rich/button` (`uik.gd`, prohibido) y validar
    con `ui_layout_test` + `flecos_layout_test` a 1.0/1.15/1.3; `content_scale_factor` escalaría todo, no solo
    el texto, y rompería el 1280×720 de diseño.
  - Remapeo: las teclas están escritas a mano como `KEY_*` (13 en `combat_screen.gd`, 4 en `main.gd`), no
    son acciones de InputMap. Plan: acciones (`ver_mazo`, `ayuda`, `terminar_turno`, `pocion_1..4`, `robo`,
    `descarte`, `agotadas`, `deshacer`) registradas al arrancar desde `Meta.settings.keys`, `is_action_pressed`
    en main/combat, y una fila «Controles» en `Dlg.options` que capture la tecla nueva.

## Comandos
```sh
cd /home/juang/projects/IngenieriaInversa/VersoDeMusas-w2
ulimit -c 0
timeout 300 godot --headless --path . res://tests/focus_audit_test.tscn
timeout 300 godot --headless --path . res://tests/shop_pad_test.tscn
timeout 300 godot --headless --path . res://tests/hand_stagger.tscn
timeout 60 godot --headless --path . --quit
timeout 200 godot --headless --path . res://tests/flecos_layout_test.tscn
```

## Verificación final (2026-11-19)
focus_audit_test 478 ok / 0 fallan / 1 pendiente (dlg.gd) · flecos_layout_test 66/0 · shop_pad_test 36/0 ·
hand_stagger 0 fallan · event_layout_test 2261/0 · arranque `--quit`: solo los avisos de fuga al salir que ya
salen con los archivos de HEAD (4 ObjectDB, 2 recursos). Respaldos: `/tmp/agB_bk_*.gd`.
