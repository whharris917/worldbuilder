#[compute]
#version 450

// The telescope projector's patterns, on a square grid that wraps at its
// edges. One shader, run in stages chosen by the script:
//   0 seed the state (reaction, convection)
//   1 clear the caustic tally
//   2 trace rays through the water surface and tally where they land
//   3 one time step of the state (reaction, convection)
//   4 draw the picture, blurred by the focus, as sRGB
// Modes: 0 caustics, 1 reaction (Gray-Scott), 2 interference,
// 3 convection (Swift-Hohenberg).

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

layout(set = 0, binding = 0, rgba32f) uniform restrict readonly image2D state_in;
layout(set = 0, binding = 1, rgba32f) uniform restrict writeonly image2D state_out;
layout(set = 0, binding = 2, r32ui) uniform restrict uimage2D tally;
layout(set = 0, binding = 3, rgba8) uniform restrict writeonly image2D picture;

layout(push_constant, std430) uniform Params {
	int stage;
	int mode;
	int size;
	int rays;        // rays per side of the grid for the caustics
	float time;      // seconds, for the patterns worked out directly
	float setting;   // the panel's pattern setting, about 0.5 to 2
	float blur;      // focus blur radius in pixels
	float seed;
	float dt;        // convection time step
	float h;         // convection grid spacing
	float noise;     // convection's stirring
	float pad;
} pc;

const float PI = 3.14159265;
const float TAU = 6.2831853;

ivec2 wrap(ivec2 p) {
	return (p % pc.size + pc.size) % pc.size;
}

float hash(vec2 p) {
	p = fract(p * vec2(443.897, 441.423) + pc.seed);
	p += dot(p, p.yx + 19.19);
	return fract((p.x + p.y) * p.x);
}

// ---- caustics -------------------------------------------------------------
// A water cell 20 cm across, its surface the sum of eight waves whose
// wavevectors are whole numbers of waves across the cell (so it wraps),
// each moving at its own angular frequency from water's dispersion,
// w^2 = g k + (sigma/rho) k^3. A ray straight down through the surface
// is bent in proportion to the slope and lands displaced on the floor of
// the cell; where the surface's curvature gathers rays, they pile up.

const ivec2 WAVES[8] = ivec2[8](ivec2(3, 1), ivec2(-2, 4), ivec2(5, -3), ivec2(1, 6),
	ivec2(-4, -2), ivec2(6, 2), ivec2(2, -5), ivec2(7, 1));

vec2 slope(vec2 uv) {
	vec2 s = vec2(0.0);
	for (int i = 0; i < 8; i++) {
		vec2 n = vec2(WAVES[i]);
		float kn = length(n);
		float k = TAU * kn / 0.2;
		float w = sqrt(9.81 * k + 7.3e-5 * k * k * k);
		float phase = TAU * dot(n, uv) - w * pc.time + float(i) * 1.7;
		// Amplitudes falling as 1/n^2, so every wave bends light alike.
		s += (TAU * n) / (kn * kn) * cos(phase);
	}
	return s;
}

void trace() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= pc.rays || id.y >= pc.rays) {
		return;
	}
	vec2 uv = (vec2(id) + 0.5) / float(pc.rays);
	vec2 landed = uv + 0.012 * pc.setting * slope(uv);
	ivec2 cell = wrap(ivec2(floor(landed * float(pc.size))));
	imageAtomicAdd(tally, cell, 1u);
}

// ---- reaction: Gray-Scott -------------------------------------------------
// u is fed in at rate F, v consumes it (u + 2v -> 3v) and dies at F + k;
// u spreads twice as fast as v. The setting slides F and k from dividing
// spots (below 1) through mazes (1) to coral (2).

