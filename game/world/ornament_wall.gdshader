shader_type spatial;
// The Shifting Room's rear wall, the custom-shader version: one flat plane
// that looks carved deep, by parallax occlusion mapping written here. For
// each pixel the line of sight is followed into the relief (the carving's
// picture, the frieze's picture and the vines, ornament_sample) until it
// meets the carved surface, which is then shaded by its slope and
// coloured by its material (ornament_motion). The plane is the relief's
// front; the deepest carving lies OS_HMAX behind it. The east wall shows
// the same ornament through the engine's own material instead
// (ornament_maps.gdshader).
//
// Moving: the gold vines turning up the columns, the stars twinkling, the
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

#include "res://world/ornament_motion.gdshaderinc"
#include "res://world/ornament_sample.gdshaderinc"

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
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
	float step_d = OS_HMAX / float(steps);
	vec2 p = p0;
	float depth = 0.0;
	vec2 p_prev = p;
	float d_prev = 0.0;
	for (int i = 0; i < 48; i++) {
		if (i >= steps || depth >= OS_HMAX - height_at(p)) {
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
		if (dm >= OS_HMAX - height_at(m)) {
			b = m;
			db = dm;
		} else {
			a = m;
			da = dm;
		}
	}
	p = clamp(b, vec2(0.0), vec2(OS_WALL));

	vec2 slope = slope_at(p, 0.008);
	vec3 nt = normalize(vec3(-slope.x, -slope.y, 1.0));
	vec3 nw = vec3(-nt.x, nt.y, -nt.z);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	bool vine;
	float along;
	vec3 mat = material_at(p, vine, along);
	vec3 albedo;
	float metal;
	float rough;
	vec3 glow;
	o_look(mat.x, mat.y, mat.z, p, time_s, write_progress, ink, vine, along, albedo, metal, rough, glow);
	ALBEDO = albedo;
	METALLIC = metal;
	ROUGHNESS = rough;
	EMISSION = glow;
}
