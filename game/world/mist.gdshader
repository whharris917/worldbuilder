shader_type spatial;
// Mist lying in a valley: drawn over the whole screen by one quad. For
// each pixel the line of sight from the camera to what it meets (from
// the depth buffer; the sky counts as MAX_RAY away) passes through
// mist whose density falls off exponentially with height over the
// valley floor, and the mist it gathers is integrated exactly along
// that line. So the mist is thin close by and deep over distance,
// fills the low ground and leaves the trees standing out of it, and
// thins as the viewer climbs. It drifts in slow wisps with the wind,
// and glows where the viewer looks toward the sun.
render_mode unshaded, blend_mix, depth_draw_never, depth_test_disabled, cull_disabled, shadows_disabled, fog_disabled;
#include "res://world/granite.gdshaderinc"

const float MAX_RAY = 600.0;

uniform sampler2D depth_tex : hint_depth_texture, filter_nearest;
uniform float density = 0.0;          // per metre, at the valley floor
uniform float floor_y = 0.0;          // the valley floor's height at z = 0
uniform float floor_slope = -0.008;   // its fall per metre of z
uniform float scale_h = 1.2;          // metres over which the mist thins by e
uniform vec3 mist_color : source_color = vec3(0.8, 0.82, 0.85);
uniform vec3 sun_color = vec3(1.0, 0.9, 0.8);
uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec2 wind_dir = vec2(0.8, 0.6);

void vertex() {
	POSITION = vec4(VERTEX.xy, 0.5, 1.0);
}

void fragment() {
	float depth = texture(depth_tex, SCREEN_UV).x;
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, depth);
	vec4 view = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	view.xyz /= view.w;
	vec3 world = (INV_VIEW_MATRIX * vec4(view.xyz, 1.0)).xyz;
	vec3 cam = CAMERA_POSITION_WORLD;
	vec3 ray = world - cam;
	float len = length(ray);
	if (len > MAX_RAY) {
		ray *= MAX_RAY / len;
		len = MAX_RAY;
	}
	float k = 1.0 / scale_h;
	float above = cam.y - (floor_y + floor_slope * cam.z);
	float dy = ray.y;
	float spread = abs(k * dy) > 1.0e-4 ? (1.0 - exp(-k * dy)) / (k * dy) : 1.0;
	// Wisps: the mist thicker and thinner in drifting banks.
	vec2 at = mix(cam.xz, cam.xz + ray.xz, 0.5);
	vec2 drift = normalize(wind_dir) * TIME * 0.4;
	float bank = value_noise(at * 0.025 - drift * 0.025) * 0.7 + value_noise(at * 0.09 - drift * 0.09) * 0.3;
	float optical = density * (0.35 + 1.3 * bank) * exp(-k * max(above, -2.0)) * len * spread;
	float a = 1.0 - exp(-optical);
	float toward = max(dot(normalize(ray), sun_dir), 0.0);
	ALBEDO = mist_color + sun_color * pow(toward, 6.0) * 0.6;
	ALPHA = clamp(a, 0.0, 0.97);
}
