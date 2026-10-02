shader_type spatial;
// A tree part painted in the anime manner: soft two-tone light whose
// edge between lit and shade wobbles with a noise over the crown, so a
// smooth ball reads as clumps of foliage brushed in; the colour varies
// a little across it. Sways with the wind (toon_sway.gdshaderinc).
#include "res://world/granite.gdshaderinc"
#include "res://world/toon_sway.gdshaderinc"

uniform vec3 tint = vec3(1.0);
uniform bool srgb_colors = true;
uniform float wobble_amount = 0.9;  // how far the light's edge wanders (0 for trunks and stones)

varying vec3 col;
varying vec3 wpos;
varying float wobble;

void vertex() {
	col = (srgb_colors ? pow(COLOR.rgb, vec3(2.2)) : COLOR.rgb) * tint;
	VERTEX = swayed(VERTEX, MODEL_MATRIX, TIME);
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float n = value_noise(wpos.xz * 0.8 + wpos.y * 0.7) * 0.6 + value_noise(wpos.xz * 2.2 - wpos.y * 1.9) * 0.4;
	wobble = (n - 0.5) * wobble_amount;
	ALBEDO = col * (0.9 + 0.2 * value_noise(wpos.xz * 0.7 + wpos.y * 0.5));
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
}

void light() {
	float ndl = dot(NORMAL, LIGHT) + wobble;
	float shadow = smoothstep(0.2, 0.8, ATTENUATION);
	float lit = smoothstep(-0.05, 0.25, ndl) * shadow;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	float rim = smoothstep(0.6, 0.8, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * smoothstep(0.0, 0.3, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * shadow * 0.25 / PI;
}
