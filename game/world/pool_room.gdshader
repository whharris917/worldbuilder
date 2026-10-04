shader_type spatial;
// A face of the pool room, matte plaster. The lamp's light reaches it
// only through the water, so that light is multiplied by the face's
// caustic texture (pool_caustics.gdshader): 1 where level water would
// send it unchanged, more in the bright lines, less between.
render_mode diffuse_lambert, specular_schlick_ggx;

uniform vec3 albedo : source_color = vec3(0.8);
uniform float roughness = 0.9;
uniform sampler2D caustics : filter_linear, repeat_disable;
uniform vec3 u_mask = vec3(1.0, 0.0, 0.0);
uniform vec3 v_mask = vec3(0.0, 0.0, 1.0);
uniform vec2 centre = vec2(0.0);
uniform vec2 half_size = vec2(5.0);
// Where the face's tile lies in the caustic texture.
uniform vec2 tile_origin = vec2(0.0);
uniform vec2 tile_scale = vec2(1.0);

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = albedo;
	ROUGHNESS = roughness;
	SPECULAR = 0.3;
}

void light() {
	vec2 uv = (vec2(dot(world_pos, u_mask), dot(world_pos, v_mask)) - centre) / half_size * 0.5 + 0.5;
	float c = texture(caustics, tile_origin + clamp(uv, 0.002, 0.998) * tile_scale).r;
	DIFFUSE_LIGHT += clamp(dot(NORMAL, LIGHT), 0.0, 1.0) * ATTENUATION * LIGHT_COLOR / PI * c;
}
