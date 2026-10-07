# Castelinho: Visita Guiada — regras para toda sessão do Claude Code

Jogo 3D de terror em Godot 4.7.2 (GDScript, renderer Compatibility/WebGL2) sobre o Castelinho de Imbé (RS).
Começa como "jogo educativo da prefeitura" (fictícia) e vai ficando macabro: 4 visitas ao prédio (salas 1–80),
porão (81–99) e Braço Morto (100). Inspiração: *Spooky's Jump Scare Mansion*. Público: amigos do autor.

- Jogar: https://icaropv01.github.io/jogo_castelinho_imb-/ (o jogo vive principalmente por esse link)
- Planos e roteiros: `docs/PLANO.md`, `docs/V2_ROTEIRO.md` (contratos em §8). Bugs: `docs/BUGS.md`.

## Quem é o usuário

Icaro (estudante de RI, PUCRS). **Não programa.** Fale em português simples, pergunte para entender o que ele quer,
explique o que mudou e por quê, e mostre o resultado (link, captura) em vez de código.

## Como trabalhar: Opus orquestra, Sonnet e Haiku executam

Toda sessão roda no **Opus 5.5 como orquestrador**: planeja, divide, revisa e integra. O trabalho vai para subagentes:

| Modelo | Para quê |
|---|---|
| **Sonnet 5.5** (`model: "sonnet"`) | sistemas com vários arquivos, níveis, mecânicas, testes novos |
| **Haiku 5.5** (`model: "haiku"`) | tarefas leves e bem delimitadas: textos, docs, buscas, conferências. **Sempre revisar** (já errou julgamento de conteúdo) |
| **Opus** (subagente) | só revisão independente (gráfica, ética, código) |

- **Agente que parou (limite de uso, erro): retome o MESMO agente** com SendMessage. Não recomece do zero (perde trabalho e cache).
- Prompts de subagente autossuficientes e curtos; peça respostas curtas (estilo caveman).
- Commits WIP de segurança durante trabalho longo. Antes de enviar, valide numa cópia limpa (`git worktree`), nunca com
  `git stash -u` enquanto há agentes rodando (tira do disco os arquivos deles).

## Regras de conteúdo (inegociáveis)

- A prefeitura do jogo é fictícia ("Programa Municipal de Memória Interativa"); não representa a Prefeitura de Imbé.
- Nenhuma pessoa, família ou instituição real como vilã ou ligada ao sobrenatural ou a crimes. **Sem casos reais**
  (o Caso Miguel fica fora; a enchente de 2024 não vira espetáculo).
- **Tito é fictício.** Peso por sugestão, nunca violência explícita contra criança. A dedicatória final traz o Disque 100.
- Fatos históricos dos painéis precisam de fonte em `docs/pesquisa/`.
- Fotos de imprensa **nunca** no git (`docs/pesquisa/refs/` é ignorado).

## Preparar uma sessão nova

```bash
bash tools/instalar_godot.sh            # Godot 4.7.2 em /usr/local/bin/godot (use --web para os templates Web)
godot --headless --import; godot --headless --import   # o 1º import avisa "font non-existent": é só ordem, o 2º sai limpo
bash tools/testar.sh godot              # 8 suítes headless; precisa passar antes de qualquer push
```

Outros testes: `tools/testar_janela.sh` (xvfb: mouse, pausa, cliques), `tools/testar_web_cenas.sh` (build Web de teste
no Chromium; precisa de `--web`), capturas em `tests/captura*.gd`. Se um agente usa `pkill godot`, rode os testes por um
link simbólico com outro nome para não ser morto junto.

## Git e publicação

- Desenvolva só na branch designada da sessão. PR como rascunho para a `main`; CI verde é obrigatório.
- Push na `main` = site publicado (GitHub Actions → Pages), só a versão Web.
- **Zip do Windows só quando o Icaro pedir:** Actions → "Web (Godot → GitHub Pages)" → Run workflow na `main` com
  `windows` marcado. O zip sai do site na próxima publicação normal.
- **Trabalho em módulos, um de cada vez; cada sessão faz o merge do próprio PR** (CI verde). Fila, roteiro e
  passagem de bastão: `docs/MODULOS.md`.

## Mapa rápido

- `autoload/`: `game_state.gd` (contrato central: salas, visitas, corrupção, épocas, discos, save), `audio`, `guia` (falas), `transicao`, `efeitos`.
- `scenes/main/main.gd`: título, carga de níveis, aquecimento de shaders, pausa.
- `world/niveis/`: `castelinho.gd` (as 4 visitas, o maior arquivo), `ato2`, `barra` (flashback), `porao*`, `braco_morto`.
- `world/visor.gd`: Visor do Tempo (discos 1–5, Q). `castelinho/`: gerador do prédio a partir de `medidas.json`.
- `ui/`, `creatures/`, `shaders/`, `data/paineis.json` (textos dos painéis), `assets/` (tudo gerado por `tools/gerar_*.py`).
- Tudo é construído por código: `.tscn` mínimos, geometria procedural, texturas e sons gerados por script.

## Armadilhas conhecidas

- `var x := algo_que_retorna_Variant` quebra no CI: declare o tipo (`var x: bool = ...`).
- Testes `extends SceneTree` não enxergam autoloads pelo nome: use `root.get_node("GameState")` e `load()` em runtime.
- Sinal criado com `add_user_signal`: conecte com `connect("nome", ...)`.
- `_poste_painel` (castelinho.gd) só funciona com yaw múltiplo de 90°.
- Áudio nunca foi ouvido na nuvem (sem placa de som): conferido só por espectrograma.
