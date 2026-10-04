extends Node3D
## Ato II — "Informações Atualizadas" (salas 26 a 30). Tudo montado por código.
##
##  26  O hall errado (a sala 7 de novo, mas errada): reboco, lustre balançando, painel corrompido.
##  27  A porta do hall abre para 1950: o núcleo original sozinho nas dunas, vento, céu cinza.
##      Longe, numa duna, uma Figura Branca parada. Some se o jogador a cerca olhando.
##  28  Dentro do núcleo de 1950 (casa de pedra de dois volumes, chaminé): primeira ameaça real.
##  29  A arcada repetida (8 módulos de arcos abatidos sobre pilares quadrados): perseguição.
##  30  A porta da Sala Medieval, fora de lugar. Ao abrir: tela preta, voz corrompida, FIM DA DEMO.
##
## Marcadores: Spawn e Checkpoint_26 (hall). Marcadores de câmera para captura: Cam_26 .. Cam_30.
## O Visor do Tempo fica instalado (Visor.instalar). Épocas: o hall só existe fora de 1950; ao
## cruzar a porta a época vira 1950 e o Visor "trava" (a época não volta ao soltar Q).
##
## Morte: Morte.mostrar() da UI (ui/morte.tscn) e volta ao Checkpoint_26 sem recarregar o nível.
## Fim da demo (sala 30): tela preta própria (camada 15, abaixo do Guia), voz corrompida do Bentinho
## (Guia.falar_engasgado) e FimDemo.mostrar() (ui/fim_demo.tscn: estatísticas e "Voltar ao início").

const Z_PORTA_HALL := -14.25
const CASA_Z_FRENTE := -72.5
const CASA_Z_FUNDO := -77.5
const ARC_Z0 := -77.7           # início da arcada (face de trás da casa)
const ARC_BAIA := 5.5           # comprimento de cada módulo
const ARC_N := 8                # módulos repetidos
const ARC_X_ESQ := -4.0         # eixo dos pilares (lado aberto)
const ARC_XC := -1.8            # eixo do corredor
const VEL_FIGURA_CASA := 2.0
const VEL_FIGURA_ARCADA := 4.0

## Ambientes por área: o céu/névoa/luz mudam de uma sala para outra.
const AMBIENTES := {
	"hall": {"bg": Color(0.04, 0.035, 0.04), "amb": Color(0.62, 0.48, 0.40), "amb_e": 0.7,
		"fog": Color(0.07, 0.06, 0.06), "fb": 6.0, "fe": 45.0, "sol": 0.0},
	"hall_aberto": {"bg": Color(0.5, 0.51, 0.53), "amb": Color(0.66, 0.58, 0.52), "amb_e": 0.8,
		"fog": Color(0.5, 0.51, 0.53), "fb": 18.0, "fe": 95.0, "sol": 0.2},
	"dunas": {"bg": Color(0.62, 0.63, 0.65), "amb": Color(0.72, 0.73, 0.76), "amb_e": 0.95,
		"fog": Color(0.62, 0.63, 0.65), "fb": 25.0, "fe": 105.0, "sol": 0.4},
	"casa": {"bg": Color(0.06, 0.06, 0.08), "amb": Color(0.40, 0.42, 0.50), "amb_e": 0.55,
		"fog": Color(0.07, 0.07, 0.09), "fb": 4.0, "fe": 34.0, "sol": 0.0},
	"arcada": {"bg": Color(0.08, 0.03, 0.03), "amb": Color(0.52, 0.34, 0.30), "amb_e": 0.6,
		"fog": Color(0.12, 0.05, 0.05), "fb": 4.0, "fe": 42.0, "sol": 0.0},
}

var player: Player
var figura: FiguraBranca
var env: Environment
var sol: DirectionalLight3D

var _t := 0.0
var _raiz_hall: Node3D
var _pivo_porta_e: Node3D
var _pivo_porta_d: Node3D
var _porta_hall_aberta := false
var _lustre: Node3D
var _luz_lustre: OmniLight3D
var _luz_lareira: OmniLight3D
var _luzes_arcada: Array[OmniLight3D] = []
var _fator_luz := 1.0
var _ambiente_atual := "hall"
var _tween_amb: Tween
var _vento: CPUParticles3D
var _em_dunas := false
var _chase_ativo := false
var _apagando := false
var _prox_apagao := 0.0
var _morrendo := false
var _fim := false
var _pivo_final_e: Node3D
var _pivo_final_d: Node3D
var _interagivel_final: Interagivel
var _visitou := {}
var _cena_fim: FimDemo
var _tween_lustre: Tween

# materiais
var m_pedra: StandardMaterial3D
var m_pedra_cinza: StandardMaterial3D
var m_piso: StandardMaterial3D
var m_madeira: StandardMaterial3D
var m_reboco: StandardMaterial3D
var m_areia: StandardMaterial3D
var m_telha: StandardMaterial3D
var m_ferro: StandardMaterial3D
var m_papelao: StandardMaterial3D


func _ready() -> void:
	_materiais()
	_ambiente_inicial()
	_terreno()
	_dunas_extras()
	_hall()
	_casa()
	_arcada()
	_porta_final()
	_sala_medieval()
	_triggers()
	_marcadores()
	_criar_figura()
	_criar_vento()


# ============================================================================ contrato com o Main
## Chamado pelo Main depois de colocar o jogador no marcador.
func iniciar(p: Player) -> void:
	player = p
	figura.alvo = p
	Visor.instalar(self)
	_vento.reparent(p, false)
	_vento.position = Vector3(0, 1.2, 0)
	_resetar_estado()
	GameState.set_flag("epoca_visor", GameState.Epoca.E1950)
	Guia.falar("bentinho", [
		"Desculpe! Dados desatualizados!",
		"Estamos atualizando as informações... por favor, aguarde.",
		"Esta sala é a mesma de antes. (Não é?)"])


## Morte: fade vermelho, tela de morte (ui/morte.tscn, se existir) e volta ao Checkpoint_26.
func ao_morrer() -> void:
	if _morrendo:
		return
	_morrendo = true
	if player:
		player.pode_mover = false
	await Transicao.fade_out(0.25, Color(0.45, 0.0, 0.0))
	await _tela_morte()
	_resetar_estado()
	_reposicionar_jogador()
	await Transicao.fade_in(0.9)
	_morrendo = false


