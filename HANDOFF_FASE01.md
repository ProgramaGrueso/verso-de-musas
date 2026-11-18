# Traspaso · Fase 0 y Fase 1 (pausa 2026-11-18)

Rama: `ccr-a7209c0c-soukyo`. Todo lo de abajo está **sin commitear** (working tree sucio a propósito:
el siguiente paso es revisar y hacer uno o varios commits). Este documento permite retomar sin releer
la conversación. El plan sigue en `ROADMAP.md`; aquí va el estado real medido.

Resumen: **Fase 0 cerrada salvo la revisión visual a ojo** y **Fase 1 con la curva ya dentro de banda en
las 3 semillas**, con Pesadilla 5 y comparativa `base` hechas; pendiente la referencia humana (18 partidas).

---

## 1. Qué se hizo (y dónde)

### Fase 0 · Beta fiable

| Punto del roadmap | Estado | Dónde |
|---|---|---|
| `--import` y `.uid` | Hecho. No aparecieron `.uid` nuevos; ya estaban commiteados. | — |
| `run_traces` 350 ok | Hecho: **350 ok, 0 fallan** (última ejecución tras todos los cambios). | `tests/run_traces.gd` |
| `playthrough` 6 musas + fácil + semilla | **Hecho**: 6 musas en normal (todas murieron en el jefe del Acto I salvo Aurora, que llegó al 26), 1 en fácil con `god` y semilla (`dragon`) que **ganó usando 19 deshaceres**, y 1 normal con semilla. Sin `SCRIPT ERROR`; solo el aviso de recursos vivos al salir. Queda la revisión visual a ojo. | `tests/playthrough.gd` |
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
| `-- 100 5` Pesadilla | **Hecho**: 1,0–6,0 % de victorias, sin errores; las muertes se concentran en el Acto I (65–79 de 100). | — |
| Comparativa `base` | **Hecho**: delta grande de la oleada (tabla abajo). | — |

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

### Pesadilla · escalera rediseñada (10 niveles)

La versión anterior tenía tres muros y dos niveles muertos. Medido con 100 partidas por musa y semilla 1
(media de las 6 musas):

| Nivel | Efecto (versión antigua) | Media | Coste del escalón |
|---|---|---|---|
| 0 | — | 38,9 % | — |
| 1 | +10 % PV | 27,7 % | −11,3 |
| 2 | +10 % daño | 16,2 % | −11,5 |
| 3 | Duda | 10,0 % | −6,2 |
| 4 | −25 % oro | 10,3 % | +0,3 (ruido) |
| 5 | élites/jefes +2 Fuerza | 3,0 % | −7,3 |
| 6 | hoguera 20 % | 2,7 % | −0,3 |
| 7 | +25 % PV | 0–3 % | — |
| 10 | +1 Fuerza a todos, +4 a jefes | **0 %** (0 de 600) | — |

**El problema no era el techo (10), era el reparto:** los niveles 1, 2 y 5 se llevaban 30 de los 36
puntos y el 4 y el 6 no hacían nada. La Pesadilla termina en 10 —el logro «El Fin de la Canción» y el
desenlace cierran ahí— y no se amplía a 20.

**Escalera nueva** (`data/balance_w2.json` → `nm`; leída solo con `DB.extra`, un cambio por nivel):

| Nivel | Efecto |
|---|---|
| 1 | Los enemigos infligen +3 % de daño |
| 2 | Ganas un 15 % menos de oro |
| 3 | Los enemigos tienen +3 % de PV |
| 4 | La hoguera cura solo un 25 % |
| 5 | Los enemigos infligen +6 % de daño (total) |
| 6 | Cada combate empieza con una Herida |
| 7 | Los enemigos tienen +6 % de PV (total) |
| 8 | Empiezas con la maldición Duda |
| 9 | Los élites empiezan con +1 de Fuerza |
| 10 | Los jefes empiezan con +1 de Fuerza |

Curva medida (200 partidas por musa, semilla 1 y 2; media de las 6 musas):

