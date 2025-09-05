class_name Arena extends Node2D

signal player_crashed(player_id)

class Settings:
	var powerups_enabled: bool = true
	var powerup_frequencies: Array[float] = []
	var powerup_type_frequencies: Array[Array] = []
	var powerup_times: Array[float] = []
	var powerup_delay: float = 7.0
	var delay_offset: float = 2.5

	func _init() -> void:
		var power_count: int = Powerup.Power.values().size()

		powerup_frequencies.resize(power_count)
		powerup_frequencies.fill(1)

		powerup_type_frequencies.resize(power_count)
		powerup_type_frequencies.fill([])
		for arr in powerup_type_frequencies:
			arr.resize(3)
			arr.fill(1)

		powerup_times.resize(power_count)
		powerup_times.fill(7.0)


const PLAYER_SCENE: PackedScene = preload("res://objects/player/player.tscn")
const POWERUP_SCENE: PackedScene = preload("res://objects/powerups/powerup.tscn")

@onready var _players_root: Node2D = $Players
@onready var _powerups_root: Node2D = $Powerups
@onready var _walls: Node2D = $Walls

var _arena_settings: Settings = null

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

func _set_process_mode(value): process_mode = value
var frozen: bool = false:
	set(value):
		if value: call_deferred("_set_process_mode", Node.PROCESS_MODE_DISABLED)
		else: call_deferred("_set_process_mode", Node.PROCESS_MODE_PAUSABLE)
		frozen = value

var _next_powerup_delay: float


func _ready() -> void:
	if not _arena_settings: _arena_settings = Settings.new()
	_connect_signals()
	_walls.set_size(arena_width, arena_height, border_width)

func _physics_process(delta: float) -> void:
	if _arena_settings.powerups_enabled and not frozen:
		_next_powerup_delay -= delta
		if _next_powerup_delay <= 0:
			_add_random_powerup()
			_new_powerup_delay()


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

func _add_random_powerup() -> void:
	const MARGIN = 32.0
	var rng = RandomNumberGenerator.new()
	# Pick random powerup and powerup type
	var power_id = rng.rand_weighted(PackedFloat32Array(_arena_settings.powerup_frequencies))
	if power_id == -1: return
	var power_type = rng.rand_weighted(PackedFloat32Array(_arena_settings.powerup_type_frequencies[power_id]))
	if power_type == -1: return

	var time: float = _arena_settings.powerup_times[power_id]
	var powerup = _create_powerup(power_id, power_type, time, _get_random_position(MARGIN, rng))
	_powerups_root.add_child(powerup)

## Add a powerup to the arena with given values
func _create_powerup(power_id, power_type, time: float, pos: Vector2 = Vector2.ZERO) -> Powerup:
	var powerup = POWERUP_SCENE.instantiate()
	powerup.power_id = power_id as Powerup.Power
	powerup.power_type = power_type as Powerup.Type
	powerup.time = time
	powerup.position = pos
	powerup.obtained.connect(_on_powerup_obtain, CONNECT_ONE_SHOT)
	return powerup

func _clear_players() -> void:
	for player in _players_root.get_children():
		player.queue_free()

func _clear_powerups() -> void:
	for powerup in _powerups_root.get_children():
		powerup.queue_free()

## Gets margin from walls and [RandomNumberGenerator],
## returns [Vector2] of random position in arena
func _get_random_position(margin: float, rng: RandomNumberGenerator) -> Vector2:
	var lr: float = max(arena_width/2.0 - margin, 0.0)
	var ud: float = max(arena_height/2.0 - margin, 0.0)
	return Vector2(rng.randf_range(-lr, lr), rng.randf_range(-ud, ud))

func _new_powerup_delay() -> void:
	var rng = RandomNumberGenerator.new()
	var delay = _arena_settings.powerup_delay
	_next_powerup_delay = clamp(rng.randfn(delay), delay - _arena_settings.delay_offset, delay + _arena_settings.delay_offset)

# Public function
# ===============

func new_game() -> void:
	#_clear_players()
	# TODO: create new players 
	return

func new_round() -> void:
	const MARGIN: float = 90.0
	var rng := RandomNumberGenerator.new()

	_clear_powerups()
	_new_powerup_delay()

	# For each player: return to default state and
	# give random position and rotation.
	for player in _players_root.get_children():
		if player is Player:
			player.set_default_values()
			player.delete_trail()
			player.head_position = _get_random_position(MARGIN, rng)
			player.head_angle = rng.randf_range(0, 2*PI)
	# freeze at start of round
	frozen = true

func toggle_freeze() -> void: frozen = not frozen

# Signal calls
# ============

func _on_player_crash(crasher_id: int, _obstacle_id: int, _is_player: bool):
	player_crashed.emit(crasher_id)

func _on_powerup_obtain(player_id: int, power_id, power_type, time: float):
	# Apply powerup on players according to type
	match power_type as Powerup.Type:
		Powerup.Type.ALL:
			for player in _players_root.get_children():
				if player is Player: player.apply_power(power_id, time)
		Powerup.Type.OTHERS:
			for player in _players_root.get_children():
				if player is Player and player.player_id != player_id:
					player.apply_power(power_id, time)
		Powerup.Type.SELF:
			for player in _players_root.get_children():
				if player is Player and player.player_id == player_id:
					player.apply_power(power_id, time)

