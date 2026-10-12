class_name DelayGate
extends LightGate
## An opening gate that opens only once its stone has been lit for its
## time, `delay` seconds, worked by its geotrope on its spring as the
## pointed gate's is (LightGate), timed by a mechanism between the stone
## and the leaf. Two kinds (`works`):
##
## "sand", the hourglass: the stone's axle turns a sand glass beside the
## ring through a pair of gears, from leaning with bulb A down (the stone
## at rest) to leaning the other way with bulb B down (the stone on its
## upper peg, SAND_TOP; light too weak to hold it there leaves the glass
## short of the pan). Sand runs from whichever bulb is up into the lower at a
## steady rate, the whole of it in GLASS_RUN seconds (`_sand`, the share
## in B). With the glass over, B's end rests on the pan of a lever; as
## sand gathers in B it presses harder, and once the share passes the
## counterweight's setting (delay over GLASS_RUN; the weight slides along
## the lever) the lever tips and its far end lifts a link that turns the
## leaf edge-on. When the light leaves, the spring swings the stone back,
## the glass tips back, B's end leaves the pan and the leaf shuts; the
## sand then runs back into A, so a light coming again soon finds some
## still in B and opens sooner.
##
## "clock", the clockwork: the stone's axle carries a wheel driving an
## escape wheel through a pinion, governed by an anchor on a pendulum
## beating every BEAT seconds: while the light's pull beats the spring by
## more than ESCAPE, the stone climbs one tooth a beat, at RATE whatever
## the light, until its upper peg at TOP; with less it stalls. A ratchet
## in the wheel lets it fall back freely: when the light leaves, the
## spring swings it down to its lower peg at once. The lower peg is set
## by the delay (TOP less the climb of `delay` seconds), so the climb
## takes the delay; in its last TRIP of travel a finger on the stone's
## axle lifts a link to the leaf's crank, turning the leaf edge-on.
##
## Either way the gate lets its beam by while the leaf is within CLEAR
## of edge-on.

const TOP := 1.2217                     # rad: the clockwork stone's upper peg, 70 degrees over level
const LOWEST := -0.1745                 # rad: its lower peg for the longest delay, 10 degrees under
const LONGEST := 13.0                   # s
const RATE := (TOP - LOWEST) / LONGEST  # rad/s: the escapement's climb
const BEAT := 0.5                       # s: the pendulum's swing one way, a tooth
const PENDULUM := 0.248                 # m: the length beating half seconds
const ESCAPE := 0.002                   # N m: the twist the escapement needs to run
const TRIP := 0.0873                    # rad: the last 5 degrees of the climb turn the leaf
const CLOCK_INERTIA := 3.0e-4           # kg m²: the stone and its wheel, falling free
const CLOCK_PRELOAD := 0.008            # N m: its spring at the lowest peg
const GLASS_RUN := 14.4                 # s: all the sand from one bulb to the other
const GLASS_INERTIA := 3.0e-3           # kg m²: the stone with the glass geared to it
const LEAN := 0.35                      # rad: the glass's lean either side
const SAND_TOP := 1.3963                # rad: the hourglass stone's upper peg, 80 degrees over level, short
                                        # of upright so the light holds it there
const GLASS_TURN := (PI - 2.0 * LEAN) / SAND_TOP     # the glass's turn for the stone's
const GLASS_X := SIDE + 0.045           # m: the glass's middle, out to the side
const GLASS_Y := STONE_UP - 0.069       # m: its axle, under the stone's
const BULB := 0.085                     # m: the glass's middle to each end
const LEAF_SNAP := 15.0                 # rad/s: the leaf turned by the lever's link

var works := "sand"
var delay := 2.0

