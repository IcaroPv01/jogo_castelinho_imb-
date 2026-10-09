extends SceneTree
## Teste automático (headless) do Q e da Figura Branca "Granny pura" (módulo 9, V2_ROTEIRO §4.3):
##   - Visor: visitas 1 e 2 sem risco; V3 só susto (Figura no slide só depois de ~3,5 s, estouro só aos 10 s, nunca
##     perseguição); V4 estoura em ~7 s e porão em ~5 s; graça depois do bloqueio; Figura do slide é um corpo no
##     MUNDO sobre o rastro do jogador (nunca atrás de parede sem caminho) e com teste de profundidade.
##   - Perseguidora: não congela quando olhada, não atravessa parede, perde o jogador, segue o rastro, procura e
##     desiste (e some só fora da vista); velocidade entre o andar e o correr.
##   - Chaves de debug: figura_off, imortal, atencao_congelada.
## Uso: godot --headless -s res://tests/figura_q_test.gd
## (não referencie classes do jogo por nome: o script de teste compila antes dos autoloads; use load())

var falhas := 0
var GS: Node
var VisorCls
var FigCls
var RastroCls
var DebugCls
var v                        # o Visor da fixture
var mundo: Node3D            # mundo da fixture do Visor
var arena: Node3D            # mundo da fixture da perseguidora
var jog: CharacterBody3D     # jogador de mentira (grupo "player", com `camera`)
var dt_q := 0.0              # duração de 1 quadro de física (time_scale / 60)


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	VisorCls = load("res://world/visor.gd")
	FigCls = load("res://creatures/figura_branca.gd")
	RastroCls = load("res://world/rastro.gd")
	DebugCls = load("res://ui/debug.gd")
	Engine.time_scale = 4.0
	dt_q = Engine.time_scale / 60.0
	_preparar_visor()

	await _teste_rastro()
	await _teste_v1_v2()
	await _teste_v3()
	await _teste_v4_e_porao()
	await _teste_slide_no_mundo()
	await _teste_graca_e_esvaziar()
	await _teste_debug_visor()
	_desmontar_visor()

	await _teste_nao_congela()
	await _teste_parede()
	await _teste_perde_de_vista()
	await _teste_desiste_fora_da_vista()
	await _teste_corredor_em_ele()
	await _teste_velocidades()
	await _teste_debug_figura()

	Engine.time_scale = 1.0
	DebugCls.figura_off = false
	DebugCls.imortal = false
	DebugCls.atencao_congelada = false
	Input.action_release("visor")
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ================================================================== fixture do Visor (tempo conduzido à mão)
func _preparar_visor() -> void:
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
	v.set_process(false)   # o tempo é conduzido à mão (_passo)


func _desmontar_visor() -> void:
	Input.action_release("visor")
	if is_instance_valid(mundo):
		mundo.queue_free()


func _zerar(visita: int) -> void:
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
	v._tem_pos_fig = false
	v._fig_no_mundo = false
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.selecionar_disco(GS.Epoca.E1950)


func _passo(segundos: float, dt := 0.1) -> void:
	for i in int(round(segundos / dt)):
		v._process(dt)


func _q(apertado: bool) -> void:
	if apertado:
		Input.action_press("visor")
	else:
		Input.action_release("visor")
	await create_timer(0.16, true, false, true).timeout   # tempo real (INTERVALO_MIN do Visor)
	v._process(0.016)


## O jogador andou `metros` em linha reta pelo -X até (0,0,0) (rastro de migalhas do Visor).
func _dar_rastro(metros: float) -> void:
	v._rastro.limpar()
	var x := -metros
	while x <= 0.0:
		v._rastro.seguir(Vector3(x, 0.0, 0.0))
		x += 0.5


## Segura o Q até `quando` (s) em passos de 0,1 s e devolve {t_fig, t_estouro, grupo_vazio, atrav}.
func _segurar(limite: float, visita: int) -> Dictionary:
	var r := {"t_fig": -1.0, "t_estouro": -1.0, "grupo_vazio": true, "atrav": []}
	var f = func(x): r["atrav"].append(x)
	v.figura_atravessou.connect(f)
	await _q(true)
	var t := 0.0
	while t < limite:
		v._process(0.1)
		t += 0.1
		if r["t_fig"] < 0.0 and v.figura_visivel:
			r["t_fig"] = t
		if r["t_estouro"] < 0.0 and VisorCls.bloqueado():
			r["t_estouro"] = t
			break
		if not get_nodes_in_group("figura_branca").is_empty():
			r["grupo_vazio"] = false
	v.figura_atravessou.disconnect(f)
	return r


