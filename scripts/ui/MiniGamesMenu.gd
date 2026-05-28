extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/ui/MiniGameCard.tscn")
const JsonConfigLoader = preload("res://scripts/core/JsonConfigLoader.gd")
const ConfigResolver = preload("res://scripts/core/ConfigResolver.gd")
const DEFAULT_BUTTON_BLUE: Texture2D = preload("res://assets/ui/buttons/button_secondary_blue.png")
const DEFAULT_BUTTON_ORANGE: Texture2D = preload("res://assets/ui/buttons/button_primary_orange.png")
const DEFAULT_BUTTON_DISABLED: Texture2D = preload("res://assets/ui/buttons/button_disabled_gray.png")
const DEFAULT_LOGO: Texture2D = preload("res://assets/ui/logo/logo_gustanuno_main.png")

@onready var back_button: Button = %BackButton
@onready var profile_button: Button = %ProfileButton
@onready var options_button: Button = %OptionsButton
@onready var logo_rect: TextureRect = %LogoRect
@onready var card_grid: GridContainer = %CardGrid
@onready var previous_button: Button = %PreviousButton
@onready var next_button: Button = %NextButton
@onready var page_label: Label = %PageLabel
@onready var dots_box: HBoxContainer = %DotsBox
@onready var feedback_panel: PanelContainer = %FeedbackPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var pirate_holder: Control = %PirateHolder
@onready var background_texture: TextureRect = %BackgroundTexture
@onready var background_veil: ColorRect = %BackgroundVeil
@onready var safe_area: MarginContainer = $SafeArea
@onready var header_panel: PanelContainer = $SafeArea/RootLayout/HeaderPanel
@onready var grid_margin: MarginContainer = $SafeArea/RootLayout/ContentRow/GridPanel/GridMargin
@onready var title_label: Label = $SafeArea/RootLayout/HeaderPanel/HeaderMargin/HeaderRow/TitleBox/TitleLabel
@onready var subtitle_label: Label = $SafeArea/RootLayout/HeaderPanel/HeaderMargin/HeaderRow/TitleBox/SubtitleLabel

var menu_config: Dictionary = {}
var catalog_config: Dictionary = {}
var character_config: Dictionary = {}
var rewards_config: Dictionary = {}
var unlock_rules: Dictionary = {}
var save_data: Dictionary = {}
var games: Array[Dictionary] = []
var current_page: int = 0
var page_count: int = 1
var games_per_page: int = 6
var card_size: Vector2 = Vector2(300, 230)
var feedback_tween: Tween
var character_texture_rect: TextureRect
var selected_skin_id: String = "classic"

func _ready() -> void:
	load_all_configs()
	apply_screen_config()
	apply_background()
	build_header()
	setup_catalog_panel()
	setup_character_guide()
	setup_games()
	render_page()
	back_button.pressed.connect(go_back)
	previous_button.pressed.connect(go_to_previous_page)
	next_button.pressed.connect(go_to_next_page)

func load_all_configs() -> void:
	menu_config = load_config(AppConstants.MINIGAMES_MENU_CONFIG)
	var sources: Dictionary = menu_config.get("data_sources", {})
	catalog_config = load_catalog(String(sources.get("games_catalog", "")))
	character_config = load_character_config(String(sources.get("character_config", "")))
	rewards_config = load_rewards_config(String(sources.get("rewards_config", "")))
	unlock_rules = load_unlock_rules(String(sources.get("unlock_rules", "")))
	save_data = SaveManager.load_game()

func load_config(path: String) -> Dictionary:
	return JsonConfigLoader.load_json_config(path)

func load_catalog(path: String) -> Dictionary:
	return JsonConfigLoader.load_json_config(path)

func load_character_config(path: String) -> Dictionary:
	return JsonConfigLoader.load_json_config(path)

func load_rewards_config(path: String) -> Dictionary:
	return JsonConfigLoader.load_json_config(path)

func load_unlock_rules(path: String) -> Dictionary:
	return JsonConfigLoader.load_json_config(path)

