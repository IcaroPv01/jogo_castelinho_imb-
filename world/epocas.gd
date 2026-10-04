class_name Epocas
extends RefCounted
## Camadas de tempo (Visor do Tempo, PLANO §5.1).
## Marque nós que só existem em certas épocas; quando GameState.epoca muda, eles aparecem/somem
## e a colisão deles liga/desliga junto.
##
##   Epocas.marcar(no, [GameState.Epoca.E1950])                  # só aparece em 1950
##   Epocas.marcar(no, [GameState.Epoca.E2019, GameState.Epoca.E2020])
## Nós NÃO marcados existem em todas as épocas.


static func marcar(n: Node, epocas: Array) -> void:
	n.set_meta("epocas", epocas)
	n.add_to_group("epocal")
	_aplicar_no(n, GameState.epoca)


static func aplicar(arvore: SceneTree, epoca: int) -> void:
	for n in arvore.get_nodes_in_group("epocal"):
		_aplicar_no(n, epoca)


static func _aplicar_no(n: Node, epoca: int) -> void:
	var ativo: bool = epoca in n.get_meta("epocas", [])
	if n is Node3D or n is CanvasItem:
		n.visible = ativo
	n.process_mode = Node.PROCESS_MODE_INHERIT if ativo else Node.PROCESS_MODE_DISABLED
