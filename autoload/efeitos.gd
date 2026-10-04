extends CanvasLayer
## Pós-processamento de tela ligado a GameState.corruption (pixelização, pontilhado, cor, grão).
## STUB do M0: o shader real vem no M3. API estável:
##   Efeitos.pulso(intensidade, dur)   glitch momentâneo (susto)
##   Efeitos.visor(ativo)              moldura do Visor do Tempo


func pulso(_intensidade := 1.0, _dur := 0.3) -> void:
	pass


func visor(_ativo: bool) -> void:
	pass
