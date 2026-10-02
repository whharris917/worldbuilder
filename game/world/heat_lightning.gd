class_name HeatLightning
extends Node3D
## Heat lightning, an event the world starts: two or three thunderheads
## rise into view behind the hills about three kilometres off where the
## viewer is looking, and for half a minute lightning flickers inside
## them, too far for its thunder to carry: single flashes, doubles,
## a glow running across a cloud, sometimes two clouds at once. Then
## they fade. Each cloud is an upright card (cumulonimbus.gdshader)
## turned to the viewer, coloured by the clock and hazed by distance.

const DIST := 3000.0
const FADE_IN := 4.0
const FLICKER := 30.0
const FADE_OUT := 5.0

var _world: WorldBase
var _t := -1.0
var _clouds: Array[MeshInstance3D] = []
var _mats: Array[ShaderMaterial] = []
var _flashes: Array[Dictionary] = []     # {cloud, at, x, y, r, strength, run}
var _next := 0.0
var _rng := RandomNumberGenerator.new()


func setup(world: WorldBase) -> void:
	_world = world


func running() -> bool:
	return _t >= 0.0


## Raise the clouds where the viewer at `eye` faces `forward`.
func play(eye: Vector3, forward: Vector3) -> void:
	_clear()
	_rng.randomize()
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	var az := atan2(flat.z, flat.x)
	var count := 2 + _rng.randi() % 2
	var shader := load("res://world/cumulonimbus.gdshader") as Shader
	for k in count:
		var a := az + (float(k) - (count - 1) / 2.0) * 0.32 + _rng.randf_range(-0.08, 0.08)
		var d := DIST * _rng.randf_range(0.85, 1.15)
		# Their bases behind the hills (which hide everything under about
		# 400 m at this distance), their anvils some twenty degrees up.
		var height := _rng.randf_range(1000.0, 1350.0)
		var width := height * _rng.randf_range(1.0, 1.25)
		var at := eye + Vector3(cos(a), 0.0, sin(a)) * d
		at.y = 250.0 + height / 2.0
		var mat := ShaderMaterial.new()
		mat.shader = shader
		mat.set_shader_parameter("seed", _rng.randf_range(0.0, 50.0))
		mat.set_shader_parameter("lean", _rng.randf_range(-1.0, 1.0))
		mat.render_priority = -1
		var quad := QuadMesh.new()
		quad.size = Vector2(width, height)
		var cloud := MeshInstance3D.new()
		cloud.mesh = quad
		cloud.material_override = mat
		cloud.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(cloud)
		cloud.look_at_from_position(at, Vector3(eye.x, at.y, eye.z), Vector3.UP)
		cloud.rotate_object_local(Vector3.UP, PI)
		_clouds.append(cloud)
		_mats.append(mat)
	_flashes.clear()
	_next = FADE_IN * 0.6
	_t = 0.0
	_light_clouds()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > FADE_IN + FLICKER + FADE_OUT:
		_clear()
		return
	var opacity := smoothstep(0.0, FADE_IN, _t) * (1.0 - smoothstep(FADE_IN + FLICKER, FADE_IN + FLICKER + FADE_OUT, _t))
	# A new flash now and then while the storm is at its height.
	if _t < FADE_IN + FLICKER:
		_next -= delta
		if _next <= 0.0:
			_spark()
			_next = _rng.randf_range(0.25, 2.6)
	var cells: Array = []
	for _m in _mats:
		cells.append([])
	var k := 0
	while k < _flashes.size():
		var f: Dictionary = _flashes[k]
		var age := _t - float(f["at"])
		if age > 0.9:
			_flashes.remove_at(k)
			continue
		k += 1
		if age < 0.0:
			continue
		# A flicker: a sharp rise, a quick fall with a stutter in it; a
		# running flash drifts across the cloud as it burns.
		var s := float(f["strength"]) * exp(-age / 0.09) * (0.75 + 0.25 * sin(age * 90.0))
		var x := float(f["x"]) + float(f["run"]) * age
		(cells[int(f["cloud"])] as Array).append(Vector4(x, float(f["y"]), float(f["r"]), s))
	for i in _mats.size():
		var list: Array = cells[i]
		list.sort_custom(func(a: Vector4, b: Vector4) -> bool: return a.w > b.w)
		var four := PackedVector4Array()
		for j in 4:
			four.append(list[j] if j < list.size() else Vector4.ZERO)
		_mats[i].set_shader_parameter("flashes", four)
		_mats[i].set_shader_parameter("opacity", opacity)
	_light_clouds()


## One flash, or a burst of them: in one cloud, low in the tower or up
## in the anvil, sometimes running sideways, sometimes answered in
## another cloud.
func _spark() -> void:
	var cloud := _rng.randi() % _clouds.size()
	var pulses := 1 + _rng.randi() % 3
	var start := _t
	var run := _rng.randf_range(-0.8, 0.8) if _rng.randf() < 0.3 else 0.0
	var x := _rng.randf_range(-0.3, 0.3)
	var y := _rng.randf_range(0.2, 0.85)
	for _p in pulses:
		_flashes.append({"cloud": cloud, "at": start, "x": x, "y": y, "r": _rng.randf_range(0.18, 0.4),
			"strength": _rng.randf_range(0.5, 1.0), "run": run})
		start += _rng.randf_range(0.06, 0.2)
	if _clouds.size() > 1 and _rng.randf() < 0.25:
		_flashes.append({"cloud": (cloud + 1) % _clouds.size(), "at": start + 0.1, "x": _rng.randf_range(-0.3, 0.3),
			"y": _rng.randf_range(0.3, 0.8), "r": 0.3, "strength": 0.6, "run": 0.0})


## The clouds' daylight from the clock: white tops and slate shade by
## day, warm at dusk, almost unseen at night but for the flashes.
func _light_clouds() -> void:
	var env := _world.sky_env
	if env == null:
		return
	var horizon := env.fog_light_color
	var amb := env.ambient_light_color * env.ambient_light_energy
	var sun := Color.BLACK
	if _world.sun != null and _world.sun.visible:
		sun = _world.sun.light_color * clampf(_world.sun.light_energy / 1.8, 0.0, 1.0)
	var lit := (amb * 0.5 + sun * 0.75).clamp(Color(0.02, 0.02, 0.03), Color(1, 1, 1))
	for mat in _mats:
		mat.set_shader_parameter("day_color", lit)
		mat.set_shader_parameter("shade_color", lit * 0.5)
		mat.set_shader_parameter("haze_color", horizon)


func _clear() -> void:
	for c in _clouds:
		c.queue_free()
	_clouds.clear()
	_mats.clear()
	_flashes.clear()
	_t = -1.0