## Mostra a tela de morte da UI (Morte.mostrar) e espera o jogador continuar.
func _tela_morte() -> void:
	var m := Morte.mostrar("figura_branca")
	await m.terminou


func _reposicionar_jogador() -> void:
	var cp := get_node("Checkpoint_26") as Node3D
	player.global_transform = cp.global_transform
	player.velocity = Vector3.ZERO
	player.cabeca.rotation.x = 0.0
	player.pode_mover = true


## Põe tudo como no começo do Ato II (usado em iniciar e depois de morrer).
func _resetar_estado() -> void:
	_chase_ativo = false
	_apagando = false
	_fator_luz = 1.0
	_em_dunas = false
	_visitou.clear()
	_vento.emitting = false
	Audio.ambiente("", -8.0, 0.5)
	GameState.set_flag("visor_travado", false)
	GameState.trocar_epoca(GameState.Epoca.E2020)
	Efeitos.visor(false)
	_fechar_porta_hall()
	figura.reiniciar(_pos_duna_figura(), false)
	figura.velocidade = VEL_FIGURA_CASA
	figura.reaparecer_fn = Callable()
	figura.pontos_reaparecer = _pontos_reaparecer_dunas()
	figura.pontos_caminho = []
	_ambiente("hall", 0.0)
	GameState.entrar_sala(26)


# ============================================================================ materiais e ambiente
func _materiais() -> void:
	# Usa as texturas do agente do castelinho quando existem (escala física: tools/gerar_texturas.py);
	# senão, as procedurais de Ato2Pecas.
	var t_pedra := Ato2Pecas.externa("pedra_castelinho")
	var e_pedra := 1.0
	if t_pedra == null:
		t_pedra = Ato2Pecas.externa("parede_castelinho")
		e_pedra = 1.0 / 1.48
	if t_pedra == null:
		t_pedra = Ato2Pecas.tex_pedra()
		e_pedra = 1.0
	var t_piso := Ato2Pecas.externa("piso_pedra")
	var t_areia := Ato2Pecas.externa("areia_1950")
	var t_telha := Ato2Pecas.externa("fibrocimento")
	m_pedra = Ato2Pecas.mat_tri("pedra", Color.WHITE, t_pedra, e_pedra)
	m_pedra_cinza = Ato2Pecas.mat_tri("pedra_cinza", Color(0.62, 0.62, 0.66), t_pedra, e_pedra * 0.8)
	m_piso = Ato2Pecas.mat_tri("piso", Color.WHITE, t_piso if t_piso else Ato2Pecas.tex_piso_pedra(), 0.5 if t_piso else 0.35)
	m_madeira = Ato2Pecas.mat_tri("madeira", Color.WHITE, Ato2Pecas.tex_madeira(), 0.7)
	m_reboco = Ato2Pecas.mat_tri("reboco", Color.WHITE, Ato2Pecas.tex_reboco(), 0.4)
	m_areia = Ato2Pecas.mat_tri("areia", Color.WHITE, t_areia if t_areia else Ato2Pecas.tex_areia(), 0.5 if t_areia else 0.18, 1.0)
	m_telha = Ato2Pecas.mat_tri("telha", Color.WHITE, t_telha if t_telha else Ato2Pecas.tex_telha(), 1.0 / 1.416 if t_telha else 1.2)
	m_ferro = Ato2Pecas.mat_cor(Color(0.1, 0.1, 0.11))
	m_papelao = Ato2Pecas.mat_cor(Color(0.78, 0.64, 0.46))


func _ambiente_inicial() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_depth_curve = 1.0
	we.environment = env
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.rotation_degrees = Vector3(-48, 35, 0)
	sol.light_color = Color(0.85, 0.87, 0.95)
	sol.shadow_enabled = false
	add_child(sol)
	_ambiente("hall", 0.0)


## Muda céu, névoa e luz ambiente para o preset `nome` em `dur` segundos.
func _ambiente(nome: String, dur := 1.5) -> void:
	_ambiente_atual = nome
	var a: Dictionary = AMBIENTES[nome]
	if _tween_amb and _tween_amb.is_valid():
		_tween_amb.kill()
	if dur <= 0.0:
		env.background_color = a["bg"]
		env.ambient_light_color = a["amb"]
		env.ambient_light_energy = a["amb_e"]
		env.fog_light_color = a["fog"]
		env.fog_depth_begin = a["fb"]
		env.fog_depth_end = a["fe"]
		sol.light_energy = a["sol"]
		return
	_tween_amb = create_tween().set_parallel()
	_tween_amb.tween_property(env, "background_color", a["bg"], dur)
	_tween_amb.tween_property(env, "ambient_light_color", a["amb"], dur)
	_tween_amb.tween_property(env, "ambient_light_energy", a["amb_e"], dur)
	_tween_amb.tween_property(env, "fog_light_color", a["fog"], dur)
	_tween_amb.tween_property(env, "fog_depth_begin", a["fb"], dur)
	_tween_amb.tween_property(env, "fog_depth_end", a["fe"], dur)
	_tween_amb.tween_property(sol, "light_energy", a["sol"], dur)


# ============================================================================ pequenos construtores
## Caixa por extremos (x0..x1, y0..y1, z0..z1).
func _bloco(pai: Node3D, x0: float, x1: float, y0: float, y1: float, z0: float, z1: float, mat: Material, colisao := true) -> MeshInstance3D:
	return Construtor.caixa(pai, Vector3(x1 - x0, y1 - y0, z1 - z0),
		Vector3((x0 + x1) * 0.5, (y0 + y1) * 0.5, (z0 + z1) * 0.5), mat, colisao)


