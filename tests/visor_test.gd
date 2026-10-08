extends SceneTree
## Teste automático (headless) do Visor do Tempo 2.0 (V2_ROTEIRO §4): discos, Q por disco, atenção (sobe, desce,
## susto no máximo, bloqueio de 10 s, Figura no slide), sinal figura_atravessou, B06, HUD e fallback de painel.
## Uso: godot --headless -s res://tests/visor_test.gd
##
## O tempo é conduzido à mão: o `_process` do Visor é desligado e chamado com dt fixo (o Q é simulado com
## Input.action_press). Só a troca ligar/desligar espera 0,15 s reais (INTERVALO_MIN do Visor).

var falhas := 0
var GS
var Ef
var VisorCls
var PainelUI
var v
var mundo: Node3D


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Ef = root.get_node("/root/Efeitos")
	VisorCls = load("res://world/visor.gd")
	PainelUI = load("res://ui/painel_ui.gd")
	_preparar()

	await _teste_fallback_paineis()
	await _teste_discos()
	await _teste_q_por_disco()
	await _teste_sem_atencao_nas_visitas_1_e_2()
	await _teste_atencao()
	await _teste_susto_e_bloqueio()
	await _teste_figura_atravessou()
	await _teste_b06()
	await _teste_visor_travado()
	await _teste_hud()
	await _teste_paineis_3d()

	Input.action_release("visor")
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _preparar() -> void:
	GS.novo_jogo()
	GS.jogando = false
	VisorCls.resetar_estado()
	mundo = Node3D.new()
	root.add_child(mundo)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.55, 0)
	mundo.add_child(cam)
	cam.current = true
	v = VisorCls.instalar(mundo)
	v.set_process(false)   # o tempo é conduzido à mão (passo)


## Anda `segundos` do Visor em passos de `dt` (sem esperar tempo real).
func _passo(segundos: float, dt := 0.1) -> void:
	var n := int(round(segundos / dt))
	for i in n:
		v._process(dt)


## Muda o estado do Q e deixa passar tempo real suficiente para o INTERVALO_MIN do Visor.
func _q(apertado: bool) -> void:
	if apertado:
		Input.action_press("visor")
	else:
		Input.action_release("visor")
	await create_timer(0.16).timeout
	v._process(0.016)


func _zerar(visita := 1) -> void:
	Input.action_release("visor")
	GS.visita = visita
	GS.discos.clear()
	GS.disco_atual = -1
	GS.definir_atencao(0.0)
	GS.flags.erase("tem_visor")
	GS.flags.erase("epoca_visor")
	GS.flags.erase("visor_travado")
	GS.trocar_epoca(GS.Epoca.E2020)
	VisorCls.resetar_estado()
	v.ativo = false
	v._epoca_mostrada = -1


