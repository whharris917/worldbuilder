class_name ShellAcoustics
extends Node
## How the bowls sound to someone at their centre, worked out from where
## each bowl's stone lies at every moment.
##
## What the ear can reach: directions from the centre, 384 spread evenly
## over the sphere. A direction meets a bowl where it falls within the
## bowl's cap (more than a tenth of the radius toward its pole). A bowl
## is heard, and heard back, through the directions where it is met and
## no bowl inside it is, nor the platform underfoot (which shuts out
## everything within 72 degrees of straight down, its edge 4 m out and
## 1.6 m below the ear). That share, and the middle of those directions,
## are worked out again each frame.
##
## Echoes of the footsteps. A sphere's inside is a mirror that sends
## sound from near its centre back to the point opposite: a step at the
## feet comes back focused on a point as far above the centre as the feet
## are below it, 2R / c later (R the radius, c 343 m/s), converging there
## from every direction the bowl is heard through. A converging wave's
## amplitude goes as 1/s at s from its focus, so an echo against the
## step heard directly (1.6 m from the ear) is a (1.6 / s), a the share
## of the bowl heard through times the stone's reflectance, 0.95. It
## passes the focus and goes out to the bowl again, and comes back on the
## feet 4R / c after the step, and so on: three returns from each bowl,
## each a times the last. Standing at the platform's centre, the first
## return is about as loud as the step itself; a few metres off the
## centre it is much weaker. The air takes the treble on the way, the
## more the longer the path (about 43,900 / sqrt(d) Hz at -3 dB): echoes
## travelling under 400 m play through a low-pass at 3 kHz, under 1.2 km
## at 1.5 kHz, beyond at 800 Hz.
##
## The groans: when a bowl jolts onto a new axis its stone rings, and the
## sound reaches the centre R / c later, from the middle of the
## directions it is heard through, as loud as the share of it heard and
## a sixth as loud through stone. `heard` is given with the bowl's index
## as it arrives.
##
## Each bowl hums as it turns (shell_drone_loop.wav), from the middle of
## the directions it is heard through: pitched by its rate of turning
## and its size (the square root of each), as loud as the share heard.
##
## The sun breaking through: when the line from the centre to the sun
## comes clear of every bowl (and the sun is up), a high chord swells
## from the sun's direction (shell_light.wav); not again within 4 s, so
## a gap's edge passing slowly over the sun is heard once.
##
## The wind at this height, a low rush of air, swells with the speed of a
## fall.

signal heard(index: int)

const C_SOUND := 343.0
const REFLECTANCE := 0.95
const RETURNS := 3
const DIRECTIONS := 384
const PLATFORM_COS := -0.31             # below this, a direction meets the platform
const ECHO_BUSES := {"Echo near": 3000.0, "Echo mid": 1500.0, "Echo far": 800.0}
const DRONE := preload("res://audio/shell_drone_loop.wav")
const AIR := preload("res://audio/air_loop.wav")
const LIGHT := preload("res://audio/shell_light.wav")
const SHIFTS: Array[AudioStream] = [preload("res://audio/shell_shift_1.wav"), preload("res://audio/shell_shift_2.wav"),
	preload("res://audio/shell_shift_3.wav"), preload("res://audio/shell_shift_4.wav"), preload("res://audio/shell_shift_5.wav")]

var shells: Array[SpinningShell] = []
var centre := Vector3.ZERO
var player: Player
var sun_dir := Vector3.UP               # toward the sun

var _dirs: Array[Vector3] = []
var _share: Array[float] = []           # per bowl: the share of directions it is heard through
var _toward: Array[Vector3] = []        # per bowl: the middle of those directions
var _drones: Array[AudioStreamPlayer3D] = []
var _pending: Array[Dictionary] = []    # sounds to start: at, stream, volume, pitch, bus, from
var _pool: Array[AudioStreamPlayer] = []
var _pool_3d: Array[AudioStreamPlayer3D] = []
var _wind: AudioStreamPlayer
var _clock := 0.0
var _sun_clear := false
var _light_at := -10.0                  # when the chord last sounded
var _buses: Array[String] = []
var _silent := DisplayServer.get_name() == "headless"


func _init() -> void:
	name = "Acoustics"


func _ready() -> void:
	var golden := PI * (3.0 - sqrt(5.0))
	for i in DIRECTIONS:
		var y := 1.0 - 2.0 * (i + 0.5) / DIRECTIONS
		var r := sqrt(1.0 - y * y)
		_dirs.append(Vector3(r * cos(golden * i), y, r * sin(golden * i)))
	# The footsteps play on "Room"; a bus of that name left by another
	# world, with its effects, is replaced by a plain one.
	while AudioServer.get_bus_index("Room") != -1:
		AudioServer.remove_bus(AudioServer.get_bus_index("Room"))
	_make_bus("Room", null)
	for bus_name: String in ECHO_BUSES:
		var lp := AudioEffectLowPassFilter.new()
		lp.cutoff_hz = ECHO_BUSES[bus_name]
		_make_bus(bus_name, lp)
	for i in shells.size():
		_share.append(0.0)
		_toward.append(Vector3.UP)
		var drone := AudioStreamPlayer3D.new()
		drone.stream = DRONE
		drone.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		drone.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		var shell := shells[i]
		drone.pitch_scale = sqrt(20.0 / shell.period) * sqrt(100.0 / shell.radius)
		drone.volume_db = -80.0
		add_child(drone)
		_drones.append(drone)
		shell.turned.connect(_on_turned.bind(i))
	for i in 24:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)
	for i in 6:
		var p3 := AudioStreamPlayer3D.new()
		p3.attenuation_model = AudioStreamPlayer3D.ATTENUATION_DISABLED
		p3.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		add_child(p3)
		_pool_3d.append(p3)
	_wind = AudioStreamPlayer.new()
	_wind.stream = AIR
	_wind.volume_db = -30.0
	add_child(_wind)
	player.footstep.connect(_on_step, CONNECT_DEFERRED)
	if not _silent:
		for d in _drones:
			d.play(randf() * 16.0)
		_wind.play()


