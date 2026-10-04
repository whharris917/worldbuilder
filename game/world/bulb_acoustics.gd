class_name BulbAcoustics
extends Node
## How sound travels in the one-bulb scene, worked out from the room's
## known shape for every source alike: a source says only where it is and
## what it plays, and this decides how it reaches the ear (the camera).
## Each source plays on its own bus (its own effects first, then air and
## wall, reverb, echoes) with a twin at the doorway on a second bus. The
## listener's own sounds, the footsteps, play on the bus "Room", which
## this makes for the scene.
##
## Spreading: amplitude as 1/d (Godot's "inverse distance", -6 dB a
## doubling, the physical law); Godot's "inverse square" is 1/d^2 in
## amplitude, -12 dB a doubling, offered for comparison.
## Air absorption: treble lost with distance, about 1.56e-9 f^2 dB/m
## (0.025 dB/m at 4 kHz, 0.1 at 8 kHz, after ISO 9613-1 at 20 C and 50%
## humidity), so the -3 dB point is 43,900 / sqrt(d) Hz.
## Over the wall: when the wall stands between source and ear, sound
## still reaches over its top edge. Maekawa's barrier loss,
## 10 log10(3 + 20 N) dB with N = 2 delta f / c, delta the detour over
## the edge: about the loss at 500 Hz overall, and a low-pass where the
## edge starts to shade the treble, c / delta. The wall's own
## transmission, some -45 dB for 20 cm of masonry, is neglected.
## Through the doorway: with source and ear on opposite sides, the twin
## plays from the doorway, as loud as the path through it allows
## (1/(d1 + d2) against the 1/d2 Godot applies) and duller the more
## sharply the path bends there.
## Reverb: the room's own, Sabine's RT60 = 0.161 V / A, the open top
## counting as a perfect absorber, floor and wall by their materials'
## coefficients; mapped onto Godot's reverb (a Freeverb: comb feedback
## 0.7 + 0.28 room size over about 30 ms combs), heard while the ear is
## inside the room, louder against the direct sound beyond the critical
## distance. Reverb is linear, so one per source sums to the room's.
## Echoes: the wall's first reflections, for the short sounds (footsteps
## and knocks), where they are heard as echoes; under a long sound they
## blend into the reverb, and a delay moved while it plays crackles.
## Inside, the nearest stretch of wall and the opposite one, at the
## points along the line from the centre through the midpoint of source
## and ear; outside, the wall's outer face. Each arrives (a + b - d) / c
## after the direct sound, a and b the distances from source and ear to
## the wall. A curved wall focuses or spreads its reflection like a
## mirror, taken at normal incidence: vertically the wall is flat, the
## wave's radius a there; across, it leaves with radius rho, from
## 1/rho = 1/a - 2/R (R the wall's radius, negative for the convex outer
## face), and reaches the ear with amplitude
## sqrt(a / (a + b)) sqrt(rho / (rho + b)) / a. Inside the room the
## reflection converges toward the centre, and near the centre it
## arrives from every direction at once, capped at 12 dB over a flat
## wall's. Lost where the wall is lower than the reflection point (soft
## over half a metre) or the doorway takes it; the wall's absorption
## takes its share.
## Doppler: Godot's, on the sources and the camera.
## Sound's travel time (about 3 ms a metre) is not delayed, the echoes'
## extra path excepted.

const C_SOUND := 343.0
const FOCUS_CAP := 4.0                  # 12 dB over a flat wall's echo

var room_r := 15.0
var wall_h := 3.6
var wall_t := 0.2
var door_w := 0.9
var alpha_floor := 0.02
var alpha_wall := 0.02
var spreading := "1/d"
var air := true
var over_wall := true
var doorway := true
var reverb := true
var echoes := true
var doppler := true
var status := ""

var _sources := {}                      # id -> Dictionary
var _buses: Array[String] = []
var _ear := Transform3D.IDENTITY
var _feet := Vector3.ZERO
var _rt60 := 0.0
var _critical := 1.0
var _feedback := 0.0
var _room_verb: AudioEffectReverb
var _room_echo: AudioEffectDelay
var _step_note := ""
var _silent := DisplayServer.get_name() == "headless"


func _init() -> void:
	name = "Acoustics"


