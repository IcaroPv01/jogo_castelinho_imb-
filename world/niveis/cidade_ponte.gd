extends CidadeBase
## LUGAR DA CIDADE: Ponte à noite (Módulo 14). A ponte de três pistas entre Imbé e Tramandaí (fato: três pontes lado a lado,
## ~150 m, famosa pela pesca de sardinha nas margens; `docs/pesquisa/historia_imbe.md` §6) vista como terror calmo, de noite, com
## neblina leve. Aqui a ponte é comprida de brinquedo (88 m de tabuleiro) para dar tempo de ter medo. A lenda do Passo da Mãe
## Rosa (a figura branca que some quando cercada, §8) é só cenário: ninguém real, nada de crime, nada de violência.
##
## TAREFA (1 pista, `ponte_figura`): atravessar pelo lado DIREITO (leste) contando os postes. O SEXTO poste está apagado. Na grade
## perto dele a Figura deixou um fio de pesca com uma sandália de criança e um T de cabeça para baixo riscado de giz (sugestão,
## nada de corpo). Achada a pista, as luzes piscam e a Figura aparece lá no começo da ponte; volta-se ao portão e `sair()` vira
## `concluir()` (grava "cidade_ponte_feito"). Antes da pista, sair pelo portão é só sair.
##
## O QUE ASSUSTA (tudo leve, nada persegue, ninguém morre):
##   - 7 pescadores de sardinha PARADOS na grade oeste (silhuetas genéricas). Nunca se mexem enquanto estão na tela; quando saem
##     da tela (o jogador olha para outro lado) trocam de direção. A 1ª vez que o jogador passa por eles e olha para trás, todos
##     estão virados para ele: um susto leve (som + tranco + fala).
##   - um poste pisca, um está morto; a Figura Branca (`FiguraBranca`, parada) aparece longe e SOME quando o jogador a cerca
##     (olhando, a menos de DIST_FIGURA m), como no Ato II; depois de 2 sumiços some de vez.
## Orçamento: 1 Sol + 5 luzes, malhas combinadas em MultiMesh (postes, lâmpadas, brilhos, pescadores, faixas, pilares), névoa
## em vez de geometria. Teste: `tests/cidade_ponte_test.gd`.

enum Olhar { AGUA, JOGADOR, ESTRADA, FRENTE, TRAS }

const Z_TAB := 44.0                       # meia extensão do tabuleiro (o resto é terra firme)
const X_GRADE := 5.35                     # centro do parapeito (a AREA vai até ±5,8)
const ALT_GRADE := 0.94
const NIVEL_AGUA := -3.6
const Z_POSTES: Array[float] = [36.0, 24.0, 12.0, 0.0, -12.0, -24.0, -36.0]
const POSTE_PISCA := 2                    # 3º poste do lado leste pisca
const POSTE_APAGADO := 5                  # 6º poste do lado leste está morto
const PESC_Z: Array[float] = [-3.0, -5.6, -8.5, -11.2, -14.3, -17.0, -20.2]
const PESC_X := -4.5
const DIST_FIGURA := 10.0                 # olhando e mais perto que isso: ela some
const POS_PISTA := Vector3(5.15, 0.0, -24.4)     # a grade que a Figura marcou (face interna do parapeito)
const FIGURA_LONGE := Vector3(1.0, 0.0, -51.0)
const FIGURA_PORTAO := Vector3(-0.5, 0.0, 26.0)
const COR_LAMPADA := Color(1.0, 0.8, 0.45)
const SUMICOS_MAX := 2

# --- estado (público para os testes)
var figura: FiguraBranca
var postes_passados := 0
var pista_vista := false                  # a pista foi achada (nesta visita ou antes)
var sumicos := 0                          # quantas vezes a Figura sumiu na fase atual
var susto_feito := false
var pesc_yaw: Array[float] = []
var pesc_modo: Array[int] = []
var perto_do_apagado := false
var dicas := 0

var _t := 0.0
var _sem_progresso := 0.0
var _fala_pescadores := false
var _mm_pesc: MultiMesh
var _pesc_pos: Array[Vector3] = []
var _pesc_visto: Array[bool] = []
var _pesc_fora: Array[float] = []
var _pesc_espera: Array[float] = []
var _pesc_trocou: Array[bool] = []
var _mat_lampada: StandardMaterial3D
var _mat_halo: StandardMaterial3D
var _luzes: Array[OmniLight3D] = []
var _luz_energia: Array[float] = []
var _luz_pisca: OmniLight3D
var _lamp_pisca: MeshInstance3D
var _halo_pisca: MeshInstance3D
var _mat_lamp_pisca: StandardMaterial3D
var _mat_halo_pisca: StandardMaterial3D
var _pendulo: Node3D
var _boia_luz: MeshInstance3D
var _apagao := false
var _ultima_vez := false
var _lampadas_cerca: Array[MeshInstance3D] = []
var _interagivel_pista: Interagivel
var _halo_pista: MeshInstance3D
var _mat_halo_pista: StandardMaterial3D
var _prox_som_pista := 3.0


