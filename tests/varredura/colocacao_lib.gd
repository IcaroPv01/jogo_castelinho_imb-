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

## EXCEÇÕES CONHECIDAS (revisadas na fase 2 do módulo 10): achados que parecem erro mas foram avaliados como
## de propósito, ou ficaram como DÚVIDA para o Icaro (tools/galeria/duvidas.json). {tipo, padrao, motivo}: casa se
## `padrao` aparece na etiqueta, no arquivo:linha, no detalhe ou no arquivo do outro objeto. O teste de regressão
## (tests/colocacao_test.gd) falha para qualquer achado "real" que NÃO esteja aqui.
const EXCECOES := [
	{"tipo": "flutuando", "padrao": "painel_p", "motivo": "painel de parede/poste: a base fica acima do piso por desenho (preso pela lateral)"},
	{"tipo": "flutuando", "padrao": "buraco_muro_dentes", "motivo": "dentes de bloco quebrado presos às bordas do buraco do muro (1967)"},
	{"tipo": "flutuando", "padrao": "PainelSolto", "motivo": "o painel P08 se solta da parede de propósito (evento da Sala dos Povos)"},
	{"tipo": "enfiado", "padrao": "painel_p", "motivo": "a moldura do painel afunda ~8 cm na parede (montagem rente); o texto fica na frente"},
	{"tipo": "enfiado", "padrao": "Arcada/MeshInstance3D", "motivo": "colar do pilar 0 da arcada, rente à parede dos fundos da casa (junção)"},
	{"tipo": "enfiado", "padrao": "TitoNaMargem", "motivo": "as canelas do Tito sentado pendem para fora do meio-fio e cruzam a barreira INVISÍVEL que impede de cair no lago"},
	{"tipo": "enfiado", "padrao": "Slide", "motivo": "DÚVIDA: menino sentado nos slides do último dia afunda no piso (pose sentada pensada para uma borda); ver duvidas.json"},
	{"tipo": "atravessa_parede", "padrao": "casa_vizinha", "motivo": "DÚVIDA: o corredor de 1975 atravessa casas vizinhas (pode ser a impossibilidade de propósito); ver duvidas.json"},
	{"tipo": "atravessa_parede", "padrao": "cadeira_medieval", "motivo": "fita zebrada da visita 4 passa rente à cadeira (5 cm)"},
	{"tipo": "degrau_de_piso", "padrao": "_gramado", "motivo": "caminho de lajotas 3 cm acima do gramado: camada visual, o chão de colisão é plano"},
	{"tipo": "zfighting", "padrao": "parapeito", "motivo": "parapeito x ameia: mesmo shader com tons parecidos, 0,1 m2 a 4 m de altura"},
	{"tipo": "zfighting", "padrao": "merloes", "motivo": "ameia x parede: mesmo shader com tons parecidos, 0,07 m2 a 4 m de altura"},
	{"tipo": "zfighting", "padrao": "_escada_torre", "motivo": "contato bloco da escada x parede: 0,03 m2, encostado e sem vista"},
	{"tipo": "zfighting", "padrao": "_escada_patio", "motivo": "contato bloco da escada x parede: 0,03 m2, encostado e sem vista"},
	{"tipo": "zfighting", "padrao": "criar_tito", "motivo": "peças do boneco do Tito (112 cm2, caixas encostadas do mesmo corpo)"},
	{"tipo": "zfighting", "padrao": "Arcada/MeshInstance3D", "motivo": "vigas de madeira rentes ao topo/face externa da parede da arcada (0,09 m2 cada, lado de fora)"},
	{"tipo": "zfighting", "padrao": "porao_salas.gd:346", "motivo": "moldura da cela: 192 cm2, atrás das barras"},
	{"tipo": "zfighting", "padrao": "_escada_do_porao", "motivo": "poço da escada do Braço Morto: 0,12 m2 entre degrau e muro lateral, no escuro"},
]

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
	if not d["provavel_intencional"]:
		var texto: String = "%s|%s|%s|%s" % [d["etiqueta"], d["arquivo"], d["detalhe"], d.get("outro_arquivo", "")]
		for ex in EXCECOES:
			if ex["tipo"] == tipo and texto.contains(ex["padrao"]):
				d["provavel_intencional"] = true
				d["motivo"] = "exceção documentada: " + ex["motivo"]
				d["excecao"] = true
				break
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


