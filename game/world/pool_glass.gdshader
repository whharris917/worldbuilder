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
	vec2 slope = (sa + sb) * 0.5 * ripple_strength;
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
