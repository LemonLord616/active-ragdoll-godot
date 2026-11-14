extends Node
class_name PDIntegrator

@export var stiffness := 1600.0
@export var damping := 70.0
@export var max_torque := 2000.0
@export var bones_strengths: Dictionary[PhysicalBone3D, float] = {}

func integrate_rotation(bone: PhysicalBone3D, target: Quaternion, target_velocity: Vector3, delta: float) -> void:
	var current := (bone.global_transform * bone.body_offset.affine_inverse()).basis.orthonormalized().get_rotation_quaternion()
	var error := AnimationSkeleton.rotation_vector(target * current.inverse())
	var torque := stiffness * error + damping * (target_velocity - bone.angular_velocity)
	bone.angular_velocity += torque.limit_length(max_torque) * bones_strengths.get(bone, 1.0) * delta
