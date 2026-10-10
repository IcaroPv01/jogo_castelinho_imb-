extends SceneTree
## Galeria dos objetos 3D do jogo: fotografa cada objeto isolado (3 ângulos), tira a foto "onde fica" no nível
## e exporta um .glb. Escreve também galeria/manifesto.json. Não é um teste (precisa de renderização).
##
## Uso (xvfb):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --rendering-driver opengl3 -s res://tools/galeria/fotografar.gd -- <saida> [opções]
## <saida> = pasta (ex.: galeria; relativa à raiz do projeto ou absoluta). Opções:
##   ids=a,b,c     só estes objetos (grava manifesto_parcial.json em vez de manifesto.json)
##   cen=chave     só este cenário (idem)
##   sem_local     não tira a foto "onde fica"
##   sem_glb       não exporta .glb
##
## O catálogo (o que fotografar, onde fica e como recortar) está em tools/galeria/catalogo.gd.
## Objetos "fundidos" na malha do prédio (mobília) são RECORTADOS do nível vivo: os triângulos cujo centro cai dentro
## de uma caixa (AABB) conhecida pelo código-fonte. Objetos que são nós (criaturas, painéis...) são instanciados direto.
## O estúdio é um SubViewport com mundo próprio (fundo cinza, luz de estúdio presa à câmera).
## ATENÇÃO: sobe o jogo de verdade (main.tscn) e, como os testes de captura, mexe em user://save.json.

const LARG := 640
const ALT := 480
const FOV_ESTUDIO := 35.0
const ELEV_NORMAL := [14.0, 10.0, 32.0]
const ELEV_CHAO := [55.0, 40.0, 75.0]
const AZIM := [35.0, 90.0, 215.0]
const ELEV_FINO := [8.0, 14.0, 24.0]          # folhas verticais finas (mural, painel, banner): só se vê a frente
const AZIM_FINO := [24.0, -34.0, 58.0]

var Cat
var gs: Node
var main: Node
var nivel: Node3D
var player: Node3D
var sv: SubViewport
var cam: Camera3D
var estudio: Node3D
var saida := ""
var so_ids: PackedStringArray = PackedStringArray()
var so_cen := ""
var sem_local := false
var sem_glb := false
var manifesto: Array = []
var falhas: Array = []
var _mats_export := {}
var _n_fotos := 0
var _cen_atual := ""


func _initialize() -> void:
	_rodar.call_deferred()


# ====================================================================================== principal
func _rodar() -> void:
	var t0 := Time.get_ticks_msec()
	var args := OS.get_cmdline_user_args()
	saida = args[0] if args.size() > 0 else "galeria"
	for i in range(1, args.size()):
		var a: String = args[i]
		if a.begins_with("ids="):
			so_ids = a.substr(4).split(",")
		elif a.begins_with("cen="):
			so_cen = a.substr(4)
		elif a == "sem_local":
			sem_local = true
		elif a == "sem_glb":
			sem_glb = true
	if not saida.is_absolute_path():
		saida = ProjectSettings.globalize_path("res://").path_join(saida)
	DirAccess.make_dir_recursive_absolute(saida.path_join("fotos"))
	DirAccess.make_dir_recursive_absolute(saida.path_join("modelos"))
	root.size = Vector2i(1280, 720)
	gs = root.get_node("/root/GameState")
	Cat = load("res://tools/galeria/catalogo.gd")
	_montar_estudio()
	var lista: Array = Cat.lista()
	var por_cen := {}
	for o in lista:
		if so_ids.size() > 0 and not (o["id"] in so_ids):
			continue
		if so_cen != "" and o["cen"] != so_cen:
			continue
		if not por_cen.has(o["cen"]):
			por_cen[o["cen"]] = []
		por_cen[o["cen"]].append(o)
	print("galeria: ", lista.size(), " objetos no catálogo; ", por_cen.size(), " cenários a rodar")
	for chave in Cat.CEN.keys():
		if not por_cen.has(chave):
			continue
		_cen_atual = chave
		print("== cenário ", chave, " (", por_cen[chave].size(), " objetos)")
		var ok: bool = await _carregar_cenario(chave)
		if not ok:
			for o in por_cen[chave]:
				falhas.append(o["id"] + " (cenário não carregou)")
			continue
		for o in por_cen[chave]:
			var t1 := Time.get_ticks_msec()
			await _processar(o)
			print("   ", o["id"], "  ", Time.get_ticks_msec() - t1, " ms")
	_escrever_manifesto()
	print("galeria: ", manifesto.size(), " objetos fotografados; falhas: ", falhas.size())
	for f in falhas:
		print("   FALHOU: ", f)
	print("galeria: tempo total ", (Time.get_ticks_msec() - t0) / 1000, " s")
	quit()


