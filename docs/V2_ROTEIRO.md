# Versão 2: quatro visitas, o porão e o menino do Braço Morto

> Aprovado pelo Icaro em 05/10/2026. Substitui a estrutura de atos do `MVP_ROTEIRO.md`; os sistemas e as APIs de lá continuam valendo. Regras de ética do `PLANO.md` §3 continuam inegociáveis, com os acréscimos da §1.

## 1. A história (tudo fictício)

**Tito**, 9 anos, é um menino **fictício**. A família dele veraneava em Imbé e alugava uma casa perto do Castelinho. Em **março de 1967**, no fim da temporada, ele sumiu. Na cidade, a lenda diz que ele se afogou no **Braço Morto**, o antigo braço do Rio Tramandaí.

- O jogo nunca diz que alguém o matou. **A história não culpa ninguém real nem fictício**: nem o construtor real do Castelinho, nem a família real, nem qualquer morador.
- **Ganchos reais** (`pesquisa/braco_morto.md`):
  - o Braço Morto ficou isolado do rio justamente **nos anos 1960**, quando a barra foi fixada. Em 1967 ele ainda "morria";
  - hoje o lago é o ponto mais baixo da cidade e recebe os córregos canalizados que passam sob a **Av. Nilza Godoy e a Garibaldi**, a esquina do Castelinho.
  - O jogo pode dizer que "a água desce por baixo do Castelinho até o Braço Morto" sem inventar fato sobre ninguém.
- O que o jogo sugere: Tito seguiu a **Figura Branca** (a "Aparição" da lenda do Passo da Mãe Rosa) até a água. A água do Braço Morto corre **por baixo do Castelinho**, num porão que não existe na planta.
- **A mãe de Tito** (fictícia, sem nome) aparece só como voz no telefone do acervo e em cartazes de "PROCURA-SE".
- **Pesado sem ser gráfico:**
  - desenhos de criança que pioram;
  - marcas de altura na parede que param de crescer;
  - a voz dele;
  - a água subindo;
  - o último slide.
  - Nada de corpo, sangue ou violência mostrada contra criança.

**Linhas que continuam fora:**
- o Caso Miguel ou qualquer caso real;
- nomes reais em eventos sombrios;
- a enchente de 2024 como espetáculo.

**Tela de dedicatória (fim, obrigatória):** fundo preto, sem som de susto, depois dos créditos:
> *Tito é um personagem fictício. As crianças que sofrem violência e abandono não são.*
> *Se você desconfia de que uma criança está em perigo: **Disque 100** (Direitos Humanos, gratuito, 24h) ou procure o **Conselho Tutelar** da sua cidade.*

## 2. Estrutura e ritmo

O contador continua sendo de 100 salas, e o HUD mostra **"VISITA 2 · SALA 27"**.

| Bloco | Salas | Hora / clima | Corruption | Sensação |
|---|---|---|---|---|
| **Visita 1** | 1–22 | Manhã de sol | **0 o tempo todo** | Jogo educativo de prefeitura, quase nada estranho |
| **Visita 2** | 23–44 | Fim de tarde, vento | 0,10 → 0,22 | "Tem algo errado com os textos" |
| **Visita 3** | 45–66 | Noite, lanterna | 0,30 → 0,45 | Medo de verdade, primeiras perseguições |
| **Visita 4** | 67–80 | Madrugada, chuva | 0,50 → 0,65 | O Castelinho está errado; a porta zebrada está aberta |
| **Porão** | 81–100 | Sem hora | 0,70 → 1,00 | Masmorra, água subindo, horror pleno |

**Ritmo (pedido do Icaro): mais lento até ficar bizarro.**
- **Visita 1:** só **três sementes** discretas (§3.1). Nenhum susto, nenhuma criatura.
- **Visita 2:** os sustos são piadas de papelão. O primeiro medo "de verdade" é **só no fim da visita 2**.

