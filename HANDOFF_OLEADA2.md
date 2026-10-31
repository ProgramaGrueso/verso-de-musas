# Traspaso · Oleada 2 (para el agente con ComfyUI y Godot)

Rama: `ccr-a7209c0c-soukyo`. Este trabajo se hizo **sin poder ejecutar Godot**: el entorno no permitía lanzar el binario.
Todo el GDScript nuevo o tocado pasa el parser de `gdtoolkit` (sintaxis de Godot 4), y se ha revisado a mano el tipado
(`:=` sobre valores sin tipo). Pero **nada se ha compilado ni probado dentro del motor**. Tu primera tarea es compilar y probar;
después vienen el arte y el equilibrio.

## Qué hay de nuevo

| Área | Dónde | Resumen |
|---|---|---|
| Eventos | `data/events_extra.json`, `EventsLogic._options_w2` | 17 eventos nuevos (24 en total): 5 generales, 2 por acto y 6 exclusivos de musa (bendiciones permanentes `G.perm`). |
| Enemigos | `data/enemies_extra.json`, `Eng._ai_custom` | Por acto: 1 jefe (`drowncaptain`, `mycelking`, `waxcolossus`), 1 élite (`sirena`, `mantis`, `hornet`) y 1 normal (`eel`, `brambwolf`, `workerbee`). |
| Encuentros | `RunGen.encounter_game` | Los 3 primeros combates normales de cada acto salen de `easy` y el resto de `hard`, sin repetir el anterior. El jefe se sortea al crear el mapa (`G.bossId`) y se muestra en él con su retrato. |
| Reliquias | `data/relics_extra.json`, `scripts/engine/relics.gd`, `eng.gd` | 26 nuevas: poco comunes, raras, de jefe y 2-3 por musa. Rareza al azar en `Eng.random_relic_tiered`; tienda con común + poco común + poco común/rara. |
| Pociones | ídem | 8 nuevas (eco, mejorar mano, malabarista, agilidad, espinas, savia/Regeneración, bomba, memoria). |
| Historial | `scripts/ui/screens/history_screen.gd`, `Meta.record_run` | Estadísticas por musa, cartas más jugadas, retos diarios y detalle de las últimas 60 partidas. |
| Semillas | `Eng.seed_from_text`, `Eng.act_seed`, selección de musa | La misma semilla repite los tres mapas (cada acto reinicia el RNG con `act_seed`). La entidad del Favor también sale de la semilla. |
| Reto diario | `scripts/engine/daily.gd`, menú principal | Semilla, musa y modificador sacados de la fecha local. Resultados en `Meta.data.daily`. |
| Combate | `combat_screen.gd` | Daño entrante sobre la barra de vida; **deshacer** la última carta en modo fácil (botón o Z); atajos Q/W/R/T (pociones), D/S/X (pilas), M (mazo), H/F1 (ayuda). |
| Equilibrio | `tests/balance.gd` | Simulador sin interfaz: % de victorias por musa y Pesadilla, dureza de jefes/élites, encuentros que más matan y reliquias. |
| Respaldos | `Icons.emoji`, `EnemyView.EMOJI` | Sin arte, reliquias/pociones/enemigos se ven con emoji, así que el juego funciona antes de generar las imágenes. |

Todo el contenido nuevo depende de `DB.extra`: con `DB.extra = false` (trazas de paridad) el motor sigue el camino original.

## 1. Compilar y probar (primero de todo)

```sh
godot --headless --path . --import            # registra las clases nuevas (Daily, HistoryScreen) y crea los .uid
godot --headless --path . --script tests/run_traces.gd     # debe seguir en 350 ok, 0 fallan
godot --headless --path . --script tests/balance.gd -- 30 0   # comprobación rápida: no debe haber errores de script
godot --path . res://tests/playthrough.tscn -- zafiro 2 8      # bot por la interfaz real (repetir con cada musa)
```

- Haz commit de los `.uid` nuevos (`scripts/engine/daily.gd.uid`, `scripts/ui/screens/history_screen.gd.uid`, `tests/balance.gd.uid`).
- Si `run_traces` falla, el culpable está en un cambio del motor que se ejecuta también con `DB.extra = false`. Los candidatos son
  `add_status`, `draw_cards` (gancho `onShuffle`), `kill_enemy` (`onKill`), `_player_down`, `play_card` (eco y recuento) y
  `start_combat` (`apply_perm`). Ninguno debería cambiar nada sin las reliquias nuevas.
- Para el bot de interfaz, prueba también una partida en **modo fácil** (deshacer) y una con semilla.

### Puntos con más riesgo (revísalos a mano en partida)
1. **Deshacer** (`Eng.snapshot` / `Eng.restore` y `CombatScreen.undo`): juega una carta con objetivo, una que descarte o agote
   (diálogo), una de Selene con orbes y una de Claudia con Osty, y deshaz cada una. No debe aparecer si muere un enemigo.
2. **Cristal de Eco / Destilado de Eco** (`Eng._echo`): cartas de coste X, cartas con objetivo cuyo objetivo muere en la primera
   pasada, Poderes, y cartas con diálogo de descarte o agotar (`ask_prompt` puede llamarse dos veces).
