extends Node3D
## Nível "Castelinho" (salas 1 a 25 do Ato I). Monta o prédio (Castelinho), o entorno (EntornoCastelinho), a
## iluminação por época, os marcadores, as SalaTrigger e todos os eventos do roteiro (docs/MVP_ROTEIRO.md).
## Layout interior documentado em castelinho/LEIAME.md.
##
## Marcadores: Spawn (sala 1, calçada), Checkpoint_1/6/11/16/21/25, Spawn_volta_barra (Sala do Pescador),
## e câmeras Cam_* só para capturas de conferência com as fotos (tests/captura_cam.gd).
##
## Eventos: cada um acontece uma única vez, controlado por flags "evt_*" em GameState (persistem no save).
## Épocas: tudo que é "museu" só existe em E2020; os painéis P24/P25 e o corredor só em E1975.

const E1950 := 0   # GameState.Epoca (enum) como inteiros, para poder usar em const
const E1975 := 1
const E2019 := 2
const E2020 := 3

const AMBIENTES := {
	# época: [céu topo, céu horizonte, cor do Sol, energia do Sol, pitch, yaw, cor ambiente, energia amb., cor névoa, densidade névoa]
	E2020: [Color(0.52, 0.65, 0.84), Color(0.84, 0.89, 0.95), Color(1.0, 0.97, 0.9), 1.2, -52.0, 40.0, Color(0.78, 0.8, 0.86), 0.55, Color(0.84, 0.88, 0.93), 0.0022],
	E1975: [Color(0.5, 0.45, 0.58), Color(1.0, 0.68, 0.42), Color(1.0, 0.6, 0.28), 1.25, -16.0, 110.0, Color(0.95, 0.7, 0.52), 0.55, Color(0.96, 0.7, 0.5), 0.006],
	E1950: [Color(0.52, 0.52, 0.56), Color(0.76, 0.73, 0.68), Color(0.88, 0.84, 0.78), 0.55, -40.0, 40.0, Color(0.66, 0.64, 0.62), 0.7, Color(0.74, 0.71, 0.66), 0.012],
	E2019: [Color(0.46, 0.52, 0.54), Color(0.68, 0.72, 0.7), Color(0.8, 0.86, 0.82), 0.6, -50.0, 40.0, Color(0.62, 0.68, 0.66), 0.6, Color(0.66, 0.72, 0.7), 0.009],
}

const MAX_LUZES_ATIVAS := 5
const X_COR := EntornoCastelinho.X_CORREDOR
const Z_COR_FIM := EntornoCastelinho.Z_CORREDOR_FIM

var castelo: Castelinho
var entorno: Dictionary
var player: Player
var sol: DirectionalLight3D
var ambiente: Environment
var ceu: ProceduralSkyMaterial
var vento: CPUParticles3D

var _luzes: Array = []                # [{no: OmniLight3D, pos: Vector3}]
var _t_luzes := 0.0
var _paineis: Dictionary = {}
var _triggers := {}                   # número da sala -> SalaTrigger
var _props: Malha                     # postes dos painéis externos, marcas de arrasto
var _pinguim: Node3D
var _armadura: Node3D
var _recortes := {}                   # nome -> Node3D
var _telefone: Interagivel
var _telefone_tocando := false
var _mural: Interagivel
var _porta_saida_1975: Interagivel
var _t_apito := 0.0
var _armadura_estado := 0             # 0 = nunca olhou, 1 = olhou, 2 = desviou o olhar, 3 = apareceu
var _quico19_pendente := false


func _ready() -> void:
	_montar_ambiente()
	castelo = Castelinho.new()
	castelo.name = "Predio"
	add_child(castelo)
	entorno = EntornoCastelinho.construir(self, castelo)
	_marcadores()
	_criar_luzes()
	_montar_triggers()
	_montar_objetos()
	_montar_paineis()
	_montar_props()
	_montar_vento()
	GameState.epoca_mudou.connect(_on_epoca)
	GameState.sala_mudou.connect(_on_sala)
	_on_epoca(GameState.epoca)


func iniciar(p: Player) -> void:
	player = p
	Visor.instalar(self)
	Audio.musica("jingle")
	if GameState.flag("porta_entrada_aberta"):
		_abrir_porta_entrada(true)
	_atualizar_luzes()
	if GameState.flag("viu_flashback_barra"):
		# voltou do flashback da Barra: os gatilhos 13/14 não podem derrubar o contador de 15
		for n in [13]:
			if _triggers.has(n):
				_triggers[n].monitoring = false
		if _uma_vez("sala15"):
			_evt_sala15()


