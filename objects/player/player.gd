class_name Player extends Node2D

signal crashed(crasher_id: int, obstacle_id: int, is_player: bool)


# Player settings used for editor only
@export_group("Player Settings")
@export_color_no_alpha var _edit_trail_color: Color = Color.RED
@export_range(0.0, 5000.0) var _edit_default_speed: float = 1500.0
@export_range(1.0, 1000.0) var _edit_default_width: float = 256.0
@export_range(0.0, 10.0) var _edit_default_turn: float = 2.5
@export var _edit_default_form: PLAYER_FORMS = PLAYER_FORMS.NORMAL
@export_group("")

class Settings:
	const HOLE_DELAY := 3.5
	const HOLE_LENGTH := 500.0

	var name: String = "P"
	var trail_color: Color = Color.RED
	var default_head_color: Color = Color.YELLOW
	var reverse_color: Color = Color.BLUE

	var default_speed: float = 1000.0
	var default_width: float = 256.0
	var default_turn_sharpness: float = 2.0
	var default_player_from: PLAYER_FORMS = PLAYER_FORMS.NORMAL

enum PLAYER_FORMS{NORMAL, SQUARE}

@onready var _head_root: Node2D = $HeadRoot
@onready var _head: Area2D = $HeadRoot/Head
@onready var _head_sprite: Sprite2D = $HeadRoot/Head/HeadSprite
@onready var _trail_collisions: Area2D = $TrailRoot/TrailCollisions
@onready var _trail_lines_root: Node2D = $TrailRoot/Lines

const CIRCLE_TEXTURE = preload("res://assets/sprites/player/circle.png")
const SQUARE_TEXTURE = preload("res://assets/sprites/player/square.png")

const SAFE_SELF_PERIOD = 0.1
const SPRITE_WIDTH = 256.0

# inputs
var _left_pressed: bool = false
var _right_pressed: bool = false


# Player info
# ===========
@export var player_id: int = 1
var player_settings: Settings = null

# time player has been alive
var _time_alive: float = 0
# timestamp where player should be invincible right after
var _grace_period_stamp: float = -100.0


# Player status
# =============

# speed of player (pixels/s)
var _speed: float
# width of player (in pixels)
var _width: float
# how fast the player turns (radians/s)
var _turn_sharpness: float

# current form of the player
var _current_form: PLAYER_FORMS = PLAYER_FORMS.NORMAL
# true if player is alive
var _alive: bool = true
# true if player leaves a trail
var _leaves_trail: bool = true
# true if controls are reversed
var _reversed: bool = false
# true if player is invincible
var _invincible: bool = false
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
	_trail_collisions.set_meta("id", player_id)
	_head.set_meta("id", player_id)
	_head.area_shape_entered.connect(_on_collision)

	if not player_settings:
		player_settings = Settings.new()
		player_settings.trail_color = _edit_trail_color
		player_settings.default_speed = _edit_default_speed
		player_settings.default_width = _edit_default_width
		player_settings.default_turn_sharpness = _edit_default_turn
		player_settings.default_player_from = _edit_default_form
		# TODO: add editor values for funzies

	set_default_values()

func _process(delta: float) -> void:
	if _alive:
		_time_alive += delta
		_get_inputs()
		if not _frozen:
			var movement_vec = _move(delta)
			if _leaves_trail: _leave_trail(delta, movement_vec)



## Moves player according to delta time,
## returns Vector2 of the movement relative to previous position
func _move(delta: float) -> Vector2:
	# If normal mode then turn
	if _current_form == PLAYER_FORMS.NORMAL:
		# Get current turning direction from input
		var turn_direction = (-1 if _left_pressed else 0) + (1 if _right_pressed else 0)
		if _reversed: turn_direction *= -1
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
	#TODO: make delay random
	_next_hole_delay = player_settings.HOLE_DELAY
	_current_hole_length = 0.0