const _PAL_INTENC := ["luz", "chama", "brilho", "halo", "raio", "sombra", "mancha", "fumaca", "poeira", "faisca", "particula", "brasa", "fogo", "vento", "agua", "onda", "espuma",
	"passaporte", "caca_", "disco_", "chuva", "montinho", "recolhida", "pegada", "rastro", "mosca", "estrela", "brilha", "lampada", "balao", "folha_costela"]
const _PAL_VAO := ["vidro", "porta", "janela", "grade", "arco", "veneziana", "folha_e", "folha_d"]


## O sólido cabe inteiro dentro do objeto em dois eixos (colar de pilar, moldura): a sobreposição é só o miolo do próprio sólido.
static func _envolve(o: E, s: E) -> bool:
	var dentro := 0
	for ax in 3:
		if s.mn[ax] >= o.mn[ax] - 0.01 and s.mx[ax] <= o.mx[ax] + 0.01:
			dentro += 1
	return dentro >= 2


static func _palavra_vao(et: String) -> String:
	var l := et.to_lower()
	for p in _PAL_VAO:
		if l.contains(p):
			return p
	return ""


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
		var motivo := ("nome sugere efeito/objeto flutuante de propósito (%s)" % pal) if pal != "" else ("material emissivo/sem luz" if emis else "")
		if gap_y <= FOLGA or gap_up <= FOLGA:
			continue
		var fino_min := minf(tam.x, minf(tam.y, tam.z))
		if not intenc and fino_min <= 0.05 and gap_any <= 0.055:
			intenc = true
			motivo = "folha/decalque fino afastado ~%.0f cm do plano de propósito (anti z-fighting)" % (gap_any * 100.0)
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
		elif _palavra_vao(e0.et) != "":
			intenc = true
			motivo = "peça de vão (%s): fica dentro da espessura da parede; o colisor do vão é aproximado" % _palavra_vao(e0.et)
		elif _envolve(melhor, melhor_s) and not melhor_atrav:
			intenc = true
			motivo = "o objeto ENVOLVE o sólido (colar/moldura em volta de pilar ou poste)"
		elif minf(ts2.x, minf(ts2.y, ts2.z)) <= 0.12 and _bb_cluster(c).size.length() >= 0.9 and not melhor_atrav:
			intenc = true
			motivo = "poste/haste fina fixa o objeto (sobreposição de fixação)"
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
		var oculta := _face_oculta(ea, eb, ax, f_sg[a], f_c[a], (maxf(f_u0[a], f_u0[b]) + minf(f_u1[a], f_u1[b])) * 0.5, (maxf(f_v0[a], f_v0[b]) + minf(f_v1[a], f_v1[b])) * 0.5)
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
			achou[chave]["oculta"] = achou[chave]["oculta"] and oculta
		else:
			achou[chave] = {"area": area, "n": 1, "a": ea, "b": eb, "p": p, "ax": ax, "dist": absf(f_c[a] - f_c[b]), "oculta": oculta}
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
		var so := String(ea.d.get("onde", "")) + String(eb.d.get("onde", ""))
		if r["oculta"]:
			intenc = true
			motivo = "faces voltadas para dentro de outro sólido (não aparecem)"
			grav = "B"
		elif pa != "" or pb != "":
			intenc = true
			motivo = "nome sugere decalque/efeito"
		elif so.contains("sombras.gd") or ma.get("transparente", false) or mb.get("transparente", false):
			intenc = true
			motivo = "decalque/sombra pintada sobre o chão (coplanar de propósito, material transparente/multiplicado)"
		_acha("zfighting", grav, ea, r["p"], area * 10000.0, "faces coplanares (%s, dist %.1f mm) com materiais diferentes: '%s' (%s) x '%s' (%s); %d par(es), %.3f m2 sobrepostos" % [["X", "Y", "Z"][int(r["ax"])], float(r["dist"]) * 1000.0,
			ea.et if ea.et != "" else _nome_estrutura(ea), ma.get("nome", "?"), eb.et if eb.et != "" else _nome_estrutura(eb), mb.get("nome", "?"), int(r["n"]), area], intenc, motivo,
			{"outro": eb.et if eb.et != "" else _nome_estrutura(eb), "outro_arquivo": _arquivo(eb), "area_m2": snappedf(area, 0.001)})


