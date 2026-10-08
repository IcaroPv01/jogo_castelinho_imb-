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
## Visual (redesenho "afogada"): ~2,4 m, magra demais, corcunda, braços até abaixo dos joelhos com dedos longos,
## cabeça pequena e torta, rosto = vazio escuro com mechas de cabelo molhado, vestido rasgado sem pés.
## 4 malhas (corpo+vestido, cabeça+cabelo, 2 braços), 1 material (shader sem luz, cor por vértice): 4 draw calls.
## Movimento: poses "estaladas" (sem interpolação), quadros pulados, só mexe quando está andando;
## olhada = congelada. Corre em arrancos (média = `velocidade`).
const SHADER := """shader_type spatial;
render_mode unshaded, cull_disabled;
uniform float brilho = 1.0;
uniform float suelo = 0.0;
varying vec3 vp;
varying float alt;
float h3(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float vn(vec3 p) {
	vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
	return mix(mix(mix(h3(i), h3(i + vec3(1,0,0)), f.x), mix(h3(i + vec3(0,1,0)), h3(i + vec3(1,1,0)), f.x), f.y),
		mix(mix(h3(i + vec3(0,0,1)), h3(i + vec3(1,0,1)), f.x), mix(h3(i + vec3(0,1,1)), h3(i + vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() {
	vp = VERTEX;
	alt = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y - suelo;
}
void fragment() {
	float n = vn(vp * 7.0) * 0.6 + vn(vp * 19.0 + 3.0) * 0.4;
	float suja = smoothstep(0.42, 0.72, n);
	float pingo = smoothstep(0.55, 0.9, vn(vec3(vp.x * 40.0, vp.y * 4.0, vp.z * 40.0)));
	float umido = smoothstep(1.3, 0.1, alt);
	float rim = pow(1.0 - abs(dot(normalize(NORMAL), normalize(VIEW))), 2.0);
	vec3 c = COLOR.rgb;
	c *= 1.0 - 0.5 * suja - 0.25 * pingo;
	c = mix(c, c * vec3(0.55, 0.7, 0.65), umido * 0.8);
	c *= 1.0 - 0.45 * rim;
	if (COLOR.a < 0.5) {   // tronco: costelas e clavícula sugeridas por sombra
		float frente = step(vp.z, 0.0);
		float banda = smoothstep(0.28, 0.36, vp.y) * smoothstep(0.76, 0.66, vp.y);
		float costela = (sin(vp.y * 52.0) * 0.5 + 0.5);
		c *= 1.0 - 0.4 * costela * banda * frente;
		c *= 1.0 - 0.5 * smoothstep(0.014, 0.0, abs(vp.y - 0.76 - 0.05 * abs(vp.x))) * frente;
	}
	ALBEDO = c * brilho;
}
"""
const COR_PELE := Color(0.66, 0.74, 0.69)
const COR_VESTIDO := Color(0.68, 0.73, 0.70)
const COR_BARRA := Color(0.30, 0.35, 0.35)
const COR_CABELO := Color(0.12, 0.14, 0.16)
const COR_VAZIO := Color(0.0, 0.0, 0.0)

var _cabeca: Node3D
var _corpo: Node3D
var _mat: ShaderMaterial
var _nv := 0
var _snap_t := 0.0
var _lurch_t := 0.0
var _arranco := false
var _olhada_ant := false
var _dist := 99.0
var _brilho := 1.0


