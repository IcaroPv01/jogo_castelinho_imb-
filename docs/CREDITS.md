# Créditos e licenças

Regra do projeto (PLANO §3.5): só entram assets com licença CC0/MIT/OFL, ou CC-BY com crédito aqui. Tudo que aparece abaixo está no repositório.

## Fontes (SIL Open Font License 1.1)

As fontes ficam em `assets/fonts/` junto com o texto da licença de cada uma (`OFL_<fonte>.txt`). A OFL permite uso, embutir em jogos e redistribuir; as fontes não são vendidas separadamente e nenhuma delas declara "Reserved Font Name".

| Fonte | Uso no jogo | Autoria / origem | Arquivo | Licença |
|---|---|---|---|---|
| **Baloo 2** | títulos, botões "gel", contador de salas | © 2019 The Baloo 2 Project Authors (Ek Type). https://github.com/EkType/Baloo2, via `google/fonts` (`ofl/baloo2`) | `Baloo2-Latin.ttf` | OFL 1.1, `OFL_baloo2.txt` |
| **Comic Neue** (Bold) | texto corrido, balões de fala, painéis | © 2014 The Comic Neue Project Authors (Craig Rozynski, Hrant Papazian). https://github.com/crozynski/comicneue, via `google/fonts` (`ofl/comicneue`) | `ComicNeue-Bold.ttf` (sem modificação) | OFL 1.1, `OFL_comicneue.txt` |
| **VT323** | erros de sistema, texto corrompido, fala de "???" | © 2011 The VT323 Project Authors (Peter Hull). via `google/fonts` (`ofl/vt323`) | `VT323-Latin.ttf` | OFL 1.1, `OFL_vt323.txt` |
| **Arimo** | moldura institucional (caixa "sistema", rodapés, fontes dos painéis) | © 2026 The Arimo Project Authors. https://github.com/googlefonts/arimo, via `google/fonts` (`ofl/arimo`) | `Arimo-Latin.ttf` | OFL 1.1, `OFL_arimo.txt` |

Modificação: Baloo 2, VT323 e Arimo foram reduzidas ao subconjunto **Latin** (letras com acento do português, pontuação e símbolos básicos) com `pyftsubset` (fontTools) para pesar menos no navegador. Os eixos variáveis (`wght`) foram mantidos. Baloo 2 é usada em peso 800 (ExtraBold) e Arimo em 500, via `FontVariation`.

## Imagens

- **Mascotes** (`assets/ui/mascotes/*.svg`: Bentinho, Tainá, Quico e as variantes `_corrompido`) e **ícones dos painéis** (`assets/ui/icones/*.svg`): desenhos **originais** do projeto, escritos em SVG pelo script `tools/gerar_mascotes.py`. Não derivam de nenhum personagem ou marca existente. A "Turma da Memória" é fictícia.
- Nenhum brasão, logotipo ou marca da Prefeitura de Imbé, nem de qualquer outra instituição, foi usado. O emblema da tela de título é uma estrela genérica.
- O cenário da tela de título (castelo, nuvens, morros) é desenhado por código (`ui/tela_titulo.gd`).
- **Texturas do mundo 3D** (`assets/textures/*.png`): todas **geradas por código** pelo script `tools/gerar_texturas.py` (numpy + Pillow), sem fotos nem texturas de terceiros. Inclui as da revisão gráfica: `parede_interna`, `parede_nucleo`, `tabuas_claras`, `nuvens` e `banner_ambiental` (um banner genérico, sem marca real). As cores da pedra foram medidas nas fotos de referência, que servem só de consulta (não entram no jogo).
- **Arte da história do Tito** (`assets/ui/tito/*.png`): os 7 desenhos de giz de cera, o cartaz "PROCURA-SE" e as marcas de altura são **gerados por código** por `tools/gerar_desenhos.py` (numpy + Pillow; só usa as fontes OFL já listadas e fontes do sistema para o cartaz). Nenhuma imagem, foto ou desenho de terceiros. Tito, a mãe e o cartaz são fictícios; o telefone "4-27" é inventado.
- **Shaders** (`shaders/*.gdshader`: céu com nuvens, parede triplanar com oclusão falsa, moldura das placas, pós-processamento, água, PSX): escritos para o projeto.

## Áudio

Todos os sons (`assets/audio/*`) são **sintetizados** pelo script `tools/gerar_audio.py` (Python + numpy; os arquivos `.ogg` são codificados com `ffmpeg`/libvorbis). Não há nenhuma amostra, trecho de música ou efeito de terceiros. O jingle institucional é uma melodia original em Dó maior, com marimba, xilofone, baixo e percussão sintéticos; o hino municipal **não** é usado. Os sons da versão 2 (`chuva`, `goteira`, `agua_sobe`, `crianca_ei`, `telefone_voz` e `atencao`) também saem de `tools/gerar_audio.py`: a "voz" da criança e a da mãe ao telefone são só ruído filtrado em formantes, sem nenhuma gravação ou síntese de voz realista; o texto vai na tela.

## Textos

Os textos dos painéis (`data/paineis.json`) são escritos pelo projeto. Cada fato traz o campo `fonte` com o link de onde foi retirado; as fontes e o grau de confiança de cada fato estão em `docs/pesquisa/historia_imbe.md` e `docs/pesquisa/castelinho.md`. As citações curtas ("De início, era só esse miolo aqui...") vêm da reportagem da Beta Redação (Unisinos), citada no próprio painel. Wikipédia (CC BY-SA 4.0) aparece só como fonte de consulta; nenhum trecho foi copiado.