## The listener's own sounds: the footsteps play on "Room" from the
## player. A world built on WorldBase leaves a Room bus of its own behind;
## it is replaced while this scene is open.
func _ready() -> void:
	while AudioServer.get_bus_index("Room") != -1:
		AudioServer.remove_bus(AudioServer.get_bus_index("Room"))
	_room_verb = AudioEffectReverb.new()
	_room_echo = _echo_effect()
	_make_bus("Room", [_room_verb, _room_echo])


func _exit_tree() -> void:
	_sources.clear()
	_room_verb = null
	_room_echo = null
	for bus_name in _buses:
		var idx := AudioServer.get_bus_index(bus_name)
		if idx != -1:
			AudioServer.remove_bus(idx)
	_buses.clear()


func _make_bus(bus_name: String, effects: Array) -> void:
	var i := AudioServer.bus_count
	AudioServer.add_bus(i)
	AudioServer.set_bus_name(i, bus_name)
	AudioServer.set_bus_send(i, "Master")
	for effect: AudioEffect in effects:
		AudioServer.add_bus_effect(i, effect)
	_buses.append(bus_name)


func _echo_effect() -> AudioEffectDelay:
	var echo := AudioEffectDelay.new()
	echo.dry = 1.0
	echo.feedback_active = false
	echo.tap1_active = false
	echo.tap2_active = false
	return echo


## A source: `at` carries it (a looping source plays from there and
## starts at once), or null for one heard where play() puts it. `own`
## are its own effects, ahead of the room's (shared by its doorway twin).
func add_source(id: String, at: Node3D, stream: AudioStream, own: Array = [], voices := 1) -> void:
	var lp := AudioEffectLowPassFilter.new()
	var door_lp := AudioEffectLowPassFilter.new()
	var verb := AudioEffectReverb.new()
	var echo := _echo_effect()
	_make_bus("BulbSound_" + id, own + [lp, verb, echo])
	_make_bus("BulbSound_" + id + "_door", own + [door_lp])
	var main := AudioStreamPlayer3D.new()
	var door := AudioStreamPlayer3D.new()
	for p: AudioStreamPlayer3D in [main, door]:
		p.stream = stream
		p.unit_size = 2.0
		p.max_distance = 0.0
		p.attenuation_filter_db = 0.0          # air absorption is done on the bus
		p.max_polyphony = voices
		p.volume_db = -80.0
	main.bus = "BulbSound_" + id
	door.bus = "BulbSound_" + id + "_door"
	door.top_level = true
	add_child(door)
	if at != null:
		at.add_child(main)
	else:
		main.top_level = true
		add_child(main)
	_sources[id] = {"main": main, "door": door, "lp": lp, "door_lp": door_lp, "verb": verb, "echo": echo,
		"level": 0.0, "paused": false, "note": ""}
	if at != null and not _silent:
		main.play()
		door.play()


func set_level(id: String, db: float) -> void:
	_sources[id]["level"] = db


func set_paused(id: String, paused: bool) -> void:
	_sources[id]["paused"] = paused


func source_note(id: String) -> String:
	return str(_sources[id]["note"])


## A short sound from a source carried by nothing: placed, routed and its
## echoes set for this moment, then started.
func play(id: String, stream: AudioStream, at: Vector3, db: float, pitch: float) -> void:
	if _silent:
		return
	var src: Dictionary = _sources[id]
	var main := src["main"] as AudioStreamPlayer3D
	main.global_position = at
	src["level"] = db
	for p: AudioStreamPlayer3D in [main, src["door"] as AudioStreamPlayer3D]:
		p.stream = stream
		p.pitch_scale = pitch
	_route(src)
	_set_echoes(src["echo"] as AudioEffectDelay, at, _ear.origin)
	main.play()
	(src["door"] as AudioStreamPlayer3D).play()


## A footstep is about to sound: its echoes set for where the feet and
## the ear are now. The steps themselves are the player's.
func step() -> void:
	if _room_echo == null:
		return
	_step_note = _set_echoes(_room_echo, _feet, _ear.origin)


