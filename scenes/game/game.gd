extends Node2D

@export_range(1,10) var _player_count: int = 2

var _player_scores: Array[int] = []

var _round_ended: bool = false

@onready var _arena: Node2D = $Arena
@onready var _pause_menu: Control = $PauseMenu

func _ready() -> void:
	_pause_menu.resume.connect(_on_pmenu_resume)
	_pause_menu.quit.connect(_on_pmenu_quit)

	_arena.player_crashed.connect(_on_player_crashed)
	_arena.round_ended.connect(_on_round_ended)

	_new_game()

func _new_game() -> void:
	return

func _new_round() -> void:
	_arena.new_round()
	_round_ended = false

## Pause the game
func _pause() -> void:
	get_tree().paused = true
	_pause_menu.visible = true

## Resume the game
func _resume() -> void:
	_pause_menu.visible = false
	get_tree().paused = false

## Toggle between paused and unpaused state
func _toggle_pause() -> void:
	if get_tree().paused:
		_resume()
	else:
		_pause()

# Arena Events
# ============

func _on_player_crashed(crashed_id: int):
	return

func _on_round_ended(winner_id: int):
	_arena.frozen = true
	_round_ended = true

# Pause menu inputs
# =================

func _on_pmenu_resume() -> void:
	_resume()

func _on_pmenu_quit() -> void:
	# TODO quit
	return

# Inputs
# ======

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()

	elif event.is_action_pressed("freeze"):
		if not get_tree().paused:
			if _round_ended:
				_new_round()
			else:
				_arena.toggle_freeze()

