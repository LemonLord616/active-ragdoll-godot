extends LimboHSM
class_name MovingHSM

@export var walk: LimboState
@export var run: LimboState
@export var feet: Array[FootIK] = []
var player: Player
var speed := 0.0

func _setup() -> void:
	player = agent as Player

func _ready() -> void:
	add_transition(walk, run, &"run")
	add_transition(run, walk, &"walk")

func _enter() -> void:
	player.anim_player.play(&"Walk")
	for foot in feet:
		foot.active = true

func _exit() -> void:
	player.anim_player.pause()
	for foot in feet:
		foot.active = false

func _update(delta: float) -> void:
	dispatch(&"run" if player.device.run else &"walk")
	var input := player.device.input_vector()
	var forward := player.anim_skeleton.global_basis.z
	var up := player.ragdoll.get_up_direction()
	var direction := -input.y * forward + input.x * forward.cross(up)
	player.motor.move(direction, speed, delta)
	player.animation_controller.set_speed(speed)
	var pelvis := player.ragdoll.get_pelvis_transform()
	for foot in feet:
		foot.place_on_floor(pelvis, up)
