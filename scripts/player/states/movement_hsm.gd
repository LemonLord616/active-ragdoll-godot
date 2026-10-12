extends LimboHSM


@export var player: Player
@export var floor_detect: Area3D
@export var on_ground: LimboState
@export var in_air: LimboState


func _ready() -> void:
	add_transition(on_ground, in_air, &"to_air")
	add_transition(in_air, on_ground, &"to_ground")
	initialize(player)
	set_active(true)


func _update(_delta: float) -> void:
	if floor_detect.has_overlapping_bodies():
		dispatch(&"to_ground")
	else:
		dispatch(&"to_air")
