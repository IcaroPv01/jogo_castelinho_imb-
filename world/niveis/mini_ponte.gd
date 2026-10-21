extends MiniGameBase
## Minigame "Um, dois, três, pescador!" (Módulo 16): o jogador atravessa a ponte à noite, de poste a poste, enquanto sete
## pescadores de sardinha (silhuetas genéricas, sem rosto) contam de costas e se viram de repente.
##   - UMA ação, MANTIDA: segurar a ação (clique, [E] ou o botão Interagir) = andar (2 m/s); soltar = parar.
##   - Os pescadores dizem "UM... DOIS... TRÊS..." (legenda grande + cliques) e então se viram todos de uma vez. Se o jogador ainda
##     está segurando quando terminam de virar, apanhou: a câmera volta ao começo do TRECHO atual (nada além disso: nunca morre).
##     No 3º apanhado seguido a contagem fica mais lenta (`lenta`). Soltou a tempo: eles ficam olhando um instante, viram de volta.
##   - 3 trechos de 8 m (de poste a poste). No 3º o poste da frente está apagado e acende quando o jogador chega.
##   - VIRADA (só sugestão, sem grito): ao chegar ao último poste os pescadores viram TODOS para o mesmo lugar, atrás do jogador
##     (para onde ele começou), e não para ele. A câmera gira e, bem longe na neblina, há UMA figura branca parada (`FiguraBranca`,
##     ativa=false, como na cidade_ponte); no guarda-corpo ao lado dele, uma sandália pequena (sugestão do Tito, fictício).
##     A Tainá diz "Eles nunca olham para mim...". Silêncio.
## Fatos (docs/pesquisa/historia_imbe.md §6 e §8): ponte de três pistas, pesca de sardinha, lenda do Passo da Mãe Rosa (figura
## branca que some). Nada além disso.
## Públicos para os testes: `trecho` (1..3), `palavra` (0..3 = já falou UM/DOIS/TRÊS; 4 = "PESCADOR!"), `pescadores_virados`
## (olhando para o jogador), `pescadores_para_tras` (virada), `apanhados_seguidos`, `apanhados_total`, `facilitadas`, `lenta`,
## `segurando_simulado` (o teste segura sem Input), `posicao_z()`, `chegou`, `virada_ativa`, `inicio_do_trecho()`.

enum Fase { LIVRE, CONTANDO, VIRANDO, OLHANDO, VOLTANDO, APANHADO, PARADO }

const ZS: Array[float] = [0.0, -8.0, -16.0, -24.0]   # início do trecho 1, e o poste que fecha cada trecho
const X_JOGADOR := -3.2
const VELOCIDADE := 2.0                               # m/s segurando
const Z_FILA := -32.0                                 # a fila de pescadores
const X_FILA: Array[float] = [-4.5, -3.0, -1.5, 0.0, 1.5, 3.0, 4.5]
const Z_FIM_FILA := -39.0                             # o poste aceso no fim da fila (luz de fundo)
const X_GRADE := 5.35
const ALT_GRADE := 0.94
const TEMPO_VIRAR := 0.5
const FATOR_LENTA := 1.7
const APANHADOS_PARA_FACILITAR := 3
const Z_FIGURA := 4.0                                # a figura branca: bem atrás do ponto de partida
const COR_LAMPADA := Color(1.0, 0.8, 0.45)
const COR_LAMPADA_MORTA := Color(0.3, 0.3, 0.33)

const PALAVRAS: Array = ["UM...", "DOIS...", "TRÊS...", "PESCADOR!"]
const CORES_PALAVRA: Array = [Color(0.95, 0.97, 1.0), Color(1.0, 0.92, 0.55), Color(1.0, 0.66, 0.25), Color(1.0, 0.3, 0.25)]

## (teste/ajuste) começar direto num trecho: 1 a 3.
@export var trecho_inicial := 1

var trecho := 1
var palavra := 0
var pescadores_virados := false
var pescadores_para_tras := false
var apanhados_seguidos := 0
var apanhados_total := 0
var facilitadas := 0
var lenta := false
var segurando_simulado := false
var chegou := false
var virada_ativa := false
var contagem_ultima := 0.0                 # s da última contagem (soma dos intervalos; para o teste)

