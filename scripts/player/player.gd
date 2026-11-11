extends Node3D
class_name Player

@export var device: Device
@export var camera: PhantomCamera3D

@export var motor: RagdollMotor
@export var pdcontroller: PDController
@export var pelvis_bone: PhysicalBone3D
@export var phys_simulator: PhysicalBoneSimulator3D
@export var phys_skeleton: Skeleton3D
@export var anim_player: AnimationPlayer
@export var anim_skeleton: VelocitySkeleton3D
