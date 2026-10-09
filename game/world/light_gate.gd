class_name LightGate
extends StaticBody3D
## A gate a beam passes through, worked by light (Workshop, BenchLight):
## a brass ring with a round leaf in it that turns on a spindle, edge-on
## to let a beam through the ring or square across it to stop one, and
## above the ring a small glass bulb with vanes, its sensor. An opening
## gate stands open while any lit beam strikes its sensor; a closing gate
## (`closing`) stands shut while one does. It changes at once.
##
## Beams are told apart by what they strike: the ring's plate (this
## body) is the way through; the bulb is a body of its own (`sensor`,
## carrying meta "part_of" back to the gate). The ring faces along its
## head's -z, turned by `aim` as a glass is.

var closing := false
var open := false
var yaw := 0.0
var pitch := 0.0
var lit := false                        # light on its sensor
var sensor := StaticBody3D.new()

var _head := Node3D.new()
var _leaf := Node3D.new()
var _vanes := Node3D.new()
var _shape := CollisionShape3D.new()
var _bulb_glow: StandardMaterial3D
var _label: Label3D
var _spin := 0.0


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
	# The spindle across the ring, upright, and the leaf on it.
	var spindle := CylinderMesh.new()
	spindle.top_radius = 0.008
	spindle.bottom_radius = 0.008
	spindle.height = 0.25
	spindle.material = brass
	_add(spindle, Vector3.ZERO)
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
	# The sensor on its arm above the ring.
	var arm := CylinderMesh.new()
	arm.top_radius = 0.01
	arm.bottom_radius = 0.012
	arm.height = 0.08
	arm.material = brass
	_add(arm, Vector3(0, 0.175, 0))
	var bulb := SphereMesh.new()
	bulb.radius = 0.055
	bulb.height = 0.11
	bulb.radial_segments = 16
	bulb.rings = 8
	_bulb_glow = StandardMaterial3D.new()
	_bulb_glow.albedo_color = Color(0.85, 0.95, 1.0, 0.25)
	_bulb_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_bulb_glow.roughness = 0.05
	_bulb_glow.emission_enabled = true
	_bulb_glow.emission = Color(1.0, 0.72, 0.25)
	_bulb_glow.emission_energy_multiplier = 0.0
	bulb.material = _bulb_glow
	_add(bulb, Vector3(0, 0.27, 0))
	_vanes.position = Vector3(0, 0.27, 0)
	_head.add_child(_vanes)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.02, 0.02)
	for k in 4:
		var vane := MeshInstance3D.new()
		var plate := BoxMesh.new()
		plate.size = Vector3(0.028, 0.028, 0.003)
		plate.material = black
		vane.mesh = plate
		vane.position = Vector3(cos(TAU * k / 4.0), 0, sin(TAU * k / 4.0)) * 0.03
		vane.rotation.y = -TAU * k / 4.0
		_vanes.add_child(vane)
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
	ball.radius = 0.075
	catch.shape = ball
	catch.position = Vector3(0, 0.27, 0)
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


## Light on the sensor this step, and the gate set at once.
func sense(on: bool) -> void:
	lit = on
	var now := on != closing
	if now != open:
		open = now
		_show()


func _show() -> void:
	_leaf.rotation.y = PI * 0.5 if open else 0.0
	_bulb_glow.emission_energy_multiplier = 1.5 if lit else 0.0


func _process(delta: float) -> void:
	_spin = move_toward(_spin, 1.0 if lit else 0.0, delta * 3.0)
	_vanes.rotation.y += _spin * 14.0 * delta
	_bulb_glow.emission_energy_multiplier = 1.5 * _spin


func show_label(on: bool) -> void:
	_label.visible = on


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


## Where its sensor is.
func sensor_point() -> Vector3:
	return _head.to_global(Vector3(0, 0.27, 0))
