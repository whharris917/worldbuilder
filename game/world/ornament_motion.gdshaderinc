// The moving parts of the Shifting Room's ornamented walls and the look of
// every material, shared by the custom-shader wall (ornament_wall.gdshader)
// and the pictures painted for the engine-material wall
// (ornament_maps.gdshader), so the two walls draw them alike. Include
// after ornament_lib.gdshaderinc.

const float MO_COLS[4] = float[4](1.6, 5.2, 18.8, 22.4);
const float MO_CR = 0.55;               // the columns' radius
const float MO_PITCH = 2.6;             // m of column to one turn of a vine
const float MO_VINE = 0.045;            // the vine's radius
const float MO_TURN = 0.3;              // rad/s the vines turn round the columns

vec3 o_lin(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

// The vines' height over the wall at p at time t (0 where none). On a
// column the surface at p faces round by angle phi; a vine at height y is
// at angle alpha(y), turning with time. Unrolled, the column's surface is
// flat and each vine a straight line across it, so the distance from p to
// the vine is the angle between them in metres of surface times the
// slant. Leaves grow alternately either side every 0.5 m along the vine,
// fluttering. `along` is how far up the vine p is (over 100 on a leaf).
float o_vines(vec2 p, float t, out float along) {
	along = 0.0;
	if (p.y < 3.0 || p.y > 19.7) {
		return 0.0;
	}
	float best = 0.0;
	float slant = MO_CR * TAU / MO_PITCH;
	float norm = sqrt(1.0 + slant * slant);
	for (int i = 0; i < 4; i++) {
		float dx = p.x - MO_COLS[i];
		if (abs(dx) >= MO_CR) {
			continue;
		}
		float s = dx / MO_CR;
		float phi = asin(s);
		float shaft = 0.12 + 0.25 * sqrt(1.0 - s * s);
		for (int k = 0; k < 2; k++) {
			float alpha = p.y * TAU / MO_PITCH + t * MO_TURN + float(k) * PI;
			float off = (mod(phi - alpha + PI, TAU) - PI) * MO_CR;
			float across = off / norm;
			float d = abs(across);
			if (d < MO_VINE) {
				float h = shaft + 0.05 * o_rod(d, MO_VINE) / MO_VINE;
				if (h > best) {
					best = h;
					along = p.y;
				}
			}
			float arc = p.y * norm + off * slant / norm;
			float n = floor(arc / 0.5);
			float side = mod(n + float(k), 2.0) == 0.0 ? 1.0 : -1.0;
			float flutter = 1.0 + 0.18 * sin(t * 1.7 + n * 2.3 + float(i));
			vec2 leaf = vec2(mod(arc, 0.5) - 0.25, across - side * 0.085) / flutter;
			float l = length(leaf * vec2(1.0 / 0.11, 1.0 / 0.045));
			if (l < 1.0) {
				float h = shaft + 0.03 * sqrt(1.0 - l * l);
				if (h > best) {
					best = h;
					along = p.y + 100.0;
				}
			}
		}
	}
	return best;
}

// The look of material m (with its values va and vb from the carving) at
// p and time t: linear colour, metalness, roughness and glow. Stars
// twinkle; a vine's gold carries a glint running up it; script not yet
// written (its place in the order va beyond `written`) is bare
// vellum, fresh ink glistens, and the ink fades as `ink_level` falls.
void o_look(float m, float va, float vb, vec2 p, float t, float written, float ink_level, bool vine,
		float along, out vec3 albedo, out float metal, out float rough, out vec3 glow) {
	albedo = vec3(0.5);
	metal = 0.0;
	rough = 0.8;
	glow = vec3(0.0);
	if (m == M_STONE) {
		albedo = o_lin(vec3(0.60, 0.55, 0.47)) * (0.82 + 0.3 * va) * (0.88 + 0.24 * o_fbm(p * 3.0, 3));
		rough = 0.85;
	} else if (m == M_MARBLE) {
		float vein = o_fbm(p * vec2(1.6, 0.6) + va * 13.0, 4);
		float line = 1.0 - smoothstep(0.0, 0.05, abs(sin((p.y * 0.7 + p.x * 2.0 + 7.0 * vein) * 3.0)));
		albedo = mix(o_lin(vec3(0.93, 0.91, 0.88)), o_lin(vec3(0.52, 0.52, 0.56)), line * 0.65);
		rough = 0.12;
	} else if (m == M_WOOD) {
		float grain = 0.5 + 0.5 * sin(vb * 24.0 + o_fbm(vec2(va * 2.0, vb * 6.0), 3) * 7.0);
		albedo = mix(o_lin(vec3(0.28, 0.16, 0.08)), o_lin(vec3(0.50, 0.32, 0.17)), grain);
		rough = 0.55;
	} else if (m == M_SILVER) {
		albedo = o_lin(vec3(0.92, 0.93, 0.95));
		metal = 1.0;
		rough = 0.22;
	} else if (m == M_GOLD) {
		albedo = o_lin(vec3(1.0, 0.78, 0.36));
		metal = 1.0;
		rough = 0.24;
		if (vine) {
			float glint = pow(max(0.0, sin(along * 2.0 - t * 1.5)), 12.0);
			glow = o_lin(vec3(1.0, 0.8, 0.4)) * glint * 0.6;
		}
	} else if (m == M_LAPIS) {
		albedo = o_lin(vec3(0.06, 0.10, 0.33)) * (0.75 + 0.5 * o_fbm(p * 2.0, 3));
		rough = 0.35;
		if (o_hash(floor(p * 120.0)) > 0.985) {
			albedo = o_lin(vec3(1.0, 0.8, 0.4));
			metal = 1.0;
			rough = 0.3;
		}
	} else if (m == M_VELLUM || ((m == M_INK || m == M_RED) && vb > 0.5 && va >= written)) {
		albedo = o_lin(vec3(0.87, 0.81, 0.66)) * (0.9 + 0.12 * o_fbm(p * 1.5, 3));
		rough = 0.75;
	} else if (m == M_INK || m == M_RED) {
		vec3 colour = m == M_INK ? o_lin(vec3(0.07, 0.05, 0.04)) : o_lin(vec3(0.70, 0.16, 0.08));
		float shown = vb > 0.5 ? ink_level : 1.0;
		albedo = mix(o_lin(vec3(0.87, 0.81, 0.66)), colour, shown);
		bool fresh = vb > 0.5 && written - va < 0.004;
		rough = fresh ? 0.08 : 0.5;
	} else if (m == M_BLUE) {
		albedo = o_lin(vec3(0.10, 0.20, 0.62));
		rough = 0.5;
	} else if (m == M_BLACK) {
		float vein = o_fbm(p * vec2(0.8, 2.5), 4);
		float line = 1.0 - smoothstep(0.0, 0.04, abs(sin((p.x * 1.3 + 9.0 * vein) * 2.0)));
		albedo = mix(o_lin(vec3(0.035, 0.035, 0.04)), o_lin(vec3(0.5, 0.5, 0.52)), line * 0.4);
		rough = 0.2;
	} else if (m == M_STAR) {
		albedo = o_lin(vec3(0.92, 0.93, 0.96));
		metal = 1.0;
		rough = 0.15;
		float twinkle = pow(0.5 + 0.5 * sin(t * (1.1 + 2.2 * va) + va * 40.0), 8.0);
		glow = o_lin(vec3(0.85, 0.9, 1.0)) * twinkle * 3.0;
	}
}
