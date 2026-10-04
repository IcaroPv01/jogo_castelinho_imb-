class_name Malha
extends RefCounted
## Acumulador de geometria estática. Junta tudo por material numa única ArrayMesh (uma superfície por
## material): em vez de centenas de MeshInstance3D, o prédio inteiro vira poucos draw calls (meta da web).
## Também acumula as caixas de colisão (formas simples, separadas da malha visual).
##
## Convenção: os métodos recebem a NORMAL desejada da face; o enrolamento (horário no Godot) é
## corrigido sozinho, então a ordem dos vértices não precisa ser exata, só formar um laço.

var _sup := {}                 # Material -> {"v","n","uv","c"}
var _ordem: Array = []         # materiais na ordem de criação
var colisoes: Array[AABB] = [] # caixas de colisão (coordenadas do mundo)
var convexas: Array = []       # formas convexas (rampas de escada): cada item é um PackedVector3Array
var triangulos := 0

const F_PX := 1
const F_NX := 2
const F_PY := 4
const F_NY := 8
const F_PZ := 16
const F_NZ := 32
const F_TODAS := 63
const F_SEM_BASE := 63 - 8


## Materiais "de cor" (Castelinho.mat_cor/mat_tri com tom) carregam metadados e são fundidos num só material
## com cor de vértice: dezenas de cores viram poucas superfícies (draw calls).
static func _resolver(mat: Material, cor: Color) -> Array:
	if mat.has_meta("vc_base"):
		return [mat.get_meta("vc_base"), (mat.get_meta("vc") as Color) * cor]
	return [mat, cor]


func _s(mat: Material) -> Dictionary:
	if not _sup.has(mat):
		_sup[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
		_ordem.append(mat)
	return _sup[mat]


func vazia() -> bool:
	return _ordem.is_empty()


## Triângulo com normal dada. uvs opcionais (3 Vector2).
func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO, cor := Color.WHITE) -> void:
	var rr := _resolver(mat, cor)
	mat = rr[0]
	cor = rr[1]
	var s := _s(mat)
	if (b - a).cross(c - a).dot(n) < 0.0:
		# inverte para que a face fique voltada para `n` (frente = sentido horário no Godot)
		var t := b
		b = c
		c = t
		var tu := uvb
		uvb = uvc
		uvc = tu
	# o produto vetorial (b-a)x(c-a) agora aponta para n: emitir em ordem (a,c,b) = horário visto da frente
	for p in [[a, uva], [c, uvc], [b, uvb]]:
		s["v"].append(p[0])
		s["n"].append(n)
		s["uv"].append(p[1])
		s["c"].append(cor)
	triangulos += 1


## Quadrilátero a,b,c,d (laço em torno da face). uv_tam > 0 liga UV por metros (a->b = u, a->d = v).
func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv_tam := Vector2.ZERO, cor := Color.WHITE) -> void:
	var ua := Vector2.ZERO
	var ub := Vector2.ZERO
	var uc := Vector2.ZERO
	var ud := Vector2.ZERO
	if uv_tam != Vector2.ZERO:
		var eu := (b - a).normalized()
		var ev := (d - a).normalized()
		ub = Vector2((b - a).dot(eu) / uv_tam.x, (b - a).dot(ev) / uv_tam.y)
		uc = Vector2((c - a).dot(eu) / uv_tam.x, (c - a).dot(ev) / uv_tam.y)
		ud = Vector2((d - a).dot(eu) / uv_tam.x, (d - a).dot(ev) / uv_tam.y)
	tri(mat, a, b, c, n, ua, ub, uc, cor)
	tri(mat, a, c, d, n, ua, uc, ud, cor)


## Quadrilátero com UV explícita por vértice (a,b,c,d em laço; uv na mesma ordem).
func quad_uv(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2, cor := Color.WHITE) -> void:
	tri(mat, a, b, c, n, uva, uvb, uvc, cor)
	tri(mat, a, c, d, n, uva, uvc, uvd, cor)


## Quadrilátero cuja normal é calculada (e orientada para `dica`).
func quad_auto(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, dica: Vector3, uv_tam := Vector2.ZERO, cor := Color.WHITE) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.dot(dica) < 0.0:
		n = -n
	quad(mat, a, b, c, d, n, uv_tam, cor)


