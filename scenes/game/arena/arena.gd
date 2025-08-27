extends Node2D

signal player_crashed(player_id)
signal round_ended(winner_id)

const PLAYER_SCENE: PackedScene = preload("res://objects/player/player.tscn")
const POWERUP_SCENE: PackedScene = preload("res://objects/powerups/powerup.tscn")

@onready var _players_root: Node2D = $Players
@onready var _powerups_root: Node2D = $Powerups
@onready var _walls: Node2D = $Walls

@export var arena_width: float = 1400.0:
	set(value):
		arena_width = value
		_walls.set_size(arena_width, arena_height, border_width)
@export var arena_height: float = 1400.0:
	set(value):
		arena_height = value
		_walls.set_size(arena_width, arena_height, border_width)
@export var border_width: float = 10.0:
	set(value):
		border_width = value
		_walls.set_size(arena_width, arena_height, border_width)

func _ready() -> void:
	_connect_signals()
	_walls.set_size(arena_width, arena_height, border_width)

## Connects existing players and powerup signals to arena. used for editor
func _connect_signals() -> void:
	for player in _players_root.get_children():
		if player is Player: player.crashed.connect(_on_player_crash)
	for powerup in _powerups_root.get_children():
		if powerup is Powerup: powerup.obtained.connect(_on_powerup_obtain, CONNECT_ONE_SHOT)


func _create_players():
	return

## get [Player] form player id
func _get_player_from_id(player_id: int) -> Player:
	for player in _players_root.get_children():
		if player is Player and player.player_id == player_id:
			return player
	return null

## Add a powerup to the arena with given values
func _add_powerup(power_id, power_type, pos: Vector2 = Vector2.ZERO) -> void:
	var powerup = POWERUP_SCENE.instantiate()
	powerup.power_id = power_id as Powerup.POWER
	powerup.power_type = power_type as Powerup.TYPE
	powerup.position = pos
	powerup.obtained.connect(_on_powerup_obtain, CONNECT_ONE_SHOT)

	_powerups_root.add_child(powerup)

func _clear_players() -> void:
	for player in _players_root.get_children():
		player.queue_free()

func _clear_powerups() -> void:
	for powerup in _powerups_root.get_children():
		powerup.queue_free()

# Public function
# ===============

func new_game() -> void:
	_clear_players()
	_clear_powerups()

func new_round() -> void:
	_clear_powerups()
	for player in _players_root.get_children():
		if player is Player:
			player.set_default_values()
			player.delete_trail()

# Signal calls
# ============

func _on_player_crash(crasher_id: int, obstacle_id: int, is_player: bool):
	print(_get_player_from_id(crasher_id).name + " crashed!!!")

func _on_powerup_obtain(player_id: int, power_id, power_type):
	match power_type as Powerup.TYPE:
		Powerup.TYPE.ALL:
			for player in _players_root.get_children():
				if player is Player: player.apply_power(power_id)
		Powerup.TYPE.OTHERS:
			for player in _players_root.get_children():
				if player is Player and player.player_id != player_id:
					player.apply_power(power_id)
		Powerup.TYPE.SELF:
			for player in _players_root.get_children():
				if player is Player and player.player_id == player_id:
					player.apply_power(power_id)
			

