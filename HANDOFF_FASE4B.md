# HANDOFF · Fase 4B · Élites nuevos y eventos raros (2026-11-19, cortado por plazo)

## Estado (actualizado 2026-11-19 tarde)
- **IMPLEMENTADO y commiteado** (`13e7d0e`): los 3 élites (`spectralbosun`, `rootwarden`+2 Brotes, `royalbeetle`)
  y 3 eventos raros con `"once": true` (`campana_bruma`, `corazon_hueco`, `cera_memoria`) vía `G.onceEvents`
  + filtro en `RunGen.event_ok`. El sorteo pasó a pesos reales (`weight`) sin cambiar el reparto de las musas.
- Mecánicas: Cañón Rompible (`brk`, cuenta también lo absorbido por Bloqueo; `_brk_check`), Escudo de Raíces
  (mitad de daño con Brotes vivos, estado `rootShield` sincronizado), Coraza (`shellCap`).
- Medido `balance.gd -- 100 0`: global 36,2 %; bosun 10,5 %, rootwarden 12,7 %, **royalbeetle 18,6 % (alto, por ajustar)**.
- `events_test` 143.302 ok/0 (incluye las mecánicas de los tres élites y los eventos únicos).

## Hallazgos (para no releer)
- El arte del enemigo se carga por id: `res://assets/enemies/<id>.webp` (`scripts/ui/enemy_view.gd:48`); si falta, sale sin imagen.
  Un élite nuevo con arte reutilizado = copiar un `.webp` existente con el id nuevo y correr `godot --headless --path . --import`.
- Fondo de evento: `res://assets/bg/ev_<id>.webp` (`event_screen.gd:75`), tolera que falte.
- La intención se telegrafía con `it.name` + iconos de dmg/block/selfStr/thorns/apply/add/heal/summon (`enemy_view.gd:227-285`):
  una mecánica nueva se explica en el nombre del movimiento o con un estado nuevo en `STATES` (states_extra.json).
- Eventos: lógica en `scripts/engine/events.gd::_options_w2`; sorteo en `scripts/engine/run.gd::_pick_event_extra`.
  `seenEvents` se vacía al agotar el pool, así que «una vez por partida» necesita una lista aparte
  (p. ej. `G.onceEvents`) y un filtro en `RunGen.event_ok` para eventos con `"once": true` (solo con `DB.extra`).
- Élites del juego ampliado: se suman en `db.gd` (`A.elite + X.elite`) desde `ENCOUNTERS[...]["elite"]` del generador.

## Diseño propuesto (pendiente de implementar)
1. Acto I · «Contramaestre Espectral» (arte de `ghostpirate`): **cañonazo rompible** — el golpe grande lleva `brk: N`;
   si el jugador le inflige N de daño en ese turno, la intención pasa a «¡Aturdido!». Engancha en `deal_to_enemy` (eng.gd, edición mínima).
2. Acto II · élite con 2 `sprout` (arte de `dryad`/`treant`): **Escudo de Raíces** — recibe la mitad de daño mientras viva un brote;
   estado visible en el enemigo. Decisión: limpiar brotes o atacar al élite.
3. Acto III · «Escarabajo Real» (arte de `beetle`): **Coraza** — ningún golpe le quita más de ~10 PV; premia multigolpe.
4. Eventos raros (`"once": true`, peso bajo), 1-2 por acto, con riesgo/recompensa y texto apto para todos.
- Todo solo con `DB.extra`; medir con `balance.gd -- 100 0` (global 35-45 %, élites nuevos 8-12 % de derrotas) y extender `events_test.gd`.

## Comandos
```
python3 tools/make_content_w2.py
godot --headless --path . --script tests/run_traces.gd     # 350 ok
godot --headless --path . --script tests/events_test.gd
godot --headless --path . --script tests/balance.gd -- 100 0
```
