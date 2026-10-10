extends RefCounted
## Biblioteca do verificador de colocação (ver colocacao.gd). Recebe o REGISTRO de `Malha` (castelinho/malha.gd +
## castelinho/registro.gd) de UMA construção de nível e devolve achados:
##   flutuando, enfiado, atravessa_parede, fora_da_sala, zfighting, fresta, degrau_de_piso.
## Não depende de cena: só de dados (dá para testar com um registro salvo). Carregue com load(): GDScript headless
## não enxerga class_name novo sem reimportar.
##
## MODELO
##  - "objeto" = entrada com etiqueta (Malha.abrir / Malha.nomear) que não é "estrutura".
##    "estrutura" = sem etiqueta (paredes, pisos, lajes) ou nó grande sem nome (auto).
##  - "sólido" = colisão (tipo col) sem etiqueta + caixa estrutural com menor lado >= 5 cm.
##  - Cada entrada tem uma máscara de épocas (bit = 1 << GameState.Epoca; [] = todas). Duas entradas só interagem se
##    compartilham uma época.
##  - Limiares (m): FOLGA = 0,03 (vão mínimo para "flutuando"), PROF_MIN = 0,04 (enfiado), ZF = 0,002.

const FOLGA := 0.03
const PROF_MIN := 0.04
const ZF := 0.0021
const TODAS := 63
const NOMES_EPOCA := ["1950", "1975", "2019", "2020", "1967", "sem_data"]

# ---- achados
var achados: Array = []
var contexto: Dictionary = {}

# ---- dados preparados
var es: Array = []                    # Array[E]
var grade: Grade
var _sol: Array = []                  # sólidos
var _grade_sol: Grade
var materiais: Dictionary = {}


class E:
	var i := 0
	var et := ""
	var tipo := ""
	var mn := Vector3.ZERO
	var mx := Vector3.ZERO
	var n := Vector3.ZERO
	var faces := 0
	var mat := ""
	var epm := TODAS
	var obj := false
	var estr := false
	var transp := false
	var emis := false
	var visivel := true
	var area := 0.0
	var fino := -1            # eixo (0..2) de uma folha plana alinhada aos eixos; -1 = volume
	var cl := -1
	var d: Dictionary
	var col := false
	var terreno := false

	func tam() -> Vector3:
		return mx - mn

	func centro() -> Vector3:
		return (mn + mx) * 0.5


class Grade:
	var cel := 1.5
	var d := {}
	var grandes: Array = []
	var marca := PackedInt32Array()
	var q := 0

	func _init(n: int, c := 1.5) -> void:
		cel = c
		marca.resize(n + 1)

	func inserir(idx: int, mn: Vector3, mx: Vector3, margem := 0.0) -> void:
		var a := Vector3i(floori((mn.x - margem) / cel), floori((mn.y - margem) / cel), floori((mn.z - margem) / cel))
		var b := Vector3i(floori((mx.x + margem) / cel), floori((mx.y + margem) / cel), floori((mx.z + margem) / cel))
		var total := (b.x - a.x + 1) * (b.y - a.y + 1) * (b.z - a.z + 1)
		if total > 300:
			grandes.append(idx)
			return
		for x in range(a.x, b.x + 1):
			for y in range(a.y, b.y + 1):
				for z in range(a.z, b.z + 1):
					var k := Vector3i(x, y, z)
					if d.has(k):
						d[k].append(idx)
					else:
						d[k] = PackedInt32Array([idx])

	func consultar(mn: Vector3, mx: Vector3) -> PackedInt32Array:
		q += 1
		var r := PackedInt32Array()
		var a := Vector3i(floori(mn.x / cel), floori(mn.y / cel), floori(mn.z / cel))
		var b := Vector3i(floori(mx.x / cel), floori(mx.y / cel), floori(mx.z / cel))
		var total := (b.x - a.x + 1) * (b.y - a.y + 1) * (b.z - a.z + 1)
		if total > 2000:
			for k in d:
				for i in (d[k] as PackedInt32Array):
					if marca[i] != q:
						marca[i] = q
						r.append(i)
		else:
			for x in range(a.x, b.x + 1):
				for y in range(a.y, b.y + 1):
					for z in range(a.z, b.z + 1):
						var k := Vector3i(x, y, z)
						if d.has(k):
							for i in (d[k] as PackedInt32Array):
								if marca[i] != q:
									marca[i] = q
									r.append(i)
		for i in grandes:
			if marca[i] != q:
				marca[i] = q
				r.append(i)
		return r


# ============================================================================ preparação
static func bits(eps: Array) -> int:
	if eps.is_empty():
		return TODAS
	var m := 0
	for e in eps:
		m |= 1 << int(e)
	return m


static func nomes_epocas(m: int) -> Array:
	if m == TODAS:
		return ["todas"]
	var r: Array = []
	for i in 6:
		if m & (1 << i):
			r.append(NOMES_EPOCA[i])
	return r


