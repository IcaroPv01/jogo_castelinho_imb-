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
## FINAIS (contagem invisível; `fim` emite exatamente "encontrado", "visita_concluida" ou "sala_101"):
##   "Encontrado"        `pistas_tito >= PISTAS_ENCONTRADO` (8): Tito conta o que houve ("Disseram que eu fugi de casa. /
##                       Ninguém olhou na água. / Agora alguém sabe."), levanta, anda até a luz do calçadão deixando pegadas
##                       molhadas e some. A Figura Branca, parada na água do outro lado, afunda e o lago aquieta. O T da
##                       lápide, de cabeça para baixo, fica certo.
##   "Visita concluída"  o padrão (< 8 pistas): "Você também vai embora." Tito se vira para a água; a cortina escurece, a
##                       Figura sobe atrás dele e uma mão longa pousa em seu ombro (nada além disso); corta para o preto.
##                       Título com cartão alegre da prefeitura: "Obrigado pela visita! Volte sempre!" (contraste irônico).
##   "Sala 101"          opcional e NUNCA por acidente: o jogador entra no lago de propósito pela rampa do atracadouro dos
##                       pedalinhos (convite do Tito + aviso "(a água está gelada.)" no primeiro passo; ~3,5 m adentro o
##                       controle trava e a câmera afunda). No fundo, só sugestão: sapatinhos e um balde vermelho; os dedos
##                       longos da Figura fecham sobre a lente; preto. "VOCÊ FICOU." e o cartão "Sala 101 - Visitante registrado."
## Peso só por sugestão: nenhuma violência explícita contra criança. Dedicatória (Disque 100) igual nos três finais.
## Contadores/flags que este nível LÊ: `pistas_tito` (contador; quem acha uma pista com o Visor faz
## `set_flag("pista_<id>")` + `somar("pistas_tito")`, uma vez por pista). Que ESCREVE: flags `viu_tito_final`,
## `final_encontrado`, `final_visita_concluida` ou `final_sala_101`, e `pista_lapide`.
## Sem som de susto e sem nada violento: é um lugar triste e bonito. A tela final é `Dedicatoria.mostrar()` (UI).

signal cena_tito_terminou
signal fim(final: String)

const SalasGd := preload("res://world/niveis/porao_salas.gd")
const QuartoGd := preload("res://world/niveis/porao_quarto.gd")
const MalhaGd := preload("res://castelinho/malha.gd")

const PISTAS_ENCONTRADO := 8
const LAGO_X := 100.0              # meia extensão do lago (200 m)
const LAGO_Z0 := -44.0
const LAGO_Z1 := -8.0              # margem (muro do calçadão)
const AGUA_Y := -0.3
const POS_TITO := Vector3(3.0, 0.0, -7.2)
const POS_LAPIDE := Vector3(8.5, 0.0, -5.6)
const EPOCAS_TITO: Array[int] = [5, 4]     # ESEMDATA, E1967
# rampa do atracadouro dos pedalinhos: o único jeito de entrar no lago (o resto do meio-fio tem parede de colisão)
const RAMPA_X0 := 37.2
const RAMPA_X1 := 40.6
const RAMPA_Z_FIM := -16.0         # onde a rampa chega ao fundo raso (y = RAMPA_Y_FIM)
const RAMPA_Y_FIM := -1.5
const DIST_AFUNDAR := 3.5          # m adentro (a partir do primeiro passo na água) até o final "sala 101"

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
var _visor: Visor
var _tito_concluido := false    # a cena do Tito acabou: só então a lápide encerra o jogo
var _t_superficie := 0.0         # segundos na superfície (y > -0.5), para a dica da lápide
var _dica_dada := false
var _t_lapide: Label3D            # o "T" de cabeça para baixo da lápide (vira certo no final Encontrado)
var _tito_em_pe: Node3D           # Tito de pé (só aparece no final Encontrado)
var _figura: FiguraBranca
var _tinta: ColorRect             # tinta azul-escura de debaixo d'água
var _cartao: PanelContainer       # cartão alegre da prefeitura (finais Visita concluída e Sala 101)
var _convite_dado := false
var _entrou_na_agua := false
var _entrada_pos := Vector3.ZERO
var _filtro: AudioEffectLowPassFilter
var _marola: MeshInstance3D       # anel de marola em volta da Figura na água
var _ult_pegada := -1.0           # fração do caminho da última pegada deixada


func _ready() -> void:
	_ambiente()
	_terreno()
	_lago()
	_calcadao_e_mobiliario()
	_pontilhoes()
	_pedalinhos()
	_atracadouro()
	_arvores_e_casas()
	_margem_de_la()
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
	_visor = Visor.instalar(self)
	Audio.musica("", 1.0)
	Audio.ambiente("rio", -14.0, 3.0)
	_legenda_de_chegada()


## O jogador chega parado no pé da escada, ambiente em silêncio. O porão já mostrou "(ar fresco...)" por 2 s antes da
## transição de 1,4 s; 1,5 s depois do fade a legenda anterior já sumiu e esta não se sobrepõe a nada.
func _legenda_de_chegada() -> void:
	await get_tree().create_timer(1.5, false).timeout
	if encerrando or cena_feita or not is_inside_tree():
		return
	_mostrar_legenda("(lá em cima, um lago. alguém deixou um castelinho de areia na beira.)", 4.5)


func pontos_aquecer() -> Array:
	return [{"transform": Transform3D(Basis(), Vector3(-14, 1.55, 6))},
		{"transform": Transform3D(Basis(Vector3.UP, deg_to_rad(-60)), Vector3(0, 1.55, -2))}]


## Sem morte aqui, mas o Main chama se alguma coisa matar: volta ao começo da margem.
func ao_morrer() -> void:
	if encerrando:
		return     # o fim já está rolando: não teletransporta nem devolve o controle
	await Transicao.fade_out(0.3)
	if player and not encerrando:
		player.global_position = Vector3(-14, 0.05, 6)
		player.pode_mover = not (cena_feita and not _tito_concluido)     # no meio da cena do Tito o controle continua travado
	await Transicao.fade_in(0.6)


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.definir_corruption_manual(-1.0)
	if is_instance_valid(Audio):
		Audio.ambiente("", -8.0, 0.5)
	_abafar(false)


# ============================================================================ céu, luzes e materiais
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky_mat = ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.015, 0.02, 0.06)
	sky_mat.sky_horizon_color = Color(0.1, 0.12, 0.22)     # (revisão V2: um pouco mais claro: o casario recorta o céu)
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
	env.fog_light_color = Color(0.08, 0.1, 0.17)
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
	var mi := m.construir_instancia(self, "Ceu")
	mi.extra_cull_margin = 16384.0
	_lua_disco(Vector3(-60, 80, -140), 5.0)


## A lua: um disco de 20 lados (claro, sem neblina) mais um halo fraco, virados para o jogador.
func _lua_disco(lua_pos: Vector3, r: float) -> void:
	for par in [[r * 1.9, 0.07, Color(0.75, 0.82, 1.0)], [r, 1.0, Color(0.93, 0.94, 0.88)]]:
		var disco := CylinderMesh.new()
		disco.top_radius = par[0]
		disco.bottom_radius = par[0]
		disco.height = 0.05
		disco.radial_segments = 20
		disco.rings = 1
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(par[2].r, par[2].g, par[2].b, par[1])
		if par[1] < 1.0:
			mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.disable_fog = true
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		var lm := MeshInstance3D.new()
		lm.name = "LuaDisco"
		lm.mesh = disco
		lm.material_override = mat
		lm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		lm.extra_cull_margin = 16384.0
		add_child(lm)
		lm.look_at_from_position(lua_pos, Vector3.ZERO, Vector3.UP)     # -Z para o jogador
		lm.rotate_object_local(Vector3.RIGHT, PI * 0.5)                 # o eixo do cilindro (Y) vira o -Z


func _mat(tex: String, tam: float, tom: Color, falsa: Callable) -> ShaderMaterial:
	var t := SalasGd._textura(tex, falsa)
	return SalasGd._mat_pedra(t, tam, tom, 0.0, 0.0)


