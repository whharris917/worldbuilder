class_name ResetSnuffer
extends Node3D
## A timer gate's reset (RetentiveTimer, RetentiveSandglass): a second
## geotrope, the reset stone, on its own axle with its own coil spring and
## pegs, lit by its own beam (its own sensor body, meta "input" "reset",
## so BenchLight tells it from the timing stone's and the gate passes its
## watts on to `watts`). Light on it swings it up against its spring as
## the pointed gate's stone swings, and its crank, through a link, slides
## a brass snuffer can along the timing stone's axle over the timing
## stone, closing on a fixed end plate, so no light reaches it (`shade`).
## The gate reads `travel` to work its own release (a pawl lifted, flap
## stoppers drawn out). When the reset light leaves, the spring swings the
## stone down and the can slides back.
##
## Built in the gate's head frame: the timing stone's axle at STONE_UP over
## the ring's middle, along x; the reset stone above it at RESET_UP, out at
## RESET_X; its post at POST_AT, up from the gate's bracket.

const RESET_UP := LightGate.STONE_UP + 0.17
const RESET_X := 0.1
const POST_AT := LightGate.SIDE + 0.06
const TOP := 1.3963                     # rad: its upper peg, 80 degrees over level
const INERTIA := 8.0e-4                 # kg m²: the stone, crank and the can through the link
const CAN_R := 0.075                    # m
const CAN_LONG := 0.09                  # m
const CAN_PARKED := 0.1                 # m: the can's middle along the axle when parked
const CAN_OVER := 0.0                   # m: and over the stone
const PLATE_X := -0.048                 # m: the fixed end plate it closes on
const SNUFF_FROM := 0.7                 # the can's travel at which it starts to shade the stone

var sensor := StaticBody3D.new()
var watts := 0.0                        # on the reset stone this step

var _gate: LightGate
var _turn := 0.0
var _rate := 0.0
var _stone := Node3D.new()
var _can := Node3D.new()
var _link: MeshInstance3D
var _glow: StandardMaterial3D


func _init(gate: LightGate, brass: Material) -> void:
	name = "ResetSnuffer"
	_gate = gate
	_build(brass)


func _build(brass: Material) -> void:
	var up := LightGate.STONE_UP
	# The fixed end plate and the can, its open end toward the stone.
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
	# The reset stone's post and axle, its coil and pegs.
	_gate._bar(self, Vector3(POST_AT, up, 0), Vector3(POST_AT, RESET_UP + 0.01, 0), 0.008, brass)
	_gate._bar(self, Vector3(POST_AT, RESET_UP, 0), Vector3(RESET_X - 0.05, RESET_UP, 0), 0.005, brass)
	for k in 3:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.008
		turn.outer_radius = 0.012
		turn.rings = 10
		turn.ring_segments = 6
		turn.material = brass
		var turn_view := MeshInstance3D.new()
		turn_view.mesh = turn
		turn_view.position = Vector3(RESET_X + 0.045 + k * 0.006, RESET_UP, 0)
		turn_view.rotation.z = PI * 0.5
		add_child(turn_view)
	# The stop plate, fixed on the axle past the coil, and its two pegs
	# set into it where the stone's stop arm meets them.
	var stop_plate := CylinderMesh.new()
	stop_plate.top_radius = 0.04
	stop_plate.bottom_radius = 0.04
	stop_plate.height = 0.003
	stop_plate.radial_segments = 20
	stop_plate.material = brass
	var stop_view := MeshInstance3D.new()
	stop_view.mesh = stop_plate
	stop_view.position = Vector3(RESET_X + 0.062, RESET_UP, 0)
	stop_view.rotation.z = PI * 0.5
	add_child(stop_view)
	for a: float in [-0.17, TOP + 0.17]:
		var peg_at := Vector3(0, sin(a), -cos(a)) * 0.03 + Vector3(RESET_X + 0.036, RESET_UP, 0)
		_gate._bar(self, peg_at, peg_at + Vector3(0.025, 0, 0), 0.0025, brass)
	# The stone, its stop arm and its crank (down toward the can at rest).
	_stone.position = Vector3(RESET_X, RESET_UP, 0)
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
	view.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 0.4), Vector3(0, 0, -0.008))
	_stone.add_child(view)
	_gate._bar(_stone, Vector3(0.04, 0, 0), Vector3(0.04, 0, -0.035), 0.003, brass)
	_gate._bar(_stone, Vector3(-0.03, 0, 0), Vector3(-0.03, -0.05, 0), 0.004, brass)
	_link = _gate._bar(self, Vector3.ZERO, Vector3.UP, 0.003, brass)
	# Its sensor.
	sensor.set_meta("part_of", _gate)
	sensor.set_meta("view", _gate)
	sensor.set_meta("input", "reset")
	var catch := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.06
	catch.shape = ball
	catch.position = Vector3(RESET_X, RESET_UP, 0)
	sensor.add_child(catch)
	add_child(sensor)


## The can's travel, 0 parked to 1 over the stone.
func travel() -> float:
	return clampf(_turn / (TOP * 0.9), 0.0, 1.0)


## How much of the timing stone's light the can shuts out, 0 to 1.
func shade() -> float:
	return clampf((travel() - SNUFF_FROM) / (1.0 - SNUFF_FROM), 0.0, 1.0)


## Where the reset stone is (world).
func point() -> Vector3:
	return to_global(Vector3(RESET_X, RESET_UP, 0))


## One step of the reset stone against its spring, `frame` the head's
## basis in the world.
func step(frame: Basis, h: float) -> void:
	var seek := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
	var twist := Photogyrite.pull(watts, 0.0) * seek.cross(Vector3.UP).dot(frame.x.normalized()) \
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
	var t := travel()
	_can.position = Vector3(lerpf(CAN_PARKED, CAN_OVER, t), LightGate.STONE_UP, 0)
	_stone.rotation.x = _turn
	var pin := Vector3(RESET_X - 0.03, RESET_UP, 0) + Vector3(0, -cos(_turn), -sin(_turn)) * 0.05
	var top := _can.position + Vector3(0, CAN_R, 0)
	var length := maxf(pin.distance_to(top), 0.001)
	_link.transform = Transform3D(CozyMesh.aligned((top - pin) / length).scaled_local(Vector3(1, length, 1)), (pin + top) * 0.5)
	_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(watts / 60.0, 0.0, 1.0)
