extends SceneTree
## Teste automático (headless) do MIOLO do Calçadão da Barra (Módulo 14, lugar `barra`): carrega, cenário e orçamento, a plaquinha,
## o pescador antes da hora, a tarrafa com o boto (lance cedo, janela perdida, E/clique, 2 lances, rede cheia, SEM o 3º lance que
## afoga), objetivo e dica no Mapa, a conversa que dá a pista `barra_pescador` UMA vez só, `concluir()` (flag + volta ao
## Castelinho), a volta pela placa (rejogar sem pista nova nem nova saída forçada), cancelar ao se afastar, o portão de volta e o
## escurecer do céu. O contrato geral da base (borda, rede de segurança, HUD) está em `tests/cidade_test.gd`.
## Uso: godot --headless -s res://tests/cidade_barra_test.gd
## (não referencie classes do jogo por nome aqui: o script de teste compila antes dos autoloads; use load())

const CENA := "res://world/niveis/cidade_barra.tscn"

var falhas := 0
var GS: Node
var Gui: Node
var Obj: GDScript
var main: Node
var nivel: Node
var player: Node


func _initialize() -> void:
	_rodar.call_deferred()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _frames(n: int) -> void:
	for i in n:
		await physics_frame


func _ate(cond: Callable, max_frames := 900) -> bool:
	for i in max_frames:
		if cond.call():
			return true
		await physics_frame
	return cond.call()


## Avança as falas da Guia até acabarem.
func _falas(max_frames := 3000) -> bool:
	for i in max_frames:
		if not Gui.ocupado():
			return true
		Gui.avancar()
		await physics_frame
	return not Gui.ocupado()


func _rodar() -> void:
	Engine.time_scale = 4.0
	GS = root.get_node("/root/GameState")
	Gui = root.get_node("/root/Guia")
	Obj = load("res://world/objetivo.gd")
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	main.tela_titulo.queue_free()
	GS.novo_jogo()
	GS.jogando = true
	main.hud.visible = true
	GS.visita = 3
	GS.entrar_sala(45)
	await _carregar()
	await _cenario()
	await _plaquinha_e_pescador_cedo()
	await _pesca()
	await _dica_e_cancelar()
	await _conversa_e_conclusao()
	await _rejogar()
	await _portao_e_ceu()
	Engine.time_scale = 1.0
	load("res://world/niveis/ato2_pecas.gd")._tex.clear()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _carregar() -> void:
	await main.carregar_mundo(CENA, "Spawn")
	nivel = main.mundo.get_child(0)
	player = main.player
	nivel.pulou_intro = true               # sem a explicação (ela é testada à parte em _pesca)
	nivel.espera_min = 0.3
	nivel.espera_max = 0.6
	await _frames(10)


func _perto_do_ponto() -> void:
	player.global_position = nivel.PONTO + Vector3(0.0, 0.1, 1.3)
	player.velocity = Vector3.ZERO
	await _frames(3)


func _apertar_lancar() -> void:
	Input.action_press("interagir")
	await _frames(3)
	Input.action_release("interagir")
	await _frames(2)


