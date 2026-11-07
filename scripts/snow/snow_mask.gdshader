shader_type spatial;

// Fullscreen depth/mask pass used by the snow SubViewport.
// Reads the depth buffer, normalizes it into snow depth and keeps the maximum
// value seen so far. The previous frame is fed back by snow_mask.gd.

render_mode unshaded, fog_disabled, depth_draw_never, depth_test_disabled, cull_disabled;

uniform sampler2D depth_texture : hint_depth_texture, filter_linear;
uniform sampler2D previous_frame_texture : source_color, hint_default_black, filter_linear;

// Distance from the depth camera to the snow base divided by the camera far
// plane. With the default camera at y = -1 and far = 2.5 this is 0.4.
uniform float depth_start_percentage = 0.4;


void vertex() {
	// The quad mesh is 2x2, so VERTEX.xy is already in clip space.
	// This keeps the mask pass independent of mesh/camera size.
	POSITION = vec4(VERTEX.xy, 0.0, 1.0);
}


float sample_depth(vec2 uv) {
	return texture(depth_texture, uv).x;
}


void fragment() {
	// Small cross blur. The original uses a 9x9 Gaussian; this is enough to
	// soften trails and costs five samples.
	vec2 texel = 1.0 / vec2(textureSize(depth_texture, 0));
	float raw = sample_depth(SCREEN_UV);
	raw += sample_depth(SCREEN_UV + vec2(texel.x, 0.0));
	raw += sample_depth(SCREEN_UV - vec2(texel.x, 0.0));
	raw += sample_depth(SCREEN_UV + vec2(0.0, texel.y));
	raw += sample_depth(SCREEN_UV - vec2(0.0, texel.y));
	raw *= 0.2;

	// Reverse-Z: raw depth is 1 at the near plane and 0 at the far plane.
	// Map the part between the snow base and the camera's far plane to 0..1.
	float closest_depth = 1.0 - depth_start_percentage;
	float depth = clamp(raw / closest_depth, 0.0, 1.0);

	float previous = texture(previous_frame_texture, SCREEN_UV).r;

	ALBEDO = vec3(max(depth, previous), 0.0, 0.0);
}
