# Pendências e pedidos entre agentes

## Agente UI e conteúdo

### Para o integrador (arquivos fora da minha divisão)

1. **`scenes/main/main.gd`: pausa e `ui_aberta`.** Já está feito no commit `8264845` (a pausa e o recapture do mouse ignoram `GameState.flag("ui_aberta")`). Confirmei que o contrato é esse: `PainelUI`, `Diploma`, `Morte` e `FimDemo` usam `Flash.abrir_ui()` (liga a flag, solta o mouse, trava o jogador) e `Flash.fechar_ui()` (recaptura o mouse e desliga a flag). Nada a mudar.
2. **`main._on_morte`** (opcional): hoje faz só fade vermelho e recarrega. Para mostrar a tela "Ops! Você se perdeu da visita!":
   ```gdscript
   var m := Morte.mostrar(causa)   # CanvasLayer 120, acima da Transicao
   await m.terminou                # espaço/Enter/clique ou botão "Tentar de novo"
   ```
   O `ato2.gd` já instancia `ui/morte.tscn` e espera o sinal `terminou`, então funciona sem mudança.
3. **`GameState`**: nada novo. A UI só usa `set_flag`, `flag`, `somar("paineis_lidos"|"quiz_acertos")`, `ganhar_selo`, `selos`, `contadores`, `tem_save()` e `corruption`/`corruption_mudou`.
4. **`build/.gdignore`**: o Godot importava as capturas de tela em `build/capturas/` (PNGs de ~1 MB) e as colocava no `.pck` (ficou com 24 MB só no meu ambiente). Criei `build/.gdignore` (a pasta `build/` não é versionada, então só vale localmente; no CI não existe `build/`).
5. **`ui/hud.gd`** (só visual): fontes Baloo/Comic Neue com contorno azul-marinho e, com corruption > 0.35, o contador "SALA nn" mostra por um instante um número errado (interface que mente sobre o progresso).
6. **`tools/testar_web.py`** clica no centro da tela (640, 360) para começar. Na nova tela de título o botão "Começar a visita" fica em ~(985, 560-600); sem save, apertar **Enter** também começa (e o clique precisa ser no botão). Ajuste o script (ou use `pg.keyboard.press("Enter")`).
7. **Sons que outros arquivos pedem e agora existem**: `slide` (Visor do Tempo), `sussurro` (Figura Branca), `splash` e `tarrafa` (flashback da Barra). Qualquer nome desconhecido só gera um aviso no console (uma vez) e não quebra.

### Para o agente do Castelinho (como usar o que fiz)

- **Painéis**: `var p := Painel3D.new("p01")`, `p.position = ...`, `p.rotation_degrees.y = ...`, `add_child(p)`, `p.lido.connect(func(id): ...)`. A frente da placa é o +Z local. Tamanho 1,6 x 1,1 m, centro na origem (use y ≈ 1,4 numa parede).
- **Qual id em qual sala**: sala N usa `"pNN"` de 01 a 21 (sala 22 = `"quiz_final"`, `"p22"` é alias), sala 23 = `"p23"`, 24 = `"p24"`, 25 = `"p25"`, sala 26 = `"p07_corrompido"`. Quizzes (com selo) nos painéis `p02`, `p05`, `p08` e no `quiz_final` (3 perguntas). Total de selos: 6 (`Flash.TOTAL_SELOS`).
- **Painel sem objeto 3D**: `var ui := PainelUI.mostrar("p10"); await ui.fechado`.
- **Diploma (sala 22)**, depois de `lido` do `quiz_final`: `var d := Diploma.mostrar(); await d.fechado`.
- **Fim da demo**: `FimDemo.mostrar()` (o `ato2.gd` já instancia `ui/fim_demo.tscn` sozinho; o botão "Voltar ao início" limpa a Transicao e recarrega a cena principal).
- **Fala**: `await Guia.falar("bentinho", ["..."])` (não trava), `await Guia.falar("taina", [...], true)` (trava), **`await Guia.falar_engasgado("bentinho", [...])` na sala 11**. Personagens: `bentinho`, `taina`, `quico`, `sistema`, `???`. `Guia.avancar()` e `Guia.cancelar()` existem para testes e trocas de nível.
- **Áudio**: o nível deve chamar `Audio.musica("jingle")` ao começar (o jingle troca sozinho para as versões 1 e 2 conforme `GameState.corruption`; `Audio.musica("")` silencia). Ambiente: `Audio.ambiente("vento")`, `"mar"`, `"rio"`. Efeitos: `Audio.sfx("telefone")`, `sfx_3d("apito", pos)`, etc. (lista no cabeçalho de `autoload/audio.gd`).
- **Testes**: scripts que citam autoloads só compilam depois que os autoloads existem; num teste `extends SceneTree`, carregue classes como `PainelUI`/`Painel3D`/`Flash` com `load("res://...")` em runtime (ver `tests/ui_test.gd`).

