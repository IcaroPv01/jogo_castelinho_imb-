class_name RedeSeguranca
extends Node
## Rede de segurança do jogador (playtest do Bernardo, 14/10/2026: "fiquei preso numa parede", "buguei no void",
## "tive que resetar"). Vale para todo nível: `main.carregar_mundo` chama `RedeSeguranca.instalar(nivel, player)`.
##
## - Guarda pontos seguros (no chão, fora de parede, com o jogador livre para andar) a cada 0,25 s.
## - **Void / fora do mapa:** o jogador cai mais de `QUEDA_MAX` m abaixo do chão mais baixo do nível, fica caindo mais
##   de `TEMPO_QUEDA` s, ou sai dos limites do nível (+ `MARGEM` m) → volta ao último ponto seguro.
## - **Preso na parede:** cápsula enfiada na colisão do mundo por mais de `TEMPO_PRESO` s → `Player.desprender()`;
##   se não resolver, volta ao último ponto seguro.
## - `destravar()`: botão "Destravar" do menu de pausa (preso num canto sem estar dentro de parede).
##
## Só usa a API pública do Player (`global_position`, `velocity`, `is_on_floor()`, `pode_mover`, `desprender()`).
## Pulo: supõe pulo baixo (pico <= 1 m) e sem pulo duplo; no ar nunca grava ponto seguro.
## Um nível pode desligar a rede com `func rede_seguranca_ativa() -> bool` (ex.: cena final em que o jogador afunda) e
## dar os limites com `func limites_mapa() -> AABB`; senão a rede mede a colisão estática do nível.

const INTERVALO := 0.25
const MAX_PONTOS := 16          # ~4 s de histórico
const IDADE_MIN := 1.0          # o ponto usado no resgate tem pelo menos 1 s (não é a beira de onde ele caiu)
const QUEDA_MAX := 6.0
const TEMPO_QUEDA := 4.0
const MARGEM := 3.0
const TEMPO_PRESO := 0.6
const REMEDIR := 2.0            # o porão monta e libera salas aos poucos: os limites são medidos de novo

static var atual: RedeSeguranca = null

var nivel: Node3D
var player: Player
var limites := AABB()
var tem_limites := false
var resgates := 0               # para testes e para o log
var ultimo_motivo := ""

var _pontos: Array = []         # [{pos, t}]
var _historico: Array = []      # um ponto a cada 2 s, último minuto (quando os recentes não servem, ex.: corredor de 1975)
var _t_hist := 0.0
var _t := 0.0
var _t_ponto := 0.0
var _t_medir := 0.0
var _t_caindo := 0.0
var _t_preso := 0.0
var _cache_formas := {}         # id da forma -> AABB local (a malha das dunas tem ~58 mil vértices: medir uma vez só)


static func instalar(n: Node3D, p: Player) -> RedeSeguranca:
	var r := RedeSeguranca.new()
	r.name = "RedeSeguranca"
	r.nivel = n
	r.player = p
	n.add_child(r)
	return r


func _ready() -> void:
	atual = self
	process_physics_priority = 10    # depois do Player


func _exit_tree() -> void:
	if atual == self:
		atual = null


func _physics_process(dt: float) -> void:
	if player == null or not is_instance_valid(player) or not player.is_inside_tree():
		return
	_t += dt
	_t_medir -= dt
	if nivel and nivel.has_method("limites_mapa"):
		_medir_limites()             # barato e pode mudar com a época (corredor de 1975)
	elif _t_medir <= 0.0:
		_t_medir = REMEDIR
		_medir_limites()
	if not _ativa():
		_t_caindo = 0.0
		_t_preso = 0.0
		return
	var pos := player.global_position
	var no_chao := player.is_on_floor()
	_t_caindo = 0.0 if no_chao or player.velocity.y >= 0.0 else _t_caindo + dt
	if tem_limites:
		if pos.y < limites.position.y - QUEDA_MAX:
			resgatar("void")
			return
		if not _dentro(pos):
			resgatar("fora_do_mapa")
			return
	if _t_caindo > TEMPO_QUEDA:
		resgatar("queda")
		return
	if _sobrepoe(pos):
		_t_preso += dt
		if _t_preso > TEMPO_PRESO:
			_t_preso = 0.0
			if not player.desprender() or _sobrepoe(player.global_position):
				resgatar("parede")
			return
	else:
		_t_preso = 0.0
	_t_ponto -= dt
	if _t_ponto <= 0.0 and no_chao:
		_t_ponto = INTERVALO
		_pontos.append({"pos": pos, "t": _t})
		if _pontos.size() > MAX_PONTOS:
			_pontos.pop_front()
		if _t - _t_hist >= 2.0:
			_t_hist = _t
			_historico.append(pos)
			if _historico.size() > 30:
				_historico.pop_front()


func _ativa() -> bool:
	if not player.pode_mover or not GameState.jogando or not player.is_physics_processing():
		return false
	if nivel and nivel.has_method("rede_seguranca_ativa") and not nivel.rede_seguranca_ativa():
		return false
	return true


