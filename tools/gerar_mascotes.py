#!/usr/bin/env python3
"""Gera os SVGs da Turma da Memória (mascotes) e dos ícones dos painéis.

Uso: python3 tools/gerar_mascotes.py
Escreve em assets/ui/mascotes/*.svg (normal e _corrompido) e assets/ui/icones/*.svg.

Estilo: cartoon Flash dos anos 2000 (cor chapada + contorno grosso). A silhueta de cada
mascote é desenhada em duas passadas (contorno azul-marinho grosso, depois o preenchimento)
para o contorno ficar contínuo, sem linhas internas entre partes da mesma cor.
As variantes "_corrompido" usam a mesma geometria: cores dessaturadas, olhos vazios,
sorriso esticado cheio de dentes e lágrimas pretas.
"""
import os

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
NAVY = "#1B2250"
OW = 13  # largura extra do contorno (metade para cada lado)


def svg(corpo, tam=256, px=None):
    """tam = lado do viewBox; px = tamanho em pixels da textura importada (padrão = tam)."""
    px = px or tam
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{px}" height="{px}" '
            f'viewBox="0 0 {tam} {tam}">\n{corpo}\n</svg>\n')


def forma(tag, attrs, cor, sw=None, tr=""):
    return {"tag": tag, "attrs": attrs, "cor": cor, "sw": sw, "tr": tr}


def silhueta(formas):
    """Duas passadas: contorno contínuo e depois o preenchimento de cada parte."""
    out = ['<g stroke-linejoin="round" stroke-linecap="round">']
    for f in formas:
        t = f' transform="{f["tr"]}"' if f["tr"] else ""
        if f["sw"] is None:
            out.append(f'<{f["tag"]} {f["attrs"]}{t} fill="{NAVY}" stroke="{NAVY}" stroke-width="{OW}"/>')
        else:
            out.append(f'<{f["tag"]} {f["attrs"]}{t} fill="none" stroke="{NAVY}" stroke-width="{f["sw"] + OW}"/>')
    for f in formas:
        t = f' transform="{f["tr"]}"' if f["tr"] else ""
        if f["sw"] is None:
            out.append(f'<{f["tag"]} {f["attrs"]}{t} fill="{f["cor"]}" stroke="none"/>')
        else:
            out.append(f'<{f["tag"]} {f["attrs"]}{t} fill="none" stroke="{f["cor"]}" stroke-width="{f["sw"]}"/>')
    out.append("</g>")
    return "\n".join(out)


def tracos(d, w=5, cor=NAVY, fill="none", extra=""):
    return (f'<path d="{d}" fill="{fill}" stroke="{cor}" stroke-width="{w}" '
            f'stroke-linecap="round" stroke-linejoin="round" {extra}/>')


def dentes(x0, y0, n, passo, alt, cor="#FFFFFF"):
    """Fileira de dentes triangulares (zigue-zague) para o sorriso corrompido."""
    pts = [f"{x0},{y0}"]
    x = x0
    for i in range(n):
        x += passo
        pts.append(f"{x},{y0 + (alt if i % 2 == 0 else 0)}")
    return f'<polyline points="{" ".join(pts)}" fill="{cor}" stroke="{NAVY}" stroke-width="2.5" stroke-linejoin="round"/>'


