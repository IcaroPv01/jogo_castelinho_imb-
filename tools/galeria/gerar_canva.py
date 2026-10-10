#!/usr/bin/env python3
"""Gera galeria/canva.html: páginas 1920x1080 para o Canva importar ("import design from URL").

Uso:
  python3 tools/galeria/gerar_canva.py [--base URL] [--manifesto CAM] [--saida CAM]

Só biblioteca padrão. HTML estático (sem JS, sem CSS externo). Cada página é um
<section> de topo com data-document-role="page". Fotos que não existem em galeria/
são puladas. As imagens usam URL absoluta: --base + caminho da foto.
"""
import argparse
import html
import json
import os
import sys
from urllib.parse import quote

RAIZ = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..'))
GALERIA = os.path.join(RAIZ, 'galeria')
BASE_PADRAO = 'https://icaropv01.github.io/jogo_castelinho_imb-/galeria/'
GRUPOS = [
    ('castelo', 'Castelo'),
    ('barra', 'Barra'),
    ('porao', 'Porão'),
    ('lago', 'Lago (Braço Morto)'),
    ('criaturas', 'Criaturas'),
]
W, H = 1920, 1080
COR_FUNDO = '#121214'
COR_TEXTO = '#e8e6e1'
COR_SUAVE = '#a7a6a0'
COR_DESTAQUE = '#c9a24a'
COR_NOTA = '#ffe9a6'
BG_NOTA = '#3a3112'
BORDA_NOTA = '#e0b84f'
MAX_FOTOS = 3

PULADAS = []


def esc(valor):
    return html.escape(str(valor), quote=True)


def data_br(s):
    partes = str(s or '').split('-')
    if len(partes) == 3 and all(p.isdigit() for p in partes):
        return f'{partes[2]}/{partes[1]}/{partes[0]}'
    return str(s or '')


def foto_no_disco(rel):
    """Devolve o caminho relativo se o arquivo existe dentro de galeria/, senão None."""
    if not isinstance(rel, str) or not rel or os.path.isabs(rel):
        return None
    destino = os.path.normpath(os.path.join(GALERIA, rel))
    if not destino.startswith(GALERIA + os.sep):
        return None
    return rel if os.path.isfile(destino) else None


def url_absoluta(base, rel):
    return base + '/'.join(quote(seg) for seg in rel.split('/'))


def pagina(label, notas, corpo, fundo=COR_FUNDO):
    estilo = (
        f'position:relative;box-sizing:border-box;width:{W}px;height:{H}px;overflow:hidden;'
        f'background:{fundo};color:{COR_TEXTO};font-family:Arial,Helvetica,sans-serif;'
        'padding:60px 80px;margin:0;'
    )
    return (
        f'<section data-document-role="page" data-label="{esc(label)}" '
        f'data-speaker-notes="{esc(notas)}" style="{estilo}">\n{corpo}\n</section>'
    )


def capa(data_txt):
    corpo = (
        '<div style="display:flex;flex-direction:column;justify-content:center;height:100%;box-sizing:border-box;">'
        f'<p style="font-size:36px;color:{COR_DESTAQUE};margin:0 0 20px;letter-spacing:4px;text-transform:uppercase;">'
        'Castelinho de Imbé</p>'
        '<h1 style="font-size:150px;line-height:1.05;margin:0 0 40px;">Castelinho — Galeria 3D</h1>'
        f'<p style="font-size:44px;margin:0 0 16px;">Atualizado em {esc(data_txt)}</p>'
        f'<p style="font-size:40px;color:{COR_SUAVE};margin:0 0 16px;">'
        'Comente nos objetos: use os comentários do Canva.</p>'
        f'<p style="font-size:30px;color:{COR_SUAVE};margin:0;">Contém spoilers do jogo.</p>'
        '</div>'
    )
    notas = 'Capa da galeria. Contém spoilers do jogo. Comente nos objetos usando os comentários do Canva.'
    return pagina('Capa', notas, corpo)


def divisoria(nome, qtd):
    texto_qtd = '1 objeto' if qtd == 1 else f'{qtd} objetos'
    corpo = (
        '<div style="display:flex;flex-direction:column;justify-content:center;height:100%;box-sizing:border-box;">'
        f'<h1 style="font-size:160px;line-height:1.05;margin:0;color:{COR_DESTAQUE};">{esc(nome)}</h1>'
        f'<p style="font-size:44px;color:{COR_SUAVE};margin:30px 0 0;">{texto_qtd}</p>'
        '</div>'
    )
    return pagina(nome, f'Divisória do grupo {nome}: {texto_qtd}.', corpo)