func _configurar() -> void:
	id = "ponte"
	area = Rect2(-5.8, -64.0, 11.6, 118.0)      # estreita e comprida: x de -5,8 a 5,8; z de -64 (Tramandaí) a 54 (Imbé)
	hora = Hora.NOITE
	clima = Clima.LIMPO                          # a "neblina leve" é a névoa ajustada em _construir
	spawn_pos = Vector3(0.0, 0.1, 50.0)
	spawn_yaw = 0.0                              # olhando para -z, rumo a Tramandaí; o lado direito é o leste (+x)
	corrupcao = 0.2
	ambiente_audio = "rio"


func _material_chao() -> Material:
	return mat_asfalto()


# ============================================================================ cenário
func _construir() -> void:
	_nevoa()
	_esconder_chao_base()
	_agua_e_terra()
	_tabuleiros()
	_faixas()
	_postes_e_luzes()
	_pescadores()
	_pista_visual()
	_cercas()
	_luzes_ao_longe()
	_boia()
	MinigamesCastelo.porta_em(self, "ponte")     # a porta do minigame "Um, dois, três, pescador!" (Módulo 16)


## Neblina leve: começa perto e some devagar (o resto do ambiente é o da base: noite, Lua fraca).
func _nevoa() -> void:
	env.fog_depth_begin = 8.0
	env.fog_depth_end = 115.0
	env.fog_depth_curve = 1.0
	env.fog_light_color = Color(0.1, 0.125, 0.21)


## O chão da base é uma caixa larga (colisão certa, visual errado para uma ponte): fica só a colisão.
func _esconder_chao_base() -> void:
	var chao := find_child("Chao", false, false) as MeshInstance3D
	if chao:
		chao.visible = false
	var longe := find_child("ChaoLonge", false, false)
	if longe:
		longe.queue_free()


func _agua_e_terra() -> void:
	# água escura (shader da Barra com cores da noite), só sob a ponte
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/agua.gdshader") as Shader
	m.set_shader_parameter("cor_fundo", Vector3(0.012, 0.025, 0.05))
	m.set_shader_parameter("cor_raso", Vector3(0.012, 0.025, 0.05))
	m.set_shader_parameter("cor_ceu", Vector3(0.07, 0.1, 0.19))
	m.set_shader_parameter("cor_sol", Vector3(0.45, 0.55, 0.85))
	m.set_shader_parameter("dir_sol", Vector3(0.3, 0.45, -0.85).normalized())
	m.set_shader_parameter("margem_z", -2000.0)       # sem espuma de margem
	m.set_shader_parameter("amplitude", 0.05)
	var plano := PlaneMesh.new()
	plano.size = Vector2(700.0, 2.0 * Z_TAB + 4.0)
	plano.subdivide_width = 70
	plano.subdivide_depth = 14
	Ato2Pecas.malha(self, plano, Vector3(0.0, NIVEL_AGUA, 0.0), m).name = "Agua"
	# margens: terra de areia escura nas duas cabeceiras (a água termina num barranco)
	var terra := mat_areia(0.28)
	var comp := 260.0
	for lado in [1.0, -1.0]:
		var sinal: float = lado
		var cz: float = sinal * (Z_TAB + comp * 0.5 - 0.5)
		Construtor.caixa(self, Vector3(700.0, 5.0, comp), Vector3(0.0, -2.6, cz), terra, false, "Margem")
		# estrada que continua além da cerca
		Construtor.caixa(self, Vector3(11.9, 0.1, comp), Vector3(0.0, -0.05, cz), mat_asfalto(), false, "EstradaLonge")
	# fundo do rio (para não ver o vazio por baixo da água)
	Construtor.caixa(self, Vector3(700.0, 0.2, 2.0 * Z_TAB + 4.0), Vector3(0.0, NIVEL_AGUA - 1.6, 0.0), Ato2Pecas.mat_cor(Color(0.02, 0.03, 0.04)), false, "FundoRio")


