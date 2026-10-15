"""Genera los iconos del juego (reliquias, pociones, estados, nodos...) con ComfyUI local (Krea2 + darkbrush).
Uso: python3 tools/gen_icons.py [grupo ...]   grupos: relic potion node status intent ui orb
Salida: gen/icons_raw/<kind>_<id>.png  y  assets/icons/<kind>_<id>.webp (192 px)."""
import sys, json, pathlib, time
sys.path.insert(0, "/mnt/Datos/IngenieriaInversa/VersoDeMusas/gen")
import comfy
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "gen" / "icons_raw"; RAW.mkdir(parents=True, exist_ok=True)
OUT = ROOT / "assets" / "icons"; OUT.mkdir(parents=True, exist_ok=True)
comfy.OUT = RAW
LORA = "krea2_darkbrush.safetensors"
STYLE = ("dark fantasy game item icon, {d}, single object centered filling the frame, painterly digital illustration, rich detail, "
         "dramatic rim lighting, subtle glow, dark moody vignette background, no text, no watermark, no border")

STYLE2 = ("{d}, single bold object, thick solid shapes, clean strong silhouette, centered, painterly dark fantasy game icon, vivid saturated colors, "
          "strong rim light, isolated on a plain flat light gray background, no smoke, no mist, no particles, no frame, no border, no text, no watermark")

G = {
 "relic": {
  "brasa_carmesi": "a glowing crimson ember burning in a small iron brazier",
  "anillo_cazadora": "an ornate silver ring with a green emerald and leaf engravings",
  "sello_osty": "a round bronze seal medallion engraved with a violet spectral skeletal hand",
  "prisma_solar": "a radiant golden glass prism splitting sunlight into rainbow rays",
  "llave_maestra": "an ornate brass clockwork master key with gears",
  "concha_marea": "a pearlescent spiral seashell with glowing sea water inside",
  "ancla": "a rusty ship anchor wrapped in an old chain",
  "linterna": "an old bilge lantern glowing teal light",
  "vajra": "an ancient curved ceremonial dagger with a jeweled hilt",
  "canicas": "a small leather bag spilling glowing glass marbles",
  "piedra": "a smooth polished river stone with a faint glow",
  "orichalcum": "a bright orange-gold orichalcum metal ingot",
  "escamas": "bronze fish scales armor piece, shiny",
  "fresa": "a golden strawberry with a leafy top",
  "flor": "a cheerful glowing yellow daisy flower",
  "idolo_dorado": "a small golden idol statue",
  "tarjeta": "a gold embossed membership card with a seal",
  "cuerno": "a curved hunting horn with brass bands",
  "vela": "an eternal white candle with a blue flame",
  "resorte_reserva": "a coiled brass spring clockwork part",
  "lupa_relojero": "a watchmaker's brass loupe magnifier with tiny gears",
  "perla_negra": "a lustrous black pearl with purple highlights",
  "cuenco_marea": "a carved stone bowl full of swirling glowing water",
  "corazon_laton": "a mechanical heart made of brass gears and pipes",
  "cetro_maremoto": "a golden trident scepter wrapped in crashing waves",
  "nucleo": "a glowing energy core crystal sphere with lightning inside",
  "ojo": "a huge eye of the abyss with a dark iris, eldritch",
  "pozo": "a glowing pink heart-shaped crystal of life essence",
 },
 "potion": {
  "fuego": "a glass flask of swirling orange fire potion, cork stopper",
  "escudo": "a glass flask of shimmering blue potion with a shield shape of light",
  "fuerza": "a glass flask of red potion with a flexed arm silhouette glowing",
  "energia": "a glass flask of bright yellow crackling lightning potion",
  "curacion": "a glass flask of pink glowing healing potion with a heart",
  "veneno": "a glass vial of toxic green potion with a tiny skull",
  "niebla": "a glass flask of purple swirling mist potion",
  "rapidez": "a glass flask of cyan potion with wind swirls",
 },
 "node": {
  "combat": "two crossed swords with sparks",
  "elite": "a horned demonic skull with glowing eyes, fearsome",
  "event": "a mysterious glowing rune portal with a question mark shape",
  "shop": "a plump coin sack with gold coins spilling",
  "rest": "a warm campfire with glowing embers",
  "boss": "a dark royal crown with red jewels and thorns",
 },
 "orb": {
  "ola": "a glowing blue orb containing a rolling ocean wave",
  "bruma": "a pale grey-blue orb of drifting sea mist",
  "abismo": "a black orb of the deep abyss with violet swirls",
  "perla": "a luminous white pearl orb",
 },
 "intent": {
  "attack": "a bold bright sword pointing up, glowing red",
  "block": "a sturdy blue steel shield",
  "buff": "a bold red upward arrow with a glowing aura",
  "debuff": "a bold purple downward arrow with dark smoke",
  "curse": "a cursed playing card with a skull, dark purple",
  "heal": "a green glowing cross of healing",
  "summon": "a glowing summoning circle with runes and spirits",
  "unknown": "a glowing question mark rune",
 },
 "ui": {
  "hp": "a bright red glossy heart",
  "gold": "a shiny gold coin with an embossed crest",
  "deck": "a stack of fanned playing cards, ornate backs",
  "energy": "a bright golden lightning bolt in a circle",
  "menu": "an ornate scroll with a ribbon",
  "help": "an ornate book with a glowing question mark rune",
  "gear": "an ornate brass gear cog",
  "full": "four ornate arrows pointing outward to the corners, golden",
  "lock": "an ornate iron padlock",
  "music": "a golden musical note with glowing sound waves",
  "sound": "an ornate brass bell with sound waves",
  "hand": "a gloved hand pointing with the index finger, glowing",
  "speed": "a bold glowing lightning bolt with speed streaks",
  "discard": "a stack of face-down playing cards with a blue ornate back",
  "exhaust": "a playing card burning away to ash with violet flames",
  "anvil": "an iron blacksmith anvil with glowing sparks",
  "burn": "a playing card burning into ash with embers",
  "bed": "a cozy bedroll beside a small fire, restful",
  "target": "a glowing golden crosshair target reticle",
  "moon": "a crescent moon with purple glow, nightmare",
  "tent": "a small adventurer tent at night",
 },
 "status": {
  "strength": "a clenched armored fist glowing red", "dexterity": "a winged leather boot",
  "vulnerable": "a cracked steel shield breaking apart", "weak": "a wilted drooping flower",
  "frail": "a cracked glass shard", "poison": "a green poison droplet with a tiny skull",
  "thorns": "a thorny green vine", "tthorns": "flaming thorns burning orange",
  "tstr": "a red hourglass with a fist symbol", "metallicize": "a polished steel armor plate",
  "demon": "a pair of burning demon horns", "combust": "a white-hot glowing iron bar",
  "noxious": "a green toxic gas cloud", "accuracy": "a bullseye target with an arrow",
  "cuts": "many crossed daggers", "barricade": "a barricade of sharpened wooden stakes",
  "boneDance": "a dancing skeleton", "darkEmbrace": "two dark shadowy arms embracing",
  "ostyCleave": "a crowd of shadow soldiers", "glow": "a blinding sun glare lens flare",
  "heat": "a burning orange flame orb", "mirage": "an ornate hand mirror reflecting light",
  "reflect": "a mirrored silver shield reflecting beams", "prism": "a glowing blue crystal prism",
  "incand": "a sunrise over the horizon with rays", "noon": "a blazing sun at its zenith",
  "apoth": "a golden royal throne", "corona": "a crown made of fire",
  "cuerda": "a brass winding key", "resorte": "a coiled brass spring",
  "tictac": "an old clock face with gears", "precision": "a watchmaker's precision tool with gears",
  "perpetuum": "an infinity symbol made of gears", "maestro": "a master gear mechanism",
  "resonancia": "concentric blue sound wave ripples", "marea_alta": "a huge ocean wave under a full moon",
  "corriente": "a swirling underwater current", "bucle": "two circular arrows forming a loop",
  "perlera": "a string of luminous pearls", "ostyRegen": "a violet necromancy orb with a skeletal hand",
 },
}

