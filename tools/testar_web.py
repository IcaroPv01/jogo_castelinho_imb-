"""Abre o build web num Chromium, CLICA em "Começar a visita", mede o tempo até o jogo começar, anda e tira capturas.

Uso: python3 tools/testar_web.py [pasta_build] [pasta_saida] [segundos_andando]
     HEADFUL=1 xvfb-run -a -s "-screen 0 1400x900x24" python3 tools/testar_web.py     (janela de verdade: testa o pointer lock)
     MODO=enter python3 tools/testar_web.py                                           (começa com Enter em vez do clique)

Mostra no terminal os erros do console do navegador (erros de script do Godot aparecem lá) e:
  - se a tela "Carregando..." apareceu depois do clique (capturas 02a_carregando.png);
  - quanto tempo levou do clique até a linha "[carga] ... pronto em N ms" do jogo (com renderização por SOFTWARE, SwiftShader,
    isso é bem mais lento do que numa placa de vídeo; use para comparar versões, não como valor absoluto).
"""
import functools, glob, http.server, os, sys, threading, time
from playwright.sync_api import sync_playwright

build = sys.argv[1] if len(sys.argv) > 1 else "build/web"
saida = sys.argv[2] if len(sys.argv) > 2 else "build/capturas"
andar = float(sys.argv[3]) if len(sys.argv) > 3 else 3.0
modo = os.environ.get("MODO", "clique")
headful = os.environ.get("HEADFUL") == "1"
os.makedirs(saida, exist_ok=True)

class Quieto(http.server.SimpleHTTPRequestHandler):
    def log_message(self, *a):
        pass


handler = functools.partial(Quieto, directory=build)
srv = http.server.ThreadingHTTPServer(("127.0.0.1", 8765), handler)
threading.Thread(target=srv.serve_forever, daemon=True).start()

exe = (glob.glob("/opt/pw-browsers/chromium-*/chrome-linux*/chrome") or [None])[0]
erros, logs = [], []
t_clique = None
with sync_playwright() as p:
    nav = p.chromium.launch(executable_path=exe, headless=not headful, args=[
        "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--ignore-gpu-blocklist"])
    pg = nav.new_page(viewport={"width": 1280, "height": 720})
    pg.on("console", lambda m: (erros if m.type == "error" else logs).append((time.time(), m.text)))
    pg.on("pageerror", lambda e: erros.append((time.time(), str(e))))
    pg.goto("http://127.0.0.1:8765/index.html")
    try:
        pg.wait_for_function("!document.getElementById('status')", timeout=120000)
    except Exception:
        print("AVISO: tela de carregamento não sumiu"); print("ERROS:", *[e[1] for e in erros], sep="\n  ")
    time.sleep(2)
    pg.screenshot(path=f"{saida}/01_titulo.png")
    t_clique = time.time()
    if modo == "enter":
        pg.keyboard.press("Enter")           # sem save, Enter começa; com save, continua
    else:
        pg.mouse.click(985, 590)             # botão "Começar a visita" (sem save)
    time.sleep(1.5)
    pg.screenshot(path=f"{saida}/02a_carregando.png")
    pronto = None
    while time.time() - t_clique < 120:
        achou = [t for t, m in logs if "[carga]" in m]
        if achou:
            pronto = achou[0]
            break
        time.sleep(0.5)
    time.sleep(2)
    pg.screenshot(path=f"{saida}/02_inicio.png")
    lock = pg.evaluate("!!document.pointerLockElement")
    pg.keyboard.down("w"); time.sleep(andar); pg.keyboard.up("w")
    time.sleep(0.5)
    pg.screenshot(path=f"{saida}/03_andou.png")
    pg.mouse.move(800, 360, steps=10)
    time.sleep(1)
    pg.screenshot(path=f"{saida}/04_olhou.png")
    nav.close()
srv.shutdown()
print("clique -> jogo pronto: %s" % ("%.1f s" % (pronto - t_clique) if pronto else "NÃO CHEGOU em 120 s"))
print("pointer lock ativo depois do clique:", lock, "(só vale com HEADFUL=1)")
print("LOGS:", *[m for _, m in logs[-15:]], sep="\n  ")
print("ERROS:", *[m for _, m in erros[-20:]], sep="\n  ")