var _rest := 0.0                        # rad: the clockwork stone's lower peg
var _beat := 0.0
var _swing := 0.0                       # rad: the pendulum's phase
var _amp := 0.0                         # its swing, 0 to 1
var _sand := 0.0                        # the share of the sand in bulb B
var _leaf_turn := 0.0
var _tripped := false
var _brass: Material
var _glass_mat: Material
var _low_peg: MeshInstance3D
var _glass := Node3D.new()
var _sand_a: MeshInstance3D
var _sand_b: MeshInstance3D
var _lever := Node3D.new()
var _weight: MeshInstance3D
var _link: MeshInstance3D
var _pendulum := Node3D.new()
var _escape := Node3D.new()
var _crank_dz := 1.0


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, how: String, wait: float) -> void:
	works = how
	delay = wait
	_brass = brass
	_glass_mat = glass
	super(at, brass, leaf_metal, glass, false)
	name = "Hourglass" if works == "sand" else "ClockworkDelay"
	set_delay(wait)
	_turn = _rest


## The delay, seconds: the clockwork's lower peg or the hourglass's
## counterweight moved to it.
func set_delay(seconds: float) -> void:
	delay = clampf(seconds, 0.5, LONGEST)
	if works == "clock":
		_rest = TOP - delay * RATE
		if _low_peg != null:
			_low_peg.queue_free()
		_low_peg = _peg(_brass, _rest - 0.17)
		if _turn < _rest:
			_turn = _rest
	elif _weight != null:
		_weight.position = Vector3(0, 0, -0.025 - 0.035 * delay / LONGEST)


func _build_mechanism(brass: Material, stone_view: MeshInstance3D) -> void:
	if works == "clock":
		_build_clock(brass, stone_view)
	else:
		_build_sand(brass, stone_view)


## The bracket from the ring's right shoulder up beside the mechanism.
func _bracket(brass: Material, x: float, top: float) -> void:
	_bar(_head, Vector3(0.125, 0.06, 0), Vector3(x, 0.12, 0), 0.008, brass)
	_bar(_head, Vector3(x, 0.12, 0), Vector3(x, top, 0), 0.008, brass)


