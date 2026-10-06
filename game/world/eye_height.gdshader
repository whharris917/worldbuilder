shader_type canvas_item;
// The height of the Shifting Room's eye over the front wall, drawn each
// frame into a picture the wall's shader moves its surface by. A patch of
// wall `patch` metres square; the picture's red is the height out of the
// wall in metres, its green and blue the slope across and up, held to
// -8..8 and stored as 0.5 + slope / 16 so no value is negative (worked out
// here at full precision, so the wall's shading does not step with the
// picture's half-float values). Nothing here is coloured: the eye is shape
// alone, the same grey as the walls.
//
// An eyeball, a sphere of radius `ball`, pushes out through the wall as
// `emerge` goes from 0 to 1 (its centre rising from behind the wall). Over
// it lies a lid, a shell a little larger than the ball on the same centre,
// open in an almond-shaped slit whose height shrinks to nothing as
// `blink` goes to 1; the lid's edge rolls down onto the ball. Where the
// eye meets the wall the two are joined by a smooth fillet, so the wall
// swells round it. On the ball, round the direction it looks (`gaze`, x
// right, y up, z out of the wall), the cornea bulges, a shallow groove
// rings the iris, and the pupil is a dip.

uniform float patch = 8.0;
uniform float ball = 1.6;
uniform float lid_gap = 0.12;           // the lid's shell over the ball
uniform float emerge = 0.0;
uniform float blink = 1.0;
uniform vec3 gaze = vec3(0.0, 0.0, 1.0);

const float SLIT_HALF_WIDTH = 1.45;
const float SLIT_HALF_HEIGHT = 0.85;
const float FILLET = 0.35;

// A maximum with a rounded join k wide.
float smax(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (a - b) / k, 0.0, 1.0);
	return mix(b, a, h) + k * h * (1.0 - h);
}

float height(vec2 p) {
	float centre = emerge * 1.3 - ball;          // the ball's centre, out of the wall
	float r2 = dot(p, p);
	float shell = ball + lid_gap;
	float lid = r2 < shell * shell ? centre + sqrt(shell * shell - r2) : -10.0;
	float eye = lid;
	// The slit: open where |y| is under the almond's half-height at x.
	float across = clamp(abs(p.x) / SLIT_HALF_WIDTH, 0.0, 1.0);
	float half_open = SLIT_HALF_HEIGHT * (1.0 - blink) * pow(1.0 - across * across, 0.8);
	if (r2 < ball * ball && half_open > 0.0) {
		float surface = sqrt(ball * ball - r2);
		vec3 n = vec3(p, surface) / ball;
		float b = centre + surface;
		// Cornea, iris groove, pupil, by the angle from the gaze.
		float angle = acos(clamp(dot(n, normalize(gaze)), -1.0, 1.0));
		b += 0.09 * max(0.0, 1.0 - (angle / 0.42) * (angle / 0.42));
		b -= 0.025 * exp(-pow((angle - 0.42) / 0.03, 2.0));
		b -= 0.05 * (1.0 - smoothstep(0.10, 0.15, angle));
		// The lid's edge rolls onto the ball over 12 cm, with a slight rim.
		float into_lid = (abs(p.y) - half_open) / 0.12;
		float cover = smoothstep(0.0, 1.0, into_lid);
		eye = mix(b, lid, cover) + 0.04 * exp(-into_lid * into_lid * 4.0);
	}
	return smax(eye, 0.0, FILLET);
}

void fragment() {
	// Picture rows run down; y here runs up.
	vec2 p = vec2(UV.x - 0.5, 0.5 - UV.y) * patch;
	float step_m = patch / 1024.0;
	float h = height(p);
	float dx = (height(p + vec2(step_m, 0.0)) - height(p - vec2(step_m, 0.0))) / (2.0 * step_m);
	float dy = (height(p + vec2(0.0, step_m)) - height(p - vec2(0.0, step_m))) / (2.0 * step_m);
	COLOR = vec4(h, 0.5 + clamp(dx, -8.0, 8.0) / 16.0, 0.5 + clamp(dy, -8.0, 8.0) / 16.0, 1.0);
}
