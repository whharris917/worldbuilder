shader_type spatial;
// A country road of packed gravel and earth, or a farm's two-track
// lane, on a ribbon whose UV is metres across from the centre line and
// metres along it. The road: a pale crowned middle, two darker wheel
// tracks worn smooth, loose stones toward the edges, and its edge
// running ragged into the grass. The lane (two_track): only its two
// bare ruts are drawn; the grass grows between and beside them. Detail fades with distance so the
// far road is an even pale line over the hills.
#include "res://world/granite.gdshaderinc"

uniform float half_width = 2.6;
uniform float two_track = 0.0;
uniform vec3 gravel : source_color = vec3(0.47, 0.43, 0.36);
uniform vec3 earth : source_color = vec3(0.36, 0.30, 0.22);
uniform vec3 grass : source_color = vec3(0.11, 0.14, 0.06);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float x = UV.x;
	float along = UV.y;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float fine = 1.0 - smoothstep(30.0, 150.0, dist);
	vec2 p = world_pos.xz;
	float ax = abs(x);
	vec3 col;
	if (two_track > 0.5) {
		// Two ruts 0.75 m either side of the middle, each about 0.45 m.
		float rut = 1.0 - smoothstep(0.18, 0.3, abs(ax - 0.75) + 0.06 * (value_noise(vec2(along * 0.4, x)) - 0.5));
		if (rut < 0.5) {
			discard;
		}
		col = mix(earth, gravel, 0.35 + 0.3 * value_noise(p * 3.0) * fine);
		col *= 0.85 + 0.25 * value_noise(p * 14.0) * fine;
	} else {
		col = mix(earth, gravel, 0.6 + 0.25 * value_noise(p * 0.8));
		// The crown pale, the wheel tracks darker and smoother.
		float track = 1.0 - smoothstep(0.25, 0.55, abs(ax - 1.1));
		col *= 1.0 - 0.14 * track;
		col *= 1.0 + 0.08 * (1.0 - smoothstep(0.0, 0.6, ax));
		// Loose stones and their shadows, most off the tracks.
		float stones = smoothstep(0.62, 0.8, value_noise(p * 9.0)) * (1.0 - 0.7 * track) * fine;
		col = mix(col, gravel * 1.12, stones * 0.4);
		col *= 0.9 + 0.2 * value_noise(p * 25.0) * fine + 0.1 * (1.0 - fine);
		// The edge running ragged into the grass.
		float edge = half_width - 0.25 + 0.45 * (value_noise(vec2(along * 0.35, sign(x) * 7.0)) - 0.5);
		col = mix(col, grass * (0.8 + 0.4 * value_noise(p * 2.0)), smoothstep(edge - 0.15, edge + 0.25, ax));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.15;
}
