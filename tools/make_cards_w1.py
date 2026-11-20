"""Oleada 1 de cartas: +9 por musa y un pool neutral de 23.
Genera data/cards_extra.json (cartas + pools) y gen/jobs_cards_w1.json (prompts de arte para gen/comfy.py).
Solo usa mecánicas que el motor ya soporta (claves fx existentes), así que no cambia la lógica de combate.
Uso: python3 tools/make_cards_w1.py
"""
import json, pathlib

ROOT = pathlib.Path(__file__).resolve().parent.parent

STYLE = ("Painterly fantasy digital illustration, concept art for a card game, visible brush strokes, rich saturated colors, "
         "stylized painted environment and effects (not a photograph), only her face and skin are realistic and sharply defined. ")
STYLE_NEUTRAL = ("Painterly dark fantasy digital illustration, concept art for a card game, visible brush strokes, rich saturated colors, "
                 "dramatic lighting, no people facing the camera, ")
END = " No text, no watermark."

MUSE = {
    "zafiro": dict(lora="miranda_capurro_krea2.safetensors", strength=0.85,
        who="The heroine: a single young woman, miranda_capurro, with a photorealistic sharply defined real human face, intense dark eyes, dark brown hair pulled back, wearing dark ornate plate armor with a long torn red cape and wielding a big greatsword."),
    "lia": dict(lora="staryuuki_krea2_v2.safetensors", strength=0.85,
        who="The heroine: a single young woman, staryuuki, with a photorealistic sharply defined real human face, grey-green eyes, black hair with straight bangs, wearing a black hooded jacket with leather straps and carrying curved daggers."),
    "claudia": dict(lora="karen_krea2.safetensors", strength=0.85,
        who="The heroine: a single pale gothic young woman, karen_character, with a photorealistic sharply defined real human face, long straight black hair with bangs, wearing a black coat with a fur collar, gold trim and red lining, accompanied by a ghostly skeletal left hand."),
    "aurora": dict(lora="SadieS_SoloLoRA_Kr2v1.safetensors", strength=0.85,
        who="The heroine: a single young woman with a photorealistic, sharply defined real human face, symmetrical honey-amber eyes, bronze tan skin, wavy chestnut hair with golden combs, saffron and gold silk dancer outfit, gold jewelry, holding large gold filigree folding hand fans with mirror facets."),
    "irene": dict(lora="RLY-thot_shot-KREA2-irena-v1.safetensors", strength=0.85,
        who="The heroine: a single young clockwork doll woman, rlyirena, with a photorealistic sharply defined real human face, symmetrical light blue-grey eyes, long wavy blonde hair, dusty rose pink Victorian lace dress, white lace-up boots and a large brass winding key on her back."),
    "selene": dict(lora="RLY-thot_shot-KREA2-jada-v11-trigger-rlyjada.safetensors", strength=0.85,
        who="The heroine: a single young woman, rlyjada, with a photorealistic sharply defined real human face, dark brown eyes, long wavy dark brown hair, a flowing deep teal-blue silk gown with white-silver trim and a necklace of large white pearls, barefoot."),
}

