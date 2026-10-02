shader_type spatial;
// A cartoon outline: the surface drawn again a little larger, its back
// faces only, in flat ink, so a dark line shows round its silhouette.
// The line keeps about the same width on screen near and far. Swayed
// as its surface is (toon_sway.gdshaderinc).
render_mode unshaded, cull_front, shadows_disabled;
#include "res://world/toon_sway.gdshaderinc"

uniform vec3 ink : source_color = vec3(0.10, 0.09, 0.08);
uniform float width = 0.0016;      // the line's width, as a share of the distance to it
uniform float far_fade = 400.0;    // past here the line thins away

void vertex() {
	vec3 v = swayed(VERTEX, MODEL_MATRIX, TIME);
	vec3 world = (MODEL_MATRIX * vec4(v, 1.0)).xyz;
	vec3 n = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	float dist = length(world - CAMERA_POSITION_WORLD);
	world += n * (0.02 + dist * width) * (1.0 - smoothstep(far_fade * 0.5, far_fade, dist));
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	ALBEDO = ink;
}
