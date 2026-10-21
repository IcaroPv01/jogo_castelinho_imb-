extends MiniGameBase
## Minigame "Quico Diz" (Módulo 16): o respiro leve e engraçado entre trechos pesados.
## O Quico (quero-quero, o "fiscal da visita": a ave que apita alto para avisar de intrusos) apita um ritmo e o jogador
## repete apertando a ação (E, clique ou botão Interagir) no mesmo ritmo.
##   - 4 rodadas, com 3, 4, 5 e 6 batidas. Cada batida é CURTA ("piu") ou LONGA ("PIIIU"): a longa deixa um intervalo maior
##     antes da próxima. O jogador só aperta; o que conta são os INTERVALOS entre os apertos (tolerância de 35%).
##   - Errou: o Quico dá uma bronca engraçada e repete a rodada. No 3º erro seguido ele facilita sozinho (a rodada passa):
##     o jogo nunca trava.
##   - Sem áudio também funciona: toda batida tem sinal visual forte (o bico abre, um anel cresce, um halo muda de cor, o balão
##     "PIU!" aparece e a fileira de notas no alto acende; notas curtas são quadradinhos, longas são barras).
##   - VIRADA (só no fim, leve e estranha): depois da 4ª rodada o Quico apita um padrão que o jogador NÃO repete e, do outro
##     lado do muro, alguém responde com o MESMO ritmo, mais agudo, duas vezes. O Quico olha para lá, silêncio, e diz
##     "Não fui eu.". Sem monstro, sem susto: é só sugestão do Tito (fictício).
## Públicos para os testes: `padrao_atual()` (intervalos em s), `tipos_atual()`, `ouvindo`, `rodada`, `erros_seguidos`,
## `facilitadas`, `respostas_de_fora`, `julgar()`. O relógio do jogo é `_relogio` (acumula o delta: respeita Engine.time_scale).

const RODADAS: Array = [      # 0 = batida curta, 1 = batida longa
	[0, 1, 1],
	[0, 0, 1, 0],
	[1, 0, 0, 1, 0],
	[0, 0, 1, 0, 0, 1],
]
const FINAL: Array = [0, 0, 1]            # o padrão da virada: o jogador não repete
const GAP_CURTA := 0.5                    # s entre o início de uma batida curta e o da próxima
const GAP_LONGA := 1.0
const TOLERANCIA := 0.35
const LIMITE_GAP := 2.6                   # s sem apertar no meio do padrão = rodada perdida
const LIMITE_INICIO := 9.0                # s sem apertar nada depois da vez dele = rodada perdida
const ERROS_PARA_FACILITAR := 3

const POS_QUICO := Vector3(0, 0.3, -4.8)
const POS_RESPOSTA := Vector3(7.6, 2.3, -8.5)   # de onde vem a resposta: atrás do muro, fora de campo
const ESCALA_QUICO := 1.4
const YAW_QUICO := 28.0                       # de 3/4, o bico para a direita: o bico aberto lê melhor

const COR_DEMO := Color(1.0, 0.82, 0.2)
const COR_TOQUE := Color(0.3, 0.9, 0.45)
const COR_ERRO := Color(0.95, 0.3, 0.25)
const COR_APAGADA := Color(0.14, 0.17, 0.26, 0.75)

const BRONCAS: Array = [
	["PIII! Foi... criativo. De novo!"],
	["Eu sou fiscal, não maestro! Mas isso aí foi jazz. De novo!"],
]
const ELOGIOS: Array = [
	["PIII! Nada mal para um humano!"],
	["Quase uma banda! Só falta o triângulo."],
	["Tá me assustando de tão bom! Digo... PIII!"],
	["Mandou bem! Agora a última.", "Essa é só pra eu apitar. Você só escuta, tá?"],
]

## (teste/ajuste) começar direto numa rodada: 1 a 4; 5 = pular direto para a virada.
@export var rodada_inicial := 1

var rodada := 0
var erros_seguidos := 0
var erros_total := 0
var facilitadas := 0
var ouvindo := false
var respostas_de_fora := 0
var virada_ativa := false

var _relogio := 0.0
var _toques: Array[float] = []
var _tipos: Array = []

