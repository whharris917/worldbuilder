#[compute]
#version 450

// The light pool's caustics: the picture carried by the spot light at the
// lamp that lights the room through the glass. Rays leave the lamp in
// every direction of that light's cone; each meets the glass's flat
// underside, is bent into the water (the glass is a parallel slab, so
// only the water's index counts), leaves through the rippled water
// surface, bent by Snell's law at the surface's normal there, and goes on
// to whichever it meets first of the ceiling and the four walls. The
// surface's slope is the two sliding ripple maps' plus the drops' rings,
// both read exactly as pool_glass.gdshader reads them.
//
// The direction from the lamp to where a ray lands is tallied in the
// light's picture. Every point of the room lies in one direction from the
// lamp, so the picture, thrown from the lamp, puts the light where the
// rays land, on the ceiling and the walls alike. Each ray is shared among
// the four pixels round where it lands, by nearness (in 64ths), so a
// shift of the rays by part of a pixel changes the tally smoothly; counted
// whole in one pixel, the rays' starting grid showed as outlines wherever
// the shift crossed a pixel's edge. Then the tally is blurred by the
// bulb's size.
//
// Stages: 0 clear the tally, 1 trace, 2 draw the picture as sRGB.
// The picture holds a quarter of the intensity relative to still water
// (1 = still water), so the light's energy is four times the plain one.

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, r32ui) uniform restrict uimage2D tally;
layout(set = 0, binding = 1, r8) uniform restrict writeonly image2D picture;
layout(set = 0, binding = 2) uniform sampler2D ripple_a;
layout(set = 0, binding = 3) uniform sampler2D ripple_b;
layout(set = 0, binding = 4, std430) restrict readonly buffer Drops {
	vec4 drops[];        // x, z where it landed; when (s); strength, 0 for none
};

layout(push_constant, std430) uniform Params {
	int stage;
	int size;        // the picture's side in pixels
	int rays;        // rays per side of the cone
	int test;        // 1: draw a marker in one quarter instead
	vec4 lamp;       // xyz the lamp, w the water's height
	float ceiling;   // the ceiling's height
	float tan_angle; // tangent of the light's half-angle
	float strength;  // the ripples' slope at full strength of the maps
	float ripple_size;
	vec4 offsets;    // xy the first map's slide, zw the second's
	float blur;      // the bulb's blur, in pixels of the picture
	float now;       // the clock the drops' times are on
	float drip_strength;
	float half_room; // the walls stand this far either way from x 0, z 0
} pc;

const float WATER = 1.33;
const float TAU = 6.2831853;
const float SHARE = 64.0;              // a whole ray in the tally
const int MAX_DROPS = 100;
const float G = 9.8;
const float SIGMA_RHO = 7.28e-5;
const float NU = 1e-6;
const float FILM = 0.003;               // m, the water's depth on the glass
// The glass drags on the thin film under every wave: amplitude falls at
// 3 nu / (2 h^2) a second, a third every 6 s. After 30 s less than 1%
// is left, so a drop is let go then.
const float DRAG = 3.0 * NU / (2.0 * FILM * FILM);
const float MAX_AGE = 30.0;

// The slope from every drop's rings at a point of the surface: a copy of
// drip_slope in pool_glass.gdshader, which explains it; the two must stay
// the same, so the caustics' rings are the rings on the glass.
vec2 drip_slope(vec2 at) {
	vec2 slope = vec2(0.0);
	for (int d = 0; d < MAX_DROPS; d++) {
		vec4 drop = drops[d];
		float age = pc.now - drop.z;
		if (drop.w <= 0.0 || age <= 0.0 || age > MAX_AGE) {
			continue;
		}
		vec2 off = at - drop.xy;
		float r = length(off);
		if (r > age * 0.4 + 0.1) {
			continue;
		}
		vec2 dir = off / max(r, 1e-4);
		float sum = 0.0;
		for (int i = 0; i < 8; i++) {
			float k = 63.0 * pow(12.5, float(i) / 7.0);
			// Waves on water FILM deep: w^2 = (g k + (sigma/rho) k^3) tanh(k h);
			// the group speed is d(w^2)/dk / (2 w).
			float t = tanh(k * FILM);
			float deep = G * k + SIGMA_RHO * k * k * k;
			float w = sqrt(deep * t);
			float cg = ((G + 3.0 * SIGMA_RHO * k * k) * t + deep * FILM * (1.0 - t * t)) / (2.0 * w);
			float centre = cg * age;
			float width = 0.03 + 0.25 * centre;
			float x = (r - centre) / width;
			float env = exp(-x * x) * exp(-(2.0 * NU * k * k + DRAG) * age) / sqrt(1.0 + r / 0.05);
			sum += -sin(k * r - w * age) * env;
		}
		slope += dir * sum * drop.w;
	}
	return slope * 0.4 * pc.drip_strength;
}