func _tabuleiros() -> void:
	var concreto := Ato2Pecas.mat_cor(Color(0.3, 0.31, 0.34))
	var escuro := Ato2Pecas.mat_cor(Color(0.12, 0.125, 0.14))
	var comp := 2.0 * Z_TAB + 0.4
	# ponte A (a do jogador): tabuleiro, viga por baixo e parapeitos com colisão
	Construtor.caixa(self, Vector3(11.9, 0.8, comp), Vector3(0.0, -0.4, 0.0), mat_asfalto(), false, "Tabuleiro")
	Construtor.caixa(self, Vector3(12.3, 0.6, comp), Vector3(0.0, -1.1, 0.0), escuro, false, "Viga")
	for lado in [-1.0, 1.0]:
		var sx: float = lado
		Construtor.caixa(self, Vector3(0.4, ALT_GRADE, comp), Vector3(sx * X_GRADE, ALT_GRADE * 0.5, 0.0), concreto, true, "Grade_%s" % ("L" if sx > 0.0 else "O"))
	# pontes B e C ao lado (o resto da "ponte de três pistas"): só para olhar
	for cx in [18.0, 31.0]:
		var x: float = cx
		Construtor.caixa(self, Vector3(11.9, 0.8, comp), Vector3(x, -0.4, 0.0), mat_asfalto(), false, "TabuleiroLado")
		Construtor.caixa(self, Vector3(12.3, 0.6, comp), Vector3(x, -1.1, 0.0), escuro, false, "VigaLado")
		for lado in [-1.0, 1.0]:
			var sx2: float = lado
			Construtor.caixa(self, Vector3(0.4, ALT_GRADE, comp), Vector3(x + sx2 * X_GRADE, ALT_GRADE * 0.5, 0.0), concreto, false, "GradeLado")
	# pilares (uma MultiMesh só) dentro d'água
	var trs: Array[Transform3D] = []
	for cx in [0.0, 18.0, 31.0]:
		for z in [-36.0, -18.0, 0.0, 18.0, 36.0]:
			for dx in [-2.6, 2.6]:
				trs.append(Transform3D(Basis.from_scale(Vector3(1.5, 3.3, 1.7)), Vector3(float(cx) + float(dx), -2.55, float(z))))
	var cubo := BoxMesh.new()
	_multi(cubo, escuro, trs, "Pilares")


func _faixas() -> void:
	# faixa central tracejada e bordas da pista (a ponte A)
	var tracos: Array[Transform3D] = []
	var z := Z_TAB - 2.0
	while z > -Z_TAB + 1.0:
		tracos.append(Transform3D(Basis(), Vector3(0.0, 0.015, z)))
		z -= 4.0
	var tr := BoxMesh.new()
	tr.size = Vector3(0.16, 0.02, 1.8)
	_multi(tr, Ato2Pecas.mat_cor(Color(0.5, 0.45, 0.22)), tracos, "FaixaCentral")
	var bordas: Array[Transform3D] = []
	for sx in [-4.15, 4.15]:
		bordas.append(Transform3D(Basis(), Vector3(float(sx), 0.015, 0.0)))
	var br := BoxMesh.new()
	br.size = Vector3(0.12, 0.02, 2.0 * Z_TAB)
	_multi(br, Ato2Pecas.mat_cor(Color(0.42, 0.43, 0.45)), bordas, "FaixaBorda")


# ============================================================================ postes e luzes
func _malha_caixas(itens: Array) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for it: Array in itens:
		var bm := BoxMesh.new()
		bm.size = it[0]
		st.append_from(bm, 0, Transform3D(Basis(), it[1]))
	return st.commit()


