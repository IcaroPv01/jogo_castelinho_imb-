# Castelinho de Imbé — geometria, fotos e flashbacks (rodada 2)

Data da pesquisa: 04/10/2026. Continua o dossiê `castelinho.md`. Só fontes online; ninguém foi ao local. Tudo que está em `refs/` é referência privada (fora do git, direitos dos veículos e dos autores). Para baixar de novo: `bash docs/pesquisa/baixar_refs.sh`.

Convenção de confiança: **alta** = dado de fonte ou medida redundante; **média** = medida em foto com escala plausível, erro de 10 a 20%; **baixa** = leitura em foto oblíqua ou só uma foto, erro de 30% ou mais, tratar como chute informado.

---

## 0. O que mudou em relação ao dossiê (leia primeiro)

1. **Ruas.** A Av. Nilza Costa Godoy é a **antiga Av. Rio Grande** (Litoral na Rede, 16/05/2024: "Avenida Nilza Costa Godoy, antiga Rio Grande"). No OpenStreetMap a via ainda se chama "Avenida Rio Grande" (way 903024551, descrição "denominado pela Lei Municipal 1744/2016"). Ela é a avenida **diagonal, rumo ~19,5° (NNE)**, a **leste** do lote. A **Av. Garibaldi** é a via de **pista dupla com canteiro** que passa a **sul**, rumo ~287° (OSM ways 236493318 e 236493319, oneway, ~8,4 m entre os eixos das pistas). O Castelinho fica no **cruzamento das duas** (Garibaldi ao sul, Nilza a leste). Isso explica a legenda "Garibaldi com Rio Grande" do TripAdvisor e a "Av. Garibaldi" do nó OSM.
2. **Orientação das fachadas.** A arcada (5 arcos) olha para a **Av. Garibaldi (sul)**. O lado do letreiro "Castelinho", com as duas janelas de grade e a porta arqueada de madeira, olha para a **Av. Nilza (leste)**. Dedução a partir das fotos `aerea_2019_litoralnarede.jpg`, `jpl_2021_aerea_drone_fachadas.jpg` e `lnr_2026_frontal_esquina_ivan.jpg` (foto tirada da esquina) cruzadas com o satélite. Confiança média.
3. **Alturas das torres.** O dossiê dizia 8 a 10 m. As fotos de esquina com contagem de fiadas dão **torre A ≈ 5,0 m até o topo das ameias e ≈ 6,3 m até o ápice da torreta**. Revisar o chute antigo para baixo (confiança média/baixa, ±1 m).
4. **A "torreta" é pequena.** A torre com cobertura piramidal alta, vista na frente, é uma **torreta de canto de ~1 m de seção** encostada no corpo quadrado da torre A, e não uma segunda torre habitável.
5. **Material.** De perto (`textura_tijolo_mesa_acervo_beta.jpg`) são **blocos de ~35 × 11,5 cm, face áspera e porosa, juntas de ~2 cm**. Parecem tijolo rústico ou arenito cortado em formato de tijolo. As fontes dizem "pedra grés/gris". Para o modelo, o módulo é o mesmo.
6. **Outro "castelinho" em Imbé.** A matéria "Castelo misterioso intriga veranistas em Imbé" (Start Comunicação, 11/02/2024, foto do Correio do Povo) é sobre **outro** prédio: casa particular na **Av. Beira-Mar**, pertinho da Barra, com **muralha, portão de madeira, mastro com bandeira do Inter, bruxa e sete anões no jardim**, dono vivo que diz "é só uma casa". **Não é a Casa de Cultura.** Cuidado ao pesquisar o nome; "Imobiliária Castelinho" (YouTube) é outra coisa ainda.
7. **Elementos novos vistos nas fotos:** passagem em arco sob uma "ponte" ameada junto à torre A; terraço/laje com platibanda branca entre o corpo principal e a ala dos fundos; torre B com porta em arco na base; pavilhão isolado de cobertura piramidal na aérea de 2019 (não aparece em 2021/2026); duas portas grandes em arco na ala dos fundos; chaminé quadrada com capa piramidal.

---

## 1. Pegada real do prédio

### 1.1 OpenStreetMap

- **Overpass API** (`overpass-api.de` e três espelhos): o proxy da sessão derrubou todas as tentativas (reset/timeout). Usei a **API de mapa do OSM** (`api.openstreetmap.org/api/0.6/map?bbox=-50.1225,-29.9665,-50.1190,-29.9640`), que serve os mesmos dados.
- **Resultado: não existe polígono `building` do Castelinho.** O único `building` num raio de 180 m é um way de 5 nós a 181 m (`599449062`, `building=yes`, sem nome). O prédio só existe como **nó** `5859911470` (`tourism=museum`, "Castelinho de Imbé", em -29.9652230, -50.1207137; o Cadastro de Museus dá -29.9652025, -50.1206533, 6 m a NE). Por isso não há área, azimute nem dimensões vindas do OSM. Também **não existe polígono do lote** (`landuse`) nas imediações.
- **Ruas num raio de 120 m** (nome, tipo, distância ao ponto do Cadastro, rumo):

