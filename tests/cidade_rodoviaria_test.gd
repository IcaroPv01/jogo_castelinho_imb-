extends SceneTree
## Teste automático (headless) do MIOLO da Rodoviária (Módulo 14, `world/niveis/cidade_rodoviaria.gd`): só o disco de 1967 (e o sem data)
## mostra as 3 plaquinhas, o ônibus e as silhuetas; 3 plaquinhas no quadro abrem o guichê; o cartaz lido conta a pista UMA vez; o portão
## passa a concluir (flag + volta à calçada); o Visor não gera atenção (sem Figura); não prende o jogador; texto do cartaz coerente
## com o jornal e o PROCURA-SE do Castelinho. O contrato da base (borda, rede de segurança, HUD, Mapa) é de `tests/cidade_test.gd`.
## Uso: godot --headless -s res://tests/cidade_rodoviaria_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var guia: Node
var efeitos: Node
const CENA := "res://world/niveis/cidade_rodoviaria.tscn"


func _initialize() -> void:
	_rodar.call_deferred()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 600) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	guia = root.get_node("/root/Guia")
	efeitos = root.get_node("/root/Efeitos")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	await _epocas_e_cenario()
	await _tarefa()
	await _concluir_e_voltar()
	await _nao_prende()
	await _ja_resolvido()
	main.queue_free()
	await process_frame
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


## Jogo novo na visita 4 (Sala Medieval alcançada: a rodoviária abre), todos os discos, e carrega o lugar.
func _entrar() -> Node:
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.visita = 4
	GS.sala_maxima = 78
	GS.entrar_sala(67)
	GS.set_flag("tem_visor", true)
	for e in [GS.Epoca.E1950, GS.Epoca.E1967, GS.Epoca.E1975, GS.Epoca.E2019, GS.Epoca.ESEMDATA]:
		GS.ganhar_disco(e)
	await main.carregar_mundo(CENA, "Spawn")
	await _frames(8)
	guia.cancelar()
	return main.mundo.get_child(0)


func _na_epoca(nivel: Node, e: int) -> void:
	GS.trocar_epoca(e)
	await _frames(3)
	guia.cancelar()


func _bate_no_onibus(nivel: Node) -> bool:
	var espaco: PhysicsDirectSpaceState3D = nivel.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(Vector3(8.0, 1.5, -1.2), Vector3(8.0, 1.5, 4.0), 1)
	var r := espaco.intersect_ray(q)
	return not r.is_empty()


