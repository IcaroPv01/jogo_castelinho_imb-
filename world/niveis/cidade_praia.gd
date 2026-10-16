extends CidadeBase
## LUGAR DA CIDADE: Praia de Imbé (Módulo 14). Noite de ressaca: faixa de areia larga, mar com ondas (shader), a água que avança
## e recua sobre a areia molhada (zona segura: sem afogamento, sem morte), duna baixa com capim ao vento, luzes do calçadão e da
## cidade ao longe, restos de madeira, uma bóia, uma rede de pesca abandonada e o casco antigo de um barco, encalhado e quase
## enterrado (uma lembrança discreta dos naufrágios da costa gaúcha; a placa cita só o que está em `docs/pesquisa/historia_imbe.md` §7.1).
##
## TAREFA (1 pista, `praia_balde`): a maré deixou 4 objetos de criança espalhados pela areia (chinelo, bolinha, pazinha, balde).
## Em qualquer ordem. Um sino toca ao longe e soa do lado do próximo objeto; pegadinhas pálidas na areia ligam um ao outro; se o
## jogador demora, a Tainá/o Bentinho dão dicas. O balde vermelho tem um T riscado de cabeça para baixo (o mesmo que o Tito faz).
## Com os 4 achados vem a pista; o portão de volta passa a CONCLUIR o lugar (grava `cidade_praia_feito`). Sair antes pelo portão
## não conclui e o progresso fica salvo (flags `praia_achou_<objeto>`). Peso por sugestão: nada de corpo, o Tito não aparece.
## Tabela: `GameState.CIDADE["praia"]`. Teste: `tests/cidade_praia_test.gd`.
## Custo web: ~35 chamadas de desenho (malhas combinadas, MultiMesh, 2 sombreadores baratos), 4 luzes (Sol + 3 postes), sem sombras.

const SOM_SINO: AudioStream = preload("res://assets/audio/pista.wav")      # (sem áudio novo) grave e devagar vira o "sino" de longe
const PITCH_SINO := 0.5

const Z_COSTA := -25.0           # onde a água começa (a AREA termina um pouco antes, em -24)
const NIVEL_MAR := -0.08
const SWASH_Z_MIN := -25.0       # até onde a água recua
const SWASH_Z_MAX := -15.5       # até onde ela avança sobre a areia
const PERIODO_MARE := 10.0
const DUNA_Z0 := 5.0
const DUNA_Z1 := 12.5
const DUNA_VAO_X := 1.5          # centro do vão sem duna (por onde passa a trilha)
const X_LONGE := 220.0           # as faixas visuais (sem colisão) vão até aqui; a névoa esconde o resto

const DICA_PRIMEIRA := 60.0      # s sem achar nada até a primeira dica (depois, uma a cada 60 s)
const DICA_INTERVALO := 60.0

## Os 4 achados, na ordem da trilha de pegadas (qualquer ordem vale para o jogador).
const OBJETOS := [
	{"id": "chinelo", "nome": "o chinelo", "olhar": "Olhar o chinelo", "pos": Vector3(-7.0, 0.0, 2.5),
		"onde": "perto das dunas, à esquerda do portão",
		"legenda": "(um chinelinho de criança, cor-de-rosa, cheio de areia molhada. só um pé.)",
		"dica": ["bentinho", "Pelas dunas! Tem uma coisinha cor-de-rosa na areia, perto das dunas, à esquerda do portão."]},
	{"id": "bola", "nome": "a bolinha", "olhar": "Olhar a bolinha", "pos": Vector3(-17.0, 0.0, -6.0),
		"onde": "à esquerda, perto da madeira velha do barco",
		"legenda": "(uma bolinha de praia listrada. murcha de um lado. a maré a trouxe até aqui.)",
		"dica": ["taina", "Eu vi uma bolinha listrada rolando, lá pra esquerda, perto do barco velho. Eu ficaria longe do mastro, mas é você quem sabe."]},
	{"id": "pazinha", "nome": "a pazinha", "olhar": "Olhar a pazinha", "pos": Vector3(-5.0, 0.0, -12.5),
		"onde": "no meio da praia, onde a areia começa a escurecer",
		"legenda": "(uma pazinha amarela. o cabo está liso de tanto ser segurado.)",
		"dica": ["bentinho", "Atenção, visitante! No meio da praia, onde a areia fica mais escura, tem algo amarelinho."]},
	{"id": "balde", "nome": "o balde", "olhar": "Olhar o balde", "pos": Vector3(9.0, 0.0, -17.5),
		"onde": "bem perto da água, onde a espuma chega",
		"legenda": "(um balde vermelho. na lateral, riscado com o dedo: um T. de cabeça para baixo.)",
		"dica": ["taina", "Lá perto da água, onde a espuma chega... tem uma cor que eu conheço. Vermelho."]},
]

## A trilha de pegadas pequenas (começa perto do portão, passa pelos 4 achados e entra no mar).
const TRILHA := [Vector3(3.3, 0.0, 12.0), Vector3(1.0, 0.0, 8.0), Vector3(-2.5, 0.0, 5.0), Vector3(-7.0, 0.0, 2.5),
	Vector3(-11.0, 0.0, -1.0), Vector3(-14.5, 0.0, -3.0), Vector3(-17.0, 0.0, -6.0), Vector3(-14.0, 0.0, -9.5),
	Vector3(-9.0, 0.0, -11.0), Vector3(-5.0, 0.0, -12.5), Vector3(0.0, 0.0, -14.0), Vector3(4.5, 0.0, -16.0),
	Vector3(9.0, 0.0, -17.5), Vector3(10.5, 0.0, -20.0), Vector3(11.5, 0.0, -23.0)]

const FALA_TAINA := [
	"Um chinelo. Uma bolinha. Uma pazinha. E este balde.",
	"Tem um T riscado na lateral, com o dedo. De cabeça para baixo.",
	"Igualzinho ao do fundo do lago.",
	"O mar sempre traz de volta o que a gente deixa para trás. ...Quase sempre.",
]
const FALA_BENTINHO := [
	"Atenção, visitante! Achados e perdidos devem ser entregues à prefeitura!",
	"...Não entregue. Deixe onde está. É dele.",
	"Vamos voltar pelo portão? A visita continua!",
]
const TEXTO_PLACA := [
	"PROGRAMA MUNICIPAL DE MEMÓRIA INTERATIVA",
	"Painel da Praia",
	"A costa gaúcha é chamada de \"Cemitério dos Navegantes\": há registro de pelo menos 10 naufrágios entre Torres e Cidreira até 1963.",
	"Em Tramandaí, vizinha de Imbé, a Marinha registra o Minuano (1836) e o Meteoro (1902).",
	"Achados e perdidos: o mar devolve tudo. Só demora.",
]

