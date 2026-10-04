#!/usr/bin/env python3
"""Gera as texturas PNG do Castelinho (próprias, sem assets de terceiros).

Uso:  python3 tools/gerar_texturas.py [nome ...]      (sem argumentos gera todas)
Saída: assets/textures/*.png   (256x256 ou 512x512, tileáveis, estilo low-poly/PS1 com pixels visíveis)

Escala física (para o jogo, uv1_scale = 1 / tamanho_em_metros):
  parede_castelinho*.png  1,48 m (largura) x 1,485 m (altura): 4 blocos de 35 cm (+2 cm de junta) x 11 fiadas de 13,5 cm
  parede_interna.png      idem (blocos mais claros e rosados, junta cinza grossa: fotos do interior)
  piso_pedra.png          2,0 m x 2,0 m    (cacos de pedra de ~35-45 cm)
  fibrocimento.png        1,416 m x 1,416 m (8 ondas de 17,7 cm)
  grama / areia / asfalto 2,0 m
  demais                  ver comentário de cada função
Depende só de numpy e Pillow (pip install numpy pillow).
"""
import math
import os
import sys

import numpy as np
from PIL import Image, ImageDraw, ImageFont

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SAIDA = os.path.join(RAIZ, "assets", "textures")


# ------------------------------------------------------------------ utilitários
def rng(seed):
    return np.random.default_rng(seed)


def hexa(h):
    h = h.lstrip("#")
    return np.array([int(h[i:i + 2], 16) for i in (0, 2, 4)], dtype=np.float64)


