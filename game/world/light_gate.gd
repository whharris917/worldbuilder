class_name LightGate
extends StaticBody3D
## A gate a beam passes through, worked by light (Workshop, BenchLight):
## a brass ring with a round leaf in it on a spindle across it, square
## across the ring to stop a beam or turned edge-on to let it through, and
## a spinstone that turns the leaf against a spring, in one of two ways.
##
## Pointed (`by_spin` false): above the ring's middle, on its own axle
## parallel to the spindle (carried on a post beside the ring), a small
## geotrope pivoted at its middle, its seeking end toward the ring's
## front. A crank arm on each axle at the side, the same length and
## pointing the same way, a pin at each arm's end and a rod hung between
## the pins, so the two axles always stand at the same turn. A coil spring
## round the stone's axle, one end hooked into a round plate fixed on the
## post, the other into a collar on the axle, presses the seeking end
## down. Two pegs in the plate stop an arm on the collar: at rest the
## spring holds the stone level against the lower peg; the upper peg stops
## it pointing straight up, a quarter turn round. Light on the stone pulls
## its seeking end toward the upright by the geotrope's law, by the axle's
## own direction in the world, against the spring (PRELOAD, rising by
## SPRING with the turn); the pull fades to nothing at the upright, so the
## spring always holds it a little short: about 4 degrees in a lantern's
## beam, a tenth of a degree in the sun collector's.
##
## Spun (`by_spin` true): beside the ring, on a shaft standing upright in
## three bearings on a post, an earthstone standing on end, its seeking
## end up. The shaft's foot carries a bevel gear meshing with one on the
## end of the leaf's spindle, the pair alike, so the leaf turns as the
## shaft does. A flat spiral spring round the shaft, its inner end fixed to
## the shaft and its outer end to the post, holds the shaft against a peg;
## a second peg stops it a quarter turn round. Its seeking end already
## points at its body, so light pulls it nowhere (the bearings take any
## pull); it spins it about its length by the earthstone's law, and that
## twist, against the spiral's (SPIN_PRELOAD, rising by SPIN_SPRING),
## turns the shaft, the gears and the leaf.
##
## Either way the stone, the linkage and the leaf turn as one (INERTIA:
## mostly the leaf, a thin brass disc), stepped each physics frame from
## the watts on the stone (BenchLight, each step), with the pivots' drag
## and the pegs. Too little light leaves it on its first peg; more turns it
## to where light and spring balance; enough holds it on the second. The
## leaf lets a beam by while within CLEAR of edge-on: an opening gate's
## leaf is square at rest and edge-on a quarter turn round; a closing
## gate's is set a quarter turn round.
##
## Beams are told apart by what they strike: the ring's plate (this
## body) is the way through; the stone is a body of its own (`sensor`,
## carrying meta "part_of" back to the gate). The ring faces along its
## head's -z, turned by `aim` as a glass is.

const STONE_UP := 0.27                  # m: the stone's middle over the ring's middle
const CRANK := 0.05                     # m: each crank's reach
const SIDE := 0.17                      # m: the cranks, out to the side of the ring
const POST_X := -0.11                   # m: the post carrying the geotrope's axle
const SHAFT_X := 0.19                   # m: the earthstone's upright shaft, out to the side
const SHAFT_POST_X := 0.12              # m: the post carrying that shaft
const GEAR := 0.025                     # m: the bevel gears' pitch radius
const SPIRAL_Y := 0.1                   # m: the spiral spring, up the shaft
const STOP_Y := 0.16                    # m: the shaft's stop arm and its pegs
const TOP_Y := 0.37                     # m: the shaft's top bearing
const LEAF_THICK := 0.002               # m: the leaf, sheet brass
const INERTIA := 2.2e-3                 # kg m²: the leaf (2.0e-3) with the stone and linkage
const PRELOAD := 0.0145                 # N m: the coil's push at rest, which 3 W on the geotrope overcomes
const SPRING := 0.003                   # N m per radian of turn from rest
const SPIN_PRELOAD := 7.5e-4            # N m: the spiral's at rest, which 3 W spinning the earthstone overcomes
const SPIN_SPRING := 9.5e-4             # N m per radian: so 7 W turns the leaf open and 9 W holds it on its peg
const PIVOT := 2.5e-3                   # N m s: the pivots' drag
const BOUNCE := 0.2                     # how much of its speed the arm keeps off a peg
const CLEAR := 0.5236                   # rad: a leaf this near edge-on lets a beam by
const STEPS := 4                        # steps a physics frame