const SHADER_MAR := """
shader_type spatial;
render_mode specular_disabled;
// Mar de ressaca à noite. Marulho que anda para a praia (+z) com período fixo, duas ondas cruzadas, brilho da lua,
// espuma nas cristas e linhas de arrebentação junto da areia. Sem refração nem transparência (Compatibility/WebGL2).
uniform vec3 cor_fundo : source_color = vec3(0.012, 0.03, 0.05);
uniform vec3 cor_ceu : source_color = vec3(0.07, 0.1, 0.17);
uniform vec3 cor_espuma : source_color = vec3(0.62, 0.7, 0.74);
uniform vec3 dir_lua = vec3(0.3, 0.8, -0.5);
uniform float periodo = 10.0;
uniform float comprimento = 32.0;
uniform float amplitude = 0.2;
uniform float costa_z = -25.0;
varying vec3 pos_mundo;
varying float alt;

vec3 ondas(vec2 p, float t) {
	float w = 6.28318 / periodo;
	float k = 6.28318 / comprimento;
	float f0 = k * p.y - w * t;
	float h = sin(f0) + 0.35 * sin(2.0 * f0 - 1.0);
	float dz = k * cos(f0) + 0.7 * k * cos(2.0 * f0 - 1.0);
	float dx = 0.0;
	vec2 d1 = normalize(vec2(0.45, 0.9));
	float k1 = 6.28318 / 11.0;
	float f1 = dot(p, d1) * k1 - 1.5 * t;
	h += 0.45 * sin(f1);
	dx += 0.45 * k1 * d1.x * cos(f1);
	dz += 0.45 * k1 * d1.y * cos(f1);
	vec2 d2 = normalize(vec2(-0.6, 0.8));
	float k2 = 6.28318 / 5.3;
	float f2 = dot(p, d2) * k2 - 2.2 * t;
	h += 0.2 * sin(f2);
	dx += 0.2 * k2 * d2.x * cos(f2);
	dz += 0.2 * k2 * d2.y * cos(f2);
	return vec3(h, dx, dz) * amplitude;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 o = ondas(w.xz, TIME);
	VERTEX.y += o.x;
	NORMAL = normalize(vec3(-o.y, 1.0, -o.z));
	pos_mundo = w;
	alt = o.x / amplitude;
}

void fragment() {
	vec3 n = normalize(NORMAL);
	vec3 v = normalize(VIEW);
	float f = pow(1.0 - clamp(dot(n, v), 0.0, 1.0), 3.0);
	vec3 cor = mix(cor_fundo, cor_ceu, clamp(f * 0.9 + 0.05, 0.0, 1.0));
	vec3 ls = normalize((VIEW_MATRIX * vec4(normalize(dir_lua), 0.0)).xyz);
	float brilho = pow(max(dot(reflect(-ls, n), v), 0.0), 40.0);
	cor += vec3(0.55, 0.65, 0.85) * brilho * 1.3;
	// espuma nas cristas (rendada)
	float renda = 0.5 + 0.5 * sin(pos_mundo.x * 1.9 + sin(pos_mundo.z * 0.8) * 2.0 + TIME * 0.7) * sin(pos_mundo.z * 2.3 - pos_mundo.x * 0.6);
	float crista = smoothstep(1.05, 1.55, alt) * (0.35 + 0.65 * renda);
	// linhas de arrebentação junto da costa
	float d = costa_z - pos_mundo.z;
	float linha = smoothstep(0.62, 0.95, sin(d * 1.1 - TIME * 1.15 + sin(pos_mundo.x * 0.45) * 1.6));
	float perto = 1.0 - smoothstep(0.0, 12.0, d);
	float espuma = clamp(crista * 0.8 + linha * perto * 0.75, 0.0, 1.0);
	cor = mix(cor, cor_espuma, espuma);
	ALBEDO = cor;
	EMISSION = cor * 0.45;
	ROUGHNESS = 0.35;
}
"""

const SHADER_ESPRAIADO := """
shader_type spatial;
render_mode blend_mix, unshaded, depth_draw_never, cull_disabled;
// A água que sobe na areia e volta (período fixo, avanço rápido e recuo lento), com a franja de espuma na ponta e a areia
// molhada que fica escura. É só um lençol pintado sobre o chão: não tem volume, não empurra nem afoga ninguém.
uniform float periodo = 10.0;
uniform float z_min = -25.0;
uniform float z_max = -15.5;
uniform vec3 cor_molhada : source_color = vec3(0.02, 0.035, 0.06);
uniform vec3 cor_espuma : source_color = vec3(0.5, 0.56, 0.6);
varying vec3 p;

float avanco(float u) {
	return smoothstep(0.0, 0.2, u) * (1.0 - smoothstep(0.2, 1.0, u));
}

void vertex() {
	p = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float u = fract(TIME / periodo);
	float e = mix(z_min, z_max, avanco(u)) + 0.5 * sin(p.x * 0.4 + TIME * 0.6) + 0.25 * sin(p.x * 1.3 - TIME * 0.9);
	float d = e - p.z;                         // > 0: o lençol cobre este ponto
	float molhada = smoothstep(-13.0, -20.0, p.z) * 0.26;
	float lenco = smoothstep(0.0, 0.3, d) * 0.36;
	float borda = (1.0 - smoothstep(0.0, 0.55, d)) * smoothstep(-0.1, 0.05, d);
	float renda = 0.5 + 0.5 * sin(p.x * 3.1 + sin(p.z * 5.0) * 2.0 + TIME);
	float rastro = smoothstep(0.7, 1.0, sin(p.x * 2.3 + d * 4.0) * sin(p.z * 3.1 - p.x)) * (1.0 - smoothstep(0.3, 2.4, d)) * step(0.0, d) * 0.5;
	float espuma = clamp(borda * (0.5 + 0.5 * renda) + rastro, 0.0, 1.0);
	float a = clamp(molhada + lenco * (1.0 - molhada), 0.0, 1.0);
	ALBEDO = mix(cor_molhada, cor_espuma, espuma);
	ALPHA = clamp(a + espuma * 0.8, 0.0, 1.0);
}
"""

const SHADER_CAPIM := """
shader_type spatial;
render_mode cull_disabled, specular_disabled;
// Capim rasteiro das dunas: balança com o vento (mais na ponta que na raiz).
uniform float vento = 0.12;
void vertex() {
	float h = max(VERTEX.y, 0.0);
	vec3 o = MODEL_MATRIX[3].xyz;
	float s = sin(TIME * 1.7 + o.x * 0.6 + o.z * 0.35) + 0.5 * sin(TIME * 3.1 + o.x * 1.7);
	VERTEX.x += s * vento * h * h * 4.0;
	VERTEX.z += s * vento * h * h * 2.0;
}
void fragment() {
	ALBEDO = COLOR.rgb;
	ROUGHNESS = 1.0;
}
"""

# --- estado da tarefa
## Espera (s) entre o 4º achado e a pista (a legenda do balde precisa ser lida). Os testes zeram.
var atraso_final := 2.6
var _objs: Array[Dictionary] = []                # {def, no, it, achado}
var _achados := 0
var _pronto := false                              # os 4 achados e a pista dada: o portão agora conclui
var _tempo := 0.0
var _ocioso := 0.0                                # s sem achar nada
var _proxima_dica := DICA_PRIMEIRA
var _n_dicas := 0
var dicas_dadas := 0
var _t_sino := 4.0
var _t_sino2 := -1.0
var _sino: AudioStreamPlayer3D
var _brilhos: MultiMeshInstance3D
var _feixes: MultiMeshInstance3D
var _legenda: Label
var _tween_legenda: Tween
var _mat_mar: ShaderMaterial
var _ruido_duna: FastNoiseLite


func _configurar() -> void:
	id = "praia"
	area = Rect2(-40.0, -24.0, 80.0, 44.0)       # o mar é o limite do norte: a borda de colisão fica 0,5 m depois da AREA, antes da água funda
	hora = Hora.NOITE
	clima = Clima.RESSACA
	spawn_pos = Vector3(0.0, 0.1, 15.0)
	spawn_yaw = 0.0
	ambiente_audio = "mar"
	_ruido_duna = FastNoiseLite.new()
	_ruido_duna.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_ruido_duna.seed = 1939
	_ruido_duna.frequency = 0.07


func _material_chao() -> Material:
	return mat_areia(0.8)


# ============================================================================ cenário
func _construir() -> void:
	env.ambient_light_energy = maxf(env.ambient_light_energy, 1.05)      # o mar de ressaca é escuro, a areia precisa ser lida
	_areia_e_ruas()
	_dunas()
	_mar()
	_espraiado()
	_cidade_ao_longe()
	_pecas_fixas()
	_capim()
	_pegadas()
	_objetos_visuais()


func _areia_e_ruas() -> void:
	# areia além da AREA (sem colisão): a praia segue para os lados até a névoa
	Construtor.caixa(self, Vector3(2.0 * X_LONGE, 0.2, 48.0), Vector3(0, -0.12, -2.0), mat_areia(0.8), false, "AreiaLonge")
	# a rampa onde a areia desce para dentro do mar (visual)
	var rampa := Construtor.caixa(self, Vector3(2.0 * X_LONGE, 0.2, 5.2), Vector3(0, -0.5, Z_COSTA - 3.2), mat_areia(0.3), false, "RampaDoMar")
	rampa.rotation_degrees.x = -10.2
	# calçadão e a mureta de pedra entre ele e a duna
	Construtor.caixa(self, Vector3(2.0 * X_LONGE, 0.03, 9.0), Vector3(0, 0.005, 17.5), mat_calcada(), false, "Calcadao")
	Construtor.caixa(self, Vector3(2.0 * X_LONGE, 0.07, 0.3), Vector3(0, 0.035, 13.0), Ato2Pecas.mat_cor(Color(0.55, 0.54, 0.52)), false, "Meio_fio")
	# a avenida atrás do calçadão
	Construtor.caixa(self, Vector3(2.0 * X_LONGE, 0.1, 8.0), Vector3(0, -0.07, 26.0), mat_asfalto(), false, "Avenida")


