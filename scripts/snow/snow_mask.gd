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
var _seed_texture: Texture2D
var _viewport_is_srgb := true
var _first_frame := true


func _ready() -> void:
	_viewport_is_srgb = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	_material = mask_quad.material_override as ShaderMaterial
	if _material != null:
		_previous_frame_texture = _material.get_shader_parameter("previous_frame_texture") as Texture2D
		var seed := Image.create(1, 1, false, Image.FORMAT_RGBA8)
		seed.fill(Color.BLACK)
		_seed_texture = ImageTexture.create_from_image(seed)
		reset_mask()


## Restarts the feedback from the seed texture. The mask accumulates the
## maximum compaction, so a bad frame (for example a bake before the terrain
## data is ready) would otherwise stay visible forever.
func reset_mask() -> void:
	_previous_frame_texture = _seed_texture
	_first_frame = true
	if _material != null:
		# The seed texture is sRGB. Updating the parameters immediately avoids
		# one frame that still reads the old (possibly saturated) mask.
		_material.set_shader_parameter("previous_is_srgb", true)
		_material.set_shader_parameter("previous_frame_texture", _seed_texture)


func _process(_delta: float) -> void:
	await RenderingServer.frame_post_draw

	if _material != null:
		# The seeded noise is an sRGB texture. After the first frame the
		# feedback texture is the viewport, whose color space depends on the
		# renderer.
		_material.set_shader_parameter("previous_is_srgb", _first_frame or _viewport_is_srgb)
		_material.set_shader_parameter("previous_frame_texture", _previous_frame_texture)
		_previous_frame_texture = get_texture()
		_first_frame = false
