#!/usr/bin/env python3
"""Sintetiza TODOS os sons do jogo (nada de arquivos de terceiros).

Uso:  python3 tools/gerar_audio.py            # gera tudo em assets/audio/
      python3 tools/gerar_audio.py clique acerto   # só alguns

Requisitos: numpy (pip install numpy). Se o `ffmpeg` existir, sons longos (jingles e
ambientes em loop) saem em .ogg (bem menores); senão ficam em .wav.
Formato: mono, 22050 Hz, 16 bits. Sons curtos e leves (o jogo roda no navegador).

Os jingles são pré-renderizados em 3 versões porque o modo "Sample" do áudio na web não
aceita efeitos de bus (pitch/distorção em tempo real). O Audio.gd troca entre elas conforme
GameState.corruption:  jingle_0 (normal) -> jingle_1 (meio tom abaixo, mais lento, um
instrumento a menos) -> jingle_2 (desafinado, lento, com ruído).
"""
import os
import shutil
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 22050
RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
SAIDA = os.path.join(RAIZ, "assets", "audio")
RNG = np.random.default_rng(20201223)  # 23/12/2020: determinístico, os arquivos não mudam a cada rodada


# ------------------------------------------------------------------ utilidades
def tt(dur):
    return np.arange(int(dur * SR)) / SR


def midi(n):
    return 440.0 * 2 ** ((np.asarray(n, dtype=float) - 69) / 12)


def ruido(dur):
    return RNG.uniform(-1, 1, int(dur * SR))


def fade(x, ini=0.002, fim=0.004):
    x = x.copy()
    a, b = int(ini * SR), int(fim * SR)
    if a > 0 and len(x) > a:
        x[:a] *= np.linspace(0, 1, a)
    if b > 0 and len(x) > b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def filtro(x, tipo, fc, fc2=None, ordem=2):
    """Filtro por FFT (fase zero). tipo: 'baixa', 'alta', 'banda' (fc..fc2). Circular: bom para loops."""
    n = len(x)
    f = np.fft.rfftfreq(n, 1 / SR)
    f[0] = 1e-6
    if tipo == "baixa":
        h = 1 / (1 + (f / fc) ** (2 * ordem))
    elif tipo == "alta":
        h = (f / fc) ** (2 * ordem) / (1 + (f / fc) ** (2 * ordem))
    else:
        h = (1 / (1 + (f / fc2) ** (2 * ordem))) * ((f / fc) ** (2 * ordem) / (1 + (f / fc) ** (2 * ordem)))
    return np.fft.irfft(np.fft.rfft(x) * h, n)


def fase(freq):
    """Integra uma frequência (escalar ou array) em fase."""
    return 2 * np.pi * np.cumsum(freq) / SR


def normalizar(x, pico=0.85):
    m = np.max(np.abs(x))
    return x * (pico / m) if m > 0 else x


def salvar_wav(caminho, x):
    x = np.clip(x, -1, 1)
    dados = (x * 32767).astype("<i2")
    with wave.open(caminho, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(dados.tobytes())


# ------------------------------------------------------------------ instrumentos
def marimba(freq, dur=0.5, brilho=1.0):
    t = tt(dur + 0.25)
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.30)
    y += 0.40 * brilho * np.sin(2 * np.pi * freq * 4.0 * t) * np.exp(-t / 0.07)
    y += 0.12 * brilho * np.sin(2 * np.pi * freq * 9.4 * t) * np.exp(-t / 0.025)
    return fade(y, 0.002, 0.03)


def xilofone(freq, dur=0.3):
    t = tt(dur + 0.2)
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.14)
    y += 0.5 * np.sin(2 * np.pi * freq * 3.0 * t) * np.exp(-t / 0.06)
    y += 0.2 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.03)
    return fade(y, 0.001, 0.03)


def sino(freq, dur=0.8):
    t = tt(dur)
    y = np.sin(2 * np.pi * freq * t) * np.exp(-t / 0.35)
    y += 0.5 * np.sin(2 * np.pi * freq * 2.76 * t) * np.exp(-t / 0.2)
    y += 0.25 * np.sin(2 * np.pi * freq * 5.4 * t) * np.exp(-t / 0.1)
    return fade(y, 0.001, 0.02)


def baixo(freq, dur=0.3):
    t = tt(dur + 0.1)
    tri = (2 / np.pi) * np.arcsin(np.sin(2 * np.pi * freq * t))
    y = (tri + 0.25 * np.sin(2 * np.pi * freq * 2 * t)) * np.exp(-t / 0.18)
    return fade(y, 0.004, 0.04)


def pizz(freq, dur=0.15):
    t = tt(dur + 0.08)
    tri = (2 / np.pi) * np.arcsin(np.sin(2 * np.pi * freq * t))
    return fade(tri * np.exp(-t / 0.07), 0.002, 0.02)


def toquinho():
    t = tt(0.08)
    y = np.sin(2 * np.pi * 1750 * t) * np.exp(-t / 0.012) + 0.4 * filtro(ruido(0.08), "banda", 1500, 4000) * np.exp(-t / 0.006)
    return fade(y, 0.0005, 0.01)


def chocalho():
    t = tt(0.07)
    return fade(filtro(ruido(0.07), "alta", 5000) * np.exp(-t / 0.02), 0.001, 0.01)


def serra(freq, t, harmonicos=8):
    y = np.zeros_like(t)
    for k in range(1, harmonicos + 1):
        y += np.sin(2 * np.pi * freq * k * t) / k
    return y * (2 / np.pi)


def colocar(buf, x, pos_s, ganho=1.0):
    i = int(pos_s * SR)
    if i >= len(buf):
        return
    n = min(len(x), len(buf) - i)
    buf[i:i + n] += x[:n] * ganho


# ------------------------------------------------------------------ efeitos de interface
def s_clique():
    t = tt(0.07)
    f = 1100 * np.exp(-t * 14)
    y = np.sin(fase(f)) * np.exp(-t / 0.022) + 0.35 * ruido(0.07) * np.exp(-t / 0.002)
    return y


def s_boing():
    t = tt(0.4)
    ph = 2 * np.pi * 330 * t + 7 * np.sin(2 * np.pi * 13 * t) * np.exp(-t / 0.16)
    return np.sin(ph) * np.exp(-t / 0.15)


def s_blip_bentinho():
    t = tt(0.055)
    y = (2 / np.pi) * np.arcsin(np.sin(2 * np.pi * 690 * t)) + 0.3 * np.sin(2 * np.pi * 1380 * t)
    return y * np.exp(-t / 0.022)


def s_blip_taina():
    t = tt(0.07)
    f = 480 + 520 * (t / 0.07) ** 0.7
    return np.sin(fase(f)) * np.exp(-t / 0.03)


