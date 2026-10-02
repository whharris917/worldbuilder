shader_type sky;
// A painted sky in the manner of the Ghibli backgrounds: a deep blue
// overhead fading to a pale haze at the horizon, and big cumulus clouds
// drifting low over the hills, white on top and blue-grey underneath,
// with clean soft-edged shapes. At dawn and dusk the horizon and the
// clouds' undersides warm to orange and rose; at night the dome goes
// to a deep navy for the stars (NightSky) and the moon. The world sets
// sun_dir and moon_dir (toward each) from its clock.

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float cover = 0.38;        // how much of the sky the clouds take
uniform vec2 drift = vec2(0.004, 0.0015);
uniform float flash = 0.0;           // lightning, lighting the sky toward it
uniform vec3 flash_dir = vec3(0.0, 0.2, -1.0);

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
		p = p * 2.03 + vec2(1.7, 9.2);
		a *= 0.5;
	}
	return v;
}

void sky() {
	vec3 d = normalize(EYEDIR);
	float elev = sun_dir.y;
	float day = smoothstep(-0.12, 0.12, elev);
	float low = (1.0 - smoothstep(0.05, 0.4, elev)) * smoothstep(-0.2, -0.02, elev);
	float up = clamp(d.y, 0.0, 1.0);

	vec3 top_day = vec3(0.07, 0.25, 0.72);
	vec3 hor_day = vec3(0.55, 0.78, 0.95);
	vec3 top_dusk = vec3(0.16, 0.18, 0.45);
	vec3 hor_dusk = vec3(1.0, 0.58, 0.36);
	vec3 top_night = vec3(0.004, 0.008, 0.03);
	vec3 hor_night = vec3(0.015, 0.025, 0.07);
	vec3 top = mix(mix(top_night, top_dusk, smoothstep(-0.25, 0.0, elev)), top_day, day * (1.0 - low * 0.7));
	vec3 hor = mix(mix(hor_night, hor_dusk, smoothstep(-0.25, 0.0, elev)), hor_day, day * (1.0 - low));
	// The warm side of the sky is the sun's side.
	float sunward = max(dot(normalize(vec3(d.x, 0.0, d.z) + 1.0e-4), normalize(vec3(sun_dir.x, 0.0, sun_dir.z) + 1.0e-4)), 0.0);
	hor = mix(hor, hor_dusk * 1.1, low * sunward * 0.6);
	vec3 col = mix(hor, top, pow(up, 0.55));
	// Below the horizon: the haze carried down.
	if (d.y < 0.0) {
		col = mix(hor, hor * 0.6, clamp(-d.y * 3.0, 0.0, 1.0));
	}

	// The clouds: a layer seen in perspective, thickest toward the
	// horizon, shaped by a thresholded noise with a soft rim.
	if (d.y > 0.0) {
		// Big heaped clouds: the noise warped by itself so the edges
		// billow, the shapes larger and more of them toward the horizon.
		vec2 uv = d.xz / (d.y + 0.18) * 0.75 + TIME * drift;
		vec2 warp = vec2(fbm(uv * 1.7 + 3.1), fbm(uv * 1.7 + 8.3)) - 0.5;
		vec2 q = uv + warp * 0.35;
		float n = fbm(q);
		float edge = mix(0.62, 0.5, cover) - 0.08 * (1.0 - up);
		float shape = smoothstep(edge, edge + 0.025, n);
		// Lit on the tops and the sun's side, the bases shaded: the noise a
		// step up the sky (toward the zenith) and toward the sun.
		vec2 toward = normalize(sun_dir.xz + 1.0e-4) * 0.05;
		float above = fbm(q * 0.94);
		float lit = clamp((n - above) * 7.0 + (n - fbm(q + toward)) * 4.0 + 0.5, 0.0, 1.0);
		float body = smoothstep(edge + 0.02, edge + 0.25, n);
		vec3 bright = mix(vec3(0.95, 0.66, 0.55), vec3(1.0, 1.0, 0.98), day * (1.0 - low * 0.8));
		vec3 under = mix(vec3(0.55, 0.42, 0.55), vec3(0.62, 0.70, 0.86), day * (1.0 - low * 0.6));
		vec3 cloud = mix(under, bright, max(lit, 1.0 - body * 0.7));
		cloud *= mix(0.06, 1.0, smoothstep(-0.2, 0.05, elev));
		col = mix(col, cloud, shape * smoothstep(0.0, 0.06, up));
	}

	// The sun and the moon.
	float s = dot(d, normalize(sun_dir));
	col += vec3(1.0, 0.92, 0.75) * (smoothstep(0.9993, 0.9996, s) * 20.0 + pow(max(s, 0.0), 64.0) * 0.6) * smoothstep(-0.05, 0.02, elev);
	float m = dot(d, normalize(moon_dir));
	col += vec3(0.85, 0.88, 0.95) * smoothstep(0.99955, 0.9998, m) * 2.0 * smoothstep(-0.02, 0.05, moon_dir.y);
	float toward_flash = clamp(dot(d, normalize(flash_dir)), 0.0, 1.0);
	col += vec3(0.55, 0.60, 0.78) * flash * (0.25 + 1.5 * pow(toward_flash, 6.0));
	COLOR = col;
}
