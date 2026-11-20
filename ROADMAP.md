# Roadmap · Verso de Musas

Estado: beta v0.9 (solo build de Windows). Este documento ordena el trabajo desde aquí hasta el lanzamiento.
Se actualiza al cerrar cada fase: marcar casillas, anotar la fecha y enlazar el commit.

> **Progreso 2026-11-18:** Fase 0 cerrada salvo la revisión visual a ojo (el bot ya pasó por las 6 musas,
> por una partida en fácil con 19 deshaceres y por una con semilla). Fase 1 con la curva en banda
> (media de 3×200 partidas: 39 / 39 / 40 / 41 / 33 / 36 %, diferencia entre musas 8,3 puntos) y
> comparativa `base` hecha. Pesadilla: escalera de 10 niveles rediseñada en datos, sin muros y con NM10
> pasando de 0 % a ~8 %. Guardado atómico con `.bak`, volcado por partida y overrides solo con `DB.extra`.
> Falta la referencia humana: 3 partidas por musa. Detalle en [`HANDOFF_FASE01.md`](HANDOFF_FASE01.md).

**Principio rector:** no añadir contenido nuevo hasta que la curva de dificultad y la sensación de juego
estén bien. Con 244 cartas, 35 enemigos, 24 eventos, 54 reliquias y 16 pociones el problema ya no es
cantidad: es equilibrio, claridad y progresión a largo plazo.

---

## Punto de partida (medido el 2026-11-17)

```sh
godot --headless --path . --script tests/balance.gd -- 40 0   # 240 partidas, 4,6 s
```

| Musa | Victorias (bot, Pesadilla 0) |
|---|---|
| Claudia | 70,0 % |
| Aurora | 50,0 % |
| Selene | 37,5 % |
| Lia | 27,5 % |
| Zafiro | 20,0 % |
| Irene | 17,5 % |

Hallazgos:

- **El Acto I concentra las muertes** (Zafiro 21/40, Irene 26/40). Los jefes del Acto I
  (`crabking` 35,3 %, `drowncaptain` 38,3 %) duelen el doble que los de los Actos II–III (15–23 %).
- **Los élites son gratis**: 0–4,5 % de derrotas; `chainwarden` (10,5 %) es la excepción.
- **Los encuentros fáciles no cuestan nada**: 1,6 PV de media frente a 7,3 PV los difíciles en el Acto I.
- **Reliquias con delta sospechoso**: `piedra` +33, `fresa` +21, `vela` +17, `huevo` +17,
  `corona_espinas` +17, `nucleo` +16,7, `cuerno` +15,6, `idolo_dorado` +15,2, `vajra` +14.
  Muestras pequeñas y bot simple: confirmar antes de tocar.
- **No hay sistemas de largo plazo**: sin logros, sin desbloqueo de cartas/reliquias (todo el pool está
  disponible desde la primera partida), Pesadilla tope 10, sin localización, sin nube/Steam y solo hay
  preset de exportación para Windows.
- **Cautela con la tabla**: el bot es simple. La brecha Irene/Claudia puede ser complejidad mal explicada
  (Cuerda, orbes) y no solo poder. Por eso la Fase 1 empieza midiendo mejor.

Resumen de prioridad:

| Fase | Impacto | Esfuerzo | Riesgo |
|---|---|---|---|
| 0 · Beta fiable | Alto | 2–3 días | Bajo |
| 1 · Equilibrio | Muy alto | 1 semana | Medio (medir mal) |
| 2 · Sensación y claridad | Muy alto | 2 semanas | Bajo |
| 3 · Progresión y retención | Alto | 2–3 semanas | Medio |
| 4 · Profundidad | Medio | 3–4 semanas | Alto (scope) |
| 5 · Lanzamiento | Alto | 2–3 semanas | Medio |

---

## Fase 0 · Beta fiable (2–3 días)

Objetivo: una base estable sobre la que medir. Sin esto, el resto son conjeturas.

- [x] `godot --headless --path . --import` y commit de los `.uid` nuevos.
- [x] `run_traces`: 350 ok, 0 fallan.
- [x] `playthrough` con las 6 musas; una partida con semilla y una en modo fácil (deshacer).
      *(6/6 sin errores, todas menos Aurora murieron en el jefe del Acto I; la de fácil ganó con 19 deshaceres.)*
- [x] Repasar los 7 puntos de riesgo de `HANDOFF_OLEADA2.md`: deshacer, Eco, Pluma de Fénix, eventos
      con `await`, Reloj Detenido, Medallón del Boticario e Historial.
      *(cubiertos por tests; queda la vuelta manual por interfaz.)*
- [x] Guardado a prueba de balas: copia de `user://save.json` antes de escribir, tolerancia a archivo
      corrupto y prueba de matar el proceso en mitad de un combate.
- [x] Volcado por partida en `tests/balance.gd` (musa, semilla, piso, causa de muerte, mazo) para comparar
      fases con el mismo criterio.

