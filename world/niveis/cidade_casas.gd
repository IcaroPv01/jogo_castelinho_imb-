extends CidadeBase
## LUGAR DA CIDADE: Rua das casas de veraneio (Módulo 14). Fim de tarde, cidade-jardim com ruas curvas, canteiros, pinheiros e
## palmeiras, oito casas de veraneio FECHADAS (fora da temporada) e uma com a luz acesa. Tudo FICTÍCIO: números e casas inventados,
## nenhuma pessoa, família ou rua real. A calma é o susto: não há perseguição, nem morte, nem o Tito em perigo (só sugestão).
##
## TAREFA: achar a casa certa. Os números estão fora de ordem.
##   1. O cartaz de PROCURA-SE de 1967 (num poste, desbotado) diz o número (7) e uma marca: balde vermelho no quintal.
##   2. A casa 7 está trancada. Um bilhete diz: "chave sob o vaso da casa de FRENTE" (a 18, do outro lado da rua). O vaso do
##      próprio 7 é a pegadinha ("só terra"). A luz acesa da casa 36 é outra: temporizador quebrado, casa errada.
##   3. Com a chave o portão abre e a porta da casa fica encostada. Dentro: PISTA 1 `casas_caderno` (caderno de desenhos com o T
##      de cabeça para baixo, em 2020) e PISTA 2 `casas_mala` (a mala feita às pressas, só no quarto VIVO de 1967: Visor, disco 1967).
##   O disco de 1967 só vem do Acervo (Visita 2). Sem ele a casa mostra só a pista 1, uma voz diz para voltar com o Visor, e o
##   jogador pode sair quando quiser (`sair()` é livre). `concluir()` só com as duas pistas. A mãe do Tito (fictícia) é só VOZ.
## Progresso (flags, para não perder ao sair): casas_cartaz, casas_bilhete, casas_chave, casas_portao. Pistas: pista_casas_caderno,
## pista_casas_mala (contam uma vez, `pista()` da base). Dica quando demora: DEMORA_DICA s no mesmo passo (fala + Mapa).
## Orçamento web: 5 malhas combinadas (vertex color), 4 MultiMesh, 6 luzes no máximo, sem sombra.

const RUA_MEIA := 3.2            # metade da pista (m)
const CALCADA := 1.6
const FRENTE := 7.8              # eixo da rua até a frente das casas
const CERCA_Z := 2.7             # da frente da casa até a cerca (m, no sentido da rua)
const LOTE := 6.25               # meia largura do lote
const ZC_AMP := 2.0              # a rua faz uma curva suave: z = ZC_AMP * sin(ZC_K * x)
const ZC_K := 0.12
const ALTURA := 3.0

const NUMERO_CERTO := "7"
const ALVO_W := 8.4              # a casa 7 é maior: dá para entrar
const ALVO_D := 6.0
const GX_ALVO := -2.4            # x (local) do portão e da porta da 7
const DEMORA_DICA := 60.0        # s no mesmo passo até a primeira dica automática (a 2ª vem com o dobro)

## Passos da tarefa (o objetivo do Mapa e as dicas dependem do passo).
enum Passo { CARTAZ, NUMERO, CHAVE, PORTAO, CASA, MALA, FIM }

## As casas. lado: -1 = norte (esquerda de quem olha para leste), 1 = sul. gx = x local do portão e da porta.
const CASAS := [
	{"n": "9", "x": -21.0, "lado": -1, "gx": -0.6, "parede": Color(0.62, 0.76, 0.88), "telha": Color(0.58, 0.3, 0.24),
		"persiana": Color(0.25, 0.4, 0.58), "extras": ["bici", "aluga"], "balde": Color(0.95, 0.8, 0.2), "bici": Color(0.75, 0.2, 0.2),
		"vaso": "Só terra e uma samambaia seca.",
		"portao": "Casa 9. Portão trancado. Uma bicicleta encostada na cerca, com a corrente enferrujada."},
	{"n": "36", "x": -6.5, "lado": -1, "gx": 0.6, "parede": Color(0.92, 0.68, 0.58), "telha": Color(0.5, 0.5, 0.52),
		"persiana": Color(0.55, 0.3, 0.25), "extras": ["luz", "aluga"], "balde": Color(0.3, 0.7, 0.4),
		"vaso": "Só terra. A planta morreu faz tempo, mas o vaso continua aqui.",
		"portao": "Casa 36. A luz da sala está acesa, mas ninguém atende. Um bilhete na grade: 'O temporizador quebrou. A luz fica acesa desde o fim do verão. Não adianta apagar. — Caseiro'"},
	{"n": "18", "x": 12.5, "lado": -1, "gx": 0.9, "parede": Color(0.66, 0.82, 0.72), "telha": Color(0.6, 0.33, 0.25),
		"persiana": Color(0.3, 0.5, 0.4), "extras": ["carro"], "balde": Color(0.3, 0.55, 0.85),
		"vaso": "Embaixo do vaso, uma chavinha enferrujada.",
		"portao": "Casa 18. Portão trancado. O carro dorme debaixo de uma capa cinza."},
	{"n": "72", "x": 24.0, "lado": -1, "gx": -0.9, "parede": Color(0.9, 0.88, 0.82), "telha": Color(0.45, 0.28, 0.3),
		"persiana": Color(0.35, 0.35, 0.4), "extras": ["bici", "aluga_velha"], "balde": Color(0.25, 0.45, 0.9), "bici": Color(0.85, 0.15, 0.15),
		"vaso": "Uma flor de plástico, desbotada de sol.",
		"portao": "Casa 72. Uma placa velha: 'ALUGA-SE — TEMPORADA 67/68'. Ninguém tirou."},
	{"n": "40", "x": -19.0, "lado": 1, "gx": 0.3, "parede": Color(0.58, 0.42, 0.3), "telha": Color(0.3, 0.3, 0.32),
		"persiana": Color(0.35, 0.25, 0.18), "extras": ["carro"], "balde": Color(0.9, 0.5, 0.2),
		"vaso": "Só terra e folhas de pinheiro.",
		"portao": "Casa 40. Chalé de madeira, venezianas fechadas. Cheira a mar guardado."},
	{"n": "5", "x": -3.5, "lado": 1, "gx": -0.4, "parede": Color(0.9, 0.72, 0.74), "telha": Color(0.58, 0.3, 0.24),
		"persiana": Color(0.5, 0.25, 0.35), "extras": ["aluga"], "balde": Color(0.95, 0.8, 0.2),
		"vaso": "Só terra. Um caracolzinho dorme na borda.",
		"portao": "Casa 5. ALUGA-SE. As venezianas estão fechadas há meses."},
	{"n": "7", "x": 11.0, "lado": 1, "gx": -2.4, "parede": Color(0.93, 0.85, 0.62), "telha": Color(0.55, 0.28, 0.22),
		"persiana": Color(0.28, 0.45, 0.62), "extras": [], "balde": Color(0.85, 0.1, 0.1),
		"vaso": "Só terra e uma samambaia seca.",
		"portao": "Casa 7."},
	{"n": "14", "x": 25.0, "lado": 1, "gx": 0.7, "parede": Color(0.55, 0.65, 0.82), "telha": Color(0.5, 0.5, 0.52),
		"persiana": Color(0.85, 0.85, 0.88), "extras": ["bici", "carro"], "balde": Color(0.3, 0.7, 0.4), "bici": Color(0.2, 0.4, 0.8),
		"vaso": "Só terra. Alguém já regou isto faz muito tempo.",
		"portao": "Casa 14. Fechada. Uma bicicleta e um carro cobertos de pó."},
]

const COR_ASFALTO := Color(1, 1, 1)

# ---- estado da tarefa
var tempo_passo := 0.0            # s no passo atual (dica quando passa de DEMORA_DICA)
var dicas_faladas := 0            # quantas dicas deste passo já foram faladas
var chamadas_mae := 0             # quantas vezes a voz da mãe foi ouvida (uma só)
var dentro_casa := false
var no_quarto := false
var _passo_ultimo := -1
var _concluindo := false

# ---- objetos
var _corpo: StaticBody3D
var _g: MB                        # malha geral (vertex color + grão)
var _gi: MB                       # a casa 7 por dentro (com um pouco de luz própria: dentro é escuro)
var _p: MB                        # plantas e coisas planas (vertex color, sem textura)
var _l: MB                        # luz (sem sombreamento)
var _asf: MB
var _cal: MB
var _casa7: Node3D
var _portao_folha: Node3D
var _portao_col: CollisionShape3D
var _portao_it: Interagivel
var _porta_folha: Node3D
var _porta_col: CollisionShape3D
var _luz_varanda: OmniLight3D
var _brilho_varanda: MeshInstance3D
var _vaso_chave_it: Interagivel
var _grupo20: Node3D
var _grupo67: Node3D
var _brilhos: Dictionary = {}     # nome -> [nó, flag que o apaga]: brilhos dourados que chamam o olho para o que se pode pegar
var _legenda_lbl: Label
var _legenda_tween: Tween
var _tex_cache := {}
var _pegadas: Array[Rect2] = []
var _portoes_x: Array[float] = []


# ============================================================================ malha combinada (vertex color)
## Acumula triângulos coloridos (poucos draw calls). Os pontos entram em coordenadas LOCAIS e saem por `base`.
## Cada face é virada para fora do centro da peça (formas convexas), então não há erro de enrolamento.
class MB extends RefCounted:
	const CARAS := [[0, 2, 6, 4], [1, 3, 7, 5], [0, 1, 5, 4], [2, 3, 7, 6], [0, 1, 3, 2], [4, 5, 7, 6]]
	var base := Transform3D.IDENTITY
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()

	func tri(a: Vector3, b: Vector3, d: Vector3, col: Color, centro: Vector3) -> void:
		var nn := (b - a).cross(d - a)
		if nn.length_squared() < 1.0e-10:
			return
		nn = nn.normalized()
		if nn.dot((a + b + d) / 3.0 - centro) >= 0.0:
			_empurra(a, d, b, nn, col)      # Godot: face da frente = sentido horário
		else:
			_empurra(a, b, d, -nn, col)

	func quad(a: Vector3, b: Vector3, d: Vector3, e: Vector3, col: Color, centro: Vector3) -> void:
		tri(a, b, d, col, centro)
		tri(a, d, e, col, centro)

	func _empurra(a: Vector3, b: Vector3, d: Vector3, nn: Vector3, col: Color) -> void:
		v.append(a)
		v.append(b)
		v.append(d)
		for i in 3:
			n.append(nn)
			c.append(col)

	func box(pos: Vector3, tam: Vector3, col: Color, rot := Basis.IDENTITY) -> void:
		var t := base * Transform3D(rot, pos)
		var h := tam * 0.5
		var p: Array[Vector3] = []
		for i in 8:
			p.append(t * Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z))
		for f in CARAS:
			quad(p[f[0]], p[f[1]], p[f[2]], p[f[3]], col, t.origin)

	## Telhado de duas águas: cumeeira ao longo de x. `pos` = meio da base (nível do beiral).
	func telhado(pos: Vector3, w: float, d: float, h: float, col: Color) -> void:
		var t := base * Transform3D(Basis.IDENTITY, pos)
		var hw := w * 0.5
		var hd := d * 0.5
		var A := t * Vector3(-hw, 0, hd)
		var B := t * Vector3(hw, 0, hd)
		var C := t * Vector3(hw, h, 0)
		var D := t * Vector3(-hw, h, 0)
		var E := t * Vector3(-hw, 0, -hd)
		var F := t * Vector3(hw, 0, -hd)
		var ct := t * Vector3(0, h * 0.33, 0)
		quad(A, B, C, D, col, ct)
		quad(F, E, D, C, col.darkened(0.12), ct)
		tri(B, F, C, col.darkened(0.25), ct)
		tri(A, E, D, col.darkened(0.25), ct)
		quad(A, B, F, E, col.darkened(0.35), ct)

	## Cilindro/cone vertical (r_topo < 0 = reto; r_topo ~ 0 = cone). `pos` = centro.
	func cil(pos: Vector3, r: float, h: float, col: Color, seg := 8, rot := Basis.IDENTITY, r_topo := -1.0) -> void:
		var t := base * Transform3D(rot, pos)
		var rt := r if r_topo < 0.0 else r_topo
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var b0 := t * Vector3(cos(a0) * r, -h * 0.5, sin(a0) * r)
			var b1 := t * Vector3(cos(a1) * r, -h * 0.5, sin(a1) * r)
			var t1 := t * Vector3(cos(a1) * rt, h * 0.5, sin(a1) * rt)
			var t0 := t * Vector3(cos(a0) * rt, h * 0.5, sin(a0) * rt)
			quad(b0, b1, t1, t0, col, t.origin)
			tri(t * Vector3(0, -h * 0.5, 0), b0, b1, col.darkened(0.3), t.origin)
			if rt > 0.05:
				tri(t * Vector3(0, h * 0.5, 0), t0, t1, col, t.origin)

	## Bola de poucos polígonos.
	func esfera(pos: Vector3, r: float, col: Color, seg := 8, aneis := 4) -> void:
		var t := base * Transform3D(Basis.IDENTITY, pos)
		for j in aneis:
			var l0 := PI * float(j) / float(aneis) - PI * 0.5
			var l1 := PI * float(j + 1) / float(aneis) - PI * 0.5
			for i in seg:
				var a0 := TAU * float(i) / float(seg)
				var a1 := TAU * float(i + 1) / float(seg)
				var p00 := t * Vector3(cos(l0) * cos(a0), sin(l0), cos(l0) * sin(a0)) * 1.0
				var p10 := t * Vector3(cos(l0) * cos(a1), sin(l0), cos(l0) * sin(a1))
				var p11 := t * Vector3(cos(l1) * cos(a1), sin(l1), cos(l1) * sin(a1))
				var p01 := t * Vector3(cos(l1) * cos(a0), sin(l1), cos(l1) * sin(a0))
				# escala em torno do centro
				var o := t.origin
				quad(o + (p00 - o) * r, o + (p10 - o) * r, o + (p11 - o) * r, o + (p01 - o) * r, col, o)

	func malha() -> ArrayMesh:
		var m := ArrayMesh.new()
		if v.is_empty():
			return m
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