func preparar(registro: Array, mats: Dictionary, ctx: Dictionary) -> void:
	contexto = ctx
	materiais = mats
	achados = []
	es = []
	_sol = []
	for d in registro:
		var e := E.new()
		e.i = es.size()
		e.d = d
		e.et = d["etiqueta"]
		e.tipo = d["tipo"]
		var bb: AABB = d["aabb"]
		e.mn = bb.position
		e.mx = bb.position + bb.size
		e.n = d["normal"]
		e.faces = d["faces"]
		e.mat = "%s|%s" % [d["material"], d["cor"]]
		e.epm = bits(d["epocas"])
		e.col = e.tipo == "col"
		e.terreno = d.get("terreno", false)
		e.estr = d.get("estrutura", false)
		e.obj = e.et != "" and not e.estr and not e.col
		e.visivel = d.get("visivel", true)
		e.area = d.get("area", 0.0)
		var mi: Dictionary = mats.get(d["material"], {})
		e.transp = mi.get("transparente", false)
		e.emis = mi.get("emissivo", false) or mi.get("sem_luz", false)
		if e.tipo == "quad" or e.tipo == "tri":
			for ax in 3:
				if absf(e.n[ax]) > 0.999 and (e.mx[ax] - e.mn[ax]) < 0.002:
					e.fino = ax
		elif e.tipo == "no" or e.tipo == "caixa":
			pass
		es.append(e)
	grade = Grade.new(es.size())
	for e in es:
		var ee: E = e
		if ee.col:
			continue
		grade.inserir(ee.i, ee.mn, ee.mx, 0.0)
	agrupar_objetos()
	_atribuir_colisoes_aos_donos()
	_montar_solidos()


## Colisões sem etiqueta que cabem (>= 70 % do volume) dentro de um objeto são o colisor DESSE objeto (cx(..., col=true)).
func _atribuir_colisoes_aos_donos() -> void:
	var bbs: Array = []
	for c in _clusters:
		bbs.append(_bb_cluster(c))
	var gc := Grade.new(_clusters.size() + 1, 2.0)
	for i in bbs.size():
		gc.inserir(i, (bbs[i] as AABB).position, (bbs[i] as AABB).end, 0.05)
	for e in es:
		var ee: E = e
		if not ee.col or ee.et != "":
			continue
		var vol := ee.tam().x * ee.tam().y * ee.tam().z
		if vol <= 0.0:
			continue
		for ci in gc.consultar(ee.mn - Vector3.ONE * 0.05, ee.mx + Vector3.ONE * 0.05):
			var bb: AABB = (bbs[ci] as AABB).grow(0.03)
			if (bb.size.x > 20.0 or bb.size.z > 20.0) or (_epm_cluster(_clusters[ci]) & ee.epm) == 0:
				continue
			var inter := bb.intersection(AABB(ee.mn, ee.tam()))
			if inter.size.x * inter.size.y * inter.size.z >= 0.7 * vol:
				ee.et = (_clusters[ci][0] as E).et
				ee.d["dono"] = ee.et
				break


func _montar_solidos() -> void:
	_sol = []
	_grade_sol = Grade.new(es.size())
	for e in es:
		var ee: E = e
		var t := ee.tam()
		var s := false
		if ee.col and ee.et == "" and not ee.d.get("invisivel", false):
			s = true
		elif (ee.tipo == "caixa") and not ee.obj and ee.et == "" and minf(t.x, minf(t.y, t.z)) >= 0.05:
			s = true
		if s:
			_sol.append(ee)
			_grade_sol.inserir(ee.i, ee.mn, ee.mx, 0.0)


func sala_de(p: Vector3) -> String:
	var f: Callable = contexto.get("sala_fn", Callable())
	if f.is_valid():
		return f.call(p)
	return ""


func _acha(tipo: String, grav: String, e: E, p: Vector3, medida_cm: float, desc: String, intencional: bool, motivo: String, extra := {}) -> void:
	var d := {"tipo": tipo, "gravidade": grav, "nivel": contexto.get("nivel", ""), "visita": contexto.get("visita", 0),
		"epocas": nomes_epocas(e.epm if e else TODAS), "sala": sala_de(p), "etiqueta": (e.et if e.et != "" else _nome_estrutura(e)) if e else "",
		"no": e.d.get("no", "") if e else "", "posicao": [snappedf(p.x, 0.01), snappedf(p.y, 0.01), snappedf(p.z, 0.01)],
		"medida_cm": snappedf(medida_cm, 0.1), "detalhe": desc, "arquivo": _arquivo(e) if e else "",
		"pilha": e.d.get("onde", "") if e else "", "provavel_intencional": intencional, "motivo": motivo}
	for k in extra:
		d[k] = extra[k]
	achados.append(d)


static func _nome_estrutura(e: E) -> String:
	if e == null:
		return ""
	var o: String = e.d.get("onde", "")
	var p := o.split(" < ")
	var ult := p[p.size() - 1] if p.size() > 0 else ""
	return "estrutura@" + (p[min(1, p.size() - 1)] if p.size() > 0 else "")


static func _arquivo(e: E) -> String:
	var o: String = e.d.get("onde", "")
	if o == "":
		return ""
	var p := o.split(" < ")
	# primeira moldura que NÃO é construtor genérico (muros.gd, mobilia.cx...) é a mais útil; guardamos a 2ª também
	return p[0] if p.size() == 1 else (p[0] + "  <  " + p[1])


# ============================================================================ geometria
static func dist_caixas(amn: Vector3, amx: Vector3, bmn: Vector3, bmx: Vector3) -> float:
	var dx := maxf(0.0, maxf(amn.x - bmx.x, bmn.x - amx.x))
	var dy := maxf(0.0, maxf(amn.y - bmx.y, bmn.y - amx.y))
	var dz := maxf(0.0, maxf(amn.z - bmx.z, bmn.z - amx.z))
	return sqrt(dx * dx + dy * dy + dz * dz)