## Each frame: the room's reverberation for its present shape, then
## every source's paths to the ear.
func listen(ear: Transform3D, feet: Vector3) -> void:
	_ear = ear
	_feet = feet
	var area := PI * room_r * room_r
	var volume := area * wall_h
	var absorb := area * (1.0 + alpha_floor) + TAU * room_r * wall_h * alpha_wall
	# With no wall there is no room and no reverberation; the formulas
	# would divide nothing by nothing, and a reverb fed that falls silent,
	# taking its source with it.
	var walled := wall_h > 0.05
	_rt60 = 0.161 * volume / absorb if walled else 0.0
	_feedback = pow(10.0, -0.09 / _rt60) if walled else 0.0
	_critical = 0.057 * sqrt(volume / _rt60) if walled else 1.0
	for src: Dictionary in _sources.values():
		_route(src)
	if _room_verb != null:
		_set_reverb(_room_verb, feet.distance_to(ear.origin))
	status = "Reverb %.2f s (Sabine; the open top absorbs most)." % _rt60
	if echoes and _step_note != "":
		status += " Your steps' echo: " + _step_note + "."


func _inside(p: Vector3) -> bool:
	return Vector2(p.x, p.z).length() < room_r + wall_t * 0.5


func _set_reverb(rv: AudioEffectReverb, d: float) -> void:
	rv.room_size = clampf((_feedback - 0.7) / 0.28, 0.0, 1.0)
	rv.damping = 0.5
	rv.dry = 1.0
	rv.wet = clampf(0.12 * d / _critical, 0.04, 0.6) if reverb and _inside(_ear.origin) and wall_h > 0.05 else 0.0
	rv.predelay_msec = clampf((room_r - Vector2(_ear.origin.x, _ear.origin.z).length()) / C_SOUND * 1000.0, 5.0, 100.0)


## Both paths for one source, set on its players and buses.
func _route(src: Dictionary) -> void:
	var main := src["main"] as AudioStreamPlayer3D
	var door := src["door"] as AudioStreamPlayer3D
	var ear := _ear.origin
	var level := float(src["level"])
	var models := {"1/d": AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE,
		"1/d²": AudioStreamPlayer3D.ATTENUATION_INVERSE_SQUARE_DISTANCE,
		"Log": AudioStreamPlayer3D.ATTENUATION_LOGARITHMIC, "None": AudioStreamPlayer3D.ATTENUATION_DISABLED}
	var tracking := AudioStreamPlayer3D.DOPPLER_TRACKING_PHYSICS_STEP if doppler else AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	for p: AudioStreamPlayer3D in [main, door]:
		p.attenuation_model = models[spreading]
		p.stream_paused = bool(src["paused"])
	main.doppler_tracking = tracking
	var notes: Array[String] = []

	# The straight path: over the wall's top if the wall stands between,
	# clear if the line passes the doorway or both are on one side.
	var at := main.global_position
	var d := at.distance_to(ear)
	var gain := 0.0
	var cut := 20000.0
	if air:
		cut = minf(cut, 43900.0 / sqrt(maxf(d, 1.0)))
	var crossing := _inside(at) != _inside(ear)
	var through_door := false
	if crossing:
		var hit := _wall_crossing(at, ear)
		var half := asin(door_w * 0.5 / room_r)
		through_door = absf(atan2(hit.x, -hit.z)) < half and hit.y < wall_h
		if hit.y < wall_h and not through_door:
			if over_wall:
				var top := Vector3(hit.x, wall_h, hit.z)
				var delta := at.distance_to(top) + top.distance_to(ear) - d
				var loss := 10.0 * log(3.0 + 20.0 * 2.0 * delta * 500.0 / C_SOUND) / log(10.0)
				gain -= loss
				cut = minf(cut, clampf(C_SOUND / maxf(delta, 0.01), 150.0, 20000.0))
				notes.append("over the wall %d dB, treble above %d Hz shaded" % [int(-loss), int(cut)])
			else:
				gain -= 45.0
				notes.append("through the wall -45 dB")
	main.volume_db = level + gain
	(src["lp"] as AudioEffectLowPassFilter).cutoff_hz = cut

	# The doorway path, when the wall stands between and the line misses it.
	if doorway and crossing and not through_door:
		var gap := Vector3(0.0, clampf((at.y + ear.y) * 0.5, 0.3, wall_h - 0.3), -(room_r + wall_t * 0.5))
		door.global_position = gap
		var d1 := at.distance_to(gap)
		var d2 := maxf(gap.distance_to(ear), 0.5)
		var bend := (gap - at).normalized().angle_to((ear - gap).normalized())
		var bend_loss := 9.0 * clampf(bend / (PI * 0.5), 0.0, 1.5)
		door.volume_db = level - 20.0 * log((d1 + d2) / d2) / log(10.0) - bend_loss
		var door_cut := lerpf(16000.0, 600.0, clampf(bend / (PI * 0.5), 0.0, 1.0))
		if air:
			door_cut = minf(door_cut, 43900.0 / sqrt(maxf(d1 + d2, 1.0)))
		(src["door_lp"] as AudioEffectLowPassFilter).cutoff_hz = door_cut
		notes.append("through the doorway %d dB, bent %d degrees" % [int(door.volume_db - level), int(rad_to_deg(bend))])
	else:
		door.volume_db = -80.0

	_set_reverb(src["verb"] as AudioEffectReverb, d)
	if air and d > 30.0:
		notes.append("air takes the treble above %d Hz" % int(43900.0 / sqrt(d)))
	var note := "%.0f m away" % d
	if not notes.is_empty():
		note += "; " + "; ".join(notes)
	src["note"] = note