# ------------------------------------------------------------------ Bentinho (boto)
def bentinho(c):
    corpo, esc, barriga = ("#8E9BA6", "#6B7680", "#CDD2D6") if c else ("#78A9D0", "#4F7FAE", "#EAF4FB")
    rosa = "#8A8F94" if c else "#FF9AA8"
    gravata = "#5E1F2A" if c else "#E8362E"
    f = [
        forma("path", 'd="M100,206 C74,232 40,234 26,206"', corpo, sw=36),
        forma("circle", 'cx="66" cy="196" r="24"', corpo),
        forma("ellipse", 'cx="14" cy="182" rx="11" ry="27"', esc, tr="rotate(-28 14 182)"),
        forma("ellipse", 'cx="46" cy="176" rx="11" ry="27"', esc, tr="rotate(28 46 176)"),
        forma("path", 'd="M64,64 C50,44 48,28 56,18 C80,22 102,36 108,58 Z"', esc),
        forma("ellipse", 'cx="116" cy="158" rx="58" ry="80"', corpo, tr="rotate(-6 116 158)"),
        forma("ellipse", 'cx="122" cy="88" rx="58" ry="54"', corpo),
        forma("ellipse", 'cx="198" cy="100" rx="40" ry="17"', corpo, tr="rotate(6 198 100)"),
        forma("ellipse", 'cx="196" cy="122" rx="34" ry="16"', barriga, tr="rotate(6 196 122)"),
        forma("ellipse", 'cx="62" cy="172" rx="12" ry="30"', esc, tr="rotate(22 62 172)"),
        forma("ellipse", 'cx="180" cy="158" rx="14" ry="34"', esc, tr="rotate(-42 180 158)"),
    ]
    s = ['<g transform="translate(8,4)">', silhueta(f)]
    s.append(f'<ellipse cx="138" cy="170" rx="38" ry="62" fill="{barriga}" transform="rotate(-6 138 170)"/>')
    # gravata-borboleta
    s.append(f'<path d="M134,146 L106,130 L106,162 Z" fill="{gravata}" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    s.append(f'<path d="M134,146 L164,130 L164,162 Z" fill="{gravata}" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    s.append(f'<circle cx="134" cy="146" r="9" fill="{gravata}" stroke="{NAVY}" stroke-width="5"/>')
    if c:
        s.append('<ellipse cx="150" cy="78" rx="19" ry="22" fill="#000" stroke="%s" stroke-width="5"/>' % NAVY)
        s.append(tracos("M148,98 Q142,132 152,152", 7, "#000"))
        s.append('<circle cx="153" cy="156" r="5" fill="#000"/>')
        s.append(tracos("M130,50 Q148,34 170,52", 7))
        # sorriso esticado, passando da bochecha
        s.append(f'<path d="M150,104 Q200,176 246,84 Q204,134 150,104 Z" fill="#14060C" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
        s.append(dentes(166, 118, 10, 7.8, 12))
    else:
        s.append(f'<ellipse cx="150" cy="78" rx="17" ry="20" fill="#fff" stroke="{NAVY}" stroke-width="5"/>')
        s.append(f'<circle cx="155" cy="81" r="9.5" fill="{NAVY}"/>')
        s.append('<circle cx="159" cy="76" r="3.6" fill="#fff"/>')
        s.append(tracos("M132,52 Q150,42 170,54", 6))
        s.append(f'<circle cx="150" cy="112" r="10" fill="{rosa}" opacity="0.75"/>')
        # boca aberta sorrindo
        s.append(f'<path d="M160,108 Q202,150 240,106 Q200,114 160,108 Z" fill="#B3263A" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
        s.append('<ellipse cx="204" cy="127" rx="15" ry="7" fill="#FF8FA0"/>')
        s.append(tracos("M160,108 q-6,-2 -9,-9", 4.5))
    s.append("</g>")
    return svg("\n".join(s), 256, 384)


# ------------------------------------------------------------------ Tainá (tainha)
def taina(c):
    corpo, esc, barriga = ("#9AA3A9", "#6E777E", "#D7DBDE") if c else ("#BCCFDF", "#8FA9BF", "#F3F8FC")
    laco = "#7A4A55" if c else "#FF5FA2"
    listra = "#5E676E" if c else "#6F8BA3"
    f = [
        forma("path", 'd="M52,130 L8,84 Q28,130 8,176 Z"', esc),
        forma("path", 'd="M104,88 L126,44 L156,84 Z"', esc),
        forma("path", 'd="M160,90 L168,62 L190,96 Z"', esc),
        forma("ellipse", 'cx="132" cy="130" rx="98" ry="52"', corpo),
        forma("ellipse", 'cx="150" cy="168" rx="26" ry="12"', esc, tr="rotate(30 150 168)"),
    ]
    s = ['<g transform="translate(-10,6) rotate(-10 128 128)">', silhueta(f)]
    s.append(f'<ellipse cx="142" cy="152" rx="82" ry="26" fill="{barriga}"/>')
    for k, dy in enumerate((-14, 0, 14)):
        s.append(tracos(f"M60,{124 + dy} Q130,{108 + dy} 190,{122 + dy}", 3.5, listra, extra='opacity="0.8"'))
    for (x, y) in ((94, 142), (112, 148), (130, 142), (78, 150)):
        s.append(tracos(f"M{x},{y} q8,-8 16,0", 3, listra, extra='opacity="0.7"'))
    s.append(tracos("M150,96 Q140,130 150,162", 5))
    # laço
    s.append(f'<path d="M206,86 L186,68 L184,100 Z" fill="{laco}" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    s.append(f'<path d="M206,86 L232,70 L228,104 Z" fill="{laco}" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    s.append(f'<circle cx="206" cy="86" r="8" fill="{laco}" stroke="{NAVY}" stroke-width="5"/>')
    # olho grande
    if c:
        s.append('<circle cx="182" cy="122" r="28" fill="#000" stroke="%s" stroke-width="5"/>' % NAVY)
        s.append(tracos("M178,148 Q170,176 180,196", 7, "#000"))
        s.append('<circle cx="181" cy="200" r="5" fill="#000"/>')
        s.append(f'<path d="M200,142 Q226,186 248,124 Q226,162 200,142 Z" fill="#14060C" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
        s.append(dentes(208, 152, 7, 6.3, 10))
    else:
        s.append(f'<circle cx="182" cy="122" r="27" fill="#fff" stroke="{NAVY}" stroke-width="5"/>')
        s.append(f'<circle cx="188" cy="125" r="13" fill="{NAVY}"/>')
        s.append('<circle cx="193" cy="119" r="5" fill="#fff"/>')
        s.append(tracos("M156,104 l-10,-6", 4.5))
        s.append(tracos("M160,94 l-8,-9", 4.5))
        s.append(tracos("M170,88 l-5,-11", 4.5))
        s.append('<circle cx="204" cy="152" r="9" fill="#FF9AA8" opacity="0.75"/>')
        s.append(tracos("M214,136 Q232,156 246,134", 5.5))
    s.append("</g>")
    return svg("\n".join(s), 256, 384)


# ------------------------------------------------------------------ Quico (quero-quero)
def quico(c):
    dorso, branco, rosto = ("#8C8880", "#E3E1DC", "#B9B6AE") if c else ("#A8987E", "#FFFFFF", "#D9D2C2")
    perna = "#8A5B58" if c else "#E5524A"
    apito = "#9A9A9A" if c else "#FFC93C"
    f = [
        forma("path", 'd="M104,206 L98,238"', perna, sw=8),
        forma("path", 'd="M146,206 L152,238"', perna, sw=8),
        forma("path", 'd="M98,238 l-16,4 M98,238 l2,8 M98,238 l14,5"', perna, sw=6),
        forma("path", 'd="M152,238 l-12,5 M152,238 l-1,8 M152,238 l16,4"', perna, sw=6),
        forma("ellipse", 'cx="122" cy="156" rx="56" ry="60"', branco, tr="rotate(-10 122 156)"),
        forma("path", 'd="M84,108 C60,150 70,196 112,206 C96,170 100,140 120,112 Z"', dorso),
        forma("circle", 'cx="152" cy="88" r="36"', rosto),
        forma("path", 'd="M178,86 L224,96 L180,108 Z"', "#F08A7E" if not c else "#9B8A86"),
        forma("path", 'd="M138,58 Q112,26 78,34"', "#111111", sw=9),
        forma("path", 'd="M146,54 Q128,16 98,14"', "#111111", sw=8),
    ]
    s = [silhueta(f)]
    # asa
    s.append(f'<path d="M88,130 C74,166 90,196 128,204 C114,172 124,148 150,134 Z" fill="{dorso}" stroke="{NAVY}" stroke-width="5" stroke-linejoin="round"/>')
    s.append(f'<path d="M96,150 Q112,150 120,170" fill="none" stroke="{NAVY}" stroke-width="3.5" stroke-linecap="round" opacity="0.55"/>')
    # peito preto
    s.append(f'<path d="M146,124 Q176,126 186,150 Q160,160 140,150 Z" fill="#111" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
    # boné preto na cabeça
    s.append(f'<path d="M122,80 Q132,50 160,54 Q184,58 186,80 Q150,66 122,80 Z" fill="#111" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
    # esporão
    s.append(f'<path d="M92,140 l-12,-6" stroke="{apito}" stroke-width="5" stroke-linecap="round"/>')
    # apito na boca
    s.append(f'<rect x="196" y="96" width="30" height="20" rx="9" fill="{apito}" stroke="{NAVY}" stroke-width="5"/>')
    s.append(f'<circle cx="216" cy="106" r="5" fill="{NAVY}"/>')
    s.append(f'<path d="M178,102 L198,104" stroke="{NAVY}" stroke-width="5" stroke-linecap="round"/>')
    if c:
        s.append(f'<ellipse cx="156" cy="86" rx="15" ry="17" fill="#000" stroke="{NAVY}" stroke-width="4.5"/>')
        s.append(tracos("M154,102 Q150,130 158,146", 6, "#000"))
        s.append('<circle cx="159" cy="150" r="4.5" fill="#000"/>')
        s.append(tracos("M138,64 Q156,52 176,66", 6))
        # grito/apito esticado: sorriso aberto no bico
        s.append(f'<path d="M168,116 Q196,150 226,112 Q196,134 168,116 Z" fill="#14060C" stroke="{NAVY}" stroke-width="4" stroke-linejoin="round"/>')
        s.append(dentes(176, 122, 7, 7, 8))
    else:
        s.append(f'<circle cx="156" cy="86" r="14" fill="#fff" stroke="{NAVY}" stroke-width="4.5"/>')
        s.append(f'<circle cx="159" cy="87" r="9" fill="#D0312D"/>')
        s.append(f'<circle cx="160" cy="88" r="4.6" fill="#000"/>')
        s.append('<circle cx="163" cy="84" r="2.6" fill="#fff"/>')
        s.append(tracos("M140,66 Q156,56 174,66", 5))
        s.append('<circle cx="170" cy="108" r="7" fill="#FF9AA8" opacity="0.7"/>')
        # linhas de som do apito
        s.append(tracos("M236,86 l12,-8", 4.5))
        s.append(tracos("M240,102 l14,0", 4.5))
        s.append(tracos("M236,118 l12,8", 4.5))
    return svg("\n".join(s), 256, 384)


# ------------------------------------------------------------------ ícones dos painéis (128x128)
def ic(corpo):
    return svg(corpo, 128)


def ct(d, fill, w=5, extra="", cor=NAVY):
    return (f'<path d="{d}" fill="{fill}" stroke="{cor}" stroke-width="{w}" '
            f'stroke-linejoin="round" stroke-linecap="round" {extra}/>')


def rect(x, y, w, h, fill, r=0, sw=5):
    return f'<rect x="{x}" y="{y}" width="{w}" height="{h}" rx="{r}" fill="{fill}" stroke="{NAVY}" stroke-width="{sw}" stroke-linejoin="round"/>'


def circ(cx, cy, r, fill, sw=5):
    return f'<circle cx="{cx}" cy="{cy}" r="{r}" fill="{fill}" stroke="{NAVY}" stroke-width="{sw}"/>'


PEDRA, PEDRA_E = "#C9806A", "#A8583F"
AZUL, AMAR, VERD, VERM, CREME = "#3AA0FF", "#FFD23F", "#5CCB4A", "#FF5A4F", "#FFF3D1"


def ameias(x, y, n, larg, alt, cor=PEDRA):
    return "".join(rect(x + i * larg * 2, y, larg, alt, cor, 0, 4) for i in range(n))


ICONES = {
    "castelo": lambda: ic(
        ameias(8, 18, 2, 10, 12) + rect(8, 28, 32, 80, PEDRA) + ameias(88, 38, 2, 10, 12) + rect(88, 48, 32, 60, PEDRA)
        + rect(36, 62, 56, 46, PEDRA_E) + ameias(36, 52, 3, 8, 10, PEDRA_E)
        + "".join(ct(f"M{42 + i * 14},108 L{42 + i * 14},88 Q{49 + i * 14},76 {56 + i * 14},88 L{56 + i * 14},108 Z", "#4A2A22", 4) for i in range(3))
        + rect(18, 44, 12, 18, "#4A2A22", 5, 4) + rect(98, 62, 12, 16, "#4A2A22", 5, 4)
        + ct("M104,10 L104,48", "none", 4) + ct("M104,10 L122,16 L104,24 Z", VERM, 3)),
    "folha": lambda: ic(
        ct("M64,118 C62,96 64,80 70,62", "none", 6)
        + ct("M64,108 C20,102 8,58 36,30 C44,40 50,34 58,24 C62,34 70,34 76,24 C84,34 92,40 98,34 C122,64 108,104 64,108 Z", VERD)
        + ct("M64,104 C62,80 64,60 64,40", "none", 4) + ct("M40,50 L60,66 M32,74 L58,80 M88,50 L66,66 M96,76 L68,82", "none", 4)),
    "pedra": lambda: ic(
        rect(10, 78, 52, 30, PEDRA, 6) + rect(66, 78, 52, 30, PEDRA_E, 6) + rect(36, 46, 56, 30, PEDRA_E, 6)
        + rect(8, 46, 24, 28, PEDRA, 6) + rect(96, 46, 24, 28, PEDRA, 6) + rect(36, 14, 56, 30, PEDRA, 6)),
    "barco": lambda: ic(
        ct("M8,86 L120,86 L100,112 L28,112 Z", "#8A5A36") + ct("M62,16 L62,82", "none", 5) + ct("M66,20 L108,76 L66,76 Z", CREME)
        + ct("M58,30 L30,76 L58,76 Z", "#FFFFFF") + ct("M62,16 L84,22 L62,28 Z", VERM, 3)
        + ct("M4,116 Q16,106 28,116 T52,116 T76,116 T100,116 T124,116", "none", 5, cor="#3AA0FF")),
    "arcada": lambda: ic(
        rect(6, 20, 116, 90, PEDRA, 6) + ameias(10, 8, 5, 8, 12)
        + "".join(ct(f"M{14 + i * 27},110 L{14 + i * 27},70 Q{26 + i * 27},46 {38 + i * 27},70 L{38 + i * 27},110 Z", "#4A2A22", 4) for i in range(4))),
    "lei": lambda: ic(
        ct("M26,14 H98 Q108,14 108,24 V96 Q108,114 94,114 H34 Q20,114 20,96 V24 Q20,14 26,14 Z", CREME)
        + ct("M36,36 H92 M36,54 H92 M36,72 H70", "none", 5) + circ(88, 92, 14, VERM, 5)
        + ct("M80,102 L74,122 L88,114 L100,122 L96,102", VERM, 4)),
    "museu": lambda: ic(
        ct("M8,40 L64,10 L120,40 Z", AMAR) + rect(12, 40, 104, 10, CREME, 2)
        + "".join(rect(20 + i * 24, 52, 14, 46, "#FFFFFF", 2) for i in range(4)) + rect(8, 98, 112, 14, PEDRA_E, 3)),
    "concha": lambda: ic(
        ct("M64,112 C20,104 6,70 14,44 C30,34 98,34 114,44 C122,70 108,104 64,112 Z", "#F6B9C8")
        + ct("M64,112 L28,44 M64,112 L46,40 M64,112 L64,38 M64,112 L82,40 M64,112 L100,44", "none", 4)
        + rect(44, 104, 40, 14, "#F6B9C8", 6)),
    "boto": lambda: ic(
        ct("M10,92 C14,50 52,28 88,38 C104,42 114,54 122,52 C118,66 108,70 98,70 C100,92 80,112 52,110 C34,108 22,102 10,92 Z", "#78A9D0")
        + ct("M44,32 C48,18 60,12 70,14 C66,22 66,28 70,36 Z", "#4F7FAE") + ct("M10,92 L0,112 L26,102 Z", "#4F7FAE", 4)
        + circ(92, 52, 6, "#FFFFFF", 4) + circ(94, 53, 2.4, NAVY, 1) + ct("M100,64 Q112,70 122,58", "none", 4)),
    "telefone": lambda: ic(
        rect(14, 66, 100, 46, "#E8362E", 12) + circ(64, 90, 22, CREME, 5) + circ(64, 90, 6, "#E8362E", 4)
        + ct("M12,54 Q20,26 44,30 L50,46 Q34,44 30,58 Z", "#2B2B35") + ct("M116,54 Q108,26 84,30 L78,46 Q94,44 98,58 Z", "#2B2B35")
        + ct("M44,32 Q64,20 84,32", "none", 7)),
    "ponte": lambda: ic(
        rect(4, 44, 120, 14, "#8E8E99", 3) + "".join(ct(f"M{8 + i * 40},96 Q{28 + i * 40},46 {48 + i * 40},96", "none", 6, cor="#8E8E99") for i in range(3))
        + ct("M4,96 H124", "none", 5) + ct("M4,104 Q16,96 28,104 T52,104 T76,104 T100,104 T124,104", "none", 5, cor="#3AA0FF")
        + ct("M16,44 V28 M52,44 V28 M88,44 V28 M112,44 V28", "none", 4)),
    "escudo": lambda: ic(
        ct("M16,18 H112 V60 C112,92 88,108 64,120 C40,108 16,92 16,60 Z", AZUL)
        + ct("M16,18 H64 V58 H16 Z", VERM, 4) + ct("M64,58 H112 V60 C112,70 108,80 102,88 L64,88 Z", VERM, 4)
        + ct("M64,18 V118 M16,58 H112", "none", 8, cor="#FFD23F")),
    "pessoas": lambda: ic(
        circ(34, 34, 14, "#FFD7A8") + ct("M12,100 C12,64 56,64 56,100 Z", AZUL) + circ(94, 34, 14, "#FFD7A8")
        + ct("M72,100 C72,64 116,64 116,100 Z", VERD) + circ(64, 52, 16, "#FFD7A8") + ct("M38,114 C38,76 90,76 90,114 Z", AMAR)),
    "relogio": lambda: ic(
        circ(64, 66, 50, "#FFFFFF", 6) + ct("M64,28 V66 L90,80", "none", 7) + circ(64, 66, 6, VERM, 4)
        + ct("M30,16 Q40,6 52,10 M98,16 Q88,6 76,10", "none", 6)),
    "mapa": lambda: ic(
        ct("M8,28 L44,18 L84,28 L120,18 V100 L84,110 L44,100 L8,110 Z", CREME) + ct("M44,18 V100 M84,28 V110", "none", 4)
        + ct("M64,52 C48,52 46,72 64,94 C82,72 80,52 64,52 Z", VERM) + circ(64, 66, 5, "#FFFFFF", 3)),
    "interrogacao": lambda: ic(
        circ(64, 64, 54, AZUL, 6) + ct("M42,48 C42,22 86,22 86,46 C86,64 64,64 64,82", "none", 11, cor="#FFFFFF")
        + circ(64, 100, 8, "#FFFFFF", 3)),
    "estrela": lambda: ic(
        ct("M64,8 L80,46 L121,50 L90,77 L99,118 L64,97 L29,118 L38,77 L7,50 L48,46 Z", AMAR, 6)),
    "check": lambda: ic(circ(64, 64, 54, VERD, 6) + ct("M34,66 L54,88 L94,42", "none", 12, cor="#FFFFFF")),
    "alerta": lambda: ic(
        ct("M64,10 L120,108 H8 Z", AMAR, 6) + ct("M64,44 V76", "none", 11) + circ(64, 92, 6, NAVY, 2)),
    "onda": lambda: ic(
        circ(96, 34, 20, AMAR) + ct("M4,70 Q20,52 36,70 T68,70 T100,70 T132,70 V120 H4 Z", AZUL)
        + ct("M4,92 Q20,78 36,92 T68,92 T100,92 T132,92", "none", 5, cor="#FFFFFF")),
    "torre": lambda: ic(
        ameias(30, 8, 3, 10, 14) + rect(30, 22, 68, 90, PEDRA, 5) + ct("M30,50 H98", "none", 4)
        + rect(52, 66, 24, 46, "#4A2A22", 10, 4) + rect(56, 30, 16, 14, "#4A2A22", 5, 4)),
    "sol": lambda: ic(
        circ(64, 50, 24, AMAR) + "".join(ct(f"M{64 + 34 * c:.0f},{50 + 34 * s:.0f} L{64 + 46 * c:.0f},{50 + 46 * s:.0f}", "none", 6)
        for c, s in ((1, 0), (-1, 0), (0, 1), (0, -1), (.7, .7), (-.7, .7), (.7, -.7), (-.7, -.7)))
        + ct("M4,96 Q20,80 36,96 T68,96 T100,96 T132,96 V122 H4 Z", AZUL)),
    "peixe": lambda: ic(
        ct("M22,64 C40,24 92,24 108,64 C92,104 40,104 22,64 Z", "#BCCFDF") + ct("M24,64 L2,40 Q10,64 2,88 Z", "#8FA9BF", 4)
        + circ(88, 56, 8, "#FFFFFF", 4) + circ(90, 57, 3, NAVY, 1) + ct("M98,72 Q106,76 110,68", "none", 4)),
    "coroa": lambda: ic(
        ct("M14,100 L10,36 L40,62 L64,22 L88,62 L118,36 L114,100 Z", AMAR) + rect(12, 96, 104, 16, "#E8A000", 3)
        + circ(10, 34, 7, VERM, 4) + circ(64, 20, 7, VERM, 4) + circ(118, 34, 7, VERM, 4)),
}


def escrever(caminho, conteudo):
    os.makedirs(os.path.dirname(caminho), exist_ok=True)
    with open(caminho, "w", encoding="utf-8") as f:
        f.write(conteudo)
    print("escrito:", os.path.relpath(caminho, RAIZ))


def main():
    base = os.path.join(RAIZ, "assets", "ui", "mascotes")
    for nome, fn in (("bentinho", bentinho), ("taina", taina), ("quico", quico)):
        escrever(os.path.join(base, f"{nome}.svg"), fn(False))
        escrever(os.path.join(base, f"{nome}_corrompido.svg"), fn(True))
    for nome, fn in ICONES.items():
        escrever(os.path.join(RAIZ, "assets", "ui", "icones", f"{nome}.svg"), fn())


if __name__ == "__main__":
    main()
