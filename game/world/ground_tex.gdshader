shader_type spatial;
// The ground outside the one-bulb room: a library material laid flat by
// world position (x and z in metres), with two remedies for a small tile
// repeated over a large ground. Breaking up the tiling: the maps are read
// twice, the second copy 2.7 times larger and turned 37 degrees, and
// noise about 9 m across chooses between them, so no repeat lines up.
// Variation: broad patches, 6 to 40 m across, move the colour toward a
// drier yellow or a deeper green and the brightness up and down.

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D rough_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D ao_tex : hint_default_white, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool use_albedo = false;
uniform bool use_normal = false;
uniform bool use_rough = false;
uniform bool use_ao = false;
uniform vec3 base_color : source_color = vec3(0.5);
uniform vec2 tile_m = vec2(1.4);            // metres one copy of the image covers
uniform float normal_strength = 1.0;
uniform float roughness_scale = 1.0;
uniform float specular = 0.5;            // head-on reflectance, 0.5 = 4%
uniform float brightness = 1.0;
uniform float variation = 0.6;              // 0 none, 1 full
uniform float break_tiling = 1.0;           // 0 off, 1 on

varying vec2 ground;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

void vertex() {
	ground = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	const float TURN = 0.6458;              // 37 degrees
	mat2 turn = mat2(vec2(cos(TURN), sin(TURN)), vec2(-sin(TURN), cos(TURN)));
	vec2 uv1 = ground / tile_m;
	vec2 uv2 = turn * ground / (tile_m * 2.7) + vec2(0.31, 0.57);
	float pick = smoothstep(0.3, 0.7, noise(ground / 9.0)) * break_tiling;

	vec3 albedo = base_color;
	if (use_albedo) {
		albedo = mix(texture(albedo_tex, uv1).rgb, texture(albedo_tex, uv2).rgb, pick);
	}
	float dry = noise(ground / 23.0 + 7.3) * 0.7 + noise(ground / 41.0 - 2.9) * 0.3;
	float lush = noise(ground / 6.0 - 3.1);
	dry = smoothstep(0.25, 0.75, dry);
	vec3 tint = mix(vec3(0.72, 0.92, 0.62), vec3(1.35, 1.12, 0.62), dry) * (0.7 + 0.6 * lush);
	ALBEDO = albedo * mix(vec3(1.0), tint, variation) * brightness;

	float rough = 1.0;
	if (use_rough) {
		rough = mix(texture(rough_tex, uv1).r, texture(rough_tex, uv2).r, pick);
	}
	ROUGHNESS = clamp(rough * roughness_scale, 0.0, 1.0);
	SPECULAR = specular;
	if (use_ao) {
		AO = mix(texture(ao_tex, uv1).r, texture(ao_tex, uv2).r, pick);
	}
	if (use_normal) {
		vec3 n1 = texture(normal_tex, uv1).xyz * 2.0 - 1.0;
		vec3 n2 = texture(normal_tex, uv2).xyz * 2.0 - 1.0;
		// The second copy is turned: turn its slopes back into the first's axes.
		n2.xy = transpose(turn) * n2.xy;
		NORMAL_MAP = normalize(mix(n1, n2, pick)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = normal_strength;
	}
}
