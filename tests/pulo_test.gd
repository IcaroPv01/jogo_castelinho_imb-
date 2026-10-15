extends SceneTree
## Teste automático (headless) do pulo baixo do jogador: Espaço pula, a altura é baixa (< 0,5 m), não pula no ar,
## não pula com fala da Guia ou menu aberto, e o pulo não muda a velocidade horizontal.
## Uso: godot --headless -s res://tests/pulo_test.gd

var falhas := 0
var GS
var P


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	GS.novo_jogo()
	GS.jogando = false
	var mundo := Node3D.new()
	root.add_child(mundo)
	var chao := StaticBody3D.new()
	chao.collision_layer = 1
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(40, 1, 40)
	cs.shape = box
	cs.position.y = -0.5
	chao.add_child(cs)
	mundo.add_child(chao)
	P = load("res://player/player.gd").new()
	mundo.add_child(P)
	P.global_position = Vector3(0, 0.05, 0)
	for i in 10:
		await physics_frame
	_checar(P.is_on_floor(), "jogador no chão")

	var y0: float = P.global_position.y
	var altura := await _pular()
	_checar(altura > 0.2, "Espaço faz o jogador subir (%.2f m)" % altura)
	_checar(altura < 0.5, "o pulo é baixo (%.2f m < 0,5 m)" % altura)
	_checar(absf(P.global_position.y - y0) < 0.05 and P.is_on_floor(), "volta ao chão no mesmo nível")

	# não pula no ar: segura o botão e confere que o teto do pulo é o mesmo
	Input.action_press("pular")
	await physics_frame
	Input.action_release("pular")
	for i in 6:
		await physics_frame
	var meio: float = P.global_position.y
	Input.action_press("pular")
	await physics_frame
	Input.action_release("pular")
	var teto := meio
	for i in 60:
		await physics_frame
		teto = maxf(teto, P.global_position.y)
	_checar(teto - y0 < 0.5, "pular de novo no ar não dá pulo duplo (teto %.2f m)" % (teto - y0))
	for i in 40:
		await physics_frame

	# fala da Guia: o Espaço só avança o texto
	P.pode_mover = true
	GS.set_flag("ui_aberta", true)
	var a2 := await _pular()
	_checar(a2 < 0.05, "com tela aberta o Espaço não pula (%.2f m)" % a2)
	GS.set_flag("ui_aberta", false)
	P.pode_mover = false
	var a3 := await _pular()
	_checar(a3 < 0.05, "sem poder mover (cena) não pula (%.2f m)" % a3)
	P.pode_mover = true

	# andar e pular: velocidade horizontal igual à do chão
	Input.action_press("frente")
	for i in 12:
		await physics_frame
	var vel_chao: float = Vector2(P.velocity.x, P.velocity.z).length()
	Input.action_press("pular")
	await physics_frame
	Input.action_release("pular")
	for i in 6:
		await physics_frame
	var vel_ar: float = Vector2(P.velocity.x, P.velocity.z).length()
	Input.action_release("frente")
	_checar(absf(vel_ar - vel_chao) < 0.01, "pular não acelera (%.2f vs %.2f m/s)" % [vel_ar, vel_chao])

	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


## Aperta Espaço por um quadro e devolve a altura máxima alcançada.
func _pular() -> float:
	for i in 30:
		await physics_frame
	var y0: float = P.global_position.y
	Input.action_press("pular")
	await physics_frame
	Input.action_release("pular")
	var topo := y0
	for i in 60:
		await physics_frame
		topo = maxf(topo, P.global_position.y)
	return topo - y0


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
