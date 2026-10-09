extends Node3D
## Flashback da Barra (VISITA 2, V2_ROTEIRO §3.2 e §8.2; antes "sala 14", PLANO §5.2, MVP_ROTEIRO "Flashback da Barra").
## Contador: `GameState.sala_global(14)` (sala 36 na visita 2) e, na volta, `sala_global(15)` (sala 37), em `Spawn_volta_barra`.
## Foz do Rio Tramandaí ao entardecer: areia, molhe de pedra, água com ondas (shader), pescadores
## genéricos em silhueta com tarrafas, ponte ao longe com o sol baixo atrás dela.
##
## Minigame da tarrafa: a Tainá explica; o boto (nadadeira dorsal CORTADA) vem até a margem e
## "bate a cabeça" na água; o jogador lança com E ou clique dentro da janela. São 3 lances.
## Nos 2 primeiros a rede pega tainhas. No 3º o boto sinaliza na hora errada, a rede puxa o
## JOGADOR para a água (câmera afunda, tela escurece, "agua_puxa"). A rede traz também UMA SANDÁLIA DE CRIANÇA
## (só o objeto, nó "Sandalia" dentro da rede, sem nenhum drama gráfico) e a Tainá diz "...era eu na rede?".
## Depois: flag viu_flashback_barra, sala `sala_global(15)` e volta ao Castelinho em Spawn_volta_barra.
##
## O contador fica na sala da Barra (`sala_global(14)`) e treme de vez em quando (Efeitos.pulso + tremida no HUD).
## Parâmetros de teste/ajuste: espera_min/espera_max (s entre sinais do boto), destino.

signal lance_feito(numero: int, acertou: bool)
signal puxado
signal terminou

enum Fase { INTRO, ESPERA, JANELA, LANCADO, PUXADO, FIM }

const NIVEL_AGUA := -0.3
const MARGEM_Z := -3.2            # z da linha d'água
const JANELA_DUR := 1.7           # s depois da batida em que o lance ainda vale
const SOL := Vector3(-0.62, 0.10, -0.78)
const TOTAL_LANCES := 3

@export var espera_min := 3.2
@export var espera_max := 5.0
@export var lance_inicial := 1       # (teste/ajuste) começar direto num lance, ex.: 3 = o do rio
@export var destino := "res://world/niveis/castelinho.tscn"
@export var spawn_destino := "Spawn_volta_barra"

var player: Player
var fase := Fase.INTRO
var lances := 0
var tainhas := 0
var janela_aberta := false
var pulou_intro := false

var env: Environment
var sol_luz: DirectionalLight3D
var boto: Node3D
var _boto_corpo: Node3D
var _boto_fin: Node3D
var _pescadores: Array[Node3D] = []
var _agua_mats: Array[ShaderMaterial] = []
var _barreira_frente: StaticBody3D
var _t := 0.0
var _boto_nada := true
var _boto_pos := Vector3(0, NIVEL_AGUA - 0.5, -9.0)
var _boto_yaw := 0.0
var _boto_vel := Vector3.ZERO
var _alvo_lance := Vector3(0, NIVEL_AGUA, -6.8)
var _janela_t := 0.0
var _desde_fase := 0.0
var _exclama: Label3D
var _corda: MeshInstance3D
var _rede_jogador: Node3D
var _corda_a := Vector3.ZERO
var _cortina: ColorRect
var _lbl_placar: Label
var _lbl_dica: Label
var _prox_pulso := 6.0
var _shake_ativo := false
var _hud_pos := Vector2.ZERO
var _puxa := false
var _puxa_origem := Vector3.ZERO
var _puxa_alvo := Vector3.ZERO
var _puxa_t := 0.0
var _mat_rede: StandardMaterial3D
var _mat_peixe: StandardMaterial3D
var _mat_espuma: StandardMaterial3D


func _ready() -> void:
	_ambiente()
	_chao()
	_agua()
	_molhe_e_ponte()
	_margem_oposta_e_orla()
	_barreiras()
	_criar_pescadores()
	_criar_boto()
	_criar_hud()
	_marcadores()
	_mat_rede = Ato2Pecas.mat_cor(Color(0.06, 0.05, 0.07, 0.6), true)
	_mat_rede.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_peixe = Ato2Pecas.mat_cor(Color(0.85, 0.88, 0.92), true)
	_mat_espuma = Ato2Pecas.mat_cor(Color(0.95, 0.92, 0.85, 0.7), true)
	_mat_espuma.cull_mode = BaseMaterial3D.CULL_DISABLED


## Sala (global) do flashback e da volta ao Castelinho: 36 e 37 na visita 2 (nada de 14/15 fixos).
func sala_global_barra() -> int:
	return GameState.sala_global(14)


func sala_global_volta() -> int:
	return GameState.sala_global(15)


# ============================================================================ contrato com o Main
func iniciar(p: Player) -> void:
	player = p
	GameState.entrar_sala(sala_global_barra())
	GameState.definir_corruption_manual(0.1)
	Audio.ambiente("mar", -10.0, 2.0)
	_hud_pos = _hud_label_pos()
	_rodar_minigame()


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.definir_corruption_manual(-1.0)
	if is_instance_valid(Audio):
		Audio.ambiente("", -8.0, 0.5)
	_restaurar_hud()


