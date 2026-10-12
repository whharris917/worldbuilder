class_name SandShutter
extends DelayGate
## A gate whose shutter is an hourglass standing in the ring itself
## (DelayGate's "shutter"), worked by its geotrope on its spring as the
## pointed gate's is (LightGate), through a cord over two pulleys that
## turns the glass twice as far as the stone.
##
## The glass turns end over end on an axle across the ring through the
## beam's point, P. At rest bulb B is below with all the sand, its pile's
## top at P, so the sand stops the beam. P lies DROP from the neck, a
## third of the bulb's length, so the full pile is longer than half the
## bulb: turned over, its sand slides to the neck end and still covers P,
## and lying level as it turns it fills the bulb past its middle, so the
## beam never gets through on the way. Over, the sand runs from B down
## into A; once B's sand no longer reaches P the beam passes. That is the
## delay: B's sand from full down to DROP's length, (1 - DROP / (LENGTH -
## DROP)) of the whole run. A gets all of it below P, so the beam stays
## clear. When the light leaves, the glass turns back: A's sand, now
## above, lies at A's shoulder by the neck, where a wide glass tube
## (RETURN) takes it round the glass's side, clear of the beam, to B's far
## end, all of it in BYPASS_RUN seconds, so B is full to P again and the
## beam stopped almost at once. While the glass is over, A's sand lies at
## A's far end and B's at its neck, both clear of the tube's mouths, so
## only the neck passes sand. T fits a glass with
## a narrower or wider neck (sand flows as the neck's width to the 2.5
## power), so the run suits the delay.

const LENGTH := 0.08                    # m: each bulb, neck to end
const DROP := LENGTH / 3.0              # m: the neck to P, in B
const FULL := LENGTH - DROP             # m: B's sand at full, end to P
const BULB_R := 0.03                    # m
const REST_S := -0.1745                 # rad: the stone at rest, 10 degrees under level
const TOP_S := 1.3963                   # rad: its upper peg, 80 degrees over, a quarter turn on
const FRAME_X := 0.04                   # m: the glass's frame, either side of it
const PULLEY_BIG := 0.04                # m: on the stone's axle
const PULLEY_SMALL := 0.02              # m: on the glass's
## The return tube in the glass's frame: a cubic's four points from A's
## shoulder by the neck, out to the side across the ring (x) and a little
## toward the ring's back, to B's far end.
const RETURN := [Vector3(-0.02, DROP + 0.012, 0), Vector3(-0.078, DROP + 0.035, 0.02),
		Vector3(-0.078, -FULL - 0.035, 0.02), Vector3(-0.016, -FULL + 0.008, 0)]

var _run := 10.0                        # s: all the sand through the neck
var _neck: MeshInstance3D
var _stream: MeshInstance3D
var _pile_a: MeshInstance3D
var _pile_b: MeshInstance3D


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	_sand = 1.0
	super(at, brass, leaf_metal, glass, "shutter", wait)
	name = "SandShutter"
	open = false


## The delay, seconds: a glass whose neck runs B down to DROP in it.
func set_delay(seconds: float) -> void:
	delay = clampf(seconds, 0.5, LONGEST)
	_rest = REST_S
	_run = delay / (1.0 - DROP / FULL)
	if _neck != null:
		var r := 0.004 * pow(_run / 10.0, -0.4)
		(_neck.mesh as CylinderMesh).top_radius = r
		(_neck.mesh as CylinderMesh).bottom_radius = r


