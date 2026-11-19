# HANDOFF Fase 2.1 (juice) + 2.2 (legibilidad) + 2.5 «reducir movimiento»

Fecha: 2026-11-19. Sin git commit. Sin ComfyUI ni GPU (capturas con llvmpipe por software).

## Hecho
- **Hitstop** 65–80 ms (`Engine.time_scale` 0.05, encadenado con `_stop_until`) en golpe grande a enemigo (≥15), golpe grande a la musa (≥max(12, 18 % PV máx.)), muerte de enemigo y derrota. Desactivado en test_mode y en modo calma.
- **Flash + sacudida**: enemigo `flash_hit(strength)` blanco→rojo y sacudida proporcional; musa `_player_flash` + `_player_shake` + flash de pantalla.
- **Números de daño escalonados**: `_popup` reparte por objetivo en abanico `POP_FAN` y con un retraso `POP_GAP`; tipo nuevo "poison"; tamaño según daño.
- **Slam al jugar carta**: anticipación, vuelo, impacto (anillo de color según tipo y chispas), golpe de escala; las cartas pesadas (`_is_heavy`) llevan su sonido y sacuden la pantalla.
- **Transición de turno**: banda «Turno enemigo» (roja) + tinte rojo y mano atenuada (`_enemy_phase_look`); banda «Tu turno · Turno N»; el botón dice «Turno enemigo…».
- **Sonidos sintetizados** (sfx.gd, sin archivos): blockUp, blocked, poisonApply, orbChannel, orbEvoke, heavy, playerDie, relic, enemyTurn, turn, danger.
- **Reliquia que se dispara**: eng.gd solo emite `_fx("relic")` comparando una huella de estado antes y después de cada hook (de solo lectura, sin RNG), más 6 disparos inline. `Main.pulse_relic`: el icono pulsa y aparece un chip compacto en una columna a la izquierda (x 10, y 128+34·n).
- **Tooltip de enemigo**: `EnemyView.tip_text()` muestra PV, Bloqueo, Intención, Mejoras y Penalizaciones con su descripción.
- **MUERTE SEGURA**: insignia roja que late, con tooltip, y viñeta, cuando el daño entrante ≥ PV (ya descontado el Bloqueo). Muestra «GOLPE MORTAL · Pluma» si la Pluma sigue sin usar.
- **Hoguera**: al pasar el ratón o el foco por una carta en `Dlg.pick_cards` con `upgradePreview` se ve al lado la carta mejorada y una nota (`Dlg.upgrade_note`).
- **Fase 2 de jefe** (fx `bossPhase` {e, msg} que emite el motor): banda roja «<Jefe> · ¡Fase 2!» con el msg, sacudida corta (omitida en calma), flash y anillo sobre el jefe, sonidos danger+bigHit. Escenario de captura: `drive.tscn -- bossphase <dir>`.
- **Opciones → «Reducir movimiento»** (`Meta.settings.calm`): quita sacudidas, hitstop, partículas, anillos, parallax y brasas; los popups y bandas solo hacen fundido.

## Archivos tocados
- Nuevo: `scripts/ui/juice.gd`.
- Modificados:
  - `scripts/core/sfx.gd`
  - `scripts/core/meta.gd`: solo el default `calm`.
  - `scripts/engine/eng.gd`: solo emisión de eventos.
  - `scripts/ui/main.gd`
  - `scripts/ui/dlg.gd`
  - `scripts/ui/enemy_view.gd`
  - `scripts/ui/screens/combat_screen.gd`
  - `scripts/ui/screens/rest_screen.gd`: subtítulo.
  - `tests/drive.gd`: escenario `juice`.
  - `ROADMAP.md`
- El coordinador añadió en `tests/run_traces.gd` un filtro que ignora el fx "relic".

## Cómo verificar
```
godot --headless --path . --script tests/run_traces.gd        # 350 ok, 0 fallan
godot --headless --path . --script tests/risk.gd              # 892, 0 fallan
XDG_DATA_HOME=/tmp/x godot --headless --path . res://tests/save_test.tscn     # SAVE_TEST OK
XDG_DATA_HOME=/tmp/x godot --headless --path . res://tests/ui_risk_test.tscn  # exit 0
# 19 capturas de juice (j01..j19), sin GPU:
LIBGL_ALWAYS_SOFTWARE=1 __GLX_VENDOR_LIBRARY_NAME=mesa __EGL_VENDOR_LIBRARY_FILENAMES=/usr/share/glvnd/egl_vendor.d/50_mesa.json \
  godot --rendering-driver opengl3 --path . res://tests/drive.tscn -- juice <dir_salida>
```

## Pendiente / decisiones para Juan
- Los sonidos son sintéticos: funcionan y se distinguen, pero no son de calidad AAA. Si se quieren muestras reales, hay que producirlas o licenciarlas.
- Arte nuevo: todo se hizo por código (anillos, chispas, bandas). No se generó arte con ComfyUI, por orden de Juan.
- La vista previa de la hoguera se superpone a la carta vecina, como en StS. La nota repite el texto de la carta cuando la mejora solo cambia números; se podría mostrar un diff del tipo «6 → 9».
- Falta un test automático que compruebe que cada sonido nuevo no es silencio (las recetas usan los mismos generadores `_t`/`_n` que los sonidos existentes).
