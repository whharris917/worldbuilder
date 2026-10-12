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
## The reset (ResetSnuffer): a second geotrope above, lit by its own beam,
## slides a snuffer can over the timing stone, shutting out its light; once
## the can is most of the way over, its crank's cam lifts the holding pawl
## (PAWL_LIFT), and the timing stone's spring drops it to its lower peg
## (the ratchet in its wheel lets it fall free of the escapement): reset,
## the leaf shut. The can keeps it dark while the reset stone stays lit,
## whatever the timing beam does.

const PAWL_LIFT := 0.8                  # the can's travel at which the cam lifts the pawl

var _snuffer: ResetSnuffer
var _pawl: Node3D


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	super(at, brass, leaf_metal, glass, "clock", wait)
	name = "RetentiveTimer"


func _build_mechanism(brass: Material, stone_view: MeshInstance3D) -> void:
	super(brass, stone_view)
	# The holding pawl over the timing stone's wheel.
	_pawl = Node3D.new()
	_pawl.position = Vector3(SIDE + 0.004, STONE_UP + 0.062, -0.03)
	_head.add_child(_pawl)
	_bar(_pawl, Vector3.ZERO, Vector3(0, -0.016, 0.026), 0.003, brass)
	_bar(_head, Vector3(SIDE + 0.06, STONE_UP + 0.062, -0.03), Vector3(SIDE + 0.004, STONE_UP + 0.062, -0.03), 0.003, brass)
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
## pull beats the spring by ESCAPE; held by the pawl otherwise; dropped
## free to its lower peg while the pawl is lifted and the spring wins.
func _hold_step(lift: float, h: float) -> void:
	var drive := lift - (CLOCK_PRELOAD + SPRING * (_turn - LOWEST))
	var lifted := _snuffer.travel() > PAWL_LIFT
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
	if _snuffer == null:
		return
	_snuffer.place()
	_pawl.rotation.x = -0.5 if _snuffer.travel() > PAWL_LIFT else 0.0