## Caixa entre dois cantos. `uv_tam` > 0 gera UV mundial por face (para materiais não triplanares).
func caixa(mat: Material, p0: Vector3, p1: Vector3, faces := F_SEM_BASE, uv_tam := 0.0, cor := Color.WHITE) -> void:
	var x0 := minf(p0.x, p1.x)
	var x1 := maxf(p0.x, p1.x)
	var y0 := minf(p0.y, p1.y)
	var y1 := maxf(p0.y, p1.y)
	var z0 := minf(p0.z, p1.z)
	var z1 := maxf(p0.z, p1.z)
	if x1 - x0 < 0.0005 or y1 - y0 < 0.0005 or z1 - z0 < 0.0005:
		return
	var t := Vector2(uv_tam, uv_tam)
	if faces & F_PX:
		_face_uv(mat, Vector3(x1, y0, z0), Vector3(x1, y1, z0), Vector3(x1, y1, z1), Vector3(x1, y0, z1), Vector3.RIGHT, t, 1, cor)
	if faces & F_NX:
		_face_uv(mat, Vector3(x0, y0, z1), Vector3(x0, y1, z1), Vector3(x0, y1, z0), Vector3(x0, y0, z0), Vector3.LEFT, t, 1, cor)
	if faces & F_PY:
		_face_uv(mat, Vector3(x0, y1, z0), Vector3(x0, y1, z1), Vector3(x1, y1, z1), Vector3(x1, y1, z0), Vector3.UP, t, 2, cor)
	if faces & F_NY:
		_face_uv(mat, Vector3(x0, y0, z0), Vector3(x1, y0, z0), Vector3(x1, y0, z1), Vector3(x0, y0, z1), Vector3.DOWN, t, 2, cor)
	if faces & F_PZ:
		_face_uv(mat, Vector3(x1, y0, z1), Vector3(x1, y1, z1), Vector3(x0, y1, z1), Vector3(x0, y0, z1), Vector3.BACK, t, 0, cor)
	if faces & F_NZ:
		_face_uv(mat, Vector3(x0, y0, z0), Vector3(x0, y1, z0), Vector3(x1, y1, z0), Vector3(x1, y0, z0), Vector3.FORWARD, t, 0, cor)


## eixo_u: 0 = u segue x (faces Z), 1 = u segue z (faces X), 2 = u segue x e v segue z (faces Y)
func _face_uv(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, t: Vector2, modo: int, cor: Color) -> void:
	if t.x <= 0.0:
		quad(mat, a, b, c, d, n, Vector2.ZERO, cor)
		return
	var pts := [a, b, c, d]
	var uvs := []
	for p in pts:
		var q := p as Vector3
		match modo:
			0:
				uvs.append(Vector2(q.x / t.x, -q.y / t.y))
			1:
				uvs.append(Vector2(q.z / t.x, -q.y / t.y))
			_:
				uvs.append(Vector2(q.x / t.x, q.z / t.y))
	tri(mat, a, b, c, n, uvs[0], uvs[1], uvs[2], cor)
	tri(mat, a, c, d, n, uvs[0], uvs[2], uvs[3], cor)


## Pirâmide de base retangular (centro da base em `c`), com 4 faces + base. `uv_tam` por metros.
func piramide(mat: Material, c: Vector3, w: float, d: float, h: float, uv_tam := 1.0, mat_base: Material = null) -> void:
	var x0 := c.x - w * 0.5
	var x1 := c.x + w * 0.5
	var z0 := c.z - d * 0.5
	var z1 := c.z + d * 0.5
	var ap := Vector3(c.x, c.y + h, c.z)
	var p00 := Vector3(x0, c.y, z0)
	var p10 := Vector3(x1, c.y, z0)
	var p11 := Vector3(x1, c.y, z1)
	var p01 := Vector3(x0, c.y, z1)
	var lados := [[p00, p10], [p10, p11], [p11, p01], [p01, p00]]
	for l in lados:
		var a: Vector3 = l[0]
		var b: Vector3 = l[1]
		var n := (b - a).cross(ap - a).normalized()
		# normal precisa apontar para fora
		var meio := (a + b) * 0.5
		var fora := Vector3(meio.x - c.x, 0, meio.z - c.z)
		if n.dot(fora) < 0.0:
			n = -n
		var comp := (b - a).length()
		var alt := (ap - meio).length()
		tri(mat, a, b, ap, n, Vector2(0, alt / uv_tam), Vector2(comp / uv_tam, alt / uv_tam), Vector2(comp * 0.5 / uv_tam, 0))
	if mat_base != null:
		quad(mat_base, p00, p10, p11, p01, Vector3.DOWN)


