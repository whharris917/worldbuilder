shader_type spatial;
// The cut edge of the diorama's board: the land seen in section, as a
// model maker leaves it. UV.y is metres below the ground's surface, so
// the layers follow the land: a band of turf, dark topsoil with pebbles,
// a paler clay in wavy strata, then stony subsoil to the base.
#include "res://world/granite.gdshaderinc"

uniform vec3 turf : source_color = vec3(0.50, 0.70, 0.34);
uniform vec3 topsoil : source_color = vec3(0.42, 0.30, 0.22);
uniform vec3 clay : source_color = vec3(0.70, 0.54, 0.38);
uniform vec3 subsoil : source_color = vec3(0.56, 0.50, 0.46);

varying vec2 at;

void vertex() {
	at = UV;
}

void fragment() {
	float below = at.y + 0.25 * sin(at.x * 0.21) + 0.15 * sin(at.x * 0.57 + 1.0);
	vec3 col = turf;
	if (at.y > 0.3) {
		col = topsoil;
		col = mix(col, subsoil * 1.2, step(0.86, value_noise(at * vec2(3.0, 6.0))));
	}
	if (below > 1.6) {
		col = mix(clay, clay * 0.85, step(0.5, fract(below * 1.4)));
	}
	if (below > 4.2) {
		col = subsoil * (0.9 + 0.2 * step(0.7, value_noise(at * 2.5)));
	}
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.05;
}
