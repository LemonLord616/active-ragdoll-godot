extends LimboHSM


@export var idle: LimboState
@export var walk: LimboState
@export var run: LimboState


var player: Player

func _setup() -> void:
	player = agent as Player


func _ready() -> void:
	add_transition(walk, idle, &"to_idle")
	add_transition(run,  idle, &"to_idle")
	add_transition(idle, walk, &"to_walk")
	add_transition(run,  walk, &"to_walk")
	add_transition(idle, run,  &"to_run")
	add_transition(walk, run,  &"to_run")


func _update(_delta: float) -> void:
	if player.device.input_vector().is_zero_approx():
		dispatch(&"to_idle")
	elif player.device.run:
		dispatch(&"to_run")
	else:
		dispatch(&"to_walk")

func _enter() -> void:
	player.device.jump.connect(_on_jump)

func _exit() -> void:
	player.device.jump.disconnect(_on_jump)

func _on_jump() -> void:
	player.motor.velocity.y += player.jump_speed
