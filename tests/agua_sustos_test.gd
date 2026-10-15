extends SceneTree
## Teste automático (headless) do módulo "água e sustos": lampejos de água no hall (FlashAgua), goteiras do porão,
## água ferrugem quando a Figura está perto, sustos no caminho obrigatório (visitas 3 e 4) e o recorte de jornal.
## Uso: godot --headless -s res://tests/agua_sustos_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var main: Node
var nivel: Node
var player: Node


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

	await _teste_jornal()
	await _teste_sustos_v3()
	await _teste_hall_v4()
	await _teste_goteiras_e_agua()

	Engine.time_scale = 1.0
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


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


func _carregar(cena: String, spawn := "Spawn") -> void:
	await main.carregar_mundo(cena, spawn)
	nivel = main.mundo.get_child(0)
	player = main.player
	await _frames(10)


func _guia() -> Node:
	return root.get_node("/root/Guia")


# ============================================================================ jornal
func _teste_jornal() -> void:
	print("-- jornal entre as visitas 2 e 3")
	var J = load("res://ui/jornal.gd")
	GS.flags.erase(J.FLAG)
	_checar(J.CORPO.contains("Tito, 9 anos") and J.MANCHETE == "MENINO DE 9 ANOS DESAPARECE NO IMBÉ" and J.MASTRO == "FOLHA DO VERANEIO",
		"textos do recorte (mastro, manchete, corpo)")
	_checar(J.RODAPE.contains("jornal fictício"), "rodapé avisa que o jornal é fictício")
	var j = J.mostrar()
	await _frames(4)
	_checar(is_instance_valid(j) and j.is_inside_tree(), "o recorte aparece na tela")
	_checar(GS.flag("ui_aberta") == true, "aberto: ui_aberta ligada")
	var menor := 99
	for l in j.find_children("*", "Label", true, false):
		menor = mini(menor, (l as Label).get_theme_font_size("font_size"))
	_checar(menor >= 14, "nenhum texto abaixo de 14 px (menor: %d)" % menor)
	# antes do tempo mínimo nada fecha
	var ev := InputEventKey.new()
	ev.keycode = KEY_E
	ev.pressed = true
	j._input(ev)
	_checar(not j._feito and not j.pode_fechar(), "antes de 3 s o E não fecha")
	var clique := InputEventMouseButton.new()
	clique.button_index = MOUSE_BUTTON_LEFT
	clique.pressed = true
	j._input(clique)
	_checar(not j._feito, "antes de 3 s o clique não fecha")
	j._t = J.MIN_LEITURA + 0.1
	_checar(j.pode_fechar(), "depois de 3 s pode fechar")
	var fechou := [false]
	j.terminou.connect(func(): fechou[0] = true)
	j._input(ev)
	_checar(j._feito and fechou[0], "depois de 3 s o E fecha e emite `terminou`")
	_checar(GS.flag("ui_aberta") != true, "fechado: ui_aberta desligada")
	await _frames(40)
	_checar(not is_instance_valid(j), "o recorte se remove da cena")
	# uma vez por save
	GS.flags.erase(J.FLAG)
	J.exibir_uma_vez()
	await _frames(3)
	_checar(GS.flag(J.FLAG) == true, "exibir_uma_vez grava a flag")
	var abertos := 0
	for n in root.get_children():
		if n.get_script() and n.get_script().get_global_name() == "Jornal":
			abertos += 1
			n._t = 5.0
			n.continuar()
	_checar(abertos == 1, "exibir_uma_vez abre um recorte")
	await _frames(40)
	var depois := 0
	var chamada = J.exibir_uma_vez()
	await chamada
	for n in root.get_children():
		if n.get_script() and n.get_script().get_global_name() == "Jornal":
			depois += 1
	_checar(depois == 0, "com a flag gravada o recorte não volta")
	GS.flags.erase(J.FLAG)
	GS.flags.erase("ui_aberta")


