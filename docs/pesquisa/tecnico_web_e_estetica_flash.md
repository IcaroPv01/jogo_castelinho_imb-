# Pesquisa: Godot 4 no navegador (GitHub Pages) e a estética "jogo educativo em Flash dos anos 2000"

> Data da pesquisa: 04/10/2026. Complementa `docs/PLANO.md` (v0.2) e `docs/pesquisa/spookys_e_referencias.md`.
> **Como ler os níveis de confiança:** itens marcados **[testado]** eu executei neste container (Godot 4.7.2 real, exportação Web real, Chromium headless com WebGL2 por software). Itens **[doc]** vêm da documentação ou do código-fonte oficial do Godot 4.7.2. Itens **[não verificado]** são conhecimento geral ou memória que não consegui confirmar agora; estão marcados para você não tratar como fato. Metas de desempenho marcadas **[heurística]** são sugestão minha, não número oficial.

---

## 0. Resumo executivo

| Decisão | Recomendação | Confiança |
|---|---|---|
| Versão do Godot | **4.7.2-stable** (18/08/2026). Fixar essa versão no PC, no container e no CI. | alta [doc] |
| Renderer | **Compatibility (WebGL 2.0)** desde o M0. É o único que exporta para web. | alta [doc] |
| Threads | **Single-thread** (`variant/thread_support=false`). É o padrão e o caminho recomendado pelo Godot desde a 4.3. Dispensa COOP/COEP, então funciona no GitHub Pages sem `coi-serviceworker`. | alta [doc][testado] |
| Deploy | GitHub Actions: baixar Godot + templates por `curl` (com cache e checagem SHA-512), exportar com `--headless --export-release`, publicar com `upload-pages-artifact` + `deploy-pages`. | alta [testado localmente; o YAML em si não rodou no GitHub] |
| Dono do repositório liga à mão | *Settings → Pages → Build and deployment → Source = **GitHub Actions***. | alta [doc] |
| Repositório privado | **Pages não funciona em repositório privado no plano Free.** Ver §3.6. | alta [doc] |
| Estética PSX | O plugin `scolastico/psx_visuals_gd4` **funciona** no Compatibility/WebGL2. O `adamscott/godot-psx-style-demo` é **Godot 3** e não roda sem portar. | alta [testado] |
| Névoa | Névoa de profundidade simples (`Environment.fog_*`) funciona. **Névoa volumétrica não.** | alta [doc][testado] |

### 0.1 Como esta pesquisa se encaixa no PLANO.md (v0.2) e no que já está no repositório

O `PLANO.md` v0.2 (§7.1 e §7.1.1) **já adotou** Compatibility/WebGL2, exportação single-thread, GitHub Pages com `Source = GitHub Actions` e repositório público, e responde "Flash educativo" à pergunta do visual do Ato I. O que sobra para esta pesquisa é confirmar, corrigir e detalhar:

1. **Confirmado:** tudo isso é o caminho recomendado pela documentação oficial (§2). Nenhuma mudança de rumo.
2. **Névoa volumétrica:** o plano já a troca por névoa de profundidade. Falta só trocar também os "raios de luz" por cones falsos (malha com alfa e blend aditivo). Ver §4.2.
3. **`.gitignore`:** a versão anterior ignorava `*.import`, o que estava errado para Godot 4 (a doc oficial manda ignorar só `.godot/`; os `*.import` guardam as configurações de importação, e sem eles o CI reimporta tudo com valores padrão). **A árvore de trabalho atual já corrige isso** (removeu `*.import`, adicionou `build/`) e já traz `docs/.gdignore`, que a documentação oficial recomenda para que `docs/` (fotos incluídas) **não entre no `.pck`**. Deixo o registro porque é a causa de dois bugs silenciosos clássicos: textura PSX borrada só na versão publicada, e download inflado.
4. **`project.godot` atual usa 1280x720 com `stretch/aspect="expand"`.** Para a abertura "Flash 4:3" (§5.2), o palco 4:3 teria de ser um painel dentro da tela (moldura/pillarbox desenhado por você), não a janela inteira. Decisão de design, não limitação técnica.
5. **Pontos que o plano ainda não cobre** e que eu achei ao testar:
   - o deploy só funciona a partir do **branch padrão** por causa da proteção do ambiente `github-pages` (§3.3);
   - `Thread` **não é confiável** no export single-thread (§2.4);
   - **efeitos de bus de áudio não tocam** em modo Sample (§2.6): a "corrupção sonora" tem de ser feita com arquivos pré-renderizados;
   - **fontes do sistema não existem** na web: embutir as `.ttf` (§2.8, §5.5);
   - o jogador precisa de um **gesto** (clique) para mouse capturado, áudio e tela cheia, e o Esc solta o mouse (§2.7).
6. **Publicar na web é publicar de verdade.** O plano (§10) já trata do risco de imagem e do histórico do git antes de tornar o repositório público. Reforço: uma URL pública do Pages é a publicação.

---

# PARTE A: Técnica

## 1. Versão e exportação

### 1.1 Qual é a versão estável mais recente

Fonte: página de arquivo de downloads, godotengine.org/download/archive.

| Versão | Data | Observação |
|---|---|---|
| **4.7.2-stable** | **18/08/2026** | **Mais recente estável.** Segunda versão de manutenção da série 4.7. |
| 4.7.1-stable | 14/07/2026 | |
| 4.7-stable | 18/06/2026 | |
| 4.6.3-stable | 20/05/2026 | Manutenção da série anterior. |
| 4.8-dev7 | 29/09/2026 | Snapshot de desenvolvimento (4.8 é esperado para o 4º trimestre de 2026). **Não usar.** |

**Recomendação: 4.7.2-stable.** É versão de correção de bugs (sem mudança de API em relação a 4.7) e as imagens/ações de CI já a suportam (a imagem Docker `barichello/godot-ci:4.7.2` foi publicada em 18/08/2026). O plano pedia "4.4 ou mais nova": 4.7.2 cumpre. Quem for usar no PC precisa ter **exatamente** o mesmo 4.7.2 (menu Ajuda → Sobre), porque o formato das cenas e os UIDs mudam entre versões menores e o editor mais novo regrava arquivos.

### 1.2 URLs de download (4.7.2-stable)

Todas estas URLs responderam **HTTP 200** neste container [testado]. Os binários oficiais ficam no repositório `godotengine/godot-builds` (espelho oficial das releases) e em `downloads.godotengine.org`.

| Item | URL | Tamanho |
|---|---|---|
| Editor Linux x86_64 (serve como "headless" com `--headless`) | `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_linux.x86_64.zip` | 77,9 MB |
| Export templates (todas as plataformas) | `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/Godot_v4.7.2-stable_export_templates.tpz` | **1,28 GB** |
| Checksums SHA-512 | `https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/SHA512-SUMS.txt` | pequeno |
| Mesmos arquivos pelo site oficial | `https://downloads.godotengine.org/?version=4.7.2&flavor=stable&slug=linux.x86_64.zip&platform=linux.64` (editor) e `...&slug=export_templates.tpz&platform=templates` (templates) | |

Notas:
- **Não existe mais build "headless" separado** no Godot 4. O binário Linux normal roda sem tela com `--headless`. (O README do `firebelley/godot-export` ainda diz "Linux Headless"; para Godot 4 isso significa o binário Linux normal.)
- O `.tpz` é um zip com a pasta `templates/`. Os templates de Web ficam em `templates/web_nothreads_release.zip` e `web_nothreads_debug.zip` (~10 MB cada) mais `version.txt`. **O nome `web_nothreads_*` é o que o Godot procura quando `thread_support=false`** [testado: sem esse arquivo o export falha com "Could not open template for export"]. Os `web_*.zip` sem "nothreads" são os de multithread e os `web_dlink_*` são para GDExtension.
- Instalar templates à mão: extrair em `~/.local/share/godot/export_templates/4.7.2.stable/` (o nome da pasta vem de `version.txt`, aqui `4.7.2.stable`).
- Os checksums do editor e do `.tpz` baixados aqui bateram com o `SHA512-SUMS.txt` [testado].

Instalação local testada:

```bash
V=4.7.2
BASE=https://github.com/godotengine/godot-builds/releases/download/${V}-stable
curl -fsSLO $BASE/Godot_v${V}-stable_linux.x86_64.zip
curl -fsSLO $BASE/Godot_v${V}-stable_export_templates.tpz
unzip -q Godot_v${V}-stable_linux.x86_64.zip
mkdir -p ~/.local/share/godot/export_templates/${V}.stable
unzip -q Godot_v${V}-stable_export_templates.tpz -d tpl
mv tpl/templates/* ~/.local/share/godot/export_templates/${V}.stable/
./Godot_v${V}-stable_linux.x86_64 --headless --version   # 4.7.2.stable.official.ed1daf0bf
```

---

## 2. Exportação Web no Godot 4

### 2.1 Renderer obrigatório

[doc] "Godot 4 can only target WebGL 2.0 (using the Compatibility rendering method). Forward+/Mobile are not supported on the web platform [...]. Godot currently does not support WebGPU." Safari tem vários problemas com WebGL 2.0; a documentação recomenda Chromium (Chrome/Edge) ou Firefox. Como o jogo é para navegador de computador, **testar em Chrome, Edge e Firefox; tratar Safari como "pode ter bugs"**.