vec2 feed_kill() {
	vec2 spots = vec2(0.0367, 0.0649);
	vec2 mazes = vec2(0.029, 0.057);
	vec2 coral = vec2(0.0545, 0.062);
	float s = clamp(pc.setting, 0.5, 2.0);
	return s < 1.0 ? mix(spots, mazes, (s - 0.5) / 0.5) : mix(mazes, coral, (s - 1.0));
}

vec4 react(ivec2 p) {
	vec2 c = imageLoad(state_in, p).xy;
	vec2 lap = -c;
	lap += 0.2 * (imageLoad(state_in, wrap(p + ivec2(1, 0))).xy + imageLoad(state_in, wrap(p - ivec2(1, 0))).xy
		+ imageLoad(state_in, wrap(p + ivec2(0, 1))).xy + imageLoad(state_in, wrap(p - ivec2(0, 1))).xy);
	lap += 0.05 * (imageLoad(state_in, wrap(p + ivec2(1, 1))).xy + imageLoad(state_in, wrap(p + ivec2(1, -1))).xy
		+ imageLoad(state_in, wrap(p + ivec2(-1, 1))).xy + imageLoad(state_in, wrap(p - ivec2(1, 1))).xy);
	vec2 fk = feed_kill();
	float uvv = c.x * c.y * c.y;
	float u = c.x + (1.0 * lap.x - uvv + fk.x * (1.0 - c.x));
	float v = c.y + (0.5 * lap.y + uvv - (fk.x + fk.y) * c.y);
	return vec4(clamp(u, 0.0, 1.0), clamp(v, 0.0, 1.0), 0.0, 1.0);
}

// ---- convection: Swift-Hohenberg ------------------------------------------
// du/dt = r u - (1 + lap)^2 u + g u^2 - u^3, the textbook model of the
// rolls and hexagonal cells of a fluid heated from below; with g > 0 the
// cells are hexagons. A little noise each step keeps them shifting.

float field(ivec2 p) {
	return imageLoad(state_in, wrap(p)).x;
}

vec4 convect(ivec2 p) {
	float u = field(p);
	float n = field(p + ivec2(0, 1)) + field(p - ivec2(0, 1)) + field(p + ivec2(1, 0)) + field(p - ivec2(1, 0));
	float d = field(p + ivec2(1, 1)) + field(p + ivec2(1, -1)) + field(p + ivec2(-1, 1)) + field(p - ivec2(1, 1));
	float f = field(p + ivec2(0, 2)) + field(p - ivec2(0, 2)) + field(p + ivec2(2, 0)) + field(p - ivec2(2, 0));
	float h2 = pc.h * pc.h;
	float lap = (n - 4.0 * u) / h2;
	float bilap = (20.0 * u - 8.0 * n + 2.0 * d + f) / (h2 * h2);
	float r = 0.25;
	float g = 1.0;
	float du = r * u - (u + 2.0 * lap + bilap) + g * u * u - u * u * u;
	float stir = pc.noise * (hash(vec2(p) + pc.time * 13.1) - 0.5);
	return vec4(u + pc.dt * du + stir * sqrt(pc.dt), 0.0, 0.0, 1.0);
}

// ---- interference ---------------------------------------------------------
// Five point sources of waves of nearly the same frequency drifting
// slowly about; the brightness is the intensity of their sum. The
// frequencies differ a little, so the fringes move.

float interfere(vec2 uv) {
	float lambda = 0.06 * pc.setting;
	float k = TAU / lambda;
	vec2 sum = vec2(0.0);
	for (int i = 0; i < 5; i++) {
		float fi = float(i);
		vec2 at = vec2(0.5) + 0.32 * vec2(sin(0.11 * pc.time * (1.0 + 0.3 * fi) + fi * 2.1),
			cos(0.09 * pc.time * (1.0 + 0.23 * fi) + fi * 1.3));
		vec2 d = uv - at;
		d -= round(d);       // nearest copy across the wrapped edges
		float r = length(d);
		float phase = k * r - (1.0 + 0.04 * fi) * pc.time * 2.0;
		sum += vec2(cos(phase), sin(phase)) / sqrt(r + 0.03);
	}
	return dot(sum, sum) / 60.0;
}

