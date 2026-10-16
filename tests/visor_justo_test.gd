extends SceneTree
## Teste (headless) do módulo 2, parte 3: Visor justo e caças mais visíveis.
##   - zonas de perigo (a atenção e a Figura do slide só agem nelas; fora delas o Q é livre)
##   - medo: vinheta vermelha (Efeitos.medo) e respiração ofegante (Audio.medo) sobem com a Figura e somem quando seguro
##   - "preso no Visor": começa, bloqueia o Q, termina sem matar nem estourar, solta o Q
##   - caça: texto "falta nas salas ..." e pista de proximidade (ping mais rápido perto, dica de época uma vez)
## Uso: godot --headless -s res://tests/visor_justo_test.gd
## O tempo do Visor é conduzido à mão (set_process(false) + _process(dt)); o Efeitos roda por conta própria e o chamamos também.

var falhas := 0
var GS
var Ef
var Au
var VisorCls
var v
var mundo: Node3D
var jog: Node3D


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GS = root.get_node("/root/GameState")
	Ef = root.get_node("/root/Efeitos")
	Au = root.get_node("/root/Audio")
	VisorCls = load("res://world/visor.gd")
	GS.novo_jogo()
	GS.jogando = false
	VisorCls.resetar_estado()
	mundo = Node3D.new()
	root.add_child(mundo)
	jog = Node3D.new()
	jog.add_to_group("player")
	mundo.add_child(jog)
	var cam := Camera3D.new()
	cam.position = Vector3(0, 1.55, 0)
	mundo.add_child(cam)
	cam.current = true
	v = VisorCls.instalar(mundo)
	v.set_process(false)

	_teste_tabela()
	await _teste_zonas()
	await _teste_medo()
	await _teste_preso()
	_teste_texto_salas()
	await _teste_proximidade()

	Input.action_release("visor")
	GS.novo_jogo()
	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


func _passo(segundos: float, dt := 0.1) -> void:
	for i in int(round(segundos / dt)):
		v._process(dt)


func _dar_rastro(metros: float) -> void:
	v._rastro.limpar()
	var x := -metros
	while x <= 0.0:
		v._rastro.seguir(Vector3(x, 0.0, 0.0))
		x += 0.5


func _q(apertado: bool) -> void:
	if apertado:
		Input.action_press("visor")
	else:
		Input.action_release("visor")
	await create_timer(0.16).timeout
	v._process(0.016)


func _zerar(visita: int, sala: int) -> void:
	Input.action_release("visor")
	GS.visita = visita
	GS.sala_atual = sala
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
	v._alerta = 0.0
	v._em_zona = false


func _teste_tabela() -> void:
	print("-- tabela das zonas de perigo")
	var Z = load("res://world/zonas_perigo.gd")
	_checar(Z.SALAS[3].size() == 2 and Z.SALAS[4].size() == 3, "visita 3 tem 2 salas e a visita 4 tem 3")
	_checar(Z.eh_perigo(3, 57) and Z.eh_perigo(3, 58) and not Z.eh_perigo(3, 56) and not Z.eh_perigo(3, 50), "visita 3: 57 e 58, só")
	_checar(Z.eh_perigo(4, 74) and Z.eh_perigo(4, 77) and Z.eh_perigo(4, 80) and not Z.eh_perigo(4, 72), "visita 4: 74, 77 e 80, só")
	_checar(Z.eh_perigo(5, 81) and Z.eh_perigo(5, 90) and Z.eh_perigo(5, 99), "porão: todas as salas (comportamento de sempre)")
	_checar(not Z.eh_perigo(1, 5) and not Z.eh_perigo(2, 30), "visitas 1 e 2: nenhuma")


