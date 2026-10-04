# Revisão gráfica independente (direção de arte técnica)

> Revisão feita sem compromisso com decisões anteriores. Primeiro capturei tudo, depois escrevi a crítica e só então
> corrigi, do maior impacto para o menor. **A identidade não mudou:** a interface continua Flash dos anos 2000, o
> mundo 3D continua low-poly com texturas pixeladas (filtro nearest) e a corrupção continua sendo o motor do terror.
> O que mudou é a execução.

**Capturas:** `build/capturas/revisao/` (não versionada). Para refazer:

```
# por câmera Cam_* (castelinho) — época 0..3, corruption
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cam.gd -- \
    res://world/niveis/castelinho.tscn build/capturas/revisao/depois/e3 Cam_drone,Cam_frontal,Cam_esquina 3 0
# foto real x jogo, lado a lado (precisa das fotos de docs/pesquisa/refs/)
python3 tools/comparar_fotos.py build/capturas/revisao/depois build/capturas/revisao/depois/cmp
```

* `antes/`: estado recebido. `depois/`: estado final. `folhas/`: folhas de contato (várias capturas numa imagem).
* `antes/cmp/` e `depois/cmp/`: foto real à esquerda, jogo à direita (drone, frontal, esquina, torres, aérea 2019,
  núcleo 1950).

---

## 1. Inventário

Capturei:

* **Exterior do Castelinho em 2020:** drone, frontal, esquina, torres, aérea, fundos, spawn e deck.
* **Interiores:** hall, Povos Originários, Meio Ambiente, corredor, Salão de Arte, Sala do Pescador (2 vistas),
  escada, topo da torre, terraço, Torre B e Sala Medieval (2 vistas).
* **Épocas:** 1950, 1975 e 2019, em 6 a 7 vistas cada.
* **Ato II:** salas 26 a 30, de 2 a 3 ângulos cada.
* **Barra:** 4 ângulos.
* **Corrupção:** 0, 0,3, 0,6 e 0,9, por fora e por dentro.
* **Interface:** título (com e sem save), painel, quiz, quiz certo, fala do guia (normal e corrompida), placa 3D,
  diploma, morte, fim da demo e painel com corrupção.
* **Navegador real:** exportação Web com Chromium e SwiftShader (`antes/web/`).

## 2. Crítica priorizada

Impacto e esforço vão de 1 a 5. A prioridade é o impacto dividido pelo esforço, desempatada pelo impacto. As
evidências estão em `build/capturas/revisao/antes/`.

