extends SceneTree
## Rede de segurança do jogador (world/rede_seguranca.gd), bugs do playtest do Bernardo (14/10/2026):
##  B37 cair no void / sair do mapa: volta ao último ponto seguro (em todo nível)
##  B38 dunas do Ato II sem borda: andava ~100 m até cair no void; agora paredes invisíveis em x ±50
##  B40 desligar o Visor no corredor de 1975 deixava o jogador no gramado fora do lote (andava ~300 m e caía)
##  B39 preso dentro de parede sem troca de época: a rede tira o jogador sozinha
## Uso: godot --headless -s res://tests/rede_seguranca_test.gd

const CASTELINHO := "res://world/niveis/castelinho.tscn"
const ATO2 := "res://world/niveis/ato2.tscn"
const PORAO := "res://world/niveis/porao.tscn"
const BRACO := "res://world/niveis/braco_morto.tscn"
const BARRA := "res://world/niveis/barra.tscn"

var falhas := 0
var GS
var main
var p


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	for cena in [CASTELINHO, ATO2, PORAO, BRACO, BARRA]:
		await _void_e_fora(cena)
	await _parede()
	await _dunas_borda()
	await _corredor_1975()
	await _sem_resgate_em_cena()
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _carregar(cena: String) -> Node:
	GS.novo_jogo()
	GS.jogando = true
	await main.carregar_mundo(cena, "Spawn")
	await _frames(20)
	p = main.player
	return main.mundo.get_child(0)


func _rede():
	return load("res://world/rede_seguranca.gd").atual


## Espera o jogador ficar parado no chão por ~1,5 s (a rede só usa pontos com 1 s ou mais).
func _assentar() -> Vector3:
	await _frames(100)
	return p.global_position


func _void_e_fora(cena: String) -> void:
	print("-- B37 void e fora do mapa: ", cena.get_file())
	await _carregar(cena)
	var rede = _rede()
	_checar(rede != null and rede.tem_limites, "rede instalada e com limites medidos")
	if rede == null:
		return
	root.get_node("/root/Guia").cancelar()   # fala de abertura que trava o jogador (Barra)
	await _frames(5)
	p.pode_mover = true
	var seguro: Vector3 = await _assentar()
	_checar(p.is_on_floor(), "jogador no chão no Spawn (%s)" % str(seguro))
	var n0: int = rede.resgates
	p.global_position = Vector3(seguro.x, rede.limites.position.y - 30.0, seguro.z)
	await _frames(3)
	_checar(rede.resgates == n0 + 1 and p.global_position.distance_to(seguro) < 1.0,
		"abaixo do chão volta ao ponto seguro (%s, motivo %s)" % [str(p.global_position), rede.ultimo_motivo])
	await _assentar()
	p.global_position = Vector3(rede.limites.end.x + 40.0, seguro.y + 1.0, seguro.z)
	await _frames(3)
	_checar(p.global_position.distance_to(seguro) < 1.0,
		"fora dos limites volta ao ponto seguro (%s, motivo %s)" % [str(p.global_position), rede.ultimo_motivo])
	await _assentar()
	_checar(rede.destravar() and p.global_position.distance_to(seguro) < 1.5, "destravar() volta a um ponto seguro")


func _parede() -> void:
	print("-- B39 preso dentro de parede (sem trocar de época)")
	await _carregar(CASTELINHO)
	var rede = _rede()
	await _assentar()
	var livres := 0
	var pontos := [Vector3(-27, 0.1, -12), Vector3(-24, 0.1, -14), Vector3(-20, 0.1, -20), Vector3(-14, 0.1, -26)]
	for pos in pontos:
		p.global_position = pos
		await _frames(60)
		if not rede._sobrepoe(p.global_position):
			livres += 1
	_checar(livres == pontos.size(), "a rede tira o jogador de %d/%d paredes" % [livres, pontos.size()])


func _dunas_borda() -> void:
	print("-- B38 dunas do Ato II têm borda")
	var nivel: Node = await _carregar(ATO2)
	GS.trocar_epoca(GS.Epoca.E1950)
	await _frames(5)
	var h: float = load("res://world/niveis/ato2_pecas.gd").altura_duna(44.0, -40.0)
	p.global_position = Vector3(44.0, h + 0.3, -40.0)
	p.rotation.y = 0.0
	await _frames(30)
	Engine.time_scale = 4.0
	Input.action_press("direita")
	Input.action_press("correr")
	await _frames(240)
	Input.action_release("direita")
	Input.action_release("correr")
	Engine.time_scale = 1.0
	_checar(p.global_position.x < nivel.DUNAS_X and p.global_position.y > h - 5.0,
		"correndo para o leste para na borda x=%.0f (%s)" % [nivel.DUNAS_X, str(p.global_position)])
	GS.trocar_epoca(GS.Epoca.E2020)


func _sem_resgate_em_cena() -> void:
	print("-- rede desligada quando o jogador não controla (cenas)")
	await _carregar(CASTELINHO)
	var rede = _rede()
	await _assentar()
	var n0: int = rede.resgates
	p.pode_mover = false
	p.global_position = Vector3(0, rede.limites.position.y - 30.0, 0)
	await _frames(3)
	_checar(rede.resgates == n0, "com pode_mover=false a rede não mexe no jogador")
	p.pode_mover = true
	await _frames(3)


func _corredor_1975() -> void:
	print("-- B40 Visor desligado dentro do corredor de 1975")
	await _carregar(CASTELINHO)
	var rede = _rede()
	await _assentar()
	GS.trocar_epoca(GS.Epoca.E1975)
	await _frames(10)
	p.global_position = Vector3(-10.2, 0.2, -50.0)
	await _frames(30)
	_checar(rede.resgates == 0 and p.global_position.z < -45.0, "em 1975 o corredor é área permitida (%s)" % str(p.global_position))
	GS.trocar_epoca(GS.Epoca.E2020)
	await _frames(10)
	_checar(p.global_position.z > -38.0, "fora de 1975 a rede devolve ao lote (%s, %s)" % [str(p.global_position), rede.ultimo_motivo])
