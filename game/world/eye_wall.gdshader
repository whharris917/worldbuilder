shader_type spatial;
// The patch of the Shifting Room's front wall where the eye is: a finely
// divided flat plane whose points are moved out of the wall by the height
// in `heights` (red, metres), and whose shading follows the slope stored
// with it (green across, blue up, each as 0.5 + slope / 16), as
// eye_height.gdshader draws them; its alpha says what the surface is.
// The plane lies with its own up axis out of the wall, its x across and its
// z down the wall.
//
// Stone (the wall and the eye's lid): rough stone made from noise in world
// space (rough_stone.gdshaderinc), as on the rest of the front wall, so the
// two meet without a seam. The eye: a wet white, a blue iris shaded by the
// picture (streaks and a darker rim), a black pupil, all glossy.
render_mode cull_back;

#include "res://world/rough_stone.gdshaderinc"

uniform sampler2D heights : filter_linear, repeat_disable;
uniform vec3 white : source_color = vec3(0.86, 0.83, 0.78);
uniform vec3 iris_dark : source_color = vec3(0.05, 0.12, 0.32);
uniform vec3 iris_light : source_color = vec3(0.30, 0.55, 0.85);
uniform vec3 pupil : source_color = vec3(0.01, 0.01, 0.012);

varying vec3 world_pos;

void vertex() {
	vec4 h = textureLod(heights, UV, 0.0);
	VERTEX.y += h.r;
	// Slope across (x) and up the wall; up is the plane's -z.
	vec2 s = (h.gb - 0.5) * 16.0;
	NORMAL = normalize(vec3(-s.x, 1.0, s.y));
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec4 h = texture(heights, UV);
	vec2 s = (h.gb - 0.5) * 16.0;
	vec3 n = normalize(vec3(-s.x, 1.0, s.y));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float what = h.a;
	// Worked out before the branch: the bump reads how values change from
	// pixel to pixel, which is undefined inside a branch neighbours differ on.
	vec3 stone_normal = stone_bump(NORMAL, VERTEX, stone_height(world_pos));
	// The label read between its pixels changes smoothly from one region's
	// value to the next, so each boundary is a narrow blend, not a step.
	float to_eye = smoothstep(0.1, 0.2, what);
	float to_iris = smoothstep(0.38, 0.46, what);
	float to_pupil = smoothstep(0.8, 0.95, what);
	float shade = clamp((what - 0.5) / 0.25, 0.0, 1.0);
	vec3 eye = mix(white, mix(iris_dark, iris_light, shade), to_iris);
	eye = mix(eye, pupil, to_pupil);
	float eye_rough = mix(mix(0.2, 0.15, to_iris), 0.1, to_pupil);
	ALBEDO = mix(stone_albedo(world_pos), eye, to_eye);
	ROUGHNESS = mix(stone_roughness(world_pos), eye_rough, to_eye);
	NORMAL = normalize(mix(stone_normal, NORMAL, to_eye));
}
