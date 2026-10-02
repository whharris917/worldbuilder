shader_type spatial;
// Shell grass: the ground round the camera drawn again in thin layers
// one above the other (GrassField's shell mesh, the layer's height up
// it in UV2.x, above 0 at the ground to 1 at the top; the ground itself
// is the turf's floor). Each layer keeps only
// the cross-sections of the strands that reach it: the ground is cut
// into small cells, each cell one strand of its own height, round and
// narrowing upward, so the stack of layers reads as a turf of fine
// blades. The layers slide downwind with the gusts, more the higher
// they are, and the gusts brighten the grass as they pass. Strands
// fall short toward the edge of the stack and where the ground grows
// no grass.
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
uniform float ripple = 0.6;

uniform vec3 green : source_color = vec3(0.22, 0.32, 0.11);
uniform vec3 yellow_green : source_color = vec3(0.40, 0.44, 0.18);
uniform vec3 seed_tan : source_color = vec3(0.56, 0.50, 0.33);
uniform vec3 root_dark : source_color = vec3(0.06, 0.08, 0.03);

varying vec2 ground_xz;    // where the strand stands, before the wind moves the layer
varying float layer;
varying float growth;
varying float gust;

float gust_at(vec2 p, vec2 wd, float speed) {
	return value_noise(p * 0.05 - wd * TIME * speed * 0.05) * 0.65
		+ value_noise(p * 0.17 - wd * TIME * speed * 0.17) * 0.35;
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
	float speed = 2.5 + 4.0 * wind;
	float wave = gust_at(w.xz, wd, speed);
	gust = smoothstep(0.3, 0.8, wave) * (0.3 + 0.7 * wind);
	vec2 sway = wd * wind * (0.15 + 0.6 * wave * wave);
	vec2 away = w.xz - player_pos.xz;
	float near_leg = (1.0 - smoothstep(0.3, 1.0, length(away))) * (1.0 - smoothstep(1.2, 2.0, abs(w.y - player_pos.y)));
	sway += normalize(away + vec2(0.001)) * near_leg * 0.8;
	w.xz += sway * layer * layer * grass_height * growth;
	w.y = g.r + h + 0.01;
	VERTEX = w - MODEL_MATRIX[3].xyz;
	NORMAL = vec3(0.0, 1.0, 0.0);
}

void fragment() {
	if (growth < 0.04) {
		discard;
	}
	vec2 cell = ground_xz * strands;
	vec2 id = floor(cell);
	float h = hash2(id);
	float tall = mix(0.35, 1.0, h);
	if (layer > tall) {
		discard;
	}
	// A flat blade in section, turned its own way, narrowing to a
	// point at the strand's own top.
	vec2 off = vec2(hash2(id + 17.0), hash2(id + 31.0)) - 0.5;
	vec2 d = fract(cell) - 0.5 - off * 0.3;
	float a = hash2(id + 43.0) * 3.1416;
	vec2 along = vec2(cos(a), sin(a));
	float r = length(vec2(dot(d, along), dot(d, vec2(-along.y, along.x)) * 3.0));
	if (r > 0.6 * pow(max(1.0 - layer / tall, 0.0), 0.6)) {
		discard;
	}
	float dry = smoothstep(0.45, 0.85, value_noise(ground_xz * 0.08) * 0.7 + value_noise(ground_xz * 0.31 + 4.0) * 0.3);
	vec3 c = mix(green, yellow_green, hash2(id + 5.0));
	c = mix(c, seed_tan, dry * 0.45);
	vec3 col = mix(root_dark, c, smoothstep(0.0, 0.45, layer));
	col = mix(col, yellow_green, 0.3 * smoothstep(0.6, 1.0, layer / tall));
	col *= 1.0 + ripple * gust * layer;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = col * 0.5;
	AO = mix(0.6, 1.0, layer);
	AO_LIGHT_AFFECT = 0.3;
}
