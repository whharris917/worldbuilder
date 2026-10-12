class_name RetentiveTimer
extends DelayGate
## A clockwork delay (DelayGate's "clock") that keeps its time: a timer
## that adds up how long its stone has been lit, holds it while dark, and
## opens once the total reaches its delay, staying open until reset.
##
## The timing stone climbs a tooth a beat through the escapement while lit,
## as the clockwork delay's does. A holding pawl on a ratchet wheel on its
## axle stops it falling back when the light leaves, so it stays where it
## had climbed to and climbs on from there when lit again; at the top its
## finger turns the leaf edge-on and it stays there, lit or not.
##
## Above it a second geotrope, the reset stone, on its own axle with its
## own coil spring and pegs, lit by its own beam (its own sensor body,
## meta "input" "reset", so BenchLight tells the two beams apart and calls
## `sense_reset`). Light on it swings it up against its spring (as the
## pointed gate's stone), and its crank, through a link, slides a brass
## snuffer can along the timing stone's axle over the timing stone,
## closing on a fixed end plate, so no light reaches it; once the can is
## most of the way over, the crank's cam lifts the holding pawl, and the
## timing stone's spring, its light cut off, drops it to its lower peg (the
## ratchet in its wheel lets it fall free of the escapement): reset, the
## leaf shut. The can keeps it dark while the reset stone stays lit,
## whatever the timing beam does. When the reset light leaves, the spring
## swings the reset stone down, the can slides back and the pawl drops.

const RESET_UP := STONE_UP + 0.17       # m: the reset stone's axle over the ring's middle
const RESET_X := 0.1                    # m: and out to the side, over the can's parked place
const RESET_TOP := 1.3963               # rad: its upper peg, 80 degrees over level
const RESET_INERTIA := 8.0e-4           # kg m²: the stone, crank and the can through the link
const CAN_R := 0.075                    # m: the snuffer can's radius
const CAN_LONG := 0.09                  # m: its length
const CAN_PARKED := 0.1                 # m: its middle out along the axle when parked
const CAN_OVER := 0.0                   # m: and over the stone
const PLATE_X := -0.048                 # m: the fixed end plate it closes on
const SNUFF_FROM := 0.7                 # the can's travel at which it starts to shade the stone
const PAWL_LIFT := 0.8                  # and at which the cam lifts the pawl

var reset_sensor := StaticBody3D.new()

var _reset_watts := 0.0
var _r_turn := 0.0                      # rad: the reset stone, 0 level to RESET_TOP
var _r_rate := 0.0
var _r_stone := Node3D.new()
var _can: Node3D
var _pawl: Node3D
var _r_link: MeshInstance3D
var _r_glow: StandardMaterial3D


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	super(at, brass, leaf_metal, glass, "clock", wait)
	name = "RetentiveTimer"


func _build_mechanism(brass: Material, stone_view: MeshInstance3D) -> void:
	super(brass, stone_view)
	_build_reset(brass)


## The pawl, the snuffer can and its end plate, the reset stone on its
## axle with its spring, pegs, crank and link, and its sensor.
func _build_reset(brass: Material) -> void:
	# The holding pawl over the timing stone's wheel.
	_pawl = Node3D.new()
	_pawl.position = Vector3(SIDE + 0.004, STONE_UP + 0.062, -0.03)
	_head.add_child(_pawl)
	_bar(_pawl, Vector3.ZERO, Vector3(0, -0.016, 0.026), 0.003, brass)
	_bar(_head, Vector3(SIDE + 0.06, STONE_UP + 0.062, -0.03), Vector3(SIDE + 0.004, STONE_UP + 0.062, -0.03), 0.003, brass)
	# The fixed end plate and the can.
	var plate := CylinderMesh.new()
	plate.top_radius = CAN_R
	plate.bottom_radius = CAN_R
	plate.height = 0.004
	plate.radial_segments = 24
	plate.material = brass
	_add(plate, Vector3(PLATE_X, STONE_UP, 0)).rotation.z = PI * 0.5
	_can = Node3D.new()
	_head.add_child(_can)
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
	# Its open end toward the stone (-x), its capped end away.
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
	# The reset stone's post up from the clockwork's bracket, its axle.
	_bar(_head, Vector3(SIDE + 0.06, STONE_UP, 0), Vector3(SIDE + 0.06, RESET_UP + 0.01, 0), 0.008, brass)
	_bar(_head, Vector3(SIDE + 0.06, RESET_UP, 0), Vector3(RESET_X - 0.05, RESET_UP, 0), 0.005, brass)
	for k in 3:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.008
		turn.outer_radius = 0.012
		turn.rings = 10
		turn.ring_segments = 6
		turn.material = brass
		_add(turn, Vector3(RESET_X + 0.045 + k * 0.006, RESET_UP, 0)).rotation.z = PI * 0.5
	for a: float in [-0.17, RESET_TOP + 0.17]:
		var peg_at := Vector3(0, sin(a), -cos(a)) * 0.03 + Vector3(RESET_X + 0.04, RESET_UP, 0)
		_bar(_head, peg_at, peg_at + Vector3(0.015, 0, 0), 0.0025, brass)
	_r_stone.position = Vector3(RESET_X, RESET_UP, 0)
	_head.add_child(_r_stone)
	_r_glow = StandardMaterial3D.new()
	_r_glow.albedo_color = Color(0.5, 0.8, 0.48, 0.9)
	_r_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_r_glow.roughness = 0.08
	_r_glow.metallic_specular = 0.9
	_r_glow.emission_enabled = true
	_r_glow.emission = Color(0.24, 0.62, 0.26)
	_r_glow.emission_energy_multiplier = 0.1
	var grown := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 919
	LumenPart.grow_spinstone(grown, rng)
	var view := MeshInstance3D.new()
	view.mesh = grown.commit(_r_glow)
	view.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 0.4), Vector3(0, 0, -0.008))
	_r_stone.add_child(view)
	# Its stop arm and its crank (down toward the can at rest).
	_bar(_r_stone, Vector3(0.04, 0, 0), Vector3(0.04, 0, -0.035), 0.003, brass)
	_bar(_r_stone, Vector3(-0.03, 0, 0), Vector3(-0.03, -0.05, 0), 0.004, brass)
	_r_link = _bar(_head, Vector3.ZERO, Vector3.UP, 0.003, brass)
	# Its sensor.
	reset_sensor.set_meta("part_of", self)
	reset_sensor.set_meta("view", self)
	reset_sensor.set_meta("input", "reset")
	var catch := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.06
	catch.shape = ball
	catch.position = Vector3(RESET_X, RESET_UP, 0)
	reset_sensor.add_child(catch)
	_head.add_child(reset_sensor)


