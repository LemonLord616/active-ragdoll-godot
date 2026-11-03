extends Node
class_name Debugger

@export var active := true
@export var node: Node
@export var property: StringName
@export var method: StringName
@export var draw_pos := false
@export var draw_arrow := false


enum LogLevel {
	DEBUG,
	WARNING,
	ERROR,
}

func _physics_process(_delta: float) -> void:
	if not active:
		return
	if property:
		debug(node.name, property, node.get(property))
	if method:
		debug(node.name, method, node.call(method))
	if node is not Node3D:
		return
	if draw_pos:
		DebugDraw3D.draw_sphere(node.global_position, 0.1)
	if draw_arrow:
		DebugDraw3D.draw_arrow(
			node.global_position - node.position,
			node.global_position,
			Color.GREEN_YELLOW, 0.2)


static func _log(level: LogLevel, args: Array) -> void:
	var parts: PackedStringArray = []
	match level:
		LogLevel.DEBUG: parts.append("[DEBUG]")
		LogLevel.WARNING: parts.append("[WARNING]")
		LogLevel.ERROR: parts.append("[ERROR]")
	var stack := get_stack()
	if stack.size() > 2:
		var frame: Dictionary = stack[2]
		parts.append("[%s:%d]" % [frame.source.get_file(), frame.line])
	for arg in args:
		parts.append(str(arg))
	print(" ".join(parts))

static func debug(...args) -> void:
	_log(LogLevel.DEBUG, args)

static func warn(...args) -> void:
	_log(LogLevel.WARNING, args)

static func error(...args) -> void:
	_log(LogLevel.ERROR, args)
