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
