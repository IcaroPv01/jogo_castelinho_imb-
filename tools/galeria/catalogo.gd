extends RefCounted
## Catálogo da galeria dos objetos 3D (lido por tools/galeria/fotografar.gd).
##
## Cada entrada diz: quem é o objeto, onde ele fica e COMO obtê-lo isolado ("fonte"):
##   no        fábrica que devolve um Node3D novo (criaturas, criar_*, Painel3D...)
##   nivel_no  nó que já existe no nível carregado (achado pelo nome) e é copiado
##   nivel_fn  função(nivel) -> Node3D (novo, ou vivo no nível: nesse caso é copiado)
##   crop      objeto FUNDIDO na malha do prédio/do nível: recorta os triângulos cujo centro cai na caixa (AABB do
##             código-fonte; coordenadas do mundo). "grupo" restringe a um nó do nível (ex.: "Museu_2020").
##   crop_sala o mesmo, dentro de uma sala do porão (caixa em coordenadas LOCAIS da sala; função(ctx) -> AABB)
## Campos opcionais: frente (graus: lado para onde o objeto "olha", 0 = +Z), ref (função(nivel) -> nó vivo para mirar
## na foto de local), colocar ({pos, yaw, sala}: põe uma cópia no nível só para a foto), pre (função(nivel, foto) a
## rodar antes), shader (bool: recorta também superfícies com ShaderMaterial, ex.: parede interna), dist (m).
## O jogo muda; os números abaixo vêm do código-fonte e a galeria só é tão boa quanto eles (ver "notas").

const NIVEIS := "res://world/niveis/"

## Cores de vértice da tocha de parede (ferro e chama): para tirar a tocha de dentro de outras caixas.
const TOCHA_CORES := [Color(0.1, 0.1, 0.11), Color(1.0, 0.55, 0.15)]

## Cenários: cada um carrega um nível numa visita/época. A ordem daqui é a ordem de execução.
const CEN := {
	"c_v1_hoje": {"cena": NIVEIS + "castelinho.tscn", "visita": 1, "epoca": 3, "malha": "castelinho"},
	"c_v2_hoje": {"cena": NIVEIS + "castelinho.tscn", "visita": 2, "epoca": 3, "malha": "castelinho"},
	"c_v3_hoje": {"cena": NIVEIS + "castelinho.tscn", "visita": 3, "epoca": 3, "malha": "castelinho"},
	"c_v3_1975": {"cena": NIVEIS + "castelinho.tscn", "visita": 3, "epoca": 1, "malha": "castelinho"},
	"c_v4_hoje": {"cena": NIVEIS + "castelinho.tscn", "visita": 4, "epoca": 3, "malha": "castelinho"},
	"c_v4_2019": {"cena": NIVEIS + "castelinho.tscn", "visita": 4, "epoca": 2, "malha": "castelinho"},
	"c_v1_1967": {"cena": NIVEIS + "castelinho.tscn", "visita": 1, "epoca": 4, "malha": "castelinho"},
	"c_v1_2019": {"cena": NIVEIS + "castelinho.tscn", "visita": 1, "epoca": 2, "malha": "castelinho"},
	"c_v1_1950": {"cena": NIVEIS + "castelinho.tscn", "visita": 1, "epoca": 0, "malha": "castelinho"},
	"ato2": {"cena": NIVEIS + "ato2.tscn", "visita": 3, "epoca": 3, "corr": 0.3},
	"barra": {"cena": NIVEIS + "barra.tscn", "visita": 2, "epoca": 3},
	"porao": {"cena": NIVEIS + "porao.tscn", "visita": 5, "epoca": 3, "novo_jogo": true, "comecar_visita": 5, "corr": 0.2, "preparar": "porao"},
	"porao_semdata": {"cena": NIVEIS + "porao.tscn", "visita": 5, "epoca": 5, "novo_jogo": true, "comecar_visita": 5, "corr": 0.2, "preparar": "porao"},
	"lago": {"cena": NIVEIS + "braco_morto.tscn", "visita": 5, "epoca": 5, "novo_jogo": true, "corr": 0.3},
}


# ====================================================================================== ajudantes
## Caixa por limites (x0, x1, y0, y1, z0, z1).
static func _c(x0: float, x1: float, y0: float, y1: float, z0: float, z1: float) -> AABB:
	return AABB(Vector3(minf(x0, x1), minf(y0, y1), minf(z0, z1)), Vector3(absf(x1 - x0), absf(y1 - y0), absf(z1 - z0)))


## "sala 21 (V1) · 43 (V2) · 65 (V3) · 87 (V4)" para uma sala base do Castelinho.
static func _salas(base: int) -> String:
	return "sala %d (V1) · %d (V2) · %d (V3) · %d (V4)" % [base, base + 22, base + 44, base + 66]


static func _e(id: String, nome: String, grupo: String, onde: String, arquivo: String, padrao: String, cen: String, fonte: Dictionary, extra := {}) -> Dictionary:
	var d := {"id": id, "nome": nome, "grupo": grupo, "onde": onde, "arquivo": arquivo, "padrao": padrao, "cen": cen, "fonte": fonte}
	d.merge(extra, true)
	return d


static func _no(f: Callable) -> Dictionary:
	return {"t": "no", "f": f}


static func _nn(nome: String) -> Dictionary:
	return {"t": "nivel_no", "nome": nome}


static func _nf(f: Callable) -> Dictionary:
	return {"t": "nivel_fn", "f": f}


## Objeto por etiqueta da Malha (castelinho/malha.gd): lista de "nome" exato ou "prefixo*".
static func _et(ets: Array, extra := {}) -> Dictionary:
	var d := {"t": "et", "et": ets}
	d.merge(extra, true)
	return d


static func _ponto(vistas: Array) -> Dictionary:
	return {"t": "ponto", "vistas": vistas}


static func _crop(caixa: AABB, grupo := "", extra := {}) -> Dictionary:
	var d := {"t": "crop", "caixa": caixa, "grupo": grupo}
	d.merge(extra, true)
	return d


static func _sala(idx: int, f: Callable, extra := {}) -> Dictionary:
	var d := {"t": "crop_sala", "idx": idx, "caixa": f}
	d.merge(extra, true)
	return d


static func _pai_com(f: Callable) -> Node3D:
	var n := Node3D.new()
	f.call(n)
	return n


## Painel3D / folha de papel: a "frente" é +Z.
static func _painel(id: String) -> Node3D:
	return Painel3D.new(id)


static func _recorte(tipo: String) -> Node3D:
	var raiz := Node3D.new()
	raiz.name = "Recorte_" + tipo
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = MobiliaCastelinho.textura_recorte(tipo)
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	mat.alpha_scissor_threshold = 0.5
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	var mat_verso := mat.duplicate() as StandardMaterial3D
	mat_verso.albedo_texture = MobiliaCastelinho.textura_recorte(tipo, true)
	var qm := QuadMesh.new()
	qm.size = Vector2(0.9, 1.8)
	var frente := MeshInstance3D.new()
	frente.mesh = qm
	frente.material_override = mat
	frente.position = Vector3(0, 0.95, 0.01)
	raiz.add_child(frente)
	var verso := MeshInstance3D.new()
	verso.mesh = qm
	verso.material_override = mat_verso
	verso.position = Vector3(0, 0.95, -0.01)
	verso.rotation_degrees.y = 180.0
	raiz.add_child(verso)
	var pe := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.05, 0.3)
	pe.mesh = bm
	pe.material_override = Castelinho.mat_tri("madeira_escura", Vector3(1, 1, 1))
	pe.position = Vector3(0, 0.025, 0)
	raiz.add_child(pe)
	return raiz


static func _por_classe(nv: Node, classe: String) -> Node3D:
	var l := nv.find_children("*", classe, true, false)
	return l[0] as Node3D if not l.is_empty() else null


static func _capim() -> Node3D:
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.14
	cone.height = 0.9
	cone.radial_segments = 5
	cone.rings = 1
	var raiz := Node3D.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for i in 5:
		var mi := MeshInstance3D.new()
		mi.mesh = cone
		mi.material_override = Ato2Pecas.mat_cor(Color(0.56, 0.53, 0.30))
		var s := rng.randf_range(0.8, 1.5)
		mi.scale = Vector3(s, s, s)
		mi.position = Vector3(rng.randf_range(-0.25, 0.25), 0.45 * s, rng.randf_range(-0.25, 0.25))
		mi.rotation = Vector3(rng.randf_range(-0.15, 0.15), rng.randf() * TAU, rng.randf_range(-0.15, 0.15))
		raiz.add_child(mi)
	return raiz


static func _folha_costela() -> Node3D:
	# o Sprite3D do nível, montado a seco (a função do nível é de instância)
	var img := Image.create(48, 48, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))
	var verde := Color(0.13, 0.5, 0.2)
	var escuro := Color(0.06, 0.3, 0.12)
	for y in 48:
		for x in 48:
			var dx := (x - 24.0) / 22.0
			var dy := (y - 22.0) / 20.0
			if dx * dx + dy * dy < 1.0:
				img.set_pixel(x, y, verde)
	for k in 4:
		for t in 10:
			img.set_pixel(24 + t, 10 + k * 9, Color(0, 0, 0, 0))
			img.set_pixel(24 - t, 12 + k * 9, Color(0, 0, 0, 0))
	for t in 20:
		img.set_pixel(24, 22 + t, escuro)
	var s := Sprite3D.new()
	s.name = "FolhaCostelaDeAdao"
	s.texture = ImageTexture.create_from_image(img)
	s.pixel_size = 0.009
	s.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	s.alpha_cut = SpriteBase3D.ALPHA_CUT_DISCARD
	s.double_sided = true
	var raiz := Node3D.new()
	raiz.add_child(s)
	return raiz


static func _costela_cipo() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.name = "CostelaCipo"
	mi.mesh = Costela.malha_variante(1)
	mi.material_override = Costela.material()
	var raiz := Node3D.new()
	raiz.add_child(mi)
	return raiz


static func _figura() -> Node3D:
	var f := FiguraBranca.new()
	f.somente_visual = true
	f.som_ativo = false
	return f