# ================================================================== céu, Sol, névoa, vento
func _montar_ambiente() -> void:
	var we := WorldEnvironment.new()
	ambiente = Environment.new()
	ceu = ProceduralSkyMaterial.new()
	ceu.sun_angle_max = 1.0
	ceu.sky_curve = 0.25
	var sky := Sky.new()
	sky.sky_material = ceu
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
	Epocas.marcar(vento, [E1950])


func _on_epoca(e: int) -> void:
	var a: Array = AMBIENTES.get(e, AMBIENTES[E2020])
	ceu.sky_top_color = a[0]
	ceu.sky_horizon_color = a[1]
	ceu.ground_horizon_color = a[1]
	ceu.ground_bottom_color = (a[1] as Color).darkened(0.25)
	sol.light_color = a[2]
	sol.light_energy = a[3]
	sol.rotation_degrees = Vector3(a[4], a[5], 0)
	ambiente.ambient_light_color = a[6]
	ambiente.ambient_light_energy = a[7]
	ambiente.fog_light_color = a[8]
	ambiente.fog_density = a[9]
	if e == E1950:
		Audio.ambiente("vento")
	else:
		Audio.ambiente("")
	_atualizar_luzes()
	_checar_sala24()


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
	_marcar("Checkpoint_1", Vector3(-23.0, 0.1, 1.5), -28.0)
	_marcar("Checkpoint_6", Vector3(-6.55, 0.1, -9.0), 0.0)
	_marcar("Checkpoint_11", Vector3(-8.5, 0.1, -19.5), 180.0)
	_marcar("Checkpoint_16", Vector3(-12.3, 0.1, -19.55), 90.0)
	_marcar("Checkpoint_21", Vector3(-12.6, 0.1, -24.2), 0.0)
	_marcar("Checkpoint_25", Vector3(X_COR, 0.1, -31.0), 0.0)
	_marcar("Spawn_volta_barra", Vector3(-8.6, 0.1, -15.6), 0.0)
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
	_cam("Cam_topo_torre", Vector3(-19.5, 8.3, -12.2), Vector3(-6.0, 4.0, -12.0), 80.0)
	_cam("Cam_pescador", Vector3(-8.7, 1.55, -15.9), Vector3(-8.7, 1.35, -14.2), 74.0)
	_cam("Cam_pescador2", Vector3(-6.0, 1.55, -15.6), Vector3(-9.5, 1.3, -14.2), 80.0)
	_cam("Cam_corredor", Vector3(-23.5, 1.55, -21.8), Vector3(-6.0, 1.5, -21.8), 72.0)
	_cam("Cam_escada", Vector3(-12.8, 1.55, -19.55), Vector3(-21.0, 3.0, -19.55), 75.0)
	_cam("Cam_terraco", Vector3(-6.5, 5.0, -12.6), Vector3(-18.0, 5.0, -12.9), 75.0)
	_cam("Cam_salaarte", Vector3(-8.5, 1.55, -19.6), Vector3(-10.5, 1.3, -17.6), 72.0)
	_cam("Cam_povos", Vector3(-17.0, 1.55, -12.9), Vector3(-26.0, 1.3, -12.9), 72.0)
	_cam("Cam_ambiente", Vector3(-19.0, 1.55, -15.6), Vector3(-23.0, 1.0, -16.8), 72.0)
	_cam("Cam_medieval2", Vector3(-12.6, 1.55, -23.8), Vector3(-13.5, 1.4, -29.0), 78.0)
	_cam("Cam_torreb", Vector3(-7.6, 3.5, -23.7), Vector3(-6.6, 4.5, -26.0), 80.0)
	_cam("Cam_spawn", Vector3(-23.0, 1.55, 1.5), Vector3(-12.0, 2.5, -11.0), 72.0)
	_cam("Cam_deck", Vector3(-10.7, 1.55, -2.5), Vector3(-10.7, 2.5, -11.0), 72.0)
	_cam("Cam_corredor1975", Vector3(X_COR, 1.55, -31.0), Vector3(X_COR, 1.5, -60.0), 72.0)


# ================================================================== luzes internas (poucas, quentes)
func _criar_luzes() -> void:
	for l in castelo.luzes:
		var o := OmniLight3D.new()
		o.position = l["pos"]
		o.light_color = Color(1.0, 0.82, 0.55)
		o.light_energy = 1.4
		o.omni_range = 7.0
		o.omni_attenuation = 1.2
		o.shadow_enabled = false
		o.visible = false
		add_child(o)
		_luzes.append({"no": o, "pos": l["pos"], "sala": l.get("sala", "")})


