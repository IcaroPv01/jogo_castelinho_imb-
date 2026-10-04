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

	lanterna = SpotLight3D.new()
	lanterna.spot_range = 14.0
	lanterna.spot_angle = 28.0
	lanterna.light_energy = 2.2
	lanterna.light_color = Color(1.0, 0.93, 0.8)
	lanterna.shadow_enabled = false
	lanterna.visible = false
	lanterna.position = Vector3(0.15, -0.15, 0)
	camera.add_child(lanterna)


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
		Audio.sfx("clique")


func _physics_process(dt: float) -> void:
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