### Conteúdo e dúvidas

- Os painéis **P14, P15, P16, P19, P21 e P23** não tinham tema no roteiro (só P01-P13, P17, P18, P20, P24, P25). Escrevi textos próprios, sempre com fato com fonte em `historia_imbe.md`/`castelinho.md`; vale uma revisão de tom.
- **P09** diz "muitos navios visitaram nossa costa!" (eufemismo para os naufrágios do "Cemitério dos Navegantes") e **P05** diz que os pescadores "foram acomodados" (P24 corrige para "removidos"), como no roteiro.
- Fatos que **não** consegui reconfirmar online nesta rodada (as fontes bloquearam o acesso): a data exata da primeira ponte (1934) e o "~16 mil para ~80 mil" de P12. Ambos vêm de `historia_imbe.md` com a ressalva de lá.
- **Áudio nunca foi ouvido** (a nuvem não tem placa de som): os sons foram conferidos só por espectrograma e níveis. Ouça o jingle e os efeitos no navegador; ajustes finos de volume ficam em `VOLUME_PADRAO` (`autoload/audio.gd`) e de timbre em `tools/gerar_audio.py` (rode `python3 tools/gerar_audio.py` e depois `godot --headless --import`).
- Regenerar arte e tema: `python3 tools/gerar_mascotes.py` (SVGs) e `godot --headless -s res://tools/gerar_tema.gd` (grava `ui/tema_flash.tres`).

## Agente Efeitos e Ato II

### APIs novas (para o agente do Castelinho e o integrador)

- **`Efeitos`** (autoload, CanvasLayer **camada 5**, abaixo do HUD 10, da UI 20/120 e da Transicao 100):
  - Pós-processamento ligado a `GameState.corruption` (interpolado suavemente). Em corruption 0 (e sem pulso/visor) a camada some e a imagem fica **intacta**. Sobe: pixelização leve, dithering/menos cores, dessaturação, vinheta, grão, aberração cromática; acima de ~0.5, faixas de glitch.
  - `Efeitos.pulso(intensidade, dur)` (susto), `Efeitos.visor(ativo)` (moldura do Visor: plástico vermelho, dois olhos redondos, sépia, legenda do ano, clarão e `Audio.sfx("slide")`).
  - Extras: `Efeitos.legenda_visor("Em 1950, aqui era só areia!")` (frase sob o ano; apague com `""`), `Efeitos.flash(dur, cor, forca)`, `Efeitos.material_psx(cor, textura)` (ShaderMaterial com vertex snapping que piora com a corruption; opcional).
