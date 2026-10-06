// Shared shapes and noise for the Shifting Room's ornamented rear wall:
// the carving drawn once (ornament_static.gdshader), the frieze drawn each
// frame (ornament_frieze.gdshader) and the wall that shows them
// (ornament_wall.gdshader). Lengths are metres of wall.

// Material numbers, kept in the pictures as (number + 0.5) / 16.
const float M_STONE = 0.0;
const float M_MARBLE = 1.0;
const float M_WOOD = 2.0;
const float M_SILVER = 3.0;
const float M_GOLD = 4.0;
const float M_LAPIS = 5.0;
const float M_VELLUM = 6.0;
const float M_INK = 7.0;
const float M_RED = 8.0;
const float M_BLUE = 9.0;
const float M_BLACK = 10.0;
const float M_STAR = 12.0;

// Pseudo-random 0..1 (Dave Hoskins' hashes).
float o_hash(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

vec2 o_hash2(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * vec3(0.1031, 0.1030, 0.0973));
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.xx + p3.yz) * p3.zy);
}

float o_noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(o_hash(i), o_hash(i + vec2(1.0, 0.0)), u.x),
		mix(o_hash(i + vec2(0.0, 1.0)), o_hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float o_fbm(vec2 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += o_noise(p) * amp;
		norm += amp;
		p = p * 2.03 + vec2(17.1, 5.3);
		amp *= 0.5;
	}
	return sum / norm;
}

// Signed distance to a box of half-size b centred at the origin.
float o_box(vec2 p, vec2 b) {
	vec2 d = abs(p) - b;
	return length(max(d, vec2(0.0))) + min(max(d.x, d.y), 0.0);
}

// Distance to the segment a-b, and how far along it (0..1).
vec2 o_segment(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
	return vec2(length(pa - ba * h), h);
}

// 0 outside a shape (signed distance d), rising to 1 over w inside it: a
// bevelled edge.
float o_bevel(float d, float w) {
	return smoothstep(0.0, 1.0, clamp(-d / w, 0.0, 1.0));
}

// The height of a round rod of radius r at distance d from its middle line.
float o_rod(float d, float r) {
	return d < r ? sqrt(r * r - d * d) : 0.0;
}

// A pointed arch of span 2w (an equilateral arch: each side an arc of
// radius 2w about the opposite springing), springing at y = 0, with a
// straight-sided part of height `leg` below. Signed distance.
float o_arch(vec2 q, float w, float leg) {
	if (q.y > 0.0) {
		return max(length(q - vec2(w, 0.0)) - 2.0 * w, length(q + vec2(w, 0.0)) - 2.0 * w);
	}
	return o_box(q - vec2(0.0, -leg * 0.5), vec2(w, leg * 0.5));
}
