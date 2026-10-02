shader_type spatial;
// Shell grass: the ground round the camera drawn again in thin layers
// one above the other (GrassField's shell mesh, the layer's height up
// it in UV2.x, above 0 at the ground to 1 at the top; the ground itself
// is the turf's floor). Each layer keeps only
// the cross-sections of the strands that reach it: the ground is cut
// into small cells, each cell one strand of its own height, round and
// narrowing upward, so the stack of layers reads as a turf of fine
// blades. Gusts cross the field as long bands lying across the wind
// and running downwind: in a band the layers slide downwind, more the
// higher they are, so the grass leans, and the leaning grass turns
// pale as a field does when its blades bend and show their sheen;
// between bands it stands up and darker. Strands
// fall short toward the edge of the stack and where the ground grows
// no grass. Each strand stands anywhere in its own cell of a lattice
// and reaches at most half a cell from its foot, so a layer's pixel
// need look only at the four cells round its nearest corner; told
// apart by an integer hash, the strands form no rows to line up into
// stripes when looked along.
render_mode cull_disabled;
#include "res://world/granite.gdshaderinc"

uniform sampler2D ground : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-128.0);
uniform float ground_size = 256.0;
uniform vec3 player_pos = vec3(0.0, -1000.0, 0.0);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.3;
uniform float height_scale = 1.0;
uniform float grass_height = 0.7;    // the tallest strand at full growth, metres
uniform float strands = 18.0;        // strands a metre each way
uniform float reach = 32.0;          // strands are gone by here from the camera
uniform float ripple = 1.0;          // how pale the grass turns where a gust leans it
uniform float gust_speed = 1.2;      // how fast the gusts run downwind, metres a second, in a calm
uniform float band_length = 30.0;    // a gust band's length across the wind, metres
uniform float band_width = 6.0;      // and its width along it
uniform vec3 sheen : source_color = vec3(0.62, 0.68, 0.48);   // leaning grass's pale side
uniform float lattice_turn = 0.53;   // the lattice against the world's axes, radians

uniform vec3 green : source_color = vec3(0.22, 0.32, 0.11);
uniform vec3 yellow_green : source_color = vec3(0.40, 0.44, 0.18);
uniform vec3 seed_tan : source_color = vec3(0.56, 0.50, 0.33);
uniform vec3 root_dark : source_color = vec3(0.06, 0.08, 0.03);

varying vec2 ground_xz;    // where the strand stands, before the wind moves the layer
varying float layer;
varying float growth;
varying float gust;

// A strand's own random numbers, 0 to 1, from its cell and a salt.
float strand_hash(ivec2 c, uint salt) {
	uint v = uint(c.x) * 1597334677u ^ uint(c.y) * 3812015801u ^ salt * 2654435769u;
	v = v * 747796405u + 2891336453u;
	v = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u;
	v = (v >> 22u) ^ v;
	return float(v) / 4294967295.0;
}

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 guv = (w.xz - ground_origin) / ground_size;
	vec4 g = textureLod(ground, guv, 0.0);
	float inside = step(0.0, guv.x) * step(guv.x, 1.0) * step(0.0, guv.y) * step(guv.y, 1.0);
	layer = UV2.x;
	float dist = length(w.xz - CAMERA_POSITION_WORLD.xz);
	growth = g.g * inside * (1.0 - smoothstep(reach * 0.6, reach, dist));
	ground_xz = w.xz;
	float h = layer * grass_height * height_scale * growth;

	vec2 wd = normalize(wind_dir);
	// The gusts: a pattern in the wind's own frame, long across it and
	// narrow along it, carried downwind; a slow drift across the wind
	// keeps the bands from repeating. Even a light breeze shows them.
	float speed = gust_speed * (1.0 + 1.5 * wind);
	vec2 across = vec2(-wd.y, wd.x);
	float u = (dot(w.xz, wd) - TIME * speed) / band_width;
	float v = (dot(w.xz, across) + TIME * 0.3) / band_length;
	float bands = value_noise(vec2(u, v)) * 0.75 + value_noise(vec2(u * 2.3, v * 1.7) + 11.0) * 0.25;
	float strength = 0.45 + 0.55 * wind;
	gust = smoothstep(0.38, 0.62, bands) * strength;
	float flutter = sin(TIME * 2.1 + dot(w.xz, vec2(1.3, 0.9))) * 0.04;
	vec2 sway = wd * (0.08 * strength + 0.8 * gust + flutter * wind);
	vec2 away = w.xz - player_pos.xz;
	float near_leg = (1.0 - smoothstep(0.3, 1.0, length(away))) * (1.0 - smoothstep(1.2, 2.0, abs(w.y - player_pos.y)));
	sway += normalize(away + vec2(0.001)) * near_leg * 0.8;
	vec2 lean = sway * pow(layer, 1.4) * grass_height * growth;
	w.xz += lean;
	// A leaning blade reaches less high.
	w.y = g.r + h - length(lean) * 0.4 * layer + 0.01;
	VERTEX = w - MODEL_MATRIX[3].xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

