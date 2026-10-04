shader_type spatial;
// The pool's glass, opaque, showing what lies behind it. A second camera
// at the eye renders the scene without the pane (LightPool, `_portal`),
// so each point of the pane looks up the pixel of that picture at its
// own place on the screen and gives it off as light, dimmed by the
// glass's opacity; the glass's own colour shows by the opacity and is lit
// like any surface. The picture is untonemapped, so the screen's tone
// curve applies once.
render_mode cull_back;

uniform sampler2D behind : filter_linear, repeat_disable;
uniform vec3 tint : source_color = vec3(0.88, 0.95, 0.92);
uniform float opacity = 0.1;
uniform float roughness = 0.05;
uniform float specular = 0.5;

void fragment() {
	ALBEDO = tint * opacity;
	ROUGHNESS = roughness;
	SPECULAR = specular;
	EMISSION = texture(behind, SCREEN_UV).rgb * (1.0 - opacity);
}
