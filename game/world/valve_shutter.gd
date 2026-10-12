class_name ValveShutter
extends SandShutter
## The sand shutter (SandShutter) with a straight glass, a cylinder from
## end to end, divided at its waist by a ring of PETALS hinged brass
## triangles in place of a neck: a check valve for sand.
##
## Each petal is a tapering plate hung from a hinge along a chord of the
## wall at the waist (the eight hinges an octagon), swinging by its own
## weight toward whichever end is lower; shut, the eight are the faces of
## a regular eight-sided funnel, their edges meeting along its ridges, so
## the only way through is the eight-sided hole at its point. With B (the
## bulb holding the beam's point, P) below, the petals hang flat against
## the wall on B's side and the glass is open its whole width: sand from A
## above falls straight through, all of it in BYPASS_RUN seconds. With B
## above, they swing down through the waist into A until they rest on
## their stops at FUNNEL from the wall, their tips meeting round a small
## hole on the axis: a funnel, and the sand runs through the hole at the
## glass's rate, as through an hourglass's neck. So the light, turning the
## glass over, sets the funnel and the delay runs as in the sand shutter;
## the light leaving, the glass turns back, the petals fall open and the
## sand drops back into B at once. A petal falls as soon as the glass
## passes level, the sand only once it is tipped past its angle of repose
## (REPOSE), so the funnel is shut before the sand comes down on it. T fits a ring with a smaller or
## larger hole, its petals longer or shorter to meet round it.

const PETALS := 8
const FUNNEL := 2.356                   # rad: the petals' swing from the wall, 135 degrees: 45 to the axis toward A
const SWING := 20.0                     # rad/s: a petal falling to its other side, light and quick
const LEAK := 0.09                      # the share of the sand that slips through before the petals shut, in a lantern's beam
const REPOSE := 0.57                    # the sine of sand's angle of repose, 35 degrees: tipped less, it does not slide
const WALL_R := 0.028                   # m: the glass's inside radius

var _petals: Array[Node3D] = []
var _plates: Array[MeshInstance3D] = []
var _petal_turn := 0.0                  # rad: 0 against the wall on B's side, FUNNEL shut
var _hole := 0.004                      # m: the hole's radius


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	super(at, brass, leaf_metal, glass, wait)
	name = "ValveShutter"


## The delay, seconds: the glass's run sized for it, allowing for the
## sand that slips through while the petals fall (LEAK; brighter light
## turns the glass faster and lets a little more through).
func set_delay(seconds: float) -> void:
	super(seconds)
	_run = delay / (1.0 - DROP / FULL - LEAK)
	_hole = 0.004 * pow(_run / 10.0, -0.4)
	var plate := _plate()
	for view in _plates:
		view.mesh = plate


## One petal: in its hinge's frame (x along the hinge, z outward), a plate
## hanging toward -y, as wide as the octagon's side at the hinge and
## narrowing so that, swung to FUNNEL, its edges run to the funnel's axis
## and it ends at the hole's octagon.
func _plate() -> ArrayMesh:
	var half := tan(PI / PETALS)
	var at_hinge := WALL_R * cos(PI / PETALS)          # the hinge's distance from the axis
	var slant := (at_hinge - _hole) / sin(PI - FUNNEL)
	var points := PackedVector3Array([Vector3(-at_hinge * half, 0, 0), Vector3(at_hinge * half, 0, 0),
			Vector3(_hole * half, -slant, 0), Vector3(-_hole * half, -slant, 0)])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([points[0], points[1], points[2], points[0], points[2], points[3]])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## The straight glass, its caps and frame, the ring of petals, the sand.
