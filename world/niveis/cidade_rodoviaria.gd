extends CidadeBase
## LUGAR DA CIDADE: Rodoviária, fim da temporada (Módulo 14). Abre depois da Sala Medieval da visita 4 (o jogador JÁ tem os discos).
## Em 2020 (e nos discos de 1950, 1975 e 2019) é uma rodoviária genérica, vazia, ao fim de tarde: plataformas cobertas, bancos,
## guichê fechado, quadro de horários desbotado, relógio parado, lixeira e máquina de bilhete. SEM nome de empresa nem marca real.
## Com o Visor no disco de 1967 (ou no sem data) é MARÇO DE 1967, o último ônibus da temporada: silhuetas e malas, um ônibus de
## linha antigo parado, vozes abafadas, cartazes de PROCURA-SE recém pregados.
##
## TAREFA (1 pista, `rodoviaria_cartaz`), tudo no Visor de 1967:
##   1. O quadro de horários perdeu 3 plaquinhas de destino (TRAMANDAÍ, OSÓRIO, PORTO ALEGRE). Elas estão espalhadas: sob os bancos
##      (oeste), no degrau do ônibus e no carrinho de bagagem (leste). Cada uma brilha de leve.
##   2. Recolocá-las no quadro abre o guichê (a persiana sobe). Dentro, preso na parede, está o cartaz escrito à mão que a mãe do
##      Tito (SÓ VOZ, nunca aparece) deixou antes do último ônibus: data 12/03/1967, descrição sem foto, endereço FICTÍCIO da casa.
##   3. Ler o cartaz conta a pista e fecha a história: o Tito sumiu em 1967, não em 2019. Depois o portão de volta passa a
##      CONCLUIR o lugar (`concluir()`: grava `cidade_rodoviaria_feito` e volta à calçada).
## Sem o Visor ligado nada acontece além do cenário e das dicas da Guia (Bentinho/Tainá). Nada trava: o portão sempre sai.
##
## VISOR: a visita é a 4, em que o Visor "atrai a atenção" e solta a Figura. AQUI NÃO: este lugar liga a flag `visor_calmo`
## (a mesma do final "Tito salvo", Módulo 13; o Visor zera a atenção) e a tira ao sair. `GameState.carregar` também a descarta.
## Os subtítulos do Visor por época vêm de `Efeitos.subtitulo_lugar`. Contrato com o Main: igual ao da base.
## Teste: `tests/cidade_rodoviaria_test.gd`. Captura: `tests/captura_cidade_rodoviaria.gd`.
## Conteúdo: tudo fictício (casa, rua, mãe e família); o Tito NUNCA aparece; só sugestão (a mala ao pé do banco), nada de violência.

const PISTA := "rodoviaria_cartaz"
## 1967 = disco de 1967 e disco sem data. O resto das épocas vê a rodoviária de hoje.
const E67: Array = [GameState.Epoca.E1967, GameState.Epoca.ESEMDATA]
const E_HOJE: Array = [GameState.Epoca.E1950, GameState.Epoca.E1975, GameState.Epoca.E2019, GameState.Epoca.E2020]

# --- planta (x leste, z sul): prédio ao norte, plataforma coberta, pista dos ônibus, calçada ao sul
const Z_FACE := -9.0               # fachada do prédio (olha para +z)
const Z_BEIRA := -2.6              # borda da cobertura
const X_QUADRO := -10.5            # centro do quadro de horários
const X_GUICHE := -4.0             # centro do guichê
const JX0 := -5.4                  # janela do guichê
const JX1 := -2.6
const JY0 := 1.0
const JY1 := 2.3
const Z_CAV := -10.6               # fundo da cavidade do guichê
const ALT_PREDIO := 4.2
const ALT_TETO := 3.95
const ONIBUS := Rect2(3.0, -0.1, 10.4, 2.5)   # (x, z, comprimento em x, largura em z); a porta fica na face norte
const FONTE_QUADRO := "res://assets/fonts/VT323-Latin.ttf"

## Quadro de horários de 1967: [horário, destino, id da plaquinha que falta ("" = a placa está lá)].
const LINHAS := [
	["07:10", "CIDREIRA", ""],
	["08:30", "TRAMANDAÍ", "tramandai"],
	["10:15", "TORRES", ""],
	["12:30", "CAPÃO DA CANOA", ""],
	["14:40", "OSÓRIO", "osorio"],
	["18:00", "PORTO ALEGRE", "poa"],
]
## As 3 plaquinhas: onde estão, para onde viram e a dica se o jogador demora. `linha` = índice em LINHAS.
const PLACAS := {
	"tramandai": {"linha": 1, "pos": Vector3(-16.4, 0.6, -5.08), "yaw": 0.0, "roll": 5.0,
		"dica": "Uma plaquinha brilha perto dos bancos, do lado de onde você chegou."},
	"osorio": {"linha": 4, "pos": Vector3(12.05, 0.44, -0.32), "yaw": 180.0, "roll": -4.0,
		"dica": "Outra plaquinha está no degrau da porta do ônibus parado."},
	"poa": {"linha": 5, "pos": Vector3(16.5, 0.45, -6.15), "yaw": 0.0, "roll": 3.0,
		"dica": "A última está no carrinho de bagagem, no fim da plataforma, longe da entrada."},
}
const TEXTO_PROCURA := {
	"titulo": "PROCURA-SE",
	"nome": "TITO, 9 anos",
	"corpo": "Sumiu no domingo, 12/03/1967, na praia, perto da obra do castelinho.\nCamiseta listrada, bermuda azul, cabelo escuro e curto. Levava um balde vermelho.",
	"foto": "Não temos foto dele. Só os desenhos que ele faz.",
	"endereco": "Se alguém viu, avise: Casa 7, Travessa das Conchas (a casa de veraneio da família). Fone 4-27.",
	"assina": "— a mãe do Tito",
	"rodape": "cartaz fictício · Castelinho: Visita Guiada",
}
const DICA_ATRASO := 50.0          # s sem progresso até a Guia dar uma dica
const MAX_DICAS := 6

# --- estado
var _n67: Node3D                   # tudo que só existe em 1967
var _n20: Node3D                   # tudo que só existe nos outros anos
var _no_placas := {}               # id -> Node3D (plaquinha pendurada no cenário)
var _mat_placas := {}              # id -> StandardMaterial3D (brilho que pisca)
var _levadas: Array[String] = []   # plaquinhas na mão
var _postas: Array[String] = []    # plaquinhas já no quadro
var _plac_quadro := {}             # id -> Node3D (a placa no quadro, escondida até pendurar)
var guiche_aberto := false
var lido := false                  # o cartaz foi lido (a pista foi contada)
var _lendo := false
var ui_cartaz: CartazUI            # (testes)
var _persiana: Node3D
var _luz_guiche: OmniLight3D
var _cartaz_dentro: Node3D
var _it_quadro: Interagivel
var _it_guiche: Interagivel
var _mat_fantasma: StandardMaterial3D
var _fantasmas: Array = []         # {no, base, eixo, amp, vel, fase}
var _t := 0.0
var _t_dica := 0.0
var _dicas := 0
var _t_voz := 6.0
var _epoca_vista := -1
var visor_1967_visto := false
var _mae_falou := false
var _fonte: Font


func _configurar() -> void:
	id = "rodoviaria"
	area = Rect2(-25.0, -15.0, 50.0, 30.0)
	hora = Hora.FIM_DE_TARDE
	clima = Clima.LIMPO
	spawn_pos = Vector3(-21.0, 0.1, 4.0)
	spawn_yaw = -90.0                       # de frente para o leste: o ônibus ao fundo, a plataforma à esquerda
	portao_pos = Vector3(-22.6, 0.0, 8.6)
	ambiente_audio = "vento"
	usa_visor = true


func _material_chao() -> Material:
	return mat_calcada()


func iniciar(p: Player) -> void:
	# SEM Figura aqui: a atenção do Visor fica em zero (flag lida por visor.gd; `GameState.carregar` a descarta de qualquer save)
	GameState.flags["visor_calmo"] = true
	super.iniciar(p)


func _exit_tree() -> void:
	if is_instance_valid(GameState):
		GameState.flags.erase("visor_calmo")
	if is_instance_valid(Efeitos):
		Efeitos.subtitulo_lugar = {}
		if Efeitos.visor_ativo:
			Efeitos.legenda_visor("")
	super._exit_tree()


