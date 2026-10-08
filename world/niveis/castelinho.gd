extends Node3D
## Nível "Castelinho" nas QUATRO VISITAS (docs/V2_ROTEIRO.md §2 e §3). É o mesmo prédio e as mesmas salas físicas; o que
## muda é o estado: hora e clima, painéis, eventos, objetos e os discos do Visor. `GameState.visita` (1..4) manda.
##
##   visita 1  manhã de sol, corrupção 0, 3 sementes discretas, Visor + disco 1950 na sala 10, diploma
##   visita 2  fim de tarde e vento; painéis _v2; telefone, engasgo, recorte que cai, Barra; disco 1967 no Acervo;
##             diploma com "TITO", apagão e o balde vermelho no trono
##   visita 3  noite, lanterna (Quico); cartazes PROCURA-SE; porta para 1950 (Ato II); disco 1975 no topo da Torre A;
##             marcas de altura (só em 1975); pinguim, armadura; fita zebrada na saída (em 1975 ela está aberta)
##   visita 4  madrugada com chuva; painéis só com desenhos; disco 2019 atrás de um painel solto; porta zebrada no
##             hall (sala 80) e escada na Sala Medieval (só em 2019): descem para o porão
##
## Numeração: os gatilhos são numerados pela sala BASE (1..22 + 23..25 do corredor). `_global(base)` converte para a sala
## global da visita (visitas 1 a 3 = base + 0/22/44; visita 4 usa V4_SALAS, que comprime as 22 bases nas salas 67 a 79 e
## deixa a 80 para a porta zebrada). As bases 23, 24 e 25 (porta de saída, Sala Medieval em 1975, corredor de 1975) contam
## como a base 22 (a última sala da visita): a 23 global de cada visita já é a primeira da seguinte.
##
## Marcadores: Spawn (calçada), Checkpoint_<base> e Checkpoint_<global da visita atual>, Spawn_volta_barra (base 15),
## Spawn_volta_ato2 (topo da Torre A, base 17) e câmeras Cam_* de conferência (tests/captura_cam.gd).
## Eventos: cada um acontece uma vez por visita (flags "evt_v<visita>_<nome>" em GameState, persistem no save).
## Épocas: tudo do museu só existe em E2020; o Visor mostra as outras (E1950, E1967, E1975, E2019) segurando Q.

const E1950 := 0   # GameState.Epoca (enum) como inteiros, para poder usar em const
const E1975 := 1
const E2019 := 2
const E2020 := 3
const E1967 := 4

## Épocas FORA do presente (o Visor): [céu topo, céu horizonte, cor do Sol, energia do Sol, pitch, yaw, cor ambiente,
## energia amb., cor névoa, densidade névoa]. O presente (E2020) de cada visita está em PRESENTE.
const AMBIENTES := {
	# 1975: fim de tarde de verdade, Sol baixo a oés-noroeste (sombras longas para o leste)
	E1975: [Color(0.42, 0.38, 0.58), Color(1.0, 0.66, 0.4), Color(1.0, 0.6, 0.3), 1.3, -16.0, -110.0, Color(0.86, 0.66, 0.6), 0.5, Color(0.96, 0.7, 0.5), 0.006],
	E1950: [Color(0.52, 0.52, 0.56), Color(0.76, 0.73, 0.68), Color(0.88, 0.84, 0.78), 0.55, -40.0, 40.0, Color(0.66, 0.64, 0.62), 0.7, Color(0.74, 0.71, 0.66), 0.012],
	# 2019: nublado e úmido (a aérea de 2019 não tem neblina: névoa só para o fundo ficar cinza)
	E2019: [Color(0.5, 0.54, 0.56), Color(0.72, 0.74, 0.73), Color(0.86, 0.88, 0.86), 0.55, -50.0, 40.0, Color(0.64, 0.67, 0.67), 0.62, Color(0.7, 0.73, 0.72), 0.0055],
	# 1967: tarde de verão na obra, areia clara e céu limpo (licença criativa, ver castelinho/LEIAME.md)
	E1967: [Color(0.38, 0.58, 0.86), Color(0.88, 0.88, 0.84), Color(1.0, 0.92, 0.76), 1.3, -42.0, -70.0, Color(0.82, 0.78, 0.72), 0.6, Color(0.88, 0.88, 0.84), 0.0035],
}

## O PRESENTE (E2020) por visita.
const PRESENTE := {
	# 1: manhã clara, Sol alto do sul-sudeste (fachada sul bem iluminada, leste a meia-luz, oeste na sombra)
	1: [Color(0.4, 0.6, 0.88), Color(0.8, 0.88, 0.96), Color(1.0, 0.96, 0.88), 1.25, -48.0, 25.0, Color(0.8, 0.78, 0.8), 0.56, Color(0.82, 0.87, 0.94), 0.0022],
	# 2: fim de tarde alaranjado e ventania
	2: [Color(0.46, 0.4, 0.62), Color(1.0, 0.62, 0.36), Color(1.0, 0.58, 0.28), 1.15, -13.0, -70.0, Color(0.88, 0.66, 0.58), 0.5, Color(0.96, 0.66, 0.46), 0.0065],
	# 3: noite com lua; o que ilumina é a lanterna, a luz da rua (poças de sódio) e o museu aceso por dentro.
	#    Revisão V2: ambiente mais baixo (0,42 -> 0,34): por dentro a noite passa a depender das poucas lâmpadas e da lanterna.
	3: [Color(0.03, 0.04, 0.1), Color(0.11, 0.13, 0.24), Color(0.55, 0.65, 1.0), 0.3, -50.0, 30.0, Color(0.32, 0.38, 0.62), 0.34, Color(0.07, 0.09, 0.17), 0.012],
	# 4: madrugada de chuva, céu fechado. Revisão V2: a névoa era quase preta e densa (apagava o prédio); agora é um
	#    cinza-azulado de chuva, mais claro que o prédio, que destaca as silhuetas (o Castelinho escuro contra a névoa),
	#    e o ambiente caiu (0,62 -> 0,3): por dentro mandam a lanterna, duas lâmpadas falhando e os relâmpagos.
	4: [Color(0.1, 0.12, 0.15), Color(0.27, 0.3, 0.34), Color(0.5, 0.6, 0.7), 0.22, -55.0, 20.0, Color(0.32, 0.37, 0.44), 0.3, Color(0.17, 0.2, 0.24), 0.03],
}

## Nuvens (shaders/ceu_nuvens.gdshader): [cor da nuvem, cor da sombra da nuvem, cobertura (menor = mais nuvem),
## deslocamento da textura, força do disco do Sol/Lua].
const CEUS := {
	E1975: [Color(1.0, 0.8, 0.6), Color(0.62, 0.42, 0.5), 0.6, Vector2(0.37, 0.11), 1.0],
	E1950: [Color(0.82, 0.8, 0.76), Color(0.62, 0.61, 0.6), 0.2, Vector2(0.61, 0.43), 0.0],
	E2019: [Color(0.74, 0.77, 0.76), Color(0.54, 0.58, 0.58), 0.2, Vector2(0.2, 0.71), 0.0],
	E1967: [Color(1.0, 1.0, 1.0), Color(0.72, 0.78, 0.9), 0.66, Vector2(0.52, 0.3), 1.0],
}
const CEUS_PRESENTE := {
	1: [Color(1.0, 1.0, 1.0), Color(0.7, 0.76, 0.88), 0.6, Vector2(0.0, 0.0), 1.0],
	2: [Color(1.0, 0.78, 0.58), Color(0.6, 0.42, 0.5), 0.55, Vector2(0.25, 0.3), 1.0],
	3: [Color(0.2, 0.22, 0.36), Color(0.08, 0.09, 0.18), 0.52, Vector2(0.4, 0.2), 0.5],
	4: [Color(0.2, 0.23, 0.27), Color(0.1, 0.12, 0.15), 0.1, Vector2(0.7, 0.5), 0.0],
}

## Lâmpadas do museu por visita: [multiplicador de energia, máximo de OmniLight3D ligadas]. Com a lanterna (SpotLight3D)
## e a luz do Sol/Lua, o orçamento da web é de 6 luzes: 1 + 4 + 1 nas visitas 3 e 4.
## Revisão V2: a escala por dentro era plana (V1 = V2, V3 quase igual). Agora: V2 é fim de expediente (lâmpadas um pouco
## mais fracas e âmbar); V3 é o museu fechado à noite (3 lâmpadas fracas: entre as poças fica escuro e a lanterna conta);
## V4 tem só 2 lâmpadas frias que falham.
const LAMPADAS := {1: [1.0, 5], 2: [0.76, 5], 3: [0.62, 3], 4: [0.55, 2]}
const COR_LAMPADA := {1: Color(1.0, 0.8, 0.52), 2: Color(1.0, 0.6, 0.3), 3: Color(1.0, 0.74, 0.46), 4: Color(0.8, 0.88, 1.0)}
## Luz da rua por visita (cor da cabeça dos postes): apagada de dia, acendendo no fim de tarde, sódio aceso à noite e
## apagada na madrugada (falta de luz: lá fora só os relâmpagos e a lanterna).
const COR_POSTE := {1: Color(0.78, 0.78, 0.74), 2: Color(1.0, 0.82, 0.55), 3: Color(1.0, 0.74, 0.36), 4: Color(0.16, 0.16, 0.17)}
const COR_SODIO := Color(1.0, 0.66, 0.3)
## Janelas acesas vistas de fora na visita 3 (o museu "fechado" com luz lá dentro chama o jogador para a porta).
const COR_JANELA_NOITE := Color(1.0, 0.68, 0.32)

## Visita 4: as 22 salas base comprimidas na numeração 67..79 (a 80 é a porta zebrada do hall).
const V4_SALAS := {
	1: 67, 2: 68, 3: 68, 4: 69, 5: 70, 6: 70, 7: 71, 8: 72, 9: 73, 10: 74, 11: 75, 12: 76, 13: 77, 14: 77, 15: 77,
	16: 77, 17: 77, 18: 77, 19: 77, 20: 77, 21: 78, 22: 79,
}
const SALA_V4_PORTA := 80

## Marcadores de checkpoint por sala base (V2 §8.1; SALAS_CHECKPOINT em game_state.gd são os números globais).
const BASES_CHECKPOINT := {1: Vector3(-23.0, 0.1, 1.5), 8: Vector3(-24.0, 0.1, -12.9), 10: Vector3(-15.5, 0.1, -21.8),
	13: Vector3(-8.7, 0.1, -15.8), 16: Vector3(-13.4, 0.1, -19.55), 17: Vector3(-19.4, 6.9, -12.6)}

## Visita 4: o desenho que cada painel mostra (V2 §3.4 e §5), cada vez mais perturbador ao longo do caminho.
const V4_DESENHOS := {
	"p01": "desenho_2", "p02": "desenho_2", "p03": "desenho_3", "p04": "desenho_3", "p05": "desenho_4", "p06": "desenho_4",
	"p07": "desenho_4", "p08": "desenho_5", "p09": "desenho_5", "p10": "desenho_5", "p11": "desenho_5", "p12": "desenho_5",
	"p13": "desenho_6", "p14": "desenho_6", "p15": "desenho_6", "p16": "desenho_6", "p17": "desenho_6", "p18": "desenho_7",
	"p19": "desenho_7", "p20": "desenho_7", "p21": "desenho_7",
}
## Cartazes de PROCURA-SE colados por cima de painéis (visita 3 em diante).
const CARTAZES_V3 := ["p01", "p04", "p07", "p09", "p11", "p13", "p18", "p20"]
const CARTAZES_V4 := ["p02", "p06", "p10", "p14"]

const POS_PORTA_ATO2 := Vector3(-12.1, 0.0, -18.0)     # visita 3: porta nova na parede oeste do Salão de Arte (base 11)
const POS_PORTA_PORAO := Vector3(-14.0, 0.0, -13.77)    # visita 4: porta zebrada no hall (sala 80)
const POS_ESCADA_2019 := Vector3(-14.0, 0.0, -26.8)     # visita 4: escada do chão da Sala Medieval (só em 2019)
const POS_DISCO_1967 := Vector3(-5.9, 1.01, -19.8)
const POS_DISCO_1975 := Vector3(-20.6, 7.7, -12.2)      # sobre um pedestal no topo da Torre A (piso em y = 6,8)
const POS_PAINEL_SOLTO := Vector3(-26.35, 1.45, -13.0)  # Sala dos Povos: o painel p08 solto da parede
const POS_ARMADURA := Vector3(-9.25, 0.0, -28.2)
const POS_PORTA_SAIDA := Vector3(-10.2, 1.2, -29.2)

const X_COR := EntornoCastelinho.X_CORREDOR
const Z_COR_FIM := EntornoCastelinho.Z_CORREDOR_FIM

var castelo: Castelinho
var entorno: Dictionary
var player: Player
var sol: DirectionalLight3D
var ambiente: Environment
var ceu: ShaderMaterial
var vento: CPUParticles3D
var chuva: CPUParticles3D
var visita := 1                       # visita deste nível (lida de GameState uma vez, em _ready)

var _sombras: SombrasChao             # sombras pintadas no chão (uma imagem por época)
var _luzes: Array = []                # [{no: OmniLight3D, pos: Vector3, base: float}]
var _t_luzes := 0.0
var _t := 0.0
var _paineis: Dictionary = {}         # id BASE ("p05") -> Painel3D (ou nó de desenho)
var _triggers := {}                   # sala base -> SalaTrigger
var _props: Malha                     # postes dos painéis externos, marcas de arrasto
var _pinguim: Node3D
var _armadura: Node3D
var _recortes := {}                   # nome -> Node3D
var _telefone: Interagivel
var _telefone_tocando := false
var _mural: Interagivel
var _porta_saida: Interagivel         # porta da Sala Medieval (visitas 1 e 2: sair; 3 e 4: em reforma)
var _porta_saida_1975: Interagivel    # porta do fim do corredor de 1975 (visita 3: leva à visita 4)
var _porta_ato2: Interagivel
var _porta_porao: Interagivel
var _escada_2019: Interagivel
var _bloqueio_escada: StaticBody3D
var _discos_chao := {}                # época -> [raiz, interagível]
var _balde: Node3D
var _passaporte_itens := {}           # id -> [raiz, interagível] dos objetos do Passaporte ainda não achados (visita 1)
var _passaporte_falando := false
var _desenhos := {}                   # nome -> nó
var _tito: Node3D                     # Tito vivo (E1967)
var _tito_visor: Node3D               # Tito "no canto da sala", só dentro do Visor (visitas 3 e 4)
var _tito_corredor: Node3D            # visita 4: Tito de costas no fim do corredor; some quando o jogador o encara
var _tito_corredor_olhado := 0.0
var _pegadas_v4: Node3D               # visita 4: pegadas pequenas e molhadas até o mural (Sala do Pescador)
var _t_apito := 0.0
var _t_goteira := 4.0
var _armadura_estado := 0             # 0 = nunca olhou, 1 = olhou, 2 = desviou o olhar, 3 = apareceu
var _quico19_pendente := false
var _quico_lanterna: Node3D
var _saindo_barra := false
var _saindo_visita := false
var _saindo_ato2 := false
var _saindo_porao := false
var _porta_falando := false
var _figura_v4: FiguraBranca          # perseguidora criada sob demanda quando o Visor estoura (visita 4)
var _visor_v4: Visor
var _persegue_id := 0                 # invalida o temporizador de uma perseguição anterior
var persegue_s := 12.0           # s que a Figura persegue na visita 4 (o Visor fica bloqueado por 10 s)
var _painel_solto: Node3D
var _lampada_fase := 0.0
var _t_relampago := 6.0               # visita 4: segundos até o próximo relâmpago
var _clarao := 0.0                    # 0..1: força do relâmpago neste quadro
var _vidros: Array = []               # materiais de vidro do prédio (acesos por fora na visita 3)
var _janelas_acesas := -1             # -1 = ainda não aplicado; 0/1 = estado atual


func _ready() -> void:
	visita = clampi(GameState.visita, 1, 4)
	_montar_ambiente()
	castelo = Castelinho.new()
	castelo.name = "Predio"
	add_child(castelo)
	entorno = EntornoCastelinho.construir(self, castelo)
	_montar_sombras()
	_marcadores()
	_criar_luzes()
	_montar_triggers()
	_montar_objetos()
	_montar_paineis()
	_montar_props()
	_montar_vento()
	_montar_chuva()
	_montar_luz_da_rua()
	_montar_visita()
	_montar_epoca_1967()
	GameState.epoca_mudou.connect(_on_epoca)
	_on_epoca(GameState.epoca)