var _ave: Node3D
var _corpo: Node3D
var _cabeca: Node3D
var _bico_sup: Node3D
var _bico_inf: Node3D
var _halo: MeshInstance3D
var _mat_halo: StandardMaterial3D
var _tw_sup: Tween
var _tw_inf: Tween
var _tw_ave: Tween
var _tw_halo: Tween
var _mesh_pena: BoxMesh
var _mat_pena: StandardMaterial3D
var _notas: HBoxContainer
var _notas_sb: Array[StyleBoxFlat] = []


func _init() -> void:
	super()
	id = "quico"
	quem_fala = "quico"
	fala_fim = ["Toma o selo de Fiscal Auxiliar! PIII!", "...e se piarem do outro lado do muro, não responde. Combinado?"]
	corrupcao = 0.08


func ponto_jogador() -> Vector3:
	return Vector3(0, 0.1, 0)


func alvo_olhar() -> Vector3:
	return Vector3(0, 1.8, -5.0)


# ============================================================================ acessores públicos (testes)
## Intervalos (s) entre os apertos esperados no padrão atual: N-1 números para N batidas.
func padrao_atual() -> Array:
	return intervalos_de(_tipos)


func tipos_atual() -> Array:
	return _tipos.duplicate()


static func intervalos_de(tipos: Array) -> Array:
	var r: Array = []
	for i in range(tipos.size() - 1):
		r.append(GAP_LONGA if int(tipos[i]) == 1 else GAP_CURTA)
	return r


## Os intervalos medidos (entre apertos seguidos) batem com o padrão? Cada um pode errar até `tol` (fração) do esperado.
static func julgar(toques: Array, intervalos: Array, tol := TOLERANCIA) -> bool:
	if toques.size() != intervalos.size() + 1:
		return false
	for i in intervalos.size():
		var gap: float = float(toques[i + 1]) - float(toques[i])
		var esperado: float = float(intervalos[i])
		if absf(gap - esperado) > esperado * tol:
			return false
	return true


# ============================================================================ o aperto do jogador
func acionar() -> void:
	if not ouvindo or not acao_vale():
		return
	if _toques.size() >= _tipos.size():
		return
	_toques.append(_relogio)
	_acender(_toques.size() - 1, COR_TOQUE)
	_toque_visual()


func _process(dt: float) -> void:
	super(dt)
	_relogio += dt
	if _corpo:
		_corpo.position.y = sin(_relogio * 2.3) * 0.025
		_corpo.rotation_degrees.z = sin(_relogio * 1.4) * 1.2


# ============================================================================ cenário
func _montar() -> void:
	ambiente(Color(0.36, 0.64, 1.0), Color(0.84, 0.93, 1.0), Color(0.86, 0.93, 0.97), 0.006, 1.05)
	_mesh_pena = BoxMesh.new()
	_mesh_pena.size = Vector3(0.1, 0.02, 0.26)
	_mat_pena = Ato2Pecas.mat_cor(Color(0.98, 0.98, 0.95))
	_chao_e_castelinho()
	_muro_e_arvores()
	_placa_titulo()
	_criar_quico()
	_criar_halo()
	_criar_notas()
	placar("Rodada 1/%d" % RODADAS.size())
	dica("", "")
	Audio.ambiente("vento", -22.0, 1.0)


