// The sway of a cartoon tree's parts, shared by their surface and their
// outline so the two move together: a crown or a cone leans downwind,
// more at its top, each tree on its own slow phase.

uniform float sway = 0.0;          // metres the top of a part leans in a full wind
uniform float wind = 0.3;
uniform vec2 wind_dir = vec2(0.8, 0.6);

vec3 swayed(vec3 vertex, mat4 model, float time) {
	// A part that does not sway, or one scaled flat (whose inverse would
	// be infinite and light the screen with a blot), stays as it is.
	if (sway <= 0.0 || abs(determinant(mat3(model))) < 1.0e-9) {
		return vertex;
	}
	vec3 o = model[3].xyz;
	float phase = o.x * 0.21 + o.z * 0.17;
	float up = clamp(vertex.y + 0.5, 0.0, 1.5);
	float swing = 0.7 + 0.3 * sin(time * (0.9 + 0.6 * wind) + phase) + 0.15 * sin(time * 2.3 + phase * 1.7);
	vec3 push = vec3(wind_dir.x, 0.0, wind_dir.y) * sway * wind * swing * up;
	return vertex + (inverse(model) * vec4(push, 0.0)).xyz;
}