# ============================================================================ cenário
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.13, 0.15, 0.36)
	mat.sky_horizon_color = Color(1.0, 0.55, 0.28)
	mat.ground_horizon_color = Color(0.95, 0.5, 0.3)
	mat.ground_bottom_color = Color(0.25, 0.14, 0.2)
	mat.sky_curve = 0.18
	mat.ground_curve = 0.1
	mat.sun_angle_max = 14.0
	mat.sun_curve = 0.12
	sky.sky_material = mat
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.42, 0.40)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.92, 0.55, 0.38)
	env.fog_depth_begin = 90.0
	env.fog_depth_end = 480.0
	env.fog_depth_curve = 1.3
	env.fog_sky_affect = 0.0   # senão a névoa pinta o céu todo de laranja chapado
	we.environment = env
	add_child(we)
	sol_luz = DirectionalLight3D.new()
	sol_luz.name = "Sol"
	sol_luz.light_color = Color(1.0, 0.62, 0.34)
	sol_luz.light_energy = 1.25
	sol_luz.shadow_enabled = false
	sol_luz.transform = Transform3D(Basis.looking_at(-SOL.normalized(), Vector3.UP), Vector3.ZERO)
	add_child(sol_luz)


func _mat_areia(tom: float = 1.0) -> StandardMaterial3D:
	return Ato2Pecas.mat_tri("areia_barra_%.2f" % tom, Color(tom, tom * 0.96, tom * 0.9), Ato2Pecas.tex_areia(), 0.22, 1.0)


func _chao() -> void:
	var areia := _mat_areia(1.0)
	# faixa de areia onde o jogador fica (com colisão) até a linha d'água
	Construtor.caixa(self, Vector3(500, 0.6, 60.0), Vector3(0, -0.3, MARGEM_Z + 30.0), areia, true, "Areia")
	# areia molhada (mais escura) junto à água
	Construtor.caixa(self, Vector3(500, 0.02, 2.2), Vector3(0, 0.005, MARGEM_Z + 1.1), _mat_areia(0.6), false)
	# barranco que desce para dentro d'água
	var rampa := Construtor.caixa(self, Vector3(500, 0.3, 5.0), Vector3(0, -0.45, MARGEM_Z - 2.3), _mat_areia(0.55), false)
	rampa.rotation_degrees.x = -7
	# fundo escuro (areia do rio) para não ver o vazio por baixo da água
	Construtor.caixa(self, Vector3(400, 0.2, 300), Vector3(0, -3.0, -140), Ato2Pecas.mat_cor(Color(0.1, 0.12, 0.13)), false)


func _agua() -> void:
	var sh := load("res://shaders/agua.gdshader") as Shader
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("margem_z", MARGEM_Z)
	m.set_shader_parameter("dir_sol", SOL.normalized())
	_agua_mats.append(m)
	var perto := PlaneMesh.new()
	perto.size = Vector2(300, 60)
	perto.subdivide_width = 120
	perto.subdivide_depth = 40
	Ato2Pecas.malha(self, perto, Vector3(0, NIVEL_AGUA, MARGEM_Z - 30.0), m).name = "AguaPerto"
	var longe := PlaneMesh.new()
	longe.size = Vector2(1200, 330)
	longe.subdivide_width = 30
	longe.subdivide_depth = 20
	Ato2Pecas.malha(self, longe, Vector3(0, NIVEL_AGUA, MARGEM_Z - 60.0 - 165.0), m).name = "AguaLonge"


