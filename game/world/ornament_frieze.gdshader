shader_type canvas_item;
// The Shifting Room's frieze, drawn each frame into a strip picture that
// covers the band 9.7 to 11.5 m up the rear wall, 24 m long: red the
// height of the procession's figures (0 where there is none; the band's
// black marble ground is in the carving's picture), green their material
// as in ornament_lib. Written as is, not blended.
//
// Thirteen robed figures in silver relief walk along the band at a slow
// pace, wrapping round from one end to the other, their legs striding and
// their arms swinging with each step (a step every 0.55 m). Each carries
// something by turn: a gold staff, a gold lantern held out, a palm frond,
// or nothing, hands raised.
render_mode blend_disabled;

#include "res://world/ornament_lib.gdshaderinc"

uniform float time_s = 0.0;

const float WALL = 24.0;
const float BOTTOM = 9.7;
const float BAND = 1.8;
const float FLOOR = 9.86;
const int FIGURES = 13;
const float SPEED = 0.22;
const float STRIDE = 0.55;
const float GROUND = 0.05;

void raise_to(inout vec2 r, float h, float m) {
	if (h > r.x) {
		r = vec2(h, m);
	}
}

// A rod from a to b of radius rad, its height over the ground.
void rod(vec2 p, vec2 a, vec2 b, float rad, float m, inout vec2 r) {
	float d = o_segment(p, a, b).x;
	if (d < rad) {
		raise_to(r, GROUND + 0.012 + 0.6 * o_rod(d, rad), m);
	}
}

void figure(vec2 p, float x, int kind, inout vec2 r) {
	vec2 q = p - vec2(x, FLOOR);
	if (abs(q.x) > 0.75 || q.y > 1.6) {
		return;
	}
	float phase = x / STRIDE * 3.14159;
	float swing = sin(phase);
	// Feet below the hem, stepping.
	for (int f = 0; f < 2; f++) {
		float side = f == 0 ? 1.0 : -1.0;
		vec2 foot = q - vec2(side * swing * 0.11 + 0.03, 0.04 + 0.03 * max(0.0, side * cos(phase)));
		float fd = length(foot * vec2(1.0, 2.2)) - 0.07;
		if (fd < 0.0) {
			raise_to(r, GROUND + 0.02 + 0.015 * o_bevel(fd, 0.03), M_SILVER);
		}
	}
	// The robe: a gown widening to the hem, swaying a little, its folds
	// running down.
	float t = clamp((q.y - 0.16) / 0.9, 0.0, 1.0);
	float half_w = mix(0.24 + 0.02 * swing, 0.12, t);
	float robe = max(abs(q.x - 0.02 * swing * (1.0 - t)) - half_w, max(0.16 - q.y, q.y - 1.06));
	if (robe < 0.0) {
		float folds = 0.004 * sin((q.x - 0.02 * swing) * 70.0) * (1.0 - t);
		raise_to(r, GROUND + 0.02 + 0.03 * o_bevel(robe, 0.05) + folds, M_SILVER);
	}
	// Head and hood.
	vec2 head = q - vec2(0.03, 1.18);
	float hd = length(head) / 0.09;
	if (hd < 1.0) {
		raise_to(r, GROUND + 0.03 + 0.035 * sqrt(1.0 - hd * hd), M_SILVER);
	}
	vec2 shoulder = vec2(0.02, 1.0);
	if (kind == 3) {
		// Hands raised before the face.
		rod(q, shoulder, vec2(0.14, 1.12), 0.03, M_SILVER, r);
		rod(q, vec2(0.14, 1.12), vec2(0.17, 1.26), 0.026, M_SILVER, r);
		return;
	}
	float arm = -swing * 0.45;
	vec2 elbow = shoulder + 0.24 * vec2(sin(arm), -cos(arm));
	vec2 hand = elbow + 0.22 * vec2(sin(arm + 0.5), -cos(arm + 0.5));
	if (kind == 1) {
		hand = shoulder + vec2(0.36, -0.08);
		elbow = shoulder + vec2(0.18, -0.12);
	}
	rod(q, shoulder, elbow, 0.032, M_SILVER, r);
	rod(q, elbow, hand, 0.028, M_SILVER, r);
	if (kind == 0) {
		rod(q, hand + vec2(0.0, -0.75), hand + vec2(0.0, 0.55), 0.016, M_GOLD, r);
		float knob = length(q - hand - vec2(0.0, 0.58)) / 0.04;
		if (knob < 1.0) {
			raise_to(r, GROUND + 0.02 + 0.03 * sqrt(1.0 - knob * knob), M_GOLD);
		}
	} else if (kind == 1) {
		vec2 lamp = q - hand - vec2(0.0, -0.12);
		float lb = o_box(lamp, vec2(0.05, 0.07));
		if (lb < 0.0) {
			raise_to(r, GROUND + 0.02 + 0.025 * o_bevel(lb, 0.02), M_GOLD);
		}
		rod(q, hand, hand + vec2(0.0, -0.05), 0.008, M_GOLD, r);
	} else {
		// A palm frond: a curved stem with leaflets.
		vec2 tip = hand + vec2(0.2, 0.42);
		rod(q, hand, tip, 0.012, M_SILVER, r);
		vec2 s = o_segment(q, hand, tip);
		if (s.y > 0.3 && s.x < 0.07) {
			vec2 dir = normalize(tip - hand);
			float along = dot(q - hand, dir);
			float leaflet = abs(fract(along * 14.0) - 0.5);
			if (leaflet < 0.18) {
				raise_to(r, GROUND + 0.018, M_SILVER);
			}
		}
	}
}

void fragment() {
	vec2 p = vec2(UV.x * WALL, BOTTOM + (1.0 - UV.y) * BAND);
	vec2 r = vec2(0.0, M_BLACK);
	float spacing = WALL / float(FIGURES);
	for (int i = 0; i < FIGURES; i++) {
		float x = mod(float(i) * spacing + time_s * SPEED, WALL);
		figure(p, x, i % 4, r);
		figure(p, x - WALL, i % 4, r);
		figure(p, x + WALL, i % 4, r);
	}
	COLOR = vec4(r.x, (r.y + 0.5) / 16.0, 0.0, 1.0);
}
