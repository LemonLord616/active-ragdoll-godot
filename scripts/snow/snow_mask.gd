extends SubViewport

## Feeds the mask viewport back into its own shader.
##
## This is the only runtime code in the package. Everything else (nodes,
## materials, textures, sizes) is configured in snow.tscn. Godot cannot sample
## the current viewport texture from inside the same viewport without explicitly
## passing an older frame back, so this small loop is unavoidable.
##
## The texture is handed over one frame late: the render target that is still
## being drawn to samples as white, so the mask would be poisoned on frame one.

@export var mask_quad: MeshInstance3D

var _material: ShaderMaterial
var _previous_frame_texture: Texture2D


func _ready() -> void:
	_material = mask_quad.material_override as ShaderMaterial
	if _material != null:
		_previous_frame_texture = _material.get_shader_parameter("previous_frame_texture") as Texture2D


func _process(_delta: float) -> void:
	await RenderingServer.frame_post_draw

	if _material != null:
		_material.set_shader_parameter("previous_frame_texture", _previous_frame_texture)
		_previous_frame_texture = get_texture()