def s_blip_quico():
    t = tt(0.07)
    f = 1700 + 700 * (t / 0.07) + 90 * np.sin(2 * np.pi * 55 * t)
    return (np.sin(fase(f)) + 0.2 * np.sin(2 * fase(f))) * np.exp(-t / 0.028)


def s_blip_sistema():
    t = tt(0.04)
    return (0.6 * np.sin(2 * np.pi * 1250 * t) + 0.5 * filtro(ruido(0.04), "alta", 2500)) * np.exp(-t / 0.01)


def s_blip_misterio():
    t = tt(0.09)
    y = serra(78, t, 6) + 0.3 * filtro(ruido(0.09), "baixa", 600)
    return y * np.exp(-t / 0.05)


def s_acerto():
    buf = np.zeros(int(1.2 * SR))
    for i, n in enumerate((72, 76, 79, 84)):
        colocar(buf, marimba(midi(n), 0.25), i * 0.085, 0.8)
        colocar(buf, sino(midi(n + 12), 0.3), i * 0.085, 0.4)
    for n in (84, 88, 91):
        colocar(buf, sino(midi(n), 0.7), 0.34, 0.35)
    return buf


def s_erro():
    t1, t2 = tt(0.16), tt(0.3)
    a = np.sign(np.sin(2 * np.pi * 220 * t1)) * np.exp(-t1 / 0.2)
    b = np.sign(np.sin(2 * np.pi * 156 * t2)) * (0.8 + 0.2 * np.sin(2 * np.pi * 30 * t2)) * np.exp(-t2 / 0.18)
    y = np.concatenate([fade(a), fade(b)])
    return filtro(y, "baixa", 1400)


def s_selo():
    buf = np.zeros(int(1.4 * SR))
    t = tt(0.12)
    colocar(buf, np.sin(fase(160 * np.exp(-t * 12))) * np.exp(-t / 0.05) * 1.2, 0.0)
    for i, n in enumerate((84, 86, 88, 91, 96)):
        colocar(buf, sino(midi(n), 0.55), 0.1 + i * 0.065, 0.5)
    colocar(buf, sino(midi(96), 0.9) + 0.6 * sino(midi(103), 0.9), 0.45, 0.6)
    return buf


def s_confete():
    buf = np.zeros(int(1.0 * SR))
    t = tt(0.25)
    pop = filtro(ruido(0.25), "baixa", 3200) * np.exp(-t / 0.03) * 1.3
    pop += np.sin(fase(240 * np.exp(-t * 18))) * np.exp(-t / 0.04)
    colocar(buf, pop, 0.0)
    brilho = filtro(ruido(0.9), "alta", 4200) * np.exp(-tt(0.9) / 0.25) * 0.25
    colocar(buf, brilho, 0.03)
    for _ in range(22):
        dur = RNG.uniform(0.04, 0.09)
        f = RNG.uniform(3000, 6500)
        tin = np.sin(2 * np.pi * f * tt(dur)) * np.exp(-tt(dur) / 0.02)
        colocar(buf, tin, RNG.uniform(0.04, 0.85), RNG.uniform(0.1, 0.3))
    return buf


def s_fanfarra():
    buf = np.zeros(int(2.8 * SR))

    def metal(freq, dur, ganho):
        t = tt(dur + 0.2)
        y = serra(freq, t, 10) + serra(freq * 1.004, t, 10)
        env = np.minimum(1, t / 0.02) * np.exp(-np.maximum(0, t - dur) / 0.08)
        return filtro(y * env, "baixa", 3200) * ganho

    ritmo = ((0.0, (67, 72, 76), 0.18), (0.22, (67, 72, 76), 0.18), (0.44, (67, 72, 76), 0.18),
             (0.7, (69, 74, 77), 0.18), (0.95, (71, 74, 79), 1.6))
    for ini, acorde, dur in ritmo:
        for n in acorde:
            colocar(buf, metal(midi(n), dur, 0.35), ini)
    for i, n in enumerate((84, 88, 91, 96)):
        colocar(buf, sino(midi(n), 0.6), 1.0 + i * 0.07, 0.25)
    return buf


def passo(grave, brilho, seed):
    r = np.random.default_rng(seed)
    t = tt(0.22)
    thump = np.sin(fase(grave * np.exp(-t * 22))) * np.exp(-t / 0.04)
    sopro = filtro(r.uniform(-1, 1, len(t)), "banda", 250, brilho) * np.exp(-t / 0.035) * 1.1
    y = thump * 1.2 + sopro
    y = np.concatenate([y, np.zeros(int(0.12 * SR))])
    y2 = y.copy()
    k = int(0.045 * SR)
    y2[k:] += 0.22 * y[:-k]  # eco curto de piso de pedra
    return y2


def s_ofego():
    n = 1.1
    t = tt(n)
    env = np.where(t < 0.4, (t / 0.4) ** 1.5, np.exp(-(t - 0.4) / 0.28)) * (1 + 0.2 * np.sin(2 * np.pi * 6 * t))
    return filtro(ruido(n), "banda", 350, 2400) * env * 1.4


def s_susto():
    buf = np.zeros(int(1.2 * SR))
    t = tt(1.1)
    for f in (1244.5, 1318.5, 1760.0, 2093.0, 2637.0):
        vib = 1 + 0.01 * np.sin(2 * np.pi * 7 * t)
        colocar(buf, serra(f, t, 6) * vib * np.exp(-t / 0.5) * 0.18, 0.0)
    colocar(buf, filtro(ruido(0.25), "alta", 1200) * np.exp(-tt(0.25) / 0.05) * 0.8, 0.0)
    tb = tt(0.4)
    colocar(buf, np.sin(fase(110 * np.exp(-tb * 5))) * np.exp(-tb / 0.12) * 0.9, 0.0)
    return buf


def s_apito():
    n = 0.62
    t = tt(n)
    f = 2900 + 70 * np.sin(2 * np.pi * 22 * t)
    y = np.sin(fase(f)) * (0.6 + 0.4 * np.sin(2 * np.pi * 34 * t))
    y += 0.35 * filtro(ruido(n), "alta", 3000)
    env = np.minimum(1, t / 0.015) * np.where(t > 0.5, np.exp(-(t - 0.5) / 0.03), 1.0)
    return y * env


def s_telefone():
    buf = np.zeros(int(2.1 * SR))

    def toque(dur):
        t = tt(dur)
        alt = (np.sin(2 * np.pi * 22 * t) > 0).astype(float)
        y = alt * (np.sin(2 * np.pi * 1480 * t) + 0.5 * np.sin(2 * np.pi * 2960 * t)) \
            + (1 - alt) * (np.sin(2 * np.pi * 1180 * t) + 0.5 * np.sin(2 * np.pi * 2360 * t))
        return fade(y * 0.5, 0.01, 0.02)

    colocar(buf, toque(0.42), 0.0)
    colocar(buf, toque(0.42), 0.62)
    return buf