func apply_screen_config() -> void:
	var screen: Dictionary = menu_config.get("screen", {})
	safe_area.add_theme_constant_override("margin_left", int(screen.get("safe_margin_left", 32)))
	safe_area.add_theme_constant_override("margin_top", int(screen.get("safe_margin_top", 24)))
	safe_area.add_theme_constant_override("margin_right", int(screen.get("safe_margin_right", 32)))
	safe_area.add_theme_constant_override("margin_bottom", int(screen.get("safe_margin_bottom", 24)))

	var header: Dictionary = menu_config.get("header", {})
	header_panel.custom_minimum_size.y = float(header.get("height", 190))

	var grid: Dictionary = menu_config.get("grid", {})
	games_per_page = int(grid.get("items_per_page", catalog_config.get("items_per_page_default", 6)))
	card_grid.columns = int(grid.get("columns", 3))
	card_grid.add_theme_constant_override("h_separation", int(grid.get("horizontal_gap", 28)))
	card_grid.add_theme_constant_override("v_separation", int(grid.get("vertical_gap", 24)))
	var configured_card_size: Dictionary = grid.get("card_size", {})
	card_size = Vector2(float(configured_card_size.get("width", 300)), float(configured_card_size.get("height", 230)))
	var padding: Dictionary = grid.get("padding", {})
	grid_margin.add_theme_constant_override("margin_left", int(padding.get("left", 34)))
	grid_margin.add_theme_constant_override("margin_top", int(padding.get("top", 28)))
	grid_margin.add_theme_constant_override("margin_right", int(padding.get("right", 34)))
	grid_margin.add_theme_constant_override("margin_bottom", int(padding.get("bottom", 24)))

	var arrows: Dictionary = menu_config.get("navigation_arrows", {})
	var arrow_left: Dictionary = arrows.get("left", {})
	var arrow_size: Dictionary = arrow_left.get("size", {})
	var arrow_minimum := Vector2(float(arrow_size.get("width", 78)), float(arrow_size.get("height", 78)))
	previous_button.custom_minimum_size = arrow_minimum
	next_button.custom_minimum_size = arrow_minimum

func apply_background() -> void:
	var background: Dictionary = menu_config.get("background", {})
	var texture_path := get_valid_texture_path(
		String(background.get("texture_path", "")),
		String(background.get("fallback_texture_path", ""))
	)
	background_texture.texture = load(texture_path) as Texture2D if not texture_path.is_empty() else null
	background_texture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED

	var overlay: Dictionary = background.get("overlay", {})
	background_veil.visible = bool(overlay.get("enabled", false))
	background_veil.color = ConfigResolver.color_from_hex(String(overlay.get("color", "#FFFFFF")), float(overlay.get("alpha", 0.0)))

func build_header() -> void:
	var header: Dictionary = menu_config.get("header", {})
	var logo: Dictionary = header.get("logo", {})
	logo_rect.texture = ConfigResolver.load_texture(String(logo.get("texture_path", "")), "")
	if logo_rect.texture == null:
		logo_rect.texture = DEFAULT_LOGO
	var logo_size: Dictionary = logo.get("size", {})
	logo_rect.custom_minimum_size = Vector2(float(logo_size.get("width", 420)), float(logo_size.get("height", 130)))

	var title: Dictionary = header.get("title", {})
	title_label.text = String(title.get("text", "Minijuegos"))
	title_label.add_theme_font_size_override("font_size", int(title.get("font_size", 64)))
	title_label.add_theme_color_override("font_color", ConfigResolver.color_from_hex(String(title.get("color", "#FFFFFF"))))
	title_label.add_theme_color_override("font_outline_color", ConfigResolver.color_from_hex(String(title.get("outline_color", "#1F4B82"))))
	title_label.add_theme_constant_override("outline_size", int(title.get("outline_size", 8)))

	var subtitle: Dictionary = header.get("subtitle", {})
	subtitle_label.text = String(subtitle.get("text", "Elige un juego"))
	subtitle_label.add_theme_font_size_override("font_size", int(subtitle.get("font_size", 30)))
	subtitle_label.add_theme_color_override("font_color", ConfigResolver.color_from_hex(String(subtitle.get("color", "#4A2F1B"))))
	subtitle_label.add_theme_color_override("font_outline_color", ConfigResolver.color_from_hex(String(subtitle.get("outline_color", "#FFF1C2"))))
	subtitle_label.add_theme_constant_override("outline_size", int(subtitle.get("outline_size", 3)))

	var back_config: Dictionary = header.get("back_button", {})
	back_button.text = String(back_config.get("text", "Volver"))
	var back_size: Dictionary = back_config.get("size", {})
	back_button.custom_minimum_size = Vector2(float(back_size.get("width", 240)), float(back_size.get("height", 82)))
	apply_button_style(back_button, String(back_config.get("button_texture", "")), String(back_config.get("fallback_texture", "res://assets/ui/buttons/button_secondary_blue.png")))

	profile_button.icon = ConfigResolver.load_texture("res://assets/ui/icons/icon_profile.png")
	options_button.icon = ConfigResolver.load_texture("res://assets/ui/icons/icon_options.png")
	apply_button_style(profile_button, "", "res://assets/ui/buttons/button_primary_orange.png")
	apply_button_style(options_button, "", "res://assets/ui/buttons/button_primary_orange.png")