func _chao_e_castelinho() -> void:
	var grama := Construtor.material(Color(0.9, 1.0, 0.85), 0.95, load("res://assets/textures/grama.png") as Texture2D, Vector3(0.45, 0.45, 0.45))
	Construtor.caixa(self, Vector3(80, 0.5, 70), Vector3(0, -0.25, -24), grama, true, "Gramado")
	var calcada := Construtor.material(Color(0.95, 0.93, 0.88), 0.95, load("res://assets/textures/calcada_lajotas.png") as Texture2D, Vector3(0.5, 0.5, 0.5))
	Construtor.caixa(self, Vector3(40, 0.04, 2.6), Vector3(0, 0.02, -15.6), calcada, false, "Calcada")
	# o Castelinho ao fundo: só formas simples (corpo, torre, arco da porta, janelas e ameias)
	var tijolo := Construtor.material(Color(1.0, 0.95, 0.92), 0.95, load("res://assets/textures/parede_castelinho.png") as Texture2D, Vector3(0.35, 0.35, 0.35))
	var escuro := Ato2Pecas.mat_cor(Color(0.1, 0.12, 0.17))
	var verde_vidro := Ato2Pecas.mat_cor(Color(0.45, 0.55, 0.45))
	var castelo := Node3D.new()
	castelo.name = "CastelinhoAoFundo"
	add_child(castelo)
	Construtor.caixa(castelo, Vector3(18, 5.0, 4.0), Vector3(2, 2.5, -20), tijolo, false, "Corpo")
	Construtor.caixa(castelo, Vector3(4.6, 9.0, 4.6), Vector3(-8.0, 4.5, -20.6), tijolo, false, "Torre")
	var tel := CylinderMesh.new()
	tel.top_radius = 0.0
	tel.bottom_radius = 1.7
	tel.height = 2.4
	tel.radial_segments = 4
	tel.rings = 1
	Ato2Pecas.malha(castelo, tel, Vector3(-6.4, 10.2, -18.8), Ato2Pecas.mat_cor(Color(0.5, 0.22, 0.18)), Vector3(0, 45, 0))
	Construtor.caixa(castelo, Vector3(1.6, 2.5, 0.1), Vector3(1.0, 1.25, -17.97), escuro, false, "Porta")
	var arco := CylinderMesh.new()
	arco.top_radius = 0.8
	arco.bottom_radius = 0.8
	arco.height = 0.1
	arco.radial_segments = 14
	Ato2Pecas.malha(castelo, arco, Vector3(1.0, 2.5, -17.97), escuro, Vector3(90, 0, 0))
	for x in [-3.0, -1.2, 3.4, 5.4]:
		Construtor.caixa(castelo, Vector3(0.8, 1.3, 0.1), Vector3(x, 2.5, -17.97), escuro, false)
	for y in [5.4, 7.6]:
		Construtor.caixa(castelo, Vector3(0.5, 1.5, 0.1), Vector3(-8.0, y, -18.27), verde_vidro, false)
	# ameias (um MultiMesh só)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var bloco := BoxMesh.new()
	bloco.size = Vector3(0.45, 0.55, 0.45)
	mm.mesh = bloco
	var pos: Array[Vector3] = []
	var x := -4.0
	while x < 11.0:
		pos.append(Vector3(x, 5.27, -18.1))
		x += 0.9
	x = -10.2
	while x < -5.8:
		pos.append(Vector3(x, 9.27, -18.4))
		pos.append(Vector3(x, 9.27, -22.8))
		x += 0.9
	mm.instance_count = pos.size()
	for i in pos.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos[i]))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = tijolo
	mmi.name = "Ameias"
	castelo.add_child(mmi)


func _muro_e_arvores() -> void:
	var reboco := Ato2Pecas.mat_cor(Color(0.86, 0.83, 0.77))
	# o muro à direita: do outro lado dele alguém vai responder
	Construtor.caixa(self, Vector3(10.0, 1.5, 0.35), Vector3(9.0, 0.75, -6.5), reboco, true, "Muro")
	Construtor.caixa(self, Vector3(10.3, 0.12, 0.55), Vector3(9.0, 1.56, -6.5), Ato2Pecas.mat_cor(Color(0.7, 0.67, 0.62)), false)
	var tronco := CylinderMesh.new()
	tronco.top_radius = 0.18
	tronco.bottom_radius = 0.26
	tronco.height = 3.0
	var copa := CylinderMesh.new()
	copa.top_radius = 0.0
	copa.bottom_radius = 1.6
	copa.height = 3.4
	copa.radial_segments = 8
	copa.rings = 1
	var madeira := Ato2Pecas.mat_cor(Color(0.35, 0.24, 0.16))
	var folha := Ato2Pecas.mat_cor(Color(0.16, 0.38, 0.22))
	for p in [Vector3(-8.6, 0, -8.0), Vector3(13.5, 0, -11.5)]:
		Ato2Pecas.malha(self, tronco, p + Vector3(0, 1.5, 0), madeira)
		Ato2Pecas.malha(self, copa, p + Vector3(0, 4.2, 0), folha)
	# hortênsias (um MultiMesh): o gramado do Castelinho
	var esfera := SphereMesh.new()
	esfera.radius = 0.4
	esfera.height = 0.7
	esfera.radial_segments = 8
	esfera.rings = 4
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = esfera
	mm.instance_count = 9
	for i in 9:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(1.0 + (i % 3) * 0.2, 1.0, 1.0)), Vector3(-6.0 + i * 1.7, 0.3, -17.0)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ato2Pecas.mat_cor(Color(0.55, 0.6, 0.95))
	mmi.name = "Hortensias"
	add_child(mmi)


