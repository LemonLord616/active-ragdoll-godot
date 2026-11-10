@icon("res://addons/at-icons/animation/footsteps.svg")
extends LimboState


var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	player.anim_player.play(&"Walk")
	player.motor.speed = player.run_speed

func _update(_delta: float) -> void:
	player.motor.set_input_vector(player.device.input_vector())
