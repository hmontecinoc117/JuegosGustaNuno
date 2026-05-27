extends Control

@onready var back_button: Button = %BackButton

# Escena de prueba para validar navegacion desde el menu.
func _ready() -> void:
	back_button.pressed.connect(_on_back_button_pressed)

# Regresa al menu principal usando el manager global.
func _on_back_button_pressed() -> void:
	GameManager.return_to_main_menu()
