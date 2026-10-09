extends SceneTree
## Capturas das cenas das visitas 3 e 4 do Castelinho (precisa de renderização: xvfb-run). Fora do CI. Uso:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tests/captura_visitas.gd -- <modo> <pasta_saida>
## Modos (um por execução, cada um sobe o jogo do zero):
##   folha    visita 3, corredor de 1975: abre a porta final -> folha "TITO 6..9", fala engasgada, fade para a V4
##            (v3_folha_1_aberta, v3_folha_2_fala, v3_folha_3_fade [, v3_folha_4_v4])
##   tito     visita 4, sala 74: Tito de costas no fim do corredor (v4_tito_costas, v4_tito_costas_perto)
##   pegadas  visita 4, sala 77: pegadas molhadas (v4_pegadas_geral, v4_pegadas_chao)
##   susto18  _susto_castelo V3 sala 18 (v3_susto18);  susto22  V4 sala 22 (v4_susto22): um frame no pico
## Chama as funções reais do nível (_abrir_porta_final, _entrou, _evt_*). O jogador fica parado; câmera = a do jogador.
## ATENÇÃO: escreve em user://save.json (como o jogo). Não rode junto com outros testes que mexem em save.

var gs: Node
var main: Node
var pasta := ""
var nivel: Node3D
var player: Node3D


func _initialize() -> void:
	_rodar.call_deferred()


func _foto(nome: String, frames := 6) -> void:
	for i in frames:
		await process_frame
	root.get_texture().get_image().save_png("%s/%s.png" % [pasta, nome])
	print("foto: ", nome)


func _esperar(seg: float) -> void:
	await create_timer(seg, true).timeout


## Sobe o Castelinho na visita pedida (como captura_cam.gd: define gs.visita antes de montar o nível).
func _subir(visita: int, epoca: int, corr := 0.0) -> void:
	root.size = Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	gs.jogando = false
	gs.visita = visita
	gs.flags["tem_lanterna"] = true
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	main.hud.visible = false
	gs.definir_corruption_manual(corr)
	gs.trocar_epoca(epoca)
	nivel = main.mundo.get_child(0)
	player = main.player
	player.collision_layer = 0          # os gatilhos de sala não veem o jogador: chamamos _entrou() à mão
	for i in 20:
		await process_frame


## Põe o jogador com os PÉS em `pos`, olhando para `alvo` (yaw no corpo, pitch na cabeça).
func _olhar(pos: Vector3, alvo: Vector3) -> void:
	player.global_position = pos
	var olho := pos + Vector3(0, 1.6, 0)
	var d := alvo - olho
	player.rotation.y = atan2(-d.x, -d.z)
	player.cabeca.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())


func _rodar() -> void:
	var a := OS.get_cmdline_user_args()
	var modo: String = a[0]
	pasta = a[1]
	DirAccess.make_dir_recursive_absolute(pasta)
	match modo:
		"folha": await _folha()
		"tito": await _tito()
		"pegadas": await _pegadas()
		"susto18": await _susto18()
		"susto22": await _susto22()
	quit()


func _folha() -> void:
	await _subir(3, 1)        # época 1 = 1975
	gs.set_flag("visor_travado", true)
	var x: float = nivel.X_COR
	_olhar(Vector3(x, 0.05, -55.0), Vector3(x, 1.4, -62.0))      # perto da porta do fim do corredor
	for i in 10:
		await process_frame
	await _foto("v3_folha_0_corredor", 2)
	nivel._abrir_porta_final(null)        # = atravessar a porta: _fim_de_visita() -> _beat_final_v3()
	await _esperar(1.2)
	await _foto("v3_folha_1_aberta", 4)
	await _esperar(1.5)
	await _foto("v3_folha_1b_aberta", 2)
	var Painel = load("res://ui/painel_ui.gd")
	if Painel.atual != null and is_instance_valid(Painel.atual):
		Painel.atual.fechar()
	await _esperar(1.6)
	await _foto("v3_folha_2_fala", 2)
	await _esperar(1.6)
	await _foto("v3_folha_2b_fala", 2)
	await _esperar(2.5)
	await _foto("v3_folha_2c_fala", 2)
	# fala engasgada termina sozinha (ou avança com o Guia): empurra até o fade
	var guia := root.get_node("/root/Guia")
	for i in 40:
		guia.avancar()
		await _esperar(0.35)
		var tr := root.get_node("/root/Transicao")
		if tr.ocupado:
			break
	await _foto("v3_folha_3_fade", 2)
	await _esperar(2.5)
	await _foto("v3_folha_4_v4", 2)