func setup_character_guide() -> void:
	var guide_config: Dictionary = menu_config.get("character_guide", {})
	if not bool(guide_config.get("enabled", true)):
		pirate_holder.visible = false
		return
	pirate_holder.visible = true
	pirate_holder.z_index = int(guide_config.get("z_index", 20))
	selected_skin_id = get_selected_character_skin()
	set_character_reaction(String(guide_config.get("default_reaction", character_config.get("default_reaction", "welcome"))))

func setup_catalog_panel() -> void:
	var catalog: Dictionary = menu_config.get("catalog_panel", {})
	var style_config: Dictionary = catalog.get("style", {})
	var panel := $SafeArea/RootLayout/ContentRow/GridPanel as PanelContainer
	panel.add_theme_stylebox_override("panel", make_panel_style(style_config))
	header_panel.add_theme_stylebox_override("panel", make_panel_style({
		"background_color": "#FFF4C8",
		"background_alpha": 0.82,
		"border_color": "#F8B62D",
		"border_width": 3,
		"corner_radius": 24,
		"shadow_color": "#000000",
		"shadow_alpha": 0.16,
		"shadow_size": 8
	}))
	feedback_panel.add_theme_stylebox_override("panel", make_panel_style({
		"background_color": "#FFF4C8",
		"background_alpha": 0.96,
		"border_color": "#F8B62D",
		"border_width": 3,
		"corner_radius": 24,
		"shadow_color": "#000000",
		"shadow_alpha": 0.18,
		"shadow_size": 8
	}))

func setup_games() -> void:
	games.clear()
	var configured_games: Array = catalog_config.get("games", [])
	for game in configured_games:
		if typeof(game) != TYPE_DICTIONARY:
			continue
		var game_data := (game as Dictionary).duplicate(true)
		if not bool(game_data.get("enabled", true)):
			continue
		game_data["status"] = resolve_game_status(game_data)
		game_data["scene_path"] = ConfigResolver.resolve_scene_path(String(game_data.get("scene_constant", "")), String(game_data.get("scene_path", "")))
		games.append(game_data)
	page_count = max(1, int(ceil(float(games.size()) / float(games_per_page))))

func resolve_game_status(game_data: Dictionary) -> String:
	var rule_id := String(game_data.get("unlock_rule_id", ""))
	var configured_status := String(game_data.get("status", "coming_soon"))
	if configured_status == "locked" and is_unlock_rule_completed(rule_id):
		return "active"
	if not rule_id.is_empty() and not is_unlock_rule_completed(rule_id):
		return "locked"
	return configured_status

func render_page() -> void:
	clear_grid()
	var start_index: int = current_page * games_per_page
	var end_index: int = mini(start_index + games_per_page, games.size())
	for index in range(start_index, end_index):
		create_card(games[index])
	update_pagination()

func clear_grid() -> void:
	for child in card_grid.get_children():
		child.queue_free()

func create_card(game_data: Dictionary) -> void:
	var holder := CenterContainer.new()
	holder.custom_minimum_size = card_size
	holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card_grid.add_child(holder)

	var card := CARD_SCENE.instantiate()
	var status := String(game_data.get("status", "coming_soon"))
	var styles: Dictionary = menu_config.get("card_style", {})
	var style_config: Dictionary = styles.get(status, styles.get("coming_soon", {}))
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.play_pressed.connect(on_card_play_pressed)
	card.card_pressed.connect(on_card_pressed)
	card.card_focused.connect(_on_card_focused)
	holder.add_child(card)
	card.setup(game_data, style_config)

