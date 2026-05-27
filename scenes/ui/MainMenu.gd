extends Control

const BG_MAIN_MENU: Texture2D = preload("res://assets/backgrounds/bg_main_menu_pirate_hub.png")
const PIRATE_GUIDE_SCENE: PackedScene = preload("res://scenes/characters/PirateGuide.tscn")
const MENU_LOGO: Texture2D = preload("res://assets/ui/logo/logo_gustanuno_main.png")
const BUTTON_JUEGOS: Texture2D = preload("res://assets/ui/buttons/button_juegos.png")
const BUTTON_PERFIL: Texture2D = preload("res://assets/ui/buttons/button_perfil.png")
const BUTTON_OPCIONES: Texture2D = preload("res://assets/ui/buttons/button_opciones.png")
const SHADOW_SOFT: Texture2D = preload("res://assets/ui/fx/shadow_soft_ellipse.png")

@onready var play_button: BaseButton = %PlayButton
@onready var profile_button: BaseButton = %ProfileButton
@onready var options_button: BaseButton = %OptionsButton
@onready var exit_button: BaseButton = %ExitButton
@onready var message_label: Label = %MessageLabel

var animated_buttons: Array[BaseButton] = []

# Conecta acciones del menu principal.
func _ready() -> void:
	_apply_real_assets()
	call_deferred("_apply_final_composition_offsets")

	animated_buttons = [play_button, profile_button, options_button, exit_button]
	for button in animated_buttons:
		button.pressed.connect(_on_any_button_pressed.bind(button))
		button.button_down.connect(_play_button_touch.bind(button))

	play_button.pressed.connect(_on_play_button_pressed)
	profile_button.pressed.connect(_on_profile_button_pressed)
	options_button.pressed.connect(_on_options_button_pressed)
	exit_button.pressed.connect(_on_exit_button_pressed)

# Inicia el flujo de juego desde GameManager.
func _on_play_button_pressed() -> void:
	GameManager.start_game()

# Muestra un mensaje temporal hasta crear pantalla de perfil.
func _on_profile_button_pressed() -> void:
	message_label.text = "Perfil disponible en la siguiente fase"

# Muestra un mensaje temporal hasta crear la pantalla de opciones.
func _on_options_button_pressed() -> void:
	message_label.text = "Opciones disponibles en una fase futura"

# Cierra el juego. En Android normalmente envia la app a segundo plano.
func _on_exit_button_pressed() -> void:
	get_tree().quit()

# Reproduce un rebote suave al tocar cualquier boton.
func _on_any_button_pressed(button: BaseButton) -> void:
	_play_button_bounce(button)

# Anticipa la respuesta tactil al presionar.
func _play_button_touch(button: BaseButton) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.06)

# Completa el rebote visual del boton.
func _play_button_bounce(button: BaseButton) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.06, 1.06), 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)

# Aplica PNG finales manteniendo la estructura y senales actuales.
func _apply_real_assets() -> void:
	_add_fullscreen_background(BG_MAIN_MENU)
	_hide_placeholder_nodes(["Sky", "SoftClouds", "HillsBack", "Ground"])
	_apply_menu_layout()
	_apply_mascot_texture()
	_apply_logo_panel()
	play_button = _replace_button_with_texture(play_button, BUTTON_JUEGOS, "Juegos")
	profile_button = _replace_button_with_texture(profile_button, BUTTON_PERFIL, "Perfil")
	options_button = _replace_button_with_texture(options_button, BUTTON_OPCIONES, "Opciones")
	exit_button.visible = false

# Crea fondo escalable horizontal para Android.
func _add_fullscreen_background(texture: Texture2D) -> void:
	var background := TextureRect.new()
	background.name = "RealBackground"
	background.texture = texture
	background.layout_mode = 1
	background.anchors_preset = Control.PRESET_FULL_RECT
	background.anchor_right = 1.0
	background.anchor_bottom = 1.0
	background.grow_horizontal = Control.GROW_DIRECTION_BOTH
	background.grow_vertical = Control.GROW_DIRECTION_BOTH
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)
	move_child(background, 0)

func _apply_menu_layout() -> void:
	var safe_area := get_node_or_null("SafeArea") as MarginContainer
	if safe_area != null:
		safe_area.add_theme_constant_override("margin_left", 36)
		safe_area.add_theme_constant_override("margin_top", 24)
		safe_area.add_theme_constant_override("margin_right", 44)
		safe_area.add_theme_constant_override("margin_bottom", 34)

	var main_layout := get_node_or_null("SafeArea/MainLayout") as HBoxContainer
	if main_layout != null:
		main_layout.add_theme_constant_override("separation", 0)

	var mascot_zone := get_node_or_null("SafeArea/MainLayout/MascotZone") as Control
	if mascot_zone != null:
		mascot_zone.custom_minimum_size = Vector2(250, 0)
		mascot_zone.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

	var menu_zone := get_node_or_null("SafeArea/MainLayout/MenuZone") as Control
	if menu_zone != null:
		menu_zone.custom_minimum_size = Vector2(650, 0)
		menu_zone.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var menu_box := get_node_or_null("SafeArea/MainLayout/MenuZone/MenuBox") as VBoxContainer
	if menu_box != null:
		menu_box.custom_minimum_size = Vector2(610, 600)
		menu_box.add_theme_constant_override("separation", 4)

	var logo_panel := get_node_or_null("SafeArea/MainLayout/MenuZone/MenuBox/LogoPanel") as Control
	if logo_panel != null:
		logo_panel.custom_minimum_size = Vector2(650, 270)

	var title_label := get_node_or_null("SafeArea/MainLayout/MenuZone/MenuBox/LogoPanel/LogoMargin/LogoText/TitleLabel") as Label
	if title_label != null:
		title_label.visible = false

	var subtitle_label := get_node_or_null("SafeArea/MainLayout/MenuZone/MenuBox/LogoPanel/LogoMargin/LogoText/SubtitleLabel") as Label
	if subtitle_label != null:
		subtitle_label.visible = false

	message_label.text = ""
	message_label.visible = false
	message_label.add_theme_font_size_override("font_size", 21)
	message_label.add_theme_color_override("font_color", Color(1.0, 0.96, 0.78, 0.96))
	message_label.add_theme_color_override("font_outline_color", Color(0.08, 0.17, 0.26, 0.60))
	message_label.add_theme_color_override("font_shadow_color", Color(1.0, 0.92, 0.72, 0.65))
	message_label.add_theme_constant_override("outline_size", 2)
	message_label.add_theme_constant_override("shadow_offset_x", 0)
	message_label.add_theme_constant_override("shadow_offset_y", 2)

	for button in [play_button, profile_button, options_button]:
		button.custom_minimum_size = Vector2(500, 118)

