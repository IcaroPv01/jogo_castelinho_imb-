extends SceneTree
## Captura da cidade (Módulo 14; precisa de renderização: xvfb-run; fora do CI). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_cidade.gd -- <modo> <saida.png> [giro_graus] [largura altura]
## Modo extra da ponte: ponte@X,Z,GIRO[,PITCH[,QUADROS[,virar]]] (põe o jogador em X,Z olhando para GIRO graus, espera QUADROS de física;
##        'virar' = depois de esperar, gira 180 graus para trás e espera mais 3 quadros)
## Modos: casas | barra | ponte | praia | rodoviaria (visto do Spawn; `giro_graus` gira a câmera) | placa (a placa 3D na calçada)
##        folheto (o roteiro aberto, visita 4 com a 'casas' feita) | portao (o portão de volta, de perto)
## ATENÇÃO: escreve em user://save.json (como o jogo).

var gs: Node
var main: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	var extra := PackedStringArray()
	if modo.begins_with("ponte@"):
		extra = modo.substr(6).split(",")
		modo = "ponte"
	var saida: String = a[1]
	var giro: float = float(a[2]) if a.size() >= 3 else 0.0
	root.size = Vector2i(int(a[3]), int(a[4])) if a.size() >= 5 else Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.visita = 4
	gs.set_flag("tem_visor", true)
	gs.set_flag("cidade_casas_feito", true)
	gs.ganhar_disco(gs.Epoca.E1967)
	gs.jogando = true
	main.hud.visible = true
	main.set_process(false)      # sem mouse capturado (xvfb) o main pausaria o jogo
	if modo in gs.CIDADE_ORDEM or modo == "portao":
		var id: String = "casas" if modo == "portao" else modo
		await main.carregar_mundo(gs.CIDADE[id]["cena"], "Spawn")
		for i in 12:
			await physics_frame
		var nivel: Node = main.mundo.get_child(0)
		main.player.rotation.y += deg_to_rad(giro)
		if extra.size() >= 3:
			main.player.global_position = Vector3(float(extra[0]), 0.1, float(extra[1]))
			main.player.rotation.y = deg_to_rad(float(extra[2]))
			main.player.cabeca.rotation.x = deg_to_rad(float(extra[3])) if extra.size() >= 4 else 0.0
			for i in (int(extra[4]) if extra.size() >= 5 else 10):
				await physics_frame
			if extra.size() >= 6 and extra[5] == "virar":
				main.player.rotation.y += PI
				for i in 3:
					await physics_frame
		if modo == "portao":
			var p: Node3D = nivel.find_child("Portao", true, false)
			main.player.global_position = p.global_position + p.global_transform.basis.z * 3.0
			main.player.look_at(p.global_position + Vector3(0, 1.5, 0), Vector3.UP)
			main.player.rotation.x = 0.0
			main.player.rotation.z = 0.0
	else:
		gs.entrar_sala(67)
		await main.carregar_mundo(gs.CENA_CASTELINHO, "Spawn_volta_cidade")
		for i in 12:
			await physics_frame
		if modo == "folheto":
			load("res://ui/placa_cidade.gd").abrir(true)
		else:
			main.player.rotation.y += deg_to_rad(giro)
	for i in 10:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("foto: ", saida)
	quit(0)
