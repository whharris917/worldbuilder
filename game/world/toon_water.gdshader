shader_type spatial;
// Cartoon water for the brook's ribbon (UV in metres across and along,
// along running upstream): a flat teal, darker where it runs deep,
// streaks of light drifting downstream, and a solid white line of foam
// where it meets the banks and the stones (read from the depth buffer).
// Flat-lit (toon.gdshaderinc).
render_mode cull_disabled;
#include "res://world/granite.gdshaderinc"
#include "res://world/toon.gdshaderinc"

uniform vec3 shallow : source_color = vec3(0.30, 0.72, 0.78);
uniform vec3 deep : source_color = vec3(0.12, 0.42, 0.58);
uniform float flow = 0.7;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;

varying vec2 along;

void vertex() {
	along = UV;
}

void fragment() {
	float depth_raw = texture(depth_tex, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	view.xyz /= view.w;
	float dz = max(-view.z + VERTEX.z, 0.0);
	vec3 ray = normalize(VERTEX);
	float vertical = dz * max(abs(ray.y), 0.05);
	vec3 col = mix(shallow, deep, smoothstep(0.15, 0.3, vertical));
	float streak = value_noise(along * vec2(1.6, 0.35) + vec2(0.0, TIME * flow * 0.35));
	col = mix(col, shallow * 1.35, smoothstep(0.72, 0.75, streak));
	float foam = 1.0 - smoothstep(0.035, 0.05, vertical + 0.03 * value_noise(along * 4.0 + vec2(0.0, TIME * flow * 2.0)));
	col = mix(col, vec3(0.95), foam);
	ALBEDO = col;
	ALPHA = clamp(0.85 + foam + smoothstep(0.0, 0.03, vertical), 0.0, 1.0);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
