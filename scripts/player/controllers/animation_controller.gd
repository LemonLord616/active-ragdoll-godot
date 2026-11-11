extends Node
class_name AnimationController


@export var player: Player
@onready var pelvis := player.pelvis_bone
@onready var anim_player := player.anim_player

@export var animation_speeds: Dictionary[StringName, float] = {
	&"Walk": 2.7,
}

func _physics_process(_delta: float) -> void:
	var anim_speed = animation_speeds.get(anim_player.current_animation)
	if anim_speed:
		# var vel := pelvis.linear_velocity
		# vel.y = 0.0
		# var current_speed := vel.length()
		var current_speed := player.motor.speed
		if is_zero_approx(current_speed):
			return
		anim_player.speed_scale = current_speed / anim_speed
