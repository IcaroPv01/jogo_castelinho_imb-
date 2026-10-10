class_name Malha
extends RefCounted
## Acumulador de geometria estática. Junta tudo por material numa única ArrayMesh (uma superfície por
## material): em vez de centenas de MeshInstance3D, o prédio inteiro vira poucos draw calls (meta da web).
## Também acumula as caixas de colisão (formas simples, separadas da malha visual).
##
## Convenção: os métodos recebem a NORMAL desejada da face; o enrolamento (horário no Godot) é
## corrigido sozinho, então a ordem dos vértices não precisa ser exata, só formar um laço.
##
## ========================= INSTRUMENTAÇÃO (verificador de colocação e galeria 3D) =========================
## DESLIGADA por padrão (`registrar = false`): o jogo (web) paga só um `if` por primitiva. Ligada, cada primitiva
## de alto nível (caixa, quad, tri, bolha, pirâmide, telhado, col, rampa) grava UMA entrada em `Malha.registro`:
##   {etiqueta, tipo, aabb, normal, faces, material, cor, grupo, epocas, nivel, onde, malha}
##   etiqueta  nome do OBJETO (snake_case, ex.: "sofa_1975"); "" = estrutura/cenário sem nome.
##   tipo      "caixa" | "quad" | "tri" | "bolha" | "piramide" | "telhado" | "col" | "rampa" | "no" (nó da árvore).
##   aabb      AABB no MUNDO (já somado a `Malha.origem`). normal: Vector3 da face (quad/tri); ZERO nas caixas.
##   faces     máscara F_* das faces emitidas (caixa). area: m² (quad/tri). material: id (ver `Malha.materiais`); cor: "#rrggbb" do tom.
##   grupo     rótulo da Malha ("Casa/ext", "Museu_2020/int"...); epocas: Array de GameState.Epoca ([] = todas).
##   nivel     `Malha.nivel` no momento da construção ("castelinho", "porao", ...). onde: "arq.gd:linha fn < ..." (pilha).
##   malha     instance_id da Malha (para casar com `Malha.malhas`).
## Como usar:
##   Malha.ligar("castelinho")                  # liga e limpa (registrar = true)
##   ... construir o nível (as construtoras marcam os objetos com a etiqueta) ...
##   Malha.registro                              # Array[Dictionary] com tudo
##   Malha.info_por_etiqueta()                   # {etiqueta: {nivel, grupos, epocas, n, aabb, onde}}
##   Malha.mesh_da_etiqueta("sofa_1975")         # ArrayMesh só com os triângulos dessa etiqueta (coords do mundo)
##   Malha.desligar()
## Nas construtoras de objetos:
##   var _et := Malha.abrir("sofa_1975")         # `etiqueta` passa a valer; devolve a anterior
##   ... g.inte.caixa(...) ...
##   Malha.fechar(_et)                           # volta à anterior
## Objetos que são NÓS (MeshInstance3D, Painel3D, criaturas...) entram pela varredura da árvore:
## `RegistroObjetos.varrer(raiz, nivel)` (castelinho/registro.gd) escreve no mesmo `registro` (tipo "no"); o nome
## vem de `Malha.nomear(no, "nome")` (meta "etiqueta") ou, na falta, do caminho do nó.
## Salas do porão: `Malha.origem` é somado às coordenadas (cada sala fica no seu lugar do mundo).

static var registrar := false
static var etiqueta := ""                 # objeto sendo construído agora
static var registro: Array = []           # entradas (ver acima)
static var materiais := {}                # id -> {"nome", "transparente", "sem_luz", "emissivo", "dupla"}
static var malhas: Array = []             # todas as Malha criadas com `registrar` ligado
static var nivel := ""                    # nível em construção (marca as entradas)
static var origem := Vector3.ZERO         # deslocamento de mundo somado às entradas e a `mesh_da_etiqueta`
static var _prof := 0                     # >0 dentro de uma primitiva composta: só a de fora grava

var rotulo := ""                          # grupo desta Malha (Castelinho.Grupo escreve "Casa/ext"...)
var epocas: Array = []                    # épocas do grupo ([] = todas)
var desloc := Vector3.ZERO                # `origem` no instante em que a Malha nasceu