# ====================================================================================== estúdio
func _montar_estudio() -> void:
	sv = SubViewport.new()
	sv.size = Vector2i(LARG, ALT)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	sv.msaa_3d = Viewport.MSAA_4X
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.5, 0.51, 0.53)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.92, 0.93, 0.97)
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	sv.add_child(we)
	estudio = Node3D.new()
	estudio.name = "Estudio"
	sv.add_child(estudio)
	cam = Camera3D.new()
	cam.fov = FOV_ESTUDIO
	cam.near = 0.02
	cam.far = 300.0
	sv.add_child(cam)
	cam.current = true
	# luz de estúdio presa à câmera: principal (cima-esquerda), preenchimento (direita) e contraluz suave
	var principal := DirectionalLight3D.new()
	principal.light_energy = 1.05
	principal.rotation_degrees = Vector3(-38.0, 28.0, 0.0)
	cam.add_child(principal)
	var preench := DirectionalLight3D.new()
	preench.light_energy = 0.45
	preench.light_color = Color(0.85, 0.9, 1.0)
	preench.rotation_degrees = Vector3(-12.0, -55.0, 0.0)
	cam.add_child(preench)
	var topo := DirectionalLight3D.new()
	topo.light_energy = 0.3
	topo.rotation_degrees = Vector3(-80.0, 0.0, 0.0)
	cam.add_child(topo)


func _descendentes(no: Node) -> Array:
	var r: Array = []
	var pilha: Array = [no]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		r.append(n)
		for c in n.get_children():
			pilha.append(c)
	return r


## Caixa (no espaço global) de tudo que é visível dentro de `no`.
func _aabb_no(no: Node3D) -> AABB:
	var res := AABB()
	var tem := false
	for n in _descendentes(no):
		if not (n is Node3D) or n is Light3D:
			continue
		if not (n is MeshInstance3D or n is Label3D or n is Sprite3D):
			continue
		var g := n as GeometryInstance3D
		if not g.is_visible_in_tree():
			continue
		if g is MeshInstance3D and (g as MeshInstance3D).mesh == null:
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		if bb.size.length() < 0.0001:
			continue
		res = bb if not tem else res.merge(bb)
		tem = true
	if not tem:
		res = AABB(no.global_position - Vector3.ONE * 0.1, Vector3.ONE * 0.2)
	return res


## Tira o que atrapalha um objeto isolado: luzes, colisões, sons, partículas, gatilhos.
func _limpar_para_estudio(no: Node) -> void:
	for n in _descendentes(no):
		if not is_instance_valid(n):
			continue
		if n is Light3D or n is CollisionShape3D or n is CollisionPolygon3D or n is AudioStreamPlayer3D or n is GPUParticles3D \
				or n is CPUParticles3D or n is NavigationAgent3D or n is Camera3D or n is WorldEnvironment:
			n.free()
		elif n is CollisionObject3D:
			(n as CollisionObject3D).collision_layer = 0
			(n as CollisionObject3D).collision_mask = 0


func _enquadrar(bb: AABB, az_graus: float, el_graus: float) -> void:
	var c := bb.get_center()
	var az := deg_to_rad(az_graus)
	var el := deg_to_rad(el_graus)
	var dir := Vector3(sin(az) * cos(el), sin(el), cos(az) * cos(el)).normalized()
	cam.global_position = c + dir * 10.0
	cam.look_at(c, Vector3.UP)
	var b := cam.global_transform.basis
	var dir_olhar := -b.z
	var ty := tan(deg_to_rad(FOV_ESTUDIO) * 0.5)
	var tx := ty * float(LARG) / float(ALT)
	var margem := 0.84
	var d := bb.size.length() * 0.5 + 0.05
	for i in 8:
		var p: Vector3 = bb.get_endpoint(i) - c
		var px := absf(p.dot(b.x))
		var py := absf(p.dot(b.y))
		var pz := p.dot(dir_olhar)
		d = maxf(d, px / (tx * margem) - pz)
		d = maxf(d, py / (ty * margem) - pz)
	cam.global_position = c + dir * d
	cam.look_at(c, Vector3.UP)


func _quadros(n := 4) -> void:
	for i in n:
		await process_frame


## Foto do estúdio com o objeto `no` já na árvore do estúdio.
func _foto_estudio(no: Node3D, az: float, el: float, arq: String) -> bool:
	var bb := _aabb_no(no)
	_enquadrar(bb, az, el)
	await _quadros(4)
	var img := sv.get_texture().get_image()
	if img == null:
		return false
	img.convert(Image.FORMAT_RGB8)
	var err := img.save_jpg(arq, 0.82)
	_n_fotos += 1
	return err == OK


