extends MiniGameBase
## Minigame "O Lanchão" (Módulo 16): a gravura da Sala do Pescador. Junho de 1839: o lanchão Seival é levado por terra,
## por bois, até a barra do Rio Tramandaí (docs/pesquisa/historia_imbe.md; PLANO §5.2). Cena pequena na margem, neblina cinza.
##
## UMA ação (clique, [E] ou Interagir no celular): os bois dão um passo no ritmo. Cada passo tem um "pulso" visível (cabeças
## baixando, corda esticando, "!" amarelo e o aviso PUXA! na tela, mais um "TUM" no som). Apertar dentro da janela
## (~0,5 s) faz o barco avançar um trecho; errar só atrasa (a rodada passa em falso). 8 puxadas certas = chegou à água.
##
## VIRADA: o barco entra na água, todos param e sentam, mas os bois e a corda seguem dando passos na neblina, no mesmo
## ritmo. Tainá: "Já acabou. Quem ainda está puxando?" Na lama, junto da corda, fica UMA pegada pequena de criança
## (a pista do Tito, só sugestão). Nada de sangue nem de violência: só a corda que não para.
##
## Parâmetros de teste: `esta_na_janela()` (hora de apertar), `puxadas`, `erros`, sinais `puxada_feita` e `virou`.
signal puxada_feita(numero: int)
signal virou

const META := 8
const PASSO := 1.4                 # metros que o barco anda a cada puxada certa
const CICLO := 3.2                 # s entre um passo dos bois e o próximo
const BATIDA := 2.4                # s (desde o começo do ciclo) em que o casco do boi bate no chão: o "TUM"
const JANELA_MEIA := 0.27          # a janela vale BATIDA ± isto (0,54 s no total: generosa)
const ANTIC_INI := 1.45            # s em que a corda começa a esticar e os bois a baixar a cabeça
const Z_PISTA := -6.0              # z do caminho do barco
const Z_BARCO_FIM := -9.8          # z do barco quando está na água
const Z_BORDA := -8.2              # z da margem (a água começa aqui)
const BOIS_X := 6.2                # onde os bois ficam, na frente do barco (x do comboio)
const CAM_DX := 2.6                # a câmera anda junto: fica 2,6 m à frente do centro do barco
const COR_CORDA := Color(0.42, 0.31, 0.19)
const COR_JANELA := Color(1.0, 0.82, 0.2)

var puxadas := 0
var erros := 0
var erros_seguidos := 0

var _t := 0.0
var _tc := 0.0                     # tempo dentro do ciclo do passo
var _ativo_ciclo := false
var _travado := false              # já apertou neste ciclo (cedo, tarde ou certo): um aperto por passo
var _acertou := false
var _puxou := false
var _fantasma := false             # a virada: os bois seguem no ritmo sem ninguém
var _fantasma_forca := 1.0
var _seguir := true                # a câmera acompanha o comboio
var _na_agua := false
var _tens := 0.0
var _wig := 0.0
var _aviso_t := 0.0
var _janela_antes := false

var _com: Node3D                   # comboio: barco + bois + homens (tudo que anda)
var _barco: Node3D
var _bois: Node3D
var _cabecas: Array[Node3D] = []
var _pernas: Array[Node3D] = []
var _homens: Array[Node3D] = []
var _homens_sentados := false
var _corda_seg: Array[MeshInstance3D] = []
var _mat_corda: StandardMaterial3D
var _mat_poeira: StandardMaterial3D
var _exclama: Label3D
var _lbl_aviso: Label
var _pegada: MeshInstance3D
var _lama: MeshInstance3D


func _init() -> void:
	super()
	id = "lanchao"
	quem_fala = "taina"
	fala_fim = [
		"Tem uma pegada na lama. Pequena. De criança.",
		"Descalça. E bem perto da corda...",
	]


func ponto_jogador() -> Vector3:
	return Vector3(CAM_DX, 0.1, 0.0)


func alvo_olhar() -> Vector3:
	return Vector3(CAM_DX, 1.3, Z_PISTA)


## Os bois param de verdade só no fim: o balão não-bloqueante da Tainá não impede o clique (só uma fala que bloqueia).
func acao_vale() -> bool:
	return not terminado and not cancelado and _desde_inicio > 0.4 and not Guia.bloqueando()