# ============================================================================ cenário
func _construir() -> void:
	_fonte = load(FONTE_QUADRO)
	_n67 = Node3D.new()
	_n67.name = "Rodoviaria1967"
	add_child(_n67)
	_n20 = Node3D.new()
	_n20.name = "RodoviariaHoje"
	add_child(_n20)
	_cenario_fixo()
	_hoje()
	_em_1967()
	Epocas.marcar(_n67, E67)
	Epocas.marcar(_n20, E_HOJE)
	_fundo_distante()


func _c(r: float, g: float, b: float, a := 1.0) -> StandardMaterial3D:
	return Castelinho.mat_cor(Color(r, g, b, a))


## Caixa com colisão opcional (coordenadas do mundo) numa Malha.
func _bloco(m: Malha, mat: Material, p0: Vector3, p1: Vector3, colisao := true) -> void:
	m.caixa(mat, p0, p1)
	if colisao:
		m.col(p0, p1)


func _texto(pai: Node3D, texto: String, pos: Vector3, fonte_px: int, cor: Color, pixel := 0.004, alinh := HORIZONTAL_ALIGNMENT_CENTER,
		fonte: Font = null, yaw := 0.0) -> Label3D:
	var l := Label3D.new()
	l.text = texto
	l.font_size = fonte_px
	l.modulate = cor
	l.outline_size = 0
	l.pixel_size = pixel
	l.position = pos
	l.horizontal_alignment = alinh
	l.double_sided = false
	if fonte != null:
		l.font = fonte
	l.rotation_degrees.y = yaw
	pai.add_child(l)
	return l


## O que existe em todas as épocas: prédio, guichê (a estrutura), cobertura, bancos, lixeira, carrinho, pista, calçada.
func _cenario_fixo() -> void:
	var mf := Malha.new()
	var parede := _c(0.82, 0.78, 0.63)
	var rodape := _c(0.45, 0.46, 0.42)
	var teto := _c(0.36, 0.4, 0.42)
	var faixa := _c(0.16, 0.36, 0.3)
	var ferro := _c(0.22, 0.24, 0.26)
	var porta := _c(0.2, 0.26, 0.3)
	var vidro := _c(0.27, 0.4, 0.44)
	var concreto := _c(0.6, 0.58, 0.54)

	# prédio (blocos maciços): a cavidade do guichê fica entre o bloco da esquerda e o da direita
	_bloco(mf, parede, Vector3(-23.0, 0.0, -15.0), Vector3(JX0, ALT_PREDIO, Z_FACE))
	_bloco(mf, parede, Vector3(JX1, 0.0, -15.0), Vector3(17.0, ALT_PREDIO, Z_FACE))
	_bloco(mf, parede, Vector3(JX0, 0.0, -15.0), Vector3(JX1, ALT_PREDIO, Z_CAV))
	_bloco(mf, parede, Vector3(JX0, 0.0, Z_CAV), Vector3(JX1, JY0, Z_FACE))
	_bloco(mf, parede, Vector3(JX0, JY1, Z_CAV), Vector3(JX1, ALT_PREDIO, Z_FACE))
	# interior da cavidade mais escuro (a face de trás e o balcão de dentro), para a janela ler como "buraco"
	mf.caixa(_c(0.5, 0.46, 0.38), Vector3(JX0 + 0.01, JY0, Z_CAV + 0.0), Vector3(JX1 - 0.01, JY1, Z_CAV + 0.02))
	# detalhes da fachada (4 cm à frente da parede, sem colisão)
	mf.caixa(rodape, Vector3(-22.98, 0.0, Z_FACE - 0.02), Vector3(16.98, 0.55, Z_FACE + 0.04))
	mf.caixa(faixa, Vector3(-22.97, 3.3, Z_FACE - 0.02), Vector3(16.97, 3.68, Z_FACE + 0.03))
	for xs in [[-21.0, -19.6], [-18.9, -17.5], [7.6, 9.0], [9.8, 11.2]]:
		mf.caixa(porta, Vector3(xs[0], 0.0, Z_FACE - 0.02), Vector3(xs[1], 2.4, Z_FACE + 0.06))
	mf.caixa(vidro, Vector3(12.6, 0.7, Z_FACE - 0.02), Vector3(16.2, 2.7, Z_FACE + 0.05))
	for x in [12.6, 14.4, 16.2]:
		mf.caixa(ferro, Vector3(x - 0.04, 0.68, Z_FACE + 0.03), Vector3(x + 0.04, 2.72, Z_FACE + 0.07))
	# moldura da janela do guichê e a soleira
	mf.caixa(ferro, Vector3(JX0 - 0.12, JY0 - 0.06, Z_FACE - 0.02), Vector3(JX0 - 0.02, JY1 + 0.1, Z_FACE + 0.05))
	mf.caixa(ferro, Vector3(JX1 + 0.02, JY0 - 0.06, Z_FACE - 0.02), Vector3(JX1 + 0.12, JY1 + 0.1, Z_FACE + 0.05))
	mf.caixa(ferro, Vector3(JX0 - 0.02, JY1 + 0.02, Z_FACE - 0.02), Vector3(JX1 + 0.02, JY1 + 0.1, Z_FACE + 0.05))
	mf.caixa(concreto, Vector3(JX0 - 0.1, JY0 - 0.04, Z_FACE), Vector3(JX1 + 0.1, JY0 + 0.02, Z_FACE + 0.2))
	# letreiro (a placa do prédio, em cima da cobertura)
	mf.caixa(faixa, Vector3(-9.0, ALT_PREDIO - 0.02, Z_FACE - 0.02), Vector3(1.0, 5.5, Z_FACE + 0.12))

	# cobertura da plataforma: laje, friso da frente e colunas
	mf.caixa(teto, Vector3(-23.3, 3.7, Z_FACE - 0.02), Vector3(17.8, ALT_TETO, Z_BEIRA))
	mf.caixa(faixa, Vector3(-23.35, 3.4, Z_BEIRA - 0.12), Vector3(17.85, ALT_TETO + 0.03, Z_BEIRA + 0.03))
	for x in [-21.5, -15.0, -8.5, -2.0, 4.5, 11.0, 17.0]:
		_bloco(mf, concreto, Vector3(x - 0.12, 0.0, -3.12), Vector3(x + 0.12, 3.7, -2.88))

	# chão: piso da plataforma, pista de asfalto, faixa de meio-fio e divisórias das baias
	mf.caixa(concreto, Vector3(-25.0, 0.0, Z_FACE), Vector3(25.0, 0.012, Z_BEIRA - 0.3), Malha.F_PY)
	mf.caixa(_c(0.2, 0.2, 0.23), Vector3(-25.0, 0.0, -1.4), Vector3(25.0, 0.02, 9.4), Malha.F_PY)
	mf.caixa(_c(0.78, 0.62, 0.14), Vector3(-25.0, 0.0, -1.75), Vector3(25.0, 0.025, -1.58), Malha.F_PY)
	var xd := -24.0
	while xd < 24.0:
		mf.caixa(_c(0.8, 0.8, 0.74), Vector3(xd, 0.0, 5.9), Vector3(xd + 1.6, 0.025, 6.05), Malha.F_PY)
		xd += 3.2
	for x in [2.2, 14.8]:
		mf.caixa(_c(0.85, 0.85, 0.8), Vector3(x - 0.06, 0.0, -1.3), Vector3(x + 0.06, 0.03, 3.6), Malha.F_PY)

	# bancos (assento voltado para a pista), lixeira e carrinho de bagagem
	var madeira := _c(0.42, 0.28, 0.17)
	for bx in [-16.5, -8.0, 2.0, 10.0]:
		mf.caixa(madeira, Vector3(bx - 0.95, 0.42, -5.25), Vector3(bx + 0.95, 0.475, -4.75))
		mf.caixa(madeira, Vector3(bx - 0.95, 0.68, -5.27), Vector3(bx + 0.95, 1.0, -5.2))
		mf.caixa(ferro, Vector3(bx - 0.85, 0.0, -5.22), Vector3(bx - 0.77, 0.42, -4.78))
		mf.caixa(ferro, Vector3(bx + 0.77, 0.0, -5.22), Vector3(bx + 0.85, 0.42, -4.78))
		mf.col(Vector3(bx - 0.95, 0.0, -5.28), Vector3(bx + 0.95, 1.0, -4.74))
	_bloco(mf, _c(0.26, 0.36, 0.3), Vector3(7.2, 0.0, -8.7), Vector3(7.7, 0.9, -8.2))
	mf.caixa(_c(0.13, 0.15, 0.15), Vector3(7.15, 0.9, -8.75), Vector3(7.75, 0.97, -8.15))
	var carr := Vector3(16.5, 0.0, -6.2)
	mf.caixa(ferro, carr + Vector3(-0.8, 0.22, -0.4), carr + Vector3(0.8, 0.3, 0.4))
	mf.caixa(ferro, carr + Vector3(0.76, 0.3, -0.38), carr + Vector3(0.82, 1.05, -0.32))
	mf.caixa(ferro, carr + Vector3(0.76, 0.3, 0.32), carr + Vector3(0.82, 1.05, 0.38))
	mf.caixa(ferro, carr + Vector3(0.76, 1.0, -0.38), carr + Vector3(0.82, 1.06, 0.38))
	for dx in [-0.7, 0.7]:
		for dz in [-0.34, 0.34]:
			mf.caixa(_c(0.1, 0.1, 0.1), carr + Vector3(dx - 0.05, 0.0, dz - 0.04), carr + Vector3(dx + 0.05, 0.22, dz + 0.04))
	mf.col(carr + Vector3(-0.8, 0.0, -0.4), carr + Vector3(0.8, 0.5, 0.4))

	# a cerca viva ao sul
	var verde := [_c(0.2, 0.34, 0.2), _c(0.24, 0.4, 0.22), _c(0.17, 0.3, 0.19)]
	var xs_cerca := -24.0
	var k := 0
	while xs_cerca < 24.0:
		var comp := 2.6 + float(k % 3) * 0.5
		mf.caixa(verde[k % 3], Vector3(xs_cerca, 0.0, 13.8), Vector3(xs_cerca + comp, 0.8 + float(k % 4) * 0.12, 14.7))
		xs_cerca += comp + 0.35
		k += 1
	mf.construir_instancia(self, "CenarioFixo")
	mf.construir_colisao(self, "CenarioFixoColisao")

	# placas de texto do prédio
	_texto(self, "RODOVIÁRIA DE IMBÉ", Vector3(-4.0, 4.85, Z_FACE + 0.14), 150, Color(0.95, 0.93, 0.82), 0.0058)
	_texto(self, "PLATAFORMA 1", Vector3(-9.0, 3.66, Z_BEIRA + 0.04), 64, Color(0.95, 0.93, 0.82), 0.0045)
	_texto(self, "PLATAFORMA 2", Vector3(9.0, 3.66, Z_BEIRA + 0.04), 64, Color(0.95, 0.93, 0.82), 0.0045)
	_texto(self, "BILHETERIA", Vector3(X_GUICHE, 2.5, Z_FACE + 0.06), 56, Color(0.2, 0.2, 0.18), 0.0042)
	# dois postes de luz da pista (só a peça; sem luz de verdade)
	poste(Vector3(-13.0, 0.0, 9.8), 5.0)
	poste(Vector3(17.0, 0.0, 9.8), 5.0)