func _teste_zonas() -> void:
	print("-- atenção só nas zonas de perigo")
	for par in [[3, 50], [3, 56], [4, 72], [4, 75]]:
		_zerar(par[0], par[1])
		GS.ganhar_disco(GS.Epoca.E1950)
		await _q(true)
		_dar_rastro(20.0)
		_passo(12.0)
		_checar(GS.atencao == 0.0 and not v.figura_visivel and not VisorCls.bloqueado() and v.ativo,
			"V%d sala %d (fora): Q livre, atenção %.2f, sem Figura, sem bloqueio" % [par[0], par[1], GS.atencao])
		await _q(false)
	for par in [[3, 57], [4, 77]]:
		_zerar(par[0], par[1])
		GS.ganhar_disco(GS.Epoca.E1950)
		await _q(true)
		_dar_rastro(20.0)
		_passo(5.0)
		_checar(GS.atencao > 0.3, "V%d sala %d (dentro): a atenção sobe (%.2f)" % [par[0], par[1], GS.atencao])
		_passo(4.0)
		_checar(v.figura_visivel or VisorCls.bloqueado(), "V%d sala %d (dentro): a Figura vem no slide ou estoura" % [par[0], par[1]])
		await _q(false)
		VisorCls.resetar_estado()
	# sair da zona com atenção cheia: só cai (nunca sobe)
	_zerar(4, 77)
	GS.ganhar_disco(GS.Epoca.E1950)
	await _q(true)
	_dar_rastro(20.0)
	_passo(3.0)
	var antes: float = GS.atencao
	GS.sala_atual = 78
	_passo(2.0)
	_checar(GS.atencao < antes and not v.figura_visivel, "saindo da zona com o Q ligado a atenção cai (%.2f -> %.2f) e a Figura some" % [antes, GS.atencao])
	await _q(false)
	# aviso ao entrar numa zona com o Q ligado: batimento baixinho
	_zerar(3, 56)
	GS.ganhar_disco(GS.Epoca.E1950)
	await _q(true)
	_passo(1.0)
	_checar(v._alerta <= 0.0, "fora da zona não há aviso")
	GS.sala_atual = 57
	_passo(0.2)
	_checar(v._alerta > 2.0 and GS.atencao < 0.1, "entrou na zona com o Q ligado: aviso de batimento (%.1f s), atenção ainda baixa" % v._alerta)
	await _q(false)
	# debug: atenção congelada continua valendo dentro da zona
	var D = load("res://ui/debug.gd")
	D.atencao_congelada = true
	_zerar(3, 57)
	GS.ganhar_disco(GS.Epoca.E1950)
	await _q(true)
	_passo(6.0)
	_checar(GS.atencao == 0.0, "debug: atenção congelada na zona de perigo")
	D.atencao_congelada = false
	await _q(false)


func _teste_medo() -> void:
	print("-- medo: vinheta vermelha e respiração")
	_zerar(4, 77)
	GS.definir_atencao(0.0)
	for i in 40:
		Ef._process(0.1)
	_checar(Ef.medo < 0.01 and not Au.respiracao_tocando(), "seguro: sem vinheta (%.2f) e sem respiração" % Ef.medo)
	var Medo = load("res://world/medo.gd")
	_checar(Medo.da_atencao(0.0) == 0.0 and Medo.da_atencao(0.9) > Medo.da_atencao(0.5), "o medo da atenção cresce com a atenção")
	GS.definir_atencao(0.5)
	for i in 40:
		Ef._process(0.1)
	var meio: float = Ef.medo
	var db_meio: float = Au.respiracao_db()
	GS.definir_atencao(0.95)
	for i in 40:
		Ef._process(0.1)
	_checar(meio > 0.1 and Ef.medo > meio, "a vinheta cresce com a atenção (%.2f -> %.2f)" % [meio, Ef.medo])
	_checar(Au.respiracao_tocando() and Au.respiracao_db() > db_meio, "a respiração toca e fica mais alta (%.1f -> %.1f dB)" % [db_meio, Au.respiracao_db()])
	_checar(Ef._mat.get_shader_parameter("medo") > 0.5 and Ef._rect.visible, "o shader recebe o medo e liga a camada de pós-processamento")
	GS.definir_atencao(0.0)
	for i in 60:
		Ef._process(0.1)
	_checar(Ef.medo < 0.01 and not Au.respiracao_tocando(), "a salvo outra vez: vinheta e respiração somem")
	# Figura de verdade perseguindo
	var f = load("res://creatures/figura_branca.gd").new()
	f.alvo = jog
	mundo.add_child(f)
	f.set_physics_process(false)
	f.ativa = true
	f.estado = 1
	f.global_position = Vector3(3, 0, 0)
	var perto: float = Medo.da_figura_real(self)
	f.global_position = Vector3(12, 0, 0)
	var longe: float = Medo.da_figura_real(self)
	f.global_position = Vector3(30, 0, 0)
	var fora: float = Medo.da_figura_real(self)
	_checar(perto > 0.6 and perto > longe and longe > 0.0 and fora == 0.0, "Figura real: medo perto %.2f > longe %.2f > fora %.2f" % [perto, longe, fora])
	f.global_position = Vector3(3, 0, 0)
	for i in 40:
		Ef._process(0.1)
	_checar(Ef.medo > 0.5 and Au.respiracao_tocando(), "perseguição a 3 m: vinheta (%.2f) e respiração" % Ef.medo)
	f.estado = 4
	_checar(Medo.da_figura_real(self) == 0.0, "indo embora, ela já não assusta")
	f.estado = 1
	var DD = load("res://ui/debug.gd")
	DD.figura_off = true
	_checar(Medo.da_figura_real(self) == 0.0, "debug: Figura desligada, sem medo")
	DD.figura_off = false
	f.free()
	for i in 60:
		Ef._process(0.1)
	_checar(Ef.medo < 0.01, "sem Figura o medo volta a zero")


