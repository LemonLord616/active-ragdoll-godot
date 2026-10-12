extends Device
class_name Keyboard

var _mouse_delta := Vector2.ZERO

func _ready() -> void:
	return
	# Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _input(event: InputEvent) -> void:
	if event.device == event.DEVICE_ID_KEYBOARD:
		super._input(event)
	if event is InputEventMouseMotion:
		_mouse_delta += event.relative

func input_vector() -> Vector2:
	return Input.get_vector("left", "right", "up", "down")
	# return Vector2(
	# 	int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A)),
	# 	int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	# )

func camera_delta() -> Vector2:
	var result = _mouse_delta
	_mouse_delta = Vector2.ZERO
	return result
