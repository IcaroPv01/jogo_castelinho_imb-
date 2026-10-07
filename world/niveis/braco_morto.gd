extends Node3D
## O BRAÇO MORTO (sala 100, V2_ROTEIRO §6.3): a cena final. O jogador sai do porão por uma escada e chega à margem do
## lago à noite, com a aparência real de hoje (docs/pesquisa/braco_morto.md): lago de ~200 m, calçadão, pontilhões
## pintados, bancos, postes de luz amarela, pedalinhos em forma de cisne parados, árvores, canteiros, casas ao redor e,
## numa ponta, o canteiro de obra da canalização (tubos pretos, cones, tapume). Tudo montado por código.
##
## Perto da água há uma LÁPIDE DE AREIA feita por criança (castelo de balde e uma plaquinha "TITO", o T de cabeça para
## baixo, como em todos os desenhos dele). Com o Visor (disco sem data, ou o de 1967) vê-se Tito sentado na margem,
## de costas. Ele se vira e diz "Você veio me procurar." Depois: o final, a dedicatória e o título.
##
## FINAIS (contagem invisível):
##   "Encontrado"        `GameState.contadores["pistas_tito"] >= PISTAS_ENCONTRADO`: Tito sorri e some.
##   "Visita concluída"  o padrão: Tito olha para o jogador e continua ali, olhando a água.
## Contadores/flags que este nível LÊ: `pistas_tito` (contador; quem acha uma pista com o Visor faz
## `set_flag("pista_<id>")` + `somar("pistas_tito")`, uma vez por pista). Que ESCREVE: flags `viu_tito_final`,
## `final_encontrado` ou `final_visita_concluida`, e `pista_lapide`.
## Sem som de susto e sem nada violento: é um lugar triste e bonito. A tela final é `Dedicatoria.mostrar()` (UI).

signal cena_tito_terminou
signal fim(final: String)

const SalasGd := preload("res://world/niveis/porao_salas.gd")
const QuartoGd := preload("res://world/niveis/porao_quarto.gd")
const MalhaGd := preload("res://castelinho/malha.gd")

const PISTAS_ENCONTRADO := 6
const LAGO_X := 100.0              # meia extensão do lago (200 m)
const LAGO_Z0 := -44.0
const LAGO_Z1 := -8.0              # margem (muro do calçadão)
const AGUA_Y := -0.3
const POS_TITO := Vector3(3.0, 0.0, -7.2)
const POS_LAPIDE := Vector3(8.5, 0.0, -5.6)
const EPOCAS_TITO: Array[int] = [5, 4]     # ESEMDATA, E1967

## Os testes desligam para conferir a dedicatória sem recarregar a cena principal.
var voltar_ao_titulo := true
var player: Player
var tito: Node3D
var cena_feita := false
var final := ""
var encerrando := false
var dedicatoria: Node
var env: Environment
var mat_agua: ShaderMaterial
var sky_mat: ProceduralSkyMaterial
var lapide: Interagivel

var _cortina: ColorRect
var _legenda: Label
var _titulo_final: Label
var _tween_legenda: Tween
var _tween_env: Tween
var _visto_t := 0.0
var _t := 0.0


func _ready() -> void:
	_ambiente()
	_terreno()
	_lago()
	_calcadao_e_mobiliario()
	_pontilhoes()
	_pedalinhos()
	_arvores_e_casas()
	_obra()
	_escada_do_porao()
	_lapide_de_areia()
	_tito()
	_hud_proprio()
	GameState.epoca_mudou.connect(_ao_mudar_epoca)


# ============================================================================ contrato com o Main
func iniciar(p: Player) -> void:
	player = p
	GameState.entrar_sala(100)
	GameState.definir_corruption_manual(0.4)     # a cena final é calma: o pós-processamento do porão (1.0) não cabe aqui
	GameState.set_flag("visor_travado", false)
	Visor.instalar(self)
	Audio.musica("", 1.0)
	Audio.ambiente("rio", -14.0, 3.0)


