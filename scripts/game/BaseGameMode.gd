extends Node
class_name BaseGameMode

# Clase base para futuros minijuegos o modos de nivel.
var level_id: String = ""
var is_completed: bool = false

# Punto de entrada comun para iniciar un modo de juego.
func start_mode() -> void:
	is_completed = false

# Marca el modo como completado para que recompensas o progreso puedan reaccionar.
func complete_mode() -> void:
	is_completed = true
