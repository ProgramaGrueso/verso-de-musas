# HANDOFF · Agente E (Fase 4 restante: poda del pool y 2 arquetipos por musa) · 2026-11-20

Dueño exclusivo de: `data/`, `tools/`, `scripts/engine/`, `scripts/core/` (reglas/contenido), `tests/balance.gd`
y tests de contenido/balance. No toca `scripts/ui/*`, `assets/` ni tests de UI. Sin commits.

## 0 · Medición (herramienta) — HECHO
`tests/balance.gd` ahora recoge, sin cambiar el juego del bot por defecto (verificado: `-- 100 0 all 1` da
exactamente 34/38/38/38/34/40 % antes y después de instrumentar):
- **Oferta/elección por carta** en recompensas (`card_st`), presencia en el mazo final (`deck_st`) y
  **victorias por arquetipo** (`arch_st`). Todo va a `user://balance.json` (`cards`, `deck`, `arch`).
- `ARCH` (const al principio del archivo): 2 arquetipos por musa con sus cartas núcleo.
- Variables de entorno (sin ellas, el bot es el de siempre):
  - `VDM_ARCH=1`: el bot se compromete con un arquetipo (alterna A/B por partida), +7 a sus cartas en la
    recompensa (−2 a las del otro) y compra en tienda las de su plan. Da el **% de victorias por arquetipo forzado**.
  - `VDM_EXPLORE=1`: elige al azar entre las 3 cartas y «saltar». La columna **Δcoger** = % victorias si la
    cogió − % si se la ofrecieron y no; es el valor causal de la carta sin el sesgo de la heurística de rareza.
  - `VDM_CARDS=1`: imprime la tabla de cartas completa.
- Arreglo del bot (afecta solo a Selene): Evocar sin orbes valía 5 puntos; ahora 0 (no lo juega en vacío).
- Scripts de medida (scratchpad, no van al repo): `measure.sh <tag> 1000` (4 semillas en paralelo, cada una
  con su `XDG_DATA_HOME`) y `agg.py <tag> [<tag_despues>] [--cards musa] [--arch]`.

Comandos:
```sh
godot --headless --path . --script tests/balance.gd -- 1000 0 all <semilla>                 # por defecto
VDM_ARCH=1 godot --headless --path . --script tests/balance.gd -- 1000 0 all <semilla>      # arquetipos
VDM_EXPLORE=1 VDM_CARDS=1 godot --headless --path . --script tests/balance.gd -- 1000 0 all <semilla>
```

## 1 · Línea base (4 semillas × 1000 partidas por musa, Pesadilla 0)

| musa | victorias (bot normal) | arquetipo A forzado | arquetipo B forzado |
|---|---|---|---|
| zafiro | 34,0 % | fuerza 26,4 % | coraza 41,1 % |
| lia | 36,8 % | veneno 46,3 % | cuchillas 28,9 % |
| claudia | 39,9 % | osty 43,0 % | agotar 33,0 % |
| aurora | 37,6 % | calor 28,9 % | luz 64,2 % |
| irene | 29,5 % | engranajes 75,5 % | descarga 17,2 % |
| selene | 34,8 % | evocar 27,7 % | marea 47,7 % |
| **global** | **35,4 %** | | |

Élites en conjunto 8,5 % de derrotas, jefes 22,6 %.

Hallazgo clave: **Irene no es débil, el bot la construye mal**: su heurística de recompensa premia `windSpend`
(+3) y el bot coge Liberar (85 %), Descarga de Muelle (79 %), Sobrecarga (79 %) y Sobrecuerda (76 %), que tienen
Δcoger negativo (−5 a −18). Forzada a engranajes gana el 75 %.

## 2 · Ronda 1 (arquetipos) — HECHO
Cambios en `tools/make_content_w2.py` → `CARD_TUNING` (se fusiona en `BALANCE["cards"]`, sale en
`data/balance_w2.json`; solo con `DB.extra`, las trazas base no cambian):
Irene Liberar windSpend 3→5, Descarga de Muelle 2→3, Autómata Colosal 20/20→16/16 · Aurora Pétalo de Brasa y
Giro de Llamas Calor 1→2, Abrasar Resplandor 3→2 · Lia Destripar y Vals de Cuchillas coste 2, Aguja Paralizante
Débil 2→1 · Zafiro Sangre Antigua Fuerza 2, Flexionar Fuerza temporal 3 · Claudia Abrazo Oscuro coste 1 (mejora 0),
Pira 12→10 · bot: Evocar sin orbes = 0.

