// Rough stone made from noise in world space: no picture, so it never
// repeats, and since the noise is three-dimensional it needs no
// projecting onto faces and runs on round any curved surface. Used by the
// Shifting Room's front wall (rough_stone.gdshader) and the stone of its
// eye's patch (eye_wall.gdshader), which meet without a seam because both
// read the same world positions.
//
// The stone: a weathered grey-brown, clouded at a few metres' scale and
// faintly mottled at a hand's, with a fine dark grain; its face is rough at
// every scale, swelling over most of a metre, knobbled at a quarter, pitted
// at a few centimetres and grainy below that, the pits darker. The knobs
// and pits are steep enough to show even in light falling nearly straight
// on. `stone_height` is the
// relief in metres, for bump shading; colours are written as sRGB and put
// through stone_lin, since a literal in a shader is linear.

vec3 stone_lin(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

// A pseudo-random 0..1 for each noise point (Dave Hoskins' hash13). A
// product-of-coordinates hash gave nearly 0 to every point in a plane
// where one coordinate came out near 0, drawing a line of pits across the
// wall.
float stone_hash(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float stone_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(mix(stone_hash(i), stone_hash(i + vec3(1, 0, 0)), u.x),
			mix(stone_hash(i + vec3(0, 1, 0)), stone_hash(i + vec3(1, 1, 0)), u.x), u.y),
		mix(mix(stone_hash(i + vec3(0, 0, 1)), stone_hash(i + vec3(1, 0, 1)), u.x),
			mix(stone_hash(i + vec3(0, 1, 1)), stone_hash(i + vec3(1, 1, 1)), u.x), u.y), u.z);
}

// Octaves of noise, each twice as fine and half as strong; 0 to 1.
float stone_fbm(vec3 p, int octaves) {
	float sum = 0.0;
	float amp = 0.5;
	float norm = 0.0;
	for (int i = 0; i < octaves; i++) {
		sum += stone_noise(p) * amp;
		norm += amp;
		p = p * 2.03 + vec3(17.1, 5.3, 11.7);
		amp *= 0.5;
	}
	return sum / norm;
}

// How deep in a pit, 0 to 1: where the centimetre-scale noise is low.
float stone_pit(vec3 wp) {
	return smoothstep(0.42, 0.25, stone_fbm(wp * 14.0 + vec3(7.0), 2));
}

float stone_height(vec3 wp) {
	float swell = stone_fbm(wp * 1.2, 2) * 0.05;
	float knobs = stone_fbm(wp * 4.0 + vec3(3.0), 3) * 0.045;
	float grain = stone_noise(wp * 60.0) * 0.002;
	return swell + knobs + grain - stone_pit(wp) * 0.008;
}

vec3 stone_albedo(vec3 wp) {
	float cloud = stone_fbm(wp * 0.3, 3);
	float mottle = stone_fbm(wp * 4.0 + vec3(3.0), 2);
	float grain = stone_noise(wp * 45.0);
	vec3 c = mix(stone_lin(vec3(0.42, 0.40, 0.37)), stone_lin(vec3(0.50, 0.47, 0.43)), smoothstep(0.3, 0.7, cloud));
	c *= 0.93 + 0.14 * mottle;
	c = mix(c, stone_lin(vec3(0.24, 0.23, 0.21)), smoothstep(0.75, 0.92, grain) * 0.4);
	c *= 1.0 - 0.35 * stone_pit(wp);
	return c;
}

float stone_roughness(vec3 wp) {
	return 0.82 + 0.12 * stone_fbm(wp * 5.0 + vec3(9.0), 2);
}

// The surface normal (view space) tilted by the relief `h`, from how h and
// the surface position change from pixel to pixel (Mikkelsen's bump
// mapping from screen derivatives).
vec3 stone_bump(vec3 n, vec3 view_pos, float h) {
	vec3 dpdx = dFdx(view_pos);
	vec3 dpdy = dFdy(view_pos);
	vec3 r1 = cross(dpdy, n);
	vec3 r2 = cross(n, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(h) * r1 + dFdy(h) * r2);
	return normalize(abs(det) * n - grad);
}