# Oculta placeholders construidos con nodos simples.
func _hide_placeholder_nodes(node_names: Array[String]) -> void:
	for node_name in node_names:
		var node := get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false

# Reemplaza el personaje placeholder por el guia pirata real.
func _apply_mascot_texture() -> void:
	var mascot_stack := get_node_or_null("SafeArea/MainLayout/MascotZone/MascotStack")
	if mascot_stack == null:
		return
	mascot_stack.custom_minimum_size = Vector2(255, 340)
	for child in mascot_stack.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	var shadow := TextureRect.new()
	shadow.name = "PirateGuideShadow"
	shadow.texture = SHADOW_SOFT
	shadow.layout_mode = 1
	shadow.anchor_left = 0.20
	shadow.anchor_top = 0.86
	shadow.anchor_right = 0.82
	shadow.anchor_bottom = 0.95
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shadow.stretch_mode = TextureRect.STRETCH_SCALE
	mascot_stack.add_child(shadow)

	var pirate_guide := PIRATE_GUIDE_SCENE.instantiate() as PirateGuide
	pirate_guide.name = "PirateGuideMenu"
	pirate_guide.default_pose = "welcome"
	pirate_guide.bounce_enabled = false
	pirate_guide.layout_mode = 1
	pirate_guide.anchors_preset = Control.PRESET_FULL_RECT
	pirate_guide.anchor_right = 1.0
	pirate_guide.anchor_bottom = 1.0
	pirate_guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mascot_stack.add_child(pirate_guide)

# Aplica panel PNG al logo.
func _apply_logo_panel() -> void:
	var logo_panel := get_node_or_null("SafeArea/MainLayout/MenuZone/MenuBox/LogoPanel") as PanelContainer
	if logo_panel == null:
		return
	logo_panel.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	for child in logo_panel.get_children():
		if child is CanvasItem:
			(child as CanvasItem).visible = false

	var logo_texture := TextureRect.new()
	logo_texture.name = "PremiumLogo"
	logo_texture.texture = MENU_LOGO
	logo_texture.layout_mode = 1
	logo_texture.anchors_preset = Control.PRESET_FULL_RECT
	logo_texture.anchor_right = 1.0
	logo_texture.anchor_bottom = 1.0
	logo_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	logo_panel.add_child(logo_texture)

func _replace_button_with_texture(original_button: BaseButton, texture: Texture2D, node_name: String) -> TextureButton:
	var parent := original_button.get_parent()
	var insertion_index := original_button.get_index()
	original_button.visible = false
	original_button.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var texture_button := TextureButton.new()
	texture_button.name = "%sTextureButton" % node_name
	texture_button.texture_normal = texture
	texture_button.texture_hover = texture
	texture_button.texture_pressed = texture
	texture_button.texture_disabled = texture
	texture_button.ignore_texture_size = true
	texture_button.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	texture_button.custom_minimum_size = original_button.custom_minimum_size
	texture_button.size_flags_horizontal = original_button.size_flags_horizontal
	texture_button.size_flags_vertical = original_button.size_flags_vertical
	texture_button.focus_mode = Control.FOCUS_NONE

	parent.add_child(texture_button)
	parent.move_child(texture_button, insertion_index)
	return texture_button

func _apply_final_composition_offsets() -> void:
	await get_tree().process_frame
	await get_tree().process_frame

	var viewport_size := get_viewport_rect().size

	var menu_box := get_node_or_null("SafeArea/MainLayout/MenuZone/MenuBox") as Control
	if menu_box != null:
		var menu_size := _get_control_layout_size(menu_box)
		menu_box.top_level = true
		menu_box.global_position = Vector2(
			floor((viewport_size.x - menu_size.x) * 0.5),
			18.0
		)

	var mascot_stack := get_node_or_null("SafeArea/MainLayout/MascotZone/MascotStack") as Control
	if mascot_stack != null:
		var mascot_size := _get_control_layout_size(mascot_stack)
		mascot_stack.top_level = true
		mascot_stack.global_position = Vector2(
			58.0,
			viewport_size.y - mascot_size.y - 34.0
		)

func _get_control_layout_size(control: Control) -> Vector2:
	var layout_size := control.size
	if layout_size.x <= 1.0 or layout_size.y <= 1.0:
		layout_size = control.get_combined_minimum_size()
	return layout_size