var _fase: Fase = Fase.LIVRE
var _z := 0.0
var _relogio := 0.0
var _passo_t := 0.0
var _giro := 0.0                           # 0 = de costas, 1 = olhando (o alvo está em `_yaw_alvo`)
var _tw_giro: Tween
var _yaw_alvo: Array[float] = []
var _pesc: Array[Node3D] = []
var _lbl_conta: Label
var _lamp_mat: Array[StandardMaterial3D] = []
var _halo_mat: Array[StandardMaterial3D] = []
var _luz_p3: OmniLight3D
var _sandalia: Node3D
var _figura: FiguraBranca
var _tw_cortina: Tween
var _tw_conta: Tween


func _init() -> void:
	super()
	id = "ponte"
	quem_fala = "taina"
	fala_fim = ["Aquela sandália é bem pequena...", "Vamos voltar. E sem olhar para trás, tá?"]
	destino = "res://world/niveis/cidade_ponte.tscn"
	corrupcao = 0.1


func ponto_jogador() -> Vector3:
	return Vector3(X_JOGADOR, 0.1, 0.0)


func alvo_olhar() -> Vector3:
	return Vector3(X_JOGADOR, 1.6, -30.0)


# ============================================================================ acessores públicos (testes)
func posicao_z() -> float:
	return _z


func inicio_do_trecho() -> float:
	return ZS[clampi(trecho, 1, 3) - 1]


func fase_atual() -> int:
	return _fase


## A ação está sendo mantida? (o teste usa `segurando_simulado` ou Input.action_press)
func segurando() -> bool:
	return segurando_simulado or Input.is_action_pressed("interagir")


func _pode_andar() -> bool:
	return _fase in [Fase.LIVRE, Fase.CONTANDO, Fase.VIRANDO, Fase.VOLTANDO]


# ============================================================================ o jogador "anda"
func _process(dt: float) -> void:
	super(dt)
	_relogio += dt
	if player == null or terminado or cancelado:
		return
	if acao_vale() and segurando() and _pode_andar() and not chegou and not virada_ativa:
		var alvo_z: float = ZS[clampi(trecho, 1, 3)]
		_z = maxf(_z - VELOCIDADE * dt, alvo_z)
		_passo_t -= dt
		if _passo_t <= 0.0:
			_passo_t = 0.75
			Audio.passo()
		if _z <= alvo_z + 0.001:
			chegou = true
	player.global_position = Vector3(X_JOGADOR, player.global_position.y, _z)
	if (_fase == Fase.OLHANDO or _fase == Fase.APANHADO) and _giro >= 1.0 and not pescadores_para_tras:
		_yaw_alvo = _yaws_para_o_jogador()           # os olhos acompanham o jogador (também enquanto a câmera volta)
		_set_giro(1.0)


# ============================================================================ cenário
func _montar() -> void:
	ambiente(Color(0.02, 0.035, 0.09), Color(0.12, 0.16, 0.3), Color(0.1, 0.13, 0.24), 0.016, 0.85)
	for c in get_children():
		if c is DirectionalLight3D:
			(c as DirectionalLight3D).light_energy = 0.28      # a Lua fraca
			(c as DirectionalLight3D).light_color = Color(0.62, 0.72, 1.0)
	_ponte_e_agua()
	_postes()
	_fila_de_pescadores()
	_sandalia_no_guarda_corpo()
	_luzes_longe()
	_hud_conta()
	placar("Trecho 1/3")
	dica("", "")
	Audio.ambiente("vento", -20.0, 1.5)