func pontos_aquecer() -> Array:
	return [{"transform": Transform3D(Basis(), Vector3(-14, 1.55, 6))},
		{"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-60)), Vector3(0, 1.55, -2))}]


## Sem morte aqui, mas o Main chama se alguma coisa matar: volta ao começo da margem.
func ao_morrer() -> void:
	await Transicao.fade_out(0.3)
	if player:
		player.global_position = Vector3(-14, 0.05, 6)
		player.pode_mover = true
	await Transicao.fade_in(0.6)


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.definir_corruption_manual(-1.0)
	if is_instance_valid(Audio):
		Audio.ambiente("", -8.0, 0.5)


# ============================================================================ céu, luzes e materiais
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.02, 0.06)
	sky_mat.sky_horizon_color = Color(0.07, 0.09, 0.17)
	sky_mat.ground_horizon_color = Color(0.05, 0.06, 0.1)
	sky_mat.ground_bottom_color = Color(0.02, 0.025, 0.04)
	sky_mat.sky_curve = 0.25
	sky.sky_material = sky_mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.30, 0.36, 0.55)
	env.ambient_light_energy = 0.8
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.06, 0.08, 0.14)
	env.fog_depth_begin = 20.0
	env.fog_depth_end = 150.0
	env.fog_depth_curve = 1.2
	env.fog_sky_affect = 0.0
	we.environment = env
	add_child(we)
	var lua := DirectionalLight3D.new()
	lua.name = "Lua"
	lua.rotation_degrees = Vector3(-38, 35, 0)
	lua.light_color = Color(0.55, 0.66, 1.0)
	lua.light_energy = 0.45
	lua.shadow_enabled = false
	add_child(lua)
	# a lua no céu e um punhado de estrelas (uma malha só, sem luz)
	var m: Malha = MalhaGd.new()
	var mat := SalasGd.mat_luz()
	var rng := RandomNumberGenerator.new()
	rng.seed = 100
	for i in 90:
		var dir := Vector3(rng.randf_range(-1, 1), rng.randf_range(0.15, 1.0), rng.randf_range(-1, 0.4)).normalized()
		var c := dir * 170.0
		var s := rng.randf_range(0.25, 0.7)
		var cor := Color(0.8, 0.85, 1.0) * rng.randf_range(0.5, 1.0)
		m.quad(mat, c + Vector3(-s, -s, 0), c + Vector3(s, -s, 0), c + Vector3(s, s, 0), c + Vector3(-s, s, 0), -dir, Vector2.ZERO, cor)
	var lua_pos := Vector3(-60, 80, -140)
	var r := 5.0
	m.quad(mat, lua_pos + Vector3(-r, -r, 0), lua_pos + Vector3(r, -r, 0), lua_pos + Vector3(r, r, 0), lua_pos + Vector3(-r, r, 0), Vector3(0.3, -0.4, 1).normalized(), Vector2.ZERO, Color(0.95, 0.95, 0.85))
	var mi := m.construir_instancia(self, "Ceu")
	mi.extra_cull_margin = 16384.0


func _mat(tex: String, tam: float, tom: Color, falsa: Callable) -> ShaderMaterial:
	var t := SalasGd._textura(tex, falsa)
	return SalasGd._mat_pedra(t, tam, tom, 0.0, 0.0)


# ============================================================================ terreno: grama, calçadão, quadra do lago
func _terreno() -> void:
	var m: Malha = MalhaGd.new()
	var grama := _mat("grama", 4.0, Color(0.30, 0.42, 0.30), Ato2Pecas.tex_areia)
	var concreto := _mat("calcada_lajotas", 1.5, Color(0.66, 0.66, 0.70), Ato2Pecas.tex_piso_pedra)
	var asfalto := _mat("asfalto", 2.5, Color(0.5, 0.5, 0.55), Ato2Pecas.tex_piso_pedra)
	# a grama é cortada em 4 pedaços por causa do poço da escada (x -15.6..-12.4, z 7..14.4)
	var gx0 := -160.0
	var gx1 := 160.0
	var gz0 := -3.0
	var gz1 := 70.0
	var sx0 := -15.6
	var sx1 := -12.4
	var sz0 := 7.0
	var sz1 := 14.4
	_terra(m, grama, gx0, sx0, gz0, gz1)
	_terra(m, grama, sx1, gx1, gz0, gz1)
	_terra(m, grama, sx0, sx1, gz0, sz0)
	_terra(m, grama, sx0, sx1, sz1, gz1)
	# calçadão de lajotas junto à água e uma rua de asfalto ao fundo
	m.caixa(concreto, Vector3(gx0, -0.05, LAGO_Z1), Vector3(gx1, 0.02, gz0), Malha.F_PY, 0.0, Color.WHITE)
	m.caixa(asfalto, Vector3(gx0, -0.05, 30.0), Vector3(gx1, 0.0, 38.0), Malha.F_PY, 0.0, Color.WHITE)
	# meio-fio do lago: parede de concreto de -0,9 a 0 e a calçada que o cobre
	m.caixa(concreto, Vector3(gx0, -1.0, LAGO_Z1 - 0.3), Vector3(gx1, 0.02, LAGO_Z1), Malha.F_PZ | Malha.F_PY, 0.0, Color(0.7, 0.7, 0.7))
	m.col(Vector3(gx0, -2.0, LAGO_Z1 - 1.0), Vector3(gx1, 1.2, LAGO_Z1 + 0.05))      # impede de cair no lago
	# fundo e margens do lago (terra escura, só visual)
	var lama := SalasGd.mat_vc()
	m.caixa(lama, Vector3(-LAGO_X - 20.0, -2.4, LAGO_Z0 - 20.0), Vector3(LAGO_X + 20.0, -2.0, LAGO_Z1), Malha.F_PY, 0.0, Color(0.05, 0.07, 0.05))
	m.caixa(grama, Vector3(-LAGO_X - 20.0, -0.06, LAGO_Z0 - 20.0), Vector3(-LAGO_X, 0.0, LAGO_Z1), Malha.F_PY, 0.0, Color.WHITE)
	m.caixa(grama, Vector3(LAGO_X, -0.06, LAGO_Z0 - 20.0), Vector3(LAGO_X + 20.0, 0.0, LAGO_Z1), Malha.F_PY, 0.0, Color.WHITE)
	m.construir_instancia(self, "Terreno")
	m.construir_colisao(self, "ColisaoTerreno")


