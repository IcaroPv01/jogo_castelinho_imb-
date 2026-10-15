class_name Pedalinho
extends RefCounted
## Pedalinho em forma de cisne (o do Braço Morto, Módulo 13). Só o modelo, montado com malhas simples.
## Origem = centro do casco na linha d'água; a frente (o cisne) é o -Z local. `criar` devolve o nó raiz:
##   "Casco"  o corpo, "Cisne" pescoço, cabeça e bico, "Pedais" (gira com `pedalar`), "Esteira" o anel de marola.
## O jogador "dirige" levando este nó junto com ele (world/niveis/braco_salvar.gd).

const ALTURA_CONVES := 0.52      # y do convés (onde os pés ficam) sobre a linha d'água do nó


static func criar(cor_casco: Color, cor_cisne: Color, cor_detalhe: Color, com_balde := false) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Pedalinho"
	var casco_mat := Construtor.material(cor_casco, 0.7)
	var cisne_mat := Construtor.material(cor_cisne, 0.6)
	var det_mat := Construtor.material(cor_detalhe, 0.8)
	var bico_mat := Construtor.material(Color(0.95, 0.55, 0.12), 0.7)
	var escuro := Construtor.material(Color(0.07, 0.07, 0.09), 0.9)
	var casco := Node3D.new()
	casco.name = "Casco"
	raiz.add_child(casco)
	# corpo: elipsoide achatado (esfera esticada) e a "borda" de outra cor em volta
	_malha(casco, _esfera(1.0, 12, 6), Vector3(0, 0.22, 0), casco_mat, Vector3(0.78, 0.30, 1.4))
	_malha(casco, _esfera(1.0, 12, 4), Vector3(0, 0.40, 0), det_mat, Vector3(0.80, 0.10, 1.42))
	# banco corrido e o espaço dos pés (atrás e na frente do jogador)
	_malha(casco, _caixa(Vector3(1.0, 0.1, 0.34)), Vector3(0, 0.62, 0.62), det_mat)
	_malha(casco, _caixa(Vector3(0.10, 0.36, 0.30)), Vector3(-0.42, 0.40, 0.62), det_mat)
	_malha(casco, _caixa(Vector3(0.10, 0.36, 0.30)), Vector3(0.42, 0.40, 0.62), det_mat)
	# o cisne: pescoço curvo para a frente, cabeça, bico e olhos; cauda levantada atrás
	var cisne := Node3D.new()
	cisne.name = "Cisne"
	raiz.add_child(cisne)
	_malha(cisne, _capsula(0.125, 0.62), Vector3(0, 0.62, -1.08), cisne_mat, Vector3.ONE, Vector3(-18, 0, 0))
	_malha(cisne, _capsula(0.10, 0.46), Vector3(0, 0.98, -1.30), cisne_mat, Vector3.ONE, Vector3(-38, 0, 0))
	_malha(cisne, _esfera(0.125, 8, 4), Vector3(0, 1.17, -1.46), cisne_mat)
	_malha(cisne, _caixa(Vector3(0.08, 0.05, 0.26)), Vector3(0, 1.12, -1.68), bico_mat)
	for lado in [-1.0, 1.0]:
		_malha(cisne, _esfera(0.022, 5, 3), Vector3(lado * 0.1, 1.2, -1.55), escuro)
	_malha(cisne, _caixa(Vector3(0.5, 0.06, 0.5)), Vector3(0, 0.62, 1.30), cisne_mat, Vector3.ONE, Vector3(28, 0, 0))
	# pedais: dois pedais de cada lado do centro, dentro do espaço dos pés (giram)
	var pedais := Node3D.new()
	pedais.name = "Pedais"
	pedais.position = Vector3(0, 0.56, -0.28)
	raiz.add_child(pedais)
	for lado in [-1.0, 1.0]:
		_malha(pedais, _caixa(Vector3(0.14, 0.03, 0.18)), Vector3(lado * 0.22, 0.0, lado * 0.12), escuro)
	_malha(raiz, _caixa(Vector3(0.05, 0.28, 0.05)), Vector3(0, 0.66, -0.28), det_mat)
	if com_balde:
		# o balde vermelho do Tito, esquecido no banco
		var cil := CylinderMesh.new()
		cil.top_radius = 0.13
		cil.bottom_radius = 0.1
		cil.height = 0.22
		cil.radial_segments = 8
		cil.rings = 1
		_malha(raiz, cil, Vector3(0.34, 0.78, 0.62), Construtor.material(Color(0.9, 0.12, 0.08), 0.8))
	raiz.add_child(esteira())
	return raiz


## Gira os pedais (rad por quadro de pedalada).
static func pedalar(pedalinho: Node3D, angulo: float) -> void:
	var p := pedalinho.get_node_or_null("Pedais") as Node3D
	if p:
		p.rotation.x = angulo


## Anel de marola na linha d'água em volta do casco (quad aditivo, 1 draw).
static func esteira() -> MeshInstance3D:
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.55, 0.78, 1.0])
	g.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 96
	t.height = 96
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_texture = t
	mat.albedo_color = Color(0.6, 0.72, 0.9, 0.5)
	mat.render_priority = 2
	var pl := PlaneMesh.new()
	pl.size = Vector2(4.6, 5.6)
	var mi := MeshInstance3D.new()
	mi.name = "Esteira"
	mi.mesh = pl
	mi.material_override = mat
	mi.position = Vector3(0, 0.03, 0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi


static func _malha(pai: Node3D, malha: Mesh, pos: Vector3, mat: Material, escala := Vector3.ONE, rot_graus := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = malha
	mi.material_override = mat
	mi.position = pos
	mi.scale = escala
	mi.rotation_degrees = rot_graus
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pai.add_child(mi)
	return mi


static func _esfera(r: float, seg: int, aneis: int) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = seg
	s.rings = aneis
	return s


static func _capsula(r: float, h: float) -> CapsuleMesh:
	var c := CapsuleMesh.new()
	c.radius = r
	c.height = h
	c.radial_segments = 8
	c.rings = 2
	return c


static func _caixa(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b
