extends Node
class_name RagdollMotor


@export var damping := 0.9
@export var walk_speed := 1.5
@export var run_speed := 3.0
@export var jump_impulse := 50.0

@export var player: Player
@onready var skeleton := player.anim_skeleton
@onready var pelvis := player.pelvis_bone


# state
@onready var speed := walk_speed
var _dir := Vector3.FORWARD


func move(input_vector: Vector2, delta) -> void:
	var forward := face_dir()
	var right := forward.cross(Vector3.UP)
	var move3 := -input_vector.y * forward + input_vector.x * right
	if move3.is_zero_approx():
		return
	_dir = move3.normalized()
	for bone in player.pdcontroller._bones:
		var strength: float = player.pdcontroller.bones_strengths.get(bone, 1.0)
		bone.linear_velocity += _dir * speed * delta * strength
	# pelvis.linear_velocity += _dir * speed * delta
	# pelvis.linear_velocity *= Vector3(damping, 1, damping)

func apply_impulse(p: Vector3) -> void:
	pelvis.linear_velocity += p

func face_dir() -> Vector3:
	var dir := skeleton.global_basis.z
	dir.y = 0
	return dir.normalized()