static func sobrep(a0: float, a1: float, b0: float, b1: float) -> float:
	return minf(a1, b1) - maxf(a0, b0)


# ============================================================================ clusters de objetos
var _clusters: Array = []     # Array of Array[E]


func agrupar_objetos() -> void:
	_clusters = []
	var por_et := {}
	var fixos := {}          # entradas de nós: um cluster por objeto-raiz (sem depender de contato)
	for e in es:
		var ee: E = e
		if ee.obj and ee.visivel:
			var on: String = ee.d.get("objeto_no", "")
			if on != "":
				var kk := "no:" + on
				if not fixos.has(kk):
					fixos[kk] = []
				fixos[kk].append(ee)
				continue
			if not por_et.has(ee.et):
				por_et[ee.et] = []
			por_et[ee.et].append(ee)
	for kk in fixos:
		var cl: Array = fixos[kk]
		for e in cl:
			(e as E).cl = _clusters.size()
		_clusters.append(cl)
	for et in por_et:
		var lst: Array = por_et[et]
		var pai := PackedInt32Array()
		pai.resize(lst.size())
		for i in lst.size():
			pai[i] = i
		var achar := func(x: int) -> int:
			while pai[x] != x:
				pai[x] = pai[pai[x]]
				x = pai[x]
			return x
		if lst.size() <= 80:
			for i in lst.size():
				for j in range(i + 1, lst.size()):
					var a: E = lst[i]
					var b: E = lst[j]
					if (a.epm & b.epm) != 0 and dist_caixas(a.mn, a.mx, b.mn, b.mx) <= FOLGA:
						pai[achar.call(i)] = achar.call(j)
		else:
			var g := Grade.new(lst.size())
			for i in lst.size():
				g.inserir(i, (lst[i] as E).mn, (lst[i] as E).mx, FOLGA)
			for i in lst.size():
				var a: E = lst[i]
				for j in g.consultar(a.mn - Vector3.ONE * FOLGA, a.mx + Vector3.ONE * FOLGA):
					if j > i:
						var b: E = lst[j]
						if (a.epm & b.epm) != 0 and dist_caixas(a.mn, a.mx, b.mn, b.mx) <= FOLGA:
							pai[achar.call(i)] = achar.call(j)
		var grupos := {}
		for i in lst.size():
			var r: int = achar.call(i)
			if not grupos.has(r):
				grupos[r] = []
			grupos[r].append(lst[i])
		for r in grupos:
			var c: Array = grupos[r]
			for e in c:
				(e as E).cl = _clusters.size()
			_clusters.append(c)


static func _bb_cluster(c: Array) -> AABB:
	var mn: Vector3 = (c[0] as E).mn
	var mx: Vector3 = (c[0] as E).mx
	for e in c:
		var ee: E = e
		mn = mn.min(ee.mn)
		mx = mx.max(ee.mx)
	return AABB(mn, mx - mn)


static func _epm_cluster(c: Array) -> int:
	var m := 0
	for e in c:
		m |= (e as E).epm
	return m


const _PAL_INTENC := ["luz", "chama", "brilho", "halo", "raio", "sombra", "mancha", "fumaca", "poeira", "faisca", "particula", "brasa", "fogo", "vento", "agua", "onda", "espuma"]


static func _palavra_intencional(et: String) -> String:
	var l := et.to_lower()
	for p in _PAL_INTENC:
		if l.contains(p):
			return p
	return ""


# ============================================================================ 1) flutuando
func checar_flutuando() -> void:
	for ci in _clusters.size():
		var c: Array = _clusters[ci]
		var bb := _bb_cluster(c)
		var epm := _epm_cluster(c)
		var e0: E = c[0]
		var big := bb.size.x > 30.0 or bb.size.z > 30.0
		if big:
			continue
		var cand := grade.consultar(bb.position - Vector3.ONE * 1.0, bb.end + Vector3.ONE * 1.0)
		var gap_any := 99.0
		var gap_y := 99.0           # vão até o apoio ABAIXO (99 = nada abaixo)
		var gap_up := 99.0          # vão até o teto ACIMA
		var apoio_et := ""
		var base_y := bb.position.y
		var topo_y := bb.end.y
		for i in cand:
			var o: E = es[i]
			if o.cl == ci or o.col or not o.visivel or (o.epm & epm) == 0:
				continue
			if o.tipo == "no" and o.terreno:
				continue
			for e in c:
				var ee: E = e
				var dd := dist_caixas(ee.mn, ee.mx, o.mn, o.mx)
				if dd < gap_any:
					gap_any = dd
			# apoio abaixo: considera as peças da base do objeto
			for e in c:
				var ee: E = e
				if ee.mn.y <= base_y + FOLGA:
					var ox := sobrep(ee.mn.x, ee.mx.x, o.mn.x, o.mx.x)
					var oz := sobrep(ee.mn.z, ee.mx.z, o.mn.z, o.mx.z)
					if ox > 0.005 and oz > 0.005:
						if o.mn.y - FOLGA <= base_y and o.mx.y + FOLGA >= base_y:
							gap_y = minf(gap_y, 0.0)          # a base está dentro/encostada na peça
							apoio_et = o.et
						elif o.mx.y < base_y:
							if base_y - o.mx.y < gap_y:
								gap_y = base_y - o.mx.y
								apoio_et = o.et
				if ee.mx.y >= topo_y - FOLGA:
					var ox2 := sobrep(ee.mn.x, ee.mx.x, o.mn.x, o.mx.x)
					var oz2 := sobrep(ee.mn.z, ee.mx.z, o.mn.z, o.mx.z)
					if ox2 > 0.005 and oz2 > 0.005 and o.mn.y >= topo_y - 0.0001:
						gap_up = minf(gap_up, o.mn.y - topo_y)
		var tam := bb.size
		var pos := bb.get_center()
		pos.y = base_y
		var pal := _palavra_intencional(e0.et)
		var emis := true
		for e in c:
			if not (e as E).emis:
				emis = false
		var intenc := pal != "" or emis
		var motivo := ("nome sugere efeito (%s)" % pal) if pal != "" else ("material emissivo/sem luz" if emis else "")
		if gap_y <= FOLGA or gap_up <= FOLGA:
			continue
		if gap_any <= FOLGA:
			# encostado só em parede/outro objeto. Perto do chão (< 35 cm) sem apoio embaixo = provável degrau mal calculado
			if gap_y < 0.35 and gap_y > FOLGA:
				_acha("flutuando", "M", e0, pos, gap_y * 100.0, "base a %.1f cm acima de '%s', encostado só lateralmente (tam %.2fx%.2fx%.2f m)" % [gap_y * 100.0, apoio_et, tam.x, tam.y, tam.z], intenc, motivo,
					{"parte": "base", "tamanho_m": [tam.x, tam.y, tam.z]})
			continue
		var g := gap_any
		var grav := "A" if g >= 0.10 else "M"
		var onde := "nada embaixo" if gap_y > 50.0 else ("%.1f cm acima de '%s'" % [gap_y * 100.0, apoio_et])
		_acha("flutuando", grav, e0, pos, g * 100.0, "vão de %.1f cm até qualquer superfície; %s (tam %.2fx%.2fx%.2f m)" % [g * 100.0, onde, tam.x, tam.y, tam.z], intenc, motivo,
			{"tamanho_m": [tam.x, tam.y, tam.z]})