func _build_mechanism(brass: Material, stone_view: MeshInstance3D) -> void:
	_leaf.visible = false
	_mount_geotrope(brass, stone_view, POST_X, SIDE + 0.006)
	_peg(brass, REST_S - 0.17)
	_peg(brass, TOP_S + 0.17)
	# The pulleys and the cord between them.
	var big := _wheel(brass, PULLEY_BIG, 0)
	big.position = Vector3(SIDE, 0, 0)
	_stone.add_child(big)
	_head.add_child(_glass)
	var small := _wheel(brass, PULLEY_SMALL, 0)
	small.position = Vector3(SIDE, 0, 0)
	_glass.add_child(small)
	var cord := StandardMaterial3D.new()
	cord.albedo_color = Color(0.35, 0.27, 0.2)
	for side: float in [-1.0, 1.0]:
		_bar(_head, Vector3(SIDE, STONE_UP, side * PULLEY_BIG), Vector3(SIDE, 0, side * PULLEY_SMALL), 0.0025, cord)
	# The glass's axle from the ring's sides to its frame, out to the pulley.
	_bar(_head, Vector3(-0.14, 0, 0), Vector3(-FRAME_X, 0, 0), 0.005, brass)
	_bar(_head, Vector3(FRAME_X, 0, 0), Vector3(SIDE + 0.006, 0, 0), 0.005, brass)
	# The glass, in its own frame: P at the origin, B from FULL below it
	# to the neck DROP above, A from the neck to LENGTH beyond.
	for k in 2:
		var bulb := SphereMesh.new()
		bulb.radius = BULB_R
		bulb.height = LENGTH
		bulb.material = _glass_mat
		var bulb_view := MeshInstance3D.new()
		bulb_view.mesh = bulb
		bulb_view.position = Vector3(0, DROP + LENGTH * 0.5 if k == 0 else DROP - LENGTH * 0.5, 0)
		bulb_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glass.add_child(bulb_view)
	for y: float in [-FULL, DROP + LENGTH]:
		var cap := CylinderMesh.new()
		cap.top_radius = BULB_R + 0.003
		cap.bottom_radius = BULB_R + 0.003
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
	var neck := CylinderMesh.new()
	neck.height = 0.012
	neck.radial_segments = 10
	neck.material = _glass_mat
	_neck = MeshInstance3D.new()
	_neck.mesh = neck
	_neck.position = Vector3(0, DROP, 0)
	_glass.add_child(_neck)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.86, 0.74, 0.5)
	sand_mat.roughness = 0.95
	for k in 2:
		var pile := CylinderMesh.new()
		pile.top_radius = 0.019
		pile.bottom_radius = 0.019
		pile.height = 1.0
		pile.radial_segments = 12
		pile.material = sand_mat
		var pile_view := MeshInstance3D.new()
		pile_view.mesh = pile
		_glass.add_child(pile_view)
		if k == 0:
			_pile_a = pile_view
		else:
			_pile_b = pile_view
	_stream = _bar(_glass, Vector3(0, -0.5, 0), Vector3(0, 0.5, 0), 0.0015, sand_mat)
	var tube := CozyMesh.new()
	for k in 20:
		tube.rod(_return_at(k / 20.0), _return_at((k + 1) / 20.0), 0.0055, 8, Color.WHITE)
	var tube_view := MeshInstance3D.new()
	tube_view.mesh = tube.commit(_glass_mat)
	tube_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_glass.add_child(tube_view)
	var grain := SphereMesh.new()
	grain.radius = 0.0045
	grain.height = 0.008
	grain.radial_segments = 6
	grain.rings = 3
	grain.material = sand_mat
	for k in GRAINS:
		var g := MeshInstance3D.new()
		g.mesh = grain
		g.visible = false
		_glass.add_child(g)
		_grains.append(g)
		_grain_at.append(-1.0)
	if closing:
		_bead(Vector3(POST_X, 0.08, 0))


func _physics_process(delta: float) -> void:
	_step = delta
	var frame := _head.global_basis
	var pull := Photogyrite.pull(_watts, 0.0)
	var h := delta / STEPS
	for k in STEPS:
		var seeking := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
		var lift := pull * seeking.cross(Vector3.UP).dot(frame.x.normalized())
		var twist := lift - (PRELOAD + SPRING * (_turn - REST_S))
		_rate += (twist - PIVOT * _rate) / GLASS_INERTIA * h
		_turn += _rate * h
		if _turn < REST_S:
			_turn = REST_S
			_rate = -_rate * BOUNCE if _rate < 0.0 else _rate
		elif _turn > TOP_S:
			_turn = TOP_S
			_rate = -_rate * BOUNCE if _rate > 0.0 else _rate
		# Sand runs through the neck from the upper bulb to the lower.
		var into_b := clampf(cos(_flip()) * 3.0, -1.0, 1.0)
		var run := _run
		if into_b > 0.0:
			# A above: its sand pours round the return tube as well.
			run = 1.0 / (1.0 / _run + 1.0 / BYPASS_RUN)
		_sand = clampf(_sand + into_b * h / run, 0.0, 1.0)
	open = not _covered()
	_place()


