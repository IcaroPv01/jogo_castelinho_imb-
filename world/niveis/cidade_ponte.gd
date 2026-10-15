extends CidadeBase
## LUGAR DA CIDADE: Ponte à noite (Módulo 14). ESQUELETO: a base (`cidade_base.gd`) já dá ambiente, chão, borda invisível, rede de
## segurança, HUD, portão "Voltar ao Castelinho", pistas e `concluir()`. O MIOLO (cenário, tarefa, textos) é do agente deste lugar:
## troque tudo o que estiver marcado "TODO miolo" e mantenha os ganchos `_configurar()`, `_construir()` e `_tarefa()`.
## A ponte de três pistas à noite, com pescadores de sardinha parados que não saem do lugar. Tarefa do miolo: contar as luzes, não olhar para trás e achar o que a Figura deixou. Lenda do Passo da Mãe Rosa só como cenário, sem pessoa real.
## Tabela: `GameState.CIDADE["ponte"]` (abre depois da visita 3; pistas: ponte_figura). Teste: `tests/cidade_ponte_test.gd` (crie).


func _configurar() -> void:
	id = "ponte"
	area = Rect2(-6.0, -46.0, 12.0, 92.0)       # AREA jogável (x, z, largura, profundidade); a borda invisível e a rede de segurança usam isto
	hora = Hora.NOITE
	clima = Clima.LIMPO
	spawn_pos = Vector3(0.0, 0.1, 40.0)
	spawn_yaw = 0.0
	corrupcao = 0.2
	ambiente_audio = "rio"


func _material_chao() -> Material:
	return mat_asfalto()


func _construir() -> void:
	# TODO miolo: ponte comprida (3 pistas), mureta/grade, pescadores parados, luzes para contar. A AREA é estreita (12 x 92).
	for k in 3:
		poste(Vector3(-5.0, 0.0, 20.0 - k * 22.0), 5.5, k == 0)


func _tarefa() -> void:
	# TODO miolo: a tarefa de verdade (achar, abrir, escolher, escapar) e o texto do objetivo que o Mapa (M) mostra em "Agora:".
	definir_objetivo("Atravesse a ponte sem olhar para trás.")
	# TODO miolo: troque este objeto de teste pela pista de verdade.
	_marca_teste(Vector3(0.0, 0.0, 14.0), "PistaTeste0")
	interagivel("Olhar o que ficou no chão", Vector3(0.0, 0.0, 14.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: pista("ponte_figura", ["[placeholder] Algo foi deixado aqui."]))
	# TODO miolo: quando a tarefa de verdade acabar, chame concluir() (grava "cidade_ponte_feito" e volta à calçada).
	_marca_teste(Vector3(0.0, 0.0, -40.0), "TarefaTeste", Color(0.2, 1.0, 0.4))
	interagivel("Chegar ao outro lado (tarefa de teste)", Vector3(0.0, 0.0, -40.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: concluir())


## Cubo de teste bem visível (placeholder). TODO miolo: apague.
func _marca_teste(pos: Vector3, nome: String, cor := Color(1.0, 0.1, 0.9)) -> MeshInstance3D:
	return Construtor.caixa(self, Vector3(0.5, 0.5, 0.5), pos + Vector3(0.0, 0.25, 0.0), Ato2Pecas.mat_cor(cor, true), false, nome)
