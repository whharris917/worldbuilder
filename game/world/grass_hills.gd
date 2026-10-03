extends OutdoorWorld
class_name GrassHills
## Open rolling hills of long grass under a wide sky, with nothing else
## on them: a study in wind. The breeze rises through the day and falls
## at evening, gusting; its gusts cross the hills as long bands lying
## across the wind (gust.gdshaderinc), leaning and paling the shell
## grass near the viewer and running on over the far hillsides in the
## ground's own shading, so the wind can be watched coming from far off.
## The sound is the same wind: a low rush of air as strong as the
## breeze, and the hiss of bending grass swelling as a band reaches
## the listener (Gusts, the bands on the CPU). Its own save, clock and
## grass model.
##
## A farmhouse stands by the pond (HillsLand.find_site), and in its
## parlour a console radio plays "Levittown Levity" (the director's
## recording, levittown_levity.mp3), heard through the open doors and
## windows: it fades
## with distance and loses its brightness first, so from up the hill it
## is a faint, muffled tune over the wind. A red pickup (PickupTruck)
## stands on the farm's lane facing the road, to be driven.
##
## Drawn in a look (`style`, set by its scene): "real", or "anime"
## (grass_hills_painted.tscn), painted as the meadow's painted look is:
## the painted sky of towering clouds, soft two-tone light warm in the
## sun and cool in the shade, the grass and the far hillsides in flat
## greens with the gusts laid on in strokes of pale gold-green. The
## options' Look row builds the hills again in the other look with the
## player where they stood; each look keeps its own save.

const WIND_DIR := Vector2(0.8, 0.6)
const ROOT_DARK := Color(0.11, 0.14, 0.06)
const GRASS_KEY := "hills_grass"
const LOOK_KEY := "hills_look"
## look, its name in the options, its scene.
const STYLES: Array = [
	["real", "As it is", "res://world/grass_hills.tscn"],
	["anime", "Painted", "res://world/grass_hills_painted.tscn"],
]
const FIELD := 512.0                 # the grass's baked square, metres
const SKY_KEY := "hills_sky"
## The air, chosen in the options: name, fog density, sun scatter,
## aerial perspective, the sky's haze, its zenith and horizon by day.
const SKIES: Array = [
	["Summer haze", 0.0011, 0.25, 0.5, 0.5, Color(0.19, 0.36, 0.72), Color(0.62, 0.72, 0.84)],
	["Clear autumn", 0.00022, 0.06, 0.12, 0.06, Color(0.10, 0.26, 0.66), Color(0.46, 0.62, 0.84)],
]

@export var style := "real"

## Where the player stood when the look was changed: position, turn,
## the camera's tilt.
static var _handoff: Array = []

var land: HillsLand
var house: BuildingMesh
var truck: PickupTruck
var grass: GrassField
var gusts := Gusts.new()
var wind := 0.3
var _air: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _hiss_level := 0.0
var _wind_noise := FastNoiseLite.new()
var _clock := 0.0
## The pond's surface, or far below everything with no pond.
var _water: float:
	get:
		return land.lake_level if not land.lake_cells.is_empty() else -1.0e6


func _init() -> void:
	super()
	save_path = "user://save_hills.json"
	settings_prefix = "hills_"
	time_of_day = 17.0
	_wind_noise.seed = 20261011
	_wind_noise.frequency = 1.0


func _build_environment() -> void:
	super()
	if style == "anime":
		# The painted sky, and a clear summer air with blue distance.
		var painted := ShaderMaterial.new()
		painted.shader = load("res://world/sky_anime.gdshader")
		sky_env.sky.sky_material = painted
		sky_mat = painted
		sun.light_energy = 1.5
		_sun_base_energy = 1.5
		sky_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
		sky_env.tonemap_white = 6.0
		sky_env.adjustment_enabled = true
		sky_env.adjustment_saturation = 1.2
		sky_env.fog_density = 0.0005
		sky_env.fog_aerial_perspective = 0.7
		sky_env.glow_intensity = 0.3
		return
	_apply_sky(int(_read_settings().get(SKY_KEY, 1)))


## The painted look's shade: lit more by the sky by day, painted cool
## blue against the warm sun.
func _on_time_of_day(horizon: float, twilight: float) -> void:
	super(horizon, twilight)
	if style == "anime":
		sky_env.ambient_light_color = sky_env.ambient_light_color.lerp(Color(0.48, 0.60, 0.95), 0.6 * twilight)
		sky_env.ambient_light_energy *= lerpf(1.0, 1.5, twilight)