# ============================================================================
func _cenario() -> void:
	print("-- carrega e cenário")
	_checar(main.nivel_atual == CENA and nivel.id == "barra", "carrega a cena e o id 'barra'")
	_checar(nivel.hora == 2 and nivel.clima == 0, "hora ENTARDECER e clima limpo (como no esqueleto)")
	_checar(nivel.find_child("Visor", true, false) == null, "sem Visor")
	_checar(not GS.cidade_feita("barra") and not GS.flag("pista_barra_pescador"), "começa sem pista nem 'feito'")
	_checar(nivel.estagio() == 0 and not nivel.em_pesca and not nivel.rede_cheia, "estágio 0: ainda não pescou")
	_checar(nivel.boto != null and nivel.boto.is_inside_tree() and nivel._pescadores.size() == 4, "boto e 4 pescadores (silhuetas)")
	_checar(nivel.velho != null and nivel.find_child("PescadorVelhoFala", true, false) != null, "pescador mais velho com interação")
	_checar(nivel.find_child("PontoTarrafa", true, false) != null and nivel.find_child("Plaquinha", true, false) != null, "ponto da tarrafa e plaquinha")
	_checar(nivel.find_child("Molhe", true, false) is MultiMeshInstance3D, "molhe de pedra em MultiMesh")
	_checar(nivel.find_child("AguaPerto", true, false) != null and nivel.find_child("FundoLuzes", true, false) != null, "água e a ponte/outra margem ao fundo")
	var luzes := 0
	var malhas := 0
	for n in nivel.find_children("*", "Node", true, false):
		if n is Light3D:
			luzes += 1
		elif n is MeshInstance3D:
			malhas += 1
	_checar(luzes <= 6, "no máximo 6 luzes (%d)" % luzes)
	_checar(malhas <= 120, "poucas malhas (%d); o resto está em lotes combinados" % malhas)
	var texto: String = nivel.find_child("PlacaTexto", true, false).text
	_checar(texto.contains("2026") and texto.contains("Patrimônio"), "a plaquinha cita o patrimônio de 2026 (fato do dossiê)")
	var tudo := ""
	for l in nivel.find_children("*", "Label3D", true, false):
		tudo += (l as Label3D).text + "\n"
	_checar(not tudo.to_lower().contains("geraldona") and not tudo.to_lower().contains("bagrinho"), "sem nomes de botos reais nas placas")
	_checar(Obj.atual() == nivel._texto_objetivo() and "tarrafa" in Obj.atual().to_lower(), "Mapa/objetivo: '%s'" % Obj.atual())
	var area: Rect2 = nivel.area
	_checar(area.has_point(Vector2(nivel.PONTO.x, nivel.PONTO.z)) and area.has_point(Vector2(nivel.VELHO_POS.x, nivel.VELHO_POS.z)), "plataforma e pescador estão dentro da AREA")
	_checar(main.hud.lbl_sala.text == "CIDADE · CALÇADÃO DA BARRA", "HUD: '%s'" % main.hud.lbl_sala.text)


func _plaquinha_e_pescador_cedo() -> void:
	print("-- plaquinha e o pescador antes da hora")
	var antes: int = int(GS.contadores.get("pistas_tito", 0))
	nivel._ler_plaquinha()
	await _frames(3)
	_checar(Gui.ocupado(), "ler a plaquinha abre a fala do SISTEMA")
	_checar(await _falas(), "a leitura termina")
	# o pescador, sem a rede cheia: pede a tarrafa primeiro e NÃO dá a pista
	nivel.falar_velho()
	await _frames(3)
	_checar(Gui.ocupado() and nivel.conversando, "o pescador responde")
	_checar(await _falas(), "a fala termina")
	await _frames(3)
	_checar(not nivel.conversando and not GS.flag("pista_barra_pescador") and int(GS.contadores.get("pistas_tito", 0)) == antes, "sem a rede cheia não há pista")
	_checar(GS.cidade_feita("barra") == false and main.nivel_atual == CENA, "e não conclui nem sai")


