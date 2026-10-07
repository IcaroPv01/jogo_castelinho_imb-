extends Node3D
## O PORÃO (V2_ROTEIRO §6): a masmorra "fora da planta" embaixo do Castelinho. Salas globais 81 a 99.
##
##  - 19 salas sorteadas com SEMENTE FIXA NO SAVE (`GameState.flag("porao_semente")`): a 1ª é a escada da porta zebrada,
##    a 15ª (sala 95) é o QUARTO DO TITO, as 4 últimas (96 a 99) são o ÚLTIMO DIA (slides do disco sem data) e as 13 do
##    meio saem dos 11 tipos de `PoraoSalas` + 2 bifurcações (a sala da voz).
##  - Só existem 2 ou 3 salas por vez (anterior, atual, próxima): a próxima é montada quando o jogador entra na atual e
##    a anterior é descarregada depois que a porta se fecha atrás dele. Orçamento web: < 150 draw calls, <= 6 luzes
##    (cada sala tem no máximo 2; as da sala anterior apagam na hora), névoa de profundidade.
##  - A ÁGUA SOBE a cada 5 salas (nas salas 86, 91 e 96: tornozelo, joelho, cintura), o jogador anda mais devagar
##    conforme a profundidade, com o som "agua_sobe" e a ambiência "goteira".
##  - ÉPOCA SEM DATA: pistas e passagens que só existem com o disco sem data (ou 1967) via `Epocas.marcar`.
##  - CHECKPOINTS nas salas 81, 86, 91 e 96 (`Checkpoint_81`...); `ao_morrer()` volta ao último.
##  - AMEAÇAS: Figura Branca (regra de sempre + a que o Visor solta com a atenção cheia), Costela-de-Adão (cipós que
##    crescem se o jogador fica parado) e a voz do Tito (certa ou fatal: a bifurcação com água funda).
##  - Sala 99: sobe por uma escada ao luar e vai para `braco_morto.tscn` (sala 100).
##
## Marcadores: `Spawn` e `Checkpoint_<N>` para qualquer N de 81 a 99 (criados sob demanda em `ponto_spawn`).
## Contrato com o Main: `iniciar(player)`, `ao_morrer()`, `ponto_spawn(nome)` (Checkpoint_N / Spawn),
## `pontos_aquecer()`. Contadores que este nível ESCREVE: `pistas_tito` (+1 por pista, uma vez cada, flag `pista_<id>`).

const SalasGd := preload("res://world/niveis/porao_salas.gd")
const CostelaGd := preload("res://creatures/costela.gd")

signal sala_entrada(idx: int)            # o jogador entrou na sala de índice idx (0..18)
signal agua_subiu(nivel: int)
signal disco_pego
signal saiu_do_porao

const PRIMEIRA := 81
const N := 19
const SALA_QUARTO := 95
const SALA_ULTIMA := 99
## Checkpoints internos (a morte volta ao último). O `GameState` só grava 81 e 95 (SALAS_CHECKPOINT); ver PENDENCIAS.
const CHECKPOINTS: Array[int] = [81, 86, 91, 95, 96]
## Profundidade da água (m acima do piso) em cada nível: nada, tornozelo, joelho, cintura.
const PROF_AGUA: Array[float] = [0.0, 0.22, 0.55, 0.95]
const TEMPO_SUBIR := 6.0
const COSTELA_OK: Array[String] = ["abobada", "colunas", "desenhos", "crianca", "pedras", "arcos", "telefone", "poco"]
const FIGURA_OK: Array[String] = ["abobada", "colunas", "desenhos", "pedras", "arcos", "poco", "cisterna"]
const VOZ_OK: Array[String] = ["abobada", "colunas", "pedras", "desenhos", "arcos", "poco"]
const T := 0.6

var player: Player
var figura: FiguraBranca
var costela: Node3D
var semente := 1
var plano: Array = []                 # um Dictionary por sala (índice 0 = sala 81)
var salas := {}                       # idx -> Ctx (só as carregadas)
var idx_atual := -1
var ultimo_checkpoint := 81
var prof := 0.0:                      # profundidade global da água (m), animada pelo `_subir_agua`
	set(v):
		prof = v
		_aplicar_agua()
var nivel_agua := 0
var env: Environment
var mat_agua: ShaderMaterial
var afogando := false
var morrendo := false
var visor: Node
var disco_pego_aqui := false

var _t := 0.0
var _ultima_pos := Vector3.ZERO
var _tem_ultima := false
var _voz_t := 4.0
var _passo_agua_t := 0.0
var _pistas_t := 0.0
var _causa := ""
var _cortina: ColorRect
var _legenda: Label
var _tween_legenda: Tween
var _tween_agua: Tween
var _tween_env: Tween
var _fator_agua := 1.0
var _epoca_ant := -1


func _ready() -> void:
	process_physics_priority = 100        # depois do jogador: encolhe o deslocamento dentro d'água
	_semente()
	_gerar_plano()
	_ambiente()
	_criar_agua_material()
	_hud_proprio()
	_carregar_sala(0)
	_carregar_sala(1)
	var sp := Marker3D.new()
	sp.name = "Spawn"
	salas[0].raiz.add_child(sp)
	sp.position = Vector3(0, 0.1, -1.0)
	GameState.epoca_mudou.connect(_ao_mudar_epoca)
	_atualizar_luzes(0)
	_aplicar_agua()


