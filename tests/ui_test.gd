extends SceneTree
## Teste automático (headless) da UI e do conteúdo: painéis (JSON, placa 3D, tela de leitura, quiz),
## Guia (fala simples, bloqueante, fila, engasgo e corrupção), Audio e telas (título, diploma, morte, fim).
## Uso: godot --headless -s res://tests/ui_test.gd
##
## Obs.: scripts que citam autoloads (GameState...) só compilam depois que os autoloads existem,
## por isso as classes são carregadas com load() dentro do teste, e não citadas pelo nome.

var falhas := 0
var GameState
var Guia
var Audio
var PainelUI
var Flash


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	GameState = root.get_node("/root/GameState")
	Guia = root.get_node("/root/Guia")
	Audio = root.get_node("/root/Audio")
	PainelUI = load("res://ui/painel_ui.gd")
	Flash = load("res://ui/flash.gd")
	GameState.novo_jogo()
	GameState.jogando = false

	await _teste_json()
	await _teste_painel_quiz()
	await _teste_quiz_final()
	await _teste_guia()
	await _teste_audio()
	await _teste_telas()

	print("RESULTADO: ", "OK" if falhas == 0 else "%d FALHA(S)" % falhas)
	quit(1 if falhas else 0)


# ---------------------------------------------------------------- conteúdo
func _teste_json() -> void:
	print("-- JSON dos painéis")
	var tudo: Dictionary = PainelUI.carregar_dados()
	_checar(tudo.size() > 25, "paineis.json carregou (%d entradas)" % tudo.size())
	var palavras_demais := []
	for n in range(1, 26):
		var id := "p%02d" % n
		var d: Dictionary = PainelUI.dados(id)
		if d.get("titulo", "") == "Painel em construção" or str(d.get("texto", "")) == "":
			_checar(false, "%s existe e tem texto" % id)
			continue
		if str(d.texto).split(" ", false).size() > 66:
			palavras_demais.append(id)
		_checar(str(d.get("fonte", "")).begins_with("http"), "%s tem fonte (URL)" % id)
		_checar(Flash.icone(str(d.icone)) != null, "%s: ícone '%s' existe" % [id, d.icone])
	_checar(palavras_demais.is_empty(), "textos com até ~60 palavras (excesso: %s)" % str(palavras_demais))
	_checar(PainelUI.dados("p07_corrompido").has("texto"), "p07_corrompido existe")
	var qf = PainelUI.dados("quiz_final").get("quiz")
	_checar(qf is Array and qf.size() == 3, "quiz_final tem 3 perguntas")
	for id in ["p02", "p05", "p08"]:
		var q = PainelUI.dados(id).get("quiz")
		_checar(q is Dictionary and q.opcoes.size() == 3 and int(q.correta) in [0, 1, 2] and q.selo != "", "%s tem quiz válido" % id)
	_checar(PainelUI.dados("p22").get("titulo") == PainelUI.dados("quiz_final").get("titulo"), "p22 é alias do quiz_final")
	_checar(PainelUI.dados("zzz").get("titulo") == "Painel em construção", "id desconhecido cai no painel genérico")
	for m in ["bentinho", "taina", "quico"]:
		_checar(Flash.mascote(m) != null and Flash.mascote(m, true) != null, "mascote %s (normal e corrompido) carregam" % m)


func _teste_painel_quiz() -> void:
	print("-- Painel3D + tela de leitura + quiz")
	var Painel3D = load("res://world/painel_3d.gd")
	var p = Painel3D.new("p02")
	root.add_child(p)
	await process_frame
	var lidos := []
	p.lido.connect(func(i): lidos.append(i))
	_checar(p.get_node("Visual").get_child_count() > 5, "placa 3D montou suas peças")
	_checar("quiz" in p.texto_interacao.to_lower(), "aviso da placa com quiz: '%s'" % p.texto_interacao)
	p.interagir(null)
	for i in 4:
		await process_frame
	var ui = PainelUI.atual
	_checar(ui != null and is_instance_valid(ui), "interagir abriu a tela de leitura")
	_checar(GameState.flag("ui_aberta") == true, "flag ui_aberta ligada")
	_checar(GameState.contadores.paineis_lidos == 1, "paineis_lidos = 1")
	ui.avancar()                      # termina de "digitar"
	ui.avancar()                      # abre o quiz
	_checar(ui._em_quiz, "botão principal abriu o quiz")
	_checar(ui.responder(0) == false, "resposta errada devolve false")
	_checar(GameState.selos.is_empty(), "errar não dá selo")
	_checar(ui.responder(2) == true, "resposta certa devolve true")
	_checar("selo_nome" in GameState.selos, "acertar deu o selo")
	_checar(GameState.contadores.quiz_acertos == 1, "quiz_acertos = 1")
	ui.avancar()                      # "Terminar"
	for i in 4:
		await process_frame
	_checar(lidos == ["p02"], "sinal lido(p02) emitido ao fechar (%s)" % str(lidos))
	_checar(GameState.flag("ui_aberta") == false, "flag ui_aberta desligada")
	_checar(PainelUI.atual == null, "tela de leitura liberada")
	p.queue_free()
	# painel sem quiz fecha direto; reabrir não conta de novo
	var ui2 = PainelUI.mostrar("p01")
	await process_frame
	await process_frame
	ui2.avancar()
	ui2.avancar()
	for i in 4:
		await process_frame
	_checar(GameState.contadores.paineis_lidos == 2, "p01 lido: paineis_lidos = 2")
	_checar(not GameState.flag("ui_aberta"), "p01 fechou sem travar nada")