## A plaquinha "QUICO DIZ" à esquerda do palco.
func _placa_titulo() -> void:
	var madeira := Ato2Pecas.mat_cor(Color(0.5, 0.34, 0.2))
	var placa := Node3D.new()
	placa.name = "PlacaQuicoDiz"
	placa.position = Vector3(-3.5, 0, -3.3)
	placa.rotation_degrees.y = 14.0
	add_child(placa)
	Construtor.caixa(placa, Vector3(0.12, 1.7, 0.12), Vector3(-0.9, 0.85, 0), madeira, false)
	Construtor.caixa(placa, Vector3(0.12, 1.7, 0.12), Vector3(0.9, 0.85, 0), madeira, false)
	Construtor.caixa(placa, Vector3(2.3, 0.85, 0.1), Vector3(0, 1.5, 0), Ato2Pecas.mat_cor(Color(0.98, 0.86, 0.35)), false)
	var t := Construtor.rotulo(placa, "QUICO DIZ", Vector3(0, 1.57, 0.06), 72, Color(0.35, 0.1, 0.05))
	t.pixel_size = 0.0085
	var t2 := Construtor.rotulo(placa, "fiscal da visita", Vector3(0, 1.27, 0.06), 44, Color(0.45, 0.2, 0.1))
	t2.pixel_size = 0.0075


# ============================================================================ o Quico (aves de caixas e esferas)
func _esfera(pai: Node3D, raio: float, pos: Vector3, mat: Material, esc := Vector3.ONE) -> MeshInstance3D:
	var m := SphereMesh.new()
	m.radius = raio
	m.height = raio * 2.0
	m.radial_segments = 14
	m.rings = 7
	return Ato2Pecas.malha(pai, m, pos, mat, Vector3.ZERO, esc)


func _caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := BoxMesh.new()
	m.size = tam
	return Ato2Pecas.malha(pai, m, pos, mat, rot)


