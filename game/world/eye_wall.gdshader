shader_type spatial;
// The patch of the Shifting Room's front wall where the eye is: a finely
// divided flat plane whose points are moved out of the wall by the height
// in `heights` (red, metres), and whose shading follows the slope stored
// with it (green across, blue up, each as 0.5 + slope / 16), as
// eye_height.gdshader draws them.
// Matte grey like the other walls. The plane lies with its own up axis
// out of the wall, its x across and its z down the wall.
render_mode cull_back;

uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec3 albedo : source_color = vec3(0.6);
uniform float roughness = 0.9;

void vertex() {
	vec4 h = textureLod(heights, UV, 0.0);
	VERTEX.y += h.r;
	// Slope across (x) and up the wall; up is the plane's -z.
	vec2 s = (h.gb - 0.5) * 16.0;
	NORMAL = normalize(vec3(-s.x, 1.0, s.y));
}

void fragment() {
	vec2 s = (texture(heights, UV).gb - 0.5) * 16.0;
	vec3 n = normalize(vec3(-s.x, 1.0, s.y));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
	ALBEDO = albedo;
	ROUGHNESS = roughness;
}