def pagina_objeto(o, base):
    nome = o.get('nome') or o.get('id') or 'Sem nome'
    onde = o.get('onde') or '—'
    arquivo = o.get('arquivo') or '?'
    linha = o.get('linha')
    codigo = f'{arquivo}:{linha}' if linha else arquivo
    notas = [n.strip() for n in (o.get('notas') or []) if isinstance(n, str) and n.strip()]

    fotos = []
    for rel in o.get('fotos') or []:
        ok = foto_no_disco(rel)
        if ok:
            fotos.append(ok)
        else:
            PULADAS.append(rel)
    fotos = fotos[:MAX_FOTOS]

    local = foto_no_disco(o.get('local'))
    if o.get('local') and not local:
        PULADAS.append(o.get('local'))

    # Cabeçalho: nome, onde fica, código; à direita, quadro amarelo com as dúvidas.
    bloco_texto = (
        f'<h1 style="font-size:84px;line-height:1.05;margin:0 0 20px;">{esc(nome)}</h1>'
        f'<p style="font-size:36px;margin:0 0 12px;"><strong style="color:{COR_DESTAQUE};">Onde fica:</strong> {esc(onde)}</p>'
        f'<p style="font-size:30px;margin:0;color:{COR_SUAVE};"><strong>Código:</strong> <code>{esc(codigo)}</code></p>'
    )
    if notas:
        itens = ''.join(f'<li style="margin:0 0 8px;">{esc(n)}</li>' for n in notas)
        quadro = (
            f'<div style="width:640px;flex:none;box-sizing:border-box;background:{BG_NOTA};'
            f'border:3px solid {BORDA_NOTA};border-radius:16px;padding:24px 30px;color:{COR_NOTA};overflow:hidden;">'
            f'<h2 style="font-size:32px;margin:0 0 12px;color:{COR_NOTA};">Pontos de dúvida</h2>'
            f'<ul style="margin:0;padding-left:28px;font-size:26px;line-height:1.35;">{itens}</ul>'
            '</div>'
        )
    else:
        quadro = ''
    cabecalho = (
        f'<div style="display:flex;gap:60px;align-items:flex-start;">'
        f'<div style="flex:1;min-width:0;">{bloco_texto}</div>{quadro}</div>'
    )

    blocos = [cabecalho]

    if fotos:
        celulas = ''
        for i, rel in enumerate(fotos):
            alt = f'{nome} — foto {i + 1}'
            src = esc(url_absoluta(base, rel))
            celulas += (
                '<div style="flex:1;min-width:0;height:260px;border-radius:12px;overflow:hidden;">'
                f'<img src="{src}" alt="{esc(alt)}" '
                'style="display:block;width:100%;height:260px;object-fit:cover;"></div>'
            )
        blocos.append(f'<div style="display:flex;gap:30px;">{celulas}</div>')

    if local:
        src = esc(url_absoluta(base, local))
        blocos.append(
            f'<div><p style="font-size:26px;color:{COR_DESTAQUE};margin:0 0 10px;'
            'text-transform:uppercase;letter-spacing:3px;">Onde fica</p>'
            f'<img src="{src}" alt="{esc(nome + " — onde fica")}" '
            'style="display:block;width:100%;height:330px;object-fit:cover;border-radius:14px;"></div>'
        )

    corpo = (
        '<div style="display:flex;flex-direction:column;gap:30px;height:100%;box-sizing:border-box;">'
        + ''.join(blocos) + '</div>'
    )

    partes = [f'Onde fica: {onde}', f'Código: {codigo}']
    if notas:
        partes.append('Pontos de dúvida:\n' + '\n'.join(f'- {n}' for n in notas))
    return pagina(nome, '\n'.join(partes), corpo)


def main():
    ap = argparse.ArgumentParser(description='Gera galeria/canva.html para importar no Canva.')
    ap.add_argument('--base', default=BASE_PADRAO, help='URL absoluta de galeria/ publicada')
    ap.add_argument('--manifesto', default=os.path.join(GALERIA, 'manifesto.json'))
    ap.add_argument('--saida', default=os.path.join(GALERIA, 'canva.html'))
    args = ap.parse_args()

    base = args.base.replace(' ', '%20')
    if not base.endswith('/'):
        base += '/'
    try:
        with open(args.manifesto, encoding='utf-8') as f:
            manifesto = json.load(f)
    except (OSError, ValueError) as e:
        sys.exit(f'Erro ao ler {args.manifesto}: {e}')

    objetos = [o for o in (manifesto.get('objetos') or []) if isinstance(o, dict)]
    conhecidos = {g for g, _ in GRUPOS}

    paginas = [capa(data_br(manifesto.get('gerado')))]
    for chave, nome in GRUPOS:
        do_grupo = [o for o in objetos if o.get('grupo') == chave]
        paginas.append(divisoria(nome, len(do_grupo)))
        paginas.extend(pagina_objeto(o, base) for o in do_grupo)

    outros = [o for o in objetos if o.get('grupo') not in conhecidos]
    if outros:
        paginas.append(divisoria('Outros', len(outros)))
        paginas.extend(pagina_objeto(o, base) for o in outros)

    doc = (
        '<!doctype html>\n<html lang="pt-BR">\n<head>\n<meta charset="utf-8">\n'
        '<meta name="viewport" content="width=device-width, initial-scale=1">\n'
        '<title>Castelinho — Galeria 3D (Canva)</title>\n'
        '<style>html,body{margin:0;padding:0;background:#121214;}</style>\n'
        '</head>\n<body>\n'
        + '\n'.join(paginas)
        + '\n</body>\n</html>\n'
    )

    with open(args.saida, 'w', encoding='utf-8') as f:
        f.write(doc)

    print(f'{args.saida}: {len(paginas)} páginas, {len(objetos)} objetos, base {base}', file=sys.stderr)
    if PULADAS:
        print('Fotos ausentes puladas: ' + ', '.join(str(p) for p in PULADAS), file=sys.stderr)


if __name__ == '__main__':
    main()