def s_porta():
    n = 1.5
    t = tt(n)
    f = 95 + 90 * np.sin(np.pi * np.clip(t / 0.95, 0, 1)) + 14 * np.sin(2 * np.pi * 9 * t)
    ranger = serra(1, fase(f) / (2 * np.pi), 10) * np.where(t < 0.95, np.sin(np.pi * np.clip(t / 0.95, 0, 1)) ** 0.6, 0)
    ranger = filtro(ranger + 0.3 * filtro(ruido(n), "banda", 400, 1800), "banda", 120, 2200) * 0.6
    y = ranger.copy()
    tb = tt(0.3)
    batida = (np.sin(fase(90 * np.exp(-tb * 14))) * np.exp(-tb / 0.07) + 0.5 * filtro(ruido(0.3), "baixa", 500) * np.exp(-tb / 0.05)) * 1.1
    colocar(y, batida, 1.0)
    return y


def s_vento():
    dur = 8.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = filtro(ruido(dur), "banda", 120, 900)
    alto = filtro(ruido(dur), "banda", 700, 2600)
    lfo1 = 0.55 + 0.45 * np.sin(2 * np.pi * (2 / dur) * t + 0.4)
    lfo2 = 0.5 + 0.5 * np.sin(2 * np.pi * (3 / dur) * t + 2.1)
    lfo3 = 0.5 + 0.5 * np.sin(2 * np.pi * (5 / dur) * t + 4.0)
    return base * lfo1 * 1.2 + alto * (lfo2 * lfo3) * 0.55


def s_mar():
    dur = 10.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    grave = filtro(ruido(dur), "baixa", 700)
    onda = (0.5 + 0.5 * np.sin(2 * np.pi * (2 / dur) * t - 1.0)) ** 2
    espuma = filtro(ruido(dur), "banda", 1500, 6000)
    crista = (0.5 + 0.5 * np.sin(2 * np.pi * (2 / dur) * t - 0.2)) ** 6
    return grave * (0.25 + onda) * 1.3 + espuma * crista * 0.45


def s_rio():
    dur = 8.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    corrente = filtro(ruido(dur), "banda", 250, 1800) * (0.7 + 0.3 * np.sin(2 * np.pi * (4 / dur) * t))
    borbulhas = np.zeros(n)
    for _ in range(40):
        d = RNG.uniform(0.04, 0.09)
        f0 = RNG.uniform(400, 900)
        tb = tt(d)
        b = np.sin(fase(f0 * (1 + 2.5 * tb / d))) * np.exp(-tb / 0.02)
        colocar(borbulhas, b, RNG.uniform(0, dur - 0.1), RNG.uniform(0.05, 0.2))
    return corrente + borbulhas


def s_agua_puxa():
    dur = 2.8
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    for fc, centro in ((3200, 0.25), (1600, 0.6), (800, 1.0), (400, 1.5), (200, 2.0)):
        banda = filtro(ruido(dur), "banda", fc * 0.5, fc * 1.4)
        y += banda * np.exp(-((t - centro) ** 2) / 0.12) * 1.1
    for _ in range(30):
        d = RNG.uniform(0.05, 0.12)
        tb = tt(d)
        f0 = RNG.uniform(200, 450)
        b = np.sin(fase(f0 * (1 + 1.8 * tb / d))) * np.exp(-tb / 0.03)
        colocar(y, b, RNG.uniform(0.1, 2.3), RNG.uniform(0.1, 0.3))
    return y * np.minimum(1, (dur - t) / 0.5)


def s_chiado_radio():
    dur = 1.8
    n = int(dur * SR)
    t = np.arange(n) / SR
    lento = np.interp(t, np.linspace(0, dur, 18), RNG.uniform(0.3, 1.0, 18))
    y = filtro(ruido(dur), "banda", 300, 3600) * lento
    for _ in range(60):
        pos = int(RNG.uniform(0, n - 40))
        y[pos:pos + 3] += RNG.uniform(-1, 1) * 1.2
    for ini, f0, f1 in ((0.35, 700, 1900), (1.1, 2200, 900)):
        tb = tt(0.28)
        y_ = np.sin(fase(np.linspace(f0, f1, len(tb)))) * np.sin(np.pi * tb / 0.28) * 0.25
        colocar(y, y_, ini)
    return y


def s_glitch():
    dur = 0.28
    n = int(dur * SR)
    y = np.zeros(n)
    pos = 0
    while pos < n:
        d = int(RNG.uniform(0.01, 0.045) * SR)
        f = RNG.uniform(120, 2400)
        tb = np.arange(min(d, n - pos)) / SR
        seg = np.sign(np.sin(2 * np.pi * f * tb)) if RNG.random() < 0.6 else RNG.uniform(-1, 1, len(tb))
        y[pos:pos + len(tb)] = seg * RNG.uniform(0.3, 1.0)
        pos += d
    return y


def s_slide():
    """Visor do Tempo (estilo View-Master): troca de slide, dois cliques de plástico com mola."""
    buf = np.zeros(int(0.32 * SR))
    for ini, f in ((0.0, 190), (0.085, 250)):
        t = tt(0.05)
        thunk = np.sin(fase(f * np.exp(-t * 30))) * np.exp(-t / 0.015)
        click = filtro(ruido(0.05), "banda", 1500, 5200) * np.exp(-t / 0.005)
        colocar(buf, thunk * 0.9 + click * 0.9, ini)
    t = tt(0.1)
    colocar(buf, filtro(ruido(0.1), "banda", 2000, 6000) * np.sin(np.pi * t / 0.1) * 0.25, 0.04)
    return buf


def s_sussurro():
    """Sussurro (Figura Branca): ruído chiado com sílabas lentas, quase sem tom."""
    dur = 1.9
    n = int(dur * SR)
    t = np.arange(n) / SR
    a = filtro(ruido(dur), "banda", 1800, 5200)
    b = filtro(ruido(dur), "banda", 700, 2000)
    silabas = np.clip(np.sin(2 * np.pi * 3.1 * t + 0.6), 0, 1) ** 1.5 + 0.35 * np.clip(np.sin(2 * np.pi * 1.3 * t), 0, 1)
    formante = 0.5 + 0.5 * np.sin(2 * np.pi * 0.9 * t)
    y = (a * formante + b * (1 - formante)) * silabas
    y *= np.minimum(1, t / 0.2) * np.minimum(1, (dur - t) / 0.4)
    return y