func _build_glass(brass: Material) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = WALL_R + 0.002
	tube.bottom_radius = WALL_R + 0.002
	tube.height = FULL + DROP + LENGTH
	tube.radial_segments = 20
	tube.cap_top = false
	tube.cap_bottom = false
	tube.material = _glass_mat
	var tube_view := MeshInstance3D.new()
	tube_view.mesh = tube
	tube_view.position = Vector3(0, (DROP + LENGTH - FULL) * 0.5, 0)
	tube_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass.add_child(tube_view)
	for y: float in [-FULL, DROP + LENGTH]:
		var cap := CylinderMesh.new()
		cap.top_radius = WALL_R + 0.005
		cap.bottom_radius = WALL_R + 0.005
		cap.height = 0.006
		cap.material = brass
		var cap_view := MeshInstance3D.new()
		cap_view.mesh = cap
		cap_view.position = Vector3(0, y, 0)
		_glass.add_child(cap_view)
	for x: float in [-FRAME_X, FRAME_X]:
		_bar(_glass, Vector3(x, -FULL, 0), Vector3(x, DROP + LENGTH, 0), 0.003, brass)
		_bar(_glass, Vector3(x, -FULL, 0), Vector3(0, -FULL, 0), 0.003, brass)
		_bar(_glass, Vector3(x, DROP + LENGTH, 0), Vector3(0, DROP + LENGTH, 0), 0.003, brass)
	# The hinge ring round the waist.
	var ring := TorusMesh.new()
	ring.inner_radius = WALL_R - 0.002
	ring.outer_radius = WALL_R + 0.004
	ring.rings = 20
	ring.ring_segments = 6
	ring.material = brass
	var ring_view := MeshInstance3D.new()
	ring_view.mesh = ring
	ring_view.position = Vector3(0, DROP, 0)
	_glass.add_child(ring_view)
	# The petals: each on its hinge along a chord of the wall, its frame x
	# along the hinge, y along the glass toward A, z outward; it hangs
	# toward B (-y) at a turn of 0 and swings inward about x.
	var plate := _plate()
	var petal_mat: BaseMaterial3D = StandardMaterial3D.new()
	if brass is BaseMaterial3D:
		petal_mat = (brass as BaseMaterial3D).duplicate() as BaseMaterial3D
	petal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in PETALS:
		var a := TAU * (k + 0.5) / PETALS
		var out := Vector3(cos(a), 0, sin(a))
		var hinge := Node3D.new()
		hinge.position = out * WALL_R * cos(PI / PETALS) + Vector3(0, DROP, 0)
		hinge.basis = Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)
		_glass.add_child(hinge)
		var swing := Node3D.new()
		hinge.add_child(swing)
		var view := MeshInstance3D.new()
		view.mesh = plate
		view.material_override = petal_mat
		swing.add_child(view)
		_plates.append(view)
		_petals.append(hinge)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.86, 0.74, 0.5)
	sand_mat.roughness = 0.95
	for k in 2:
		var pile := CylinderMesh.new()
		pile.top_radius = WALL_R - 0.003
		pile.bottom_radius = WALL_R - 0.003
		pile.height = 1.0
		pile.radial_segments = 14
		pile.material = sand_mat
		var pile_view := MeshInstance3D.new()
		pile_view.mesh = pile
		_glass.add_child(pile_view)
		if k == 0:
			_pile_a = pile_view
		else:
			_pile_b = pile_view
	_stream = _bar(_glass, Vector3(0, -0.5, 0), Vector3(0, 0.5, 0), 0.0015, sand_mat)


## The sand over one step, and the petals: they swing toward whichever end
## is lower; sand from the upper end runs through the funnel's hole while
## they are shut, falls freely while they are open, between as they swing.
func _run_sand(h: float) -> void:
	var c := cos(_flip())
	var target := FUNNEL if c < 0.0 else 0.0
	if absf(c) > 0.05:
		_petal_turn = move_toward(_petal_turn, target, SWING * h)
	var into_b := signf(c) * clampf((absf(c) - REPOSE) * 5.0, 0.0, 1.0)
	var shut := clampf((_petal_turn - (FUNNEL - 0.35)) / 0.35, 0.0, 1.0)
	var rate := lerpf(1.0 / BYPASS_RUN, 1.0 / _run, shut)
	_sand = clampf(_sand + into_b * h * rate, 0.0, 1.0)


func _place() -> void:
	super()
	if _petals.is_empty():
		return
	for p in _petals:
		(p.get_child(0) as Node3D).rotation.x = _petal_turn
	# The stream through the waist: a thread through the hole, the glass's
	# width while the petals are open.
	var shut := clampf((_petal_turn - (FUNNEL - 0.35)) / 0.35, 0.0, 1.0)
	_stream.scale = Vector3(lerpf(12.0, 1.0, shut), _stream.scale.y, lerpf(12.0, 1.0, shut))