| Via | Tag | Dist. | Rumo | Largura |
|---|---|---|---|---|
| Av. Rio Grande (= Nilza Costa Godoy) | secondary, 2 ways (903024551, 1020416953) | 23 m | 19,5° | sem tag. Pelo satélite ~7 m de asfalto a leste da fachada até a borda da pista (leitura em imagem de 0,52 m/px, ±2 m) |
| Av. Garibaldi | secondary, oneway=yes, asphalt, 2 ways (236493318, 236493319) | 24 m e 35 m | 287° / 107° | sem tag. 8,4 m entre eixos das duas pistas; caixa estimada ~16 m com canteiro |
| Rua Uruguaiana | residential | 55 m | 22° | sem tag |
| Rua São Borja | residential | 106 m | — | sem tag |
| Rua Passo Fundo | residential | 136 m | — | sem tag |

  Nenhuma via traz `width` ou `lanes`. A posição do OSM aparece deslocada ~4 m em relação ao satélite (alinhamento Bing).
- A Av. Nilza Costa Godoy no OSM (way 235558512) termina ao sul do cruzamento; a mesma avenida continua ao norte com o nome "Rio Grande" no mapa. Não é erro do prédio, é a renomeação pela Lei 1744/2016.

### 1.2 Satélite

- **Esri World Imagery só tem tile até z18 neste ponto.** Em z19 (e z20, z21) o servidor devolve o cartão cinza "Map data not yet available". Salvei o que existe.
- `refs/satelite_z18.jpg`: mosaico 5×5 tiles (1280 px, ~660 m). `refs/satelite_z18_lote.jpg`: recorte de 120 px ampliado 8×, com a coordenada do Cadastro marcada e barra de 20 m.
- Escala z18 a -29,965°: 156543,03·cos(lat)/2^18 = **0,517 m/px**. Tile z18 da coordenada: x=94575, y=153960 (mosaico começa no tile 94573,153958; a coordenada cai no pixel (577,673) do mosaico).
- O satélite é borrado, com árvores e sombras. **Dá para ver**: lote entre as duas avenidas; um telhado claro grande (~13 × 11 m, corpo principal mais o terraço) junto ao ponto; telhado escuro maior ao norte (ala dos fundos); gramado de ~14 × 15 m entre a fachada sul e a Garibaldi; faixa de terra/gramado de ~7 m entre a fachada leste e a borda da Av. Nilza. **Não dá para ver**: torres, ameias, arcos. A pegada abaixo vem das **fotos oblíquas** (aérea 2019, drone 2021, frontal 2026) calibradas pela largura dos vãos da arcada, pela contagem de fiadas e pela extensão total no satélite (~21 m de leste a oeste, arcada + corpo).

### 1.3 Croqui

`refs/croqui_planta.png` (matplotlib, cotas em metros, volumes com hachura onde é especulativo). Origem na esquina Garibaldi × Nilza. Eixo **X** ao longo da Garibaldi **para oeste** (rumo 287°); eixo **Y** ao longo da Nilza **para norte** (rumo 19,5°). Esse par é espelhado em relação ao padrão matemático; para o Godot use `posição = (-X, altura, -Y)`.

### 1.4 Planta com cotas

| Volume | X (m) | Y (m) | Largura (X) | Profund. (Y) | Alturas | Confiança |
|---|---|---|---|---|---|---|
| Corpo principal (letreiro) | 5,0 | 11,0 | 7,5 | 9,5 | beiral leste 4,2; cota alta oeste ~5,5; cobertura 1 água ~10° | pegada média/baixa; altura média |
| Ala da arcada (5 arcos) | 12,5 | 11,0 | 10,5 | 3,0 | topo do parapeito com ameias 4,4 | média/baixa |
| Torre A (corpo ameado) | 19,0 | 14,0 | 4,0 | 4,0 | topo das ameias 5,0 | baixa (±1 m, ±2 m de posição) |
| Torreta da torre A (canto NE) | 19,0 | 16,8 | 1,2 | 1,2 | ápice 6,3 | seção média, altura média/baixa |
| Pavilhão oeste (só em 2019) | 26,0 | 14,5 | 1,4 | 1,4 | ápice ~4,0 | baixa, especulativo |
| Terraço/laje | 5,0 | 20,5 | 14,0 | 3,0 | laje 3,8 + platibanda 1,1 | baixa |
| Ala dos fundos | 8,2 | 23,5 | 8,8 | 6,0 | beiral 3,6; alto 4,6 | baixa |
| Torre B | 5,0 | 23,5 | 3,2 | 3,2 | ameias 4,3; ápice 5,6 | baixa |
| Chaminé 1 / chaminé 2 | 11,4 / 15,6 | 12,0 / 28,2 | 0,9 / 0,8 | 0,9 / 0,8 | +1,3 / +1,2 acima da cobertura | baixa (posição) |