No `project.godot`:

```ini
[rendering]
renderer/rendering_method="gl_compatibility"
renderer/rendering_method.mobile="gl_compatibility"
```

### 2.2 O que funciona e o que NÃO funciona

Fonte: tabela de recursos da página "Renderers" (docs 4.7) e `doc/classes/*.xml` do 4.7.2. Os itens marcados [testado] rodaram no meu export de teste dentro de Chromium (WebGL 2.0, `OpenGL ES 3.0 (WebGL 2.0 ...)`), sem erros no console.

**NÃO funciona em Compatibility (portanto, nem na web):**

| Recurso | Consequência para o jogo |
|---|---|
| **Névoa volumétrica** | Usar névoa de profundidade + cones de luz falsos. |
| **SDFGI, VoxelGI, SSIL, SSR** | Iluminação baked (`LightmapGI`) ou luzes falsas. (Atenção: o *render* de lightmaps funciona, mas o **bake exige hardware com RenderingDevice**; a doc não diz se dá para assar com o projeto em Compatibility. Teste no M0 ou asse num projeto auxiliar em Forward+.) |
| Decals | Usar quads/planos com textura (sangue, rachaduras). |
| Projetores de luz (textura), PCSS, contact shadows | Nada a fazer; não são necessários. |
| Trilhas de partículas, colisão SDF de partículas, `emit_particle()` | Partículas simples apenas. |
| Profundidade de campo (blur), debanding, subsurface scattering | Sem. |
| TAA, FSR2, FXAA, SMAA, MSAA 2D | Só MSAA 3D e SSAA existem. Para o visual PS1 não se quer anti-aliasing mesmo. |
| `CompositorEffects`, compute shaders, buffer Normal/Roughness, `RenderingDevice` | Pós-processamento só com **quad em tela cheia** (`hint_screen_texture`), que funciona. |
| HDR, 2D HDR | Cor é RGBA8 (baixa faixa dinâmica). Faz *banding*, o que o dithering PSX esconde. |

**Funciona** (todos na tabela oficial como "Supported"): névoa de profundidade e de altura, glow (implementação simplificada), tonemap, adjustments, SSAO (novidade: a doc 4.7 lista SSAO como suportado em Compatibility, mas é caro; evitar na web), `hint_screen_texture` e `hint_depth_texture`, ReflectionProbe (2 por malha), MSAA 3D, sombras.

**Perguntas específicas do pedido:**

- **GPU particles?** `GPUParticles3D` básico **funciona** em Compatibility [testado: 200 partículas, sem erro]. Não funcionam trilhas, colisão SDF e `emit_particle`. Alternativa mais previsível: `CPUParticles3D` para poucos efeitos.
- **AudioStreamPlayer3D?** **Existe, mas com ressalvas oficiais.** Na web o áudio usa por padrão o modo **Sample** (Web Audio API). A doc diz: "Positional audio may not always work correctly depending on the node's properties". Sem suporte a efeitos de áudio, reverb e doppler. Não consegui testar som real num navegador headless. **Risco a testar cedo** (passos do monstro ao redor do jogador é central no terror). Plano B: panning e volume calculados por script num `AudioStreamPlayer` comum. Ver §2.6.
- **Shaders específicos?** Shaders `spatial`, `canvas_item` e uniforms globais funcionam [testado com os shaders PSX]. Não funcionam: compute, `hint_normal_roughness_texture`, qualquer coisa de `RenderingDevice`. Sem *ubershaders*/pré-compilação de pipeline: a doc diz que em Compatibility "você precisa usar a abordagem antiga de pré-carregar materiais, shaders e partículas exibindo-os por pelo menos um frame no frustum durante o carregamento". Na prática: **uma "sala de aquecimento" invisível na tela de carregamento**, senão cada material novo trava o primeiro frame em que aparece.
- **C#:** não exporta para web no Godot 4. Usar GDScript.
- **GDExtension:** só com `variant/extensions_support=true` (exige cabeçalhos COOP/COEP; evitar).

### 2.3 Limites de desempenho

A documentação oficial **não publica números** de orçamento para web. O que ela afirma:

- [doc] Compatibility: "baixo custo base, mas alto custo de escala" (o oposto do Forward+).
- [doc] Web é WebAssembly, "não código nativo": CPU e GPU são recurso escasso.
- [doc] **No máximo 8 OmniLights e 8 SpotLights por malha**; luzes com sombra usam abordagem **multi-pass** (mais cara) com mistura menos precisa.
- [doc] Profundidade de 24 bits **sem reverse-Z**: planos *near/far* muito espaçados dão z-fighting. Manter `far` curto (a névoa de curto alcance ajuda).
- [doc] Memória inicial do WASM é 32 MiB com crescimento automático (`initial_memory=32`, `ALLOW_MEMORY_GROWTH=1` no `detect.py` do 4.7.2). O `.pck` é baixado inteiro e copiado para o sistema de arquivos em memória do Emscripten (leitura de `preloader.js`), logo **o tamanho do `.pck` conta contra a RAM do navegador**.

**Metas sugeridas [heurística, validar com profiling no navegador alvo]:**

| Item | Meta |
|---|---|
| Resolução interna | 640x480 ou menor, ampliada com filtro *nearest* (é o visual PS1 e a melhor economia de GPU). Renderizar o 3D num `SubViewport` de 320x240 a 480x360 e esticar. |
| Draw calls por frame | abaixo de ~300 |
| Triângulos visíveis | abaixo de ~100 mil (PS1 real: dezenas de milhares) |
| Luzes com sombra | 1 a 2 no máximo; preferir luz "baked" no vértice (as malhas PSX já usam `vertex_lighting`) |
| Texturas | 64x64 a 256x256, sem mipmap, sem compressão com perda desnecessária |
| `.pck` | abaixo de ~50 a 100 MB (carregamento inicial e RAM) |
| Música | loops curtos em OGG (1 a 2 MB cada); na web o áudio em modo Sample é decodificado no navegador |
| Medir | `Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)` num HUD de debug + aba Performance do DevTools |

### 2.4 Single-thread, COOP/COEP e GitHub Pages

[doc] Texto oficial (docs, "Exporting for the Web"): "Desde o Godot 4.3, o Godot suporta exportar o jogo em uma única thread [...] Embora tenha desvantagens (não pode usar threads e não é tão rápido quanto o multi-thread), não exige tanta instalação. É mais compatível com itch.io, Poki, CrazyGames [...]. **Por esses motivos, é a forma preferida e agora padrão de exportar jogos para a Web.**"

Por quê: multithread usa `SharedArrayBuffer`, que exige HTTPS e os cabeçalhos `Cross-Origin-Opener-Policy: same-origin` e `Cross-Origin-Embedder-Policy: require-corp`. **O GitHub Pages não permite cabeçalhos customizados.** Opções:

| Opção | Veredito |
|---|---|
| **Single-thread** (`variant/thread_support=false`) | **Recomendado.** Nada de cabeçalho. [testado: servi o export com `python -m http.server` (sem COOP/COEP); o console mostrou `Build configuration: Emscripten 4.0.20, single-threaded, no GDExtension support`, `crossOriginIsolated=false`, e o jogo rodou.] |
| Multi-thread + opção PWA do Godot (`progressive_web_app/enabled` com `ensure_cross_origin_isolation_headers`) | A própria doc oferece isso: um *service worker* embutido "garante que os cabeçalhos estejam sempre presentes". Funciona no Pages, mas traz cache de service worker (risco de jogador preso numa versão antiga) e recarrega a página na primeira visita. |
| `coi-serviceworker` (biblioteca de terceiros) | **Não usar.** É o mesmo truque do PWA, mas externo, sem necessidade, já que o Godot tem o equivalente embutido. [não verificado: estado atual do projeto] |

**O que se perde sem threads [doc]:** nenhum multithread de engine; áudio em modo Sample (não Stream) para ter baixa latência; carregamento e física no mesmo thread principal. Para um jogo de salas pequenas com poucos inimigos, isso é aceitável.

**Teste que fiz [testado]:** no export single-thread, `ResourceLoader.load_threaded_request()` funcionou (status LOADED); `Thread.new().start()` retornou OK, **mas `wait_to_finish()` devolveu `null` em vez do valor da função**; `OS.has_feature("threads")` = `false`. **Não confie em `Thread` na web;** use `load_threaded_request` ou carregue entre salas atrás de uma transição.

### 2.5 Tamanho do `.wasm` e como reduzir

Medido [testado], export de projeto mínimo, Godot 4.7.2, single-thread, release:

| Arquivo | Tamanho |
|---|---|
| `index.wasm` | **39,5 MB** (sem compressão) |
| `index.wasm` com gzip -9 | **10,1 MB** |
| `index.js` | 0,28 MB |
| `index.pck` (projeto mínimo) | 10 KB |

