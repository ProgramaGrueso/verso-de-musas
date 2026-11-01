"""Genera con ComfyUI las ilustraciones de los capítulos de lore nuevos (jefes de la oleada 2) a 1280x720.
Uso: python3 tools/gen_lore_w2.py   (ComfyUI en 127.0.0.1:8188). Se salta las que ya existen."""
import sys, json, pathlib
from PIL import Image
ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "gen"))
import comfy
RAW = ROOT / "gen" / "w2_raw"; RAW.mkdir(exist_ok=True)
comfy.OUT = RAW
lore = json.load(open(ROOT / "data" / "lore.json", encoding="utf-8"))["lore"]
for i, l in enumerate(x for x in lore if x["id"] in ("capitana", "micelio", "cera")):
    out = ROOT / "assets" / "lore" / (l["id"] + ".webp")
    if out.exists():
        continue
    wf = comfy.image_wf(l["ap"] + ", wide cinematic composition, painterly digital illustration, no text", "karen_krea2.safetensors", 1280, 720, 53000 + i * 11, 0)
    files = comfy.wait(comfy.post(wf), "lore_" + l["id"])
    if files:
        Image.open(files[0]).convert("RGB").resize((1280, 720), Image.LANCZOS).save(out, quality=88, method=6)
        print("listo", out.name, flush=True)
