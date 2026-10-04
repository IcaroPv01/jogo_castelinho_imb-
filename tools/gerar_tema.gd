extends SceneTree
## Gera ui/tema_flash.tres (tema "Flash educativo"). Rode depois de `godot --headless --import`:
##   godot --headless -s res://tools/gerar_tema.gd
## O .tres resultante é um recurso normal: pode ser editado no Godot depois, mas rodar este
## script de novo sobrescreve tudo. Fontes e cores vêm de ui/flash.gd.


var F   # script de ui/flash.gd, carregado em runtime (ele usa autoloads, que não existem ao compilar este arquivo)


func _initialize() -> void:
	_rodar.call_deferred()


func _rodar() -> void:
	F = load("res://ui/flash.gd")
	var t := Theme.new()
	var f_texto: Font = F.fonte_texto()
	var f_titulo: Font = F.fonte_titulo()
	t.default_font = f_texto
	t.default_font_size = 22

	# ---- Label: branco com contorno azul-marinho (legível sobre o 3D); telas próprias usam variações.
	t.set_font("font", "Label", f_texto)
	t.set_font_size("font_size", "Label", 22)
	t.set_color("font_color", "Label", Color.WHITE)
	t.set_color("font_outline_color", "Label", F.NAVY)
	t.set_constant("outline_size", "Label", 5)
	t.set_color("font_shadow_color", "Label", Color(0, 0, 0, 0))

	# variações de Label
	t.set_type_variation("RotuloEscuro", "Label")
	t.set_color("font_color", "RotuloEscuro", F.NAVY)
	t.set_constant("outline_size", "RotuloEscuro", 0)
	t.set_type_variation("RotuloTitulo", "Label")
	t.set_font("font", "RotuloTitulo", f_titulo)
	t.set_font_size("font_size", "RotuloTitulo", 40)
	t.set_color("font_color", "RotuloTitulo", F.AMARELO)
	t.set_constant("outline_size", "RotuloTitulo", 10)
	t.set_type_variation("RotuloErro", "Label")
	t.set_font("font", "RotuloErro", F.fonte_erro())
	t.set_font_size("font_size", "RotuloErro", 30)
	t.set_color("font_color", "RotuloErro", Color("E01B24"))
	t.set_constant("outline_size", "RotuloErro", 0)

	# ---- Button (gel azul) + variações de cor
	_botao(t, "Button", F.AZUL, f_titulo)
	_botao_variacao(t, "BotaoVerde", F.VERDE, f_titulo)
	_botao_variacao(t, "BotaoAmarelo", F.AMARELO, f_titulo)
	_botao_variacao(t, "BotaoVermelho", F.VERMELHO, f_titulo)
	_botao_variacao(t, "BotaoRosa", F.ROSA, f_titulo)
	_botao_variacao(t, "BotaoCinza", Color("8E99A8"), f_titulo)

	# ---- Painéis
	var painel: StyleBoxFlat = F.caixa(F.CREME, F.NAVY, 18, 5)
	painel.content_margin_left = 16
	painel.content_margin_right = 16
	painel.content_margin_top = 12
	painel.content_margin_bottom = 12
	t.set_stylebox("panel", "Panel", painel)
	t.set_stylebox("panel", "PanelContainer", painel.duplicate())
	t.set_type_variation("PainelAzul", "PanelContainer")
	t.set_stylebox("panel", "PainelAzul", F.caixa(F.AZUL, F.NAVY, 18, 5))
	t.set_type_variation("PainelAmarelo", "PanelContainer")
	t.set_stylebox("panel", "PainelAmarelo", F.caixa(F.AMARELO, F.NAVY, 18, 5))

	# ---- ProgressBar (stamina e barras de progresso)
	var fundo_barra: StyleBoxFlat = F.caixa(Color.WHITE, F.NAVY, 8, 3, false)
	fundo_barra.content_margin_left = 3
	fundo_barra.content_margin_right = 3
	fundo_barra.content_margin_top = 2
	fundo_barra.content_margin_bottom = 2
	var enchimento: StyleBoxFlat = F.caixa(F.VERDE, F.NAVY, 6, 2, false)
	t.set_stylebox("background", "ProgressBar", fundo_barra)
	t.set_stylebox("fill", "ProgressBar", enchimento)
	t.set_font("font", "ProgressBar", f_titulo)
	t.set_color("font_color", "ProgressBar", F.NAVY)

	# ---- LineEdit / separadores / barras de rolagem
	var campo: StyleBoxFlat = F.caixa(Color.WHITE, F.NAVY, 10, 3, false)
	campo.content_margin_left = 10
	campo.content_margin_right = 10
	t.set_stylebox("normal", "LineEdit", campo)
	t.set_color("font_color", "LineEdit", F.NAVY)
	t.set_stylebox("grabber", "VScrollBar", F.caixa(F.AMARELO, F.NAVY, 8, 3, false))
	t.set_stylebox("grabber_highlight", "VScrollBar", F.caixa(F.AMARELO.lightened(0.2), F.NAVY, 8, 3, false))
	t.set_stylebox("grabber_pressed", "VScrollBar", F.caixa(F.LARANJA, F.NAVY, 8, 3, false))
	t.set_stylebox("scroll", "VScrollBar", F.caixa(Color("DDE9FF"), F.NAVY, 8, 2, false))

	var erro := ResourceSaver.save(t, "res://ui/tema_flash.tres")
	print("tema salvo: ", "OK" if erro == OK else "ERRO %d" % erro)
	quit(0 if erro == OK else 1)


