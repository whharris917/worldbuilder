class_name ResetSnuffer
extends Node3D
## A timer gate's reset (RetentiveTimer, RetentiveSandglass): a second
## geotrope, the reset stone, lit by its own beam (its own sensor body,
## meta "input" "reset", so BenchLight tells it from the timing stone's and
## the gate passes its watts on to `watts`), sliding a brass snuffer can
## along the timing stone's axle over the timing stone so no light reaches
## it (`shade`). The gate reads `can_x` and `travel` to work its own
## release.
##
## The reset stone's axle runs front to back (z), square to the timing
## stone's (x), at CENTRE over it; the stone lies level with its seeking
## end toward the ring's middle (-x) at rest, held on its lower peg by a
## coil spring, and light swings it up against the spring. A crank on its
## axle, hanging below it, swings its pin across as the stone turns, and a
## connecting rod of fixed length ROD from the pin to a lug on the can's
## top pushes the can along the axle: a slider and crank. The can closing
## on the fixed end plate is where the stone stops (TOP, its upper peg).
## When the reset light leaves, the spring swings the stone down and the
## rod draws the can back.
##
## Built in the gate's head frame: the timing stone's axle at
## LightGate.STONE_UP over the ring's middle, along x.

const CENTRE := Vector3(0.0085, LightGate.STONE_UP + 0.2, 0)   # the reset stone's axle
const POST_AT := LightGate.SIDE + 0.06  # its post, up from the gate's bracket
const BACK := -0.05                     # its axle's bearing, behind
const TOP := 1.2566                     # rad: its upper peg, 72 degrees over level: the can closed
const INERTIA := 8.0e-4                 # kg m²: the stone, crank and the can through the rod
const CRANK := 0.085                    # m: the crank's reach
const CRANK_AT := -0.9425               # rad: its angle at rest, 54 degrees below level toward +x
const CRANK_Z := 0.03                   # m: the crank and rod in front of the stone
const ROD := 0.075                      # m: the connecting rod
const CAN_R := 0.075                    # m
const CAN_LONG := 0.09                  # m
const CAN_PARKED := 0.1                 # m: the can's middle along the axle when parked
const CAN_OVER := 0.0                   # m: and closed over the stone
const PLATE_X := -0.048                 # m: the fixed end plate it closes on
const SNUFF_FROM := 0.7                 # the can's travel at which it starts to shade the stone

var sensor := StaticBody3D.new()
var watts := 0.0                        # on the reset stone this step

var _gate: LightGate
var _turn := 0.0
var _rate := 0.0
var _stone := Node3D.new()
var _can := Node3D.new()
var _rod: MeshInstance3D
var _glow: StandardMaterial3D
var _lug_y := 0.0
var _zero := 0.0                        # the slider's offset that parks the can at rest


func _init(gate: LightGate, brass: Material) -> void:
	name = "ResetSnuffer"
	_gate = gate
	_lug_y = LightGate.STONE_UP + sqrt(CAN_R * CAN_R - CRANK_Z * CRANK_Z)
	_zero = 0.0
	_zero = CAN_PARKED - _slide(0.0)
	_build(brass)


## The pin of the crank at the stone's turn `t`, in the head's frame.
func _pin(t: float) -> Vector3:
	var a := CRANK_AT - t
	return CENTRE + Vector3(cos(a), sin(a), 0) * CRANK + Vector3(0, 0, CRANK_Z)


## The can's middle along the axle with the stone at turn `t`: the rod's
## fixed length from the pin down to the lug at the can's top.
func _slide(t: float) -> float:
	var pin := _pin(t)
	var dy := pin.y - _lug_y
	return pin.x + sqrt(maxf(ROD * ROD - dy * dy, 0.0)) + _zero


## Where the can's middle is now along the axle.
func can_x() -> float:
	return _slide(_turn)


## The can's travel, 0 parked to 1 closed over the stone.
func travel() -> float:
	return clampf((CAN_PARKED - can_x()) / (CAN_PARKED - CAN_OVER), 0.0, 1.0)


