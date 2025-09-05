extends Node

const DEFAULT_NAMES: Array[String] = ["Fred", "Bluebell", "Greenlee", "Pinkey", "Willem", "Greydon"]
const DEFAULT_COLORS: Array[Color] = [Color.RED, Color.CYAN, Color.GREEN, Color.PINK, Color.ORANGE, Color.LIGHT_GRAY]

# Game settings
var game_settings: Game.Settings = null
# Arena settings
var arena_settings: Arena.Settings = null
# array of Player.Settings
var players_settings: Array = []

func _ready():
	if not game_settings: game_settings = Game.Settings.new()
	if not arena_settings: arena_settings = Arena.Settings.new()
	if players_settings.is_empty():
		players_settings.resize(game_settings.player_count)
		for i in range(min(game_settings.player_count, DEFAULT_NAMES.size())):
			players_settings[i] = Player.Settings.new()
			players_settings[i].name = DEFAULT_NAMES[i]
			players_settings[i].trail_color = DEFAULT_COLORS[i]


# Helper functions
func clamp_angle(angle: float) -> float:
	if angle < 0: angle += 2.0*PI
	elif angle > 2.0*PI: angle -= 2.0*PI
	return angle
