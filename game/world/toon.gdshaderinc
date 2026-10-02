// Cartoon light, for a spatial shader to include: each light gives two
// flat tones, lit and in shade, with a narrow soft step between them;
// shadows fall the same way, as flat shapes. No highlights; a thin rim
// of light on the edges turned from the viewer, on the lit side. The
// shade is what the world's ambient light leaves, so the sky sets its
// colour.

uniform float toon_step = 0.08;    // how soft the line between lit and shade

void light() {
	float ndl = dot(NORMAL, LIGHT);
	float shadow = smoothstep(0.3, 0.6, ATTENUATION);
	float lit = smoothstep(0.0, toon_step, ndl) * shadow;
	DIFFUSE_LIGHT += LIGHT_COLOR * lit / PI;
	float rim = smoothstep(0.66, 0.74, 1.0 - max(dot(NORMAL, VIEW), 0.0)) * smoothstep(0.0, 0.3, ndl);
	DIFFUSE_LIGHT += LIGHT_COLOR * rim * shadow * 0.35 / PI;
}
