# Pesquisa de game design: Spooky's Jump Scare Mansion e referências para o jogo do Castelinho de Imbé

Data da pesquisa: 2026-10-04. Escopo: inspiração para um jogo 3D de terror indie em Godot 4 que começa como "jogo educacional da prefeitura" fofo e vai ficando creepy até uma masmorra.

> **Nota de confiança.** O wiki Fandom do jogo, o TV Tropes e o PSNProfiles bloquearam o acesso direto (HTTP 402/403/429), então os dados sobre espécimes vêm de trechos de busca (títulos e resumos de páginas Fandom/TV Tropes/Steam) e de reviews lidos na íntegra. Onde houve conflito entre fontes ou só uma fonte fraca, está marcado com **[verificar]**. Números de sala são os que as fontes citaram; a versão HD Renovation muda alguns (ex.: Espécime 7 em 411 no original e 423 no remake). Não encontrei palestra de GDC nem entrevista longa com a Lag Studios; nada aqui é atribuído a "falas dos devs" além do que está nas páginas citadas.

---

## 1. Estrutura do Spooky's Jump Scare Mansion

### 1.1 Ficha técnica

| Item | Dado |
|---|---|
| Original | "Spooky's House of Jump Scares" (depois renomeado "Spooky's Jump Scare Mansion"), freeware em 24/10/2014 segundo a Wikipedia; Steam em 2015 |
| Estúdio | Lag Studios (Carolina do Norte), dupla Akuma Kira (design/programação) e AMGSheena (programação/QA/RP) |
| Engine original | GameMaker (8), com "técnicas elaboradas para emular 3D" |
| Remake | HD Renovation, 1/3/2017, Albino Moose Games, Unity, 3D de verdade |
| Portes | PS4 (2019), Switch (2022), Xbox (2023); suporte a VR |
| DLCs | Karamari Hospital (2015, "interquel") e Spooky's Dollhouse (2020, final) |
| Preço / recepção Steam | US$ 9,99; ~95-96% positivas em ~2.650 reviews |
| Duração | ~2 horas para as 1000 salas (segundo review) |
| Tags Steam | Horror, Indie, Cute, Funny, Jump Scare, Psychological Horror, First-Person |

### 1.2 As 1000 salas: geração semi-procedural

- O mapa é uma sequência linear de 1000 salas em 12 "andares" de 50, 100 ou 200 salas. Cada sala é um **template pré-feito** sorteado quando você abre uma porta. Não é geração de geometria; é **embaralhamento de salas modulares**. Salas de marco (milestones) e de introdução de espécimes são **scriptadas**.
- Depois de cada checkpoint (a cada 50 ou 100 salas), **novos layouts entram no pool**, o que sobe a dificuldade sem mudar as regras. Isso é o truque central: o jogador aprende a "ler" tipos de sala e escolher a rota mais eficiente.
- Salas variam de corredores simples a labirintos, salas de estar, florestas, laboratórios (GL Labs), "abismos" (salas escuras com vazios), uma "mansão dentro da mansão" (sala 810) e um restaurante (sala 710).
- **Save points** (cruzes roxas, tecla E): a cada 50 salas nas primeiras 300, depois a cada 100, mais salas 250 e 750.
- **Senhas** permitem retomar partidas e liberar variações (um review cita isso como incentivo de replay).

### 1.3 Espécimes (lista consolidada)

Espécime 1 é o "falso perigo". A partir do 2 há perseguição. Cada um tem tema musical próprio e uma "regra" distinta. Esta é a parte mais útil para nosso design.

