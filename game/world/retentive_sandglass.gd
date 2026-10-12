class_name RetentiveSandglass
extends ValveShutter
## A sandglass in the ring that keeps its time: the flap sandglass
## (ValveShutter) whose flaps, coming back from the funnel, are caught flat
## on stoppers, so the sand that has run is held where it is through the
## dark; a reset stone draws the stoppers out and the flaps drop open.
##
## The glass: a straight tube, bulb B (holding the beam's point, P, at its
## middle) and bulb A, each BULB_LEN long, the waist between them; the sand,
## SAND of a bulb's length, all in B to begin. P at B's middle and B more
## than half full mean the same amount of sand in B covers P whichever way
## the glass lies (from either end, or lying level, more than half a bulb
## covers its middle): the beam is stopped while B holds THRESH of the sand
## or more, and passes once less, in any position. So the light's count
## is the sand run out of B, kept through the dark.
##
## The flaps: eight brass triangles hinged on the chords of an octagon at
## the waist, reaching to the axis, a little wider than their share of the
## ring so neighbours overlap like an iris's leaves; each swings by its own
## weight toward whichever end is lower. Lit, the geotrope turns the glass
## over (B up) and the flaps fall toward A onto their funnel stops,
## leaving a small hole at the point between their tips (the stop's angle
## sets the hole: T); sand runs from B through it. Dark, the glass turns
## back (B down) and the flaps swing toward B until they lie flat on eight
## stoppers just under the waist on B's side: a closed floor, A's sand
## resting on it. The stoppers are latches that fold away from a flap
## swinging up past them from below and spring back, so a flap can always
## rise past them and is caught coming down. The count goes on from where
## it was at the next light.
##
## The reset (ResetSnuffer): the reset stone's can shuts out the timing
## stone's light, so the glass turns back; a rod from the can slides a
## collar along the glass's axle that draws the stoppers out into the wall
## (STOPS_OUT of the can's travel); the flaps drop open and A's sand falls
## back into B in BYPASS_RUN seconds, covering P. The can keeps the timing
## stone dark while the reset stone stays lit.

const BULB_LEN := 0.07                      # m: each bulb, waist to end
const WAIST := BULB_LEN * 0.5               # m: the waist above P, which is B's middle
const SAND := 0.85                      # the sand, as a share of a bulb's length
const THRESH := 0.5 / SAND              # the share of the sand in B that covers P
const FLAT := PI * 0.5                  # the flaps' turn lying flat across the waist
const STOPS_OUT := 0.85                 # the can's travel that draws the stoppers out
const OVERLAP := 1.35                   # each flap's width over its share of the ring

var _stops: Array[Node3D] = []
var _collar: MeshInstance3D
var _stop_rod: MeshInstance3D
var _snuffer: ResetSnuffer
var _funnel := 2.1                      # rad: the flaps' funnel stop, set by T


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	_petal_turn = FLAT
	super(at, brass, leaf_metal, glass, wait)
	name = "RetentiveSandglass"


## The delay, seconds: the glass's run, and the funnel stop's angle that
## leaves a hole between the flaps' tips to run it.
func set_delay(seconds: float) -> void:
	delay = clampf(seconds, 0.5, LONGEST)
	_rest = REST_S
	_run = delay / (1.0 - THRESH)
	_hole = 0.004 * pow(_run / 10.0, -0.4)
	var reach := WALL_R * cos(PI / PETALS)
	_funnel = PI - asin(clampf(1.0 - _hole / reach, 0.0, 1.0))


func _build_mechanism(brass: Material, stone_view: MeshInstance3D) -> void:
	_build_drive(brass, stone_view)
	_build_glass(brass)
	_bracket(brass, ResetSnuffer.POST_AT, STONE_UP + 0.01)
	_snuffer = ResetSnuffer.new(self, brass)
	_head.add_child(_snuffer)
	# The collar on the glass's axle that draws the stoppers out, and the
	# rod down to it from the can.
	var collar := CylinderMesh.new()
	collar.top_radius = 0.009
	collar.bottom_radius = 0.009
	collar.height = 0.012
	collar.material = brass
	_collar = MeshInstance3D.new()
	_collar.mesh = collar
	_collar.rotation.z = PI * 0.5
	_head.add_child(_collar)
	_stop_rod = _bar(_head, Vector3.ZERO, Vector3.UP, 0.003, brass)