**Salida:** 0 errores en consola, 0 regresiones de paridad, las 6 musas completan una partida y el guardado
sobrevive a un cierre brusco.

---

## Fase 1 · Equilibrio y curva de dificultad (5–7 días)

Objetivo: que la dificultad suba de forma legible y ninguna musa sea una trampa.

### 1.1 Arreglar la medición primero

- [x] Políticas de bot por musa en `tests/balance.gd`: Cuerda (Irene), orbes (Selene), Osty (Claudia),
      Calor/Resplandor (Aurora).
- [ ] 3 partidas humanas por musa (18 en total) como verdad de referencia; anotar piso y causa de muerte.
- [ ] Decidir con esos datos qué es desequilibrio real y qué es “el bot no sabe jugarlo”.

### 1.2 Objetivos numéricos

| Métrica | Objetivo |
|---|---|
| Victorias del bot (normal) | 35–50 % |
| Diferencia entre musas | ≤ 15 puntos |
| Muertes en Acto I | ≤ 30 % de las partidas |
| Derrotas contra jefes del Acto I | 20–28 % |
| Derrotas contra élites | 8–12 % |
| PV perdidos: encuentros fáciles / difíciles | 3–5 / 8–12 |
| Delta de reliquia frente a su grupo | ≤ ±8 puntos |

### 1.3 Cambios

- [x] Suavizar `crabking` y `drowncaptain` (`data/enemies_extra.json`, `_ai_custom`).
- [x] Subir élites: `sirena`, `mantis`, `hornet`, `hivemind`, `royalguard`, `stag`, `treant`.
      *(los cuatro últimos siguen cortos: 1–7 % de derrotas.)*
- [x] Encuentros `easy` con algo de coste real; `hard` sin picos de 18 PV en un normal.
- [x] Reliquias outlier y flojas (`medallon` 38,5 %, `capa_sombra` 40 %).
- [x] Editar siempre en `tools/make_content_w2.py` y regenerar; no a mano en los JSON.

### 1.4 Verificación

- [x] `-- 200 0` con tres semillas distintas.
- [x] `-- 100 5` para Pesadilla. *(antes del rediseño: 1–6 %; la escalera nueva se mide con `-- 200 sweep`.)*
- [x] Comparativa contra `base` (sin Oleada 2) para medir el delta real de la oleada.
      *(ver tabla en el handoff: +10 a +36 puntos salvo Claudia, que baja por el nerf de Osty.)*

**Salida:** tabla antes/después en el commit, ninguna musa fuera de banda, ninguna reliquia con delta > +8.

---

## Fase 2 · Sensación y claridad (2 semanas)

Objetivo: que se entienda y se sienta bien. Es la fase con más impacto por hora invertida.

### 2.1 Juice (combate)

- [x] Hitstop de 60–80 ms en golpes grandes.
- [x] Flash + sacudida al recibir daño; números de daño escalonados.
- [x] Sonidos distintos para Bloqueo, Veneno, orbe, carta pesada y muerte.
- [x] “Slam” al jugar carta y transición clara de fin de turno.

### 2.2 Legibilidad

- [x] Resaltar la reliquia que se dispara (muchas son invisibles hoy).
- [x] Tooltip de buffs/debuffs enemigos al pasar el ratón.
- [x] Aviso de “muerte segura” si el daño entrante supera PV + Bloqueo.
- [x] Previsualización de la mejora de carta antes de gastar la hoguera.

### 2.3 Inspección

- [ ] Clic en reliquia → tooltip (texto y origen).
- [ ] Pilas con filtros (ataque/habilidad/poder) y marca de mejoradas.
- [ ] Mazo consultable desde cualquier sala (`M` ya abre el diálogo; ampliarlo).

### 2.4 Onboarding contextual

- [ ] Minitutorial de Cuerda la primera vez que Irene la gana.
- [ ] Minitutorial de orbes (canalizar/evocar) para Selene.
- [ ] Minitutorial de Osty para Claudia.
- [ ] Minitutorial de Calor/Resplandor para Aurora.
- [ ] Repaso de “Cómo jugar” con una captura o diagrama por concepto.

### 2.5 Accesibilidad

- [ ] Escala de texto.
- [x] Opción “reducir movimiento”.
- [x] **Ningún texto se sale de su caja** (2026-11-19, `7f8c825`): autoajuste de botones (`UIK.fit_button`),
      `UIK.wrap/fit_title/button_row`, herramientas `tests/ui_layout_test` (42 pantallas y 19 diálogos ×
      2 resoluciones) y `tests/ui_shot` (capturas). Ver `HANDOFF.md`.
- [x] **Mando en la tienda** (2026-11-19, `7f8c825`): comprar ya no deja la pantalla sin foco
      (`tests/shop_pad_test`). La auditoría del resto sigue abierta abajo.
