class_name WorldBase
extends Node3D
## Shared bootstrap for every world: player, HUD, options, audio buses,
## the clock and the sky, and quicksave/quickload of where the player
## stands. Subclasses build their environment in _build_world(), tune the
## knobs below in _init(), and place what follows the build in
## _after_build().

@onready var player: Player = $Player

var hud: Hud

# Knobs a world sets in _init(), before _ready runs.
var save_path := "user://save.json"
var reverb_room_size := 0.85
var reverb_wet := 0.25

var _loop_players: Array[AudioStreamPlayer] = []

# On-screen options: the sun follows a time-of-day slider, the weather a
# slider where a world has weather, and the music is a toggle, off by
# default. All persist in user://settings.json. Worlds hand their sun
# (and their sky material) to these so one slider serves every world.
const SETTINGS_PATH := "user://settings.json"
var sun: DirectionalLight3D = null
var sky_mat: Material = null          # sky.gdshader; a Procedural or Physical sky material is honoured too
var sky_env: Environment = null
var settings: SettingsPanel
var music_player: AudioStreamPlayer = null
var time_of_day := 10.0
var weather_level := -1.0              # 0 fair to 1 storm; below 0, the world has no weather
var settings_prefix := ""              # a world keeps its own clock and weather under its own keys
var moonlight := 1.0                   # the night's light, 0 none to 2 twice the moon's (options)
var moonlight_key := ""                # where it is saved; empty: the world's prefix + "moonlight"
var music_on := false
var graphics := GraphicsSettings.new()   # presets and knobs; see ui/graphics_settings.gd
var _sun_base_energy := 1.5
var _sun_base_color := Color(1.0, 0.97, 0.90)


func _ready() -> void:
	var t_start := Time.get_ticks_msec()
	_build_world()
	_build_audio()
	var ms_world := Time.get_ticks_msec() - t_start
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Hud.new()
	layer.add_child(hud)
	settings = SettingsPanel.new()
	layer.add_child(settings)
	settings.on_time_changed = func(hours: float) -> void:
		set_time_of_day(hours)
		_save_settings()
	if weather_level >= 0.0:
		settings.on_weather_changed = func(level: float) -> void:
			set_weather(level)
			_save_settings()
	settings.on_moonlight_changed = func(level: float) -> void:
		moonlight = level
		set_time_of_day(time_of_day)
		_save_settings()
	settings.on_music_changed = func(on: bool) -> void:
		set_music(on)
		_save_settings()
	settings.graphics = graphics
	settings.on_graphics_changed = func() -> void:
		graphics.apply(self)
		_save_settings()
	hud.toast("WASD walk · Shift run · E use · wheel zoom (ctrl: optic) · O options · F5/F9 save/load")
	_after_build()
	load_player()
	print("[worldbuilder] startup %d ms — world %d" % [Time.get_ticks_msec() - t_start, ms_world])
	_load_settings()


## Environment, geometry, lighting. Override in each world.
func _build_world() -> void:
	pass


## What a world places once it is built: its actors, the spawn point,
## its startup report. Override where needed.
func _after_build() -> void:
	pass


## ---- where the player stands -------------------------------------------

func save_player() -> bool:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		return false
	var p := player.global_position
	file.store_string(JSON.stringify({"player": [p.x, p.y, p.z, player.rotation.y]}))
	return true


func load_player() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var file := FileAccess.open(save_path, FileAccess.READ)
	if file == null:
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary or not (parsed as Dictionary).get("player") is Array:
		return false
	var at: Array = parsed["player"]
	if at.size() < 4:
		return false
	player.global_position = Vector3(float(at[0]), float(at[1]), float(at[2]))
	player.rotation.y = float(at[3])
	return true


## Frames after startup, headless: what a frame's main loop costs
## without rendering.
var _report_in: int = 0
var _loop_acc := 0.0
var _loop_n := 0


func _headless_reports() -> void:
	print("[worldbuilder] main loop: %.1f ms a frame over %d headless frames"
		% [_loop_acc / maxi(_loop_n, 1) * 1000.0, _loop_n])


