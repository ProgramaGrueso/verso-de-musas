# HANDOFF Build Linux (Fase 5) · 2026-11-19

## Hecho
- `export_presets.cfg`: añadido `[preset.2]` "Linux" (x86_64, pck aparte, mismo exclude_filter). Windows y Web intactos.
- `export/linux/VersoDeMusas.pck` (515 MB) exportado con `--export-pack "Linux"`.
- Humo: `godot --headless --main-pack export/linux/VersoDeMusas.pck --quit-after 600` → rc 0, sin SCRIPT ERROR
  (solo el aviso conocido "2 resources still in use at exit").
- `tools/build_linux.sh [release|debug]`: exporta binario si hay plantilla, si no solo el .pck, y hace el humo. Sin probar de punta a punta (corte de plazo).

## Pendiente
- **Faltan plantillas Linux** de Godot 4.7.2 (`~/.local/share/godot/export_templates/4.7.2.stable/` solo tiene windows y web).
  Hace falta el `.tpz` oficial (~1 GB): decisión de Juan. Sin ellas no hay `VersoDeMusas.x86_64` distribuible.
- Prueba en ventana corta del build: no hecha.
- Soak de 50 partidas: no hecho. Comando (playthrough ya acepta nº de partidas):
  `XDG_DATA_HOME=/tmp/vdm_soak godot --headless --path . res://tests/playthrough.tscn -- zafiro 50 20 2>&1 | tee soak.log; grep -c "SCRIPT ERROR" soak.log`
  y rápido por motor: `godot --headless --path . --script tests/balance.gd -- 50 0`.
- Casillas de Fase 5 en ROADMAP.md: sin marcar (nada completo).