func iniciar(p: Player) -> void:
	player = p
	GameState.flags.erase("saindo_para_barra")      # saves antigos podem ter a flag presa
	var visor := Visor.instalar(self)
	if visita == 4 and visor and visor.has_signal("figura_atravessou") and not visor.figura_atravessou.is_connected(_on_figura_atravessou):
		visor.figura_atravessou.connect(_on_figura_atravessou)
		_visor_v4 = visor
	_ambiente_sonoro()
	if GameState.flag("porta_entrada_aberta"):
		_abrir_porta_entrada(true)
	_atualizar_luzes()
	if visita >= 3 and GameState.flag("tem_lanterna"):
		player.lanterna.visible = not GameState.flag("lanterna_desligada")
	# volta da Barra (visita 2): os gatilhos 13/14 não podem derrubar o contador de 15
	# (também ao "Continuar" depois da volta: antes o gatilho 13 voltava a valer e a sala caía de 38 para 35)
	if visita == 2 and GameState.flag("viu_flashback_barra"):
		if _triggers.has(13):
			_triggers[13].monitoring = false
		if not GameState.flag(_chave("sala15")):
			GameState.entrar_sala(_global(15))
			if _uma_vez("sala15"):
				_evt_sala15()
	# volta do Ato II (visita 3): o jogador nasce no topo da Torre A; a escada passa a ficar aberta
	var mk := find_child("Spawn_volta_ato2", true, false) as Node3D
	if visita == 3 and mk and player.global_position.distance_to(mk.global_position) < 2.5:
		_ato2_concluido()


## Pontos de vista para o "aquecimento" feito pelo main.gd atrás da tela de carregamento (o 1º quadro de cada
## material compila o shader): interiores, torre, e uma vista em cada época (1950, 1967, 1975, 2019).
func pontos_aquecer() -> Array:
	var lista: Array = []
	for par in [["Cam_hall", E2020], ["Cam_corredor", E2020], ["Cam_salaarte", E2020], ["Cam_medieval", E2020],
			["Cam_topo_torre", E2020], ["Cam_nucleo1950", E1950], ["Cam_obra1967", E1967], ["Cam_corredor1975", E1975],
			["Cam_aerea2019", E2019]]:
		var mk := find_child(par[0], false, false) as Node3D
		if mk:
			lista.append({"transform": mk.global_transform, "epoca": par[1]})
	return lista


# ================================================================== utilitários da visita
## Sala global de uma sala BASE na visita deste nível (ver o cabeçalho).
func _global(base: int) -> int:
	if visita == 4:
		return V4_SALAS.get(base, 79)
	return GameState.sala_global(mini(base, GameState.SALAS_POR_VISITA))


func _chave(nome: String) -> String:
	return "evt_v%d_%s" % [visita, nome]


## Cada evento acontece uma única vez por visita.
func _uma_vez(nome: String) -> bool:
	var chave := _chave(nome)
	if GameState.flag(chave):
		return false
	GameState.set_flag(chave, true)
	return true


## Classe global do projeto (class_name) por nome, ou null: as telas VolteSempre/Telefone são de outro agente e
## podem ainda não existir; o Castelinho tem um plano B para cada uma.
static func _classe(nome: String) -> Script:
	for d in ProjectSettings.get_global_class_list():
		if d.get("class", "") == nome:
			return load(d["path"]) as Script
	return null


# ================================================================== céu, Sol/Lua, névoa, vento, chuva
func _montar_ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	ceu = ShaderMaterial.new()
	ceu.shader = preload("res://shaders/ceu_nuvens.gdshader")
	var tn := Castelinho._tex("nuvens")
	if tn:
		ceu.set_shader_parameter("nuvens", tn)
	var sky := Sky.new()
	sky.sky_material = ceu
	sky.radiance_size = Sky.RADIANCE_SIZE_32
	ambiente.background_mode = Environment.BG_SKY
	ambiente.sky = sky
	ambiente.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	ambiente.fog_enabled = true
	ambiente.fog_sky_affect = 0.4
	ambiente.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	we.environment = ambiente
	add_child(we)
	sol = DirectionalLight3D.new()
	sol.name = "Sol"
	sol.shadow_enabled = false
	sol.light_cull_mask = 1       # só a camada 1: o interior (camada 2) não recebe Sol
	add_child(sol)


func _preset(e: int) -> Array:
	return PRESENTE[visita] if e == E2020 else AMBIENTES.get(e, PRESENTE[1])


func _preset_ceu(e: int) -> Array:
	return CEUS_PRESENTE[visita] if e == E2020 else CEUS.get(e, CEUS_PRESENTE[1])


func _montar_vento() -> void:
	vento = CPUParticles3D.new()
	vento.name = "VentoDeAreia"
	vento.amount = 140
	vento.lifetime = 2.2
	vento.local_coords = false
	vento.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	vento.emission_box_extents = Vector3(18, 3, 18)
	vento.direction = Vector3(1, 0.05, -0.4)
	vento.spread = 8.0
	vento.initial_velocity_min = 11.0
	vento.initial_velocity_max = 16.0
	vento.gravity = Vector3.ZERO
	var qm := BoxMesh.new()
	qm.size = Vector3(0.5, 0.012, 0.04)
	vento.mesh = qm
	vento.material_override = Castelinho.mat_luz(Color(0.86, 0.78, 0.6, 1.0), 0.0)
	add_child(vento)
	Epocas.marcar(vento, [E1950, E1967])       # a areia voa em 1950 e em 1967 (sem prédio em volta)


## Chuva da visita 4 (partículas simples que seguem o jogador; só no presente e fora do prédio).
func _montar_chuva() -> void:
	if visita != 4:
		return
	chuva = CPUParticles3D.new()
	chuva.name = "Chuva"
	chuva.amount = 360
	chuva.lifetime = 0.75
	chuva.local_coords = false
	chuva.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	chuva.emission_box_extents = Vector3(11, 0.1, 11)
	chuva.direction = Vector3(0.18, -1.0, 0.06)
	chuva.spread = 2.5
	chuva.initial_velocity_min = 15.0
	chuva.initial_velocity_max = 19.0
	chuva.gravity = Vector3.ZERO
	var qm := BoxMesh.new()
	qm.size = Vector3(0.012, 0.42, 0.012)
	chuva.mesh = qm
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0.72, 0.82, 0.95, 0.55)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	chuva.material_override = mt
	chuva.position = Vector3(-15.0, 9.0, -12.0)
	add_child(chuva)
	Epocas.marcar(chuva, [E2020])


