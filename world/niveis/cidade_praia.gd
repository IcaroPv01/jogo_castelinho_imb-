extends CidadeBase
## LUGAR DA CIDADE: Praia de Imbé (Módulo 14). ESQUELETO: a base (`cidade_base.gd`) já dá ambiente, chão, borda invisível, rede de
## segurança, HUD, portão "Voltar ao Castelinho", pistas e `concluir()`. O MIOLO (cenário, tarefa, textos) é do agente deste lugar:
## troque tudo o que estiver marcado "TODO miolo" e mantenha os ganchos `_configurar()`, `_construir()` e `_tarefa()`.
## A praia vazia, de noite, com ressaca. Tarefa do miolo: caçar objetos que a maré trouxe e ouvir um sino ao longe. Ligação mais fraca com o Tito: balde e pazinha.
## Tabela: `GameState.CIDADE["praia"]` (abre depois da visita 2; pistas: praia_balde). Teste: `tests/cidade_praia_test.gd` (crie).


func _configurar() -> void:
	id = "praia"
	area = Rect2(-40.0, -40.0, 80.0, 60.0)       # AREA jogável (x, z, largura, profundidade); a borda invisível e a rede de segurança usam isto
	hora = Hora.NOITE
	clima = Clima.RESSACA
	spawn_pos = Vector3(0.0, 0.1, 15.0)
	spawn_yaw = 0.0
	ambiente_audio = "mar"


func _material_chao() -> Material:
	return mat_areia(0.8)


func _construir() -> void:
	# TODO miolo: areia com dunas baixas, mar com ressaca (FORA da AREA), objetos trazidos pela maré, o sino.
	Construtor.caixa(self, Vector3(3.0, 1.0, 2.0), Vector3(-16.0, 0.5, -10.0), mat_areia(0.6), true, "DunaPlaceholder")


func _tarefa() -> void:
	# TODO miolo: a tarefa de verdade (achar, abrir, escolher, escapar) e o texto do objetivo que o Mapa (M) mostra em "Agora:".
	definir_objetivo("Siga o som do sino, ao longe.")
	# TODO miolo: troque este objeto de teste pela pista de verdade.
	_marca_teste(Vector3(10.0, 0.0, -5.0), "PistaTeste0")
	interagivel("Olhar o balde", Vector3(10.0, 0.0, -5.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: pista("praia_balde", ["[placeholder] Um balde e uma pazinha na areia."]))
	# TODO miolo: quando a tarefa de verdade acabar, chame concluir() (grava "cidade_praia_feito" e volta à calçada).
	_marca_teste(Vector3(-12.0, 0.0, -20.0), "TarefaTeste", Color(0.2, 1.0, 0.4))
	interagivel("Achar o sino (tarefa de teste)", Vector3(-12.0, 0.0, -20.0) + Vector3(0.0, 0.5, 0.0), Vector3(1.2, 1.2, 1.2), func(_p: Node) -> void: concluir())


## Cubo de teste bem visível (placeholder). TODO miolo: apague.
func _marca_teste(pos: Vector3, nome: String, cor := Color(1.0, 0.1, 0.9)) -> MeshInstance3D:
	return Construtor.caixa(self, Vector3(0.5, 0.5, 0.5), pos + Vector3(0.0, 0.25, 0.0), Ato2Pecas.mat_cor(cor, true), false, nome)