## Leva o jogador ao último ponto seguro (com pelo menos 1 s, fora de parede na época atual). Sem ponto, vai ao
## checkpoint (ou ao Spawn) do nível. Devolve true se moveu.
func resgatar(motivo := "destravar") -> bool:
	ultimo_motivo = motivo
	var destino := Vector3.INF
	for i in range(_pontos.size() - 1, -1, -1):
		var pt: Dictionary = _pontos[i]
		if _t - float(pt["t"]) < IDADE_MIN and motivo != "destravar":
			continue
		if not _sobrepoe(pt["pos"]) and _dentro(pt["pos"]):
			destino = pt["pos"]
			# os pontos mais novos que este levaram ao problema: descarta
			_pontos = _pontos.slice(0, i + 1)
			break
	if destino == Vector3.INF:
		_pontos.clear()
		for i in range(_historico.size() - 1, -1, -1):
			var hp: Vector3 = _historico[i]
			if not _sobrepoe(hp) and _dentro(hp):
				destino = hp
				break
	if destino == Vector3.INF:
		destino = _ponto_do_nivel()
	if destino == Vector3.INF:
		return false
	player.global_position = destino
	player.velocity = Vector3.ZERO
	_t_caindo = 0.0
	_t_preso = 0.0
	resgates += 1
	print("RedeSeguranca: resgate (%s) -> %s" % [motivo, destino])
	if motivo != "destravar":
		Efeitos.aviso("(você se perdeu da visita. De volta ao caminho!)", 2.5)
	return true


## Para o menu de pausa: volta a um ponto seguro mais antigo (preso num canto, num vão sem saída).
func destravar() -> bool:
	if _pontos.size() > 4:
		_pontos = _pontos.slice(0, _pontos.size() - 4)
	return resgatar("destravar")


func _dentro(pos: Vector3) -> bool:
	if not tem_limites:
		return true
	var h := limites.grow(MARGEM)
	return pos.x >= h.position.x and pos.x <= h.end.x and pos.z >= h.position.z and pos.z <= h.end.z


## Mesma conta do Player (cápsula 0,3 x 1,75 um pouco encolhida): a cápsula está dentro da colisão do mundo?
func _sobrepoe(pos: Vector3) -> bool:
	if not player.is_inside_tree():
		return false
	var q := PhysicsShapeQueryParameters3D.new()
	var forma := CapsuleShape3D.new()
	forma.radius = 0.26
	forma.height = 1.67
	q.shape = forma
	q.transform = Transform3D(Basis(), pos + Vector3(0, 0.895, 0))
	q.collision_mask = 1
	q.exclude = [player.get_rid()]
	return not player.get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()


func _ponto_do_nivel() -> Vector3:
	if nivel == null:
		return Vector3.INF
	for nome in ["Checkpoint_%d" % GameState.checkpoint_sala, "Spawn"]:
		var m := nivel.find_child(nome, true, false) as Node3D
		if m and _dentro(m.global_position):
			return m.global_position
	return Vector3.INF


func _medir_limites() -> void:
	if nivel == null:
		return
	if nivel.has_method("limites_mapa"):
		limites = nivel.limites_mapa()
		tem_limites = limites.size != Vector3.ZERO
		return
	var caixa := AABB()
	var achou := false
	for cs: CollisionShape3D in nivel.find_children("*", "CollisionShape3D", true, false):
		var corpo := cs.get_parent() as StaticBody3D
		if corpo == null or (corpo.collision_layer & 1) == 0 or cs.shape == null:
			continue
		var id := cs.shape.get_instance_id()
		if not _cache_formas.has(id):
			_cache_formas[id] = _aabb_da_forma(cs.shape)
		var a: AABB = cs.global_transform * (_cache_formas[id] as AABB)
		if a.size == Vector3.ZERO:
			continue
		caixa = a if not achou else caixa.merge(a)
		achou = true
	if achou:
		# o porão libera salas antigas: os limites só crescem (união com o que já foi medido)
		limites = caixa if not tem_limites else limites.merge(caixa)
		tem_limites = true


static func _aabb_da_forma(s: Shape3D) -> AABB:
	if s is BoxShape3D:
		var t: Vector3 = s.size
		return AABB(-t * 0.5, t)
	if s is ConcavePolygonShape3D or s is ConvexPolygonShape3D:
		var pts: PackedVector3Array = s.get_faces() if s is ConcavePolygonShape3D else s.points
		if pts.is_empty():
			return AABB()
		var a := AABB(pts[0], Vector3.ZERO)
		for v in pts:
			a = a.expand(v)
		return a
	if s is CylinderShape3D or s is CapsuleShape3D:
		var r: float = s.radius
		var h: float = s.height
		return AABB(Vector3(-r, -h * 0.5, -r), Vector3(2 * r, h, 2 * r))
	if s is SphereShape3D:
		var r2: float = s.radius
		return AABB(Vector3.ONE * -r2, Vector3.ONE * 2 * r2)
	if s is WorldBoundaryShape3D or s is HeightMapShape3D:
		return AABB()
	return AABB()
