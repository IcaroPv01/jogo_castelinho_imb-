# Castelinho de Imbé: modelo paramétrico e o nível das quatro visitas (V2)

Tudo é gerado por código (nenhum `.glb`, nenhuma malha feita à mão). Os números ficam em `medidas.json`;
mudar uma medida e recarregar o nível basta. Fontes: `docs/pesquisa/geometria_e_fotos.md`, as fotos de
`docs/pesquisa/refs/` e `docs/MVP_ROTEIRO.md`.

## Arquivos

| Arquivo | O que faz |
|---|---|
| `medidas.json` | Medidas já em coordenadas do Godot, corrigidas pelas fotos (ver "Correções"). Cópia embutida em `medidas_embutidas.gd` (`tools/gerar_medidas_embutidas.py`): a exportação web não empacota esse JSON. |
| `castelinho.gd` | `class_name Castelinho` (Node3D). Materiais, grupos por época, ajudantes de parede/ameia/cornija/laje. `Castelinho.new()` + `add_child` constrói tudo. |
| `casco.gd` | Fachadas, torres, anexo, pavilhão, ala dos fundos, Torre B, lajes, chaminés, coberturas. |
| `interior.gd` | Pisos, forros, vigas, divisórias, escadas (rampa de colisão sob degraus), lustres. |
| `extras.gd` | Camadas de tempo: museu (2020), ruína (2019), núcleo (1950). |
| `mobilia.gd` | Cavaletes, vitrines, lareira, tronos, mural, móveis de 1975; pinguim, armadura, telefone e a textura dos recortes de papelão (desenhada com `Image`). |
| `entorno.gd` | Lote, calçadas, avenidas, casas vizinhas, pinheiros, postes, cercas, dunas de 1950, barreiras e o corredor de 1975. |
| `malha.gd` | `Malha`: junta a geometria por material (uma `ArrayMesh`, uma superfície por material) e as caixas de colisão. `bolha` (elipsoide low-poly com cor de vértice) faz tufos de pinheiro, arbustos, hortênsias e peças do acervo. |
| `sombras.gd` | `SombrasChao`: sombras pintadas no chão, com uma imagem por época (sombra projetada pelo Sol da época, oclusão no pé dos volumes e copas), num quadrilátero em modo MULTIPLICAR. Custa 1 draw call. |
| `obra.gd` | `ObraCastelinho`: a época **E1967** (o Castelinho em obra), ver "Licença criativa" abaixo. |
| `tito.gd` | `TitoCastelinho`: o boneco do Tito (só E1967), desenhos, cartaz de PROCURA-SE, marcas de altura, balde e disco. Usa as texturas de `assets/ui/tito/` e, se faltarem, gera placeholders. |
| `gatilho.gd` | `GatilhoCastelinho`: o `SalaTrigger` que entrega a sala BASE ao nível (que converte para a sala global da visita). |
| `muros.gd` | `Muros`: parede reta com aberturas (arco abatido, ogival, retangular) gerada por código, sem CSG. |
| `../world/niveis/castelinho.gd/.tscn` | O nível das 4 visitas: céu, luzes, marcadores, gatilhos, painéis, eventos, discos e o loop de visitas. |
| `../tools/gerar_texturas.py` | Texturas PNG próprias em `assets/textures/` (numpy + Pillow). |

## Sistema de coordenadas

Godot: **x = leste, z = sul, y = altura**. Origem na esquina Av. Garibaldi (sul) x Av. Nilza Costa Godoy (leste).
O JSON da pesquisa usa um sistema espelhado: `posição Godot = (-X, Z, -Y)`. O lote vai de x -30 a 0 e z -34 a 0
(norte = -z). Garibaldi fica em z > 0, Nilza em x > 0. O jogador nasce na calçada da Garibaldi.

## Correções pelas fotos (o que mudou em relação ao relatório)

Capturas de comparação (rodar `tests/captura_cam.gd`): `build/capturas/cmp2_drone.png`, `cmp2_frontal.png`,
`cmp2_torres.png`, `cmp_esquina.png`, `cmp_aerea2019.png` (foto à esquerda, captura do jogo à direita).

* **Torre A**: o relatório dava ~5 m até as ameias. No drone e na foto frontal o corpo tem 2 pavimentos acima do
  parapeito da arcada (4,4 m). Adotado: terraço a 6,8 m, ameias a 7,8 m, torreta com ápice a 9,9 m.
* **Planta da Torre A**: 6,8 x 4,0 m no total, com a **torreta de 2,1 m na quina SE**. Pela razão entre a face sul
  e a face leste visíveis no drone, o corpo sem a torreta tem ~4,7 m. A largura também é o que permite uma escada reta
  com declive jogável por dentro.
