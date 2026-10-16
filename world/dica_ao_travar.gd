class_name DicaAoTravar
extends Node
## Dica de quem está parado: se o jogador fica um bom tempo sem avançar na visita (o "O que fazer agora" do Mapa, M, não
## muda e ele não chega a salas novas), um monitor lembra o objetivo em voz alta. Só por escolha dele de ficar perdido:
## quem está jogando bem nunca ouve. Substitui a necessidade de os monitores ficarem repetindo o caminho a cada sala.
##
##   DicaAoTravar.instalar(self)                       # no iniciar() do castelinho.gd (visitas 1 a 4)
##   DicaAoTravar.linhas(visita, objetivo, n) -> {"quem": String, "linhas": Array}
##
## Tempo: ESPERAS[n] segundos parado e livre (sem fala, sem tela aberta, sem Figura atrás) para a n-ésima dica do mesmo
## objetivo; no máximo ESPERAS.size() dicas por objetivo. Mudou o objetivo ou chegou a sala nova: recomeça do zero.

const ESPERAS: Array[float] = [90.0, 150.0, 210.0]

var nivel: Node
var _parado := 0.0
var _n := 0
var _assinatura := ""


static func instalar(n: Node) -> DicaAoTravar:
	var d := DicaAoTravar.new()
	d.name = "DicaAoTravar"
	d.nivel = n
	n.add_child(d)
	return d


## Quem fala e o que diz. A voz acompanha a visita (guia animado, aviso institucional, a voz de dentro das paredes).
static func linhas(visita: int, objetivo: String, n: int) -> Dictionary:
	match visita:
		1, 2:
			var abre := ["Perdido? Acontece nas melhores visitas!", "Ainda por aqui? Vou te dar uma mãozinha."]
			return {"quem": "bentinho", "linhas": [abre[n % abre.size()], objetivo]}
		3:
			return {"quem": "sistema", "linhas": ["Lembrete da visita:", objetivo]}
	return {"quem": "???", "linhas": ["Por aqui.", objetivo]}


## Máquina de estados pura (testável): devolve o índice da dica a falar agora, ou -1.
func passo(dt: float, livre: bool, assinatura: String) -> int:
	if assinatura != _assinatura:
		_assinatura = assinatura
		_parado = 0.0
		_n = 0
		return -1
	if not livre or _n >= ESPERAS.size():
		return -1
	_parado += dt
	if _parado < ESPERAS[_n]:
		return -1
	var i := _n
	_n += 1
	_parado = 0.0
	return i


func _process(dt: float) -> void:
	if nivel == null or not is_instance_valid(nivel) or get_tree().paused:
		return
	var v := int(nivel.get("visita"))
	if v < 1 or v > 4:
		return
	var obj := Objetivo.atual()
	var i := passo(dt, _livre(), "%d|%s|%d" % [v, obj, GameState.sala_maxima])
	if i < 0 or obj.begins_with("Siga em frente"):
		return
	var d := linhas(v, obj, i)
	Guia.falar(d.quem, d.linhas)


func _livre() -> bool:
	if Guia.ocupado() or GameState.flag("ui_aberta"):
		return false
	for p in ["_saindo_barra", "_saindo_visita", "_saindo_ato2", "_saindo_porao"]:
		if nivel.get(p) == true:
			return false
	for f in get_tree().get_nodes_in_group("figura_branca"):
		if f is Node3D and f.visible and f.get("ativa") == true:
			return false
	var p = nivel.get("player")
	return p != null and is_instance_valid(p) and p.pode_mover