[doc] O `.wasm` "comprime bem, para cerca de um quarto do tamanho com gzip"; Brotli comprime ainda mais. **O GitHub Pages serve gzip dinamicamente** (a doc cita Pages na lista de hosts "com compressão on-the-fly") mas não Brotli. Esperar ~10 MB de download do motor + o `.pck`. (O blog do Godot 4.3 citava ~5 MB com Brotli.)

Como reduzir, em ordem de esforço:

1. **Nada a fazer:** deixar o gzip do Pages agir. Mostrar uma tela de "Carregando..." boa (aproveitar para a estética, §5).
2. **Menos conteúdo no `.pck`:** `docs/.gdignore`, texturas pequenas, áudio OGG de baixa taxa, exportar só o necessário (filtro "Export selected scenes (and dependencies)").
3. **Template de exportação customizado** (a doc "Optimizing a build for size"): compilar o motor com `target=template_release optimize=size lto=full`, `disable_3d=no`, e **desligar módulos que o jogo não usa** (`module_*_enabled=no`: `webrtc`, `websocket`, `openxr`, `webxr`, `enet`, `mbedtls`, `multiplayer`, `tilemap`, `gltf`, `fbx`, `svg`, `theora`, `mp3`, `vhacd`, etc.) e usar um **perfil de build** gerado pelo editor ("Detect from Project"). Desligar `disable_physics_2d`, `disable_advanced_gui` quando possível. Exige Emscripten (a doc atual pede 6.0.1+ para compilar a web) e `threads=no`. É a única forma de baixar o `.wasm` de verdade, e dá trabalho de CI. **Só vale a pena se o carregamento ficar um problema.** [não testado]
4. Brotli exige outro host; fora de escopo.

### 2.6 Áudio na web

- [doc] Navegadores bloqueiam *autoplay*. "A forma mais fácil é pedir ao jogador que clique, toque ou aperte uma tecla para ativar o áudio, por exemplo numa tela de abertura." **Solução natural para este jogo:** a tela inicial "Clique para começar" (parece mesmo um jogo em Flash) destrava o áudio, captura o mouse e pode entrar em tela cheia, tudo no mesmo evento de clique.
- [doc] Desde a 4.3, o padrão é **Sample playback** (Web Audio API): baixa latência sem threads, mas **sem AudioEffects**, **sem reverb e doppler**, sem áudio procedural, e 3D posicional "nem sempre correto".
- [doc] Dá para mudar para **Stream** em `Audio > General > Default Playback Type.web` ou por nó (`Playback Type`), recuperando todos os efeitos, mas com **mais latência (especialmente sem threads)**.
- Consequência de design: **bus effects (reverb de corredor, low-pass de "abafado", distorção) não tocam em modo Sample.** Se a corrupção do áudio (§5.7) depende de efeitos em tempo real, ou use Stream só nos nós que precisam (aceitando latência), ou pré-renderize as versões "corrompidas" como arquivos separados e troque entre elas (mais simples e mais robusto).
- Música MIDI: o Godot **não toca arquivos .mid**. Renderizar o MIDI para OGG (FluidSynth + soundfont de licença livre) e usar loops curtos.

### 2.7 Captura do mouse (pointer lock) para FPS

[doc] "Entrar em tela cheia e capturar o cursor **têm de ocorrer como resposta a um evento de input do JavaScript**. No Godot isso significa chamar de dentro de um callback de evento pressionado como `_input` ou `_unhandled_input`. Consultar o singleton `Input` não basta."

O que apurei lendo `display_server_web.cpp` e `library_godot_display.js` do 4.7.2 e testando:

- `Input.mouse_mode = Input.MOUSE_MODE_CAPTURED` chama `canvas.requestPointerLock()`. **Fora de um evento de usuário, falha em silêncio.**
- **[testado]** Clique no canvas → `document.pointerLockElement` = `CANVAS`, e `Input.mouse_mode` passa a `2` (CAPTURED). Ao sair do lock (`document.exitPointerLock()`), `Input.mouse_mode` **volta a `0` (VISIBLE) sozinho**, e um novo clique recaptura. O Godot lê o estado real do navegador (`mouse_get_mode()` consulta `isPointerLocked`).
- `InputEventMouseMotion.relative` funciona normalmente com o mouse capturado (o JS escala `movementX/Y`).
- `MOUSE_MODE_CONFINED` e `CONFINED_HIDDEN` **não são suportados** na web (erro). `Input.warp_mouse()` **não faz nada** na web.
- Cursor customizado (`Input.set_custom_mouse_cursor`): na web **máximo 128x128**, e acima de 32x32 só aparece se o cursor estiver totalmente dentro da página. Útil para o cursor "mãozinha de Flash".
- **Esc sai do pointer lock** [MDN, Pointer Lock API]. Depois de sair por Esc, é preciso um novo gesto do usuário para travar de novo. No Chrome há uma pequena janela depois do Esc em que um novo pedido é recusado [não verificado]. Além disso, o navegador **consome o Esc**, então não conte com `ui_cancel` para pausar [não verificado].
- **Padrão recomendado (testado a parte do estado):**

```gdscript
# Em um nó sempre ativo (ex.: autoload "Input"/"GameState"):
func _unhandled_input(event: InputEvent) -> void:
    # A captura precisa acontecer DENTRO de um evento de clique/tecla.
    if event is InputEventMouseButton and event.pressed \
            and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED and jogando:
        Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
        get_tree().paused = false

func _process(_d: float) -> void:
    # Esc, Alt-Tab, etc. soltam o mouse: tratar como pausa.
    if jogando and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
        get_tree().paused = true
        mostrar_aviso("Clique para continuar")
```

  Use outra tecla para pausar (P, Tab) em vez de depender do Esc. Se `iframe` for usado em algum momento: precisa de `sandbox="allow-pointer-lock"`. No GitHub Pages direto não é necessário.
- Opção `html/focus_canvas_on_start=true` (padrão): foca o canvas ao iniciar, para o teclado funcionar sem clique extra.

### 2.8 Outras limitações da web que afetam o plano

| Limitação | Fonte | Impacto |
|---|---|---|
| Aba em segundo plano **pausa** o jogo (`_process` para) | [doc] | Aceitável (é terror de uma pessoa só). Usar `Window` focus events para pausar com elegância. |
| `user://` persiste só com IndexedDB/cookies liberados; anônimo não persiste | [doc] | Salvamento/progresso pode não persistir. Pense em "checkpoint por sala" que sobrevive a recarregar (ou aceite perder). |
| Rede de baixo nível não existe (só HTTP, WebSocket cliente, WebRTC) | [doc] | Irrelevante para jogo solo. |
| Gamepad só é detectado após apertar um botão | [doc] | Foco é teclado e mouse. |
| Fontes do sistema não existem; **tem de embutir as `.ttf` no projeto** | conhecimento geral do funcionamento da web [não verificado, mas consequência direta de não haver acesso a fontes do SO] | Obrigatório para a Parte B. Todas as fontes recomendadas abaixo são OFL e podem ser embutidas. |
| Sem *ubershaders* | [doc] | "Sala de aquecimento" (§2.2). |
| `Thread` não confiável | [testado] | §2.4. |
| Tela cheia só por gesto do usuário | [doc] | Botão "Tela cheia" ou F11 do navegador. |
| `NavigationAgent3D` (perseguidores) | não testei na web | Testar no M2 com poucos agentes. |

### 2.9 O que eu testei de fato (resumo)

Projeto mínimo `GL Compatibility`, Godot 4.7.2: cena com piso, 20 caixas com o shader `psx_opaque` do plugin `scolastico`, `Environment` com névoa de profundidade, `OmniLight3D`, `GPUParticles3D` (200), `AudioStreamPlayer3D`, `ColorRect` com `psx_postprocess` (dithering 5 bits via `hint_screen_texture`), seis *shader globals* declarados em `[shader_globals]` do `project.godot`.

- Importar e exportar com `godot --headless` em checkout limpo: **OK** (7 s).
- Executar em desktop com OpenGL 3 (Mesa/llvmpipe): **sem erros de shader**.
- Exportar para Web e abrir em **Chromium headless 153 com WebGL 2.0** (SwiftShader), servido **sem** COOP/COEP: **renderiza, sem erros de shader**; screenshot confirmou piso e caixas com névoa e *banding* dithered. Clique capturou o mouse.
- **Não testado:** desempenho em GPU real, som real, Firefox/Safari, variantes `transparent`/`double` do shader PSX, o plugin editor `AutoApply`, e o workflow YAML rodando no GitHub de verdade.

---

## 3. GitHub Actions: exportar para Web e publicar no GitHub Pages

### 3.1 Comparativo das abordagens (estado em out/2026)

