class_name RegistroObjetos
extends RefCounted
## Varredura da ÁRVORE DE NÓS para o registro de objetos (ver o cabeçalho de malha.gd): grava em `Malha.registro`
## os objetos que NÃO nascem de uma Malha (MeshInstance3D soltos, Sprite3D, Label3D, caixas do Construtor, criaturas...)
## e as colisões (StaticBody3D). Também corrige as entradas de Malhas "locais" (objetos montados fora do lugar, como
## o pinguim e a armadura: a Malha gravou coordenadas locais; a varredura as leva para o mundo).
##
## Uso (com `Malha.registrar` ligado ANTES de construir o nível):
##   RegistroObjetos.varrer(nivel_node, "ato2")
## Nome do objeto: meta "etiqueta" (Malha.nomear) no nó ou num ancestral; senão "pai/Nome#índice" (estável).
## Épocas: meta "epocas" (Epocas.marcar) no nó ou num ancestral.
## Entradas "no" ganham também: "no" (caminho), "malha_no" (classe da malha), "auto" (nome inventado), "rot" (inclinado),
## "estrutura" (parece parede/piso: grande) e "visivel".

const F_TODAS := 63


static func varrer(raiz: Node, nivel_nome := "") -> int:
	var n0 := Malha.registro.size()
	var corrigidas := {}
	var cache := {}
	_visitar(raiz, raiz, nivel_nome, corrigidas, cache)
	return Malha.registro.size() - n0


static func _epocas_de(no: Node) -> Array:
	var n := no
	while n != null:
		if n.has_meta("epocas"):
			return n.get_meta("epocas")
		n = n.get_parent()
	return []


static func _eh_conteiner(p: Node, cache: Dictionary) -> bool:
	if cache.has(p):
		return cache[p]
	var r := false
	if p.get_child_count() > 0:
		var gs := p.find_children("*", "GeometryInstance3D", true, false)
		if gs.size() > 30:
			r = true
		elif gs.size() > 1:
			var bb := AABB()
			var primeiro := true
			for g in gs:
				var gi := g as GeometryInstance3D
				if gi.get_parent() is Node3D or true:
					var a := _aabb_mundo(gi)
					bb = a if primeiro else bb.merge(a)
					primeiro = false
			if bb.size.x > 9.0 or bb.size.z > 9.0:
				r = true
	cache[p] = r
	return r


static func _slug(t: String) -> String:
	var r := t.to_lower().strip_edges()
	for ch in [" ", "-", ".", ",", "/", "\\", "(", ")", "[", "]", "'", "\""]:
		r = r.replace(ch, "_")
	while r.contains("__"):
		r = r.replace("__", "_")
	return r.trim_prefix("_").trim_suffix("_")


static func _objeto(no: Node, raiz: Node, cache: Dictionary) -> Node:
	var n := no
	while n != null and n != raiz:
		if n.has_meta("etiqueta"):
			return n
		if n.has_method("interagir"):        # Interagivel / Painel3D: um objeto só, com as peças dentro
			return n
		n = n.get_parent()
	# sem nome explícito: sobe enquanto o pai for um agrupador pequeno (lustre, vitrine...) e não o nível
	var alvo := no
	var p := no.get_parent()
	while p != null and p != raiz and p is Node3D and p.get_class() == "Node3D" and not _eh_conteiner(p, cache):
		alvo = p
		p = p.get_parent()
	return alvo


static func _nome_obj(no: Node, raiz: Node) -> String:
	if no.has_method("interagir"):
		var pid = no.get("id")
		if pid != null and String(pid) != "":
			return "painel_" + String(pid)
		var tx = no.get("texto_interacao")
		if tx != null:
			return "interagivel_" + _slug(String(tx)) + "#" + str(no.get_index())
	return _nome_estavel(no, raiz)


static func _nome_estavel(no: Node, raiz: Node) -> String:
	var nm := String(no.name).replace("@", "")
	var re := RegEx.new()
	re.compile("[0-9]{2,}$")
	nm = re.sub(nm, "")
	var par := no.get_parent()
	var idx := no.get_index()
	var pai_nome := ""
	if par != null and par != raiz:
		pai_nome = String(par.name).replace("@", "")
		pai_nome = re.sub(pai_nome, "")
	return ("%s/%s#%d" % [pai_nome, nm, idx]) if pai_nome != "" else ("%s#%d" % [nm, idx])


