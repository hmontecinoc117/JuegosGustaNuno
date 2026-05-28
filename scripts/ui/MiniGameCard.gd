extends PanelContainer
class_name MiniGameCard

signal play_pressed(game_data: Dictionary)
signal card_pressed(game_data: Dictionary)
signal card_focused(game_data: Dictionary)

const ConfigResolver = preload("res://scripts/core/ConfigResolver.gd")
const FALLBACK_MEMORY: Texture2D = preload("res://assets/ui/cards/card_front_default.png")
const FALLBACK_PUZZLE: Texture2D = preload("res://assets/ui/icons/icon_options.png")
const FALLBACK_COMING_SOON: Texture2D = preload("res://assets/ui/cards/card_back_default.png")

@onready var thumbnail_rect: TextureRect = %ThumbnailRect
@onready var title_ribbon: PanelContainer = %TitleRibbon
@onready var title_label: Label = %TitleLabel
@onready var subtitle_label: Label = %SubtitleLabel
@onready var status_label: Label = %StatusLabel
@onready var play_button: Button = %PlayButton

var game_data: Dictionary = {}
var style_config: Dictionary = {}
var status: String = "coming_soon"
var feedback_tween: Tween

func _ready() -> void:
	gui_input.connect(_on_gui_input)
	mouse_entered.connect(_on_mouse_entered)
	play_button.pressed.connect(emit_play_pressed)

func setup(data: Dictionary, card_style: Dictionary = {}) -> void:
	game_data = data.duplicate(true)
	style_config = card_style.duplicate(true)
	status = String(game_data.get("status", "coming_soon"))

	title_label.text = String(game_data.get("title", "Pronto"))
	subtitle_label.text = String(game_data.get("subtitle", "Nueva aventura"))
	apply_thumbnail(String(game_data.get("thumbnail", "")), String(game_data.get("fallback_thumbnail", "")))
	apply_status_style(status)

func apply_status_style(current_status: String) -> void:
	var button_config: Dictionary = style_config.get("button", {})
	var status_text := "Muy pronto"
	if current_status == "active":
		status_text = "Activo"
	elif current_status == "locked":
		status_text = "Bloqueado"

	status_label.text = status_text
	title_label.add_theme_color_override("font_color", ConfigResolver.color_from_hex(String(style_config.get("title_color", "#24466D"))))
	subtitle_label.add_theme_color_override("font_color", ConfigResolver.color_from_hex(String(style_config.get("subtitle_color", "#24466D"))))
	status_label.add_theme_color_override("font_color", ConfigResolver.color_from_hex(String(style_config.get("status_color", "#9A5A12"))))
	thumbnail_rect.modulate = Color(1.0, 1.0, 1.0, float(style_config.get("thumbnail_alpha", 1.0)))
	status_label.visible = current_status == "locked"

	apply_panel_style(style_config)
	apply_title_ribbon_style(style_config.get("title_ribbon", {}))
	apply_button_style(button_config)

func apply_thumbnail(path: String, fallback: String = "") -> void:
	var valid_path := ConfigResolver.get_valid_texture_path(path, fallback)
	if not valid_path.is_empty():
		thumbnail_rect.texture = load(valid_path) as Texture2D
		return

	var game_id := String(game_data.get("id", ""))
	if game_id == "memory":
		thumbnail_rect.texture = FALLBACK_MEMORY
	elif game_id == "puzzle":
		thumbnail_rect.texture = FALLBACK_PUZZLE
	else:
		thumbnail_rect.texture = FALLBACK_COMING_SOON

