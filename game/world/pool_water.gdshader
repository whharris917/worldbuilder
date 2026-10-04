shader_type spatial;
// The pool's water, 30 cm over clear glass. The surface is drawn flat
// (its ripples are millimetres high) and shaded with the ripple grid's
// slope (pool_ripples.gdshader), which bends what is seen through it: the glass, the steel under it and the
// lamp below, read from the screen and dimmed a little by the water,
// red first. The room is reflected at glancing angles by the engine.
render_mode cull_back, depth_draw_always;

uniform sampler2D screen_tex : hint_screen_texture, filter_linear, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform sampler2D ripples : filter_linear, repeat_disable;
uniform float pool_half = 4.0;
// How fast each colour fades through a metre of water.
uniform vec3 absorb = vec3(0.30, 0.06, 0.05);
// What the glass lets through, its edge-green tint.
uniform vec3 glass = vec3(0.90, 0.94, 0.92);
uniform float bend = 0.6;            // how far a slope bends the view, as a fraction of the depth behind

varying vec2 pool_uv;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	pool_uv = w.xz / (2.0 * pool_half) + 0.5;
}

void fragment() {
	float e = 1.0 / float(textureSize(ripples, 0).x);
	float m = 2.0 * pool_half * e;
	float hx = (texture(ripples, pool_uv + vec2(e, 0.0)).r - texture(ripples, pool_uv - vec2(e, 0.0)).r) / (2.0 * m);
	float hz = (texture(ripples, pool_uv + vec2(0.0, e)).r - texture(ripples, pool_uv - vec2(0.0, e)).r) / (2.0 * m);
	vec3 wn = normalize(vec3(-hx, 1.0, -hz));
	NORMAL = normalize((VIEW_MATRIX * vec4(wn, 0.0)).xyz);

	float raw = texture(depth_tex, SCREEN_UV).x;
	vec4 behind_v = INV_PROJECTION_MATRIX * vec4(SCREEN_UV * 2.0 - 1.0, raw, 1.0);
	behind_v.xyz /= behind_v.w;
	float path = max(length(behind_v.xyz) - length(VERTEX), 0.0);
	// The view bent by the slope, in proportion to how far behind the
	// surface the thing seen lies; never onto something in front.
	vec2 off = (VIEW_MATRIX * vec4(hx, 0.0, hz, 0.0)).xy;
	vec2 uv = SCREEN_UV - off * bend * min(path, 3.0) / max(-VERTEX.z, 0.5);
	float raw2 = texture(depth_tex, uv).x;
	vec4 bent_v = INV_PROJECTION_MATRIX * vec4(uv * 2.0 - 1.0, raw2, 1.0);
	bent_v.xyz /= bent_v.w;
	if (length(bent_v.xyz) < length(VERTEX)) {
		uv = SCREEN_UV;
	} else {
		path = max(length(bent_v.xyz) - length(VERTEX), 0.0);
	}
	vec3 seen = textureLod(screen_tex, uv, 0.0).rgb;
	// The water's own depth over the glass, whatever lies further down.
	float wet = min(path, 0.6);
	vec3 through = exp(-absorb * wet) * glass;

	vec3 view = normalize(-VERTEX);
	float fresnel = 0.02 + 0.98 * pow(clamp(1.0 - dot(NORMAL, view), 0.0, 1.0), 5.0);
	EMISSION = seen * through * (1.0 - fresnel);
	ALBEDO = vec3(0.0);
	ROUGHNESS = 0.03;
	SPECULAR = 0.5;
	METALLIC = 0.0;
	ALPHA = 1.0;
}
