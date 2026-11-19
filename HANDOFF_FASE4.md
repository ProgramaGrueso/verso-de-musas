# HANDOFF · Fase 4 · Jefes con fases (2026-11-19)

## Hecho
- Datos: `tools/make_content_w2.py` → `BOSS_PHASES` (tras `BALANCE`), se mezcla en `BALANCE["enemies"]` y
  sale en `data/balance_w2.json` (solo se carga con `DB.extra`). Cada jefe tiene `phase2` = {at, str, block, msg, seq}
  y 1 movimiento nuevo: crabking «Guillotina», drowncaptain «Tormenta de Metralla», rootmother «Bosque de Espinas»,
  mycelking «Esporada Final», queen «Enjambre Real», waxcolossus «Núcleo Ardiente».
- Motor (`scripts/engine/eng.gd`): `_boss_phase()` y `_phase_key()` junto a `deal_to_enemy`; enganches en
  `deal_to_enemy` (al cruzar el umbral, re-telegrafía el intent si es turno del jugador) y al inicio de `_ai_key`
  (cubre el veneno). Emite fx `bossPhase` {e, msg} + el fx `status` de Fuerza y `enemyBlock` que la UI ya pinta.
- Test: `tests/boss_phase_test.gd`.
- Equilibrio (`balance.gd -- 100 0`): con +Fuerza e invocaciones en fase 2 caía a 22 % de victorias (muro). Versión
  final sin Fuerza, sin curas ni invocaciones en fase 2: **39,3 %** global (base sin fases 40,2 %). Derrotas por jefe
  base→fases: crabking 14,6→21,8 %, drowncaptain 19,5→14,2, mycelking 24,3→22,9, queen 23,1→14,0,
  rootmother 18,9→21,5, waxcolossus 21,1→29,8. Los campos `str`/`block` siguen soportados (hoy a 0).

## Pendiente
- ~~UI: banner para el fx `bossPhase`~~ **Hecho** (verificado 2026-11-19): `combat_screen.gd:638-649` ya pinta
  banda roja «<Jefe> · ¡Fase 2!» + sacudida, flash, anillo y sonidos danger+bigHit (lo implementó la Fase 2;
  este handoff quedó desactualizado). Escenario de captura: `drive.tscn -- bossphase`.
- Ajustar cifras de fase con `balance.gd` a más partidas (200 sweep).

## Comandos
```
python3 tools/make_content_w2.py
godot --headless --path . --script tests/run_traces.gd          # 350 ok
godot --headless --path . --script tests/boss_phase_test.gd     # 0 fallan
godot --headless --path . --script tests/balance.gd -- 100 0
```
