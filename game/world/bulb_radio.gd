class_name BulbRadio
extends Node3D
## A radio playing the director's recording "Levittown Levity", sitting
## on the one-bulb room's swinging ball, and how its sound reaches the
## ear, worked out each frame from the room's known shape:
##
## Spreading: amplitude as 1/d (Godot's "inverse distance", -6 dB a
## doubling, the physical law); Godot's "inverse square" is 1/d^2 in
## amplitude, -12 dB a doubling, offered for comparison.
## Air absorption: treble lost with distance, about 1.56e-9 f^2 dB/m
## (0.025 dB/m at 4 kHz, 0.1 at 8 kHz, after ISO 9613-1 at 20 C and 50%
## humidity), so the -3 dB point is 43,900 / sqrt(d) Hz.
## Over the wall: when the wall stands between radio and ear, sound
## still reaches over its top edge. Maekawa's barrier loss,
## 10 log10(3 + 20 N) dB with N = 2 delta f / c, delta the detour over
## the edge: about the loss at 500 Hz overall, and a low-pass where the
## edge starts to shade the treble, c / delta. The wall's own
## transmission, some -45 dB for 20 cm of masonry, is neglected.
## Through the doorway: with radio and ear on opposite sides, a second
## copy of the sound plays from the doorway, as loud as the path through
## it allows (1/(d1 + d2) against the 1/d2 Godot applies) and duller the
## more sharply the path bends there.
## Reverb: Sabine's RT60 = 0.161 V / A, the open top counting as a
## perfect absorber, floor and wall by their materials' coefficients;
## mapped onto Godot's reverb (a Freeverb: comb feedback 0.7 + 0.28 room
## size over about 30 ms combs), heard while the ear is inside the room,
## louder against the direct sound beyond the critical distance.
## Doppler: Godot's, on the radio and the camera.
## Sound's travel time (about 3 ms a metre) is not delayed.

const C_SOUND := 343.0

var room_r := 15.0
var wall_h := 3.6
var wall_t := 0.2
var door_w := 0.9
var alpha_floor := 0.02
var alpha_wall := 0.02
var playing := true
var volume_db := -6.0
var spreading := "1/d"
var air := true
var over_wall := true
var doorway := true
var reverb := true
var doppler := true
var status := ""

var _direct: AudioStreamPlayer3D
var _door: AudioStreamPlayer3D
var _dial: StandardMaterial3D
var _lp: Array[AudioEffectLowPassFilter] = []
var _rv: Array[AudioEffectReverb] = []
const BUSES: Array[String] = ["BulbRadio", "BulbRadioDoor"]


func _init() -> void:
	name = "Radio"
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.17, 0.08)
	wood.roughness = 0.45
	_box(Vector3(0.36, 0.24, 0.17), Vector3.ZERO, wood)
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.55, 0.47, 0.33)
	cloth.roughness = 1.0
	_box(Vector3(0.20, 0.15, 0.01), Vector3(-0.06, 0.0, -0.088), cloth)
	_dial = StandardMaterial3D.new()
	_dial.albedo_color = Color(0.9, 0.8, 0.55)
	_dial.emission_enabled = true
	_dial.emission = Color(1.0, 0.7, 0.35)
	_dial.emission_energy_multiplier = 0.6
	_box(Vector3(0.08, 0.05, 0.01), Vector3(0.11, 0.03, -0.088), _dial)
	_direct = AudioStreamPlayer3D.new()
	add_child(_direct)
	_door = AudioStreamPlayer3D.new()
	_door.top_level = true
	add_child(_door)


func _box(size: Vector3, at: Vector3, mat: Material) -> void:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = at
	node.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	add_child(node)


func _ready() -> void:
	for bus_name in BUSES:
		if AudioServer.get_bus_index(bus_name) == -1:
			var i := AudioServer.bus_count
			AudioServer.add_bus(i)
			AudioServer.set_bus_name(i, bus_name)
			AudioServer.set_bus_send(i, "Master")
			AudioServer.add_bus_effect(i, AudioEffectLowPassFilter.new())
			AudioServer.add_bus_effect(i, AudioEffectReverb.new())
		var idx := AudioServer.get_bus_index(bus_name)
		_lp.append(AudioServer.get_bus_effect(idx, 0) as AudioEffectLowPassFilter)
		_rv.append(AudioServer.get_bus_effect(idx, 1) as AudioEffectReverb)
	if DisplayServer.get_name() == "headless":
		return
	var stream := load("res://audio/levittown_levity.mp3") as AudioStreamMP3
	stream.loop = true
	for p: AudioStreamPlayer3D in [_direct, _door]:
		p.stream = stream
		p.unit_size = 2.0
		p.max_distance = 0.0
		p.attenuation_filter_db = 0.0          # air absorption is done on the bus
	_direct.bus = BUSES[0]
	_door.bus = BUSES[1]
	_direct.play()
	_door.play()


func _exit_tree() -> void:
	for bus_name in BUSES:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.remove_bus(idx)