| musa | victorias base → R1 | A forzado base → R1 | B forzado base → R1 |
|---|---|---|---|
| zafiro | 34,0 → 40,2 | fuerza 26,4 → 34,6 | coraza 41,1 → 43,1 |
| lia | 36,8 → 39,3 | veneno 46,3 → 44,9 | cuchillas 28,9 → 35,2 |
| claudia | 39,9 → 38,9 | osty 43,0 → 43,2 | agotar 33,0 → 33,0 |
| aurora | 37,6 → 36,6 | calor 28,9 → 31,4 | luz 64,2 → 61,5 |
| irene | 29,5 → 36,6 | engranajes 75,5 → 73,2 | descarga 17,2 → 23,1 |
| selene | 34,8 → 37,6 | evocar 27,7 → 28,1 | marea 47,7 → 50,1 |
| **global** | **35,4 → 38,2** | | |

Élites 8,5 → 7,6 %, jefes 22,6 → 21,1 %.

## 3 · Ronda 2 (arquetipos) — HECHO
Irene Sobrecuerda autodaño 3→1, Sobremarcha 4→2, Mecanismo de Resorte 1→2 Cuerda/turno (mejora 3), Obra Maestra
24→20 (mejora 26), Cadena de Relojería 4→3 ×3 (mejora 4) · Aurora Corona coste 3 (mejora 2), Eclipse Dorado coste 2 ·
Selene Resaca coste 0, Carga de Profundidad coste 1, Maremoto coste 1 (mejora 0).

| musa | victorias R1 → R2 | A forzado R1 → R2 | B forzado R1 → R2 |
|---|---|---|---|
| aurora | 36,6 → 37,0 | calor 31,4 → 34,5 | luz 61,5 → 62,2 |
| irene | 36,6 → 37,8 | engranajes 73,2 → 69,5 | descarga 23,1 → 28,4 |
| selene | 37,6 → 43,8 | evocar 28,1 → 43,0 | marea 50,1 → 49,5 |
| (resto sin cambios) | | | |
| **global** | **38,2 → 39,5** | | |

Élites 7,6 → 7,1 %, jefes 21,1 → 20,6 %. Selene ya tiene dos arquetipos viables.

## 4 · Ronda 3 (arquetipos + poda de neutrales) — HECHO
- Irene Tic-tac Cuerda 1→2 (mejora 3), Carillón +3/Cuerda (mejora 4), Cuerda Rápida sin autodaño, Mecanismo Fino
  Precisión 2→1 (mejora 2) · Aurora Deslumbrar Resplandor 2→1 (mejora 2), Clímax 4→5 por Calor · Claudia Presagio coste 0.
- **Poda del pool neutral** (Δcoger medio en las 6 musas, VDM_EXPLORE, 4×1000):
  - Retiradas del pool (definición conservada; `RETIRED` en `tools/make_cards_w1.py`): Carga Desesperada (−10,3 ±1,4;
    negativa en las 6 musas) y Pausa Estratégica (−6,5 ±1,5). Ya no salen en recompensas, tienda, desbloqueos ni
    en el compendio (que lista `DB.neutral`).
  - Dominantes, bajan: Segunda Oportunidad (+15,6) curar/bloquear 12→10 (mejora 14); Bomba de Humo (+12,3) Débil 2→1 (mejora 2).
  - Flojas, más baratas: Marca del Cazador (−4,8) y Rebusca (−4,0) coste 0; Todo o Nada (−5,9) autodaño 2→1.
  - Quedan 21 neutrales (10 comunes; progress_test exige ≥ 8).

