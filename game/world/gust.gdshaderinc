// The wind's gusts over grass: long bands lying across the wind,
// narrow along it, carried downwind at gust_speed in a calm and faster
// with the wind, drifting slowly across it so they never repeat. Shared
// by the shell grass and the hills' ground so near and far gusts are
// the same gusts, and matched on the CPU by Gusts (gusts.gd), whose
// constants are these defaults, for what the ear hears. The pattern is
// built from an integer hash so the CPU's copy gives the same bands.

uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.3;            // 0 still to 1 a gale: the breeze now
uniform float gust_travel = 0.0;     // how far the gusts have run: the sum over time of 1 + 1.5 * wind (GrassField)
uniform float gust_speed = 1.2;      // metres a second the gusts run downwind, in a calm
uniform float band_length = 30.0;    // a gust band's length across the wind, metres
uniform float band_width = 6.0;      // and its width along it

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

// The gust at a point on the ground: 0 between bands to 0.45-1 (with
// the breeze) at a band's crest.
float gust_at(vec2 p) {
	vec2 wd = normalize(wind_dir);
	vec2 across = vec2(-wd.y, wd.x);
	float run = gust_travel * gust_speed;
	float u = (dot(p, wd) - run) / band_width;
	float v = (dot(p, across) + run * 0.25) / band_length;
	float bands = gust_noise(vec2(u, v)) * 0.75 + gust_noise(vec2(u * 2.3, v * 1.7) + 11.0) * 0.25;
	return smoothstep(0.38, 0.62, bands) * (0.45 + 0.55 * wind);
}