## Luz da rua (revisão V2): a cabeça dos postes muda de cor por visita (COR_POSTE) e, na visita 3, cada poste ganha
## uma poça de luz de sódio no chão e um cone de luz fraco no ar: a noite fica bonita e o caminho da calçada até a
## entrada fica legível. Tudo sem luz de verdade (o orçamento da web é de 6 luzes): 1 malha aditiva para as poças e
## 1 MultiMesh para os cones (2 draw calls).
func _montar_luz_da_rua() -> void:
	var cabeca := Castelinho.mat_luz(Color(1.0, 0.95, 0.8), 1.0)
	cabeca.albedo_color = COR_POSTE[visita]
	if visita != 3:
		return
	var tex := _tex_radial(64)
	var m_poca := StandardMaterial3D.new()
	m_poca.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_poca.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m_poca.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_poca.albedo_texture = tex
	m_poca.albedo_color = Color(COR_SODIO.r, COR_SODIO.g, COR_SODIO.b, 0.85)
	m_poca.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m_poca.disable_receive_shadows = true
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := 4.6
	for p in EntornoCastelinho.POSTES:
		var c := Vector3(p.x - 1.35, 0.17, p.z)
		var a := [c + Vector3(-r, 0, -r), c + Vector3(r, 0, -r), c + Vector3(r, 0, r), c + Vector3(-r, 0, r)]
		var uv := [Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1)]
		for i in [0, 1, 2, 0, 2, 3]:
			st.set_normal(Vector3.UP)
			st.set_uv(uv[i])
			st.add_vertex(a[i])
	var mi := MeshInstance3D.new()
	mi.name = "PocasDeLuz"
	mi.mesh = st.commit()
	mi.material_override = m_poca
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	Epocas.marcar(mi, [E2020])
	# cones: cilindro aberto, transparente em cima e embaixo (textura em gradiente vertical)
	var cone := CylinderMesh.new()
	cone.top_radius = 0.18
	cone.bottom_radius = 2.6
	cone.height = 6.6
	cone.radial_segments = 10
	cone.rings = 1
	cone.cap_top = false
	cone.cap_bottom = false
	var m_cone := StandardMaterial3D.new()
	m_cone.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_cone.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m_cone.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_cone.cull_mode = BaseMaterial3D.CULL_DISABLED
	m_cone.albedo_texture = _tex_gradiente_v(32)
	m_cone.albedo_color = Color(COR_SODIO.r, COR_SODIO.g * 0.9, COR_SODIO.b * 0.8, 0.075)
	m_cone.disable_receive_shadows = true
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = cone
	mm.instance_count = EntornoCastelinho.POSTES.size()
	for i in mm.instance_count:
		var p: Vector3 = EntornoCastelinho.POSTES[i]
		mm.set_instance_transform(i, Transform3D(Basis(), Vector3(p.x - 1.35, 6.72 - cone.height * 0.5, p.z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "ConesDeLuz"
	mmi.multimesh = mm
	mmi.material_override = m_cone
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	Epocas.marcar(mmi, [E2020])
	# vidros do prédio (Castelinho.mat_vidro já vem com a emissão ligada em preto): só a cor muda depois
	for k in ["vidro", "vidro_verde", "vidro_ambar"]:
		var mt := castelo.m.get(k) as StandardMaterial3D
		if mt:
			mt.emission_energy_multiplier = 1.2 if k == "vidro" else 1.1
			_vidros.append(mt)


## Mancha radial suave (centro claro, borda transparente), em poucos tons: o pixel aparece, como no resto do jogo.
static func _tex_radial(n: int) -> ImageTexture:
	var img := Image.create(n, n, false, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var d := Vector2(x + 0.5 - n * 0.5, y + 0.5 - n * 0.5).length() / (n * 0.5)
			var a := clampf(1.0 - d, 0.0, 1.0)
			a = floorf(pow(a, 1.6) * 6.0) / 6.0
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Gradiente vertical para o cone de luz: forte perto da lâmpada (v = 0), some no chão (v = 1).
static func _tex_gradiente_v(n: int) -> ImageTexture:
	var img := Image.create(4, n, false, Image.FORMAT_RGBA8)
	for y in n:
		var v := float(y) / float(n - 1)
		var a := pow(1.0 - v, 1.3) * smoothstep(0.0, 0.06, v)
		for x in 4:
			img.set_pixel(x, y, Color(1, 1, 1, a))
	return ImageTexture.create_from_image(img)


## Visita 3: os vidros do museu brilham quando o jogador está do lado de fora (de dentro, a janela é noite).
func _atualizar_janelas() -> void:
	if _vidros.is_empty():
		return
	var acesas := 1 if (GameState.epoca == E2020 and not _jogador_dentro()) else 0
	if acesas == _janelas_acesas:
		return
	_janelas_acesas = acesas
	for mt in _vidros:
		(mt as StandardMaterial3D).emission = COR_JANELA_NOITE if acesas == 1 else Color.BLACK


## Visita 4: relâmpagos. A cada 7 a 15 s, dois clarões curtos (o segundo mais fraco) acendem o céu, a névoa e o
## ambiente: por um instante o Castelinho aparece inteiro, escuro e errado contra o céu. O trovão vem 0,6 a 2 s depois.
## Dentro do prédio o clarão é menor (entra pelas janelas). Só no presente (no Visor a época é outra).
func _relampagos(dt: float) -> void:
	if GameState.epoca != E2020:
		_clarao = 0.0
		return
	_t_relampago -= dt
	if _t_relampago <= 0.0:
		_t_relampago = randf_range(7.0, 15.0)
		_disparar_relampago()
	if _clarao <= 0.0:
		return
	var a: Array = PRESENTE[4]
	var dentro := _jogador_dentro()
	var k := _clarao * (0.45 if dentro else 1.0)
	ambiente.ambient_light_energy = lerpf(a[7], 2.2, k)
	ambiente.ambient_light_color = (a[6] as Color).lerp(Color(0.7, 0.78, 0.95), k)
	ambiente.fog_light_color = (a[8] as Color).lerp(Color(0.62, 0.68, 0.8), k)
	sol.light_energy = lerpf(a[3], 2.4, k)
	ceu.set_shader_parameter("cor_horizonte", (a[1] as Color).lerp(Color(0.72, 0.78, 0.9), k))
	ceu.set_shader_parameter("cor_topo", (a[0] as Color).lerp(Color(0.42, 0.46, 0.58), k))


func _disparar_relampago() -> void:
	var tw := create_tween()
	tw.tween_property(self, "_clarao", 1.0, 0.03)
	tw.tween_property(self, "_clarao", 0.15, 0.07)
	tw.tween_property(self, "_clarao", 0.7, 0.04)
	tw.tween_property(self, "_clarao", 0.0, 0.45)
	tw.tween_callback(_fim_relampago)
	var atraso := randf_range(0.6, 2.0)
	get_tree().create_timer(atraso).timeout.connect(func(): Audio.sfx("trovao", -2.0 - atraso * 3.0, randf_range(0.85, 1.05)))


func _fim_relampago() -> void:
	_clarao = 0.0
	if GameState.epoca == E2020:
		_on_epoca(E2020)


func _ambiente_sonoro() -> void:
	match visita:
		1:
			Audio.musica("jingle")
		2:
			Audio.musica("jingle")
		3:
			# depois do Ato II o jingle desafina de vez (jingle_2, roteiro §3.3); antes dele, a versão da corrupção
			Audio.musica("jingle_2" if GameState.flag("v3_ato2_feito") else "jingle")
		4:
			Audio.musica("")      # quase sem música: só chuva, vento e goteiras


func _on_epoca(e: int) -> void:
	var a: Array = _preset(e)
	var cn: Array = _preset_ceu(e)
	ceu.set_shader_parameter("cor_topo", a[0])
	ceu.set_shader_parameter("cor_horizonte", a[1])
	ceu.set_shader_parameter("cor_chao", (a[1] as Color).darkened(0.25))
	ceu.set_shader_parameter("cor_nuvem", cn[0])
	ceu.set_shader_parameter("cor_nuvem_sombra", cn[1])
	ceu.set_shader_parameter("cobertura", cn[2])
	ceu.set_shader_parameter("deslocamento", cn[3])
	ceu.set_shader_parameter("sol_forca", cn[4])
	sol.light_color = a[2]
	sol.light_energy = a[3]
	sol.rotation_degrees = Vector3(a[4], a[5], 0)
	ambiente.ambient_light_color = a[6]
	ambiente.ambient_light_energy = a[7]
	ambiente.fog_light_color = a[8]
	ambiente.fog_density = a[9]
	if _sombras:
		_sombras.trocar(e)
	match e:
		E1950:
			Audio.ambiente("vento")
		E1967:
			Audio.ambiente("mar")
		E2020:
			match visita:
				2:
					Audio.ambiente("vento", -14.0)
				4:
					Audio.ambiente("chuva")
				_:
					Audio.ambiente("")
		_:
			Audio.ambiente("")
	_atualizar_luzes()


# ================================================================== sombras pintadas no chão
## Volumes simplificados do prédio (planta + altura do topo, ameias incluídas) para as sombras de SombrasChao.
## O Sol de cada época vem de AMBIENTES/PRESENTE (mesma direção da DirectionalLight3D); 1950 e 2019 são nublados, e as
## visitas 3 e 4 (noite e chuva) só têm a oclusão no pé dos volumes.
func _montar_sombras() -> void:
	var vol: Dictionary = Castelinho.medidas.get("volumes", {})
	var ta: Dictionary = vol.get("torre_a", {})
	var tb: Dictionary = vol.get("torre_b", {})
	var tta: Dictionary = ta.get("torreta", {})
	var ttb: Dictionary = tb.get("torreta", {})
	var casa := [
		[-15.8, -5.0, -14.2, -11.0, 4.4],                         # galeria da arcada (com ameias)
		[-12.5, -5.0, -20.5, -14.0, 4.9],                         # corpo principal (telhado de 4,2 a 5,5)
		[-22.6, -15.8, -15.0, -11.0, 7.8],                        # Torre A
		[tta.x[0], tta.x[1], tta.z[0], tta.z[1], float(tta.get("apice", 10.3)) - 0.4],
		[-26.8, -22.6, -15.0, -11.0, 4.4],                        # anexo
		[-28.6, -26.8, -13.0, -11.0, 5.2],                        # pavilhão de canto
		[-25.0, -12.5, -20.5, -15.0, 3.9],                        # bloco do pátio
		[-25.0, -5.0, -23.5, -20.5, 4.0],                         # corredor
		[-17.0, -8.2, -29.5, -23.5, 4.4],                         # ala dos fundos
		[-8.2, -5.0, -26.7, -23.1, 7.2],                          # Torre B
		[ttb.x[0], ttb.x[1], ttb.z[0], ttb.z[1], float(ttb.get("apice", 8.9)) - 0.3],
	]
	for ch in Castelinho.medidas.get("chamines", []):
		var w: float = ch["w"]
		casa.append([ch["x"] - w * 0.5, ch["x"] + w * 0.5, ch["z"] - w * 0.5, ch["z"] + w * 0.5, ch["topo"]])
	var nucleo := [
		[-12.5, -5.0, -20.5, -15.5, 5.6],                         # volume A (alto)
		[-12.5, -5.0, -15.5, -11.0, 3.9],                         # volume B (baixo)
		[-7.1, -6.0, -21.2, -20.5, 7.1],                          # chaminé saliente
	]
	var obra: Array = castelo.obra.get("volumes", [])
	# por dentro das plantas: branco (o piso interno não recebe sombra de fora)
	var dentro: Array = []
	for i in [0, 1, 2, 4, 6, 7, 8]:
		var v: Array = casa[i]
		dentro.append([v[0] + 0.25, v[1] - 0.25, v[2] + 0.25, v[3] - 0.25])
	var dentro_1975 := dentro.duplicate()
	dentro_1975.append([X_COR - EntornoCastelinho.L_CORREDOR * 0.5, X_COR + EntornoCastelinho.L_CORREDOR * 0.5, Z_COR_FIM, -29.4])
	var arv: Array = entorno.get("arvores", [])
	var sois := {}
	for e in [E2020, E1975, E2019, E1950, E1967]:
		var a: Array = _preset(e)
		var d := Basis.from_euler(Vector3(deg_to_rad(a[4]), deg_to_rad(a[5]), 0.0)) * Vector3.FORWARD
		match e:
			E2020:
				if visita <= 2:
					sois[e] = {"dir": d, "sombra": 0.6, "ao": 0.74}
				else:
					sois[e] = {"dir": Vector3.ZERO, "ao": 0.62}      # noite e chuva: só oclusão
			E1975, E1967:
				sois[e] = {"dir": d, "sombra": 0.6, "ao": 0.76}
			_:
				sois[e] = {"dir": Vector3.ZERO, "ao": 0.72}         # nublado: só oclusão
	_sombras = SombrasChao.new()
	_sombras.construir(self, {E2020: casa, E1975: casa, E2019: casa, E1950: nucleo, E1967: obra},
		{E2020: arv, E1975: arv, E2019: arv}, sois,
		{E2020: dentro, E1975: dentro_1975, E2019: dentro, E1950: [[-12.25, -5.25, -20.25, -11.25]], E1967: []})


# ================================================================== marcadores
func _marcar(nome: String, pos: Vector3, yaw := 0.0) -> Marker3D:
	var mk := Marker3D.new()
	mk.name = nome
	mk.position = pos
	mk.rotation_degrees.y = yaw
	add_child(mk)
	return mk


func _cam(nome: String, desde: Vector3, para: Vector3, fov := 60.0) -> void:
	var mk := Marker3D.new()
	mk.name = nome
	add_child(mk)
	mk.look_at_from_position(desde, para)
	mk.set_meta("fov", fov)


func ponto_spawn(nome: String) -> Node3D:
	return find_child(nome, true, false) as Node3D


func _marcadores() -> void:
	_marcar("Spawn", Vector3(-23.0, 0.1, 1.5), -28.0)
	# checkpoints por sala base (e o nome pelo número GLOBAL da visita: o main usa "Checkpoint_%d" % checkpoint_sala)
	var yaws := {1: -28.0, 8: 90.0, 10: 0.0, 13: 0.0, 16: 90.0, 17: 0.0}
	for base in BASES_CHECKPOINT:
		_marcar("Checkpoint_%d" % base, BASES_CHECKPOINT[base], yaws[base])
		var g := _global(base)
		if g != base and find_child("Checkpoint_%d" % g, false, false) == null:
			_marcar("Checkpoint_%d" % g, BASES_CHECKPOINT[base], yaws[base])
	_marcar("Spawn_volta_barra", Vector3(-8.6, 0.1, -15.6), 0.0)
	_marcar("Spawn_volta_ato2", Vector3(-19.4, 6.9, -12.6), 0.0)
	# câmeras de conferência (comparar com docs/pesquisa/refs/*.jpg)
	_cam("Cam_drone", Vector3(8.0, 13.5, 6.0), Vector3(-13.0, 2.8, -15.0), 73.0)
	_cam("Cam_frontal", Vector3(-9.0, 1.6, 9.5), Vector3(-14.5, 3.0, -11.0), 58.0)
	_cam("Cam_esquina", Vector3(7.0, 1.7, 0.5), Vector3(-12.0, 3.2, -12.0), 56.0)
	_cam("Cam_torres", Vector3(-17.0, 1.6, 1.5), Vector3(-23.0, 3.0, -12.0), 62.0)
	_cam("Cam_aerea2019", Vector3(-27.0, 14.0, 13.0), Vector3(-14.0, 3.0, -17.0), 66.0)
	_cam("Cam_fundos", Vector3(9.0, 9.0, -27.0), Vector3(-12.0, 3.0, -22.0), 70.0)
	_cam("Cam_hall", Vector3(-5.7, 1.55, -12.6), Vector3(-15.0, 1.5, -12.6), 72.0)
	_cam("Cam_medieval", Vector3(-12.0, 2.6, -23.7), Vector3(-13.0, 1.3, -29.0), 78.0)
	_cam("Cam_nucleo1950", Vector3(8.0, 2.2, -2.0), Vector3(-9.0, 2.6, -16.0), 66.0)
	_cam("Cam_topo_torre", Vector3(-21.6, 8.35, -13.9), Vector3(-6.0, 4.6, -15.0), 80.0)
	_cam("Cam_pescador", Vector3(-8.7, 1.55, -15.9), Vector3(-8.7, 1.35, -14.2), 74.0)
	_cam("Cam_pescador2", Vector3(-6.0, 1.55, -15.6), Vector3(-9.5, 1.3, -14.2), 80.0)
	_cam("Cam_corredor", Vector3(-23.5, 1.55, -21.8), Vector3(-6.0, 1.5, -21.8), 72.0)
	_cam("Cam_escada", Vector3(-12.8, 1.55, -19.55), Vector3(-21.0, 3.0, -19.55), 75.0)
	_cam("Cam_terraco", Vector3(-6.5, 5.0, -12.6), Vector3(-18.0, 5.0, -12.9), 75.0)
	_cam("Cam_salaarte", Vector3(-8.5, 1.55, -19.6), Vector3(-10.5, 1.3, -17.6), 72.0)
	_cam("Cam_salaarte2", Vector3(-8.2, 1.55, -18.4), Vector3(-12.5, 1.3, -18.2), 75.0)
	_cam("Cam_povos", Vector3(-17.0, 1.55, -12.9), Vector3(-26.0, 1.3, -12.9), 72.0)
	_cam("Cam_povos2", Vector3(-22.5, 1.55, -12.9), Vector3(-26.7, 1.3, -13.0), 70.0)
	_cam("Cam_ambiente", Vector3(-19.0, 1.55, -15.6), Vector3(-23.0, 1.0, -16.8), 72.0)
	_cam("Cam_acervo", Vector3(-7.4, 1.55, -17.6), Vector3(-5.9, 1.0, -19.8), 70.0)
	_cam("Cam_medieval2", Vector3(-12.6, 1.55, -23.8), Vector3(-13.5, 1.4, -29.0), 78.0)
	_cam("Cam_medieval3", Vector3(-15.0, 1.55, -24.2), Vector3(-9.5, 1.4, -29.0), 78.0)
	_cam("Cam_torreb", Vector3(-7.6, 3.5, -23.7), Vector3(-6.6, 4.5, -26.0), 80.0)
	_cam("Cam_spawn", Vector3(-23.0, 1.55, 1.5), Vector3(-12.0, 2.5, -11.0), 72.0)
	_cam("Cam_deck", Vector3(-14.0, 1.55, -1.6), Vector3(-9.0, 2.0, -9.5), 72.0)
	_cam("Cam_corredor1975", Vector3(X_COR, 1.55, -31.0), Vector3(X_COR, 1.5, -60.0), 72.0)
	_cam("Cam_obra1967", Vector3(5.0, 2.2, 1.5), Vector3(-12.0, 2.4, -14.0), 70.0)
	_cam("Cam_tito1967", Vector3(-6.2, 1.5, -3.0), Vector3(-2.4, 0.9, -7.2), 62.0)
	_cam("Cam_buraco1967", Vector3(-20.0, 1.5, 3.0), Vector3(-21.6, 0.6, -1.0), 64.0)
	_cam("Cam_porta_porao", Vector3(-14.0, 1.55, -11.6), Vector3(-14.0, 0.6, -13.8), 80.0)
	_cam("Cam_porta_ato2", Vector3(-9.6, 1.55, -18.1), Vector3(-12.5, 1.2, -18.0), 72.0)
	_cam("Cam_escada2019", Vector3(-14.0, 1.55, -24.4), Vector3(-14.0, 0.2, -26.8), 70.0)
	_cam("Cam_calcada", Vector3(-21.0, 1.55, 1.2), Vector3(-34.0, 0.4, 3.0), 72.0)   # revisão V2: a calçada e o poste do spawn


# ================================================================== luzes internas (poucas, quentes)
func _criar_luzes() -> void:
	var lamp: Array = LAMPADAS[visita]
	for l in castelo.luzes:
		var o := OmniLight3D.new()
		o.position = l["pos"]
		# lâmpadas quentes com queda mais rápida: fazem "poças" de luz visíveis sob os lustres
		o.light_color = COR_LAMPADA[visita]
		var base := 2.1 * float(lamp[0])
		o.light_energy = base
		o.omni_range = 7.5
		o.omni_attenuation = 1.7
		o.shadow_enabled = false
		o.visible = false
		add_child(o)
		_luzes.append({"no": o, "pos": l["pos"], "sala": l.get("sala", ""), "base": base, "fase": randf() * TAU})


## Liga só as `LAMPADAS[visita][1]` luzes mais próximas do jogador (a web não aguenta muitas OmniLight3D).
func _atualizar_luzes() -> void:
	var ref := Vector3(-23.0, 1.5, 1.5)
	if player and is_instance_valid(player):
		ref = player.global_position
	else:
		var cam := get_viewport().get_camera_3d()
		if cam:
			ref = cam.global_position
	var maximo: int = LAMPADAS[visita][1]
	var cand: Array = []
	for l in _luzes:
		var no: OmniLight3D = l["no"]
		if not _luz_existe(l["sala"], GameState.epoca):
			no.visible = false
			continue
		var d: float = (l["pos"] as Vector3).distance_to(ref)
		cand.append([d, no])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var i := 0
	for par in cand:
		var no: OmniLight3D = par[1]
		no.visible = i < maximo and par[0] < 16.0
		if no.visible:
			i += 1


## A luz só existe na época do objeto que a "acende": nada do prédio em 1950 e 1967 (sem isso a areia ficava com uma
## mancha laranja onde hoje é o hall), o corredor de 1975 só em 1975 e as tochas do museu só em 2020.
func _luz_existe(sala: String, e: int) -> bool:
	if e == E1950 or e == E1967:
		return false
	if sala == "corredor1975":
		return e == E1975
	if sala.begins_with("medieval_tocha"):
		return e == E2020
	return true


## Lâmpadas que tremem na noite e na madrugada (visitas 3 e 4), por quadro.
func _tremer_lampadas() -> void:
	if visita < 3:
		return
	var forca := 0.22 if visita == 3 else 0.4
	for l in _luzes:
		var no: OmniLight3D = l["no"]
		if not no.visible:
			continue
		var f: float = l["fase"]
		var r := sin(_t * 9.0 + f) * sin(_t * 3.7 + f * 2.0)
		var queda := 1.0 - forca * maxf(0.0, r)
		# de vez em quando uma lâmpada quase apaga (a cada ~11 s, por 0,25 s)
		if visita == 4 and fmod(_t + f * 3.0, 11.0) < 0.25:
			queda = 0.15
		no.light_energy = float(l["base"]) * queda


# ================================================================== SalaTrigger de cada sala base
func _trigger(n: int, centro: Vector3, tam: Vector3, epocas: Array = []) -> SalaTrigger:
	var t := GatilhoCastelinho.new(n, tam)
	t.name = "Sala_%02d" % n
	t.position = centro
	t.ao_entrar = _entrou
	add_child(t)
	if not epocas.is_empty():
		Epocas.marcar(t, epocas)
	_triggers[n] = t
	return t


func _montar_triggers() -> void:
	# exterior (2020): 1 calçada, 2 gramado/churrasqueira, 3 lateral da torre, 4 deck, 5 arcada, 6 porta
	_trigger(1, Vector3(-23.0, 0, 1.2), Vector3(7, 3, 3))
	_trigger(2, Vector3(-24.5, 0, -4.6), Vector3(7, 3, 3))
	_trigger(3, Vector3(-22.5, 0, -9.2), Vector3(7, 3, 2))
	_trigger(4, Vector3(-10.7, 0, -5.6), Vector3(7, 3, 5))
	_trigger(5, Vector3(-8.0, 0, -9.0), Vector3(5, 3, 2.2))
	_trigger(6, Vector3(-6.55, 0, -10.3), Vector3(2.6, 3, 1.2))
	# interior
	_trigger(7, Vector3(-10.4, 0, -12.6), Vector3(8.6, 3, 2.0))
	_trigger(8, Vector3(-22.0, 0, -13.0), Vector3(11.0, 3, 3.0))
	_trigger(9, Vector3(-20.5, 0, -17.2), Vector3(8.0, 3, 3.4))
	_trigger(10, Vector3(-15.5, 0, -21.8), Vector3(16.0, 3, 2.2))
	_trigger(11, Vector3(-9.8, 0, -18.8), Vector3(4.8, 3, 2.2))
	_trigger(12, Vector3(-6.4, 0, -18.8), Vector3(2.2, 3, 2.4))
	_trigger(13, Vector3(-8.7, 0, -15.8), Vector3(6.4, 3, 2.6))
	_trigger(16, Vector3(-13.6, 0, -19.55), Vector3(2.2, 3, 1.1))
	_trigger(17, Vector3(-19.3, 6.8, -12.2), Vector3(4.0, 3, 2.0))
	_trigger(18, Vector3(-10.4, 3.5, -12.6), Vector3(9.0, 3, 2.4))
	_trigger(19, Vector3(-6.6, 3.5, -24.9), Vector3(2.2, 3, 2.6))
	var t20 := _trigger(20, Vector3(-22.7, 3.5, -19.6), Vector3(3.0, 3, 2.6))
	t20.monitoring = false      # só liga depois da sala 19 (descida)
	_trigger(21, Vector3(-12.6, 0, -25.5), Vector3(7.0, 3, 3.6))
	_trigger(22, Vector3(-15.4, 0, -28.0), Vector3(2.4, 3, 2.6))
	_trigger(23, Vector3(-10.2, 0, -28.0), Vector3(3.0, 3, 2.0))
	_trigger(25, Vector3(X_COR, 0, -31.2), Vector3(2.0, 3, 2.4), [E1975])      # corredor de 1975 (visita 3)
	if visita == 4:
		# a porta zebrada do hall: sala 80 (o gatilho só vale depois de a Sala Medieval ter sido vista)
		var t80 := _trigger(SALA_V4_PORTA, Vector3(POS_PORTA_PORAO.x, 0, -12.7), Vector3(3.0, 3, 1.7))
		t80.name = "Sala_80"
	# na ida e volta da escada: depois de chegar à sala 17 o gatilho 16 sai de cena; o 20 só vale depois da 19
	GameState.sala_mudou.connect(func(n: int) -> void:
		var g17 := _global(17)
		if visita <= 3 and n >= g17 and n < _global(21) and _triggers.has(16):
			_triggers[16].monitoring = false
		if visita <= 3 and n == _global(19) and _triggers.has(20):
			_triggers[20].monitoring = true
		if visita <= 3 and n >= _global(21) and _triggers.has(20):
			_triggers[20].monitoring = false
	)


# ================================================================== painéis (Painel3D) e objetos interativos
## Id do painel nesta visita: pNN_vK se existir em data/paineis.json (senão o base); na visita 4, o desenho do Tito.
func _id_painel(base: String) -> String:
	var dados: Dictionary = PainelUI.carregar_dados()
	if visita == 4 and V4_DESENHOS.has(base):
		var desenho: String = V4_DESENHOS[base]
		if dados.has(desenho):
			return desenho
	if visita >= 2:
		var idv := "%s_v%d" % [base, visita]
		if dados.has(idv):
			return idv
	return base


func _painel(id: String, pos: Vector3, yaw := 0.0, epocas: Array = [E2020], poste := false) -> Painel3D:
	var p := Painel3D.new(_id_painel(id))
	p.position = pos
	p.rotation_degrees.y = yaw
	p.alcance = 13.0 if poste else 9.0     # vale também quando a placa se reconstrói (corruption)
	add_child(p)
	_paineis[id] = p
	if not epocas.is_empty():
		Epocas.marcar(p, epocas)
	p.lido.connect(_on_painel_lido)
	_limitar_alcance(p, 13.0 if poste else 9.0)
	if poste:
		_poste_painel(pos, yaw)
	return p


## Alcance de visibilidade (HLOD nativo): o painel some a mais de `d` metros e não pesa nos draw calls.
func _limitar_alcance(no: Node, d: float) -> void:
	if no is GeometryInstance3D:
		(no as GeometryInstance3D).visibility_range_end = d
	for c in no.get_children():
		_limitar_alcance(c, d)


## Só funciona com yaw múltiplo de 90°: as caixas da Malha são alinhadas aos eixos.
func _poste_painel(pos: Vector3, yaw: float) -> void:
	if _props == null:
		_props = Malha.new()
	var dir := Vector3(cos(deg_to_rad(yaw)), 0, -sin(deg_to_rad(yaw)))
	var madeira: Material = castelo.m.madeira
	var c0 := Vector3(pos.x, 0, pos.z)
	for lado in [-1, 1]:
		var c: Vector3 = c0 + dir * 0.7 * lado
		_props.caixa(madeira, c + Vector3(-0.05, 0, -0.05), c + Vector3(0.05, pos.y - 0.45, 0.05), Malha.F_SEM_BASE, 1.0)
	# fundo de madeira atrás da placa
	var atras := -Vector3(sin(deg_to_rad(yaw)), 0, cos(deg_to_rad(yaw)))
	var c1 := c0 + atras * 0.1
	_props.caixa(madeira, c1 - dir * 0.85 + atras * 0.02 + Vector3(0, pos.y - 0.6, 0), c1 + dir * 0.85 - atras * 0.02 + Vector3(0, pos.y + 0.6, 0), Malha.F_TODAS, 1.0)


func _montar_paineis() -> void:
	# exterior (em postes de madeira)
	_painel("p01", Vector3(-19.6, 1.4, -1.6), 0.0, [E2020], true)   # ao lado do caminho (não bloqueia quem anda reto do Spawn)
	var p02 := _painel("p02", Vector3(-24.8, 1.4, -4.6), 0.0, [E2020], true)
	_painel("p03", Vector3(-24.2, 1.4, -7.6), 0.0, [E2020], true)
	_painel("p04", Vector3(-10.7, 1.4, -3.2), 0.0, [E2020], true)
	_painel("p05", Vector3(-9.4, 1.4, -9.2), 0.0, [E2020], true)
	_painel("p06", Vector3(-4.6, 1.4, -9.0), -90.0, [E2020], true)
	# interior (nas paredes)
	_painel("p07", Vector3(-7.4, 1.5, -13.74), 0.0)
	if visita == 4:
		_montar_painel_solto()                                      # o p08 da visita 4 é o painel solto (disco 2019)
	else:
		_painel("p08", Vector3(-26.35, 1.45, -13.0), 90.0)         # (antes x=-26,76: enterrado na parede, a face interna é x=-26,4)
	_painel("p09", Vector3(-24.55, 1.45, -17.4), 90.0)
	_painel("p10", Vector3(-17.0, 1.5, -23.04), 0.0)
	_painel("p11", Vector3(-10.9, 1.5, -20.04), 0.0)
	_painel("p12", Vector3(-5.46, 1.5, -19.0), -90.0)
	_painel("p13", Vector3(-11.3, 1.5, -17.18), 0.0)
	_painel("p14", Vector3(-8.6, 1.5, -17.18), 0.0)
	_painel("p15", Vector3(-12.06, 1.5, -15.8), 90.0)
	_painel("p16", Vector3(-14.9, 2.0, -20.02), 0.0)
	_painel("p17", Vector3(-16.85, 7.6, -13.06), 180.0)
	_painel("p18", Vector3(-9.0, 4.3, -13.76), 0.0)
	_painel("p19", Vector3(-7.78, 4.7, -25.0), 90.0)
	_painel("p20", Vector3(-15.6, 1.5, -23.04), 0.0)
	_painel("p21", Vector3(-15.4, 1.5, -23.56), 180.0)
	# o quiz final existe nas 4 visitas: V1 normal, V2 "encerrado", V3 corrompido ("tudo correto"), V4 riscado com desenho
	_painel("quiz_final", Vector3(-16.56, 1.5, -28.3), 90.0)
	if visita <= 3:
		_painel("p23", Vector3(-8.64, 1.5, -24.6), -90.0, [E2020, E2019])
	if visita == 3:
		_painel("p24", Vector3(-8.64, 1.5, -24.6), -90.0, [E1975])
		_painel("p25", Vector3(X_COR + 1.07, 1.5, -48.0), -90.0, [E1975])
	# folha de costela-de-Adão brotando no canto do painel P02 (semente "creepy" do roteiro)
	var folha := _folha_costela()
	folha.position = p02.position + Vector3(0.78, -0.45, 0.07)
	add_child(folha)
	Epocas.marcar(folha, [E2020])
	# cartazes de PROCURA-SE colados por cima dos painéis (visita 3 em diante)
	if visita >= 3:
		var lista: Array = CARTAZES_V3 if visita == 3 else CARTAZES_V4
		for id in lista:
			if _paineis.has(id):
				var painel: Node3D = _paineis[id]
				var cartaz := TitoCastelinho.cartaz_sobre(self, painel, 1 if id.hash() % 2 == 0 else -1)
				cartaz.name = "Cartaz_" + id
				if id == lista[0]:
					_interagivel_pista("Ler o cartaz", cartaz.position + Vector3(0, 0, 0.03), Vector3(0.55, 0.75, 0.25), "cartaz",
						["PROCURA-SE: Tito, 9 anos. Desaparecido desde 12/03/1967. Bermuda azul, balde vermelho.", "\"Informações: fone 4-27. A família agradece.\""], [E2020])
				_limitar_alcance(cartaz, 9.0)
				Epocas.marcar(cartaz, [E2020])


func _folha_costela() -> Sprite3D:
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var verde := Color(0.13, 0.5, 0.2)
	var escuro := Color(0.06, 0.3, 0.12)
	for y in 48:
		for x in 48:
			var dx := (x - 24.0) / 22.0
			var dy := (y - 22.0) / 20.0
			if dx * dx + dy * dy < 1.0:
				img.set_pixel(x, y, verde)
	# fendas e furos característicos da costela-de-Adão
	for k in 4:
		for t in 10:
			img.set_pixel(24 + t, 10 + k * 9, Color(0, 0, 0, 0))
			img.set_pixel(24 - t, 12 + k * 9, Color(0, 0, 0, 0))
	for t in 20:
		img.set_pixel(24, 22 + t, escuro)
	var s := Sprite3D.new()
	s.name = "FolhaCostelaDeAdao"
	s.texture = ImageTexture.create_from_image(img)
	s.pixel_size = 0.009
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.double_sided = true
	s.rotation_degrees.z = -18.0
	return s


# ================================================================== objetos
func _montar_objetos() -> void:
	# pinguim empalhado (Meio Ambiente): os olhos acompanham o jogador (só da visita 3 em diante)
	_pinguim = MobiliaCastelinho.criar_pinguim()
	_pinguim.position = Vector3(-22.6, 0.03, -16.0)
	_pinguim.rotation_degrees.y = 160.0
	add_child(_pinguim)
	Epocas.marcar(_pinguim, [E2020])
	# telefone antigo do acervo (interagível: atender; só toca na visita 2)
	var tel := MobiliaCastelinho.criar_telefone()
	tel.position = Vector3(-6.6, 0.8, -19.0)
	add_child(tel)
	Epocas.marcar(tel, [E2020])
	_telefone = Interagivel.new("Atender o telefone", Vector3(0.5, 0.4, 0.5), _atender_telefone)
	_telefone.position = Vector3(-6.6, 0.95, -19.0)
	add_child(_telefone)
	Epocas.marcar(_telefone, [E2020])
	# mural da Sala do Pescador (visita 2: leva ao flashback da Barra)
	_mural = Interagivel.new("Olhar o mural", Vector3(3.8, 2.0, 0.5), _usar_mural)
	_mural.position = Vector3(-8.7, 1.5, -14.5)
	add_child(_mural)
	Epocas.marcar(_mural, [E2020])
	# armadura que aparece no trono (sala 21, só na visita 3)
	_armadura = MobiliaCastelinho.criar_armadura()
	_armadura.position = POS_ARMADURA
	_armadura.rotation_degrees.y = -90.0
	_armadura.visible = false
	add_child(_armadura)
	# recortes de papelão
	_recortes["visitante"] = _recorte("visitante", Vector3(-17.0, 0, -9.6), 0.0, true)    # virado para a parede (semente nº 1)
	Epocas.marcar(_recortes["visitante"], [E2020])     # é um objeto do museu: não fica sozinho nas dunas de 1950
	_recortes["pescador"] = _recorte("pescador", Vector3(-6.4, 0, -17.55), 180.0, false)
	_recortes["pescador"].visible = false
	_recortes["quico"] = _recorte("quico", Vector3(-7.2, 3.5, -24.2), 180.0, false)
	_recortes["quico"].visible = false
	# porta de saída da Sala Medieval: visitas 1 e 2 saem por ela; nas visitas 3 e 4 está em reforma (fitas zebradas)
	_porta_saida = Interagivel.new("Sair do Castelinho", Vector3(1.4, 2.4, 0.5), _usar_porta_saida)
	_porta_saida.position = POS_PORTA_SAIDA
	add_child(_porta_saida)
	Epocas.marcar(_porta_saida, [E2020])
	if visita >= 3:
		_fita_zebrada()
	# porta final do corredor de 1975 (visita 3: leva à visita 4)
	_porta_saida_1975 = Interagivel.new("Abrir a porta", Vector3(1.4, 2.4, 0.5), _abrir_porta_final)
	_porta_saida_1975.position = Vector3(X_COR, 1.2, Z_COR_FIM + 0.4)
	add_child(_porta_saida_1975)
	Epocas.marcar(_porta_saida_1975, [E1975])


## Recorte de papelão (quad com textura desenhada em código por MobiliaCastelinho.textura_recorte).
## `de_costas`: virado para a parede (o jogador só vê o verso, em papelão cru).
func _recorte(tipo: String, pos: Vector3, yaw: float, de_costas: bool) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Recorte_" + tipo
	raiz.position = pos
	raiz.rotation_degrees.y = yaw
	var tex := MobiliaCastelinho.textura_recorte(tipo)
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = tex
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mat_verso := mat.duplicate() as StandardMaterial3D
	mat_verso.albedo_texture = MobiliaCastelinho.textura_recorte(tipo, true)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 1.8)
	var frente := MeshInstance3D.new()
	frente.mesh = qm
	frente.material_override = mat
	frente.position = Vector3(0, 0.95, 0.01)
	raiz.add_child(frente)
	var verso := MeshInstance3D.new()
	verso.mesh = qm
	verso.material_override = mat_verso
	verso.position = Vector3(0, 0.95, -0.01)
	verso.rotation_degrees.y = 180.0
	raiz.add_child(verso)
	var pe := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.05, 0.3)
	pe.mesh = bm
	pe.material_override = castelo.m.madeira
	pe.position = Vector3(0, 0.025, 0)
	raiz.add_child(pe)
	add_child(raiz)
	if pos.x < -5.0 and pos.z < -11.0 and pos.y < 3.0:
		# dentro do prédio: camada 2 (o Sol não atravessa o telhado), como o resto do interior
		for f in [frente, verso, pe]:
			f.layers = 2
	if de_costas:
		raiz.rotation_degrees.y = 180.0 + yaw        # a frente (desenho) vira para a parede
	return raiz


## Fitas zebradas e a placa "EM REFORMA" na porta de saída da Sala Medieval (visitas 3 e 4, só no presente).
func _fita_zebrada() -> void:
	# listras amarelas e pretas (Image) em três fitas cruzando a porta de saída, no lado de dentro
	var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 64:
			var listra := int((x + y) / 8) % 2 == 0
			img.set_pixel(x, y, Color(0.95, 0.8, 0.1) if listra else Color(0.08, 0.08, 0.08))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := Malha.new()
	for par in [[1.05, -10.9, -9.5], [1.45, -9.5, -10.9], [1.85, -10.9, -9.5]]:
		var y: float = par[0]
		m.quad_uv(mat, Vector3(par[1], y, -29.02), Vector3(par[2], y + 0.1, -29.02), Vector3(par[2], y + 0.2, -29.02), Vector3(par[1], y + 0.1, -29.02), Vector3(0, 0, 1),
			Vector2(0, 0), Vector2(3, 0), Vector2(3, 1), Vector2(0, 1))
	var no := Node3D.new()
	no.name = "FitaZebrada"
	add_child(no)
	m.construir_instancia(no, "Fita", 2)
	# placa de madeira com "EM REFORMA" pendurada na porta
	var placa := Malha.new()
	placa.caixa(castelo.m.madeira, Vector3(-11.05, 2.15, -29.04), Vector3(-9.35, 2.6, -29.0), Malha.F_TODAS, 1.0)
	placa.construir_instancia(no, "Placa", 2)
	var l := Construtor.rotulo(no, "EM REFORMA", Vector3(-10.2, 2.375, -28.99), 40, Color(0.97, 0.9, 0.7))
	l.pixel_size = 0.0036
	l.double_sided = false
	l.layers = 2
	Epocas.marcar(no, [E2020])


func _montar_props() -> void:
	if _props == null:
		_props = Malha.new()
	# marcas de arrasto no deck (sala 4): duas faixas escuras paralelas
	var marca: Material = Castelinho.mat_cor(Color(0.12, 0.07, 0.05), 1.0)
	for dz in [-0.2, 0.2]:
		_props.quad(marca, Vector3(-9.2, 0.078, -5.6 + dz - 0.05), Vector3(-12.6, 0.078, -4.6 + dz - 0.05), Vector3(-12.6, 0.078, -4.6 + dz + 0.05), Vector3(-9.2, 0.078, -5.6 + dz + 0.05), Vector3.UP)
	var no := Node3D.new()
	no.name = "PropsExternos"
	add_child(no)
	_props.construir_instancia(no, "Postes", 1)
	Epocas.marcar(no, [E2020])


# ================================================================== o estado de cada visita (objetos extras)
func _montar_visita() -> void:
	# --- discos do Visor: ficam nos lugares do V2_ROTEIRO §4.1 até serem pegos
	_disco_no_chao(E1967, POS_DISCO_1967, Color(0.85, 0.12, 0.1), "Pegar o disco da vitrine", 2,
		["Um disco do Visor! A etiqueta, escrita à mão, diz: \"não catalogado\".", "Aperte 1 a 5 (ou a rolagem do mouse) para trocar de disco e segure Q para ver."], true)
	_disco_no_chao(E1975, POS_DISCO_1975, Color(0.95, 0.65, 0.12), "Pegar o disco", 3,
		["Outro disco do Visor, caído no topo da torre.", "Este mostra o Castelinho pronto, como era em 1975."], false)
	match visita:
		1:
			# semente nº 2: um desenho de criança entre os quadros dos artistas locais (Salão de Arte, sala 11)
			_desenhos["desenho_1"] = TitoCastelinho.folha(self, "desenho_1", Vector3(-9.62, 1.25, -20.01), 0.0, 0.46, 2)
			_montar_passaporte()
		2:
			_desenhos["desenho_2"] = TitoCastelinho.folha(self, "desenho_2", Vector3(-6.45, 1.45, -20.01), 0.0, 0.5, 2)
			_interagivel_pista("Olhar o desenho", Vector3(-6.45, 1.45, -19.9), Vector3(0.6, 0.6, 0.3), "desenho_2",
				["Um desenho de giz de cera: um menino e a mãe, de mãos dadas, na praia.", "Está assinado \"TITO\", com o T ao contrário."], [E2020])
			if GameState.flag(_chave("apagao")):
				_criar_balde_e_desenho3()
		3:
			_desenhos["desenho_4"] = TitoCastelinho.folha(self, "desenho_4", Vector3(-24.5, 1.25, -16.0), 90.0, 0.5, 2)
			_interagivel_pista("Olhar o desenho", Vector3(-24.4, 1.25, -16.0), Vector3(0.3, 0.6, 0.6), "desenho_4",
				["Um menino pequeno embaixo de um castelo enorme, todo de pedra.", "O castelo está em cima dele."], [E2020])
			_montar_porta_ato2()
			_montar_pedestal_1975()
			_montar_bloqueio_escada()
		4:
			_montar_pegadas_v4()
			_montar_bloqueio_escada()
			_montar_porta_porao()
			_montar_escada_2019()
			_montar_desenho_oculto_2019()
	if visita >= 3 and GameState.flag("evt_v2_apagao"):
		_criar_balde_e_desenho3()      # o balde do fim da visita 2 não some (p21_v3 fala dele)
	for d in _desenhos.values():
		if d is Node3D:
			_limitar_alcance(d, 9.0)
			Epocas.marcar(d, [E2020])
	# marcas de altura a lápis: só existem em 1975 (o presente tem a parede rebocada). A textura é um trecho de batente
	# (a madeira à esquerda), então a coloco encostada na lateral da porta de saída, na Sala Medieval.
	var marcas := TitoCastelinho.folha(self, "marcas_altura", Vector3(-9.2, 1.25, -29.085), 0.0, 0.6, 2)
	marcas.name = "MarcasDeAltura"
	Epocas.marcar(marcas, [E1975])
	_interagivel_pista("Olhar as marcas na parede", Vector3(-9.2, 1.25, -28.95), Vector3(0.7, 0.9, 0.4), "marcas_altura",
		["Marcas de altura a lápis: \"TITO 6\", \"7\", \"8\", \"TITO 9\"...", "Depois do nove, nada. A parede não tem mais marcas."], [E1975])
	_limitar_alcance(marcas, 9.0)
	# Tito "no canto da sala", só dentro do Visor (visitas 3 e 4), cada vez mais perto
	if visita >= 3:
		_tito_visor = TitoCastelinho.criar_tito()
		_tito_visor.name = "TitoNoVisor"
		_tito_visor.visible = false
		add_child(_tito_visor)
		Epocas.marcar(_tito_visor, [E1950, E1967, E1975, E2019])
		_tito_visor.position = _spot_tito_visor(7)


## Posição do Tito dentro do Visor conforme a sala base em que o jogador está: cada visita o mostra mais perto.
func _spot_tito_visor(base: int) -> Vector3:
	var v3 := {8: Vector3(-26.0, 0, -12.2), 9: Vector3(-23.8, 0, -19.0), 10: Vector3(-24.0, 0, -22.4), 16: Vector3(-17.4, 0, -20.6), 21: Vector3(-14.8, 0, -24.4)}
	var v4 := {7: Vector3(-15.2, 0, -12.3), 8: Vector3(-24.0, 0, -14.4), 9: Vector3(-23.0, 0, -17.8), 10: Vector3(-16.0, 0, -22.0),
		11: Vector3(-11.2, 0, -18.4), 13: Vector3(-9.6, 0, -15.0), 21: Vector3(-11.6, 0, -26.2), 22: Vector3(-13.6, 0, -28.0)}
	var tab: Dictionary = v3 if visita == 3 else v4
	var melhor: int = -1
	for k in tab:
		if k <= base and k > melhor:
			melhor = k
	if melhor < 0:
		melhor = tab.keys()[0]
	return tab[melhor]


func _montar_epoca_1967() -> void:
	var info: Dictionary = castelo.obra
	_tito = TitoCastelinho.criar_tito()
	_tito.position = info.get("tito_pos", ObraCastelinho.TITO_POS)
	add_child(_tito)
	Epocas.marcar(_tito, [E1967])
	_interagivel_pista("Acenar para o Tito", _tito.position + Vector3(0, 0.65, 0), Vector3(0.9, 1.4, 0.9), "tito_1967",
		["Um menino de bermuda azul brinca de castelo na areia, com um balde vermelho.", "Ele acena para você. Ninguém mais parece vê-lo."], [E1967])
	# o buraco no muro: pista que só existe em 1967 (Interagivel só nessa época)
	var bp: Vector3 = info.get("buraco_pos", ObraCastelinho.BURACO_POS)
	var it := Interagivel.new("Olhar o buraco no muro", Vector3(1.0, 1.0, 0.8), _olhar_buraco)
	it.position = bp + Vector3(0, 0.5, 0.0)
	it.name = "BuracoNoMuro"
	add_child(it)
	Epocas.marcar(it, [E1967])


# ---------------------------------------------------------------- pistas do Tito (final "Encontrado": GameState.contadores["pistas_tito"])
## Convenção do projeto: uma vez por pista, flag "pista_<id>" + somar("pistas_tito"). O Castelinho tem 8: o buraco no muro
## (1967), o Tito brincando (1967), as marcas de altura (1975), os desenhos 2, 3 e 4 e o cartaz de PROCURA-SE (presente) e o
## desenho atrás do painel (2019). Todas pedem uma ação deliberada (E em cima do objeto; quatro delas só com o Visor).
func _pista(id: String) -> void:
	if GameState.flag("pista_" + id):
		return
	GameState.set_flag("pista_" + id, true)
	GameState.somar("pistas_tito")


## Interagivel sobre um objeto de pista: olhar (E) fala a linha e conta a pista.
func _interagivel_pista(texto: String, pos: Vector3, tam: Vector3, id: String, fala: Array, epocas: Array, quem := "sistema") -> Interagivel:
	var it := Interagivel.new(texto, tam, Callable())
	it.position = pos
	it.name = "Pista_" + id
	it.acao = func(_p: Node) -> void:
		_pista(id)
		await Guia.falar(quem, fala)
	add_child(it)
	Epocas.marcar(it, epocas)
	return it


func _olhar_buraco(_p: Node) -> void:
	await Guia.falar("sistema", ["Um buraco no muro, do tamanho de uma criança.", "Marcas de pezinhos na areia levam para dentro da obra."])
	_pista("buraco")


# ---------------------------------------------------------------- discos
## Disco do Visor na vitrine/pedestal, até o jogador pegá-lo. `a_partir_da_visita`: só existe desta visita em diante.
func _disco_no_chao(epoca: int, pos: Vector3, cor: Color, texto: String, a_partir_da_visita: int, fala: Array, etiqueta: bool) -> void:
	if GameState.discos.has(epoca) or visita < a_partir_da_visita:
		return
	var raiz := Node3D.new()
	raiz.name = "Disco_%s" % GameState.NOMES_EPOCA[epoca]
	raiz.position = pos
	add_child(raiz)
	var disco := TitoCastelinho.criar_disco(cor)
	disco.rotation_degrees.x = 12.0
	raiz.add_child(disco)
	if etiqueta:
		# etiqueta escrita à mão: "não catalogado"
		var tag := Construtor.rotulo(raiz, "não catalogado", Vector3(0.0, -0.18, 0.22), 26, Color(0.12, 0.1, 0.08))
		tag.pixel_size = 0.0012
		tag.layers = 2
		var papel := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.2, 0.06)
		papel.mesh = qm
		papel.material_override = Castelinho.mat_cor(Color(0.95, 0.9, 0.7), 1.0)
		papel.position = Vector3(0.0, -0.18, 0.215)
		papel.layers = 2
		raiz.add_child(papel)
	# revisão V2: o disco gira devagar e pisca um brilho de 4 pontas de vez em quando (o "item" de jogo educativo
	# Flash): sem isso o disco de 1967 era um botão vermelho perdido na vitrine, e o de 1975 sumia no escuro da torre
	disco.name = "Disco"
	var brilho := Sprite3D.new()
	brilho.name = "Brilho"
	brilho.texture = _tex_brilho()
	brilho.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	brilho.shaded = false
	brilho.no_depth_test = false
	brilho.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	brilho.pixel_size = 0.012
	brilho.position = Vector3(0.09, 0.1, 0.05)
	brilho.modulate = Color(1.0, 0.95, 0.7)
	brilho.layers = 2
	raiz.add_child(brilho)
	Epocas.marcar(raiz, [E2020])
	var it := Interagivel.new(texto, Vector3(0.4, 0.3, 0.4), Callable())
	it.position = pos + Vector3(0, 0.05, 0)
	it.acao = func(_p: Node) -> void: _pegar_disco(epoca, fala)
	add_child(it)
	Epocas.marcar(it, [E2020])
	_discos_chao[epoca] = [raiz, it]


## Brilho de 4 pontas, 16 px, pixelado (para o disco no chão).
static func _tex_brilho() -> ImageTexture:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var dx := absf(x - 7.5)
			var dy := absf(y - 7.5)
			var a := 0.0
			if dx < 1.0 or dy < 1.0:
				a = clampf(1.0 - maxf(dx, dy) / 8.0, 0.0, 1.0)
			if dx + dy < 3.0:
				a = 1.0
			img.set_pixel(x, y, Color(1, 1, 1, floorf(a * 3.0) / 3.0))
	return ImageTexture.create_from_image(img)


## Anima os discos que ainda estão no chão: giro lento e o brilho que pisca a cada ~2,5 s.
func _animar_discos(dt: float) -> void:
	for ep in _discos_chao:
		var raiz: Node3D = _discos_chao[ep][0]
		if not is_instance_valid(raiz) or not raiz.visible:
			continue
		var d := raiz.get_node_or_null("Disco") as Node3D
		if d:
			d.rotation.y += dt * 0.9
		var b := raiz.get_node_or_null("Brilho") as Sprite3D
		if b:
			var f := maxf(0.0, sin(_t * 2.5 + float(ep)))
			f = pow(f, 6.0)
			b.scale = Vector3.ONE * (0.2 + 1.0 * f)
			b.rotation.z = _t * 1.5


func _pegar_disco(epoca: int, fala: Array) -> void:
	var par: Array = _discos_chao.get(epoca, [])
	if par.is_empty():
		return
	_discos_chao.erase(epoca)
	for n in par:
		if is_instance_valid(n):
			(n as Node).queue_free()
	GameState.ganhar_disco(epoca)
	Audio.sfx("selo")
	Efeitos.flash(0.25, Color(1, 1, 1), 0.35)
	await Guia.falar("sistema", fala)


# ---------------------------------------------------------------- Passaporte do Museu (visita 1: ganhar o disco 1950)
## Fatos: docs/pesquisa/castelinho.md. pedra = §2.3 (pedra de barco pelo Tramandaí, fonte [1]); foto = §2.1/2.3 (obra a partir
## de 1950, "só o miolo", torres em momentos diferentes, fonte [1]); chave = §2.1/2.4 (compra em 2019, quase ruínas, inauguração
## em 23/12/2020, fontes [2][4][5]).
const PASSAPORTE := {
	"pedra": {"texto": "Examinar a pedra velha", "pos": Vector3(-11.0, 0.62, -7.3), "interno": false,
		"fato": ["Uma pedra do Castelinho! Ela veio de barco pelo rio Tramandaí.", "Imagina carregar isso tudo no barco!"],
		"dica": "Uma pedra velha brilha lá fora, perto do deck e da arcada (salas 4 e 5)."},
	"foto": {"texto": "Examinar a foto antiga", "pos": Vector3(-21.5, 0.95, -12.9), "interno": true,
		"fato": ["Uma foto antiga! No começo, a partir de 1950, era só o miolo da casa.", "As torres vieram depois, em épocas diferentes."],
		"dica": "Uma foto antiga está na sala dos Povos Originários, depois do hall (sala 8)."},
	"chave": {"texto": "Examinar a chave velha", "pos": Vector3(-20.3, 0.8, -18.4), "interno": true,
		"fato": ["Uma chave velha! Em 2019 o prédio foi comprado e salvo, porque quase virou ruínas.", "Em dezembro de 2020 ele abriu como Casa de Cultura e Museu."],
		"dica": "Uma chave velha brilha na sala do Meio Ambiente, perto do pinguim (sala 9)."},
}


func _montar_passaporte() -> void:
	if GameState.discos.has(E1950):
		return                      # save antigo (ou caça concluída): sem caça
	for id in PASSAPORTE:
		if GameState.flag("passaporte_" + id):
			continue
		var d: Dictionary = PASSAPORTE[id]
		var raiz := Node3D.new()
		raiz.name = "Passaporte_" + id
		raiz.position = d["pos"]
		var modelo := _modelo_passaporte(id)
		modelo.name = "Modelo"
		raiz.add_child(modelo)
		var brilho := Sprite3D.new()
		brilho.name = "Brilho"
		brilho.texture = _tex_brilho()
		brilho.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		brilho.shaded = false
		brilho.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
		brilho.pixel_size = 0.014
		brilho.position = Vector3(0.14, 0.16, 0.05)
		brilho.modulate = Color(1.0, 0.9, 0.35)
		raiz.add_child(brilho)
		add_child(raiz)
		if d["interno"]:
			_camada_interna(raiz)
		Epocas.marcar(raiz, [E2020])
		var it := Interagivel.new(d["texto"], Vector3(0.7, 0.7, 0.7), Callable())
		it.name = "InterPassaporte_" + id
		it.position = d["pos"]
		it.acao = func(_p: Node) -> void: _coletar_passaporte(id)
		add_child(it)
		Epocas.marcar(it, [E2020])
		_passaporte_itens[id] = [raiz, it]


func _camada_interna(no: Node) -> void:
	if no is VisualInstance3D:
		(no as VisualInstance3D).layers = 2
	for c in no.get_children():
		_camada_interna(c)


func _peca(pai: Node3D, malha: Mesh, cor: Color, pos: Vector3, rot := Vector3.ZERO) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = malha
	m.material_override = Castelinho.mat_cor(cor, 0.7)
	m.position = pos
	m.rotation_degrees = rot
	pai.add_child(m)
	return m


## Modelos simples, de cor viva (jogo educativo Flash): pedra ferrugem, foto sépia com moldura, chave dourada.
func _modelo_passaporte(id: String) -> Node3D:
	var n := Node3D.new()
	match id:
		"pedra":
			# pedra grés bruta, lascada (não um tijolo: o bloco liso com junta lia como baú)
			var r := SphereMesh.new()
			r.radius = 0.16
			r.height = 0.22
			r.radial_segments = 7
			r.rings = 3
			_peca(n, r, Color(0.72, 0.4, 0.3), Vector3.ZERO, Vector3(12, 25, 8))
			var lasca := SphereMesh.new()
			lasca.radius = 0.1
			lasca.height = 0.14
			lasca.radial_segments = 5
			lasca.rings = 2
			_peca(n, lasca, Color(0.62, 0.34, 0.26), Vector3(0.11, 0.03, 0.05), Vector3(0, 40, 20))
		"foto":
			var mold := BoxMesh.new()
			mold.size = Vector3(0.42, 0.32, 0.03)
			_peca(n, mold, Color(0.35, 0.18, 0.08), Vector3.ZERO)
			var papel := BoxMesh.new()
			papel.size = Vector3(0.36, 0.26, 0.035)
			_peca(n, papel, Color(0.93, 0.85, 0.62), Vector3.ZERO)
			var casa := BoxMesh.new()
			casa.size = Vector3(0.14, 0.07, 0.04)
			_peca(n, casa, Color(0.45, 0.32, 0.2), Vector3(-0.04, -0.03, 0))
			var teto := BoxMesh.new()
			teto.size = Vector3(0.16, 0.025, 0.045)
			_peca(n, teto, Color(0.3, 0.2, 0.14), Vector3(-0.04, 0.02, 0))
		"chave":
			var anel := TorusMesh.new()
			anel.inner_radius = 0.045
			anel.outer_radius = 0.08
			_peca(n, anel, Color(1.0, 0.78, 0.15), Vector3(-0.12, 0, 0), Vector3(90, 0, 0))
			var haste := BoxMesh.new()
			haste.size = Vector3(0.24, 0.04, 0.04)
			_peca(n, haste, Color(1.0, 0.78, 0.15), Vector3(0.06, 0, 0))
			var dente := BoxMesh.new()
			dente.size = Vector3(0.04, 0.09, 0.04)
			_peca(n, dente, Color(1.0, 0.78, 0.15), Vector3(0.14, -0.04, 0))
			_peca(n, dente, Color(1.0, 0.78, 0.15), Vector3(0.07, -0.04, 0))
	return n


func _animar_passaporte(dt: float) -> void:
	for id in _passaporte_itens:
		var raiz: Node3D = _passaporte_itens[id][0]
		if not is_instance_valid(raiz) or not raiz.visible:
			continue
		var m := raiz.get_node_or_null("Modelo") as Node3D
		if m:
			m.rotation.y += dt * 1.1
			m.position.y = sin(_t * 2.0 + float(id.length())) * 0.04
		var b := raiz.get_node_or_null("Brilho") as Sprite3D
		if b:
			var f := pow(maxf(0.0, sin(_t * 2.2 + float(id.length()))), 4.0)
			b.scale = Vector3.ONE * (0.5 + 0.9 * f)
			b.rotation.z = _t * 1.5


## O Bentinho lança o Passaporte (sala 1 da visita 1). Sem caça se o jogador já tem o disco 1950.
func _lancar_passaporte() -> void:
	if GameState.discos.has(E1950) or GameState.flag("passaporte_lancado"):
		return
	GameState.set_flag("passaporte_lancado")
	await Guia.falar("bentinho", ["Hoje você ganha o Passaporte do Museu!", "Ache 3 objetos antigos escondidos pelo caminho e ganhe carimbos!", "Eles brilham de leve. Procure nas salas de 1 a 10!"])


func _coletar_passaporte(id: String) -> void:
	var par: Array = _passaporte_itens.get(id, [])
	if par.is_empty():
		return
	_passaporte_itens.erase(id)
	for n in par:
		if is_instance_valid(n):
			(n as Node).queue_free()
	GameState.set_flag("passaporte_" + id)
	GameState.set_flag("passaporte_lancado")
	Audio.sfx("selo")                       # o carimbo
	Efeitos.flash(0.2, Color(1, 0.95, 0.6), 0.3)
	var n := GameState.passaporte_achados()
	var linhas: Array = PASSAPORTE[id]["fato"].duplicate()
	if n >= GameState.PASSAPORTE_IDS.size():
		linhas.append("Carimbo %d de 3! Passaporte completo: fale com o Bentinho no corredor, sala 10." % n)
	else:
		linhas.append("Carimbo %d de 3!" % n)
	await Guia.falar("bentinho", linhas)


## Pedestal de madeira no topo da Torre A (visita 3) onde fica o disco 1975.
func _montar_pedestal_1975() -> void:
	if GameState.discos.has(E1975):
		return
	var m := Malha.new()
	m.caixa(castelo.m.madeira, Vector3(-20.85, 6.8, -12.45), Vector3(-20.35, 7.63, -11.95), Malha.F_SEM_BASE, 1.0)
	var no := Node3D.new()
	no.name = "Pedestal1975"
	add_child(no)
	m.construir_instancia(no, "Pedestal", 1)
	Epocas.marcar(no, [E2020])


# ---------------------------------------------------------------- visita 2: o balde e o desenho nº 3
## O balde vermelho no trono e o desenho da mulher branca na parede. Só existem depois do apagão (fim da visita 2).
func _criar_balde_e_desenho3() -> void:
	if _balde != null:
		return
	_balde = TitoCastelinho.criar_balde(1.4)
	# V2: sobre o trono do fundo (z -28,2). V3 e V4: o balde fica (consequência do apagão), no outro trono (z -27,0),
	# porque a armadura da V3 senta no do fundo.
	_balde.position = Vector3(-9.2, 0.7, -28.2 if visita == 2 else -27.0)
	add_child(_balde)
	Epocas.marcar(_balde, [E2020])
	# a sandália da Barra, junto do balde (só o objeto): duas coisas de criança no mesmo trono
	var sandalia := Node3D.new()
	sandalia.name = "SandaliaDeCrianca"
	sandalia.position = Vector3(0.02, 0.1, 0.24)
	sandalia.rotation_degrees = Vector3(0, 35, 8)
	_balde.add_child(sandalia)
	var sola := Castelinho.mat_cor(Color(0.3, 0.52, 0.9))
	var tira := Castelinho.mat_cor(Color(0.95, 0.8, 0.2))
	Construtor.caixa(sandalia, Vector3(0.09, 0.025, 0.2), Vector3.ZERO, sola, false)
	Construtor.caixa(sandalia, Vector3(0.09, 0.012, 0.03), Vector3(0, 0.02, -0.02), tira, false)
	Construtor.caixa(sandalia, Vector3(0.035, 0.012, 0.09), Vector3(0, 0.02, 0.03), tira, false)
	var d3 := TitoCastelinho.folha(self, "desenho_3", Vector3(-16.55, 1.5, -26.0), 90.0, 0.5, 2)
	_limitar_alcance(d3, 9.0)
	Epocas.marcar(d3, [E2020])
	_desenhos["desenho_3"] = d3
	_interagivel_pista("Olhar o desenho", Vector3(-16.45, 1.5, -26.0), Vector3(0.3, 0.6, 0.6), "desenho_3",
		["O castelo desenhado a giz de cera, e na janela da torre uma mulher toda branca.", "Esse desenho não estava aqui antes."], [E2020])


# ---------------------------------------------------------------- visita 3: a porta para 1950 (Ato II) e a escada interditada
func _montar_porta_ato2() -> void:
	if GameState.flag("v3_ato2_feito"):
		return
	var m := Malha.new()
	var o := POS_PORTA_ATO2
	# moldura escura e folha de madeira velha na parede oeste do Salão (a face olha para +x)
	m.caixa(castelo.m.escuro, o + Vector3(-0.03, 0.0, -0.58), o + Vector3(0.02, 2.2, 0.58), Malha.F_TODAS)
	m.quad(castelo.m.porta, o + Vector3(0.025, 0.0, 0.5), o + Vector3(0.025, 0.0, -0.5), o + Vector3(0.025, 2.05, -0.5), o + Vector3(0.025, 2.05, 0.5), Vector3(1, 0, 0), Vector2(1, 1))
	m.caixa(castelo.m.ferro, o + Vector3(0.03, 1.0, 0.38), o + Vector3(0.06, 1.1, 0.46), Malha.F_TODAS)
	# fresta de luz clara embaixo da porta e uma luminosidade na folha: as dunas de 1950 do outro lado (chama o olhar de noite)
	var luz := Castelinho.mat_luz(Color(1.0, 0.92, 0.65), 1.0)
	m.quad(luz, o + Vector3(0.04, 0.0, 0.5), o + Vector3(0.04, 0.0, -0.5), o + Vector3(0.04, 0.035, -0.5), o + Vector3(0.04, 0.035, 0.5), Vector3(1, 0, 0))
	m.quad(luz, o + Vector3(0.04, 0.0, 0.52), o + Vector3(0.04, 0.0, 0.5), o + Vector3(0.04, 2.1, 0.5), o + Vector3(0.04, 2.1, 0.52), Vector3(1, 0, 0))
	m.quad(luz, o + Vector3(0.04, 0.0, -0.5), o + Vector3(0.04, 0.0, -0.52), o + Vector3(0.04, 2.1, -0.52), o + Vector3(0.04, 2.1, -0.5), Vector3(1, 0, 0))
	var no := Node3D.new()
	no.name = "PortaPara1950"
	add_child(no)
	m.construir_instancia(no, "Porta", 2)
	Epocas.marcar(no, [E2020])
	_porta_ato2 = Interagivel.new("Abrir a porta", Vector3(0.5, 2.2, 1.2), _abrir_porta_ato2)
	_porta_ato2.position = o + Vector3(0.1, 1.1, 0.0)
	add_child(_porta_ato2)
	Epocas.marcar(_porta_ato2, [E2020])


## A escada para a laje fica interditada (fita zebrada) na visita 3 até o Ato II ser concluído, e na visita 4.
func _montar_bloqueio_escada() -> void:
	if visita == 3 and GameState.flag("v3_ato2_feito"):
		return
	_bloqueio_escada = StaticBody3D.new()
	_bloqueio_escada.name = "EscadaInterditada"
	_bloqueio_escada.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.6, 2.4, 1.3)
	cs.shape = bs
	cs.position = Vector3(-12.3, 1.2, -19.55)
	_bloqueio_escada.add_child(cs)
	add_child(_bloqueio_escada)
	# fitas zebradas atravessando a porta (as mesmas da saída em reforma)
	var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 64:
			img.set_pixel(x, y, Color(0.95, 0.8, 0.1) if int((x + y) / 8) % 2 == 0 else Color(0.08, 0.08, 0.08))
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = ImageTexture.create_from_image(img)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var m := Malha.new()
	for par in [[1.0, -20.0, -19.1], [1.4, -19.1, -20.0], [1.8, -20.0, -19.1]]:
		var y: float = par[0]
		m.quad_uv(mat, Vector3(-12.3, y, par[1]), Vector3(-12.3, y + 0.1, par[2]), Vector3(-12.3, y + 0.2, par[2]), Vector3(-12.3, y + 0.1, par[1]), Vector3(1, 0, 0),
			Vector2(0, 0), Vector2(3, 0), Vector2(3, 1), Vector2(0, 1))
	m.construir_instancia(_bloqueio_escada, "Fitas", 2)
	var it := Interagivel.new("Escada interditada", Vector3(0.6, 2.2, 1.2), _escada_interditada)
	it.position = Vector3(-12.2, 1.1, -19.55)
	_bloqueio_escada.add_child(it)
	Epocas.marcar(_bloqueio_escada, [E2020])