## Telhado de uma água: plano inclinado + beiral. Retorna nada; (x0..x1) (z0..z1); y_lado_x0 e y_lado_x1 = cota da face superior.
func telhado_agua(mat_topo: Material, mat_sob: Material, x0: float, x1: float, z0: float, z1: float, y_x0: float, y_x1: float, esp := 0.1, ondas_em_z := true) -> void:
	var a := Vector3(x0, y_x0, z0)
	var b := Vector3(x1, y_x1, z0)
	var c := Vector3(x1, y_x1, z1)
	var d := Vector3(x0, y_x0, z1)
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	if ondas_em_z:
		# u ao longo de z (as ondas correm na direção da água, que cai ao longo de x)
		quad(mat_topo, a, d, c, b, n, Vector2(1.416, 1.416))
	else:
		quad(mat_topo, a, b, c, d, n, Vector2(1.416, 1.416))
	var a2 := a - Vector3(0, esp, 0)
	var b2 := b - Vector3(0, esp, 0)
	var c2 := c - Vector3(0, esp, 0)
	var d2 := d - Vector3(0, esp, 0)
	quad(mat_sob, a2, b2, c2, d2, -n, Vector2(1.0, 1.0))
	# frentes (espessura)
	quad(mat_sob, a, b, b2, a2, Vector3.FORWARD, Vector2(1.0, 1.0))
	quad(mat_sob, d, c, c2, d2, Vector3.BACK, Vector2(1.0, 1.0))
	quad(mat_sob, a, d, d2, a2, Vector3.LEFT, Vector2(1.0, 1.0))
	quad(mat_sob, b, c, c2, b2, Vector3.RIGHT, Vector2(1.0, 1.0))


## Telhado de uma água com a queda ao longo de Z (y_z0 em z0, y_z1 em z1). As ondas correm ao longo de Z.
func telhado_agua_z(mat_topo: Material, mat_sob: Material, x0: float, x1: float, z0: float, z1: float, y_z0: float, y_z1: float, esp := 0.1) -> void:
	var a := Vector3(x0, y_z0, z0)
	var b := Vector3(x1, y_z0, z0)
	var c := Vector3(x1, y_z1, z1)
	var d := Vector3(x0, y_z1, z1)
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	quad(mat_topo, a, b, c, d, n, Vector2(1.416, 1.416))
	var e := Vector3(0, esp, 0)
	quad(mat_sob, a - e, b - e, c - e, d - e, -n, Vector2(1.0, 1.0))
	quad(mat_sob, a, b, b - e, a - e, Vector3.FORWARD, Vector2(1.0, 1.0))
	quad(mat_sob, d, c, c - e, d - e, Vector3.BACK, Vector2(1.0, 1.0))
	quad(mat_sob, a, d, d - e, a - e, Vector3.LEFT, Vector2(1.0, 1.0))
	quad(mat_sob, b, c, c - e, b - e, Vector3.RIGHT, Vector2(1.0, 1.0))


## Adiciona uma caixa de colisão (coordenadas do mundo).
func col(p0: Vector3, p1: Vector3) -> void:
	var mn := Vector3(minf(p0.x, p1.x), minf(p0.y, p1.y), minf(p0.z, p1.z))
	var mx := Vector3(maxf(p0.x, p1.x), maxf(p0.y, p1.y), maxf(p0.z, p1.z))
	if mx.x - mn.x < 0.001 or mx.y - mn.y < 0.001 or mx.z - mn.z < 0.001:
		return
	colisoes.append(AABB(mn, mx - mn))


## Rampa (prisma convexo) para escadas: pontos em coordenadas do mundo.
func rampa(pts: PackedVector3Array) -> void:
	convexas.append(pts)


## Cria a ArrayMesh combinada. `indices` recebe material -> índice de superfície (para trocar materiais por época).
func construir_malha(indices: Dictionary = {}) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	for mat in _ordem:
		var s: Dictionary = _sup[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = s["v"]
		arr[Mesh.ARRAY_NORMAL] = s["n"]
		arr[Mesh.ARRAY_TEX_UV] = s["uv"]
		arr[Mesh.ARRAY_COLOR] = s["c"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		var idx := mesh.get_surface_count() - 1
		mesh.surface_set_material(idx, mat)
		indices[mat] = idx
	return mesh


func construir_instancia(pai: Node, nome: String, camada := 1, indices: Dictionary = {}) -> MeshInstance3D:
	if vazia():
		return null
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = construir_malha(indices)
	mi.layers = camada
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


## Cria um StaticBody3D com uma CollisionShape3D (BoxShape3D) por caixa acumulada.
func construir_colisao(pai: Node, nome: String) -> StaticBody3D:
	if colisoes.is_empty() and convexas.is_empty():
		return null
	var sb := StaticBody3D.new()
	sb.name = nome
	sb.collision_layer = 1
	sb.collision_mask = 0
	for bx in colisoes:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = bx.size
		cs.shape = bs
		cs.position = bx.get_center()
		sb.add_child(cs)
	for pts in convexas:
		var cs := CollisionShape3D.new()
		var cp := ConvexPolygonShape3D.new()
		cp.points = pts
		cs.shape = cp
		sb.add_child(cs)
	pai.add_child(sb)
	return sb