| Abordagem | Estado | Como funciona | Prós | Contras |
|---|---|---|---|---|
| **`abarichello/godot-ci`** (imagem Docker `barichello/godot-ci`) | Ativo: tags `4.7.2` e `latest` publicadas em 18/08/2026 (Docker Hub); último commit no repositório em 22/06/2026 ("Fix CI failing due to .NET version not being set for Godot 4.7"). | Job roda dentro do contêiner com Godot e templates pré-instalados. | Mais simples; muito usado; tem tutoriais. | O workflow de exemplo do README ainda fixa Godot **4.3** e publica com `JamesIves/github-pages-deploy-action` num branch `gh-pages` (jeito antigo, não o oficial `deploy-pages`). Precisa mover os templates de `/root/.local/...` para `~/.local/...` no início (visto no próprio workflow deles). Contêiner grande baixado a cada execução. Terceiro na cadeia de confiança. |
| **`firebelley/godot-export`** | Mantido: v8.0.0 (runtime Node 24), README com Godot 4 e `actions/checkout@v5`. | Ação que baixa Godot + templates por URL, exporta **todos** os presets e (opcional) arquiva em `.zip` e cria *Release*. Opção `cache`. | Bom para publicar binários de PC em *Releases*. | Pensada para releases, não para Pages: a saída exige passo extra para chegar ao `upload-pages-artifact`. Os exemplos do README usam URLs antigas (`downloads.tuxfamily.org`, hoje desatualizadas). Eu não a testei. |
| **`chickensoft-games/setup-godot`** | Mantido: v2.4.3 como última release que vi (a data exata não confirmei), runtime Node 24. | Instala Godot (e opcionalmente templates) no runner, com cache; expõe `godot`/`GODOT` no PATH. Entrada `version` (precisa de `major.minor.patch`). | Boa para testes e CI multi-OS. | **`use-dotnet` vem `true` por padrão** (precisa `false` para baixar o Godot sem .NET). **`include-templates: true` baixa os templates de TODAS as plataformas (1,3 GB)**; só o cache salva. Eu não a testei contra 4.7.2 (a URL de download que ela usa é `godot-builds/releases/download/`, a mesma que verifiquei). |
| **Baixar o binário à mão** (`curl` + `unzip`) | Qualquer versão, mesma URL oficial. | Você controla tudo. | Sem terceiros; **verifica SHA-512**; dá para guardar em cache só os 2 templates Web (~20 MB em vez de 1,3 GB); trivial de atualizar (mudar `GODOT_VERSION`). | ~25 linhas de shell para manter. |

**Recomendação: baixar à mão, com cache e checagem de checksum.** Para um jogo de um desenvolvedor, o fluxo é pequeno, evita atrasos de terceiros quando sair o Godot 4.8 e eu rodei esses mesmos passos de shell aqui (§3.3). Se preferir menos manutenção, `godot-ci` é a segunda opção (§3.8).

### 3.2 Versões das ações oficiais do GitHub

Confirmei com `git ls-remote --tags` que existem: `actions/checkout@v7`, `actions/cache@v5` (e v6), `actions/configure-pages@v5` (e v6), `actions/upload-pages-artifact@v5`, `actions/deploy-pages@v5`. O workflow de exemplo oficial (`actions/starter-workflows`, `pages/static.yml`) usa `configure-pages@v5`, `upload-pages-artifact@v3`/`deploy-pages@v5`, com `permissions: contents: read, pages: write, id-token: write` e `concurrency: pages`. Se alguma versão causar problema, voltar uma major.

### 3.3 Workflow completo (`.github/workflows/deploy-web.yml`)

**Status:** os dois passos de shell (baixar/instalar e exportar) foram extraídos do YAML e **executados aqui** num HOME limpo, com checagem SHA-512, cache simulado só dos templates Web, `--import` e `--export-release`: terminaram OK e geraram `index.html`, `index.wasm`, `index.pck`. O YAML passou em `yaml.safe_load`. **Não rodou no GitHub Actions de verdade**, então o primeiro run pode pedir ajuste (nome do preset, caminho do projeto).

```yaml
name: Deploy Web (GitHub Pages)

on:
  push:
    branches: [main]
  workflow_dispatch:

permissions:
  contents: read
  pages: write
  id-token: write

concurrency:
  group: pages
  cancel-in-progress: false

env:
  GODOT_VERSION: "4.7.2"        # sem o sufixo -stable
  PROJECT_PATH: "."             # pasta onde está o project.godot
  EXPORT_PRESET: "Web"          # nome EXATO (maiúsculas/minúsculas) no export_presets.cfg

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
      - name: Checkout
        uses: actions/checkout@v7
        # with: { lfs: true }   # só se usar Git LFS para texturas/áudio

      - name: Cache do Godot + templates Web
        id: godot-cache
        uses: actions/cache@v5
        with:
          path: |
            ~/godot-bin
            ~/.local/share/godot/export_templates/${{ env.GODOT_VERSION }}.stable
          key: godot-${{ env.GODOT_VERSION }}-web-v1

      - name: Baixar Godot e templates (só se o cache falhou)
        if: steps.godot-cache.outputs.cache-hit != 'true'
        run: |
          set -euo pipefail
          BASE="https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable"
          EDITOR_ZIP="Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
          TPZ="Godot_v${GODOT_VERSION}-stable_export_templates.tpz"
          mkdir -p "$RUNNER_TEMP/dl" ~/godot-bin
          cd "$RUNNER_TEMP/dl"
          curl -fsSL --retry 3 -O "$BASE/$EDITOR_ZIP" -O "$BASE/$TPZ" -O "$BASE/SHA512-SUMS.txt"
          grep -E " (${EDITOR_ZIP}|${TPZ})\$" SHA512-SUMS.txt | sha512sum -c -
          unzip -q "$EDITOR_ZIP" -d ~/godot-bin
          # Os templates completos têm ~1,3 GB. Guardamos só os de Web single-thread.
          unzip -q "$TPZ" 'templates/version.txt' 'templates/web_nothreads_*.zip' -d tpl
          T=~/.local/share/godot/export_templates/${GODOT_VERSION}.stable
          mkdir -p "$T"
          mv tpl/templates/* "$T/"

      - name: Exportar para Web
        run: |
          set -euo pipefail
          GODOT=~/godot-bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64
          chmod +x "$GODOT"
          "$GODOT" --version
          mkdir -p build/web
          cd "$PROJECT_PATH"
          # Primeiro import: gera .godot/ (pode avisar de erros inofensivos).
          "$GODOT" --headless --import || true
          "$GODOT" --headless --export-release "$EXPORT_PRESET" "$GITHUB_WORKSPACE/build/web/index.html"
          test -s "$GITHUB_WORKSPACE/build/web/index.html"
          test -s "$GITHUB_WORKSPACE/build/web/index.wasm"
          test -s "$GITHUB_WORKSPACE/build/web/index.pck"
          ls -la "$GITHUB_WORKSPACE/build/web"

      - name: Configurar Pages
        uses: actions/configure-pages@v5

      - name: Upload do artefato do Pages
        uses: actions/upload-pages-artifact@v5
        with:
          path: build/web

  deploy:
    needs: build
    runs-on: ubuntu-24.04
    environment:
      name: github-pages
      url: ${{ steps.deployment.outputs.page_url }}
    steps:
      - name: Publicar no GitHub Pages
        id: deployment
        uses: actions/deploy-pages@v5
```

Detalhes importantes:
- **O arquivo precisa se chamar `index.html`.** A doc: "O export Web do Godot 4 espera que alguns arquivos tenham o mesmo nome do export inicial. Podem ocorrer problemas se arquivos exportados forem renomeados, inclusive o HTML principal."
- Sem prévia `--import` o export também funcionou aqui, num projeto simples [testado]. Mantive o `--import` com `|| true` por segurança em projetos com muitas texturas e para gerar a pasta `.godot/` antes.
- Com `cache-hit`, o passo de download é pulado. A cada mudança de versão, troque a chave (`-v1` → `-v2`) só se mudar o conteúdo do cache; a versão já está na chave.
- O `deploy` em ambiente `github-pages` **só aceita o branch padrão** por regra de proteção do ambiente. O repositório hoje trabalha no branch `claude/confident-euler-tlf6z1`; um run disparado dali falha no `deploy` com erro de "branch not allowed" [não verificado, comportamento conhecido do GitHub]. Soluções: fazer merge em `main` (o gatilho do YAML) ou, em *Settings → Environments → github-pages → Deployment branches*, permitir esse branch.
- `actions/configure-pages` serve para falhar com mensagem clara se o Pages não estiver ligado. A opção `enablement: true` que o liga sozinho **exige token com permissão de admin** e não funciona só com `GITHUB_TOKEN`, então ligue à mão (§3.4).

### 3.4 O que o dono do repositório precisa ligar à mão

1. **Settings → Pages → Build and deployment → Source: `GitHub Actions`** (não "Deploy from a branch").
2. **Repositório público** (ou plano pago, §3.6).
3. Em *Settings → Actions → General*, ações habilitadas (padrão). As permissões do `GITHUB_TOKEN` já vêm no próprio YAML (`permissions:`), então a configuração padrão do repositório não importa.
4. Garantir que o `github-pages` environment aceite o branch que vai fazer deploy (§3.3).
5. Depois do primeiro deploy: a URL sai no resumo do job e fica `https://<usuário>.github.io/<repositório>/`. Para este repositório (`IcaroPv01/jogo_castelinho_imb-`): `https://icaropv01.github.io/jogo_castelinho_imb-/` (a mesma que o PLANO §7.1.1 cita). (O hífen final no nome do repositório é válido, mas deixa a URL estranha; renomear o repositório ajudaria.)
6. Limites do Pages [doc]: site publicado até **1 GB**, repositório recomendado até 1 GB, **100 GB/mês de banda (limite "soft")**, **10 builds por hora (soft)**, e o deploy dá timeout em **10 minutos**. Com ~10 MB de wasm + `.pck`, 100 GB equivalem a milhares de jogadas.