func set_layer(layer: int) -> void:
	super(layer)
	reset_sensor.collision_layer = layer


## The watts of light on the reset stone this step.
func sense_reset(watts: float) -> void:
	_reset_watts = watts


## Where the reset stone is.
func reset_point() -> Vector3:
	return _head.to_global(Vector3(RESET_X, RESET_UP, 0))


## The can's travel, 0 parked to 1 over the stone, from the reset stone's
## turn.
func _travel() -> float:
	return clampf(_r_turn / (RESET_TOP * 0.9), 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_step = delta
	var frame := _head.global_basis
	var axle := frame.x.normalized()
	var h := delta / STEPS
	for k in STEPS:
		# The reset stone against its spring, as the pointed gate's.
		var r_seek := frame * (Basis(Vector3.RIGHT, _r_turn) * Vector3.FORWARD)
		var r_twist := Photogyrite.pull(_reset_watts, 0.0) * r_seek.cross(Vector3.UP).dot(axle) - (PRELOAD + SPRING * _r_turn)
		_r_rate += (r_twist - PIVOT * _r_rate) / RESET_INERTIA * h
		_r_turn += _r_rate * h
		if _r_turn < 0.0:
			_r_turn = 0.0
			_r_rate = -_r_rate * BOUNCE if _r_rate < 0.0 else _r_rate
		elif _r_turn > RESET_TOP:
			_r_turn = RESET_TOP
			_r_rate = -_r_rate * BOUNCE if _r_rate > 0.0 else _r_rate
		# The timing stone, its light shaded by the can.
		var shade := clampf((_travel() - SNUFF_FROM) / (1.0 - SNUFF_FROM), 0.0, 1.0)
		var seeking := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
		var lift := Photogyrite.pull(_watts * (1.0 - shade), 0.0) * seeking.cross(Vector3.UP).dot(axle)
		_hold_step(lift, h)
	var target := clampf((_turn - (TOP - TRIP)) / TRIP, 0.0, 1.0) * PI * 0.5
	_leaf_turn = move_toward(_leaf_turn, target, LEAF_SNAP * delta)
	open = _leaf_turn > PI * 0.5 - CLEAR
	_place()


## The timing stone, one step: the climb a tooth a beat while the light's
## pull beats the spring by ESCAPE; held by the pawl otherwise; dropped
## free to its lower peg while the pawl is lifted and the spring wins.
func _hold_step(lift: float, h: float) -> void:
	var drive := lift - (CLOCK_PRELOAD + SPRING * (_turn - LOWEST))
	var lifted := _travel() > PAWL_LIFT
	if lifted and (_rate < 0.0 or drive < 0.0) and _turn > _rest:
		_rate += (drive - PIVOT * _rate) / CLOCK_INERTIA * h
		_turn += _rate * h
		_beat = 0.0
		if _turn <= _rest:
			_turn = _rest
			_rate = 0.0
	elif drive > ESCAPE and _turn < TOP:
		_rate = 0.0
		_beat += h
		_swing += h * PI / BEAT
		_amp = move_toward(_amp, 1.0, h * 2.0)
		if _beat >= BEAT:
			_beat -= BEAT
			_turn = minf(_turn + RATE * BEAT, TOP)
	else:
		_rate = 0.0
		_amp = move_toward(_amp, 0.0, h * 0.5)
		_swing += h * PI / BEAT


func _place() -> void:
	super()
	if _can == null:
		return
	var travel := _travel()
	_can.position = Vector3(lerpf(CAN_PARKED, CAN_OVER, travel), STONE_UP, 0)
	_r_stone.rotation.x = _r_turn
	_pawl.rotation.x = -0.5 if travel > PAWL_LIFT else 0.0
	# The link from the crank's pin to the can's top.
	var pin := Vector3(RESET_X - 0.03, RESET_UP, 0) + Vector3(0, -cos(_r_turn), -sin(_r_turn)) * 0.05
	var top := _can.position + Vector3(0, CAN_R, 0)
	_set_link_bar(_r_link, pin, top)
	_r_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(_reset_watts / 60.0, 0.0, 1.0)


func _set_link_bar(bar: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var length := maxf(a.distance_to(b), 0.001)
	bar.transform = Transform3D(CozyMesh.aligned((b - a) / length).scaled_local(Vector3(1, length, 1)), (a + b) * 0.5)
