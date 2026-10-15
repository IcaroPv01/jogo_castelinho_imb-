# Varredura automática (módulo 1, 08/10/2026)

Scripts exploratórios que percorrem o jogo inteiro. Ficam **fora do CI** (não terminam em `_test.gd`). Os bugs que
eles acharam viraram correções com testes nas suítes de verdade (ver `docs/BUGS.md`, B15 a B24).
Alguns ainda listam observações conhecidas (marcadas "ACHADO"/"FALHA") que estão em "Sem correção" no BUGS.md.

Rodar um: `timeout 300 godot --headless -s res://tests/varredura/<nome>.gd`

| script | o que percorre |
|---|---|
| `v12.gd` | visitas 1 e 2: gatilhos de sala, rota a pé, falas |
| `v34.gd` | visitas 3 e 4, Ato II, passagem para o porão |
| `barra.gd` | flashback da Barra: caminhada, minigame, volta, morte e save no meio |
| `porao.gd` | porão 81–99: chão, checkpoints, morte, água, Visor |
| `braco.gd` | Braço Morto, finais, dedicatória, volta ao título |
| `save.gd` | "Continuar" em todos os checkpoints, saves quebrados/antigos |
| `estatico_console.gd` | carrega cada nível e procura erros no console |
| `fuga.gd` | caminhante aleatório (anda, corre, pula, troca de época) em todos os níveis: void, fora do mapa, preso na parede, trava (rede de segurança desligada; `--com-rede` liga). Ver o cabeçalho do script |
| `web_extra.sh` | build Web com câmera em cada shader e época (Chromium) |

Vários godot em paralelo gravam o mesmo `user://save.json`: rode os que mexem em save um de cada vez.

## Verificador de colocação (módulo 10)

`colocacao.gd` (+ `colocacao_lib.gd`) constrói cada nível/visita com o registro de `Malha` ligado (`castelinho/malha.gd`,
`castelinho/registro.gd`) e procura: objeto flutuando, enfiado/atravessando parede, z-fighting, frestas (com raio de
confirmação), degraus de piso e objetos que mudam entre visitas. Rodar: `godot --headless -s res://tests/varredura/colocacao.gd`
(ou `-- castelo ato2 barra porao braco` para escolher). Saída: `tests/varredura/saida/colocacao.{json,md}` (ignorada pelo git).
Depurar um objeto: `COLOC_DEBUG=etiqueta COLOC_DEBUG_V=1`; um par de z-fighting: `COLOC_ZF=etiqueta`.
