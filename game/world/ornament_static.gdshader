shader_type canvas_item;
// The Shifting Room's rear wall, the carving that does not move, drawn
// once into a picture 24 m square: red the relief's height (metres out
// from the wall's back), green the material ((number + 0.5) / 16, see
// ornament_lib), blue and alpha a value for that material (a block's or a
// column's shade, a star's twinkle phase and size, the order in which the
// manuscript's script is written). Written as is, not blended.
//
// From the bottom: a stone plinth carved with quatrefoils, gold bosses at
// their hearts; ashlar above; between the inner columns a carved-wood
// forest of branching trees on a lapis night sky set with silver stars,
// framed in gold; the frieze's black marble band between gold
// bead-and-reel borders (its figures are drawn each frame elsewhere); a
// manuscript plaque in a gold rope frame, vellum, two columns of
// blackletter-like script (shapes only, nothing to read), an illuminated
// initial in gold on blue, red and blue vines with gold bezants in the
// margins; tall panels of carved wooden tracery in the side bays; four
// fluted marble columns on stone bases with gold rings and gilded leafy
// capitals; above the cornice a blind arcade of pointed arches round a
// rose window of gold, silver and lapis.
render_mode blend_disabled;

#include "res://world/ornament_lib.gdshaderinc"

const float WALL = 24.0;
const float COLS[4] = float[4](1.6, 5.2, 18.8, 22.4);
const float CR = 0.55;

// The plaque's script.
const float TEXT_TOP = 18.9;
const float LINE = 0.3;
const int LINES = 21;
const float GLYPH = 0.13;
const float XH = 0.11;
const vec2 TEXT_COL0 = vec2(7.7, 11.85);
const vec2 TEXT_COL1 = vec2(12.15, 16.3);

void put(inout vec4 r, float h, float m, float a, float b) {
	r = vec4(h, m, a, b);
}

void raise_to(inout vec4 r, float h, float m, float a, float b) {
	if (h > r.x) {
		r = vec4(h, m, a, b);
	}
}

vec4 ashlar(vec2 p) {
	float row = floor(p.y / 0.6);
	float off = mod(row, 2.0) * 0.6;
	float col = floor((p.x + off) / 1.2);
	vec2 local = vec2(mod(p.x + off, 1.2), mod(p.y, 0.6));
	float joint = min(min(local.x, 1.2 - local.x), min(local.y, 0.6 - local.y));
	float h = 0.03 + 0.004 * o_fbm(p * 3.0, 3) - 0.014 * (1.0 - smoothstep(0.004, 0.022, joint));
	return vec4(h, M_STONE, o_hash(vec2(row, col)), 0.0);
}

void plinth(vec2 p, inout vec4 r) {
	if (p.y > 2.45) {
		return;
	}
	float h = 0.09 + 0.003 * o_fbm(p * 4.0, 2);
	float t = (p.y - 2.3) / 0.15;
	if (abs(t) < 1.0) {
		h = max(h, 0.09 + 0.05 * sqrt(1.0 - t * t));
	}
	put(r, h, M_STONE, 0.3, 0.0);
	vec2 q = p - vec2((floor(p.x / 2.4) + 0.5) * 2.4, 1.2);
	float d = 1e3;
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 1.5707963;
		d = min(d, length(q - 0.24 * vec2(cos(a), sin(a))) - 0.27);
	}
	if (d < 0.0) {
		put(r, h - 0.045 * o_bevel(d, 0.04), M_STONE, 0.3, 0.0);
	}
	float boss = length(q) / 0.09;
	if (boss < 1.0) {
		put(r, h - 0.045 + 0.065 * sqrt(1.0 - boss * boss), M_GOLD, 0.0, 0.0);
	}
}

