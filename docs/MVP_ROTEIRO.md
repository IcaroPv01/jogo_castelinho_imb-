# MVP: roteiro das salas 1 a 30 e contratos técnicos

> Documento de trabalho para quem constrói o MVP (humanos e agentes). A fonte da verdade criativa é `docs/PLANO.md`; os fatos históricos estão em `docs/pesquisa/`. **Nada aqui pode contradizer as regras de ética do PLANO §3** (nenhuma pessoa real como vilã, prefeitura fictícia "Programa Municipal de Memória Interativa", sem crimes reais, sem enchente de 2024 como terror).

## 1. Fluxo do MVP

```
Tela de título (Flash) → nível CASTELINHO (salas 1–25, 2020 + visor)
                          └─ sala 14: flashback BARRA (cena separada) → volta à sala 15
                       → nível ATO2 (salas 26–30, espaços impossíveis + Figura Branca)
                       → tela "Fim da demonstração" (estatísticas, selos) → título
```

Cenas:

| Cena | Caminho | Responsável |
|---|---|---|
| Título | `res://ui/tela_titulo.tscn` (emite `comecar(continuar: bool)`) | Agente UI |
| Castelinho | `res://world/niveis/castelinho.tscn` | Agente Castelinho |
| Flashback da Barra | `res://world/niveis/barra.tscn` | Agente Efeitos |
| Ato II | `res://world/niveis/ato2.tscn` | Agente Efeitos |
| Fim da demo | `res://ui/fim_demo.tscn` (chamada por `Transicao`/nível) | Agente UI |

## 2. Roteiro sala por sala

Legenda: **P**xx = painel (texto em `data/paineis.json`), **Q** = quiz, **★** = selo, **⚑** = checkpoint (marcador `Checkpoint_N` no nível).

### Exterior — 2020+ (corruption 0)

| Sala | Local real | O que acontece |
|---|---|---|
| 1 ⚑ | Calçada da Av. Garibaldi, frente do lote | Bentinho aparece (balão): "Oi! Eu sou o Bentinho! Bem-vindo à Visita Guiada do Castelinho!". **P01** "Bem-vindo ao Castelinho!" (Casa de Cultura e Museu desde 23/12/2020). Um recorte de papelão de visitante sorridente está **virado para a parede** (ninguém comenta). |
| 2 | Gramado frontal, mesa/churrasqueira de pedra | **Tainá** se apresenta ("Eu sou a Tainá, a tainha! Vou fazer umas perguntinhas!"). **P02** "De onde vem o nome Imbé?" (cipó-imbé/costela-de-Adão) + **Q** ★. Uma folha de costela-de-Adão real está brotando no canto do painel. |
| 3 | Lateral da torre grande, hortênsias | **P03** "Um castelo feito à mão": pedra trazida de barco pelo Rio Tramandaí, obra de décadas (1950–1975). Placa: "Construtor: ______". |
| 4 | Deck de madeira com pérgola | **Quico** se apresenta ("Eu sou o Quico! Fiscal da visita! Não sai do caminho, hein! PIII!"). Explica os selos. **P04** Garibaldi e o lanchão Seival (1839). Marcas de arrasto no chão do deck. |
| 5 | Arcada (4 arcos) | **P05** "A cidade-jardim de 1939" (Ubatuba de Faria). Texto diz que os pescadores "foram **acomodados**". **Q** ★. |
| 6 ⚑ | Porta de entrada | **P06** "Imbé ganha autonomia" (Lei 8.600 de 09/05/1988; instalação 01/01/1989). Confete e fanfarra. Porta abre. |

### Interior — 2020+ (corruption 0 → 0.25 até a sala 25)