# ============================================================================ ganchos da base
func _configurar() -> void:
	id = "casas"
	area = Rect2(-30.0, -18.0, 60.0, 36.0)
	hora = Hora.FIM_DE_TARDE
	clima = Clima.LIMPO
	spawn_pos = Vector3(-24.0, 0.1, 0.0)
	spawn_yaw = -90.0
	portao_pos = Vector3(-27.0, 0.0, -1.2)      # a placa de volta fica atrás do Spawn (de onde o jogador veio), fora do caminho
	ambiente_audio = "mar"
	usa_visor = true          # o quarto de 1967 só aparece pelo Visor (disco 1967)


func mat_asfalto() -> StandardMaterial3D:
	return _mat_liso("casas_asfalto", Color(0.46, 0.46, 0.5), 0.35)


func mat_calcada() -> StandardMaterial3D:
	return _mat_liso("casas_calcada", Color(0.82, 0.78, 0.72), 0.5)


## Piso liso com o grão de ruído (asfalto, calçada), triplanar.
func _mat_liso(nome: String, cor: Color, escala: float) -> StandardMaterial3D:
	return Ato2Pecas.mat_tri(nome, cor, _tex_grao(), escala, 1.0)


func _material_chao() -> Material:
	return Ato2Pecas.mat_tri("casas_grama", Color(0.82, 0.9, 0.7), _tex_grama(), 0.35, 1.0)


func _construir() -> void:
	_corpo = StaticBody3D.new()
	_corpo.name = "ColisaoFixa"
	add_child(_corpo)
	_g = MB.new()
	_gi = MB.new()
	_p = MB.new()
	_l = MB.new()
	_asf = MB.new()
	_cal = MB.new()
	_gramado_longe()
	_rua()
	for d: Dictionary in CASAS:
		_casa(d)
	_poste_cartaz()
	_postes()
	_vegetacao()
	_cerca_viva_do_fundo()
	_fechar_malhas()
	_montar_legenda()
	GameState.epoca_mudou.connect(_ao_mudar_epoca)


func _tarefa() -> void:
	_restaurar_progresso()
	_atualizar_estado()
	_legenda("(fim de tarde. a temporada acabou, mas ninguém avisou a rua.)", 4.5)
	_falar("bentinho", ["Rua das casas de veraneio! Fora do verão, quase todas ficam fechadas.",
		"Dizem que um cartaz antigo ainda está preso num poste. Procure por ele."])


# ============================================================================ mundo: terreno, rua, calçadas
static func _zc(x: float) -> float:
	return ZC_AMP * sin(ZC_K * x)


func _gramado_longe() -> void:
	# grama além do chão da base (a base deixa uma faixa escura bem longe): nada de vazio na beira da rua
	var mi := MeshInstance3D.new()
	mi.name = "GramadoLonge"
	var pm := PlaneMesh.new()
	pm.size = Vector2(420.0, 420.0)
	mi.mesh = pm
	mi.material_override = Ato2Pecas.mat_tri("casas_grama_longe", Color(0.6, 0.7, 0.5), _tex_grama(), 0.2, 1.0)
	mi.position = Vector3(0.0, -0.03, 0.0)
	add_child(mi)


func _rua() -> void:
	var passo := 1.5
	var x := -34.0
	while x < 34.0:
		var x2 := x + passo
		var za := _zc(x)
		var zb := _zc(x2)
		var cm := Vector3((x + x2) * 0.5, -1.0, (za + zb) * 0.5)
		# asfalto
		_asf.quad(Vector3(x, 0.02, za - RUA_MEIA), Vector3(x2, 0.02, zb - RUA_MEIA), Vector3(x2, 0.02, zb + RUA_MEIA), Vector3(x, 0.02, za + RUA_MEIA), COR_ASFALTO, cm)
		# calçadas (norte e sul) e meio-fio
		for s in [-1, 1]:
			var f: float = float(s)
			var d0 := RUA_MEIA * f
			var d1 := (RUA_MEIA + CALCADA) * f
			_cal.quad(Vector3(x, 0.05, za + d0), Vector3(x2, 0.05, zb + d0), Vector3(x2, 0.05, zb + d1), Vector3(x, 0.05, za + d1), COR_ASFALTO, cm)
			var cc := Vector3((x + x2) * 0.5, 0.03, (za + zb) * 0.5 + (RUA_MEIA + 1.0) * f)
			_cal.quad(Vector3(x, 0.02, za + d0), Vector3(x2, 0.02, zb + d0), Vector3(x2, 0.05, zb + d0), Vector3(x, 0.05, za + d0), COR_ASFALTO, cc)
		x = x2
	# faixa amarela tracejada no meio
	_p.base = Transform3D.IDENTITY
	var xs := -33.0
	while xs < 33.0:
		var xe := xs + 1.5
		var ca := Vector3((xs + xe) * 0.5, -1.0, _zc((xs + xe) * 0.5))
		_p.quad(Vector3(xs, 0.03, _zc(xs) - 0.07), Vector3(xe, 0.03, _zc(xe) - 0.07), Vector3(xe, 0.03, _zc(xe) + 0.07), Vector3(xs, 0.03, _zc(xs) + 0.07), Color(0.86, 0.72, 0.3), ca)
		xs += 4.0


# ============================================================================ as casas
func _casa(d: Dictionary) -> void:
	var num: String = d["n"]
	var alvo: bool = num == NUMERO_CERTO
	var lado: int = d["lado"]
	var xh: float = d["x"]
	var w: float = ALVO_W if alvo else 7.0
	var dp: float = ALVO_D if alvo else 5.6
	var gx: float = d["gx"]
	var tinta: Color = d["parede"]
	var telha: Color = d["telha"]
	var pers: Color = d["persiana"]
	var extras: Array = d["extras"]
	var X := Transform3D(Basis(Vector3.UP, 0.0 if lado < 0 else PI), Vector3(xh, 0.0, _zc(xh) + float(lado) * FRENTE))
	var no := Node3D.new()
	no.name = "Casa_" + num
	no.transform = X
	add_child(no)
	var corpo := StaticBody3D.new()
	corpo.name = "Colisao"
	no.add_child(corpo)
	_g.base = X
	_gi.base = X
	_p.base = X
	_l.base = X
	var z_frente: float = X.origin.z
	var z_a: float = z_frente + float(lado) * dp                 # fundo da casa
	var z_b: float = z_frente - float(lado) * CERCA_Z            # a cerca
	_pegadas.append(Rect2(xh - w * 0.5 - 0.6, minf(z_a, z_b) - 0.6, w + 1.2, absf(z_a - z_b) + 1.2))
	_portoes_x.append((X * Vector3(gx, 0.0, 0.0)).x)

	# --- corpo da casa
	if alvo:
		_casa7_corpo(no, corpo, d)
	else:
		_g.box(Vector3(0, ALTURA * 0.5, -dp * 0.5), Vector3(w, ALTURA, dp), tinta)
		_col(corpo, Vector3(0, ALTURA * 0.5, -dp * 0.5), Vector3(w, ALTURA, dp))
	_g.box(Vector3(0, 0.12, 0.0), Vector3(w + 0.2, 0.24, 0.3), tinta.darkened(0.2))       # rodapé que sai da parede
	_g.telhado(Vector3(0, ALTURA, -dp * 0.5), w + 0.7, dp + 0.9, 1.5, telha)
	if not alvo and "luz" not in extras:
		_g.box(Vector3(w * 0.28, ALTURA + 1.2, -dp * 0.7), Vector3(0.5, 1.6, 0.5), tinta.darkened(0.3))   # chaminé

	# --- janelas de frente (venezianas fechadas; a da 36 está acesa)
	var janelas: Array = [1.1, 3.2] if alvo else [-2.4, 2.4]
	for jx: float in janelas:
		if "luz" in extras:
			_janela_acesa(jx)
		else:
			_janela_fechada(jx, pers, tinta)

	# --- porta, varanda e luz da varanda
	if not alvo:
		_g.box(Vector3(gx, 1.1, 0.02), Vector3(1.25, 2.25, 0.06), tinta.lightened(0.3))
		_g.box(Vector3(gx, 1.05, 0.06), Vector3(1.0, 2.1, 0.1), pers.darkened(0.15))
		_g.box(Vector3(gx + 0.36, 1.0, 0.13), Vector3(0.07, 0.07, 0.06), Color(0.85, 0.75, 0.4))
	_g.box(Vector3(gx, 2.6, 0.75), Vector3(2.4, 0.1, 1.5), telha.darkened(0.15))            # beiral da varanda
	for sx in [-1.0, 1.0]:
		_g.box(Vector3(gx + sx * 1.05, 1.3, 1.4), Vector3(0.12, 2.6, 0.12), tinta.lightened(0.35))
		_col(corpo, Vector3(gx + sx * 1.05, 1.3, 1.4), Vector3(0.14, 2.6, 0.14))
	_g.box(Vector3(gx + 1.15, 2.35, 0.22), Vector3(0.18, 0.2, 0.18), Color(0.3, 0.3, 0.32))    # lanterna da varanda (apagada)
	if "luz" in extras:
		_l.box(Vector3(gx + 1.15, 2.35, 0.22), Vector3(0.14, 0.16, 0.14), Color(1.0, 0.82, 0.45))

	# --- cerca baixa, pilares, portão, número, caixa de correio
	_cerca(corpo, gx, tinta, pers, num, d)

	# --- vaso na calçada (a chave está sob o da casa 18)
	_vaso(no, gx, num, d)

	# --- extras
	if "carro" in extras:
		_carro_coberto(corpo, (w * 0.5 + 1.7) * (1.0 if gx < 0.0 else -1.0), 0.0)
	if "bici" in extras:
		_bicicleta(d.get("bici", Color(0.8, 0.2, 0.2)), (w * 0.5 - 0.5) * (1.0 if gx < 0.0 else -1.0), 1.1)
	if "aluga" in extras or "aluga_velha" in extras:
		_placa_aluga(no, gx, "aluga_velha" in extras)
	_balde(no, gx, d["balde"], alvo)
	# --- canteiro de flores no quintal
	_canteiro(X, gx)
	# --- caminho do portão à porta
	_cal.base = X
	_cal.quad(Vector3(gx - 0.45, 0.04, CERCA_Z), Vector3(gx + 0.45, 0.04, CERCA_Z), Vector3(gx + 0.45, 0.04, 0.2), Vector3(gx - 0.45, 0.04, 0.2), COR_ASFALTO, Vector3(gx, -1.0, 1.0))
	_cal.base = Transform3D.IDENTITY

	if "luz" in extras:
		var lz := Construtor.luz(no, Vector3(gx, 2.0, 1.6), Color(1.0, 0.78, 0.45), 1.5, 7.5)
		lz.name = "LuzJanela36"
	if alvo:
		_casa7 = no
		_casa7_extras(no, corpo, d)

	var it := Interagivel.new("Olhar o portão", Vector3(1.7, 1.5, 0.9), func(_pl: Node) -> void: _tocou_portao(num))
	it.name = "IntPortao_" + num
	it.position = Vector3(gx, 0.75, CERCA_Z)
	no.add_child(it)
	if alvo:
		_portao_it = it
		# o portão da 7 tem folha própria (abre): troca o gradil fixo por uma folha articulada
	_g.base = Transform3D.IDENTITY
	_gi.base = Transform3D.IDENTITY
	_p.base = Transform3D.IDENTITY
	_l.base = Transform3D.IDENTITY


