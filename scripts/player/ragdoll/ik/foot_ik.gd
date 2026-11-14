extends LimbIK
class_name FootIK

@export_flags_3d_physics var ground_mask := 9
@export var ray_height := 0.35
@export var ray_depth := 0.5
@export var max_floor_adjustment := 0.08

func place_on_floor(physical_pelvis: Transform3D, up: Vector3) -> void:
	var foot := skeleton.get_bone_position(get_end_bone(0))
	var world_foot := physical_pelvis * foot
	var horizontal := (world_foot - physical_pelvis.origin).slide(up)
	var query := PhysicsRayQueryParameters3D.create(physical_pelvis.origin + horizontal + up * ray_height, world_foot - up * ray_depth, ground_mask)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	query.from -= horizontal
	query.to -= horizontal
	var base := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and not base.is_empty() and hit.normal.dot(up) > 0.5 and base.normal.dot(up) > 0.5:
		# Adapt to terrain height differences, not the physical pelvis sagging.
		var correction: float = (hit.position - base.position).dot(up)
		world_foot += up * clampf(correction, -max_floor_adjustment, max_floor_adjustment)
		foot = physical_pelvis.affine_inverse() * world_foot
	set_target_position(foot)
	var hip := skeleton.get_bone_position(get_root_bone(0))
	var knee := skeleton.get_bone_position(get_middle_bone(0))
	var axis := (skeleton.get_bone_position(get_end_bone(0)) - hip).normalized()
	var bend := (knee - hip).slide(axis)
	if bend.is_zero_approx():
		bend = Vector3.BACK.slide(axis)
	set_pole_position(knee + bend.normalized() * 0.5)