## The air: summer haze, the distance going blue and the sun's glow in
## it; or a clear autumn day, a deep blue overhead and the far hills
## sharp.
func _apply_sky(index: int) -> void:
	var air: Array = SKIES[clampi(index, 0, SKIES.size() - 1)]
	sky_env.fog_density = float(air[1])
	sky_env.fog_sun_scatter = float(air[2])
	sky_env.fog_aerial_perspective = float(air[3])
	var painted := sky_mat as ShaderMaterial
	painted.set_shader_parameter("haze", float(air[4]))
	painted.set_shader_parameter("zenith_day", air[5])
	painted.set_shader_parameter("horizon_day", air[6])


func _change_sky(index: int) -> void:
	_apply_sky(index)
	set_time_of_day(time_of_day)
	_store(SKY_KEY, index)


func _build_ground() -> void:
	land = HillsLand.new()
	if style != "real":
		save_path = "user://save_hills_%s.json" % style
		moonlight_key = "hills_%s_moonlight" % style
		land.ground_shader = "res://world/hills_ground_painted.gdshader"
	add_child(land)
	land.build()
	if land.site.x != INF:
		# The farmhouse on its graded yard by the pond, facing the water.
		house = BuildingMesh.open("res://data/buildings/farmhouse.bld")
		house.position = Vector3(land.site.x, land.site_y, land.site.y)
		house.rotation.y = land.site_yaw
		add_child(house)
		_build_radio()
	grass = GrassField.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(land, Vector2.ZERO, FIELD, land.grass_at, func(_x: float, _z: float) -> float: return 0.0,
		style, str(_read_settings().get(GRASS_KEY, "shells")), 1.0)
	# The gusts' pull downhill, over the land as far as the eye follows them.
	gusts.bake_flow(land, 4096.0, 16.0)
	land.terrain_mat.set_shader_parameter("reach", float(GrassField.MODELS["shells"]["reach"]))
	_tune_grass()
	_build_sound()
	_park_truck()


## The pickup on the lane a few metres from the yard, facing the road,
## let down onto its wheels.
func _park_truck() -> void:
	if land.drive_pts.size() < 6:
		return
	var at: Vector2 = land.drive_pts[4]
	var dir: Vector2 = (land.drive_pts[5] - land.drive_pts[3]).normalized()
	truck = PickupTruck.new()
	truck.name = "Truck"
	truck.world = self
	truck.position = Vector3(at.x, land.height_at(at.x, at.y) + 0.12, at.y)
	truck.rotation.y = atan2(dir.x, dir.y)
	add_child(truck)


## The parlour's console radio, in the house's frame (metres, +x its
## front, the first floor 0.6 m up): a walnut cabinet against the end
## wall between the windows, its cloth grille and lit dial toward the
## room, and the tune playing from it.
func _build_radio() -> void:
	var radio := Node3D.new()
	radio.name = "Radio"
	radio.position = Vector3(0.0, 0.6, 3.75)
	radio.rotation.y = PI
	house.add_child(radio)
	var walnut := StandardMaterial3D.new()
	walnut.albedo_color = Color(0.24, 0.13, 0.07)
	walnut.roughness = 0.45
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.55, 0.47, 0.34)
	cloth.roughness = 1.0
	var dial := StandardMaterial3D.new()
	dial.albedo_color = Color(0.95, 0.80, 0.50)
	dial.emission_enabled = true
	dial.emission = Color(1.0, 0.72, 0.35)
	dial.emission_energy_multiplier = 1.4
	# +z toward the room in the radio's own frame.
	for part: Array in [
		[Vector3(0.78, 1.02, 0.40), Vector3(0.0, 0.51, 0.0), walnut],
		[Vector3(0.62, 0.42, 0.02), Vector3(0.0, 0.42, 0.205), cloth],
		[Vector3(0.40, 0.09, 0.02), Vector3(0.0, 0.80, 0.205), dial],
		[Vector3(0.82, 0.04, 0.44), Vector3(0.0, 1.04, 0.0), walnut],
	]:
		var box := BoxMesh.new()
		box.size = part[0]
		var mi := MeshInstance3D.new()
		mi.mesh = box
		mi.position = part[1]
		mi.material_override = part[2]
		radio.add_child(mi)
	for x: float in [-0.12, 0.12]:
		var knob := CylinderMesh.new()
		knob.top_radius = 0.025
		knob.bottom_radius = 0.028
		knob.height = 0.03
		var k := MeshInstance3D.new()
		k.mesh = knob
		k.rotation.x = PI / 2.0
		k.position = Vector3(x, 0.70, 0.215)
		k.material_override = walnut
		radio.add_child(k)
	var glow := OmniLight3D.new()
	glow.light_color = Color(1.0, 0.75, 0.45)
	glow.light_energy = 0.15
	glow.omni_range = 1.2
	glow.position = Vector3(0.0, 0.8, 0.35)
	radio.add_child(glow)
	if DisplayServer.get_name() == "headless":
		return
	var stream := load("res://audio/levittown_levity.mp3") as AudioStreamMP3
	stream.loop = true
	var sound := AudioStreamPlayer3D.new()
	sound.stream = stream
	sound.position = Vector3(0.0, 0.5, 0.0)
	sound.volume_db = -4.0
	sound.unit_size = 3.0
	sound.max_distance = 140.0
	sound.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	# Farther off the tune keeps its low notes and loses its bright ones.
	sound.attenuation_filter_cutoff_hz = 2500.0
	sound.attenuation_filter_db = -18.0
	sound.bus = "Outdoor"
	radio.add_child(sound)
	sound.play()


