@tool
class_name Powerup extends Area2D

signal obtained(player_id: int, power_id: POWER, power_type: TYPE)


enum TYPE{ALL, SELF, OTHERS}
const TYPE_COLOR: Array[Color] = [Color.BLUE, Color.GREEN, Color.RED]

enum POWER{FAST, SLOW, WIDE, THIN, SQUARE,
			CLEAR_TRAIL, INVINCIBLE, REVERSE, LOOP, SCRAMBLE}
const POWER_NAMES := ["fast", "slow", "wide", "thin", "square",
					"clear_trail", "invincible", "reverse", "loop", "scramble"]
const SPRITES_DIR: String = "res://assets/sprites/powerups/"


@onready var circle_sprite: Sprite2D = $Circle
@onready var power_sprite: Sprite2D = $Power

@export var power_type: TYPE:
	set(value):
		power_type = value as TYPE
		if Engine.is_editor_hint(): _ready()
@export var power_id: POWER:
	set(value):
		power_id = value as POWER
		if Engine.is_editor_hint(): _ready()

func _ready() -> void:
	name = POWER_NAMES[power_id].capitalize()
	circle_sprite.modulate = TYPE_COLOR[power_type]
	var power_texture = load(SPRITES_DIR.path_join(POWER_NAMES[power_id]) + ".png")
	if power_texture: power_sprite.texture = power_texture

## Called by player that obtained power
func activate(player: Player) -> void:
	obtained.emit(player.player_id, power_id, power_type)
	queue_free()
	
