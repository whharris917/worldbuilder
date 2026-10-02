shader_type spatial;
// Clear still water: a pond in the hills. What lies behind the surface
// (the bed, a stone, the far bank seen through the shallows) is read
// from the screen and dimmed by the water it passes through, red first,
// so the shallows are glass and the deep water goes green-blue; the
// water's own colour, lit like any surface, makes up what the light
// lost. Ripples bend what is seen through it and break up the sky's
// reflection, which the engine adds at a glancing angle. The wind's
// gusts (gust.gdshaderinc, the grass's own) roughen the surface where
// they pass, so dark cat's paws run over the pond with the bands on
// the hills.
render_mode cull_disabled, depth_draw_always;
#include "res://world/granite.gdshaderinc"
#include "res://world/gust.gdshaderinc"

uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
// How fast each colour fades through a metre of water: very clear, red
// lost first.
uniform vec3 absorb = vec3(0.26, 0.075, 0.065);
// The water's own colour, where it is deep enough to show it.
uniform vec3 body : source_color = vec3(0.04, 0.09, 0.08);
uniform float bend = 0.025;          // how far ripples bend what is seen through them

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// The surface's slope from a few drifting ripple patterns, gentle in a
// calm and rough where a gust runs over it.
vec2 ripple_slope(vec2 p, float rough) {
	vec2 wd = normalize(wind_dir);
	float t = gust_travel * gust_speed;
	vec2 g = vec2(0.0);
	float e = 0.05;
	float freq = 0.9;
	float amp = 1.0;
	for (int k = 0; k < 3; k++) {
		vec2 q = p * freq - wd * t * freq * 0.7 + float(k) * 13.0;
		float a0 = value_noise(q);
		g += vec2(value_noise(q + vec2(e, 0.0)) - a0, value_noise(q + vec2(0.0, e)) - a0) / e * amp;
		freq *= 2.3;
		amp *= 0.5;
	}
	return g * rough;
}

void fragment() {
	vec2 p = world_pos.xz;
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	float gust = gust_at(p);
	// Ripples finer than a pixel would sparkle: they calm with distance.
	float fade = clamp(1.0 - dist / 60.0, 0.03, 1.0);
	vec2 slope = ripple_slope(p, (0.008 + 0.07 * gust) * fade);
	vec3 wn = normalize(vec3(-slope.x, 1.0, -slope.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	// What lies behind, and how much water the eye looks through to it.
	float raw = texture(depth_tex, SCREEN_UV).x;
	vec4 behind_v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind_v.xyz /= behind_v.w;
	float path = max(length(behind_v.xyz) - length(VERTEX), 0.0);
	// Bent by the ripples, but never onto something in front of the water.
	vec2 uv = SCREEN_UV + slope * bend * clamp(path, 0.0, 1.0) / max(dist * 0.15, 1.0);
	float raw2 = texture(depth_tex, uv).x;
	vec4 bent_v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw2, 1.0);
	bent_v.xyz /= bent_v.w;
	if (length(bent_v.xyz) < length(VERTEX)) {
		uv = SCREEN_UV;
	} else {
		path = max(length(bent_v.xyz) - length(VERTEX), 0.0);
	}
	vec3 seen = textureLod(screen_tex, uv, 0.0).rgb;
	vec3 through = exp(-absorb * path);

	vec3 view = normalize(-VERTEX);
	float fresnel = 0.02 + 0.98 * pow(clamp(1.0 - dot(NORMAL, view), 0.0, 1.0), 5.0);
	EMISSION = seen * through * (1.0 - fresnel);
	ALBEDO = body * (vec3(1.0) - through) * (1.0 - fresnel);
	ROUGHNESS = 0.02 + 0.08 * gust;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
