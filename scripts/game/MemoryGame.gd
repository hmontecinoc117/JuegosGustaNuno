extends Control

const CARD_SCENE: PackedScene = preload("res://scenes/game/MemoryCard.tscn")
const LEVEL_ID: String = AppConstants.MEMORY_LEVEL_ID
const ANIMAL_LABELS: Array[String] = ["Perro", "Gato", "Pato", "Oso", "Pez", "Leon"]
const DEBUG_SHOW_ANIMAL_PREVIEW: bool = false
const DEBUG_PREVIEW_ANIMAL_IDS: Array[String] = ["leon", "perro", "gato"]
const BG_MEMORY_GAME: Texture2D = preload("res://assets/backgrounds/bg_memory_game_cartoon.png")
const PANEL_STATS: Texture2D = preload("res://assets/ui/panels/panel_stats.png")
const PANEL_BOARD: Texture2D = preload("res://assets/ui/panels/panel_board.png")
const PANEL_STARS: Texture2D = preload("res://assets/ui/panels/panel_stars.png")
const PANEL_VICTORY: Texture2D = preload("res://assets/ui/panels/panel_victory.png")
const PANEL_MESSAGE: Texture2D = preload("res://assets/ui/panels/panel_message.png")
const BUTTON_SMALL_ORANGE: Texture2D = preload("res://assets/ui/buttons/button_small_orange.png")
const BUTTON_PRIMARY_ORANGE: Texture2D = preload("res://assets/ui/buttons/button_primary_orange.png")
const BUTTON_PRIMARY_ORANGE_HOVER: Texture2D = preload("res://assets/ui/buttons/button_primary_orange_hover.png")
const BUTTON_PRIMARY_ORANGE_PRESSED: Texture2D = preload("res://assets/ui/buttons/button_primary_orange_pressed.png")
const BUTTON_SECONDARY_BLUE: Texture2D = preload("res://assets/ui/buttons/button_secondary_blue.png")
const ICON_MENU: Texture2D = preload("res://assets/ui/icons/icon_menu.png")
const ICON_RESTART: Texture2D = preload("res://assets/ui/icons/icon_restart.png")
const ICON_NEXT: Texture2D = preload("res://assets/ui/icons/icon_next.png")
const ICON_ATTEMPTS: Texture2D = preload("res://assets/ui/icons/icon_attempts.png")
const ICON_PAIRS: Texture2D = preload("res://assets/ui/icons/icon_pairs.png")
const ICON_BEST_SCORE: Texture2D = preload("res://assets/ui/icons/icon_best_score.png")
const PIRATE_GUIDE_SCENE: PackedScene = preload("res://scenes/characters/PirateGuide.tscn")
const REWARD_STAR_FULL: Texture2D = preload("res://assets/ui/rewards/reward_star_full.png")
const REWARD_STAR_EMPTY: Texture2D = preload("res://assets/ui/rewards/reward_star_empty.png")
const REWARD_SPARKLE: Texture2D = preload("res://assets/ui/rewards/reward_sparkle.png")
const CARD_SHADOW: Texture2D = preload("res://assets/ui/cards/card_shadow.png")
const ANIMAL_TEXTURES: Dictionary = {
	"perro": preload("res://assets/sprites/animals/card/animal_dog_card.png"),
	"gato": preload("res://assets/sprites/animals/card/animal_cat_card.png"),
	"pato": preload("res://assets/sprites/animals/card/animal_duck_card.png"),
	"oso": preload("res://assets/sprites/animals/card/animal_bear_card.png"),
	"pez": preload("res://assets/sprites/animals/card/animal_fish_card.png"),
	"leon": preload("res://assets/sprites/animals/card/animal_lion_card.png")
}

