extends CharacterBody3D
class_name PlayerMotor


@export var allowed_offset := 0.1
@export var constraint_stiffness := 80.0
@export var constraint_damping := 8.0

@export var acceleration := 18.0
@export var deceleration := 24.0

@export var player: Player
@onready var skeleton := player.target_skeleton


# state
@onready var speed := player.walk_speed
var _dir := Vector3.FORWARD


func _physics_process(delta: float) -> void:
	velocity += get_gravity() * delta
	_move(delta)
	_constraint(delta)
	move_and_slide()

func _move(delta: float) -> void:
	var target := _dir * speed

	var rate := acceleration * delta
	if _dir.is_zero_approx():
		rate = deceleration * delta
	
	velocity.x = move_toward(velocity.x, target.x, rate)
	velocity.z = move_toward(velocity.z, target.z, rate)

	_dir = Vector3.ZERO

func _constraint(delta: float) -> void:
	var offset := global_position - player.pelvis_bone.global_position
	offset.y = 0.0

	var distance := offset.length()
	if distance <= allowed_offset:
		return
	
	var excess := offset.normalized() * (distance - allowed_offset)

	var correction := (
		-constraint_stiffness * excess
		-constraint_damping * Vector3(velocity.x, 0.0, velocity.z)
	) * delta

	velocity += correction

func set_input_vector(input_vector: Vector2) -> void:

	var forward := face_dir()
	var right := forward.cross(Vector3.UP)
	var move3 := -input_vector.y * forward + input_vector.x * right
	if move3.is_zero_approx():
		return
	_dir = move3.normalized()

func face_dir() -> Vector3:
	var dir := skeleton.global_basis.z
	dir.y = 0
	return dir.normalized()
