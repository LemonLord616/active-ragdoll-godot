extends CharacterBody3D
class_name FpsPlayer


@export var gravity_enabled := true
@export var walk_speed := 1.418
@export var run_speed := 6.0
@export var jump_speed := 5.0
@export var horizontal_sensitivity := 0.005
@export var vertical_sensitivity := 0.005

@export var device: Device
@export var y_axis: Node3D
@export var x_axis: Node3D
@export var anim: AnimationPlayer
@export var visuals: Node3D
@export var bones: PhysicalBoneSimulator3D


const WALK_ANIM_SPEED = 1.418
const RUN_ANIM_SPEED = 6.0

func _physics_process(delta: float) -> void:
	var camera_delta := device.camera_delta()

	apply_camera_delta(camera_delta)
	
	velocity += get_gravity() * int(gravity_enabled) * delta
	move_and_slide()


func apply_camera_delta(camera_delta: Vector2) -> void:
	y_axis.rotate_y(-camera_delta.x * horizontal_sensitivity)
	x_axis.rotate_x(-camera_delta.y * vertical_sensitivity)
	x_axis.rotation.x = clampf(x_axis.rotation.x, deg_to_rad(-90.0), deg_to_rad(90.0))

func apply_input_vector(input_vector: Vector2, speed: float) -> void:
	var forward := face_dir()
	# forward.y = 0
	# forward = forward.normalized()
	var right := forward.cross(Vector3.UP)
	var move := (-input_vector.y * forward + input_vector.x * right) * speed
	velocity.x = move.x
	velocity.z = move.z

func face_dir() -> Vector3:
	return -y_axis.global_basis.z

func look_dir() -> Vector3:
	return -x_axis.global_basis.z
