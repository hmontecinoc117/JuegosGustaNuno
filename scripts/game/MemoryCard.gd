extends Button
class_name MemoryCard

signal card_selected(card: MemoryCard)

const BACK_TEXT: String = "?"
const CARD_BACK_TEXTURE: Texture2D = preload("res://assets/ui/cards/card_back_default.png")
const CARD_FRONT_TEXTURE: Texture2D = preload("res://assets/ui/cards/card_front_default.png")
const CARD_SUCCESS_TEXTURE: Texture2D = preload("res://assets/ui/cards/card_front_success.png")
const CARD_ERROR_TEXTURE: Texture2D = preload("res://assets/ui/cards/card_front_error.png")
const CARD_PAW_ICON: Texture2D = preload("res://assets/ui/icons/icon_attempts.png")
const ANIMAL_VISUAL_TUNING: Dictionary = {
	"leon": {"scale": 1.08, "offset": Vector2(0, -1)},
	"perro": {"scale": 1.08, "offset": Vector2(0, -1)},
	"gato": {"scale": 1.06, "offset": Vector2(0, 0)},
	"pato": {"scale": 1.08, "offset": Vector2(0, -1)},
	"oso": {"scale": 1.06, "offset": Vector2(0, 0)},
	"pez": {"scale": 1.02, "offset": Vector2(0, 0)}
}

@onready var back_face: PanelContainer = %BackFace
@onready var front_face: PanelContainer = %FrontFace
@onready var animal_label_node: Label = %AnimalLabel
@onready var animal_sprite_node: TextureRect = %AnimalSprite
@onready var back_texture_node: TextureRect = get_node_or_null("BackFace/BackTexture") as TextureRect
@onready var front_texture_node: TextureRect = get_node_or_null("FrontFace/FrontTexture") as TextureRect
@onready var back_center: CenterContainer = get_node_or_null("BackFace/BackCenter") as CenterContainer
@onready var back_badge: PanelContainer = get_node_or_null("BackFace/BackCenter/BackBadge") as PanelContainer
@onready var back_label: Label = get_node_or_null("BackFace/BackCenter/BackBadge/BackLabel") as Label

var card_id: String = ""
var animal_label: String = ""
var animal_texture: Texture2D
var is_face_up: bool = false
var is_matched: bool = false
var is_locked: bool = false
var active_tween: Tween

# Conecta la interaccion propia de la carta.
func _ready() -> void:
	pressed.connect(_on_pressed)
	pivot_offset = size * 0.5
	_apply_card_assets()
	_reset_visual_state()

# Mantiene el pivote centrado si Godot recalcula el tamano del boton.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		pivot_offset = size * 0.5

# Configura los datos de la carta antes de iniciar la partida.
func setup_card(new_card_id: String, new_animal_label: String, new_texture: Texture2D = null) -> void:
	card_id = new_card_id
	animal_label = new_animal_label
	animal_texture = new_texture
	if is_node_ready():
		reset_card()

# Evita seleccionar cartas bloqueadas, reveladas o ya resueltas.
func _on_pressed() -> void:
	if is_locked or is_face_up or is_matched:
		return
	touch_bounce()
	card_selected.emit(self)

# Muestra el contenido de la carta con un giro simple.
func reveal_card() -> void:
	if is_face_up:
		return
	is_face_up = true
	set_card_locked(true)
	await _play_flip(false)
	_show_front()
	await _play_flip(true)
	if not is_matched:
		set_card_locked(false)

# Oculta el contenido si la carta aun no fue emparejada.
func hide_card() -> void:
	if is_matched:
		return
	is_face_up = false
	set_card_locked(true)
	await _play_flip(false)
	_reset_visual_state()
	await _play_flip(true)
	set_card_locked(false)

# Muestra el frente para revision visual de animales reales.
func show_preview_front() -> void:
	is_face_up = true
	is_locked = true
	disabled = true
	scale = Vector2.ONE
	_show_front()

# Marca la carta como par encontrado y reproduce feedback positivo.
func mark_as_matched() -> void:
	is_matched = true
	is_face_up = true
	is_locked = true
	disabled = true
	_show_front()
	_set_front_texture(CARD_SUCCESS_TEXTURE)
	await match_success()

# Reproduce un rebote tactil corto al tocar.
func touch_bounce() -> void:
	_kill_tween()
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_BACK)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", Vector2(0.96, 0.96), 0.05)
	active_tween.tween_property(self, "scale", Vector2.ONE, 0.1)

# Reproduce un pequeno salto para aciertos.
func match_success() -> void:
	_kill_tween()
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_BACK)
	active_tween.set_ease(Tween.EASE_OUT)
	active_tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.12)
	active_tween.tween_property(self, "scale", Vector2.ONE, 0.16)
	await active_tween.finished

