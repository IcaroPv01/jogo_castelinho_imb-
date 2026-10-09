class_name Pegada
extends RefCounted
## Pegada molhada de pé de criança (calcanhar + planta + 5 dedinhos), uma textura só, gerada em código.
## Usada nas pegadas do Tito (Braço Morto) e nas da Sala do Pescador (visita 4). Aspecto de água: escurece o chão,
## cor azul-acinzentada escura (nunca avermelhada) e um brilho fraco. Os pés alternam (esquerdo/direito = espelho).

const W := 64
const H := 128
const COR_AGUA := Color(0.05, 0.085, 0.12)

static var _tex := {}     # esquerdo(bool) -> ImageTexture
static var _mats := {}    # chave -> StandardMaterial3D


## Textura RGBA: rgb branco, alfa = pegada. Ponta dos dedos para cima (u = x, v = -z do plano).
static func textura(esquerdo: bool) -> Texture2D:
	if _tex.has(esquerdo):
		return _tex[esquerdo]
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	# elipses (cx, cy, rx, ry): calcanhar, ponte fina, antepé e os cinco dedos (do maior para o menor)
	var formas := [
		[31.0, 108.0, 11.5, 15.0],   # calcanhar
		[34.0, 88.0, 7.0, 13.0],     # lateral do pé (o arco fica vazado do lado de dentro)
		[32.0, 66.0, 16.0, 20.0],    # antepé (planta)
		[41.0, 36.0, 7.5, 8.5],      # dedão
		[28.0, 30.0, 5.2, 6.4],
		[20.0, 35.0, 4.7, 5.8],
		[14.0, 43.0, 4.2, 5.2],
		[10.5, 52.0, 3.6, 4.4],      # dedinho
	]
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	for y in H:
		for x in W:
			var a := 0.0
			for f in formas:
				var dx: float = (float(x) - f[0]) / f[2]
				var dy: float = (float(y) - f[1]) / f[3]
				var d := sqrt(dx * dx + dy * dy)
				a = maxf(a, clampf((1.0 - d) / 0.22, 0.0, 1.0))
			# o arco (lado de dentro, à direita): corta a planta entre o calcanhar e o antepé
			var arco := Vector2((float(x) - 52.0) / 17.0, (float(y) - 90.0) / 14.0).length()
			a *= clampf((arco - 0.55) / 0.35, 0.0, 1.0) if arco < 0.9 else 1.0
			# umidade irregular: a borda e o miolo falham de leve, como água que já escorre
			var n := fposmod(sin(float(x) * 12.9898 + float(y) * 78.233) * 43758.5453, 1.0)
			a *= 0.9 + 0.1 * n
			img.set_pixel(x, y, Color(1, 1, 1, a))
	if not esquerdo:     # o desenho base tem o dedão à direita = pé esquerdo
		img.flip_x()
	img.generate_mipmaps()
	var t := ImageTexture.create_from_image(img)
	_tex[esquerdo] = t
	return t


static func material(esquerdo: bool, forca := 1.0) -> StandardMaterial3D:
	var chave := "%s_%.2f" % [esquerdo, forca]
	if _mats.has(chave):
		return _mats[chave]
	var m := StandardMaterial3D.new()
	m.albedo_texture = textura(esquerdo)
	m.albedo_color = Color(COR_AGUA.r, COR_AGUA.g, COR_AGUA.b, clampf(0.78 * forca, 0.0, 1.0))
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.08          # molhado: liso, pega o brilho das luzes
	m.metallic = 0.0
	m.metallic_specular = 0.9
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true     # um fio de azul frio, para a marca ser lida mesmo no escuro
	m.emission = Color(0.12, 0.2, 0.3)
	m.emission_energy_multiplier = 0.35 * forca
	_mats[chave] = m
	return m


## Uma pegada deitada no chão em `pos` (mundo/local do pai), com a ponta dos dedos para onde `dir` (plano XZ) aponta.
## `comp` = comprimento do pé em metros. `forca` > 1 = mais contraste.
static func criar(pos: Vector3, dir: Vector3, esquerdo: bool, comp := 0.22, forca := 1.0) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(comp * float(W) / float(H) * 1.0, comp)
	mi.mesh = pl
	mi.material_override = material(esquerdo, forca)
	mi.position = pos
	mi.rotation.y = atan2(-dir.x, -dir.z)     # -Z local (ponta dos dedos) aponta para `dir`
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi
