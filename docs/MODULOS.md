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
| 1 | QA e bugs | Varredura das 100 salas, corrigir o que o Icaro e os testes acharem | `tests/`, `docs/BUGS.md` (correções pontuais em qualquer arquivo) | varredura automática feita (B15–B24); reabre quando o Icaro jogar |
| 2 | Visor do Tempo | Acertar a mecânica do Q e dos discos conforme o retorno de quem jogou | `world/visor.gd`, `world/epocas.gd`, `ui/faixa_discos.gd`, `ui/olho_atencao.gd` | parte 1 feita (bugs, escada 2019, Figura na V4, caça do disco 1950); caça dos discos 1967–sem data espera o Icaro jogar a do 1950 |
| 3 | Visitas 1 a 4 | Ritmo ("mais lento até ficar bizarro"), sustos, painéis, flashback da Barra | `world/niveis/castelinho.gd`, `ato2.gd`, `barra.gd`, `data/paineis.json` | feito (PR #11): ritmo, quiz V2–V4, bugs, fontes; reabre quando o Icaro jogar |
| 4 | Porão | A masmorra (salas 81 a 99) | `world/niveis/porao*.gd`, `shaders/porao_*` | feito (PR #12): sequência fixa, masmorra, Figura nova, sustos (porão e V3/V4), bugs; reabre quando o Icaro jogar |
| 5 | Braço Morto e final | Sala 100, Tito, finais, dedicatória | `world/niveis/braco_morto.gd`, `castelinho/tito.gd`, `ui/dedicatoria.gd`, `ui/volte_sempre.gd`, `ui/telefone.gd` | feito (PR #14): três finais (Encontrado ≥8 pistas, Visita concluída, Sala 101), menu do Esc, contador de pistas, título muda após zerar; reabre quando o Icaro jogar |
| 6 | Áudio | Jingle, ambientes e sustos (ninguém ouviu ainda: precisa do ouvido do Icaro) | `autoload/audio.gd`, `tools/gerar_audio.py`, `assets/audio/` | feito (PR #15): 9 sons novos, mixagem medida, Sala 101 abafada na web, jingle_1 mais estranho; reabre quando o Icaro ouvir (Mesa de som) |
| 7 | Arte e gráficos | Acabamento visual mantendo o estilo Flash educativo | `shaders/`, `tools/gerar_texturas.py`, `castelinho/` | na fila |

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
- Pendente: controles de celular (o Visor só funciona com teclado e mouse); esvaziamento da atenção (9 s) permite
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
