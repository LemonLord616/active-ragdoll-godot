@icon("res://addons/at-icons/animation/footsteps.svg")
extends LimboState


var player: FpsPlayer

func _setup() -> void:
	player = agent as FpsPlayer

func _enter() -> void:
	player.anim.play(&"Walk", -1, player.walk_speed / player.WALK_ANIM_SPEED)

func _update(_delta: float) -> void:
	player.apply_input_vector(player.device.input_vector(), player.walk_speed)