**O loop:** ao terminar cada visita, a saída devolve o jogador à **calçada da Av. Garibaldi**.
- A transição é um fade e a placa "Volte sempre!"; a próxima visita começa no `Spawn` com outra iluminação e outro estado.
- Mesmo prédio, mesmas salas físicas (estilo *P.T.*): o que muda é o estado.
- No nível, `sala = base + deslocamento[visita]`. Os gatilhos continuam numerados pela "sala base" (1–22).

## 3. As quatro visitas

### 3.1 Visita 1: "Bem-vindo ao Castelinho!" (salas 1–22)

O roteiro das salas 1–22 do MVP, **mais calmo**:
- painéis p01…p22 com os textos educativos atuais;
- quizzes e selos;
- diploma na Sala Medieval.

**Saem da visita 1** e vão para a 2 ou a 3:
- o engasgo do Bentinho;
- o telefone que toca;
- os recortes que caem;
- os olhos do pinguim;
- a armadura no trono;
- a saída em reforma.

**As três sementes:**
1. o recorte de papelão virado para a parede (já existe);
2. no Salão de Arte, um **desenho de criança** entre os quadros dos artistas locais: um castelo e um boneco palito, assinado "TITO";
3. na Sala do Pescador, o mural tem **uma criança na margem** que ninguém comenta.

**O Visor do Tempo** é entregue na sala 10 com o **Disco 1950**, um "brinde educativo".
- É só brinquedo: mostra o núcleo de 1950 na areia, com legenda didática.
- Não há "atenção" nesta visita.

**Fim:** diploma, porta de saída, fade, a placa **"Obrigado pela visita! Volte sempre!"** e **VISITA 2** começa na calçada.

### 3.2 Visita 2: "Informações atualizadas" (salas 23–44)

- **Clima:** fim de tarde alaranjado, vento, jingle_1.
- **Painéis reescritos:** o mesmo painel diz outra coisa, com fato real sem verniz. "Os pescadores foram **removidos**", "Sambaquis também eram **cemitérios**", "Afogamentos na barra: Imbé concentra 13% das mortes do estudo". Os textos ficam em `data/paineis.json` com sufixo `_v2`.
- **Telefone do acervo:** toca. Voz de mulher, chiada: *"Alô? É do Castelinho? O meu filho... ele vinha sempre brincar aí na obra... vocês viram o Tito?"*, e desliga.
- **Disco 1967:** fica no Acervo, numa vitrine com uma etiqueta à mão "não catalogado". Mostra o Castelinho **em obra**, com as torres pela metade, andaimes e a pilha de pedras trazidas pelo rio. **Tito** brinca de castelo na areia ao lado: menino magro, bermuda azul, balde vermelho. Ele **acena** para a câmera.
- **Bentinho:** engasga (sala 11+22 = 33).
- **Sustos-piada:** o recorte de pescador cai (sala 37).
- **Flashback da Barra (sala 36):** o minigame da tarrafa que já existe. No 3º lance, o que vem na rede é a Tainá e **uma sandália de criança**.
- **Fim da visita 2 (primeiro medo real):**
  - na Sala Medieval, o diploma sai com o nome **"TITO"** já escrito;
  - as luzes apagam por 2 segundos;
  - quando voltam, um dos tronos tem um **balde vermelho**.

### 3.3 Visita 3: "Fechado para reforma" (salas 45–66)

- **Clima e ferramentas:** noite. O jogador ganha a **lanterna** (`tem_lanterna`) na calçada, entregue pelo Quico: "Tá escuro, guri! PIII!". O Quico some depois disso. Toca jingle_2.
- **Cartazes de "PROCURA-SE":** foto desenhada de Tito, "Desaparecido desde 12/03/1967". Ficam colados por cima dos painéis.
- **Disco 1975:** na Torre A.
  - Mostra o Castelinho pronto e a sala de veraneio mobiliada.
  - Na parede de uma das salas: **marcas de altura a lápis**, "TITO 6 anos", "TITO 7", "TITO 8", "TITO 9"… e depois nada.
  - Em 2020 a parede está rebocada, e só o Visor mostra as marcas.