3. **Pluma de Fénix**: muerte por ataque, por Espinas enemigas (`deal_to_enemy`) y por `selfdmg` de una carta.
4. **Eventos con `await`** (`biblioteca`, `recuerdo`, `espejo`, `trono`, `coliseo`…): elegir y también cancelar cada diálogo.
5. **Reloj Detenido** en una hoguera sin cartas mejorables: debe aparecer «Seguir el camino ➜».
6. **Medallón del Boticario**: 4 huecos de poción (barra superior y tecla T).
7. **Historial**: termina una partida ganando, perdiendo y rindiéndote; abre el detalle de cada una.

## 2. Arte (ComfyUI)

### Enemigos y fondos de eventos: `gen/jobs_w2.json` (26 trabajos)
Mismo formato que `gen/jobs_fix.json` y `jobs_favor.json`: `gen/comfy.py` con `karen_krea2.safetensors`. Cada trabajo
trae un campo `out` con la ruta final.

- **9 enemigos** → `assets/enemies/<id>.webp`, **RGBA sin fondo** (recórtalos con rembg, como hace `tools/cut_icons.py`) y unos
  **520 px en el lado mayor**, como los actuales (p. ej. `crabking.webp` mide 520×485). Los jefes salen a 640×640: recórtalos y
  escálalos igual.
  - Deben **mirar a la izquierda**, hacia la musa. Si alguno sale mirando a la derecha, añade su id a `EnemyView.FLIP`.
  - `drowncaptain`, `mycelking` y `waxcolossus` también se ven en el mapa, a la derecha del nodo del jefe (`MapScreen._add_node`).
- **17 fondos de evento** → `assets/bg/ev_<id>.webp`, 1280×720, RGB (como `ev_duelo.webp`).

### Iconos: `gen/icons_w2.json` (26 reliquias + 8 pociones + 1 estado)
`tools/gen_icons.py` ya los incluye y se salta los que ya existen:
```sh
python3 tools/gen_icons.py relic potion status
uv run --python 3.12 --with "rembg[cpu]" --with pillow python tools/cut_icons.py
```
Salida: `assets/icons/relic_<id>.webp`, `potion_<id>.webp` y `status_regen.webp` (192 px, RGBA).

### Otros extras de arte (opcionales)
- Retratos en la Galería o capítulos de lore para los jefes nuevos: hoy `data/lore.json` solo conoce los tres originales.
- El texto final de `EndingScreen` y de `data/lore.json` (`ending`) habla de la Reina de la Colmena. `EndScreen` ya usa el jefe
  real (`RunGen.boss_id`), pero la cinemática del final no.

## 3. Revisión visual (1280×720)
- **Menú principal** con partida guardada: 8 botones (Continuar, Nueva partida, Reto diario, Historial, Galería, Cómo jugar,
  Opciones, Salir) en formato compacto. Comprueba que no se sale por abajo ni pisa el aviso de Pesadilla.
- **Selección de musa**: la barra inferior lleva ahora «Modo fácil» y el botón «Semilla: …». Prueba el diálogo de texto (Enter y Esc).
- **Combate**: el texto de daño entrante (`incoming_lbl`, y=328 en `player_box`) no debe tapar la cabeza de musas altas como
  Zafiro o Aurora. El botón «↶ Deshacer (Z)» (1090, 432) no debe chocar con «Terminar turno».
- **Tienda**: ahora caben 3 reliquias; mira que la fila central (neutrales + reliquias + pociones + eliminar) no se salga de 1200 px.
- **Mapa**: el retrato del jefe (220×200) a la derecha del nodo, y la etiqueta con su nombre (220 px de ancho).
- **Historial** y **pantalla final** (con victoria hay 4 botones de tamaño normal).

## 4. Equilibrio
```sh
godot --headless --path . --script tests/balance.gd -- 200 0      # ~1200 partidas
godot --headless --path . --script tests/balance.gd -- 100 5
```
El bot es simple: sirve para **comparar**, no como valor absoluto. Objetivos orientativos:
- En cada acto, el **% de derrotas contra el jefe nuevo** debería quedar a ±5 puntos del jefe original del mismo acto. Lo mismo
  para los élites.
- Los encuentros `easy` deben costar claramente menos PV de media que los `hard` (sección «Normales más duros»).
- Ninguna reliquia nueva debería disparar el % de victorias de las partidas que la tienen. Vigila especialmente `cristal`,
  `corona_espinas`, `reloj_roto`, `capa_sombra`, `eclipse`, `luna_violeta` y `corazon_volcan`.
- Las diferencias entre musas no deberían crecer respecto a antes de la oleada.

Los números se tocan en `tools/make_content_w2.py` (PV, movimientos, encuentros). Después: `python3 tools/make_content_w2.py`.
Los efectos de reliquias y pociones están en `scripts/engine/relics.gd`; los de eventos, en `scripts/engine/events.gd`.

## 5. Ideas que quedaron fuera
- Música propia para los jefes nuevos (hoy usan la pista de jefe del acto).
- Más modificadores del reto diario (`Daily.MODS`) y un marcador compartido, que necesitaría servidor.
- Deshacer más de una carta.
