@icon("res://addons/at-icons/animation/wing.svg")
extends LimboState


var player: FpsPlayer

func _setup() -> void:
	player = agent as FpsPlayer

func _enter() -> void:
	player.anim.play(&"Jump")
	var velocity = player.velocity
	player.bones.physical_bones_start_simulation()
	for bone in player.bones.get_children():
		if bone is PhysicalBone3D:
			bone.linear_velocity = velocity
