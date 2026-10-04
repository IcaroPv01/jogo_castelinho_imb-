#!/usr/bin/env python3
"""Monta comparações lado a lado: foto de referência (esquerda) x captura do jogo (direita).

Uso:
  python3 tools/comparar_fotos.py <pasta_capturas> <pasta_saida> [prefixo_capturas]

Espera as capturas de tests/captura_cam.gd com nomes <prefixo>_<Cam>.png (prefixo padrão "e3"; o núcleo de 1950 usa
"e0" e a aérea de 2019 usa "e2" quando existirem). As fotos ficam em docs/pesquisa/refs/ (privadas, não versionadas:
baixe com docs/pesquisa/baixar_refs.sh). Gera cmp_<nome>.png com as duas imagens na mesma altura.
Depende só de Pillow.
"""
import os
import sys

from PIL import Image, ImageDraw

RAIZ = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
REFS = os.path.join(RAIZ, "docs", "pesquisa", "refs")

# nome da comparação: (foto, câmera, prefixo preferido)
PARES = {
    "drone": ("jpl_2021_aerea_drone_fachadas.jpg", "Cam_drone", None),
    "frontal": ("fachada_frontal_2026_beta.jpg", "Cam_frontal", None),
    "esquina": ("lnr_2026_frontal_esquina_ivan.jpg", "Cam_esquina", None),
    "torres": ("torres_fachada_lateral_2026_correiodoimbe.jpg", "Cam_torres", None),
    "aerea2019": ("aerea_2019_litoralnarede.jpg", "Cam_aerea2019", "e2"),
    "nucleo1950": ("foto_antiga_nucleo_original_beta.jpg", "Cam_nucleo1950", "e0"),
}
ALTURA = 540


def lado_a_lado(foto, cap, rotulo, saida):
    a = Image.open(foto).convert("RGB")
    b = Image.open(cap).convert("RGB")
    a = a.resize((round(a.width * ALTURA / a.height), ALTURA), Image.LANCZOS)
    b = b.resize((round(b.width * ALTURA / b.height), ALTURA), Image.LANCZOS)
    out = Image.new("RGB", (a.width + b.width + 8, ALTURA + 18), "white")
    out.paste(a, (0, 18))
    out.paste(b, (a.width + 8, 18))
    d = ImageDraw.Draw(out)
    d.text((4, 3), "foto: " + os.path.basename(foto), fill="black")
    d.text((a.width + 12, 3), "jogo: " + rotulo, fill="black")
    out.save(saida)
    print("comparação:", saida)


def main():
    caps = sys.argv[1] if len(sys.argv) > 1 else "build/capturas"
    saida = sys.argv[2] if len(sys.argv) > 2 else caps
    prefixo = sys.argv[3] if len(sys.argv) > 3 else "e3"
    os.makedirs(saida, exist_ok=True)
    for nome, (foto, cam, pref) in PARES.items():
        fp = os.path.join(REFS, foto)
        if not os.path.exists(fp):
            print("sem foto (rode docs/pesquisa/baixar_refs.sh):", foto)
            continue
        cand = [os.path.join(caps, "%s_%s.png" % (p, cam)) for p in ([pref] if pref else []) + [prefixo]]
        cap = next((c for c in cand if os.path.exists(c)), None)
        if cap is None:
            print("sem captura:", cand[-1])
            continue
        lado_a_lado(fp, cap, os.path.basename(cap), os.path.join(saida, "cmp_%s.png" % nome))


if __name__ == "__main__":
    main()
