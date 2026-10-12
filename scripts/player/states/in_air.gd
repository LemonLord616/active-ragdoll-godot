@icon("res://addons/at-icons/animation/wing.svg")
extends LimboState


var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	player.anim.play(&"Jump")