### 3.5 `export_presets.cfg` para Web

Gere pelo editor (*Projeto → Exportar → Adicionar → Web*), e **commite o arquivo** (ele **não pode** estar no `.gitignore`; é o erro mais comum, citado no README do godot-ci). Este é o arquivo que usei no teste, e funcionou sem editar no export da 4.7.2:

```ini
[preset.0]

name="Web"
platform="Web"
runnable=true
advanced_options=false
dedicated_server=false
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/web/index.html"
patch_list=PackedStringArray()
encryption_include_filters=""
encryption_exclude_filters=""
seed=0
encrypt_pck=false
encrypt_directory=false
script_export_mode=2

[preset.0.options]

custom_template/debug=""
custom_template/release=""
variant/extensions_support=false
variant/thread_support=false
vram_texture_compression/for_desktop=true
vram_texture_compression/for_mobile=false
html/export_icon=true
html/custom_html_shell=""
html/head_include=""
html/canvas_resize_policy=2
html/focus_canvas_on_start=true
html/experimental_virtual_keyboard=false
progressive_web_app/enabled=false
progressive_web_app/ensure_cross_origin_isolation_headers=true
progressive_web_app/offline_page=""
progressive_web_app/display=1
progressive_web_app/orientation=0
progressive_web_app/icon_144x144=""
progressive_web_app/icon_180x180=""
progressive_web_app/icon_512x512=""
progressive_web_app/background_color=Color(0, 0, 0, 1)
```

Chaves que importam (nomes confirmados no `export_plugin.cpp` do 4.7.2):

| Chave | Valor | Por quê |
|---|---|---|
| `variant/thread_support` | `false` | Single-thread, sem COOP/COEP. |
| `variant/extensions_support` | `false` | GDExtension exigiria cabeçalhos. |
| `vram_texture_compression/for_desktop` | `true` | Só PC; evita duplicar texturas para mobile. |
| `progressive_web_app/enabled` | `false` | Evita cache de service worker preso em versão antiga. |
| `html/custom_html_shell` | opcional | Para a tela "Carregando..." em estilo Flash (§5.6). O shell padrão já traz `onProgress(current, total)` e uma `<progress>`. |
| `export_filter` | `all_resources` | Simples, mas exporta tudo que está em `res://`. Trocar por `scenes` (cenas e dependências) se o `.pck` engordar. |
| `name` | `"Web"` | Tem de ser **igual** ao `EXPORT_PRESET` do workflow (diferencia maiúsculas). |

### 3.6 GitHub Pages com repositório privado no plano gratuito

**Não funciona.** Documentação oficial: "Se a conta dona do repositório usa GitHub Free ou GitHub Free for organizations, o repositório precisa ser público." Em planos pagos (Pro, Team, Enterprise Cloud) o Pages funciona com repositório privado, **mas o site publicado continua público na internet**, a menos que seja Enterprise Cloud com controle de acesso [não verificado o detalhe por plano; a doc consultada só confirma a regra do Free].

O PLANO §11 já lista "tornar o repositório público" como passo seu. O acesso anônimo à URL do repositório respondeu 404 neste ambiente, coerente com repositório **ainda privado** (ou só bloqueio do proxy do container). **Confirme em *Settings → General → Danger zone → Change visibility*.** Se continuar privado no plano Free, as saídas são: (a) tornar o repositório público, como o PLANO §7.1.1 já prevê (código e `docs/` ficam públicos; antes disso limpar as fotos de imprensa do **histórico** do git, PLANO §10); (b) usar um segundo repositório público só com a saída do export; (c) hospedar em outro lugar. Em todos os casos, **o jogo publicado é público**.

### 3.7 Armadilhas já conhecidas

- `export_presets.cfg` não pode estar ignorado; nome do preset é *case-sensitive*; caminhos relativos mudam se o projeto estiver em subpasta (godot-ci README).
- Remover `*.import` do `.gitignore` (§0.1).
- `docs/.gdignore` (§0.1).
- Git LFS: se usar para áudio/texturas grandes, `lfs: true` no checkout (e a cota gratuita de banda do LFS é pequena).
- Mantenha o Godot do CI **idêntico** ao do seu PC.
- Cada push em `main` faz deploy: aproveite `workflow_dispatch` para publicar sob demanda e proteja `main`.

### 3.8 Alternativa: `godot-ci` (Docker)

Trecho adaptado do próprio exemplo do README (que fixa 4.3; aqui a tag `4.7.2` existe no Docker Hub). **Não testei este trecho.**

```yaml
  build:
    runs-on: ubuntu-24.04
    container:
      image: barichello/godot-ci:4.7.2
    steps:
      - uses: actions/checkout@v7
      - name: Setup
        run: |
          mkdir -v -p ~/.local/share/godot/export_templates/
          mv /root/.local/share/godot/export_templates/4.7.2.stable ~/.local/share/godot/export_templates/4.7.2.stable
      - name: Web build
        run: |
          mkdir -v -p build/web
          godot --headless --verbose --export-release "Web" "$GITHUB_WORKSPACE/build/web/index.html"
      - uses: actions/upload-pages-artifact@v5
        with: { path: build/web }
```

---

## 4. Estética PS1/low-poly em WebGL2/Compatibility

### 4.1 Os dois repositórios citados

| | `scolastico/psx_visuals_gd4` | `adamscott/godot-psx-style-demo` |
|---|---|---|
| Engine alvo | **Godot 4** (`gdshader`, `global uniform`, `hint_screen_texture`) | **Godot 3** (`config_version=4`, arquivos `.shader`) |
| Último commit | 14/04/2026 | 19/01/2021 |
| Licença | MIT (copyright 2026 Joschua Becker; o original em Godot 3 é de snotbane) | MIT (copyright 2020 MenacingMecha) |
| Funciona em Compatibility/WebGL2? | **Sim [testado]**: `psx_opaque.gdshader`, `psx.gdshaderinc` e `psx_postprocess.gdshader` compilaram e renderizaram em WebGL 2.0, com uniforms globais, dithering por `hint_screen_texture` e névoa própria. | **Não direto.** Sintaxe de Godot 3; precisaria portar. Serve só como **referência de ideias** (LCD, reflexo "cromado", sprites billboard). |

O que o plugin do scolastico entrega: *vertex snapping* (tremor de vértice), mapeamento de textura afim ("textura ondulando"), névoa por distância, dithering de profundidade de cor (pós-processamento), materiais opaco/transparente/dupla-face. Os parâmetros ficam em **uniforms globais** (`psx_snap_distance`, `psx_affine_strength`, `psx_fog_near/far/color`, `psx_bit_depth`). Isso é ótimo para o plano, porque dá para ligar `GameState.corruption` a esses valores (`RenderingServer.global_shader_parameter_set`) e a imagem inteira degrada ao mesmo tempo.

Ressalvas:
- O README do plugin avisa que a abordagem atual (trocar materiais em tempo de execução com `AutoApply`) **perde mapas PBR** e que a versão futura será "conversão de projeto". Para este jogo (PS1, sem PBR) tanto faz.
- **Declare os uniforms globais no `project.godot`** (seção `[shader_globals]`) ou o shader nem compila. Em projeto novo, ativar o plugin e usar o diálogo de setup os cria. No meu teste os escrevi à mão.
- O `psx_postprocess` lê a tela inteira (`hint_screen_texture`), o que em Compatibility significa uma **cópia da tela por frame**. Melhor alternativa: renderizar o 3D num `SubViewport` de baixa resolução e aplicar o dithering só nele; reduz o custo e dá o visual autêntico de 320x240.
- Eu só testei a variante **opaca** e o pós-processamento. Testar `transparent` e `double` quando precisar (grades, vidros, cortinas).
- Aviso do autor sobre Z-fighting com `next_pass`: usar os materiais PSX **no lugar** dos `StandardMaterial3D`, não como segunda passada.

### 4.2 Névoa de profundidade simples

**Funciona.** `Environment.fog_enabled = true` com `fog_mode = FOG_MODE_DEPTH`, `fog_depth_begin/end` e `fog_light_color` renderizou sem erro em WebGL2 [testado], e a doc de renderers lista "Fog (Depth and Height): ✔️ Supported" em Compatibility. Há também a névoa **dentro do shader PSX** (por distância ao vértice; esses materiais usam `fog_disabled`), que dá o visual "pop-in" de PS1 e é a mais barata. Para a masmorra: névoa curta e escura + luz pontual quente + partículas de poeira. O "volumétrico" que o plano previa deve virar **cones de luz falsos** (malhas com alfa e *additive blend*).

---

# PARTE B: Estética "jogo educativo em Flash dos anos 2000"

