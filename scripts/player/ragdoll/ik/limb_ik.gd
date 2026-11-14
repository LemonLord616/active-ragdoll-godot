extends TwoBoneIK3D
class_name LimbIK

@export var lower_bone: PhysicalBone3D
@export var skeleton: AnimationSkeleton
@export var target: Marker3D
@export var pole: Marker3D

## Target and pole coordinates are relative to the animation pelvis.
func get_target_position() -> Vector3:
	return skeleton.get_bone_global_pose(skeleton.pelvis_bone).affine_inverse() * transform * target.position

func set_target_position(pelvis_position: Vector3) -> void:
	target.position = transform.affine_inverse() * skeleton.get_bone_global_pose(skeleton.pelvis_bone) * pelvis_position

func set_pole_position(pelvis_position: Vector3) -> void:
	pole.position = transform.affine_inverse() * skeleton.get_bone_global_pose(skeleton.pelvis_bone) * pelvis_position

func physical_transform() -> Transform3D:
	var physical: Skeleton3D = lower_bone.get_parent().get_parent()
	return lower_bone.global_transform * lower_bone.body_offset.affine_inverse() * physical.get_bone_pose(get_end_bone(0))
