class_name FeixeCaca
extends RefCounted
## Marcas de VISIBILIDADE dos achados das caças dos discos (módulo 2, parte 3: "as coisas estão escondidas demais"):
##   - `criar()`: um feixe de luz vertical e macio (quad que gira só em Y, soma luz) que sobe do item e se vê de longe
##     (some além de `ALCANCE` m). Como é filho da raiz do item, só existe na época do item.
##   - `registrar()`: põe a raiz do item no grupo "caca_item" para a pista de proximidade (world/caca_proximidade.gd).
##   - `pulsar()`: respiração lenta da luz do feixe (chamada pelas animações dos níveis).

const GRUPO := "caca_item"
const ALCANCE := 24.0       # m: o feixe desaparece além disso

static var _tex: ImageTexture


## Textura do feixe: largura macia (sino) e brilho que desvanece para cima, com um pouco de pé.
static func _textura() -> ImageTexture:
	if _tex != null:
		return _tex
	var larg := 32
	var alt := 64
	var img := Image.create(larg, alt, false, Image.FORMAT_RGBA8)
	for y in alt:
		var h := float(y) / float(alt - 1)            # 0 = topo, 1 = chão
		var vertical := pow(h, 0.8) * minf(1.0, (1.0 - h) * 12.0 + 0.35)
		for x in larg:
			var u := (float(x) + 0.5) / float(larg) * 2.0 - 1.0
			var horizontal := exp(-u * u * 4.5)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(horizontal * vertical, 0.0, 1.0)))
	_tex = ImageTexture.create_from_image(img)
	return _tex


## Feixe de luz de `altura` m a partir da origem do nó pai. `cor` tinge a luz.
static func criar(altura: float, cor: Color, largura := 1.2) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.name = "Feixe"
	var q := QuadMesh.new()
	q.size = Vector2(largura, altura)
	q.center_offset = Vector3(0.0, altura * 0.5, 0.0)
	m.mesh = q
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.albedo_texture = _textura()
	mat.albedo_color = Color(cor.r, cor.g, cor.b, 0.95)
	mat.disable_receive_shadows = true
	m.material_override = mat
	m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	m.visibility_range_end = ALCANCE
	return m


## Põe o item no grupo da pista de proximidade. `disco` = chave de GameState.CACAS; `id` = id do achado.
static func registrar(raiz: Node3D, disco: int, id: String) -> void:
	raiz.add_to_group(GRUPO)
	raiz.set_meta("caca_disco", disco)
	raiz.set_meta("caca_id", id)


## Respiração da luz do feixe (alfa 0,55..0,95) e do brilho (balanço leve). `t` = tempo em s.
static func pulsar(raiz: Node3D, t: float) -> void:
	var f := raiz.get_node_or_null("Feixe") as MeshInstance3D
	if f != null and f.material_override is StandardMaterial3D:
		var mat := f.material_override as StandardMaterial3D
		mat.albedo_color.a = 0.75 + 0.2 * sin(t * 2.0 + float(raiz.get_instance_id() % 7))
