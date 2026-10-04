class_name Construtor
extends RefCounted
## Ajudantes para montar geometria por código (caixas com colisão, materiais, rótulos).
## Usado pelos níveis e pelo gerador do Castelinho.

static var _cache_mat := {}


static func material(cor: Color, rugosidade := 0.9, textura: Texture2D = null, escala_uv := Vector3.ONE) -> StandardMaterial3D:
	var chave := "%s|%s|%s|%s" % [cor.to_html(), rugosidade, textura.resource_path if textura else "", escala_uv]
	if _cache_mat.has(chave):
		return _cache_mat[chave]
	var m := StandardMaterial3D.new()
	m.albedo_color = cor
	m.roughness = rugosidade
	if textura:
		m.albedo_texture = textura
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = escala_uv
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	_cache_mat[chave] = m
	return m


## Caixa sólida (visual + colisão). `pos` é o centro da caixa.
static func caixa(pai: Node3D, tam: Vector3, pos: Vector3, mat: Material, colisao := true, nome := "") -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = tam
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	if nome != "":
		mi.name = nome
	pai.add_child(mi)
	if colisao:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = tam
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi


## Texto 3D (placas, painéis).
static func rotulo(pai: Node3D, texto: String, pos: Vector3, tamanho := 32, cor := Color.BLACK) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = tamanho
	l.modulate = cor
	l.outline_size = 0
	l.pixel_size = 0.004
	l.position = pos
	l.double_sided = false
	pai.add_child(l)
	return l


static func luz(pai: Node3D, pos: Vector3, cor := Color(1, 0.9, 0.75), energia := 1.0, alcance := 8.0) -> OmniLight3D:
	var o := OmniLight3D.new()
	o.position = pos
	o.light_color = cor
	o.light_energy = energia
	o.omni_range = alcance
	pai.add_child(o)
	return o