# ================================================================== o rastro de migalhas
func _teste_rastro() -> void:
	print("-- Rastro de migalhas")
	var r = RastroCls.new()
	root.add_child(r)
	for i in 200:
		r.seguir(Vector3(i * 0.25, 0.0, 0.0))   # 50 m andados, um ponto a cada 0,25 m
	_checar(r.comprimento() <= RastroCls.COMP_MAX + 0.6, "guarda só os últimos ~45 m (%.1f m)" % r.comprimento())
	_checar(r.pontos.size() <= 100, "poucos pontos (um a cada 0,5 m: %d)" % r.pontos.size())
	var p: Vector3 = r.ponto_atras(14.0)
	_checar(absf(p.x - (r.pos_atual.x - 14.0)) < 0.05, "ponto_atras(14) está 14 m atrás ao longo do caminho (%.2f)" % (r.pos_atual.x - p.x))
	r.seguir(Vector3(500.0, 0.0, 0.0))   # teleporte
	_checar(r.pontos.size() == 1 and r.comprimento() < 0.1, "um pulo de mais de 4 m (teleporte) apaga o rastro")
	r.queue_free()


# ================================================================== visitas 1 e 2: sem risco
func _teste_v1_v2() -> void:
	print("-- V1 e V2: segurar Q por 30 s não faz nada")
	for vis in [1, 2]:
		_zerar(vis)
		_dar_rastro(30.0)
		var r: Dictionary = await _segurar(30.0, vis)
		_checar(GS.atencao == 0.0, "V%d: atenção continua 0 (%.2f)" % [vis, GS.atencao])
		_checar(r["t_fig"] < 0.0 and not is_instance_valid(v._figura), "V%d: nenhuma Figura no slide" % vis)
		_checar(r["t_estouro"] < 0.0 and not VisorCls.bloqueado() and r["atrav"].is_empty(), "V%d: nada de susto, bloqueio nem perseguição" % vis)
		_checar(v.ativo, "V%d: o Visor funciona normalmente" % vis)
		await _q(false)


# ================================================================== visita 3: só susto
func _teste_v3() -> void:
	print("-- V3: Figura só depois de ~3,5 s, estouro só aos 10 s, nunca perseguição real")
	_zerar(3)
	_dar_rastro(30.0)
	var r: Dictionary = await _segurar(14.0, 3)
	_checar(r["t_fig"] >= 3.4 and r["t_fig"] <= 4.0, "a Figura do slide surge aos ~3,5 s (%.1f s)" % r["t_fig"])
	_checar(r["t_estouro"] >= 9.0 and r["t_estouro"] <= 10.4, "o estouro não vem antes de 9 s (%.1f s)" % r["t_estouro"])
	_checar(r["atrav"].is_empty(), "V3: o susto não solta Figura de verdade (figura_atravessou não sai)")
	_checar(r["grupo_vazio"], "V3: nenhuma FiguraBranca real (grupo figura_branca vazio) em nenhum momento")
	_checar(VisorCls.bloqueado() and absf(VisorCls.bloqueio_restante() - 10.0) < 0.5, "V3: Visor bloqueado por 10 s depois do susto")
	await _q(false)

	# a Figura do slide é só visual, no mundo, com teste de profundidade
	_zerar(3)
	_dar_rastro(30.0)
	await _q(true)
	_passo(7.0)
	var f = v._figura
	_checar(is_instance_valid(f) and f.somente_visual and f.visible, "a Figura do slide existe e está visível com o Q apertado")
	_checar(not f.is_in_group("figura_branca") and f.collision_layer == 0 and f.collision_mask == 0, "ela não é uma perseguidora: sem grupo, sem colisão")
	_checar(not f.is_physics_processing(), "e não tem IA (sem física)")
	var mat: ShaderMaterial = f._mat
	_checar(mat.shader.code.find("depth_test_disabled") < 0, "material COM teste de profundidade (as paredes a escondem)")
	var todas_malhas := true
	for m in f.find_children("*", "MeshInstance3D", true, false):
		if m.material_override != mat:
			todas_malhas = false
	_checar(todas_malhas, "todas as malhas usam esse material")
	await _q(false)
	_checar(not f.visible and not v.figura_visivel, "soltar o Q esconde a Figura do slide (só aparece dentro do Visor)")
	# V3 sem rastro: sem onde pôr a Figura, ela não aparece (mas o susto vem igual)
	_zerar(3)
	v._rastro.limpar()
	v._rastro.seguir(Vector3.ZERO)
	var r2: Dictionary = await _segurar(14.0, 3)
	_checar(r2["t_fig"] < 0.0 and r2["t_estouro"] > 9.0, "sem rastro andado ela não surge (nunca fica atrás de parede por mágica), o susto vem")
	await _q(false)


