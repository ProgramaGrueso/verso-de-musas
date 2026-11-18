# Traspaso · Fase 0 y Fase 1 (pausa 2026-11-18)

Rama: `ccr-a7209c0c-soukyo`. Todo lo de abajo está **sin commitear** (working tree sucio a propósito:
el siguiente paso es revisar y hacer uno o varios commits). Este documento permite retomar sin releer
la conversación. El plan sigue en `ROADMAP.md`; aquí va el estado real medido.

Resumen: **Fase 0 cerrada salvo la pasada de interfaz con las 6 musas** y **Fase 1 con la curva ya dentro
de banda en las 3 semillas**, pendiente de Pesadilla 5, comparativa `base`, referencia humana y commit.

---

## 1. Qué se hizo (y dónde)

### Fase 0 · Beta fiable

| Punto del roadmap | Estado | Dónde |
|---|---|---|
| `--import` y `.uid` | Hecho. No aparecieron `.uid` nuevos; ya estaban commiteados. | — |
| `run_traces` 350 ok | Hecho: **350 ok, 0 fallan** (última ejecución tras todos los cambios). | `tests/run_traces.gd` |
| `playthrough` 6 musas + fácil + semilla | **Parcial**: solo humo con Zafiro (100 s, murió en piso 6 del Acto I) *antes* de los cambios de balance. Falta repetirlo con las 6 y con `easy`/semilla. | `tests/playthrough.gd` |
| 7 puntos de riesgo | Cubiertos por tests automáticos: `risk` (deshacer/Eco/Pluma) **892 ok**, `events_test` **126.504 ok**, `history_test` OK, `ui_risk_test` OK, `save_test` OK. Falta la vuelta manual por interfaz. | `tests/risk.gd`, `events_test.gd`, `history_test.tscn`, `ui_risk_test.tscn` |
| Guardado a prueba de balas | **Hecho**: escritura atómica `.tmp` + rename, copia `.bak` antes de sobrescribir, lectura con caída al `.bak`, `clear_save` borra los tres, y prueba de `kill -9` real. | `scripts/core/meta.gd`, `tests/save_test.gd`, `tests/crash_writer.*`, `tests/crash_reader.*` |
| Volcado por partida | **Hecho**: `user://balance_runs.json` con musa, semilla, Pesadilla, acto, piso, causa de muerte, PV, oro, mazo y reliquias. | `tests/balance.gd` |

Prueba de cierre brusco (repetible):

```sh
export XDG_DATA_HOME=/tmp/vdm_crash && rm -rf /tmp/vdm_crash
(godot --path . res://tests/crash_writer.tscn -- 4242 > /tmp/cw.log 2>&1 & echo $! > /tmp/cw.pid)
until grep -q SAVED /tmp/cw.log; do sleep 0.25; done
kill -9 $(cat /tmp/cw.pid)
godot --headless --path . res://tests/crash_reader.tscn   # imprime CRASH_SAVE OK
```

### Fase 1 · Equilibrio

| Punto | Estado | Dónde |
|---|---|---|
| Políticas de bot por musa | **Hecho**: valoración por daño real (`preview_dmg`), Bloqueo según peligro, objetivo que remata, Osty, orbes, Cuerda/Engranaje, Calor, veneno, sinergias al elegir recompensa, pociones cuando hay riesgo. | `tests/balance.gd` |
| 3 partidas humanas × musa | **Pendiente** (no se puede hacer desde el agente). Es el hueco de la Fase 1.1. |
| Arreglar la medición | Hecho lo automático. Queda contrastar con las 18 humanas. | `tests/balance.gd` |
| Suavizar jefes del Acto I | `crabking` y `drowncaptain` ajustados por overrides (solo con `DB.extra`). | `tools/make_content_w2.py` → `data/balance_w2.json` |
| Subir élites | Subidas las 9; ver banda abajo. | ídem |
| Encuentros fáciles/difíciles | Acto I: +`eel+eel`, +`ghostpirate+jelly`, `jelly`/`crab` con más PV. Acto III: `honeyslime`/`beetle`/`workerbee` más duros. | ídem |
| Reliquias outlier | `escamas` 3→2 Espinas, `caparazon` 2→1 Metalizar, `pozo` 25→18 PV, `nucleo` 1→2 Heridas, y buffs a las iniciales flojas (`brasa_carmesi`, `llave_maestra`). | ídem + `scripts/engine/relics.gd` |
| Editar solo en el generador | Hecho: los JSON se regeneran con `python3 tools/make_content_w2.py`. También se alineó el prompt de `eclipse` para que regenerar no ensucie `gen/icons_w2.json`. | `tools/make_content_w2.py` |
| `-- 200 0` × 3 semillas | **Hecho** (tabla abajo). | — |
| `-- 100 5` Pesadilla | **Pendiente**. | — |
| Comparativa `base` | **Pendiente**. | — |