# (id, nombre, tipo, coste, rareza, fx, up, flags, escena)
# up = {"fx": {...}} solo con las claves que cambian; flags opcionales
A, S, P = "attack", "skill", "power"
CARDS = {
 "zafiro": [
  ("dragon_breath", "Aliento de Dragón", A, 1, "common", {"dmg": 7, "all": True, "selfdmg": 2}, {"fx": {"dmg": 10}}, {}, "exhaling a cone of roaring flame from her mouth sweeping across a line of enemies, scorched courtyard, embers"),
  ("shoulder", "Espaldarazo", A, 1, "common", {"dmg": 6, "block": 6}, {"fx": {"dmg": 8, "block": 8}}, {}, "low angle shoulder-charge slamming an armored soldier backward, shield-like pauldron, dust and sparks"),
  ("warcry", "Grito de Batalla", S, 1, "common", {"tstr": 3, "block": 5}, {"fx": {"tstr": 4, "block": 7}}, {}, "roaring a war cry with sword raised high, shockwave rings, red cape flaring, army silhouettes behind"),
  ("shatter", "Sacudida de Coraza", A, 2, "uncommon", {"dmgBlock": True, "all": True}, {"fx": {"vuln": 1}}, {}, "slamming her armored gauntlet into the ground releasing a metallic shockwave that flings enemies, cracked flagstones"),
  ("old_blood", "Sangre Vieja", S, 0, "uncommon", {"selfdmg": 4, "str": 1, "draw": 1}, {"fx": {"str": 2}}, {"exhaust": True}, "cutting her palm over her sword, glowing crimson blood running down the blade, eyes burning, dark chapel"),
  ("quake", "Golpe Sísmico", A, 2, "uncommon", {"dmg": 11, "strMul": 3, "vuln": 2}, {"fx": {"dmg": 14, "strMul": 4}}, {}, "overhead greatsword strike cracking the earth in a radial fissure, rocks flying, an enemy staggering"),
  ("living_wall", "Muro Viviente", P, 2, "uncommon", {"pw": {"metallicize": 3, "thorns": 1}}, {"fx": {"pw": {"metallicize": 4, "thorns": 2}}}, {}, "standing unmoving as thousands of arrows shatter against her armor, spikes growing from her pauldrons, stormy battlefield"),
  ("ember_armor", "Armadura de Brasas", P, 2, "rare", {"pw": {"metallicize": 4, "combust": 5}}, {"fx": {"pw": {"metallicize": 5, "combust": 7}}}, {}, "her whole plate armor glowing red-hot with molten cracks and rising heat shimmer, flames licking her cape, dark forge"),
  ("guillotine", "Guillotina Roja", A, 2, "rare", {"dmg": 18, "strMul": 5}, {"fx": {"dmg": 22, "strMul": 6}}, {"exhaust": True}, "executioner-style falling greatsword stroke trailing a crimson arc of light, a towering ogre mid-collapse, ruined arena"),
 ],
 "lia": [
  ("hidden_knife", "Cuchillo Escondido", S, 0, "common", {"add": {"id": "lia_shiv", "n": 1, "to": "hand"}, "draw": 1}, {"fx": {"add": {"id": "lia_shiv", "n": 2, "to": "hand"}}}, {}, "pulling a thin dagger from her boot with a playful smirk, moonlit alley, a sleeping guard behind"),
  ("ambush", "Emboscada", A, 1, "common", {"dmg": 9, "vuln": 1}, {"fx": {"dmg": 12, "vuln": 2}}, {}, "dropping from a tree branch onto a bandit with both daggers, forest canopy, falling leaves"),
  ("toxic_dew", "Rocío Tóxico", S, 1, "common", {"poison": 4, "block": 5}, {"fx": {"poison": 6, "block": 7}}, {}, "flicking glowing green droplets from a vial toward a monster while ducking behind a cloak, swamp mist"),
  ("blade_dance", "Danza de Filos", A, 1, "uncommon", {"dmg": 3, "hits": 3}, {"fx": {"dmg": 4}}, {}, "spinning pirouette slashing three times with twin daggers, afterimages of blades, moonlit rooftop"),
  ("steel_burst", "Ráfaga de Acero", S, 1, "uncommon", {"add": {"id": "lia_shiv", "n": 2, "to": "hand"}, "block": 6}, {"fx": {"add": {"id": "lia_shiv", "n": 3, "to": "hand"}, "block": 8}}, {}, "tossing a fan of silver daggers into the air that hover around her like a shield, dark forest clearing"),
  ("paralysis", "Aguja Paralizante", A, 1, "uncommon", {"dmg": 6, "weak": 2, "poison": 3}, {"fx": {"dmg": 8, "weak": 3, "poison": 4}}, {}, "jabbing a long glowing needle into a hulking brute's neck, green veins spreading under his skin, tavern shadows"),
  ("shadow_agile", "Sombra Ágil", P, 1, "uncommon", {"dex": 1, "pw": {"accuracy": 3}}, {"fx": {"dex": 2, "pw": {"accuracy": 4}}}, {}, "leaping across rooftops in a blur of black cloth with her shadow stretching behind her, full moon, city of chimneys"),
  ("plague", "Plaga Total", S, 2, "rare", {"poison": 9, "all": True}, {"fx": {"poison": 12}}, {"exhaust": True}, "holding up a cracked glass orb that releases a spreading cloud of glowing green plague over a horde of monsters, ruined village"),
  ("blade_waltz", "Vals de Cuchillas", A, 3, "rare", {"dmg": 4, "hits": 4, "all": True}, {"fx": {"dmg": 5}}, {}, "a whirlwind waltz in the middle of a circle of enemies, countless flying daggers forming a glittering ring, ballroom turned battlefield"),
 ],
 "claudia": [
  ("osty_claw", "Zarpa de Osty", A, 1, "common", {"ostyHit": 6}, {"fx": {"ostyHit": 9}}, {}, "the giant ghostly skeletal left hand raking its claws across a monster while she watches calmly, violet mist, crypt"),
  ("bone_whisper", "Murmullo de Huesos", S, 1, "common", {"block": 7, "ostyHeal": 4}, {"fx": {"block": 10, "ostyHeal": 6}}, {}, "whispering to a swarm of small bones that knit together into a protective wall around her, candlelit catacomb"),
  ("minor_harvest", "Cosecha Menor", A, 1, "common", {"dmg": 7, "exhaustPick": 1}, {"fx": {"dmg": 10}}, {}, "slashing a scythe of violet light through a monster while a card-like glowing page burns away in her other hand, graveyard"),
  ("skeletal_guard", "Guardián Esquelético", S, 2, "uncommon", {"summon": 8, "block": 8}, {"fx": {"summon": 10, "block": 11}}, {}, "a towering armored skeleton guardian rising from the ground beside her with a tower shield, purple lightning, cemetery gates"),
  ("twin_bite", "Mordida Doble", A, 1, "uncommon", {"ostyHit": 4, "hits": 2, "weak": 1}, {"fx": {"ostyHit": 6}}, {}, "the skeletal left hand snapping twice like jaws at a snarling ghoul, bone fragments flying, mausoleum"),
  ("requiem", "Réquiem", A, 2, "uncommon", {"dmg": 8, "all": True, "ostyHit": 4}, {"fx": {"dmg": 11, "ostyHit": 6}}, {}, "conducting an unseen choir with her arms raised while a wave of violet spectral sound sweeps over all enemies, gothic cathedral ruins"),
  ("blood_ritual", "Ritual de Sangre", S, 0, "uncommon", {"selfdmg": 3, "ostyPow": 1, "draw": 1}, {"fx": {"ostyPow": 2}}, {}, "drawing a crimson sigil on the floor with her own blood while the ghostly hand grows larger behind her, candlelit ritual circle"),
  ("bone_throne", "Trono de Huesos", P, 2, "rare", {"ostyPow": 2, "pw": {"ostyRegen": 4}}, {"fx": {"ostyPow": 3, "pw": {"ostyRegen": 6}}}, {}, "seated on a colossal throne of fused skeletons with the ghostly hand resting on its armrest, violet fire torches, vast ossuary hall"),
  ("violet_eclipse", "Eclipse Violeta", A, 3, "rare", {"dmg": 20, "all": True, "ostyHit": 8}, {"fx": {"dmg": 26, "ostyHit": 10}}, {"exhaust": True}, "a violet eclipse swallowing the sky over a battlefield as a colossal spectral hand descends and crushes everything below, she stands calm"),
 ],
 "aurora": [
  ("ember_petal", "Pétalo Ardiente", A, 1, "common", {"dmg": 6, "heat": 1}, {"fx": {"dmg": 9, "heat": 2}}, {}, "flicking a burning petal from her fan that streaks toward an enemy, rose-gold sparks, sunset temple courtyard"),
  ("gilded_veil", "Velo Dorado", S, 1, "common", {"block": 7, "glow": 1, "all": True}, {"fx": {"block": 10}}, {}, "twirling a translucent golden veil that flares blinding light across a group of enemies, marble temple, sunbeams"),
  ("flame_spin", "Giro Ardiente", A, 1, "common", {"dmg": 5, "hits": 2, "heat": 1}, {"fx": {"dmg": 7}}, {}, "spinning twice with both fans leaving a spiral of fire, wind-whipped silk, desert dunes at golden hour"),
  ("blinding_gleam", "Resplandor Cegador", S, 1, "uncommon", {"weak": 2, "vuln": 1, "all": True}, {"fx": {"weak": 3, "vuln": 2}}, {}, "raising a mirror fan to reflect the sun into a dazzling beam that blinds a crowd of enemies, shielding their eyes, white-gold flare"),
  ("dawn_dance", "Danza del Amanecer", S, 0, "uncommon", {"heat": 2, "energyIfAttack": 1}, {"fx": {"heat": 3}}, {"dance": True}, "dancing with arms wide at the break of dawn on a temple rooftop, first sunrays igniting her veils, warm golden mist"),
  ("ray_rain", "Lluvia de Rayos", A, 2, "uncommon", {"dmg": 4, "hits": 3, "all": True}, {"fx": {"dmg": 6}}, {}, "dozens of thin golden rays raining from the sky through the temple ceiling onto enemies while she stands in the light"),
  ("burning_mirror", "Espejo Ardiente", S, 2, "uncommon", {"block": 8, "reflect": True, "heat": 1}, {"fx": {"block": 11}}, {}, "holding a huge burning mirror shield that reflects a monster's blast back at it, molten gold frame, ruined arena"),
  ("golden_eclipse", "Eclipse Dorado", A, 3, "rare", {"dmg": 14, "heatDmg": 8, "all": True}, {"fx": {"dmg": 18, "heatDmg": 10}}, {}, "a golden solar eclipse overhead with a corona of fire while she stands on a ziggurat with fans spread wide, enemies below silhouetted"),
  ("sun_hymn", "Himno del Sol", S, 0, "rare", {"heat": 4, "energy": 1, "draw": 2}, {"fx": {"heat": 6}}, {"exhaust": True, "dance": True}, "singing and dancing before a colossal rising sun disc, golden choir of veiled dancers behind her, radiant glory"),
 ],
 "irene": [
  ("loose_gear", "Engranaje Suelto", A, 0, "common", {"dmg": 4, "wind": 1}, {"fx": {"dmg": 6}}, {"gear": True}, "pulling a spinning brass cog loose from her own wrist and flicking it like a throwing disc, workshop sparks"),
  ("reinforced_spring", "Muelle Reforzado", S, 1, "common", {"block": 8, "wind": 1}, {"fx": {"block": 11}}, {"gear": True}, "a giant coiled steel spring bracing her against a crashing blow, brass pistons, factory floor"),
  ("pendulum_blow", "Golpe de Péndulo", A, 1, "common", {"dmg": 5, "vuln": 1}, {"fx": {"dmg": 7, "vuln": 2}}, {"gear": True}, "swinging a heavy brass pendulum weight like a mace into an enemy's chest, grandfather clock tower"),
  ("quick_wind", "Cuerda Rápida", S, 0, "common", {"wind": 3, "draw": 1, "selfdmg": 1}, {"fx": {"wind": 4}}, {}, "frantically cranking the brass key on her back with a tiny grimace, steam hissing from her joints, dim clockwork attic"),
  ("clockwork_chain", "Cadena de Relojería", A, 1, "uncommon", {"dmg": 4, "hits": 3}, {"fx": {"dmg": 5}}, {"gear": True}, "three rapid precise strikes with a chain of linked small cogs, a ribbon of motion blur, watchmaker's studio"),
  ("clock_tower", "Torre del Reloj", S, 2, "uncommon", {"block": 10, "weak": 1, "all": True}, {"fx": {"block": 14}}, {"gear": True}, "a vast clock tower face behind her chiming a shockwave that staggers enemies, mist over a Victorian city"),
  ("spring_discharge", "Descarga de Muelle", A, 2, "uncommon", {"dmg": 8, "all": True, "windSpend": 2}, {"fx": {"windSpend": 3}}, {}, "a huge wound spring bursting open and releasing a shockwave of cogs and light that flings enemies away, brass cathedral"),
  ("fine_clockwork", "Relojería Fina", P, 1, "uncommon", {"pw": {"precision": 2, "resorte": 1}}, {"fx": {"pw": {"precision": 3, "resorte": 1}}}, {}, "an intricate glowing blueprint of interlocking tiny gears floating around her hands as she adjusts a mechanism, loupe, lamplit bench"),
  ("colossal_automaton", "Autómata Colosal", A, 3, "rare", {"dmg": 20, "block": 20}, {"fx": {"dmg": 26, "block": 26}}, {"gear": True}, "a colossal brass automaton towering behind her punching down a gate while she stands unflinching in its shadow, steam and gears"),
  ("clock_heart", "Corazón de Reloj", P, 2, "rare", {"pw": {"tictac": 4, "resorte": 2}}, {"fx": {"pw": {"tictac": 6, "resorte": 2}}}, {}, "her porcelain chest open revealing a glowing golden clockwork heart beating in perfect rhythm, light pouring through the gears, dark void"),
 ],
 "selene": [
  ("stray_drop", "Gota Rebelde", A, 0, "common", {"dmg": 3, "ch": ["ola"]}, {"fx": {"dmg": 5}}, {}, "a single glowing blue water droplet leaping from her fingertip into an enemy's face, splash crown, cave pool"),
  ("mist_veil", "Velo de Bruma", S, 1, "common", {"block": 7, "ch": ["bruma"]}, {"fx": {"block": 10}}, {}, "wrapping herself in a swirling veil of sea mist that deflects arrows, lighthouse cliff at dawn"),
  ("shining_conch", "Caracola Brillante", S, 1, "common", {"ch": ["perla"], "draw": 1}, {"fx": {"draw": 2}}, {}, "holding a glowing conch shell to her ear and listening as a pearl forms in its mouth, tide pool at twilight"),
  ("rising_tide", "Marea Creciente", A, 2, "uncommon", {"dmg": 8, "ch": ["ola", "bruma"]}, {"fx": {"dmg": 11}}, {}, "a wall of rising sea water surging up a stone staircase with her at its crest, moonlit harbor, spray"),
  ("pearl_whirl", "Torbellino de Perlas", A, 2, "uncommon", {"dmgPerOrb": 4, "all": True, "ch": ["perla"]}, {"fx": {"dmgPerOrb": 5}}, {}, "a swirling vortex of glowing pearls and sea foam sweeping around her and out across an enemy crowd, underwater temple"),
  ("abyssal_echo", "Eco Abismal", S, 1, "uncommon", {"ch": ["abismo"], "evoke": 1}, {"fx": {"draw": 1}}, {}, "dropping a pebble into a bottomless black well while a deep echo ripples outward in glowing rings, bioluminescent depths"),
  ("silver_current", "Corriente de Plata", P, 1, "uncommon", {"focus": 1, "slots": 1}, {"fx": {"focus": 2}}, {}, "a river of silver light flowing around her arms and widening into extra glowing orbs, moonlit estuary"),
  ("siren_song", "Canto de Sirena", S, 1, "uncommon", {"weak": 2, "all": True, "ch": ["bruma"]}, {"fx": {"weak": 3}}, {}, "singing with eyes closed on a rock in the sea while enemy sailors drop their weapons entranced, glowing sound waves over waves"),
  ("colossal_wave", "Ola Colosal", A, 3, "rare", {"dmgPerOrb": 7, "all": True, "evoke": 1}, {"fx": {"dmgPerOrb": 9}}, {"exhaust": True}, "a mountain-sized wave rearing over a fleet of enemy ships with her tiny figure standing on the crest, storm sky, epic scale"),
  ("endless_tide", "Marea Perpetua", P, 2, "rare", {"pw": {"marea_alta": 1, "corriente": 3}}, {"fx": {"pw": {"marea_alta": 1, "corriente": 4}}}, {}, "the tide endlessly rising and falling around her in a spiral beneath twin moons, glowing orbs orbiting, vast tidal plain"),
 ],
}

