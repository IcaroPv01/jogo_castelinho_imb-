extends CidadeBase
## LUGAR DA CIDADE: Calçadão da Barra / Guia Corrente (Módulo 14). A Barra de Imbé para andar à vontade, no fim da tarde que
## vai escurecendo aos poucos: calçadão com mureta, quiosques e barracas FECHADOS (fora de temporada), bancos, postes, o molhe de
## pedra, a margem do rio Tramandaí, a ponte ao longe e pescadores de tarrafa em silhueta. NÃO é o flashback `barra.gd` (V2),
## que não muda: daqui só se REAPROVEITA o desenho do boto e dos pescadores (veja `_modelos_do_flashback`).
##
## TAREFA (1 pista, `barra_pescador`), tudo opcional e sem morte:
##   1. Na plataforma de madeira (bandeira laranja), E em "Jogar a tarrafa com o boto": versão curta e justa do minigame do
##      flashback. O boto nada, sobe e BATE A CABEÇA na água; com a "!" amarela na tela, clique ou E lança a tarrafa.
##      São 2 lances que dão tainha. Lançar cedo ou deixar passar só rende uma dica da Tainá (e a janela de tempo aumenta);
##      NÃO existe o 3º lance que afoga. Dá para rejogar à vontade (também em outra visita, pela placa).
##   2. Com a rede cheia (uma sandália de criança vem junto, só o objeto), o pescador mais velho (fictício, sentado perto do
##      molhe) conta que viu um menino seguir uma moça de branco até o braço morto, no fim de uma temporada.
##      A pista `barra_pescador` sai dessa conversa, a Tainá comenta e só então `concluir()` volta à calçada.
## Objetivo/Mapa (M): `_texto_objetivo()` muda a cada passo e ganha uma "Dica:" se o jogador demora (`DICA_APOS`).
## Orçamento web: ~35 malhas + 2 lotes combinados (caixas coloridas num único ArrayMesh), molhe em MultiMesh, 5 luzes, sem sombras.
## Tabela: `GameState.CIDADE["barra"]` (abre depois da visita 2). Teste: `tests/cidade_barra_test.gd`.

signal lance_feito(numero: int, acertou: bool)
signal rede_encheu
signal conversou

enum Fase { LIVRE, ESPERA, JANELA, LANCADO }

const COTA_AGUA := -0.3
const MARGEM_Z := -12.4                       # fim do chão / linha d'água (a AREA começa 0,2 m antes, na borda invisível)
const PONTO := Vector3(-14.0, 0.0, -11.1)     # plataforma de madeira onde se pesca
const ALVO_Z := -15.8                         # onde a tarrafa cai
const BOTO_Z := -18.0                         # por onde o boto nada
const LANCES := 2
const RAIO_LANCE := 7.0                       # do PONTO: lança de dentro disto
const RAIO_SAIR := 11.0                       # passou disto, a pesca é cancelada (volta a poder falar com o ponto)
const JANELA_BASE := 2.1                      # s em que o lance vale depois do boto emergir (cresce a cada lance perdido)
const DICA_APOS := 70.0                       # s sem progresso até o Mapa mostrar uma "Dica:"
const VELHO_POS := Vector3(24.5, 0.0, -10.9)  # pescador mais velho, ao lado do molhe
const SOL := Vector3(-0.62, 0.10, -0.78)
const DUSK_SEG := 420.0                       # s até o escurecer chegar no máximo
const DUSK_MAX := 0.7                         # 0 = entardecer, 1 = noite fechada (nunca passa disto: dá para enxergar)

@export var espera_min := 2.0
@export var espera_max := 3.4
var pulou_intro := false                      # (teste) não conta a explicação da Tainá

# --- estado da tarefa
var fase: int = Fase.LIVRE
var em_pesca := false
var lances_ok := 0
var tainhas := 0
var rede_cheia := false
var conversando := false
var janela_aberta := false
var perdidas := 0
var boto: Node3D
var velho: Node3D

var _sessao := 0
var _janela_t := 0.0
var _desde_lance := 9.0
var _desde_guia := 9.0
var _cedos := 0
var _ocioso := 0.0
var _lembrou_estagio := -1
var _explicou := false
var _boto_corpo: Node3D
var _exclama: Label3D
var _exclama_velho: Label3D
var _boto_nada := true
var _boto_ocupado := false
var _boto_pos := Vector3(PONTO.x, COTA_AGUA - 0.5, BOTO_Z)
var _boto_yaw := 0.0
var _alvo_atual := Vector3(PONTO.x, COTA_AGUA, ALVO_Z)
var _t := 0.0
var _agua_mat: ShaderMaterial
var _luzes: Array[OmniLight3D] = []
var _spot: Interagivel
var _pescadores: Array[Node3D] = []
var _pilha: Node3D
var _mat_rede: StandardMaterial3D
var _mat_espuma: StandardMaterial3D
var _mat_peixe: StandardMaterial3D
var _malha_rede: CylinderMesh
var _lbl_placar: Label
var _lbl_dica: Label
var _dusk := 0.0
var _prox_dusk := 0.0


func _configurar() -> void:
	id = "barra"
	area = Rect2(-42.0, -12.6, 84.0, 28.0)       # x -42..42, z -12.6 (rio) .. 15.4 (rua)
	hora = Hora.ENTARDECER                       # (o céu escurece sozinho: `_ceu_escurecendo`, sem mudar `hora`)
	clima = Clima.LIMPO
	spawn_pos = Vector3(-34.0, 0.1, 0.0)
	spawn_yaw = -60.0                            # olha para o leste/nordeste: a plataforma, o rio e o boto já à vista
	ambiente_audio = "mar"


func _material_chao() -> Material:
	return mat_calcada()


## Chão só do calçadão e da areia: a água precisa ficar à vista (a base cobriria 2 m além da AREA).
func _chao() -> void:
	var c := area.get_center()
	var z1 := area.end.y + 2.0
	Construtor.caixa(self, Vector3(area.size.x + 4.0, 0.6, z1 - MARGEM_Z), Vector3(c.x, -0.3, (MARGEM_Z + z1) * 0.5), _material_chao(), true, "Chao")
	Construtor.caixa(self, Vector3(area.size.x + 200.0, 0.2, area.size.y + 200.0), Vector3(c.x, -0.62, c.y),
		Ato2Pecas.mat_cor(Color(0.1, 0.11, 0.12)), false, "ChaoLonge")