# ================================================================== visita 4 e porão: perseguição de verdade
func _teste_v4_e_porao() -> void:
	print("-- V4 e porão: estouro em ~7 s e ~5 s, a Figura atravessa onde a do slide estava")
	for par in [[4, 7.0], [5, 5.0]]:
		_zerar(par[0])
		_dar_rastro(30.0)
		var pos := [Vector3.INF]
		var h = func(_vis): pos[0] = v.pos_figura_slide()
		v.figura_atravessou.connect(h)
		var r: Dictionary = await _segurar(12.0, par[0])
		v.figura_atravessou.disconnect(h)
		_checar(absf(r["t_estouro"] - par[1]) < 0.4, "visita %d: estouro em ~%.0f s (%.1f s)" % [par[0], par[1], r["t_estouro"]])
		_checar(r["atrav"] == [par[0]], "visita %d: figura_atravessou(%d) emitido" % [par[0], par[0]])
		var p: Vector3 = pos[0]
		_checar(p.is_finite(), "visita %d: há uma posição para a Figura atravessar" % par[0])
		_checar(v._rastro.distancia_ao_rastro(p) < 0.06, "visita %d: ela atravessa SOBRE o rastro do jogador (a %.2f m dele)" % [par[0], v._rastro.distancia_ao_rastro(p)])
		_checar(Vector2(p.x - v._rastro.pos_atual.x, p.z - v._rastro.pos_atual.z).length() >= 4.5, "visita %d: e a pelo menos ~5 m dele (%.1f m): dá para fugir" % [par[0], Vector2(p.x - v._rastro.pos_atual.x, p.z - v._rastro.pos_atual.z).length()])
		await _q(false)
		VisorCls.resetar_estado()


# ================================================================== a Figura do slide nunca está "atrás da parede"
func _teste_slide_no_mundo() -> void:
	print("-- slide: a Figura fica sobre o rastro (U com parede no meio), não numa linha reta pela parede")
	_zerar(3)
	var parede := _parede(mundo, Vector3(2.0, 1.5, -5.5), Vector3(0.3, 3.0, 11.0))
	await physics_frame
	await physics_frame
	# o jogador andou: (0,0) -> (0,-12) -> (4,-12) -> (4,-2); a parede x=2 separa as duas pernas do U
	v._rastro.limpar()
	var pts: Array[Vector3] = []
	var z0 := 0.0
	while z0 >= -12.0:
		pts.append(Vector3(0, 0, z0))
		z0 -= 0.5
	var x0 := 0.5
	while x0 <= 4.0:
		pts.append(Vector3(x0, 0, -12.0))
		x0 += 0.5
	var z1 := -11.5
	while z1 <= -2.0:
		pts.append(Vector3(4.0, 0, z1))
		z1 += 0.5
	for p in pts:
		v._rastro.seguir(p)
	await _q(true)
	_passo(3.8)   # atenção ~0,38: ela acabou de surgir, ~14 m atrás pelo caminho (do outro lado da parede)
	var f = v._figura
	_checar(is_instance_valid(f) and f.visible and v.figura_visivel, "a Figura aparece no slide")
	var onde: Vector3 = f.global_position
	_checar(v._rastro.distancia_ao_rastro(onde) < 0.06, "ela está EM CIMA do rastro (a %.2f m)" % v._rastro.distancia_ao_rastro(onde))
	var de: Vector3 = v._rastro.pos_atual + Vector3.UP * 1.55
	var q := PhysicsRayQueryParameters3D.create(de, onde + Vector3.UP * 1.55, 1)
	var bloqueada: bool = not mundo.get_world_3d().direct_space_state.intersect_ray(q).is_empty()
	_checar(bloqueada, "a linha reta jogador -> Figura atravessa a parede: ela NÃO foi posta por linha reta (e a parede a esconde)")
	var dentro: bool = absf(onde.x - 2.0) < 0.35 and onde.z < -1.0 and onde.z > -11.0
	_checar(not dentro, "a Figura nunca está dentro da parede (%s)" % str(onde))
	_passo(4.6)   # atenção ~0,85: ela anda pelo rastro (volta pelo U) e fica perto, do mesmo lado do jogador
	var perto: Vector3 = f.global_position
	_checar(v._rastro.distancia_ao_rastro(perto) < 0.06, "andando pelo rastro, continua em cima dele")
	_checar(Vector2(perto.x - v._rastro.pos_atual.x, perto.z - v._rastro.pos_atual.z).length() < onde.distance_to(v._rastro.pos_atual) - 3.0, "e chegou mais perto do jogador (%.1f m)" % perto.distance_to(v._rastro.pos_atual))
	await _q(false)
	parede.queue_free()