# ---------------------------------------------------------------- painéis
func _teste_fallback_paineis() -> void:
	print("-- fallback de painéis")
	var base: Dictionary = PainelUI.dados("p05")
	_checar(PainelUI.dados("p05_v9") == base, "variante inexistente (p05_v9) cai em p05")
	_checar(PainelUI.id_efetivo("p05_v9") == "p05" and PainelUI.id_efetivo("p05_v2") == "p05_v2", "id_efetivo: cai só se não existe")
	_checar(PainelUI.dados("p22_v9") == PainelUI.dados("quiz_final"), "p22_v9 -> p22 -> alias quiz_final")
	_checar(PainelUI.dados("zzz_v2").get("titulo") == "Painel em construção", "id sem base continua 'em construção'")
	var faltando := []
	for n in range(1, 23):
		for k in [2, 3, 4]:
			var id := "p%02d_v%d" % [n, k]
			if not PainelUI.carregar_dados().has(id):
				faltando.append(id)
	_checar(faltando.is_empty(), "p01..p22 têm _v2, _v3 e _v4 (faltam: %s)" % str(faltando))
	var sem_fonte := []
	var longos := []
	for n in range(1, 23):
		var d2: Dictionary = PainelUI.dados("p%02d_v2" % n)
		if not str(d2.get("fonte", "")).begins_with("http"):
			sem_fonte.append(n)
		if str(d2.texto).split(" ", false).size() > 66:
			longos.append(n)
		_checar(bool(d2.get("seco", false)), "p%02d_v2 usa a placa seca" % n) if n == 1 else null
		var d3: Dictionary = PainelUI.dados("p%02d_v3" % n)
		_checar("revis" in (str(d3.titulo) + str(d3.texto)).to_lower(), "p%02d_v3 fala em revisão" % n) if n in [1, 9] else null
		var d4: Dictionary = PainelUI.dados("p%02d_v4" % n)
		_checar(str(d4.texto).length() <= 10 and bool(d4.get("riscado", false)), "p%02d_v4 quase sem texto e riscado" % n) if n in [1, 14, 22] else null
		var img := str(PainelUI.dados(str(d4.get("desenho", ""))).get("imagem", ""))
		if not ResourceLoader.exists(img):
			sem_fonte.append("v4 %d sem imagem" % n)
	_checar(sem_fonte.is_empty(), "v2 com fonte http e v4 com desenho (%s)" % str(sem_fonte))
	_checar(longos.is_empty(), "textos v2 com até ~60 palavras (%s)" % str(longos))
	var tem_menino := 0
	for n in range(1, 23):
		if "menino desaparecido em 1967" in str(PainelUI.dados("p%02d_v3" % n).texto):
			tem_menino += 1
	_checar(tem_menino >= 4, "v3 menciona o menino desaparecido em 1967 (%d painéis)" % tem_menino)
	for id in ["desenho_1", "desenho_2", "desenho_3", "desenho_4", "desenho_5", "desenho_6", "desenho_7", "procura_se", "marcas_altura"]:
		var d: Dictionary = PainelUI.dados(id)
		_checar(d.get("tipo") == "imagem" and ResourceLoader.exists(str(d.get("imagem", ""))), "%s: imagem existe" % id)
	# revisão dos seis painéis do tom: sem as frases antigas
	_checar("instagramável" not in str(PainelUI.dados("p21").texto), "p21 revisado (sem 'instagramável')")
	_checar("guarda-vidas" in str(PainelUI.dados("p14").texto), "p14 revisado (dica dos guarda-vidas)")


# ---------------------------------------------------------------- discos
func _teste_discos() -> void:
	print("-- discos (teclas 1-5 e rolagem)")
	_zerar(1)
	_checar(InputMap.has_action("disco_1") and InputMap.has_action("disco_5") and InputMap.has_action("disco_prox") and InputMap.has_action("disco_ant"), "ações de input criadas pelo Visor")
	_checar(not v.selecionar_slot(1), "sem o disco 1967, a tecla 2 não faz nada")
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.set_flag("tem_visor")
	_checar(GS.disco_atual == GS.Epoca.E1950, "ganhar_disco seleciona o novo disco")
	GS.ganhar_disco(GS.Epoca.E1975)
	GS.ganhar_disco(GS.Epoca.E1967)
	_checar(GS.disco_atual == GS.Epoca.E1967, "o último disco ganho fica selecionado")
	_checar(v.selecionar_slot(0) and GS.disco_atual == GS.Epoca.E1950, "tecla 1 = disco 1950")
	_checar(v.selecionar_slot(2) and GS.disco_atual == GS.Epoca.E1975, "tecla 3 = disco 1975")
	_checar(not v.selecionar_slot(3) and GS.disco_atual == GS.Epoca.E1975, "tecla 4 sem o 2019: nada muda")
	# pelo pipeline de input de verdade: a tecla 2 e a rolagem
	var ev := InputEventKey.new()
	ev.physical_keycode = KEY_2
	ev.pressed = true
	Input.parse_input_event(ev)
	await process_frame
	await process_frame
	_checar(GS.disco_atual == GS.Epoca.E1967, "a tecla 2 de verdade seleciona o 1967 (%d)" % GS.disco_atual)
	GS.set_flag("ui_aberta", true)
	v.ciclar(1)
	GS.set_flag("ui_aberta", false)
	# ciclar: ordem fixa 1950 -> 1967 -> 1975 -> (volta)
	GS.selecionar_disco(GS.Epoca.E1950)
	v.ciclar(1)
	_checar(GS.disco_atual == GS.Epoca.E1967, "rolagem para frente: 1950 -> 1967")
	v.ciclar(1)
	_checar(GS.disco_atual == GS.Epoca.E1975, "rolagem para frente: 1967 -> 1975")
	v.ciclar(1)
	_checar(GS.disco_atual == GS.Epoca.E1950, "rolagem dá a volta (só entre os discos que tem)")
	v.ciclar(-1)
	_checar(GS.disco_atual == GS.Epoca.E1975, "rolagem para trás")
	var m := InputEventMouseButton.new()
	m.button_index = MOUSE_BUTTON_WHEEL_UP
	m.pressed = true
	var antes: int = GS.disco_atual
	Input.parse_input_event(m)
	await process_frame
	await process_frame
	_checar(GS.disco_atual != antes, "a rolagem do mouse de verdade troca de disco")
	_checar(VisorCls.ORDEM_DISCOS == [GS.Epoca.E1950, GS.Epoca.E1967, GS.Epoca.E1975, GS.Epoca.E2019, GS.Epoca.ESEMDATA], "ordem das teclas = 1950, 1967, 1975, 2019, sem data")