func _col(corpo: StaticBody3D, pos: Vector3, tam: Vector3, rot := Basis.IDENTITY) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = tam
	cs.shape = bs
	cs.transform = Transform3D(rot, pos)
	corpo.add_child(cs)
	return cs


func _janela_fechada(cx: float, pers: Color, tinta: Color) -> void:
	var y := 1.65
	_g.box(Vector3(cx, y, 0.03), Vector3(1.35, 1.55, 0.06), tinta.lightened(0.3))          # moldura
	_g.box(Vector3(cx, y, 0.08), Vector3(1.1, 1.3, 0.06), pers.darkened(0.1))                # folhas fechadas
	for i in 6:
		_g.box(Vector3(cx, y - 0.55 + float(i) * 0.22, 0.12), Vector3(1.05, 0.06, 0.04), pers.lightened(0.18))   # ripas da veneziana
	_g.box(Vector3(cx, y - 0.82, 0.14), Vector3(1.5, 0.07, 0.22), tinta.lightened(0.4))     # peitoril


func _janela_acesa(cx: float) -> void:
	var y := 1.65
	_g.box(Vector3(cx, y, 0.03), Vector3(1.35, 1.55, 0.06), Color(0.95, 0.93, 0.88))
	_l.box(Vector3(cx, y, 0.07), Vector3(1.1, 1.3, 0.05), Color(1.0, 0.8, 0.42))             # vidro aceso
	_g.box(Vector3(cx, y, 0.1), Vector3(0.05, 1.3, 0.04), Color(0.95, 0.93, 0.88))           # caixilho
	_g.box(Vector3(cx, y + 0.1, 0.1), Vector3(1.1, 0.05, 0.04), Color(0.95, 0.93, 0.88))
	_g.box(Vector3(cx - 0.3, y - 0.15, 0.09), Vector3(0.3, 0.9, 0.04), Color(0.7, 0.3, 0.25))  # cortina
	_g.box(Vector3(cx, y - 0.82, 0.14), Vector3(1.5, 0.07, 0.22), Color(0.95, 0.93, 0.88))


## Cerca baixa com pilares; o pilar da esquerda leva a placa com o NÚMERO, o da direita a caixa de correio.
func _cerca(corpo: StaticBody3D, gx: float, tinta: Color, pers: Color, num: String, d: Dictionary) -> void:
	var muro := tinta.lightened(0.12)
	var meia_gap := 0.7
	var a1 := -LOTE
	var b1 := gx - meia_gap - 0.2
	var a2 := gx + meia_gap + 0.2
	var b2 := LOTE
	for seg in [[a1, b1], [a2, b2]]:
		var cx: float = (seg[0] + seg[1]) * 0.5
		var len: float = seg[1] - seg[0]
		_g.box(Vector3(cx, 0.3, CERCA_Z), Vector3(len, 0.6, 0.16), muro)
		_g.box(Vector3(cx, 0.63, CERCA_Z), Vector3(len, 0.06, 0.26), muro.lightened(0.2))
		_col(corpo, Vector3(cx, 0.4, CERCA_Z), Vector3(len, 0.8, 0.2))
	for sx in [-1.0, 1.0]:
		var px: float = gx + sx * (meia_gap + 0.1)
		_g.box(Vector3(px, 0.85, CERCA_Z), Vector3(0.34, 1.7, 0.34), muro.darkened(0.05))
		_g.box(Vector3(px, 1.72, CERCA_Z), Vector3(0.44, 0.08, 0.44), muro.lightened(0.25))
		_col(corpo, Vector3(px, 0.85, CERCA_Z), Vector3(0.36, 1.7, 0.36))
	# placa do número no pilar da esquerda (esquerda de quem olha de fora = +x local... o pilar em gx - 0.8)
	var pxn: float = gx - (meia_gap + 0.1)
	_g.box(Vector3(pxn, 1.2, CERCA_Z + 0.19), Vector3(0.64, 0.48, 0.04), Color(0.97, 0.97, 0.94))
	_g.box(Vector3(pxn, 1.2, CERCA_Z + 0.205), Vector3(0.58, 0.42, 0.02), Color(0.14, 0.26, 0.52))
	# caixa de correio no pilar da direita
	var pxm: float = gx + (meia_gap + 0.1)
	var cor_cx: Color = Color(0.8, 0.2, 0.18) if num != "36" else Color(0.9, 0.78, 0.2)
	_g.box(Vector3(pxm, 1.0, CERCA_Z + 0.34), Vector3(0.3, 0.24, 0.34), cor_cx)
	_g.box(Vector3(pxm, 1.14, CERCA_Z + 0.34), Vector3(0.32, 0.05, 0.36), cor_cx.darkened(0.3))
	# portão fixo (a folha da 7 é separada e abre)
	if num == NUMERO_CERTO:
		_montar_portao_7(gx)
	else:
		var ferro := Color(0.18, 0.2, 0.22)
		_p.box(Vector3(gx, 0.1, CERCA_Z), Vector3(1.4, 0.06, 0.05), ferro)
		_p.box(Vector3(gx, 0.6, CERCA_Z), Vector3(1.4, 0.06, 0.05), ferro)
		for i in 8:
			_p.box(Vector3(gx - 0.6 + float(i) * 0.17, 0.35, CERCA_Z), Vector3(0.04, 0.55, 0.04), ferro)
		_col(corpo, Vector3(gx, 0.4, CERCA_Z), Vector3(1.4, 0.8, 0.1))
	# o número (Label3D de frente para a rua)
	var no: Node3D = get_node("Casa_" + num)
	var r := Construtor.rotulo(no, num, Vector3(pxn, 1.2, CERCA_Z + 0.226), 150, Color(1, 1, 1))
	r.name = "Numero_" + num
	r.pixel_size = 0.0034
	r.outline_size = 0


func _montar_portao_7(gx: float) -> void:
	var no: Node3D = get_node("Casa_" + NUMERO_CERTO)
	_portao_folha = Node3D.new()
	_portao_folha.name = "PortaoFolha"
	_portao_folha.position = Vector3(gx - 0.7, 0.0, CERCA_Z)
	no.add_child(_portao_folha)
	var mb := MB.new()
	var ferro := Color(0.18, 0.2, 0.22)
	mb.box(Vector3(0.7, 0.1, 0.0), Vector3(1.4, 0.06, 0.05), ferro)
	mb.box(Vector3(0.7, 0.6, 0.0), Vector3(1.4, 0.06, 0.05), ferro)
	for i in 8:
		mb.box(Vector3(0.1 + float(i) * 0.17, 0.35, 0.0), Vector3(0.04, 0.55, 0.04), ferro)
	var mi := MeshInstance3D.new()
	mi.name = "Gradil"
	mi.mesh = mb.malha()
	mi.material_override = _mat_vc(null)
	_portao_folha.add_child(mi)
	var sb := StaticBody3D.new()
	_portao_folha.add_child(sb)
	_portao_col = _col(sb, Vector3(0.7, 0.4, 0.0), Vector3(1.4, 0.8, 0.1))
	# o bilhete preso na grade
	_p.base = Transform3D.IDENTITY
	var bil := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.28, 0.01)
	bil.mesh = bm
	bil.material_override = Ato2Pecas.mat_cor(Color(0.95, 0.93, 0.8))
	bil.position = Vector3(1.1, 0.42, 0.03)
	bil.name = "Bilhete"
	_portao_folha.add_child(bil)


func _vaso(no: Node3D, gx: float, num: String, d: Dictionary) -> void:
	var vx: float = gx + 1.5
	var vz: float = CERCA_Z + 1.0
	var cor_vaso := Color(0.74, 0.72, 0.68)
	_g.box(Vector3(vx, 0.22, vz), Vector3(0.5, 0.44, 0.5), cor_vaso)
	_g.box(Vector3(vx, 0.46, vz), Vector3(0.58, 0.07, 0.58), cor_vaso.darkened(0.12))
	_p.box(Vector3(vx, 0.54, vz), Vector3(0.4, 0.09, 0.4), Color(0.28, 0.2, 0.14))
	_p.box(Vector3(vx, 0.78, vz), Vector3(0.1, 0.45, 0.1), Color(0.2, 0.42, 0.22), Basis(Vector3.FORWARD, 0.0))
	_p.box(Vector3(vx - 0.1, 0.76, vz), Vector3(0.28, 0.06, 0.06), Color(0.2, 0.42, 0.22), Basis(Vector3.FORWARD, 0.6))
	_p.box(Vector3(vx + 0.1, 0.76, vz), Vector3(0.28, 0.06, 0.06), Color(0.2, 0.42, 0.22), Basis(Vector3.FORWARD, -0.6))
	_col(no.get_node("Colisao") as StaticBody3D, Vector3(vx, 0.3, vz), Vector3(0.55, 0.6, 0.55))
	var it := Interagivel.new("Olhar o vaso", Vector3(0.9, 1.0, 0.9), func(_pl: Node) -> void: _tocou_vaso(num))
	it.name = "IntVaso_" + num
	it.position = Vector3(vx, 0.5, vz)
	no.add_child(it)
	if num == "18":
		_vaso_chave_it = it
		_brilho(no, Vector3(vx, 1.1, vz), 0.5, "casas_chave", "BrilhoChave")      # o brilho da chave no vaso, visível da rua


func _placa_aluga(no: Node3D, gx: float, velha: bool) -> void:
	var px: float = gx - 2.2
	var cor_placa := Color(0.9, 0.9, 0.85) if not velha else Color(0.78, 0.74, 0.62)
	_g.box(Vector3(px, 0.9, CERCA_Z + 0.04), Vector3(0.9, 0.5, 0.05), cor_placa)
	_g.box(Vector3(px - 0.35, 0.65, CERCA_Z + 0.04), Vector3(0.05, 0.3, 0.05), Color(0.4, 0.3, 0.22))
	_g.box(Vector3(px + 0.35, 0.65, CERCA_Z + 0.04), Vector3(0.05, 0.3, 0.05), Color(0.4, 0.3, 0.22))
	var r := Construtor.rotulo(no, "ALUGA-SE", Vector3(px, 0.96, CERCA_Z + 0.075), 70, Color(0.78, 0.1, 0.1) if not velha else Color(0.55, 0.3, 0.25))
	r.pixel_size = 0.0035
	r.outline_size = 0
	var r2 := Construtor.rotulo(no, "TEMPORADA 67/68" if velha else "TEMPORADA", Vector3(px, 0.78, CERCA_Z + 0.075), 36, Color(0.2, 0.2, 0.25) if not velha else Color(0.4, 0.34, 0.28))
	r2.pixel_size = 0.0035
	r2.outline_size = 0


