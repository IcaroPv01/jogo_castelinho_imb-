class_name Costela
extends Node3D
## A Costela-de-Adão (a planta que dá nome à cidade, V2_ROTEIRO §6.2): cipós de folhas grandes e recortadas que crescem
## nas paredes e no chão ENQUANTO O JOGADOR FICA PARADO.
##
## REGRA (uma só, legível):
##   - Parado (< `vel_parado` m/s) por `tempo_prende` s: os cipós crescem a partir das paredes e do chão ao redor.
##   - Andando, eles recuam (mais depressa do que crescem).
##   - Se chegarem ao fim, PRENDEM: o jogador fica travado no lugar (a câmera continua livre). Apertar uma direção
##     (andar = lutar) solta se for por `luta_necessaria` s; sem lutar, em `tempo_mata` s eles matam:
##     `GameState.matar_jogador("costela")`. Solto, o jogador fica imune por 1,5 s (para fugir).
##
## É só a mecânica: o nível liga com `ativa = true` nas salas da Costela. Nenhum gráfico violento: a tela só escurece.
##
## Uso:
##     var c := Costela.new(); c.alvo = player; nivel.add_child(c); c.ativa = true
## Também oferece `decor(...)`: cipós secos e imóveis nas paredes (a dica visual de que ali a planta manda).

signal prendeu
signal soltou
signal matou

@export var tempo_prende := 3.2
@export var tempo_mata := 2.6
@export var vel_parado := 0.45          # m/s: abaixo disso o jogador conta como parado
@export var luta_necessaria := 0.9      # s apertando uma direção para se soltar

const N_CIPOS := 12
const CORES := {"talo": Color(0.20, 0.27, 0.09), "folha_escura": Color(0.07, 0.24, 0.1), "folha_clara": Color(0.2, 0.48, 0.2),
	"nervura": Color(0.05, 0.14, 0.06)}

var alvo: Node3D
var ativa := false:
	set(v):
		ativa = v
		if not v:
			_zerar()
var parado_t := 0.0            # s acumulados parado (0..tempo_prende)
var crescimento := 0.0         # 0..1 (o que aparece)
var presa := false
var tempo_preso := 0.0
var luta := 0.0
var velocidade := 0.0          # m/s do jogador (suavizada), para testes

static var _malhas: Array[ArrayMesh] = []
static var _material: StandardMaterial3D

var _cipos: Array[MeshInstance3D] = []
var _ancoras_ok := false
var _pos_ant := Vector3.ZERO
var _tem_pos := false
var _imune := 0.0
var _pos_prisao := Vector3.ZERO
var _prox_pulso := 0.0


func _ready() -> void:
	name = "Costela"
	process_physics_priority = 101     # depois do jogador e do nível: a prisão vale por último
	for i in N_CIPOS:
		var mi := MeshInstance3D.new()
		mi.mesh = malha_variante(i % 3)
		mi.material_override = material()
		mi.visible = false
		mi.top_level = true
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		_cipos.append(mi)


# ---------------------------------------------------------------- lógica
func _physics_process(dt: float) -> void:
	if alvo == null or not is_instance_valid(alvo):
		alvo = get_tree().get_first_node_in_group("player") as Node3D
		return
	var pos := alvo.global_position
	if not _tem_pos:
		_pos_ant = pos
		_tem_pos = true
	var v_inst := Vector2(pos.x - _pos_ant.x, pos.z - _pos_ant.z).length() / maxf(dt, 0.0001)
	if v_inst > 12.0:         # teletransporte (checkpoint): não conta como corrida
		v_inst = 0.0
	velocidade = lerpf(velocidade, v_inst, 1.0 - exp(-dt * 14.0))
	_pos_ant = pos
	if not ativa:
		return
	var livre: bool = alvo.get("pode_mover") != false and not GameState.flag("ui_aberta")
	_imune = maxf(0.0, _imune - dt)

	if presa:
		_atualizar_presa(dt)
	else:
		var parado := velocidade < vel_parado and livre and _imune <= 0.0
		if parado:
			if not _ancoras_ok and parado_t <= 0.001:
				_sortear_ancoras()
			parado_t = minf(parado_t + dt, tempo_prende)
			if parado_t >= tempo_prende:
				_prender()
		else:
			parado_t = maxf(0.0, parado_t - dt * 3.0)        # recuam depressa
			if parado_t <= 0.001:
				_ancoras_ok = false
	crescimento = 1.0 if presa else clampf(parado_t / tempo_prende, 0.0, 1.0)
	_aplicar_escala()


