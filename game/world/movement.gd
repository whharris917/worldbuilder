extends Node3D
## Five vast bowls of stone turning about one point in the air, and the
## player standing at that point, for studying movement: One Bulb's hills
## far below, lit by its far sun under its Atmosphere sky. The hills and
## grass as One Bulb was last set (hills 53 m high and 350 m across,
## ruggedness 0.29, seed 58). Godot's default shading; no WorldBase.
##
## The bowls (SpinningShell): each the cap left of a spherical shell when
## a ribbon a fifth of its radius wide is cut round its middle and one
## half removed, 100 to 500 m in radius about a centre 650 m up, so the
## largest clears the ground by 150 m. Each turns once in 5 to 30 s
## (drawn at random for each bowl on arrival) about an axis drawn afresh
## every 10 s, all five at once; rings of small lights on their insides
## flare as they jolt.
##
## The player stands on a platform at the centre: a disc of dark polished
## stone 8 m across, tapering below to a point, its top 1.6 m under the
## centre so the eye is at the centre, with a line of light round it an
## arm's length in from the edge, which flares as each bowl's groan
## reaches the centre. Off the edge, the fall is caught 40 m down: the
## screen fades to black and the player is put back at the centre.
##
## The air is drawn as Godot's volumetric fog, thin and lit by the sun
## alone, so the sunlight shows as shafts through the gaps. What can be
## heard is worked out from the bowls' positions (ShellAcoustics): the
## footsteps' echoes focused back on the centre, each bowl's groan
## arriving after the time sound takes to cross it, its hum from where it
## is open to the ear, a chord when the sun breaks through to the centre,
## and the wind.
##
## Two panels of controls (BenchPanel; Esc frees the mouse), kept in
## user://movement.json. Sun, as One Bulb sets it: its polar angle and
## azimuth, its energy, and whether the air colours its light; and how
## far from the player shadows are drawn. Sky: the atmosphere's air, haze
## and ozone against Earth's, from none to many times as much, and how
## forward the haze scatters.

const SHELL_CENTRE := Vector3(0, 650, 3)
const START := SHELL_CENTRE - Vector3(0, 1.6, 0)   # the eye at the centre
const PLATFORM_R := 4.0
const FALL_LIMIT := 40.0                # m below the platform: put back
const STATE_PATH := "user://movement.json"

# The atmosphere as atmosphere_sky.gdshader has it, for the sunlight
# that reaches the ground: per metre for red, green and blue.
const R_EARTH := 6360e3
const R_AIR := 6460e3
const RAYLEIGH := Vector3(5.802e-6, 13.558e-6, 33.1e-6)
const H_RAYLEIGH := 8000.0
const MIE_EXTINCT := 4.40e-6
const H_MIE := 1200.0
const OZONE := Vector3(0.650e-6, 1.881e-6, 0.085e-6)
const SHELL_RADII: Array[float] = [100.0, 170.0, 260.0, 370.0, 500.0]
const SKY_PARAMS := {"Air density": "rayleigh_scale", "Haze": "mie_scale", "Ozone": "ozone_scale",
	"Haze forward": "mie_g"}

var _debanding_was := false
var _panel: BenchPanel
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial
var _env: Environment
var _rim_mat: StandardMaterial3D
var _rim_glow := 0.0                    # extra glow on the platform's rim, fading
var _fade: ColorRect
var _shells: Array[SpinningShell] = []
var _acoustics: ShellAcoustics
var _falling := -1.0                    # s since the fade out began; below 0, none


func _ready() -> void:
	var player := $Player as Player
	player.global_position = START
	var vp := get_viewport()
	_debanding_was = vp.use_debanding
	vp.use_debanding = true
	_build_sky()
	_build_sun()
	_build_ground()
	_build_shells()
	_build_platform()
	_build_fade()
	_acoustics = ShellAcoustics.new()
	_acoustics.shells = _shells
	_acoustics.centre = SHELL_CENTRE
	_acoustics.player = player
	_acoustics.heard.connect(func(_k: int) -> void: _rim_glow = 4.0)
	add_child(_acoustics)
	_build_panel()
	_panel.restore()
	_place_sun()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] movement: %d bowls about the platform, sun, atmosphere sky" % _shells.size())