# ---------------------------------------------------------------- Q
func _teste_q_por_disco() -> void:
	print("-- Q mostra a época do disco")
	_zerar(1)
	# sem disco e sem flag: Q não faz nada
	GS.set_flag("tem_visor")
	await _q(true)
	_checar(not v.ativo and GS.epoca == GS.Epoca.E2020, "sem disco o Q não faz nada")
	await _q(false)
	# MVP: sem discos mas com epoca_visor, o Q ainda funciona (compatibilidade)
	GS.set_flag("epoca_visor", GS.Epoca.E1975)
	await _q(true)
	_checar(v.ativo and GS.epoca == GS.Epoca.E1975, "compatibilidade: sem discos, a flag epoca_visor vale")
	await _q(false)
	_checar(not v.ativo and GS.epoca == GS.Epoca.E2020, "soltar volta para 2020")
	_zerar(1)
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.ganhar_disco(GS.Epoca.E1967)
	GS.ganhar_disco(GS.Epoca.ESEMDATA)
	GS.set_flag("epoca_visor", GS.Epoca.E1975)   # com discos, a flag é ignorada
	for par in [[GS.Epoca.E1950, "1950"], [GS.Epoca.E1967, "1967"], [GS.Epoca.ESEMDATA, "????"]]:
		GS.selecionar_disco(par[0])
		await _q(true)
		_checar(v.ativo and GS.epoca == par[0], "Q com o disco %s mostra a época dele" % par[1])
		_checar(Ef._lbl_ano.text == par[1], "a moldura mostra o ano '%s' (mostra '%s')" % [par[1], Ef._lbl_ano.text])
		await _q(false)
		_checar(not v.ativo and GS.epoca == GS.Epoca.E2020, "soltar volta para 2020 (disco %s)" % par[1])
	# trocar de disco com o Q apertado troca a época na hora
	GS.selecionar_disco(GS.Epoca.E1950)
	await _q(true)
	v.selecionar_slot(1)
	v._process(0.016)
	_checar(v.ativo and GS.epoca == GS.Epoca.E1967, "trocar de disco com Q apertado troca a época")
	await _q(false)
	# visor_travado: soltar não volta para 2020 (fica na época de antes; ver _teste_visor_travado)
	GS.trocar_epoca(GS.Epoca.E1975)
	GS.set_flag("visor_travado", true)
	await _q(true)
	await _q(false)
	_checar(GS.epoca == GS.Epoca.E1975, "visor_travado: a época não volta para 2020 ao soltar")
	GS.set_flag("visor_travado", false)
	GS.trocar_epoca(GS.Epoca.E2020)
	# o painel de UI aberto impede o Q
	GS.set_flag("ui_aberta", true)
	await _q(true)
	_checar(not v.ativo, "com tela aberta o Q não liga")
	GS.set_flag("ui_aberta", false)
	await _q(false)


