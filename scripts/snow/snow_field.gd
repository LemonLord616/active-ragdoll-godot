@tool
extends Node3D

## Turns the snow prefab into a heightfield that follows a terrain surface.
##
## The depth-mask pipeline is unchanged: a mask viewport records the lowest
## object surface seen from below, and the snow shader raises the snow surface
## by (1 - mask) * snow_max_height.
##
## This script adds the missing part for non-flat ground. It bakes the terrain
## height and slope coverage into the snow mesh (vertex Y and UV2.x) and stores
## the height + coverage in a texture for the mask shader:
##
##   snow vertex:  y = terrain_height + (1 - mask) * H * coverage
##   mask:         compaction = (terrain_height + H * coverage - object_y) / H
##
## Terrain3D is optional. Without it the baked height is the snow node's own Y,
## so the prefab behaves exactly like the original flat snow field.

@export var terrain: Terrain3D
## Cached editor bake, saved with the scene. Rebuild after terrain changes.
@export var bake: SnowBake
@export_tool_button("Bake snow") var bake_action: Callable = rebake

var _field_size: Vector2
## Resolution of the persistent mask viewport and the snow mesh grid.
@export_range(16, 2048, 1) var mask_resolution: int = 512
## Independent geometry budget. Match this to mask resolution for sharp tracks.
@export_range(16, 2048, 1) var mesh_resolution: int = 256
## Resolution of the baked terrain height texture. 256 is enough for most
## terrain; raise it if the terrain has very sharp features.
@export_range(2, 2048, 1) var height_resolution: int = 256
@export var snow_max_height: float = 1.5
## Contact smoothing radius in metres. Zero disables filtering. Takes effect live.
@export_range(0.0, 2.0, 0.01) var deformation_smoothing: float = 0.15:
	set(value):
		deformation_smoothing = maxf(value, 0.0)
		if is_node_ready():
			var material := mask_quad.material_override as ShaderMaterial
			if material != null:
				material.set_shader_parameter("deformation_smoothing", deformation_smoothing)
## Snow fades to zero as the terrain slope approaches this angle.
@export_range(0.0, 89.0, 1.0) var slope_limit_degrees: float = 55.0
@export_range(0.0, 45.0, 1.0) var slope_fade_degrees: float = 15.0
## Soft border around the field, in metres, so the snow does not end in a wall.
@export_range(0.0, 20.0, 0.1) var edge_fade: float = 2.0
## Keeps the untouched snow shell just above the terrain to avoid z-fighting.
@export var snow_offset: float = 0.02
## Render layer that contains objects which should leave prints. The terrain
## and the snow surface must not be on this layer.
@export_range(1, 32, 1) var influence_layer: int = 5
@export var auto_bake: bool = true

@export var snow_surface: MeshInstance3D
@export var depth_camera_anchor: RemoteTransform3D
@export var mask_viewport: SnowMask
@export var depth_camera: Camera3D
@export var mask_quad: MeshInstance3D

var _terrain_data: Terrain3DData
var _height_texture: ImageTexture
var _min_height := 0.0
var _max_height := 0.0
var _baked_heights := PackedFloat32Array()
var _baked_coverage := PackedFloat32Array()
var _baked_normals := PackedVector3Array()
var _baked_resolution := 0


func _ready() -> void:
	if bake != null:
		_apply_bake()
	elif Engine.is_editor_hint():
		call_deferred("rebake")
	elif auto_bake:
		await get_tree().process_frame
		await get_tree().process_frame
		rebake()


func rebake() -> void:
	if not is_node_ready():
		return
	if not global_basis.orthonormalized().is_equal_approx(Basis.IDENTITY) or global_basis.determinant() <= 0.0:
		push_error("Snow must remain world aligned with positive scale.")
		return
	_field_size = Vector2(global_basis.x.length(), global_basis.z.length())
	_terrain_data = terrain.data if terrain != null else null
	_configure_viewport()
	_bake_height_texture()
	_build_mesh()
	bake = SnowBake.new()
	bake.mesh = snow_surface.mesh
	bake.height_texture = _height_texture
	bake.minimum_height = _min_height
	bake.maximum_height = _max_height
	bake.field_size = _field_size
	bake.origin = global_position
	_apply_bake()


func _apply_bake() -> void:
	_field_size = bake.field_size
	_min_height = bake.minimum_height
	_max_height = bake.maximum_height
	_height_texture = bake.height_texture
	snow_surface.mesh = bake.mesh
	# Geometry is in world metres; the root scale defines only the footprint.
	snow_surface.top_level = true
	snow_surface.global_transform = Transform3D(Basis.IDENTITY, bake.origin)
	_configure_viewport()
	_configure_camera()
	_configure_materials()
	_configure_aabb()
	if Engine.is_editor_hint():
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	else:
		mask_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		mask_viewport.reset_mask()


