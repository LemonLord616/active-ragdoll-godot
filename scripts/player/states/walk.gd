@icon("res://addons/at-icons/animation/footsteps.svg")
extends LimboState


var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	# player.anim.play(&"Walk", -1, player.walk_speed / player.WALK_ANIM_SPEED)
	pass

func _update(_delta: float) -> void:
	player.apply_input_vector(player.device.input_vector(), player.walk_speed)
	player.anim.play(&"Walk", -1,
		player.ragdoll.root_bone.linear_velocity.length() / player.WALK_ANIM_SPEED)
