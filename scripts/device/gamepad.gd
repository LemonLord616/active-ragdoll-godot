extends Device
class_name Gamepad


@export var device_id: int
@export var left_stick_dead_zone := 0.1
@export var right_stick_dead_zone := 0.1

func input_vector() -> Vector2:
	var stick_vec := left_stick()
	if stick_vec.length() < left_stick_dead_zone:
		return Vector2.ZERO
	return stick_vec

func camera_delta() -> Vector2:
	var stick_vec := right_stick()
	if stick_vec.length() < right_stick_dead_zone:
		return Vector2.ZERO
	return stick_vec

func _input(event: InputEvent) -> void:
	if event.device == device_id:
		super._input(event)


func left_stick() -> Vector2:
	return Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y)
	)

func right_stick() -> Vector2:
	return Vector2(
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_X),
		Input.get_joy_axis(device_id, JOY_AXIS_RIGHT_Y)
	)