## Tubo ao longo de `pts` com raio `rad` por ponto, elipse `esc` (largura, profundidade), cor por ponto/direção.
func _tubo(st: SurfaceTool, pts: Array, rad: Array, seg: int, cor: Callable, esc := Vector2.ONE) -> void:
	var base := _nv
	var n := pts.size()
	for i in n:
		var t: Vector3 = (pts[mini(i + 1, n - 1)] - pts[maxi(i - 1, 0)]).normalized()
		var ref := Vector3.FORWARD if absf(t.dot(Vector3.FORWARD)) < 0.9 else Vector3.RIGHT
		var u := t.cross(ref).normalized()
		var v := t.cross(u).normalized()
		for k in seg:
			var ang := TAU * k / seg
			var d := u * cos(ang) * esc.x + v * sin(ang) * esc.y
			st.set_color(cor.call(i, d.normalized()))
			st.add_vertex(pts[i] + d * float(rad[i]))
			_nv += 1
	for i in n - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a := base + i * seg + k
			var b := base + i * seg + k2
			var c := base + (i + 1) * seg + k
			var e := base + (i + 1) * seg + k2
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(e)
	# tampas
	for fim: int in [0, n - 1]:
		st.set_color(cor.call(fim, Vector3.ZERO))
		st.add_vertex(pts[fim])
		_nv += 1
		var cen := _nv - 1
		var anel := base + fim * seg
		for k in seg:
			st.add_index(cen); st.add_index(anel + k); st.add_index(anel + (k + 1) % seg)


func _cor_const(c: Color) -> Callable:
	return func(_i: int, _d: Vector3) -> Color: return c


func _malha(st: SurfaceTool) -> ArrayMesh:
	st.generate_normals()
	return st.commit()