## The wall's first reflections of a sound at `src` heard at `ear`, set
## as the delay's two taps; a few words on them, or "" when there are none.
func _set_echoes(echo: AudioEffectDelay, src: Vector3, ear: Vector3) -> String:
	echo.tap1_active = false
	echo.tap2_active = false
	if not echoes or wall_h <= 0.05:
		return ""
	var d := maxf(src.distance_to(ear), 0.3)
	var mid := Vector2(src.x + ear.x, src.z + ear.z) * 0.5
	var out := mid.normalized() if mid.length() > 0.01 else Vector2(0.0, 1.0)
	var walls: Array = []                 # [point on the wall, its signed radius]
	var src_in := _inside(src)
	if src_in != _inside(ear):
		return ""
	if src_in:
		walls = [[out * room_r, room_r], [-out * room_r, room_r]]
	else:
		walls = [[out * (room_r + wall_t), -(room_r + wall_t)]]
	var said: Array[String] = []
	for i in walls.size():
		var flat := walls[i][0] as Vector2
		var radius := float(walls[i][1])
		var a := Vector2(src.x, src.z).distance_to(flat)
		var b := Vector2(ear.x, ear.z).distance_to(flat)
		var up := src.y + (ear.y - src.y) * a / maxf(a + b, 0.01)
		var spot := Vector3(flat.x, up, flat.y)
		a = maxf(src.distance_to(spot), 0.1)
		b = maxf(spot.distance_to(ear), 0.1)
		# Across, the wave leaves the curved wall with radius rho.
		var inv_rho := 1.0 / a - 2.0 / radius
		var across := 1.0
		if absf(inv_rho) > 1e-6:
			var rho := 1.0 / inv_rho
			across = sqrt(absf(rho / (rho + b))) if absf(rho + b) > 1e-6 else 1e6
		var flat_amp := 1.0 / (a + b)
		var amp := sqrt(a / (a + b)) * across / a
		amp = minf(amp, flat_amp * FOCUS_CAP)
		var kept := sqrt(1.0 - alpha_wall) * clampf((wall_h - up) / 0.5, 0.0, 1.0)
		var half := asin(door_w * 0.5 / room_r)
		if absf(atan2(flat.x, -flat.y)) < half + 0.02:
			kept = 0.0
		var rel := amp * d * kept
		if rel < 0.001:
			continue
		var ms := clampf((a + b - d) / C_SOUND * 1000.0, 1.0, 1500.0)
		var db := clampf(20.0 * log(rel) / log(10.0), -60.0, 0.0)
		var toward := (spot - ear).normalized()
		var pan := clampf(toward.dot(_ear.basis.x), -1.0, 1.0)
		var focus := 20.0 * log(amp / flat_amp) / log(10.0)
		if i == 0:
			echo.tap1_active = true
			echo.tap1_delay_ms = ms
			echo.tap1_level_db = db
			echo.tap1_pan = pan
		else:
			echo.tap2_active = true
			echo.tap2_delay_ms = ms
			echo.tap2_level_db = db
			echo.tap2_pan = pan
		var where := ("near wall" if i == 0 else "far wall") if src_in else "outer face"
		said.append("%d ms off the %s, %+d dB by its curve" % [int(ms), where, int(round(focus))])
	return ", ".join(said)


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