void frieze_ground(vec2 p, inout vec4 r) {
	if (p.y < 9.7 || p.y > 11.5) {
		return;
	}
	put(r, 0.05, M_BLACK, 0.0, 0.0);
	float e = min(p.y - 9.7, 11.5 - p.y);
	if (e < 0.14) {
		float t = (e - 0.07) / 0.07;
		float h = 0.08 + 0.03 * sqrt(max(1.0 - t * t, 0.0));
		// Beads and reels along the border.
		float along = mod(p.x, 0.24);
		vec2 bead = vec2(along - 0.08, e - 0.07);
		float b = length(bead * vec2(0.8, 1.0)) / 0.05;
		if (b < 1.0) {
			h += 0.025 * sqrt(1.0 - b * b);
		}
		vec2 reel = vec2(along - 0.195, e - 0.07);
		float rl = length(reel * vec2(1.6, 1.0)) / 0.035;
		if (rl < 1.0) {
			h += 0.02 * sqrt(1.0 - rl * rl);
		}
		put(r, h, M_GOLD, 0.0, 0.0);
	}
}

// One tree: a trunk forking four times, each branch shorter and thinner,
// turned by its own amount, with a carved leaf-cluster at every tip. Each
// branch's turn comes from a hash of its place in the tree, so the
// branches meet where they fork.
void tree(vec2 p, int index, inout vec4 r) {
	float fi = float(index);
	vec2 root = vec2(7.3 + fi * 1.6 + (o_hash(vec2(fi, 1.0)) - 0.5) * 0.5, 3.6);
	if (abs(p.x - root.x) > 2.3 || p.y < root.y - 0.2) {
		return;
	}
	float len0 = 1.35 + 0.45 * o_hash(vec2(fi, 2.0));
	float lean = (o_hash(vec2(fi, 3.0)) - 0.5) * 0.25;
	for (int level = 0; level < 5; level++) {
		int count = 1 << level;
		for (int k = 0; k < count; k++) {
			vec2 a = root;
			float angle = 1.5708 + lean;
			float len = len0;
			float rad = 0.11;
			vec2 b = a + len * vec2(cos(angle), sin(angle));
			for (int s = 1; s <= level; s++) {
				int node = k >> (level - s);
				int bit = node & 1;
				float turn = 0.32 + 0.38 * o_hash(vec2(fi * 31.0 + float(node), float(s) * 7.0));
				a = b;
				angle += (bit == 0 ? 1.0 : -1.0) * turn;
				len *= 0.72;
				rad *= 0.64;
				b = a + len * vec2(cos(angle), sin(angle));
			}
			vec2 seg = o_segment(p, a, b);
			float rr = rad * mix(1.0, 0.72, seg.y);
			if (seg.x < rr) {
				float prof = sqrt(1.0 - (seg.x / rr) * (seg.x / rr));
				raise_to(r, 0.05 + 0.04 * prof, M_WOOD, seg.y * len + float(level), seg.x / rr);
			}
			if (level == 4) {
				vec2 q = p - b;
				float lobes = 0.14 + 0.035 * sin(atan(q.y, q.x) * 5.0 + fi);
				float leaf = length(q) - lobes;
				if (leaf < 0.0) {
					raise_to(r, 0.055 + 0.03 * o_bevel(leaf, 0.05) + 0.006 * o_noise(q * 60.0), M_WOOD, 0.0, 2.0);
				}
			}
		}
	}
}