func _teste_sem_atencao_nas_visitas_1_e_2() -> void:
	print("-- sem atenção nas visitas 1 e 2")
	for vis in [1, 2]:
		_zerar(vis)
		GS.ganhar_disco(GS.Epoca.E1950)
		await _q(true)
		_passo(8.0)
		_checar(GS.atencao == 0.0 and v.ativo and not VisorCls.bloqueado(), "visita %d: o Visor é só um brinquedo (atenção %.2f)" % [vis, GS.atencao])
		await _q(false)


# ---------------------------------------------------------------- atenção
func _teste_atencao() -> void:
	print("-- atenção: sobe com Q, desce ao soltar, tempos por visita")
	_zerar(3)
	GS.ganhar_disco(GS.Epoca.E1950)
	await _q(true)
	_passo(3.0)
	_checar(absf(GS.atencao - 0.5) < 0.06, "visita 3: meio medidor em ~3 s (%.2f)" % GS.atencao)
	_checar(v.figura_visivel, "a Figura aparece no slide com o Q apertado e atenção > 12%")
	var sinais := []
	GS.atencao_mudou.connect(func(a): sinais.append(a))
	_passo(0.5)
	_checar(not sinais.is_empty(), "GameState.atencao_mudou é emitido")
	var antes: float = GS.atencao
	await _q(false)
	_passo(2.0)
	_checar(GS.atencao < antes and GS.atencao > 0.0, "soltar o Q faz a atenção cair devagar (%.2f -> %.2f)" % [antes, GS.atencao])
	_checar(not v.figura_visivel, "sem Q a Figura some do slide")
	_passo(12.0)
	_checar(GS.atencao == 0.0, "e esvazia por completo")
	# tempo até encher: visita 3 ~6 s, visita 4 ~4 s, porão ~3 s
	for par in [[3, 6.0], [4, 4.0], [5, 3.0]]:
		_zerar(par[0])
		GS.ganhar_disco(GS.Epoca.E1950)
		await _q(true)
		var t := 0.0
		while not VisorCls.bloqueado() and t < 12.0:
			_passo(0.1)
			t += 0.1
		_checar(absf(t - par[1]) < 0.35, "visita %d: enche em ~%.0f s (levou %.1f s)" % [par[0], par[1], t])
		await _q(false)
		VisorCls.resetar_estado()


func _teste_susto_e_bloqueio() -> void:
	print("-- susto no máximo e bloqueio de 10 s")
	_zerar(3)
	GS.ganhar_disco(GS.Epoca.E1967)
	var cheios := []
	var bloqs := []
	var atrav := []
	var c1 = func(vis): cheios.append(vis)
	var c2 = func(b): bloqs.append(b)
	var c3 = func(vis): atrav.append(vis)
	v.atencao_cheia.connect(c1)
	v.bloqueio_mudou.connect(c2)
	v.figura_atravessou.connect(c3)
	var sustos0: int = GS.contadores.get("sustos", 0)
	await _q(true)
	_checar(v.ativo and GS.epoca == GS.Epoca.E1967, "visor ligado em 1967")
	_passo(6.3)
	_checar(cheios == [3], "atenção cheia emitida na visita 3 (%s)" % str(cheios))
	_checar(not v.ativo and GS.epoca == GS.Epoca.E2020, "o Visor foi arrancado da mão (desligou, época de hoje)")
	_checar(VisorCls.bloqueado() and absf(VisorCls.bloqueio_restante() - 10.0) < 0.5, "bloqueado por 10 s (%.1f)" % VisorCls.bloqueio_restante())
	_checar(GS.atencao == 0.0, "a atenção volta a zero")
	_checar(GS.contadores.get("sustos", 0) == sustos0 + 1, "conta como um susto")
	_checar(Ef._pulso > 0.5, "Efeitos.pulso forte (%.2f)" % Ef._pulso)
	_checar(bloqs == [true], "bloqueio_mudou(true)")
	_checar(atrav.is_empty(), "visita 3: o susto não solta a Figura de verdade")
	# com o Q ainda apertado, nada acontece durante o bloqueio
	Input.action_press("visor")
	await create_timer(0.2).timeout
	_passo(4.0)
	_checar(not v.ativo and GS.epoca == GS.Epoca.E2020, "bloqueado: Q apertado não liga (4 s depois)")
	_passo(5.0)
	_checar(VisorCls.bloqueado(), "ainda bloqueado aos ~9 s")
	_passo(1.5)
	_checar(not VisorCls.bloqueado() and bloqs == [true, false], "depois de 10 s o bloqueio acaba")
	await create_timer(0.2).timeout
	_passo(0.2)
	_checar(v.ativo, "e o Q (ainda apertado) volta a funcionar")
	await _q(false)
	v.atencao_cheia.disconnect(c1)
	v.bloqueio_mudou.disconnect(c2)
	v.figura_atravessou.disconnect(c3)
	VisorCls.resetar_estado()