@onready var card_grid: GridContainer = %CardGrid
@onready var attempts_label: Label = %AttemptsLabel
@onready var pairs_label: Label = %PairsLabel
@onready var best_label: Label = %BestLabel
@onready var back_button: Button = %BackButton
@onready var restart_button: Button = %RestartButton
@onready var feedback_panel: PanelContainer = %FeedbackPanel
@onready var feedback_label: Label = %FeedbackLabel
@onready var victory_overlay: ColorRect = %VictoryOverlay
@onready var victory_message: Label = %VictoryMessage
@onready var victory_attempts_label: Label = %VictoryAttemptsLabel
@onready var victory_best_label: Label = %VictoryBestLabel
@onready var victory_restart_button: Button = %VictoryRestartButton
@onready var victory_menu_button: Button = %VictoryMenuButton
@onready var victory_next_button: Button = %VictoryNextButton

var selected_cards: Array[MemoryCard] = []
var attempts: int = 0
var pairs_found: int = 0
var total_pairs: int = 0
var best_attempts: int = 0
var is_checking_pair: bool = false
var feedback_tween: Tween
var animated_buttons: Array[Button] = []
var memory_cards: Array[MemoryCard] = []
var pirate_guide: PirateGuide
var victory_pirate_guide: PirateGuide

# Prepara botones, audio opcional y crea una partida nueva.
func _ready() -> void:
	_apply_real_assets()

	animated_buttons = [back_button, restart_button, victory_restart_button, victory_next_button, victory_menu_button]
	for button in animated_buttons:
		button.button_down.connect(_play_button_touch.bind(button))
		button.pressed.connect(_play_button_bounce.bind(button))

	back_button.pressed.connect(_on_back_button_pressed)
	restart_button.pressed.connect(_on_restart_button_pressed)
	victory_restart_button.pressed.connect(_on_restart_button_pressed)
	victory_menu_button.pressed.connect(_on_back_button_pressed)
	victory_next_button.pressed.connect(_on_next_button_pressed)
	AudioManager.play_music_from_path(AppConstants.AUDIO_MEMORY_MUSIC)
	start_new_game()

# Reinicia datos, mezcla cartas y actualiza la interfaz.
func start_new_game() -> void:
	attempts = 0
	pairs_found = 0
	total_pairs = ANIMAL_LABELS.size()
	best_attempts = GameManager.get_best_attempts(LEVEL_ID)
	selected_cards.clear()
	is_checking_pair = false
	feedback_panel.visible = false
	victory_overlay.visible = false
	if pirate_guide != null:
		pirate_guide.visible = true
	_set_pirate_guide_pose("welcome")
	_clear_board()
	_create_cards()
	_update_hud()
	if DEBUG_SHOW_ANIMAL_PREVIEW:
		_show_debug_animal_preview()

# Limpia cartas existentes antes de crear una nueva partida.
func _clear_board() -> void:
	memory_cards.clear()
	for child in card_grid.get_children():
		child.queue_free()

# Crea una grilla 4x3 con seis pares de animales.
func _create_cards() -> void:
	var deck: Array[Dictionary] = []
	for animal in ANIMAL_LABELS:
		var card_id := animal.to_lower()
		var card_data: Dictionary = {
			"id": card_id,
			"label": animal,
			"texture": ANIMAL_TEXTURES.get(card_id)
		}
		deck.append(card_data)
		deck.append(card_data.duplicate(true))

	deck.shuffle()

	for card_data in deck:
		var card_holder := CenterContainer.new()
		card_holder.custom_minimum_size = Vector2(190, 162)
		card_holder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		card_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL

		var card_stack := Control.new()
		card_stack.custom_minimum_size = Vector2(142, 174)
		card_stack.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card_stack.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		card_holder.add_child(card_stack)

		var shadow := TextureRect.new()
		shadow.texture = CARD_SHADOW
		shadow.layout_mode = 1
		shadow.anchor_left = 0.08
		shadow.anchor_top = 0.87
		shadow.anchor_right = 0.92
		shadow.anchor_bottom = 0.98
		shadow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		shadow.stretch_mode = TextureRect.STRETCH_SCALE
		shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		shadow.modulate = Color(0.32, 0.26, 0.16, 0.17)
		card_stack.add_child(shadow)

		var card: MemoryCard = CARD_SCENE.instantiate() as MemoryCard
		card.layout_mode = 1
		card.anchor_left = 0.0
		card.anchor_top = 0.0
		card.anchor_right = 1.0
		card.anchor_bottom = 0.96
		var texture: Texture2D = card_data["texture"] as Texture2D
		card.setup_card(String(card_data["id"]), String(card_data["label"]), texture)
		card.card_selected.connect(_on_card_selected)
		card_stack.add_child(card)
		memory_cards.append(card)
		card_grid.add_child(card_holder)

