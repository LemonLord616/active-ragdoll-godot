extends Node
class_name RagdollMotor

@export var walk_speed := 1.5
@export var run_speed := 3.0
@export var jump_impulse := 4.5
@export var bones_strengths: Dictionary[PhysicalBone3D, float] = {}
@export var player: Player

func move(direction: Vector3, speed: float, delta: float) -> void:
	for bone in bones_strengths:
		bone.linear_velocity += direction * speed * bones_strengths[bone] * delta

func apply_impulse(impulse: Vector3) -> void:
	player.ragdoll.pelvis.linear_velocity += impulse
