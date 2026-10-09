extends Node
## Áudio global. Todos os sons são sintetizados por tools/gerar_audio.py (assets/audio/*.wav|ogg).
## API estável (só adicionamos parâmetros opcionais e funções novas):
##   Audio.sfx(nome, volume_db := 0.0, pitch := 1.0)   efeito curto (pool de players)
##   Audio.sfx_3d(nome, posicao, volume_db := 0.0)     efeito posicional (player 3D temporário)
##   Audio.musica(nome, fade := 1.0)                   troca a música com crossfade ("" = silêncio)
##   Audio.ambiente(nome, volume_db := -8.0, fade := 1.5)   loop de fundo ("vento", "mar", "rio"; "" para)
##   Audio.passo()                                     passo do jogador (3 variações, pitch aleatório)
##
## Nomes: "clique", "boing", "blip_bentinho", "blip_taina", "blip_quico", "blip_sistema", "blip_misterio",
## "acerto", "erro", "selo", "confete", "fanfarra", "passo", "ofego", "susto", "apito", "telefone", "porta",
## "agua_puxa" (ou "água_puxa"), "chiado_radio", "glitch", "slide" (Visor do Tempo), "sussurro", "splash",
## "tarrafa", "vento", "mar", "rio", "jingle_0/1/2".
## V2: loops de ambiente "chuva" e "goteira" (Audio.ambiente); efeitos "agua_sobe", "crianca_ei" (sussurro "ei... aqui..."
## de ruído filtrado, o texto vai na tela), "telefone_voz" (a mãe do Tito, chiada) e "atencao" (UM batimento de 0,6 s:
## o Visor o repete mais depressa e mais alto conforme a atenção sobe). Revisão V2: "trovao" (trovão distante, visita 4).
## Módulo 6 (porão e Braço Morto): "susto_agua", "susto_perto", "susto_queda" (opção "sfx" do Susto), "voz_tito" (murmúrio
## abafado sem palavras), "afundar", "figura_sobe", "figura_afunda", "pista" (nova pista no HUD) e o loop "subaquatico"
## (já sai abafado do arquivo, porque o filtro de bus não funciona na web).
##
## Música "jingle": a versão tocada acompanha GameState.corruption (o modo Sample da web não aceita
## efeitos de bus, então as três versões foram pré-renderizadas):
##   corruption < 0.2   jingle_0  normal
##   corruption < 0.5   jingle_1  meio tom abaixo, mais lento, um instrumento a menos
##   corruption >= 0.5  jingle_2  desafinado, lento, com ruído
## `Audio.musica("jingle_1")` (nome explícito) toca aquele arquivo fixo, sem troca automática.

const CAMINHO := "res://assets/audio/"
const TAMANHO_POOL := 10
const LIMIAR_JINGLE_1 := 0.2
const LIMIAR_JINGLE_2 := 0.5
const SILENCIO_DB := -60.0

## Ajuste de volume por som (os arquivos são normalizados no mesmo pico).
const VOLUME_PADRAO := {
	"erro": -7.0, "glitch": -8.0, "telefone": -3.0, "susto": -1.0, "fanfarra": -5.0,
	"blip_bentinho": -8.0, "blip_taina": -8.0, "blip_quico": -9.0, "blip_sistema": -9.0,
	"blip_misterio": -6.0, "clique": -5.0, "boing": -4.0, "passo_1": -5.0, "passo_2": -5.0, "passo_3": -5.0,
	"vento": -4.0, "mar": -4.0, "rio": -4.0, "ofego": -3.0, "confete": -3.0, "sussurro": -2.0, "slide": -4.0,
	"chuva": -6.0, "goteira": -5.0, "agua_sobe": -3.0, "crianca_ei": -3.0, "telefone_voz": -3.0, "atencao": -2.0,
	"trovao": -3.0,
	"susto_agua": -2.0, "susto_perto": -2.0, "susto_queda": -2.0, "voz_tito": -2.0, "afundar": -3.0,
	"subaquatico": -6.0, "figura_sobe": -2.0, "figura_afunda": -2.0, "pista": -3.0,
}

