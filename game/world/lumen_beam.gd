class_name LumenBeam
extends Node3D
## A beam of light carrying one signal from a lumen part's output to
## another part's input, in a straight line. Light here travels slowly
## (SPEED), so a signal is seen to run along it: when the source lights,
## a lit stretch grows from it toward the target; when the source goes
## dark, the stretch's back leaves the source and runs after its front.
## A short flash is a short stretch travelling the whole way. The target
## reads the beam as lit while a stretch covers its end (`delivered`).
##
## Drawn as glowing tubes (an engine cylinder, emissive, one per lit
## stretch); nothing else lights or blocks it.

const SPEED := 12.0                    # metres a second
const RADIUS := 0.018
const MAX_STRETCHES := 6

var source: LumenPart
var target: LumenPart
var delivered := false

var _a := Vector3.ZERO
var _b := Vector3.ZERO
var _length := 1.0
var _stretches: Array = []              # [front, back, attached] in metres from the source
var _tubes: Array[MeshInstance3D] = []


func _init(from: LumenPart, to: LumenPart, colour: Color) -> void:
	name = "Beam"
	source = from
	target = to
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = colour
	mat.emission_enabled = true
	mat.emission = colour
	mat.emission_energy_multiplier = 3.0
	mat.disable_receive_shadows = true
	var tube := CylinderMesh.new()
	tube.top_radius = 1.0
	tube.bottom_radius = 1.0
	tube.height = 1.0
	tube.radial_segments = 6
	tube.rings = 1
	tube.material = mat
	for i in MAX_STRETCHES:
		var mi := MeshInstance3D.new()
		mi.mesh = tube
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = false
		add_child(mi)
		_tubes.append(mi)


## Ends fixed once both parts stand in place.
func place() -> void:
	_a = source.out_point()
	_b = target.in_point()
	_length = maxf(_a.distance_to(_b), 0.01)


## One step of the light: a new stretch when the source lights, the
## back let go when it goes dark, every stretch moved on.
func step(dt: float) -> void:
	var lit := source.out
	var last: Array = _stretches.back() if not _stretches.is_empty() else []
	if lit and (last.is_empty() or not bool(last[2])):
		if _stretches.size() < MAX_STRETCHES:
			_stretches.append([0.0, 0.0, true])
	elif not lit and not last.is_empty() and bool(last[2]):
		last[2] = false
	var move := SPEED * dt
	delivered = false
	for s: Array in _stretches:
		s[0] = minf(float(s[0]) + move, _length)
		if not bool(s[2]):
			s[1] = minf(float(s[1]) + move, _length)
		if float(s[0]) >= _length and float(s[1]) < _length:
			delivered = true
	_stretches = _stretches.filter(func(s: Array) -> bool: return float(s[1]) < _length)
	_draw()


func _draw() -> void:
	var along := (_b - _a) / _length
	var side := along.cross(Vector3.UP if absf(along.y) < 0.95 else Vector3.RIGHT).normalized()
	var up := side.cross(along)
	for i in _tubes.size():
		var tube := _tubes[i]
		if i >= _stretches.size():
			tube.visible = false
			continue
		var s: Array = _stretches[i]
		var front := float(s[0])
		var back := float(s[1])
		var span := front - back
		tube.visible = span > 0.01
		if tube.visible:
			var mid := _a + along * (back + front) * 0.5
			tube.transform = Transform3D(Basis(side * RADIUS, along * span, up * RADIUS), mid)