## One Bulb's Atmosphere sky (`atmosphere_sky.gdshader`: sunlight
## scattered by the air and by haze and absorbed by ozone, worked out
## along each line of sight) at the standard atmosphere, as the
## background, the ambient light and what glossy surfaces reflect.
func _build_sky() -> void:
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = load("res://world/atmosphere_sky.gdshader") as Shader
	var sky := Sky.new()
	sky.sky_material = _sky_mat
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	# The air between the bowls, lit by the sun alone, so it shows where
	# the sunlight runs: shafts through the gaps, the shade behind the
	# stone. Its light scatters forward, brightest looking toward the sun.
	env.volumetric_fog_enabled = true
	env.volumetric_fog_density = 0.0025
	env.volumetric_fog_albedo = Color(0.9, 0.92, 0.95)
	env.volumetric_fog_anisotropy = 0.6
	env.volumetric_fog_length = 700.0
	env.volumetric_fog_ambient_inject = 0.0
	env.volumetric_fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.6
	env.glow_bloom = 0.02
	_env = env
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)


## The sun infinitely far: a directional light, every ray parallel. It
## lights the ground only; the sky draws its own sun from the same
## direction.
func _build_sun() -> void:
	_sun = DirectionalLight3D.new()
	_sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	_sun.shadow_enabled = true
	add_child(_sun)


func _build_panel() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var sun := _panel.panel("Sun")
	var place := func(_v: Variant) -> void: _place_sun()
	_panel.slider(sun, "Polar angle", 0.0, 180.0, 1.0, 50.0, place)
	_panel.note(sun, "From straight up: 0 overhead, 90 on the horizon, beyond 90 below it.")
	_panel.slider(sun, "Azimuth", 0.0, 360.0, 1.0, 200.0, place)
	_panel.note(sun, "Around the horizon from straight ahead at the start: 90 to the right, 180 behind.")
	_panel.slider(sun, "Sun energy", 0.0, 4.0, 0.01, 1.0, place)
	_panel.note(sun, "Light on a surface facing the sun, above the air.")
	_panel.switch(sun, "Atmosphere dims and reddens the sun", true, place)
	_panel.note(sun, "The beam loses light on its way through the atmosphere, worked out from the Sky panel's air, haze and ozone, as the sky is: on Earth, overhead the sun keeps most of its light; low, it turns orange and red and fades; set, it gives none.")
	_panel.slider(sun, "Shadow distance (m)", 100.0, 2000.0, 10.0, 1200.0, func(v: float) -> void:
		_sun.directional_shadow_max_distance = v)
	_panel.note(sun, "Shadows are drawn only this far from you; beyond it everything is drawn in sunlight. The biggest bowl's shadow is a kilometre across, so to see its edge from beneath it this must reach past the edge. Farther costs more time a frame (watch the count at the top right) and blurs the shadows near you, which share the same shadow map.")

	var sky := _panel.panel("Sky")
	for spec: Array in [["Air density", 0.0, 20.0, 0.01, 1.0], ["Haze", 0.0, 100.0, 0.1, 1.0],
			["Ozone", 0.0, 20.0, 0.01, 1.0], ["Haze forward", 0.0, 0.95, 0.01, 0.8]]:
		var param := str(SKY_PARAMS[spec[0]])
		_panel.slider(sky, str(spec[0]), float(spec[1]), float(spec[2]), float(spec[3]), float(spec[4]),
			func(v: float) -> void:
				_sky_mat.set_shader_parameter(param, v)
				_place_sun())
	_panel.note(sky, "Each against Earth's on a clear day, which is 1. Air density: the gas itself, which scatters blue most, so more air gives a deeper blue overhead and redder sunsets, and none a black sky by day. Haze: dust and droplets low down, which scatter all colours alike, whitening the sky and dimming the sun. Ozone: a layer high up that takes out orange and yellow, turning twilight purple. Haze forward: how much of the haze's light goes on in the sun's direction, making a bright glow round the sun.")
	_panel.button(sky, "Back to Earth", func() -> void:
		for title: String in ["Air density", "Haze", "Ozone"]:
			(_panel.sliders[title] as HSlider).value = 1.0
		(_panel.sliders["Haze forward"] as HSlider).value = 0.8)


## Unit vector toward the sun.
func _sun_dir() -> Vector3:
	var polar := deg_to_rad(float((_panel.sliders["Polar angle"] as HSlider).value))
	var azimuth := deg_to_rad(float((_panel.sliders["Azimuth"] as HSlider).value))
	return Vector3(sin(polar) * sin(azimuth), cos(polar), -sin(polar) * cos(azimuth))