> **Aviso de método.** Os fatos históricos que dá para checar (RIVED, Iguinho, Turma da Mônica, Discovery Kids, Flash EOL, jogos de terror) estão com fonte no fim. A **descrição visual e sonora** abaixo é síntese de conhecimento geral sobre a época e os sites listados; eu **não consegui abrir capturas dos sites originais** (muitos saíram do ar) e portanto trato a linguagem visual como **hipótese de trabalho**, não como medição. Antes de fechar a direção de arte, vale revisar capturas no Internet Archive/Wayback e nos acervos de Flash (Flashpoint, arquivos da Turma da Mônica e do Discovery Kids citados nas fontes).

## 5. Linguagem visual e sonora

### 5.1 Contexto

- Flash Player: suporte encerrado em **31/12/2020**, bloqueio de conteúdo a partir de **12/01/2021**. Ruffle (emulador em Rust/WebAssembly) e Flashpoint (arquivo comunitário) preservam o legado. Para o jogo, isso é material de enredo: o "conteúdo educativo antigo" que **não deveria mais rodar**.
- No Brasil, o ecossistema era de **portais infantis** (Smartkids, Iguinho/iG de 2000, Discovery Kids, Turma da Mônica, de 1997 a ~2005 com jogos em Flash), **objetos de aprendizagem do MEC** (RIVED, Rede Interativa Virtual de Educação: objetos em Flash para ciências, matemática, física, química, história, artes e geografia, de 1997/2004 em diante) e **sites de governo/prefeitura** com cara de portal institucional.

### 5.2 Linguagem visual (hipótese de trabalho)

| Elemento | Como era | Como reproduzir no Godot |
|---|---|---|
| **Palco 4:3 fixo** | Flash tinha palco de tamanho fixo (lembro do padrão 550x400 [não verificado]); sites "melhor visualizados em 800x600". | UI em 800x600 (`stretch/mode=canvas_items`, `aspect=keep`). **Pillarbox** com moldura/fundo de "página". |
| **Taxa de quadros baixa** | Animação em 12 a 24 fps [não verificado], movimentos de mascote em passos. | Animar mascote/UI a **12 fps** (passos discretos, `AnimationPlayer` com `step`) para dar o "tremidinho" de tween de Flash. |
| **Vetor chapado + contorno grosso** | Preenchimento de cor sólida, contorno preto/escuro de 3 a 6 px, sombras duras, poucos gradientes. | `StyleBoxFlat` com `border_width` 3-4, `corner_radius` 12-24, `shadow_offset` duro; texturas 2D ilustradas; contorno de texto com `outline_size` no tema. |
| **Botões "gel"/brilhantes** | Era "Web 2.0" (2005 a 2008): botão com gradiente, reflexo branco semitransparente na metade de cima, borda clara, sombra. | `StyleBoxTexture` 9-slice com `GradientTexture2D` + elipse branca com alfa sobreposta; estados *hover*/*pressed* com leve escala (efeito "boing"). |
| **Paletas** | Primárias saturadas (azul-céu `#1E90FF`, amarelo-sol, vermelho-tomate, verde-grama), fundo de céu azul com nuvens, grama, arco-íris; sites institucionais: azul-marinho/cinza com degradê, faixa verde-amarela. | Definir **uma paleta fechada de ~8 cores** num `Theme` e num `Resource`; a corrupção (§5.7) mexe nela. |
| **Mascotes com balão de fala** | Personagem 2D que "fala" (boca trocando de quadro), balão com texto "datilografado", sons bobos por letra. | `Sprite2D` com 3-4 quadros de boca + `RichTextLabel.visible_characters` crescendo + um blip por caractere. |
| **Telas de "Carregando..."** | Barra com porcentagem, mascote correndo, mensagem "Aguarde, carregando 78%". | Shell HTML customizado + `onProgress` (já exposto), ou tela do Godot após o `.pck`. |
| **Transições** | Cortinas, círculo que fecha (iris), "zoom boing", *fade* por quadros, página que vira. | `ColorRect` com `ShaderMaterial` (iris/cortina) ou `AnimationPlayer`. |
| **Recompensas** | Estrelinhas, selos, "Parabéns!", **diplomas** imprimíveis com o nome, medalhas, barra de progresso. | Já previsto no plano (selos por quiz). O diploma final é um bom gancho de terror (ver §5.7). |
| **Cursor** | Mãozinha/luva branca de desenho animado. | Cursor custom ≤ 32x32 (ou ≤ 128 com a restrição da web, §2.7). |
| **Cara de portal público** | Faixa superior com brasão, menu em abas, contador de visitas, "Fale conosco", rodapé com data, GIFs animados. | Moldura do menu inicial do "Programa Municipal de Memória Interativa" (**fictício**, sem usar o brasão real, regra do plano §3.3). |

### 5.3 Linguagem sonora (hipótese de trabalho)

- **Música:** loops curtos (8 a 16 compassos), tom maior, andamento animado, instrumentos de *General MIDI*: marimba/xilofone, pizzicato, flauta, steel drum, órgão de feira, baixo "saltitante". Timbre de *soft-synth* barato (tipo o sintetizador padrão do Windows). Repetição constante. Hoje: renderizar MIDI para OGG (§2.6).
- **Efeitos de interface:** clique "pop"/"blip", *boing*/*sproing* de mola, *ding* de acerto, *buzzer* bobo de erro, *whoosh* de transição, "tchan!" de conquista, brilho de varinha ao ganhar estrela.
- **Voz:** locutor(a) animado(a) e didático(a), frases do tipo "Muito bem!", "Tente de novo!", "Vamos aprender?"; narração com sibilância e compressão MP3 baixa (22 kHz, mono). Para o jogo: gravar/sintetizar com **licença limpa** e degradar de propósito (filtro de banda, bitcrusher) para soar "de 2003".
- **Compressão como estética:** o áudio "ruim" do Flash (chiado, *clipping* leve) é parte da nostalgia, então não precisa de qualidade alta, o que **ajuda o tamanho do `.pck`**.

### 5.4 Referências por site (o que observar em cada uma)

| Referência | O que é | O que aproveitar (hipótese a conferir em captura) |
|---|---|---|
| **Smartkids** (`smartkids.com.br`) | Um dos primeiros sites infantis brasileiros; atividades para imprimir, alfabeto, jogo da forca, memória, "caça-erros", ortografia, datas comemorativas. Público de 4 a 10 anos. | Menu de **categorias com ícones**, jogos simples de uma tela, linguagem de "atividade da escola". Bom modelo para os **painéis/quizzes do Ato I**. |
| **Iguinho / iG Kids** (2000; mascote cachorrinho; jogos e animações em Flash) | Portal infantil do iG; "As Aventuras de Gui & Estopa". | Mascote animal, personagens com rivais "vilões" bobos, jogos curtos. Bom para **o guia-mascote**. |
| **Discovery Kids (BR)** | Jogos em Flash: ABCdário, Ordenar os Planetas, Seja o Herói do Planeta, Vida Natural, etc. | Tom **pseudo-científico** e "ecológico", exercícios de ordenar/relacionar. |
| **Turma da Mônica** (`monica.com.br`) | Jogos em Flash de 1997 a ~2005: 7 Erros, Jogo da Memória, Ligue os Pontos, Siga o Som, Jogo das Sombras, Guarda-Roupa da Mônica. | Estilo de **quadrinhos coloridos**, contorno grosso, personagens reconhecíveis. **Não copiar personagens nem marca** (propriedade de terceiros). |
| **RIVED / MEC** | Objetos de aprendizagem em Flash, com "guia do professor". | Visual **institucional-educativo**: simulações, abas de "Atividade", "Resumo", "Créditos". O tom certo para o "Programa Municipal". |
| **Sítio do Picapau Amarelo (site/jogos da época)** | Não consegui conferir o site da época. | Só conceito: personagens de literatura brasileira, cenário rural colorido. [não verificado; pesquisar acervo antes de usar] |
| **Ciência Hoje das Crianças / CHC Online** | Revista de divulgação científica infantil (1986; independente a partir de 1990) com presença online (CH Online/CHC Online). | **Tom de curiosidade científica**, seções "você sabia?", experimentos. Casa com os fatos reais da história de Imbé. |
| **Sites de prefeitura/governo** | Portal institucional, brasão, notícias, banner. | Moldura da **abertura**. Importante: o jogo usa um programa **fictício**. |
| **Neopets** | Mundo virtual de pets (2000+); estrelas amarelas sobre azul real, ícones de loja e moedas. | **Economia de recompensas** e iconografia de selos. |
| **Miniclip** | Portal de minijogos Flash. | Menu de miniaturas e "play now". |
| **Nick Jr. / PBS Kids** | Sites de TV infantil com jogos Flash. | Narrador que **fala direto com a criança**, pausa para "você consegue?" |
| **Club Penguin** | Mundo virtual (2005+); estilo "Penguin Style". | Cenários isométricos/2D, interface de bolhas/ícones coloridos. |
| **Poptropica** | Mundo de ilhas com aventuras; teve preservação pós-Flash. | Aventura em seções ("ilhas") ≈ nossas "salas". |

### 5.5 Fontes tipográficas LIVRES (Google Fonts, licença confirmada no `METADATA.pb` do repositório `google/fonts`)

