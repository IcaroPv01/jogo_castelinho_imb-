class_name AguaFerrugem
extends Node
## A água do porão fica ferrugem escura e turva quando a Figura está por perto (V2 §6.1: a água "sabe" de quem está
## chegando). Filho do nível do porão (`AguaFerrugem.instalar(self)`); mexe só nos uniforms `tint_cor` e
## `tint_quantidade` do shader (shaders/porao_agua.gdshader) do material `mat_agua`.
##
## Tinge enquanto: a Figura (visível) está a menos de DIST_FIGURA do jogador; nas salas 90 e 94 enquanto ela persegue;
## e durante o susto J2 (sala 86: rosto e mãos na água). Sobe em ~0,7 s e volta ao normal em ~2 s depois que acaba.
## Nunca na sala 95 (o quarto do Tito, seco) nem no Braço Morto (outro nível, sem este nó).

## A cor da água turva. É a ÚNICA constante a mexer para mudar o tom (a quantidade vai de 0 a 1 por cima da água normal).
const COR_AGUA_FERRUGEM := Color(0.32, 0.08, 0.05)
const DIST_FIGURA := 6.0             # m: perto o bastante para a água "sentir"
const TEMPO_SUBIR := 0.7             # s até a cor cheia
const TEMPO_VOLTAR := 2.0            # s para voltar ao normal depois
const SEGURAR_J2 := 1.4              # s que a água fica turva depois que o susto J2 dispara (ele dura ~1 s)
const IDX_SALAS_PERSEGUICAO: Array[int] = [9, 13]       # salas 90 e 94 (índice = sala - 81)
const IDX_QUARTO := 14                                  # sala 95

var nivel: Node
var quantidade := 0.0                # 0..1, o valor que está no shader
var _segurar := 0.0
var _j2_visto := false


static func instalar(n: Node) -> AguaFerrugem:
	var a := AguaFerrugem.new()
	a.name = "AguaFerrugem"
	a.nivel = n
	n.add_child(a)
	return a


func _ready() -> void:
	_j2_visto = Susto.ja_aconteceu("porao_j2")       # numa partida retomada o J2 já passou: não turva ao carregar
	_aplicar()


func _process(dt: float) -> void:
	if nivel == null or not is_instance_valid(nivel):
		return
	if not _j2_visto and Susto.ja_aconteceu("porao_j2"):
		_j2_visto = true
		_segurar = SEGURAR_J2
	_segurar = maxf(0.0, _segurar - dt)
	var alvo := 1.0 if alvo_ativo() else 0.0
	quantidade = move_toward(quantidade, alvo, dt / (TEMPO_SUBIR if alvo > quantidade else TEMPO_VOLTAR))
	_aplicar()


## A água deve estar turva agora? (público para o teste)
func alvo_ativo() -> bool:
	var idx: int = nivel.get("idx_atual") if nivel.get("idx_atual") != null else -1
	if idx == IDX_QUARTO or idx < 0:
		return false
	if _segurar > 0.0:
		return true
	var fig: Node3D = nivel.get("figura") as Node3D
	var jogador: Node3D = nivel.get("player") as Node3D
	if fig == null or jogador == null or not is_instance_valid(fig) or not is_instance_valid(jogador) or not fig.visible:
		return false
	if idx in IDX_SALAS_PERSEGUICAO and fig.get("ativa") == true:
		return true
	return fig.global_position.distance_to(jogador.global_position) < DIST_FIGURA


func _aplicar() -> void:
	var mat := nivel.get("mat_agua") as ShaderMaterial if nivel != null and is_instance_valid(nivel) else null
	if mat == null:
		return
	mat.set_shader_parameter("tint_cor", COR_AGUA_FERRUGEM)
	mat.set_shader_parameter("tint_quantidade", quantidade)
