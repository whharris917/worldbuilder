class_name LightGate
extends StaticBody3D
## A gate a beam passes through, worked by light (Workshop, BenchLight):
## a brass ring with a round leaf in it on a spindle across it, square
## across the ring to stop a beam or turned edge-on to let it through;
## and above the ring's middle, on its own axle parallel to the spindle
## (carried on a post beside the ring), a small geotrope pivoted at its
## middle, its seeking end toward the ring's front.
##
## The linkage: a crank arm on each axle at the side, the same length and
## pointing the same way, a pin at each arm's end and a rod hung between
## the pins, so the two axles always stand at the same turn. The spring: a
## coil round the stone's axle, one end hooked into a round plate fixed on
## the post, the other into a collar on the axle, wound so it presses the
## stone's seeking end down. Two pegs in the plate stop an arm on the
## collar: at rest the spring holds the stone against the lower peg, its
## seeking end REST below level; at the upper peg the stone stands OPEN
## above level, a quarter turn from rest.
##
## Light on the stone (watts, from BenchLight each step) pulls its seeking
## end toward the upright by the geotrope's law (Photogyrite, purity 0,
## by the axle's own direction in the world), against the spring's push
## (PRELOAD at rest, rising by SPRING with the turn) and the pivots' drag;
## the stone, the cranks and the leaf turn as one (INERTIA), stepped each
## physics frame. Too little light leaves it on its lower peg; a little
## more swings it part way, to where pull and spring balance; enough holds
## it on the upper peg. The leaf lets a beam by while within CLEAR of
## edge-on: an opening gate's leaf is square at rest and edge-on at the
## upper peg; a closing gate's is set a quarter turn round.
##
## Beams are told apart by what they strike: the ring's plate (this
## body) is the way through; the stone is a body of its own (`sensor`,
## carrying meta "part_of" back to the gate). The ring faces along its
## head's -z, turned by `aim` as a glass is.

const STONE_UP := 0.27                  # m: the stone's axle over the ring's middle
const CRANK := 0.05                     # m: each crank's reach
const SIDE := 0.17                      # m: the cranks, out to the side of the ring
const POST_X := -0.11                   # m: the post carrying the stone's axle
const REST := -0.2618                   # rad: the seeking end's turn at rest, 15 degrees below level
const OPEN := 1.309                     # rad: and on the upper peg, 75 degrees above
const INERTIA := 2.4e-4                 # kg m²: the stone, cranks, rod and leaf about their axles
const PRELOAD := 0.0145                 # N m: the spring's push at rest, which 3 W on the stone overcomes
const SPRING := 0.003                   # N m per radian of turn from rest
const PIVOT := 2.5e-3                   # N m s: the pivots' drag
const BOUNCE := 0.2                     # how much of its speed the arm keeps off a peg
const CLEAR := 0.5236                   # rad: a leaf this near edge-on lets a beam by
const STEPS := 4                        # steps a physics frame

var closing := false
var open := false
var yaw := 0.0
var pitch := 0.0
var lit := false                        # light on its stone
var sensor := StaticBody3D.new()