func _escada_interditada(_p: Node) -> void:
	if visita == 3:
		await Guia.falar("quico", ["PIII! Escada interditada! Obra!", "Primeiro resolva essa porta nova aí no Salão."])
	else:
		await Guia.falar("sistema", ["A escada está interditada. Não há mais nada lá em cima."])


func _ato2_concluido() -> void:
	GameState.set_flag("v3_ato2_feito", true)
	Audio.musica("jingle_2")
	if _bloqueio_escada and is_instance_valid(_bloqueio_escada):
		_bloqueio_escada.queue_free()
		_bloqueio_escada = null
	if _porta_ato2 and is_instance_valid(_porta_ato2):
		_porta_ato2.queue_free()
		_porta_ato2 = null
	var no := find_child("PortaPara1950", false, false)
	if no:
		no.queue_free()


func _abrir_porta_ato2(_p: Node) -> void:
	if _saindo_ato2:
		return
	var destino := GameState.CENA_ATO2
	if not ResourceLoader.exists(destino):
		Guia.falar("sistema", ["O Ato II ainda não foi instalado."])
		return
	_saindo_ato2 = true
	GameState.entrar_sala(_global(11))
	await Guia.falar("bentinho", ["Essa porta não estava aqui antes...", "Pelas dunas! Isso não consta do roteiro da visita!"], true)
	# o trecho do Ato II (salas 55..60) tem checkpoint próprio: "Continuar" volta para lá
	GameState.checkpoint_sala = maxi(GameState.checkpoint_sala, GameState.CHECKPOINT_ATO2)
	GameState.salvar()
	await Transicao.ir_para(destino, "Spawn")
	_saindo_ato2 = false      # só chega aqui se a troca foi recusada (este nível continua vivo)


