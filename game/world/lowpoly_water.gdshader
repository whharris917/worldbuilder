shader_type spatial;
// The diorama's water: a sheet of resin, as on a model, clear teal over
// the sandy bed and deeper where the bed falls away (read from the
// depth buffer), glossy, with a pale line where it meets the banks.
render_mode cull_disabled;

uniform vec3 shallow : source_color = vec3(0.50, 0.85, 0.85);
uniform vec3 deep : source_color = vec3(0.20, 0.55, 0.70);
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;

void fragment() {
	float depth_raw = texture(depth_tex, SCREEN_UV).x;
	vec4 view = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, depth_raw, 1.0);
	view.xyz /= view.w;
	float dz = max(-view.z + VERTEX.z, 0.0);
	float vertical = dz * max(abs(normalize(VERTEX).y), 0.05);
	vec3 col = mix(shallow, deep, smoothstep(0.1, 0.6, vertical));
	col = mix(col, vec3(0.92, 0.97, 0.97), 1.0 - smoothstep(0.02, 0.05, vertical));
	ALBEDO = col;
	ALPHA = clamp(0.6 + vertical * 1.5, 0.0, 0.92);
	ROUGHNESS = 0.08;
	SPECULAR = 0.6;
}