void forest(vec2 p, inout vec4 r) {
	vec2 lo = vec2(6.4, 3.2);
	vec2 hi = vec2(17.6, 9.4);
	vec2 c = (lo + hi) * 0.5;
	vec2 hb = (hi - lo) * 0.5;
	float d = o_box(p - c, hb);
	if (d > 0.0) {
		return;
	}
	if (d > -0.16) {
		float t = (d + 0.08) / 0.08;
		bool side = abs(p.x - c.x) > hb.x - 0.16;
		float along = side ? p.y : p.x;
		float h = 0.06 + 0.06 * sqrt(max(1.0 - t * t, 0.0)) + 0.012 * (0.5 + 0.5 * cos(along * 39.27));
		put(r, h, M_GOLD, 0.0, 0.0);
		return;
	}
	put(r, 0.0, M_LAPIS, 0.0, 0.0);
	// Stars: one in most cells of a 42 cm grid, a dome with four rays.
	vec2 cell = floor(p / 0.42);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 cc = cell + vec2(float(i), float(j));
			if (o_hash(cc + 7.3) > 0.72) {
				continue;
			}
			vec2 at = (cc + 0.15 + 0.7 * o_hash2(cc)) * 0.42;
			float size = 0.03 + 0.05 * o_hash(cc + 3.1);
			vec2 q = p - at;
			float rays = min(abs(q.x) * 7.0 + abs(q.y), abs(q.y) * 7.0 + abs(q.x)) - size * 1.7;
			float star = min(length(q) - size * 0.5, rays);
			if (star < 0.0) {
				raise_to(r, 0.008 + 0.02 * o_bevel(star, size * 0.4), M_STAR, o_hash(cc + 1.7), size);
			}
		}
	}
	// The ground, rolling.
	float ground = 3.75 + 0.25 * sin(p.x * 0.9) + 0.12 * sin(p.x * 2.3 + 1.0);
	if (p.y < ground) {
		float h = 0.04 + 0.02 * smoothstep(0.0, 0.3, ground - p.y) + 0.004 * o_fbm(p * 6.0, 2);
		put(r, h, M_WOOD, p.x * 0.3, p.y);
	}
	for (int t = 0; t < 7; t++) {
		tree(p, t, r);
	}
}

// Blackletter-like script: rows of upright strokes (minims) with diamond
// feet and heads, some with ascenders or descenders, hairlines joining
// some pairs, words parted by spaces. Shapes only. Each glyph carries its
// place in the writing order (0 first, 1 last); paragraphs begin in red.
void script(vec2 p, inout vec4 r) {
	int column = -1;
	vec2 span = vec2(0.0);
	if (p.x > TEXT_COL0.x && p.x < TEXT_COL0.y) {
		column = 0;
		span = TEXT_COL0;
	} else if (p.x > TEXT_COL1.x && p.x < TEXT_COL1.y) {
		column = 1;
		span = TEXT_COL1;
	}
	if (column < 0 || p.y > TEXT_TOP || p.y < TEXT_TOP - float(LINES) * LINE) {
		return;
	}
	float line = floor((TEXT_TOP - p.y) / LINE);
	float x0 = span.x;
	// The initial takes the first five lines of the first column.
	if (column == 0 && line < 5.0) {
		x0 = span.x + 1.6;
		if (p.x < x0) {
			return;
		}
	}
	float base = TEXT_TOP - (line + 1.0) * LINE + 0.09;
	float ly = p.y - base;
	float per_line = floor((span.y - span.x) / GLYPH);
	float g = floor((p.x - x0) / GLYPH);
	float lx = mod(p.x - x0, GLYPH);
	vec2 id = vec2(g + float(column) * 100.0, line);
	float kind = o_hash(id);
	if (kind < 0.17) {
		return;                                 // a space
	}
	if (mod(line, 7.0) == 6.0 && g > per_line * 0.55) {
		return;                                 // a paragraph's short last line
	}
	int strokes = 1 + int(o_hash(id + 5.0) * 3.0);
	float ink = 1e3;
	for (int s = 0; s < 3; s++) {
		if (s >= strokes) {
			break;
		}
		float sx = 0.02 + float(s) * 0.038;
		float top = XH;
		float bottom = 0.0;
		if (s == 0 && o_hash(id + 9.0) < 0.25) {
			top = 0.21;
		}
		if (s == strokes - 1 && o_hash(id + 11.0) < 0.15) {
			bottom = -0.08;
		}
		ink = min(ink, o_box(vec2(lx - sx, ly - (top + bottom) * 0.5), vec2(0.0105, (top - bottom) * 0.5)));
		// Diamond foot and head.
		ink = min(ink, abs(lx - sx - 0.006) + abs(ly - bottom) - 0.02);
		ink = min(ink, abs(lx - sx + 0.004) + abs(ly - top) - 0.018);
		if (s > 0 && o_hash(id + float(s) * 3.0) < 0.6) {
			ink = min(ink, o_segment(vec2(lx, ly), vec2(sx - 0.038, XH - 0.012), vec2(sx, XH - 0.004)).x - 0.0035);
		}
	}
	if (ink < 0.0) {
		float order = (float(column) * float(LINES) + line + g / per_line) / (2.0 * float(LINES));
		float m = (mod(line, 7.0) == 0.0 && g < 6.0) ? M_RED : M_INK;
		// Ink stands only a hair proud of the vellum, so a glyph not yet
		// written does not show as an embossed blank; alpha 1 marks it as
		// script, which the wall writes and fades.
		put(r, r.x + 0.0004, m, order, 1.0);
	}
}