# ---------------------------------------------------------------- visita 4: painel solto, porta zebrada do hall, escada de 2019
## O p08 da visita 4: um painel torto, solto da parede da Sala dos Povos. Atrás dele fica o disco 2019 (e, em 2019, um
## desenho do Tito na parede).
func _montar_painel_solto() -> void:
	var raiz := Node3D.new()
	raiz.name = "PainelSolto"
	raiz.position = POS_PAINEL_SOLTO
	raiz.rotation_degrees.y = 90.0
	add_child(raiz)
	var desenho := _id_painel("p08")
	var folha := TitoCastelinho.folha(raiz, desenho if desenho.begins_with("desenho_") else "desenho_5", Vector3(0.0, 0.0, 0.05), 0.0, 1.3, 2)
	folha.rotation_degrees.z = 6.0
	_limitar_alcance(raiz, 9.0)
	Epocas.marcar(raiz, [E2020])
	_painel_solto = raiz
	_paineis["p08"] = raiz
	var it := Interagivel.new("Olhar atrás do painel solto", Vector3(1.5, 1.2, 0.8), _olhar_painel_solto)
	it.name = "PainelSoltoInterativo"
	it.position = POS_PAINEL_SOLTO + Vector3(0.15, 0.0, 0.0)
	add_child(it)
	Epocas.marcar(it, [E2020])


