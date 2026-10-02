shader_type spatial;
// The diorama's ground: the terrain's own coarse triangles lit flat,
// in pastel colours by what the ground is (vertex colour as
// meadow_ground.gdshader: red the bed, green the forest floor, blue
// the meadow), each grid square a shade of its own, as a painted model
// is.
#include "res://world/granite.gdshaderinc"

uniform vec3 meadow : source_color = vec3(0.56, 0.76, 0.38);
uniform vec3 meadow_light : source_color = vec3(0.68, 0.82, 0.42);
uniform vec3 wood_floor : source_color = vec3(0.42, 0.58, 0.34);
uniform vec3 earth : source_color = vec3(0.74, 0.58, 0.42);
uniform vec3 sand : source_color = vec3(0.90, 0.82, 0.64);
uniform float square = 2.5;      // the terrain's grid, for a shade per square

varying vec3 world_pos;
varying vec3 tint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	tint = COLOR.rgb;
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, -VERTEX) < 0.0) {
		n = -n;
	}
	NORMAL = n;
	vec3 wn = (INV_VIEW_MATRIX * vec4(n, 0.0)).xyz;
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	vec2 cell = floor(world_pos.xz / square);
	float jitter = hash2(cell) - 0.5;
	float patch = step(0.55, value_noise(world_pos.xz * 0.04));
	vec3 field = mix(meadow, meadow_light, patch);
	vec3 color = mix(wood_floor, field, smoothstep(0.3, 0.6, tint.b * (1.0 - tint.g * 0.6)));
	color = mix(color, earth, step(0.45, slope) * (1.0 - tint.r));
	color = mix(color, sand, step(0.5, tint.r));
	ALBEDO = color * (1.0 + 0.08 * jitter);
	ROUGHNESS = 0.9;
	SPECULAR = 0.1;
}
