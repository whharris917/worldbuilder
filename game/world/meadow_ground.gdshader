shader_type spatial;
// The meadow's ground, under and beyond its grass. Vertex colour red is
// the brook's bed, green the forest floor, blue the meadow. Near the
// camera the meadow is the dark thatch and soil the blades stand in;
// with distance, as the blades thin out (grass.gdshader), it takes the
// colour of the grass seen from above, so the meadow carries on to its
// far edge. The forest floor is leaf litter and needles with moss in
// patches; steep banks are bare earth; the bed is gravel and stones.
// World-space throughout, so nothing swims.
#include "res://world/granite.gdshaderinc"

uniform vec3 thatch : source_color = vec3(0.14, 0.15, 0.07);
uniform vec3 meadow_green : source_color = vec3(0.12, 0.17, 0.06);
uniform vec3 meadow_dry : source_color = vec3(0.30, 0.28, 0.16);
uniform vec3 litter : source_color = vec3(0.20, 0.15, 0.09);
uniform vec3 needles : source_color = vec3(0.24, 0.17, 0.10);
uniform vec3 moss : source_color = vec3(0.14, 0.20, 0.07);
uniform vec3 earth : source_color = vec3(0.17, 0.13, 0.09);
// Where the blades have thinned to nothing and the ground stands for them.
uniform float grass_far = 64.0;

varying vec3 world_pos;
varying vec3 world_normal;
varying vec3 tint;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	tint = COLOR.rgb;
}

void fragment() {
	float dist = length(world_pos - CAMERA_POSITION_WORLD);
	vec2 p = world_pos.xz;
	vec3 wn = normalize(world_normal);
	float slope = 1.0 - clamp(wn.y, 0.0, 1.0);
	float bed = tint.r;
	float wood = tint.g;
	float meadow = tint.b;
	float near = clamp(1.0 - dist / 25.0, 0.0, 1.0);

	// The meadow: thatch underfoot, the grass's own colour far off, in
	// the same patches of green and seeding tan the blades wear.
	float dry = smoothstep(0.45, 0.85, value_noise(p * 0.08) * 0.7 + value_noise(p * 0.31 + 4.0) * 0.3);
	vec3 canopy = mix(meadow_green, meadow_dry, dry * 0.7);
	// Drifts of darker and paler grass at every scale, so the far meadow
	// is never a lawn.
	canopy *= 0.7 + 0.35 * value_noise(p * 0.21 + 11.0) + 0.25 * value_noise(p * 0.9) + 0.15 * value_noise(p * 3.7);
	vec3 under = thatch * (0.75 + 0.5 * value_noise(p * 3.0 + 2.0));
	float seen = smoothstep(grass_far * 0.35, grass_far, dist);
	vec3 field = mix(under, canopy, seen);

	// The forest floor: last year's leaves, needles under the pines, moss.
	float m = smoothstep(0.5, 0.8, value_noise(p * 0.15 + 9.0) * 0.7 + value_noise(p * 1.1) * 0.3);
	vec3 floor_col = mix(litter, needles, smoothstep(0.4, 0.7, value_noise(p * 0.05 + 21.0)));
	floor_col *= 0.8 + 0.4 * value_noise(p * 4.0 + 1.0) * (0.4 + 0.6 * near);
	floor_col = mix(floor_col, moss, m * 0.6);

	// Between the two where the meadow thins into the wood: grass going
	// over to litter.
	vec3 color = mix(floor_col, field, clamp(meadow * (1.0 - wood * 0.6), 0.0, 1.0));

	// Banks: bare earth where the ground falls steeply.
	float bank = smoothstep(0.25, 0.5, slope) * (1.0 - bed);
	color = mix(color, earth * (0.8 + 0.4 * value_noise(p * 5.0)), bank);

	// The bed: gravel, rusty and grey, darker where it lies wet.
	vec3 gravel = mix(lin(vec3(0.30, 0.27, 0.22)), lin(vec3(0.42, 0.38, 0.32)), smoothstep(0.4, 0.8, value_noise(p * 7.0)));
	gravel = mix(gravel, lin(vec3(0.33, 0.22, 0.12)), smoothstep(0.55, 0.85, value_noise(p * 2.3 + 5.0)) * 0.6);
	gravel = mix(gravel, lin(vec3(0.20, 0.15, 0.09)), 0.5) * 0.45;
	color = mix(color, gravel, bed);

	ALBEDO = color;
	ROUGHNESS = mix(0.95, 0.75, bed);
	SPECULAR = mix(0.06, 0.3, bed);

	// Relief near the camera: lumps of thatch and litter.
	if (dist < 40.0) {
		float e = 0.04;
		float h0 = value_noise(p * 3.0) * 0.6 + value_noise(p * 17.0) * 0.4;
		float hx = value_noise((p + vec2(e, 0.0)) * 3.0) * 0.6 + value_noise((p + vec2(e, 0.0)) * 17.0) * 0.4;
		float hz = value_noise((p + vec2(0.0, e)) * 3.0) * 0.6 + value_noise((p + vec2(0.0, e)) * 17.0) * 0.4;
		vec2 bump = vec2(hx - h0, hz - h0) * 3.0 * clamp(1.0 - dist / 40.0, 0.0, 1.0);
		NORMAL_MAP = normalize(vec3(-bump.x, -bump.y, 1.0)) * 0.5 + 0.5;
		NORMAL_MAP_DEPTH = 0.5;
	}
}
