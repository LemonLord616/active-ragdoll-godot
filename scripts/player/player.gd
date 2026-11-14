extends Node3D
class_name Player

@export var animation_controller: AnimationController
@export var body_support: BodySupport
@export var body_balance: BodyBalance
@export var floor_detector: FloorDetector
@export var motor: RagdollMotor
@export var pd_integrator: PDIntegrator
@export var device: Device
@export var camera: PhantomCamera3D
@export var ragdoll: Ragdoll
@export var anim_player: AnimationPlayer
@export var anim_skeleton: AnimationSkeleton