## No trees.
func _build_forest() -> void:
	pass


func _build_sound() -> void:
	if DisplayServer.get_name() == "headless":
		return
	_air = _loop_player("res://audio/air_loop.wav")
	_hiss = _loop_player("res://audio/grass_hiss_loop.wav")


func _loop_player(path: String) -> AudioStreamPlayer:
	var stream := load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = -60.0
	p.bus = "Outdoor"
	add_child(p)
	p.play()
	return p


## The breeze: calm at dawn and in the night, rising through the
## morning to its strongest in mid-afternoon, falling at evening; the
## open hills windier than the meadow's valley; gusts on top of it.
func _breeze(h: float, t: float) -> float:
	var day := smoothstep(7.0, 14.0, h) * (1.0 - smoothstep(17.0, 21.0, h))
	var base := 0.15 + 0.4 * day
	var gust := 0.5 + 0.5 * _wind_noise.get_noise_1d(t * 0.05) + 0.25 * _wind_noise.get_noise_1d(t * 0.21 + 40.0)
	return clampf(base * (0.5 + 1.1 * maxf(gust, 0.0)), 0.0, 1.0)


func _process(delta: float) -> void:
	super._process(delta)
	if grass == null:
		return
	_clock += delta
	wind = _breeze(time_of_day, _clock)
	var wd := WIND_DIR.normalized()
	var cam := get_viewport().get_camera_3d()
	var cam_pos := cam.global_position if cam != null else player.global_position
	grass.follow(cam_pos, player.global_position, wind, wd)
	land.terrain_mat.set_shader_parameter("wind", wind)
	land.terrain_mat.set_shader_parameter("wind_dir", wd)
	land.terrain_mat.set_shader_parameter("gust_travel", grass.travel)
	if land.lake_mat != null:
		land.lake_mat.set_shader_parameter("wind", wind)
		land.lake_mat.set_shader_parameter("wind_dir", wd)
		land.lake_mat.set_shader_parameter("gust_travel", grass.travel)
	if _air == null:
		return
	# The hiss is the grass round the listener bending: the gusts at the
	# listener and a few metres about, so it swells as a band arrives.
	var at := Vector2(cam_pos.x, cam_pos.z)
	var across := Vector2(-wd.y, wd.x)
	var g := 0.0
	for offset: Vector2 in [Vector2.ZERO, wd * 6.0, -wd * 6.0, across * 6.0, -across * 6.0]:
		g += gusts.at(at + offset, grass.travel, wind, wd)
	g /= 5.0
	_hiss_level = lerpf(_hiss_level, g, clampf(delta * 3.0, 0.0, 1.0))
	_air.volume_db = linear_to_db(0.12 + 0.6 * wind) - 18.0
	_hiss.volume_db = linear_to_db(0.03 + 0.9 * _hiss_level * (0.4 + 0.6 * wind)) - 30.0


func _after_build() -> void:
	var looks: Array[String] = []
	var current := 0
	for k in STYLES.size():
		looks.append(str(STYLES[k][1]))
		if STYLES[k][0] == style:
			current = k
	settings.add_choice("Look", looks, current, _change_look)
	if not MouseMode.probe:
		_store(LOOK_KEY, style)
	if style == "real":
		var skies: Array[String] = []
		for air: Array in SKIES:
			skies.append(str(air[0]))
		settings.add_choice("Sky", skies, clampi(int(_read_settings().get(SKY_KEY, 1)), 0, SKIES.size() - 1), _change_sky)
	settings.add_choice("Grass", ["Full", "Light", "Fluffy", "Shells", "None"],
		GrassField.MODEL_NAMES.find(grass.model), _change_grass)
	if not FileAccess.file_exists(save_path):
		# On the slope above the pond, looking down over it; with no
		# pond, on the first rise facing into the wind.
		var at := Vector2.ZERO
		var look := -WIND_DIR.normalized()
		if not land.lake_cells.is_empty():
			at = _overlook(land.lake_centre)
			look = (land.lake_centre - at).normalized()
		player.global_position = Vector3(at.x, land.surface_height(at.x, at.y) + 0.4, at.y)
		player.rotation.y = atan2(-look.x, -look.y)
	if style == "anime":
		hud.toast("Open hills of long grass, painted. O options: the time of day, the grass, the look. F5/F9 save/load")
	else:
		hud.toast("Open hills of long grass. O options: the time of day, the grass, the look. F5/F9 save/load")
	print("[worldbuilder] hills: terrain %d ms, grass %d ms over %d chunks; pond %d m2, %.1f m deep at (%d, %d), level %.2f; farmhouse at (%d, %d), %.1f m over the water, yard spread %.2f m; road %.1f km%s"
		% [int(land.stats.get("ms_terrain", 0)), int(grass.stats.get("ms", 0)), int(grass.stats.get("chunks_with_grass", 0)),
		int(land.stats.get("lake_m2", 0)), land.lake_depth, int(land.lake_centre.x), int(land.lake_centre.y), land.lake_level,
		int(land.site.x), int(land.site.y), land.site_y - land.lake_level, float(land.stats.get("site_spread", 0.0)),
		float(land.stats.get("road_km", 0.0)),
		" (BROKEN: it fails its checks)" if house != null and house.broken else ""])
	if DisplayServer.get_name() == "headless":
		_report_in = 20