// The water's slope (rise over run along x and z) at a point of the
// surface, from the two sliding normal maps exactly as pool_glass.gdshader
// reads them.
vec2 slope(vec2 xz) {
	vec2 p = xz / pc.ripple_size;
	vec2 sa = textureLod(ripple_a, p + pc.offsets.xy, 0.0).xy * 2.0 - 1.0;
	vec2 sb = textureLod(ripple_b, p * 0.73 + pc.offsets.zw, 0.0).xy * 2.0 - 1.0;
	return (sa + sb) * 0.5 * pc.strength + drip_slope(xz);
}

// Picture pixel for a direction from the lamp given as its tangents
// across x and z: the light's picture spans -tan_angle..tan_angle, its
// first axis along +x and its second along -z (the light points up with
// +z as its own up, and a picture's rows run down).
vec2 to_pixel(vec2 t) {
	return (vec2(t.x, -t.y) / pc.tan_angle * 0.5 + 0.5) * float(pc.size);
}

void trace() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= pc.rays || id.y >= pc.rays) {
		return;
	}
	vec2 t = ((vec2(id) + 0.5) / float(pc.rays) * 2.0 - 1.0) * pc.tan_angle;
	vec3 d = normalize(vec3(t.x, 1.0, t.y));
	vec3 at = pc.lamp.xyz + d * (pc.lamp.w - pc.lamp.y) / d.y;
	vec3 inside = refract(d, vec3(0.0, -1.0, 0.0), 1.0 / WATER);
	vec2 s = slope(at.xz);
	vec3 n = normalize(vec3(-s.x, 1.0, -s.y));
	vec3 out_dir = refract(inside, -n, WATER);
	if (out_dir.y < 0.01) {
		return;          // turned back inside the water, or skimming flat
	}
	float reach = (pc.ceiling - at.y) / out_dir.y;
	if (abs(out_dir.x) > 1e-6) {
		reach = min(reach, (sign(out_dir.x) * pc.half_room - at.x) / out_dir.x);
	}
	if (abs(out_dir.z) > 1e-6) {
		reach = min(reach, (sign(out_dir.z) * pc.half_room - at.z) / out_dir.z);
	}
	vec3 lands = at + out_dir * max(reach, 0.0);
	vec2 seen = (lands.xz - pc.lamp.xz) / (lands.y - pc.lamp.y);
	vec2 pos = to_pixel(seen) - 0.5;
	ivec2 base = ivec2(floor(pos));
	vec2 f = pos - vec2(base);
	for (int y = 0; y <= 1; y++) {
		for (int x = 0; x <= 1; x++) {
			ivec2 px = base + ivec2(x, y);
			if (px.x < 0 || px.y < 0 || px.x >= pc.size || px.y >= pc.size) {
				continue;
			}
			float w = (x == 0 ? 1.0 - f.x : f.x) * (y == 0 ? 1.0 - f.y : f.y);
			imageAtomicAdd(tally, px, uint(round(w * SHARE)));
		}
	}
}

float count(ivec2 p) {
	p = clamp(p, ivec2(0), ivec2(pc.size - 1));
	return float(imageLoad(tally, p).r);
}

void draw() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= pc.size || id.y >= pc.size) {
		return;
	}
	float v;
	if (pc.test == 1) {
		vec2 t = ((vec2(id) + 0.5) / float(pc.size) * 2.0 - 1.0) * pc.tan_angle;
		t.y = -t.y;
		v = (t.x > 0.05 && t.y > 0.15) ? 0.25 : 0.0;
	} else {
		// The tally averaged over a disc as wide as the bulb's blur (rings
		// of 6, 12, 18 ... samples), or, for a blur under a pixel and a
		// half, smoothed over its neighbours (weights 4, 2, 1).
		float per = SHARE * float(pc.rays * pc.rays) / float(pc.size * pc.size);
		float sum = 0.0;
		float weight = 0.0;
		int rings = clamp(int(ceil(pc.blur / 1.5)), 0, 8);
		for (int ring = 0; ring <= rings; ring++) {
			float r = rings == 0 ? 0.0 : pc.blur * float(ring) / float(rings);
			int steps = ring == 0 ? 1 : 6 * ring;
			for (int j = 0; j < steps; j++) {
				float a = TAU * (float(j) + 0.5 * float(ring)) / float(steps);
				ivec2 c = id + ivec2(round(r * vec2(cos(a), sin(a))));
				float s = 0.0;
				if (rings == 0) {
					for (int y = -1; y <= 1; y++) {
						for (int x = -1; x <= 1; x++) {
							s += (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0) * count(c + ivec2(x, y));
						}
					}
					s /= 16.0;
				} else {
					s = count(c);
				}
				sum += s;
				weight += 1.0;
			}
		}
		v = 0.25 * sum / weight / per;
	}
	v = clamp(v, 0.0, 1.0);
	imageStore(picture, id, vec4(pow(v, 1.0 / 2.2), 0.0, 0.0, 1.0));
}

void main() {
	if (pc.stage == 1) {
		trace();
		return;
	}
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= pc.size || id.y >= pc.size) {
		return;
	}
	if (pc.stage == 0) {
		imageStore(tally, id, uvec4(0u));
	} else {
		draw();
	}
}
