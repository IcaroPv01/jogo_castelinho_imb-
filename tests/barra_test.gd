extends SceneTree
## Teste automático do flashback da Barra (headless): carrega o nível, confere o chão, joga os 3
## lances da tarrafa (E/clique), o 3º puxa o jogador para a água e a cena volta ao Castelinho.
## Uso: godot --headless -s res://tests/barra_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads)

var falhas := 0
var GS: Node
var Ef: Node
var Gui: Node
var main: Node
var nivel: Node
var player: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	Ef = root.get_node("/root/Efeitos")
	Gui = root.get_node("/root/Guia")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true

	await _passada_completa()
	await _passada_auto()

	Engine.time_scale = 1.0
	load("res://world/niveis/ato2_pecas.gd")._tex.clear()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _carregar() -> void:
	await main.carregar_mundo("res://world/niveis/barra.tscn", "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.destino = "res://world/niveis/teste.tscn"   # o Castelinho é de outro agente
	nivel.espera_min = 0.3
	nivel.espera_max = 0.6
	await _frames(10)


## Aperta E (ação "interagir") por 3 quadros.
func _apertar_lancar() -> void:
	Input.action_press("interagir")
	await _frames(3)
	Input.action_release("interagir")
	await _frames(2)


func _passada_completa() -> void:
	print("-- barra: 3 lances")
	GS.set_flag("viu_flashback_barra", false)
	await _carregar()
	_checar(player.is_on_floor() and absf(player.global_position.y) < 0.05, "jogador no chão (y=%.2f)" % player.global_position.y)
	_checar(GS.sala_atual == 14 and main.hud.lbl_sala.text == "SALA 14", "contador mostra SALA 14 (%s)" % main.hud.lbl_sala.text)
	_checar(abs(GS.corruption - 0.1) < 0.02, "corruption manual do flashback (%.2f)" % GS.corruption)
	_checar(nivel.get_node_or_null("Spawn") != null and nivel.boto != null, "marcador Spawn e boto")
	_checar(nivel.fase == nivel.Fase.INTRO, "começa na introdução (Tainá explica)")
	# a Tainá fala (bloqueando): avança as falas
	var ok: bool = await _ate(func():
		Gui.avancar()
		return nivel.fase == nivel.Fase.ESPERA, 1500)
	_checar(ok, "depois da fala, o minigame começa")

	# lance cedo (antes do boto bater a cabeça): não conta
	await _frames(20)
	nivel.lancar()
	await _frames(60)
	_checar(nivel.lances == 0 and nivel.tainhas == 0, "lance cedo não conta")

	# lances 1 e 2: o boto sinaliza, o lance pega tainhas
	for n in [1, 2]:
		ok = await _ate(func(): return nivel.janela_aberta, 1500)
		_checar(ok, "lance %d: o boto bateu a cabeça (janela aberta)" % n)
		await _apertar_lancar()
		ok = await _ate(func(): return nivel.lances == n, 600)
		_checar(ok, "lance %d contou (lances=%d)" % [n, nivel.lances])
		_checar(nivel.tainhas > 0, "lance %d pegou tainhas (%d)" % [n, nivel.tainhas])
	var tainhas_antes: int = nivel.tainhas

	# lance 3: o boto sinaliza na hora errada e o rio puxa o jogador
	ok = await _ate(func(): return nivel.janela_aberta, 1500)
	_checar(ok, "lance 3: o boto sinaliza")
	_checar(nivel.fase == nivel.Fase.JANELA, "janela do 3º lance")
	var pos0: Vector3 = player.global_position
	await _apertar_lancar()
	ok = await _ate(func(): return nivel.fase == nivel.Fase.PUXADO, 600)
	_checar(ok, "o 3º lance puxa: fase PUXADO")
	_checar(nivel.tainhas == tainhas_antes, "o 3º lance não pega tainhas")
	_checar(not player.pode_mover, "jogador não controla mais nada")
	ok = await _ate(func(): return player.global_position.z < nivel.MARGEM_Z - 1.0, 900)
	_checar(ok, "o jogador é arrastado para dentro da água (z=%.1f)" % player.global_position.z)
	ok = await _ate(func(): return player.global_position.y < -1.0, 600)
	_checar(ok, "a câmera afunda (y=%.1f)" % player.global_position.y)
	ok = await _ate(func(): return nivel._cortina.color.a > 0.5, 600)
	_checar(ok, "a tela escurece")
	_checar(abs(GS.corruption - 0.5) < 0.02, "corruption sobe no rio (%.2f)" % GS.corruption)

	# tremida do contador
	var base: Vector2 = nivel._hud_pos
	nivel._tremer_contador()
	_checar(Ef._pulso > 0.1, "o contador treme com pulso de glitch")
	await _ate(func(): return not nivel._shake_ativo, 600)
	await _frames(5)
	_checar(main.hud.lbl_sala.position.distance_to(base) < 0.5, "contador volta à posição")

	# fala final da Tainá e volta ao Castelinho (aqui: nível de teste)
	ok = await _ate(func():
		Gui.avancar()
		return main.nivel_atual == "res://world/niveis/teste.tscn" and not nivel_vivo(), 2400)
	_checar(ok, "volta ao nível de destino")
	await _frames(30)
	_checar(GS.flag("viu_flashback_barra") == true, "flag viu_flashback_barra")
	_checar(GS.sala_atual == 15, "entra na sala 15 (sala %d)" % GS.sala_atual)
	_checar(GS.corruption_manual == -1.0, "corruption manual liberada ao sair")
	_checar(main.hud.lbl_sala.text == "SALA 15", "HUD mostra SALA 15")


func nivel_vivo() -> bool:
	return is_instance_valid(nivel) and nivel.is_inside_tree()


func _passada_auto() -> void:
	print("-- barra: 3º lance sozinho (jogador não lança)")
	GS.set_flag("viu_flashback_barra", false)
	await _carregar()
	nivel.lance_inicial = 3
	var ok: bool = await _ate(func():
		Gui.avancar()
		return nivel.fase != nivel.Fase.INTRO, 1500)
	_checar(ok, "intro terminou")
	_checar(nivel.lances == 2, "começa direto no 3º lance (lances=%d)" % nivel.lances)
	ok = await _ate(func(): return nivel.fase == nivel.Fase.PUXADO, 1800)
	_checar(ok, "sem lançar, a rede se lança sozinha e puxa")
	ok = await _ate(func():
		Gui.avancar()
		return main.nivel_atual == "res://world/niveis/teste.tscn", 2400)
	_checar(ok, "e a cena volta ao destino")
	_checar(GS.flag("viu_flashback_barra") == true and GS.sala_atual == 15, "flag e sala 15")
