class_name Orbs
extends Node3D
## The lights over the trees: an event the world starts. Three warm
## lights rise slowly over the wood far off where the viewer is
## looking, small with the distance; after a few seconds they cross to
## hover over the meadow in front of the viewer in about half a
## second, then each parts into three; the nine drift a while and then,
## one after another, accelerate straight up and away at a speed nothing
## could fly. Each carries a light, so the trees and the grass under
## them are lit as they pass. Positions are worked out from the time
## since the start, so the event plays the same at any frame rate.

const RISE := 6.0          # seconds rising over the trees
const ZOOM_AT := 7.5       # when they cross to the meadow
const ZOOM_LEN := 0.55
const SPLIT_AT := 11.0     # when each parts into three
const SPLIT_LEN := 1.6
const LEAVE_AT := 18.5     # when the first leaves
const LEAVE_GAP := 0.22    # between one leaving and the next
const GONE := 1.8          # seconds a light takes to vanish once it goes
const FAR := 260.0         # how far off they rise
const HOVER_D := 30.0      # how far in front of the viewer they hover
const HOVER_H := 18.0      # and how high over the ground

var _t := -1.0
var _orbs: Array[MeshInstance3D] = []
var _lights: Array[OmniLight3D] = []
var _rise_at: Array[Vector3] = []     # each group's start, over the far trees
var _hover_at: Array[Vector3] = []    # each group's place over the meadow
var _leave_dir: Array[Vector3] = []
var _leave_order: Array[int] = []
var _mat: ShaderMaterial
var _rng := RandomNumberGenerator.new()


func running() -> bool:
	return _t >= 0.0


## Start the event as seen from `eye` looking along `forward`, on the
## ground the height function gives.
func play(eye: Vector3, forward: Vector3, height: Callable) -> void:
	_clear()
	_rng.randomize()
	var flat := Vector3(forward.x, 0.0, forward.z)
	if flat.length() < 0.01:
		flat = Vector3.FORWARD
	flat = flat.normalized()
	var right := flat.cross(Vector3.UP)
	var far := eye + flat * FAR
	var near := eye + flat * HOVER_D
	for g in 3:
		var side := float(g - 1)
		var f := far + right * side * 9.0
		f.y = float(height.call(f.x, f.z)) + 6.0 + _rng.randf_range(-1.0, 1.0)
		_rise_at.append(f)
		var h := near + right * side * 7.0 + flat * _rng.randf_range(-2.0, 2.0)
		h.y = float(height.call(h.x, h.z)) + HOVER_H + side * side * -1.5 + _rng.randf_range(-1.0, 1.0)
		_hover_at.append(h)
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://world/orb.gdshader")
	var quad := QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)
	for k in 9:
		var orb := MeshInstance3D.new()
		orb.mesh = quad
		orb.material_override = _mat
		orb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		orb.extra_cull_margin = 64.0
		orb.set_instance_shader_parameter("glow", 0.0)
		add_child(orb)
		_orbs.append(orb)
		var light := OmniLight3D.new()
		light.light_color = Color(1.0, 0.75, 0.45)
		light.omni_range = 45.0
		light.light_energy = 0.0
		light.shadow_enabled = false
		orb.add_child(light)
		_lights.append(light)
		var a := _rng.randf_range(0.0, TAU)
		_leave_dir.append(Vector3(cos(a) * 0.25, 1.0, sin(a) * 0.25).normalized())
		_leave_order.append(k)
	# They go in no set order.
	for k in range(8, 0, -1):
		var j := _rng.randi() % (k + 1)
		var tmp := _leave_order[k]
		_leave_order[k] = _leave_order[j]
		_leave_order[j] = tmp
	_t = 0.0
	_place()


func _process(delta: float) -> void:
	if _t < 0.0:
		return
	_t += delta
	if _t > LEAVE_AT + 8.0 * LEAVE_GAP + GONE:
		_clear()
		return
	_place()


func _place() -> void:
	for k in 9:
		var g := k / 3
		var j := k % 3
		var group := _group_at(g)
		var at := group
		var glow := smoothstep(0.0, 1.5, _t)
		var energy := 5.0
		if _t < SPLIT_AT:
			# Before the parting only the first of each three shows.
			if j != 0:
				glow = 0.0
		else:
			var s := smoothstep(SPLIT_AT, SPLIT_AT + SPLIT_LEN, _t)
			var spin := float(j) * TAU / 3.0 + float(g) * 0.7 + (_t - SPLIT_AT) * 0.25
			var tilt := Vector3(cos(spin), 0.35 * sin(spin * 1.3 + float(g)), sin(spin))
			at += tilt * 4.5 * s
			energy = lerpf(5.0, 2.4, s)
		# Leaving: from standing still to kilometres a second in a breath.
		var order := _leave_order.find(k)
		var u := _t - (LEAVE_AT + order * LEAVE_GAP)
		if u > 0.0:
			at += _leave_dir[k] * (2.0 * u + 900.0 * u * u * u)
			glow *= 1.0 - smoothstep(GONE * 0.6, GONE, u)
			energy *= 1.0 - smoothstep(0.0, 0.4, u)
		# A slow pulse, each its own.
		glow *= 0.85 + 0.15 * sin(_t * 2.3 + float(k) * 1.9)
		_orbs[k].position = at
		_orbs[k].set_instance_shader_parameter("glow", glow)
		_lights[k].light_energy = energy * glow


## Where group g is now: rising, crossing, or hovering with a drift.
func _group_at(g: int) -> Vector3:
	var bob := Vector3(sin(_t * 0.7 + g * 2.1), sin(_t * 0.9 + g * 1.3) * 0.6, cos(_t * 0.5 + g)) * 0.8
	var rise := _rise_at[g] + Vector3(0.0, 34.0 * smoothstep(0.0, RISE, _t - g * 0.4), 0.0)
	if _t < ZOOM_AT:
		return rise + bob * 2.0
	var u := clampf((_t - ZOOM_AT) / ZOOM_LEN, 0.0, 1.0)
	var s := 0.5 - 0.5 * cos(PI * u)
	var risen := _rise_at[g] + Vector3(0.0, 34.0, 0.0) + bob * 2.0
	return risen.lerp(_hover_at[g] + bob, s)


func _clear() -> void:
	for orb in _orbs:
		orb.queue_free()
	_orbs.clear()
	_lights.clear()
	_rise_at.clear()
	_hover_at.clear()
	_leave_dir.clear()
	_leave_order.clear()
	_t = -1.0