func _tito() -> void:
	await _subir(4, 3, 0.3)       # época 3 = 2020
	nivel._entrou(10)             # sala 74 (base 10): cria o Tito de costas
	await process_frame
	var t: Node3D = nivel._tito_corredor
	print("tito: ", t, " pos ", t.global_position if t else "?")
	# parado no checkpoint do corredor, olhando para o leste; zera o contador "olhado" para ele não sumir
	var P := Vector3(-15.5, 0.05, -21.8)
	_olhar(P, Vector3(-7.6, 1.0, -21.8))
	for i in 10:
		nivel._tito_corredor_olhado = 0.0
		await process_frame
	nivel._tito_corredor_olhado = 0.0
	await _foto("v4_tito_costas", 1)
	_olhar(Vector3(-11.5, 0.05, -21.8), Vector3(-7.6, 0.9, -21.8))
	for i in 8:
		nivel._tito_corredor_olhado = 0.0
		await process_frame
	await _foto("v4_tito_costas_perto", 1)
	# visto da entrada do corredor (oeste), um pouco de lado, como o jogador chega
	_olhar(Vector3(-22.5, 0.05, -21.8), Vector3(-7.6, 1.0, -21.8))
	for i in 8:
		nivel._tito_corredor_olhado = 0.0
		await process_frame
	await _foto("v4_tito_costas_longe", 1)


func _pegadas() -> void:
	await _subir(4, 3, 0.3)
	nivel._entrou(13)             # sala 77 (base 13): as pegadas aparecem
	await process_frame
	print("pegadas visiveis: ", nivel._pegadas_v4.visible)
	_olhar(Vector3(-5.4, 0.05, -17.2), Vector3(-8.2, 0.9, -14.6))
	for i in 10:
		await process_frame
	await _foto("v4_pegadas_geral", 1)
	_olhar(Vector3(-6.0, 0.05, -16.6), Vector3(-7.6, 0.0, -15.5))
	player.cabeca.rotation.x = -0.75
	for i in 10:
		await process_frame
	await _foto("v4_pegadas_chao", 1)
	_olhar(Vector3(-8.7, 0.05, -16.9), Vector3(-8.0, 0.0, -14.9))
	player.cabeca.rotation.x = -0.9
	for i in 10:
		await process_frame
	await _foto("v4_pegadas_chao2", 1)
	_olhar(Vector3(-8.7, 0.05, -15.8), Vector3(-8.7, 1.3, -14.2))   # o mural (Cam_pescador)
	for i in 10:
		await process_frame
	await _foto("v4_pegadas_mural", 1)


## Dispara o susto real (via _entrou -> _evt_salaNN -> _susto_castelo) e fotografa quando a Figura aparece.
func _susto(nome: String, base: int, pos: Vector3, alvo: Vector3) -> void:
	_olhar(pos, alvo)
	var antes := nivel.get_children()
	nivel._entrou(base)
	var t0 := Time.get_ticks_msec()
	var t := 0.0
	var achou := false
	while t < 8.0:
		await process_frame
		t = (Time.get_ticks_msec() - t0) / 1000.0
		for c in nivel.get_children():
			if not antes.has(c) and c is Node3D and c.get_script() != null \
					and str(c.get_script().resource_path).ends_with("figura_branca.gd"):
				achou = true
		if achou:
			break
	print(nome, ": figura apareceu=", achou, " em t=", t)
	await _foto(nome, 3)
	await _esperar(1.0)


func _susto18() -> void:
	await _subir(3, 3, 0.2)
	# V3 sala 18: hall do andar de cima, olhando para o oeste ao longo do hall
	await _susto("v3_susto18", 18, Vector3(-8.2, 3.45, -12.6), Vector3(-15.0, 4.8, -12.6))


func _susto22() -> void:
	await _subir(4, 3, 0.3)
	await _susto("v4_susto22", 22, Vector3(-15.4, 0.05, -28.0), Vector3(-10.0, 1.6, -28.0))
