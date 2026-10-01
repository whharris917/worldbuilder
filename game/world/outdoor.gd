class_name OutdoorWorld
extends WorldBase
## A world out of doors: the sky, the sun, the night sky turning with
## the clock, and two rings of woods. A world builds its own ground
## (_build_ground) and replaces the woods where it has its own
## (_build_forest).

## The faintest star the eye reaches here on a clear moonless night.
var star_limit := 6.3
var _stars: NightSky


func _init() -> void:
	reverb_room_size = 0.3
	reverb_wet = 0.05


func _build_world() -> void:
	_build_environment()
	_build_ground()
	_build_forest()


## The ground under everything: an infinite walkable plane. A world
## with a site or a landscape overrides this.
func _build_ground() -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	shape.shape = WorldBoundaryShape3D.new()
	body.add_child(shape)
	add_child(body)


## Two rings of trees round the origin, the near ring dense and
## shadowed, the far ring taller and sparser so no gap shows the
## horizon from ground level.
func _build_forest() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260912
	var near := Forest.new()
	near.plant_bushes(Vector3.ZERO, 84.0, 96.0, 3.2, rng)
	near.plant_ring(Vector3.ZERO, 88.0, 130.0, 4.4, 11.0, rng)
	near.finish(true)
	add_child(near)
	var far := Forest.new()
	far.plant_ring(Vector3.ZERO, 130.0, 210.0, 6.5, 16.0, rng)
	far.finish(false)
	add_child(far)


func _build_environment() -> void:
	# Our own sky (world/sky.gdshader): it carries its twilight, so the
	# dome stays lit as the sun nears the horizon, and the ambient and
	# reflections come from it. A crisp autumn day here: little haze.
	var painted := ShaderMaterial.new()
	painted.shader = load("res://world/sky.gdshader")
	painted.set_shader_parameter("haze", 0.3)
	painted.set_shader_parameter("energy", 1.0)
	painted.set_shader_parameter("ground_color", Color(0.30, 0.32, 0.30))
	sky_mat = painted
	var sky := Sky.new()
	sky.sky_material = sky_mat
	sky.radiance_size = Sky.RADIANCE_SIZE_128
	# The radiance follows the material's changes on its own; the clock
	# does not run by itself, so nothing here needs the per-frame realtime
	# mode, which strobes.

	var env := Environment.new()
	sky_env = env
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_white = 4.0
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.18
	env.glow_bloom = 0.05
	# Contact shadow in the corners and under the eaves.
	env.ssao_enabled = true
	env.ssao_radius = 1.2
	env.ssao_intensity = 2.0
	env.ssao_power = 1.8
	# A whisper of distance fog gives the ground a horizon, and aerial
	# perspective lets the distance take the sky's colour.
	env.fog_enabled = true
	env.fog_light_color = Color(0.72, 0.78, 0.84)
	env.fog_density = 0.0005
	env.fog_aerial_perspective = 0.25
	env.fog_sky_affect = 0.0
	# Screen-space reflections: glass and paint pick up what stands
	# beside them, not only the sky.
	env.ssr_enabled = true
	env.ssr_max_steps = 64
	env.ssr_fade_in = 0.15
	env.ssr_fade_out = 2.0
	env.ssr_depth_tolerance = 0.2
	# Volumetric fog waits on the Ultra preset (with SDFGI).
	env.volumetric_fog_density = 0.004
	env.volumetric_fog_albedo = Color(0.90, 0.93, 0.97)
	env.volumetric_fog_sky_affect = 0.0
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48, 32, 0)
	sun.light_energy = 1.8
	sun.light_color = Color(1.0, 0.97, 0.90)
	_sun_base_energy = sun.light_energy
	_sun_base_color = sun.light_color
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 200.0
	sun.shadow_blur = 1.5
	sun.light_angular_distance = 0.5   # the sun's half-degree: soft penumbrae, a real disc in the sky

	# The night sky: the stars of the catalogue and the Milky Way,
	# turning with the clock.
	_stars = NightSky.new(star_limit)
	add_child(_stars)
	sun.directional_shadow_split_1 = 0.08
	sun.directional_shadow_split_2 = 0.2
	sun.directional_shadow_split_3 = 0.5
	add_child(sun)


func _process(delta: float) -> void:
	super._process(delta)
	if _stars != null:
		_stars.follow(player.global_position)


## Stars come out as twilight goes.
func _on_time_of_day(_horizon: float, twilight: float) -> void:
	if _stars != null:
		# The first stars wait for the afterglow to go: the brightest at
		# the end of civil twilight, the field once it is dark. Cloud
		# hides them; the moon's light drowns the faint ones.
		var cover := _sky_cover()
		var moon := SkyClock.moon_world(time_of_day)
		var moon_light := pow(SkyClock.moon_lit(time_of_day), 1.5) * clampf(moon.y * 5.0, 0.0, 1.0)
		_stars.update(time_of_day, pow(1.0 - twilight, 1.8) * pow(1.0 - cover, 2.0), moon_light * (1.0 - cover))


## How much of the sky cloud hides, 0 to 1: a world with weather says.
func _sky_cover() -> float:
	return 0.0