func _postes_e_luzes() -> void:
	# poste: haste + braço + caixa da lâmpada (o braço aponta para -x; o lado oeste gira 180°)
	var poste_mesh := _malha_caixas([
		[Vector3(0.18, 6.2, 0.18), Vector3(0, 3.1, 0)],
		[Vector3(1.6, 0.1, 0.12), Vector3(-0.7, 6.15, 0)],
		[Vector3(0.6, 0.14, 0.3), Vector3(-1.35, 6.05, 0)]])
	var ferro := Ato2Pecas.mat_cor(Color(0.17, 0.18, 0.2))
	var painel := BoxMesh.new()
	painel.size = Vector3(0.5, 0.04, 0.24)
	_mat_lampada = Ato2Pecas.mat_cor(COR_LAMPADA, true)
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_mat_halo = _material_halo(Color(1.0, 0.72, 0.38, 0.5))
	var poste_t: Array[Transform3D] = []
	var lamp_t: Array[Transform3D] = []
	var halo_t: Array[Transform3D] = []
	for cx in [0.0, 18.0, 31.0]:
		var x0: float = cx
		for lado in [1.0, -1.0]:
			var sx: float = lado
			var base := Basis(Vector3.UP, 0.0 if sx > 0.0 else PI)
			for i in Z_POSTES.size():
				var z: float = Z_POSTES[i]
				var origem := Vector3(x0 + sx * X_GRADE, 0.0, z)
				poste_t.append(Transform3D(base, origem))
				var lampada := origem + base * Vector3(-1.35, 5.96, 0.0)
				if x0 == 0.0 and sx > 0.0 and (i == POSTE_APAGADO or i == POSTE_PISCA):
					continue            # o morto não acende; o que pisca é uma peça separada
				lamp_t.append(Transform3D(base, lampada))
				halo_t.append(Transform3D(Basis.from_scale(Vector3(3.2, 3.2, 3.2)), lampada + Vector3(0, -0.15, 0)))
	_multi(poste_mesh, ferro, poste_t, "Postes")
	_multi(painel, _mat_lampada, lamp_t, "Lampadas")
	_multi(quad, _mat_halo, halo_t, "Brilhos")
	# o poste que pisca: lâmpada e brilho próprios (material separado) e uma luz de verdade
	var zp: float = Z_POSTES[POSTE_PISCA]
	var pos_pisca := Vector3(X_GRADE - 1.35, 5.96, zp)
	_mat_lamp_pisca = Ato2Pecas.mat_cor(COR_LAMPADA, true)
	_lamp_pisca = Ato2Pecas.malha(self, painel, pos_pisca, _mat_lamp_pisca)
	_lamp_pisca.name = "LampadaPisca"
	_mat_halo_pisca = _material_halo(Color(1.0, 0.72, 0.38, 0.5))
	_halo_pisca = Ato2Pecas.malha(self, quad, pos_pisca + Vector3(0, -0.15, 0), _mat_halo_pisca, Vector3.ZERO, Vector3(3.2, 3.2, 3.2))
	_halo_pisca.name = "BrilhoPisca"
	_luz_pisca = Construtor.luz(self, pos_pisca + Vector3(0, -0.5, 0), COR_LAMPADA, 1.8, 20.0)
	_luz_pisca.name = "LuzPisca"
	# mais 4 luzes fracas, espalhadas: o resto da ponte fica em penumbra (só o brilho das lâmpadas)
	var fixas := [Vector3(X_GRADE - 1.35, 5.5, Z_POSTES[0]), Vector3(-X_GRADE + 1.35, 5.5, Z_POSTES[2]),
		Vector3(-X_GRADE + 1.35, 5.5, Z_POSTES[4]), Vector3(X_GRADE - 1.35, 5.5, Z_POSTES[6])]
	for p: Vector3 in fixas:
		var l := Construtor.luz(self, p, COR_LAMPADA, 1.6, 20.0)
		_luzes.append(l)
		_luz_energia.append(1.6)


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


## MultiMeshInstance3D com uma lista de transformações: um desenho para centenas de peças.
func _multi(mesh: Mesh, mat: Material, trs: Array[Transform3D], nome: String) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = trs.size()
	for i in trs.size():
		mm.set_instance_transform(i, trs[i])
	var mi := MultiMeshInstance3D.new()
	mi.name = nome
	mi.multimesh = mm
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ============================================================================ pescadores
func _malha_pescador() -> ArrayMesh:
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
	aba.size = Vector3(0.22, 0.02, 0.16)
	st.append_from(aba, 0, Transform3D(Basis(), Vector3(0, 1.82, -0.17)))
	var braco := CapsuleMesh.new()
	braco.radius = 0.055
	braco.height = 0.75
	braco.radial_segments = 6
	braco.rings = 2
	for sx in [0.24, -0.24]:
		st.append_from(braco, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(-65.0)), Vector3(float(sx), 1.22, -0.25)))
	var vara := BoxMesh.new()
	vara.size = Vector3(0.025, 0.025, 3.4)
	st.append_from(vara, 0, Transform3D(Basis(Vector3.RIGHT, deg_to_rad(24.0)), Vector3(0.2, 1.85, -1.75)))
	var balde := CylinderMesh.new()
	balde.top_radius = 0.17
	balde.bottom_radius = 0.14
	balde.height = 0.32
	balde.radial_segments = 8
	st.append_from(balde, 0, Transform3D(Basis(), Vector3(-0.55, 0.16, 0.1)))
	return st.commit()


func _pescadores() -> void:
	var trs: Array[Transform3D] = []
	for i in PESC_Z.size():
		var p := Vector3(PESC_X + (0.4 if i % 2 == 1 else 0.0), 0.0, PESC_Z[i])
		_pesc_pos.append(p)
		pesc_yaw.append(PI * 0.5)           # de costas para a estrada, rosto e vara para a água (oeste)
		pesc_modo.append(Olhar.AGUA)
		_pesc_visto.append(false)
		_pesc_fora.append(0.0)
		_pesc_espera.append(randf_range(0.8, 2.2))
		_pesc_trocou.append(false)
		trs.append(Transform3D())
	var mat := Ato2Pecas.mat_cor(Color(0.13, 0.145, 0.2))
	var mi := _multi(_malha_pescador(), mat, trs, "Pescadores")
	_mm_pesc = mi.multimesh
	_aplicar_pescadores()


func _aplicar_pescadores() -> void:
	for i in _pesc_pos.size():
		var esc := 0.96 + 0.05 * float(i % 3)
		_mm_pesc.set_instance_transform(i, Transform3D(Basis(Vector3.UP, pesc_yaw[i]).scaled(Vector3(esc, esc, esc)), _pesc_pos[i]))


