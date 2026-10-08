extends SceneTree
## Varredura QA (headless) do Braço Morto (sala 100), finais, dedicatória, volta ao título, Telefone e VolteSempre.
## Uso: timeout 300 godot --headless -s res://tests/varredura/braco.gd
## (não referencia classes do jogo por nome: usa load(); autoloads por root.get_node)

var falhas := 0
var GS
var main
var nivel
var player
const BRACO := "res://world/niveis/braco_morto.tscn"
const PORAO := "res://world/niveis/porao.tscn"
var achados: Array = []


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.set_flag("tem_visor", true)
	GS.comecar_visita(5)
	await _carregar()
	await _t_spawn()
	await _t_escada_e_borda()
	await _t_grade_de_queda()
	await _t_oito_direcoes()
	await _t_checkpoint()
	await _t_final("encontrado")
	await _t_final("visita_concluida")
	await _t_telefone()
	await _t_volte_sempre()
	await _t_volta_ao_titulo()
	Engine.time_scale = 1.0
	print("ACHADOS:")
	for a in achados:
		print("  - " + a)
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _achado(msg: String) -> void:
	achados.append(msg)
	print("  ACHADO " + msg)


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _carregar(spawn := "Spawn") -> void:
	await main.carregar_mundo(BRACO, spawn)
	nivel = main.mundo.get_child(0)
	player = main.player
	await _frames(12)


func _ir_para(p: Vector3, yaw := 0.0) -> void:
	player.global_position = p
	player.rotation.y = yaw
	player.cabeca.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	await _frames(10)


# ============================================================================
func _t_spawn() -> void:
	print("-- Braço: nasce no poço da escada")
	_checar(GS.sala_atual == 100, "sala 100 (sala %d)" % GS.sala_atual)
	_checar(player.is_on_floor(), "no chão do poço (y=%.2f)" % player.global_position.y)
	_checar(nivel.get_node_or_null("Spawn") != null, "marcador Spawn")


func _t_escada_e_borda() -> void:
	print("-- escada, gramado e borda do calçadão (z -3 a -8)")
	await _ir_para(Vector3(-14.0, -2.3, 12.4))
	Input.action_press("frente")
	await _ate(func(): return player.global_position.z < 5.0, 900)
	Input.action_release("frente")
	await _frames(20)
	_checar(player.is_on_floor() and player.global_position.y > -0.3, "a escada leva ao gramado (y=%.2f, z=%.1f)" % [player.global_position.y, player.global_position.z])
	# segue reto para o lago: o calçadão (z -8 a -3) não tem chão colidível?
	Input.action_press("frente")
	var caiu: bool = await _ate(func(): return player.global_position.y < -4.0, 900)
	Input.action_release("frente")
	print("   (diag) posição final: %s" % str(player.global_position))
	if caiu:
		_achado("A1 [A] Jogador anda reto do gramado para o lago e CAI sem fim: calçadão z -8..-3 sem colisão. Reproduzir: spawn -> subir escada -> andar em -Z. Ver world/niveis/braco_morto.gd _terreno() (_terra só vai de z -3; col da parede só z -9..-7.95)")
	_checar(not caiu, "andando para o lago o jogador não cai no vazio")
	await _ir_para(Vector3(0.0, 0.05, 0.0))


func _t_grade_de_queda() -> void:
	print("-- grade de queda: solta o jogador de 3 m em cada ponto (X = caiu, . = ficou em pé)")
	var xs := [-60, -48, -36, -24, -12, 0, 12, 24, 36, 48, 60]
	var zs := [-20, -14, -10, -8, -6, -4, -3, -2, 0, 4, 8, 12]
	var buracos_grama: Array = []
	var linhas: Array = []
	for z in zs:
		var linha := ""
		for x in xs:
			player.global_position = Vector3(x, 3.0, z)
			player.velocity = Vector3.ZERO
			await _frames(90)
			var y: float = player.global_position.y
			var em_pe: bool = y > -2.0
			linha += "." if em_pe else "X"
			if not em_pe and z >= -2:
				buracos_grama.append("(%d,%d)" % [x, z])
		linhas.append("z=%4d  %s" % [z, linha])
	print("   colunas x: -60 -48 -36 -24 -12 0 12 24 36 48 60")
	for l in linhas:
		print("   " + l)
	_checar(buracos_grama.is_empty(), "gramado sólido de z -2 a 12 (buracos: %s)" % str(buracos_grama))
	_checar(true, "grade feita (linhas z<-3 são o lago e o calçadão)")
	await _ir_para(Vector3(0.0, 0.05, 0.0))