# ============================================================================ épocas e cenário
func _epocas_e_cenario() -> void:
	print("-- épocas e cenário")
	var nivel := await _entrar()
	_checar(main.nivel_atual == CENA and nivel.id == "rodoviaria", "carrega a cena e o id é 'rodoviaria'")
	_checar(bool(GS.flag("visor_calmo")), "flag visor_calmo ligada (sem Figura)")
	var n67: Node3D = nivel.find_child("Rodoviaria1967", true, false)
	var n20: Node3D = nivel.find_child("RodoviariaHoje", true, false)
	_checar(n67 != null and n20 != null, "tem os dois cenários (1967 e hoje)")
	var it_placa := nivel.find_child("Pegar", true, false) as Node
	# o objetivo no Mapa dá a dica do Visor (antes de ligá-lo)
	var obj: String = nivel._texto_objetivo()
	_checar(obj.find("Q") >= 0 and obj.find("1967") >= 0, "objetivo manda ligar o Visor no disco de 1967 ('%s')" % obj)
	# hoje (2020)
	_checar(GS.epoca == GS.Epoca.E2020 and n20.visible and not n67.visible, "em 2020: só o cenário de hoje")
	_checar(not it_placa.can_process(), "em 2020: a plaquinha não pode ser pega")
	_checar(not _bate_no_onibus(nivel), "em 2020: não há ônibus (nada bloqueia a pista)")
	# todas as épocas que não são 1967 veem a rodoviária de hoje
	for e in [GS.Epoca.E1950, GS.Epoca.E1975, GS.Epoca.E2019]:
		await _na_epoca(nivel, e)
		_checar(n20.visible and not n67.visible, "disco %s: rodoviária de hoje" % str(GS.NOMES_EPOCA[e]))
	# 1967 e sem data
	for e in [GS.Epoca.E1967, GS.Epoca.ESEMDATA]:
		await _na_epoca(nivel, e)
		_checar(n67.visible and not n20.visible, "disco %s: março de 1967" % str(GS.NOMES_EPOCA[e]))
		_checar(it_placa.can_process(), "  a plaquinha pode ser pega")
		var plac_vis := 0
		for pid in ["tramandai", "osorio", "poa"]:
			var no: Node3D = nivel.find_child("Plaquinha_" + pid, true, false)
			if no != null and no.is_visible_in_tree():
				plac_vis += 1
		_checar(plac_vis == 3, "  as 3 plaquinhas aparecem (%d)" % plac_vis)
		_checar(_bate_no_onibus(nivel), "  o ônibus é sólido")
		_checar(nivel.find_child("Silhuetas", true, false).is_visible_in_tree(), "  silhuetas de passageiros")
	# subtítulo do Visor por época
	await _na_epoca(nivel, GS.Epoca.E1967)
	efeitos._atualizar_legenda()
	_checar(str(efeitos._lbl_epoca.text).begins_with("março de 1967"), "legenda do Visor: '%s'" % str(efeitos._lbl_epoca.text).replace("\n", " / "))
	await _na_epoca(nivel, GS.Epoca.E2019)
	efeitos._atualizar_legenda()
	_checar(str(efeitos._lbl_epoca.text).find("nada de especial") >= 0, "disco 2019: legenda manda tentar 1967 ('%s')" % str(efeitos._lbl_epoca.text))
	await _na_epoca(nivel, GS.Epoca.E2020)
	# orçamento
	var luzes := 0
	var malhas := 0
	var rotulos := 0
	for n in nivel.find_children("*", "Node", true, false):
		if n is Light3D:
			luzes += 1
		elif n is MeshInstance3D:
			malhas += 1
		elif n is Label3D:
			rotulos += 1
	_checar(luzes <= 6, "no máximo 6 luzes (%d)" % luzes)
	_checar(malhas + rotulos <= 150, "poucos objetos desenháveis (%d malhas + %d rótulos, em todas as épocas juntas)" % [malhas, rotulos])
	# nada de empresa/marca no texto do lugar
	var proibidas := ["viação", "expresso", "ltda", "eucatur", "unesul", "citral", "planalto"]
	var achou := ""
	for l in nivel.find_children("*", "Label3D", true, false):
		var t: String = str((l as Label3D).text).to_lower()
		for p in proibidas:
			if t.find(p) >= 0:
				achou = t
	_checar(achou == "", "nenhum nome de empresa nos rótulos")


