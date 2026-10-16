extends SceneTree
## Dica de quem está parado (world/dica_ao_travar.gd): só fala depois do tempo, só livre, recomeça ao avançar.

var falhas := 0


func _checar(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  FALHA ") + msg)
	if not cond:
		falhas += 1


func _initialize() -> void:
	var D = load("res://world/dica_ao_travar.gd")
	var d = D.new()
	root.add_child(d)
	_checar(d.passo(1.0, true, "a") == -1, "primeira chamada só registra o objetivo")
	_checar(d.passo(60.0, true, "a") == -1, "60 s parado ainda não fala")
	_checar(d.passo(31.0, true, "a") == 0, "passou de 90 s: 1ª dica")
	_checar(d.passo(100.0, true, "a") == -1, "100 s depois ainda não (2ª espera é 150 s)")
	_checar(d.passo(50.0, true, "a") == 1, "150 s: 2ª dica")
	_checar(d.passo(210.0, true, "a") == 2, "210 s: 3ª dica")
	_checar(d.passo(9999.0, true, "a") == -1, "depois da 3ª, nunca mais para o mesmo objetivo")
	_checar(d.passo(5.0, true, "b") == -1 and d.passo(89.0, true, "b") == -1, "objetivo novo recomeça do zero")
	_checar(d.passo(2.0, true, "b") == 0, "e volta a dar dica depois de 90 s")
	_checar(d.passo(500.0, false, "b") == -1, "ocupado (fala/tela/Figura): o tempo não conta")
	var l1: Dictionary = D.linhas(1, "Faça X.", 0)
	var l3: Dictionary = D.linhas(3, "Faça X.", 0)
	var l4: Dictionary = D.linhas(4, "Faça X.", 0)
	_checar(l1.quem == "bentinho" and l3.quem == "sistema" and l4.quem == "???", "cada visita tem a sua voz")
	_checar(l1.linhas[-1] == "Faça X." and l3.linhas[-1] == "Faça X." and l4.linhas[-1] == "Faça X.", "a última linha é o objetivo")
	d.queue_free()
	print("RESULTADO: %s" % ("OK" if falhas == 0 else "%d FALHA(S)" % falhas))
	quit(0 if falhas == 0 else 1)