func _yaw_modo(i: int, modo: int) -> float:
	match modo:
		Olhar.AGUA:
			return PI * 0.5 + randf_range(-0.2, 0.2)
		Olhar.ESTRADA:
			return -PI * 0.5 + randf_range(-0.3, 0.3)
		Olhar.FRENTE:
			return randf_range(-0.25, 0.25)
		Olhar.TRAS:
			return PI + randf_range(-0.25, 0.25)
		_:
			var d := _pesc_pos[i] - player.global_position
			return atan2(d.x, d.z)         # de frente para o jogador: -sen(yaw), -cos(yaw) = direção para ele


func _passou_pescadores() -> bool:
	return player != null and player.global_position.z < PESC_Z[PESC_Z.size() - 1] - 1.0


func _virar_pescador(i: int) -> void:
	var modo: int
	if not susto_feito and _passou_pescadores():
		modo = Olhar.JOGADOR                  # a 1ª vez que você passa e eles saem da tela: todos viram para você
	else:
		var sorteio := randf()
		if sorteio < 0.38:
			modo = Olhar.AGUA
		elif sorteio < 0.62:
			modo = Olhar.ESTRADA
		elif sorteio < 0.82:
			modo = Olhar.JOGADOR
		elif sorteio < 0.92:
			modo = Olhar.FRENTE
		else:
			modo = Olhar.TRAS
		if modo == pesc_modo[i]:
			modo = (modo + 1) % 5
	pesc_modo[i] = modo
	pesc_yaw[i] = _yaw_modo(i, modo)
	var esc := 0.96 + 0.05 * float(i % 3)
	_mm_pesc.set_instance_transform(i, Transform3D(Basis(Vector3.UP, pesc_yaw[i]).scaled(Vector3(esc, esc, esc)), _pesc_pos[i]))


func _atualizar_pescadores(dt: float) -> void:
	var cam := player.camera
	if cam == null:
		return
	for i in _pesc_pos.size():
		var ponto := _pesc_pos[i] + Vector3(0, 1.2, 0)
		var d: float = player.global_position.distance_to(ponto)
		var visto: bool = d < 75.0 and cam.is_position_in_frustum(ponto)
		if visto:
			if not _pesc_visto[i]:
				_ao_ver_pescador(i, d)
			_pesc_visto[i] = true
			_pesc_fora[i] = 0.0
			_pesc_trocou[i] = false
		else:
			_pesc_visto[i] = false
			_pesc_fora[i] += dt
			if not _pesc_trocou[i] and _pesc_fora[i] >= _pesc_espera[i]:
				_pesc_trocou[i] = true
				_pesc_espera[i] = randf_range(0.8, 2.4)
				_virar_pescador(i)


func _ao_ver_pescador(i: int, d: float) -> void:
	if susto_feito or pesc_modo[i] != Olhar.JOGADOR or d > 34.0 or not _passou_pescadores():
		return
	susto_feito = true
	Audio.sfx("susto", -9.0)
	Efeitos.pulso(0.3, 0.35)
	Guia.falar("bentinho", ["Tainá... eles não estavam olhando pra água?"])
	Guia.falar("taina", ["Não olha. Só anda. Eles nunca fizeram nada com ninguém."])
	_sem_progresso = 0.0