- **Recuos**: fachada sul a ~11 m da testada da Garibaldi; fachada leste a ~5 m da testada da Nilza. Baixa/média (±3 m).
- **Lote**: ~30 × 34 m (~1.000 m²; a imprensa diz "mais de 900 m²"). Limites não medidos.
- **Soma das pegadas térreas** (sem terraço): 71 + 31 + 16 + 10 + 53 + 2 ≈ **185 m²**. Com segundo pavimento do corpo principal e níveis das torres, chega perto dos **290 m construídos** da imprensa. É só conferência de ordem de grandeza.
- **Azimutes das faces** (normal para fora, rumo geográfico): sul/arcada **199,5°**; leste/letreiro **107°**; oeste **287°**; norte **19,5°**. Sol da manhã bate no letreiro (leste). A arcada, voltada ao sul, fica quase sempre na sombra, porque no hemisfério sul o sol corre pelo lado norte; só pega luz rasante no verão, de manhã e de tarde.
- **Qual lado dá para qual avenida**: sul → Garibaldi; leste → Nilza Costa Godoy.

---

## 2. Fotos do Castelinho (todas em `refs/`)

Total em `refs/`: **8 do dossiê + 18 novas = 26 imagens do prédio**, mais `satelite_z18.jpg`, `satelite_z18_lote.jpg` e `croqui_planta.png`. Dessas, só `foto_antiga_nucleo_original_beta.jpg` é foto de época. Os quadros `yt_*` são miniaturas automáticas de vídeos do YouTube (480×360, só como referência de forma).

**Fotos que mais valem para modelar** (negrito):

| Arquivo | O que mostra | Fonte |
|---|---|---|
| **`lnr_2026_frontal_esquina_ivan.jpg`** | **A melhor elevação.** Da esquina SE: torre A com torreta e cobertura piramidal, arcada com cornija, corpo principal com letreiro, 2 janelas de grade com venezianas, porta arqueada de madeira, beiral de madeira, chaminé | Litoral na Rede, 02/03/2026, foto Ivan de Andrade/PMI |
| **`jpl_2021_aerea_drone_fachadas.jpg`** | Drone de ~15 m: torres A e B de cima, terraço, chaminé, telhado de fibrocimento, arcada, placa "Casa de Cultura e Museu Municipal", cascalho do lado leste | JP Litoral, fev/2021 |
| **`aerea_2019_litoralnarede.jpg`** | (dossiê) Planta oblíqua: torre A com terraço, pavilhão oeste, ala dos fundos com 2 portões em arco, torre B, deck/pérgola, carro e pessoas para escala | Litoral na Rede 2019 |
| **`lnr_2019_arcada_ameias_marques3.jpg`** | Arcada de baixo, cornija de mísulas em degraus, merlões, pilares, arcos abertos, corpo principal à direita com lamparina | Litoral na Rede 2019, Maurício Marques/PMI |
| **`lnr_2019_passagem_arco_marques.jpg`** | Passagem em arco com "ponte" ameada, torre com 2 frestas em arco, janela com venezianas de losango, **pessoa em pé para escala**, tijolo bem nítido | idem |
| `textura_tijolo_mesa_acervo_beta.jpg` | Parede de blocos de perto com máquina de escrever, livros e telefone: **escala do bloco** | Beta Redação 2026 |
| `dpn_natal_frontal_torre_arcada_ivan.jpg` | Torre A, arcada, placas institucionais, grade de pedra e hortênsias (chamada "Noite de Natal no Castelo"; data da foto não informada) | Da Praia News, foto Ivan de Andrade |
| `dim_2026_torre_ameias_hibisco.jpg` | Torre A e anexo ameado de perto, janelas com veneziana, hibisco em primeiro plano | Jornal Dimensão, 20/02/2026 |
| `interior_meio_ambiente_piso_pedra_2020_jplitoral.jpg` | Piso de cacos de pedra, parede de bloco, janelinha com grade de losango, pinguim empalhado | JP Litoral 2020 |
| `interior_porta_arco_nicho_2020_jplitoral.jpg` | Porta em arco de madeira, nicho em arco na parede, arandela, piso de pedra | JP Litoral 2020 |
| `ci_2025_sala_lareira_escudos.jpg` | Sala com lareira de bloco, escudo com machados cruzados, mesa grande, cadeiras de madeira escura | Correio do Imbé, ago/2025 |
| `yt_ondatv_torre_passagem.jpg` | Torre A, anexo ameado com 2 janelas em arco, passagem em arco, homem para escala (selfie) | ONDA TV (YouTube) |
| `yt_ondatv_escudo_espadas_parede.jpg` | Escudo redondo de metal com espadas cruzadas e machado na parede de bloco | idem |
| `yt_mundoreverso_capa_torre.jpg` | Torre A vista de fora, de baixo | Mundo Reverso (YouTube) |
| `yt_vonhelden_porta_4vidros_torre.jpg` | Porta de madeira com janela de 4 vidros, torre ameada ao fundo | TV Nativoos/Von Helden (YouTube) |
| `yt_radiok_porta_interna_4vidros.jpg` | Porta de madeira de 2 folhas, janela de 4 vidros | Rádio K FM (YouTube) |
| `yt_vernissage_sala_lareira_arcos.jpg`, `yt_vernissage_arcos_interno.jpg` | Interior: lareira, arcos de bloco | Marcos Figueiró TV |
| `yt_festivalmedieval_arcada_parapeito.jpg` | Parapeito da arcada, torre e chaminé (capa de vídeo) | Curiosidades Litorâneas |