func _carro_coberto(corpo: StaticBody3D, cx: float, cz: float) -> void:
	var capa := Color(0.66, 0.7, 0.76)
	_g.box(Vector3(cx, 0.78, cz), Vector3(1.75, 0.85, 3.9), capa)
	_g.box(Vector3(cx, 1.38, cz - 0.1), Vector3(1.5, 0.55, 2.0), capa.lightened(0.06))
	_g.box(Vector3(cx, 0.28, cz), Vector3(1.8, 0.2, 3.95), capa.darkened(0.35))
	_col(corpo, Vector3(cx, 0.85, cz), Vector3(1.8, 1.7, 3.95))


func _bicicleta(cor: Color, bx: float, bz: float) -> void:
	var preto := Color(0.1, 0.1, 0.1)
	var rx := Basis(Vector3.FORWARD, PI * 0.5)
	_p.cil(Vector3(bx, 0.34, bz - 0.55), 0.34, 0.04, preto, 10, rx)
	_p.cil(Vector3(bx, 0.34, bz + 0.55), 0.34, 0.04, preto, 10, rx)
	_p.box(Vector3(bx, 0.6, bz), Vector3(0.04, 0.04, 1.1), cor)
	_p.box(Vector3(bx, 0.5, bz - 0.2), Vector3(0.04, 0.5, 0.04), cor, Basis(Vector3.RIGHT, 0.5))
	_p.box(Vector3(bx, 0.95, bz - 0.5), Vector3(0.5, 0.04, 0.04), preto)
	_p.box(Vector3(bx, 0.85, bz + 0.15), Vector3(0.12, 0.05, 0.25), preto)


func _balde(no: Node3D, gx: float, cor: Color, alvo: bool) -> void:
	var bxx: float = gx + 1.0
	_p.box(Vector3(bxx, 0.2, 1.9), Vector3(0.44, 0.04, 0.44), Color(0.5, 0.38, 0.26))      # banquinho de jardim
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			_p.box(Vector3(bxx + lx * 0.17, 0.1, 1.9 + lz * 0.17), Vector3(0.05, 0.2, 0.05), Color(0.42, 0.32, 0.22))
	_p.cil(Vector3(bxx, 0.4, 1.9), 0.2, 0.36, cor, 8, Basis.IDENTITY, 0.15)                 # o balde
	_p.cil(Vector3(bxx, 0.57, 1.9), 0.17, 0.03, Color(0.78, 0.72, 0.55), 8)                 # areia seca no balde
	if alvo:
		var it := Interagivel.new("Olhar o balde", Vector3(0.8, 0.9, 0.8), func(_pl: Node) -> void: _ver_balde())
		it.name = "IntBalde"
		it.position = Vector3(bxx, 0.4, 1.9)
		no.add_child(it)


func _canteiro(X: Transform3D, gx: float) -> void:
	# duas faixas de flores/arbustos dentro do quintal, uma de cada lado do caminho (flores = MultiMesh, mais adiante)
	for sx in [-1.0, 1.0]:
		var cx: float = gx + sx * 1.9
		if absf(cx) > LOTE - 0.8:
			continue
		_p.box(Vector3(cx, 0.1, 1.5), Vector3(1.4, 0.2, 0.7), Color(0.38, 0.27, 0.2))
		_p.box(Vector3(cx, 0.1, 1.5), Vector3(1.5, 0.12, 0.8), Color(0.78, 0.76, 0.7))
		_flores.append([X * Vector3(cx, 0.28, 1.5), 0.7])


var _flores: Array = []      # [posição global, meia largura] dos canteiros


func _ver_balde() -> void:
	_falar("sistema", ["Um balde vermelho de plástico, cheio de areia seca.", "Faz muito tempo que ninguém brinca com ele."])


# ============================================================================ a casa 7 (por dentro)
func _casa7_corpo(no: Node3D, corpo: StaticBody3D, d: Dictionary) -> void:
	var w := ALVO_W
	var dp := ALVO_D
	var h := ALTURA
	var t := 0.2
	var cor: Color = d["parede"]
	var cin: Color = cor.lightened(0.18)
	var gx := GX_ALVO
	# paredes (finas, com face de dentro)
	_parede(corpo, Vector3(0, h * 0.5, -dp + t * 0.5), Vector3(w, h, t), cor)                          # fundo
	_parede(corpo, Vector3(-w * 0.5 + t * 0.5, h * 0.5, -dp * 0.5), Vector3(t, h, dp), cor)           # oeste
	_parede(corpo, Vector3(w * 0.5 - t * 0.5, h * 0.5, -dp * 0.5), Vector3(t, h, dp), cor)            # leste
	var porta_l := gx - 0.55
	var porta_r := gx + 0.55
	var fe := (-w * 0.5 + porta_l) * 0.5
	_parede(corpo, Vector3(fe, h * 0.5, -t * 0.5), Vector3(porta_l + w * 0.5, h, t), cor)              # frente, à esquerda da porta
	var fd := (porta_r + w * 0.5) * 0.5
	_parede(corpo, Vector3(fd, h * 0.5, -t * 0.5), Vector3(w * 0.5 - porta_r, h, t), cor)              # frente, à direita
	_parede(corpo, Vector3(gx, 2.15 + (h - 2.15) * 0.5, -t * 0.5), Vector3(1.1, h - 2.15, t), cor)      # verga da porta
	# divisória sala | quarto (x = 0.6), com uma passagem de 1 m
	var px := 0.6
	_parede(corpo, Vector3(px, h * 0.5, -1.15), Vector3(0.16, h, 1.9), cin)
	_parede(corpo, Vector3(px, h * 0.5, -4.5), Vector3(0.16, h, 2.8), cin)
	_parede(corpo, Vector3(px, 2.15 + (h - 2.15) * 0.5, -2.6), Vector3(0.16, h - 2.15, 1.0), cin)
	# batente da porta (por fora)
	_gi.box(Vector3(porta_l - 0.08, 1.1, 0.03), Vector3(0.16, 2.25, 0.06), cor.lightened(0.3))
	_gi.box(Vector3(porta_r + 0.08, 1.1, 0.03), Vector3(0.16, 2.25, 0.06), cor.lightened(0.3))
	_gi.box(Vector3(gx, 2.22, 0.03), Vector3(1.4, 0.14, 0.06), cor.lightened(0.3))
	# chão e forro
	_gi.box(Vector3(0, -0.04, -dp * 0.5), Vector3(w, 0.1, dp), Color(0.5, 0.36, 0.24))
	_gi.box(Vector3(0, h - 0.05, -dp * 0.5), Vector3(w - 0.3, 0.1, dp - 0.3), Color(0.9, 0.88, 0.82))
	# rodapé interno e fresta de luz do fim da tarde pelas venezianas (acesa)
	for i in 4:
		_l.box(Vector3(w * 0.5 - t - 0.02, 1.2 + float(i) * 0.18, -3.0), Vector3(0.03, 0.05, 1.0), Color(0.95, 0.62, 0.3))


func _parede(corpo: StaticBody3D, pos: Vector3, tam: Vector3, cor: Color) -> void:
	_gi.box(pos, tam, cor)
	_col(corpo, pos, tam)