| Sala | Local | O que acontece |
|---|---|---|
| 7 | Hall/galeria (piso de pedra irregular, porta dupla em arco, vigas, lustre de ferro) | **P07** "O museu" (salas temáticas, visitas guiadas). |
| 8 | Sala dos Povos Originários | **P08** sambaquis — texto diz que eram "**moradias**" (meia-verdade). Vitrine com conchas. **Q** ★. |
| 9 | Sala de Meio Ambiente | **P09** "Nossa costa" (baleias, pinguins, "muitos navios visitaram nossa costa!"). Pinguim empalhado — **os olhos dele seguem o jogador** (sutil). |
| 10 | Corredor da Secretaria | Bentinho entrega o **Visor do Tempo** (`GameState.set_flag("tem_visor")`). Tutorial: "Segure **Q** para ver como era em 1950!". Ao segurar: a sala vira **areia e vento** (o núcleo de 1950 não chegava até aqui). **P10** "O Castelinho através do tempo". |
| 11 | Salão de Arte | **P11** "A ponte Giuseppe Garibaldi". **Primeiro glitch**: a voz/balão do Bentinho engasga e repete uma frase. |
| 12 | Acervo de antiguidades (telefone antigo, máquina de escrever, discos) | O **telefone toca**. Atender: voz chiada: "Alô? ...A temporada acabou?" (desliga). **P12** "Veraneio: de 16 mil para 80 mil pessoas". |
| 13 | Sala do Pescador (mural do barco ao pôr do sol, fauna artesanal, letreiro "Castelinho Imbé/RS" em letra gótica) | **P13** "A pesca com os botos" (Patrimônio Cultural do Brasil, 11/03/2026). O boto do painel tem a **nadadeira cortada**. Tainá faz piada ("Ainda bem que eu não sou pescada... né?"). |
| 14 | Sala do Pescador — **mural** | Interagir com o mural → **FLASHBACK DA BARRA** (`Transicao.ir_para("res://world/niveis/barra.tscn")`). O contador mostra "SALA 14" com tremidas. |
| 15 | Sala do Pescador (volta, `Spawn_volta_barra`) | Sala um pouco errada (corruption ~0.1). **Recorte de papelão de pescador cai da porta** (susto-piada nº 1; Bentinho ri "Hahaha! Te peguei!"). |
| 16 ⚑ | Escada da torre grande | Subida. Quico apita se o jogador correr. |
| 17 | Topo da torre grande (ameias, vista da cidade) | **P17** "As torres vieram depois" (o núcleo original não tinha torres). Segurando Q: em 1950 **a torre não existe** — o jogador vê o chão lá embaixo, flutuando. |
| 18 | Terraço ameado sobre a arcada | Caminhar sobre o terraço entre as ameias. **P18** "Imbé hoje" (26.824 habitantes em 2022, ~80 mil no verão). |
| 19 | Torreta | Quarto pequeno. Um **segundo recorte** (Quico de papelão) aparece de repente atrás do jogador. |
| 20 | Descida para a Sala Medieval | **P20** "A Feira Medieval" (evento real no Castelinho). |
| 21 | Sala Medieval (dois tronos, escudos, lanças, tochas) | Um dos tronos está **ocupado por uma armadura** que não estava lá antes (só aparece quando o jogador olha de novo). |
| 22 | Sala Medieval — fundo | **Quiz final do Ato I** (3 perguntas) → **Diploma**: "Parabéns! Você concluiu a Visita Guiada!" (falso final, estilo Spooky's). |
| 23 | Porta de saída | Saída "em reforma" (fita zebrada). Bentinho: "Ops! A saída está em reforma! Mas o Visor mostra outro caminho...". Segurando Q (o Visor agora mostra **1975**), há uma porta aberta. |
| 24 | Casa de veraneio de 1975 (mesmo cômodo, mobiliado, luz de fim de tarde) | Os painéis voltam **reescritos**: **P24** "Os pescadores foram **removidos**" (fato real, sem verniz). |
| 25 ⚑ | Corredor de 1975, **mais longo do que a casa poderia ter** | **P25** "Sambaquis também eram **cemitérios**". Fim do Ato I. Porta no fim → `Transicao.ir_para("res://world/niveis/ato2.tscn")`. |

### Ato II — "Informações Atualizadas" (corruption 0.3 → 0.6)

| Sala | Local | O que acontece |
|---|---|---|
| 26 ⚑ | O hall da sala 7 de novo, mas errado (painel P07 com texto corrompido, lustre balançando) | A guia: "Desculpe! Dados desatualizados! Estamos atualizando...". |
| 27 | Porta do hall abre para **1950**: o núcleo original **sozinho nas dunas**, sem cidade, vento forte, céu cinza | Longe, numa duna, uma **figura branca** parada. Some quando o jogador se aproxima olhando. |
| 28 | Dentro do núcleo de 1950 (casa de pedra de dois volumes, chaminé, janela gradeada no alto) | **A Figura Branca** (regra: avança quando o jogador **não está olhando** para ela; some se o jogador se aproxima **olhando** — "cercar"). Primeira morte possível. |
| 29 | **Arcada repetida**: corredor de arcos abatidos que se repete ~8 vezes | Perseguição: a Figura Branca vem atrás. O jogador precisa olhar para trás periodicamente para pará-la e avançar até a porta. |
| 30 | Porta da Sala Medieval (fora de lugar) | Ao abrir: tela preta, voz do Bentinho corrompida: "Obrigado pela visita... A visita continua...". → `ui/fim_demo.tscn`: "FIM DA DEMONSTRAÇÃO — Sala 30/100", selos, painéis lidos, mortes. |

### Flashback da Barra (dentro da sala 14)

- **Cena:** foz do Rio Tramandaí, entardecer, molhes de pedra, areia, água (plano com shader simples), pescadores genéricos (silhuetas low-poly) com tarrafas em linha na margem, ponte ao longe.
- **Minigame da tarrafa:**
  - Tainá explica: "Quando o boto **bater a cabeça** na água, joga a tarrafa (clique/E)!".
  - O jogador lança 3 vezes. Nas 2 primeiras o boto sinaliza certo, o lance pega tainhas e a Tainá comemora, meio sem graça.
  - Na **3ª** o boto sinaliza, o jogador lança... e a rede puxa **o jogador**: tela escurece, som de água, a voz da Tainá ("...era eu na rede?").
  - Volta ao Castelinho, `Spawn_volta_barra`, sala 15.
- **Fidelidade:** a barra real tem molhes de pedra, calçadão e a ponte com três pistas ao fundo. É simplificado, não detalhado.

## 3. Contratos técnicos (APIs que já existem — não mudar a assinatura)

| Sistema | API |
|---|---|
| `GameState` (autoload) | `entrar_sala(n)`, `sala_atual`, `corruption`, `definir_corruption_manual(v)` (−1 volta à curva), `epoca`, `trocar_epoca(e)`, `Epoca.E1950/E1975/E2019/E2020`, `set_flag(nome, v)`, `flag(nome)`, `somar(contador)`, `ganhar_selo(id)`, `matar_jogador(causa)`, sinais `sala_mudou`, `corruption_mudou`, `epoca_mudou`, `jogador_morreu`. Flags usadas: `tem_visor`, `tem_lanterna`, `epoca_visor` (int: época que o Visor mostra; padrão E1950), `visor_travado` (bool: o Visor não deixa voltar). |
| `Transicao` | `await ir_para(cena, spawn)`, `fade_out(dur, cor)`, `fade_in(dur)` |
| `Guia` | `await falar(personagem, linhas: Array, bloquear := false)`, `ocupado()`. Personagens: `bentinho`, `taina`, `quico`, `sistema`, `???`. |
| `Audio` | `sfx(nome)`, `sfx_3d(nome, pos)`, `musica(nome)`, `passo()` |
| `Efeitos` | `pulso(intensidade, dur)`, `visor(ativo)` |
| `Epocas` (classe) | `Epocas.marcar(no, [épocas])` |
| `Painel3D` (classe) | `Painel3D.new("p01")`, sinal `lido(id)` |
| `SalaTrigger` | `SalaTrigger.new(numero, tamanho)` (Area3D; base no chão) |
| `Interagivel` | `Interagivel.new(texto, tamanho, callback(player))`, sinal `usado` |
| `Construtor` | `caixa(pai, tam, pos, mat, colisao)`, `material(cor, rug, textura, escala_uv)`, `rotulo(...)`, `luz(...)` |
| `Player` | `pode_mover`, `olhar_para(ponto)`, `direcao_olhar()`, `camera`, `cabeca` |
| Nível | Node3D com `Marker3D` `Spawn`, `Checkpoint_N`, opcional `func iniciar(player)`, `func ao_morrer()` |

**Camadas de colisão:**
- 1 = mundo;
- 2 = jogador;
- 3 (valor 4) = interagíveis;
- 4 (valor 8) = criaturas.

**Visor do Tempo:** **segurar Q** mostra a época `GameState.flag("epoca_visor", E1950)`. Soltar Q volta para E2020, a não ser que `visor_travado` esteja ligado. O jogador pode andar segurando Q: é assim que atravessa portas que só existem em outra época.

**Corrupção:** `GameState.corruption` controla o pós-processamento (Efeitos), a música (Audio) e a interface (Guia/painéis): troca de fonte, letras erradas, menos saturação.

## 4. Divisão de trabalho (arquivos de cada agente — não editar arquivos de outro)

| Agente | Arquivos |
|---|---|
| **UI e conteúdo** | `autoload/guia.gd`, `autoload/audio.gd`, `ui/**` (exceto `hud.gd`, só ajustes visuais permitidos), `world/painel_3d.gd`, `data/paineis.json`, `assets/ui/**`, `assets/fonts/**`, `assets/audio/**`, `tools/gerar_audio.py` |
| **Efeitos e Ato II** | `autoload/efeitos.gd`, `shaders/**`, `world/visor.gd`, `creatures/**`, `world/niveis/ato2.*`, `world/niveis/barra.*` |
| **Castelinho** | `castelinho/**`, `world/niveis/castelinho.*`, `assets/textures/**`, `tools/gerar_texturas.py` |
| **Integrador (Opus)** | `autoload/game_state.gd`, `scenes/main/**`, `player/**`, `world/*.gd` base, `project.godot`, `tests/**`, `docs/**` |

Precisa mudar um arquivo de outro agente? Escreva o pedido em `docs/PENDENCIAS.md`.