var closing := false
var by_spin := false
var open := false
var yaw := 0.0
var pitch := 0.0
var lit := false                        # light on its stone
var sensor := StaticBody3D.new()

var _head := Node3D.new()
var _leaf := Node3D.new()
var _low_crank := Node3D.new()
var _stone := Node3D.new()
var _stone_at := Vector3(0, STONE_UP, 0)
var _rod: MeshInstance3D
var _shape := CollisionShape3D.new()
var _stone_glow: StandardMaterial3D
var _label: Label3D
var _turn := 0.0                        # rad: from rest, 0 to a quarter turn
var _rate := 0.0                        # rad/s
var _watts := 0.0


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, is_closing: bool, spun := false) -> void:
	closing = is_closing
	by_spin = spun
	open = closing
	name = ("Closing" if closing else "Opening") + ("SpinGate" if by_spin else "Gate")
	position = at
	set_meta("view", self)
	add_child(_head)
	var ring := TorusMesh.new()
	ring.inner_radius = 0.115
	ring.outer_radius = 0.14
	ring.rings = 24
	ring.ring_segments = 8
	ring.material = brass
	_add(ring, Vector3.ZERO).rotation.x = PI * 0.5
	_head.add_child(_leaf)
	var leaf := CylinderMesh.new()
	leaf.top_radius = 0.11
	leaf.bottom_radius = 0.11
	leaf.height = LEAF_THICK
	leaf.radial_segments = 24
	leaf.rings = 1
	leaf.material = leaf_metal
	var leaf_view := MeshInstance3D.new()
	leaf_view.mesh = leaf
	leaf_view.rotation.x = PI * 0.5
	_leaf.add_child(leaf_view)
	_stone_glow = StandardMaterial3D.new()
	_stone_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stone_glow.roughness = 0.08
	_stone_glow.metallic_specular = 0.9
	_stone_glow.emission_enabled = true
	_stone_glow.emission_energy_multiplier = 0.1
	var grown := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	LumenPart.grow_spinstone(grown, rng)
	var stone_view := MeshInstance3D.new()
	stone_view.mesh = grown.commit(_stone_glow)
	_head.add_child(_stone)
	_stone.add_child(stone_view)
	if by_spin:
		_build_spun(brass, stone_view)
	else:
		_build_pointed(brass, stone_view)
	# The way through the ring.
	var plate_shape := BoxShape3D.new()
	plate_shape.size = Vector3(0.26, 0.26, 0.03)
	_shape.shape = plate_shape
	add_child(_shape)
	# The sensor's own body, at the stone.
	sensor.set_meta("part_of", self)
	sensor.set_meta("view", self)
	var catch := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.08
	catch.shape = ball
	catch.position = _stone_at
	sensor.add_child(catch)
	_head.add_child(sensor)
	_label = Label3D.new()
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 0.45
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)
	set_layer(4)
	_place()