# ============================================================================ semente e plano das 19 salas
func _semente() -> void:
	semente = int(GameState.flag("porao_semente", 0))
	if semente <= 0:
		semente = randi_range(1000, 1 << 29)
		GameState.set_flag("porao_semente", semente)


## Sorteia os tipos, as ameaças e as vozes com a semente do save e calcula a posição (no mundo) de cada sala.
func _gerar_plano() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = semente
	var tipos: Array = SalasGd.TIPOS_SORTEIO.duplicate()
	tipos.append("bifurcacao")
	tipos.append("bifurcacao")
	for tentativa in 500:
		for i in range(tipos.size() - 1, 0, -1):
			var j := rng.randi_range(0, i)
			var tmp = tipos[i]
			tipos[i] = tipos[j]
			tipos[j] = tmp
		if _tipos_validos(tipos):
			break
	var lista: Array[String] = ["escada"]
	for t in tipos:
		lista.append(t)
	lista.append_array(["quarto_tito", "abobada", "arcos", "cisterna", "escada_sobe"])
	plano.clear()
	for i in N:
		plano.append({"tipo": lista[i], "idx": i, "sala": PRIMEIRA + i, "ultimo": 96 + (i - 15) if i >= 15 and i <= 17 else (99 if i == 18 else 0),
			"costela": false, "figura": false, "voz_ambiente": false, "voz_certa": true, "lado": 1 if rng.randf() < 0.5 else -1})
	# vozes: as duas bifurcações, uma certa e uma errada (em ordem aleatória)
	var certas := [true, false]
	if rng.randf() < 0.5:
		certas.reverse()
	var k := 0
	for d in plano:
		if d["tipo"] == "bifurcacao":
			d["voz_certa"] = certas[k]
			k += 1
	# ameaças: nada na 1ª sala de cada bloco com checkpoint (81, 86, 91): quem acabou de morrer não nasce no meio
	var livres_bloco := [0, 5, 10]
	var cand_costela := []
	var cand_figura := []
	var cand_voz := []
	for i in range(1, 14):
		if i in livres_bloco:
			continue
		var tp: String = plano[i]["tipo"]
		if tp in COSTELA_OK:
			cand_costela.append(i)
		if tp in FIGURA_OK:
			cand_figura.append(i)
		if tp in VOZ_OK:
			cand_voz.append(i)
	_embaralhar(cand_costela, rng)
	for i in mini(4, cand_costela.size()):
		plano[cand_costela[i]]["costela"] = true
	_embaralhar(cand_figura, rng)
	var f := 0
	for i in cand_figura:
		if f >= 4:
			break
		if plano[i]["costela"]:
			continue
		plano[i]["figura"] = true
		f += 1
	_embaralhar(cand_voz, rng)
	var v := 0
	for i in cand_voz:
		if v >= 3:
			break
		if plano[i]["costela"] or plano[i]["figura"]:
			continue
		plano[i]["voz_ambiente"] = true
		v += 1
	# transformações (as salas se encadeiam em linha reta; a escada muda o `y`)
	var t := Transform3D.IDENTITY
	var w_prev: float = SalasGd.DIMS["escada"]["w"]
	for i in N:
		var dim: Dictionary = SalasGd.DIMS[plano[i]["tipo"]]
		plano[i]["t"] = t
		plano[i]["w_prev"] = 3.6 if i == 0 else w_prev
		t = t * Transform3D(Basis(), Vector3(0, dim["dy"], -dim["L"] - T))
		w_prev = dim["w"]


func _tipos_validos(tipos: Array) -> bool:
	if tipos[0] == "escada" or tipos[0] == "bifurcacao":
		return false
	for i in tipos.size() - 1:
		if tipos[i] == "bifurcacao" and tipos[i + 1] == "bifurcacao":
			return false
		if tipos[i] == tipos[i + 1]:
			return false
	# a bifurcação não fica colada na escada (a escada desce e esconde o fundo da sala)
	for i in tipos.size():
		if tipos[i] == "bifurcacao" and ((i > 0 and tipos[i - 1] == "escada") or (i < tipos.size() - 1 and tipos[i + 1] == "escada")):
			return false
	return true


func _embaralhar(a: Array, rng: RandomNumberGenerator) -> void:
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = a[i]
		a[i] = a[j]
		a[j] = tmp


func nivel_da_sala(sala: int) -> int:
	if sala >= 96:
		return 3
	if sala >= 91:
		return 2
	if sala >= 86:
		return 1
	return 0


# ============================================================================ ambiente e água
func _ambiente() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.016, 0.022, 0.022)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.34, 0.40, 0.40)
	env.ambient_light_energy = 0.55
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.018, 0.026, 0.026)
	env.fog_depth_begin = 2.0
	env.fog_depth_end = 26.0
	env.fog_depth_curve = 1.1
	we.environment = env
	add_child(we)


func _criar_agua_material() -> void:
	mat_agua = ShaderMaterial.new()
	mat_agua.shader = load("res://shaders/porao_agua.gdshader")


func _aplicar_agua() -> void:
	for i in salas:
		_ajustar_agua_sala(salas[i])


