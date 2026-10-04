class_name Ato2Pecas
extends RefCounted
## Peças procedurais do Ato II e da Barra: texturas geradas por código (pedra avermelhada do
## Castelinho com juntas claras grossas, piso de lajes irregulares, areia, madeira, reboco, telha),
## malhas próprias (arco abatido, prisma triangular, terreno de dunas) e ajudantes de colisão.
## Tudo estático e com cache. Texturas pequenas (≤128 px), filtro nearest: visual PSX/Flash.

const CAMINHO_PEDRA_CASTELINHO := "res://assets/textures/pedra_castelinho.png"

static var _tex := {}
static var _ruido_dunas: FastNoiseLite


# ============================================================================ texturas
static func _img_para_tex(img: Image) -> ImageTexture:
	return ImageTexture.create_from_image(img)


## Textura gerada pelo agente do castelinho (assets/textures/<nome>.png), se já estiver importada.
static func externa(nome: String) -> Texture2D:
	var caminho := "res://assets/textures/%s.png" % nome
	if FileAccess.file_exists(caminho + ".import"):
		return load(caminho) as Texture2D
	return null


## Pedra do Castelinho: blocos ferrugem/salmão (#A8583F a #C9806A) com juntas claras grossas.
## Usa assets/textures/pedra_castelinho.png se o agente do castelinho já a tiver gerado.
static func tex_pedra() -> Texture2D:
	if _tex.has("pedra"):
		return _tex["pedra"]
	var t: Texture2D = null
	if FileAccess.file_exists(CAMINHO_PEDRA_CASTELINHO + ".import"):
		t = load(CAMINHO_PEDRA_CASTELINHO) as Texture2D
	if t == null:
		t = _gerar_pedra()
	_tex["pedra"] = t
	return t


static func _gerar_pedra() -> Texture2D:
	const N := 120
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1950
	var junta := Color(0.74, 0.70, 0.62)
	img.fill(junta)
	var c1 := Color("A8583F")
	var c2 := Color("C9806A")
	var altura := 12
	for fiada in N / altura:
		var y0 := fiada * altura
		# larguras variadas que somam N (textura sem emenda)
		var larguras: Array[int] = []
		var soma := 0
		while soma < N:
			var w := rng.randi_range(22, 34)
			if N - soma - w < 20:
				w = N - soma
			larguras.append(w)
			soma += w
		var x0 := -rng.randi_range(0, 10) if fiada % 2 == 1 else 0
		for w in larguras:
			var base := c1.lerp(c2, rng.randf())
			base = base.darkened(rng.randf_range(0.0, 0.12))
			for y in range(y0 + 2, y0 + altura):
				for x in range(x0 + 2, x0 + w):
					var luz := 1.0
					if y < y0 + 4:
						luz += 0.10
					elif y > y0 + altura - 3:
						luz -= 0.12
					var r := rng.randf_range(-0.045, 0.045)
					var px := Color(base.r * luz + r, base.g * luz + r, base.b * luz + r)
					img.set_pixel(posmod(x, N), y, px)
			x0 += w
	return _img_para_tex(img)


## Lajes irregulares escuras (piso interno de pedra "cacos"), Voronoi com emenda.
static func tex_piso_pedra() -> Texture2D:
	if _tex.has("piso"):
		return _tex["piso"]
	const N := 96
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	var pts: Array[Vector2] = []
	var cores: Array[Color] = []
	for i in 18:
		pts.append(Vector2(rng.randf() * N, rng.randf() * N))
		var v := rng.randf_range(0.22, 0.38)
		cores.append(Color(v, v * 0.97, v * 0.92))
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var d1 := 1e9
			var d2 := 1e9
			var i1 := 0
			for i in pts.size():
				var dx := absf(x - pts[i].x)
				var dy := absf(y - pts[i].y)
				dx = minf(dx, N - dx)
				dy = minf(dy, N - dy)
				var d := dx * dx + dy * dy
				if d < d1:
					d2 = d1
					d1 = d
					i1 = i
				elif d < d2:
					d2 = d
			var borda := sqrt(d2) - sqrt(d1)
			var cor := cores[i1]
			if borda < 2.2:
				cor = Color(0.10, 0.09, 0.08)
			else:
				var r := rng.randf_range(-0.03, 0.03)
				cor = Color(cor.r + r, cor.g + r, cor.b + r)
			img.set_pixel(x, y, cor)
	_tex["piso"] = _img_para_tex(img)
	return _tex["piso"]


## Areia de duna: ruído suave + marcas de vento.
static func tex_areia() -> Texture2D:
	if _tex.has("areia"):
		return _tex["areia"]
	const N := 128
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.03
	n.seed = 5
	var base := n.get_seamless_image(N, N)
	var rng := RandomNumberGenerator.new()
	rng.seed = 12
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var v := base.get_pixel(x, y).r
			var onda := sin((x + v * 30.0) * TAU / 32.0) * 0.035
			var s := 0.84 + (v - 0.5) * 0.25 + onda + rng.randf_range(-0.03, 0.03)
			img.set_pixel(x, y, Color(0.80 * s, 0.73 * s, 0.58 * s))
	_tex["areia"] = _img_para_tex(img)
	return _tex["areia"]


