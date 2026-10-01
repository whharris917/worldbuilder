class_name CoastWorld
extends OutdoorWorld
## The Maine coast: MaineCoast (or a world's own coast) builds the
## landscape; this world owns the sky, the fog that lies on the water at
## dawn, the tide's clock, and what the camera sees under water.

var coast: MaineCoast
var _fog_density := 0.0
var _underwater := false


func _build_environment() -> void:
	super()
	# Coastal air: more water in it than open country's crisp autumn
	# day, and a dark sea under the horizon in the reflections.
	var painted := sky_mat as ShaderMaterial
	painted.set_shader_parameter("haze", 0.55)
	painted.set_shader_parameter("ground_color", Color(0.10, 0.14, 0.17))
	sky_env.fog_density = 0.0009
	sky_env.fog_aerial_perspective = 0.45
	sky_env.fog_height = MaineCoast.SEA + 4.0
	sky_env.fog_height_density = 0.0
	_fog_density = sky_env.fog_density


func _build_ground() -> void:
	coast = MaineCoast.new()
	add_child(coast)
	coast.build()


## The landscape plants its own wood, by the ground.
func _build_forest() -> void:
	pass


func _on_time_of_day(horizon: float, twilight: float) -> void:
	super(horizon, twilight)
	if coast != null:
		coast.set_time_of_day(time_of_day, horizon, twilight)
	# Sea fog: a veil on the water at dawn that burns off by mid-morning.
	if sky_env != null:
		var morning := clampf(1.0 - absf(time_of_day - 6.5) / 3.0, 0.0, 1.0)
		sky_env.fog_height_density = 0.02 * morning
		sky_env.fog_height = MaineCoast.SEA + 2.0 + 2.0 * morning


func _process(delta: float) -> void:
	super._process(delta)
	if coast == null or sky_env == null:
		return
	# Under the surface the world goes green and short.
	var under := player.camera.global_position.y < coast.tide_y
	if under != _underwater:
		_underwater = under
		if under:
			sky_env.fog_density = 0.09
			sky_env.fog_light_color = Color(0.04, 0.12, 0.13)
			sky_env.fog_sky_affect = 1.0
		else:
			sky_env.fog_density = _fog_density
			sky_env.fog_sky_affect = 0.0
			set_time_of_day(time_of_day)
