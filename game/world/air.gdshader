shader_type spatial;
// Small lights in the air over the meadow, one billboard each, from a
// MultiMesh laid once in a box the camera carries: each instance keeps
// its place in the world and wraps to the far side of the box when the
// camera leaves it behind, fading near the box's edge so none pops.
// Fireflies: over the grass at dusk, each drifting on its own slow
// path and flashing on its own period, rising a little as it flashes,
// as the common eastern firefly does. Motes: seeds and dust adrift in
// the day, seen only where the sun catches them, brightest when the
// viewer looks toward the sun.
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
#include "res://world/granite.gdshaderinc"

uniform sampler2D ground : filter_linear, repeat_disable;
uniform vec2 ground_origin = vec2(-128.0);
uniform float ground_size = 256.0;
uniform bool motes = false;
uniform float box = 60.0;
uniform float amount = 0.0;          // fireflies: how dark; motes: how sunny
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec2 wind_dir = vec2(0.8, 0.6);
uniform float wind = 0.3;

varying float glow;

void vertex() {
	vec3 base = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float ph = hash2(base.xz * 3.1 + 1.0);
	float ph2 = hash2(base.xz * 1.7 + 9.0);
	vec2 cam = CAMERA_POSITION_WORLD.xz;
	vec2 drift = vec2(sin(TIME * 0.21 + ph * 6.28), cos(TIME * 0.17 + ph2 * 6.28)) * (motes ? 0.6 : 1.2);
	if (motes) {
		drift += normalize(wind_dir) * TIME * (0.15 + 0.8 * wind);
	}
	vec2 rel = mod(base.xz + drift - cam + box * 0.5, box) - box * 0.5;
	vec2 at = cam + rel;
	float edge = 1.0 - smoothstep(box * 0.35, box * 0.5, max(abs(rel.x), abs(rel.y)));
	vec2 guv = (at - ground_origin) / ground_size;
	vec4 g = textureLod(ground, guv, 0.0);
	float inside = step(0.0, guv.x) * step(guv.x, 1.0) * step(0.0, guv.y) * step(guv.y, 1.0);
	float y;
	float bright;
	if (motes) {
		y = g.r + 0.3 + base.y * 3.5 + sin(TIME * 0.4 + ph * 6.28) * 0.3;
		vec3 to = normalize(vec3(at.x, y, at.y) - CAMERA_POSITION_WORLD);
		float toward = max(dot(to, sun_dir), 0.0);
		bright = amount * (0.08 + 1.6 * pow(toward, 12.0)) * inside;
	} else {
		// A flash every few seconds, half a second long, rising as it glows.
		float period = 3.0 + 4.0 * ph2;
		float p = fract(TIME / period + ph);
		float flash = smoothstep(0.0, 0.04, p) * (1.0 - smoothstep(0.06, 0.15, p));
		y = g.r + 0.4 + base.y * 1.8 + sin(TIME * 0.33 + ph * 6.28) * 0.25 + p * 0.35;
		bright = amount * flash * smoothstep(0.15, 0.4, g.g) * inside;
	}
	glow = bright * edge;
	vec3 centre = vec3(at.x, y, at.y);
	float dist = length(centre - CAMERA_POSITION_WORLD);
	// Never under a pixel or two: a light far off still shows as a point.
	float size = motes ? max(0.006, dist * 0.0015) : max(0.07, dist * 0.004);
	vec3 right = INV_VIEW_MATRIX[0].xyz;
	vec3 up = INV_VIEW_MATRIX[1].xyz;
	vec3 world = centre + (right * VERTEX.x + up * VERTEX.y) * size * (glow > 0.001 ? 1.0 : 0.0);
	POSITION = PROJECTION_MATRIX * VIEW_MATRIX * vec4(world, 1.0);
}

void fragment() {
	float d = length(UV - 0.5) * 2.0;
	float dot_ = 1.0 - smoothstep(0.2, 1.0, d);
	vec3 col = motes ? lin(vec3(1.0, 0.95, 0.85)) * 0.8 : lin(vec3(0.75, 1.0, 0.25)) * 10.0;
	ALBEDO = col * dot_ * glow;
}