| # | Primeira aparição | Comportamento | Como evadir | Confiança |
|---|---|---|---|---|
| 1 "Cutouts" | Sala 1 em diante (aleatório) | Recortes de papelão fofos (fantasminha azul, abóbora, sorvete, torrada...) saltam da parede com som alto. Congela o jogador ~0,5 s. Mais tarde, versões distorcidas ou caveira sangrenta. Inofensivo | Não precisa; é só susto | alta |
| 2 "Gel"/"Ink Boy" | Sala 60 | Primeiro hostil. Flutua e atravessa objetos; ligeiramente mais lento que o jogador andando. Deixa poças verdes que **lentificam** | Ouvir a música com batidas e o gemido; correr, evitar poças | alta |
| 3 | Salas ~120 (GL Labs) | Clique sonoro avisa. Rasteja, mesma velocidade do 2. Abre buracos no teto e cai de lá. 30 de dano por contato (cooldown 2 s); abaixo de 45 de vida mata no golpe seguinte | Correr; não ficar parado na sala | média-alta |
| 4 | ~166 | Inspirado em horror japonês / Corpse Party. Voa por vãos estreitos | Fácil de correr, mas cuidado com passagens apertadas | média |
| 5 | ~210 (outra fonte: 213+) | Alucinações: névoa na visão, paredes/chão/portas viram rios de sangue animados; persiste até escapar | Foco no layout da sala para não se perder | média **[verificar sala]** |
| 6 "Vendedor" | ~310 | Inspirado no Vendedor de Máscaras de Majora's Mask. **Só se move quando você não olha**; se você o encara parado por mais de ~8 s, some e ataca. Pode ser derrubado com machado/espada | Manter contato visual e andar, ou matar | alta |
| 7 | 411 (423 no HD) | Parede viva que ocupa **toda a largura** da sala e consome tudo lentamente; morte por contato. Salas vermelhas, piso xadrez, quadros animados, portas de metal | Fácil de correr | alta |
| 8 | 550-558 (após floresta/cabanas com cervos violentos) | Emerge de um beco escuro no fim da sala 558. Atravessa paredes e flutua sobre vãos; perigoso em salas não lineares (abismos) | Fazê-lo seguir o jogador por quase todo o caminho para reduzir a vantagem dele | média-alta |
| 9 | ~500s? "corredor infinito" | Domínio é um corredor escuro sem fim; quem entra fica preso até ser pego. Há relato de que o jogo envia o 9 atrás de quem altera o número da sala com programa externo (anti-cheat diegético) | **Não entrar no corredor sem fim** | média **[verificar]**: uma fonte também chama o chefe final de "Espécime 9" |
| 10 | 617 | Precisa ser mantido **perto**; se você se afasta, vira forma rápida (sanguessuga minúscula) | Ficar próximo dele o tempo todo (inversão do instinto de fugir) | alta |
| 11 "Food Demon" | Fim da sala 710 (restaurante; após pegar chave no freezer) | Mesma velocidade do jogador andando; pode **tornar as portas invisíveis** | Memorizar saídas; cuidado em salas abertas | alta |
| 12 "Old Man" | Sala 810 ("mansão dentro da mansão" vitoriana) | Duas formas: humanoide lento que bate forte; se você o ultrapassa ou ataca, gera forma de verme, mais perigosa | Não provocar; gerir a fuga | média-alta |
| 13 "Sereia" | Sala 910 | Penúltimo espécime | sem dado | baixa **[verificar]** |
| Chefe final | Sala 1000, no exterior | Luta contra "Espécime 9" segundo as fontes de finais | Machado | média **[verificar]** |
| 14 | Final ruim | O próprio protagonista, se violento demais | n/a | alta |
| 15 | citado em fórum Steam (estática na tela, grito, "forma berserk" do 4) | Pouco confiável | n/a | baixa **[verificar]** |

Notas: o protagonista tem barra de vida (3 acertos do Espécime 3 mata), há **machado** (sala 554, floresta) e **espada** (secreta, Karamari, New Game+).

### 1.4 Spooky: a guia fofa

- Fantasma de menina "de cabelo desgrenhado" (arquétipo de ghost girl), desenhada de forma infantil. Aparece como guia ao longo das salas, **parabeniza, narra, dá dicas** por cartazes e voz.
- Personalidade: "adorável e desajeitada" (gagueja, constrangida) mas **sarcástica**, cada vez mais decepcionada que você continue vivo. Congratula enquanto sugere o contrário.
- Backstory (cartas encontradas após a sala 50): em vida tentou assustar pessoas na noite de Halloween e nunca conseguiu; na última tentativa, uma vítima com TEPT atirou nela de susto. Pai fundou o GL Labs, que capturou/criou os espécimes. Ela virou a "mestra" deles.
- Papel de design: **voz de autoridade que muda de sentido** sem mudar de rosto. A guia é a mesma do início ao fim, só o que ela diz recontextualiza tudo.

### 1.5 Progressão de tom

