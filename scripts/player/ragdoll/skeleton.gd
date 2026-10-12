extends Skeleton3D
class_name RagdollSkeleton

@export var linear_spring_stiffness: float = 1200.0
@export var linear_spring_damping: float = 40.0
@export var max_linear_force: float = 9999.0

@export var angular_spring_stiffness: float = 4000.0
@export var angular_spring_damping: float = 80.0
@export var max_angular_force: float = 9999.0

@export var sim: PhysicalBoneSimulator3D
@export var root_bone: RagdollBone
@export var anim: Skeleton3D

var physics_bones: Array[RagdollBone]


func _ready():
	for child in sim.get_children():
		if child is RagdollBone:
			if child.get_bone_id() != root_bone.get_bone_id():
				physics_bones.append(child)
	sim.physical_bones_start_simulation()


func hookes_law(displacement: Vector3, current_velocity: Vector3, stiffness: float, damping: float) -> Vector3:
	return (stiffness * displacement) - (damping * current_velocity)



func _physics_process(delta):
	var root_current := global_transform * get_bone_global_pose(root_bone.get_bone_id())
	var root_target := anim.global_transform * anim.get_bone_global_pose(root_bone.get_bone_id())

	for bone in physics_bones:
		var target := anim.global_transform * anim.get_bone_global_pose(bone.get_bone_id())
		var target_rel := root_target.inverse() * target
		var current_rel := root_current.inverse() * (bone.global_transform * bone.joint_offset)

		var pos_err := target_rel.origin - current_rel.origin
		var rot_err: Basis = target_rel.basis * current_rel.basis.inverse()
		var pos_err_world := global_basis * pos_err
		var rot_err_world: Basis = global_basis * rot_err * global_basis.inverse()
		
		DebugDraw3D.draw_arrow(
			(global_transform * current_rel).origin, 
			(anim.global_transform * target_rel).origin,
		Color.GREEN, 0.01, true)
		
		if pos_err_world.length_squared() > 1.0:
			bone.global_position = root_target * target_rel.origin
		else:
			var force := hookes_law(pos_err_world, bone.linear_velocity, linear_spring_stiffness, linear_spring_damping)
			force = force.limit_length(max_linear_force)
			print(force)
			#DebugDraw3D.draw_arrow(
				#bone.global_position, 
				#bone.global_position + force,
			#Color.RED, 0.01, true)
			#bone.apply_force(force)
			bone.linear_velocity += force * delta
		
		var torque := hookes_law(rot_err_world.get_euler(), bone.angular_velocity, angular_spring_stiffness, angular_spring_damping)
		torque = torque.limit_length(max_angular_force)
		# bone.apply_torque(torque)
		bone.angular_velocity += torque * delta
		
		#var target := anim.global_transform * anim.get_bone_global_pose(bone.get_bone_id())
		#var current := global_transform * get_bone_global_pose(bone.get_bone_id())
		#set_bone_global_pose_override(
			#bone.get_bone_id(),
			#global_transform.affine_inverse() * target.interpolate_with(current, physics_interpolation),
			#1.0, true)


@export var debug_enabled: bool = true
@export var bone_color: Color = Color.CYAN

func _process(_delta: float) -> void:
	if not debug_enabled:
		return
	for bone_id in get_bone_count():
		var parent_id = get_bone_parent(bone_id)
		if parent_id == -1:
			_draw_bone_hierarchy(bone_id)

func _draw_bone_hierarchy(bone_id: int) -> void:
	var parent_global_pos = global_transform * get_bone_global_pose(bone_id).origin
	var children = get_bone_children(bone_id)
	
	for child_id in children:
		var child_global_pos = global_transform * get_bone_global_pose(child_id).origin
		DebugDraw3D.draw_line(parent_global_pos, child_global_pos, bone_color)
		_draw_bone_hierarchy(child_id)
