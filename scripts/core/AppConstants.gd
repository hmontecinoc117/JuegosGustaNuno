extends Node
class_name AppConstants

# Rutas principales de escenas usadas por el flujo base del juego.
const MAIN_MENU_SCENE: String = "res://scenes/ui/MainMenu.tscn"
const GAME_SCENE: String = "res://scenes/game/GameScene.tscn"
const MEMORY_GAME_SCENE: String = "res://scenes/game/MemoryGame.tscn"
const MEMORY_CARD_SCENE: String = "res://scenes/game/MemoryCard.tscn"
const MINIGAMES_MENU_SCENE: String = "res://scenes/ui/MiniGamesMenu.tscn"
const PUZZLE_GAME_SCENE: String = "res://scenes/game/PuzzleGame.tscn"

# Alias nuevos para pantallas de catalogo y minijuegos.
const SCENE_MAIN_MENU: String = MAIN_MENU_SCENE
const SCENE_MINIGAMES_MENU: String = MINIGAMES_MENU_SCENE
const SCENE_MEMORY_GAME: String = MEMORY_GAME_SCENE
const SCENE_PUZZLE_GAME: String = PUZZLE_GAME_SCENE

# Identificadores de niveles y minijuegos.
const MEMORY_LEVEL_ID: String = "memory_game_01"

# Nombre del archivo local usado por SaveManager.
const SAVE_FILE_PATH: String = "user://save_data.json"

# Valores base para Android horizontal.
const BASE_WIDTH: int = 1280
const BASE_HEIGHT: int = 720

# Rutas opcionales para audio profesional. Si no existen, AudioManager no falla.
const AUDIO_CARD_FLIP: String = "res://assets/audio/sfx/card_flip.ogg"
const AUDIO_MATCH_OK: String = "res://assets/audio/sfx/match_ok.ogg"
const AUDIO_MATCH_ERROR: String = "res://assets/audio/sfx/match_error.ogg"
const AUDIO_VICTORY: String = "res://assets/audio/sfx/victory.ogg"
const AUDIO_MEMORY_MUSIC: String = "res://assets/audio/music/memory_theme.ogg"

# Configuracion de pantallas data-driven.
const MINIGAMES_MENU_CONFIG: String = "res://config/ui/minigames_menu_config.json"
