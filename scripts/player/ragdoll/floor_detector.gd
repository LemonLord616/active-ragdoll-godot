extends Node
class_name FloorDetector

@export var player: Player
@export_flags_3d_physics var ground_mask := 9 # World and solid props; exclude the ragdoll.

func is_on_floor() -> bool:
	var up := player.ragdoll.get_up_direction()
	for bone in player.ragdoll.bones:
		var state := PhysicsServer3D.body_get_direct_state(bone.get_rid())
		if state == null:
			continue
		for contact in state.get_contact_count():
			var collider := state.get_contact_collider(contact)
			if PhysicsServer3D.body_get_collision_layer(collider) & ground_mask:
				if state.get_contact_local_normal(contact).dot(up) > 0.5:
					return true
	return false