# ============================================================================ a tarefa
func _tarefa() -> void:
	print("-- tarefa: plaquinhas, guichê, cartaz")
	var nivel := await _entrar()
	var pistas0: int = int(GS.contadores.get("pistas_tito", 0))
	await _na_epoca(nivel, GS.Epoca.E1967)
	_checar(nivel.placas_pegas() == 0 and not nivel.guiche_aberto, "começa com 0/3 e o guichê fechado")
	# sem nada na mão, o quadro só diz o que falta
	nivel._acao_quadro()
	guia.cancelar()
	_checar(nivel.placas_pegas() == 0, "quadro sem plaquinhas na mão: nada muda")
	# pega a 1ª e a 2ª; a 2ª vez não conta
	_checar(nivel.pegar_placa("tramandai") and not nivel.pegar_placa("tramandai"), "plaquinha 'tramandai' pega uma vez só")
	_checar(not nivel.pegar_placa("inexistente"), "plaquinha desconhecida não conta")
	_checar(nivel.find_child("Plaquinha_tramandai", true, false) == null or nivel.find_child("Plaquinha_tramandai", true, false).is_queued_for_deletion(), "a plaquinha sai do cenário")
	nivel.pegar_placa("osorio")
	nivel.pendurar_placas()
	_checar(nivel.placas_pegas() == 2 and not nivel.guiche_aberto, "2 plaquinhas no quadro: guichê ainda fechado")
	_checar(nivel.find_child("PlacaNoQuadro_tramandai", true, false).visible, "a plaquinha aparece no quadro")
	_checar(not GS.flag("pista_rodoviaria_cartaz") and int(GS.contadores.get("pistas_tito", 0)) == pistas0, "sem cartaz lido: sem pista")
	nivel._acao_guiche()
	guia.cancelar()
	_checar(not nivel.guiche_aberto and nivel.ui_cartaz == null, "guichê fechado: E só dá dica (não abre o cartaz)")
	# a 3ª abre o guichê
	nivel.pegar_placa("poa")
	nivel.pendurar_placas()
	_checar(nivel.placas_pegas() == 3 and nivel.guiche_aberto, "3 plaquinhas no quadro: o guichê abre")
	_checar(nivel._persiana != null, "tem persiana")
	var subiu: bool = await _ate(func() -> bool: return nivel._persiana.scale.y < 0.2, 400)
	_checar(subiu, "a persiana sobe")
	_checar(nivel._texto_objetivo().find("cartaz") >= 0, "objetivo: ler o cartaz ('%s')" % nivel._texto_objetivo())
	guia.cancelar()
	# lê o cartaz
	nivel._acao_guiche()
	await _frames(6)
	var ui: Node = nivel.ui_cartaz
	_checar(ui != null and ui.is_inside_tree() and GS.flag("ui_aberta"), "E na janela abre o cartaz na tela (trava o jogo)")
	var texto := _todo_texto(ui)
	_checar(texto.find("PROCURA-SE") >= 0 and texto.find("12/03/1967") >= 0, "cartaz traz PROCURA-SE e a data 12/03/1967")
	_checar(texto.find("9 anos") >= 0 and texto.find("listrada") >= 0, "descrição: 9 anos, camiseta listrada")
	_checar(texto.find("foto") >= 0 and texto.find("Travessa") >= 0 and texto.find("4-27") >= 0, "sem foto, endereço fictício e o fone 4-27 do jornal")
	_checar(not ui.pode_fechar(), "não fecha no primeiro instante")
	ui._t = 10.0
	ui.continuar()
	var lido: bool = await _ate(func() -> bool: return nivel.lido, 120)
	_checar(lido and GS.flag("pista_rodoviaria_cartaz"), "fechar o cartaz conta a pista 'rodoviaria_cartaz'")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "pistas_tito +1")
	_checar(not GS.flag("ui_aberta"), "o jogo é liberado")
	guia.cancelar()
	# ler de novo não conta outra vez
	nivel._acao_guiche()
	await _frames(6)
	if nivel.ui_cartaz != null:
		nivel.ui_cartaz._t = 10.0
		nivel.ui_cartaz.continuar()
	await _frames(20)
	guia.cancelar()
	_checar(int(GS.contadores.get("pistas_tito", 0)) == pistas0 + 1, "ler de novo não conta outra pista")
	_checar(nivel._texto_objetivo().find("portão") >= 0, "objetivo: voltar ao portão ('%s')" % nivel._texto_objetivo())
	var volta := nivel.find_child("PortaoVolta", true, false) as Node
	_checar(volta != null and str(volta.texto_interacao).find("concluída") >= 0, "o portão agora conclui ('%s')" % str(volta.texto_interacao))
	# Visor sem atenção: visita 4, Q ligado por 10 s de jogo, atenção continua em zero e o Visor não estoura
	var visor: Node = nivel.find_child("Visor", true, false)
	_checar(visor != null and GS.visita == 4, "Visor instalado na visita 4")
	visor.ativo = true
	visor._atualizar_atencao(10.0)
	visor._atualizar_atencao(10.0)
	_checar(is_zero_approx(float(GS.atencao)) and visor.ativo and not visor.bloqueado(), "atenção do Visor fica em zero (sem Figura, sem bloqueio)")
	visor._desligar()


func _todo_texto(no: Node) -> String:
	var s := ""
	for n in no.find_children("*", "Label", true, false):
		s += (n as Label).text + "\n"
	return s