// The strands at p: x positive where this layer is empty there, y the
// height of the strand found (0 to 1 of the stack), z its colour's
// random. A strand is a flat blade in section, turned its own way,
// narrowing to a point at its top; it may stand anywhere in its cell.
vec3 strand(vec2 p) {
	float ct = cos(lattice_turn);
	float st = sin(lattice_turn);
	vec2 cell = vec2(ct * p.x - st * p.y, st * p.x + ct * p.y) * strands;
	// The four cells round the nearest corner.
	vec2 corner = floor(cell + 0.5);
	vec3 best = vec3(1.0e3, 0.0, 0.0);
	ivec2 best_id = ivec2(corner);
	for (int j = -1; j <= 0; j++) {
		for (int i = -1; i <= 0; i++) {
			ivec2 id = ivec2(corner) + ivec2(i, j);
			// One hash, four bytes: height, where in the cell, the turn.
			uint v = uint(strand_hash(id, 1u) * 4294967295.0);
			vec4 b = vec4(float(v & 255u), float((v >> 8u) & 255u),
				float((v >> 16u) & 255u), float(v >> 24u)) / 255.0;
			float tall = mix(0.35, 1.0, b.x);
			if (layer > tall) {
				continue;
			}
			vec2 d = cell - (vec2(id) + b.yz);
			float a = b.w * 3.1416;
			vec2 along = vec2(cos(a), sin(a));
			float r = length(vec2(dot(d, along), dot(d, vec2(-along.y, along.x)) * 3.0));
			float gap = r - 0.5 * pow(max(1.0 - layer / tall, 0.0), 0.6);
			if (gap < best.x) {
				best = vec3(gap, tall, 0.0);
				best_id = id;
			}
		}
	}
	best.z = strand_hash(best_id, 5u);
	return best;
}

void fragment() {
	if (growth < 0.04) {
		discard;
	}
	vec3 hit = strand(ground_xz);
	if (hit.x > 0.0) {
		discard;
	}
	float tall = hit.y;
	float dry = smoothstep(0.45, 0.85, value_noise(ground_xz * 0.08) * 0.7 + value_noise(ground_xz * 0.31 + 4.0) * 0.3);
	vec3 c = mix(green, yellow_green, hit.z);
	c = mix(c, seed_tan, dry * 0.45);
	vec3 col = mix(root_dark, c, smoothstep(0.0, 0.45, layer));
	col = mix(col, yellow_green, 0.3 * smoothstep(0.6, 1.0, layer / tall));
	// Leaning grass turns pale from a little above the roots, where
	// most of what the eye sees of the turf is; standing grass is a
	// little darker.
	float tips = smoothstep(0.0, 0.3, layer);
	col = mix(col, sheen, clamp(ripple * gust * tips * 0.8, 0.0, 1.0));
	col *= 0.85 + 0.15 * smoothstep(0.0, 0.3, gust) + 0.35 * ripple * gust * tips;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.5;
	AO = mix(0.6, 1.0, layer);
	AO_LIGHT_AFFECT = 0.3;
}