## Móveis e objetos da casa 7: o que existe nas duas épocas fica na malha geral; o que muda vai em dois grupos (Epocas).
func _casa7_extras(no: Node3D, corpo: StaticBody3D, d: Dictionary) -> void:
	var madeira := Color(0.45, 0.32, 0.2)
	# mesa da sala e cadeiras (nas duas épocas)
	_gi.box(Vector3(-2.4, 0.75, -4.2), Vector3(1.3, 0.06, 0.8), madeira.lightened(0.15))
	for lx in [-1.0, 1.0]:
		for lz in [-1.0, 1.0]:
			_gi.box(Vector3(-2.4 + lx * 0.58, 0.36, -4.2 + lz * 0.33), Vector3(0.08, 0.72, 0.08), madeira)
	_col(corpo, Vector3(-2.4, 0.4, -4.2), Vector3(1.3, 0.8, 0.8))
	for cx in [-1.35, -3.45]:
		_gi.box(Vector3(cx, 0.24, -4.2), Vector3(0.42, 0.06, 0.42), madeira)
		_gi.box(Vector3(cx + (-0.2 if cx < -2.4 else 0.2), 0.55, -4.2), Vector3(0.05, 0.55, 0.42), madeira)
		_col(corpo, Vector3(cx, 0.3, -4.2), Vector3(0.44, 0.6, 0.44))
	# estante no fundo
	_gi.box(Vector3(-2.4, 1.0, -5.62), Vector3(2.4, 2.0, 0.34), madeira.darkened(0.15))
	_col(corpo, Vector3(-2.4, 1.0, -5.62), Vector3(2.4, 2.0, 0.34))
	for i in 5:
		var cor_livro := Color(0.55 + 0.08 * float(i % 3), 0.35 + 0.1 * float(i % 2), 0.3)
		_gi.box(Vector3(-3.3 + float(i) * 0.4, 1.35 + float(i % 2) * 0.5, -5.42), Vector3(0.28, 0.32, 0.06), cor_livro)
	# armário e cama (estruturas das duas épocas)
	_gi.box(Vector3(1.5, 1.0, -5.55), Vector3(1.2, 2.0, 0.5), madeira.darkened(0.1))
	_col(corpo, Vector3(1.5, 1.0, -5.55), Vector3(1.2, 2.0, 0.5))
	_gi.box(Vector3(3.3, 0.18, -4.6), Vector3(1.0, 0.26, 1.9), madeira)                 # estrado
	_gi.box(Vector3(3.3, 0.5, -5.5), Vector3(1.0, 0.7, 0.1), madeira.darkened(0.1))     # cabeceira
	_col(corpo, Vector3(3.3, 0.3, -4.6), Vector3(1.0, 0.6, 1.9))
	# calendário na parede, parado em FEVEREIRO nas duas épocas
	_gi.box(Vector3(-3.99, 1.7, -3.0), Vector3(0.02, 0.6, 0.5), Color(0.95, 0.92, 0.82))
	var cal := Construtor.rotulo(no, "FEVEREIRO", Vector3(-3.975, 1.72, -3.0), 40, Color(0.55, 0.12, 0.1))
	cal.pixel_size = 0.0022
	cal.outline_size = 0
	cal.rotation_degrees.y = 90.0
	# --- 2020: lençóis de poeira, caderno na mesa
	_grupo20 = Node3D.new()
	_grupo20.name = "Interior2020"
	no.add_child(_grupo20)
	var m20 := MB.new()
	var lenco := Color(0.88, 0.88, 0.86)
	m20.box(Vector3(-3.55, 0.28, -2.5), Vector3(0.85, 0.56, 1.9), lenco)              # sofá coberto
	m20.box(Vector3(3.3, 0.55, -4.6), Vector3(1.05, 0.32, 1.95), lenco)                # cama coberta
	m20.box(Vector3(1.5, 1.05, -5.4), Vector3(1.3, 2.15, 0.7), lenco.darkened(0.04))   # armário coberto
	m20.box(Vector3(-1.4, 0.4, -1.2), Vector3(0.6, 0.8, 0.6), lenco.darkened(0.08))    # coisa coberta no canto
	_col(corpo, Vector3(-3.55, 0.3, -2.5), Vector3(0.9, 0.6, 1.95))
	# o caderno aberto sobre a mesa: páginas, capa e um sol de giz
	m20.box(Vector3(-2.6, 0.79, -4.2), Vector3(0.24, 0.015, 0.34), Color(0.97, 0.95, 0.88))
	m20.box(Vector3(-2.35, 0.79, -4.2), Vector3(0.24, 0.015, 0.34), Color(0.97, 0.95, 0.88))
	m20.box(Vector3(-2.475, 0.775, -4.2), Vector3(0.52, 0.01, 0.37), Color(0.2, 0.35, 0.65))    # capa azul
	m20.cil(Vector3(-2.3, 0.80, -4.28), 0.04, 0.005, Color(0.95, 0.8, 0.15), 8)                   # sol de giz
	m20.box(Vector3(-2.3, 0.80, -4.14), Vector3(0.05, 0.005, 0.01), Color(0.85, 0.15, 0.15))
	m20.box(Vector3(-2.28, 0.805, -4.2), Vector3(0.016, 0.004, 0.14), Color(0.96, 0.96, 0.98))      # a moça de branco, alta, do lado de fora
	var mi20 := MeshInstance3D.new()
	mi20.name = "Poeira"
	mi20.mesh = m20.malha()
	mi20.material_override = _mat_interior()
	_grupo20.add_child(mi20)
	# o T de cabeça para baixo: um "T" girado 180 graus na página da esquerda, e "ITO" normal
	var pag := Node3D.new()
	pag.name = "PaginaNome"
	pag.position = Vector3(-2.6, 0.8, -4.2)
	pag.rotation_degrees = Vector3(-90.0, 0.0, 0.0)
	_grupo20.add_child(pag)
	var t_inv := Construtor.rotulo(pag, "T", Vector3(-0.085, 0.0, 0.0), 60, Color(0.85, 0.12, 0.12))
	t_inv.name = "T_deCabecaParaBaixo"
	t_inv.pixel_size = 0.0014
	t_inv.rotation.z = PI
	t_inv.outline_size = 0
	var ito := Construtor.rotulo(pag, "ITO", Vector3(0.03, 0.0, 0.0), 60, Color(0.2, 0.2, 0.7))
	ito.pixel_size = 0.0014
	ito.outline_size = 0
	var it_cad := Interagivel.new("Olhar o caderno", Vector3(1.1, 0.7, 0.9), func(_pl: Node) -> void: _ver_caderno())
	it_cad.name = "IntCaderno"
	it_cad.position = Vector3(-2.4, 0.9, -4.2)
	_grupo20.add_child(it_cad)
	_brilho(_grupo20, Vector3(-2.4, 1.25, -4.2), 0.36, "pista_casas_caderno", "BrilhoCaderno")
	Epocas.marcar(_grupo20, [GameState.Epoca.E2020, GameState.Epoca.E2019, GameState.Epoca.E1975, GameState.Epoca.E1950, GameState.Epoca.ESEMDATA])
	# --- 1967: o quarto vivo (cama arrumada às pressas, brinquedos, abajur aceso, a mala aberta)
	_grupo67 = Node3D.new()
	_grupo67.name = "Interior1967"
	no.add_child(_grupo67)
	var m67 := MB.new()
	m67.box(Vector3(3.3, 0.42, -4.6), Vector3(0.96, 0.18, 1.86), Color(0.92, 0.9, 0.84))            # colchão
	m67.box(Vector3(3.3, 0.54, -4.35), Vector3(0.98, 0.1, 1.25), Color(0.25, 0.4, 0.7))              # cobertor azul, amarrotado
	m67.box(Vector3(3.3, 0.53, -3.95), Vector3(0.98, 0.07, 0.15), Color(0.95, 0.95, 0.95))           # listra
	m67.box(Vector3(3.3, 0.52, -5.3), Vector3(0.55, 0.12, 0.34), Color(0.97, 0.95, 0.9))             # travesseiro
	m67.box(Vector3(-0.3, 0.12, -2.2), Vector3(0.26, 0.12, 0.15), Color(0.8, 0.12, 0.1))            # carrinho de lata
	m67.box(Vector3(-0.3, 0.2, -2.2), Vector3(0.14, 0.07, 0.12), Color(0.9, 0.9, 0.5))
	m67.esfera(Vector3(2.3, 0.11, -1.3), 0.11, Color(0.9, 0.3, 0.2), 8, 4)                            # bola
	m67.box(Vector3(2.0, 0.04, -3.7), Vector3(0.1, 0.05, 0.22), Color(0.35, 0.5, 0.8))              # um chinelinho
	m67.box(Vector3(2.2, 0.04, -3.8), Vector3(0.1, 0.05, 0.22), Color(0.35, 0.5, 0.8), Basis(Vector3.UP, 0.6))
	m67.box(Vector3(2.2, 0.35, -5.5), Vector3(0.4, 0.7, 0.4), madeira.lightened(0.1))                # criado-mudo
	m67.box(Vector3(3.9, 1.55, -3.6), Vector3(0.1, 1.5, 0.35), Color(0.92, 0.84, 0.66))             # cortina aberta (lado esquerdo)
	m67.box(Vector3(3.9, 1.55, -2.4), Vector3(0.1, 1.5, 0.35), Color(0.92, 0.84, 0.66))             # (lado direito)
	# a mala feita às pressas: aberta em cima da cama, roupa pendurada para fora
	m67.box(Vector3(3.3, 0.66, -4.3), Vector3(0.7, 0.16, 0.46), Color(0.5, 0.33, 0.2))               # fundo da mala
	m67.box(Vector3(3.3, 0.9, -4.57), Vector3(0.7, 0.04, 0.42), Color(0.55, 0.38, 0.24), Basis(Vector3.RIGHT, -1.2))   # tampa levantada
	m67.box(Vector3(3.22, 0.78, -4.27), Vector3(0.4, 0.09, 0.28), Color(0.95, 0.95, 0.95))           # camiseta listrada
	m67.box(Vector3(3.22, 0.785, -4.27), Vector3(0.4, 0.09, 0.07), Color(0.2, 0.3, 0.6))
	m67.box(Vector3(3.55, 0.7, -4.12), Vector3(0.25, 0.2, 0.18), Color(0.85, 0.6, 0.2))             # outra roupa
	m67.box(Vector3(3.62, 0.63, -4.0), Vector3(0.28, 0.04, 0.1), Color(0.95, 0.95, 0.9))             # a manga pendurada
	var mi67 := MeshInstance3D.new()
	mi67.name = "QuartoVivo"
	mi67.mesh = m67.malha()
	mi67.material_override = _mat_interior()
	_grupo67.add_child(mi67)
	var l67 := MB.new()
	l67.box(Vector3(2.2, 0.82, -5.5), Vector3(0.22, 0.2, 0.22), Color(1.0, 0.82, 0.45))              # abajur aceso
	l67.box(Vector3(3.97, 1.6, -3.0), Vector3(0.03, 1.3, 0.8), Color(1.0, 0.74, 0.42))               # a janela, com o sol baixo
	var mil := MeshInstance3D.new()
	mil.name = "QuartoVivoLuz"
	mil.mesh = l67.malha()
	mil.material_override = _mat_vc(null, true)
	_grupo67.add_child(mil)
	var luz67 := Construtor.luz(_grupo67, Vector3(2.4, 2.0, -3.2), Color(1.0, 0.78, 0.5), 1.4, 6.0)
	luz67.name = "Luz1967"
	var it_mala := Interagivel.new("Olhar a mala", Vector3(1.4, 0.9, 1.7), func(_pl: Node) -> void: _ver_mala())
	it_mala.name = "IntMala"
	it_mala.position = Vector3(3.3, 0.8, -4.4)
	_grupo67.add_child(it_mala)
	_brilho(_grupo67, Vector3(3.3, 1.45, -4.4), 0.36, "pista_casas_mala", "BrilhoMala")
	Epocas.marcar(_grupo67, [GameState.Epoca.E1967])
	# --- porta da frente: folha articulada (fica só encostada quando o portão abre)
	_porta_folha = Node3D.new()
	_porta_folha.name = "PortaFolha"
	_porta_folha.position = Vector3(GX_ALVO + 0.5, 0.0, -0.1)
	no.add_child(_porta_folha)
	var mp := MB.new()
	mp.box(Vector3(-0.5, 1.05, 0.0), Vector3(1.0, 2.1, 0.08), (d["persiana"] as Color).darkened(0.15))
	mp.box(Vector3(-0.85, 1.0, 0.07), Vector3(0.07, 0.07, 0.05), Color(0.85, 0.75, 0.4))
	var mip := MeshInstance3D.new()
	mip.name = "Porta"
	mip.mesh = mp.malha()
	mip.material_override = _mat_interior()
	_porta_folha.add_child(mip)
	var sbp := StaticBody3D.new()
	_porta_folha.add_child(sbp)
	_porta_col = _col(sbp, Vector3(-0.5, 1.05, 0.0), Vector3(1.0, 2.1, 0.1))
	# varanda: a luz acende no final
	_luz_varanda = OmniLight3D.new()
	_luz_varanda.name = "LuzVaranda7"
	_luz_varanda.position = Vector3(GX_ALVO + 1.15, 2.2, 0.8)
	_luz_varanda.light_color = Color(1.0, 0.8, 0.5)
	_luz_varanda.light_energy = 1.4
	_luz_varanda.omni_range = 6.5
	_luz_varanda.shadow_enabled = false
	_luz_varanda.visible = false
	no.add_child(_luz_varanda)
	_brilho_varanda = MeshInstance3D.new()
	_brilho_varanda.name = "BrilhoVaranda7"
	var bmv := BoxMesh.new()
	bmv.size = Vector3(0.14, 0.16, 0.14)
	_brilho_varanda.mesh = bmv
	_brilho_varanda.material_override = Ato2Pecas.mat_cor(Color(1.0, 0.82, 0.45), true)
	_brilho_varanda.position = Vector3(GX_ALVO + 1.15, 2.35, 0.22)
	_brilho_varanda.visible = false
	no.add_child(_brilho_varanda)


## Brilho dourado em forma de estrela que pulsa: chama o olho para a pista/objeto da tarefa (some quando ele é achado).
func _brilho(pai: Node3D, pos: Vector3, tam: float, flag_some: String, nome: String) -> void:
	var mb := MB.new()
	var cor := Color(1.0, 0.9, 0.45)
	mb.box(Vector3.ZERO, Vector3(tam, tam * 0.16, tam * 0.16), cor)
	mb.box(Vector3.ZERO, Vector3(tam * 0.16, tam, tam * 0.16), cor)
	mb.box(Vector3.ZERO, Vector3(tam * 0.16, tam * 0.16, tam), cor)
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mb.malha()
	mi.material_override = _mat_vc(null, true)
	mi.position = pos
	pai.add_child(mi)
	_brilhos[nome] = [mi, flag_some]


func _animar_brilhos() -> void:
	var t := Time.get_ticks_msec() / 1000.0
	for nome: String in _brilhos:
		var par: Array = _brilhos[nome]
		var mi: MeshInstance3D = par[0]
		if not is_instance_valid(mi):
			continue
		var oculto: bool = par[1] != "" and GameState.flag(par[1])
		mi.visible = not oculto
		if not oculto:
			mi.rotation.y = t * 1.6
			mi.scale = Vector3.ONE * (1.0 + 0.3 * sin(t * 4.0))


