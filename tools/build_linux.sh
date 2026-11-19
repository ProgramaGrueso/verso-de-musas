#!/bin/sh
# Build Linux de Verso de Musas (preset "Linux" de export_presets.cfg) en export/linux/.
# Uso: tools/build_linux.sh [release|debug]
# Sin plantillas linux_*.x86_64 de Godot 4.7.2 exporta solo el .pck (se ejecuta con
# `godot --main-pack export/linux/VersoDeMusas.pck`).
set -eu
cd "$(dirname "$0")/.."
MODE="${1:-release}"
OUT=export/linux
TPL="$HOME/.local/share/godot/export_templates/4.7.2.stable/linux_${MODE}.x86_64"
mkdir -p "$OUT"
godot --headless --path . --import >/dev/null 2>&1 || true
if [ -f "$TPL" ]; then
	godot --headless --path . "--export-$MODE" "Linux" "$OUT/VersoDeMusas.x86_64"
	test -x "$OUT/VersoDeMusas.x86_64"
else
	echo "AVISO: falta $TPL; exporto solo el .pck" >&2
	godot --headless --path . --export-pack "Linux" "$OUT/VersoDeMusas.pck"
fi
test -s "$OUT/VersoDeMusas.pck"
# humo: arranca el paquete exportado sin ventana y falla si hay SCRIPT ERROR
LOG=$(mktemp)
XDG_DATA_HOME=$(mktemp -d) timeout 120 godot --headless --main-pack "$OUT/VersoDeMusas.pck" --quit-after 600 >"$LOG" 2>&1 || true
if grep -q "SCRIPT ERROR" "$LOG"; then cat "$LOG"; exit 1; fi
echo "OK: $OUT"
ls -la "$OUT"