## Hora de apertar? (o teste usa isto)
func esta_na_janela() -> bool:
	return _ativo_ciclo and not _travado and not _puxou and absf(_tc - BATIDA) <= JANELA_MEIA and acao_vale()


## A ação do jogador. Um aperto por passo dos bois: dentro da janela puxa, fora dela o passo passa em falso.
func acionar() -> void:
	if not _ativo_ciclo or _travado or _fantasma or not acao_vale():
		return
	_travado = true
	if absf(_tc - BATIDA) <= JANELA_MEIA:
		_acertou = true
		if _tc >= BATIDA:
			_puxar()       # depois da batida: puxa agora; antes dela, o barco anda na batida (veja _batida)
		else:
			_aviso("Boa!", Color(0.5, 1.0, 0.55), 0.5)
	else:
		_errar("Cedo demais!" if _tc < BATIDA else "Tarde!")


# ============================================================================ cenário
func _montar() -> void:
	ambiente(Color(0.56, 0.6, 0.64), Color(0.8, 0.81, 0.8), Color(0.74, 0.75, 0.74), 0.028, 0.95)
	_mat_corda = Ato2Pecas.mat_cor(COR_CORDA)
	_mat_poeira = Ato2Pecas.mat_cor(Color(0.62, 0.58, 0.52, 0.6), true)
	_mat_poeira.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_chao_e_agua()
	_com = Node3D.new()
	_com.name = "Comboio"
	_com.position = Vector3(0, 0, Z_PISTA)
	add_child(_com)
	_criar_barco()
	_criar_bois()
	_criar_homens()
	_criar_corda()
	_exclama = Construtor.rotulo(self, "!", Vector3(0, 3.0, Z_PISTA), 130, COR_JANELA)
	_exclama.pixel_size = 0.008
	_exclama.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_exclama.no_depth_test = true
	_exclama.outline_size = 22
	_exclama.outline_modulate = Color(0.2, 0.05, 0.0)
	_exclama.visible = false
	_exclama.name = "Exclama"
	_lbl_aviso = Label.new()
	_lbl_aviso.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_lbl_aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_aviso.offset_top = 90.0
	_lbl_aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_estilo(_lbl_aviso, 72)
	_lbl_aviso.visible = false
	_camada.add_child(_lbl_aviso)
	placar("Puxadas 0/%d" % META)