## Parede ao longo de x (local) com vãos em arco abatido. Retorna o nó; posicione-o no centro
## da base e gire em y para paredes ao longo de z. Cada vão: Vector4(xc, largura, h_apoio, flecha).
func _parede_vao(pai: Node3D, comprimento: float, altura: float, espessura: float, vaos: Array, mat: Material) -> Node3D:
	var raiz := Node3D.new()
	pai.add_child(raiz)
	var x := -comprimento * 0.5
	for v in vaos:
		var xa: float = v.x - v.y * 0.5
		var xb: float = v.x + v.y * 0.5
		if xa > x + 0.001:
			_bloco(raiz, x, xa, 0.0, altura, -espessura * 0.5, espessura * 0.5, mat)
		var arco := Ato2Pecas.malha(raiz, Ato2Pecas.arco_abatido(v.y, v.z, v.w, altura, espessura), Vector3(v.x, 0, 0), mat)
		arco.name = "ArcoVao"
		Ato2Pecas.colisao_invisivel(raiz, Vector3(v.y, altura - v.z, espessura), Vector3(v.x, (v.z + altura) * 0.5, 0))
		x = xb
	if x < comprimento * 0.5 - 0.001:
		_bloco(raiz, x, comprimento * 0.5, 0.0, altura, -espessura * 0.5, espessura * 0.5, mat)
	return raiz


func _luz(pai: Node3D, pos: Vector3, cor: Color, energia: float, alcance: float) -> OmniLight3D:
	var l := Construtor.luz(pai, pos, cor, energia, alcance)
	l.shadow_enabled = false
	return l


func _rotulo(pai: Node3D, texto: String, pos: Vector3, rot_y: float, tamanho: int, cor: Color) -> Label3D:
	var l := Construtor.rotulo(pai, texto, pos, tamanho, cor)
	l.rotation_degrees.y = rot_y
	l.pixel_size = 0.003
	return l


# ============================================================================ terreno e dunas
func _terreno() -> void:
	var malha := Ato2Pecas.malha_dunas(-120.0, 120.0, -215.0, 30.0, 2.5)
	var mi := Ato2Pecas.com_colisao_trimesh(self, malha, m_areia)
	mi.name = "Dunas"


func _altura(x: float, z: float) -> float:
	return Ato2Pecas.altura_duna(x, z)


func _pos_duna_figura() -> Vector3:
	return Vector3(22.0, _altura(22.0, -40.0) + 0.15, -40.0)


func _pontos_reaparecer_dunas() -> Array:
	return [Vector3(-38.0, _altura(-38.0, -90.0) + 0.15, -90.0), Vector3(46.0, _altura(46.0, -105.0) + 0.15, -105.0)]


func _dunas_extras() -> void:
	# estacas de madeira marcando um caminho até o núcleo
	var rng := RandomNumberGenerator.new()
	rng.seed = 27
	for i in 9:
		var z := -22.0 - i * 6.0
		for lado in [-1.0, 1.0]:
			var x: float = lado * (3.2 + rng.randf() * 0.5)
			var est := Construtor.caixa(self, Vector3(0.14, 1.2, 0.14), Vector3(x, _altura(x, z) + 0.5, z), m_madeira, false)
			est.rotation_degrees = Vector3(rng.randf_range(-6, 6), rng.randf_range(0, 90), rng.randf_range(-6, 6))
	# tufos de capim de duna (MultiMesh: uma chamada de desenho)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.14
	cone.height = 0.9
	cone.radial_segments = 5
	cone.rings = 1
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	var n := 140
	mm.instance_count = n
	for i in n:
		var x := rng.randf_range(-70.0, 70.0)
		var z := rng.randf_range(-190.0, -20.0)
		if absf(x) < 5.0 and z > -80.0:
			x += 9.0 * signf(x if x != 0.0 else 1.0)
		var s := rng.randf_range(0.7, 1.7)
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))).scaled(Vector3(s, s, s))
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, _altura(x, z) + 0.4 * s, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ato2Pecas.mat_cor(Color(0.56, 0.53, 0.30))
	mmi.name = "Capins"
	add_child(mmi)


func _criar_vento() -> void:
	_vento = CPUParticles3D.new()
	_vento.name = "VentoAreia"
	_vento.amount = 110
	_vento.lifetime = 2.2
	_vento.local_coords = false
	_vento.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_vento.emission_box_extents = Vector3(9.0, 2.5, 9.0)
	_vento.direction = Vector3(1.0, 0.04, 0.25)
	_vento.spread = 8.0
	_vento.gravity = Vector3.ZERO
	_vento.initial_velocity_min = 9.0
	_vento.initial_velocity_max = 14.0
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := Ato2Pecas.mat_cor(Color(0.82, 0.76, 0.62, 0.7), true)
	m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = m
	_vento.mesh = q
	_vento.emitting = false
	add_child(_vento)