var volume_musica_db := -9.0
var _pool: Array[AudioStreamPlayer] = []
var _prox_pool := 0
var _cache := {}
var _cache_loop := {}
var _musica_players: Array[AudioStreamPlayer] = []
var _musica_idx := 0
var _musica_nome := ""       # o que foi pedido: "jingle", "jingle_1", "vento"...
var _musica_arquivo := ""    # o arquivo que está de fato tocando
var _ambiente_player: AudioStreamPlayer
var _ambiente_nome := ""
var _tweens := {}            # AudioStreamPlayer -> Tween (um por player)
var _ultimo_passo := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in TAMANHO_POOL:
		var p := AudioStreamPlayer.new()
		p.name = "Sfx%d" % i
		add_child(p)
		_pool.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.name = "Musica%d" % i
		m.volume_db = SILENCIO_DB
		add_child(m)
		_musica_players.append(m)
	_ambiente_player = AudioStreamPlayer.new()
	_ambiente_player.name = "Ambiente"
	_ambiente_player.volume_db = SILENCIO_DB
	add_child(_ambiente_player)
	GameState.corruption_mudou.connect(_ao_mudar_corruption)


# ---------------------------------------------------------------- efeitos
func sfx(nome: String, volume_db := 0.0, pitch := 1.0) -> void:
	var n := _normalizar(nome)
	if n == "passo":
		passo()
		return
	var s := _carregar(n)
	if s == null:
		return
	var p := _jogador_livre()
	p.stream = s
	p.volume_db = volume_db + VOLUME_PADRAO.get(n, 0.0)
	p.pitch_scale = pitch
	p.play()


func sfx_3d(nome: String, posicao: Vector3, volume_db := 0.0) -> void:
	var n := _normalizar(nome)
	if n == "passo":
		n = "passo_%d" % randi_range(1, 3)
	var s := _carregar(n)
	if s == null:
		return
	var p := AudioStreamPlayer3D.new()
	p.stream = s
	p.volume_db = volume_db + VOLUME_PADRAO.get(n, 0.0)
	p.unit_size = 5.0
	p.max_distance = 40.0
	p.finished.connect(p.queue_free)
	var pai: Node = get_tree().current_scene if get_tree().current_scene else get_tree().root
	pai.add_child(p)
	p.global_position = posicao
	p.play()


func passo() -> void:
	var i := randi_range(1, 3)
	if i == _ultimo_passo:
		i = i % 3 + 1
	_ultimo_passo = i
	var s := _carregar("passo_%d" % i)
	if s == null:
		return
	var p := _jogador_livre()
	p.stream = s
	p.volume_db = VOLUME_PADRAO.get("passo_%d" % i, 0.0) + randf_range(-2.0, 0.5)
	p.pitch_scale = randf_range(0.92, 1.08)
	p.play()


# ---------------------------------------------------------------- música e ambiente
func musica(nome: String, fade := 1.0) -> void:
	var n := _normalizar(nome)
	if n == _musica_nome and _tocando(_musica_players[_musica_idx]):
		return
	_musica_nome = n
	if n == "":
		_musica_arquivo = ""
		_fade(_musica_players[_musica_idx], SILENCIO_DB, fade, true)
		return
	var arquivo := _arquivo_jingle(GameState.corruption) if n == "jingle" else n
	_trocar_musica(arquivo, fade, 0.0)


func musica_atual() -> String:
	return _musica_arquivo


## Loop de fundo (vento, mar, rio) que fica sob a música. "" para.
func ambiente(nome: String, volume_db := -8.0, fade := 1.5) -> void:
	var n := _normalizar(nome)
	if n == _ambiente_nome and _tocando(_ambiente_player):
		_fade(_ambiente_player, volume_db + VOLUME_PADRAO.get(n, 0.0), fade, false)
		return
	_ambiente_nome = n
	if n == "":
		_fade(_ambiente_player, SILENCIO_DB, fade, true)
		return
	var s := _carregar_loop(n)
	if s == null:
		return
	_ambiente_player.stream = s
	_ambiente_player.volume_db = SILENCIO_DB
	_ambiente_player.play(randf() * s.get_length())
	_fade(_ambiente_player, volume_db + VOLUME_PADRAO.get(n, 0.0), fade, false)