# ================================================================== graça e esvaziar rápido
func _teste_graca_e_esvaziar() -> void:
	print("-- graça de 6 s depois do estouro e esvaziar em 4 s")
	_zerar(4)
	_dar_rastro(30.0)
	await _segurar(12.0, 4)
	_checar(VisorCls.bloqueado(), "estourou")
	_passo(10.2)
	_checar(not VisorCls.bloqueado(), "bloqueio de 10 s acabou")
	await create_timer(0.2, true, false, true).timeout
	_passo(0.3)
	_checar(v.ativo, "Q volta a funcionar")
	_passo(5.5)
	_checar(GS.atencao == 0.0, "5,5 s depois do bloqueio ainda é graça: atenção 0 (%.2f)" % GS.atencao)
	_check_nova_figura_nao()
	_passo(2.0)
	_checar(GS.atencao > 0.0, "passada a graça a atenção sobe (%.2f)" % GS.atencao)
	GS.definir_atencao(1.0 - 0.001)
	await _q(false)
	var antes: float = GS.atencao
	_passo(2.0)
	_checar(absf((antes - GS.atencao) - 0.5) < 0.07, "soltar o Q: esvazia 0,5 em 2 s, cheio a zero em 4 s (%.2f -> %.2f)" % [antes, GS.atencao])


func _check_nova_figura_nao() -> void:
	_checar(not v.figura_visivel, "e a Figura não aparece durante a graça")


# ================================================================== debug no Visor
func _teste_debug_visor() -> void:
	print("-- debug: figura_off e atencao_congelada no Visor")
	DebugCls.figura_off = true
	_zerar(3)
	_dar_rastro(30.0)
	await _q(true)
	_passo(8.0)
	_checar(GS.atencao > 0.6 and not v.figura_visivel and not (is_instance_valid(v._figura) and v._figura.visible), "figura_off: a Figura do slide nunca aparece (atenção %.2f)" % GS.atencao)
	await _q(false)
	DebugCls.figura_off = false
	DebugCls.atencao_congelada = true
	_zerar(3)
	GS.definir_atencao(0.4)
	_dar_rastro(30.0)
	await _q(true)
	_passo(6.0)
	_checar(absf(GS.atencao - 0.4) < 0.001, "atencao_congelada: o Visor não mexe na atenção (%.2f)" % GS.atencao)
	_checar(not VisorCls.bloqueado(), "e não estoura")
	await _q(false)
	_passo(3.0)
	_checar(absf(GS.atencao - 0.4) < 0.001, "nem esvazia")
	DebugCls.atencao_congelada = false
	GS.definir_atencao(0.0)


# ================================================================== a perseguidora (física de verdade)
func _montar_arena() -> void:
	arena = Node3D.new()
	root.add_child(arena)
	var chao := StaticBody3D.new()
	chao.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = Vector3(400, 1, 400)
	cs.shape = bx
	chao.add_child(cs)
	chao.position = Vector3(0, -0.5, 0)
	arena.add_child(chao)
	var sc := GDScript.new()
	sc.source_code = "extends CharacterBody3D\nvar camera: Camera3D\nvar pode_mover := true\nfunc olhar_para(_p, _t) -> void:\n\tpass\n"
	sc.reload()
	jog = CharacterBody3D.new()
	jog.set_script(sc)
	jog.collision_layer = 2
	jog.collision_mask = 0
	jog.add_to_group("player")
	arena.add_child(jog)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.55, 0)
	jog.add_child(cam)
	jog.camera = cam
	cam.current = true


