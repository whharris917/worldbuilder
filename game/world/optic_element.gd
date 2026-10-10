class_name OpticElement
extends StaticBody3D
## A piece of glass or silver on a post that a beam passes by, aimed by
## the player as an aimed lumen part is (hold E, move the mouse):
## - MIRROR: a silvered disc. A beam striking its face is turned off it,
##   angle in equal to angle out, losing a tenth of its reach; its back
##   stops a beam.
## - SPLITTER: a half-silvered glass plate. A beam striking either face
##   goes on through and is turned off it, each part with half its reach.
## - LENS: a burning glass. A beam passing through it along its axis
##   (within sixty degrees) leaves focused, its remaining reach doubled.
## Its plate faces along its head's -z (`normal`).

enum Kind { MIRROR, SPLITTER, LENS }

var kind: Kind
var title := ""
var yaw := 0.0
var pitch := 0.0
var _head := Node3D.new()
var _shape := CollisionShape3D.new()
var _label: Label3D


func _init(element_kind: Kind, at: Vector3, ground: float, wood: Material, frame: Material,
		silver: Material, glass: Material, with_post := true) -> void:
	kind = element_kind
	title = ["mirror", "splitter", "lens"][kind]
	name = Kind.keys()[kind].capitalize()
	position = at
	set_meta("view", self)
	_head.set_meta(StaticMerge.MOVES, true)
	add_child(_head)
	if with_post:
		var post := CylinderMesh.new()
		post.top_radius = 0.04
		post.bottom_radius = 0.055
		post.height = maxf(at.y - ground - 0.22, 0.1)
		post.material = wood
		var post_view := MeshInstance3D.new()
		post_view.mesh = post
		post_view.position.y = -0.22 - post.height * 0.5
		add_child(post_view)
	# A fork on the post holding the plate, which turns in it.
	var fork := TorusMesh.new()
	fork.inner_radius = 0.2
	fork.outer_radius = 0.225
	fork.rings = 24
	fork.ring_segments = 6
	fork.material = frame
	var fork_view := MeshInstance3D.new()
	fork_view.mesh = fork
	fork_view.rotation.x = PI * 0.5
	_head.add_child(fork_view)
	var plate := CylinderMesh.new()
	plate.top_radius = 0.19
	plate.bottom_radius = 0.19
	plate.radial_segments = 24
	plate.rings = 1
	match kind:
		Kind.MIRROR:
			plate.height = 0.02
			plate.material = silver
		Kind.SPLITTER:
			plate.height = 0.012
			var half := StandardMaterial3D.new()
			half.albedo_color = Color(0.82, 0.86, 0.95, 0.45)
			half.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			half.metallic = 0.8
			half.roughness = 0.08
			plate.material = half
		Kind.LENS:
			plate.height = 0.05
			plate.material = glass
	var plate_view := MeshInstance3D.new()
	plate_view.mesh = plate
	plate_view.rotation.x = PI * 0.5
	_head.add_child(plate_view)
	if kind == Kind.LENS:
		for side: float in [-1.0, 1.0]:
			var bulge := SphereMesh.new()
			bulge.radius = 0.19
			bulge.height = 0.06
			bulge.is_hemisphere = true
			bulge.material = glass
			var b := MeshInstance3D.new()
			b.mesh = bulge
			b.rotation.x = -PI * 0.5 * side
			b.position.z = 0.0
			_head.add_child(b)
	if kind == Kind.MIRROR:
		# Its back, plain brass, so its silvered face can be told.
		var back := CylinderMesh.new()
		back.top_radius = 0.19
		back.bottom_radius = 0.19
		back.height = 0.01
		back.material = frame
		var bv := MeshInstance3D.new()
		bv.mesh = back
		bv.rotation.x = PI * 0.5
		bv.position.z = 0.016
		_head.add_child(bv)
	var box := BoxShape3D.new()
	box.size = Vector3(0.4, 0.4, 0.06)
	_shape.shape = box
	add_child(_shape)
	_label = Label3D.new()
	_label.text = describe()
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


## What a player looking at it is told. Drafts.
func describe() -> String:
	var how := "\nHold E and move the mouse to aim it."
	match kind:
		Kind.MIRROR:
			return "Mirror\nTurns a beam off its silvered face; a little of the beam's reach is lost." + how
		Kind.SPLITTER:
			return "Splitter\nHalf-silvered glass: a beam goes on through and is turned aside as well, each with half its reach." + how
		_:
			return "Lens\nA beam passing through it leaves focused, reaching twice as far again." + how


## What a right click on it reads: its name, then what it does.
func inspect_text() -> String:
	return _label.text


## Its label made to read `text` in place of its own description.
func relabel(text: String) -> void:
	_label.text = text


func aim(y: float, p: float) -> void:
	yaw = y
	pitch = clampf(p, -1.5, 1.5)
	_head.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))
	_shape.transform = _head.transform


func turn_by(motion: Vector2) -> void:
	aim(yaw - motion.x * 0.004, pitch - motion.y * 0.004)


## The plate facing along `dir` (world).
func aim_along(dir: Vector3) -> void:
	var local := global_transform.basis.inverse() * dir.normalized()
	aim(atan2(-local.x, -local.z), asin(clampf(local.y, -1.0, 1.0)))


## Which way its face looks.
func normal() -> Vector3:
	return -(_head.global_transform.basis.z).normalized()
