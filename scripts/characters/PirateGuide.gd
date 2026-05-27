class_name PirateGuide
extends Control

@export var default_pose: String = "idle"
@export var bounce_enabled: bool = false
@export var bounce_height: float = 10.0
@export var bounce_duration: float = 0.95
@export var alpha_crop_enabled: bool = true
@export var alpha_crop_padding: int = 18
@export var alpha_largest_component_crop: bool = true
@export var background_cleanup_enabled: bool = false
@export var background_edge_delta: float = 0.12

@onready var texture_rect: TextureRect = %GuideTexture

var pose_map: Dictionary = {
	"idle": "res://assets/sprites/characters/pirate_guide/pirate_idle.png",
	"welcome": "res://assets/sprites/characters/pirate_guide/pirate_welcome.png",
	"pointing": "res://assets/sprites/characters/pirate_guide/pirate_pointing.png",
	"happy": "res://assets/sprites/characters/pirate_guide/pirate_celebrating.png",
	"celebrating": "res://assets/sprites/characters/pirate_guide/pirate_celebrating.png",
	"holding_map": "res://assets/sprites/characters/pirate_guide/pirate_holding_map.png",
	"badge": "res://assets/sprites/characters/pirate_guide/pirate_badge.png"
}

var pose_fallbacks: Dictionary = {
	"holding_map": ["res://assets/sprites/characters/pirate_guide/pirate_holdingmap.png"]
}

var current_pose: String = ""
var bounce_tween: Tween
var processed_texture_cache: Dictionary = {}

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	texture_rect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	set_pose(default_pose)
	if bounce_enabled:
		start_bounce()

func set_pose(pose_name: String) -> void:
	var texture_path := _resolve_pose_path(pose_name)
	if texture_path.is_empty():
		push_warning("PirateGuide: no texture found for pose '%s'; guide will stay unchanged." % pose_name)
		return

	var texture := load(texture_path) as Texture2D
	if texture == null:
		push_warning("PirateGuide: failed to load texture '%s' for pose '%s'." % [texture_path, pose_name])
		return

	texture_rect.texture = _make_alpha_cropped_texture(texture_path, texture)
	current_pose = pose_name

func start_bounce() -> void:
	stop_bounce()
	var base_position := position
	bounce_tween = create_tween()
	bounce_tween.set_loops()
	bounce_tween.set_trans(Tween.TRANS_SINE)
	bounce_tween.set_ease(Tween.EASE_IN_OUT)
	bounce_tween.tween_property(self, "position", base_position + Vector2(0, -bounce_height), bounce_duration)
	bounce_tween.tween_property(self, "position", base_position, bounce_duration)

func stop_bounce() -> void:
	if bounce_tween != null and bounce_tween.is_valid():
		bounce_tween.kill()
	bounce_tween = null

func _resolve_pose_path(pose_name: String) -> String:
	var candidates: Array[String] = []
	if pose_map.has(pose_name):
		candidates.append(String(pose_map[pose_name]))
	if pose_fallbacks.has(pose_name):
		for fallback_path in pose_fallbacks[pose_name]:
			candidates.append(String(fallback_path))
	candidates.append(String(pose_map["idle"]))

	for candidate in candidates:
		if ResourceLoader.exists(candidate):
			if candidate != String(pose_map.get(pose_name, "")):
				push_warning("PirateGuide: pose '%s' using fallback texture '%s'." % [pose_name, candidate])
			return candidate
	return ""

func _make_alpha_cropped_texture(texture_path: String, fallback_texture: Texture2D) -> Texture2D:
	if not alpha_crop_enabled and not background_cleanup_enabled:
		return fallback_texture
	if processed_texture_cache.has(texture_path):
		return processed_texture_cache[texture_path]

	var image := Image.new()
	var error := image.load(ProjectSettings.globalize_path(texture_path))
	if error != OK or image.is_empty():
		return fallback_texture

	if background_cleanup_enabled:
		_clear_border_connected_background(image)

	var used_rect := _get_alpha_used_rect(image)
	if alpha_largest_component_crop:
		used_rect = _get_largest_alpha_component_rect(image, used_rect)
	if used_rect.size.x <= 0 or used_rect.size.y <= 0:
		return fallback_texture

	var source_image := image
	if alpha_crop_enabled:
		used_rect = _pad_rect(used_rect, image.get_size(), alpha_crop_padding)
		source_image = image.get_region(used_rect)

	var processed_texture := ImageTexture.create_from_image(source_image)
	processed_texture_cache[texture_path] = processed_texture
	return processed_texture

