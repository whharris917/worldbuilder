shader_type spatial;
// The patch of the Shifting Room's front wall where the eye is: a finely
// divided flat plane whose points are moved out of the wall by the height
// in `heights` (red, metres), and whose shading follows the slope stored
// with it (green across, blue up, each as 0.5 + slope / 16), as
// eye_height.gdshader draws them; its alpha says what the surface is.
// The plane lies with its own up axis out of the wall, its x across and its
// z down the wall.
//
// Rock (the wall and the eye's lid): the rough rock scan laid as the rest
// of the front wall's StandardMaterial3D lays it, triplanar in world space
// with the same scale, flip and tangents, so the two meet without a seam.
// The eye: a wet white, a blue iris shaded by the picture (streaks and a
// darker rim), a black pupil, all glossy.
render_mode cull_back;

uniform sampler2D heights : filter_linear, repeat_disable;
uniform sampler2D rock_albedo : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_normal : hint_normal, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_roughness : hint_roughness_r, filter_linear_mipmap, repeat_enable;
uniform sampler2D rock_ao : filter_linear_mipmap, repeat_enable;
uniform float rock_scale = 0.5;         // repeats a metre
uniform vec3 white : source_color = vec3(0.86, 0.83, 0.78);
uniform vec3 iris_dark : source_color = vec3(0.05, 0.12, 0.32);
uniform vec3 iris_light : source_color = vec3(0.30, 0.55, 0.85);
uniform vec3 pupil : source_color = vec3(0.01, 0.01, 0.012);

varying vec3 triplanar_pos;
varying vec3 triplanar_weights;

void vertex() {
	vec4 h = textureLod(heights, UV, 0.0);
	VERTEX.y += h.r;
	// Slope across (x) and up the wall; up is the plane's -z.
	vec2 s = (h.gb - 0.5) * 16.0;
	NORMAL = normalize(vec3(-s.x, 1.0, s.y));
	// The front wall's tangents: world +x and world +y, here the plane's
	// +x and -z, kept square to the moved surface.
	TANGENT = normalize(vec3(1.0, 0.0, 0.0) - NORMAL * NORMAL.x);
	BINORMAL = normalize(vec3(0.0, 0.0, -1.0) + NORMAL * NORMAL.z);
	vec3 world_normal = abs(mat3(MODEL_MATRIX) * NORMAL);
	triplanar_weights = world_normal / dot(world_normal, vec3(1.0));
	triplanar_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz * rock_scale * vec3(1.0, -1.0, 1.0);
}

// A texture laid on three sides and blended by the surface's facing, as
// StandardMaterial3D's triplanar mapping does; a side that adds less than
// 1% is not read, so the flat wall costs one reading, not three.
vec4 triplanar(sampler2D tex) {
	vec4 c = texture(tex, triplanar_pos.xy) * triplanar_weights.z;
	if (triplanar_weights.x > 0.01) {
		c += texture(tex, triplanar_pos.zy * vec2(-1.0, 1.0)) * triplanar_weights.x;
	}
	if (triplanar_weights.y > 0.01) {
		c += texture(tex, triplanar_pos.xz * vec2(1.0, -1.0)) * triplanar_weights.y;
	}
	return c;
}

void fragment() {
	vec4 h = texture(heights, UV);
	vec2 s = (h.gb - 0.5) * 16.0;
	vec3 n = normalize(vec3(-s.x, 1.0, s.y));
	NORMAL = normalize((VIEW_MATRIX * MODEL_MATRIX * vec4(n, 0.0)).xyz);
	float what = h.a;
	if (what < 0.15) {
		ALBEDO = triplanar(rock_albedo).rgb;
		NORMAL_MAP = triplanar(rock_normal).rgb;
		ROUGHNESS = triplanar(rock_roughness).r;
		AO = triplanar(rock_ao).r;
	} else if (what < 0.4) {
		ALBEDO = white;
		ROUGHNESS = 0.2;
	} else if (what < 0.9) {
		float shade = clamp((what - 0.5) / 0.25, 0.0, 1.0);
		ALBEDO = mix(iris_dark, iris_light, shade);
		ROUGHNESS = 0.15;
	} else {
		ALBEDO = pupil;
		ROUGHNESS = 0.1;
	}
}
