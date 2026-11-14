extends Skeleton3D
class_name Ragdoll

@export var pelvis: PhysicalBone3D
@onready var simulator: PhysicalBoneSimulator3D = $PhysicalBoneSimulator3D
var bones: Array[PhysicalBone3D] = []

func _ready() -> void:
	for child in simulator.get_children():
		if child is PhysicalBone3D:
			bones.append(child)
			PhysicsServer3D.body_set_enable_continuous_collision_detection(child.get_rid(), true)
			PhysicsServer3D.body_set_max_contacts_reported(child.get_rid(), 8)
	simulator.physical_bones_start_simulation()

func get_bone_gravity(bone: PhysicalBone3D) -> Vector3:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")
	var direction: Vector3 = ProjectSettings.get_setting("physics/3d/default_gravity_vector")
	return direction * gravity * bone.gravity_scale

func get_up_direction() -> Vector3:
	var gravity := get_bone_gravity(pelvis)
	return -gravity.normalized() if not gravity.is_zero_approx() else global_basis.y

func get_pelvis_transform() -> Transform3D:
	return pelvis.global_transform * pelvis.body_offset.affine_inverse()