## The geotrope over the ring on its level axle, the coil spring, the
## cranks and rod.
func _build_pointed(brass: Material, stone_view: MeshInstance3D) -> void:
	_stone_glow.albedo_color = Color(0.5, 0.8, 0.48, 0.9)
	_stone_glow.emission = Color(0.24, 0.62, 0.26)
	# The leaf's spindle across the ring, in bearings at either side of it,
	# and out to its crank.
	_bar(_head, Vector3(-0.14, 0, 0), Vector3(SIDE + 0.006, 0, 0), 0.007, brass)
	# The post up from the ring's side to the stone's axle, and the axle
	# out from its top past the stone to the crank.
	_bar(_head, Vector3(POST_X, 0.08, 0), Vector3(POST_X, STONE_UP + 0.012, 0), 0.01, brass)
	_bar(_head, Vector3(POST_X, STONE_UP, 0), Vector3(SIDE + 0.006, STONE_UP, 0), 0.006, brass)
	# The spring's plate on the post, and its two stop pegs.
	var plate := CylinderMesh.new()
	plate.top_radius = 0.05
	plate.bottom_radius = 0.05
	plate.height = 0.004
	plate.radial_segments = 20
	plate.material = brass
	_add(plate, Vector3(POST_X + 0.012, STONE_UP, 0)).rotation.z = PI * 0.5
	for a: float in [-0.17, PI * 0.5 + 0.17]:
		var peg_at := Vector3(0, sin(a), -cos(a)) * 0.04 + Vector3(0, STONE_UP, 0)
		_bar(_head, peg_at + Vector3(POST_X + 0.012, 0, 0), peg_at + Vector3(-0.055, 0, 0), 0.003, brass)
	# The coil, its fixed end hooked into the plate.
	for k in 4:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.011
		turn.outer_radius = 0.016
		turn.rings = 10
		turn.ring_segments = 6
		turn.material = brass
		_add(turn, Vector3(-0.09 + k * 0.007, STONE_UP, 0)).rotation.z = PI * 0.5
	var hook := Vector3(0, -0.0135, 0) + Vector3(0, STONE_UP, 0)
	_bar(_head, hook + Vector3(POST_X + 0.012, 0, 0), hook + Vector3(-0.09, 0, 0), 0.0025, brass)
	# What turns with the stone's axle: the stone, the collar with the
	# coil's other end hooked into it and the arm the pegs stop, the crank.
	_stone.position = Vector3(0, STONE_UP, 0)
	var collar := CylinderMesh.new()
	collar.top_radius = 0.012
	collar.bottom_radius = 0.012
	collar.height = 0.012
	collar.material = brass
	var collar_view := MeshInstance3D.new()
	collar_view.mesh = collar
	collar_view.position = Vector3(-0.058, 0, 0)
	collar_view.rotation.z = PI * 0.5
	_stone.add_child(collar_view)
	_bar(_stone, Vector3(-0.069, 0.0135, 0), Vector3(-0.058, 0.0135, 0), 0.0025, brass)
	_bar(_stone, Vector3(-0.058, 0, 0), Vector3(-0.058, 0, -0.046), 0.0035, brass)
	_crank(_stone, brass)
	_head.add_child(_low_crank)
	_crank(_low_crank, brass)
	# The rod between the two crank pins.
	var rod := CylinderMesh.new()
	rod.top_radius = 0.005
	rod.bottom_radius = 0.005
	rod.height = STONE_UP
	rod.material = brass
	_rod = _add(rod, Vector3(SIDE + 0.02, STONE_UP * 0.5, 0))
	# Grown upright (+y its seeking end), laid toward -z, made smaller.
	stone_view.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 0.55), Vector3(0, 0, -0.01))
	if closing:
		_bead(Vector3(POST_X, 0.08, 0))


