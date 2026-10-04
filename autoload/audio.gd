extends Node
## Áudio global. STUB do M0: a implementação completa (jingle, sfx sintetizados, distorção por
## corruption) vem no M2. API estável — use só estas funções:
##   Audio.sfx(nome)            efeito curto (ex.: "clique", "passo", "susto", "selo", "erro")
##   Audio.musica(nome)         troca a música de fundo ("" = silêncio)
##   Audio.passo()              som de passo do jogador
##   Audio.sfx_3d(nome, pos)    efeito posicional


func sfx(_nome: String, _volume_db := 0.0) -> void:
	pass


func sfx_3d(_nome: String, _posicao: Vector3, _volume_db := 0.0) -> void:
	pass


func musica(_nome: String, _fade := 1.0) -> void:
	pass


func passo() -> void:
	pass