func _altura_duna(x: float, z: float) -> float:
	if z <= DUNA_Z0 or z >= DUNA_Z1:
		return -0.02
	var u := (z - DUNA_Z0) / (DUNA_Z1 - DUNA_Z0)
	var banda: float = sin(u * PI)
	banda *= banda
	var r: float = 0.5 + 0.5 * _ruido_duna.get_noise_2d(x, z * 0.6)
	var vao: float = smoothstep(3.0, 9.0, absf(x - DUNA_VAO_X))
	return banda * (0.15 + 0.6 * r) * vao - 0.02


func _dunas() -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var x0 := -120.0
	var nx := 241
	var nz := 11
	var dz := (DUNA_Z1 - DUNA_Z0) / float(nz - 1)
	for j in nz:
		for i in nx:
			var x := x0 + float(i)
			var z := DUNA_Z0 + float(j) * dz
			st.add_vertex(Vector3(x, _altura_duna(x, z), z))
	for j in nz - 1:
		for i in nx - 1:
			var a := j * nx + i
			var b := a + 1
			var c := a + nx
			var d := c + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(c)
			st.add_index(b)
			st.add_index(d)
			st.add_index(c)
	st.generate_normals()
	var malha := st.commit()
	Ato2Pecas.com_colisao_trimesh(self, malha, mat_areia(0.68)).name = "Dunas"


func _mar() -> void:
	var sh := Shader.new()
	sh.code = SHADER_MAR
	_mat_mar = ShaderMaterial.new()
	_mat_mar.shader = sh
	_mat_mar.set_shader_parameter("dir_lua", (CEUS[Hora.NOITE]["sol"] as Vector3).normalized())
	_mat_mar.set_shader_parameter("periodo", PERIODO_MARE)
	_mat_mar.set_shader_parameter("costa_z", Z_COSTA)
	var perto := PlaneMesh.new()
	perto.size = Vector2(260.0, 62.0)
	perto.subdivide_width = 130
	perto.subdivide_depth = 62
	Ato2Pecas.malha(self, perto, Vector3(0, NIVEL_MAR, Z_COSTA - 31.0), _mat_mar).name = "MarPerto"
	var longe := PlaneMesh.new()
	longe.size = Vector2(1600.0, 700.0)
	longe.subdivide_width = 16
	longe.subdivide_depth = 10
	Ato2Pecas.malha(self, longe, Vector3(0, NIVEL_MAR, Z_COSTA - 62.0 - 350.0), _mat_mar).name = "MarLonge"


## O lençol de água que sobe na areia molhada e volta (só visual).
func _espraiado() -> void:
	var sh := Shader.new()
	sh.code = SHADER_ESPRAIADO
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("periodo", PERIODO_MARE)
	m.set_shader_parameter("z_min", SWASH_Z_MIN)
	m.set_shader_parameter("z_max", SWASH_Z_MAX)
	m.render_priority = 0
	var plano := PlaneMesh.new()
	plano.size = Vector2(2.0 * X_LONGE, 14.0)
	Ato2Pecas.malha(self, plano, Vector3(0, 0.014, -19.0), m).name = "Espraiado"


# ---------------------------------------------------------------------------- a cidade, ao longe
func _cidade_ao_longe() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1988
	var predios: Array[Dictionary] = []
	var x := -150.0
	while x < 150.0:
		var larg := rng.randf_range(10.0, 20.0)
		var alt := rng.randf_range(14.0, 42.0)
		var prof := rng.randf_range(9.0, 14.0)
		var z := 52.0 + rng.randf_range(0.0, 22.0)
		predios.append({"x": x + larg * 0.5, "z": z, "l": larg, "a": alt, "p": prof})
		x += larg + rng.randf_range(2.0, 9.0)
	# prédios: um BoxMesh unitário, uma chamada de desenho
	var caixa := BoxMesh.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = caixa
	mm.instance_count = predios.size()
	for i in predios.size():
		var p: Dictionary = predios[i]
		var b := Basis.IDENTITY.scaled(Vector3(p["l"], p["a"], p["p"]))
		mm.set_instance_transform(i, Transform3D(b, Vector3(p["x"], float(p["a"]) * 0.5, p["z"])))
		var tom := rng.randf_range(0.8, 1.2)
		mm.set_instance_color(i, Color(0.06 * tom, 0.07 * tom, 0.1 * tom))
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	mmi.material_override = mat
	mmi.name = "Predios"
	add_child(mmi)
	# janelas acesas (a face que olha para a praia, -z)
	var jan: Array[Transform3D] = []
	var cores: Array[Color] = []
	for p: Dictionary in predios:
		var cols := int(float(p["l"]) / 2.6)
		var linhas := int(float(p["a"]) / 3.4)
		for c in cols:
			for l in linhas:
				if rng.randf() > 0.36:
					continue
				var jx: float = float(p["x"]) - float(p["l"]) * 0.5 + (float(c) + 0.5) * float(p["l"]) / float(cols)
				var jy := 2.0 + float(l) * 3.4
				var jz: float = float(p["z"]) - float(p["p"]) * 0.5 - 0.03
				jan.append(Transform3D(Basis(Vector3.UP, PI), Vector3(jx, jy, jz)))
				cores.append(Color(1.0, 0.82, 0.5) if rng.randf() < 0.8 else Color(0.7, 0.85, 1.0))
	var qm := MultiMesh.new()
	qm.transform_format = MultiMesh.TRANSFORM_3D
	qm.use_colors = true
	var quad := QuadMesh.new()
	quad.size = Vector2(1.3, 1.8)
	qm.mesh = quad
	qm.instance_count = jan.size()
	for i in jan.size():
		qm.set_instance_transform(i, jan[i])
		qm.set_instance_color(i, cores[i])
	var mj := StandardMaterial3D.new()
	mj.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mj.vertex_color_use_as_albedo = true
	mj.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mji := MultiMeshInstance3D.new()
	mji.multimesh = qm
	mji.material_override = mj
	mji.name = "Janelas"
	add_child(mji)