1. **Salas 1-50 ("fofo")**: mansão de desenho infantil, recortes de papelão, apenas Espécime 1. Sustos barulhentos mas ridículos (e hilários). Funciona como paródia do gênero e como **treino**: você aprende que "susto = inofensivo".
2. **Sala ~50**: cartas revelam a backstory sombria, estética começa a abandonar o fofo.
3. **Sala 60**: primeiro perigo real (Espécime 2). Ensina a regra "música muda = perseguição".
4. **Salas 100-500**: laboratórios, abismos, alucinações, parede viva. Cada espécime ensina **uma ideia**.
5. **Sala 750**: troca de stamina por stamina infinita que **remove o sprint** (só dá para balançar o machado à vontade), até passar 15 salas (10 no HD). É uma quebra de regra deliberada para gerar vulnerabilidade.
6. **Salas 800-1000**: sequências temáticas (mansão dentro da mansão, restaurante, sereia) e chefe.

### 1.6 Finais (6 no total entre jogo base e DLCs)

- **Bom**: derrotar o chefe usando o machado **no máximo 20 vezes**. O teto cai e o protagonista morre, virando "o último fantasma" do exército de Spooky.
- **Ruim**: chefe derrotado com **mais de 20 usos** do machado. O protagonista continua golpeando o cadáver; Spooky chega e diz que ele dará um bom espécime.
- **Espécime**: mais de 20 "pontos de violência" **antes** do chefe (golpear espécimes específicos). Spooky o converte no Espécime 14.
- **Final de piada (HD)**: se espécimes estão desligados nas opções e você chega à 1000, vê uma sala de festa com balões e faixa "1000 Rooms!"; Spooky dá parabéns sem vontade.
- Mais finais em Karamari Hospital e Dollhouse (não detalhados).
- Lição: **o sistema de moralidade é invisível** (contagem de golpes) e o jogo comenta isso em vez de punir com UI.

### 1.7 DLCs e Endless

- **Karamari Hospital**: "universo alternativo em que o elevador caiu abaixo da sala 1000". Mapa **predefinido** (não aleatório), com "Monstros" novos. Contém a espada secreta (New Game+).
- **Spooky's Dollhouse**: depois do Karamari; andar de casa de bonecas onde o GL Labs prendia espíritos em bonecos. Você carrega uma **boneca encantada** para resolver puzzles e abrir portas. Novos "Dolls" como inimigos.
- **Endless Mode** (atualização de 4/7/2016): espécimes de todos os tipos podem aparecer a qualquer momento; "Unknown Specimens 1-5" (ex.: o "White Face" 8-bit, referência a IMSCARED) aparecem em números aleatórios. Também há "Build Your Own Mansion" com Steam Workshop no HD.

---

## 2. Mecânicas

| Sistema | Como funciona |
|---|---|
| Movimento | Primeira pessoa, WASD + mouse; **Shift** corre; **E** abre portas, lê notas, salva; botão esquerdo usa o machado |
| Stamina | Barra esvazia em ~4 s de sprint e recarrega na mesma velocidade; cada toque em Shift gasta um pouco (spam esvazia a barra sem se mover). Machado: armar e golpear gastam ~1/10 cada |
| Combate | **Evitar é o padrão**. Machado opcional e arriscado (afeta o final). Só alguns espécimes são mortos pelo machado (ex.: 6). Sem armas de fogo |
| Itens | Machado, espada (secreta), chaves, notas/cartas de lore; boneca (Dollhouse) |
| Vida | Existe barra de vida (ex.: 30 de dano do 3) |
| Save | Cruzes roxas em intervalos; senhas |
| HUD | Mínimo: stamina, vida, número da sala. O **contador de sala** é o próprio "mapa de progresso" |
| Escalada de tensão | (a) novos layouts a cada checkpoint; (b) um espécime novo com regra nova a cada ~100 salas; (c) música de perseguição por espécime; (d) quebra de regra no 750 |
| Ritmo | Longos trechos de salas calmas, sustos barulhentos inofensivos, depois picos de perseguição curtos. As salas de save funcionam como "respiros" |
| Áudio | Trilha com ~3 faixas ambientes + tema por espécime; sinais sonoros de aviso (clique do 3, batidas do 2, silêncios). Review: temas dos espécimes são esquecíveis quando só aparecem uma vez |

Observação de design: **todo espécime tem uma resposta legível** (correr, não olhar, ficar perto, não entrar). O medo vem de ter de descobrir e executar a regra sob pressão, não de reflexo puro.