func _teste_preso() -> void:
	print("-- Preso no Visor")
	_zerar(4, 72)
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.ganhar_disco(GS.Epoca.E2019)
	GS.selecionar_disco(GS.Epoca.E2019)
	GS.set_flag("tem_visor")
	var Z = load("res://world/zonas_perigo.gd")
	_checar(not Z.ativa(), "sala 72 (Povos) está fora das zonas de perigo")
	var terminou := []
	v.preso_terminou.connect(func(): terminou.append(true))
	var sustos0: int = GS.contadores.get("sustos", 0)
	_dar_rastro(25.0)
	_checar(v.preso_iniciar(6.0) and VisorCls.preso(), "começou: preso por 6 s")
	await _q(true)
	_checar(v.ativo and Input.is_action_pressed("visor") and Z.ativa(), "o Visor ligou sozinho e a sala conta como zona de perigo")
	v.alternar()
	_passo(0.2)
	_checar(Input.is_action_pressed("visor") and v.ativo and VisorCls.preso(), "tocar no Q durante o aperto não desliga")
	var maxima := 0.0
	var viu_figura := false
	var t := 0.0
	while VisorCls.preso() and t < 8.0:
		_passo(0.1)
		t += 0.1
		maxima = maxf(maxima, GS.atencao)
		viu_figura = viu_figura or v.figura_visivel
		if VisorCls.preso():
			_checar_silencioso(v.ativo and Input.is_action_pressed("visor"), "ligado durante o aperto")
	_checar(not VisorCls.preso() and absf(t - 5.8) < 0.5, "terminou depois de ~6 s (%.1f s)" % t)
	_checar(maxima > 0.8 and maxima < 1.0, "a atenção chega perto do máximo mas não estoura (%.2f)" % maxima)
	_checar(viu_figura, "a Figura apareceu no slide durante o aperto")
	_checar(not VisorCls.bloqueado() and terminou == [true], "sem bloqueio e o sinal preso_terminou saiu")
	_checar(GS.contadores.get("sustos", 0) == sustos0 + 1 and GS.atencao == 0.0, "um susto rente e a atenção volta a zero")
	await create_timer(0.16).timeout
	v._process(0.016)
	_checar(not Input.is_action_pressed("visor") and not v.ativo, "o Visor é solto (Q desliga)")
	v.alternar()
	await create_timer(0.16).timeout
	v._process(0.016)
	_checar(Input.is_action_pressed("visor") and v.ativo, "depois disso o Q volta a ligar normalmente")
	await _q(false)
	# sem disco não prende
	_zerar(4, 72)
	_checar(not v.preso_iniciar(5.0) and not VisorCls.preso(), "sem disco não há como prender")
	# reiniciar o nível nunca deixa preso
	GS.ganhar_disco(GS.Epoca.E2019)
	v.preso_iniciar(5.0)
	VisorCls.resetar_estado()
	_checar(not VisorCls.preso(), "resetar_estado solta o aperto")
	await _q(false)