# Abre algunas cartas para revisar composicion real de sprites.
func _show_debug_animal_preview() -> void:
	for animal_id in DEBUG_PREVIEW_ANIMAL_IDS:
		for card in memory_cards:
			if card.card_id == animal_id and not card.is_face_up:
				card.show_preview_front()
				break

# Procesa la seleccion de una carta y valida cuando hay dos reveladas.
func _on_card_selected(card: MemoryCard) -> void:
	if is_checking_pair or selected_cards.has(card):
		return

	AudioManager.play_sfx_from_path(AppConstants.AUDIO_CARD_FLIP)
	card.reveal_card()
	selected_cards.append(card)

	if selected_cards.size() == 2:
		attempts += 1
		_update_hud()
		_check_selected_pair()

# Compara las dos cartas elegidas y decide si quedan visibles u ocultas.
func _check_selected_pair() -> void:
	is_checking_pair = true
	_set_cards_locked(true)

	var first_card: MemoryCard = selected_cards[0]
	var second_card: MemoryCard = selected_cards[1]

	if first_card.card_id == second_card.card_id:
		await get_tree().create_timer(0.28).timeout
		AudioManager.play_sfx_from_path(AppConstants.AUDIO_MATCH_OK)
		await first_card.mark_as_matched()
		await second_card.mark_as_matched()
		pairs_found += 1
		selected_cards.clear()
		is_checking_pair = false
		_set_cards_locked(false)
		_update_hud()
		_set_pirate_guide_pose("happy")
		_show_feedback("Muy bien, encontraste un par", Color(0.45, 0.78, 0.46, 1.0))
		_check_victory()
		return

	await get_tree().create_timer(0.45).timeout
	AudioManager.play_sfx_from_path(AppConstants.AUDIO_MATCH_ERROR)
	_set_pirate_guide_pose("pointing")
	_show_feedback("Sigue intentando", Color(1.0, 0.58, 0.43, 1.0))
	await first_card.wrong_pair()
	await second_card.wrong_pair()
	await first_card.hide_card()
	await second_card.hide_card()
	selected_cards.clear()
	is_checking_pair = false
	_set_cards_locked(false)

# Bloquea la grilla completa mientras se revisa un par.
func _set_cards_locked(value: bool) -> void:
	for holder in card_grid.get_children():
		_set_card_locked_recursive(holder, value)

# Busca cartas aunque esten dentro de contenedores visuales.
func _set_card_locked_recursive(node: Node, value: bool) -> void:
	if node is MemoryCard:
		(node as MemoryCard).set_card_locked(value)
		return
	for child in node.get_children():
		_set_card_locked_recursive(child, value)

# Actualiza contadores visibles de la partida.
func _update_hud() -> void:
	attempts_label.text = "Intentos: %d" % attempts
	pairs_label.text = "Pares: %d/%d" % [pairs_found, total_pairs]
	if best_attempts > 0:
		best_label.text = "Mejor: %d" % best_attempts
	else:
		best_label.text = "Mejor: --"

# Muestra un mensaje temporal para aciertos y errores.
func _show_feedback(message: String, color: Color) -> void:
	if feedback_tween != null and feedback_tween.is_valid():
		feedback_tween.kill()

	feedback_label.text = message
	feedback_label.add_theme_color_override("font_color", color.darkened(0.38))
	feedback_panel.modulate = Color.WHITE
	feedback_panel.visible = true
	feedback_panel.scale = Vector2(0.96, 0.96)

	feedback_tween = create_tween()
	feedback_tween.set_trans(Tween.TRANS_BACK)
	feedback_tween.set_ease(Tween.EASE_OUT)
	feedback_tween.tween_property(feedback_panel, "scale", Vector2.ONE, 0.12)
	feedback_tween.tween_interval(1.0)
	feedback_tween.tween_property(feedback_panel, "modulate:a", 0.0, 0.2)
	await feedback_tween.finished
	feedback_panel.visible = false
	feedback_panel.modulate.a = 1.0

