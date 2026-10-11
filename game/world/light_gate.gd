class_name LightGate
extends StaticBody3D
## A gate a beam passes through, worked by light (Workshop, BenchLight):
## a brass ring with a round leaf in it on a spindle across it, square
## across the ring to stop a beam or turned edge-on to let it through;
## and above the ring's middle, on its own axle parallel to the spindle
## (carried on a post beside the ring), a small earthstone held lying
## level by a coiled spring, its seeking end
## toward the ring's front. A crank on each axle and a rod between them
## make the two turn together. Light on the stone draws its seeking end
## up toward the sky against the spring, a quarter turn, and the leaf
## turns with it: an opening gate's leaf, square at rest, goes edge-on and
## lets the beam through; a closing gate's, set a quarter turn round,
## goes square and stops it. When the light leaves, the spring swings the
## stone back level. The gate is open or shut at once with the light; the
## stone's swing (SWING) is how it shows.
##
## Beams are told apart by what they strike: the ring's plate (this
## body) is the way through; the stone is a body of its own (`sensor`,
## carrying meta "part_of" back to the gate). The ring faces along its
## head's -z, turned by `aim` as a glass is.

const STONE_UP := 0.27                  # m: the stone's axle over the ring's middle
const CRANK := 0.05                     # m: each crank's reach
const SIDE := 0.17                      # m: the cranks, out to the side of the ring
const SWING := 10.0                     # a quarter turn's share a second: the stone's swing, either way

var closing := false
var open := false
var yaw := 0.0
var pitch := 0.0
var lit := false                        # light on its stone
var sensor := StaticBody3D.new()

var _head := Node3D.new()
var _leaf := Node3D.new()
var _stone := Node3D.new()
var _rod: MeshInstance3D
var _shape := CollisionShape3D.new()
var _stone_glow: StandardMaterial3D
var _label: Label3D
var _swing := 0.0                       # 0 the stone level, 1 a quarter turn up


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
	# The leaf's spindle across the ring, side to side, out to its crank.
	var spindle := CylinderMesh.new()
	spindle.top_radius = 0.007
	spindle.bottom_radius = 0.007
	spindle.height = SIDE * 2.0
	spindle.material = brass
	_add(spindle, Vector3(SIDE * 0.5 - 0.0, 0, 0)).rotation.z = PI * 0.5
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
	# The post up from the ring to the stone's axle, and the axle.
	var post := CylinderMesh.new()
	post.top_radius = 0.009
	post.bottom_radius = 0.011
	post.height = STONE_UP - 0.1
	post.material = brass
	_add(post, Vector3(-0.11, 0.1 + (STONE_UP - 0.1) * 0.5, 0))
	var axle := CylinderMesh.new()
	axle.top_radius = 0.006
	axle.bottom_radius = 0.006
	axle.height = SIDE + 0.11
	axle.material = brass
	_add(axle, Vector3((SIDE - 0.11) * 0.5, STONE_UP, 0)).rotation.z = PI * 0.5
	# The spring: a coil round the stone's axle beside the post.
	for k in 5:
		var turn := TorusMesh.new()
		turn.inner_radius = 0.012
		turn.outer_radius = 0.018
		turn.rings = 10
		turn.ring_segments = 6
		turn.material = brass
		_add(turn, Vector3(-0.1 + k * 0.009, STONE_UP, 0)).rotation.z = PI * 0.5
	# The cranks, one on each axle at the side, and the rod between them.
	for y: float in [0.0, STONE_UP]:
		var hub := CylinderMesh.new()
		hub.top_radius = 0.014
		hub.bottom_radius = 0.014
		hub.height = 0.012
		hub.material = brass
		_add(hub, Vector3(SIDE, y, 0)).rotation.z = PI * 0.5
	var rod := CylinderMesh.new()
	rod.top_radius = 0.005
	rod.bottom_radius = 0.005
	rod.height = STONE_UP
	rod.material = brass
	_rod = _add(rod, Vector3(SIDE + 0.008, STONE_UP * 0.5, 0))
	# The stone on its axle, its seeking end toward the ring's front at rest.
	_stone.position = Vector3(0, STONE_UP, 0)
	_head.add_child(_stone)
	_stone_glow = StandardMaterial3D.new()
	_stone_glow.albedo_color = Color(0.74, 0.62, 0.95, 0.9)
	_stone_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stone_glow.roughness = 0.08
	_stone_glow.metallic_specular = 0.9
	_stone_glow.emission_enabled = true
	_stone_glow.emission = Color(0.5, 0.36, 0.85)
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
		# A closing gate wears a red bead on its arm.
		var bead := SphereMesh.new()
		bead.radius = 0.02
		bead.height = 0.04
		var red := StandardMaterial3D.new()
		red.albedo_color = Color(0.8, 0.12, 0.1)
		bead.material = red
		_add(bead, Vector3(0, 0.15, 0))
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
	_show()


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	_head.add_child(m)
	return m


## Its ring and its sensor on collision layer `layer` (0: struck by
## nothing).
func set_layer(layer: int) -> void:
	collision_layer = layer
	sensor.collision_layer = layer


## Light on the stone this step, and the gate set at once.
func sense(on: bool) -> void:
	lit = on
	var now := on != closing
	if now != open:
		open = now
		_show()


func _show() -> void:
	_stone_glow.emission_energy_multiplier = 0.1 + 0.9 * _swing


## The stone swung up while lit, the spring bringing it back; the leaf
## and the crank rod with it.
func _process(delta: float) -> void:
	_swing = move_toward(_swing, 1.0 if lit else 0.0, delta * SWING)
	var turn := _swing * PI * 0.5
	_stone.rotation.x = turn
	_leaf.rotation.x = turn + (PI * 0.5 if closing else 0.0)
	# The rod between the two crank pins, both a crank's reach from their
	# axles at the same turn.
	var pin := Vector3(0, sin(turn), -cos(turn)) * CRANK
	_rod.position = Vector3(SIDE + 0.008, STONE_UP * 0.5, 0) + pin
	_show()


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
