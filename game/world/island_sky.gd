class_name IslandSky
extends Node3D
## The cozy island's sky from day through dusk to night: the sun, the
## moon and its light, the stars, and the two skies (the engine's
## physical sky, and its procedural sky in chosen colours). Engine
## features only: lights, sky materials, standard materials and meshes;
## the script sets their values from the sun's and moon's heights.
##
## Sunlight through the air: its colour and strength are worked out from
## how much air it crosses (the air mass, Kasten and Young's formula, 1
## overhead and about 38 at the horizon) and how much each of red, green
## and blue is scattered out on the way (TAU, the clear air's optical
## depth at sea level: blue scatters about three times as much as red).
## So the light weakens and reddens as the sun sinks, and goes out as
## its disc passes below the horizon; moonlight the same way. The sky is
## lit by a second sun of its own, at full strength (the physical sky
## works out the air's dimming and colour itself, and the storybook
## sky's disc stays bright), lighting nothing in the world.
##
## The moon is a ball 3 km off, textured from NASA's maps, kept centred
## on the viewer. A light of its own, aimed as the sun is and lighting
## nothing else (render layer MOON), shows its phase whatever the hour.
## Its light on the world is a second directional light, its strength
## the lit fraction of the disc. Real moonlight is about 400,000 times
## fainter than sunlight; the eye adapts and loses colour, and films
## show night as dimmer and bluer instead, which is done here.
##
## Stars: every star of the Yale Bright Star Catalogue to magnitude 6 as
## a small square always facing the viewer and always the same size on
## screen (a standard material's billboard and fixed-size flags), drawn
## additively, brightness from magnitude and colour from temperature,
## 3.6 km off and kept centred on the viewer. The sky is set as at 9 pm
## on SkyClock's date and latitude and does not turn. The storybook stars
## are the brightest only, larger, as four-pointed sparkles.
##
## The storybook sky's colours, its clouds' tint and the haze's colour
## are blended between key heights of the sun (KEYS).

const MOON := 1 << 10                  # render layer of the moon's ball
const STAR_R := 3600.0
const MOON_D := 3000.0
const SHADOW_REACH := 90.0             # metres from the eye that shadows reach
const TAU_AIR := Vector3(0.12, 0.18, 0.32)
const MOONLIGHT := 0.18                # its energy when full and high
const MOON_COLOUR := Color(0.62, 0.72, 1.0)
const STAR_HOURS := 21.0
# Sun height (degrees); sky top; horizon; clouds (alpha their strength);
# haze.
const KEYS := [
	[-18.0, Color(0.02, 0.035, 0.1), Color(0.05, 0.08, 0.18), Color(0.15, 0.18, 0.28, 0.35), Color(0.04, 0.06, 0.12)],
	[-6.0, Color(0.12, 0.14, 0.36), Color(0.6, 0.42, 0.58), Color(0.55, 0.45, 0.6, 0.6), Color(0.35, 0.3, 0.45)],
	[0.0, Color(0.32, 0.38, 0.72), Color(1.0, 0.62, 0.45), Color(1.0, 0.72, 0.62, 0.8), Color(0.95, 0.72, 0.6)],
	[6.0, Color(0.42, 0.56, 0.86), Color(1.0, 0.82, 0.62), Color(1.0, 0.9, 0.8, 0.8), Color(0.95, 0.85, 0.75)],
	[20.0, Color(0.36, 0.6, 0.92), Color(0.82, 0.88, 0.95), Color(1.0, 1.0, 1.0, 0.8), Color(0.8, 0.86, 0.95)],
]

var sun: DirectionalLight3D
var moonlight: DirectionalLight3D
var sky := Sky.new()
var daylight := 1.0                    # 1 by day, 0 at night, through twilight
var haze_colour := Color.WHITE