# ====================================================================================== cenários
func _criar_main() -> void:
	main = load("res://scenes/main/main.tscn").instantiate()
	root.add_child(main)
	main.aquecer_ativo = false
	await process_frame
	if is_instance_valid(main.tela_titulo):
		main.tela_titulo.queue_free()
	await process_frame


func _esconder_ui() -> void:
	for c in root.get_children():
		if c is CanvasLayer:
			(c as CanvasLayer).visible = false
	if main:
		for c in main.get_children():
			if c is CanvasLayer:
				(c as CanvasLayer).visible = false
		if main.hud:
			main.hud.visible = false


func _carregar_cenario(chave: String) -> bool:
	var c: Dictionary = Cat.CEN[chave]
	if main == null:
		await _criar_main()
	if sem_local and false:
		return true
	gs.jogando = false
	gs.visita = int(c.get("visita", 1))
	gs.flags["tem_lanterna"] = true
	for f in c.get("flags", {}):
		gs.flags[f] = c["flags"][f]
	if c.get("novo_jogo", false):
		gs.novo_jogo()
		for f in c.get("flags", {}):
			gs.flags[f] = c["flags"][f]
		if c.has("comecar_visita"):
			gs.comecar_visita(int(c["comecar_visita"]))
		gs.jogando = false
	gs.epoca = int(c.get("epoca", 3))
	await main.carregar_mundo(c["cena"], "Spawn")
	if main.mundo.get_child_count() == 0:
		return false
	nivel = main.mundo.get_child(0)
	player = main.player
	player.collision_layer = 0
	gs.definir_corruption_manual(float(c.get("corr", 0.0)))
	gs.epoca = -1
	gs.trocar_epoca(int(c.get("epoca", 3)))
	_esconder_ui()
	await _quadros(20)
	await physics_frame
	await physics_frame
	match str(c.get("preparar", "")):
		"porao":
			nivel.ameacas_ligadas = false
	_esconder_ui()
	return true


# ====================================================================================== objeto a objeto
func _processar(o: Dictionary) -> void:
	var id: String = o["id"]
	_esconder_ui()
	if o.has("pre"):
		await (o["pre"] as Callable).call(nivel, self)
		await _quadros(3)
	# 1. monta o objeto isolado
	var fonte: Dictionary = o["fonte"]
	var obj: Node3D = await _montar_objeto(o, fonte)
	if obj == null:
		falhas.append(id + " (nada encontrado: " + str(fonte.get("t", "?")) + ")")
		return
	var info: Dictionary = {}
	if obj.has_meta("_frame"):
		info = obj.get_meta("_frame")
	estudio.add_child(obj)
	_limpar_para_estudio(obj)
	await _quadros(3)
	var bb0 := _aabb_no(obj)
	# centraliza no chão do estúdio (base no y = 0, centro em x/z = 0)
	var desloc := Vector3(-(bb0.position.x + bb0.size.x * 0.5), -bb0.position.y, -(bb0.position.z + bb0.size.z * 0.5))
	obj.position += desloc
	await _quadros(2)
	var bb := _aabb_no(obj)
	if bb.size.length() < 0.001:
		falhas.append(id + " (objeto sem geometria visível)")
		obj.queue_free()
		return
	if bool(o.get("parado", true)):
		obj.process_mode = Node.PROCESS_MODE_DISABLED
	# 2. três ângulos
	var plano := bb.size.y < 0.12 * maxf(bb.size.x, bb.size.z) and bb.size.y < 0.6
	var fino_v := not plano and (bb.size.z < 0.12 * maxf(bb.size.x, bb.size.y) or bb.size.x < 0.12 * maxf(bb.size.z, bb.size.y)) \
		and minf(bb.size.x, bb.size.z) < 0.6
	var elev: Array = ELEV_CHAO if plano else (ELEV_FINO if fino_v else ELEV_NORMAL)
	var azs: Array = AZIM_FINO if fino_v else AZIM
	var frente: float = float(o.get("frente", 0.0))
	var fotos: Array = []
	for k in 3:
		var rel := "fotos/%s_%d.jpg" % [id, k + 1]
		var ok := await _foto_estudio(obj, frente + azs[k], elev[k], saida.path_join(rel))
		if ok:
			fotos.append(rel)
	# 3. glb
	var glb := ""
	if not sem_glb:
		glb = _exportar(obj, id)
	# 4. onde fica (foto no nível)
	var local := ""
	if not sem_local and not bool(o.get("sem_local", false)):
		local = await _foto_local(o, info, bb)
	obj.queue_free()
	await _quadros(1)
	if fotos.size() < 3:
		falhas.append(id + " (fotos do estúdio incompletas)")
		return
	var notas: Array = (o.get("notas", []) as Array).duplicate()
	if info.get("aviso", "") != "":
		notas.append(info["aviso"])
	if local == "" and not sem_local and not bool(o.get("sem_local", false)):
		notas.append("sem foto de local (nenhum ponto de vista livre achado)")
	var d := {
		"id": id, "nome": o["nome"], "grupo": o["grupo"], "onde": o["onde"],
		"arquivo": o["arquivo"], "linha": _achar_linha(o["arquivo"], o.get("padrao", "")),
		"glb": glb, "fotos": fotos, "local": local, "notas": notas,
	}
	manifesto.append(d)


