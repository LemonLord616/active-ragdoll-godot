@icon("res://addons/at-icons/animation/person_body.svg")
extends LimboState


var player: FpsPlayer

func _setup() -> void:
	player = agent as FpsPlayer

func _enter() -> void:
	player.anim.play(&"Idle")
	player.velocity = Vector3.ZERO