static func _aabb_mundo(g: GeometryInstance3D) -> AABB:
	var a := g.get_aabb()
	if a.size == Vector3.ZERO and not (g is MeshInstance3D):
		a = AABB(Vector3(-0.01, -0.01, -0.01), Vector3(0.02, 0.02, 0.02))
	return g.global_transform * a


static func _alinhado(b: Basis) -> bool:
	for i in 3:
		var col := b[i].normalized()
		var ok := false
		for ax in [Vector3.RIGHT, Vector3.UP, Vector3.BACK]:
			if absf(col.dot(ax)) > 0.9999:
				ok = true
		if not ok:
			return false
	return true


static func _novo(et: String, tipo: String, bb: AABB, n: Vector3, no: Node, mat: Material, nv: String, auto: bool) -> Dictionary:
	var d := {"etiqueta": et, "tipo": tipo, "aabb": bb, "normal": n, "faces": F_TODAS if tipo == "caixa" else 0,
		"material": Malha._mat_id(mat), "cor": "#ffffff", "grupo": "", "epocas": _epocas_de(no), "nivel": nv,
		"onde": "", "malha": 0, "no": "", "malha_no": "", "auto": auto, "rot": false, "estrutura": false, "visivel": true}
	if mat is BaseMaterial3D:
		d["cor"] = (mat as BaseMaterial3D).albedo_color.to_html(false)
	return d


static func _visitar(no: Node, raiz: Node, nv: String, corrigidas: Dictionary, cache: Dictionary) -> void:
	if no is MeshInstance3D and (no as MeshInstance3D).has_meta("malha"):
		_corrigir_malha(no as MeshInstance3D, raiz, nv, corrigidas, cache)
	elif no is GeometryInstance3D:
		_geometria(no as GeometryInstance3D, raiz, nv, cache)
	elif no is CollisionShape3D:
		_colisao(no as CollisionShape3D, raiz, nv)
	for c in no.get_children():
		_visitar(c, raiz, nv, corrigidas, cache)


static func _geometria(g: GeometryInstance3D, raiz: Node, nv: String, cache: Dictionary) -> void:
	if g is MultiMeshInstance3D:
		var mm := (g as MultiMeshInstance3D).multimesh
		if mm == null or mm.mesh == null:
			return
		var ma := mm.mesh.get_aabb()
		for i in mm.instance_count:
			var t: Transform3D = g.global_transform * mm.get_instance_transform(i)
			var d := _novo("multimesh/" + String(g.name), "no", t * ma, Vector3.ZERO, g, null, nv, true)
			d["no"] = str(raiz.get_path_to(g))
			d["malha_no"] = "MultiMesh"
			d["estrutura"] = true            # árvores: não entram nas checagens de objeto
			Malha.registro.append(d)
		return
	var obj := _objeto(g, raiz, cache)
	var auto := not obj.has_meta("etiqueta")
	var et: String = obj.get_meta("etiqueta") if not auto else _nome_obj(obj, raiz)
	var tipo := "no"
	var normal := Vector3.ZERO
	var rot := not _alinhado(g.global_transform.basis)
	var mat: Material = g.material_override
	var classe := g.get_class()
	if g is MeshInstance3D:
		var mi := g as MeshInstance3D
		if mi.mesh == null:
			return
		classe = mi.mesh.get_class()
		if mat == null and mi.mesh.get_surface_count() > 0:
			mat = mi.get_active_material(0)
		if mi.mesh is BoxMesh and not rot:
			tipo = "caixa"
		elif (mi.mesh is PlaneMesh or mi.mesh is QuadMesh) and not rot:
			tipo = "quad"
			normal = (g.global_transform.basis * (Vector3.UP if mi.mesh is PlaneMesh else Vector3.BACK)).normalized()
	elif g is Sprite3D or g is Label3D:
		if not rot:
			tipo = "quad"
			normal = (g.global_transform.basis * Vector3.BACK).normalized()
	var bb := _aabb_mundo(g)
	if tipo == "quad":
		# folha: achata na espessura
		var ax := 0
		if absf(normal.y) > 0.9:
			ax = 1
		elif absf(normal.z) > 0.9:
			ax = 2
		var pos := bb.position
		var sz := bb.size
		var c := bb.get_center()
		sz[ax] = 0.0
		pos[ax] = c[ax]
		bb = AABB(pos, sz)
	var d := _novo(et, tipo, bb, normal, g, mat, nv, auto)
	d["no"] = str(raiz.get_path_to(g))
	d["objeto_no"] = str(raiz.get_path_to(obj)) if (obj != g or obj.has_meta("etiqueta")) else ""
	d["malha_no"] = classe
	d["rot"] = rot
	d["visivel"] = g.visible
	d["onde"] = g.get_meta("q") if g.has_meta("q") else _onde_de(g, raiz)
	var tam := bb.size
	if auto:
		d["estrutura"] = tam.x >= 2.5 or tam.z >= 2.5 or tam.y >= 2.3
	Malha.registro.append(d)


