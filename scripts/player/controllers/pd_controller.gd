extends Node
class_name PDController 

@export_range(0.0, 5000.0, 10.0) var linear_stiffness := 2200.0
@export_range(0.0, 100.0, 1.0) var linear_damping := 40.0
@export var max_linear_force := 9999.0

@export_range(0.0, 5000.0, 10.0) var angular_stiffness: float = 4000.0
@export_range(0.0, 100.0, 1.0) var angular_damping: float = 80.0
@export var max_angular_force := 9999.0

@export var player: Player

@export_group("PD Debug")
@export var debug_enabled := true
@export var debug_duration := 0.05
@export var error_draw_scale := 1.0
@export var force_draw_scale := 0.002
@export var min_arrow_length := 0.05

@onready var target := player.target_skeleton
@onready var sim := player.bone_sim

var physics_bones: Array[PhysicalBone3D]


func _ready():
	for child in sim.get_children():
		if child is PhysicalBone3D:
			physics_bones.append(child)
	sim.physical_bones_start_simulation()

func pd_linear(Tt: Transform3D, Tc: Transform3D, vt: Vector3, vc: Vector3) -> Vector3:
	var pos_error := Tt.origin - Tc.origin
	
	var vel_error := vt - vc
	
	var force := (
		linear_stiffness * pos_error
		+ linear_damping * vel_error
	)
	force = force.limit_length(max_linear_force)

	return force

func pd_angular(Tt: Transform3D, Tc: Transform3D, wt: Vector3, wc: Vector3) -> Vector3:
	var q_target := Quaternion(
		Tt.basis.orthonormalized()
	)
	var q_current := Quaternion(
		Tc.basis.orthonormalized()
	)
	
	var q_error := (
		q_target * q_current.inverse()
	).normalized()
	
	if q_error.w < 0.0:
		q_error = -q_error
	
	var rot_error := (
		q_error.get_axis() * q_error.get_angle()
	)

	var vel_error := wt - wc
	
	var torque := (
		angular_stiffness * rot_error
		+ angular_damping * vel_error 
	)
	
	torque = torque.limit_length(max_angular_force)
	return torque


func _physics_process(delta: float) -> void:
	for bone in physics_bones:
		var id := bone.get_bone_id()
	
		var joint_transform := (
			target.global_transform
			* target.get_bone_global_pose(id)
		)
		var target_transform := joint_transform * bone.body_offset
		var current_transform := bone.global_transform

		var r := target_transform.origin - joint_transform.origin

		var joint_linear_velocity := target.get_bone_linear_velocity(id)
		var target_angular_velocity := target.get_bone_angular_velocity(id)

		var target_linear_velocity := joint_linear_velocity + target_angular_velocity.cross(r)

		var current_linear_velocity := bone.linear_velocity
		var current_angular_velocity := bone.angular_velocity

		var force := pd_linear(
			target_transform, current_transform, 
			target_linear_velocity, current_linear_velocity
		)
		var torque := pd_angular(
			target_transform, current_transform,
			target_angular_velocity, current_angular_velocity
		)

		debug_bone(target_transform, current_transform, force, torque)

		bone.linear_velocity += force / bone.mass * delta
		bone.angular_velocity += torque / bone.mass * delta

func debug_bone(
	target_transform: Transform3D,
	current_transform: Transform3D,
	force: Vector3,
	torque: Vector3
) -> void:
	if not debug_enabled:
		return

	var current_pos := current_transform.origin
	var target_pos := target_transform.origin

	# Position error.
	var pos_error := target_pos - current_pos

	if pos_error.length() > min_arrow_length:
		DebugDraw3D.draw_arrow(
			current_pos,
			current_pos + pos_error * error_draw_scale,
			Color.GREEN,
			debug_duration
		)

	var force_strength := clampf(
		force.length() / maxf(max_linear_force, 0.001),
		0.0,
		1.0
	)
	
	if force.length() > 0.001:
		DebugDraw3D.draw_arrow(
			current_pos,
			current_pos + force.normalized() * 0.5,
			strength_color(force_strength),
			debug_duration
		)

	# PD torque (angular direction).
	# var torque_strength := clampf(
	# 	torque.length() / maxf(max_angular_force, 0.001),
	# 	0.0,
	# 	1.0
	# )

	# if torque.length() > 0.001:
	# 	DebugDraw3D.draw_arrow(
	# 		current_pos,
	# 		current_pos + torque.normalized() * 0.5,
	# 		strength_color(torque_strength),
	# 		debug_duration
	# 	)


func strength_color(value: float) -> Color:
	var t := clampf(value, 0.0, 1.0)
	if t < 0.5:
		return Color.BLUE.lerp(Color.YELLOW, t * 2.0)
	return Color.YELLOW.lerp(Color.RED, (t - 0.5) * 2.0)