func _terra(m: Malha, mat: Material, x0: float, x1: float, z0: float, z1: float) -> void:
	m.caixa(mat, Vector3(x0, -1.0, z0), Vector3(x1, 0.0, z1), Malha.F_PY, 0.0, Color.WHITE)
	m.col(Vector3(x0, -1.0, z0), Vector3(x1, 0.0, z1))


func _lago() -> void:
	mat_agua = ShaderMaterial.new()
	mat_agua.shader = load("res://shaders/porao_agua.gdshader")
	mat_agua.set_shader_parameter("cor_fundo", Color(0.02, 0.045, 0.035))
	mat_agua.set_shader_parameter("cor_ceu", Color(0.10, 0.13, 0.22))
	mat_agua.set_shader_parameter("opacidade", 0.97)
	mat_agua.set_shader_parameter("velocidade", 0.35)
	var plano := PlaneMesh.new()
	plano.size = Vector2(LAGO_X * 2.0, LAGO_Z1 - LAGO_Z0)
	var mi := MeshInstance3D.new()
	mi.name = "Lago"
	mi.mesh = plano
	mi.material_override = mat_agua
	mi.position = Vector3(0, AGUA_Y, (LAGO_Z0 + LAGO_Z1) * 0.5)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# folhas de aguapé / vitória-régia (manchas verdes planas) perto da margem
	var m: Malha = MalhaGd.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var verde := SalasGd.mat_vc()
	for i in 40:
		var x := rng.randf_range(-LAGO_X + 5.0, LAGO_X - 5.0)
		var z := rng.randf_range(LAGO_Z0 + 3.0, LAGO_Z1 - 1.5)
		var r := rng.randf_range(0.3, 0.8)
		m.quad(verde, Vector3(x - r, AGUA_Y + 0.02, z - r), Vector3(x + r, AGUA_Y + 0.02, z - r), Vector3(x + r, AGUA_Y + 0.02, z + r), Vector3(x - r, AGUA_Y + 0.02, z + r), Vector3.UP, Vector2.ZERO, Color(0.12, 0.3, 0.12))
	m.construir_instancia(self, "Folhas")


# ============================================================================ calçadão: postes, bancos, lixeiras
func _calcadao_e_mobiliario() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var ml := SalasGd.mat_luz()
	var ferro := Color(0.1, 0.1, 0.12)
	var luz_poste := Color(1.0, 0.82, 0.45)
	# postes a cada 18 m ao longo do calçadão (a luz de verdade só nos 3 mais próximos do jogador)
	var x := -90.0
	while x <= 90.0:
		m.caixa(mv, Vector3(x - 0.07, 0.0, -3.6), Vector3(x + 0.07, 4.0, -3.4), Malha.F_SEM_BASE, 0.0, ferro)
		m.caixa(mv, Vector3(x - 0.07, 3.9, -3.9), Vector3(x + 0.07, 4.0, -3.4), Malha.F_SEM_BASE, 0.0, ferro)
		m.caixa(ml, Vector3(x - 0.22, 3.72, -4.1), Vector3(x + 0.22, 3.88, -3.7), Malha.F_TODAS, 0.0, luz_poste)
		# poça de luz no chão (quad amarelo translúcido, sem luz): ilumina o calçadão sem gastar luz de verdade
		m.quad(ml, Vector3(x - 2.4, 0.03, -6.8), Vector3(x + 2.4, 0.03, -6.8), Vector3(x + 2.4, 0.03, -1.4), Vector3(x - 2.4, 0.03, -1.4), Vector3.UP, Vector2.ZERO, Color(0.28, 0.22, 0.1))
		x += 18.0
	# bancos de madeira pintada voltados para o lago, a cada 12 m
	x = -84.0
	var k := 0
	while x <= 90.0:
		var cor := Color(0.18, 0.35, 0.6) if k % 2 == 0 else Color(0.7, 0.62, 0.3)
		m.caixa(mv, Vector3(x - 0.9, 0.42, -4.6), Vector3(x + 0.9, 0.5, -4.15), Malha.F_SEM_BASE, 0.0, cor)
		m.caixa(mv, Vector3(x - 0.9, 0.5, -4.15), Vector3(x + 0.9, 0.95, -4.08), Malha.F_SEM_BASE, 0.0, cor)
		m.caixa(mv, Vector3(x - 0.85, 0.0, -4.55), Vector3(x - 0.7, 0.42, -4.2), Malha.F_SEM_BASE, 0.0, ferro)
		m.caixa(mv, Vector3(x + 0.7, 0.0, -4.55), Vector3(x + 0.85, 0.42, -4.2), Malha.F_SEM_BASE, 0.0, ferro)
		m.col(Vector3(x - 0.9, 0.0, -4.65), Vector3(x + 0.9, 0.95, -4.05))
		x += 12.0
		k += 1
	# canteiros com folhagem baixa junto aos postes
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	for i in 18:
		var cx := -88.0 + i * 10.3
		m.caixa(mv, Vector3(cx - 0.7, 0.0, -2.4), Vector3(cx + 0.7, 0.35, -1.6), Malha.F_SEM_BASE, 0.0, Color(0.55, 0.55, 0.5))
		m.bolha(mv, Vector3(cx, 0.6, -2.0), Vector3(0.55, 0.4, 0.4), rng, 6, 2, 0.2, Color(0.2, 0.42, 0.2), Color(0.08, 0.18, 0.08))
	m.construir_instancia(self, "Mobiliario")
	m.construir_colisao(self, "ColisaoMobiliario")
	# luzes de verdade: só os três postes ao redor da ação (orçamento de luzes)
	for px in [-14.0, 2.0, 18.0]:
		var l := OmniLight3D.new()
		l.position = Vector3(px, 3.6, -3.8)
		l.light_color = luz_poste
		l.light_energy = 2.2
		l.omni_range = 16.0
		l.shadow_enabled = false
		add_child(l)


