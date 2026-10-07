// Reading the Shifting Room's ornament: the carving's picture, the
// frieze's picture and the vines, combined into one height and one
// material at a point of the wall. Shared by ornament_wall.gdshader and
// ornament_maps.gdshader. Include after ornament_lib and ornament_motion,
// in a shader that declares the samplers `carving` (linear),
// `carving_exact` (nearest), `frieze` (linear), `frieze_exact` (nearest)
// and the uniform `time_s`.

const float OS_WALL = 24.0;
const float OS_HMAX = 0.45;             // the deepest carving behind the front

vec2 carving_uv(vec2 p) {
	return vec2(p.x / OS_WALL, 1.0 - p.y / OS_WALL);
}

vec2 frieze_uv(vec2 p) {
	return vec2(p.x / OS_WALL, (11.5 - p.y) / 1.8);
}

float carving_h(vec2 p) {
	return textureLod(carving, carving_uv(p), 0.0).r;
}

// The procession's height, only where the carving shows the frieze's
// black marble ground, so the figures pass behind the columns and the
// side bays' panels.
float frieze_h(vec2 p) {
	if (p.y < 9.7 || p.y > 11.5) {
		return 0.0;
	}
	if (floor(textureLod(carving_exact, carving_uv(p), 0.0).g * 16.0) != M_BLACK) {
		return 0.0;
	}
	return textureLod(frieze, frieze_uv(p), 0.0).r;
}

float height_at(vec2 p) {
	p = clamp(p, vec2(0.0), vec2(OS_WALL));
	float along;
	return max(max(carving_h(p), frieze_h(p)), o_vines(p, time_s, along));
}

// The material on top at p and its values: (material, va, vb); `vine`
// and `along` say whether a vine is on top and how far up it.
vec3 material_at(vec2 p, out bool vine, out float along) {
	float hc = carving_h(p);
	float hf = frieze_h(p);
	float hv = o_vines(p, time_s, along);
	vec4 c = textureLod(carving_exact, carving_uv(p), 0.0);
	vec3 r = vec3(floor(c.g * 16.0), c.b, c.a);
	vine = false;
	if (hf > hc && hf >= hv) {
		r.x = floor(textureLod(frieze_exact, frieze_uv(p), 0.0).g * 16.0);
	}
	if (hv > max(hc, hf)) {
		r.x = M_GOLD;
		vine = true;
	}
	return r;
}

// The surface's slope across and up at p, from the heights either side.
vec2 slope_at(vec2 p, float e) {
	return vec2(height_at(p + vec2(e, 0.0)) - height_at(p - vec2(e, 0.0)),
		height_at(p + vec2(0.0, e)) - height_at(p - vec2(0.0, e))) / (2.0 * e);
}
