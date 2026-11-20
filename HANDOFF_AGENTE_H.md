# Agente H: retratos propios de los 3 élites nuevos

Generados con Krea2 local (t2i + BiRefNet) usando el `ap` de `data/enemies_extra.json`, 520 px lado mayor, RGBA, WebP q92
(mismo formato que los demás sprites). Ya sustituyen a las copias en la MISMA ruta, así que el juego no necesita cambios de referencia:

| Élite | Archivo | Antes (copia de) | Semilla |
|---|---|---|---|
| spectralbosun | assets/enemies/spectralbosun.webp | ghostpirate | 91001 |
| rootwarden | assets/enemies/rootwarden.webp | dryad | 91001 |
| royalbeetle | assets/enemies/royalbeetle.webp | beetle | 91002 |

Pendiente (archivos de otro agente, no tocados):
- `tools/make_content_w2.py` línea 130: `ART_COPIES = {"spectralbosun": "ghostpirate", "rootwarden": "dryad", "royalbeetle": "beetle"}`
  Es solo una lista de "no crear trabajo de generación" (no copia archivos). Cambiarla a `ART_COPIES = {}` haría que el script
  vuelva a crear jobs `enemy_<id>` y los regenere con rembg/semillas distintas: mejor dejarla o, si se quiere reflejar la realidad,
  cambiar el comentario de la línea 129 a "arte propio generado con Krea2 (HANDOFF_AGENTE_H.md); no regenerar".
- Reimportar en Godot: `godot --headless --path . --import` (los .webp.import ya existen).
- Quitar el punto 8 de HANDOFF.md ("retratos de los 3 élites nuevos").
Crudos (1024 px + máscara): scratchpad de la sesión, no versionados.
