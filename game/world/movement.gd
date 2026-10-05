extends Node3D
## Open ground under the sky, for studying how the player moves: One
## Bulb's hills without its room, lit by its far sun under its
## Atmosphere sky. The hills and grass as One Bulb was last set (hills
## 53 m high and 350 m across, ruggedness 0.29, seed 58). Godot's default shading; no
## WorldBase. The ground is level for 19 m round the start and rises
## into the hills beyond; a player who falls off its edge is put back at
## the start.
##
## Over the start hang five concentric shells of stone (SpinningShell),
## 100 to 500 m in radius about a centre 650 m up, so the largest clears
## the ground by 150 m. Each has a ribbon a fifth of its radius wide cut
## round its middle and turns once in 5 to 30 s (drawn at random for
## each shell on arrival) about an axis drawn afresh every 10 s.
##
## Two panels of controls (BenchPanel; Esc frees the mouse), kept in
## user://movement.json. Sun, as One Bulb sets it: its polar angle and
## azimuth, its energy, and whether the air colours its light. Sky: the
## atmosphere's air, haze and ozone against Earth's, from none to many
## times as much, and how forward the haze scatters.

const START := Vector3(0, 0, 3)
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
const SHELL_CENTRE := Vector3(0, 650, 3)
const SHELL_RADII: Array[float] = [100.0, 170.0, 260.0, 370.0, 500.0]
const SKY_PARAMS := {"Air density": "rayleigh_scale", "Haze": "mie_scale", "Ozone": "ozone_scale",
	"Haze forward": "mie_g"}

var _debanding_was := false
var _panel: BenchPanel
var _sun: DirectionalLight3D
var _sky_mat: ShaderMaterial


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
	_build_panel()
	_panel.restore()
	_place_sun()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] movement: open ground, sun, atmosphere sky")


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
	_sun.directional_shadow_max_distance = 200.0   # the near hills; 800 m cost about 80 ms a frame
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
	_panel.switch(sun, "Sun colour from the air", true, place)
	_panel.note(sun, "The beam loses light on its way through the atmosphere, worked out from the Sky panel's air, haze and ozone, as the sky is: on Earth, overhead the sun keeps most of its light; low, it turns orange and red and fades; set, it gives none.")

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
	_sky_mat.set_shader_parameter("sun_illuminance", energy)
	var through := Color(1, 1, 1)
	if (_panel.switches["Sun colour from the air"] as CheckButton).button_pressed:
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


func _physics_process(_delta: float) -> void:
	var player := $Player as Player
	if player.global_position.y < -30.0:
		player.global_position = START
		player.velocity = Vector3.ZERO


func _exit_tree() -> void:
	get_viewport().use_debanding = _debanding_was
