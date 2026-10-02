shader_type spatial;
// Fluffy grass: each clump is a few upright cards crossed through its
// centre, every card cut into a fan of tapered blades in the fragment
// (no texture), drawn by GrassField in the same tiles and thinning as
// the blade grass. The cards are lit with the ground's normal, so a
// clump reads as one soft mass rather than as flat planes, and the
// wind shows mostly as light: the same gust pattern that leans the
// cards a little brightens the grass where it passes, so bands of
// light run downwind over the meadow as they do over a real field
// when the blades bend and show their sheen.
render_mode cull_disabled;
#include "res://world/granite.gdshaderinc"

uniform sampler2D ground : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-128.0);
uniform float ground_size = 256.0;
uniform float band_density = 3.0;
uniform float full_density = 3.0;
uniform float full_r = 7.0;
uniform float grass_far = 64.0;
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.3;
uniform float height_scale = 1.0;
uniform float blades_across = 20.0;  // blades cut into each card
uniform float ripple = 0.6;          // how much the passing gusts brighten the grass

uniform vec3 green : source_color = vec3(0.22, 0.32, 0.11);
uniform vec3 yellow_green : source_color = vec3(0.40, 0.44, 0.18);
uniform vec3 seed_tan : source_color = vec3(0.56, 0.50, 0.33);
uniform vec3 root_dark : source_color = vec3(0.06, 0.08, 0.03);

varying vec3 clump_col;
varying float gust;
varying float seed;

vec2 rot(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

// The gust pattern over the meadow at a point: 0 calm to 1 the crest.
float gust_at(vec2 p, vec2 wd, float speed) {
	return value_noise(p * 0.05 - wd * TIME * speed * 0.05) * 0.65
		+ value_noise(p * 0.17 - wd * TIME * speed * 0.17) * 0.35;
}

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 guv = (root.xz - ground_origin) / ground_size;
	vec4 g = textureLod(ground, guv, 0.0);
	float inside = step(0.0, guv.x) * step(guv.x, 1.0) * step(0.0, guv.y) * step(guv.y, 1.0);
	float r1 = hash2(root.xz * 1.37 + 0.5);
	float r2 = hash2(root.xz * 2.11 + 7.0);
	float r3 = hash2(root.xz * 0.73 + 13.0);
	seed = r3;

	float dist = length(root.xz - CAMERA_POSITION_WORLD.xz);
	float target = min(full_density, full_density * pow(full_r / max(dist, 0.1), 1.5))
		* (1.0 - smoothstep(grass_far - 12.0, grass_far, dist));
	float keep = clamp(target / band_density, 0.0, 1.0);
	float alive = clamp((keep - r1) / 0.12, 0.0, 1.0);
	float spread = sqrt(band_density / full_density);

	float height = g.g * (0.6 + 0.5 * r2) * alive * inside * height_scale;
	vec3 v = VERTEX;
	float up = UV.y;
	v.y *= height;
	v.xz *= mix(0.4, 1.0, clamp(height * 2.0 / height_scale, 0.0, 1.0)) * spread;
	v.xz = rot(v.xz, r1 * 6.2832 + r2 * 3.0);

	vec2 wd = normalize(wind_dir);
	float speed = 2.5 + 4.0 * wind;
	float wave = gust_at(root.xz, wd, speed);
	gust = smoothstep(0.3, 0.8, wave) * (0.3 + 0.7 * wind);
	// A slight lean with the gust and a slow nod: the light does the rest.
	float nod = sin(TIME * (1.6 + r2) + root.x * 0.7 + root.z * 0.5) * 0.03;
	vec2 sway = wd * (wind * (0.1 + 0.35 * wave * wave) + nod);
	vec2 away = root.xz + v.xz - player_pos.xz;
	float near_leg = (1.0 - smoothstep(0.3, 1.0, length(away))) * (1.0 - smoothstep(1.2, 2.0, abs(root.y - player_pos.y)));
	sway += normalize(away + vec2(0.001)) * near_leg * 0.9;
	v.xz += sway * up * up * max(v.y, 0.0);
	v.y += g.r;
	VERTEX = v;
	// Lit as the ground is lit: the clump is one mass.
	NORMAL = vec3(0.0, 1.0, 0.0);

	float dry = smoothstep(0.45, 0.85, value_noise(root.xz * 0.08) * 0.7 + value_noise(root.xz * 0.31 + 4.0) * 0.3);
	vec3 c = mix(green, yellow_green, r2 * 0.6);
	c = mix(c, seed_tan, dry * 0.35);
	clump_col = c * (0.85 + 0.3 * r3);
}

void fragment() {
	// The card cut into a fan of blades: each its own height, curving
	// over to one side, tapering to a point; the outer blades shorter so
	// the clump is rounded.
	float across = UV.x * blades_across;
	float id = floor(across);
	float h = hash2(vec2(id, seed * 91.0));
	float edge = abs(UV.x - 0.5) * 2.0;
	float top = (0.4 + 0.6 * h) * (1.0 - 0.45 * edge * edge);
	float lean = (h - 0.5) * 1.6 + (UV.x - 0.5) * 1.2;
	float fx = fract(across) - 0.5 - lean * UV.y * UV.y;
	float half_w = 0.45 * pow(max(1.0 - UV.y / top, 0.0), 0.9);
	ALPHA = step(abs(fx), half_w) * step(UV.y, top);
	ALPHA_SCISSOR_THRESHOLD = 0.5;

	float rise = UV.y / top;
	vec3 col = mix(root_dark, clump_col, smoothstep(0.0, 0.6, rise));
	col = mix(col, yellow_green, 0.15 * smoothstep(0.7, 1.0, rise));
	col *= 0.92 + 0.16 * h;
	// The gust's sheen, strongest at the tips that bend.
	col *= 1.0 + ripple * gust * rise;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.6;
	AO = mix(0.45, 1.0, rise);
	AO_LIGHT_AFFECT = 0.3;
}
