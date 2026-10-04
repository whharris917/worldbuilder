shader_type canvas_item;
// One step of the pool's surface: the wave equation on a grid, a texel
// for every 3 cm of the pool. Red holds the height now in metres, green
// the height a step ago; the next height is twice the present less the
// past, plus the pull of the neighbours, a little damped. Reading past
// the grid's edge returns the edge texel, so a wave meets the pool's
// side as a wall and comes back. The player's legs push a dip into the
// water aside where they stand.
render_mode blend_disabled, unshaded;

uniform sampler2D prev : filter_nearest, repeat_disable;
// (c dt / dx)^2: how far a wave runs in a step, in texels, squared.
uniform float courant = 0.2;
// What is kept of the motion each step.
uniform float keep = 0.995;
// How much each height is drawn toward its neighbours' mean each step:
// it smooths away ripples only a few texels long, which the grid
// cannot carry and would draw as a chequer.
uniform float smoothing = 0.06;
// Up to two pushes: centre in texture coordinates, radius in texture
// coordinates, depth in metres added this step (negative pushes down).
// A push moves water, it does not remove it: the dip under the leg is
// ringed by a rise holding the same water.
uniform vec4 push_a = vec4(0.0);
uniform vec4 push_b = vec4(0.0);

float pushed(vec2 uv, vec4 p) {
	if (p.z <= 0.0) {
		return 0.0;
	}
	vec2 d = (uv - p.xy) / p.z;
	float r2 = dot(d, d);
	return p.w * (1.0 - r2) * exp(-r2);
}

void fragment() {
	vec2 px = 1.0 / vec2(textureSize(prev, 0));
	vec2 now = texture(prev, UV).rg;
	float n = texture(prev, UV + vec2(0.0, px.y)).r;
	float s = texture(prev, UV - vec2(0.0, px.y)).r;
	float e = texture(prev, UV + vec2(px.x, 0.0)).r;
	float w = texture(prev, UV - vec2(px.x, 0.0)).r;
	float next = 2.0 * now.r - now.g + courant * (n + s + e + w - 4.0 * now.r);
	// Damp the motion, not the height: the step's change shrinks.
	next = now.r + (next - now.r) * keep;
	next += smoothing * ((n + s + e + w) * 0.25 - now.r);
	next += pushed(UV, push_a) + pushed(UV, push_b);
	COLOR = vec4(next, now.r, 0.0, 1.0);
}