## Devolve o nó isolado (ainda fora da árvore). Meta "_frame": dados para a foto de local.
func _montar_objeto(o: Dictionary, f: Dictionary) -> Node3D:
	var t: String = f["t"]
	match t:
		"no":
			var n: Node3D = (f["f"] as Callable).call()
			return n
		"nivel_no":
			var alvo := _achar_no(f["nome"])
			if alvo == null:
				return null
			return _copiar_do_nivel(alvo)
		"nivel_fn":
			var r = (f["f"] as Callable).call(nivel)
			if r == null:
				return null
			var n3 := r as Node3D
			if n3.is_inside_tree():
				return _copiar_do_nivel(n3)
			return n3
		"crop":
			return _recortar_do_nivel(o, f)
		"crop_sala":
			return _recortar_de_sala(o, f)
	return null


func _achar_no(nome: String) -> Node3D:
	var n := nivel.find_child(nome, true, false)
	return n as Node3D


## Copia um nó vivo do nível para o estúdio mantendo a pose de mundo.
func _copiar_do_nivel(alvo: Node3D) -> Node3D:
	var caixa_mundo := _aabb_no(alvo)
	var envelope := Node3D.new()
	envelope.name = "Copia_" + String(alvo.name)
	var d := alvo.duplicate() as Node3D
	envelope.add_child(d)
	d.transform = alvo.global_transform
	envelope.set_meta("_frame", {"centro": caixa_mundo.get_center(), "raio": caixa_mundo.size.length() * 0.5, "base": caixa_mundo.position.y})
	return envelope


# ---------------------------------------------------------------------------------------- recorte
func _recortar_do_nivel(o: Dictionary, f: Dictionary) -> Node3D:
	var raiz_busca: Node = nivel
	var grupo: String = f.get("grupo", "")
	if grupo != "":
		raiz_busca = nivel.find_child(grupo, true, false)
		if raiz_busca == null:
			print("   (grupo ", grupo, " não existe neste cenário)")
			return null
	return _recortar(raiz_busca, f["caixa"], Transform3D.IDENTITY, f)


func _recortar_de_sala(o: Dictionary, f: Dictionary) -> Node3D:
	var idx: int = f["idx"]
	if not nivel.has_method("ir_para_sala"):
		return null
	if nivel.idx_atual != idx:
		nivel.ir_para_sala(idx)
	var c = nivel.salas.get(idx)
	if c == null:
		return null
	var caixa: AABB = (f["caixa"] as Callable).call(c)
	var frame: Transform3D = c.raiz.global_transform
	var f2 := f.duplicate()
	var ok_mats: Array = []
	for nome in f.get("shader_mats", []):
		if c.mats.has(nome):
			ok_mats.append(c.mats[nome])
	f2["shader_ok"] = ok_mats
	return _recortar(c.raiz, caixa, frame, f2)