## Só nos outros anos (2020 e os discos 1950/1975/2019): persiana fechada, quadro desbotado, relógio parado, máquina de bilhete.
func _hoje() -> void:
	var m := Malha.new()
	m.epocas = E_HOJE
	var cinza := _c(0.5, 0.52, 0.5)
	m.caixa(cinza, Vector3(JX0 + 0.01, JY0 + 0.01, Z_FACE - 0.02), Vector3(JX1 - 0.01, JY1 - 0.01, Z_FACE + 0.06))
	for i in 7:
		m.caixa(_c(0.4, 0.42, 0.4), Vector3(JX0, JY0 + 0.1 + i * 0.18, Z_FACE + 0.06), Vector3(JX1, JY0 + 0.14 + i * 0.18, Z_FACE + 0.075))
	# máquina de bilhete, apagada
	m.caixa(_c(0.28, 0.34, 0.4), Vector3(3.9, 0.0, Z_FACE - 0.02), Vector3(4.9, 1.9, Z_FACE + 0.55))
	m.col(Vector3(3.9, 0.0, Z_FACE - 0.02), Vector3(4.9, 1.9, Z_FACE + 0.55))
	m.caixa(_c(0.08, 0.09, 0.1), Vector3(4.05, 1.25, Z_FACE + 0.55), Vector3(4.75, 1.7, Z_FACE + 0.57))
	m.caixa(_c(0.1, 0.1, 0.11), Vector3(4.15, 0.75, Z_FACE + 0.55), Vector3(4.65, 0.9, Z_FACE + 0.58))
	# quadro de horários desbotado (a placa saiu da cor, faltam letras)
	var x0 := X_QUADRO - 1.9
	m.caixa(_c(0.4, 0.4, 0.37), Vector3(x0 - 0.06, 0.74, Z_FACE - 0.02), Vector3(x0 + 3.86, 3.06, Z_FACE + 0.03))
	m.caixa(_c(0.58, 0.6, 0.55), Vector3(x0, 0.8, Z_FACE + 0.03), Vector3(x0 + 3.8, 3.0, Z_FACE + 0.05))
	m.caixa(_c(0.5, 0.52, 0.47), Vector3(x0 + 2.6, 0.8, Z_FACE + 0.05), Vector3(x0 + 3.8, 1.3, Z_FACE + 0.056))   # canto manchado
	m.construir_instancia(_n20, "Hoje")
	m.construir_colisao(_n20, "HojeColisao")
	var tinta := Color(0.3, 0.32, 0.3, 0.5)
	var rows := ["07:10  CIDRE RA", "08:30  T AMAN AÍ", "10:15  TO  ES", "12:30  CAPÃO D  C NOA", "14:40  OS RIO", "18:00  PO TO ALE RE"]
	_texto(_n20, "S  DAS", Vector3(X_QUADRO, 2.82, Z_FACE + 0.06), 72, tinta, 0.0045, HORIZONTAL_ALIGNMENT_CENTER, _fonte)
	for i in 6:
		_texto(_n20, rows[i], Vector3(x0 + 0.15, 2.45 - i * 0.27, Z_FACE + 0.06), 56, tinta, 0.0038, HORIZONTAL_ALIGNMENT_LEFT, _fonte)
	_texto(_n20, "FECHADO", Vector3(X_GUICHE, 1.65, Z_FACE + 0.085), 70, Color(0.15, 0.15, 0.14), 0.0045)
	_texto(_n20, "FORA DE SERVIÇO", Vector3(4.4, 1.5, Z_FACE + 0.6), 36, Color(0.7, 0.2, 0.15), 0.0027)
	_relogio(_n20, Vector3(X_GUICHE, 3.1, Z_FACE + 0.05), 4, 20, Color(0.7, 0.68, 0.6))
	# interações de hoje
	var it_q := interagivel("Ler o quadro de horários", Vector3(X_QUADRO, 1.9, Z_FACE + 0.5), Vector3(3.8, 2.3, 1.2), _ler_quadro_hoje)
	var it_g := interagivel("Olhar o guichê", Vector3(X_GUICHE, 1.7, Z_FACE + 0.5), Vector3(3.0, 1.6, 1.2), _guiche_hoje)
	var it_m := interagivel("Olhar a máquina de bilhete", Vector3(4.4, 1.0, Z_FACE + 0.6), Vector3(1.2, 2.0, 1.0),
		func(_p: Node) -> void: _falar("bentinho", ["A máquina de bilhete está apagada. Faz tempo que ninguém compra passagem aqui."]))
	Epocas.marcar(it_q, E_HOJE)
	Epocas.marcar(it_g, E_HOJE)
	Epocas.marcar(it_m, E_HOJE)