Todas com subconjunto **latin** (cobre ã, ç, é, õ do português). **Embuta as `.ttf` no projeto** (na web não há fontes do sistema, §2.8) e registre o crédito em `CREDITS.md`.

| Fonte | Licença | Vibe / uso sugerido |
|---|---|---|
| **Comic Neue** (Craig Rozynski, Hrant Papazian) | OFL | **A "Comic Sans" livre.** Corpo de texto de painéis, balões. Mais limpa que a Comic Sans, mas reconhecível. |
| **Comic Relief** (Jeff Davis; adicionada em fev/2025) | OFL | Alternativa ainda mais próxima da Comic Sans, em Regular/Bold. |
| **Baloo 2** (Ek Type) | OFL | Arredondada, gordinha; **títulos e botões "gel"**. |
| **Fredoka** (Milena Brandão, Hafontia) | OFL | Arredondada e limpa; títulos de menu. |
| **Nunito** | OFL | Arredondada de leitura confortável; texto secundário. |
| **Sniglet** | OFL | Display arredondada, "brinquedo"; letreiros. |
| **Bubblegum Sans** | OFL | Display "chiclete" com cara de desenho. |
| **Londrina Solid** (Marcelo Magalhães) | OFL | Display grossa, bem de "quadrinho infantil". |
| **Grandstander** | OFL | Display brincalhona, variável; ótima para "Parabéns!". |
| **Lilita One** | OFL | Display grossa com contorno forte; títulos de ato. |
| **Boogaloo** | OFL | Display de "cartaz de circo/desenho". |
| **Patrick Hand** / **Pangolin** / **Itim** / **Delius** / **Short Stack** / **Gochi Hand** / **Kalam** | OFL | Manuscritas de caderno/lousa; "anotações da professora", e usadas na corrupção (§5.7, letra "escrita à mão" por cima do texto limpo). |
| **Andika** | OFL | Desenhada para **alfabetização** (a, g de uma andar); autêntica para "aprender a ler". |
| **Chewy**, **Luckiest Guy**, **Schoolbell**, **Coming Soon** | **Apache 2.0** (não OFL) | Também livres; checar a licença ao creditar. |
| **Arimo**, **Tinos**, **Cousine** | OFL | Substitutos livres de **Arial/Times/Courier**: para a moldura **institucional da prefeitura** (a parte sem graça, antes da parte fofa). |
| **VT323**, **Press Start 2P**, **IBM Plex Mono** | OFL | Terminal/"erro de sistema" nas telas corrompidas. |
| **Special Elite** | Apache 2.0 | Máquina de escrever: "documentos oficiais" e carimbos. |

**Combinação sugerida:** títulos em **Baloo 2 ExtraBold** (com `outline_size` de 4 px, contorno escuro), texto em **Comic Neue Bold**, moldura da prefeitura em **Arimo**, e a camada "corrompida" em **Patrick Hand** (rabiscos) e **VT323** (erros).

### 5.6 Como isso entra no Godot sem pesar

- **Tema único (`Theme.tres`)** com `StyleBoxFlat`/`StyleBoxTexture`, fontes e tamanhos; trocar variantes de tema em tempo de execução é o mecanismo para a corrupção da interface.
- **Tela "Carregando..." HTML** via `html/custom_html_shell`: ela aparece **antes** do motor existir (útil porque o download de ~10 MB de `.wasm` leva alguns segundos). O shell padrão tem `onProgress(current,total)`, então dá para fazer uma barra e um mascote em CSS/GIF na própria página. Essa é a "abertura Flash" mais barata e mais fiel.
- **Pré-render de MIDI** e áudio curto; efeitos de clique como `.wav` pequenos.
- Mascote em **Sprite2D** com poucos quadros (12 fps): o oposto do 3D; custo quase zero na web.
- **Mistura 2D/3D:** o Ato I pode ser UI 2D (painéis, quiz) sobre o 3D baixo-polígono do prédio, e o 3D só "se revela" aos poucos.

### 5.7 Cinco formas concretas de corromper essa estética aos poucos

Cada uma é um **parâmetro numérico** ligado a `GameState.corruption` (0 a 1), como o plano já faz com o shader PSX.

1. **Tipografia que se desfaz.** Começa em Comic Neue limpa. Subir a corrupção troca letras por homógrafos (`o`→`0`, `l`→`I`), faz o espaçamento oscilar, substitui palavras-chave por versões "reescritas" (como no Ato II do plano: "acomodados" → "removidos"), e acaba trocando a fonte infantil por **Special Elite/VT323** ou por texto manuscrito em Patrick Hand "escrito por cima". Barato: só alterar `text` e a variante de fonte do tema.
2. **Música e efeitos que desafinam.** O loop MIDI-render perde instrumentos um a um (primeiro a marimba, depois o baixo), o `pitch_scale` baixa 1 a 3 semitons, o andamento cai e surge uma segunda faixa **invertida** quase inaudível. O "clique" de botão vira um som úmido. **Na web, pré-renderize as versões corrompidas** (modo Sample não faz efeito de bus, §2.6) e faça *crossfade* entre elas.
3. **O mascote perde a sincronia.** A boca não bate com o texto, o balão de fala mostra a frase **antes** de a voz falar (ou depois), os olhos param de piscar e passam a **seguir o cursor/olhar do jogador**, e um quadro de animação "entre dois quadros" fica preso por alguns frames. Em 12 fps é fácil de fazer parecer erro de animação, não efeito.
4. **A interface mente sobre o progresso.** Barra de "Carregando..." que chega a 100% e **volta**; o contador "Sala 01/100" mostra números errados; as estrelinhas de recompensa somem uma a uma (ou viram olhos); o **diploma** final sai com o nome em branco, com uma data impossível ou com "Aprovado" em letra de mão. Botões "gel" perdem o brilho e o contorno engrossa. (Tudo já combina com as mentiras do plano: placas "Construtor: _____".)
5. **Cor e moldura se desfazem.** Cai a saturação, o contorno grosso dos desenhos engrossa e fica irregular, o fundo de céu azul de "palco" vira a **foto/textura** de uma parede, o palco 4:3 **racha** e a imagem vaza para a tela inteira em 3D PS1. Mesmo uniforme global do dithering (`psx_bit_depth` cai de 8 para 3 bits) comanda o visual.
6. *(Bônus de enredo)* **"Este conteúdo requer um player que não existe mais."** O Flash Player deixou de existir em 31/12/2020, oito dias depois da abertura do museu (23/12/2020, segundo o plano). Uma caixa de erro de "reprodutor de animações" quebrando quando o conteúdo "desatualizado" aparece é uma metáfora direta. **Não usar a marca, logotipo ou layout da Adobe**; escrever um aviso genérico e fictício.

> **Cuidado ético (do plano, §3):** as contradições dos painéis do Ato II devem usar **fatos reais** ditos sem verniz (sambaquis como cemitério, remoção dos pescadores, afogamentos). Tratar afogamentos com respeito; evitar caricatura de vítimas reais.

## 5.8 Jogos de terror com estética de Flash/edutainment: o que aproveitar