# Muestra victoria y registra progreso cuando todos los pares fueron encontrados.
func _check_victory() -> void:
	if pairs_found < total_pairs:
		return

	GameManager.complete_memory_level(LEVEL_ID, attempts)
	best_attempts = GameManager.get_best_attempts(LEVEL_ID)
	AudioManager.play_sfx_from_path(AppConstants.AUDIO_VICTORY)
	victory_message.text = "NIVEL COMPLETADO"
	victory_attempts_label.text = "Intentos: %d" % attempts
	victory_best_label.text = "Mejor puntaje: %d intentos" % best_attempts
	_set_pirate_guide_pose("celebrating")
	if pirate_guide != null:
		pirate_guide.visible = false
	if victory_pirate_guide != null:
		victory_pirate_guide.set_pose("celebrating")
	victory_overlay.visible = true

# Vuelve al menu principal mediante GameManager.
func _on_back_button_pressed() -> void:
	GameManager.return_to_main_menu()

# Reinicia la escena actual mediante GameManager.
func _on_restart_button_pressed() -> void:
	GameManager.restart_game()

# Mantiene el flujo preparado para mundos o niveles futuros.
func _on_next_button_pressed() -> void:
	_set_pirate_guide_pose("holding_map")
	_show_feedback("Siguiente mundo en una fase futura", Color(0.45, 0.78, 0.96, 1.0))

# Anticipa respuesta tactil en botones de juego.
func _play_button_touch(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(0.96, 0.96), 0.05)

# Completa el rebote de boton.
func _play_button_bounce(button: Button) -> void:
	var tween: Tween = create_tween()
	tween.set_trans(Tween.TRANS_BACK)
	tween.set_ease(Tween.EASE_OUT)
	tween.tween_property(button, "scale", Vector2(1.05, 1.05), 0.08)
	tween.tween_property(button, "scale", Vector2.ONE, 0.12)

# Aplica assets finales sin cambiar la logica del minijuego.
func _apply_real_assets() -> void:
	_add_fullscreen_background(BG_MEMORY_GAME)
	_hide_placeholder_nodes(["Sky", "BackHills", "Ground", "CloudStrip"])
	_apply_panel_assets()
	_apply_button_asset(back_button, BUTTON_SECONDARY_BLUE, ICON_MENU, "Menu")
	_apply_button_asset(restart_button, BUTTON_PRIMARY_ORANGE, ICON_RESTART, "Reiniciar", BUTTON_PRIMARY_ORANGE_HOVER, BUTTON_PRIMARY_ORANGE_PRESSED)
	_apply_button_asset(victory_restart_button, BUTTON_SMALL_ORANGE, ICON_RESTART, "Reintentar")
	_apply_button_asset(victory_next_button, BUTTON_SMALL_ORANGE, ICON_NEXT, "Siguiente")
	_apply_button_asset(victory_menu_button, BUTTON_SMALL_ORANGE, ICON_MENU, "Mapa")
	_apply_side_pirate_guide()
	_apply_victory_assets()

# Crea fondo escalable del memorice.
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

	var veil := ColorRect.new()
	veil.name = "GameplayVeil"
	veil.layout_mode = 1
	veil.anchors_preset = Control.PRESET_FULL_RECT
	veil.anchor_right = 1.0
	veil.anchor_bottom = 1.0
	veil.color = Color(1.0, 0.94, 0.78, 0.08)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(veil)
	move_child(veil, 1)

# Oculta fondos placeholder creados con nodos simples.
func _hide_placeholder_nodes(node_names: Array[String]) -> void:
	for node_name in node_names:
		var node := get_node_or_null(node_name)
		if node is CanvasItem:
			(node as CanvasItem).visible = false