# ============================================================================ 2/3) enfiado, atravessa parede
func checar_enfiado() -> void:
	for ci in _clusters.size():
		var c: Array = _clusters[ci]
		var epm := _epm_cluster(c)
		var e0: E = c[0]
		var melhor_prof := 0.0
		var melhor: E = null
		var melhor_s: E = null
		var melhor_eixo := -1
		var melhor_atrav := false
		var melhor_ov := Vector3.ZERO
		var melhor_dentro := false
		for e in c:
			var ee: E = e
			if ee.tipo == "tri" or ee.tipo == "bolha" or ee.tipo == "telhado" or ee.tipo == "piramide":
				continue
			if ee.tipo == "quad" and ee.fino < 0:
				continue
			if ee.tipo == "no" and ee.d.get("rot", false):
				continue
			var cand := _grade_sol.consultar(ee.mn - Vector3.ONE * 0.02, ee.mx + Vector3.ONE * 0.02)
			for i in cand:
				var s: E = es[i]
				if (s.epm & ee.epm) == 0 or s.terreno:
					continue
				var ov := Vector3(sobrep(ee.mn.x, ee.mx.x, s.mn.x, s.mx.x), sobrep(ee.mn.y, ee.mx.y, s.mn.y, s.mx.y), sobrep(ee.mn.z, ee.mx.z, s.mn.z, s.mx.z))
				var prof := 0.0
				var eixo := -1
				var atrav := false
				if ee.fino >= 0:
					var ax: int = ee.fino
					var co: float = ee.mn[ax]
					var u := (ax + 1) % 3
					var v := (ax + 2) % 3
					if ov[u] > 0.02 and ov[v] > 0.02 and co > s.mn[ax] + 0.0005 and co < s.mx[ax] - 0.0005:
						prof = minf(co - s.mn[ax], s.mx[ax] - co)
						eixo = ax
				else:
					if ov.x > 0.0 and ov.y > 0.0 and ov.z > 0.0:
						var mm := minf(ov.x, minf(ov.y, ov.z))
						prof = mm
						eixo = 0 if mm == ov.x else (1 if mm == ov.y else 2)
						# atravessa: o objeto passa por inteiro pelo lado fino do sólido
						var ts := s.tam()
						for ax in 3:
							if ts[ax] <= 0.7 and ee.mn[ax] <= s.mn[ax] + 0.01 and ee.mx[ax] >= s.mx[ax] - 0.01:
								var u2 := (ax + 1) % 3
								var v2 := (ax + 2) % 3
								if ov[u2] > 0.1 and ov[v2] > 0.1:
									atrav = true
				if prof > melhor_prof or (atrav and not melhor_atrav and prof > 0.0):
					melhor_prof = prof
					melhor = ee
					melhor_s = s
					melhor_eixo = eixo
					melhor_atrav = atrav or melhor_atrav
					melhor_ov = ov
		if melhor == null or melhor_prof < PROF_MIN:
			continue
		var centro := _bb_cluster(c).get_center()
		var dentro := melhor_s.mn.x <= centro.x and centro.x <= melhor_s.mx.x and melhor_s.mn.y <= centro.y and centro.y <= melhor_s.mx.y and melhor_s.mn.z <= centro.z and centro.z <= melhor_s.mx.z
		var grav := "B"
		if melhor_prof >= 0.20 or dentro or melhor_atrav:
			grav = "A"
		elif melhor_prof >= 0.08:
			grav = "M"
		var ts2 := melhor_s.tam()
		var chao := melhor_eixo == 1 and melhor.mn.y >= melhor_s.mn.y and ts2.y <= 1.0 and ts2.x > 1.0 and ts2.z > 1.0
		var parede := melhor_eixo != 1 and ts2.y >= 1.5
		var intenc := false
		var motivo := ""
		if chao and melhor_prof <= 0.06:
			intenc = true
			motivo = "assentado no piso (embute <= 6 cm de propósito, evita fresta)"
		elif parede and melhor_prof <= 0.06 and not melhor_atrav:
			intenc = true
			motivo = "encostado na parede com <= 6 cm de folga de encaixe"
		elif _palavra_intencional(e0.et) != "":
			intenc = true
			motivo = "nome sugere efeito/decalque (%s)" % _palavra_intencional(e0.et)
		var eixo_nome: String = ["X", "Y", "Z"][maxi(melhor_eixo, 0)]
		var tipo := "atravessa_parede" if melhor_atrav else "enfiado"
		var quem := melhor_s.et if melhor_s.et != "" else "estrutura/colisão"
		_acha(tipo, grav, e0, melhor.centro(), melhor_prof * 100.0,
			"%s: %.1f cm dentro de %s (%s) no eixo %s; sólido %.2fx%.2fx%.2f m%s" % [("atravessa a parede" if melhor_atrav else "enfiado"), melhor_prof * 100.0, quem,
				("col" if melhor_s.col else "caixa"), eixo_nome, ts2.x, ts2.y, ts2.z, (" (centro do objeto DENTRO do sólido)" if dentro else "")],
			intenc, motivo, {"solido_aabb": [melhor_s.mn.x, melhor_s.mn.y, melhor_s.mn.z, melhor_s.mx.x, melhor_s.mx.y, melhor_s.mx.z], "solido_onde": melhor_s.d.get("onde", "")})