var _physical := PhysicalSkyMaterial.new()
var _story := ProceduralSkyMaterial.new()
var _moon: MeshInstance3D
var _moon_real: StandardMaterial3D
var _moon_story: StandardMaterial3D
var _moon_sun: DirectionalLight3D
var _sky_sun: DirectionalLight3D
var _moon_dir := Vector3.UP
var _moon_radius := 1.0
var _stars_real: MultiMeshInstance3D
var _stars_story: MultiMeshInstance3D
var _star_mats: Array[StandardMaterial3D] = []


func _init() -> void:
	name = "IslandSky"
	_physical.ground_color = Color(0.1, 0.16, 0.2)
	_physical.energy_multiplier = 2.5
	_story.sky_curve = 0.12
	_story.sun_angle_max = 20.0
	_story.sun_curve = 0.1
	_story.sky_cover = _clouds()
	sky.sky_material = _physical

	# One shadow map each for the sun and the moon, over SHADOW_REACH:
	# each map means drawing the whole scene again from the light, so two
	# maps (sharp near, coarse far) cost twice as much.
	sun = DirectionalLight3D.new()
	sun.shadow_enabled = true
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = SHADOW_REACH
	sun.shadow_blur = 1.0
	sun.light_cull_mask = 0xFFFFF & ~MOON
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(sun)
	_sky_sun = DirectionalLight3D.new()
	_sky_sun.sky_mode = DirectionalLight3D.SKY_MODE_SKY_ONLY
	add_child(_sky_sun)
	moonlight = DirectionalLight3D.new()
	moonlight.shadow_enabled = true
	moonlight.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moonlight.directional_shadow_max_distance = SHADOW_REACH
	moonlight.light_cull_mask = 0xFFFFF & ~MOON
	# The sky draws the sun's disc and lights the air from it; the moon's
	# own ball stands for the moon in the sky.
	moonlight.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(moonlight)
	_moon_sun = DirectionalLight3D.new()
	_moon_sun.light_cull_mask = MOON
	_moon_sun.light_energy = 2.5
	_moon_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	add_child(_moon_sun)
	_build_moon()
	_build_stars()


## Clouds for the storybook sky: noise mapped round the sky, white above
## a threshold and nothing below, added to the sky's colour.
func _clouds() -> NoiseTexture2D:
	var clouds := NoiseTexture2D.new()
	clouds.width = 1024
	clouds.height = 512
	clouds.seamless = true
	var noise := FastNoiseLite.new()
	noise.seed = 3
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	clouds.noise = noise
	var ramp := Gradient.new()
	ramp.set_color(0, Color(0, 0, 0, 0))
	ramp.set_offset(0, 0.62)
	ramp.set_color(1, Color(1, 1, 1, 1))
	ramp.set_offset(1, 0.72)
	clouds.color_ramp = ramp
	return clouds


func _build_moon() -> void:
	_moon_real = StandardMaterial3D.new()
	_moon_real.albedo_texture = load("res://textures/planet_moon/albedo.jpg") as Texture2D
	_moon_real.normal_enabled = true
	_moon_real.normal_texture = load("res://textures/planet_moon/normal.png") as Texture2D
	_moon_real.roughness = 1.0
	_moon_real.metallic_specular = 0.0
	_moon_story = StandardMaterial3D.new()
	_moon_story.albedo_color = Color(1.0, 0.95, 0.75)
	_moon_story.diffuse_mode = BaseMaterial3D.DIFFUSE_TOON
	_moon_story.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_moon_story.roughness = 0.05
	for m: StandardMaterial3D in [_moon_real, _moon_story]:
		m.disable_fog = true
		m.disable_ambient_light = true
	var ball := SphereMesh.new()
	ball.radius = 1.0
	ball.height = 2.0
	ball.radial_segments = 48
	ball.rings = 24
	_moon = MeshInstance3D.new()
	_moon.mesh = ball
	_moon.layers = MOON
	_moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_moon)


## The stars twice over: as they are, and the storybook's few.
func _build_stars() -> void:
	var data := FileAccess.get_file_as_bytes("res://data/stars.bin")
	var turn := SkyClock.to_world(STAR_HOURS)
	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.25, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.5), Color(1, 1, 1, 0)])
	dot.gradient = fade
	_stars_real = _star_field(data, turn, 6.0, 0.006, dot, false)
	_stars_story = _star_field(data, turn, 4.2, 0.03, _sparkle(), true)


