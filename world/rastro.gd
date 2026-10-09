class_name Rastro
extends Node
## Rastro de migalhas do jogador: guarda por onde ele andou (um ponto a cada ~0,5 m, os últimos ~45 m).
##
## Serve a duas coisas (módulo 9, "Granny pura"):
##   - o Visor põe a Figura do slide SOBRE o rastro, atrás do jogador: onde ele já andou não tem parede no meio;
##   - a Figura Branca perseguidora segue o rastro até o último ponto onde viu o jogador (contorna quinas sem atravessar).
##
## Cada ponto tem uma coordenada de arco `s` (metros andados desde o começo, só cresce). Assim "o ponto a 14 m atrás"
## é `ponto_atras(14.0)`, e uma posição guardada como `s` continua valendo enquanto o jogador anda.
## Um pulo de mais de `SALTO` m entre dois quadros (teleporte, transição) apaga o rastro: os pontos antigos não
## estão mais ligados ao novo lugar.
##
## Um só Rastro por cena (grupo `rastro_jogador`): `Rastro.garantir(no)` acha o existente ou cria um filho de `no`.
## Em testes sem jogador, alimente com `seguir(pos)`.

const GRUPO := "rastro_jogador"
const PASSO := 0.5          # m entre pontos
const COMP_MAX := 45.0      # m guardados
const SALTO := 4.0          # m: mais que isso num quadro = teleporte, apaga o rastro
const MAX_PONTOS := 130

var pontos: Array[Vector3] = []     # do mais antigo ao mais novo
var s_pontos: Array[float] = []     # coordenada de arco de cada ponto
var pos_atual := Vector3.ZERO       # onde o jogador está agora (ponta do rastro)
var tem_atual := false
var alvo: Node3D


static func garantir(no: Node) -> Rastro:
	for n in no.get_tree().get_nodes_in_group(GRUPO):
		if is_instance_valid(n):
			return n as Rastro
	var r := Rastro.new()
	r.name = "Rastro"
	no.add_child(r)
	return r


func _ready() -> void:
	add_to_group(GRUPO)


func _physics_process(_dt: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("player") as Node3D
	if alvo != null:
		seguir(alvo.global_position)


## Registra a posição do jogador (chamado todo quadro de física, ou à mão nos testes).
func seguir(pos: Vector3) -> void:
	if tem_atual and Vector2(pos.x - pos_atual.x, pos.z - pos_atual.z).length() > SALTO:
		limpar()
	pos_atual = pos
	tem_atual = true
	if pontos.is_empty():
		pontos.append(pos)
		s_pontos.append(0.0)
	else:
		var ult: Vector3 = pontos[pontos.size() - 1]
		var d := ult.distance_to(pos)
		if d >= PASSO:
			pontos.append(pos)
			s_pontos.append(s_pontos[s_pontos.size() - 1] + d)
	while pontos.size() > 1 and (s_atual() - s_pontos[0] > COMP_MAX or pontos.size() > MAX_PONTOS):
		pontos.remove_at(0)
		s_pontos.remove_at(0)


func limpar() -> void:
	pontos.clear()
	s_pontos.clear()
	tem_atual = false


## Coordenada de arco da ponta (o jogador agora).
func s_atual() -> float:
	if pontos.is_empty():
		return 0.0
	return s_pontos[s_pontos.size() - 1] + pontos[pontos.size() - 1].distance_to(pos_atual)


## Coordenada de arco do ponto mais antigo guardado.
func s_inicio() -> float:
	return s_pontos[0] if not s_pontos.is_empty() else 0.0


## Metros de rastro guardados (do ponto mais antigo ao jogador).
func comprimento() -> float:
	return s_atual() - s_inicio()


## Posição na coordenada de arco `s` (presa entre o ponto mais antigo e o jogador).
func ponto_em(s: float) -> Vector3:
	if pontos.is_empty():
		return pos_atual
	var fim := s_atual()
	s = clampf(s, s_pontos[0], fim)
	var n := pontos.size()
	if s >= s_pontos[n - 1]:
		var seg := fim - s_pontos[n - 1]
		return pontos[n - 1] if seg < 0.001 else pontos[n - 1].lerp(pos_atual, (s - s_pontos[n - 1]) / seg)
	# busca binária do segmento
	var lo := 0
	var hi := n - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if s_pontos[mid] <= s:
			lo = mid
		else:
			hi = mid
	var seg2 := s_pontos[hi] - s_pontos[lo]
	return pontos[lo] if seg2 < 0.001 else pontos[lo].lerp(pontos[hi], (s - s_pontos[lo]) / seg2)


## Ponto do rastro a `dist` metros ANDADOS atrás do jogador (se o rastro for mais curto, o mais antigo).
func ponto_atras(dist: float) -> Vector3:
	return ponto_em(s_atual() - dist)


## Menor distância (horizontal) de `p` a qualquer trecho do rastro. Para testes.
func distancia_ao_rastro(p: Vector3) -> float:
	var melhor := INF
	var todos: Array[Vector3] = pontos.duplicate()
	if tem_atual:
		todos.append(pos_atual)
	for i in todos.size():
		var a := Vector2(todos[i].x, todos[i].z)
		var b := a if i == todos.size() - 1 else Vector2(todos[i + 1].x, todos[i + 1].z)
		var q := Vector2(p.x, p.z)
		var ab := b - a
		var t := 0.0 if ab.length_squared() < 0.000001 else clampf((q - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		melhor = minf(melhor, q.distance_to(a + ab * t))
	return melhor