func _teste_figura_atravessou() -> void:
	print("-- figura_atravessou (visita 4 e porão)")
	for vis in [4, 5]:
		_zerar(vis)
		GS.ganhar_disco(GS.Epoca.ESEMDATA if vis == 5 else GS.Epoca.E2019)
		var atrav := []
		var f = func(x): atrav.append(x)
		v.figura_atravessou.connect(f)
		await _q(true)
		_passo(5.0)
		_checar(atrav == [vis], "visita %d: Visor.figura_atravessou(%d) emitido (%s)" % [vis, vis, str(atrav)])
		v.figura_atravessou.disconnect(f)
		await _q(false)
		VisorCls.resetar_estado()


func _teste_b06() -> void:
	print("-- B06: trocar de nível com Q apertado devolve 2020")
	_zerar(1)
	GS.ganhar_disco(GS.Epoca.E1950)
	var m2 := Node3D.new()
	root.add_child(m2)
	var v2 = VisorCls.new()
	m2.add_child(v2)
	v2.set_process(false)
	v.queue_free()
	await process_frame
	Input.action_press("visor")
	await create_timer(0.2).timeout
	v2._process(0.016)
	_checar(v2.ativo and GS.epoca == GS.Epoca.E1950, "visor ligado (1950)")
	m2.queue_free()   # o nível acaba com o Q apertado
	await process_frame
	await process_frame
	_checar(GS.epoca == GS.Epoca.E2020 and not Ef.visor_ativo, "ao sair do nível a época volta para 2020 e a moldura desliga")
	Input.action_release("visor")
	v = VisorCls.instalar(mundo)
	v.set_process(false)


## visor_travado: segurar Q com OUTRO disco e soltar volta para a época de antes (não fica no disco); troca de disco salva.
func _teste_visor_travado() -> void:
	print("-- visor_travado: soltar o Q volta para a época de antes; selecionar_disco salva")
	_zerar(1)
	GS.ganhar_disco(GS.Epoca.E1975)
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.trocar_epoca(GS.Epoca.E1975)   # o corredor de 1975 (época de antes)
	GS.flags["visor_travado"] = true
	await _q(true)
	_checar(v.ativo and GS.epoca == GS.Epoca.E1950, "Q com o disco 1950 mostra 1950")
	await _q(false)
	_checar(not v.ativo and GS.epoca == GS.Epoca.E1975, "travado: soltar volta para 1975, não fica em 1950 (%d)" % GS.epoca)
	await _q(true)
	v._exit_tree()   # o nível acaba com o Q apertado
	_checar(GS.epoca == GS.Epoca.E1975, "travado: sair do nível também volta para 1975")
	Input.action_release("visor")
	GS.flags.erase("visor_travado")
	GS.trocar_epoca(GS.Epoca.E2020)
	v.ativo = false
	# o nível trava o Visor com o Q apertado (o jogador entra no corredor olhando pelo Visor, com o disco 1950)
	await _q(true)
	GS.set_flag("visor_travado", true)
	GS.trocar_epoca(GS.Epoca.E1975)
	await _q(false)
	_checar(GS.epoca == GS.Epoca.E1975, "travado com o Q apertado: soltar fica na época do nível (%d)" % GS.epoca)
	GS.flags.erase("visor_travado")
	GS.trocar_epoca(GS.Epoca.E2020)
	GS.selecionar_disco(GS.Epoca.E1975)
	var f := FileAccess.open(GS.ARQUIVO_SAVE, FileAccess.READ)
	var dados = JSON.parse_string(f.get_as_text()) if f else null
	_checar(typeof(dados) == TYPE_DICTIONARY and int(dados.get("disco_atual", -9)) == GS.Epoca.E1975, "selecionar_disco grava disco_atual no save")


