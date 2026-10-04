class_name FiguraBranca
extends CharacterBody3D
## A Figura Branca (PLANO §6): inspirada na lenda "A Aparição" do Passo da Mãe Rosa.
## Silhueta feminina alta, branca, sem rosto, com véu. Feita só de malhas simples.
##
## REGRA (uma só, legível):
##   - Avança em direção ao jogador SÓ quando NÃO está sendo olhada.
##     "Olhada" = dentro do cone de visão do jogador (< `angulo_visao`) com linha de visão livre.
##   - Se o jogador se aproxima olhando (distância < `distancia_cercar` enquanto olha), ela SOME
##     e reaparece mais longe (num de `pontos_reaparecer`, ou em `reaparecer_fn`, ou mais longe
##     na mesma direção).
##   - Encostou (distância < `distancia_toque`) sem ser olhada: GameState.matar_jogador("figura_branca").
##
## Uso:
##     var f := FiguraBranca.new()
##     f.velocidade = 2.4
##     f.pontos_reaparecer = [Vector3(30, 5, -60)]
##     nivel.add_child(f); f.global_position = ponto
##     f.ativa = false         # parada: só some quando cercada (sala 27)
##     f.ativar()              # passa a avançar
## Camada de colisão 4 (valor 8); colide só com o mundo (o jogador a atravessa: o toque é por distância).

signal sumiu(onde: Vector3)
signal reapareceu(onde: Vector3)
signal matou_jogador

@export var velocidade := 2.2
@export var ativa := true                    # false = parada (só some quando cercada)
@export var angulo_visao := 35.0             # graus: meio-cone de visão do jogador
@export var distancia_cercar := 2.5          # m: olhando e mais perto que isso -> ela some
@export var distancia_toque := 0.9           # m: sem ser olhada e mais perto -> mata
@export var tempo_reaparecer := 1.2          # s sumida antes de reaparecer
@export var distancia_reaparecer := 14.0     # m (reaparecimento padrão: mais longe na mesma direção)
@export var usar_navegacao := false          # usa NavigationAgent3D se o nível tiver navmesh
@export var som_ativo := true

var pontos_reaparecer: Array = []             # de Vector3
var pontos_caminho: Array = []                # de Vector3: pontos de passagem (portas) para contornar paredes
var reaparecer_fn := Callable()              # func(figura) -> Vector3 (tem prioridade)
var alvo: Node3D                             # o jogador (achado pelo grupo "player")
var escuro := false:                         # apagão: o jogador não a vê (conta como não olhada)
	set(v):
		escuro = v
		if _modelo:
			_modelo.visible = not v
var olhada := false                          # resultado da última checagem (para testes e debug)
var sumida := false
var matou := false

var _modelo: Node3D
var _veu: Node3D
var _braco_e: Node3D
var _braco_d: Node3D
var _colisao: CollisionShape3D
var _agente: NavigationAgent3D
var _t := 0.0
var _movendo := false
var _prox_som := 0.0
var _pos_antes := Vector3.ZERO
var _idx_ponto := -1


func _ready() -> void:
	collision_layer = 8
	collision_mask = 1
	floor_snap_length = 0.4
	add_to_group("figura_branca")
	_colisao = CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 2.0
	_colisao.shape = cap
	_colisao.position.y = 1.0
	add_child(_colisao)
	_construir_visual()
	if usar_navegacao:
		_agente = NavigationAgent3D.new()
		_agente.path_desired_distance = 0.6
		_agente.target_desired_distance = 0.6
		add_child(_agente)
	_t = randf() * 6.0


# ---------------------------------------------------------------- visual
func _material(alfa: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.96, 0.97, 1.0, alfa)
	m.emission_enabled = true
	m.emission = Color(0.55, 0.6, 0.7)
	m.emission_energy_multiplier = 0.3
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	if alfa < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m


