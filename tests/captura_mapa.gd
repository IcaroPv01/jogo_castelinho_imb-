extends SceneTree
## Captura do Mapa da Visita (precisa de renderização: xvfb-run; fora do CI). Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_mapa.gd -- <modo> <saida.png> [largura altura]
## Modos: v1 (térreo, hall) | v1_cima (andar de cima) | v2 | v3 | v4 | v4_torre | porao | ato2 | sem (nível de teste)
## ATENÇÃO: escreve em user://save.json (como o jogo).

var gs: Node
var main: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	var saida: String = a[1]
	var tam := Vector2i(int(a[2]), int(a[3])) if a.size() >= 4 else Vector2i(1280, 720)
	root.size = tam
	gs = root.get_node("/root/GameState")
	var MapaC = load("res://ui/mapa.gd")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	var nivel := "res://world/niveis/castelinho.tscn"
	var pos := Vector3(-10.4, 0.2, -12.6)
	var yaw := 0.0
	var sala_max := 7
	match modo:
		"v1":
			gs.visita = 1
			gs.set_flag("passaporte_lancado", true)
			gs.set_flag("passaporte_pedra", true)
		"v1_cima":
			gs.visita = 1
			sala_max = 18
			pos = Vector3(-10.4, 3.7, -12.6)
			yaw = PI / 2.0
		"v2":
			gs.visita = 2
			sala_max = 33
			pos = Vector3(-9.8, 0.2, -18.8)
			yaw = PI
		"v3":
			gs.visita = 3
			gs.set_flag("tem_lanterna", true)
			sala_max = 50
			pos = Vector3(-15.5, 0.2, -21.8)
			yaw = -PI / 2.0
		"v4":
			gs.visita = 4
			gs.set_flag("tem_lanterna", true)
			sala_max = 71
			pos = Vector3(-20.5, 0.2, -17.2)
			yaw = PI * 0.75
		"v4_torre":
			gs.visita = 4
			gs.set_flag("tem_lanterna", true)
			gs.ganhar_disco(gs.Epoca.E2019)
			sala_max = 77
			pos = Vector3(-19.0, 7.0, -12.4)
		"porao":
			gs.visita = 5
			nivel = "res://world/niveis/porao.tscn"
			sala_max = 83
		"ato2":
			gs.visita = 3
			nivel = "res://world/niveis/ato2.tscn"
			sala_max = 57
		"sem":
			nivel = "res://world/niveis/teste.tscn"
	gs.jogando = true
	main.hud.visible = false
	await main.carregar_mundo(nivel, "Spawn")
	for i in 8:
		await physics_frame
	var jog: Node3D = main.player
	if modo.begins_with("v") and jog:
		jog.global_position = pos
		jog.rotation.y = yaw
	for s in range(1, sala_max + 1):
		if modo.begins_with("v") and gs.visita_da_sala(s) == gs.visita or modo == "porao" or modo == "ato2":
			gs.entrar_sala(s)
	if modo == "v1":
		gs.entrar_sala(7)
	gs.jogando = true
	MapaC.abrir(true)
	for i in 14:
		await process_frame
	root.get_texture().get_image().save_png(saida)
	print("foto: ", saida)
	quit(0)