func _pesca() -> void:
	print("-- tarrafa com o boto")
	await _perto_do_ponto()
	# a explicação da Tainá (só na 1ª vez): bloqueia e depois a pesca roda
	nivel.pulou_intro = false
	nivel.comecar_pesca()
	await _frames(3)
	_checar(nivel.em_pesca and nivel.estagio() == 1 and nivel._spot.collision_layer == 0, "E no ponto começa a pesca (e esconde o aviso do ponto)")
	_checar(Gui.ocupado(), "a Tainá explica antes do primeiro lance")
	_checar(await _falas(), "a explicação termina")
	nivel.pulou_intro = true
	_checar("quando o boto bater" in Obj.atual().to_lower() or "quando o boto" in Obj.atual().to_lower(), "objetivo na pesca: '%s'" % Obj.atual())
	# lance cedo: cai na água vazia, não conta
	var ok: bool = await _ate(func() -> bool: return nivel.fase == nivel.Fase.ESPERA and nivel._desde_lance > 0.45, 300)
	_checar(ok, "espera o boto")
	nivel.lancar()
	await _frames(20)
	_checar(nivel.lances_ok == 0 and nivel.tainhas == 0 and nivel.fase != nivel.Fase.LANCADO, "lance cedo não conta (e não pune)")
	# janela perdida: o boto bate a cabeça, o jogador não faz nada
	ok = await _ate(func() -> bool: return nivel.janela_aberta, 900)
	_checar(ok, "o boto bate a cabeça: a janela abre")
	_checar(nivel._exclama.visible, "o '!' amarelo aparece")
	var j0: float = nivel._janela_t
	ok = await _ate(func() -> bool: return not nivel.janela_aberta, 900)
	await _frames(5)
	_checar(ok and nivel.lances_ok == 0 and nivel.perdidas == 1, "janela perdida: sem pena (perdidas=%d, lances=%d)" % [nivel.perdidas, nivel.lances_ok])
	await _falas(200)       # (a dica da Tainá, se apareceu)
	# 1º lance pelo botão (E): conta
	ok = await _ate(func() -> bool: return nivel.janela_aberta, 900)
	_checar(ok, "o boto sinaliza de novo")
	_checar(nivel._janela_t > j0 - 0.01, "a janela fica MAIS folgada depois de um lance perdido (%.2f > %.2f)" % [nivel._janela_t, j0])
	await _apertar_lancar()
	ok = await _ate(func() -> bool: return nivel.lances_ok == 1, 300)
	_checar(ok and nivel.tainhas > 0 and nivel.perdidas == 0, "E dentro da janela: lance 1 pega tainhas (%d)" % nivel.tainhas)
	_checar(nivel.fase == nivel.Fase.LANCADO or nivel.fase == nivel.Fase.ESPERA, "segue o jogo")
	_checar(player.pode_mover and absf(player.global_position.y) < 0.2, "o jogador continua livre e em pé (sem puxão)")
	await _falas(200)
	# lance 2 (por código): a rede enche
	ok = await _ate(func() -> bool: return nivel.janela_aberta, 1200)
	_checar(ok, "terceiro sinal do boto")
	var tainhas1: int = nivel.tainhas
	nivel.lancar()
	ok = await _ate(func() -> bool: return nivel.rede_cheia, 900)
	_checar(ok and nivel.lances_ok == nivel.LANCES and nivel.tainhas > tainhas1, "lance 2: a rede enche (%d tainhas)" % nivel.tainhas)
	_checar(not nivel.em_pesca and nivel.fase == nivel.Fase.LIVRE, "a pesca acaba nos 2 lances: NÃO existe o 3º lance")
	_checar(nivel._pilha.visible and nivel._pilha.find_child("Pilha", true, false) != null, "a pilha da rede (com a sandália de criança) aparece")
	_checar(nivel._spot.collision_layer == 4, "o ponto da tarrafa volta a aceitar E (rejogar)")
	_checar(nivel.estagio() == 2 and "pescador mais velho" in Obj.atual(), "objetivo: '%s'" % Obj.atual())
	_checar(nivel._exclama_velho.visible, "o pescador mais velho ganha um '!'")
	_checar(not GS.flag("pista_barra_pescador") and not GS.cidade_feita("barra"), "ainda sem pista: ela sai da conversa")
	await _falas()


func _dica_e_cancelar() -> void:
	print("-- dica no Mapa e se afastar")
	nivel._ocioso = nivel.DICA_APOS + 5.0
	_checar("Dica:" in Obj.atual() and "molhe" in Obj.atual(), "demorando, o objetivo ganha uma dica: '%s'" % Obj.atual())
	nivel._ocioso = 0.0
	_checar(not ("Dica:" in Obj.atual()), "e a dica some quando há progresso")
	# rejogar do zero e sair andando cancela a pesca (sem prender nada)
	await _perto_do_ponto()
	nivel.comecar_pesca()
	await _frames(3)
	_checar(nivel.em_pesca and not nivel.rede_cheia and nivel.lances_ok == 0, "rejogar recomeça do zero")
	nivel.falar_velho()
	await _frames(3)
	_checar(not nivel.conversando, "com a pesca em andamento o pescador manda terminar antes")
	await _falas(300)
	player.global_position = Vector3(-34.0, 0.1, 0.0)
	var ok: bool = await _ate(func() -> bool: return not nivel.em_pesca, 120)
	_checar(ok and nivel._spot.collision_layer == 4 and nivel.fase == nivel.Fase.LIVRE, "afastar-se cancela a pesca e solta o ponto")
	await _frames(60)
	_checar(nivel.boto.position.y < nivel.COTA_AGUA + 0.1, "o boto volta a nadar")