# ---------------------------------------------------------------------------- peças fixas (uma malha só, cores nos vértices)
func _pecas_fixas() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1902
	var c := Cola.new()
	var madeira := Color(0.34, 0.26, 0.19)
	var madeira_velha := Color(0.4, 0.36, 0.3)
	var ferro := Color(0.2, 0.21, 0.23)
	# postes do calçadão (cabeças acesas à parte)
	var cabecas: Array[Vector3] = []
	for px: float in [-30.0, -15.0, 4.5, 22.0, 36.0]:
		c.cilindro(Transform3D(Basis.IDENTITY, Vector3(px, 0.0, 18.5)), 0.09, 0.06, 5.0, ferro, 6)
		c.caixa(Transform3D(Basis.IDENTITY, Vector3(px - 0.4, 5.0, 18.5)), Vector3(0.9, 0.08, 0.1), ferro)
		cabecas.append(Vector3(px - 0.8, 4.92, 18.5))
	_lampadas(cabecas)
	for lx: float in [-15.0, 4.5, 22.0]:
		Construtor.luz(self, Vector3(lx - 0.8, 4.5, 18.0), Color(1.0, 0.82, 0.5), 1.1, 11.0).name = "LuzPoste"
	# bancos do calçadão
	for bx: float in [-23.0, 12.0, 29.0]:
		c.caixa(Transform3D(Basis.IDENTITY, Vector3(bx, 0.48, 14.6)), Vector3(1.8, 0.06, 0.45), madeira)
		c.caixa(Transform3D(Basis.IDENTITY, Vector3(bx, 0.78, 14.4)), Vector3(1.8, 0.34, 0.05), madeira)
		c.caixa(Transform3D(Basis.IDENTITY, Vector3(bx - 0.8, 0.22, 14.6)), Vector3(0.08, 0.44, 0.4), ferro)
		c.caixa(Transform3D(Basis.IDENTITY, Vector3(bx + 0.8, 0.22, 14.6)), Vector3(0.08, 0.44, 0.4), ferro)
	# a placa do painel da prefeitura (fictícia)
	var placa_pos := Vector3(-4.2, 0.0, 12.7)
	c.cilindro(Transform3D(Basis.IDENTITY, placa_pos + Vector3(-0.85, 0.0, -0.13)), 0.07, 0.07, 1.9, madeira, 6)
	c.cilindro(Transform3D(Basis.IDENTITY, placa_pos + Vector3(0.85, 0.0, -0.13)), 0.07, 0.07, 1.9, madeira, 6)
	c.caixa(Transform3D(Basis.IDENTITY, placa_pos + Vector3(0.0, 1.45, 0.0)), Vector3(2.1, 1.3, 0.08), Color(0.1, 0.2, 0.42))
	c.caixa(Transform3D(Basis.IDENTITY, placa_pos + Vector3(0.0, 1.45, 0.045)), Vector3(1.96, 1.16, 0.02), Color(0.9, 0.9, 0.84))
	_texto_da_placa(placa_pos + Vector3(0.0, 1.45, 0.06))
	# o casco antigo, encalhado e quase enterrado (referência discreta aos naufrágios da costa)
	_casco(c, rng, Vector3(-26.0, 0.0, -8.0))
	# bóia meio enterrada
	var tf_boia := Transform3D(Basis(Vector3.FORWARD, deg_to_rad(16.0)) * Basis(Vector3.RIGHT, deg_to_rad(-10.0)), Vector3(17.0, 0.06, -3.0))
	c.toro(tf_boia, 0.4, 0.1, [Color(0.82, 0.12, 0.1), Color(0.82, 0.12, 0.1), Color(0.88, 0.88, 0.84), Color(0.88, 0.88, 0.84)], 16, 6)
	# restos de madeira (toras e tábuas) longe da trilha
	var feitos := 0
	var tentativas := 0
	while feitos < 12 and tentativas < 200:
		tentativas += 1
		var p := Vector3(rng.randf_range(-38.0, 38.0), 0.0, rng.randf_range(-22.0, 3.5))
		if _perto_da_trilha(p, 2.2) or _perto_de_objeto(p, 2.5) or (p.x < -20.0 and p.x > -34.0 and p.z < -3.0 and p.z > -13.0):
			continue
		feitos += 1
		var yaw := rng.randf_range(0.0, TAU)
		var comp := rng.randf_range(0.8, 2.6)
		if rng.randf() < 0.55:
			var r := rng.randf_range(0.04, 0.1)
			var tf := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, deg_to_rad(90.0 + rng.randf_range(-4.0, 4.0))), p + Vector3(0, r * 0.6, 0))
			c.cilindro(tf, r, r * 0.85, comp, madeira_velha, 6)
		else:
			var tf2 := Transform3D(Basis(Vector3.UP, yaw) * Basis(Vector3.FORWARD, deg_to_rad(rng.randf_range(-8.0, 8.0))), p + Vector3(0, 0.05, 0))
			c.caixa(tf2, Vector3(comp, 0.06, rng.randf_range(0.14, 0.26)), madeira)
	# a rede de pesca abandonada, esticada entre três estacas
	_rede(c, rng, Vector3(18.0, 0.0, -9.0))
	var inst := MeshInstance3D.new()
	inst.mesh = c.malha()
	inst.material_override = _mat_vertice()
	inst.name = "Pecas"
	add_child(inst)


static func _mat_vertice() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.95
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m


func _lampadas(pos: Array[Vector3]) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := BoxMesh.new()
	q.size = Vector3(0.45, 0.1, 0.22)
	mm.mesh = q
	mm.instance_count = pos.size()
	for i in pos.size():
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, pos[i]))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = Ato2Pecas.mat_cor(Color(1.0, 0.86, 0.55), true, 1.0)
	mi.name = "Lampadas"
	add_child(mi)


## Placa do painel: o texto vai na frente e o jogador lê com E (a Guia fala as linhas).
func _texto_da_placa(pos: Vector3) -> void:
	var r := Construtor.rotulo(self, "\n".join(PackedStringArray([TEXTO_PLACA[0], "", TEXTO_PLACA[2]])), pos, 22, Color(0.1, 0.1, 0.12))
	r.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	r.width = 470.0
	r.double_sided = true
	r.name = "TextoPlaca"
	r.position.y += 0.02
	var it := interagivel("Ler a placa", pos + Vector3(0.0, -0.1, 0.5), Vector3(2.4, 1.6, 1.4), func(_p: Node) -> void: _ler_placa())
	it.name = "PlacaPraia"


func _ler_placa() -> void:
	Guia.falar("sistema", [TEXTO_PLACA[0] + " · " + TEXTO_PLACA[1], TEXTO_PLACA[2], TEXTO_PLACA[3], TEXTO_PLACA[4]])


func _casco(c: Cola, rng: RandomNumberGenerator, pos: Vector3) -> void:
	var tf := Transform3D(Basis(Vector3.UP, deg_to_rad(-22.0)) * Basis(Vector3.FORWARD, deg_to_rad(5.0)) * Basis(Vector3.RIGHT, deg_to_rad(-3.0)), pos)
	var tabua := Color(0.5, 0.45, 0.38)         # madeira velha, cinza de sal
	var verde := Color(0.34, 0.4, 0.36)         # limo do mar
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.05, 0)), Vector3(9.4, 0.4, 0.5), tabua)
	var costelas: Array = []
	for i in 9:
		var x := -4.0 + float(i)
		var u := x / 4.7
		var sc := sqrt(maxf(1.0 - u * u, 0.0))
		var rx := 1.75 * sc
		var ry := 3.4 * sc * (1.0 + 0.25 * u)
		var lados: Array = []
		for s: float in [-1.0, 1.0]:
			var tmax := rng.randf_range(0.85, 1.3)
			var pts: Array[Vector3] = []
			for k in 6:
				var th := tmax * float(k) / 5.0
				pts.append(Vector3(x, ry * (1.0 - cos(th)) - 0.15, s * rx * sin(th)))
			for k in 5:
				var cor := tabua if k < 3 else verde
				c.entre(tf * pts[k], tf * pts[k + 1], 0.12 - 0.01 * float(k), 0.12 - 0.01 * float(k + 1), cor, 5)
			lados.append(pts)
		costelas.append(lados)
	# tábuas que sobraram entre as costelas (nem todas)
	for i in 8:
		for s in 2:
			for k in [2, 4]:
				if rng.randf() < 0.55:
					continue
				var pa: Vector3 = (costelas[i][s] as Array)[k] if k < (costelas[i][s] as Array).size() else Vector3.INF
				var pb: Vector3 = (costelas[i + 1][s] as Array)[k] if k < (costelas[i + 1][s] as Array).size() else Vector3.INF
				if pa == Vector3.INF or pb == Vector3.INF:
					continue
				c.entre(tf * pa, tf * pb, 0.09, 0.09, tabua, 5)
	# roda de proa e cadaste
	c.entre(tf * Vector3(4.4, -0.1, 0), tf * Vector3(5.3, 1.9, 0), 0.11, 0.08, tabua, 5)
	c.entre(tf * Vector3(-4.4, -0.1, 0), tf * Vector3(-4.8, 1.1, 0), 0.11, 0.08, tabua, 5)
	# o mastro quebrado, inclinado, com uma verga atravessada
	var base := Vector3(1.0, 0.2, 0.0)
	var topo := base + Vector3(-1.5, 4.7, 0.5)
	c.entre(tf * base, tf * topo, 0.2, 0.11, tabua, 6)
	var verga_c := base.lerp(topo, 0.72)
	c.entre(tf * (verga_c + Vector3(0.3, -0.35, -1.6)), tf * (verga_c + Vector3(-0.3, 0.35, 1.6)), 0.06, 0.06, tabua, 5)
	# um pedaço de corda pendurada
	c.entre(tf * (verga_c + Vector3(0.0, 0.0, 1.5)), tf * (verga_c + Vector3(0.05, -1.4, 1.55)), 0.015, 0.015, Color(0.5, 0.45, 0.35), 4)
	# colisão grossa só do casco (o jogador não entra no esqueleto); o mastro fica alto demais para atrapalhar
	var col := Ato2Pecas.colisao_invisivel(self, Vector3(9.4, 1.5, 3.2), pos + Vector3(0, 0.7, 0))
	col.rotation_degrees.y = -22.0
	col.name = "ColisaoCasco"


