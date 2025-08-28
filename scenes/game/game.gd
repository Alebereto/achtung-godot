extends Node2D

@export_range(1,10) var _player_count: int = 2
@export var _winning_score: int = 10

var _player_scores: Array[int] = []
var _alive: Array[bool] = []

var _round_ended: bool = false
var _game_ended: bool = false

@onready var _arena: Node2D = $Arena
@onready var _pause_menu: Control = $PauseMenu

func _ready() -> void:
	_pause_menu.resume.connect(_on_pmenu_resume)
	_pause_menu.quit.connect(_on_pmenu_quit)

	_arena.player_crashed.connect(_on_player_crashed)

	_new_game()

func _new_game() -> void:
	_game_ended = false
	_player_scores.resize(_player_count)
	_alive.resize(_player_count)

	_player_scores.fill(0)
	_arena.new_game()
	_new_round()

func _new_round() -> void:
	_alive.fill(true)

	_arena.new_round()
	_round_ended = false

func _on_round_end() -> void:
	_arena.frozen = true
	_round_ended = true

	# Check if there is a winner
	var max_score: int = -1
	var max_id: int = -1
	for i in range(_player_count):
		if _player_scores[i] >= max_score:
			max_score = _player_scores[i]
			max_id = i
	if max_score >= _winning_score and _player_scores.count(max_score) == 1:
		_on_game_over(max_id)

func _on_game_over(winner_id: int) -> void:
	_game_ended = true
	print("winner is player " + str(winner_id+1) + "!!")

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
	print("player " + str(crashed_id+1) + " crashed!!!")

	_alive[crashed_id] = false
	# Add a point to players that are alive
	for i in range(_player_count): if _alive[i]: _player_scores[i] += 1
	if _alive.count(true) <= 1: _on_round_end()

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
	if event.is_action_pressed("pause"): _pause_button()
	elif event.is_action_pressed("freeze"): _freeze_button()

func _pause_button() -> void:
	_toggle_pause()

func _freeze_button() -> void:
	if not get_tree().paused:
		if _game_ended: _new_game()

		elif _round_ended: _new_round()

		else: _arena.toggle_freeze()