func _teste_quiz_final() -> void:
	print("-- quiz_final (3 perguntas)")
	var ui = PainelUI.mostrar("quiz_final")
	await process_frame
	await process_frame
	ui.avancar()
	ui.avancar()
	var q: Array = PainelUI.dados("quiz_final").quiz
	for i in 3:
		_checar(ui.responder(int(q[i].correta)), "pergunta %d certa" % (i + 1))
		ui.avancar()
	for i in 4:
		await process_frame
	_checar(GameState.selos.size() == 4, "4 selos no total (%d)" % GameState.selos.size())
	_checar(GameState.contadores.quiz_acertos == 4, "quiz_acertos = 4")
	_checar(not GameState.flag("ui_aberta"), "quiz_final fechou")


# ---------------------------------------------------------------- Guia
func _acelerar(segundos := 4.0) -> void:
	# aperta "avançar" de tempos em tempos (os textos de teste são curtos); sem efeito se não houver fala
	var t := 0.0
	while t < segundos:
		await create_timer(0.3).timeout
		t += 0.3
		Guia.avancar()


func _teste_guia() -> void:
	print("-- Guia")
	_checar(not Guia.ocupado(), "Guia começa livre")
	_acelerar()
	var t0 := Time.get_ticks_msec()
	var vistas := []
	Guia.linha_mostrada.connect(func(pers, txt): vistas.append(pers))
	Guia.falar("bentinho", ["Oi!", "Eu sou o Bentinho!"])
	_checar(Guia.ocupado(), "ocupado logo depois de falar()")
	await Guia.fala_terminou
	_checar(not Guia.ocupado(), "livre depois de fala_terminou")
	_checar(vistas.count("bentinho") == 2, "mostrou as 2 linhas")
	print("   (fala simples levou %.1fs)" % ((Time.get_ticks_msec() - t0) / 1000.0))

	# fila: duas chamadas seguidas, a segunda espera a primeira
	_acelerar()
	var ordem := []
	var a := func():
		await Guia.falar("taina", ["Primeira."])
		ordem.append("a")
	var b := func():
		await Guia.falar("quico", ["Segunda."])
		ordem.append("b")
	a.call()
	b.call()
	while Guia.ocupado():
		await process_frame
	await process_frame
	_checar(ordem == ["a", "b"], "fila respeita a ordem (%s)" % str(ordem))

	# duas falas em sequência (a segunda começa no meio do fade-out da primeira): a caixa tem que ficar visível
	_acelerar(2.5)
	var seq := func():
		await Guia.falar("bentinho", ["Primeira."])
		await Guia.falar("bentinho", ["Segunda, logo em seguida."])
	seq.call()
	var vis_ok := true
	for i in 20:
		await create_timer(0.05).timeout
		if Guia._ativo and Guia._texto.text.begins_with("Segunda") and Guia._caixa.modulate.a < 0.9 and Guia._t_linha > 0.3:
			vis_ok = false
	_checar(vis_ok, "falas em sequência não deixam a caixa invisível")
	while Guia.ocupado():
		await process_frame

	# bloqueante: trava o jogador e devolve o movimento no fim
	var Player = load("res://player/player.gd")
	var jog = Player.new()
	root.add_child(jog)
	await process_frame
	_acelerar()
	var estados := []
	var c := func():
		await Guia.falar("sistema", ["Aviso bloqueante."], true)
		estados.append(jog.pode_mover)
	c.call()
	await create_timer(0.1).timeout
	_checar(jog.pode_mover == false, "falar(..., true) trava o jogador")
	while Guia.ocupado():
		await process_frame
	await process_frame
	_checar(jog.pode_mover == true and estados == [true], "e libera no fim")

	# corrupção e engasgo
	GameState.definir_corruption_manual(0.7)
	_checar(Flash.corromper("Bem-vindo a visita guiada, tudo bem?", 0.7) != "Bem-vindo a visita guiada, tudo bem?" \
		or true, "corromper roda sem erro")
	var difere := false
	for i in 30:
		if Flash.corromper("Bem-vindo ao Castelinho, vocês estão aqui", 0.9) != "Bem-vindo ao Castelinho, vocês estão aqui":
			difere = true
	_checar(difere, "corromper troca letras com corruption alta")
	_checar(Flash.corromper("Oi, tudo bem?", 0.1) == "Oi, tudo bem?", "corromper não mexe com corruption baixa")
	var eg: Dictionary = Flash.engasgar("Esta é a visita guiada")
	_checar(eg.ini >= 0 and "-" in eg.texto, "engasgar repete uma sílaba: '%s'" % eg.texto)
	_acelerar()
	await Guia.falar_engasgado("bentinho", ["Esta é a ponte Giuseppe Garibaldi, que liga Imbé a Tramandaí."])
	_checar(not Guia.ocupado(), "falar_engasgado terminou")
	GameState.definir_corruption_manual(-1.0)

	# cancelar libera quem está esperando
	var fim := []
	var d := func():
		await Guia.falar("quico", ["Fala longa que será cancelada no meio do caminho."], true)
		fim.append("ok")
	d.call()
	await create_timer(0.2).timeout
	Guia.cancelar()
	await create_timer(0.3).timeout
	_checar(fim == ["ok"] and not Guia.ocupado() and jog.pode_mover, "cancelar() libera tudo")
	jog.queue_free()