var _head := Node3D.new()
var _leaf := Node3D.new()
var _low_crank := Node3D.new()
var _stone := Node3D.new()
var _rod: MeshInstance3D
var _shape := CollisionShape3D.new()
var _stone_glow: StandardMaterial3D
var _label: Label3D
var _turn := REST                       # rad: the seeking end above level
var _rate := 0.0                        # rad/s
var _watts := 0.0


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, is_closing: bool) -> void:
	closing = is_closing
	open = closing
	name = "ClosingGate" if closing else "OpeningGate"
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
	# The leaf's spindle across the ring, in bearings at either side of it,
	# and out to its crank.
	_bar(_head, Vector3(-0.14, 0, 0), Vector3(SIDE + 0.006, 0, 0), 0.007, brass)
	_head.add_child(_leaf)
	var leaf := CylinderMesh.new()
	leaf.top_radius = 0.11
	leaf.bottom_radius = 0.11
	leaf.height = 0.012
	leaf.radial_segments = 24
	leaf.rings = 1
	leaf.material = leaf_metal
	var leaf_view := MeshInstance3D.new()
	leaf_view.mesh = leaf
	leaf_view.rotation.x = PI * 0.5
	_leaf.add_child(leaf_view)
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
	for a: float in [REST - 0.17, OPEN + 0.17]:
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
	_head.add_child(_stone)
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
	_low_crank.position = Vector3.ZERO
	_head.add_child(_low_crank)
	_crank(_low_crank, brass)
	# The rod between the two crank pins.
	var rod := CylinderMesh.new()
	rod.top_radius = 0.005
	rod.bottom_radius = 0.005
	rod.height = STONE_UP
	rod.material = brass
	_rod = _add(rod, Vector3(SIDE + 0.02, STONE_UP * 0.5, 0))
	# The stone, its seeking end toward the ring's front at a turn of 0.
	_stone_glow = StandardMaterial3D.new()
	_stone_glow.albedo_color = Color(0.5, 0.8, 0.48, 0.9)
	_stone_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stone_glow.roughness = 0.08
	_stone_glow.metallic_specular = 0.9
	_stone_glow.emission_enabled = true
	_stone_glow.emission = Color(0.24, 0.62, 0.26)
	_stone_glow.emission_energy_multiplier = 0.1
	var grown := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 909
	LumenPart.grow_spinstone(grown, rng)
	var stone_view := MeshInstance3D.new()
	stone_view.mesh = grown.commit(_stone_glow)
	# Grown upright (+y its seeking end), laid toward -z, made smaller.
	stone_view.transform = Transform3D(Basis(Vector3.RIGHT, -PI * 0.5).scaled(Vector3.ONE * 0.55), Vector3(0, 0, -0.01))
	_stone.add_child(stone_view)
	if closing:
		# A closing gate wears a red bead on its post.
		var bead := SphereMesh.new()
		bead.radius = 0.02
		bead.height = 0.04
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.8, 0.12, 0.1)
		bead.material = red
		_add(bead, Vector3(POST_X, 0.08, 0))
	# The way through the ring.
	var plate_shape := BoxShape3D.new()
	plate_shape.size = Vector3(0.26, 0.26, 0.03)
	_shape.shape = plate_shape
	add_child(_shape)
	# The sensor's own body.
	sensor.set_meta("part_of", self)
	sensor.set_meta("view", self)
	var catch := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = 0.08
	catch.shape = ball
	catch.position = Vector3(0, STONE_UP, 0)
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


## The stone swung by the light against the spring, between its pegs; the
## leaf, cranks and rod with it; open by where the leaf stands.
func _physics_process(delta: float) -> void:
	var axle := _head.global_basis.x.normalized()
	var pull := Photogyrite.pull(_watts, 0.0)
	var h := delta / STEPS
	for k in STEPS:
		var seeking := _head.global_basis * (Basis(Vector3.RIGHT, _turn) * Vector3.FORWARD)
		var twist := pull * seeking.cross(Vector3.UP).dot(axle) - (PRELOAD + SPRING * (_turn - REST)) - PIVOT * _rate
		_rate += twist / INERTIA * h
		_turn += _rate * h
		if _turn < REST:
			_turn = REST
			_rate = -_rate * BOUNCE if _rate < 0.0 else _rate
		elif _turn > OPEN:
			_turn = OPEN
			_rate = -_rate * BOUNCE if _rate > 0.0 else _rate
	var swung := _turn - REST
	open = swung < CLEAR if closing else swung > PI * 0.5 - CLEAR
	_place()


func _place() -> void:
	var swung := _turn - REST
	_stone.rotation.x = _turn
	_low_crank.rotation.x = _turn
	_leaf.rotation.x = swung + (PI * 0.5 if closing else 0.0)
	# The rod between the two crank pins, both a crank's reach from their
	# axles at the same turn.
	var pin := Vector3(0, sin(_turn), -cos(_turn)) * CRANK
	_rod.position = Vector3(SIDE + 0.02, STONE_UP * 0.5, 0) + pin
	_stone_glow.emission_energy_multiplier = 0.1 + 0.9 * clampf(swung / (PI * 0.5), 0.0, 1.0)


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
	return _head.to_global(Vector3(0, STONE_UP, 0))
