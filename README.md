# Castelinho: Visita Guiada

**▶ Jogar no navegador (computador ou celular):** https://icaropv01.github.io/jogo_castelinho_imb-/
**Versão para Windows (offline):** gerada só sob pedido. Fica em https://icaropv01.github.io/jogo_castelinho_imb-/Castelinho_Windows.zip até a próxima atualização do site.

Jogo 3D de terror em Godot 4 sobre o Castelinho de Imbé (RS). Começa como um "jogo educativo da prefeitura" sobre a história de Imbé e vai ficando cada vez mais estranho até descer a uma masmorra. Inspiração: *Spooky's Jump Scare Mansion*.

## Controles

| Tecla | Ação |
|---|---|
| Clique | Começar e capturar o mouse |
| W A S D / setas | Andar |
| Shift | Correr (gasta fôlego) |
| Mouse | Olhar |
| E ou clique | Ler painel / usar |
| **1–5** | Selecionar disco do Visor |
| **Rolagem do mouse** | Trocar disco do Visor |
| Q (segurar) | Mostrar época do disco (Visor do Tempo) |
| **F** | Lanterna (a partir da visita 3) |
| Espaço / Enter | Avançar diálogo |
| Esc ou P | Pausar (clique para voltar) |

### No celular (Chrome no Android, Safari no iPhone)

Abra o mesmo link e jogue **com o celular deitado** (em pé, o jogo pede para virar e pausa). Os controles de toque
aparecem sozinhos; dá para forçar em Pausa → Opções → Controles de toque (Automático / Sempre / Nunca).

| Toque | Ação |
|---|---|
| Arrastar no lado esquerdo | Andar (analógico) |
| Arrastar no lado direito (analógico com o olho) | Girar a câmera: quanto mais longe do centro, mais rápido |
| **Interagir** (fica amarelo perto de algo) | Ler painel / usar |
| **Correr** | Liga a corrida; para sozinha ao soltar o analógico |
| **Visor** (segurar) | Mostrar época do disco |
| Tocar num disco da faixa | Selecionar disco |
| **Lanterna** | Lanterna (a partir da visita 3) |
| Tocar na tela | Avançar diálogo |
| ⏸ (canto de cima) | Pausar |
| ⛶ (canto de cima) | Tela cheia (no iPhone: Compartilhar → Adicionar à Tela de Início) |

No celular o jogo usa um modo leve (imagem 3D um pouco mais baixa, 30 quadros por segundo, menos luzes).

**Versão 2:** Quatro visitas ao Castelinho (salas 1–80), um porão com salas 81–99, e o Braço Morto (sala 100). O jogo salva sozinho no navegador. A história se desdobra em cada visita, com ritmo lento na visita 1 e complexidade crescente.

## Modo debug

Para testar o jogo sem sofrer. Fica **desligado** para quem joga normalmente: ninguém vê nada.

**Como ligar**
- No computador ou celular: abra https://icaropv01.github.io/jogo_castelinho_imb-/?debug=1
- Sem o link: na tela de título, dê **5 toques rápidos no "Visitantes: ..."** (embaixo, à esquerda). Vale só até fechar a página; toque 5 vezes de novo para desligar.
- No computador instalado: rode o jogo com `--debug` no fim da linha de comando.

**Como abrir o painel**
- Teclado: tecla **'** (apóstrofo; no teclado brasileiro é a tecla à esquerda do 1). A mesma tecla fecha.
- Celular: botão **DBG**, no meio do topo da tela.
- O jogo fica pausado enquanto o painel está aberto.

**O que tem no painel**
- **Imortal:** nada mata você (a Figura e a água não fazem efeito).
- **Figura Branca desligada:** ela some e fica parada.
- **Atenção do Visor congelada:** o "olho" do Visor não sobe mais.
- **Mostrar informações:** escreve no topo da tela a sala, a época, a visita e os quadros por segundo.
- **Ganhar tudo:** os 5 discos, a lanterna e o Visor de uma vez.
- **Pular para:** escolha a visita (ou Porão, ou Braço Morto) e a sala, e toque em "Ir para lá". O jogo só tem pontos de chegada em alguns lugares (checkpoints): se a sala escolhida não for um deles, você nasce no checkpoint mais perto **antes** dela, e o painel avisa qual.
- **Ver um final:** leva direto ao Braço Morto e começa o final "Encontrado", "Visita concluída" ou "Sala 101".

**O save normal não é mexido.** Com o debug ligado o jogo lê e grava em outro arquivo (`save_debug.json`); o seu progresso de verdade fica guardado como estava. Desligando o debug, tudo volta ao save normal.

## Documentação

- **Plano do projeto:** [`docs/PLANO.md`](docs/PLANO.md)
- **Roteiro da Versão 2:** [`docs/V2_ROTEIRO.md`](docs/V2_ROTEIRO.md)
- **Revisão gráfica e de ritmo (V2):** [`docs/REVISAO_V2.md`](docs/REVISAO_V2.md)
- **Bugs conhecidos:** [`docs/BUGS.md`](docs/BUGS.md)
- **Roteiro do MVP (salas 1 a 30):** [`docs/MVP_ROTEIRO.md`](docs/MVP_ROTEIRO.md)
- **Revisão gráfica:** [`docs/REVISAO_GRAFICA.md`](docs/REVISAO_GRAFICA.md)
- **Créditos e licenças:** [`docs/CREDITS.md`](docs/CREDITS.md)
- **Testes:** `bash tools/testar.sh` (headless) e `python3 tools/testar_web.py` (navegador)
- **Pesquisa:**
  - [Castelinho](docs/pesquisa/castelinho.md)
  - [História de Imbé](docs/pesquisa/historia_imbe.md)
  - [Spooky's e referências técnicas](docs/pesquisa/spookys_e_referencias.md)
- **Fotos de referência** (não versionadas): `bash docs/pesquisa/baixar_refs.sh`

## Conteúdo

**Aviso:** Este jogo trata de um **desaparecimento infantil fictício** com temas pesados. Nada é mostrado de forma gráfica ou violenta: o horror é psicológico e por sugestão. Ao final do jogo, há informações sobre proteção infantil: **Disque 100** (Direitos Humanos, gratuito, 24h).

Obra de ficção. O programa municipal mostrado no jogo é inventado e não representa a Prefeitura de Imbé.