# Aplica paneles PNG a tablero, stats, estrellas, mensaje y victoria.
func _apply_panel_assets() -> void:
	_apply_locked_panel_styles()
	_apply_panel("VictoryOverlay/VictoryCenter/VictoryPanel", PANEL_VICTORY, 52)
	_tune_labels()
	_apply_stat_rows()
	_apply_star_panel_assets()

# Fija el sistema visual final del memorice sin depender de paneles decorativos.
func _apply_locked_panel_styles() -> void:
	_set_panel_style("SafeArea/RootBox/TopPanel", _make_flat_style(
		Color(1.0, 0.97, 0.84, 0.95),
		Color(0.98, 0.73, 0.22, 0.88),
		3,
		30,
		Color(0.10, 0.14, 0.18, 0.12),
		10,
		Vector2(0, 4)
	))
	_set_panel_style("SafeArea/RootBox/GameLayout/BoardPanel", _make_flat_style(
		Color(1.0, 0.96, 0.82, 0.94),
		Color(0.00, 0.75, 0.80, 0.96),
		6,
		42,
		Color(0.06, 0.11, 0.15, 0.15),
		18,
		Vector2(0, 7),
		Color(0.96, 0.72, 0.20, 0.92),
		2
	))
	for path in [
		"SafeArea/RootBox/GameLayout/SidePanel/StatsBox/AttemptsBox",
		"SafeArea/RootBox/GameLayout/SidePanel/StatsBox/PairsBox",
		"SafeArea/RootBox/GameLayout/SidePanel/StatsBox/BestBox"
	]:
		_set_panel_style(path, _make_flat_style(
			Color(1.0, 0.97, 0.84, 0.96),
			Color(0.00, 0.72, 0.78, 0.90),
			3,
			18,
			Color(0.08, 0.14, 0.18, 0.10),
			7,
			Vector2(0, 3),
			Color(0.96, 0.72, 0.20, 0.88),
			1
		))
	_set_panel_style("SafeArea/RootBox/GameLayout/SidePanel/StarPanel", _make_flat_style(
		Color(1.0, 0.96, 0.80, 0.97),
		Color(0.00, 0.72, 0.78, 0.92),
		3,
		24,
		Color(0.08, 0.14, 0.18, 0.12),
		9,
		Vector2(0, 4),
		Color(0.96, 0.72, 0.20, 0.88),
		1
	))
	_set_panel_style("FeedbackLayer/FeedbackPanel", _make_flat_style(
		Color(1.0, 0.96, 0.82, 0.98),
		Color(0.00, 0.72, 0.78, 0.92),
		2,
		22,
		Color(0.08, 0.14, 0.18, 0.13),
		10,
		Vector2(0, 4),
		Color(0.96, 0.72, 0.20, 0.82),
		1
	))

# Aplica estilo a paneles existentes.
func _set_panel_style(path: String, style: StyleBoxFlat) -> void:
	var panel := get_node_or_null(path) as PanelContainer
	if panel != null:
		panel.add_theme_stylebox_override("panel", style)

# Crea superficies tactiles del sistema visual final.
func _make_flat_style(
	bg_color: Color,
	border_color: Color,
	border_width: int,
	radius: int,
	shadow_color: Color,
	shadow_size: int,
	shadow_offset: Vector2,
	inner_border_color: Color = Color(0, 0, 0, 0),
	inner_border_width: int = 0
) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_color = border_color
	style.border_width_left = border_width
	style.border_width_top = border_width
	style.border_width_right = border_width
	style.border_width_bottom = border_width
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_right = radius
	style.corner_radius_bottom_left = radius
	style.shadow_color = shadow_color
	style.shadow_size = shadow_size
	style.shadow_offset = shadow_offset
	style.set_expand_margin_all(shadow_size * 0.25)
	if inner_border_width > 0:
		style.border_blend = true
		style.corner_detail = 10
		# Parametros reservados para mantener la intencion de borde interno sin agregar nodos.
		var _unused_inner_border_color := inner_border_color
		var _unused_inner_border_width := inner_border_width
	return style

