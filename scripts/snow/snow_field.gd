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

@export var terrain_path: NodePath
## Width and depth of the square snow field, in metres.
@export_range(1.0, 4096.0, 1.0) var area_size: float = 100.0
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

@onready var snow_surface: MeshInstance3D = $SnowSurface
@onready var depth_camera_anchor: RemoteTransform3D = $DepthCameraAnchor
@onready var mask_viewport: SubViewport = $MaskViewport
@onready var depth_camera: Camera3D = $MaskViewport/DepthCamera
@onready var mask_quad: MeshInstance3D = $MaskViewport/DepthCamera/MaskQuad

var _terrain: Node
var _terrain_data: Object
var _height_texture: ImageTexture
var _min_height := 0.0
var _max_height := 0.0
var _baked_heights := PackedFloat32Array()
var _baked_coverage := PackedFloat32Array()
var _baked_normals := PackedVector3Array()
var _baked_resolution := 0


func _ready() -> void:
	if auto_bake:
		await _bake_when_terrain_ready()


## Terrain3D populates its height maps a frame after entering the tree. Baking
## in _ready samples the -200 "no data" height, so wait for the load to finish.
func _bake_when_terrain_ready() -> void:
	_terrain = _resolve_terrain()
	if _terrain != null:
		await get_tree().process_frame
		await get_tree().process_frame
	# Wait for region data, with a bounded timeout instead of baking a sentinel.
	if _terrain != null:
		for attempt in 120:
			var data = _terrain.get("data")
			if data != null and data.call("get_region_count") > 0:
				break
			await get_tree().process_frame
	rebake()


## Re-samples the terrain and rebuilds the snow height texture. Call this after
## moving the field or editing the terrain at runtime.
func rebake() -> void:
	if not global_basis.is_equal_approx(Basis.IDENTITY):
		push_error("Snow requires world-aligned rotation and unit scale (including parents).")
		return
	_terrain = _resolve_terrain()
	_terrain_data = null
	if _terrain != null:
		var data = _terrain.get("data")
		if data != null and data.has_method("get_surface_height"):
			_terrain_data = data

	_configure_viewport()
	_place_camera_provisional()
	_bake_height_texture()
	_build_mesh()
	_configure_camera()
	_configure_materials()
	_configure_aabb()
	if mask_viewport.has_method("reset_mask"):
		mask_viewport.reset_mask()


func _resolve_terrain() -> Node:
	if terrain_path != NodePath():
		var configured := get_node_or_null(terrain_path)
		if configured != null:
			return configured

	var root := get_tree().current_scene
	if root == null:
		root = get_tree().root
	for node in root.find_children("*", "", true, false):
		if node.get_class() == "Terrain3D":
			return node
	return null


## Builds the snow mesh with the terrain height already baked into the vertex
## positions. Keeping the height out of the vertex shader means the mask
## ViewportTexture is the only texture sampled there, which the Compatibility
## renderer requires.
func _build_mesh() -> void:
	var res := clampi(mesh_resolution, 2, 2048)
	var count := res * res
	var half := area_size * 0.5

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
				-half + u * area_size,
				baked.x - global_position.y,
				-half + v * area_size
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


func _place_camera_provisional() -> void:
	# The XZ mapping of an upward-looking orthographic camera does not depend on
	# its Y position, so the bake can run before the terrain height range is
	# known. The camera is moved to its final height afterwards.
	depth_camera_anchor.position = Vector3(0.0, -1.0, 0.0)
	if depth_camera_anchor.has_method("force_update_cache"):
		depth_camera_anchor.force_update_cache()
	depth_camera.global_transform = depth_camera_anchor.global_transform
	depth_camera.size = area_size
	depth_camera.near = 0.05
	depth_camera.far = 1000.0
	depth_camera.cull_mask = _depth_cull_mask()


func _bake_height_texture() -> void:
	var res := clampi(height_resolution, 2, 2048)
	var count := res * res
	var heights := PackedFloat32Array()
	heights.resize(count)
	var valid := PackedByteArray()
	valid.resize(count)

	var min_h := INF
	var max_h := -INF
	var viewport_size := Vector2(mask_viewport.size)

	for y in res:
		for x in res:
			var uv := Vector2(
				(float(x) + 0.5) / float(res),
				(float(y) + 0.5) / float(res)
			)
			var ray_origin := depth_camera.project_ray_origin(uv * viewport_size)
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
	var spacing := area_size / float(res)
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
			var nx := hl - hr
			var nz := hu - hd
			var ny := 2.0 * spacing
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

	var h = _terrain_data.call("get_surface_height", Vector3(x, 0.0, z))
	if typeof(h) == TYPE_FLOAT:
		return h
	if typeof(h) == TYPE_INT:
		return float(h)
	return NAN


func _configure_camera() -> void:
	var camera_y := _min_height - 1.0
	depth_camera_anchor.position = Vector3(0.0, camera_y - global_position.y, 0.0)
	if depth_camera_anchor.has_method("force_update_cache"):
		depth_camera_anchor.force_update_cache()
	depth_camera.global_transform = depth_camera_anchor.global_transform
	depth_camera.size = area_size
	depth_camera.near = 0.05
	depth_camera.far = _max_height + snow_max_height - camera_y + 2.0
	depth_camera.cull_mask = _depth_cull_mask()


func _configure_materials() -> void:
	var compatibility := RenderingServer.get_current_rendering_method() == "gl_compatibility"

	var snow_material := snow_surface.material_override as ShaderMaterial
	if snow_material != null:
		snow_material.set_shader_parameter("snow_max_height", snow_max_height)
		snow_material.set_shader_parameter("area_size", area_size)
		snow_material.set_shader_parameter("mesh_spacing", area_size / float(maxi(mesh_resolution - 1, 1)))
		snow_material.set_shader_parameter("edge_fade", edge_fade)
		snow_material.set_shader_parameter("snow_offset", snow_offset)
		snow_material.set_shader_parameter("mask_is_srgb", not compatibility)

	var mask_material := mask_quad.material_override as ShaderMaterial
	if mask_material != null:
		# Leave previous_frame_texture and previous_is_srgb alone: they are
		# driven by snow_mask.gd's feedback loop.
		mask_material.set_shader_parameter("deformation_smoothing", deformation_smoothing)
		mask_material.set_shader_parameter("height_texture", _height_texture)
		mask_material.set_shader_parameter("snow_max_height", snow_max_height)
		mask_material.set_shader_parameter("area_size", area_size)
		mask_material.set_shader_parameter("edge_fade", edge_fade)
		mask_material.set_shader_parameter("snow_offset", snow_offset)
		mask_material.set_shader_parameter("ndc_z_scale", 2.0 if compatibility else 1.0)
		mask_material.set_shader_parameter("ndc_z_offset", -1.0 if compatibility else 0.0)


func _configure_aabb() -> void:
	var min_local := _min_height - global_position.y
	var max_local := _max_height - global_position.y
	var half := area_size * 0.5
	var height := max_local - min_local + snow_max_height + 0.3
	snow_surface.custom_aabb = AABB(
		Vector3(-half, min_local - 0.1, -half),
		Vector3(area_size, height, area_size)
	)


func _depth_cull_mask() -> int:
	var layer := clampi(influence_layer, 1, 32)
	return (1 << (layer - 1)) | mask_quad.layers
