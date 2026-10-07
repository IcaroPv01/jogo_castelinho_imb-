class_name Telefone
extends Node
## A voz da mãe do Tito no telefone do acervo (V2 §3.2). Ela é FICÇÃO e nunca tem nome: só voz, num fio ruim.
##
##   await Telefone.tocar(["Alô? É do Castelinho?",
##       "O meu filho... ele vinha sempre brincar aí na obra...", "Vocês viram o Tito?"]).terminou
##
## Toca o telefone (som "telefone"), atende (clique) e mostra cada linha na caixa "???" do Guia (VT323 vermelho sobre
## preto), com o som "telefone_voz" (murmúrio de ruído filtrado, nada de voz sintetizada) e CHIADO: algumas letras
## viram `#`, `%`, `·` e a linha às vezes falha no meio ("Vocês vi%%%u o Ti·o?"). O jogador fica travado durante a
## ligação (as falas são bloqueantes, o botão de avançar é o do Guia). Desliga com um clique e `terminou` sai.
##   Telefone.tocar(linhas, false)   sem o toque (quando o nível já tocou o telefone)
##   Telefone.chiar(texto, forca)    a função de chiado (estática, para testes)
## Texto original sempre inteiro em `Telefone.linhas_limpas` (a legenda real fica na tela, sem esconder o que ela diz).

signal terminou

var linhas_limpas: Array = []
var _com_toque := true
var _executando := false
var _feito := false


static func tocar(linhas: Array, com_toque := true) -> Telefone:
	var t := Telefone.new()
	t.linhas_limpas = linhas.duplicate()
	t._com_toque = com_toque
	Flash.raiz().add_child.call_deferred(t)
	return t


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_executar()


func _executar() -> void:
	if _executando:
		return
	_executando = true
	if _com_toque:
		Audio.sfx("telefone")
		await get_tree().create_timer(2.3, false).timeout
		Audio.sfx("clique", -2.0, 0.8)
		await get_tree().create_timer(0.35, false).timeout
	for i in linhas_limpas.size():
		Audio.sfx("telefone_voz")
		Efeitos.pulso(0.25, 0.3)
		await Guia.falar("???", [chiar(str(linhas_limpas[i]), 0.07 + 0.04 * i)], true)
		if i < linhas_limpas.size() - 1:
			Audio.sfx("chiado_radio", -10.0)
	Audio.sfx("clique", -2.0, 0.7)
	Audio.sfx("chiado_radio", -6.0)   # o fio cai
	await get_tree().create_timer(0.5, false).timeout
	_feito = true
	terminou.emit()
	queue_free()


## Chiado da linha: `forca` (0..1) é a chance de cada letra virar ruído; uma falha curta pode comer um pedaço.
static func chiar(texto: String, forca := 0.08) -> String:
	var ruido := ["#", "%", "·", "~", "*"]
	var saida := ""
	var falha := 0
	for ch in texto:
		if falha > 0:
			falha -= 1
			saida += ruido[randi() % ruido.size()] if ch != " " else " "
			continue
		if ch != " " and ch not in ".,?!" and randf() < forca:
			saida += ruido[randi() % ruido.size()]
			if randf() < 0.18:
				falha = randi_range(1, 3)
		else:
			saida += ch
	return saida
