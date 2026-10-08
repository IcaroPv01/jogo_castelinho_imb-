extends Node
## Varredura EXTRA de shaders no navegador (WebGL2). Complementa tests/web_cenas.gd:
##  1) para cada nível/visita/época, acha os nós VISÍVEIS que usam um shader de shaders/*.gdshader e põe uma câmera
##     olhando para eles (o shader só compila quando é desenhado);
##  2) força o shader de pós-processamento com todos os efeitos ligados (corrupção, pulso, Visor, atenção);
##  3) cria um material psx_material (Efeitos.material_psx) numa malha na frente da câmera (não é usado pelo jogo).
## Imprime VARRE_OK / VARRE_AVISO e VARRE_FIM_EXTRA no console.

const NIVEIS := [
	# [cena, visita, flags]
	["res://world/niveis/castelinho.tscn", 1, ["tem_visor"]],
	["res://world/niveis/castelinho.tscn", 2, ["tem_visor"]],
	["res://world/niveis/castelinho.tscn", 3, ["tem_visor"]],
	["res://world/niveis/castelinho.tscn", 4, ["tem_visor"]],
	["res://world/niveis/porao.tscn", 5, []],
	["res://world/niveis/braco_morto.tscn", 5, []],
	["res://world/niveis/ato2.tscn", 3, []],
	["res://world/niveis/barra.tscn", 2, []],
]
const EPOCAS := [0, 1, 2, 3, 4]
const MAX_POR_SHADER := 2


func _ready() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var gs = get_node("/root/GameState")
	var main = load("res://scenes/main/main.tscn").instantiate()
	add_child(main)
	await get_tree().process_frame
	if main.tela_titulo:
		main.tela_titulo.queue_free()
	for n in NIVEIS:
		for e in EPOCAS:
			gs.novo_jogo()
			gs.visita = n[1]
			for f in n[2]:
				gs.set_flag(f)
			await main.carregar_mundo(n[0], "Spawn")
			gs.trocar_epoca(e)
			var nivel: Node = main.mundo.get_child(0)
			await _quadros(20)
			var achados: Dictionary = {}
			_coletar(nivel, achados)
			for nome in achados.keys():
				var lista: Array = achados[nome]
				print("VARRE_INFO ", nome, " ", n[0].get_file(), " v", n[1], " ep", e, " n=", lista.size())
				for i in mini(MAX_POR_SHADER, lista.size()):
					await _olhar(nivel, lista[i])
	await _forcar_pos_e_psx(main, gs)
	print("VARRE_FIM_EXTRA")


## Acha nós visíveis cujo material é ShaderMaterial (override, superfície de MeshInstance3D ou MultiMesh).
func _coletar(no: Node, achados: Dictionary) -> void:
	if no is GeometryInstance3D and (no as GeometryInstance3D).is_visible_in_tree():
		for mat in _materiais(no as GeometryInstance3D):
			if mat is ShaderMaterial and (mat as ShaderMaterial).shader != null:
				var nome: String = (mat as ShaderMaterial).shader.resource_path.get_file()
				if not achados.has(nome):
					achados[nome] = []
				(achados[nome] as Array).append(no)
	for c in no.get_children():
		_coletar(c, achados)


func _materiais(g: GeometryInstance3D) -> Array:
	var r: Array = []
	if g.material_override:
		r.append(g.material_override)
	if g is MeshInstance3D and (g as MeshInstance3D).mesh:
		var malha: Mesh = (g as MeshInstance3D).mesh
		for i in malha.get_surface_count():
			r.append((g as MeshInstance3D).get_active_material(i))
	if g is MultiMeshInstance3D and (g as MultiMeshInstance3D).multimesh and (g as MultiMeshInstance3D).multimesh.mesh:
		var mm: Mesh = (g as MultiMeshInstance3D).multimesh.mesh
		for i in mm.get_surface_count():
			r.append(mm.surface_get_material(i))
	return r


## Põe uma câmera olhando para o nó (de um lado, um pouco de cima) e espera alguns quadros.
func _olhar(nivel: Node, no: GeometryInstance3D) -> void:
	var aabb: AABB = no.get_aabb()
	var c: Vector3 = no.global_transform * aabb.get_center()
	var raio: float = maxf(aabb.get_longest_axis_size() * 0.5, 0.5)
	var cam := Camera3D.new()
	cam.fov = 60.0
	nivel.add_child(cam)
	cam.global_position = c + Vector3(0.0, 0.6, 1.0).normalized() * (raio * 1.5 + 2.0)
	cam.look_at(c, Vector3.UP)
	cam.current = true
	await _quadros(12)
	cam.queue_free()


## Pós-processamento com tudo ligado + psx_material criado em código, na frente de uma câmera.
func _forcar_pos_e_psx(main: Node, gs) -> void:
	var ef = get_node("/root/Efeitos")
	gs.novo_jogo()
	gs.visita = 4
	gs.set_flag("tem_visor")
	await main.carregar_mundo("res://world/niveis/castelinho.tscn", "Spawn")
	gs.trocar_epoca(3)
	var nivel: Node = main.mundo.get_child(0)
	gs.corruption_manual = 0.9
	gs.atencao = 1.0
	ef.pulso(1.2, 3.0)
	ef.visor(true)
	await _quadros(40)
	print("VARRE_OK pos_processamento corrupcao+pulso+visor+atencao ligados")
	ef.visor(false)
	gs.corruption_manual = -1.0
	gs.atencao = 0.0

	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(0.9, 0.2, 0.2))
	var tex := ImageTexture.create_from_image(img)
	var mat: ShaderMaterial = ef.material_psx(Color.WHITE, tex, Vector2(2.0, 2.0))
	var quad := QuadMesh.new()
	quad.size = Vector2(3.0, 3.0)
	var mi := MeshInstance3D.new()
	mi.mesh = quad
	mi.material_override = mat
	nivel.add_child(mi)
	var cam := Camera3D.new()
	nivel.add_child(cam)
	mi.global_position = Vector3(0.0, 1.5, 0.0)
	cam.global_position = Vector3(0.0, 1.5, 4.0)
	cam.look_at(mi.global_position, Vector3.UP)
	cam.current = true
	await _quadros(20)
	gs.corruption_manual = 0.9
	await _quadros(20)
	print("VARRE_OK psx_material (material_psx) desenhado")
	gs.corruption_manual = -1.0


func _quadros(n: int) -> void:
	for i in n:
		await get_tree().process_frame
