class_name BeachSite
extends Node3D
## The common ground of the cozy island's beach works (SaltWorks,
## ColourWorks): a frame laid on the shore at a bearing round the island,
## helpers to build in it, and the light-beam circuit (LumenPart,
## LumenBeam) a works runs on.
##
## The frame: u along the shore (counter-clockwise seen from above), v
## inland from the waterline, y absolute height. `at(u, v, y)` is a point
## in it; everything built goes under `_site`, which carries the frame.

var island: CozyIsland
var parts: Array[LumenPart] = []
var beams: Array[LumenBeam] = []

var _site := Node3D.new()
var _dir := Vector3.ZERO                # seaward
var _in := Vector3.ZERO                 # inland
var _along := Vector3.ZERO
var _origin := Vector3.ZERO             # where the bearing meets the waterline
var _wood: StandardMaterial3D           # posts, set by the works before its circuit
var _brass: StandardMaterial3D          # fittings


func _init(owner_island: CozyIsland, bearing: float) -> void:
	island = owner_island
	var a := deg_to_rad(bearing)
	_dir = Vector3(cos(a), 0.0, sin(a))
	_in = -_dir
	_along = Vector3(-_dir.z, 0.0, _dir.x)
	_origin = _dir * island.coast(a, 0.0)
	_site.basis = Basis(_along, Vector3.UP, _in)
	_site.position = Vector3(_origin.x, 0.0, _origin.z)


## The world point (on the ground plane) of (u, v) in the frame at
## `bearing`, for placing things before a works is built.
static func site_point(owner_island: CozyIsland, bearing: float, u: float, v: float) -> Vector3:
	var a := deg_to_rad(bearing)
	var d := Vector3(cos(a), 0.0, sin(a))
	var o := d * owner_island.coast(a, 0.0)
	return o + Vector3(-d.z, 0.0, d.x) * u - d * v


## A point of the site: u along the shore, v inland, y absolute.
func at(u: float, v: float, y: float) -> Vector3:
	return Vector3(u, y, v)


## Ground height at (u, v).
func ground(u: float, v: float) -> float:
	var p := _origin + _along * u + _in * v
	return island.height(p.x, p.z)


## ---- building helpers ------------------------------------------------------

func _box(size: Vector3, pos: Vector3, mat: Material, collide := false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = mat
	return _put(mesh, pos, collide, size, parent)


func _cyl(top: float, bottom: float, height: float, pos: Vector3, mat: Material,
		segments := 12, collide := false, parent: Node3D = null) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = segments
	mesh.rings = 1
	mesh.material = mat
	var view := _put(mesh, pos, false, Vector3.ZERO, parent)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := CylinderShape3D.new()
		shape.radius = maxf(top, bottom)
		shape.height = height
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		(parent if parent != null else _site).add_child(body)
	return view


func _ball(radius: float, pos: Vector3, mat: Material, parent: Node3D = null) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.material = mat
	return _put(mesh, pos, false, Vector3.ZERO, parent)


func _put(mesh: Mesh, pos: Vector3, collide: bool, size: Vector3, parent: Node3D) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = pos
	var into := parent if parent != null else _site
	into.add_child(view)
	if collide:
		var body := StaticBody3D.new()
		body.position = pos
		var shape := BoxShape3D.new()
		shape.size = size
		var c := CollisionShape3D.new()
		c.shape = shape
		body.add_child(c)
		into.add_child(body)
	return view


## A rod or timber of `radius` from a to b (site coordinates).
func _rod(a: Vector3, b: Vector3, radius: float, mat: Material, segments := 8, parent: Node3D = null) -> MeshInstance3D:
	var view := _cyl(radius, radius, a.distance_to(b), (a + b) * 0.5, mat, segments, false, parent)
	view.basis = _aligned(b - a)
	return view


## A basis whose y runs along `dir`.
static func _aligned(dir: Vector3) -> Basis:
	var y := dir.normalized()
	var x := y.cross(Vector3.FORWARD if absf(y.z) < 0.9 else Vector3.RIGHT).normalized()
	return Basis(x, y, x.cross(y))


## A sound, looped if asked; none when headless (nothing would hear it,
## and a loop left playing holds its file at exit).
func _sound(path: String, loop: bool) -> AudioStreamWAV:
	if DisplayServer.get_name() == "headless":
		return null
	var stream := load(path) as AudioStreamWAV
	if loop:
		stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
		stream.loop_begin = 0
		stream.loop_end = int(stream.get_length() * stream.mix_rate)
	return stream


## A 3D sound at `pos` in the site; a loop starts silent and playing.
func _speaker(path: String, loop: bool, pos: Vector3, unit_size := 5.0) -> AudioStreamPlayer3D:
	var p := AudioStreamPlayer3D.new()
	p.stream = _sound(path, loop)
	p.position = pos
	p.unit_size = unit_size
	if loop:
		p.volume_db = -80.0
		p.autoplay = p.stream != null
	_site.add_child(p)
	return p


## Plays a one-shot speaker, if there is sound.
static func _play(p: AudioStreamPlayer3D, pitch := 1.0) -> void:
	if p.stream != null:
		p.pitch_scale = pitch
		p.play()


## A loop's loudness, 0 to 1.
static func _level(p: AudioStreamPlayer3D, level: float, top_db := 0.0) -> void:
	p.volume_db = linear_to_db(clampf(level, 0.0001, 1.0)) + top_db


## ---- the circuit -----------------------------------------------------------

const NO_BASE := -1000.0


## A part at (u, v) at height y, its post down to the ground (or to
## `base`, a deck's height, when given).
func _part(kind: LumenPart.Kind, title: String, u: float, v: float, y: float, delay := 0.0, base := NO_BASE) -> LumenPart:
	var p := LumenPart.new(kind, title, at(u, v, y), ground(u, v) if base == NO_BASE else base, _wood, _brass, delay)
	_site.add_child(p)
	parts.append(p)
	return p


## A column of lanterns on one post at (u, v), from `y0` above the
## ground (or above `base`, a deck's height, when given) up by `dy`, each
## post standing on the lantern below.
func _lantern_column(u: float, v: float, titles: Array, y0: float, dy := 0.38, base := NO_BASE) -> Array[LumenPart]:
	var g := ground(u, v) if base == NO_BASE else base
	var out: Array[LumenPart] = []
	for i in titles.size():
		var y := g + y0 + dy * i
		var p := LumenPart.new(LumenPart.Kind.LANTERN, titles[i], at(u, v, y), (y - dy + 0.15) if i > 0 else g, _wood, _brass)
		_site.add_child(p)
		parts.append(p)
		out.append(p)
	return out


func _wire(from: LumenPart, to: LumenPart) -> void:
	var b := LumenBeam.new(from, to, from.colour())
	add_child(b)
	to.inputs.append(b)
	beams.append(b)


## Beams fixed between their parts and lanterns turned to their first
## beam, once every part stands in place.
func _place_beams() -> void:
	for b in beams:
		b.place()
	for b in beams:
		if b.source.kind == LumenPart.Kind.LANTERN:
			b.source.face(b.target.global_position)


## One step of the circuit: every part reads the beams as they stand,
## then every beam carries the new outputs on.
func _step_circuit(dt: float) -> void:
	for p in parts:
		p.evaluate(dt)
	for b in beams:
		b.step(dt)