func _process(_delta: float) -> void:
	if _report_in > 0:
		_report_in -= 1
		_loop_acc += Performance.get_monitor(Performance.TIME_PROCESS)
		_loop_n += 1
		if _report_in == 0:
			_headless_reports()
	var view := player.look_view()
	_reveal_labels(view)
	if view != null and view.has_method("describe"):
		hud.set_look_text(str(view.call("describe")))
	else:
		hud.set_look_text("")


## Floating text shows only on what the crosshair is over. Signs are
## physical and stay.
var _labelled: Node = null


func _reveal_labels(view: Node3D) -> void:
	var target: Node = view
	if target == null:
		var collider := player.aimed_collider()
		if collider != null and collider.has_meta("owner_view"):
			target = collider.get_meta("owner_view") as Node
	if target == _labelled:
		return
	if _labelled != null and is_instance_valid(_labelled):
		_set_floating(_labelled, false)
	_labelled = target
	if target != null:
		_set_floating(target, true)


static func _set_floating(root: Node, on: bool) -> void:
	for label in root.find_children("*", "Label3D", true, false):
		if label.has_meta("floating"):
			(label as Label3D).visible = on


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("options"):
		settings.toggle()
		player.input_locked = settings.visible
		MouseMode.set_captured(not settings.visible)
	elif event.is_action_pressed("quicksave"):
		hud.toast("saved" if save_player() else "save FAILED")
	elif event.is_action_pressed("quickload"):
		hud.toast("loaded" if load_player() else "no save found")
	elif event.is_action_pressed("graphics_preset"):
		# F7: the next preset, applied on the spot, so the frame rate and
		# the picture can be compared without leaving the world.
		graphics.next_preset()
		graphics.apply(self)
		_save_settings()
		settings.refresh()
		hud.toast("Graphics: " + graphics.summary())


## ---- options: the sun, the weather and the music ------------------------

