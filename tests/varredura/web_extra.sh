#!/usr/bin/env bash
# Cópia de tools/testar_web_cenas.sh que roda tests/varredura/web_extra.tscn (shaders não cobertos pela suíte base).
# Diferenças: a raiz é ../.. (este arquivo fica em tests/varredura) e a cópia do projeto não usa git (find/tar).
# Variável RUNNER: caminho de um .js/.py que abre o build (padrão: tools/abrir_web_cenas.py).
# Uso: bash tests/varredura/web_extra.sh [binário_godot]
set -euo pipefail
GODOT="${1:-godot}"
RAIZ="$(cd "$(dirname "$0")/../.." && pwd)"
TMP="$(mktemp -d)"
mkdir -p "$TMP/proj"
(cd "$RAIZ" && find . -type f -not -path "./.git/*" -not -path "./.godot/*" -not -path "./docs/*" -not -path "./build/*" -not -path "./docs/pesquisa/refs/*" -print0 | tar --null -cf - -T -) | tar -xf - -C "$TMP/proj"
cd "$TMP/proj"
sed -i 's#^run/main_scene=.*#run/main_scene="res://tests/varredura/web_extra.tscn"#' project.godot
sed -i 's#exclude_filter="docs/\*, tools/\*, tests/\*, build/\*"#exclude_filter="docs/*, tools/*, build/*"#' export_presets.cfg
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
mkdir -p "$TMP/web"
timeout 600 "$GODOT" --headless --export-release Web "$TMP/web/index.html" >/dev/null 2>&1
echo "build em $TMP/web"
if [ -n "${RUNNER:-}" ]; then
  case "$RUNNER" in
    *.js) node "$RUNNER" "$TMP/web" 8772 900 ;;
    *)    python3 "$RUNNER" "$TMP/web" ;;
  esac
else
  python3 "$RAIZ/tools/abrir_web_cenas.py" "$TMP/web"
fi
