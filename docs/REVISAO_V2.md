# Revisão de arte e experiência da V2 (direção de arte técnica, independente)

> Revisão sem compromisso com as decisões anteriores, feita a pedido do dono ("o jogo tem que ser um pouco mais lento até
> ficar bizarro"). Processo: inventário de capturas → crítica priorizada → correções por ordem de impacto, cada uma com
> antes/depois. **O estilo não muda:** interface Flash dos anos 2000, 3D low-poly com textura pixelada, corrupção como
> motor do terror, prédio fiel às fotos, e a história do Tito (fictício) pesada **só por sugestão**.
>
> **Estado:** ver §5 (atualizado a cada etapa; se esta revisão for interrompida, retome por lá).

**Capturas:** `build/capturas/revisao_v2/` (não versionada). `antes/` = estado recebido (commit `25e1724`), `depois/` =
estado final, `folhas/` = folhas de contato (várias capturas numa imagem; linhas = visitas 1 a 4).

Como refazer (o `captura_cam.gd` agora leva a lanterna e as lâmpadas próximas junto com a câmera, como no jogo):

```
# castelinho: <cena> <prefixo> <cams> <época 0-4> <corruption> <visita 1-4> [flags]
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cam.gd -- \
    res://world/niveis/castelinho.tscn build/capturas/revisao_v2/depois/v3_e3 Cam_spawn,Cam_hall 3 0.38 3
# porão: <prefixo> <semente> <índices 0-18> [água] [época] [vista]
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_porao.gd -- \
    build/capturas/revisao_v2/depois/porao/p 777 0,1,2,3 -1 3 ini
```

Corrupção usada em cada visita (meio da curva de `GameState.corruption_por_sala`): V1 = 0, V2 = 0,16, V3 = 0,38,
V4 = 0,58, porão = 0,5 (a ferramenta), Braço Morto = 0,4 (o nível fixa).

---

## 1. Inventário

| O quê | Capturas (`antes/`) | Folha |
|---|---|---|
| Exterior nas 4 visitas: spawn, frontal, drone | `v{1..4}_e3_Cam_{spawn,frontal,drone}` | `folhas/antes_visitas_spawn_frontal_drone.png` |
| Interiores nas 4 visitas: hall, corredor, Salão de Arte, Sala Medieval, Povos, Acervo, escada, Sala do Pescador | `v{1..4}_e3_Cam_*` | `folhas/antes_visitas_*.png` |
| Época 1967 (obra, Tito, muro, barco) | `v2_e4_Cam_{obra1967,tito1967,buraco1967,drone,frontal,spawn,hall}` | `folhas/antes_1967.png` |
| Peças das visitas 3 e 4: porta do Ato II, corredor 1975, porta zebrada, escada 2019, painel solto | `v3_e1_*`, `v4_e2_*`, `v4_e3_*` | `folhas/antes_v34_especificos.png` |
| Porão: as 19 salas (semente 777) | `porao/p_<i>_<tipo>` | `folhas/antes_porao.png` |
| Braço Morto (noite e disco sem data) | `braco/b_*`, `braco/b_semdata_*` | `folhas/antes_braco.png` |
| UI: Volte sempre (1ª e 2ª), Telefone, créditos, dedicatória, HUD com olho, Visor com a Figura (atenção 0 / 0,5 / 0,9) | `ui/*` | `folhas/antes_ui.png` |

Draw calls medidos: Castelinho 65–111 por vista (V3 corredor = 111, o pior), 1967 = 12–17, porão = 13–42 (2–4 luzes),
Braço Morto = 16–38. Todos dentro do orçamento (< 150).

## 2. Crítica priorizada

Impacto e esforço de 1 a 5. Prioridade = impacto ÷ esforço, desempate pelo impacto.

| # | Área | Problema | Evidência (`antes/`) | Imp. | Esf. |
|---|---|---|---|---|---|
| 1 | Leitura / bug | **A lanterna apaga a cada troca de cena.** O `Player` é recriado em `main.carregar_mundo` com a lanterna desligada, e nem o porão nem o Braço Morto a acendem. O jogador chega ao porão (o lugar mais escuro do jogo, desenhado em volta da lanterna) no breu, e só enxerga se lembrar do F. Nas salas sem tocha perto da entrada, a imagem é preta (`p_1_pedras`). | `porao/p_1_pedras`, `porao/p_0_escada`, `braco/b_Cam_tito` | 5 | 1 |
| 2 | Progressão | **Visita 4 por fora é um borrão preto.** A névoa é quase preta (0,10/0,12/0,15) e densa (0,026): ela não esconde, ela apaga. A silhueta do Castelinho some e o jogador não acha a entrada. O "pior que a visita 3" virou "não dá para ver", não "o Castelinho está errado". Falta o elemento óbvio da madrugada de chuva: **relâmpago**, que revela o prédio por um instante (susto + leitura). | `v4_e3_Cam_{spawn,frontal,drone,torres,esquina}` | 5 | 2 |
| 3 | Lanterna | **A lanterna estoura de perto e some de longe.** Ângulo de 28°, sem queda suave na borda e energia 2,2: em parede a 1 m vira um disco branco que apaga o conteúdo (mural da Sala do Pescador na V4), e a 6 m quase não aparece. | `v4_e3_Cam_pescador`, `v3_e3_Cam_corredor` | 4 | 1 |
| 4 | Progressão | **Os interiores não escalam.** V1 e V2 são idênticos por dentro (as lâmpadas dominam e são iguais). A V3 ("noite, fechado para reforma") por dentro é só um pouco mais escura que a V1 e a lanterna quase não faz diferença; a V4 por dentro tem *mais* luz ambiente que a V3 (0,62 contra 0,42). | `folhas/antes_visitas_hall_corredor_salaarte`, `..._medieval_povos_acervo` | 4 | 1 |
| 5 | Progressão / beleza | **A noite da V3 é chapada.** Postes com lâmpada e nenhuma luz no chão, janelas do museu apagadas: a noite não é bonita nem guia o caminho. Uma noite de verdade tem poças de luz amarela na calçada e o museu aceso por dentro, que é o que chama o jogador para a porta. Na V4, a luz da rua falhando é o "pior". | `v3_e3_Cam_{frontal,spawn,drone}` | 4 | 2 |
| 6 | Portas importantes | **A porta zebrada do porão (sala 80) é um retângulo preto com duas fitas**, e a **escada de 2019 é uma grelha de ralo** no chão. O roteiro pede degraus que descem e água escorrendo; são as duas passagens mais importantes do jogo e não chamam o olho nem se leem como "descer". | `v4_e3_Cam_porta_porao`, `v4_e2_Cam_escada2019` | 4 | 2 |
| 7 | Braço Morto | **A cena final é preta e azul-marinho.** Os postes têm cabeça acesa mas não fazem poça; a água não reflete nada. A pesquisa (`braco_morto.md` §3, "Noite") pede luz amarela em poças no calçadão e **reflexos longos na água**: é a imagem que dá o "triste e bonito". O horizonte de casas é uma fila de caixas escuras. | `braco/b_Cam_{margem,pier,tito,lapide}` | 4 | 2 |
| 8 | Porão | **As chamas das tochas são pirâmides brancas** (cor de vértice branca): parecem facas ou velas de plástico, não fogo, e são o único ponto quente do porão. | `porao/p_3_abobada`, `porao/p_7_desenhos` | 3 | 1 |
| 9 | Visor | **A Figura no slide perto do máximo vira duas colunas rosadas.** A 1,15 m e com 2,4 m de altura, a cabeça sai do quadro e o que sobra é a saia; o pico do susto é ilegível. | `ui/visor_09` (comparar `ui/visor_05`) | 3 | 1 |
| 10 | UI / bug | **"Volte sempre" da 2ª vez: o texto se atropela** ("visita" por cima de "Volte"; "sempre..." cai fora da placa). | `ui/volte2` | 3 | 1 |
| 11 | Pistas | **O cartaz de PROCURA-SE é um selinho** de 34 cm no canto do painel: à noite, a 3 m, não se lê que é um cartaz de criança desaparecida. É o elemento narrativo central da visita 3. | `v3_e3_Cam_spawn` | 3 | 1 |
| 12 | 1967 | **A obra não parece obra.** O andaime é de barras pretas finas (o roteiro pede madeira), o "buraco no muro" é um vão retangular perfeito (parece porta, não buraco por onde um menino se enfia), o barco encalhado é uma forma azul chapada, e o topo dos muros é reto e limpo. | `v2_e4_Cam_{obra1967,buraco1967,spawn,drone}` | 3 | 2 |
| 13 | UI | **Telefone:** caixa pequena com fonte miúda no canto inferior; não há nada que diga "telefone" nem "chiado" na tela. | `ui/telefone` | 2 | 1 |
| 14 | Porão | Variedade das salas: as formas variam (abóbada, colunas, cisterna, poço, quarto), mas o breu uniforme as iguala. Com a lanterna (item 1) e as chamas (item 8) a diferença aparece; não mexo na geometria. | `folhas/antes_porao` | 2 | 3 |
| 15 | Braço Morto | A lápide de areia lê como cubos de açúcar sobre uma toalha; a câmera `Cam_escada` olha para a parede. | `braco/b_Cam_lapide`, `braco/b_Cam_escada` | 2 | 2 |
| 17 | Susto / ritmo | **O "primeiro medo real" (fim da visita 2) é mudo e limpo:** 2 s de preto com um clique, e a luz volta num fade suave. Sem som no escuro e sem falha na volta, o momento passa como transição, não como susto. | lógica de `_apagao_e_balde` | 3 | 1 |
| 18 | Leitura | **Os discos não chamam o olho.** O de 1967 é um botão vermelho parado em cima de uma caixa escura do acervo; o de 1975 some no escuro do topo da torre (visita 3). | `antes/v2_e3_Cam_acervo` | 3 | 1 |
| 16 | Avaliado, sem ação | Visita 1 (manhã) e visita 2 (fim de tarde) por fora: bonitas e distintas, com escala clara. Créditos e dedicatória: sóbrias, legíveis, sem susto (como o roteiro manda). Faixa de discos e olho de atenção: legíveis e no estilo Flash. Quarto do Tito (sala 95): o único lugar quente e seco, funciona. Draw calls: todos < 150. | `folhas/antes_ui`, `v1/v2_*` | – | – |

**Ordem de ataque:** 1, 3, 2, 4, 5, 8, 10, 11, 9, 6, 7, 12, 13, 15, 17, 18.

## 3. Correções feitas

(preenchido à medida que cada item é corrigido)

| # | O que mudou | Arquivos | Antes → depois |
|---|---|---|---|
| 1 | **A lanterna sobrevive à troca de cena.** O `Player` lê `tem_lanterna` e a nova flag `lanterna_desligada` (gravada quando o jogador aperta F) ao nascer: quem chega ao porão, ao Ato II ou ao Braço Morto com a lanterna acesa continua com ela acesa. O Quico limpa a flag ao entregar a lanterna, e o Castelinho respeita a escolha. | `player/player.gd`, `world/niveis/castelinho.gd` | `antes/porao/p_1_pedras` → `depois/porao/p_1_pedras`; `folhas/ad_porao.png` |
| 3 | **Lanterna nova.** Cone de 34° (antes 28°) com borda suave, queda com a distância mais lenta (`spot_attenuation` 0,5) e facho 10° para baixo: faz poça no chão a 3–8 m (o caminho) sem estourar a parede a 1 m. Continua sendo 1 SpotLight sem sombra. | `player/player.gd` | `antes/v3_e3_Cam_medieval` → `depois/...`; `antes/porao/p_9_colunas` → `depois/...` |
| 4 | **Escala por dentro.** Lâmpadas por visita: V1 1,0 × 5; V2 0,76 × 5, âmbar (fim de expediente); V3 0,62 × 3 (museu fechado: entre as poças fica escuro); V4 0,55 × 2, frias e falhando. Ambiente da V3 0,42 → 0,34 e da V4 0,62 → 0,30: agora a V4 é mais escura que a V3 por dentro, e nas duas quem mostra o caminho é a lanterna. | `world/niveis/castelinho.gd` (`LAMPADAS`, `COR_LAMPADA`, `PRESENTE`) | `folhas/antes_visitas_*` → `folhas/depois_visitas_*` |
| 2 | **Madrugada legível e pior.** Névoa da V4 de quase preta (0,10/0,12/0,15) para cinza-azulado de chuva (0,17/0,20/0,24) e céu mais claro no horizonte: o Castelinho vira silhueta escura contra a névoa, em vez de sumir. **Relâmpagos** a cada 7–15 s (dois clarões, o 2º mais fraco; menor dentro do prédio; só no presente) mostram o prédio inteiro por um instante, e um **trovão** sintetizado (`trovao`, novo) chega 0,6–2 s depois, mais baixo quanto mais longe. A luz da rua está **apagada** na V4 (falta de luz). | `world/niveis/castelinho.gd` (`_relampagos`, `_disparar_relampago`), `tools/gerar_audio.py` (`s_trovao`), `assets/audio/trovao.ogg`, `autoload/audio.gd` | `antes/v4_e3_Cam_frontal` → `depois/v4_e3_Cam_frontal` e `depois/v4_relampago_Cam_frontal`; idem `Cam_drone` |
| 5 | **Noite da V3 bonita e com caminho.** Os postes acendem em sódio e cada um faz uma poça de luz no chão e um cone fraco no ar (1 malha aditiva + 1 MultiMesh: 2 draw calls, nenhuma luz nova). As **janelas e a arcada do museu brilham** vistas de fora (vidros com material próprio e emissão preta por padrão; a V3 só troca a cor quando o jogador está fora): o museu "fechado" aceso por dentro puxa o jogador para a porta. Postes: apagados de dia (V1), acendendo no fim de tarde (V2), sódio (V3), mortos (V4). | `world/niveis/castelinho.gd` (`_montar_luz_da_rua`, `_atualizar_janelas`), `castelinho/castelinho.gd` (`mat_vidro`), `castelinho/entorno.gd` (`POSTES`) | `antes/v3_e3_Cam_frontal` → `depois/v3_e3_Cam_frontal`; `Cam_drone` |
| 8 | **Chamas das tochas do porão.** Duas pirâmides com cor de vértice (laranja → vermelho por fora, amarelo-claro → laranja por dentro), levemente tortas. Antes: pirâmides brancas. | `world/niveis/porao_salas.gd` (`chama`) | `antes/porao/p_3_abobada` → `depois/porao/p_3_abobada` |
| 10 | **"Volte sempre" estranho sem atropelo.** Os textos não quebram mais linha: a fonte encolhe até caber (`_caber`), também quando o texto muda no tremido. | `ui/volte_sempre.gd` | `antes/ui/volte2` → `depois/ui/volte2_1` |
| 11 | **Cartaz de PROCURA-SE em tamanho A3** (50 cm, antes 34 cm) e cobrindo um terço do texto do painel; a área de interação acompanha. | `castelinho/tito.gd` (`cartaz_sobre`), `world/niveis/castelinho.gd` | `antes/v3_e3_Cam_spawn` → `depois/v3_e3_Cam_spawn` |
| 9 | **A Figura no slide se debruça sobre a lente.** Para a ~2,6 m (antes 1,15 m) e inclina até 48° na direção da câmera a partir de metade da atenção: no pico, cabeça, ombros e braços abertos enchem o slide (antes: duas colunas rosadas). | `world/visor.gd` | `antes/ui/visor_09` → `depois/ui/visor_0.9` |
| 6 | **Porta zebrada e alçapão de 2019 com escada de verdade.** Novo `shaders/escada_falsa.gdshader`: mapeamento de interior (um raio caminha por uma escada virtual atrás do quad), com degraus de pedra, paredes de tijolo, um fio de água descendo e um brilho frio no fundo. 1 draw call, sem geometria nova, o chão e a parede continuam sólidos (a descida é pela interação, como antes). O alçapão ganhou borda de pedra. Os cavaletes do hall andaram 0,5 m para o leste: o terceiro cobria metade da porta. | `shaders/escada_falsa.gdshader`, `world/niveis/castelinho.gd` (`_escada_falsa`), `castelinho/mobilia.gd` | `antes/v4_e3_Cam_porta_porao` → `depois/v4_e3_Cam_porta_porao`; `antes/v4_e2_Cam_escada2019` → `depois/v4_e2_Cam_escada2019` |
| 7 | **Braço Morto: a noite "triste e bonita" da pesquisa.** As poças de luz eram quads opacos cor de mostarda: viraram manchas aditivas em degraus. A margem de lá ganhou calçada e uma fila de postes, e cada um tem **reflexo longo na água** (novo `shaders/reflexo_agua.gdshader`: faixa deitada na água que sempre aponta para a câmera, com marola; 1 MultiMesh). Horizonte e névoa um pouco mais claros: o casario recorta o céu. `Cam_escada` agora olha escada acima. | `world/niveis/braco_morto.gd` (`_margem_de_la`, `_tex_luzes`), `shaders/reflexo_agua.gdshader` | `antes/braco/b_Cam_{margem,tito,lapide,pier,escada}` → `depois/braco/...` |
| 12 | **A obra de 1967 parece obra.** Andaime de pinho cru (cor clara, varas de 14 cm, pranchas largas com rodapé), em vez de barras pretas; o buraco no muro ficou serrilhado (blocos meio quebrados avançando para dentro do vão), não uma porta; barco de madeira cinza-clara com costado verde-água desbotado; canteiro de obra novo: carrinho de mão, caixa de massa com enxada, monte de areia grossa, sacos de cimento e tábuas no chão. | `castelinho/obra.gd` (`_andaime`, `_barco`, `_muro_com_buraco`, `_canteiro`) | `antes/v2_e4_Cam_{spawn,buraco1967,obra1967}` → `depois/...`; `folhas/antes_1967` → `folhas/depois_1967` |
| 13 | **Telefone com cara de telefone.** Sobre a caixa "???" aparece uma plaquinha "LIGAÇÃO · LINHA 4-27" com um fone de gancho desenhado e uma onda de chiado que treme a 12 qps (mais alta quando a voz fala). Some quando a linha cai. | `ui/telefone.gd` | `antes/ui/telefone` → `depois/ui/telefone` |
| 15 | **Lápide de areia de criança.** O quadrado chapado virou um monte baixo e irregular, e as quatro "caixas com tampa" viraram torres de balde (tronco de cone de 8 lados com ameias de dedo). | `world/niveis/braco_morto.gd` (`_balde_de_areia`) | `antes/braco/b_Cam_lapide` → `depois/braco/b_Cam_lapide` |
| 17 | **Apagão do fim da visita 2.** No escuro, um sussurro baixinho (ainda é a visita 2: nada de grito); a luz volta falhando (acende, apaga, acende, com dois cliques) e só então firma. Mesma duração total, mesma lógica e mesmo balde. | `world/niveis/castelinho.gd` (`_apagao_e_balde`) | só som e tempo: sem captura |
| 18 | **Discos que se encontram.** O disco no chão gira devagar e, a cada ~2,5 s, pisca um brilho de 4 pontas pixelado (o "item" de jogo educativo Flash). Discreto de dia, visível no escuro. | `world/niveis/castelinho.gd` (`_animar_discos`, `_tex_brilho`) | `antes/v2_e3_Cam_acervo` → `depois/v2_e3_Cam_acervo` |
| – | **Ferramentas.** `captura_cam.gd` leva o jogador junto com a câmera (a lanterna e as lâmpadas mais próximas acompanham; antes as capturas de interior da V3/V4 tinham as lâmpadas escolhidas a partir do Spawn e nenhuma lanterna) sem disparar gatilhos de sala, e aceita `RELAMPAGO=0..1`. `captura_porao.gd` liga `tem_lanterna`. Câmera nova `Cam_calcada` (luz da rua) e `Cam_porta_porao`/`Cam_escada` (Braço Morto) reposicionadas. **As capturas `antes/` foram refeitas com as ferramentas novas sobre o código recebido**, para a comparação ser justa. | `tests/captura_cam.gd`, `tests/captura_porao.gd` | – |

## 4. O que ficou de fora, e por quê

| Item | Por quê |
|---|---|
| Teste no navegador das cenas novas (porta zebrada, alçapão, Braço Morto) | `tools/testar_web.py` só cobre o começo da visita 1 (passou sem erro de console, carga em 14,2 s contra 15,4 s do build recebido: sem regressão). Tentei rodar `captura_cam` dentro do build web (args `-s` no `GODOT_CONFIG`) e o Godot web ignorou o script. Os dois shaders novos usam só recursos do GLSL ES 3.00 (`inverse`, laço com `break`, uniforms `int`) e compilam no Compatibility do desktop; vale abrir a visita 4 e o Braço Morto num navegador de verdade antes de publicar. |
| Variedade das 19 salas do porão (item 14) | Com a lanterna e as chamas certas, as formas (abóbada, colunas, cisterna, poço, quarto, telefone) passam a se distinguir (`folhas/depois_porao`). Mexer na geometria das salas é mexer no gerador e nos testes do porão; fica para o agente do Porão se ainda parecer repetitivo jogando. |
| Interior da visita 2 com luz de pôr do sol entrando pelas janelas | O interior não recebe o Sol (camada 2, decisão da revisão anterior para não vazar luz pelo telhado). A V2 por dentro ficou distinta pela cor e pela força das lâmpadas; raios de sol falsos pelas janelas seriam o próximo passo. |
| Relâmpago dentro do Visor e no porão | O relâmpago só existe no presente da visita 4 (no Visor a época é outra; o porão não tem céu). |
| Som | Não há placa de som na nuvem: `trovao` foi conferido por nível (RMS por meio segundo, decai de 0,19 a 0,01 em 4 s) e pelo centro espectral; o sussurro do apagão reusa `sussurro`. Ajuste fino de volume em `VOLUME_PADRAO` (`autoload/audio.gd`). |
| Cones de luz dos postes vistos de cima (drone) | Cilindros aditivos de borda dura: de perto e na altura do olho leem como facho (estilo PS1, `depois/v3_e3_Cam_calcada`); do alto quase somem. Aceitável: o jogador nunca vê de cima. |
| Postes com luz de verdade | Orçamento web de 6 luzes: as poças e os cones são pintados (aditivos), não iluminam objetos. |


## 5. Estado da revisão

- [x] Inventário de capturas (`antes/`, `folhas/antes_*`)
- [x] Crítica priorizada (§2)
- [x] Correções (§3): 1 a 13, 15, 17 e 18 (o 14 ficou de fora, ver §4)
- [x] Testes: `tools/testar.sh` (8 testes) e `tools/testar_janela.sh` com "RESULTADO: OK" e sem "SCRIPT ERROR"; export web + `tools/testar_web.py` sem erro de console
- [x] Resumo final (§6)

## 6. Resumo final

**A escala agora sobe de visita em visita, e cada degrau é visível na mesma câmera** (`folhas/depois_visitas_*`, uma linha
por visita):

1. **Visita 1**, manhã: intacta (nada mudou de propósito; é a "bonita e inocente").
2. **Visita 2**, fim de tarde: lâmpadas âmbar e mais fracas por dentro (antes, igual à V1), postes acendendo.
3. **Visita 3**, noite: a cidade acesa em sódio, o museu aceso por dentro visto de fora (o que chama para a porta), e por
   dentro só três lâmpadas fracas: entre as poças fica escuro e a lanterna nova faz diferença.
4. **Visita 4**, madrugada: falta de luz na rua, duas lâmpadas frias falhando, névoa de chuva que recorta o Castelinho
   como silhueta e relâmpagos que o mostram inteiro por um instante, com trovão.
5. **Porão**: a lanterna chega acesa (antes, breu até o jogador lembrar do F) e as tochas são fogo.
6. **Braço Morto**: a noite triste e bonita da pesquisa, com poças amarelas e os reflexos longos na água.

**Leitura:** a lanterna ilumina o chão à frente sem estourar a parede; a porta zebrada e o alçapão se leem como escadas
que descem, com água; o cartaz de PROCURA-SE se lê a 3 m; os discos piscam.

**Peças novas:** a obra de 1967 tem andaime de madeira, buraco serrilhado e canteiro; a Figura no slide se debruça sobre
a lente no pico da atenção; a lápide é um castelinho de balde; o telefone tem fone e chiado na tela; o "Volte sempre"
estranho não se atropela.

**Ética:** nenhuma imagem de corpo, sangue ou violência; nenhum nome ou caso real. As mudanças de susto são de luz e som
(sussurro baixo, luz que falha, relâmpago).

**Orçamento web:** maior vista medida 116 draw calls (corredor da V3; era 111: +3 dos vidros com material próprio, +2 da luz da rua); porão ≤ 78, Braço Morto ≤ 27. Luzes: V3 = Lua + 3 lâmpadas + lanterna;
V4 = 1 + 2 + 1; porão = 4 + lanterna; Braço Morto = Lua + 3 postes + escada + lanterna (6). Texturas novas ≤ 64 px,
geradas em tempo de carga. Shaders novos: 2 (1 draw call cada uso).

**Arquivos de outras divisões tocados (sem mudar API pública, marcadores, ids de painel nem regras de criatura):**
`player/player.gd` (lanterna), `world/niveis/castelinho.gd`, `castelinho/{castelinho,entorno,mobilia,obra,tito}.gd`,
`world/niveis/{porao_salas,braco_morto}.gd`, `world/visor.gd` (só o posicionamento da Figura do slide), `ui/{telefone,volte_sempre}.gd`,
`autoload/audio.gd` (volume do `trovao`), `tools/gerar_audio.py` (`s_trovao`, no fim do catálogo, com gerador aleatório
próprio: os outros sons não mudam se forem regenerados), `tests/captura_{cam,porao}.gd`. Novos: `shaders/escada_falsa.gdshader`,
`shaders/reflexo_agua.gdshader`, `assets/audio/trovao.ogg`. Flag nova de save: `lanterna_desligada`.
