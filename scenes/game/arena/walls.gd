@tool
extends Node2D

@export var width: float = 1400.0:
	set(value):
		width = value
		if Engine.is_editor_hint(): _update_sizes()
@export var height: float = 1400.0:
	set(value):
		height = value
		if Engine.is_editor_hint(): _update_sizes()
@export var wall_width: float = 10.0:
	set(value):
		wall_width = value
		if Engine.is_editor_hint(): _update_sizes()

@onready var _line: Line2D = $Line2D
@onready var _left: Area2D = $Left
@onready var _up: Area2D = $Up
@onready var _right: Area2D = $Right
@onready var _down: Area2D = $Down

func _ready() -> void:
	_update_sizes()

func _update_sizes() -> void:
	_line.clear_points()
	_line.width = wall_width
	var lr := (width/2.0) + (wall_width/2.0)
	var ud := (height/2.0) + (wall_width/2.0)
	_line.add_point(Vector2(-lr, ud))
	_line.add_point(Vector2(-lr, -ud))
	_line.add_point(Vector2(lr, -ud))
	_line.add_point(Vector2(lr, ud))
	
	_left.position = Vector2(-width/2.0, 0.0)
	_up.position = Vector2(0.0, -height/2.0)
	_right.position = Vector2(width/2.0, 0.0)
	_down.position = Vector2(0.0, height/2.0)


func set_size(arena_width, arena_height, border_width) -> void:
	width = arena_width
	height = arena_height
	wall_width = border_width
	_update_sizes()

