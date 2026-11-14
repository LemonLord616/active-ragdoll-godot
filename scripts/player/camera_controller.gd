extends Node
class_name CameraController

@export var mouse_sensitivity := 0.05
@export var min_pitch := -60.0
@export var max_pitch := 45.0
@export var player: Player

func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	_face_forward()

func _face_forward() -> void:
	var up := player.ragdoll.get_up_direction()
	var forward := -player.camera.global_basis.z.slide(up)
	if not forward.is_zero_approx():
		# The character's front is +Z; point it along the camera's viewing direction.
		player.anim_skeleton.look_at(player.anim_skeleton.global_position + forward, up, true)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var rot := player.camera.get_third_person_rotation_degrees()

		rot.x = clampf(
			rot.x - event.relative.y * mouse_sensitivity,
			min_pitch,
			max_pitch
		)
		rot.y = wrapf(
			rot.y - event.relative.x * mouse_sensitivity,
			0.0,
			360.0
		)

		player.camera.set_third_person_rotation_degrees(rot)

		_face_forward()