- [ ] Auditoría de navegación completa con mando (mapa, recompensas, eventos): la tienda se arregló; falta
      rehacer la pasada completa con `tests/gamepad_test` + `tests/focus_reach` y añadir un test de foco por
      pantalla que se reconstruya (recompensa, hoguera, eventos).
- [ ] Remapeo básico de teclas.

**Salida:** 5 personas nuevas terminan el Acto I sin ayuda externa y ninguna acción de combate queda sin
feedback visual y sonoro.

---

## Fase 3 · Progresión y retención (2–3 semanas)

Objetivo: dar una razón para la partida 20.

- [x] **Logros** (~30) enganchados a las estadísticas que ya guarda `Meta.data.s`. Hecho 2026-11-19: 37 logros
      en 8 categorías (`data/progress.json`, `Progress`), pantalla con medallones, avisos emergentes y
      **Maestría** por musa (6 rangos). Ver `HANDOFF_FASE3.md`.
- [x] **Pesadilla 10 · escalera rediseñada** (el techo es 10, no 20). Un efecto por nivel, en datos
      (`balance_w2.json` → `nm`) y sin muros: ningún escalón cuesta más de ~6 puntos y NM10 pasa de 0 %
      a ~8 % con el bot. Queda validarla con jugadores y decidir si ese 8 % es la banda correcta.
      Extender a 20 solo tendría sentido post-lanzamiento y exigiría lore, logros y desenlace nuevos.
- [x] **Desbloqueo de contenido** (21 grupos de la Oleada 1/2; con `DB.extra=false` no se bloquea nada; Compendio con condición): cartas y reliquias que entran al pool al cumplir hitos. Hoy todo está
      disponible desde el minuto uno, lo que quita la curva de descubrimiento.
- [x] **Reto diario con histórico** (pantalla con calendario, racha, copiar reto y revancha de días pasados): racha local, tabla mensual, semilla compartible y “revancha”.
      El marcador online puede esperar a que haya jugadores.
- [x] **Resumen de partida compartible** («Copiar resumen» y «Revancha» en la pantalla final): musa + semilla + resultado (la semilla ya se copia desde la pausa).

**Salida:** un jugador nuevo tiene objetivos a 1, 5 y 20 partidas; el diario tiene una razón para volver
mañana.

---

## Fase 4 · Profundidad sin inflar (3–4 semanas)

Objetivo: más decisiones, no más cartas.

- [x] **Jefes con fases** o cambio de patrón a mitad de vida (2026-11-19, solo `DB.extra`: los 6 jefes pasan a fase 2 bajo 50 % PV con aviso, golpe nuevo telegrafiado y secuencia propia; victorias 39 % vs 40 % sin fases; ver `HANDOFF_FASE4.md`). Banner de fase 2 en UI: hecho (`combat_screen.gd`, Fase 2).
- [ ] **Variedad de élites** por acto y 1–2 eventos raros por acto que solo salgan una vez por partida.
- [ ] **Poda del pool**: con los datos de elección del bot, buffear o retirar lo que nadie coge.
- [ ] **Sinergias por musa**: asegurar 2 arquetipos viables por musa y que la recompensa no fuerce uno solo.
- [ ] Opcional post-lanzamiento: Acto IV / modo infinito como contenido de actualización.

**Salida:** ninguna carta por debajo de un umbral de elección y cada musa con dos formas claras de ganar.

---

## Fase 5 · Lanzamiento (2–3 semanas)

- [ ] Exportar Linux además de Windows (`export_presets.cfg` solo tiene Windows).
- [ ] Revisión en Steam Deck: 720p, mando, suspensión, legibilidad.
- [ ] Demo con el Acto I y página de tienda.
- [ ] Logros de Steam y guardado en nube.
- [ ] **Localización ES/EN**: hoy todo el texto está incrustado en español; preparar `tr()` antes de que crezca.
- [ ] Pipeline de build reproducible, soak test de 50 partidas seguidas y reporte de fallos opcional.

**Salida:** build listo para tienda, 60 fps estables en Deck y cero crashes en el soak test.

---

## Orden de arranque (esta semana)

1. Políticas de bot por musa y repetir el balance: separar “Irene es débil” de “el bot no sabe jugar Irene”.
2. Bajar `crabking`/`drowncaptain` y subir élites con los datos del simulador.
3. Tutorial contextual de Cuerda, orbes y Osty.
4. Tooltip al hacer clic en reliquia.
5. Copia de seguridad automática del guardado.

## Lo que no haremos todavía

Más cartas, una séptima musa, PvP online, cambio de motor o un rediseño grande. La deuda real no es
contenido: es curva, claridad y progresión.

## Decisiones abiertas

- ¿El lanzamiento es premium en Steam o free-to-play con demo? Condiciona logros, nube y telemetría.
- ¿La localización EN entra en el lanzamiento o en una actualización?
- ¿El reto diario necesita marcador online desde el día uno o basta el histórico local?
- ¿Se mantiene la paridad con el web a largo plazo o el port pasa a ser el proyecto principal?
