extends Node3D
## Open ground under the sky, for studying how the player moves: One
## Bulb's hills without its room, lit by its far sun under its
## Atmosphere sky. The hills and grass as One Bulb was last set (hills
## 53 m high and 350 m across, ruggedness 0.29, seed 58); the sky a clear
## day in the standard atmosphere. Godot's default shading; no
## WorldBase. The ground is level for 19 m round the start and rises
## into the hills beyond; a player who falls off its edge is put back at
## the start.
##
## One panel of controls (BenchPanel; Esc frees the mouse), the sun as
## One Bulb sets it: its polar angle and azimuth, its energy, and whether
## the air colours its light. Kept in user://movement.json.

const START := Vector3(0, 0, 3)
const STATE_PATH := "user://movement.json"
const BulbVoid := preload("res://world/bulb_void.gd")

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
	_panel.note(sun, "The beam loses light on its way through the atmosphere, blue most: overhead the sun keeps about three quarters of its light; low, it turns orange and red and fades; set, it gives none.")


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
		through = BulbVoid._air_transmittance(float((_panel.sliders["Polar angle"] as HSlider).value))
	var lum := 0.2126 * through.r + 0.7152 * through.g + 0.0722 * through.b
	var hue := Color(through.r / maxf(through.r, 1e-6), through.g / maxf(through.r, 1e-6), through.b / maxf(through.r, 1e-6))
	_sun.light_color = hue.linear_to_srgb() if lum > 0.0 else Color.WHITE
	_sun.light_energy = energy * lum


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


func _physics_process(_delta: float) -> void:
	var player := $Player as Player
	if player.global_position.y < -30.0:
		player.global_position = START
		player.velocity = Vector3.ZERO


func _exit_tree() -> void:
	get_viewport().use_debanding = _debanding_was