func _rede(c: Cola, rng: RandomNumberGenerator, pos: Vector3) -> void:
	var madeira := Color(0.36, 0.28, 0.2)
	var a_topo := pos + Vector3(-2.0, 1.3, -0.6)
	var b_topo := pos + Vector3(2.2, 0.8, 0.1)
	var m_topo := pos + Vector3(0.2, 1.0, -0.2)
	for t: Vector3 in [a_topo, b_topo, m_topo]:
		c.entre(Vector3(t.x, -0.2, t.z), t, 0.06, 0.05, madeira, 5)
	# boias de cortiça na corda de cima
	for i in 9:
		var s := float(i) / 8.0
		var p := a_topo.lerp(b_topo, s) + Vector3(0, -0.12 * sin(s * PI), 0)
		c.elipsoide(Transform3D(Basis.IDENTITY, p), Vector3(0.07, 0.05, 0.05), Color(0.85, 0.5, 0.18), 6, 3)
	# o pano de rede: pende da corda e se arrasta pela areia (textura de malha com recorte)
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var nx := 12
	var nt := 7
	var grade: Array = []
	for j in nt + 1:
		var linha: Array[Vector3] = []
		for i in nx + 1:
			var s := float(i) / float(nx)
			var topo := a_topo.lerp(b_topo, s) + Vector3(0, -0.15 * sin(s * PI), 0)
			var chao := pos + Vector3(-2.4 + 5.0 * s, 0.03, 0.9)
			var t := float(j) / float(nt)
			var q := topo.lerp(chao, minf(t * 1.4, 1.0))
			if t > 0.7:        # o resto se arrasta pela areia
				q = chao + Vector3(0.0, 0.0, (t - 0.7) * 5.0)
				q.y = 0.03 + 0.07 * absf(sin(s * 9.0 + t * 7.0))
			q += Vector3(rng.randf_range(-0.04, 0.04), 0.0, rng.randf_range(-0.04, 0.04))
			linha.append(q)
		grade.append(linha)
	for j in nt + 1:
		for i in nx + 1:
			st.set_uv(Vector2(float(i) * 0.9, float(j) * 0.9))
			st.add_vertex((grade[j] as Array)[i])
	for j in nt:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var cc := a + nx + 1
			var d := cc + 1
			st.add_index(a)
			st.add_index(b)
			st.add_index(cc)
			st.add_index(b)
			st.add_index(d)
			st.add_index(cc)
	st.generate_normals()
	var mi := MeshInstance3D.new()
	mi.mesh = st.commit()
	mi.material_override = _mat_rede()
	mi.name = "RedeDePesca"
	add_child(mi)


func _mat_rede() -> StandardMaterial3D:
	const N := 64
	var img := Image.create(N, N, false, Image.FORMAT_RGBA8)
	for y in N:
		for x in N:
			var a := 0.0
			if (x + y) % 16 <= 1 or (x - y + N) % 16 <= 1:
				a = 1.0
			img.set_pixel(x, y, Color(0.6, 0.64, 0.56, a))
	img.generate_mipmaps()
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.5
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.roughness = 1.0
	m.emission_enabled = true
	m.emission = Color(0.1, 0.11, 0.1)
	return m


# ---------------------------------------------------------------------------- capim, pegadas e os 4 achados
func _capim() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# a touceira: 6 folhas finas inclinadas, mais claras na ponta
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 6:
		var ang := TAU * float(k) / 6.0 + rng.randf() * 0.4
		var dir := Vector3(cos(ang), 0, sin(ang))
		var lado := Vector3(-dir.z, 0, dir.x) * 0.025
		var alt := rng.randf_range(0.28, 0.46)
		var ponta := dir * rng.randf_range(0.08, 0.2) + Vector3(0, alt, 0)
		var cb := Color(0.11, 0.14, 0.07)
		var cp := Color(0.34, 0.37, 0.19)
		for v: Array in [[-lado + dir * 0.02, cb], [lado + dir * 0.02, cb], [ponta, cp]]:
			st.set_normal(Vector3.UP)
			st.set_color(v[1])
			st.add_vertex(v[0])
	var malha := st.commit()
	var posicoes: Array[Vector3] = []
	var tentativas := 0
	while posicoes.size() < 280 and tentativas < 2000:
		tentativas += 1
		var x := rng.randf_range(-70.0, 70.0)
		var z := rng.randf_range(DUNA_Z0 - 0.5, DUNA_Z1 + 0.3)
		var h := _altura_duna(x, z)
		if h < 0.07 and rng.randf() > 0.12:
			continue
		if absf(x - DUNA_VAO_X) < 2.2:
			continue
		posicoes.append(Vector3(x, h, z))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = malha
	mm.instance_count = posicoes.size()
	for i in posicoes.size():
		var esc := rng.randf_range(0.8, 1.7)
		var b := Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3(esc, esc, esc))
		mm.set_instance_transform(i, Transform3D(b, posicoes[i]))
	var sh := Shader.new()
	sh.code = SHADER_CAPIM
	var mat := ShaderMaterial.new()
	mat.shader = sh
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	mi.material_override = mat
	mi.name = "Capim"
	add_child(mi)


func _perto_da_trilha(p: Vector3, raio: float) -> bool:
	for i in TRILHA.size() - 1:
		var a: Vector3 = TRILHA[i]
		var b: Vector3 = TRILHA[i + 1]
		var ab := b - a
		var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
		if (a + ab * t).distance_to(Vector3(p.x, 0.0, p.z)) < raio:
			return true
	return false


func _perto_de_objeto(p: Vector3, raio: float) -> bool:
	for o: Dictionary in OBJETOS:
		if (o["pos"] as Vector3).distance_to(Vector3(p.x, 0.0, p.z)) < raio:
			return true
	return false


## Pegadas pequenas, pálidas (giz na areia): dois MultiMesh (pé esquerdo e direito); as últimas somem no mar.
func _pegadas() -> void:
	var esq: Array[Transform3D] = []
	var dir_: Array[Transform3D] = []
	var alfa_e: Array[float] = []
	var alfa_d: Array[float] = []
	var total := 0.0
	for i in TRILHA.size() - 1:
		total += (TRILHA[i + 1] as Vector3).distance_to(TRILHA[i])
	var andado := 0.0
	var lado := 1.0
	for i in TRILHA.size() - 1:
		var a: Vector3 = TRILHA[i]
		var b: Vector3 = TRILHA[i + 1]
		var seg := b - a
		var comp := seg.length()
		var d := seg / comp
		var perp := Vector3(-d.z, 0.0, d.x)
		var s := 0.0
		while s < comp:
			var p := a + d * s + perp * 0.1 * lado
			p.y = maxf(0.025, _altura_duna(p.x, p.z) + 0.012)
			var frac := (andado + s) / total
			var alfa := 1.0 if frac < 0.82 else lerpf(1.0, 0.1, (frac - 0.82) / 0.18)
			var rot := Basis(Vector3.UP, atan2(-d.x, -d.z)).scaled(Vector3.ONE * 0.62)
			if lado > 0.0:
				esq.append(Transform3D(rot, p))
				alfa_e.append(alfa)
			else:
				dir_.append(Transform3D(rot, p))
				alfa_d.append(alfa)
			lado = -lado
			s += 0.62
		andado += comp
	var plano := PlaneMesh.new()
	plano.size = Pegada.TAM_BASE
	for par in [[true, esq, alfa_e], [false, dir_, alfa_d]]:
		var lista: Array = par[1]
		var alfas: Array = par[2]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = plano
		mm.instance_count = lista.size()
		for i in lista.size():
			mm.set_instance_transform(i, lista[i])
			mm.set_instance_color(i, Color(0.9, 0.9, 0.82, 0.62 * float(alfas[i])))
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = Pegada.textura(par[0])
		mat.vertex_color_use_as_albedo = true
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.render_priority = 1
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = mat
		mi.name = "Pegadas_E" if par[0] else "Pegadas_D"
		add_child(mi)


func _mat_objeto() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.7
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.emission_enabled = true
	m.emission = Color(0.2, 0.2, 0.24)           # um fiapo de brilho: de noite os achados precisam ser lidos
	return m


