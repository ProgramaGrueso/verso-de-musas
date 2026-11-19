"""Arte premium (oleada 3): medallones de nodos del mapa, medallones de logros y retratos de fase 2 de jefes.
Trabajos en gen/jobs_art_w3.json. Krea2 local (DaSiWa, el moody+darkbrush de las oleadas 1-2 ya no existe)
y recorte con el BiRefNet nativo de ComfyUI (sin rembg).
Uso:  python3 tools/gen_art_w3.py gen   [filtro]   # genera lo que falte en gen/art_w3_raw/ (reanudable)
      python3 tools/gen_art_w3.py build [filtro]   # deja los PNG/WebP finales en assets/
Kinds: frame (aro dorado común) · node (ilustración circular + aro, 256 px RGBA) · medal (arte cuadrado 384 px)
       · boss2 (sprite recortado 520 px, Identity Edit sobre assets/enemies/<id>.webp)."""
import sys, json, math, pathlib, time, urllib.request, urllib.parse, shutil
from PIL import Image, ImageFilter, ImageDraw, ImageChops
import numpy as np

ROOT = pathlib.Path(__file__).resolve().parent.parent
sys.path.insert(0, "/mnt/Datos/VideoMusical/shared/lib")
import krea2_lib as k2

HOST = "http://127.0.0.1:8188"
RAW = ROOT / "gen" / "art_w3_raw"; RAW.mkdir(parents=True, exist_ok=True)
COMFY_INPUT = pathlib.Path("/home/juang/ComfyUI/input")
JOBS = json.load(open(ROOT / "gen" / "jobs_art_w3.json", encoding="utf-8"))
NODE_PX = 256


def with_cutout(wf, img_node):
    """Añade BiRefNet: guarda la máscara como imagen aparte (prefijo _mask)."""
    pre = wf[[k for k in wf if wf[k]["class_type"] == "SaveImage"][0]]["inputs"]["filename_prefix"]
    wf["bgm"] = {"class_type": "LoadBackgroundRemovalModel", "inputs": {"bg_removal_name": "birefnet.safetensors"}}
    wf["bgr"] = {"class_type": "RemoveBackground", "inputs": {"bg_removal_model": ["bgm", 0], "image": img_node}}
    wf["m2i"] = {"class_type": "MaskToImage", "inputs": {"mask": ["bgr", 0]}}
    wf["msave"] = {"class_type": "SaveImage", "inputs": {"filename_prefix": pre + "_mask", "images": ["m2i", 0]}}
    return wf


def run(wf, name):
    data = json.dumps({"prompt": wf}).encode()
    pid = json.load(urllib.request.urlopen(urllib.request.Request(HOST + "/prompt", data, {"Content-Type": "application/json"})))["prompt_id"]
    while True:
        h = json.load(urllib.request.urlopen(f"{HOST}/history/{pid}"))
        if pid in h:
            break
        time.sleep(2)
    st = h[pid].get("status", {})
    if st.get("status_str") == "error":
        print("ERROR", name, json.dumps(st)[:600], flush=True)
        return False
    for o in h[pid]["outputs"].values():
        for f in o.get("images", []):
            q = urllib.parse.urlencode({"filename": f["filename"], "subfolder": f["subfolder"], "type": f["type"]})
            dst = RAW / (name + ("_mask" if "_mask" in f["filename"] else "") + ".png")
            dst.write_bytes(urllib.request.urlopen(f"{HOST}/view?{q}").read())
    print("OK", name, flush=True)
    return True