# ============================================================================ pista no parapeito
func _pista_visual() -> void:
	var giz := Ato2Pecas.mat_cor(Color(0.9, 0.93, 0.95), true)
	# T de cabeça para baixo (⊥) em giz na face interna do parapeito
	var x := POS_PISTA.x - 0.006
	var z := POS_PISTA.z
	Construtor.caixa(self, Vector3(0.012, 0.07, 0.62), Vector3(x, 0.4, z), giz, false, "GizBase")
	Construtor.caixa(self, Vector3(0.012, 0.5, 0.07), Vector3(x, 0.66, z), giz, false, "GizHaste")
	# fio de pesca com boia e uma sandália de criança, pendurado numa vara esquecida sobre a grade
	var zf := POS_PISTA.z + 1.1
	var vara := Ato2Pecas.mat_cor(Color(0.1, 0.1, 0.12))
	Construtor.caixa(self, Vector3(0.9, 0.03, 0.03), Vector3(5.3, ALT_GRADE + 0.03, zf), vara, false, "VaraEsquecida")
	_pendulo = Node3D.new()
	_pendulo.name = "Fio"
	_pendulo.position = Vector3(4.9, ALT_GRADE + 0.02, zf)
	add_child(_pendulo)
	var linha := Ato2Pecas.mat_cor(Color(0.8, 0.85, 0.9), true)
	Construtor.caixa(_pendulo, Vector3(0.008, 0.75, 0.008), Vector3(0, -0.375, 0), linha, false, "Linha")
	var boia := SphereMesh.new()
	boia.radius = 0.06
	boia.height = 0.12
	Ato2Pecas.malha(_pendulo, boia, Vector3(0, -0.12, 0), Ato2Pecas.mat_cor(Color(0.85, 0.2, 0.18), true)).name = "Boia"
	var sandalia := Ato2Pecas.mat_cor(Color(0.95, 0.48, 0.4), true)
	Construtor.caixa(_pendulo, Vector3(0.09, 0.2, 0.025), Vector3(0, -0.85, 0), sandalia, false, "Sandalia")
	Construtor.caixa(_pendulo, Vector3(0.1, 0.03, 0.03), Vector3(0, -0.77, 0.01), Ato2Pecas.mat_cor(Color(0.4, 0.2, 0.2), true), false, "Tira")
	# brilho frio pulsando sobre o fio e o giz: chama o olho de longe (some devagar depois de achada)
	_mat_halo_pista = _material_halo(Color(0.62, 0.86, 1.0, 0.7))
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_halo_pista = Ato2Pecas.malha(self, quad, Vector3(POS_PISTA.x - 0.4, 0.62, POS_PISTA.z + 0.5), _mat_halo_pista, Vector3.ZERO, Vector3(3.4, 3.4, 3.4))
	_halo_pista.name = "BrilhoPista"
	_interagivel_pista = Interagivel.new("Examinar a grade", Vector3(1.6, 1.8, 3.4), func(_p: Node) -> void: _examinar_grade())
	_interagivel_pista.name = "PistaGrade"
	_interagivel_pista.position = Vector3(POS_PISTA.x - 0.5, 0.9, POS_PISTA.z + 0.5)
	add_child(_interagivel_pista)


# ============================================================================ cercas, luzes longe, boia
func _cercas() -> void:
	var vermelho := Ato2Pecas.mat_cor(Color(0.72, 0.16, 0.1))
	var branco := Ato2Pecas.mat_cor(Color(0.78, 0.78, 0.74))
	var ambar := Ato2Pecas.mat_cor(Color(1.0, 0.6, 0.1), true)
	# duas cercas de obra fecham as pontas (a de Tramandaí e a de Imbé, atrás do Spawn); `dir` = lado de quem olha
	for par in [[area.end.y - 1.8, -1.0], [area.position.y + 3.0, 1.0]]:
		var zz: float = par[0]
		var dir: float = par[1]
		for k in 3:
			Construtor.caixa(self, Vector3(11.6, 0.2, 0.07), Vector3(0.0, 0.45 + k * 0.28, zz + dir * 0.09), vermelho if k % 2 == 0 else branco, true, "Cerca")
		for sx in [-5.4, 0.0, 5.4]:
			Construtor.caixa(self, Vector3(0.1, 1.3, 0.1), Vector3(float(sx), 0.65, zz), branco, false, "CercaPe")
		for sx in [-5.4, 5.4]:
			var l := Construtor.caixa(self, Vector3(0.16, 0.16, 0.16), Vector3(float(sx), 1.38, zz), ambar, false, "CercaLuz")
			_lampadas_cerca.append(l)
		var placa := Construtor.rotulo(self, "OBRAS", Vector3(0.0, 0.73, zz + dir * 0.15), 90, Color(1, 0.92, 0.7))
		placa.double_sided = false
		placa.rotation.y = 0.0 if dir > 0.0 else PI


func _luzes_ao_longe() -> void:
	# luzes da cidade nas duas margens (só brilhos, bem longe, dentro da névoa)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1967
	var trs: Array[Transform3D] = []
	for i in 34:
		var lado := 1.0 if i % 2 == 0 else -1.0
		var p := Vector3(rng.randf_range(-160.0, 160.0), rng.randf_range(0.6, 3.5), lado * rng.randf_range(80.0, 150.0))
		if absf(p.x) < 12.0:
			p.x += 24.0 * signf(p.x + 0.01)
		var s := rng.randf_range(1.2, 2.4)
		trs.append(Transform3D(Basis.from_scale(Vector3(s, s, s)), p))
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	_multi(quad, _material_halo(Color(1.0, 0.82, 0.55, 0.45)), trs, "LuzesLonge")


func _boia() -> void:
	var s := SphereMesh.new()
	s.radius = 0.35
	s.height = 0.7
	_boia_luz = Ato2Pecas.malha(self, s, Vector3(-32.0, NIVEL_AGUA + 0.1, -10.0), Ato2Pecas.mat_cor(Color(1.0, 0.1, 0.08), true, 1.0))
	_boia_luz.name = "BoiaSinal"


