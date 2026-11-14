extends LimboHSM
class_name MovementHSM

@export_range(0.1, 5.0, 0.1) var coyote := 1.0
@export var player: Player
@export var on_ground: LimboHSM
@export var in_air: LimboState

var _timer := 0.0

func _ready() -> void:
	add_transition(in_air, on_ground, &"on_ground")
	add_transition(on_ground, in_air, &"in_air")
	initial_state = in_air
	initialize(player)
	set_active(true)

func _update(delta: float) -> void:
	var on_floor := player.floor_detector.is_on_floor()
	if on_floor:
		_timer = coyote
		dispatch(&"on_ground")
	elif _timer < 0:
		dispatch(&"in_air")
	else:
		_timer -= delta