def s_splash():
    dur = 1.0
    t = tt(dur)
    y = filtro(ruido(dur), "baixa", 4500) * np.exp(-t / 0.12) * 1.2
    y += filtro(ruido(dur), "banda", 800, 3000) * np.exp(-t / 0.4) * 0.35
    for _ in range(14):
        d = RNG.uniform(0.04, 0.09)
        tb = tt(d)
        f0 = RNG.uniform(500, 1200)
        colocar(y, np.sin(fase(f0 * (1 + 2.2 * tb / d))) * np.exp(-tb / 0.02), RNG.uniform(0.05, 0.7), RNG.uniform(0.08, 0.22))
    return y


def s_tarrafa():
    """Lance da tarrafa: um 'fiu' de rede girando e o splash na água."""
    buf = np.zeros(int(1.5 * SR))
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    sopro = filtro(ruido(0.5), "banda", 600, 3500) * np.sin(np.pi * t / 0.5) ** 1.3
    colocar(buf, sopro * 0.8, 0.0)
    colocar(buf, s_splash()[: int(1.0 * SR)], 0.45, 0.9)
    return buf


# ------------------------------------------------------------------ sons da V2 (visitas, porão, Tito)
def s_chuva():
    """Chuva de madrugada (loop, 8 s): chiado denso de banda larga com respingos e uma ondulação lenta."""
    dur = 8.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    base = filtro(ruido(dur), "banda", 1200, 7500) * (0.8 + 0.2 * np.sin(2 * np.pi * (3 / dur) * t + 1.0))
    grave = filtro(ruido(dur), "banda", 150, 700) * (0.5 + 0.2 * np.sin(2 * np.pi * (2 / dur) * t))
    gotas = np.zeros(n)
    for _ in range(260):  # respingos: estalinhos curtos espalhados (circular: o fim emenda no começo)
        d = RNG.uniform(0.006, 0.02)
        g = filtro(ruido(d), "alta", 3000) * np.exp(-tt(d) / 0.004) * RNG.uniform(0.2, 0.7)
        i = int(RNG.uniform(0, dur - 0.05) * SR)
        gotas[i:i + len(g)] += g
    return base * 0.9 + grave * 0.5 + gotas * 0.8


def s_goteira():
    """Goteira (loop, 6 s): pingos esparsos e graves numa sala de pedra, com eco curto."""
    dur = 6.0
    buf = np.zeros(int(dur * SR))
    for pos, f0, ganho in [(0.4, 1250, 1.0), (1.55, 980, 0.7), (2.9, 1500, 0.9), (3.7, 1100, 0.55), (4.95, 1350, 0.8)]:
        d = 0.16
        t = tt(d)
        gota = np.sin(fase(f0 * (1 + 1.4 * np.exp(-t / 0.03)))) * np.exp(-t / 0.045)
        gota += 0.25 * filtro(ruido(d), "banda", 800, 3000) * np.exp(-t / 0.01)
        colocar(buf, gota, pos, ganho)
        colocar(buf, gota, pos + 0.19, ganho * 0.32)   # eco curto
        colocar(buf, gota, pos + 0.41, ganho * 0.14)
    buf += filtro(ruido(dur), "banda", 80, 400) * 0.03   # fundo molhado
    return buf


def s_agua_sobe():
    """Água subindo no porão (4,5 s): ronco grave que cresce, borbulhar e um gorgolejo que fica mais agudo."""
    dur = 4.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    cresce = np.clip(t / 3.6, 0, 1) ** 1.4
    ronco = filtro(ruido(dur), "baixa", 260) * (0.25 + 0.75 * cresce)
    corrente = filtro(ruido(dur), "banda", 300, 2200) * (0.1 + 0.7 * cresce) * (0.8 + 0.2 * np.sin(2 * np.pi * 5.5 * t))
    bolhas = np.zeros(n)
    for _ in range(60):
        d = RNG.uniform(0.05, 0.12)
        pos = RNG.uniform(0.3, dur - 0.3)
        f0 = RNG.uniform(250, 600) * (1 + 0.8 * pos / dur)
        tb = tt(d)
        b = np.sin(fase(f0 * (1 + 2.2 * tb / d))) * np.exp(-tb / 0.03) * RNG.uniform(0.25, 0.7)
        i = int(pos * SR)
        bolhas[i:i + len(b)] += b
    y = ronco * 1.4 + corrente * 0.7 + bolhas * 0.5
    return y * np.minimum(1, t / 0.4) * np.minimum(1, (dur - t) / 0.6)


def s_crianca_ei():
    """'ei... aqui...': sussurro de RUÍDO filtrado com formantes (sem tom, sem voz realista).
    O texto aparece na tela; o som só dá a silhueta das sílabas, bem de longe."""
    dur = 2.6
    n = int(dur * SR)
    t = np.arange(n) / SR

    def silaba(ini, d, formantes, ganho):
        m = int(d * SR)
        s = np.zeros(m)
        for fc, largura, g in formantes:
            s += g * filtro(ruido(d), "banda", max(fc - largura, 100), fc + largura)
        env = np.sin(np.pi * np.clip(tt(d)[:m] / d, 0, 1)) ** 1.6
        return ini, s * env * ganho

    buf = np.zeros(n)
    # "e" (F1 ~ 450, F2 ~ 2000), "i" (F1 ~ 300, F2 ~ 2600): as sílabas de "ei"
    for ini, x in [silaba(0.15, 0.30, [(450, 150, 1.0), (2000, 500, 0.8)], 0.9),
                   silaba(0.42, 0.45, [(300, 100, 1.0), (2600, 600, 0.9)], 0.8),
                   # "a-qui"
                   silaba(1.35, 0.25, [(750, 200, 1.0), (1300, 300, 0.6)], 0.85),
                   silaba(1.62, 0.18, [(400, 120, 0.8), (2200, 500, 0.9)], 0.75),
                   silaba(1.78, 0.55, [(300, 100, 1.0), (2600, 600, 0.9)], 0.65)]:
        colocar(buf, x, ini)
    buf += filtro(ruido(dur), "alta", 3500) * 0.02
    return buf


