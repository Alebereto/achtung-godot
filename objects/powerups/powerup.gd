class_name Powerup extends Area2D

signal obtained(player_id: int, power_id: int)

func _ready() -> void:
	return

## Called by player that obtained power
func activate(player: Player) -> void:
	obtained.emit(player.player_id, 1)
	queue_free()
	
