extends SceneTree
## Capturas do módulo "água e sustos" (precisa de renderização: xvfb-run). Fora do CI. Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_agua_sustos.gd -- <modo> <pasta_saida>
## Modos (um por execução):
##   lampejo   visita 4, hall: água subindo no meio da subida (lampejo_hall_meio, lampejo_hall_pico)
##   goteiras  porão: sala 84 com gotas caindo e respingo (goteiras_*)
##   ferrugem  porão, sala 86 (alagada): água normal e água ferrugem (agua_normal, agua_ferrugem)
##   jornal    o recorte de jornal (jornal)
##   fantasma  visita 3, corredor: o fantasma do Tito no fundo (fantasma_*)
##   janela    visita 4, hall: a Figura fora da janela no relâmpago (janela_*)
## ATENÇÃO: escreve em user://save.json (como o jogo).

var gs: Node
var main: Node
var pasta := ""
var nivel: Node3D
var player: Node3D


func _initialize() -> void:
	_rodar.call_deferred()


func _foto(nome: String, frames := 4) -> void:
	root.get_node("/root/Guia").cancelar()
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [pasta, nome])
	print("foto: ", nome)


func _subir(cena: String, visita: int, epoca := 3, corr := 0.3) -> void:
	root.size = Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.novo_jogo()
	gs.jogando = false
	gs.visita = visita
	gs.flags["tem_lanterna"] = true
	await main.carregar_mundo(cena, "Spawn")
	main.hud.visible = false
	gs.definir_corruption_manual(corr)
	gs.trocar_epoca(epoca)
	nivel = main.mundo.get_child(0)
	player = main.player
	player.collision_layer = 0
	for i in 20:
		await process_frame
	root.get_node("/root/Guia").cancelar()


func _olhar(pos: Vector3, alvo: Vector3) -> void:
	player.global_position = pos
	var olho := pos + Vector3(0, 1.6, 0)
	var d := alvo - olho
	player.rotation.y = atan2(-d.x, -d.z)
	player.cabeca.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	pasta = a[1]
	DirAccess.make_dir_recursive_absolute(pasta)
	match a[0]:
		"lampejo": await _lampejo()
		"goteiras": await _goteiras()
		"ferrugem": await _ferrugem()
		"jornal": await _jornal()
		"fantasma": await _fantasma()
		"janela": await _janela()
	quit()


func _lampejo() -> void:
	await _subir("res://world/niveis/castelinho.tscn", 4)
	_olhar(Vector3(-9.0, 0.05, -12.6), Vector3(-15.0, 1.4, -12.6))
	for i in 10:
		await process_frame
	await _foto("lampejo_hall_0_antes", 1)
	var FA = load("res://world/flash_agua.gd")
	var raiz := Node3D.new()
	nivel.add_child(raiz)
	var partes: Dictionary = FA.montar(raiz, player.global_position)
	FA.posicionar(partes, 0.55, 0.45)
	await _foto("lampejo_hall_meio", 2)
	FA.posicionar(partes, 0.95, 0.6)
	await _foto("lampejo_hall_pico", 2)
	raiz.queue_free()
	# o fluxo real, com o clarão da tela: pega um quadro durante os lampejos
	FA.disparar(nivel)
	await create_timer(0.12, true).timeout
	await _foto("lampejo_hall_real", 1)