func _molhe_e_ponte() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	# molhe de pedra: corre pela margem para a direita, em direção ao mar
	var bloco := BoxMesh.new()
	bloco.size = Vector3(1, 1, 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = bloco
	var n := 260
	mm.instance_count = n
	for i in n:
		var x := 16.0 + rng.randf() * 150.0
		var z := MARGEM_Z - 1.0 - rng.randf() * 6.0
		var s := Vector3(rng.randf_range(0.8, 1.8), rng.randf_range(0.6, 1.4), rng.randf_range(0.8, 1.8))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(s)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, NIVEL_AGUA + 0.3 + rng.randf() * 0.6, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ato2Pecas.mat_tri("pedra_molhe", Color(0.55, 0.5, 0.5), Ato2Pecas.tex_piso_pedra(), 0.5)
	mmi.name = "Molhe"
	add_child(mmi)

	# ponte Giuseppe Garibaldi ao longe, à esquerda, contra o sol baixo (silhueta, 3 pistas)
	var ponte := Node3D.new()
	ponte.name = "Ponte"
	add_child(ponte)
	var sombra := Ato2Pecas.mat_cor(Color(0.08, 0.05, 0.09), true)
	var luz_poste := Ato2Pecas.mat_cor(Color(1.0, 0.75, 0.4), true, 1.0)
	var x_ponte := -120.0
	Construtor.caixa(ponte, Vector3(14, 1.2, 150), Vector3(x_ponte, 7.0, MARGEM_Z - 78.0), sombra, false)
	for i in 13:
		var z := MARGEM_Z - 10.0 - i * 11.5
		Construtor.caixa(ponte, Vector3(2.0, 8.0, 2.0), Vector3(x_ponte, 3.0, z), sombra, false)
		Construtor.caixa(ponte, Vector3(0.3, 0.3, 0.3), Vector3(x_ponte - 6.8, 8.6, z), luz_poste, false)
		Construtor.caixa(ponte, Vector3(0.3, 0.3, 0.3), Vector3(x_ponte + 6.8, 8.6, z), luz_poste, false)


func _margem_oposta_e_orla() -> void:
	var escuro := Ato2Pecas.mat_cor(Color(0.1, 0.07, 0.12), true)
	var janela := Ato2Pecas.mat_cor(Color(1.0, 0.72, 0.4), true, 1.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	# margem de Tramandaí do outro lado do rio: faixa baixa escura com prédios pequenos
	Construtor.caixa(self, Vector3(900, 3.0, 20.0), Vector3(0, 0.0, -170.0), escuro, false)
	for i in 34:
		var x := -300.0 + i * 18.0 + rng.randf() * 8.0
		var h := rng.randf_range(4.0, 16.0) if rng.randf() < 0.85 else rng.randf_range(18.0, 26.0)
		Construtor.caixa(self, Vector3(rng.randf_range(6, 12), h, rng.randf_range(6, 10)), Vector3(x, h * 0.5, -168.0), escuro, false)
		if rng.randf() < 0.5:
			Construtor.caixa(self, Vector3(0.8, 0.8, 0.2), Vector3(x, h * 0.6, -163.0), janela, false)
	# atrás do jogador: calçadão, postes e prédios da orla de Imbé
	Construtor.caixa(self, Vector3(500, 0.5, 6.0), Vector3(0, -0.1, 20.0), Ato2Pecas.mat_cor(Color(0.55, 0.5, 0.48)), true)
	var pastel := [Color(0.9, 0.7, 0.6), Color(0.7, 0.8, 0.85), Color(0.9, 0.85, 0.6), Color(0.75, 0.6, 0.7)]
	for i in 24:
		var h := rng.randf_range(5.0, 16.0)
		var c: Color = pastel[i % pastel.size()]
		Construtor.caixa(self, Vector3(10, h, 9), Vector3(-130.0 + i * 12.0 + rng.randf() * 4.0, h * 0.5, 70.0 + rng.randf() * 10.0), Ato2Pecas.mat_cor(c), false)
	for i in 7:
		Construtor.caixa(self, Vector3(0.15, 4.0, 0.15), Vector3(-30.0 + i * 10.0, 2.0, 17.5), escuro, false)
		Construtor.caixa(self, Vector3(0.5, 0.3, 0.5), Vector3(-30.0 + i * 10.0, 4.1, 17.5), janela, false)


func _barreiras() -> void:
	# paredes invisíveis: o jogador fica no seu "lugar" na fila, na beira d'água
	_barreira_frente = Ato2Pecas.colisao_invisivel(self, Vector3(14, 4, 0.6), Vector3(0, 2.0, -3.0))
	Ato2Pecas.colisao_invisivel(self, Vector3(0.6, 4, 16), Vector3(-3.2, 2.0, 5.0))
	Ato2Pecas.colisao_invisivel(self, Vector3(0.6, 4, 16), Vector3(3.2, 2.0, 5.0))
	Ato2Pecas.colisao_invisivel(self, Vector3(14, 4, 0.6), Vector3(0, 2.0, 10.0))


func _marcadores() -> void:
	var s := Marker3D.new()
	s.name = "Spawn"
	s.position = Vector3(0, 0.1, -1.0)
	add_child(s)
	var c := Marker3D.new()
	c.name = "Cam_boto"
	c.position = Vector3(0, 0.1, -1.6)
	add_child(c)
	var c2 := Marker3D.new()
	c2.name = "Cam_ponte"
	c2.position = Vector3(0, 0.1, -1.0)
	c2.rotation_degrees.y = 55.0
	add_child(c2)
	var c3 := Marker3D.new()
	c3.name = "Cam_molhe"
	c3.position = Vector3(0, 0.1, -1.0)
	c3.rotation_degrees.y = -70.0
	add_child(c3)
	var c4 := Marker3D.new()
	c4.name = "Cam_costas"
	c4.position = Vector3(0, 0.1, -1.0)
	c4.rotation_degrees.y = 180.0
	add_child(c4)


# ============================================================================ pescadores e boto
func _criar_pescadores() -> void:
	var sombra := Ato2Pecas.mat_cor(Color(0.07, 0.045, 0.08), true)
	var rede := Ato2Pecas.mat_cor(Color(0.07, 0.05, 0.08, 0.7), true)
	rede.cull_mode = BaseMaterial3D.CULL_DISABLED
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
	var braco := CapsuleMesh.new()
	braco.radius = 0.05
	braco.height = 0.8
	var tarrafa := CylinderMesh.new()
	tarrafa.top_radius = 0.04
	tarrafa.bottom_radius = 0.45
	tarrafa.height = 0.7
	tarrafa.radial_segments = 12
	tarrafa.rings = 1
	tarrafa.cap_top = false
	tarrafa.cap_bottom = false
	var xs := [-12.0, -8.5, -5.4, 5.6, 8.9, 12.5]
	for i in xs.size():
		var p := Node3D.new()
		p.name = "Pescador%d" % i
		p.position = Vector3(xs[i], NIVEL_AGUA - 0.05, -3.9 - (i % 2) * 0.7)
		p.rotation_degrees.y = (i * 37 % 20) - 10.0
		add_child(p)
		Ato2Pecas.malha(p, corpo, Vector3(0, 0.95, 0), sombra)
		Ato2Pecas.malha(p, cabeca, Vector3(0, 1.88, 0), sombra)
		Ato2Pecas.malha(p, chapeu, Vector3(0, 2.02, 0), sombra)
		# braço levantado segurando a tarrafa
		Ato2Pecas.malha(p, braco, Vector3(0.28, 1.55, -0.25), sombra, Vector3(-50, 0, -18))
		Ato2Pecas.malha(p, tarrafa, Vector3(0.42, 1.45, -0.55), rede, Vector3(8, 0, -10))
		_pescadores.append(p)


func _criar_boto() -> void:
	boto = Node3D.new()
	boto.name = "Boto"
	add_child(boto)
	_boto_corpo = Node3D.new()
	boto.add_child(_boto_corpo)
	var gris := Ato2Pecas.mat_cor(Color(0.42, 0.45, 0.5), false, 0.3)   # um pouco de emissão: o contraluz do sol não o apaga
	var claro := Ato2Pecas.mat_cor(Color(0.78, 0.8, 0.82), false, 0.3)
	var preto := Ato2Pecas.mat_cor(Color(0.02, 0.02, 0.03), true)
	var tronco := CapsuleMesh.new()
	tronco.radius = 0.27
	tronco.height = 2.3
	Ato2Pecas.malha(_boto_corpo, tronco, Vector3.ZERO, gris, Vector3(90, 0, 0))
	var barriga := CapsuleMesh.new()
	barriga.radius = 0.2
	barriga.height = 1.9
	Ato2Pecas.malha(_boto_corpo, barriga, Vector3(0, -0.11, 0), claro, Vector3(90, 0, 0))
	var focinho := CylinderMesh.new()
	focinho.top_radius = 0.025
	focinho.bottom_radius = 0.1
	focinho.height = 0.4
	Ato2Pecas.malha(_boto_corpo, focinho, Vector3(0, -0.06, -1.3), gris, Vector3(-90, 0, 0))
	var cauda := CylinderMesh.new()
	cauda.top_radius = 0.05
	cauda.bottom_radius = 0.2
	cauda.height = 0.7
	Ato2Pecas.malha(_boto_corpo, cauda, Vector3(0, 0.02, 1.3), gris, Vector3(90, 0, 0))
	var barbatana := BoxMesh.new()
	barbatana.size = Vector3(0.5, 0.04, 0.26)
	for lado in [-1.0, 1.0]:
		Ato2Pecas.malha(_boto_corpo, barbatana, Vector3(lado * 0.3, 0.0, 1.78), gris, Vector3(0, -lado * 25.0, lado * 8.0))
		Ato2Pecas.malha(_boto_corpo, barbatana, Vector3(lado * 0.32, -0.14, -0.5), gris, Vector3(0, lado * 20.0, lado * 30.0))
		var olho := SphereMesh.new()
		olho.radius = 0.03
		olho.height = 0.06
		Ato2Pecas.malha(_boto_corpo, olho, Vector3(lado * 0.2, 0.1, -0.98), preto)
	# nadadeira dorsal CORTADA: um toco achatado, sem ponta, com a marca clara do corte
	_boto_fin = Node3D.new()
	_boto_fin.position = Vector3(0, 0.3, 0.1)
	_boto_fin.rotation_degrees.x = 12.0
	_boto_corpo.add_child(_boto_fin)
	var toco := CylinderMesh.new()
	toco.top_radius = 0.05
	toco.bottom_radius = 0.17
	toco.height = 0.22
	toco.radial_segments = 8
	Ato2Pecas.malha(_boto_fin, toco, Vector3(0, 0.1, 0), gris, Vector3.ZERO, Vector3(1.0, 1.0, 0.22))
	var corte := BoxMesh.new()
	corte.size = Vector3(0.11, 0.025, 0.07)
	Ato2Pecas.malha(_boto_fin, corte, Vector3(0, 0.215, 0), claro)
	boto.position = _boto_pos
	boto.scale = Vector3(1.3, 1.3, 1.3)
	_exclama = Construtor.rotulo(self, "!", Vector3(0, 3.0, -7.0), 120, Color(1.0, 0.85, 0.2))
	_exclama.pixel_size = 0.008
	_exclama.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_exclama.no_depth_test = true
	_exclama.outline_size = 20
	_exclama.outline_modulate = Color(0.2, 0.05, 0.0)
	_exclama.visible = false


func _criar_hud() -> void:
	var camada := CanvasLayer.new()
	camada.name = "MinigameUI"
	camada.layer = 8
	add_child(camada)
	_cortina = ColorRect.new()
	_cortina.color = Color(0.0, 0.03, 0.06, 0.0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	_lbl_placar = Label.new()
	_lbl_placar.anchor_left = 1.0
	_lbl_placar.anchor_right = 1.0
	_lbl_placar.offset_left = -24.0
	_lbl_placar.offset_right = -24.0
	_lbl_placar.offset_top = 22.0
	_lbl_placar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_lbl_placar.add_theme_font_size_override("font_size", 28)
	_lbl_placar.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_placar.add_theme_constant_override("outline_size", 8)
	camada.add_child(_lbl_placar)
	_lbl_dica = Label.new()
	_lbl_dica.text = Celular.dica("Clique ou [E] para lançar a tarrafa", "Toque em Interagir para lançar a tarrafa")
	_lbl_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_dica.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_dica.offset_top = -150.0
	_lbl_dica.add_theme_font_size_override("font_size", 30)
	_lbl_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_dica.add_theme_constant_override("outline_size", 8)
	_lbl_dica.visible = false
	camada.add_child(_lbl_dica)
	# tela escura própria (camada 15): fica abaixo do Guia (20), então a fala da Tainá aparece
	var preta := CanvasLayer.new()
	preta.name = "Escuridao"
	preta.layer = 15
	add_child(preta)
	preta.add_child(_cortina)
	_atualizar_placar()


func _atualizar_placar() -> void:
	_lbl_placar.text = "Lances %d/%d   Tainhas %d" % [lances, TOTAL_LANCES, tainhas]


# ============================================================================ animação contínua
func _process(dt: float) -> void:
	_t += dt
	_desde_fase += dt
	if _boto_nada:
		_nadar(dt)
	if janela_aberta:
		_janela_t -= dt
		if _janela_t <= 0.0:
			_fechar_janela()
	if _puxa:
		_puxa_t = minf(_puxa_t + dt / 2.4, 1.0)
		var e := _puxa_t * _puxa_t
		var pos := _puxa_origem.lerp(_puxa_alvo, e)
		player.global_position.x = pos.x
		player.global_position.z = pos.z
	if _corda and _corda.visible and _rede_jogador and is_instance_valid(_rede_jogador):
		_esticar_corda(_corda_origem(), _rede_jogador.global_position)
	_lbl_dica.visible = fase == Fase.ESPERA or fase == Fase.JANELA
	# lance
	# (um clique que só dispensa a fala da Tainá não conta como lance cedo)
	if player and Input.is_action_just_pressed("interagir") and (fase == Fase.JANELA \
			or (fase == Fase.ESPERA and _desde_fase > 0.5 and not Guia.ocupado())):
		lancar()
	# tremidas do contador de sala e pulsos de glitch
	if fase != Fase.INTRO and fase != Fase.FIM:
		_prox_pulso -= dt
		if _prox_pulso <= 0.0:
			_prox_pulso = randf_range(5.0, 9.0)
			_tremer_contador()


func _nadar(dt: float) -> void:
	# o boto nada de um lado para o outro à frente do jogador, só a nadadeira cortada à mostra
	var alvo := Vector3(sin(_t * 0.42) * 7.0, NIVEL_AGUA - 0.5, -9.5 + sin(_t * 0.27) * 1.8)
	var d := alvo - _boto_pos
	_boto_pos += d * clampf(dt * 1.6, 0.0, 1.0)
	_boto_pos.y = NIVEL_AGUA - 0.5 + sin(_t * 2.6) * 0.05
	if d.length() > 0.05:
		_boto_yaw = lerp_angle(_boto_yaw, atan2(-d.x, -d.z), clampf(dt * 3.0, 0.0, 1.0))
	boto.position = _boto_pos
	boto.rotation.y = _boto_yaw
	_boto_corpo.rotation.x = sin(_t * 2.6 + 1.0) * 0.12


func _hud_label_pos() -> Vector2:
	var main := get_tree().get_first_node_in_group("main")
	if main and main.get("hud") and main.hud.get("lbl_sala"):
		return main.hud.lbl_sala.position
	return Vector2(24, 18)


func _restaurar_hud() -> void:
	if not is_inside_tree():
		return
	var main := get_tree().get_first_node_in_group("main")
	if main and main.get("hud") and main.hud.get("lbl_sala"):
		main.hud.lbl_sala.position = _hud_pos
		main.hud.lbl_sala.rotation = 0.0


## O contador de sala treme (e a imagem dá um pulso de glitch): este não é um lugar de verdade.
func _tremer_contador(forte := false) -> void:
	Efeitos.pulso(0.55 if forte else 0.25, 0.4 if forte else 0.28)
	var main := get_tree().get_first_node_in_group("main")
	if _shake_ativo or main == null or main.get("hud") == null or main.hud.get("lbl_sala") == null:
		return
	_shake_ativo = true
	var lbl: Label = main.hud.lbl_sala
	var base := _hud_pos
	var n := 14 if forte else 8
	for i in n:
		if not is_inside_tree() or not is_instance_valid(lbl):
			return
		var k := 9.0 if forte else 5.0
		lbl.position = base + Vector2(randf_range(-k, k), randf_range(-k, k))
		lbl.rotation = randf_range(-0.05, 0.05) * (2.0 if forte else 1.0)
		await get_tree().create_timer(0.04).timeout
	if is_instance_valid(lbl):
		lbl.position = base
		lbl.rotation = 0.0
	_shake_ativo = false


# ============================================================================ minigame
func _rodar_minigame() -> void:
	fase = Fase.INTRO
	if not pulou_intro:
		await Guia.falar("taina", [
			"Oi, guri! Aqui é a Barra do Tramandaí, no fim da tarde.",
			"Os botos empurram as tainhas até a margem. Eu sei bem... eu sou uma tainha.",
			"Quando o boto BATER A CABEÇA na água, joga a tarrafa! (clique ou E)",
			"São três lances. Vai ser rapidinho. Prometo."], true)
	var n := lance_inicial
	lances = n - 1
	_atualizar_placar()
	while n <= TOTAL_LANCES:
		var ok: bool = await _rodada(n)
		if ok:
			n += 1
	await _puxado()


## Uma rodada: o boto sinaliza e o jogador tem uma janela para lançar. Devolve true se o lance
## contou (cedo/tarde não conta e o boto sinaliza de novo). O 3º lance sempre "conta" e puxa.
func _rodada(n: int) -> bool:
	_entrar_fase(Fase.ESPERA)
	var espera := randf_range(espera_min, espera_max)
	var t := 0.0
	while t < espera:
		await get_tree().process_frame
		t += get_process_delta_time()
		if fase != Fase.ESPERA:
			return false   # lançou cedo: _lance_cedo já tratou
	var alvo := Vector3(randf_range(-2.0, 2.0), NIVEL_AGUA, -6.8)
	if n == TOTAL_LANCES:
		alvo = Vector3(player.global_position.x, NIVEL_AGUA, -5.0)   # perto demais: a hora errada
	await _boto_sinalizar(alvo, n == TOTAL_LANCES)
	return await _aguardar_lance(n)


func _entrar_fase(f: Fase) -> void:
	fase = f
	_desde_fase = 0.0


## Espera o jogador lançar durante a janela. Devolve se a rodada contou.
func _aguardar_lance(n: int) -> bool:
	while fase == Fase.JANELA and janela_aberta:
		await get_tree().process_frame
	# `lancar()` mudou a fase para LANCADO (dentro da janela) ou a janela expirou
	if fase == Fase.LANCADO:
		return true
	# janela expirou sem lance
	if n == TOTAL_LANCES:
		# no 3º a rede se lança sozinha: o jogador não precisa fazer nada
		lancar(true)
		return true
	Guia.falar("taina", ["Opa, perdeu a hora! Espera o boto bater a cabeça na água."])
	_entrar_fase(Fase.ESPERA)
	return false


## Lançar a tarrafa (E ou clique). Chamado pelo _process; público para testes.
func lancar(sozinha := false) -> void:
	if fase == Fase.ESPERA:
		_lance_cedo()
		return
	if fase != Fase.JANELA:
		return
	var n := lances + 1
	var dentro := janela_aberta or sozinha
	if not dentro:
		return   # a janela fechou neste quadro: fica em JANELA e _aguardar_lance trata como "perdeu a hora"
	janela_aberta = false
	_exclama.visible = false
	_entrar_fase(Fase.LANCADO)
	if n < TOTAL_LANCES:
		_lance_certo(n)
	else:
		_lance_errado(sozinha)


func _lance_cedo() -> void:
	# lançou antes do boto bater a cabeça: a rede cai na água vazia
	_entrar_fase(Fase.LANCADO)
	var destino_rede := Vector3(randf_range(-1.5, 1.5), NIVEL_AGUA, -7.0)
	var rede := _lancar_rede(destino_rede, 0.5)
	await get_tree().create_timer(0.7).timeout
	if is_instance_valid(rede):
		_afundar_rede(rede)
	Guia.falar("taina", ["Calma! Espera o boto bater a cabeça na água!"])
	lance_feito.emit(lances, false)
	_entrar_fase(Fase.ESPERA)


func _lance_certo(n: int) -> void:
	var rede := _lancar_rede(_alvo_lance, 0.55)
	await get_tree().create_timer(0.6).timeout
	_splash(_alvo_lance, 1.2)
	var qtd := 4 + n
	_peixes(_alvo_lance, qtd)
	tainhas += qtd
	lances = n
	_atualizar_placar()
	GameState.definir_corruption_manual(0.1 + 0.08 * n)
	if n == 1:
		Guia.falar("taina", ["Boa! Pegou umas tainhas!", "...Que bom. Que bom pra vocês."])
	else:
		Guia.falar("taina", ["Mais tainhas! Hehe... eu estou ótima, viu?", "(Eu conheço uma delas.)"])
	lance_feito.emit(n, true)
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(rede):
		_afundar_rede(rede)


func _lance_errado(_sozinha: bool) -> void:
	# o 3º lance: a rede cai perto demais e algo a puxa para o fundo, com o jogador junto
	_rede_jogador = _lancar_rede(_alvo_lance, 0.5)
	_sandalia_na_rede(_rede_jogador)
	lances = TOTAL_LANCES
	_atualizar_placar()
	lance_feito.emit(lances, true)


# ============================================================================ boto sinaliza
func _boto_sinalizar(alvo: Vector3, errado: bool) -> void:
	_alvo_lance = alvo
	_boto_nada = false
	var yaw_para_jogador := PI if errado else PI - 0.75   # de 3/4 (perfil visível); no errado, de frente
	# nada até o ponto, de frente para a margem
	var t := create_tween().set_parallel()
	t.tween_property(boto, "position", Vector3(alvo.x, NIVEL_AGUA - 0.5, alvo.z - 1.3), 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(boto, "rotation:y", boto.rotation.y + angle_difference(boto.rotation.y, yaw_para_jogador), 1.1)
	t.tween_property(_boto_corpo, "rotation:x", 0.0, 1.0)
	await t.finished
	_boto_pos = boto.position
	_boto_yaw = boto.rotation.y
	# emerge, mostrando a cabeça
	var t2 := create_tween().set_parallel()
	t2.tween_property(boto, "position:y", NIVEL_AGUA + (0.45 if errado else 0.25), 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(_boto_corpo, "rotation:x", 0.75, 0.4)
	await t2.finished
	# pescadores armam as tarrafas
	_exclama.global_position = Vector3(alvo.x, 3.2, alvo.z - 0.6)
	_exclama.visible = true
	_abrir_janela()
	await get_tree().create_timer(0.18 if not errado else 0.5).timeout
	# BATE A CABEÇA na água
	var t3 := create_tween().set_parallel()
	t3.tween_property(_boto_corpo, "rotation:x", -0.45, 0.12).set_trans(Tween.TRANS_QUAD)
	t3.tween_property(boto, "position:y", NIVEL_AGUA - 0.35, 0.12)
	await t3.finished
	_splash(Vector3(alvo.x, NIVEL_AGUA, alvo.z - 0.9), 1.0)
	Audio.sfx("splash", -4.0)
	for p in _pescadores:
		if randf() < 0.6:
			_lancar_rede_npc(p)
	if errado:
		# sinaliza de novo, devagar e olhando para o jogador: a hora errada
		await get_tree().create_timer(0.35).timeout
		var t4 := create_tween()
		t4.tween_property(_boto_corpo, "rotation:x", 0.7, 0.35)
		t4.tween_property(_boto_corpo, "rotation:x", -0.45, 0.14)
		await t4.finished
		_splash(Vector3(alvo.x, NIVEL_AGUA, alvo.z - 0.9), 1.4)
		Audio.sfx("splash", -2.0)
	# mergulha de novo e volta a nadar
	var t5 := create_tween().set_parallel()
	t5.tween_property(_boto_corpo, "rotation:x", 0.0, 0.5)
	t5.tween_property(boto, "position:y", NIVEL_AGUA - 0.5, 0.5)
	await t5.finished
	_boto_pos = boto.position
	_boto_nada = true


func _abrir_janela() -> void:
	janela_aberta = true
	_janela_t = JANELA_DUR
	_entrar_fase(Fase.JANELA)


func _fechar_janela() -> void:
	janela_aberta = false
	_exclama.visible = false


# ============================================================================ redes, respingos, peixes
func _corda_origem() -> Vector3:
	if player == null:
		return Vector3.ZERO
	return player.global_position + Vector3(0.25, 1.2, -0.3)


func _lancar_rede(destino_rede: Vector3, dur: float) -> Node3D:
	Audio.sfx("tarrafa", -3.0)
	var rede := Node3D.new()
	add_child(rede)
	var malha := CylinderMesh.new()
	malha.top_radius = 0.03
	malha.bottom_radius = 0.9
	malha.height = 0.5
	malha.radial_segments = 14
	malha.rings = 1
	malha.cap_top = false
	malha.cap_bottom = false
	var mi := Ato2Pecas.malha(rede, malha, Vector3.ZERO, _mat_rede)
	mi.name = "Rede"
	var inicio := _corda_origem()
	rede.position = inicio
	rede.scale = Vector3(0.35, 0.35, 0.35)
	var t := create_tween()
	t.tween_method(func(k: float):
		var p := inicio.lerp(destino_rede, k)
		p.y += sin(k * PI) * 2.2
		rede.position = p
		var s := lerpf(0.35, 1.7, minf(k * 1.6, 1.0))
		rede.scale = Vector3(s, lerpf(s, 0.35, k * k), s), 0.0, 1.0, dur)
	return rede


## A sandália de criança que vem na rede do 3º lance: um objeto pequeno e comum (sola azul, tira amarela), nada mais.
func _sandalia_na_rede(rede: Node3D) -> void:
	var sandalia := Node3D.new()
	sandalia.name = "Sandalia"
	sandalia.position = Vector3(0.05, -0.1, 0.0)
	sandalia.rotation_degrees = Vector3(0, 35, 12)
	rede.add_child(sandalia)
	var sola := Ato2Pecas.mat_cor(Color(0.3, 0.52, 0.9))
	var tira := Ato2Pecas.mat_cor(Color(0.95, 0.8, 0.2))
	Construtor.caixa(sandalia, Vector3(0.09, 0.025, 0.2), Vector3(0, 0, 0), sola, false)
	Construtor.caixa(sandalia, Vector3(0.09, 0.012, 0.03), Vector3(0, 0.02, -0.02), tira, false)
	Construtor.caixa(sandalia, Vector3(0.035, 0.012, 0.09), Vector3(0.0, 0.02, 0.03), tira, false)
	GameState.set_flag("viu_sandalia_barra", true)


func _afundar_rede(rede: Node3D) -> void:
	var t := create_tween().set_parallel()
	t.tween_property(rede, "position:y", NIVEL_AGUA - 1.0, 0.8)
	t.tween_property(rede, "scale", Vector3(0.3, 0.1, 0.3), 0.8)
	t.chain().tween_callback(rede.queue_free)


func _lancar_rede_npc(p: Node3D) -> void:
	var inicio := p.global_position + Vector3(0.4, 1.9, -0.4)
	var destino_rede := p.global_position + Vector3(randf_range(-2.0, 2.0), 0.0, -randf_range(4.0, 7.0))
	destino_rede.y = NIVEL_AGUA
	var rede := Node3D.new()
	add_child(rede)
	var malha := CylinderMesh.new()
	malha.top_radius = 0.03
	malha.bottom_radius = 0.8
	malha.height = 0.4
	malha.radial_segments = 12
	malha.rings = 1
	malha.cap_top = false
	malha.cap_bottom = false
	Ato2Pecas.malha(rede, malha, Vector3.ZERO, _mat_rede)
	rede.position = inicio
	rede.scale = Vector3(0.4, 0.4, 0.4)
	var t := create_tween()
	t.tween_method(func(k: float):
		var q := inicio.lerp(destino_rede, k)
		q.y += sin(k * PI) * 1.8
		rede.position = q
		var s := lerpf(0.4, 1.5, minf(k * 1.6, 1.0))
		rede.scale = Vector3(s, lerpf(s, 0.3, k * k), s), 0.0, 1.0, 0.6)
	t.tween_callback(func(): _splash(destino_rede, 0.7))
	t.tween_interval(0.7)
	t.tween_callback(func(): _afundar_rede(rede))


func _splash(pos: Vector3, tam: float) -> void:
	var anel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.35
	tor.outer_radius = 0.42
	tor.rings = 16
	tor.ring_segments = 4
	anel.mesh = tor
	anel.material_override = _mat_espuma
	anel.position = Vector3(pos.x, NIVEL_AGUA + 0.04, pos.z)
	anel.scale = Vector3(0.4, 0.2, 0.4)
	add_child(anel)
	var t := create_tween().set_parallel()
	t.tween_property(anel, "scale", Vector3(3.2, 0.2, 3.2) * tam, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(anel, "position:y", NIVEL_AGUA - 0.05, 1.1)
	t.chain().tween_callback(anel.queue_free)
	var gota := SphereMesh.new()
	gota.radius = 0.06
	gota.height = 0.12
	gota.radial_segments = 6
	gota.rings = 3
	for i in 8:
		var g := MeshInstance3D.new()
		g.mesh = gota
		g.material_override = _mat_espuma
		g.position = Vector3(pos.x, NIVEL_AGUA, pos.z)
		add_child(g)
		var dir := Vector3(randf_range(-1.0, 1.0), 0.0, randf_range(-1.0, 1.0)) * 0.6 * tam
		var alto := randf_range(0.6, 1.3) * tam
		var tg := create_tween()
		tg.tween_method(func(k: float):
			g.position = Vector3(pos.x, NIVEL_AGUA, pos.z) + dir * k + Vector3(0, sin(k * PI) * alto, 0), 0.0, 1.0, 0.7)
		tg.tween_callback(g.queue_free)


func _peixes(pos: Vector3, qtd: int) -> void:
	var peixe := SphereMesh.new()
	peixe.radius = 0.5
	peixe.height = 1.0
	peixe.radial_segments = 8
	peixe.rings = 4
	for i in qtd:
		var f := MeshInstance3D.new()
		f.mesh = peixe
		f.material_override = _mat_peixe
		f.scale = Vector3(0.07, 0.07, 0.3)
		f.position = Vector3(pos.x, NIVEL_AGUA, pos.z)
		add_child(f)
		var dir := Vector3(randf_range(-1.1, 1.1), 0.0, randf_range(-1.1, 1.1))
		var alto := randf_range(0.8, 1.6)
		var atraso := i * 0.06
		var tg := create_tween()
		tg.tween_interval(atraso)
		tg.tween_method(func(k: float):
			f.position = Vector3(pos.x, NIVEL_AGUA, pos.z) + dir * k + Vector3(0, sin(k * PI) * alto, 0)
			f.rotation.z = k * 6.0, 0.0, 1.0, 0.9)
		tg.tween_callback(f.queue_free)


func _esticar_corda(a: Vector3, b: Vector3) -> void:
	var d := b - a
	var comp := d.length()
	if comp < 0.01:
		return
	_corda.global_position = a + d * 0.5
	_corda.look_at(b, Vector3.UP)
	_corda.scale = Vector3(1, 1, comp)


# ============================================================================ o 3º lance: o rio puxa
func _puxado() -> void:
	_entrar_fase(Fase.PUXADO)
	player.pode_mover = false
	await get_tree().create_timer(0.7).timeout   # a rede termina de cair
	puxado.emit()
	GameState.definir_corruption_manual(0.35)    # o pico da Barra fica abaixo do apagão do fim da visita
	Audio.sfx("agua_puxa")
	player.pode_mover = false
	# a corda estica entre o jogador e a rede
	var fio := BoxMesh.new()
	fio.size = Vector3(0.03, 0.03, 1.0)   # comprimento em z: look_at + scale.z esticam a corda
	_corda = MeshInstance3D.new()
	_corda.mesh = fio
	_corda.material_override = Ato2Pecas.mat_cor(Color(0.1, 0.07, 0.05), true)
	add_child(_corda)
	_tremer_contador(true)
	Efeitos.pulso(0.7, 0.6)
	# todos os pescadores se viram para o jogador
	for p in _pescadores:
		var d := player.global_position - p.global_position
		var yaw := atan2(-d.x, -d.z)
		create_tween().tween_property(p, "rotation:y", p.rotation.y + angle_difference(p.rotation.y, yaw), 0.7)
	# o rio puxa: o jogador é arrastado para a água, olhando para baixo
	if _barreira_frente:
		_barreira_frente.queue_free()
		_barreira_frente = null
	_puxa_origem = player.global_position
	_puxa_alvo = Vector3(player.global_position.x, 0.0, -10.5)
	_puxa_t = 0.0
	_puxa = true
	create_tween().tween_property(player.cabeca, "rotation:x", -0.55, 2.2).set_trans(Tween.TRANS_SINE)
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(env):
		var te := create_tween().set_parallel()
		te.tween_property(env, "fog_light_color", Color(0.02, 0.07, 0.1), 1.2)
		te.tween_property(env, "fog_depth_begin", 0.5, 1.2)
		te.tween_property(env, "fog_depth_end", 5.0, 1.2)
		te.tween_property(env, "fog_sky_affect", 1.0, 0.8)   # debaixo d'água não há céu
	await get_tree().create_timer(0.8).timeout
	_tremer_contador(true)
	var tc := create_tween()
	tc.tween_property(_cortina, "color:a", 1.0, 1.0)
	await tc.finished
	_puxa = false
	await _final()


func _final() -> void:
	_entrar_fase(Fase.FIM)
	await Guia.falar("taina", ["...era eu na rede?", "...e uma sandalinha. Pequena. De criança."], true)
	GameState.set_flag("viu_flashback_barra", true)
	GameState.entrar_sala(sala_global_volta())
	terminou.emit()
	var cena := destino
	if not ResourceLoader.exists(cena):
		push_warning("Barra: destino '%s' ainda não existe; usando o nível de teste." % cena)
		cena = "res://world/niveis/teste.tscn"
	await Transicao.ir_para(cena, spawn_destino)
