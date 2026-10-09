extends SceneTree
## Teste automático (headless) do modo debug (módulo 9): desligado por padrão, save à parte, imortal, painel, gesto do
## título, e os pulos (visita/sala e finais).
## Uso: godot --headless -s res://tests/debug_test.gd

var falhas := 0
var GS: Node
var main: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _ler(caminho: String) -> String:
	if not FileAccess.file_exists(caminho):
		return ""
	return FileAccess.get_file_as_string(caminho)


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	_teste_padrao()
	var normal_antes := _preparar_save_normal()
	await _teste_gesto_titulo()
	_teste_save_separado(normal_antes)
	_teste_imortal()
	await _teste_painel()
	_teste_destinos()
	await _teste_pulos()
	_teste_desligar(normal_antes)
	Debug.ligado = false
	Debug.imortal = false
	Debug.info = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Debug.ARQUIVO_SAVE))
	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _teste_padrao() -> void:
	print("-- desligado por padrão")
	_checar(not Debug.ligado, "Debug.ligado começa falso")
	_checar(not Debug.imortal and not Debug.figura_off and not Debug.atencao_congelada and not Debug.info, "todas as chaves começam desligadas")
	_checar(GS.arquivo_save() == GS.ARQUIVO_SAVE, "com o debug desligado o save é o normal (%s)" % GS.arquivo_save())
	_checar(not Debug.detectar(), "detectar() sem --debug nem ?debug=1 continua desligado")


## Grava um save normal conhecido e devolve o texto do arquivo.
func _preparar_save_normal() -> String:
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Debug.ARQUIVO_SAVE))
	GS.novo_jogo()
	GS.set_flag("marca_normal", true)
	return _ler(GS.ARQUIVO_SAVE)


func _teste_gesto_titulo() -> void:
	print("-- gesto escondido no título (5 toques no contador)")
	var t: Control = load("res://ui/tela_titulo.tscn").instantiate()
	root.add_child(t)
	await process_frame
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	for i in 4:
		t._toque_no_contador(clique)
	_checar(not Debug.ligado, "4 toques não ligam")
	t._toque_no_contador(clique)
	_checar(Debug.ligado, "o 5º toque liga o debug")
	_checar(GS.arquivo_save() == Debug.ARQUIVO_SAVE, "e o save passa a ser o de debug")
	_checar(not GS.flag("marca_normal"), "o estado em memória não herda o save normal")
	t.queue_free()
	await process_frame


func _teste_save_separado(normal_antes: String) -> void:
	print("-- save separado")
	GS.set_flag("marca_debug", true)
	_checar(FileAccess.file_exists(Debug.ARQUIVO_SAVE), "o save de debug existe")
	_checar(_ler(Debug.ARQUIVO_SAVE).contains("marca_debug"), "a flag foi para o save de debug")
	_checar(_ler(GS.ARQUIVO_SAVE) == normal_antes, "o save normal ficou intacto")
	GS.ganhar_selo("selo_debug")
	GS.entrar_sala(10)
	_checar(_ler(GS.ARQUIVO_SAVE) == normal_antes, "o save normal segue intacto depois de salvar mais")
	GS.recarregar_save()
	_checar(GS.flag("marca_debug", false) and not GS.flag("marca_normal"), "recarregar_save lê o arquivo de debug")


func _teste_imortal() -> void:
	print("-- imortal")
	var mortes := [0]
	var antes: int = int(GS.contadores.get("mortes", 0))
	GS.jogador_morreu.connect(func(_c): mortes[0] += 1)
	Debug.imortal = true
	GS.matar_jogador("teste")
	_checar(mortes[0] == 0, "imortal: o sinal jogador_morreu não sai")
	_checar(int(GS.contadores.get("mortes", 0)) == antes, "imortal: o contador de mortes não sobe")
	Debug.imortal = false
	GS.matar_jogador("teste")
	_checar(mortes[0] == 1 and int(GS.contadores.get("mortes", 0)) == antes + 1, "sem imortal: morre normalmente")
	Debug.definir_chave("figura_off", true)
	_checar(Debug.figura_off and Debug.chave("figura_off"), "definir_chave/chave mexem na variável")
	Debug.definir_chave("figura_off", false)