func _olhar_painel_solto(_p: Node) -> void:
	if GameState.discos.has(E2019):
		await Guia.falar("sistema", ["Atrás do painel só ficou a marca da fita."])
		return
	if _painel_solto and is_instance_valid(_painel_solto):
		var t := create_tween()
		t.tween_property(_painel_solto, "rotation_degrees:z", -38.0, 0.7).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	Audio.sfx_3d("porta", POS_PAINEL_SOLTO)
	GameState.ganhar_disco(E2019)
	Audio.sfx("selo")
	Efeitos.flash(0.25, Color(1, 1, 1), 0.35)
	await Guia.falar("sistema", ["Atrás do painel solto havia um disco do Visor.", "Este mostra o Castelinho em 2019, já em ruínas."])


## O desenho atrás do painel (pista que só existe em 2019) e a estante rasa onde o disco ficava.
func _montar_desenho_oculto_2019() -> void:
	var d := TitoCastelinho.folha(self, "desenho_6", Vector3(-26.37, 1.35, -13.0), 90.0, 0.7, 2)
	d.name = "DesenhoAtrasDoPainel"
	Epocas.marcar(d, [E2019])
	_limitar_alcance(d, 9.0)
	var it := Interagivel.new("Olhar o desenho na parede", Vector3(0.5, 0.9, 0.9), _olhar_desenho_2019)
	it.position = Vector3(-26.2, 1.35, -13.0)
	add_child(it)
	Epocas.marcar(it, [E2019])


func _olhar_desenho_2019(_p: Node) -> void:
	await Guia.falar("sistema", ["Um desenho a giz de cera na parede, escondido atrás do painel: dois olhos num fundo preto.", "Assinado: TITO."])
	_pista("desenho_2019")


