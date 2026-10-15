extends CidadeBase
## LUGAR DA CIDADE: Rua das casas de veraneio (Módulo 14). ESQUELETO: a base (`cidade_base.gd`) já dá ambiente, chão, borda invisível, rede de
## segurança, HUD, portão "Voltar ao Castelinho", pistas e `concluir()`. O MIOLO (cenário, tarefa, textos) é do agente deste lugar:
## troque tudo o que estiver marcado "TODO miolo" e mantenha os ganchos `_configurar()`, `_construir()` e `_tarefa()`.
## Quarteirão de casas de veraneio fechadas (a cidade esvazia fora do verão); uma tem a luz acesa. Tarefa do miolo: achar a casa certa pelos números fora de ordem, abrir o portão e entrar no quarto de 1967 com o Visor. Casas e pessoas FICTÍCIAS.
## Tabela: `GameState.CIDADE["casas"]` (abre depois da visita 1; pistas: casas_caderno, casas_mala). Teste: `tests/cidade_casas_test.gd` (crie).


func _configurar() -> void:
	id = "casas"
	area = Rect2(-30.0, -18.0, 60.0, 36.0)       # AREA jogável (x, z, largura, profundidade); a borda invisível e a rede de segurança usam isto
	hora = Hora.FIM_DE_TARDE
	clima = Clima.LIMPO
	spawn_pos = Vector3(-24.0, 0.1, 0.0)
	spawn_yaw = -90.0
	usa_visor = true          # o quarto de 1967 só aparece pelo Visor (disco 1967)


func _material_chao() -> Material:
	return mat_asfalto()


func _construir() -> void:
	# TODO miolo: o quarteirão (casas fechadas, números fora de ordem, a casa da luz acesa, o portão, o quarto de 1967).
	var parede := Ato2Pecas.mat_cor(Color(0.82, 0.72, 0.6))
	Construtor.caixa(self, Vector3(9.0, 3.0, 8.0), Vector3(-8.0, 1.5, -12.0), parede, true, "CasaPlaceholderA")
	Construtor.caixa(self, Vector3(9.0, 3.0, 8.0), Vector3(8.0, 1.5, 12.0), parede, true, "CasaPlaceholderB")
	poste(Vector3(-16.0, 0.0, 5.0))


func _tarefa() -> void:
	# TODO miolo: a tarefa de verdade (achar, abrir, escolher, escapar) e o texto do objetivo que o Mapa (M) mostra em "Agora:".
	definir_objetivo("Ache a casa da luz acesa e entre no quarto de 1967 com o Visor.")
	# TODO miolo: troque este objeto de teste pela pista de verdade.
	_marca_teste(Vector3(-14.0, 0.0, -4.0), "PistaTeste0")
	interagivel("Olhar o caderno", Vector3(-14.0, 0.0, -4.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: pista("casas_caderno", ["[placeholder] Um caderno de desenhos esquecido."]))
	# TODO miolo: troque este objeto de teste pela pista de verdade.
	_marca_teste(Vector3(-6.0, 0.0, 5.0), "PistaTeste1")
	interagivel("Olhar a mala", Vector3(-6.0, 0.0, 5.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: pista("casas_mala", ["[placeholder] Uma mala feita às pressas."]))
	# TODO miolo: quando a tarefa de verdade acabar, chame concluir() (grava "cidade_casas_feito" e volta à calçada).
	_marca_teste(Vector3(6.0, 0.0, 0.0), "TarefaTeste", Color(0.2, 1.0, 0.4))
	interagivel("Abrir o portão (tarefa de teste)", Vector3(6.0, 0.0, 0.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: concluir())


## Cubo de teste bem visível (placeholder). TODO miolo: apague.
func _marca_teste(pos: Vector3, nome: String, cor := Color(1.0, 0.1, 0.9)) -> MeshInstance3D:
	return Construtor.caixa(self, Vector3(0.5, 0.5, 0.5), pos + Vector3(0.0, 0.25, 0.0), Ato2Pecas.mat_cor(cor, true), false, nome)