func _t_oito_direcoes() -> void:
	print("-- oito direções, a partir de três pontos do gramado (1,5 s andando)")
	for ponto in [Vector3(-40, 0.05, 2), Vector3(0, 0.05, 2), Vector3(40, 0.05, 2)]:
		var linha := ""
		for k in 8:
			player.global_position = ponto
			player.rotation.y = k * PI / 4.0
			player.velocity = Vector3.ZERO
			await _frames(10)
			var p0: Vector3 = player.global_position
			Input.action_press("frente")
			await _frames(90)
			Input.action_release("frente")
			await _frames(5)
			var p1: Vector3 = player.global_position
			var d := Vector2(p1.x - p0.x, p1.z - p0.z).length()
			if p1.y < -4.0:
				linha += " %d:CAIU" % (k * 45)
			elif d < 0.5:
				linha += " %d:PRESO(%.1f)" % [k * 45, d]
			else:
				linha += " %d:ok(%.1f)" % [k * 45, d]
		print("   ponto %s ->%s" % [str(ponto), linha])
	await _ir_para(Vector3(0.0, 0.05, 0.0))


func _t_checkpoint() -> void:
	print("-- checkpoint 100 e Continuar")
	# o porão faz GameState.entrar_sala(100) ao sair (ele estava na 99)
	GS.checkpoint_sala = 96
	GS.sala_atual = 99
	GS.entrar_sala(100)
	_checar(GS.checkpoint_sala == 100, "entrar no Braço grava checkpoint 100 (está %d)" % GS.checkpoint_sala)
	if GS.checkpoint_sala != 100:
		_achado("A2 [M] Entrar no Braço Morto não grava checkpoint 100: SALAS_CHECKPOINT (autoload/game_state.gd) não tem 100 e porao.gd _ir_ao_braco_morto só chama entrar_sala(100). Resultado: Continuar depois de chegar ao Braço leva ao Porão (sala 96), não ao Braço. Ato II grava à mão (castelinho.gd:1413), o Braço não.")
	GS.checkpoint_sala = 100
	var destino: Array = GS.preparar_continuar()
	_checar(destino[0] == BRACO and destino[1] == "Spawn", "Continuar com checkpoint 100 vai ao Braço, Spawn (%s)" % str(destino))
	await _carregar(destino[1])
	_checar(GS.sala_atual == 100 and player.is_on_floor(), "Continuar do Braço nasce no poço (sala %d, y=%.2f)" % [GS.sala_atual, player.global_position.y])
	GS.checkpoint_sala = 96
	var d96: Array = GS.preparar_continuar()
	_checar(d96[0] == PORAO and d96[1] == "Checkpoint_96", "checkpoint 96 volta ao Porão (%s)" % str(d96))