---

## 3. Por que funciona (e onde falha)

### 3.1 Pontos fortes

1. **Subversão de tom em camadas**: o jogo se vende como paródia de jump scare ("morbidly cute... reminiscent of childish drawings") e usa isso para baixar a guarda. Quando o perigo real chega na sala 60, o contraste é o susto.
2. **Humor e medo se alimentam**: os recortes absurdos criam afeição; Spooky sarcástica cria cumplicidade; o horror real depois tem peso porque você "gosta" do mundo. Um review resume: "paródia do gênero e horror genuíno".
3. **Quebra da quarta parede controlada**: Spooky fala diretamente com o jogador; o jogo detecta alteração de sala por programa externo; o final de piada com espécimes desligados reconhece as opções do jogador.
4. **Loop simples e legível**: abrir porta, ler a sala, escolher rota. Review: "sounds quite boring, but they do so much with this simple formula".
5. **Perseguidores com regras distintas**: cada um ensina uma habilidade (ouvir, olhar, aproximar-se, memorizar saídas).
6. **Referências a outros jogos** (Majora's Mask, Corpse Party, Silent Hill, SCP, IMSCARED) dão camada de "easter egg" para a comunidade e rendem Let's Plays.
7. **Escala de dificuldade pelo pool de salas**, não por stats.

### 3.2 Críticas e pontos fracos

- **Repetição**: salas parecidas; "1000 salas" soa entediante; reviews dizem que ainda é "um pouco repetitivo".
- **Ritmo lento no início**: a "queima lenta" de ~100 salas testa a paciência (Save or Quit).
- **Salas de puzzle** com sequência aleatória ficam "extremamente tediosas depois da quinta vez" (Rely on Horror).
- **Polimento**: texturas com glitch, salas secretas "raras" aparecendo demais, furtividade "contextual demais"; no HD, sensibilidade do controle não funcionava no lançamento e "feel de Early Access".
- **Trilhas de espécimes esquecíveis** quando vistos uma vez.
- Dependência de jump scares pode afastar quem quer horror "substancial".
- **Avisos para nós**: se o início for longo demais sem variação, o jogador sai antes da virada. Se a virada for "só mais um monstro", perde-se a subversão.

---

## 4. Jogos de referência com transição "educacional/infantil para horror"

| Jogo | O que faz | O que ensina para o Castelinho |
|---|---|---|
| **Baldi's Basics in Education and Learning** (Micah McGonigal, 2018, Meta Game Jam) | Paródia de edutainment dos anos 90; 7 cadernos e um professor perseguidor. O criador buscou o sentimento "off/unsettling" dos jogos educativos reais via mistura de 3D e 2D inconsistente | **É a referência mais direta.** O *uncanny* nasce de **estética de baixo orçamento + voz de apresentador animado + regras escolares absurdas**. Texto de "folheto da prefeitura" lido em voz entusiasmada (TTS ou voz amadora) já é creepy. Mistura sprites 2D com 3D |
| **Doki Doki Literature Club** | Visual novel fofa que quebra a quarta parede e mexe nos arquivos do jogo | Falsas "interfaces de sistema" e menu que muda; usar **a própria UI** (menu, créditos, tela de save) como lugar do horror. Aviso de conteúdo no início cria expectativa irônica. Cuidado: usa arquivos do PC; fazer só em escopo diegético |
| **Poppy Playtime** | Fábrica de brinquedos abandonada, mascote fofo vira antagonista, VHS de propaganda | **Fitas/VHS de propaganda institucional** que revelam a verdade aos poucos. Mascote que parece amigável é bom vilão. Itens-ferramenta (mão grabpack) como mecânica de puzzle |
| **Bendy and the Ink Machine** | Desenho dos anos 30, estúdio decadente, tinta | Direção de arte coesa em torno de um estilo "vintage" e a descida física para níveis mais profundos (a masmorra). Texto em paredes como narrativa |
| **Happy's Humble Burger Farm** | Fast-food simulador onde o trabalho cotidiano vira surreal | **Tarefas mundanas viram mecânica**; o ambiente "profissional" fofo se degrada. Funciona mistura de engraçado, esquisito e perturbador |
| **Mouthwashing** (Wrong Organ, 2024) | PS1-style, nave cargueira, humor negro e tragédia, tempo não linear, alucinações | Mostra que **estilo low-poly + tom emocional/humor negro** funcionam; o horror vem do que *aconteceu*, não do monstro. Usar o espaço real (castelinho) como cenário de memória |
| **Iron Lung** (David Szymanski, 2022) | Submarino cego em oceano de sangue, minimalista | Limitar informação visual. Horror por **ausência** e instrumentos. Útil para uma seção final curta (cofre/masmorra) |
| **PS1 horror (Puppet Combo, etc.)** | Visual PS1, grain, slasher | Estética de baixo custo que "esconde" o orçamento e aumenta o creepy; shaders de PSX são faceis no Godot |
| **Analog horror: Local 58, The Mandela Catalogue** | Falsas transmissões institucionais (TV local, alertas), horror pelo contexto burocrático | **A inspiração perfeita para "jogo educacional da prefeitura"**: uma campanha de "educação patrimonial" com locução calma que vai dizendo coisas erradas; avisos oficiais que se contradizem; "regras de visita" (como Mandela Catalogue). Texto e áudio fazem 80% do trabalho |
| **IMSCARED**, **Spooky's** | Quarta parede em jump scare | Já ligado ao nosso modelo |

Resumo da lição por categoria:
- **Paródia + horror real** (Spooky's, Baldi's, HHBF): comece engraçado, comprometa-se com o horror depois.
- **Falsa autoridade institucional** (analog horror, Poppy VHS): a voz oficial é o monstro.
- **Interface como arma** (DDLC): o menu, a barra de carregamento e o save podem mudar.
- **Minimalismo** (Iron Lung, Mouthwashing): o que *não* se vê vale mais.

**Nota legal**: usar "Prefeitura de Imbé" real como emissora do jogo educacional pode confundir e ser sensível (órgão real, patrimônio municipal real). Sugestão: criar uma **entidade fictícia** (ex. "Secretaria Municipal de Educação Patrimonial de Imbé") e deixar claro que é ficção. Obras de analog horror evitam marcas reais pelo mesmo motivo.

---

## 5. Técnico em Godot 4

### 5.1 Contexto do Castelinho (para ancorar o cenário)

- Construído entre ~1950 e 1956 (conclusão do fechamento em 1975, segundo uma matéria) por Walmyr Roszanyi, professor de artes de Santo Antônio da Patrulha, como casa de veraneio; pedra cinza transportada de barco pelo rio Tramandaí.
- A Prefeitura comprou o imóvel (~R$ 703 mil) para virar Casa de Cultura e Museu Municipal; abre aos sábados com visitas guiadas (9h-17h) na Av. Nilza Costa Godoy esq. Av. Garibaldi, Imbé/RS.
- Ideia aproveitável: a Casa de Cultura real é um **museu com visita guiada**, formato natural para a "guia fofa" estilo Spooky.

### 5.2 Controlador FPS

| Recurso | URL | Observação |
|---|---|---|
| Facility 13: FPS Horror Starter (CommunityPokeOrg) | https://github.com/CommunityPokeOrg/godot-fps-horror | Godot 4.3+, lanterna, sanidade, IA, stamina que drena e faz ruído. **Licença não confirmada [verificar]** |
| NOSHOT First Person Controller | https://github.com/theRealUnd3rdog/Godot_Noshot_Controller | Godot 4.2, sons de passos por superfície |
| Jeh3no Advanced State Machine FPC | https://github.com/Jeh3no/Godot-Advanced-State-Machine-First-Person-Controller | Máquina de estados, bem comentado |
| Quality Godot First Person 2 | https://github.com/ColormaticStudios/quality-godot-first-person-2 | Controlador "bem feito" |
| Simple First Person Controller | https://godotengine.org/asset-library/asset/3882 | Pular, agachar, passos |
| Advanced First Person Controller | https://godotengine.org/asset-library/asset/3475 | Asset Library |

Recomendação: **escrever o nosso** com um `CharacterBody3D` (200 linhas) e usar os repositórios só para consulta; stamina é um float com regras de regeneração, como no Spooky's (4 s de sprint e ~4 s de recarga).

### 5.3 Geração procedural / templates de salas

| Recurso | URL | Observação |
|---|---|---|
| dungeon-crawler-3d (p-lorenzo) | https://github.com/p-lorenzo/dungeon-crawler-3d | Prefab rooms com conectores automáticos e validação espacial |
| SimpleDungeons (majikayogames) | https://github.com/majikayogames/SimpleDungeons | Salas prefab definidas pelo usuário |
| godot-procedural3d (RodZill4) | https://github.com/RodZill4/godot-procedural3d | Salas modulares com saídas |
| Dingo | https://github.com/benjtek01/dingo-godot-addon | Layout por GridMap |
| GDQuest procedural generation demos | https://github.com/gdquest-demos/godot-4-procedural-generation | Algoritmos didáticos |
| WFC 3D (MarkusMannil) | https://github.com/MarkusMannil/WaveFunctionCollapse3DPlugin | Regras por lado dos objetos |
| Cade-WFC | https://github.com/ctrlcade/Cade-WFC | WFC 3D |
| Astral-Sheep WFC | https://github.com/Astral-Sheep/WaveFunctionCollapse | 2D e 3D |
| godot-constraint-solving (AlexeyBond) | https://github.com/AlexeyBond/godot-constraint-solving | WFC/CSP |

**Conselho**: para nosso caso (corredor linear de N salas, como Spooky's) **não precisamos de WFC**. Um `RoomPool` com `PackedScene` de salas pré-feitas (cada uma com `Marker3D` "entrada" e "saída"), sorteio por *tier* e instanciar a próxima sala só quando a porta abre (descarregar a anterior) é mais barato, controlável e reproduz o modelo do jogo de referência. WFC só vale para a masmorra se quisermos labirinto.

### 5.4 Shaders estilo PS1

| Recurso | URL | Licença / nota |
|---|---|---|
| PS1/PSX Visuals GD4 port (scolastico) | https://github.com/scolastico/psx_visuals_gd4 | **MIT** (segundo o resultado); vertex snapping, affine, fog por distância, dithering pós-processo |
| Asset Library, PSX Visuals GD4 | https://godotengine.org/asset-library/asset/4687 | espelho |
| Asset Library, PSX Visuals (original) | https://godotengine.org/asset-library/asset/4557 | |
| godot-psx-look-free | https://github.com/Spyridon-Pikoulas/godot-psx-look-free | "Free for commercial use"; vertex snap, affine, tela 240p **[licença exata: verificar]** |
| godot-psx-style-demo (adamscott) | https://github.com/adamscott/godot-psx-style-demo | MIT |
| PS1 Shader (godotshaders) | https://godotshaders.com/shader/ps1-shader/ | cada shader do site tem licença própria; conferir |
| PS1/PSX PostProcessing | https://godotshaders.com/shader/ps1-psx-postprocessing/ | |
| Godot Color Dither | https://github.com/Donitzo/godot-color-dither | https://godotengine.org/asset-library/asset/3036 |
| Simple Ordered Dithering + Pixelation | https://godotshaders.com/shader/simple-ordered-dithering-and-screen-pixelation/ | Bayer 4x4 |
| Retro Post-Processing | https://godotshaders.com/shader/retro-post-processing/ | |

Ideia de design: **o shader PSX é o termômetro de horror**. Comece com uma versão "limpa" (sem snapping, cores vivas, 1080p) para o visual de jogo infantil e aumente progressivamente: snapping, dithering, resolução menor, paleta dessaturada, grain. Assim a transição de tom é também uma transição técnica, controlada por um único parâmetro global `corruption` (0 a 1).

### 5.5 IA de perseguidor (NavigationAgent3D)

- `NavigationRegion3D` com navmesh baked, `CharacterBody3D` + `NavigationAgent3D`; ler `get_next_path_position()` a cada `_physics_process`; atualizar `target_position` num `Timer` (ex. 0,2 s), não a cada frame.
- Máquina de estados: `IDLE`, `PATROL`, `INVESTIGATE`, `CHASE`, `ATTACK`; duas `Area3D` (detecção e ataque), mais *raycast* de linha de visão.
- Tutoriais: https://codingquests.io/blog/godot-4-enemy-ai-tutorial ; https://www.youtube.com/watch?v=5hW9A2XFm38 ("Godot 4 Navigation for 3D Games: Get Enemies to Chase You"); https://www.youtube.com/watch?v=-juhGgA076E ; https://forum.godotengine.org/t/how-to-make-ai-chase-the-player/43001
- **Inspirado no Spooky's**: não precisa de pathfinding sofisticado. Espécimes 2, 4, 8 atravessam paredes ou voam; só alguns precisam de navmesh. Cada perseguidor com **uma regra** (olhar, proximidade, som) vale mais que IA complexa.

### 5.6 Diálogo

| Recurso | URL | Licença / nota |
|---|---|---|
| Dialogic 2 | https://github.com/dialogic-godot/dialogic | MIT. A busca indicou exigir **Godot 4.5+ [verificar]**; Asset Library: https://godotengine.org/asset-library/asset/833 |
| Dialogue Manager (Nathan Hoad) | https://github.com/nathanhoad/godot_dialogue_manager | MIT. Versão 4 pede **Godot 4.6+ [verificar]**; versões anteriores atendem 4.x mais antigos; Asset Library 1432 (v2) |

Para esse jogo (guia que fala, notas, avisos de "folheto"), **Dialogue Manager** é mais leve (texto estilo script, sem editor visual pesado); Dialogic compensa se quisermos retratos animados e caixas de texto personalizadas tipo visual novel (útil para a guia estilo Doki Doki).

### 5.7 Áudio 3D

- `AudioStreamPlayer3D` com atenuação e `Area3D` com **reverb bus** por sala (cada tipo de sala escolhe o bus): https://docs.godotengine.org/en/stable/tutorials/audio/audio_streams.html e https://docs.godotengine.org/en/stable/tutorials/audio/audio_effects.html
- `AudioEffectReverb`: https://docs.godotengine.org/en/4.3/classes/class_audioeffectreverb.html
- Oclusão: não é nativa. Opções de terceiros: godot-steam-audio (https://github.com/stechyo/godot-steam-audio/wiki) e GigaAudio (https://stuyk.itch.io/gigaaudio-for-godot). Alternativa barata: *raycast* do emissor ao jogador e filtro *low-pass* por bus.
- Bug a conhecer: issue #96480 (reverb bus de `Area3D` afetando saída do player 3D): https://github.com/godotengine/godot/issues/96480
- **Dica de design**: silêncio e "música de elevador/jingle institucional" que fica distorcida com `corruption` são mais assustadores que estingers.

### 5.8 Névoa

- **Volumetric fog e FogVolume só funcionam no renderer Forward+**, não em Mobile/Compatibility: https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html ; https://godotengine.org/article/fog-volumes-arrive-in-godot-4/
- Para estética PS1 a névoa simples de profundidade (`Environment.fog_enabled`, funciona em todos os renderers) já basta e custa menos; reservar volumétrica para a masmorra se o público-alvo tiver GPU razoável. Decidir o renderer cedo, pois afeta shaders.

### 5.9 Licenças e fontes de assets CC0

| Fonte | URL | Licença |
|---|---|---|
| Kenney | https://kenney.nl/assets | CC0, uso comercial livre, atribuição opcional |
| Poly Haven | https://polyhaven.com/license | CC0 (texturas, modelos, HDRIs) |
| ambientCG | https://ambientcg.com/ ; https://docs.ambientcg.com/license/ | CC0 1.0 |
| Freesound | https://freesound.org/help/faq/ | **Misto**: CC0, CC-BY (exige atribuição), CC-BY-NC (**não usar** em jogo comercial). Filtrar por CC0 e guardar registro de autoria |
| Godot Shaders | https://godotshaders.com | Licença por shader; conferir |

Boa prática: manter `docs/CREDITS.md` e `assets/_licenses/` com uma linha por asset (origem, URL, licença, data). Para addons MIT, incluir o arquivo LICENSE no repositório.

---

## 6. Plano de adaptação sugerido (para discussão)

1. **Fase 1, "Visita Guiada" (fofo)**: Castelinho em cores vivas, filtro limpo, guia fofa (mascote fictício) que narra como "aplicativo educacional da Secretaria". Recortes de papelão ("Espécime 1") com sustos ridículos.
2. **Fase 2, "Contradições"**: folhetos e placas com informações erradas; voz da guia começa a se corrigir; primeira perseguição curta (equivalente à sala 60).
3. **Fase 3, "Fechado para Reforma"**: salas fora do mapa real, shader PSX subindo, interface falhando (estilo DDLC), fitas VHS (estilo Poppy/analog horror).
4. **Fase 4, "Masmorra"**: descida física (escada/elevador), sem guia, névoa, perseguidores com regras próprias, uma seção "Iron Lung" (visão limitada).
5. **Finais** dependentes de contagem invisível (violência, curiosidade, cumprimento das "regras de visita"), como no Spooky's.

---

## Lista de fontes

**Spooky's Jump Scare Mansion**
- Wikipedia: https://en.wikipedia.org/wiki/Spooky%27s_Jump_Scare_Mansion
- Steam (HD Renovation): https://store.steampowered.com/app/577690/Spookys_Jump_Scare_Mansion_HD_Renovation/
- Fandom wiki (acesso bloqueado; usados resumos de busca): https://spookys-jump-scare-mansion.fandom.com/wiki/Rooms , /Game_Mechanics , /Axe , /Sword , /Endings , /Endless_Mode , /Specimen_2 a /Specimen_13 , /Lag_Studios
- Villains Wiki (Specimens): https://villains.fandom.com/wiki/Specimens_(Spooky's_Jump_Scare_Mansion)
- TV Tropes: https://tvtropes.org/pmwiki/pmwiki.php/VideoGame/SpookysJumpScareMansion ; /Characters/SpookysJumpScareMansion ; /NightmareFuel/SpookysJumpScareMansion ; /YMMV/SpookysJumpScareMansion
- Save or Quit (review HD): https://saveorquit.com/2017/04/01/review-spookys-jump-scare-mansion-hd-renovation/
- Rely on Horror (review): https://www.relyonhorror.com/reviews/review-spookys-house-of-jump-scares/
- Witch's Review Corner: https://witchsreviewcorner.com/2017/03/21/spookys-jump-scare-mansion-hd-renovation-review/
- Guias Steam: https://steamcommunity.com/sharedfiles/filedetails/?id=553889246 ; https://steamcommunity.com/sharedfiles/filedetails/?id=1460297071 ; https://steamcommunity.com/sharedfiles/filedetails/?id=2971908036
- The Cutting Room Floor (HD vs freeware): https://tcrf.net/Spooky's_Jumpscare_Mansion:_HD_Renovation/Changes_from_the_Freeware_Version
- Nota: PC Gamer e Rock Paper Shotgun não retornaram reviews do jogo na busca.

**Referências de tom**
- Baldi's Basics (Wikipedia): https://en.wikipedia.org/wiki/Baldi%27s_Basics_in_Education_and_Learning
- Mouthwashing (Wikipedia): https://en.wikipedia.org/wiki/Mouthwashing_(video_game) ; entrevista Skybox Critics: https://skyboxcritics.com/2025/07/14/mouthwashings-genesis-sick-jokes-and-the-thin-line-between-goofy-and-grotesque-an-interview-with-wrong-organ/
- Iron Lung (Wikipedia): https://en.wikipedia.org/wiki/Iron_Lung_(video_game)
- Happy's Humble Burger Farm (OpenCritic): https://opencritic.com/game/12432/happys-humble-burger-farm/reviews
- Doki Doki Literature Club, Poppy Playtime, Bendy, Puppet Combo, Local 58, The Mandela Catalogue: conhecimento geral, **não pesquisados nesta rodada** (descrições acima de memória; vale checar antes de citar publicamente). "Wrestling Wolf" (citado no pedido) não foi localizado.

**Castelinho de Imbé**
- Beta Redação: https://www.betaredacao.com.br/o-castelinho-de-imbe-um-sonho-de-pedra-a-beira-mar/
- Jovem Pan Litoral (compra): https://jplitoral.com.br/patrimonio-historico-prefeitura-de-imbe-fecha-compra-do-castelinho/
- Correio do Imbé: https://www.correiodoimbe.com.br/noticia/castelinho-da-cultura-em-imbe-estara-aberto-aos-sabados-para-visitacao
- Museus.gov.br: https://cadastro.museus.gov.br/museus/casa-de-cultura-e-museu-municipal-de-imbe/

**Godot**
- Repositórios e docs listados na seção 5 (todos os URLs vieram de resultados de busca; licenças marcadas "[verificar]" devem ser conferidas no arquivo LICENSE antes do uso).
- Volumetric fog: https://docs.godotengine.org/en/latest/tutorials/3d/volumetric_fog.html
- Kenney: https://kenney.nl/support ; Poly Haven: https://polyhaven.com/license ; ambientCG: https://docs.ambientcg.com/license/ ; Freesound: https://freesound.org/help/faq/