# Reproduce una sacudida para errores.
func wrong_pair() -> void:
	_kill_tween()
	var start_position: Vector2 = position
	_set_front_texture(CARD_ERROR_TEXTURE)
	active_tween = create_tween()
	active_tween.tween_property(self, "position", start_position + Vector2(-10, 0), 0.06)
	active_tween.tween_property(self, "position", start_position + Vector2(10, 0), 0.06)
	active_tween.tween_property(self, "position", start_position, 0.06)
	await active_tween.finished
	position = start_position
	_set_front_texture(CARD_FRONT_TEXTURE)

# Bloquea o habilita la carta durante validaciones temporales.
func set_card_locked(value: bool) -> void:
	is_locked = value
	if not is_matched:
		disabled = value

# Restaura la carta para una nueva partida.
func reset_card() -> void:
	is_face_up = false
	is_matched = false
	is_locked = false
	disabled = false
	scale = Vector2.ONE
	rotation = 0.0
	if is_node_ready():
		_reset_visual_state()

# Aplica el aspecto de carta boca abajo.
func _reset_visual_state() -> void:
	back_face.visible = true
	front_face.visible = false
	animal_sprite_node.texture = null
	animal_label_node.text = ""
	_set_front_texture(CARD_FRONT_TEXTURE)

# Aplica el aspecto de carta revelada y deja preparado el uso de sprites reales.
func _show_front() -> void:
	back_face.visible = false
	front_face.visible = true
	animal_label_node.text = ""
	animal_sprite_node.texture = animal_texture
	_apply_animal_fit()

# Ejecuta medio giro para simular volteo sin requerir animaciones externas.
func _play_flip(showing: bool) -> void:
	_kill_tween()
	var target_scale_x: float = 1.0 if showing else 0.08
	active_tween = create_tween()
	active_tween.set_trans(Tween.TRANS_SINE)
	active_tween.set_ease(Tween.EASE_IN_OUT)
	active_tween.tween_property(self, "scale:x", target_scale_x, 0.11)
	await active_tween.finished

# Cancela animaciones previas antes de iniciar una nueva.
func _kill_tween() -> void:
	if active_tween != null and active_tween.is_valid():
		active_tween.kill()

# Aplica cartas base generadas como PNG.
func _apply_card_assets() -> void:
	if back_center != null:
		back_center.visible = false
	if back_badge != null:
		back_badge.custom_minimum_size = Vector2(54, 54)
		back_badge.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
		if back_badge.get_node_or_null("BackPawIcon") == null:
			var paw_icon := TextureRect.new()
			paw_icon.name = "BackPawIcon"
			paw_icon.texture = CARD_PAW_ICON
			paw_icon.custom_minimum_size = Vector2(42, 42)
			paw_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			paw_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			paw_icon.modulate = Color(1.0, 0.88, 0.36, 0.72)
			paw_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			back_badge.add_child(paw_icon)
	if back_label != null:
		back_label.visible = false
	back_face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	front_face.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	if back_texture_node != null:
		back_texture_node.texture = CARD_BACK_TEXTURE
		back_texture_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back_texture_node.stretch_mode = TextureRect.STRETCH_SCALE
	_set_front_texture(CARD_FRONT_TEXTURE)
	add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	add_theme_stylebox_override("disabled", StyleBoxEmpty.new())
	animal_sprite_node.custom_minimum_size = Vector2(118, 120)
	animal_sprite_node.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	animal_sprite_node.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED

# Normaliza la presencia visual de cada animal dentro del frente de carta.
func _apply_animal_fit() -> void:
	var tuning: Dictionary = ANIMAL_VISUAL_TUNING.get(card_id, {})
	var visual_scale: float = float(tuning.get("scale", 0.95))
	var visual_offset: Vector2 = tuning.get("offset", Vector2.ZERO)
	animal_sprite_node.scale = Vector2(visual_scale, visual_scale)
	animal_sprite_node.position = visual_offset

# Cambia la textura frontal completa sin deformarla como marco 9-slice.
func _set_front_texture(texture: Texture2D) -> void:
	if front_texture_node != null:
		front_texture_node.texture = texture

# Convierte PNGs de carta en paneles escalables.
func _make_texture_stylebox(texture: Texture2D, margin: int) -> StyleBoxTexture:
	var style := StyleBoxTexture.new()
	style.texture = texture
	style.texture_margin_left = margin
	style.texture_margin_top = margin
	style.texture_margin_right = margin
	style.texture_margin_bottom = margin
	style.draw_center = true
	return style