func _peca(pai: Node3D, malha: Mesh, pos: Vector3, mat: Material, rot := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	mi.scale = escala
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


func _construir_visual() -> void:
	_modelo = Node3D.new()
	_modelo.name = "Modelo"
	_modelo.scale = Vector3(1.0, 1.12, 1.0)   # alta: ~2,5 m
	add_child(_modelo)
	var corpo := _material(0.92)
	var tecido := _material(0.45)

	# vestido longo (saia) e tronco estreito
	var saia := CylinderMesh.new()
	saia.top_radius = 0.16
	saia.bottom_radius = 0.44
	saia.height = 1.4
	saia.radial_segments = 12
	saia.rings = 1
	_peca(_modelo, saia, Vector3(0, 0.7, 0), corpo)
	var tronco := CapsuleMesh.new()
	tronco.radius = 0.15
	tronco.height = 0.78
	tronco.radial_segments = 10
	tronco.rings = 3
	_peca(_modelo, tronco, Vector3(0, 1.68, 0), corpo)

	# cabeça comprida, inclinada, sem rosto
	var cab := SphereMesh.new()
	cab.radius = 0.11
	cab.height = 0.22
	cab.radial_segments = 10
	cab.rings = 6
	_peca(_modelo, cab, Vector3(0.03, 2.16, 0), corpo, Vector3(0, 0, deg_to_rad(-12)), Vector3(0.85, 1.25, 0.9))

	# braços compridos demais, pendurados
	var braco := CapsuleMesh.new()
	braco.radius = 0.04
	braco.height = 1.25
	braco.radial_segments = 6
	braco.rings = 2
	_braco_e = Node3D.new()
	_braco_e.position = Vector3(-0.2, 1.9, 0)
	_modelo.add_child(_braco_e)
	_peca(_braco_e, braco, Vector3(-0.06, -0.55, 0), corpo, Vector3(0, 0, deg_to_rad(6)))
	_braco_d = Node3D.new()
	_braco_d.position = Vector3(0.2, 1.9, 0)
	_modelo.add_child(_braco_d)
	_peca(_braco_d, braco, Vector3(0.06, -0.55, 0), corpo, Vector3(0, 0, deg_to_rad(-6)))

	# véu: cone aberto, translúcido, da cabeça até quase o chão
	_veu = Node3D.new()
	_veu.position = Vector3(0, 0, 0)
	_modelo.add_child(_veu)
	var veu := CylinderMesh.new()
	veu.top_radius = 0.18
	veu.bottom_radius = 0.66
	veu.height = 2.3
	veu.radial_segments = 14
	veu.rings = 1
	veu.cap_top = false
	veu.cap_bottom = false
	_peca(_veu, veu, Vector3(0, 1.15, 0.02), tecido)


func _process(dt: float) -> void:
	if _modelo == null:
		return
	_t += dt
	_modelo.position.y = 0.05 + 0.04 * sin(_t * 1.6)       # flutua um pouco
	_veu.rotation.z = sin(_t * 1.3) * 0.05
	_veu.scale = Vector3(1.0 + 0.05 * sin(_t * 2.1), 1.0, 1.0 + 0.05 * cos(_t * 1.7))
	_braco_e.rotation.x = sin(_t * 1.1) * 0.09
	_braco_d.rotation.x = sin(_t * 1.1 + 1.7) * 0.09
	var incl := deg_to_rad(-9.0) if _movendo else 0.0
	_modelo.rotation.x = lerpf(_modelo.rotation.x, incl, 1.0 - exp(-dt * 5.0))


# ---------------------------------------------------------------- API
func ativar() -> void:
	ativa = true


func desativar() -> void:
	ativa = false


## Põe a figura num ponto (visível e ativa fisicamente), sem efeitos.
func teleportar(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	sumida = false
	visible = true
	if _colisao:
		_colisao.set_deferred("disabled", false)


## Volta ao estado inicial depois de uma morte.
func reiniciar(pos: Vector3, nova_ativa := false) -> void:
	matou = false
	escuro = false
	ativa = nova_ativa
	teleportar(pos)


## Some de vez (fim da sala 30, por exemplo).
func esconder() -> void:
	ativa = false
	sumida = true
	visible = false
	if _colisao:
		_colisao.set_deferred("disabled", true)


## O jogador está vendo a figura agora? (cone de visão + linha de visão livre)
func esta_sendo_olhada() -> bool:
	if escuro or sumida or alvo == null:
		return false
	var cam := _camera()
	if cam == null:
		return false
	var origem := cam.global_position
	var frente := -cam.global_transform.basis.z
	for h: float in [1.4, 2.3, 0.5]:   # peito, cabeça, barra do vestido
		var ponto := global_position + Vector3.UP * h
		var dir := ponto - origem
		var dist := dir.length()
		if dist < 0.05:
			return true
		if rad_to_deg(frente.angle_to(dir / dist)) < angulo_visao and _linha_livre(origem, ponto):
			return true
	return false


# ---------------------------------------------------------------- física
func _physics_process(dt: float) -> void:
	if not is_on_floor():
		velocity.y -= 18.0 * dt
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("player") as Node3D
	_movendo = false
	if sumida or matou or alvo == null:
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var pa := alvo.global_position
	var para := pa - global_position
	para.y = 0.0
	var dist := para.length()
	if dist > 0.01:
		_virar(para, dt)

	olhada = esta_sendo_olhada()
	velocity.x = 0.0
	velocity.z = 0.0
	if olhada:
		if dist < distancia_cercar:
			_sumir()
			return
	elif ativa:
		if dist < distancia_toque and absf(pa.y - global_position.y) < 1.8:
			_matar()
			return
		var dir := _direcao_para(pa)
		velocity.x = dir.x * velocidade
		velocity.z = dir.z * velocidade
		_movendo = true
		_prox_som -= dt
		if _prox_som <= 0.0:
			_prox_som = 1.6
			if som_ativo:
				Audio.sfx_3d("sussurro", global_position)
	move_and_slide()


func _virar(para: Vector3, dt: float) -> void:
	var yaw := atan2(-para.x, -para.z)
	rotation.y = lerp_angle(rotation.y, yaw, 1.0 - exp(-dt * 8.0))


## Direção horizontal (unitária) para chegar em `destino`: reto, por pontos de passagem
## (portas), por NavigationAgent3D (se houver navmesh) e desviando de paredes à frente.
func _direcao_para(destino: Vector3) -> Vector3:
	var peito := global_position + Vector3.UP * 1.0
	var alvo_mov := destino
	var usou_nav := false
	if usar_navegacao and _agente != null:
		var mapa := _agente.get_navigation_map()
		if NavigationServer3D.map_get_iteration_id(mapa) > 0 and not NavigationServer3D.map_get_regions(mapa).is_empty():
			_agente.target_position = destino
			alvo_mov = _agente.get_next_path_position()
			usou_nav = true
	if not usou_nav and not _linha_livre(peito, destino + Vector3.UP * 1.0):
		var melhor := INF
		for p: Vector3 in pontos_caminho:
			if p.distance_to(global_position) < 0.7:
				continue
			if not _linha_livre(peito, p + Vector3.UP * 1.0):
				continue
			var d := p.distance_to(destino)
			if d < melhor:
				melhor = d
				alvo_mov = p
	var dir := alvo_mov - global_position
	dir.y = 0.0
	if dir.length() < 0.01:
		return Vector3.ZERO
	return _desviar(dir.normalized())


func _desviar(dir: Vector3) -> Vector3:
	if not _bloqueado(dir):
		return dir
	for ang in [35.0, -35.0, 70.0, -70.0, 105.0, -105.0]:
		var d2 := dir.rotated(Vector3.UP, deg_to_rad(ang))
		if not _bloqueado(d2):
			return d2
	return dir


func _bloqueado(dir: Vector3) -> bool:
	var de := global_position + Vector3.UP * 0.7
	return not _linha_livre(de, de + dir * 0.9)


func _linha_livre(de: Vector3, para: Vector3) -> bool:
	var q := PhysicsRayQueryParameters3D.create(de, para, 1)
	q.collide_with_areas = false
	return get_world_3d().direct_space_state.intersect_ray(q).is_empty()


func _camera() -> Camera3D:
	var c = alvo.get("camera") if alvo else null
	if c is Camera3D:
		return c
	return get_viewport().get_camera_3d()


# ---------------------------------------------------------------- sumir / reaparecer / matar
func _sumir() -> void:
	_pos_antes = global_position
	sumida = true
	visible = false
	_colisao.set_deferred("disabled", true)
	velocity = Vector3.ZERO
	sumiu.emit(_pos_antes)
	Efeitos.pulso(0.35, 0.25)
	if som_ativo:
		Audio.sfx_3d("chiado_radio", _pos_antes)
	get_tree().create_timer(tempo_reaparecer).timeout.connect(_reaparecer)


func _reaparecer() -> void:
	if not sumida or matou or not is_inside_tree():
		return
	var p := _ponto_reaparecer()
	teleportar(p)
	reapareceu.emit(p)


func _ponto_reaparecer() -> Vector3:
	if reaparecer_fn.is_valid():
		return reaparecer_fn.call(self)
	var pa := alvo.global_position if alvo else global_position
	if not pontos_reaparecer.is_empty():
		for i in pontos_reaparecer.size():
			_idx_ponto = (_idx_ponto + 1) % pontos_reaparecer.size()
			var cand: Vector3 = pontos_reaparecer[_idx_ponto]
			if cand.distance_to(pa) >= 6.0:
				return cand
		return pontos_reaparecer[_idx_ponto]
	# padrão: mais longe, na mesma direção em que ela estava em relação ao jogador
	var dir := _pos_antes - pa
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3.FORWARD
	var destino := pa + dir * distancia_reaparecer
	var q := PhysicsRayQueryParameters3D.create(pa + Vector3.UP * 0.8, destino + Vector3.UP * 0.8, 1)
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if not h.is_empty():
		destino = h.position - dir * 0.7
	destino.y = _pos_antes.y + 0.1
	return destino


func _matar() -> void:
	matou = true
	velocity = Vector3.ZERO
	matou_jogador.emit()
	if alvo and "pode_mover" in alvo:
		alvo.pode_mover = false
	if alvo and alvo.has_method("olhar_para"):
		alvo.olhar_para(global_position + Vector3.UP * 2.0, 0.15)
	Efeitos.pulso(1.0, 0.6)
	Audio.sfx("susto")
	GameState.matar_jogador("figura_branca")
