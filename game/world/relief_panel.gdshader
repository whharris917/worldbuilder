shader_type spatial;
// A moving bas-relief (LightPool's two wall panels). The height at each
// point of the panel is smooth noise in three dimensions with time as
// the third: sliding through it, hills swell, sink and drift. Where the
// height is above `threshold` the surface is polished gold, below it
// matte grey metal, with a soft edge between.
//
// Two ways to show the relief, chosen per panel by `displace`:
//  - off: the panel stays flat; only its shading follows the hills
//    (NORMAL tilted by their slope). It looks raised in the light but
//    has a flat outline and casts no shadows of its own.
//  - on: the panel's mesh is fine, and each vertex is moved out by the
//    height; the engine lights, outlines and shadows real geometry.
// Either way the shading's tilt comes from the same formula, so the two
// panels look alike face on.
//
// The noise is gradient noise: random slopes at the corners of a unit
// grid in 3D, blended smoothly between them; three layers of it, each
// finer and fainter, are added (fractal noise). Its positions are in
// metres on the panel divided by `feature_size`.

uniform float phase = 0.0;             // how far through time the noise has moved; summed by the script
uniform float feature_size = 0.6;      // metres to one noise cell
uniform float height = 0.05;           // metres from the lowest point to the highest
uniform float threshold = 0.6;         // height, 0 to 1, above which the surface is gold
uniform vec3 gold : source_color = vec3(1.0, 0.86, 0.57);
uniform vec3 base : source_color = vec3(0.77, 0.78, 0.78);
uniform float gold_roughness = 0.15;
uniform float base_roughness = 0.6;
uniform bool displace = false;

varying vec2 panel_pos;                // metres across and up the panel

vec3 grad3(vec3 p) {
	p = vec3(dot(p, vec3(127.1, 311.7, 74.7)), dot(p, vec3(269.5, 183.3, 246.1)), dot(p, vec3(113.5, 271.9, 124.6)));
	return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}

// Gradient noise, about -1 to 1.
float noise3(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	vec3 u = f * f * f * (f * (f * 6.0 - 15.0) + 10.0);
	return mix(mix(mix(dot(grad3(i + vec3(0, 0, 0)), f - vec3(0, 0, 0)),
	                   dot(grad3(i + vec3(1, 0, 0)), f - vec3(1, 0, 0)), u.x),
	               mix(dot(grad3(i + vec3(0, 1, 0)), f - vec3(0, 1, 0)),
	                   dot(grad3(i + vec3(1, 1, 0)), f - vec3(1, 1, 0)), u.x), u.y),
	           mix(mix(dot(grad3(i + vec3(0, 0, 1)), f - vec3(0, 0, 1)),
	                   dot(grad3(i + vec3(1, 0, 1)), f - vec3(1, 0, 1)), u.x),
	               mix(dot(grad3(i + vec3(0, 1, 1)), f - vec3(0, 1, 1)),
	                   dot(grad3(i + vec3(1, 1, 1)), f - vec3(1, 1, 1)), u.x), u.y), u.z);
}

// The relief's height at a point of the panel, 0 to 1.
float relief(vec2 pos) {
	vec3 p = vec3(pos / feature_size, phase);
	float h = noise3(p) + 0.5 * noise3(p * 2.03 + 17.0) + 0.25 * noise3(p * 4.01 + 31.0);
	return clamp(h / 1.75 * 0.9 + 0.5, 0.0, 1.0);
}

void vertex() {
	panel_pos = VERTEX.xy;
	if (displace) {
		VERTEX.z += relief(panel_pos) * height;
	}
}

void fragment() {
	float e = 0.005;
	float h = relief(panel_pos);
	float hx = (relief(panel_pos + vec2(e, 0.0)) - relief(panel_pos - vec2(e, 0.0))) / (2.0 * e) * height;
	float hy = (relief(panel_pos + vec2(0.0, e)) - relief(panel_pos - vec2(0.0, e))) / (2.0 * e) * height;
	vec3 n = normalize(vec3(-hx, -hy, 1.0));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float g = smoothstep(threshold - 0.02, threshold + 0.02, h);
	ALBEDO = mix(base, gold, g);
	METALLIC = 1.0;
	ROUGHNESS = mix(base_roughness, gold_roughness, g);
}