# ============================================================================ pedaço de malha combinado
## Caixas coloridas (cor por vértice) somadas num ÚNICO ArrayMesh: um draw call para dezenas de peças.
class Lote extends RefCounted:
	var v := PackedVector3Array()
	var n := PackedVector3Array()
	var c := PackedColorArray()
	var idx := PackedInt32Array()

	## `pos` = centro da caixa; `giro` = graus em torno do eixo Y.
	func caixa(pos: Vector3, tam: Vector3, cor: Color, giro := 0.0) -> void:
		var b := Basis(Vector3.UP, deg_to_rad(giro))
		var h := tam * 0.5
		for eixo in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
			var nrm: Vector3 = eixo
			var u := Vector3(0, 1, 0) if absf(nrm.y) < 0.5 else Vector3(1, 0, 0)
			var w := nrm.cross(u)
			var hn := h.dot(nrm.abs())
			var hu := h.dot(u.abs())
			var hw := h.dot(w.abs())
			var p0 := nrm * hn
			var q: Array[Vector3] = [p0 - u * hu - w * hw, p0 + u * hu - w * hw, p0 + u * hu + w * hw, p0 - u * hu + w * hw]
			# fica de frente (sentido horário visto de fora): se não, inverte
			if (q[1] - q[0]).cross(q[2] - q[0]).dot(nrm) > 0.0:
				var tmp := q[1]
				q[1] = q[3]
				q[3] = tmp
			var base := v.size()
			var nm := b * nrm
			for p in q:
				v.append(pos + b * p)
				n.append(nm)
				c.append(cor)
			idx.append_array(PackedInt32Array([base, base + 1, base + 2, base, base + 2, base + 3]))

	func malha() -> ArrayMesh:
		var arr := []
		arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = v
		arr[Mesh.ARRAY_NORMAL] = n
		arr[Mesh.ARRAY_COLOR] = c
		arr[Mesh.ARRAY_INDEX] = idx
		var m := ArrayMesh.new()
		m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		return m


