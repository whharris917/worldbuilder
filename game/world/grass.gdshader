shader_type spatial;
// Meadow grass: tufts of blades, each blade a tapered strip, drawn by
// GrassField in tiles round the camera. A tuft stands on the ground
// read from a data texture (red: height; green: how tall the grass
// grows there; blue: where flowers may bloom), turned and sized by a
// hash of where it stands, so the same tile repeated never repeats.
// Tufts thin out with distance at one rate whatever tile mesh carries
// them, so tiles of different density meet without a seam.
//
// The wind runs over the meadow in gusts: a pattern travelling
// downwind bends the blades, a faster flutter on top, the world's
// gust strength scaling both. The player parts the grass. Light comes
// through the blades from behind (backlight), and their roots sit in
// their own shade.
render_mode cull_disabled;
#include "res://world/grass.gdshaderinc"
