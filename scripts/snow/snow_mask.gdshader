shader_type spatial;

// Fullscreen depth/mask pass used by the snow SubViewport.
// Reads the depth buffer, reconstructs the world-space height of the lowest
// object surface at each texel, and converts it into a snow compaction value
// relative to the baked terrain height. The previous frame is fed back by
// snow_mask.gd.

render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform sampler2D previous_frame_texture : hint_default_black, filter_linear;
uniform sampler2D height_texture : hint_default_black, filter_linear, repeat_disable;

uniform float snow_max_height = 1.5;
uniform vec2 field_size = vec2(100.0);
uniform float edge_fade = 2.0;
uniform float snow_offset = 0.02;
uniform float deformation_smoothing = 0.15;

// Set by snow_field.gd. Forward+ renders the mask viewport as sRGB and uses
// [0, 1] clip depth; Compatibility renders it linear and uses [-1, 1] clip
// depth.
uniform bool previous_is_srgb = true;
uniform float ndc_z_scale = 1.0;
uniform float ndc_z_offset = 0.0;


void vertex() {
	// The quad mesh is 2x2, so VERTEX.xy is already in clip space.
	// This keeps the mask pass independent of mesh/camera size.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}


float sample_depth(vec2 uv) {
	return texture(depth_texture, uv).x;
}


float srgb_to_linear(float value) {
	if (value <= 0.04045) {
		return value / 12.92;
	}
	return pow((value + 0.055) / 1.055, 2.4);
}


// Convert each contact to terrain-relative compaction before filtering.
// Blurring raw depth would mix background/terrain heights across slopes.
float contact_compaction(vec2 uv, mat4 inv_projection, mat4 inv_view) {
 uv = clamp(uv, vec2(0.0), vec2(1.0));
 float raw = sample_depth(uv);
 float ndc_z = raw * ndc_z_scale + ndc_z_offset;
 vec4 view = inv_projection * vec4(uv * 2.0 - 1.0, ndc_z, 1.0);
 view.xyz /= view.w;
 float object_y = (inv_view * vec4(view.xyz, 1.0)).y;
 vec4 height_data = texture(height_texture, uv);
 vec2 edge_distance = min(uv, vec2(1.0) - uv);
 vec2 edge_t = smoothstep(vec2(0.0),
  vec2(max(edge_fade, 0.001)) / max(field_size, vec2(0.001)), edge_distance);
 float local_height = snow_max_height * height_data.g * edge_t.x * edge_t.y;
 if (local_height <= 0.001) { return 0.0; }
 return clamp((height_data.r + local_height + snow_offset - object_y) / local_height, 0.0, 1.0);
}

void fragment() {
 float compaction = 0.0;
 if (deformation_smoothing <= 0.0) {
  compaction = contact_compaction(SCREEN_UV, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX);
 } else {
  // Dense pixel-spaced taps avoid repeated copies of narrow contacts.
  vec2 texel = 1.0 / vec2(textureSize(depth_texture, 0));
  float radius_pixels = clamp(deformation_smoothing / max(field_size.x, 0.001) / texel.x, 1.0, 16.0);
  int radius = int(ceil(radius_pixels));
  float sigma = max(radius_pixels / 3.0, 0.5);
  float weight_sum = 0.0;
  for (int y = -16; y <= 16; y++) {
   if (abs(y) > radius) { continue; }
   for (int x = -16; x <= 16; x++) {
    if (abs(x) > radius) { continue; }
    float weight = exp(-float(x*x + y*y) / (2.0 * sigma * sigma));
    compaction += contact_compaction(SCREEN_UV + vec2(float(x), float(y)) * texel, INV_PROJECTION_MATRIX, INV_VIEW_MATRIX) * weight;
    weight_sum += weight;
   }
  }
  compaction /= weight_sum;
 }

	float previous = texture(previous_frame_texture, SCREEN_UV).r;
	if (previous_is_srgb) {
		previous = srgb_to_linear(previous);
	}

	ALBEDO = vec3(max(compaction, previous), 0.0, 0.0);
}