## Só em 1967: o ônibus, o quadro com 3 vazios, a persiana, a mala, as silhuetas, os cartazes e as plaquinhas.
func _em_1967() -> void:
	var m := Malha.new()
	m.epocas = E67
	var creme := _c(0.86, 0.8, 0.64)
	var verde := _c(0.16, 0.38, 0.32)
	var escuro := _c(0.06, 0.09, 0.08)
	var cartela := _c(0.9, 0.86, 0.7)
	# --- quadro de horários (mesma parede, mais novo; os 3 vazios são os destinos que faltam)
	var x0 := X_QUADRO - 1.9
	m.caixa(_c(0.38, 0.26, 0.15), Vector3(x0 - 0.06, 0.74, Z_FACE - 0.02), Vector3(x0 + 3.86, 3.06, Z_FACE + 0.03))
	m.caixa(_c(0.12, 0.2, 0.16), Vector3(x0, 0.8, Z_FACE + 0.03), Vector3(x0 + 3.8, 3.0, Z_FACE + 0.05))
	for i in LINHAS.size():
		var y: float = 2.45 - i * 0.27
		var falta: bool = LINHAS[i][2] != ""
		m.caixa(escuro if falta else cartela, Vector3(X_QUADRO - 1.0, y - 0.1, Z_FACE + 0.05), Vector3(X_QUADRO + 1.8, y + 0.1, Z_FACE + 0.06))
	# --- o ônibus de linha antigo, parado na baia 1 (porta na face norte, virada para a plataforma)
	var b := ONIBUS
	var x1 := b.position.x + b.size.x
	var z0 := b.position.y
	var z1 := b.position.y + b.size.y
	var bx := b.position.x
	m.caixa(creme, Vector3(bx, 0.35, z0), Vector3(x1, 1.6, z1))
	m.caixa(creme, Vector3(bx + 0.05, 1.6, z0 + 0.05), Vector3(x1 - 0.05, 2.9, z1 - 0.05))
	m.caixa(_c(0.74, 0.7, 0.58), Vector3(bx + 0.15, 2.9, z0 + 0.15), Vector3(x1 - 0.15, 3.05, z1 - 0.15))
	m.caixa(verde, Vector3(bx - 0.01, 0.95, z0 - 0.01), Vector3(x1 + 0.01, 1.25, z1 + 0.01))
	for zz in [z0, z1]:
		var sinal: float = -1.0 if zz == z0 else 1.0
		m.caixa(_c(0.1, 0.14, 0.18), Vector3(bx + 0.4, 1.72, zz - 0.02), Vector3(x1 - 1.9, 2.55, zz + 0.02))
		var xp := bx + 1.4
		while xp < x1 - 1.9:
			m.caixa(creme, Vector3(xp - 0.04, 1.7, zz + sinal * 0.01), Vector3(xp + 0.04, 2.57, zz + sinal * 0.05))
			xp += 1.3
	m.caixa(_c(0.1, 0.14, 0.18), Vector3(x1 - 0.02, 1.7, z0 + 0.2), Vector3(x1 + 0.03, 2.55, z1 - 0.2))                  # para-brisa
	m.caixa(creme, Vector3(x1 - 0.03, 1.68, (z0 + z1) * 0.5 - 0.04), Vector3(x1 + 0.045, 2.57, (z0 + z1) * 0.5 + 0.04))
	m.caixa(_c(0.12, 0.12, 0.1), Vector3(x1 - 0.02, 2.6, z0 + 0.3), Vector3(x1 + 0.055, 2.88, z1 - 0.3))                    # letreiro
	m.caixa(_c(0.62, 0.62, 0.64), Vector3(x1, 0.4, z0), Vector3(x1 + 0.14, 0.62, z1))
	m.caixa(Castelinho.mat_luz(Color(1.0, 0.92, 0.7)), Vector3(x1, 0.78, z0 + 0.18), Vector3(x1 + 0.07, 1.04, z0 + 0.5))
	m.caixa(Castelinho.mat_luz(Color(1.0, 0.92, 0.7)), Vector3(x1, 0.78, z1 - 0.5), Vector3(x1 + 0.07, 1.04, z1 - 0.18))
	m.caixa(Castelinho.mat_luz(Color(0.8, 0.12, 0.1)), Vector3(bx - 0.04, 0.8, z0 + 0.15), Vector3(bx, 1.0, z0 + 0.45))
	m.caixa(Castelinho.mat_luz(Color(0.8, 0.12, 0.1)), Vector3(bx - 0.04, 0.8, z1 - 0.45), Vector3(bx, 1.0, z1 - 0.15))
	for xw in [bx + 2.0, x1 - 2.2]:
		for zz in [z0 - 0.06, z1 - 0.2]:
			m.caixa(_c(0.07, 0.07, 0.08), Vector3(xw - 0.45, 0.0, zz), Vector3(xw + 0.45, 0.8, zz + 0.26))
	m.caixa(_c(0.1, 0.22, 0.2), Vector3(11.6, 0.45, z0 - 0.03), Vector3(12.5, 2.5, z0 + 0.01))                              # porta
	m.caixa(_c(0.5, 0.5, 0.48), Vector3(11.6, 0.12, z0 - 0.42), Vector3(12.5, 0.28, z0))                                      # degrau
	m.col(Vector3(bx, 0.0, z0), Vector3(x1, 3.0, z1))
	# --- a malinha e o balde ao pé do banco (peso por sugestão: ninguém veio buscar)
	m.caixa(_c(0.5, 0.35, 0.2), Vector3(1.25, 0.0, -4.55), Vector3(1.7, 0.27, -4.3))
	m.caixa(_c(0.28, 0.2, 0.12), Vector3(1.25, 0.1, -4.43), Vector3(1.7, 0.13, -4.42))
	m.caixa(_c(0.78, 0.7, 0.5), Vector3(1.43, 0.0, -4.56), Vector3(1.49, 0.275, -4.29))                                       # barbante
	m.construir_instancia(_n67, "Visao1967")
	m.construir_colisao(_n67, "Colisao1967")
	var balde := TitoCastelinho.criar_balde(0.8)
	balde.position = Vector3(0.75, 0.0, -4.25)
	_n67.add_child(balde)
	_texto(_n67, "PORTO ALEGRE", Vector3(x1 + 0.045, 2.74, (z0 + z1) * 0.5), 60, Color(1.0, 0.82, 0.4), 0.0034, HORIZONTAL_ALIGNMENT_CENTER, _fonte, 90.0)

	# --- quadro: horários, destinos e os espaços vazios
	_texto(_n67, "SAÍDAS · FIM DA TEMPORADA", Vector3(X_QUADRO, 2.84, Z_FACE + 0.065), 64, Color(0.95, 0.92, 0.8), 0.0042, HORIZONTAL_ALIGNMENT_CENTER, _fonte)
	for i in LINHAS.size():
		var y: float = 2.45 - i * 0.27
		_texto(_n67, LINHAS[i][0], Vector3(x0 + 0.15, y, Z_FACE + 0.065), 56, Color(0.95, 0.92, 0.8), 0.0038, HORIZONTAL_ALIGNMENT_LEFT, _fonte)
		if LINHAS[i][2] == "":
			_texto(_n67, LINHAS[i][1], Vector3(X_QUADRO + 0.4, y, Z_FACE + 0.07), 56, Color(0.12, 0.12, 0.1), 0.0038, HORIZONTAL_ALIGNMENT_CENTER, _fonte)
		else:
			var plac := Node3D.new()
			plac.name = "PlacaNoQuadro_" + str(LINHAS[i][2])
			plac.position = Vector3(X_QUADRO + 0.4, y, Z_FACE + 0.062)
			plac.visible = false
			_n67.add_child(plac)
			Construtor.caixa(plac, Vector3(2.8, 0.2, 0.012), Vector3.ZERO, Ato2Pecas.mat_cor(Color(0.92, 0.88, 0.72)), false)
			_texto(plac, LINHAS[i][1], Vector3(0, 0, 0.02), 56, Color(0.12, 0.12, 0.1), 0.0038, HORIZONTAL_ALIGNMENT_CENTER, _fonte)
			_plac_quadro[LINHAS[i][2]] = plac
	_texto(_n67, "ÚLTIMO ÔNIBUS DA TEMPORADA · 18:00", Vector3(X_QUADRO, 0.9, Z_FACE + 0.065), 48, Color(0.95, 0.92, 0.8), 0.0036, HORIZONTAL_ALIGNMENT_CENTER, _fonte)
	_relogio(_n67, Vector3(X_GUICHE, 3.1, Z_FACE + 0.05), 5, 50, Color(0.92, 0.88, 0.74))

	# --- persiana do guichê (sobe quando as 3 plaquinhas voltam ao quadro) e o cartaz lá dentro
	_persiana = Node3D.new()
	_persiana.name = "Persiana"
	_persiana.position = Vector3(X_GUICHE, JY1, Z_FACE)
	_n67.add_child(_persiana)
	Construtor.caixa(_persiana, Vector3(JX1 - JX0, JY1 - JY0, 0.06), Vector3(0, -(JY1 - JY0) * 0.5, 0.045), _c(0.34, 0.4, 0.34), false, "Folha")
	_texto(_persiana, "FECHADO", Vector3(0, -0.5, 0.085), 70, Color(0.92, 0.9, 0.78), 0.0045)
	_texto(_persiana, "voltamos na próxima temporada", Vector3(0, -0.85, 0.085), 34, Color(0.92, 0.9, 0.78), 0.0028)
	_cartaz_dentro = Node3D.new()
	_cartaz_dentro.name = "CartazDentro"
	_cartaz_dentro.position = Vector3(X_GUICHE - 0.2, 1.68, Z_CAV + 0.03)
	_n67.add_child(_cartaz_dentro)
	Construtor.caixa(_cartaz_dentro, Vector3(0.62, 0.8, 0.01), Vector3.ZERO, Ato2Pecas.mat_cor(Color(0.92, 0.88, 0.7)), false, "Papel")
	_cartaz_dentro.rotation_degrees.z = -2.5
	_texto(_cartaz_dentro, "PROCURA-SE", Vector3(0, 0.28, 0.008), 70, Color(0.1, 0.08, 0.08), 0.0015)
	_texto(_cartaz_dentro, "TITO, 9 anos", Vector3(0, 0.14, 0.008), 48, Color(0.1, 0.08, 0.08), 0.0013)
	_texto(_cartaz_dentro, "desaparecido desde\n12/03/1967", Vector3(0, -0.04, 0.008), 34, Color(0.1, 0.08, 0.08), 0.0012)
	_texto(_cartaz_dentro, "Casa 7, Travessa das Conchas", Vector3(0, -0.26, 0.008), 26, Color(0.1, 0.08, 0.08), 0.0011)
	_texto(_n67, "14 MAR 1967", Vector3(X_GUICHE + 1.0, 1.35, Z_CAV + 0.025), 34, Color(0.12, 0.1, 0.08), 0.0034)
	_luz_guiche = Construtor.luz(_n67, Vector3(X_GUICHE, 2.1, Z_CAV + 1.0), Color(1.0, 0.82, 0.5), 0.0, 5.0)
	_luz_guiche.visible = false

	# --- cartazes de PROCURA-SE recém pregados (a mesma arte dos cartazes do Castelinho)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1967
	for p in [Vector3(-14.4, 1.65, Z_FACE + 0.03), Vector3(-0.2, 1.6, Z_FACE + 0.03), Vector3(12.0, 1.55, Z_FACE + 0.03),
			Vector3(-15.0, 1.6, -2.84), Vector3(11.0, 1.6, -2.84)]:
		TitoCastelinho.folha(_n67, "procura_se", p, 0.0, 0.52, 1, false, rng.randf_range(-3.5, 3.5))

	_fantasmas_1967()
	_plaquinhas()
	_interacoes_1967()


