# Verso de Musas (Godot)

Port a Godot 4.7 del deckbuilder roguelike web `../VersoDeMusas` (el web queda congelado como "preview").

## Jugar
```
./jugar.sh            # abre el juego
./jugar.sh --editor   # abre el editor
```

## Estructura
```
data/            JSON exportado del web (cartas, enemigos, reliquias, eventos, retos, estados)
scripts/engine/  motor sin interfaz: eng.gd (combate/partida), relics.gd, run.gd (mapa/tienda), events.gd
scripts/core/    meta.gd (progreso, ajustes, guardado), sfx.gd (efectos sintetizados + música), db.gd (carga de datos)
scripts/ui/      main.gd (raíz), nav.gd (navegación), dlg.gd (diálogos), card_view.gd, screens/*
tests/           run_traces.gd (paridad con el web), playthrough.gd (bot que juega por la interfaz), drive.gd (capturas)
tools/           export_data.mjs, gen_trace.mjs (se ejecutan con node desde esta carpeta)
```

## Paridad con el web
El motor (`scripts/engine/*`) es una traducción 1:1 de `engine.js`. `tests/traces.json` contiene partidas de referencia
generadas con el motor web (semilla + bot determinista); el motor de Godot debe reproducir cada línea exacta
(RNG, combate, mapa, tienda, recompensas):
```
node tools/gen_trace.mjs                                              # regenera las trazas desde el web
godot --headless --path . --script tests/run_traces.gd                # compara (350 casos)
```

## Añadir contenido
- Carta / enemigo / reliquia: editar el JSON de `data/` (o el JS del web y volver a ejecutar `node tools/export_data.mjs`).
- Mecánica nueva en una carta (`fx`): añadir su manejo en `Eng.run_fx` y su texto en `CardText.lines`; regenerar trazas.
- Arte: `assets/cards/card_<id>.webp`, `assets/enemies/<id>.webp`, etc. (mismos nombres que el web, ver `../VersoDeMusas/AGENTS.md`).

## Contenido nuevo (más allá del port)
- `data/cards_extra.json` (generado por `tools/make_cards_w1.py`): Oleada 1 de cartas (+9/10 por musa y 23 neutrales). Las trazas de paridad con el web lo desactivan (`DB.extra = false`).
- Arte de cartas: `gen/jobs_cards_w1.json` → `gen/comfy.py` (Krea2 + LoRA de cada musa), luego a `assets/cards/card_<id>.webp` (560×424).
- Mapa del juego: `RunGen.gen_map_game` (el `gen_map` original se conserva para las trazas). Favor de las Musas: `scripts/engine/favors.gd`.

## Oleada 2 (variedad, historial y reto diario)
Contenido generado por `tools/make_content_w2.py` (se desactiva con `DB.extra = false`, igual que las cartas de la Oleada 1):
- `data/events_extra.json`: 17 eventos nuevos (24 en total). Algunos solo salen en un acto (`act`) y otros solo con una musa (`char`);
  «Un Recuerdo» cambia de texto según la musa (`textBy`). Lógica en `EventsLogic._options_w2`. Los eventos de musa dan bendiciones
  permanentes (`G.perm`, aplicadas en `Eng.apply_perm` al empezar cada combate).
- `data/enemies_extra.json`: 9 enemigos (un jefe, un élite y un normal por acto) y encuentros por acto separados en `easy`/`hard`.
  Los 3 primeros combates normales de cada acto salen de `easy`; el resto de `hard`, sin repetir el anterior (`RunGen.encounter_game`).
  El jefe de cada acto se sortea al crear el mapa (`G.bossId`) y se muestra en él.
- `data/relics_extra.json`: 26 reliquias (poco comunes, raras, de jefe y 2-3 por musa) y 8 pociones. Efectos en `scripts/engine/relics.gd`
  y ganchos nuevos en `eng.gd` (`onKill`, `onShuffle`, eco de cartas, Pluma de Fénix...). Las reliquias aleatorias salen por rareza
  (`Eng.random_relic_tiered`) y la tienda ofrece común + poco común + poco común/rara.
- `data/states_extra.json`: estado Regeneración.
- Arte pendiente: `gen/jobs_w2.json` (enemigos y fondos de eventos) y `gen/icons_w2.json` (iconos; `tools/gen_icons.py` ya los incluye).
  Sin arte, el juego usa emojis de respaldo.

Además:
- **Historial** (menú principal): estadísticas por musa, cartas más jugadas, retos diarios y detalle de las últimas 60 partidas (`Meta.record_run`).
- **Semillas**: en la selección de musa se puede escribir una semilla; cada acto arranca de `Eng.act_seed(seed, acto)`, así que la misma
  semilla repite los tres mapas. La semilla se ve (y se copia) en el menú de pausa, el final de partida y el historial.
- **Reto diario** (`scripts/engine/daily.gd`): semilla, musa y modificador sacados de la fecha.
- **Combate**: daño entrante total sobre la barra de vida; deshacer la última carta en modo fácil (`Eng.snapshot`/`Eng.restore`, tecla Z);
  pociones con Q/W/R/T, pilas con D/S/X, mazo con M y ayuda con H/F1.
- **Equilibrio**: `godot --headless --path . --script tests/balance.gd -- 100 0` juega partidas completas con un bot y resume
  % de victorias por musa, dureza de jefes/élites y qué encuentros matan más.