# ============================================================================ tarefa
func _tarefa() -> void:
	susto_feito = false
	pista_vista = GameState.flag("pista_ponte_figura")
	figura = FiguraBranca.new()
	figura.name = "FiguraBranca"
	figura.ativa = false                     # parada: só some quando cercada olhando
	figura.distancia_cercar = DIST_FIGURA
	figura.tempo_reaparecer = 1.4
	add_child(figura)
	figura.alvo = player
	figura.sumiu.connect(_ao_figura_sumiu)
	figura.reapareceu.connect(_ao_figura_reapareceu)
	if pista_vista:
		_figura_no_portao()
	else:
		_figura_no_fim()
	_atualizar_objetivo()
	if not pista_vista:
		get_tree().create_timer(1.2).timeout.connect(_fala_inicial)


func _fala_inicial() -> void:
	if not is_inside_tree() or postes_passados > 0 or pista_vista:
		return
	Guia.falar("taina", ["Essa é a ponte entre Imbé e Tramandaí. São três lado a lado.",
		"De dia tem pescador de sardinha em toda a grade. De noite... eles ficam. Só ficam.",
		"O Tito passou por aqui. Vai pelo lado direito e conta os postes. O sexto está apagado.",
		"A Figura Branca deixou alguma coisa na grade, perto dele."])
	Guia.falar("bentinho", ["Eu não gosto de ponte à noite. Vai você na frente?"])


func _figura_no_fim() -> void:
	sumicos = 0
	_ultima_vez = false
	figura.pontos_reaparecer = [Vector3(-1.5, 0.0, -58.0), Vector3(1.5, 0.0, -60.0)]
	figura.teleportar(FIGURA_LONGE)


func _figura_no_portao() -> void:
	sumicos = 0
	_ultima_vez = false
	figura.pontos_reaparecer = [Vector3(1.0, 0.0, 38.0), Vector3(-1.0, 0.0, 41.0)]
	figura.teleportar(FIGURA_PORTAO)


func _ao_figura_sumiu(_onde: Vector3) -> void:
	sumicos += 1
	if sumicos >= SUMICOS_MAX:
		_ultima_vez = true          # ela reaparece ao longe (mesmo quadro) e some de vez
	_sem_progresso = 0.0


func _ao_figura_reapareceu(_onde: Vector3) -> void:
	if _ultima_vez:
		figura.esconder()


func _texto_dinamico() -> String:
	if GameState.cidade_feita(id):
		return "Aqui está tudo certo. Volte ao Castelinho pelo portão."
	if pista_vista:
		return "Volte pela ponte até o portão do começo (Voltar ao Castelinho)."
	if perto_do_apagado:
		return "Examine a grade perto do poste apagado (E): o fio e o T de giz."
	if postes_passados >= POSTE_APAGADO:
		return "O próximo poste do lado direito é o apagado. Olhe a grade perto dele."
	return "Atravesse a ponte pelo lado direito, contando os postes. O sexto está apagado. (Passou por %d.)" % postes_passados


func _atualizar_objetivo() -> void:
	definir_objetivo(_texto_dinamico())


func _texto_objetivo() -> String:
	return _texto_dinamico()


func _examinar_grade() -> void:
	if _apagao:
		return
	Audio.sfx("pista")
	var nova: bool = await pista("ponte_figura", [])
	pista_vista = true
	_atualizar_objetivo()
	_sem_progresso = 0.0
	Efeitos.pulso(0.3, 0.3)
	if nova:
		Guia.falar("taina", ["Um fio de pesca amarrado na vara, com uma boia vermelha.",
			"E na ponta... uma sandália de criança. Pequena.",
			"E no muro um T de giz. De cabeça para baixo.",
			"A Figura deixou isso aqui pro Tito seguir."])
		Guia.falar("bentinho", ["Vamos embora daqui? O portão fica lá no começo da ponte."])
	else:
		Guia.falar("sistema", ["Um fio, uma sandália pequena e um T de cabeça para baixo, em giz."])
	var tw := create_tween()
	tw.tween_interval(1.6)
	tw.tween_callback(_apagao_e_figura)


## As luzes caem por um instante; quando voltam, a Figura está lá no começo da ponte, no caminho do portão.
func _apagao_e_figura() -> void:
	_apagao = true
	_acender(false)
	Audio.sfx("chiado_radio", -6.0)
	var tw := create_tween()
	tw.tween_interval(0.5)
	tw.tween_callback(_acender.bind(true))
	tw.tween_interval(0.25)
	tw.tween_callback(_acender.bind(false))
	tw.tween_interval(0.2)
	tw.tween_callback(func() -> void:
		_apagao = false
		_acender(true)
		_figura_no_portao()
		Guia.falar("taina", ["Olha lá no portão... é ela. Ela some quando a gente chega perto, lembra?"]))


func _acender(ligado: bool) -> void:
	_mat_lampada.albedo_color = COR_LAMPADA if ligado else Color(0.02, 0.02, 0.025)
	_mat_halo.albedo_color = Color(1.0, 0.72, 0.38, 0.5) if ligado else Color(1.0, 0.72, 0.38, 0.0)
	for i in _luzes.size():
		_luzes[i].light_energy = _luz_energia[i] if ligado else 0.0