func _agua_y_local(c) -> float:
	var minimo: float = 0.14 if c.tipo == "alagado" else 0.0
	return c.base_agua + maxf(prof, minimo)


func _ajustar_agua_sala(c) -> void:
	var y := _agua_y_local(c)
	var no := c.raiz.get_node_or_null("Agua") as MeshInstance3D
	if no:
		no.position.y = y
		no.visible = c.agua and (prof > 0.02 or c.base_agua <= -1.0 or c.tipo == "alagado") and no.get_meta("visivel_epoca", true)
	var y_mundo: float = c.raiz.global_position.y + y
	SalasGd.definir_agua(c, y_mundo, c.raiz.global_position.y + c.base_agua)
	# objetos que boiam (o balde do slide 4) seguem a água
	for n in c.nos_agua_alvo:
		if is_instance_valid(n):
			(n as Node3D).position.y = y + 0.06


# ============================================================================ salas: carregar e descarregar
func _carregar_sala(i: int) -> void:
	if i < 0 or i >= N or salas.has(i):
		return
	var d: Dictionary = plano[i]
	var c := SalasGd.Ctx.new()
	c.tipo = d["tipo"]
	c.idx = i
	c.sala = d["sala"]
	c.rng.seed = semente * 131 + i
	c.w_prev = d["w_prev"]
	c.ultimo = d["ultimo"]
	c.com_costela = d["costela"]
	c.com_figura = d["figura"]
	c.lamina_saida = i == N - 1
	c.porta_aberta = true
	if i == 15 and not _tem_disco():
		c.porta_aberta = false          # a sala 96 só abre depois que o jogador pega o disco sem data
	if c.tipo == "bifurcacao":
		c.pontos["lado_armadilha"] = d["lado"]
		c.voz = {"certa": d["voz_certa"]}
	var raiz := Node3D.new()
	raiz.name = "Sala%d" % c.sala
	raiz.transform = d["t"]
	add_child(raiz)
	c.raiz = raiz
	SalasGd.construir(c)
	salas[i] = c
	if c.voz.is_empty() and d["voz_ambiente"]:
		c.voz = {"pos": c.pontos["voz"], "certa": true}
	if c.com_costela:
		CostelaGd.decor(raiz, c.rng, c.w, c.L, 3.3, 7)
		SalasGd.rotulo(c, "NAO PARA", Vector3(-c.w * 0.5 + 0.04, 1.4, -1.8), 90.0, 40, Color(0.15, 0.3, 0.85, 0.95), 0.004)
	# água
	if c.agua:
		var plano_a := PlaneMesh.new()
		plano_a.size = Vector2(c.w + 0.1, c.L)
		var mi := MeshInstance3D.new()
		mi.name = "Agua"
		mi.mesh = plano_a
		mi.material_override = mat_agua
		mi.position = Vector3(0, c.base_agua, -c.L * 0.5)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		raiz.add_child(mi)
		if i == 15:
			# no último dia, ao sair de casa, a água ainda não tinha subido: o plano some na época sem data
			Epocas.marcar(mi, [GameState.Epoca.E2020, GameState.Epoca.E1950, GameState.Epoca.E1975, GameState.Epoca.E2019, GameState.Epoca.E1967])
	_criar_extras(c)
	_ajustar_agua_sala(c)
	_atualizar_luzes(idx_atual)


## Telefone, disco, sandália, voz com marca do Visor, afogamento e a saída final.
func _criar_extras(c) -> void:
	if c.pontos.has("telefone"):
		var tel := Interagivel.new("Atender o telefone", Vector3(0.8, 0.5, 0.6), _atender_telefone.bind(c))
		tel.position = c.pontos["telefone"]
		c.raiz.add_child(tel)
		c.interativos.append(tel)
	if c.pontos.has("disco") and not _tem_disco():
		var di := Interagivel.new("Pegar o disco", Vector3(0.5, 0.4, 0.5), _pegar_disco.bind(c))
		di.position = c.pontos["disco"]
		di.name = "InteragivelDisco"
		c.raiz.add_child(di)
		c.interativos.append(di)
	elif c.pontos.has("disco"):
		var disco := c.raiz.get_node_or_null("Disco")
		if disco:
			disco.visible = false
	if c.pontos.has("sandalia"):
		var sa := Interagivel.new("Pegar a sandália", Vector3(0.5, 0.4, 0.5), _pegar_sandalia.bind(c))
		sa.position = c.pontos["sandalia"]
		c.raiz.add_child(sa)
		c.interativos.append(sa)
	if not c.voz.is_empty():
		_marca_voz(c)
	if c.afogar:
		c.afogar.body_entered.connect(func(corpo: Node):
			if corpo.is_in_group("player"):
				_afogar())
	if c.idx == N - 1:
		var saida := Area3D.new()
		saida.name = "SaidaFinal"
		saida.collision_layer = 0
		saida.collision_mask = 2
		saida.monitorable = false
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.6, 2.6, 1.2)
		cs.shape = bs
		cs.position = Vector3(0, c.dy + 1.3, -c.L + 0.5)
		saida.add_child(cs)
		c.raiz.add_child(saida)
		saida.body_entered.connect(func(corpo: Node):
			if corpo.is_in_group("player"):
				_ir_ao_braco_morto())