## Work out both paths for an ear at `ear` and set the players and buses.
func listen(ear: Vector3) -> void:
	if _lp.is_empty():
		return
	var src := _direct.global_position
	var models := {"1/d": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
		"1/d²": AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE,
		"Log": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC, "None": AudioStreamPlayer3D.ATTENUATION_DISABLED}
	var tracking := AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP if doppler else AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	for p: AudioStreamPlayer3D in [_direct, _door]:
		p.attenuation_model = models[spreading]
		p.stream_paused = not playing
	_direct.doppler_tracking = tracking
	_dial.emission_energy_multiplier = 0.6 if playing else 0.0
	var notes: Array[String] = []

	# The straight path: over the wall's top if the wall stands between,
	# clear if the line passes the doorway or both are on one side.
	var d := src.distance_to(ear)
	var gain := 0.0
	var cut := 20000.0
	if air:
		cut = minf(cut, 43900.0 / sqrt(maxf(d, 1.0)))
	var src_in := Vector2(src.x, src.z).length() < room_r + wall_t * 0.5
	var ear_in := Vector2(ear.x, ear.z).length() < room_r + wall_t * 0.5
	var crossing := src_in != ear_in
	var through_door := false
	if crossing:
		var hit := _wall_crossing(src, ear)
		var a := atan2(hit.x, -hit.z)
		var half := asin(door_w * 0.5 / room_r)
		through_door = absf(a) < half and hit.y < wall_h
		if hit.y < wall_h and not through_door:
			if over_wall:
				var top := Vector3(hit.x, wall_h, hit.z)
				var delta := src.distance_to(top) + top.distance_to(ear) - d
				var loss := 10.0 * log(3.0 + 20.0 * 2.0 * delta * 500.0 / C_SOUND) / log(10.0)
				gain -= loss
				cut = minf(cut, clampf(C_SOUND / maxf(delta, 0.01), 150.0, 20000.0))
				notes.append("over the wall %d dB, treble above %d Hz shaded" % [int(-loss), int(cut)])
			else:
				gain -= 45.0
				notes.append("through the wall -45 dB")
	_direct.volume_db = volume_db + gain
	_lp[0].cutoff_hz = cut

	# The doorway path, when the wall stands between and the line misses it.
	var door_on := doorway and crossing and not through_door
	if door_on:
		var at := Vector3(0.0, clampf((src.y + ear.y) * 0.5, 0.3, wall_h - 0.3), -(room_r + wall_t * 0.5))
		_door.global_position = at
		var d1 := src.distance_to(at)
		var d2 := maxf(at.distance_to(ear), 0.5)
		var bend := (at - src).normalized().angle_to((ear - at).normalized())
		var bend_loss := 9.0 * clampf(bend / (PI * 0.5), 0.0, 1.5)
		_door.volume_db = volume_db - 20.0 * log((d1 + d2) / d2) / log(10.0) - bend_loss
		var door_cut := lerpf(16000.0, 600.0, clampf(bend / (PI * 0.5), 0.0, 1.0))
		if air:
			door_cut = minf(door_cut, 43900.0 / sqrt(maxf(d1 + d2, 1.0)))
		_lp[1].cutoff_hz = door_cut
		notes.append("through the doorway %d dB, bent %d degrees" % [int(_door.volume_db - volume_db), int(rad_to_deg(bend))])
	else:
		_door.volume_db = -80.0

	# The room's reverberation, heard inside it.
	var area := PI * room_r * room_r
	var volume := area * wall_h
	var absorb := area * (1.0 + alpha_floor) + TAU * room_r * wall_h * alpha_wall
	# With no wall there is no room and no reverberation; the formulas
	# below would divide nothing by nothing, and a reverb fed that falls
	# silent, taking the music with it.
	var walled := wall_h > 0.05
	var rt60 := 0.161 * volume / absorb if walled else 0.0
	var feedback := pow(10.0, -0.09 / rt60) if walled else 0.0
	var critical := 0.057 * sqrt(volume / rt60) if walled else 1.0
	for i in 2:
		var rv: AudioEffectReverb = _rv[i]
		rv.room_size = clampf((feedback - 0.7) / 0.28, 0.0, 1.0)
		rv.damping = 0.5
		rv.dry = 1.0
		rv.wet = clampf(0.12 * d / critical, 0.04, 0.6) if reverb and ear_in and walled else 0.0
		rv.predelay_msec = clampf((room_r - Vector2(ear.x, ear.z).length()) / C_SOUND * 1000.0, 5.0, 100.0)
	if air and d > 30.0:
		notes.append("air takes the treble above %d Hz" % int(43900.0 / sqrt(d)))
	status = "%.0f m away. Reverb %.2f s (Sabine; the open top absorbs most)." % [d, rt60]
	if not notes.is_empty():
		var said := "; ".join(notes)
		status += " " + said.substr(0, 1).to_upper() + said.substr(1) + "."


## Where the straight line from a to b crosses the wall's middle circle.
func _wall_crossing(a: Vector3, b: Vector3) -> Vector3:
	var p := Vector2(a.x, a.z)
	var q := Vector2(b.x, b.z) - p
	var r := room_r + wall_t * 0.5
	var qa := q.dot(q)
	var qb := 2.0 * p.dot(q)
	var qc := p.dot(p) - r * r
	var disc := maxf(qb * qb - 4.0 * qa * qc, 0.0)
	var t1 := (-qb - sqrt(disc)) / (2.0 * qa)
	var t2 := (-qb + sqrt(disc)) / (2.0 * qa)
	var t := t1 if t1 >= 0.0 and t1 <= 1.0 else t2
	return a.lerp(b, clampf(t, 0.0, 1.0))
