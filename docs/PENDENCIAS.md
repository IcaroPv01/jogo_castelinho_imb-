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

## Agente Visor/UI (V2)

Arquivos meus (V2 §8.3): `world/visor.gd`, `autoload/{efeitos,guia,audio}.gd`, `ui/**`, `world/painel_3d.gd`, `data/**`, `assets/ui/**`, `assets/audio/**`, `tools/{gerar_audio,gerar_desenhos}.py`, `tests/{ui,visor}_test.gd`, `tests/captura_ui.gd`.

### Andamento (checklist; atualizado a cada etapa)

- [x] 1. Áudio novo (`tools/gerar_audio.py`): chuva, goteira (loops ogg), agua_sobe, crianca_ei, telefone_voz, atencao (wav). Gerados e importados.
- [x] 2. Arte gerada (`tools/gerar_desenhos.py`): desenho_1..7 (512x512), procura_se (512x720, com alfa), marcas_altura (384x512, opaca). PNG em paleta de 256 cores (~1,5 MB no total). Vistos e iterados.
- [x] 3. Painéis: `pNN_v2/_v3/_v4` (p01..p22), fallback `pNN_vK` -> `pNN` (`PainelUI.id_efetivo/dados`), entradas de imagem (`desenho_N`, `procura_se`, `marcas_altura`), P14/15/16/19/21/23 revisados.
- [x] 4. Visor 2.0 escrito (`world/visor.gd`): discos 1-5 e rolagem, Q por disco, atenção, Figura no slide, susto, bloqueio de 10 s, `figura_atravessou`. FALTA testar (item 7).
- [x] 5. HUD: "VISITA n · SALA nn" (porão: "SALA nn"), `ui/faixa_discos.gd`, `ui/olho_atencao.gd`. Ajustes de captura pendentes (ver "A fazer").
- [x] 6. Telas escritas: `ui/volte_sempre.gd`, `ui/telefone.gd`, `ui/dedicatoria.gd`. Capturadas; ajustes pendentes (ver "A fazer").
- [x] 7. Testes: `tests/visor_test.gd` (novo, 100% ok) e `tests/ui_test.gd` (sons novos + telas V2) passam. `bash tools/testar.sh`: meus testes, ato2, barra e smoke OK, sem "SCRIPT ERROR". Falhas que NÃO são minhas (domínio Visitas, anotadas): `castelinho_test` (V1 marcas de altura, V4 porta zebrada = sala 71 em vez de 80, draw calls > 150 nos pontos (-9.8,-18.8) e (-10.4,-12.6)) e `qa_logica_test` (checkpoints 6/11/21/25/26 caem em `Spawn`, corrupção do fim da demo); vêm de `entrar_sala`/`preparar_continuar` e do nível em reescrita.
- [x] 8. Capturas de UI vistas (build/capturas/*, não versionada): painéis v2/v3/v4, desenhos, placas 3D, volte sempre (1ª e 2ª), telefone, créditos, dedicatória, HUD, Visor com a Figura.

### Feito depois das capturas
- FaixaDiscos posicionada pelo tamanho da janela (sem anchors); estrelas do VolteSempre atrás da placa; créditos centralizados; olho maior.

### Para o integrador
- `docs/CREDITS.md`: acrescentar `tools/gerar_desenhos.py` (arte do Tito, cartaz e marcas, tudo por código) e os sons novos (todos sintetizados).
- Quem chama: `GameState.comecar_visita(n+1); await VolteSempre.mostrar().terminou`; `await Telefone.tocar([...]).terminou` (2º argumento false pula o toque); `await Dedicatoria.mostrar().terminou` (ou `mostrar(true)` recarrega a cena principal sozinha).
- Importante: rode `godot --headless --import` ao integrar para gerar os `.import` dos PNG/WAV novos.
- `Visor.figura_atravessou(visita)` (instância): o nível do porão (e da visita 4) liga com `Visor.instalar(self).figura_atravessou.connect(...)`.

### Decisões
- `Visor` é de instância; sinal de instância `figura_atravessou(visita)` nas visitas 4 e 5 (documentado no cabeçalho de `world/visor.gd`). `atencao_cheia(visita)` sai sempre.
- Q sem disco não faz nada; exceção de compatibilidade com os níveis do MVP: sem NENHUM disco e com a flag `epoca_visor` definida, o Q usa essa época. Com discos, `epoca_visor` é ignorada.
- Tecla n escolhe o disco fixo (1=1950, 2=1967, 3=1975, 4=2019, 5=sem data); rolagem passa entre os discos que o jogador tem.
- Bloqueio de 10 s é estático (atravessa troca de nível); zera em `Visor._ready` se `sala_atual <= 0`.
- A Figura do slide é um visual próprio (`Visor.FiguraSlide`), sem IA e fora do grupo "figura_branca": o `FiguraBranca` real mata por proximidade.
- Assinatura do Tito: o primeiro T é desenhado de cabeça para baixo (um T espelhado na horizontal seria igual ao normal).
- Desenhos/cartaz em Painel3D: `Painel3D.new("desenho_3")` é uma folha na parede (largura `largura_m` do JSON); `marcas_altura.png` é opaca (batente de porta + parede), pensada para o Visitas colar na parede de 1975.
- Painéis v4: `anfitriao` vazio, `riscado`, `desenho`; v3 tem `carimbo` "EM REVISÃO". v2/v3/v4 não têm quiz (selos só na visita 1).
- Pedido ao integrador: `Visor.registrar_inputs()` cria as ações disco_1..5/prox/ant; HUD instancia FaixaDiscos e OlhoAtencao. Telefone/VolteSempre/Dedicatoria sem .tscn (só `class_name` + `new()`).

## Agente Porão (V2)

> Seção viva: atualizada à medida que avanço. Se eu for interrompido, quem continuar começa pelo "Estado" abaixo.

### Estado (atualizado a cada etapa)
- [x] 1. Renumerar `ato2` (salas 55 a 60, `Checkpoint_55`, flag `v3_ato2_feito`, volta em `Spawn_volta_ato2`) e `barra` (`sala_global(14)/(15)`, sandália) + `ato2_test`/`barra_test` (passam)
- [x] 2. `porao.tscn`/`porao.gd` + `porao_salas.gd` (12 tipos + quarto + escada que sobe) + `porao_quarto.gd` (quarto do Tito e slides) + shaders `porao_pedra`/`porao_agua`: carregam, capturas conferidas (draw calls 20 a 50, 4 luzes)
- [x] 3. Criaturas: `creatures/costela.gd` (prende parado, solta andando, mata se não lutar), voz do Tito com marcas do Visor, Figura Branca ligada ao `figura_atravessou` (testados em `porao_test`)
- [x] 4. `braco_morto.tscn`/`.gd`: margem do lago, lápide de areia, Tito pelo Visor, finais "Encontrado"/"Visita concluída", `Dedicatoria.mostrar()` (testado)
- [x] 5. `tests/porao_test.gd` passa (~47 s). `bash tools/testar.sh`: ato2, barra, porao, qa_logica, smoke, ui e visor passam; `castelinho_test` falha em "V4: porta zebrada do hall = sala 80" (é do Visitas, ainda em obra)
- [x] 6. Capturas conferidas com `tests/captura_porao.gd` (salas do porão, quarto do Tito, slides 96 a 99, Costela) e `tests/captura_cam.gd` (Braço Morto: Cam_margem, Cam_lapide, Cam_pier, Cam_tito, Cam_escada)

Limites conhecidos: áudio nunca foi ouvido (sons "crianca_ei", "agua_sobe", "goteira" existem, vindos do Visor/UI); desempenho no navegador não medido (só draw calls/luzes em Mesa);
a passarela da sala 98 (época sem data) e a sandália são a "passagem" do disco sem data; o resto das pistas usa 1967 (voz, pegadas, mão, desenho escondido) e 1975 (marcas de altura).

## Agente Visitas (V2)

> Seção viva (atualizada à medida que avanço). Se eu for interrompido, quem continuar começa pelo "Estado".
> Meus arquivos: `castelinho/**`, `world/niveis/castelinho.*`, `assets/textures/**`, `tools/gerar_texturas.py`,
> `tests/{castelinho,qa_logica}_test.gd`, `tests/janela_jogador.gd`, `GameState.entrar_sala` e `preparar_continuar`.

### Estado
- [x] 1. `game_state.gd`: regra de checkpoint (`SALAS_CHECKPOINT`) e `preparar_continuar` (visitas, Ato II, porão, Braço Morto)
- [x] 2. E1967 (obra) gerada: `castelinho/obra.gd`, Tito e desenhos em `castelinho/tito.gd`
- [x] 3. Nível `world/niveis/castelinho.gd` em 4 visitas (iluminação, clima, eventos, painéis, discos, loop). Falta só conferir posições por captura (porta do Ato II, painel solto)
- [x] 4. Testes: `castelinho_test`, `qa_logica_test` e `janela_jogador` atualizados e passando (4 visitas, loop, E1967, Continuar por checkpoint). `bash tools/testar.sh`: tudo OK e sem SCRIPT ERROR, exceto `porao_test` (do agente Porão, em andamento). Dica: outro agente mata processos `godot` com `pkill`; rode os testes com um symlink (`ln -s $(which godot) /tmp/gdv; bash tools/testar.sh /tmp/gdv`)
- [x] 5. Capturas de cada visita e da E1967 conferidas (build/capturas/v2/); LEIAME do Castelinho atualizado

### Contratos que o Visitas assume (por favor, confirmem ou avisem)
- **Checkpoints (números globais):** 1, 10, 16 | 23, 32, 38 | 45, 54, 61 | 67, 72, 77 | porão 81 e 95. O nível cria os marcadores
  `Checkpoint_<base>` (bases 1, 8, 10, 13, 16, 17) **e** `Checkpoint_<global>` da visita atual (a morte em `main.gd`
  usa `"Checkpoint_%d" % checkpoint_sala`).
- **Ato II (para o Porão):** ao abrir a porta da visita 3 (base 11 = sala 55) o Castelinho grava `checkpoint_sala = 55` e vai para
  `ato2.tscn` "Spawn". O "Continuar" com checkpoint 55 devolve `["res://world/niveis/ato2.tscn", "Checkpoint_55"]`: o `ato2`
  precisa ter um marcador **`Checkpoint_55`** (pode ser igual ao `Spawn`). A volta é em **`Spawn_volta_ato2`** (topo da Torre A).
  Ao voltar, o `ato2` deve ligar a flag **`v3_ato2_feito`** (`GameState.set_flag("v3_ato2_feito", true)`): sem ela o
  Castelinho mantém a escada da visita 3 interditada. O Castelinho também liga essa flag ao receber o jogador em `Spawn_volta_ato2`.
- **Porão:** marcadores `Checkpoint_81` (entrada, `Spawn` também) e `Checkpoint_95` (quarto do Tito). Braço Morto: `Spawn`.
  Entrada no porão a partir do Castelinho: `Transicao.ir_para("res://world/niveis/porao.tscn", "Spawn")` (porta do hall na visita 4
  = sala 80; escada da Sala Medieval só em 2019).
- **Barra:** o mural leva a `barra.tscn` "Spawn" só na visita 2 (sala 36). A volta é em `Spawn_volta_barra` (sala 37).
- **Visor/UI:** (a) o Castelinho **não** grava mais `epoca_visor`; quem manda é o disco selecionado. (b) O Castelinho chama
  `GameState.ganhar_disco(E1950|E1967|E1975|E2019)`. (c) Diploma da visita 2: o Castelinho liga a flag `diploma_nome = "TITO"`
  antes de `Diploma.mostrar()` (e tenta `set("nome", "TITO")` no nó): peço que `ui/diploma.gd` leia a flag. (d) O Castelinho usa
  `VolteSempre.mostrar()` e `Telefone.tocar(linhas)` se as classes existirem (procura em `ProjectSettings` as classes globais);
  senão cai em um fade com Label e em `Guia.falar("???", ...)`. (e) Texturas: usa `assets/ui/tito/{desenho_1..7,procura_se,marcas_altura}.png`
  quando existirem; senão, placeholders gerados em `castelinho/tito.gd` (mesmo estilo).
- **Painéis por visita:** o nível pede `pNN_vK` (K = visita); se o id não existe em `data/paineis.json` usa `pNN`. Na visita 4 usa
  `desenho_N` (N = 3..6 conforme a sala). `quiz_final` só existe nas visitas 1 e 2.

### Decisões e contratos do Porão (para o Visitas, o Visor/UI e o integrador)

**Arquivos meus:** `world/niveis/{ato2,barra,porao,porao_salas,porao_quarto,braco_morto}.gd` (+ `.tscn`), `creatures/costela.gd`,
`shaders/porao_pedra.gdshader`, `shaders/porao_agua.gdshader`, `tests/{ato2,barra,porao}_test.gd`, `tests/captura_porao.gd`.
`porao_salas.gd`/`porao_quarto.gd` usam `Malha` e `Muros` de `castelinho/` (só leitura: se a API deles mudar, avisem).

**Checkpoints do porão (formato).** `ponto_spawn("Checkpoint_<N>")` aceita qualquer N de 81 a 99: monta a sala N e devolve o marcador (o Main cai
nele quando `find_child` não acha). Para a morte, o porão guarda `ultimo_checkpoint` entre 81, 86, 91, 95 e 96 (volta ao começo daquela sala, com a
água daquele bloco). O `GameState.SALAS_CHECKPOINT` (do Visitas) só grava 81 e 95; **pedido ao Visitas**: se quiserem que o "Continuar" também volte a
86, 91 e 96, acrescentem 86, 91, 96 em `SALAS_CHECKPOINT` e façam `preparar_continuar` devolver `["res://world/niveis/porao.tscn", "Checkpoint_%d" % cp]`
para cp de 81 a 99 (os marcadores existem sob demanda). Sala 100: `["res://world/niveis/braco_morto.tscn", "Spawn"]` (existe).
`ato2.tscn` tem `Spawn`, `Checkpoint_55` (e o apelido antigo `Checkpoint_26`), liga `v3_ato2_feito` na volta e volta em `Spawn_volta_ato2`.

**Semente:** `GameState.flags["porao_semente"]` (int sorteado no 1º acesso; `novo_jogo()` apaga e sorteia outro).

**Contadores e flags que o final lê/escreve:** lê `contadores["pistas_tito"]` (>= `BracoMorto.PISTAS_ENCONTRADO` = 6 dá o final "Encontrado"; senão
"Visita concluída"). Convenção para QUALQUER agente que ache uma pista com o Visor: `if not GameState.flag("pista_<id>"): GameState.set_flag("pista_<id>", true);
GameState.somar("pistas_tito")` (uma vez por pista). O porão registra: `desenho_porao`, `marcas_porao`, `pegadas_porao`, `mao_poco`, `telefone`,
`quarto_tito` (pegar o disco) e `sandalia_porao`; a lápide registra `lapide`. Escreve ainda `viu_tito_final`, `final_encontrado`, `final_visita_concluida`,
`telefone_porao_atendido`, `tem_disco_semdata`, `viu_sandalia_barra` (Barra). **Pedido ao Visitas:** contem as pistas da visita 3 e 4 (marcas de altura/1975,
desenho atrás do painel/2019, buraco no muro/1967) com essa convenção, para o total passar de 6.

**Visor:** o porão usa `Visor.instalar(self)` e escuta `figura_atravessou` (solta a Figura de verdade atrás do jogador). As marcas da voz (facho vermelho com
balde = caminho certo; facho azul com ondas = água funda) e as pistas aparecem com `Epocas.marcar` nas épocas E1967 e ESEMDATA. No disco sem data o porão
esquenta a luz (fim de tarde) e a água para (ondas = 0).

**Orçamento web medido (captura):** 20 a 50 draw calls por vista, 4 luzes (2 por sala, sala atual e próxima; a lanterna do jogador seria a 5ª),
2 a 3 salas montadas por vez, névoa de profundidade. Água: um plano por sala com `porao_agua.gdshader` (sem refração).

**Lentidão na água:** o `player.gd` não é meu, então o nível (prioridade de física 100) encolhe o deslocamento horizontal do jogador depois que ele andou:
fator `clamp(1 - prof*0.6, 0.42, 1)` (tornozelo 0,87; joelho 0,67; cintura 0,43). Se o integrador preferir, o jogador pode ler `nivel.fator_agua()`.

**Costela:** cipós crescem em ~3,2 s de jogador parado (< 0,45 m/s), recuam rápido andando; prendem (jogador travado, câmera livre); apertar uma direção
por 0,9 s solta (imune por 1,5 s); sem lutar, em 2,6 s `matar_jogador("costela")`. Afogamento: `matar_jogador("afogamento")` (tela escurece, sem gráfico).
**Pedido ao Visor/UI:** `ui/morte.gd` pode ter textos para as causas "costela", "afogamento" e "figura_branca" (hoje mostra a mesma tela para todas).

### Decisões e notas do Visitas
- **Bug achado e corrigido (existia desde o MVP):** o painel `p08` (Sala dos Povos, tem quiz) estava a 36 cm DENTRO da parede
  (x -26,76; a face interna é x -26,4) e ninguém conseguia lê-lo. Agora em x -26,35. `castelinho_test` confere que todo painel
  visível é alcançável pelo raio do jogador (V1 e V4).
- **Numeração:** bases 23, 24 e 25 (porta de saída, Sala Medieval em 1975, corredor de 1975) contam como a base 22: a sala
  global 23/45/67 já é a primeira da visita seguinte. Visita 4 comprime as bases em 67..79 (`V4_SALAS`); a 80 é a porta zebrada
  do hall, que só conta depois da Sala Medieval (78) ter sido vista. Os gatilhos chamam `_entrou(base)` do nível
  (`GatilhoCastelinho`), não `entrar_sala_base` direto.
- **Visita 3 e o Ato II:** a escada para a laje fica interditada (fita zebrada + colisão) até o Ato II ser concluído (flag
  `v3_ato2_feito`, ligada ao nascer em `Spawn_volta_ato2` ou ao entrar na sala 17). O disco 1975 fica num pedestal no topo da Torre A.
  A porta nova para 1950 fica na parede oeste do Salão de Arte (x -12,1; z -18). Ela grava `checkpoint_sala = 55` antes de ir ao `ato2`.
- **Fim da visita 3:** o Visor com o disco 1975 mostra a saída aberta (o vão da Sala Medieval em 1975 leva ao corredor); o gatilho
  do corredor trava o Visor em 1975 e a porta do fundo chama `comecar_visita(4)` sem placa "Volte sempre".
- **Visita 4:** porta zebrada no hall (parede da pilastra, x -14,0) e escada da Sala Medieval (só em 2019, x -14; z -26,8) descem para
  `porao.tscn` "Spawn" com `comecar_visita(5)`. Painéis mostram `desenho_3..6` (se existirem em `data/paineis.json`).
- **Pistas do Tito** (para o final "Encontrado"): flags `pista_buraco` (muro de 1967), `pista_desenho_2019` (atrás do painel solto) e
  contador `pistas_tito`; as marcas de altura (1975) são só visuais por enquanto (sem Interagivel).
- **Tito no Visor (visitas 3 e 4):** boneco `TitoNoVisor`, visível só nas épocas fora do presente, a cada sala mais perto (`_spot_tito_visor`).
- **Pendências para outros agentes:** (Visor/UI) `ui/diploma.gd` ler a flag `diploma_nome` ("TITO" na visita 2); (Porão) ligar
  `v3_ato2_feito` no `ato2` ao sair é opcional (o Castelinho já liga); marcador `Spawn_volta_ato2` existe em y = 6,9.
- Os níveis do Castelinho mexem em `Efeitos.flash`, `Guia.falar_engasgado`, `Audio.ambiente("chuva"|"vento"|"mar")` e `sfx_3d("goteira")`.

### Fechamento do Visitas (rodada 2)
- **Sala 80 (porta zebrada):** o gatilho 80 fica dentro do gatilho 7 (hall); se os dois disparavam no mesmo quadro a ordem era arbitrária e o contador podia cair para 71 (falha intermitente). Agora `_entrou(7)` na visita 4 reaplica a sala 80 se o jogador está na zona da porta.
- **Checkpoints do porão:** `SALAS_CHECKPOINT` ganhou 86, 91 e 96; `preparar_continuar` devolve `Checkpoint_<maior de 81/86/91/95/96 <= cp>` em `porao.tscn`. `qa_logica_test` cobre os cinco.
- **Pistas (`pistas_tito`)**, convenção `pista_<id>` + `somar`, uma vez cada, todas com E em cima do objeto: `buraco` e `tito_1967` (só em 1967), `marcas_altura` (só em 1975), `desenho_2`, `desenho_3`, `desenho_4`, `cartaz`, `desenho_2019` (só em 2019) = 8 no Castelinho; só andar não conta. `castelinho_test` confere.

## Revisão de arte e experiência da V2 (diretor de arte técnico)

Relatório completo em `docs/REVISAO_V2.md` (capturas em `build/capturas/revisao_v2/`, não versionada). Nenhuma API
pública, marcador, id de painel ou regra de criatura mudou. Para cada divisão:

- **Integrador:** `player/player.gd`: lanterna com cone/queda novos e estado que sobrevive à troca de cena (flag de save
  `lanterna_desligada`, gravada ao apertar F). `tests/captura_cam.gd` (jogador acompanha a câmera, `RELAMPAGO=`) e
  `tests/captura_porao.gd` (com lanterna).
- **Visitas:** `world/niveis/castelinho.gd`: luz por visita (`LAMPADAS`, `COR_LAMPADA`, `PRESENTE` 3 e 4), luz da rua
  (`COR_POSTE`, `_montar_luz_da_rua`), janelas acesas na V3, relâmpagos na V4, apagão da V2 com sussurro e luz falhando,
  discos que giram e piscam, escada virtual na porta zebrada e no alçapão de 2019 (`_escada_falsa`), câmeras
  `Cam_calcada` (nova) e `Cam_porta_porao` (movida). `castelinho/castelinho.gd` (`mat_vidro`), `entorno.gd` (`POSTES`),
  `mobilia.gd` (cavaletes do hall 0,5 m a leste: cobriam a porta zebrada), `obra.gd` (andaime, buraco, barco, canteiro),
  `tito.gd` (cartaz A3).
- **Porão:** `porao_salas.gd` (chamas coloridas, `chama`), `braco_morto.gd` (poças aditivas, margem de lá com reflexos,
  lápide de balde, `Cam_escada`). Shaders novos `escada_falsa` e `reflexo_agua`.
- **Visor/UI:** `world/visor.gd` (a Figura do slide para a 2,6 m e se debruça), `ui/telefone.gd` (plaquinha de ligação),
  `ui/volte_sempre.gd` (texto que cabe), `autoload/audio.gd` + `tools/gerar_audio.py` (som `trovao`).
- **A conferir no navegador:** a visita 4 (porta zebrada, alçapão, relâmpago) e o Braço Morto (reflexos). Só o começo da
  visita 1 passou pelo `testar_web.py`.