## Os 4 objetos (um nó cada, na posição de OBJETOS) e o brilho que chama o olhar.
func _objetos_visuais() -> void:
	var mat := _mat_objeto()
	for def: Dictionary in OBJETOS:
		var c := Cola.new()
		match str(def["id"]):
			"chinelo":
				_m_chinelo(c)
			"bola":
				_m_bola(c)
			"pazinha":
				_m_pazinha(c)
			"balde":
				_m_balde(c)
		var no := Node3D.new()
		no.name = "Obj_" + str(def["id"])
		no.position = def["pos"]
		add_child(no)
		var mi := MeshInstance3D.new()
		mi.mesh = c.malha()
		mi.material_override = mat
		no.add_child(mi)
		_objs.append({"def": def, "no": no, "it": null, "achado": false})
	# brilhos (billboards aditivos), um por objeto
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	mm.mesh = q
	mm.instance_count = OBJETOS.size()
	var grad := GradientTexture2D.new()
	grad.fill = GradientTexture2D.FILL_RADIAL
	grad.fill_from = Vector2(0.5, 0.5)
	grad.fill_to = Vector2(1.0, 0.5)
	grad.width = 64
	grad.height = 64
	var g := Gradient.new()
	g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	g.offsets = PackedFloat32Array([0.0, 1.0])
	grad.gradient = g
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	bm.billboard_keep_scale = true
	bm.albedo_texture = grad
	bm.albedo_color = Color(0.7, 0.85, 1.0, 0.5)
	bm.no_depth_test = false
	bm.render_priority = 2
	_brilhos = MultiMeshInstance3D.new()
	_brilhos.multimesh = mm
	_brilhos.material_override = bm
	_brilhos.name = "Brilhos"
	add_child(_brilhos)
	_criar_feixes()
	_pulsar_brilhos()


## Coluna de luz fina e pálida em cada achado (aparece de longe, por cima da névoa): o olho vai atrás dela.
func _criar_feixes() -> void:
	var img := Image.create(32, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 32:
			var lado := 1.0 - absf(float(x) / 31.0 - 0.5) * 2.0
			var baixo := pow(float(y) / 63.0, 1.6)
			img.set_pixel(x, y, Color(1, 1, 1, clampf(lado * lado * baixo, 0.0, 1.0)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var q := QuadMesh.new()
	q.size = Vector2(1.0, 1.0)
	mm.mesh = q
	mm.instance_count = OBJETOS.size()
	var bm := StandardMaterial3D.new()
	bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	bm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	bm.billboard_keep_scale = true
	bm.albedo_texture = ImageTexture.create_from_image(img)
	bm.albedo_color = Color(0.6, 0.85, 1.0, 0.6)
	bm.render_priority = 2
	_feixes = MultiMeshInstance3D.new()
	_feixes.multimesh = mm
	_feixes.material_override = bm
	_feixes.name = "Feixes"
	add_child(_feixes)


func _m_chinelo(c: Cola) -> void:
	var rosa := Color(1.0, 0.5, 0.66)
	var k := 2.0
	var tf := Transform3D(Basis(Vector3.UP, deg_to_rad(35.0)) * Basis(Vector3.FORWARD, deg_to_rad(4.0)), Vector3(0, 0.02, 0))
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0, 0.07 * k)), Vector3(0.085, 0.016, 0.13) * k, rosa)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0, -0.04 * k)), Vector3(0.075, 0.016, 0.1) * k, rosa * 0.92)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.001, 0)), Vector3(0.07, 0.016, 0.05) * k, rosa * 0.96)
	var tira := Color(0.92, 0.86, 0.45)
	c.entre(tf * (Vector3(0, 0.012, 0.075) * k), tf * (Vector3(-0.03, 0.04, 0.03) * k), 0.01, 0.01, tira, 4)
	c.entre(tf * (Vector3(-0.03, 0.04, 0.03) * k), tf * (Vector3(-0.045, 0.012, 0.0) * k), 0.01, 0.01, tira, 4)
	c.entre(tf * (Vector3(0, 0.012, 0.075) * k), tf * (Vector3(0.03, 0.04, 0.03) * k), 0.01, 0.01, tira, 4)
	c.entre(tf * (Vector3(0.03, 0.04, 0.03) * k), tf * (Vector3(0.045, 0.012, 0.0) * k), 0.01, 0.01, tira, 4)
	# areia grudada na sola
	c.elipsoide(Transform3D(Basis(Vector3.UP, 0.5), Vector3(0.03, 0.02, -0.12)), Vector3(0.08, 0.02, 0.06), Color(0.52, 0.47, 0.38), 6, 2)


func _m_bola(c: Cola) -> void:
	var paineis: Array[Color] = [Color(0.85, 0.18, 0.14), Color(0.88, 0.88, 0.82), Color(0.2, 0.38, 0.8), Color(0.88, 0.88, 0.82)]
	var tf := Transform3D(Basis(Vector3.UP, 0.7) * Basis(Vector3.RIGHT, deg_to_rad(25.0)) * Basis(Vector3.FORWARD, deg_to_rad(15.0)), Vector3(0, 0.1, 0))
	var seg := 12
	var aneis := 6
	var raios := Vector3(0.17, 0.14, 0.17)         # murcha embaixo (meio afundada)
	var pts: Array = []
	for i in aneis + 1:
		var th := PI * float(i) / float(aneis)
		var linha: Array[Vector3] = []
		for k in seg + 1:
			var ph := TAU * float(k) / float(seg)
			linha.append(Vector3(raios.x * sin(th) * cos(ph), raios.y * cos(th), raios.z * sin(th) * sin(ph)))
		pts.append(linha)
	for i in aneis:
		for k in seg:
			var cor := paineis[(k / 3) % 4] * (0.7 + 0.3 * float(aneis - i) / float(aneis))
			cor.a = 1.0
			var a: Vector3 = tf * (pts[i][k] as Vector3)
			var b: Vector3 = tf * (pts[i][k + 1] as Vector3)
			var cc: Vector3 = tf * (pts[i + 1][k] as Vector3)
			var d: Vector3 = tf * (pts[i + 1][k + 1] as Vector3)
			var cen := tf * Vector3.ZERO
			c.tri(a, cc, b, cor, cor, cor, (a + b + cc) / 3.0 - cen)
			c.tri(b, cc, d, cor, cor, cor, (b + cc + d) / 3.0 - cen)


func _m_pazinha(c: Cola) -> void:
	var am := Color(1.0, 0.82, 0.12)
	var k := 1.9
	var tf := Transform3D(Basis(Vector3.UP, deg_to_rad(-125.0)) * Basis(Vector3.RIGHT, deg_to_rad(-4.0)), Vector3(0, 0.02, 0))
	c.caixa(tf, Vector3(0.075, 0.009, 0.08) * k, am)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(-0.0375, 0.012, 0.0) * k), Vector3(0.009, 0.02, 0.08) * k, am * 0.9)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0.0375, 0.012, 0.0) * k), Vector3(0.009, 0.02, 0.08) * k, am * 0.9)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.012, -0.04) * k), Vector3(0.075, 0.02, 0.009) * k, am * 0.9)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.004, 0.075) * k), Vector3(0.022, 0.01, 0.07) * k, am)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.004, 0.16) * k), Vector3(0.02, 0.012, 0.11) * k, am * 0.95)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0, 0.004, 0.225) * k), Vector3(0.07, 0.012, 0.014) * k, am)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(-0.03, 0.004, 0.25) * k), Vector3(0.014, 0.012, 0.05) * k, am)
	c.caixa(tf * Transform3D(Basis.IDENTITY, Vector3(0.03, 0.004, 0.25) * k), Vector3(0.014, 0.012, 0.05) * k, am)
	c.elipsoide(Transform3D(Basis.IDENTITY, Vector3(0.1, 0.012, -0.05)), Vector3(0.12, 0.02, 0.08), Color(0.5, 0.45, 0.36), 6, 2)


## Balde vermelho de pé, meio inclinado, com o T riscado de cabeça para baixo (bastão em cima, barra embaixo) voltado para a terra.
func _m_balde(c: Cola) -> void:
	var verm := Color(0.88, 0.12, 0.08)
	var inclina := Basis(Vector3.RIGHT, deg_to_rad(9.0)) * Basis(Vector3.FORWARD, deg_to_rad(-7.0))
	# o balde olha com a "frente" (+z local) para o lado de onde o jogador vem (terra, um pouco a oeste)
	var tf := Transform3D(Basis(Vector3.UP, atan2(-0.45, 0.9)) * inclina, Vector3(0, 0.02, 0))
	var r0 := 0.13
	var r1 := 0.185
	var h := 0.34
	c.cilindro(tf, r0, r1, h, verm, 10, false)
	c.cilindro(tf * Transform3D(Basis.IDENTITY, Vector3(0, h - 0.015, 0)), r1 + 0.008, r1 + 0.008, 0.03, verm * 0.85, 10, false)
	c.cilindro(tf * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.92, 0)), r1 * 0.94, r1 * 0.94, 0.001, Color(0.22, 0.03, 0.03), 10)
	c.elipsoide(tf * Transform3D(Basis.IDENTITY, Vector3(0, h * 0.9, 0.0)), Vector3(0.1, 0.03, 0.1), Color(0.5, 0.46, 0.38), 6, 2)
	# a alça caída para o lado
	var alca := Color(0.86, 0.86, 0.86)
	var ant := Vector3.INF
	for k in 9:
		var th := PI * float(k) / 8.0
		var pa := Vector3(r1 * 0.95 * cos(th), h - 0.02 + 0.07 * sin(th), 0.1 * sin(th))
		if ant != Vector3.INF:
			c.entre(tf * ant, tf * pa, 0.007, 0.007, alca, 4)
		ant = pa
	# o T: cal/giz na lateral. Barra embaixo e traço para cima = T de cabeça para baixo.
	var giz := Color(0.95, 0.93, 0.84)
	var tilt := atan2(r1 - r0, h)
	var frente := tf * Transform3D(Basis(Vector3.RIGHT, tilt), Vector3.ZERO)
	var rz := lerpf(r0, r1, 0.4) + 0.006
	c.caixa(frente * Transform3D(Basis.IDENTITY, Vector3(0, 0.09, rz)), Vector3(0.13, 0.028, 0.014), giz)
	c.caixa(frente * Transform3D(Basis.IDENTITY, Vector3(0, 0.17, rz)), Vector3(0.028, 0.15, 0.014), giz)