## Stars brighter than `limit`, each a square `size` radians across
## (wider for the brightest), drawn with `tex`.
func _star_field(data: PackedByteArray, turn: Basis, limit: float, size: float,
		tex: Texture2D, story: bool) -> MultiMeshInstance3D:
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	mat.fixed_size = true
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = tex
	mat.disable_fog = true
	mat.disable_receive_shadows = true
	_star_mats.append(mat)
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var picked: Array[Vector4] = []    # direction, magnitude
	var colours: Array[Color] = []
	for i in data.size() / 16:
		var mag := data.decode_float(i * 16 + 8)
		if mag > limit:
			continue
		var dir := (turn * SkyClock.celestial(data.decode_float(i * 16), data.decode_float(i * 16 + 4))).normalized()
		if dir.y < -0.1:
			continue
		picked.append(Vector4(dir.x, dir.y, dir.z, mag))
		colours.append(NightSky._temperature(data.decode_float(i * 16 + 12)))
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = quad
	mm.instance_count = picked.size()
	for i in picked.size():
		var p := picked[i]
		var mag := p.w
		var grow: float
		var bright: float
		var c := colours[i]
		if story:
			grow = 0.7 + 0.25 * clampf(3.0 - mag, 0.0, 4.0)
			bright = clampf(pow(10.0, -0.4 * (mag - 2.5)), 0.3, 1.5)
			c = c.lerp(Color(1.0, 0.95, 0.8), 0.7)
		else:
			grow = 1.0 + 0.25 * clampf(2.5 - mag, 0.0, 4.0)
			bright = clampf(pow(10.0, -0.4 * (mag - 2.0)), 0.03, 6.0)
		mm.set_instance_transform(i, Transform3D(Basis.from_scale(Vector3.ONE * grow),
				Vector3(p.x, p.y, p.z) * STAR_R))
		mm.set_instance_color(i, Color(c.r * bright, c.g * bright, c.b * bright, 1.0))
	var field := MultiMeshInstance3D.new()
	field.multimesh = mm
	field.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	field.custom_aabb = AABB(Vector3.ONE * -STAR_R * 1.2, Vector3.ONE * STAR_R * 2.4)
	add_child(field)
	return field


## A four-pointed sparkle, drawn pixel by pixel into a picture: a soft
## core and two thin crossed rays.
func _sparkle() -> ImageTexture:
	var n := 64
	var img := Image.create(n, n, true, Image.FORMAT_RGBA8)
	for y in n:
		for x in n:
			var u := (x + 0.5) / n * 2.0 - 1.0
			var v := (y + 0.5) / n * 2.0 - 1.0
			var core := exp(-(u * u + v * v) * 30.0)
			var rays := exp(-u * u * 600.0) * maxf(0.0, 1.0 - absf(v)) + exp(-v * v * 600.0) * maxf(0.0, 1.0 - absf(u))
			img.set_pixel(x, y, Color(1, 1, 1, clampf(core + 0.9 * rays, 0.0, 1.0)))
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)


## A direction from its height above the horizon and its bearing from
## north toward east, in degrees; north is -z, east +x.
static func direction(height: float, bearing: float) -> Vector3:
	var h := deg_to_rad(height)
	var b := deg_to_rad(bearing)
	return Vector3(sin(b) * cos(h), sin(h), -cos(b) * cos(h))


## The share of red, green and blue light that crosses the air from a
## body at `height` degrees, against the same body overhead; nothing once
## its disc is below the horizon.
static func through_air(height: float) -> Vector3:
	if height < -1.0:
		return Vector3.ZERO
	var mass := 1.0 / (sin(deg_to_rad(height)) + 0.50572 * pow(height + 6.07995, -1.6364))
	var t := Vector3(exp(-TAU_AIR.x * (mass - 1.0)), exp(-TAU_AIR.y * (mass - 1.0)), exp(-TAU_AIR.z * (mass - 1.0)))
	return t * smoothstep(-1.0, 0.5, height)