func _recortar(raiz_busca: Node, caixa: AABB, frame: Transform3D, f: Dictionary) -> Node3D:
	var inv := frame.affine_inverse()
	var opc := {"shader": bool(f.get("shader", false)), "ok": f.get("shader_ok", []), "excl": f.get("excluir_cores", []), "aresta2": pow(float(f.get("aresta_max", 8.0)), 2.0)}
	var com_rotulos: bool = bool(f.get("rotulos", true))
	var bks := {}
	var ordem: Array = []
	var rotulos: Array = []
	var pilha: Array = [raiz_busca]
	while not pilha.is_empty():
		var n: Node = pilha.pop_back()
		if n is Node3D and not (n as Node3D).is_visible_in_tree():
			continue
		for c in n.get_children():
			pilha.append(c)
		if n is MeshInstance3D:
			var nome := String(n.name)
			if nome.begins_with("Agua") or nome.begins_with("Ceu") or nome == "Lago":
				continue
			_recortar_mi(n as MeshInstance3D, caixa, inv, opc, bks, ordem)
		elif com_rotulos and (n is Label3D or n is Sprite3D):
			var pos: Vector3 = inv * (n as Node3D).global_position
			if caixa.has_point(pos):
				rotulos.append(n)
	if ordem.is_empty() and rotulos.is_empty():
		return null
	var raiz := Node3D.new()
	raiz.name = "Recorte"
	if not ordem.is_empty():
		var am := ArrayMesh.new()
		for mat in ordem:
			var b: Dictionary = bks[mat]
			var arr := []
			arr.resize(Mesh.ARRAY_MAX)
			arr[Mesh.ARRAY_VERTEX] = b["v"]
			arr[Mesh.ARRAY_NORMAL] = b["n"]
			arr[Mesh.ARRAY_TEX_UV] = b["uv"]
			arr[Mesh.ARRAY_COLOR] = b["c"]
			am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
			am.surface_set_material(am.get_surface_count() - 1, mat)
		var mi := MeshInstance3D.new()
		mi.name = "Malha"
		mi.mesh = am
		raiz.add_child(mi)
	for r in rotulos:
		var cp := (r as Node3D).duplicate() as Node3D
		raiz.add_child(cp)
		cp.transform = inv * (r as Node3D).global_transform
	raiz.set_meta("_frame", {"centro": frame * _centro_real(raiz), "raio": _raio_real(raiz), "base": (frame * Vector3(0, _base_real(raiz), 0)).y})
	return raiz


func _centro_real(raiz: Node3D) -> Vector3:
	var mi := raiz.get_node_or_null("Malha") as MeshInstance3D
	if mi:
		return mi.mesh.get_aabb().get_center()
	return Vector3.ZERO


func _raio_real(raiz: Node3D) -> float:
	var mi := raiz.get_node_or_null("Malha") as MeshInstance3D
	if mi:
		return mi.mesh.get_aabb().size.length() * 0.5
	return 0.5


func _base_real(raiz: Node3D) -> float:
	var mi := raiz.get_node_or_null("Malha") as MeshInstance3D
	if mi:
		return mi.mesh.get_aabb().position.y
	return 0.0


func _prim(mesh: Mesh, s: int) -> int:
	if mesh is ArrayMesh:
		return (mesh as ArrayMesh).surface_get_primitive_type(s)
	return Mesh.PRIMITIVE_TRIANGLES


