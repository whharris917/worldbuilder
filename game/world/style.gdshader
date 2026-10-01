shader_type canvas_item;
// A picture style laid over the finished frame, for comparing looks:
// a ColorRect over the whole screen reads what is drawn under it (the
// 3D world with its mist, water and fireflies) and redraws it.
//   1 oil paint: a Kuwahara filter flattens the picture into brush
//     strokes, the colour a little richer, a canvas weave under it;
//   2 ink and watercolour: a soft wash in few tones on paper, the
//     shapes drawn in brown ink where the picture changes sharply;
//   3 cel: light in four flat bands, colour kept, dark outlines;
//   4 pixel art: a 320-wide picture in a few levels a channel, ordered
//     dither between them;
//   5 old photograph: sepia, a soft lens, grain, the corners dark.
// 0 leaves the frame as it is.

uniform sampler2D screen : hint_screen_texture, filter_linear_mipmap;
uniform int style = 0;

float luma(vec3 c) {
	return dot(c, vec3(0.299, 0.587, 0.114));
}

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec3 tex(vec2 uv) {
	return textureLod(screen, uv, 0.0).rgb;
}

// Sobel on brightness: how sharply the picture changes here.
float edge(vec2 uv, vec2 px) {
	float tl = luma(tex(uv + px * vec2(-1, -1)));
	float t = luma(tex(uv + px * vec2(0, -1)));
	float tr = luma(tex(uv + px * vec2(1, -1)));
	float l = luma(tex(uv + px * vec2(-1, 0)));
	float r = luma(tex(uv + px * vec2(1, 0)));
	float bl = luma(tex(uv + px * vec2(-1, 1)));
	float b = luma(tex(uv + px * vec2(0, 1)));
	float br = luma(tex(uv + px * vec2(1, 1)));
	float gx = -tl - 2.0 * l - bl + tr + 2.0 * r + br;
	float gy = -tl - 2.0 * t - tr + bl + 2.0 * b + br;
	return length(vec2(gx, gy));
}

vec3 kuwahara(vec2 uv, vec2 px) {
	const int R = 4;
	vec3 best = vec3(0.0);
	float best_var = 1.0e9;
	for (int q = 0; q < 4; q++) {
		vec2 dir = vec2(q % 2 == 0 ? -1.0 : 1.0, q < 2 ? -1.0 : 1.0);
		vec3 sum = vec3(0.0);
		vec3 sq = vec3(0.0);
		for (int j = 0; j <= R; j++) {
			for (int i = 0; i <= R; i++) {
				vec3 c = tex(uv + dir * vec2(float(i), float(j)) * px);
				sum += c;
				sq += c * c;
			}
		}
		float n = float((R + 1) * (R + 1));
		vec3 mean = sum / n;
		vec3 v = sq / n - mean * mean;
		float var = v.r + v.g + v.b;
		if (var < best_var) {
			best_var = var;
			best = mean;
		}
	}
	return best;
}

vec3 saturate_by(vec3 c, float s) {
	return mix(vec3(luma(c)), c, s);
}

void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 px = SCREEN_PIXEL_SIZE;
	vec2 pos = FRAGCOORD.xy;
	vec3 c = tex(uv);
	if (style == 1) {
		vec3 k = kuwahara(uv, px * 1.5);
		k = saturate_by(k, 1.25);
		float weave = (sin(pos.x * 1.6) * sin(pos.y * 1.6)) * 0.5 + 0.5;
		k *= 0.95 + 0.07 * weave;
		c = k;
	} else if (style == 2) {
		// The wash: the picture softened, its tones gently grouped, laid
		// thin so the paper lights it, pigment gathering at its edges.
		vec3 wash = vec3(0.0);
		for (int j = -2; j <= 2; j++) {
			for (int i = -2; i <= 2; i++) {
				wash += tex(uv + vec2(float(i), float(j)) * px * 2.5);
			}
		}
		wash /= 25.0;
		vec3 q = floor(wash * 7.0) / 7.0;
		wash = mix(wash, q + smoothstep(0.0, 1.0, fract(wash * 7.0)) / 7.0, 0.6);
		wash = saturate_by(wash, 0.85);
		float grain = hash(floor(pos / 2.0));
		vec3 paper = vec3(0.97, 0.95, 0.89) * (0.95 + 0.05 * grain);
		vec3 col = paper * (1.0 - (1.0 - wash * 1.15) * 0.85);
		float pool = smoothstep(0.08, 0.3, edge(uv, px * 4.0));
		col *= 1.0 - pool * 0.12;
		float ink = smoothstep(0.45, 0.85, edge(uv, px * 1.5)) * (0.6 + 0.4 * grain);
		c = mix(col, vec3(0.22, 0.15, 0.10), ink * 0.8);
	} else if (style == 3) {
		// Light in a few flat bands with soft steps, the colour lifted and
		// richer, outlines where the picture changes sharply.
		vec3 lit = c * 1.35;
		float l = max(luma(lit), 1.0e-4);
		float bands = 4.0;
		float x = pow(l, 0.7) * bands;
		float lq = (floor(x) + smoothstep(0.42, 0.58, fract(x))) / bands;
		vec3 toon = lit / l * pow(lq + 0.08, 1.0 / 0.7);
		toon = saturate_by(toon, 1.45);
		float line = smoothstep(0.35, 0.6, edge(uv, px * 1.2));
		c = mix(toon, vec3(0.05, 0.06, 0.08), line);
	} else if (style == 4) {
		vec2 grid = vec2(320.0, 180.0);
		vec2 cell = floor(uv * grid);
		vec3 p = tex((cell + 0.5) / grid);
		const float bayer[16] = float[](0.0, 8.0, 2.0, 10.0, 12.0, 4.0, 14.0, 6.0, 3.0, 11.0, 1.0, 9.0, 15.0, 7.0, 13.0, 5.0);
		int bi = int(mod(cell.x, 4.0)) + int(mod(cell.y, 4.0)) * 4;
		float d = ((bayer[bi] + 0.5) / 16.0 - 0.5) * 0.6;
		float levels = 8.0;
		vec3 g = pow(p, vec3(1.0 / 1.6));
		g = saturate_by(g, 1.2);
		g = floor(g * (levels - 1.0) + 0.5 + d) / (levels - 1.0);
		c = pow(clamp(g, 0.0, 1.0), vec3(1.6));
	} else if (style == 5) {
		vec3 soft = (tex(uv) * 4.0 + tex(uv + vec2(px.x, 0.0) * 1.5) + tex(uv - vec2(px.x, 0.0) * 1.5)
			+ tex(uv + vec2(0.0, px.y) * 1.5) + tex(uv - vec2(0.0, px.y) * 1.5)) / 8.0;
		float l = luma(soft);
		// Halation: the highlights bleed.
		vec3 glow = textureLod(screen, uv, 3.0).rgb;
		l += max(luma(glow) - 0.6, 0.0) * 0.5;
		l = smoothstep(0.02, 0.95, l);
		l = mix(l, l * l * (3.0 - 2.0 * l), 0.5);
		vec3 sepia = mix(vec3(0.12, 0.08, 0.05), vec3(1.0, 0.92, 0.76), l);
		float grain = hash(pos + fract(TIME) * 91.0) - 0.5;
		sepia += grain * 0.07;
		vec2 v = uv - 0.5;
		sepia *= 1.0 - smoothstep(0.35, 0.85, length(v * vec2(1.3, 1.0)));
		c = sepia;
	}
	COLOR = vec4(c, 1.0);
}