## Hours 0-24. The sun rises in the east at six, stands 60 degrees up at
## noon, sets in the west at six, and below the horizon the world runs
## on the moon. Colour warms toward the horizon; the sky darkens with it.
func set_time_of_day(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0)
	if sun == null:
		return
	var day_frac := (time_of_day - 6.0) / 12.0          # 0 at sunrise, 1 at sunset
	var elevation := 60.0 * sin(clampf(day_frac, 0.0, 1.0) * PI)
	var up := day_frac >= 0.0 and day_frac <= 1.0
	# The light shines from the east at dawn, the south at noon, the west
	# at dusk (-z is north): its yaw turns from 90 through 0 to -90.
	var azimuth := 90.0 - clampf(day_frac, 0.0, 1.0) * 180.0
	# Below the horizon the same light is the moon, from where it stands
	# (SkyClock), as bright as its phase and height allow; with the moon
	# down, the faint light of the whole sky from overhead.
	var moon := SkyClock.moon_world(time_of_day)
	var moon_light := pow(SkyClock.moon_lit(time_of_day), 1.5) * clampf(moon.y * 5.0, 0.0, 1.0)
	if up:
		sun.rotation_degrees = Vector3(-elevation, azimuth, 0)
	elif moon_light > 0.01:
		sun.basis = Basis.looking_at(-moon, Vector3.UP if absf(moon.y) < 0.99 else Vector3.FORWARD)
	else:
		sun.rotation_degrees = Vector3(-88.0, 0.0, 0.0)
	# Twilight: an hour either side of the horizon, night fades in and
	# out instead of switching.
	var twilight := 1.0
	if day_frac < 0.0:
		twilight = clampf(1.0 + day_frac / 0.085, 0.0, 1.0)
	elif day_frac > 1.0:
		twilight = clampf(1.0 - (day_frac - 1.0) / 0.085, 0.0, 1.0)
	var horizon := clampf(elevation / 20.0, 0.0, 1.0)
	var warm := Color(1.0, 0.62, 0.35).lerp(_sun_base_color, horizon)
	var night := Color(0.45, 0.55, 0.80)
	sun.light_color = night.lerp(warm, twilight)
	var night_energy := lerpf(0.05, 0.35, clampf(moon_light / 0.25, 0.0, 1.0)) * moonlight
	sun.light_energy = lerpf(night_energy, _sun_base_energy * (0.25 + 0.75 * horizon), twilight)
	if sky_mat is ShaderMaterial:
		# Our sky (world/sky.gdshader) wants the sun's true direction,
		# under the horizon too, and the moon's; and with a dome that is
		# bright at dawn, the direct sun can be as weak as it really is
		# at the horizon, coming up over the first twelve degrees.
		var painted := sky_mat as ShaderMaterial
		var true_elevation := 60.0 * sin(day_frac * PI)
		var sun_basis := Basis.from_euler(Vector3(deg_to_rad(-true_elevation), deg_to_rad(azimuth), 0.0))
		painted.set_shader_parameter("sun_dir", sun_basis.z)
		painted.set_shader_parameter("moon_dir", moon)
		painted.set_shader_parameter("moon_up", SkyClock.moon_up(time_of_day))
		painted.set_shader_parameter("moon_sun", SkyClock.sun_world(time_of_day))
		painted.set_shader_parameter("moon_lit", SkyClock.moon_lit(time_of_day))
		var sun_strength := smoothstep(0.0, 1.0, clampf(elevation / 12.0, 0.0, 1.0))
		sun.light_energy = lerpf(night_energy, _sun_base_energy * (0.05 + 0.95 * sun_strength), twilight)
	var day_horizon := Color(0.72, 0.78, 0.84)
	var dusk_horizon := Color(0.95, 0.55, 0.32)
	var night_horizon := Color(0.10, 0.12, 0.18)
	var horizon_color := night_horizon.lerp(dusk_horizon.lerp(day_horizon, horizon), twilight)
	if sky_mat is PhysicalSkyMaterial:
		# A low sun leaves a physical sky dim while the real one glows:
		# lift its energy toward the horizon, and let night fade it.
		(sky_mat as PhysicalSkyMaterial).energy_multiplier = \
			lerpf(0.5, 1.4 + 1.6 * (1.0 - horizon), maxf(twilight, 0.25))
	if sky_mat is ProceduralSkyMaterial:
		# The painted sky: its colours follow the clock by hand.
		var painted := sky_mat as ProceduralSkyMaterial
		var day_top := Color(0.30, 0.48, 0.72)
		var dusk_top := Color(0.16, 0.18, 0.34)
		var night_top := Color(0.03, 0.04, 0.08)
		painted.sky_top_color = night_top.lerp(dusk_top.lerp(day_top, horizon), twilight)
		painted.sky_horizon_color = horizon_color
		painted.ground_horizon_color = horizon_color.darkened(0.15)
	if sky_env != null:
		if sky_mat is PhysicalSkyMaterial or sky_mat is ShaderMaterial:
			# The ambient follows the clock by hand: blue-grey by day, warm
			# at dusk, blue at night. The sky supplies the reflections.
			var day_amb := Color(0.62, 0.68, 0.78)
			var dusk_amb := Color(0.62, 0.44, 0.34)
			var night_amb := Color(0.14, 0.18, 0.28)
			sky_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
			sky_env.ambient_light_color = night_amb.lerp(dusk_amb.lerp(day_amb, horizon), twilight)
			sky_env.ambient_light_energy = lerpf(0.55 * moonlight, 0.66 + 0.04 * horizon, twilight)
		else:
			sky_env.ambient_light_energy = lerpf(0.25 * moonlight, 0.55 + 0.05 * horizon, twilight)
		sky_env.fog_light_color = horizon_color
	_on_time_of_day(horizon, twilight)


## A world's own response to the clock: lamps, stars. horizon is 0 at
## the horizon and 1 with the sun 20 degrees up; twilight is 1 by day
## and 0 by night.
func _on_time_of_day(_horizon: float, _twilight: float) -> void:
	pass


func apply_graphics() -> void:
	graphics.apply(self)


func set_music(on: bool) -> void:
	music_on = on
	if music_player == null:
		return
	if on and not music_player.playing:
		# Headless runs never start a stream (see _looping_player): a
		# saved "music on" would otherwise leak its playback at exit.
		if DisplayServer.get_name() != "headless":
			music_player.play()
	elif not on and music_player.playing:
		music_player.stop()


