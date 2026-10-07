#!/usr/bin/env bash
# Instala o Godot 4.7.2 (editor Linux, para rodar os testes headless) numa sessão nova.
# Uso: bash tools/instalar_godot.sh          -> só o editor (basta para tools/testar.sh)
#      bash tools/instalar_godot.sh --web    -> também os templates Web (para tools/testar_web_cenas.sh)
# Mesmos arquivos e conferência SHA-512 do CI (.github/workflows/deploy-web.yml).
set -euo pipefail
VER="4.7.2"
BASE="https://github.com/godotengine/godot-builds/releases/download/${VER}-stable"
EDITOR_ZIP="Godot_v${VER}-stable_linux.x86_64.zip"
TPZ="Godot_v${VER}-stable_export_templates.tpz"
DEST="${GODOT_DIR:-/opt/godot}"   # GODOT_DIR muda o destino (útil para testar este script)
BIN="$DEST/Godot_v${VER}-stable_linux.x86_64"
TPL=~/.local/share/godot/export_templates/${VER}.stable

DL=$(mktemp -d)
trap 'rm -rf "$DL"' EXIT
cd "$DL"
curl -fsSL --retry 3 -O "$BASE/SHA512-SUMS.txt"

if [ ! -x "$BIN" ]; then
  curl -fsSL --retry 3 -O "$BASE/$EDITOR_ZIP"
  grep -E " ${EDITOR_ZIP}\$" SHA512-SUMS.txt | sha512sum -c -
  mkdir -p "$DEST"
  unzip -q -o "$EDITOR_ZIP" -d "$DEST"
  chmod +x "$BIN"
fi
ln -sf "$BIN" /usr/local/bin/godot

if [ "${1:-}" = "--web" ] && [ ! -f "$TPL/web_nothreads_release.zip" ]; then
  curl -fsSL --retry 3 -O "$BASE/$TPZ"
  grep -E " ${TPZ}\$" SHA512-SUMS.txt | sha512sum -c -
  unzip -q "$TPZ" 'templates/version.txt' 'templates/web_nothreads_*.zip' -d tpl
  mkdir -p "$TPL"
  mv tpl/templates/* "$TPL/"
fi

godot --version
