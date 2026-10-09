extends SceneTree
## Captura de tela do modo celular (controles de toque, retrato). Não é um teste: precisa de renderização (xvfb).
## Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_celular.gd -- \
##       <saida.png> [largura altura] [modo]
## modo: castelinho (nível real, sala inicial; 5º argumento "desk" = sem modo celular, para comparar) | jogo (padrão: HUD + controles + faixa de discos) | fala (com balão da Guia) | pausa | opcoes | retrato

func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var saida: String = a[0]
	var w := int(a[1]) if a.size() > 2 else 844
	var h := int(a[2]) if a.size() > 2 else 390
	var modo: String = a[3] if a.size() > 3 else "jogo"
	var gs = root.get_node("/root/GameState")
	var Cel = load("res://ui/celular.gd")
	root.size = Vector2i(w, h)
	DisplayServer.window_set_size(Vector2i(w, h))
	var main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	var desk: bool = a.size() > 4 and a[4] == "desk"
	Cel.modo = "nunca" if desk else "sempre"   # (depois do HUD nascer: o Opcoes.carregar do HUD relê o modo do arquivo)
	Cel.detectar()
	gs.novo_jogo()
	gs.jogando = true
	gs.set_flag("tem_lanterna", true)
	gs.ganhar_disco(0)
	gs.ganhar_disco(4)
	gs.ganhar_disco(2)
	main.hud.visible = true
	var nivel := "res://world/niveis/castelinho.tscn" if modo == "castelinho" else "res://world/niveis/teste.tscn"
	await main.carregar_mundo(nivel, a[5] if a.size() > 5 else "Spawn")
	if desk:
		main.set_process(false)   # desktop sem mouse capturado pausaria sozinho: congela o main para a captura
	load("res://world/visor.gd").instalar(main.mundo)
	Cel.pausa_toque = false
	if desk:
		paused = false
	if modo == "fala":
		root.get_node("/root/Guia").falar("bentinho", ["Oi! Eu sou o Bentinho! Toque nos discos para trocar de época."], false)
	if a.size() > 4 and a[4] == "full3d":   # comparar a nitidez com e sem o 3D a 70%
		root.scaling_3d_scale = 1.0
	for i in 50:
		await process_frame
	if modo == "pausa" or modo == "opcoes":
		Cel.pausa_toque = true
		main._atualizar_pausa()
		if modo == "opcoes":
			main.hud.menu_pausa._ir("opcoes")
		for i in 10:
			await process_frame
	if modo == "retrato":
		root.size = Vector2i(h, w)
		DisplayServer.window_set_size(Vector2i(h, w))
		for i in 10:
			await process_frame
	await create_timer(0.5).timeout
	var img := root.get_texture().get_image()
	img.save_png(saida)
	print("3D scale: ", root.scaling_3d_scale, " fps max: ", Engine.max_fps)
	print("viewport: ", root.get_visible_rect().size, " escala: ", root.content_scale_factor, " imagem: ", img.get_size())
	Cel.modo = "auto"
	Cel.ativo = false
	quit()
