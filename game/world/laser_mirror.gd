class_name LaserMirror
extends Node3D
## A round mirror 25 cm across on a slim post, its centre at the beam's
## height, turning about the post. The player turns it with E held while
## looking at it, the other way with Shift and E, at TURN_RATE. Its
## front faces local +Z; `face` is that direction in the world.
##
## The glass is a flat disc of silver in a black holder, drawn with the
## engine's standard material (fully metallic, almost smooth), so what it
## shows of the room comes from the room's reflection probe and from
## screen-space reflections.

const GLASS_R := 0.125
const HOLDER_R := 0.135
const THICK := 0.02
const TURN_RATE := 6.0                  # degrees a second while E is held

var head: StaticBody3D                  # the disc: the beam reflects off its front
var _turning := 0.0                     # +1 or -1 while E is held after a use


func _init(height: float, holder: Material, glass: Material, post: Material) -> void:
	set_meta("view", self)
	head = StaticBody3D.new()
	head.position.y = height
	head.set_meta("view", self)
	head.set_meta("mirror", self)
	add_child(head)
	var rim := CylinderMesh.new()
	rim.top_radius = HOLDER_R
	rim.bottom_radius = HOLDER_R
	rim.height = THICK
	rim.radial_segments = 48
	rim.material = holder
	var rim_view := MeshInstance3D.new()
	rim_view.mesh = rim
	rim_view.rotation_degrees.x = 90.0
	head.add_child(rim_view)
	var disc := CylinderMesh.new()
	disc.top_radius = GLASS_R
	disc.bottom_radius = GLASS_R
	disc.height = 0.002
	disc.radial_segments = 48
	disc.material = glass
	var disc_view := MeshInstance3D.new()
	disc_view.mesh = disc
	disc_view.rotation_degrees.x = 90.0
	disc_view.position.z = THICK * 0.5 + 0.001
	head.add_child(disc_view)
	var shape := CylinderShape3D.new()
	shape.radius = HOLDER_R
	shape.height = THICK + 0.004
	var collide := CollisionShape3D.new()
	collide.shape = shape
	collide.rotation_degrees.x = 90.0
	collide.position.z = 0.002
	head.add_child(collide)

	# The post from a round foot to the holder's lower edge.
	var stand := StaticBody3D.new()
	stand.set_meta("view", self)
	add_child(stand)
	var top := height - HOLDER_R
	var rod := CylinderMesh.new()
	rod.top_radius = 0.012
	rod.bottom_radius = 0.012
	rod.height = top
	rod.material = post
	var rod_view := MeshInstance3D.new()
	rod_view.mesh = rod
	rod_view.position.y = top * 0.5
	stand.add_child(rod_view)
	var foot := CylinderMesh.new()
	foot.top_radius = 0.11
	foot.bottom_radius = 0.12
	foot.height = 0.03
	foot.material = post
	var foot_view := MeshInstance3D.new()
	foot_view.mesh = foot
	foot_view.position.y = 0.015
	stand.add_child(foot_view)
	var rod_shape := CylinderShape3D.new()
	rod_shape.radius = 0.06
	rod_shape.height = top
	var rod_collide := CollisionShape3D.new()
	rod_collide.shape = rod_shape
	rod_collide.position.y = top * 0.5
	stand.add_child(rod_collide)


## The disc's centre in the world.
func centre() -> Vector3:
	return head.global_position


## The direction the glass faces in the world.
func face() -> Vector3:
	return global_basis.z.normalized()


## Turn so the glass faces `normal`, kept level.
func aim(normal: Vector3) -> void:
	rotation.y = atan2(normal.x, normal.z)


func use() -> void:
	_turning = -1.0 if Input.is_action_pressed("run") else 1.0


func _process(delta: float) -> void:
	if _turning == 0.0:
		return
	if not Input.is_action_pressed("interact"):
		_turning = 0.0
		return
	rotation.y += deg_to_rad(TURN_RATE) * _turning * delta