static func _mat_lote(sem_luz: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	if sem_luz:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m


func _fechar_lote(l: Lote, sem_luz: bool, nome: String, pai: Node3D = null) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = l.malha()
	mi.material_override = _mat_lote(sem_luz)
	mi.name = nome
	(pai if pai != null else self).add_child(mi)
	return mi


# ============================================================================ cenário
func _construir() -> void:
	_materiais()
	_agua()
	_areia_e_molhe()
	_calcadao()
	_ao_fundo()
	_plataforma_e_placas()
	_modelos_do_flashback()
	_pescador_velho()
	_ui()
	_luzes_do_calcadao()
	_marcadores_extra()


func _materiais() -> void:
	_mat_rede = Ato2Pecas.mat_cor(Color(0.06, 0.05, 0.07, 0.6), true)
	_mat_rede.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat_peixe = Ato2Pecas.mat_cor(Color(0.85, 0.88, 0.92), true)
	_mat_espuma = Ato2Pecas.mat_cor(Color(0.95, 0.92, 0.85, 0.7), true)
	_mat_espuma.cull_mode = BaseMaterial3D.CULL_DISABLED
	_malha_rede = CylinderMesh.new()
	_malha_rede.top_radius = 0.03
	_malha_rede.bottom_radius = 0.9
	_malha_rede.height = 0.5
	_malha_rede.radial_segments = 14
	_malha_rede.rings = 1
	_malha_rede.cap_top = false
	_malha_rede.cap_bottom = false


func _agua() -> void:
	var m := ShaderMaterial.new()
	m.shader = load("res://shaders/agua.gdshader") as Shader
	m.set_shader_parameter("margem_z", MARGEM_Z)
	m.set_shader_parameter("dir_sol", SOL.normalized())
	_agua_mat = m
	var perto := PlaneMesh.new()
	perto.size = Vector2(500.0, 50.0)
	perto.subdivide_width = 100
	perto.subdivide_depth = 20
	Ato2Pecas.malha(self, perto, Vector3(0, COTA_AGUA, MARGEM_Z - 25.0), m).name = "AguaPerto"
	var longe := PlaneMesh.new()
	longe.size = Vector2(1400.0, 330.0)
	longe.subdivide_width = 30
	longe.subdivide_depth = 20
	Ato2Pecas.malha(self, longe, Vector3(0, COTA_AGUA, MARGEM_Z - 215.0), m).name = "AguaLonge"


func _caixa_malha(tam: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = tam
	return b


func _areia_e_molhe() -> void:
	var larg := area.size.x + 4.0
	Ato2Pecas.malha(self, _caixa_malha(Vector3(larg, 0.04, 4.6)), Vector3(0, 0.01, -10.5), mat_areia(1.0)).name = "Areia"
	Ato2Pecas.malha(self, _caixa_malha(Vector3(larg, 0.02, 1.4)), Vector3(0, 0.03, -11.7), mat_areia(0.6)).name = "AreiaMolhada"
	# barranco que desce para dentro d'água
	Ato2Pecas.malha(self, _caixa_malha(Vector3(larg, 0.3, 5.0)), Vector3(0, -0.45, MARGEM_Z - 2.3), mat_areia(0.55), Vector3(-7, 0, 0)).name = "Barranco"
	# molhe de pedra: uma língua de pedras que entra no rio (MultiMesh: um draw call)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = _caixa_malha(Vector3.ONE)
	var n := 320
	mm.instance_count = n
	for i in n:
		var z := MARGEM_Z - 0.8 - rng.randf() * 34.0
		var x := 26.0 + rng.randfn(0.0, 2.1)
		var s := Vector3(rng.randf_range(0.9, 2.0), rng.randf_range(0.6, 1.5), rng.randf_range(0.9, 2.0))
		var b := Basis.from_euler(Vector3(rng.randf_range(-0.3, 0.3), rng.randf() * TAU, rng.randf_range(-0.3, 0.3))).scaled(s)
		mm.set_instance_transform(i, Transform3D(b, Vector3(x, COTA_AGUA + 0.25 + rng.randf() * 0.7, z)))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = Ato2Pecas.mat_tri("pedra_molhe", Color(0.55, 0.5, 0.5), Ato2Pecas.tex_piso_pedra(), 0.5)
	mmi.name = "Molhe"
	add_child(mmi)


func _calcadao() -> void:
	var L := Lote.new()    # com luz
	var S := Lote.new()    # sem luz (lâmpadas, janelas, bandeira)
	var clara := Color(0.78, 0.74, 0.68)
	# --- mureta entre o calçadão e a areia, com duas aberturas (à plataforma e ao molhe)
	var trechos := [[-42.0, -20.0], [-8.0, 18.0], [30.0, 42.0]]
	for t in trechos:
		var a: float = t[0]
		var b: float = t[1]
		var cx := (a + b) * 0.5
		L.caixa(Vector3(cx, 0.4, -8.2), Vector3(b - a, 0.8, 0.35), clara)
		L.caixa(Vector3(cx, 0.85, -8.2), Vector3(b - a + 0.1, 0.1, 0.55), Color(0.86, 0.83, 0.78))
		Ato2Pecas.colisao_invisivel(self, Vector3(b - a, 1.0, 0.45), Vector3(cx, 0.5, -8.2))
	# --- postes de luz (a lâmpada acesa fica no lote sem luz)
	for x in [-36.0, -24.0, -12.0, 0.0, 12.0, 24.0, 36.0]:
		L.caixa(Vector3(x, 2.5, -5.0), Vector3(0.14, 5.0, 0.14), Color(0.2, 0.21, 0.23))
		L.caixa(Vector3(x, 4.95, -5.45), Vector3(0.1, 0.08, 0.9), Color(0.2, 0.21, 0.23))
		S.caixa(Vector3(x, 4.85, -5.9), Vector3(0.32, 0.12, 0.32), Color(1.0, 0.82, 0.5))
	# --- bancos virados para o rio
	for x in [-31.0, -4.0, 4.0, 16.0, 34.0]:
		var madeira := Color(0.45, 0.32, 0.2)
		L.caixa(Vector3(x, 0.46, -6.2), Vector3(1.7, 0.07, 0.5), madeira)
		L.caixa(Vector3(x, 0.8, -5.95), Vector3(1.7, 0.4, 0.06), madeira)
		L.caixa(Vector3(x - 0.7, 0.22, -6.2), Vector3(0.08, 0.44, 0.45), Color(0.18, 0.18, 0.2))
		L.caixa(Vector3(x + 0.7, 0.22, -6.2), Vector3(0.08, 0.44, 0.45), Color(0.18, 0.18, 0.2))
		Ato2Pecas.colisao_invisivel(self, Vector3(1.7, 0.9, 0.6), Vector3(x, 0.45, -6.1))
	# --- quiosques FECHADOS (fora de temporada), de frente para o calçadão
	var quiosques := [[-22.0, "SORVETES", Color(0.86, 0.78, 0.62), Color(0.8, 0.3, 0.3)],
		[-2.0, "CALDO DE PEIXE", Color(0.7, 0.82, 0.86), Color(0.2, 0.45, 0.65)],
		[12.0, "ARTESANATO", Color(0.88, 0.72, 0.66), Color(0.9, 0.6, 0.2)],
		[32.0, "PASTEL", Color(0.82, 0.86, 0.66), Color(0.35, 0.6, 0.35)]]
	for q in quiosques:
		_quiosque(L, q[0], q[1], q[2], q[3])
	# --- barracas cobertas por lona
	for x in [-11.0, 21.0]:
		L.caixa(Vector3(x, 0.55, 3.4), Vector3(2.4, 1.1, 1.5), Color(0.18, 0.28, 0.5))
		L.caixa(Vector3(x, 1.2, 3.4), Vector3(2.7, 0.12, 1.8), Color(0.25, 0.38, 0.62))
		for dx in [-1.2, 1.2]:
			L.caixa(Vector3(x + dx, 1.1, 2.5), Vector3(0.08, 2.2, 0.08), Color(0.3, 0.3, 0.32))
		L.caixa(Vector3(x, 2.25, 2.7), Vector3(2.9, 0.1, 1.5), Color(0.9, 0.9, 0.85) if int(x) % 2 == 0 else Color(0.85, 0.35, 0.3))
		Ato2Pecas.colisao_invisivel(self, Vector3(2.6, 1.2, 1.7), Vector3(x, 0.6, 3.4))
	# --- piso claro do calçadão (a pedra escura da base ficaria pesada demais ao entardecer), com juntas
	L.caixa(Vector3(0, 0.012, 0.5), Vector3(88.0, 0.024, 17.1), Color(0.72, 0.68, 0.62))
	L.caixa(Vector3(0, 0.014, -7.7), Vector3(88.0, 0.028, 0.6), Color(0.55, 0.52, 0.48))
	for i in 23:
		L.caixa(Vector3(-44.0 + i * 4.0, 0.015, 0.5), Vector3(0.07, 0.03, 17.1), Color(0.5, 0.47, 0.43))
	for i in 5:
		L.caixa(Vector3(0, 0.015, -4.0 + i * 3.4), Vector3(88.0, 0.03, 0.07), Color(0.5, 0.47, 0.43))
	# --- a rua atrás do calçadão
	L.caixa(Vector3(0, 0.01, 12.3), Vector3(88.0, 0.04, 6.3), Color(0.2, 0.2, 0.22))
	L.caixa(Vector3(0, 0.06, 9.05), Vector3(88.0, 0.12, 0.3), Color(0.72, 0.7, 0.66))
	for i in 11:
		L.caixa(Vector3(-40.0 + i * 8.0, 0.036, 12.3), Vector3(2.4, 0.01, 0.16), Color(0.85, 0.78, 0.4))
	_fechar_lote(L, false, "CalcadaoPecas")
	_fechar_lote(S, true, "CalcadaoLuzes")


func _quiosque(L: Lote, x: float, nome: String, parede: Color, toldo: Color) -> void:
	L.caixa(Vector3(x, 1.5, 4.0), Vector3(5.0, 3.0, 3.4), parede)
	L.caixa(Vector3(x, 3.12, 3.7), Vector3(5.8, 0.25, 4.4), Color(0.55, 0.28, 0.2))
	L.caixa(Vector3(x, 1.35, 2.27), Vector3(4.0, 1.7, 0.08), Color(0.55, 0.58, 0.6))     # persiana baixada
	for i in 4:
		L.caixa(Vector3(x, 0.8 + i * 0.4, 2.2), Vector3(4.0, 0.04, 0.06), Color(0.4, 0.42, 0.45))
	for i in 6:                                                                       # toldo listrado
		L.caixa(Vector3(x - 2.0 + 0.4 + i * 0.8, 2.6, 1.7), Vector3(0.8, 0.08, 1.2), toldo if i % 2 == 0 else Color(0.92, 0.9, 0.84))
	L.caixa(Vector3(x + 1.75, 1.45, 2.17), Vector3(0.62, 0.42, 0.03), Color(0.95, 0.92, 0.82))   # cartaz "FECHADO"
	Ato2Pecas.colisao_invisivel(self, Vector3(5.0, 3.0, 3.4), Vector3(x, 1.5, 4.0))
	var r := Construtor.rotulo(self, nome, Vector3(x, 2.9, 2.18), 40, Color(0.2, 0.15, 0.12))
	r.rotation_degrees.y = 180.0
	var f := Construtor.rotulo(self, "FECHADO\nvolta no verão", Vector3(x + 1.75, 1.45, 2.14), 22, Color(0.55, 0.12, 0.1))
	f.rotation_degrees.y = 180.0


## O fundo: prédios da orla de Imbé atrás da rua, a outra margem do rio (Tramandaí) e a ponte ao longe, tudo em silhueta.
func _ao_fundo() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var L := Lote.new()
	var S := Lote.new()
	var pastel := [Color(0.9, 0.7, 0.6), Color(0.7, 0.8, 0.85), Color(0.9, 0.85, 0.6), Color(0.75, 0.6, 0.7), Color(0.8, 0.86, 0.72)]
	var x := -58.0
	var i := 0
	while x < 60.0:
		var w := rng.randf_range(8.5, 11.0)
		var h := rng.randf_range(7.0, 16.0)
		L.caixa(Vector3(x, h * 0.5 - 0.6, 22.5), Vector3(w, h, 8.0), pastel[i % pastel.size()])
		var andares := int(h / 3.2)
		for a in andares:
			for col in 3:
				var acesa := rng.randf() < 0.35
				S.caixa(Vector3(x - w * 0.3 + col * w * 0.3, 2.0 + a * 3.0, 18.46), Vector3(1.0, 1.2, 0.06),
					Color(1.0, 0.78, 0.45) if acesa else Color(0.16, 0.18, 0.28))
		x += w + rng.randf_range(0.5, 2.0)
		i += 1
	# outra margem (Tramandaí): faixa baixa escura com prédios pequenos
	var escuro := Color(0.1, 0.07, 0.12)
	L.caixa(Vector3(0, 0.0, -170.0), Vector3(900, 3.0, 20.0), escuro)
	for k in 34:
		var xx := -300.0 + k * 18.0 + rng.randf() * 8.0
		var hh := rng.randf_range(4.0, 16.0) if rng.randf() < 0.85 else rng.randf_range(18.0, 26.0)
		L.caixa(Vector3(xx, hh * 0.5, -168.0), Vector3(rng.randf_range(6, 12), hh, rng.randf_range(6, 10)), escuro)
		if rng.randf() < 0.5:
			S.caixa(Vector3(xx, hh * 0.6, -163.0), Vector3(0.8, 0.8, 0.2), Color(1.0, 0.72, 0.4))
	# ponte Giuseppe Garibaldi (3 pistas) à esquerda, contra o sol baixo
	var xp := -95.0
	var sombra := Color(0.08, 0.05, 0.09)
	S.caixa(Vector3(xp, 7.0, -92.0), Vector3(14, 1.2, 156.0), sombra)
	for k in 13:
		var zz := -24.0 - k * 11.5
		S.caixa(Vector3(xp, 3.0, zz), Vector3(2.0, 8.0, 2.0), sombra)
		S.caixa(Vector3(xp - 6.8, 8.6, zz), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.75, 0.4))
		S.caixa(Vector3(xp + 6.8, 8.6, zz), Vector3(0.3, 0.3, 0.3), Color(1.0, 0.75, 0.4))
	# luz de sinalização na ponta do molhe
	S.caixa(Vector3(26.0, 2.0, -46.5), Vector3(0.12, 3.0, 0.12), Color(0.3, 0.3, 0.32))
	S.caixa(Vector3(26.0, 3.7, -46.5), Vector3(0.35, 0.35, 0.35), Color(1.0, 0.25, 0.2))
	_fechar_lote(L, false, "Fundo")
	_fechar_lote(S, true, "FundoLuzes")


func _plataforma_e_placas() -> void:
	var L := Lote.new()
	var S := Lote.new()
	# plataforma de madeira (só visual: o chão é o mesmo) com bandeira laranja, boias e um balde
	for i in 5:
		L.caixa(Vector3(PONTO.x, 0.022, PONTO.z - 1.0 + i * 0.5), Vector3(5.0, 0.05, 0.46),
			Color(0.46, 0.33, 0.21) if i % 2 == 0 else Color(0.4, 0.29, 0.19))
	L.caixa(Vector3(PONTO.x + 2.7, 3.3, PONTO.z - 0.9), Vector3(0.16, 6.6, 0.16), Color(0.85, 0.85, 0.82))
	S.caixa(Vector3(PONTO.x + 3.7, 5.9, PONTO.z - 0.9), Vector3(2.0, 1.0, 0.06), Color(1.0, 0.5, 0.1))
	for dx in [-2.4, 2.4]:
		L.caixa(Vector3(PONTO.x + dx, 0.5, PONTO.z - 1.15), Vector3(0.12, 1.0, 0.12), Color(0.35, 0.25, 0.17))
		L.caixa(Vector3(PONTO.x + dx, 1.05, PONTO.z - 1.15), Vector3(0.28, 0.2, 0.28), Color(0.9, 0.25, 0.2) if dx < 0 else Color(0.95, 0.95, 0.92))
	L.caixa(Vector3(PONTO.x - 1.9, 0.2, PONTO.z + 0.6), Vector3(0.38, 0.4, 0.38), Color(0.2, 0.35, 0.6))
	# placa grande, bem à vista de quem vem do Spawn: onde jogar a tarrafa
	var pl := Vector3(-28.5, 0.0, -3.2)
	L.caixa(Vector3(pl.x - 1.3, 1.3, pl.z), Vector3(0.14, 2.6, 0.14), Color(0.32, 0.22, 0.14))
	L.caixa(Vector3(pl.x + 1.3, 1.3, pl.z), Vector3(0.14, 2.6, 0.14), Color(0.32, 0.22, 0.14))
	L.caixa(Vector3(pl.x, 2.0, pl.z), Vector3(3.0, 1.1, 0.1), Color(0.95, 0.55, 0.12))
	Ato2Pecas.colisao_invisivel(self, Vector3(3.0, 2.6, 0.3), Vector3(pl.x, 1.3, pl.z))
	var t := Construtor.rotulo(self, "PESCA COM O BOTO", Vector3(pl.x, 2.18, pl.z + 0.07), 46, Color(0.1, 0.06, 0.02))
	t.name = "TextoPesca"
	Construtor.rotulo(self, "na beira do rio, na bandeira laranja", Vector3(pl.x, 1.82, pl.z + 0.07), 24, Color(0.1, 0.06, 0.02)).name = "TextoPesca2"
	# a plaquinha educativa (do Programa Municipal de Memória Interativa, fictício)
	var pq := Vector3(-21.8, 0.0, -7.2)
	L.caixa(Vector3(pq.x - 1.2, 0.7, pq.z), Vector3(0.12, 1.4, 0.12), Color(0.3, 0.3, 0.32))
	L.caixa(Vector3(pq.x + 1.2, 0.7, pq.z), Vector3(0.12, 1.4, 0.12), Color(0.3, 0.3, 0.32))
	L.caixa(Vector3(pq.x, 1.45, pq.z), Vector3(2.9, 1.5, 0.1), Color(0.1, 0.2, 0.42))
	Ato2Pecas.colisao_invisivel(self, Vector3(2.9, 2.0, 0.3), Vector3(pq.x, 1.0, pq.z))
	var e := Construtor.rotulo(self, "PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA", Vector3(pq.x, 2.05, pq.z + 0.06), 20, Color(0.8, 0.85, 0.95))
	e.name = "PlacaTopo"
	var corpo := Construtor.rotulo(self, "PESCA COM BOTOS\n\nNa foz do rio Tramandaí, botos e\npescadores trabalham juntos.\nO boto avisa a hora da tarrafa.\nEm 2026 isso virou Patrimônio\nCultural do Brasil.", Vector3(pq.x, 1.4, pq.z + 0.06), 24, Color(1, 0.97, 0.85))
	corpo.name = "PlacaTexto"
	_fechar_lote(L, false, "PlataformaPecas")
	_fechar_lote(S, true, "PlataformaLuzes")
	_spot = interagivel("Jogar a tarrafa com o boto", Vector3(PONTO.x, 1.0, PONTO.z), Vector3(5.0, 2.0, 3.0), func(_p: Node) -> void: comecar_pesca())
	_spot.name = "PontoTarrafa"
	interagivel("Ler a plaquinha", Vector3(pq.x, 1.2, pq.z + 0.3), Vector3(3.0, 1.8, 0.8), func(_p: Node) -> void: _ler_plaquinha()).name = "Plaquinha"
	# a pilha da rede cheia (rede, tainhas e uma sandália de criança): só aparece quando a rede enche
	_pilha = Node3D.new()
	_pilha.name = "RedeCheia"
	_pilha.position = Vector3(PONTO.x + 1.7, 0.0, PONTO.z + 0.85)
	_pilha.visible = false
	add_child(_pilha)
	var P := Lote.new()
	P.caixa(Vector3(0, 0.06, 0), Vector3(1.1, 0.12, 0.85), Color(0.14, 0.13, 0.17), 20.0)
	for k in 5:
		P.caixa(Vector3(-0.3 + k * 0.15, 0.17 + (k % 2) * 0.04, -0.15 + (k % 3) * 0.14), Vector3(0.5, 0.09, 0.13), Color(0.82, 0.86, 0.9), -25.0 + k * 22.0)
	P.caixa(Vector3(0.25, 0.28, 0.1), Vector3(0.14, 0.035, 0.32), Color(0.3, 0.52, 0.9), 35.0)             # sola da sandália
	P.caixa(Vector3(0.25, 0.31, 0.06), Vector3(0.14, 0.02, 0.05), Color(0.95, 0.8, 0.2), 35.0)             # tira
	P.caixa(Vector3(0.26, 0.31, 0.13), Vector3(0.05, 0.02, 0.14), Color(0.95, 0.8, 0.2), 35.0)
	_fechar_lote(P, false, "Pilha", _pilha)


## Pega o desenho do boto e dos pescadores do flashback (`barra.gd`, que não muda) sem copiá-lo: o script é instanciado FORA da
## árvore (o `_ready` dele não roda), chamamos `_criar_pescadores`/`_criar_boto` e passamos os nós prontos para esta cena.
func _modelos_do_flashback() -> void:
	var flash: Node3D = (load("res://world/niveis/barra.gd") as GDScript).new()
	flash.call("_criar_pescadores")
	flash.call("_criar_boto")
	var peixeiros: Array = flash.get("_pescadores")
	# 4 dos 6 pescadores, espalhados pela margem, longe da plataforma; viram genéricos e ficam com os pés n'água
	var xs := [-27.0, -21.0, -5.5, 0.5]
	var vivos: Array[Node3D] = []
	for k in peixeiros.size():
		var p: Node3D = peixeiros[k]
		flash.remove_child(p)
		if k < xs.size():
			p.position = Vector3(xs[k], COTA_AGUA - 0.05, MARGEM_Z - 0.5 - (k % 2) * 0.6)
			p.rotation_degrees.y = (k * 37 % 20) - 10.0
			add_child(p)
			vivos.append(p)
		else:
			p.free()
	_pescadores = vivos
	boto = flash.get("boto")
	_exclama = flash.get("_exclama")
	_boto_corpo = boto.get_child(0)
	flash.remove_child(boto)
	flash.remove_child(_exclama)
	add_child(boto)
	add_child(_exclama)
	boto.position = _boto_pos
	flash.free()


func _pescador_velho() -> void:
	velho = Node3D.new()
	velho.name = "PescadorVelho"
	velho.position = VELHO_POS
	velho.rotation_degrees.y = 25.0          # de frente para o rio, meio de lado para o calçadão
	add_child(velho)
	var jaqueta := Ato2Pecas.mat_cor(Color(0.34, 0.4, 0.28))
	var calca := Ato2Pecas.mat_cor(Color(0.22, 0.24, 0.3))
	var pele := Ato2Pecas.mat_cor(Color(0.66, 0.48, 0.38))
	var palha := Ato2Pecas.mat_cor(Color(0.82, 0.72, 0.45))
	var caixa := Ato2Pecas.mat_cor(Color(0.85, 0.85, 0.82))
	var corpo := CapsuleMesh.new()
	corpo.radius = 0.24
	corpo.height = 0.95
	var cabeca := SphereMesh.new()
	cabeca.radius = 0.14
	cabeca.height = 0.28
	var chapeu := CylinderMesh.new()
	chapeu.top_radius = 0.13
	chapeu.bottom_radius = 0.36
	chapeu.height = 0.12
	var perna := CapsuleMesh.new()
	perna.radius = 0.1
	perna.height = 0.7
	var vara := CylinderMesh.new()
	vara.top_radius = 0.008
	vara.bottom_radius = 0.02
	vara.height = 3.0
	Construtor.caixa(velho, Vector3(0.7, 0.45, 0.45), Vector3(0, 0.225, 0), caixa, false, "Caixa")     # caixa de isopor onde ele senta
	Ato2Pecas.malha(velho, corpo, Vector3(0, 0.95, 0.02), jaqueta, Vector3(8, 0, 0))
	Ato2Pecas.malha(velho, cabeca, Vector3(0, 1.58, -0.04), pele)
	Ato2Pecas.malha(velho, chapeu, Vector3(0, 1.74, -0.04), palha)
	Ato2Pecas.malha(velho, perna, Vector3(-0.13, 0.5, -0.3), calca, Vector3(-80, 0, 0))
	Ato2Pecas.malha(velho, perna, Vector3(0.13, 0.5, -0.3), calca, Vector3(-80, 0, 0))
	Ato2Pecas.malha(velho, vara, Vector3(0.3, 1.5, -1.2), Ato2Pecas.mat_cor(Color(0.2, 0.15, 0.1)), Vector3(-62, 0, 0))
	_exclama_velho = Construtor.rotulo(self, "!", VELHO_POS + Vector3(0, 2.7, 0), 120, Color(1.0, 0.85, 0.2))
	_exclama_velho.pixel_size = 0.008
	_exclama_velho.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_exclama_velho.no_depth_test = true
	_exclama_velho.outline_size = 20
	_exclama_velho.outline_modulate = Color(0.2, 0.05, 0.0)
	_exclama_velho.visible = false
	interagivel("Falar com o pescador", VELHO_POS + Vector3(0, 1.0, 0), Vector3(2.0, 2.2, 2.0), func(_p: Node) -> void: falar_velho()).name = "PescadorVelhoFala"
	Ato2Pecas.colisao_invisivel(self, Vector3(0.9, 1.2, 0.7), VELHO_POS + Vector3(0, 0.6, 0))


func _ui() -> void:
	var camada := CanvasLayer.new()
	camada.name = "PescaUI"
	camada.layer = 8
	add_child(camada)
	_lbl_placar = Label.new()
	_lbl_placar.anchor_left = 1.0
	_lbl_placar.anchor_right = 1.0
	_lbl_placar.offset_left = -24.0
	_lbl_placar.offset_right = -24.0
	_lbl_placar.offset_top = 70.0
	_lbl_placar.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_lbl_placar.add_theme_font_size_override("font_size", 28)
	_lbl_placar.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_placar.add_theme_constant_override("outline_size", 8)
	_lbl_placar.visible = false
	camada.add_child(_lbl_placar)
	_lbl_dica = Label.new()
	_lbl_dica.text = Celular.dica("Clique ou [E] para lançar a tarrafa", "Toque em Interagir para lançar a tarrafa")
	_lbl_dica.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_lbl_dica.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_lbl_dica.offset_top = -150.0
	_lbl_dica.add_theme_font_size_override("font_size", 30)
	_lbl_dica.add_theme_color_override("font_outline_color", Color.BLACK)
	_lbl_dica.add_theme_constant_override("outline_size", 8)
	_lbl_dica.visible = false
	camada.add_child(_lbl_dica)
	_atualizar_placar()


func _luzes_do_calcadao() -> void:
	# as lâmpadas acendem aos poucos com o escurecer (energia sobe em `_ceu_escurecendo`); no máximo 5 luzes
	for p in [Vector3(-24.0, 4.3, -5.9), Vector3(0.0, 4.3, -5.9), Vector3(24.0, 4.3, -5.9), Vector3(PONTO.x, 2.6, PONTO.z + 1.4), Vector3(VELHO_POS.x - 1.0, 2.4, VELHO_POS.z + 1.4)]:
		var l := Construtor.luz(self, p, Color(1.0, 0.8, 0.5), 0.0, 11.0)
		_luzes.append(l)


func _marcadores_extra() -> void:
	# o aquecimento de shaders do Main passa pelos "Cam_*": a água e os quiosques entram nele
	var rio := Marker3D.new()
	rio.name = "Cam_rio"
	rio.position = Vector3(PONTO.x, 0.1, PONTO.z + 0.5)
	add_child(rio)
	var qui := Marker3D.new()
	qui.name = "Cam_quiosques"
	qui.position = Vector3(-10.0, 0.1, -4.0)
	qui.rotation_degrees.y = 180.0
	add_child(qui)


# ============================================================================ a tarefa
func _tarefa() -> void:
	_atualizar_objetivo()
	if not pulou_intro:
		if GameState.cidade_feita(id):
			Guia.falar("taina", ["De volta à Barra! Quer pescar mais um pouquinho?"])
		else:
			Guia.falar("taina", ["Chegamos na Barra! É aqui que o boto ajuda os pescadores.",
				"Vai até a bandeira laranja, na beira do rio, e joga a tarrafa com ele!"])


## 0 = ir pescar, 1 = pescando, 2 = falar com o pescador mais velho, 3 = feito.
func estagio() -> int:
	if GameState.flag("pista_barra_pescador"):
		return 3
	if rede_cheia:
		return 2
	return 1 if em_pesca else 0


func _atualizar_objetivo() -> void:
	_texto_estagio()
	_ocioso = 0.0
	_exclama_velho.visible = estagio() == 2


## Escreve o objetivo do estágio (o Mapa lê `_texto_objetivo`, que acrescenta a "Dica:" se o jogador demora).
func _texto_estagio() -> void:
	match estagio():
		0: definir_objetivo("Jogue a tarrafa com o boto, na beira do rio (bandeira laranja).")
		1: definir_objetivo(Celular.dica("Jogue a tarrafa quando o boto bater a cabeça na água (E ou clique).", "Jogue a tarrafa quando o boto bater a cabeça na água (botão Interagir)."))
		2: definir_objetivo("Fale com o pescador mais velho, sentado perto do molhe.")
		_: definir_objetivo("Aqui está tudo certo. Volte ao Castelinho pelo portão.")


func _texto_objetivo() -> String:
	if GameState.cidade_feita(id):
		return super()
	_texto_estagio()
	var t := super()
	if _ocioso > DICA_APOS:
		t += "  Dica: " + _dica_extra()
	return t


func _dica_extra() -> String:
	match estagio():
		0: return "a plataforma de madeira fica na beira da água, com uma bandeira laranja. Chegue perto e aperte E."
		1: return "o boto aparece com um ! amarelo. Essa é a hora de lançar."
		_: return "ele está sentado na areia, ao lado das pedras do molhe, à direita."


func _ler_plaquinha() -> void:
	await Guia.falar("sistema", ["Programa Municipal de Memória Interativa. Placa: Pesca com botos.",
		"Na foz do rio Tramandaí, botos e pescadores pescam juntos há mais de cem anos. O boto empurra as tainhas para perto da margem e bate a cabeça na água para avisar a hora de lançar a tarrafa.",
		"Em 2026 essa tradição foi reconhecida como Patrimônio Cultural do Brasil. Para ela continuar, o rio precisa ficar limpo. Cuide dele."])
	_ocioso = 0.0


## E no ponto da tarrafa: começa a pesca (rejogável: depois da rede cheia, recomeça do zero).
func comecar_pesca() -> void:
	if em_pesca or conversando:
		return
	em_pesca = true
	rede_cheia = false
	_pilha.visible = false
	lances_ok = 0
	tainhas = 0
	perdidas = 0
	_cedos = 0
	_sessao += 1
	fase = Fase.ESPERA
	_desde_lance = -0.4                                      # o mesmo E que abriu a pesca não lança a tarrafa
	_spot.collision_layer = 0                                # sem o aviso de "Jogar a tarrafa" enquanto pesca (E é o lance)
	_atualizar_placar()
	_lbl_placar.visible = true
	_atualizar_objetivo()
	if is_instance_valid(player):
		player.olhar_para(Vector3(PONTO.x, 1.0, ALVO_Z), 0.5)
	_rodar_pesca(_sessao)


func _cancelar_pesca() -> void:
	if not em_pesca:
		return
	em_pesca = false
	_sessao += 1
	fase = Fase.LIVRE
	janela_aberta = false
	_exclama.visible = false
	_lbl_placar.visible = false
	_spot.collision_layer = 4
	_atualizar_objetivo()


func _rodar_pesca(sid: int) -> void:
	if not _explicou and not pulou_intro:
		_explicou = true
		await Guia.falar("taina", ["Olha o boto ali! Ele empurra as tainhas para perto da margem.",
			"Quando ele BATER A CABEÇA na água, joga a tarrafa! (clique ou E)",
			"Só dois lances. Se errar, é só tentar de novo, sem pressa."], true)
		if sid != _sessao:
			return
	while sid == _sessao and lances_ok < LANCES:
		fase = Fase.ESPERA
		var espera := randf_range(espera_min, espera_max)
		var t := 0.0
		while t < espera:
			await get_tree().process_frame
			if sid != _sessao:
				return
			t += get_process_delta_time()
		var alvo := Vector3(PONTO.x + randf_range(-2.0, 2.0), COTA_AGUA, ALVO_Z)
		await _boto_sinalizar(alvo, sid)
		if sid != _sessao:
			return
		while janela_aberta:
			await get_tree().process_frame
			if sid != _sessao:
				return
		if fase == Fase.JANELA:                                # a janela fechou sem lance
			perdidas += 1
			fase = Fase.ESPERA
			lance_feito.emit(lances_ok, false)
			if perdidas == 1 or perdidas % 3 == 0:
				_dica_taina(["Opa, perdeu a hora! Joga quando o boto bater a cabeça na água.", "Sem pressa, ele volta."])
		elif fase == Fase.LANCADO:
			perdidas = 0
			await get_tree().create_timer(1.5).timeout
			if sid != _sessao:
				return
	if sid == _sessao:
		await _encher_rede(sid)


func _dica_taina(linhas: Array) -> void:
	if not Guia.ocupado():
		Guia.falar("taina", linhas)


## Lançar a tarrafa (E ou clique, no `_process`; público para testes).
func lancar() -> void:
	if not em_pesca or _desde_lance < 0.4:
		return
	if is_instance_valid(player) and Vector2(player.global_position.x - PONTO.x, player.global_position.z - PONTO.z).length() > RAIO_LANCE:
		if not Guia.ocupado():
			Guia.falar("taina", ["Chega mais perto da beira, guri! Lá na plataforma de madeira."])
		return
	if fase == Fase.JANELA and janela_aberta:
		_desde_lance = 0.0
		_lance_certo()
	elif fase == Fase.ESPERA:
		_desde_lance = 0.0
		_lance_cedo()


func _origem_rede() -> Vector3:
	if not is_instance_valid(player):
		return Vector3(PONTO.x, 1.4, PONTO.z)
	return player.global_position + Vector3(0.0, 1.3, 0.0) - player.global_transform.basis.z * 0.5


func _lance_cedo() -> void:
	_cedos += 1
	Audio.sfx("tarrafa", -3.0)
	var dest := Vector3(PONTO.x + randf_range(-1.5, 1.5), COTA_AGUA, ALVO_Z + 1.5)
	var rede := _rede_voo(_origem_rede(), dest, 0.5, 0.9)
	lance_feito.emit(lances_ok, false)
	await get_tree().create_timer(0.55).timeout
	_splash(dest, 0.8)
	Audio.sfx("splash", -8.0)
	if _cedos == 1 or _cedos % 3 == 0:
		_dica_taina(["Calma! Espera o boto bater a cabeça na água!"])
	await get_tree().create_timer(0.5).timeout
	_afundar_rede(rede)


func _lance_certo() -> void:
	janela_aberta = false
	_exclama.visible = false
	fase = Fase.LANCADO
	lances_ok += 1
	perdidas = 0
	var n := lances_ok
	var qtd := 4 + n
	tainhas += qtd
	_atualizar_placar()
	_ocioso = 0.0
	lance_feito.emit(n, true)
	Audio.sfx("tarrafa", -3.0)
	var alvo := Vector3(_alvo_atual.x, COTA_AGUA, ALVO_Z)
	var rede := _rede_voo(_origem_rede(), alvo, 0.55, 0.9)
	await get_tree().create_timer(0.6).timeout
	if not is_inside_tree():
		return
	_splash(alvo, 1.2)
	_peixes(alvo, qtd)
	Audio.sfx("acerto", -6.0)
	if n == 1:
		_dica_taina(["Boa! Pegou umas tainhas!", "Mais um lance e a rede enche."])
	await get_tree().create_timer(0.9).timeout
	if is_instance_valid(rede):
		_afundar_rede(rede)


func _encher_rede(sid: int) -> void:
	fase = Fase.LIVRE
	em_pesca = false
	rede_cheia = true
	_spot.collision_layer = 4
	_pilha.visible = true
	_atualizar_placar()
	_atualizar_objetivo()
	rede_encheu.emit()
	Audio.sfx("acerto", -3.0)
	await get_tree().create_timer(1.2).timeout
	if sid != _sessao or not is_inside_tree():
		return
	_lbl_placar.visible = false
	if GameState.flag("pista_barra_pescador"):
		await Guia.falar("taina", ["Rede cheia de novo! Que boto bom."])
	else:
		await Guia.falar("taina", ["Rede cheia! Olha só quantas tainhas!",
			"...Peraí. Tem uma sandalinha ali no meio. Pequena. De criança.",
			"O pescador mais velho, sentado perto do molhe, está olhando pra gente. Vamos falar com ele?"])


## E no pescador mais velho (público para testes).
func falar_velho() -> void:
	if conversando:
		return
	if em_pesca:
		if not Guia.ocupado():
			Guia.falar("taina", ["Primeiro termina a tarrafa! O boto está esperando."])
		return
	conversando = true
	_ocioso = 0.0
	var ja_tem: bool = GameState.flag("pista_barra_pescador")
	if not rede_cheia and not ja_tem:
		await Guia.falar("pescador", ["Ô guri, tá olhando o quê? Quer conversa, então ajuda na pesca.",
			"Joga a tarrafa com o boto, ali na plataforma. Quando a rede encher, eu te conto."])
		conversando = false
		return
	if ja_tem:
		await Guia.falar("pescador", ["Pesca boa, guri. O boto não erra a hora.",
			"Aquele menino... eu ainda penso nele quando o rio fica quieto assim."])
		conversando = false
		conversou.emit()
		return
	await Guia.falar("pescador", ["Bonito lance, guri. O boto gostou de ti.",
		"Eu pesco aqui desde antes de ter essa ponte toda iluminada. Vejo tudo que passa pela barra.",
		"Faz muito tempo, no fim de uma temporada. A praia já tava vazia.",
		"Um menino seguiu uma moça de branco, pela beira do rio, até o braço morto.",
		"Gritei pra ele voltar. Ele não olhou pra trás.",
		"Nunca contei isso pra ninguém. Ninguém ia acreditar."], true)
	var nova: bool = await pista("barra_pescador")
	_atualizar_objetivo()
	await Guia.falar("taina", ["Uma moça de branco... até o braço morto.",
		"Será que o menino é o Tito? Anotei essa pista. Obrigada, seu pescador!"], true)
	conversando = false
	conversou.emit()
	if nova or not GameState.cidade_feita(id):
		concluir()


# ============================================================================ animação do boto, tarrafa e água
func _process(dt: float) -> void:
	_t += dt
	_desde_lance += dt
	if Guia.ocupado():
		_desde_guia = 0.0
	else:
		_desde_guia += dt
	if not Guia.ocupado() and not GameState.flag("ui_aberta"):
		_ocioso += dt
	if _boto_nada and boto != null:
		_nadar(dt)
	if janela_aberta:
		_janela_t -= dt
		if _janela_t <= 0.0:
			janela_aberta = false
			_exclama.visible = false
	_lbl_dica.visible = em_pesca and (fase == Fase.ESPERA or fase == Fase.JANELA) and not Guia.ocupado()
	if em_pesca and is_instance_valid(player):
		if Vector2(player.global_position.x - PONTO.x, player.global_position.z - PONTO.z).length() > RAIO_SAIR:
			_cancelar_pesca()
		elif Input.is_action_just_pressed("interagir") and player.pode_mover and (fase == Fase.JANELA \
				or (fase == Fase.ESPERA and _desde_guia > 0.35)):       # (o clique que fecha uma fala não vira lance cedo)
			lancar()
	_dica_taina_parado()
	_prox_dusk -= dt
	if _prox_dusk <= 0.0:
		_prox_dusk = 0.5
		_ceu_escurecendo(minf(_t / DUSK_SEG, 1.0) * DUSK_MAX)


## Se o jogador fica parado sem fazer nada, a Tainá lembra uma vez por etapa (o Mapa já traz a dica por escrito).
func _dica_taina_parado() -> void:
	if _ocioso < DICA_APOS * 1.6 or estagio() == _lembrou_estagio or Guia.ocupado() or GameState.cidade_feita(id):
		return
	_lembrou_estagio = estagio()
	_ocioso = DICA_APOS + 1.0
	var d := _dica_extra()
	Guia.falar("taina", ["Precisa de ajuda? " + d.substr(0, 1).to_upper() + d.substr(1)])


func _nadar(dt: float) -> void:
	# o boto nada de um lado para o outro à frente da plataforma, só a nadadeira cortada à mostra
	var alvo := Vector3(PONTO.x + sin(_t * 0.42) * 7.0, COTA_AGUA - 0.5, BOTO_Z + sin(_t * 0.27) * 1.4)
	var d := alvo - _boto_pos
	_boto_pos += d * clampf(dt * 1.6, 0.0, 1.0)
	_boto_pos.y = COTA_AGUA - 0.5 + sin(_t * 2.6) * 0.05
	if d.length() > 0.05:
		_boto_yaw = lerp_angle(_boto_yaw, atan2(-d.x, -d.z), clampf(dt * 3.0, 0.0, 1.0))
	boto.position = _boto_pos
	boto.rotation.y = _boto_yaw
	_boto_corpo.rotation.x = sin(_t * 2.6 + 1.0) * 0.12


## O boto vai até o ponto, sobe e BATE A CABEÇA na água; a janela do lance abre quando ele emerge.
func _boto_sinalizar(alvo: Vector3, sid: int) -> void:
	while _boto_ocupado:
		await get_tree().process_frame
	if sid != _sessao:
		return
	_boto_ocupado = true
	_alvo_atual = alvo
	_boto_nada = false
	var t := create_tween().set_parallel()
	t.tween_property(boto, "position", Vector3(alvo.x, COTA_AGUA - 0.5, alvo.z - 1.3), 1.3).set_trans(Tween.TRANS_SINE)
	t.tween_property(boto, "rotation:y", boto.rotation.y + angle_difference(boto.rotation.y, PI - 0.75), 1.1)
	t.tween_property(_boto_corpo, "rotation:x", 0.0, 1.0)
	await t.finished
	_boto_pos = boto.position
	_boto_yaw = boto.rotation.y
	var t2 := create_tween().set_parallel()
	t2.tween_property(boto, "position:y", COTA_AGUA + 0.25, 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t2.tween_property(_boto_corpo, "rotation:x", 0.75, 0.4)
	await t2.finished
	if sid == _sessao:
		_exclama.global_position = Vector3(alvo.x, 3.2, alvo.z - 0.6)
		_exclama.visible = true
		janela_aberta = true
		_janela_t = JANELA_BASE + minf(perdidas, 3) * 0.5
		fase = Fase.JANELA
	await get_tree().create_timer(0.18).timeout
	var t3 := create_tween().set_parallel()
	t3.tween_property(_boto_corpo, "rotation:x", -0.45, 0.12).set_trans(Tween.TRANS_QUAD)
	t3.tween_property(boto, "position:y", COTA_AGUA - 0.35, 0.12)
	await t3.finished
	_splash(Vector3(alvo.x, COTA_AGUA, alvo.z - 0.9), 1.0)
	Audio.sfx("splash", -4.0)
	for p in _pescadores:
		if randf() < 0.6:
			_rede_npc(p)
	var t5 := create_tween().set_parallel()
	t5.tween_property(_boto_corpo, "rotation:x", 0.0, 0.5)
	t5.tween_property(boto, "position:y", COTA_AGUA - 0.5, 0.5)
	await t5.finished
	_boto_pos = boto.position
	_boto_nada = true
	_boto_ocupado = false


func _rede_voo(inicio: Vector3, destino: Vector3, dur: float, raio: float) -> Node3D:
	var rede := Node3D.new()
	add_child(rede)
	var mi := Ato2Pecas.malha(rede, _malha_rede, Vector3.ZERO, _mat_rede)
	mi.name = "Rede"
	rede.position = inicio
	rede.scale = Vector3.ONE * 0.35
	var k0 := raio / 0.9
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		if not is_instance_valid(rede):
			return
		var p := inicio.lerp(destino, k)
		p.y += sin(k * PI) * 2.0
		rede.position = p
		var s := lerpf(0.35, 1.7, minf(k * 1.6, 1.0)) * k0
		rede.scale = Vector3(s, lerpf(s, 0.35, k * k), s), 0.0, 1.0, dur)
	return rede


func _rede_npc(p: Node3D) -> void:
	var inicio := p.global_position + Vector3(0.4, 1.9, -0.4)
	var dest := p.global_position + Vector3(randf_range(-2.0, 2.0), 0.0, -randf_range(4.0, 7.0))
	dest.y = COTA_AGUA
	var rede := _rede_voo(inicio, dest, 0.6, 0.8)
	var t := create_tween()
	t.tween_interval(0.6)
	t.tween_callback(func() -> void: _splash(dest, 0.7))
	t.tween_interval(0.7)
	t.tween_callback(func() -> void:
		if is_instance_valid(rede):
			_afundar_rede(rede))


func _afundar_rede(rede: Node3D) -> void:
	if not is_instance_valid(rede):
		return
	var t := create_tween().set_parallel()
	t.tween_property(rede, "position:y", COTA_AGUA - 1.0, 0.8)
	t.tween_property(rede, "scale", Vector3(0.3, 0.1, 0.3), 0.8)
	t.chain().tween_callback(rede.queue_free)


func _splash(pos: Vector3, tam: float) -> void:
	var anel := MeshInstance3D.new()
	var tor := TorusMesh.new()
	tor.inner_radius = 0.35
	tor.outer_radius = 0.42
	tor.rings = 16
	tor.ring_segments = 4
	anel.mesh = tor
	anel.material_override = _mat_espuma
	anel.position = Vector3(pos.x, COTA_AGUA + 0.04, pos.z)
	anel.scale = Vector3(0.4, 0.2, 0.4)
	add_child(anel)
	var t := create_tween().set_parallel()
	t.tween_property(anel, "scale", Vector3(3.2, 0.2, 3.2) * tam, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.tween_property(anel, "position:y", COTA_AGUA - 0.05, 1.1)
	t.chain().tween_callback(anel.queue_free)


func _peixes(pos: Vector3, qtd: int) -> void:
	var peixe := SphereMesh.new()
	peixe.radius = 0.5
	peixe.height = 1.0
	peixe.radial_segments = 8
	peixe.rings = 4
	for i in qtd:
		var f := MeshInstance3D.new()
		f.mesh = peixe
		f.material_override = _mat_peixe
		f.scale = Vector3(0.07, 0.07, 0.3)
		f.position = Vector3(pos.x, COTA_AGUA, pos.z)
		add_child(f)
		var dir := Vector3(randf_range(-1.1, 1.1), 0.0, randf_range(-1.1, 1.1))
		var alto := randf_range(0.8, 1.6)
		var tg := create_tween()
		tg.tween_interval(i * 0.06)
		tg.tween_method(func(k: float) -> void:
			if not is_instance_valid(f):
				return
			f.position = Vector3(pos.x, COTA_AGUA, pos.z) + dir * k + Vector3(0, sin(k * PI) * alto, 0)
			f.rotation.z = k * 6.0, 0.0, 1.0, 0.9)
		tg.tween_callback(f.queue_free)


func _atualizar_placar() -> void:
	_lbl_placar.text = "Lances %d/%d   Tainhas %d" % [lances_ok, LANCES, tainhas]


# ============================================================================ o fim de tarde vai escurecendo
## k = 0 (entardecer) .. 1 (noite). Mexe só no céu, na névoa, no Sol, na água e nas lâmpadas; `hora` continua ENTARDECER.
func _ceu_escurecendo(k: float) -> void:
	_dusk = k
	var a: Dictionary = CEUS[Hora.ENTARDECER]
	var b: Dictionary = CEUS[Hora.NOITE]
	var mat := env.sky.sky_material as ProceduralSkyMaterial
	mat.sky_top_color = (a["topo"] as Color).lerp(b["topo"], k)
	mat.sky_horizon_color = (a["horizonte"] as Color).lerp(b["horizonte"], k)
	mat.ground_horizon_color = (a["chao_h"] as Color).lerp(b["chao_h"], k)
	mat.ground_bottom_color = (a["chao_b"] as Color).lerp(b["chao_b"], k)
	env.ambient_light_color = (a["amb"] as Color).lerp(b["amb"], k)
	env.ambient_light_energy = lerpf(float(a["amb_e"]), float(b["amb_e"]), k)
	env.fog_light_color = (a["nevoa"] as Color).lerp(b["nevoa"], k)
	sol_luz.light_color = (a["sol_cor"] as Color).lerp(b["sol_cor"], k)
	sol_luz.light_energy = lerpf(float(a["sol_e"]), float(b["sol_e"]), k)
	var dir := ((a["sol"] as Vector3).lerp(b["sol"], k)).normalized()
	sol_luz.transform = Transform3D(Basis.looking_at(-dir, Vector3.UP), Vector3.ZERO)
	_agua_mat.set_shader_parameter("cor_ceu", Color(1.0, 0.55, 0.3).lerp(Color(0.12, 0.16, 0.34), k))
	_agua_mat.set_shader_parameter("cor_sol", Color(1.0, 0.8, 0.5).lerp(Color(0.4, 0.5, 0.8), k))
	for l in _luzes:
		l.light_energy = lerpf(0.15, 1.3, k / DUSK_MAX)