## A face (eixo ax, sinal sg, coordenada co, ponto u,v no plano) aponta para dentro de uma caixa sólida (ou seja, não aparece)?
func _face_oculta(ea: E, eb: E, ax: int, sg: int, co: float, u: float, v: float) -> bool:
	if ax == 1 and sg == 0 and absf(co) <= 0.02:
		return true          # face de baixo no nível do chão: nunca aparece
	var q := Vector3.ZERO
	q[ax] = co + (0.01 if sg == 1 else -0.01)
	q[(ax + 1) % 3] = u
	q[(ax + 2) % 3] = v
	for i in grade.consultar(q - Vector3.ONE * 0.02, q + Vector3.ONE * 0.02):
		var o: E = es[i]
		if o == ea or o == eb or o.tipo != "caixa" or (o.epm & ea.epm) == 0:
			continue
		var t := o.tam()
		if minf(t.x, minf(t.y, t.z)) < 0.03:
			continue
		if q.x > o.mn.x + 0.001 and q.x < o.mx.x - 0.001 and q.y > o.mn.y + 0.001 and q.y < o.mx.y - 0.001 and q.z > o.mn.z + 0.001 and q.z < o.mx.z - 0.001:
			return true
	return false


static func ov_ok(a0: float, a1: float, b0: float, b1: float) -> bool:
	return minf(a1, b1) - maxf(a0, b0) > 0.01


# ============================================================================ 5) frestas (emendas com folga)
## Para cada borda de cada face ESTRUTURAL grande, amostra pontos: se não encosta (<= 4 mm) em nenhuma outra superfície
## mas há uma a menos de 9 cm numa direção que NÃO é a normal da face (camada/decalque), é uma fresta. Cada fresta
## é confirmada por um RAIO que atravessa o vão (nas duas direções da normal): se escapa (> 60 m sem bater em nada
## estrutural) a luz/o vazio aparece pelo buraco.
var _fe: Array = []        # faces estruturais [ent, ax, sg, co, u0,u1,v0,v1]
var _gf: Grade


func _montar_faces_estruturais() -> void:
	_fe = []
	for e in es:
		var ee: E = e
		if ee.col or ee.obj or not ee.visivel or ee.tipo == "no" or ee.tipo == "bolha" or ee.tipo == "rampa" or ee.tipo == "telhado" or ee.tipo == "piramide":
			continue
		if ee.transp:
			continue
		if ee.tipo == "caixa":
			var spec := [[1, 0, 1], [2, 0, 0], [4, 1, 1], [8, 1, 0], [16, 2, 1], [32, 2, 0]]
			for sp in spec:
				if ee.faces & sp[0]:
					var ax: int = sp[1]
					var sg: int = sp[2]
					var u := (ax + 1) % 3
					var v := (ax + 2) % 3
					_fe.append([ee, ax, sg, ee.mx[ax] if sg == 1 else ee.mn[ax], ee.mn[u], ee.mx[u], ee.mn[v], ee.mx[v]])
		elif ee.fino >= 0:
			var ax2: int = ee.fino
			var u2 := (ax2 + 1) % 3
			var v2 := (ax2 + 2) % 3
			var bba := (ee.mx[u2] - ee.mn[u2]) * (ee.mx[v2] - ee.mn[v2])
			var retangular := ee.tipo == "quad" and ee.area >= 0.9995 * bba
			_fe.append([ee, ax2, 1 if ee.n[ax2] > 0 else 0, ee.mn[ax2], ee.mn[u2], ee.mx[u2], ee.mn[v2], ee.mx[v2], retangular])
	_gf = Grade.new(_fe.size() + 1, 1.0)
	for i in _fe.size():
		var f: Array = _fe[i]
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
		_gf.inserir(i, mn, mx, 0.0)