Os 8 do dossiê (`fachada_frontal_2026_beta.jpg`, `torres_fachada_lateral_2026_correiodoimbe.jpg`, `arcada_cornija_2020_jplitoral.jpg`, `janelas_grade_2020_jplitoral.jpg`, `foto_antiga_nucleo_original_beta.jpg`, `interior_galeria_arco_porta_2026_beta.jpg`, `interior_sala_pescador_2026_beta.jpg`) continuam como descritos em `castelinho.md` §5.

**Não achei** (busquei): fotos dos **fundos reais** (lado norte, ala dos fundos, vista do pátio), **da lateral oeste**, **dos telhados por dentro**, **escada das torres**, **vista noturna do prédio** (só a aérea noturna da Beira-Mar/ponte, outro assunto). Fontes tentadas e resultados:
- **Wikimedia Commons**: nenhum arquivo do Castelinho (apenas praia, guarita, bandeiras de Imbé).
- **Mapillary**: a API exige token (erro 190). **KartaView**: 0 fotos num raio de 500 m. **Flickr/Panoramio/TripAdvisor/Google Maps**: nada indexado do prédio (o TripAdvisor só traz outros "Castelinhos").
- **Instagram da Von Helden/Prefeitura**: HTTP 429/JS, inacessível. **Facebook**: idem. **YouTube**: busca funcionou; **download de vídeo foi bloqueado** (verificação anti-robô), só miniaturas.
- Sites de notícia (Litoral na Rede, JP Litoral, Correio do Imbé, Dimensão, Da Praia News, Beta Redação, Litoralmania, Correio do Povo) foram varridos por imagens; o que serve está em `refs/`. GZH e Rádio Tramandaí não têm matéria do prédio nos resultados.

---

## 3. Medidas estimadas por foto

**Escala base.** Bloco medido contra a máquina de escrever Hermes portátil (~32 cm de largura) e livros em `textura_tijolo_mesa_acervo_beta.jpg`: **comprimento ~35 cm, altura ~11,5 cm, junta ~2 cm, fiada com junta 13,5 cm (7,4 fiadas por metro)**. Conferi na fachada frontal: 1 fiada ≈ 10,5 px → ~78 px/m; sinal "Castelinho" resulta em ~2,1 m de largura e a porta de vidro em ~2,3 m, números plausíveis. Alturas = contagem de fiadas × 13,5 cm ou pixels ÷ escala local; a perspectiva (torres mais longe, câmera de telefoto) foi corrigida a olho.