# ============================================================================ pontilhões pintados
func _pontilhoes() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var cores := [[Color(0.2, 0.4, 0.75), Color(0.9, 0.9, 0.88)], [Color(0.85, 0.7, 0.2), Color(0.9, 0.9, 0.88)]]
	var xs := [-34.0, 52.0]
	for k in 2:
		var x: float = xs[k]
		var c1: Color = cores[k][0]
		var c2: Color = cores[k][1]
		# convés de tábuas e guarda-corpo pintado de duas cores
		m.caixa(mv, Vector3(x - 1.4, -0.12, LAGO_Z1 - 14.0), Vector3(x + 1.4, 0.08, LAGO_Z1 - 0.2), Malha.F_SEM_BASE, 0.0, Color(0.42, 0.3, 0.2))
		m.col(Vector3(x - 1.4, -0.5, LAGO_Z1 - 14.0), Vector3(x + 1.4, 0.08, LAGO_Z1 - 0.2))
		for lado in [-1.0, 1.0]:
			for yr in [0.55, 0.95]:
				m.caixa(mv, Vector3(x + lado * 1.35 - 0.05, yr, LAGO_Z1 - 14.0), Vector3(x + lado * 1.35 + 0.05, yr + 0.08, LAGO_Z1 - 0.2), Malha.F_SEM_BASE, 0.0, c1)
			m.col(Vector3(x + lado * 1.35 - 0.08, 0.08, LAGO_Z1 - 14.0), Vector3(x + lado * 1.35 + 0.08, 1.2, LAGO_Z1 - 0.2))
			var z := LAGO_Z1 - 14.0
			while z < LAGO_Z1 - 0.3:
				m.caixa(mv, Vector3(x + lado * 1.35 - 0.07, -0.3, z - 0.07), Vector3(x + lado * 1.35 + 0.07, 1.1, z + 0.07), Malha.F_SEM_BASE, 0.0, c2)
				z += 2.3
		# pontaletes dentro d'água
		for z2 in [-12.0, -8.0]:
			for lado in [-1.0, 1.0]:
				m.caixa(mv, Vector3(x + lado * 1.2 - 0.1, -2.0, LAGO_Z1 + z2 - 0.1), Vector3(x + lado * 1.2 + 0.1, -0.12, LAGO_Z1 + z2 + 0.1), Malha.F_SEM_BASE, 0.0, Color(0.25, 0.2, 0.15))
	m.construir_instancia(self, "Pontilhoes")
	m.construir_colisao(self, "ColisaoPontilhoes")


# ============================================================================ pedalinhos (cisnes brancos, atracados)
func _pedalinhos() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	for i in 5:
		var x := 16.0 + i * 4.2
		var z := LAGO_Z1 - 2.6 - (i % 2) * 0.6
		var y := AGUA_Y + 0.12
		# casco e cisne
		m.bolha(mv, Vector3(x, y + 0.25, z), Vector3(1.0, 0.35, 0.65), rng, 8, 3, 0.05, Color(0.95, 0.95, 0.95), Color(0.5, 0.5, 0.55))
		m.bolha(mv, Vector3(x - 0.55, y + 0.95, z), Vector3(0.14, 0.5, 0.14), rng, 6, 2, 0.05, Color(0.95, 0.95, 0.95), Color(0.8, 0.8, 0.8))
		m.bolha(mv, Vector3(x - 0.62, y + 1.5, z), Vector3(0.17, 0.14, 0.12), rng, 6, 2, 0.05, Color(0.95, 0.95, 0.95), Color(0.8, 0.8, 0.8))
		m.caixa(mv, Vector3(x - 0.9, y + 1.45, z - 0.05), Vector3(x - 0.72, y + 1.52, z + 0.05), Malha.F_SEM_BASE, 0.0, Color(0.95, 0.65, 0.15))
		m.caixa(mv, Vector3(x + 0.1, y + 0.55, z - 0.5), Vector3(x + 0.45, y + 0.9, z + 0.5), Malha.F_SEM_BASE, 0.0, Color(0.9, 0.2, 0.2) if i % 2 == 0 else Color(0.2, 0.4, 0.8))
		# a corda para a margem
		m.caixa(mv, Vector3(x - 0.01, y + 0.4, z), Vector3(x + 0.01, y + 0.42, LAGO_Z1 - 0.1), Malha.F_SEM_BASE, 0.0, Color(0.2, 0.18, 0.15))
	m.construir_instancia(self, "Pedalinhos")