# ============================================================================ 4) z-fighting
func checar_zfight() -> void:
	# faces: eixo, sinal, coordenada, retângulo (u0,u1,v0,v1)
	var f_e := PackedInt32Array()
	var f_k := PackedInt32Array()          # chave de balde
	var f_c := PackedFloat32Array()
	var f_u0 := PackedFloat32Array()
	var f_u1 := PackedFloat32Array()
	var f_v0 := PackedFloat32Array()
	var f_v1 := PackedFloat32Array()
	var f_fill := PackedFloat32Array()
	var f_ax := PackedInt32Array()
	var f_sg := PackedInt32Array()
	var baldes := {}
	var add := func(e: E, ax: int, sg: int, co: float, u0: float, u1: float, v0: float, v1: float, fill: float) -> void:
		if u1 - u0 < 0.01 or v1 - v0 < 0.01:
			return
		var k := int(roundf(co / 0.002)) * 6 + ax * 2 + sg
		var idx := f_e.size()
		f_e.append(e.i)
		f_k.append(k)
		f_c.append(co)
		f_u0.append(u0)
		f_u1.append(u1)
		f_v0.append(v0)
		f_v1.append(v1)
		f_fill.append(fill)
		f_ax.append(ax)
		f_sg.append(sg)
		if not baldes.has(k):
			baldes[k] = PackedInt32Array()
		baldes[k].append(idx)
	for e in es:
		var ee: E = e
		if ee.col or not ee.visivel or ee.tipo == "no" or ee.tipo == "bolha" or ee.tipo == "rampa" or ee.tipo == "telhado" or ee.tipo == "piramide":
			continue
		if ee.tipo == "caixa":
			var m := ee.faces
			# PX=1 NX=2 PY=4 NY=8 PZ=16 NZ=32 ; u,v = (ax+1)%3,(ax+2)%3
			var spec := [[1, 0, 1], [2, 0, 0], [4, 1, 1], [8, 1, 0], [16, 2, 1], [32, 2, 0]]
			for sp in spec:
				if m & sp[0]:
					var ax: int = sp[1]
					var sg: int = sp[2]
					var u := (ax + 1) % 3
					var v := (ax + 2) % 3
					add.call(ee, ax, sg, ee.mx[ax] if sg == 1 else ee.mn[ax], ee.mn[u], ee.mx[u], ee.mn[v], ee.mx[v], 1.0)
		elif ee.fino >= 0:
			var ax2: int = ee.fino
			var u2 := (ax2 + 1) % 3
			var v2 := (ax2 + 2) % 3
			var bba := (ee.mx[u2] - ee.mn[u2]) * (ee.mx[v2] - ee.mn[v2])
			var fill := 1.0
			if ee.area > 0.0 and bba > 0.0:
				fill = clampf(ee.area / bba, 0.0, 1.0)
			if fill < 0.45:
				continue
			add.call(ee, ax2, 1 if ee.n[ax2] > 0 else 0, ee.mn[ax2], ee.mn[u2], ee.mx[u2], ee.mn[v2], ee.mx[v2], fill)
	var achou := {}
	var comparar := func(a: int, b: int) -> void:
		var ea: E = es[f_e[a]]
		var eb: E = es[f_e[b]]
		if ea == eb or ea.mat == eb.mat or (ea.epm & eb.epm) == 0:
			return
		if absf(f_c[a] - f_c[b]) > ZF:
			return
		var ou := minf(f_u1[a], f_u1[b]) - maxf(f_u0[a], f_u0[b])
		var ov := minf(f_v1[a], f_v1[b]) - maxf(f_v0[a], f_v0[b])
		if ou < 0.01 or ov < 0.01:
			return
		var area := ou * ov * minf(f_fill[a], f_fill[b])
		if area < 0.004:
			return
		var ax: int = f_ax[a]
		if OS.get_environment("COLOC_ZF") != "" and (ea.et == OS.get_environment("COLOC_ZF") or String(eb.d.get("onde", "")).contains(OS.get_environment("COLOC_ZF"))):
			print("ZF ", ea.tipo, ea.mn, ea.mx, " f=", ea.faces, " n=", ea.n, " sg=", f_sg[a], " x ", eb.tipo, eb.mn, eb.mx, " f=", eb.faces, " n=", eb.n, " sg=", f_sg[b], " ", ea.mat, " ", eb.mat, " coord ", f_c[a], f_c[b], " ", ea.d.get("onde", "").get_slice(" < ", 0), " ", eb.d.get("onde", "").get_slice(" < ", 0))
		var chave := "%s|%s|%d|%s|%s" % [ea.et if ea.et != "" else _nome_estrutura(ea), eb.et if eb.et != "" else _nome_estrutura(eb), ax, String(ea.d.get("onde", "")).get_slice(" < ", 0), String(eb.d.get("onde", "")).get_slice(" < ", 0)]
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		var p := Vector3.ZERO
		p[ax] = f_c[a]
		p[u] = (maxf(f_u0[a], f_u0[b]) + minf(f_u1[a], f_u1[b])) * 0.5
		p[v] = (maxf(f_v0[a], f_v0[b]) + minf(f_v1[a], f_v1[b])) * 0.5
		if achou.has(chave):
			achou[chave]["area"] += area
			achou[chave]["n"] += 1
		else:
			achou[chave] = {"area": area, "n": 1, "a": ea, "b": eb, "p": p, "ax": ax, "dist": absf(f_c[a] - f_c[b])}
	var chaves := baldes.keys()
	for k in chaves:
		var lst: PackedInt32Array = baldes[k]
		# varredura por u0 dentro do balde e entre baldes vizinhos (mesmo eixo/sinal, coordenada +1 passo)
		var todos := PackedInt32Array(lst)
		if baldes.has(k + 6):
			todos.append_array(baldes[k + 6])
		var ord: Array = Array(todos)
		ord.sort_custom(func(x: int, y: int) -> bool: return f_u0[x] < f_u0[y])
		for ii in ord.size():
			var a: int = ord[ii]
			for jj in range(ii + 1, ord.size()):
				var b: int = ord[jj]
				if f_u0[b] >= f_u1[a] - 0.01:
					break
				if ov_ok(f_v0[a], f_v1[a], f_v0[b], f_v1[b]):
					# evita repetir pares (k+6)x(k+6) que serão vistos no balde seguinte
					if f_k[a] != k and f_k[b] != k:
						continue
					comparar.call(a, b)
	for ch in achou:
		var r: Dictionary = achou[ch]
		var ea: E = r["a"]
		var eb: E = r["b"]
		var area: float = r["area"]
		var grav := "A" if area >= 1.0 else ("M" if area >= 0.1 else "B")
		var ma: Dictionary = materiais.get(ea.d["material"], {})
		var mb: Dictionary = materiais.get(eb.d["material"], {})
		var intenc := false
		var motivo := ""
		var pa := _palavra_intencional(ea.et)
		var pb := _palavra_intencional(eb.et)
		if pa != "" or pb != "":
			intenc = true
			motivo = "nome sugere decalque/efeito"
		_acha("zfighting", grav, ea, r["p"], area * 10000.0, "faces coplanares (%s, dist %.1f mm) com materiais diferentes: '%s' (%s) x '%s' (%s); %d par(es), %.3f m2 sobrepostos" % [["X", "Y", "Z"][int(r["ax"])], float(r["dist"]) * 1000.0,
			ea.et if ea.et != "" else _nome_estrutura(ea), ma.get("nome", "?"), eb.et if eb.et != "" else _nome_estrutura(eb), mb.get("nome", "?"), int(r["n"]), area], intenc, motivo,
			{"outro": eb.et if eb.et != "" else _nome_estrutura(eb), "outro_arquivo": _arquivo(eb), "area_m2": snappedf(area, 0.001)})