## The straight glass, caps and frame, the ring of overlapping flaps on
## their hinges, the stoppers under them, the sand.
func _build_glass(brass: Material) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = WALL_R + 0.002
	tube.bottom_radius = WALL_R + 0.002
	tube.height = BULB_LEN * 2.0
	tube.radial_segments = 20
	tube.cap_top = false
	tube.cap_bottom = false
	tube.material = _glass_mat
	var tube_view := MeshInstance3D.new()
	tube_view.mesh = tube
	tube_view.position = Vector3(0, WAIST, 0)
	tube_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass.add_child(tube_view)
	for y: float in [-WAIST, WAIST + BULB_LEN]:
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
		_bar(_glass, Vector3(x, -WAIST, 0), Vector3(x, WAIST + BULB_LEN, 0), 0.003, brass)
		_bar(_glass, Vector3(x, -WAIST, 0), Vector3(0, -WAIST, 0), 0.003, brass)
		_bar(_glass, Vector3(x, WAIST + BULB_LEN, 0), Vector3(0, WAIST + BULB_LEN, 0), 0.003, brass)
	var ring := TorusMesh.new()
	ring.inner_radius = WALL_R - 0.002
	ring.outer_radius = WALL_R + 0.004
	ring.rings = 20
	ring.ring_segments = 6
	ring.material = brass
	var ring_view := MeshInstance3D.new()
	ring_view.mesh = ring
	ring_view.position = Vector3(0, WAIST, 0)
	_glass.add_child(ring_view)
	# The flaps: triangles from the octagon's side to the axis, widened to
	# overlap; every other one a hair nearer B so the overlaps lie one on
	# another.
	var reach := WALL_R * cos(PI / PETALS)
	var half := reach * tan(PI / PETALS) * OVERLAP
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = PackedVector3Array([Vector3(-half, 0, 0), Vector3(half, 0, 0), Vector3(0, -reach, 0)])
	arrays[Mesh.ARRAY_NORMAL] = PackedVector3Array([Vector3.BACK, Vector3.BACK, Vector3.BACK])
	var plate := ArrayMesh.new()
	plate.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var petal_mat: BaseMaterial3D = StandardMaterial3D.new()
	if brass is BaseMaterial3D:
		petal_mat = (brass as BaseMaterial3D).duplicate() as BaseMaterial3D
	petal_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for k in PETALS:
		var a := TAU * (k + 0.5) / PETALS
		var out := Vector3(cos(a), 0, sin(a))
		var hinge := Node3D.new()
		hinge.position = out * reach + Vector3(0, WAIST - (0.0012 if k % 2 == 1 else 0.0), 0)
		hinge.basis = Basis(Vector3.UP.cross(out).normalized(), Vector3.UP, out)
		_glass.add_child(hinge)
		var swing := Node3D.new()
		hinge.add_child(swing)
		var view := MeshInstance3D.new()
		view.mesh = plate
		view.material_override = petal_mat
		swing.add_child(view)
		_petals.append(hinge)
		# Its stopper: a pin out of the wall just under the waist on B's
		# side, under the flap's middle.
		var stop := Node3D.new()
		stop.position = Vector3(0, WAIST - 0.004, 0)
		stop.basis = Basis(Vector3.UP, -a + PI * 0.5)
		_glass.add_child(stop)
		_bar(stop, Vector3(0, 0, WALL_R + 0.002), Vector3(0, 0, WALL_R - 0.008), 0.0018, brass)
		_stops.append(stop)
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


func set_layer(layer: int) -> void:
	super(layer)
	if _snuffer != null:
		_snuffer.sensor.collision_layer = layer


func sense_reset(watts: float) -> void:
	_snuffer.watts = watts


func reset_point() -> Vector3:
	return _snuffer.point()


func _physics_process(delta: float) -> void:
	_step = delta
	var frame := _head.global_basis
	var h := delta / STEPS
	for k in STEPS:
		_snuffer.step(frame, h)
		var seeking := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
		var lift := Photogyrite.pull(_watts * (1.0 - _snuffer.shade()), 0.0) * seeking.cross(Vector3.UP).dot(frame.x.normalized())
		var twist := lift - (PRELOAD + SPRING * (_turn - REST_S))
		_rate += (twist - PIVOT * _rate) / GLASS_INERTIA * h
		_turn += _rate * h
		if _turn < REST_S:
			_turn = REST_S
			_rate = -_rate * BOUNCE if _rate < 0.0 else _rate
		elif _turn > TOP_S:
			_turn = TOP_S
			_rate = -_rate * BOUNCE if _rate > 0.0 else _rate
		_run_sand(h)
	open = not _covered()
	_place()