# ============================================================================ tarefa
func _tarefa() -> void:
	_criar_legenda()
	_criar_sino()
	for i in _objs.size():
		var o: Dictionary = _objs[i]
		var def: Dictionary = o["def"]
		var jah: bool = GameState.flag("praia_achou_" + str(def["id"])) or GameState.cidade_feita(id)
		if jah:
			o["achado"] = true
			_achados += 1
			continue
		var pos: Vector3 = def["pos"]
		var idx := i
		o["it"] = interagivel(str(def["olhar"]), pos + Vector3(0.0, 0.45, 0.0), Vector3(1.4, 0.9, 1.4), func(_p: Node) -> void: _achar(idx))
		(o["it"] as Node).name = "Achado_" + str(def["id"])
	if _achados >= OBJETOS.size():
		_pronto = true
		_ligar_portao()
	_atualizar_objetivo()
	_pulsar_brilhos()
	if _achados == 0:
		_t_sino = 3.0


## O jogador achou o objeto `i` (E). Idempotente.
func _achar(i: int) -> void:
	var o: Dictionary = _objs[i]
	if bool(o["achado"]):
		return
	o["achado"] = true
	var def: Dictionary = o["def"]
	GameState.set_flag("praia_achou_" + str(def["id"]), true)
	var it: Node = o["it"]
	if is_instance_valid(it):
		it.queue_free()
	o["it"] = null
	_achados += 1
	_ocioso = 0.0
	_proxima_dica = DICA_INTERVALO
	_atualizar_objetivo()
	_pulsar_brilhos()
	_mostrar_legenda("%s   [%d de %d]" % [str(def["legenda"]), _achados, OBJETOS.size()], 5.0, 24)
	if _achados >= OBJETOS.size():
		_completar()


func _completar() -> void:
	_pronto = true
	if atraso_final > 0.0:
		await get_tree().create_timer(atraso_final).timeout
	if not is_inside_tree() or _saindo:
		return
	_t_sino = 2.0
	pista("praia_balde", FALA_TAINA, "taina")             # conta antes de falar: não esperamos a fala acabar
	Guia.falar("bentinho", FALA_BENTINHO)
	_ligar_portao()
	_atualizar_objetivo()


## Depois da pista, o portão de volta passa a concluir o lugar (grava `cidade_praia_feito`).
func _ligar_portao() -> void:
	var it := find_child("PortaoVolta", true, false) as Interagivel
	if it != null:
		it.acao = func(_p: Node) -> void: concluir()


func _atualizar_objetivo() -> void:
	if _achados >= OBJETOS.size():
		definir_objetivo("Objetos: %d/%d. Tudo achado. Volte ao portão, na calçada (atrás de você, perto do Spawn), e saia da praia." % [_achados, OBJETOS.size()])
		return
	var falta: Array[String] = []
	var proximo: Dictionary = {}
	for o: Dictionary in _objs:
		if not bool(o["achado"]):
			falta.append(str((o["def"] as Dictionary)["nome"]))
			if proximo.is_empty():
				proximo = o["def"]
	if _achados == 0:
		definir_objetivo("Objetos: 0/%d. A maré trouxe coisas de criança. Siga o som do sino e as pegadinhas na areia. Faltam: %s." % [OBJETOS.size(), ", ".join(PackedStringArray(falta))])
	else:
		definir_objetivo("Objetos: %d/%d. Faltam: %s. Procure %s." % [_achados, OBJETOS.size(), ", ".join(PackedStringArray(falta)), str(proximo["onde"])])


# ============================================================================ sino, dicas, brilho
func _criar_sino() -> void:
	_sino = AudioStreamPlayer3D.new()
	_sino.name = "Sino"
	_sino.stream = SOM_SINO
	_sino.unit_size = 14.0
	_sino.max_distance = 140.0
	_sino.volume_db = -3.0
	_sino.pitch_scale = PITCH_SINO
	add_child(_sino)


func _process(dt: float) -> void:
	_tempo += dt
	_pulsar_brilhos()
	if player == null or _sino == null:
		return
	_ritmo_do_sino(dt)
	_ritmo_das_dicas(dt)


## O sino soa "do lado" do próximo objeto, a 12 m dele, de longe: dá a direção sem dizer a distância. Depois da pista, soa do portão.
func _ritmo_do_sino(dt: float) -> void:
	if _t_sino2 > 0.0:
		_t_sino2 -= dt
		if _t_sino2 <= 0.0:
			_sino.pitch_scale = PITCH_SINO * 0.84
			_sino.volume_db = -6.0
			_sino.play()
	_t_sino -= dt
	if _t_sino > 0.0:
		return
	_t_sino = randf_range(8.0, 10.5) if not _pronto else 14.0
	_sino.global_position = fonte_do_sino()
	_sino.pitch_scale = PITCH_SINO
	_sino.volume_db = -3.0
	_sino.play()
	_t_sino2 = 1.5


## Onde o sino soa agora (mundo).
func fonte_do_sino() -> Vector3:
	var alvo := Vector3.ZERO
	var tem := false
	if _pronto:
		var pt := find_child("Portao", true, false) as Node3D
		alvo = pt.global_position if pt != null else Vector3(3.0, 0.0, 14.0)
		tem = true
	else:
		var melhor := INF
		for o: Dictionary in _objs:
			if bool(o["achado"]):
				continue
			var p: Vector3 = (o["no"] as Node3D).global_position
			var d := p.distance_to(player.global_position)
			if d < melhor:
				melhor = d
				alvo = p
				tem = true
	if not tem:
		return Vector3(0.0, 4.0, Z_COSTA - 20.0)
	var de := player.global_position
	var dir := Vector3(alvo.x - de.x, 0.0, alvo.z - de.z)
	dir = dir.normalized() if dir.length() > 1.5 else Vector3(0.0, 0.0, -1.0)
	return alvo + dir * (6.0 if _pronto else 12.0) + Vector3(0.0, 2.5, 0.0)


func _ritmo_das_dicas(dt: float) -> void:
	if _pronto or Guia.ocupado():
		return
	_ocioso += dt
	if _ocioso >= _proxima_dica:
		_ocioso = 0.0
		_proxima_dica = DICA_INTERVALO
		dar_dica()


## Uma dica falada pela Tainá ou pelo Bentinho (a primeira é geral; as outras apontam o próximo achado).
func dar_dica() -> void:
	dicas_dadas += 1
	if _n_dicas == 0:
		_n_dicas += 1
		Guia.falar("taina", ["Psiu! O sino toca do lado de cada coisinha. E olha: tem pegadas pequenas na areia, bem fraquinhas."])
		return
	_n_dicas += 1
	for o: Dictionary in _objs:
		if not bool(o["achado"]):
			var d: Array = (o["def"] as Dictionary)["dica"]
			Guia.falar(str(d[0]), [str(d[1])])
			return