func _criar_quico() -> void:
	var branco := Ato2Pecas.mat_cor(Color(0.97, 0.97, 0.94))
	var preto := Ato2Pecas.mat_cor(Color(0.07, 0.07, 0.09))
	var cinza := Ato2Pecas.mat_cor(Color(0.45, 0.47, 0.5))
	var pardo := Ato2Pecas.mat_cor(Color(0.62, 0.53, 0.43))
	var laranja := Ato2Pecas.mat_cor(Color(0.98, 0.62, 0.15))
	var laranja_esc := Ato2Pecas.mat_cor(Color(0.85, 0.48, 0.1))
	var vermelho := Ato2Pecas.mat_cor(Color(0.88, 0.2, 0.2))
	var amarelo := Ato2Pecas.mat_cor(Color(1.0, 0.86, 0.2), false, 0.35)
	# pedestal de pedra
	var ped := CylinderMesh.new()
	ped.top_radius = 1.05
	ped.bottom_radius = 1.2
	ped.height = 0.3
	ped.radial_segments = 20
	ped.rings = 1
	Ato2Pecas.malha(self, ped, Vector3(0, 0.15, POS_QUICO.z), Ato2Pecas.mat_cor(Color(0.66, 0.64, 0.6))).name = "Pedestal"
	_ave = Node3D.new()
	_ave.name = "Quico"
	_ave.position = POS_QUICO
	_ave.scale = Vector3.ONE * ESCALA_QUICO
	_ave.rotation_degrees.y = YAW_QUICO
	add_child(_ave)
	for lado in [-1.0, 1.0]:
		_caixa(_ave, Vector3(0.07, 0.62, 0.07), Vector3(lado * 0.16, 0.31, 0.0), vermelho)
		_caixa(_ave, Vector3(0.2, 0.04, 0.3), Vector3(lado * 0.16, 0.02, 0.07), vermelho)
	_corpo = Node3D.new()
	_corpo.name = "Corpo"
	_ave.add_child(_corpo)
	_esfera(_corpo, 0.55, Vector3(0, 1.0, -0.05), branco, Vector3(1.0, 1.1, 1.0))
	for lado in [-1.0, 1.0]:
		var asa := _esfera(_corpo, 0.4, Vector3(lado * 0.46, 1.0, -0.12), pardo, Vector3(0.28, 1.0, 0.8))
		asa.rotation_degrees.z = lado * 8.0
	_esfera(_corpo, 0.3, Vector3(0, 1.4, 0.3), preto, Vector3(1.0, 0.8, 0.55))          # babador
	_cabeca = Node3D.new()
	_cabeca.name = "Cabeca"
	_cabeca.position = Vector3(0, 1.62, 0.12)
	_corpo.add_child(_cabeca)
	_esfera(_cabeca, 0.3, Vector3(0, 0.1, 0), branco)
	_esfera(_cabeca, 0.27, Vector3(0, 0.3, -0.02), cinza, Vector3(1.0, 0.4, 1.0))        # coroa cinza
	_caixa(_cabeca, Vector3(0.04, 0.42, 0.04), Vector3(0, 0.5, -0.2), preto, Vector3(-38, 0, 0))   # topete
	_caixa(_cabeca, Vector3(0.04, 0.3, 0.04), Vector3(0, 0.42, -0.27), preto, Vector3(-62, 0, 0))
	for lado in [-1.0, 1.0]:
		_esfera(_cabeca, 0.08, Vector3(lado * 0.19, 0.15, 0.19), vermelho)
		_esfera(_cabeca, 0.038, Vector3(lado * 0.21, 0.15, 0.26), preto)
	_bico_sup = Node3D.new()
	_bico_sup.name = "BicoSup"
	_bico_sup.position = Vector3(0, 0.07, 0.27)
	_cabeca.add_child(_bico_sup)
	_caixa(_bico_sup, Vector3(0.13, 0.05, 0.34), Vector3(0, 0, 0.17), laranja)
	var apito := _caixa(_bico_sup, Vector3(0.11, 0.08, 0.12), Vector3(0, 0.065, 0.2), amarelo)   # o apito do fiscal
	apito.name = "Apito"
	_bico_inf = Node3D.new()
	_bico_inf.name = "BicoInf"
	_bico_inf.position = Vector3(0, 0.03, 0.27)
	_cabeca.add_child(_bico_inf)
	_caixa(_bico_inf, Vector3(0.1, 0.04, 0.27), Vector3(0, -0.02, 0.135), laranja_esc)


func _criar_halo() -> void:
	var disco := CylinderMesh.new()
	disco.top_radius = 2.6
	disco.bottom_radius = 2.6
	disco.height = 0.02
	disco.radial_segments = 28
	disco.rings = 1
	_mat_halo = Ato2Pecas.mat_cor(Color(1, 1, 1, 0.0), true)
	_halo = Ato2Pecas.malha(self, disco, Vector3(0, 2.2, POS_QUICO.z - 1.6), _mat_halo, Vector3(90, 0, 0))
	_halo.name = "Halo"


# ============================================================================ a fileira de notas (HUD)
func _criar_notas() -> void:
	_notas = HBoxContainer.new()
	_notas.name = "Notas"
	_notas.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_notas.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_notas.offset_top = 22.0
	_notas.add_theme_constant_override("separation", 14)
	_notas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_camada.add_child(_notas)


func _montar_notas(tipos: Array) -> void:
	for c in _notas.get_children():
		c.queue_free()
		_notas.remove_child(c)
	_notas_sb.clear()
	for t in tipos:
		var p := Panel.new()
		p.custom_minimum_size = Vector2(92.0 if int(t) == 1 else 44.0, 44.0)
		p.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sb := StyleBoxFlat.new()
		sb.bg_color = COR_APAGADA
		sb.set_corner_radius_all(22)
		sb.set_border_width_all(3)
		sb.border_color = Color(1, 1, 1, 0.85)
		p.add_theme_stylebox_override("panel", sb)
		_notas.add_child(p)
		_notas_sb.append(sb)


func _acender(i: int, cor: Color) -> void:
	if i < 0 or i >= _notas_sb.size():
		return
	create_tween().tween_property(_notas_sb[i], "bg_color", cor, 0.06)