## The hills' shells: sunlit grass with only its roots in shade, and
## that shade lit by the open sky, so upright grass between gusts is
## not a pit; the ground under the shells the same.
func _tune_grass() -> void:
	for mat in grass.materials:
		mat.set_shader_parameter("root_shade", 0.18)
		mat.set_shader_parameter("root_dark", ROOT_DARK)
		mat.set_shader_parameter("water_level", _water)
		gusts.apply(mat)
	land.terrain_mat.set_shader_parameter("root_dark", ROOT_DARK)
	land.terrain_mat.set_shader_parameter("water_level", _water)
	if style == "anime":
		# The painted turf in the painted grass's greens.
		land.terrain_mat.set_shader_parameter("green", Color(0.20, 0.40, 0.17))
		land.terrain_mat.set_shader_parameter("yellow_green", Color(0.40, 0.56, 0.21))
		land.terrain_mat.set_shader_parameter("sheen", Color(0.80, 0.86, 0.48))
		land.terrain_mat.set_shader_parameter("toon_step", 0.3)
	gusts.apply(land.terrain_mat)
	if land.lake_mat != null:
		gusts.apply(land.lake_mat)


## A spot above the pond to look over it from: of the points round it
## from 15 to 90 metres beyond its rough edge, the one standing highest
## over the water, most open toward it.
func _overlook(pond: Vector2) -> Vector2:
	var best := pond
	var best_h := -INF
	for a in 24:
		var dir := Vector2(cos(TAU * a / 24.0), sin(TAU * a / 24.0))
		var r := land.lake_radius() + 15.0
		while r <= land.lake_radius() + 90.0:
			var q := pond + dir * r
			var h := land.height_at(q.x, q.y)
			# Not cut off from the water by higher ground between.
			var clear := true
			for k in range(1, 6):
				var m := pond + dir * r * k / 6.0
				if land.height_at(m.x, m.y) > h - 0.5 * float(k) / 6.0 * (h - land.lake_level):
					clear = false
			if clear and h > best_h:
				best_h = h
				best = q
			r += 5.0
	return best


func _change_grass(index: int) -> void:
	grass.set_model(GrassField.MODEL_NAMES[index])
	_tune_grass()
	_store(GRASS_KEY, grass.model)


## One value of the hills' own into the shared settings file.
func _store(key: String, value: Variant) -> void:
	var saved := _read_settings()
	saved[key] = value
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved))


## Build the hills again in look `index` of STYLES, the player where
## they stand.
func _change_look(index: int) -> void:
	if STYLES[index][0] == style:
		return
	_handoff = [player.global_position, player.rotation.y, player.camera.rotation.x]
	_save_settings()
	# The options close and the note shows before the build holds the
	# screen for some seconds.
	settings.visible = false
	player.input_locked = false
	hud.toast("Changing the look...")
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().change_scene_to_file(str(STYLES[index][2]))


## Arriving from another look, the player stands where they stood in it;
## otherwise where this look's save left them.
func load_player() -> bool:
	if _handoff.is_empty():
		var loaded := super()
		# A save from before the land changed may lie under the ground.
		var p := player.global_position
		var ground := land.height_at(p.x, p.z)
		if loaded and p.y < ground + 0.2:
			player.global_position.y = ground + 0.4
		return loaded
	player.global_position = _handoff[0]
	player.rotation.y = _handoff[1]
	player.camera.rotation.x = _handoff[2]
	_handoff = []
	return true


## The scene of the look the hills were last seen in, for the title
## menu's one entry.
static func last_look_scene() -> String:
	var look := ""
	if FileAccess.file_exists(SETTINGS_PATH):
		var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				look = str((parsed as Dictionary).get(LOOK_KEY, ""))
	for entry: Array in STYLES:
		if entry[0] == look:
			return str(entry[2])
	return str(STYLES[0][2])
