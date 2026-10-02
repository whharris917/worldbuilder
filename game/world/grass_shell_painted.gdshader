shader_type spatial;
// Shell grass painted: the same strands, wind and layers
// (grass_shell.gdshaderinc) in flat tones under soft two-tone light.
render_mode cull_disabled;
#define PAINTED
#include "res://world/grass_shell.gdshaderinc"
#include "res://world/toon.gdshaderinc"