## The earthstone on end on its upright shaft beside the ring, its
## bearings and post, the spiral spring, the pegs, the bevel gears.
func _build_spun(brass: Material, stone_view: MeshInstance3D) -> void:
	_stone_glow.albedo_color = Color(0.74, 0.62, 0.95, 0.9)
	_stone_glow.emission = Color(0.5, 0.36, 0.85)
	_stone_at = Vector3(SHAFT_X, STONE_UP, 0)
	# The leaf's spindle across the ring and out to its gear, which faces
	# the shaft's foot.
	_bar(_head, Vector3(-0.14, 0, 0), Vector3(SHAFT_X - GEAR + 0.006, 0, 0), 0.007, brass)
	var low_gear := Node3D.new()
	low_gear.position = Vector3(SHAFT_X - GEAR, 0, 0)
	low_gear.rotation.z = -PI * 0.5
	_bevel(low_gear, brass)
	_leaf.add_child(low_gear)
	# The post standing on the ring's shoulder, three arms out from it to
	# the shaft's bearings, and the shaft.
	var foot := Vector3(SHAFT_POST_X, 0.045, 0)
	_bar(_head, foot, Vector3(SHAFT_POST_X, TOP_Y + 0.01, 0), 0.009, brass)
	for y: float in [GEAR + 0.025, STOP_Y - 0.012, TOP_Y]:
		_bar(_head, Vector3(SHAFT_POST_X, y, 0), Vector3(SHAFT_X, y, 0), 0.006, brass)
		var bearing := CylinderMesh.new()
		bearing.top_radius = 0.012
		bearing.bottom_radius = 0.012
		bearing.height = 0.01
		bearing.material = brass
		_add(bearing, Vector3(SHAFT_X, y, 0))
	_stone.position = Vector3(SHAFT_X, 0, 0)
	_bar(_stone, Vector3(0, GEAR - 0.004, 0), Vector3(0, TOP_Y + 0.012, 0), 0.005, brass)
	var top_gear := Node3D.new()
	top_gear.position = Vector3(0, GEAR, 0)
	top_gear.rotation.x = PI
	_bevel(top_gear, brass)
	_stone.add_child(top_gear)
	# The stop plate (the middle bearing's arm widened), its two pegs, and
	# the arm on the shaft they stop.
	var plate := CylinderMesh.new()
	plate.top_radius = 0.045
	plate.bottom_radius = 0.045
	plate.height = 0.004
	plate.radial_segments = 20
	plate.material = brass
	_add(plate, Vector3(SHAFT_X, STOP_Y - 0.012, 0))
	for a: float in [-0.17, PI * 0.5 + 0.17]:
		var peg_at := Vector3(SHAFT_X - sin(a) * 0.035, STOP_Y - 0.012, -cos(a) * 0.035)
		_bar(_head, peg_at, peg_at + Vector3(0, 0.02, 0), 0.003, brass)
	_bar(_stone, Vector3(0, STOP_Y, 0), Vector3(0, STOP_Y, -0.042), 0.0035, brass)
	# The spiral spring: three turns flat round the shaft, the inner end in
	# a collar on the shaft, the outer end pinned to the post.
	var points: Array[Vector3] = []
	var turns := 3.0
	var n := 72
	for k in n + 1:
		var f := float(k) / n
		var a := PI + f * turns * TAU
		var r := lerpf(0.04, 0.008, f)
		points.append(Vector3(SHAFT_X + cos(a) * r, SPIRAL_Y, sin(a) * r))
	var coil := CozyMesh.new()
	for k in n:
		coil.rod(points[k], points[k + 1], 0.0015, 5, Color.WHITE)
	var spiral := MeshInstance3D.new()
	spiral.mesh = coil.commit(brass)
	_head.add_child(spiral)
	_bar(_head, points[0], Vector3(SHAFT_POST_X, SPIRAL_Y, 0), 0.0025, brass)
	var collar := CylinderMesh.new()
	collar.top_radius = 0.009
	collar.bottom_radius = 0.009
	collar.height = 0.008
	collar.material = brass
	var collar_view := MeshInstance3D.new()
	collar_view.mesh = collar
	collar_view.position = Vector3(0, SPIRAL_Y, 0)
	_stone.add_child(collar_view)
	# The earthstone on end, its seeking end up, on the shaft.
	stone_view.transform = Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * 0.55), Vector3(0, STONE_UP - 0.009, 0))
	if closing:
		_bead(foot + Vector3(0, 0.02, 0))


## A bevel gear in `parent`, its axis the parent's y, its teeth toward +y
## round a cone narrowing that way.
func _bevel(parent: Node3D, mat: Material) -> void:
	var cone := CylinderMesh.new()
	cone.top_radius = GEAR - 0.008
	cone.bottom_radius = GEAR + 0.004
	cone.height = 0.012
	cone.radial_segments = 16
	cone.rings = 1
	cone.material = mat
	var cone_view := MeshInstance3D.new()
	cone_view.mesh = cone
	parent.add_child(cone_view)
	var tooth := BoxMesh.new()
	tooth.size = Vector3(0.005, 0.01, 0.01)
	tooth.material = mat
	for k in 14:
		var a := TAU * k / 14.0
		var t := MeshInstance3D.new()
		t.mesh = tooth
		t.transform = Transform3D(Basis(Vector3.UP, a) * Basis(Vector3.RIGHT, -0.785), Vector3(sin(a), 0, cos(a)) * GEAR + Vector3(0, 0.002, 0))
		parent.add_child(t)


## A closing gate wears a red bead.
func _bead(at: Vector3) -> void:
	var bead := SphereMesh.new()
	bead.radius = 0.02
	bead.height = 0.04
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.12, 0.1)
	bead.material = red
	_add(bead, at)


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	_head.add_child(m)
	return m