# Aplica una textura 9-slice a PanelContainer.
func _apply_panel(path: String, texture: Texture2D, margin: int) -> void:
	var panel := get_node_or_null(path) as PanelContainer
	if panel == null:
		return
	panel.add_theme_stylebox_override("panel", _make_texture_stylebox(texture, margin))

# Ajusta texto y espacios para evitar superposiciones con los PNG.
func _tune_labels() -> void:
	var title_label := get_node_or_null("SafeArea/RootBox/TopPanel/TopMargin/Header/TitleLabel") as Label
	if title_label != null:
		title_label.add_theme_color_override("font_color", Color(0.00, 0.45, 0.52, 1.0))
		title_label.add_theme_color_override("font_shadow_color", Color(1.0, 1.0, 1.0, 0.92))
		title_label.add_theme_color_override("font_outline_color", Color(0.0, 0.33, 0.40, 0.18))
		title_label.add_theme_constant_override("shadow_offset_x", 0)
		title_label.add_theme_constant_override("shadow_offset_y", 3)
		title_label.add_theme_constant_override("outline_size", 2)
		title_label.add_theme_font_size_override("font_size", 34)
	for label in [attempts_label, pairs_label, best_label]:
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.add_theme_font_size_override("font_size", 18)
		label.add_theme_color_override("font_color", Color(0.15, 0.22, 0.31, 1.0))
	var star_title := get_node_or_null("SafeArea/RootBox/GameLayout/SidePanel/StarPanel/StarMargin/StarBox/StarTitle") as Label
	if star_title != null:
		star_title.add_theme_color_override("font_color", Color(0.16, 0.24, 0.36, 1.0))
		star_title.add_theme_font_size_override("font_size", 19)
	var star_hint := get_node_or_null("SafeArea/RootBox/GameLayout/SidePanel/StarPanel/StarMargin/StarBox/StarHint") as Label
	if star_hint != null:
		star_hint.add_theme_color_override("font_color", Color(0.16, 0.24, 0.36, 1.0))
		star_hint.text = "Pares encontrados"
		star_hint.add_theme_font_size_override("font_size", 13)

# Organiza los contadores con iconos visibles y texto centrado.
func _apply_stat_rows() -> void:
	_apply_stat_row("SafeArea/RootBox/GameLayout/SidePanel/StatsBox/AttemptsBox", attempts_label, ICON_ATTEMPTS)
	_apply_stat_row("SafeArea/RootBox/GameLayout/SidePanel/StatsBox/PairsBox", pairs_label, ICON_PAIRS)
	_apply_stat_row("SafeArea/RootBox/GameLayout/SidePanel/StatsBox/BestBox", best_label, ICON_BEST_SCORE)

# Crea una fila tactil para estadisticas sin cambiar referencias de labels.
func _apply_stat_row(panel_path: String, label: Label, icon_texture: Texture2D) -> void:
	var panel := get_node_or_null(panel_path) as PanelContainer
	if panel == null or panel.get_node_or_null("StatMargin") != null:
		return

	var old_parent := label.get_parent()
	if old_parent != null:
		old_parent.remove_child(label)

	var margin := MarginContainer.new()
	margin.name = "StatMargin"
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_top", 7)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_bottom", 7)
	panel.add_child(margin)

	var row := HBoxContainer.new()
	row.name = "StatRow"
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 9)
	margin.add_child(row)

	var icon := TextureRect.new()
	icon.name = "StatIcon"
	icon.texture = icon_texture
	icon.custom_minimum_size = Vector2(34, 34)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(icon)

	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(label)

# Cambia estrellas de texto por sprites reales.
func _apply_star_panel_assets() -> void:
	var star_row := get_node_or_null("SafeArea/RootBox/GameLayout/SidePanel/StarPanel/StarMargin/StarBox/StarRow") as HBoxContainer
	if star_row == null:
		return
	for child in star_row.get_children():
		child.queue_free()
	for index in range(3):
		var star := TextureRect.new()
		star.texture = REWARD_STAR_FULL
		star.custom_minimum_size = Vector2(52, 52)
		star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		star_row.add_child(star)