func _chao_e_agua() -> void:
	var barro := Ato2Pecas.mat_tri("lanchao_chao", Color(0.78, 0.73, 0.66), Ato2Pecas.tex_areia(), 0.25, 1.0)
	var lama := Ato2Pecas.mat_cor(Color(0.3, 0.25, 0.2))
	# terra firme com colisão (o jogador fica parado, mas a câmera anda: a colisão evita o vazio)
	Construtor.caixa(self, Vector3(200, 0.6, 40.0), Vector3(15, -0.3, Z_BORDA + 20.0), barro, true, "Chao")
	# caminho de barro batido por onde o barco passa
	Construtor.caixa(self, Vector3(199.5, 0.02, 3.6), Vector3(15, 0.012, Z_PISTA), lama, false, "Caminho")
	# margem molhada
	Construtor.caixa(self, Vector3(199.5, 0.02, 1.0), Vector3(15, 0.01, Z_BORDA + 0.5), Ato2Pecas.mat_cor(Color(0.2, 0.19, 0.18)), false, "Margem")
	# o rio Tramandaí: um plano só, cinza, quase parado
	var agua := PlaneMesh.new()
	agua.size = Vector2(400, 130)
	var mat_agua := Ato2Pecas.mat_cor(Color(0.30, 0.38, 0.43))
	mat_agua.roughness = 0.25
	var mi := Ato2Pecas.malha(self, agua, Vector3(15, -0.13, Z_BORDA - 65.0), mat_agua)
	mi.name = "Rio"
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	# a outra margem, só uma faixa fantasmagórica na neblina
	Construtor.caixa(self, Vector3(300, 5.0, 3.0), Vector3(15, 1.5, -70.0), Ato2Pecas.mat_cor(Color(0.4, 0.43, 0.42)), false, "OutraMargem")
	# tufos de capim e pedras (uma MultiMesh cada) para o chão "andar" quando a câmera anda
	var rng := RandomNumberGenerator.new()
	rng.seed = 1839
	var tufo := BoxMesh.new()
	tufo.size = Vector3(0.06, 0.4, 0.06)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = tufo
	mm.instance_count = 140
	for i in mm.instance_count:
		var pos := _ponto_livre(rng)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3)))
		b = b.scaled(Vector3(1, rng.randf_range(0.6, 1.5), 1))
		mm.set_instance_transform(i, Transform3D(b, Vector3(pos.x, 0.18, pos.z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ato2Pecas.mat_cor(Color(0.36, 0.38, 0.26))
	mmi.name = "Capim"
	add_child(mmi)
	var pedra := BoxMesh.new()
	pedra.size = Vector3(0.5, 0.25, 0.4)
	var mm2 := MultiMesh.new()
	mm2.transform_format = MultiMesh.TRANSFORM_3D
	mm2.mesh = pedra
	mm2.instance_count = 50
	for i in mm2.instance_count:
		var pos2 := _ponto_livre(rng)
		var b2 := Basis.from_euler(Vector3(0, rng.randf() * TAU, 0)).scaled(Vector3.ONE * rng.randf_range(0.5, 1.2))
		mm2.set_instance_transform(i, Transform3D(b2, Vector3(pos2.x, 0.05, pos2.z)))
	var mmi2 := MultiMeshInstance3D.new()
	mmi2.multimesh = mm2
	mmi2.material_override = Ato2Pecas.mat_cor(Color(0.5, 0.5, 0.48))
	mmi2.name = "Pedras"
	add_child(mmi2)


## Um ponto da terra fora do caminho do barco (para capim e pedras não ficarem no meio dele).
func _ponto_livre(rng: RandomNumberGenerator) -> Vector3:
	var x := rng.randf_range(-14.0, 40.0)
	var z := rng.randf_range(Z_BORDA + 1.2, 6.0)
	if absf(z - Z_PISTA) < 2.2:
		z = Z_PISTA + 2.4 + rng.randf() * 3.0
	return Vector3(x, 0.0, z)


func _criar_barco() -> void:
	_barco = Node3D.new()
	_barco.name = "Lanchao"
	_com.add_child(_barco)
	var madeira := Ato2Pecas.mat_cor(Color(0.36, 0.25, 0.16))
	var tabua := Ato2Pecas.mat_cor(Color(0.46, 0.33, 0.21))
	var escuro := Ato2Pecas.mat_cor(Color(0.2, 0.14, 0.1))
	Construtor.caixa(_barco, Vector3(3.8, 0.55, 1.5), Vector3(0, 0.62, 0), madeira, false, "Casco")
	for lado in [-1.0, 1.0]:
		Construtor.caixa(_barco, Vector3(3.9, 0.3, 0.08), Vector3(0, 1.0, lado * 0.77), tabua, false)
	Construtor.caixa(_barco, Vector3(3.5, 0.06, 1.35), Vector3(0, 0.92, 0), escuro, false)        # interior escuro
	for x in [-1.0, 0.2, 1.2]:
		Construtor.caixa(_barco, Vector3(0.22, 0.07, 1.4), Vector3(x, 1.06, 0), tabua, false)       # bancos
	var proa := PrismMesh.new()
	proa.size = Vector3(0.55, 1.0, 1.5)     # depois de girar: 0,55 de altura, 1,0 de comprimento, ponta para +x
	Ato2Pecas.malha(_barco, proa, Vector3(2.35, 0.62, 0), madeira, Vector3(0, 0, -90))
	var popa := PrismMesh.new()
	popa.size = Vector3(0.55, 0.45, 1.5)
	Ato2Pecas.malha(_barco, popa, Vector3(-2.1, 0.62, 0), madeira, Vector3(0, 0, 90))
	# rolos de madeira sob o casco (o barco vai arrastado por terra)
	var rolo := CylinderMesh.new()
	rolo.top_radius = 0.17
	rolo.bottom_radius = 0.17
	rolo.height = 1.9
	rolo.radial_segments = 8
	for x in [-1.3, 0.0, 1.3]:
		Ato2Pecas.malha(_barco, rolo, Vector3(x, 0.17, 0), escuro, Vector3(90, 0, 0))
	var nome := Construtor.rotulo(_barco, "SEIVAL", Vector3(0, 0.66, 0.77), 56, Color(0.93, 0.88, 0.74))
	nome.pixel_size = 0.0065
	nome.name = "Nome"


func _criar_bois() -> void:
	_bois = Node3D.new()
	_bois.name = "Bois"
	_bois.position = Vector3(BOIS_X, 0, 0)
	_com.add_child(_bois)
	var corpo := CapsuleMesh.new()
	corpo.radius = 0.36
	corpo.height = 1.7
	var focinho := BoxMesh.new()
	focinho.size = Vector3(0.6, 0.4, 0.36)
	var perna := BoxMesh.new()
	perna.size = Vector3(0.13, 0.75, 0.13)
	var chifre := CylinderMesh.new()
	chifre.top_radius = 0.0
	chifre.bottom_radius = 0.05
	chifre.height = 0.32
	chifre.radial_segments = 5
	chifre.rings = 1
	var cores := [Color(0.42, 0.28, 0.18), Color(0.66, 0.58, 0.46)]
	for k in 2:
		var cor: Color = cores[k]
		var mat := Ato2Pecas.mat_cor(cor)
		var boi := Node3D.new()
		boi.name = "Boi%d" % k
		boi.position = Vector3(0, 0, (k * 2 - 1) * 0.5)
		_bois.add_child(boi)
		Ato2Pecas.malha(boi, corpo, Vector3(0, 1.05, 0), mat, Vector3(0, 0, 90))
		Construtor.caixa(boi, Vector3(0.12, 0.1, 0.1), Vector3(-0.95, 1.2, 0), mat, false)      # rabo
		var pescoco := Node3D.new()
		pescoco.position = Vector3(0.78, 1.25, 0)
		boi.add_child(pescoco)
		Ato2Pecas.malha(pescoco, focinho, Vector3(0.36, -0.06, 0), mat)
		Ato2Pecas.malha(pescoco, chifre, Vector3(0.2, 0.26, 0.13), Ato2Pecas.mat_cor(Color(0.85, 0.8, 0.7)), Vector3(0, 0, 0))
		Ato2Pecas.malha(pescoco, chifre, Vector3(0.2, 0.26, -0.13), Ato2Pecas.mat_cor(Color(0.85, 0.8, 0.7)), Vector3(0, 0, 0))
		Construtor.caixa(pescoco, Vector3(0.12, 0.22, 0.3), Vector3(0.68, -0.12, 0), Ato2Pecas.mat_cor(Color(0.15, 0.1, 0.09)), false)
		_cabecas.append(pescoco)
		for i in 4:
			var quadril := Node3D.new()
			quadril.position = Vector3(0.55 if i < 2 else -0.55, 0.75, (i % 2) * 0.36 - 0.18)
			boi.add_child(quadril)
			Ato2Pecas.malha(quadril, perna, Vector3(0, -0.375, 0), mat)
			_pernas.append(quadril)
	# canga (a travessa de madeira que une os dois bois) e o ponto onde a corda se prende
	Construtor.caixa(_bois, Vector3(0.14, 0.14, 1.5), Vector3(0.95, 1.5, 0), Ato2Pecas.mat_cor(Color(0.3, 0.21, 0.13)), false, "Canga")


func _criar_homens() -> void:
	var sombra := Ato2Pecas.mat_cor(Color(0.1, 0.1, 0.13))
	var corpo := CapsuleMesh.new()
	corpo.radius = 0.23
	corpo.height = 1.55
	var cabeca := SphereMesh.new()
	cabeca.radius = 0.13
	cabeca.height = 0.26
	var chapeu := CylinderMesh.new()
	chapeu.top_radius = 0.12
	chapeu.bottom_radius = 0.34
	chapeu.height = 0.12
	var lugares := [Vector3(-3.2, 0, 0.35), Vector3(-4.0, 0, -0.5), Vector3(-1.4, 0, -1.4), Vector3(0.9, 0, -1.4)]   # atrás e do lado de lá: não tapam o barco
	for i in lugares.size():
		var h := Node3D.new()
		h.name = "Homem%d" % i
		h.position = lugares[i]
		h.rotation_degrees.y = -4.0 * i
		_com.add_child(h)
		Ato2Pecas.malha(h, corpo, Vector3(0, 0.95, 0), sombra)
		Ato2Pecas.malha(h, cabeca, Vector3(0, 1.88, 0), sombra)
		Ato2Pecas.malha(h, chapeu, Vector3(0, 2.02, 0), sombra)
		_homens.append(h)


func _criar_corda() -> void:
	var fio := BoxMesh.new()
	fio.size = Vector3(0.07, 0.07, 1.0)       # comprimento em z: look_at + scale.z esticam o segmento
	for i in 7:
		var mi := MeshInstance3D.new()
		mi.mesh = fio
		mi.material_override = _mat_corda
		mi.name = "Corda%d" % i
		add_child(mi)
		_corda_seg.append(mi)


# ============================================================================ animação
func _process(dt: float) -> void:
	super._process(dt)
	_t += dt
	var ritmo := _ativo_ciclo or _fantasma
	var tc_ant := _tc
	if ritmo:
		_tc += dt
		if _tc >= BATIDA and tc_ant < BATIDA:
			_batida()
		if _fantasma and _tc >= CICLO:
			_tc -= CICLO
	_tens = _calcular_tensao(ritmo) * (_fantasma_forca if _fantasma else 1.0)
	_wig = maxf(_wig - dt * 0.5, 0.0)
	_animar_bois(ritmo)
	_animar_homens()
	_animar_barco()
	_esticar_corda()
	_atualizar_avisos(dt)
	if player and not terminado:
		player.pode_mover = false     # (um modal que feche no meio não pode soltar o jogador do palco)
	if _seguir and player and not terminado:
		player.global_position = Vector3(_com.position.x + CAM_DX, 0.1, 0.0)


func _calcular_tensao(ritmo: bool) -> float:
	if not ritmo or _tc < ANTIC_INI:
		return 0.0
	if _tc < BATIDA:
		return smoothstep(ANTIC_INI, BATIDA, _tc)
	return 1.0 - smoothstep(BATIDA, BATIDA + 0.7, _tc)


func _animar_bois(ritmo: bool) -> void:
	var forca := _fantasma_forca if _fantasma else 1.0
	for c in _cabecas:
		c.rotation.z = -_tens * 0.55
	_bois.rotation.z = -_tens * 0.05
	var amp := (0.15 + 0.5 * _tens) * forca if ritmo else 0.0
	var fase := (_tc / CICLO) * TAU * 2.0
	for i in _pernas.size():
		_pernas[i].rotation.z = sin(fase + (i % 2) * PI + (i / 4) * 0.6) * amp


func _animar_homens() -> void:
	if _homens_sentados:
		return
	for h in _homens:
		h.rotation.z = -0.2 - 0.12 * _tens      # empurram o barco: inclinados para a frente


func _animar_barco() -> void:
	if _na_agua:
		_barco.position.y = -0.12 + sin(_t * 1.4) * 0.03
		_barco.rotation.z = sin(_t * 1.1) * 0.025


## Segmentos da corda entre a proa e a canga dos bois: frouxa quando os bois descansam, reta na batida.
func _esticar_corda() -> void:
	var a := _barco.to_global(Vector3(2.8, 0.75, 0.0))
	var b := _bois.to_global(Vector3(0.95, 1.4, 0.0))
	var frouxa := (1.0 - _tens) * 0.9
	var n := _corda_seg.size()
	var ant := a
	for i in n:
		var u := float(i + 1) / n
		var p := a.lerp(b, u)
		p.y -= frouxa * 4.0 * u * (1.0 - u)
		p.z += sin(_t * 7.0 + u * 7.0) * _wig * sin(u * PI)
		_segmento(_corda_seg[i], ant, p)
		ant = p


func _segmento(mi: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var d := b - a
	var comp := d.length()
	if comp < 0.001:
		return
	mi.global_position = a + d * 0.5
	mi.look_at(b, Vector3.UP)
	mi.scale = Vector3(1, 1, comp)


func _atualizar_avisos(dt: float) -> void:
	var na_janela := _ativo_ciclo and not _travado and not _puxou and absf(_tc - BATIDA) <= JANELA_MEIA
	if na_janela != _janela_antes:
		_janela_antes = na_janela
		_mat_corda.albedo_color = COR_JANELA if na_janela else COR_CORDA
	_exclama.visible = na_janela
	if na_janela:
		_exclama.global_position = _bois.to_global(Vector3(0.95, 2.35, 0.0))
		_lbl_aviso.text = "PUXA!"
		_lbl_aviso.modulate = COR_JANELA
		_lbl_aviso.visible = true
		return
	_aviso_t = maxf(_aviso_t - dt, 0.0)
	_lbl_aviso.visible = _aviso_t > 0.0


func _aviso(texto: String, cor: Color, dur: float) -> void:
	_lbl_aviso.text = texto
	_lbl_aviso.modulate = cor
	_aviso_t = dur


## O casco do boi bate no chão: "TUM", poeira, e (se o jogador apertou) o barco anda.
func _batida() -> void:
	Audio.sfx("passo_2", -2.0, 0.55)
	for z in [-0.45, 0.45]:
		_poeira(_bois.to_global(Vector3(0.6, 0.06, z)))
	if _fantasma:
		_wig = 0.22
		if _na_agua:
			_empurrao_fantasma()
		return
	if _acertou and not _puxou:
		_puxar()


func _poeira(pos: Vector3) -> void:
	var m := _mat_poeira.duplicate() as StandardMaterial3D
	var mi := MeshInstance3D.new()
	var esf := SphereMesh.new()
	esf.radius = 0.5
	esf.height = 0.6
	esf.radial_segments = 8
	esf.rings = 4
	mi.mesh = esf
	mi.material_override = m
	mi.position = pos
	mi.scale = Vector3(0.3, 0.2, 0.3)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(1.0, 0.45, 1.0), 0.9).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.9)
	tw.chain().tween_callback(mi.queue_free)


# ============================================================================ puxar e errar
func _puxar() -> void:
	if _puxou:
		return
	_puxou = true
	puxadas += 1
	erros_seguidos = 0
	placar("Puxadas %d/%d" % [puxadas, META])
	Audio.sfx("acerto", -8.0)
	_aviso("Boa!", Color(0.5, 1.0, 0.55), 0.7)
	var tw := create_tween()
	tw.tween_property(_com, "position:x", PASSO * puxadas, 0.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	puxada_feita.emit(puxadas)
	match puxadas:
		1:
			Guia.falar("taina", ["Isso! Um passo de cada vez."])
		3:
			Guia.falar("taina", ["Foram de 80 a 100 quilômetros assim, de verdade! Haja paciência."])
		5:
			Guia.falar("taina", ["Os homens nem reclamam. Estão todos quietinhos."])
		7:
			Guia.falar("taina", ["Falta pouco! Já dá pra sentir o cheiro do rio."])


func _errar(texto: String) -> void:
	erros += 1
	erros_seguidos += 1
	_wig = 0.25
	Audio.sfx("erro", -10.0)
	_aviso(texto, Color(1.0, 0.55, 0.45), 0.8)
	if erros_seguidos == 2:
		Guia.falar("taina", ["Calma! Espere o ! amarelo aparecer e aperte só então."])


# ============================================================================ o jogo
func _rodar() -> bool:
	if not await falar("taina", [
			"Oi, guri! Junho de 1839: o Garibaldi levou o lanchão Seival por terra, com bois, até a barra do Rio Tramandaí!",
			"Os bois dão um passo no ritmo, bem pesado: TUM! Quando aparecer o ! amarelo, clique (ou E) para puxar junto!",
			"Oito puxadas e o barco chega na água. Errou? Sem problema: só demora mais."]):
		return false
	dica("Clique ou [E] na hora do passo", "Toque em Interagir na hora do passo")
	if not await esperar(0.8):
		return false
	while puxadas < META:
		if not await _ciclo():
			return false
	# --- a virada: o barco chega à água, todos param, mas os bois seguem
	_fantasma = true
	_ativo_ciclo = false
	dica("", "")
	GameState.definir_corruption_manual(0.22)
	if not await esperar(0.9):
		return false
	_barco_na_agua()
	Guia.falar("taina", ["Chegou! Dali o Seival seguiu por mar, rumo a Laguna!"])
	if not await esperar(2.0):
		return false
	_homens_param()
	virou.emit()
	create_tween().tween_property(env, "fog_density", 0.05, 8.0)
	if not await esperar(3.2):
		return false
	if not await falar("taina", ["Já acabou.", "Quem ainda está puxando?"]):
		return false
	if not await esperar(2.4):
		return false
	_seguir = false
	_ir_para_pegada()
	if not await esperar(2.6):
		return false
	_parar_bois()
	if not await esperar(2.2):
		return false
	_mostrar_pegada()
	return await esperar(2.6)


## Um passo dos bois (CICLO s). Termina cedo depois da última puxada.
func _ciclo() -> bool:
	_tc = 0.0
	_acertou = false
	_travado = false
	_puxou = false
	_ativo_ciclo = true
	var fim_janela := BATIDA + JANELA_MEIA + 0.08
	if not await esperar(fim_janela):
		return false
	if not _travado and not _puxou:
		_errar("Perdeu o passo!")
	if puxadas >= META:
		return true
	return await esperar(CICLO - fim_janela)


func _barco_na_agua() -> void:
	_na_agua = false
	var tw := create_tween().set_parallel()
	tw.tween_property(_barco, "position:z", Z_BARCO_FIM - Z_PISTA, 1.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_property(_barco, "position:y", -0.12, 1.6)
	tw.chain().tween_callback(func() -> void:
		_na_agua = true
		Audio.sfx("splash", -3.0)
		_anel_na_agua(_barco.global_position))


func _anel_na_agua(pos: Vector3) -> void:
	var tor := TorusMesh.new()
	tor.inner_radius = 0.9
	tor.outer_radius = 1.0
	tor.rings = 20
	tor.ring_segments = 4
	var m := Ato2Pecas.mat_cor(Color(0.95, 0.95, 0.92, 0.7), true)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var mi := Ato2Pecas.malha(self, tor, Vector3(pos.x, -0.1, pos.z), m)
	mi.scale = Vector3(1.2, 0.2, 1.0)
	var tw := create_tween().set_parallel()
	tw.tween_property(mi, "scale", Vector3(3.4, 0.2, 2.6), 1.6).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 1.6)
	tw.chain().tween_callback(mi.queue_free)


## Com a corda esticada, o barco na água dá um tranco leve a cada passo dos bois, sem ninguém puxando.
func _empurrao_fantasma() -> void:
	var x0 := _barco.position.x
	var tw := create_tween()
	tw.tween_property(_barco, "position:x", x0 + 0.1, 0.12)
	tw.tween_property(_barco, "position:x", x0, 0.5).set_trans(Tween.TRANS_SINE)


## Todo mundo para: os homens recuam e se sentam na margem.
func _homens_param() -> void:
	_homens_sentados = true
	var tw := create_tween().set_parallel()
	for h in _homens:
		tw.tween_property(h, "scale:y", 0.58, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(h, "position:x", h.position.x - 0.5, 1.2).set_trans(Tween.TRANS_SINE)
		tw.tween_property(h, "rotation:z", 0.05, 1.2)


func _ir_para_pegada() -> void:
	var xf := _com.position.x
	var alvo := Vector3(xf + 3.7, 0.1, -4.7)
	var yaw := atan2(-((xf + 4.0) - alvo.x), -(-7.0 - alvo.z))
	var tw := create_tween().set_parallel()
	tw.tween_property(player, "global_position", alvo, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player, "rotation:y", yaw, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(player.cabeca, "rotation:x", -0.52, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


## O silêncio: a corda cai frouxa e os bois param, de uma vez, no meio de um passo.
func _parar_bois() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_fantasma_forca", 0.0, 1.1)
	tw.tween_callback(func() -> void:
		_fantasma = false
		_wig = 0.0)


## UMA pegada pequena de criança na lama, junto da corda (a pista do Tito: só sugestão).
func _mostrar_pegada() -> void:
	var xf := _com.position.x
	var centro := Vector3(xf + 4.0, 0.0, -7.0)
	var lama_mat := Ato2Pecas.mat_cor(Color(0.52, 0.47, 0.4))   # lama lisa e clara: a pegada escura se lê
	var cil := CylinderMesh.new()
	cil.top_radius = 0.42
	cil.bottom_radius = 0.42
	cil.height = 0.01
	cil.radial_segments = 14
	cil.rings = 1
	_lama = Ato2Pecas.malha(self, cil, Vector3(centro.x, 0.02, centro.z), lama_mat, Vector3.ZERO, Vector3(1.0, 1.0, 1.5))
	_lama.name = "Lama"
	_pegada = Pegada.criar(Vector3(centro.x, 0.035, centro.z), Vector3(0, 0, 1), true, 0.55, 1.8)
	_pegada.name = "PegadaTito"
	add_child(_pegada)
	Audio.sfx("sussurro", -14.0)

