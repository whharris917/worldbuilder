shader_type spatial;
// The Shifting Room's rear wall: one flat plane that looks carved deep,
// by parallax occlusion mapping. For each pixel the line of sight is
// followed into the relief (heights from the carving's picture, the
// frieze's picture and the vines worked out here) until it meets the
// carved surface, which is then shaded by its slope and coloured by its
// material. The plane is the relief's front; the deepest carving lies
// HMAX behind it.
//
// Moving here: the gold vines, two to a column, spiralling up the marble
// shafts as they turn, their leaves fluttering and a glint running up
// them; the stars in the forest twinkling, each at its own rate; the
// manuscript's script written glyph by glyph (`write_progress`, from the
// room's script), fresh ink glistening, and faded (`ink`) before it is
// written again. The procession moves in the frieze's picture.
render_mode cull_back;

#include "res://world/ornament_lib.gdshaderinc"

uniform sampler2D carving : filter_linear, repeat_disable;
uniform sampler2D carving_exact : filter_nearest, repeat_disable;
uniform sampler2D frieze : filter_linear, repeat_disable;
uniform sampler2D frieze_exact : filter_nearest, repeat_disable;
uniform float time_s = 0.0;
uniform float write_progress = 1.0;
uniform float ink = 1.0;

const float WALL = 24.0;
const float HMAX = 0.45;
const float COLS[4] = float[4](1.6, 5.2, 18.8, 22.4);
const float CR = 0.55;
const float PITCH = 2.6;                // m of column to one turn of a vine
const float VINE = 0.045;               // the vine's radius
const float TURN = 0.3;                 // rad/s the vines turn round the columns

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec3 lin(vec3 srgb) {
	return pow(srgb, vec3(2.2));
}

vec2 carving_uv(vec2 p) {
	return vec2(p.x / WALL, 1.0 - p.y / WALL);
}

