extends Node

# Gestiona la navegacion entre escenas para mantener pantallas desacopladas.
var current_scene_path: String = ""

# Cambia a una escena usando una ruta res:// valida.
func change_scene(scene_path: String) -> void:
	if scene_path.is_empty():
		push_warning("SceneManager recibio una ruta vacia.")
		return

	current_scene_path = scene_path
	var error: Error = get_tree().change_scene_to_file(scene_path)
	if error != OK:
		push_error("No se pudo cargar la escena: " + scene_path)

# Abre el menu principal.
func go_to_main_menu() -> void:
	change_scene(AppConstants.MAIN_MENU_SCENE)

# Abre la escena de juego base.
func go_to_game_scene() -> void:
	change_scene(AppConstants.GAME_SCENE)

# Abre el minijuego de memorice infantil.
func go_to_memory_game() -> void:
	change_scene(AppConstants.MEMORY_GAME_SCENE)

# Reinicia la escena actual si existe una ruta registrada.
func reload_current_scene() -> void:
	if current_scene_path.is_empty():
		get_tree().reload_current_scene()
		return
	change_scene(current_scene_path)
