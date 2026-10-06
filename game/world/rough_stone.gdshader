shader_type spatial;
// The Shifting Room's front wall: rough stone made from noise in world
// space (rough_stone.gdshaderinc), the same stone as the eye's patch.

#include "res://world/rough_stone.gdshaderinc"

varying vec3 world_pos;

void vertex() {
	world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	ALBEDO = stone_albedo(world_pos);
	ROUGHNESS = stone_roughness(world_pos);
	NORMAL = stone_bump(NORMAL, VERTEX, stone_height(world_pos));
}
