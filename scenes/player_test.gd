extends Node3D


@export var sim: PhysicalBoneSimulator3D

func _ready() -> void:
	sim.physical_bones_start_simulation()