# ============================================================================ terreno: grama, calçadão, quadra do lago
func _terreno() -> void:
	var m: Malha = MalhaGd.new()
	var grama := _mat("grama", 1.5, Color(0.30, 0.42, 0.30), Ato2Pecas.tex_areia)     # (4.0 dava blocos de Minecraft de perto)
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
	m.col(Vector3(gx0, -1.0, LAGO_Z1), Vector3(gx1, 0.02, gz0))     # sem isto o calçadão (e a lápide) era um buraco
	m.caixa(asfalto, Vector3(gx0, -0.05, 30.0), Vector3(gx1, 0.0, 38.0), Malha.F_PY, 0.0, Color.WHITE)
	# meio-fio do lago: parede de concreto de -0,9 a 0 e a calçada que o cobre
	# (com uma abertura na rampa do atracadouro: ver _atracadouro)
	for seg in [[gx0, RAMPA_X0], [RAMPA_X1, gx1]]:
		m.caixa(concreto, Vector3(seg[0], -1.0, LAGO_Z1 - 0.3), Vector3(seg[1], 0.02, LAGO_Z1), Malha.F_PZ | Malha.F_PY, 0.0, Color(0.7, 0.7, 0.7))
		m.col(Vector3(seg[0], -2.0, LAGO_Z1 - 1.0), Vector3(seg[1], 1.2, LAGO_Z1 + 0.05))      # impede de cair no lago
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
	mat_agua.set_shader_parameter("ondas", 1.0)
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
		# (a poça de luz no chão era um quad opaco cor de mostarda: virou mancha aditiva em _margem_de_la)
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


# ============================================================================ atracadouro: a rampa para dentro d'água
## Rampa de concreto de pedalinho, com grades e placa, ao lado dos cisnes. É a única abertura no meio-fio. Desce de y=0 até
## -1,5 em 8 m e segue num fundo raso plano, entre paredes de colisão; a água (y=-0,3) chega no peito. Nada aqui é armadilha:
## entrar é sempre um ato deliberado (ver `_vigiar_lago`).
func _atracadouro() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var x0 := RAMPA_X0
	var x1 := RAMPA_X1
	var concreto := Color(0.42, 0.45, 0.42)
	var n := 8
	for i in n:
		var za := LAGO_Z1 - i
		var ytopo := 0.02 + (RAMPA_Y_FIM - 0.02) * float(i + 1) / n
		m.caixa(mv, Vector3(x0, -2.2, za - 1.0), Vector3(x1, ytopo, za), Malha.F_SEM_BASE, 0.0, concreto * (0.9 + 0.1 * (i % 2)))
	m.caixa(mv, Vector3(x0, -2.2, RAMPA_Z_FIM - 4.0), Vector3(x1, RAMPA_Y_FIM, RAMPA_Z_FIM), Malha.F_SEM_BASE, 0.0, concreto * 0.8)
	# colisão: a rampa (prisma), o fundo raso, e paredes dos lados e do fundo
	m.rampa(PackedVector3Array([Vector3(x0, 0.02, LAGO_Z1), Vector3(x1, 0.02, LAGO_Z1), Vector3(x0, RAMPA_Y_FIM, RAMPA_Z_FIM), Vector3(x1, RAMPA_Y_FIM, RAMPA_Z_FIM),
		Vector3(x0, -2.2, LAGO_Z1), Vector3(x1, -2.2, LAGO_Z1), Vector3(x0, -2.2, RAMPA_Z_FIM), Vector3(x1, -2.2, RAMPA_Z_FIM)]))
	m.col(Vector3(x0, -2.2, RAMPA_Z_FIM - 4.0), Vector3(x1, RAMPA_Y_FIM, RAMPA_Z_FIM))
	m.col(Vector3(x0 - 0.2, -2.5, RAMPA_Z_FIM - 4.0), Vector3(x0, 1.4, LAGO_Z1))
	m.col(Vector3(x1, -2.5, RAMPA_Z_FIM - 4.0), Vector3(x1 + 0.2, 1.4, LAGO_Z1))
	m.col(Vector3(x0, -2.5, RAMPA_Z_FIM - 4.2), Vector3(x1, 1.4, RAMPA_Z_FIM - 4.0))
	# grades amarelas nos dois lados da parte seca, e a placa do atracadouro
	for lado in [x0 - 0.1, x1 + 0.1]:
		m.caixa(mv, Vector3(lado - 0.05, 0.0, LAGO_Z1 - 2.0), Vector3(lado + 0.05, 0.95, LAGO_Z1 + 0.6), Malha.F_SEM_BASE, 0.0, Color(0.85, 0.7, 0.2))
	m.caixa(mv, Vector3(x0 - 1.4, 0.0, -6.6), Vector3(x0 - 1.3, 1.9, -6.5), Malha.F_SEM_BASE, 0.0, Color(0.15, 0.15, 0.17))
	m.caixa(mv, Vector3(x0 - 2.2, 1.2, -6.5), Vector3(x0 - 0.5, 1.9, -6.44), Malha.F_SEM_BASE, 0.0, Color(0.2, 0.4, 0.75))
	m.construir_instancia(self, "Atracadouro")
	m.construir_colisao(self, "ColisaoAtracadouro")
	var placa := Construtor.rotulo(self, "PEDALINHOS\nEMBARQUE", Vector3(x0 - 1.35, 1.55, -6.42), 30, Color(0.95, 0.95, 0.9))
	placa.shaded = false
	placa.pixel_size = 0.004


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


## Revisão V2 (pesquisa §3, "Noite"): poças de luz amarela no calçadão e REFLEXOS LONGOS NA ÁGUA. Os postes deste lado
## ficam entre o jogador e a água e não refletem para quem está no calçadão; quem reflete é a margem de lá: uma fila de
## postes do outro lado do lago, cujo brilho se estica sobre a água até perto do jogador. Tudo sem luz de verdade:
## 1 malha opaca (postes e calçada de lá) + 1 malha aditiva (poças e reflexos) = 2 draw calls.
func _margem_de_la() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var ml := SalasGd.mat_luz()
	var luz_poste := Color(1.0, 0.82, 0.45)
	# calçada da outra margem (faixa escura) e postes
	m.caixa(mv, Vector3(-LAGO_X - 20.0, -0.3, LAGO_Z0 - 7.0), Vector3(LAGO_X + 20.0, 0.05, LAGO_Z0), Malha.F_PY | Malha.F_PZ, 0.0, Color(0.32, 0.32, 0.34))
	var xs: Array = []
	var x := -81.0
	while x <= 90.0:
		xs.append(x)
		m.caixa(mv, Vector3(x - 0.08, 0.0, LAGO_Z0 - 2.2), Vector3(x + 0.08, 4.2, LAGO_Z0 - 2.0), Malha.F_SEM_BASE, 0.0, Color(0.1, 0.1, 0.12))
		m.caixa(ml, Vector3(x - 0.25, 3.9, LAGO_Z0 - 2.0), Vector3(x + 0.25, 4.08, LAGO_Z0 - 1.6), Malha.F_TODAS, 0.0, luz_poste)
		x += 18.0
	m.construir_instancia(self, "MargemDeLa")
	# aditivo: poças nos dois calçadões e reflexos esticados sobre a água
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	x = -90.0
	while x <= 90.0:
		_quad_uv(st, Vector3(x, 0.05, -5.5), 4.6, 2.4, Rect2(0, 0, 0.5, 1))            # poça deste lado (metade esq. da textura), toda dentro do calçadão (z -8 a -3)
		x += 18.0
	for xl in xs:
		_quad_uv(st, Vector3(xl, 0.08, LAGO_Z0 - 2.4), 4.0, 3.2, Rect2(0, 0, 0.5, 1))  # poça do lado de lá
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = _tex_luzes()
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR     # NEAREST dava degraus serrilhados na poça
	mat.albedo_color = Color(1.0, 0.72, 0.36, 0.9)
	mat.render_priority = 2          # depois da água (também transparente), senão o lago cobre os reflexos
	var mi := MeshInstance3D.new()
	mi.name = "PocasEReflexos"
	mi.mesh = st.commit()
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	# reflexos: uma faixa por poste da margem de lá, sempre apontada para a câmera (shaders/reflexo_agua.gdshader)
	var faixa := ArrayMesh.new()
	var arr := []
	arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-1, 0, 0), Vector3(1, 0, 0), Vector3(1, 0, 1), Vector3(-1, 0, 1)])
	arr[Mesh.ARRAY_TEX_UV] = PackedVector2Array([Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)])
	arr[Mesh.ARRAY_INDEX] = PackedInt32Array([0, 1, 2, 0, 2, 3])
	faixa.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var mr := ShaderMaterial.new()
	mr.shader = preload("res://shaders/reflexo_agua.gdshader")
	mr.set_shader_parameter("faixa", mat.albedo_texture)
	mr.render_priority = 2           # depois da água (também transparente), senão o lago cobre os reflexos
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = faixa
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(xs[i], AGUA_Y + 0.02, LAGO_Z0 + 0.4)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ReflexosNaAgua"
	mmi.multimesh = mm
	mmi.material_override = mr
	mmi.extra_cull_margin = 60.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)