## The glass's turn: twice the stone's from rest, 0 with B below.
func _flip() -> float:
	return 2.0 * (_turn - REST_S)


## Whether B's sand covers P: with B's end below, only when B is full to
## P; with its neck below, while its sand reaches DROP; lying near level,
## while it fills more than half the bulb, above the axis.
func _covered() -> bool:
	var c := cos(_flip())
	var length := _sand * FULL
	if c > 0.25:
		return _sand > 0.985
	if c < -0.25:
		return length >= DROP
	return length / LENGTH > 0.5


func _place() -> void:
	_stone.rotation.x = _turn
	_glass.rotation.x = _flip()
	if _pile_a == null:
		return
	var b_low := cos(_flip()) > 0.0
	# B's sand from its lower end: its far end (-FULL) or its neck (DROP).
	var b_len := _sand * FULL
	_pile_b.visible = b_len > 0.001
	var b_from := -FULL if b_low else DROP
	var b_dir := 1.0 if b_low else -1.0
	_pile_b.scale = Vector3(1, maxf(b_len, 0.001), 1)
	_pile_b.position = Vector3(0, b_from + b_dir * b_len * 0.5, 0)
	# A's from its lower end: its neck when B is below, else its far end.
	var a_len := (1.0 - _sand) * FULL
	_pile_a.visible = a_len > 0.001
	var a_from := DROP if b_low else DROP + LENGTH
	var a_dir := 1.0 if b_low else -1.0
	_pile_a.scale = Vector3(1, maxf(a_len, 0.001), 1)
	_pile_a.position = Vector3(0, a_from + a_dir * a_len * 0.5, 0)
	# The thin stream through the neck while sand runs, from the neck to
	# the lower bulb's pile.
	var running := absf(cos(_flip())) > 0.3 and (_sand > 0.0 if not b_low else _sand < 1.0)
	_stream.visible = running
	if running:
		var top := DROP
		var bottom := (b_from + b_dir * b_len) if b_low else (a_from + a_dir * a_len)
		_set_bar(_stream, Vector3(0, top, 0), Vector3(0, bottom, 0))
	_pour()
	_stone_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(_watts / 60.0, 0.0, 1.0)


## A point on the return tube, `u` 0 at A's shoulder to 1 at B's far end.
func _return_at(u: float) -> Vector3:
	var a: Vector3 = RETURN[0]
	var b: Vector3 = RETURN[1]
	var c: Vector3 = RETURN[2]
	var d: Vector3 = RETURN[3]
	var v := 1.0 - u
	return a * v * v * v + b * 3.0 * v * v * u + c * 3.0 * v * u * u + d * u * u * u


## The sand running round the return tube: while A is above with sand in
## it, clumps leave its mouth one after another and run down to B; once A
## is empty, those in the tube run on out and no more follow.
func _pour() -> void:
	var pouring := _sand < 1.0 and cos(_flip()) > 0.3
	var last := 2.0
	for k in GRAINS:
		if _grain_at[k] >= 0.0:
			last = minf(last, _grain_at[k])
	for k in GRAINS:
		var u := _grain_at[k]
		if u >= 0.0:
			u += GRAIN_SPEED * _step
			if u > 1.0:
				u = -1.0
		if u < 0.0 and pouring and (last >= 1.0 / GRAINS or last > 1.5):
			u = 0.0
			last = 0.0
		_grain_at[k] = u
		_grains[k].visible = u >= 0.0
		if u >= 0.0:
			_grains[k].position = _return_at(u)


func _set_bar(bar: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := maxf(a.distance_to(b), 0.001)
	bar.transform = Transform3D(CozyMesh.aligned((b - a) / length).scaled_local(Vector3(1, length, 1)), (a + b) * 0.5)
