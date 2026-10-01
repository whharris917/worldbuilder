shader_type spatial;
// Meadow grass: tufts of blades, each blade a tapered strip, drawn by
// GrassField in tiles round the camera. A tuft stands on the ground
// read from a data texture (red: height; green: how tall the grass
// grows there; blue: where flowers may bloom), turned and sized by a
// hash of where it stands, so the same tile repeated never repeats.
// Tufts thin out with distance at one rate whatever tile mesh carries
// them, so tiles of different density meet without a seam.
//
// The wind runs over the meadow in gusts: a pattern travelling
// downwind bends the blades, a faster flutter on top, the world's
// gust strength scaling both. The player parts the grass. Light comes
// through the blades from behind (backlight), and their roots sit in
// their own shade.
render_mode cull_disabled;
#include "res://world/granite.gdshaderinc"

uniform sampler2D ground : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-128.0);
uniform float ground_size = 256.0;
uniform float band_density = 14.0;  // tufts a square metre in this tile mesh
uniform float full_density = 14.0;  // tufts a square metre close to the camera
uniform float full_r = 6.0;         // out to here, full density
uniform float grass_far = 58.0;     // where the last tuft is gone
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.3;           // 0 still to 1 a gale: the gusts' strength now

uniform vec3 green : source_color = vec3(0.22, 0.32, 0.11);
uniform vec3 yellow_green : source_color = vec3(0.40, 0.44, 0.18);
uniform vec3 seed_tan : source_color = vec3(0.56, 0.50, 0.33);
uniform vec3 root_dark : source_color = vec3(0.06, 0.08, 0.03);

varying vec3 blade_col;
varying float tip;
varying float flower;

vec2 rot(vec2 v, float a) {
	float c = cos(a);
	float s = sin(a);
	return vec2(c * v.x - s * v.y, s * v.x + c * v.y);
}

void vertex() {
	vec3 root = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	vec2 guv = (root.xz - ground_origin) / ground_size;
	vec4 g = textureLod(ground, guv, 0.0);
	float inside = step(0.0, guv.x) * step(guv.x, 1.0) * step(0.0, guv.y) * step(guv.y, 1.0);
	float r1 = hash2(root.xz * 1.37 + 0.5);
	float r2 = hash2(root.xz * 2.11 + 7.0);
	float r3 = hash2(root.xz * 0.73 + 13.0);

	// Thinning with distance, the same for every tile mesh: a tuft lives
	// while its rank is under the share this mesh must keep here.
	float dist = length(root.xz - CAMERA_POSITION_WORLD.xz);
	float target = min(full_density, full_density * pow(full_r / max(dist, 0.1), 1.5))
		* (1.0 - smoothstep(grass_far - 12.0, grass_far, dist));
	float keep = clamp(target / band_density, 0.0, 1.0);
	float alive = clamp((keep - r1) / 0.12, 0.0, 1.0);
	// Thinner tufts far off stand for more grass: a little wider.
	float spread = sqrt(band_density / full_density);

	tip = UV.y;
	float is_flower = COLOR.g;
	float is_head = COLOR.b;
	// Flowers: four kinds, each in its own drifts; elsewhere the flower
	// stem is not there.
	float daisy = value_noise(root.xz * 0.09 + 3.0);
	float butter = value_noise(root.xz * 0.11 + 17.0);
	float hawk = value_noise(root.xz * 0.07 + 31.0);
	float lupine = value_noise(root.xz * 0.05 + 47.0);
	float best = max(max(daisy, butter), max(hawk, lupine));
	float blooms = g.b * smoothstep(0.62, 0.74, best) * step(r3, 0.35);
	vec3 petal = lin(vec3(0.86, 0.85, 0.80));
	if (best == butter) {
		petal = lin(vec3(0.90, 0.76, 0.16));
	} else if (best == hawk) {
		petal = lin(vec3(0.82, 0.44, 0.12));
	} else if (best == lupine) {
		petal = lin(vec3(0.46, 0.38, 0.70));
	}
	float shown = mix(1.0, blooms, is_flower);
	flower = is_head;

	float height = g.g * (0.45 + 0.8 * r2) * alive * inside * shown;
	vec3 v = VERTEX;
	v.y *= height;
	v.xz *= mix(0.5, 1.0, clamp(height * 2.0, 0.0, 1.0)) * spread;
	// Turn the tuft by its own hash.
	float turn = r1 * 6.2832 + r2 * 3.0;
	v.xz = rot(v.xz, turn);
	vec3 n = NORMAL;
	n.xz = rot(n.xz, turn);
	float bh = max(v.y, 0.0);
	float t2 = UV.y * UV.y;

	// Wind: gusts travelling downwind across the meadow, and a flutter.
	vec2 wd = normalize(wind_dir);
	float speed = 2.5 + 4.0 * wind;
	float wave = value_noise(root.xz * 0.05 - wd * TIME * speed * 0.05) * 0.65
		+ value_noise(root.xz * 0.17 - wd * TIME * speed * 0.17) * 0.35;
	float bend = wind * (0.25 + 1.1 * wave * wave);
	float flutter = sin(TIME * (5.0 + 3.0 * COLOR.r) + root.x * 1.3 + root.z * 0.9 + COLOR.r * 6.28)
		* (0.04 + 0.08 * wind);
	vec2 sway = wd * (bend * 0.9 + flutter) + vec2(-wd.y, wd.x) * flutter * 0.5;
	// Parted by the player's legs.
	vec2 away = root.xz + v.xz - player_pos.xz;
	float near_leg = (1.0 - smoothstep(0.25, 0.9, length(away))) * (1.0 - smoothstep(1.2, 2.0, abs(root.y - player_pos.y)));
	sway += normalize(away + vec2(0.001)) * near_leg * 1.2;
	vec2 push = sway * t2 * bh;
	v.xz += push;
	// A bent blade is shorter, not longer.
	v.y -= min(length(push) * 0.5, bh * 0.6) * UV.y;
	v.y += g.r;
	VERTEX = v;
	// Lit as a mass more than as strips: the blade's normal leans up.
	NORMAL = normalize(mix(n, vec3(0.0, 1.0, 0.0), 0.55));

	// The blade's colour: green in the drifts of fresh growth, seeding tan
	// in the dry ones, each blade its own shade, the tips lighter.
	float dry = smoothstep(0.45, 0.85, value_noise(root.xz * 0.08) * 0.7 + value_noise(root.xz * 0.31 + 4.0) * 0.3);
	vec3 c = mix(green, yellow_green, COLOR.r);
	c = mix(c, seed_tan, (0.2 + 0.8 * dry) * step(0.6, fract(COLOR.r * 7.3)) * 0.8);
	c *= 0.85 + 0.3 * r3;
	blade_col = mix(c, petal, is_head);
	if (is_flower > 0.5 && is_head < 0.5) {
		blade_col = green * 0.8;
	}
}

void fragment() {
	// The roots stand in the tuft's own shade.
	float shade = mix(0.25, 1.0, smoothstep(0.0, 0.7, tip));
	vec3 col = mix(root_dark, blade_col, shade);
	col = mix(col, blade_col, flower);
	ALBEDO = col;
	ROUGHNESS = 0.75;
	SPECULAR = 0.3;
	BACKLIGHT = col * 0.7;
	AO = mix(0.4, 1.0, tip);
	AO_LIGHT_AFFECT = 0.3;
}
