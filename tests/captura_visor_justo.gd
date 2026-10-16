extends SceneTree
## Captura do módulo 2, parte 3 (Visor justo): o Visor quase em tela cheia, a vinheta vermelha do medo e o feixe de luz de um achado.
## Rode com xvfb-run (não é teste):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_visor_justo.gd -- <pasta_saida>
## Gera <pasta>/visor_grande.png, visor_vinheta.png, visor_feixe.png e visor_feixe_longe.png.

var gs
var main


func _initialize() -> void:
	_rodar.call_deferred()


func _carregar(visita: int, discos: Array, disco_atual: int) -> Node:
	gs.novo_jogo()
	gs.jogando = false
	gs.visita = visita
	gs.flags["tem_visor"] = true
	gs.flags["tem_lanterna"] = visita >= 3
	gs.discos.assign(discos)
	gs.disco_atual = disco_atual
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	return main.mundo.get_child(0)


func _olhar(de: Vector3, alvo: Vector3) -> void:
	main.player.global_position = Vector3(de.x, 0.1, de.z)
	main.player.rotation_degrees.y = rad_to_deg(atan2(-(alvo.x - de.x), -(alvo.z - de.z)))
	main.player.cabeca.rotation_degrees.x = -rad_to_deg(atan2(1.6 - alvo.y, Vector2(alvo.x - de.x, alvo.z - de.z).length()))


func _quadros(n: int) -> void:
	for i in n:
		root.get_node("Guia").cancelar()
		await process_frame


func _rodar() -> void:
	var pasta: String = OS.get_cmdline_user_args()[0]
	root.size = Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.aquecer_ativo = false
	main.tela_titulo.queue_free()
	main.hud.visible = true

	# 1) o Visor grande: visita 2, disco 1950, olhando o terreno de 1950 da calçada
	var nivel = await _carregar(2, [0], 0)
	_olhar(Vector3(-23.0, 0.1, 1.5), Vector3(-10.0, 1.5, -12.0))
	var visor = nivel.get_node_or_null("Visor")
	visor.alternar()
	await create_timer(0.5).timeout
	await _quadros(30)
	root.get_texture().get_image().save_png("%s/visor_grande.png" % pasta)
	print("captura: visor_grande")

	# 2) a vinheta vermelha: visita 4, zona de perigo (sala 74), atenção alta congelada (debug) com o Q ligado
	nivel = await _carregar(4, [0, 4, 1, 2], 2)
	gs.sala_atual = 74
	var D = load("res://ui/debug.gd")
	D.atencao_congelada = true
	_olhar(Vector3(-15.5, 0.1, -21.0), Vector3(-9.0, 1.5, -21.8))
	visor = nivel.get_node_or_null("Visor")
	visor.alternar()
	await create_timer(0.4).timeout
	gs.definir_atencao(0.92)
	await create_timer(1.8).timeout
	await _quadros(20)
	root.get_texture().get_image().save_png("%s/visor_vinheta.png" % pasta)
	print("captura: visor_vinheta, medo=", root.get_node("Efeitos").medo)
	D.atencao_congelada = false
	gs.definir_atencao(0.0)

	# 3) o feixe de luz: a pilha de pedra a ~12 m, só no disco de 1950 (visita 2), Q ligado e depois a 20 m
	nivel = await _carregar(2, [0], 0)
	var raiz: Node3D = nivel.find_child("Caca_4_pedra_gres", true, false)
	var p := raiz.global_position
	visor = nivel.get_node_or_null("Visor")
	visor.alternar()
	_olhar(p + Vector3(2.0, 0, 11.5), p + Vector3(0, 3.0, 0))
	await create_timer(0.5).timeout
	await _quadros(40)
	root.get_texture().get_image().save_png("%s/visor_feixe.png" % pasta)
	print("captura: visor_feixe")
	_olhar(p + Vector3(6.0, 0, 18.0), p + Vector3(0, 3.0, 0))
	await _quadros(20)
	root.get_texture().get_image().save_png("%s/visor_feixe_longe.png" % pasta)
	print("captura: visor_feixe_longe")
	quit()