## Um final completo: pistas -> lápide (conta a pista) -> Tito se vira -> final -> dedicatória -> (sem volta ao título).
func _t_final(final: String) -> void:
	print("-- final '%s'" % final)
	await _carregar()
	GS.flags.erase("viu_tito_final")
	GS.flags.erase("final_encontrado")
	GS.flags.erase("final_visita_concluida")
	GS.flags.erase("pista_lapide")
	GS.contadores["pistas_tito"] = 5 if final == "encontrado" else 0
	nivel.voltar_ao_titulo = false
	GS.set_flag("tem_visor", true)
	# lápide: sem o Visor, só a dica; a pista conta uma vez
	GS.trocar_epoca(GS.Epoca.E2020)
	_checar(not nivel.tito.visible, "sem o Visor, Tito não aparece")
	await _ir_para(Vector3(8.5, 0.05, -2.9), 0.0)
	await _frames(6)
	var alcance: bool = player._alvo == nivel.lapide
	_checar(alcance, "lápide ao alcance do jogador parado no gramado (z -2.9)")
	if not alcance:
		_achado("A3 [B] Lápide de areia não fica ao alcance a partir do gramado (ALCANCE 2,4 m; lápide em z -5,6 dentro da borda sem chão)")
	nivel.lapide.interagir(player)
	await _frames(5)
	_checar(not nivel.encerrando and GS.flag("pista_lapide"), "lápide sem o Visor: só dica e conta pista")
	_checar(int(GS.contadores["pistas_tito"]) == (6 if final == "encontrado" else 1), "contador após a lápide = %d" % int(GS.contadores["pistas_tito"]))
	# agora com o disco sem data: Tito aparece na margem
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	_checar(nivel.tito.visible, "com o Visor sem data, Tito aparece")
	await _ir_para(Vector3(3.0, 0.05, -2.4), 0.0)
	var menino: Node3D = nivel.tito.get_node("Menino")
	var fim := [""]
	nivel.fim.connect(func(f): fim[0] = f)
	var ok: bool = await _ate(func(): return nivel.cena_feita, 900)
	_checar(ok, "olhar para Tito com o Visor dispara a cena final")
	var virou: bool = await _ate(func(): return absf(menino.rotation.y - PI) < 0.05, 900)
	_checar(virou, "Tito se vira para o jogador")
	var falou: bool = await _ate(func(): return nivel._legenda.text == "Você veio me procurar.", 300)
	_checar(falou, "ele diz: 'Você veio me procurar.'")
	var decidiu: bool = await _ate(func(): return GS.flag("viu_tito_final"), 1500)
	_checar(decidiu and nivel.final == final, "final decidido pelas pistas: %s (pistas=%d)" % [nivel.final, int(GS.contadores["pistas_tito"])])
	if final == "encontrado":
		var boca: Label3D = menino.get_node("Boca") as Label3D
		await _ate(func(): return menino.scale.x < 0.01, 1200)
		_checar(menino.scale.x < 0.01 and GS.flag("final_encontrado") and boca.text == ")", "Encontrado: Tito sorri e some")
	else:
		_checar(menino.scale.x > 0.9 and GS.flag("final_visita_concluida") and not GS.flag("final_encontrado"), "Visita concluída: Tito continua ali")
	# o fim chega sozinho (4 s depois) e abre a dedicatória
	var ok3: bool = await _ate(func(): return nivel.dedicatoria != null, 2400)
	_checar(ok3 and fim[0] == final, "fim emitido com o final certo e a dedicatória aparece (fim=%s)" % fim[0])
	if not ok3:
		return
	var d = nivel.dedicatoria
	var txt: String = d.texto_dedicatoria()
	_checar(txt.contains("Tito é um personagem fictício") and txt.contains("Disque 100") and txt.contains("Conselho Tutelar"), "dedicatória: texto com Disque 100 e Conselho Tutelar")
	var termina := [false]
	d.terminou.connect(func(): termina[0] = true)
	var n := 0
	while d.fase != "dedicatoria" and n < 3000:
		await physics_frame
		n += 1
	while d._t_fase < 1.0 and n < 3000:
		await physics_frame
		n += 1
	d.avancar()
	await _frames(3)
	_checar(not termina[0] and d.fase == "dedicatoria", "dedicatoria: apertar antes de 6 s não encerra")
	while d._t_fase < 6.3 and n < 6000:
		await physics_frame
		n += 1
	d.avancar()
	await _frames(3)
	_checar(termina[0], "dedicatoria: depois de 6 s, um clique encerra (terminou emitido)")
	await _frames(90)
	_checar(not is_instance_valid(d), "dedicatoria some depois do fade (não fica na tela)")
	_checar(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "mouse solto depois da dedicatória")
	_checar(not GS.flag("ui_aberta"), "sem 'ui_aberta' presa depois do final")


