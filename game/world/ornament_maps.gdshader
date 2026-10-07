shader_type canvas_item;
// Paints one of the five pictures the east wall's StandardMaterial3D draws
// the ornament from, over the whole wall (24 m square, rows running down),
// by `map`: 0 colour (sRGB), 1 the surface's slope as a normal map (x
// across, y up, z out; the engine's OpenGL convention), 2 roughness (red)
// and metalness (green), 3 height (0 the deepest carving, 1 the front),
// 4 glow (sRGB, a third of the real strength; the material multiplies it
// by 3). The same carving, frieze, vines and materials as the
// custom-shader wall (ornament_sample, ornament_motion). The room paints
// the whole picture once, then only the moving parts again: the point
// painted is worked out from where on the picture it lies, so any
// rectangle drawn with this shader paints its own part.
render_mode blend_disabled;

#include "res://world/ornament_lib.gdshaderinc"

uniform sampler2D carving : filter_linear, repeat_disable;
uniform sampler2D carving_exact : filter_nearest, repeat_disable;
uniform sampler2D frieze : filter_linear, repeat_disable;
uniform sampler2D frieze_exact : filter_nearest, repeat_disable;
uniform float time_s = 0.0;
uniform float write_progress = 1.0;
uniform float ink = 1.0;
uniform int map = 0;

#include "res://world/ornament_motion.gdshaderinc"
#include "res://world/ornament_sample.gdshaderinc"

const float GLOW_SCALE = 3.0;

void fragment() {
	vec2 p = vec2(SCREEN_UV.x, 1.0 - SCREEN_UV.y) * OS_WALL;
	if (map == 3) {
		COLOR = vec4(vec3(height_at(p) / OS_HMAX), 1.0);
	} else if (map == 1) {
		vec2 slope = slope_at(p, 0.008);
		vec3 n = normalize(vec3(-slope.x, -slope.y, 1.0));
		COLOR = vec4(n * 0.5 + 0.5, 1.0);
	} else {
		bool vine;
		float along;
		vec3 mat = material_at(p, vine, along);
		vec3 albedo;
		float metal;
		float rough;
		vec3 glow;
		o_look(mat.x, mat.y, mat.z, p, time_s, write_progress, ink, vine, along, albedo, metal, rough, glow);
		if (map == 0) {
			COLOR = vec4(pow(albedo, vec3(1.0 / 2.2)), 1.0);
		} else if (map == 2) {
			COLOR = vec4(rough, metal, 0.0, 1.0);
		} else {
			COLOR = vec4(pow(clamp(glow / GLOW_SCALE, 0.0, 1.0), vec3(1.0 / 2.2)), 1.0);
		}
	}
}