* **Arcada**: começa na esquina da fachada leste (arco de entrada colado no canto) e vai para oeste até a torre.
  **5 arcos** (1 de entrada com 1,9 m + 4 de 1,3 m), pilares de 0,65 m. Pelas fotos: 4 arcos aparecem inteiros e
  um quinto, parcialmente escondido pela árvore, confirma o número da pesquisa. O croqui punha a arcada atrás da torre.
* **Anexo ameado** (2 pares de janelas geminadas em arco com veneziana) e **pavilhão de canto** a oeste da torre,
  alinhados com a fachada sul (aérea de 2019 e foto do hibisco).
* **Torre B**: 3,2 m de lado, quarto pequeno sobre a laje; torreta no canto, apice a 8,5 m.
* **Ameias**: 0,37 x 0,40 m a cada 0,62 m, com capa; **cornija de mísulas**: 3 fiadas (0,405 m) projetando 0,13 m,
  com o fundo entre as mísulas mais escuro (sem sombras dinâmicas na web, isso faz a faixa "ler" como na foto).
* **Cor da parede** (revisão gráfica, `docs/REVISAO_GRAFICA.md`): blocos de 35 x 11,5 cm, junta de 2 cm, de #A35E4A a
  #C98A74, com junta clara #C7BBA6 de pouco contraste e sem "poros" de alto contraste. Medido nas fotos: média de
  #C6AC95 ao sol e #A88C7C à sombra. **Interior:** `parede_interna`, mais clara e rosada, com junta cinza grossa,
  como nas fotos de dentro. **Núcleo de 1950:** `parede_nucleo`, pálida e arenosa, como na foto antiga. A parede usa
  `shaders/parede_tri.gdshader` (triplanar com oclusão falsa no pé).
* **Torretas** (revisão gráfica): a Torre A tem fuste até 9,2 m e ápice a 10,3 m; a Torre B, fuste até 8,0 m e ápice
  a 8,9 m. Nas fotos de 2026 a torreta passa ~1,4 m das ameias e a pirâmide é baixa (~40°).
* **Cornija**: arquinhos (arcuação) entre as mísulas, como nas fotos.

## Camadas de tempo (`Epocas.marcar`)

| Grupo | Épocas | Conteúdo |
|---|---|---|
| `Casa` | 1975, 2019, 2020 | Prédio inteiro: paredes, lajes, torres, interior. Em 2019 a parede troca para a textura com musgo. |
| `Museu_2020` | 2020 | Vidros nos arcos 2 a 5, porta de vidro de entrada (`Castelinho.porta_entrada`), deck com pérgola, cerca de corda, hortênsias, letreiros, cavaletes, vitrines, lareira, tronos, mural, porta fechada da Sala Medieval. |
| `Veraneio_1975` | 1975 | Sofá, poltronas, tapete, estante, redes: o mesmo cômodo da Sala Medieval mobiliado. |
| `Ruina_2019` | 2019 | Chapas de fibrocimento soltas, mato, erva nas ameias, deck e pérgola. |
| `Nucleo_1950` | 1950 | Casa de pedra de dois volumes (A alto ao norte, B baixo ao sul), telhados de duas águas, chaminé saliente, janela gradeada alta, porta arqueada aberta. **Posição: onde hoje é o corpo principal** (x -12,5..-5, z -20,5..-11, mesma fachada leste do letreiro, a da foto antiga: duas janelas, porta arqueada, janela alta). Oco e caminhável. |
| `Cidade` | 1975, 2019, 2020 | Ruas, calçadas, casas vizinhas, postes, cercas, pinheiros. |
| `Areia_1950` | 1950 | Chão de areia clara e dunas. Vento (partículas) e `Audio.ambiente("vento")`. |
| `Corredor_1975` | 1975 | Corredor de 1975 (x -10,2, de z -29,5 até -82): passa do limite do lote (z -34). É o fim da visita 3. |
| `Obra_1967` | 1967 | O Castelinho em obra (licença criativa, abaixo). `Areia_1950` (chão e dunas) também vale em 1967; a `Cidade` não. |

**Colisão elevada persiste em 1950**: lajes, terraços e parapetos ficam sólidos (invisíveis) em todas as épocas.
Assim, na sala 17, segurando Q no topo da torre, o jogador **flutua** sobre o chão de areia em vez de cair. As paredes
do térreo, as escadas e o mobiliário somem de verdade (colisão incluída).

## Licença criativa: a época E1967 (obra)

Os dados históricos dizem que a obra foi de 1950 a 1975 e que as torres vieram depois. **O estado exato em 1967 não está
documentado**: o que está em `obra.gd` é uma estimativa plausível, não um fato.

