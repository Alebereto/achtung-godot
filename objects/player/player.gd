class_name Player extends Node2D

signal crashed(crasher_id: int, obstacle_id: int, is_player: bool)


# Player settings used for editor only
@export_group("Player Settings")
@export var _edit_id: int = 0
@export_color_no_alpha var _edit_trail_color: Color = Color.RED
@export_range(0.0, 1500.0) var _edit_default_speed: float = 148.0
@export_range(1.0, 1000.0) var _edit_default_width: float = 10.0
@export_range(0.0, 10.0) var _edit_default_turn: float = 2.9
@export var _edit_default_form: PlayerForms = PlayerForms.NORMAL
@export_group("")

class Settings:
	# hole length is width * hole_scale
	const HOLE_SCALE: float = 3.0

	# average time to create next hole
	var hole_delay: float = 3.0

	var name: String = "Player"
	var trail_color: Color = Color.RED
	var default_head_color: Color = Color.YELLOW
	var reverse_color: Color = Color.BLUE

	var default_speed: float = 148.0
	var default_width: float = 10.0
	var default_turn_sharpness: float = 2.5
	var default_player_from: PlayerForms = PlayerForms.NORMAL

	func _init() -> void:
		var rng = RandomNumberGenerator.new()
		trail_color = Color(rng.randf(), rng.randf(), rng.randf())

class Powers:
	const WIDE_SCALE: float = 1.4
	const THIN_SCALE: float = 1.0/WIDE_SCALE
	const FAST_SCALE: float = 1.4
	const SLOW_SCALE: float = 1.0/FAST_SCALE

	var counts: Array[int]

	func _init():
		var power_count: int = Powerup.Power.values().size()
		counts.resize(power_count)
		counts.fill(0)

	## Clear all player powers
	func clear():
		counts.fill(0)

	## Give player a power
	func add(power_id):
		counts[power_id] += 1
	
	## Remove power from player
	func remove(power_id):
		counts[power_id] = max(0, counts[power_id]-1)

enum PlayerForms {NORMAL, SQUARE}

@onready var _head_root: Node2D = $HeadRoot
@onready var _head: Area2D = $HeadRoot/Head
@onready var _head_sprite: Sprite2D = $HeadRoot/Head/HeadSprite
@onready var _trail_collisions: Area2D = null
@onready var _trail_lines_root: Node2D = $TrailRoot/Lines
@onready var _timers_root: Node = $TimersRoot

const CIRCLE_TEXTURE = preload("res://assets/sprites/player/circle.png")
const SQUARE_TEXTURE = preload("res://assets/sprites/player/square.png")

const SAFE_SELF_PERIOD = 0.2
# width of head sprite
const SPRITE_WIDTH = 32.0

# inputs
var _left_pressed: bool = false
var _right_pressed: bool = false


# Player info
# ===========
var player_id: int = 0
var player_settings: Settings = null

# time player has been alive
var _time_alive: float = 0
# timestamp where player should be invincible right after
var _grace_period_stamp: float = -100.0


# Player status
# =============

var _powers: Powers = null

# speed of player (pixels/s)
var _speed: float
# width of player (in pixels)
var _width: float
# how fast the player turns (radians/s)
var _turn_sharpness: float

# current form of the player
var _current_form: PlayerForms = PlayerForms.NORMAL
# true if player is alive
var _alive: bool = true
# true if player leaves a trail
var _leaves_trail: bool = true
# true if player cannot move
var _frozen: bool = false

# current position of the head
var head_position: Vector2:
	get:
		return _head_root.position
	set(value):
		_head_root.position = value
# current angle of the head
var head_angle: float:
	get:
		return _head.rotation
	set(value):
		_head.rotation = value

# Variables used for trails
# =========================
var _current_line: Line2D = null
var _next_hole_delay: float = 100.0
var _current_hole_length: float = 0


func _ready() -> void:
	_powers = Powers.new()
	_reset_trail_root()
	_head.set_meta("id", player_id)
	_head.area_shape_entered.connect(_on_collision)

	if not player_settings:
		player_settings = Settings.new()
		player_settings.trail_color = _edit_trail_color
		player_settings.default_speed = _edit_default_speed
		player_settings.default_width = _edit_default_width
		player_settings.default_turn_sharpness = _edit_default_turn
		player_settings.default_player_from = _edit_default_form
		player_id = _edit_id
		# TODO: add editor values for funzies

	set_default_values()

func _process(delta: float) -> void:
	if _alive:
		_time_alive += delta
		_get_inputs()
		if not _frozen:
			var movement_vec = _move(delta)
			if _leaves_trail: _leave_trail(delta, movement_vec)

func _crash(other_id: int, is_head: bool) -> void:
	die()
	crashed.emit(player_id, other_id, is_head)

