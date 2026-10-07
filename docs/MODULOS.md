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
| 1 | QA e bugs | Varredura das 100 salas, corrigir o que o Icaro e os testes acharem | `tests/`, `docs/BUGS.md` (correções pontuais em qualquer arquivo) | na fila |
| 2 | Visor do Tempo | Acertar a mecânica do Q e dos discos conforme o retorno de quem jogou | `world/visor.gd`, `world/epocas.gd`, `ui/faixa_discos.gd`, `ui/olho_atencao.gd` | na fila |
| 3 | Visitas 1 a 4 | Ritmo ("mais lento até ficar bizarro"), sustos, painéis, flashback da Barra | `world/niveis/castelinho.gd`, `ato2.gd`, `barra.gd`, `data/paineis.json` | na fila |
| 4 | Porão | A masmorra (salas 81 a 99) | `world/niveis/porao*.gd`, `shaders/porao_*` | na fila |
| 5 | Braço Morto e final | Sala 100, Tito, finais, dedicatória | `world/niveis/braco_morto.gd`, `castelinho/tito.gd`, `ui/dedicatoria.gd`, `ui/volte_sempre.gd`, `ui/telefone.gd` | na fila |
| 6 | Áudio | Jingle, ambientes e sustos (ninguém ouviu ainda: precisa do ouvido do Icaro) | `autoload/audio.gd`, `tools/gerar_audio.py`, `assets/audio/` | na fila |
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

### Módulo 0: Fundação (07/10/2026)

- Versão 2 publicada: 4 visitas, Visor 2.0, porão e Braço Morto. 8 suítes de teste verdes.
- **O Icaro ainda não deu retorno da versão 2** (ritmo, Visor, porão, bugs, áudio). O módulo 1 começa perguntando isso.
- Zip do Windows agora é só sob pedido (ver `CLAUDE.md`, Git e publicação).
- Pendências antigas: revisar o tom dos painéis P14, P15, P16, P19, P21 e P23, que não tinham tema no roteiro
  (`docs/PENDENCIAS.md`), e reconfirmar a data da primeira ponte (1934) e o "~16 mil para ~80 mil" do P12.