## Madeira escura com veios verticais (portas, vigas, estacas, assoalho).
static func tex_madeira() -> Texture2D:
	if _tex.has("madeira"):
		return _tex["madeira"]
	const N := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 33
	var col: Array[float] = []
	for x in N:
		col.append(rng.randf_range(0.75, 1.15))
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var v := col[x] * (0.92 + 0.08 * sin(y * 0.4 + x * 0.9)) + rng.randf_range(-0.04, 0.04)
			if x % 16 == 0:
				v *= 0.55   # junta entre tábuas
			img.set_pixel(x, y, Color(0.30 * v, 0.19 * v, 0.11 * v))
	_tex["madeira"] = _img_para_tex(img)
	return _tex["madeira"]


## Reboco bege manchado (paredes do hall do museu).
static func tex_reboco() -> Texture2D:
	if _tex.has("reboco"):
		return _tex["reboco"]
	const N := 96
	var n := FastNoiseLite.new()
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = 0.05
	n.seed = 9
	var base := n.get_seamless_image(N, N)
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var v := 0.88 + (base.get_pixel(x, y).r - 0.5) * 0.28
			img.set_pixel(x, y, Color(0.87 * v, 0.80 * v, 0.66 * v))
	_tex["reboco"] = _img_para_tex(img)
	return _tex["reboco"]


## Telha ondulada cinza (fibrocimento).
static func tex_telha() -> Texture2D:
	if _tex.has("telha"):
		return _tex["telha"]
	const N := 64
	var rng := RandomNumberGenerator.new()
	rng.seed = 41
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var onda := 0.78 + 0.22 * sin(x * TAU / 16.0)
			var mancha := rng.randf_range(-0.05, 0.05)
			img.set_pixel(x, y, Color(0.50 * onda + mancha, 0.52 * onda + mancha, 0.50 * onda + mancha))
	_tex["telha"] = _img_para_tex(img)
	return _tex["telha"]


# ============================================================================ malhas
static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> void:
	# O Godot considera frente a face em sentido horário. Corrige a ordem para olhar para `n`.
	if (b - a).cross(c - a).dot(n) > 0.0:
		var t := b
		b = c
		c = t
	for v in [a, b, c]:
		st.set_normal(n)
		st.set_uv(Vector2(v.x, v.y))
		st.add_vertex(v)


static func _quad(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, n: Vector3) -> void:
	_tri(st, a, b, c, n)
	_tri(st, a, c, d, n)


## Painel de parede com vão em arco abatido (parte ACIMA do vão): o vão tem `largura`, a linha
## de apoio fica em `h_apoio`, a flecha do arco é `flecha` e o painel sobe até `h_total`.
## Centrado em x (vão entre -largura/2 e +largura/2) e em z (espessura `prof`).
## Sem colisão (fica acima da cabeça). Material: use um com triplanar (Construtor.material).
static func arco_abatido(largura: float, h_apoio: float, flecha: float, h_total: float, prof: float, seg := 10) -> ArrayMesh:
	var raio := (largura * largura / 4.0 + flecha * flecha) / (2.0 * flecha)
	var cy := h_apoio + flecha - raio
	var xs: Array[float] = []
	var ys: Array[float] = []
	for i in seg + 1:
		var x := -largura * 0.5 + largura * float(i) / seg
		xs.append(x)
		ys.append(cy + sqrt(maxf(raio * raio - x * x, 0.0)))
	var zf := prof * 0.5
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		# faces frontal e traseira (entre a curva e o topo)
		_quad(st, Vector3(xs[i], ys[i], zf), Vector3(xs[i + 1], ys[i + 1], zf), Vector3(xs[i + 1], h_total, zf), Vector3(xs[i], h_total, zf), Vector3.BACK)
		_quad(st, Vector3(xs[i], ys[i], -zf), Vector3(xs[i + 1], ys[i + 1], -zf), Vector3(xs[i + 1], h_total, -zf), Vector3(xs[i], h_total, -zf), Vector3.FORWARD)
		# intradorso (face de baixo do arco)
		var xm := (xs[i] + xs[i + 1]) * 0.5
		var ym := (ys[i] + ys[i + 1]) * 0.5
		var nint := Vector3(-(xm), -(ym - cy), 0.0).normalized()
		_quad(st, Vector3(xs[i], ys[i], zf), Vector3(xs[i + 1], ys[i + 1], zf), Vector3(xs[i + 1], ys[i + 1], -zf), Vector3(xs[i], ys[i], -zf), nint)
	# topo e laterais
	_quad(st, Vector3(-largura * 0.5, h_total, zf), Vector3(largura * 0.5, h_total, zf), Vector3(largura * 0.5, h_total, -zf), Vector3(-largura * 0.5, h_total, -zf), Vector3.UP)
	return st.commit()