- **`Visor`** (`world/visor.gd`, `class_name Visor`): lógica do Visor do Tempo. **Cada nível que quiser o Visor chama `Visor.instalar(self)`** (idempotente, reaproveita o que já existir). Com `GameState.flag("tem_visor")`: segurar Q troca para `flag("epoca_visor", E1950)` + `Efeitos.visor(true)`; soltar volta para E2020, exceto se `visor_travado`. O nível é quem define a época inicial em `iniciar()` (o Visor não restaura a época ao ser destruído). Não dá para registrar como autoload com o nome `Visor` (conflita com o `class_name`); se o integrador preferir autoload, use outro nome, p.ex. `VisorTempo`, e remova o `instalar` dos níveis (o grupo `visor_tempo` evita duplicar).
- **`FiguraBranca`** (`creatures/figura_branca.gd`, CharacterBody3D, camada 4 = valor 8, colide só com o mundo): `var f := FiguraBranca.new(); f.velocidade = 2.2; f.pontos_reaparecer = [Vector3(...)]; nivel.add_child(f); f.global_position = ...`. Parâmetros: `ativa` (false = parada, só some se cercada), `angulo_visao` (35), `distancia_cercar` (2,5), `distancia_toque` (0,9), `tempo_reaparecer`, `distancia_reaparecer`, `pontos_reaparecer`, `reaparecer_fn` (Callable), `pontos_caminho` (portas, para contornar paredes), `escuro` (apagão: conta como não olhada), `usar_navegacao` (usa NavigationAgent3D só se o nível tiver navmesh). Métodos: `ativar()`, `teleportar(pos)`, `reiniciar(pos, ativa)`, `esconder()`, `esta_sendo_olhada()`. Sinais: `sumiu`, `reapareceu`, `matou_jogador`. Mata com `GameState.matar_jogador("figura_branca")`.
- **Níveis**: `world/niveis/ato2.tscn` (marcadores `Spawn`, `Checkpoint_26`, câmeras `Cam_26..Cam_30`) e `world/niveis/barra.tscn` (marcador `Spawn`). Entradas: Ato I sala 14 chama `await Transicao.ir_para("res://world/niveis/barra.tscn")`; a Barra volta para `res://world/niveis/castelinho.tscn` em **`Spawn_volta_barra`** (sala 15) e liga a flag `viu_flashback_barra`. Fim do Ato I (sala 25) chama `Transicao.ir_para("res://world/niveis/ato2.tscn")`. Se `castelinho.tscn` ainda não existir, a Barra cai no nível de teste (aviso no console).
- **Morte no Ato II**: `ao_morrer()` do nível usa `Morte.mostrar(...)` (UI) e volta ao `Checkpoint_26` **sem recarregar a cena**. **Fim da demo (sala 30)**: tela preta própria (camada 15, abaixo do Guia), `Guia.falar_engasgado("bentinho", ...)` e `FimDemo.mostrar()`.
- **Estado que o Ato II mexe** (para o integrador saber): `epoca` (E2020 no hall, E1950 depois da porta), flags `visor_travado` e `epoca_visor`, `entrar_sala(26..30)`, `Audio.musica("")` ao entrar nas dunas (o jingle para: só vento). `iniciar()` do Ato II zera a época e a trava; a Barra usa `definir_corruption_manual(0.1..0.5)` e **devolve a curva (`-1`) ao sair**.

### Arquivos fora da minha lista em MVP_ROTEIRO §4
- `world/niveis/ato2_pecas.gd` (`class_name Ato2Pecas`): texturas procedurais, arco abatido, empena, terreno de dunas. É usado também pela Barra. As texturas do castelinho (`parede_castelinho`, `piso_pedra`, `areia_1950`, `fibrocimento`) são usadas automaticamente se estiverem importadas; senão há versões procedurais.
- `tests/ato2_test.gd` e `tests/barra_test.gd` (pedidos no briefing). Eles aceleram o tempo (`Engine.time_scale = 4`); a bateria inteira leva ~55 s.
- Apaguei por engano os PNGs de `build/capturas/` (pasta não versionada) ao refazer minhas capturas; os `.import` ficaram.

### Para o integrador (opcional)
1. `GameState.set_flag(...)` grava o save a cada chamada; o Visor e o Ato II chamam pouco, mas se isso pesar no navegador vale agrupar.
2. `main._on_morte` não precisa de mudança: o Ato II implementa `ao_morrer()`. O Castelinho pode fazer o mesmo.
3. Aviso de teste: arquivos `extends SceneTree` não podem citar `Visor`, `FiguraBranca`, `Ato2Pecas`... por nome (compilam antes dos autoloads); use `load("res://...")` em runtime, como em `tests/ato2_test.gd`.

### Decisões e limites
- A Figura Branca anda em linha reta com desvio de paredes e pontos de passagem; o Ato II não gera navmesh. No corredor reto da arcada isso basta. Quem preferir navmesh liga `usar_navegacao`.
- Na arcada a regra "olhar para trás" pode ser burlada andando de costas olhando para ela; o contraponto são os **apagões** (a cada 6-10 s, 0,45 s no escuro, ela avança sem ser vista). Ajuste em `VEL_FIGURA_ARCADA` e `_apagao()` no `ato2.gd`.
- Áudio e desempenho no navegador **não foram testados** (só captura em Mesa/llvmpipe e testes headless). O pós-processamento custa uma cópia da tela por quadro só quando corruption > 0.

## Agente Castelinho

### O que entrou
- `castelinho/` (gerador paramétrico, `LEIAME.md` com planta, correções pelas fotos e como regenerar), `world/niveis/castelinho.tscn/.gd` (salas 1 a 25), `assets/textures/` (22 PNGs de `tools/gerar_texturas.py`), `tests/castelinho_test.gd`, `tests/captura_cam.gd` (ferramenta de captura por câmeras `Cam_*`, serve aos outros níveis também).
- Marcadores: `Spawn`, `Checkpoint_1/6/11/16/21/25`, `Spawn_volta_barra`. Câmeras `Cam_*` listadas no `LEIAME.md`.
- Integra: `Visor.instalar(self)` em `iniciar()`, `Painel3D.new("pNN")`, `Diploma.mostrar()`, `Audio.musica("jingle")`, `Audio.ambiente("vento")` em 1950, `Guia.falar`, `Transicao.ir_para` para `barra.tscn` (mural) e `ato2.tscn` (porta de saída, protegida por `ResourceLoader.exists`).

