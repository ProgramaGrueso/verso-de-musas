# HANDOFF · Fase 4B · Élites nuevos y eventos raros (2026-11-19, cortado por plazo)

## Estado
- **No se editó ningún archivo del proyecto.** Árbol intacto y consistente: `run_traces` = 350 ok, 0 fallan (17:58).
- Solo hubo lectura y diseño. ROADMAP sin marcar (la casilla de élites/eventos sigue abierta).

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