static func _quad_uv(st: SurfaceTool, c: Vector3, rx: float, rz: float, r: Rect2) -> void:
	var pts := [c + Vector3(-rx, 0, -rz), c + Vector3(rx, 0, -rz), c + Vector3(rx, 0, rz), c + Vector3(-rx, 0, rz)]
	var uvs := [r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)]
	for i in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP)
		st.set_uv(uvs[i])
		st.add_vertex(pts[i])


## Textura 64x64: à esquerda uma mancha radial em degraus (poça), à direita o reflexo (faixas horizontais quebradas,
## fortes perto da margem de lá e sumindo em direção ao jogador, como luz sobre água parada com marola).
static func _tex_luzes() -> ImageTexture:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1967
	for y in 64:
		for x in 32:
			var d := Vector2(x + 0.5 - 16.0, (y + 0.5) * 0.5 - 16.0).length() / 16.0
			var a := floorf(pow(clampf(1.0 - d, 0.0, 1.0), 1.5) * 8.0) / 8.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
		var v := float(y) / 63.0
		var onda := 0.6 + 0.4 * sin(y * 1.7 + rng.randf() * 2.0)
		var largura := 0.3 + 0.6 * v * rng.randf_range(0.5, 1.0)
		var desvio := rng.randf_range(-0.15, 0.15) * v
		for x in range(32, 64):
			var u := absf((x - 48.0 + 0.5) / 16.0 - desvio)
			var a2 := 0.0
			if u < largura and rng.randf() < 0.9:
				a2 = pow(1.0 - v * 0.8, 1.3) * onda * (1.0 - u / largura * 0.5)
			img.set_pixel(x, y, Color(1, 1, 1, ceilf(a2 * 4.0 - 0.3) / 4.0))
	return ImageTexture.create_from_image(img)


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
	var piso := _mat("calcada_lajotas", 1.0, Color(0.66, 0.66, 0.70), Ato2Pecas.tex_piso_pedra)
	var n := 8
	var z0 := 13.4
	var tread := (z0 - 7.2) / n
	for i in n:
		var za := z0 - i * tread
		var y := -2.4 + (i + 1) * 0.3
		# piso de lajota, espelho (a parte que se sobe) de tijolo e uma borda um pouco mais clara: lê como degrau, não rampa
		m.caixa(piso, Vector3(-15.6, y - 0.3, za - tread), Vector3(-12.4, y, za), Malha.F_PY, 0.0, Color.WHITE)
		m.caixa(pedra, Vector3(-15.6, y - 0.3, za - tread), Vector3(-12.4, y, za), Malha.F_PZ, 0.0, Color(0.85, 0.85, 0.85))
		m.caixa(piso, Vector3(-15.6, y, za - 0.14), Vector3(-12.4, y + 0.008, za), Malha.F_PY, 0.0, Color(1.45, 1.45, 1.4))
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
	get_node("Cam_escada").transform = Transform3D(Basis(Vector3.RIGHT, deg_to_rad(16.0)), Vector3(-14.0, -0.75, 12.6))
	get_node("Cam_pier").transform = Transform3D(Basis(Vector3.UP, deg_to_rad(55.0)), Vector3(-20.0, 1.6, -3.0))
	# a luz que vem do alto da escada: o jogador sai do escuro para a noite (uma luz fria só)
	var l := OmniLight3D.new()
	l.position = Vector3(-14.0, -0.8, 10.0)
	l.light_color = Color(0.5, 0.65, 1.0)
	l.light_energy = 1.2
	l.omni_range = 7.0
	l.shadow_enabled = false
	add_child(l)
	# luz de preenchimento fria no pé da escada, para os degraus aparecerem
	var l2 := OmniLight3D.new()
	l2.name = "LuzDosDegraus"
	l2.position = Vector3(-14.0, -1.0, 11.2)
	l2.light_color = Color(0.6, 0.75, 1.0)
	l2.light_energy = 1.1
	l2.omni_range = 7.0
	l2.shadow_enabled = false
	add_child(l2)


# ============================================================================ a lápide de areia (feita por criança)
func _lapide_de_areia() -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var areia := Color(0.78, 0.68, 0.48)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var p := POS_LAPIDE
	# o montinho de areia que uma criança trouxe para a calçada: um monte baixo e irregular (antes um quadrado chapado)
	# e quatro torres de balde (tronco de cone de 8 lados, com ameias de dedo), não caixas com tampa
	m.bolha(mv, Vector3(p.x, -0.05, p.z - 0.1), Vector3(2.1, 0.2, 1.35), rng, 10, 2, 0.14, areia * 0.95, areia * 0.72)
	for i in 4:
		var x: float = p.x + [-1.45, -0.9, 0.9, 1.45][i]
		var alt := 0.36 + (i % 2) * 0.1
		_balde_de_areia(m, mv, Vector3(x, 0.08, p.z - 0.05 + (i % 2) * 0.12), 0.21, 0.15, alt, Color(0.92, 0.8, 0.56), Color(0.7, 0.6, 0.4))
	# a lápide: laje de areia arredondada em cima, com um monte na frente
	m.bolha(mv, Vector3(p.x, 0.35, p.z), Vector3(0.5, 0.42, 0.17), rng, 8, 3, 0.05, areia * 1.1, areia * 0.8)
	# placa lisa de areia alisada com a mão, encostada na frente do domo: é nela que o nome é riscado
	m.caixa(mv, Vector3(p.x - 0.36, 0.24, p.z + 0.1), Vector3(p.x + 0.36, 0.56, p.z + 0.215), Malha.F_SEM_BASE, 0.0, areia * 1.08)
	m.bolha(mv, Vector3(p.x, 0.12, p.z - 0.55), Vector3(0.75, 0.16, 0.5), rng, 8, 2, 0.12, areia * 1.0, areia * 0.8)
	# um balde vermelho e uma pazinha esquecidos ao lado (só o objeto)
	m.caixa(mv, Vector3(p.x + 1.1, 0.06, p.z - 0.2), Vector3(p.x + 1.4, 0.34, p.z + 0.1), Malha.F_SEM_BASE, 0.0, Color(0.85, 0.1, 0.08))
	m.caixa(mv, Vector3(p.x + 1.55, 0.06, p.z - 0.3), Vector3(p.x + 1.65, 0.1, p.z + 0.2), Malha.F_SEM_BASE, 0.0, Color(0.9, 0.7, 0.15))
	m.construir_instancia(self, "LapideDeAreia")
	# TITO riscado na lápide, com o T de cabeça para baixo (o jeito dele assinar)
	var letras := ["T", "I", "T", "O"]
	for i in 4:
		var l := Construtor.rotulo(self, letras[i], Vector3(p.x - 0.27 + i * 0.18, 0.4, p.z + 0.222), 64, Color(0.13, 0.08, 0.04))
		l.pixel_size = 0.0033
		l.no_depth_test = false
		l.render_priority = 2
		l.shaded = false
		l.outline_size = 6
		l.outline_modulate = Color(0.95, 0.85, 0.6)
		if i == 0:
			l.rotation_degrees.z = 180.0
			_t_lapide = l
	# uma luz quente baixa para o castelinho de areia ser achado de longe à noite (uma luz só, sem sombra)
	var luz := OmniLight3D.new()
	luz.name = "LuzDaLapide"
	luz.position = Vector3(p.x, 1.4, p.z + 0.9)
	luz.light_color = Color(1.0, 0.78, 0.45)
	luz.light_energy = 2.8
	luz.omni_range = 7.0
	luz.shadow_enabled = false
	add_child(luz)
	lapide = Interagivel.new("Ver a lápide de areia", Vector3(1.4, 1.0, 0.9), _usar_lapide)
	lapide.position = Vector3(p.x, 0.5, p.z)
	add_child(lapide)
	# recado de giz na calçada, para quem tem o Visor
	var recado := Construtor.rotulo(self, "OLHA PELA LENTE", Vector3(p.x, 0.04, p.z + 1.9), 44, Color(0.2, 0.35, 0.85, 0.9))
	recado.rotation_degrees.x = -90.0
	recado.pixel_size = 0.005
	recado.shaded = false