func _ponte_e_agua() -> void:
	var asfalto := Ato2Pecas.mat_cor(Color(0.2, 0.21, 0.24))
	var concreto := Ato2Pecas.mat_cor(Color(0.3, 0.31, 0.35))
	Construtor.caixa(self, Vector3(11.9, 0.8, 130.0), Vector3(0, -0.4, -35.0), asfalto, true, "Tabuleiro")
	for lado in [-1.0, 1.0]:
		Construtor.caixa(self, Vector3(0.4, ALT_GRADE, 130.0), Vector3(float(lado) * X_GRADE, ALT_GRADE * 0.5, -35.0), concreto, false, "Grade")
	var agua := PlaneMesh.new()
	agua.size = Vector2(500.0, 500.0)
	Ato2Pecas.malha(self, agua, Vector3(0, -3.6, -35.0), Ato2Pecas.mat_cor(Color(0.012, 0.025, 0.055))).name = "Agua"
	# faixa central tracejada (dá noção de movimento) e bordas (um MultiMesh cada)
	var tracos := MultiMesh.new()
	tracos.transform_format = MultiMesh.TRANSFORM_3D
	var tr := BoxMesh.new()
	tr.size = Vector3(0.16, 0.02, 1.8)
	tracos.mesh = tr
	var zs: Array[float] = []
	var z := 24.0
	while z > -68.0:
		zs.append(z)
		z -= 4.0
	tracos.instance_count = zs.size()
	for i in zs.size():
		tracos.set_instance_transform(i, Transform3D(Basis(), Vector3(0, 0.015, zs[i])))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = tracos
	mi.material_override = Ato2Pecas.mat_cor(Color(0.55, 0.5, 0.26))
	mi.name = "FaixaCentral"
	add_child(mi)
	for sx in [-4.15, 4.15]:
		Construtor.caixa(self, Vector3(0.12, 0.02, 130.0), Vector3(float(sx), 0.015, -35.0), Ato2Pecas.mat_cor(Color(0.42, 0.43, 0.47)), false, "FaixaBorda")


func _material_halo(cor: Color) -> StandardMaterial3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.28), Color(1, 1, 1, 0)])
	var tex := GradientTexture2D.new()
	tex.gradient = g
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 64
	tex.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	m.billboard_keep_scale = true
	m.albedo_texture = tex
	m.albedo_color = cor
	m.disable_receive_shadows = true
	return m


func _malha_caixas(itens: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it: Array in itens:
		var bm := BoxMesh.new()
		bm.size = it[0]
		st.append_from(bm, 0, Transform3D(Basis(), it[1]))
	return st.commit()


## Postes do lado leste (o braço aponta para -x): os 3 do caminho (o 3º apagado) e o do fim da fila (sempre aceso, luz de fundo).
func _postes() -> void:
	var mesh := _malha_caixas([
		[Vector3(0.18, 6.2, 0.18), Vector3(0, 3.1, 0)],
		[Vector3(1.6, 0.1, 0.12), Vector3(-0.7, 6.15, 0)],
		[Vector3(0.6, 0.14, 0.3), Vector3(-1.35, 6.05, 0)]])
	var ferro := Ato2Pecas.mat_cor(Color(0.27, 0.28, 0.32))
	var painel := BoxMesh.new()
	painel.size = Vector3(0.5, 0.04, 0.24)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var posicoes: Array[float] = [ZS[1], ZS[2], ZS[3], Z_FIM_FILA]
	for i in posicoes.size():
		var z: float = posicoes[i]
		var aceso: bool = i != 2           # o 3º poste (índice 2) começa apagado
		Ato2Pecas.malha(self, mesh, Vector3(X_GRADE, 0.0, z), ferro).name = "Poste%d" % (i + 1)
		var mat := Ato2Pecas.mat_cor(COR_LAMPADA if aceso else COR_LAMPADA_MORTA, true)
		_lamp_mat.append(mat)
		Ato2Pecas.malha(self, painel, Vector3(X_GRADE - 1.35, 5.96, z), mat).name = "Lampada%d" % (i + 1)
		var hm := _material_halo(Color(1.0, 0.72, 0.38, 0.5 if aceso else 0.0))
		_halo_mat.append(hm)
		Ato2Pecas.malha(self, quad, Vector3(X_GRADE - 1.35, 5.8, z), hm, Vector3.ZERO, Vector3(3.6, 3.6, 3.6)).name = "Brilho%d" % (i + 1)
	# a única luz de verdade: acende com o 3º poste
	_luz_p3 = Construtor.luz(self, Vector3(X_GRADE - 1.35, 5.4, ZS[3]), COR_LAMPADA, 0.0, 16.0)
	_luz_p3.name = "LuzPoste3"


func _luzes_longe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1934
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	mm.mesh = quad
	mm.instance_count = 16
	for i in 16:
		var lado := 1.0 if i % 2 == 0 else -1.0
		var p := Vector3(lado * rng.randf_range(30.0, 90.0), rng.randf_range(1.0, 4.0), rng.randf_range(-110.0, -60.0))
		var s := rng.randf_range(1.4, 2.6)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3(s, s, s)), p))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = _material_halo(Color(1.0, 0.82, 0.55, 0.4))
	mi.name = "LuzesLonge"
	add_child(mi)


