// The wind's gusts over grass: long bands lying across the wind,
// narrow along it, shared by the shell grass and the hills' ground so
// near and far gusts are the same gusts, and matched on the CPU by
// Gusts (gusts.gd), whose constants are these defaults, for what the ear
// hears. The pattern is built from an integer hash so the CPU's copy
// gives the same bands.
//
// The bands do not all run one way. Each point has its own flow: the
// prevailing wind, plus a pull down the local slope (flow_map, baked from
// the land, where a world gives one), plus eddies that wander slowly; its
// length is the local speed, so gusts quicken running downhill and
// slacken climbing. The pattern is carried along that flow as a flow map
// carries water: two copies, each displaced along the local flow by an
// amount that grows through a cycle and then starts again from a fresh
// part of the pattern, cross-faded so neither restart shows. Carried
// this way the bands bend and swirl locally without being dragged out
// of shape over distance.

uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.3;            // 0 still to 1 a gale: the breeze now
uniform float gust_travel = 0.0;     // how far the gusts have run: the sum over time of 1 + 1.5 * wind (GrassField)
uniform float gust_speed = 1.2;      // metres a second the gusts run downwind, in a calm
uniform float band_length = 30.0;    // a gust band's length across the wind, metres
uniform float band_width = 6.0;      // and its width along it
uniform sampler2D flow_map : filter_linear, repeat_disable;   // the downhill pull, metres a metre of run, RG
uniform vec2 flow_origin = vec2(-1024.0);
uniform float flow_size = 2048.0;
uniform float use_flow = 0.0;        // 1 where a world gives a flow map
uniform float eddy = 0.9;            // how far the eddies turn the flow
uniform float eddy_size = 45.0;      // their size, metres
uniform float warp = 12.0;           // how far the bands' shapes are bent, metres

const float GUST_CYCLE = 24.0;       // metres of run before a copy of the pattern starts again

float gust_hash(ivec2 c) {
	uint v = uint(c.x) * 1597334677u ^ uint(c.y) * 3812015801u;
	v = v * 747796405u + 2891336453u;
	v = ((v >> ((v >> 28u) + 4u)) ^ v) * 277803737u;
	v = (v >> 22u) ^ v;
	return float(v) / 4294967295.0;
}

float gust_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = p - i;
	vec2 u = f * f * (3.0 - 2.0 * f);
	ivec2 c = ivec2(i);
	return mix(mix(gust_hash(c), gust_hash(c + ivec2(1, 0)), u.x),
		mix(gust_hash(c + ivec2(0, 1)), gust_hash(c + ivec2(1, 1)), u.x), u.y);
}

// The flow at p: which way and how fast, relative to the gusts' speed,
// the bands run there.
vec2 gust_flow(vec2 p) {
	vec2 wd = normalize(wind_dir);
	vec2 down = use_flow > 0.5 ? textureLod(flow_map, (p - flow_origin) / flow_size, 0.0).rg : vec2(0.0);
	float t = gust_travel * gust_speed;
	// Eddies at two sizes, each wandering on its own.
	vec2 e = vec2(gust_noise(p / eddy_size + vec2(t * 0.022, 3.0)),
		gust_noise(p / eddy_size + vec2(17.0, -t * 0.018))) - 0.5;
	vec2 e2 = vec2(gust_noise(p / (eddy_size * 0.4) + vec2(-t * 0.05, 41.0)),
		gust_noise(p / (eddy_size * 0.4) + vec2(53.0, t * 0.043))) - 0.5;
	vec2 f = wd + down + (e * 2.0 + e2) * eddy;
	float len = length(f);
	return f / max(len, 1e-4) * clamp(len, 0.15, 2.2);
}

// The bands' pattern, fixed in the prevailing wind's frame.
float gust_pattern(vec2 q) {
	vec2 wd = normalize(wind_dir);
	vec2 across = vec2(-wd.y, wd.x);
	// The bands bent and broken, so they are never straight strips.
	q += (vec2(gust_noise(q / 35.0 + 5.0), gust_noise(q / 35.0 + 29.0)) - 0.5) * 2.0 * warp;
	float u = dot(q, wd) / band_width;
	float v = dot(q, across) / band_length;
	return gust_noise(vec2(u, v)) * 0.75 + gust_noise(vec2(u * 2.3, v * 1.7) + 11.0) * 0.25;
}

// The gust at a point on the ground: 0 between bands to 0.45-1 (with
// the breeze) at a band's crest.
float gust_at(vec2 p) {
	vec2 f = gust_flow(p);
	float c = gust_travel * gust_speed / GUST_CYCLE;
	float b = 0.0;
	float w2 = 0.0;
	for (int k = 0; k < 2; k++) {
		float ck = c + 0.5 * float(k);
		float cycle = floor(ck);
		float s = (ck - cycle) * GUST_CYCLE;
		// Each cycle starts from its own far part of the pattern.
		vec2 jump = vec2(gust_hash(ivec2(int(cycle), k)), gust_hash(ivec2(k, int(cycle)) + 7)) * 4000.0;
		float w = 1.0 - abs(2.0 * (ck - cycle) - 1.0);
		b += (gust_pattern(p - f * s + jump) - 0.5) * w;
		w2 += w * w;
	}
	// Two patterns averaged are greyer than one: restore the contrast.
	b = 0.5 + b / sqrt(max(w2, 1e-4));
	return smoothstep(0.38, 0.62, b) * (0.45 + 0.55 * wind);
}