// ---- the picture ----------------------------------------------------------

float value(vec2 px) {
	ivec2 p = wrap(ivec2(floor(px)));
	if (pc.mode == 0) {
		// The tally smoothed over its neighbours (weights 4, 2, 1), so the
		// grid the rays started on does not show where they are few.
		float per = float(pc.rays * pc.rays) / float(pc.size * pc.size);
		float sum = 0.0;
		for (int y = -1; y <= 1; y++) {
			for (int x = -1; x <= 1; x++) {
				float w = (x == 0 ? 2.0 : 1.0) * (y == 0 ? 2.0 : 1.0);
				sum += w * float(imageLoad(tally, wrap(p + ivec2(x, y))).r);
			}
		}
		return 0.3 * sum / 16.0 / per;
	} else if (pc.mode == 1) {
		return 3.5 * imageLoad(state_in, p).y;
	} else if (pc.mode == 2) {
		return interfere(px / float(pc.size));
	}
	// The convection's cells come out 8 pixels across on its grid, too
	// fine to project, so the middle of the grid is shown enlarged by the
	// setting (1 to 3 times), read smoothly between grid points.
	float zoom = clamp(1.0 + pc.setting, 1.0, 3.0) * 1.5;
	vec2 q = (px - 0.5 * float(pc.size)) / zoom + 0.5 * float(pc.size) - 0.5;
	ivec2 a = ivec2(floor(q));
	vec2 f = q - vec2(a);
	float u = mix(mix(imageLoad(state_in, wrap(a)).x, imageLoad(state_in, wrap(a + ivec2(1, 0))).x, f.x),
		mix(imageLoad(state_in, wrap(a + ivec2(0, 1))).x, imageLoad(state_in, wrap(a + ivec2(1, 1))).x, f.x), f.y);
	return 0.5 + 0.5 * clamp(u / 0.6, -1.0, 1.0);
}

void draw() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (id.x >= pc.size || id.y >= pc.size) {
		return;
	}
	vec2 px = vec2(id) + 0.5;
	float sum = value(px);
	float count = 1.0;
	if (pc.blur > 0.5) {
		// Out of focus, a point spreads into a disc: average over two rings.
		for (int ring = 1; ring <= 2; ring++) {
			float rr = pc.blur * float(ring) / 2.0;
			int steps = 6 * ring;
			for (int j = 0; j < steps; j++) {
				float a = TAU * (float(j) + 0.5 * float(ring)) / float(steps);
				sum += value(px + rr * vec2(cos(a), sin(a)));
				count += 1.0;
			}
		}
	}
	float v = clamp(sum / count, 0.0, 1.0);
	imageStore(picture, id, vec4(vec3(pow(v, 1.0 / 2.2)), 1.0));
}

void main() {
	ivec2 id = ivec2(gl_GlobalInvocationID.xy);
	if (pc.stage == 2) {
		trace();
		return;
	}
	if (pc.stage == 4) {
		draw();
		return;
	}
	if (id.x >= pc.size || id.y >= pc.size) {
		return;
	}
	if (pc.stage == 0) {
		vec2 cell = floor(vec2(id) / 12.0);
		float r = hash(cell);
		if (pc.mode == 1) {
			imageStore(state_out, id, r < 0.12 ? vec4(0.5, 0.25, 0.0, 1.0) : vec4(1.0, 0.0, 0.0, 1.0));
		} else {
			imageStore(state_out, id, vec4(0.1 * (hash(vec2(id)) - 0.5), 0.0, 0.0, 1.0));
		}
	} else if (pc.stage == 1) {
		imageStore(tally, id, uvec4(0u));
	} else if (pc.stage == 3) {
		imageStore(state_out, id, pc.mode == 1 ? react(id) : convect(id));
	}
}
