extends Skeleton3D
class_name AnimationSkeleton

@export var pelvis_bone := 1
var _rotations: Dictionary[int, Quaternion] = {}
var _previous: Dictionary[int, Quaternion] = {}
var _delta := 0.0

func _ready() -> void:
	modifier_callback_mode_process = Skeleton3D.MODIFIER_CALLBACK_MODE_PROCESS_MANUAL
	_capture_rotations()
	# IK rotations are only available until Godot restores the animation pose.
	skeleton_updated.connect(_capture_rotations)

func _physics_process(delta: float) -> void:
	_previous = _rotations.duplicate()
	_delta = delta
	advance(delta)
	notification(NOTIFICATION_UPDATE_SKELETON)

func _capture_rotations() -> void:
	for id in get_bone_count():
		_rotations[id] = get_bone_global_pose(id).basis.orthonormalized().get_rotation_quaternion()

## Getters use the animation pelvis frame, independent of node transforms.
func get_bone_rotation(id: int) -> Quaternion:
	return _rotations[pelvis_bone].inverse() * _rotations[id]

func get_bone_angular_velocity(id: int) -> Vector3:
	if is_zero_approx(_delta):
		return Vector3.ZERO
	var previous := _previous[pelvis_bone].inverse() * _previous[id]
	return rotation_vector(get_bone_rotation(id) * previous.inverse()) / _delta

## Reference animation position for preparing IK targets, before modifiers.
func get_bone_position(id: int) -> Vector3:
	return get_bone_global_pose(pelvis_bone).affine_inverse() * get_bone_global_pose(id).origin

static func rotation_vector(rotation: Quaternion) -> Vector3:
	var q := rotation.normalized()
	if q.w < 0.0:
		q = -q
	var imaginary := Vector3(q.x, q.y, q.z)
	var length := imaginary.length()
	if is_zero_approx(length):
		return imaginary * 2.0
	return imaginary * (2.0 * atan2(length, q.w) / length)