func _init() -> void:
	if registrar:
		desloc = origem
		rotulo = nivel
		malhas.append(self)


static func ligar(nivel_novo := "") -> void:
	limpar()
	registrar = true
	nivel = nivel_novo


static func desligar() -> void:
	registrar = false
	etiqueta = ""
	origem = Vector3.ZERO


static func limpar() -> void:
	registro.clear()
	malhas.clear()
	materiais.clear()
	etiqueta = ""
	origem = Vector3.ZERO
	_prof = 0


## Abre uma etiqueta de objeto; devolve a anterior para `fechar`.
static func abrir(nome: String) -> String:
	var ant := etiqueta
	etiqueta = nome
	return ant


static func fechar(anterior: String) -> void:
	etiqueta = anterior


## Dá nome estável a um nó-objeto (lido pela varredura da árvore). Devolve o próprio nó.
static func nomear(no: Node, nome: String) -> Node:
	no.set_meta("etiqueta", nome)
	return no


## Pilha curta (fora de malha.gd) "arq.gd:linha fn < arq.gd:linha fn ...": arquivo:linha provável de quem criou.
static func quem(max_frames := 4) -> String:
	var partes: PackedStringArray = []
	for fr in get_stack():
		var src: String = fr.get("source", "")
		if src.ends_with("/malha.gd"):
			continue
		partes.append("%s:%d %s" % [src.get_file(), int(fr.get("line", 0)), fr.get("function", "")])
		if partes.size() >= max_frames:
			break
	return " < ".join(partes)


static func _mat_id(mat: Material) -> int:
	if mat == null:
		return 0
	var id := mat.get_instance_id()
	if not materiais.has(id):
		var d := {"nome": mat.resource_name, "transparente": false, "sem_luz": false, "emissivo": false, "dupla": false}
		if mat is BaseMaterial3D:
			var b := mat as BaseMaterial3D
			d["transparente"] = b.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED
			d["sem_luz"] = b.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED
			d["emissivo"] = b.emission_enabled
			d["dupla"] = b.cull_mode == BaseMaterial3D.CULL_DISABLED
			if d["nome"] == "" and b.albedo_texture:
				d["nome"] = b.albedo_texture.resource_path.get_file()
			if d["nome"] == "":
				d["nome"] = "cor " + b.albedo_color.to_html(false)
		elif mat is ShaderMaterial:
			var sm := mat as ShaderMaterial
			if d["nome"] == "" and sm.shader:
				d["nome"] = "shader " + sm.shader.resource_path.get_file()
		materiais[id] = d
	return id


func _reg(tipo: String, mat: Material, cor: Color, bb: AABB, n := Vector3.ZERO, faces := 0, area := 0.0) -> void:
	if _prof > 0:
		return
	var mid := 0
	var tom := cor
	if mat:
		var rr := _resolver(mat, cor)
		mid = _mat_id(rr[0])
		tom = rr[1]
	registro.append({"etiqueta": etiqueta, "tipo": tipo, "aabb": AABB(bb.position + desloc, bb.size), "normal": n, "faces": faces,
		"material": mid, "cor": tom.to_html(false), "area": area, "grupo": rotulo, "epocas": epocas, "nivel": nivel,
		"onde": quem(), "malha": get_instance_id()})


static func _bb(pts: Array) -> AABB:
	var bb := AABB(pts[0], Vector3.ZERO)
	for i in range(1, pts.size()):
		bb = bb.expand(pts[i])
	return bb


## Resumo por etiqueta: {nivel, grupos, epocas (união; [] = todas), n (primitivas), aabb, onde}.
static func info_por_etiqueta() -> Dictionary:
	var r := {}
	for e in registro:
		var et: String = e["etiqueta"]
		if et == "":
			continue
		if not r.has(et):
			r[et] = {"nivel": e["nivel"], "grupos": [], "epocas": [], "todas_epocas": false, "n": 0, "aabb": e["aabb"], "onde": e["onde"]}
		var d: Dictionary = r[et]
		d["n"] += 1
		d["aabb"] = (d["aabb"] as AABB).merge(e["aabb"])
		if not (e["grupo"] in d["grupos"]):
			d["grupos"].append(e["grupo"])
		if (e["epocas"] as Array).is_empty():
			d["todas_epocas"] = true
		for ep in e["epocas"]:
			if not (ep in d["epocas"]):
				d["epocas"].append(ep)
	for et in r:
		if r[et]["todas_epocas"]:
			r[et]["epocas"] = []
	return r


