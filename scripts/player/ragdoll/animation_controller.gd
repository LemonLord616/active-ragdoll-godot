extends Node
class_name AnimationController

@export var player: Player
## Movement speed represented by each animation at its authored playback rate.
@export var reference_speeds: Dictionary[StringName, float] = {&"Walk": 1.5}

func set_speed(speed: float) -> void:
	var reference: float = reference_speeds.get(player.anim_player.assigned_animation, 1.0)
	player.anim_player.speed_scale = 1.0 if is_zero_approx(reference) else speed / reference