# ============================================================================ cartaz e postes
func _poste_cartaz() -> void:
	var px := -16.0
	var pz := _zc(px) - (RUA_MEIA + CALCADA * 0.5)
	var madeira := Color(0.36, 0.26, 0.18)
	_g.base = Transform3D.IDENTITY
	_g.box(Vector3(px, 2.6, pz), Vector3(0.24, 5.2, 0.24), madeira)
	_g.box(Vector3(px, 4.9, pz), Vector3(1.6, 0.14, 0.14), madeira)
	_g.box(Vector3(px + 0.7, 4.75, pz), Vector3(0.28, 0.1, 0.18), Color(0.3, 0.3, 0.32))
	_l.base = Transform3D.IDENTITY
	_l.box(Vector3(px + 0.7, 4.68, pz), Vector3(0.2, 0.08, 0.14), Color(1.0, 0.85, 0.5))
	_col(_corpo, Vector3(px, 2.6, pz), Vector3(0.26, 5.2, 0.26))
	var luz := Construtor.luz(self, Vector3(px + 0.7, 4.3, pz + 0.2), Color(1.0, 0.85, 0.55), 1.0, 8.5)
	luz.name = "LuzPoste1"
	# o cartaz: papel velho preso por pregos, foto desbotada, texto apagado
	var cart := Node3D.new()
	cart.name = "Cartaz"
	cart.position = Vector3(px, 1.75, pz + 0.19)
	add_child(cart)
	var papel := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.62, 0.84, 0.012)
	papel.mesh = bm
	papel.material_override = Ato2Pecas.mat_cor(Color(0.86, 0.8, 0.66))
	cart.add_child(papel)
	var halo := MeshInstance3D.new()                  # moldura clara e acesa: o cartaz se vê de longe
	var hm := BoxMesh.new()
	hm.size = Vector3(0.74, 0.96, 0.006)
	halo.mesh = hm
	halo.material_override = Ato2Pecas.mat_cor(Color(1.0, 0.93, 0.62), true)
	halo.position = Vector3(0, 0, -0.02)
	cart.add_child(halo)
	_brilho(cart, Vector3(0, 0.66, 0.05), 0.5, "casas_cartaz", "BrilhoCartaz")
	var mb := MB.new()
	mb.base = Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.008))
	mb.box(Vector3(0, 0.08, 0), Vector3(0.24, 0.28, 0.004), Color(0.62, 0.55, 0.44))     # foto desbotada
	mb.cil(Vector3(0, 0.15, 0.003), 0.055, 0.004, Color(0.45, 0.38, 0.3), 8, Basis(Vector3.RIGHT, PI * 0.5))   # cabeça
	mb.box(Vector3(0, 0.03, 0.003), Vector3(0.16, 0.1, 0.004), Color(0.45, 0.38, 0.3))      # ombros
	mb.box(Vector3(-0.27, 0.38, 0.003), Vector3(0.04, 0.04, 0.004), Color(0.3, 0.3, 0.3))   # pregos
	mb.box(Vector3(0.27, 0.38, 0.003), Vector3(0.04, 0.04, 0.004), Color(0.3, 0.3, 0.3))
	var mi := MeshInstance3D.new()
	mi.mesh = mb.malha()
	mi.material_override = _mat_vc(null)
	cart.add_child(mi)
	var t1 := Construtor.rotulo(cart, "PROCURA-SE", Vector3(0, 0.3, 0.016), 60, Color(0.35, 0.12, 0.1, 0.8))
	t1.pixel_size = 0.0012
	t1.outline_size = 0
	var t2 := Construtor.rotulo(cart, "TITO · 6 ANOS · 12/03/1967", Vector3(0, -0.13, 0.016), 40, Color(0.3, 0.25, 0.2, 0.7))
	t2.pixel_size = 0.0012
	t2.outline_size = 0
	var t3 := Construtor.rotulo(cart, "CASA 7 · TRAV. DAS CONCHAS", Vector3(0, -0.22, 0.016), 30, Color(0.4, 0.22, 0.18, 0.55))
	t3.pixel_size = 0.0012
	t3.outline_size = 0
	var t4 := Construtor.rotulo(cart, "balde vermelho no quintal", Vector3(0, -0.3, 0.016), 28, Color(0.4, 0.22, 0.18, 0.4))
	t4.pixel_size = 0.0012
	t4.outline_size = 0
	var it := Interagivel.new("Ler o cartaz", Vector3(1.0, 1.1, 0.9), func(_pl: Node) -> void: _ler_cartaz())
	it.name = "IntCartaz"
	it.position = Vector3(0, 0, 0.3)
	cart.add_child(it)


func _postes() -> void:
	# postes sem luz de verdade (só a lâmpada acesa de enfeite), e um com luz perto do 7
	var lista := [[-8.0, 1, false], [2.0, -1, false], [9.5, 1, true], [19.0, -1, false], [27.0, 1, false]]
	for p: Array in lista:
		var px: float = p[0]
		var lado: int = p[1]
		var pz: float = _zc(px) + float(lado) * (RUA_MEIA + CALCADA * 0.5)
		var braco := 0.7
		_g.base = Transform3D.IDENTITY
		_g.box(Vector3(px, 2.4, pz), Vector3(0.16, 4.8, 0.16), Color(0.24, 0.25, 0.27))
		_g.box(Vector3(px + braco * 0.5, 4.8, pz), Vector3(braco + 0.1, 0.08, 0.1), Color(0.24, 0.25, 0.27))
		_g.box(Vector3(px + braco, 4.72, pz), Vector3(0.3, 0.1, 0.2), Color(0.3, 0.3, 0.32))
		_l.base = Transform3D.IDENTITY
		_l.box(Vector3(px + braco, 4.64, pz), Vector3(0.22, 0.06, 0.14), Color(1.0, 0.86, 0.55))
		_col(_corpo, Vector3(px, 2.4, pz), Vector3(0.18, 4.8, 0.18))
		if p[2]:
			var luz := Construtor.luz(self, Vector3(px + braco, 4.2, pz), Color(1.0, 0.85, 0.55), 1.0, 8.5)
			luz.name = "LuzPoste2"


# ============================================================================ plantas
func _vegetacao() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1967
	var pinheiros: Array[Transform3D] = []
	var cor_pin: Array[Color] = []
	var palmeiras: Array[Transform3D] = []
	var cor_pal: Array[Color] = []
	var ipes: Array[Transform3D] = []
	var cor_ipe: Array[Color] = []
	# 1) árvores de dentro da área: nos fundos dos lotes e na calçada, longe de portões, vasos, postes e casas
	var fundos: Array = []
	for i in 46:
		var x := rng.randf_range(-29.0, 29.0)
		var z := rng.randf_range(-17.3, 17.3)
		if absf(z - _zc(x)) < RUA_MEIA + CALCADA + 1.3:
			continue
		var p2 := Vector2(x, z)
		var livre := true
		for r: Rect2 in _pegadas:
			if r.grow(1.4).has_point(p2):
				livre = false
		for pxg in _portoes_x:
			if absf(x - pxg) < 4.5 and absf(z - _zc(x)) < 11.0:
				livre = false
		for q: Vector2 in fundos:
			if q.distance_to(p2) < 3.0:
				livre = false
		if not livre:
			continue
		fundos.append(p2)
		var s := rng.randf_range(0.8, 1.35)
		var sorteio := rng.randf()
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s, s)), Vector3(x, 0.0, z))
		var tom := rng.randf_range(0.85, 1.05)
		if sorteio < 0.55:
			pinheiros.append(xf)
			cor_pin.append(Color(tom, tom, tom))
		elif sorteio < 0.8:
			palmeiras.append(xf)
			cor_pal.append(Color(tom, tom, tom))
		else:
			ipes.append(xf)
			cor_ipe.append(Color(tom, tom, tom))
		_col_cil(Vector3(x, 1.0, z), 0.25, 2.0)
	# 2) uma árvore de rua entre os postes, nas duas calçadas (palmeiras e ipês)
	for entrada in [[-12.0, -1, 0], [-1.5, 1, 1], [5.5, -1, 1], [16.0, 1, 0], [21.0, -1, 1], [28.0, -1, 0]]:
		var ex: float = entrada[0]
		var ez: float = _zc(ex) + float(entrada[1]) * (RUA_MEIA + CALCADA * 0.5)
		var ok := true
		for pxg in _portoes_x:
			if absf(ex - pxg) < 2.6:
				ok = false
		if not ok:
			continue
		var xf := Transform3D(Basis(Vector3.UP, rng.randf() * TAU), Vector3(ex, 0.0, ez))
		if entrada[2] == 0:
			palmeiras.append(xf)
			cor_pal.append(Color(1, 1, 1))
		else:
			ipes.append(xf)
			cor_ipe.append(Color(1, 1, 1))
		_col_cil(Vector3(ex, 1.0, ez), 0.22, 2.0)
	# 3) bosque além da borda: fecha o horizonte (sem colisão, a borda invisível já segura)
	var a := area
	for i in 110:
		var lado := rng.randi_range(0, 3)
		var x := 0.0
		var z := 0.0
		match lado:
			0:
				x = rng.randf_range(a.position.x - 14.0, a.end.x + 14.0)
				z = a.position.y - rng.randf_range(1.8, 14.0)
			1:
				x = rng.randf_range(a.position.x - 14.0, a.end.x + 14.0)
				z = a.end.y + rng.randf_range(1.8, 14.0)
			2:
				x = a.position.x - rng.randf_range(1.8, 14.0)
				z = rng.randf_range(a.position.y - 12.0, a.end.y + 12.0)
			_:
				x = a.end.x + rng.randf_range(1.8, 14.0)
				z = rng.randf_range(a.position.y - 12.0, a.end.y + 12.0)
		var s := rng.randf_range(1.0, 1.7)
		var tom := rng.randf_range(0.8, 1.0)
		pinheiros.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(s, s * rng.randf_range(1.0, 1.25), s)), Vector3(x, 0.0, z)))
		cor_pin.append(Color(tom, tom, tom))
	_mm("Pinheiros", _malha_pinheiro(), pinheiros, cor_pin)
	_mm("Palmeiras", _malha_palmeira(), palmeiras, cor_pal)
	_mm("Ipes", _malha_ipe(), ipes, cor_ipe)
	# 4) flores dos canteiros
	var tf: Array[Transform3D] = []
	var cf: Array[Color] = []
	var paleta := [Color(0.95, 0.35, 0.45), Color(0.98, 0.85, 0.25), Color(0.95, 0.95, 0.98), Color(0.7, 0.45, 0.9), Color(0.98, 0.55, 0.2)]
	for f: Array in _flores:
		var c0: Vector3 = f[0]
		for k in 9:
			var fx := rng.randf_range(-0.6, 0.6)
			var fz := rng.randf_range(-0.28, 0.28)
			var xf2 := Transform3D(Basis.IDENTITY, c0 + Vector3(fx, 0.0, fz))
			tf.append(xf2)
			cf.append(paleta[rng.randi_range(0, paleta.size() - 1)])
	if tf.size() > 0:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.13, 0.13, 0.13)
		_mm("Flores", bm, tf, cf)
	# arbustos baixos (cerca viva) entre as casas e a rua dão volume às calçadas
	_p.base = Transform3D.IDENTITY


func _col_cil(pos: Vector3, r: float, h: float) -> void:
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = r
	sh.height = h
	cs.shape = sh
	cs.position = pos
	_corpo.add_child(cs)


func _malha_pinheiro() -> ArrayMesh:
	var mb := MB.new()
	mb.cil(Vector3(0, 0.8, 0), 0.2, 1.6, Color(0.34, 0.24, 0.16), 6)
	mb.cil(Vector3(0, 2.2, 0), 1.45, 2.2, Color(0.12, 0.3, 0.17), 8, Basis.IDENTITY, 0.05)
	mb.cil(Vector3(0, 3.5, 0), 1.1, 1.9, Color(0.14, 0.34, 0.2), 8, Basis.IDENTITY, 0.05)
	mb.cil(Vector3(0, 4.6, 0), 0.75, 1.6, Color(0.17, 0.38, 0.22), 8, Basis.IDENTITY, 0.05)
	return mb.malha()


func _malha_palmeira() -> ArrayMesh:
	var mb := MB.new()
	mb.cil(Vector3(0, 2.2, 0), 0.15, 4.4, Color(0.5, 0.4, 0.3), 6, Basis.IDENTITY, 0.11)
	for i in 8:
		var ang := TAU * float(i) / 8.0
		var inclina := Basis(Vector3.UP, ang) * Basis(Vector3.BACK, -0.5)
		mb.box(Vector3(cos(ang) * 0.9, 4.35, -sin(ang) * 0.9), Vector3(1.9, 0.05, 0.38), Color(0.2, 0.46, 0.22), inclina)
	return mb.malha()