def gen(filt):
    for j in JOBS:
        if filt and filt not in j["name"]:
            continue
        if (RAW / (j["name"] + ".png")).exists():
            continue
        pre = "VersoDeMusas/w3_" + j["name"]
        if j["kind"] == "boss2":
            src = ROOT / "assets" / "enemies" / (j["ref"] + ".webp")
            ref = "versodemusas_ref_" + j["ref"] + ".png"
            im = Image.open(src).convert("RGBA")
            bg = Image.new("RGBA", (768, 768), (18, 14, 26, 255))
            s = 640 / max(im.size)
            im = im.resize((round(im.width * s), round(im.height * s)), Image.LANCZOS)
            bg.alpha_composite(im, ((768 - im.width) // 2, (768 - im.height) // 2))
            bg.convert("RGB").save(COMFY_INPUT / ref)
            wf = k2.edit_wf(j["prompt"], ref, None, j["seed"], pre, size=(j["w"], j["h"]))
            wf = with_cutout(wf, ["dec", 0])
        else:
            wf = k2.t2i_wf(j["prompt"], j["seed"], pre, size=(j["w"], j["h"]))
            if j.get("cut"):
                wf = with_cutout(wf, ["610", 0])
        run(wf, j["name"])


# ---------- acabado ----------
def rgba(name):
    im = Image.open(RAW / (name + ".png")).convert("RGB")
    m = Image.open(RAW / (name + "_mask.png")).convert("L").resize(im.size, Image.LANCZOS)
    im = im.convert("RGBA"); im.putalpha(m)
    return im


def ring_frame():
    """Aro dorado común: recorte BiRefNet + agujero circular calculado del perfil radial."""
    fr = rgba("frame")
    bb = fr.getchannel("A").point(lambda v: 255 if v > 40 else 0).getbbox()
    fr = fr.crop(bb)
    side = max(fr.size)
    sq = Image.new("RGBA", (side, side), (0, 0, 0, 0)); sq.alpha_composite(fr, ((side - fr.width) // 2, (side - fr.height) // 2))
    sq = sq.resize((NODE_PX, NODE_PX), Image.LANCZOS)
    a = np.asarray(sq.getchannel("A")).astype(float) / 255.0
    c = (NODE_PX - 1) / 2
    yy, xx = np.mgrid[0:NODE_PX, 0:NODE_PX]
    rr = np.hypot(xx - c, yy - c)
    # radio interior: primer radio (desde el centro) donde el aro es mayormente opaco
    inner = None
    for r in range(10, NODE_PX // 2):
        band = (rr >= r) & (rr < r + 1)
        if a[band].mean() > 0.85:
            inner = r; break
    inner = inner or int(NODE_PX * 0.38)
    hole = np.clip((rr - (inner - 1.5)) / 3.0, 0, 1)   # borde suave
    a2 = a * hole
    sq.putalpha(Image.fromarray((a2 * 255).astype(np.uint8)))
    return sq, inner


def build_node(j, frame, inner):
    im = Image.open(RAW / (j["name"] + ".png")).convert("RGB")
    side = min(im.size)
    im = im.crop(((im.width - side) // 2, (im.height - side) // 2, (im.width + side) // 2, (im.height + side) // 2))
    d = 2 * (inner + 3)
    zoom = j.get("zoom", 1.0)
    big = round(d * zoom)
    im = im.resize((big, big), Image.LANCZOS).crop(((big - d) // 2, (big - d) // 2, (big - d) // 2 + d, (big - d) // 2 + d))
    mask = Image.new("L", (d * 4, d * 4), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, d * 4 - 1, d * 4 - 1), fill=255)
    mask = mask.resize((d, d), Image.LANCZOS)
    # viñeta interior: el borde del disco se oscurece hacia el aro
    vig = Image.radial_gradient("L").resize((d, d))
    vig = vig.point(lambda v: 255 - int(max(0, v - 150) * 1.4))
    im = ImageChops.multiply(im, Image.merge("RGB", (vig, vig, vig)))
    out = Image.new("RGBA", (NODE_PX, NODE_PX), (0, 0, 0, 0))
    disc = im.convert("RGBA"); disc.putalpha(mask)
    out.alpha_composite(disc, ((NODE_PX - d) // 2, (NODE_PX - d) // 2))
    out.alpha_composite(frame)
    dst = ROOT / j["out"]; dst.parent.mkdir(parents=True, exist_ok=True)
    out.save(dst, quality=92, method=6)
    print("node", dst.relative_to(ROOT), flush=True)


def build_medal(j):
    im = Image.open(RAW / (j["name"] + ".png")).convert("RGB")
    side = min(im.size)
    im = im.crop(((im.width - side) // 2, (im.height - side) // 2, (im.width + side) // 2, (im.height + side) // 2))
    dst = ROOT / j["out"]
    im.resize((384, 384), Image.LANCZOS).save(dst, quality=90, method=6)
    print("medal", dst.relative_to(ROOT), flush=True)


def build_boss2(j):
    im = rgba(j["name"])
    im = im.crop(im.getchannel("A").point(lambda v: 255 if v > 24 else 0).getbbox())
    s = 520 / max(im.size)
    dst = ROOT / j["out"]
    im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS).save(dst, quality=92, method=6)
    print("boss2", dst.relative_to(ROOT), flush=True)


def build(filt):
    frame, inner = ring_frame() if (RAW / "frame.png").exists() else (None, 0)
    if frame is not None:
        frame.save(RAW / "frame_cut.png")
    for j in JOBS:
        if filt and filt not in j["name"]:
            continue
        if not (RAW / (j["name"] + ".png")).exists() or j["kind"] == "frame":
            continue
        {"node": lambda: build_node(j, frame, inner), "medal": lambda: build_medal(j), "boss2": lambda: build_boss2(j)}[j["kind"]]()


if __name__ == "__main__":
    cmd = sys.argv[1] if len(sys.argv) > 1 else "gen"
    f = sys.argv[2] if len(sys.argv) > 2 else ""
    gen(f) if cmd == "gen" else build(f)