// The illuminated initial: blue ground, a red rule round it, a gold
// interlaced knot.
void initial(vec2 p, inout vec4 r) {
	vec2 c = vec2(TEXT_COL0.x + 0.72, TEXT_TOP - 0.74);
	vec2 q = p - c;
	float d = o_box(q, vec2(0.72));
	if (d > 0.0) {
		return;
	}
	put(r, 0.045, M_BLUE, 0.0, 0.0);
	if (d > -0.04) {
		put(r, 0.047, M_RED, 0.0, 0.0);
		return;
	}
	float knot = abs(length(q) - 0.45) - 0.03;
	for (int i = 0; i < 4; i++) {
		float a = float(i) * 1.5707963 + 0.785398;
		knot = min(knot, abs(length(q - 0.3 * vec2(cos(a), sin(a))) - 0.24) - 0.022);
	}
	knot = min(knot, length(q) - 0.08);
	if (knot < 0.0) {
		put(r, 0.05 + 0.02 * o_bevel(knot, 0.02), M_GOLD, 0.0, 0.0);
	}
}

// Margins: a red and blue vine down each side with leaves, gold bezants
// between; a row of bezants along the top and the foot.
void margins(vec2 p, inout vec4 r) {
	for (int side = 0; side < 2; side++) {
		float mid = side == 0 ? 7.34 : 16.66;
		if (abs(p.x - mid) > 0.3 || p.y < 12.3 || p.y > 19.1) {
			continue;
		}
		float vx = mid + 0.11 * sin(p.y * 5.0 + float(side) * 3.0);
		float stem = abs(p.x - vx) - 0.012;
		float colour = mod(floor(p.y * 5.0 / 3.14159), 2.0) == 0.0 ? M_RED : M_BLUE;
		if (stem < 0.0) {
			raise_to(r, 0.043, colour, 0.0, 0.0);
		}
		float at = floor(p.y / 0.63) * 0.63 + 0.315;
		float lean = mod(floor(p.y / 0.63), 2.0) == 0.0 ? 1.0 : -1.0;
		vec2 leaf = p - vec2(mid + 0.11 * sin(at * 5.0 + float(side) * 3.0) + lean * 0.09, at);
		float lf = length(leaf * vec2(1.0, 2.2)) - 0.075;
		if (lf < 0.0) {
			raise_to(r, 0.044, lean > 0.0 ? M_BLUE : M_RED, 0.0, 0.0);
		}
		vec2 bez = p - vec2(mid - lean * 0.12, at + 0.31);
		float bz = length(bez) / 0.035;
		if (bz < 1.0) {
			raise_to(r, 0.045 + 0.012 * sqrt(1.0 - bz * bz), M_GOLD, 0.0, 0.0);
		}
	}
	for (int row = 0; row < 2; row++) {
		float y = row == 0 ? 19.2 : 12.2;
		if (abs(p.y - y) < 0.05 && p.x > 7.6 && p.x < 16.4) {
			vec2 q = vec2(mod(p.x, 0.3) - 0.15, p.y - y);
			float bz = length(q) / 0.035;
			if (bz < 1.0) {
				raise_to(r, 0.045 + 0.012 * sqrt(1.0 - bz * bz), M_GOLD, 0.0, 0.0);
			}
		}
	}
}

void plaque(vec2 p, inout vec4 r) {
	vec2 c = vec2(12.0, 15.7);
	vec2 hb = vec2(5.0, 3.8);
	float d = o_box(p - c, hb);
	if (d > 0.0) {
		return;
	}
	if (d > -0.24) {
		float t = (d + 0.12) / 0.12;
		bool side = abs(p.x - c.x) > hb.x - 0.24;
		float along = side ? p.y : p.x;
		float twist = 0.5 + 0.5 * sin(along * 26.0 + t * 3.0);
		put(r, 0.08 + 0.05 * sqrt(max(1.0 - t * t, 0.0)) + 0.015 * twist, M_GOLD, 0.0, 0.0);
		return;
	}
	put(r, 0.04 + 0.0015 * o_fbm(p * 8.0, 2), M_VELLUM, 0.0, 0.0);
	margins(p, r);
	initial(p, r);
	script(p, r);
}

