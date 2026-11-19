# Handoff · Fase 3 (progresión y retención) — 2026-11-19

## Hecho
- **Logros (37, 8 categorías)** en `data/progress.json`; lógica estática y testeable en `scripts/core/progress.gd`
  (`Progress.check(data)` marca grupos y logros en `Meta.data.ach` / `Meta.data.unl`, guardado atómico + .bak de siempre).
  Pantalla `scripts/ui/screens/achievements_screen.gd` (pestañas Logros / Maestría / Desbloqueos) con medallones
  (`scripts/ui/medal.gd`: arte pintado recortado, aro dorado, icono; gris + candado si falta).
- **Avisos emergentes** `scripts/ui/unlock_banner.gd` (lo añade `main.gd`; sustituye al antiguo `_on_unlock`):
  Galería, logro y contenido nuevo, en cola sin solaparse.
- **Desbloqueo de contenido**: 21 grupos (solo contenido de la Oleada 1/2). Foto `G.locked` en `Eng.new_run`
  vía `Eng.meta_locked`; filtros con `Eng.unlocked()` en botín, tienda, eventos y favores, y en `_relic_candidates`.
  Con `DB.extra=false`, en trazas/balance (sin Meta) y en el reto diario no se bloquea nada. Lo desbloqueado
  a mitad de partida entra en la siguiente.
- **Compendio** `compendium_screen.gd` (desde Galería): cartas por musa/neutrales y reliquias; bloqueadas
  oscurecidas con candado, condición y progreso.
- **Maestría**: `mp_<musa>` suma 1 por victoria (+1 Pesadilla 4+, +1 Pesadilla 8+, fácil no suma); 6 rangos.
- **Reto diario con histórico** `daily_screen.gd`: calendario mensual (musa del día y estado), racha actual/mejor,
  «Copiar reto», revancha de días pasados (`G.dailyLate`: cuenta en calendario, no en racha ni logros).
  Histórico del diario ahora 400 días. Menú: «Reto diario · racha N» y «Logros n/37».
- **Resumen compartible**: en `end_screen.gd` fila nueva «Revancha» (`Nav.rematch`), «Copiar resumen»
  (`Progress.share_text`) y «Logros»; muestra logros/desbloqueos de la partida y la Maestría al ganar.
- Estadísticas nuevas: `eng.gd` (`flawlessBoss`, `fastBoss`, `maxTurnCards`), `nav.gd` (`bestAct_<c>`, `act2`),
  `meta.gd` (`nmWin_`, `mp_`, hazañas al ganar, `dailyStreakBest`, relleno único `progV` desde el historial).

## Archivos
Nuevos: `data/progress.json`, `scripts/core/progress.gd`, `scripts/ui/medal.gd`, `scripts/ui/unlock_banner.gd`,
`scripts/ui/screens/{achievements,compendium,daily}_screen.gd`, `tests/progress_test.gd`.
Tocados: `scripts/core/meta.gd`, `scripts/engine/{eng,run,events,favors,daily}.gd`, `scripts/ui/{main,nav}.gd`,
`scripts/ui/screens/{title,end,gallery,history}_screen.gd`, `tests/drive.gd` (escenario `fase3`), `ROADMAP.md`.
No tocados (otro agente): combat_screen, rest_screen, card_view, enemy_view, hp_bar, tip, sfx.

## Comandos
```
godot --headless --path . --script tests/progress_test.gd     # 712 ok, 0 fallan
godot --headless --path . --script tests/run_traces.gd        # 350 ok, 0 fallan
XDG_DATA_HOME=/tmp/x godot --headless --path . tests/save_test.tscn   # SAVE_TEST OK (es Node: no va con --script)
XDG_DATA_HOME=/tmp/x godot --path . res://tests/drive.tscn -- fase3 <dir>   # capturas f3_*.png
```
También en verde: risk, events_test, seed_test, nm_test, history_test.tscn, ui_risk_test.tscn.

## Pendiente
- **Arte con Krea2** (no se usó GPU): medallones propios por logro (hoy reutilizan arte de Galería/fondos)
  e iconos de categoría dedicados; ilustración para el Compendio.
- Validar el ritmo de desbloqueo con jugadores (el bot de balance juega con todo desbloqueado). Las 3 reliquias
  raras de la Oleada 2 esperan a 2 jefes; mientras, el sorteo cae a poco común.
- Si en un mismo momento se ganan muchos logros, la cola dura ~4 s por aviso (al cargar un guardado antiguo
  el relleno es silencioso, sin avisos).
- Marcador online del diario: aplazado (fuera de alcance).
