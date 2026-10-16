extends SceneTree
## Captura do Calçadão da Barra (Módulo 14; precisa de renderização: xvfb-run; fora do CI). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cidade_barra.gd -- <saida.png> <x> <z> <yaw_graus> <pitch_graus> [estado] [dusk 0..1] [largura altura]
## estado: nada | pesca (começa a pesca e espera o boto bater a cabeça) | cheia (rede cheia, pescador com "!") | lance (logo depois do lance 1)
## yaw 0 = olha para -z (o rio); -90 = olha para +x (leste). ATENÇÃO: escreve em user://save.json (como o jogo).

var gs: Node
var main: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var saida: String = a[0]
	var x: float = float(a[1])
	var z: float = float(a[2])
	var yaw: float = float(a[3])
	var pitch: float = float(a[4])
	var estado: String = a[5] if a.size() > 5 else "nada"
	var dusk: float = float(a[6]) if a.size() > 6 else 0.0
	root.size = Vector2i(int(a[7]), int(a[8])) if a.size() > 8 else Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.visita = 3
	gs.jogando = true
	main.hud.visible = true
	main.set_process(false)
	await main.carregar_mundo(gs.CIDADE["barra"]["cena"], "Spawn")
	for i in 12:
		await physics_frame
	var nivel: Node = main.mundo.get_child(0)
	nivel.pulou_intro = true
	root.get_node("/root/Guia").cancelar()
	nivel._t = dusk * nivel.DUSK_SEG / nivel.DUSK_MAX if dusk > 0.0 else 0.0
	main.player.global_position = Vector3(x, 0.1, z)
	main.player.rotation.y = deg_to_rad(yaw)
	main.player.cabeca.rotation.x = deg_to_rad(pitch)
	if estado == "pesca" or estado == "lance":
		nivel.espera_min = 0.3
		nivel.espera_max = 0.4
		nivel.comecar_pesca()
		for i in 600:
			await physics_frame
			if nivel.janela_aberta:
				break
		if estado == "lance":
			nivel.lancar()
			for i in 40:
				await physics_frame
	elif estado == "cheia":
		nivel.rede_cheia = true
		nivel._pilha.visible = true
		nivel._atualizar_objetivo()
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("foto: ", saida)
	quit(0)
