# HANDOFF · Verso de Musas · cierre de orquestación 2026-11-19 (tarde)

Proyecto: `/home/juang/projects/IngenieriaInversa/VersoDeMusas-w2` (Godot 4.7.2).
Plan maestro: `ROADMAP.md`. Estado: **jugable de punta a punta** (`./jugar.sh`; el bot de interfaz completa una partida y muere en el jefe del Acto I como se espera del bot aleatorio).

## ¿Qué se hace con los handoffs ya completados? (para Juan)

**No se borran.** Se mantienen como historial: explican *por qué* cada número es como es (por ejemplo, por qué la fase 2 de los jefes va sin Fuerza). Lo que sí se hace cada cierre:
1. **Este HANDOFF.md se reescribe** y pasa a ser el único índice con lo que falta.
2. Los handoffs de fase ya cerrados dejan de actualizarse (solo se corrigen si dicen algo falso, como pasó hoy con el banner `bossPhase`).
3. Cuando un handoff se vuelva ruido (p. ej. `HANDOFF_OLEADA2.md`, cerrado en la Fase 0), se puede mover a `docs/historial/` sin borrarlo. Decisión de Juan.

---

## Hecho en esta sesión (todo commiteado)

| Commit | Contenido | Handoff de detalle |
|---|---|---|
| `7980d2a` feat(combate) | Fase 2: juice, sonidos, chips de reliquia, tooltip enemigo, muerte segura, hoguera, banner de jefe, modo calma | `HANDOFF_FASE2.md` |
| `0404285` feat(jefes) | Fase 4: fase 2 al 50 % PV en los 6 jefes (solo `DB.extra`) | `HANDOFF_FASE4.md` |
| `88c1abb` feat(progresion) | Fase 3: 37 logros, Maestría, 21 grupos de desbloqueo, Compendio, Diario, resumen compartible | `HANDOFF_FASE3.md` |
| `dc8346c` build(linux) | Preset Linux + `tools/build_linux.sh`; `.pck` exportado y humo OK | `HANDOFF_BUILD.md` |
| `e73a39f`/`a91e4e3` art | Pipeline `gen_art_w3.py`; aro + 7 medallones de mapa; 12 medallas de logro; 6 retratos de fase 2 | `HANDOFF_ARTE.md` |
| `13e7d0e` feat(elites) | **Fase 4B**: 3 élites nuevos + 3 eventos raros una vez por partida | `HANDOFF_FASE4B.md` |
| `695e5fc` art | Integración: medallones en el mapa y su leyenda, medallas en logros, retratos al entrar en fase 2 | — |
| `6cb4d9a` docs | Handoffs corregidos (banner `bossPhase` sí existe: `combat_screen.gd:638-649`) | — |

### Verificación al cierre
- `run_traces` 350 ok/0 · `progress_test` 712 · `boss_phase_test` 6/6 · `risk` 892 · `events_test` **143.302 ok/0** · `save_test` y `ui_risk_test` OK.
- Soak interfaz: 50/50 partidas completadas, 0 `SCRIPT ERROR` (bot aleatorio: 0 victorias es lo esperado).
- Build: `tools/build_linux.sh debug` → `.pck` 518 MB + humo headless rc 0.
- Balance `-- 100 0`: global **36,2 %** (banda 35–45). Élites nuevos: bosun 10,5 %, rootwarden 12,7 %, **royalbeetle 18,6 % (alto)**.
- Arte: 25 imágenes revisadas a ojo (hoja de contacto + captura `mapview`).

---

## Lo que FALTA (por valor)

1. **Ajustar el Escarabajo Real** (18,6 % de derrotas, objetivo 8–12): subir `shellCap` a 14 o bajarle PV en `tools/make_content_w2.py` y regenerar. Pequeño.
2. **Fase 2.3 Inspección + flecos de Fase 2** (el agente se quedó sin cuota; piezas ya hechas: `Icons.tex_or` y `with_text` con respaldo):
   - Clic en reliquia → tooltip (hoy solo hover; hace falta para mando/táctil).
   - Pilas con filtros ataque/habilidad/poder y marca de mejoradas.
   - Mazo consultable desde cualquier sala (hoy `M` solo en combate).
   - Hoguera: mostrar «6 → 9» en vez de repetir el texto.
   - `tests/sfx_test.gd`: que ningún sonido sintetizado sea silencio.
3. **Fase 2.4/2.5**: tutoriales por musa (Cuerda, orbes, Osty, Calor), escala de texto, remapeo de teclas, auditoría de mando completa.
4. **Linux**: plantillas 4.7.2 (~1 GB, `~/.local/share/godot/export_templates/4.7.2.stable/`) → decidir y descargar Juan; luego probar el binario en ventana y en Deck.
5. **Arte restante (opcional)**: iconos de categoría de logros, ilustración del Compendio, retratos de los 3 élites nuevos (hoy son copias de otro sprite).
6. **Fase 4 restante**: poda del pool con datos de elección del bot; 2 arquetipos viables por musa.
7. **Fase 5**: localización ES/EN (`tr()`), Steam/nube, demo, pipeline de build reproducible.
8. **Validación humana**: 3 partidas por musa (Fase 1.1), ritmo de desbloqueo y banda de Pesadilla 10 (~8 %).

## Decisiones abiertas (de Juan)
- Premium en Steam vs free-to-play con demo.
- ¿Localización EN en el lanzamiento o en una actualización?
- ¿Reto diario con marcador online desde el día uno?
- Fuerza de fase 2 de los jefes: hoy 0 (con Fuerza era un muro, 22 % vs 40 %).
- ¿Mover handoffs cerrados a `docs/historial/` o dejarlos en la raíz?

## Comandos
```sh
godot --headless --path . --script tests/run_traces.gd      # 350 ok, 0 fallan
godot --headless --path . --script tests/progress_test.gd   # 712 ok
godot --headless --path . --script tests/boss_phase_test.gd # 6/6
godot --headless --path . --script tests/events_test.gd     # 143.302 ok, 0 fallan
godot --headless --path . --script tests/risk.gd            # 892 ok
godot --headless --path . --script tests/balance.gd -- 100 0   # victoria global 35-45 %
godot --path .               # jugar a mano (./jugar.sh)
python3 tools/make_content_w2.py                            # tras editar contenido
python3 tools/gen_art_w3.py gen && python3 tools/gen_art_w3.py build   # arte (ComfyUI)
tools/build_linux.sh [release|debug]
```

## Reglas (no romper)
- Contenido/balance nuevo SOLO con `DB.extra=true`; los datos base están congelados por las 350 trazas.
- Editar el generador `tools/make_content_w2.py` (y `gen/jobs_art_w3.json` para arte) y regenerar; no tocar JSON/artefactos a mano.
- Calidad premium: sin placeholders.
- Agentes en paralelo no deben tocar los mismos archivos. Dueños históricos: `tests/drive.gd` (uno cada vez), `scripts/ui/**` en una sola oleada, `scripts/engine/**` en otra.
- ComfyUI: encendido en :8188, compartido; no apagarlo. Solo se descargan **LoRAs** si falta un modelo (orden de Juan).
