extends Node



@export var node: Node3D


func _physics_process(delta: float) -> void:
	print(node.global_position)