### Para o integrador
1. **Exportação web**: `castelinho/medidas.json` não entra no pacote (só `data/*.json`). Não é urgente: `castelinho/medidas_embutidas.gd` (gerado por `tools/gerar_medidas_embutidas.py`) é o plano B e o teste confere que os dois são iguais. Se editar o JSON, rode o gerador. Opcional: `include_filter="data/*.json, castelinho/*.json"` em `export_presets.cfg`.
2. A sala 25 grava `GameState.checkpoint_sala` = 25 por código ao ligar `visor_travado` (e entra em E1975). Se `GameState` ganhar um método próprio de checkpoint, vale trocar.
3. **Peso dos painéis**: cada `Painel3D` tem ~12 superfícies. No nível, os descendentes recebem `visibility_range_end` (13 m fora, 9 m dentro), então só os mais próximos contam. Medido com `captura_cam.gd`: 70 a 150 draw calls por vista (~20 mil triângulos). Se o `Painel3D` ganhar um parâmetro de alcance, dá para tirar essa gambiarra de `_limitar_alcance`.
4. **Colisão elevada em 1950**: lajes, terraços e parapetos continuam sólidos (invisíveis) em todas as épocas; assim, quem segura Q no topo da torre flutua sobre a areia em vez de cair. As paredes do térreo e o mobiliário somem de verdade. Se o Ato II quiser o mesmo efeito, o grupo é `col_sempre` em `castelinho.gd`.
5. Texturas reaproveitáveis pelo Ato II/Barra: `areia_1950`, `parede_castelinho`, `piso_pedra`, `fibrocimento`, `grama`, `asfalto`.

### Limites conhecidos
- Fotos só cobrem fachadas sul e leste; norte, oeste, telhados por dentro e escadas das torres são invenção plausível (documentado).
- Pinheiros em 3 variantes de `MultiMeshInstance3D` (tronco nu e copa em tufos, revisão gráfica); sem sombras dinâmicas (web), só sombras pintadas no chão; letreiro em fonte serifada comum, sem brasão da prefeitura.
- Decalques em parede interna precisam de >= 3 cm de folga (1 a 2 cm somem por profundidade).
- Em 1950, soltar Q com a cápsula dentro de onde uma parede reaparece prende o jogador por instantes; ele se desprende sozinho.
- Desempenho no navegador e áudio não foram testados (só Mesa/llvmpipe e testes headless).

## Revisão gráfica (diretor de arte técnico)

Relatório completo em `docs/REVISAO_GRAFICA.md`. Arquivos de outras divisões que mudaram, sem mudar nenhuma API pública:

- **`world/painel_3d.gd`** (UI): ganhou a propriedade opcional `alcance`. Se for maior que 0, aplica
  `visibility_range_end` a todas as peças a cada reconstrução por corruption. As 6 a 7 caixas da moldura viraram uma
  malha só (`shaders/placa_cor.gdshader`), com resultado idêntico pixel a pixel. Motivo: com corruption > 0 o Ato I
  passava de 300 draw calls.
- **`world/niveis/ato2.gd`** (Efeitos):
  - `_limitar_alcances()`: alcance só de renderização. A casa aparece a 70 m; a arcada, a porta final e a Sala
    Medieval, a 46 m. O hall caiu de 249 para 84 draw calls.
  - O hall da sala 26 usa os blocos internos do Castelinho (`parede_interna`) e o núcleo usa `parede_nucleo`.
  - Os presets "dunas" e "hall_aberto" ficaram mais escuros.
- **`ui/tela_titulo.gd`** (UI): o castelo do cenário foi redesenhado com a silhueta real (torreta esbelta, arcada de
  5 arcos, anexo ameado).
- **`tests/captura.gd`** (integrador): agora imprime draw calls e triângulos, como `captura_cam.gd`.
- **Para quem cuida da Barra:** a vista `barra_m70` tem ~69 mil triângulos, provavelmente da água ou dos molhes. Os
  prédios do horizonte (vista de costas) são caixas sem janela.