## A light given the colour and strength of `energy` passed through the
## air from `height`.
static func _light(light: DirectionalLight3D, to_body: Vector3, height: float, energy: float, tint: Color) -> void:
	var t := through_air(height)
	var top := maxf(t.x, maxf(t.y, t.z))
	light.look_at_from_position(Vector3.ZERO, -to_body, Vector3.UP if absf(to_body.y) < 0.99 else Vector3.FORWARD)
	light.light_energy = energy * t.y
	if top > 0.0:
		light.light_color = Color(tint.r * t.x / top, tint.g * t.y / top, tint.b * t.z / top)
	light.visible = light.light_energy > 0.0005


## Everything set for the sun and moon where they stand.
func set_state(sun_height: float, sun_bearing: float, sun_energy: float, moon_height: float,
		moon_bearing: float, story: bool) -> void:
	var to_sun := direction(sun_height, sun_bearing)
	_light(sun, to_sun, sun_height, sun_energy, Color.WHITE)
	_moon_dir = direction(moon_height, moon_bearing)
	_moon_sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	var lit := (1.0 - to_sun.dot(_moon_dir)) * 0.5
	_light(moonlight, _moon_dir, moon_height, MOONLIGHT * lit, MOON_COLOUR)
	# While the sun is up the moon's light is lost in it; its shadows would
	# only cost.
	moonlight.visible = moonlight.visible and sun_height < 0.0
	_sky_sun.look_at_from_position(Vector3.ZERO, -to_sun, Vector3.UP if absf(to_sun.y) < 0.99 else Vector3.FORWARD)
	_sky_sun.light_energy = sun_energy
	_sky_sun.light_color = Color.WHITE if not story else \
			Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.3), 1.0 - smoothstep(0.0, 12.0, sun_height))
	daylight = smoothstep(-10.0, 8.0, sun_height)

	sky.sky_material = _story if story else _physical
	var key := _key(sun_height)
	_story.sky_top_color = key[1]
	_story.sky_horizon_color = key[2]
	_story.ground_horizon_color = key[2]
	_story.ground_bottom_color = (key[2] as Color).darkened(0.5)
	_story.sky_cover_modulate = key[3]
	haze_colour = key[4]

	# The storybook moon is about three times the real one's half degree.
	_moon_radius = MOON_D * tan(deg_to_rad(0.8 if story else 0.26))
	_moon.material_override = _moon_story if story else _moon_real
	_moon.visible = moon_height > -2.0
	# Stars come out through twilight, the brightest at the sun 2 degrees
	# down, all by 14; moonlight hides the faint ones a little.
	var stars := smoothstep(-2.0, -14.0, sun_height) * (1.0 - 0.4 * lit * float(moon_height > 0.0))
	for m in _star_mats:
		m.albedo_color = Color(1, 1, 1, stars)
	_stars_real.visible = not story and stars > 0.0
	_stars_story.visible = story and stars > 0.0


## The storybook colours at a sun height, blended between the keys.
func _key(height: float) -> Array:
	if height <= KEYS[0][0]:
		return KEYS[0]
	for i in range(1, KEYS.size()):
		var hi: Array = KEYS[i]
		if height <= hi[0]:
			var lo: Array = KEYS[i - 1]
			var f := (height - float(lo[0])) / (float(hi[0]) - float(lo[0]))
			var out := [height]
			for k in range(1, lo.size()):
				out.append((lo[k] as Color).lerp(hi[k], f))
			return out
	return KEYS[-1]


## Moon and stars kept centred on the viewer, the moon's near side
## toward them.
func follow(at: Vector3) -> void:
	_stars_real.position = at
	_stars_story.position = at
	var up := Vector3.UP if absf(_moon_dir.y) < 0.99 else Vector3.FORWARD
	_moon.transform = Transform3D(Basis.looking_at(-_moon_dir, up) * Basis.from_scale(Vector3.ONE * _moon_radius),
			at + _moon_dir * MOON_D)