## Liga só as MAX_LUZES_ATIVAS luzes mais próximas do jogador (a web não aguenta muitas OmniLight3D).
func _atualizar_luzes() -> void:
	var ref := Vector3(-23.0, 1.5, 1.5)
	if player and is_instance_valid(player):
		ref = player.global_position
	else:
		var cam := get_viewport().get_camera_3d()
		if cam:
			ref = cam.global_position
	var cand: Array = []
	for l in _luzes:
		var d: float = (l["pos"] as Vector3).distance_to(ref)
		cand.append([d, l["no"]])
	cand.sort_custom(func(a, b): return a[0] < b[0])
	var i := 0
	for par in cand:
		var no: OmniLight3D = par[1]
		no.visible = i < MAX_LUZES_ATIVAS and par[0] < 16.0
		if no.visible:
			i += 1


# ================================================================== SalaTrigger de cada sala
func _trigger(n: int, centro: Vector3, tam: Vector3, epocas: Array = []) -> SalaTrigger:
	var t := SalaTrigger.new(n, tam)
	t.name = "Sala_%02d" % n
	t.position = centro
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
	_trigger(24, Vector3(-12.6, 0, -26.0), Vector3(7.0, 3, 5.0), [E1975])
	_trigger(25, Vector3(X_COR, 0, -31.2), Vector3(2.0, 3, 2.4), [E1975])
	# na ida e volta da escada: depois de chegar à sala 17 o gatilho 16 sai de cena; o 20 só vale depois da 19
	GameState.sala_mudou.connect(func(n: int) -> void:
		if n >= 17 and _triggers.has(16):
			_triggers[16].monitoring = false
		if n == 19 and _triggers.has(20):
			_triggers[20].monitoring = true
		if n >= 21 and _triggers.has(20):
			_triggers[20].monitoring = false
	)


# ================================================================== painéis (Painel3D) e objetos interativos
func _painel(id: String, pos: Vector3, yaw := 0.0, epocas: Array = [E2020], poste := false) -> Painel3D:
	var p := Painel3D.new(id)
	p.position = pos
	p.rotation_degrees.y = yaw
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
	_painel("p01", Vector3(-21.0, 1.4, -2.2), 0.0, [E2020], true)
	var p02 := _painel("p02", Vector3(-24.8, 1.4, -4.6), 0.0, [E2020], true)
	_painel("p03", Vector3(-24.2, 1.4, -7.6), 0.0, [E2020], true)
	_painel("p04", Vector3(-10.7, 1.4, -3.2), 0.0, [E2020], true)
	_painel("p05", Vector3(-9.4, 1.4, -9.2), 0.0, [E2020], true)
	_painel("p06", Vector3(-4.6, 1.4, -9.0), -90.0, [E2020], true)
	# interior (nas paredes)
	_painel("p07", Vector3(-7.4, 1.5, -13.74), 0.0)
	_painel("p08", Vector3(-26.76, 1.45, -13.0), 90.0)
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
	_painel("quiz_final", Vector3(-16.56, 1.5, -28.3), 90.0)
	_painel("p23", Vector3(-8.64, 1.5, -24.6), -90.0, [E2020, E2019])
	_painel("p24", Vector3(-8.64, 1.5, -24.6), -90.0, [E1975])
	_painel("p25", Vector3(X_COR + 1.07, 1.5, -48.0), -90.0, [E1975])
	# folha de costela-de-Adão brotando no canto do painel P02 (semente "creepy" do roteiro)
	var folha := _folha_costela()
	folha.position = p02.position + Vector3(0.78, -0.45, 0.07)
	add_child(folha)
	Epocas.marcar(folha, [E2020])


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