static func ov_ok(a0: float, a1: float, b0: float, b1: float) -> bool:
	return minf(a1, b1) - maxf(a0, b0) > 0.01


# ============================================================================ 5) frestas (emendas com folga)
## Para cada borda de cada face ESTRUTURAL grande, amostra pontos: se não encosta (<= 4 mm) em nenhuma outra superfície
## mas há uma a menos de 9 cm numa direção que NÃO é a normal da face (camada/decalque), é uma fresta.
func checar_frestas() -> void:
	var fe: Array = []     # faces estruturais: [ent, ax, sg, co, u0,u1,v0,v1]
	for e in es:
		var ee: E = e
		if ee.col or ee.obj or not ee.visivel or ee.tipo == "no" or ee.tipo == "bolha" or ee.tipo == "rampa" or ee.tipo == "telhado" or ee.tipo == "piramide":
			continue
		if ee.tipo == "caixa":
			var spec := [[1, 0, 1], [2, 0, 0], [4, 1, 1], [8, 1, 0], [16, 2, 1], [32, 2, 0]]
			for sp in spec:
				if ee.faces & sp[0]:
					var ax: int = sp[1]
					var sg: int = sp[2]
					var u := (ax + 1) % 3
					var v := (ax + 2) % 3
					fe.append([ee, ax, sg, ee.mx[ax] if sg == 1 else ee.mn[ax], ee.mn[u], ee.mx[u], ee.mn[v], ee.mx[v]])
		elif ee.fino >= 0:
			var ax2: int = ee.fino
			var u2 := (ax2 + 1) % 3
			var v2 := (ax2 + 2) % 3
			fe.append([ee, ax2, 1 if ee.n[ax2] > 0 else 0, ee.mn[ax2], ee.mn[u2], ee.mx[u2], ee.mn[v2], ee.mx[v2]])
	# índice espacial das faces
	var gf := Grade.new(fe.size() + 1, 1.0)
	for i in fe.size():
		var f: Array = fe[i]
		var mn := Vector3.ZERO
		var mx := Vector3.ZERO
		var ax: int = f[1]
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		mn[ax] = f[3]
		mx[ax] = f[3]
		mn[u] = f[4]
		mx[u] = f[5]
		mn[v] = f[6]
		mx[v] = f[7]
		gf.inserir(i, mn, mx, 0.0)
	var achou := {}
	for fi in fe.size():
		var f: Array = fe[fi]
		var e: E = f[0]
		var ax: int = f[1]
		var u := (ax + 1) % 3
		var v := (ax + 2) % 3
		var u0: float = f[4]
		var u1: float = f[5]
		var v0: float = f[6]
		var v1: float = f[7]
		if (u1 - u0) * (v1 - v0) < 0.25 or minf(u1 - u0, v1 - v0) < 0.12:
			continue
		var co: float = f[3]
		# 4 arestas: (fixo = v0|v1, varia u) e (fixo = u0|u1, varia v)
		for aresta in 4:
			var comp := (u1 - u0) if aresta < 2 else (v1 - v0)
			var n_amostras := clampi(int(ceil(comp / 0.5)), 2, 12)
			for s in n_amostras:
				var t := float(s) / float(n_amostras - 1)
				var p := Vector3.ZERO
				p[ax] = co
				if aresta < 2:
					p[u] = lerpf(u0, u1, t)
					p[v] = v0 if aresta == 0 else v1
				else:
					p[v] = lerpf(v0, v1, t)
					p[u] = u0 if aresta == 2 else u1
				# recua 1 mm para dentro do canto (evita contar o canto como "encosta em si mesma")
				var cand := gf.consultar(p - Vector3.ONE * 0.09, p + Vector3.ONE * 0.09)
				var dmin := 99.0
				var qmin := Vector3.ZERO
				var gmin: E = null
				for gi in cand:
					if gi == fi:
						continue
					var g: Array = fe[gi]
					var ge: E = g[0]
					if (ge.epm & e.epm) == 0:
						continue
					var gax: int = g[1]
					var gu := (gax + 1) % 3
					var gv := (gax + 2) % 3
					var q := p
					q[gax] = g[3]
					q[gu] = clampf(p[gu], g[4], g[5])
					q[gv] = clampf(p[gv], g[6], g[7])
					var dd := p.distance_to(q)
					if dd < dmin:
						dmin = dd
						qmin = q
						gmin = ge
				if dmin <= 0.004 or dmin > 0.09:
					continue
				# camada paralela (decalque/tapete): o vão é ao longo da normal da face
				var dirv := (qmin - p).normalized()
				if absf(dirv[ax]) > 0.9:
					continue
				var chave := "%s|%s|%s" % [String(e.d.get("onde", "")).get_slice(" < ", 0), String(gmin.d.get("onde", "")).get_slice(" < ", 0), "%d" % ax]
				if achou.has(chave):
					var r: Dictionary = achou[chave]
					r["n"] += 1
					r["wmin"] = minf(r["wmin"], dmin)
					r["wmax"] = maxf(r["wmax"], dmin)
					r["bmn"] = (r["bmn"] as Vector3).min(p)
					r["bmx"] = (r["bmx"] as Vector3).max(p)
				else:
					achou[chave] = {"n": 1, "wmin": dmin, "wmax": dmin, "a": e, "b": gmin, "p": p, "bmn": p, "bmx": p, "ax": ax}
	for ch in achou:
		var r: Dictionary = achou[ch]
		var ea: E = r["a"]
		var eb: E = r["b"]
		var comp: float = ((r["bmx"] as Vector3) - (r["bmn"] as Vector3)).length()
		var w: float = r["wmin"]
		var grav := "M" if (int(r["n"]) >= 4 and w < 0.05) else "B"
		_acha("fresta", grav, ea, ((r["bmn"] as Vector3) + (r["bmx"] as Vector3)) * 0.5, w * 100.0,
			"emenda com folga de %.1f-%.1f cm entre '%s' e '%s' (%d pontos de borda, ~%.1f m de extensão)" % [w * 100.0, float(r["wmax"]) * 100.0, _nome_estrutura(ea), _nome_estrutura(eb), int(r["n"]), comp],
			false, "", {"outro_arquivo": _arquivo(eb), "extensao_m": snappedf(comp, 0.1), "pontos": int(r["n"])})


