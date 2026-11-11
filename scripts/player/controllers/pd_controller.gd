extends Node
class_name PDController

@export_range(0.0, 8000.0, 0.1) var stiffness := 4000.0
@export_range(0.0, 200.0, 0.05) var damping := 80.0
@export var max_torque := 8000.0
@export var bones_strengths: Dictionary[PhysicalBone3D, float] = {}

@export var player: Player

@onready var target := player.anim_skeleton
@onready var ragdoll := player.phys_skeleton
@onready var sim := player.phys_simulator

var _bones: Array[PhysicalBone3D] = []

func _ready() -> void:
	sim.physical_bones_start_simulation()
	for child in sim.get_children():
		if child is PhysicalBone3D:
			_bones.append(child)

func pd(
	Tt: Transform3D,
	Tc: Transform3D,
	wt: Vector3,
	wc: Vector3,
) -> Vector3:
	var pos_err := (Tt.basis * Tc.basis.inverse()).get_euler()
	var vel_err := wt - wc

	var torque := stiffness * pos_err + damping * vel_err
	return torque.limit_length(max_torque)


func _physics_process(delta: float) -> void:
	target.sample_pose()
	for bone: PhysicalBone3D in _bones:
		var id := bone.get_bone_id()

		var target_transform := target.global_transform * target.get_bone_global_pose(id)
		var current_transform := bone.global_transform * bone.body_offset.affine_inverse()

		var target_angular_velocity := target.get_bone_angular_velocity(id, delta)

		var torque := pd(
			target_transform,
			current_transform,
			target_angular_velocity,
			bone.angular_velocity,
		)

		var strength: float = bones_strengths.get(bone, 1.0)
		
		bone.angular_velocity += torque * strength * delta
