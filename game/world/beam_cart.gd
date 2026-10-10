class_name BeamCart
extends StaticBody3D
## A straight track LENGTH metres long on wooden sleepers, its brass rails
## laid in lengths of RAIL with a joint between, and a small cart on four
## flanged wheels on it that push and pull beams move (Workshop,
## BenchLight). The cart carries a pole with a copper ball on top, its
## handle (`sensor`, a body of its own carrying meta "part_of" back to the
## cart): a push beam striking the handle drives the cart along the track
## away from the beam's source, a pull beam toward it, each by as much of
## the beam as runs along the track (none across it).
##
## The motion is Newton's with a drag in proportion to the speed: a beam
## straight along the track gives ACCEL; the speed falls by DRAG of
## itself each second, so one beam carries the cart to ACCEL / DRAG at
## most. It stops dead at the buffers at the track's ends.
##
## Sound from the cart's own motion: the wheels' roll, louder and higher
## the faster it goes; a clack as each axle crosses a rail joint; a knock
## at a buffer, as hard as it struck.
##
## Its frame: the origin at the middle of the track on the ground, the
## track along x; it is turned about the upright by `aim`, as a piece.

const LENGTH := 16.0
const RAIL := 2.0                       # a rail's length between joints
const HANDLE := 1.1                     # the handle's height over the ground
const ACCEL := 2.0                      # m/s² for a beam running straight along the track
const DRAG := 0.25                      # how fast it slows, per second: a top speed of 8 m/s
const STOP := 0.35                      # the cart's middle kept this far from a track end
const WHEEL := 0.07                     # wheel radius
const AXLE := 0.18                      # each axle this far from the cart's middle
const GAUGE := 0.15                     # each rail this far from the track's middle

var yaw := 0.0
var pitch := 0.0
var along := 0.0                        # the cart's place on the track, m from its middle
var speed := 0.0
var sensor := StaticBody3D.new()

var _cart := Node3D.new()
var _wheels: Array[Node3D] = []
var _label: Label3D
var _roll: AudioStreamPlayer3D
var _clacks: Array[AudioStreamPlayer3D] = []
var _buffer: AudioStreamPlayer3D


func _init(at: Vector3, wood: Material, timber: Material, brass: Material, copper: Material) -> void:
	name = "BeamCart"
	position = at
	set_meta("view", self)
	var half := LENGTH * 0.5
	# Sleepers, and rails in lengths with a joint between.
	var n := int(LENGTH / 0.5) + 1
	for k in n:
		var sleeper := BoxMesh.new()
		sleeper.size = Vector3(0.12, 0.05, 0.5)
		sleeper.material = timber
		_add(sleeper, Vector3(-half + k * LENGTH / (n - 1), 0.025, 0), self)
	var lengths := int(LENGTH / RAIL)
	for side: float in [-GAUGE, GAUGE]:
		for k in lengths:
			var rail := BoxMesh.new()
			rail.size = Vector3(RAIL - 0.012, 0.04, 0.03)
			rail.material = brass
			_add(rail, Vector3(-half + (k + 0.5) * RAIL, 0.07, side), self)
	for end: float in [-1.0, 1.0]:
		var buffer := BoxMesh.new()
		buffer.size = Vector3(0.08, 0.2, 0.42)
		buffer.material = timber
		_add(buffer, Vector3(end * (half - 0.04), 0.15, 0), self)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(LENGTH, 0.2, 0.5)
	shape.shape = box
	shape.position.y = 0.1
	add_child(shape)
	# The cart: four flanged wheels on two axles on the rails, the bed over
	# them, the pole and the handle.
	add_child(_cart)
	var rail_top := 0.09
	for u: float in [-AXLE, AXLE]:
		var axle := CylinderMesh.new()
		axle.top_radius = 0.012
		axle.bottom_radius = 0.012
		axle.height = GAUGE * 2.0 + 0.08
		axle.radial_segments = 8
		axle.rings = 1
		axle.material = timber
		_add(axle, Vector3(u, rail_top + WHEEL, 0), _cart).rotation.x = PI * 0.5
		for v: float in [-GAUGE, GAUGE]:
			var wheel := Node3D.new()
			wheel.position = Vector3(u, rail_top + WHEEL, v)
			wheel.rotation.x = PI * 0.5
			_cart.add_child(wheel)
			_wheels.append(wheel)
			var tread := CylinderMesh.new()
			tread.top_radius = WHEEL
			tread.bottom_radius = WHEEL
			tread.height = 0.03
			tread.radial_segments = 16
			tread.rings = 1
			tread.material = brass
			_add(tread, Vector3.ZERO, wheel)
			# The flange, on the inside of the rail.
			var flange := CylinderMesh.new()
			flange.top_radius = WHEEL + 0.015
			flange.bottom_radius = WHEEL + 0.015
			flange.height = 0.008
			flange.radial_segments = 16
			flange.rings = 1
			flange.material = brass
			_add(flange, Vector3(0, -signf(v) * 0.019, 0), wheel)
			# A spoke across, so the turning shows.
			var spoke := BoxMesh.new()
			spoke.size = Vector3(WHEEL * 1.7, 0.034, 0.016)
			spoke.material = timber
			_add(spoke, Vector3.ZERO, wheel)
	var bed_y := rail_top + WHEEL * 2.0 + 0.04
	var bed := BoxMesh.new()
	bed.size = Vector3(0.56, 0.06, 0.42)
	bed.material = wood
	_add(bed, Vector3(0, bed_y, 0), _cart)
	var pole := CylinderMesh.new()
	pole.top_radius = 0.018
	pole.bottom_radius = 0.024
	pole.height = HANDLE - bed_y - 0.03
	pole.material = brass
	_add(pole, Vector3(0, bed_y + 0.03 + pole.height * 0.5, 0), _cart)
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
	_build_sound()
	set_layer(4)


