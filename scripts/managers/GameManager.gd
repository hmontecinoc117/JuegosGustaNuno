extends Node

# Controla estado global y datos de sesion del juego.
var current_level: int = 1
var is_game_paused: bool = false
var player_profile: Dictionary = {}

func _ready() -> void:
	load_initial_state()

# Prepara datos base al iniciar la aplicacion.
func load_initial_state() -> void:
	player_profile = SaveManager.load_game()
	current_level = int(player_profile.get("current_level", 1))

# Inicia una partida desde el minijuego activo.
func start_game() -> void:
	open_minigames_menu()

# Abre el catalogo de minijuegos desde el menu principal.
func open_minigames_menu() -> void:
	is_game_paused = false
	SceneManager.go_to_minigames_menu()

# Inicia el minijuego de memorice infantil.
func start_memory_game() -> void:
	is_game_paused = false
	SceneManager.go_to_memory_game()

# Reinicia la escena de juego actual.
func restart_game() -> void:
	is_game_paused = false
	SceneManager.reload_current_scene()

# Registra el nivel de memorice como completado.
func complete_memory_level(level_id: String, attempts: int) -> void:
	player_profile = SaveManager.save_level_progress(level_id, attempts)

# Devuelve el mejor puntaje de intentos del nivel.
func get_best_attempts(level_id: String) -> int:
	return SaveManager.get_best_attempts(level_id)

# Indica si el nivel ya fue completado.
func is_level_completed(level_id: String) -> bool:
	return SaveManager.is_level_completed(level_id)

# Vuelve al menu principal y limpia estados temporales.
func return_to_main_menu() -> void:
	is_game_paused = false
	SceneManager.go_to_main_menu()

# Actualiza el nivel activo y guarda el progreso.
func set_current_level(level: int) -> void:
	current_level = max(level, 1)
	player_profile["current_level"] = current_level
	SaveManager.save_game(player_profile)

# Pausa o reanuda la logica global del juego.
func set_game_paused(value: bool) -> void:
	is_game_paused = value
	get_tree().paused = value