## A round brass bar from `a` to `b` in `parent`'s frame.
func _bar(parent: Node3D, a: Vector3, b: Vector3, r: float, mat: Material) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	c.rings = 1
	c.material = mat
	var m := MeshInstance3D.new()
	m.mesh = c
	m.transform = Transform3D(CozyMesh.aligned((b - a).normalized()), (a + b) * 0.5)
	parent.add_child(m)


## A crank on an axle at the side: hub, arm toward -z at a turn of 0, pin.
func _crank(parent: Node3D, mat: Material) -> void:
	var hub := CylinderMesh.new()
	hub.top_radius = 0.014
	hub.bottom_radius = 0.014
	hub.height = 0.012
	hub.material = mat
	var hub_view := MeshInstance3D.new()
	hub_view.mesh = hub
	hub_view.position = Vector3(SIDE, 0, 0)
	hub_view.rotation.z = PI * 0.5
	parent.add_child(hub_view)
	var arm := BoxMesh.new()
	arm.size = Vector3(0.008, 0.016, CRANK + 0.016)
	arm.material = mat
	var arm_view := MeshInstance3D.new()
	arm_view.mesh = arm
	arm_view.position = Vector3(SIDE + 0.01, 0, -CRANK * 0.5)
	parent.add_child(arm_view)
	_bar(parent, Vector3(SIDE + 0.006, 0, -CRANK), Vector3(SIDE + 0.03, 0, -CRANK), 0.004, mat)


## Its ring and its sensor on collision layer `layer` (0: struck by
## nothing).
func set_layer(layer: int) -> void:
	collision_layer = layer
	sensor.collision_layer = layer


## The watts of light on its stone this step.
func sense(watts: float) -> void:
	_watts = watts
	lit = watts > 0.0


## The stone turned by the light against the spring, between its pegs; the
## leaf and linkage with it; open by where the leaf stands.
func _physics_process(delta: float) -> void:
	var frame := _head.global_basis
	var h := delta / STEPS
	for k in STEPS:
		var twist: float
		if by_spin:
			var lined := maxf(frame.y.normalized().dot(Vector3.UP), 0.0)
			twist = Photogyrite.spin(_watts, lined, _rate, 0.0) - (SPIN_PRELOAD + SPIN_SPRING * _turn)
		else:
			var seeking := frame * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
			twist = Photogyrite.pull(_watts, 0.0) * seeking.cross(Vector3.UP).dot(frame.x.normalized()) - (PRELOAD + SPRING * _turn)
		_rate += (twist - PIVOT * _rate) / INERTIA * h
		_turn += _rate * h
		if _turn < 0.0:
			_turn = 0.0
			_rate = -_rate * BOUNCE if _rate < 0.0 else _rate
		elif _turn > PI * 0.5:
			_turn = PI * 0.5
			_rate = -_rate * BOUNCE if _rate > 0.0 else _rate
	open = _turn < CLEAR if closing else _turn > PI * 0.5 - CLEAR
	_place()


func _place() -> void:
	_leaf.rotation.x = _turn + (PI * 0.5 if closing else 0.0)
	if by_spin:
		_stone.rotation.y = _turn
	else:
		_stone.rotation.x = _turn
		_low_crank.rotation.x = _turn
		# The rod between the two crank pins, both a crank's reach from
		# their axles at the same turn.
		var pin := Vector3(0, sin(_turn), -cos(_turn)) * CRANK
		_rod.position = Vector3(SIDE + 0.02, STONE_UP * 0.5, 0) + pin
	_stone_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(_turn / (PI * 0.5), 0.0, 1.0)


## What a right click on it reads: its name, then what it does.
func inspect_text() -> String:
	return _label.text


func relabel(text: String) -> void:
	_label.text = text


func aim(y: float, p: float) -> void:
	yaw = y
	pitch = clampf(p, -1.5, 1.5)
	_head.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	_shape.transform = _head.transform


## The ring facing along `dir` (world).
func aim_along(dir: Vector3) -> void:
	var local := global_transform.basis.inverse() * dir.normalized()
	aim(atan2(-local.x, -local.z), asin(clampf(local.y, -1.0, 1.0)))


## Where its stone is.
func sensor_point() -> Vector3:
	return _head.to_global(_stone_at)