func _reset_trail_root() -> void:
	if _trail_collisions: _trail_collisions.queue_free()
	if _trail_lines_root: _trail_lines_root.queue_free()
	# Collisions
	_trail_collisions = Area2D.new()
	_trail_collisions.name = "TrailCollisions"
	_trail_collisions.collision_mask = 0
	_trail_collisions.collision_layer = 3
	_trail_collisions.monitoring = false
	_trail_collisions.input_pickable = false
	_trail_collisions.set_meta("id", player_id)
	$TrailRoot.add_child(_trail_collisions)
	# Lines
	_trail_lines_root.queue_free()
	_trail_lines_root = Node2D.new()
	_trail_lines_root.name = "TrailRoot"
	_trail_lines_root.z_index = -1
	$TrailRoot.add_child(_trail_lines_root)


## Moves player according to delta time,
## returns Vector2 of the movement relative to previous position
func _move(delta: float) -> Vector2:
	# If normal mode then turn
	if _current_form == PlayerForms.NORMAL:
		# Get current turning direction from input
		var turn_direction = (-1 if _left_pressed else 0) + (1 if _right_pressed else 0)
		if _is_reversed(): turn_direction *= -1
		# turn head
		_turn_head(turn_direction, delta)

	# Move forward
	var movement_vector: Vector2 = Vector2.from_angle(head_angle) * _speed * delta
	head_position += movement_vector
	return movement_vector


func _turn_head(turn_direction: int, delta: float) -> void:
	# Set new angle
	head_angle = Globals.clamp_angle(head_angle + turn_direction * _turn_sharpness * delta)

## Turn head by 90 degrees to given directoin
func _turn_head_sharp(turn_direction: int) -> void:
	head_angle = Globals.clamp_angle(head_angle + 0.5*PI * turn_direction)
	_start_line(true)

## Start a new visual trail.
## if `update = true` just update current line.
func _start_line(update: bool = false) -> void:
	if not _current_line and update: return

	var newline := Line2D.new()
	newline.default_color = player_settings.trail_color
	newline.add_point(head_position + _get_point_offset())
	newline.width = _width

	_current_line = newline
	_trail_lines_root.add_child(_current_line)

# Sets a new delay for next hole
func _new_hole_delay() -> void:
	var rng = RandomNumberGenerator.new()
	_next_hole_delay = rng.randfn(player_settings.hole_delay)
	_current_hole_length = 0.0

## Updates line after movement
func _leave_trail(delta: float, movement_vec: Vector2) -> void:
	var dis = movement_vec.length()

	# update hole progress
	var during_hole: bool = false
	_next_hole_delay -= delta
	# if during hole
	if _next_hole_delay <= 0:
		during_hole = true
		_current_hole_length += dis
		# if hole should end
		if _current_hole_length >= max(_width * player_settings.HOLE_SCALE,
			player_settings.default_width * player_settings.HOLE_SCALE):
			_new_hole_delay()
			during_hole = false
	
	# place trail if not during a hole
	if not during_hole:
		if _current_line:
			var point_offset: Vector2 = _get_point_offset()
			# Add point to current line
			_current_line.add_point(head_position + point_offset)

			# create collision segment
			var rectangle_shape = RectangleShape2D.new()
			rectangle_shape.size = Vector2(dis, _width)
			var collision_segment = CollisionShape2D.new()
			collision_segment.shape = rectangle_shape
			collision_segment.rotation = head_angle
			collision_segment.position = head_position - (movement_vec/2.0) + point_offset
			collision_segment.set_meta("time", _time_alive) # record current time

			# add collision segment to segment root
			_trail_collisions.add_child(collision_segment)
		else:
			_start_line()
	else:
		_current_line = null

func _is_during_hole() -> bool:
	return _next_hole_delay <= 0

func _is_invincible() -> bool:
	return _powers.counts[Powerup.Power.INVINCIBLE] > 0

func _is_reversed() -> bool:
	return _powers.counts[Powerup.Power.REVERSE] > 0

## Get offset of where line points should be added from head position
func _get_point_offset() -> Vector2:
	var point_offset: Vector2
	match _current_form:
		PlayerForms.SQUARE:
			point_offset = -(Vector2.from_angle(head_angle) * (_width/2.0))
		_:
			point_offset = Vector2.ZERO
	return point_offset


func _trail_on() -> void:
	_new_hole_delay()
	_leaves_trail = true

func _trail_off() -> void:
	_leaves_trail = false
	_current_line = null

func _update_grace_stamp() -> void:
	_grace_period_stamp = _time_alive

# Powerups ======

func _add_power_timed(power_id, time: float):
	_powers.add(power_id)
	# create timer to remove power later
	var timer = Timer.new()
	timer.wait_time = time
	timer.one_shot = true
	timer.autostart = true
	timer.timeout.connect(func(): _on_timer_timeout(power_id, timer), CONNECT_ONE_SHOT)
	# add timer to tree
	_timers_root.add_child(timer)

func _on_timer_timeout(power_id, timer: Timer):
	_powers.remove(power_id)
	_update_power_effects()
	timer.queue_free()