## The weather, 0 fair to 1 a storm. A world with weather overrides
## this; the options slider calls it.
func set_weather(level: float) -> void:
	weather_level = clampf(level, 0.0, 1.0)


## Every world's keys share one file: what this world does not own is
## read back and kept.
func _save_settings() -> void:
	var saved := _read_settings()
	saved[settings_prefix + "time_of_day"] = time_of_day
	if weather_level >= 0.0:
		saved[settings_prefix + "weather"] = weather_level
	saved[_moonlight_key()] = moonlight
	saved["music"] = music_on
	saved["graphics"] = graphics.to_dict()
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	if file == null:
		return
	file.store_string(JSON.stringify(saved))


func _moonlight_key() -> String:
	return moonlight_key if moonlight_key != "" else settings_prefix + "moonlight"


func _read_settings() -> Dictionary:
	if not FileAccess.file_exists(SETTINGS_PATH):
		return {}
	var file := FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	return parsed if parsed is Dictionary else {}


func _load_settings() -> void:
	var hours := time_of_day
	var on := music_on
	var saved := _read_settings()
	if not saved.is_empty():
		hours = float(saved.get(settings_prefix + "time_of_day", hours))
		on = bool(saved.get("music", on))
		moonlight = float(saved.get(_moonlight_key(), moonlight))
		if weather_level >= 0.0:
			weather_level = float(saved.get(settings_prefix + "weather", weather_level))
		if saved.get("graphics") is Dictionary:
			graphics.from_dict(saved["graphics"])
	if weather_level >= 0.0:
		set_weather(weather_level)
		settings.set_weather(weather_level)
	set_time_of_day(hours)
	set_music(on)
	graphics.apply(self)
	settings.set_values(time_of_day, music_on)
	settings.set_moonlight(moonlight)


func _build_audio() -> void:
	var bus := AudioServer.bus_count
	AudioServer.add_bus(bus)
	AudioServer.set_bus_name(bus, "Room")
	AudioServer.set_bus_send(bus, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = reverb_room_size
	reverb.wet = reverb_wet
	reverb.damping = 0.55
	AudioServer.add_bus_effect(bus, reverb)
	# The weather and the sea play through Outdoor, a harbour bell through
	# Bell into it; each has a low-pass a world closes when the sound is
	# heard through walls (a world with nothing to muffle leaves them open).
	for name_: String in ["Outdoor", "Bell"]:
		if AudioServer.get_bus_index(name_) == -1:
			var idx := AudioServer.bus_count
			AudioServer.add_bus(idx)
			AudioServer.set_bus_name(idx, name_)
			var cut := AudioEffectLowPassFilter.new()
			cut.cutoff_hz = 20000.0
			AudioServer.add_bus_effect(idx, cut)
		AudioServer.set_bus_send(AudioServer.get_bus_index(name_), "Outdoor" if name_ == "Bell" else "Master")
		var i := AudioServer.get_bus_index(name_)
		(AudioServer.get_bus_effect(i, 0) as AudioEffectLowPassFilter).cutoff_hz = 20000.0
		AudioServer.set_bus_volume_db(i, 0.0)

	# The music is off until the options toggle turns it on: it must not
	# play for the seconds before the settings load, so it is never told
	# to autoplay at all.
	music_player = _looping_player("res://audio/music_loop.wav", -16.0, "Master", false)


func _looping_player(path: String, volume_db: float, bus: String,
		autoplay: bool = true) -> AudioStreamPlayer:
	var stream := load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	var audio_player := AudioStreamPlayer.new()
	audio_player.stream = stream
	audio_player.volume_db = volume_db
	audio_player.bus = bus
	# Playing streams leak their playback objects in a teardown race at
	# process exit; only start them when a real audio driver exists.
	audio_player.autoplay = autoplay and DisplayServer.get_name() != "headless"
	add_child(audio_player)
	_loop_players.append(audio_player)
	return audio_player


func _exit_tree() -> void:
	for audio_player in _loop_players:
		audio_player.stop()
