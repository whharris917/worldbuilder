shader_type sky;
// A physical atmosphere: single scattering of sunlight, worked out along
// each line of sight. The observer stands 2 m up on an Earth of radius
// 6,360 km under 100 km of air. The line of sight is cut into steps; at
// each, the sunlight arriving there (less what the air took out on the
// way, and none if the Earth stands between it and the sun) is scattered
// toward the eye by the air (Rayleigh, as wavelength^-4) and by haze
// (Mie, strongly forward), and loses more on its way to the eye.
// Ozone, a layer centred at 25 km, absorbs but does not scatter: across
// the long paths of twilight it takes out orange and leaves the zenith
// blue and the high sky purple. Twilight and the Earth's shadow come of
// themselves from the shadow test.
//
// Coefficients per metre for red, green and blue: Rayleigh at sea level
// (5.802, 13.558, 33.1) e-6 with an 8 km scale height; haze 3.996e-6
// scattering and 4.40e-6 extinction with a 1.2 km scale height; ozone
// absorption (0.650, 1.881, 0.085) e-6 at its peak, a layer 30 km thick.
// The result is radiance per unit of sunlight above the air, times
// sun_illuminance, in the scene's units.

uniform vec3 sun_dir = vec3(0.0, 0.7, -0.7);        // toward the sun
uniform float sun_illuminance = 1.0;                // the sun's light above the air, scene units
uniform float rayleigh_scale = 1.0;                 // air density against the standard atmosphere
uniform float mie_scale = 1.0;                      // haze against a clear day's
uniform float ozone_scale = 1.0;
uniform float mie_g : hint_range(0.0, 0.99) = 0.8; // how forward the haze scatters
uniform vec4 ground_color : source_color = vec4(0.10, 0.11, 0.08, 1.0);

const float R_EARTH = 6360e3;
const float R_AIR = 6460e3;
const vec3 RAYLEIGH = vec3(5.802e-6, 13.558e-6, 33.1e-6);
const float H_RAYLEIGH = 8000.0;
const float MIE_SCATTER = 3.996e-6;
const float MIE_EXTINCT = 4.40e-6;
const float H_MIE = 1200.0;
const vec3 OZONE = vec3(0.650e-6, 1.881e-6, 0.085e-6);
const int VIEW_STEPS = 16;
const int SUN_STEPS = 8;
const float SUN_COS = 0.99999;                      // the sun's disc, 0.5 degrees across (generously)
const float SUN_SOLID_ANGLE = 6.8e-5;               // steradians

// Where a ray from ro along rd meets a sphere about the Earth's centre:
// near and far distances, both -1 when it misses.
vec2 sphere(vec3 ro, vec3 rd, float r) {
	float b = dot(ro, rd);
	float c = dot(ro, ro) - r * r;
	float d = b * b - c;
	if (d < 0.0) {
		return vec2(-1.0);
	}
	float s = sqrt(d);
	return vec2(-b - s, -b + s);
}

// Rayleigh, haze and ozone densities at a height, against their peaks.
vec3 densities(float h) {
	return vec3(exp(-h / H_RAYLEIGH), exp(-h / H_MIE), max(0.0, 1.0 - abs(h - 25000.0) / 15000.0));
}

vec3 extinction(vec3 d) {
	return RAYLEIGH * rayleigh_scale * d.x + MIE_EXTINCT * mie_scale * d.y + OZONE * ozone_scale * d.z;
}

void sky() {
	vec3 rd = EYEDIR;
	vec3 ro = vec3(0.0, R_EARTH + 2.0, 0.0);
	vec3 sun = normalize(sun_dir);
	float t_end = sphere(ro, rd, R_AIR).y;
	float t_ground = sphere(ro, rd, R_EARTH).x;
	bool ground = t_ground > 0.0;
	if (ground) {
		t_end = t_ground;
	}
	float ds = t_end / float(VIEW_STEPS);
	float mu = dot(rd, sun);
	float phase_r = 3.0 / (16.0 * PI) * (1.0 + mu * mu);
	float g = mie_g;
	float phase_m = 3.0 / (8.0 * PI) * ((1.0 - g * g) * (1.0 + mu * mu))
		/ ((2.0 + g * g) * pow(max(1.0 + g * g - 2.0 * g * mu, 1e-4), 1.5));
	vec3 light = vec3(0.0);
	vec3 depth = vec3(0.0);                         // optical depth from the eye so far
	for (int i = 0; i < VIEW_STEPS; i++) {
		vec3 p = ro + rd * ds * (float(i) + 0.5);
		vec3 d = densities(length(p) - R_EARTH);
		vec3 ext = extinction(d) * ds;
		depth += ext * 0.5;
		if (sphere(p, sun, R_EARTH).x <= 0.0) {
			float dl = sphere(p, sun, R_AIR).y / float(SUN_STEPS);
			vec3 sun_depth = vec3(0.0);
			for (int j = 0; j < SUN_STEPS; j++) {
				vec3 q = p + sun * dl * (float(j) + 0.5);
				sun_depth += extinction(densities(length(q) - R_EARTH)) * dl;
			}
			light += exp(-(depth + sun_depth))
				* (RAYLEIGH * rayleigh_scale * d.x * phase_r + MIE_SCATTER * mie_scale * d.y * phase_m) * ds;
		}
		depth += ext * 0.5;
	}
	if (ground) {
		// The ground below the horizon, lit by the sun through the air.
		light += exp(-depth) * ground_color.rgb * max(sun.y, 0.0) / PI;
	} else if (mu > SUN_COS) {
		light += exp(-depth) / SUN_SOLID_ANGLE * smoothstep(SUN_COS, SUN_COS + 0.000004, mu);
	}
	COLOR = light * sun_illuminance * PI;
}
