@icon("res://addons/at-icons/animation/footsteps.svg")
extends LimboState


var player: FpsPlayer

func _setup() -> void:
	player = agent as FpsPlayer

func _enter() -> void:
	player.anim.play(&"Sprint", -1, player.run_speed / player.RUN_ANIM_SPEED)
	# player.anim.play(&"Sprint")

func _update(_delta: float) -> void:
	player.apply_input_vector(player.device.input_vector(), player.run_speed)