func _recortar_mi(mi: MeshInstance3D, caixa: AABB, inv: Transform3D, opc: Dictionary, bks: Dictionary, ordem: Array) -> void:
	var mesh: Mesh = mi.mesh
	if mesh == null:
		return
	# descarta rápido a malha que nem encosta na caixa
	var xf: Transform3D = inv * mi.global_transform
	if not (xf * mesh.get_aabb()).intersects(caixa):
		return
	var nb := xf.basis.inverse().transposed()
	for s in mesh.get_surface_count():
		if _prim(mesh, s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var mat: Material = mi.get_surface_override_material(s)
		if mat == null:
			mat = mi.material_override
		if mat == null:
			mat = mesh.surface_get_material(s)
		if mat is ShaderMaterial and not opc["shader"] and not (mat in opc["ok"]):
			continue
		var arr := mesh.surface_get_arrays(s)
		var vs: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var ns: PackedVector3Array = arr[Mesh.ARRAY_NORMAL] if arr[Mesh.ARRAY_NORMAL] != null else PackedVector3Array()
		var uvs: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV] if arr[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var cs: PackedColorArray = arr[Mesh.ARRAY_COLOR] if arr[Mesh.ARRAY_COLOR] != null else PackedColorArray()
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX] if arr[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var ntri: int = (idx.size() if idx.size() > 0 else vs.size()) / 3
		var tem_n := ns.size() == vs.size()
		var tem_uv := uvs.size() == vs.size()
		var tem_c := cs.size() == vs.size()
		var b: Dictionary
		for t in ntri:
			var i0: int
			var i1: int
			var i2: int
			if idx.size() > 0:
				i0 = idx[t * 3]
				i1 = idx[t * 3 + 1]
				i2 = idx[t * 3 + 2]
			else:
				i0 = t * 3
				i1 = t * 3 + 1
				i2 = t * 3 + 2
			var a: Vector3 = xf * vs[i0]
			var bb: Vector3 = xf * vs[i1]
			var cc: Vector3 = xf * vs[i2]
			var ct := (a + bb + cc) / 3.0
			if not caixa.has_point(ct):
				continue
			if (a - bb).length_squared() > opc["aresta2"] or (bb - cc).length_squared() > opc["aresta2"] or (cc - a).length_squared() > opc["aresta2"]:
				continue
			if tem_c and not (opc["excl"] as Array).is_empty():
				var cor_t: Color = cs[i0]
				var fora_ := false
				for ec in opc["excl"]:
					if absf(cor_t.r - ec.r) < 0.03 and absf(cor_t.g - ec.g) < 0.03 and absf(cor_t.b - ec.b) < 0.03:
						fora_ = true
						break
				if fora_:
					continue
			if b.is_empty():
				if not bks.has(mat):
					bks[mat] = {"v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "c": PackedColorArray()}
					ordem.append(mat)
				b = bks[mat]
			var fn := (bb - a).cross(cc - a).normalized()
			var pts := [a, bb, cc]
			var ids := [i0, i1, i2]
			for k in 3:
				b["v"].append(pts[k])
				if tem_n:
					b["n"].append((nb * ns[ids[k]]).normalized())
				else:
					b["n"].append(fn)
				b["uv"].append(uvs[ids[k]] if tem_uv else Vector2.ZERO)
				b["c"].append(cs[ids[k]] if tem_c else Color.WHITE)


# ====================================================================================== foto "onde fica"
func _foto_local(o: Dictionary, info: Dictionary, bb_estudio: AABB) -> String:
	var rel := "fotos/%s_local.jpg" % o["id"]
	var centro: Vector3
	var raio: float
	var base_y: float
	var ref_no: Node3D = null
	var colocado: Node3D = null
	if o.has("ref"):
		ref_no = (o["ref"] as Callable).call(nivel)
	if ref_no == null and o.has("colocar") and (o["fonte"]["t"] == "no" or o["fonte"]["t"] == "nivel_fn"):
		var cl: Dictionary = o["colocar"]
		var pai: Node = nivel
		if cl.has("sala"):
			var idx_sala := int(cl["sala"])
			if not nivel.salas.has(idx_sala):
				nivel.ir_para_sala(idx_sala)
			var cc = nivel.salas.get(idx_sala)
			if cc:
				pai = cc.raiz
		colocado = await _montar_objeto(o, o["fonte"])
		if colocado.is_inside_tree():
			colocado.get_parent().remove_child(colocado)
		pai.add_child(colocado)
		if cl.has("transform"):
			colocado.transform = cl["transform"]
		else:
			colocado.position = cl.get("pos", Vector3.ZERO)
			colocado.rotation_degrees.y = float(cl.get("yaw", 0.0))
		if colocado.has_method("_ready") and "somente_visual" in colocado:
			colocado.somente_visual = true
		ref_no = colocado
		await _quadros(3)
	if ref_no != null:
		var bbn := _aabb_no(ref_no)
		centro = bbn.get_center()
		raio = bbn.size.length() * 0.5
		base_y = bbn.position.y
	elif not info.is_empty():
		centro = info["centro"]
		raio = float(info["raio"])
		base_y = float(info["base"])
	else:
		return ""
	raio = clampf(raio, 0.25, 12.0)
	var pt = _achar_vista(centro, raio, base_y, float(o.get("frente", 0.0)), float(o.get("dist", 0.0)))
	if pt == null:
		if colocado:
			colocado.queue_free()
		return ""
	print("      local: pés ", pt[0], " alvo ", centro, " raio ", snappedf(raio, 0.01))
	_olhar(pt[0], centro)
	_esconder_ui()
	await _quadros(14)
	var img := root.get_texture().get_image()
	var ok := false
	if img:
		img.convert(Image.FORMAT_RGB8)
		img.resize(960, 540, Image.INTERPOLATE_LANCZOS)
		ok = img.save_jpg(saida.path_join(rel), 0.82) == OK
	if colocado:
		colocado.queue_free()
		await _quadros(1)
	return rel if ok else ""


## Põe o jogador com os PÉS em `pos`, olhando para `alvo` (yaw no corpo, pitch na cabeça).
func _olhar(pos: Vector3, alvo: Vector3) -> void:
	player.global_position = pos
	var olho: Vector3 = pos + Vector3(0, player.cabeca.position.y, 0)
	var d := alvo - olho
	player.rotation.y = atan2(-d.x, -d.z)
	player.cabeca.rotation.x = atan2(d.y, Vector2(d.x, d.z).length())
	if "velocity" in player:
		player.velocity = Vector3.ZERO


func _raio(de: Vector3, para: Vector3) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(de, para, 1)
	q.collide_with_areas = false
	q.hit_from_inside = true
	return nivel.get_world_3d().direct_space_state.intersect_ray(q)


## Procura um lugar onde o jogador possa ficar em pé, com a vista livre para o objeto. Devolve [pés, olho] ou null.
func _achar_vista(centro: Vector3, raio: float, base_y: float, frente_deg: float, dist_pref: float):
	var alt_olho: float = player.cabeca.position.y
	var d0: float = dist_pref if dist_pref > 0.0 else maxf(2.0, raio * 2.5)
	var dists: Array = [d0, d0 * 1.3, d0 * 0.8, d0 * 1.7, d0 * 0.6, d0 * 2.3]
	var offs: Array = [0.0, 35.0, -35.0, 70.0, -70.0, 110.0, -110.0, 150.0, -150.0, 180.0]
	var pontos_alvo: Array = [Vector3.ZERO, Vector3(0, minf(raio, 0.5) * 0.8, 0), Vector3(0, -minf(raio, 0.5) * 0.8, 0)]
	for d in dists:
		for off in offs:
			var az := deg_to_rad(frente_deg + off)
			var xz := Vector3(centro.x + sin(az) * d, 0, centro.z + cos(az) * d)
			var y_ini := base_y + 0.7
			var hit := _raio(Vector3(xz.x, y_ini, xz.z), Vector3(xz.x, y_ini - 8.0, xz.z))
			if hit.is_empty():
				continue
			if (hit["normal"] as Vector3).y < 0.7:
				continue
			var pes: Vector3 = hit["position"] + Vector3(0, 0.03, 0)
			var olho := pes + Vector3(0, alt_olho, 0)
			# o corpo e a cabeça cabem (sem parede por perto)
			var livre := true
			for k in 8:
				var a := TAU * float(k) / 8.0
				var dd := Vector3(cos(a), 0, sin(a)) * 0.42
				if not _raio(olho, olho + dd).is_empty() or not _raio(pes + Vector3(0, 0.9, 0), pes + Vector3(0, 0.9, 0) + dd).is_empty():
					livre = false
					break
			if not livre:
				continue
			if not _raio(olho, olho + Vector3(0, 0.3, 0)).is_empty():
				continue
			# vista livre até a superfície do objeto
			var vista_ok := true
			for pa in pontos_alvo:
				var alvo: Vector3 = centro + pa
				var para: Vector3 = (olho - alvo).normalized()
				var ponto: Vector3 = alvo + para * raio * 1.25
				if not _raio(olho, ponto).is_empty():
					vista_ok = false
					break
			if not vista_ok:
				continue
			return [pes, olho]
	return null


# ====================================================================================== exportação glb
func _exportar(obj: Node3D, id: String) -> String:
	var raiz := Node3D.new()
	raiz.name = id
	estudio.add_child(raiz)
	var n_mesh := 0
	for n in _descendentes(obj):
		if not (n is MeshInstance3D):
			continue
		var mi := n as MeshInstance3D
		if mi.mesh == null or not mi.is_visible_in_tree():
			continue
		var am := _mesh_export(mi)
		if am == null:
			continue
		var novo := MeshInstance3D.new()
		novo.name = "%s_%d" % [String(mi.name).replace("@", "_"), n_mesh]
		novo.mesh = am
		raiz.add_child(novo)
		novo.global_transform = mi.global_transform
		n_mesh += 1
	if n_mesh == 0:
		raiz.queue_free()
		return ""
	var caminho := saida.path_join("modelos/%s.glb" % id)
	var doc := GLTFDocument.new()
	if "image_format" in doc:
		doc.set("image_format", "PNG")
	var st := GLTFState.new()
	var err := doc.append_from_scene(raiz, st)
	if err == OK:
		err = doc.write_to_filesystem(st, caminho)
	raiz.queue_free()
	if err != OK:
		falhas.append(id + " (glb: erro " + str(err) + ")")
		return ""
	var tam := FileAccess.get_size(caminho)
	if tam > 1500000:
		print("   AVISO: ", id, ".glb com ", tam / 1024, " KB")
	return "modelos/%s.glb" % id


func _mesh_export(mi: MeshInstance3D) -> ArrayMesh:
	var am := ArrayMesh.new()
	var mesh := mi.mesh
	for s in mesh.get_surface_count():
		if _prim(mesh, s) != Mesh.PRIMITIVE_TRIANGLES:
			continue
		var arr := mesh.surface_get_arrays(s)
		if arr[Mesh.ARRAY_VERTEX] == null or (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() < 3:
			continue
		# só o que o glTF usa
		var limpo := []
		limpo.resize(Mesh.ARRAY_MAX)
		limpo[Mesh.ARRAY_VERTEX] = arr[Mesh.ARRAY_VERTEX]
		limpo[Mesh.ARRAY_NORMAL] = arr[Mesh.ARRAY_NORMAL]
		limpo[Mesh.ARRAY_TEX_UV] = arr[Mesh.ARRAY_TEX_UV]
		limpo[Mesh.ARRAY_COLOR] = arr[Mesh.ARRAY_COLOR]
		limpo[Mesh.ARRAY_INDEX] = arr[Mesh.ARRAY_INDEX]
		var mat: Material = mi.get_surface_override_material(s)
		if mat == null:
			mat = mi.material_override
		if mat == null:
			mat = mesh.surface_get_material(s)
		var tem_cor: bool = arr[Mesh.ARRAY_COLOR] != null
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, limpo)
		am.surface_set_material(am.get_surface_count() - 1, _mat_export(mat, tem_cor))
	if am.get_surface_count() == 0:
		return null
	return am


func _cor_media(tex: Texture2D) -> Color:
	var img := tex.get_image()
	if img == null:
		return Color(0.6, 0.6, 0.6)
	if img.is_compressed():
		img.decompress()
	img.resize(1, 1, Image.INTERPOLATE_LANCZOS)
	var c := img.get_pixel(0, 0)
	c.a = 1.0
	return c


func _tex_pequena(tex: Texture2D) -> Texture2D:
	var img := tex.get_image()
	if img == null:
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var m := maxi(img.get_width(), img.get_height())
	if m > 256:
		var k := 256.0 / float(m)
		img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)), Image.INTERPOLATE_LANCZOS)
	return ImageTexture.create_from_image(img)