- **Os olhos do pinguim** seguem o jogador. **A armadura** está no trono.
- **Porta para 1950 (o Ato II que já existe, salas 55–60):**
  - a porta do hall abre para as **dunas de 1950**, com o núcleo sozinho;
  - a **Figura Branca** está na duna;
  - perseguição na casa de 1950 e na **arcada repetida**;
  - no fim da arcada, a porta devolve o jogador ao Castelinho, na sala 61.
  - O nível `ato2` é reaproveitado com a numeração nova.
- **A atenção do Visor passa a existir** (§4.3).
- **Fim:** a porta de saída tem **fitas zebradas** e uma placa "EM REFORMA". Ao segurar o Visor (disco 1975), a porta aparece aberta. Atravessar leva à calçada da **VISITA 4**, sem placa de "Volte sempre".

### 3.4 Visita 4: "Ninguém mais visita" (salas 67–80)

- **Clima:** madrugada, chuva, vento forte. O jogo fica quase sem música, só vento e goteiras.
- **Painéis:** só mostram **desenhos do Tito**, cada vez mais perturbadores (§5). Os textos educativos estão riscados por cima.
- **Bentinho:** a voz dele aparece corrompida, na caixa "???". Ele pede desculpas: "A gente devia ter procurado melhor."
- **Disco 2019:** atrás de um painel solto na Sala dos Povos Originários. Mostra o prédio em ruína: fibrocimento caído, mato. No chão da Sala Medieval, uma **escada que desce**.
- **A porta da fita zebrada (sala 80):** fica no **hall**, onde nunca houve porta. Está aberta, com fitas rasgadas e água escorrendo pelos degraus. **Desce para o PORÃO.**

## 4. O Visor do Tempo 2.0

### 4.1 Discos (inventário)

| Disco | Onde se acha | Época que mostra |
|---|---|---|
| 1950 | Sala 10, visita 1 (entregue pelo Bentinho) | O núcleo na areia |
| **1967** | Acervo, visita 2 | **NOVA época**: o Castelinho em obra, com Tito vivo |
| 1975 | Topo da Torre A, visita 3 | Casa de veraneio completa |
| 2019 | Sala dos Povos, visita 4 | Ruína |
| **Sem data** | Porão, sala 95 | O último dia do Tito (§6.3) |

- **Troca de disco:** teclas **1–5** ou rolagem do mouse. Uma faixa no HUD, estilo Flash, mostra os discos que o jogador tem e o selecionado.
- **Segurar Q** mostra a época do disco selecionado. A lógica de `Epocas` continua igual; a época **E1967** é nova.
- A época E1967 no Castelinho tem:
  - corpo principal e arcada levantados;
  - Torre A pela metade (até ~4 m), com andaime de madeira;
  - Torre B só nas fundações;
  - pilhas de blocos de pedra;
  - um barco de madeira encalhado no terreno;
  - areia e poucas casas em volta.
- **Fidelidade:** os dados históricos dizem que a obra foi de 1950 a 1975 e que as torres vieram depois. O estado em 1967 é estimado e marcado como licença no LEIAME.

### 4.2 O que o Visor revela

- **Pistas que só existem em outra época:**
  - as marcas de altura (1975);
  - o desenho atrás do painel (2019);
  - o buraco no muro por onde Tito entrava na obra (1967).
- **Caminhos:**
  - portas que existiam em outra época (já existe);
  - na visita 4, a escada do porão só aparece no 2019;
  - no porão, as passagens mudam conforme o disco.
- **Tito no slide:**
  - no 1967 ele brinca;
  - nas visitas seguintes ele aparece **em lugares do presente**, só dentro do Visor: no canto de uma sala, na escada, sempre um pouco mais perto.

### 4.3 Atenção: "do outro lado, algo percebe você" (visita 3 em diante)