func _montar_objetos() -> void:
	# pinguim empalhado (Meio Ambiente): os olhos acompanham o jogador
	_pinguim = MobiliaCastelinho.criar_pinguim()
	_pinguim.position = Vector3(-22.6, 0.03, -16.0)
	_pinguim.rotation_degrees.y = 160.0
	add_child(_pinguim)
	Epocas.marcar(_pinguim, [E2020])
	# telefone antigo do acervo (interagível: atender)
	var tel := MobiliaCastelinho.criar_telefone()
	tel.position = Vector3(-6.6, 0.8, -19.0)
	add_child(tel)
	Epocas.marcar(tel, [E2020])
	_telefone = Interagivel.new("Atender o telefone", Vector3(0.5, 0.4, 0.5), _atender_telefone)
	_telefone.position = Vector3(-6.6, 0.95, -19.0)
	add_child(_telefone)
	Epocas.marcar(_telefone, [E2020])
	# mural da Sala do Pescador (leva ao flashback da Barra)
	_mural = Interagivel.new("Olhar o mural", Vector3(3.8, 2.0, 0.5), _usar_mural)
	_mural.position = Vector3(-8.7, 1.5, -14.5)
	add_child(_mural)
	Epocas.marcar(_mural, [E2020])
	# armadura que aparece no trono (sala 21)
	_armadura = MobiliaCastelinho.criar_armadura()
	_armadura.position = Vector3(-9.25, 0.0, -28.2)
	_armadura.rotation_degrees.y = -90.0
	_armadura.visible = false
	add_child(_armadura)
	# recortes de papelão
	_recortes["visitante"] = _recorte("visitante", Vector3(-17.0, 0, -9.6), 0.0, true)    # virado para a parede
	_recortes["pescador"] = _recorte("pescador", Vector3(-6.4, 0, -17.55), 180.0, false)
	_recortes["pescador"].visible = false
	_recortes["quico"] = _recorte("quico", Vector3(-7.2, 3.5, -24.2), 180.0, false)
	_recortes["quico"].visible = false
	# fita zebrada na porta de saída em reforma (sala 23)
	_fita_zebrada()
	# porta final do corredor de 1975 (leva ao Ato II)
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
	if de_costas:
		raiz.rotation_degrees.y = 180.0 + yaw        # a frente (desenho) vira para a parede
	return raiz


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


# ================================================================== loop: luzes, olhos, apito, armadura
func _process(dt: float) -> void:
	_t_luzes -= dt
	if _t_luzes <= 0.0:
		_t_luzes = 0.3
		_atualizar_luzes()
		_atualizar_armadura()
	if player == null or not is_instance_valid(player):
		return
	if vento and vento.visible:
		vento.global_position = player.global_position + Vector3(0, 2, 0)
	_olhos_do_pinguim()
	_t_apito -= dt
	if GameState.sala_atual == 16 and _t_apito <= 0.0 and player.velocity.length() > 4.2 and not Guia.ocupado():
		_t_apito = 6.0
		Audio.sfx("apito")
		Guia.falar("quico", ["PIII! Sem correr na escada, hein!"])
	if _quico19_pendente and player.global_position.distance_to(Vector3(-6.6, 3.5, -24.9)) < 1.2:
		_quico19_pendente = false
		_surgir_quico19()


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
	if player == null or _armadura_estado >= 3 or GameState.sala_atual < 21:
		return
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


# ================================================================== eventos por sala
func _uma_vez(nome: String) -> bool:
	var chave := "evt_" + nome
	if GameState.flag(chave):
		return false
	GameState.set_flag(chave, true)
	return true


func _on_sala(n: int) -> void:
	match n:
		1: _evt_sala1()
		2: _evt_sala2()
		4: _evt_sala4()
		9: _evt_sala9()
		10: _evt_sala10()
		11: _evt_sala11()
		12: _evt_sala12()
		13: _evt_sala13()
		19: _evt_sala19()
		21: _armadura_estado = 0 if _armadura_estado < 3 else 3
		23: _evt_sala23()
		24: _evt_sala24()
		25: _evt_sala25()


func _evt_sala1() -> void:
	if not _uma_vez("sala1"):
		return
	await Guia.falar("bentinho", ["Oi! Eu sou o Bentinho!", "Bem-vindo à Visita Guiada do Castelinho!"])
	# o recorte de papelão virado para a parede não é comentado por ninguém


func _evt_sala2() -> void:
	if not _uma_vez("sala2"):
		return
	await Guia.falar("taina", ["Eu sou a Tainá, a tainha!", "Vou fazer umas perguntinhas!"])


func _evt_sala4() -> void:
	if not _uma_vez("sala4"):
		return
	await Guia.falar("quico", ["Eu sou o Quico! Fiscal da visita!", "Não sai do caminho, hein! PIII!"])
	Audio.sfx("apito")
	await Guia.falar("quico", ["Cada quiz que você acerta vale um selo. Eu guardo todos!"])


func _evt_sala9() -> void:
	if not _uma_vez("sala9"):
		return
	await Guia.falar("bentinho", ["Olha só o pinguim! Ele parece vivo, né?"])


func _evt_sala10() -> void:
	if not _uma_vez("sala10"):
		return
	GameState.set_flag("tem_visor")
	Audio.sfx("selo")
	await Guia.falar("bentinho", ["Presente! O Visor do Tempo!", "Segure Q para ver como era em 1950!"])