## Torre de balde: tronco de cone de 8 lados (mais largo embaixo), tampa e quatro ameias marcadas com o dedo.
static func _balde_de_areia(m: Malha, mat: Material, base: Vector3, r0: float, r1: float, h: float, cor: Color, cor_baixo: Color) -> void:
	var n := 8
	var topo := base + Vector3(0, h, 0)
	for i in n:
		var a0 := TAU * i / n
		var a1 := TAU * (i + 1) / n
		var b0 := base + Vector3(cos(a0) * r0, 0, sin(a0) * r0)
		var b1 := base + Vector3(cos(a1) * r0, 0, sin(a1) * r0)
		var t0 := topo + Vector3(cos(a0) * r1, 0, sin(a0) * r1)
		var t1 := topo + Vector3(cos(a1) * r1, 0, sin(a1) * r1)
		var fora := Vector3(cos((a0 + a1) * 0.5), 0.25, sin((a0 + a1) * 0.5))
		m.tri_cores(mat, b0, b1, t1, fora, cor_baixo, cor_baixo, cor)
		m.tri_cores(mat, b0, t1, t0, fora, cor_baixo, cor, cor)
		m.tri_cores(mat, topo, t0, t1, Vector3.UP, cor, cor, cor)
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var c := topo + Vector3(cos(a) * r1 * 0.72, 0, sin(a) * r1 * 0.72)
		m.caixa(mat, c + Vector3(-0.04, 0, -0.04), c + Vector3(0.04, 0.07, 0.04), Malha.F_SEM_BASE, 0.0, cor)


