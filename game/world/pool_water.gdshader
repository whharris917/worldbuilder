shader_type spatial;
// The pool's water, 30 cm over clear glass. The surface is drawn flat
// (its ripples are millimetres high) and shaded with the ripple grid's
// slope (pool_ripples.gdshader), which bends what is seen through it: the glass, the steel under it and the
// lamp below, read from the screen and dimmed a little by the water,
// red first. The room is reflected at glancing angles by the engine.
// From the chamber below, through the glass, the surface is seen from
// inside the water: the room shows through it bent by the ripples, and
// past the critical angle (48.6 degrees from straight up) the surface is
// a mirror of the chamber under it. The chamber is a plain box lit by one
// lamp, so what the mirror shows is worked out here: where the reflected
// ray meets the chamber's floor or walls, the lamp's light on that spot
// and a constant for the light the chamber bounces, and the bulb itself
// where the ray passes through it.
render_mode cull_disabled, depth_draw_always;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform sampler2D ripples : filter_linear, repeat_disable;
uniform float pool_half = 4.0;
uniform vec2 pool_centre = vec2(0.0);       // x, z
// How fast each colour fades through a metre of water.
uniform vec3 absorb = vec3(0.30, 0.06, 0.05);
// What the glass lets through, its edge-green tint.
uniform vec3 glass = vec3(0.90, 0.94, 0.92);
// The chamber, for what the surface mirrors from below.
uniform vec3 lamp = vec3(0.0, -2.4, 0.0);
uniform vec3 lamp_light = vec3(60.0);        // the light's linear colour times its energy
uniform float bulb_radius = 0.06;
uniform vec3 bulb_glow = vec3(40.0);
uniform float chamber_floor = -3.2;
uniform float chamber_half = 5.0;            // its walls at +- this in x and z
uniform float chamber_albedo = 0.014;       // linear
// The chamber's light from its own surfaces (the bounce the engine adds
// to what is seen directly), as a radiance, matched by eye.
uniform vec3 chamber_bounce = vec3(0.04);
uniform float bend = 0.6;            // how far a slope bends the view, as a fraction of the depth behind

varying vec2 pool_uv;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pool_uv = (w.xz - pool_centre) / (2.0 * pool_half) + 0.5;
}

// The chamber seen along a ray from p going down: the lamp's light on
// the floor or wall it meets, as a matte surface reflects it, and the
// bulb where the ray passes through it.
vec3 chamber(vec3 p, vec3 r) {
	float t = (chamber_floor - p.y) / min(r.y, -1e-4);
	vec3 n = vec3(0.0, 1.0, 0.0);
	vec2 side = vec2(r.x < 0.0 ? -1.0 : 1.0, r.z < 0.0 ? -1.0 : 1.0);
	vec2 wall = (side * chamber_half - p.xz) / (side * max(abs(r.xz), vec2(1e-4)));
	if (wall.x < t) {
		t = wall.x;
		n = vec3(-side.x, 0.0, 0.0);
	}
	if (wall.y < t) {
		t = wall.y;
		n = vec3(0.0, 0.0, -side.y);
	}
	vec3 q = p + r * t;
	vec3 l = lamp - q;
	float d2 = max(dot(l, l), 0.01);
	vec3 seen = chamber_bounce + lamp_light * chamber_albedo / PI * max(dot(n, l), 0.0) * inversesqrt(d2) / d2;
	// The bulb: the ray's nearest approach to its centre.
	vec3 to_lamp = lamp - p;
	float along = dot(to_lamp, r);
	if (along > 0.0 && along < t && length(to_lamp - r * along) < bulb_radius) {
		seen = bulb_glow;
	}
	return seen;
}

void fragment() {
	float e = 1.0 / float(textureSize(ripples, 0).x);
	float m = 2.0 * pool_half * e;
	float hx = (texture(ripples, pool_uv + vec2(e, 0.0)).r - texture(ripples, pool_uv - vec2(e, 0.0)).r) / (2.0 * m);
	float hz = (texture(ripples, pool_uv + vec2(0.0, e)).r - texture(ripples, pool_uv - vec2(0.0, e)).r) / (2.0 * m);
	vec3 wn = normalize(vec3(-hx, 1.0, -hz));
	// The normal facing the eye, from above or below.
	NORMAL = normalize((VIEW_MATRIX * vec4(FRONT_FACING ? wn : -wn, 0.0)).xyz);

	float raw = texture(depth_tex, SCREEN_UV).x;
	vec4 behind_v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind_v.xyz /= behind_v.w;
	float path = max(length(behind_v.xyz) - length(VERTEX), 0.0);
	// The view bent by the slope, in proportion to how far behind the
	// surface the thing seen lies; never onto something in front.
	vec2 off = (VIEW_MATRIX * vec4(hx, 0.0, hz, 0.0)).xy;
	vec2 uv = SCREEN_UV - off * bend * min(path, 3.0) / max(-VERTEX.z, 0.5);
	float raw2 = texture(depth_tex, uv).x;
	vec4 bent_v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw2, 1.0);
	bent_v.xyz /= bent_v.w;
	if (length(bent_v.xyz) < length(VERTEX)) {
		uv = SCREEN_UV;
	} else {
		path = max(length(bent_v.xyz) - length(VERTEX), 0.0);
	}
	vec3 seen = textureLod(screen_tex, uv, 0.0).rgb;
	// The water's own depth over the glass, whatever lies further down.
	float wet = min(path, 0.6);
	vec3 through = exp(-absorb * wet) * glass;

	vec3 view = normalize(-VERTEX);
	float c = clamp(dot(NORMAL, view), 0.0, 1.0);
	if (FRONT_FACING) {
		float fresnel = 0.02 + 0.98 * pow(1.0 - c, 5.0);
		EMISSION = seen * through * (1.0 - fresnel);
		SPECULAR = 0.5;
	} else {
		// Inside the water: the angle the light leaves by into the air
		// sets the reflectance (Schlick on the air side); none leaves
		// past the critical angle.
		float s2 = 1.333 * 1.333 * (1.0 - c * c);
		float fresnel = 1.0;
		if (s2 < 1.0) {
			float ct = sqrt(1.0 - s2);
			fresnel = 0.02 + 0.98 * pow(1.0 - ct, 5.0);
		}
		vec3 eye = (INV_VIEW_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
		vec3 here = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
		vec3 r = reflect(normalize(here - eye), -wn);
		EMISSION = seen * through * (1.0 - fresnel) + chamber(here, r) * fresnel;
		SPECULAR = 0.0;
	}
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.03;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
