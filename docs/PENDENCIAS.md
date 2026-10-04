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