# Agrega el guia al panel lateral para que no cubra cartas ni HUD principal.
func _apply_side_pirate_guide() -> void:
	if pirate_guide != null:
		return
	var side_panel := get_node_or_null("SafeArea/RootBox/GameLayout/SidePanel") as VBoxContainer
	if side_panel == null:
		return

	var guide_holder := PanelContainer.new()
	guide_holder.name = "PirateGuidePanel"
	guide_holder.custom_minimum_size = Vector2(218, 102)
	guide_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	guide_holder.add_theme_stylebox_override("panel", _make_flat_style(
		Color(1.0, 0.97, 0.84, 0.92),
		Color(0.96, 0.72, 0.20, 0.85),
		2,
		24,
		Color(0.08, 0.14, 0.18, 0.10),
		7,
		Vector2(0, 3)
	))
	side_panel.add_child(guide_holder)

	var guide_margin := MarginContainer.new()
	guide_margin.name = "PirateGuideMargin"
	guide_margin.add_theme_constant_override("margin_left", 10)
	guide_margin.add_theme_constant_override("margin_top", 0)
	guide_margin.add_theme_constant_override("margin_right", 8)
	guide_margin.add_theme_constant_override("margin_bottom", 4)
	guide_holder.add_child(guide_margin)

	pirate_guide = _make_pirate_guide("PirateGuideSide", "welcome")
	pirate_guide.custom_minimum_size = Vector2(200, 112)
	guide_margin.add_child(pirate_guide)

# Aplica textura e icono a botones.
func _apply_button_asset(
	button: Button,
	button_texture: Texture2D,
	icon_texture: Texture2D,
	label: String,
	hover_texture: Texture2D = null,
	pressed_texture: Texture2D = null
) -> void:
	button.text = label
	button.icon = icon_texture
	button.expand_icon = true
	button.alignment = HORIZONTAL_ALIGNMENT_CENTER
	button.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_constant_override("h_separation", 10)
	button.add_theme_constant_override("icon_max_width", 34)
	button.add_theme_constant_override("outline_size", 1)
	button.add_theme_color_override("font_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_hover_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_pressed_color", Color(1, 1, 1, 1))
	button.add_theme_color_override("font_disabled_color", Color(0.9, 0.92, 0.95, 1))
	button.add_theme_color_override("font_shadow_color", Color(0.10, 0.14, 0.20, 0.42))
	button.add_theme_color_override("font_outline_color", Color(0.10, 0.14, 0.20, 0.22))
	button.add_theme_constant_override("shadow_offset_x", 0)
	button.add_theme_constant_override("shadow_offset_y", 2)
	button.add_theme_font_size_override("font_size", 21)
	var hover_source: Texture2D = hover_texture if hover_texture != null else button_texture
	var pressed_source: Texture2D = pressed_texture if pressed_texture != null else button_texture
	if label == "Menu" or label == "Reiniciar":
		var is_primary := label == "Reiniciar"
		button.add_theme_stylebox_override("normal", _make_header_button_style(is_primary, 1.0, 0))
		button.add_theme_stylebox_override("hover", _make_header_button_style(is_primary, 1.08, -1))
		button.add_theme_stylebox_override("pressed", _make_header_button_style(is_primary, 0.92, 2))
		button.add_theme_stylebox_override("disabled", _make_header_button_style(is_primary, 0.70, 0))
	else:
		button.add_theme_stylebox_override("normal", _make_texture_stylebox(button_texture, 28))
		button.add_theme_stylebox_override("hover", _make_texture_stylebox(hover_source, 28))
		button.add_theme_stylebox_override("pressed", _make_texture_stylebox(pressed_source, 28))
		button.add_theme_stylebox_override("disabled", _make_texture_stylebox(button_texture, 28))

