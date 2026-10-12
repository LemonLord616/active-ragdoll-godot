extends PhysicalBone3D
class_name RagdollBone


var _force := Vector3.ZERO
var _torque := Vector3.ZERO

func apply_force(force: Vector3) -> void:
	_force += force

func apply_torque(torque: Vector3) -> void:
	_torque += torque

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	state.apply_force(_force)
	state.apply_torque(_torque)
	_force = Vector3.ZERO
	_torque = Vector3.ZERO