func _no_malha(pai: Node3D, malha: Mesh, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = _mat
	mi.position = pos
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


func _novo_st() -> SurfaceTool:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	_nv = 0
	return st


func _braco(lado: float) -> Node3D:
	var no := Node3D.new()
	no.position = Vector3(0.15 * lado, 0.80, 0.0)   # ombro estreito e caído
	_corpo.add_child(no)
	var st := _novo_st()
	var pele := _cor_const(COR_PELE)
	# ombro -> cotovelo (dobra leve) -> pulso, pendendo um pouco para a frente (-Z)
	var pulso := Vector3(0.05 * lado, -1.0, -0.2)
	_tubo(st, [Vector3(-0.07 * lado, 0.07, 0.01), Vector3(0, 0.0, 0.01), Vector3(0.015 * lado, -0.3, -0.03), Vector3(0.03 * lado, -0.62, -0.14), Vector3(0.04 * lado, -0.85, -0.17), pulso],
		[0.018, 0.04, 0.027, 0.02, 0.017, 0.016], 6, pele)
	# mão: 4 dedos longos, finos e abertos
	for j in 4:
		var abre := (float(j) - 1.5)
		var comp := 0.30 + 0.06 * float(1 - absi(j - 1))
		var dx := abre * 0.045 * lado
		_tubo(st, [pulso, pulso + Vector3(dx * 0.5, -comp * 0.5, -0.02 - 0.02 * abs(abre)), pulso + Vector3(dx * 1.0 + 0.02 * lado, -comp, -0.05 - 0.03 * abs(abre))],
			[0.012, 0.009, 0.004], 4, pele)
	_no_malha(no, _malha(st), Vector3.ZERO)
	return no


func _construir_visual() -> void:
	_mat = ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = SHADER
	_mat.shader = sh
	_modelo = Node3D.new()
	_modelo.name = "Modelo"
	add_child(_modelo)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1337

	# vestido: anéis + língulas rasgadas na barra, sem pés
	var st := _novo_st()
	var aneis := [[1.12, 0.12, COR_VESTIDO], [0.70, 0.2, COR_VESTIDO.lerp(COR_BARRA, 0.25)], [0.34, 0.3, COR_VESTIDO.lerp(COR_BARRA, 0.65)]]
	var seg := 14
	var base := _nv
	for r in aneis.size():
		for k in seg:
			var ang := TAU * k / seg
			var jitter := rng.randf_range(-0.04, 0.04) if r == 2 else 0.0
			var rr: float = aneis[r][1] * (1.0 + (0.12 * sin(ang * 3.0 + 1.0) if r > 0 else 0.0))
			st.set_color(aneis[r][2])
			st.add_vertex(Vector3(cos(ang) * rr * 0.9, float(aneis[r][0]) + jitter, sin(ang) * rr))
			_nv += 1
	for r in aneis.size() - 1:
		for k in seg:
			var k2 := (k + 1) % seg
			var a := base + r * seg + k
			var b := base + r * seg + k2
			var c := base + (r + 1) * seg + k
			var e := base + (r + 1) * seg + k2
			st.add_index(a); st.add_index(c); st.add_index(b)
			st.add_index(b); st.add_index(c); st.add_index(e)
	for k in seg:   # tiras rasgadas penduradas
		var k2 := (k + 1) % seg
		var ang := TAU * (k + 0.5) / seg
		var rr := 0.33 + rng.randf_range(0.0, 0.07)
		st.set_color(COR_BARRA.lerp(COR_VAZIO, 0.5))
		st.add_vertex(Vector3(cos(ang) * rr * 0.95, rng.randf_range(0.04, 0.2), sin(ang) * rr))
		_nv += 1
		st.add_index(base + 2 * seg + k); st.add_index(_nv - 1); st.add_index(base + 2 * seg + k2)
	_no_malha(_modelo, _malha(st), Vector3.ZERO)

	# corpo (tronco) com pivô no quadril: a corcunda inclina daqui
	_corpo = Node3D.new()
	_corpo.position = Vector3(0, 1.0, 0)
	_modelo.add_child(_corpo)
	st = _novo_st()
	_tubo(st, [Vector3(0, -0.12, 0.0), Vector3(0, 0.2, 0.01), Vector3(0, 0.5, 0.04), Vector3(0, 0.72, 0.04), Vector3(0, 0.82, 0.0), Vector3(0, 0.88, -0.01), Vector3(0, 0.92, -0.01)],
		[0.085, 0.052, 0.095, 0.115, 0.085, 0.04, 0.035], 8, _cor_const(Color(COR_PELE.r, COR_PELE.g, COR_PELE.b, 0.0)), Vector2(1.25, 0.6))
	_no_malha(_corpo, _malha(st), Vector3.ZERO)
	_braco_e = _braco(-1.0)
	_braco_d = _braco(1.0)

	# cabeça pequena e comprida, rosto vazio, cabelo molhado em mechas
	_cabeca = Node3D.new()
	_cabeca.position = Vector3(0, 0.9, 0)
	_corpo.add_child(_cabeca)
	st = _novo_st()
	var cor_cab := func(i: int, d: Vector3) -> Color:
		if i >= 3 and i <= 5:
			var f := clampf(-d.z, 0.0, 1.0)
			return COR_PELE.lerp(COR_VAZIO, smoothf(0.25, 0.7, f))
		if i == 2:   # boca escura sobre o queixo pálido
			return COR_PELE.lerp(COR_VAZIO, 0.8 * smoothf(0.5, 0.9, clampf(-d.z, 0.0, 1.0)))
		return COR_PELE
	_tubo(st, [Vector3(0, 0, 0), Vector3(0, 0.14, -0.01), Vector3(0, 0.2, -0.015), Vector3(0, 0.28, -0.02), Vector3(0, 0.37, -0.015), Vector3(0, 0.45, 0), Vector3(0, 0.48, 0)],
		[0.035, 0.03, 0.05, 0.08, 0.077, 0.045, 0.01], 8, cor_cab, Vector2(0.9, 1.05))
	var cab_c := _cor_const(COR_CABELO)
	var ys := [0.46, 0.38, 0.28, 0.1, -0.15]
	var rs := [0.02, 0.07, 0.1, 0.098, 0.105]
	var nm := 22
	for m in nm:
		var ang := TAU * m / nm + rng.randf_range(-0.05, 0.05)
		# frente = -Z (ang = -PI/2): deixa uma fresta ali, onde aparecem o queixo pálido e a boca escura
		if absf(wrapf(ang + PI / 2.0, -PI, PI)) < 0.5:
			continue
		var fr := -sin(ang) * 0.5 + 0.5
		var fim := -0.28 - 0.3 * fr - rng.randf_range(0.0, 0.28)   # cortina reta até o peito, barra irregular
		var pts := []
		for i in ys.size():
			pts.append(Vector3(cos(ang) * rs[i] * 0.95, ys[i], sin(ang) * rs[i] * 1.02 - 0.015))
		pts.append(Vector3(cos(ang) * 0.1, fim, sin(ang) * 0.105 - 0.015))
		_tubo(st, pts, [0.012, 0.022, 0.024, 0.022, 0.02, 0.004], 4, cab_c)
	_no_malha(_cabeca, _malha(st), Vector3.ZERO)
	_pose_base()


func smoothf(a: float, b: float, x: float) -> float:
	return smoothstep(a, b, x)


## Pose de descanso: corcunda, cabeça pendida para o lado, braços soltos.
func _pose_base() -> void:
	_corpo.rotation = Vector3(-0.22, 0.0, 0.04)
	_cabeca.rotation = Vector3(-0.1, 0.0, 0.16)
	_braco_e.rotation = Vector3(0.05, 0.0, 0.03)
	_braco_d.rotation = Vector3(-0.04, 0.0, -0.05)
	_modelo.position.y = 0.0


## Nova pose "estalada" (sem interpolação): chamada em intervalos curtos enquanto ela anda.
func _pose_nova(forte: bool) -> void:
	var f := 1.6 if forte else 1.0
	_corpo.rotation = Vector3(-0.22 - (0.15 if forte else randf_range(-0.05, 0.08)), randf_range(-0.12, 0.12) * f, randf_range(-0.09, 0.09) * f)
	_cabeca.rotation = Vector3(-0.1 + randf_range(-0.15, 0.2), randf_range(-0.5, 0.5) * f, 0.16 * signf(_cabeca.rotation.z) + randf_range(-0.15, 0.15))
	if randf() < 0.18:
		_cabeca.rotation.z = -_cabeca.rotation.z   # estala para o outro lado
	_braco_e.rotation = Vector3(randf_range(-0.3, 0.35), 0.0, randf_range(-0.05, 0.14) * f)
	_braco_d.rotation = Vector3(randf_range(-0.35, 0.3), 0.0, randf_range(-0.14, 0.05) * f)   # fora de sincronia
	_modelo.position.y = randf_range(0.0, 0.025)
	_modelo.rotation.y = randf_range(-0.07, 0.07)


## Ao ser vista: congela com a cabeça virada de vez para o jogador (um estalo só).
func _pose_olhada() -> void:
	_pose_base()
	_cabeca.rotation = Vector3(0.1, 0.0, 0.5 * (1.0 if randf() < 0.5 else -1.0))
	_corpo.rotation = Vector3(-0.28, 0.0, 0.0)
	_modelo.rotation.y = 0.0


func _process(dt: float) -> void:
	if _modelo == null:
		return
	_t += dt
	_mat.set_shader_parameter("suelo", global_position.y)
	if _movendo:
		_snap_t -= dt
		if _snap_t <= 0.0:
			_snap_t = randf_range(0.07, 0.2)
			if _arranco:
				_arranco = false
				_pose_nova(true)
			elif randf() > 0.15:   # 15%: quadro pulado (segura a pose)
				_pose_nova(false)
	elif olhada and not _olhada_ant:
		_pose_olhada()
	_olhada_ant = olhada
	# cintilação só de perto, andando
	var b := 1.0
	if _movendo and _dist < 6.0 and randf() < 0.1:
		b = randf_range(0.15, 0.6)
	if not is_equal_approx(b, _brilho):
		_brilho = b
		_mat.set_shader_parameter("brilho", b)


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
	_dist = dist
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