# ---------------------------------------------------------------- HUD
func _teste_hud() -> void:
	print("-- HUD: contador, faixa de discos e olho")
	_zerar(1)
	var HUDc = load("res://ui/hud.gd")
	var hud = HUDc.new()
	root.add_child(hud)
	await process_frame
	GS.entrar_sala(27)
	GS.visita = 2
	_checar(hud.lbl_sala.text == "VISITA 2 · SALA 27", "contador: '%s'" % hud.lbl_sala.text)
	GS.entrar_sala(5)
	GS.visita = 1
	_checar(hud.lbl_sala.text == "VISITA 1 · SALA 05", "visita 1: '%s'" % hud.lbl_sala.text)
	GS.entrar_sala(87)
	GS.visita = 5
	_checar(hud.lbl_sala.text == "SALA 87", "porão: só 'SALA 87' ('%s')" % hud.lbl_sala.text)
	GS.entrar_sala(60)
	_checar(hud.lbl_sala.text == "VISITA 3 · SALA 60", "o número da sala manda: sala 60 é da visita 3 ('%s')" % hud.lbl_sala.text)
	# faixa de discos
	_checar(not hud.faixa_discos.visible, "sem discos a faixa não aparece")
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.ganhar_disco(GS.Epoca.E1975)
	await process_frame
	_checar(hud.faixa_discos.visible and hud.faixa_discos.discos_mostrados() == [GS.Epoca.E1950, GS.Epoca.E1975], "a faixa mostra só os discos que o jogador tem")
	GS.selecionar_disco(GS.Epoca.E1950)
	for i in 5:
		await process_frame
	_checar(hud.faixa_discos.position.y > 400.0, "a faixa fica embaixo (y=%.0f)" % hud.faixa_discos.position.y)
	# olho
	GS.definir_atencao(0.0)
	for i in 10:
		await process_frame
	_checar(not hud.olho.visible, "atenção 0: sem olho")
	GS.definir_atencao(1.0)
	for i in 70:
		await process_frame
	_checar(hud.olho.visible and hud.olho.abertura() > 0.9, "atenção 1: olho aberto (%.2f)" % hud.olho.abertura())
	GS.definir_atencao(0.0)
	hud.queue_free()
	await process_frame


# ---------------------------------------------------------------- Painel3D
func _teste_paineis_3d() -> void:
	print("-- Painel3D: variantes, desenhos e cartaz")
	var Painel3D = load("res://world/painel_3d.gd")
	var lista := []
	for id in ["p05_v2", "p05_v3", "p05_v4", "p05_v7", "desenho_3", "procura_se", "marcas_altura"]:
		var p = Painel3D.new(id)
		root.add_child(p)
		lista.append(p)
	await process_frame
	await process_frame
	for p in lista:
		_checar(p.get_node("Visual").get_child_count() >= 2, "Painel3D(%s) montou (%d peças)" % [p.id, p.get_node("Visual").get_child_count()])
	_checar("quiz" in lista[3].texto_interacao.to_lower(), "p05_v7 cai em p05 (que tem quiz): '%s'" % lista[3].texto_interacao)
	_checar(lista[4].texto_interacao == "Ver o desenho" and lista[5].texto_interacao == "Ler o cartaz", "avisos de interação das folhas")
	# abrir a visualização de um desenho
	lista[4].interagir(null)
	for i in 4:
		await process_frame
	var ui = PainelUI.atual
	_checar(ui != null and is_instance_valid(ui) and ui._imagem != null, "interagir com o desenho abre a visualização com a imagem")
	if ui:
		ui.fechar()
	for i in 4:
		await process_frame
	var Flash = load("res://ui/flash.gd")
	Flash.resetar_ui()
	for p in lista:
		p.queue_free()
	await process_frame


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
