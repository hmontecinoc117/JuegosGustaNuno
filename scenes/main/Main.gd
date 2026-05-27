extends Node

# Escena raiz. Su unica responsabilidad es enviar al usuario al menu inicial.
func _ready() -> void:
	SceneManager.go_to_main_menu()
