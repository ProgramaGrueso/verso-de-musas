"""Quita el fondo a los iconos (gen/icons_raw/*.png) y deja solo el objeto: recorta, centra y guarda assets/icons/*.webp con alfa.
Uso: uv run --python 3.12 --with "rembg[cpu]" --with pillow python tools/cut_icons.py [filtro]"""
import sys, pathlib
from PIL import Image, ImageFilter
from rembg import remove, new_session

ROOT = pathlib.Path(__file__).resolve().parent.parent
RAW = ROOT / "gen" / "icons_raw"
OUT = ROOT / "assets" / "icons"
SIZE = 192
sess = new_session("isnet-general-use")
filt = sys.argv[1] if len(sys.argv) > 1 and sys.argv[1] != "--soft" else ""
only = set(l.strip() for l in open(sys.argv[2])) if len(sys.argv) > 2 else None
for f in sorted(RAW.glob("*.png")) if "--soft" not in sys.argv else []:
    if filt and filt not in f.name:
        continue
    if only is not None and f.stem not in only:
        continue
    im = Image.open(f).convert("RGB")
    cut = remove(im, session=sess, alpha_matting=False)
    bbox = cut.getbbox()
    if not bbox:
        print("vacío", f.name); continue
    cut = cut.crop(bbox)
    w, h = cut.size
    s = (SIZE - 16) / max(w, h)
    cut = cut.resize((max(1, int(w * s)), max(1, int(h * s))), Image.LANCZOS)
    canvas = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    pos = ((SIZE - cut.width) // 2, (SIZE - cut.height) // 2)
    # halo suave claro detrás: los objetos oscuros se leen sobre fondos oscuros
    alpha = Image.new("L", (SIZE, SIZE), 0)
    alpha.paste(cut.getchannel("A"), pos)
    halo = alpha.filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(4)).point(lambda v: int(v * 0.5))
    glow = Image.new("RGBA", (SIZE, SIZE), (255, 236, 200, 0))
    glow.putalpha(halo)
    canvas = Image.alpha_composite(canvas, glow)
    canvas.alpha_composite(cut, pos)
    canvas.save(OUT / (f.stem + ".webp"), quality=92, method=6)
    print("ok", f.stem, flush=True)


def soft(names):
    """Iconos de efectos (fuego, niebla, olas...): se funde la imagen oscura en un óvalo difuso en vez de recortarla."""
    import math
    for n in names:
        f = ROOT / "gen" / "icons_soft" / (n + ".png")
        if not f.exists():
            continue
        im = Image.open(f).convert("RGB").resize((SIZE, SIZE), Image.LANCZOS)
        mask = Image.new("L", (SIZE, SIZE), 0)
        px = mask.load()
        c = (SIZE - 1) / 2
        for y in range(SIZE):
            for x in range(SIZE):
                r = math.hypot(x - c, y - c) / c
                a = 1.0 if r < 0.50 else max(0.0, 1.0 - (r - 0.50) / 0.42)
                px[x, y] = int(255 * a * a * (3 - 2 * a))
        out = im.convert("RGBA")
        out.putalpha(mask)
        out.save(OUT / (n + ".webp"), quality=92, method=6)
        print("soft", n, flush=True)

if len(sys.argv) > 1 and sys.argv[1] == "--soft":
    soft([l.strip() for l in open(sys.argv[2]) if l.strip()])