func _make_header_button_style(is_primary: bool, light: float, press_offset: int) -> StyleBoxFlat:
	var base := Color(1.0, 0.44, 0.07, 1.0) if is_primary else Color(0.00, 0.70, 0.78, 1.0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(
		clamp(base.r * light, 0.0, 1.0),
		clamp(base.g * light, 0.0, 1.0),
		clamp(base.b * light, 0.0, 1.0),
		1.0
	)
	style.border_color = Color(1.0, 0.83, 0.28, 1.0)
	style.border_width_left = 4
	style.border_width_top = 4
	style.border_width_right = 4
	style.border_width_bottom = 4
	style.corner_radius_top_left = 32
	style.corner_radius_top_right = 32
	style.corner_radius_bottom_right = 32
	style.corner_radius_bottom_left = 32
	style.shadow_color = Color(0.48, 0.27, 0.08, 0.30)
	style.shadow_size = 8
	style.shadow_offset = Vector2(0, 4 + press_offset)
	style.corner_detail = 16
	style.content_margin_left = 24
	style.content_margin_right = 24
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	style.set_expand_margin_all(3)
	return style

# Reemplaza el placeholder de victoria y estrellas por sprites reales.
func _apply_victory_assets() -> void:
	var mascot := get_node_or_null("VictoryOverlay/VictoryCenter/VictoryPanel/VictoryMargin/VictoryLayout/VictoryMascot")
	if mascot != null:
		(mascot as Control).custom_minimum_size = Vector2(220, 330)
		for child in mascot.get_children():
			if child is CanvasItem:
				(child as CanvasItem).visible = false
		victory_pirate_guide = _make_pirate_guide("PirateGuideVictory", "celebrating")
		victory_pirate_guide.layout_mode = 1
		victory_pirate_guide.anchors_preset = Control.PRESET_FULL_RECT
		victory_pirate_guide.anchor_right = 1.0
		victory_pirate_guide.anchor_bottom = 1.0
		victory_pirate_guide.offset_top = 18.0
		victory_pirate_guide.offset_bottom = -10.0
		victory_pirate_guide.offset_left = 0.0
		victory_pirate_guide.offset_right = 0.0
		mascot.add_child(victory_pirate_guide)

	var stars_label := get_node_or_null("VictoryOverlay/VictoryCenter/VictoryPanel/VictoryMargin/VictoryLayout/VictoryBox/VictoryStars") as Label
	if stars_label != null:
		stars_label.text = ""
		if stars_label.get_node_or_null("RewardStars") == null:
			var row := HBoxContainer.new()
			row.name = "RewardStars"
			row.alignment = BoxContainer.ALIGNMENT_CENTER
			row.add_theme_constant_override("separation", 8)
			stars_label.add_child(row)
			for index in range(3):
				var star := TextureRect.new()
				star.texture = REWARD_STAR_FULL if index < 2 else REWARD_STAR_EMPTY
				star.custom_minimum_size = Vector2(58, 58)
				star.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
				star.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
				row.add_child(star)

			var sparkle := TextureRect.new()
			sparkle.name = "RewardSparkle"
			sparkle.texture = REWARD_SPARKLE
			sparkle.custom_minimum_size = Vector2(46, 46)
			sparkle.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			sparkle.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			row.add_child(sparkle)

# Convierte un PNG en StyleBoxTexture.
func _make_texture_stylebox(texture: Texture2D, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.draw_center = true
	return style

func _make_pirate_guide(node_name: String, pose: String) -> PirateGuide:
	var guide := PIRATE_GUIDE_SCENE.instantiate() as PirateGuide
	guide.name = node_name
	guide.default_pose = pose
	guide.bounce_enabled = true
	guide.layout_mode = 1
	guide.anchors_preset = Control.PRESET_FULL_RECT
	guide.anchor_right = 1.0
	guide.anchor_bottom = 1.0
	guide.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return guide

func _set_pirate_guide_pose(pose: String) -> void:
	if pirate_guide != null:
		pirate_guide.set_pose(pose)
