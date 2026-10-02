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

const WIND_DIR := Vector2(0.8, 0.6)
const GRASS_KEY := "hills_grass"
const FIELD := 512.0                 # the grass's baked square, metres

var land: HillsLand
var grass: GrassField
var wind := 0.3
var _air: AudioStreamPlayer
var _hiss: AudioStreamPlayer
var _hiss_level := 0.0
var _wind_noise := FastNoiseLite.new()
var _clock := 0.0


func _init() -> void:
	super()
	save_path = "user://save_hills.json"
	settings_prefix = "hills_"
	time_of_day = 17.0
	_wind_noise.seed = 20261011
	_wind_noise.frequency = 1.0


func _build_environment() -> void:
	super()
	# Clear summer air with the distance going blue, the sun's glow in it.
	sky_env.fog_density = 0.0011
	sky_env.fog_sun_scatter = 0.25
	sky_env.fog_aerial_perspective = 0.5
	(sky_mat as ShaderMaterial).set_shader_parameter("haze", 0.5)


func _build_ground() -> void:
	land = HillsLand.new()
	add_child(land)
	land.build()
	grass = GrassField.new()
	grass.name = "Grass"
	add_child(grass)
	grass.build(land, Vector2.ZERO, FIELD, land.grass_at, func(_x: float, _z: float) -> float: return 0.0,
		"real", str(_read_settings().get(GRASS_KEY, "shells")), 1.0)
	land.terrain_mat.set_shader_parameter("reach", float(GrassField.MODELS["shells"]["reach"]))
	_tune_grass()
	_build_sound()


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
	if _air == null:
		return
	# The hiss is the grass round the listener bending: the gusts at the
	# listener and a few metres about, so it swells as a band arrives.
	var at := Vector2(cam_pos.x, cam_pos.z)
	var across := Vector2(-wd.y, wd.x)
	var g := 0.0
	for offset: Vector2 in [Vector2.ZERO, wd * 6.0, -wd * 6.0, across * 6.0, -across * 6.0]:
		g += Gusts.at(at + offset, grass.travel, wind, wd)
	g /= 5.0
	_hiss_level = lerpf(_hiss_level, g, clampf(delta * 3.0, 0.0, 1.0))
	_air.volume_db = linear_to_db(0.12 + 0.6 * wind) - 4.0
	_hiss.volume_db = linear_to_db(0.03 + 0.9 * _hiss_level * (0.4 + 0.6 * wind)) - 2.0


func _after_build() -> void:
	settings.add_choice("Grass", ["Full", "Light", "Fluffy", "Shells", "None"],
		GrassField.MODEL_NAMES.find(grass.model), _change_grass)
	if not FileAccess.file_exists(save_path):
		# On the first rise, facing into the wind, so the gusts come
		# across the hills toward the viewer.
		player.global_position = Vector3(0.0, land.surface_height(0.0, 0.0) + 0.4, 0.0)
		var into := -WIND_DIR.normalized()
		player.rotation.y = atan2(-into.x, -into.y)
	hud.toast("Open hills of long grass. O options: the time of day, the grass. F5/F9 save/load")
	print("[worldbuilder] hills: terrain %d ms, grass %d ms over %d chunks"
		% [int(land.stats.get("ms_terrain", 0)), int(grass.stats.get("ms", 0)), int(grass.stats.get("chunks_with_grass", 0))])
	if DisplayServer.get_name() == "headless":
		_report_in = 20


## The hills' shells: sunlit grass with only its roots in shade, and
## that shade lit by the open sky, so upright grass between gusts is
## not a pit; the ground under the shells the same.
const ROOT_DARK := Color(0.11, 0.14, 0.06)

func _tune_grass() -> void:
	for mat in grass.materials:
		mat.set_shader_parameter("root_shade", 0.18)
		mat.set_shader_parameter("root_dark", ROOT_DARK)
	land.terrain_mat.set_shader_parameter("root_dark", ROOT_DARK)


func _change_grass(index: int) -> void:
	grass.set_model(GrassField.MODEL_NAMES[index])
	_tune_grass()
	var saved := _read_settings()
	saved[GRASS_KEY] = grass.model
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(saved))
