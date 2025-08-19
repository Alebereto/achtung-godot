extends Node


# array of Player.Settings
var player_settings: Array = []

func clamp_angle(angle: float) -> float:
	if angle < 0: angle += 2.0*PI
	elif angle > 2.0*PI: angle -= 2.0*PI
	return angle