## Called when updating or removing powers
func _update_power_effects() -> void:
	# update width
	set_width(player_settings.default_width * 
	pow(_powers.WIDE_SCALE, _powers.counts[Powerup.Power.WIDE]) *
	pow(_powers.THIN_SCALE, _powers.counts[Powerup.Power.THIN]))

	# update speed
	set_speed(player_settings.default_speed * 
	pow(_powers.FAST_SCALE, _powers.counts[Powerup.Power.FAST]) *
	pow(_powers.SLOW_SCALE, _powers.counts[Powerup.Power.SLOW]))

	# Square start or end
	if _powers.counts[Powerup.Power.SQUARE] > 0 and _current_form != PlayerForms.SQUARE:
		set_form(PlayerForms.SQUARE)
	if _powers.counts[Powerup.Power.SQUARE] == 0 and _current_form != PlayerForms.NORMAL:
		set_form(PlayerForms.NORMAL)

	# Invincible start or end
	if _is_invincible() and _leaves_trail:
		_trail_off()
	if not _is_invincible() and not _leaves_trail:
		_trail_on()
	
	# set head color
	if _is_reversed():
		_head_sprite.modulate = player_settings.reverse_color
	else:
		_head_sprite.modulate = player_settings.default_head_color
	

# Public functions
# ================

## Return player to default state
func set_default_values() -> void:
	_powers.clear()
	for child in _timers_root.get_children(): child.queue_free()
	_alive = true
	_frozen = false
	_time_alive = 0.0
	_grace_period_stamp = -100.0
	_head_sprite.modulate = player_settings.default_head_color
	set_width(player_settings.default_width)
	_speed = player_settings.default_speed
	_turn_sharpness = player_settings.default_turn_sharpness
	set_form(player_settings.default_player_from)
	_new_hole_delay()
	_trail_on()

func apply_power(power_id, time: float = -1) -> void:
	match power_id as Powerup.Power:
		Powerup.Power.CLEAR_TRAIL:
			delete_trail()
		_:
			if (time < 0): _powers.add(power_id)
			else: _add_power_timed(power_id, time)
			_update_power_effects()

## Deletes all of the player's trail
func delete_trail() -> void:
	_current_line = null
	_reset_trail_root()

## Kills player
func die() -> void:
	_alive = false

## Sets player's width
func set_width(w: float, grace: bool = false) -> void:
	_width = w
	_start_line(true) # update current line
	if grace: _update_grace_stamp()
	var head_scale = _width / SPRITE_WIDTH
	_head.scale = Vector2(head_scale, head_scale)

## Sets player's speed
func set_speed(s: float) -> void:
	_speed = s

func set_form(player_form: PlayerForms) -> void:
	_current_form = player_form
	# Disable all collision shapes
	_head.find_child("Circle").set_deferred("disabled", true)
	_head.find_child("Square").set_deferred("disabled", true)
	# update grace period when collision shape changes
	_update_grace_stamp()

	# Turn on new form collision and change sprite
	match player_form:
		PlayerForms.NORMAL:
			_head_sprite.texture = CIRCLE_TEXTURE
			_head.find_child("Circle").set_deferred("disabled", false)
		PlayerForms.SQUARE:
			_head_sprite.texture = SQUARE_TEXTURE
			_head.find_child("Square").set_deferred("disabled", false)
	# update line after change form
	_start_line(true)

func is_alive() -> bool: return _alive

# Signal calls
# ============

## Gets called when player head enters the given [Area2D].
func _on_collision(_area_RID, area: Area2D, area_shape_index: int, _lsi) -> void:
	if not _alive: return

	# If touched powerup
	if area is Powerup:
		area.activate(self)
	# check if player should die
	elif not (_is_invincible() or _is_during_hole()):
		# if is a player or a trail
		if area.has_meta("id"):
			var other_id: int = area.get_meta("id")
			var other_shape: CollisionShape2D = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index))
			var crashed_on_trail: bool = other_shape.has_meta("time")
			# check if collision should kill
			if not (other_id == player_id and crashed_on_trail and (
				(_time_alive - other_shape.get_meta("time") <= SAFE_SELF_PERIOD) or
				(_time_alive - _grace_period_stamp <= SAFE_SELF_PERIOD))):
				_crash(other_id, not crashed_on_trail)
		else:
			_crash(-1, false)

# Player inputs
# =============

## Read current inputs
func _get_inputs() -> void:
	_left_pressed = Input.is_action_pressed("p%d_left" %(player_id+1))
	_right_pressed = Input.is_action_pressed("p%d_right" %(player_id+1))

## Handle inputs
func _unhandled_input(event: InputEvent) -> void:
	if not _alive: return

	if _current_form == PlayerForms.SQUARE:
		var turn_direction = 0
		if event.is_action_pressed("p%d_left" %(player_id+1), false): turn_direction = -1
		elif event.is_action_pressed("p%d_right" %(player_id+1), false): turn_direction = 1
		else: return

		if _is_reversed(): turn_direction *= -1
		_turn_head_sharp(turn_direction)