def s_telefone_voz():
    """Voz da mãe no telefone do acervo: um murmúrio de banda estreita (300-3000 Hz) com sílabas, chiado e estalos.
    Não imita fala: só o contorno de quem fala longe, com a linha ruim. O texto vem na caixa '???'."""
    dur = 3.4
    n = int(dur * SR)
    t = np.arange(n) / SR
    voz = filtro(ruido(dur), "banda", 280, 1500) + 0.6 * filtro(ruido(dur), "banda", 1500, 3000)
    ritmo = np.clip(np.sin(2 * np.pi * 3.7 * t) + 0.6 * np.sin(2 * np.pi * 1.1 * t + 1.3), 0, None) ** 1.2
    pausas = np.where((t > 1.25) & (t < 1.6), 0.15, 1.0) * np.where((t > 2.4) & (t < 2.62), 0.0, 1.0)
    y = voz * ritmo * pausas * 0.9
    y += filtro(ruido(dur), "banda", 500, 3400) * 0.22        # chiado da linha
    estalos = np.zeros(n)
    for _ in range(14):
        i = int(RNG.uniform(0, dur - 0.05) * SR)
        d = int(RNG.uniform(0.002, 0.012) * SR)
        estalos[i:i + d] += RNG.uniform(-1, 1, d) * RNG.uniform(0.4, 1.0)
    y += estalos * 0.5
    y += 0.08 * np.sin(2 * np.pi * 50 * t)                    # zumbido da rede
    y *= np.minimum(1, t / 0.1) * np.minimum(1, (dur - t) / 0.5)
    return y


def s_atencao():
    """Um batimento ('tum-tá', 0,55 s). O Visor o repete cada vez mais depressa e mais alto conforme a atenção sobe."""
    buf = np.zeros(int(0.6 * SR))

    def tum(freq, d, ganho):
        t = tt(d)
        return (np.sin(fase(freq * (1 + 0.9 * np.exp(-t / 0.03)))) * np.exp(-t / 0.06)
                + 0.3 * filtro(ruido(d), "baixa", 300) * np.exp(-t / 0.03)) * ganho

    colocar(buf, tum(58, 0.22, 1.0), 0.0)
    colocar(buf, tum(48, 0.25, 0.7), 0.17)
    return buf


# ------------------------------------------------------------------ módulo 6: porão e Braço Morto
# Todos usam um gerador próprio (como o trovão) para não deslocar a sequência aleatória dos outros sons.
def _bolha(rng, f0, d=None, sobe=2.0, tau=0.03):
    d = d or rng.uniform(0.05, 0.12)
    tb = tt(d)
    return np.sin(fase(f0 * (1 + sobe * tb / d))) * np.exp(-tb / tau)


def s_susto_agua():
    """Susto de emergir (1,2 s): água estoura, impacto grave e cordas raspadas dissonantes que somem."""
    rng = np.random.default_rng(60001)
    dur = 1.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    r = rng.uniform(-1, 1, n)
    estouro = filtro(r, "banda", 400, 5500) * np.exp(-t / 0.16)
    estouro *= np.minimum(1, t / 0.004)
    espuma = filtro(rng.uniform(-1, 1, n), "alta", 2500) * np.exp(-t / 0.35) * 0.35
    impacto = np.sin(fase(70 * np.exp(-t * 7) + 38)) * np.exp(-t / 0.22) * 1.3
    # cordas raspadas: duas notas quase em semitom + harmônicos agudos, com ruído de arco
    cordas = np.zeros(n)
    for f in (1180, 1250, 1769):
        vib = 1 + 0.012 * np.sin(2 * np.pi * 6.5 * t + rng.uniform(0, 6))
        cordas += serra(f * vib * (1 - 0.04 * t), t, 6) * 0.5
    arco = filtro(rng.uniform(-1, 1, n), "banda", 1800, 4800) * 0.6
    cordas = (cordas + arco * (0.6 + 0.4 * np.sin(2 * np.pi * 23 * t))) * np.exp(-t / 0.42) * np.minimum(1, t / 0.03)
    return estouro * 1.0 + espuma + impacto + cordas * 0.45


def s_susto_perto():
    """Susto bem perto (1,0 s): inspiração molhada e rouca, depois um estalo agudo (stinger)."""
    rng = np.random.default_rng(60002)
    dur = 1.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    # inspiração rouca (0,05 .. 0,52 s): ruído em formante de garganta, subindo
    di = 0.47
    ti = tt(di)
    env = np.sin(np.pi * np.clip(ti / di, 0, 1)) ** 1.3 * (0.4 + 0.6 * ti / di)
    rouco = (filtro(rng.uniform(-1, 1, len(ti)), "banda", 350, 1100) + 0.8 * filtro(rng.uniform(-1, 1, len(ti)), "banda", 1800, 3800)) * env
    rouco *= 0.7 + 0.3 * np.sign(np.sin(2 * np.pi * 70 * ti)) * np.abs(np.sin(2 * np.pi * 9 * ti))  # raspado
    y = np.zeros(n)
    colocar(y, rouco, 0.04, 1.0)
    # molhado: bolhinhas na inspiração
    for pos in (0.12, 0.2, 0.33, 0.41):
        colocar(y, _bolha(rng, rng.uniform(500, 900), 0.06), pos, 0.35)
    # stinger: estalo + nota aguda dissonante
    ts = tt(0.5)
    estalo = filtro(rng.uniform(-1, 1, len(ts)), "alta", 2500) * np.exp(-ts / 0.012)
    ping = (np.sin(2 * np.pi * 2637 * ts) + 0.8 * np.sin(2 * np.pi * 2794 * ts) + 0.5 * np.sin(2 * np.pi * 3951 * ts)) * np.exp(-ts / 0.16)
    colocar(y, (estalo * 1.2 + ping * 0.5), 0.52, 1.0)
    colocar(y, np.sin(fase(60 * np.exp(-ts * 10) + 40)) * np.exp(-ts / 0.1), 0.52, 0.8)
    return y


def s_susto_queda():
    """Queda (1,2 s): baque surdo e um guincho metálico agudo descendo."""
    rng = np.random.default_rng(60003)
    dur = 1.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    baque = np.sin(fase(85 * np.exp(-t * 9) + 40)) * np.exp(-t / 0.18) * 1.3
    baque += filtro(rng.uniform(-1, 1, n), "baixa", 400) * np.exp(-t / 0.05) * 0.9
    ts = t - 0.06
    ativo = (ts > 0).astype(float)
    f = 4200 * np.exp(-np.clip(ts, 0, None) * 1.6) + 600
    guincho = (np.sin(fase(f)) + 0.6 * np.sin(fase(f * 2.31)) + 0.35 * np.sin(fase(f * 3.77)))
    guincho *= np.exp(-np.clip(ts, 0, None) / 0.55) * ativo * np.minimum(1, np.clip(ts, 0, None) / 0.01)
    guincho *= 0.8 + 0.2 * np.sin(2 * np.pi * 31 * t)
    atrito = filtro(rng.uniform(-1, 1, n), "alta", 3500) * np.exp(-np.clip(ts, 0, None) / 0.25) * ativo * 0.25
    return baque + guincho * 0.55 + atrito