func _exit_tree() -> void:
	_pending.clear()
	for node in get_children():
		if node is AudioStreamPlayer:
			(node as AudioStreamPlayer).stop()
		elif node is AudioStreamPlayer3D:
			(node as AudioStreamPlayer3D).stop()
	for bus_name in _buses:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.remove_bus(idx)
	_buses.clear()


func _make_bus(bus_name: String, effect: AudioEffect) -> void:
	AudioServer.add_bus()
	var idx := AudioServer.bus_count - 1
	AudioServer.set_bus_name(idx, bus_name)
	AudioServer.set_bus_send(idx, "Master")
	if effect != null:
		AudioServer.add_bus_effect(idx, effect)
	_buses.append(bus_name)


## The share of each bowl heard from the centre, and where from.
func _listen() -> void:
	var poles: Array[Vector3] = []
	for shell in shells:
		poles.append(shell.pole())
	var counts: Array[int] = []
	var sums: Array[Vector3] = []
	for k in shells.size():
		counts.append(0)
		sums.append(Vector3.ZERO)
	for d in _dirs:
		if d.y < PLATFORM_COS:
			continue
		for k in shells.size():
			if d.dot(poles[k]) > 0.1:
				counts[k] += 1
				sums[k] += d
				break
	for k in shells.size():
		_share[k] = float(counts[k]) / DIRECTIONS
		_toward[k] = sums[k].normalized() if counts[k] > 0 else poles[k]
	var clear := sun_dir.y > 0.0
	for pole in poles:
		if sun_dir.dot(pole) > 0.1:
			clear = false
	if clear and not _sun_clear and _clock - _light_at > 4.0:
		_light_at = _clock
		_later(0.0, {"light": true})
	_sun_clear = clear


func _process(delta: float) -> void:
	_clock += delta
	_listen()
	var ear := player.get_viewport().get_camera_3d().global_position
	for k in shells.size():
		var drone := _drones[k]
		drone.global_position = ear + _toward[k] * 20.0
		var size := shells[k].radius / 500.0
		drone.volume_db = linear_to_db(maxf(_share[k] * 2.0 * (0.4 + 0.6 * size), 0.003)) - 14.0
	var fall := maxf(-player.velocity.y, 0.0)
	_wind.volume_db = -30.0 + 20.0 * log(1.0 + fall / 6.0) / log(10.0)
	_wind.pitch_scale = 1.0 + minf(fall / 80.0, 0.5)
	while not _pending.is_empty() and float(_pending[0]["at"]) <= _clock:
		_start(_pending.pop_front())


## A sound to start `delay` seconds from now, in time order.
func _later(delay: float, sound: Dictionary) -> void:
	if _silent:
		return
	sound["at"] = _clock + delay
	var i := 0
	while i < _pending.size() and float(_pending[i]["at"]) <= float(sound["at"]):
		i += 1
	_pending.insert(i, sound)


func _start(sound: Dictionary) -> void:
	if sound.has("shell"):
		var k := int(sound["shell"])
		var p3 := _free_3d()
		var ear := player.get_viewport().get_camera_3d().global_position
		p3.global_position = ear + _toward[k] * 20.0
		p3.stream = SHIFTS[k]
		var heard_share := _share[k] / 0.45
		p3.volume_db = linear_to_db(clampf(1.0 / 6.0 + heard_share, 0.0, 1.2)) - 3.0
		p3.play()
		heard.emit(k)
		return
	if sound.has("light"):
		var pl := _free_3d()
		pl.global_position = player.get_viewport().get_camera_3d().global_position + sun_dir * 20.0
		pl.stream = LIGHT
		pl.volume_db = -9.0
		pl.play()
		return
	var p := _free()
	p.stream = sound["stream"]
	p.volume_db = float(sound["volume"])
	p.pitch_scale = float(sound["pitch"])
	p.bus = str(sound["bus"])
	p.play()


func _free() -> AudioStreamPlayer:
	for p in _pool:
		if not p.playing:
			return p
	return _pool[0]


func _free_3d() -> AudioStreamPlayer3D:
	for p in _pool_3d:
		if not p.playing:
			return p
	return _pool_3d[0]


func _on_turned(index: int) -> void:
	_later(shells[index].radius / C_SOUND, {"shell": index})


## A step or a landing has just started: its returns from every bowl.
func _on_step() -> void:
	var step := player.step_player()
	if step.stream == null:
		return
	var feet := player.global_position
	var ear := player.get_viewport().get_camera_3d().global_position
	var opposite := 2.0 * centre - feet
	for k in shells.size():
		var a := _share[k] * REFLECTANCE
		if a < 0.01:
			continue
		var amp := 1.0
		for n in range(1, RETURNS + 1):
			amp *= a
			var focus := opposite if n % 2 == 1 else feet
			var s := maxf(ear.distance_to(focus), 0.3)
			var level := minf(amp * 1.6 / s, 1.0)
			if level < 0.003:
				break
			var path := 2.0 * n * shells[k].radius
			var bus := "Echo near" if path < 400.0 else ("Echo mid" if path < 1200.0 else "Echo far")
			_later(path / C_SOUND, {"stream": step.stream, "volume": step.volume_db + linear_to_db(level),
				"pitch": step.pitch_scale, "bus": bus})
