#!/usr/bin/env bash
# Exporta o jogo REAL (main_scene intacta) para Web, sobe um servidor estático com COOP/COEP e roda
# tools/testar_web_celular.js: Chromium com emulação de celular (844x390, toque), fotos em <saida> e
# erros do console em <saida>/console.txt. Não altera o projeto: trabalha numa cópia.
# Uso: bash tools/testar_web_celular.sh [binário_godot] [pasta_saida]
#      (PORTA_WEB muda a porta do servidor; padrão 8772)
set -euo pipefail
GODOT="${1:-godot}"
RAIZ="$(cd "$(dirname "$0")/.." && pwd)"
SAIDA="${2:-$RAIZ/build/teste_celular}"
PORTA="${PORTA_WEB:-8772}"
TMP="$(mktemp -d)"
SRV=""
trap '[ -n "$SRV" ] && kill "$SRV" 2>/dev/null || true; rm -rf "$TMP"' EXIT

mkdir -p "$TMP/proj"
(cd "$RAIZ" && git ls-files -co --exclude-standard | grep -v "^docs/" | tar -cf - -T -) | tar -xf - -C "$TMP/proj"
cd "$TMP/proj"
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
timeout 300 "$GODOT" --headless --import >/dev/null 2>&1 || true
mkdir -p "$TMP/web"
if ! timeout 600 "$GODOT" --headless --export-release Web "$TMP/web/index.html" >"$TMP/export.log" 2>&1 || [ ! -f "$TMP/web/index.html" ]; then
  echo "EXPORT WEB FALHOU. Fim do log:"
  tail -40 "$TMP/export.log"
  exit 1
fi
echo "export ok: $(ls "$TMP/web" | wc -l) arquivos em $TMP/web"

# servidor estático mínimo com os cabeçalhos que o Godot Web exige
python3 - "$TMP/web" "$PORTA" <<'PY' &
import sys, functools, http.server
pasta, porta = sys.argv[1], int(sys.argv[2])
class H(http.server.SimpleHTTPRequestHandler):
    def end_headers(self):
        self.send_header("Cross-Origin-Opener-Policy", "same-origin")
        self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
        self.send_header("Cache-Control", "no-store")
        super().end_headers()
    def log_message(self, *a):
        pass
http.server.ThreadingHTTPServer(("127.0.0.1", porta), functools.partial(H, directory=pasta)).serve_forever()
PY
SRV=$!
for _ in $(seq 1 50); do
  curl -sf -o /dev/null "http://localhost:$PORTA/index.html" && break
  sleep 0.2
done

mkdir -p "$SAIDA"
PORTA_WEB="$PORTA" node "$RAIZ/tools/testar_web_celular.js" "$TMP/web" "$SAIDA"
echo "saída em $SAIDA"
