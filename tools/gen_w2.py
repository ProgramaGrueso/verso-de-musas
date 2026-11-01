"""Genera con ComfyUI los 26 trabajos de gen/jobs_w2.json (9 enemigos + 17 fondos de evento) y los deja en su ruta final.
Enemigos: recorta el fondo con rembg y escala a 520 px de lado mayor (RGBA). Fondos: 1280x720 RGB.
Uso: uv run --python 3.12 --with "rembg[cpu]" --with pillow python tools/gen_w2.py [filtro]
Reanudable: se salta lo que ya existe en su ruta final."""
import sys, json, pathlib
from PIL import Image

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT / "gen"))
import comfy
RAW = ROOT / "gen" / "w2_raw"; RAW.mkdir(exist_ok=True)
comfy.OUT = RAW
jobs = json.load(open(ROOT / "gen" / "jobs_w2.json", encoding="utf-8"))
filt = sys.argv[1] if len(sys.argv) > 1 else ""
sess = None

def finish(j, raw):
    global sess
    out = ROOT / j["out"]; out.parent.mkdir(parents=True, exist_ok=True)
    im = Image.open(raw).convert("RGB")
    if j["name"].startswith("ev_"):
        im.resize((1280, 720), Image.LANCZOS).save(out, quality=88, method=6)
    else:
        from rembg import remove, new_session
        sess = sess or new_session("isnet-general-use")
        cut = remove(im, session=sess)
        cut = cut.crop(cut.getbbox())
        s = 520 / max(cut.size)
        cut.resize((max(1, round(cut.width * s)), max(1, round(cut.height * s))), Image.LANCZOS).save(out, quality=92, method=6)
    print("listo", j["out"], flush=True)

for j in jobs:
    if filt and filt not in j["name"]:
        continue
    if (ROOT / j["out"]).exists():
        continue
    raw = RAW / (j["name"] + ".png")
    if not raw.exists():
        wf = comfy.image_wf(j["prompt"], j["lora"], j["w"], j["h"], j["seed"], j.get("strength", 0.9))
        if not comfy.wait(comfy.post(wf), j["name"]):
            print("FALLÓ", j["name"]); continue
    finish(j, raw)
