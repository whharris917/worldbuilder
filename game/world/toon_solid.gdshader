shader_type spatial;
// A cartoon surface in its instance's colour: the plain trees' trunks,
// cones and crowns, and the stones. Flat-lit (toon.gdshaderinc); the
// crowns and cones sway with the wind (toon_sway.gdshaderinc). Its
// outline is outline_hull.gdshader, as the next pass.
#include "res://world/toon.gdshaderinc"
#include "res://world/toon_sway.gdshaderinc"

uniform vec3 tint = vec3(1.0);     // multiplies the instance colour
uniform bool srgb_colors = true;   // instance colours picked as screen colours

varying vec3 col;

void vertex() {
	col = (srgb_colors ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb) * tint;
	VERTEX = swayed(VERTEX, MODEL_MATRIX, TIME);
}

void fragment() {
	ALBEDO = col;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