| # | Categoria | Problema | Evidência | Imp. | Esf. |
|---|---|---|---|---|---|
| 1 | Vegetação / fidelidade | **Pinheiros parecem "árvore de Natal de caixas"** (pilhas de placas verdes cada vez menores). Os *Pinus* reais das fotos têm tronco alto, reto e nu, e a copa escura e irregular fica em tufos no terço superior. É o elemento mais visível de todo o exterior. | `e3_Cam_drone`, `cmp/cmp_drone`, `e3_Cam_esquina` | 5 | 2 |
| 2 | Textura / fidelidade | **A parede parece tijolo comum de olaria.** Os "poros" pixelados de alto contraste viram ruído e a cor é laranja saturada. O real é um bloco rústico salmão-terroso, com variação suave de bloco a bloco e juntas claras pouco contrastadas. **Por dentro a textura é a mesma**, mas nas fotos o interior é bem mais claro, rosado e com junta cinza grossa. | `antes/cmp/cmp_esquina`, `e3_Cam_hall`, `e3_Cam_povos`, `refs/interior_sala_pescador_2026_beta.jpg` | 5 | 2 |
| 3 | Iluminação | **Nada ancora o prédio no chão.** Sem sombra nem oclusão, ele "flutua" no gramado e as faces ficam chapadas. Árvores e postes também não têm sombra. | `e3_Cam_frontal`, `e3_Cam_drone` | 5 | 3 |
| 4 | Bug visual | **Sala 25:** a cerca-viva norte atravessa o corredor de 1975 (um paralelepípedo verde na frente da câmera). **1950:** as luzes internas do prédio continuam acesas e fazem uma mancha laranja na areia. **1950, 1975 e 2019:** o recorte de papelão do visitante fica sozinho no lote ou nas dunas. | `e1_Cam_corredor1975`, `e0_Cam_nucleo1950`, `e0_Cam_spawn` | 4 | 1 |
| 5 | Céu / clima | **O céu é um degradê liso em todas as épocas.** As fotos têm cúmulos, e 1950 e 2019 pedem nuvem fechada com textura. O horizonte é uma faixa branca sem nada. | `e3_Cam_frontal`, `e2_Cam_drone`, `e0_Cam_drone` | 4 | 2 |
| 6 | Vegetação / fidelidade | **As hortênsias são caixas verdes com cubinhos coloridos e a cerca-viva é um paralelepípedo.** A árvore retorcida da frente são placas verdes soltas no ar. As hortênsias azul, branca e rosa são marca do lugar (fotos `torres_*` e `dim_*`). | `e3_Cam_torres`, `e3_Cam_esquina`, `e3_Cam_spawn` | 4 | 3 |
| 7 | Iluminação interior | **Os interiores têm luz chapada.** Os lustres não fazem poça de luz, o ambiente é uniforme e os cantos não escurecem. Como as salas 7 a 25 se passam quase todas dentro, isso pesa muito. | `e3_Cam_hall`, `e3_Cam_corredor`, `e3_Cam_povos` | 4 | 2 |
| 8 | Textura | **O piso interno é pedra azul-escura com junta marrom.** O real (fotos de interior) é laje de pedra cinza-clara e quente, com junta clara. | `e3_Cam_hall`, `refs/interior_galeria_arco_porta_2026_beta.jpg` | 3 | 1 |
| 9 | Fidelidade | **A cornija de mísulas é uma fileira de traços escuros.** No real, entre as mísulas há arquinhos (arcuação), e é isso que dá o desenho "de castelo" sob as ameias. | `e3_Cam_topo_torre`, `cmp/cmp_esquina`, `refs/dim_2026_torre_ameias_hibisco.jpg` | 3 | 2 |
| 10 | Proporção | **As torretas estão atarracadas.** Na Torre A, o fuste quase não passa das ameias e a pirâmide é íngreme demais: nas fotos o fuste sobe ~1,4 m acima das ameias e a pirâmide é baixa (~40°). Na Torre B, a torreta mal aparece acima do parapeito. | `cmp/cmp_frontal`, `cmp/cmp_drone` | 3 | 1 |
| 11 | Época 2019 | **A textura com musgo desbota o prédio até um cinza-esverdeado** e ele vira uma ruína de pedra genérica. Na aérea de 2019 o prédio continua avermelhado, só encardido. | `e2_Cam_drone`, `cmp/cmp_aerea2019` | 3 | 1 |
| 12 | Sala Medieval | **A lareira é um retângulo preto e os escudos são discos cinza.** No real há um capelo trapezoidal claro que sobe até o forro, um escudo redondo com machados e um brasão com águia. É a sala do quiz final e da armadura. | `e3_Cam_medieval`, `refs/ci_2025_sala_lareira_escudos.jpg` | 3 | 2 |
| 13 | Ato II | **Sala 26:** as paredes de reboco bege não lembram o hall da sala 7 (galeria de tijolo). Para o "errado" funcionar, o lugar precisa ser reconhecível. | `a2_26_0`, `e3_Cam_hall` | 3 | 2 |
| 14 | Ato II | **Sala 27:** as dunas e o céu claros e lavados deixam a imagem mais clara que o Ato I. É pouco opressivo, e a névoa é uma cortina cinza uniforme. | `a2_27_0`, `a2_27_m44` | 3 | 1 |
| 15 | Interface / fidelidade | **O castelo da tela de título é genérico** (duas torres iguais, sem torreta). Não lembra a silhueta do Castelinho: torre alta com torreta piramidal, arcada ameada e casa com telhado e letreiro. | `ui_titulo` | 3 | 2 |
| 16 | Terreno | **O gramado é um único tile uniforme**, com repetição visível do alto e sem as trilhas de terra batida das fotos. | `e3_Cam_drone`, `e3_Cam_aerea2019` | 2 | 2 |
| 17 | Terreno / composição | **As lajotas da calçada são grandes, claras e contrastadas.** No spawn elas puxam o olho para o chão em vez do castelo. | `e3_Cam_frontal`, `antes/web/02_inicio` | 2 | 1 |
| 18 | Época 1950 | **O núcleo tem janelas que são retângulos pretos**, sem caixilho nem veneziana. A foto antiga mostra venezianas de tábua. A parede tem um tom azulado estranho. | `e0_Cam_nucleo1950`, `cmp/cmp_nucleo1950` | 2 | 1 |
| 19 | Entorno | **As casas vizinhas são carimbos idênticos** (caixa e pirâmide), com a mesma porta e duas janelas. | `e3_Cam_aerea2019` | 2 | 2 |
| 20 | Ferramentas | **Duas câmeras de conferência estão inutilizadas:** `Cam_deck` está colada no painel P04 e `Cam_topo_torre` na torreta. Sem elas não dá para revisar essas salas. | `e3_Cam_deck`, `e3_Cam_topo_torre` | 1 | 1 |
| 21 | Mobília 1975 | **O sofá, as poltronas e a estante são blocos de cor chapada.** Ficam aceitáveis no estilo, mas são o ponto mais "cinza de protótipo" da época. | `e1_Cam_medieval` | 2 | 3 |
| 22 | Pós-processamento | Avaliado e **sem ação**. A rampa 0 → 0,3 → 0,6 → 0,9 é progressiva e legível (vinheta, dessaturação, pontilhado, pixelização em 240 linhas e glitch). A imagem fica intacta em 0. | `folhas/antes_barra_corr` | – | – |
| 23 | Interface | Avaliado e **sem ação**. Painel, quiz, diploma, morte e fim estão coesos e legíveis, no estilo Flash (contorno grosso, botões gel, Baloo e Comic Neue). | `folhas/antes_ui` | – | – |
| 24 | Desempenho | Medido: **56 a 115 draw calls** e ~20 mil triângulos por vista. Há folga para vegetação melhor e sombra falsa, mas não para sombras dinâmicas: no Compatibility, uma luz com sombra redesenha os objetos que ela ilumina. | saída de `captura_cam.gd` | – | – |

