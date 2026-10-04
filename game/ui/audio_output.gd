extends Node
## The game's sound as it leaves for the listener, the same in every
## world (an autoload, AudioOutput), set for what it is played on and
## kept in user://audio_output.json:
##
## Speakers: a gentle compressor (from -20 dB at 3:1, 5 ms attack, 200 ms
## release, 6 dB of make-up gain) and a limiter at -1 dB on the master
## bus, so small speakers have the level they need without clipping. It
## evens loudness far less than a laptop's own loudness equalisation, so
## distance and muffling still tell.
## Headphones: no compressor, the full range of loudness, and the stereo
## image narrowed to 70%, so a sound panned hard reaches both ears a
## little, as from speakers in front; a crude stand-in for crossfeed,
## which Godot has no effect for. A limiter at -1 dB as well.
## Master volume: the master bus's level, -24 to +12 dB.

const PATH := "user://audio_output.json"

var mode := "Speakers"
var master_db := 0.0

var _added: Array[AudioEffect] = []


func _ready() -> void:
	if FileAccess.file_exists(PATH):
		var file := FileAccess.open(PATH, FileAccess.READ)
		if file != null:
			var parsed: Variant = JSON.parse_string(file.get_as_text())
			if parsed is Dictionary:
				mode = str((parsed as Dictionary).get("mode", mode))
				master_db = float((parsed as Dictionary).get("master_db", master_db))
	_apply()


func set_mode(value: String) -> void:
	mode = value
	_apply()
	_save()


func set_master_db(value: float) -> void:
	master_db = value
	_apply()
	_save()


func _apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	# Take out what was put in before, last first, so indices hold.
	for i in range(AudioServer.get_bus_effect_count(bus) - 1, -1, -1):
		if _added.has(AudioServer.get_bus_effect(bus, i)):
			AudioServer.remove_bus_effect(bus, i)
	_added.clear()
	if mode == "Speakers":
		var squeeze := AudioEffectCompressor.new()
		squeeze.threshold = -20.0
		squeeze.ratio = 3.0
		squeeze.attack_us = 5000.0
		squeeze.release_ms = 200.0
		squeeze.gain = 6.0
		_added.append(squeeze)
	else:
		var narrow := AudioEffectStereoEnhance.new()
		narrow.pan_pullout = 0.7
		_added.append(narrow)
	var limit := AudioEffectHardLimiter.new()
	limit.ceiling_db = -1.0
	_added.append(limit)
	for effect in _added:
		AudioServer.add_bus_effect(bus, effect)
	AudioServer.set_bus_volume_db(bus, master_db)


func _save() -> void:
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify({"mode": mode, "master_db": master_db}))
