shader_type spatial;
// The pool's glass, opaque, showing what lies behind it. A second camera
// at the eye renders the scene without the pane (LightPool, `_portal`),
// so each point of the pane looks up the pixel of that picture at its
// own place on the screen and gives it off as light, filtered by the
// tint, as tinted glass colours what is seen through it, and dimmed by
// the glass's opacity; the tint also shows as the glass's own colour by
// the opacity, lit like any surface. The picture is untonemapped, so
// the screen's tone curve applies once.
//
// Ripples, as of a thin film of water on the glass: two normal maps
// (engine-made noise) slide across the pane in different directions, the
// script moving them. Their sum is the water's slope. It tilts the
// surface (NORMAL), so the engine's lighting and reflections ripple, and
// it shifts where the picture behind is looked up, as refraction shifts
// what is seen through water: by the slope times `bend`, the same for
// near and far things, since the picture holds no depth.
//
// Drips add rings to that slope. Each drop (up to MAX_DROPS at once, from
// LightPool: where it landed, when, how hard) sends out ripples of many
// wavelengths, each at its own speed, as water's waves do: a ripple of
// wavenumber k (2 pi over its wavelength) on water h deep oscillates at w
// with
//     w^2 = (g k + (sigma / rho) k^3) tanh(k h)
// (gravity, and surface tension over density, 7.28e-5 m^3/s^2). The film
// is 3 mm deep, so the longer ripples feel the glass and go slower than on
// deep water; below about 1.7 cm wavelength surface tension rules and
// shorter ripples are faster. A ripple's energy travels at its group speed dw/dk, so the ring
// of each wavelength is centred where that speed has carried it, spread
// over a width that grows with time; within it the crests move at
// w / k. Rings thin as 1/sqrt(distance) past 5 cm, as a ring's length
// grows, and
// each wavelength dies by viscosity at 2 nu k^2 a second (nu, water's,
// 1e-6 m^2/s), so fine ripples fade first; and all of them fade as the
// glass under the thin film drags on the water (DRAG). Eight wavelengths are summed,
// from 10 cm to 8 mm. The slope is worked out directly from the formula.
render_mode cull_back;

uniform sampler2D behind : filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(0.88, 0.95, 0.92);
uniform float opacity = 0.1;
uniform float roughness = 0.05;
uniform float specular = 0.5;
uniform sampler2D ripple_a : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D ripple_b : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec2 offset_a = vec2(0.0);     // how far each map has slid, in repeats
uniform vec2 offset_b = vec2(0.0);
uniform float ripple_size = 1.5;       // metres of pane to one repeat
uniform float ripple_strength = 0.3;   // slope at full strength of the maps
uniform float bend = 0.02;             // screen shift per unit of slope
const int MAX_DROPS = 100;
uniform vec4 drops[100];                // x, z where it landed; when (s); strength, 0 for none
uniform float now = 0.0;               // the clock the drops' times are on
uniform float drip_strength = 1.0;
const float G = 9.8;
const float SIGMA_RHO = 7.28e-5;
const float NU = 1e-6;
const float FILM = 0.003;               // m, the water's depth on the glass
// The glass drags on the thin film under every wave: amplitude falls at
// 3 nu / (2 h^2) a second, a third every 6 s. After 30 s less than 1%
// is left, so a drop is let go then.
const float DRAG = 3.0 * NU / (2.0 * FILM * FILM);
const float MAX_AGE = 30.0;

// The slope from every drop's rings at a point of the surface. The
// caustics (pool_caustics.glsl) hold a copy; change both alike.
vec2 drip_slope(vec2 at) {
	vec2 slope = vec2(0.0);
	for (int d = 0; d < MAX_DROPS; d++) {
		vec4 drop = drops[d];
		float age = now - drop.z;
		if (drop.w <= 0.0 || age <= 0.0 || age > MAX_AGE) {
			continue;
		}
		vec2 off = at - drop.xy;
		float r = length(off);
		// No ripple outruns the fastest group speed here, about 0.35 m/s.
		if (r > age * 0.4 + 0.1) {
			continue;
		}
		vec2 dir = off / max(r, 1e-4);
		float sum = 0.0;
		for (int i = 0; i < 8; i++) {
			float k = 63.0 * pow(12.5, float(i) / 7.0);      // 63 to 785 per metre
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
			// Slope of cos(k r - w t) is -k sin(k r - w t); the amplitude
			// falls as 1/k, so each wavelength's slope is about the same.
			sum += -sin(k * r - w * age) * env;
		}
		slope += dir * sum * drop.w;
	}
	return slope * 0.4 * drip_strength;
}

varying vec3 world_pos;
varying vec3 world_normal;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec2 p = world_pos.xz / ripple_size;
	vec2 sa = texture(ripple_a, p + offset_a).xy * 2.0 - 1.0;
	vec2 sb = texture(ripple_b, p * 0.73 + offset_b).xy * 2.0 - 1.0;
	vec2 slope = (sa + sb) * 0.5 * ripple_strength + drip_slope(world_pos.xz);
	vec2 uv = SCREEN_UV;
	// Only the pane's top and bottom are water-covered; its edges are not.
	if (abs(world_normal.y) > 0.5) {
		vec3 n = normalize(vec3(-slope.x, world_normal.y, -slope.y));
		NORMAL = normalize((VIEW_MATRIX * vec4(n, 0.0)).xyz);
		uv += (VIEW_MATRIX * vec4(slope.x, 0.0, slope.y, 0.0)).xy * bend;
	}
	ALBEDO = tint * opacity;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = texture(behind, uv).rgb * tint * (1.0 - opacity);
}