## How much of the timing stone's light the can shuts out, 0 to 1.
func shade() -> float:
	return clampf((travel() - SNUFF_FROM) / (1.0 - SNUFF_FROM), 0.0, 1.0)


## Where the reset stone is (world).
func point() -> Vector3:
	return to_global(CENTRE)


func _build(brass: Material) -> void:
	var up := LightGate.STONE_UP
	# The fixed end plate and the can, its open end toward the stone, a
	# lug on its top for the rod.
	var plate := CylinderMesh.new()
	plate.top_radius = CAN_R
	plate.bottom_radius = CAN_R
	plate.height = 0.004
	plate.radial_segments = 24
	plate.material = brass
	var plate_view := MeshInstance3D.new()
	plate_view.mesh = plate
	plate_view.position = Vector3(PLATE_X, up, 0)
	plate_view.rotation.z = PI * 0.5
	add_child(plate_view)
	add_child(_can)
	var shell := CylinderMesh.new()
	shell.top_radius = CAN_R
	shell.bottom_radius = CAN_R
	shell.height = CAN_LONG
	shell.radial_segments = 24
	shell.cap_bottom = false
	var can_mat: BaseMaterial3D = StandardMaterial3D.new()
	if brass is BaseMaterial3D:
		can_mat = (brass as BaseMaterial3D).duplicate() as BaseMaterial3D
	can_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	shell.material = can_mat
	var shell_view := MeshInstance3D.new()
	shell_view.mesh = shell
	shell_view.rotation.z = -PI * 0.5
	_can.add_child(shell_view)
	var band := TorusMesh.new()
	band.inner_radius = CAN_R - 0.002
	band.outer_radius = CAN_R + 0.005
	band.rings = 24
	band.ring_segments = 6
	band.material = brass
	var band_view := MeshInstance3D.new()
	band_view.mesh = band
	band_view.position = Vector3(-CAN_LONG * 0.5, 0, 0)
	band_view.rotation.z = PI * 0.5
	_can.add_child(band_view)
	var lug := BoxMesh.new()
	lug.size = Vector3(0.012, 0.012, 0.01)
	lug.material = brass
	var lug_view := MeshInstance3D.new()
	lug_view.mesh = lug
	lug_view.position = Vector3(0, _lug_y - up + 0.004, CRANK_Z)
	_can.add_child(lug_view)
	# The post up from the gate's bracket, an arm back and across to the
	# reset stone's bearing behind it, its axle running forward.
	_gate._bar(self, Vector3(POST_AT, up, 0), Vector3(POST_AT, CENTRE.y + 0.008, 0), 0.008, brass)
	_gate._bar(self, Vector3(POST_AT, CENTRE.y, 0), Vector3(POST_AT, CENTRE.y, BACK), 0.006, brass)
	_gate._bar(self, Vector3(POST_AT, CENTRE.y, BACK), Vector3(CENTRE.x, CENTRE.y, BACK), 0.006, brass)
	_gate._bar(self, Vector3(CENTRE.x, CENTRE.y, BACK), Vector3(CENTRE.x, CENTRE.y, CRANK_Z + 0.012), 0.005, brass)
	# Its stop plate behind the stone, the two pegs out of it, the coil.
	var stop_plate := CylinderMesh.new()
	stop_plate.top_radius = 0.04
	stop_plate.bottom_radius = 0.04
	stop_plate.height = 0.003
	stop_plate.radial_segments = 20
	stop_plate.material = brass
	var stop_view := MeshInstance3D.new()
	stop_view.mesh = stop_plate
	stop_view.position = CENTRE + Vector3(0, 0, -0.04)
	stop_view.rotation.x = PI * 0.5
	add_child(stop_view)
	for t: float in [-0.17, TOP + 0.17]:
		var peg_at := CENTRE + Vector3(-cos(t), sin(t), 0) * 0.03
		_gate._bar(self, peg_at + Vector3(0, 0, -0.04), peg_at + Vector3(0, 0, -0.012), 0.0025, brass)
	for k in 3:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.008
		turn.outer_radius = 0.012
		turn.rings = 10
		turn.ring_segments = 6
		turn.material = brass
		var turn_view := MeshInstance3D.new()
		turn_view.mesh = turn
		turn_view.position = CENTRE + Vector3(0, 0, -0.036 + k * 0.006)
		turn_view.rotation.x = PI * 0.5
		add_child(turn_view)
	# The stone, turning about z: its seeking end toward -x at rest, a stop
	# arm behind it toward the pegs, the crank in front of it.
	_stone.position = CENTRE
	add_child(_stone)
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.5, 0.8, 0.48, 0.9)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	_glow.emission = Color(0.24, 0.62, 0.26)
	_glow.emission_energy_multiplier = 0.1
	var grown := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	LumenPart.grow_spinstone(grown, rng)
	var view := MeshInstance3D.new()
	view.mesh = grown.commit(_glow)
	view.transform = Transform3D(Basis(Vector3.BACK, PI * 0.5).scaled(Vector3.ONE * 0.4), Vector3(-0.006, 0, 0))
	_stone.add_child(view)
	_gate._bar(_stone, Vector3(0, 0, -0.02), Vector3(-0.035, 0, -0.02), 0.003, brass)
	var hub := CylinderMesh.new()
	hub.top_radius = 0.012
	hub.bottom_radius = 0.012
	hub.height = 0.008
	hub.material = brass
	var hub_view := MeshInstance3D.new()
	hub_view.mesh = hub
	hub_view.position = Vector3(0, 0, CRANK_Z)
	hub_view.rotation.x = PI * 0.5
	_stone.add_child(hub_view)
	_gate._bar(_stone, Vector3(0, 0, CRANK_Z), Vector3(cos(CRANK_AT), sin(CRANK_AT), 0) * CRANK + Vector3(0, 0, CRANK_Z), 0.004, brass)
	_rod = _gate._bar(self, Vector3.ZERO, Vector3.UP, 0.003, brass)
	# Its sensor.
	sensor.set_meta("part_of", _gate)
	sensor.set_meta("view", _gate)
	sensor.set_meta("input", "reset")
	var catch := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.06
	catch.shape = ball
	catch.position = CENTRE
	sensor.add_child(catch)
	add_child(sensor)