| musa | victorias R2 → R3 | A forzado R2 → R3 | B forzado R2 → R3 |
|---|---|---|---|
| zafiro | 40,2 → 41,8 | fuerza 34,6 → 35,1 | coraza 43,1 → 44,6 |
| lia | 39,3 → 40,8 | veneno 44,9 → 49,9 | cuchillas 35,2 → 38,0 |
| claudia | 38,9 → 40,8 | osty 43,2 → 42,5 | agotar 33,0 → 36,5 |
| aurora | 37,0 → 40,2 | calor 34,5 → 36,0 | luz 62,2 → 61,1 |
| irene | 37,8 → 43,3 | engranajes 69,5 → 69,0 | descarga 28,4 → 39,2 |
| selene | 43,8 → 44,4 | evocar 43,0 → 42,5 | marea 49,5 → 52,5 |
| **global** | **39,5 → 41,9** | | |

Élites 7,1 → 7,1 % (por debajo de la banda 8–12), jefes 20,6 → 19,3 %.

## 5 · Ronda 4 — HECHO (carta nueva descartada)
- Carta nueva **Aurora · Última Ascua** (`aurora_last_ember`, ataque común, coste 1: 4 de daño + consume Calor +3/carga;
  mejora 6 / +4). Arte reutilizado `img: card_aurora_ember_petal` (provisional). Definida en `FASE4` de `tools/make_cards_w1.py`.
- Aurora Velo Dorado Bloqueo 7→6 (mejora 9) · Irene Engranaje Suelto 4→3 (mejora 5), Puntada 3→2 (mejora 4).
- Bot: Refracción («pierdes tu Bloqueo») ahora descuenta el Bloqueo perdido frente al golpe entrante.

Resultado R3 → R4: Aurora 40,2 → **36,6** (mazos de calor del bot normal 46 → 41 %), calor forzado 36,0 → 35,9,
luz 61,1 → 59,2; Irene 43,3 → 44,2, engranajes 69,0 → 68,2, descarga 39,2 → 40,2; global 41,9 → 41,4; élites 6,9 %.
**Última Ascua se descarta**: un remate barato que consume todo el Calor se juega pronto y deja sin carga a
Clímax/Supernova. Se conserva el hueco `FASE4` en `make_cards_w1.py` (vacío, con la carta comentada).
Se quedan Velo Dorado, Engranaje Suelto, Puntada y el arreglo del bot de Refracción.

## 6 · Ronda 5 — HECHO
- Aurora Clímax coste 2→1 (heatDmg 5); Tajo de Abanico también da 1 de Calor.
- Élites (con el pool podado bajaron a 7 %): +8 % PV a sirena 106-110, mantis 117-121, hornet 144-148,
  chainwarden 78-82, stag 123-127, hivemind 142-147; jefe del Acto I crabking 142-146 (estaba en 18,7 %, banda 20-28).

| musa | victorias R4 → R5 | A forzado R4 → R5 | B forzado R4 → R5 |
|---|---|---|---|
| zafiro | 41,8 → 40,5 | fuerza 35,1 → 34,4 | coraza 44,6 → 41,7 |
| lia | 40,8 → 40,0 | veneno 49,9 → 49,3 | cuchillas 38,0 → 35,2 |
| claudia | 40,8 → 40,0 | osty 42,5 → 41,5 | agotar 36,5 → 34,5 |
| aurora | 36,6 → 45,5 | calor 35,9 → 45,4 | luz 59,2 → 61,9 |
| irene | 44,2 → 42,1 | engranajes 68,2 → 64,8 | descarga 40,2 → 34,9 |
| selene | 44,3 → 42,4 | evocar 42,8 → 42,4 | marea 53,0 → 51,0 |
| **global** | **41,4 → 41,8** | | |

Élites 6,9 → 7,7 % (chainwarden 8,7, mantis 7,1, sirena 7,1, stag 5,7, hivemind 2,1 sigue inmóvil); crabking 18,9 → 21,0 %.
Ruido entre rondas para musas sin cambios: ±1-3 puntos en el modo forzado (2000 partidas, ±1,1 de error típico).

## 7 · Ronda 6 — HECHO (+ exploración final)
- Irene Obra Maestra 20→17 (mejora 22), Autómata Colosal 16→14 (mejora 18), Tic-Tac 3→4 (mejora 5), Muelle Bloqueo 4→6 (mejora 8).
- Aurora Muro de Refracción 16→14 (mejora 19).
- Élites treant 125-129 y royalguard 153-158 (+5 % PV).