# ============================================================================ 6a) degraus de piso (emendas de altura)
func checar_degraus() -> void:
	var passo := 0.5
	var tops := []        # [ent, x0,x1,z0,z1,y]
	for e in es:
		var ee: E = e
		if ee.col or ee.obj or not ee.visivel or ee.tipo == "no" or ee.tipo == "rampa":
			continue
		if ee.tipo == "caixa" and (ee.faces & 4):
			tops.append([ee, ee.mn.x, ee.mx.x, ee.mn.z, ee.mx.z, ee.mx.y])
		elif ee.fino == 1 and ee.n.y > 0.0:
			tops.append([ee, ee.mn.x, ee.mx.x, ee.mn.z, ee.mx.z, ee.mn.y])
	var cel := {}
	for ti in tops.size():
		var t: Array = tops[ti]
		if t[5] > 12.0 or t[5] < -3.0:
			continue
		if (t[2] - t[1]) > 150.0 or (t[4] - t[3]) > 150.0:
			continue
		var ix0 := int(floor(t[1] / passo))
		var ix1 := int(floor(t[2] / passo))
		var iz0 := int(floor(t[3] / passo))
		var iz1 := int(floor(t[4] / passo))
		for ix in range(ix0, ix1 + 1):
			for iz in range(iz0, iz1 + 1):
				var k := Vector2i(ix, iz)
				if not cel.has(k):
					cel[k] = []
				(cel[k] as Array).append(ti)
	var achou := {}
	for kk in cel:
		var k: Vector2i = kk
		var lst: Array = cel[k]
		for dk in [Vector2i(1, 0), Vector2i(0, 1)]:
			var k2: Vector2i = k + dk
			if not cel.has(k2):
				continue
			var lst2: Array = cel[k2]
			for ia in lst:
				var ta: Array = tops[ia]
				var ea: E = ta[0]
				# o ponto central da célula tem de estar mesmo dentro da face
				var cx: float = (k.x + 0.5) * passo
				var cz: float = (k.y + 0.5) * passo
				if cx < ta[1] or cx > ta[2] or cz < ta[3] or cz > ta[4]:
					continue
				for ib in lst2:
					var tb: Array = tops[ib]
					var eb: E = tb[0]
					if (ea.epm & eb.epm) == 0 or ea == eb:
						continue
					var cx2: float = (k2.x + 0.5) * passo
					var cz2: float = (k2.y + 0.5) * passo
					if cx2 < tb[1] or cx2 > tb[2] or cz2 < tb[3] or cz2 > tb[4]:
						continue
					var dy := absf(ta[5] - tb[5])
					if dy < 0.008 or dy > 0.12:
						continue
					# existe alguma superfície na célula A ou B no meio dessa diferença? (então é escada/rampa)
					var ch := "%s|%s" % [String(ea.d.get("onde", "")).get_slice(" < ", 0), String(eb.d.get("onde", "")).get_slice(" < ", 0)]
					var p := Vector3((cx + cx2) * 0.5, maxf(ta[5], tb[5]), (cz + cz2) * 0.5)
					if achou.has(ch):
						achou[ch]["n"] += 1
						achou[ch]["dy"] = maxf(achou[ch]["dy"], dy)
						achou[ch]["bmn"] = (achou[ch]["bmn"] as Vector3).min(p)
						achou[ch]["bmx"] = (achou[ch]["bmx"] as Vector3).max(p)
					else:
						achou[ch] = {"n": 1, "dy": dy, "a": ea, "b": eb, "p": p, "bmn": p, "bmx": p}
	for ch in achou:
		var r: Dictionary = achou[ch]
		var dy: float = r["dy"]
		var ea: E = r["a"]
		var eb: E = r["b"]
		var grav := "M" if dy >= 0.03 else "B"
		_acha("degrau_de_piso", grav, ea, ((r["bmn"] as Vector3) + (r["bmx"] as Vector3)) * 0.5, dy * 100.0,
			"pisos vizinhos '%s' e '%s' com %.1f cm de diferença de altura (%d células de %.1f m)" % [_nome_estrutura(ea), _nome_estrutura(eb), dy * 100.0, int(r["n"]), passo],
			false, "", {"outro_arquivo": _arquivo(eb), "celulas": int(r["n"])})


