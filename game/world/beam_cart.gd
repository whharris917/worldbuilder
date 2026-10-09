class_name BeamCart
extends StaticBody3D
## A straight track LENGTH metres long on wooden sleepers, with a small
## cart on it that push and pull beams move (Workshop, BenchLight). The
## cart carries a pole with a copper ball on top, its handle (`sensor`,
## a body of its own carrying meta "part_of" back to the cart): a push
## beam striking the handle drives the cart along the track away from
## the beam's source, a pull beam toward it, each by as much of the beam
## as runs along the track (none across it). The cart rolls, slowing by
## itself (DRAG), and stops dead at the buffers at the track's ends.
##
## Its frame: the origin at the middle of the track on the ground, the
## track along x; it is turned about the upright by `aim`, as a piece.

const LENGTH := 4.0
const HANDLE := 1.1                     # the handle's height over the ground
const ACCEL := 1.2                      # m/s² for a beam running straight along the track
const DRAG := 1.2                       # how fast it slows, per second
const STOP := 0.35                      # the cart's middle kept this far from a track end

var yaw := 0.0
var pitch := 0.0
var along := 0.0                        # the cart's place on the track, m from its middle
var speed := 0.0
var sensor := StaticBody3D.new()

var _cart := Node3D.new()
var _wheels: Array[MeshInstance3D] = []
var _label: Label3D


func _init(at: Vector3, wood: Material, timber: Material, brass: Material, copper: Material) -> void:
	name = "BeamCart"
	position = at
	set_meta("view", self)
	var half := LENGTH * 0.5
	# Sleepers and rails.
	var n := int(LENGTH / 0.5) + 1
	for k in n:
		var sleeper := BoxMesh.new()
		sleeper.size = Vector3(0.12, 0.05, 0.5)
		sleeper.material = timber
		_add(sleeper, Vector3(-half + k * LENGTH / (n - 1), 0.025, 0), self)
	for side: float in [-0.15, 0.15]:
		var rail := BoxMesh.new()
		rail.size = Vector3(LENGTH, 0.04, 0.03)
		rail.material = brass
		_add(rail, Vector3(0, 0.07, side), self)
	for end: float in [-1.0, 1.0]:
		var buffer := BoxMesh.new()
		buffer.size = Vector3(0.08, 0.16, 0.42)
		buffer.material = timber
		_add(buffer, Vector3(end * (half - 0.04), 0.13, 0), self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH, 0.2, 0.5)
	shape.shape = box
	shape.position.y = 0.1
	add_child(shape)
	# The cart, its wheels on the rails, its pole and handle.
	add_child(_cart)
	var bed := BoxMesh.new()
	bed.size = Vector3(0.5, 0.06, 0.4)
	bed.material = wood
	_add(bed, Vector3(0, 0.16, 0), _cart)
	for u: float in [-0.16, 0.16]:
		for v: float in [-0.15, 0.15]:
			var wheel := CylinderMesh.new()
			wheel.top_radius = 0.045
			wheel.bottom_radius = 0.045
			wheel.height = 0.03
			wheel.radial_segments = 12
			wheel.rings = 1
			wheel.material = brass
			var w := _add(wheel, Vector3(u, 0.135, v), _cart)
			w.rotation.x = PI * 0.5
			_wheels.append(w)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.024
	pole.height = HANDLE - 0.19
	pole.material = brass
	_add(pole, Vector3(0, 0.19 + pole.height * 0.5, 0), _cart)
	var ball := SphereMesh.new()
	ball.radius = 0.1
	ball.height = 0.2
	ball.radial_segments = 16
	ball.rings = 8
	ball.material = copper
	_add(ball, Vector3(0, HANDLE, 0), _cart)
	var band := TorusMesh.new()
	band.inner_radius = 0.095
	band.outer_radius = 0.115
	band.rings = 20
	band.ring_segments = 6
	band.material = brass
	_add(band, Vector3(0, HANDLE, 0), _cart)
	sensor.set_meta("part_of", self)
	sensor.set_meta("view", self)
	var catch := CollisionShape3D.new()
	var ball_shape := SphereShape3D.new()
	ball_shape.radius = 0.13
	catch.shape = ball_shape
	catch.position.y = HANDLE
	sensor.add_child(catch)
	_cart.add_child(sensor)
	_label = Label3D.new()
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = HANDLE + 0.3
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	_cart.add_child(_label)
	set_layer(4)


func _add(mesh: Mesh, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	parent.add_child(m)
	return m


## Its track and its handle on collision layer `layer` (0: struck by
## nothing).
func set_layer(layer: int) -> void:
	collision_layer = layer
	sensor.collision_layer = layer


## The track turned to `y` about the upright; it stays level.
func aim(y: float, _p: float) -> void:
	yaw = y
	rotation.y = y


## Which way along the track is forward.
func axis() -> Vector3:
	return global_basis.x.normalized()


## Where the handle is.
func sensor_point() -> Vector3:
	return _cart.to_global(Vector3(0, HANDLE, 0))


## The cart at `at` metres along the track, standing.
func place_cart(at: float) -> void:
	along = clampf(at, -LENGTH * 0.5 + STOP, LENGTH * 0.5 - STOP)
	speed = 0.0
	_cart.position.x = along


## One step: `force` is the sum of the beams on the handle, each as much
## of it as runs along the track (+1 forward).
func drive(force: float, dt: float) -> void:
	speed += force * ACCEL * dt
	speed *= exp(-DRAG * dt)
	if is_zero_approx(force) and absf(speed) < 0.01:
		speed = 0.0
	along += speed * dt
	var end := LENGTH * 0.5 - STOP
	if along > end:
		along = end
		speed = minf(speed, 0.0)
	elif along < -end:
		along = -end
		speed = maxf(speed, 0.0)
	_cart.position.x = along
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, -speed * dt / 0.045)


func show_label(on: bool) -> void:
	_label.visible = on


func relabel(text: String) -> void:
	_label.text = text