## Relógio redondo na parede (a face olha para +z). `h`/`mi` = a hora que mostra.
func _relogio(pai: Node3D, pos: Vector3, h: int, mi: int, cor_face: Color) -> void:
	var r := Node3D.new()
	r.name = "Relogio"
	r.position = pos
	pai.add_child(r)
	var aro := CylinderMesh.new()
	aro.top_radius = 0.44
	aro.bottom_radius = 0.44
	aro.height = 0.06
	aro.radial_segments = 20
	Ato2Pecas.malha(r, aro, Vector3.ZERO, Ato2Pecas.mat_cor(Color(0.14, 0.14, 0.14)), Vector3(90, 0, 0))
	var face := CylinderMesh.new()
	face.top_radius = 0.38
	face.bottom_radius = 0.38
	face.height = 0.06
	face.radial_segments = 20
	Ato2Pecas.malha(r, face, Vector3(0, 0, 0.012), Ato2Pecas.mat_cor(cor_face), Vector3(90, 0, 0))
	var tinta := Ato2Pecas.mat_cor(Color(0.1, 0.1, 0.1))
	for i in 4:
		var t := Node3D.new()
		t.position = Vector3(0, 0, 0.05)
		t.rotation_degrees.z = i * 90.0
		r.add_child(t)
		Construtor.caixa(t, Vector3(0.03, 0.07, 0.01), Vector3(0, 0.3, 0), tinta, false)
	var ang := [(h % 12) * 30.0 + mi * 0.5, mi * 6.0]
	var comp := [0.2, 0.31]
	for i in 2:
		var pivo := Node3D.new()
		pivo.position = Vector3(0, 0, 0.06 + i * 0.01)
		pivo.rotation_degrees.z = -float(ang[i])
		r.add_child(pivo)
		Construtor.caixa(pivo, Vector3(0.035 - i * 0.01, float(comp[i]), 0.01), Vector3(0, float(comp[i]) * 0.5, 0), tinta, false)


## Silhuetas escuras e translúcidas (gente que não está mais lá) e as malas delas. Sem rosto, sem colisão.
func _fantasmas_1967() -> void:
	_mat_fantasma = Ato2Pecas.mat_cor(Color(0.05, 0.06, 0.1, 0.62), true)
	var pessoa := Malha.new()
	pessoa.epocas = E67
	pessoa.caixa(_mat_fantasma, Vector3(-0.22, 0.0, -0.1), Vector3(0.22, 0.85, 0.1))
	pessoa.caixa(_mat_fantasma, Vector3(-0.27, 0.85, -0.14), Vector3(0.27, 1.45, 0.14))
	pessoa.caixa(_mat_fantasma, Vector3(-0.13, 1.47, -0.12), Vector3(0.13, 1.72, 0.12))
	var mesh_pessoa := pessoa.construir_malha()
	var chapeu := Malha.new()
	chapeu.epocas = E67
	chapeu.caixa(_mat_fantasma, Vector3(-0.22, 0.0, -0.1), Vector3(0.22, 0.85, 0.1))
	chapeu.caixa(_mat_fantasma, Vector3(-0.27, 0.85, -0.14), Vector3(0.27, 1.5, 0.14))
	chapeu.caixa(_mat_fantasma, Vector3(-0.13, 1.52, -0.12), Vector3(0.13, 1.74, 0.12))
	chapeu.caixa(_mat_fantasma, Vector3(-0.3, 1.74, -0.3), Vector3(0.3, 1.78, 0.3))
	var mesh_chapeu := chapeu.construir_malha()
	var grupo := Node3D.new()
	grupo.name = "Silhuetas"
	_n67.add_child(grupo)
	# fila no guichê (de frente para ele) e dois perto da porta do ônibus; um anda pela plataforma, outro pela beira da pista
	var def := [
		[Vector3(-1.5, 0.0, -8.0), Vector3(1, 0, 0), 0.1, 0.5, false], [Vector3(-0.8, 0.0, -7.0), Vector3(1, 0, 0), 0.12, 0.6, true],
		[Vector3(-1.2, 0.0, -6.0), Vector3(1, 0, 0), 0.1, 0.45, false],
		[Vector3(10.2, 0.0, -2.0), Vector3(1, 0, 0.3), 0.18, 0.7, true], [Vector3(12.0, 0.0, -2.3), Vector3(1, 0, 0.2), 0.14, 0.55, false],
		[Vector3(6.0, 0.0, -3.9), Vector3(1, 0, 0), 8.0, 0.2, true], [Vector3(-18.0, 0.0, -0.9), Vector3(1, 0, 0), 4.0, 0.28, false],
	]
	for i in def.size():
		var d: Array = def[i]
		var mi := MeshInstance3D.new()
		mi.name = "Silhueta%d" % i
		mi.mesh = mesh_chapeu if d[4] else mesh_pessoa
		mi.position = d[0]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		grupo.add_child(mi)
		_fantasmas.append({"no": mi, "base": d[0], "eixo": (d[1] as Vector3).normalized(), "amp": d[2], "vel": d[3], "fase": float(i) * 1.9})
	# as malas deles, tudo numa malha só
	var malas := Malha.new()
	malas.epocas = E67
	for caixa in [[-2.1, -8.0, 0.5, 0.34, 0.2], [-0.2, -7.4, 0.42, 0.5, 0.22], [-1.9, -6.2, 0.55, 0.3, 0.2], [9.9, -1.2, 0.5, 0.36, 0.2],
			[12.5, -1.3, 0.6, 0.4, 0.24], [15.9, -6.5, 0.5, 0.4, 0.3], [16.7, -6.0, 0.45, 0.32, 0.25], [16.2, -6.2, 0.4, 0.28, 0.4],
			[6.4, -8.0, 0.48, 0.34, 0.2], [-12.4, -6.0, 0.5, 0.34, 0.2]]:
		var y0: float = 0.3 if caixa[0] > 15.0 else 0.0
		malas.caixa(_mat_fantasma, Vector3(caixa[0] - caixa[2] * 0.5, y0, caixa[1] - caixa[4] * 0.5), Vector3(caixa[0] + caixa[2] * 0.5, y0 + caixa[3], caixa[1] + caixa[4] * 0.5))
	malas.construir_instancia(grupo, "MalasFantasma")