func _evt_sala11() -> void:
	if not _uma_vez("sala11"):
		return
	await Guia.falar_engasgado("bentinho", ["Este é o Salão de Arte da nossa cidade!", "Quanta cor, quanta cor!"])


func _evt_sala12() -> void:
	if not _uma_vez("sala12"):
		return
	_telefone_tocando = true
	_tocar_telefone()


func _tocar_telefone() -> void:
	for i in 8:
		if not _telefone_tocando or not is_inside_tree():
			return
		Audio.sfx_3d("telefone", _telefone.global_position)
		await get_tree().create_timer(2.6).timeout


func _atender_telefone(_p: Node) -> void:
	if not _telefone_tocando:
		Guia.falar("sistema", ["O telefone está mudo."])
		return
	_telefone_tocando = false
	Audio.sfx("chiado_radio")
	await Guia.falar("???", ["Alô? ...A temporada acabou?"])
	Audio.sfx("clique")
	GameState.somar("sustos")


func _evt_sala13() -> void:
	if not _uma_vez("sala13"):
		return
	await Guia.falar("taina", ["Ainda bem que eu não sou pescada... né?"])


func _usar_mural(_p: Node) -> void:
	if GameState.flag("viu_flashback_barra"):
		Guia.falar("bentinho", ["Já vimos esse mural! Vamos continuar a visita!"])
		return
	if GameState.flag("saindo_para_barra"):
		return
	GameState.set_flag("saindo_para_barra", true)
	GameState.entrar_sala(14)
	await Guia.falar("taina", ["Que mural bonito! Parece até que dá para entrar nele..."], true)
	await Transicao.ir_para("res://world/niveis/barra.tscn", "Spawn")
	GameState.set_flag("saindo_para_barra", false)


## Volta da Barra (sala 15): um recorte de pescador cai da porta (susto-piada nº 1).
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


func _evt_sala19() -> void:
	if not _uma_vez("sala19"):
		return
	_quico19_pendente = true


func _surgir_quico19() -> void:
	var r: Node3D = _recortes["quico"]
	r.visible = true
	r.position = Vector3(-7.2, 3.5, -23.75)
	Audio.sfx("susto")
	Efeitos.pulso(0.4, 0.3)
	GameState.somar("sustos")


func _evt_sala23() -> void:
	GameState.set_flag("epoca_visor", GameState.Epoca.E1975)
	if not _uma_vez("sala23"):
		return
	await Guia.falar("bentinho", ["Ops! A saída está em reforma!", "Mas o Visor mostra outro caminho..."])


func _evt_sala24() -> void:
	GameState.set_flag("epoca_visor", GameState.Epoca.E1975)
	if _uma_vez("sala24"):
		await Guia.falar("sistema", ["Os painéis foram reescritos."])


func _evt_sala25() -> void:
	GameState.checkpoint_sala = maxi(GameState.checkpoint_sala, 25)
	GameState.set_flag("visor_travado", true)
	GameState.trocar_epoca(GameState.Epoca.E1975)
	if _uma_vez("sala25"):
		await Guia.falar("???", ["Este corredor... é mais longo do que a casa."])


## Se o jogador troca para 1975 já dentro da Sala Medieval, conta a sala 24 mesmo sem cruzar o gatilho.
func _checar_sala24() -> void:
	if player == null or not is_instance_valid(player) or GameState.epoca != E1975:
		return
	var p := player.global_position
	if p.x > -16.6 and p.x < -8.6 and p.z > -29.2 and p.z < -23.5 and p.y < 1.0 and GameState.sala_atual in [21, 22, 23]:
		GameState.entrar_sala(24)


func _on_painel_lido(id: String) -> void:
	match id:
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


func _diploma() -> void:
	if not _uma_vez("diploma"):
		return
	if ResourceLoader.exists("res://ui/diploma.tscn"):
		var d := Diploma.mostrar()
		await d.fechado
	else:
		await Guia.falar("sistema", ["Parabéns! Você concluiu a Visita Guiada!"])
	await Guia.falar("bentinho", ["Parabéns! Você concluiu a Visita Guiada!", "Agora é só sair pela porta... pela porta..."])


func _abrir_porta_final(_p: Node) -> void:
	var destino := "res://world/niveis/ato2.tscn"
	if ResourceLoader.exists(destino):
		await Transicao.ir_para(destino, "Spawn")
	else:
		Guia.falar("sistema", ["O Ato II ainda não foi instalado."])