### Cambios de diseño que hay que conocer

1. **Osty revive una sola vez por combate** (antes revivía a 1 PV cada turno). Sin esto Claudia ganaba
   el 99 % de las partidas del bot. Se aplica solo con `DB.extra = true`, así que las trazas del web
   (`DB.extra = false`) siguen intactas. Valor en `balance_w2.json` → `osty_revives`.
2. **Overrides de balance solo con `DB.extra`**: `data/balance_w2.json` mezcla recursivamente enemigos,
   cartas, personajes y reliquias. Motivo: los datos base están congelados por las 350 trazas de paridad;
   tocar `data/enemies.json` o `cards.json` las rompe y no tenemos el fuente web para regenerarlas.
3. **Vida inicial ajustada** (override, no JSON base): Zafiro 94, Irene 96, Selene 94, Lia 82, Aurora 72.
   Más `brasa_carmesi` cura 11 y `llave_maestra` da 5 de Cuerda. Es el grueso de la subida de las musas
   que morían en el Acto I/II.
4. **Aurora**: recortado el remate (`aurora_climax` 5→4 de daño por Calor, `supernova` 1,5→1,35), no la
   generación; sigue siendo la más alta pero dentro de banda.

---

## 2. Números actuales (3 semillas × 200 partidas, Pesadilla 0)

```sh
for s in 1 2 3; do
  godot --headless --path . --script tests/balance.gd -- 200 0 all $s
done
```

| Musa | Media | Rango |
|---|---|---|
| Zafiro | 39,0 % | 36,0–40,5 |
| Lia | 39,2 % | 36,0–41,0 |
| Claudia | 40,2 % | 36,5–45,5 |
| Aurora | 41,2 % | 39,0–42,5 |
| Irene | 32,8 % | 32,0–34,5 |
| Selene | 35,8 % | 33,0–39,5 |

- **Diferencia entre musas: 8,3 puntos** (objetivo ≤ 15). ✅
- Victorias del bot: 32,8–41,2 % de media; objetivo 35–50. **Irene se queda ~2 puntos corta** y Selene
  roza el mínimo. No tocar a ciegas: primero las partidas humanas.
- Muertes en Acto I (total de las 3 semillas): ≈ 24 % de las partidas (objetivo ≤ 30). ✅
- Jefes (media): `crabking` 17,5 % (objetivo 20–28), `drowncaptain` 20,3 % ✅, `mycelking` 25,7,
  `rootmother` 21,2, `queen` 21,5, `waxcolossus` 25,6.
- Élites (media): `chainwarden` 9,1 ✅, `tentacle` 12,2 ✅, `treant` 10,3 ✅, `royalguard` 10,9 ✅,
  `sirena` 7,5, `stag` 6,5, `hornet` 5,7, `mantis` 4,2, `hivemind` 1,4 (estos cuatro, cortos).
- PV por encuentro (media): Acto I **2,8 / 9,5** (fácil corto: objetivo 3–5), Acto II 4,0 / 10,4 ✅,
  Acto III 3,7 / 8,6 ✅.

Comparativa con el punto de partida del roadmap (bot viejo): Claudia 70 %, Aurora 50 %, Selene 37,5 %,
Lia 27,5 %, Zafiro 20 %, Irene 17,5 %. **No es directamente comparable**: el bot cambió a propósito.
La comparación honesta es contra el mismo bot con `base` (pendiente).

### Sobre las reliquias

`balance.gd` imprime el delta de cada reliquia frente a su grupo (misma musa y rareza), pero **la métrica
tiene sesgo de supervivencia**: para tener una reliquia común hay que haber ganado combates, así que casi
todas salen positivas. Con las 3 semillas siguen por encima de +8 `perla_negra`, `luna_violeta`,
`caracola_abismal`, `orichalcum`, `vajra`, `corazon_laton`, `cetro_maremoto`, `nucleo`, `pozo`,
`eclipse`, `corona_espinas`, etc. Antes de seguir nerfeando hay que **arreglar la métrica** (ideal:
guardar el piso en que se obtuvo cada reliquia y comparar contra partidas que llegaron a ese piso).
No nerfear más a ciegas.

