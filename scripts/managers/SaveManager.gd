extends Node

# Centraliza lectura y escritura de progreso local.
const SAVE_FILE_PATH: String = "user://save_data.json"

var default_save_data: Dictionary = {
	"current_level": 1,
	"completed_levels": [],
	"best_attempts": {},
	"unlocked_characters": [],
	"coins": 0,
	"music_enabled": true,
	"sfx_enabled": true
}

# Guarda datos del jugador en formato JSON.
func save_game(data: Dictionary) -> void:
	var merged_data: Dictionary = _merge_with_defaults(data)

	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file == null:
		push_error("No se pudo abrir el archivo de guardado.")
		return

	file.store_string(JSON.stringify(merged_data, "\t"))
	file.close()

# Carga datos guardados o devuelve valores por defecto.
func load_game() -> Dictionary:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return default_save_data.duplicate(true)

	var file: FileAccess = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file == null:
		push_error("No se pudo leer el archivo de guardado.")
		return default_save_data.duplicate(true)

	var content: String = file.get_as_text()
	file.close()

	var parsed_data: Variant = JSON.parse_string(content)
	if typeof(parsed_data) != TYPE_DICTIONARY:
		return default_save_data.duplicate(true)

	return _merge_with_defaults(parsed_data as Dictionary)

# Guarda un nivel completado y conserva la mejor cantidad de intentos.
func save_level_progress(level_id: String, attempts: int) -> Dictionary:
	var save_data: Dictionary = load_game()
	var completed_levels: Array = save_data.get("completed_levels", [])
	if not completed_levels.has(level_id):
		completed_levels.append(level_id)
	save_data["completed_levels"] = completed_levels

	var best_attempts: Dictionary = save_data.get("best_attempts", {})
	var previous_best: int = int(best_attempts.get(level_id, 0))
	if previous_best == 0 or attempts < previous_best:
		best_attempts[level_id] = attempts
	save_data["best_attempts"] = best_attempts

	save_game(save_data)
	return save_data

# Devuelve el mejor puntaje de intentos para un nivel.
func get_best_attempts(level_id: String) -> int:
	var save_data: Dictionary = load_game()
	var best_attempts: Dictionary = save_data.get("best_attempts", {})
	return int(best_attempts.get(level_id, 0))

# Indica si un nivel ya fue completado.
func is_level_completed(level_id: String) -> bool:
	var save_data: Dictionary = load_game()
	var completed_levels: Array = save_data.get("completed_levels", [])
	return completed_levels.has(level_id)

# Borra el progreso local y restaura valores iniciales.
func reset_save() -> void:
	if FileAccess.file_exists(SAVE_FILE_PATH):
		DirAccess.remove_absolute(SAVE_FILE_PATH)

# Mantiene compatibilidad si se agregan nuevas claves al guardado.
func _merge_with_defaults(data: Dictionary) -> Dictionary:
	var merged_data: Dictionary = default_save_data.duplicate(true)
	for key in data.keys():
		merged_data[key] = data[key]
	return merged_data