func _conversa_e_conclusao() -> void:
	print("-- conversa, pista e concluir")
	await _perto_do_ponto()
	# enche a rede de novo (por código, rápido)
	nivel.comecar_pesca()
	for n in 2:
		var ok: bool = await _ate(func() -> bool: return nivel.janela_aberta, 1200)
		_checar(ok, "sinal %d" % (n + 1))
		nivel.lancar()
		await _frames(6)
	var ok2: bool = await _ate(func() -> bool: return nivel.rede_cheia, 900)
	_checar(ok2, "rede cheia")
	await _falas()
	var antes: int = int(GS.contadores.get("pistas_tito", 0))
	_checar(not GS.flag("pista_barra_pescador"), "pista ainda não achada")
	nivel.falar_velho()
	var falou := false
	for i in 4000:
		if GS.flag("pista_barra_pescador"):
			falou = true
		if main.nivel_atual != CENA:
			break
		if Gui.ocupado():
			Gui.avancar()
		await physics_frame
	_checar(falou, "a pista 'barra_pescador' sai da conversa")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == antes + 1, "conta UMA vez (pistas_tito +1)")
	var voltou: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 900)
	_checar(voltou, "depois da pista e do comentário da Tainá, concluir() volta ao Castelinho")
	await _frames(10)
	_checar(GS.cidade_feita("barra"), "flag cidade_barra_feito gravada")
	_checar(GS.flag("pista_barra_pescador") and int(GS.contadores.get("pistas_tito", 0)) == antes + 1, "a pista continua contada uma vez")
	var castelo: Node = main.mundo.get_child(0)
	var vc: Node3D = castelo.find_child("Spawn_volta_cidade", true, false)
	_checar(vc != null and main.player.global_position.distance_to(vc.global_position) < 1.5, "chega na calçada (Spawn_volta_cidade)")
	_checar(GS.visita == 3 and GS.sala_atual == 45, "visita e sala intactas")


func _rejogar() -> void:
	print("-- voltar pela placa e rejogar")
	await _carregar()
	_checar(GS.cidade_feita("barra") and GS.flag("pista_barra_pescador"), "lugar já feito")
	_checar(Obj.atual() == nivel._texto_objetivo() and "Volte ao Castelinho" in Obj.atual(), "objetivo de lugar feito: '%s'" % Obj.atual())
	var antes: int = int(GS.contadores.get("pistas_tito", 0))
	await _perto_do_ponto()
	nivel.comecar_pesca()
	for n in 2:
		var ok: bool = await _ate(func() -> bool: return nivel.janela_aberta, 1200)
		_checar(ok, "rejogo: sinal %d" % (n + 1))
		nivel.lancar()
		await _frames(6)
	var ok2: bool = await _ate(func() -> bool: return nivel.rede_cheia, 900)
	_checar(ok2, "dá para rejogar: rede cheia de novo")
	await _falas()
	nivel.falar_velho()
	await _frames(3)
	_checar(nivel.conversando, "o pescador fala outra coisa")
	_checar(await _falas(), "a fala termina")
	await _frames(20)
	_checar(main.nivel_atual == CENA and nivel.is_inside_tree(), "sem pista nova não manda de volta: o jogador fica")
	_checar(int(GS.contadores.get("pistas_tito", 0)) == antes, "pistas_tito intacto (%d)" % antes)
	_checar(nivel.estagio() == 3, "estágio 3")


func _portao_e_ceu() -> void:
	print("-- portão de volta e o céu escurecendo")
	# o céu escurece sem mudar a `hora` do esqueleto
	var amb0: float = nivel.env.ambient_light_energy
	var topo0: Color = (nivel.env.sky.sky_material as ProceduralSkyMaterial).sky_top_color
	nivel._t = nivel.DUSK_SEG
	nivel._prox_dusk = 0.0
	await _frames(5)
	var topo1: Color = (nivel.env.sky.sky_material as ProceduralSkyMaterial).sky_top_color
	_checar(topo1.get_luminance() < topo0.get_luminance(), "o céu escurece com o tempo")
	_checar(nivel.hora == 2 and nivel._dusk <= nivel.DUSK_MAX + 0.001, "`hora` fica ENTARDECER e o escuro tem limite")
	var acesas := 0
	for l in nivel._luzes:
		if l.light_energy > 0.9:
			acesas += 1
	_checar(acesas == nivel._luzes.size() and amb0 > 0.0, "as lâmpadas acendem (%d)" % acesas)
	# o portão sempre funciona (nunca preso), mesmo no meio de uma pesca
	await _perto_do_ponto()
	nivel.comecar_pesca()
	await _frames(5)
	var volta: Node = nivel.find_child("PortaoVolta", true, false)
	_checar(volta != null, "portão 'Voltar ao Castelinho'")
	volta.interagir(player)
	var ok: bool = await _ate(func() -> bool: return main.nivel_atual == GS.CENA_CASTELINHO and not bool(root.get_node("/root/Transicao").ocupado), 900)
	_checar(ok, "o portão volta ao Castelinho mesmo no meio da pesca")
	await _frames(10)
	_checar(int(GS.corruption_manual) == -1, "corrupção manual liberada")
