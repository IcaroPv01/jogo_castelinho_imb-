#!/usr/bin/env bash
# Testes que precisam de janela (mouse capturado, pausa com Esc, clique nos botões): rodam sob xvfb-run.
# Uso: bash tools/testar_janela.sh [binário_godot]
# São mais lentos que tools/testar.sh (renderização por software) e por isso ficam separados dele.
set -uo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
status=0
for t in tests/janela_*.gd; do
  echo "== $t"
  out=$(timeout 600 xvfb-run -a -s "-screen 0 1280x720x24" "$GODOT" --rendering-driver opengl3 -s "res://$t" 2>&1)
  code=$?
  echo "$out" | grep -vE "^Godot Engine|^$|^WARNING|^ERROR: Condition|ALSA|audio_driver|^OpenGL API|^\s+at: "
  if [ $code -ne 0 ] || echo "$out" | grep -q "SCRIPT ERROR"; then
    echo "!! FALHOU: $t"; status=1
  fi
done
exit $status