## Updates line after movement
func _leave_trail(delta: float, movement_vec: Vector2) -> void:
	var dis = movement_vec.length()

	# update hole progress
	var during_hole: bool = false
	_next_hole_delay -= delta
	if _next_hole_delay <= 0:
		during_hole = true
		_current_hole_length += dis
		if _current_hole_length >= player_settings.HOLE_LENGTH:
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

## Get offset of where line points should be added from head position
func _get_point_offset() -> Vector2:
	var point_offset: Vector2
	match _current_form:
		PLAYER_FORMS.SQUARE:
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


# Public functions
# ================

## Return player to default state
func set_default_values() -> void:
	_time_alive = 0.0
	_grace_period_stamp = -100.0

	set_width(player_settings.default_width)
	_speed = player_settings.default_speed
	_turn_sharpness = player_settings.default_turn_sharpness
	_alive = true
	_frozen = false
	_reversed = false
	_invincible = false
	set_form(player_settings.default_player_from)
	_new_hole_delay()
	_trail_on()

## Deletes all of the player's trail
func delete_trail() -> void:
	_current_line = null
	_start_line(true)
	#TODO: correctly (if currently placing trail, start new line)
	for collision in _trail_collisions:
		collision.queue_free()
	for line in _trail_lines_root:
		line.queue_free()

## Kills player
func die() -> void:
	_alive = false

## Sets player's width
func set_width(w: float, grace: bool = false) -> void:
	_width = w
	_start_line(true) # update current line
	if grace: _grace_period_stamp = _time_alive
	#TODO: scale head

## Sets player's speed
func set_speed(s: float) -> void:
	_speed = s

func set_form(player_form: PLAYER_FORMS) -> void:
	_current_form = player_form
	# Disable all collision shapes
	_head.find_child("Circle").set_deferred("disabled", true)
	_head.find_child("Square").set_deferred("disabled", true)
	# Turn on new form collision and change sprite
	match player_form:
		PLAYER_FORMS.NORMAL:
			_head_sprite.texture = CIRCLE_TEXTURE
			_head.find_child("Circle").set_deferred("disabled", false)
		PLAYER_FORMS.SQUARE:
			_head_sprite.texture = SQUARE_TEXTURE
			_head.find_child("Square").set_deferred("disabled", false)
	# update line after change form
	_start_line(true)

# Signal calls
# ============

## Gets called when player head enters the given [Area2D].
func _on_collision(_area_RID, area: Area2D, area_shape_index: int, _lsi) -> void:
	if not _alive: return

	# If touched powerup
	if area is Powerup:
		area.activate(self)
	# check if player should die
	elif not (_invincible or _is_during_hole()):
		# if is a player or a trail
		if area.has_meta("id"):
			var other_id: int = area.get_meta("id")
			var other_shape: CollisionShape2D = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index))
			var crashed_on_trail: bool = other_shape.has_meta("time")
			# if crash should not kill
			if (other_id == player_id and crashed_on_trail and (
				(_time_alive - other_shape.get_meta("time") < SAFE_SELF_PERIOD) or
				(_time_alive - _grace_period_stamp < SAFE_SELF_PERIOD))):
				return
			die()
			crashed.emit(player_id, other_id, not crashed_on_trail)
		else:
			die()
			crashed.emit(player_id, -1, false)

# Player inputs
# =============

## Read current inputs
func _get_inputs() -> void:
	_left_pressed = Input.is_action_pressed("p%d_left" %player_id)
	_right_pressed = Input.is_action_pressed("p%d_right" %player_id)

## Handle inputs
func _unhandled_input(event: InputEvent) -> void:
	if not _alive: return

	if _current_form == PLAYER_FORMS.SQUARE:
		var turn_direction = 0
		if event.is_action_pressed("p%d_left" %player_id, false): turn_direction = -1
		elif event.is_action_pressed("p%d_right" %player_id, false): turn_direction = 1
		else: return

		if _reversed: turn_direction *= -1
		_turn_head_sharp(turn_direction)