func _apagar_notas() -> void:
	for sb in _notas_sb:
		sb.bg_color = COR_APAGADA


func _pintar_notas(cor: Color) -> void:
	for sb in _notas_sb:
		create_tween().tween_property(sb, "bg_color", cor, 0.12)


# ============================================================================ efeitos de cada batida (todos visuais)
func _bico_pos() -> Vector3:
	return _bico_sup.global_transform * Vector3(0, 0.1, 0.5)     # a ponta do bico (acompanha o giro do Quico)


func _abrir_bico(dur: float) -> void:
	for par in [[_bico_sup, -30.0, 0], [_bico_inf, 24.0, 1]]:
		var no: Node3D = par[0]
		var tw: Tween = _tw_sup if int(par[2]) == 0 else _tw_inf
		if tw and tw.is_valid():
			tw.kill()
		tw = create_tween()
		tw.tween_property(no, "rotation_degrees:x", float(par[1]), 0.05)
		tw.tween_interval(maxf(dur - 0.13, 0.0))
		tw.tween_property(no, "rotation_degrees:x", 0.0, 0.08)
		if int(par[2]) == 0:
			_tw_sup = tw
		else:
			_tw_inf = tw


func _anel(pos: Vector3, cor: Color, raio_fim: float, dur: float) -> void:
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 24
	tor.ring_segments = 6
	var mat := Ato2Pecas.mat_cor(cor, true)
	mat.no_depth_test = true
	var mi := MeshInstance3D.new()
	mi.mesh = tor
	mi.material_override = mat
	mi.rotation_degrees = Vector3(90, 0, 0)
	mi.position = pos
	mi.scale = Vector3.ONE * 0.2
	add_child(mi)
	var t := create_tween().set_parallel()
	t.tween_property(mi, "scale", Vector3.ONE * raio_fim, dur).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(mat, "albedo_color:a", 0.0, dur)
	t.chain().tween_callback(mi.queue_free)


func _flash_halo(cor: Color, alfa: float, dur: float) -> void:
	if _tw_halo and _tw_halo.is_valid():
		_tw_halo.kill()
	_mat_halo.albedo_color = Color(cor.r, cor.g, cor.b, alfa)
	_tw_halo = create_tween()
	_tw_halo.tween_property(_mat_halo, "albedo_color:a", 0.0, dur)