## A marca que o Visor (disco 1967 ou sem data) mostra no lugar da voz: um facho VERMELHO com um balde (a voz é
## verdadeira: segue-la leva à saída) ou um facho AZUL com ondas (a voz leva à água funda).
func _marca_voz(c) -> void:
	var certa: bool = c.voz.get("certa", true)
	var pos_voz: Vector3 = c.voz["pos"]
	var chao_y: float = c.piso_fn.call(pos_voz.z)
	var no := Node3D.new()
	no.name = "MarcaVoz"
	no.position = Vector3(pos_voz.x, chao_y + 0.03, pos_voz.z)
	c.raiz.add_child(no)
	var cor := Color(0.95, 0.12, 0.08) if certa else Color(0.2, 0.45, 1.0)
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var m_fa := StandardMaterial3D.new()
	m_fa.albedo_color = Color(cor.r, cor.g, cor.b, 0.35)
	m_fa.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m_fa.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m_fa.cull_mode = BaseMaterial3D.CULL_DISABLED
	var facho := CylinderMesh.new()
	facho.top_radius = 0.05
	facho.bottom_radius = 0.18
	facho.height = 1.9
	facho.radial_segments = 8
	facho.rings = 1
	facho.cap_top = false
	facho.cap_bottom = false
	var mf := MeshInstance3D.new()
	mf.mesh = facho
	mf.material_override = m_fa
	mf.position.y = 0.95
	no.add_child(mf)
	if certa:
		var balde := CylinderMesh.new()
		balde.top_radius = 0.15
		balde.bottom_radius = 0.11
		balde.height = 0.24
		balde.radial_segments = 8
		balde.rings = 1
		var mb := MeshInstance3D.new()
		mb.mesh = balde
		mb.material_override = m
		mb.position.y = 0.14
		no.add_child(mb)
	else:
		var anel := TorusMesh.new()
		anel.inner_radius = 0.25
		anel.outer_radius = 0.32
		anel.rings = 14
		anel.ring_segments = 4
		var ma := MeshInstance3D.new()
		ma.mesh = anel
		ma.material_override = m
		ma.position.y = 0.04
		ma.scale = Vector3(1.0, 0.25, 1.0)
		no.add_child(ma)
		for k in 3:
			var onda := BoxMesh.new()
			onda.size = Vector3(0.5 - k * 0.1, 0.02, 0.05)
			var mo := MeshInstance3D.new()
			mo.mesh = onda
			mo.material_override = m
			mo.position = Vector3(0, 0.06 + k * 0.5, 0)
			no.add_child(mo)
	Epocas.marcar(no, [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA])


func _descarregar_sala(i: int) -> void:
	if not salas.has(i):
		return
	var c = salas[i]
	salas.erase(i)
	if is_instance_valid(c.raiz):
		c.raiz.queue_free()


func _descarregar_todas() -> void:
	for i in salas.keys():
		_descarregar_sala(i)


## Só as luzes da sala atual e da próxima ficam acesas (orçamento de 6 luzes: 2 + 2 + a lanterna do jogador).
func _atualizar_luzes(cur: int) -> void:
	for i in salas:
		var ligada: bool = i == cur or i == cur + 1 or cur < 0 and i <= 1
		for l in salas[i].luzes:
			if is_instance_valid(l):
				l.visible = ligada


func total_luzes_visiveis() -> int:
	var n := 0
	for l in get_tree().get_nodes_in_group("") if false else []:
		n += 1
	for i in salas:
		for l in salas[i].luzes:
			if is_instance_valid(l) and l.is_visible_in_tree():
				n += 1
	if is_instance_valid(player) and player.lanterna and player.lanterna.visible:
		n += 1
	return n


# ============================================================================ contrato com o Main
## Chamado pelo Main depois de colocar o jogador no marcador.
func iniciar(p: Player) -> void:
	player = p
	if GameState.visita != 5:
		GameState.comecar_visita(5)
	GameState.set_flag("visor_travado", false)
	_criar_figura()
	_criar_costela()
	visor = Visor.instalar(self)
	if visor.has_signal("figura_atravessou"):
		visor.figura_atravessou.connect(_on_figura_atravessou)
	GameState.jogador_morreu.connect(func(causa: String): _causa = causa)
	var i := _sala_por_posicao(p.global_position, 1.0)
	if i < 0:
		i = 0
	nivel_agua = nivel_da_sala(PRIMEIRA + i)
	prof = PROF_AGUA[nivel_agua]
	_ao_entrar_sala(i, true)
	Audio.musica("", 1.0)
	Audio.ambiente("goteira", -9.0, 2.0)


## Vistas para o aquecimento de shaders atrás da tela de carregamento (ver main.gd).
func pontos_aquecer() -> Array:
	var lista: Array = []
	for i in [0, 1]:
		if salas.has(i):
			var t: Transform3D = salas[i].raiz.global_transform
			lista.append({"transform": t * Transform3D(Basis(), Vector3(0, 1.55, -1.5))})
			lista.append({"transform": t * Transform3D(Basis(Vector3.UP, PI), Vector3(0, 1.55, -salas[i].L * 0.5))})
	return lista