# ============================================================================ quadro a quadro
func _physics_process(dt: float) -> void:
	_t += dt
	_pisca_poste()
	_animar_detalhes()
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	_atualizar_pescadores(dt)
	_vigiar_progresso(dt)


func _pisca_poste() -> void:
	var ciclo := fmod(_t, 6.0)
	var ligado := not ((ciclo > 4.4 and ciclo < 5.1 and sin(_t * 41.0) > -0.3) or (ciclo > 1.3 and ciclo < 1.42))
	if _apagao:
		ligado = false
	_mat_lamp_pisca.albedo_color = COR_LAMPADA if ligado else Color(0.02, 0.02, 0.025)
	_mat_halo_pisca.albedo_color = Color(1.0, 0.72, 0.38, 0.5) if ligado else Color(1.0, 0.72, 0.38, 0.0)
	_luz_pisca.light_energy = 1.8 if ligado else 0.0


func _animar_detalhes() -> void:
	if _pendulo:
		_pendulo.rotation.z = sin(_t * 1.4) * 0.1
		_pendulo.rotation.x = sin(_t * 0.9 + 1.0) * 0.06
	if _mat_halo_pista:
		var a := 0.0 if pista_vista else 0.45 + 0.3 * sin(_t * 2.2)
		_mat_halo_pista.albedo_color = Color(0.62, 0.86, 1.0, a)
		if player and not pista_vista and _t > _prox_som_pista:
			_prox_som_pista = _t + 8.0
			if player.global_position.distance_to(POS_PISTA) < 40.0:
				Audio.sfx_3d("chiado_radio", POS_PISTA + Vector3(-0.3, 1.0, 0.0), -12.0)      # som direcional vindo da grade
	if _boia_luz:
		_boia_luz.visible = fmod(_t, 2.2) < 0.7
	var ambar := fmod(_t, 1.2) < 0.6
	for l in _lampadas_cerca:
		l.visible = ambar


func _vigiar_progresso(dt: float) -> void:
	var p := player.global_position
	_sem_progresso += dt
	while postes_passados < Z_POSTES.size() and p.z < Z_POSTES[postes_passados] - 0.5:
		postes_passados += 1
		_ao_passar_poste(postes_passados)
	var d_apagado: float = Vector2(p.x - POS_PISTA.x, p.z - POS_PISTA.z).length()
	var perto := d_apagado < 6.5 and not pista_vista
	if perto != perto_do_apagado:
		perto_do_apagado = perto
		_atualizar_objetivo()
		if perto:
			_sem_progresso = 0.0
			Guia.falar("taina", ["É este o poste apagado! Procura na grade, bem perto dele."])
	if not _fala_pescadores and absf(p.z - PESC_Z[0]) < 16.0 and p.z > PESC_Z[0] and not pista_vista:
		_fala_pescadores = true
		Guia.falar("bentinho", ["Pescadores de sardinha! Boa noite? ...Eles nem se mexem."])
	if _sem_progresso > 60.0:
		_sem_progresso = 0.0
		_dar_dica()


func _ao_passar_poste(n: int) -> void:
	_sem_progresso = 0.0
	Audio.sfx("clique", -3.0, 0.8 + 0.07 * float(n))
	_atualizar_objetivo()
	if n == POSTE_PISCA + 1:
		Efeitos.aviso("Poste %d (piscando)" % n, 1.6)
		if not pista_vista:
			Guia.falar("bentinho", ["Esse poste está piscando... deve ser mau contato. Deve ser."])
	elif n == POSTE_APAGADO:
		Efeitos.aviso("Poste %d" % n, 1.4)
		if not pista_vista:
			Guia.falar("taina", ["O próximo é o apagado. Fica bem escuro ali."])
	elif n == POSTE_APAGADO + 1:
		Efeitos.aviso("Poste %d (apagado)" % n, 1.8)
	else:
		Efeitos.aviso("Poste %d" % n, 1.2)


func _dar_dica() -> void:
	if Guia.ocupado():
		return
	dicas += 1
	if pista_vista:
		Guia.falar("taina", ["O portão do começo da ponte é o caminho de volta. Pode ir sem pressa."])
	elif postes_passados >= POSTE_APAGADO:
		Guia.falar("taina", ["Procura a grade do lado direito, perto do poste sem luz. Tem um brilho azulado e um risco de giz branco."])
	else:
		Guia.falar("taina", ["Vai pelo lado direito da ponte e conta os postes. O sexto está sem luz."])


# ============================================================================ saída
## Antes da pista, o portão é só sair. Com a pista achada, voltar ao portão conclui o lugar.
func sair() -> void:
	if not _saindo and GameState.flag("pista_ponte_figura"):
		concluir()
	else:
		super.sair()