func _malha_ipe() -> ArrayMesh:
	var mb := MB.new()
	mb.cil(Vector3(0, 1.2, 0), 0.18, 2.4, Color(0.4, 0.3, 0.22), 6, Basis.IDENTITY, 0.14)
	mb.esfera(Vector3(0, 3.2, 0), 1.5, Color(0.93, 0.76, 0.22), 8, 4)
	mb.esfera(Vector3(0.8, 3.6, 0.3), 0.9, Color(0.98, 0.84, 0.3), 6, 3)
	mb.esfera(Vector3(-0.7, 3.5, -0.5), 0.85, Color(0.55, 0.62, 0.22), 6, 3)
	return mb.malha()


func _mm(nome: String, malha: Mesh, tfs: Array, cores: Array) -> void:
	if tfs.is_empty():
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = malha
	mm.instance_count = tfs.size()
	for i in tfs.size():
		mm.set_instance_transform(i, tfs[i])
		mm.set_instance_color(i, cores[i])
	var mmi := MultiMeshInstance3D.new()
	mmi.name = nome
	mmi.multimesh = mm
	mmi.material_override = _mat_vc(null)
	add_child(mmi)


## Cerca viva além da borda invisível (a borda da base é quem segura o jogador: aqui só o visual), nos quatro lados.
func _cerca_viva_do_fundo() -> void:
	_p.base = Transform3D.IDENTITY
	var verde := Color(0.16, 0.36, 0.2)
	var a := area
	_p.box(Vector3(a.get_center().x, 0.9, a.position.y - 0.5), Vector3(a.size.x + 2.0, 1.8, 1.0), verde)
	_p.box(Vector3(a.get_center().x, 0.9, a.end.y + 0.5), Vector3(a.size.x + 2.0, 1.8, 1.0), verde)
	_p.box(Vector3(a.position.x - 0.5, 0.9, a.get_center().y), Vector3(1.0, 1.8, a.size.y), verde)
	_p.box(Vector3(a.end.x + 0.5, 0.9, a.get_center().y), Vector3(1.0, 1.8, a.size.y), verde)