* Corpo principal e arcada de pé (sem telhado, só caibros; parapeito da arcada incompleto, com ferros de armação).
* Torre A pela metade (topo desigual, 2,6 a 4,2 m) com andaime de madeira; Torre B só na fundação (0,9 m) com ferros.
* Pilhas de blocos de pedra, um barco de madeira encalhado, chão de areia, três casas de madeira de pilotis, nenhuma rua.
* Um muro baixo de blocos ao longo da Av. Garibaldi **com um buraco de criança** (pista que só existe em 1967): é por ele
  que o Tito entrava na obra.
* **Tito** (fictício, 9 anos): boneco low-poly de caixas (estilo PS1), bermuda azul, camiseta clara, balde vermelho, rosto de
  dois pontos. Brinca na areia ao lado de um castelinho de areia e acena para a câmera (`TitoCastelinho.animar`). Só existe
  em E1967 (e, como "visão", dentro do Visor nas visitas 3 e 4). Nada de rosto realista, nada gráfico.

## As quatro visitas (V2)

O nível é o mesmo prédio nas quatro visitas; `GameState.visita` muda o estado. Gatilhos numerados pela sala base 1..22;
`sala = base + {0, 22, 44}` nas visitas 1 a 3, e a visita 4 comprime as bases nas salas 67..79 (`V4_SALAS`), com a 80 na porta
zebrada do hall. As bases 23, 24, 25 (porta de saída, corredor de 1975) contam como a 22.

| Visita | Hora/clima | O que muda |
|---|---|---|
| 1 | manhã de sol | 3 sementes (recorte virado para a parede, desenho nº 1 no Salão de Arte, criança no mural). Visor + disco 1950 na sala 10. Diploma. |
| 2 | fim de tarde, vento | painéis `_v2`; telefone (sala 34), engasgo (33), recorte que cai (37), Barra (mural, 36); disco 1967 no Acervo; diploma "TITO", apagão de 2 s e balde vermelho no trono. |
| 3 | noite, lanterna | Quico entrega a lanterna; cartazes PROCURA-SE; porta para 1950 (Ato II) no Salão de Arte; disco 1975 no topo da Torre A; marcas de altura (só em 1975); pinguim que olha; armadura; saída com fita zebrada (em 1975 aberta, pelo corredor). |
| 4 | madrugada, chuva | painéis com desenhos do Tito; disco 2019 atrás do painel solto (Povos); porta zebrada no hall (sala 80) e escada na Sala Medieval (só em 2019): descem para o porão. |

Checkpoints (globais): 1, 10, 16 | 23, 32, 38 | 45, 54, 61 | 67, 72, 77 | porão 81 e 95. Marcadores `Checkpoint_<base>` e
`Checkpoint_<global>`. Orçamento: no máximo 6 luzes (Sol/Lua + 5 lâmpadas na visita 1/2; 4 lâmpadas + lanterna nas 3 e 4).

 (invenção plausível; não existe planta real)

Fachadas e volumes seguem as fotos; o miolo é nosso. Sequência linear das salas do roteiro (norte em cima, x cresce
para a direita):

```
  x:  -27 ......... -22.6 ......... -16 ........ -12.5 ........ -5
z -29.5            .      ala dos fundos (Sala Medieval 21-23, x -17..-8,2)
z -23.5   ┌────────────── corredor da Secretaria (10) ──────────── Torre B (19, sobre a laje)
z -20.5   │  Meio Ambiente (9)  │ escada │ B4: Salão de Arte (11) / Acervo (12)
z -15       ├──────────────────┬──────────┤ B4: Sala do Pescador (13-15)
z -14   anexo+torre A: Povos (8) │ hall/galeria da arcada (7), 5 arcos
z -11   ═══════ fachada sul (Av. Garibaldi) ═════════════════════
```

1. Calçada (1), gramado/churrasqueira (2), lateral da torre com hortênsias (3), deck (4), arcada (5), porta (6).
2. **Hall** (7): galeria da arcada, entrada pelo arco do canto leste (porta de vidro, abre ao ler o P06).
3. **Povos Originários** (8): térreo da Torre A + anexo, ligados por um arco largo.
4. **Meio Ambiente** (9): bloco do pátio, com o pinguim cujos olhos seguem o jogador.
5. **Corredor da Secretaria** (10): Bentinho entrega o Visor.
6. Corpo principal: **Salão de Arte** (11) e **Acervo** (12, telefone que toca) na metade norte; **Sala do Pescador**
   (13-15, mural) na metade sul, ligadas por um arco. O mural leva ao flashback da Barra.