func _balao(texto: String, cor: Color, pos: Vector3, tam := 1.0) -> void:
	var l := Label3D.new()
	l.text = texto
	l.font_size = 96
	l.pixel_size = 0.011 * tam
	l.modulate = cor
	l.outline_size = 24
	l.outline_modulate = Color(0.18, 0.06, 0.0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos
	l.scale = Vector3.ONE * 0.4
	add_child(l)
	var t := create_tween().set_parallel()
	t.tween_property(l, "scale", Vector3.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(l, "position:y", pos.y + 0.6, 0.9)
	t.chain().tween_property(l, "modulate:a", 0.0, 0.3)
	t.chain().tween_callback(l.queue_free)


func _penas(qtd: int, forca := 1.0) -> void:
	var centro := _ave.global_position + Vector3(0, 2.0, 0.3)
	for i in qtd:
		var p := MeshInstance3D.new()
		p.mesh = _mesh_pena
		p.material_override = _mat_pena
		p.position = centro + Vector3(randf_range(-0.5, 0.5), randf_range(-0.2, 0.4), randf_range(-0.2, 0.4))
		p.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)
		add_child(p)
		var alvo := p.position + Vector3(randf_range(-1.2, 1.2) * forca, -1.7 - randf() * 0.5, randf_range(0.0, 1.0))
		var t := create_tween().set_parallel()
		t.tween_property(p, "position:x", alvo.x, 1.1).set_trans(Tween.TRANS_SINE)
		t.tween_property(p, "position:z", alvo.z, 1.1)
		t.tween_property(p, "position:y", alvo.y, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		t.tween_property(p, "rotation:z", p.rotation.z + randf_range(-4.0, 4.0), 1.1)
		t.chain().tween_callback(p.queue_free)


func _pop_ave(fator: float, dur: float) -> void:
	if _tw_ave and _tw_ave.is_valid():
		_tw_ave.kill()
		_ave.scale = Vector3.ONE * ESCALA_QUICO
	_tw_ave = create_tween()
	_tw_ave.tween_property(_ave, "scale", Vector3.ONE * ESCALA_QUICO * fator, dur * 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	_tw_ave.tween_property(_ave, "scale", Vector3.ONE * ESCALA_QUICO, dur * 0.65)


## Uma batida do Quico: bico abre, anel, halo, balão, pop e som (longa = grave, grande e laranja; curta = aguda e amarela).
func _batida_quico(longa: bool) -> void:
	var cor: Color = Color(1.0, 0.5, 0.12, 0.95) if longa else COR_DEMO
	_abrir_bico(0.5 if longa else 0.17)
	_anel(_bico_pos(), cor, 2.6 if longa else 1.7, 0.85 if longa else 0.5)
	if longa:
		get_tree().create_timer(0.14).timeout.connect(func() -> void:
			if is_inside_tree():
				_anel(_bico_pos(), cor, 1.9, 0.7))
		_penas(4, 0.6)
	_flash_halo(cor, 0.5 if longa else 0.4, 0.6 if longa else 0.32)
	_pop_ave(1.14 if longa else 1.07, 0.3 if longa else 0.18)
	_balao("PIIIIU!" if longa else "PIU!", Color(1.0, 0.9, 0.3), _bico_pos() + Vector3(0.7, 0.8, 0), 1.25 if longa else 0.9)
	Audio.sfx("apito", -1.0 if longa else -3.0, randf_range(0.82, 0.9) if longa else randf_range(1.18, 1.3))


## O aperto do jogador: anel ciano na frente do pedestal, halo verde e um pio curtinho (confirma que o toque contou).
func _toque_visual() -> void:
	_anel(Vector3(0, 0.9, POS_QUICO.z + 1.2), Color(0.35, 1.0, 0.6, 0.9), 1.9, 0.4)
	_flash_halo(COR_TOQUE, 0.28, 0.25)
	_pop_ave(1.03, 0.14)
	Audio.sfx("apito", -9.0, randf_range(1.5, 1.6))


func _balancar_cabeca() -> void:
	var t := create_tween()
	for ang in [18.0, -18.0, 12.0, -12.0, 0.0]:
		t.tween_property(_cabeca, "rotation_degrees:z", ang, 0.08)


func _pular_alegre() -> void:
	var t := create_tween()
	t.tween_property(_ave, "position:y", POS_QUICO.y + 0.5, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(_ave, "position:y", POS_QUICO.y, 0.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)


func _reagir_erro() -> void:
	_balancar_cabeca()
	_penas(8)
	_pintar_notas(COR_ERRO)
	_flash_halo(COR_ERRO, 0.35, 0.5)
	_balao("PIII?!", Color(1.0, 0.45, 0.35), _bico_pos() + Vector3(0.7, 0.7, 0), 1.0)
	Audio.sfx("erro", 0.0, 1.0)


func _reagir_acerto() -> void:
	_pular_alegre()
	_penas(10, 1.4)
	_pintar_notas(COR_TOQUE)
	_flash_halo(COR_TOQUE, 0.45, 0.6)
	_balao("PIII!!", Color(0.6, 1.0, 0.6), _bico_pos() + Vector3(0.7, 0.7, 0), 1.2)
	Audio.sfx("acerto", 0.0, 1.0)


# ============================================================================ o jogo
func _rodar() -> bool:
	if not await falar("quico", [
			"PIII! Eu sou o Quico, fiscal oficial do gramado!",
			"Brincadeira rápida: eu apito um ritmo e você repete apertando o botão no mesmo ritmo.",
			"Não precisa ser perfeito. Eu sou fiscal, não maestro!"]):
		return false
	for r in range(rodada_inicial - 1, RODADAS.size()):
		rodada = r + 1
		placar("Rodada %d/%d" % [rodada, RODADAS.size()])
		erros_seguidos = 0
		var passou := false
		while not passou:
			var res: int = await _tentar(r)
			if res < 0:
				return false
			if res == 1:
				passou = true
				continue
			erros_seguidos += 1
			erros_total += 1
			_reagir_erro()
			if erros_seguidos >= ERROS_PARA_FACILITAR:
				facilitadas += 1
				if not await falar("quico", ["Tá, tá, tá! Passou! Hoje o fiscal tá bonzinho. PIII!"]):
					return false
				_reagir_acerto()
				passou = true
			else:
				if not await falar("quico", BRONCAS[mini(erros_seguidos - 1, BRONCAS.size() - 1)]):
					return false
		if erros_seguidos == 0:
			_reagir_acerto()
		if not await falar("quico", ELOGIOS[r]):
			return false
	return await _virada()


## Uma tentativa da rodada `r`: o Quico apita, o jogador repete. 1 = acertou, 0 = errou, -1 = pulou.
func _tentar(r: int) -> int:
	_tipos = RODADAS[r]
	_montar_notas(_tipos)
	_toques.clear()
	ouvindo = false
	dica("Escute o Quico...", "Escute o Quico...")
	if not await esperar(0.8):
		return -1
	for i in _tipos.size():
		var longa: bool = int(_tipos[i]) == 1
		_acender(i, COR_DEMO)
		_batida_quico(longa)
		if not await esperar(GAP_LONGA if longa else GAP_CURTA):
			return -1
	dica("Sua vez! Aperte [E] ou clique no mesmo ritmo", "Sua vez! Toque em Interagir no mesmo ritmo")
	_apagar_notas()
	Audio.sfx("clique", 0.0, 1.4)
	_toques.clear()
	ouvindo = true
	var t0 := _relogio
	while true:
		if not await esperar(0.02):
			ouvindo = false
			return -1
		if _toques.size() >= _tipos.size():
			break
		var ref: float = t0 if _toques.is_empty() else _toques[_toques.size() - 1]
		var lim: float = LIMITE_INICIO if _toques.is_empty() else LIMITE_GAP
		if _relogio - ref > lim:
			break
	ouvindo = false
	dica("", "")
	if not await esperar(0.35):
		return -1
	return 1 if julgar(_toques, padrao_atual()) else 0


## A virada: o Quico apita um padrão que o jogador não repete e, de fora de campo, respondem com o mesmo ritmo, mais agudo.
func _virada() -> bool:
	virada_ativa = true
	_tipos = FINAL
	_montar_notas(FINAL)
	placar("Rodada final")
	dica("Só escute...", "Só escute...")
	if not await esperar(0.9):
		return false
	for i in FINAL.size():
		var longa: bool = int(FINAL[i]) == 1
		_acender(i, COR_DEMO)
		_batida_quico(longa)
		if not await esperar(GAP_LONGA if longa else GAP_CURTA):
			return false
	if not await esperar(0.9):
		return false
	for vez in 2:
		if vez == 0:
			_olhar_para_o_muro()
			GameState.definir_corruption_manual(0.2)
			if is_instance_valid(env):
				var te := create_tween().set_parallel()
				te.tween_property(env, "ambient_light_energy", 0.75, 2.0)
				te.tween_property(env, "fog_light_color", Color(0.72, 0.8, 0.88), 2.0)
		for i in FINAL.size():
			var longa: bool = int(FINAL[i]) == 1
			_resposta_de_fora(longa)
			if not await esperar(GAP_LONGA if longa else GAP_CURTA):
				return false
		respostas_de_fora += 1
		if not await esperar(1.0):
			return false
	Efeitos.pulso(0.25, 0.4)
	if not await esperar(2.4):          # silêncio
		return false
	return await falar("quico", ["...", "Não fui eu."])


## A resposta de fora de campo: o mesmo ritmo, mais agudo; anéis pálidos acima do muro e um "pii" miúdo (vale mesmo sem som).
func _resposta_de_fora(longa: bool) -> void:
	var cor := Color(0.78, 0.9, 1.0, 0.8)
	_anel(POS_RESPOSTA, cor, 2.4 if longa else 1.5, 0.9 if longa else 0.55)
	_balao("piiiiu" if longa else "pii", Color(0.82, 0.92, 1.0), POS_RESPOSTA + Vector3(randf_range(-0.5, 0.5), 0.5 + randf_range(0.0, 0.5), 0), 0.8 if longa else 0.6)
	Audio.sfx("apito", -5.0, randf_range(1.85, 1.95) if longa else randf_range(2.1, 2.2))


func _olhar_para_o_muro() -> void:
	create_tween().tween_property(_ave, "rotation_degrees:y", 78.0, 0.9).set_trans(Tween.TRANS_SINE)




