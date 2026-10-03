extends LimboHSM


@export var player: FpsPlayer
@export var on_ground: LimboState
@export var in_air: LimboState


func _ready() -> void:
	add_transition(on_ground, in_air, &"check_floor", func(): return not player.is_on_floor())
	add_transition(in_air, on_ground, &"check_floor", func(): return player.is_on_floor())
	print(player)
	print(player.device)
	initialize(player)
	set_active(true)


func _update(_delta: float) -> void:
	dispatch("check_floor")
