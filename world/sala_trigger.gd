class_name SalaTrigger
extends Area3D
## Volume invisível que marca a entrada numa "sala" (atualiza o contador do HUD).

@export var numero := 1
@export var tamanho := Vector3(2, 3, 2)

signal entrou


func _init(n := 1, t := Vector3(2, 3, 2)) -> void:
	numero = n
	tamanho = t


func _ready() -> void:
	collision_layer = 0
	collision_mask = 2   # só o jogador
	monitorable = false
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tamanho
	f.shape = b
	f.position.y = tamanho.y * 0.5
	add_child(f)
	body_entered.connect(_on_body)


func _on_body(body: Node) -> void:
	if body.is_in_group("player"):
		GameState.entrar_sala(numero)
		entrou.emit()
