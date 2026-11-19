# Traspaso · Arte premium (oleada 3) · 2026-11-19, cortado por plazo 17:58

## Hecho
- Diagnóstico: el pipeline anterior (`gen/comfy.py`, `tools/gen_icons.py`) usa `moodyKrea2Mix...v70_fp8` + `krea2_darkbrush`, que **ya no existen** en ComfyUI. `rembg` (de `tools/cut_icons.py`) tampoco está disponible sin descargar modelos.
- Nuevo generador `tools/gen_art_w3.py`: Krea2 DaSiWa vía `krea2_lib` + recorte con **BiRefNet nativo** de ComfyUI (`LoadBackgroundRemovalModel`/`RemoveBackground`, sin descargas). Kinds: `frame` (aro dorado común), `node` (disco ilustrado + aro, 256 px RGBA), `medal` (384 px), `boss2` (Identity Edit sobre `assets/enemies/<id>.webp`, 520 px RGBA).
- `gen/jobs_art_w3.json`: aro + 7 medallones de nodo (combat, elite, boss, rest, shop, event, treasure) con prompts y semillas 73001 / 73100+i*11. Salida prevista `assets/icons/mapnode_<tipo>.webp`.
- Captura de referencia del mapa actual: `tests/drive.tscn -- mapview <dir> 1` (funciona).

## NO hecho (nada generado aún; el juego no se tocó)
1. Ejecutar: `python3 tools/gen_art_w3.py gen` y luego `build`; revisar `gen/art_w3_raw/frame_cut.png` (el agujero del aro se calcula por perfil radial; ajustar si falla) y `godot --headless --path . --import`.
2. Enchufar en `scripts/ui/screens/map_screen.gd` (`_add_node`, línea ~169): `var mt := Icons.tex("mapnode", n.type); b.icon = mt if mt != null else Icons.tex("node", n.type)` y subir `icon_max_width` a ~0.96*sz con stylebox de relleno transparente (el anillo de estado puede quedar). Leyenda (línea ~139) igual.
3. Medallas (máx 12): añadir jobs `medal` con `out` `assets/lore/ach_<id>.webp` y cambiar solo `"art"` en `data/progress.json` a `lore:ach_<id>` (`Progress.art_path` ya soporta `lore:`; la galería no lista archivos sueltos). Candidatas: primera_victoria, primer_jefe, voz_* (6), nm1, nm5, nm10, fiel. Tamaño de uso: 52-84 px en disco.
4. Fase 2 de jefes: jobs `boss2` con `ref` = crabking, drowncaptain, rootmother, mycelking, queen, waxcolossus → `assets/enemies/<id>_fase2.webp`; el enchufe natural es `enemy_view.gd` al recibir el fx `bossPhase` (archivo de otro agente: coordinar).
5. Verificar: `godot --headless --path . --script tests/run_traces.gd` (350 ok) y captura `mapview`.

ComfyUI quedó encendido en :8188 (no se apagó, lo usa otro agente).