func _clear_border_connected_background(image: Image) -> void:
	var size := image.get_size()
	if size.x <= 0 or size.y <= 0:
		return

	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	visited.fill(0)

	var queue: Array[Vector2i] = []
	for x in range(size.x):
		_try_enqueue_background_pixel(image, visited, queue, Vector2i(x, 0), Color.TRANSPARENT)
		_try_enqueue_background_pixel(image, visited, queue, Vector2i(x, size.y - 1), Color.TRANSPARENT)
	for y in range(size.y):
		_try_enqueue_background_pixel(image, visited, queue, Vector2i(0, y), Color.TRANSPARENT)
		_try_enqueue_background_pixel(image, visited, queue, Vector2i(size.x - 1, y), Color.TRANSPARENT)

	var queue_index := 0
	while queue_index < queue.size():
		var point := queue[queue_index]
		queue_index += 1
		var color := image.get_pixel(point.x, point.y)
		image.set_pixel(point.x, point.y, Color(color.r, color.g, color.b, 0.0))
		_try_enqueue_background_pixel(image, visited, queue, point + Vector2i(1, 0), color)
		_try_enqueue_background_pixel(image, visited, queue, point + Vector2i(-1, 0), color)
		_try_enqueue_background_pixel(image, visited, queue, point + Vector2i(0, 1), color)
		_try_enqueue_background_pixel(image, visited, queue, point + Vector2i(0, -1), color)

func _try_enqueue_background_pixel(
	image: Image,
	visited: PackedByteArray,
	queue: Array[Vector2i],
	point: Vector2i,
	previous_color: Color
) -> void:
	var size := image.get_size()
	if point.x < 0 or point.y < 0 or point.x >= size.x or point.y >= size.y:
		return

	var index := point.y * size.x + point.x
	if visited[index] == 1:
		return

	var color := image.get_pixel(point.x, point.y)
	if color.a <= 0.02:
		visited[index] = 1
		queue.append(point)
		return

	if previous_color.a <= 0.02:
		return

	if previous_color.a > 0.02 and _color_delta(color, previous_color) > background_edge_delta:
		return

	visited[index] = 1
	queue.append(point)

func _color_delta(a: Color, b: Color) -> float:
	return absf(a.r - b.r) + absf(a.g - b.g) + absf(a.b - b.b)

func _get_alpha_used_rect(image: Image) -> Rect2i:
	var size := image.get_size()
	var min_x := size.x
	var min_y := size.y
	var max_x := -1
	var max_y := -1

	for y in range(size.y):
		for x in range(size.x):
			if image.get_pixel(x, y).a > 0.02:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)

	if max_x < min_x or max_y < min_y:
		return Rect2i()
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)

func _get_largest_alpha_component_rect(image: Image, fallback_rect: Rect2i) -> Rect2i:
	var size := image.get_size()
	if size.x <= 0 or size.y <= 0:
		return fallback_rect

	var visited := PackedByteArray()
	visited.resize(size.x * size.y)
	visited.fill(0)

	var best_rect := Rect2i()
	var best_count := 0
	for y in range(size.y):
		for x in range(size.x):
			var index := y * size.x + x
			if visited[index] == 1:
				continue
			if image.get_pixel(x, y).a <= 0.02:
				visited[index] = 1
				continue

			var component := _scan_alpha_component(image, visited, Vector2i(x, y))
			var component_count := int(component["count"])
			if component_count > best_count:
				best_count = component_count
				best_rect = component["rect"] as Rect2i

	return best_rect if best_count > 0 else fallback_rect

func _scan_alpha_component(image: Image, visited: PackedByteArray, start: Vector2i) -> Dictionary:
	var size := image.get_size()
	var queue: Array[Vector2i] = [start]
	var min_x := start.x
	var min_y := start.y
	var max_x := start.x
	var max_y := start.y
	var count := 0
	visited[start.y * size.x + start.x] = 1

	var queue_index := 0
	while queue_index < queue.size():
		var point := queue[queue_index]
		queue_index += 1
		count += 1
		min_x = mini(min_x, point.x)
		min_y = mini(min_y, point.y)
		max_x = maxi(max_x, point.x)
		max_y = maxi(max_y, point.y)

		for offset: Vector2i in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var next_point: Vector2i = point + offset
			if next_point.x < 0 or next_point.y < 0 or next_point.x >= size.x or next_point.y >= size.y:
				continue
			var next_index: int = next_point.y * size.x + next_point.x
			if visited[next_index] == 1:
				continue
			visited[next_index] = 1
			if image.get_pixel(next_point.x, next_point.y).a <= 0.02:
				continue
			queue.append(next_point)

	return {
		"count": count,
		"rect": Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
	}

func _pad_rect(rect: Rect2i, image_size: Vector2i, padding: int) -> Rect2i:
	var left := maxi(rect.position.x - padding, 0)
	var top := maxi(rect.position.y - padding, 0)
	var right := mini(rect.position.x + rect.size.x + padding, image_size.x)
	var bottom := mini(rect.position.y + rect.size.y + padding, image_size.y)
	return Rect2i(left, top, right - left, bottom - top)