vec2 frieze_uv(vec2 p) {
	return vec2(p.x / WALL, (11.5 - p.y) / 1.8);
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

// The vines' height over the wall at p (0 where none). On a column the
// surface at p faces round by angle phi; a vine at height y is at angle
// alpha(y), turning with time. Unrolled, the column's surface is flat and
// each vine a straight line across it, so the distance from p to the vine
// is the angle between them in metres of surface times the slant. Leaves
// grow alternately either side every 0.5 m along the vine.
float vines(vec2 p, out float along) {
	along = 0.0;
	if (p.y < 3.0 || p.y > 19.7) {
		return 0.0;
	}
	float best = 0.0;
	float slant = CR * TAU / PITCH;     // m round the column per m up
	float norm = sqrt(1.0 + slant * slant);
	for (int i = 0; i < 4; i++) {
		float dx = p.x - COLS[i];
		if (abs(dx) >= CR) {
			continue;
		}
		float s = dx / CR;
		float phi = asin(s);
		float shaft = 0.12 + 0.25 * sqrt(1.0 - s * s);
		for (int k = 0; k < 2; k++) {
			float alpha = p.y * TAU / PITCH + time_s * TURN + float(k) * PI;
			float off = (mod(phi - alpha + PI, TAU) - PI) * CR;
			float across = off / norm;
			float d = abs(across);
			if (d < VINE) {
				float h = shaft + 0.05 * o_rod(d, VINE) / VINE;
				if (h > best) {
					best = h;
					along = p.y;
				}
			}
			// Leaves.
			float arc = p.y * norm + off * slant / norm;
			float n = floor(arc / 0.5);
			float side = mod(n + float(k), 2.0) == 0.0 ? 1.0 : -1.0;
			float flutter = 1.0 + 0.18 * sin(time_s * 1.7 + n * 2.3 + float(i));
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

float height_at(vec2 p) {
	p = clamp(p, vec2(0.0), vec2(WALL));
	float along;
	return max(max(carving_h(p), frieze_h(p)), vines(p, along));
}

void fragment() {
	vec2 p0 = vec2(12.0 - wpos.x, wpos.y);
	vec3 v = normalize(CAMERA_POSITION_WORLD - wpos);
	// The view in the wall's own frame: x across as seen, y up, z out.
	vec3 vt = vec3(-v.x, v.y, -v.z);
	float vz = max(vt.z, 0.15);
	vec2 drift = -vt.xy / vz;           // m along the wall per m into it
	// Fewer steps looking straight on, where the line of sight crosses
	// little of the relief; more at a slant.
	int steps = int(mix(28.0, 10.0, vz));
	float step_d = HMAX / float(steps);
	vec2 p = p0;
	float depth = 0.0;
	vec2 p_prev = p;
	float d_prev = 0.0;
	for (int i = 0; i < 48; i++) {
		if (i >= steps || depth >= HMAX - height_at(p)) {
			break;
		}
		p_prev = p;
		d_prev = depth;
		p += drift * step_d;
		depth += step_d;
	}
	vec2 a = p_prev;
	vec2 b = p;
	float da = d_prev;
	float db = depth;
	for (int i = 0; i < 5; i++) {
		vec2 m = (a + b) * 0.5;
		float dm = (da + db) * 0.5;
		if (dm >= HMAX - height_at(m)) {
			b = m;
			db = dm;
		} else {
			a = m;
			da = dm;
		}
	}
	p = clamp(b, vec2(0.0), vec2(WALL));

	// The surface's slope, from the heights either side.
	float e = 0.008;
	float hx = (height_at(p + vec2(e, 0.0)) - height_at(p - vec2(e, 0.0))) / (2.0 * e);
	float hy = (height_at(p + vec2(0.0, e)) - height_at(p - vec2(0.0, e))) / (2.0 * e);
	vec3 nt = normalize(vec3(-hx, -hy, 1.0));
	vec3 nw = vec3(-nt.x, nt.y, -nt.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	// What is on top here: the carving, a figure, or a vine.
	float hc = carving_h(p);
	float hf = frieze_h(p);
	float along;
	float hv = vines(p, along);
	vec4 c = textureLod(carving_exact, carving_uv(p), 0.0);
	float m = floor(c.g * 16.0);
	float va = c.b;
	float vb = c.a;
	bool vine = false;
	if (hf > hc && hf >= hv) {
		m = floor(textureLod(frieze_exact, frieze_uv(p), 0.0).g * 16.0);
	}
	if (hv > max(hc, hf)) {
		m = M_GOLD;
		vine = true;
	}

	vec3 albedo = vec3(0.5);
	float metal = 0.0;
	float rough = 0.8;
	vec3 glow = vec3(0.0);
	if (m == M_STONE) {
		albedo = lin(vec3(0.60, 0.55, 0.47)) * (0.82 + 0.3 * va) * (0.88 + 0.24 * o_fbm(p * 3.0, 3));
		rough = 0.85;
	} else if (m == M_MARBLE) {
		float vein = o_fbm(p * vec2(1.6, 0.6) + va * 13.0, 4);
		float line = 1.0 - smoothstep(0.0, 0.05, abs(sin((p.y * 0.7 + p.x * 2.0 + 7.0 * vein) * 3.0)));
		albedo = mix(lin(vec3(0.93, 0.91, 0.88)), lin(vec3(0.52, 0.52, 0.56)), line * 0.65);
		rough = 0.12;
	} else if (m == M_WOOD) {
		float grain = 0.5 + 0.5 * sin(vb * 24.0 + o_fbm(vec2(va * 2.0, vb * 6.0), 3) * 7.0);
		albedo = mix(lin(vec3(0.28, 0.16, 0.08)), lin(vec3(0.50, 0.32, 0.17)), grain);
		rough = 0.55;
	} else if (m == M_SILVER) {
		albedo = lin(vec3(0.92, 0.93, 0.95));
		metal = 1.0;
		rough = 0.22;
	} else if (m == M_GOLD) {
		albedo = lin(vec3(1.0, 0.78, 0.36));
		metal = 1.0;
		rough = 0.24;
		if (vine) {
			float glint = pow(max(0.0, sin(along * 2.0 - time_s * 1.5)), 12.0);
			glow = lin(vec3(1.0, 0.8, 0.4)) * glint * 0.6;
		}
	} else if (m == M_LAPIS) {
		albedo = lin(vec3(0.06, 0.10, 0.33)) * (0.75 + 0.5 * o_fbm(p * 2.0, 3));
		rough = 0.35;
		if (o_hash(floor(p * 120.0)) > 0.985) {
			albedo = lin(vec3(1.0, 0.8, 0.4));
			metal = 1.0;
			rough = 0.3;
		}
	} else if (m == M_VELLUM || ((m == M_INK || m == M_RED) && vb > 0.5 && va >= write_progress)) {
		albedo = lin(vec3(0.87, 0.81, 0.66)) * (0.9 + 0.12 * o_fbm(p * 1.5, 3));
		rough = 0.75;
	} else if (m == M_INK || m == M_RED) {
		vec3 colour = m == M_INK ? lin(vec3(0.07, 0.05, 0.04)) : lin(vec3(0.70, 0.16, 0.08));
		vec3 vellum = lin(vec3(0.87, 0.81, 0.66));
		float shown = vb > 0.5 ? ink : 1.0;
		albedo = mix(vellum, colour, shown);
		bool fresh = vb > 0.5 && write_progress - va < 0.004;
		rough = fresh ? 0.08 : 0.5;
	} else if (m == M_BLUE) {
		albedo = lin(vec3(0.10, 0.20, 0.62));
		rough = 0.5;
	} else if (m == M_BLACK) {
		float vein = o_fbm(p * vec2(0.8, 2.5), 4);
		float line = 1.0 - smoothstep(0.0, 0.04, abs(sin((p.x * 1.3 + 9.0 * vein) * 2.0)));
		albedo = mix(lin(vec3(0.035, 0.035, 0.04)), lin(vec3(0.5, 0.5, 0.52)), line * 0.4);
		rough = 0.2;
	} else if (m == M_STAR) {
		albedo = lin(vec3(0.92, 0.93, 0.96));
		metal = 1.0;
		rough = 0.15;
		float twinkle = pow(0.5 + 0.5 * sin(time_s * (1.1 + 2.2 * va) + va * 40.0), 8.0);
		glow = lin(vec3(0.85, 0.9, 1.0)) * twinkle * 3.0;
	}
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = glow;
}