# ============================================================================ materiais e texturas
func _mat_vc(textura: Texture2D, sem_luz := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	if textura != null:
		m.albedo_texture = textura
		m.uv1_triplanar = true
		m.uv1_world_triplanar = true
		m.uv1_scale = Vector3.ONE * 0.7
		m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
	if sem_luz:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


## Material de dentro da casa 7: o mesmo grão, com um fundo de luz (sem sombra, o interior ficaria lama).
func _mat_interior() -> StandardMaterial3D:
	var m := _mat_vc(_tex_grao())
	m.emission_enabled = true
	m.emission = Color(0.2, 0.165, 0.13)
	m.emission_energy_multiplier = 1.0
	return m


static var _tg: Texture2D = null
static var _tgrao: Texture2D = null


static func _tex_grama() -> Texture2D:
	if _tg != null:
		return _tg
	const N := 96
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.07
	ruido.seed = 3
	var base := ruido.get_seamless_image(N, N)
	var rng := RandomNumberGenerator.new()
	rng.seed = 21
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var k := 0.92 + (base.get_pixel(x, y).r - 0.5) * 0.45 + rng.randf_range(-0.06, 0.06)
			img.set_pixel(x, y, Color(0.46 * k, 0.62 * k, 0.32 * k))
	img.generate_mipmaps()
	_tg = ImageTexture.create_from_image(img)
	return _tg


static func _tex_grao() -> Texture2D:
	if _tgrao != null:
		return _tgrao
	const N := 64
	var ruido := FastNoiseLite.new()
	ruido.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	ruido.frequency = 0.08
	ruido.seed = 11
	var base := ruido.get_seamless_image(N, N)
	var img := Image.create(N, N, false, Image.FORMAT_RGB8)
	for y in N:
		for x in N:
			var k := 0.9 + (base.get_pixel(x, y).r - 0.5) * 0.25
			img.set_pixel(x, y, Color(k, k, k))
	img.generate_mipmaps()
	_tgrao = ImageTexture.create_from_image(img)
	return _tgrao


func _fechar_malhas() -> void:
	_g.base = Transform3D.IDENTITY
	_nova_malha("Casas", _g, _mat_vc(_tex_grao()))
	_nova_malha("CasaInterior", _gi, _mat_interior())
	_nova_malha("Plantas", _p, _mat_vc(null))
	_nova_malha("Luzes", _l, _mat_vc(null, true))
	_nova_malha("Asfalto", _asf, mat_asfalto())
	_nova_malha("Calcadas", _cal, mat_calcada())


func _nova_malha(nome: String, mb: MB, mat: Material) -> void:
	var mi := MeshInstance3D.new()
	mi.name = nome
	mi.mesh = mb.malha()
	mi.material_override = mat
	add_child(mi)


# ============================================================================ legenda e fala
func _montar_legenda() -> void:
	var cl := CanvasLayer.new()
	cl.name = "LegendaCasas"
	cl.layer = 19
	add_child(cl)
	_legenda_lbl = Label.new()
	_legenda_lbl.add_theme_font_size_override("font_size", 26)
	_legenda_lbl.add_theme_color_override("font_color", Color(0.96, 0.93, 0.85))
	_legenda_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_legenda_lbl.add_theme_constant_override("outline_size", 6)
	_legenda_lbl.anchor_left = 0.0
	_legenda_lbl.anchor_right = 1.0
	_legenda_lbl.anchor_top = 0.0
	_legenda_lbl.anchor_bottom = 0.0
	_legenda_lbl.offset_left = 120.0
	_legenda_lbl.offset_right = -120.0
	_legenda_lbl.offset_top = 96.0
	_legenda_lbl.offset_bottom = 190.0
	_legenda_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_legenda_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var faixa := StyleBoxFlat.new()
	faixa.bg_color = Color(0, 0, 0, 0.45)
	faixa.content_margin_left = 16
	faixa.content_margin_right = 16
	faixa.content_margin_top = 6
	faixa.content_margin_bottom = 6
	faixa.set_corner_radius_all(8)
	_legenda_lbl.add_theme_stylebox_override("normal", faixa)
	_legenda_lbl.modulate.a = 0.0
	cl.add_child(_legenda_lbl)


## Legenda discreta (o que se ouve ou sente; não é fala de personagem).
func _legenda(texto: String, dur := 3.5) -> void:
	if _legenda_lbl == null:
		return
	_legenda_lbl.text = Celular.adaptar(texto)
	if _legenda_tween and _legenda_tween.is_valid():
		_legenda_tween.kill()
	_legenda_tween = create_tween()
	_legenda_tween.tween_property(_legenda_lbl, "modulate:a", 1.0, 0.3)
	_legenda_tween.tween_interval(dur)
	_legenda_tween.tween_property(_legenda_lbl, "modulate:a", 0.0, 0.9)


func _falar(quem: String, linhas: Array) -> void:
	var l: Array = []
	for s in linhas:
		l.append(Celular.adaptar(str(s)))
	Guia.falar(quem, l)


# ============================================================================ a tarefa, passo a passo
func _tem_disco() -> bool:
	return GameState.Epoca.E1967 in GameState.discos


func _restaurar_progresso() -> void:
	# o que já foi feito antes (saiu e voltou): portão aberto, chave no bolso
	if GameState.flag("casas_portao"):
		_abrir_portao(false)
	if GameState.flag("pista_casas_caderno") and GameState.flag("pista_casas_mala"):
		_luz_da_varanda(true)


func passo_atual() -> int:
	if GameState.flag("pista_casas_caderno") and GameState.flag("pista_casas_mala"):
		return Passo.FIM
	if GameState.flag("casas_portao"):
		return Passo.MALA if GameState.flag("pista_casas_caderno") else Passo.CASA
	if GameState.flag("casas_chave"):
		return Passo.PORTAO
	if GameState.flag("casas_bilhete"):
		return Passo.CHAVE
	if GameState.flag("casas_cartaz"):
		return Passo.NUMERO
	return Passo.CARTAZ


func texto_do_passo(p: int) -> String:
	match p:
		Passo.CARTAZ:
			return "Procure o cartaz de PROCURA-SE preso num poste da calçada."
		Passo.NUMERO:
			return "Ache a casa nº 7 (balde vermelho no quintal). Os números estão fora de ordem."
		Passo.CHAVE:
			return "A chave está sob um vaso da casa DE FRENTE ao 7, do outro lado da rua."
		Passo.PORTAO:
			return "Use a chave no portão da casa 7."
		Passo.CASA:
			return "Entre na casa 7 e olhe o que tem em cima da mesa da sala."
		Passo.MALA:
			if _tem_disco():
				return "No quarto dos fundos, aperte Q (Visor, disco de 1967, tecla 2) e olhe a cama."
			return "Falta algo que só o Visor de 1967 mostra. Volte com o disco do Acervo (Visita 2). Sair: portão azul."
	return "Aqui está tudo certo."


## Dicas por passo: [quem, texto] (a 1ª vem depois de DEMORA_DICA s, a 2ª depois do dobro).
func dicas_do_passo(p: int) -> Array:
	match p:
		Passo.CARTAZ:
			return [["bentinho", "Procure um poste de madeira com um papel colado. Ande pela calçada e aperte E perto dele."],
				["taina", "O poste do cartaz fica do lado esquerdo da rua, mais à frente. Tem uma luz nele."]]
		Passo.NUMERO:
			return [["taina", "Procure a placa azul com o número 7 no pilar do portão. O balde vermelho no quintal também ajuda."],
				["bentinho", "A casa 7 fica do lado direito da rua, depois do meio. Olhe o portão e aperte E."]]
		Passo.CHAVE:
			return [["taina", "O bilhete falou de uma casa 'de frente'. É a que fica do outro lado da rua, bem em frente ao 7."],
				["bentinho", "A casa da frente é a 18. Olhe os vasos da calçada dela e aperte E."]]
		Passo.PORTAO:
			return [["bentinho", "Com a chave na mão, volte ao portão do 7 e aperte E."],
				["bentinho", "O portão do 7 é o que tem o balde vermelho no quintal. Aperte E nele."]]
		Passo.CASA:
			return [["taina", "A porta está encostada. Entre e procure algo em cima da mesa da sala."],
				["bentinho", "Dentro da casa 7, na sala, tem um caderno em cima da mesa. Aperte E nele."]]
		Passo.MALA:
			if _tem_disco():
				return [["taina", "Ligue o Visor com Q e escolha o disco de 1967 (tecla 2). Depois vá ao quarto dos fundos."],
					["bentinho", "Com o Visor em 1967, olhe a cama do quarto. Tem uma mala em cima dela."]]
			return [["taina", "Tem algo neste quarto que só 1967 mostra. O disco fica no Acervo, na Visita 2."],
				["bentinho", "Dá para sair pelo portão azul e voltar depois, com o Visor. A pista do caderno você já tem."]]
	return []


func _atualizar_estado() -> void:
	var p := passo_atual()
	if p != _passo_ultimo:
		_passo_ultimo = p
		tempo_passo = 0.0
		dicas_faladas = 0
	definir_objetivo(texto_do_passo(p))
	_atualizar_textos()


func _atualizar_textos() -> void:
	if _portao_it != null and is_instance_valid(_portao_it):
		if GameState.flag("casas_chave"):
			_portao_it.texto_interacao = "Abrir o portão com a chave"
		elif GameState.flag("casas_bilhete"):
			_portao_it.texto_interacao = "Olhar o portão (trancado)"
		else:
			_portao_it.texto_interacao = "Olhar o portão"


func _texto_objetivo() -> String:
	var t := super._texto_objetivo()
	if not GameState.cidade_feita(id) and tempo_passo >= DEMORA_DICA:
		var dicas := dicas_do_passo(passo_atual())
		if not dicas.is_empty():
			var i := 1 if tempo_passo >= DEMORA_DICA * 2.0 else 0
			t += "\nDica: " + str(dicas[mini(i, dicas.size() - 1)][1])
	return Celular.adaptar(t)


func _process(dt: float) -> void:
	if player == null or not is_instance_valid(player) or _saindo:
		return
	if GameState.atencao > 0.0:
		GameState.definir_atencao(0.0)       # aqui o Visor é calmo: ninguém do outro lado repara em você
	_atualizar_estado()
	_animar_brilhos()
	_posicao_do_jogador()
	if GameState.cidade_feita(id) or GameState.flag("ui_aberta"):
		return
	tempo_passo += dt
	var dicas := dicas_do_passo(passo_atual())
	var nivel := 0 if tempo_passo >= DEMORA_DICA else -1
	if tempo_passo >= DEMORA_DICA * 2.0:
		nivel = 1
	if nivel >= 0 and dicas_faladas <= nivel and not dicas.is_empty() and not Guia.ocupado():
		var d: Array = dicas[mini(nivel, dicas.size() - 1)]
		dicas_faladas = nivel + 1
		_falar(str(d[0]), [str(d[1])])


## Dentro da casa 7 / no quarto: pequenos momentos (a casa fala sem palavras).
func _posicao_do_jogador() -> void:
	if _casa7 == null or player == null:
		return
	var l := _casa7.to_local(player.global_position)
	var dentro := l.x > -ALVO_W * 0.5 + 0.1 and l.x < ALVO_W * 0.5 - 0.1 and l.z < -0.1 and l.z > -ALVO_D + 0.1
	if dentro and not dentro_casa:
		dentro_casa = true
		_legenda("(a casa cheira a mar fechado. o relógio da parede parou.)", 4.0)
	elif not dentro:
		dentro_casa = false
		no_quarto = false
	if dentro_casa:
		var quarto := l.x > 0.9
		if quarto and not no_quarto:
			no_quarto = true
			_entrou_no_quarto()
		elif not quarto:
			no_quarto = false
		_mae_chama_se_for_1967()


func _entrou_no_quarto() -> void:
	if GameState.epoca == GameState.Epoca.E1967:
		return
	if GameState.flag("pista_casas_mala"):
		return
	if _tem_disco():
		_legenda("(o quarto está estranhamente quente. aperte Q: o disco de 1967 é a tecla 2.)", 5.0)
	else:
		_legenda("(um som abafado de mulher, como se viesse de outro tempo. não dá para entender.)", 5.0)
		_falar("taina", ["Tem algo neste quarto, mas eu não consigo ver.", "O Acervo da prefeitura guarda um disco de 1967. Volte com ele e o Visor."])


func _mae_chama_se_for_1967() -> void:
	if chamadas_mae > 0 or GameState.epoca != GameState.Epoca.E1967:
		return
	chamadas_mae += 1
	Audio.sfx("crianca_ei", -2.0)
	_legenda("(de dentro da casa, uma voz de mulher, apressada:)\n— Titooo! Vem arrumar a mala, filho!", 5.0)


func _ao_mudar_epoca(e: int) -> void:
	# em 1967 o céu esquenta (fim de tarde mais alaranjado); fora dele, volta ao normal
	if e == GameState.Epoca.E1967:
		aplicar_ambiente(Hora.ENTARDECER, clima)
	elif hora != Hora.FIM_DE_TARDE:
		aplicar_ambiente(Hora.FIM_DE_TARDE, clima)
	_mae_chama_se_for_1967_dentro()


func _mae_chama_se_for_1967_dentro() -> void:
	if _casa7 != null and player != null and dentro_casa:
		_mae_chama_se_for_1967()


func _exit_tree() -> void:
	super._exit_tree()
	# garantia: o Castelinho nunca recebe a época de 1967 do quarto vivo (o Visor também a devolve ao sair)
	if is_instance_valid(GameState) and GameState.epoca == GameState.Epoca.E1967:
		GameState.trocar_epoca(GameState.Epoca.E2020)


# ---- interações
func _ler_cartaz() -> void:
	var primeira: bool = not GameState.flag("casas_cartaz")
	if primeira:
		GameState.set_flag("casas_cartaz", true)
		_atualizar_estado()
		_falar("sistema", ["PROCURA-SE. Menino de 6 anos, camiseta listrada e bermuda azul. Atende por Tito.",
			"Passava o verão na Casa 7, Travessa das Conchas. No quintal tem um balde vermelho.",
			"Sumiu em 12/03/1967. A tinta está quase toda apagada. Dá para ler: 'Quem viu, avise a família.'"])
		_falar("taina", ["Casa 7, com um balde vermelho no quintal.", "Mas olha só: os números das casas daqui estão todos fora de ordem!"])
	else:
		_falar("sistema", ["PROCURA-SE · Tito, 6 anos · Casa 7, Travessa das Conchas · 12/03/1967 · balde vermelho no quintal."])


func _tocou_portao(num: String) -> void:
	if num == NUMERO_CERTO:
		_portao_7()
		return
	var d: Dictionary = {}
	for c: Dictionary in CASAS:
		if c["n"] == num:
			d = c
	var linhas: Array = [str(d["portao"])]
	_falar("sistema", linhas)
	if num == "36":
		if GameState.flag("casas_cartaz"):
			_falar("taina", ["A luz é só de um temporizador quebrado. A casa do cartaz é a 7!"])
		else:
			_falar("taina", ["Uma luz acesa numa rua inteira de casas fechadas... Que estranho."])
	elif GameState.flag("casas_chave"):
		_falar("taina", ["A chave não serve aqui. Tente o portão do 7."])
	elif GameState.flag("casas_cartaz"):
		_falar("taina", ["Esta é a casa %s. Procure o 7." % num])


func _portao_7() -> void:
	if GameState.flag("casas_portao"):
		_falar("sistema", ["O portão da casa 7 está aberto."])
		return
	if GameState.flag("casas_chave"):
		_abrir_portao(true)
		GameState.set_flag("casas_portao", true)
		_atualizar_estado()
		Audio.sfx("porta")
		_falar("sistema", ["A chave gira. O portão se abre com um rangido."])
		_falar("bentinho", ["A porta da casa também ficou só encostada. Vamos entrar?"])
		return
	if not GameState.flag("casas_bilhete"):
		GameState.set_flag("casas_bilhete", true)
		_atualizar_estado()
		_falar("sistema", ["Casa 7. O portão está trancado.",
			"Preso na grade, um bilhete a lápis: 'Chave sob o vaso da casa de FRENTE. — Caseiro.'"])
		_falar("taina", ["De frente? Então é do outro lado da rua."])
	else:
		_falar("sistema", ["Trancado. O bilhete diz: chave sob o vaso da casa de FRENTE."])


func _abrir_portao(animar: bool) -> void:
	if _portao_folha == null:
		return
	if _portao_col != null:
		_portao_col.set_deferred("disabled", true)
	if animar:
		var tw := create_tween().set_parallel()
		tw.tween_property(_portao_folha, "rotation:y", deg_to_rad(100.0), 0.9).set_trans(Tween.TRANS_SINE)
		_porta_ajar()
	else:
		_portao_folha.rotation.y = deg_to_rad(100.0)
		if _porta_folha != null:
			_porta_folha.rotation.y = deg_to_rad(-85.0)
		if _porta_col != null:
			_porta_col.set_deferred("disabled", true)
	if _portao_it != null and is_instance_valid(_portao_it):
		_portao_it.texto_interacao = "Portão aberto"


func _porta_ajar() -> void:
	if _porta_folha == null:
		return
	var tw := create_tween()
	tw.tween_interval(0.7)
	tw.tween_property(_porta_folha, "rotation:y", deg_to_rad(-85.0), 0.8).set_trans(Tween.TRANS_SINE)
	if _porta_col != null:
		_porta_col.set_deferred("disabled", true)


func _tocou_vaso(num: String) -> void:
	var d: Dictionary = {}
	for c: Dictionary in CASAS:
		if c["n"] == num:
			d = c
	if num == "18":
		if not GameState.flag("casas_chave"):
			GameState.set_flag("casas_chave", true)
			_atualizar_estado()
			Audio.sfx("acerto", -6.0)
			_falar("sistema", ["Embaixo do vaso, uma chavinha enferrujada. Você a guarda no bolso."])
			_falar("taina", ["Achou! Agora é só voltar ao portão do 7."])
		else:
			_falar("sistema", ["Só o lugar onde a chave estava. Um círculo limpo na calçada."])
		return
	var linhas: Array = [str(d["vaso"])]
	if num == NUMERO_CERTO and GameState.flag("casas_bilhete") and not GameState.flag("casas_chave"):
		linhas.append("A chave não ia ficar aqui, né? O bilhete disse 'casa de FRENTE'.")
	_falar("sistema", linhas)


func _ver_caderno() -> void:
	var nova: bool = await pista("casas_caderno", [])
	_atualizar_estado()
	if nova:
		await Guia.falar("sistema", ["Um caderno de desenhos de criança, de giz de cera. Casa, sol, a praia.",
			"Em todas as páginas, uma moça de branco, bem alta, do lado de fora.",
			"Na primeira folha, o nome em letras grandes: ITO. O T está de cabeça para baixo."])
		await Guia.falar("taina", ["O T está virado. Parece que ele escreveu o próprio nome olhando do outro lado do vidro."])
		if GameState.flag("pista_casas_mala"):
			_fim_com_calma()
		elif _tem_disco():
			await Guia.falar("bentinho", ["Pista do Tito! Falta o quarto dos fundos: ligue o Visor (Q) no disco de 1967."])
		else:
			await Guia.falar("bentinho", ["Pista do Tito! Mas este quarto guarda mais, e só o disco de 1967 mostra. Volte com o Visor."])
	else:
		_falar("sistema", ["O caderno do Tito. O T continua de cabeça para baixo."])
		_fim_se_completo()


func _ver_mala() -> void:
	var nova: bool = await pista("casas_mala", [])
	_atualizar_estado()
	if nova:
		await Guia.falar("sistema", ["Uma mala de papelão, aberta em cima da cama. As roupas foram enfiadas de qualquer jeito.",
			"Camisetas listradas, de menino. Um carrinho de lata. E na tampa, a letra de uma mulher: 'Casa 7'.",
			"Dentro, um bilhete: 'Deixar a luz da varanda acesa. O Tito não gosta de dormir no escuro.'"])
		await Guia.falar("taina", ["Alguém arrumou isto correndo, e deixou a mala aberta, esperando alguém voltar."])
		_fim_com_calma()
	else:
		_falar("sistema", ["A mala aberta do Tito. A luz da varanda ficou acesa para ele."])
		_fim_se_completo()


## As duas pistas achadas: a luz da varanda acende e o lugar termina com calma (o jogador também pode sair antes).
func _fim_com_calma() -> void:
	if not (GameState.flag("pista_casas_caderno") and GameState.flag("pista_casas_mala")) or _concluindo:
		return
	_concluindo = true
	_luz_da_varanda(true)
	_legenda("(lá fora, a luz da varanda do 7 se acendeu sozinha.)", 4.0)
	await Guia.falar("bentinho", ["Duas pistas! A luz da varanda acendeu... como alguém pediu no bilhete."])
	await get_tree().create_timer(1.2, false).timeout
	_concluindo = false
	_fim_se_completo()


func _fim_se_completo() -> void:
	if GameState.flag("pista_casas_caderno") and GameState.flag("pista_casas_mala") and not GameState.cidade_feita(id):
		concluir()


func _luz_da_varanda(acesa: bool) -> void:
	if _luz_varanda != null:
		_luz_varanda.visible = acesa
	if _brilho_varanda != null:
		_brilho_varanda.visible = acesa
	if acesa:
		Audio.sfx("clique", -6.0, 0.8)
