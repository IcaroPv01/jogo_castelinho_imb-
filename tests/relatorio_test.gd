extends SceneTree
## Teste automático (headless) do relatório do menu de pausa: Relatorio.gerar(), buffers e a página nova do MenuPausa.
## Uso: godot --headless -s res://tests/relatorio_test.gd

var falhas := 0


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	var gs: Node = root.get_node("GameState")
	var Rel = load("res://ui/relatorio.gd")
	gs.novo_jogo()
	gs.jogando = false

	print("-- gerar() sem jogador")
	Rel.instalar()
	Rel.instalar()   # idempotente
	var t: String = Rel.gerar()
	_checar(t is String and t != "", "gerar() devolve texto sem jogador nem nível")
	_checar(t.contains("Sala"), "texto tem 'Sala'")
	var nome_epoca: String = str(gs.NOMES_EPOCA[gs.epoca])
	_checar(t.contains(nome_epoca), "texto tem a época (%s)" % nome_epoca)
	_checar(t.contains("Jogador: ?"), "sem jogador = '?'")
	_checar(t.length() <= 1500, "texto <= 1500 caracteres (%d)" % t.length())

	print("-- coletor de erros do motor (Logger)")
	if OS.has_method("add_logger"):
		push_error("teste_relatorio_logger")
		_checar(Rel.gerar().contains("teste_relatorio_logger"), "push_error cai no relatório")

	print("-- buffers")
	for i in 30:
		Rel.registrar_erro("erro numero %d com uma mensagem " % i + "x".repeat(300))
		Rel.registrar_sala(i + 1)
	_checar(Rel.quantos_erros() == 8, "buffer de erros para em 8 (%d)" % Rel.quantos_erros())
	t = Rel.gerar()
	_checar(t.contains("erro numero 29") and not t.contains("erro numero 21 "), "guarda só os últimos erros")
	_checar(t.contains("30@") and not t.contains(" 18@"), "trilha guarda só as últimas 12 salas")
	_checar(t.length() <= 1500, "texto cheio <= 1500 caracteres (%d)" % t.length())
	_checar(Rel.link_whatsapp("a b&c").begins_with("https://wa.me/?text=a%20b%26c"), "link do WhatsApp codificado")

	print("-- menu de pausa")
	var menu = load("res://ui/menu_pausa.gd").new()
	root.add_child(menu)
	await process_frame
	_checar(menu.btn_relatorio != null and menu.btn_relatorio.text == "Enviar relatório", "botão 'Enviar relatório' existe")
	_checar(menu._pag_relatorio != null and not menu._pag_relatorio.visible, "página do relatório começa escondida")
	_checar(menu.caixa_relatorio != null and not menu.caixa_relatorio.editable, "caixa é só leitura")
	_checar(not menu.caixa_relatorio.virtual_keyboard_enabled, "teclado virtual desligado")
	menu.mostrar(true, 0)
	menu.btn_relatorio.pressed.emit()
	_checar(menu._pag_relatorio.visible and not menu._pag_principal.visible, "botão abre a página")
	_checar(menu.caixa_relatorio.text.contains("Sala"), "caixa tem o relatório gerado")
	menu.btn_copiar.pressed.emit()
	_checar(menu.btn_copiar.text == "Copiado!", "Copiar mostra 'Copiado!'")
	var ev := InputEventAction.new()
	ev.action = "pausa"
	ev.pressed = true
	menu._unhandled_input(ev)
	_checar(menu._pag_principal.visible and not menu._pag_relatorio.visible, "Esc volta à página principal")
	menu.queue_free()
	await process_frame

	print("Relatório: %s" % ("OK" if falhas == 0 else "%d falha(s)" % falhas))
	quit(1 if falhas > 0 else 0)


func _checar(cond: bool, msg: String) -> void:
	if cond:
		print("  ok  ", msg)
	else:
		falhas += 1
		print("  FALHOU  ", msg)