def s_voz_tito():
    """Murmúrio de criança sem palavras (1,3 s), abafado como debaixo d'água, com 3 bolhinhas.
    Só a silhueta das sílabas (formantes agudos, como crianca_ei), nada inteligível."""
    rng = np.random.default_rng(60004)
    dur = 1.3
    n = int(dur * SR)

    def silaba(ini, d, f0a, f0b, formantes, ganho):
        m = int(d * SR)
        tb = np.arange(m) / SR
        f0 = np.linspace(f0a, f0b, m)
        fonte = np.zeros(m)
        ph = fase(f0)
        for k in range(1, 22):
            fonte += np.sin(k * ph) / k
        s = np.zeros(m)
        for fc, largura, g in formantes:
            s += g * filtro(fonte, "banda", max(fc - largura, 100), fc + largura)
        s += 0.15 * filtro(rng.uniform(-1, 1, m), "banda", 1500, 4000)
        env = np.sin(np.pi * np.clip(tb / d, 0, 1)) ** 1.4
        return ini, s * env * ganho

    buf = np.zeros(n)
    for ini, x in [silaba(0.08, 0.26, 330, 300, [(700, 180, 1.0), (1500, 300, 0.7), (3200, 500, 0.4)], 0.9),
                   silaba(0.38, 0.22, 360, 410, [(420, 120, 1.0), (2400, 500, 0.8), (3500, 500, 0.4)], 0.8),
                   silaba(0.66, 0.30, 400, 310, [(550, 150, 1.0), (1900, 400, 0.8), (3300, 500, 0.4)], 0.85),
                   silaba(1.0, 0.2, 320, 280, [(380, 100, 1.0), (2200, 400, 0.6)], 0.55)]:
        colocar(buf, x, ini)
    buf = filtro(buf, "baixa", 1500, ordem=3)
    buf = normalizar(buf, 0.7)
    bol = np.zeros(n)
    for pos in (0.25, 0.58, 0.93):
        colocar(bol, _bolha(rng, rng.uniform(350, 600), 0.07, 2.0, 0.025), pos, 0.5)
    buf += filtro(bol, "baixa", 1500)
    return buf


def s_afundar():
    """Afundar no Braço Morto (5 s): bolhas subindo, ronco abafado de pressão. Tudo passa-baixa."""
    rng = np.random.default_rng(60005)
    dur = 5.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    ronco = filtro(rng.uniform(-1, 1, n), "baixa", 180, ordem=3) * (0.4 + 0.6 * np.clip(t / 2.5, 0, 1)) * 1.6
    ronco += 0.4 * np.sin(2 * np.pi * 42 * t + 0.6 * np.sin(2 * np.pi * 0.5 * t))
    bolhas = np.zeros(n)
    for _ in range(85):
        pos = rng.uniform(0.05, dur - 0.2)
        f0 = rng.uniform(220, 900)
        colocar(bolhas, _bolha(rng, f0, rng.uniform(0.05, 0.16), 2.4, 0.035), pos, rng.uniform(0.15, 0.7))
    bolhas = filtro(bolhas, "baixa", 1400)
    y = ronco + bolhas * 0.9
    y = filtro(y, "baixa", 1800)
    return y * np.minimum(1, t / 0.25) * np.minimum(1, (dur - t) / 0.9)


def s_subaquatico():
    """Loop de 8 s debaixo d'água: drone grave abafado e uma bolha rara. Já sai abafado do arquivo
    (na web o filtro de bus não funciona). Ciclos inteiros em 8 s => emenda sem corte."""
    rng = np.random.default_rng(60006)
    dur = 8.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = 0.8 * np.sin(2 * np.pi * 44 * t + 0.8 * np.sin(2 * np.pi * (2 / dur) * t))
    y += 0.5 * np.sin(2 * np.pi * 66.25 * t + 1.1)            # 530 ciclos em 8 s
    y += 0.25 * np.sin(2 * np.pi * 88.5 * t) * (0.5 + 0.5 * np.sin(2 * np.pi * (3 / dur) * t))
    y += filtro(rng.uniform(-1, 1, n), "baixa", 220, ordem=3) * (0.9 + 0.5 * np.sin(2 * np.pi * (4 / dur) * t + 1.0))
    bol = np.zeros(n)
    for pos, f0, g in ((2.1, 380, 0.5), (5.6, 300, 0.4), (6.5, 460, 0.25)):
        colocar(bol, _bolha(rng, f0, 0.12, 2.2, 0.04), pos, g)
    y += filtro(bol, "baixa", 1000) * 0.6
    return filtro(y, "baixa", 900, ordem=3)


def s_figura_sobe():
    """Água escorrendo de um corpo que sai da lagoa (2,5 s): gotejar denso, filete e gorgolejo."""
    rng = np.random.default_rng(60007)
    dur = 2.5
    n = int(dur * SR)
    t = np.arange(n) / SR
    y = np.zeros(n)
    # gotejar denso que rareia
    pos = 0.0
    while pos < dur - 0.1:
        d = 0.05
        td = tt(d)
        f0 = rng.uniform(900, 2200)
        gota = np.sin(fase(f0 * (1 + 1.2 * np.exp(-td / 0.015)))) * np.exp(-td / 0.018) * rng.uniform(0.2, 0.9)
        colocar(y, gota, pos)
        pos += rng.uniform(0.012, 0.04) * (1 + 3.5 * (pos / dur) ** 2)
    # filete contínuo
    filete = filtro(rng.uniform(-1, 1, n), "banda", 1200, 4500) * (0.5 + 0.5 * np.sin(2 * np.pi * 7 * t + 1)) ** 0.5
    y += filete * 0.28 * np.exp(-t / 1.4) * np.minimum(1, t / 0.15)
    # gorgolejo grave que sobe
    gor = filtro(rng.uniform(-1, 1, n), "banda", 150, 700) * (0.6 + 0.4 * np.sin(2 * np.pi * 11 * t)) * np.exp(-t / 1.0)
    y += gor * 0.7
    for _ in range(14):
        colocar(y, _bolha(rng, rng.uniform(300, 700), rng.uniform(0.05, 0.1), 2.0, 0.03), rng.uniform(0.0, 1.8), rng.uniform(0.25, 0.6))
    return y * np.minimum(1, (dur - t) / 0.5)


def s_figura_afunda():
    """A Figura afunda (4 s): gorgolejo lento, bolhas grandes que rareiam."""
    rng = np.random.default_rng(60008)
    dur = 4.0
    n = int(dur * SR)
    t = np.arange(n) / SR
    gor = filtro(rng.uniform(-1, 1, n), "banda", 90, 500, 3)
    gor *= (0.55 + 0.45 * np.sin(2 * np.pi * (5.5 - 3.0 * t / dur) * t)) * np.exp(-t / 1.8)
    y = gor * 1.4
    pos = 0.05
    k = 0
    while pos < dur - 0.4:
        d = rng.uniform(0.12, 0.28)
        colocar(y, _bolha(rng, rng.uniform(140, 380), d, 1.8, 0.07), pos, rng.uniform(0.5, 1.0) * (1 - 0.6 * pos / dur))
        pos += 0.12 + 0.1 * k ** 1.25 * rng.uniform(0.7, 1.3)
        k += 1
    y = filtro(y, "baixa", 1300, ordem=2)
    return y * np.minimum(1, t / 0.08) * np.minimum(1, (dur - t) / 0.7)