# ============================================================================ depuração
## COLOC_DEBUG=etiqueta1,etiqueta2 : imprime as entradas do objeto e as vizinhas (até 0,5 m).
func depurar(nomes: PackedStringArray) -> void:
	for nm in nomes:
		for c in _clusters:
			if (c[0] as E).et != nm:
				continue
			var bb := _bb_cluster(c)
			print("== DEBUG ", nm, " bb ", bb, " épocas ", nomes_epocas(_epm_cluster(c)))
			var n_ep := 0
			for o in es:
				if (o as E).epm == (_epm_cluster(c)) and dist_caixas(bb.position, bb.end, (o as E).mn, (o as E).mx) < 0.5:
					n_ep += 1
			print("   entradas da mesma época perto (varredura linear): ", n_ep)
			for e in c:
				var ee: E = e
				print("   [obj] ", ee.tipo, " ", ee.mn, " ", ee.mx, " ", ee.d.get("onde", ""))
			for i in grade.consultar(bb.position - Vector3.ONE * 0.5, bb.end + Vector3.ONE * 0.5):
				var o: E = es[i]
				if o.cl == (c[0] as E).cl:
					continue
				if dist_caixas(bb.position, bb.end, o.mn, o.mx) < 0.5:
					print("   [viz] ", o.tipo, " et='", o.et, "' ", o.mn, " ", o.mx, " n=", o.n, " ep=", nomes_epocas(o.epm), " ", String(o.d.get("onde", "")).get_slice(" < ", 0))
			break