func _pulsar_brilhos() -> void:
	if _brilhos == null:
		return
	var mm := _brilhos.multimesh
	for i in _objs.size():
		var o: Dictionary = _objs[i]
		var s := 0.0 if bool(o["achado"]) else 0.34 + 0.1 * sin(_tempo * 2.2 + float(i) * 1.7)
		var p: Vector3 = (o["no"] as Node3D).position + Vector3(0.0, 0.55, 0.0)
		mm.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * maxf(s, 0.0001)), p))
		if _feixes != null:
			var f := 0.0 if bool(o["achado"]) else 1.0 + 0.15 * sin(_tempo * 1.6 + float(i) * 2.1)
			var base: Vector3 = (o["no"] as Node3D).position
			_feixes.multimesh.set_instance_transform(i, Transform3D(Basis.IDENTITY.scaled(Vector3(0.5 * maxf(f, 0.0001), 4.0 * maxf(f, 0.0001), 1.0)), base + Vector3(0.0, 2.0, 0.0)))


# ============================================================================ legenda
func _criar_legenda() -> void:
	var camada := CanvasLayer.new()
	camada.layer = 14
	camada.name = "LegendaPraia"
	add_child(camada)
	_legenda = Label.new()
	_legenda.add_theme_font_size_override("font_size", 24)
	_legenda.add_theme_color_override("font_color", Color(0.92, 0.95, 1.0))
	_legenda.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_legenda.add_theme_constant_override("outline_size", 6)
	_legenda.anchor_left = 0.0
	_legenda.anchor_right = 1.0
	_legenda.anchor_top = 1.0
	_legenda.anchor_bottom = 1.0
	_legenda.offset_left = 140.0
	_legenda.offset_right = -140.0
	_legenda.offset_top = -330.0
	_legenda.offset_bottom = -250.0
	_legenda.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_legenda.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_legenda.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_legenda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legenda.modulate.a = 0.0
	camada.add_child(_legenda)


func _mostrar_legenda(texto: String, dur := 4.0, tam := 24) -> void:
	if _legenda == null:
		return
	_legenda.text = Celular.adaptar(texto)
	_legenda.add_theme_font_size_override("font_size", tam)
	if _tween_legenda and _tween_legenda.is_valid():
		_tween_legenda.kill()
	_tween_legenda = create_tween()
	_tween_legenda.tween_property(_legenda, "modulate:a", 1.0, 0.3)
	_tween_legenda.tween_interval(dur)
	_tween_legenda.tween_property(_legenda, "modulate:a", 0.0, 0.9)


# ============================================================================ malha por código (cores nos vértices)
## Monta uma malha só com caixas, cilindros, elipsoides e toros, com cor por vértice e normais certas (face voltada para fora).
class Cola extends RefCounted:
	var st: SurfaceTool = SurfaceTool.new()

	func _init() -> void:
		st.begin(Mesh.PRIMITIVE_TRIANGLES)

	func malha() -> ArrayMesh:
		return st.commit()

	## Triângulo com `fora` = para onde a face deve apontar (ajusta a ordem dos vértices e a normal).
	func tri(a: Vector3, b: Vector3, c: Vector3, ca: Color, cb: Color, cc: Color, fora: Vector3) -> void:
		var n := (c - a).cross(b - a)
		if n.length_squared() < 1e-12:
			return
		if n.dot(fora) < 0.0:
			var t := b
			b = c
			c = t
			var tc := cb
			cb = cc
			cc = tc
			n = -n
		n = n.normalized()
		st.set_normal(n)
		st.set_color(ca)
		st.add_vertex(a)
		st.set_normal(n)
		st.set_color(cb)
		st.add_vertex(b)
		st.set_normal(n)
		st.set_color(cc)
		st.add_vertex(c)

	func caixa(tf: Transform3D, tam: Vector3, col: Color) -> void:
		var h := tam * 0.5
		for eixo in 3:
			for sinal: float in [-1.0, 1.0]:
				var u := (eixo + 1) % 3
				var v := (eixo + 2) % 3
				var cen := Vector3.ZERO
				cen[eixo] = sinal * h[eixo]
				var du := Vector3.ZERO
				du[u] = h[u]
				var dv := Vector3.ZERO
				dv[v] = h[v]
				var p0 := tf * (cen - du - dv)
				var p1 := tf * (cen + du - dv)
				var p2 := tf * (cen + du + dv)
				var p3 := tf * (cen - du + dv)
				var fora := tf.basis * cen
				tri(p0, p1, p2, col, col, col, fora)
				tri(p0, p2, p3, col, col, col, fora)

	## Cilindro/tronco de cone ao longo do +Y de `tf`, da base (raio r0) ao topo (raio r1, em y = h).
	func cilindro(tf: Transform3D, r0: float, r1: float, h: float, col: Color, lados := 8, tampas := true) -> void:
		var c0 := tf * Vector3.ZERO
		var c1 := tf * Vector3(0.0, h, 0.0)
		for k in lados:
			var a0 := TAU * float(k) / float(lados)
			var a1 := TAU * float(k + 1) / float(lados)
			var p00 := tf * Vector3(cos(a0) * r0, 0.0, sin(a0) * r0)
			var p01 := tf * Vector3(cos(a1) * r0, 0.0, sin(a1) * r0)
			var p10 := tf * Vector3(cos(a0) * r1, h, sin(a0) * r1)
			var p11 := tf * Vector3(cos(a1) * r1, h, sin(a1) * r1)
			var am := (a0 + a1) * 0.5
			var fora := tf.basis * Vector3(cos(am), 0.0, sin(am))
			tri(p00, p01, p11, col, col, col, fora)
			tri(p00, p11, p10, col, col, col, fora)
			if tampas:
				tri(c0, p01, p00, col, col, col, tf.basis * Vector3.DOWN)
				tri(c1, p10, p11, col, col, col, tf.basis * Vector3.UP)

	## Cilindro entre dois pontos.
	func entre(a: Vector3, b: Vector3, r0: float, r1: float, col: Color, lados := 6) -> void:
		var d := b - a
		if d.length() < 0.001:
			return
		var y := d.normalized()
		var q := Quaternion(Vector3.UP, y) if y.dot(Vector3.UP) > -0.999 else Quaternion(Vector3.RIGHT, PI)
		cilindro(Transform3D(Basis(q), a), r0, r1, d.length(), col, lados)

	func elipsoide(tf: Transform3D, raios: Vector3, col: Color, seg := 8, aneis := 4) -> void:
		var pts: Array = []
		for i in aneis + 1:
			var th := PI * float(i) / float(aneis)
			var linha: Array[Vector3] = []
			for k in seg + 1:
				var ph := TAU * float(k) / float(seg)
				linha.append(Vector3(raios.x * sin(th) * cos(ph), raios.y * cos(th), raios.z * sin(th) * sin(ph)))
			pts.append(linha)
		var cen := tf * Vector3.ZERO
		for i in aneis:
			for k in seg:
				var a: Vector3 = tf * (pts[i][k] as Vector3)
				var b: Vector3 = tf * (pts[i][k + 1] as Vector3)
				var c: Vector3 = tf * (pts[i + 1][k] as Vector3)
				var d: Vector3 = tf * (pts[i + 1][k + 1] as Vector3)
				tri(a, c, b, col, col, col, (a + b + c) / 3.0 - cen)
				tri(b, c, d, col, col, col, (b + c + d) / 3.0 - cen)

	## Toro deitado no plano XZ de `tf`; `cores` se repetem a cada par de segmentos.
	func toro(tf: Transform3D, grande: float, pequeno: float, cores: Array, seg := 16, lados := 6) -> void:
		for i in seg:
			var a0 := TAU * float(i) / float(seg)
			var a1 := TAU * float(i + 1) / float(seg)
			var col: Color = cores[(i * cores.size() / seg) % cores.size()]
			var cen := tf * Vector3((grande) * cos((a0 + a1) * 0.5), 0.0, grande * sin((a0 + a1) * 0.5))
			for j in lados:
				var b0 := TAU * float(j) / float(lados)
				var b1 := TAU * float(j + 1) / float(lados)
				var p00 := tf * _no_toro(grande, pequeno, a0, b0)
				var p01 := tf * _no_toro(grande, pequeno, a0, b1)
				var p10 := tf * _no_toro(grande, pequeno, a1, b0)
				var p11 := tf * _no_toro(grande, pequeno, a1, b1)
				var fora := (p00 + p01 + p10 + p11) * 0.25 - cen
				tri(p00, p01, p11, col, col, col, fora)
				tri(p00, p11, p10, col, col, col, fora)

	func _no_toro(grande: float, pequeno: float, a: float, b: float) -> Vector3:
		var r := grande + pequeno * cos(b)
		return Vector3(r * cos(a), pequeno * sin(b), r * sin(a))
