extends Node
class_name BodySupport

@export var player: Player
## Additional gravity units: positive pushes down, negative lifts, zero does nothing.
@export var bones_strengths: Dictionary[PhysicalBone3D, float] = {}

func apply(delta: float) -> void:
	for bone in bones_strengths:
		bone.linear_velocity += player.ragdoll.get_bone_gravity(bone) * bones_strengths[bone] * delta
