#!/usr/bin/env bash
# Recorta NotoColorEmoji.ttf a los glifos que usa el juego (11 MB -> ~300 KB).
# Uso: tools/subset_emoji.sh /ruta/a/NotoColorEmoji_completa.ttf   (se ejecuta desde la carpeta del proyecto)
set -euo pipefail
src=${1:?ruta a la fuente completa}
codes=$(python3 -I - <<'P'
import glob
s={0xFE0F,0x200D}
for p in glob.glob('scripts/**/*.gd',recursive=True)+glob.glob('data/*.json'):
    for ch in open(p,encoding='utf8',errors='ignore').read():
        o=ord(ch)
        if o>0x2000 and not (0x2500<=o<=0x257f): s.add(o)
print(' '.join('U+%04X'%o for o in sorted(s)))
P
)
pyftsubset "$src" --unicodes="${codes// /,}" --output-file=assets/fonts/NotoColorEmoji.ttf --layout-features='*'
