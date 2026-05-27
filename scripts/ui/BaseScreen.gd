extends Control
class_name BaseScreen

# Clase base para pantallas UI reutilizables.
func show_screen() -> void:
	visible = true
	set_process_input(true)

# Oculta la pantalla y desactiva entrada si no esta en uso.
func hide_screen() -> void:
	visible = false
	set_process_input(false)
