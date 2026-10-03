@abstract
extends Node
class_name Device


var run := false :
	set(v):
		if run == v:
			return
		run = v
		run_changed.emit(run)
signal run_changed(bool)
signal jump

func _input(event: InputEvent) -> void:
	if event.is_action("run"):
		run = event.is_pressed()
	if event.is_action_pressed("jump"):
		jump.emit()

@abstract
func input_vector() -> Vector2

@abstract
func camera_delta() -> Vector2
