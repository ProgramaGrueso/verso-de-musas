#!/bin/sh
# Lanza Verso de Musas (Godot). Con --editor abre el editor.
cd "$(dirname "$0")"
if [ "$1" = "--editor" ]; then exec godot --editor --path .; fi
exec godot --path . "$@"
