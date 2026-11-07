shader_type spatial;

render_mode blend_mix, depth_draw_opaque, cull_back, diffuse_burley, specular_schlick_ggx;

uniform sampler2D snow_mask : source_color, filter_linear;
uniform float snow_max_height = 1.5;

uniform vec4 albedo : source_color = vec4(1.0);
uniform vec4 albedo_bottom : source_color = vec4(0.7636, 0.8418, 0.92, 1.0);

uniform sampler2D texture_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D texture_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;

uniform float roughness = 1.0;
uniform float specular : hint_range(0.0, 1.0, 0.01) = 0.5;
uniform float uv_scale = 1.81;

varying vec3 world_position;


void vertex() {
	float mask = textureLod(snow_mask, vec2(UV.x, 1.0 - UV.y), 0.0).r;
	VERTEX.y += (1.0 - mask) * snow_max_height;
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}


void fragment() {
	// Geometric normal from the displaced surface. This avoids passing the
	// mesh size and vertex count to the shader, so the plane can be resized
	// freely.
	vec3 tangent_x = dFdx(world_position);
	vec3 tangent_y = dFdy(world_position);
	vec3 normal_world = normalize(cross(tangent_x, tangent_y));

	// The snow surface points along the mesh's local +Y. Flip the derivative
	// normal if it ended up pointing the other way.
	vec3 up_world = normalize((MODEL_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	if (dot(normal_world, up_world) < 0.0) {
		normal_world = -normal_world;
	}
	NORMAL = normalize((VIEW_MATRIX * vec4(normal_world, 0.0)).xyz);

	vec2 uv = UV * uv_scale;
	float mask = texture(snow_mask, vec2(UV.x, 1.0 - UV.y)).r;

	ALBEDO = mix(albedo.rgb, albedo_bottom.rgb, mask) * texture(texture_albedo, uv).rgb;
	ROUGHNESS = texture(texture_roughness, uv).r * roughness;
	SPECULAR = specular;
	SSS_STRENGTH = 0.1;
}