## A porta zebrada do hall (sala 80): onde nunca houve porta. Aberta, com fitas rasgadas e água escorrendo pelos degraus.
func _montar_porta_porao() -> void:
	var m := Malha.new()
	var o := POS_PORTA_PORAO
	var amarela := StandardMaterial3D.new()
	var img := Image.create(64, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 64:
			img.set_pixel(x, y, Color(0.95, 0.8, 0.1) if int((x + y) / 8) % 2 == 0 else Color(0.08, 0.08, 0.08))
	amarela.albedo_texture = ImageTexture.create_from_image(img)
	amarela.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	amarela.cull_mode = BaseMaterial3D.CULL_DISABLED
	# o vão: uma escada de pedra que desce para dentro da parede, com água escorrendo (shaders/escada_falsa)
	for lado in [-1.0, 1.0]:
		m.caixa(castelo.m.madeira, o + Vector3(lado * 0.55 - 0.05, 0.0, -0.01), o + Vector3(lado * 0.55 + 0.05, 2.15, 0.07), Malha.F_TODAS, 1.0)
	m.caixa(castelo.m.madeira, o + Vector3(-0.6, 2.1, -0.01), o + Vector3(0.6, 2.2, 0.07), Malha.F_TODAS, 1.0)
	# poça na soleira: a água vem do hall e desce a escada
	var agua := Castelinho.mat_cor(Color(0.2, 0.38, 0.5, 0.65), 0.1, true)
	m.quad(agua, o + Vector3(-0.45, 0.02, 0.05), o + Vector3(0.45, 0.02, 0.05), o + Vector3(0.7, 0.02, 1.2), o + Vector3(-0.7, 0.02, 1.2), Vector3.UP)
	# fitas zebradas rasgadas: dois pedaços pendurados na moldura e um caído no chão
	m.quad_uv(amarela, o + Vector3(-0.55, 1.75, 0.08), o + Vector3(-0.05, 1.4, 0.08), o + Vector3(-0.05, 1.5, 0.08), o + Vector3(-0.55, 1.85, 0.08), Vector3(0, 0, 1),
		Vector2(0, 0), Vector2(3, 0), Vector2(3, 1), Vector2(0, 1))
	m.quad_uv(amarela, o + Vector3(0.55, 1.05, 0.08), o + Vector3(0.2, 0.55, 0.08), o + Vector3(0.2, 0.65, 0.08), o + Vector3(0.55, 1.15, 0.08), Vector3(0, 0, 1),
		Vector2(0, 0), Vector2(2, 0), Vector2(2, 1), Vector2(0, 1))
	m.quad_uv(amarela, o + Vector3(-0.3, 0.02, 0.5), o + Vector3(0.4, 0.02, 0.7), o + Vector3(0.4, 0.02, 0.8), o + Vector3(-0.3, 0.02, 0.6), Vector3.UP,
		Vector2(0, 0), Vector2(3, 0), Vector2(3, 1), Vector2(0, 1))
	var no := Node3D.new()
	no.name = "PortaZebradaDoHall"
	add_child(no)
	m.construir_instancia(no, "Porta", 2)
	no.add_child(_escada_falsa(0, Vector2(1.1, 2.1), o + Vector3(0, 1.05, 0.0), Vector3(0, 1.05, 0), Vector3.ZERO))
	Epocas.marcar(no, [E2020, E2019])
	_porta_porao = Interagivel.new("Descer", Vector3(1.4, 2.2, 0.8), _usar_porta_porao)
	_porta_porao.position = o + Vector3(0, 1.1, 0.3)
	add_child(_porta_porao)
	Epocas.marcar(_porta_porao, [E2020, E2019])


func _montar_escada_2019() -> void:
	# a escada que desce do chão da Sala Medieval só existe em 2019 (pista do Visor, V2 §4.2)
	# revisão V2: antes cinco faixas pintadas no chão (lia como ralo); agora um alçapão com a escada descendo para o
	# norte, por baixo do piso (shaders/escada_falsa), e uma borda de pedra quebrada em volta
	var m := Malha.new()
	var o := POS_ESCADA_2019
	var borda := Castelinho.mat_cor(Color(0.36, 0.33, 0.3), 1.0)
	m.caixa(borda, o + Vector3(-0.82, 0.0, -0.72), o + Vector3(0.82, 0.05, -0.6), Malha.F_SEM_BASE)
	m.caixa(borda, o + Vector3(-0.82, 0.0, 0.6), o + Vector3(0.82, 0.05, 0.72), Malha.F_SEM_BASE)
	m.caixa(borda, o + Vector3(-0.82, 0.0, -0.6), o + Vector3(-0.7, 0.05, 0.6), Malha.F_SEM_BASE)
	m.caixa(borda, o + Vector3(0.7, 0.0, -0.6), o + Vector3(0.82, 0.05, 0.6), Malha.F_SEM_BASE)
	var no := Node3D.new()
	no.name = "Escada2019"
	add_child(no)
	m.construir_instancia(no, "Escada", 2)
	no.add_child(_escada_falsa(1, Vector2(1.4, 1.2), o + Vector3(0, 0.03, 0), Vector3.ZERO, Vector3(-90, 0, 0)))
	Epocas.marcar(no, [E2019])
	_escada_2019 = Interagivel.new("Descer a escada", Vector3(1.4, 0.6, 1.4), _usar_escada_2019)
	_escada_2019.position = o + Vector3(0, 0.3, 0)
	add_child(_escada_2019)
	Epocas.marcar(_escada_2019, [E2019])


## Quad com a escada virtual (shaders/escada_falsa.gdshader). modo 0 = porta na parede, 1 = alçapão no chão.
func _escada_falsa(modo: int, tam: Vector2, pos: Vector3, origem: Vector3, rot_graus: Vector3) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = tam
	var mt := ShaderMaterial.new()
	mt.shader = preload("res://shaders/escada_falsa.gdshader")
	mt.set_shader_parameter("modo", modo)
	mt.set_shader_parameter("origem", origem)
	mt.set_shader_parameter("meia_largura", tam.x * 0.5 - 0.04)
	if modo == 1:
		mt.set_shader_parameter("vao_d", Vector2(-tam.y * 0.5, tam.y * 0.5))
		mt.set_shader_parameter("pisada", 0.34)
		mt.set_shader_parameter("espelho", 0.17)
		mt.set_shader_parameter("luz", 1.0)
	var mi := MeshInstance3D.new()
	mi.name = "EscadaQueDesce"
	mi.mesh = q
	mi.material_override = mt
	mi.position = pos
	mi.rotation_degrees = rot_graus
	mi.layers = 2
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


func _descer_porao() -> void:
	if _saindo_porao:
		return
	if GameState.sala_maxima < _global(21):
		await Guia.falar("sistema", ["Ainda tem coisa para ver na visita. Siga o caminho até o fim."])
		return
	var destino := GameState.CENA_PORAO
	if not ResourceLoader.exists(destino):
		Guia.falar("sistema", ["O porão ainda não foi instalado."])
		return
	_saindo_porao = true
	GameState.entrar_sala(SALA_V4_PORTA)
	await Guia.falar("???", ["Desce. É por aqui que ele ia."], true)
	GameState.comecar_visita(5)
	await Transicao.ir_para(destino, "Spawn")
	_saindo_porao = false


## A porta zebrada do hall é só clima: não desce. O único caminho é a escada da Sala Medieval, em 2019.
func _usar_porta_porao(_p: Node) -> void:
	if _porta_falando:
		return
	_porta_falando = true
	await Guia.falar("???", ["Daqui não."])
	_porta_falando = false


func _usar_escada_2019(_p: Node) -> void:
	_descer_porao()


## O Visor estourou a atenção (visita 4): a Figura Branca (a mesma do porão) aparece e persegue por persegue_s.
## Se pegar, a Figura mata o jogador e o main volta ao checkpoint (recarrega o nível, que some com ela).
func _on_figura_atravessou(_v: int) -> void:
	if visita != 4 or player == null or not is_instance_valid(player) or _saindo_porao:
		return
	if _figura_v4 == null or not is_instance_valid(_figura_v4):
		_figura_v4 = FiguraBranca.new()
		_figura_v4.name = "FiguraPerseguidora"
		_figura_v4.alvo = player
		_figura_v4.reaparecer_fn = _reaparecer_figura_v4
		add_child(_figura_v4)
	var dir := -player.global_transform.basis.z
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var p := player.global_position - dir * 7.0           # atrás do jogador
	_figura_v4.reiniciar(Vector3(p.x, player.global_position.y + 0.05, p.z), true)
	_figura_v4.velocidade = 2.2
	_persegue_id += 1
	var id := _persegue_id
	await get_tree().create_timer(persegue_s, false).timeout
	if id == _persegue_id and _figura_v4 and is_instance_valid(_figura_v4) and not _figura_v4.matou:
		_figura_v4.esconder()


func _reaparecer_figura_v4(_f: Node) -> Vector3:
	var dir := player.global_transform.basis.z
	dir.y = 0.0
	var p := player.global_position + dir.normalized() * 8.0
	return Vector3(p.x, player.global_position.y + 0.05, p.z)


func _exit_tree() -> void:
	_persegue_id += 1
	if _figura_v4 and is_instance_valid(_figura_v4):
		_figura_v4.esconder()
	if _visor_v4 and is_instance_valid(_visor_v4) and _visor_v4.figura_atravessou.is_connected(_on_figura_atravessou):
		_visor_v4.figura_atravessou.disconnect(_on_figura_atravessou)


# ================================================================== loop: luzes, olhos, apito, armadura, Tito, chuva
func _process(dt: float) -> void:
	_t += dt
	_animar_passaporte(dt)
	_t_luzes -= dt
	if _t_luzes <= 0.0:
		_t_luzes = 0.3
		_atualizar_luzes()
		_atualizar_armadura()
	_tremer_lampadas()
	_animar_discos(dt)
	if player == null or not is_instance_valid(player):
		return
	if vento and vento.visible:
		vento.global_position = player.global_position + Vector3(0, 2, 0)
	if chuva:
		chuva.global_position = player.global_position + Vector3(0, 9, 0)
		chuva.emitting = not _jogador_dentro()
		_goteiras(dt)
	if visita == 4:
		_relampagos(dt)
	elif visita == 3:
		_atualizar_janelas()
	if visita >= 3:
		_olhos_do_pinguim()
	if _tito_corredor:
		_atualizar_tito_corredor(dt)
	if _tito and _tito.visible:
		TitoCastelinho.animar(_tito, _t, player.camera.global_position)
	if _tito_visor and _tito_visor.visible:
		TitoCastelinho.animar(_tito_visor, _t + 2.0, player.camera.global_position)
	_t_apito -= dt
	if GameState.sala_atual == _global(16) and _t_apito <= 0.0 and player.velocity.length() > 4.2 and not Guia.ocupado() and visita <= 2:
		_t_apito = 6.0
		Audio.sfx("apito")
		Guia.falar("quico", ["PIII! Sem correr na escada, hein!"])
	if _quico19_pendente and player.global_position.distance_to(Vector3(-6.6, 3.5, -24.9)) < 1.2:
		_quico19_pendente = false
		_surgir_quico19()


## Dentro da planta do prédio (e sob teto): a chuva não cai ali.
func _jogador_dentro() -> bool:
	var p := player.global_position
	return p.x > -28.6 and p.x < -4.9 and p.z > -29.6 and p.z < -11.1 and p.y < 3.4


## Goteiras (visita 4): dentro do prédio, uma gota cai a cada poucos segundos.
func _goteiras(dt: float) -> void:
	if not _jogador_dentro():
		return
	_t_goteira -= dt
	if _t_goteira <= 0.0:
		_t_goteira = randf_range(3.5, 8.0)
		Audio.sfx_3d("goteira", player.global_position + Vector3(randf_range(-4, 4), 2.5, randf_range(-4, 4)))


func _olhos_do_pinguim() -> void:
	if _pinguim == null or not _pinguim.visible:
		return
	for nome in ["Olho_E", "Olho_D"]:
		var o := _pinguim.get_node_or_null(nome) as Node3D
		if o == null:
			continue
		var local: Vector3 = _pinguim.to_local(player.camera.global_position) - o.position
		var yaw := clampf(atan2(local.x, local.z), -0.6, 0.6)
		var pitch := clampf(-atan2(local.y, Vector2(local.x, local.z).length()), -0.4, 0.4)
		o.rotation = Vector3(pitch, yaw, 0)


func _atualizar_armadura() -> void:
	if player == null or visita != 3 or _armadura_estado >= 3 or GameState.sala_atual < _global(21):
		return
	if not GameState.flag("v3_ato2_feito"):
		return              # a armadura só "acorda" depois do Ato II (ordem guiada da visita 3)
	var p := player.camera.global_position
	var alvo := Vector3(-9.2, 1.0, -27.6)
	var dir := alvo - p
	if dir.length() > 14.0:
		return
	var cosseno := player.direcao_olhar().dot(dir.normalized())
	match _armadura_estado:
		0:
			if cosseno > 0.62:
				_armadura_estado = 1
		1:
			if cosseno < 0.15:
				_armadura_estado = 2
		2:
			if cosseno > 0.62:
				_armadura_estado = 3
				_armadura.visible = true
				Audio.sfx_3d("susto", _armadura.global_position)
				Efeitos.pulso(0.5, 0.3)
				GameState.somar("sustos")


# ================================================================== eventos por sala (chamados pelos gatilhos)
func _entrou(base: int) -> void:
	if base == SALA_V4_PORTA:
		if GameState.sala_maxima < _global(21):
			return              # a porta zebrada só conta depois de a Sala Medieval ter sido vista
		GameState.entrar_sala(SALA_V4_PORTA)
		_evt_sala80()
		return
	GameState.entrar_sala(_global(base))
	_evento(base)
	# o gatilho 80 (porta zebrada) está dentro do gatilho 7 (hall): se os dois disparam no mesmo quadro, a ordem é
	# arbitrária e o 7 podia derrubar o contador de 80 para 71. Quem está dentro da zona da porta fica em 80.
	if visita == 4 and base == 7 and _triggers.has(SALA_V4_PORTA) and player and is_instance_valid(player) \
			and (_triggers[SALA_V4_PORTA] as Area3D).overlaps_body(player):
		_entrou(SALA_V4_PORTA)


func _evento(base: int) -> void:
	match base:
		1: _evt_sala1()
		2: _evt_sala2()
		4: _evt_sala4()
		7: _evt_sala7()
		8: _evt_sala8()
		9: _evt_sala9()
		10: _evt_sala10()
		11: _evt_sala11()
		12: _evt_sala12()
		13: _evt_sala13()
		17: _evt_sala17()
		19: _evt_sala19()
		21: _evt_sala21()
		22: _evt_sala22()
		23: _evt_sala23()
		25: _evt_sala25()
	_mover_tito_visor(base)


func _mover_tito_visor(base: int) -> void:
	if _tito_visor:
		_tito_visor.position = _spot_tito_visor(base)


## Visita 4, sala 74 (corredor): um menino de costas no fundo, de bermuda e balde. Quando o jogador o encara, some.
## Só sugestão: ele não se move, não ataca e não faz nada; só deixa de estar lá.
func _evt_tito_corredor() -> void:
	if not _uma_vez("tito_corredor"):
		return
	_tito_corredor = TitoCastelinho.criar_tito()
	_tito_corredor.name = "TitoDeCostas"
	_tito_corredor.position = Vector3(-7.6, 0.0, -21.8)
	_tito_corredor.rotation_degrees.y = 90.0          # olha para +x (o leste): de costas para quem chega do oeste
	add_child(_tito_corredor)
	Epocas.marcar(_tito_corredor, [E2020])
	_tito_corredor_olhado = 0.0


func _atualizar_tito_corredor(dt: float) -> void:
	if not is_instance_valid(_tito_corredor):
		_tito_corredor = null
		return
	var alvo := _tito_corredor.global_position + Vector3(0, 0.7, 0)
	var dir := alvo - player.camera.global_position
	var dist := dir.length()
	var olhando: bool = dist < 10.0 and player.direcao_olhar().dot(dir.normalized()) > 0.9
	_tito_corredor_olhado = _tito_corredor_olhado + dt if olhando else maxf(0.0, _tito_corredor_olhado - dt)
	if _tito_corredor_olhado > 0.7 or dist < 2.0:
		_tito_corredor.queue_free()
		_tito_corredor = null
		Audio.sfx("crianca_ei", -14.0)
		Efeitos.pulso(0.3, 0.3)


## Visita 4, Sala do Pescador (sala 77): pegadas pequenas e molhadas vindas do arco e paradas diante do mural.
func _montar_pegadas_v4() -> void:
	_pegadas_v4 = Node3D.new()
	_pegadas_v4.name = "PegadasMolhadas"
	_pegadas_v4.visible = false
	add_child(_pegadas_v4)
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.albedo_color = Color(0.1, 0.16, 0.2, 0.7)
	mt.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var ini := Vector3(-6.5, 0.025, -16.1)
	var fim := Vector3(-8.6, 0.025, -14.85)
	var passos := 7
	var dirp := (fim - ini).normalized()
	for i in passos:
		var f := float(i) / float(passos - 1)
		var lado := -1.0 if i % 2 == 0 else 1.0
		var qm := QuadMesh.new()
		qm.size = Vector2(0.075, 0.17)
		var mi := MeshInstance3D.new()
		mi.mesh = qm
		mi.material_override = mt
		mi.position = ini.lerp(fim, f) + Vector3(-dirp.z, 0, dirp.x) * 0.06 * lado
		mi.rotation = Vector3(-PI * 0.5, atan2(-dirp.x, -dirp.z), 0)
		mi.layers = 2
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_pegadas_v4.add_child(mi)
	Epocas.marcar(_pegadas_v4, [E2020])
	var it := Interagivel.new("Olhar as pegadas", Vector3(2.0, 0.6, 1.4), Callable())
	it.position = Vector3(-7.6, 0.3, -15.5)
	it.name = "PegadasInterativo"
	it.acao = func(_p: Node) -> void:
		await Guia.falar("sistema", ["Pegadas pequenas, ainda molhadas.", "Vêm da porta e param diante do mural."])
	add_child(it)
	Epocas.marcar(it, [E2020])


func _evt_sala1() -> void:
	if not _uma_vez("sala1"):
		return
	match visita:
		1:
			await Guia.falar("bentinho", ["Oi! Eu sou o Bentinho!", "Bem-vindo à Visita Guiada do Castelinho!"])
			await _lancar_passaporte()
			# o recorte de papelão virado para a parede não é comentado por ninguém
		2:
			await Guia.falar("bentinho", ["Bem-vindo de volta!", "Atualizamos as informações da visita. Agora com mais verdade!"])
		3:
			await _quico_da_lanterna()
		4:
			await Guia.falar("???", ["Ninguém mais visita.", "Ninguém mais."])


## Visita 3: o Quico entrega a lanterna na calçada e some.
func _quico_da_lanterna() -> void:
	var q := _recorte("quico", Vector3(-21.4, 0, 0.2), 195.0, false)
	_quico_lanterna = q
	# a lanterna é gravada ANTES da fala: se o jogo fechar no meio dela, o "Continuar" não perde a lanterna
	GameState.set_flag("tem_lanterna")
	GameState.flags.erase("lanterna_desligada")
	if player and is_instance_valid(player):
		player.lanterna.visible = true
	await Guia.falar("quico", ["Tá escuro, guri! PIII!", "Leva a lanterna. Aperta F para ligar e desligar."], true)
	Audio.sfx("apito")
	Audio.sfx("selo")
	# o Quico some (de repente, sem despedida)
	await get_tree().create_timer(0.8).timeout
	if is_instance_valid(q):
		q.queue_free()
	_quico_lanterna = null


func _evt_sala2() -> void:
	if visita != 1 or not _uma_vez("sala2"):
		return
	await Guia.falar("taina", ["Eu sou a Tainá, a tainha!", "Vou fazer umas perguntinhas!"])


func _evt_sala4() -> void:
	if visita != 1 or not _uma_vez("sala4"):
		return
	await Guia.falar("quico", ["Eu sou o Quico! Fiscal da visita!", "Não sai do caminho, hein! PIII!"])
	Audio.sfx("apito")
	await Guia.falar("quico", ["Cada quiz que você acerta vale um selo. Eu guardo todos!"])


func _evt_sala7() -> void:
	if visita == 4 and _uma_vez("sala7"):
		await Guia.falar("???", ["O prédio está errado. Você também sente?"])
	elif visita == 3 and _uma_vez("sala7"):
		await Guia.falar("bentinho", ["Eu não devia estar aqui à noite.", "Ninguém me disse quando a visita termina."])


func _evt_sala8() -> void:
	if visita == 4 and _uma_vez("sala8"):
		await Guia.falar("???", ["Desculpa...", "A gente devia ter procurado melhor.", "O painel ali está solto. Olha atrás dele."])


func _evt_sala9() -> void:
	if visita == 3 and _uma_vez("sala9"):
		await Guia.falar("bentinho", ["O pinguim estava virado para a parede.", "Eu lembro. Eu lembro?"])
		return
	if visita != 1 or not _uma_vez("sala9"):
		return
	await Guia.falar("bentinho", ["Olha só o pinguim! Ele parece vivo, né?"])


func _evt_sala10() -> void:
	if visita == 4:
		_evt_tito_corredor()
		return
	if visita == 3:
		# ordem guiada: o corredor aponta para o Salão de Arte (a porta nova) antes de o jogador vagar pelo resto
		if not GameState.flag("v3_ato2_feito") and _uma_vez("corredor_dica"):
			await Guia.falar("bentinho", ["O Salão de Arte fica no fim do corredor.", "Tem uma porta lá que eu não conheço."])
		return
	if visita != 1 or GameState.discos.has(E1950) or _passaporte_falando:
		return
	_passaporte_falando = true
	var n := GameState.passaporte_achados()
	if n < GameState.PASSAPORTE_IDS.size():
		# faltam objetos: o Bentinho diz quantos e onde procurar (sem trava: eles seguem nos lugares).
		# Uma vez por contagem de carimbos: o corredor é passagem e a fala não pode repetir a cada travessia.
		if not _uma_vez("quase_%d" % n):
			_passaporte_falando = false
			return
		GameState.set_flag("passaporte_lancado")
		var falta: Array = []
		for id in GameState.PASSAPORTE_IDS:
			if not GameState.flag("passaporte_" + id):
				falta.append(id)
		var dica: String = PASSAPORTE[falta[0]]["dica"]
		await Guia.falar("bentinho", ["Quase lá! Seu Passaporte tem %d de 3 carimbos." % n, "Falta%s %d. %s" % ["m" if falta.size() > 1 else "", falta.size(), dica]])
		_passaporte_falando = false
		return
	# Passaporte completo: o Visor do Tempo vem com o Disco 1950, um "brinde educativo" (V2 §3.1)
	_uma_vez("sala10")
	GameState.set_flag("tem_visor")
	GameState.ganhar_disco(GameState.Epoca.E1950)
	Audio.sfx("fanfarra")
	await Guia.falar("bentinho", ["Três carimbos! Passaporte completo, parabéns!"])
	Audio.sfx("selo")
	await Guia.falar("bentinho", ["Presente! O Visor do Tempo!", "Segure Q para ver como era em 1950!"])
	_passaporte_falando = false


func _evt_sala11() -> void:
	if not _uma_vez("sala11"):
		return
	match visita:
		1:
			await Guia.falar("bentinho", ["Este é o Salão de Arte da nossa cidade!", "Quanta cor, quanta cor!"])
		2:
			await Guia.falar_engasgado("bentinho", ["Este é o Salão de Arte da nossa cidade!", "Quanta cor, quanta cor!"])
		3:
			await Guia.falar("bentinho", ["Hum... essa porta na parede aqui não estava no mapa.", "Será que eu... posso abrir?"])


func _evt_sala12() -> void:
	if visita == 2 and _uma_vez("sala12"):
		_telefone_tocando = true
		_tocar_telefone()
		if not GameState.discos.has(E1967):
			await get_tree().create_timer(1.0).timeout
			Guia.falar("sistema", ["Tem um disco numa vitrine do Acervo, com uma etiqueta escrita à mão."])
	elif visita == 2 and not GameState.flag(_chave("telefone_atendido")) and not _telefone_tocando:
		# não atendeu (ou o nível foi recriado pela Barra): volta a tocar ao reentrar na sala, até atender
		_telefone_tocando = true
		_tocar_telefone()
	elif visita >= 3 and not GameState.discos.has(E1967) and _uma_vez("dica1967"):
		await Guia.falar("sistema", ["Na vitrine do Acervo ainda há um disco \"não catalogado\"."])


func _tocar_telefone() -> void:
	for i in 8:
		if not _telefone_tocando or not is_inside_tree():
			return
		Audio.sfx_3d("telefone", _telefone.global_position)
		await get_tree().create_timer(2.6).timeout
	_telefone_tocando = false      # ninguém atendeu: toca de novo quando o jogador reentrar na sala 12


func _atender_telefone(_p: Node) -> void:
	if not _telefone_tocando:
		Guia.falar("sistema", ["O telefone está mudo."])
		return
	_telefone_tocando = false
	GameState.set_flag(_chave("telefone_atendido"), true)
	var linhas := ["Alô? É do Castelinho?", "O meu filho... ele vinha sempre brincar aí na obra...", "Vocês viram o Tito?"]
	var cls := _classe("Telefone")
	if cls:
		var r = cls.call("tocar", linhas)
		if r is Object and (r as Object).has_signal("terminou"):
			await r.terminou
	else:
		Audio.sfx("chiado_radio")
		await Guia.falar("???", linhas)
	Audio.sfx("clique")
	GameState.somar("sustos")


func _evt_sala13() -> void:
	if visita == 4 and _uma_vez("sala13"):
		# as pegadas aparecem só agora (e uma gota cai): quem passou por aqui acabou de sair
		if _pegadas_v4:
			_pegadas_v4.visible = true
			Audio.sfx_3d("goteira", _pegadas_v4.global_position + Vector3(0, 0.3, 0))
		return
	if visita != 2 or not _uma_vez("sala13"):
		return
	await Guia.falar("taina", ["Ainda bem que eu não sou pescada... né?", "Aquele mural é bonito. Dá vontade de entrar nele."])


func _usar_mural(_p: Node) -> void:
	if visita != 2 or GameState.flag("viu_flashback_barra"):
		match visita:
			1:
				Guia.falar("bentinho", ["Que mural bonito! Os pescadores fazem parte da história de Imbé."])
			4:
				Guia.falar("???", ["Tem uma criança na margem. Você viu?"])
			_:
				Guia.falar("bentinho", ["Já vimos esse mural! Vamos continuar a visita!"])
		return
	if _saindo_barra:
		return
	# (era uma flag salva em GameState, mas o código depois do `await` nunca rodava: o nível é destruído na troca.
	# Quem saísse do jogo no meio da ida à Barra voltava com o mural "ocupado" para sempre.)
	_saindo_barra = true
	GameState.entrar_sala(_global(14))
	await Guia.falar("taina", ["Que mural bonito! Parece até que dá para entrar nele..."], true)
	await Transicao.ir_para("res://world/niveis/barra.tscn", "Spawn")
	_saindo_barra = false      # só chega aqui se a troca foi recusada (este nível continua vivo)


## Volta da Barra (sala 37): um recorte de pescador cai da porta (susto-piada nº 1, visita 2).
func _evt_sala15() -> void:
	await get_tree().create_timer(1.6).timeout
	var r: Node3D = _recortes["pescador"]
	r.visible = true
	r.rotation_degrees = Vector3(0, 180, 0)
	var t := create_tween()
	t.tween_property(r, "rotation_degrees:x", -88.0, 0.45).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await t.finished
	Audio.sfx("susto")
	Efeitos.pulso(0.6, 0.35)
	GameState.somar("sustos")
	await Guia.falar("bentinho", ["Hahaha! Te peguei!"])


func _evt_sala17() -> void:
	if visita == 3:
		_ato2_concluido()
		if not GameState.discos.has(E1975) and _uma_vez("dica1975"):
			await Guia.falar("sistema", ["Algo brilha num pedestal, aqui no topo da torre."])


func _evt_sala19() -> void:
	if visita != 3 or not _uma_vez("sala19"):
		return
	_quico19_pendente = true


func _surgir_quico19() -> void:
	var r: Node3D = _recortes["quico"]
	r.visible = true
	r.position = Vector3(-7.2, 3.5, -23.75)
	Audio.sfx("susto")
	Efeitos.pulso(0.4, 0.3)
	GameState.somar("sustos")


func _evt_sala21() -> void:
	if visita == 3:
		_armadura_estado = 0 if _armadura_estado < 3 else 3
		if not GameState.flag("v3_ato2_feito") and _uma_vez("sala21_cedo"):
			await Guia.falar("bentinho", ["Esta sala está pronta. O resto da visita ficou no Salão de Arte.", "Aquela porta que não estava no mapa."])
	elif visita == 4 and _uma_vez("sala21"):
		if GameState.discos.has(E2019):
			await Guia.falar("???", ["O chão desta sala tem uma escada. Só que não agora.", "Segure Q e escolha o disco de 2019: lá ela existe."])
		else:
			await Guia.falar("???", ["O chão desta sala tem uma escada. Só que não agora.", "Falta o disco de 2019.", "Ele ficou atrás de algo solto."])


func _evt_sala22() -> void:
	pass


func _evt_sala23() -> void:
	match visita:
		3:
			if not GameState.flag("v3_ato2_feito"):
				if _uma_vez("sala23_cedo"):
					await Guia.falar("bentinho", ["Ops! A saída está em reforma!", "A porta nova do Salão de Arte... será que leva a algum lugar?"])
			elif _uma_vez("sala23"):
				await Guia.falar("bentinho", ["Ops! A saída está em reforma!", "Mas o Visor mostra outro caminho... Tecle 1 a 5 e escolha o disco de 1975."])
		4:
			if _uma_vez("sala23"):
				await Guia.falar("???", ["A saída está fechada. A de verdade é no hall."])


## Corredor de 1975 (visita 3): o Visor mente (a época trava em 1975) e o jogador atravessa para a visita seguinte.
func _evt_sala25() -> void:
	GameState.set_flag("visor_travado", true)
	GameState.trocar_epoca(GameState.Epoca.E1975)
	if _uma_vez("sala25"):
		await Guia.falar("???", ["Este corredor... é mais longo do que a casa."])


## Visita 4, sala 80: a porta zebrada do hall. Água escorrendo pelos degraus.
func _evt_sala80() -> void:
	if _uma_vez("sala80"):
		await Guia.falar("???", ["Essa porta nunca existiu.", "Ouça. A água desce por aqui."])


func _on_painel_lido(id: String) -> void:
	match id.get_slice("_v", 0):
		"p06":
			_abrir_porta_entrada(false)
		"quiz_final":
			_diploma()


func _abrir_porta_entrada(imediato: bool) -> void:
	if castelo.porta_entrada == null:
		return
	GameState.set_flag("porta_entrada_aberta", true)
	var fe := castelo.porta_entrada.get_node_or_null("Folha_E") as Node3D
	var fd := castelo.porta_entrada.get_node_or_null("Folha_D") as Node3D
	if fe == null or fd == null:
		return
	if imediato:
		fe.rotation_degrees.y = -105.0
		fd.rotation_degrees.y = 105.0
		return
	Audio.sfx("confete")
	Audio.sfx("fanfarra")
	_confete(Vector3(-6.55, 2.6, -10.2))
	Audio.sfx_3d("porta", Vector3(-6.55, 1.0, -11.2))
	var t := create_tween().set_parallel()
	t.tween_property(fe, "rotation_degrees:y", -105.0, 1.0).set_trans(Tween.TRANS_SINE)
	t.tween_property(fd, "rotation_degrees:y", 105.0, 1.0).set_trans(Tween.TRANS_SINE)


func _confete(pos: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.name = "Confete"
	p.position = pos
	p.amount = 90
	p.lifetime = 3.0
	p.one_shot = true
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0.3)
	p.spread = 70.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 5.5
	p.gravity = Vector3(0, -3.2, 0)
	p.angular_velocity_min = -300.0
	p.angular_velocity_max = 300.0
	var qm := QuadMesh.new()
	qm.size = Vector2(0.09, 0.05)
	p.mesh = qm
	var mt := StandardMaterial3D.new()
	mt.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mt.vertex_color_use_as_albedo = true
	mt.cull_mode = BaseMaterial3D.CULL_DISABLED
	p.material_override = mt
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(0.3, 0.8, 1), Color(1, 0.9, 0.2), Color(0.5, 1, 0.4), Color(1, 0.5, 0.9)])
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	p.color_initial_ramp = g
	add_child(p)
	p.emitting = true
	get_tree().create_timer(4.5).timeout.connect(p.queue_free)