## The flaps and the sand over one step. The flaps swing toward the lower
## end: toward A onto the funnel stop with B up; toward B with B down,
## caught flat on the stoppers unless they are drawn out (a flap already
## below them stays below until it swings up past them). Sand runs from
## the upper end once the glass is tipped past its angle of repose: shut
## flat, none; between flat and the funnel, through the opening hole;
## open, freely.
func _run_sand(h: float) -> void:
	var c := cos(_flip())
	var caught := _snuffer.travel() < STOPS_OUT
	var target := _funnel if c < 0.0 else 0.0
	if absf(c) > 0.05:
		var moved := move_toward(_petal_turn, target, SWING * h)
		if caught and _petal_turn >= FLAT and moved < FLAT:
			moved = FLAT
		_petal_turn = moved
	var into_b := signf(c) * clampf((absf(c) - REPOSE) * 5.0, 0.0, 1.0)
	var rate := 0.0
	if _petal_turn < FLAT - 0.01:
		rate = (FLAT - _petal_turn) / FLAT / BYPASS_RUN
	else:
		rate = clampf((_petal_turn - FLAT) / maxf(_funnel - FLAT, 0.01), 0.0, 1.0) / _run
	_sand = clampf(_sand + into_b * h * rate, 0.0, 1.0)


## Whether B's sand covers P: in any position, while B holds THRESH of it.
func _covered() -> bool:
	return _sand >= THRESH


func _place() -> void:
	_stone.rotation.x = _turn
	_glass.rotation.x = _flip()
	if _pile_a == null:
		return
	var b_low := cos(_flip()) > 0.0
	# Each bulb's sand from its lower end: B's far end or the waist; A's
	# far end or the waist.
	var b_len := _sand * SAND * BULB_LEN
	_pile_b.visible = b_len > 0.001
	var b_from := -WAIST if b_low else WAIST
	var b_dir := 1.0 if b_low else -1.0
	_pile_b.scale = Vector3(1, maxf(b_len, 0.001), 1)
	_pile_b.position = Vector3(0, b_from + b_dir * b_len * 0.5, 0)
	var a_len := (1.0 - _sand) * SAND * BULB_LEN
	_pile_a.visible = a_len > 0.001
	var a_from := WAIST if b_low else WAIST + BULB_LEN
	var a_dir := 1.0 if b_low else -1.0
	_pile_a.scale = Vector3(1, maxf(a_len, 0.001), 1)
	_pile_a.position = Vector3(0, a_from + a_dir * a_len * 0.5, 0)
	# The stream through the waist while sand runs.
	var moving := absf(cos(_flip())) > REPOSE and ((not b_low and _sand > 0.0) or (b_low and _sand < 1.0)) \
			and absf(_petal_turn - FLAT) > 0.02
	_stream.visible = moving
	if moving:
		var bottom := (b_from + b_dir * b_len) if b_low else (a_from + a_dir * a_len)
		_set_bar(_stream, Vector3(0, WAIST, 0), Vector3(0, bottom, 0))
		var wide := 12.0 if _petal_turn < FLAT else 1.0
		_stream.scale = Vector3(wide, _stream.scale.y, wide)
	for p in _petals:
		(p.get_child(0) as Node3D).rotation.x = _petal_turn
	# The stoppers drawn out into the wall with the collar.
	var out := clampf((_snuffer.travel() - (STOPS_OUT - 0.2)) / 0.2, 0.0, 1.0)
	for s in _stops:
		(s.get_child(0) as Node3D).position.z = WALL_R - 0.003 + out * 0.009
	_snuffer.place()
	var collar_x := 0.062 - 0.016 * out
	_collar.position = Vector3(collar_x, 0, 0)
	var can_low := Vector3(lerpf(ResetSnuffer.CAN_PARKED, ResetSnuffer.CAN_OVER, _snuffer.travel()) + 0.03,
			STONE_UP - ResetSnuffer.CAN_R, 0)
	_set_bar(_stop_rod, can_low, Vector3(collar_x + 0.006, 0.008, 0))
	_stone_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(_watts / 60.0, 0.0, 1.0)
