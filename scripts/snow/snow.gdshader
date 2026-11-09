shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_mask : hint_default_black, filter_linear;
uniform float snow_max_height = 1.5;

// Set by snow_field.gd. Forward+ renders the mask viewport as sRGB,
// Compatibility renders it linear.
uniform bool mask_is_srgb = true;

// Baked heightfield parameters.
uniform vec2 field_size = vec2(100.0);
uniform float edge_fade = 2.0;
uniform float snow_offset = 0.02;
uniform vec2 mesh_spacing = vec2(0.078);

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 albedo_bottom : source_color = vec4(0.7636, 0.8418, 0.92, 1.0);

uniform float grain_scale = 18.0;
uniform float grain_strength : hint_range(0.0, 0.2) = 0.045;
varying vec3 snow_world_position;
float grain(vec3 p) {
 vec3 cell = floor(p);
 vec3 f = fract(p);
 f = f * f * (3.0 - 2.0 * f);
 float n = 0.0;
 for (int z=0; z<2; z++) {
  for (int y=0; y<2; y++) {
   for (int x=0; x<2; x++) {
    vec3 o = vec3(float(x), float(y), float(z));
    vec3 w = mix(vec3(1.0)-f, f, o);
    n += fract(sin(dot(cell+o, vec3(127.1,311.7,74.7)))*43758.5453)*w.x*w.y*w.z;
   }
  }
 }
 return n;
}


uniform float roughness = 1.0;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float uv_scale = 1.81;

varying float v_coverage;
varying float v_edge;


float srgb_to_linear(float value) {
	if (value <= 0.04045) {
		return value / 12.92;
	}
	return pow((value + 0.055) / 1.055, 2.4);
}


float decode_mask(float value) {
	if (mask_is_srgb) {
		return srgb_to_linear(value);
	}
	return value;
}


// The Compatibility renderer samples a high mip level when a ViewportTexture
// is read with texture()/textureLod() in the vertex stage. texelFetch bypasses
// mip selection, so the mask is fetched manually here with bilinear filtering.
// texelFetch is used in both stages: the Compatibility renderer cannot combine
// texture() and texelFetch() on the same sampler.
float sample_mask(vec2 uv) {
	ivec2 size = textureSize(snow_mask, 0);
	vec2 texel = uv * vec2(size) - 0.5;
	ivec2 base = ivec2(floor(texel));
	vec2 frac = fract(texel);
	ivec2 last = size - 1;
	float v00 = texelFetch(snow_mask, clamp(base, ivec2(0), last), 0).r;
	float v10 = texelFetch(snow_mask, clamp(base + ivec2(1, 0), ivec2(0), last), 0).r;
	float v01 = texelFetch(snow_mask, clamp(base + ivec2(0, 1), ivec2(0), last), 0).r;
	float v11 = texelFetch(snow_mask, clamp(base + ivec2(1, 1), ivec2(0), last), 0).r;
	float value = mix(mix(v00, v10, frac.x), mix(v01, v11, frac.x), frac.y);
	return decode_mask(value);
}


// Snow thickness at a mask UV. Used for the displacement and for its gradient.
float snow_depth(vec2 uv, float coverage) {
	vec2 edge_distance = min(uv, vec2(1.0) - uv);
	vec2 edge_t = smoothstep(
		vec2(0.0),
		vec2(max(edge_fade, 0.001) / max(field_size, vec2(0.001))),
		edge_distance
	);
	float edge = edge_t.x * edge_t.y;
	return (1.0 - sample_mask(uv)) * snow_max_height * coverage * edge
		+ snow_offset;
}


void vertex() {
	// The mask is rendered by an upward-looking camera, so its screen UV has
	// the opposite V direction from the plane's UV.
	vec2 mask_uv = vec2(UV.x, 1.0 - UV.y);

	// Terrain height is baked into the mesh. UV2.x carries slope coverage.
	float coverage = UV2.x;
	float depth = snow_depth(mask_uv, coverage);

	// Smooth vertex normal: the baked terrain normal from the mesh, perturbed
	// by the snow thickness gradient. Derivative normals in the fragment stage
	// pick up per-row interpolation noise in Compatibility and stripe the
	// surface, so the normal is built here instead.
	vec2 mask_texel = max(1.0 / vec2(textureSize(snow_mask, 0)), vec2(mesh_spacing / max(field_size, vec2(0.001))));
	float depth_left = snow_depth(mask_uv - vec2(mask_texel.x, 0.0), coverage);
	float depth_right = snow_depth(mask_uv + vec2(mask_texel.x, 0.0), coverage);
	float depth_back = snow_depth(mask_uv - vec2(0.0, mask_texel.y), coverage);
	float depth_front = snow_depth(mask_uv + vec2(0.0, mask_texel.y), coverage);

	float snow_dx = (depth_right - depth_left) / (2.0 * mask_texel.x * field_size.x);
	// mask_uv.y decreases as local +Z increases.
	float snow_dz = -(depth_front - depth_back) / (2.0 * mask_texel.y * field_size.y);

	vec3 terrain_normal = normalize(NORMAL);
	float terrain_dx = -terrain_normal.x / max(terrain_normal.y, 0.001);
	float terrain_dz = -terrain_normal.z / max(terrain_normal.y, 0.001);

	VERTEX.y += depth;
	snow_world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	NORMAL = normalize(vec3(
		-(terrain_dx + snow_dx),
		1.0,
		-(terrain_dz + snow_dz)
	));

	vec2 edge_distance = min(mask_uv, vec2(1.0) - mask_uv);
	vec2 edge_t = smoothstep(
		vec2(0.0),
		vec2(max(edge_fade, 0.001) / max(field_size, vec2(0.001))),
		edge_distance
	);
	v_coverage = coverage;
	v_edge = edge_t.x * edge_t.y;
}


void fragment() {
	// Snow is discarded where it has no thickness (steep slopes) or where the
	// field fades out at its border. The terrain then shows through.
	if (v_coverage * v_edge < 0.01) {
		discard;
	}

	vec2 mask_uv = vec2(UV.x, 1.0 - UV.y);
	float mask = sample_mask(mask_uv);

	vec2 uv = UV * uv_scale;
	ALBEDO = mix(albedo.rgb, albedo_bottom.rgb, mask) * vec3(1.0 - grain_strength * grain(snow_world_position * grain_scale));
	ROUGHNESS = clamp(roughness - 0.08 * grain(snow_world_position * grain_scale), 0.0, 1.0);
	SPECULAR = specular;
	SSS_STRENGTH = 0.1;
}