# ============================================================================ árvores, casas e o resto
func _arvores_e_casas() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var ml := SalasGd.mat_luz()
	var rng := RandomNumberGenerator.new()
	rng.seed = 55
	for i in 26:
		var x := -95.0 + i * 7.6 + rng.randf_range(-2.0, 2.0)
		var z := rng.randf_range(4.0, 24.0)
		if absf(x + 14.0) < 5.0 and z > 3.0 and z < 16.0:
			continue
		var h := rng.randf_range(4.5, 8.0)
		m.caixa(mv, Vector3(x - 0.25, 0.0, z - 0.25), Vector3(x + 0.25, h * 0.55, z + 0.25), Malha.F_SEM_BASE, 0.0, Color(0.2, 0.15, 0.1))
		m.col(Vector3(x - 0.3, 0.0, z - 0.3), Vector3(x + 0.3, 2.0, z + 0.3))
		m.bolha(mv, Vector3(x, h * 0.8, z), Vector3(rng.randf_range(2.0, 3.2), h * 0.4, rng.randf_range(2.0, 3.2)), rng, 7, 3, 0.2, Color(0.15, 0.32, 0.18), Color(0.04, 0.1, 0.06))
	# casas e prédios baixos além da rua e do outro lado do lago (silhuetas com janelas acesas)
	for i in 60:
		var x := -150.0 + (i % 30) * 10.5 + rng.randf_range(-2.0, 2.0)
		var w := rng.randf_range(6.0, 9.0)
		var h := rng.randf_range(4.0, 11.0)
		var z := 44.0 + rng.randf_range(0.0, 8.0) if i < 30 else -70.0 - rng.randf_range(0.0, 10.0)
		var cor := Color(0.25, 0.22, 0.27) * rng.randf_range(0.7, 1.2)
		m.caixa(mv, Vector3(x - w * 0.5, 0.0, z - 4.0), Vector3(x + w * 0.5, h, z + 4.0), Malha.F_SEM_BASE, 0.0, cor)
		if rng.randf() < 0.6:
			var zj := z - 4.05 if i < 30 else z + 4.05
			m.caixa(ml, Vector3(x - 0.5, h * 0.5, minf(zj, zj + 0.07)), Vector3(x + 0.5, h * 0.5 + 0.9, maxf(zj, zj + 0.07)), Malha.F_TODAS, 0.0, Color(1.0, 0.8, 0.45) * 0.6)
	m.construir_instancia(self, "ArvoresECasas")
	m.construir_colisao(self, "ColisaoArvores")


## A obra de canalização que a pesquisa registra perto da Garibaldi: tubos pretos, cones, tapume e uma vala.
func _obra() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var x0 := -48.0
	for fila in 3:
		for k in 4 - fila:
			m.caixa(mv, Vector3(x0 + k * 0.7 + fila * 0.35, fila * 0.55, 18.0), Vector3(x0 + k * 0.7 + fila * 0.35 + 0.6, fila * 0.55 + 0.55, 24.0), Malha.F_SEM_BASE, 0.0, Color(0.06, 0.06, 0.07))
	m.col(Vector3(x0, 0.0, 18.0), Vector3(x0 + 3.0, 1.6, 24.0))
	for i in 5:
		m.piramide(mv, Vector3(x0 - 4.0 + i * 1.6, 0.0, 15.0), 0.4, 0.4, 0.7, 1.0)
	m.caixa(mv, Vector3(x0 - 5.0, 0.0, 12.5), Vector3(x0 + 5.0, 1.8, 12.7), Malha.F_SEM_BASE, 0.0, Color(0.7, 0.45, 0.2))
	m.col(Vector3(x0 - 5.0, 0.0, 12.4), Vector3(x0 + 5.0, 1.8, 12.8))
	m.construir_instancia(self, "Obra")
	m.construir_colisao(self, "ColisaoObra")