- **O medidor:** enquanto o jogador segura Q, enche um medidor de **atenção**. Ele aparece no HUD como um olho que vai se abrindo e não tem número.
- **O que acontece conforme enche:** a Figura Branca aparece **dentro do slide**, cada vez mais perto da lente.
- **No máximo:** ela "atravessa" o visor. Vem o pulso forte, o susto e o Visor arranca da mão por 10 s. Na visita 4 e no porão, ela atravessa de verdade e persegue o jogador.
- **Ritmo:** soltar Q esvazia a atenção devagar. O tempo até encher fica em ~6 s na visita 3, ~4 s na visita 4 e ~3 s no porão.
- **O dilema:** as pistas pedem olhar, e olhar chama a Figura.

## 5. Os desenhos do Tito (texturas geradas por código, estilo giz de cera)

Ordem de aparição. Todos são assinados "TITO" com o "T" ao contrário:

1. Castelo com sol e boneco palito (visita 1, sala 11).
2. Ele e a mãe na praia (visita 2).
3. O castelo com uma **mulher branca** na janela da torre (visita 2, fim).
4. Ele embaixo do castelo, e o castelo em cima dele, todo em pedra (visita 3).
5. Muita água azul, e ele pequeno no meio (visita 4).
6. Página toda pintada de preto, com dois olhos (visita 4).
7. Um desenho do **jogador**, de costas, com o visor na mão (porão).

## 6. O porão (salas 81–100)

### 6.1 Espaço

- **O lugar:** masmorra "fora da planta" embaixo do Castelinho, com a **mesma pedra** avermelhada, mais escura e úmida, abóbadas e arcos abatidos. O jogo diz com todas as letras que o porão é impossível: "Imbé é areia. Não existe porão aqui."
- **Salas embaralhadas**, à moda do Spooky's: de ~12 tipos de sala pré-fabricada, sorteiam-se 20, com semente fixa por save. Cada sala tem entrada e saída.
- **Tipos de sala:**
  - corredor de abóbada;
  - sala de colunas;
  - cisterna;
  - escada que desce;
  - sala dos desenhos;
  - quarto de criança dos anos 60 (impossível);
  - sala de pedras empilhadas;
  - corredor alagado;
  - galeria de arcos (como a arcada);
  - sala do telefone (o telefone do acervo, tocando);
  - poço;
  - "o quarto do Tito".
- **A água sobe** a cada 5 salas: no tornozelo, no joelho, na cintura. Andar fica mais lento, e há som de água.

### 6.2 Ameaças (cada uma com uma regra)

- **Figura Branca:** a regra já existe (avança quando não é olhada) e agora também vem pelo Visor (§4.3).
- **Costela-de-Adão** (a planta que dá nome à cidade): cipós que crescem enquanto o jogador **fica parado**; se ficar parado demais, prendem e matam. É uma criatura nova, simples, do PLANO §6.
- **A voz do Tito:** chama "ei... aqui...". Em algumas salas, seguir a voz leva ao caminho certo; em outras, à água funda e à morte. O Visor (disco sem data, ou o 1967) mostra qual é qual.

### 6.3 Final (salas 95–100)

- **Sala 95, "o quarto do Tito":**
  - o quarto de veraneio de 1967, intacto e seco, no meio da masmorra alagada;
  - o balde vermelho e os desenhos;
  - na cama, o **disco sem data**.
- **Salas 96–99:** com o disco sem data, o Visor mostra **o último dia**. Slides em sequência, um por sala, conforme o jogador avança:
  1. Tito sai de casa ao entardecer com o balde;
  2. Tito na margem do Braço Morto;
  3. a Figura Branca do outro lado da água, de braços abertos;
  4. a água parada, sem ninguém, e o balde boiando.