# ============================================================================ os pescadores (silhuetas sem rosto)
func _malha_pescador() -> ArrayMesh:
	# frente = +z local. Corpo, cabeça, chapéu com aba para a frente, vara apoiada no ombro e um balde ao lado.
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var corpo := CapsuleMesh.new()
	corpo.radius = 0.27
	corpo.height = 1.5
	corpo.radial_segments = 10
	corpo.rings = 3
	st.append_from(corpo, 0, Transform3D(Basis(), Vector3(0, 0.78, 0)))
	var cab := SphereMesh.new()
	cab.radius = 0.14
	cab.height = 0.28
	cab.radial_segments = 10
	cab.rings = 5
	st.append_from(cab, 0, Transform3D(Basis(), Vector3(0, 1.72, 0)))
	var bone := CylinderMesh.new()
	bone.top_radius = 0.1
	bone.bottom_radius = 0.16
	bone.height = 0.1
	bone.radial_segments = 10
	st.append_from(bone, 0, Transform3D(Basis(), Vector3(0, 1.87, 0)))
	var aba := BoxMesh.new()
	aba.size = Vector3(0.3, 0.02, 0.2)
	st.append_from(aba, 0, Transform3D(Basis(), Vector3(0, 1.82, 0.17)))
	var vara := BoxMesh.new()
	vara.size = Vector3(0.025, 2.4, 0.025)
	st.append_from(vara, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(28.0)), Vector3(0.26, 1.95, -0.5)))
	var balde := CylinderMesh.new()
	balde.top_radius = 0.17
	balde.bottom_radius = 0.14
	balde.height = 0.32
	balde.radial_segments = 8
	st.append_from(balde, 0, Transform3D(Basis(), Vector3(-0.55, 0.16, -0.1)))
	return st.commit()


func _fila_de_pescadores() -> void:
	var corpo_mesh := _malha_pescador()
	var mat := Ato2Pecas.mat_cor(Color(0.035, 0.04, 0.06))
	var rosto := SphereMesh.new()                    # um oval pálido e liso no lugar do rosto: só mostra para que lado olham
	rosto.radius = 0.1
	rosto.height = 0.2
	rosto.radial_segments = 8
	rosto.rings = 4
	var mat_rosto := Ato2Pecas.mat_cor(Color(0.72, 0.74, 0.8))
	for i in X_FILA.size():
		var n := Node3D.new()
		n.name = "Pescador%d" % (i + 1)
		var esc := 0.96 + 0.05 * float(i % 3)
		n.position = Vector3(X_FILA[i], 0.0, Z_FILA + [0.0, 0.5, -0.3, 0.4, -0.2, 0.5, 0.0][i])
		n.scale = Vector3(esc, esc, esc)
		n.rotation.y = PI                            # de costas para o jogador, olhando para -z
		add_child(n)
		Ato2Pecas.malha(n, corpo_mesh, Vector3.ZERO, mat).name = "Corpo"
		Ato2Pecas.malha(n, rosto, Vector3(0, 1.71, 0.09), mat_rosto, Vector3.ZERO, Vector3(0.85, 1.05, 0.4)).name = "Rosto"
		_pesc.append(n)
		_yaw_alvo.append(PI)


func _set_giro(k: float) -> void:
	_giro = k
	for i in _pesc.size():
		_pesc[i].rotation.y = lerpf(PI, _yaw_alvo[i], k)