func _botao(t: Theme, tipo: String, cor: Color, fonte: Font) -> void:
	var raio := 22
	var normal: StyleBoxFlat = F.caixa(cor, F.NAVY, raio, 5)
	var hover: StyleBoxFlat = F.caixa(cor.lightened(0.16), F.NAVY, raio, 5)
	var apertado: StyleBoxFlat = F.caixa(cor.darkened(0.14), F.NAVY, raio, 5)
	apertado.shadow_offset = Vector2(0, 1)
	var desativado: StyleBoxFlat = F.caixa(F.dessaturar(cor, 0.85).lightened(0.2), Color("6B7280"), raio, 5, false)
	for s: StyleBoxFlat in [normal, hover, apertado, desativado]:
		s.content_margin_left = 24
		s.content_margin_right = 24
		s.content_margin_top = 8
		s.content_margin_bottom = 12
	var foco := StyleBoxFlat.new()
	foco.draw_center = false
	foco.border_color = F.AMARELO
	foco.set_border_width_all(4)
	foco.set_corner_radius_all(raio + 4)
	foco.expand_margin_left = 4
	foco.expand_margin_right = 4
	foco.expand_margin_top = 4
	foco.expand_margin_bottom = 4
	t.set_stylebox("normal", tipo, normal)
	t.set_stylebox("hover", tipo, hover)
	t.set_stylebox("pressed", tipo, apertado)
	t.set_stylebox("disabled", tipo, desativado)
	t.set_stylebox("focus", tipo, foco)
	t.set_font("font", tipo, fonte)
	t.set_font_size("font_size", tipo, 26)
	t.set_color("font_color", tipo, Color.WHITE)
	t.set_color("font_hover_color", tipo, Color.WHITE)
	t.set_color("font_pressed_color", tipo, Color("FFF6C0"))
	t.set_color("font_focus_color", tipo, Color.WHITE)
	t.set_color("font_disabled_color", tipo, Color("DDE2EA"))
	t.set_color("font_outline_color", tipo, F.NAVY)
	t.set_constant("outline_size", tipo, 5)


func _botao_variacao(t: Theme, nome: String, cor: Color, fonte: Font) -> void:
	t.set_type_variation(nome, "Button")
	_botao(t, nome, cor, fonte)