def s_pista():
    """Pista nova (0,9 s): risco de giz (dois traços) e uma nota grave de caixinha de música, em tom menor, que ecoa."""
    rng = np.random.default_rng(60009)
    dur = 0.9
    n = int(dur * SR)
    y = np.zeros(n)
    for ini, d, g in ((0.0, 0.11, 1.0), (0.13, 0.09, 0.8)):
        td = tt(d)
        traco = filtro(rng.uniform(-1, 1, len(td)), "banda", 3500, 8500) * np.sin(np.pi * td / d) ** 0.7
        traco *= 0.6 + 0.4 * np.sin(2 * np.pi * 90 * td)
        colocar(y, traco, ini, g)
    # caixinha: Ré menor (D4 e F4 dissonando de leve com A4 ao fundo), dedilhado grave que ecoa
    for ini, nota, g in ((0.2, 62, 1.0),):
        f = float(midi(nota))
        tn = tt(0.7)
        nt = (np.sin(2 * np.pi * f * tn) * np.exp(-tn / 0.28)
              + 0.45 * np.sin(2 * np.pi * f * 2.0 * tn) * np.exp(-tn / 0.12)
              + 0.25 * np.sin(2 * np.pi * f * 5.04 * tn) * np.exp(-tn / 0.04)
              + 0.3 * np.sin(2 * np.pi * float(midi(65)) * tn) * np.exp(-tn / 0.18))  # terça menor
        nt = fade(nt, 0.001, 0.02)
        colocar(y, nt, ini, g)
        colocar(y, nt, ini + 0.17, g * 0.3)   # eco
    return y



# ------------------------------------------------------------------ jingle (3 versões)
# Melodia (beat, nota MIDI, duração em beats): 8 compassos em Dó maior (C - Am - F - G - C - Am - F - G).
MELODIA = [
    (0, 72, 1), (1, 76, .5), (1.5, 79, .5), (2, 76, 1), (3, 72, 1),
    (4, 69, 1), (5, 72, .5), (5.5, 76, .5), (6, 72, 1.5), (7.5, 69, .5),
    (8, 77, 1), (9, 81, .5), (9.5, 77, .5), (10, 74, 1), (11, 77, 1),
    (12, 79, 1.5), (13.5, 77, .5), (14, 76, 1), (15, 74, 1),
    (16, 76, .5), (16.5, 79, .5), (17, 84, 1), (18, 83, .5), (18.5, 79, .5), (19, 76, 1),
    (20, 76, .5), (20.5, 81, .5), (21, 79, 1), (22, 76, 1), (23, 72, 1),
    (24, 81, 1), (25, 79, .5), (25.5, 77, .5), (26, 76, 1), (27, 74, 1),
    (28, 79, 1), (29, 74, 1), (30, 71, 1), (31, 74, 1),
]
RAIZES = [48, 45, 41, 43, 48, 45, 41, 43]
ACORDES = [(60, 64, 67), (57, 60, 64), (57, 60, 65), (59, 62, 67)] * 2

# Módulo 6: jingle_1 mais estranho (desafina 18 cents, fita mais instável, uma nota some de vez em quando).
VERSOES_JINGLE = {
    0: dict(bpm=120, trans=0, xilo=True, chocalho=True, stabs=True, baixo=True, cents=0, hiss=0.0, wob=0.0, drop=0.0, lp=9000),
    1: dict(bpm=104, trans=-1, xilo=False, chocalho=False, stabs=True, baixo=True, cents=18, hiss=0.0, wob=0.012, drop=0.04, lp=4200),
    2: dict(bpm=84, trans=-2, xilo=False, chocalho=False, stabs=False, baixo=True, cents=38, hiss=0.02, wob=0.03, drop=0.14, lp=3000),
}


def s_trovao():
    """Trovão distante da madrugada (visita 4, revisão V2): estalo abafado e ronco grave que rola e morre em ~4 s.
    Usa um gerador próprio para não deslocar a sequência aleatória dos outros sons."""
    rng = np.random.default_rng(19670312)
    dur = 4.2
    n = int(dur * SR)
    t = np.arange(n) / SR
    branco = rng.uniform(-1, 1, n)
    ronco = filtro(branco, "banda", 35, 260, 2)
    rola = 0.55 + 0.45 * np.abs(np.sin(2 * np.pi * 1.3 * t + rng.uniform(0, 6))) * np.abs(np.sin(2 * np.pi * 0.47 * t))
    env = np.minimum(1, t / 0.18) * np.exp(-t / 1.25)
    y = ronco * rola * env
    est = filtro(rng.uniform(-1, 1, int(0.5 * SR)), "banda", 180, 1100, 2) * np.exp(-tt(0.5) / 0.09)
    y[:len(est)] += est * 0.35
    return y