## Todos viram na mesma direção (anti-horária vista de cima): para o jogador ou, na virada, para o mesmo ponto atrás dele.
## `para` vazio = mantém os alvos de agora (para virar de volta sem pulo).
func _virar(para: Array[float], dur: float, de := 0.0, ate := 1.0) -> void:
	if not para.is_empty():
		_yaw_alvo = para
	if _tw_giro and _tw_giro.is_valid():
		_tw_giro.kill()
	_tw_giro = create_tween()
	_tw_giro.tween_method(_set_giro, de, ate, maxf(dur, 0.01)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _yaws_para_o_jogador() -> Array[float]:
	var r: Array[float] = []
	for n in _pesc:
		var d := Vector3(X_JOGADOR, 0.0, _z) - n.position
		var y := atan2(d.x, d.z)                     # direção da frente (+z local girada por yaw) até o jogador
		r.append(y + TAU)                            # +2π: todos giram no mesmo sentido
	return r


func _yaws_paralelos() -> Array[float]:
	var r: Array[float] = []
	for n in _pesc:
		r.append(TAU)                                # +z: todos olham para o mesmo lugar, atrás do jogador
	return r


# ============================================================================ sandália (só aparece na virada)
func _sandalia_no_guarda_corpo() -> void:
	_sandalia = Node3D.new()
	_sandalia.name = "Sandalia"
	_sandalia.position = Vector3(-X_GRADE, ALT_GRADE + 0.02, ZS[3] + 1.5)
	_sandalia.rotation_degrees.y = 25.0
	_sandalia.scale = Vector3.ONE * 1.5
	_sandalia.visible = false
	add_child(_sandalia)
	var sola := Ato2Pecas.mat_cor(Color(0.86, 0.5, 0.62), false, 0.25)
	var tira := Ato2Pecas.mat_cor(Color(0.95, 0.85, 0.5), false, 0.2)
	var b := BoxMesh.new()
	b.size = Vector3(0.1, 0.025, 0.24)
	Ato2Pecas.malha(_sandalia, b, Vector3.ZERO, sola)
	var t := BoxMesh.new()
	t.size = Vector3(0.1, 0.02, 0.035)
	Ato2Pecas.malha(_sandalia, t, Vector3(0, 0.03, 0.02), tira)
	var t2 := BoxMesh.new()
	t2.size = Vector3(0.035, 0.02, 0.07)
	Ato2Pecas.malha(_sandalia, t2, Vector3(0, 0.03, -0.05), tira)


# ============================================================================ HUD da contagem
func _hud_conta() -> void:
	_lbl_conta = Label.new()
	_lbl_conta.name = "Contagem"
	_lbl_conta.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_conta.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_conta.custom_minimum_size = Vector2(900.0, 120.0)
	_lbl_conta.offset_left = -450.0
	_lbl_conta.offset_right = 450.0
	_lbl_conta.offset_top = 70.0
	_lbl_conta.pivot_offset = Vector2(450.0, 60.0)
	_lbl_conta.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_conta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_estilo(_lbl_conta, 92)
	_lbl_conta.visible = false
	_camada.add_child(_lbl_conta)


func _legenda(texto: String, cor: Color, dur := 0.0) -> void:
	_lbl_conta.text = texto
	_lbl_conta.add_theme_color_override("font_color", cor)
	_lbl_conta.visible = true
	_lbl_conta.modulate.a = 1.0
	_lbl_conta.scale = Vector2(0.6, 0.6)
	if _tw_conta and _tw_conta.is_valid():
		_tw_conta.kill()
	_tw_conta = create_tween()
	_tw_conta.tween_property(_lbl_conta, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if dur > 0.0:
		_tw_conta.tween_interval(dur)
		_tw_conta.tween_property(_lbl_conta, "modulate:a", 0.0, 0.3)


func _esconder_legenda() -> void:
	if _tw_conta and _tw_conta.is_valid():
		_tw_conta.kill()
	_lbl_conta.visible = false


func _tintar(cor: Color, alfa: float, dur: float) -> void:
	if _tw_cortina and _tw_cortina.is_valid():
		_tw_cortina.kill()
	_cortina.color = Color(cor.r, cor.g, cor.b, _cortina.color.a)
	_tw_cortina = create_tween()
	_tw_cortina.tween_property(_cortina, "color:a", alfa, dur)


# ============================================================================ o jogo
func _rodar() -> bool:
	if not await falar("taina", [
			"Brincadeira da ponte: \"Um, dois, três, pescador!\"",
			Celular.dica("Segure o clique (ou [E]) para andar até o poste.", "Segure o botão Interagir para andar até o poste."),
			"Quando eles virarem, tem que estar parado. Se pegarem você, volta ao começo do trecho. Sem drama!"]):
		return false
	dica("Segure o clique ou [E] para andar, solte quando eles virarem", "Segure o botão Interagir para andar, solte quando eles virarem")
	for t in range(trecho_inicial, 4):
		trecho = t
		_z = ZS[t - 1]
		chegou = false
		lenta = false
		apanhados_seguidos = 0
		placar("Trecho %d/3" % t)
		if t == 3:
			if not await falar("taina", ["O poste da frente está apagado. Chega lá que ele acende!"]):
				return false
		while not chegou:
			if not await _ciclo():
				return false
		if not await _chegada(t):
			return false
	return await _virada()


## Uma contagem completa: UM, DOIS, TRÊS, eles viram, olham, viram de volta. false = o jogador pulou.
func _ciclo() -> bool:
	var k := FATOR_LENTA if lenta else 1.0
	_fase = Fase.CONTANDO
	palavra = 0
	var gaps: Array[float] = [randf_range(0.5, 0.8) * k, randf_range(0.5, 0.8) * k, randf_range(0.5, 1.1) * k]
	contagem_ultima = gaps[0] + gaps[1] + gaps[2]
	for i in 3:
		palavra = i + 1
		_legenda(PALAVRAS[i], CORES_PALAVRA[i])
		Audio.sfx("clique", -2.0, 0.8 + 0.2 * float(i))
		if not await _esperar_chegada(gaps[i]):
			return false
		if chegou:
			return await _cancelar_ciclo()
	# "PESCADOR!": todos se viram de uma vez
	palavra = 4
	_legenda(PALAVRAS[3], CORES_PALAVRA[3])
	Audio.sfx("slide", -4.0, 0.7)
	var tv := TEMPO_VIRAR * (1.5 if lenta else 1.0)
	_fase = Fase.VIRANDO
	_virar(_yaws_para_o_jogador(), tv)
	if not await _esperar_chegada(tv):
		return false
	if chegou:
		return await _cancelar_ciclo()
	pescadores_virados = true
	_fase = Fase.OLHANDO
	_tintar(Color(0.45, 0.0, 0.02), 0.16, 0.2)
	var pego: bool = acao_vale() and segurando()
	if pego:
		if not await _apanhado():
			return false
	else:
		apanhados_seguidos = 0
		if not await esperar(1.0):
			return false
	_esconder_legenda()
	_tintar(Color(0.45, 0.0, 0.02), 0.0, 0.3)
	pescadores_virados = false
	_fase = Fase.VOLTANDO
	_virar([], tv, 1.0, 0.0)
	if not await esperar(tv + 0.15):
		return false
	_fase = Fase.LIVRE
	return true


## Espera `seg` (s de jogo) ou até o jogador chegar ao poste. false = pulou.
func _esperar_chegada(seg: float) -> bool:
	var fim := _relogio + seg
	while _relogio < fim and not chegou:
		if not await esperar(0.02):
			return false
	return true


## O jogador chegou ao poste no meio da contagem: eles voltam de costas depressa e a contagem acaba.
func _cancelar_ciclo() -> bool:
	pescadores_virados = false
	_esconder_legenda()
	_fase = Fase.PARADO
	_virar([], 0.25, _giro, 0.0)
	return await esperar(0.3)


## Apanhou: flash vermelho, a câmera volta ao começo do trecho (só isso). 3 seguidos: contagem mais lenta.
func _apanhado() -> bool:
	_fase = Fase.APANHADO
	apanhados_seguidos += 1
	apanhados_total += 1
	_legenda("PARADO!", Color(1.0, 0.25, 0.2))
	_tintar(Color(0.6, 0.0, 0.0), 0.5, 0.08)
	Audio.sfx("erro", -4.0, 0.8)
	Efeitos.pulso(0.4, 0.3)
	if not await esperar(0.55):
		return false
	_tintar(Color(0.45, 0.0, 0.02), 0.16, 0.3)
	var voltar := create_tween()
	voltar.tween_property(self, "_z", inicio_do_trecho(), 0.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await esperar(1.0):
		return false
	_z = inicio_do_trecho()
	if apanhados_total == 1:
		if not await falar("taina", ["Ele disse \"parado\"!", "Volta ao poste e tenta de novo."]):
			return false
	elif apanhados_seguidos >= APANHADOS_PARA_FACILITAR:
		lenta = true
		facilitadas += 1
		apanhados_seguidos = 0
		if not await falar("taina", ["Tá, tá! Eu peço para eles contarem mais devagar."]):
			return false
	return true


## Chegou ao poste do trecho `t`: o poste acende (o 3º estava apagado) e o trecho acaba.
func _chegada(t: int) -> bool:
	_fase = Fase.PARADO
	pescadores_virados = false
	_esconder_legenda()
	_acender_poste(t - 1)
	Audio.sfx("acerto", -3.0, 1.0)
	if t < 3:
		Efeitos.aviso("Poste %d" % t, 1.2)
	return await esperar(0.9)


func _acender_poste(i: int) -> void:
	var tw := create_tween().set_parallel()
	tw.tween_property(_lamp_mat[i], "albedo_color", COR_LAMPADA, 0.5)
	tw.tween_property(_halo_mat[i], "albedo_color:a", 0.5, 0.5)
	if i == 2 and _luz_p3:
		tw.tween_property(_luz_p3, "light_energy", 2.0, 0.6)


## VIRADA: os pescadores olham todos para o mesmo lugar, atrás do jogador. Sem susto, só silêncio.
func _virada() -> bool:
	virada_ativa = true
	dica("", "")
	GameState.definir_corruption_manual(0.2)
	if not await esperar(1.2):
		return false
	Audio.ambiente("", -8.0, 2.0)                    # o vento para
	_virar(_yaws_paralelos(), 1.6)
	if not await esperar(1.9):
		return false
	pescadores_para_tras = true
	pescadores_virados = false
	_sandalia.visible = true
	# a câmera gira para trás (passa pela sandália no guarda-corpo) e acha a figura longe
	var tw := create_tween()
	tw.tween_property(player, "rotation:y", PI, 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await esperar(1.4):
		return false
	_criar_figura()
	if not await esperar(2.0):
		return false
	if not await esperar(1.8):                       # silêncio: ela só está lá
		return false
	if not await falar("taina", ["Eles nunca olham para mim...", "Hoje estão olhando para lá."]):
		return false
	var tw2 := create_tween()
	tw2.tween_property(player, "rotation:y", deg_to_rad(152.0), 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	if not await esperar(3.2):
		return false
	return true


func _criar_figura() -> void:
	if _figura != null:
		return
	_figura = FiguraBranca.new()
	_figura.name = "FiguraBranca"
	_figura.ativa = false                            # parada, como na cidade_ponte
	_figura.som_ativo = false
	_figura.distancia_cercar = 1.0
	add_child(_figura)
	_figura.global_position = Vector3(X_JOGADOR, 0.0, Z_FIGURA)
	_figura.alvo = player
	# um clarão fraco atrás dela (a névoa a engole): só para o olho achá-la
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	var brilho := Ato2Pecas.malha(self, quad, Vector3(X_JOGADOR, 1.2, Z_FIGURA - 0.3), _material_halo(Color(0.75, 0.88, 1.0, 0.0)), Vector3.ZERO, Vector3(4.5, 4.5, 4.5))
	brilho.name = "BrilhoFigura"
	create_tween().tween_property(brilho.material_override, "albedo_color:a", 0.16, 2.5)
