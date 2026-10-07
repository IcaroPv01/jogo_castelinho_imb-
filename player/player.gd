class_name Player
extends CharacterBody3D
## Jogador em primeira pessoa: andar, correr com stamina (estilo Spooky's), olhar, interagir, lanterna.
##
## Contrato de interação: qualquer nó atingido pelo raio (ou um ancestral dele) que tenha
## `func interagir(player)` é interagível. Texto do aviso: propriedade `texto_interacao` (String).

signal alvo_mudou(texto: String)   # "" quando não há alvo
signal stamina_mudou(valor: float)

const VEL_ANDAR := 3.0
const VEL_CORRER := 5.4
const GRAVIDADE := 18.0
const ALTURA_OLHOS := 1.55
const SENS_MOUSE := 0.0022
const ALCANCE := 2.4
const DRENO := 0.28      # stamina por segundo correndo
const RECARGA := 0.22    # stamina por segundo parado/andando
const LIMIAR_CANSADO := 0.35

var pode_mover := true
var stamina := 1.0
var cansado := false
var cabeca: Node3D
var camera: Camera3D
var raio: RayCast3D
var lanterna: SpotLight3D
var _alvo: Node = null
var _dist_passo := 0.0
var _bob := 0.0
var _checar_preso := 0           # quadros de física restantes para conferir se a época prendeu o jogador
var _ultimo_seguro := Vector3.ZERO
var _tem_seguro := false


func _ready() -> void:
	add_to_group("player")
	collision_layer = 2
	collision_mask = 1
	var forma := CollisionShape3D.new()
	var capsula := CapsuleShape3D.new()
	capsula.radius = 0.3
	capsula.height = 1.75
	forma.shape = capsula
	forma.position.y = 0.875
	add_child(forma)

	cabeca = Node3D.new()
	cabeca.position.y = ALTURA_OLHOS
	add_child(cabeca)
	camera = Camera3D.new()
	camera.fov = 72.0
	camera.near = 0.05
	camera.far = 200.0
	camera.current = true
	cabeca.add_child(camera)

	raio = RayCast3D.new()
	raio.target_position = Vector3(0, 0, -ALCANCE)
	raio.collide_with_areas = true
	raio.collision_mask = 1 | 4   # mundo + interagíveis (camada 3)
	raio.add_exception(self)
	camera.add_child(raio)

	# Lanterna (revisão V2): cone mais aberto com borda suave e queda MAIS SUAVE com a distância (não estoura a parede a
	# 1 m e ainda faz poça a 8 m). O estado sobrevive à troca de cena: o Player é recriado a cada nível, e antes a
	# lanterna voltava apagada no porão e no Braço Morto. A flag "lanterna_desligada" guarda a escolha do jogador.
	lanterna = SpotLight3D.new()
	lanterna.spot_range = 18.0
	lanterna.spot_angle = 34.0
	lanterna.spot_angle_attenuation = 0.8
	lanterna.spot_attenuation = 0.5
	lanterna.light_energy = 3.0
	lanterna.light_color = Color(1.0, 0.92, 0.76)
	lanterna.shadow_enabled = false
	lanterna.visible = GameState.flag("tem_lanterna") and not GameState.flag("lanterna_desligada")
	lanterna.position = Vector3(0.15, -0.15, 0)
	lanterna.rotation_degrees.x = -10.0    # um pouco para baixo: o facho cai no chão à frente e mostra o caminho
	camera.add_child(lanterna)
	# Trocar de época liga e desliga colisões (paredes que somem e voltam): se uma parede reaparecer em cima do
	# jogador, `desprender()` o tira de dentro dela (senão ele ficava preso para sempre, ex.: soltar Q em 1950).
	GameState.epoca_mudou.connect(_ao_mudar_epoca)


func _unhandled_input(e: InputEvent) -> void:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		return
	if e is InputEventMouseMotion and pode_mover:
		var s := SENS_MOUSE * GameState.sensibilidade
		rotate_y(-e.relative.x * s)
		cabeca.rotate_x(-e.relative.y * s)
		cabeca.rotation.x = clampf(cabeca.rotation.x, deg_to_rad(-85), deg_to_rad(85))
	elif e.is_action_pressed("interagir") and pode_mover and _alvo and is_instance_valid(_alvo):
		_alvo.interagir(self)
		get_viewport().set_input_as_handled()
	elif e.is_action_pressed("lanterna") and GameState.flag("tem_lanterna"):
		lanterna.visible = not lanterna.visible
		GameState.set_flag("lanterna_desligada", not lanterna.visible)
		Audio.sfx("clique")


