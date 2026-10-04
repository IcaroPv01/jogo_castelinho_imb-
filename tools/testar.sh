#!/usr/bin/env bash
# Roda os testes automáticos headless. Uso: bash tools/testar.sh [binário_godot]
# Falha se algum teste falhar OU se aparecer "SCRIPT ERROR" na saída.
set -uo pipefail
GODOT="${1:-godot}"
cd "$(dirname "$0")/.."
status=0
for t in tests/*_test.gd; do
  echo "== $t"
  out=$(timeout 180 "$GODOT" --headless -s "res://$t" 2>&1)
  code=$?
  echo "$out" | grep -vE "^Godot Engine|^$"
  if [ $code -ne 0 ] || echo "$out" | grep -q "SCRIPT ERROR"; then
    echo "!! FALHOU: $t"; status=1
  fi
done
exit $status
