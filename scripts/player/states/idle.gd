@icon("res://addons/at-icons/animation/person_body.svg")
extends LimboState


var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	player.anim_player.play(&"Idle")
