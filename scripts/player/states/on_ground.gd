extends LimboHSM

@export var idle: LimboState
@export var moving: LimboHSM
var player: Player

func _ready() -> void:
	add_transition(idle, moving, &"move")
	add_transition(moving, idle, &"stop")

func _setup() -> void:
	player = agent as Player

func _update(delta: float) -> void:
	dispatch(&"stop" if player.device.input_vector().is_zero_approx() else &"move")
	player.body_support.apply(delta)
	player.body_balance.apply(delta)

func _physics_process(delta: float) -> void:
	if not is_active():
		return
	var skeleton := player.anim_skeleton
	var pelvis := player.ragdoll.get_pelvis_transform()
	var rotation := pelvis.basis.get_rotation_quaternion()
	for bone in player.ragdoll.bones:
		if bone == player.ragdoll.pelvis:
			continue
		var id := bone.get_bone_id()
		var target := rotation * skeleton.get_bone_rotation(id)
		var velocity := player.ragdoll.pelvis.angular_velocity + pelvis.basis * skeleton.get_bone_angular_velocity(id)
		player.pd_integrator.integrate_rotation(bone, target, velocity, delta)

func _enter() -> void:
	player.device.jump.connect(_on_jump)

func _exit() -> void:
	player.device.jump.disconnect(_on_jump)

func _on_jump() -> void:
	if player.floor_detector.is_on_floor():
		player.motor.apply_impulse(player.motor.jump_impulse * player.ragdoll.get_up_direction())
