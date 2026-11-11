@icon("res://addons/at-icons/animation/footsteps.svg")
extends LimboState


var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	player.anim_player.play(&"Walk")
	player.motor.speed = player.motor.walk_speed

func _update(delta: float) -> void:
	player.motor.move(player.device.input_vector(), delta)