# ---------------------------------------------------------------- Audio
func _teste_audio() -> void:
	print("-- Audio")
	var nomes := ["clique", "boing", "blip_bentinho", "blip_taina", "blip_quico", "acerto", "erro", "selo", "confete",
		"fanfarra", "passo_1", "passo_2", "passo_3", "ofego", "susto", "apito", "telefone", "porta", "vento", "mar",
		"rio", "agua_puxa", "chiado_radio", "jingle_0", "jingle_1", "jingle_2",
		"slide", "sussurro", "splash", "tarrafa", "chuva", "goteira", "agua_sobe", "crianca_ei", "telefone_voz", "atencao"]
	var faltando := []
	for n in nomes:
		if Audio._carregar(n) == null:
			faltando.append(n)
	_checar(faltando.is_empty(), "todos os sons existem (faltam: %s)" % str(faltando))
	_checar(Audio._normalizar("Água Puxa") == "agua_puxa", "nomes com acento viram arquivo")
	Audio.sfx("clique")
	Audio.sfx("água_puxa")
	Audio.passo()
	Audio.sfx_3d("apito", Vector3.ZERO)
	GameState.definir_corruption_manual(0.0)
	Audio.musica("jingle", 0.0)
	_checar(Audio.musica_atual() == "jingle_0", "música 'jingle' começa na versão 0")
	GameState.definir_corruption_manual(0.3)
	await process_frame
	_checar(Audio.musica_atual() == "jingle_1", "corruption 0.3 troca para jingle_1")
	GameState.definir_corruption_manual(0.7)
	await process_frame
	_checar(Audio.musica_atual() == "jingle_2", "corruption 0.7 troca para jingle_2")
	Audio.musica("jingle_1", 0.0)
	GameState.definir_corruption_manual(0.0)
	await process_frame
	_checar(Audio.musica_atual() == "jingle_1", "nome explícito não troca sozinho")
	Audio.ambiente("vento", -8.0, 0.0)
	Audio.silenciar(0.0)
	GameState.definir_corruption_manual(-1.0)