# ================================================================== fim da visita
## Diploma da visita (depois do quiz final). Visita 2: sai com o nome "TITO" já escrito, depois o apagão e o balde.
func _diploma() -> void:
	if visita >= 4:
		return                  # V4: o painel do quiz é só um desenho riscado
	if not _uma_vez("diploma"):
		return
	if visita == 3:
		await _diploma_recusado()
		return
	if visita == 2:
		GameState.set_flag("diploma_nome", "TITO")       # contrato com ui/diploma.gd (ver docs/PENDENCIAS.md)
	if ResourceLoader.exists("res://ui/diploma.tscn"):
		var d := Diploma.mostrar()
		if visita == 2:
			_tentar_nome_no_diploma(d, "TITO")
		await d.fechado
	else:
		await Guia.falar("sistema", ["Parabéns! Você concluiu a Visita Guiada!"])
	if visita == 2:
		await _apagao_e_balde()
		return
	await Guia.falar("bentinho", ["Parabéns! Você concluiu a Visita Guiada!", "Agora é só sair pela porta... pela porta..."])


## Visita 3: o quiz corrompido aceita qualquer resposta e o diploma não sai (bônus perturbador, não trava nada).
func _diploma_recusado() -> void:
	Audio.sfx("erro")
	Efeitos.pulso(0.5, 0.4)
	await Guia.falar("sistema", ["Parabéns! Diploma em emissão...", "Diploma indisponível. Visitante não identificado."])
	await get_tree().create_timer(0.8).timeout
	Audio.sfx("clique", -4.0, 0.8)
	await Guia.falar("bentinho", ["Não liga. Era só uma formalidade.", "Ninguém aqui foi identificado. Nem eu."])


func _tentar_nome_no_diploma(d: Object, nome: String) -> void:
	if d == null:
		return
	if d.has_method("definir_nome"):
		d.call("definir_nome", nome)
		return
	for prop in d.get_property_list():
		if prop["name"] == "nome":
			d.set("nome", nome)
			return


## Primeiro medo de verdade (fim da visita 2): as luzes apagam por 2 s; quando voltam, um dos tronos tem um balde
## vermelho (e um desenho novo na parede). Sem violência, sem criatura: só a ausência e o objeto.
func _apagao_e_balde() -> void:
	if not _uma_vez("apagao"):
		return
	await Guia.falar("bentinho", ["Parabéns! Você concluiu a Visita Guiada!"])
	player.pode_mover = false
	var camada := CanvasLayer.new()
	camada.layer = 8
	var rect := ColorRect.new()
	rect.color = Color(0, 0, 0, 0)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(rect)
	add_child(camada)
	Audio.sfx("clique")
	var t := create_tween()
	t.tween_property(rect, "color:a", 1.0, 0.12)
	await t.finished
	_criar_balde_e_desenho3()
	GameState.definir_corruption_manual(0.5)      # o apagão é o pico da visita 2 (a Barra fica em 0,35)
	# revisão V2: no escuro, um sussurro baixinho (não um grito: é o primeiro medo, ainda é a visita 2), e a luz volta
	# falhando (acende, apaga, acende) em vez de um fade limpo: o olho procura o que mudou
	await get_tree().create_timer(0.9).timeout
	Audio.sfx("sussurro", -10.0, 0.85)
	await get_tree().create_timer(1.1).timeout
	Audio.sfx("clique")
	var t2 := create_tween()
	t2.tween_property(rect, "color:a", 0.15, 0.06)
	t2.tween_interval(0.12)
	t2.tween_property(rect, "color:a", 0.95, 0.04)
	t2.tween_interval(0.22)
	t2.tween_callback(func(): Audio.sfx("clique", -4.0, 1.1))
	t2.tween_property(rect, "color:a", 0.0, 0.3)
	await t2.finished
	camada.queue_free()
	GameState.definir_corruption_manual(-1.0)
	player.pode_mover = true
	await get_tree().create_timer(0.8).timeout
	await Guia.falar("bentinho", ["Hum... alguém deixou um balde no trono.", "Deve ser de alguma criança da visita. Duas, talvez. Vamos sair!"])


func _usar_porta_saida(_p: Node) -> void:
	if visita >= 3:
		Guia.falar("sistema", ["A porta está lacrada com fitas zebradas: EM REFORMA."])
		return
	if not GameState.flag(_chave("diploma")):
		Guia.falar("bentinho", ["Ainda falta o quiz final!", "Leia o painel do quiz para ganhar o diploma."])
		return
	if visita == 2 and not GameState.flag(_chave("apagao")):
		return
	_fim_de_visita()


func _abrir_porta_final(_p: Node) -> void:
	# só a visita 3 sai por aqui; na 4 (o disco de 1975 continua com o jogador) ela pulava o porão e virava "visita 5"
	if visita != 3:
		Guia.falar("sistema", ["A porta está trancada."])
		return
	_fim_de_visita()


## Fim da visita (§8.2): comecar_visita(n+1), a placa "Volte sempre!" (só nas visitas 1->2 e 2->3), e de volta à calçada.
func _fim_de_visita() -> void:
	if _saindo_visita:
		return
	_saindo_visita = true
	var n := visita
	GameState.set_flag("visor_travado", false)
	GameState.comecar_visita(n + 1)      # grava a visita 4 antes do beat: fechar o jogo aqui não perde o progresso
	if n == 3:
		await _beat_final_v3()
	if n <= 2:
		await _volte_sempre()
	if n >= 3:
		GameState.trocar_epoca(GameState.Epoca.E2020)
	await Transicao.ir_para(GameState.CENA_CASTELINHO, "Spawn")
	_saindo_visita = false      # só chega aqui se a troca foi recusada


## Fim da visita 3 (atravessar a porta do corredor de 1975): as marcas de altura do Tito, "TITO 6, 7, 8, 9" e depois
## nada, e uma última fala engasgada. Só sugestão; depois disso o fade leva à visita 4.
func _beat_final_v3() -> void:
	if player and is_instance_valid(player):
		player.pode_mover = false
	Efeitos.pulso(0.4, 0.4)
	var ui := PainelUI.mostrar("marcas_altura")
	if ui:
		await ui.fechado
	await Guia.falar_engasgado("bentinho", ["Obrigado pela visita...", "Volte sem-sem-sempre. Alguém precisa voltar."], true)
	if player and is_instance_valid(player):
		player.pode_mover = true


## A placa "Obrigado pela visita! Volte sempre!": usa VolteSempre (agente Visor/UI) se existir; senão, um plano B nosso.
func _volte_sempre() -> void:
	var cls := _classe("VolteSempre")
	if cls:
		var r = cls.call("mostrar")
		if r is Object and (r as Object).has_signal("terminou"):
			await r.terminou
		return
	var camada := CanvasLayer.new()
	camada.layer = 90
	var rect := ColorRect.new()
	rect.color = Color(0.05, 0.1, 0.2, 0.0)
	rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	camada.add_child(rect)
	var l := Label.new()
	l.text = "Obrigado pela visita!\nVolte sempre!"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.add_theme_font_size_override("font_size", 56)
	l.modulate = Color(1, 1, 1, 0)
	camada.add_child(l)
	add_child(camada)
	var t := create_tween().set_parallel()
	t.tween_property(rect, "color:a", 1.0, 0.7)
	t.tween_property(l, "modulate:a", 1.0, 0.7)
	await t.finished
	await get_tree().create_timer(1.8).timeout