func _teste_texto_salas() -> void:
	print("-- caça: onde ainda falta")
	var O = load("res://world/objetivo.gd")
	_checar(O.texto_salas([26, 30]) == "salas 26 e 30", "duas salas: '%s'" % O.texto_salas([26, 30]))
	_checar(O.texto_salas([26]) == "sala 26" and O.texto_salas([]) == "", "uma sala / nenhuma")
	_checar(O.texto_salas([26, 30, 31]) == "salas 26, 30 e 31", "três salas: '%s'" % O.texto_salas([26, 30, 31]))
	_zerar(3, 50)
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.ganhar_disco(GS.Epoca.E1967)
	var Hud = load("res://ui/hud.gd")
	O.salas_caca = Callable()
	_checar(Hud.objetivo_caca().begins_with("Marcas 0/3: ligue o Q"), "sem o nível, o texto de sempre ('%s')" % Hud.objetivo_caca())
	O.salas_caca = func(_d: int) -> Array: return [26, 30]
	var t: String = Hud.objetivo_caca()
	_checar(t.begins_with("Marcas 0/3: falta nas salas 26 e 30."), "objetivo: '%s'" % t)
	_checar(O.atual() != "", "o mapa (Objetivo.atual) tem texto")
	O.salas_caca = Callable()


func _teste_proximidade() -> void:
	print("-- caça: pista de proximidade")
	_zerar(3, 50)
	GS.ganhar_disco(GS.Epoca.E1950)
	GS.ganhar_disco(GS.Epoca.E1967)
	GS.set_flag("tem_visor")
	var Prox = load("res://world/caca_proximidade.gd")
	Prox.resetar()
	var item := Node3D.new()
	item.position = Vector3(6, 0, 0)
	mundo.add_child(item)
	load("res://world/feixe_caca.gd").registrar(item, GS.Epoca.E1975 if GS.CACAS.has(GS.Epoca.E1975) else 1, "balde")
	var c = Prox.instalar(mundo)
	c.set_process(false)
	_checar(Prox.intervalo(1.0) < Prox.intervalo(5.0) and Prox.intervalo(5.0) < Prox.intervalo(9.0), "o ping fica mais rápido quanto mais perto (%.2f < %.2f < %.2f)" % [Prox.intervalo(1.0), Prox.intervalo(5.0), Prox.intervalo(9.0)])
	_checar(GS.caca_ativa() == GS.Epoca.E1975, "a caça ativa é a de 1975 (Marcas)")
	c._olhar()
	_checar(absf(c._dist - 6.0) < 0.01 and c.ultimo_alvo == "%d:balde" % GS.Epoca.E1975, "a 6 m, item visível: é o alvo do ping (%s)" % c.ultimo_alvo)
	var p0: int = c.pings
	c._prox_ping = 0.0
	c._varrer = 99.0
	c._process(0.01)
	_checar(c.pings == p0 + 1, "o ping toca")
	jog.position = Vector3(20, 0, 0)
	c._olhar()
	_checar(c._dist == INF and c.ultimo_alvo == "", "a 14 m: nada de ping")
	jog.position = Vector3.ZERO
	# item em outra época (invisível): dica uma vez
	item.visible = false
	c._olhar()
	_checar(c.ultima_dica == "Algo brilha em outra época: ligue o Q.", "outra época: dica '%s'" % c.ultima_dica)
	c.ultima_dica = ""
	c._olhar()
	_checar(c.ultima_dica == "", "a dica sai uma vez só por item")
	_checar(c._dist == INF, "item de outra época não pinga")
	Prox.resetar()
	Input.action_press("visor")
	GS.selecionar_disco(GS.Epoca.E1950)
	_checar(Prox.texto_dica(GS.Epoca.E1975).contains("aperte 2 para trocar"), "Q ligado no disco errado: '%s'" % Prox.texto_dica(GS.Epoca.E1975))
	Input.action_release("visor")
	# achado não conta mais
	item.visible = true
	GS.caca_concluir(GS.Epoca.E1975)
	c._olhar()
	_checar(c._dist == INF, "caça completa: sem ping")
	item.free()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _checar_silencioso(cond: bool, msg: String) -> void:
	if not cond:
		print("  FALHA " + msg)
		falhas += 1