# Pool neutral (sin musa): id, nombre, tipo, coste, rareza, fx, up, flags, escena
N = [
 ("second_wind", "Segundo Aliento", S, 1, "common", {"heal": 4, "block": 6}, {"fx": {"heal": 6, "block": 9}}, {}, "a weary traveler's hands cupping a glowing spring of water at dawn, warm light, mossy stones"),
 ("focus", "Concentración", S, 0, "common", {"draw": 2, "discard": 1}, {"fx": {"draw": 3}}, {}, "a candle flame burning perfectly still inside a dark empty room, a single sheet of light on a desk"),
 ("improvised_guard", "Guardia Improvisada", S, 1, "common", {"block": 9}, {"fx": {"block": 12}}, {}, "a wooden tavern door torn off its hinges and raised as a shield with arrows stuck in it, dusty road"),
 ("sure_strike", "Golpe Certero", A, 1, "common", {"dmg": 8}, {"fx": {"dmg": 11}}, {}, "a plain iron sword striking a stone, a bright spark flying, workshop forge background"),
 ("trip", "Zancadilla", A, 1, "common", {"dmg": 5, "weak": 1, "vuln": 1}, {"fx": {"dmg": 7, "weak": 2}}, {}, "a taut rope strung across a dark alley sending a heavy armored boot tumbling, lantern light"),
 ("ration", "Ración de Campaña", S, 1, "common", {"heal": 6}, {"fx": {"heal": 9}}, {"exhaust": True}, "bread, cheese and a flask on a cloth beside a small campfire under the stars"),
 ("scavenge", "Rebusca", S, 1, "common", {"draw": 2, "exhaustPick": 1}, {"fx": {"draw": 3}}, {}, "a gloved hand rummaging through a pile of old books and trinkets in a ruined library, dust motes in light"),
 ("purge", "Purga", S, 0, "common", {"exhaustPick": 1, "block": 4, "draw": 1}, {"fx": {"block": 7}}, {}, "a page of black ink burning to nothing in a silver brazier, clean white smoke, dark chapel"),
 ("lucky_blow", "Golpe de Suerte", A, 0, "common", {"dmg": 4, "draw": 1}, {"fx": {"dmg": 6}}, {}, "a pair of old bone dice mid-air with a golden coin glinting beside them, tavern table"),
 ("hunters_mark", "Marca del Cazador", S, 1, "common", {"vuln": 2}, {"fx": {"vuln": 3}}, {}, "a glowing red sigil burned into a wooden post at the edge of a dark forest, drifting embers"),
 ("courage_rush", "Descarga de Valor", S, 0, "uncommon", {"energy": 1, "draw": 1}, {"fx": {"draw": 2}}, {"exhaust": True}, "a burst of golden light from a raised fist clenching a torn banner, wind and sparks"),
 ("stand_firm", "Plantar Cara", S, 1, "uncommon", {"block": 7, "tstr": 2}, {"fx": {"block": 10, "tstr": 3}}, {}, "a lone figure planting a heavy boot and a spear in the mud as a wave of foes approaches, rain and torches"),
 ("smoke_bomb", "Bomba de Humo", S, 1, "uncommon", {"weak": 2, "block": 6, "all": True}, {"fx": {"weak": 3, "block": 9}}, {}, "a clay bomb bursting into a thick cloud of violet smoke in a narrow street, silhouettes coughing"),
 ("camp_tonic", "Tónico de Campamento", S, 1, "uncommon", {"heal": 8, "draw": 1}, {"fx": {"heal": 11}}, {"exhaust": True}, "a small glass bottle of golden tonic glowing on a mossy log beside a lantern in the forest"),
 ("all_or_nothing", "Todo o Nada", S, 0, "uncommon", {"draw": 3, "selfdmg": 2}, {"fx": {"draw": 4}}, {"exhaust": True}, "a hand pushing a pile of gold coins into the center of a candlelit table, tense shadows, a dagger beside"),
 ("desperate_charge", "Carga Desesperada", A, 2, "uncommon", {"dmg": 14, "selfdmg": 3}, {"fx": {"dmg": 18}}, {}, "a rusted spear thrown through a collapsing gate in a blaze of torchlight, soldiers diving aside"),
 ("barrage", "Andanada", A, 1, "uncommon", {"dmg": 4, "hits": 3}, {"fx": {"dmg": 5}}, {}, "three arrows in flight frozen in a line over a misty valley, feathered shafts, soft dawn"),
 ("shockwave", "Onda de Choque", A, 2, "uncommon", {"dmg": 9, "all": True, "vuln": 1}, {"fx": {"dmg": 12}}, {}, "a circular shockwave of dust and cracked cobblestones spreading from a crater in a plaza, debris floating"),
 ("strategic_pause", "Pausa Estratégica", S, 1, "uncommon", {"energy": 2}, {"fx": {"energy": 3}}, {"exhaust": True}, "an hourglass with golden sand frozen mid-fall on a war table with a map and carved pieces"),
 ("second_chance", "Segunda Oportunidad", S, 1, "rare", {"heal": 12, "block": 12}, {"fx": {"heal": 16, "block": 16}}, {"exhaust": True}, "a phoenix feather glowing gold lying in the ashes of a burnt battlefield, first dawn light"),
 ("destiny_blow", "Golpe del Destino", A, 2, "rare", {"dmg": 24}, {"fx": {"dmg": 32}}, {"exhaust": True}, "a single colossal sword of white light falling from the clouds onto a dark plain, a moment before impact"),
 ("vigil", "Vigilia", P, 2, "rare", {"draw": 1, "pw": {"metallicize": 3}}, {"fx": {"pw": {"metallicize": 4}}}, {}, "a lone stone sentinel statue keeping watch on a cliff at night, a lantern at its feet, stars wheeling above"),
 ("resolve", "Resolución", P, 1, "rare", {"str": 1, "dex": 1}, {"fx": {"str": 2, "dex": 2}}, {}, "a sword and a feather crossed on an old stone altar under a ray of light, ancient temple"),
]


