"""Abre o build web num Chromium headless, clica para começar, anda e tira capturas de tela.

Uso: python3 tools/testar_web.py [pasta_build] [pasta_saida] [segundos_andando]
Mostra no terminal os erros do console do navegador (erros de script do Godot aparecem lá).
"""
import functools, glob, http.server, os, sys, threading, time
from playwright.sync_api import sync_playwright

build = sys.argv[1] if len(sys.argv) > 1 else "build/web"
saida = sys.argv[2] if len(sys.argv) > 2 else "build/capturas"
andar = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
os.makedirs(saida, exist_ok=True)

class Quieto(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


handler = functools.partial(Quieto, directory=build)
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 8765), handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()

exe = (glob.glob("/opt/pw-browsers/chromium-*/chrome-linux*/chrome") or [None])[0]
erros, logs = [], []
with sync_playwright() as p:
    nav = p.chromium.launch(executable_path=exe, args=[
        "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    pg = nav.new_page(viewport={"width": 1280, "height": 720})
    pg.on("console", lambda m: (erros if m.type == "error" else logs).append(m.text))
    pg.on("pageerror", lambda e: erros.append(str(e)))
    pg.goto("http://127.0.0.1:8765/index.html")
    try:
        pg.wait_for_function("!document.getElementById('status')", timeout=120000)
    except Exception:
        print("AVISO: tela de carregamento não sumiu"); print("ERROS:", *erros, sep="\n  ")
    time.sleep(2)
    pg.screenshot(path=f"{saida}/01_titulo.png")
    pg.mouse.click(640, 360)
    time.sleep(3)
    pg.screenshot(path=f"{saida}/02_inicio.png")
    pg.keyboard.down("w"); time.sleep(andar); pg.keyboard.up("w")
    time.sleep(0.5)
    pg.screenshot(path=f"{saida}/03_andou.png")
    pg.mouse.move(800, 360, steps=10)
    time.sleep(1)
    pg.screenshot(path=f"{saida}/04_olhou.png")
    nav.close()
srv.shutdown()
print("LOGS:", *logs[-15:], sep="\n  ")
print("ERROS:", *erros[-20:], sep="\n  ")
