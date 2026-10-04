class_name Interagivel
extends StaticBody3D
## Objeto genérico que o jogador pode usar com [E]. Conecte `usado` ou passe um Callable.
## Fica na camada 3 (bit 4) para o raio do jogador o achar mesmo sem colisão física.

signal usado(player: Node)

@export var texto_interacao := "Interagir"
var acao: Callable
var uma_vez := false
var _usado := false


func _init(texto := "Interagir", tamanho := Vector3(0.6, 0.6, 0.6), callback := Callable()) -> void:
	texto_interacao = texto
	acao = callback
	collision_layer = 4
	collision_mask = 0
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tamanho
	f.shape = b
	add_child(f)


func interagir(player: Node) -> void:
	if uma_vez and _usado:
		return
	_usado = true
	Audio.sfx("clique")
	usado.emit(player)
	if acao.is_valid():
		acao.call(player)
