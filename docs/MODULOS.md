# Módulos de trabalho

Cada módulo é **uma sessão do Claude Code**: Opus 5.5 orquestra, Sonnet 5.5 e Haiku 5.5 executam (ver `CLAUDE.md`).
Decisões do Icaro (07/10/2026):

- **Um módulo de cada vez.** Só começa o próximo quando o anterior fez o merge na `main`.
- **Cada sessão faz o merge do próprio PR**, com CI verde e testes locais passando.
- A ordem da fila é do Icaro: ele pode trocar a qualquer momento, de preferência depois de jogar.

## Fila

| # | Módulo | Objetivo | Arquivos principais | Situação |
|---|---|---|---|---|
| 0 | Fundação | `CLAUDE.md`, este mapa, instalador do Godot | `CLAUDE.md`, `docs/MODULOS.md`, `tools/instalar_godot.sh` | feito |
| 1 | QA e bugs | Varredura das 100 salas, corrigir o que o Icaro e os testes acharem | `tests/`, `docs/BUGS.md` (correções pontuais em qualquer arquivo) | rodada 2 (playtest do Bernardo, PR #23): rede de segurança, Destravar, borda das dunas, corredor de 1975 (B37–B40); reabre quando alguém jogar |
| 2 | Visor do Tempo | Acertar a mecânica do Q e dos discos conforme o retorno de quem jogou | `world/visor.gd`, `world/epocas.gd`, `ui/faixa_discos.gd`, `ui/olho_atencao.gd` | feito: caças dos 5 discos (1950 PR #10; 1967, 1975, 2019 e sem data PR desta parte 2); reabre quando o Icaro jogar |
| 3 | Visitas 1 a 4 | Ritmo ("mais lento até ficar bizarro"), sustos, painéis, flashback da Barra | `world/niveis/castelinho.gd`, `ato2.gd`, `barra.gd`, `data/paineis.json` | feito (PR #11): ritmo, quiz V2–V4, bugs, fontes; reabre quando o Icaro jogar |
| 4 | Porão | A masmorra (salas 81 a 99) | `world/niveis/porao*.gd`, `shaders/porao_*` | feito (PR #12): sequência fixa, masmorra, Figura nova, sustos (porão e V3/V4), bugs; reabre quando o Icaro jogar |
| 5 | Braço Morto e final | Sala 100, Tito, finais, dedicatória | `world/niveis/braco_morto.gd`, `castelinho/tito.gd`, `ui/dedicatoria.gd`, `ui/volte_sempre.gd`, `ui/telefone.gd` | feito (PR #14): três finais (Encontrado ≥8 pistas, Visita concluída, Sala 101), menu do Esc, contador de pistas, título muda após zerar; reabre quando o Icaro jogar |
| 6 | Áudio | Jingle, ambientes e sustos (ninguém ouviu ainda: precisa do ouvido do Icaro) | `autoload/audio.gd`, `tools/gerar_audio.py`, `assets/audio/` | feito (PR #15): 9 sons novos, mixagem medida, Sala 101 abafada na web, jingle_1 mais estranho; reabre quando o Icaro ouvir (Mesa de som) |
| 7 | Arte e gráficos | Acabamento visual mantendo o estilo Flash educativo | `shaders/`, `tools/gerar_texturas.py`, `castelinho/` | feito (PR #16): capturas das cenas só testadas, revisão gráfica (Opus), Figura nova no slide 98, mão/dedos de afogada, pegadas com forma de pé, lago e chegada; reabre quando o Icaro jogar |
| 8 | Celular | Jogar no navegador do celular (Android/iPhone), deitado, pelo mesmo link; computador igual | `ui/celular.gd`, `ui/controles_toque.gd`, `ui/aviso_retrato.gd`, `export_presets.cfg` (head_include) | feito (PR #17): toque, pausa sem pointer lock, retrato, modo leve, som no 1º toque; reabre quando o Icaro testar no celular |
| 9 | Modo debug e Figura no Q | Q possível e tenso (sem perseguição cedo); painel de debug para testar sem morrer | `world/visor.gd`, `world/rastro.gd`, `creatures/figura_branca.gd`, `ui/debug.gd`, `ui/painel_debug.gd` | feito (PR #19): Figura do slide no mundo, perseguição "tipo Granny", olho mais lento, modo debug `?debug=1`; reabre quando o Icaro testar o Q |
| 10 | Galeria 3D e colocação dos objetos | Varredura automática de colocação (flutuando, enfiado, fora da sala, z-fighting, frestas, continuidade); galeria `/galeria/` com fotos e glTF; design no Canva para comentários | `tests/varredura/colocacao*.gd`, `tests/colocacao_test.gd`, `castelinho/malha.gd` (registro), `castelinho/registro.gd`, `tools/galeria/`, `galeria/` | feito (PR #20): achados reais zerados (correções B26–B36 ou exceções com motivo), 166 objetos na galeria, dúvidas no Canva; reabre quando o Icaro comentar |
| 11 | Q liga/desliga, pulo e relatório | Pedidos do playtest do Bernardo (14/10): Q como o Correr, pulo baixo, botão de enviar relatório | `world/visor.gd`, `player/player.gd`, `ui/controles_toque.gd`, `ui/relatorio.gd`, `ui/menu_pausa.gd` | feito (PR #22): Q/Visor liga e desliga com um toque, Espaço/botão Pular (pulo baixo), "Enviar relatório" na pausa; reabre quando o Icaro testar |
| 12 | Épocas, caminho e história | Playtest do Bernardo, fase B2: épocas distintas, caminho claro, história fora dos painéis, sustos no caminho, ideias da água | `castelinho/ruina2019.gd`, `castelinho/tito.gd`, `autoload/efeitos.gd`, `ui/mapa.gd`, `world/objetivo.gd`, `ui/jornal.gd`, `world/flash_agua.gd`, `world/goteiras.gd`, `world/agua_ferrugem.gd`, `world/niveis/sustos_caminho.gd` | feito (PR a seguir): 2019 interditado, Tito fantasma depois de 1967, legenda das épocas, Mapa da Visita (M), jornal de 1967, lampejos de água, goteiras, água ferrugem, 3 sustos no caminho; reabre quando o Icaro jogar |
| 13 | Pedalinho, final secreto e fundo da Sala 101 | Playtest do Bernardo, fase C: pedalinho no lago, final secreto "salvar o Tito", fundo da Sala 101 mais caprichado | `castelinho/pedalinho.gd`, `world/niveis/braco_salvar.gd`, `world/niveis/fundo_do_lago.gd`, `world/niveis/braco_morto.gd`, `ui/finais.gd`, `ui/tela_titulo.gd` | feito (PR a seguir): pedalinho amarelo no atracadouro, luz no lago com 12 pistas, olhar o Tito de 1967 com o Visor, 4º final "Tito voltou pra casa", fundo da Sala 101 com mais cenário; reabre quando o Icaro jogar |
| 14 | Mais partes da cidade | Playtest do Bernardo, fase D: 5 lugares opcionais da cidade, cada um com tarefa e pistas do Tito | `world/niveis/cidade_base.gd`, `world/niveis/cidade_{casas,barra,ponte,praia,rodoviaria}.gd`, `ui/placa_cidade.gd`, `GameState.CIDADE`, `castelinho/*` (placa 3D) | feito (PR a seguir): Rua das casas, Calçadão da Barra, Ponte à noite, Praia de Imbé e Rodoviária 1967, abertos pela placa da prefeitura na calçada e pelo Mapa (M); +6 pistas (21 no total); reabre quando o Icaro jogar |
| 15 | Falas dos monitores | Pedido do Icaro (16/10): falas somem sozinhas, sem repetir no mesmo lugar, e úteis (ligadas à história e ao objetivo da visita) | `autoload/guia.gd`, `world/niveis/castelinho.gd` (e as falas em `ato2.gd`, `barra.gd`, `porao.gd`) | feito (PR #27 + PR a seguir): avanço automático, sem repetição, bronca da escada 1 vez; falas enxutas, ligadas ao Objetivo e dica quando o jogador trava; reabre quando o Icaro jogar |
| 16 | Minigames | Pedido do Icaro (16/10): mais minigames como o da Tainha (o Icaro aprovou as 5 ideias, todas no caminho, com botão Pular) | `world/niveis/minigame_base.gd`, `mini_lanchao.gd`, `mini_quico.gd`, `mini_lotes.gd`, `castelinho_minigames.gd`, `tests/mini_*_test.gd` | em andamento (PR #28): lanchão Seival (V2), Quico Diz (V1) e lotes de 1939 (V3) feitos; Ponte e caderno do Tito esperam o merge do Módulo 14 |

`autoload/game_state.gd` e `scenes/main/main.gd` são de todos: mude só o necessário e descreva a mudança no PR.

## Roteiro de cada sessão

1. Ler `CLAUDE.md`, esta página (sobretudo a **Passagem de bastão** abaixo) e os docs do módulo.
2. Começar da `main` mais recente. Preparar o Godot (`bash tools/instalar_godot.sh`) e rodar `bash tools/testar.sh godot`.
3. **Conversar com o Icaro antes de construir:** perguntar o que ele viu ao jogar e mostrar um plano curto do módulo.
4. Delegar aos subagentes (Sonnet para sistemas, Haiku para tarefas leves) e revisar tudo o que voltar.
5. Testes locais verdes (headless e, se mexer em tela ou shader, `testar_janela.sh` e `testar_web_cenas.sh`).
6. Atualizar esta página no mesmo PR: a **Situação** do módulo e uma entrada na **Passagem de bastão**.
7. PR rascunho para a `main` → CI verde → marcar como pronto → **merge pela própria sessão**.
8. Conferir que o site publicado abre e avisar o Icaro com o link e o que testar.

## Texto para abrir a sessão de um módulo

Cole numa sessão nova do Claude Code (no repositório `IcaroPv01/jogo_castelinho_imb-`, modelo Opus 5.5), trocando o número:

> Você é a sessão do **módulo N** do jogo Castelinho. Leia `CLAUDE.md` e `docs/MODULOS.md` (incluindo a Passagem de
> bastão) antes de tudo. Siga o roteiro de cada sessão: converse comigo antes de construir, orquestre subagentes
> Sonnet e Haiku, revise tudo, faça o merge do seu PR com CI verde e atualize a página de módulos.

## Passagem de bastão

O que cada sessão deixou para a próxima. A mais recente fica em cima.

### Módulo 16: minigames (16/10/2026)

- **Pedido:** "mais minigames, tipo o da Tainha". Receita da Tainha (`barra.gd`): uma ação só (clique/E/Interagir), sinal visual claro, 3 a 8 rodadas
  curtas, mascote comentando e uma virada estranha. O Icaro aprovou as 5 ideias, "todas no caminho, igual à Tainha".
- **Base** `world/niveis/minigame_base.gd` (`MiniGameBase`): cena própria, câmera parada, HUD (placar, dica, botão **Pular**; no PC
  Backspace). Filha: `_init` com `super()` + `id`/`quem_fala`/`fala_fim`, `_montar()` (cenário), `_rodar() -> bool` (todo `await` passa por
  `falar()`/`esperar()`/`esperar_acao()`; `false` = pulou, `return false`), `acionar()` (a ação; público para testes).
  Vencer = flag `mini_<id>_feito`, pista `pista_mini_<id>` (+1 em `pistas_tito`) e selo `mini_<id>`. Pular não ganha nada e a porta continua.
  Armadilha achada: `_rodar` da base precisa de um `await` (senão o `await _rodar()` não retoma a coroutine da filha).
- **Portas** `world/niveis/castelinho_minigames.gd` (`MinigamesCastelo`, plugada em `castelinho.gd`: 4 linhas): tabela `ENTRADAS`, um
  Interagivel com "!" amarelo (some ao vencer), aviso do mascote ao entrar na sala (uma vez), frase no Mapa (M) só dentro da sala da porta,
  e `Spawn_volta_mini_<id>` para o retorno. Entrada nova = uma linha da tabela + um `_visual_<id>`.
- **Feitos:** `lanchao` (V2, Sala do Pescador, gravura na parede leste: puxar o Lanchão Seival de 1839 no ritmo dos bois; no fim todos param
  e os bois seguem puxando; uma pegada de criança na lama), `quico` (V1, sala 5, Quico Diz: repetir o ritmo dos apitos; no fim algo responde
  do outro lado do muro e o Quico diz "Não fui eu."), `lotes` (V3, Acervo/sala 12, "Planejar a cidade" de 1939: carimbar 6 lotes; o tom cai,
  os ranchos somem, sobra o carrinho de madeira). Fatos só do que está em `docs/pesquisa/historia_imbe.md`. Todas as portas só existem em 2020.
- **Pendente (Módulo 14):** `ponte` (um, dois, três, pescador; Ponte à noite) e `caderno` (desenhos do Tito; Rua das casas). Esperam o
  merge do Módulo 14. Ao construir, ajustar `PISTAS_SALVAR` (os minigames somam pistas: o Módulo 14 sobe 12 para 16 com total 21; com
  +5 minigames o total vira 26, proposta: 20) e o aviso do contador, se houver.
- **Limitações:** a Tainá "bipa" mesmo nas falas pesadas dos lotes (o `Guia` não tem modo silencioso); áudio só conferido por testes e
  espectrograma; a pegada do lanchão é maior que um pé real, só para ler.
- Pendente: o Icaro jogar as 3 e dizer se o ritmo, a dificuldade e o lugar das portas estão bons.

### Módulo 2, parte 3: Visor justo e caças mais visíveis (16/10/2026)

- **Origem:** playtest do Icaro: coisas escondidas demais; Visor "meio injusto"; quer sustos e perseguição só em certas partes; Visor
  cobrindo quase a tela; medo de verdade (borda vermelha, respiração); um momento preso no Visor.
- **Zonas de perigo** (`world/zonas_perigo.gd`, tabela `SALAS`, números globais): V3 = 57 e 58 (Ato II: núcleo de 1950 e arcada);
  V4 = 74 (corredor), 77 (trecho longo escada/terraço/Pescador), 80 (hall da porta zebrada); porão = todas (como antes). Só ali
  a atenção sobe e a Figura aparece no slide/persegue pelo Visor (`Visor.zona_de_perigo()`); fora, Q livre e atenção só cai.
  Entrar numa zona com Q ligado: batimento baixinho 3 s (`_alerta`). Salas das caças da V4 (73, 75, 78) e a 72 ficam de fora.
  Testes que enchem a atenção precisam pôr `GameState.sala_atual` numa zona (ver `_zerar` em `visor_test`/`figura_q_test`).
- **Medo** (`world/medo.gd`): max(atenção suavizada, proximidade da `FiguraBranca` real ativa a até 16 m). `Efeitos.medo` alimenta o
  uniform `medo` do shader (vinheta vermelha que pulsa, com ou sem Visor) e `Audio.medo(v)` (loop novo `respiracao.wav`, volume
  -30..-3 dB e tom sobem com v; some em 0). Batimento "atencao" intacto. Sons novos: `respiracao`, `ping` (tools/gerar_audio.py).
- **Visor grande** (`shaders/pos_processamento.gdshader`): duas lentes de cantos arredondados quase coladas, ~91% da tela (era ~62%), moldura
  vermelha fina; cada olho vê a tela inteira. O celular não tem máscara própria: só o botão Visor (nada mudou em `celular.gd` além de
  "ligue o Q" -> "toque no botão Visor"). Não conferido: aparência no celular de verdade.
- **Caças mais visíveis:** `world/feixe_caca.gd` (feixe de luz vertical aditivo, 6,5 m fora / 2,7 m dentro, visível até 24 m, só na época do
  item) + brilho 60% maior e sempre aceso, em todos os achados (Passaporte, 1967, 1975 incl. Tito e buraco, 2019, porão).
  `world/caca_proximidade.gd`: a menos de 10 m de achado visível, "ping" que acelera (1,8 s a 0,35 s); em outra época, dica única por item
  ("Algo brilha em outra época: ligue o Q." ou "aperte N para trocar de disco"). Objetivo/mapa M: "Vestígios 1/3: falta nas salas 26 e 30."
  (`Objetivo.salas_caca`, o nível registra; castelo usa `sala_do_ponto` = gatilho mais perto; porão usa `PoraoCacas.salas_faltando`).
- **Preso no Visor** (V4, logo depois de pegar o disco de 2019 na sala 72, uma vez, flag `evt_v4_preso_visor`): `Visor.preso_iniciar(15)`: liga
  sozinho, Q não desliga ("O Visor não desliga!"), tremores, atenção forçada 0,45 a 0,92 (nunca estoura: sem perseguição nem morte), Figura
  no slide; no fim susto rente e solta. Sair do nível zera. Não é salvo.
- **Testes:** novo `tests/visor_justo_test.gd`; ajustes em `visor_test`, `figura_q_test`, `castelinho_test`. Captura: `tests/captura_visor_justo.gd`.
- Pendente: o Icaro jogar e dizer se as zonas e o ping estão bons; sons novos só conferidos por teste, nunca ouvidos.

### Módulo 1, rodada 2: playtest do Bernardo (15/10/2026)

- **Relato:** "fiquei preso numa parede", "buguei no void", "tive que resetar porque tava preso numa fase", "o deserto é giga,
  demora muito pra cair no void".
- **Rede de segurança** (`world/rede_seguranca.gd`, `RedeSeguranca`): um nó por nível, instalado por `main.carregar_mundo`
  (1 linha). Guarda pontos seguros a cada 0,25 s (no chão, fora de parede) e um a cada 2 s do último minuto. Resgata em:
  void (chão mais baixo −6 m), fora dos limites (+3 m), 4 s caindo, 0,6 s dentro de parede (tenta `desprender()` antes).
  Só usa a API pública do Player; supõe o pulo do módulo 11 (~0,37 m). Desligada com `pode_mover = false`, fora do jogo
  ou com `rede_seguranca_ativa() == false` no nível. Limites: `limites_mapa()` do nível (Castelinho: lote, e o corredor
  só em 1975) ou a colisão estática medida a cada 2 s (o porão só cresce). Aviso "(você se perdeu da visita...)".
- **Pausa → Destravar:** `RedeSeguranca.atual.destravar()` volta a um ponto de alguns segundos atrás (preso num canto).
- **Dunas:** paredes invisíveis (x ±50, z +25..−135) e terreno menor.
- **Varredura** `tests/varredura/fuga.gd` (fora do CI; ver LEIA-ME): caminhante aleatório com pulo e troca de época em
  todos os níveis. Achou só o corredor de 1975 (B40). Não reproduziu "preso na parede" nem "trava de fase" em colisão
  estática: devem vir de eventos de script (portas, cenas). Barra e Braço Morto têm chão largo sem parede além da área
  de jogo, mas o jogador não chega lá andando (a rede cobre se chegar).
- **Para áreas novas (módulo 14 em diante):** área andável fora do lote do Castelinho precisa entrar em
  `castelinho.gd` `limites_mapa()` (senão a rede devolve o jogador ao lote); nível novo pode dar o seu `limites_mapa()`
  ou deixar a rede medir a colisão. Cena em que o jogador deve cair/afundar: `pode_mover = false`, física desligada ou
  `rede_seguranca_ativa()` false (ex.: Barra a partir do PUXADO). Fechar bordas com paredes invisíveis, como as dunas.
- Pendente: alguém jogar e dizer se a rede disparou sem motivo (aviso na tela) ou se ainda prendeu; o relatório da
  pausa (módulo 11) ajuda a achar o lugar.
### Módulo 15: falas dos monitores (16/10/2026)

- **Pedido do Icaro:** (1) a fala deve passar sozinha, sem tocar na tela (difícil correndo); (2) falas se repetem em alguns lugares
  (ex.: correndo na escada); (3) as falas parecem jogadas e dá para ignorar.
- **Parte 1 (feita):** `autoload/guia.gd`: toda fala agora avança sozinha, também a que trava o jogador (antes esperava 40 s). Tempo
  parado depois de digitar: `Guia.tempo_leitura(n_letras, bloqueante, tem_fila)` (não travando 1,6 a 5,5 s; travando 3 a 9 s; com outra
  fala esperando na fila, a atual sai ~40% mais depressa, para quem corre pelas salas não acumular balões atrasados). Clique/espaço
  continuam adiantando. Fala idêntica (mesmo personagem e linhas, não travando) que já está na tela, na fila ou terminou há menos de
  `REPETICAO_S` (6 s) é descartada; `cancelar()` zera essa memória. `castelinho.gd`: o Quico da escada (sala 16) xinga **uma vez por
  visita** (`_uma_vez("quico_escada")`) e depois só apita (a cada 10 s, antes 6 s com a frase repetida).
  Teste novo em `tests/ui_test.gd` (avança sozinha sem clique, teto de tempo, repetição descartada).
- **Parte 2 (feita, direção escolhida pelo Icaro: "os três juntos"):**
  - **Papéis fixos:** *Bentinho* = o guia que vai rachando (V1 animado, V2 engasga e "mais verdade", V3 não devia estar ali à noite,
    V4 vira a voz "???" que pede desculpas); *Tainá* = quiz e Barra (pergunta, sabe mais do que diz); *Quico* = fiscal das regras
    (some na V3 depois da lanterna); *sistema* = aviso institucional frio (cresce nas visitas 3 e 4 e no porão); *???* = o Tito / quem
    o procurou (só pistas e sugestão). Regra de escrita: toda fala ou **diz o que fazer agora**, ou **conta um pedaço da história do
    Tito**, ou é um arrepio curto; nunca só enche tempo.
  - **Roteiro enxuto:** as duas falas do Quico na sala 4 viraram uma; Tainá (sala 2) passa a mandar ler o painel antes do quiz; Salão
    de Arte (sala 11) deixa de dizer só "quanta cor" e ensina algo; Tainá (sala 13) manda apertar E no mural; V4 sala 7 liga ao
    fato de os painéis agora serem desenhos do Tito.
  - **Fala que repete o caminho:** as falas de porta/escada/mural travados (`_escada_interditada`, `_descer_porao`, `_usar_porta_saida`,
    `_abrir_porta_final`, `_usar_mural`) terminam com `Objetivo.atual()`, a mesma frase do Mapa da Visita (M); assim o objetivo vive
    num lugar só e mudar o `world/objetivo.gd` muda a fala.
  - **Dica quando trava:** `world/dica_ao_travar.gd` (`DicaAoTravar.instalar(self)` no `iniciar()` do castelinho.gd). Se o objetivo e a
    sala mais distante não mudam por 90 s (livre: sem fala, tela, Figura nem trava), o monitor da visita lembra o objetivo; depois de
    150 s e 210 s, no máximo 3 por objetivo. Voz: V1/V2 Bentinho, V3 sistema ("Lembrete da visita:"), V4 "???" ("Por aqui."). Não fala
    no porão/Braço. Teste: `tests/dica_ao_travar_test.gd`.
  - **Pendente:** o Icaro jogar e dizer se ainda há fala jogada. As falas do porão, da Barra, do Ato II e das caças não foram
    reescritas (já estavam ligadas ao objetivo/história); `ui/telefone.gd` idem.

### Módulo 14: mais partes da cidade (16/10/2026)

- **Origem:** fase D do playtest do Bernardo ("muito lugar pra ir que não tem nada"). O Icaro escolheu **os 5 lugares** da proposta
  (`/mnt/project-files/castelinho/modulo14-cidade-proposta.md`). Retorno dele sobre as caças do Módulo 2 ("escondidas demais, quero
  senso de exploração sem perder conteúdo"): em todos os lugares as pistas têm luz, brilho ou som direcional e dica automática em ~60 s.
- **Base** (`world/niveis/cidade_base.gd`, `CidadeBase`): ambiente por hora/clima, chão, borda invisível (AREA), HUD "CIDADE · lugar",
  `pista(id, fala)` (uma vez; flag `pista_<id>` + `pistas_tito`), `concluir()` (flag `cidade_<id>_feito`, volta à calçada em
  `Spawn_volta_cidade`), `sair()` (portão "Voltar ao Castelinho"), objetivo no Mapa (M). A **rede de segurança do Módulo 1** vale
  (`limites_mapa()` = AREA); a vigia da base só age sem ela. Ganchos por lugar: `_configurar/_construir/_tarefa`.
- **Acesso:** placa 3D da prefeitura fictícia na calçada da Garibaldi (só em 2020, só se algum lugar abriu) → `ui/placa_cidade.gd`
  (folheto, teclas 1–5, clique/toque). Abertura (`GameState.CIDADE`, "depois da visita N" = `visita > N`; a V4 conta ao chegar à
  Sala Medieval, `sala_maxima >= 78`): casas V2+, barra e praia V3+, ponte V4+, rodoviária V4 depois da Sala Medieval.
  Debug: `Debug.pular_cidade(id)` e 5 botões no painel; "ganhar tudo" conclui a cidade.
- **Pistas:** casas 2 (`casas_caderno`, `casas_mala`), barra 1 (`barra_pescador`), ponte 1 (`ponte_figura`), praia 1 (`praia_balde`),
  rodoviária 1 (`rodoviaria_cartaz`) = 6; total do jogo **21**. Escolha minha: `BracoSalvar.PISTAS_SALVAR` sobe de 12 para **16**;
  Encontrado continua 8.
- **Lugares:** *Rua das casas* (fim de tarde; achar a casa 7 da Travessa das Conchas pelo cartaz PROCURA-SE, abrir o portão; caderno em
  2020, mala do quarto de 1967 só com o Visor no disco de 1967). *Calçadão da Barra* (entardecer que escurece; tarrafa com o boto, 2 lances,
  sem o puxão do flashback, rejogável; o pescador mais velho dá a pista; reaproveita `barra.gd` sem alterá-lo). *Ponte à noite* (7
  postes, um morto, pescadores parados que se viram, Figura Branca que some se cercada, T de giz e sandália no guarda-corpo; sem
  morte). *Praia de Imbé* (ressaca, maré que avança e recua sem afogar, 4 objetos de criança, sino direcional, placa com fatos de
  `historia_imbe.md` §7.1). *Rodoviária* (2020 vazia; com o Visor em 1967, 3 plaquinhas de destino abrem o guichê e o cartaz da mãe, só voz;
  `visor_calmo` zera a atenção; `Efeitos.subtitulo_lugar`).
- **Arquivos fora dos lugares:** `autoload/efeitos.gd` (`subtitulo_lugar`), `autoload/game_state.gd` (tabela da cidade, `carregar()`
  apaga `visor_calmo`), `castelinho.gd` (placa 3D e `Spawn_volta_cidade`), `ui/debug.gd`, `ui/painel_debug.gd`, `world/objetivo.gd`,
  `tests/varredura/colocacao_lib.gd` (2 exceções: `FiguraBranca/Modelo` e `Relogio`).
- **Testes:** `tests/cidade_test.gd` (contrato da base) e `cidade_<id>_test.gd` por lugar (entram sozinhos no `testar.sh` por glob);
  capturas `tests/captura_cidade*.gd` (xvfb). Nunca rode dois `testar.sh` ao mesmo tempo (save compartilhado: `debug_test` falha em falso).
- **Não conferido:** nenhum som novo foi ouvido (sino da praia = `pista.wav` grave; plim/chiado/voz usam sons existentes), toque no celular
  real, desempenho na web da rodoviária com a moldura do Visor (~140 draw calls de 150).
- Pendente: o Icaro jogar e dizer se as pistas estão fáceis o bastante, se 16 pistas para o final secreto é muito, e se o tom das falas
  (pescador, mãe, Tainá) serve; o balde do fundo da Sala 101 não tem o T pintado (o da praia tem).

### Módulo 13: pedalinho, final secreto e fundo da Sala 101 (15/10/2026)

- **Origem:** fase C do playtest do Bernardo (`/mnt/project-files/castelinho/playtest-bernardo-plano.md`). O Icaro disse "considere feito"
  para o pedalinho, achou boa ideia o final "salvar o Tito" e aprovou o fundo da Sala 101 mais caprichado no formulário.
- **Escolhas minhas (dá para trocar):** o que destrava o final secreto é `pistas_tito >= 12` (`BracoSalvar.PISTAS_SALVAR`; o Encontrado pede 8,
  e há 15 no total). Sem as 12, o pedalinho amarelo está "preso com uma corrente de criança". "Buscar o Tito no fundo" virou **olhar para
  ele**: o Tito de 1967 está sozinho num pedalinho no meio do lago e o jogador o protege olhando pelo Visor ("Ninguém olhou na água" vira
  "alguém olhou"); ele nunca aparece na água nem em perigo. A mãe (fictícia, só voz, como no telefone do acervo) o chama da calçada.
- **O que o jogador vê:** com 12 pistas, uma coluna de luz azul se acende no meio do lago (`legenda`: "uma luz se acendeu"). Na margem,
  perto do atracadouro, o **pedalinho amarelo com balde vermelho** (E: embarcar). O jogador pedala (andar + mouse, 2,6 m/s, a proa segue
  o movimento, não o olhar; limites do lago; bate nos 5 cisnes e nos pontilhões) até a luz. Perto dela, com o Visor no disco de 1967
  (tecla 2) ou no sem data, aparece o pedalinho de 1967 com o Tito de costas, a Figura do outro lado da água e o céu de fim de tarde.
  Olhar para ele soma 9 s (não precisam ser seguidos; a luz fica mais forte). **Atenção do Visor**: sobe como sempre (5 s no
  porão/Braço); se encher, a Figura atravessa, o Visor sai da mão 10 s e a água puxa o barco 24 m para trás (o olhar já dado fica,
  sem morte). Perto do atracadouro, E desce do pedalinho.
- **Final "tito_salvo":** completo o olhar, o Tito se vira ("Você ficou olhando."), voz de mulher "— Titooo! Já pra casa!", "É a minha
  mãe.", "Obrigado por olhar na água.", a Figura afunda e o lago aquieta, a luz se apaga, ele vai pedalando para a margem em 1967
  (passa perto do barco do jogador). Título "TITO VOLTOU PRA CASA", cartão "Obrigado por olhar na água." e a dedicatória com o Disque 100.
  Título do jogo: 4ª marquinha branca só depois de visto e frase "Ele chegou a tempo." (T da lápide fica certo, como no Encontrado).
- **Código:** `castelinho/pedalinho.gd` (`Pedalinho.criar` = modelo, `pedalar`, `esteira`); `world/niveis/braco_salvar.gd` (`BracoSalvar`,
  criado em `braco_morto._ready`, `braco_morto.salvar`; `jogador(p, visor)` em `iniciar`; sinais `embarcou`/`desembarcou`/`puxado`/`concluiu`;
  `depurar_cena_final()`); em `braco_morto.gd` só ganchos (`_process`/`ao_morrer` ignoram quem está no barco, `_titulos_e_dedicatoria`
  com o 4º final, colisão dos 5 cisnes). `world/visor.gd`: a flag `visor_calmo` zera a atenção (só durante a cena final).
  `ui/finais.gd` (`TODOS` com `tito_salvo`, `SECRETO`), `ui/debug.gd` (`pular_final("tito_salvo")` embarca e começa a cena) e botão no painel.
- **Testes:** `tests/braco_pedalinho_test.gd` (trava por pistas, luz, embarcar/pedalar/descer, limites, olhar só na época certa, puxão,
  cena final até a dedicatória). Capturas (xvfb, fora do CI): `tests/captura_pedalinho.gd` (modos doca|barco|olhar|cena) e
  `captura_final.gd titulos` com o 4º final.
- **Fundo da Sala 101** (`world/niveis/fundo_do_lago.gd`, `FundoDoLago.chao_e_algas/pecas`, chamados por `_areia_e_algas` e `_pecas_do_fundo`):
  areia com ondulações e lodo, mais algas; sapatinhos e balde (com areia derramada), pazinha, bolinha listrada, óculos de natação, um
  chinelo, garrafas, pedras, âncora enferrujada com corrente e um pedalinho-cisne tombado ao longe; seis raios de luz que pulsam, a
  superfície vista de baixo, 30 bolhas e poeira em suspensão, névoa azul-esverdeada. Só sugestão, nada de corpo. Custo: 2 Malhas,
  8 quads aditivos, 2 emissores (≤40), 2 luzes, sem sombra. A câmera, o pitch e a mão da Figura não mudaram. Os óculos leem como duas
  lentes azuis (pouco nítidos).
- **Não conferido:** sons (nenhum som novo: pedalada usa `splash` baixo; a voz da mãe é só legenda + `crianca_ei`), o pedalinho no
  celular de verdade (usa o joystick e o botão E), desempenho do barco na web.
- **Para o próximo (módulo D, mais partes da cidade):** o lago continua sendo um retângulo de 200 x 36 m; se a cidade ganhar mais água
  ou margens, ajuste `BracoSalvar.LIMITE_X/LIMITE_Z0/LIMITE_Z1`. O PR #23 (módulo 1, paredes/void/rede de segurança) mexe na
  mesma região de `braco_morto._process`; conferir a rede de segurança (`y < -8`) ao integrar.
- Pendente: o Icaro jogar o final secreto (12 pistas é muito? o barco é lento? a mãe chamando funciona?).

### Módulo 2: Visor do Tempo, parte 2: caças dos discos (15/10/2026)

- **Decisão do Icaro (14/10):** aprovou as caças dos 4 discos restantes no formato do Passaporte. Plano:
  `/mnt/project-files/castelinho/cacas-discos-plano.md` (pasta do projeto, fora do git).
- **Regra:** cada disco se ganha achando 3 coisas com o disco anterior ligado (Q). Sem os 3, a entrega fala quantos faltam e dá dica.
- **Código:** `GameState.CACAS` (disco → visita, disco anterior, prefixo de flag, rótulo, ids) e `caca_achados/caca_completa/
  caca_achar/caca_concluir/caca_ativa`. O Passaporte virou a entrada do 1950 com o prefixo `passaporte_` (saves antigos ok).
  Objetos em `world/niveis/castelinho_cacas.gd` (`CacasCastelo`) e `world/niveis/porao_cacas.gd` (`PoraoCacas`); HUD genérico
  ("Passaporte/Vestígios/Marcas/Medidas/Desenhos n/3").
- **Caças:** 1967 (V2, com 1950): pedra grés, chaminé da casa original, estaca no lote de areia → vitrine do Acervo trancada até 3.
  1975 (V3, com 1967): Tito brincando, buraco no muro (seguem valendo como pista), pazinha e baldinho ao pé da Torre A → pegadas
  até a torre, pedestal só nasce com 3. 2019 (V4, com 1975): riscos "TITO 6/7/8" (Salão de Arte, Sala Medieval, Meio Ambiente)
  → painel solto só com 3. Sem data (porão, com 2019): desenhos de giz nas salas 82, 85, 88 → disco do quarto só com 3; se
  faltar algum ao chegar no quarto, os que faltam reaparecem na parede dele (as salas fecham atrás).
- **Buraco no muro** não virou passagem nova (a Torre A em 1967 está pela metade): virou ponteiro com pegadas e fala.
- **Debug:** "ganhar tudo" conclui as caças; pular de fase conclui as anteriores e dá os discos delas.
- **Mapa da Visita:** `Hud.objetivo_caca` está plugado em `Objetivo.extras` e mostra a caça ativa ("Vestígios 1/3: ligue o Q..."). Mover objetos de `CACAS`
  ou das entregas exige rever `castelinho_cacas.gd` e os testes.
- **Testes:** `castelinho_test`, `porao_test`, `debug_test`; capturas `tests/captura_cacas.gd`. Os testes dividem saves em `user://`:
  nunca rode dois `testar.sh` ao mesmo tempo (dá falha falsa em `debug_test`/`figura_q_test`).
- Pendente: o Icaro jogar e dizer se as caças ficaram divertidas e se alguma é difícil de achar; TITO 7 fica ao lado de um arco.
### Módulo 12: épocas, caminho e história (15/10/2026)

- **Origem:** fase B2 do playtest do Bernardo (`/mnt/project-files/castelinho/playtest-bernardo-plano.md`): ele se perdeu, achou
  muitas salas vazias, não entendeu a história (achou que o Tito morreu em 2019 porque o via no Visor em 2019) e não entendeu a
  fala "A água desce por aqui". Decisão do Icaro: o sumiço continua em **12/03/1967**. As caças dos discos são do Módulo 2.
- **Épocas:** legenda fixa sob o ano no Visor (`Efeitos._lbl_epoca`, tabela `SUBTITULO_EPOCA`; o `_lbl_extra` continua livre).
  **2019** (`castelinho/ruina2019.gd`, chamado no fim de `extras._ruina`): tábuas nos arcos (a porta fica livre), fita e placa
  INTERDITADO, letreiro CHOPERIA apagado (fato: restaurante até 2019), mato, mesas viradas e cadeiras, cartaz PROCURA-SE
  desbotado e pichação "CADÊ O TITO?" na fachada leste. Tudo **sem colisão**. **2026:** faixa "REABERTO · visitas guiadas aos
  sábados" na pérgola (V1–V2 inteira, V3 rasgada, V4 some; fato: sábados desde 20/02/2026). **Tito:** vivo só em 1967;
  `TitoNoVisor` agora é `criar_tito(true)` (fantasma azul-acinzentado, molhado, pingando) e só existe em 1975 e 2019.
- **Mapa da Visita** (`ui/mapa.gd`, tecla M, botão "Mapa" no toque e na pausa): folheto da prefeitura fictícia com andares,
  "você está aqui", próxima sala, salas vistas e a linha "Agora:". O nível dá os dados por `dados_mapa()` (só o Castelinho tem;
  porão: "Este andar não consta na planta"; Ato II e Barra: "Esta área não consta no mapa!"). V3 rabiscado, V4 com giz do Tito.
  **"Agora:"** vem de `Objetivo.atual()` (`world/objetivo.gd`); quem tiver objetivo próprio (as caças do Módulo 2) faz
  `Objetivo.extras.append(callable)`: o primeiro texto não vazio vence. Porão e Braço Morto: genérico ("Siga em frente.").
- **História fora dos painéis:** entre a visita 2 e a 3, o recorte da "Folha do Veraneio" (jornal fictício) de 14/03/1967
  (`ui/jornal.gd`, uma vez por save, flag `jornal_1967_visto`; `tests/castelinho_test.gd` o fecha no loop de visitas).
- **Água:** "Ouça. A água desce por aqui." (sala 80) dispara 3 lampejos da água subindo até 1,3 m (`world/flash_agua.gd`,
  compara a linha por semelhança porque a V4 a corrompe). Porão: goteiras com respingo no ritmo de `goteira.ogg`
  (`world/goteiras.gd`, menos no celular, nunca na sala 95). A água do porão fica cor de ferrugem com a Figura a menos de 6 m,
  no J2 e nas perseguições 90/94 (`world/agua_ferrugem.gd`, uma constante `COR_AGUA_FERRUGEM`; escolha da cor com o Icaro).
- **Sustos no caminho** (`world/niveis/sustos_caminho.gd`, cada um uma vez, adiam com fala, tela aberta, Visor ou perseguição):
  V3 sala 54 o fantasma do Tito cruza o fundo do corredor; V3 sala 66 a armadura aparece ao olhar de volta se o susto antigo
  não disparou; V4 sala 71 relâmpago com a Figura do lado de fora da janela do hall.
- **Testes novos:** `epocas_visual_test`, `mapa_test`, `agua_sustos_test`; botão Mapa no `celular_test`; lampejo no
  `tests/web_cenas.gd`. Capturas: `tests/captura_epocas.gd`, `captura_mapa.gd`, `captura_agua_sustos.gd`.
- **Não conferido:** sons dos sustos (sem placa de som), o mapa no celular de verdade. `debug_test` falha se o `save.json` do
  user dir estiver sujo de outra execução: rode com `XDG_DATA_HOME` limpo quando várias sessões testam ao mesmo tempo.

### Módulo 11: Q liga/desliga, pulo baixo e relatório (14/10/2026)

- **Origem:** o amigo Bernardo jogou e zerou (conversa repassada pelo Icaro). Decisões do Icaro: Q igual ao Correr; pulo
  baixo; relatório para quem trava ou bugou. Fora deste módulo (esperam o módulo 1 e os seguintes): paredes e void,
  épocas mais distintas, caminho e história (o sumiço do Tito continua em 1967), sustos no caminho, pedalinho e final secreto.
- **Q liga/desliga** (`world/visor.gd`): a tecla Q agora é a ação `visor_alternar` (a ação `visor` não tem mais tecla).
  `Visor.alternar()` aperta ou solta a ação `visor` e o resto do código segue perguntando `Input.is_action_pressed("visor")`
  (atenção, Figura, época, testes antigos que simulam o Q seguram a ação como antes). O Visor só solta sozinho o Q que ele
  mesmo ligou (`_latch`): tela aberta (`ui_aberta`), sem Visor, estouro da atenção (bloqueio) ou saída do nível.
  Sem disco ou bloqueado, tocar no Q dá só o tique de erro. Celular: o botão Visor chama `alternar()` (liga/desliga, azul
  quando ligado). Textos "segure Q" viraram "aperte Q" (painéis, falas, faixa de discos, README).
- **Pulo baixo** (`player/player.gd`): ação `pular` = Espaço, botão Pular no celular (acima do Visor, `ui/controles_toque.gd`).
  `VEL_PULO` 3,5 m/s com gravidade 18: **sobe ~0,37 m** (medido em `tests/pulo_test.gd`), sem pulo duplo, sem pular em fala da
  Guia, tela aberta ou cena (`pode_mover` falso), e não acelera o andar (a Figura não é driblada por pulo). Quem mexer
  em degraus, muretas ou bordas do mapa: nada deve ter entre 0,3 e 0,4 m de altura sem querer.
- **Relatório** (`ui/relatorio.gd` + página nova em `ui/menu_pausa.gd`, 1 linha em `scenes/main/main.gd`): como o site é
  estático, o jogador abre Pausa → "Enviar relatório" e vê um texto curto (versão, plataforma, nível, sala, visita, época, disco,
  atenção, posição, qps, trilha das últimas 12 salas com tempo, últimos 8 erros do motor via `Logger`) com **Copiar** e
  **Mandar pelo WhatsApp** (`wa.me/?text=`, o jogador escolhe o contato). Sem servidor, sem dados pessoais. A versão sai "?"
  porque o `project.godot` não define `application/config/version`.
- **Testes novos:** `tests/pulo_test.gd`, `tests/relatorio_test.gd`, bloco "Q liga e desliga" em `visor_test`, botões Visor/Pular em
  `celular_test`. Não conferido: o clipboard e o WhatsApp de verdade no navegador, e o layout do relatório no celular deitado.
- Pendente: o Icaro testar (Q com um toque no PC e no celular, pulo, relatório) e dizer se o pulo está bom.

### Módulo 10: Galeria 3D e colocação dos objetos (14/10/2026)

- **Pedido do Icaro:** "erros de continuação/colocação dos objetos 3D" (não lembrava onde: varrer tudo) e uma visão de todos
  os objetos, com comentários no Canva. Não respondeu às perguntas da abertura: segui as recomendações (galeria pública com
  aviso de spoiler e sem link no jogo; Canva com uma página por objeto, agrupado por lugar; correção direta do que é
  claramente erro; teste no CI porque roda em ~8 s).
- **Registro de objetos** (`castelinho/malha.gd`, topo do arquivo): `Malha.ligar(nivel)` / `desligar()`; nas construtoras,
  `var _et := Malha.abrir("nome")` … `Malha.fechar(_et)`. Desligado, custa um `if` por primitiva. `Malha.registro`,
  `info_por_etiqueta()`, `mesh_da_etiqueta(et)`. Nós soltos: `RegistroObjetos.varrer(raiz, nivel)` (`castelinho/registro.gd`),
  nome por `Malha.nomear(no, "nome")`. Só o castelo tem etiquetas; porão, Ato II, Barra e lago usam nome automático do nó.
  **Regra nova:** objeto novo no castelo ganha `Malha.abrir/fechar` com nome legível.
- **Verificador:** `godot --headless -s res://tests/varredura/colocacao.gd [-- castelo ato2 barra porao braco]` (~12 s),
  relatório em `tests/varredura/saida/colocacao.{json,md}`. `tests/colocacao_test.gd` (CI, ~8 s) falha com qualquer
  flutuando/enfiado/atravessa parede/z-fighting real fora de `EXCECOES` (`tests/varredura/colocacao_lib.gd`, cada uma com
  o motivo). Frestas, degraus de piso e continuidade ficam só no relatório. Não cobre: cenas dos finais, piso por época,
  continuidade de objetos-nó.
- **Corrigido** (B26–B36 em `docs/BUGS.md`): tocha, lanças e poltronas da Sala Medieval, plaquinha da entrada, cartazes e
  desenhos colados na parede, blocos da Torre A (1967), P03 75 cm ao norte (postes atravessavam o banco), desenho da sala
  83, balde do menino, Tito do Braço Morto sentado na borda (`POS_TITO.z` -7,72), z-fighting (escadas, cavaletes, pisos
  do porão, soleiras de todos os vãos +4 mm em `muros.gd`, Barra, rua do lago), meio-fio e calçadão do lago sem face.
- **Galeria** (`galeria/`, tem `.gdignore`; o workflow copia para `build/web/galeria/`):
  `xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tools/galeria/fotografar.gd -- galeria`
  (~4,5 min; `ids=a,b`, `cen=chave`, `sem_local`, `sem_glb`). Catálogo em `tools/galeria/catalogo.gd` (castelo por
  etiqueta; porão, lago e Barra por caixa de recorte medida no código: revise se mexer nesses objetos). Gera fotos,
  `.glb` e `galeria/manifesto.json`. Dúvidas para o Icaro: `tools/galeria/duvidas.json` (vão para as notas). Depois
  `python3 tools/galeria/gerar_canva.py` gera `galeria/canva.html` (uma página por objeto, para o Canva importar).
- **Canva:** design "Castelinho — Galeria 3D (objetos e dúvidas)", id `DAHYBywfhYE`, 172 páginas, importado de
  `.../galeria/canva.html` (ver: https://www.canva.com/d/MFcSEKkAWuZuGo8; editar: https://www.canva.com/d/ICFrQtm7LqyqR5n;
  link também no topo da galeria, campo `canva` do manifesto).
  **Para ler os comentários do Icaro:** carregue `mcp__Canva__list-comments` (ToolSearch) com o id do design (começa com
  "D", está no link) e `list-replies` para as respostas; cada página tem o nome do objeto no título (`data-label`) e o id
  nas notas do apresentador. Responda com `reply-to-comment`. Para refazer o design depois de mudar a galeria: gere o
  `canva.html`, publique (merge) e importe de novo (`import-design-from-url`); comentários antigos ficam no design velho.
- **Dúvidas em aberto (no Canva):** corredor de 1975 atravessando a casa vizinha, menino dos slides 97/98 com as canelas
  no piso, P08 solto da parede, moldura do P17 na torreta, dentes do buraco do muro, fita zebrada perto da cadeira, e
  conferir as duas mudanças (Tito do lago, P03).
- **Limites:** mascotes só existem em 2D (fora da galeria); `folha_costela` e as dúvidas sem `.glb`; textos de Label3D e
  shaders saem como cor lisa no `.glb`; `fundo_lago_pecas` sem foto de local. 64 frestas pequenas (B) só no relatório.
- Pendente: o Icaro comentar no Canva; a próxima sessão lê os comentários e corrige.

### Módulo 9: Modo debug e Figura no Q (09/10/2026)

- **Problema do Icaro (visita 3):** "toda hora que aperto Q o monstro vem direto em mim". Causa: a Figura do slide era o
  modelo antigo, presa na frente da câmera (girava junto), desenhada por cima das paredes e aparecia com 0,7 s de Q; e a
  atenção esvaziava em 9 s, então ela acumulava entre um Q e outro.
- **Decisões do Icaro:** perseguição de verdade só na V4 e no porão; a Figura **"tipo a Granny pura"**: corpo de verdade,
  não atravessa parede, não congela quando olhada, nunca reaparece atrás do jogador; atalho do debug = tecla `'`.
- **Atenção** (`world/visor.gd`): `TEMPO_ENCHER` {3: 10, 4: 7, 5: 5} s, `TEMPO_ESVAZIAR` 4 s, `GRACA_S` 6 s sem encher
  depois do bloqueio de 10 s, Figura no slide só acima de 0,35. V1 e V2 continuam sem atenção.
- **Figura do slide:** uma `FiguraBranca` `somente_visual` no mundo (com profundidade), visível só com o Q, parada no
  **rastro** do jogador (`world/rastro.gd`, `Rastro`: migalhas a cada 0,5 m, últimos 45 m) ~14 m atrás e chegando
  pelo caminho até 2,5 m (V3) ou 5 m (V4/porão). Sem rastro (jogador parado), não aparece. `pos_figura_slide()`.
- **Perseguição "Granny"** (`creatures/figura_branca.gd`, `ativa=true`): enxerga até 20 m em qualquer ângulo sem parede
  no meio; velocidade entre 3,3 e 4,5 (jogador anda 3,0, corre 5,4); perdeu de vista → segue o rastro até onde viu,
  procura 4 s, sinal `desistiu`, vai embora e some fora da vista. API: `ativar(atraso)`, `desistir()`, `estado`.
  `ativa=false` (dunas, sala 27) segue como antes (some quando cercada). V4: nasce onde a do slide estava, 3,7 m/s,
  teto 45 s. Porão: salas 90 (3,4) e 94 (3,8) agora nascem na entrada quando o jogador passa de 35 % da sala.
  Ato II: casa 3,3, arcada 3,8 saindo da porta dos fundos.
- **Ficou mais difícil:** quem fica parado na casa da sala 57 ou na cela do giz (90) com ela vindo morre (antes olhar
  salvava). Sala 58 andando reto dá para chegar à porta. Nada disso foi jogado a pé, só por teste.
- **Modo debug** (`ui/debug.gd` `Debug`, `ui/painel_debug.gd`): liga com `?debug=1`, `--debug` ou 5 toques em 3 s no
  contador "Visitantes" do título (celular); tecla `'` ou botão DBG abre o painel (pausa o jogo). Imortal
  (`GameState.matar_jogador` ignora), Figura desligada (toda `FiguraBranca` some, inclusive nas cenas finais), atenção
  congelada, ganhar tudo, pular para visita+sala (cai no checkpoint mais perto antes da sala pedida) e para cada final,
  info (sala, época, visita, qps). Save à parte (`user://save_debug.json`) e finais à parte (`user://finais_debug.cfg`):
  o jogo normal nunca é tocado. O `?debug=1` real na Web só foi conferido por leitura, não no navegador.
- **Testes:** `tests/figura_q_test.gd`, `tests/debug_test.gd`; `visor_test`, `ato2_test`, `castelinho_test`,
  `porao_test` ajustados à regra nova (olhando, ela anda).
- Pendente: o Icaro testar o Q na V3/V4 e as perseguições (57, 58, 90, 94, V4) e dizer se ficou tenso ou fácil demais.

### Módulo 8: Celular (09/10/2026)

- **O Icaro não respondeu às perguntas da abertura:** segui as recomendações (dá para desfazer). Opção "Controles de
  toque: Automático / Sempre / Nunca" (Pausa → Opções, `user://opcoes.cfg` chave `controles_toque`); Correr liga com um
  toque e para ao soltar o analógico; modo leve automático; sensibilidade do olhar usa o mesmo slider. Celular dele:
  ainda não sabemos.
- **Detecção** (`ui/celular.gd`, `Celular`, estático): página Web define `castelinhoToque()` (ponteiro grosso + toque),
  `castelinhoIOS()`, `castelinhoSeguro()` (entalhe) no head_include do `export_presets.cfg`. URL `?celular=1`/`0` força;
  `--celular` na linha de comando também. **Armadilha:** `JavaScriptBridge.eval` devolve booleano JS como número na Web
  real (no headless não se vê): use `Celular._js_bool()`.
- **Regra nova para todos:** nunca `Input.mouse_mode = ...` direto: `Celular.capturar_mouse()` / `soltar_mouse()` (no
  iPhone não há pointer lock). Pausa: `main.gd` `deve_pausar()` — desktop = mouse solto; celular = `Celular.pausa_toque`
  (botão, foco perdido, Esc de teclado) ou `Celular.retrato`. Dica de tecla mostrada ao jogador passa por
  `Celular.adaptar(texto)` ou `Celular.dica(teclado, toque)`.
- **Controles** (`ui/controles_toque.gd`, camada 15, abaixo do balão da Guia): analógico flutuante à esquerda
  (`Input.action_press` com força), analógico da câmera à direita (velocidade de giro, `VEL_YAW`/`VEL_PITCH` em `ui/controles_toque.gd`; o Icaro achou o arrasto direto brusco: um toque virava a câmera), Interagir
  (amarelo com alvo), Correr, Lanterna, Visor (segurar), Pausa (sempre visível jogando, inclusive em cinema), Tela cheia.
  Toque na faixa de discos (`FaixaDiscos.slot_em`). Toque rápido avança a Guia; a Guia ignora o clique emulado do toque e,
  no celular, o clique sai da ação "interagir". Balão da Guia encolhe até `Celular.borda_botoes()`.
- **Telas:** interface 1,35× só durante o jogo (título, painéis, menus e finais ficam em 1,0: foram desenhados para
  1280x720); aviso "vire o celular" opaco (`ui/aviso_retrato.gd`); área segura do entalhe em `Celular.margens()`.
- **Modo leve** (`Celular.aplicar_qualidade()`, desfeito no desktop): 3D a 70 %, 30 qps, até 3 luzes no Castelinho
  (`Celular.limite_luzes()`), metade das partículas, sem a LuzDosDegraus no Braço Morto. Pós-processamento mantido.
- **Som:** head_include destrava o AudioContext no 1º toque e põe `navigator.audioSession` em "playback" (iPhone no
  silencioso). Nunca ouvido de verdade.
- **Testes:** `tests/celular_test.gd` (CI). `tools/testar_web_celular.sh` (fora do CI, ~5 min): build Web real no
  Chromium 844x390 com toque; capturas da fala, painel, pausa, Opções e retrato. Captura xvfb: `tests/captura_celular.gd`.
- **Não medido:** desempenho real (a nuvem roda a 2–3 qps por software). O corte de luzes só foi visto na visita 1, não
  nas noturnas. Telas cheias (painel, quiz, diploma) ficam com texto ~14 px no celular: legível, mas pequeno.
- Pendente: o Icaro testar no celular (lista no PR #17) e dizer o que travou, ficou pequeno ou difícil de tocar.

### Módulo 7: Arte e gráficos (09/10/2026)

- **O Icaro não respondeu às perguntas da abertura:** segui as recomendações (dá para desfazer). Mão e dedos de afogada
  (pálidos, enrugados, sem garras); começo Flash intocado, acabamento só do porão em diante; slide 98 com a Figura nova;
  da revisão Opus, aplicados os achados baratos.
- **Capturas a olho** (scripts novos fora do CI: `tests/captura_visitas.gd` modos folha|tito|pegadas|susto18|susto22,
  `tests/captura_figura_mov.gd`, `tests/captura_porao_vista.gd`). Ok sem mexer: folha "TITO 6–9" e fala engasgada (V3),
  Tito de costas (V4 sala 74), giz da cela 90, títulos dos finais.
- **Corrigido:** pegadas (V4 e lago) viraram pé de criança molhado, helper novo `world/pegada.gd` (`Pegada.criar`);
  mão no ombro com cotovelo e dedos curvos (`_mao_longa`); dedos na lente afinando, com nós e palma, sem a "unha" preta
  (`_mao_na_camera`, 7 dedos); lápide com "TITO" inteiro numa placa; lua redonda; fundo da Sala 101 com areia, algas,
  sapatinhos e balde perto e iluminados; HUD diz "SALA 101" ao afundar (`entrar_sala(101)`; `sala_maxima` vira 101,
  checkpoint segue 100); slide 98 com `_figura_slide` (nó "FiguraSlide") e menino afastado; Figura com `_arranco` ligado
  e andar aos trancos alternando lados; sustos com pés no chão a mais de 2 m e `_ponto_livre` (nunca nasce dentro de
  parede; vale para todo susto sem `pos`); V4 sala 22 sem o arco cortando; correntes da 87 em aço com tocha; cela 90 com
  fundo aberto, banco e balde.
- **Revisão Opus aplicada:** HUD some nas cenas de cinema (`hud.modo_cinema`; no Visita concluída fica escondido até o
  fim); poça do lago sem degraus serrilhados; legenda de chegada mais baixa e com faixa escura; degraus da escada de
  chegada em lajota com borda clara; marola em volta da Figura no lago; grama mais fina; mural "Castelinho Imbé/RS"
  legível; lustres sem verde-neon; dicas "Esc: fechar" e "segure Q: ver" maiores.
- **Não feito (ideias):** a Figura no lago segue "de pé na água" (escolha de roteiro); fundo da Sala 101 ainda simples;
  dedos da mão do ombro podiam curvar mais; balde do fundo é um bloco vermelho. Áudio: durações das cenas finais não
  mudaram (só o ângulo da cabeça no afundar).
- Pendente: o Icaro jogar os finais e o porão e dizer o que ficou feio.

### Módulo 6: Áudio (09/10/2026)

- **O Icaro não respondeu no prazo de 2 h:** segui as recomendações (abaixo). Ele ainda **não ouviu** nada; tudo segue
  conferido só por número. Para ouvir sem jogar: página **Mesa de som** (artifact privado do Icaro,
  https://claude.ai/artifact/8QEcTF238ZrVzPWyTGaCtJ) com todos os sons no volume do jogo, cenas mixadas e notas por som
  (ficam no banco do artifact, coleção `notas`; leia com ArtifactData). Seis perguntas lá no topo; pendentes de verdade:
  "o jingle soa Flash educativo?" e "o volume das Opções funciona no navegador?".
- **Decidido sem o Icaro (dá para desfazer):** Tito fala com murmúrio abafado (`voz_tito`); um som por tipo de susto;
  jingle_1 mais estranho (18 cents, fita instável, notas somem, `VERSOES_JINGLE[1]`); Visita 1 segue sem ambiente.
- **Sons novos** (`tools/gerar_audio.py`, semente própria cada; os antigos não mudam): `susto_agua` (porão 86),
  `susto_perto` (88), `susto_queda` (99), `voz_tito`, `afundar` + loop `subaquatico` (Sala 101), `figura_sobe`
  (Visita concluída), `figura_afunda` (Encontrado), `pista` (contador do HUD, antes `blip_misterio`).
- **Bug:** o abafado da Sala 101 era filtro no bus Master, que **não funciona na web** (modo Sample, sem efeitos de bus).
  Agora o abafado vem do arquivo `subaquatico`; o filtro ficou para o desktop. Regra: na web, todo efeito de som tem de
  ser pré-renderizado no arquivo.
- **Mixagem** (RMS da janela mais forte × dB no jogo): os sustos eram mais baixos que apito e carimbo → `COMPRIMIR` no
  gerador (saturação suave) e agora estão no topo; J5 de +6 para +2 dB (passava do pico). Goteira, rio, sussurro e
  blip_sistema subiram; apito, selo e telefone desceram (`VOLUME_PADRAO`).
- **Para o módulo 7 (Arte):** nada de áudio depende de arte. Se mudar a duração de cenas do final (`braco_morto.gd`), confira
  que `figura_sobe` (2,5 s), `figura_afunda` (4 s) e `afundar` (5 s) ainda casam com os tweens. Um susto visual novo
  pode usar `"sfx": "susto_agua" | "susto_perto" | "susto_queda"` no `Susto.disparar`.
- Pendente: o Icaro ouvir e marcar notas na Mesa de som; ajustar o que ele marcar (próxima sessão de QA ou áudio).

### Módulo 5: Braço Morto e final (09/10/2026)

- **Decisões do Icaro:** pistas para o Encontrado = 8 (de 15: 8 castelinho, 6 porão, 1 lápide); contador visível (T de
  giz invertido + número, sem total); finais "o mais pesado possível" só por sugestão; 3º final sim; título muda após
  zerar; menu no Esc. O Icaro ainda **não jogou** o final.
- **Chegada:** legenda "(lá em cima, um lago...)" 1,5 s depois; dica única aos 45 s; luz quente na lápide.
- **Bugs:** lápide durante a cena do Tito; soltar Q no meio da cena (Visor travado); `ao_morrer` durante o fim.
- **Finais** (`world/niveis/braco_morto.gd`, `fim(final)` = `encontrado` / `visita_concluida` / `sala_101`):
  - Encontrado: falas "Disseram que eu fugi de casa." / "Ninguém olhou na água." / "Agora alguém sabe."; Tito anda para
    a luz com pegadas, a Figura afunda, o T da lápide se endireita.
  - Visita concluída: "Você também vai embora."; a Figura sobe atrás dele e pousa a mão no ombro; cartão "Obrigado pela
    visita! Volte sempre!".
  - Sala 101: atracadouro de pedalinhos é a única entrada no lago; convite "(vem. aqui embaixo é quietinho.)"; aviso
    "(a água está gelada.)"; a ~3,5 m afunda (filtro passa-baixa no Master, tirado no `_exit_tree`); sapatinhos e balde
    no fundo; dedos da Figura na lente; "VOCÊ FICOU." + cartão "Sala 101".
  - Dedicatória com Disque 100 em todos.
- **UI:** `ui/menu_pausa.gd` (Continuar, Opções, Voltar ao título com confirmação); `ui/opcoes.gd` (`user://opcoes.cfg`:
  volume, sensibilidade); contador de pistas em `ui/hud.gd` (escuta `flag_mudou` "pista_*"); `ui/finais.gd`
  (`user://finais.cfg`) e lápide na tela de título; contador "Visitantes" do título vira 000101 após o final Sala 101.
  `main.gd`: 2 linhas ligam `fim` a `Finais.registrar`.
- **Captura:** `tests/captura_final.gd` (xvfb, fora do CI; modos titulos|pausa|chegada|encontrado|visita_concluida|sala_101).
- **Para o módulo 6 (Áudio):** falta som próprio para Tito falando as falas novas, o afundar (Sala 101), a Figura
  subindo/afundando e o pulso do contador (hoje `blip_misterio`); conferir volume do menu de Opções no navegador.
- **Para o módulo 7 (Arte):** mão/dedos da Figura (Sala 101 e ombro do Tito), pegadas molhadas, Figura do outro lado do
  lago, lápide de areia (título e lago), escada escura de chegada, slide 98 do porão com a Figura antiga.
- Pendente: menu do Esc só testado no xvfb, não no navegador (recaptura do mouse no clique).

### Módulo 4: Porão (08/10/2026)

- **Decisões do Icaro:** o porão é história com começo, meio e fim: **toda partida é igual** (acabou o sorteio e a
  `porao_semente`; a tabela `PLANO` em `porao.gd` manda). História do Tito: **afogamento**, com um "sequestro"
  sobrenatural sugerido (a Figura chama o menino para a água), nunca uma pessoa. A escada de 2019 desce até o outro
  lado de fitas zebradas "EM REFORMA" (sala 81). Água 97–99 com o disco "sem data": baixa ao tornozelo, espelho dourado,
  sem lentidão (B25). Porão de 15 a 20 min. O Icaro ainda **não jogou** o porão.
- **Sequência fixa:** 81 escada e fitas (fala "área fora da visitação") · 82 abóbada (sussurro, dica do Visor) ·
  83 desenhos · 84 colunas com celas (regulamento: "não vá até a água") · 85 criança · 86 alagado (tornozelo, checkpoint)
  · 87 pedras com celas e correntes, Costela · 88 telefone · 89 bifurcação com a voz certa (o balde vermelho ensina o
  caminho) · 90 arcos, 1ª Figura, cela aberta com o giz "ELA DISSE QUE O LAGO É LÁ EMBAIXO" (pista `giz_cela`) ·
  91 escada (joelho, checkpoint, "de um res— responsável") · 92 poço, Costela · 93 bifurcação com a isca (a voz imita o
  Tito e leva à água funda) · 94 cisterna, Figura mais rápida ("um a mais do que entrou") · 95 quarto ("não consta na
  planta") · 96–99 último dia (Visor não solta a Figura ali) · topo da 99 "Fim da área de visitação", pausa com
  "(ar fresco. lá fora, a água corre.)" e o fade.
- **Figura Branca nova** (`creatures/figura_branca.gd`, vale para o jogo todo): afogada, alta e magra, cabelo molhado
  cobrindo o rosto, dedos longos; mexe aos trancos, congela quando vista com um estalo da cabeça, arranca na perseguição.
  API igual. Captura: `tests/captura_figura.gd` (xvfb, fora do CI).
- **Sustos (pedido do Icaro: "faltam jumpscares"):** `creatures/susto.gd` (`Susto.disparar(nivel, chave, opções)`, não
  mata, uma vez por partida com flag `susto_<chave>`, rosto da Figura na altura dos olhos). Porão: J1 85 vulto de
  criança no apagão · J2 86 a Figura sobe da água · J3 88 atrás do jogador depois do telefone (ao virar) · J4 91 apagão
  na escada · J5 99 cai do escuro colada na câmera, antes do "ar fresco". 95–98 sem susto (contraste). Visitas
  (`castelinho.gd`, `_susto_castelo`): V3 sala 18 (apagão, Figura no facho da lanterna), V4 sala 22 (luzes piscam,
  Figura de lado), V4 painel 11 (ao virar as costas). V1 e V2 sem susto.
- **Cela da 90 mais pesada (Icaro: "pode ser mais pesado"):** 4 desenhos de giz (menino e sol → a figura segurando a
  mão, "ELA DISSE QUE O LAGO É LÁ EMBAIXO" → água subindo, "QUERO IR PRA CASA" → só o balde boiando), riscos de contar
  dias na altura de criança, mãos molhadas na grade. Só sugestão.
- **Bugs:** voz do poço sobre o poço; Figura nas salas pequenas; morte durante a saída; sussurro repetido e cobrindo
  legendas importantes; grade da 96 sem aviso.
- **Para o módulo 5 (Braço Morto):** o jogador chega do porão parado, com a legenda do ar fresco e o ambiente já em
  silêncio; `GameState.entrar_sala(100)` só roda logo antes da troca de cena. Falta uma fala ou legenda de chegada no
  lago (hoje a 1ª dica só vem na lápide). Pistas possíveis para o final "Encontrado" agora incluem `giz_cela`
  (reveja o limite de 6). O slide 98 (porão) ainda desenha a Figura antiga, de braços abertos: vale alinhar com a nova no módulo 7.
- Pendentes: `tests/varredura/porao.gd` e `tests/captura_porao.gd` ainda gravam `porao_semente` (ignorada; fora do CI).
  `docs/V2_ROTEIRO.md` §6 ainda fala em salas sorteadas: a verdade agora é a tabela `PLANO`. Movimento da Figura e
  correntes da 87 só vistos por teste e captura parada: vale olhar no módulo 7.

### Módulo 3: Visitas 1 a 4 (08/10/2026)

- Revisão de ritmo (Sonnet, relatório resumido abaixo) e correções. O Icaro aprovou todas as recomendações.
- **Quiz:** V1 normal; V2 "Quiz final: encerrado" (`quiz_final_v2` = `p22_v2`; diploma TITO, apagão e balde seguem);
  V3 `quiz_final_v3` corrompido (3 perguntas sobre o Tito, opção `qualquer` em `painel_ui.gd`: toda resposta é
  "CORRETO!", sem selo) e "Diploma indisponível. Visitante não identificado."; V4 sem quiz (painel riscado, desenho_7).
- **Ritmo:** V2 termina mais forte que o meio (sandália junto do balde, apagão vai a 0,5 e volta à curva; a Barra caiu
  de 0,5 para 0,35). V3 mais guiada (falas na sala 10, armadura só depois do Ato II) e com fim: a folha das marcas de
  altura "TITO 6…9" abre ao atravessar a porta de 1975, fala engasgada, fade para a V4. jingle_2 depois do Ato II.
  V4 com dois acontecimentos fixos: Tito de costas no fim do corredor (sala 74, some quando encarado) e pegadas
  pequenas molhadas até o mural (sala 77). Dicas do disco 2019 sem repetir (sala 8: painel solto; sala 21: vaga).
- **Bugs:** lanterna da V3 gravada antes da fala do Quico; telefone da V2 toca de novo até atender; balde e sandália
  ficam no trono na V3/V4; semente 3 (criança com balde na margem do mural) pintada; "Quase lá" e "pela porta" sem repetir.
- **Fontes** (`docs/pesquisa/historia_imbe.md`, "Reconfirmação"): 1934 só pela Prefeitura de Tramandaí (mantida a
  atribuição); "16 mil/80 mil" é da Vitruvius de 2007 (P12 diz "em 2007"; P18 sem os 80 mil). P15_v2, P16_v2 e P19_v2
  mais precisos. Tom de P14, P15, P16, P19, P21 e P23 conferido: ok.
- **Só validado por teste automático, não a olho:** o beat final da V3 e as duas cenas da V4. Vale captura no módulo 7.
- **Para o módulo 4 (Porão):** a V4 entra no porão só pela escada de 2019 (`_descer_porao`), com corrupção ~0,65 e sem
  música; o jogador chega já tendo visto o Tito de costas, as pegadas molhadas e o balde com a sandália. O porão deve
  subir a partir daí, sem repetir esses sustos. A sala 80 diz só "Ouça. A água desce por aqui." (não cita mais o
  Braço Morto). Ainda pendente do módulo 1: água das salas 97–99 com o disco "sem data".
- Pendente para o Icaro jogar: se o "CORRETO!" da V3 assusta ou soa bobo; se a V4 ficou pesada o bastante.

### Módulo 2: Visor do Tempo, parte 1 (08/10/2026)

- Revisão independente do Visor (Sonnet). Corrigido (PR #9): `visor_travado` prendia o jogador ao trocar de disco no
  corredor de 1975/dunas (agora volta à época de antes, ou à que o nível impôs com o Q apertado); `selecionar_disco`
  salva; `Efeitos.aviso(texto)` novo ("Você ainda não tem esse disco."); dica de teclas na faixa de discos.
- **Decisões do Icaro:** (A) visita 4 desce ao porão **só** pela escada da Sala Medieval em 2019 (a porta zebrada do
  hall só fala); (B) cada disco tem uma pista obrigatória; (C) na visita 4 a Figura **persegue** (12 s) quando o olho
  enche; e **cada disco se ganha com uma "caça ao objeto"** usando o disco anterior.
- Feito: A, C e a caça do **1950** ("Passaporte do Museu", salas 1–10: pedra, foto, chave; fatos de
  `docs/pesquisa/castelinho.md`; flags `passaporte_<id>`, contador no HUD; a sala 10 só entrega o disco com os 3).
- **Plano aprovado para os próximos discos** (fazer depois que o Icaro jogar a do 1950 e aprovar o formato):
  1967 = achar 3 coisas que só existem em 1950 (V2, leva à vitrine do Acervo); 1975 = marcas do Tito em 1967, com o
  buraco no muro virando passagem até a Torre (V3); 2019 = marcas de altura em 1975 apontando o painel solto (V4);
  sem data = desenhos do Tito em 2019 (porão). Tom: alegre na V1, sinistro no porão.
- **Para o módulo 3 (Visitas 1 a 4):** `castelinho.gd` ganhou o bloco "Passaporte do Museu", `_on_figura_atravessou`
  (perseguição V4) e `_exit_tree`; a porta zebrada do hall não desce mais; as falas das salas 21 e 80 da V4 mudaram.
  Mudar a posição dos discos/objetos mexe com as caças: combine com o módulo 2.
- Pendente: ~~controles de celular~~ (feito no módulo 8); esvaziamento da atenção (9 s) permite
  "espiar em rajadas" na V4/porão, o Icaro decide ao jogar.

### Módulo 1: QA e bugs, varredura automática (08/10/2026)

- O Icaro ainda não jogou a versão 2; esta sessão só fez a varredura automática (8 agentes Haiku em paralelo, um
  Sonnet no porão). Scripts em `tests/varredura/` (fora do CI, ver o LEIA-ME de lá).
- 10 bugs corrigidos com teste (`docs/BUGS.md` B15–B24). Os graves: o jogo **não terminava** (escada da sala 99 era
  uma parede), **queda sem fim** no calçadão do Braço Morto, na bifurcação e na cisterna do porão, e a **porta de 1975
  na visita 4 pulava o porão**.
- Limpos: os 19 checkpoints do "Continuar", o console em todas as cenas e os shaders WebGL em todas as épocas.
- Pendente para o Icaro: água das salas 97–99 com o disco "sem data" (ver "Sem correção" no BUGS.md). Para o módulo 3:
  o quiz final só existe nas visitas 1 e 2.
- Ferramenta: `tools/testar_web_cenas.sh` precisa do Playwright de Python, que não vem na nuvem (`pip` falhou);
  a varredura usou o Playwright de Node. Vale consertar quando alguém mexer em shader.
- Próximo: quando o Icaro jogar, uma sessão do módulo 1 (ou do módulo do problema) registra e corrige o que ele achar.

### Módulo 0: Fundação (07/10/2026)

- Versão 2 publicada: 4 visitas, Visor 2.0, porão e Braço Morto. 8 suítes de teste verdes.
- **O Icaro ainda não deu retorno da versão 2** (ritmo, Visor, porão, bugs, áudio). O módulo 1 começa perguntando isso.
- Zip do Windows agora é só sob pedido (ver `CLAUDE.md`, Git e publicação).
- Pendências antigas: revisar o tom dos painéis P14, P15, P16, P19, P21 e P23, que não tinham tema no roteiro
  (`docs/PENDENCIAS.md`), e reconfirmar a data da primeira ponte (1934) e o "~16 mil para ~80 mil" do P12.
