shader_type spatial;
// The meadow grass as a cartoon: the same blades, wind and parting
// (grass.gdshaderinc), drawn in flat tones under cartoon light.
render_mode cull_disabled;
#define TOON
#include "res://world/grass.gdshaderinc"
#include "res://world/toon.gdshaderinc"