func _atualizar_presa(dt: float) -> void:
	tempo_preso += dt
	alvo.global_position = _pos_prisao
	if alvo is CharacterBody3D:
		(alvo as CharacterBody3D).velocity = Vector3.ZERO
	var luta_agora := Input.get_vector("esquerda", "direita", "frente", "tras").length() > 0.2
	luta = clampf(luta + (dt if luta_agora else -dt * 0.6), 0.0, luta_necessaria)
	_prox_pulso -= dt
	if _prox_pulso <= 0.0:
		_prox_pulso = 1.1
		Efeitos.pulso(0.28 + 0.4 * (tempo_preso / tempo_mata), 0.35)
	if luta >= luta_necessaria:
		_soltar()
	elif tempo_preso >= tempo_mata:
		presa = false
		ativa = false
		matou.emit()
		GameState.matar_jogador("costela")


func _prender() -> void:
	presa = true
	tempo_preso = 0.0
	luta = 0.0
	_pos_prisao = alvo.global_position
	Audio.sfx("ofego", -2.0)
	Efeitos.pulso(0.5, 0.4)
	prendeu.emit()


func _soltar() -> void:
	presa = false
	parado_t = 0.0
	luta = 0.0
	tempo_preso = 0.0
	_imune = 1.5
	_ancoras_ok = false
	Audio.sfx("ofego", -6.0, 1.2)
	soltou.emit()


func _zerar() -> void:
	presa = false
	parado_t = 0.0
	crescimento = 0.0
	tempo_preso = 0.0
	luta = 0.0
	_ancoras_ok = false
	for c in _cipos:
		if is_instance_valid(c):
			c.visible = false


func _aplicar_escala() -> void:
	for i in _cipos.size():
		var c := _cipos[i]
		# cada cipó tem seu atraso: crescem em ondas, não todos juntos
		var atraso := float(i % 4) * 0.08
		var k := clampf((crescimento - atraso) / (1.0 - atraso), 0.0, 1.0)
		k = k * k * (3.0 - 2.0 * k)
		c.visible = k > 0.02 and _ancoras_ok
		if c.visible:
			var esc: float = c.get_meta("esc", 1.0)
			c.scale = Vector3.ONE * (k * esc)


## Escolhe as raízes: 1 em cada 3 no chão, bem perto (anel de 0,5 a 1,3 m), o resto nas paredes que houver num raio de
## 3,6 m; cada cipó nasce na superfície e se inclina para o jogador.
func _sortear_ancoras() -> void:
	var base := alvo.global_position
	var cabeca := base + Vector3(0, 1.4, 0)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var espaco := get_world_3d().direct_space_state
	for i in _cipos.size():
		var ang := TAU * (float(i) + rng.randf() * 0.7) / _cipos.size()
		var dir := Vector3(cos(ang), 0, sin(ang))
		var ponto := Vector3.ZERO
		var normal := Vector3.UP
		var achou := false
		if i % 3 != 0:
			var q := PhysicsRayQueryParameters3D.create(base + Vector3(0, rng.randf_range(0.3, 1.5), 0), base + Vector3(0, 0.0, 0) + dir * 3.6, 1)
			q.exclude = [alvo.get_rid()] if alvo is CollisionObject3D else []
			var h := espaco.intersect_ray(q)
			if not h.is_empty() and absf((h.normal as Vector3).y) < 0.6:
				ponto = h.position
				normal = h.normal
				achou = true
		if not achou:
			var r := rng.randf_range(0.5, 1.3)
			var o := base + dir * r + Vector3(0, 0.8, 0)
			var q2 := PhysicsRayQueryParameters3D.create(o, o + Vector3(0, -2.0, 0), 1)
			q2.exclude = [alvo.get_rid()] if alvo is CollisionObject3D else []
			var h2 := espaco.intersect_ray(q2)
			if h2.is_empty():
				ponto = base + dir * r
			else:
				ponto = h2.position
				normal = h2.normal
		var c := _cipos[i]
		var y := (normal * 0.78 + (cabeca - ponto).normalized() * 0.22).normalized()
		var z := (cabeca - ponto) - y * (cabeca - ponto).dot(y)
		if z.length() < 0.05:
			z = y.cross(Vector3.RIGHT)
		z = z.normalized()
		var x := y.cross(z).normalized()
		c.global_transform = Transform3D(Basis(x, y, z.cross(x).normalized()).orthonormalized(), ponto)
		c.set_meta("esc", rng.randf_range(0.85, 1.25) * (1.15 if i % 3 == 0 else 1.0))
	_ancoras_ok = true


