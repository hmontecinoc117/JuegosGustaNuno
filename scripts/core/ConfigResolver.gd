extends Node
class_name ConfigResolver

const JsonConfigLoader = preload("res://scripts/core/JsonConfigLoader.gd")

# Resuelve una ruta de textura con fallback sin romper si falta el asset.
static func get_valid_texture_path(primary_path: String, fallback_path: String = "") -> String:
	if not primary_path.is_empty() and ResourceLoader.exists(primary_path):
		return primary_path
	if not fallback_path.is_empty() and ResourceLoader.exists(fallback_path):
		return fallback_path
	if not primary_path.is_empty():
		push_warning("Asset no encontrado: " + primary_path)
	return ""

static func load_texture(primary_path: String, fallback_path: String = "") -> Texture2D:
	var valid_path := get_valid_texture_path(primary_path, fallback_path)
	if valid_path.is_empty():
		return null
	return load(valid_path) as Texture2D

static func color_from_hex(hex_color: String, alpha: float = 1.0) -> Color:
	var color := Color(hex_color)
	color.a = alpha
	return color

static func resolve_scene_path(scene_constant: String, scene_path: String = "") -> String:
	match scene_constant:
		"SCENE_MAIN_MENU":
			return AppConstants.SCENE_MAIN_MENU
		"SCENE_MINIGAMES_MENU":
			return AppConstants.SCENE_MINIGAMES_MENU
		"SCENE_MEMORY_GAME":
			return AppConstants.SCENE_MEMORY_GAME
		"SCENE_PUZZLE_GAME":
			return AppConstants.SCENE_PUZZLE_GAME
		_:
			return scene_path

static func get_save_value(save_data: Dictionary, key_path: String, default_value: Variant = null) -> Variant:
	return JsonConfigLoader.get_value(save_data, key_path, default_value)

static func is_unlock_rule_completed(rule_id: String, rules_config: Dictionary, save_data: Dictionary) -> bool:
	if rule_id.is_empty():
		return true
	var rules: Dictionary = rules_config.get("rules", {})
	if not rules.has(rule_id):
		return false
	var rule: Dictionary = rules.get(rule_id, {})
	var rule_type := String(rule.get("type", ""))

	if rule_type == "completed_games":
		var required_games: Array = rule.get("games", [])
		var completed_levels: Array = save_data.get("completed_levels", [])
		for game_id in required_games:
			if not completed_levels.has(String(game_id)) and not completed_levels.has("%s_game_01" % String(game_id)):
				return false
		return true

	if rule_type == "stars_total":
		return int(save_data.get("stars_total", 0)) >= int(rule.get("value", 0))

	return false