# ============================================================================ visita 3
func _teste_sustos_v3() -> void:
	print("-- sustos no caminho: visita 3")
	GS.novo_jogo()
	GS.jogando = true
	GS.set_flag("tem_lanterna")
	GS.comecar_visita(3)
	await _carregar("res://world/niveis/castelinho.tscn")
	var SC = load("res://world/niveis/sustos_caminho.gd")
	var sc: Node = nivel.get_node_or_null("SustosCaminho")
	_checar(sc != null, "visita 3: SustosCaminho instalado no nível")
	_checar(SC.CHAVES.size() == 3 and "v3_tito_corredor" in SC.CHAVES and "v3_armadura" in SC.CHAVES and "v4_relampago_janela" in SC.CHAVES,
		"as 3 chaves registradas")
	for k in SC.CHAVES:
		_checar(not GS.flag("susto_" + k), "flag de %s começa desligada" % k)

	# condição de adiar: fala do Guia ocupando
	_guia().falar("bentinho", ["Teste de fala longa para ocupar o Guia."], true)
	await _frames(5)
	_checar(not sc.livre(), "com fala do Guia o susto adia (livre() = false)")
	_guia().cancelar()
	await _frames(10)
	_checar(sc.livre(), "sem fala nem UI o jogador está livre")

	# fantasma do Tito: sai de verdade pelo caminho (entrar na sala 10 olhando para o fundo do corredor)
	GS.set_flag("v3_ato2_feito", true)
	nivel.player.global_position = Vector3(-17.0, 0.1, -21.9)
	nivel.player.rotation.y = -PI / 2.0              # olha para +x (o fundo do corredor)
	nivel.player.cabeca.rotation.x = 0.0
	await _frames(5)
	nivel._entrou(10)
	var apareceu := [false]
	var viu := await _ate(func():
		_guia().cancelar()
		if nivel.get_node_or_null("FantasmaTito") != null:
			apareceu[0] = true
		return GS.flag("susto_v3_tito_corredor") == true, 900)
	_checar(viu, "entrando no corredor e olhando para o fundo, o fantasma do Tito dispara sozinho")
	await _frames(2)
	_checar(apareceu[0] or nivel.get_node_or_null("FantasmaTito") != null, "o fantasma do Tito existiu no corredor")
	var sumiu := await _ate(func(): return nivel.get_node_or_null("FantasmaTito") == null, 300)
	_checar(sumiu, "e sumiu depois da corrida (nada sobra na cena)")
	_checar(not sc.forcar("v3_tito_corredor"), "só uma vez (o segundo forcar() não dispara)")
	# visual do fantasma: translúcido e claro
	var f = SC.criar_fantasma()
	var mat: StandardMaterial3D = f.get_meta("material")
	_checar(mat.albedo_color.a < 0.9 and mat.albedo_color.b > 0.7, "fantasma pálido e translúcido")
	f.free()

	# armadura: o fallback dispara ao olhar de volta depois de passar
	_checar(not nivel._armadura.visible, "armadura escondida antes")
	nivel.player.global_position = Vector3(-15.4, 0.1, -28.0)
	GS.entrar_sala(nivel._global(22))
	nivel.player.rotation.y = PI / 2.0             # olha para -x, de costas para a armadura
	await _frames(6)
	_checar(not GS.flag("susto_v3_armadura"), "olhando para longe a armadura não aparece")
	nivel.player.rotation.y = -PI / 2.0            # vira e olha para +x, a armadura
	var arm := await _ate(func(): return GS.flag("susto_v3_armadura") == true and nivel._armadura.visible, 300)
	_checar(arm, "passou pela sala e olhou de volta: a armadura aparece (fallback)")
	_checar(nivel._armadura_estado == 3, "estado da armadura = 3 (o gatilho original não repete)")
	await _frames(2)