## As 3 plaquinhas brilhando de leve.
func _plaquinhas() -> void:
	for pid: String in PLACAS:
		var d: Dictionary = PLACAS[pid]
		var no := Node3D.new()
		no.name = "Plaquinha_" + pid
		no.position = d["pos"]
		no.rotation_degrees = Vector3(0, d["yaw"], d["roll"])
		_n67.add_child(no)
		var mat := Ato2Pecas.mat_cor(Color(1.0, 0.96, 0.7), true)
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		_mat_placas[pid] = mat
		var q := MeshInstance3D.new()
		var qm := QuadMesh.new()
		qm.size = Vector2(0.96, 0.27)
		q.mesh = qm
		q.material_override = mat
		no.add_child(q)
		_texto(no, LINHAS[int(d["linha"])][1], Vector3(0, 0, 0.004), 46, Color(0.1, 0.1, 0.08), 0.0038, HORIZONTAL_ALIGNMENT_CENTER, _fonte)
		var it := Interagivel.new("Pegar a plaquinha", Vector3(1.4, 1.2, 1.4), func(_p: Node) -> void: pegar_placa(pid))
		it.name = "Pegar"
		it.position = Vector3(0, 0.1, 0)
		no.add_child(it)
		_no_placas[pid] = no


func _interacoes_1967() -> void:
	_it_quadro = interagivel("Olhar o quadro de horários", Vector3(X_QUADRO, 1.9, Z_FACE + 0.5), Vector3(3.8, 2.3, 1.2), _acao_quadro)
	_it_guiche = interagivel("Olhar o guichê", Vector3(X_GUICHE, 1.7, Z_FACE + 0.5), Vector3(3.0, 1.6, 1.2), _acao_guiche)
	var it_mala := interagivel("Olhar a malinha", Vector3(1.2, 0.4, -4.4), Vector3(1.8, 1.0, 1.2),
		func(_p: Node) -> void: _falar("bentinho", ["Uma malinha de criança, bem pequena, ao pé do banco.", "Ao lado, um balde vermelho de praia. Ficou esperando junto com a mala."]))
	var it_bus := interagivel("Espiar o ônibus", Vector3(12.0, 1.3, -0.9), Vector3(2.6, 2.6, 1.4),
		func(_p: Node) -> void: _falar("bentinho", ["Um ônibus de linha antigo, parado na plataforma 1, com o motor desligado.", "É o último da temporada. Depois dele, a cidade esvazia até o próximo verão."]))
	for it in [_it_quadro, _it_guiche, it_mala, it_bus]:
		Epocas.marcar(it, E67)


## Casas ao fundo, para o fim da área nunca mostrar o vazio (sem colisão, longe da borda).
func _fundo_distante() -> void:
	var m := Malha.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var cores := [_c(0.62, 0.58, 0.5), _c(0.55, 0.6, 0.58), _c(0.66, 0.56, 0.5), _c(0.5, 0.52, 0.56), _c(0.7, 0.66, 0.55)]
	var n := 0
	var x := -34.0
	while x < 34.0:    # ao sul
		var larg := rng.randf_range(4.0, 7.0)
		m.caixa(cores[n % 5], Vector3(x + rng.randf_range(0.0, 0.3), -0.6, rng.randf_range(19.0, 24.0)), Vector3(x + larg - rng.randf_range(0.0, 0.3), rng.randf_range(4.0, 10.0), rng.randf_range(28.0, 33.0)), Malha.F_TODAS)
		x += larg + rng.randf_range(0.5, 2.5)
		n += 1
	var z := -24.0
	while z < 18.0:    # a oeste e a leste
		var larg := rng.randf_range(4.0, 7.0)
		m.caixa(cores[n % 5], Vector3(rng.randf_range(-33.0, -29.0), -0.6, z + rng.randf_range(0.0, 0.3)), Vector3(rng.randf_range(-43.0, -38.0), rng.randf_range(4.0, 9.0), z + larg - rng.randf_range(0.0, 0.3)), Malha.F_TODAS)
		m.caixa(cores[(n + 2) % 5], Vector3(rng.randf_range(29.0, 33.0), -0.6, z + rng.randf_range(0.0, 0.3)), Vector3(rng.randf_range(38.0, 43.0), rng.randf_range(4.0, 9.0), z + larg - rng.randf_range(0.0, 0.3)), Malha.F_TODAS)
		z += larg + rng.randf_range(0.5, 2.5)
		n += 1
	x = -34.0
	while x < 34.0:    # ao norte, atrás do prédio
		var larg := rng.randf_range(5.0, 8.0)
		m.caixa(cores[n % 5], Vector3(x, -0.6, rng.randf_range(-26.0, -23.0)), Vector3(x + larg, rng.randf_range(6.0, 13.0), rng.randf_range(-18.5, -16.5)), Malha.F_TODAS)
		x += larg + rng.randf_range(0.5, 2.0)
		n += 1
	m.construir_instancia(self, "FundoDistante")


# ============================================================================ tarefa
func _tarefa() -> void:
	Efeitos.subtitulo_lugar = {
		GameState.Epoca.E1967: "março de 1967 · fim da temporada\no último ônibus",
		GameState.Epoca.ESEMDATA: "março de 1967 · fim da temporada\no último ônibus",
		GameState.Epoca.E1950: "nada de especial aqui neste ano",
		GameState.Epoca.E1975: "nada de especial aqui neste ano",
		GameState.Epoca.E2019: "nada de especial aqui neste ano",
	}
	_epoca_vista = int(GameState.epoca)
	if GameState.flag("pista_" + PISTA):      # já resolvido numa visita anterior: tudo aberto, o portão conclui
		_restaurar_resolvido()
	else:
		_atualizar_objetivo()
		_boas_vindas()


func _boas_vindas() -> void:
	await get_tree().create_timer(1.5).timeout
	if not is_inside_tree() or _lendo:
		return
	await Guia.falar("bentinho", ["Rodoviária de Imbé. Tudo parado e vazio, ao fim de tarde.",
		"Aqui o Visor mostra março de 1967, o último ônibus da temporada. Aperte Q e escolha o disco de 1967 (tecla 2)."])


## O que o Mapa (M) mostra em "Agora:".
func _atualizar_objetivo() -> void:
	if lido:
		definir_objetivo("Volte ao portão (do lado de onde você chegou) para sair da rodoviária.")
	elif guiche_aberto:
		definir_objetivo("O guichê abriu: chegue na janela e leia o cartaz (E).")
	elif not visor_1967_visto:
		definir_objetivo("Aperte Q e escolha o disco de 1967 (tecla 2): olhe a rodoviária no último ônibus da temporada.")
	elif not _levadas.is_empty():
		definir_objetivo("Plaquinhas %d/3: leve as plaquinhas ao quadro de horários, na parede perto do guichê." % (_postas.size() + _levadas.size()))
	else:
		definir_objetivo("Plaquinhas %d/3: no Visor de 1967, ache as plaquinhas de destino que caíram do quadro de horários." % _postas.size())


func _falar(quem: String, linhas: Array) -> void:
	await Guia.falar(quem, linhas)


# --- plaquinhas
func placas_pegas() -> int:
	return _levadas.size() + _postas.size()


