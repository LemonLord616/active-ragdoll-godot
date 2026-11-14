extends Node
class_name BodyBalance

@export var player: Player

func apply(delta: float) -> void:
	var rotation := player.anim_skeleton.global_basis.get_rotation_quaternion()
	player.pd_integrator.integrate_rotation(player.ragdoll.pelvis, rotation, Vector3.ZERO, delta)