def ruido(w, h, cel, r, suave=False):
    """Ruído de valor tileável. `cel` = tamanho da célula em pixels. Blocos (nearest) por padrão: pixels visíveis."""
    gh, gw = max(1, h // cel), max(1, w // cel)
    g = r.random((gh, gw))
    if not suave:
        return np.kron(g, np.ones((math.ceil(h / gh), math.ceil(w / gw))))[:h, :w]
    ys = (np.arange(h) + 0.5) / h * gh
    xs = (np.arange(w) + 0.5) / w * gw
    y0 = np.floor(ys - 0.5).astype(int)
    x0 = np.floor(xs - 0.5).astype(int)
    fy = (ys - 0.5) - y0
    fx = (xs - 0.5) - x0
    y1, x1 = (y0 + 1) % gh, (x0 + 1) % gw
    y0, x0 = y0 % gh, x0 % gw
    a = g[np.ix_(y0, x0)]
    b = g[np.ix_(y0, x1)]
    c = g[np.ix_(y1, x0)]
    d = g[np.ix_(y1, x1)]
    fxm, fym = fx[None, :], fy[:, None]
    return (a * (1 - fxm) + b * fxm) * (1 - fym) + (c * (1 - fxm) + d * fxm) * fym


def fbm(w, h, r, celulas=(64, 32, 16, 8), pesos=None, suave=True):
    pesos = pesos or [1.0 / (i + 1) for i in range(len(celulas))]
    t = np.zeros((h, w))
    for c, p in zip(celulas, pesos):
        t += p * ruido(w, h, c, r, suave)
    return t / sum(pesos)


def quant(img, niveis=28):
    """Posteriza (retrô/PS1)."""
    n = niveis - 1
    return np.round(np.clip(img, 0, 255) / 255.0 * n) / n * 255.0


def salvar(nome, img, alfa=None):
    os.makedirs(SAIDA, exist_ok=True)
    a = np.clip(img, 0, 255).astype(np.uint8)
    if alfa is not None:
        a = np.dstack([a, np.clip(alfa, 0, 255).astype(np.uint8)])
        Image.fromarray(a, "RGBA").save(os.path.join(SAIDA, nome))
    else:
        Image.fromarray(a, "RGB").save(os.path.join(SAIDA, nome))
    print("  gerada:", nome, a.shape[1], "x", a.shape[0])


def voronoi(w, h, nx, ny, r, jitter=0.85):
    """Células de Voronoi tileáveis. Retorna (d1, d2, id) em pixels."""
    pts = []
    for j in range(ny):
        for i in range(nx):
            px = ((i + 0.5 + (r.random() - 0.5) * jitter) / nx) * w
            py = ((j + 0.5 + (r.random() - 0.5) * jitter) / ny) * h
            pts.append((px, py))
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    d1 = np.full((h, w), 1e9)
    d2 = np.full((h, w), 1e9)
    idx = np.zeros((h, w), dtype=np.int32)
    for k, (px, py) in enumerate(pts):
        for ox in (-w, 0, w):
            for oy in (-h, 0, h):
                d = np.hypot(xs - (px + ox), ys - (py + oy))
                menor = d < d1
                d2 = np.where(menor, d1, np.minimum(d2, d))
                idx = np.where(menor, k, idx)
                d1 = np.where(menor, d, d1)
    return d1, d2, idx


# ------------------------------------------------------------------ parede de blocos
# Cores medidas nas fotos (docs/pesquisa/refs): parede ao sol ~#C6AC95, à sombra/nublado ~#A88C7C (média com as
# juntas). O par da pesquisa (#A8583F a #C9806A) é o tom do bloco limpo; aqui os blocos ficam entre os dois
# (salmão-terroso, um pouco menos saturado que o tijolo de olaria) e a junta é clara e pouco contrastada.
def _parede_base(seed, w=256, h=256, fiadas=11, blocos=4, cor_a="#A35E4A", cor_b="#C98A74", cor_junta="#C7BBA6",
                 jh=3, jv=4, var_bloco=1.0):
    """Camada de blocos. Retorna (rgb, mascara_junta, indice_bloco) sem envelhecimento."""
    r = rng(seed)
    cor_a, cor_b = hexa(cor_a), hexa(cor_b)
    cor_junta = hexa(cor_junta)
    img = np.zeros((h, w, 3))
    junta = np.zeros((h, w), dtype=bool)
    bid = np.zeros((h, w), dtype=np.int32)
    lb = w // blocos
    n = 0
    for f in range(fiadas):
        y0 = round(f * h / fiadas)
        y1 = round((f + 1) * h / fiadas)
        off = int(r.choice([0, lb // 2, lb // 3, (2 * lb) // 3, lb // 4]))
        for k in range(blocos + 1):
            x0 = k * lb + off - lb
            x1 = x0 + lb
            t = 0.12 + 0.88 * r.random() ** 0.9
            base = cor_a * (1 - t) + cor_b * t
            base = base * (1.0 + var_bloco * (r.random() - 0.5) * 0.10)
            sorte = r.random()
            if sorte < 0.07:
                base = base * np.array([0.86, 0.84, 0.84])     # bloco mais queimado
            elif sorte < 0.13:
                base = base * np.array([1.04, 1.08, 1.1])      # bloco mais pálido (arenoso)
            n += 1
            for y in range(y0, y1):
                for xx in range(x0, x1):
                    xm = xx % w
                    borda_v = xx - x0 < jv // 2 or x1 - 1 - xx < (jv + 1) // 2
                    borda_h = y - y0 < jh // 2 + 1 or y1 - 1 - y < jh // 2 + 1
                    if borda_v or borda_h:
                        junta[y % h, xm] = True
                    else:
                        bid[y % h, xm] = n
                        # relevo suave: aresta de cima clara, de baixo escura
                        rel = 1.0
                        if y - y0 == jh // 2 + 1:
                            rel += 0.06
                        if y1 - 1 - y == jh // 2 + 1:
                            rel -= 0.08
                        img[y % h, xm] = base * rel
    # face rústica: manchas suaves (sem os "poros" de alto contraste, que viravam ruído na tela)
    manchas = fbm(w, h, r, (16, 8, 4), suave=True)
    grao = ruido(w, h, 1, r)
    img = img * (0.92 + 0.14 * manchas)[..., None]
    img = img * (0.96 + 0.08 * grao)[..., None]
    # pequenas cavidades da face rústica (poucas e de baixo contraste)
    cav = (ruido(w, h, 1, r) > 0.965)[..., None]
    img = np.where(cav, img * 0.88, img)
    # junta clara com pouco ruído e uma sombrinha sob o bloco
    jr = ruido(w, h, 2, r)
    cj = cor_junta[None, None, :] * (0.93 + 0.1 * jr[..., None])
    sombra = np.zeros((h, w))
    sombra[1:, :] = np.where(~junta[:-1, :] & junta[1:, :], 1.0, 0.0)
    cj = cj * (1 - 0.16 * sombra[..., None])
    img = np.where(junta[..., None], cj, img)
    return img, junta, bid


def parede_castelinho():
    img, _, _ = _parede_base(11)
    salvar("parede_castelinho.png", quant(img, 40))


def parede_interna():
    """Paredes internas: os mesmos blocos, mais claros e rosados, com junta cinza grossa (fotos do interior)."""
    img, _, _ = _parede_base(13, cor_a="#B98877", cor_b="#D7AE9C", cor_junta="#A39B90", jh=4, jv=5, var_bloco=0.8)
    salvar("parede_interna.png", quant(img, 40))


def parede_nucleo():
    """Núcleo de 1950 (foto antiga): os mesmos blocos, recém-assentados, mais pálidos e arenosos."""
    img, _, _ = _parede_base(17, cor_a="#A98A74", cor_b="#CDB39C", cor_junta="#D3CAB8", var_bloco=1.2)
    salvar("parede_nucleo.png", quant(img, 40))


def parede_musgo():
    """Versão 2019 (ruína): o mesmo bloco avermelhado, encardido, com escorridos, musgo no pé e líquen."""
    img, junta, _ = _parede_base(11)
    r = rng(77)
    h, w, _ = img.shape
    cinza = img.mean(axis=2, keepdims=True)
    img = img * 0.8 + cinza * 0.2               # dessatura pouco: o prédio continua vermelho na aérea de 2019
    img = img * 0.8
    # manchas escuras de umidade (escorridos verticais)
    esc = np.kron(r.random((1, w // 4)), np.ones((h, 4)))
    esc = esc * fbm(w, h, r, (64, 32), suave=True)
    img = img * (1.0 - 0.18 * np.clip((esc - 0.35) * 3.0, 0.0, 1.0))[..., None]
    # musgo verde-oliva: só em manchas, mais forte embaixo e nas juntas
    m = fbm(w, h, r, (48, 24, 12, 6))
    grad = np.linspace(0.0, 1.0, h)[:, None]
    grad = np.maximum(grad ** 3, (1 - grad) ** 6 * 0.7)
    mm = (m + grad * 0.22 + junta * 0.08) > 0.84
    verde = np.array([70, 82, 44]) * (0.85 + 0.35 * ruido(w, h, 2, r)[..., None])
    img = np.where(mm[..., None], img * 0.4 + verde * 0.6, img)
    # líquen claro
    liq = (ruido(w, h, 3, r) > 0.975)[..., None]
    img = np.where(liq, np.array([168, 172, 140]), img)
    salvar("parede_castelinho_musgo.png", quant(img, 32))


# ------------------------------------------------------------------ pisos
def piso_pedra():
    """Cacos de pedra (laje cinza-clara, levemente quente) com juntas claras: piso interno das fotos. Tile = 2,0 m."""
    r = rng(5)
    w = h = 256
    d1, d2, idx = voronoi(w, h, 6, 6, r)
    borda = (d2 - d1) * 0.5
    cores = []
    for _ in range(36 + 1):
        t = r.random()
        base = np.array([128, 124, 120]) * (1 - t) + np.array([164, 156, 146]) * t
        sorte = r.random()
        if sorte < 0.2:
            base = base * np.array([1.04, 0.98, 0.9])   # caco ferrugem
        elif sorte < 0.32:
            base = base * np.array([0.95, 0.97, 1.0])   # caco ardósia
        cores.append(base * (0.92 + 0.16 * r.random()))
    cores = np.array(cores)
    img = cores[idx]
    gr = (0.93 + 0.14 * fbm(w, h, r, (32, 8, 4), suave=True))[..., None]
    img = img * gr
    # relevo: borda do caco um pouco mais escura (laje assentada), meio plano
    img = np.where((borda < 6)[..., None], img * (0.86 + 0.14 * (borda / 6)[..., None]), img)
    junta = borda < 2.6
    cj = np.array([180, 174, 162])[None, None, :] * (0.88 + 0.16 * ruido(w, h, 2, r)[..., None])
    img = np.where(junta[..., None], cj, img)
    salvar("piso_pedra.png", quant(img, 32))


def calcada_lajotas():
    """Calçada de lajotas de pedra irregulares, claras. Tile = 2,0 m."""
    r = rng(9)
    w = h = 256
    d1, d2, idx = voronoi(w, h, 4, 4, r, 0.75)
    borda = (d2 - d1) * 0.5
    cores = []
    for _ in range(17):
        t = r.random()
        base = np.array([156, 150, 140]) * (1 - t) + np.array([176, 164, 150]) * t
        cores.append(base * (0.92 + 0.16 * r.random()))
    img = np.array(cores)[idx]
    img = img * (0.93 + 0.14 * fbm(w, h, r, (32, 8), suave=False))[..., None]
    img = np.where((borda < 6)[..., None], img * 0.9, img)
    junta = borda < 3.0
    mato = (ruido(w, h, 3, r) > 0.82) & (borda < 5)
    cj = np.array([112, 106, 96])[None, None, :] * (0.85 + 0.3 * ruido(w, h, 2, r)[..., None])
    cj = np.where(mato[..., None], np.array([76, 110, 52]), cj)
    img = np.where((junta | mato)[..., None], cj, img)
    salvar("calcada_lajotas.png", quant(img, 28))


# ------------------------------------------------------------------ madeiras
def _tabuas(w, h, n, vertical, cor_a, cor_b, r, gap=2, grao=0.12):
    """Tábuas retas. Retorna (img, mascara_gap, indice_tabua)."""
    img = np.zeros((h, w, 3))
    mask = np.zeros((h, w), dtype=bool)
    idx = np.zeros((h, w), dtype=np.int32)
    L = w if vertical else h
    for k in range(n):
        a, b = round(k * L / n), round((k + 1) * L / n)
        t = r.random()
        base = cor_a * (1 - t) + cor_b * t
        base = base * (0.9 + 0.2 * r.random())
        if vertical:
            img[:, a:b] = base
            mask[:, a:a + gap] = True
            idx[:, a:b] = k
        else:
            img[a:b, :] = base
            mask[a:a + gap, :] = True
            idx[a:b, :] = k
    # veios: ruído esticado ao longo da tábua
    g = ruido(w, h, 2, r)
    if vertical:
        g = np.kron(r.random((1, w // 2)), np.ones((h, 2))) * 0.5 + 0.5 * np.kron(r.random((h // 16, 1)), np.ones((16, w)))[:h, :w] * 0.3 + 0.2 * g
    else:
        g = np.kron(r.random((h // 2, 1)), np.ones((2, w))) * 0.5 + 0.5 * np.kron(r.random((1, w // 16)), np.ones((h, 16)))[:h, :w] * 0.3 + 0.2 * g
    img = img * (1 - grao + 2 * grao * g)[..., None]
    return img, mask, idx


def madeira_porta():
    """Tábuas verticais de madeira muito escura (portas) com pregos de ferro. Tile = 1,0 m."""
    r = rng(21)
    w = h = 256
    img, gap, idx = _tabuas(w, h, 8, True, hexa("#2E211B"), hexa("#4A3429"), r, gap=2, grao=0.18)
    img = np.where(gap[..., None], np.array([14, 10, 8]), img)
    # pregos: topo e base de cada tábua
    for k in range(8):
        cx = round((k + 0.5) * w / 8)
        for cy in (14, h - 14, h // 2):
            img[cy - 1:cy + 2, cx - 1:cx + 2] = np.array([96, 92, 88])
            img[cy - 1, cx - 1] = np.array([140, 136, 130])
    # duas travessas horizontais discretas
    for cy in (40, 216):
        img[cy:cy + 6, :] = img[cy:cy + 6, :] * 0.8 + np.array([20, 14, 10])
    salvar("madeira_porta.png", quant(img, 24))


def tabuas_claras():
    """Tábuas verticais de madeira mais clara (venezianas e porta do núcleo de 1950, foto antiga). Tile = 1,0 m."""
    r = rng(25)
    w = h = 128
    img, gap, idx = _tabuas(w, h, 6, True, hexa("#6B4A30"), hexa("#8C6544"), r, gap=2, grao=0.16)
    img = np.where(gap[..., None], np.array([36, 24, 16]), img)
    for cy in (12, h - 16):
        img[cy:cy + 5, :] = img[cy:cy + 5, :] * 0.82
    salvar("tabuas_claras.png", quant(img, 24))


def madeira_escura():
    """Madeira escura (vigas, caixilhos, venezianas), veio horizontal. Tile = 1,0 m."""
    r = rng(22)
    w = h = 256
    img, gap, idx = _tabuas(w, h, 4, False, hexa("#3B2A22"), hexa("#5A4034"), r, gap=1, grao=0.2)
    img = np.where(gap[..., None], np.array([20, 14, 12]), img)
    salvar("madeira_escura.png", quant(img, 24))


def forro_madeira():
    """Forro de madeira do teto (mais claro, tábuas horizontais). Tile = 1,5 m."""
    r = rng(23)
    w = h = 256
    img, gap, idx = _tabuas(w, h, 8, False, hexa("#7A5236"), hexa("#9A6C48"), r, gap=2, grao=0.14)
    img = np.where(gap[..., None], np.array([48, 32, 22]), img)
    salvar("forro_madeira.png", quant(img, 26))


def deck_madeira():
    """Deck do lounge externo (madeira avermelhada). Tile = 1,5 m."""
    r = rng(24)
    w = h = 256
    img, gap, idx = _tabuas(w, h, 8, False, hexa("#6B3B2A"), hexa("#8A5236"), r, gap=3, grao=0.16)
    img = np.where(gap[..., None], np.array([30, 18, 12]), img)
    salvar("deck_madeira.png", quant(img, 24))


# ------------------------------------------------------------------ coberturas e reboco
def fibrocimento():
    """Telha ondulada de fibrocimento cinza: 8 ondas de 17,7 cm. Tile = 1,416 m. Onda varia em U."""
    r = rng(31)
    w = h = 256
    xs = np.arange(w)[None, :].astype(np.float64)
    fase = 2 * math.pi * xs / (w / 8)
    onda = 0.5 + 0.5 * np.sin(fase + 0.9)
    sombra = 0.74 + 0.30 * onda
    base = hexa("#9A9A96")[None, None, :] * np.ones((h, w, 1))
    img = base * sombra[..., None]
    sujo = fbm(w, h, r, (128, 32, 8), suave=False)
    streak = np.kron(r.random((1, w // 3 + 1)), np.ones((h, 3)))[:, :w] * fbm(w, h, r, (64, 16), suave=True)
    img = img * (0.86 + 0.2 * sujo)[..., None]
    img = img * (1.0 - 0.12 * (streak > 0.55))[..., None]
    mancha = (fbm(w, h, r, (64, 32, 16)) > 0.72)[..., None]
    img = np.where(mancha, img * np.array([0.78, 0.86, 0.72]), img)   # líquen esverdeado
    # divisão entre chapas: linha horizontal a cada 128 px
    for cy in (0, 128):
        img[cy:cy + 2, :] = img[cy:cy + 2, :] * 0.62
    salvar("fibrocimento.png", quant(img, 28))


def _telhas(seed, base_a, base_b, w=256, h=256, fiadas=10, larg=32, musgo=0.0):
    r = rng(seed)
    img = np.zeros((h, w, 3))
    lh = h // fiadas
    for f in range(fiadas):
        off = (larg // 2) if f % 2 else 0
        for k in range(w // larg + 1):
            x0 = k * larg + off - larg
            t = r.random()
            base = base_a * (1 - t) + base_b * t
            base = base * (0.88 + 0.24 * r.random())
            for y in range(f * lh, (f + 1) * lh):
                v = (y - f * lh) / lh
                for xx in range(x0, x0 + larg):
                    jj = (xx - x0) < 2
                    cor = base * (0.62 + 0.5 * v) * (0.7 if jj else 1.0)
                    if v > 0.82:
                        cor = cor * 0.55       # sombra da telha de cima
                    img[y, xx % w] = cor
    g = ruido(w, h, 2, r)
    img = img * (0.9 + 0.2 * g)[..., None]
    if musgo > 0:
        m = fbm(w, h, r, (64, 32, 16)) > (1 - musgo)
        img = np.where(m[..., None], np.array([60, 74, 44]), img)
    return img


def telha_escura():
    """Cobertura piramidal das torres: telhas escuras, gastas. Tile = 1,0 m."""
    img = _telhas(41, hexa("#4E3F38"), hexa("#6E5A4C"), musgo=0.18)
    salvar("telha_escura.png", quant(img, 24))


def telha_ceramica():
    """Telhado cerâmico alaranjado das casas vizinhas. Tile = 1,0 m."""
    img = _telhas(42, hexa("#A0502D"), hexa("#C46A3A"))
    salvar("telha_ceramica.png", quant(img, 24))


def reboco():
    """Reboco/massa branca-suja (platibanda, casas vizinhas). Tile = 2,0 m."""
    r = rng(51)
    w = h = 256
    img = hexa("#E4DFD0")[None, None, :] * np.ones((h, w, 1))
    g = fbm(w, h, r, (64, 16, 4), suave=False)
    img = img * (0.88 + 0.16 * g)[..., None]
    manch = (fbm(w, h, r, (96, 32)) > 0.64)[..., None]
    img = np.where(manch, img * 0.86, img)
    salvar("reboco.png", quant(img, 30))


# ------------------------------------------------------------------ terreno
def grama():
    r = rng(61)
    w = h = 256
    base = hexa("#4F7D3A")
    g1 = fbm(w, h, r, (64, 32, 16, 8), suave=False)
    img = base[None, None, :] * (0.78 + 0.5 * g1)[..., None]
    tufos = (ruido(w, h, 4, r) > 0.80)[..., None]
    img = np.where(tufos, img * np.array([0.7, 0.82, 0.7]), img)
    flor = (ruido(w, h, 2, r) > 0.972)[..., None]
    img = np.where(flor, np.array([128, 168, 80]), img)
    seco = (fbm(w, h, r, (96, 48)) > 0.70)[..., None]
    img = np.where(seco, img * np.array([1.12, 1.0, 0.72]), img)
    salvar("grama.png", quant(img, 28))


def _areia(nome, seed, base, claro):
    r = rng(seed)
    w = h = 256
    g = fbm(w, h, r, (64, 32, 8), suave=False)
    # ondulações do vento (faixas horizontais ligeiramente inclinadas)
    ys = np.arange(h)[:, None]
    xs = np.arange(w)[None, :]
    ond = 0.5 + 0.5 * np.sin((ys + 6 * np.sin(xs / w * 2 * math.pi)) / h * 2 * math.pi * 7)
    img = base[None, None, :] * (0.86 + 0.14 * g + (0.06 if claro else 0.1) * ond)[..., None]
    grao = ruido(w, h, 1, r)
    img = np.where((grao > 0.93)[..., None], img * 1.12, img)
    img = np.where((grao < 0.05)[..., None], img * 0.85, img)
    salvar(nome, quant(img, 30))


def areia():
    _areia("areia.png", 71, hexa("#C8B48A"), False)


def areia_1950():
    """Areia mais clara e seca, do litoral de 1950 (sem cidade, só dunas)."""
    _areia("areia_1950.png", 72, hexa("#E0D2AC"), True)


def asfalto():
    r = rng(81)
    w = h = 256
    img = hexa("#3E3E42")[None, None, :] * (0.85 + 0.3 * fbm(w, h, r, (64, 16, 4), suave=False))[..., None]
    pedra = ruido(w, h, 1, r)
    img = np.where((pedra > 0.9)[..., None], img * 1.45, img)
    img = np.where((pedra < 0.06)[..., None], img * 0.7, img)
    # rachaduras
    for _ in range(3):
        x, y = int(r.integers(0, w)), int(r.integers(0, h))
        for _ in range(60):
            img[y % h, x % w] = img[y % h, x % w] * 0.55
            x += int(r.integers(-1, 2)) + 1
            y += int(r.integers(-1, 2))
    salvar("asfalto.png", quant(img, 28))


def folhagem():
    """Folhagem (agulhas de pinus em tufos; também arbustos, tingida por cor de vértice). Tile = 1,3 m."""
    r = rng(91)
    w = h = 128
    img = hexa("#3C5E42")[None, None, :] * (0.7 + 0.5 * fbm(w, h, r, (16, 8, 4), suave=False))[..., None]
    # tufos de agulhas: traços curtos claros e escuros
    for _ in range(420):
        x, y = int(r.integers(0, w)), int(r.integers(0, h))
        dx, dy = (1, 0) if r.random() < 0.5 else (1, 1 if r.random() < 0.5 else -1)
        cor = np.array([96, 130, 88]) if r.random() < 0.55 else np.array([26, 44, 32])
        for k in range(int(r.integers(2, 5))):
            img[(y + dy * k) % h, (x + dx * k) % w] = cor * (0.9 + 0.2 * r.random())
    salvar("folhagem.png", quant(img, 24))


def casca():
    """Casca de pinheiro (tronco). Tile = 1,0 m."""
    r = rng(92)
    w = h = 128
    col = np.kron(r.random((1, w // 4)), np.ones((h, 4)))
    img = hexa("#5B4130")[None, None, :] * (0.6 + 0.6 * (0.6 * col + 0.4 * fbm(w, h, r, (32, 8), suave=False)))[..., None]
    for y in range(0, h, 12):
        img[y:y + 1, :] = img[y:y + 1, :] * 0.6
    salvar("casca.png", quant(img, 22))


# ------------------------------------------------------------------ texturas com transparência
def grade_losango():
    """Grade de ferro em losango (janelas). RGBA. Tile = 1 janela (0,9 x 1,4 m)."""
    w, h = 128, 128
    img = np.zeros((h, w, 3)) + np.array([20, 18, 18])
    alfa = np.zeros((h, w))
    n = 4
    for i in range(-n, n + 1):
        for off in (0, 1):
            pass
    ys, xs = np.mgrid[0:h, 0:w]
    passo = w // n
    d1 = np.abs(((xs + ys) % passo) - passo / 2)
    d2 = np.abs(((xs - ys) % passo) - passo / 2)
    barra = (d1 > passo / 2 - 2) | (d2 > passo / 2 - 2)
    alfa[barra] = 255
    # moldura
    alfa[:3, :] = 255
    alfa[-3:, :] = 255
    alfa[:, :3] = 255
    alfa[:, -3:] = 255
    img = img * (0.9 + 0.2 * ruido(w, h, 2, rng(1))[..., None])
    salvar("grade_losango.png", img, alfa)


def veneziana():
    """Veneziana de madeira escura com recorte em losango no alto. RGBA. Tile = 1 folha (0,45 x 1,5 m)."""
    r = rng(2)
    w, h = 64, 128
    img = hexa("#3B2A22")[None, None, :] * np.ones((h, w, 1))
    ys = np.arange(h)[:, None]
    ripa = (ys % 6) < 2
    img = np.where(ripa[..., None] * np.ones((1, w, 1), dtype=bool), img * 0.55, img * (0.85 + 0.3 * ruido(w, h, 2, r)[..., None]))
    alfa = np.full((h, w), 255.0)
    # losango recortado no alto
    cx, cy, rad = w // 2, 18, 11
    yy, xx = np.mgrid[0:h, 0:w]
    losango = (np.abs(xx - cx) + np.abs(yy - cy)) < rad
    alfa[losango] = 0
    img[:3, :] = img[:3, :] * 0.6
    img[-3:, :] = img[-3:, :] * 0.6
    img[:, :3] = img[:, :3] * 0.6
    img[:, -3:] = img[:, -3:] * 0.6
    salvar("veneziana.png", quant(img, 24), alfa)


def letreiro_castelinho():
    """Letreiro 'Castelinho' em letras brancas (metal aplicado), estilo gótico simplificado. RGBA 512x128."""
    w, h = 512, 128
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    fonte = None
    for caminho in ("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", "/usr/share/fonts/truetype/freefont/FreeSerifBold.ttf"):
        if os.path.exists(caminho):
            fonte = ImageFont.truetype(caminho, 92)
            # maior fonte que cabe em 96% da largura (na foto as letras ocupam a placa toda)
            for tam in range(130, 60, -2):
                f2 = ImageFont.truetype(caminho, tam)
                bb2 = d.textbbox((0, 0), "Castelinho", font=f2)
                if bb2[2] - bb2[0] <= w * 0.96 and bb2[3] - bb2[1] <= h * 0.86:
                    fonte = f2
                    break
            break
    if fonte is None:
        fonte = ImageFont.load_default(size=80)
    texto = "Castelinho"
    bb = d.textbbox((0, 0), texto, font=fonte)
    x = (w - (bb[2] - bb[0])) // 2 - bb[0]
    y = (h - (bb[3] - bb[1])) // 2 - bb[1]
    d.text((x + 5, y + 5), texto, font=fonte, fill=(40, 30, 28, 220))   # sombra (letras de metal afastadas da parede)
    d.text((x, y), texto, font=fonte, fill=(244, 244, 238, 255))
    # pixelização leve: reduz e amplia
    im = im.resize((w // 2, h // 2), Image.NEAREST).resize((w, h), Image.NEAREST)
    os.makedirs(SAIDA, exist_ok=True)
    im.save(os.path.join(SAIDA, "letreiro_castelinho.png"))
    print("  gerada: letreiro_castelinho.png 512 x 128")


def mural_pescador():
    """Mural da Sala do Pescador: barco ao pôr do sol (genérico, pintado à mão). 512x256."""
    r = rng(3)
    w, h = 512, 256
    img = np.zeros((h, w, 3))
    hor = 150
    for y in range(h):
        if y < hor:
            t = y / hor
            topo, meio, base = hexa("#7FA6C8"), hexa("#E8D8C0"), hexa("#F08A24")
            if t < 0.55:
                c = topo * (1 - t / 0.55) + meio * (t / 0.55)
            else:
                c = meio * (1 - (t - 0.55) / 0.45) + base * ((t - 0.55) / 0.45)
            img[y, :] = c
        else:
            t = (y - hor) / (h - hor)
            img[y, :] = hexa("#6E88A8") * (1 - t) + hexa("#46607E") * t
    # nuvens
    n = fbm(w, h, r, (64, 32, 16), suave=True)
    nuvem = (n > 0.58) & (np.arange(h)[:, None] < hor - 20)
    img = np.where(nuvem[..., None], img * 0.4 + np.array([255, 255, 255]) * 0.6, img)
    # ondas
    for y in range(hor + 6, h, 7):
        for x in range(0, w, 18):
            xx = x + int(r.integers(0, 10))
            img[y, xx:xx + 8] = img[y, xx:xx + 8] * 0.7 + np.array([255, 255, 255]) * 0.3
    # barco + pescador (silhueta)
    im = Image.fromarray(np.clip(img, 0, 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(im)
    d.polygon([(40, 178), (170, 168), (200, 150), (190, 186), (60, 204)], fill=(24, 22, 28))
    d.polygon([(110, 168), (118, 120), (126, 100), (136, 104), (134, 124), (146, 168)], fill=(24, 22, 28))   # corpo
    d.ellipse((118, 90, 134, 104), fill=(24, 22, 28))
    d.polygon([(108, 94), (146, 94), (138, 88), (116, 88)], fill=(24, 22, 28))                               # chapéu
    d.line([(134, 112), (172, 100)], fill=(24, 22, 28), width=4)                                            # braço lançando a tarrafa
    d.line([(172, 100), (230, 70)], fill=(60, 60, 70), width=1)
    d.arc((170, 60, 260, 130), 200, 300, fill=(60, 60, 70), width=1)
    try:
        fonte = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 22)
        d.text((330, 96), "Castelinho", font=fonte, fill=(20, 20, 24))
        fonte2 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSerif-Bold.ttf", 15)
        d.text((350, 122), "Imbé/RS", font=fonte2, fill=(20, 20, 24))
    except OSError:
        pass
    im = im.resize((w // 2, h // 2), Image.NEAREST).resize((w, h), Image.NEAREST)   # pixels visíveis
    os.makedirs(SAIDA, exist_ok=True)
    im.save(os.path.join(SAIDA, "mural_pescador.png"))
    print("  gerada: mural_pescador.png 512 x 256")


def banner_ambiental():
    """Banner enrolável genérico de educação ambiental (Meio Ambiente): céu, sol, folha, ondas e faixas de
    texto (sem texto legível nem marcas reais). 64x128, pixels visíveis."""
    w, h = 64, 128
    im = Image.new("RGB", (w, h), (236, 244, 250))
    d = ImageDraw.Draw(im)
    for y in range(0, 56):
        t = y / 56
        d.line([(0, y), (w, y)], fill=(int(150 + 80 * t), int(205 + 30 * t), int(240 + 10 * t)))
    d.ellipse((14, 14, 50, 50), fill=(250, 250, 245), outline=(40, 120, 70), width=3)
    d.polygon([(32, 20), (44, 32), (32, 44), (20, 32)], fill=(70, 170, 80))
    d.line([(32, 22), (32, 42)], fill=(30, 100, 50), width=1)
    for k, cor in enumerate([(60, 140, 220), (40, 110, 200), (30, 80, 170)]):
        y0 = 58 + k * 8
        for x in range(0, w, 2):
            yy = y0 + int(2.5 * math.sin(x / 6.0 + k))
            d.line([(x, yy), (x, yy + 6)], fill=cor)
    for k in range(5):
        y = 90 + k * 6
        d.rectangle((8, y, 8 + (48 if k % 2 == 0 else 36), y + 2), fill=(70, 80, 100))
    d.rectangle((0, 0, w - 1, h - 1), outline=(200, 205, 210))
    os.makedirs(SAIDA, exist_ok=True)
    im.save(os.path.join(SAIDA, "banner_ambiental.png"))
    print("  gerada: banner_ambiental.png 64 x 128")


# ------------------------------------------------------------------ céu
def nuvens():
    """Nuvens de desenho para o céu (shaders/ceu_nuvens.gdshader). Tileável 256x256.
    R = densidade (o shader corta num limiar: borda dura), G = luz (núcleo claro, borda escura). Tons chapados."""
    r = rng(101)
    w = h = 256
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    campo = np.zeros((h, w))
    for _ in range(16):
        cx, cy = r.random() * w, r.random() * h
        larg = r.uniform(18, 40)
        for _ in range(int(r.integers(4, 8))):
            px = cx + r.normal(0, larg * 0.6)
            py = cy + r.normal(0, larg * 0.25)
            rad = r.uniform(9, 24)
            dx = np.abs(xs - px)
            dx = np.minimum(dx, w - dx)
            dy = np.abs(ys - py)
            dy = np.minimum(dy, h - dy)
            v = np.clip(1.0 - (dx * dx + dy * dy) / (rad * rad), 0.0, 1.0)
            campo = np.maximum(campo, v)
    ru = fbm(w, h, r, (32, 16, 8), suave=True)
    dens = np.clip(campo * 0.85 + (ru - 0.5) * 0.3 + 0.12, 0.0, 1.0)
    luz = np.clip((dens - 0.5) * 2.4 + (ru - 0.5) * 0.25, 0.0, 1.0)
    img = np.dstack([dens * 255, luz * 255, np.zeros((h, w))])
    salvar("nuvens.png", img)


TODAS = [
    parede_castelinho, parede_interna, parede_nucleo, parede_musgo, piso_pedra, calcada_lajotas, madeira_porta, madeira_escura,
    forro_madeira, deck_madeira, fibrocimento, telha_escura, telha_ceramica, reboco, grama, areia,
    areia_1950, asfalto, folhagem, casca, grade_losango, veneziana, letreiro_castelinho, mural_pescador,
    nuvens, banner_ambiental, tabuas_claras,
]


def main():
    nomes = sys.argv[1:]
    for f in TODAS:
        if not nomes or f.__name__ in nomes:
            f()


if __name__ == "__main__":
    main()