// Carved wooden tracery in the side bays: stacked pointed arches with a
// trefoil in each, gold bosses at the trefoils' hearts.
void bays(vec2 p, inout vec4 r) {
	for (int i = 0; i < 2; i++) {
		vec2 c = vec2(i == 0 ? 3.4 : 20.6, 11.35);
		vec2 hb = vec2(1.1, 8.15);
		float d = o_box(p - c, hb);
		if (d > 0.0) {
			continue;
		}
		float h = 0.05 + 0.004 * o_fbm(vec2(p.x * 20.0, p.y * 1.5), 2);
		if (d > -0.1) {
			float t = (d + 0.05) / 0.05;
			put(r, 0.08 + 0.02 * sqrt(max(1.0 - t * t, 0.0)), M_WOOD, p.y, 0.0);
			continue;
		}
		put(r, h, M_WOOD, p.y * 0.5, p.x);
		float unit = mod(p.y - 3.2, 2.0375);
		vec2 q = vec2(p.x - c.x, unit - 0.7);
		float arch = o_arch(q, 0.7, 0.55);
		float groove = abs(arch + 0.05) - 0.025;
		if (groove < 0.0) {
			put(r, h - 0.025 * o_bevel(groove, 0.012), M_WOOD, p.y, 0.0);
		}
		vec2 tc = vec2(0.0, 0.5);
		float tre = 1e3;
		for (int k = 0; k < 3; k++) {
			float a = 1.5708 + float(k) * 2.0944;
			tre = min(tre, length(q - tc - 0.19 * vec2(cos(a), sin(a))) - 0.19);
		}
		float tg = abs(tre) - 0.02;
		if (tg < 0.0) {
			put(r, h - 0.02 * o_bevel(tg, 0.01), M_WOOD, p.y, 0.0);
		}
		float boss = length(q - tc) / 0.06;
		if (boss < 1.0) {
			put(r, h + 0.03 * sqrt(1.0 - boss * boss), M_GOLD, 0.0, 0.0);
		}
	}
}

void columns(vec2 p, inout vec4 r) {
	for (int i = 0; i < 4; i++) {
		float dx = p.x - COLS[i];
		if (abs(dx) > 1.0) {
			continue;
		}
		if (p.y >= 2.45 && p.y < 3.0 && abs(dx) < CR * 1.35) {
			put(r, 0.2 + 0.02 * o_bevel(abs(dx) - CR * 1.35, 0.05), M_STONE, 0.5, 0.0);
			float t = (p.y - 2.88) / 0.08;
			if (abs(t) < 1.0 && abs(dx) < CR * 1.2) {
				float s = dx / (CR * 1.2);
				put(r, 0.12 + 0.28 * sqrt(1.0 - s * s) + 0.04 * sqrt(1.0 - t * t), M_GOLD, 0.0, 0.0);
			}
		}
		if (p.y >= 3.0 && p.y < 19.7 && abs(dx) < CR) {
			float s = dx / CR;
			float phi = asin(clamp(s, -1.0, 1.0));
			float h = 0.12 + 0.25 * sqrt(1.0 - s * s) - 0.006 * pow(0.5 + 0.5 * cos(phi * 16.0), 4.0);
			put(r, h, M_MARBLE, float(i) / 4.0, 0.0);
		}
		if (p.y >= 19.7 && p.y < 20.6) {
			float t = (p.y - 19.7) / 0.9;
			float w = CR * mix(1.0, 1.55, t * t);
			if (abs(dx) < w) {
				float s = dx / w;
				float leaf = 0.5 + 0.5 * cos(asin(clamp(s, -1.0, 1.0)) * 7.0);
				float h = 0.12 + 0.27 * sqrt(1.0 - s * s) + 0.035 * leaf * (0.4 + 0.6 * sin(t * 3.14159));
				put(r, h, M_GOLD, 0.0, 0.0);
			}
		}
		if (p.y >= 20.6 && p.y < 20.9 && abs(dx) < CR * 1.75) {
			put(r, 0.36 + 0.015 * o_bevel(abs(dx) - CR * 1.75, 0.03), M_STONE, 0.6, 0.0);
		}
	}
}