def redo_soft(path):
    """Versión «luminosa»: fondo oscuro con viñeta (se recorta con una máscara radial suave en cut_icons.py --soft)."""
    out = ROOT / "gen" / "icons_soft"; out.mkdir(exist_ok=True)
    comfy.OUT = out
    for i, name in enumerate(l.strip() for l in open(path) if l.strip()):
        g, k = name.split("_", 1)
        wf = comfy.image_wf(STYLE.format(d=G[g][k]) + ", glowing energy effect", LORA, 320, 320, 9100 + i * 7, 0.8)
        comfy.wait(comfy.post(wf), name)


def redo(path):
    """Regenera (con fondo gris claro, más fácil de recortar) los iconos listados en el archivo: uno por línea, p. ej. status_heat."""
    names = [l.strip() for l in open(path) if l.strip()]
    for i, name in enumerate(names):
        g, k = name.split("_", 1)
        wf = comfy.image_wf(STYLE2.format(d=G[g][k]), LORA, 320, 320, 7000 + i * 13, 0.7)
        comfy.wait(comfy.post(wf), name)


def main():
    if sys.argv[1:2] == ["--soft"]:
        return redo_soft(sys.argv[2])
    if sys.argv[1:2] == ["--redo"]:
        return redo(sys.argv[2])
    groups = sys.argv[1:] or list(G.keys())
    jobs = []
    for g in groups:
        for k, d in G[g].items():
            if (OUT / f"{g}_{k}.webp").exists():
                continue
            jobs.append((f"{g}_{k}", d))
    print(len(jobs), "iconos por generar", flush=True)
    for name, d in jobs:
        wf = comfy.image_wf(STYLE.format(d=d), LORA, 320, 320, abs(hash(name)) % (2**31), 0.8)
        files = comfy.wait(comfy.post(wf), name)
        if files:
            im = Image.open(files[0]).convert("RGB").resize((192, 192), Image.LANCZOS)
            im.save(OUT / f"{name}.webp", quality=88)

if __name__ == "__main__":
    main()