| Jogo | Fatos verificados | O que aproveitar | O que evitar |
|---|---|---|---|
| **Baldi's Basics in Education and Learning** (Micah McGonigal / Mystman12; beta em 31/03/2018; Unity) | Paródia de jogos educativos dos anos 90 (cita *Sonic's Schoolhouse*, *I.M. Meen*, *3D Dinosaur Adventure*). Feito para a game jam Meta-Game Jam. Usa modelos de poucos polígonos, texturas desencontradas e áudio áspero de propósito. | A **escolha deliberada de "ruim"** como linguagem; regra única do perseguidor (erra o problema, ele fica mais rápido); contraste "lição de matemática" com ameaça. Cabe na estrutura de salas e quizzes do Ato I. | Virar meme ("gritos" aleatórios). Nosso tom precisa ser **sutil**, como no Spooky's. |
| **Petscop** (Tony Domenico; série no YouTube, mar/2017 a nov/2019, 24 vídeos) | Fingia ser um *Let's Play* de um jogo de PlayStation de 1997 sobre colecionar bichos num mundo colorido ("Gift Plane"). Música "alegre" inspirada no lado luminoso do PS1 (Spyro, Ridge Racer). | **Interface que mente** e regras opacas; tutoriais estranhos; texto de menu com erros; números e códigos escondidos; a combinação 3D PS1 + fofura. Ótima referência para a **lenta virada de tom** e para o Ato II. | Narrativa tão críptica que o jogador desista. Aqui o jogador tem de entender a ameaça. |
| **Don't Hug Me I'm Scared** (Becky Sloan e Joseph Pelling; 6 episódios no YouTube entre 29/07/2011 e 19/06/2016; série de TV em 2022) | Paródia de TV educativa infantil com bonecos, canções e uma "lição" que desmorona em surrealismo e horror. | **Estrutura "lição → música → colapso"**; a **canção alegre** como ferramenta de dissonância; cortes bruscos para outro registro visual. O "guia animado" do Castelinho pode ter um jingle que desafina (ver §5.7). | Humor absurdo demais: o plano quer terror e história local, não comédia surreal. |
| **Spooky's Jump Scare Mansion** (Lag Studios, 2014) | Já analisado em `spookys_e_referencias.md`. | Contador de salas e guia fofa constante. | Copiar o conteúdo. |
| **Hello Neighbor** (Dynamic Pixels/tinyBuild, 2017) | Não é Flash/edutainment (é estética de livro infantil colorido). IA que aprende com o jogador. | **Paleta saturada de subúrbio com ameaça**; a casa como quebra-cabeça. | IA adaptativa pesada (CPU na web, sem threads); uso muito grande de física. |
| **Garten of Banban** (Euphoric Brothers; 1º capítulo em 06/01/2023, gratuito no Steam; mais de 6 capítulos em 2023) | Horror de **mascote** num jardim de infância misterioso. | Mascotes "de brinquedo", cartazes de "regras do jardim de infância", personagens com cara de produto infantil. | Excesso de sustos e *lore* em capítulos; fidelidade a clichês de "mascote corrompido". |
| **Dumb Ways to Die** (Metro Trains Melbourne / McCann, nov/2012) | **Não é terror:** campanha de segurança ferroviária com personagens fofos que morrem de maneiras "bobas" ao som de uma canção chiclete; também virou jogo. | **O registro "instrução de segurança fofa com morte"**: casa com os painéis sobre afogamentos na barra e o tom do jingle. Contraste música alegre + perigo real. | Humor com morte real de vítimas identificáveis. Usar o registro, não o conteúdo. |
| **Poppy Playtime** (Mob Games, 2021) | Fábrica de brinquedos; *fitas VHS* com vídeo de mascote explicando. [não verificado em fonte aqui] | **Vídeos de orientação antigos como exposição de enredo** (a "gravação de 2003" do programa). | Cópia de design de mascote azul/rosa (propriedade). |
| **Doki Doki Literature Club!** (Team Salvato, 2017) | Visual novel fofa que se corrompe. [não verificado em fonte aqui] | A **interface que "sabe" que é um jogo** e se desfaz; texto e UI com *glitch*. | Personalização invasiva (nome do jogador, arquivos do computador). Na web nem é possível, e não seria correto. |
| **Bendy and the Ink Machine** (2017) | Desenho animado dos anos 30 que apodrece em tinta. [não verificado em fonte aqui] | A **tinta que vaza** como shader de corrupção para o contorno grosso dos desenhos. | Dependência de estética de época diferente (30s, não 2000). |

---

## Fontes

### Godot (oficiais)

- Godot, arquivo de downloads: https://godotengine.org/download/archive/ e página 4.7.2: https://godotengine.org/download/archive/4.7.2-stable/
- Releases (espelho oficial de binários): https://github.com/godotengine/godot-builds/releases/tag/4.7.2-stable (checksums em `SHA512-SUMS.txt` do mesmo release)
- Política de releases: https://docs.godotengine.org/en/stable/about/release_policy.html
- Exportando para a Web (inclui limitações, áudio, threads, servir arquivos, GitHub Pages): https://docs.godotengine.org/en/stable/tutorials/export/exporting_for_web.html (lido também no código-fonte `tutorials/export/exporting_for_web.rst` do `godot-docs`)
- Renderers e tabelas de recursos (Compatibility, Mobile, Forward+): https://docs.godotengine.org/en/stable/tutorials/rendering/renderers.html
- Compilação para Web e otimização de tamanho (`engine_details/development/compiling/compiling_for_web.rst` e `optimizing_for_size.rst`): https://docs.godotengine.org/en/stable/engine_details/development/compiling/optimizing_for_size.html
- Compilações de pipeline e shaders na Compatibility (`tutorials/performance/pipeline_compilations.rst`): https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html
- Organização de projeto e `.gdignore`: https://docs.godotengine.org/en/stable/tutorials/best_practices/project_organization.html
- Controle de versão (o que ignorar: `.godot/`): https://docs.godotengine.org/en/stable/tutorials/best_practices/version_control_systems.html
- Exportar projetos (filtros de exportação): https://docs.godotengine.org/en/stable/tutorials/export/exporting_projects.html
- Blog: progresso do export Web na 4.3 (single-thread, áudio por samples, ~5 MB com Brotli): https://godotengine.org/article/progress-report-web-export-in-4-3/
- Código-fonte do 4.7.2 consultado: `doc/classes/Environment.xml`, `Input.xml`, `AudioStreamPlayer3D.xml`, `GPUParticles3D.xml`; `platform/web/export/export_plugin.cpp`, `display_server_web.cpp`, `js/libs/library_godot_display.js`, `library_godot_input.js`, `js/engine/preloader.js`, `detect.py`. Base: https://github.com/godotengine/godot/tree/4.7.2-stable
- Pointer Lock API (MDN): https://developer.mozilla.org/en-US/docs/Web/API/Pointer_Lock_API

### GitHub Actions e Pages

- Limites do Pages: https://docs.github.com/en/pages/getting-started-with-github-pages/github-pages-limits
- Criar um site Pages (repositório privado só em plano pago): https://docs.github.com/en/pages/getting-started-with-github-pages/creating-a-github-pages-site
- Workflow inicial oficial do Pages: https://github.com/actions/starter-workflows/blob/main/pages/static.yml
- `actions/upload-pages-artifact`: https://github.com/actions/upload-pages-artifact ; `actions/deploy-pages`: https://github.com/actions/deploy-pages ; `actions/configure-pages`: https://github.com/actions/configure-pages ; `actions/checkout`: https://github.com/actions/checkout ; `actions/cache`: https://github.com/actions/cache
- `abarichello/godot-ci`: https://github.com/abarichello/godot-ci ; imagens: https://hub.docker.com/r/barichello/godot-ci/
- `firebelley/godot-export`: https://github.com/firebelley/godot-export
- `chickensoft-games/setup-godot`: https://github.com/chickensoft-games/setup-godot

### Estética PSX

- https://github.com/scolastico/psx_visuals_gd4 (Godot 4, MIT)
- https://github.com/adamscott/godot-psx-style-demo (Godot 3, MIT; demo em https://menacingmecha.itch.io/godot-psx-style-demo)

### Parte B

- RIVED/MEC: http://rived.mec.gov.br/ e http://rived.mec.gov.br/artigos.php ; "O projeto Rived: a aprendizagem dos participantes" (Unesp): https://repositorio.unesp.br/handle/11449/139668
- Smartkids: https://www.smartkids.com.br/
- Iguinho: https://iguinho.com.br/ ; "As Aventuras de Gui & Estopa": https://en.wikipedia.org/wiki/As_Aventuras_de_Gui_%26_Estopa
- Turma da Mônica, arquivo de jogos em Flash: https://archive.org/details/flash-monica e https://archive.org/details/jogos-flash-monica
- Jogos do Discovery Kids (arquivo): https://archive.org/details/jogos-do-discovery-kids
- Ciência Hoje das Crianças: https://chc.org.br/sobre-a-chc/ ; história do Instituto Ciência Hoje: https://cienciahoje.org.br/instituto/historia/
- Fim do Flash Player (Adobe): https://www.adobe.com/products/flashplayer/end-of-life-alternative.html ; Ruffle e Flashpoint (reportagens e guias): https://www.gamingonlinux.com/2020/11/the-internet-archive-are-keeping-flash-creations-alive-with-the-open-source-ruffle/page=1/ e https://www.denofgeek.com/games/how-to-play-flash-games-download-browser/
- Club Penguin: https://archives.clubpenguinwiki.info/wiki/Penguin_Style ; Poptropica (preservação pós-Flash): https://poptropi.ca/2020/01/05/preserving-poptropica-post-flash/
- Baldi's Basics: https://en.wikipedia.org/wiki/Baldi%27s_Basics_in_Education_and_Learning
- Petscop: https://en.wikipedia.org/wiki/Petscop ; entrevista sobre a trilha (Bandcamp Daily): https://daily.bandcamp.com/features/petscop-soundtrack-interview
- Don't Hug Me I'm Scared: https://en.wikipedia.org/wiki/Don%27t_Hug_Me_I%27m_Scared
- Garten of Banban (Steam): https://store.steampowered.com/app/2232840/Garten_of_Banban/
- Dumb Ways to Die: https://en.wikipedia.org/wiki/Dumb_Ways_to_Die ; caso (Campaign Brief): https://campaignbrief.com/australian-campaigns-of-the-decade-metro-trains-dumb-ways-to-die-2012%E2%80%88via-mccann-melbourne/
- Licenças das fontes (campo `license` dos `METADATA.pb`): https://github.com/google/fonts (ex.: `ofl/comicneue`, `ofl/baloo2`, `ofl/fredoka`, `ofl/comicrelief`, `ofl/arimo`, `apache/chewy`)

### Testes locais citados

Container desta sessão, 04/10/2026: Godot 4.7.2 (`4.7.2.stable.official.ed1daf0bf`), Mesa 25.2.8 (llvmpipe), Chromium Headless Shell 153.0.8010.12 via `playwright-core`. Código de teste: projeto mínimo de ~120 linhas em GDScript; não versionado no repositório.