7. **Escada** (16): pela porta oeste do Salão, sobe para a laje do pátio (3,5 m). Escada reta de 24 graus em corredor fechado.
8. **Terraços** a 3,5 m formam uma só rede (laje do pátio, laje dos fundos, terraço da arcada):
   **topo da Torre A** (17, escada de 41 graus pelo 2º nível), **terraço ameado da arcada** (18), **Torre B** (19).
9. **Descida** (20) pela mesma escada do pátio, corredor, **Sala Medieval** (21 e 22: lareira, tronos, escudos, tochas,
   quiz final) e **porta de saída** (23, fita zebrada na época de hoje).
10. **1975** (24, 25): o mesmo espaço mobiliado e o corredor de 1975, só em E1975.

Escalas: olhos a 1,55 m, cápsula de 0,3 m de raio, portas de 0,95 a 1,6 m de largura e 2,1 m ou mais de altura,
degraus visuais de ~19 cm sobre rampa de colisão. O teste `tests/castelinho_test.gd` anda esse percurso inteiro com o
controlador real (portas, escadas, terraços, torres).

## Desempenho (web)

* Geometria estática junta por material (`Malha`): o prédio inteiro são ~60 superfícies; cores lisas e tons de uma mesma
  textura viram um só material (cor de vértice). Pinheiros em 3 `MultiMeshInstance3D`.
* Medido com `tests/captura_cam.gd` (renderizador de verdade): **70 a 150 draw calls** por vista e ~20 mil triângulos;
  o teste automático estima o teto em ~130. Painéis (`Painel3D`, ~12 superfícies cada) têm `visibility_range_end`
  (9 m dentro, 13 m fora), então só os mais próximos pesam.
* Colisão separada da malha, em caixas e prismas convexos (rampas). Nada de CSG.
* Malhas internas na camada visual 2 (o Sol tem `light_cull_mask = 1`): o interior não recebe Sol através do telhado
  e fica mais escuro, só com luz ambiente e as luzes quentes. No máximo 5 `OmniLight3D` ligadas (as mais próximas).
* Sem sombras dinâmicas: as sombras no chão são pintadas (`sombras.gd`) e o pé das paredes escurece no shader.
  Decalques colados em parede precisam de pelo menos 3 cm de folga (2 cm ainda brigam com a profundidade em `inte`).
* Painéis: `Painel3D.alcance` (9 m dentro, 13 m fora) é reaplicado quando a placa se reconstrói por `corruption`.
  Sem isso, o nível passava de 300 draw calls assim que a corruption subia. A moldura de cada placa é uma malha só.
* Medido depois da revisão gráfica: **66 a 100 draw calls** por vista em 2020 (até 134 com corruption 0,3 no Salão
  de Arte) e ~39 mil triângulos, quase todos dos pinheiros.

## Como regenerar

```
python3 tools/gerar_texturas.py                 # texturas (opcional: nomes das funções)
python3 tools/comparar_fotos.py build/capturas build/capturas/cmp   # foto real x jogo, lado a lado
python3 tools/gerar_medidas_embutidas.py        # depois de editar castelinho/medidas.json
godot --headless --import
bash tools/testar.sh
xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cam.gd -- \
    res://world/niveis/castelinho.tscn build/capturas/cast Cam_drone,Cam_frontal,Cam_hall 3 0
```

Câmeras `Cam_*` do nível: drone, frontal, esquina, torres, aerea2019, fundos, hall, medieval, nucleo1950, topo_torre,
pescador, corredor, escada, terraco, salaarte, povos, ambiente, torreb, corredor1975, spawn, deck, e da V2: obra1967,
tito1967, buraco1967, acervo, porta_ato2, porta_porao, escada2019, povos2. Argumentos de `captura_cam.gd`: época (0 = 1950,
1 = 1975, 2 = 2019, 3 = 2020, 4 = 1967), corrupção, **visita** (1 a 4) e flags a ligar (ex.: `evt_v2_apagao`).

## Limitações conhecidas

* Fachadas norte e oeste, telhados por dentro e a escada real das torres não têm foto: são invenção.
* O letreiro "Castelinho" é uma fonte serifada (sem fonte gótica livre no repositório) e a placa traz o programa
  fictício, nunca o brasão ou o nome oficial da prefeitura.
* Medido na V2 (`captura_cam.gd`): 70 a 113 draw calls nas visitas 1 a 4 e 11 a 16 em 1967 (o teste estima o teto sem frustum).
* O painel p08 da Sala dos Povos estava enterrado na parede (x -26,76; a face interna é x -26,4): corrigido; `castelinho_test`
  confere que todo painel visível é alcançável pelo raio do jogador.
* Em 1950 o jogador pode ficar preso numa parede se soltar Q dentro de onde uma parede reaparece; a cápsula se
  desprende sozinha, mas convém soltar Q em espaço aberto.
