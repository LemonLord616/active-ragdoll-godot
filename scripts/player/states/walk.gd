extends LimboState

var player: Player

func _setup() -> void:
	player = agent as Player

func _enter() -> void:
	(get_parent() as MovingHSM).speed = player.motor.walk_speed
