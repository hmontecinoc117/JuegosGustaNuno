extends Control

const BG_MINIGAMES_PATH: String = "res://assets/backgrounds/bg_minigames_menu_pirate_clean.png"
const BUTTON_SECONDARY_BLUE: Texture2D = preload("res://assets/ui/buttons/button_secondary_blue.png")

@onready var back_button: Button = %BackButton

func _ready() -> void:
	_add_background()
	_apply_button_style(back_button)
	back_button.pressed.connect(_go_back)

func _go_back() -> void:
	SceneManager.change_scene(AppConstants.SCENE_MINIGAMES_MENU)

func _add_background() -> void:
	if ResourceLoader.exists(BG_MINIGAMES_PATH):
		_add_fullscreen_background(load(BG_MINIGAMES_PATH) as Texture2D)
		return
	_add_placeholder_background()

func _add_fullscreen_background(texture: Texture2D) -> void:
	var background := TextureRect.new()
	background.name = "RealBackground"
	background.texture = texture
	background.layout_mode = 1
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

func _add_placeholder_background() -> void:
	# Placeholder temporal: reemplazar por bg_minigames_menu_pirate_clean.png generado con Stable Diffusion.
	var sky := ColorRect.new()
	sky.name = "MiniGamesSkyPlaceholder"
	sky.layout_mode = 1
	sky.anchors_preset = Control.PRESET_FULL_RECT
	sky.anchor_right = 1.0
	sky.anchor_bottom = 1.0
	sky.color = Color(0.42, 0.80, 0.96, 1.0)
	sky.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sky)
	move_child(sky, 0)

	var sea := ColorRect.new()
	sea.name = "MiniGamesSeaPlaceholder"
	sea.layout_mode = 1
	sea.anchor_top = 0.56
	sea.anchor_right = 1.0
	sea.anchor_bottom = 1.0
	sea.color = Color(0.06, 0.72, 0.78, 1.0)
	sea.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sea)
	move_child(sea, 1)

func _apply_button_style(button: Button) -> void:
	var style := StyleBoxTexture.new()
	style.texture = BUTTON_SECONDARY_BLUE
	style.texture_margin_left = 28
	style.texture_margin_top = 28
	style.texture_margin_right = 28
	style.texture_margin_bottom = 28
	button.add_theme_stylebox_override("normal", style)
	button.add_theme_stylebox_override("hover", style)
	button.add_theme_stylebox_override("pressed", style)
	button.add_theme_font_size_override("font_size", 24)
	button.add_theme_color_override("font_color", Color.WHITE)
