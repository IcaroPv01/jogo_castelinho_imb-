class_name GatilhoCastelinho
extends SalaTrigger
## SalaTrigger do Castelinho na V2: em vez de chamar `GameState.entrar_sala(numero)` direto (o número aqui é a sala
## BASE, 1..22), delega ao nível, que converte base -> sala global da visita atual e dispara os eventos da visita.
## `ao_entrar` recebe a sala base.

var ao_entrar: Callable


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		if ao_entrar.is_valid():
			ao_entrar.call(numero)
		else:
			GameState.entrar_sala_base(numero)
		entrou.emit()