## The hourglass: the geotrope over the ring, gears to the glass beside
## it, the glass with its sand, the lever and pan under it, the link to
## the leaf's crank.
func _build_sand(brass: Material, stone_view: MeshInstance3D) -> void:
	_bar(_head, Vector3(-0.14, 0, 0), Vector3(GLASS_X + 0.006, 0, 0), 0.007, brass)
	_mount_geotrope(brass, stone_view, POST_X, SIDE + 0.006)
	_peg(brass, -0.17)
	_peg(brass, SAND_TOP + 0.17)
	_bracket(brass, SIDE + 0.085, STONE_UP + 0.01)
	_bar(_head, Vector3(SIDE + 0.085, STONE_UP, 0), Vector3(SIDE, STONE_UP, 0), 0.005, brass)
	_bar(_head, Vector3(SIDE - 0.006, GLASS_Y, 0), Vector3(SIDE + 0.085, GLASS_Y, 0), 0.005, brass)
	# The gears: the stone's larger, the glass's smaller.
	var big := _wheel(brass, 0.042, 18)
	big.position = Vector3(SIDE, 0, 0)
	_stone.add_child(big)
	_glass.position = Vector3(0, GLASS_Y, 0)
	_head.add_child(_glass)
	var small := _wheel(brass, 0.027, 12)
	small.position = Vector3(SIDE, 0, 0)
	_glass.add_child(small)
	# The glass: two bulbs and a neck between brass caps and pillars, its
	# axle through the neck; bulb A toward its -y end, B toward +y.
	for side: float in [-1.0, 1.0]:
		var bulb := SphereMesh.new()
		bulb.radius = 0.028
		bulb.height = 0.07
		bulb.material = _glass_mat
		var bulb_view := MeshInstance3D.new()
		bulb_view.mesh = bulb
		bulb_view.position = Vector3(GLASS_X, side * 0.042, 0)
		bulb_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		_glass.add_child(bulb_view)
		var cap := CylinderMesh.new()
		cap.top_radius = 0.03
		cap.bottom_radius = 0.03
		cap.height = 0.008
		cap.material = brass
		var cap_view := MeshInstance3D.new()
		cap_view.mesh = cap
		cap_view.position = Vector3(GLASS_X, side * BULB, 0)
		_glass.add_child(cap_view)
		_bar(_glass, Vector3(GLASS_X + 0.026 * side, -BULB, 0.0), Vector3(GLASS_X + 0.026 * side, BULB, 0.0), 0.003, brass)
	_bar(_glass, Vector3(GLASS_X, -0.012, 0), Vector3(GLASS_X, 0.012, 0), 0.006, _glass_mat)
	var sand_mat := StandardMaterial3D.new()
	sand_mat.albedo_color = Color(0.86, 0.74, 0.5)
	sand_mat.roughness = 0.95
	for k in 2:
		var pile := CylinderMesh.new()
		pile.top_radius = 0.02
		pile.bottom_radius = 0.02
		pile.height = 1.0
		pile.radial_segments = 10
		pile.material = sand_mat
		var pile_view := MeshInstance3D.new()
		pile_view.mesh = pile
		_glass.add_child(pile_view)
		if k == 0:
			_sand_a = pile_view
		else:
			_sand_b = pile_view
	# The lever: its pivot on a post from the bracket, the pan under B's
	# end when the glass is over, the counterweight on the far arm.
	var pivot := Vector3(GLASS_X, GLASS_Y - BULB - 0.02, -0.075)
	_bar(_head, Vector3(SIDE + 0.085, 0.12, 0), Vector3(GLASS_X, pivot.y - 0.01, pivot.z), 0.005, brass)
	_lever.position = pivot
	_head.add_child(_lever)
	_bar(_lever, Vector3(0, 0, -0.06), Vector3(0, 0, 0.06), 0.004, brass)
	var pan := CylinderMesh.new()
	pan.top_radius = 0.022
	pan.bottom_radius = 0.016
	pan.height = 0.008
	pan.material = brass
	var pan_view := MeshInstance3D.new()
	pan_view.mesh = pan
	pan_view.position = Vector3(0, 0.006, 0.046)
	_lever.add_child(pan_view)
	var weight := CylinderMesh.new()
	weight.top_radius = 0.012
	weight.bottom_radius = 0.012
	weight.height = 0.022
	weight.material = brass
	_weight = MeshInstance3D.new()
	_weight.mesh = weight
	_weight.rotation.x = PI * 0.5
	_lever.add_child(_weight)
	_leaf_crank(brass, GLASS_X, -1.0)


## The leaf's crank at `x`, its arm toward the ring's back (`dz` 1) or
## front (-1) at rest, and the link from its pin up to the lever or the
## stone's finger.
func _leaf_crank(brass: Material, x: float, dz: float) -> void:
	_crank_dz = dz
	_bar(_leaf, Vector3(x - 0.006, 0, 0), Vector3(x + 0.006, 0, 0), 0.014, brass)
	_bar(_leaf, Vector3(x, 0, 0), Vector3(x, 0, CRANK * dz), 0.005, brass)
	_link = _bar(_head, Vector3.ZERO, Vector3.UP, 0.003, brass)