**Ordem de ataque:** 4 (bugs), 1, 2, 8, 3, 5, 10, 7, 6, 9, 11, 14, 13, 12, 15, 16, 17, 18, 20, 19 e 21.

---

## 3. Correções feitas

Cada linha cita a captura de antes e depois. Os pares lado a lado estão em
`build/capturas/revisao/antes_depois/ad_<captura>.png`, com o antes à esquerda e o depois à direita. As
comparações com as fotos reais estão em `antes/cmp/` e `depois/cmp/`.

| # | O que mudou | Como (arquivos) | Antes → depois |
|---|---|---|---|
| 1 | **Pinheiros *Pinus*.** O tronco é alto, nu e em prisma de 6 lados, com tocos de galho seco. A copa fica no terço de cima, feita de 8 a 10 tufos achatados e irregulares, com galhos aparentes. O sombreado vem da cor de vértice (claro em cima, escuro embaixo) e não há mais "caixas empilhadas". Os pinheiros ficaram menos densos a leste, onde nas fotos se vê o céu atrás do corpo principal. | `castelinho/entorno.gd` (`_pinus_mesh`, `prisma`, `_galho`) e o novo primitivo `Malha.bolha`/`tri_cores` em `castelinho/malha.gd` | `ad_e3_Cam_drone`, `ad_e3_Cam_esquina` |
| 2 | **Parede fiel às fotos.** Os "poros" de alto contraste saíram. Os blocos ficaram salmão-terrosos, com variação suave e alguns blocos queimados ou pálidos, e a junta clara ficou com pouco contraste. O **interior ganhou textura própria** (`parede_interna`): mais clara e rosada, com junta cinza grossa, como nas fotos de dentro. | `tools/gerar_texturas.py` (`_parede_base`, `parede_interna`) e `castelinho/castelinho.gd` | `ad_e3_Cam_esquina`, `ad_e3_Cam_hall`, `ad_e3_Cam_povos` |
| 3 | **O prédio assenta no chão.** (a) O novo shader de parede faz uma oclusão falsa no pé: escurece até 1,5 m acima do chão por fora e 1 m por dentro. (b) Há **sombras pintadas no chão**: uma imagem L8 pequena por época, com a sombra projetada de cada volume pelo Sol da época, a oclusão no pé e a sombra das copas, num único quadrilátero em modo MULTIPLICAR. Custa 1 draw call. Em 1950 e 2019 (nublado) fica só a oclusão. Em 1975 o Sol baixo dá sombras compridas. | `shaders/parede_tri.gdshader`, `castelinho/sombras.gd` (novo, `SombrasChao`), `world/niveis/castelinho.gd` (`_montar_sombras`) | `ad_e3_Cam_drone`, `ad_e1_Cam_drone`, `ad_e3_Cam_frontal` |
| 4 | **Céu com nuvens de desenho.** É um shader de céu com uma camada de nuvens em 3 tons chapados e contorno. Em 2020 são cúmulos soltos; em 1975, nuvens acesas pelo pôr do sol; em 1950 e 2019, céu fechado. O mapa de radiância tem 32 px e só é refeito quando a época muda. | `shaders/ceu_nuvens.gdshader`, `assets/textures/nuvens.png` e `world/niveis/castelinho.gd` (`CEUS`) | `ad_e3_Cam_frontal`, `ad_e0_Cam_nucleo1950`, `ad_e2_Cam_frontal` |
| 5 | **Bugs.** (a) A cerca-viva norte atravessava o corredor de 1975: ganhou um vão, fechado por um trecho que só existe em 2019 e 2020. (b) As luzes internas acendiam em 1950 e faziam uma mancha laranja na areia: agora cada luz só existe na sua época (`_luz_existe`). (c) O recorte do visitante ficava sozinho nas dunas: agora só aparece em 2020. | `castelinho/entorno.gd`, `world/niveis/castelinho.gd` | `ad_e1_Cam_corredor1975`, `ad_e0_Cam_nucleo1950` |
| 6 | **Vegetação do jardim.** As hortênsias viraram arbustos redondos com cachos azuis, lilases, brancos e rosas. Diante do anexo e da torre há agora um maciço contínuo, como nas fotos de 2026. A cerca-viva e as moitas viraram arbustos arredondados. A árvore retorcida da frente ganhou tronco inclinado, galhos em leque e copa rala em guarda-chuva. | `castelinho/extras.gd` (`_hortensias`), `castelinho/entorno.gd` (`_cerca_viva`, `_lote`) | `ad_e3_Cam_torres`, `ad_e3_Cam_frontal` |
| 7 | **Torretas esbeltas.** O fuste da Torre A sobe até 9,2 m (antes 8,4), com ápice a 10,3 m e pirâmide mais baixa. Na Torre B, o fuste vai a 8,0 m e o ápice a 8,9 m. As duas ganharam uma fresta em arco no alto do fuste. Medido nas fotos frontal e esquina de 2026. | `castelinho/medidas.json` (e a cópia embutida) e `castelinho/casco.gd` | `antes/cmp/cmp_frontal` → `depois/cmp/cmp_frontal` |
| 8 | **Cornija com arcuação.** Entre as mísulas há agora arquinhos claros, o desenho "de castelo" das fotos sob as ameias. | `castelinho/castelinho.gd` (`cornija`, `_arquinho`) | `depois/cmp/cmp_esquina` |
| 9 | **Piso interno e calçada.** O piso interno virou laje de pedra cinza-clara e quente, com junta clara (antes era azul-escuro). As lajotas da calçada ficaram menores e menos contrastadas e pararam de roubar o primeiro plano do spawn. O gramado perto do lote virou uma grade com variação de cor (manchas secas) e trilhas de grama pisada ao longo do caminho dos painéis. | `tools/gerar_texturas.py`, `castelinho/entorno.gd` (`_gramado`) | `ad_e3_Cam_hall`, `ad_e3_Cam_spawn`, `ad_e3_Cam_drone` |
| 10 | **Iluminação interna e do Ato I.** As lâmpadas ficaram mais fortes e com queda mais rápida, o que dá poças de luz. O Sol de 2020 ficou mais alto, vindo do sul-sudeste, com ambiente neutro-quente. O Sol de 1975 virou um fim de tarde de verdade, baixo a oés-noroeste. Em 2019 a névoa diminuiu (a aérea de 2019 é nublada, não enevoada). | `world/niveis/castelinho.gd` (`AMBIENTES`, `_criar_luzes`) | `ad_e3_Cam_hall`, `ad_e1_Cam_drone`, `ad_e2_Cam_aerea2019` |
| 11 | **2019 continua vermelho.** O musgo agora fica em manchas e escorridos, sem desbotar o prédio para cinza-esverdeado. As "varetas" verdes do mato viraram touceiras de capim com lâminas, do pé escuro até a ponta de palha. | `tools/gerar_texturas.py` (`parede_musgo`), `castelinho/extras.gd` (`_touceira`) | `ad_e2_Cam_aerea2019`, `ad_e2_Cam_frontal` |
| 12 | **Sala Medieval.** Ganhou capelo trapezoidal claro até o forro, consolo de madeira, escudo redondo de tábuas com machados cruzados, brasão com águia, e escudo com espadas (foto `ci_2025_sala_lareira_escudos`). | `castelinho/mobilia.gd` | `ad_e3_Cam_medieval` |
| 13 | **Sala de 1975 (salas 24 e 25).** Recebeu sofá de braços com almofadas mostarda, tapete com barra, poltronas, mesa de pés palito, estante com lombadas, abajur de pé aceso, TV de madeira e quadro de pôr do sol. | `castelinho/mobilia.gd` (`_veraneio_1975`) | `ad_e1_Cam_medieval` |
| 14 | **Núcleo de 1950 fiel à foto antiga.** A pedra ficou pálida e arenosa (`parede_nucleo`), sem o tom azulado. As janelas viraram venezianas de tábua clara com verga de pedra, e a porta ganhou a folha aberta. O Ato II (salas 27 e 28) usa a mesma pedra, para o núcleo ser o mesmo prédio nos dois níveis. | `tools/gerar_texturas.py`, `castelinho/extras.gd`, `castelinho/castelinho.gd` (`veneziana_fechada`), `world/niveis/ato2.gd` | `ad_e0_Cam_nucleo1950`, `depois/cmp/cmp_nucleo1950` |
| 15 | **Ato II.** O hall da sala 26 agora usa os mesmos blocos do hall da sala 7: é reconhecível, e por isso o "errado" funciona. As dunas da sala 27 ficaram mais escuras e fechadas, com céu baixo cinza-esverdeado e névoa mais perto (antes eram mais claras que o Ato I). | `world/niveis/ato2.gd` | `ad_a2_26_0`, `ad_a2_27_0` |
| 16 | **Tela de título.** O castelo genérico virou a silhueta do Castelinho: pavilhão, anexo ameado com janelas geminadas, Torre A com a torreta esbelta piramidal, arcada de 5 arcos (a de entrada mais larga), corpo do letreiro com telhado de uma água e chaminé, Torre B ao fundo, e faixas de mísulas e ameias. Continua chapado, com contorno grosso de Flash. | `ui/tela_titulo.gd` (`_castelo`) | `ad_ui_titulo` |
| 17 | **Acervo e sustos.** O pinguim, as conchas, a tartaruga, o boto de pano e a vértebra de baleia ficaram arredondados, e há um banner de educação ambiental (genérico). O recorte de papelão do Quico agora é o mascote da interface (topete, babador, olho vermelho e apito), e não um boneco de neve cinza. As peças internas avulsas foram para a camada 2 (sem Sol pelo telhado). | `castelinho/mobilia.gd`, `world/niveis/castelinho.gd` | `ad_e3_Cam_ambiente` |
| 18 | **Desempenho (bug de draw calls).** Ver a seção 5. | `world/painel_3d.gd`, `shaders/placa_cor.gdshader`, `world/niveis/ato2.gd`, `world/niveis/castelinho.gd` | `ad_corr0.6_Cam_frontal` |
| 19 | **Ferramentas.** As câmeras `Cam_deck` e `Cam_topo_torre` foram reposicionadas (estavam coladas num painel e na torreta). `tests/captura.gd` agora imprime draw calls e triângulos. Novo `tools/comparar_fotos.py`, que monta a foto real e o jogo lado a lado. | `world/niveis/castelinho.gd`, `tests/captura.gd` | `ad_e3_Cam_...` |

