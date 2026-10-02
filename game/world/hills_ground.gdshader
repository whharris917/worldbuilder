shader_type spatial;
// The grass hills' ground. Under the shell grass near the camera it is
// the dark floor of the turf; past where the shells end it is the turf
// itself seen from afar, in the shells' own colours, so the hills are
// grass to the horizon. The gusts (gust.gdshaderinc, the same bands as
// the shells') run over it as they do over the shells: where a band
// passes the grass turns pale, between bands it is darker, so the
// wind can be watched crossing the far hillsides. World-space
// throughout, so nothing swims.
#include "res://world/granite.gdshaderinc"
#include "res://world/gust.gdshaderinc"

uniform vec3 green : source_color = vec3(0.22, 0.32, 0.11);
uniform vec3 yellow_green : source_color = vec3(0.40, 0.44, 0.18);
uniform vec3 seed_tan : source_color = vec3(0.56, 0.50, 0.33);
uniform vec3 root_dark : source_color = vec3(0.06, 0.08, 0.03);
uniform vec3 sheen : source_color = vec3(0.62, 0.68, 0.48);
uniform float ripple = 1.0;
// Where the shell grass ends: the ground stands for it beyond.
uniform float reach = 32.0;
// How much of the turf seen from afar is the strands' lit sides
// rather than the shade between them.
uniform float lit_share = 0.55;
// The turf seen from afar against the shells' look up close: the share
// of shade the eye sees between the strands darkens it.
uniform float turf_tone = 0.5;
// The leaning grass's pale side as seen from afar, through the same
// shade: the sheen at this share.
uniform float sheen_far = 0.25;

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	vec2 p = world_pos.xz;
	// The turf's own patches: drier and fresher drifts, and its grain at
	// every scale, so a far hillside is never a lawn.
	float dry = smoothstep(0.45, 0.85, value_noise(p * 0.08) * 0.7 + value_noise(p * 0.31 + 4.0) * 0.3);
	vec3 c = mix(green, yellow_green, 0.35 + 0.3 * value_noise(p * 0.6 + 3.0));
	c = mix(c, seed_tan, dry * 0.45);
	vec3 turf = mix(root_dark, c, lit_share) * turf_tone;
	// The grain fades with distance before it is finer than a pixel.
	float fine = 1.0 - smoothstep(60.0, 300.0, dist);
	turf *= 0.8 + 0.25 * value_noise(p * 0.05 + 7.0) + (0.15 * value_noise(p * 0.4) + 0.1 * value_noise(p * 2.5)) * fine
		+ 0.125 * (1.0 - fine);
	// Underfoot: the shade at the turf's roots.
	vec3 floor_col = root_dark * (0.8 + 0.4 * value_noise(p * 3.0 + 2.0));
	float seen = smoothstep(reach * 0.55, reach, dist);
	vec3 col = mix(floor_col, turf, seen);
	// The gusts, as on the shells.
	float gust = gust_at(p);
	col = mix(col, sheen * mix(1.0, sheen_far, seen), clamp(ripple * gust * 0.6 * seen, 0.0, 1.0));
	col *= 0.85 + 0.15 * smoothstep(0.0, 0.3, gust) + 0.25 * ripple * gust * seen;
	ALBEDO = col;
	ROUGHNESS = 0.9;
	SPECULAR = 0.15;
	BACKLIGHT = col * 0.3 * seen;
}