## The clockwork: the geotrope over the ring, its wheel, the escape wheel
## on its pinion, the anchor and pendulum, the finger and link to the
## leaf's crank on the far side.
func _build_clock(brass: Material, stone_view: MeshInstance3D) -> void:
	_bar(_head, Vector3(-0.17, 0, 0), Vector3(0.14, 0, 0), 0.007, brass)
	_mount_geotrope(brass, stone_view, -0.17, SIDE + 0.006)
	_peg(brass, TOP + 0.17)
	_bracket(brass, SIDE + 0.06, STONE_UP + 0.01)
	_bar(_head, Vector3(SIDE + 0.06, STONE_UP, 0), Vector3(SIDE, STONE_UP, 0), 0.005, brass)
	var wheel := _wheel(brass, 0.045, 30)
	wheel.position = Vector3(SIDE, 0, 0)
	_stone.add_child(wheel)
	# The escape wheel and its pinion on an arbor below.
	var arbor_y := STONE_UP - 0.057
	_escape.position = Vector3(0, arbor_y, 0)
	_head.add_child(_escape)
	_bar(_head, Vector3(SIDE - 0.006, arbor_y, 0), Vector3(SIDE + 0.06, arbor_y, 0), 0.004, brass)
	var pinion := _wheel(brass, 0.012, 8)
	pinion.position = Vector3(SIDE, 0, 0)
	_escape.add_child(pinion)
	var escape := _wheel(brass, 0.03, 15, true)
	escape.position = Vector3(SIDE + 0.025, 0, 0)
	_escape.add_child(escape)
	# The anchor over it and the pendulum from the anchor's arbor.
	_pendulum.position = Vector3(SIDE + 0.025, arbor_y + 0.04, 0)
	_head.add_child(_pendulum)
	_bar(_head, Vector3(SIDE + 0.06, arbor_y + 0.04, 0), Vector3(SIDE + 0.018, arbor_y + 0.04, 0), 0.003, brass)
	for side: float in [-1.0, 1.0]:
		_bar(_pendulum, Vector3.ZERO, Vector3(0, -0.028, side * 0.024), 0.003, brass)
	_bar(_pendulum, Vector3.ZERO, Vector3(0, -PENDULUM, 0), 0.002, brass)
	var bob := SphereMesh.new()
	bob.radius = 0.016
	bob.height = 0.032
	bob.material = brass
	var bob_view := MeshInstance3D.new()
	bob_view.mesh = bob
	bob_view.position = Vector3(0, -PENDULUM, 0)
	_pendulum.add_child(bob_view)
	# The finger on the stone's axle beyond the post, and the leaf's crank.
	_bar(_stone, Vector3(-0.165, 0, 0), Vector3(-0.165, -0.03, -0.012), 0.004, brass)
	_leaf_crank(brass, -0.165, 1.0)


## A toothed wheel turning about x: a disc and its teeth (sharp ones for
## an escape wheel).
func _wheel(brass: Material, r: float, teeth: int, sharp := false) -> Node3D:
	var n := Node3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = r
	disc.bottom_radius = r
	disc.height = 0.004
	disc.radial_segments = maxi(teeth, 12)
	disc.material = brass
	var disc_view := MeshInstance3D.new()
	disc_view.mesh = disc
	disc_view.rotation.z = PI * 0.5
	n.add_child(disc_view)
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.004, 0.006 if sharp else 0.005, 0.003 if sharp else 0.005)
	tooth.material = brass
	for k in teeth:
		var a := TAU * k / teeth
		var t := MeshInstance3D.new()
		t.mesh = tooth
		t.transform = Transform3D(Basis(Vector3.RIGHT, a + (0.4 if sharp else 0.0)), Vector3(0, cos(a), sin(a)) * (r + 0.002))
		n.add_child(t)
	return n


func _physics_process(delta: float) -> void:
	var frame := _head.global_basis
	var pull := Photogyrite.pull(_watts, 0.0)
	var h := delta / STEPS
	for k in STEPS:
		var seeking := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
		var lift := pull * seeking.cross(Vector3.UP).dot(frame.x.normalized())
		if works == "clock":
			_clock_step(lift, h)
		else:
			_sand_step(lift, h)
	var target := 0.0
	if works == "clock":
		target = clampf((_turn - (TOP - TRIP)) / TRIP, 0.0, 1.0) * PI * 0.5
	elif _tripped:
		target = PI * 0.5
	_leaf_turn = move_toward(_leaf_turn, target, LEAF_SNAP * delta)
	open = _leaf_turn > PI * 0.5 - CLEAR
	_place()


## The clockwork, one step: the climb a tooth a beat while the light's
## pull beats the spring by ESCAPE; a free fall on the ratchet while the
## spring wins; still between.
func _clock_step(lift: float, h: float) -> void:
	var drive := lift - (CLOCK_PRELOAD + SPRING * (_turn - LOWEST))
	if _rate < 0.0 or drive < 0.0 and _turn > _rest:
		# The ratchet slips: the spring swings it down.
		_rate += (drive - PIVOT * _rate) / CLOCK_INERTIA * h
		_turn += _rate * h
		_beat = 0.0
		if _turn <= _rest:
			_turn = _rest
			_rate = 0.0
	elif drive > ESCAPE and _turn < TOP:
		_beat += h
		_swing += h * PI / BEAT
		_amp = move_toward(_amp, 1.0, h * 2.0)
		if _beat >= BEAT:
			_beat -= BEAT
			_turn = minf(_turn + RATE * BEAT, TOP)
	else:
		_amp = move_toward(_amp, 0.0, h * 0.5)
		_swing += h * PI / BEAT