# ---------------------------------------------------------------- malhas
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.85
		_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _material


static func malha_variante(k: int) -> ArrayMesh:
	while _malhas.size() < 3:
		var rng := RandomNumberGenerator.new()
		rng.seed = 4242 + _malhas.size() * 17
		var m := Malha.new()
		adicionar_cipo(m, Transform3D.IDENTITY, rng, 1.6 + 0.3 * _malhas.size(), 4 + _malhas.size())
		_malhas.append(m.construir_malha())
	return _malhas[k % 3]


## Contorno (x, y) de uma folha de costela-de-adão: coração arredondado com 4 recortes fundos de cada lado, ponta no
## topo e pecíolo na base (y = 0). Comprimento ~1 (escale à vontade).
static func contorno_folha() -> PackedVector2Array:
	var meia := [Vector2(0.0, 0.0), Vector2(0.10, 0.06), Vector2(0.27, 0.12), Vector2(0.33, 0.24), Vector2(0.17, 0.26),
		Vector2(0.37, 0.38), Vector2(0.30, 0.52), Vector2(0.14, 0.50), Vector2(0.27, 0.64), Vector2(0.20, 0.78),
		Vector2(0.07, 0.74), Vector2(0.0, 1.0)]
	var pts := PackedVector2Array()
	for p in meia:
		pts.append(p)
	for i in range(meia.size() - 2, 0, -1):
		pts.append(Vector2(-(meia[i] as Vector2).x, (meia[i] as Vector2).y))
	return pts


## Uma folha, ligada a `pos` com a ponta apontando para `dir` e a face para `normal` (duas faces: material sem cull).
static func adicionar_folha(m: Malha, pos: Vector3, dir: Vector3, normal: Vector3, tam: float) -> void:
	var mat := material()
	var lateral := dir.cross(normal).normalized()
	var norm_ := lateral.cross(dir).normalized()
	var ct := contorno_folha()
	var centro := pos + dir * tam * 0.45
	var c_centro := CORES["folha_escura"].lerp(CORES["folha_clara"], 0.5) as Color
	for i in ct.size():
		var a := ct[i]
		var b := ct[(i + 1) % ct.size()]
		var pa := pos + lateral * a.x * tam + dir * a.y * tam
		var pb := pos + lateral * b.x * tam + dir * b.y * tam
		var ca: Color = CORES["folha_escura"].lerp(CORES["folha_clara"], clampf(a.y, 0.0, 1.0))
		var cb: Color = CORES["folha_escura"].lerp(CORES["folha_clara"], clampf(b.y, 0.0, 1.0))
		# leve curvatura: a folha "abre" para cima (centro um pouco adiantado na direção da normal)
		m.tri_cores(mat, pa, pb, centro + norm_ * tam * 0.06, norm_, ca, cb, c_centro)
	# nervura central escura
	var tip := pos + dir * tam
	m.tri_cores(mat, pos + lateral * 0.015 * tam, pos - lateral * 0.015 * tam, tip, norm_, CORES["nervura"], CORES["nervura"], CORES["nervura"])