**No navegador real** (exportação Web, Chromium com WebGL2 e SwiftShader): o título, a entrada, a caminhada e o
olhar ao redor rodam sem erro no console. Os shaders novos (céu, parede, placa) compilam em WebGL2. Evidência:
`antes_depois/ad_web_0*.png`.

## 4. O que ficou de fora, e por quê

| Item | Por quê |
|---|---|
| Sombras dinâmicas de verdade (prédio sobre si mesmo, árvores sobre o prédio) | No Compatibility/WebGL2 uma luz com sombra redesenha a cena para o mapa de sombra e dobra os draw calls. As sombras pintadas cobrem o chão. As faces do prédio continuam sem sombra própria, com a sombra só implícita pela orientação ao Sol. |
| Oclusão nos cantos do forro | As paredes internas vão do chão ao forro em quads únicos e a altura do forro varia por cômodo. Escurecer o alto exigiria refazer `Muros.muro` com cor por vértice. Ficou só a oclusão no pé, que dá mais retorno. |
| Fachadas norte e oeste, telhados e escadas internas | Não há foto. Continuam como invenção plausível (LEIAME). |
| Vidros da arcada (reflexo escuro das fotos) | Um vidro escuro e refletivo pede reflexo ou cubemap. Ficou o vidro cinza translúcido. |
| Pessoas e carros no entorno, fios de poste | São ruído visual sem ganho para o jogo. Os fios de poste das fotos deixariam o enquadramento confuso. |
| Barra: os prédios do horizonte (vista de costas) são caixas chapadas sem janela; a vista `barra_m70` tem ~69 mil triângulos | A vista é secundária: o jogador olha o rio. Os triângulos vêm da água ou dos molhes do próprio nível da Barra, e não mexi na malha para não arriscar o minigame da tarrafa. Fica registrado para quem cuidar da Barra. |
| Mobília da Sala do Pescador e do acervo além do já feito; cavaletes do Salão de Arte | Leem bem no estilo e não são prioridade. |
| Figura Branca (cone translúcido com véu) | A leitura funciona no escuro da casa (`r2/figura.png`). Mexer nela é mexer no susto e na regra de visão, fora do escopo gráfico seguro. |