## The hourglass, one step: the stone against its spring with the glass
## geared to it; the sand running down the glass; the lever's pan.
func _sand_step(lift: float, h: float) -> void:
	var twist := lift - (PRELOAD + SPRING * _turn)
	_rate += (twist - PIVOT * _rate) / GLASS_INERTIA * h
	_turn += _rate * h
	if _turn < 0.0:
		_turn = 0.0
		_rate = -_rate * BOUNCE if _rate < 0.0 else _rate
	elif _turn > SAND_TOP:
		_turn = SAND_TOP
		_rate = -_rate * BOUNCE if _rate > 0.0 else _rate
	# Sand runs from the upper bulb to the lower, slowing only as the glass
	# lies near level.
	var tilt := _glass_angle()
	var into_b := clampf(-cos(tilt) * 3.0, -1.0, 1.0)
	_sand = clampf(_sand + into_b * h / GLASS_RUN, 0.0, 1.0)
	var on_pan := tilt > PI - LEAN - 0.03
	var needed := delay / GLASS_RUN
	if _tripped:
		_tripped = on_pan and _sand > needed - 0.01
	else:
		_tripped = on_pan and _sand >= needed


func _glass_angle() -> float:
	return LEAN + _turn * GLASS_TURN


func _place() -> void:
	_stone.rotation.x = _turn
	# The leaf turned so its crank's pin rises.
	_leaf.rotation.x = -_crank_dz * _leaf_turn
	var pin := Vector3(0, sin(_leaf_turn), _crank_dz * cos(_leaf_turn)) * CRANK
	if works == "clock":
		_escape.rotation.x = -(_turn - LOWEST) * 3.75
		_pendulum.rotation.x = _amp * 0.12 * sin(_swing)
		if _link != null:
			_set_link(Vector3(-0.165, 0, 0) + pin, Vector3(-0.165, STONE_UP - 0.04, CRANK * 0.6))
	else:
		# The gears turn the glass against the stone.
		_glass.rotation.x = -_glass_angle()
		_lever.rotation.x = 0.18 if _tripped else 0.0
		_place_sand()
		if _link != null:
			var far := _lever.position + _lever.basis * Vector3(0, 0, -0.06)
			_set_link(Vector3(GLASS_X, 0, 0) + pin, far)
	_stone_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(_watts / 60.0, 0.0, 1.0)


## The link between two points, a bar of its own length.
func _set_link(a: Vector3, b: Vector3) -> void:
	_link.transform = Transform3D(CozyMesh.aligned((b - a).normalized()).scaled_local(Vector3(1, a.distance_to(b), 1)), (a + b) * 0.5)


## Each bulb's sand: a column as long as its share, settled at whichever
## end of the bulb lies lower.
func _place_sand() -> void:
	if _sand_a == null:
		return
	var b_down := cos(_glass_angle()) < 0.0
	for k in 2:
		var share := _sand if k == 1 else 1.0 - _sand
		var pile := _sand_b if k == 1 else _sand_a
		var length := 0.05 * share
		pile.visible = length > 0.001
		var outer := 0.075 * (1.0 if k == 1 else -1.0)
		var inner := 0.012 * (1.0 if k == 1 else -1.0)
		var lower_is_outer := b_down if k == 1 else not b_down
		var from := outer if lower_is_outer else inner
		var toward := signf(inner - outer) if lower_is_outer else signf(outer - inner)
		pile.scale = Vector3(1, maxf(length, 0.001), 1)
		pile.position = Vector3(GLASS_X, from + toward * length * 0.5, 0)
