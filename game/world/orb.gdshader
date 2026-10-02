shader_type spatial;
// A hovering light seen as a glowing point: a billboard with a white-hot
// core and a warm halo, added to what is behind it. It never shrinks
// under a few pixels, so far off it is a bright point, not nothing.
// Each orb sets its own brightness (instance uniform).
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.72, 0.42);
uniform float radius = 1.2;          // metres, the halo's reach near by
instance uniform float glow = 0.0;

void vertex() {
	vec3 centre = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float dist = length(centre - CAMERA_POSITION_WORLD);
	float size = max(radius, dist * 0.009);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * 2.0 * size;
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float core = 1.0 - smoothstep(0.06, 0.16, d);
	float halo = pow(clamp(1.0 - d, 0.0, 1.0), 3.0);
	ALBEDO = (vec3(1.0, 0.97, 0.92) * core * 6.0 + color * halo * 2.5) * glow;
}