---

## 3. Pendiente, en orden sugerido

1. **Revisar el diff y commitear** (no hay commits nuevos). Sugerencia de commits:
   1. `fix(save): escritura atómica, copia .bak y tolerancia a corrupción` (`meta.gd`, `save_test.gd`, `crash_*`).
   2. `test(balance): bot con políticas por musa y volcado por partida` (`balance.gd`).
   3. `balance: overrides de la oleada 2 (Osty, jefes, élites, reliquias, vida inicial)` (`balance_w2.json`, `db.gd`, `eng.gd`, `relics.gd`, `make_content_w2.py`, `enemies_extra.json`).
   4. `docs: traspaso de fase 0/1` (`HANDOFF_FASE01.md`, `ROADMAP.md`).
2. **Pasada de interfaz con las 6 musas** (Fase 0): una normal y una en fácil con Zafiro (para el deshacer).
   ```sh
   XDG_DATA_HOME=/tmp/vdm_pt godot --path . res://tests/playthrough.tscn -- <musa> 1 20
   XDG_DATA_HOME=/tmp/vdm_pt godot --path . res://tests/playthrough.tscn -- zafiro 1 20 god 0 easy
   XDG_DATA_HOME=/tmp/vdm_pt godot --path . res://tests/playthrough.tscn -- <musa> 1 20 god 0 "" dragon
   ```
   Revisar también a ojo los 7 puntos de riesgo y la revisión visual 1280×720 del handoff de la Oleada 2.
3. **Pesadilla 5**: `godot --headless --path . --script tests/balance.gd -- 100 5` (objetivo razonable:
   sin errores y sin que el bot se quede a 0 %; no hay banda definida todavía).
4. **Comparativa `base`**: mismo bot y mismas semillas con el contenido original.
   ```sh
   godot --headless --path . --script tests/balance.gd -- 200 0 all 1 base
   ```
   Ojo: con `base` no existen los overrides ni la Oleada 2, así que sirve para medir el delta de la oleada,
   no para validar los ajustes.
5. **18 partidas humanas** (3 por musa) y decidir si Irene necesita otro empujón. Anotar piso y causa.
6. **Cerrar los flecos numéricos** que queden tras las humanas: `crabking` está 2,5 puntos bajo la banda
   y el Acto I fácil cuesta 2,8 PV (objetivo 3–5); `hivemind`/`mantis`/`hornet`/`stag` siguen fáciles.
   Los números se tocan en `tools/make_content_w2.py` (`BALANCE` y `ENEMIES`) y se regeneran.
7. **Arreglar la métrica de reliquias** antes de otra ronda de nerfs (ver arriba).

---

## 4. Archivos tocados

Modificados:
`data/enemies_extra.json`, `scripts/core/db.gd`, `scripts/core/meta.gd`, `scripts/engine/eng.gd`,
`scripts/engine/relics.gd`, `tests/balance.gd`, `tests/save_test.gd`, `tools/make_content_w2.py`.

Nuevos:
`data/balance_w2.json`, `tests/crash_reader.gd`, `tests/crash_reader.tscn`,
`tests/crash_writer.gd`, `tests/crash_writer.tscn`, `HANDOFF_FASE01.md`, `ROADMAP.md` (estaba sin commitear).

Comprobaciones verdes al pausar: `run_traces` 350/0, `risk` 892/0, `events_test` 126.504/0,
`history_test` OK, `ui_risk_test` OK, `save_test` OK, `CRASH_SAVE OK`.

## 5. Trampas conocidas

- **No editar a mano** `data/enemies_extra.json` ni `data/balance_w2.json`: se regeneran con
  `python3 tools/make_content_w2.py`.
- Las trazas usan `DB.extra = false`; cualquier cambio de balance tiene que ir en `balance_w2.json`
  (o en `ENEMIES`, que solo se carga en partida) para no romper la paridad.
- `tests/save_test.tscn` a veces falla al crear el swapchain de Vulkan si hay otra ventana de Godot;
  ejecutarlo con `--headless` (funciona igual).
- El bot de `playthrough.gd` es aleatorio; sirve de humo de interfaz, no de balance. El de `balance.gd`
  es el que mide.
- `user://balance_runs.json` se sobrescribe en cada ejecución: si se quieren conservar los volcados,
  copiarlo antes (ruta: `~/.local/share/godot/app_userdata/Verso de Musas/balance_runs.json`).