func silenciar(fade := 0.5) -> void:
	musica("", fade)
	ambiente("", -8.0, fade)


func _arquivo_jingle(corr: float) -> String:
	if corr >= LIMIAR_JINGLE_2:
		return "jingle_2"
	if corr >= LIMIAR_JINGLE_1:
		return "jingle_1"
	return "jingle_0"


func _ao_mudar_corruption(valor: float) -> void:
	if _musica_nome != "jingle":
		return
	var novo := _arquivo_jingle(valor)
	if novo == _musica_arquivo:
		return
	var atual := _musica_players[_musica_idx]
	var fracao := 0.0
	if atual.stream and atual.stream.get_length() > 0.0:
		fracao = atual.get_playback_position() / atual.stream.get_length()
	_trocar_musica(novo, 2.5, fracao)


func _trocar_musica(arquivo: String, fade: float, fracao: float) -> void:
	if arquivo == _musica_arquivo and _tocando(_musica_players[_musica_idx]):
		return
	var s := _carregar_loop(arquivo)
	if s == null:
		return
	var antigo := _musica_players[_musica_idx]
	_musica_idx = 1 - _musica_idx
	var novo := _musica_players[_musica_idx]
	_matar_tween(novo)
	novo.stream = s
	novo.volume_db = SILENCIO_DB if fade > 0.0 else volume_musica_db
	novo.play(clampf(fracao, 0.0, 0.999) * s.get_length())
	_musica_arquivo = arquivo
	if fade > 0.0:
		_fade(novo, volume_musica_db, fade, false)
		_fade(antigo, SILENCIO_DB, fade, true)
	else:
		antigo.stop()


func _fade(p: AudioStreamPlayer, destino_db: float, dur: float, parar_no_fim: bool) -> void:
	_matar_tween(p)
	if dur <= 0.0:
		p.volume_db = destino_db
		if parar_no_fim:
			p.stop()
		return
	var t := create_tween()
	t.tween_property(p, "volume_db", destino_db, dur)
	if parar_no_fim:
		t.tween_callback(p.stop)
	_tweens[p] = t


func _matar_tween(p: AudioStreamPlayer) -> void:
	var t = _tweens.get(p)
	if t is Tween and t.is_valid():
		t.kill()
	_tweens.erase(p)


func _tocando(p: AudioStreamPlayer) -> bool:
	return p.playing


# ---------------------------------------------------------------- carregamento
func _jogador_livre() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	_prox_pool = (_prox_pool + 1) % _pool.size()   # tudo ocupado: rouba o mais antigo (rodízio)
	return _pool[_prox_pool]


func _carregar(nome: String) -> AudioStream:
	if _cache.has(nome):
		return _cache[nome]
	var s: AudioStream = null
	for ext in ["ogg", "wav"]:
		var caminho := "%s%s.%s" % [CAMINHO, nome, ext]
		if ResourceLoader.exists(caminho):
			s = load(caminho)
			break
	if s == null:
		push_warning("Audio: som '%s' não encontrado em %s" % [nome, CAMINHO])
	_cache[nome] = s
	return s


## Cópia em loop (o original, usado por sfx(), nunca repete).
func _carregar_loop(nome: String) -> AudioStream:
	if _cache_loop.has(nome):
		return _cache_loop[nome]
	var base := _carregar(nome)
	if base == null:
		return null
	var s: AudioStream = base.duplicate()
	if s is AudioStreamOggVorbis:
		s.loop = true
	elif s is AudioStreamWAV:
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.get_length() * s.mix_rate)
	_cache_loop[nome] = s
	return s


## minúsculas, sem acento, espaço vira "_": "Água Puxa" -> "agua_puxa".
func _normalizar(nome: String) -> String:
	var n := nome.strip_edges().to_lower().replace(" ", "_")
	for par in [["á", "a"], ["à", "a"], ["â", "a"], ["ã", "a"], ["é", "e"], ["ê", "e"], ["í", "i"],
			["ó", "o"], ["ô", "o"], ["õ", "o"], ["ú", "u"], ["ç", "c"]]:
		n = n.replace(par[0], par[1])
	return n