## One step of the reset stone against its spring, `frame` the head's
## basis in the world. It turns about z backward (its seeking end, toward
## -x at rest, rising toward +y).
func step(frame: Basis, h: float) -> void:
	var seek := frame * (Basis(Vector3.BACK, -_turn) * Vector3.LEFT)
	var twist := Photogyrite.pull(watts, 0.0) * seek.cross(Vector3.UP).dot(-frame.z.normalized()) \
			- (LightGate.PRELOAD + LightGate.SPRING * _turn)
	_rate += (twist - LightGate.PIVOT * _rate) / INERTIA * h
	_turn += _rate * h
	if _turn < 0.0:
		_turn = 0.0
		_rate = -_rate * LightGate.BOUNCE if _rate < 0.0 else _rate
	elif _turn > TOP:
		_turn = TOP
		_rate = -_rate * LightGate.BOUNCE if _rate > 0.0 else _rate


func place() -> void:
	_can.position = Vector3(can_x(), LightGate.STONE_UP, 0)
	_stone.rotation.z = -_turn
	var pin := _pin(_turn)
	var lug := Vector3(can_x(), _lug_y + 0.004, CRANK_Z)
	var length := maxf(pin.distance_to(lug), 0.001)
	_rod.transform = Transform3D(CozyMesh.aligned((lug - pin) / length).scaled_local(Vector3(1, length, 1)), (pin + lug) * 0.5)
	_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(watts / 60.0, 0.0, 1.0)