func _physics_process(dt: float) -> void:
	if _checar_preso > 0:
		_checar_preso -= 1
		if _checar_preso == 0 or _sobrepoe_mundo(global_position):
			desprender()
	if not is_on_floor():
		velocity.y -= GRAVIDADE * dt
	var dir := Vector3.ZERO
	var correndo := false
	if pode_mover:
		var v := Input.get_vector("esquerda", "direita", "frente", "tras")
		dir = (transform.basis * Vector3(v.x, 0, v.y)).normalized()
		correndo = Input.is_action_pressed("correr") and not cansado and v.length() > 0.1
	_atualizar_stamina(correndo, dt)
	var vel := VEL_CORRER if correndo else VEL_ANDAR
	velocity.x = dir.x * vel
	velocity.z = dir.z * vel
	move_and_slide()
	if _checar_preso == 0 and is_on_floor():
		_ultimo_seguro = global_position
		_tem_seguro = true
	_balanco(dt, dir.length() > 0.1 and is_on_floor(), vel)
	_atualizar_alvo()


func _atualizar_stamina(correndo: bool, dt: float) -> void:
	var antes := stamina
	if correndo:
		stamina = maxf(0.0, stamina - DRENO * dt)
		if stamina <= 0.0:
			cansado = true
			Audio.sfx("ofego")
	else:
		stamina = minf(1.0, stamina + RECARGA * dt)
		if cansado and stamina >= LIMIAR_CANSADO:
			cansado = false
	if not is_equal_approx(antes, stamina):
		stamina_mudou.emit(stamina)


func _balanco(dt: float, andando: bool, vel: float) -> void:
	if andando:
		_bob += dt * vel * 2.2
		_dist_passo += dt * vel
		if _dist_passo > 1.6:
			_dist_passo = 0.0
			Audio.passo()
	else:
		_bob = lerpf(_bob, 0.0, dt * 6.0)
	camera.position.y = sin(_bob) * 0.035
	camera.position.x = cos(_bob * 0.5) * 0.02


func _atualizar_alvo() -> void:
	var novo: Node = null
	if raio.is_colliding():
		var n: Node = raio.get_collider()
		while n and not n.has_method("interagir"):
			n = n.get_parent()
		novo = n
	if novo != _alvo:
		_alvo = novo
		var txt := ""
		if _alvo:
			var t = _alvo.get("texto_interacao")
			txt = t if t is String and t != "" else "Interagir"
		alvo_mudou.emit(txt)


## Usado por cutscenes/sustos: vira a câmera para um ponto.
func olhar_para(ponto: Vector3, dur := 0.4) -> void:
	var alvo_yaw := atan2(-(ponto.x - global_position.x), -(ponto.z - global_position.z))
	var t := create_tween().set_parallel()
	t.tween_property(self, "rotation:y", alvo_yaw, dur)
	t.tween_property(cabeca, "rotation:x", 0.0, dur)
	await t.finished


func direcao_olhar() -> Vector3:
	return -camera.global_transform.basis.z


# ---------------------------------------------------------------- jogador preso dentro de uma parede
func _ao_mudar_epoca(_e: int) -> void:
	_checar_preso = 4    # a colisão das épocas muda no quadro seguinte: confere alguns quadros depois


## Há colisão do mundo (camada 1) dentro da cápsula em `pos` (pé do jogador)? A cápsula é um pouco menor do que a
## real: encostar na parede não conta, só estar enfiado nela.
func _sobrepoe_mundo(pos: Vector3, folga := 0.04) -> bool:
	if not is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.3 - folga
	forma.height = 1.75 - 2.0 * folga
	q.shape = forma
	q.transform = Transform3D(Basis(), pos + Vector3(0, 0.875 + 0.02, 0))
	q.collision_mask = 1
	q.exclude = [get_rid()]
	return not get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


## Se a cápsula está enfiada em colisão do mundo, leva o jogador para o ponto livre mais próximo (com chão embaixo);
## se não achar nenhum, volta para o último lugar seguro. Devolve true se mudou a posição.
func desprender() -> bool:
	if not _sobrepoe_mundo(global_position):
		return false
	var origem := global_position
	var espaco := get_world_3d().direct_space_state
	for raio: float in [0.15, 0.3, 0.45, 0.6, 0.8, 1.0, 1.25, 1.5, 2.0, 2.5, 3.0]:
		for i in 16:
			var ang := TAU * i / 16.0
			var cand: Vector3 = origem + Vector3(cos(ang), 0, sin(ang)) * raio
			# chão sob o candidato (a até 0,7 m acima ou 1,2 m abaixo do ponto atual)
			var rq := PhysicsRayQueryParameters3D.create(cand + Vector3(0, 0.7, 0), cand + Vector3(0, -1.2, 0), 1)
			rq.exclude = [get_rid()]
			var r := espaco.intersect_ray(rq)
			if r.is_empty():
				continue
			cand.y = (r["position"] as Vector3).y
			if not _sobrepoe_mundo(cand):
				return _teleportar_seguro(cand)
	if _tem_seguro and not _sobrepoe_mundo(_ultimo_seguro):
		return _teleportar_seguro(_ultimo_seguro)
	return false


func _teleportar_seguro(pos: Vector3) -> bool:
	global_position = pos
	velocity = Vector3.ZERO
	return true