## Main chama quando o marcador `Checkpoint_N` não existe: monta a sala N (e a seguinte) e devolve o marcador.
func ponto_spawn(nome: String) -> Node3D:
	var i := 0
	if nome.begins_with("Checkpoint_"):
		i = clampi(int(nome.get_slice("_", 1)) - PRIMEIRA, 0, N - 1)
	if i == 0:
		return salas[0].raiz.get_node_or_null("Spawn") as Node3D
	_descarregar_todas()
	_carregar_sala(i)
	_carregar_sala(i + 1)
	var c = salas[i]
	var sp := Marker3D.new()
	sp.name = nome
	c.raiz.add_child(sp)
	sp.position = Vector3(0, 0.1, -1.1)
	idx_atual = -1
	return sp


# ============================================================================ o jogo por quadro
func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player):
		return
	var pos := player.global_position
	_verificar_sala(pos)
	_lentidao_da_agua(pos, dt)
	_voz_t -= dt
	if _voz_t <= 0.0:
		_voz_t = randf_range(5.5, 9.0)
		_chamar_voz()
	_pistas_t -= dt
	if _pistas_t <= 0.0:
		_pistas_t = 0.2
		_checar_pistas()


func _process(dt: float) -> void:
	_t += dt
	var cur := idx_atual
	for i in salas:
		var c = salas[i]
		if i != cur and i != cur + 1:
			continue
		var k := 0
		for l in c.luzes:
			if is_instance_valid(l) and l.visible:
				var base: float = l.get_meta("energia_base", 1.5)
				l.light_energy = base * (0.92 + 0.08 * sin(_t * 9.0 + k * 2.3) + 0.05 * sin(_t * 23.0 + k))
			k += 1
		if c.tipo == "telefone" and i == cur and not c.get_meta("atendido", false) if c.has_method("get_meta") else false:
			pass
	_telefone_toca(dt)


var _tel_t := 0.0


## O telefone da sala do telefone toca de tempos em tempos enquanto ninguém atende.
func _telefone_toca(dt: float) -> void:
	if idx_atual < 0 or not salas.has(idx_atual):
		return
	var c = salas[idx_atual]
	if not c.pontos.has("telefone") or bool(GameState.flag("telefone_porao_atendido")):
		return
	_tel_t -= dt
	if _tel_t <= 0.0:
		_tel_t = 5.5
		Audio.sfx_3d("telefone", c.raiz.to_global(c.pontos["telefone"]), -4.0)


## Que sala (índice) contém esta posição do mundo? -1 se nenhuma. `z_min` = quanto o jogador precisa ter entrado.
func _sala_por_posicao(p: Vector3, z_min := 1.2) -> int:
	var melhor := -1
	for i in salas:
		var c = salas[i]
		var l: Vector3 = c.raiz.to_local(p)
		if l.z > -z_min or l.z < -c.L:
			continue
		if absf(l.x) > c.w * 0.5 + 0.6 + 5.6:      # inclui o corredor lateral da bifurcação
			continue
		if l.y < -4.0 + minf(0.0, c.dy) or l.y > 8.0 + maxf(0.0, c.dy):
			continue
		if melhor < 0 or i > melhor:
			melhor = i
	return melhor


func _verificar_sala(pos: Vector3) -> void:
	var i := _sala_por_posicao(pos)
	if i >= 0 and i != idx_atual:
		_ao_entrar_sala(i)


## O jogador entrou na sala de índice `i`: contador, porta que se fecha, próxima sala, água, ameaças, checkpoint.
func _ao_entrar_sala(i: int, imediato := false) -> void:
	var anterior := idx_atual
	idx_atual = i
	var sala := PRIMEIRA + i
	GameState.entrar_sala(sala)
	if sala in CHECKPOINTS:
		ultimo_checkpoint = sala
	_carregar_sala(i)
	_carregar_sala(i + 1)
	_atualizar_luzes(i)
	_fechar_porta(i, imediato)
	if anterior >= 0 and not imediato:
		# a anterior some depois que a porta fecha (com folga para o jogador não ver o vazio)
		get_tree().create_timer(1.4, false).timeout.connect(func():
			for k in salas.keys():
				if k < idx_atual:
					_descarregar_sala(k))
	# água
	var novo := nivel_da_sala(sala)
	if novo > nivel_agua:
		_subir_agua(novo)
	elif imediato:
		nivel_agua = novo
		prof = PROF_AGUA[novo]
	_preparar_ameacas(i)
	_voz_t = minf(_voz_t, 3.0)
	_tel_t = 1.0
	sala_entrada.emit(i)


