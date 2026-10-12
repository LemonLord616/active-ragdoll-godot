extends Node3D
class_name Player


@export var walk_speed := 1.418
@export var run_speed := 6.0
@export var power := 3000.0
@export var max_acceleration := 50.0
@export var jump_speed := 5.0
@export var horizontal_sensitivity := 0.005
@export var vertical_sensitivity := 0.005

@export var device: Device
@export var ragdoll: RagdollSkeleton
@export var anim: AnimationPlayer
@export var bones: PhysicalBoneSimulator3D


const WALK_ANIM_SPEED = 1.418
const RUN_ANIM_SPEED = 6.0


func _physics_process(delta: float) -> void:
	var camera_delta := device.camera_delta()
	apply_camera_delta(camera_delta)


func apply_camera_delta(camera_delta: Vector2) -> void:
	return
	# y_axis.rotate_y(-camera_delta.x * horizontal_sensitivity)
	# x_axis.rotate_x(-camera_delta.y * vertical_sensitivity)
	# x_axis.rotation.x = clampf(x_axis.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))


func apply_input_vector(input_vector: Vector2, speed: float) -> void:
	pass
	
	# var forward := face_dir()
	# var right := forward.cross(Vector3.UP)
	# var move3 := -input_vector.y * forward + input_vector.x * right
	# if move3.is_zero_approx():
	# 	return
	# move3 = move3.normalized()
	# var move2 := Vector2(move3.x, move3.z).normalized()
	# var vel := Vector2(linear_velocity.x, linear_velocity.z)
	# var eff_speed := vel.dot(move2)
	# var F_stall: float = min(4.0 * power / speed, mass * max_acceleration)
	# var F: float = F_stall * (1.0 - max(eff_speed, 0.0) / speed)
	# # var F_max := mass * max_acceleration
	# # F = clampf(F, -F_max, F_max)
	# print(F)
	# apply_force(F * move3)

# func face_dir() -> Vector3:
# 	return -y_axis.global_basis.z
# 
# func look_dir() -> Vector3:
# 	return -x_axis.global_basis.z
# 
