shader_type spatial;
// The meadow's ground drawn as a cartoon: flat fields of colour, the
// meadow a bright green laid in two tones in broad soft-edged patches,
// the wood's floor a deeper green, the banks a warm earth, the brook's
// bed sand. Vertex colour as meadow_ground.gdshader: red the bed,
// green the forest floor, blue the meadow. Flat-lit (toon.gdshaderinc).
#include "res://world/granite.gdshaderinc"
#include "res://world/toon.gdshaderinc"

uniform vec3 meadow : source_color = vec3(0.32, 0.56, 0.18);
uniform vec3 meadow_light : source_color = vec3(0.46, 0.66, 0.22);
uniform vec3 wood_floor : source_color = vec3(0.24, 0.40, 0.16);
uniform vec3 earth : source_color = vec3(0.60, 0.42, 0.24);
uniform vec3 sand : source_color = vec3(0.82, 0.72, 0.50);

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 tint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	tint = COLOR.rgb;
}

void fragment() {
	vec2 p = world_pos.xz;
	float slope = 1.0 - clamp(normalize(world_normal).y, 0.0, 1.0);
	float patch = smoothstep(0.52, 0.56, value_noise(p * 0.045) * 0.7 + value_noise(p * 0.16 + 4.0) * 0.3);
	vec3 field = mix(meadow, meadow_light, patch);
	vec3 color = mix(wood_floor, field, smoothstep(0.3, 0.6, tint.b * (1.0 - tint.g * 0.6)));
	color = mix(color, earth, smoothstep(0.3, 0.4, slope) * (1.0 - tint.r));
	color = mix(color, sand, smoothstep(0.4, 0.6, tint.r));
	ALBEDO = color;
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}
