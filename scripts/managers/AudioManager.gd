extends Node

# Centraliza musica y efectos para que las escenas no manejen audio directamente.
var music_player: AudioStreamPlayer
var sfx_players: Array[AudioStreamPlayer] = []
var music_volume_db: float = -8.0
var sfx_volume_db: float = -2.0
var loaded_streams: Dictionary = {}
var sfx_index: int = 0

func _ready() -> void:
	music_player = AudioStreamPlayer.new()
	music_player.name = "MusicPlayer"
	music_player.bus = "Music"
	add_child(music_player)

	for index in range(4):
		var sfx_player: AudioStreamPlayer = AudioStreamPlayer.new()
		sfx_player.name = "SfxPlayer%d" % index
		sfx_player.bus = "SFX"
		add_child(sfx_player)
		sfx_players.append(sfx_player)

# Reproduce musica desde ruta opcional. Si el archivo no existe, no hace nada.
func play_music_from_path(audio_path: String) -> void:
	var stream: AudioStream = _get_stream(audio_path)
	play_music(stream)

# Reproduce musica de fondo en loop si se entrega un stream valido.
func play_music(stream: AudioStream) -> void:
	if stream == null:
		return
	if music_player.stream == stream and music_player.playing:
		return
	music_player.stream = stream
	music_player.volume_db = music_volume_db
	music_player.play()

# Detiene la musica de fondo actual.
func stop_music() -> void:
	if music_player != null and music_player.playing:
		music_player.stop()

# Reproduce un efecto desde ruta opcional. Si el archivo no existe, no hace nada.
func play_sfx_from_path(audio_path: String) -> void:
	var stream: AudioStream = _get_stream(audio_path)
	play_sfx(stream)

# Reproduce un efecto de sonido corto.
func play_sfx(stream: AudioStream) -> void:
	if stream == null or sfx_players.is_empty():
		return

	var player: AudioStreamPlayer = sfx_players[sfx_index]
	sfx_index = (sfx_index + 1) % sfx_players.size()
	player.stop()
	player.stream = stream
	player.volume_db = sfx_volume_db
	player.play()

# Ajusta el volumen de musica en decibeles.
func set_music_volume(volume_db: float) -> void:
	music_volume_db = volume_db
	if music_player != null:
		music_player.volume_db = music_volume_db

# Ajusta el volumen de efectos en decibeles.
func set_sfx_volume(volume_db: float) -> void:
	sfx_volume_db = volume_db
	for player in sfx_players:
		player.volume_db = sfx_volume_db

# Carga audio bajo demanda y evita errores cuando el asset aun no existe.
func _get_stream(audio_path: String) -> AudioStream:
	if audio_path.is_empty() or not ResourceLoader.exists(audio_path):
		return null
	if loaded_streams.has(audio_path):
		return loaded_streams[audio_path] as AudioStream

	var stream: AudioStream = load(audio_path) as AudioStream
	loaded_streams[audio_path] = stream
	return stream