func on_card_play_pressed(game_data: Dictionary) -> void:
	var status := String(game_data.get("status", "coming_soon"))
	if status == "active":
		set_character_reaction(String(game_data.get("character_reaction_on_play", "celebrating")))
		var scene_path := String(game_data.get("scene_path", ""))
		if not scene_path.is_empty():
			SceneManager.change_scene(scene_path)
		return
	on_card_pressed(game_data)

func on_card_pressed(game_data: Dictionary) -> void:
	var status := String(game_data.get("status", "coming_soon"))
	if status == "locked":
		show_locked_feedback()
	else:
		show_coming_soon_feedback()

func _on_card_focused(game_data: Dictionary) -> void:
	set_character_reaction(String(game_data.get("character_reaction_on_focus", "pointing")))

func go_to_next_page() -> void:
	if current_page >= page_count - 1:
		return
	current_page += 1
	render_page()

func go_to_previous_page() -> void:
	if current_page <= 0:
		return
	current_page -= 1
	render_page()

func update_pagination() -> void:
	var pagination: Dictionary = menu_config.get("pagination", {})
	var format := String(pagination.get("page_text_format", "{current} / {total}"))
	page_label.text = format.replace("{current}", str(current_page + 1)).replace("{total}", str(page_count))
	update_arrows()
	for child in dots_box.get_children():
		child.queue_free()
	for index in range(page_count):
		var dot := Label.new()
		dot.text = "o" if index == current_page else "."
		dot.custom_minimum_size = Vector2(26, 24)
		dot.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		dot.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		dot.add_theme_font_size_override("font_size", 30 if index == current_page else 28)
		dot.add_theme_color_override("font_color", Color(1.0, 0.73, 0.16, 1.0) if index == current_page else Color(1.0, 1.0, 1.0, 0.78))
		dots_box.add_child(dot)

func update_arrows() -> void:
	var arrows: Dictionary = menu_config.get("navigation_arrows", {})
	var disabled_alpha := float(arrows.get("disabled_alpha", 0.35))
	previous_button.disabled = current_page <= 0
	next_button.disabled = current_page >= page_count - 1
	previous_button.modulate.a = disabled_alpha if previous_button.disabled else 1.0
	next_button.modulate.a = disabled_alpha if next_button.disabled else 1.0

func go_back() -> void:
	var back_config: Dictionary = JsonConfigLoader.get_value(menu_config, "header.back_button.action", {})
	var scene_path := ConfigResolver.resolve_scene_path(String(back_config.get("constant", "SCENE_MAIN_MENU")), String(back_config.get("scene_path", "")))
	SceneManager.change_scene(scene_path)

func show_coming_soon_feedback() -> void:
	var feedback: Dictionary = JsonConfigLoader.get_value(menu_config, "feedback.coming_soon", {})
	set_character_reaction(String(feedback.get("character_reaction", "holding_map")))
	show_feedback(String(feedback.get("message", "Muy pronto")))

func show_locked_feedback() -> void:
	var feedback: Dictionary = JsonConfigLoader.get_value(menu_config, "feedback.locked", {})
	set_character_reaction(String(feedback.get("character_reaction", "holding_map")))
	show_feedback(String(feedback.get("message", "Aun bloqueado")))

func show_feedback(message: String) -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()
	feedback_label.text = message
	feedback_panel.visible = true
	feedback_panel.modulate = Color.WHITE
	feedback_panel.scale = Vector2(0.94, 0.94)
	feedback_tween = create_tween()
	feedback_tween.set_trans(Tween.TRANS_BACK)
	feedback_tween.set_ease(Tween.EASE_OUT)
	feedback_tween.tween_property(feedback_panel, "scale", Vector2.ONE, 0.12)
	feedback_tween.tween_interval(0.85)
	feedback_tween.tween_property(feedback_panel, "modulate:a", 0.0, 0.18)
	await feedback_tween.finished
	feedback_panel.visible = false
	feedback_panel.modulate.a = 1.0

func set_character_reaction(reaction_id: String) -> void:
	var texture_path := get_character_reaction_path(reaction_id)
	if texture_path.is_empty():
		return
	if character_texture_rect == null:
		character_texture_rect = TextureRect.new()
		character_texture_rect.name = "PirateGuideMiniGames"
		character_texture_rect.layout_mode = 1
		character_texture_rect.anchors_preset = Control.PRESET_FULL_RECT
		character_texture_rect.anchor_right = 1.0
		character_texture_rect.anchor_bottom = 1.0
		character_texture_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		character_texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		character_texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		pirate_holder.add_child(character_texture_rect)
	character_texture_rect.texture = load(texture_path) as Texture2D

