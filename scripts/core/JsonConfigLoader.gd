extends Node
class_name JsonConfigLoader

# Carga un archivo JSON y devuelve un Dictionary seguro.
static func load_json_config(path: String) -> Dictionary:
	if path.is_empty():
		push_warning("JsonConfigLoader recibio una ruta vacia.")
		return {}
	if not FileAccess.file_exists(path):
		push_warning("No existe el JSON de configuracion: " + path)
		return {}

	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_warning("No se pudo abrir el JSON de configuracion: " + path)
		return {}

	var content := file.get_as_text()
	file.close()

	var parsed: Variant = JSON.parse_string(content)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("El JSON no devolvio un Dictionary valido: " + path)
		return {}

	return parsed as Dictionary

# Lee un valor usando una ruta tipo "header.logo.texture_path".
static func get_value(data: Dictionary, key_path: String, default_value: Variant = null) -> Variant:
	if key_path.is_empty():
		return default_value

	var current: Variant = data
	for key in key_path.split("."):
		if typeof(current) != TYPE_DICTIONARY:
			return default_value
		var current_dict := current as Dictionary
		if not current_dict.has(key):
			return default_value
		current = current_dict[key]
	return current

# Indica si una ruta anidada existe.
static func has_key_path(data: Dictionary, key_path: String) -> bool:
	if key_path.is_empty():
		return false

	var current: Variant = data
	for key in key_path.split("."):
		if typeof(current) != TYPE_DICTIONARY:
			return false
		var current_dict := current as Dictionary
		if not current_dict.has(key):
			return false
		current = current_dict[key]
	return true