- **Sala 100:** o jogador sai do porão por uma escada e chega à **margem do Braço Morto**, de noite. Aparência real de hoje: lago de ~200 m, calçadão, pontilhões pintados, bancos, postes, pedalinhos parados. Ali há uma **lápide de areia** feita por criança. O Visor mostra, pela última vez, Tito sentado na margem, de costas, que olha para o jogador e diz: *"Você veio me procurar."*
- **Créditos e depois a tela de dedicatória** (§1).

**Finais** (contagem invisível; detalhar depois):
- **"Visita concluída":** padrão.
- **"Encontrado":** o jogador viu todas as pistas do Tito com o Visor. Na última cena, Tito sorri e some.

## 7. Divisão do trabalho

| Agente | O quê |
|---|---|
| **Castelinho e visitas** | `GameState.visita`, deslocamento de salas, o loop de visitas, iluminação e clima por visita, estado de cada sala por visita, época E1967 (obra), cartazes, marcas de altura, tela "Volte sempre", lanterna, chuva |
| **Visor 2.0, UI e conteúdo** | discos e inventário, atenção e Figura no slide, HUD "VISITA n · SALA nn", textos `_v2`/`_v3`/`_v4` dos painéis, desenhos do Tito (gerados), cartaz PROCURA-SE (gerado), voz do telefone (texto + chiado), tela de dedicatória, sons novos |
| **Porão e final** | gerador de salas do porão, água subindo, Costela-de-Adão, voz do Tito, quarto do Tito, sequência do último dia, cena do Braço Morto, integração do `ato2` como trecho da visita 3 |
| **Integrador (Opus)** | contratos, `game_state.gd`, `main.gd`, testes de ponta a ponta, revisão de conteúdo e ética, publicação |

## 8. Contratos técnicos da V2 (para os agentes)

### 8.1 GameState (já implementado)

- **Épocas:**
  - `Epoca.E1967` e `Epoca.ESEMDATA` são novas e ficam **no fim** do enum (0..3 continuam iguais);
  - `NOMES_EPOCA` traz os rótulos.
- **Visitas:**
  - `visita` (1..4, 5 = porão), `comecar_visita(n)`, sinal `visita_mudou`;
  - `DESLOCAMENTO_VISITA = {1:0, 2:22, 3:44, 4:66}`, `PRIMEIRA_SALA_PORAO = 81`;
  - `sala_global(base)`, `entrar_sala_base(base)` (para os gatilhos do Castelinho) e `visita_da_sala(n)`.
- **Discos do Visor:** `discos: Array[int]` (épocas), `disco_atual`, `ganhar_disco(epoca)`, `selecionar_disco(epoca)`, sinal `discos_mudou`.
- **Atenção:** `atencao` (0..1), `definir_atencao(v)`, sinal `atencao_mudou`. Quem escreve é o Visor; HUD e níveis só leem.
- **Corrupção:** nova curva `corruption_por_sala` (§2). A visita 1 inteira fica em 0.
- **Save:** grava `visita`, `discos` e `disco_atual`.
- **Checkpoints e "Continuar"** (`entrar_sala` com regra automática, `preparar_continuar`): ficam a cargo do **agente Visitas**, que pode reescrever essas duas funções em `game_state.gd` (e só elas). Elas precisam cobrir as visitas 1–4, o trecho do Ato II na visita 3, o porão e o Braço Morto.

### 8.2 Transições entre cenas

| De | Para | Quem chama |
|---|---|---|
| Fim de cada visita (porta de saída) | `GameState.comecar_visita(n+1)`, depois `VolteSempre.mostrar()` (só nas visitas 1→2 e 2→3), depois `Transicao.ir_para("res://world/niveis/castelinho.tscn", "Spawn")` | Visitas |
| Visita 2, mural da Sala do Pescador (base 14 = sala 36) | `res://world/niveis/barra.tscn` "Spawn". Volta ao Castelinho em "Spawn_volta_barra" (base 15 = sala 37) | Visitas (ida) / Porão (Barra) |
| Visita 3, base 11 (Salão de Arte, sala 55): a porta abre para 1950 | `res://world/niveis/ato2.tscn` "Spawn": salas 55–60 nas dunas, na casa de 1950 e na arcada. Volta ao Castelinho em "Spawn_volta_ato2" (topo da Torre A, base 17 = sala 61) | Visitas / Porão (ato2) |
| Visita 4, porta zebrada no hall (sala 80) | `res://world/niveis/porao.tscn` "Spawn" (salas 81–99) | Visitas |
| Porão, sala 100 | `res://world/niveis/braco_morto.tscn` "Spawn": cena final, depois `Dedicatoria.mostrar()` (créditos + Disque 100), depois o título | Porão / UI |

