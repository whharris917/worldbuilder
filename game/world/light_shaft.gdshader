shader_type spatial;
// The burning glass's shaft of light in the room's dusty air (BurningGlass):
// a shell round the lit volume, added to what is behind it. A lit volume
// looks brightest where a look crosses most of it, through its middle,
// and fades to nothing at its edges, so each part of the shell counts by
// how squarely it faces the eye; seen edge-on it adds nothing, and the
// shell's edges leave no lines.
render_mode unshaded, cull_disabled, depth_draw_never, fog_disabled, blend_add, shadows_disabled;

uniform vec3 color : source_color = vec3(1.0, 0.92, 0.75);
uniform float strength = 0.0;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = color * strength * pow(facing, 1.5);
}