## 5. Desempenho (medido)

As medidas vêm de `RenderingServer.get_rendering_info` (`TOTAL_DRAW_CALLS_IN_FRAME` e
`TOTAL_PRIMITIVES_IN_FRAME`) em `tests/captura_cam.gd` e `tests/captura.gd`, renderizador `opengl3`, em
1280x720.

**Achado importante:** havia um bug de desempenho no projeto. O `Painel3D` se reconstrói a cada mudança de
`corruption`, e as peças novas perdiam o `visibility_range_end` que o nível tinha posto. Assim, **assim que a
corruption passava de 0, todos os ~25 painéis do Ato I eram desenhados de qualquer distância.** No Ato II, a casa,
a arcada e a Sala Medieval eram desenhadas já no hall, atrás de portas fechadas.

Correções:

* `Painel3D.alcance`: propriedade opcional, sem mudar a API. O alcance é reaplicado a cada reconstrução.
* As 6 a 7 caixas da moldura de cada placa viraram **uma** malha com cor por vértice (`shaders/placa_cor.gdshader`).
  O resultado é idêntico pixel a pixel, conferido por captura.
* O Ato II ganhou alcances de visibilidade só de renderização: casa a 70 m; arcada, porta final e Sala Medieval a
  46 m, um pouco além do fim da névoa da arcada.