# ============================================================================ concluir e voltar
func _concluir_e_voltar() -> void:
	print("-- concluir: grava a flag e volta à calçada")
	var nivel: Node = main.mundo.get_child(0)
	_checar(not GS.cidade_feita("rodoviaria"), "antes do portão: lugar ainda não concluído")
	var volta := nivel.find_child("PortaoVolta", true, false) as Node
	var jogador: Node3D = main.player
	volta.interagir(jogador)
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 600)
	_checar(voltou, "o portão volta ao Castelinho")
	await _frames(10)
	guia.cancelar()
	_checar(GS.cidade_feita("rodoviaria"), "flag cidade_rodoviaria_feito gravada")
	var castelo: Node = main.mundo.get_child(0)
	var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "chega na calçada (Spawn_volta_cidade)")
	_checar(GS.visita == 4 and GS.epoca == GS.Epoca.E2020, "visita 4 e época de hoje intactas")
	_checar(not GS.flag("visor_calmo"), "visor_calmo desligada ao sair (a atenção do Castelinho volta ao normal)")
	_checar(efeitos.subtitulo_lugar.is_empty(), "legenda do Visor volta ao normal")
	_checar(not GS.cidade_pendentes().has("rodoviaria"), "sai da lista de pendentes da placa")
	# a flag nunca volta de um save
	GS.set_flag("visor_calmo", true)
	GS.carregar()
	_checar(not GS.flag("visor_calmo"), "GameState.carregar descarta visor_calmo")


# ============================================================================ não prende o jogador
func _nao_prende() -> void:
	print("-- sem a tarefa: o portão sai sem concluir")
	var nivel := await _entrar()
	var volta := nivel.find_child("PortaoVolta", true, false) as Node
	_checar(str(volta.texto_interacao) == "Voltar ao Castelinho", "antes da pista o portão só volta")
	volta.interagir(main.player)
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 600)
	await _frames(8)
	guia.cancelar()
	_checar(voltou and not GS.cidade_feita("rodoviaria") and not GS.flag("pista_rodoviaria_cartaz"), "saiu sem concluir e sem pista")
	_checar(not GS.flag("visor_calmo"), "visor_calmo desligada")
	# entra de novo (a tarefa recomeça do zero) e o objetivo ainda manda ligar o Visor
	await main.carregar_mundo(CENA, "Spawn")
	await _frames(6)
	guia.cancelar()
	nivel = main.mundo.get_child(0)
	_checar(nivel.placas_pegas() == 0 and not nivel.guiche_aberto, "nova visita: tarefa do começo")
	# dicas por atraso: sem o Visor, a Guia manda ligá-lo (conta a dica; não trava nada)
	nivel._t_dica = 1000.0
	nivel._dica_por_atraso(0.1)
	_checar(nivel._dicas == 1, "a Guia dá dica se o jogador demora")
	guia.cancelar()


# ============================================================================ já resolvido numa visita anterior
func _ja_resolvido() -> void:
	print("-- reentrada com a pista já achada")
	GS.novo_jogo()
	GS.jogando = true
	GS.visita = 5
	GS.set_flag("tem_visor", true)
	GS.ganhar_disco(GS.Epoca.E1967)
	GS.set_flag("pista_rodoviaria_cartaz", true)
	await main.carregar_mundo(CENA, "Spawn")
	await _frames(8)
	guia.cancelar()
	var nivel: Node = main.mundo.get_child(0)
	_checar(nivel.guiche_aberto and nivel.lido and nivel.placas_pegas() == 3, "guichê aberto e quadro completo")
	var volta := nivel.find_child("PortaoVolta", true, false) as Node
	_checar(str(volta.texto_interacao).find("concluída") >= 0, "o portão já conclui")
	var antes: int = int(GS.contadores.get("pistas_tito", 0))
	nivel.concluir()
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 600)
	_checar(voltou and GS.cidade_feita("rodoviaria") and int(GS.contadores.get("pistas_tito", 0)) == antes, "conclui sem contar a pista de novo")
	await _frames(5)
	guia.cancelar()
