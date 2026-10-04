extends CanvasLayer
## Caixa de fala dos mascotes (Turma da Memória). STUB do M0: a versão visual estilo Flash vem no M2.
## API estável:
##   await Guia.falar("bentinho", ["Oi!", "Bem-vindo!"])          # não bloqueia o movimento
##   await Guia.falar("taina", [...], true)                        # bloqueia o movimento até terminar
##   Guia.ocupado() -> bool
## Personagens: "bentinho" (boto), "taina" (tainha), "quico" (quero-quero), "sistema", "???".

signal fala_terminou

var _ocupado := false


func falar(personagem: String, linhas: Array, _bloquear := false) -> void:
	_ocupado = true
	for l in linhas:
		print("[%s] %s" % [personagem, l])
	await get_tree().process_frame
	_ocupado = false
	fala_terminou.emit()


func ocupado() -> bool:
	return _ocupado
