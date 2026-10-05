extends Node3D
## Open ground under the sky, for studying how the player moves: One
## Bulb's hills without its room, lit by its far sun under Godot's
## physical sky. The hills and grass as One Bulb was last set (hills 53 m
## high and 350 m across, ruggedness 0.29, seed 58); the sun and sky at
## One Bulb's defaults, a clear day with the sun 40 degrees up. Godot's
## default shading; no WorldBase. The ground is level for 19 m round the
## start and rises into the hills beyond; a player who falls off its
## edge is put back at the start.

const START := Vector3(0, 0, 3)
const POLAR := 50.0                     # degrees from straight up
const AZIMUTH := 200.0                  # degrees round the horizon
const SUN_ENERGY := 1.0

var _debanding_was := false


func _ready() -> void:
	var player := $Player as Player
	player.global_position = START
	var vp := get_viewport()
	_debanding_was = vp.use_debanding
	vp.use_debanding = true
	_build_sky()
	_build_sun()
	_build_ground()
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] movement: open ground, sun, physical sky")


## Godot's physical sky (Rayleigh and Mie scattering worked out from the
## sun's direction, at Godot's default air) as the background, the
## ambient light and what glossy surfaces reflect. Its own dither is off: the viewport's does
## the job after the exposure.
func _build_sky() -> void:
	var sky_mat := PhysicalSkyMaterial.new()
	sky_mat.use_debanding = false
	var sky := Sky.new()
	sky.sky_material = sky_mat
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
## lights the ground and draws the sky's sun.
func _build_sun() -> void:
	var polar := deg_to_rad(POLAR)
	var azimuth := deg_to_rad(AZIMUTH)
	var dir := Vector3(sin(polar) * sin(azimuth), cos(polar), -sin(polar) * cos(azimuth))
	var sun := DirectionalLight3D.new()
	sun.basis = Basis.looking_at(-dir, Vector3.UP)
	sun.light_energy = SUN_ENERGY
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0   # the near hills; 800 m cost about 80 ms a frame
	add_child(sun)


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