## The light and the sky from the panel: the sky takes the sun's light
## above the air and works out the rest; the light on the ground is that
## less what the air scatters out of the beam on the way, as One Bulb
## reckons it.
func _place_sun() -> void:
	var dir := _sun_dir()
	var up := Vector3.FORWARD if absf(dir.y) > 0.999 else Vector3.UP
	_sun.basis = Basis.looking_at(-dir, up)
	var energy := float((_panel.sliders["Sun energy"] as HSlider).value)
	_sky_mat.set_shader_parameter("sun_dir", dir)
	if _acoustics != null:
		_acoustics.sun_dir = dir
	_sky_mat.set_shader_parameter("sun_illuminance", energy)
	var through := Color(1, 1, 1)
	if (_panel.switches["Atmosphere dims and reddens the sun"] as CheckButton).button_pressed:
		through = _transmittance(dir)
	var lum := 0.2126 * through.r + 0.7152 * through.g + 0.0722 * through.b
	var top := maxf(maxf(through.r, through.g), maxf(through.b, 1e-6))
	var hue := Color(through.r / top, through.g / top, through.b / top)
	_sun.light_color = hue.linear_to_srgb() if lum > 0.0 else Color.WHITE
	_sun.light_energy = energy * lum


## The share of the sun's light in red, green and blue that crosses the
## air to the ground, by the sky's own model: exp of the optical depth
## from the eye toward the sun to the top of the air, summed in 64 steps.
## None when the Earth stands in the way.
func _transmittance(dir: Vector3) -> Color:
	var from := Vector3(0.0, R_EARTH + 2.0, 0.0)
	var b := from.dot(dir)
	var c := from.length_squared() - R_EARTH * R_EARTH
	if b < 0.0 and b * b - c > 0.0:
		return Color(0, 0, 0)
	var length := -b + sqrt(b * b - (from.length_squared() - R_AIR * R_AIR))
	var air := float((_panel.sliders["Air density"] as HSlider).value)
	var haze := float((_panel.sliders["Haze"] as HSlider).value)
	var ozone := float((_panel.sliders["Ozone"] as HSlider).value)
	var steps := 64
	var dl := length / steps
	var depth := Vector3.ZERO
	for i in steps:
		var h := (from + dir * dl * (i + 0.5)).length() - R_EARTH
		depth += (RAYLEIGH * air * exp(-h / H_RAYLEIGH) + Vector3.ONE * MIE_EXTINCT * haze * exp(-h / H_MIE)
			+ OZONE * ozone * maxf(0.0, 1.0 - absf(h - 25000.0) / 15000.0)) * dl
	return Color(exp(-depth.x), exp(-depth.y), exp(-depth.z))


## One Bulb's terrain, filled in the middle, in its grass: the image 5.6 m
## across, laid without breaking up the repeat and without colour
## variation, its bumps at twice their strength.
func _build_ground() -> void:
	var mat := ShaderMaterial.new()
	mat.shader = load("res://world/ground_tex.gdshader") as Shader
	for pair: Array in [["albedo_tex", "use_albedo", "albedo"], ["normal_tex", "use_normal", "normal"],
			["ao_tex", "use_ao", "ao"]]:
		mat.set_shader_parameter(str(pair[0]), load("res://textures/grass/%s.jpg" % pair[2]) as Texture2D)
		mat.set_shader_parameter(str(pair[1]), true)
	mat.set_shader_parameter("tile_m", Vector2(5.6, 5.6))
	mat.set_shader_parameter("normal_strength", 2.0)
	mat.set_shader_parameter("roughness_scale", 1.8)
	mat.set_shader_parameter("specular", 0.2)
	mat.set_shader_parameter("variation", 0.0)
	mat.set_shader_parameter("break_tiling", 0.0)
	var terrain := BulbTerrain.new(mat)
	terrain.height = 53.0
	terrain.feature = 350.0
	terrain.roughness = 0.29
	terrain.noise_seed = 58
	terrain.closed = true
	add_child(terrain)
	terrain.build()


