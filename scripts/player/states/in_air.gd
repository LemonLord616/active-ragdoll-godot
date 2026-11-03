@icon("res://addons/at-icons/animation/wing.svg")
extends LimboState


var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	player.anim_player.play(&"Jump")

func _update(_delta: float) -> void:
	player.motor.set_input_vector(player.device.input_vector())
