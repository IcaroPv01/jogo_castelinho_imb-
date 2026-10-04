class_name SombrasChao
extends RefCounted
## Sombras "pintadas" no chão (sem sombra dinâmica: no renderizador Compatibility uma luz com sombra redesenha a
## cena inteira, caro demais para a web). Para cada época, uma imagem pequena (L8, ~25 cm por pixel) recebe:
##   1. oclusão no pé de cada volume (halo escuro, vale também em dia nublado);
##   2. a sombra projetada de cada volume pelo Sol da época (varredura da planta ao longo da direção da luz);
##   3. a sombra das copas dos pinheiros;
##   4. branco por dentro das plantas (o piso interno não recebe a sombra de fora).
## A imagem cobre o lote e arredores num único quadrilátero com mistura MULTIPLICAR, sem luz e sem névoa:
## 1 draw call e 2 triângulos. Pixels visíveis (filtro nearest) combinam com o resto do mundo.
##
## Uso: var s := SombrasChao.new(); s.construir(raiz, volumes_por_epoca, arvores_por_epoca, sois, brancos); s.trocar(e)
##   volumes: Array de [x0, x1, z0, z1, altura]   arvores: Array de [pos, raio, y_base_copa, y_topo]
##   sois: época -> {"dir": Vector3 (sentido da luz) ou Vector3.ZERO (nublado), "sombra": 0..1, "ao": 0..1}

const X0 := -62.0
const Z0 := -70.0
const TAM := 90.0
const RES := 360          # 25 cm por pixel
const Y_PLANO := 0.05

var no: MeshInstance3D
var _mat: StandardMaterial3D
var _texturas := {}


func construir(raiz: Node3D, volumes: Dictionary, arvores: Dictionary, sois: Dictionary, brancos: Dictionary) -> void:
	for e in sois.keys():
		var img := _pintar(volumes.get(e, []), arvores.get(e, []), sois[e], brancos.get(e, []))
		img.convert(Image.FORMAT_RGB8)       # L8 não tem swizzle no WebGL2: a imagem vira RGB antes de subir
		_texturas[e] = ImageTexture.create_from_image(img)
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_MUL
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	_mat.disable_fog = true
	_mat.disable_receive_shadows = true
	var m := Malha.new()
	var a := Vector3(X0, Y_PLANO, Z0)
	var b := Vector3(X0 + TAM, Y_PLANO, Z0)
	var c := Vector3(X0 + TAM, Y_PLANO, Z0 + TAM)
	var d := Vector3(X0, Y_PLANO, Z0 + TAM)
	m.quad_uv(_mat, a, b, c, d, Vector3.UP, Vector2(0, 0), Vector2(1, 0), Vector2(1, 1), Vector2(0, 1))
	no = m.construir_instancia(raiz, "SombrasChao", 1)
	no.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


## Mostra a imagem da época `e` (some se a época não tiver sombra pintada).
func trocar(e: int) -> void:
	if no == null:
		return
	no.visible = _texturas.has(e)
	if no.visible:
		_mat.albedo_texture = _texturas[e]


static func _px(x: float) -> float:
	return (x - X0) / TAM * RES


static func _pz(z: float) -> float:
	return (z - Z0) / TAM * RES


static func _ret(img: Image, x0: float, x1: float, z0: float, z1: float, v: float) -> void:
	var a := Vector2i(int(floor(_px(x0))), int(floor(_pz(z0))))
	var b := Vector2i(int(ceil(_px(x1))), int(ceil(_pz(z1))))
	a = a.clamp(Vector2i.ZERO, Vector2i(RES, RES))
	b = b.clamp(Vector2i.ZERO, Vector2i(RES, RES))
	if b.x <= a.x or b.y <= a.y:
		return
	img.fill_rect(Rect2i(a, b - a), Color(v, v, v))


## Escurece (mínimo) um disco elíptico: copas de árvore.
static func _disco(img: Image, c: Vector2, rx: float, rz: float, v: float) -> void:
	var cx := _px(c.x)
	var cz := _pz(c.y)
	var rpx := rx / TAM * RES
	var rpz := rz / TAM * RES
	for iy in range(int(cz - rpz), int(cz + rpz) + 1):
		if iy < 0 or iy >= RES:
			continue
		for ix in range(int(cx - rpx), int(cx + rpx) + 1):
			if ix < 0 or ix >= RES:
				continue
			var dx := (ix + 0.5 - cx) / rpx
			var dz := (iy + 0.5 - cz) / rpz
			if dx * dx + dz * dz <= 1.0:
				var atual := img.get_pixel(ix, iy).r
				if v < atual:
					img.set_pixel(ix, iy, Color(v, v, v))


func _pintar(volumes: Array, arvores: Array, sol: Dictionary, brancos: Array) -> Image:
	var img := Image.create(RES, RES, false, Image.FORMAT_L8)
	img.fill(Color.WHITE)
	var d: Vector3 = sol.get("dir", Vector3.ZERO)
	var sombra: float = sol.get("sombra", 0.62)
	var ao: float = sol.get("ao", 0.8)
	var pix := TAM / RES
	# 1. halo de oclusão (duas faixas: larga e clara, estreita e escura)
	for v in volumes:
		_ret(img, v[0] - 0.9, v[1] + 0.9, v[2] - 0.9, v[3] + 0.9, lerpf(ao, 1.0, 0.55))
	for v in volumes:
		_ret(img, v[0] - 0.4, v[1] + 0.4, v[2] - 0.4, v[3] + 0.4, ao)
	# 2. sombra projetada: a planta varrida ao longo da luz até a altura do volume
	if d != Vector3.ZERO and d.y < -0.05:
		var desl := Vector2(d.x, d.z) / -d.y          # metros de deslocamento por metro de altura
		for v in volumes:
			var total: Vector2 = desl * float(v[4])
			var passos := int(ceil(total.length() / (pix * 0.8))) + 1
			for k in passos + 1:
				var o := total * float(k) / float(passos)
				_ret(img, v[0] + o.x, v[1] + o.x, v[2] + o.y, v[3] + o.y, sombra)
		# 3. copas dos pinheiros (mais claras: a copa deixa passar luz) e o tronco
		var sombra_copa := lerpf(sombra, 1.0, 0.35)
		for a in arvores:
			var p: Vector3 = a[0]
			var meio := (float(a[2]) + float(a[3])) * 0.5
			var c := Vector2(p.x, p.z) + desl * meio
			var along := desl.length() * (float(a[3]) - float(a[2])) * 0.5
			_disco(img, c, float(a[1]) + along * absf(desl.normalized().x) * 0.6, float(a[1]) + along * absf(desl.normalized().y) * 0.6, sombra_copa)
			var base := Vector2(p.x, p.z)
			var topo_tronco := base + desl * float(a[2])
			var n := int(ceil((topo_tronco - base).length() / pix)) + 1
			for k in n + 1:
				var q := base.lerp(topo_tronco, float(k) / float(n))
				_ret(img, q.x - 0.12, q.x + 0.12, q.y - 0.12, q.y + 0.12, lerpf(sombra, 1.0, 0.25))
	else:
		# nublado: só uma mancha suave sob cada copa
		for a in arvores:
			var p: Vector3 = a[0]
			_disco(img, Vector2(p.x, p.z), float(a[1]) * 1.1, float(a[1]) * 1.1, lerpf(ao, 1.0, 0.4))
	# 4. por dentro das plantas, branco (piso interno não recebe a sombra de fora)
	for v in brancos:
		_ret(img, v[0], v[1], v[2], v[3], 1.0)
	return img