## Um cipó: talo curvo (prisma de 4 lados que afina) saindo de `t.origin` na direção de `t.basis.y`, inclinando-se para
## +Z, com folhas grandes alternadas. `comp` em metros.
static func adicionar_cipo(m: Malha, t: Transform3D, rng: RandomNumberGenerator, comp: float, n_folhas: int) -> void:
	var mat := material()
	var seg := 7
	var pts: Array[Vector3] = []
	var tans: Array[Vector3] = []
	for i in seg + 1:
		var u := float(i) / seg
		# curva suave: sobe e se inclina para +Z (e um pouco de lado, por variação)
		var p := Vector3(sin(u * 5.0 + rng.randf()) * 0.04 * comp, u * comp * 0.92, u * u * comp * 0.5)
		pts.append(t * p)
	for i in seg + 1:
		var a := pts[maxi(i - 1, 0)]
		var b := pts[mini(i + 1, seg)]
		tans.append((b - a).normalized())
	for i in seg:
		var r0 := lerpf(0.045, 0.012, float(i) / seg)
		var r1 := lerpf(0.045, 0.012, float(i + 1) / seg)
		var side0 := tans[i].cross(Vector3.RIGHT)
		if side0.length() < 0.2:
			side0 = tans[i].cross(Vector3.FORWARD)
		side0 = side0.normalized()
		var up0 := tans[i].cross(side0).normalized()
		var side1 := tans[i + 1].cross(side0).cross(tans[i + 1]).normalized()
		var up1 := tans[i + 1].cross(side1).normalized()
		var f0 := [pts[i] + side0 * r0, pts[i] + up0 * r0, pts[i] - side0 * r0, pts[i] - up0 * r0]
		var f1 := [pts[i + 1] + side1 * r1, pts[i + 1] + up1 * r1, pts[i + 1] - side1 * r1, pts[i + 1] - up1 * r1]
		for k in 4:
			var k2 := (k + 1) % 4
			var fora: Vector3 = ((f0[k] as Vector3) + (f0[k2] as Vector3)) * 0.5 - pts[i]
			m.quad(mat, f0[k], f0[k2], f1[k2], f1[k], fora.normalized(), Vector2.ZERO, CORES["talo"])
	# folhas alternadas ao longo do cipó
	for j in n_folhas:
		var u := 0.2 + 0.78 * float(j) / maxf(1.0, n_folhas - 1)
		var idx := clampi(int(u * seg), 0, seg - 1)
		var p := pts[idx].lerp(pts[idx + 1], u * seg - idx)
		var tan := tans[idx]
		var lado := 1.0 if j % 2 == 0 else -1.0
		var lat := tan.cross(Vector3.RIGHT)
		if lat.length() < 0.2:
			lat = tan.cross(Vector3.FORWARD)
		lat = lat.normalized() * lado
		var dir := (lat * 0.9 + tan * 0.35 + (t.basis * Vector3.FORWARD * 0.0)).normalized()
		var normal := tan.cross(lat).normalized()
		adicionar_folha(m, p, dir, normal, rng.randf_range(0.42, 0.62) * (1.0 - 0.35 * u))
	# folha de ponta
	adicionar_folha(m, pts[seg], tans[seg], tans[seg].cross(Vector3.RIGHT).normalized(), 0.34)


## Cipós SECOS e imóveis nas paredes de uma sala (dica visual: "aqui a planta manda"). Uma só malha (1 draw call).
## `w` e `L` = largura e comprimento internos da sala, `h` = altura. Devolve o MeshInstance3D (filho de `pai`).
static func decor(pai: Node3D, rng: RandomNumberGenerator, w: float, L: float, h: float, n := 7) -> MeshInstance3D:
	var m := Malha.new()
	for i in n:
		var lado := -1.0 if i % 2 == 0 else 1.0
		var z := -1.5 - (L - 3.0) * (float(i) + rng.randf() * 0.6) / n
		var raiz := Vector3(lado * (w * 0.5 - 0.04), rng.randf_range(0.0, 0.3), z)
		# +Y local = para cima ao longo da parede; +Z local = para o centro da sala (rola sobre a parede)
		var t := Transform3D(Basis(Vector3(0, 0, lado), Vector3.UP, Vector3(-lado, 0, 0)), raiz)
		adicionar_cipo(m, t, rng, rng.randf_range(h * 0.45, h * 0.8), 5)
	var mi := m.construir_instancia(pai, "CostelaDecor")
	return mi