## Pega uma plaquinha achada no cenário (só existe em 1967). Devolve true se era nova.
func pegar_placa(pid: String) -> bool:
	if not PLACAS.has(pid) or pid in _levadas or pid in _postas:
		return false
	_levadas.append(pid)
	var no: Node3D = _no_placas.get(pid)
	if no != null:
		no.queue_free()
		_no_placas.erase(pid)
	Audio.sfx("pista", -6.0, 1.2)
	_t_dica = 0.0
	_atualizar_texto_quadro()
	_atualizar_objetivo()
	var n := placas_pegas()
	if n >= 3:
		_falar("bentinho", ["A última plaquinha: %s! Agora leve as três ao quadro de horários." % LINHAS[int(PLACAS[pid]["linha"])][1]])
	else:
		_falar("bentinho", ["Uma plaquinha do quadro de horários: %s. Faltam %d." % [LINHAS[int(PLACAS[pid]["linha"])][1], 3 - n]])
	return true


func _atualizar_texto_quadro() -> void:
	if _it_quadro == null:
		return
	if guiche_aberto:
		_it_quadro.texto_interacao = "Olhar o quadro de horários"
	elif _levadas.is_empty():
		_it_quadro.texto_interacao = "Olhar o quadro de horários"
	else:
		_it_quadro.texto_interacao = "Pendurar as plaquinhas (%d)" % _levadas.size()


## Interagir com o quadro de 1967: pendura o que o jogador leva; sem nada na mão, diz o que falta.
func _acao_quadro(_p: Node = null) -> void:
	if _levadas.is_empty():
		if guiche_aberto:
			_falar("bentinho", ["O quadro está completo de novo. Último ônibus: 18:00, para Porto Alegre."])
		elif _postas.is_empty():
			_falar("bentinho", ["O quadro de horários perdeu 3 plaquinhas de destino: TRAMANDAÍ, OSÓRIO e PORTO ALEGRE.",
				"Elas devem estar espalhadas pela rodoviária. Procure com o Visor ligado."])
		else:
			_falar("bentinho", ["Ainda faltam %d plaquinha(s). Continue procurando com o Visor ligado." % (3 - _postas.size())])
		return
	pendurar_placas()


func pendurar_placas() -> void:
	if _levadas.is_empty():
		return
	for pid in _levadas:
		_postas.append(pid)
		var plac: Node3D = _plac_quadro.get(pid)
		if plac:
			plac.visible = true
	_levadas.clear()
	_t_dica = 0.0
	Audio.sfx("clique", -2.0, 0.8)
	_atualizar_texto_quadro()
	if _postas.size() >= 3:
		_abrir_guiche()
	else:
		_atualizar_objetivo()
		_falar("taina", ["Plaquinha no lugar. Faltam %d." % (3 - _postas.size())])


# --- guichê
func _abrir_guiche(rapido := false) -> void:
	if guiche_aberto:
		return
	guiche_aberto = true
	_atualizar_texto_quadro()
	_atualizar_objetivo()
	if rapido:
		_persiana.scale.y = 0.05
		_luz_guiche.light_energy = 1.4
		_luz_guiche.visible = true
		return
	Audio.sfx("slide", -4.0, 0.7)
	var t := create_tween().set_parallel()
	t.tween_property(_persiana, "scale:y", 0.05, 1.6).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_luz_guiche.visible = true
	t.tween_property(_luz_guiche, "light_energy", 1.4, 1.6)
	t.chain().tween_callback(_voz_do_guiche)


## A mãe, só voz, na hora em que a persiana sobe.
func _voz_do_guiche() -> void:
	if not is_inside_tree():
		return
	Audio.sfx("sussurro", -14.0, 0.6)
	await Guia.falar("???", ["— Por favor, moço, deixa este cartaz no guichê.", "— O ônibus vai sair... Alguém viu meu filho?"])
	if not is_inside_tree() or lido:
		return
	await Guia.falar("bentinho", ["O guichê abriu! Tem um papel preso na parede de dentro. Chegue na janela e leia (E)."])


func _acao_guiche(_p: Node = null) -> void:
	if guiche_aberto:
		_ler_cartaz()
	else:
		_falar("bentinho", ["A persiana do guichê está fechada, com um papel: \"voltamos na próxima temporada\".",
			"Será que o quadro de horários ajuda? Faltam plaquinhas nele."])


func _guiche_hoje(_p: Node = null) -> void:
	_falar("bentinho", ["O guichê está fechado, de persiana baixada. Ninguém atende aqui há muito tempo.",
		"Será que o Visor mostra como era? Aperte Q e escolha o disco de 1967 (tecla 2)."])


func _ler_quadro_hoje(_p: Node = null) -> void:
	_falar("taina", ["O quadro de horários está tão desbotado que não dá para ler.",
		"Mas faltam pedaços... Tente o Visor no disco de 1967 (tecla 2)."])


# --- o cartaz
func _ler_cartaz() -> void:
	if _lendo or not guiche_aberto:
		return
	_lendo = true
	ui_cartaz = CartazUI.new()
	Flash.raiz().add_child.call_deferred(ui_cartaz)
	await ui_cartaz.terminou
	_lendo = false
	ui_cartaz = null
	if not is_inside_tree():
		return
	var nova: bool = await pista(PISTA)
	lido = true
	_liberar_saida()
	_atualizar_objetivo()
	if nova:
		Audio.sfx("pista", -4.0)
		await Guia.falar("bentinho", ["12 de março de 1967. É a data que está no cartaz."])
		await Guia.falar("taina", ["Então foi em 1967 que o Tito sumiu. Não foi em 2019."])
		await Guia.falar("bentinho", ["O Tito que o Visor mostra em 1975 e 2019 é só o que ficou dele por aqui."])
		await Guia.falar("taina", ["A mãe deixou o cartaz antes do último ônibus e ficou esperando. Vamos voltar ao portão."])


## Depois da pista, o portão "Voltar ao Castelinho" passa a concluir o lugar.
func _liberar_saida() -> void:
	if _portao == null:
		return
	var it := _portao.find_child("PortaoVolta", false, false) as Interagivel
	if it != null:
		it.texto_interacao = "Voltar ao Castelinho (rodoviária concluída)"
		it.acao = func(_p: Node) -> void: concluir()


func _restaurar_resolvido() -> void:
	for pid: String in PLACAS:
		_postas.append(pid)
		_plac_quadro[pid].visible = true
		(_no_placas[pid] as Node3D).queue_free()
	_no_placas.clear()
	_abrir_guiche(true)
	lido = true
	_liberar_saida()
	_atualizar_objetivo()


# ============================================================================ quadro a quadro
func _process(dt: float) -> void:
	_t += dt
	_animar(dt)
	var e := int(GameState.epoca)
	if e != _epoca_vista:
		_epoca_vista = e
		_ao_mudar_epoca(e)
	if e in E67:
		_t_voz -= dt
		if _t_voz <= 0.0:
			_t_voz = randf_range(7.0, 12.0)
			Audio.sfx("sussurro", -21.0 + randf() * 3.0, 0.62 + randf() * 0.12)      # vozes abafadas
	_dica_por_atraso(dt)


func _animar(_dt: float) -> void:
	if _mat_fantasma != null:
		_mat_fantasma.albedo_color.a = 0.56 + 0.1 * sin(_t * 1.7)
	if _n67 != null and _n67.visible:
		for d: Dictionary in _fantasmas:
			var no: Node3D = d["no"]
			var s: float = sin(_t * float(d["vel"]) + float(d["fase"]))
			no.position = (d["base"] as Vector3) + (d["eixo"] as Vector3) * s * float(d["amp"]) + Vector3(0, absf(s) * 0.03, 0)
		var k := 0.5 + 0.5 * sin(_t * 3.0)
		for pid: String in _mat_placas:
			(_mat_placas[pid] as StandardMaterial3D).albedo_color = Color(1.0, 0.95, 0.62).lerp(Color(1.0, 1.0, 1.0), k)


func _ao_mudar_epoca(e: int) -> void:
	if e in E67:
		if not visor_1967_visto:
			visor_1967_visto = true
			_t_dica = 0.0
			_atualizar_objetivo()
		if not _mae_falou and not lido:
			_mae_falou = true
			_primeira_voz()
	elif e != int(GameState.Epoca.E2020) and Efeitos.visor_ativo:
		Efeitos.legenda_visor("Tente o disco de 1967 (tecla 2).")