func _desmontar_arena() -> void:
	if is_instance_valid(arena):
		arena.queue_free()
	arena = null


func _parede(pai: Node3D, centro: Vector3, tam: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bx := BoxShape3D.new()
	bx.size = tam
	cs.shape = bx
	b.add_child(cs)
	b.position = centro
	pai.add_child(b)
	return b


func _figura(pos: Vector3, vel := 3.6) -> Node:
	var f = FigCls.new()
	f.alvo = jog
	f.velocidade = vel
	f.som_ativo = false
	arena.add_child(f)
	f.global_position = pos
	return f


## Roda `seg` s de jogo (quadros de física); `por_quadro` (opcional) é chamado antes de cada quadro com o dt.
func _sim(seg: float, por_quadro := Callable()) -> void:
	var n := int(ceil(seg / dt_q))
	for i in n:
		if por_quadro.is_valid():
			por_quadro.call(dt_q)
		await physics_frame


func _olhar_para(alvo: Vector3) -> void:
	var d := alvo - jog.global_position
	jog.rotation.y = atan2(-d.x, -d.z)


func _teste_nao_congela() -> void:
	print("-- perseguidora: NÃO congela quando olhada")
	_montar_arena()
	jog.global_position = Vector3(0, 0, 0)
	var f = _figura(Vector3(0, 0, -18))
	await _sim(0.3)
	_olhar_para(f.global_position)
	var d0: float = f.global_position.distance_to(jog.global_position)
	await _sim(1.6, func(_dt): _olhar_para(f.global_position))
	var d1: float = f.global_position.distance_to(jog.global_position)
	_checar(f.olhada, "o jogador está olhando para ela")
	_checar(d0 - d1 > 4.0, "mesmo olhada ela anda (%.1f m -> %.1f m em 1,6 s)" % [d0, d1])
	_checar(f.estado == f.Est.CACANDO, "estado CACANDO (viu o jogador)")
	# de costas ou de frente, a mesma coisa; ela enxerga de qualquer ângulo
	jog.rotation.y = PI
	var d2: float = f.global_position.distance_to(jog.global_position)
	await _sim(0.5)
	_checar(not f.olhada and f.global_position.distance_to(jog.global_position) < d2 - 1.0, "de costas para ela, também vem")
	_desmontar_arena()
	await physics_frame


func _teste_parede() -> void:
	print("-- perseguidora: não atravessa parede")
	_montar_arena()
	_parede(arena, Vector3(0, 2, -8), Vector3(120, 4, 0.5))
	jog.global_position = Vector3(0, 0, 0)
	var f = _figura(Vector3(0, 0, -16))
	var desistiu := [false]
	f.desistiu.connect(func(): desistiu[0] = true)
	var z_max := [-99.0]
	var sumiu_em := [-1.0]
	var t := [0.0]
	await _sim(25.0, func(dt):
		t[0] += dt
		z_max[0] = maxf(z_max[0], f.global_position.z)
		if f.sumida and sumiu_em[0] < 0.0:
			sumiu_em[0] = t[0])
	_checar(z_max[0] < -8.25, "parede entre os dois: ela nunca passa (z máx %.2f, parede em -8)" % z_max[0])
	_checar(desistiu[0], "sem conseguir chegar, ela desiste (sinal desistiu)")
	_checar(f.sumida and not f.visible, "e se esconde (fora da vista: a parede está no meio)")
	_checar(not f.matou, "não matou")
	_desmontar_arena()
	await physics_frame


func _teste_perde_de_vista() -> void:
	print("-- perseguidora: perdeu de vista -> vai ao último ponto visto, procura ~4 s e desiste")
	_montar_arena()
	_parede(arena, Vector3(6, 2, 0), Vector3(0.5, 4, 80))
	jog.global_position = Vector3(0, 0, 0)
	var f = _figura(Vector3(0, 0, -12))
	var estados: Array = []
	var desistiu_t := [-1.0]
	f.desistiu.connect(func(): desistiu_t[0] = 1.0)
	await _sim(1.0)
	_checar(f.estado == f.Est.CACANDO, "vê o jogador: CACANDO")
	var visto: Vector3 = jog.global_position
	jog.global_position = Vector3(12.0, 0, 0)   # do outro lado da parede: some da vista dela
	var t := [0.0]
	var x_max := [-99.0]
	var menor := [99.0]
	var maior_passo := [0.0]
	var antes := [f.global_position]
	var t_busca := [0.0]
	var t_desiste := [-1.0]
	await _sim(40.0, func(dt):
		t[0] += dt
		x_max[0] = maxf(x_max[0], f.global_position.x)
		menor[0] = minf(menor[0], f.global_position.distance_to(visto))
		maior_passo[0] = maxf(maior_passo[0], f.global_position.distance_to(antes[0]))
		antes[0] = f.global_position
		if not estados.has(f.estado):
			estados.append(f.estado)
		if f.estado == f.Est.BUSCANDO:
			t_busca[0] += dt
		if f.estado == f.Est.EMBORA and t_desiste[0] < 0.0:
			t_desiste[0] = t[0])
	_checar(estados.has(f.Est.PROCURANDO), "passou por PROCURANDO")
	_checar(estados.has(f.Est.BUSCANDO) and t_busca[0] > 3.0 and t_busca[0] < 5.5, "procurou parada por ~4 s (%.1f s)" % t_busca[0])
	_checar(menor[0] < 1.6, "foi até o último ponto onde viu o jogador (chegou a %.1f m)" % menor[0])
	_checar(x_max[0] < 5.5, "nunca atravessou a parede (x máx %.2f, parede em 6)" % x_max[0])
	_checar(maior_passo[0] < 0.4, "nenhum teleporte: maior passo num quadro %.2f m" % maior_passo[0])
	_checar(t_desiste[0] > 0.0 and f.sumida, "desistiu (EMBORA) e se escondeu")
	_checar(not f.matou, "e não matou")
	_desmontar_arena()
	await physics_frame


func _teste_desiste_fora_da_vista() -> void:
	print("-- perseguidora: ao desistir, ela se afasta andando e só some fora da vista do jogador")
	_montar_arena()
	jog.global_position = Vector3(0, 0, 0)
	_olhar_para(Vector3(0, 0, -5))
	var f = _figura(Vector3(0, 0, -7))
	await _sim(0.2)
	f.desistir()
	var d0: float = f.global_position.distance_to(jog.global_position)
	await _sim(2.5, func(_dt): _olhar_para(f.global_position))
	_checar(f.estado == f.Est.EMBORA and not f.sumida and f.visible, "desistiu mas continua à vista, andando para longe (EMBORA)")
	_checar(f.global_position.distance_to(jog.global_position) > d0 + 2.0, "se afasta do jogador (%.1f m -> %.1f m)" % [d0, f.global_position.distance_to(jog.global_position)])
	_checar(f.olhada and not f.sumida, "enquanto o jogador olha para ela, NÃO some na frente dele")
	jog.rotation.y = PI    # vira as costas
	await _sim(0.3)
	_checar(f.sumida and not f.visible, "só some quando o jogador deixa de vê-la")
	_desmontar_arena()
	await physics_frame


## Corredor em L: o jogador corre por uma quina; ela segue o rastro dele, contorna a quina sem atravessar parede,
## perde-o quando ele passa dos 20 m, vai ao último ponto visto e desiste.
func _teste_corredor_em_ele() -> void:
	print("-- perseguidora: segue o rastro numa quina (corredor em L), não atravessa paredes, perde e desiste")
	_montar_arena()
	var paredes: Array = []   # Rect2(x, z, w, d) de cada parede, para checar que ela nunca fica dentro
	var defs := [
		[Vector3(-2.25, 2, -8.5), Vector3(0.5, 4, 24)],          # oeste do corredor 1
		[Vector3(2.25, 2, -6.25), Vector3(0.5, 4, 19.5)],        # leste do corredor 1 (z de -16 a 3,5)
		[Vector3(41.25, 2, -15.75), Vector3(77.5, 4, 0.5)],      # sul do corredor 2
		[Vector3(38.75, 2, -20.25), Vector3(82.5, 4, 0.5)],      # norte do corredor 2 e fundo do corredor 1
	]
	for d in defs:
		_parede(arena, d[0], d[1])
		paredes.append(Rect2(d[0].x - d[1].x * 0.5, d[0].z - d[1].z * 0.5, d[1].x, d[1].z))
	jog.global_position = Vector3(0, 0, -4)
	var f = _figura(Vector3(0, 0, -1), 3.7)
	var desistiu := [false]
	f.desistiu.connect(func(): desistiu[0] = true)
	var fase := [0]
	var x_max := [-99.0]
	var dentro_parede := [false]
	var maior_passo := [0.0]
	var antes := [f.global_position]
	var morreu := [false]
	f.matou_jogador.connect(func(): morreu[0] = true)
	var vel_j := 5.4
	await _sim(60.0, func(dt):
		# o jogador corre: norte até o fim do corredor 1, depois leste pelo corredor 2
		if fase[0] == 0:
			jog.global_position.z -= vel_j * dt
			if jog.global_position.z <= -18.0:
				jog.global_position.z = -18.0
				fase[0] = 1
		elif jog.global_position.x < 75.0:
			jog.global_position.x += vel_j * dt
		if not f.sumida:
			x_max[0] = maxf(x_max[0], f.global_position.x)
			maior_passo[0] = maxf(maior_passo[0], f.global_position.distance_to(antes[0]))
			antes[0] = f.global_position
			for r in paredes:
				if r.grow(-0.05).has_point(Vector2(f.global_position.x, f.global_position.z)):
					dentro_parede[0] = true)
	_checar(not dentro_parede[0], "ela nunca esteve dentro de uma parede")
	_checar(x_max[0] > 8.0, "contornou a quina e entrou no corredor 2 (x máx %.1f)" % x_max[0])
	_checar(maior_passo[0] < 0.4, "sem teleporte (maior passo %.2f m)" % maior_passo[0])
	_checar(not morreu[0], "o jogador que corre escapa")
	_checar(desistiu[0] and f.sumida, "perdeu o jogador (>20 m / sem vista), procurou e desistiu")
	_desmontar_arena()
	await physics_frame


func _teste_velocidades() -> void:
	print("-- velocidade: mais que andar (3,0), menos que correr (5,4)")
	var lento = FigCls.new()
	lento.velocidade = 2.0
	var rapido = FigCls.new()
	rapido.velocidade = 9.0
	_checar(clampf(lento.velocidade, FigCls.VEL_CACA_MIN, FigCls.VEL_CACA_MAX) > 3.0, "mesmo configurada lenta, a perseguidora anda acima de 3,0 m/s")
	_checar(clampf(rapido.velocidade, FigCls.VEL_CACA_MIN, FigCls.VEL_CACA_MAX) < 5.4, "e nunca alcança o correr (5,4)")
	lento.free()
	rapido.free()
	_montar_arena()
	jog.global_position = Vector3(0, 0, 0)
	var f = _figura(Vector3(0, 0, -30), 3.6)
	await _sim(0.2)
	var p0: Vector3 = f.global_position
	await _sim(3.0)
	var vel: float = f.global_position.distance_to(p0) / 3.0
	_checar(vel > 3.1 and vel < 4.4, "velocidade medida %.2f m/s" % vel)
	_desmontar_arena()
	await physics_frame


func _teste_debug_figura() -> void:
	print("-- debug: figura_off e imortal na perseguidora")
	_montar_arena()
	jog.global_position = Vector3(0, 0, 0)
	var f = _figura(Vector3(0, 0, -10))
	await _sim(0.3)
	DebugCls.figura_off = true
	await _sim(0.3)
	var p0: Vector3 = f.global_position
	await _sim(1.5)
	_checar(not f.visible, "figura_off: escondida")
	_checar(f.global_position.distance_to(p0) < 0.02, "figura_off: parada")
	DebugCls.figura_off = false
	await _sim(0.3)
	_checar(f.visible, "figura_off desligado: volta a aparecer")
	f.esconder()
	_desmontar_arena()
	await physics_frame

	_montar_arena()
	jog.global_position = Vector3(0, 0, 0)
	var mortes0: int = GS.contadores.get("mortes", 0)
	DebugCls.imortal = true
	var g = _figura(Vector3(0, 0, -1.5))
	await _sim(2.0)
	_checar(not g.matou and GS.contadores.get("mortes", 0) == mortes0 and jog.pode_mover, "imortal: ela encosta e não mata")
	DebugCls.imortal = false
	await _sim(1.0)
	_checar(g.matou, "sem imortal ela mata ao encostar")
	_desmontar_arena()
	await physics_frame


# ================================================================== utilitário
func _checar(cond: bool, msg: String) -> void:
	if cond:
		print("  ok: ", msg)
	else:
		print("  FALHA ", msg)
		falhas += 1