# ============================================================================ sala 26: o hall errado
func _hall() -> void:
	_raiz_hall = Node3D.new()
	_raiz_hall.name = "Hall"
	add_child(_raiz_hall)
	# o hall só existe fora de 1950 (o núcleo de 1950 estava sozinho nas dunas)
	Epocas.marcar(_raiz_hall, [GameState.Epoca.E1975, GameState.Epoca.E2019, GameState.Epoca.E2020])

	var alt := 5.2
	_bloco(_raiz_hall, -5.5, 5.5, -0.3, 0.0, -14.5, 2.5, m_piso)                  # piso
	_bloco(_raiz_hall, -5.5, 5.5, alt, alt + 0.3, -14.5, 2.5, m_madeira)          # teto
	_bloco(_raiz_hall, -5.5, -5.0, 0.0, alt, -14.5, 2.5, m_reboco)                # parede esquerda
	_bloco(_raiz_hall, 5.0, 5.5, 0.0, alt, -14.5, 2.5, m_reboco)                  # parede direita
	_bloco(_raiz_hall, -5.5, 5.5, 0.0, alt, 2.0, 2.5, m_reboco)                   # parede de trás (atrás do jogador)
	# parede do fundo com a porta (vão em arco)
	var fundo := _parede_vao(_raiz_hall, 11.0, alt, 0.5, [Vector4(0.0, 2.4, 2.6, 0.4)], m_reboco)
	fundo.position = Vector3(0, 0, Z_PORTA_HALL)
	# lambri de madeira nas laterais e vigas no teto
	_bloco(_raiz_hall, -5.0, -4.94, 0.0, 1.2, -14.0, 2.0, m_madeira, false)
	_bloco(_raiz_hall, 4.94, 5.0, 0.0, 1.2, -14.0, 2.0, m_madeira, false)
	for i in 6:
		_bloco(_raiz_hall, -5.0, 5.0, alt - 0.4, alt, -13.4 + i * 3.0 - 0.15, -13.4 + i * 3.0 + 0.15, m_madeira, false)

	# três portas IGUAIS e fechadas na parede esquerda: o hall é maior e repetido demais
	for z in [-3.0, -7.0, -11.0]:
		_bloco(_raiz_hall, -4.97, -4.87, 0.0, 2.3, z - 0.6, z + 0.6, m_madeira, false)
		var arco := Ato2Pecas.malha(_raiz_hall, Ato2Pecas.arco_abatido(1.2, 2.3, 0.3, 2.9, 0.16), Vector3(-4.95, 0, z), m_pedra, Vector3(0, 90, 0))
		arco.name = "ArcoPortaFalsa"

	# painel P07 corrompido na parede direita (Painel3D da UI: data/paineis.json "p07_corrompido")
	var painel := Painel3D.new("p07_corrompido")
	painel.position = Vector3(4.88, 2.0, -6.0)
	painel.rotation_degrees.y = -90.0
	_raiz_hall.add_child(painel)

	# recorte de papelão de visitante, virado para a parede
	_bloco(_raiz_hall, -4.1, -3.95, 0.0, 0.5, -1.55, -1.45, m_papelao, false)
	var rec := Construtor.caixa(_raiz_hall, Vector3(0.9, 1.45, 0.03), Vector3(-4.0, 1.2, -1.5), m_papelao, false)
	rec.rotation_degrees.y = 90
	var cab := Ato2Pecas.malha(_raiz_hall, SphereMesh.new(), Vector3(-4.0, 2.1, -1.5), m_papelao, Vector3.ZERO, Vector3(0.26, 0.26, 0.04))
	cab.rotation_degrees.y = 90

	# lustre de ferro balançando sem vento
	_lustre = Node3D.new()
	_lustre.position = Vector3(0, alt, -6.0)
	_raiz_hall.add_child(_lustre)
	var corrente := CylinderMesh.new()
	corrente.top_radius = 0.025
	corrente.bottom_radius = 0.025
	corrente.height = 1.3
	Ato2Pecas.malha(_lustre, corrente, Vector3(0, -0.65, 0), m_ferro)
	var aro := TorusMesh.new()
	aro.inner_radius = 0.5
	aro.outer_radius = 0.58
	aro.rings = 14
	aro.ring_segments = 5
	Ato2Pecas.malha(_lustre, aro, Vector3(0, -1.35, 0), m_ferro)
	var vela := CylinderMesh.new()
	vela.top_radius = 0.035
	vela.bottom_radius = 0.035
	vela.height = 0.22
	var m_vela := Ato2Pecas.mat_cor(Color(1.0, 0.85, 0.5), true, 1.0)
	for i in 6:
		var a := TAU * i / 6.0
		Ato2Pecas.malha(_lustre, vela, Vector3(cos(a) * 0.54, -1.22, sin(a) * 0.54), m_vela)
	_luz_lustre = _luz(_lustre, Vector3(0, -1.5, 0), Color(1.0, 0.8, 0.55), 1.6, 11.0)
	_lustre.rotation.z = deg_to_rad(-9)
	_tween_lustre = create_tween().set_loops()
	_tween_lustre.tween_property(_lustre, "rotation:z", deg_to_rad(9), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_lustre.tween_property(_lustre, "rotation:z", deg_to_rad(-9), 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)

	# luz fria perto da porta para puxar o olhar
	_luz(_raiz_hall, Vector3(0, 3.6, -11.5), Color(0.6, 0.7, 1.0), 0.6, 7.0)

	# a porta do fundo (duas folhas), fechada
	var m_porta := m_madeira
	for lado in [-1.0, 1.0]:
		var pivo := Node3D.new()
		pivo.position = Vector3(lado * 1.2, 0, Z_PORTA_HALL)
		_raiz_hall.add_child(pivo)
		var folha := Construtor.caixa(pivo, Vector3(1.2, 2.6, 0.12), Vector3(-lado * 0.6, 1.3, 0), m_porta, true)
		Construtor.caixa(folha, Vector3(0.06, 2.4, 0.14), Vector3(-lado * 0.15, 0.0, 0), m_ferro, false)
		if lado < 0.0:
			_pivo_porta_e = pivo
		else:
			_pivo_porta_d = pivo


func _abrir_porta_hall() -> void:
	if _porta_hall_aberta:
		return
	_porta_hall_aberta = true
	Audio.sfx("porta")
	var t := create_tween().set_parallel()
	t.tween_property(_pivo_porta_e, "rotation:y", deg_to_rad(105), 1.4).set_trans(Tween.TRANS_SINE)
	t.tween_property(_pivo_porta_d, "rotation:y", deg_to_rad(-105), 1.4).set_trans(Tween.TRANS_SINE)
	_ambiente("hall_aberto", 2.5)
	Audio.ambiente("vento", -16.0, 2.5)


func _fechar_porta_hall() -> void:
	_porta_hall_aberta = false
	if _pivo_porta_e:
		_pivo_porta_e.rotation.y = 0.0
		_pivo_porta_d.rotation.y = 0.0


# ============================================================================ sala 28: o núcleo de 1950
func _casa() -> void:
	var casa := Node3D.new()
	casa.name = "Casa1950"
	add_child(casa)
	var h := 3.0
	var esp := 0.4

	# paredes do volume principal (7 x 5 m): frente com a porta, fundo com a porta dos fundos,
	# esquerda com a passagem para o anexo, direita com a chaminé
	var frente := _parede_vao(casa, 7.4, h, esp, [Vector4(0.0, 1.2, 2.1, 0.35)], m_pedra)
	frente.position = Vector3(0, 0, CASA_Z_FRENTE)
	frente.name = "ParedeFrente"
	var fundo := _parede_vao(casa, 7.4, h, esp, [Vector4(-2.0, 1.2, 2.1, 0.35)], m_pedra)
	fundo.position = Vector3(0, 0, CASA_Z_FUNDO)
	fundo.name = "ParedeFundo"
	var esq := _parede_vao(casa, 5.0, h, esp, [Vector4(0.0, 1.2, 2.1, 0.35)], m_pedra)
	esq.position = Vector3(-3.5, 0, -75.0)
	esq.rotation_degrees.y = 90
	esq.name = "ParedeAnexo"
	var dir := _parede_vao(casa, 5.0, h, esp, [], m_pedra)
	dir.position = Vector3(3.5, 0, -75.0)
	dir.rotation_degrees.y = 90

	# anexo (segundo volume, mais baixo e mais estreito)
	var ha := 2.6
	_parede_vao(casa, 4.4, ha, esp, [], m_pedra).position = Vector3(-5.7, 0, -73.0)
	_parede_vao(casa, 4.4, ha, esp, [], m_pedra).position = Vector3(-5.7, 0, -77.0)
	var oeste := _parede_vao(casa, 4.0, ha, esp, [], m_pedra)
	oeste.position = Vector3(-7.7, 0, -75.0)
	oeste.rotation_degrees.y = 90
	# janelinha gradeada no alto (anexo): vidro pálido por dentro + grades
	Ato2Pecas.malha(casa, BoxMesh.new(), Vector3(-7.47, 1.95, -75.0), Ato2Pecas.mat_cor(Color(0.55, 0.62, 0.75), true), Vector3.ZERO, Vector3(0.06, 0.5, 0.4))
	for i in 3:
		Construtor.caixa(casa, Vector3(0.05, 0.56, 0.03), Vector3(-7.44, 1.95, -75.12 + i * 0.12), m_ferro, false)

	# pisos e tetos internos
	_bloco(casa, -7.9, 3.7, -0.3, 0.0, -77.7, -72.3, m_madeira)
	_bloco(casa, -3.7, 3.7, 3.0, 3.15, -77.7, -72.3, m_madeira, false)
	_bloco(casa, -7.9, -3.7, 2.6, 2.75, -77.2, -72.8, m_madeira, false)

	# telhado de duas águas (telha ondulada cinza) + empenas de pedra + cumeeira
	var ang := rad_to_deg(atan(0.6))
	for lado in [1.0, -1.0]:
		var placa := Construtor.caixa(casa, Vector3(7.9, 0.12, 3.45), Vector3(0, 3.62, -75.0 + lado * 1.475), m_telha, false)
		placa.rotation_degrees.x = ang * lado
	Construtor.caixa(casa, Vector3(7.9, 0.14, 0.3), Vector3(0, 4.52, -75.0), m_pedra_cinza, false)
	for x in [-3.5, 3.5]:
		Ato2Pecas.malha(casa, Ato2Pecas.empena(5.0, 1.5, 0.4), Vector3(x, 3.0, -75.0), m_pedra)
	# telhado do anexo (uma água)
	var placa_a := Construtor.caixa(casa, Vector3(5.0, 0.12, 5.0), Vector3(-5.7, 2.75, -75.0), m_telha, false)
	placa_a.rotation_degrees.z = 7

	# chaminé grande saliente (por fora) + lareira (por dentro)
	_bloco(casa, 3.5, 4.5, 0.0, 6.0, -76.1, -73.9, m_pedra)
	_bloco(casa, 3.4, 4.6, 6.0, 6.3, -76.2, -73.8, m_pedra_cinza)
	_bloco(casa, 2.5, 3.3, 0.0, 1.5, -76.1, -73.9, m_pedra)
	Construtor.caixa(casa, Vector3(0.05, 0.9, 1.0), Vector3(2.48, 0.5, -75.0), Ato2Pecas.mat_cor(Color(0.02, 0.01, 0.01)), false)

	# janelas de venezianas na frente (decoração; uma de cada lado da porta)
	for x in [-2.2, 2.2]:
		Construtor.caixa(casa, Vector3(1.0, 1.3, 0.06), Vector3(x, 1.6, CASA_Z_FRENTE + 0.22), m_ferro, false)
		for lado in [-1.0, 1.0]:
			Construtor.caixa(casa, Vector3(0.45, 1.2, 0.08), Vector3(x + lado * 0.26, 1.6, CASA_Z_FRENTE + 0.25), m_madeira, false)

	# mesa e areia que entrou pela porta
	Construtor.caixa(casa, Vector3(1.3, 0.06, 0.8), Vector3(1.9, 0.78, -76.2), m_madeira, false)
	for dx in [-0.55, 0.55]:
		for dz in [-0.3, 0.3]:
			Construtor.caixa(casa, Vector3(0.07, 0.76, 0.07), Vector3(1.9 + dx, 0.38, -76.2 + dz), m_madeira, false)
	var duna_peq := SphereMesh.new()
	for p in [Vector3(0.3, 0.0, -73.5), Vector3(-1.2, 0.0, -73.9), Vector3(2.4, 0.0, -73.6)]:
		Ato2Pecas.malha(casa, duna_peq, p, m_areia, Vector3.ZERO, Vector3(1.4, 0.35, 0.9))

	# aviso diegético da regra
	Construtor.caixa(casa, Vector3(1.9, 0.9, 0.05), Vector3(1.5, 1.8, -77.28), m_madeira, false)
	_rotulo(casa, "AVISO AOS VISITANTES\nMantenha contato visual\ncom os demais visitantes.", Vector3(1.5, 1.8, -77.24), 0.0, 24, Color(0.95, 0.9, 0.7))

	# luzes
	_luz_lareira = _luz(casa, Vector3(2.8, 0.9, -75.0), Color(1.0, 0.5, 0.2), 1.8, 6.5)
	_luz(casa, Vector3(-5.5, 2.0, -75.0), Color(0.55, 0.65, 1.0), 0.7, 5.0)


# ============================================================================ sala 29: a arcada repetida
func _arcada() -> void:
	var arc := Node3D.new()
	arc.name = "Arcada"
	add_child(arc)
	var comp := ARC_BAIA * ARC_N
	var z_fim := ARC_Z0 - comp
	var zc := (ARC_Z0 + z_fim) * 0.5
	var teto := 3.6

	_bloco(arc, -4.4, 0.4, -0.3, 0.0, z_fim - 0.8, ARC_Z0, m_piso)           # piso de lajes
	_bloco(arc, -4.4, 0.4, teto, teto + 0.3, z_fim - 0.8, ARC_Z0, m_madeira, false)
	_bloco(arc, 0.0, 0.4, 0.0, teto, z_fim - 0.8, ARC_Z0, m_pedra)           # parede direita (cega)

	# 9 pilares quadrados + 8 baías de arcos abatidos (todas IGUAIS)
	for k in ARC_N + 1:
		var zp := ARC_Z0 - k * ARC_BAIA
		_bloco(arc, ARC_X_ESQ - 0.4, ARC_X_ESQ + 0.4, 0.0, teto, zp - 0.4, zp + 0.4, m_pedra)
		_bloco(arc, ARC_X_ESQ - 0.48, ARC_X_ESQ + 0.48, 2.15, 2.3, zp - 0.48, zp + 0.48, m_pedra_cinza, false)
	var vao := ARC_BAIA - 0.8
	var m_luz_lant := Ato2Pecas.mat_cor(Color(1.0, 0.75, 0.4), true, 1.0)
	for k in ARC_N:
		var zb := ARC_Z0 - (k + 0.5) * ARC_BAIA
		Ato2Pecas.malha(arc, Ato2Pecas.arco_abatido(vao, 2.3, 0.8, teto, 0.8), Vector3(ARC_X_ESQ, 0, zb), m_pedra, Vector3(0, 90, 0))
		_bloco(arc, ARC_X_ESQ - 0.25, ARC_X_ESQ + 0.25, 0.0, 0.95, zb - vao * 0.5, zb + vao * 0.5, m_pedra)  # peitoril
		# porta falsa idêntica na parede direita (nenhuma abre)
		_bloco(arc, -0.1, 0.0, 0.0, 2.4, zb - 0.6, zb + 0.6, m_madeira, false)
		Ato2Pecas.malha(arc, Ato2Pecas.arco_abatido(1.2, 2.4, 0.3, 2.9, 0.2), Vector3(-0.1, 0, zb), m_pedra_cinza, Vector3(0, 90, 0))
		# lanterna
		var lant := Construtor.caixa(arc, Vector3(0.18, 0.32, 0.18), Vector3(-0.12, 2.2, zb + 1.9), m_luz_lant, false)
		lant.name = "Lanterna"
	# viga transversal a cada meia baía
	for i in ARC_N * 2:
		var zv := ARC_Z0 - (i + 0.5) * ARC_BAIA * 0.5
		_bloco(arc, -4.4, 0.4, teto - 0.3, teto, zv - 0.15, zv + 0.15, m_madeira, false)
	# cornija de mísulas (dentes) na face de fora, sob a laje
	var dente := BoxMesh.new()
	dente.size = Vector3(0.22, 0.16, 0.2)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = dente
	var nd := int(comp / 0.55)
	mm.instance_count = nd
	for i in nd:
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(ARC_X_ESQ - 0.5, teto - 0.1, ARC_Z0 - 0.3 - i * 0.55)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = m_pedra_cinza
	arc.add_child(mmi)

	# 4 lâmpadas ao longo do corredor (luz quente e fraca)
	for k in [1, 3, 5, 7]:
		var l := _luz(arc, Vector3(ARC_XC, 3.1, ARC_Z0 - (k - 0.5) * ARC_BAIA), Color(1.0, 0.72, 0.45), 1.3, 11.0)
		_luzes_arcada.append(l)

	# parede do fundo (com o vão da porta final)
	var parede := _parede_vao(arc, 4.8, teto, 0.8, [Vector4(ARC_XC + 2.0, 1.8, 2.5, 0.3)], m_pedra)
	parede.position = Vector3(-2.0, 0, z_fim - 0.4)
	parede.name = "ParedeFinal"


# ============================================================================ sala 30: a porta fora de lugar
func _porta_final() -> void:
	var z_fim := ARC_Z0 - ARC_BAIA * ARC_N
	var raiz := Node3D.new()
	raiz.name = "PortaFinal"
	add_child(raiz)
	# moldura de pedra CINZA (não combina com o resto): a porta da Sala Medieval, fora de lugar
	Ato2Pecas.malha(raiz, Ato2Pecas.arco_abatido(1.8, 2.5, 0.3, 3.3, 0.9), Vector3(ARC_XC, 0, z_fim - 0.4), m_pedra_cinza)
	for lado in [-1.0, 1.0]:
		_bloco(raiz, ARC_XC + lado * 1.05 - 0.15, ARC_XC + lado * 1.05 + 0.15, 0.0, 2.5, z_fim - 0.85, z_fim + 0.05, m_pedra_cinza)
	# folhas com 4 vidros acesos cada
	var m_vidro := Ato2Pecas.mat_cor(Color(1.0, 0.72, 0.35), true, 1.0)
	for lado in [-1.0, 1.0]:
		var pivo := Node3D.new()
		pivo.position = Vector3(ARC_XC + lado * 0.9, 0, z_fim - 0.1)
		raiz.add_child(pivo)
		var folha := Construtor.caixa(pivo, Vector3(0.9, 2.5, 0.12), Vector3(-lado * 0.45, 1.25, 0), m_madeira, true)
		for iy in 2:
			for ix in 2:
				Construtor.caixa(folha, Vector3(0.26, 0.34, 0.14), Vector3(-0.2 + ix * 0.4, 0.3 + iy * 0.55, 0), m_vidro, false)
		Construtor.caixa(folha, Vector3(0.7, 0.05, 0.15), Vector3(0, -0.4, 0), m_ferro, false)
		if lado < 0.0:
			_pivo_final_e = pivo
		else:
			_pivo_final_d = pivo
	# luz quente vazando por baixo e pelos vidros da porta: o único lugar "vivo" da arcada
	_luz(raiz, Vector3(ARC_XC, 1.7, z_fim + 1.0), Color(1.0, 0.68, 0.38), 2.2, 8.0)
	_interagivel_final = Interagivel.new("Abrir a porta", Vector3(1.9, 2.6, 0.12), _abrir_porta_final)
	_interagivel_final.position = Vector3(ARC_XC, 1.3, z_fim + 0.15)
	add_child(_interagivel_final)
	_rotulo(raiz, "SALA MEDIEVAL", Vector3(ARC_XC, 2.95, z_fim + 0.08), 0.0, 40, Color(0.95, 0.85, 0.55))


## A sala medieval atrás da porta: dois tronos, escudos, tochas... e uma armadura num trono.
func _sala_medieval() -> void:
	var z0 := ARC_Z0 - ARC_BAIA * ARC_N - 0.8
	var raiz := Node3D.new()
	raiz.name = "SalaMedieval"
	add_child(raiz)
	_bloco(raiz, -4.4, 0.4, -0.3, 0.0, z0 - 6.0, z0, m_piso)
	_bloco(raiz, -4.4, 0.4, 3.6, 3.9, z0 - 6.0, z0, m_madeira, false)
	_bloco(raiz, -4.6, -4.4, 0.0, 3.6, z0 - 6.0, z0, m_pedra_cinza)
	_bloco(raiz, 0.4, 0.6, 0.0, 3.6, z0 - 6.0, z0, m_pedra_cinza)
	_bloco(raiz, -4.4, 0.4, 0.0, 3.6, z0 - 6.2, z0 - 6.0, m_pedra_cinza)
	var m_trono := Ato2Pecas.mat_cor(Color(0.35, 0.08, 0.08))
	var m_metal := Ato2Pecas.mat_cor(Color(0.55, 0.57, 0.62))
	for x in [-2.9, -0.7]:
		_bloco(raiz, x - 0.4, x + 0.4, 0.0, 0.5, z0 - 5.4, z0 - 4.7, m_trono, false)
		_bloco(raiz, x - 0.4, x + 0.4, 0.5, 1.9, z0 - 5.55, z0 - 5.4, m_trono, false)
		var escudo := Ato2Pecas.malha(raiz, CylinderMesh.new(), Vector3(x, 2.5, z0 - 6.0), Ato2Pecas.mat_cor(Color(0.7, 0.55, 0.15)), Vector3(90, 0, 0), Vector3(0.7, 0.05, 0.9))
		escudo.name = "Escudo"
	# a armadura sentada no trono da direita (a mesma da sala 21)
	var cx := -0.7
	Construtor.caixa(raiz, Vector3(0.5, 0.55, 0.3), Vector3(cx, 0.78, z0 - 5.2), m_metal, false)
	Construtor.caixa(raiz, Vector3(0.45, 0.14, 0.14), Vector3(cx - 0.12, 0.58, z0 - 4.9), m_metal, false)
	Construtor.caixa(raiz, Vector3(0.45, 0.14, 0.14), Vector3(cx + 0.12, 0.58, z0 - 4.9), m_metal, false)
	Ato2Pecas.malha(raiz, SphereMesh.new(), Vector3(cx, 1.3, z0 - 5.2), m_metal, Vector3.ZERO, Vector3(0.3, 0.34, 0.3))
	for dx in [-1.0, 1.0]:
		Construtor.caixa(raiz, Vector3(0.12, 0.5, 0.12), Vector3(cx + dx * 0.32, 0.82, z0 - 5.05), m_metal, false)
		_luz(raiz, Vector3(dx * 1.8 - 1.8, 2.4, z0 - 5.7), Color(1.0, 0.6, 0.25), 1.4, 7.0)


func _abrir_porta_final(_p: Node) -> void:
	if _fim:
		return
	_fim = true
	if _interagivel_final:
		_interagivel_final.queue_free()
	if figura:
		figura.esconder()
	_chase_ativo = false
	if player:
		player.pode_mover = false
	Audio.sfx("porta")
	var t := create_tween().set_parallel()
	t.tween_property(_pivo_final_e, "rotation:y", deg_to_rad(95), 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(_pivo_final_d, "rotation:y", deg_to_rad(-95), 1.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.9).timeout
	Efeitos.pulso(0.6, 0.5)
	# tela preta própria (camada 15): fica ABAIXO da caixa de fala do Guia (20), que continua visível
	var negro := CanvasLayer.new()
	negro.name = "TelaPreta"
	negro.layer = 15
	add_child(negro)
	var cortina := ColorRect.new()
	cortina.color = Color(0, 0, 0, 0)
	cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	negro.add_child(cortina)
	var t2 := create_tween()
	t2.tween_property(cortina, "color:a", 1.0, 1.0)
	await t2.finished
	Audio.sfx("chiado_radio")
	var falas := ["Obrigado pela visita...", "A visita continua...", "A vi-vi-visita contin— con— continua..."]
	if Guia.has_method("falar_engasgado"):
		await Guia.falar_engasgado("bentinho", falas, true)
	else:
		await Guia.falar("bentinho", falas, true)
	await get_tree().create_timer(0.6).timeout
	_mostrar_fim_demo()


## Mostra a tela de fim da UI (FimDemo.mostrar: estatísticas + "Voltar ao início").
func _mostrar_fim_demo() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.get("hud"):
		main.hud.visible = false
	_cena_fim = FimDemo.mostrar()


# ============================================================================ figura, triggers, marcadores
func _criar_figura() -> void:
	figura = FiguraBranca.new()
	figura.name = "FiguraBranca"
	figura.ativa = false
	figura.velocidade = VEL_FIGURA_CASA
	add_child(figura)
	figura.position = _pos_duna_figura()
	figura.pontos_reaparecer = _pontos_reaparecer_dunas()


func _trigger_sala(n: int, tam: Vector3, pos: Vector3) -> SalaTrigger:
	var t := SalaTrigger.new(n, tam)
	t.position = pos
	add_child(t)
	t.entrou.connect(_on_sala.bind(n))
	return t


func _area(tam: Vector3, pos: Vector3, ao_entrar: Callable) -> Area3D:
	var a := Area3D.new()
	a.collision_layer = 0
	a.collision_mask = 2
	a.monitorable = false
	var f := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = tam
	f.shape = b
	a.add_child(f)
	a.position = pos
	add_child(a)
	a.body_entered.connect(func(corpo: Node):
		if corpo.is_in_group("player"):
			ao_entrar.call())
	return a


func _triggers() -> void:
	_trigger_sala(26, Vector3(10, 4, 2), Vector3(0, 0, 0))
	_trigger_sala(27, Vector3(30, 6, 2), Vector3(0, 0, -16.5))
	_trigger_sala(28, Vector3(6.0, 3, 1.0), Vector3(0, 0, -73.4))
	_trigger_sala(29, Vector3(4.4, 4, 1.5), Vector3(ARC_XC, 0, ARC_Z0 - 1.2))
	_trigger_sala(30, Vector3(4.4, 4, 2.0), Vector3(ARC_XC, 0, ARC_Z0 - ARC_BAIA * (ARC_N - 1) - 1.0))
	# a porta do hall abre quando o jogador se aproxima
	_area(Vector3(12, 4, 8), Vector3(0, 2, -6.0), _abrir_porta_hall)
	# a perseguição começa um pouco dentro da arcada
	_area(Vector3(4.4, 4, 1.5), Vector3(ARC_XC, 2, ARC_Z0 - 2.2 * ARC_BAIA), _iniciar_perseguicao)


func _marcadores() -> void:
	_marcador("Spawn", Vector3(0, 0.1, 0.5), 0.0)
	_marcador("Checkpoint_26", Vector3(0, 0.1, 0.5), 0.0)
	# marcadores de câmera (capturas e testes)
	_marcador("Cam_26", Vector3(0, 0.1, 1.0), 0.0)
	_marcador("Cam_26b", Vector3(0, 0.1, -12.0), 180.0)
	_marcador("Cam_27", Vector3(0, 0.1, -17.5), 0.0)
	_marcador("Cam_27b", Vector3(0, 0.1, -17.5), -44.0)
	_marcador("Cam_28", Vector3(0, 0.1, -71.0), 0.0)
	_marcador("Cam_28b", Vector3(0, 0.1, -75.0), 90.0)
	_marcador("Cam_29", Vector3(ARC_XC, 0.1, ARC_Z0 - 1.0), 0.0)
	_marcador("Cam_29b", Vector3(ARC_XC, 0.1, ARC_Z0 - 3.0 * ARC_BAIA), 180.0)
	_marcador("Cam_30", Vector3(ARC_XC, 0.1, ARC_Z0 - ARC_BAIA * ARC_N + 4.5), 0.0)


func _marcador(nome: String, pos: Vector3, yaw: float) -> Marker3D:
	var m := Marker3D.new()
	m.name = nome
	m.position = pos
	m.rotation_degrees.y = yaw
	add_child(m)
	return m


# ============================================================================ eventos por sala
func _on_sala(n: int) -> void:
	if _visitou.has(n):
		return
	_visitou[n] = true
	match n:
		27:
			# a porta do hall abre para 1950: o hall some e o Visor "mente" (não volta)
			GameState.trocar_epoca(GameState.Epoca.E1950)
			GameState.set_flag("visor_travado", true)
			_ambiente("dunas", 1.5)
			_em_dunas = true
			_vento.emitting = true
			Audio.musica("", 1.5)             # o jingle para: só o vento
			Audio.ambiente("vento", -6.0, 1.5)
			Efeitos.flash(0.8, Color(1, 1, 1), 0.7)
			Guia.falar("bentinho", [
				"Esta área não consta no mapa!",
				"Siga as estacas. Elas são seguras. Provavelmente."])
		28:
			_ambiente("casa", 1.2)
			_em_dunas = false
			_vento.emitting = false
			Audio.ambiente("vento", -18.0, 1.0)   # abafado lá fora
			Audio.sfx("porta")
			figura.pontos_reaparecer = [Vector3(-6.4, 0.05, -74.0), Vector3(-6.4, 0.05, -76.0)]
			figura.pontos_caminho = [Vector3(0, 0.05, CASA_Z_FRENTE), Vector3(-3.5, 0.05, -75.0), Vector3(-2.0, 0.05, CASA_Z_FUNDO)]
			figura.velocidade = VEL_FIGURA_CASA
			figura.teleportar(Vector3(-6.0, 0.05, -75.0))
			figura.ativar()
			Efeitos.pulso(0.4, 0.4)
			Guia.falar("bentinho", ["...", "Fique de olho nos outros visitantes. Sempre."])
		29:
			_ambiente("arcada", 1.2)
			_em_dunas = false
			Audio.ambiente("", -8.0, 1.5)
			figura.esconder()   # a figura da casa fica para trás; outra vem atrás de você
			Guia.falar("bentinho", ["Atenção: a visita guiada continua.", "Por favor, não corra. (Corra.)"])
		30:
			Guia.falar("bentinho", ["A saída é logo ali!", "...Não é a saída."])


func _iniciar_perseguicao() -> void:
	if _chase_ativo or _fim:
		return
	_chase_ativo = true
	figura.reaparecer_fn = _reaparecer_na_arcada
	figura.pontos_reaparecer = []
	figura.pontos_caminho = []
	figura.velocidade = VEL_FIGURA_ARCADA
	figura.teleportar(Vector3(ARC_XC, 0.05, ARC_Z0 + 0.2))
	figura.ativar()
	Audio.sfx("susto", -8.0)
	_prox_apagao = 6.0


## Quando a figura some (cercada), reaparece mais atrás no corredor.
func _reaparecer_na_arcada(_f: Node) -> Vector3:
	var pz := player.global_position.z if player else ARC_Z0 - 10.0
	var z := minf(pz + 14.0, ARC_Z0 + 0.2)
	if absf(z - pz) < 8.0:
		z = pz + 8.0
	return Vector3(ARC_XC, 0.05, z)


# ============================================================================ animações e apagões
func _process(dt: float) -> void:
	_t += dt
	if _luz_lareira:
		_luz_lareira.light_energy = (1.7 + sin(_t * 13.0) * 0.25 + sin(_t * 5.3) * 0.2) * _fator_luz
	for i in _luzes_arcada.size():
		_luzes_arcada[i].light_energy = (1.3 + sin(_t * 9.0 + i * 2.1) * 0.12) * _fator_luz
	if _luz_lustre:
		_luz_lustre.light_energy = 1.6 * (0.9 + 0.1 * sin(_t * 7.0))
	if _chase_ativo and not _apagando and not _fim:
		_prox_apagao -= dt
		if _prox_apagao <= 0.0:
			_apagao()


## Apagão curto: o jogador não vê a figura (ela conta como "não olhada") e ela avança no escuro.
func _apagao() -> void:
	_apagando = true
	_fator_luz = 0.0
	env.ambient_light_energy = 0.03
	figura.escuro = true
	Audio.sfx("chiado_radio")
	Efeitos.pulso(0.3, 0.3)
	await get_tree().create_timer(0.45).timeout
	_fator_luz = 1.0
	env.ambient_light_energy = AMBIENTES["arcada"]["amb_e"]
	figura.escuro = false
	_apagando = false
	_prox_apagao = randf_range(6.0, 10.0)


func _exit_tree() -> void:
	if is_instance_valid(Audio):
		Audio.ambiente("", -8.0, 0.5)