def s_jingle(versao):
    c = VERSOES_JINGLE[versao]
    r = np.random.default_rng(777 + versao)
    beat = 60.0 / c["bpm"]
    comp = 32 * beat
    cauda = 2.5
    buf = np.zeros(int((comp + cauda) * SR))
    trans = c["trans"]

    def desafinar(n):
        cents = r.uniform(-c["cents"], c["cents"]) if c["cents"] else 0.0
        return midi(n + trans + cents / 100.0)

    for ini, nota, dur in MELODIA:
        if c["drop"] and r.random() < c["drop"]:
            continue
        colocar(buf, marimba(desafinar(nota), dur * beat, 1.0 - 0.5 * (versao > 0)), ini * beat, 0.55)
        if c["xilo"] and (ini * 2) % 2 == 0:
            colocar(buf, xilofone(desafinar(nota + 12), dur * beat), ini * beat, 0.16)
    for comp_i in range(8):
        b0 = comp_i * 4
        if c["baixo"]:
            raiz = RAIZES[comp_i]
            for pos, nota in ((0, raiz), (1.5, raiz + 7), (2, raiz), (3.5, raiz + 7)):
                if c["drop"] and r.random() < c["drop"]:
                    continue
                colocar(buf, baixo(desafinar(nota), 0.3 * beat * 2), (b0 + pos) * beat, 0.5)
        if c["stabs"]:
            for pos in (1, 3):
                for nota in ACORDES[comp_i]:
                    colocar(buf, pizz(desafinar(nota)), (b0 + pos) * beat, 0.17)
        colocar_percussao = versao == 0
        if colocar_percussao:
            for pos in (1, 3):
                colocar(buf, toquinho(), (b0 + pos) * beat, 0.35)
            if c["chocalho"]:
                for k in range(8):
                    colocar(buf, chocalho(), (b0 + k * 0.5) * beat, 0.13 if k % 2 == 0 else 0.07)
    if versao == 2:
        # zumbido grave (trítono) quase inaudível por baixo, como se o disco estivesse riscado
        t = tt(comp + cauda)
        buf += 0.035 * (np.sin(2 * np.pi * 65.4 * t) + np.sin(2 * np.pi * 92.5 * t)) * (0.6 + 0.4 * np.sin(2 * np.pi * (1 / comp) * t))
    # dobra a cauda sobre o começo: loop sem emendas
    n = int(comp * SR)
    saida = buf[:n].copy()
    resto = buf[n:]
    saida[: len(resto)] += resto
    if c["lp"] < 9000:
        saida = filtro(saida, "baixa", c["lp"])
    if c["wob"]:
        # fita instável: a velocidade oscila (lenta + trêmulo rápido). Ciclos inteiros: o loop fecha.
        f1 = max(1, round(0.4 * comp)) / comp
        f2 = max(1, round(5.0 * comp)) / comp
        tt_ = np.arange(n) / SR
        desloc = c["wob"] / (2 * np.pi * f1) * np.sin(2 * np.pi * f1 * tt_) + c["wob"] * 0.12 / (2 * np.pi * f2) * np.sin(2 * np.pi * f2 * tt_)
        saida = np.interp((tt_ + desloc) % comp, tt_, saida, period=comp)
    if c["hiss"]:
        saida += filtro(ruido(comp), "alta", 2500) * c["hiss"]
        for _ in range(int(comp * 6)):
            p = int(r.uniform(0, n - 4))
            saida[p:p + 2] += r.uniform(-1, 1) * 0.35
    return normalizar(saida, 0.8)


# ------------------------------------------------------------------ catálogo
# nome: (função, formato preferido)  -- "ogg" só se houver ffmpeg
CATALOGO = {
    "clique": (s_clique, "wav"),
    "boing": (s_boing, "wav"),
    "blip_bentinho": (s_blip_bentinho, "wav"),
    "blip_taina": (s_blip_taina, "wav"),
    "blip_quico": (s_blip_quico, "wav"),
    "blip_sistema": (s_blip_sistema, "wav"),
    "blip_misterio": (s_blip_misterio, "wav"),
    "acerto": (s_acerto, "wav"),
    "erro": (s_erro, "wav"),
    "selo": (s_selo, "wav"),
    "confete": (s_confete, "wav"),
    "fanfarra": (s_fanfarra, "wav"),
    "passo_1": (lambda: passo(95, 1400, 1), "wav"),
    "passo_2": (lambda: passo(80, 1100, 2), "wav"),
    "passo_3": (lambda: passo(110, 1700, 3), "wav"),
    "ofego": (s_ofego, "wav"),
    "susto": (s_susto, "wav"),
    "apito": (s_apito, "wav"),
    "telefone": (s_telefone, "wav"),
    "porta": (s_porta, "wav"),
    "agua_puxa": (s_agua_puxa, "wav"),
    "chiado_radio": (s_chiado_radio, "wav"),
    "glitch": (s_glitch, "wav"),
    "slide": (s_slide, "wav"),
    "sussurro": (s_sussurro, "wav"),
    "splash": (s_splash, "wav"),
    "tarrafa": (s_tarrafa, "wav"),
    "vento": (s_vento, "ogg"),
    "mar": (s_mar, "ogg"),
    "rio": (s_rio, "ogg"),
    "chuva": (s_chuva, "ogg"),
    "goteira": (s_goteira, "ogg"),
    "agua_sobe": (s_agua_sobe, "wav"),
    "crianca_ei": (s_crianca_ei, "wav"),
    "telefone_voz": (s_telefone_voz, "wav"),
    "atencao": (s_atencao, "wav"),
    "jingle_0": (lambda: s_jingle(0), "ogg"),
    "jingle_1": (lambda: s_jingle(1), "ogg"),
    "jingle_2": (lambda: s_jingle(2), "ogg"),
    "trovao": (s_trovao, "ogg"),
    # módulo 6
    "susto_agua": (s_susto_agua, "wav"),
    "susto_perto": (s_susto_perto, "wav"),
    "susto_queda": (s_susto_queda, "wav"),
    "voz_tito": (s_voz_tito, "wav"),
    "afundar": (s_afundar, "wav"),
    "subaquatico": (s_subaquatico, "ogg"),
    "figura_sobe": (s_figura_sobe, "wav"),
    "figura_afunda": (s_figura_afunda, "wav"),
    "pista": (s_pista, "wav"),
}


# Módulo 6: os sustos eram transientes curtos e soavam mais baixos que o apito e o carimbo; comprimidos, ficam no topo da mistura.
COMPRIMIR = {"susto", "susto_agua", "susto_perto", "susto_queda"}


def converter_ogg(wav, ogg):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "3", "-ar", str(SR), ogg], check=True)


def main():
    os.makedirs(SAIDA, exist_ok=True)
    nomes = sys.argv[1:] or list(CATALOGO)
    tem_ffmpeg = shutil.which("ffmpeg") is not None
    total = 0
    with tempfile.TemporaryDirectory() as tmp:
        for nome in nomes:
            fn, fmt = CATALOGO[nome]
            x = fn()
            if nome.startswith("jingle") or nome in ("vento", "mar", "rio", "chuva", "goteira", "subaquatico"):
                x = normalizar(x, 0.8)  # loops: sem fade nas pontas (emenda sem corte)
            else:
                if nome in COMPRIMIR:  # sustos: saturação suave sobe o volume percebido sem passar do pico
                    x = np.tanh(3.0 * x / (np.max(np.abs(x)) + 1e-9))
                x = fade(normalizar(x, 0.85))
            for ext in ("wav", "ogg"):  # remove versão antiga em outro formato
                antigo = os.path.join(SAIDA, f"{nome}.{ext}")
                if os.path.exists(antigo):
                    os.remove(antigo)
            if fmt == "ogg" and tem_ffmpeg:
                wav = os.path.join(tmp, nome + ".wav")
                salvar_wav(wav, x)
                destino = os.path.join(SAIDA, nome + ".ogg")
                converter_ogg(wav, destino)
            else:
                destino = os.path.join(SAIDA, nome + ".wav")
                salvar_wav(destino, x)
            kb = os.path.getsize(destino) / 1024
            total += kb
            print(f"{os.path.relpath(destino, RAIZ):42s} {len(x) / SR:5.2f}s {kb:7.1f} KB")
    print(f"total: {total:.0f} KB")


if __name__ == "__main__":
    main()