## ArrayMesh só com os triângulos cuja etiqueta é `et` (coords do mundo = local + `desloc` da Malha).
## Precisa que a Malha tenha sido construída com `registrar` ligado. `prefixo` = aceita "et*".
static func mesh_da_etiqueta(et: String, prefixo := false) -> ArrayMesh:
	var mesh := ArrayMesh.new()
	var por_mat := {}
	for ma in malhas:
		var mm: Malha = ma
		for mat in mm._ordem:
			var s: Dictionary = mm._sup[mat]
			if not s.has("et"):
				continue
			var ets: PackedStringArray = s["et"]
			for t in ets.size():
				var x := ets[t]
				if x == et or (prefixo and x.begins_with(et)):
					if not por_mat.has(mat):
						por_mat[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
					var d: Dictionary = por_mat[mat]
					for k in 3:
						d["v"].append((s["v"] as PackedVector3Array)[t * 3 + k] + mm.desloc)
						d["n"].append((s["n"] as PackedVector3Array)[t * 3 + k])
						d["uv"].append((s["uv"] as PackedVector2Array)[t * 3 + k])
						d["c"].append((s["c"] as PackedColorArray)[t * 3 + k])
	for mat in por_mat:
		var d: Dictionary = por_mat[mat]
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = d["v"]
		arr[Mesh.ARRAY_NORMAL] = d["n"]
		arr[Mesh.ARRAY_TEX_UV] = d["uv"]
		arr[Mesh.ARRAY_COLOR] = d["c"]
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat)
	return mesh

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
		if registrar:
			_sup[mat]["et"] = PackedStringArray()      # etiqueta de cada triângulo (galeria 3D)
		_ordem.append(mat)
	return _sup[mat]


func vazia() -> bool:
	return _ordem.is_empty()


## Triângulo com normal dada. uvs opcionais (3 Vector2).
func tri(mat: Material, a: Vector3, b: Vector3, c: Vector3, n: Vector3, uva := Vector2.ZERO, uvb := Vector2.ZERO, uvc := Vector2.ZERO, cor := Color.WHITE) -> void:
	if registrar:
		_reg("tri", mat, cor, _bb([a, b, c]), n, 0, 0.5 * (b - a).cross(c - a).length())
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
	if registrar:
		(s["et"] as PackedStringArray).append(etiqueta)
	triangulos += 1