func _primeira_voz() -> void:
	await get_tree().create_timer(3.0).timeout
	if not is_inside_tree() or int(GameState.epoca) not in E67:
		_mae_falou = false      # fala na próxima vez que o jogador voltar a 1967
		return
	Audio.sfx("sussurro", -12.0, 0.6)
	await Guia.falar("???", ["— Alguém viu meu filho?"])


## Dica da Guia se o jogador demora (a cada DICA_ATRASO s sem progresso, no máximo MAX_DICAS).
func _dica_por_atraso(dt: float) -> void:
	if lido or _dicas >= MAX_DICAS or Guia.ocupado() or GameState.flag("ui_aberta"):
		return
	_t_dica += dt
	if _t_dica < DICA_ATRASO:
		return
	_t_dica = 0.0
	_dicas += 1
	if not visor_1967_visto:
		_falar("bentinho", ["Aperte Q para ligar o Visor e escolha o disco de 1967 (tecla 2). A rodoviária muda."])
	elif guiche_aberto:
		_falar("taina", ["O guichê está aberto. Chegue perto da janela e leia o cartaz que está lá dentro."])
	elif not _levadas.is_empty():
		_falar("taina", ["Você já tem plaquinhas na mão. Leve ao quadro de horários, na parede perto do guichê."])
	else:
		for pid: String in PLACAS:
			if not (pid in _postas) and not (pid in _levadas):
				_falar("taina", [str(PLACAS[pid]["dica"])])
				break


# ============================================================================ o cartaz na tela
## Folha escrita à mão (a mãe do Tito, só a letra dela): fecha com clique, toque, E, Espaço ou Enter.
class CartazUI extends CanvasLayer:
	signal terminou
	const MIN_LEITURA := 1.2
	const LARG := 600.0
	const ALT := 610.0
	var _feito := false
	var _t := 0.0
	var _fundo: ColorRect
	var _folha: Panel
	var _dica: Label

	func _ready() -> void:
		layer = 110
		process_mode = Node.PROCESS_MODE_ALWAYS
		_construir()
		Flash.abrir_ui()
		Audio.sfx("slide", -8.0, 0.9)
		_fundo.modulate.a = 0.0
		_folha.modulate.a = 0.0
		var pos := _folha.position
		_folha.position = pos + Vector2(0, 36)
		var t := create_tween().set_parallel()
		t.tween_property(_fundo, "modulate:a", 1.0, 0.4)
		t.tween_property(_folha, "modulate:a", 1.0, 0.5)
		t.tween_property(_folha, "position", pos, 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

	func _rot(pai: Control, texto: String, tam: int, fonte: Font, cor: Color, alinh := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
		var l := Label.new()
		l.text = texto
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = alinh
		l.add_theme_font_override("font", fonte)
		l.add_theme_font_size_override("font_size", maxi(tam, 14))
		l.add_theme_constant_override("outline_size", 0)
		l.add_theme_color_override("font_color", cor)
		l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pai.add_child(l)
		return l

	func _construir() -> void:
		_fundo = ColorRect.new()
		_fundo.color = Color(0.04, 0.035, 0.03, 0.94)
		_fundo.set_anchors_preset(Control.PRESET_FULL_RECT)
		_fundo.mouse_filter = Control.MOUSE_FILTER_STOP
		add_child(_fundo)
		_folha = Panel.new()
		_folha.anchor_left = 0.5
		_folha.anchor_right = 0.5
		_folha.anchor_top = 0.5
		_folha.anchor_bottom = 0.5
		_folha.offset_left = -LARG * 0.5
		_folha.offset_right = LARG * 0.5
		_folha.offset_top = -ALT * 0.5 - 12.0
		_folha.offset_bottom = ALT * 0.5 - 12.0
		_folha.pivot_offset = Vector2(LARG, ALT) * 0.5
		_folha.rotation = deg_to_rad(1.1)
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.92, 0.88, 0.72)
		sb.border_color = Color(0.5, 0.42, 0.28)
		sb.set_border_width_all(2)
		sb.shadow_color = Color(0, 0, 0, 0.55)
		sb.shadow_size = 16
		sb.shadow_offset = Vector2(5, 9)
		_folha.add_theme_stylebox_override("panel", sb)
		add_child(_folha)
		var alfinete := ColorRect.new()          # preso na parede por um alfinete
		alfinete.color = Color(0.62, 0.12, 0.1)
		alfinete.size = Vector2(16, 16)
		alfinete.position = Vector2(LARG * 0.5 - 8, 10)
		alfinete.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_folha.add_child(alfinete)
		var margem := MarginContainer.new()
		margem.set_anchors_preset(Control.PRESET_FULL_RECT)
		for lado in ["left", "right"]:
			margem.add_theme_constant_override("margin_" + lado, 36)
		margem.add_theme_constant_override("margin_top", 36)
		margem.add_theme_constant_override("margin_bottom", 20)
		margem.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_folha.add_child(margem)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 10)
		col.mouse_filter = Control.MOUSE_FILTER_IGNORE
		margem.add_child(col)
		var tinta := Color(0.1, 0.09, 0.14)
		var tit := Flash.fonte_titulo()
		var txt := Flash.fonte_texto()
		var T: Dictionary = TEXTO_PROCURA
		_rot(col, T["titulo"], 54, tit, Color(0.45, 0.07, 0.06))
		_rot(col, T["nome"], 36, tit, tinta)
		_rot(col, T["corpo"], 24, txt, tinta, HORIZONTAL_ALIGNMENT_LEFT)
		_rot(col, T["foto"], 23, txt, Color(0.32, 0.2, 0.14), HORIZONTAL_ALIGNMENT_LEFT)
		_rot(col, T["endereco"], 24, txt, tinta, HORIZONTAL_ALIGNMENT_LEFT)
		var vaz := Control.new()
		vaz.size_flags_vertical = Control.SIZE_EXPAND_FILL
		vaz.mouse_filter = Control.MOUSE_FILTER_IGNORE
		col.add_child(vaz)
		_rot(col, T["assina"], 30, txt, tinta, HORIZONTAL_ALIGNMENT_RIGHT)
		_rot(col, T["rodape"], 14, Flash.fonte_sistema(), Color(0.1, 0.09, 0.14, 0.55))
		_dica = Label.new()
		_dica.text = Celular.dica("Clique, E ou Espaço para fechar", "Toque para fechar")
		_dica.anchor_left = 0.5
		_dica.anchor_right = 0.5
		_dica.anchor_top = 1.0
		_dica.anchor_bottom = 1.0
		_dica.offset_left = -320.0
		_dica.offset_right = 320.0
		_dica.offset_top = -52.0
		_dica.offset_bottom = -16.0
		_dica.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_dica.add_theme_font_override("font", Flash.fonte_sistema())
		_dica.add_theme_font_size_override("font_size", 18)
		_dica.add_theme_color_override("font_color", Color(1, 1, 1, 0.8))
		_dica.modulate.a = 0.0
		_dica.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_dica)

	func _process(dt: float) -> void:
		if _feito:
			return
		_t += dt
		_dica.modulate.a = clampf((_t - MIN_LEITURA) * 2.0, 0.0, 1.0)

	func pode_fechar() -> bool:
		return not _feito and _t >= MIN_LEITURA

	func continuar() -> void:
		if _feito:
			return
		_feito = true
		Flash.fechar_ui()
		terminou.emit()
		var t := create_tween().set_parallel()
		t.tween_property(_folha, "modulate:a", 0.0, 0.25)
		t.tween_property(_fundo, "modulate:a", 0.0, 0.25)
		t.tween_property(_dica, "modulate:a", 0.0, 0.15)
		t.chain().tween_callback(queue_free)

	func _input(e: InputEvent) -> void:
		if _feito or not pode_fechar():
			return
		var avanca := false
		if e is InputEventKey and e.pressed and not e.echo:
			avanca = e.keycode in [KEY_E, KEY_SPACE, KEY_ENTER, KEY_KP_ENTER] or e.is_action_pressed("interagir") or e.is_action_pressed("avancar_dialogo")
		elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
			avanca = true
		elif e is InputEventScreenTouch and e.pressed:
			avanca = true
		if avanca:
			continuar()
			get_viewport().set_input_as_handled()