## Material "de exibição" para o glTF: StandardMaterial3D simples (triplanar e shaders viram cor média).
func _mat_export(m: Material, tem_cor_vertice: bool) -> Material:
	var chave := [m, tem_cor_vertice]
	if _mats_export.has(chave):
		return _mats_export[chave]
	var r := StandardMaterial3D.new()
	r.roughness = 0.85
	if m is StandardMaterial3D:
		var s := m as StandardMaterial3D
		r.albedo_color = s.albedo_color
		r.vertex_color_use_as_albedo = s.vertex_color_use_as_albedo
		r.roughness = s.roughness
		r.metallic = s.metallic
		r.cull_mode = s.cull_mode
		r.transparency = s.transparency
		r.alpha_scissor_threshold = s.alpha_scissor_threshold
		if s.shading_mode == BaseMaterial3D.SHADING_MODE_UNSHADED:
			r.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		if s.emission_enabled and s.emission.get_luminance() > 0.01:
			r.emission_enabled = true
			r.emission = s.emission
			r.emission_energy_multiplier = s.emission_energy_multiplier
		if s.albedo_texture != null:
			if s.uv1_triplanar:
				r.albedo_color = s.albedo_color * _cor_media(s.albedo_texture)
			else:
				r.albedo_texture = _tex_pequena(s.albedo_texture)
	elif m is ShaderMaterial:
		var sm := m as ShaderMaterial
		var base := Color(0.62, 0.6, 0.58)
		var tx = sm.get_shader_parameter("textura")
		if tx is Texture2D:
			base = _cor_media(tx)
		var tom = sm.get_shader_parameter("tom")
		if tom is Color:
			base = base * (tom as Color)
		r.albedo_color = base
		r.vertex_color_use_as_albedo = tem_cor_vertice
	else:
		r.albedo_color = Color(0.7, 0.7, 0.7)
	_mats_export[chave] = r
	return r


# ====================================================================================== manifesto
func _achar_linha(arquivo: String, padrao: String) -> int:
	if padrao == "":
		return 1
	var f := FileAccess.open("res://" + arquivo, FileAccess.READ)
	if f == null:
		return 1
	var n := 0
	while not f.eof_reached():
		n += 1
		if f.get_line().find(padrao) >= 0:
			return n
	return 1


func _escrever_manifesto() -> void:
	var parcial := so_ids.size() > 0 or so_cen != ""
	var canva := ""
	var antigo := FileAccess.open(saida.path_join("manifesto.json"), FileAccess.READ)
	if antigo:
		var j = JSON.parse_string(antigo.get_as_text())
		if typeof(j) == TYPE_DICTIONARY:
			canva = str((j as Dictionary).get("canva", ""))
	var d := {"gerado": Time.get_date_string_from_system(), "canva": canva, "objetos": manifesto}
	var nome := "manifesto_parcial.json" if parcial else "manifesto.json"
	var f := FileAccess.open(saida.path_join(nome), FileAccess.WRITE)
	if f == null:
		push_error("não consegui escrever " + nome)
		return
	f.store_string(JSON.stringify(d, "  ", false))
	f.close()
	print("galeria: escrito ", saida.path_join(nome))