## O raio de `p` na direção `dir` escapa (nenhuma face estrutural em `alcance` m)?  `engorda` = tolerância (m) de cada face.
func _raio_escapa(p: Vector3, dir: Vector3, alcance := 60.0, engorda := 0.0) -> bool:
	var passo := 0.75
	var t := 0.0
	var q0 := p
	while t < alcance:
		var q1 := q0 + dir * passo
		var mn := q0.min(q1) - Vector3.ONE * (0.01 + engorda)
		var mx := q0.max(q1) + Vector3.ONE * (0.01 + engorda)
		for fi in _gf.consultar(mn, mx):
			var f: Array = _fe[fi]
			var ax: int = f[1]
			var co: float = f[3]
			var d0 := q0[ax] - co
			var d1 := q1[ax] - co
			if (d0 > engorda and d1 > engorda) or (d0 < -engorda and d1 < -engorda):
				continue
			var den := q1[ax] - q0[ax]
			var tt := 0.0 if absf(den) < 1e-9 else clampf((co - q0[ax]) / den, 0.0, 1.0)
			var hit := q0 + (q1 - q0) * tt
			var u := (ax + 1) % 3
			var v := (ax + 2) % 3
			if hit[u] >= f[4] - engorda and hit[u] <= f[5] + engorda and hit[v] >= f[6] - engorda and hit[v] <= f[7] + engorda:
				if t + tt * passo > 0.03:
					return false
		q0 = q1
		t += passo
	return true


