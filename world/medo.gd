class_name Medo
extends RefCounted
## O medo do jogador (0..1): quão perto a Figura está. Alimenta a vinheta vermelha da tela (shader do Efeitos) e a
## respiração ofegante (Audio.medo). Duas fontes, vale a maior:
##   - a Figura do SLIDE (Visor): `GameState.atencao` (0,15 = nada, 1 = ela chegou);
##   - a Figura de VERDADE perseguindo (grupo "figura_branca", `ativa`): proximidade em linha reta, de DIST_MAX m até 0.
## Sem Figura por perto (ou com `Debug.figura_off`) devolve 0 e a tela/áudio voltam ao normal sozinhos.

const DIST_MAX := 16.0            # m: a partir daqui a Figura real começa a se fazer sentir
const ATENCAO_INICIO := 0.15      # abaixo disso a atenção não assusta


## Medo causado pela atenção do Visor (a Figura no slide).
static func da_atencao(a: float) -> float:
	return smoothstep(ATENCAO_INICIO, 1.0, a)


## Medo causado pela Figura de verdade em perseguição (a mais próxima), 0 se nenhuma.
static func da_figura_real(arvore: SceneTree) -> float:
	if Debug.figura_off:
		return 0.0
	var jog := arvore.get_first_node_in_group("player") as Node3D
	if jog == null:
		return 0.0
	var melhor := 0.0
	for n in arvore.get_nodes_in_group("figura_branca"):
		var f := n as FiguraBranca
		if f == null or not f.ativa or f.sumida or f.matou or f.estado == FiguraBranca.Est.EMBORA or not f.is_visible_in_tree():
			continue
		var d := Vector2(f.global_position.x - jog.global_position.x, f.global_position.z - jog.global_position.z).length()
		if d >= DIST_MAX:
			continue
		melhor = maxf(melhor, smoothstep(0.0, 1.0, 1.0 - d / DIST_MAX))
	return melhor


static func nivel(arvore: SceneTree) -> float:
	return clampf(maxf(da_atencao(GameState.atencao), da_figura_real(arvore)), 0.0, 1.0)
