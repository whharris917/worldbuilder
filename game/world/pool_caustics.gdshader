shader_type spatial;
// Where the lamp's light lands on one face of the room after the water
// bends it. The mesh is a grid over the pool's glass; each vertex is a
// ray from the lamp through that point of the glass, bent into the
// water, out through the rippled surface, and on to the face's plane,
// and the vertex is drawn where it lands. Where the ripples squeeze
// neighbouring rays together the light is brighter, where they spread
// it is dimmer: each vertex carries the area its patch of rays would
// cover under level water over the area it covers now, found by
// tracing its two neighbours along the grid as well, so level water
// gives 1 everywhere it reaches and moving water the caustic net. The
// brightness blends across each triangle, and adds where folds of the
// light overlap.
//
// The landing point is written in homogeneous form, the distance along
// the ray as the w coordinate, so a ray running away from the face is
// clipped by the hardware instead of drawn across it.
render_mode unshaded, blend_add, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, ambient_light_disabled, fog_disabled;

uniform sampler2D ripples : filter_linear, repeat_disable;
uniform vec3 lamp = vec3(0.0, -2.4, 0.0);
uniform float glass_y = -0.4;
uniform float water_y = -0.05;
uniform float pool_half = 4.0;
uniform vec2 pool_centre = vec2(0.0);       // x, z
// The face: its plane is dot(p, n_mask) == plane, facing the room along
// sgn * n_mask; u_mask and v_mask pick the coordinates across it, and
// the texture covers centre +- half in those.
uniform vec3 n_mask = vec3(0.0, 1.0, 0.0);
uniform vec3 u_mask = vec3(1.0, 0.0, 0.0);
uniform vec3 v_mask = vec3(0.0, 0.0, 1.0);
uniform float plane = 10.0;
uniform float sgn = 1.0;
uniform vec2 centre = vec2(0.0);
uniform vec2 half_size = vec2(5.0);
// The face's tile in a texture of three tiles by two, each tile_px square.
uniform ivec2 tile = ivec2(0);
uniform int tile_px = 512;

const float WATER_N = 1.333;

varying float bright;

float height(vec2 xz) {
	return textureLod(ripples, (xz - pool_centre) / (2.0 * pool_half) + 0.5, 0.0).r;
}

// The ray through the glass at xz: where it leaves the water (s), its
// direction out (da, or zero where the surface reflects it all back)
// and its direction under level water (i, which it keeps).
void trace(vec2 xz, out vec3 s, out vec3 da, out vec3 s0, out vec3 i) {
	vec3 g = vec3(xz.x, glass_y, xz.y);
	i = normalize(g - lamp);
	// Glass with parallel faces moves a ray sideways a little and leaves
	// its direction as air to water would. (refract() takes the normal
	// facing the incoming ray, here downward.)
	vec3 dw = refract(i, vec3(0.0, -1.0, 0.0), 1.0 / WATER_N);
	s0 = g + dw * (water_y - glass_y) / dw.y;
	s = g + dw * (water_y + height(s0.xz) - glass_y) / dw.y;
	float e = 2.0 * pool_half / float(textureSize(ripples, 0).x);
	float hx = (height(s.xz + vec2(e, 0.0)) - height(s.xz - vec2(e, 0.0))) / (2.0 * e);
	float hz = (height(s.xz + vec2(0.0, e)) - height(s.xz - vec2(0.0, e))) / (2.0 * e);
	da = refract(dw, -normalize(vec3(-hx, 1.0, -hz)), WATER_N);
}

// Where a ray from p along d meets the face's plane, in the face's
// coordinates.
vec2 meet(vec3 p, vec3 d) {
	vec3 q = p + d * (plane - dot(p, n_mask)) / dot(d, n_mask);
	return vec2(dot(q, u_mask), dot(q, v_mask));
}

float area(vec2 a, vec2 b, vec2 c) {
	vec2 ab = b - a;
	vec2 ac = c - a;
	return abs(ab.x * ac.y - ab.y * ac.x);
}

void vertex() {
	float cell = 2.0 * pool_half / float(textureSize(ripples, 0).x);
	vec3 s, da, s0, i;
	vec3 sx, dax, s0x, ix;
	vec3 sz, daz, s0z, iz;
	trace(VERTEX.xz + pool_centre, s, da, s0, i);
	trace(VERTEX.xz + pool_centre + vec2(cell, 0.0), sx, dax, s0x, ix);
	trace(VERTEX.xz + pool_centre + vec2(0.0, cell), sz, daz, s0z, iz);
	float level = area(meet(s0, i), meet(s0x, ix), meet(s0z, iz));
	bright = 0.0;
	if (dot(da, da) > 0.5 && dot(dax, dax) > 0.5 && dot(daz, daz) > 0.5) {
		float now = area(meet(s, da), meet(sx, dax), meet(sz, daz));
		bright = min(level / max(now, 1e-9), 60.0);
	} else {
		da = i;
	}

	float dn = dot(da, n_mask);
	float reach = plane - dot(s, n_mask);
	float w = sgn * dn;
	float x = sgn * ((dot(s, u_mask) - centre.x) * dn + dot(da, u_mask) * reach) / half_size.x;
	float y = sgn * ((dot(s, v_mask) - centre.y) * dn + dot(da, v_mask) * reach) / half_size.y;
	// Into the face's tile: a third of the width, half the height.
	vec2 tc = vec2(-1.0 + (float(tile.x) + 0.5) * 2.0 / 3.0, -1.0 + float(tile.y) + 0.5);
	POSITION = vec4(tc.x * w + x / 3.0, tc.y * w + y * 0.5, 0.5 * w, w);
}

void fragment() {
	// A ray landing past the face's edge would fall in a neighbour's tile.
	vec2 in_tile = FRAGCOORD.xy / float(tile_px) - vec2(tile);
	if (in_tile.x < 0.0 || in_tile.x > 1.0 || in_tile.y < 0.0 || in_tile.y > 1.0) {
		discard;
	}
	ALBEDO = vec3(isnan(bright) || isinf(bright) ? 0.0 : bright);
}