void arcade(vec2 p, inout vec4 r) {
	if (p.y < 20.9) {
		return;
	}
	put(r, 0.07 + 0.003 * o_fbm(p * 4.0, 2), M_STONE, 0.7, 0.0);
	if (p.y < 21.1) {
		float t = (p.y - 21.0) / 0.1;
		put(r, 0.1 + 0.03 * sqrt(max(1.0 - t * t, 0.0)), M_STONE, 0.7, 0.0);
		vec2 q = vec2(mod(p.x, 0.16) - 0.08, p.y - 21.0);
		float b = length(q) / 0.045;
		if (b < 1.0) {
			put(r, 0.13 + 0.03 * sqrt(1.0 - b * b), M_GOLD, 0.0, 0.0);
		}
		return;
	}
	vec2 rose = p - vec2(12.0, 22.45);
	float rd = length(rose);
	if (rd < 1.55) {
		put(r, 0.0, M_LAPIS, 0.0, 0.0);
		if (rd > 1.35) {
			float t = (rd - 1.45) / 0.1;
			put(r, 0.08 + 0.03 * sqrt(max(1.0 - t * t, 0.0)), M_GOLD, 0.0, 0.0);
			return;
		}
		float a = atan(rose.y, rose.x);
		float spoke = abs(mod(a + 0.2618, 0.5236) - 0.2618) * rd - 0.018;
		if (spoke < 0.0 && rd > 0.22) {
			put(r, 0.05 + 0.02 * o_bevel(spoke, 0.01), M_SILVER, 0.0, 0.0);
		}
		for (int k = 0; k < 6; k++) {
			float pa = float(k) * 1.0471976;
			float petal = abs(length(rose - 0.85 * vec2(cos(pa), sin(pa))) - 0.36) - 0.022;
			if (petal < 0.0) {
				put(r, 0.07 + 0.02 * o_bevel(petal, 0.01), M_GOLD, 0.0, 0.0);
			}
		}
		float boss = rd / 0.22;
		if (boss < 1.0) {
			put(r, 0.06 + 0.05 * sqrt(1.0 - boss * boss), M_GOLD, 0.0, 0.0);
		}
		return;
	}
	vec2 q = vec2(p.x - (floor(p.x / 1.5) + 0.5) * 1.5, p.y - 21.75);
	float arch = o_arch(q, 0.6, 0.55);
	if (arch < 0.0) {
		put(r, 0.035, M_STONE, 0.75, 0.0);
		vec2 tc = vec2(0.0, 0.42);
		for (int k = 0; k < 3; k++) {
			float a = 1.5708 + float(k) * 2.0944;
			float cusp = abs(length(q - tc - 0.13 * vec2(cos(a), sin(a))) - 0.13) - 0.012;
			if (cusp < 0.0) {
				put(r, 0.06, M_STONE, 0.75, 0.0);
			}
		}
	}
	float rim = abs(arch) - 0.02;
	if (rim < 0.0 && q.y > -0.55) {
		put(r, 0.09 + 0.02 * o_bevel(rim, 0.01), M_GOLD, 0.0, 0.0);
	}
}

vec4 wall(vec2 p) {
	vec4 r = ashlar(p);
	plinth(p, r);
	frieze_ground(p, r);
	forest(p, r);
	plaque(p, r);
	bays(p, r);
	arcade(p, r);
	columns(p, r);
	return r;
}

void fragment() {
	// Picture rows run down; the wall's y runs up.
	vec2 p = vec2(UV.x, 1.0 - UV.y) * WALL;
	vec4 r = wall(p);
	COLOR = vec4(r.x, (r.y + 0.5) / 16.0, r.z, r.w);
}
