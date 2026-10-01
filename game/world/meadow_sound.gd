class_name MeadowSound
extends Node3D
## The meadow's sounds, each from where it is made and when:
##   the brook, from emitters down its line, louder where it runs
##     narrow over riffles than where it pools;
##   the wind in the leaves, from the wood all round the meadow's edge,
##     as strong as the breeze is now;
##   birds singing from the trees at the edge: the dawn chorus thick,
##     the day's songs sparser, the wood thrush at dusk, and the barred
##     owl now and then at night;
##   crickets in the grass, coming up as the light goes.
## Headless runs count the emitters and make none.

const BIRDS := {
	"whitethroat": ["res://audio/bird_whitethroat.wav"],
	"chickadee": ["res://audio/bird_chickadee.wav"],
	"robin": ["res://audio/bird_robin.wav"],
	"thrush": ["res://audio/bird_thrush_1.wav", "res://audio/bird_thrush_2.wav"],
	"owl": ["res://audio/bird_owl.wav"],
}

var stats: Dictionary = {}
var _land: MeadowLand
var _rng := RandomNumberGenerator.new()
var _leaves: Array[AudioStreamPlayer3D] = []
var _crickets: Array[AudioStreamPlayer3D] = []
var _hour := 12.0
var _twilight := 1.0
var _next_bird := 2.0
var _live := false


func build(land: MeadowLand) -> void:
	_land = land
	_rng.seed = 20261008
	_live = DisplayServer.get_name() != "headless"
	# The brook: an emitter every fourteen metres for a hundred and sixty
	# either side of the meadow's middle.
	var brook := _loop("res://audio/river_loop.wav")
	var z := -160.0
	var n_brook := 0
	while z <= 160.0:
		var half := land.brook_half(z)
		var riffle := 1.0 - smoothstep(1.0, 1.9, half)
		var p := _emitter(brook, Vector3(land.brook_x(z), land.water_y(z) + 0.3, z),
			lerpf(-13.0, -4.0, riffle), 4.0, 45.0)
		if p != null:
			p.pitch_scale = 1.12 + 0.1 * riffle
		n_brook += 1
		z += 14.0
	# The leaves: emitters in the wood round the meadow, high up.
	var leaves := _loop("res://audio/leaves_loop.wav")
	for k in 12:
		var a := TAU * k / 12.0
		var x := MeadowLand.MEADOW.x + cos(a) * MeadowLand.MEADOW_RX * 1.25
		var zz := MeadowLand.MEADOW.y + sin(a) * MeadowLand.MEADOW_RZ * 1.18
		var p := _emitter(leaves, Vector3(x, land.height_at(x, zz) + 10.0, zz), -6.0, 22.0, 160.0)
		if p != null:
			_leaves.append(p)
	# Crickets in the grass about the meadow.
	var crickets := _loop("res://audio/crickets_loop.wav")
	for k in 9:
		var a := _rng.randf_range(0.0, TAU)
		var r := sqrt(_rng.randf()) * 0.85
		var x := MeadowLand.MEADOW.x + cos(a) * MeadowLand.MEADOW_RX * r
		var zz := MeadowLand.MEADOW.y + sin(a) * MeadowLand.MEADOW_RZ * r
		var p := _emitter(crickets, Vector3(x, land.height_at(x, zz) + 0.3, zz), -80.0, 9.0, 70.0)
		if p != null:
			p.pitch_scale = _rng.randf_range(0.94, 1.06)
			_crickets.append(p)
	stats["brook_emitters"] = n_brook
	stats["leaf_emitters"] = 12
	stats["cricket_emitters"] = 9


## The clock: hours 0-24, and twilight 1 by day to 0 at night.
func set_clock(hours: float, twilight: float) -> void:
	_hour = hours
	_twilight = twilight
	var night := 1.0 - twilight
	for p in _crickets:
		p.volume_db = linear_to_db(maxf(smoothstep(0.2, 0.8, night), 0.0001)) - 9.0


