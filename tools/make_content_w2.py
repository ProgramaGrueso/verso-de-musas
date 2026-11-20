"""Oleada 2 de contenido: eventos, enemigos (jefes, élites y normales), reliquias, pociones y estados nuevos.
Genera:
  data/events_extra.json   eventos nuevos (generales, por acto y exclusivos de cada musa)
  data/enemies_extra.json  enemigos nuevos + encuentros por acto separados en fáciles/difíciles, élites y jefes
  data/relics_extra.json   reliquias (poco comunes, raras, de jefe y de musa) y pociones nuevas
  data/states_extra.json   estados nuevos (Regeneración)
  gen/jobs_w2.json         prompts de arte para gen/comfy.py (enemigos y fondos de eventos)
Los iconos de reliquias/pociones nuevas se generan con tools/gen_icons.py (sus descripciones están en ese script).
La lógica de cada efecto vive en el motor (scripts/engine/relics.gd, eng.gd, events.gd, run.gd).
Todo este contenido se desactiva en las trazas de paridad con el web (DB.extra = false).
Uso: python3 tools/make_content_w2.py
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

ENEMY_STYLE = ("dark fantasy creature concept art, seen in three-quarter view facing left, full body entirely inside the frame with wide empty margins, "
               "single monster centered, painterly digital illustration, plain flat dark neutral background")
EVENT_STYLE = ("dark fantasy painterly digital illustration, wide cinematic 16:9 composition, atmospheric lighting, rich saturated colors, "
               "visible brush strokes, no people facing the camera, no text, no watermark")

# ------------------------------------------------------------------ enemigos
ENEMIES = {
    # --- Acto I: Los Bajos Muelles
    "eel": {"name": "Anguila Voltaica", "act": 1, "tier": "normal", "hp": [24, 28], "h": 170,
            "moves": {"shock": {"name": "Descarga", "dmg": 9},
                      "coil": {"name": "Enroscarse", "block": 7, "dmg": 4},
                      "zap": {"name": "Chispazo", "dmg": 3, "hits": 2, "apply": {"weak": 1}}},
            "ai": {"t": "rnd", "keys": ["shock", "coil", "zap"], "w": [3, 2, 2]},
            "ap": "a long electric eel monster coiled in the air, glowing blue lightning running along its slimy dark body, needle teeth, crackling sparks"},
    "sirena": {"name": "Sirena Abisal", "act": 1, "tier": "elite", "hp": [106, 110], "h": 290,
               "moves": {"canto": {"name": "Canto Hechizante", "apply": {"weak": 2, "vulnerable": 1}, "block": 10},
                         "garra": {"name": "Garra", "dmg": 19},
                         "marea": {"name": "Resaca", "dmg": 7, "hits": 2},
                         "lamento": {"name": "Lamento", "dmg": 5, "add": {"id": "doubt", "n": 1, "to": "discard"}}},
               "ai": {"t": "cyc", "seq": ["canto", "garra", "marea", "lamento", "garra"]},
               "ap": "a terrifying abyssal siren, a pale drowned woman-like sea creature with a long eel tail, webbed claws, black hollow eyes, seaweed hair, glowing teal runes on her skin, her chest and torso fully covered by dense wet seaweed, kelp and fish scales, modest, no nudity"},
    "spectralbosun": {"name": "Contramaestre Espectral", "act": 1, "tier": "elite", "hp": [96, 100], "h": 300,
                      "moves": {"apuntar": {"name": "Apuntar el Cañón", "block": 8, "selfStr": 1},
                                "canon": {"name": "Cañonazo Rompible (16)", "dmg": 30, "brk": 16},
                                "andanada": {"name": "Andanada Fantasma", "dmg": 5, "hits": 3},
                                "sable": {"name": "Sablazo Espectral", "dmg": 13}},
                      "ai": {"t": "cyc", "seq": ["apuntar", "canon", "andanada", "sable", "canon"]},
                      "ap": "a ghostly spectral pirate boatswain beside a huge translucent cannon, tattered naval coat, glowing green eyes, barnacles and fog, imposing elite monster"},
    "drowncaptain": {"name": "Capitana Ahogada", "act": 1, "tier": "boss", "hp": [94, 98], "h": 350,
                     "moves": {"abordaje": {"name": "¡Al abordaje!", "summon": {"id": "ghostpirate", "n": 1}, "block": 6},
                               "canon": {"name": "Cañonazo", "dmg": 10},
                               "andanada": {"name": "Andanada", "dmg": 2, "hits": 4},
                               "ancla": {"name": "Ancla de Hierro", "dmg": 7, "apply": {"frail": 1}},
                               "ron": {"name": "Ron Maldito", "selfStr": 1, "heal": 6}},
                     "ai": {"t": "custom"},
                     "ap": "a towering undead drowned pirate captain, a skeletal woman in a rotting tricorn hat and tattered captain coat dripping seawater, a cannon arm and a rusted anchor on a chain, ghostly green fire in her eye sockets, barnacles and coral on her bones"},
    # --- Acto II: La Maleza
    "brambwolf": {"name": "Lobo de Zarzas", "act": 2, "tier": "normal", "hp": [36, 40], "h": 210,
                  "moves": {"howl": {"name": "Aullido", "selfStr": 2, "block": 6},
                            "bite": {"name": "Dentellada", "dmg": 11},
                            "maul": {"name": "Zarpazo", "dmg": 6, "hits": 2}},
                  "ai": {"t": "first_alt", "first": "howl", "odd": "bite", "even": "maul"},
                  "ap": "a feral wolf made of thorny brambles and twisted vines, glowing green eyes, thorns instead of fur, snarling with wooden fangs"},
    "mantis": {"name": "Mantis de Espinas", "act": 2, "tier": "elite", "hp": [117, 121], "h": 300,
               "moves": {"camo": {"name": "Camuflaje", "block": 18, "thorns": 3},
                         "scythe": {"name": "Guadañas", "dmg": 10, "hits": 2},
                         "ambush": {"name": "Emboscada", "dmg": 23, "apply": {"vulnerable": 1}},
                         "molt": {"name": "Muda", "selfStr": 2}},
               "ai": {"t": "cyc", "seq": ["camo", "scythe", "ambush", "molt", "scythe"]},
               "ap": "a giant praying mantis monster covered in thorns and bark-like armor, huge scythe forelimbs, mossy green and dark red colors, menacing hunter pose"},
    "rootwarden": {"name": "Guardiana de Raíces", "act": 2, "tier": "elite", "hp": [116, 120], "h": 310,
                   "rootShield": True,
                   "moves": {"raices": {"name": "Escudo de Raíces", "block": 15, "selfStr": 2},
                             "golpe": {"name": "Golpe de Corteza", "dmg": 24},
                             "astillas": {"name": "Astillas", "dmg": 8, "hits": 3},
                             "lianas": {"name": "Lianas", "dmg": 9, "apply": {"weak": 1, "vulnerable": 1}}},
                   "ai": {"t": "cyc", "seq": ["raices", "golpe", "astillas", "lianas"]},
                   "ap": "an ancient regal dryad guardian with bark armor and long roots connecting her to two small saplings, glowing amber heart, mossy crown, protective pose"},
    "mycelking": {"name": "Rey Micelio", "act": 2, "tier": "boss", "hp": [172, 176], "h": 360,
                  "moves": {"colonia": {"name": "Colonia", "summon": {"id": "sporecap", "n": 1}, "block": 12},
                            "aplastar": {"name": "Aplastar", "dmg": 24},
                            "esporas": {"name": "Nube de Esporas", "dmg": 6, "apply": {"weak": 2, "frail": 2}},
                            "pudrir": {"name": "Putrefacción", "dmg": 9, "hits": 2, "add": {"id": "wound", "n": 1, "to": "discard"}},
                            "festin": {"name": "Festín Fúngico", "healAll": 10, "block": 10}},
                  "ai": {"t": "custom"},
                  "ap": "a colossal mushroom king, a hulking fungal giant with a huge glowing purple and orange cap like a crown, mycelium roots as a beard and cape, bioluminescent spores drifting, ancient and regal"},
    # --- Acto III: La Colmena
    "workerbee": {"name": "Obrera Acorazada", "act": 3, "tier": "normal", "hp": [44, 48], "h": 200,
                  "moves": {"carry": {"name": "Acarrear", "block": 10, "dmg": 6},
                            "pierce": {"name": "Perforar", "dmg": 13},
                            "rally": {"name": "Reagrupar", "selfStr": 2, "healAll": 6}},
                  "ai": {"t": "cyc", "seq": ["carry", "pierce", "rally", "pierce"]},
                  "ap": "a giant armored worker bee warrior with thick amber chitin plates, carrying a honeycomb shield, sharp mandibles, golden and black"},
    "hornet": {"name": "Avispón Verdugo", "act": 3, "tier": "elite", "hp": [144, 148], "h": 300,
               "moves": {"buzz": {"name": "Zumbido", "selfStr": 2, "block": 14},
                         "sting": {"name": "Doble Aguijón", "dmg": 13, "hits": 2, "apply": {"weak": 1}},
                         "execute": {"name": "Ejecución", "dmg": 42},
                         "frenzy": {"name": "Frenesí", "dmg": 4, "hits": 4}},
               "ai": {"t": "cyc", "seq": ["buzz", "sting", "execute", "frenzy"]},
               "ap": "a giant executioner hornet with a black and crimson carapace, a hooded executioner mask-like head, a huge barbed stinger like a blade, translucent wings"},
    "royalbeetle": {"name": "Escarabajo Real", "act": 3, "tier": "elite", "hp": [136, 142], "h": 310,
                    "shellCap": 12, "startBlock": 8,
                    "moves": {"placa": {"name": "Placas Reales", "block": 20, "selfStr": 2},
                              "embestida": {"name": "Embestida Real", "dmg": 30},
                              "esquirlas": {"name": "Esquirlas de Quitina", "dmg": 8, "hits": 3},
                              "cornada": {"name": "Cornada", "dmg": 14, "apply": {"vulnerable": 1}}},
                    "ai": {"t": "cyc", "seq": ["placa", "embestida", "esquirlas", "cornada", "embestida"]},
                    "ap": "a majestic giant royal rhinoceros beetle with overlapping golden chitin armor plates, emerald iridescent shell, crown shaped horn, elite hive guardian"},
    "waxcolossus": {"name": "Coloso de Cera", "act": 3, "tier": "boss", "hp": [226, 232], "h": 390,
                    "moves": {"sello": {"name": "Sello de Cera", "block": 28},
                              "aplastar": {"name": "Puño de Panal", "dmg": 32},
                              "goteo": {"name": "Goteo Ardiente", "dmg": 5, "hits": 5},
                              "cera": {"name": "Cera Fundida", "dmg": 12, "apply": {"frail": 2, "weak": 1}},
                              "endurecer": {"name": "Endurecer", "selfStr": 3, "thorns": 3},
                              "fundirse": {"name": "Fundición", "selfStr": 4, "dmg": 10, "hits": 2}},
                    "ai": {"t": "custom"},
                    "ap": "a colossal golem made of glowing amber beeswax and honeycomb, molten wax dripping from its body, burning candle wicks on its shoulders, a hollow glowing core in its chest, ancient guardian of the hive"},
}

# Encuentros (solo con contenido ampliado): 3 primeros combates normales de cada acto "fáciles", el resto "difíciles".
ENCOUNTERS = {
    "1": {"easy": [["jelly", "dockrat"], ["slime"], ["crab"], ["eel"], ["dockrat", "dockrat"]],
          "hard": [["dockrat", "dockrat", "dockrat"], ["ghostpirate"], ["slime", "jelly"], ["eel", "dockrat"], ["crab", "dockrat"], ["ghostpirate", "dockrat"], ["eel", "eel"], ["ghostpirate", "jelly"]],
          "elite": [["sirena"], ["spectralbosun"]], "boss": [["drowncaptain"]]},
    "2": {"easy": [["sporecap"], ["vinelasher"], ["brambwolf"], ["dryad"], ["thornbeast"]],
          "hard": [["sporecap", "vinelasher"], ["mossgolem"], ["dryad", "sporecap"], ["dryad", "brambwolf"], ["brambwolf", "sporecap"], ["thornbeast", "sprout", "sprout"]],
          "elite": [["mantis"], ["rootwarden", "sprout", "sprout"]], "boss": [["mycelking"]]},
    "3": {"easy": [["drone", "drone"], ["wasp"], ["honeyslime"], ["workerbee"], ["beetle"]],
          "hard": [["drone", "drone", "drone"], ["wasp", "drone"], ["nurse", "wasp"], ["wasp", "wasp"], ["workerbee", "drone", "drone"], ["beetle", "drone"]],
          "elite": [["hornet"], ["royalbeetle"]], "boss": [["waxcolossus"]]},
}

# Fase 4B: reutilizan arte terminado; no crean trabajos de generación ni cambian las semillas anteriores.
ART_COPIES = {"spectralbosun": "ghostpirate", "rootwarden": "dryad", "royalbeetle": "beetle"}

# ------------------------------------------------------------------ equilibrio
# Ajustes que solo se aplican con DB.extra = true (el juego con la Oleada 2). Las trazas de paridad
# usan DB.extra = false, así que la referencia del web sigue intacta. Las claves de "enemies" se mezclan
# recursivamente sobre el enemigo original: hp, moves, ai, etc.
BALANCE = {
    "osty_revives": 1,   # Osty tiene una sola segunda vida por combate (antes revivía cada turno)
    "enemies": {
        # Acto I: el Cangrejo Rey mata el 29% de las veces; se suaviza para que Irene/Zafiro pasen.
        "crabking": {"hp": [142, 146], "moves": {
            "roar": {"block": 12}, "pincer": {"dmg": 15}, "spin": {"dmg": 5}, "twin": {"dmg": 11}, "shell": {"block": 19}}},
        # Normales que solo salen en los combates difíciles del Acto I.
        "ghostpirate": {"hp": [41, 45], "moves": {"slash": {"dmg": 11}}},
        # Acto II: la Madre Raíz es el jefe que más mata; el Gólem solo sale en difíciles.
        "rootmother": {"hp": [160, 164], "moves": {"crush": {"dmg": 23}, "harvest": {"dmg": 8, "heal": 12}}},
        "mossgolem": {"hp": [56, 60], "moves": {"smash": {"dmg": 19}}},
        # Élites base: hoy son gratis (0-6%); se suben a la banda 8-12%.
        # Fase 4 (Agente E, ronda 5): con el pool podado los élites bajaron a 7 % de derrotas; +8 % PV a los 6 más flojos
        # (ronda 6: treant y royalguard +5 %).
        "chainwarden": {"hp": [78, 82], "moves": {"chain": {"dmg": 11}, "lash": {"dmg": 6}}},
        "tentacle": {"hp": [96, 100], "moves": {"whip": {"dmg": 18}, "drain": {"dmg": 11}, "drown": {"dmg": 9}}},
        "treant": {"hp": [125, 129], "moves": {"slam": {"dmg": 23}, "splinter": {"dmg": 9}}},
        "stag": {"hp": [123, 127], "moves": {"gore": {"dmg": 22}, "gallop": {"dmg": 13}}},
        "royalguard": {"hp": [153, 158], "moves": {"guard": {"block": 24}, "thrust": {"dmg": 25}, "sweep": {"dmg": 11}, "charge": {"dmg": 35}}},
        # Ronda 7: seguía en ~2 % de derrotas. Nuevo ritmo (solo DB.extra): el Pulso Mental (Vulnerable) abre y el Golpe
        # cae justo después, con el Vulnerable aún activo; antes el Golpe llegaba tras Convocar/Ola y no castigaba.
        "hivemind": {"hp": [142, 147], "moves": {"strike": {"dmg": 28}, "mind": {"dmg": 10}, "wave": {"dmg": 5}},
                     "ai": {"t": "cyc", "seq": ["mind", "strike", "swarm", "strike", "wave", "strike"]}},
        # Normales del Acto III: los «fáciles» cuestan 2,1 PV (objetivo 3-5).
        "crab": {"hp": [36, 40], "moves": {"crush": {"dmg": 13}}},
        "jelly": {"hp": [26, 30]},
        "honeyslime": {"hp": [46, 50], "moves": {"jet": {"dmg": 14}}},
        "beetle": {"hp": [60, 65], "moves": {"ram": {"dmg": 17}}},
    },
    "cards": {
        # Aurora escala sin techo con el Calor; se recorta el remate, no la generación.
        # Fase 4 (Agente E): heatDmg 4→5 (ronda 3) y coste 2→1 (ronda 5): el arquetipo Calor se quedaba en 35 %.
        "aurora_climax": {"cost": 1, "fx": {"heatDmg": 5}},
        "aurora_supernova": {"fx": {"heatMul": 1.35}},
        "aurora_warmth": {"fx": {"heat": 2}},
    },
    # Vida inicial: las tres musas que dependían de escalar despacio morían en el Acto I/II.
    "chars": {
        "zafiro": {"hp": 94},
        "irene": {"hp": 96},
        "selene": {"hp": 94},
        "lia": {"hp": 82},
        "aurora": {"hp": 72},
    },
    "relics": {
        "brasa_carmesi": {"heal": 11, "d": "Al terminar un combate, recuperas 11 PV."},
        "prisma_solar": {"dmg": 4},
        "llave_maestra": {"wind": 5, "d": "Empiezas cada combate con 5 de Cuerda."},
        # Outliers del simulador (+8 o más frente a su grupo).
        "escamas": {"thorns": 2, "d": "Empiezas cada combate con 2 de Espinas."},
        "caparazon": {"metallicize": 1, "d": "Empiezas cada combate con 1 de Metalizar."},
        "pozo": {"hp": 18, "d": "Aumenta tus PV máx. en 18 y te curas por completo."},
        "nucleo": {"wounds": 2, "d": "+1 de Energía por turno. Empiezas cada combate con 2 Heridas en tu mazo."},
    },
    # Escalera de Pesadilla (10 niveles, el techo del juego). Cada fila es el estado acumulado de ese
    # nivel: una sola variable nueva por escalón y pasos pequeños, para que no haya muros. La versión
    # anterior metía +10% PV en el 1, +10% daño en el 2 y +2 Fuerza en el 5: 30 de los 36 puntos de la
    # curva caían en tres niveles y el 4 y el 6 no hacían nada. Se mide con `balance.gd -- 100 sweep`.
    "nm": [
        {"hp": 1.0,  "dmg": 1.03, "gold": 1.0,  "rest": 0.3,  "wound": False, "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.0,  "dmg": 1.03, "gold": 0.85, "rest": 0.3,  "wound": False, "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.03, "dmg": 1.03, "gold": 0.85, "rest": 0.3,  "wound": False, "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.03, "dmg": 1.03, "gold": 0.85, "rest": 0.25, "wound": False, "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.03, "dmg": 1.06, "gold": 0.85, "rest": 0.25, "wound": False, "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.03, "dmg": 1.06, "gold": 0.85, "rest": 0.25, "wound": True,  "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.06, "dmg": 1.06, "gold": 0.85, "rest": 0.25, "wound": True,  "doubt": False, "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.06, "dmg": 1.06, "gold": 0.85, "rest": 0.25, "wound": True,  "doubt": True,  "eliteStr": 0, "bossStr": 0, "allStr": 0},
        {"hp": 1.06, "dmg": 1.06, "gold": 0.85, "rest": 0.25, "wound": True,  "doubt": True,  "eliteStr": 1, "bossStr": 0, "allStr": 0},
        {"hp": 1.06, "dmg": 1.06, "gold": 0.85, "rest": 0.25, "wound": True,  "doubt": True,  "eliteStr": 1, "bossStr": 1, "allStr": 0},
    ],
    "nm_texts": [
        "",
        "Los enemigos infligen +3% de daño.",
        "Ganas un 15% menos de oro.",
        "Los enemigos tienen +3% de PV.",
        "La hoguera cura solo un 25% de tu vida.",
        "Los enemigos infligen +6% de daño (en total).",
        "Cada combate empieza con una Herida en tu mazo.",
        "Los enemigos tienen +6% de PV (en total).",
        "Empiezas cada partida con la maldición Duda.",
        "Los élites empiezan con +1 de Fuerza.",
        "Los jefes empiezan con +1 de Fuerza.",
    ],
}

# Fase 4 · Jefes con fases (solo DB.extra): al bajar de «at»% de PV el jefe entra en fase 2 una sola vez,
# gana «str» Fuerza / «block» Bloqueo, avisa con «msg» (fx "bossPhase") y cambia a la secuencia «seq»
# (empieza por el golpe nuevo, ya telegrafiado). Un movimiento con «summon» se salta si ya hay 3 vivos.
BOSS_PHASES = {
    # Medido con balance.gd -- 100 0: con +Fuerza e invocaciones la fase 2 era un muro (22 % de victorias frente a 40 %).
    # La fase 2 cambia el ritmo (golpe nuevo telegrafiado, sin curas ni invocaciones), no infla las cifras.
    "crabking": {"moves": {"guillotina": {"name": "Guillotina", "dmg": 18}},
                 "phase2": {"at": 50, "str": 0, "msg": "¡El Cangrejo Rey se enfurece!",
                            "seq": ["guillotina", "shell", "spin", "pincer"]}},
    "drowncaptain": {"moves": {"metralla": {"name": "Tormenta de Metralla", "dmg": 2, "hits": 5}},
                     "phase2": {"at": 50, "str": 0, "msg": "¡La Capitana Ahogada iza la bandera negra!",
                                "seq": ["metralla", "ron", "canon", "ancla"]}},
    "rootmother": {"moves": {"espinas": {"name": "Bosque de Espinas", "block": 12, "thorns": 2}},
                   "phase2": {"at": 50, "str": 0, "msg": "¡La Madre Raíz se cubre de espinas!",
                              "seq": ["espinas", "crush", "root", "lash"]}},
    "mycelking": {"moves": {"esporada": {"name": "Esporada Final", "dmg": 6, "hits": 2, "apply": {"weak": 1}}},
                  "phase2": {"at": 50, "str": 0, "msg": "¡El Rey Micelio libera su esporada final!",
                             "seq": ["esporada", "aplastar", "pudrir", "esporas"]}},
    "queen": {"moves": {"enjambre": {"name": "Enjambre Real", "dmg": 3, "hits": 6}},
              "phase2": {"at": 50, "str": 0, "msg": "¡La Reina de la Colmena llama a su guardia!",
                         "seq": ["order", "enjambre", "royal", "rain", "ram"]}},
    "waxcolossus": {"moves": {"nucleo": {"name": "Núcleo Ardiente", "dmg": 34}},
                    "phase2": {"at": 50, "str": 0, "msg": "¡El Coloso de Cera se funde en furia!",
                               "seq": ["fundirse", "sello", "nucleo", "goteo"]}},
}
for _bid, _ph in BOSS_PHASES.items():
    _cur = BALANCE["enemies"].setdefault(_bid, {})
    _cur.setdefault("moves", {}).update(_ph["moves"])
    _cur["phase2"] = _ph["phase2"]

# Fase 4 · Poda del pool y 2 arquetipos por musa (solo DB.extra). Medido con tests/balance.gd, 4 semillas × 1000
# partidas por musa: VDM_ARCH=1 fuerza cada arquetipo (plan A/B) y VDM_EXPLORE=1 da el «Δcoger» de cada carta.
# Detalle y tablas en HANDOFF_AGENTE_E.md. Ojo: si se cambia el coste base y la mejora era {"cost": N}, hay que
# bajar también la mejora (si no, mejorar no haría nada).
CARD_TUNING = {
    # Irene: «descarga» (gastar Cuerda de golpe) 17 % frente a «engranajes» 76 %: un punto de Cuerda vale ~7 de daño
    # repitiendo un Engranaje y solo 2-3 en los remates.
    "irene_release": {"fx": {"windSpend": 5}, "up": {"fx": {"windSpend": 6}}},
    "irene_spring_discharge": {"fx": {"windSpend": 3}, "up": {"fx": {"windSpend": 4}}},
    "irene_colossal_automaton": {"fx": {"dmg": 14, "block": 14}, "up": {"fx": {"dmg": 18, "block": 18}}},   # ronda 6: 16 → 14
    # Ronda 2 (descarga 23 %, engranajes 73 %): generadores de Cuerda sin tanto autodaño, Resorte da 2 por turno;
    # Obra Maestra y Cadena de Relojería (Δ +25 y +19) bajan.
    "irene_overwind": {"fx": {"selfdmg": 1}},
    "irene_overdrive": {"fx": {"selfdmg": 2}},
    "irene_clockwork": {"fx": {"pw": {"resorte": 2}}, "up": {"fx": {"pw": {"resorte": 3}}}},
    "irene_masterwork": {"fx": {"dmg": 17}, "up": {"fx": {"dmg": 22}}},   # ronda 6: 20 → 17
    "irene_clockwork_chain": {"fx": {"dmg": 3}, "up": {"fx": {"dmg": 4}}},
    # Ronda 3 (descarga 28 %, engranajes 70 %): más Cuerda barata; Mecanismo Fino (Δ +11) con Precisión 1.
    "irene_tick": {"fx": {"wind": 2}, "up": {"fx": {"wind": 3}}},
    "irene_chime": {"fx": {"windDmg": 3}, "up": {"fx": {"windDmg": 4}}},
    "irene_quick_wind": {"fx": {"selfdmg": 0}},
    "irene_fine_clockwork": {"fx": {"pw": {"precision": 1}}, "up": {"fx": {"pw": {"precision": 2}}}},
    # Ronda 4 (engranajes 69 %): los Engranajes de coste 0 se repiten casi gratis (Δ +8 y +11).
    "irene_loose_gear": {"fx": {"dmg": 3}, "up": {"fx": {"dmg": 5}}},
    "irene_stitch": {"fx": {"dmg": 2}, "up": {"fx": {"dmg": 4}}},
    # Ronda 6 (descarga 35 %, engranajes 65 %): Tic-Tac (daño por Cuerda gastada, Δ +7) 3 → 4; Muelle más Bloqueo.
    "irene_tictac": {"fx": {"pw": {"tictac": 4}}, "up": {"fx": {"pw": {"tictac": 5}}}},
    "irene_spring": {"fx": {"block": 6}, "up": {"fx": {"block": 8}}},
    # Aurora: «calor» 29 % frente a «luz» 64 %. Generadores de Calor más fuertes; Abrasar (Δ +14) con menos Resplandor.
    "aurora_ember_petal": {"fx": {"heat": 2}, "up": {"fx": {"heat": 3}}},
    "aurora_flame_spin": {"fx": {"heat": 2}},
    "aurora_scorch": {"fx": {"glow": 2}, "up": {"fx": {"glow": 3}}},
    # Ronda 2 (calor 31 %, luz 62 %): Corona (Δ +13; daño = Bloqueo a todos cada turno) cuesta 3; Eclipse Dorado,
    # el remate de área del Calor, cuesta 2.
    "aurora_corona": {"cost": 3, "up": {"cost": 2}},
    "aurora_golden_eclipse": {"cost": 2},
    # Ronda 3 (calor 35 %, luz 62 %): Deslumbrar (Δ +9) con menos Resplandor; Clímax vuelve a 5 por Calor (arriba).
    "aurora_dazzle": {"fx": {"glow": 1}, "up": {"fx": {"glow": 2}}},
    # Ronda 4 (calor 36 %, luz 61 %): Velo Dorado (Δ +8: Bloqueo y Resplandor a todos por 1) con menos Bloqueo.
    # (La carta nueva Última Ascua empeoró a Aurora y se descartó: ver make_cards_w1.py.)
    "aurora_gilded_veil": {"fx": {"block": 6}, "up": {"fx": {"block": 9}}},
    # Ronda 6 (luz 62 %): Muro de Refracción (Δ +7) 16 → 14 de Bloqueo.
    "aurora_refraction_wall": {"fx": {"block": 14}, "up": {"fx": {"block": 19}}},
    # Ronda 5: Clímax, el remate principal del Calor, cuesta 1; Tajo de Abanico también genera 1 de Calor.
    "aurora_fan_slash": {"fx": {"heat": 1}},
    # Lia: «cuchillas» 29 % frente a «veneno» 46 %. Los multigolpe caros no compensaban; Aguja Paralizante (Δ +19) baja.
    "lia_eviscerate": {"cost": 2},
    "lia_blade_waltz": {"cost": 2},
    "lia_paralysis": {"fx": {"weak": 1}, "up": {"fx": {"weak": 2}}},
    # Zafiro: «fuerza» 26 % frente a «coraza» 41 %: faltan fuentes de Fuerza baratas.
    "zafiro_old_blood": {"fx": {"str": 2}, "up": {"fx": {"str": 3}}},
    "zafiro_flex": {"fx": {"tstr": 3}, "up": {"fx": {"tstr": 5}}},
    # Claudia: «agotar» 33 % frente a «osty» 43 %. Abrazo Oscuro (Δ −6) más barato; Pira (Δ +16) baja.
    "claudia_embrace": {"cost": 1, "up": {"cost": 0}},
    "claudia_pyre": {"fx": {"dmg": 10}, "up": {"fx": {"dmg": 13}}},
    # Selene (ronda 2): «evocar» 28 % frente a «marea» 50 %. Las cartas de Evocar (Δ −14 a −21) cuestan 1 menos.
    "selene_undertow": {"cost": 0},
    "selene_depthcharge": {"cost": 1},
    "selene_maremoto": {"cost": 1, "up": {"cost": 0}},
    # Claudia (ronda 3): «agotar» 33 %. Presagio (Δ −5) sin coste.
    "claudia_omen": {"cost": 0},
    # Neutrales (ronda 3; Δcoger medio de las 6 musas entre paréntesis). Carga Desesperada (−10) y Pausa Estratégica
    # (−7) salen del pool en tools/make_cards_w1.py (RETIRADAS). Las dos que dominan bajan; las flojas, más baratas.
    "neu_second_chance": {"fx": {"heal": 10, "block": 10}, "up": {"fx": {"heal": 14, "block": 14}}},   # +16
    "neu_smoke_bomb": {"fx": {"weak": 1}, "up": {"fx": {"weak": 2}}},                                 # +12
    "neu_hunters_mark": {"cost": 0},                                                                   # −5
    "neu_scavenge": {"cost": 0},                                                                       # −4
    "neu_all_or_nothing": {"fx": {"selfdmg": 1}},                                                      # −6
}
for _cid, _t in CARD_TUNING.items():
    assert _cid not in BALANCE["cards"], _cid
    BALANCE["cards"][_cid] = _t

# ------------------------------------------------------------------ reliquias
RELICS = {
    # --- generales, poco comunes
    "colmillo": {"n": "Colmillo de Lobo", "i": "🐺", "rarity": "uncommon", "d": "Cada vez que derrotas a un enemigo, recuperas 3 PV."},
    "medallon": {"n": "Medallón del Boticario", "i": "🏅", "rarity": "uncommon", "d": "Tienes 1 hueco de poción más."},
    "tinta": {"n": "Tinta de Calamar", "i": "🦑", "rarity": "uncommon", "d": "Al inicio del combate aplicas 1 Débil a todos los enemigos."},
    "caparazon": {"n": "Caparazón Pulido", "i": "🐢", "rarity": "uncommon", "d": "Empiezas cada combate con 2 de Metalizar."},
    "brujula": {"n": "Brújula de Bronce", "i": "🧭", "rarity": "uncommon", "d": "Cada vez que barajas tu descarte en el mazo de robo, ganas 5 de Bloqueo."},
    "reloj_arena": {"n": "Reloj de Arena", "i": "⏳", "rarity": "uncommon", "d": "En tu tercer turno de cada combate obtienes 2 de Energía."},
    "huevo": {"n": "Huevo de Grifo", "i": "🥚", "rarity": "uncommon", "d": "Las cartas que añades a tu mazo desde recompensas, tiendas y eventos llegan mejoradas."},
    # --- generales, raras
    "pluma": {"n": "Pluma de Fénix", "i": "🪶", "rarity": "rare", "d": "Una vez por partida, al caer a 0 PV te recuperas con el 30% de tus PV máx."},
    "cristal": {"n": "Cristal de Eco", "i": "💎", "rarity": "rare", "d": "La primera carta que juegas en cada combate se juega dos veces."},
    "amuleto": {"n": "Amuleto de las Mareas", "i": "🧿", "rarity": "rare", "d": "Cada vez que juegas un Poder, robas 1 carta y ganas 4 de Bloqueo."},
    # --- generales, de jefe
    "corona_espinas": {"n": "Corona de Espinas", "i": "🌹", "rarity": "boss", "d": "+1 de Energía por turno. Al inicio de cada combate añades 1 Quemadura a tu mazo de robo."},
    "reloj_roto": {"n": "Reloj Detenido", "i": "🕰️", "rarity": "boss", "d": "+1 de Energía por turno. Ya no puedes descansar en las hogueras (sí mejorar cartas)."},
    # --- Zafiro
    "estandarte": {"n": "Estandarte Acorazado", "i": "🚩", "rarity": "common", "char": "zafiro", "d": "Al inicio del combate, si tienes la mitad de tus PV o menos, ganas 2 de Fuerza."},
    "guantelete": {"n": "Guantelete Ígneo", "i": "🧤", "rarity": "uncommon", "char": "zafiro", "d": "Cada vez que pierdes PV por una de tus cartas, ganas 4 de Bloqueo."},
    "corazon_volcan": {"n": "Corazón de Volcán", "i": "🌋", "rarity": "boss", "char": "zafiro", "d": "+1 de Energía por turno. Al inicio de cada combate pierdes 4 PV."},
    # --- Lia
    "bandolera": {"n": "Bandolera de Cuchillas", "i": "🔪", "rarity": "common", "char": "lia", "d": "Al inicio de cada combate añades 2 Cuchillas a tu mano."},
    "colmillo_vibora": {"n": "Colmillo de Víbora", "i": "🐍", "rarity": "uncommon", "char": "lia", "d": "Cada vez que aplicas Veneno a un enemigo, aplicas 1 más."},
    "capa_sombra": {"n": "Capa de Sombras", "i": "🦇", "rarity": "boss", "char": "lia", "d": "+1 de Energía por turno. Robas 1 carta menos cada turno."},
    # --- Claudia
    "craneo_cristal": {"n": "Cráneo de Cristal", "i": "💀", "rarity": "common", "char": "claudia", "d": "Osty recupera 2 PV al inicio de cada turno."},
    "grimorio": {"n": "Grimorio Prohibido", "i": "📕", "rarity": "uncommon", "char": "claudia", "d": "Cada vez que agotas una carta, infliges 3 de daño a un enemigo al azar."},
    "luna_violeta": {"n": "Luna Violeta", "i": "🌕", "rarity": "boss", "char": "claudia", "d": "+1 de Energía por turno. Osty empieza cada combate con la mitad de sus PV."},
    # --- Aurora
    "abanico_espejo": {"n": "Abanico de Espejos", "i": "🪭", "rarity": "common", "char": "aurora", "d": "Empiezas cada combate con 3 de Calor."},
    "sol_naciente": {"n": "Sol Naciente", "i": "🌄", "rarity": "uncommon", "char": "aurora", "d": "Al inicio del combate aplicas 2 de Resplandor a TODOS los enemigos."},
    "eclipse": {"n": "Eclipse", "i": "🌘", "rarity": "boss", "char": "aurora", "d": "+1 de Energía por turno. Los enemigos empiezan cada combate con 8 de Bloqueo."},
    # --- Irene y Selene (ya tenían reliquias propias)
    "muelle_doble": {"n": "Muelle Doble", "i": "🪀", "rarity": "uncommon", "char": "irene", "d": "Cada vez que gastas Cuerda, ganas 1 de Bloqueo por cada punto gastado."},
    "caracola_abismal": {"n": "Caracola Abismal", "i": "🐙", "rarity": "uncommon", "char": "selene", "d": "Empiezas cada combate con 1 Abismo canalizado."},
}

POTIONS = {
    "duplicar": {"n": "Destilado de Eco", "i": "🔁", "c": "#c38bff", "d": "Tu próxima carta este turno se juega dos veces."},
    "herrero": {"n": "Elixir del Herrero", "i": "⚒️", "c": "#ffb15e", "d": "Mejora todas las cartas de tu mano durante este combate."},
    "gambito": {"n": "Tónico del Malabarista", "i": "🃏", "c": "#ff8fb8", "d": "Descarta tu mano y roba tantas cartas como descartaste."},
    "agilidad": {"n": "Poción de Agilidad", "i": "🦶", "c": "#8ef0c8", "d": "Obtén 2 de Destreza."},
    "espinas": {"n": "Tónico de Espinas", "i": "🌵", "c": "#9bd36a", "d": "Obtén 4 de Espinas."},
    "savia": {"n": "Savia Viva", "i": "🌿", "c": "#5fd47a", "d": "Obtén 5 de Regeneración: al inicio de tus turnos recuperas PV."},
    "brea": {"n": "Bomba de Brea", "i": "💣", "c": "#a0754a", "d": "Inflige 12 de daño a TODOS los enemigos."},
    "memoria": {"n": "Memoria Líquida", "i": "🫗", "c": "#7fc7ff", "d": "Devuelve a tu mano la última carta de tu pila de descarte."},
}

STATES = {
    "regen": {"n": "Regeneración", "i": "🌿", "d": "Al inicio de tu turno recuperas {n} PV y la Regeneración baja 1.", "negp": False, "negn": False},
    "rootShield": {"n": "Escudo de Raíces", "i": "🌳", "d": "Recibe la mitad de daño por golpe mientras viva al menos un Brote. Cantidad de Brotes protectores: {n}.", "negp": False, "negn": False},
    "carapace": {"n": "Coraza", "i": "🪲", "d": "Ningún golpe le quita más de {n} PV. Los ataques de varios golpes atraviesan mejor su defensa.", "negp": False, "negn": False},
}

# ------------------------------------------------------------------ eventos
# act: solo aparece en ese acto · char: solo con esa musa · textBy: texto según la musa
EVENTS = [
    {"id": "biblioteca", "title": "Biblioteca Sumergida", "img": "📚",
     "text": "Estanterías medio hundidas guardan tomos que no se han mojado jamás. Uno de ellos se abre solo a tu paso.",
     "ap": "a half flooded ancient library with tall bookshelves rising from dark water, floating glowing books, candles, shafts of moonlight"},
    {"id": "jugador", "title": "El Jugador de Dados", "img": "🎲",
     "text": "Un hombrecillo de sonrisa dorada agita un cubilete junto al camino. \"¿Una partida? La suerte es la única musa que nunca miente.\"",
     "ap": "a shady roadside gambling table lit by a single lantern, golden dice and coins scattered, a mysterious hooded figure's hands shaking a dice cup, dark forest road"},
    {"id": "espejo", "title": "Espejo de las Musas", "img": "🪞",
     "text": "Un espejo de marco dorado flota sobre el suelo. Tu reflejo no te imita: te observa, curioso.",
     "ap": "an ornate golden mirror floating above the ground in a dark ruined hall, its surface glowing with swirling starlight, petals and dust in the air"},
    {"id": "peregrina", "title": "Peregrina Herida", "img": "🕯️",
     "text": "Una peregrina descansa junto a un farol apagado, con la pierna vendada. \"Llevo días caminando hacia la torre... ¿me ayudarías?\"",
     "ap": "a wounded pilgrim resting against a mossy stone shrine at night, a cloak and a walking staff, an unlit lantern, seen from behind, melancholic atmosphere"},
    {"id": "recuerdo", "title": "Un Recuerdo", "img": "💭",
     "text": "Algo en este lugar te resulta dolorosamente familiar.",
     "textBy": {
         "zafiro": "Entre la bruma ves el estandarte de los Acorazados ondeando sobre una muralla que ya no existe. Por un instante oyes a tus hermanos de armas llamarte por tu nombre.",
         "lia": "Un zorro plateado te observa desde la maleza, igual que aquel que te enseñó a cazar en los Bosques Verdes. Sonríe, si es que los zorros sonríen.",
         "claudia": "La luna violeta se refleja en un charco y, en su fondo, una niña juega con una mano de huesos. Osty se agita, inquieto.",
         "aurora": "Un rayo de sol se cuela entre las ruinas y dibuja en el suelo los pasos de la primera danza que aprendiste en el templo del solio.",
         "irene": "Un tictac familiar suena a tu espalda. Por un momento recuerdas unas manos cálidas girando tu llave... y luego, nada.",
         "selene": "La espuma canta la nana con la que naciste. Las olas te llaman por un nombre que habías olvidado."},
     "ap": "a dreamlike memory scene, a ghostly translucent vision floating in a misty ruined place, soft golden light, nostalgic and melancholic, petals in the air"},
    # --- Acto I
    {"id": "naufragio", "title": "Barco Naufragado", "img": "⛵", "act": 1,
     "text": "El casco de un galeón asoma entre las aguas negras del muelle. Algo brilla en la bodega... y algo se mueve en el camarote.",
     "ap": "a wrecked pirate galleon half sunk in black harbor water at night, broken masts, a faint gold glow inside the hull, fog, lanterns on rotten docks"},
    {"id": "kraken", "title": "Ojo en la Marea", "img": "🐙", "act": 1,
     "text": "Bajo el agua, un ojo enorme se abre y te sigue. Un tentáculo emerge despacio y se queda inmóvil, esperando.",
     "ap": "a gigantic glowing eye opening beneath dark harbor water, a huge tentacle rising slowly out of the sea next to a rotten pier, eerie green bioluminescence"},
    # --- Acto II
    {"id": "susurros", "title": "Árbol de los Susurros", "img": "🌳", "act": 2,
     "text": "Las ramas de este árbol murmuran secretos en una lengua antigua. Algunos frutos brillan entre las hojas.",
     "ap": "an enormous ancient whispering tree with faces in its bark, glowing fruits hanging from its branches, mist and fireflies in an overgrown forest"},
    {"id": "hadas", "title": "Círculo de Hadas", "img": "🧚", "act": 2,
     "text": "Un anillo de setas luminosas rodea un claro. Diminutas luces bailan y ríen, invitándote a entrar.",
     "ap": "a fairy ring of glowing mushrooms in a dark forest clearing, tiny dancing lights like fairies, magical sparkles, moonlight"},
    # --- Acto III
    {"id": "panal", "title": "Panal Rebosante", "img": "🍯", "act": 3,
     "text": "Un panal del tamaño de una casa gotea miel dorada. El zumbido de su interior es tranquilo... por ahora.",
     "ap": "a gigantic dripping honeycomb wall overflowing with glowing golden honey, warm amber light, inside a vast hive cavern"},
    {"id": "trono", "title": "Trono Vacío", "img": "👑", "act": 3,
     "text": "En una sala de cera endurecida se alza un trono sin dueño. Una corona descansa sobre el asiento, esperando una cabeza.",
     "ap": "an empty royal throne made of amber wax and honeycomb in a dark hive throne room, a golden crown resting on the seat, dramatic god rays"},
    # --- Exclusivos de cada musa
    {"id": "coliseo", "title": "Arena de los Acorazados", "img": "🛡️", "char": "zafiro",
     "text": "Reconoces la arena donde entrenabas de joven. Los muñecos de práctica siguen en pie, cubiertos de óxido.",
     "ap": "an abandoned knights' training arena with rusted practice dummies, broken weapon racks, red banners torn by the wind, dramatic sunset"},
    {"id": "madriguera", "title": "Madriguera del Zorro Plateado", "img": "🦊", "char": "lia",
     "text": "Un rastro de huellas plateadas lleva a una madriguera. Dentro hay un pequeño tesoro de cazadora... y una piedra de afilar.",
     "ap": "a cozy hidden fox den under the roots of a big tree, silver glowing fox footprints, a small hunter's stash with daggers and vials, green forest light"},
    {"id": "osario", "title": "Osario Olvidado", "img": "🦴", "char": "claudia",
     "text": "Miles de huesos descansan ordenados en nichos. Osty se acerca a ellos con algo parecido al cariño.",
     "ap": "a vast gothic ossuary with walls of skulls and bones in niches, violet candlelight, an eerie peaceful atmosphere, purple mist"},
    {"id": "templo_sol", "title": "Templo del Solio", "img": "🌞", "char": "aurora",
     "text": "Un pequeño templo dorado resiste entre las ruinas. En su altar arde todavía la llama de las danzarinas.",
     "ap": "a small golden sun temple among ruins, a sacred flame burning on an altar, golden mirrors reflecting sunlight, saffron silk curtains"},
    {"id": "taller", "title": "Taller del Relojero", "img": "⚙️", "char": "irene",
     "text": "Un taller polvoriento lleno de muñecas a medio montar. Sobre la mesa, herramientas que parecen hechas para tus manos.",
     "ap": "a dusty clockmaker's workshop full of half assembled porcelain dolls wearing little dark velvet dresses and lace bonnets, brass gears and springs on a wooden table, warm lamp light"},
    {"id": "poza_lunar", "title": "Poza Lunar", "img": "🌙", "char": "selene",
     "text": "Una poza de agua inmóvil refleja una luna que no está en el cielo. Al acercarte, el agua empieza a cantar.",
     "ap": "a still moonlit pool in a dark grotto reflecting a full moon that is not in the sky, glowing pearls at the bottom, silver mist"},
    # --- Fase 4B: hallazgos raros, una sola vez por partida (usan el fondo general como fallback)
    {"id": "campana_bruma", "title": "Campana de la Bruma", "img": "🔔", "act": 1, "once": True, "weight": 0.22,
     "text": "Una campana verde oscilante cuelga de un mástil sin barco. No la mueve el viento. Dentro del bronce, una luz parpadea al ritmo de tus pasos.",
     "ap": "an ancient verdigris ship bell hanging from a single mast surrounded by spectral fog, mysterious soft light inside the bell, abandoned docks"},
    {"id": "corazon_hueco", "title": "El Corazón Hueco", "img": "💚", "act": 2, "once": True, "weight": 0.22,
     "text": "En el tronco de un roble abierto late un corazón de madera. Sus raíces se apartan con suavidad; saben que has venido a elegir qué llevarte.",
     "ap": "a hollow ancient oak with a glowing wooden heart inside, gentle roots opening like hands, emerald sap and drifting leaves"},
    {"id": "cera_memoria", "title": "La Cera Recuerda", "img": "🕯️", "act": 3, "once": True, "weight": 0.22,
     "text": "Un banco de cera tibia conserva la forma de las cartas que tocas. Las figuras cambian bajo tus dedos como si el panal recordara otra versión de tu viaje.",
     "ap": "a warm beeswax worktable holding luminous card shaped impressions, gentle golden steam, amber workshop inside a giant hive"},
]

# Descripciones para los iconos (se copian a tools/gen_icons.py).
ICON_DESC = {
    "relic": {
        "colmillo": "a large white wolf fang on a leather cord",
        "medallon": "a round bronze apothecary medallion with a small potion bottle engraved",
        "tinta": "a small glass bottle of black squid ink with a tentacle curling around it",
        "caparazon": "a polished turtle shell glowing with a soft green shine",
        "brujula": "an antique bronze compass with a glowing needle",
        "reloj_arena": "an ornate hourglass with glowing golden sand",
        "huevo": "a speckled golden griffin egg with feathers around it",
        "pluma": "a blazing phoenix feather of red and gold fire",
        "cristal": "a faceted violet crystal echoing rings of light",
        "amuleto": "a blue eye amulet charm with wave patterns",
        "corona_espinas": "a crown of black thorns with red roses",
        "reloj_roto": "a cracked silver pocket watch with stopped hands",
        "estandarte": "a small crimson battle standard with a golden knight crest",
        "guantelete": "an armored gauntlet glowing with red hot fire",
        "corazon_volcan": "a heart shaped volcanic rock with glowing lava cracks",
        "bandolera": "a leather bandolier holding green glowing throwing knives",
        "colmillo_vibora": "a viper fang dripping green venom",
        "capa_sombra": "a folded black cloak with bat wing edges and purple shadows",
        "craneo_cristal": "a crystal skull glowing violet",
        "grimorio": "a forbidden black grimoire with a violet glowing eye on the cover and chains",
        "luna_violeta": "a violet full moon orb on a silver stand",
        "abanico_espejo": "a golden folding fan with mirror facets reflecting sunlight",
        "sol_naciente": "a golden sunrise emblem with radiant rays",
        "eclipse": "a bright golden ring of a total solar eclipse, brilliant gold corona flames around a black disc, glowing",
        "muelle_doble": "a pair of brass clockwork springs intertwined",
        "caracola_abismal": "a dark spiral seashell with a deep blue abyssal glow inside",
    },
    "potion": {
        "duplicar": "a glass flask of violet potion with two mirrored swirls",
        "herrero": "a glass flask of orange molten metal potion with a tiny hammer",
        "gambito": "a glass flask of pink potion with playing cards floating around it",
        "agilidad": "a glass flask of mint green potion with a winged foot symbol",
        "espinas": "a glass flask of green potion with thorns growing on the glass",
        "savia": "a glass flask of glowing green sap with a sprouting leaf",
        "brea": "a round black tar bomb with a lit fuse",
        "memoria": "a glass flask of pale blue liquid with a ghostly card inside",
    },
    "status": {
        "regen": "a glowing green sprouting leaf with healing sparkles",
    },
}


def main():
    enemies_extra = {"enemies": {}, "encounters": ENCOUNTERS}
    jobs = []
    seed = 52000
    for eid, e in ENEMIES.items():
        d = dict(e)
        d["id"] = eid
        d["ap"] = f"{e['ap']}, {ENEMY_STYLE}"
        enemies_extra["enemies"][eid] = d
        if eid in ART_COPIES:
            continue
        seed += 7
        big = e["tier"] == "boss"
        jobs.append({"kind": "image", "name": f"enemy_{eid}", "lora": "karen_krea2.safetensors", "w": 640 if big else 512, "h": 640 if big else 512,
                     "seed": seed, "strength": 0, "prompt": d["ap"], "out": f"assets/enemies/{eid}.webp"})
    events = []
    for ev in EVENTS:
        d = {k: v for k, v in ev.items() if k != "ap"}
        events.append(d)
        if ev.get("once"):
            continue
        seed += 7
        jobs.append({"kind": "image", "name": f"ev_{ev['id']}", "lora": "karen_krea2.safetensors", "w": 1280, "h": 720,
                     "seed": seed, "strength": 0, "prompt": f"{ev['ap']}, {EVENT_STYLE}", "out": f"assets/bg/ev_{ev['id']}.webp"})
    (ROOT / "data" / "enemies_extra.json").write_text(json.dumps(enemies_extra, ensure_ascii=False, indent=1))
    (ROOT / "data" / "events_extra.json").write_text(json.dumps({"events": events}, ensure_ascii=False, indent=1))
    (ROOT / "data" / "relics_extra.json").write_text(json.dumps({"relics": RELICS, "potions": POTIONS}, ensure_ascii=False, indent=1))
    (ROOT / "data" / "states_extra.json").write_text(json.dumps({"st": STATES}, ensure_ascii=False, indent=1))
    (ROOT / "data" / "balance_w2.json").write_text(json.dumps(BALANCE, ensure_ascii=False, indent=1))
    (ROOT / "gen" / "jobs_w2.json").write_text(json.dumps(jobs, ensure_ascii=False, indent=1))
    (ROOT / "gen" / "icons_w2.json").write_text(json.dumps(ICON_DESC, ensure_ascii=False, indent=1))
    print(len(ENEMIES), "enemigos;", len(EVENTS), "eventos;", len(RELICS), "reliquias;", len(POTIONS), "pociones;", len(jobs), "imágenes")


if __name__ == "__main__":
    main()