## ⚠ Perfil real de Juan (aviso del coordinador)
Todas las mediciones de balance de este agente (`measure.sh`: R1…R6, base0, A_*) usaron un `XDG_DATA_HOME` propio
por semilla en el scratchpad, así que **no** tocaron el perfil real. Sí se lanzaron **sin** `XDG_DATA_HOME` aislado,
y por tanto pudieron escribir en `~/.local/share/godot/app_userdata/Verso de Musas/` (p. ej. `meta.json`):
- `godot --headless --path . --quit` (arranques de comprobación, ~6 veces);
- `tests/progress_test.gd`, `tests/events_test.gd`, `tests/run_traces.gd`, `tests/risk.gd`, `tests/boss_phase_test.gd` (una vez cada uno, tras la ronda 3);
- `tests/balance.gd -- 5 0 aurora 1` (prueba de humo, ronda 4) y, antes de la compactación de contexto, las pasadas
  de verificación de la instrumentación (`balance.gd -- 100 0 all 1`).
No se ha restaurado ni borrado nada del perfil real: lo decide Juan. Desde este aviso todo godot va con `XDG_DATA_HOME=$(mktemp -d)`.

## 8 · Estado final (R6) frente a la línea base — 4 semillas × 1000 por musa

| musa | victorias base → final | A forzado base → final | B forzado base → final |
|---|---|---|---|
| zafiro | 34,0 → 40,0 | fuerza 26,4 → 34,2 | coraza 41,1 → 42,9 |
| lia | 36,8 → 39,9 | veneno 46,3 → 47,8 | cuchillas 28,9 → 36,8 |
| claudia | 39,9 → 39,5 | osty 43,0 → 40,3 | agotar 33,0 → 35,0 |
| aurora | 37,6 → 44,6 | calor 28,9 → 43,1 | luz 64,2 → 61,4 |
| irene | 29,5 → 41,4 | engranajes 75,5 → 63,4 | descarga 17,2 → 38,5 |
| selene | 34,8 → 42,5 | evocar 27,7 → 41,5 | marea 47,7 → 49,7 |
| **global** | **35,4 → 41,3** (diferencia entre musas 10,6 → 5,1) | | |

Élites 8,5 → 8,0 % (banda 8–12). Jefes 22,6 → 19,3 %; crabking (Acto I) 23,5 → 21,0 %; drowncaptain 13,7 → 10,7 %
(ya estaba por debajo de la banda 20–28 antes de esta fase).
Neutrales (Δcoger medio, exploración): rango −10,3…+15,6 → −6,6…+8,7.

Verificado (cada uno con `XDG_DATA_HOME` temporal): arranque sin errores de script (queda «2 resources still in use at
exit» por la música del menú, `menu_claudia.ogg`, que viene de los cambios de UI en curso, no de datos);
events_test 143302 comprobaciones 0 fallan; run_traces 350/350; risk 891 0 fallan; boss_phase_test 0 fallan;
progress_test 708 ok; save_test OK; perf_budget_test 19 ok.

## 9 · Pendiente / decisiones para Juan
- **Irene engranajes (63 %) y Aurora luz (61 %)** siguen algo por encima de 60 en modo forzado; los dos arquetipos
  flojos ya son viables (38,5 y 43,1). El siguiente paso sería tocar la Precisión/Engranajes de la base o el −3 de
  daño del Resplandor (motor, afecta a los textos de estado), no más cartas sueltas.
- Cartas aún extremas en la exploración final (Δcoger): Aurora Frenesí −20 y Refracción −18 (cartas base; el bot las juega
  mal, se arregló a medias con Refracción), Lia Tormenta de Cuchillas −21, Selene Multimarea −28 / Ola Colosal −22 /
  Maremoto −18 (raras de evocar), Zafiro Armadura de Ascuas +26, Selene Marea Perpetua +31.
- Hivemind sigue en ~2 % de derrotas con +8 % PV: necesita un cambio de patrón, no números.
- Texto de Supernova: CardText dice «+50 % de daño» pero `heatMul` es 1,35 (UI, no mío).
- Última Ascua (carta nueva) se probó y se descartó; `FASE4` en `make_cards_w1.py` queda listo para otra carta con arte reutilizado.
- Cartas retiradas desaparecen también del compendio (lista `DB.neutral`); si se quieren ver allí, hace falta un cambio de UI.
