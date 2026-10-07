#!/usr/bin/env bash
# Exporta um build Web de TESTE cuja cena principal é tests/web_cenas.tscn e o abre no Chromium (WebGL2 por software),
# coletando erros do console (ex.: shader que não compila no WebGL). Não altera o projeto: trabalha numa cópia.
# Uso: bash tools/testar_web_cenas.sh [binário_godot]
set -euo pipefail
GODOT="${1:-godot}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
mkdir -p "$TMP/proj"
(cd "$RAIZ" && git ls-files -co --exclude-standard | grep -v "^docs/" | tar -cf - -T -) | tar -xf - -C "$TMP/proj"
cd "$TMP/proj"
sed -i 's#^run/main_scene=.*#run/main_scene="res://tests/web_cenas.tscn"#' project.godot
sed -i 's#exclude_filter="docs/\*, tools/\*, tests/\*, build/\*"#exclude_filter="docs/*, tools/*, build/*"#' export_presets.cfg
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
mkdir -p "$TMP/web"
timeout 600 "$GODOT" --headless --export-release Web "$TMP/web/index.html" >/dev/null 2>&1
python3 "$RAIZ/tools/abrir_web_cenas.py" "$TMP/web"