## Builds the snow mesh with the terrain height already baked into the vertex
## positions. Keeping the height out of the vertex shader means the mask
## ViewportTexture is the only texture sampled there, which the Compatibility
## renderer requires.
func _build_mesh() -> void:
	var res := clampi(mesh_resolution, 2, 2048)
	var count := res * res
	var half := _field_size * 0.5

	var vertices := PackedVector3Array()
	vertices.resize(count)
	var normals := PackedVector3Array()
	normals.resize(count)
	var uvs := PackedVector2Array()
	uvs.resize(count)
	var uv2s := PackedVector2Array()
	uv2s.resize(count)

	for y in res:
		var v := float(y) / float(res - 1)
		for x in res:
			var u := float(x) / float(res - 1)
			var baked := _sample_baked(u, 1.0 - v)
			var index := y * res + x
			vertices[index] = Vector3(
				-half.x + u * _field_size.x,
				baked.x - global_position.y,
				-half.y + v * _field_size.y
			)
			normals[index] = _sample_baked_normal(u, 1.0 - v)
			uvs[index] = Vector2(u, v)
			uv2s[index] = Vector2(baked.y, 0.0)

	var indices := PackedInt32Array()
	indices.resize((res - 1) * (res - 1) * 6)
	var write := 0
	for y in range(1, res):
		for x in range(1, res):
			var i00 := y * res + x
			var i10 := y * res + (x - 1)
			var i01 := (y - 1) * res + x
			var i11 := (y - 1) * res + (x - 1)
			indices[write] = i00
			indices[write + 1] = i10
			indices[write + 2] = i01
			indices[write + 3] = i10
			indices[write + 4] = i11
			indices[write + 5] = i01
			write += 6

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_TEX_UV2] = uv2s
	arrays[Mesh.ARRAY_INDEX] = indices

	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	snow_surface.mesh = mesh


## Bilinear sample of the baked terrain grid. UV follows the height texture:
## V = 0 is +Z, V = 1 is -Z.
func _sample_baked(u: float, v: float) -> Vector2:
	var res := _baked_resolution
	if res <= 0:
		return Vector2(global_position.y, 1.0)

	var tx := u * float(res) - 0.5
	var ty := v * float(res) - 0.5
	var x0 := clampi(floori(tx), 0, res - 1)
	var y0 := clampi(floori(ty), 0, res - 1)
	var x1 := mini(x0 + 1, res - 1)
	var y1 := mini(y0 + 1, res - 1)
	var fx := clampf(tx - float(x0), 0.0, 1.0)
	var fy := clampf(ty - float(y0), 0.0, 1.0)

	var i00 := y0 * res + x0
	var i10 := y0 * res + x1
	var i01 := y1 * res + x0
	var i11 := y1 * res + x1

	var h := lerpf(
		lerpf(_baked_heights[i00], _baked_heights[i10], fx),
		lerpf(_baked_heights[i01], _baked_heights[i11], fx),
		fy
	)
	var c := lerpf(
		lerpf(_baked_coverage[i00], _baked_coverage[i10], fx),
		lerpf(_baked_coverage[i01], _baked_coverage[i11], fx),
		fy
	)
	return Vector2(h, c)


## Bilinear sample of the baked terrain normal grid.
func _sample_baked_normal(u: float, v: float) -> Vector3:
	var res := _baked_resolution
	if res <= 0:
		return Vector3.UP

	var tx := u * float(res) - 0.5
	var ty := v * float(res) - 0.5
	var x0 := clampi(floori(tx), 0, res - 1)
	var y0 := clampi(floori(ty), 0, res - 1)
	var x1 := mini(x0 + 1, res - 1)
	var y1 := mini(y0 + 1, res - 1)
	var fx := clampf(tx - float(x0), 0.0, 1.0)
	var fy := clampf(ty - float(y0), 0.0, 1.0)

	var i00 := y0 * res + x0
	var i10 := y0 * res + x1
	var i01 := y1 * res + x0
	var i11 := y1 * res + x1

	return (
		_baked_normals[i00].lerp(_baked_normals[i10], fx)
		.lerp(_baked_normals[i01].lerp(_baked_normals[i11], fx), fy)
	).normalized()


func _configure_viewport() -> void:
	mask_viewport.size = Vector2i(mask_resolution, mask_resolution)