| Item | Valor | Foto/Fonte | Confiança |
|---|---|---|---|
| Bloco (C × A × junta) | 35 × 11,5 × 2 cm; fiada 13,5 cm | `textura_tijolo_mesa_acervo_beta.jpg` | média (±2 cm) |
| Beiral leste do corpo principal | 4,2 m (~31 fiadas) | `lnr_2026_frontal_esquina_ivan.jpg` | média (±0,4 m) |
| Cota alta da cobertura (oeste) | ~5,5 m (cobertura ~10°) | idem + `aerea_2019` | baixa |
| Beiral de madeira, projeção | ~0,7 m | idem | baixa |
| Largura/altura de janela do lado leste | 0,55 × 1,40 m, peitoril a 0,95 m | idem (≈10 fiadas de altura) | média/baixa |
| Venezianas | 2 folhas de ~0,28 m, recorte em losango | idem + crop | média |
| Porta de madeira arqueada (leste) | ~1,6 × 2,1 m, 4 vidros por folha | idem; `yt_vonhelden_porta_4vidros_torre.jpg` | baixa |
| Letreiro "Castelinho" | ~2,1 × 0,45 m, a ~2,6 m do piso | idem | média/baixa |
| Arco de entrada (porta de vidro) | ~1,9 × 2,3 m | idem | média/baixa |
| Arcos da arcada | 1,3 m de vão, 2,4 m de coroa, imposta 1,75 m | `lnr_2019_arcada_ameias_marques3.jpg` + frontal | média/baixa |
| Pilares da arcada | 0,65 × 0,65 m (≈ 1,8 bloco de face) | `lnr_2019_arcada_ameias_marques3.jpg` | média |
| Passo entre arcos (eixo a eixo) | ~1,95 m; 5 vãos → ~10,5 m | idem + `aerea_2019` (4 arcos visíveis) | média/baixa; contagem pode ser 4 a 6 |
| Parapeito da arcada (topo das ameias) | ~4,4 m | frontal 2026; m3 | média (±0,4 m) |
| Merlão | 0,33 L × 0,30 A × 0,30 espessura; vão 0,25; passo 0,58 | `lnr_2019_arcada_ameias_marques3.jpg`, `dim_2026_torre_ameias_hibisco.jpg` | média |
| Ritmo das ameias (fachada sul) | ~18 merlões | 10,5 m ÷ 0,58 | baixa |
| Cornija de mísulas | 3 fiadas (0,40 m), projeção total ~0,13 m em 3 degraus; mísulas a cada ~0,30 m com arquinho cego (torres/arcada), ~0,20 m nas torretas | m3; crop da torre | média para o tipo, baixa para a projeção |
| Altura da torre A até topo das ameias | ~5,0 m (~37 fiadas contadas em torno de 38) | frontal 2026 | média/baixa (±0,7 m) |
| Torreta: seção / ápice | ~0,9 a 1,2 m (≈ 2,5 blocos); ápice ~6,3 m | frontal 2026 (zoom) | seção média; altura média/baixa |
| Cobertura piramidal | ~42° (cume ~0,6 a 0,7 m acima da base de 1,2 m) | frontal; drone 2021 | média/baixa |
| Torre B | topo das ameias ~4,3 m; ápice ~5,6 m | drone 2021 / aérea 2019 (~0,85× a torre A) | baixa |
| Frestas das torres | arco ogival ~0,22 × 0,85 m, geminadas, 2 níveis (z ≈ 2,0 e 3,6 m) | `lnr_2019_passagem_arco_marques.jpg`; `yt_ondatv_torre_passagem.jpg` | quantidade média, tamanho baixa |
| Passagem em arco com "ponte" | ~1,8 m de vão × 2,6 m de coroa; ponte ameada ~0,9 m de espessura | `lnr_2019_passagem_arco_marques.jpg` | forma média, posição baixa |
| Chaminé principal | ~0,9 × 0,9 m, +1,3 m acima do telhado, capa piramidal | frontal; aérea 2019 | baixa |
| Telha de fibrocimento | onda 0,177 m (padrão do mercado), cor ~#9A9A96 | frontal; aérea 2019 | passo não medido; cor média |
| Portões da ala dos fundos | 2 vãos em arco ~1,8 × 2,4 m | `aerea_2019_litoralnarede.jpg` | baixa |
| Espessura de parede | ~0,40 m | aberturas das arcadas (m3) | baixa |

Observação: duas leituras de escala na fachada frontal discordaram até 40% (pessoa dentro do vão e papel na porta contra fiada e letreiro). Fiz a média ponderada pela fiada, que foi a única régua medida de perto. **Se o jogo precisar de proporção mais firme, a melhor aposta é visita ou medir `lnr_2026_frontal_esquina_ivan.jpg` com um tijolo de referência.**

---

## 4. Aberturas por fachada (resumo; detalhes em `medidas_estimadas.json`)

- **Sul (arcada, Av. Garibaldi):** 5 arcos abatidos (o do canto leste é a entrada, de vidro); 2 centrais vedados com vidro e esquadria preta em 2020; no alto, parapeito ameado, cornija de mísulas, placa "Casa de Cultura e Museu Municipal". Piso interno de cacos de pedra visível.
- **Leste (letreiro, Av. Nilza):** 2 janelas de grade em losango e venezianas; letreiro gótico "Castelinho"; porta de madeira arqueada de 2 folhas na ponta norte; 3 frestas de ventilação sob o beiral; 1 janela alta com veneziana; beiral largo de madeira.
- **Oeste do corpo principal (lado do pátio):** janela alta com venezianas de recorte em losango, janelinha gradeada, porta cinza. Só uma foto.
- **Torre A:** frestas em arco ogival geminadas em dois níveis, esquadria de vidro verde; torreta com 1 fresta.
- **Torre B:** porta em arco aberta na base; 2 frestas.
- **Ala dos fundos:** 2 portões em arco de madeira escura voltados ao sul.
- **Sem foto:** fachada norte e leste da ala dos fundos, lado oeste da torre A.

---

## 5. Flashbacks fora do castelo

Fotos em `refs/flashbacks/` (43 arquivos). Quase todas são **miniaturas de vídeo do YouTube** (480×360 ou 1280×720) e algumas imagens de portais de notícia. Para modelar, servem como **moodboard**, não como textura.

> **Imbé não tem foto antiga digitalizada achável online.** Para os anos 1930 a 1960 usei **Tramandaí** (a cidade do outro lado do rio) como proxy visual. Os fatos de Imbé vêm da Câmara Municipal (histórico) e das matérias; as imagens `antigo_*` são de Tramandaí e estão marcadas assim.

### 5.1 Barra do Rio Tramandaí / Guia Corrente