# ============================================================================ visita 4
func _teste_hall_v4() -> void:
	print("-- sustos no caminho + lampejos de água: visita 4")
	GS.novo_jogo()
	GS.jogando = true
	GS.comecar_visita(4)
	await _carregar("res://world/niveis/castelinho.tscn")
	var sc: Node = nivel.get_node_or_null("SustosCaminho")
	_checar(sc != null, "visita 4: SustosCaminho instalado")
	# relâmpago + Figura fora da janela do hall: pelo caminho (entrar no hall e olhar para a janela)
	nivel.player.global_position = Vector3(-9.0, 0.1, -12.9)
	nivel.player.rotation.y = -PI / 2.0              # olha para +x, a janela leste
	nivel.player.cabeca.rotation.x = 0.0
	await _frames(5)
	nivel._entrou(7)
	var ok := await _ate(func():
		_guia().cancelar()
		return GS.flag("susto_v4_relampago_janela") == true, 900)
	_checar(ok, "no hall olhando para a janela, o relâmpago revela a Figura (disparou sozinho)")
	await _frames(60)

	# lampejos de água: nada sobra e são 3
	var FA = load("res://world/flash_agua.gd")
	_checar(FA.N_LAMPEJOS == 3 and FA.ALTURA > 1.2 and FA.ALTURA < 1.4, "3 lampejos que sobem até ~1,3 m")
	_checar(nivel.get_node_or_null("FlashAgua") == null, "antes: nenhum FlashAgua na cena")
	FA.disparar(nivel)
	await _frames(2)
	_checar(nivel.get_node_or_null("FlashAgua") != null, "durante: o nó FlashAgua existe")
	var vistos := {}
	var fim := await _ate(func():
		var r := nivel.get_node_or_null("FlashAgua")
		if r:
			for c in r.get_children():
				vistos[c.get_instance_id()] = true
		return nivel.get_node_or_null("FlashAgua") == null, 600)
	_checar(fim, "depois: o FlashAgua se apagou (nada sobra)")
	_checar(vistos.size() >= 2, "os lampejos foram vários (%d vistos)" % (vistos.size() + 1))
	# o gancho da linha da fala: dispara quando a linha com "A água desce" aparece
	_guia().cancelar()
	await _ate(func(): return not _guia().ocupado(), 600)
	await _frames(20)                  # o Guia acaba de largar o cancelamento anterior (senão a fala nova seria engolida)
	FA.na_linha(nivel, "Ouça. A água desce por aqui.")
	_guia().falar("???", ["Essa porta nunca existiu.", "Ouça. A água desce por aqui."])
	var flashou := await _ate(func():
		if _guia().ocupado():
			_guia().avancar()
		return nivel.get_node_or_null("FlashAgua") != null, 1500)
	_checar(FA.mesma_linha("Ou0a. A 4gua desce p0r 4qui.", "Ouça. A água desce por aqui.") and not FA.mesma_linha("Essa porta nunca existiu.", "Ouça. A água desce por aqui."),
		"a corrupção do texto não impede o gancho (comparação por semelhança)")
	_checar(flashou, "a linha \"Ouça. A água desce por aqui.\" dispara os lampejos")
	_guia().cancelar()
	await _ate(func(): return nivel.get_node_or_null("FlashAgua") == null, 600)
	_checar(nivel.get_node_or_null("FlashAgua") == null, "e de novo nada sobra")