# ============================================================================ o poço da escada de onde o jogador sai
func _escada_do_porao() -> void:
	var m: Malha = MalhaGd.new()
	var pedra := SalasGd._mat_pedra(SalasGd._textura("parede_castelinho", Ato2Pecas.tex_pedra), 1.48, Color(0.62, 0.52, 0.5), 0.5, 0.2)
	var n := 8
	var z0 := 13.4
	var tread := (z0 - 7.2) / n
	for i in n:
		var za := z0 - i * tread
		var y := -2.4 + (i + 1) * 0.3
		m.caixa(pedra, Vector3(-15.6, y - 0.3, za - tread), Vector3(-12.4, y, za), Malha.F_PY | Malha.F_PZ, 0.0, Color.WHITE)
	m.rampa(PackedVector3Array([Vector3(-15.6, -2.4, z0), Vector3(-12.4, -2.4, z0), Vector3(-15.6, 0.0, 7.2), Vector3(-12.4, 0.0, 7.2),
		Vector3(-15.6, -2.9, z0), Vector3(-12.4, -2.9, z0), Vector3(-15.6, -2.9, 7.2), Vector3(-12.4, -2.9, 7.2)]))
	m.caixa(pedra, Vector3(-15.6, -2.4, z0), Vector3(-12.4, -2.0, z0 + 0.6), Malha.F_TODAS, 0.0, Color.WHITE)
	m.col(Vector3(-15.6, -3.0, z0 - 6.2), Vector3(-12.4, -2.4, z0 + 0.6))
	for lado in [-1.0, 1.0]:
		var x: float = -14.0 + lado * 1.6
		m.caixa(pedra, Vector3(x - 0.3, -2.9, 7.0), Vector3(x + 0.3, 0.45, z0 + 0.6), Malha.F_SEM_BASE, 0.0, Color(0.8, 0.8, 0.8))
		m.col(Vector3(x - 0.3, -2.9, 7.0), Vector3(x + 0.3, 1.2, z0 + 0.6))
	m.construir_instancia(self, "PocoDaEscada")
	m.construir_colisao(self, "ColisaoPoco")
	var sp := Marker3D.new()
	sp.name = "Spawn"
	sp.position = Vector3(-14.0, -2.3, 12.4)
	add_child(sp)
	for nome in ["Cam_margem", "Cam_lapide", "Cam_pier", "Cam_tito", "Cam_escada"]:
		var mk := Marker3D.new()
		mk.name = nome
		add_child(mk)
	get_node("Cam_margem").transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-40.0)), Vector3(-14.0, 1.6, 4.0))
	get_node("Cam_lapide").transform = Transform3D(Basis(Vector3.UP, deg_to_rad(-12.0)), Vector3(7.0, 1.5, 0.0))
	get_node("Cam_tito").transform = Transform3D(Basis(), Vector3(3.0, 1.45, -1.2))
	get_node("Cam_escada").transform = Transform3D(Basis(), Vector3(-14.0, -0.9, 11.0))
	get_node("Cam_pier").transform = Transform3D(Basis(Vector3.UP, deg_to_rad(55.0)), Vector3(-20.0, 1.6, -3.0))
	# a luz que vem do alto da escada: o jogador sai do escuro para a noite (uma luz fria só)
	var l := OmniLight3D.new()
	l.position = Vector3(-14.0, -0.8, 10.0)
	l.light_color = Color(0.5, 0.65, 1.0)
	l.light_energy = 1.2
	l.omni_range = 7.0
	l.shadow_enabled = false
	add_child(l)


