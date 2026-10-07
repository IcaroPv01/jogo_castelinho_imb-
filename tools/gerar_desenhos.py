#!/usr/bin/env python3
"""Gera, por código, a arte "de papel" da história do Tito (V2_ROTEIRO §1 e §5). Tudo é ficção.

Uso:  python3 tools/gerar_desenhos.py                 # gera tudo em assets/ui/tito/
      python3 tools/gerar_desenhos.py desenho_3 procura_se   # só alguns

Saídas (assets/ui/tito/):
  desenho_1.png .. desenho_7.png   giz de cera de uma criança de 9 anos, 512x512 (V2 §5)
  procura_se.png                   cartaz de 1967 "PROCURA-SE", 512x720
  marcas_altura.png                batente de porta com riscos de lápis, 384x512

O estilo "giz de cera" vem de um motor pequeno (classe Folha): cada cor é uma camada de máscara; o traço é uma
polilinha com tremor suave e retomadas que passam do ponto; o preenchimento é rabisco em zigue-zague; a máscara
passa por um "dente de papel" (ruído) que deixa o papel aparecer pelo traço, como cera de verdade.
As crianças que sofrem violência não aparecem em lugar nenhum: os desenhos só SUGEREM (castelo, água, escuro, olhos).

Requisitos: numpy e Pillow. Determinístico (semente fixa por arquivo).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFilter, ImageFont

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SAIDA = os.path.join(RAIZ, "assets", "ui", "tito")
FONTES = os.path.join(RAIZ, "assets", "fonts")
SS = 2  # supersampling: desenha em 2x e reduz (borda macia)

# Paleta de giz de cera (cores primárias e secundárias, meio gastas)
VERMELHO = (214, 40, 36)
AZUL = (36, 84, 200)
AZUL_CLARO = (96, 160, 235)
AMARELO = (250, 205, 30)
VERDE = (50, 150, 60)
LARANJA = (240, 130, 30)
MARROM = (120, 72, 38)
PRETO = (28, 26, 30)
CINZA = (120, 122, 128)
CINZA_ESC = (70, 72, 80)
ROSA = (236, 120, 160)
BRANCO = (255, 255, 252)
ROXO = (86, 52, 140)


# ------------------------------------------------------------------ utilidades
def suave(rng, n, janela):
    """Ruído 1D suave (passeio aleatório filtrado), média ~0, amplitude ~1."""
    if n <= 1:
        return np.zeros(max(n, 1))
    janela = max(1, int(janela))
    x = rng.normal(size=n + 2 * janela)
    k = np.ones(janela) / janela
    x = np.convolve(x, k, mode="same")
    x = x[janela:janela + n]
    s = x.std()
    return (x - x.mean()) / (s if s > 1e-6 else 1.0)


def ruido_2d(rng, w, h, escala):
    """Ruído 2D por interpolação de uma grade pequena (0..1)."""
    gw, gh = max(2, int(w / escala) + 2), max(2, int(h / escala) + 2)
    g = rng.random((gh, gw)).astype(np.float32)
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((w, h), Image.BICUBIC)
    return np.asarray(img, dtype=np.float32) / 255.0


def fractal(rng, w, h, escalas=(64, 24, 8, 3, 1), pesos=(0.3, 0.25, 0.2, 0.15, 0.1)):
    r = np.zeros((h, w), dtype=np.float32)
    for e, p in zip(escalas, pesos):
        r += p * ruido_2d(rng, w, h, e)
    return r / sum(pesos)


def fonte(nome, tam, peso=None):
    caminho = os.path.join(FONTES, nome)
    f = ImageFont.truetype(caminho, tam)
    if peso is not None:
        try:
            f.set_variation_by_axes([peso])
        except Exception:
            pass
    return f


def fonte_sistema(candidatos, tam, padrao=("Arimo-Latin.ttf", 700)):
    for c in candidatos:
        try:
            return ImageFont.truetype(c, tam)
        except Exception:
            continue
    return fonte(padrao[0], tam, padrao[1])


# ------------------------------------------------------------------ o motor "giz de cera"
class Folha:
    """Uma folha de papel desenhada em camadas de cor. Coordenadas na escala final (w x h)."""

    def __init__(self, w, h, rng, papel=(250, 244, 226), amarelar=0.0, dureza=0.5):
        self.w, self.h, self.rng = w, h, rng
        self.ss = SS
        W, H = w * SS, h * SS
        self.W, self.H = W, H
        self.dureza = dureza
        # dente do papel: ruído fino e "fibras" mais grossas; o giz só pega nos picos
        self.dente = np.clip(0.55 * fractal(rng, W, H, (14, 5, 2, 1), (0.1, 0.25, 0.35, 0.3)) +
                             0.45 * ruido_2d(rng, W, H, 1.2), 0, 1)
        base = np.array(papel, dtype=np.float32)
        tex = fractal(rng, W, H, (120, 40, 10, 2), (0.3, 0.3, 0.2, 0.2))
        tela = base[None, None, :] * (0.955 + 0.07 * tex[..., None])
        # bordas mais escuras/amareladas
        yy, xx = np.mgrid[0:H, 0:W].astype(np.float32)
        d = np.minimum(np.minimum(xx, W - xx), np.minimum(yy, H - yy)) / (0.12 * W)
        borda = 1 - np.clip(d, 0, 1)
        tela = tela * (1 - 0.06 * borda[..., None]) - np.array([0, 4, 14], dtype=np.float32) * borda[..., None] * (0.4 + amarelar)
        tela = tela - np.array([0, 5, 18], dtype=np.float32) * amarelar
        self.tela = tela
        self._cor = None
        self._m = None
        self._d = None

    # --- camadas de cor
    def cor(self, rgb, op=0.93):
        self.fechar()
        self._cor = np.array(rgb, dtype=np.float32)
        self._op = op
        self._m = Image.new("L", (self.W, self.H), 0)
        self._d = ImageDraw.Draw(self._m)
        return self

    def fechar(self):
        if self._m is None:
            return
        m = self._m.filter(ImageFilter.GaussianBlur(0.9 * self.ss))
        m = np.asarray(m, dtype=np.float32) / 255.0
        # cera: onde o papel tem "dente" alto o giz falha; traço grosso (m=1) ainda deixa falhas
        a = np.clip(m * 1.35 - self.dente * self.dureza * 1.1, 0, 1) ** 0.85
        # variação de pressão/tom
        var = ruido_2d(self.rng, self.W, self.H, 18)
        col = self._cor[None, None, :] * (0.88 + 0.2 * var[..., None])
        # onde o giz é denso, o tom fica um pouco mais escuro (camadas de cera)
        col = col * (1.0 - 0.10 * np.clip(m - 0.6, 0, 1)[..., None])
        al = (a * self._op)[..., None]
        self.tela = self.tela * (1 - al) + col * al
        self._m = None
        self._d = None

    # --- traços
    def _pts(self, pts, tremor, passo=7.0):
        """Densifica e aplica tremor suave (em pixels da folha em escala SS)."""
        p = np.array(pts, dtype=np.float32) * self.ss
        seg = np.hypot(*np.diff(p, axis=0).T) if len(p) > 1 else np.array([0.0])
        total = float(seg.sum())
        n = max(2, int(total / (passo * self.ss)) + 1)
        cum = np.concatenate([[0], np.cumsum(seg)])
        s = np.linspace(0, total, n)
        x = np.interp(s, cum, p[:, 0])
        y = np.interp(s, cum, p[:, 1])
        if tremor > 0:
            jan = max(3, n // 9)
            ox = suave(self.rng, n, jan) * tremor * self.ss * 1.0
            oy = suave(self.rng, n, jan) * tremor * self.ss * 1.0
            x = x + ox
            y = y + oy
        return list(zip(x.tolist(), y.tolist()))

    def linha(self, pts, larg=6, tremor=1.4, passes=2, sobra=0.0, fechada=False):
        """Polilinha em giz. `sobra`: fração do comprimento que o traço passa do fim (o gesto de criança)."""
        pts = [tuple(p) for p in pts]
        if fechada:
            pts = pts + [pts[0]]
        for k in range(passes):
            q = list(pts)
            if sobra > 0 and len(q) >= 2:
                (x0, y0), (x1, y1) = q[-2], q[-1]
                dx, dy = x1 - x0, y1 - y0
                q[-1] = (x1 + dx * sobra, y1 + dy * sobra)
            r = self._pts(q, tremor * (1.0 if k == 0 else 0.8))
            w = int(max(1, (larg * (1.0 - 0.18 * k) + self.rng.uniform(-0.8, 0.8)) * self.ss))
            fill = int(self.rng.uniform(215, 255))
            self._d.line(r, fill=fill, width=w, joint="curve")
            rr = w / 2.0
            for (x, y) in (r[0], r[-1]):
                self._d.ellipse([x - rr, y - rr, x + rr, y + rr], fill=fill)

    def elipse(self, cx, cy, rx, ry, larg=6, tremor=1.6, a0=None, a1=None, passes=2, giro=1):
        """Elipse irregular em um gesto só, fechando passando um pouco do começo."""
        r = self.rng
        ini = r.uniform(0, 2 * math.pi) if a0 is None else a0
        fim = ini + 2 * math.pi + 0.45 if a1 is None else a1
        n = max(24, int(abs(fim - ini) * max(rx, ry) / 5))
        t = np.linspace(ini, fim, n)
        raio = 1 + 0.045 * suave(r, n, max(3, n // 7))
        pts = [(cx + rx * raio[i] * math.cos(t[i] * giro) * (1 + 0.03 * (i / n)),
                cy + ry * raio[i] * math.sin(t[i] * giro) * (1 + 0.03 * (i / n))) for i in range(n)]
        self.linha(pts, larg, tremor, passes)

    def retangulo(self, x0, y0, x1, y1, larg=6, tremor=1.4, sobra=0.06):
        """Quatro riscos que se cruzam um pouco nas pontas, do jeito de quem desenha rápido."""
        self.linha([(x0, y0), (x1, y0 + (y1 - y0) * 0.01)], larg, tremor, sobra=sobra)
        self.linha([(x1, y0), (x1 + (x0 - x1) * 0.01, y1)], larg, tremor, sobra=sobra)
        self.linha([(x1, y1), (x0, y1)], larg, tremor, sobra=sobra)
        self.linha([(x0, y1), (x0, y0)], larg, tremor, sobra=sobra)

    def poligono(self, pts, larg=6, tremor=1.4, sobra=0.05):
        n = len(pts)
        for i in range(n):
            self.linha([pts[i], pts[(i + 1) % n]], larg, tremor, sobra=sobra)

    # --- preenchimento
    def rabisco(self, pts, esp=7, larg=None, ang=35, tremor=1.2, vaza=3, ida_volta=True):
        """Preenche um polígono com zigue-zague de giz; `vaza` px de pixels passam da borda (sem jeito de criança)."""
        larg = larg or esp * 1.05
        poli = np.array(pts, dtype=np.float32) * self.ss
        mk = Image.new("L", (self.W, self.H), 0)
        ImageDraw.Draw(mk).polygon([tuple(p) for p in poli], fill=255)
        if vaza > 0:
            mk = mk.filter(ImageFilter.MaxFilter(int(vaza * 2 * self.ss) | 1))
            mk = mk.filter(ImageFilter.GaussianBlur(self.ss * 1.5))
            mk = Image.fromarray(((np.asarray(mk, np.float32) / 255) > 0.5).astype(np.uint8) * 255)
        # zigue-zague em coordenadas giradas
        cx, cy = poli[:, 0].mean(), poli[:, 1].mean()
        raio = float(np.hypot(poli[:, 0] - cx, poli[:, 1] - cy).max()) + 8 * self.ss
        a = math.radians(ang)
        ca, sa = math.cos(a), math.sin(a)
        zz = []
        k = -raio
        sentido = 1
        passo = esp * self.ss
        while k <= raio:
            u0, u1 = (-raio, raio) if sentido > 0 else (raio, -raio)
            # linha na direção "ang", deslocada por k na perpendicular
            for u in (u0, u1):
                zz.append((cx + u * ca - k * sa, cy + u * sa + k * ca))
            sentido = -sentido if ida_volta else sentido
            k += passo * self.rng.uniform(0.8, 1.15)
        tmp = Image.new("L", (self.W, self.H), 0)
        dt = ImageDraw.Draw(tmp)
        r = self._pts([(p[0] / self.ss, p[1] / self.ss) for p in zz], tremor, passo=12)
        w = int(larg * self.ss)
        # cada segmento com pressão própria
        for i in range(len(r) - 1):
            dt.line([r[i], r[i + 1]], fill=int(self.rng.uniform(200, 255)), width=w)
        tmp = Image.fromarray(np.minimum(np.asarray(tmp), np.asarray(mk)))
        self._m.paste(Image.fromarray(np.maximum(np.asarray(self._m), np.asarray(tmp))))
        self._d = ImageDraw.Draw(self._m)

    def rabisco_elipse(self, cx, cy, rx, ry, **kw):
        pts = [(cx + rx * math.cos(t), cy + ry * math.sin(t)) for t in np.linspace(0, 2 * math.pi, 40, endpoint=False)]
        self.rabisco(pts, **kw)

    def rabisco_rect(self, x0, y0, x1, y1, **kw):
        self.rabisco([(x0, y0), (x1, y0), (x1, y1), (x0, y1)], **kw)

    def pontos(self, centros, raio=3, jit=1.0):
        for (x, y) in centros:
            x, y = x * self.ss, y * self.ss
            r = raio * self.ss * self.rng.uniform(0.85, 1.2)
            self._d.ellipse([x - r, y - r, x + r, y + r], fill=255)

    # --- saída
    def imagem(self, cinza_final=None):
        self.fechar()
        t = np.clip(self.tela, 0, 255).astype(np.uint8)
        img = Image.fromarray(t, "RGB").resize((self.w, self.h), Image.LANCZOS)
        return img


# ------------------------------------------------------------------ pedaços de desenho infantil
def assinatura(f, x, y, h=34, cor=VERMELHO, larg=5):
    """"TITO" em giz, com o primeiro T de cabeça para baixo (V2 §5: "o T ao contrário"): a criança escreve o
    próprio nome e erra a letra que ela mais repetiu. Letras desiguais, o último O não fecha direito."""
    f.cor(cor)
    r = f.rng
    xs = x
    # T invertido (⊥): haste em cima, travessa embaixo
    w = h * 0.95
    f.linha([(xs + w / 2, y), (xs + w / 2 + r.uniform(-1, 1), y + h)], larg, 1.0)
    f.linha([(xs - 4, y + h), (xs + w + 5, y + h - 1)], larg, 1.0)
    xs += w + h * 0.35
    # I
    f.linha([(xs, y + 1), (xs + 1, y + h * 1.02)], larg, 1.0)
    f.linha([(xs - 6, y + 1), (xs + 7, y)], larg - 1, 0.8)
    xs += h * 0.4
    # T normal, um pouco maior
    h2 = h * 1.08
    f.linha([(xs - 3, y - 3), (xs + w + 3, y - 2)], larg, 1.0)
    f.linha([(xs + w / 2, y - 2), (xs + w / 2 + 1, y + h2 - 2)], larg, 1.0)
    xs += w + h * 0.4
    # O (não fecha)
    f.elipse(xs + h * 0.32, y + h * 0.5, h * 0.34, h * 0.5, larg, 1.0, a0=-1.2, a1=-1.2 + 2 * math.pi + 0.5, passes=1)


def boneco(f, x, y, escala=1.0, cor=PRETO, larg=5, sorriso=True, braco_e=(-30, 25), braco_d=(30, 25), corpo_h=38, cabeca=14,
           boca="sorriso"):
    """Boneco palito. (x,y) = topo da cabeça. Devolve (centro_da_cabeca, quadril)."""
    s = escala
    cx = x
    cy = y + cabeca * s
    f.cor(cor)
    f.elipse(cx, cy, cabeca * s, cabeca * s, larg, 1.2, passes=1)
    f.linha([(cx, cy + cabeca * s), (cx, cy + cabeca * s + corpo_h * s)], larg, 1.2)
    ombro = (cx, cy + cabeca * s + corpo_h * 0.25 * s)
    f.linha([ombro, (ombro[0] + braco_e[0] * s, ombro[1] + braco_e[1] * s)], larg, 1.2)
    f.linha([ombro, (ombro[0] + braco_d[0] * s, ombro[1] + braco_d[1] * s)], larg, 1.2)
    quadril = (cx, cy + cabeca * s + corpo_h * s)
    f.linha([quadril, (quadril[0] - 14 * s, quadril[1] + 34 * s)], larg, 1.2)
    f.linha([quadril, (quadril[0] + 14 * s, quadril[1] + 34 * s)], larg, 1.2)
    # rosto
    f.pontos([(cx - 5 * s, cy - 3 * s), (cx + 5 * s, cy - 3 * s)], raio=1.8 * s + 0.8)
    if boca == "sorriso":
        f.linha([(cx - 6 * s, cy + 5 * s), (cx - 2 * s, cy + 9 * s), (cx + 2 * s, cy + 9 * s), (cx + 6 * s, cy + 5 * s)], max(2, larg - 2), 0.4, passes=1)
    elif boca == "reta":
        f.linha([(cx - 5 * s, cy + 7 * s), (cx + 5 * s, cy + 7 * s)], max(2, larg - 2), 0.4, passes=1)
    return (cx, cy), quadril


def balde(f, x, y, s=1.0, larg=4):
    """Balde de praia vermelho (trapézio com alça). (x,y) = centro da boca."""
    f.cor(VERMELHO)
    pts = [(x - 13 * s, y), (x + 13 * s, y), (x + 9 * s, y + 20 * s), (x - 9 * s, y + 20 * s)]
    f.rabisco(pts, esp=4 * s + 1, larg=5 * s + 1, ang=60, tremor=0.6, vaza=1)
    f.cor(PRETO)
    f.linha([(x - 14 * s, y), (x + 14 * s, y), (x + 10 * s, y + 21 * s), (x - 10 * s, y + 21 * s), (x - 14 * s, y)], larg * 0.6, 0.5, passes=1)
    f.linha([(x - 13 * s, y), (x - 8 * s, y - 14 * s), (x + 8 * s, y - 14 * s), (x + 13 * s, y)], larg * 0.5, 0.4, passes=1)


def bermuda(f, quadril, s=1.0):
    f.cor(AZUL)
    x, y = quadril
    f.rabisco([(x - 12 * s, y - 2 * s), (x + 12 * s, y - 2 * s), (x + 16 * s, y + 18 * s), (x + 2 * s, y + 18 * s), (x, y + 8 * s), (x - 2 * s, y + 18 * s), (x - 16 * s, y + 18 * s)],
              esp=3.5 * s + 1, larg=4.2 * s + 1, ang=70, tremor=0.5, vaza=1)


def sol(f, x, y, r=34):
    f.cor(AMARELO)
    f.rabisco_elipse(x, y, r, r, esp=6, larg=7, ang=40, vaza=2)
    f.cor(LARANJA)
    f.elipse(x, y, r, r, 4, 1.2, passes=1)
    for i in range(12):
        a = i * math.tau / 12 + f.rng.uniform(-0.08, 0.08)
        d0, d1 = r + 8, r + 22 + f.rng.uniform(-3, 8)
        f.linha([(x + d0 * math.cos(a), y + d0 * math.sin(a)), (x + d1 * math.cos(a), y + d1 * math.sin(a))], 5, 1.0, passes=1)


def nuvem(f, x, y, s=1.0, cor=AZUL_CLARO):
    f.cor(cor)
    for dx, dy, r in [(-26, 4, 18), (0, -6, 24), (28, 4, 18), (6, 10, 16)]:
        f.elipse(x + dx * s, y + dy * s, r * s, r * s * 0.8, 4, 1.0, passes=1, a0=-2.5, a1=1.2)


def castelo(f, x0, y0, x1, y1, cor_parede=VERMELHO, cor_telhado=AZUL, janela_escura=False, pedra=False, larg=6):
    """Castelo de criança: corpo retangular com ameias, duas torres com telhado pontudo, porta e janelas.
    Devolve o retângulo da torre esquerda (para a mulher na janela)."""
    r = f.rng
    w = x1 - x0
    h = y1 - y0
    # torres
    tw = w * 0.22
    tl = (x0, y0 - h * 0.35, x0 + tw, y1)
    tr = (x1 - tw, y0 - h * 0.35, x1, y1)
    # paredes (preenchimento)
    f.cor(cor_parede)
    f.rabisco_rect(x0 + tw, y0, x1 - tw, y1, esp=7, larg=8, ang=25, vaza=2)
    f.rabisco_rect(tl[0], tl[1], tl[2], tl[3], esp=7, larg=8, ang=-25, vaza=2)
    f.rabisco_rect(tr[0], tr[1], tr[2], tr[3], esp=7, larg=8, ang=-25, vaza=2)
    # telhados
    f.cor(cor_telhado)
    for (a, b, c, d) in (tl, tr):
        cx = (a + c) / 2
        f.rabisco([(a - 8, b), (c + 8, b), (cx, b - h * 0.42)], esp=6, larg=7, ang=70, vaza=1)
    # contornos
    f.cor(PRETO)
    f.retangulo(x0 + tw, y0, x1 - tw, y1, larg - 1, 1.5)
    f.retangulo(*tl, larg - 1, 1.5)
    f.retangulo(*tr, larg - 1, 1.5)
    for (a, b, c, d) in (tl, tr):
        cx = (a + c) / 2
        f.linha([(a - 8, b), (cx, b - h * 0.42), (c + 8, b)], larg - 1, 1.2, sobra=0.04)
        f.linha([(a - 8, b), (c + 8, b)], larg - 2, 1.0)
    # ameias no corpo
    n = 5
    mw = (w - 2 * tw) / n
    for i in range(n):
        xa = x0 + tw + i * mw
        if i % 2 == 0:
            f.linha([(xa, y0), (xa, y0 - 14), (xa + mw, y0 - 14), (xa + mw, y0)], larg - 2, 0.8, passes=1)
    # porta
    f.cor(MARROM)
    pw = w * 0.14
    px = (x0 + x1) / 2
    f.rabisco([(px - pw, y1), (px - pw, y1 - h * 0.34), (px, y1 - h * 0.42), (px + pw, y1 - h * 0.34), (px + pw, y1)], esp=5, larg=6, ang=80, vaza=1)
    f.cor(PRETO)
    f.linha([(px - pw, y1), (px - pw, y1 - h * 0.34), (px, y1 - h * 0.42), (px + pw, y1 - h * 0.34), (px + pw, y1)], 4, 1.0, passes=1)
    # janelas
    jw, jh = (15, 50) if janela_escura else (9, 26)
    f.cor(PRETO if janela_escura else AMARELO)
    for (a, b, c, d) in (tl, tr):
        cx = (a + c) / 2
        jy = b + h * 0.12
        f.rabisco_rect(cx - jw, jy, cx + jw, jy + jh, esp=4, larg=5, ang=80, vaza=0)
    f.cor(PRETO)
    for (a, b, c, d) in (tl, tr):
        cx = (a + c) / 2
        jy = b + h * 0.12
        f.retangulo(cx - jw, jy, cx + jw, jy + jh, 3, 0.6, sobra=0.04)
    if pedra:
        f.cor(CINZA_ESC)
        for yy in np.arange(y0 + 14, y1, 22):
            f.linha([(x0 + tw, yy), (x1 - tw, yy + r.uniform(-2, 2))], 3, 1.2, passes=1)
    return tl


def grama(f, y, x0=0, x1=512, cor=VERDE, esp=5, alt=70):
    f.cor(cor)
    f.rabisco_rect(x0, y, x1, y + alt, esp=6, larg=7, ang=10, vaza=0)
    for x in np.arange(x0 + 6, x1, 12):
        f.linha([(x, y + 6), (x + f.rng.uniform(-3, 3), y - f.rng.uniform(5, 14))], 3, 0.6, passes=1)


# ------------------------------------------------------------------ os 7 desenhos
def desenho_1(rng):
    """Castelo com sol e boneco palito (visita 1, sala 11). O alegre."""
    f = Folha(512, 512, rng)
    # céu em riscos azuis no alto
    f.cor(AZUL_CLARO, 0.55)
    f.rabisco_rect(0, 0, 512, 210, esp=10, larg=11, ang=8, vaza=0, tremor=2.0)
    sol(f, 82, 82, 34)
    nuvem(f, 330, 70, 1.1)
    nuvem(f, 440, 130, 0.8)
    grama(f, 400)
    castelo(f, 150, 240, 360, 410)
    boneco(f, 430, 296, 1.15, PRETO, 5, braco_e=(-26, -12), braco_d=(30, -24), boca="sorriso")
    # bandeirinha na torre
    f.cor(VERMELHO)
    f.linha([(150 + 23, 240 - 60 - 56), (150 + 23, 240 - 60 - 95)], 4, 0.6)
    f.rabisco([(173, 85), (209, 99), (173, 112)], esp=4, larg=5, vaza=1)
    assinatura(f, 340, 452, 36, VERMELHO)
    return f.imagem()


def desenho_2(rng):
    """Ele e a mãe na praia (visita 2)."""
    f = Folha(512, 512, rng)
    f.cor(AZUL_CLARO, 0.5)
    f.rabisco_rect(0, 0, 512, 150, esp=10, larg=11, ang=4, vaza=0, tremor=2.0)
    sol(f, 420, 70, 32)
    # mar
    f.cor(AZUL)
    f.rabisco_rect(0, 160, 512, 245, esp=8, larg=9, ang=2, vaza=0, tremor=2.2)
    f.cor(AZUL_CLARO)
    for y in (182, 207, 231):
        pts = [(x, y + 7 * math.sin(x / 20)) for x in range(0, 520, 10)]
        f.linha(pts, 4, 0.8, passes=1)
    # areia
    f.cor(AMARELO, 0.9)
    f.rabisco_rect(0, 245, 512, 512, esp=9, larg=10, ang=14, vaza=0, tremor=2.5)
    f.cor(LARANJA, 0.6)
    for _ in range(18):
        x, y = rng.uniform(10, 500), rng.uniform(300, 500)
        f.linha([(x, y), (x + rng.uniform(8, 20), y + rng.uniform(-3, 3))], 3, 0.5, passes=1)
    # mãe: bem maior, vestido de triângulo, cabelo comprido
    mx, my = 190, 230
    f.cor(ROSA)
    f.rabisco([(mx, my + 62), (mx - 34, my + 150), (mx + 34, my + 150)], esp=5, larg=6, ang=75, vaza=1)
    f.cor(PRETO)
    f.linha([(mx, my + 60), (mx - 36, my + 152), (mx + 36, my + 152), (mx, my + 60)], 5, 1.2, sobra=0.03)
    f.elipse(mx, my + 30, 25, 25, 5, 1.2, passes=1)
    f.cor(MARROM)
    f.linha([(mx - 25, my + 20), (mx - 34, my + 60), (mx - 28, my + 85)], 7, 1.0)
    f.linha([(mx + 25, my + 20), (mx + 34, my + 60), (mx + 28, my + 85)], 7, 1.0)
    f.cor(PRETO)
    f.linha([(mx - 3, my + 62), (mx - 52, my + 98)], 5, 1.2)
    f.linha([(mx + 3, my + 62), (mx + 34, my + 106)], 5, 1.2)
    f.linha([(mx - 14, my + 150), (mx - 16, my + 200)], 5, 1.0)
    f.linha([(mx + 14, my + 150), (mx + 16, my + 200)], 5, 1.0)
    f.pontos([(mx - 9, my + 27), (mx + 9, my + 27)], 2.4)
    f.linha([(mx - 11, my + 40), (mx - 4, my + 46), (mx + 4, my + 46), (mx + 11, my + 40)], 3, 0.4, passes=1)
    # menino (pequeno) de mãos dadas com ela
    (cx, cy), quad = boneco(f, 292, 330, 0.9, PRETO, 4, braco_e=(-52, 0), braco_d=(30, 22), corpo_h=34)
    bermuda(f, quad, 0.9)
    balde(f, 345, 420, 0.9)
    f.cor(PRETO)
    f.linha([(mx + 34, my + 106), (cx - 46, cy + 36)], 4, 1.0)   # as mãos se encontram
    # um castelinho de areia
    f.cor(LARANJA)
    f.rabisco([(390, 470), (448, 470), (440, 430), (396, 430)], esp=5, larg=6, vaza=1)
    f.cor(PRETO)
    f.linha([(388, 472), (450, 472), (441, 428), (396, 428), (388, 472)], 4, 1.0, passes=1)
    assinatura(f, 20, 456, 32, VERMELHO)
    return f.imagem()


def desenho_3(rng):
    """O castelo com uma mulher branca na janela da torre (fim da visita 2)."""
    f = Folha(512, 512, rng, amarelar=0.2)
    # a noite toma a folha inteira: roxo e azul-marinho em camadas cruzadas
    f.cor(ROXO, 0.92)
    f.rabisco_rect(0, 0, 512, 420, esp=8, larg=10, ang=12, vaza=0, tremor=2.2)
    f.cor((20, 28, 90), 0.88)
    f.rabisco_rect(0, 0, 512, 330, esp=9, larg=10, ang=-20, vaza=0, tremor=2.2)
    f.cor((14, 18, 60), 0.7)
    f.rabisco_rect(0, 200, 512, 420, esp=11, larg=11, ang=70, vaza=0, tremor=2.2)
    # lua e estrelas
    f.cor(AMARELO)
    f.elipse(430, 64, 24, 24, 6, 1.2, passes=2)
    for (x, y) in [(60, 50), (130, 110), (250, 40), (330, 100), (480, 160), (40, 170)]:
        f.linha([(x - 8, y), (x + 8, y)], 3, 0.4, passes=1)
        f.linha([(x, y - 8), (x, y + 8)], 3, 0.4, passes=1)
    grama(f, 400, cor=(24, 90, 50), alt=120)
    tl = castelo(f, 150, 240, 360, 410, cor_parede=CINZA_ESC, cor_telhado=(60, 30, 90), janela_escura=True)
    # a mulher branca na janela da torre esquerda (giz branco sobre o preto): vestido longo, cabeça sem rosto, cabelo caído
    cx = (tl[0] + tl[2]) / 2
    jy = tl[1] + (410 - 240) * 0.12
    f.cor(BRANCO, 0.98)
    f.rabisco([(cx - 8, jy + 17), (cx + 8, jy + 17), (cx + 13, jy + 49), (cx - 13, jy + 49)], esp=2.4, larg=3.4, ang=80, vaza=0, tremor=0.2)
    f.elipse(cx, jy + 10, 6, 7.5, 3, 0.2, passes=1)
    f.linha([(cx - 7, jy + 6), (cx - 11, jy + 30)], 2.4, 0.2, passes=1)   # cabelo comprido
    f.linha([(cx + 7, jy + 6), (cx + 11, jy + 30)], 2.4, 0.2, passes=1)
    f.linha([(cx - 5, jy + 22), (cx - 10, jy + 44)], 2.4, 0.2, passes=1)  # braços ao longo do corpo
    f.linha([(cx + 5, jy + 22), (cx + 10, jy + 44)], 2.4, 0.2, passes=1)
    # o menino lá embaixo, pequeno, em giz branco, olhando para cima
    (hx, hy), quad = boneco(f, 96, 372, 0.72, BRANCO, 4, braco_e=(-18, 18), braco_d=(18, 18), corpo_h=30, boca="reta")
    assinatura(f, 24, 446, 34, BRANCO)
    return f.imagem()


def desenho_4(rng):
    """Ele embaixo do castelo, e o castelo em cima dele, todo em pedra (visita 3)."""
    f = Folha(512, 512, rng, amarelar=0.3)
    # terra em corte (marrom) ocupando a metade de baixo
    f.cor(MARROM, 0.9)
    f.rabisco_rect(0, 250, 512, 512, esp=8, larg=10, ang=5, vaza=0, tremor=2.2)
    f.cor((84, 50, 28), 0.8)
    f.rabisco_rect(0, 330, 512, 512, esp=10, larg=11, ang=-15, vaza=0, tremor=2.2)
    # linha do chão
    f.cor(VERDE)
    f.linha([(0, 248), (512, 252)], 10, 1.5)
    # o castelo: todo em pedra, enorme, pesado: cinza em tijolinhos
    f.cor(CINZA, 0.95)
    f.rabisco_rect(60, 70, 452, 250, esp=8, larg=10, ang=12, vaza=1, tremor=1.6)
    f.rabisco_rect(40, 24, 130, 250, esp=8, larg=10, ang=-20, vaza=1)
    f.rabisco_rect(382, 24, 472, 250, esp=8, larg=10, ang=-20, vaza=1)
    f.cor(CINZA_ESC)
    for yy in range(40, 250, 24):
        off = 0 if (yy // 24) % 2 == 0 else 22
        f.linha([(40, yy), (472, yy + rng.uniform(-2, 2))], 3, 1.5, passes=1)
    for yy in range(40, 250, 24):
        off = 0 if (yy // 24) % 2 == 0 else 22
        for xx in range(40 + off, 472, 44):
            f.linha([(xx, yy), (xx + rng.uniform(-2, 2), yy + 24)], 3, 0.8, passes=1)
    f.cor(PRETO)
    f.retangulo(60, 70, 452, 250, 6, 1.5)
    f.retangulo(40, 24, 130, 250, 6, 1.5)
    f.retangulo(382, 24, 472, 250, 6, 1.5)
    for (a, c) in ((40, 130), (382, 472)):
        for x in np.arange(a, c, 22):
            f.linha([(x, 24), (x, 10), (x + 11, 10), (x + 11, 24)], 4, 0.5, passes=1)
    # janelas escuras e uma porta fechada
    f.rabisco_rect(78, 70, 98, 108, esp=4, larg=5, vaza=0)
    f.rabisco_rect(414, 70, 434, 108, esp=4, larg=5, vaza=0)
    f.rabisco_rect(232, 160, 282, 250, esp=5, larg=6, ang=80, vaza=0)
    # embaixo da terra: ele, bem pequeno, olhando para cima; a sala é uma caixinha de ar
    f.cor((226, 214, 190), 0.9)
    f.rabisco_rect(200, 380, 330, 480, esp=6, larg=7, ang=30, vaza=0)
    f.cor(PRETO)
    f.retangulo(200, 380, 330, 480, 5, 1.2)
    (cx, cy), quad = boneco(f, 262, 400, 0.78, PRETO, 4, braco_e=(-18, 14), braco_d=(18, 14), corpo_h=28, boca="reta")
    bermuda(f, quad, 0.75)
    balde(f, 305, 462, 0.7, larg=3)
    # setinha de "cima": o castelo apertando (duas linhas curtas)
    f.cor(PRETO)
    f.linha([(262, 262), (262, 296)], 5, 0.8)
    f.linha([(250, 284), (262, 298), (274, 284)], 5, 0.8)
    f.linha([(262, 310), (262, 344)], 5, 0.8)
    f.linha([(250, 332), (262, 346), (274, 332)], 5, 0.8)
    assinatura(f, 360, 466, 30, VERMELHO)
    return f.imagem()


def desenho_5(rng):
    """Muita água azul, e ele pequeno no meio (visita 4)."""
    f = Folha(512, 512, rng, amarelar=0.2)
    # a página toda de azul, em camadas que se cruzam, cada vez mais escuras
    f.cor(AZUL_CLARO, 0.95)
    f.rabisco_rect(-4, -4, 516, 516, esp=8, larg=10, ang=14, vaza=0, tremor=2.6)
    f.cor(AZUL, 0.9)
    f.rabisco_rect(-4, 70, 516, 516, esp=8, larg=10, ang=-35, vaza=0, tremor=2.6)
    f.cor((24, 54, 150), 0.85)
    f.rabisco_rect(-4, 190, 516, 516, esp=9, larg=10, ang=60, vaza=0, tremor=2.6)
    f.cor((14, 30, 96), 0.8)
    f.rabisco_rect(-4, 340, 516, 516, esp=9, larg=10, ang=-8, vaza=0, tremor=2.6)
    # ondas em arquinhos de criança, em fileiras que cobrem tudo; mais escuras e mais juntas para baixo
    def fileira(y, cor, raio, larg):
        f.cor(cor, 0.9)
        x = -10 + rng.uniform(0, raio)
        while x < 530:
            f.elipse(x, y, raio, raio * 0.8, larg, 0.8, a0=math.pi, a1=2 * math.pi + 0.15, passes=1)
            x += raio * 2 * rng.uniform(0.92, 1.05)
    for i, y in enumerate(range(28, 520, 46)):
        fileira(y, BRANCO if i % 2 == 0 else AZUL_CLARO, 22 - i * 0.5, 4)
        if y > 150:
            fileira(y + 22, (10, 18, 70) if i % 2 else (40, 80, 190), 20, 4)
    # ele, pequeno, no meio, com a água na altura do peito: cabeça, braços para os lados
    cx, cy, k = 256, 236, 1.5
    f.cor(PRETO)
    f.elipse(cx, cy, 9 * k, 9 * k, 4.5, 1.0, passes=1)
    f.linha([(cx, cy + 9 * k), (cx, cy + 28 * k)], 4.5, 0.6)
    f.linha([(cx, cy + 18 * k), (cx - 22 * k, cy + 12 * k)], 4.5, 0.6)
    f.linha([(cx, cy + 18 * k), (cx + 22 * k, cy + 12 * k)], 4.5, 0.6)
    f.pontos([(cx - 3.5 * k, cy - 2 * k), (cx + 3.5 * k, cy - 2 * k)], 1.8)
    f.linha([(cx - 3.5 * k, cy + 4 * k), (cx + 3.5 * k, cy + 4 * k)], 3, 0.2, passes=1)
    # a água por cima do corpo
    f.cor((30, 70, 190), 0.97)
    f.rabisco([(cx - 52, cy + 28), (cx + 52, cy + 28), (cx + 52, cy + 66), (cx - 52, cy + 66)], esp=4, larg=5.5, ang=5, vaza=1, tremor=0.5)
    f.cor(BRANCO, 0.9)
    pts = [(x, cy + 28 + 4 * math.sin(x / 6)) for x in range(cx - 52, cx + 54, 5)]
    f.linha(pts, 3, 0.4, passes=1)
    # balde vermelho boiando, ao lado
    f.cor(VERMELHO)
    f.rabisco([(328, 262), (362, 262), (358, 286), (332, 286)], esp=4, larg=5, vaza=1)
    f.cor(PRETO)
    f.linha([(326, 262), (364, 262), (360, 288), (330, 288), (326, 262)], 3, 0.6, passes=1)
    f.cor(AZUL, 0.9)
    f.rabisco([(308, 286), (382, 286), (378, 300), (312, 300)], esp=4, larg=5, vaza=0, tremor=0.5)
    assinatura(f, 24, 462, 34, AMARELO, larg=5)
    return f.imagem()


def desenho_6(rng):
    """A página toda pintada de preto, com dois olhos (visita 4)."""
    f = Folha(512, 512, rng, amarelar=0.5, dureza=0.9)
    # preto em camadas cruzadas, a mão pesada de uma criança brava: o papel aparece pelo dente e pelas bordas
    f.cor(PRETO, 0.97)
    f.rabisco_rect(14, 12, 500, 502, esp=9, larg=10, ang=8, vaza=0, tremor=3.2)
    f.cor((24, 20, 34), 0.95)
    f.rabisco_rect(10, 18, 504, 498, esp=11, larg=11, ang=-58, vaza=0, tremor=3.2)
    f.cor((10, 10, 14), 0.97)
    f.rabisco_rect(20, 20, 494, 494, esp=10, larg=10, ang=33, vaza=0, tremor=3.2)
    f.cor((60, 30, 70), 0.5)   # um roxo escuro por baixo do preto, aparece nos vãos
    f.rabisco_rect(30, 30, 480, 480, esp=14, larg=9, ang=80, vaza=0, tremor=3.2)
    # dois olhos de giz branco, redondos, um pouco desiguais; pupilas pretas, desviadas para o jogador
    for (x, y, r) in [(190, 232, 40), (330, 226, 46)]:
        f.cor(BRANCO, 0.98)
        f.rabisco_elipse(x, y, r, r * 0.8, esp=4.5, larg=6, ang=15, vaza=0, tremor=0.8)
        f.elipse(x, y, r, r * 0.8, 5, 1.0, passes=2)
        f.cor(PRETO, 1.0)
        f.rabisco_elipse(x - 3, y + 4, r * 0.44, r * 0.44, esp=3.2, larg=5, ang=45, vaza=0)
        f.rabisco_elipse(x - 3, y + 4, r * 0.44, r * 0.44, esp=3.2, larg=5, ang=-45, vaza=0)
    # assinatura minúscula, de giz cinza, no canto de baixo: quase não se vê
    assinatura(f, 392, 466, 22, (150, 150, 158), larg=3)
    return f.imagem()


def desenho_7(rng):
    """Um desenho do jogador, de costas, com o Visor na mão (porão)."""
    f = Folha(512, 512, rng, amarelar=0.45)
    # um corredor de pedra em perspectiva ingênua (duas paredes e o chão) em cinza e marrom; o teto fica em branco, como criança deixa
    f.cor(CINZA, 0.88)
    f.rabisco([(0, 20), (140, 130), (140, 370), (0, 512)], esp=8, larg=10, ang=70, vaza=0, tremor=2.0)
    f.rabisco([(512, 20), (372, 130), (372, 370), (512, 512)], esp=8, larg=10, ang=-70, vaza=0, tremor=2.0)
    f.cor(MARROM, 0.85)
    f.rabisco([(140, 370), (372, 370), (512, 512), (0, 512)], esp=8, larg=10, ang=5, vaza=0, tremor=2.0)
    f.cor(CINZA_ESC, 0.92)
    f.rabisco_rect(140, 130, 372, 370, esp=8, larg=10, ang=-10, vaza=0, tremor=1.5)
    f.cor(PRETO)
    f.linha([(0, 20), (140, 130)], 5, 1.2)
    f.linha([(512, 20), (372, 130)], 5, 1.2)
    f.linha([(0, 512), (140, 370)], 5, 1.2)
    f.linha([(512, 512), (372, 370)], 5, 1.2)
    f.retangulo(140, 130, 372, 370, 5, 1.5)
    # ao fundo, uma porta preta e, dentro dela, uma figura branca de braços abertos, sem rosto
    f.rabisco_rect(212, 190, 300, 370, esp=5, larg=7, ang=80, vaza=0, tremor=0.8)
    f.retangulo(212, 190, 300, 370, 4, 1.0)
    f.cor(BRANCO, 0.98)
    f.rabisco([(256, 250), (236, 350), (276, 350)], esp=3, larg=4, ang=80, vaza=0, tremor=0.3)
    f.elipse(256, 236, 8, 10, 3, 0.3, passes=1)
    f.linha([(256, 258), (222, 276)], 3, 0.4, passes=1)
    f.linha([(256, 258), (290, 276)], 3, 0.4, passes=1)
    # o jogador, de costas, em primeiro plano (escala 0.78): cabelo, camiseta verde, calça azul; braço erguido com o Visor
    S = 0.78
    px, py = 168, 268

    def P(dx, dy):
        return (px + dx * S, py + dy * S)

    f.cor(MARROM)
    f.rabisco_elipse(*P(0, 28), 30 * S, 32 * S, esp=4, larg=5.5, ang=30, vaza=1)
    f.cor(PRETO)
    f.elipse(*P(0, 28), 31 * S, 33 * S, 4, 1.2, passes=1)
    f.cor(VERDE)
    f.rabisco([P(-38, 66), P(38, 66), P(46, 190), P(-46, 190)], esp=6, larg=7, ang=75, vaza=1)
    f.cor(AZUL)
    f.rabisco([P(-44, 190), P(44, 190), P(40, 290), P(4, 290), P(0, 220), P(-4, 290), P(-40, 290)], esp=6, larg=7, ang=80, vaza=1)
    f.cor(PRETO)
    f.linha([P(-38, 66), P(-46, 190), P(46, 190), P(38, 66), P(-38, 66)], 5, 1.3)
    f.linha([P(-44, 190), P(-40, 292)], 5, 1.2)
    f.linha([P(44, 190), P(40, 292)], 5, 1.2)
    f.linha([P(-40, 292), P(-4, 292)], 4, 1.0)
    f.linha([P(40, 292), P(4, 292)], 4, 1.0)
    f.linha([P(-38, 74), P(-62, 150)], 8, 1.2)
    f.linha([P(38, 74), P(78, 40), P(90, -6)], 8, 1.2)
    # o Visor: caixinha vermelha com dois olhos redondos
    f.cor(VERMELHO)
    f.rabisco_rect(*P(66, -40), *P(124, -6), esp=4, larg=5, ang=60, vaza=1)
    f.cor(PRETO)
    f.retangulo(*P(64, -42), *P(126, -4), 4, 0.8)
    f.cor(BRANCO)
    f.elipse(*P(82, -24), 7, 7, 3, 0.3, passes=1)
    f.elipse(*P(108, -24), 7, 7, 3, 0.3, passes=1)
    assinatura(f, 24, 470, 30, VERMELHO)
    return f.imagem()


# ------------------------------------------------------------------ cartaz PROCURA-SE
def procura_se(rng):
    """Cartaz de 1967: papel amarelado e rasgado, tinta preta, retrato a traço de um menino, texto datilografado."""
    W, H = 512, 720
    f = Folha(W, H, rng, papel=(232, 214, 160), amarelar=1.0, dureza=0.4)
    tela = f.tela
    # manchas de umidade/idade e vincos
    mancha = fractal(rng, f.W, f.H, (200, 80, 30), (0.5, 0.3, 0.2))
    tela *= (0.93 + 0.12 * mancha)[..., None]
    for _ in range(3):
        y = rng.uniform(0.2, 0.8) * f.H
        tela[int(y):int(y) + 3, :, :] *= 0.9
    x = f.W * rng.uniform(0.35, 0.65)
    tela[:, int(x):int(x) + 3, :] *= 0.92
    # anel de umidade (copo/gota) no canto de baixo à direita
    yy0, xx0 = np.mgrid[0:f.H, 0:f.W].astype(np.float32)
    rr = np.hypot(xx0 - f.W * 0.80, yy0 - f.H * 0.86)
    anel = np.exp(-((rr - 92 * SS) / (4.5 * SS)) ** 2) * 0.16 + np.exp(-(rr / (90 * SS)) ** 2) * 0.05
    tela *= (1 - anel)[..., None] * np.array([1.0, 0.96, 0.88], dtype=np.float32)
    # tinta preta: texto com PIL sobre uma máscara, aplicando o "dente" para a tinta falhar um pouco
    mask = Image.new("L", (f.W, f.H), 0)
    d = ImageDraw.Draw(mask)
    s = SS
    f_tit = fonte_sistema(["/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"], 74 * s)
    f_sub = fonte_sistema(["/usr/share/fonts/truetype/liberation/LiberationMono-Bold.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf"], 29 * s)
    f_nome = fonte_sistema(["/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSerif-Bold.ttf"], 62 * s)
    f_peq = fonte_sistema(["/usr/share/fonts/truetype/liberation/LiberationMono-Regular.ttf", "/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf"], 22 * s)

    def centro(txt, y, fnt, fill=255, largura_max=(W - 84) * s):
        w = d.textlength(txt, font=fnt)
        if w > largura_max:  # encolhe para caber, mantendo a fonte
            k = largura_max / w
            fnt = fnt.font_variant(size=int(fnt.size * k))
            w = d.textlength(txt, font=fnt)
        d.text(((f.W - w) / 2 + rng.uniform(-2, 2), y * s), txt, font=fnt, fill=fill)

    # moldura de filete duplo
    d.rectangle([22 * s, 22 * s, (W - 22) * s, (H - 22) * s], outline=255, width=3 * s)
    d.rectangle([30 * s, 30 * s, (W - 30) * s, (H - 30) * s], outline=255, width=1 * s)
    centro("PROCURA-SE", 50, f_tit)
    d.line([(60 * s, 150 * s), ((W - 60) * s, 150 * s)], fill=255, width=3 * s)
    # espaço do retrato: 190..470 (largura 200)
    centro("TITO", 478, f_nome)
    centro("9 anos", 544, f_sub)
    centro("desaparecido desde 12/03/1967", 582, f_sub)
    centro("bermuda azul, balde vermelho", 618, f_sub)
    d.line([(60 * s, 660 * s), ((W - 60) * s, 660 * s)], fill=255, width=2 * s)
    centro("Informações: fone 4-27  ·  A família agradece", 672, f_peq)
    m = np.asarray(mask.filter(ImageFilter.GaussianBlur(0.5 * s)), dtype=np.float32) / 255
    a = np.clip(m * 1.2 - f.dente * 0.4, 0, 1) * 0.88   # tinta falha onde o papel é áspero (mimeógrafo gasto)
    cor_tinta = np.array([38, 30, 26], dtype=np.float32)
    f.tela = f.tela * (1 - a[..., None]) + cor_tinta * a[..., None]

    # retrato a traço (grafite/nanquim): cabeça, cabelo em franja, orelhas, olhos, nariz, boca fechada, gola
    f.cor((44, 36, 32), 0.92)
    cx, cy = W / 2, 306
    f.elipse(cx, cy, 62, 78, 3.2, 1.1, passes=2)                          # rosto
    f.linha([(cx - 62, cy - 12), (cx - 72, cy - 10), (cx - 74, cy + 14), (cx - 63, cy + 22)], 3, 0.6, passes=1)   # orelha
    f.linha([(cx + 62, cy - 12), (cx + 72, cy - 10), (cx + 74, cy + 14), (cx + 63, cy + 22)], 3, 0.6, passes=1)
    # cabelo: franja curta repartida de lado, em riscos
    f.rabisco([(cx - 66, cy - 14), (cx - 54, cy - 70), (cx - 10, cy - 92), (cx + 40, cy - 84), (cx + 66, cy - 40), (cx + 62, cy - 12),
               (cx + 36, cy - 44), (cx - 4, cy - 40), (cx - 30, cy - 32), (cx - 58, cy - 6)], esp=3.2, larg=3.4, ang=62, vaza=0, tremor=0.5)
    f.linha([(cx - 52, cy - 38), (cx - 8, cy - 62), (cx + 30, cy - 54)], 2.4, 0.7, passes=1)
    # olhos (grandes, abertos, olhando para quem vê), sobrancelhas, nariz, boca
    for ex in (-26, 26):
        f.elipse(cx + ex, cy + 2, 11, 8, 2.8, 0.5, passes=1)
        f.rabisco_elipse(cx + ex + 1, cy + 3, 4.5, 4.5, esp=2.5, larg=3.4, vaza=0)
        f.linha([(cx + ex - 14, cy - 17), (cx + ex, cy - 21), (cx + ex + 14, cy - 17)], 2.6, 0.6, passes=1)
    f.linha([(cx - 3, cy + 6), (cx - 7, cy + 30), (cx + 5, cy + 33)], 2.6, 0.5, passes=1)
    f.linha([(cx - 20, cy + 52), (cx - 6, cy + 55), (cx + 12, cy + 54), (cx + 21, cy + 50)], 2.6, 0.5, passes=1)
    # sombras de hachura no queixo e lado do rosto
    for k in range(7):
        f.linha([(cx + 40 + k * 2, cy + 18 + k * 7), (cx + 28 + k * 2, cy + 52 + k * 7)], 1.8, 0.4, passes=1)
    # pescoço e camisa de gola
    f.linha([(cx - 24, cy + 74), (cx - 28, cy + 104)], 3, 0.5, passes=1)
    f.linha([(cx + 24, cy + 74), (cx + 28, cy + 104)], 3, 0.5, passes=1)
    f.linha([(cx - 28, cy + 104), (cx - 78, cy + 124), (cx - 100, cy + 150)], 3.2, 0.8, passes=1)
    f.linha([(cx + 28, cy + 104), (cx + 78, cy + 124), (cx + 100, cy + 150)], 3.2, 0.8, passes=1)
    f.linha([(cx - 28, cy + 104), (cx, cy + 124), (cx + 28, cy + 104)], 3, 0.6, passes=1)
    # moldurinha do retrato
    f.retangulo(cx - 118, 166, cx + 118, 452, 3, 1.0, sobra=0.0)
    # fita adesiva amarelada nos cantos e um rasgo em baixo à esquerda
    f.cor((248, 236, 190), 0.55)
    f.rabisco([(8, 22), (62, 8), (84, 40), (30, 58)], esp=4, larg=5, ang=40, vaza=0)
    f.rabisco([(W - 60, 8), (W - 6, 26), (W - 30, 62), (W - 84, 44)], esp=4, larg=5, ang=-40, vaza=0)
    f.fechar()
    img = f.imagem()
    # rasgo nas bordas: recorta um pouco as pontas por um alfa irregular (o fundo fica transparente)
    img = img.convert("RGBA")
    alfa = np.full((H, W), 255, dtype=np.uint8)
    borda = fractal(rng, W, H, (20, 7, 3), (0.4, 0.4, 0.2))
    for (x0, y0, x1, y1, lado) in [(0, 0, W, 6, "t"), (0, H - 8, W, H, "b"), (0, 0, 6, H, "l"), (W - 6, 0, W, H, "r")]:
        pass
    yy, xx = np.mgrid[0:H, 0:W]
    dist = np.minimum(np.minimum(xx, W - 1 - xx), np.minimum(yy, H - 1 - yy)).astype(np.float32)
    limite = 3 + 7 * borda
    alfa[dist < limite * 0.55] = 0
    # canto rasgado (inferior esquerdo) e (superior direito)
    alfa[(xx + (H - yy) < 46) & (dist < 60)] = 0
    img.putalpha(Image.fromarray(alfa))
    return img


# ------------------------------------------------------------------ marcas de altura
def _digito(f, ch, x, y, h, larg):
    """Dígito 6..9 e letras T, I, O, em traços de lápis (x,y = canto superior esquerdo; h = altura)."""
    w = h * 0.62
    if ch == "6":
        f.linha([(x + w * 0.85, y + h * 0.02), (x + w * 0.25, y + h * 0.25), (x + w * 0.05, y + h * 0.6)], larg, 0.6, passes=1)
        f.elipse(x + w * 0.5, y + h * 0.68, w * 0.45, h * 0.3, larg, 0.6, passes=1)
    elif ch == "7":
        f.linha([(x, y + h * 0.04), (x + w, y), (x + w * 0.35, y + h)], larg, 0.6, passes=1)
    elif ch == "8":
        f.elipse(x + w * 0.5, y + h * 0.25, w * 0.38, h * 0.24, larg, 0.6, passes=1)
        f.elipse(x + w * 0.5, y + h * 0.72, w * 0.45, h * 0.28, larg, 0.6, passes=1)
    elif ch == "9":
        f.elipse(x + w * 0.5, y + h * 0.3, w * 0.45, h * 0.28, larg, 0.6, passes=1)
        f.linha([(x + w * 0.94, y + h * 0.3), (x + w * 0.9, y + h * 0.7), (x + w * 0.45, y + h)], larg, 0.6, passes=1)
    elif ch == "T":
        f.linha([(x - 1, y + 1), (x + w, y)], larg, 0.5, passes=1)
        f.linha([(x + w / 2, y), (x + w / 2 + 1, y + h)], larg, 0.5, passes=1)
    elif ch == "I":
        f.linha([(x + w * 0.3, y), (x + w * 0.3, y + h)], larg, 0.5, passes=1)
    elif ch == "O":
        f.elipse(x + w * 0.5, y + h * 0.5, w * 0.5, h * 0.5, larg, 0.6, passes=1)
    return w * 1.25 if ch not in "I" else w * 0.7


def marcas_altura(rng):
    """Batente de porta com riscos de lápis: TITO 6, 7, 8, 9, e depois nada. 384x512, opaca (é "um pedaço de
    batente com parede": o nível a cola na parede de 1975 e o Visor a mostra). Papel de parede desbotado dos anos 60,
    o batente de madeira à esquerda com os riscos, os números a lápis ao lado. Acima do último risco: nada."""
    W, H = 384, 512
    f = Folha(W, H, rng, papel=(206, 214, 188), amarelar=0.5, dureza=0.3)
    tela = f.tela
    yy, xx = np.mgrid[0:f.H, 0:f.W].astype(np.float32)
    mancha = fractal(rng, f.W, f.H, (150, 50, 14, 3), (0.35, 0.3, 0.2, 0.15))
    tela *= (0.86 + 0.24 * mancha)[..., None]
    # papel de parede: listras verdes desbotadas e uma florzinha repetida
    lista = (0.5 + 0.5 * np.sin(xx / (7.5 * SS)))
    tela *= (0.95 + 0.06 * lista)[..., None] * np.array([0.97, 1.0, 0.97], dtype=np.float32)
    px_, py_ = (xx / SS) % 46, (yy / SS) % 46
    flor = np.exp(-(((px_ - 23) ** 2 + (py_ - 23) ** 2) / 34.0)) + 0.6 * np.exp(-(((px_ - 0) ** 2 + (py_ - 0) ** 2) / 20.0))
    tela *= (1 - 0.10 * flor)[..., None] * np.array([1.0, 0.99, 1.02], dtype=np.float32)
    # umidade subindo do chão (embaixo) e uma mancha de goteira no alto à direita
    tela *= (1 - 0.14 * np.clip((yy / f.H - 0.8) * 5, 0, 1) * mancha)[..., None]
    rr = np.hypot(xx - f.W * 0.88, yy - f.H * 0.05)
    tela *= (1 - 0.18 * np.exp(-(rr / (90 * SS)) ** 2))[..., None] * np.array([1.0, 0.96, 0.85], dtype=np.float32)
    # batente de madeira (0..78 px), pintada de marrom velho, veios suaves e lascas de tinta clara
    larg_b = 78 * SS
    veio = np.asarray(Image.fromarray((ruido_2d(rng, f.W // 6, f.H // 2, 4) * 255).astype(np.uint8)).resize((f.W, f.H), Image.BICUBIC), dtype=np.float32) / 255
    lasca = (fractal(rng, f.W, f.H, (30, 9, 3), (0.4, 0.4, 0.2)) > 0.72).astype(np.float32)
    mad = np.array([116, 80, 50], dtype=np.float32)[None, None, :] * (0.85 + 0.25 * veio[..., None]) * (0.94 + 0.12 * mancha[..., None])
    mad = mad * (1 - 0.8 * lasca[..., None]) + np.array([186, 176, 150], dtype=np.float32) * 0.8 * lasca[..., None]
    mb = (xx < larg_b).astype(np.float32)
    sombra = np.clip(1 - np.abs(xx - larg_b) / (8 * SS), 0, 1) * (xx >= larg_b)
    tela = tela * (1 - mb[..., None]) + mad * mb[..., None]
    tela *= (1 - 0.32 * sombra)[..., None]
    f.tela = tela
    # riscos de lápis no batente (cada um com data embaixo, em traço fino) e o rótulo na parede, bem ao lado
    alturas = {6: 330, 7: 262, 8: 204, 9: 160}
    f.cor((52, 52, 62), 0.85)
    for idade, y in alturas.items():
        yb = y + rng.uniform(-2, 2)
        f.linha([(12, yb), (74, yb + rng.uniform(-2, 2))], 2.6, 0.6, passes=2)
        f.linha([(12, yb + 1.5), (54, yb + 1.5)], 1.4, 0.4, passes=1)   # o lápis volta e reforça
    rotulos = {6: "TITO 6", 7: "7", 8: "8", 9: "TITO 9"}
    for idade, y in alturas.items():
        x = 92
        for ch in rotulos[idade]:
            if ch == " ":
                x += 10
                continue
            x += _digito(f, ch, x + rng.uniform(-1, 1), y - 30 + rng.uniform(-2, 2), 30 + rng.uniform(-2, 2), 3.0)
    # a rachadura fina
    f.cor((88, 82, 66), 0.6)
    f.linha([(340, 0), (332, 60), (346, 130), (334, 210)], 1.6, 1.2, passes=1)
    return f.imagem()


def reduzir(img, cores=256):
    """Paleta de 256 cores com dithering: o PNG cai de ~400 KB para ~150 KB (o jogo vai para a web) e o ruído de giz
    esconde a quantização."""
    if img.mode == "RGBA":
        return img.quantize(colors=cores, method=Image.Quantize.FASTOCTREE, dither=Image.Dither.FLOYDSTEINBERG)
    return img.quantize(colors=cores, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.FLOYDSTEINBERG)


# ------------------------------------------------------------------ main
CATALOGO = {
    "desenho_1": (desenho_1, 101),
    "desenho_2": (desenho_2, 102),
    "desenho_3": (desenho_3, 103),
    "desenho_4": (desenho_4, 104),
    "desenho_5": (desenho_5, 105),
    "desenho_6": (desenho_6, 106),
    "desenho_7": (desenho_7, 107),
    "procura_se": (procura_se, 201),
    "marcas_altura": (marcas_altura, 301),
}


def main():
    os.makedirs(SAIDA, exist_ok=True)
    nomes = sys.argv[1:] or list(CATALOGO)
    for nome in nomes:
        fn, semente = CATALOGO[nome]
        img = fn(np.random.default_rng(semente))
        destino = os.path.join(SAIDA, nome + ".png")
        img = reduzir(img)
        img.save(destino, optimize=True)
        print(f"{os.path.relpath(destino, RAIZ):44s} {img.size[0]}x{img.size[1]} {os.path.getsize(destino) / 1024:6.1f} KB")


if __name__ == "__main__":
    main()