# ============================================================================ porão
func _teste_goteiras_e_agua() -> void:
	print("-- porão: goteiras e água ferrugem")
	GS.novo_jogo()
	GS.jogando = true
	GS.set_flag("tem_visor", true)
	GS.comecar_visita(5)
	await _carregar("res://world/niveis/porao.tscn")
	nivel.ameacas_ligadas = false
	var G = load("res://world/goteiras.gd")
	_checar(G.cruzou(5.9, 0.5, 0.4) and G.cruzou(5.9, 0.5, 5.95) and not G.cruzou(5.9, 0.5, 3.0) and G.cruzou(1.0, 2.0, 1.5) and not G.cruzou(1.0, 2.0, 2.5),
		"cruzou(): cruzamento do instante dentro do loop de 6 s, com a volta")
	_checar(G.IMPACTOS.size() == 5 and G.CICLO == 6.0, "5 pingos no loop de 6 s (goteira.ogg)")
	var ok_salas := 0
	for i in nivel.salas:
		if i == 14:
			continue
		var g: Node = nivel.salas[i].raiz.get_node_or_null("Goteiras")
		if g != null and g.pontos.size() >= 2 and g.pontos.size() <= 3 and g.pontos[0]["queda"] is CPUParticles3D and g.pontos[0]["splash"] is CPUParticles3D:
			ok_salas += 1
	_checar(ok_salas == nivel.salas.size(), "salas carregadas têm Goteiras com 2 ou 3 pontos (%d de %d)" % [ok_salas, nivel.salas.size()])
	nivel.ir_para_sala(14)
	await _frames(10)
	_checar(nivel.salas.has(14) and nivel.salas[14].raiz.get_node_or_null("Goteiras") == null, "sala 95 (quarto do Tito): sem goteiras")
	nivel.ir_para_sala(3)
	await _frames(10)
	var g3: Node = nivel.salas[3].raiz.get_node_or_null("Goteiras")
	_checar(g3 != null, "sala 84: Goteiras criadas")
	var pt: Dictionary = g3.pontos[0]
	g3.soltar(pt)
	g3.respingar(pt)
	_checar((pt["queda"] as CPUParticles3D).emitting and (pt["splash"] as CPUParticles3D).emitting, "soltar/respingar liga as partículas")
	_checar((pt["teto"] as float) > g3.superficie(pt) + 1.5, "a gota nasce no teto, bem acima da superfície")

	# água ferrugem
	var AF = load("res://world/agua_ferrugem.gd")
	_checar(AF.COR_AGUA_FERRUGEM == Color(0.32, 0.08, 0.05), "COR_AGUA_FERRUGEM é a constante pedida")
	var nomes := []
	for u in nivel.mat_agua.shader.get_shader_uniform_list():
		nomes.append(u["name"])
	_checar("tint_cor" in nomes and "tint_quantidade" in nomes, "shader porao_agua tem os uniforms tint_cor e tint_quantidade")
	var af: Node = nivel.get_node_or_null("AguaFerrugem")
	_checar(af != null, "AguaFerrugem instalada no porão")
	await _frames(5)
	_checar(af.quantidade == 0.0 and not af.alvo_ativo(), "sem Figura por perto: água normal")
	# a Figura aparece a 4 m
	var fig = nivel.figura
	var dir: Vector3 = -player.camera.global_transform.basis.z
	dir.y = 0.0
	fig.reiniciar(player.global_position + dir.normalized() * 4.0 + Vector3(0, 0.05, 0), false)
	fig.visible = true
	await _frames(60)
	_checar(af.alvo_ativo() and af.quantidade > 0.9, "Figura a 4 m: a água fica ferrugem (%.2f)" % af.quantidade)
	_checar(nivel.mat_agua.get_shader_parameter("tint_quantidade") > 0.9 and nivel.mat_agua.get_shader_parameter("tint_cor") == AF.COR_AGUA_FERRUGEM,
		"o material recebe tint_cor e tint_quantidade")
	fig.esconder()
	af.quantidade = 1.0
	af._process(0.7)                    # passos manuais: 0,7 s depois da Figura sumir a água ainda está turva
	_checar(af.quantidade > 0.5 and af.quantidade < 0.9, "ela some: a água volta devagar (%.2f após 0,7 s)" % af.quantidade)
	af._process(1.5)
	_checar(af.quantidade == 0.0, "e está normal depois de ~2 s")
	# nunca no quarto do Tito
	nivel.ir_para_sala(14)
	await _frames(10)
	fig.reiniciar(player.global_position + Vector3(2.0, 0.05, 0), false)
	fig.visible = true
	await _frames(40)
	_checar(not af.alvo_ativo() and af.quantidade == 0.0, "sala 95: a água não tinge nem com a Figura perto")
	fig.esconder()


