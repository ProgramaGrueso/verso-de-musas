# HANDOFF · Verso de Musas · cierre 2026-11-19 ~18:05

Proyecto: /home/juang/projects/IngenieriaInversa/VersoDeMusas-w2 (Godot 4.7.2, `./jugar.sh`).
Meta de Juan: deckbuilder triple A / GOTY (retador, ameno, rejugable, grandes y chicos). Plan maestro: `ROADMAP.md`.
~~TODO lo de abajo está SIN COMMIT~~ **Commiteado el 2026-11-19 por bloques** (combate / jefes / progresión / build; ver `git log`). Quedan fuera: arte generado (en revisión) y este cierre.

## Hecho (cada uno tiene su handoff con detalle)
| Bloque | Qué | Handoff |
|---|---|---|
| Fase 2 combate | juice (hitstop, sacudida, números escalonados, slam), sonidos sintetizados, chips de reliquia, tooltip enemigo, "muerte segura", mejora de carta en hoguera, ajuste "Reducir movimiento" (`Meta.settings.calm`), banner de jefe fase 2 | `HANDOFF_FASE2.md` |
| Fase 3 progresión | 37 logros (`data/progress.json`, `scripts/core/progress.gd`), pantallas Logros/Maestría/Desbloqueos/Compendio/Diario, 21 grupos de desbloqueo (solo con DB.extra), avisos en cola, resumen compartible | `HANDOFF_FASE3.md` |
| Fase 4 jefes | 6 jefes con fase 2 al 50 % PV (`BOSS_PHASES` en `tools/make_content_w2.py`, solo DB.extra), fx `bossPhase`, `tests/boss_phase_test.gd`. Fuerza de fase 2 = 0 (decisión abierta) | `HANDOFF_FASE4.md` |
| Build Linux (parcial) | preset "Linux" en `export_presets.cfg`, `export/linux/VersoDeMusas.pck` (arranca sin errores), `tools/build_linux.sh` (solo sintaxis probada) | `HANDOFF_BUILD.md` |

Verificación al cierre: run_traces 350 ok/0 fallan; progress_test 712 ok; boss_phase_test 6/6; risk 892 ok; `save_test` solo como .tscn (con --script falla: ya pasaba antes). El `run_traces` ignora el fx "relic" (solo UI).

## NO hecho (por orden de valor)
1. **Arte nuevo**: 0 imágenes generadas. Hay `tools/gen_art_w3.py` (`gen` y `build`) + `gen/jobs_art_w3.json` (aro común + 7 medallones de nodo del mapa). El pipeline viejo (`gen/comfy.py`, `tools/gen_icons.py`) está ROTO: ya no existen el modelo moodyKrea2Mix ni el LoRA darkbrush y `rembg` necesita red; el generador nuevo usa Krea2 actual (DaSiWa vía krea2_lib) + BiRefNet de ComfyUI. El estilo no saldrá igual que los iconos previos: revisar el primer lote a ojo. Luego: integrar iconos en `map_screen.gd`/`icons.gd` (con fallback), ~12 medallones de logros (`"art": "lore:ach_<id>"` en progress.json), 6 retratos de fase 2 de jefes (enemy_view.gd). Ver `HANDOFF_ARTE.md`. **ComfyUI solo con permiso de Juan y sin apagarlo** (lo usa otro agente).
2. **Élites y eventos raros** (Fase 4B): solo diseño en `HANDOFF_FASE4B.md` (Contramaestre Espectral, élite de brotes, Escarabajo Real; eventos 1 vez por partida vía `G.onceEvents` filtrado en `RunGen.event_ok`, solo DB.extra).
3. **Linux**: faltan plantillas de exportación 4.7.2 en `~/.local/share/godot/export_templates/4.7.2.stable` (~1 GB, decide Juan). Falta soak de 50 partidas (`tests/playthrough.gd` acepta el número) y prueba en ventana.
4. **Fase 2.4/2.5**: tutoriales por musa (Cuerda, orbes, Osty, Calor), escala de texto, remapeo de teclas, mando completo.
5. **Fase 5**: localización ES/EN, Steam/nube, demo.
6. Sonidos grabados (hoy sintetizados); hoguera: mostrar "6 → 9" en vez de repetir texto.
7. Validar con jugadores el ritmo de desbloqueo (el bot juega con todo desbloqueado); 3 partidas humanas por musa (Fase 1.1).

## Comandos
```sh
cd /home/juang/projects/IngenieriaInversa/VersoDeMusas-w2
godot --headless --path . --script tests/run_traces.gd      # debe dar 350 ok, 0 fallan
godot --headless --path . --script tests/progress_test.gd   # 712 ok
godot --headless --path . --script tests/boss_phase_test.gd # 6/6
godot --headless --path . --script tests/balance.gd -- 100 0   # victoria global del bot 35-45 %
godot --headless --path . --import                          # tras añadir assets
godot --path . tests/drive.tscn -- <escenario>              # capturas: juice, bossphase, fase3, mapview
tools/build_linux.sh [release|debug]
```

## Reglas (no romper)
- Contenido/balance nuevo SOLO con `DB.extra=true`; los datos base están congelados por las 350 trazas.
- Editar el generador `tools/make_content_w2.py` y regenerar; no tocar JSON a mano.
- Calidad premium: sin placeholders. Orquestar con `programador-opus` (código) y `ayudante-haiku` (mecánico); agentes en paralelo no deben tocar los mismos archivos.
- Un agente reportó fallo de parse en `tests/drive.gd` mientras otro lo editaba: no editar ese archivo en paralelo.