func get_selected_character_skin() -> String:
	var default_skin := String(character_config.get("default_skin", "classic"))
	var guide_config: Dictionary = menu_config.get("character_guide", {})
	var source := String(guide_config.get("selected_skin_source", ""))
	var selected := String(ConfigResolver.get_save_value(save_data, source.replace("save.", ""), default_skin))
	var skins: Dictionary = character_config.get("skins", {})
	if skins.has(selected):
		var skin: Dictionary = skins[selected]
		if bool(skin.get("unlocked", true)) or ConfigResolver.is_unlock_rule_completed(String(skin.get("unlock_rule_id", "")), unlock_rules, save_data):
			return selected
	return default_skin

func get_character_reaction_path(reaction_id: String) -> String:
	var skins: Dictionary = character_config.get("skins", {})
	var skin: Dictionary = skins.get(selected_skin_id, skins.get(String(character_config.get("default_skin", "classic")), {}))
	var reactions: Dictionary = skin.get("reactions", {})
	var path := String(reactions.get(reaction_id, ""))
	if ResourceLoader.exists(path):
		return path
	var fallbacks: Dictionary = character_config.get("reaction_fallbacks", {})
	var fallback_reaction := String(fallbacks.get(reaction_id, character_config.get("default_reaction", "idle")))
	path = String(reactions.get(fallback_reaction, ""))
	if ResourceLoader.exists(path):
		return path
	return ""

func get_valid_texture_path(primary_path: String, fallback_path: String = "") -> String:
	return ConfigResolver.get_valid_texture_path(primary_path, fallback_path)

func load_json_config(path: String) -> Dictionary:
	return JsonConfigLoader.load_json_config(path)

func is_unlock_rule_completed(rule_id: String) -> bool:
	return ConfigResolver.is_unlock_rule_completed(rule_id, unlock_rules, save_data)

func make_panel_style(config: Dictionary) -> StyleBoxFlat:
	var bg_color := ConfigResolver.color_from_hex(String(config.get("background_color", "#FFF4C8")), float(config.get("background_alpha", 0.88)))
	var border_color := ConfigResolver.color_from_hex(String(config.get("border_color", "#17A8C8")), 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	var border_width := int(config.get("border_width", 6))
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	var radius := int(config.get("corner_radius", 32))
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = ConfigResolver.color_from_hex(String(config.get("shadow_color", "#000000")), float(config.get("shadow_alpha", 0.22)))
	style.shadow_size = int(config.get("shadow_size", 16))
	style.shadow_offset = Vector2(0, 5)
	return style

func apply_button_style(button: Button, texture_path: String, fallback_path: String = "") -> void:
	var _texture_path := get_valid_texture_path(texture_path, fallback_path)
	var is_arrow := button == previous_button or button == next_button
	var normal := make_button_style(false, is_arrow, 1.0, 0)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", make_button_style(false, is_arrow, 1.05, -1))
	button.add_theme_stylebox_override("pressed", make_button_style(false, is_arrow, 0.92, 1))
	button.add_theme_stylebox_override("disabled", make_button_style(true, is_arrow, 1.0, 0))
	button.add_theme_font_size_override("font_size", 22)
	button.add_theme_color_override("font_color", Color.WHITE)
	button.add_theme_color_override("font_disabled_color", Color(0.86, 0.90, 0.94, 1.0))
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.expand_icon = true
	button.add_theme_constant_override("icon_max_width", 30)

func make_button_style(disabled: bool, is_arrow: bool, light: float, press_offset: int) -> StyleBoxFlat:
	var base := Color(0.0, 0.58, 0.76, 1.0) if not disabled else Color(0.52, 0.58, 0.62, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(clamp(base.r * light, 0.0, 1.0), clamp(base.g * light, 0.0, 1.0), clamp(base.b * light, 0.0, 1.0), base.a)
	style.border_color = Color(1.0, 0.82, 0.30, 0.92)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	var radius := 36 if is_arrow else 24
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = Color(0.08, 0.12, 0.16, 0.16)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 2 + press_offset)
	return style
