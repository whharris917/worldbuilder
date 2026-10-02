shader_type spatial;
// A thunderhead far off on the horizon, drawn on one upright card: a
// broad base, a billowing tower, and the anvil spreading flat at the
// top and streaming off to one side. Lit by the day (or barely, at
// night) and from inside by the lightning in it: up to four flashes at
// a time, each a glow round a point in the cloud, brightest where the
// cloud is thick. Hazed with the distance by hand (the world's fog
// would bury it). UV x runs -1 to 1 across, y 0 at the base to 1.
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

uniform vec3 day_color : source_color = vec3(0.85, 0.85, 0.88);   // the lit tops
uniform vec3 shade_color : source_color = vec3(0.40, 0.43, 0.50); // the base and the shaded side
uniform vec3 haze_color : source_color = vec3(0.7, 0.75, 0.82);
uniform float haze = 0.3;
uniform float opacity = 0.0;          // the cloud fading in and out
uniform float lean = 0.3;             // which way the anvil streams
uniform float seed = 0.0;
uniform vec4 flashes[4];              // (x, y, radius, strength) in UV
uniform vec3 flash_color : source_color = vec3(0.86, 0.84, 1.0);

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	return mix(mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x), mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x), u.y);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int k = 0; k < 5; k++) {
		v += a * noise(p);
		p = p * 2.07 + vec2(3.1, 7.7);
		a *= 0.5;
	}
	return v;
}

void fragment() {
	vec2 q = vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y);
	float y = q.y;
	// The outline: the half-width at each height.
	// A broad heaped tower, a little narrower as it climbs, swelling in
	// the lobes of its updraughts; the anvil spreading out over it.
	float tower = 0.50 - 0.10 * y + 0.05 * sin(y * 11.0 + seed);
	float anvil = smoothstep(0.62, 0.82, y) * (0.80 + 0.18 * smoothstep(0.82, 0.95, y));
	float half_w = max(mix(0.58, tower, smoothstep(0.0, 0.25, y)), anvil);
	float shift = lean * smoothstep(0.6, 0.95, y) * 0.35;
	float x = q.x - shift;
	vec2 p = vec2(x, y) * vec2(3.0, 3.0) + seed;
	float billow = fbm(p * 1.4) - 0.5 + (fbm(p * 4.0 + 5.0) - 0.5) * 0.4;
	float edge = half_w + billow * 0.28;
	float inside = smoothstep(edge, edge - 0.12, abs(x));
	// Flat-ish top to the anvil, a ragged base.
	// The anvil thins toward its streaming edge and its top is torn.
	float anvil_part = smoothstep(0.62, 0.8, y) * smoothstep(tower, half_w, abs(x));
	inside *= smoothstep(0.97 + billow * 0.1, 0.9 + billow * 0.1 - anvil_part * 0.05, y);
	inside *= 1.0 - anvil_part * smoothstep(0.3, 0.9, abs(x) / max(half_w, 0.01)) * 0.6;
	inside *= smoothstep(-0.02, 0.06, y + billow * 0.05);
	float thick = clamp(inside * (0.6 + fbm(p * 2.3 + 11.0)), 0.0, 1.0);
	// Lit from above and on the billows' tops.
	// Lit from above: the base and the flanks in shade, the billows'
	// tops catching the light.
	float lobes = (fbm(p * 1.4) - fbm(p * 1.4 - vec2(0.0, 0.1))) * 6.0;
	float flank = abs(x) / max(half_w, 0.01);
	float top_lit = clamp(0.1 + 0.8 * smoothstep(0.05, 0.85, y) + lobes - 0.35 * flank * flank, 0.0, 1.0);
	vec3 col = mix(shade_color * 0.8, day_color, top_lit);
	// The lightning inside.
	float glow = 0.0;
	for (int i = 0; i < 4; i++) {
		vec4 f = flashes[i];
		vec2 d = (vec2(UV.x * 2.0 - 1.0, 1.0 - UV.y) - f.xy) / max(f.z, 0.01);
		glow += f.w * exp(-dot(d, d));
	}
	// The flash lights the cloud from within: strongest in its thick
	// heart, soft through its billows, faint at its edge.
	col += flash_color * glow * thick * thick * 3.0;
	col = mix(col, haze_color, haze * (1.0 - clamp(glow, 0.0, 1.0)));
	ALBEDO = col;
	ALPHA = inside * opacity;
}