func checar_frestas() -> void:
	_montar_faces_estruturais()
	var achou := {}
	for fi in _fe.size():
		var f: Array = _fe[fi]
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
		if f.size() > 8 and not f[8]:
			continue          # triângulo/trapézio: as bordas do AABB não são bordas reais
		if String(e.d.get("no", "")).contains("Agua"):
			continue          # plano d'água: passa de propósito da parede
		for aresta in 4:
			var comp := (u1 - u0) if aresta < 2 else (v1 - v0)
			var n_amostras := clampi(int(ceil(comp / 0.5)), 2, 14)
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
				var dmin := 99.0
				var qmin := Vector3.ZERO
				var gmin: E = null
				for gi in _gf.consultar(p - Vector3.ONE * 0.09, p + Vector3.ONE * 0.09):
					if gi == fi:
						continue
					var g: Array = _fe[gi]
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
				if OS.get_environment("COLOC_FRESTA") != "":
					var pp := OS.get_environment("COLOC_FRESTA").split(",")
					if p.distance_to(Vector3(float(pp[0]), float(pp[1]), float(pp[2]))) < 0.6:
						print("FR p=", p, " f ax=", ax, " rect u[", u0, ",", u1, "] v[", v0, ",", v1, "] co=", co, " vizinho=", qmin, " d=", dmin, " ", String(e.d.get("onde", "")).get_slice(" < ", 0), " | ", String(gmin.d.get("onde", "")).get_slice(" < ", 0))
				var dirv := (qmin - p).normalized()
				if absf(dirv[ax]) > 0.9:
					continue          # camada paralela (decalque)
				var celula := "%d,%d,%d" % [floori(p.x / 2.0), floori(p.y / 2.0), floori(p.z / 2.0)]
				var chave := "%s|%s|%d|%s" % [String(e.d.get("onde", "")).get_slice(" < ", 0), String(gmin.d.get("onde", "")).get_slice(" < ", 0), ax, celula]
				var meio := (p + qmin) * 0.5
				var nrm := Vector3.ZERO
				nrm[ax] = 1.0
				if achou.has(chave):
					var r: Dictionary = achou[chave]
					r["n"] += 1
					r["wmin"] = minf(r["wmin"], dmin)
					r["wmax"] = maxf(r["wmax"], dmin)
					r["bmn"] = (r["bmn"] as Vector3).min(meio)
					r["bmx"] = (r["bmx"] as Vector3).max(meio)
					if (r["amostras"] as Array).size() < 6:
						r["amostras"].append(meio)
				else:
					achou[chave] = {"n": 1, "wmin": dmin, "wmax": dmin, "a": e, "b": gmin, "bmn": meio, "bmx": meio, "ax": ax, "nrm": nrm, "amostras": [meio]}
	for ch in achou:
		var r: Dictionary = achou[ch]
		var ea: E = r["a"]
		var eb: E = r["b"]
		var comp: float = ((r["bmx"] as Vector3) - (r["bmn"] as Vector3)).length()
		var w: float = r["wmin"]
		if int(r["n"]) < 2:
			continue          # um ponto isolado não é fresta
		# confirmação por raio: de um ponto no vão, nas duas direções da normal
		var nrm: Vector3 = r["nrm"]
		var escapa := false
		var lados := 0
		for am in r["amostras"]:
			for sg in [-1.0, 1.0]:
				if _raio_escapa((am as Vector3) + nrm * sg * 0.02, nrm * sg):
					escapa = true
					lados += 1
		var grav := "B"
		if escapa and int(r["n"]) >= 3:
			grav = "A" if (w < 0.06 and comp >= 1.0) else "M"
		elif escapa or (int(r["n"]) >= 4 and w < 0.05):
			grav = "M"
		_acha("fresta", grav, ea, ((r["bmn"] as Vector3) + (r["bmx"] as Vector3)) * 0.5, w * 100.0,
			"emenda com folga de %.1f-%.1f cm entre '%s' e '%s' (%d pontos de borda, ~%.1f m); %s" % [w * 100.0, float(r["wmax"]) * 100.0, _nome_estrutura(ea), _nome_estrutura(eb), int(r["n"]), comp,
				("o RAIO ATRAVESSA o vão e escapa (>60 m): vê-se o vazio/céu pela fresta" if escapa else "o raio pelo vão bate em algo (fresta sem vazamento)")],
			false, "", {"outro_arquivo": _arquivo(eb), "extensao_m": snappedf(comp, 0.1), "pontos": int(r["n"]), "vaza_luz": escapa})