| Cena / vista | Draw calls antes | Draw calls depois | Triângulos antes | Triângulos depois |
|---|---|---|---|---|
| Castelinho 2020, exterior (corruption 0) | 73–104 | 80–97 | ~20 mil | ~39 mil |
| Castelinho 2020, interiores (corruption 0) | 56–115 | 66–100 | ~20 mil | ~39 mil |
| Castelinho 2020, frontal (corruption 0,3) | **355** | **88** | 24 mil | 39 mil |
| Castelinho 2020, Salão de Arte, Checkpoint_11 (corruption 0,3) | **228** | **134** | 23 mil | 40 mil |
| Castelinho 1950 | 3–15 | 14 | 2,8 mil | 3,0 mil |
| Castelinho 1975 | 26–49 | 29–50 | 6–17 mil | 21–34 mil |
| Castelinho 2019 | 20–46 | 44–46 | 5–17 mil | ~33 mil |
| Ato II, hall (sala 26) | **249** | **84** | 53 mil | 30 mil |
| Ato II, dunas (sala 27) | 210 | 96 | 47 mil | 38 mil |
| Ato II, casa (sala 28) | 174 | 129 | 46 mil | 39 mil |
| Ato II, arcada (sala 29) | 135 | 118 | 32 mil | 26 mil |
| Barra (sem mudança) | 53–103 | 53–103 | 1,6–69 mil | 1,6–69 mil |

**O que custa cada novidade:**

* **Pinheiros:** dobraram os triângulos, de ~20 para ~39 mil, quase tudo no MultiMesh. Ainda é pouco para WebGL2 e
  continuam sendo 3 MultiMesh com 2 superfícies cada.
* **Sombras pintadas:** 1 draw call, 2 triângulos e 4 imagens de 360x360 geradas em tempo de carga.
* **Céu:** o mapa de radiância só é refeito quando a época troca.
* **Shader de parede:** 3 leituras de textura, como o triplanar padrão.
* **Luzes:** nenhuma luz nova. Continuam no máximo 5 `OmniLight3D` ativas, agora só as da época certa.