## The shells in grey stone (ambientCG's marble, its veins and pits
## kept but its polish taken off: matte, as weathered limestone), laid
## on triplanar in the shell's own space so it turns with it, one copy
## of the image a twentieth of the radius across: 5 m on the smallest,
## 25 m on the largest.
func _build_shells() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for r: float in SHELL_RADII:
		var mat := StandardMaterial3D.new()
		mat.albedo_texture = load("res://textures/marble/albedo.jpg") as Texture2D
		mat.albedo_color = Color(0.8, 0.8, 0.8)
		mat.roughness = 0.9
		mat.normal_enabled = true
		mat.normal_texture = load("res://textures/marble/normal.jpg") as Texture2D
		mat.normal_scale = 2.0
		mat.uv1_triplanar = true
		mat.uv1_scale = Vector3.ONE * 20.0 / r
		mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
		var shell := SpinningShell.new(r, mat, rng)
		shell.position = SHELL_CENTRE
		add_child(shell)
		_shells.append(shell)


## The platform at the bowls' centre: a disc of dark polished stone
## 8 m across, tapering below to a point 3 m down, its top 1.6 m under
## the centre so the eye of someone standing on it is at the centre. A
## thin line of light runs round the top an arm's length in from the
## edge; it flares when a bowl's groan reaches the centre.
func _build_platform() -> void:
	var stone := StandardMaterial3D.new()
	stone.albedo_texture = load("res://textures/marble/albedo.jpg") as Texture2D
	stone.albedo_color = Color(0.09, 0.09, 0.1)
	stone.roughness = 0.25
	stone.disable_ambient_light = true
	stone.normal_enabled = true
	stone.normal_texture = load("res://textures/marble/normal.jpg") as Texture2D
	stone.normal_scale = 0.4
	stone.uv1_triplanar = true
	stone.uv1_scale = Vector3.ONE * 0.25
	var cone := CylinderMesh.new()
	cone.top_radius = PLATFORM_R
	cone.bottom_radius = 0.05
	cone.height = 3.0
	cone.radial_segments = 96
	cone.material = stone
	var body := StaticBody3D.new()
	body.position = START
	add_child(body)
	var view := MeshInstance3D.new()
	view.mesh = cone
	view.position.y = -1.5
	body.add_child(view)
	var shape := CylinderShape3D.new()
	shape.radius = PLATFORM_R
	shape.height = 0.4
	var collide := CollisionShape3D.new()
	collide.shape = shape
	collide.position.y = -0.2
	body.add_child(collide)
	_rim_mat = StandardMaterial3D.new()
	_rim_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_rim_mat.albedo_color = Color(0.75, 0.88, 1.0)
	_rim_mat.emission_enabled = true
	_rim_mat.emission = Color(0.75, 0.88, 1.0)
	var ring := TorusMesh.new()
	ring.inner_radius = PLATFORM_R - 0.6 - 0.025
	ring.outer_radius = PLATFORM_R - 0.6 + 0.025
	ring.rings = 192
	ring.ring_segments = 8
	ring.material = _rim_mat
	var line := MeshInstance3D.new()
	line.mesh = ring
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.scale = Vector3(1.0, 0.4, 1.0)
	body.add_child(line)
	_set_rim(0.0)


## The rim line's brightness: a steady low glow and `extra` over it.
func _set_rim(extra: float) -> void:
	_rim_mat.emission_energy_multiplier = 1.2 + extra


## A black screen to fade through when a fall is caught.
func _build_fade() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10
	add_child(layer)
	_fade = ColorRect.new()
	_fade.color = Color(0, 0, 0, 0)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(_fade)


func _process(delta: float) -> void:
	_rim_glow *= exp(-delta / 0.6)
	_set_rim(_rim_glow)


## Off the platform: the fall goes on until the player is FALL_LIMIT
## below it, then the screen fades to black over a second and a half,
## the player is put back at the centre, and it fades in again.
func _physics_process(delta: float) -> void:
	var player := $Player as Player
	if _falling < 0.0 and player.global_position.y < START.y - FALL_LIMIT:
		_falling = 0.0
	if _falling >= 0.0:
		_falling += delta
		var down := 1.5
		if _falling < down:
			_fade.color.a = _falling / down
		elif _falling < down + 0.5:
			_fade.color.a = 1.0
			player.global_position = START
			player.velocity = Vector3.ZERO
		elif _falling < down + 2.5:
			_fade.color.a = 1.0 - (_falling - down - 0.5) / 2.0
		else:
			_fade.color.a = 0.0
			_falling = -1.0


func _exit_tree() -> void:
	get_viewport().use_debanding = _debanding_was
