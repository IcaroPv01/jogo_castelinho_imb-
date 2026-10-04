class_name Painel3D
extends Interagivel
## Painel educativo no mundo (placa colorida estilo "jogo da prefeitura").
## STUB do M0 — a versão completa (visual Flash, abre a tela de leitura e quiz) vem no M2.
## Conteúdo em data/paineis.json, chave = id (ex.: "p01").
##
##   var p := Painel3D.new("p01"); p.position = ...; nivel.add_child(p)
##   p.lido.connect(func(): ...)       # emitido quando o jogador fecha a leitura (e o quiz, se houver)

signal lido(id: String)

var id := ""


func _init(id_painel := "p00") -> void:
	super._init("Ler painel", Vector3(1.4, 1.0, 0.12))
	id = id_painel


func interagir(player: Node) -> void:
	super.interagir(player)
	GameState.somar("paineis_lidos")
	lido.emit(id)