| Nivel | Semilla 1 | Semilla 2 |
|---|---|---|
| 0 | 38,7 % | 36,5 % |
| 1 | 36,3 % | 37,4 % |
| 2 | 35,5 % | 35,2 % |
| 3 | 31,2 % | 32,2 % |
| 4 | 29,8 % | 30,8 % |
| 5 | 26,9 % | 24,7 % |
| 6 | 22,2 % | 21,6 % |
| 7 | 17,6 % | 15,5 % |
| 8 | 13,7 % | 13,2 % |
| 9 | 11,6 % | 11,2 % |
| 10 | 8,7 % | 7,2 % |

- Ningún escalón cuesta más de ~6 puntos (antes había dos de 11 y uno de 7,3).
- **NM10 ≈ 8 %**: se puede ganar, pero hay que jugarlo bien. En la versión anterior era 0 de 600.
- Los niveles 2 y 4 (oro y hoguera) apenas mueven al bot porque valora poco la economía; a un humano le
  pesan más. Las PV cuestan ~1,7 veces más que el daño, por eso la escalera reparte dos escalones de PV
  y dos de daño en vez de cargar todo en los primeros niveles.

Verificación: `balance.gd -- 200 sweep all 1` imprime la curva 0→10 en una tabla y `tests/nm_test.gd`
comprueba 10 niveles, un cambio por escalón, monotonía y que ningún salto de PV/daño pase de 5 puntos.
Las 350 trazas siguen intactas: sin `DB.extra` se usa la tabla antigua.

### Delta de la oleada 2 (mismo bot, semilla 1, 200 por musa, `base`)

| Musa | `base` | con oleada 2 | Delta |
|---|---|---|---|
| Claudia | 88,5 % | 38,5 % | −50,0 |
| Lia | 5,0 % | 41,0 % | +36,0 |
| Zafiro | 7,5 % | 36,0 % | +28,5 |
| Irene | 4,5 % | 34,5 % | +30,0 |
| Selene | 7,0 % | 39,5 % | +32,5 |
| Aurora | 32,0 % | 42,5 % | +10,5 |

`base` es el juego sin overrides **ni** contenido de la oleada 2, así que no sirve para validar los
ajustes, solo para medir cuánto mueve la oleada. Lo que explica el salto no es el contenido nuevo sino
los cambios de encuentros (en `base` `vinelasher+vinelasher+sporecap` cuesta 32,9 PV y termina 161
partidas) y la vida inicial. Claudia va al revés porque en `base` Osty revivía cada turno: el override
es justo lo que corrige ese 88,5 %.

Comparativa con el punto de partida del roadmap (bot viejo): Claudia 70 %, Aurora 50 %, Selene 37,5 %,

Lia 27,5 %, Zafiro 20 %, Irene 17,5 %. **No es directamente comparable**: el bot cambió a propósito y
aquella medición era con el contenido nuevo. La comparación honesta es contra el mismo bot con `base`.

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

1. **Revisión visual a ojo** (lo único que queda de la Fase 0). El bot ya pasó por las 6 musas y por una
   partida completa con `god` + fácil + semilla; falta mirar la interfaz:
   ```sh
   XDG_DATA_HOME=/tmp/vdm_pt godot --path . res://tests/playthrough.tscn -- <musa> 1 20
   XDG_DATA_HOME=/tmp/vdm_pt godot --path . res://tests/playthrough.tscn -- zafiro 1 20 god 0 easy dragon
   ```
   Revisar los 7 puntos de riesgo y la revisión visual 1280×720 del handoff de la Oleada 2. Si el bot se
   atasca, deja la captura en `user://stuck.png` y sale con código 1.
2. **18 partidas humanas** (3 por musa) y decidir si Irene necesita otro empujón. Anotar piso y causa.
   Es el hueco de la Fase 1.1: el bot sigue midiendo mejor que antes, pero no sustituye a un humano.
3. **Cerrar los flecos numéricos** que queden tras las humanas: `crabking` está 2,5 puntos bajo la banda
   y el Acto I fácil cuesta 2,8 PV (objetivo 3–5); `hivemind`/`mantis`/`hornet`/`stag` siguen fáciles.
   Los números se tocan en `tools/make_content_w2.py` (`BALANCE` y `ENEMIES`) y se regeneran.
