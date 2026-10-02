shader_type spatial;
// A low-poly model's surface in its instance's colour: every facet lit
// flat (its normal from the screen-space slope of the surface, so the
// mesh's smoothing is ignored), a soft matte paint. Sways with the wind
// (toon_sway.gdshaderinc). The diorama's trees, shrubs and stones.
#include "res://world/toon_sway.gdshaderinc"

uniform vec3 tint = vec3(1.0);
uniform bool srgb_colors = true;

varying vec3 col;

void vertex() {
	col = (srgb_colors ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb) * tint;
	VERTEX = swayed(VERTEX, MODEL_MATRIX, TIME);
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, -VERTEX) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.15;
}