func _t_telefone() -> void:
	print("-- Telefone (ui/telefone.gd)")
	var Tel = load("res://ui/telefone.gd")
	var frase := "Vocês viram o Tito?"
	var suja: String = Tel.chiar(frase, 1.0)
	_checar(suja.length() == frase.length(), "chiado mantém o tamanho do texto (%d)" % suja.length())
	_checar(Tel.chiar(frase, 0.0) == frase, "sem chiado (força 0) o texto sai igual")
	_checar(suja != frase, "chiado forte muda o texto")
	var t = Tel.tocar(["Alô? É do Castelinho?", "Vocês viram o Tito?"], false)
	var acabou := [false]
	t.terminou.connect(func(): acabou[0] = true)
	var ok: bool = await _ate(func():
		root.get_node("/root/Guia").avancar()
		return acabou[0], 3000)
	_checar(ok, "telefone: as duas linhas passam e 'terminou' sai")
	_checar(t.linhas_limpas.size() == 2 and t.linhas_limpas[1] == frase, "texto original guardado em linhas_limpas")


func _t_volte_sempre() -> void:
	print("-- Volte sempre (ui/volte_sempre.gd)")
	var Vs = load("res://ui/volte_sempre.gd")
	var v1 = Vs.mostrar(1)
	await _frames(4)
	_checar(v1 != null and not v1.estranho, "primeira vez: versão alegre")
	var fechou := [false]
	v1.terminou.connect(func(): fechou[0] = true)
	var auto: bool = await _ate(func(): return fechou[0], 3000)
	_checar(auto, "sozinha, a placa some e 'terminou' sai")
	await _frames(60)
	_checar(not is_instance_valid(v1), "placa liberada depois do fade")
	var v2 = Vs.mostrar(2)
	await _frames(4)
	_checar(v2.estranho, "segunda vez: versão estranha")
	var fechou2 := [false]
	v2.terminou.connect(func(): fechou2[0] = true)
	await _frames(30)
	v2.continuar()
	await _frames(3)
	_checar(fechou2[0], "clique (continuar) encerra a placa")
	await _frames(60)


## Final com voltar_ao_titulo = true, a cena principal sendo o Main: depois da dedicatória o Main deve recarregar.
func _t_volta_ao_titulo() -> void:
	print("-- depois do final: volta ao título (voltar_ao_titulo = true)")
	await _carregar()
	GS.contadores["pistas_tito"] = 6
	GS.flags.erase("viu_tito_final")
	GS.trocar_epoca(GS.Epoca.ESEMDATA)
	await _ir_para(Vector3(3.0, 0.05, -2.4), 0.0)
	var velho = main
	root.get_tree().current_scene = main
	var ok: bool = await _ate(func(): return nivel.cena_feita, 900)
	_checar(ok, "cena final disparada (modo volta ao título)")
	var n := 0
	while nivel.dedicatoria == null and n < 3000:
		await physics_frame
		n += 1
	var d = nivel.dedicatoria
	if d == null:
		_checar(false, "dedicatória apareceu")
		return
	while d.fase != "dedicatoria" and n < 6000:
		await physics_frame
		n += 1
	while d._t_fase < 6.3 and n < 9000:
		await physics_frame
		n += 1
	d.avancar()
	var recarregou: bool = await _ate(func(): return not is_instance_valid(velho), 600)
	_checar(recarregou, "depois da dedicatória a cena principal é recarregada (volta ao título)")
	await _frames(30)
	var novo: Node = null
	for c in root.get_children():
		if c != velho and c.has_method("_mostrar_titulo"):
			novo = c
	_checar(novo != null, "um Main novo, com o título, está no lugar do antigo")
	if novo != null:
		_checar(GS.jogando == false and GS.sala_atual == 0, "GameState: fora da partida, sala 0 (sala %d)" % GS.sala_atual)
		_checar(not GS.flag("ui_aberta") and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "título com mouse solto e sem UI presa")
		_checar(novo.tela_titulo != null and is_instance_valid(novo.tela_titulo), "tela de título presente")
		var destino: Array = GS.preparar_continuar()
		_checar(destino[0] == PORAO and destino[1] == "Checkpoint_96", "Continuar depois do final cai no porão 96 (%s)" % str(destino))
		_achado("A2b [M] Consequência de A2: 'Continuar' depois do final retoma no Porão 96 (salas 96-99 de novo), não no Braço (checkpoint 100 nunca gravado)")