4. **Arreglar la métrica de reliquias** antes de otra ronda de nerfs (ver arriba).
5. **Validar la escalera nueva con humanos**: el rediseño está hecho y el bot pasa de 0 % a ~8 % en NM10,
   pero la banda final es una decisión de diseño. Si a los jugadores de prueba les parece injusto, se
   bajan los dos coeficientes de PV/daño o se mueve Duda al 9. Si les parece blando, se sube el daño del
   nivel 5 y la Fuerza de jefes del 10.

---

## 4. Archivos tocados y commits

Commits de la sesión (rama `ccr-a7209c0c-soukyo`):

| Commit | Contenido |
|---|---|
| `a4eaf01` | `fix(save)`: escritura atómica, `.bak`, tolerancia a corrupción, tests de `kill -9`. |
| `e9bd0ff` | `test(balance)`: bot con políticas por musa y volcado por partida. |
| `610707a` | `balance`: overrides de la oleada 2 (`balance_w2.json`, `DB._deep`, Osty, jefes, élites, reliquias, vida). |
| `62e0422` | `docs`: roadmap y este traspaso. |
| `0cb52f2` | `test(playthrough)`: contadores del resumen y captura de atasco en `user://`. |
| `c902ec0` | `docs`: cierra la pasada de interfaz y añade Pesadilla 5 y comparativa `base`. |
| `1c490d1` | `docs`: mide Pesadilla 7 y 10. |
| `ae1553b` | `docs`: corrige la meta (10, no 20) y añade el coste por nivel. |
| `0eff052` | `balance(nm)`: escalera de Pesadilla rediseñada, en datos y sin muros. |

Modificados: `data/enemies_extra.json`, `data/balance_w2.json`, `scripts/core/db.gd`,
`scripts/core/meta.gd`, `scripts/engine/eng.gd`, `scripts/engine/relics.gd`, `tests/balance.gd`,
`tests/save_test.gd`, `tests/playthrough.gd`, `tools/make_content_w2.py`.

Nuevos: `tests/crash_reader.gd(.uid)`, `tests/crash_reader.tscn`, `tests/crash_writer.gd(.uid)`,
`tests/crash_writer.tscn`, `tests/nm_test.gd(.uid)`, `HANDOFF_FASE01.md`, `ROADMAP.md`.

Comprobaciones verdes: `run_traces` 350/0, `risk` 892/0, `events_test` 126.504/0, `history_test` OK,
`ui_risk_test` OK, `save_test` OK, `CRASH_SAVE OK`, `seed_test` 0 fallan, `nm_test` 0 fallan,
`playthrough` 6 musas + fácil con victoria y 19 deshaceres + una a NM5, `balance` 1200 partidas × 3
semillas y barridos de la escalera (200/musa, semillas 1 y 2) con 0 errores.

## 5. Trampas conocidas

- **No editar a mano** `data/enemies_extra.json` ni `data/balance_w2.json`: se regeneran con
  `python3 tools/make_content_w2.py`.
- Las trazas usan `DB.extra = false`; cualquier cambio de balance tiene que ir en `balance_w2.json`
  (o en `ENEMIES`, que solo se carga en partida) para no romper la paridad.
- `tests/save_test.tscn` a veces falla al crear el swapchain de Vulkan si hay otra ventana de Godot;
  ejecutarlo con `--headless` (funciona igual).
- El bot de `playthrough.gd` es aleatorio; sirve de humo de interfaz, no de balance. El de `balance.gd`
  es el que mide. Pierde casi siempre en el jefe del Acto I: para recorrer los tres actos hay que usar
  `god` (4000 PV) y una velocidad alta (`20`–`30`).
- `playthrough.gd` imprime el resumen de la partida al final (`combats/events/wins/losses`) y, si se
  atasca, guarda `user://stuck.png` y sale con código 1.
- `user://balance_runs.json` se sobrescribe en cada ejecución: si se quieren conservar los volcados,
  copiarlo antes (ruta: `~/.local/share/godot/app_userdata/Verso de Musas/balance_runs.json`).