## Triângulo com cor por vértice (sombreado de Gouraud "de PS1": oclusão falsa em tufos e arbustos).
## A normal é a da face (facetado low-poly) e é orientada para `dica`.
func tri_cores(mat: Material, a: Vector3, b: Vector3, c: Vector3, dica: Vector3, ca: Color, cb: Color, cc: Color) -> void:
	if registrar:
		_reg("tri", mat, Color.WHITE, _bb([a, b, c]), dica, 0, 0.5 * (b - a).cross(c - a).length())
	var rr := _resolver(mat, Color.WHITE)
	mat = rr[0]
	var tom: Color = rr[1]
	var n := (b - a).cross(c - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	if n.dot(dica) < 0.0:
		n = -n
		var t := b
		b = c
		c = t
		var tc := cb
		cb = cc
		cc = tc
	var s := _s(mat)
	for p in [[a, ca], [c, cc], [b, cb]]:
		s["v"].append(p[0])
		s["n"].append(n)
		s["uv"].append(Vector2.ZERO)
		s["c"].append((p[1] as Color) * tom)
	if registrar:
		(s["et"] as PackedStringArray).append(etiqueta)
	triangulos += 1


## Elipsoide low-poly irregular ("bolha"): tufo de pinheiro, arbusto, copa, cacho de hortênsia.
## `seg` lados x `aneis` anéis; os vértices são sacudidos por `jit` (fração do raio) com `rnd`.
## A cor de vértice vai de `cor_base` (embaixo, escuro: oclusão falsa) a `cor_topo` (em cima). Facetado.
func bolha(mat: Material, c: Vector3, r: Vector3, rnd: RandomNumberGenerator, seg := 6, aneis := 2, jit := 0.18,
		cor_topo := Color.WHITE, cor_base := Color(0.55, 0.55, 0.55)) -> void:
	if registrar:
		_reg("bolha", mat, Color.WHITE, AABB(c - r, r * 2.0))
		_prof += 1
	var anel: Array = []
	var giro := rnd.randf_range(0.0, TAU)
	for i in aneis:
		var th := PI * float(i + 1) / float(aneis + 1)
		var pts: Array = []
		for k in seg:
			var ph := giro + TAU * (float(k) + 0.5 * float(i % 2)) / float(seg)
			var j := 1.0 + rnd.randf_range(-jit, jit)
			pts.append(c + Vector3(r.x * sin(th) * cos(ph) * j, r.y * cos(th) * (1.0 + rnd.randf_range(-jit, jit) * 0.5), r.z * sin(th) * sin(ph) * j))
		anel.append(pts)
	var topo := c + Vector3(rnd.randf_range(-jit, jit) * r.x * 0.5, r.y * (1.0 + rnd.randf_range(-jit, jit) * 0.4), rnd.randf_range(-jit, jit) * r.z * 0.5)
	var base := c - Vector3(0, r.y * 0.85, 0)
	var cor := func(p: Vector3) -> Color:
		var t := clampf((p.y - (c.y - r.y)) / (2.0 * r.y), 0.0, 1.0)
		return cor_base.lerp(cor_topo, t)
	for k in seg:
		var k1 := (k + 1) % seg
		var a: Vector3 = anel[0][k]
		var b: Vector3 = anel[0][k1]
		tri_cores(mat, topo, a, b, (a + b) * 0.5 + topo - c * 2.0, cor.call(topo), cor.call(a), cor.call(b))
	for i in aneis - 1:
		for k in seg:
			var k1 := (k + 1) % seg
			var a: Vector3 = anel[i][k]
			var b: Vector3 = anel[i][k1]
			var d: Vector3 = anel[i + 1][k]
			var e: Vector3 = anel[i + 1][k1]
			var fora := (a + b + d + e) * 0.25 - c
			tri_cores(mat, a, d, b, fora, cor.call(a), cor.call(d), cor.call(b))
			tri_cores(mat, b, d, e, fora, cor.call(b), cor.call(d), cor.call(e))
	for k in seg:
		var k1 := (k + 1) % seg
		var a: Vector3 = anel[aneis - 1][k]
		var b: Vector3 = anel[aneis - 1][k1]
		tri_cores(mat, base, a, b, (a + b) * 0.5 - c, cor.call(base), cor.call(a), cor.call(b))
	if registrar:
		_prof -= 1


## Quadrilátero a,b,c,d (laço em torno da face). uv_tam > 0 liga UV por metros (a->b = u, a->d = v).
func quad(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uv_tam := Vector2.ZERO, cor := Color.WHITE) -> void:
	if registrar:
		_reg("quad", mat, cor, _bb([a, b, c, d]), n, 0, 0.5 * (c - a).cross(d - b).length())
		_prof += 1
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
	if registrar:
		_prof -= 1


## Quadrilátero com UV explícita por vértice (a,b,c,d em laço; uv na mesma ordem).
func quad_uv(mat: Material, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3, uva: Vector2, uvb: Vector2, uvc: Vector2, uvd: Vector2, cor := Color.WHITE) -> void:
	if registrar:
		_reg("quad", mat, cor, _bb([a, b, c, d]), n, 0, 0.5 * (c - a).cross(d - b).length())
		_prof += 1
	tri(mat, a, b, c, n, uva, uvb, uvc, cor)
	tri(mat, a, c, d, n, uva, uvc, uvd, cor)
	if registrar:
		_prof -= 1


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
	if registrar:
		_reg("caixa", mat, cor, AABB(Vector3(x0, y0, z0), Vector3(x1 - x0, y1 - y0, z1 - z0)), Vector3.ZERO, faces)
		_prof += 1
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
	if registrar:
		_prof -= 1


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
	if registrar:
		_reg("piramide", mat, Color.WHITE, AABB(Vector3(c.x - w * 0.5, minf(c.y, c.y + h), c.z - d * 0.5), Vector3(w, absf(h), d)))
		_prof += 1
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
	if registrar:
		_prof -= 1


## Telhado de uma água: plano inclinado + beiral. Retorna nada; (x0..x1) (z0..z1); y_lado_x0 e y_lado_x1 = cota da face superior.
func telhado_agua(mat_topo: Material, mat_sob: Material, x0: float, x1: float, z0: float, z1: float, y_x0: float, y_x1: float, esp := 0.1, ondas_em_z := true) -> void:
	var a := Vector3(x0, y_x0, z0)
	var b := Vector3(x1, y_x1, z0)
	var c := Vector3(x1, y_x1, z1)
	var d := Vector3(x0, y_x0, z1)
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	if registrar:
		_reg("telhado", mat_topo, Color.WHITE, _bb([a, b, c, d, a - Vector3(0, esp, 0), c - Vector3(0, esp, 0)]), n)
		_prof += 1
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
	if registrar:
		_prof -= 1


## Telhado de uma água com a queda ao longo de Z (y_z0 em z0, y_z1 em z1). As ondas correm ao longo de Z.
func telhado_agua_z(mat_topo: Material, mat_sob: Material, x0: float, x1: float, z0: float, z1: float, y_z0: float, y_z1: float, esp := 0.1) -> void:
	var a := Vector3(x0, y_z0, z0)
	var b := Vector3(x1, y_z0, z0)
	var c := Vector3(x1, y_z1, z1)
	var d := Vector3(x0, y_z1, z1)
	var n := (b - a).cross(d - a).normalized()
	if n.y < 0.0:
		n = -n
	if registrar:
		_reg("telhado", mat_topo, Color.WHITE, _bb([a, b, c, d, a - Vector3(0, esp, 0), c - Vector3(0, esp, 0)]), n)
		_prof += 1
	quad(mat_topo, a, b, c, d, n, Vector2(1.416, 1.416))
	var e := Vector3(0, esp, 0)
	quad(mat_sob, a - e, b - e, c - e, d - e, -n, Vector2(1.0, 1.0))
	quad(mat_sob, a, b, b - e, a - e, Vector3.FORWARD, Vector2(1.0, 1.0))
	quad(mat_sob, d, c, c - e, d - e, Vector3.BACK, Vector2(1.0, 1.0))
	quad(mat_sob, a, d, d - e, a - e, Vector3.LEFT, Vector2(1.0, 1.0))
	quad(mat_sob, b, c, c - e, b - e, Vector3.RIGHT, Vector2(1.0, 1.0))
	if registrar:
		_prof -= 1


## Adiciona uma caixa de colisão (coordenadas do mundo).
func col(p0: Vector3, p1: Vector3) -> void:
	var mn := Vector3(minf(p0.x, p1.x), minf(p0.y, p1.y), minf(p0.z, p1.z))
	var mx := Vector3(maxf(p0.x, p1.x), maxf(p0.y, p1.y), maxf(p0.z, p1.z))
	if mx.x - mn.x < 0.001 or mx.y - mn.y < 0.001 or mx.z - mn.z < 0.001:
		return
	colisoes.append(AABB(mn, mx - mn))
	if registrar:
		_reg("col", null, Color.WHITE, AABB(mn, mx - mn))


## Rampa (prisma convexo) para escadas: pontos em coordenadas do mundo.
func rampa(pts: PackedVector3Array) -> void:
	convexas.append(pts)
	if registrar and not pts.is_empty():
		_reg("rampa", null, Color.WHITE, _bb(Array(pts)))


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
	if registrar:
		mi.set_meta("malha", get_instance_id())      # a varredura da árvore reconhece a instância desta Malha
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