func _bake_height_texture() -> void:
	var res := clampi(height_resolution, 2, 2048)
	var count := res * res
	var heights := PackedFloat32Array()
	heights.resize(count)
	var valid := PackedByteArray()
	valid.resize(count)

	var min_h := INF
	var max_h := -INF
	

	for y in res:
		for x in res:
			var uv := Vector2(
				(float(x) + 0.5) / float(res),
				(float(y) + 0.5) / float(res)
			)
			var ray_origin := global_position + Vector3((uv.x - 0.5) * _field_size.x, 0.0, (0.5 - uv.y) * _field_size.y)
			var h := _sample_height(ray_origin.x, ray_origin.z)
			var index := y * res + x
			heights[index] = h
			if not is_finite(h):
				valid[index] = 0
			else:
				valid[index] = 1
				min_h = minf(min_h, h)
				max_h = maxf(max_h, h)

	if min_h == INF:
		min_h = global_position.y
		max_h = global_position.y
	_min_height = min_h
	_max_height = max_h

	for i in count:
		if valid[i] == 0:
			heights[i] = min_h

	var image := Image.create(res, res, false, Image.FORMAT_RGBAF)
	var coverage_values := PackedFloat32Array()
	coverage_values.resize(count)
	var normal_values := PackedVector3Array()
	normal_values.resize(count)
	var spacing := _field_size / float(res)
	var cos_limit := cos(deg_to_rad(slope_limit_degrees))
	var cos_fade := cos(deg_to_rad(minf(slope_limit_degrees + slope_fade_degrees, 89.0)))

	for y in res:
		for x in res:
			var index := y * res + x
			var h := heights[index]
			var hl := heights[y * res + maxi(x - 1, 0)]
			var hr := heights[y * res + mini(x + 1, res - 1)]
			var hd := heights[maxi(y - 1, 0) * res + x]
			var hu := heights[mini(y + 1, res - 1) * res + x]
			# Rows run from +Z to -Z, so the +Z neighbour is the previous row.
			var nx := (hl - hr) / spacing.x
			var nz := (hu - hd) / spacing.y
			var ny := 2.0
			var normal := Vector3(nx, ny, nz).normalized()
			var coverage := smoothstep(cos_fade, cos_limit, normal.y) if slope_fade_degrees > 0.0 else float(normal.y >= cos_limit)
			if valid[index] == 0:
				coverage = 0.0
				normal = Vector3.UP
			coverage_values[index] = coverage
			normal_values[index] = normal
			image.set_pixel(x, y, Color(h, coverage, 0.0, 1.0))

	_height_texture = ImageTexture.create_from_image(image)
	_baked_heights = heights
	_baked_coverage = coverage_values
	_baked_normals = normal_values
	_baked_resolution = res


func _sample_height(x: float, z: float) -> float:
	if _terrain_data == null:
		# Flat fallback: keep the old snow behaviour, with the surface at the
		# prefab's own origin.
		return global_position.y

	return _terrain_data.get_surface_height(Vector3(x, 0.0, z))


func _configure_camera() -> void:
	var camera_y := _min_height - 1.0
	depth_camera_anchor.force_update_cache()
	depth_camera.global_transform = Transform3D(Basis(Vector3.RIGHT, -PI / 2.0), Vector3(bake.origin.x, camera_y, bake.origin.z))
	depth_camera.keep_aspect = Camera3D.KEEP_HEIGHT
	depth_camera.size = _field_size.y
	mask_viewport.size = Vector2i(maxi(16, roundi(mask_resolution * _field_size.x / _field_size.y)), mask_resolution)
	depth_camera.near = 0.05
	depth_camera.far = _max_height + snow_max_height - camera_y + 2.0
	depth_camera.cull_mask = _depth_cull_mask()


func _configure_materials() -> void:
	var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"

	var snow_material := snow_surface.material_override as ShaderMaterial
	if snow_material != null:
		snow_material.set_shader_parameter("snow_max_height", snow_max_height)
		snow_material.set_shader_parameter("field_size", _field_size)
		snow_material.set_shader_parameter("mesh_spacing", _field_size / float(maxi(mesh_resolution - 1, 1)))
		snow_material.set_shader_parameter("edge_fade", edge_fade)
		snow_material.set_shader_parameter("snow_offset", snow_offset)
		snow_material.set_shader_parameter("mask_is_srgb", not compatibility)

	var mask_material := mask_quad.material_override as ShaderMaterial
	if mask_material != null:
		mask_material.set_shader_parameter("deformation_smoothing", deformation_smoothing)
		mask_material.set_shader_parameter("height_texture", _height_texture)
		mask_material.set_shader_parameter("snow_max_height", snow_max_height)
		mask_material.set_shader_parameter("field_size", _field_size)
		mask_material.set_shader_parameter("edge_fade", edge_fade)
		mask_material.set_shader_parameter("snow_offset", snow_offset)
		mask_material.set_shader_parameter("ndc_z_scale", 2.0 if compatibility else 1.0)
		mask_material.set_shader_parameter("ndc_z_offset", -1.0 if compatibility else 0.0)


func _configure_aabb() -> void:
	var min_local := _min_height - global_position.y
	var max_local := _max_height - global_position.y
	var half := _field_size * 0.5
	var height := max_local - min_local + snow_max_height + 0.3
	snow_surface.custom_aabb = AABB(
		Vector3(-half.x, min_local - 0.1, -half.y),
		Vector3(_field_size.x, height, _field_size.y)
	)


func _depth_cull_mask() -> int:
	var layer := clampi(influence_layer, 1, 32)
	return (1 << (layer - 1)) | mask_quad.layers
