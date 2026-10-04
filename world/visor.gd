class_name Visor
extends Node
## Lógica do Visor do Tempo (MVP_ROTEIRO §3, PLANO §5.1).
##
## Segurar Q (ação "visor") mostra a época `GameState.flag("epoca_visor", E1950)`; soltar volta
## para E2020, a não ser que a flag `visor_travado` esteja ligada (o Visor "mente": a época
## não volta). Só funciona com `GameState.flag("tem_visor")`.
##
## Como usar (cada nível que quiser o Visor), em `_ready()` ou `iniciar(player)`:
##     Visor.instalar(self)
## É idempotente: se já existe um Visor na árvore (ou se o integrador o registrar como
## autoload), reaproveita o existente.
##
## Ao ligar: troca a época, liga a moldura (Efeitos.visor(true): clarão branco + clique "slide").
## Ao soltar: o mesmo na volta. O jogador pode andar com Q segurado.

signal ativado(epoca: int)
signal desativado(epoca: int)

const GRUPO := "visor_tempo"
const INTERVALO_MIN := 0.12   # s entre trocas (evita metralhar o clique)

var ativo := false
var _ultima_troca := -10.0


## Garante um Visor dentro de `pai` (ou já em qualquer lugar da árvore) e o devolve.
static func instalar(pai: Node) -> Visor:
	for n in pai.get_tree().get_nodes_in_group(GRUPO):
		return n as Visor
	var v := Visor.new()
	v.name = "Visor"
	pai.add_child(v)
	return v


func _ready() -> void:
	add_to_group(GRUPO)


func _process(_dt: float) -> void:
	var quer: bool = GameState.flag("tem_visor") and Input.is_action_pressed("visor") \
			and not GameState.flag("ui_aberta")
	var agora := Time.get_ticks_msec() / 1000.0
	if quer != ativo and agora - _ultima_troca >= INTERVALO_MIN:
		_ultima_troca = agora
		if quer:
			_ligar()
		else:
			_desligar()


func _ligar() -> void:
	ativo = true
	var alvo := int(GameState.flag("epoca_visor", GameState.Epoca.E1950))
	GameState.trocar_epoca(alvo)
	Efeitos.visor(true)
	ativado.emit(alvo)


func _desligar() -> void:
	ativo = false
	if not GameState.flag("visor_travado"):
		GameState.trocar_epoca(GameState.Epoca.E2020)
	Efeitos.visor(false)
	desativado.emit(int(GameState.epoca))


func _exit_tree() -> void:
	# O nível acabou com o Visor ligado (ex.: transição): desliga a moldura.
	if ativo:
		ativo = false
		if is_instance_valid(Efeitos):
			Efeitos.visor(false)