func _goteiras() -> void:
	await _subir("res://world/niveis/porao.tscn", 5)
	nivel.ameacas_ligadas = false
	gs.set_flag("tem_visor", true)
	var idx := 1                  # sala 82: corredor de abóbada
	nivel.ir_para_sala(idx)
	nivel.nivel_agua = 1
	nivel.prof = nivel.PROF_AGUA[1]
	for i in 20:
		await process_frame
	var c = nivel.salas[idx]
	var g: Node = c.raiz.get_node("Goteiras")
	var pt: Dictionary = g.pontos[0]
	_olhar(c.raiz.to_global(Vector3(0, 0.05, -0.8)), c.raiz.to_global(Vector3(0, 1.3, -9.0)))
	for i in 8:
		await process_frame
	await _foto("goteiras_0_sala", 1)
	# todas as gotas soltas ao mesmo tempo: no meio da queda e depois os respingos
	for p in g.pontos:
		g.soltar(p)
	await create_timer(0.3, true).timeout
	await _foto("goteiras_1_gota", 1)
	await create_timer(0.25, true).timeout
	for p in g.pontos:
		g.respingar(p)
	await create_timer(0.12, true).timeout
	await _foto("goteiras_2_respingo", 1)
	g.respingar(pt)
	var chao: Vector3 = c.raiz.to_global(Vector3(pt["x"], g.superficie(pt), pt["z"]))
	_olhar(chao + Vector3(0.0, 0.0, 1.6) + Vector3(0, 0.05, 0), chao)
	await create_timer(0.15, true).timeout
	await _foto("goteiras_3_respingo_perto", 1)
	print("pontos: ", g.pontos.size(), "  teto=", pt["teto"], "  sup=", g.superficie(pt))


func _ferrugem() -> void:
	await _subir("res://world/niveis/porao.tscn", 5)
	nivel.ameacas_ligadas = false
	nivel.ir_para_sala(5)         # sala 86: alagada, com a água subindo
	nivel.nivel_agua = 2
	nivel.prof = nivel.PROF_AGUA[2]
	var c = nivel.salas[5]
	var af: Node = nivel.get_node("AguaFerrugem")
	af.set_process(false)
	var pos: Vector3 = c.raiz.to_global(Vector3(0, 0.05, -1.0))
	_olhar(pos, c.raiz.to_global(Vector3(0, -0.2, -9.0)))
	af.quantidade = 0.0
	af._aplicar()
	for i in 14:
		await process_frame
	await _foto("agua_normal", 2)
	af.quantidade = 1.0
	af._aplicar()
	await _foto("agua_ferrugem", 2)
	af.quantidade = 0.5
	af._aplicar()
	await _foto("agua_meio", 2)


func _jornal() -> void:
	await _subir("res://world/niveis/castelinho.tscn", 3)
	var J = load("res://ui/jornal.gd")
	var j = J.mostrar()
	await create_timer(0.1, true).timeout
	for i in 3:
		await process_frame
	await create_timer(1.2, true).timeout
	await _foto("jornal_0", 1)
	j._t = 3.5
	await create_timer(1.0, true).timeout
	await _foto("jornal_1_dica", 1)


func _fantasma() -> void:
	await _subir("res://world/niveis/castelinho.tscn", 3)
	_olhar(Vector3(-17.0, 0.05, -21.9), Vector3(-8.3, 1.0, -21.9))
	for i in 8:
		await process_frame
	await _foto("fantasma_0_corredor", 1)
	var SC = load("res://world/niveis/sustos_caminho.gd")
	var f = SC.criar_fantasma()
	nivel.add_child(f)
	f.position = Vector3(-8.3, 0, -21.9)
	f.rotation.y = PI
	await _foto("fantasma_1_meio", 3)
	f.position = Vector3(-8.3, 0, -21.4)
	_olhar(Vector3(-12.0, 0.05, -21.9), Vector3(-8.3, 1.0, -21.9))
	await _foto("fantasma_2_perto", 3)
	f.queue_free()
	# o fluxo real
	nivel.get_node("SustosCaminho").forcar("v3_tito_corredor")
	_olhar(Vector3(-17.0, 0.05, -21.9), Vector3(-8.3, 1.0, -21.9))
	await create_timer(0.3, true).timeout
	await _foto("fantasma_3_real", 1)


func _janela() -> void:
	await _subir("res://world/niveis/castelinho.tscn", 4)
	_olhar(Vector3(-9.0, 0.05, -12.9), Vector3(-5.0, 1.55, -13.0))
	for i in 8:
		await process_frame
	await _foto("janela_0_sem", 1)
	var sc = nivel.get_node("SustosCaminho")
	sc.forcar("v4_relampago_janela")
	await create_timer(0.1, true).timeout
	await _foto("janela_1_relampago", 1)
	await create_timer(0.1, true).timeout
	await _foto("janela_2_relampago", 1)