## Every frame: the leaves as loud as the wind, and a bird now and then.
func follow(delta: float, listener: Vector3, wind: float) -> void:
	for p in _leaves:
		p.volume_db = linear_to_db(0.12 + 0.88 * clampf(wind / 0.45, 0.0, 1.0)) - 6.0
	if not _live:
		return
	_next_bird -= delta
	if _next_bird > 0.0:
		return
	var song := _pick_song()
	# How busy the birds are at this hour: the gap to the next song.
	var busy := _activity()
	_next_bird = _rng.randf_range(1.0, 3.0) / maxf(busy, 0.02)
	if song == "":
		return
	var paths: Array = BIRDS[song]
	var a := _rng.randf_range(0.0, TAU)
	var r := _rng.randf_range(1.02, 1.25)
	var at := Vector3(MeadowLand.MEADOW.x + cos(a) * MeadowLand.MEADOW_RX * r, 0.0,
		MeadowLand.MEADOW.y + sin(a) * MeadowLand.MEADOW_RZ * r)
	at.y = _land.height_at(at.x, at.z) + _rng.randf_range(4.0, 14.0)
	if at.distance_to(listener) > 140.0:
		return
	_one_shot(str(paths[_rng.randi() % paths.size()]), at, -3.0 if song != "owl" else 0.0,
		_rng.randf_range(0.96, 1.04))


## Songs a minute, roughly, relative to the dawn chorus.
func _activity() -> float:
	var h := _hour
	var dawn := smoothstep(4.3, 5.0, h) * (1.0 - smoothstep(6.5, 8.0, h))
	var day := smoothstep(6.0, 8.0, h) * (1.0 - smoothstep(17.5, 20.5, h))
	var dusk := smoothstep(17.5, 18.5, h) * (1.0 - smoothstep(19.8, 20.8, h))
	var night := 1.0 - smoothstep(4.0, 5.0, h) if h < 12.0 else smoothstep(20.5, 21.5, h)
	return maxf(maxf(dawn * 1.0, day * 0.25), maxf(dusk * 0.4, night * 0.03))


## Which bird sings now, weighted by the hour.
func _pick_song() -> String:
	var h := _hour
	var night := h < 4.5 or h > 20.8
	if night:
		return "owl" if _rng.randf() < 0.7 else ""
	var dusk := h > 17.5
	var weights: Dictionary
	if dusk:
		weights = {"thrush": 5.0, "robin": 2.0, "whitethroat": 1.0}
	elif h < 8.0:
		weights = {"robin": 3.0, "whitethroat": 3.0, "thrush": 1.5, "chickadee": 2.0}
	else:
		weights = {"whitethroat": 2.0, "chickadee": 2.0, "robin": 1.0}
	var total := 0.0
	for k: String in weights:
		total += float(weights[k])
	var pick := _rng.randf() * total
	for k: String in weights:
		pick -= float(weights[k])
		if pick <= 0.0:
			return k
	return ""


func _loop(path: String) -> AudioStreamWAV:
	if not _live:
		return null
	var stream := load(path) as AudioStreamWAV
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_begin = 0
	stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


func _emitter(stream: AudioStreamWAV, at: Vector3, volume_db: float, unit_size: float,
		max_distance: float) -> AudioStreamPlayer3D:
	if stream == null:
		return null
	var p := AudioStreamPlayer3D.new()
	p.stream = stream
	p.position = at
	p.volume_db = volume_db
	p.unit_size = unit_size
	p.max_distance = max_distance
	p.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	p.bus = "Outdoor"
	add_child(p)
	p.play(_rng.randf() * stream.get_length())
	return p


func _one_shot(path: String, at: Vector3, volume_db: float, pitch: float) -> void:
	var node := AudioStreamPlayer3D.new()
	node.stream = load(path) as AudioStreamWAV
	node.position = at
	node.volume_db = volume_db
	node.pitch_scale = pitch
	node.bus = "Outdoor"
	node.unit_size = 18.0
	node.max_distance = 220.0
	node.attenuation_model = AudioStreamPlayer3D.ATTENUATION_INVERSE_DISTANCE
	node.autoplay = true
	node.finished.connect(node.queue_free)
	add_child(node)