# Fase 4 (poda del pool, Agente E): cartas retiradas. Se conserva su definición (partidas guardadas, colección) pero
# ya no salen en recompensas, tienda ni desbloqueos. Medido con tests/balance.gd VDM_EXPLORE=1: Δcoger negativo en
# las 6 musas (Carga Desesperada −10, Pausa Estratégica −7). Detalle en HANDOFF_AGENTE_E.md.
RETIRED = {"neu_desperate_charge", "neu_strategic_pause"}

# Fase 4: cartas nuevas para el arquetipo flojo de una musa. Reutilizan arte existente (campo «img» → la vista carga
# assets/cards/<img>.webp), así que no generan trabajos de arte. id, nombre, tipo, coste, rareza, fx, up, flags, img
# Probado y descartado (ronda 4): Aurora «Última Ascua» (común, coste 1, 4 de daño + consume Calor +3/carga). Un
# remate barato que consume TODO el Calor se juega pronto y deja sin carga a Clímax/Supernova: Aurora 40 → 37 %.
# Formato: "aurora": [("last_ember", "Última Ascua", "attack", 1, "common", {fx}, {up}, {flags}, "card_aurora_ember_petal")]
FASE4 = {}


def main():
    cards, pool, jobs = {}, {}, []
    seed = 31000
    for ch, lst in CARDS.items():
        pool[ch] = []
        for (cid, name, typ, cost, rar, fx, up, flags, scene) in lst:
            full = f"{ch}_{cid}"
            cards[full] = {"id": full, "name": name, "cls": ch, "type": typ, "rarity": rar, "cost": cost, "fx": fx, "up": up, "flags": flags, "ap": ""}
            if "dance" in flags:
                cards[full]["dance"] = True
                flags = {k: v for k, v in flags.items() if k != "dance"}
                cards[full]["flags"] = flags
            if "gear" in flags:
                cards[full]["gear"] = True
                cards[full]["flags"] = {k: v for k, v in flags.items() if k != "gear"}
            if full not in RETIRED:
                pool[ch].append(full)
            m = MUSE[ch]
            seed += 1
            jobs.append({"kind": "image", "name": f"card_{full}", "lora": m["lora"], "w": 512, "h": 384, "seed": seed, "strength": m["strength"],
                         "prompt": STYLE + scene + ". " + m["who"] + END})
    for ch, lst in FASE4.items():
        for (cid, name, typ, cost, rar, fx, up, flags, img) in lst:
            full = f"{ch}_{cid}"
            cards[full] = {"id": full, "name": name, "cls": ch, "type": typ, "rarity": rar, "cost": cost, "fx": fx, "up": up, "flags": flags, "ap": "", "img": img}
            pool[ch].append(full)
    pool["neutral"] = []
    for (cid, name, typ, cost, rar, fx, up, flags, scene) in N:
        full = f"neu_{cid}"
        cards[full] = {"id": full, "name": name, "cls": "neutral", "type": typ, "rarity": rar, "cost": cost, "fx": fx, "up": up, "flags": flags, "ap": ""}
        if full not in RETIRED:
            pool["neutral"].append(full)
        seed += 1
        jobs.append({"kind": "image", "name": f"card_{full}", "lora": "karen_krea2.safetensors", "w": 512, "h": 384, "seed": seed, "strength": 0,
                     "prompt": STYLE_NEUTRAL + scene + "." + END})
    (ROOT / "data" / "cards_extra.json").write_text(json.dumps({"cards": cards, "pool": pool}, ensure_ascii=False, indent=1))
    (ROOT / "gen" / "jobs_cards_w1.json").write_text(json.dumps(jobs, ensure_ascii=False, indent=1))
    print(len(cards), "cartas;", len(jobs), "imágenes")


if __name__ == "__main__":
    main()
