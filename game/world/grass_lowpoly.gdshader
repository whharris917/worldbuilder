shader_type spatial;
// The meadow grass as a model's: the same wind and parting
// (grass.gdshaderinc), each blade a flat-lit painted triangle.
render_mode cull_disabled;
#define LOWPOLY
#include "res://world/grass.gdshaderinc"
