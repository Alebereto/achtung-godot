extends Node2D

@onready var _pause_menu: Control = $PauseMenu


func _ready() -> void:
	_pause_menu.resume.connect(_on_pmenu_resume)
	_pause_menu.quit.connect(_on_pmenu_quit)

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

## Handle inputs
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		_toggle_pause()

# Pause menu inputs =============

func _on_pmenu_resume() -> void:
	_resume()

func _on_pmenu_quit() -> void:
	# TODO quit
	return
