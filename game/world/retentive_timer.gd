class_name RetentiveTimer
extends DelayGate
## A clockwork delay (DelayGate's "clock") that keeps its time: a timer
## that adds up how long its stone has been lit, holds it while dark, and
## opens once the total reaches its delay, staying open until reset.
##
## The timing stone climbs a tooth a beat through the escapement while lit,
## as the clockwork delay's does. A catch holds it from falling back when
## the light leaves: a wheel on its axle with a sawtooth face, and a pin
## in a sleeve beside it, pushed into the teeth by the snuffer can's end
## while the can is parked. The teeth let the stone climb past the pin and
## not fall back, so it stays where it had climbed to and climbs on from
## there when lit again; at the top its finger turns the leaf edge-on and
## it stays there, lit or not.
##
## The reset (ResetSnuffer): a second geotrope above, lit by its own beam,
## slides the snuffer can along the axle over the timing stone, shutting
## out its light. As the can leaves its parked place the pin's spring draws
## it out of the teeth (RELEASE), and the timing stone's spring, its light
## cut off, drops it to its lower peg (the ratchet in its wheel lets it
## fall free of the escapement): reset, the leaf shut. The can keeps it
## dark while the reset stone stays lit, whatever the timing beam does;
## sliding back, it pushes the pin into the teeth again.

const RELEASE := 0.05                   # the can's travel at which the pin has left the teeth
const FACE_X := 0.16                    # m: the catch wheel on the timing stone's axle
const PIN_R := 0.032                    # m: the pin, out from the axle
const PIN_LONG := 0.01                  # m

var _snuffer: ResetSnuffer
var _pin: Node3D


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	super(at, brass, leaf_metal, glass, "clock", wait)
	name = "RetentiveTimer"


func _build_mechanism(brass: Material, stone_view: MeshInstance3D) -> void:
	super(brass, stone_view)
	# The catch: a wheel on the timing stone's axle, sawtooth teeth on its
	# face toward the can; the pin in its sleeve, held from the bracket.
	var face := CylinderMesh.new()
	face.top_radius = 0.038
	face.bottom_radius = 0.038
	face.height = 0.004
	face.radial_segments = 20
	face.material = brass
	var face_view := MeshInstance3D.new()
	face_view.mesh = face
	face_view.position = Vector3(FACE_X, 0, 0)
	face_view.rotation.z = PI * 0.5
	_stone.add_child(face_view)
	var tooth := PrismMesh.new()
	tooth.size = Vector3(0.008, 0.008, 0.006)
	tooth.left_to_right = 1.0
	tooth.material = brass
	for k in 16:
		var a := TAU * k / 16.0
		var t := MeshInstance3D.new()
		t.mesh = tooth
		t.transform = Transform3D(Basis(Vector3.RIGHT, a) * Basis(Vector3.BACK, PI * 0.5), Vector3(FACE_X - 0.006, cos(a) * PIN_R, sin(a) * PIN_R))
		_stone.add_child(t)
	var sleeve_at := Vector3(FACE_X - 0.008, STONE_UP, PIN_R)
	var sleeve := CylinderMesh.new()
	sleeve.top_radius = 0.004
	sleeve.bottom_radius = 0.004
	sleeve.height = 0.004
	sleeve.material = brass
	_add(sleeve, sleeve_at).rotation.z = PI * 0.5
	_bar(_head, sleeve_at, sleeve_at + Vector3(0, 0, 0.03), 0.003, brass)
	_bar(_head, sleeve_at + Vector3(0, 0, 0.03), Vector3(SIDE + 0.06, STONE_UP, PIN_R + 0.03), 0.003, brass)
	_bar(_head, Vector3(SIDE + 0.06, STONE_UP, PIN_R + 0.03), Vector3(SIDE + 0.06, STONE_UP, 0), 0.003, brass)
	_pin = Node3D.new()
	_head.add_child(_pin)
	_bar(_pin, Vector3.ZERO, Vector3(PIN_LONG, 0, 0), 0.0022, brass)
	_snuffer = ResetSnuffer.new(self, brass)
	_head.add_child(_snuffer)


func set_layer(layer: int) -> void:
	super(layer)
	if _snuffer != null:
		_snuffer.sensor.collision_layer = layer


## The watts of light on the reset stone this step.
func sense_reset(watts: float) -> void:
	_snuffer.watts = watts


## Where the reset stone is.
func reset_point() -> Vector3:
	return _snuffer.point()


func _physics_process(delta: float) -> void:
	_step = delta
	var frame := _head.global_basis
	var axle := frame.x.normalized()
	var h := delta / STEPS
	for k in STEPS:
		_snuffer.step(frame, h)
		var seeking := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
		var lift := Photogyrite.pull(_watts * (1.0 - _snuffer.shade()), 0.0) * seeking.cross(Vector3.UP).dot(axle)
		_hold_step(lift, h)
	var target := clampf((_turn - (TOP - TRIP)) / TRIP, 0.0, 1.0) * PI * 0.5
	_leaf_turn = move_toward(_leaf_turn, target, LEAF_SNAP * delta)
	open = _leaf_turn > PI * 0.5 - CLEAR
	_place()


## The timing stone, one step: the climb a tooth a beat while the light's
## pull beats the spring by ESCAPE; held by the catch otherwise; dropped
## free to its lower peg while the catch is released and the spring wins.
func _hold_step(lift: float, h: float) -> void:
	var drive := lift - (CLOCK_PRELOAD + SPRING * (_turn - LOWEST))
	var released := _snuffer.travel() > RELEASE
	if released and (_rate < 0.0 or drive < 0.0) and _turn > _rest:
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
	if _snuffer == null:
		return
	_snuffer.place()
	# The pin: its tail against the can's end, drawn back by its spring to
	# its stop as the can leaves.
	var tail := clampf(_snuffer.can_x() + ResetSnuffer.CAN_LONG * 0.5, FACE_X - 0.025, FACE_X - 0.015)
	_pin.position = Vector3(tail, STONE_UP, PIN_R)