# ============================================================================ 6a) degraus de piso (emendas de altura)
func checar_degraus() -> void:
	var passo := 0.5
	var tops: Array = []        # [ent, x0,x1,z0,z1,y]
	for e in es:
		var ee: E = e
		if ee.col or ee.obj or not ee.visivel or ee.tipo == "no" or ee.tipo == "rampa" or ee.transp:
			continue
		if String(ee.d.get("onde", "")).contains("sombras.gd") or ee.d.get("no", "") != "":
			continue
		if ee.tipo == "caixa" and (ee.faces & 4):
			tops.append([ee, ee.mn.x, ee.mx.x, ee.mn.z, ee.mx.z, ee.mx.y])
		elif ee.fino == 1 and ee.n.y > 0.0 and ee.area <= 0.0 or (ee.fino == 1 and ee.n.y > 0.0 and ee.area >= 0.5 * (ee.mx.x - ee.mn.x) * (ee.mx.z - ee.mn.z)):
			tops.append([ee, ee.mn.x, ee.mx.x, ee.mn.z, ee.mx.z, ee.mn.y])
	var cel := {}
	for ti in tops.size():
		var t: Array = tops[ti]
		if t[5] > 12.0 or t[5] < -3.0:
			continue
		if (t[2] - t[1]) < 0.4 or (t[4] - t[3]) < 0.4:
			continue
		if (t[2] - t[1]) > 150.0 or (t[4] - t[3]) > 150.0:
			continue
		var ix0 := int(floor(t[1] / passo))
		var ix1 := int(floor(t[2] / passo))
		var iz0 := int(floor(t[3] / passo))
		var iz1 := int(floor(t[4] / passo))
		for ix in range(ix0, ix1 + 1):
			for iz in range(iz0, iz1 + 1):
				var cx: float = (ix + 0.5) * passo
				var cz: float = (iz + 0.5) * passo
				if cx < t[1] or cx > t[2] or cz < t[3] or cz > t[4]:
					continue
				var k := Vector2i(ix, iz)
				if not cel.has(k):
					cel[k] = []
				(cel[k] as Array).append(ti)
	# níveis por célula: tops agrupados (<= 12 cm) -> nível = o mais alto
	var niveis := {}
	for kk in cel:
		var k: Vector2i = kk
		var lst: Array = (cel[k] as Array).duplicate()
		lst.sort_custom(func(a: int, b: int) -> bool: return tops[a][5] < tops[b][5])
		var res: Array = []
		var grupo: Array = []
		for ti in lst:
			if grupo.is_empty() or tops[ti][5] - tops[grupo[grupo.size() - 1]][5] <= 0.12:
				grupo.append(ti)
			else:
				res.append(grupo[grupo.size() - 1])
				grupo = [ti]
		if not grupo.is_empty():
			res.append(grupo[grupo.size() - 1])
		niveis[k] = res
	var achou := {}
	for kk in niveis:
		var k: Vector2i = kk
		for dk in [Vector2i(1, 0), Vector2i(0, 1)]:
			var k2: Vector2i = k + dk
			if not niveis.has(k2):
				continue
			for ia in niveis[k]:
				var ta: Array = tops[ia]
				var melhor := -1
				var md := 99.0
				for ib in niveis[k2]:
					var dd := absf(ta[5] - tops[ib][5])
					if dd < md:
						md = dd
						melhor = ib
				if melhor < 0 or md < 0.02 or md > 0.12:
					continue
				var tb: Array = tops[melhor]
				var ea: E = ta[0]
				var eb: E = tb[0]
				if (ea.epm & eb.epm) == 0 or ea == eb:
					continue
				var p := Vector3((k.x + 0.5 + dk.x * 0.5) * passo, maxf(ta[5], tb[5]), (k.y + 0.5 + dk.y * 0.5) * passo)
				var ch := "%d,%d,%d" % [floori(p.x / 3.0), floori(p.z / 3.0), roundi(p.y * 2.0)]
				if achou.has(ch):
					var r: Dictionary = achou[ch]
					r["n"] += 1
					r["dy"] = maxf(r["dy"], md)
					r["bmn"] = (r["bmn"] as Vector3).min(p)
					r["bmx"] = (r["bmx"] as Vector3).max(p)
				else:
					achou[ch] = {"n": 1, "dy": md, "a": ea, "b": eb, "bmn": p, "bmx": p}
	for ch in achou:
		var r: Dictionary = achou[ch]
		var dy: float = r["dy"]
		var ea: E = r["a"]
		var eb: E = r["b"]
		if int(r["n"]) < 2:
			continue
		var grav := "M" if dy >= 0.04 else "B"
		_acha("degrau_de_piso", grav, ea, ((r["bmn"] as Vector3) + (r["bmx"] as Vector3)) * 0.5, dy * 100.0,
			"pisos vizinhos '%s' e '%s' com até %.1f cm de diferença de altura (%d células de %.1f m)" % [_nome_estrutura(ea), _nome_estrutura(eb), dy * 100.0, int(r["n"]), passo],
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