func _teste_painel() -> void:
	print("-- painel")
	var ev := InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_APOSTROPHE
	_checar(Debug.tecla_painel(ev), "apóstrofo abre")
	ev = InputEventKey.new()
	ev.pressed = true
	ev.physical_keycode = KEY_QUOTELEFT
	_checar(Debug.tecla_painel(ev), "tecla física à esquerda do 1 (ABNT2) abre")
	ev = InputEventKey.new()
	ev.pressed = true
	ev.keycode = KEY_A
	_checar(not Debug.tecla_painel(ev), "outra tecla não abre")
	var p: CanvasLayer = load("res://ui/painel_debug.gd").new()
	root.add_child(p)
	for i in 3:
		await process_frame
	_checar(not p.aberto, "o painel nasce fechado")
	p.abrir()
	_checar(p.aberto and p._caixa.visible, "abrir mostra a caixa")
	(p._checks["imortal"] as CheckBox).button_pressed = true
	_checar(Debug.imortal, "marcar 'Imortal' liga a chave")
	(p._checks["imortal"] as CheckBox).button_pressed = false
	_checar(not Debug.imortal, "desmarcar desliga")
	Debug.info = true
	await process_frame
	await process_frame
	_checar(p._info.visible, "com info ligada o texto aparece")
	var txt: String = p.texto_info()
	_checar(txt.contains("sala") and txt.contains("época") and txt.contains("visita") and txt.contains("qps"), "texto de info: '%s'" % txt)
	Debug.info = false
	p.fechar()
	_checar(not p.aberto and not p._caixa.visible, "fechar esconde")
	Debug.ganhar_tudo()
	_checar(GS.discos.size() == 5 and GS.flag("tem_visor") and GS.flag("tem_lanterna"), "ganhar tudo: 5 discos, Visor e lanterna")
	p.queue_free()
	await process_frame


func _teste_destinos() -> void:
	print("-- onde o pulo cai")
	var casos := [
		[0, 12, 10, "castelinho", 1], [0, 1, 1, "castelinho", 1], [0, 22, 16, "castelinho", 1],
		[1, 23, 23, "castelinho", 2], [1, 40, 38, "castelinho", 2],
		[2, 50, 45, "castelinho", 3], [2, 57, 55, "ato2", 3], [2, 66, 61, "castelinho", 3],
		[3, 80, 77, "castelinho", 4], [3, 70, 67, "castelinho", 4],
		[4, 97, 96, "porao", 5], [4, 81, 81, "porao", 5], [5, 100, 100, "braco_morto", 5],
	]
	for c in casos:
		var d: Dictionary = Debug.destino(c[0], c[1])
		_checar(d["cp"] == c[2] and String(d["cena"]).contains(c[3]) and d["visita"] == c[4],
			"lugar %d sala %d -> checkpoint %d (%s), visita %d [%s]" % [c[0], c[1], d["cp"], String(d["cena"]).get_file(), d["visita"], d["texto"]])
	_checar(Debug.destino(0, 99)["sala"] == 22, "sala fora da faixa do lugar é limitada")
	_checar(Debug.lugar_da_sala(100) == 5 and Debug.lugar_da_sala(30) == 1, "lugar_da_sala")


func _novo_main() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()


func _teste_pulos() -> void:
	print("-- pulos de verdade")
	await _novo_main()
	_checar(main.get_node_or_null("PainelDebug") != null, "com o debug ligado o main cria o painel")
	await Debug.pular(1, 33)
	_checar(main.nivel_atual == GS.CENA_CASTELINHO and GS.visita == 2 and GS.checkpoint_sala == 32, "visita 2 sala 33 -> castelinho, visita 2, checkpoint 32")
	_checar(GS.jogando and main.player != null, "jogo rodando com jogador")
	for i in 20:
		await physics_frame
	await Debug.pular(2, 57)
	_checar(main.nivel_atual == GS.CENA_ATO2 and GS.visita == 3 and GS.checkpoint_sala == 55, "visita 3 sala 57 -> Ato II, checkpoint 55")
	await Debug.pular(4, 90)
	_checar(main.nivel_atual == GS.CENA_PORAO and GS.visita == 5 and GS.checkpoint_sala == 86, "porão sala 90 -> checkpoint 86")
	await Debug.pular(3, 70)
	_checar(main.nivel_atual == GS.CENA_CASTELINHO and GS.visita == 4 and GS.checkpoint_sala == 67, "visita 4 sala 70 -> checkpoint 67")
	# finais
	var nivel: Variant = await Debug.pular_final("encontrado")
	_checar(main.nivel_atual == GS.CENA_BRACO and nivel != null and nivel.cena_feita, "final encontrado: Braço Morto e a cena do Tito começou")
	_checar(GS.contadores.get("pistas_tito", 0) >= 8, "com 8 pistas (decide o 'Encontrado')")
	nivel = await Debug.pular_final("visita_concluida")
	_checar(nivel != null and nivel.cena_feita and GS.contadores.get("pistas_tito", 0) == 3, "final visita concluída: cena do Tito com 3 pistas")
	nivel = await Debug.pular_final("sala_101")
	_checar(nivel != null and nivel.encerrando and nivel.final == "sala_101", "final sala 101 dispara o afundar")
	main.queue_free()
	await process_frame


func _teste_desligar(normal_antes: String) -> void:
	print("-- desligar")
	Debug.imortal = true
	Debug.definir_ligado(false)
	_checar(not Debug.ligado and not Debug.imortal, "desligar apaga as chaves")
	_checar(GS.arquivo_save() == GS.ARQUIVO_SAVE and GS.flag("marca_normal"), "volta ao save normal e ao estado dele")
	_checar(_ler(GS.ARQUIVO_SAVE) == normal_antes, "o save normal terminou igual ao começo")