**Contador nas cenas fora do Castelinho:** Barra, Ato II e porão usam **números globais**, por exemplo `GameState.entrar_sala(55)`. Nada de 14/15/26..30 fixos: use `GameState.sala_global(14)` na Barra.

### 8.3 Arquivos de cada agente (não editar o dos outros; pedidos em `docs/PENDENCIAS.md`)

| Agente | Arquivos |
|---|---|
| **Visitas (Castelinho)** | `castelinho/**`, `world/niveis/castelinho.*`, `assets/textures/**`, `tools/gerar_texturas.py`, `tests/castelinho_test.gd`, `tests/qa_logica_test.gd`, `tests/janela_jogador.gd`, e as funções `entrar_sala`/`preparar_continuar` do `game_state.gd` |
| **Visor 2.0, UI e conteúdo** | `world/visor.gd`, `autoload/efeitos.gd`, `autoload/guia.gd`, `autoload/audio.gd`, `ui/**`, `world/painel_3d.gd`, `data/**`, `assets/ui/**`, `assets/audio/**`, `tools/gerar_audio.py`, `tools/gerar_mascotes.py`, `tools/gerar_desenhos.py` (novo), `tests/ui_test.gd`, `tests/visor_test.gd` (novo) |
| **Porão e final** | `world/niveis/porao.*`, `world/niveis/braco_morto.*`, `world/niveis/ato2*`, `world/niveis/barra.*`, `creatures/**`, `shaders/**` (exceto `pos_processamento`, que é do Visor/UI), `tests/ato2_test.gd`, `tests/barra_test.gd`, `tests/porao_test.gd` (novo) |
| **Integrador** | `scenes/main/**`, `player/**`, `project.godot`, `export_presets.cfg`, `.github/**`, `tools/testar*.{sh,py}`, `docs/*.md` (exceto PENDENCIAS/BUGS) |

### 8.4 Nomes que cruzam fronteiras

- **Painéis por visita:** `Painel3D.new("p05_v2")`. Se a variante não existir no JSON, cai para `"p05"` (o Visor/UI implementa o fallback). Desenhos: `"desenho_1"` … `"desenho_7"` (V2 §5). Cartaz: `"procura_se"`.
- **Texturas geradas pelo Visor/UI:** `assets/ui/tito/desenho_1.png` … `desenho_7.png`, `procura_se.png` e `marcas_altura.png` (usadas pelo Visitas e pelo Porão).
- **UI:**
  - `VolteSempre.mostrar()` (await `.terminou`);
  - `Dedicatoria.mostrar()` (await `.terminou`);
  - `Telefone.tocar(linhas)`: a voz chiada da mãe, como caixa "???" com chiado.
- **Sons novos:**
  - `"chuva"` e `"goteira"` (loops de ambiente);
  - `"agua_sobe"`, `"crianca_ei"` (sussurro "ei..." sintetizado, ou só ruído com texto na tela), `"telefone_voz"`;
  - `"atencao"` (batimento que acelera).
- **Visor:**
  - `Visor.instalar(nivel)` continua;
  - novo: o nível pode registrar **revelações**, nós que só aparecem com um disco específico, com `Epocas.marcar(no, [GameState.Epoca.E1967])`, igual às épocas;
  - a **Figura no slide** (atenção) é responsabilidade do Visor.
