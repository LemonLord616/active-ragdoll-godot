extends Skeleton3D
class_name VelocitySkeleton3D


var _prev_pos: Dictionary[int, Vector3] = {}
var _cur_pos: Dictionary[int, Vector3] = {}
var _prev_quat: Dictionary[int, Quaternion] = {}
var _cur_quat: Dictionary[int, Quaternion] = {}
var _delta: float = 0.016


func _ready() -> void:
	_sample_pose()
	_prev_pos = _cur_pos.duplicate()
	_prev_quat = _cur_quat.duplicate()

func _physics_process(delta: float) -> void:
	_delta = delta
	_prev_pos = _cur_pos.duplicate()
	_prev_quat = _cur_quat.duplicate()
	_sample_pose()

func _sample_pose() -> void:
	_cur_pos.clear()
	_cur_quat.clear()
	for id in get_bone_count():
		var pose := get_bone_global_pose(id)
		_cur_pos.set(id, pose.origin)
		_cur_quat.set(id, Quaternion(pose.basis.orthonormalized()))

func get_bone_linear_velocity(id: int) -> Vector3:
	if not _cur_pos.has(id):
		Debugger.error("_cur_pos has no", id)
		return Vector3.ZERO
	if not _prev_pos.has(id):
		Debugger.error("_prev_pos has no", id)
		return Vector3.ZERO
	var rel	:= _cur_pos[id] - _prev_pos[id]
	return rel / _delta

func get_bone_angular_velocity(id: int) -> Vector3:
	if not _cur_quat.has(id):
		Debugger.error("_cur_quat has no", id)
		return Vector3.ZERO
	if not _prev_quat.has(id):
		Debugger.error("_prev_quat has no", id)
		return Vector3.ZERO
	var dq: Quaternion = _cur_quat[id] * _prev_quat[id].inverse()
	if dq.w < 0.0:
		dq = -dq
	var rel := dq.get_axis() * dq.get_angle()
	return rel / _delta
