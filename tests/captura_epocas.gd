extends SceneTree
## Capturas das épocas distintas (2019 abandonado, faixa do presente, Tito fantasma, legenda do Visor). Precisa de
## renderização: xvfb-run. Fora do CI. Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_epocas.gd -- <modo> <pasta>
## Modos (um por execução, cada um sobe o jogo do zero):
##   v1   visita 1: frente 2019, leste 2019 (cartaz/pichação), Sala Medieval 2019, hall 2019, frente do presente (faixa)
##   v3   visita 3: faixa rasgada, Tito fantasma em 2019 e em 1975
##   visor  visita 3: legenda do Visor em 1967 (com o subtítulo)
## O jogador fica parado; a câmera é um marcador livre (como tests/captura_cam.gd).

var gs: Node
var main: Node
var pasta := ""
var nivel: Node3D
var cam: Camera3D


func _initialize() -> void:
	_rodar.call_deferred()


func _subir(visita: int) -> void:
	root.size = Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.jogando = false
	gs.visita = visita
	gs.flags["tem_lanterna"] = visita >= 3
	gs.flags["tem_visor"] = true
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	main.hud.visible = false
	nivel = main.mundo.get_child(0)
	main.player.pode_mover = false
	main.player.collision_layer = 0
	cam = Camera3D.new()
	cam.keep_aspect = Camera3D.KEEP_WIDTH
	cam.near = 0.05
	cam.far = 400.0
	nivel.add_child(cam)


func _foto(nome: String, epoca: int, pos: Vector3, alvo: Vector3, fov := 70.0, esperar := 14) -> void:
	gs.trocar_epoca(epoca)
	cam.global_position = pos
	cam.look_at(alvo)
	cam.fov = fov
	cam.current = true
	main.player.global_position = pos - Vector3(0, 1.55, 0)
	if main.player.lanterna.visible and main.player.lanterna.get_parent() != cam:
		main.player.lanterna.reparent(cam, false)
	if nivel.has_method("_atualizar_luzes"):
		nivel._atualizar_luzes()
	for i in esperar:
		root.get_node("/root/Guia").cancelar()
		await process_frame
	var arq := "%s/%s.png" % [pasta, nome]
	root.get_texture().get_image().save_png(arq)
	print("foto: ", arq)


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	pasta = a[1]
	DirAccess.make_dir_recursive_absolute(pasta)
	var E: Dictionary = {"1950": 0, "1975": 1, "2019": 2, "2020": 3, "1967": 4}
	match modo:
		"v1":
			await _subir(1)
			await _foto("2019_frente", E["2019"], Vector3(2.5, 1.6, -7.5), Vector3(-10.5, 1.8, -11.0), 62.0)
			await _foto("2019_frente_aerea", E["2019"], Vector3(-27.0, 14.0, 13.0), Vector3(-14.0, 3.0, -17.0), 66.0)
			await _foto("2019_frente_porta", E["2019"], Vector3(-7.5, 1.6, -5.0), Vector3(-8.0, 1.8, -11.0), 70.0)
			await _foto("2019_choperia", E["2019"], Vector3(-1.0, 2.2, -8.8), Vector3(-11.7, 2.7, -11.0), 40.0)
			await _foto("2019_leste", E["2019"], Vector3(3.0, 1.6, -11.0), Vector3(-5.0, 1.2, -15.0), 62.0)
			await _foto("2019_leste_perto", E["2019"], Vector3(-1.0, 1.5, -14.0), Vector3(-5.0, 1.1, -14.55), 60.0)
			await _foto("2019_sala_medieval", E["2019"], Vector3(-12.6, 1.55, -23.8), Vector3(-12.0, 0.8, -27.5), 80.0)
			await _foto("2019_sala_medieval_b", E["2019"], Vector3(-15.0, 1.55, -24.2), Vector3(-9.5, 0.8, -28.0), 80.0)
			await _foto("2019_hall", E["2019"], Vector3(-5.7, 1.55, -12.6), Vector3(-15.0, 1.0, -12.9), 72.0)
			await _foto("2020_v1_frente", E["2020"], Vector3(-10.0, 1.6, 4.0), Vector3(-10.5, 2.0, -11.0), 62.0)
			await _foto("2020_v1_faixa", E["2020"], Vector3(-17.5, 1.6, 0.0), Vector3(-12.3, 1.9, -9.0), 55.0)
		"v3":
			await _subir(3)
			await _foto("2020_v3_faixa_rasgada", E["2020"], Vector3(-17.5, 1.6, 0.0), Vector3(-12.3, 1.9, -9.0), 55.0)
			# o Tito do Visor na posição da sala 7 (hall) da visita 3, a 3 m da câmera
			var t: Node3D = nivel._tito_visor
			t.position = Vector3(-12.0, 0.0, -24.8)
			await _foto("2019_tito_fantasma", E["2019"], Vector3(-12.9, 1.4, -22.0), Vector3(-12.0, 0.8, -24.8), 55.0, 30)
			await _foto("1975_tito_fantasma", E["1975"], Vector3(-12.9, 1.4, -22.0), Vector3(-12.0, 0.8, -24.8), 55.0, 30)
			await _foto("1967_sem_fantasma", E["1967"], Vector3(-12.9, 1.4, -22.0), Vector3(-12.0, 0.8, -24.8), 55.0, 6)
		"visor":
			await _subir(3)
			var ef: Node = root.get_node("/root/Efeitos")
			ef.visor(true)
			await _foto("visor_1967", E["1967"], Vector3(-10.0, 1.6, 4.0), Vector3(-10.5, 2.0, -11.0), 62.0, 20)
			await _foto("visor_2019", E["2019"], Vector3(-10.0, 1.6, 4.0), Vector3(-10.5, 2.0, -11.0), 62.0, 20)
	quit()
