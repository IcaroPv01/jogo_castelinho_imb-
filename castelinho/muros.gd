class_name Muros
extends RefCounted
## Paredes retas com aberturas (arco abatido, arco ogival, retangular) geradas por código na Malha.
## Nada de CSG: cada parede vira polígonos de frente/verso + soleiras/ombreiras/intradorso do vão.
##
## Uma abertura é um Dictionary:
##   {"u": centro ao longo da parede (m), "w": largura, "v0": y da base (absoluto), "vs": y da imposta
##    (começo do arco; = topo se retangular), "vc": y do fecho (topo do arco), "tipo": "arco"|"ogival"|"ret"}
## `o` = ponto u=0 no plano EXTERNO ao nível y=0; `u` = direção unitária da parede; `n` = normal externa
## (horizontal); a espessura `t` vai para dentro (-n).

const SEG_ARCO := 8
const SEG_OGIVAL := 5


## Perfil do topo de uma abertura, da esquerda para a direita: Vector2(u, y).
static func perfil(tipo: String, u0: float, u1: float, vs: float, vc: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	var w := u1 - u0
	var c := (u0 + u1) * 0.5
	var f := vc - vs
	if tipo == "ret" or f < 0.01:
		pts.append(Vector2(u0, vs))
		pts.append(Vector2(u1, vs))
		return pts
	if tipo == "ogival":
		var r := (w * w / 4.0 + f * f) / w
		var ta := atan2(f, w * 0.5 - r)          # ângulo do ápice (no arco esquerdo)
		for i in SEG_OGIVAL + 1:
			var a := lerpf(PI, ta, float(i) / SEG_OGIVAL)
			pts.append(Vector2(u0 + r + r * cos(a), vs + r * sin(a)))
		for i in range(SEG_OGIVAL - 1, -1, -1):
			var a := lerpf(PI, ta, float(i) / SEG_OGIVAL)
			# espelho: ponto simétrico em relação ao centro
			pts.append(Vector2(2.0 * c - (u0 + r + r * cos(a)), vs + r * sin(a)))
		return pts
	# arco abatido (segmental): circunferência pelos dois apoios e pelo fecho
	var R := (w * w / 4.0 + f * f) / (2.0 * f)
	var cy := vc - R
	var a0 := atan2(vs - cy, -w * 0.5)
	var a1 := atan2(vs - cy, w * 0.5)
	for i in SEG_ARCO + 1:
		var a := lerpf(a0, a1, float(i) / SEG_ARCO)
		pts.append(Vector2(c + R * cos(a), cy + R * sin(a)))
	pts[0] = Vector2(u0, vs)
	pts[pts.size() - 1] = Vector2(u1, vs)
	return pts


## Cria uma abertura (Dictionary) com valores padrão.
static func ab(u: float, w: float, v0: float, vs: float, vc := -1.0, tipo := "arco") -> Dictionary:
	if vc < 0.0:
		vc = vs
	if tipo == "arco" and vc <= vs + 0.01:
		tipo = "ret"
	return {"u": u, "w": w, "v0": v0, "vs": vs, "vc": vc, "tipo": tipo}


static func _p(o: Vector3, u: Vector3, n: Vector3, uu: float, y: float, prof: float) -> Vector3:
	## ponto da parede: uu ao longo, y absoluto, prof = distância para dentro (0 = face externa)
	return o + u * uu + Vector3(0, y, 0) - n * prof


## opc: "y1b" (topo em u=L, para topo inclinado), "tampa" (fecha o topo), "tampas_lat" (fecha as pontas),
##      "col" (gera colisão, padrão true), "col_topo" (altura da colisão, padrão y1), "mat_topo",
##      "mat_reveal" (material dos vãos, padrão mat_e), "sem_ext"/"sem_int" (não gera a face),
##      "col_abertura" (true = fecha a abertura na colisão, ex.: janela com vidro).
static func muro(me: Malha, mi: Malha, mat_e: Material, mat_i: Material, o: Vector3, u: Vector3, n: Vector3,
		L: float, t: float, y0: float, y1: float, aberturas: Array = [], opc: Dictionary = {}) -> void:
	var y1b: float = opc.get("y1b", y1)
	var col: bool = opc.get("col", true)
	var col_topo: float = opc.get("col_topo", maxf(y1, y1b))
	var mat_rev: Material = opc.get("mat_reveal", mat_e)
	var sem_ext: bool = opc.get("sem_ext", false)
	var sem_int: bool = opc.get("sem_int", false)
	var mat_topo: Material = opc.get("mat_topo", mat_e)
	var ops := aberturas.duplicate()
	ops.sort_custom(func(a, b): return a["u"] < b["u"])

	var topo := func(uu: float) -> float:
		return y1 + (y1b - y1) * (uu / L) if L > 0.0 else y1

	# --- polígonos da frente (u,y): lista de 4 pontos (laço)
	var polys: Array = []
	var cursor := 0.0
	for a in ops:
		var ua: float = a["u"] - a["w"] * 0.5
		var ub: float = a["u"] + a["w"] * 0.5
		if ua > cursor + 0.0005:
			polys.append([Vector2(cursor, y0), Vector2(ua, y0), Vector2(ua, topo.call(ua)), Vector2(cursor, topo.call(cursor))])
		if a["v0"] > y0 + 0.0005:
			polys.append([Vector2(ua, y0), Vector2(ub, y0), Vector2(ub, a["v0"]), Vector2(ua, a["v0"])])
		var pf := perfil(a["tipo"], ua, ub, a["vs"], a["vc"])
		for i in pf.size() - 1:
			var p0 := pf[i]
			var p1 := pf[i + 1]
			var t0: float = topo.call(p0.x)
			var t1: float = topo.call(p1.x)
			if t0 - p0.y > 0.001 or t1 - p1.y > 0.001:
				polys.append([p0, p1, Vector2(p1.x, t1), Vector2(p0.x, t0)])
		cursor = ub
	if cursor < L - 0.0005:
		polys.append([Vector2(cursor, y0), Vector2(L, y0), Vector2(L, topo.call(L)), Vector2(cursor, topo.call(cursor))])

	for pl in polys:
		if not sem_ext:
			me.quad(mat_e, _p(o, u, n, pl[0].x, pl[0].y, 0), _p(o, u, n, pl[1].x, pl[1].y, 0), _p(o, u, n, pl[2].x, pl[2].y, 0), _p(o, u, n, pl[3].x, pl[3].y, 0), n)
		if not sem_int:
			mi.quad(mat_i, _p(o, u, n, pl[0].x, pl[0].y, t), _p(o, u, n, pl[1].x, pl[1].y, t), _p(o, u, n, pl[2].x, pl[2].y, t), _p(o, u, n, pl[3].x, pl[3].y, t), -n)

	# --- vãos: ombreiras, soleira e intradorso
	for a in ops:
		var ua: float = a["u"] - a["w"] * 0.5
		var ub: float = a["u"] + a["w"] * 0.5
		var pf := perfil(a["tipo"], ua, ub, a["vs"], a["vc"])
		# ombreira esquerda (normal +u), direita (normal -u)
		me_quad_rev(me if not sem_ext else mi, mat_rev, o, u, n, t, ua, a["v0"], ua, a["vs"], u)
		me_quad_rev(me if not sem_ext else mi, mat_rev, o, u, n, t, ub, a["v0"], ub, a["vs"], -u)
		if a["v0"] > y0 + 0.0005:
			var q0 := _p(o, u, n, ua, a["v0"], 0)
			var q1 := _p(o, u, n, ub, a["v0"], 0)
			var q2 := _p(o, u, n, ub, a["v0"], t)
			var q3 := _p(o, u, n, ua, a["v0"], t)
			(me if not sem_ext else mi).quad(mat_rev, q0, q1, q2, q3, Vector3.UP)
		for i in pf.size() - 1:
			var s0 := pf[i]
			var s1 := pf[i + 1]
			if absf(s1.y - s0.y) < 0.0001 and a["tipo"] == "ret":
				# verga plana: normal para baixo
				var v0 := _p(o, u, n, s0.x, s0.y, 0)
				var v1 := _p(o, u, n, s1.x, s1.y, 0)
				var v2 := _p(o, u, n, s1.x, s1.y, t)
				var v3 := _p(o, u, n, s0.x, s0.y, t)
				(me if not sem_ext else mi).quad(mat_rev, v0, v1, v2, v3, Vector3.DOWN)
			else:
				var tg := (s1 - s0).normalized()
				var n2 := Vector2(tg.y, -tg.x)         # aponta para dentro do vão (para baixo)
				var n3 := u * n2.x + Vector3(0, n2.y, 0)
				var v0 := _p(o, u, n, s0.x, s0.y, 0)
				var v1 := _p(o, u, n, s1.x, s1.y, 0)
				var v2 := _p(o, u, n, s1.x, s1.y, t)
				var v3 := _p(o, u, n, s0.x, s0.y, t)
				(me if not sem_ext else mi).quad(mat_rev, v0, v1, v2, v3, n3)

	# --- topo e pontas
	if opc.get("tampa", false):
		var q0 := _p(o, u, n, 0.0, y1, 0)
		var q1 := _p(o, u, n, L, y1b, 0)
		var q2 := _p(o, u, n, L, y1b, t)
		var q3 := _p(o, u, n, 0.0, y1, t)
		me.quad(mat_topo, q0, q1, q2, q3, Vector3.UP, Vector2(1.5, 1.5))
	if opc.get("tampas_lat", false):
		var a0 := _p(o, u, n, 0.0, y0, 0)
		var a1 := _p(o, u, n, 0.0, y1, 0)
		var a2 := _p(o, u, n, 0.0, y1, t)
		var a3 := _p(o, u, n, 0.0, y0, t)
		me.quad(mat_e, a0, a1, a2, a3, -u)
		var b0 := _p(o, u, n, L, y0, 0)
		var b1 := _p(o, u, n, L, y1b, 0)
		var b2 := _p(o, u, n, L, y1b, t)
		var b3 := _p(o, u, n, L, y0, t)
		me.quad(mat_e, b0, b1, b2, b3, u)

	# --- colisão
	if col:
		var co_ab: bool = opc.get("col_abertura", false)
		var cur := 0.0
		for a in ops:
			var ua: float = a["u"] - a["w"] * 0.5
			var ub: float = a["u"] + a["w"] * 0.5
			if ua > cur + 0.001:
				_col_rect(me, o, u, n, t, cur, ua, y0, col_topo)
			var lintel: float = a["vs"] + 0.55 * (a["vc"] - a["vs"])
			if co_ab:
				_col_rect(me, o, u, n, t, ua, ub, y0, col_topo)
			else:
				if a["v0"] > y0 + 0.001:
					_col_rect(me, o, u, n, t, ua, ub, y0, a["v0"])
				if col_topo > lintel + 0.001:
					_col_rect(me, o, u, n, t, ua, ub, lintel, col_topo)
			cur = ub
		if cur < L - 0.001:
			_col_rect(me, o, u, n, t, cur, L, y0, col_topo)


static func me_quad_rev(m: Malha, mat: Material, o: Vector3, u: Vector3, n: Vector3, t: float, ua: float, ya: float, ub: float, yb: float, normal: Vector3) -> void:
	if yb - ya < 0.0005:
		return
	m.quad(mat, _p(o, u, n, ua, ya, 0), _p(o, u, n, ub, yb, 0), _p(o, u, n, ub, yb, t), _p(o, u, n, ua, ya, t), normal)


static func _col_rect(m: Malha, o: Vector3, u: Vector3, n: Vector3, t: float, ua: float, ub: float, ya: float, yb: float) -> void:
	m.col(_p(o, u, n, ua, ya, 0), _p(o, u, n, ub, yb, t))


## Atalho: parede ao longo do eixo X (z fixo). `a`<`b` em x. fora = +1 (normal +z) ou -1 (normal -z).
static func muro_x(me: Malha, mi: Malha, mat_e: Material, mat_i: Material, z_ext: float, a: float, b: float,
		fora: int, t: float, y0: float, y1: float, aberturas: Array = [], opc: Dictionary = {}) -> void:
	var n := Vector3(0, 0, float(fora))
	var u := Vector3.RIGHT
	var o := Vector3(a, 0, z_ext)
	# aberturas são dadas com u = posição ABSOLUTA em x; converte para relativa
	var rel := []
	for ab_ in aberturas:
		var c: Dictionary = ab_.duplicate()
		c["u"] = ab_["u"] - a
		rel.append(c)
	muro(me, mi, mat_e, mat_i, o, u, n, b - a, t, y0, y1, rel, opc)


## Atalho: parede ao longo do eixo Z (x fixo). `a`<`b` em z. fora = +1 (normal +x) ou -1 (normal -x).
static func muro_z(me: Malha, mi: Malha, mat_e: Material, mat_i: Material, x_ext: float, a: float, b: float,
		fora: int, t: float, y0: float, y1: float, aberturas: Array = [], opc: Dictionary = {}) -> void:
	var n := Vector3(float(fora), 0, 0)
	var u := Vector3.BACK
	var o := Vector3(x_ext, 0, a)
	var rel := []
	for ab_ in aberturas:
		var c: Dictionary = ab_.duplicate()
		c["u"] = ab_["u"] - a
		rel.append(c)
	muro(me, mi, mat_e, mat_i, o, u, n, b - a, t, y0, y1, rel, opc)
