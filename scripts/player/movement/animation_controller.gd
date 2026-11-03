extends Node


@export var player: Player
@onready var motor := player.motor
@onready var anim_player := player.anim_player

@export var animation_speeds: Dictionary[StringName, float] = {
	&"Walk": 1.418,
	&"Run": 6.0,
}

func _physics_process(_delta: float) -> void:
	var anim_speed = animation_speeds.get(anim_player.current_animation)
	if anim_speed:
		var vel := motor.velocity
		vel.y = 0.0
		var current_speed := vel.length()
		anim_player.speed_scale = current_speed / anim_speed