func _add(mesh: Mesh, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	m.mesh = mesh
	m.position = at
	parent.add_child(m)
	return m


## The roll, the clacks and the knock, riding on the cart; none when
## headless (nothing would hear them, and a loop left playing holds its
## file at exit).
func _build_sound() -> void:
	var heard := DisplayServer.get_name() != "headless"
	_roll = AudioStreamPlayer3D.new()
	if heard:
		var loop := load("res://audio/cart_roll_loop.wav") as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_begin = 0
		loop.loop_end = int(loop.get_length() * loop.mix_rate)
		_roll.stream = loop
		_roll.autoplay = true
	_roll.volume_db = -80.0
	_roll.unit_size = 4.0
	_roll.position.y = 0.15
	_cart.add_child(_roll)
	for k in range(1, 4):
		var clack := AudioStreamPlayer3D.new()
		clack.stream = load("res://audio/cart_clack_%d.wav" % k) if heard else null
		clack.unit_size = 5.0
		clack.position.y = 0.1
		_cart.add_child(clack)
		_clacks.append(clack)
	_buffer = AudioStreamPlayer3D.new()
	_buffer.stream = load("res://audio/cart_buffer.wav") if heard else null
	_buffer.unit_size = 7.0
	_buffer.position.y = 0.2
	_cart.add_child(_buffer)


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
	var was := along
	along += speed * dt
	var end := LENGTH * 0.5 - STOP
	var struck := 0.0
	if along > end:
		along = end
		struck = maxf(speed, 0.0)
		speed = minf(speed, 0.0)
	elif along < -end:
		along = -end
		struck = maxf(-speed, 0.0)
		speed = maxf(speed, 0.0)
	_cart.position.x = along
	for w in _wheels:
		w.rotate_object_local(Vector3.UP, -(along - was) / WHEEL)
	_sound(was, struck)


## The roll's loudness and pitch from the speed; a clack for each axle
## crossing a rail joint; a knock for a buffer struck.
func _sound(was: float, struck: float) -> void:
	var pace := absf(speed)
	_roll.volume_db = linear_to_db(clampf(pace / 5.0, 0.0001, 1.0)) - 4.0
	_roll.pitch_scale = 0.7 + clampf(pace / 8.0, 0.0, 1.0) * 0.9
	var half := LENGTH * 0.5
	for axle: float in [-AXLE, AXLE]:
		var a := floorf((was + axle + half) / RAIL)
		var b := floorf((along + axle + half) / RAIL)
		if a != b and pace > 0.15:
			var clack := _clacks[randi() % _clacks.size()]
			if clack.stream != null:
				clack.volume_db = linear_to_db(clampf(pace / 4.0, 0.05, 1.0)) - 2.0
				clack.pitch_scale = randf_range(0.94, 1.06)
				clack.play()
	if struck > 0.2 and _buffer.stream != null:
		_buffer.volume_db = linear_to_db(clampf(struck / 5.0, 0.1, 1.0))
		_buffer.pitch_scale = randf_range(0.95, 1.03)
		_buffer.play()


## What a right click on it reads: its name, then what it does.
func inspect_text() -> String:
	return _label.text


func relabel(text: String) -> void:
	_label.text = text