**Fatos.** O Guia Corrente é um molhe de pedras surgido nos anos 1960, depois da instalação da Petrobras em Tramandaí, para direcionar a corrente e evitar assoreamento (Da Praia News). Depois da emancipação de Imbé (1988) fizeram uma avenida à beira-mar acompanhando o molhe; quiosques de madeira dos anos 1990 foram trocados por estruturas modernas; hoje há quiosques de crepe e frutos do mar, artesanato, venda de peixe, garças, biguás e savacus. A **pesca com botos** (cooperação entre pescadores de tarrafa e botos) acontece entre Tramandaí e Imbé; o boto indica o momento de lançar a tarrafa com uma "cabeçada" (ou batida) própria do lugar, sinal ritualizado; o IPHAN tem parecer técnico sobre o ofício (`bcr.iphan.gov.br/.../Parecer-Tecnico-da-Pesca-com-Botos.pdf`).

**Visual.** Pescadores de água na altura da coxa lado a lado na margem de areia, de costas para o rio, cada um com a tarrafa em mão ou dobrada no braço; água marrom-esverdeada; molhe de blocos de pedra escuros e angulosos avançando; na outra margem os prédios altos de Tramandaí; dunas baixas na ponta. No molhe ficam pescadores com caniço e coca (rede em aro) e sacos de plástico.

| Arquivo | O que mostra |
|---|---|
| `barra_tarrafeiros_dunas_yt.jpg` | pescadores lançando tarrafa na praia da ponta, dunas ao fundo |
| `barra_tarrafeiros_skyline_yt.jpg` | fileira de tarrafeiros na água, prédios de Tramandaí do outro lado |
| `barra_botos_espetaculo_litoralnarede_yt.jpg` | "Espetáculo dos botos no Rio Tramandaí": pessoas até a coxa na água |
| `molhe_pescadores_pedras_yt.jpg`, `molhe_tarrafa_rio_imbe_yt.jpg` | molhe de pedras com pescadores, tarrafa em arco, cidade ao fundo |
| `molhe_pedras_quiosques_imbe_yt.jpg`, `molhe_pedras_pescador_yt.jpg` | pedras do molhe, mar à esquerda, quiosques de madeira de Imbé |
| `barra_aerea_drone_ponta_yt.jpg`, `barra_aerea_2016_molhe_multidao_yt.jpg`, `barra_orla_rio_aerea_imbe_yt.jpg` | aéreas da barra, ponta de areia, molhe, orla do rio, multidão em dia de pesca |

### 5.2 Ponte Giuseppe Garibaldi

**Fatos.** Liga Imbé a Tramandaí pela ERS-786 sobre o rio Tramandaí. Hoje são **três pontes**: duas de pista única no sentido Imbé→Tramandaí e uma de faixa dupla no sentido contrário. Extensão 149,5 m (Wikipédia). Cronologia divergente: a prefeitura de Tramandaí diz que a primeira ponte é de **1934**; a Wikipédia diz construção nos anos 1950 a 1980. Tratar como incerto. O nome homenageia Giuseppe Garibaldi, que levou lanchões por terra até a barra do Tramandaí durante a Revolução Farroupilha (ver §5.6). Há notícias recentes (2026) de rachaduras e interdições parciais (Dimensão TV).

**Visual.** Guarda-corpo de concreto **branco** em quadros de grade, posteado, curto; pista de asfalto estreita com marca amarela; postes de luz curvos; à esquerda os prédios altos de Tramandaí; rio largo e marrom, pescadores de sardinha na grade. À noite: iluminação amarela do tabuleiro e dos postes.

