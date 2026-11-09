@tool
extends SubViewport
class_name SnowMask

@export var mask_quad: MeshInstance3D
@export var horizontal: SubViewport
@export var history_a: SubViewport
@export var history_b: SubViewport
@export var horizontal_quad: ColorRect
@export var history_quad_a: ColorRect
@export var history_quad_b: ColorRect
@export var snow_surface: MeshInstance3D

var _seed: ImageTexture
var _write_a := true
var _reset := true
var _radius := -1.0

func _ready() -> void:
	var image := Image.create(1, 1, false, Image.FORMAT_RGBA8)
	image.fill(Color.BLACK)
	_seed = ImageTexture.create_from_image(image)
	reset_mask()

func reset_mask() -> void:
	_reset = true
	_write_a = true
	if _seed != null:
		(snow_surface.material_override as ShaderMaterial).set_shader_parameter("snow_mask", _seed)

func configure_filter(smoothing: float, field_size: Vector2) -> void:
	var radius := clampf(smoothing / field_size.x * size.x, 1.0, 16.0) if smoothing > 0.0 else 0.0
	for viewport: SubViewport in [horizontal, history_a, history_b]:
		viewport.size = size
	if is_equal_approx(radius, _radius):
		return
	_radius = radius
	var weights := PackedFloat32Array()
	weights.resize(17)
	var total := 0.0
	for i in 17:
		weights[i] = exp(-float(i * i) / (2.0 * pow(maxf(radius / 3.0, 0.5), 2.0))) if i <= ceili(radius) else 0.0
		total += weights[i] * (1.0 if i == 0 else 2.0)
	for i in 17:
		weights[i] /= total
	for rect: ColorRect in [horizontal_quad, history_quad_a, history_quad_b]:
		var material := rect.material as ShaderMaterial
		material.set_shader_parameter("weights", weights)
		material.set_shader_parameter("radius_pixels", radius)

func _process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	var capture_material := mask_quad.material_override as ShaderMaterial
	configure_filter(float(capture_material.get_shader_parameter("deformation_smoothing")), (capture_material.get_shader_parameter("field_size") as Vector2))
	var horizontal_material := horizontal_quad.material as ShaderMaterial
	horizontal_material.set_shader_parameter("input_texture", get_texture())
	horizontal_material.set_shader_parameter("decode_input", RenderingServer.get_current_rendering_method() != "gl_compatibility")
	horizontal.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var target := history_a if _write_a else history_b
	var previous := history_b if _write_a else history_a
	previous.render_target_update_mode = SubViewport.UPDATE_DISABLED
	var material := (history_quad_a if _write_a else history_quad_b).material as ShaderMaterial
	material.set_shader_parameter("input_texture", horizontal.get_texture())
	material.set_shader_parameter("history_texture", _seed if _reset else previous.get_texture())
	target.render_target_update_mode = SubViewport.UPDATE_ONCE
	var surface_material := snow_surface.material_override as ShaderMaterial
	surface_material.set_shader_parameter("snow_mask", target.get_texture())
	surface_material.set_shader_parameter("mask_is_srgb", false)
	_reset = false
	_write_a = not _write_a
