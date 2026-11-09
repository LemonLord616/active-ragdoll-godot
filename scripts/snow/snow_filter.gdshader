shader_type canvas_item;
render_mode unshaded;
uniform sampler2D input_texture : filter_nearest, repeat_disable;
uniform sampler2D history_texture : filter_nearest, repeat_disable;
uniform bool decode_input = false;
uniform bool accumulate = false;
uniform vec2 direction = vec2(1.0, 0.0);
uniform float radius_pixels = 0.0;
uniform float weights[17];
float read_input(vec2 uv) {
 float v = texture(input_texture, uv).r;
 if (decode_input) {
  return v <= 0.04045 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4);
 }
 return v;
}
void fragment() {
 vec2 step_uv = direction / vec2(textureSize(input_texture, 0));
 float value = read_input(UV) * weights[0];
 for (int i = 1; i <= 16; i++) {
  if (float(i) > ceil(radius_pixels)) { break; }
  value += (read_input(UV + step_uv * float(i)) + read_input(UV - step_uv * float(i))) * weights[i];
 }
 if (accumulate) { value = max(value, texture(history_texture, UV).r); }
 COLOR = vec4(value, 0.0, 0.0, 1.0);
}