## Prisma triangular (oco para os lados): base no plano z, ponta para cima. Para as empenas.
## Base `larg` (em z), altura `alt` (em y), espessura `esp` (em x). Origem no centro da base.
static func empena(larg: float, alt: float, esp: float) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var h := esp * 0.5
	var a := Vector3(0, 0, -larg * 0.5)
	var b := Vector3(0, 0, larg * 0.5)
	var c := Vector3(0, alt, 0)
	for lado in [-1.0, 1.0]:
		var d := Vector3(h * lado, 0, 0)
		_tri(st, a + d, b + d, c + d, Vector3(lado, 0, 0))
	# duas águas (laterais inclinadas)
	var nl := Vector3(0, larg * 0.5, -alt).normalized()
	var nr := Vector3(0, larg * 0.5, alt).normalized()
	_quad(st, a + Vector3(-h, 0, 0), a + Vector3(h, 0, 0), c + Vector3(h, 0, 0), c + Vector3(-h, 0, 0), nl)
	_quad(st, b + Vector3(-h, 0, 0), b + Vector3(h, 0, 0), c + Vector3(h, 0, 0), c + Vector3(-h, 0, 0), nr)
	return st.commit()


# ============================================================================ terreno de dunas
## Altura do terreno em (x, z). Plano na faixa central (corredor do jogador), dunas nas laterais
## e uma duna alta em (22, -40) onde a Figura Branca fica parada.
static func altura_duna(x: float, z: float) -> float:
	if _ruido_dunas == null:
		_ruido_dunas = FastNoiseLite.new()
		_ruido_dunas.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		_ruido_dunas.seed = 1950
		_ruido_dunas.frequency = 0.022
	var cristas := 1.0 - absf(_ruido_dunas.get_noise_2d(x, z))        # cristas arredondadas
	var h := cristas * cristas * 7.0 + _ruido_dunas.get_noise_2d(x * 3.1, z * 3.1) * 0.5
	var plano := 1.0 - smoothstep(13.0, 30.0, absf(x))                # corredor central plano
	var longe := smoothstep(-14.0, -34.0, z)                           # perto do hall também é plano
	var h_final := h * (1.0 - plano) * longe
	var d2 := (x - 22.0) * (x - 22.0) + (z + 40.0) * (z + 40.0)
	h_final += 5.5 * exp(-d2 / (2.0 * 8.0 * 8.0))                      # a duna da figura
	return -0.03 + h_final


static func malha_dunas(x0: float, x1: float, z0: float, z1: float, passo: float) -> ArrayMesh:
	var nx := int((x1 - x0) / passo) + 1
	var nz := int((z1 - z0) / passo) + 1
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in nz:
		for i in nx:
			var x := x0 + i * passo
			var z := z0 + j * passo
			st.set_uv(Vector2(x * 0.1, z * 0.1))
			st.add_vertex(Vector3(x, altura_duna(x, z), z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			# sentido horário visto de cima
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	return st.commit()


# ============================================================================ colisão e instâncias
## Colisão invisível (paredes de contenção).
static func colisao_invisivel(pai: Node3D, tam: Vector3, pos: Vector3) -> StaticBody3D:
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	sb.add_child(cs)
	sb.position = pos
	pai.add_child(sb)
	return sb


## Malha qualquer com colisão por trimesh (terreno).
static func com_colisao_trimesh(pai: Node3D, malha: Mesh, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	pai.add_child(mi)
	var sb := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = malha.create_trimesh_shape()
	sb.add_child(cs)
	mi.add_child(sb)
	return mi


## MeshInstance3D simples (sem colisão).
static func malha(pai: Node3D, m: Mesh, pos: Vector3, mat: Material, rot_graus := Vector3.ZERO, escala := Vector3.ONE) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = mat
	mi.position = pos
	mi.rotation_degrees = rot_graus
	mi.scale = escala
	pai.add_child(mi)
	return mi


## Material com textura triplanar em coordenadas do mundo (não precisa de UV). `escala` = repetições
## por metro. Cache por nome (o Construtor.material não distingue texturas geradas por código).
static func mat_tri(nome: String, cor: Color, tex: Texture2D, escala := 1.0, rugosidade := 0.95) -> StandardMaterial3D:
	var chave := "tri|%s|%s|%s" % [nome, cor.to_html(), escala]
	if _tex.has(chave):
		return _tex[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	m.albedo_texture = tex
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(escala, escala, escala)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_tex[chave] = m
	return m


## Material sem sombreamento (silhuetas, painéis que brilham, vidros acesos).
static func mat_cor(cor: Color, sem_luz := false, emissao := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = 1.0
	if sem_luz:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	if emissao > 0.0:
		m.emission_enabled = true
		m.emission = cor
		m.emission_energy_multiplier = emissao
	if cor.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return m