func _usar_lapide(_p: Node) -> void:
	if encerrando or (cena_feita and not _tito_concluido):
		return     # durante a cena do Tito a lápide não faz nada (senão o fim atropelava a cena)
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
	# rede de segurança: se algum buraco escapar da colisão, o jogador volta à margem em vez de cair para sempre
	if player and player.global_position.y < -8.0:
		player.global_position = Vector3(-14, 0.05, 6)
		player.velocity = Vector3.ZERO
	if player == null or cena_feita or encerrando:
		return
	# dica gentil, uma vez só: 45 s na superfície sem ter usado a lápide
	if not _dica_dada and player.global_position.y > -0.5:
		_t_superficie += dt
		if _t_superficie > 45.0:
			_dica_dada = true
			if not GameState.flag("pista_lapide"):
				_mostrar_legenda("(o castelinho de areia, perto da água, brilha sob o poste.)", 4.5)
	_vigiar_lago(dt)
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
	_hud_cinema(true)
	player.pode_mover = false
	# soltar o Q no meio da cena devolveria 2020 e o Tito sumiria falando: segura a época até o fim
	GameState.set_flag("visor_travado", true)
	var menino := tito.get_node("Menino") as Node3D
	Audio.sfx("slide", -6.0)
	# ele se vira devagar para o jogador
	var tw := create_tween()
	tw.tween_property(menino, "rotation:y", PI, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	Audio.sfx("crianca_ei", 2.0)
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	_mostrar_legenda("Você veio me procurar.", 4.2, 40)
	await get_tree().create_timer(3.2, false).timeout
	if GameState.contadores.get("pistas_tito", 0) >= PISTAS_ENCONTRADO:
		await _final_encontrado(menino)
	else:
		await _final_visita_concluida(menino)


# ---------------------------------------------------------------- final "Encontrado"
func _final_encontrado(menino: Node3D) -> void:
	final = "encontrado"
	var boca := menino.get_node("Boca") as Label3D
	boca.text = ")"
	boca.rotation_degrees.z = -90.0
	await get_tree().create_timer(1.0, false).timeout
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	_mostrar_legenda("Disseram que eu fugi de casa.", 3.0, 34)
	await get_tree().create_timer(4.0, false).timeout
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	_mostrar_legenda("Ninguém olhou na água.", 3.0, 34)
	await get_tree().create_timer(4.0, false).timeout
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	_mostrar_legenda("Agora alguém sabe.", 3.0, 34)
	await get_tree().create_timer(3.6, false).timeout
	# do outro lado do lago, a Figura em pé na água, parada; ele se levanta e anda para a luz do calçadão
	var perto := Vector3(POS_TITO.x - 2.5, AGUA_Y - 0.15, player.global_position.z - 11.0)     # ~13 m do jogador, na água
	var fig := _figura_na_agua(perto, 0.0)
	var em_pe := _levantar_tito(menino)
	var origem := em_pe.position
	var destino := Vector3(2.2, 0.0, -4.7)
	_ult_pegada = -1.0
	var dist_total := Vector2(destino.x - origem.x, destino.z - origem.z).length()
	var tw := create_tween()
	tw.tween_method(_passo_tito.bind(em_pe, origem, destino, dist_total), 0.0, 1.0, 5.0)
	await tw.finished
	await get_tree().create_timer(0.6, false).timeout
	var tw2 := create_tween()
	tw2.tween_property(em_pe, "scale", Vector3(0.001, 0.001, 0.001), 2.0).set_trans(Tween.TRANS_SINE)
	await tw2.finished
	menino.scale = Vector3(0.001, 0.001, 0.001)
	# a Figura afunda devagar e o lago fica parado
	await get_tree().create_timer(0.8, false).timeout
	Audio.sfx("figura_afunda", -6.0)
	var tw3 := create_tween()
	tw3.tween_property(fig, "position:y", AGUA_Y - 3.4, 4.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	await tw3.finished
	fig.visible = false
	if _marola:
		_marola.visible = false
	var tw4 := create_tween().set_parallel()
	tw4.tween_property(mat_agua, "shader_parameter/ondas", 0.0, 3.0)
	tw4.tween_property(mat_agua, "shader_parameter/velocidade", 0.04, 3.0)
	# o T de cabeça para baixo da lápide fica certo
	if _t_lapide:
		tw4.tween_property(_t_lapide, "rotation_degrees:z", 0.0, 2.5).set_trans(Tween.TRANS_SINE)
	await tw4.finished
	await get_tree().create_timer(1.0, false).timeout
	GameState.set_flag("final_encontrado", true)
	_fechar_cena_tito(true)


## Um passo da caminhada do Tito (f = 0..1 do caminho): anda, balança de leve e deixa pegada.
func _passo_tito(f: float, em_pe: Node3D, origem: Vector3, destino: Vector3, dist_total: float) -> void:
	var pos: Vector3 = origem.lerp(destino, f)
	var alvo_pos := pos
	alvo_pos.y = absf(sin(f * dist_total * 5.0 * PI)) * 0.025
	em_pe.position = alvo_pos
	_deixar_pegada(pos, f, dist_total)


## Troca o Tito sentado por um de pé no mesmo lugar (olhando para o jogador).
func _levantar_tito(menino: Node3D) -> Node3D:
	menino.visible = false
	_tito_em_pe = QuartoGd.menino(tito, POS_TITO, PI, false, true)
	_tito_em_pe.name = "TitoEmPe"
	(_tito_em_pe.get_node("Boca") as Label3D).text = ")"
	(_tito_em_pe.get_node("Boca") as Label3D).rotation_degrees.z = -90.0
	return _tito_em_pe


## Pegadinhas molhadas de pé de criança, a cada ~0,45 m andados, alternando esquerdo/direito (textura em `Pegada`).
func _deixar_pegada(pos: Vector3, f: float, dist_total: float) -> void:
	var passo_f: float = 0.45 / maxf(0.01, dist_total)
	if _ult_pegada >= 0.0 and f - _ult_pegada < passo_f:
		return
	_ult_pegada = f
	var esquerdo: bool = int(f / passo_f) % 2 == 0
	var dir := Vector3(2.2 - POS_TITO.x, 0.0, -4.7 - POS_TITO.z).normalized()
	var lado := -1.0 if esquerdo else 1.0
	var lateral := Vector3(-dir.z, 0.0, dir.x) * 0.07 * lado
	add_child(Pegada.criar(Vector3(pos.x, 0.035, pos.z) + lateral, dir, esquerdo, 0.26, 1.15))


## A Figura em pé na água (parada, sem avançar nem matar). `yaw` 0 = de frente para o sul (para o jogador).
func _figura_na_agua(pos: Vector3, yaw: float) -> FiguraBranca:
	if _figura == null:
		_figura = FiguraBranca.new()
		_figura.ativa = false
		_figura.som_ativo = false
		add_child(_figura)
		_figura.set_physics_process(false)     # sem gravidade nem toque: é só uma presença
	_figura.visible = true
	_marola_da_figura(pos)
	_figura.global_position = pos
	_figura.rotation.y = yaw
	_figura.scale = Vector3.ONE * 1.2     # alta, para ler de longe
	_figura._mat.set_shader_parameter("brilho", 1.9)     # pálida e legível mesmo à noite
	if _figura.get_node_or_null("LuzFria") == null:
		var lf := OmniLight3D.new()
		lf.name = "LuzFria"
		lf.position = Vector3(0.0, 1.9, 1.6)
		lf.light_color = Color(0.7, 0.85, 1.0)
		lf.light_energy = 3.0
		lf.omni_range = 7.0
		lf.shadow_enabled = false
		_figura.add_child(lf)
	return _figura


## Um anel fraco de marola (quad aditivo, 1 draw) na água em volta da Figura, crescendo e voltando devagar.
func _marola_da_figura(pos: Vector3) -> void:
	if _marola == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.85), Color(1, 1, 1, 0)])
		var t := GradientTexture2D.new()
		t.gradient = g
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		t.width = 128
		t.height = 128
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.albedo_texture = t
		mat.albedo_color = Color(0.5, 0.66, 0.9, 0.55)
		mat.render_priority = 2          # depois da água (também transparente)
		var pl := PlaneMesh.new()
		pl.size = Vector2(3.4, 3.4)
		_marola = MeshInstance3D.new()
		_marola.name = "MarolaDaFigura"
		_marola.mesh = pl
		_marola.material_override = mat
		_marola.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_marola)
		var tw := _marola.create_tween().set_loops()
		tw.tween_property(_marola, "scale", Vector3(1.3, 1.0, 1.3), 2.6).from(Vector3(0.8, 1.0, 0.8)).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
		tw.tween_property(_marola, "scale", Vector3(0.8, 1.0, 0.8), 2.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_marola.visible = true
	_marola.global_position = Vector3(pos.x, AGUA_Y + 0.02, pos.z)


# ---------------------------------------------------------------- final "Visita concluída"
func _final_visita_concluida(menino: Node3D) -> void:
	final = "visita_concluida"
	Audio.sfx("voz_tito", -4.0, randf_range(0.95, 1.05))
	_mostrar_legenda("Você também vai embora.", 3.0, 34)
	await get_tree().create_timer(2.6, false).timeout
	# ele se vira de volta para a água (o rosto sai de cena)
	var tw := create_tween()
	tw.tween_property(menino, "rotation:y", 0.0, 1.8).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw.finished
	await get_tree().create_timer(0.8, false).timeout
	GameState.set_flag("final_visita_concluida", true)
	_fechar_cena_tito(false)


## Fim da fala do Tito. No "Encontrado" o jogador ganha o controle por uns segundos; na "Visita concluída" a cena segue
## trancada: o fim vem direto.
func _fechar_cena_tito(devolver_controle: bool) -> void:
	GameState.set_flag("viu_tito_final", true)
	_tito_concluido = true
	if devolver_controle:
		_hud_cinema(false)     # no "Visita concluída" o HUD segue escondido até o fim
		GameState.set_flag("visor_travado", false)
		if not (_visor and _visor.ativo) and GameState.epoca in EPOCAS_TITO:
			GameState.trocar_epoca(GameState.Epoca.E2020)     # o Visor foi solto durante a cena: volta ao hoje
		if not encerrando:
			player.pode_mover = true
	cena_tito_terminou.emit()
	# o jogador solta o Visor e olha em volta: depois de um tempo o fim chega sozinho
	await get_tree().create_timer(4.0 if devolver_controle else 0.5, false).timeout
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
	if final == "visita_concluida":
		await _beat_visita_concluida()
	else:
		var tw := create_tween()
		tw.tween_property(_cortina, "color:a", 1.0, 1.6)
		await tw.finished
	await _titulos_e_dedicatoria()


## Escurece devagar; a Figura sobe da água atrás do Tito e uma mão longa pousa no ombro dele. Só isso. Corta para o preto.
func _beat_visita_concluida() -> void:
	var pos_m: Vector3 = tito.global_position + POS_TITO
	# a câmera se afasta para ~4,5 m de lado, para ver o Tito e quem vem atrás
	var cam_pos := Vector3(pos_m.x - 2.9, 0.05, pos_m.z + 3.5)
	var tw0 := create_tween()
	tw0.tween_property(player, "global_position", cam_pos, 1.4).set_trans(Tween.TRANS_SINE)
	await tw0.finished
	player.olhar_para(pos_m + Vector3(0.1, 0.9, -0.9), 0.5)
	await get_tree().create_timer(0.6, false).timeout
	var tw := create_tween()
	tw.tween_property(_cortina, "color:a", 0.4, 4.0).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(1.0, false).timeout
	var fig := _figura_na_agua(Vector3(pos_m.x + 0.15, AGUA_Y - 3.0, pos_m.z - 1.7), PI * 0.06)
	Audio.sfx("figura_sobe", -6.0)
	var tw2 := create_tween()
	tw2.tween_property(fig, "position:y", AGUA_Y - 0.2, 3.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await tw2.finished
	await get_tree().create_timer(0.5, false).timeout
	# a mão longa pousa no ombro dele
	var ombro := pos_m + Vector3(0.0, 0.62, -0.05)
	var mao := _mao_longa(fig.global_position + Vector3(-0.15, 1.75, 0.2), ombro)
	mao.scale = Vector3(1, 1, 0.01)
	var tw3 := create_tween()
	tw3.tween_property(mao, "scale:z", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	await tw3.finished
	await get_tree().create_timer(2.8, false).timeout     # fica visível antes de escurecer
	var tw4 := create_tween()
	tw4.tween_property(_cortina, "color:a", 1.0, 1.8).set_trans(Tween.TRANS_SINE)
	await tw4.finished
	await get_tree().create_timer(0.6, false).timeout


## Braço de afogada de `de` (ombro da Figura) até `ate` (mundo): braço e antebraço com o cotovelo dobrado para fora, e uma
## mão de dedos longos e finos com a palma achatada pousada em `ate` e os dedos curvados por cima do ombro, mais o polegar.
## Devolve o nó (escala em Z = alcance).
func _mao_longa(de: Vector3, ate: Vector3) -> Node3D:
	var raiz := Node3D.new()
	add_child(raiz)
	raiz.global_position = de
	raiz.look_at(ate, Vector3.UP)
	var cor := FiguraBranca.COR_PELE * 1.4
	var mat := _mat_pele(cor, false)
	var mat_mao := _mat_pele(cor, true)
	var comp: float = de.distance_to(ate)
	var queda: float = clampf((de.y - ate.y) / maxf(comp, 0.01), -1.0, 1.0)
	# braço: ombro -> cotovelo (para fora e um pouco para cima) -> pulso, afinando
	var cotovelo := Vector3(0.28, 0.46, -comp * 0.44)
	var pulso := Vector3(0.03, 0.05, -(comp - 0.14))
	_cone(raiz, Vector3.ZERO, cotovelo, 0.052, 0.04, mat, 8)
	_bola(raiz, cotovelo, 0.047, mat)
	_cone(raiz, cotovelo, pulso, 0.04, 0.022, mat, 8)
	_bola(raiz, pulso, 0.024, mat)
	# a mão fica num nó de eixo horizontal (a rampa do braço é desfeita), com a palma para baixo
	var mao := Node3D.new()
	mao.position = pulso
	mao.rotation.x = asin(queda)
	mao.scale = Vector3.ONE * 1.5     # mãos grandes, para lerem a 4-5 m
	raiz.add_child(mao)
	var palma := _bola(mao, Vector3(0, 0, -0.085), 1.0, mat_mao)
	(palma.mesh as SphereMesh).radial_segments = 10
	palma.scale = Vector3(0.088, 0.026, 0.1)
	# 4 dedos longos, de três falanges, abertos em leque e curvados sobre o ombro; o do meio é o maior
	var comps := [[0.17, 0.14, 0.11], [0.2, 0.16, 0.12], [0.19, 0.15, 0.11], [0.15, 0.12, 0.09]]
	for i in 4:
		var x := (float(i) - 1.5) * 0.04
		_dedo(mao, Vector3(x, 0.0, -0.17), (float(i) - 1.5) * -0.09, comps[i], 0.0145, [-6.0, -34.0, -36.0, -30.0], mat_mao, true)
	# polegar: duas falanges, para fora e para baixo
	_dedo(mao, Vector3(0.075, -0.004, -0.1), -0.7, [0.1, 0.085], 0.017, [-4.0, -26.0, -28.0], mat_mao, true)
	return raiz


## Cone de `a` (raio r0) até `b` (raio r1), no espaço do pai.
static func _cone(pai: Node3D, a: Vector3, b: Vector3, r0: float, r1: float, mat: Material, lados := 7) -> MeshInstance3D:
	var d := b - a
	var cm := CylinderMesh.new()
	cm.bottom_radius = r0
	cm.top_radius = r1
	cm.height = d.length()
	cm.radial_segments = lados
	cm.rings = 1
	var mi := MeshInstance3D.new()
	mi.mesh = cm
	mi.material_override = mat
	mi.position = (a + b) * 0.5
	mi.basis = Basis(Quaternion(Vector3.UP, d.normalized()))
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


static func _bola(pai: Node3D, pos: Vector3, r: float, mat: Material) -> MeshInstance3D:
	var sm := SphereMesh.new()
	sm.radius = r
	sm.height = r * 2.0
	sm.radial_segments = 8
	sm.rings = 4
	var mi := MeshInstance3D.new()
	mi.mesh = sm
	mi.material_override = mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## Dedo articulado que aponta para -Z a partir de `base` (giro `yaw` em Y): uma falange por item de `comps`, cada uma mais
## fina que a anterior, com um nó (junta mais grossa) entre elas e a ponta redonda com uma unha pequena e cinza.
## `curvas` = dobra de cada junta em graus (rotação em X; negativo = para baixo), uma por falange mais a do pivô.
static func _dedo(pai: Node3D, base: Vector3, yaw: float, comps: Array, raio: float, curvas: Array, mat: Material, com_unha: bool) -> void:
	var cur := Node3D.new()
	cur.position = base
	cur.rotation = Vector3(deg_to_rad(curvas[0]), yaw, 0.0)
	pai.add_child(cur)
	var r := raio
	for k in comps.size():
		var c: float = comps[k]
		var r1 := r * 0.8
		_cone(cur, Vector3.ZERO, Vector3(0, 0, -c), r, r1, mat, 6)
		var fim := Node3D.new()
		fim.position = Vector3(0, 0, -c)
		cur.add_child(fim)
		if k < comps.size() - 1:
			_bola(fim, Vector3.ZERO, r1 * 1.3, mat)     # o nó da junta
			fim.rotation.x = deg_to_rad(curvas[mini(k + 1, curvas.size() - 1)])
		else:
			_bola(fim, Vector3.ZERO, r1 * 1.05, mat)     # ponta redonda
			if com_unha:
				var un := _bola(fim, Vector3(0, r1 * 0.5, 0.007), 1.0, _mat_unha())
				un.scale = Vector3(r1 * 0.7, r1 * 0.25, 0.008)
		cur = fim
		r = r1


## Pele pálida e acinzentada (sem luz, como a Figura). `enrugada`: dobrinhas de quem ficou muito tempo n'água.
static func _mat_pele(cor: Color, enrugada: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = cor
	if enrugada:
		m.albedo_texture = _tex_enrugada()
		m.texture_repeat = true
	return m


static func _mat_unha() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.46, 0.5, 0.5)     # cinza-escuro, não preto
	return m


static var _tex_enr: Texture2D
## Branco com dobrinhas escuras atravessadas (v = ao longo do dedo), para a pele de quem ficou muito tempo na água.
static func _tex_enrugada() -> Texture2D:
	if _tex_enr == null:
		var w := 32
		var h := 64
		var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for y in h:
			for x in w:
				var u := float(x) / w
				var v := float(y) / h
				var f := sin(v * TAU * 5.0 + 2.2 * sin(u * TAU * 2.0 + v * 9.0))
				var d := pow(clampf(f * 0.5 + 0.5, 0.0, 1.0), 3.0)
				var gr := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
				var t := 1.0 - 0.2 * d - 0.04 * gr
				img.set_pixel(x, y, Color(t, t, t, 1.0))
		img.generate_mipmaps()
		_tex_enr = ImageTexture.create_from_image(img)
	return _tex_enr


## Título do final (+ cartão alegre da prefeitura quando é o caso), sinal `fim`, dedicatória e volta ao título.
func _titulos_e_dedicatoria() -> void:
	if Audio.has_method("silenciar"):
		Audio.silenciar(0.5)
	var textos := {"encontrado": "ENCONTRADO", "visita_concluida": "VISITA CONCLUÍDA", "sala_101": "VOCÊ FICOU."}
	_titulo_final.text = textos.get(final, "VISITA CONCLUÍDA")
	var tem_cartao := final == "visita_concluida" or final == "sala_101"
	if tem_cartao:
		_titulo_final.offset_bottom = -200.0     # o título sobe para o cartão ficar no centro
		_montar_cartao("Obrigado pela visita! Volte sempre!" if final == "visita_concluida" else "Sala 101 - Visitante registrado.\nVolte sempre!")
	var tw2 := create_tween()
	tw2.tween_property(_titulo_final, "modulate:a", 1.0, 1.2)
	if tem_cartao:
		tw2.tween_interval(1.0)
		tw2.tween_property(_cartao, "modulate:a", 1.0, 0.5)
		tw2.tween_interval(3.4)
		tw2.tween_property(_cartao, "modulate:a", 0.0, 0.8)
		tw2.parallel().tween_property(_titulo_final, "modulate:a", 0.0, 0.8)
	else:
		tw2.tween_interval(2.6)
		tw2.tween_property(_titulo_final, "modulate:a", 0.0, 0.8)
	await tw2.finished
	fim.emit(final)
	await _mostrar_dedicatoria()
	if voltar_ao_titulo:
		_voltar_ao_titulo()


## Cartão de folheto de prefeitura: fundo amarelo-claro, borda azul, levemente torto como um carimbo. Alegre de propósito.
func _montar_cartao(linha: String) -> void:
	if _cartao:
		_cartao.queue_free()
	_cartao = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.99, 0.93, 0.55)
	sb.border_color = Color(0.15, 0.45, 0.8)
	sb.set_border_width_all(8)
	sb.set_corner_radius_all(18)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 14
	sb.content_margin_bottom = 14
	_cartao.add_theme_stylebox_override("panel", sb)
	var caixa := VBoxContainer.new()
	_cartao.add_child(caixa)
	var topo := Label.new()
	topo.text = "PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA"
	topo.add_theme_font_size_override("font_size", 26)
	topo.add_theme_color_override("font_color", Color(0.15, 0.45, 0.8))
	topo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(topo)
	var l := Label.new()
	l.text = linha
	l.add_theme_font_size_override("font_size", 52)
	l.add_theme_color_override("font_color", Color(0.1, 0.4, 0.2))
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caixa.add_child(l)
	_cartao.modulate.a = 0.0
	_cartao.set_anchors_preset(Control.PRESET_CENTER)
	_cartao.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_cartao.grow_vertical = Control.GROW_DIRECTION_BOTH
	_cartao.offset_top = 90.0
	_cartao.offset_bottom = 90.0
	_cartao.rotation_degrees = -3.0
	_cartao.resized.connect(func(): _cartao.pivot_offset = _cartao.size * 0.5)
	_titulo_final.get_parent().add_child(_cartao)


# ============================================================================ final opcional "Sala 101": o lago
## Vigia o jogador perto da água. Convite do Tito ao chegar na beira (uma vez); aviso no primeiro passo dentro da rampa;
## ~DIST_AFUNDAR m mais adiante começa o final. Voltar para a margem cancela tudo.
func _vigiar_lago(_dt: float) -> void:
	var p := player.global_position
	if not _convite_dado and p.z < LAGO_Z1 + 1.7 and p.y > -0.2:
		_convite_dado = true
		Audio.sfx_3d("crianca_ei", Vector3(p.x, 0.0, LAGO_Z1 - 4.0), 0.0)
		_mostrar_legenda("(vem. aqui embaixo é quietinho.)", 4.0)
	var na_rampa: bool = p.z < LAGO_Z1 and p.x > RAMPA_X0 and p.x < RAMPA_X1
	if na_rampa and p.y < AGUA_Y - 0.03:
		if not _entrou_na_agua:
			_entrou_na_agua = true
			_entrada_pos = p
			Audio.sfx("splash", -8.0)
			_mostrar_legenda("(a água está gelada.)", 3.2)
		elif Vector2(p.x - _entrada_pos.x, p.z - _entrada_pos.z).length() >= DIST_AFUNDAR:
			_afundar()
	elif p.y > AGUA_Y + 0.15:
		_entrou_na_agua = false


func _afundar() -> void:
	if encerrando:
		return
	encerrando = true
	final = "sala_101"
	GameState.set_flag("final_sala_101", true)
	GameState.entrar_sala(101)     # o HUD (e o glitch do contador) passam a dizer "SALA 101" durante o afundar
	GameState.set_flag("visor_travado", true)
	player.pode_mover = false
	player.velocity = Vector3.ZERO
	_hud_cinema(true, true)     # só o "SALA 101" fica na tela
	player.set_physics_process(false)     # sem colisão: o corpo desce pelo "chão" da rampa
	var ini := player.global_position
	Audio.sfx("agua_puxa", -4.0)
	Audio.sfx("afundar")
	_abafar(true)
	# o abafado vem do próprio arquivo: na web (modo Sample) o filtro de bus do _abafar() não funciona
	Audio.ambiente("subaquatico", -10.0, 2.0)
	# tinta azul-escura sobe; a névoa fecha
	var camada := _cortina.get_parent()
	_tinta = ColorRect.new()
	_tinta.color = Color(0.02, 0.09, 0.17, 0.0)
	_tinta.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tinta.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(_tinta)
	camada.move_child(_tinta, _cortina.get_index())
	env.fog_sky_affect = 1.0
	var tw := create_tween().set_parallel()
	tw.tween_property(_tinta, "color:a", 0.5, 4.0)
	tw.tween_property(env, "fog_light_color", Color(0.01, 0.04, 0.08), 3.0)
	tw.tween_property(env, "fog_depth_begin", 0.5, 3.0)
	tw.tween_property(env, "fog_depth_end", 12.0, 3.0)
	tw.tween_property(player, "global_position", Vector3(ini.x, RAMPA_Y_FIM - 1.4, ini.z - 3.0), 6.0).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(player, "rotation:y", 0.0, 2.0)
	tw.tween_property(player.cabeca, "rotation:x", 0.35, 3.0)     # olha para cima, para a luz que fica para trás
	await tw.finished
	# no fundo: sapatinhos e um balde vermelho. Só isso.
	var fundo: Vector3 = Vector3(ini.x, RAMPA_Y_FIM + 0.02, ini.z - 3.0)
	_pecas_do_fundo(fundo)
	var tw2 := create_tween()
	tw2.tween_property(player.cabeca, "rotation:x", -0.42, 2.4).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tw2.finished
	await get_tree().create_timer(2.6, false).timeout
	# os dedos compridos da Figura entram pelas bordas e fecham sobre a lente
	var mao := _mao_na_camera()
	var tw3 := create_tween()
	tw3.tween_method(_fechar_mao.bind(mao), 0.0, 1.0, 2.4).set_trans(Tween.TRANS_SINE)
	await tw3.finished
	await get_tree().create_timer(0.6, false).timeout
	var tw4 := create_tween()
	tw4.tween_property(_cortina, "color:a", 1.0, 0.7)
	await tw4.finished
	mao.queue_free()
	await get_tree().create_timer(0.8, false).timeout
	await _titulos_e_dedicatoria()


## O fundo do lago, perto de onde o jogador afunda: um par de tênis pequenos e um balde vermelho de areia tombado (a
## ~1 m, dentro do quadro), uma luz fria fraca em cima deles, areia em ondas e touceiras de alga escura em volta.
func _pecas_do_fundo(fundo: Vector3) -> void:
	var raiz := Node3D.new()
	raiz.name = "FundoDoLago"
	add_child(raiz)
	raiz.global_position = fundo
	raiz.scale = Vector3.ONE * 1.5
	_areia_e_algas(raiz)
	var azul := Construtor.material(Color(0.25, 0.42, 0.9), 0.9)
	var branco := Construtor.material(Color(0.88, 0.88, 0.82), 0.9)
	for i in 2:
		var sola := MeshInstance3D.new()
		var bs := BoxMesh.new()
		bs.size = Vector3(0.09, 0.025, 0.2)
		sola.mesh = bs
		sola.material_override = branco
		sola.position = Vector3(-0.2 + i * 0.17, 0.02, -0.62 - i * 0.08)
		sola.rotation.y = 0.25 - i * 0.7
		raiz.add_child(sola)
		var topo := MeshInstance3D.new()
		var bt := BoxMesh.new()
		bt.size = Vector3(0.08, 0.06, 0.13)
		topo.mesh = bt
		topo.material_override = azul
		topo.position = Vector3(0, 0.04, -0.03)
		sola.add_child(topo)
	var balde := MeshInstance3D.new()
	var cil := CylinderMesh.new()
	cil.top_radius = 0.17
	cil.bottom_radius = 0.12
	cil.height = 0.26
	cil.radial_segments = 10
	balde.mesh = cil
	balde.material_override = Construtor.material(Color(0.95, 0.14, 0.09), 0.8)
	balde.position = Vector3(0.38, 0.1, -0.78)
	balde.rotation_degrees = Vector3(0, 25, 80)
	raiz.add_child(balde)
	# luz fria e fraca em cima das peças, para lerem no escuro (uma luz só, sem sombra)
	var luz := OmniLight3D.new()
	luz.position = Vector3(0.05, 0.75, -0.35)
	luz.light_color = Color(0.55, 0.78, 1.0)
	luz.light_energy = 2.6
	luz.omni_range = 4.5
	luz.shadow_enabled = false
	raiz.add_child(luz)


## Areia em ondas (montes baixos de dois tons) e touceiras de alga (fitas de duas partes, escuras) no espaço da raiz do fundo.
func _areia_e_algas(raiz: Node3D) -> void:
	var m: Malha = MalhaGd.new()
	var mv := SalasGd.mat_vc()
	var rng := RandomNumberGenerator.new()
	rng.seed = 101
	for i in 14:
		var c := Vector3(rng.randf_range(-1.6, 1.6), 0.0, rng.randf_range(-2.6, -0.5))
		var r := Vector3(rng.randf_range(0.2, 0.4), rng.randf_range(0.02, 0.045), rng.randf_range(0.1, 0.2))
		var tom := rng.randf_range(0.8, 1.15)
		m.bolha(mv, c, r, rng, 6, 2, 0.12, Color(0.30, 0.34, 0.32) * tom, Color(0.24, 0.28, 0.27))
	var touceiras := [Vector2(-0.95, -0.45), Vector2(-0.6, -1.35), Vector2(0.95, -1.05), Vector2(1.15, -0.3), Vector2(-0.25, -1.75),
		Vector2(0.35, -1.9), Vector2(-1.4, -0.95), Vector2(0.7, -0.15)]
	for t in touceiras:
		for k in rng.randi_range(4, 6):
			var base := Vector3(t.x + rng.randf_range(-0.12, 0.12), 0.0, t.y + rng.randf_range(-0.12, 0.12))
			var alt := rng.randf_range(0.35, 0.8)
			var giro := rng.randf_range(0.0, TAU)
			var lado := Vector3(cos(giro), 0, sin(giro))
			var inclina := Vector3(-lado.z, 0, lado.x) * rng.randf_range(-0.12, 0.12)
			var meio := base + Vector3(0, alt * 0.5, 0) + inclina
			var ponta := base + Vector3(0, alt, 0) + inclina * 2.6 + lado * 0.03
			var w := 0.028
			var c0 := Color(0.04, 0.1, 0.07)
			var c1 := Color(0.09, 0.2, 0.13)
			var c2 := Color(0.16, 0.3, 0.18)
			for dica in [lado.cross(Vector3.UP), -lado.cross(Vector3.UP)]:
				m.tri_cores(mv, base - lado * w, base + lado * w, meio + lado * w * 0.7, dica, c0, c0, c1)
				m.tri_cores(mv, base - lado * w, meio + lado * w * 0.7, meio - lado * w * 0.7, dica, c0, c1, c1)
				m.tri_cores(mv, meio - lado * w * 0.7, meio + lado * w * 0.7, ponta, dica, c1, c1, c2)
	m.construir_instancia(raiz, "AreiaEAlgas")


## A mão da Figura diante da câmera: dedos longos, afilados, com dois nós e pele pálida enrugada, que entram pelas bordas
## da tela; a palma sobe pela borda de baixo (com mais dois dedos). `_fechar_mao(t)` os traz para o centro e os dobra
## (0 = fora da tela, 1 = fechados sobre a lente).
const DEDOS_BORDA := [Vector2(-0.22, 0.30), Vector2(0.0, 0.32), Vector2(0.24, 0.30), Vector2(-0.52, 0.02), Vector2(0.52, -0.02),
	Vector2(-0.14, -0.30), Vector2(0.17, -0.30)]


func _mao_na_camera() -> Node3D:
	var mao := Node3D.new()
	player.camera.add_child(mao)
	mao.position = Vector3(0, 0, -0.34)
	var mat := _mat_pele(FiguraBranca.COR_PELE * 1.22, true)
	mat.no_depth_test = true
	mat.render_priority = 10
	var mat_unha := _mat_unha()
	mat_unha.no_depth_test = true
	mat_unha.render_priority = 11
	for i in DEDOS_BORDA.size():
		var piv := Node3D.new()
		piv.name = "Dedo%d" % i
		mao.add_child(piv)
		var cur: Node3D = piv
		var fal := [0.17, 0.14, 0.11]
		var rad := 0.02
		for k in 3:
			var seg := _cone(cur, Vector3.ZERO, Vector3(0, -fal[k], 0), rad, rad * 0.76, mat, 7)
			seg.name = "S%d" % k
			var junta := Node3D.new()
			junta.name = "J%d" % k
			junta.position = Vector3(0, -fal[k], 0)
			cur.add_child(junta)
			var no := _bola(junta, Vector3.ZERO, rad * 0.76 * (1.28 if k < 2 else 1.0), mat)     # o nó (junta) mais grosso
			no.scale = Vector3(1.0, 0.8, 1.0)
			cur = junta
			rad *= 0.76
		# unha discreta, cinza-escura, colada na ponta (do lado que olha para a lente)
		var unha := _bola(cur, Vector3(0, 0.026, 0.0075), 1.0, mat_unha)
		unha.scale = Vector3(0.0058, 0.013, 0.0018)
	# a palma, entrando pela borda de baixo: elipsoide achatado e o início do antebraço descendo para fora da tela
	var palma := Node3D.new()
	palma.name = "Palma"
	mao.add_child(palma)
	var pm := _bola(palma, Vector3.ZERO, 1.0, mat)
	pm.scale = Vector3(0.2, 0.17, 0.05)
	var braco := _cone(palma, Vector3(0, -0.1, 0.0), Vector3(0, -0.7, 0.02), 0.085, 0.07, mat, 8)
	braco.name = "Antebraco"
	_fechar_mao(0.0, mao)
	return mao


func _fechar_mao(t: float, mao: Node3D) -> void:
	for i in DEDOS_BORDA.size():
		var piv := mao.get_node("Dedo%d" % i) as Node3D
		var borda: Vector2 = DEDOS_BORDA[i]
		var fora := borda * 2.1
		var pos := fora.lerp(borda * 0.85, t)
		piv.position = Vector3(pos.x, pos.y, 0.0)
		# o dedo aponta (-y local) para o centro da tela
		var para := -borda.normalized()
		var ang := atan2(para.x, -para.y)     # rotação em z que leva -y para `para`
		piv.rotation = Vector3(0.0, 0.0, ang + (i - 2) * 0.05)
		var curl := lerpf(6.0, 34.0, t)
		# articulações: cada junta dobra um pouco para a frente (para a lente)
		var cur: Node3D = mao.get_node("Dedo%d" % i)
		for k in 3:
			var j := cur.get_node("J%d" % k) as Node3D
			j.rotation_degrees.x = -curl * (1.0 + k * 0.25)
			cur = j
	# a palma sobe devagar da borda de baixo
	(mao.get_node("Palma") as Node3D).position = Vector3(0.0, lerpf(-0.62, -0.31, t), 0.0)


## Abafa o som (filtro passa-baixa no Master) enquanto o jogador está debaixo d'água; `false` tira o filtro.
func _abafar(ligar: bool) -> void:
	var bus := AudioServer.get_bus_index("Master")
	if ligar and _filtro == null:
		_filtro = AudioEffectLowPassFilter.new()
		_filtro.cutoff_hz = 600.0
		AudioServer.add_bus_effect(bus, _filtro)
	elif not ligar and _filtro != null:
		for i in AudioServer.get_bus_effect_count(bus):
			if AudioServer.get_bus_effect(bus, i) == _filtro:
				AudioServer.remove_bus_effect(bus, i)
				break
		_filtro = null


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
	_legenda.offset_left = 140.0
	_legenda.offset_right = -140.0
	_legenda.offset_top = -110.0
	_legenda.offset_bottom = -40.0
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# faixa preta translúcida atrás do texto: a legenda lê sobre a lápide clara
	var faixa_leg := StyleBoxFlat.new()
	faixa_leg.bg_color = Color(0, 0, 0, 0.45)
	faixa_leg.content_margin_left = 16
	faixa_leg.content_margin_right = 16
	faixa_leg.content_margin_top = 4
	faixa_leg.content_margin_bottom = 4
	_legenda.add_theme_stylebox_override("normal", faixa_leg)
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


## HUD limpo nas cenas de cinema (faixa de discos, ⊥N, mira); `manter_sala` deixa o rótulo "SALA N".
func _hud_cinema(ligado: bool, manter_sala := false) -> void:
	var main := get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	if main and main.get("hud") and main.hud.has_method("modo_cinema"):
		main.hud.modo_cinema(ligado, manter_sala)


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
