extends Node3D
class_name Player


@export var walk_speed := 1.418
@export var run_speed := 6.0
@export var jump_speed := 5.0
@export var horizontal_sensitivity := 0.005
@export var vertical_sensitivity := 0.005

@export var device: Device
@export var camera: PhantomCamera3D

@export var motor: PlayerMotor
@export var pdcontroller: PDController
@export var bone_sim: PhysicalBoneSimulator3D
@export var pelvis_bone: PhysicalBone3D
@export var anim_player: AnimationPlayer
@export var target_skeleton: VelocitySkeleton3D


#func _physics_process(_delta: float) -> void:
	#var camera_delta := device.camera_delta()
	#apply_camera_delta(camera_delta)
#
#func apply_camera_delta(camera_delta: Vector2) -> void:
	#var rot := camera.get_third_person_rotation()
#
	#rot.x = clampf(
		#rot.x - camera_delta.y * horizontal_sensitivity,
		#deg_to_rad(-45.0),
		#deg_to_rad(60.0)
	#)
	#rot.y -= camera_delta.x * vertical_sensitivity
	#
	#camera.set_third_person_rotation(rot)