Arquivos: `ponte_garibaldi_pista_grades_yt.jpg`, `ponte_garibaldi_cabeceira_yt.jpg`, `ponte_garibaldi_noite_aerea_yt.jpg`, `ponte_garibaldi_noite_aerea2_yt.jpg`, `ponte_garibaldi_heliopere_blog.jpg` (marca d'água), `ponte_garibaldi_obras_dimensaotv_yt.jpg` (operários e caminhão no tabuleiro).

### 5.3 Praia de Imbé, guaritas e Av. Beira-Mar

**Visual.** Faixa larga de areia clara, mar aberto de ondas médias, **guaritas de salva-vidas** em estrutura de madeira/metal vermelha ou azul sobre palafitas, **calçadão/avenida Beira-Mar** com ciclovia, canteiros e rotatórias de pavimento vermelho, **poste alto** de iluminação, quiosques de madeira e lona, guarda-sóis coloridos no verão, casas e prédios baixos atrás da avenida. Dados de contexto: o monumento de Iemanjá fica na praia de Santa Terezinha (Commons).

Arquivos: `praia_imbe_guaritas_beira_mar_aerea_yt.jpg`, `beira_mar_calcadao_guarita_azul_yt.jpg`, `beira_mar_calcadao_yt.jpg`, `praia_imbe_guarita_vermelha_yt.jpg`, `imbe_aerea_orla_cidade_yt.jpg`, `imbe_aerea_beira_mar_yt.jpg`, `imbe_aerea_barra_yt.jpg`, `imbe_aerea_avenidas_ruas_yt.jpg`, `beira_mar_noite_aerea_yt.jpg`.

### 5.4 Imbé nos anos 1930 a 1960

**Fatos** (Câmara Municipal de Imbé, "Histórico"): a região era "campo, areia, banhado"; havia **ranchos de palha** na margem esquerda do rio com famílias de pescadores; a travessia era feita por **balsas e canoas** de particulares; as **primeiras casas** foram erguidas na **Av. Rio Grande, Rua São Leopoldo e Rua Santa Cruz** (a Av. Rio Grande é a que hoje se chama Nilza Costa Godoy, onde fica o Castelinho!). O município foi criado pela Lei 8.600 em 09/05/1988, instalado em 01/01/1989. A foto antiga do núcleo original do Castelinho (`foto_antiga_nucleo_original_beta.jpg`) mostra o terreno como areia nua nos anos 1950 e é o melhor documento do período. Mais contexto em `historia_imbe.md`.

**Imagens (proxy de Tramandaí, não de Imbé):**
`antigo_tramandai_inicio_seculoXX_banhistas_yt.jpg` (família de roupa de banho de listras, anos 1920), `antigo_tramandai_familia_1920_yt.jpg` (foto de grupo em tom sépia), `antigo_tramandai_carro_fordT_yt.jpg` (carro Ford T e homens de terno e chapéu), `antigo_tramandai_cartao_postal_pavilhao_yt.jpg` (pavilhão redondo na praia, cartão-postal colorido, Fuscas e Kombis nos anos 1960/70), `antigo_tramandai_1950_filme_banhista_yt.jpg` (quadro de filme de 1950, banhistas em preto e branco).

### 5.5 Av. Rio Grande (hoje Nilza Costa Godoy) alagada, maio de 2024

**Fatos.** Em **16/05/2024** (quinta) as ruas de Imbé e Tramandaí amanheceram alagadas depois que o **rio Tramandaí transbordou na madrugada**, por cheia da Lagoa do Armazém e ressaca do mar com vento de quadrante sul. A água invadiu trecho da **Av. Nilza Costa Godoy, antiga Rio Grande, especialmente perto da esquina com a Rua Alegrete**, e vias do bairro Courhasa, como a Rua Torres. Defesa Civil de Imbé (coordenador Robson Minussi) monitorou e ofereceu retirada preventiva (Litoral na Rede e Terra)., mas a posição exata da Rua Alegrete não foi conferida. O Castelinho fica na mesma avenida.

**Visual.** Pista coberta por lâmina de água cinza-marrom até o meio-fio, carros avançando devagar, postes e casas refletidos na água, céu fechado, aguapés espalhados na rua depois que a água baixa (`ressaca_2024_05_beira_rio_aguapes.jpg`, com retroescavadeira amarela).

| Arquivo | O que mostra |
|---|---|
| `alagamento_2024_05_imbe_terra.jpg` | quadro de vídeo, carros na avenida alagada de Imbé (baixa resolução) |
| `alagamento_2024_05_recanto_lagoa_tramandai.jpg` | rua alagada em Tramandaí (Defesa Civil), 16/05/2024 |
| `ressaca_2024_05_beira_rio_aguapes.jpg` | Beira-Rio de Tramandaí depois da ressaca, aguapés e areia na rua |
| `alagamento_imbe_jacare_2026_jplitoral.jpg` | **jacaré** boiando numa rua alagada de Imbé (jul/2026); bom para o tom de terror |
| `alagamento_imbe_rua_chuva_dapraianews.jpg`, `alagamento_imbe_rio_transborda_correiopovo_yt.jpg`, `alagamento_barra_imbe_dimensaotv_yt.jpg`, `alagamento_braco_morto_avenida_yt.jpg` | outros alagamentos em Imbé (anos distintos; o do Correio do Povo é de ~2017) |

### 5.6 Lanchão Seival de Garibaldi

**Fatos.** O Seival foi um lanchão usado por **Giuseppe Garibaldi** na Guerra dos Farrapos e na tomada de Laguna (República Juliana). Os lanchões foram **arrastados por terra sobre rodas, em juntas de bois**, até a barra do Tramandaí, para entrar no mar e seguir a Laguna. A **réplica** de ~15 m de comprimento, 3,8 m de boca e 3,2 m de altura, ~15 t, foi construída pelo professor Antônio Carlos Rodrigues com base em documentos, planos de embarcações de Laguna e **uma foto do Seival original de 1908** (O Nacional). Veleiro de dois mastros, casco branco com faixa vermelha na linha d'água.

Arquivos: `seival_replica_guaiba_reporterguaibense.png` (réplica à vela no Guaíba, bandeira farroupilha), `seival_gravura_garibaldi_yt.jpg` (**gravura de Garibaldi com o lanchão puxado por bois**), `seival_miniatura_pelotas_yt.jpg` (miniatura exposta), `seival_replica_conves_yt.jpg` (convés da réplica), `seival_casco_madeira_yt.jpg` (casco de madeira por dentro).

---

## 6. Como isto entra no modelo

- Fonte única para o script de modelagem: `medidas_estimadas.json` (campos `_fonte` e `_confianca`). Rodar com `posição = (-X, Z, -Y)` no Godot.
- **Ordem de confiança para decidir o que modelar com cuidado**: bloco/fiada (média) > arcada e parapeito (média) > corpo principal e janelas leste (média/baixa) > torre A (média/baixa) > ala dos fundos, torre B, terraço, pavilhão (baixa).
- Onde há margem para licença criativa sem trair o prédio: a ala dos fundos, o pátio, a torre B e o pavilhão (poucas fotos e todas de cima). Onde **não** mexer: a fachada leste e a arcada sul, que são as mais fotografadas.
- Escuro e úmido: as fotos de 2019 mostram musgo/erva-de-passarinho nas ameias da torre A e chapas empenadas no telhado; o estado de 2019 é o melhor "pré-restauro" para o terror.

---

## 7. Fontes

- OpenStreetMap, API 0.6 `map` (bbox -50.1225,-29.9665,-50.1190,-29.9640, 04/10/2026); nó 5859911470; ways 236493318, 236493319, 903024551, 1020416953, 235558512 (Nilza), 599449062. Nominatim reverse/search.
- Esri World Imagery tiles z14 a z18; z19+ indisponível.
- Litoral na Rede: "Castelinho de Imbé será transformado em centro cultural" (03/10/2019, fotos Maurício Marques/PMI, `…MARQUES.jpg`, `…MARQUES-3.jpg`); "Castelinho da Cultura em Imbé recebe evento especial em homenagem ao Dia da Mulher" (02/03/2026, foto Ivan de Andrade/PMI); "Defesa Civil monitora ruas alagadas em Tramandaí e Imbé" (16/05/2024); "Castelinho de Imbé recebe evento de cultura medieval" (24/08/2024).
- JP Litoral: "Imbé inaugura Casa de Cultura e Museu Municipal" (12/2020); "Casa de Cultura e Museu de Imbé recebeu 489 visitas em janeiro" (02/2021, foto `Castelinho.jpg`); "Chuvas causam alagamentos em Imbé e jacaré é avistado" (07/2026).
- Jornal Dimensão (20/02/2026); Correio do Imbé (conselho de cultura, 08/2025; Von Helden 2026); Da Praia News ("Noite de Natal no Castelo", Guia Corrente, Von Helden); Beta Redação (Lara Zarth, 25/05/2026, fotos Caroline Lopes); Litoralmania (Von Helden 2026; jacaré em Imbé).
- Start Comunicação, "Castelo misterioso intriga veranistas em Imbé", 11/02/2024 (outro prédio, Av. Beira-Mar).
- Câmara Municipal de Imbé, "Histórico de Imbé" (`camaraimbe.rs.gov.br/historico-de-imbe`).
- Wikipédia pt "Ponte Giuseppe Garibaldi"; Tramandaí (prefeitura, "História da Cidade"); Heliopere (blog, ponte); `heliopere.com`.
- IPHAN, Parecer Técnico da Pesca com Botos (`bcr.iphan.gov.br`); LinkedIn "Botos e pescadores trabalham juntos na pesca da tainha".
- Repórter Guaibense (réplica do Seival em Guaíba, 2022); O Nacional ("Seival terá réplica em tamanho original"; "Professor faz réplica em miniatura do Seival"); Prosa Galponeira ("Seival e os caminhos de Garibaldi", 2019).
- Terra, "VÍDEO: Rio transborda e água invade ruas de Imbé e Tramandaí" (16/05/2024).
- YouTube (miniaturas `img.youtube.com/vi/ID/*.jpg`): Mundo Reverso `gdSWn3uetmQ`; ONDA TV `Ynl65ZnIXTk`; TV Nativoos `fyE8hFpe49E`; Marcos Figueiró TV `WFzT5wrk1xA`; Rádio K FM `AVcu4417D1U`; Von Helden `UWYzbOUIG7E`; Curiosidades Litorâneas `j5lm5-GB74k`; Imagens Brasil Sul `oExDT2OZRVU`; Julio Couto Imagens `Nr7fHZ9VAho`; Nas viagens `A8MaAaYfTPc`, `8abDD28qSHE`; Litoral na Rede `ZCkBgXMdWso`; Pesca Sul `QmPs6SnnkJY`; Nas viagens `JRmgi4zGUyU`; Pitol.net `l_ZT9ZRFYLU`; TOP TRIP 343 `cxoGtIo0in4`; Dimensão TV `6oxsVM3-cig`, `yIjVqt2cnZw`, `dLM8yHMvwwY`; Invicta `OauhZQLFvck`; LC Vídeos `hndagdKHhDE`; Giro Gusto `K2_XXY1cyEM`; Nossas Pegadas `HsXWOzDEtas`; Jornal NH `vLsh7AnGl6Y`; Cidades do Sul `3rNUPJDYm1w`; Wilkens Filmes `BxznUY-vxFw`; Correio do Povo Play `6eJ4hG3TB7U`; Guia Pelotas `xxrqp3vd-sc`; Record Guaíba `iXCam0F4zLg`; Geraldo de Souza Senna `9d6-RQATeao`; Jornal Dimensão (outros).
