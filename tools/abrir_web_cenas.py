"""Abre o build de teste de cenas (tools/testar_web_cenas.sh) no Chromium e espera FIM_WEB_CENAS. Sai com 1 se houver erro."""
import functools, glob, http.server, sys, threading, time
from playwright.sync_api import sync_playwright

pasta = sys.argv[1]
class Q(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 8771), functools.partial(Q, directory=pasta))
threading.Thread(target=srv.serve_forever, daemon=True).start()
exe = (glob.glob("/opt/pw-browsers/chromium-*/chrome-linux*/chrome") or [None])[0]
logs, erros = [], []
with sync_playwright() as p:
    nav = p.chromium.launch(executable_path=exe, args=["--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    pg = nav.new_page(viewport={"width": 1280, "height": 720})
    pg.on("console", lambda m: (erros if m.type == "error" else logs).append(m.text))
    pg.on("pageerror", lambda e: erros.append(str(e)))
    pg.goto("http://127.0.0.1:8771/index.html")
    t0 = time.time()
    while time.time() - t0 < 900 and not any("FIM_WEB_CENAS" in l for l in logs):
        time.sleep(2)
    nav.close()
srv.shutdown()
for l in logs:
    if l.startswith("CENA_") or "FIM_WEB" in l or "SCRIPT ERROR" in l or "shader" in l.lower():
        print(l)
print("ERROS:", *erros, sep="\n  ")
ok = any("FIM_WEB_CENAS" in l for l in logs) and not erros
print("RESULTADO WEB:", "OK" if ok else "FALHA")
sys.exit(0 if ok else 1)