static func _onde_de(no: Node, raiz: Node) -> String:
	var sc = raiz.get_script()
	if sc is Script:
		return "%s (nó %s)" % [(sc as Script).resource_path.get_file(), no.name]
	return "(nó %s)" % no.name


static func _colisao(cs: CollisionShape3D, raiz: Node, nv: String) -> void:
	if cs.disabled or cs.shape == null:
		return
	var corpo := cs.get_parent()
	if not (corpo is StaticBody3D or corpo is AnimatableBody3D):
		return
	if corpo.has_meta("malha_col"):
		return          # colisão criada por Malha.construir_colisao: já registrada (com etiqueta) por Malha.col
	if ((corpo as CollisionObject3D).collision_layer & 1) == 0:
		return
	var sh := cs.shape
	var bb: AABB
	var terreno := false
	if sh is BoxShape3D:
		bb = cs.global_transform * AABB(-(sh as BoxShape3D).size * 0.5, (sh as BoxShape3D).size)
	elif sh is ConvexPolygonShape3D:
		var pts := (sh as ConvexPolygonShape3D).points
		if pts.is_empty():
			return
		var t := cs.global_transform
		bb = AABB(t * pts[0], Vector3.ZERO)
		for p in pts:
			bb = bb.expand(t * p)
	else:
		var dm := sh.get_debug_mesh()
		if dm == null:
			return
		bb = cs.global_transform * dm.get_aabb()
		terreno = true
	var d := _novo("", "col", bb, Vector3.ZERO, cs, null, nv, true)
	d["no"] = str(raiz.get_path_to(cs))
	d["malha_no"] = sh.get_class()
	d["terreno"] = terreno
	d["invisivel"] = not (corpo.get_parent() is GeometryInstance3D)      # colisor sem malha (paredes de contenção)
	d["onde"] = _onde_de(cs, raiz)
	Malha.registro.append(d)


## Uma MeshInstance3D criada por Malha.construir_instancia: se não está no lugar "de mundo" que a Malha
## supôs (translação `desloc`), leva as entradas dessa Malha para o mundo e herda nome/épocas do nó.
static func _corrigir_malha(mi: MeshInstance3D, raiz: Node, nv: String, corrigidas: Dictionary, cache: Dictionary) -> void:
	var id: int = mi.get_meta("malha")
	if corrigidas.has(id):
		return
	corrigidas[id] = true
	var ma = instance_from_id(id)
	var desloc := Vector3.ZERO
	if ma != null:
		desloc = ma.desloc
	var gt := mi.global_transform
	var igual := gt.origin.is_equal_approx(desloc) and gt.basis.is_equal_approx(Basis())
	if igual:
		return          # Malha do próprio nível (Casa, Cidade, salas do porão...): as entradas já estão no mundo
	var obj := _objeto(mi, raiz, cache)
	var auto := not obj.has_meta("etiqueta")
	var et_obj: String = obj.get_meta("etiqueta") if not auto else _nome_estavel(obj, raiz)
	var eps := _epocas_de(mi)
	for e in Malha.registro:
		if e["malha"] != id:
			continue
		if not igual:
			# entradas estão em (local + desloc): volta ao local e aplica o transform do nó
			var loc: AABB = (e["aabb"] as AABB)
			loc.position -= desloc
			e["aabb"] = gt * loc
			e["normal"] = (gt.basis * (e["normal"] as Vector3)).normalized() if (e["normal"] as Vector3) != Vector3.ZERO else Vector3.ZERO
			e["fora_do_lugar"] = true
			e["rot"] = not _alinhado(gt.basis)
		if e["etiqueta"] == "":
			e["etiqueta"] = et_obj
			e["auto"] = true
		if (e["epocas"] as Array).is_empty() and not eps.is_empty():
			e["epocas"] = eps
		e["no"] = str(raiz.get_path_to(mi))