static func _menino(sentado: bool) -> Node3D:
	var pai := Node3D.new()
	PoraoQuarto.menino(pai, Vector3.ZERO, 0.0, sentado, true)
	return pai


static func _figura_slide() -> Node3D:
	var pai := Node3D.new()
	PoraoQuarto._figura_slide(pai, Vector3.ZERO)
	return pai


static func _rede() -> Node3D:
	var mat: StandardMaterial3D = Ato2Pecas.mat_cor(Color(0.06, 0.05, 0.07, 0.6), true)
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	var malha := CylinderMesh.new()
	malha.top_radius = 0.03
	malha.bottom_radius = 0.9
	malha.height = 0.5
	malha.radial_segments = 14
	malha.rings = 1
	malha.cap_top = false
	malha.cap_bottom = false
	var raiz := Node3D.new()
	raiz.name = "Rede"
	Ato2Pecas.malha(raiz, malha, Vector3.ZERO, mat).name = "Rede"
	return raiz


static func _sandalia() -> Node3D:
	var s := Node3D.new()
	s.name = "Sandalia"
	var sola := Ato2Pecas.mat_cor(Color(0.3, 0.52, 0.9))
	var tira := Ato2Pecas.mat_cor(Color(0.95, 0.8, 0.2))
	Construtor.caixa(s, Vector3(0.09, 0.025, 0.2), Vector3(0, 0.0125, 0), sola, false)
	Construtor.caixa(s, Vector3(0.09, 0.012, 0.03), Vector3(0, 0.032, -0.02), tira, false)
	Construtor.caixa(s, Vector3(0.035, 0.012, 0.09), Vector3(0.0, 0.032, 0.03), tira, false)
	return s


static func _bloco_molhe() -> Node3D:
	var bm := BoxMesh.new()
	bm.size = Vector3(1.2, 1.0, 1.4)
	var mi := MeshInstance3D.new()
	mi.mesh = bm
	mi.material_override = Ato2Pecas.mat_tri("pedra_molhe", Color(0.55, 0.5, 0.5), Ato2Pecas.tex_piso_pedra(), 0.5)
	mi.rotation_degrees = Vector3(8, 25, -6)
	var raiz := Node3D.new()
	raiz.add_child(mi)
	return raiz


static func _pinheiro() -> Node3D:
	var mi := MeshInstance3D.new()
	mi.mesh = EntornoCastelinho._pinus_mesh(0)
	var raiz := Node3D.new()
	raiz.add_child(mi)
	return raiz


static func _pegada() -> Node3D:
	var raiz := Node3D.new()
	raiz.add_child(Pegada.criar(Vector3.ZERO, Vector3(0, 0, -1), true, 0.3, 1.35))
	return raiz


static func _balde_com_sandalia() -> Node3D:
	var b := TitoCastelinho.criar_balde(1.4)
	var s := _sandalia()
	s.position = Vector3(0.02, 0.1, 0.24)
	s.rotation_degrees = Vector3(0, 35, 8)
	b.add_child(s)
	return b


## Pelo menos um nó filho achado por nome (padrão curinga), ou null.
static func _filho(nv: Node, padrao: String) -> Node3D:
	var l := nv.find_children(padrao, "", true, false)
	return l[0] as Node3D if not l.is_empty() else null


static func _fundo_lago(nv: Node) -> Node3D:
	nv._pecas_do_fundo(Vector3(0.0, -40.0, 0.0))
	return nv.get_node("FundoDoLago")


static func _mao(nv: Node) -> Node3D:
	var n: Node3D = nv._mao_longa(Vector3(0, -60.0, 0), Vector3(0, -61.2, -1.4))
	var d := n.duplicate() as Node3D
	n.queue_free()
	return d


# ====================================================================================== a lista
static func lista() -> Array:
	var L: Array = []
	L.append_array(_castelo_museu())
	L.append_array(_castelo_externo())
	L.append_array(_castelo_1975())
	L.append_array(_castelo_nos())
	L.append_array(_castelo_paineis())
	L.append_array(_castelo_1967())
	L.append_array(_castelo_ato2())
	L.append_array(_barra())
	L.append_array(_porao())
	L.append_array(_lago())
	L.append_array(_criaturas())
	L.append_array(_duvidas_pontos())
	return L


