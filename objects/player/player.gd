class_name Player extends Node2D

signal crashed

@onready var _head_root: Node2D = $HeadRoot
@onready var _head: Area2D = $HeadRoot/Head
@onready var _trail_collisions: Area2D = $TrailRoot/TrailCollisions
@onready var _trail_lines_root: Node2D = $TrailRoot/Lines

# inputs
var _left_pressed: bool = false
var _right_pressed: bool = false

# Player info
@export var _player_id: int = 1
@export var trail_color: Color = Color.RED

var _body_color: Color = Color.YELLOW

var _time_alive: float = 0
var _grace_period_stamp: float = -100.0

# Player status
# =============

# true if player is alive
var _alive: bool = true
# true if player leaves a trail
var _leaves_trail: bool = true
# speed of player
@export var _speed: float = 40.0
# width of player
@export var _width: float = 256
# how fast the player turns
@export_range(0.1, 10.0) var _turn_sharpness: float = 2.0
# true if controls are reversed
var _reversed: bool = false
# true if player is invincible
var _invincible: bool = false

# current position of the head
var _head_position: Vector2:
	get:
		return _head_root.position
	set(value):
		_head_root.position = value
# current angle of the head
var _head_angle: float:
	get:
		return _head.rotation
	set(value):
		_head.rotation = value
@export var _current_form: Globals.PLAYER_FORMS = Globals.PLAYER_FORMS.NORMAL

# Variables used for trails
# =========================
const HOLE_DELAY := 4.0
const HOLE_LENGTH := 300.0
var _current_line: Line2D = null
var _next_hole_delay: float = 0
var _current_hole_length: float = 0


func _ready() -> void:
	_head.area_shape_entered.connect(_on_crash)

func _process(delta: float) -> void:
	if _alive:
		_time_alive += delta
		_get_inputs()
		var movement_vec = _move(delta)
		_draw_line(delta, movement_vec)

# func _physics_process(_delta: float) -> void:
# 	return

## Moves player according to delta time,
## returns Vector2 of the movement relative to previous position
func _move(delta: float) -> Vector2:
	# If normal mode then turn
	if _current_form == Globals.PLAYER_FORMS.NORMAL:
		# Get current turning direction from input
		var turn_direction = (-1 if _left_pressed else 0) + (1 if _right_pressed else 0)
		if _reversed: turn_direction *= -1
		# turn head
		_turn_head(turn_direction, delta)

	# Move forward
	var movement_vector: Vector2 = Vector2.from_angle(_head_angle) * _speed
	_head_position += movement_vector
	return movement_vector


func _turn_head(turn_direction: int, delta: float) -> void:
	# Set new angle
	_head_angle = Globals.clamp_angle(_head_angle + turn_direction * _turn_sharpness * delta)

## Turn head by 90 degrees to given directoin
func _turn_head_sharp(turn_direction: int) -> void:
	_head_angle = Globals.clamp_angle(_head_angle + 0.5*PI * turn_direction)


## Draws line after movement
func _draw_line(_delta: float, movement_vec: Vector2) -> void:
	var dis = movement_vec.length()
	if _leaves_trail:
		if _current_line:
			# Add point to current line
			_current_line.add_point(_head_position)
			# Add collision segment
			var rectangle_shape = RectangleShape2D.new()
			rectangle_shape.size = Vector2(dis, _width)
			var collision_segment = CollisionShape2D.new()
			collision_segment.shape = rectangle_shape
			collision_segment.position = _head_position - (movement_vec/2.0)
			collision_segment.rotation = _head_angle
			# record current time
			collision_segment.set_meta("time", _time_alive)

			_trail_collisions.add_child(collision_segment)
		else:
			_start_line(_width)

func _start_line(width: float) -> void:
	var newline := Line2D.new()
	newline.default_color = trail_color
	newline.add_point(_head_position)
	newline.width = width

	_current_line = newline
	_trail_lines_root.add_child(_current_line)


## Gets called when player head enters the given [Area2D].
func _on_crash(_area_RID, area: Area2D, area_shape_index: int, _lsi) -> void:
	if not _invincible:
		var other_shape: CollisionShape2D = area.shape_owner_get_owner(area.shape_find_owner(area_shape_index))
		# TODO: check if is a trail and is own trial
		if _time_alive - other_shape.get_meta("time") > 0.1:
			_alive = false
			crashed.emit()


## Read current inputs
func _get_inputs() -> void:
	_left_pressed = Input.is_action_pressed("p%d_left" %_player_id)
	_right_pressed = Input.is_action_pressed("p%d_right" %_player_id)

## Handle inputs
func _unhandled_input(event: InputEvent) -> void:
	if _current_form == Globals.PLAYER_FORMS.SQUARE:
		var turn_direction = 0
		if event.is_action_pressed("p%d_left" %_player_id, false): turn_direction = -1
		elif event.is_action_pressed("p%d_right" %_player_id, false): turn_direction = 1
		else: return

		if _reversed: turn_direction *= -1
		_turn_head_sharp(turn_direction)
