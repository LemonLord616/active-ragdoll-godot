@tool
extends BTCondition


func _tick(_delta: float) -> Status:
	if agent is CharacterBody3D:
		if agent.is_on_floor():
			return SUCCESS
	return FAILURE
