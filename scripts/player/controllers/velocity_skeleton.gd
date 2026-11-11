extends Skeleton3D
class_name VelocitySkeleton3D


var _prev: Dictionary[int, Transform3D] = {}
var _cur: Dictionary[int, Transform3D] = {}


func _ready() -> void:
	sample_pose()
	_prev = _cur.duplicate()

# func _physics_process(_delta: float) -> void:
# 	sample_pose()

func sample_pose() -> void:
	_prev = _cur.duplicate()
	_cur.clear()

	for id in get_bone_count():
		var pose := global_transform * get_bone_global_pose(id)
		_cur[id] = pose

func get_bone_angular_velocity(id: int, delta: float) -> Vector3:
	var err := _cur[id].basis * _prev[id].basis.inverse()
	return err.get_euler() / delta