# ---------------------------------------------------------------- telas
func _teste_telas() -> void:
	print("-- Telas")
	var titulo = load("res://ui/tela_titulo.tscn").instantiate()
	root.add_child(titulo)
	await process_frame
	var comecou := []
	titulo.comecar.connect(func(c): comecou.append(c))
	titulo.iniciar_visita(false)
	_checar(comecou == [false], "tela de título emite comecar(false)")
	titulo.queue_free()

	var Diploma = load("res://ui/diploma.gd")
	var dip = Diploma.mostrar()
	await process_frame
	await process_frame
	var fechou := []
	dip.fechado.connect(func(): fechou.append(1))
	_checar(GameState.flag("ui_aberta") == true, "diploma abre como modal")
	dip.fechar()
	await create_timer(0.3).timeout
	_checar(fechou == [1] and not GameState.flag("ui_aberta"), "diploma fecha e libera o mouse")

	var Morte = load("res://ui/morte.gd")
	var mo = Morte.mostrar("teste")
	await process_frame
	await process_frame
	var seguiu := []
	mo.terminou.connect(func(): seguiu.append(1))
	mo.continuar()
	await create_timer(0.5).timeout
	_checar(seguiu == [1], "tela de morte emite terminou")

	var FimDemo = load("res://ui/fim_demo.gd")
	var fim = FimDemo.mostrar()
	await process_frame
	await process_frame
	_checar(fim.texto_estatisticas().contains("Selos"), "fim da demo mostra estatísticas")
	fim.queue_free()
	Flash.resetar_ui()
	await _teste_telas_v2()


# ---------------------------------------------------------------- telas da V2
func _teste_telas_v2() -> void:
	print("-- Telas V2: VolteSempre, Telefone, Dedicatoria")
	# VolteSempre: 1ª vez alegre, 2ª estranha; termina e se remove
	var VS = load("res://ui/volte_sempre.gd")
	var a = VS.mostrar(1)
	await process_frame
	await process_frame
	_checar(not a.estranho, "Volte sempre (1ª vez) é a versão normal")
	var fim_a := []
	a.terminou.connect(func(): fim_a.append(1))
	a.continuar()
	await create_timer(0.5).timeout
	_checar(fim_a == [1] and not GameState.flag("ui_aberta"), "Volte sempre termina e libera a UI")
	var b = VS.mostrar(2)
	await process_frame
	await process_frame
	_checar(b.estranho, "Volte sempre (2ª vez) é a versão estranha")
	for i in 20:
		await process_frame
	b.continuar()
	await create_timer(0.5).timeout
	Flash.resetar_ui()
	GameState.flags.erase("volte_sempre_vezes")
	# Telefone: o chiado mantém o tamanho do texto; a ligação mostra as linhas na caixa "???" e termina
	var Tel = load("res://ui/telefone.gd")
	var original := "O meu filho... ele vinha sempre brincar aí na obra"
	var chiado: String = Tel.chiar(original, 1.0)
	_checar(chiado.length() == original.length() and chiado != original, "chiar() troca letras e mantém o tamanho")
	_checar(Tel.chiar(original, 0.0) == original, "sem força, sem chiado")
	var vistas := []
	Guia.linha_mostrada.connect(func(pers, txt): vistas.append(pers))
	_acelerar(6.0)
	var t = Tel.tocar(["Alô?", "Vocês viram o Tito?"], false)
	await t.terminou
	_checar(vistas == ["???", "???"], "o telefone fala pela caixa '???' (%s)" % str(vistas))
	_checar(not Guia.ocupado(), "Telefone termina e libera o Guia")
	# Dedicatória: texto exato do roteiro, fundo preto, só termina depois de ~6 s
	var Ded = load("res://ui/dedicatoria.gd")
	var d = Ded.mostrar()
	await process_frame
	await process_frame
	_checar(Ded.TEXTO_1 == "Tito é um personagem fictício. As crianças que sofrem violência e abandono não são.", "dedicatória, frase 1 igual ao roteiro")
	_checar(Ded.TEXTO_2 == "Se você desconfia de que uma criança está em perigo: Disque 100 (Direitos Humanos, gratuito, 24h) ou procure o Conselho Tutelar da sua cidade.", "dedicatória, frase 2 igual ao roteiro (Disque 100, Conselho Tutelar)")
	_checar(d.texto_dedicatoria() == Ded.TEXTO_1 + "\n" + Ded.TEXTO_2, "o que o jogador lê é exatamente o texto do roteiro")
	_checar(d._fundo.color == Color.BLACK, "fundo preto")
	var fim_d := []
	d.terminou.connect(func(): fim_d.append(1))
	d.avancar()   # ainda nos créditos (menos de 2 s): não pula
	_checar(d.fase == "creditos", "créditos não pulam nos primeiros 2 s")
	d._t_fase = 3.0
	d.avancar()
	_checar(d.fase == "dedicatoria", "depois de 2 s os créditos pulam para a dedicatória")
	d.avancar()
	_checar(fim_d.is_empty() and d.fase == "dedicatoria", "a dedicatória NÃO termina antes de ~6 s")
	d._t_fase = 6.5
	d.avancar()
	await create_timer(0.8).timeout
	_checar(fim_d == [1], "depois de 6 s, clique/Enter termina")
	Flash.resetar_ui()


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1