func _fechar_porta(i: int, imediato := false) -> void:
	if not salas.has(i):
		return
	var c = salas[i]
	if c.porta == null or not c.porta_aberta:
		return
	c.porta_aberta = false
	var y_fechada: float = c.piso_y
	if imediato:
		c.porta.position.y = y_fechada
		c.porta_corpo.disabled = false
		return
	Audio.sfx("porta", -4.0)
	var tw := create_tween()
	tw.tween_property(c.porta, "position:y", y_fechada, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.tween_callback(func():
		if is_instance_valid(c.porta_corpo):
			c.porta_corpo.disabled = false)


func _abrir_porta(i: int) -> void:
	if not salas.has(i):
		return
	var c = salas[i]
	if c.porta == null or c.porta_aberta:
		return
	c.porta_aberta = true
	c.porta_corpo.disabled = true
	Audio.sfx("porta", -2.0)
	create_tween().tween_property(c.porta, "position:y", c.piso_y + SalasGd.PORTA_VC + 0.3, 1.1).set_trans(Tween.TRANS_QUAD)


# ============================================================================ água que sobe
func _subir_agua(novo: int) -> void:
	nivel_agua = novo
	Audio.sfx("agua_sobe")
	Efeitos.pulso(0.2, 0.6)
	if _tween_agua and _tween_agua.is_valid():
		_tween_agua.kill()
	_tween_agua = create_tween()
	_tween_agua.tween_property(self, "prof", PROF_AGUA[novo], TEMPO_SUBIR).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween_agua.tween_callback(func(): agua_subiu.emit(novo))


## Quanto o jogador está dentro d'água (m, acima dos pés), 0 se não está numa sala alagada.
func profundidade_no_jogador(pos: Vector3) -> float:
	for i in salas:
		var c = salas[i]
		if not c.agua:
			continue
		var l: Vector3 = c.raiz.to_local(pos)
		if l.z > 0.0 or l.z < -c.L or absf(l.x) > c.w * 0.5:
			continue
		var topo: float = c.raiz.global_position.y + _agua_y_local(c)
		var visivel: bool = prof > 0.02 or c.tipo == "alagado" or c.base_agua <= -1.0
		if not visivel:
			return 0.0
		return maxf(0.0, topo - pos.y)
	return 0.0


## O jogador anda mais devagar conforme a água: depois que ele andou (prioridade 100), encolhemos o deslocamento.
func _lentidao_da_agua(pos: Vector3, dt: float) -> void:
	var f := 1.0
	var d := profundidade_no_jogador(pos)
	if GameState.epoca == GameState.Epoca.ESEMDATA:
		d = 0.0                      # no slide do último dia a água ainda não subiu (ou é só uma imagem)
	if d > 0.0:
		f = clampf(1.0 - d * 0.6, 0.42, 1.0)
	_fator_agua = f
	if _tem_ultima and f < 0.999:
		var delta := pos - _ultima_pos
		if Vector2(delta.x, delta.z).length() < 1.0:      # maior que isso é teletransporte, não passo
			pos.x = _ultima_pos.x + delta.x * f
			pos.z = _ultima_pos.z + delta.z * f
			player.global_position = pos
	_ultima_pos = player.global_position
	_tem_ultima = true
	if d > 0.1 and Vector2(player.velocity.x, player.velocity.z).length() > 0.5:
		_passo_agua_t -= dt
		if _passo_agua_t <= 0.0:
			_passo_agua_t = 0.55
			Audio.sfx("splash", -17.0 + d * 4.0, randf_range(0.85, 1.1))


func fator_agua() -> float:
	return _fator_agua


# ============================================================================ a voz do Tito
func _chamar_voz() -> void:
	if idx_atual < 0 or not salas.has(idx_atual):
		return
	var c = salas[idx_atual]
	if c.voz.is_empty():
		return
	var pos: Vector3 = c.raiz.to_global(c.voz["pos"])
	Audio.sfx_3d("crianca_ei", pos, 2.0)
	_mostrar_legenda("ei… aqui…")


func _hud_proprio() -> void:
	var cam := CanvasLayer.new()
	cam.layer = 14
	cam.name = "HudPorao"
	add_child(cam)
	_cortina = ColorRect.new()
	_cortina.color = Color(0, 0, 0, 0)
	_cortina.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_cortina.set_anchors_preset(Control.PRESET_FULL_RECT)
	cam.add_child(_cortina)
	_legenda = Label.new()
	_legenda.add_theme_font_size_override("font_size", 30)
	_legenda.add_theme_color_override("font_color", Color(0.85, 0.92, 0.95))
	_legenda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_legenda.add_theme_constant_override("outline_size", 6)
	_legenda.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_legenda.anchor_left = 0.0
	_legenda.anchor_right = 1.0
	_legenda.offset_left = 0.0
	_legenda.offset_right = 0.0
	_legenda.offset_top = -170.0
	_legenda.offset_bottom = -120.0
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.modulate.a = 0.0
	cam.add_child(_legenda)


func _mostrar_legenda(texto: String, dur := 2.4) -> void:
	_legenda.text = texto
	if _tween_legenda and _tween_legenda.is_valid():
		_tween_legenda.kill()
	_tween_legenda = create_tween()
	_tween_legenda.tween_property(_legenda, "modulate:a", 1.0, 0.25)
	_tween_legenda.tween_interval(dur)
	_tween_legenda.tween_property(_legenda, "modulate:a", 0.0, 0.8)


# ============================================================================ pistas (o Visor)
func _registrar_pista(id: String) -> void:
	if GameState.flag("pista_" + id):
		return
	GameState.set_flag("pista_" + id, true)
	GameState.somar("pistas_tito")


## Vale como "viu a pista": a época do Visor mostra o nó, ele está perto e na frente da câmera.
func _checar_pistas() -> void:
	var cam := player.camera if is_instance_valid(player) else null
	if cam == null:
		return
	for i in salas:
		for p in salas[i].pistas:
			var no := p["no"] as Node3D
			if not is_instance_valid(no) or not no.is_visible_in_tree():
				continue
			if GameState.epoca not in p["epocas"]:
				continue
			var alvo := no.global_position
			var dir := alvo - cam.global_position
			if dir.length() > 8.0:
				continue
			var frente := -cam.global_transform.basis.z
			if frente.angle_to(dir.normalized()) < 0.55:
				_registrar_pista(p["id"])


# ============================================================================ interativos
func _atender_telefone(_p: Node, c) -> void:
	if GameState.flag("ui_aberta"):
		return
	GameState.set_flag("telefone_porao_atendido", true)
	var linhas := ["Alô? ... é do Castelinho?", "Ele disse que ia só até o lago... o balde vermelho dele...", "Vocês viram o Tito?"]
	var tel = load("res://ui/telefone.gd") if ResourceLoader.exists("res://ui/telefone.gd") else null
	if tel:
		var t = tel.tocar(linhas, false)
		await t.terminou
	else:
		await Guia.falar("???", linhas, true)
	_registrar_pista("telefone")


func _pegar_disco(_p: Node, c) -> void:
	if _tem_disco():
		return
	disco_pego_aqui = true
	GameState.ganhar_disco(GameState.Epoca.ESEMDATA)
	GameState.set_flag("tem_disco_semdata", true)
	GameState.set_flag("tem_visor", true)
	_registrar_pista("quarto_tito")
	Audio.sfx("slide")
	Efeitos.flash(0.5, Color(1.0, 0.95, 0.85), 0.8)
	var disco := c.raiz.get_node_or_null("Disco")
	if disco:
		disco.visible = false
	for it in c.interativos:
		if is_instance_valid(it) and it.name == "InteragivelDisco":
			it.queue_free()
	_mostrar_legenda("Um disco sem data. Segure Q.", 4.0)
	# a grade da sala 96 sobe
	if salas.has(15):
		_abrir_porta(15)
	disco_pego.emit()


func _pegar_sandalia(_p: Node, c) -> void:
	_registrar_pista("sandalia_porao")
	_mostrar_legenda("(uma sandália pequena, azul)", 3.0)
	Audio.sfx("clique")
	for it in c.interativos:
		if is_instance_valid(it) and it.texto_interacao == "Pegar a sandália":
			it.queue_free()
	var s := c.raiz.get_node_or_null("SandaliaPorao")
	if s:
		s.visible = false


func _tem_disco() -> bool:
	return GameState.Epoca.ESEMDATA in GameState.discos


# ============================================================================ Figura Branca e Costela
func _criar_figura() -> void:
	figura = FiguraBranca.new()
	figura.name = "FiguraBranca"
	figura.ativa = false
	figura.velocidade = 2.1
	figura.alvo = player
	figura.reaparecer_fn = _reaparecer_figura
	add_child(figura)
	figura.esconder()


func _criar_costela() -> void:
	costela = CostelaGd.new()
	costela.alvo = player
	add_child(costela)


func _preparar_ameacas(i: int) -> void:
	figura.esconder()
	if costela:
		costela.ativa = false
	var d: Dictionary = plano[i]
	var c = salas[i]
	if d["costela"] and costela:
		costela.ativa = true
	if d["figura"]:
		var p: Vector3 = c.raiz.to_global(c.pontos["figura"])
		figura.reiniciar(p, true)
		figura.velocidade = 2.0


## Onde a Figura reaparece depois de cercada: atrás do jogador (do lado da entrada), a ~9 m.
func _reaparecer_figura(_f: Node) -> Vector3:
	if idx_atual < 0 or not salas.has(idx_atual):
		return player.global_position + Vector3(0, 0, 9)
	var c = salas[idx_atual]
	var l: Vector3 = c.raiz.to_local(player.global_position)
	var z := clampf(l.z + 9.0, -c.L + 1.0, -1.6)
	if absf(z - l.z) < 5.0:
		z = clampf(l.z - 9.0, -c.L + 1.0, -1.6)
	var x := clampf(-l.x * 0.5, -c.w * 0.25, c.w * 0.25)
	return c.raiz.to_global(Vector3(x, c.piso_fn.call(z) + 0.05, z))


## O Visor estourou a atenção (visita 5): a Figura atravessa de verdade e persegue.
func _on_figura_atravessou(_visita: int) -> void:
	if idx_atual < 0 or not salas.has(idx_atual) or not is_instance_valid(player):
		return
	var c = salas[idx_atual]
	if c.tipo == "quarto_tito" and false:
		return
	var l: Vector3 = c.raiz.to_local(player.global_position)
	var z := clampf(l.z + 7.0, -c.L + 0.8, -1.4)
	if absf(z - l.z) < 4.5:
		z = clampf(l.z - 7.0, -c.L + 0.8, -1.4)
	var p := c.raiz.to_global(Vector3(clampf(l.x, -c.w * 0.3, c.w * 0.3), c.piso_fn.call(z) + 0.05, z))
	figura.reiniciar(p, true)
	figura.velocidade = 2.4
	Audio.sfx("susto", -6.0)


# ============================================================================ afogamento, morte e checkpoint
## A bifurcação errada: a água funda. Sem gráfico: a tela escurece, a câmera afunda e a morte segue o caminho normal.
func _afogar() -> void:
	if afogando or morrendo:
		return
	afogando = true
	player.pode_mover = false
	Audio.sfx("agua_puxa")
	var tw := create_tween().set_parallel()
	tw.tween_property(player.cabeca, "position:y", 0.25, 1.5).set_trans(Tween.TRANS_SINE)
	tw.tween_property(player.cabeca, "rotation:x", deg_to_rad(40.0), 1.5)
	tw.tween_property(_cortina, "color:a", 1.0, 1.6)
	await get_tree().create_timer(1.8, false).timeout
	if afogando:
		GameState.matar_jogador("afogamento")


func ao_morrer() -> void:
	if morrendo:
		return
	morrendo = true
	if player:
		player.pode_mover = false
	await Transicao.fade_out(0.25, Color(0.05, 0.0, 0.0))
	var m := Morte.mostrar(_causa if _causa != "" else "porao")
	await m.terminou
	_reiniciar_no_checkpoint()
	await Transicao.fade_in(0.9)
	morrendo = false


func _reiniciar_no_checkpoint() -> void:
	var sala := ultimo_checkpoint
	var i := clampi(sala - PRIMEIRA, 0, N - 1)
	_descarregar_todas()
	_carregar_sala(i)
	_carregar_sala(i + 1)
	idx_atual = -1
	figura.esconder()
	costela.ativa = false
	afogando = false
	_cortina.color.a = 0.0
	player.cabeca.position.y = Player.ALTURA_OLHOS
	player.cabeca.rotation.x = 0.0
	player.velocity = Vector3.ZERO
	var c = salas[i]
	player.global_position = c.raiz.to_global(Vector3(0, 0.05, -1.3))
	player.rotation = Vector3(0, c.raiz.global_rotation.y, 0)
	_tem_ultima = false
	nivel_agua = nivel_da_sala(sala)
	prof = PROF_AGUA[nivel_agua]
	GameState.definir_atencao(0.0)
	GameState.trocar_epoca(GameState.Epoca.E2020)
	_ao_entrar_sala(i, true)
	player.pode_mover = true
	Visor.resetar_estado()


## Teletransporta o jogador ao começo da sala de índice `i` (usado por testes e por "continuar").
func ir_para_sala(i: int) -> void:
	_descarregar_todas()
	_carregar_sala(i)
	_carregar_sala(i + 1)
	idx_atual = -1
	var c = salas[i]
	player.global_position = c.raiz.to_global(Vector3(0, 0.05, -1.4))
	player.velocity = Vector3.ZERO
	_tem_ultima = false
	_ao_entrar_sala(i, true)


# ============================================================================ época e saída
func _ao_mudar_epoca(e: int) -> void:
	var sem_data: bool = e == GameState.Epoca.ESEMDATA
	if _tween_env and _tween_env.is_valid():
		_tween_env.kill()
	_tween_env = create_tween().set_parallel()
	if sem_data:
		# o último dia: fim de tarde dourado, água parada como um espelho
		_tween_env.tween_property(env, "ambient_light_color", Color(0.75, 0.50, 0.34), 0.5)
		_tween_env.tween_property(env, "ambient_light_energy", 0.95, 0.5)
		_tween_env.tween_property(env, "fog_light_color", Color(0.42, 0.24, 0.16), 0.5)
		_tween_env.tween_property(env, "background_color", Color(0.42, 0.24, 0.16), 0.5)
		_tween_env.tween_property(env, "fog_depth_end", 34.0, 0.5)
		_tween_env.tween_property(mat_agua, "shader_parameter/ondas", 0.0, 0.5)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_ceu", Color(0.85, 0.5, 0.25), 0.5)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_fundo", Color(0.18, 0.09, 0.06), 0.5)
	else:
		_tween_env.tween_property(env, "ambient_light_color", Color(0.34, 0.40, 0.40), 0.4)
		_tween_env.tween_property(env, "ambient_light_energy", 0.55, 0.4)
		_tween_env.tween_property(env, "fog_light_color", Color(0.018, 0.026, 0.026), 0.4)
		_tween_env.tween_property(env, "background_color", Color(0.016, 0.022, 0.022), 0.4)
		_tween_env.tween_property(env, "fog_depth_end", 26.0, 0.4)
		_tween_env.tween_property(mat_agua, "shader_parameter/ondas", 1.0, 0.4)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_ceu", Color(0.16, 0.24, 0.24), 0.4)
		_tween_env.tween_property(mat_agua, "shader_parameter/cor_fundo", Color(0.012, 0.045, 0.05), 0.4)
	_epoca_ant = e


func _ir_ao_braco_morto() -> void:
	if morrendo or afogando:
		return
	saiu_do_porao.emit()
	GameState.entrar_sala(100)
	var cena := "res://world/niveis/braco_morto.tscn"
	if not ResourceLoader.exists(cena):
		push_warning("Porão: '%s' ainda não existe; usando o nível de teste." % cena)
		cena = "res://world/niveis/teste.tscn"
	await Transicao.ir_para(cena, "Spawn", 1.4)


func _exit_tree() -> void:
	if is_instance_valid(Audio):
		Audio.ambiente("", -8.0, 0.5)