func apply_panel_style(style_data: Dictionary) -> void:
	var texture_path := String(style_data.get("panel_texture", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var style_texture := StyleBoxTexture.new()
		style_texture.texture = load(texture_path) as Texture2D
		style_texture.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style_texture.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		style_texture.content_margin_left = 12
		style_texture.content_margin_top = 12
		style_texture.content_margin_right = 12
		style_texture.content_margin_bottom = 12
		add_theme_stylebox_override("panel", style_texture)
		return

	var fallback_style: Dictionary = style_data.get("fallback_style", {})
	add_theme_stylebox_override("panel", make_card_style(fallback_style))

func apply_title_ribbon_style(ribbon_data: Dictionary) -> void:
	title_ribbon.visible = bool(ribbon_data.get("enabled", true))
	if not title_ribbon.visible:
		return

	var texture_path := String(ribbon_data.get("texture_path", ""))
	if not texture_path.is_empty() and ResourceLoader.exists(texture_path):
		var texture_style := StyleBoxTexture.new()
		texture_style.texture = load(texture_path) as Texture2D
		texture_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		texture_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		title_ribbon.add_theme_stylebox_override("panel", texture_style)
		return

	var ribbon_color := ConfigResolver.color_from_hex(String(ribbon_data.get("fallback_color", "#146CB5")))
	var ribbon_style := StyleBoxFlat.new()
	ribbon_style.bg_color = ribbon_color
	ribbon_style.border_color = Color(1.0, 0.75, 0.22, 0.88)
	ribbon_style.border_width_left = 3
	ribbon_style.border_width_top = 3
	ribbon_style.border_width_right = 3
	ribbon_style.border_width_bottom = 3
	ribbon_style.corner_radius_top_left = 14
	ribbon_style.corner_radius_top_right = 14
	ribbon_style.corner_radius_bottom_right = 8
	ribbon_style.corner_radius_bottom_left = 8
	ribbon_style.shadow_color = Color(0.07, 0.08, 0.10, 0.20)
	ribbon_style.shadow_size = 4
	ribbon_style.shadow_offset = Vector2(0, 2)
	title_ribbon.add_theme_stylebox_override("panel", ribbon_style)

func apply_button_style(button_data: Dictionary) -> void:
	play_button.text = String(button_data.get("text", "Pronto"))
	play_button.disabled = bool(button_data.get("disabled", status != "active"))
	play_button.visible = bool(button_data.get("visible", true))

	var text_color := ConfigResolver.color_from_hex(String(button_data.get("text_color", "#FFFFFF")))
	play_button.add_theme_color_override("font_color", text_color)
	play_button.add_theme_color_override("font_disabled_color", Color(text_color.r, text_color.g, text_color.b, 0.72))
	play_button.add_theme_font_size_override("font_size", 24)
	play_button.add_theme_color_override("font_shadow_color", Color(0.08, 0.12, 0.16, 0.24))
	play_button.add_theme_constant_override("shadow_offset_x", 0)
	play_button.add_theme_constant_override("shadow_offset_y", 1)

	var button_texture_path := String(button_data.get("texture", ""))
	if not button_texture_path.is_empty() and ResourceLoader.exists(button_texture_path):
		var texture_style := StyleBoxTexture.new()
		texture_style.texture = load(button_texture_path) as Texture2D
		texture_style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		texture_style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_STRETCH
		texture_style.content_margin_left = 16
		texture_style.content_margin_top = 8
		texture_style.content_margin_right = 16
		texture_style.content_margin_bottom = 8
		play_button.add_theme_stylebox_override("normal", texture_style)
		play_button.add_theme_stylebox_override("hover", texture_style)
		play_button.add_theme_stylebox_override("pressed", texture_style)
		play_button.add_theme_stylebox_override("disabled", texture_style)
		return

	var fallback_color := ConfigResolver.color_from_hex(String(button_data.get("fallback_color", "#8E9AA3")))
	play_button.add_theme_stylebox_override("normal", make_button_style(fallback_color, false, 1.0, 0))
	play_button.add_theme_stylebox_override("hover", make_button_style(fallback_color, false, 1.05, -1))
	play_button.add_theme_stylebox_override("pressed", make_button_style(fallback_color, false, 0.92, 1))
	play_button.add_theme_stylebox_override("disabled", make_button_style(fallback_color, true, 1.0, 0))

func emit_play_pressed() -> void:
	if status != "active":
		emit_card_pressed()
		return
	play_pressed.emit(game_data)

func emit_card_pressed() -> void:
	play_feedback()
	card_pressed.emit(game_data)

func play_feedback() -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()
	var original_position := position
	feedback_tween = create_tween()
	feedback_tween.set_trans(Tween.TRANS_SINE)
	feedback_tween.tween_property(self, "position:x", original_position.x - 8.0, 0.05)
	feedback_tween.tween_property(self, "position:x", original_position.x + 8.0, 0.08)
	feedback_tween.tween_property(self, "position:x", original_position.x, 0.05)

func make_card_style(style_data: Dictionary) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = ConfigResolver.color_from_hex(String(style_data.get("background_color", "#FFF1C2")), 0.96)
	style.border_color = ConfigResolver.color_from_hex(String(style_data.get("border_color", "#F8B62D")))
	var border_width := int(style_data.get("border_width", 5))
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	var radius := int(style_data.get("corner_radius", 26))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.12, 0.12, 0.08, float(style_data.get("shadow_alpha", 0.20)))
	style.shadow_size = int(style_data.get("shadow_size", 10))
	style.shadow_offset = Vector2(0, 5)
	style.content_margin_left = 12
	style.content_margin_top = 12
	style.content_margin_right = 12
	style.content_margin_bottom = 12
	return style

func make_button_style(base_color: Color, disabled: bool, light: float, press_offset: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		clamp(base_color.r * light, 0.0, 1.0),
		clamp(base_color.g * light, 0.0, 1.0),
		clamp(base_color.b * light, 0.0, 1.0),
		0.86 if disabled else base_color.a
	)
	style.border_color = Color(1.0, 0.88, 0.48, 0.66) if not disabled else Color(0.82, 0.84, 0.86, 0.52)
	style.border_width_left = 3
	style.border_width_top = 3
	style.border_width_right = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 22
	style.corner_radius_top_right = 22
	style.corner_radius_bottom_right = 22
	style.corner_radius_bottom_left = 22
	style.shadow_color = Color(0.09, 0.12, 0.16, 0.14)
	style.shadow_size = 4
	style.shadow_offset = Vector2(0, 2 + press_offset)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style

func _on_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if status == "active":
			play_pressed.emit(game_data)
		else:
			emit_card_pressed()

func _on_mouse_entered() -> void:
	card_focused.emit(game_data)