# ---------------------------------------------------------------------------------------- castelo: museu (2020)
## Agora por etiqueta da Malha (o outro agente etiquetou cada objeto do Castelinho): pega o objeto inteiro e só ele.
static func _castelo_museu() -> Array:
	var M := "castelinho/mobilia.gd"
	var cen := "c_v1_hoje"
	var med := _salas(21)
	var A: Array = []
	A.append(_e("cavalete", "Cavalete com tela", "castelo", "Hall e Salão de Arte (galeria de quadros), " + _salas(7) + "; hoje (2020)", M, "static func _cavalete", cen,
		_et(["cavalete_1"]), {"frente": 0.0, "dist": 2.2}))
	A.append(_e("mesa_acervo", "Mesa do acervo com máquina de escrever e livros", "castelo", "Acervo, " + _salas(12) + "; hoje (2020)", M, "# --- Acervo (metade leste)", cen,
		_et(["mesa_acervo", "maquina_escrever_acervo", "livros_acervo"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("vitrine_discos", "Vitrine de discos do Acervo", "castelo", "Canto do Acervo, " + _salas(12) + "; hoje (2020). O disco de 1967 fica em cima, a partir da visita 2", M, "# vitrine de discos no canto", cen,
		_et(["vitrine_discos_acervo"]), {"frente": 0.0, "dist": 2.4}))
	A.append(_e("mesa_corredor", "Mesa do corredor da Secretaria", "castelo", "Corredor da Secretaria, ponta leste, " + _salas(10) + "; hoje (2020)", M, "cx(g, madeira, Vector3(-6.2, 0.4, -22.5)", cen,
		_et(["mesa_corredor"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("mural_pescador", "Mural do pescador", "castelo", "Sala do Pescador, " + _salas(13) + "; hoje (2020)", M, "# --- Sala do Pescador: mural", cen,
		_et(["mural_pescador"]), {"frente": 180.0, "dist": 3.4}))
	A.append(_e("praia_conchas", "Faixa de areia com conchas, tartaruga e boto de pano", "castelo", "Sala do Pescador, " + _salas(13) + "; hoje (2020)", M, "# conchas, tartaruga e boto", cen,
		_et(["faixa_areia_pescador", "corda_amarela_pescador", "concha_pescador_*", "tartaruga_pescador", "boto_de_pano_pescador"]), {"frente": 180.0, "dist": 3.2}))
	A.append(_e("banco_baixo_pescador", "Banco baixo de madeira (Sala do Pescador)", "castelo", "Sala do Pescador, " + _salas(13) + "; hoje (2020)", M, "# bancos baixos de madeira", cen,
		_et(["banco_baixo_pescador"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("vitrine_conchas", "Vitrine longa de conchas (sambaqui)", "castelo", "Sala dos Povos Originários, " + _salas(8) + "; hoje (2020)", M, "# --- Povos Originários", cen,
		_et(["vitrine_povos_base", "vitrine_povos_vidro", "sambaqui_concha_*"]), {"frente": 0.0}))
	A.append(_e("banco_povos", "Banco baixo de madeira (Sala dos Povos)", "castelo", "Sala dos Povos Originários, " + _salas(8) + "; hoje (2020)", M, "cx(g, madeira, Vector3(-23.4, 0.3, -14.3)", cen,
		_et(["banco_povos"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("vertebra_baleia", "Vértebra de baleia", "castelo", "Sala do Meio Ambiente, " + _salas(9) + "; hoje (2020)", M, "# vértebra de baleia", cen,
		_et(["vertebra_baleia", "faixa_areia_meio_ambiente"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("banner_ambiental", "Banner de educação ambiental", "castelo", "Sala do Meio Ambiente, parede oeste, " + _salas(9) + "; hoje (2020)", M, "# banner enrolável", cen,
		_et(["banner_ambiental"]), {"frente": 90.0, "dist": 3.0}))
	A.append(_e("planta_vaso", "Planta no vaso", "castelo", "Corredor da Secretaria, ponta leste, perto da " + _salas(12) + "; hoje (2020)", M, "# planta no vaso (corredor)", cen,
		_et(["vaso_planta_corredor", "folhagem_planta_corredor"]), {"frente": 0.0, "dist": 2.4}))
	A.append(_e("lareira", "Lareira da Sala Medieval (com capelo)", "castelo", "Sala Medieval, parede norte, " + med + "; hoje (2020)", M, "# lareira (parede norte", cen,
		_et(["lareira_medieval"]), {"frente": 0.0, "dist": 3.8}))
	A.append(_e("escudo_machados", "Escudo redondo com machados cruzados", "castelo", "Sala Medieval, sobre a lareira, " + med + "; hoje (2020)", M, "_machados(g, Vector3(-14.2", cen,
		_et(["escudo_redondo_-142_25", "machados_cruzados_-142"]), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("brasao_aguia", "Brasão com águia", "castelo", "Sala Medieval, parede norte, " + med + "; hoje (2020)", M, "static func _brasao", cen,
		_et(["brasao_aguia"]), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("espadas_escudo", "Espadas cruzadas com escudo redondo", "castelo", "Sala Medieval, parede norte, " + med + "; hoje (2020)", M, "static func _espadas", cen,
		_et(["espadas_cruzadas_-90", "escudo_redondo_-90_20"]), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("lancas_parede", "Lanças na parede", "castelo", "Sala Medieval, parede sul, " + med + "; hoje (2020)", M, "# lanças e estandartes", cen,
		_et(["lanca_medieval_*"]), {"frente": 180.0, "dist": 4.0}))
	A.append(_e("trono", "Trono de madeira", "castelo", "Sala Medieval, lado leste, " + med + "; hoje (2020)", M, "# tronos (dois)", cen,
		_et(["trono_medieval_1"]), {"frente": 270.0, "dist": 3.0}))
	A.append(_e("mesa_medieval", "Mesa grande com cadeiras", "castelo", "Sala Medieval, centro, " + med + "; hoje (2020)", M, "# mesa grande com cadeiras", cen,
		_et(["mesa_grande_medieval", "cadeira_medieval_*"]), {"frente": 90.0, "dist": 3.8, "duvidas": ["cadeira_medieval_2_n"]}))
	A.append(_e("cadeira_medieval", "Cadeira da mesa medieval", "castelo", "Sala Medieval, em volta da mesa grande, " + med + "; hoje (2020)", M, "# mesa grande com cadeiras", cen,
		_et(["cadeira_medieval_1_n"]), {"frente": 0.0, "dist": 2.4}))
	A.append(_e("tocha_parede", "Tocha de parede (arandela)", "castelo", "Sala Medieval, ao lado da porta de saída, " + med + "; hoje (2020)", M, "# tochas (arandelas)", cen,
		_et(["tocha_medieval_11"]), {"frente": 0.0, "dist": 2.4}))
	A.append(_e("bau_madeira", "Baú de madeira", "castelo", "Sala Medieval, " + med + "; hoje (2020)", M, "# baú de ferro", cen,
		_et(["bau_medieval"]), {"frente": 90.0, "dist": 2.4}))
	return A


# ---------------------------------------------------------------------------------------- castelo: exterior e interior geral
static func _castelo_externo() -> Array:
	var cen := "c_v1_hoje"
	var E := "castelinho/extras.gd"
	var A: Array = []
	A.append(_e("lustre_ferro", "Lustre de ferro", "castelo", "Teto do Salão de Arte (e de quase todas as salas), " + _salas(11), "castelinho/interior.gd", "static func lustre", cen,
		_et(["lustre_ambiente_4"]), {"frente": 0.0, "dist": 3.4}))
	A.append(_e("mesa_pedra", "Mesa de pedra com bancos", "castelo", "Gramado, lado oeste do jardim, " + _salas(2) + "; hoje (2020)", "castelinho/interior.gd", "static func _bancos_de_pedra", cen,
		_et(["mesa_pedra_jardim", "banco_pedra_jardim_*"]), {"frente": 0.0, "dist": 5.5}))
	A.append(_e("churrasqueira", "Churrasqueira de pedra", "castelo", "Gramado, lado oeste do jardim, " + _salas(2) + "; hoje (2020)", "castelinho/interior.gd", "# churrasqueira de pedra", cen,
		_et(["churrasqueira_pedra"]), {"frente": 0.0, "dist": 4.5}))
	A.append(_e("arvore_jardim", "Árvore retorcida do jardim", "castelo", "Jardim diante do prédio, " + _salas(2) + "; hoje, 1975 e 2019", "castelinho/entorno.gd", "arvore_retorcida_jardim", cen,
		_et(["arvore_retorcida_jardim"]), {"frente": 0.0, "dist": 8.0}))
	A.append(_e("lixeira_jardim", "Lixeira de madeira", "castelo", "Jardim, perto do deck, " + _salas(4), "castelinho/entorno.gd", "lixeira_madeira_jardim", cen,
		_et(["lixeira_madeira_jardim"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("pergola_deck", "Pérgola do deck de madeira", "castelo", "Deck, " + _salas(4) + "; hoje (2020) e 2019", E, "static func _deck", cen,
		_et(["pergola_poste_*", "pergola_vigas", "deck_madeira"]), {"frente": 0.0, "dist": 10.0}))
	A.append(_e("guarda_sol", "Guarda-sol preto do deck", "castelo", "Deck de madeira, " + _salas(4) + "; hoje (2020)", E, "# guarda-sóis pretos", cen,
		_et(["guarda_sol_deck_1"]), {"frente": 0.0, "dist": 5.0}))
	A.append(_e("cerca_corda", "Cerca de corda trançada (trecho)", "castelo", "Frente do lote, ao longo da calçada, " + _salas(1) + "; hoje (2020)", E, "static func _corda", cen,
		_et(["cerca_corda_1", "cerca_corda_2", "cerca_corda_poste_1", "cerca_corda_poste_2", "cerca_corda_poste_3"]), {"frente": 0.0, "dist": 5.0}))
	A.append(_e("hortensia", "Hortênsia", "castelo", "Jardim em volta do prédio, " + _salas(3) + "; hoje (2020)", E, "static func _hortensias", cen,
		_et(["hortensia_9"]), {"frente": 90.0, "dist": 3.4}))
	A.append(_e("placa_casa_cultura", "Placa da Casa de Cultura e Museu", "castelo", "Arcada da fachada sul, " + _salas(5) + "; hoje (2020)", E, "static func _letreiros", cen,
		_et(["placa_casa_de_cultura"], {"rotulos": _c(-12.8, -10.6, 2.55, 3.3, -11.1, -10.8)}), {"frente": 0.0, "dist": 4.0}))
	A.append(_e("letreiro_castelinho", "Letreiro 'Castelinho' da fachada leste", "castelo", "Fachada leste, voltada para a Av. Nilza, " + _salas(1) + "; hoje (2020)", E, "static func _letreiros", cen,
		_et(["letreiro_castelinho_leste"]), {"frente": 90.0, "dist": 6.0}))
	A.append(_e("porta_vidro", "Porta de vidro da entrada", "castelo", "Arco de entrada, " + _salas(6) + "; hoje (2020)", E, "static func _porta_entrada", cen,
		_nf(func(nv): return nv.castelo.porta_entrada), {"frente": 0.0, "dist": 4.0}))
	A.append(_e("porta_secretaria", "Porta da Secretaria (com plaquinha)", "castelo", "Corredor da Secretaria, " + _salas(10) + "; hoje (2020)", "castelinho/mobilia.gd", "# corredor da Secretaria: portas com plaquinhas", cen,
		_et(["porta_secretaria_2"]), {"frente": 180.0, "dist": 3.2}))
	A.append(_e("poste_luz", "Poste de luz da rua", "castelo", "Calçada da Av. Garibaldi, esquina do lote; vale em todas as visitas", "castelinho/entorno.gd", "static func _postes", cen,
		_et(["poste_luz_1"]), {"frente": 0.0, "dist": 11.0}))
	A.append(_e("moita_cerca_viva", "Moita da cerca-viva", "castelo", "Cerca-viva baixa ao longo da Av. Nilza, lado leste do lote", "castelinho/entorno.gd", "# cerca-viva baixa ao longo da Nilza", cen,
		_et(["moita_nilza_30_1", "moita_nilza_30_2"]), {"frente": 90.0, "dist": 3.4}))
	A.append(_e("casa_vizinha_17", "Casa vizinha (alvenaria)", "castelo", "Terreno ao norte do lote, no eixo do corredor de 1975 (são 18 casas vizinhas)", "castelinho/entorno.gd", "static func _casas", cen,
		_et(["casa_vizinha_17"]), {"frente": 0.0, "dist": 22.0, "duvidas": ["casa_vizinha_17", "corredor_1975"]}))
	A.append(_e("pinheiro", "Pinheiro (pinus)", "castelo", "Fundos e oeste do lote (dezenas deles, 3 variações)", "castelinho/entorno.gd", "static func _pinus_mesh", cen,
		_no(func(): return _pinheiro()), {"colocar": {"pos": Vector3(-27.0, 0.0, -2.0)}, "dist": 14.0,
		"notas": ["no jogo é MultiMesh (3 variações); aqui a variação 0"]}))
	return A


# ---------------------------------------------------------------------------------------- castelo: casa de veraneio (1975)
static func _castelo_1975() -> Array:
	var M := "castelinho/mobilia.gd"
	var cen := "c_v3_1975"
	var onde := "Sala Medieval, que em 1975 era sala de estar, " + _salas(21) + "; só na época 1975"
	var A: Array = []
	A.append(_e("sofa_1975", "Sofá de braços com almofadas (1975)", "castelo", onde, M, "# sofá (encosto na parede norte)", cen,
		_et(["sofa_1975"]), {"frente": 0.0, "dist": 3.8}))
	A.append(_e("poltrona_1975", "Poltrona com pés (1975)", "castelo", onde, M, "# poltronas", cen,
		_et(["poltrona_1975_oeste"]), {"frente": 90.0, "dist": 2.8}))
	A.append(_e("mesa_centro_1975", "Mesa de centro de pés palito (1975)", "castelo", onde, M, "# mesa de centro de pés palito", cen,
		_et(["mesa_centro_1975", "cinzeiro_mesa_centro_1975", "vaso_mesa_centro_1975"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("estante_1975", "Estante com livros e rádio (1975)", "castelo", onde, M, "# estante na parede oeste", cen,
		_et(["estante_1975", "radio_estante_1975"]), {"frente": 90.0, "dist": 3.4}))
	A.append(_e("abajur_1975", "Abajur de pé (1975)", "castelo", onde, M, "# abajur de pé", cen,
		_et(["abajur_1975"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("tv_1975", "Televisão de madeira (1975)", "castelo", onde, M, "# TV de madeira", cen,
		_et(["tv_1975"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("quadro_por_do_sol", "Quadro de pôr do sol (1975)", "castelo", onde, M, "# quadro de pôr do sol", cen,
		_et(["quadro_por_do_sol_1975"]), {"frente": 0.0, "dist": 3.4}))
	A.append(_e("cadeira_palha_1975", "Cadeira de palha (1975)", "castelo", onde, M, "cadeira de palha", cen,
		_et(["cadeira_palha_1975"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("tapete_1975", "Tapete vermelho com barra (1975)", "castelo", onde, M, "g.inte.quad(Castelinho.mat_cor(Color(0.45, 0.14, 0.1)", cen,
		_et(["tapete_1975", "tapete_barra_1975"]), {"frente": 90.0, "dist": 3.6}))
	A.append(_e("praia_1975", "Guarda-sol dobrado e prancha de praia (1975)", "castelo", onde, M, "# bilhete de praia", cen,
		_et(["guarda_sol_dobrado_1975", "prancha_praia_1975"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("banco_hall_1975", "Banco do hall (1975)", "castelo", "Hall da casa de veraneio, " + _salas(7) + "; só na época 1975", M, "# corredor/hall: banco e cabideiro", cen,
		_et(["banco_hall_1975"]), {"frente": 0.0, "dist": 2.8}))
	A.append(_e("cabideiro_1975", "Cabideiro do hall (1975)", "castelo", "Hall da casa de veraneio, " + _salas(7) + "; só na época 1975", M, "# corredor/hall: banco e cabideiro", cen,
		_et(["cabideiro_hall_1975"]), {"frente": 0.0, "dist": 2.8}))
	A.append(_e("caixas_pesca_1975", "Rede de pesca e caixa verde (1975)", "castelo", "Sala do Pescador em 1975, " + _salas(13), M, "# Sala do Pescador em 1975", cen,
		_et(["caixa_rede_pesca_1975", "caixa_verde_pescador_1975"]), {"frente": 0.0, "dist": 3.4}))
	return A


# ---------------------------------------------------------------------------------------- castelo: objetos que são nós
static func _castelo_nos() -> Array:
	var M := "castelinho/mobilia.gd"
	var T := "castelinho/tito.gd"
	var N := "world/niveis/castelinho.gd"
	var A: Array = []
	A.append(_e("pinguim", "Pinguim empalhado", "castelo", "Sala do Meio Ambiente, " + _salas(9) + "; hoje (2020). Os olhos seguem o jogador a partir da visita 3", M, "static func criar_pinguim", "c_v1_hoje",
		_no(func(): return MobiliaCastelinho.criar_pinguim()), {"frente": 0.0, "ref": func(nv): return nv._pinguim, "dist": 2.6}))
	A.append(_e("telefone_acervo", "Telefone antigo de disco", "castelo", "Mesa do Acervo, " + _salas(12) + "; hoje (2020). Toca na visita 2", M, "static func criar_telefone", "c_v1_hoje",
		_no(func(): return MobiliaCastelinho.criar_telefone()), {"frente": 0.0, "ref": func(nv): return nv.find_child("Telefone", true, false), "dist": 2.4}))
	A.append(_e("armadura", "Armadura de ferro", "castelo", "Trono do fundo da Sala Medieval, " + _salas(21) + "; só aparece na visita 3", M, "static func criar_armadura", "c_v3_hoje",
		_no(func(): return MobiliaCastelinho.criar_armadura()), {"frente": 0.0, "pre": func(nv, _f): nv._armadura.visible = true, "ref": func(nv): return nv._armadura, "dist": 3.4}))
	A.append(_e("recorte_visitante", "Recorte de papelão: visitante", "castelo", "Gramado diante da fachada, virado para a parede, " + _salas(3) + "; hoje (2020)", N, "func _recorte(", "c_v1_hoje",
		_no(func(): return _recorte("visitante")), {"frente": 0.0, "ref": func(nv): return nv._recortes["visitante"], "dist": 3.4,
		"notas": ["no jogo este fica virado para a parede: o jogador só vê o verso de papelão"]}))
	A.append(_e("recorte_pescador", "Recorte de papelão: pescador", "castelo", "Acervo, " + _salas(12) + "; aparece na visita 2 em diante", N, "func _recorte(", "c_v1_hoje",
		_no(func(): return _recorte("pescador")), {"frente": 180.0, "pre": func(nv, _f): nv._recortes["pescador"].visible = true, "ref": func(nv): return nv._recortes["pescador"], "dist": 3.0}))
	A.append(_e("recorte_quico", "Recorte de papelão: Quico", "castelo", "Torre B, 2º andar, " + _salas(19) + "; aparece na visita 2 em diante", N, "func _recorte(", "c_v1_hoje",
		_no(func(): return _recorte("quico")), {"frente": 180.0, "pre": func(nv, _f): nv._recortes["quico"].visible = true, "ref": func(nv): return nv._recortes["quico"], "dist": 3.0}))
	A.append(_e("passaporte_pedra", "Pedra velha do Passaporte", "castelo", "Perto do deck e da arcada, " + _salas(4) + "; só na visita 1 (caça ao Passaporte)", N, "func _modelo_passaporte", "c_v1_hoje",
		_nf(func(nv): return nv._modelo_passaporte("pedra")), {"ref": func(nv): return nv.find_child("Passaporte_pedra", true, false), "dist": 2.4}))
	A.append(_e("passaporte_foto", "Foto antiga do Passaporte", "castelo", "Sala dos Povos Originários, " + _salas(8) + "; só na visita 1", N, "func _modelo_passaporte", "c_v1_hoje",
		_nf(func(nv): return nv._modelo_passaporte("foto")), {"ref": func(nv): return nv.find_child("Passaporte_foto", true, false), "dist": 2.2}))
	A.append(_e("passaporte_chave", "Chave velha do Passaporte", "castelo", "Sala do Meio Ambiente, perto do pinguim, " + _salas(9) + "; só na visita 1", N, "func _modelo_passaporte", "c_v1_hoje",
		_nf(func(nv): return nv._modelo_passaporte("chave")), {"ref": func(nv): return nv.find_child("Passaporte_chave", true, false), "dist": 2.2}))
	A.append(_e("folha_costela", "Folha de costela-de-Adão (no painel P02)", "castelo", "Brotando no canto do painel P02, " + _salas(2) + "; hoje (2020)", N, "func _folha_costela", "c_v1_hoje",
		_no(func(): return _folha_costela()), {"ref": func(nv): return nv.find_child("FolhaCostelaDeAdao", true, false), "dist": 2.4,
		"notas": ["é um Sprite3D (imagem de 48 px sempre virada para a câmera): o .glb não leva a folha"]}))
	A.append(_e("disco_1967", "Disco do Visor (1967)", "castelo", "Vitrine de discos do Acervo, " + _salas(12) + "; a partir da visita 2, até ser pego", T, "static func criar_disco", "c_v2_hoje",
		_no(func(): return TitoCastelinho.criar_disco(Color(0.85, 0.12, 0.1))), {"ref": func(nv): return nv._discos_chao[4][0], "dist": 1.6}))
	A.append(_e("disco_1975", "Disco do Visor (1975)", "castelo", "Pedestal no topo da Torre A, " + _salas(17) + "; a partir da visita 3, até ser pego", T, "static func criar_disco", "c_v3_hoje",
		_no(func(): return TitoCastelinho.criar_disco(Color(0.95, 0.65, 0.12))), {"ref": func(nv): return nv._discos_chao[1][0], "dist": 1.6}))
	A.append(_e("balde_sandalia_trono", "Balde vermelho com a sandália", "castelo", "Trono da Sala Medieval, depois do apagão da visita 2 (fica nas visitas 3 e 4), " + _salas(21), T, "static func criar_balde", "c_v2_hoje",
		_nf(func(nv): return nv._balde), {"pre": func(nv, _f): nv._criar_balde_e_desenho3(), "ref": func(nv): return nv._balde, "dist": 2.4}))
	A.append(_e("pegada_molhada", "Pegada molhada de criança", "castelo", "Sala do Pescador, diante do mural, " + _salas(13) + "; hoje (2020), só na visita 4", "world/pegada.gd", "static func criar", "c_v4_hoje",
		_no(func(): return _pegada()), {"pre": func(nv, _f): nv._pegadas_v4.visible = true, "ref": func(nv): return nv._pegadas_v4.get_child(3), "dist": 1.8}))
	A.append(_e("fita_zebrada_reforma", "Fitas zebradas e placa EM REFORMA", "castelo", "Porta de saída da Sala Medieval, " + _salas(22) + "; hoje (2020), visitas 3 e 4", N, "func _fita_zebrada", "c_v3_hoje",
		_nn("FitaZebrada"), {"frente": 0.0, "dist": 3.2}))
	A.append(_e("pedestal_disco", "Pedestal de madeira do disco 1975", "castelo", "Topo da Torre A, " + _salas(17) + "; hoje (2020), visita 3, até pegar o disco", N, "func _montar_pedestal_1975", "c_v3_hoje",
		_nn("Pedestal1975"), {"dist": 2.6}))
	A.append(_e("porta_para_1950", "Porta para 1950 (Ato II)", "castelo", "Parede oeste do Salão de Arte, " + _salas(11) + "; só na visita 3, antes do Ato II", N, "func _montar_porta_ato2", "c_v3_hoje",
		_nn("PortaPara1950"), {"frente": 90.0, "dist": 3.6}))
	A.append(_e("escada_interditada", "Escada interditada (fitas zebradas)", "castelo", "Porta da escada da Torre A, " + _salas(16) + "; hoje (2020), visitas 3 e 4", N, "func _montar_bloqueio_escada", "c_v3_hoje",
		_nn("EscadaInterditada"), {"frente": 90.0, "dist": 3.2}))
	A.append(_e("porta_zebrada_hall", "Porta zebrada do hall (escada para o porão)", "castelo", "Parede do hall, " + _salas(7) + " (sala 80 na visita 4); visita 4, hoje e 2019", N, "func _montar_porta_porao", "c_v4_hoje",
		_nn("PortaZebradaDoHall"), {"frente": 0.0, "dist": 3.6, "notas": ["a água e a escada que descem são um shader (escada_falsa); no .glb viram cor lisa"]}))
	A.append(_e("escada_2019", "Alçapão com a escada de 2019", "castelo", "Chão da Sala Medieval, " + _salas(21) + "; só em 2019, visita 4", N, "func _montar_escada_2019", "c_v4_2019",
		_nn("Escada2019"), {"dist": 3.0, "notas": ["a escada que desce é um shader (escada_falsa); no .glb vira cor lisa"]}))
	A.append(_e("painel_solto", "Painel solto da parede", "castelo", "Sala dos Povos Originários, " + _salas(8) + "; visita 4 (esconde o disco 2019)", N, "func _montar_painel_solto", "c_v4_hoje",
		_nn("PainelSolto"), {"frente": 90.0, "dist": 3.0, "duvidas": ["PainelSolto"]}))
	return A


# ---------------------------------------------------------------------------------------- castelo: painéis e folhas
static func _castelo_paineis() -> Array:
	var P := "world/painel_3d.gd"
	var A: Array = []
	A.append(_e("painel_p01", "Painel educativo (placa colorida)", "castelo", "Em poste de madeira ao lado do caminho, " + _salas(1) + "; hoje (2020). São 25 painéis iguais (p01 a p25) com textos diferentes", P, "class_name Painel3D", "c_v1_hoje",
		_no(func(): return _painel("p01")), {"ref": func(nv): return nv._paineis["p01"], "dist": 3.6, "notas": ["o texto da placa é Label3D e não vai para o .glb; a placa em si é um shader, por isso o .glb leva cores lisas"]}))
	A.append(_e("painel_p03", "Painel educativo P03 (lateral da torre)", "castelo", "Lateral da torre, no jardim oeste, " + _salas(3) + "; hoje (2020), em poste de madeira", P, "func _montar_paineis", "c_v1_hoje",
		_no(func(): return _painel("p03")), {"ref": func(nv): return nv._paineis["p03"], "dist": 3.6, "duvidas": ["painel_p03"]}))
	A.append(_e("painel_p17", "Painel educativo P17 (topo da torre)", "castelo", "Topo da Torre A, " + _salas(17) + "; hoje (2020)", P, "func _montar_paineis", "c_v1_hoje",
		_no(func(): return _painel("p17")), {"ref": func(nv): return nv._paineis["p17"], "frente": 180.0, "dist": 3.4, "duvidas": ["painel_p17"]}))
	A.append(_e("painel_p07_parede", "Painel educativo de parede", "castelo", "Parede do hall, " + _salas(7) + "; hoje (2020)", P, "func _construir", "c_v1_hoje",
		_no(func(): return _painel("p07")), {"ref": func(nv): return nv._paineis["p07"], "dist": 3.0}))
	A.append(_e("painel_quiz_final", "Painel do quiz final", "castelo", "Sala Medieval, parede oeste, " + _salas(21) + "; as 4 visitas (muda de cara em cada uma)", P, "func _init", "c_v1_hoje",
		_no(func(): return _painel("quiz_final")), {"ref": func(nv): return nv._paineis["quiz_final"], "dist": 3.0}))
	A.append(_e("painel_seco_v2", "Painel 'seco' (visita 2)", "castelo", "Mesmo lugar do painel P05, " + _salas(5) + " na visita 2: placa cinza, sem graça", P, "var _seco", "c_v2_hoje",
		_no(func(): return _painel("p05_v2")), {"ref": func(nv): return nv._paineis["p05"], "dist": 3.6}))
	A.append(_e("painel_em_revisao_v3", "Painel 'EM REVISÃO' (visita 3)", "castelo", "Mesmo lugar do painel P05, " + _salas(5) + " na visita 3: placa cinza com carimbo", P, "func _carimbo", "c_v3_hoje",
		_no(func(): return _painel("p05_v3")), {"ref": func(nv): return nv._paineis["p05"], "dist": 3.6}))
	A.append(_e("painel_riscado_v4", "Painel riscado com desenho (visita 4)", "castelo", "Mesmo lugar do painel P05, " + _salas(5) + " na visita 4: título riscado e o desenho do Tito", P, "func _riscar_titulo", "c_v4_hoje",
		_no(func(): return _painel("p05_v4")), {"ref": func(nv): return nv._paineis["p05"], "dist": 3.6}))
	# folhas de papel (desenhos do Tito, cartaz, marcas de altura)
	var D := "world/painel_3d.gd"
	A.append(_e("desenho_1", "Desenho de criança nº 1", "castelo", "Salão de Arte, entre os quadros, " + _salas(11) + "; visita 1", D, "func _construir_imagem", "c_v1_hoje",
		_no(func(): return _painel("desenho_1")), {"ref": func(nv): return nv._desenhos["desenho_1"], "dist": 2.2}))
	A.append(_e("desenho_2", "Desenho de criança nº 2 (mãe e menino na praia)", "castelo", "Acervo, " + _salas(12) + "; visita 2", D, "func _construir_imagem", "c_v2_hoje",
		_no(func(): return _painel("desenho_2")), {"ref": func(nv): return nv._desenhos["desenho_2"], "dist": 2.2}))
	A.append(_e("desenho_3", "Desenho de criança nº 3 (a mulher branca na torre)", "castelo", "Sala Medieval, parede oeste, " + _salas(21) + "; depois do apagão da visita 2", D, "func _construir_imagem", "c_v2_hoje",
		_no(func(): return _painel("desenho_3")), {"frente": 90.0, "pre": func(nv, _f): nv._criar_balde_e_desenho3(), "ref": func(nv): return nv._desenhos["desenho_3"], "dist": 2.4}))
	A.append(_e("desenho_4", "Desenho de criança nº 4 (o castelo em cima do menino)", "castelo", "Meio Ambiente, parede oeste, " + _salas(9) + "; visita 3", D, "func _construir_imagem", "c_v3_hoje",
		_no(func(): return _painel("desenho_4")), {"frente": 90.0, "ref": func(nv): return nv._desenhos["desenho_4"], "dist": 2.4}))
	A.append(_e("desenho_5", "Desenho de criança nº 5", "castelo", "Painel solto da Sala dos Povos, " + _salas(8) + "; visita 4", D, "func _construir_imagem", "c_v4_hoje",
		_no(func(): return _painel("desenho_5")), {"frente": 90.0, "ref": func(nv): return nv._painel_solto, "dist": 3.0}))
	A.append(_e("desenho_6", "Desenho de criança nº 6 (dois olhos no escuro)", "castelo", "Atrás do painel solto, Sala dos Povos, " + _salas(8) + "; só em 2019, visita 4", D, "func _construir_imagem", "c_v4_2019",
		_no(func(): return _painel("desenho_6")), {"frente": 90.0, "ref": func(nv): return nv.find_child("DesenhoAtrasDoPainel", true, false), "dist": 2.6}))
	A.append(_e("desenho_7", "Desenho de criança nº 7", "castelo", "No lugar do painel P18 (2º andar), " + _salas(18) + "; hoje (2020), visita 4", D, "func _construir_imagem", "c_v4_hoje",
		_no(func(): return _painel("desenho_7")), {"ref": func(nv): return nv._paineis["p18"], "dist": 3.0}))
	A.append(_e("cartaz_procura_se", "Cartaz PROCURA-SE do Tito", "castelo", "Colado por cima de painéis (p01, p04, p07...), visitas 3 e 4", D, "func _construir_imagem", "c_v3_hoje",
		_no(func(): return _painel("procura_se")), {"ref": func(nv): return _filho(nv, "Cartaz_*"), "dist": 2.4}))
	A.append(_e("marcas_altura", "Marcas de altura a lápis (TITO 6, 7, 8, 9)", "castelo", "Batente da porta de saída da Sala Medieval, " + _salas(21) + "; só em 1975", D, "func _construir_imagem", "c_v3_1975",
		_no(func(): return _painel("marcas_altura")), {"ref": func(nv): return nv.find_child("MarcasDeAltura", true, false), "dist": 2.2}))
	return A


# ---------------------------------------------------------------------------------------- castelo: 1967 (obra), 2019 (ruína) e 1950
static func _castelo_1967() -> Array:
	var O := "castelinho/obra.gd"
	var cen := "c_v1_1967"
	var A: Array = []
	A.append(_e("andaime_madeira", "Andaime de madeira", "castelo", "Fachada sul da Torre A, " + _salas(3) + "; época 1967 (obra)", O, "static func _andaime", cen,
		_et(["andaime_torre_a", "escada_de_mao_andaime"]), {"frente": 0.0, "dist": 11.0}))
	A.append(_e("pilha_blocos", "Pilha de blocos de pedra", "castelo", "Canteiro diante do prédio, " + _salas(3) + "; época 1967 (são 8 pilhas)", O, "static func _pilhas", cen,
		_et(["pilha_blocos_1"]), {"frente": 0.0, "dist": 4.0}))
	A.append(_e("blocos_soltos_torre_a", "Três blocos soltos no topo da parede da Torre A", "castelo", "Parede oeste da Torre A em obra, " + _salas(3) + "; época 1967", O, "bloco_solto_torre_a", cen,
		_et(["bloco_solto_torre_a_*"]), {"frente": 90.0, "dist": 5.0}))
	A.append(_e("barco_encalhado", "Barco de madeira encalhado com remo", "castelo", "Gramado diante do prédio, " + _salas(2) + "; época 1967", O, "static func _barco", cen,
		_et(["barco_encalhado", "remo_barco"]), {"frente": 0.0, "dist": 6.5}))
	A.append(_e("castelo_de_areia", "Castelinho de areia do Tito", "castelo", "Ao lado de onde o Tito brinca, " + _salas(1) + "; época 1967", O, "static func _castelo_de_areia", cen,
		_et(["castelinho_de_areia", "poca_de_areia_tito"]), {"frente": 0.0, "dist": 2.6}))
	A.append(_e("carrinho_de_mao", "Carrinho de mão", "castelo", "Canteiro, pé do andaime, " + _salas(3) + "; época 1967", O, "# carrinho de mão", cen,
		_et(["carrinho_de_mao"]), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("caixa_de_massa", "Caixa de massa com enxada", "castelo", "Canteiro, " + _salas(4) + "; época 1967", O, "# caixa de massa", cen,
		_et(["caixa_de_massa"]), {"frente": 0.0, "dist": 3.4}))
	A.append(_e("monte_areia_sacos", "Monte de areia e sacos de cimento", "castelo", "Canteiro, " + _salas(4) + "; época 1967", O, "# monte de areia grossa", cen,
		_et(["monte_de_areia_grossa", "saco_de_cimento_*"]), {"frente": 0.0, "dist": 5.0}))
	A.append(_e("tabuas_soltas", "Tábuas soltas no chão do canteiro", "castelo", "Canteiro, perto do andaime, " + _salas(2) + "; época 1967", O, "# tábuas soltas no chão", cen,
		_et(["tabua_solta_*"]), {"frente": 0.0, "dist": 4.0}))
	A.append(_e("muro_buraco", "Muro com o buraco de criança", "castelo", "Muro baixo da Av. Garibaldi, " + _salas(1) + "; época 1967", O, "static func _muro_com_buraco", cen,
		_crop(_c(-22.7, -20.5, 0, 1.2, -1.45, -0.15), "Obra_1967", {"shader": true}), {"frente": 180.0, "dist": 4.2, "duvidas": ["buraco_muro_dentes"]}))
	A.append(_e("casa_madeira_1967", "Casa de madeira sobre pilotis (1967)", "castelo", "Em volta do lote, 3 casas de madeira; época 1967", O, "static func _casas", cen,
		_et(["casa_madeira_1967_1"]), {"frente": 0.0, "dist": 14.0}))
	A.append(_e("touceira_capim", "Touceira de capim alto (ruína)", "castelo", "Ao pé das paredes, em volta do prédio abandonado; época 2019", "castelinho/extras.gd", "static func _touceira", "c_v1_2019",
		_et(["mato_alto_1"]), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("chapa_fibro_solta", "Chapa de fibrocimento solta no telhado", "castelo", "Telhado do corpo principal, época 2019", "castelinho/extras.gd", "# chapas de fibrocimento", "c_v1_2019",
		_et(["chapa_fibrocimento_solta_1"]), {"frente": 0.0, "dist": 9.0}))
	A.append(_e("chamine_1950", "Chaminé do núcleo de 1950", "castelo", "Face norte do núcleo original, " + _salas(12) + "; época 1950", "castelinho/extras.gd", "static func _nucleo_1950", "c_v1_1950",
		_et(["chamine_1950"]), {"frente": 90.0, "dist": 8.0}))
	A.append(_e("porta_nucleo_1950", "Porta do núcleo de 1950", "castelo", "Núcleo original, época 1950", "castelinho/extras.gd", "static func _nucleo_1950", "c_v1_1950",
		_et(["porta_nucleo_1950"]), {"frente": 90.0, "dist": 3.2}))
	return A


# ---------------------------------------------------------------------------------------- castelo: Ato II (dunas de 1950, salas 55 a 60)
static func _castelo_ato2() -> Array:
	var X := "world/niveis/ato2.gd"
	var cen := "ato2"
	var A: Array = []
	var hall := "Ato II (visita 3), sala 55: o hall errado (a sala 7 de novo, mas errada)"
	A.append(_e("ato2_lustre_hall", "Lustre de ferro que balança sem vento", "castelo", hall, X, "# lustre de ferro balançando sem vento", cen,
		_nf(func(nv): return nv._lustre), {"ref": func(nv): return nv._lustre, "dist": 5.0, "notas": ["no jogo balança de um lado para o outro; a foto é uma pose parada"]}))
	A.append(_e("ato2_painel_corrompido", "Painel P07 corrompido", "castelo", hall + ", parede direita", X, "Painel3D.new(\"p07_corrompido\")", cen,
		_no(func(): return _painel("p07_corrompido")), {"ref": func(nv): return _por_classe(nv, "Painel3D"), "frente": 270.0, "dist": 3.4}))
	A.append(_e("ato2_porta_falsa_hall", "Porta falsa com arco (uma de três iguais)", "castelo", hall + ", parede esquerda: 3 portas iguais e fechadas", X, "# três portas IGUAIS e fechadas", cen,
		_crop(_c(-5.1, -4.8, 0, 3.1, -4.4, -2.6), "Hall"), {"frente": 90.0, "dist": 3.4}))
	A.append(_e("ato2_recorte_hall", "Recorte de papelão de visitante, virado para a parede", "castelo", hall + ", parede esquerda", X, "# recorte de papelão de visitante", cen,
		_crop(_c(-4.25, -3.75, 0, 2.45, -2.1, -0.9), "Hall"), {"frente": 90.0, "dist": 3.0}))
	A.append(_e("ato2_porta_hall", "Porta de duas folhas do fundo do hall", "castelo", hall + "; abre para as dunas de 1950 (sala 56)", X, "# a porta do fundo (duas folhas)", cen,
		_crop(_c(-1.3, 1.3, 0.0, 2.65, -14.4, -14.1), "Hall"), {"frente": 0.0, "dist": 4.0}))
	A.append(_e("ato2_estaca_duna", "Estaca de madeira do caminho nas dunas", "castelo", "Ato II, sala 56: duas fileiras de estacas marcam o caminho até o núcleo de 1950", X, "# estacas de madeira marcando um caminho", cen,
		_crop(_c(-3.65, -3.15, -0.2, 1.3, -22.4, -21.8)), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("ato2_capim_duna", "Tufo de capim de duna", "castelo", "Ato II, sala 56: 140 tufos espalhados pelas dunas", X, "# tufos de capim de duna", cen,
		_no(func(): return _capim()), {"colocar": {"pos": Vector3(6.0, 0.0, -30.0)}, "dist": 3.0}))
	A.append(_e("ato2_janela_veneziana", "Janela de venezianas do núcleo de 1950", "castelo", "Ato II, sala 57: frente da casa de pedra (núcleo de 1950)", X, "# janelas de venezianas na frente", cen,
		_crop(_c(-2.95, -1.45, 0.9, 2.3, -72.45, -72.1), "Casa1950"), {"frente": 0.0, "dist": 3.4}))
	A.append(_e("ato2_chamine_1950", "Chaminé de pedra do núcleo (por fora)", "castelo", "Ato II, sala 57: lado leste do núcleo de 1950", X, "# chaminé grande saliente", cen,
		_crop(_c(3.75, 4.7, 0, 6.4, -76.3, -73.7), "Casa1950"), {"frente": 90.0, "dist": 9.0}))
	A.append(_e("ato2_lareira_1950", "Lareira do núcleo (por dentro)", "castelo", "Ato II, sala 57: dentro da casa de 1950, parede leste", X, "# chaminé grande saliente", cen,
		_crop(_c(2.4, 3.29, -0.02, 1.6, -76.2, -73.8), "Casa1950"), {"frente": 270.0, "dist": 3.0,
		"pre": func(nv, _f): nv._ambiente("casa", 0.01)}))
	A.append(_e("ato2_mesa_casa", "Mesa de madeira da casa de 1950", "castelo", "Ato II, sala 57: dentro do núcleo de 1950", X, "# mesa e areia que entrou pela porta", cen,
		_crop(_c(1.2, 2.6, 0, 0.9, -76.7, -75.7), "Casa1950"), {"frente": 0.0, "dist": 2.6, "pre": func(nv, _f): nv._ambiente("casa", 0.01)}))
	A.append(_e("ato2_montinho_areia", "Montinho de areia que entrou pela porta", "castelo", "Ato II, sala 57: três montinhos meio enterrados no chão da casa", X, "montinho_areia_%d", cen,
		_crop(_c(-0.5, 1.1, -0.2, 0.3, -74.1, -73.0), "Casa1950"), {"frente": 0.0, "dist": 3.0, "pre": func(nv, _f): nv._ambiente("casa", 0.01)}))
	A.append(_e("ato2_aviso_visitantes", "Aviso aos visitantes (regra do contato visual)", "castelo", "Ato II, sala 57: parede dos fundos da casa de 1950", X, "# aviso diegético da regra", cen,
		_crop(_c(0.5, 2.5, 1.3, 2.3, -77.35, -77.2), "Casa1950"), {"frente": 0.0, "dist": 3.4, "pre": func(nv, _f): nv._ambiente("casa", 0.01)}))
	A.append(_e("ato2_janela_gradeada", "Janelinha gradeada do anexo", "castelo", "Ato II, sala 57: parede oeste do anexo do núcleo", X, "# janelinha gradeada no alto", cen,
		_crop(_c(-7.6, -7.3, 1.6, 2.3, -75.5, -74.5), "Casa1950"), {"frente": 90.0, "dist": 2.8, "pre": func(nv, _f): nv._ambiente("casa", 0.01)}))
	A.append(_e("ato2_modulo_arcada", "Módulo da arcada repetida (pilar, arco abatido, peitoril)", "castelo", "Ato II, sala 58: 8 módulos IGUAIS de arcos abatidos sobre pilares quadrados", X, "# 9 pilares quadrados + 8 baías", cen,
		_crop(_c(-4.9, 0.5, -0.05, 3.7, -83.6, -78.0), "Arcada", {"aresta_max": 8.0}), {"frente": 270.0, "dist": 7.0, "pre": func(nv, _f): nv._ambiente("arcada", 0.01)}))
	A.append(_e("ato2_lanterna_arcada", "Lanterna da parede da arcada", "castelo", "Ato II, sala 58: parede direita da arcada, uma por módulo", X, "# lanterna", cen,
		_nn("Lanterna"), {"frente": 90.0, "dist": 3.0, "pre": func(nv, _f): nv._ambiente("arcada", 0.01)}))
	A.append(_e("ato2_porta_final", "Porta da Sala Medieval, fora de lugar", "castelo", "Ato II, sala 59: no fim da arcada; atravessar leva ao Castelinho (sala 60)", X, "func _porta_final", cen,
		_nn("PortaFinal"), {"frente": 0.0, "dist": 5.0, "pre": func(nv, _f): nv._ambiente("arcada", 0.01)}))
	A.append(_e("ato2_trono_vermelho", "Trono vermelho", "castelo", "Ato II, sala 60: Sala Medieval atrás da porta (o escudo dourado fica na parede atrás)", X, "func _sala_medieval", cen,
		_crop(_c(-3.4, -2.4, 0, 1.95, -128.1, -127.15), "SalaMedieval"), {"frente": 0.0, "dist": 4.0, "pre": func(nv, _f): nv._ambiente("arcada", 0.01)}))
	A.append(_e("ato2_trono_armadura", "Trono vermelho com a armadura sentada", "castelo", "Ato II, sala 60: Sala Medieval atrás da porta (a mesma armadura da sala 21)", X, "# a armadura sentada no trono da direita", cen,
		_crop(_c(-1.2, -0.2, 0, 1.95, -128.1, -127.0), "SalaMedieval"), {"frente": 0.0, "dist": 3.4, "pre": func(nv, _f): nv._ambiente("arcada", 0.01)}))
	return A


# ---------------------------------------------------------------------------------------- dúvidas (pontos do problema, sem glb)
static func _duvidas_pontos() -> Array:
	var A: Array = []
	A.append(_e("duvida_corredor_1975_casa_vizinha", "Dúvida: corredor de 1975 atravessa a casa vizinha", "castelo",
		"Corredor de 1975 (visita 3, " + _salas(25) + "), onde ele cruza a casa vizinha nº 17, ao norte do lote", "world/niveis/castelinho.gd", "func _corredor", "c_v3_1975",
		_ponto([
			{"alvo": func(nv): return Vector3(-12.3, 1.3, -40.7), "pes": func(nv): return Vector3(-16.5, 0.03, -37.0)},
			{"alvo": func(nv): return Vector3(-9.05, 1.2, -41.5), "pes": func(nv): return Vector3(-10.2, 0.03, -36.0)},
			{"alvo": func(nv): return Vector3(-11.35, 1.2, -50.5), "pes": func(nv): return Vector3(-10.2, 0.03, -56.0)},
		]), {"duvidas": ["casa_vizinha_17", "corredor_1975"]}))
	A.append(_e("duvida_menino_slide_canelas", "Dúvida: menino sentado dos slides com as canelas no piso", "porao",
		"Porão, slides do último dia: sala 97 (borda de pedra) e sala 98 (passarela); só com o disco sem data", "world/niveis/porao_quarto.gd", "static func _menino", "porao_semdata",
		_ponto([
			{"pre": func(nv, _f): nv.ir_para_sala(16), "alvo": func(nv): return nv.salas[16].raiz.find_child("Tito", true, false).global_position + Vector3(0, 0.3, 0), "raio": 0.6, "frente": 0.0, "dist": 2.2},
			{"alvo": func(nv): return nv.salas[16].raiz.find_child("Tito", true, false).global_position + Vector3(0, 0.15, 0), "raio": 0.5, "frente": 90.0, "dist": 1.8},
			{"pre": func(nv, _f): nv.ir_para_sala(17), "alvo": func(nv): return nv.salas[17].raiz.find_child("Tito", true, false).global_position + Vector3(0, 0.3, 0), "raio": 0.6, "frente": 0.0, "dist": 2.2},
		]), {"duvidas": ["Slide97", "Slide98"]}))
	A.append(_e("duvida_fita_zebrada_cadeira", "Dúvida: fita zebrada perto de uma cadeira da Sala Medieval", "castelo",
		"Sala Medieval, porta de saída em reforma, " + _salas(21) + "; visita 4", "world/niveis/castelinho.gd", "func _fita_zebrada", "c_v4_hoje",
		_ponto([
			{"alvo": func(nv): return Vector3(-12.2, 0.9, -28.0), "raio": 1.8, "frente": 0.0, "dist": 3.6},
			{"alvo": func(nv): return Vector3(-13.2, 0.5, -27.0), "raio": 0.9, "frente": 60.0, "dist": 2.6},
		]), {"duvidas": ["cadeira_medieval_2_n"]}))
	return A


# ---------------------------------------------------------------------------------------- barra (flashback)
static func _barra() -> Array:
	var B := "world/niveis/barra.gd"
	var A: Array = []
	A.append(_e("pescador", "Pescador com tarrafa (silhueta)", "barra", "Beira d'água da Barra do Tramandaí, flashback da visita 2 (" + _salas(14) + ")", B, "func _criar_pescadores", "barra",
		_nn("Pescador0"), {"frente": 0.0, "dist": 4.5}))
	A.append(_e("boto", "Boto de nadadeira cortada", "barra", "Água da Barra, vem até a margem durante o minigame da tarrafa (visita 2)", B, "func _criar_boto", "barra",
		_nn("Boto"), {"frente": 180.0, "ref": func(nv): return nv.boto, "dist": 7.0,
		"notas": ["a nadadeira dorsal CORTADA é um toco achatado: é de propósito"]}))
	A.append(_e("tarrafa_rede", "Rede de tarrafa", "barra", "Lançada pelo jogador e pelos pescadores no minigame (3 lances), Barra", B, "func _lancar_rede", "barra",
		_no(func(): return _rede()), {"colocar": {"pos": Vector3(0.0, 0.5, -1.6)}, "dist": 3.4}))
	A.append(_e("sandalia_crianca", "Sandália de criança", "barra", "Vem dentro da rede do 3º lance (e reaparece no trono do Castelinho)", B, "func _sandalia_na_rede", "barra",
		_no(func(): return _sandalia()), {"colocar": {"pos": Vector3(0.3, 0.02, -1.0), "yaw": 35.0}, "dist": 1.4}))
	A.append(_e("bloco_molhe", "Bloco de pedra do molhe", "barra", "Molhe de pedra que corre pela margem rumo ao mar (260 blocos), Barra", B, "func _molhe_e_ponte", "barra",
		_no(func(): return _bloco_molhe()), {"colocar": {"pos": Vector3(1.8, 0.55, -2.0)}, "dist": 3.0}))
	return A


# ---------------------------------------------------------------------------------------- porão
static func _porao() -> Array:
	var S := "world/niveis/porao_salas.gd"
	var Q := "world/niveis/porao_quarto.gd"
	var A: Array = []
	var nota_sala := " (sempre igual: o porão tem sequência fixa)"
	A.append(_e("fitas_entrada_porao", "Fitas zebradas, batente e placa EM REFORMA", "porao", "Entrada do porão, sala 81" + nota_sala, S, "static func _fitas_entrada", "porao",
		_sala(0, func(c): return _c(-1.55, 1.55, -0.1, 2.75, -1.8, -0.9)), {"frente": 0.0, "dist": 3.4}))
	A.append(_e("porta_porao", "Porta de tábuas que se fecha atrás do jogador", "porao", "Abertura de entrada de cada sala do porão (81 a 99)", S, "static func _porta_entrada", "porao",
		_nf(func(nv): return nv.salas[0].porta), {"pre": func(nv, _f): nv.ir_para_sala(0), "frente": 0.0, "dist": 4.0,
		"ref": func(nv): return nv.salas[0].porta,
		"notas": ["no jogo a porta começa levantada e desce quando o jogador entra"]}))
	A.append(_e("tocha_porao", "Tocha de parede do porão", "porao", "Paredes das salas 82 a 94 (a chama é a única luz de cada sala)", S, "static func tocha", "porao",
		_sala(1, func(c): return _c(-c.w * 0.5 - 0.02, -c.w * 0.5 + 0.3, 1.5, 2.45, -4.25, -3.75)), {"frente": 90.0, "dist": 2.6}))
	A.append(_e("grade_cela", "Grade de cela com nicho", "porao", "Masmorra, sala 84" + nota_sala, S, "static func _grade", "porao",
		_sala(3, func(c): return _c(-c.w * 0.5 - 0.02, -c.w * 0.5 + 0.3, -0.03, 2.5, -7.55, -5.65)), {"frente": 90.0, "dist": 3.4}))
	A.append(_e("correntes_parede", "Correntes velhas e algema na parede", "porao", "Sala 87 (masmorra com celas)" + nota_sala, S, "static func _correntes", "porao",
		_sala(6, func(c): return _c(-c.w * 0.5 - 0.02, -c.w * 0.5 + 0.3, 1.6, 2.8, -11.95, -10.2)), {"frente": 90.0, "dist": 3.0}))
	A.append(_e("cela_giz", "Cela aberta com desenhos de giz e riscos de dias", "porao", "Sala 90, a 1ª Figura (nicho na parede leste)" + nota_sala, S, "static func _cela_giz", "porao",
		_sala(9, func(c): return _c(c.w * 0.5 - 0.05, c.w * 0.5 + 2.9, -0.05, 2.5, -7.5, -4.5)), {"frente": 270.0, "dist": 4.5}))
	A.append(_e("mesinha_crianca", "Mesinha de criança com giz de cera", "porao", "Sala 83 (desenhos)" + nota_sala, S, "static func _desenhos", "porao",
		_sala(2, func(c): return _c(-0.85, 0.85, -0.05, 0.65, -5.55, -3.4), {"shader_mats": ["madeira"], "aresta_max": 4.0}), {"frente": 0.0, "dist": 3.0}))
	A.append(_e("cama_crianca", "Cama de solteiro de criança", "porao", "Sala 85 (quarto de criança impossível)" + nota_sala, S, "static func _crianca", "porao",
		_sala(4, func(c): return _c(-c.w * 0.5 - 0.02, -c.w * 0.5 + 1.0, -0.03, 0.62, -5.7, -3.1), {"shader_mats": ["madeira"], "aresta_max": 4.0}), {"frente": 90.0, "dist": 3.0}))
	A.append(_e("cavalinho_balanco", "Cavalinho de balanço", "porao", "Sala 85 (quarto de criança impossível)" + nota_sala, S, "# baú de brinquedos, cavalinho de balanço", "porao",
		_sala(4, func(c): return _c(0.8, 1.6, -0.03, 1.05, -5.95, -5.1)), {"frente": 0.0, "dist": 2.4}))
	A.append(_e("mesa_telefone_porao", "Mesa de escritório com telefone preto", "porao", "Sala 88 (o telefone toca)" + nota_sala, S, "static func _telefone", "porao",
		_sala(7, func(c): return _c(-1.25, 1.25, -0.03, 1.0, -4.75, -3.45), {"shader_mats": ["madeira"], "aresta_max": 4.0}), {"frente": 0.0, "dist": 3.4}))
	A.append(_e("poco_balde", "Poço com roldana e balde vermelho", "porao", "Sala 92 (poço)" + nota_sala, S, "static func _poco", "porao",
		_sala(11, func(c): return _c(-2.0, 2.0, -0.03, 3.6, -7.3, -3.7), {"shader_mats": ["pedra", "madeira"], "aresta_max": 4.0}), {"frente": 0.0, "dist": 6.5}))
	A.append(_e("cama_quarto_tito", "Cama e criado-mudo do quarto do Tito", "porao", "Quarto do Tito, sala 95 (quarto de 1967 inteiro e seco no meio da masmorra)", Q, "# cama de solteiro (pés para o fundo)", "porao",
		_sala(14, func(c): return _c(-c.w * 0.5, -c.w * 0.5 + 1.05, 0.65, 1.7, -6.3, -2.65), {"shader_mats": ["madeira"], "aresta_max": 4.0}), {"frente": 90.0, "dist": 3.4}))
	A.append(_e("guarda_roupa_quarto", "Guarda-roupa de duas portas", "porao", "Quarto do Tito, sala 95", Q, "# guarda-roupa de duas portas", "porao",
		_sala(14, func(c): return _c(c.w * 0.5 - 0.7, c.w * 0.5 + 0.02, 0.65, 2.75, -6.45, -4.55), {"shader_mats": ["madeira"], "aresta_max": 4.0}), {"frente": 270.0, "dist": 3.4}))
	A.append(_e("balde_pazinha_quarto", "Balde vermelho, pazinha e sandália", "porao", "Quarto do Tito, ao lado do tapete, sala 95", Q, "# tapete redondo (quadrado, low-poly)", "porao",
		_sala(14, func(c): return _c(0.7, 1.5, 0.65, 1.1, -2.9, -1.95)), {"frente": 0.0, "dist": 2.2}))
	A.append(_e("disco_sem_data", "Disco sem data (vermelho brilhante)", "porao", "Em cima da cama do Tito, sala 95; é o disco da época sem data", Q, "# o disco sem data na cama", "porao",
		_nf(func(nv): return nv.salas[14].raiz.find_child("Disco", true, false)), {"pre": func(nv, _f): nv.ir_para_sala(14), "frente": 90.0, "dist": 1.6,
		"ref": func(nv): return nv.salas[14].raiz.find_child("Disco", true, false)}))
	# slides do último dia (só na época sem data)
	A.append(_e("menino_sentado_slide", "Menino de costas sentado, com balde (slide)", "porao", "Salas 97 e 98, slides do último dia (só com o disco sem data)", Q, "static func _menino", "porao_semdata",
		_no(func(): return _menino(true)), {"colocar": {"sala": 16, "pos": Vector3(0.0, 0.0, -6.0)}, "dist": 3.0, "duvidas": ["Slide97", "Slide98"]}))
	A.append(_e("figura_slide", "Figura Branca do slide (silhueta)", "porao", "Sala 98, slide do último dia (só com o disco sem data)", Q, "static func _figura_slide", "porao_semdata",
		_no(func(): return _figura_slide()), {"colocar": {"sala": 17, "pos": Vector3(0.0, 0.0, -6.0), "yaw": 180.0}, "dist": 5.0}))
	A.append(_e("balde_boiando", "Balde vermelho boiando", "porao", "Sala 99, slide do último dia: água parada e o balde", Q, "static func _balde_boiando", "porao_semdata",
		_no(func(): return PoraoQuarto._balde_boiando()), {"colocar": {"sala": 18, "pos": Vector3(0.4, 0.05, -1.6)}, "dist": 2.4}))
	return A


# ---------------------------------------------------------------------------------------- lago (Braço Morto)
static func _lago() -> Array:
	var B := "world/niveis/braco_morto.gd"
	var cen := "lago"
	var A: Array = []
	A.append(_e("poste_calcadao", "Poste do calçadão", "lago", "Calçadão do Braço Morto (sala 100), a cada 18 m ao longo do lago", B, "func _calcadao_e_mobiliario", cen,
		_crop(_c(-0.5, 0.5, 0, 4.1, -4.25, -3.3), "Mobiliario"), {"frente": 180.0, "dist": 6.0}))
	A.append(_e("banco_calcadao", "Banco do calçadão", "lago", "Calçadão do Braço Morto (sala 100), de frente para o lago", B, "# bancos de madeira pintada voltados para o lago", cen,
		_crop(_c(-1.0, 1.0, 0, 1.0, -4.7, -4.0), "Mobiliario"), {"frente": 180.0, "dist": 4.5}))
	A.append(_e("canteiro_calcadao", "Canteiro com folhagem baixa", "lago", "Calçadão do Braço Morto, junto aos postes", B, "# canteiros com folhagem baixa", cen,
		_crop(_c(-88.9, -87.1, 0, 1.1, -2.5, -1.5), "Mobiliario"), {"frente": 0.0, "dist": 4.0}))
	A.append(_e("pontilhao_pintado", "Pontilhão pintado (trecho)", "lago", "Dois pontilhões entram no lago, Braço Morto", B, "func _pontilhoes", cen,
		_crop(_c(-35.6, -32.4, -2.1, 1.3, -14.0, -8.0), "Pontilhoes", {"aresta_max": 30.0}), {"frente": 180.0, "dist": 8.0}))
	A.append(_e("pedalinho_cisne", "Pedalinho em forma de cisne", "lago", "Atracados na margem do lago, Braço Morto", B, "func _pedalinhos", cen,
		_crop(_c(14.5, 17.4, -0.4, 1.95, -11.5, -9.6), "Pedalinhos"), {"frente": 0.0, "dist": 5.0}))
	A.append(_e("placa_atracadouro", "Placa PEDALINHOS EMBARQUE", "lago", "Ao lado da rampa do atracadouro, Braço Morto", B, "func _atracadouro", cen,
		_crop(_c(34.9, 36.9, 0, 2.0, -6.7, -6.3), "Atracadouro"), {"frente": 0.0, "dist": 4.5}))
	A.append(_e("lapide_areia", "Lápide de areia com torres de balde", "lago", "Calçada diante do lago, Braço Morto (sala 100): é onde o jogo termina", B, "func _lapide_de_areia", cen,
		_crop(_c(6.3, 10.7, -0.1, 0.9, -6.7, -4.8), "LapideDeAreia"), {"frente": 0.0, "dist": 6.0,
		"notas": ["o nome TITO riscado na lápide é Label3D e não vai para o .glb"]}))
	A.append(_e("obra_blocos_tapume", "Obra de rua: blocos pretos, cones e tapume", "lago", "Canto da calçada do Braço Morto", B, "func _obra", cen,
		_crop(_c(-53.5, -41.5, 0, 2.0, 11.5, 24.5), "Obra"), {"frente": 0.0, "dist": 14.0}))
	A.append(_e("fundo_lago_pecas", "Tênis, balde tombado e algas do fundo do lago", "lago", "Fundo do lago, onde o jogador afunda (final 'sala 101')", B, "func _pecas_do_fundo", cen,
		_nf(func(nv): return _fundo_lago(nv)), {"dist": 3.0, "frente": 0.0, "sem_local": true,
		"notas": ["sem foto de local: o fundo do lago só existe quando o jogador afunda (final 'sala 101'), longe de qualquer chão"]}))
	return A


# ---------------------------------------------------------------------------------------- criaturas
static func _criaturas() -> Array:
	var A: Array = []
	A.append(_e("figura_branca", "Figura Branca", "criaturas", "Perseguidora do jogo todo: Castelinho (visitas 2 a 4), Ato II, porão (salas 90 e 94). Aqui: sala 90", "creatures/figura_branca.gd", "class_name FiguraBranca", "porao",
		_no(func(): return _figura()), {"colocar": {"sala": 9, "pos": Vector3(0.0, 0.05, -9.0), "yaw": 180.0}, "dist": 5.5, "frente": 180.0,
		"notas": ["pose parada (a pose muda um pouco a cada passo)", "a mão e o braço longos também aparecem em braco_morto.gd (mão do afogamento)"]}))
	A.append(_e("costela_cipo", "Costela-de-Adão (cipó)", "criaturas", "Cipós que crescem nas paredes e no chão quando o jogador fica parado (salas 87 e 92 do porão)", "creatures/costela.gd", "static func malha_variante", "porao",
		_no(func(): return _costela_cipo()), {"colocar": {"sala": 6, "pos": Vector3(-3.5, 0.0, -4.0), "yaw": 90.0}, "dist": 3.5,
		"notas": ["no jogo existem 3 variações de cipó e dezenas deles; aqui a variação 1"]}))
	A.append(_e("silhueta_susto", "Vulto de susto (silhueta de criança)", "criaturas", "Usada pelos sustos do porão e do Castelinho (Susto.disparar)", "creatures/susto.gd", "static func _silhueta", "porao",
		_no(func(): return Susto._silhueta()), {"colocar": {"sala": 1, "pos": Vector3(0.0, 0.0, -6.0)}, "dist": 4.0}))
	A.append(_e("tito_boneco", "Tito (boneco de 1967)", "criaturas", "Brincando de castelo de areia diante do prédio, " + _salas(1) + "; só em 1967", "castelinho/tito.gd", "static func criar_tito", "c_v1_1967",
		_no(func(): return TitoCastelinho.criar_tito()), {"ref": func(nv): return nv._tito, "dist": 3.0, "frente": 0.0,
		"notas": ["Tito é fictício; o boneco acena e cava a areia no jogo"]}))
	A.append(_e("tito_margem", "Tito sentado na margem do lago", "criaturas", "Margem do Braço Morto (sala 100), só com o disco sem data ou 1967", "world/niveis/porao_quarto.gd", "static func menino", "lago",
		_no(func(): return _menino(true)), {"ref": func(nv): return nv.tito, "dist": 3.0, "frente": 0.0, "duvidas": ["TitoNaMargem"],
		"notas": ["sempre de costas, sempre uma silhueta: peso por sugestão"]}))
	A.append(_e("menino_em_pe", "Menino de pé com balde (slide)", "criaturas", "Sala 96 do porão, slide do último dia (só com o disco sem data)", "world/niveis/porao_quarto.gd", "static func _menino", "porao_semdata",
		_no(func(): return _menino(false)), {"colocar": {"sala": 15, "pos": Vector3(0.0, 0.0, -5.0)}, "dist": 3.0}))
	A.append(_e("mao_longa", "Mão longa da Figura", "criaturas", "Braço Morto: a mão que sai da água e pousa no ombro de quem afunda (final 'sala 101')", "world/niveis/braco_morto.gd", "func _mao_longa", "lago",
		_nf(func(nv): return _mao(nv)), {"dist": 2.2, "colocar": {"pos": Vector3(5.0, 1.0, -3.0)},
		"notas": ["a foto de local mostra a mão solta no calçadão: no jogo ela só aparece no final"]}))
	return A