# ============================================================================ a lápide de areia (feita por criança)
func _lapide_de_areia() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var areia := Color(0.78, 0.68, 0.48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var p := POS_LAPIDE
	# o montinho de areia que algumas crianças trazem para a calçada: um quadrado de areia, o castelo de balde e a placa
	m.caixa(mv, Vector3(p.x - 2.2, 0.0, p.z - 1.6), Vector3(p.x + 2.2, 0.06, p.z + 1.6), Malha.F_PY, 0.0, areia * 0.9)
	for i in 4:
		var x: float = p.x + [-1.5, -0.95, 0.95, 1.5][i]
		var alt := 0.5 + (i % 2) * 0.12
		m.caixa(mv, Vector3(x - 0.18, 0.06, p.z - 0.2), Vector3(x + 0.18, alt, p.z + 0.16), Malha.F_SEM_BASE, 0.0, Color(0.95, 0.84, 0.6))
		m.caixa(mv, Vector3(x - 0.2, alt, p.z - 0.22), Vector3(x + 0.2, alt + 0.1, p.z + 0.18), Malha.F_SEM_BASE, 0.0, Color(1.0, 0.9, 0.66))
	# a lápide: laje de areia arredondada em cima, com um monte na frente
	m.bolha(mv, Vector3(p.x, 0.35, p.z), Vector3(0.38, 0.4, 0.14), rng, 8, 3, 0.08, areia * 1.1, areia * 0.8)
	m.bolha(mv, Vector3(p.x, 0.12, p.z - 0.55), Vector3(0.75, 0.16, 0.5), rng, 8, 2, 0.12, areia * 1.0, areia * 0.8)
	# um balde vermelho e uma pazinha esquecidos ao lado (só o objeto)
	m.caixa(mv, Vector3(p.x + 1.1, 0.06, p.z - 0.2), Vector3(p.x + 1.4, 0.34, p.z + 0.1), Malha.F_SEM_BASE, 0.0, Color(0.85, 0.1, 0.08))
	m.caixa(mv, Vector3(p.x + 1.55, 0.06, p.z - 0.3), Vector3(p.x + 1.65, 0.1, p.z + 0.2), Malha.F_SEM_BASE, 0.0, Color(0.9, 0.7, 0.15))
	m.construir_instancia(self, "LapideDeAreia")
	# TITO riscado na lápide, com o T de cabeça para baixo (o jeito dele assinar)
	var letras := ["T", "I", "T", "O"]
	for i in 4:
		var l := Construtor.rotulo(self, letras[i], Vector3(p.x - 0.18 + i * 0.12, 0.41, p.z + 0.145), 34, Color(0.3, 0.22, 0.12))
		l.pixel_size = 0.0035
		l.shaded = false
		if i == 0:
			l.rotation_degrees.z = 180.0
	lapide = Interagivel.new("Ver a lápide de areia", Vector3(1.4, 1.0, 0.9), _usar_lapide)
	lapide.position = Vector3(p.x, 0.5, p.z)
	add_child(lapide)
	# recado de giz na calçada, para quem tem o Visor
	var recado := Construtor.rotulo(self, "OLHA PELA LENTE", Vector3(p.x, 0.04, p.z + 1.9), 44, Color(0.2, 0.35, 0.85, 0.9))
	recado.rotation_degrees.x = -90.0
	recado.pixel_size = 0.005
	recado.shaded = false


func _usar_lapide(_p: Node) -> void:
	if encerrando:
		return
	_registrar_pista("lapide")
	if cena_feita:
		_encerrar()
		return
	_mostrar_legenda("Alguém fez isto com as mãos. A areia ainda está úmida.\nSegure Q: o Visor (disco sem data, tecla 5) mostra o resto.", 5.5)


# ============================================================================ Tito (só pelo Visor)
func _tito() -> void:
	tito = Node3D.new()
	tito.name = "TitoNaMargem"
	add_child(tito)
	QuartoGd.menino(tito, POS_TITO, 0.0, true, true)
	tito.get_node("Tito").name = "Menino"
	Epocas.marcar(tito, EPOCAS_TITO)


func _process(dt: float) -> void:
	_t += dt
	if player == null or cena_feita or encerrando:
		return
	# vê o Tito: o Visor mostra a época dele, ele está a menos de 14 m e na frente da câmera por ~1 s
	var vendo := GameState.epoca in EPOCAS_TITO and tito.is_visible_in_tree()
	if vendo:
		var alvo := (tito.get_node("Menino") as Node3D).global_position + Vector3(0, 0.8, 0)
		var dir := alvo - player.camera.global_position
		vendo = dir.length() < 14.0 and (-player.camera.global_transform.basis.z).angle_to(dir.normalized()) < 0.55
	_visto_t = _visto_t + dt if vendo else 0.0
	if _visto_t > 1.0:
		_cena_tito()


func _cena_tito() -> void:
	if cena_feita:
		return
	cena_feita = true
	player.pode_mover = false
	var menino := tito.get_node("Menino") as Node3D
	Audio.sfx("slide", -6.0)
	# ele se vira devagar para o jogador
	var tw := create_tween()
	tw.tween_property(menino, "rotation:y", PI, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	Audio.sfx("crianca_ei", 2.0)
	_mostrar_legenda("Você veio me procurar.", 4.2, 40)
	await get_tree().create_timer(3.2, false).timeout
	if GameState.contadores.get("pistas_tito", 0) >= PISTAS_ENCONTRADO:
		final = "encontrado"
		(menino.get_node("Boca") as Label3D).text = ")"
		(menino.get_node("Boca") as Label3D).rotation_degrees.z = -90.0
		await get_tree().create_timer(1.8, false).timeout
		var tw2 := create_tween()
		tw2.tween_property(menino, "scale", Vector3(0.001, 0.001, 0.001), 2.0).set_trans(Tween.TRANS_SINE)
		await tw2.finished
		GameState.set_flag("final_encontrado", true)
	else:
		final = "visita_concluida"
		await get_tree().create_timer(1.2, false).timeout
		GameState.set_flag("final_visita_concluida", true)
	GameState.set_flag("viu_tito_final", true)
	player.pode_mover = true
	cena_tito_terminou.emit()
	# o jogador solta o Visor e olha em volta: depois de um tempo o fim chega sozinho
	await get_tree().create_timer(4.0, false).timeout
	if not encerrando:
		_encerrar()


# ============================================================================ o fim: título do final, dedicatória, volta ao título
func _encerrar() -> void:
	if encerrando:
		return
	encerrando = true
	if final == "":
		final = "visita_concluida"
	player.pode_mover = false
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 1.0, 1.6)
	await tw.finished
	if Audio.has_method("silenciar"):
		Audio.silenciar(0.5)
	_titulo_final.text = "ENCONTRADO" if final == "encontrado" else "VISITA CONCLUÍDA"
	var tw2 := create_tween()
	tw2.tween_property(_titulo_final, "modulate:a", 1.0, 1.2)
	tw2.tween_interval(2.6)
	tw2.tween_property(_titulo_final, "modulate:a", 0.0, 0.8)
	await tw2.finished
	fim.emit(final)
	await _mostrar_dedicatoria()
	if voltar_ao_titulo:
		_voltar_ao_titulo()


## A tela de dedicatória (UI: `Dedicatoria.mostrar()`); se a classe não existir, um Label com o texto exato do roteiro.
func _mostrar_dedicatoria() -> void:
	var caminho := "res://ui/dedicatoria.gd"
	if ResourceLoader.exists(caminho):
		var cls = load(caminho)
		dedicatoria = cls.mostrar(false)
		await dedicatoria.terminou
		return
	var cam := CanvasLayer.new()
	cam.layer = 130
	add_child(cam)
	var fundo := ColorRect.new()
	fundo.color = Color.BLACK
	fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam.add_child(fundo)
	var l := Label.new()
	l.text = "Tito é um personagem fictício. As crianças que sofrem violência e abandono não são.\n\nSe você desconfia de que uma criança está em perigo: Disque 100 (Direitos Humanos, gratuito, 24h) ou procure o Conselho Tutelar da sua cidade."
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.custom_minimum_size = Vector2(900, 0)
	l.position = Vector2(-450, -80)
	fundo.add_child(l)
	await get_tree().create_timer(8.0, false).timeout
	dedicatoria = cam


func _voltar_ao_titulo() -> void:
	Flash.resetar_ui()
	GameState.jogando = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = false
	Transicao.fade_in(0.05)
	var arvore := get_tree()
	if arvore.current_scene:
		arvore.reload_current_scene.call_deferred()


# ============================================================================ pistas e interface
func _registrar_pista(id: String) -> void:
	if GameState.flag("pista_" + id):
		return
	GameState.set_flag("pista_" + id, true)
	GameState.somar("pistas_tito")


func _hud_proprio() -> void:
	var cam := CanvasLayer.new()
	cam.layer = 14
	add_child(cam)
	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam.add_child(_cortina)
	_legenda = Label.new()
	_legenda.add_theme_font_size_override("font_size", 26)
	_legenda.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_legenda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_legenda.add_theme_constant_override("outline_size", 6)
	_legenda.anchor_left = 0.0
	_legenda.anchor_right = 1.0
	_legenda.anchor_top = 1.0
	_legenda.anchor_bottom = 1.0
	_legenda.offset_top = -190.0
	_legenda.offset_bottom = -110.0
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.modulate.a = 0.0
	cam.add_child(_legenda)
	_titulo_final = Label.new()
	_titulo_final.add_theme_font_size_override("font_size", 54)
	_titulo_final.add_theme_color_override("font_color", Color(0.95, 0.92, 0.8))
	_titulo_final.set_anchors_preset(Control.PRESET_FULL_RECT)
	_titulo_final.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_titulo_final.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_titulo_final.modulate.a = 0.0
	cam.add_child(_titulo_final)


func _mostrar_legenda(texto: String, dur := 3.0, tam := 26) -> void:
	_legenda.text = texto
	_legenda.add_theme_font_size_override("font_size", tam)
	if _tween_legenda and _tween_legenda.is_valid():
		_tween_legenda.kill()
	_tween_legenda = create_tween()
	_tween_legenda.tween_property(_legenda, "modulate:a", 1.0, 0.3)
	_tween_legenda.tween_interval(dur)
	_tween_legenda.tween_property(_legenda, "modulate:a", 0.0, 0.9)


## O Visor sem data (ou 1967) mostra o fim de tarde em que o Tito ainda estava ali: céu e luz esquentam.
func _ao_mudar_epoca(e: int) -> void:
	var passado: bool = e in EPOCAS_TITO
	if _tween_env and _tween_env.is_valid():
		_tween_env.kill()
	_tween_env = create_tween().set_parallel()
	var d := 0.6
	if passado:
		_tween_env.tween_property(sky_mat, "sky_top_color", Color(0.28, 0.15, 0.36), d)
		_tween_env.tween_property(sky_mat, "sky_horizon_color", Color(0.95, 0.52, 0.22), d)
		_tween_env.tween_property(sky_mat, "ground_horizon_color", Color(0.9, 0.5, 0.25), d)
		_tween_env.tween_property(env, "ambient_light_color", Color(0.8, 0.55, 0.4), d)
		_tween_env.tween_property(env, "fog_light_color", Color(0.55, 0.3, 0.2), d)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_ceu", Color(0.85, 0.5, 0.25), d)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_fundo", Color(0.2, 0.1, 0.06), d)
	else:
		_tween_env.tween_property(sky_mat, "sky_top_color", Color(0.015, 0.02, 0.06), d)
		_tween_env.tween_property(sky_mat, "sky_horizon_color", Color(0.07, 0.09, 0.17), d)
		_tween_env.tween_property(sky_mat, "ground_horizon_color", Color(0.05, 0.06, 0.1), d)
		_tween_env.tween_property(env, "ambient_light_color", Color(0.30, 0.36, 0.55), d)
		_tween_env.tween_property(env, "fog_light_color", Color(0.06, 0.08, 0.14), d)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_ceu", Color(0.10, 0.13, 0.22), d)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_fundo", Color(0.02, 0.045, 0.035), d)
