class_name LumenPart
extends StaticBody3D
## One part of a light-beam logic circuit, standing on a wooden post:
## a lantern (an input), a crystal or an hourglass (logic), or a
## radiometer (an output). Parts are joined by LumenBeams; each reads the
## beams reaching it and lights its own output.
##
## Kinds, in a PLC programmer's terms:
## - LANTERN: an input contact. A brass lantern whose shutter is open
##   while `condition` holds (set by the machine it watches).
## - AND, OR, NOT: the gates. A crystal shining while all its beams are
##   lit, while any is, or while its beam is dark.
## - LATCH: a set-reset memory. Its first beam lights it, its second puts
##   it out (the second wins); between, it keeps what it was.
## - TON: an on-delay timer, drawn as an hourglass. Its sand runs while
##   its beam is lit and it shines once the sand has run `delay` seconds;
##   the beam going dark turns it back over.
## - TOF: an off-delay timer. A crystal that shines while its beam is
##   lit and keeps glowing `delay` seconds after, fading (an afterglow).
## - RISE, FALL: edge triggers. One flash (PULSE seconds) when the beam
##   comes on, or when it goes dark.
## - RADIOMETER: an output coil. A Crookes radiometer: vanes in a glass
##   bulb that spin in light. `spin` (0 to 1) eases toward lit or not;
##   the machine it drives reads it, or `powered`.
##
## Looking at a part shows its name and what it does (`describe`, a
## hover label).

enum Kind { LANTERN, AND, OR, NOT, LATCH, TON, TOF, RISE, FALL, RADIOMETER }

const PULSE := 0.4
const COLOURS := {
	Kind.LANTERN: Color(1.0, 0.72, 0.3),
	Kind.AND: Color(1.0, 0.8, 0.2),
	Kind.OR: Color(0.3, 0.75, 1.0),
	Kind.NOT: Color(1.0, 0.25, 0.2),
	Kind.LATCH: Color(0.75, 0.35, 1.0),
	Kind.TON: Color(0.45, 1.0, 0.45),
	Kind.TOF: Color(0.2, 1.0, 0.7),
	Kind.RISE: Color(1.0, 1.0, 1.0),
	Kind.FALL: Color(0.85, 0.9, 1.0),
	Kind.RADIOMETER: Color(1.0, 1.0, 1.0),
}

var kind: Kind
var title := ""
var delay := 0.0
var condition := false                  # a lantern's
var out := false
var powered := false                    # a radiometer's: light reaching it
var spin := 0.0                         # a radiometer's vanes, 0 to 1
var inputs: Array[LumenBeam] = []

var _acc := 0.0
var _last_in := false
var _pulse_left := 0.0
var _vane_angle := 0.0
var _glow: StandardMaterial3D
var _shutter: Node3D
var _vanes: Node3D
var _sand_top: MeshInstance3D
var _sand_bottom: MeshInstance3D
var _label: Label3D
var _head := Node3D.new()


## A part of `kind` at `at` (the head's centre), its post down to
## `ground`. `wood` and `brass` are the post's and fittings' materials.
func _init(part_kind: Kind, part_title: String, at: Vector3, ground: float,
		wood: Material, brass: Material, part_delay := 0.0) -> void:
	kind = part_kind
	title = part_title
	delay = part_delay
	name = Kind.keys()[kind].capitalize() + "Part"
	position = at
	set_meta("view", self)
	add_child(_head)
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.06
	post.height = maxf(at.y - ground - 0.12, 0.1)
	post.material = wood
	var post_view := MeshInstance3D.new()
	post_view.mesh = post
	post_view.position.y = -0.12 - post.height * 0.5
	add_child(post_view)
	var cradle := CylinderMesh.new()
	cradle.top_radius = 0.09
	cradle.bottom_radius = 0.06
	cradle.height = 0.06
	cradle.material = brass
	var cradle_view := MeshInstance3D.new()
	cradle_view.mesh = cradle
	cradle_view.position.y = -0.12
	add_child(cradle_view)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.42, 0.36)
	shape.shape = box
	add_child(shape)
	var post_shape := CollisionShape3D.new()
	var rod := CylinderShape3D.new()
	rod.radius = 0.06
	rod.height = post.height
	post_shape.shape = rod
	post_shape.position.y = post_view.position.y
	add_child(post_shape)
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = (COLOURS[kind] as Color).darkened(0.35)
	_glow.roughness = 0.15
	_glow.emission_enabled = true
	_glow.emission = COLOURS[kind]
	match kind:
		Kind.LANTERN:
			_build_lantern(brass)
		Kind.TON:
			_build_hourglass(brass)
		Kind.RADIOMETER:
			_build_radiometer()
		_:
			_build_crystal()
	_label = Label3D.new()
	_label.text = describe()
	_label.font_size = 26
	_label.pixel_size = 0.0022
	_label.outline_size = 8
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.no_depth_test = true
	_label.position.y = 0.42
	_label.width = 520.0
	_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_label.visible = false
	add_child(_label)


func colour() -> Color:
	return COLOURS[kind]


## Where beams leave and arrive: the head's centre.
func out_point() -> Vector3:
	return global_position


func in_point() -> Vector3:
	return global_position


## The lantern's face turned toward where its first beam goes.
func face(toward: Vector3) -> void:
	var flat := Vector3(toward.x - global_position.x, 0.0, toward.z - global_position.z)
	if flat.length() > 0.01:
		var local := global_transform.basis.inverse() * flat.normalized()
		_head.basis = Basis.looking_at(Vector3(local.x, 0.0, local.z).normalized(), Vector3.UP)


func show_label(on: bool) -> void:
	_label.visible = on


## What a player looking at it is told. Drafts.
func describe() -> String:
	match kind:
		Kind.LANTERN:
			return "Lantern: %s\nIts shutter is open while this holds." % title
		Kind.AND:
			return "AND crystal: %s\nShines only while every beam reaching it is lit." % title
		Kind.OR:
			return "OR crystal: %s\nShines while any beam reaching it is lit." % title
		Kind.NOT:
			return "NOT crystal: %s\nShines while its beam is dark." % title
		Kind.LATCH:
			return "Latch crystal: %s\nThe first beam lights it, the second puts it out; between, it remembers." % title
		Kind.TON:
			return "Hourglass, on-delay %d s: %s\nShines once its beam has stayed lit that long." % [roundi(delay), title]
		Kind.TOF:
			return "Afterglow crystal, off-delay %d s: %s\nKeeps shining that long after its beam goes dark." % [roundi(delay), title]
		Kind.RISE:
			return "Rising spark: %s\nOne flash when its beam comes on." % title
		Kind.FALL:
			return "Falling spark: %s\nOne flash when its beam goes dark." % title
		_:
			return "Radiometer: %s\nIts vanes spin in the light and drive the machine." % title


## One step of the logic, from the beams as they stand.
func evaluate(dt: float) -> void:
	var lit: Array[bool] = []
	for b in inputs:
		lit.append(b.delivered)
	var first: bool = lit[0] if not lit.is_empty() else false
	match kind:
		Kind.LANTERN:
			out = condition
		Kind.AND:
			out = not lit.is_empty() and not lit.has(false)
		Kind.OR:
			out = lit.has(true)
		Kind.NOT:
			out = not first
		Kind.LATCH:
			var reset: bool = lit[1] if lit.size() > 1 else false
			if reset:
				out = false
			elif first:
				out = true
		Kind.TON:
			_acc = minf(_acc + dt, delay) if first else 0.0
			out = first and _acc >= delay
		Kind.TOF:
			_acc = 0.0 if first else _acc + dt
			out = first or _acc < delay
		Kind.RISE, Kind.FALL:
			var edge := (first and not _last_in) if kind == Kind.RISE else (_last_in and not first)
			if edge:
				_pulse_left = PULSE
			_pulse_left = maxf(_pulse_left - dt, 0.0)
			out = _pulse_left > 0.0
		Kind.RADIOMETER:
			powered = lit.has(true)
			spin = move_toward(spin, 1.0 if powered else 0.0, dt * 1.2)
			out = false
	_last_in = first


func _process(delta: float) -> void:
	match kind:
		Kind.LANTERN:
			_shutter.rotation.x = lerp_angle(_shutter.rotation.x, -1.4 if out else 0.0, 1.0 - exp(-10.0 * delta))
			_glow.emission_energy_multiplier = 3.0 if out else 0.0
		Kind.TON:
			var run := _acc / maxf(delay, 0.01)
			_sand_top.scale = Vector3.ONE * maxf(1.0 - run, 0.01)
			_sand_bottom.scale = Vector3.ONE * maxf(run, 0.01)
			_glow.emission_energy_multiplier = 2.5 if out else 0.1
		Kind.TOF:
			var after := 1.0 if (out and _acc == 0.0) else clampf(1.0 - _acc / maxf(delay, 0.01), 0.0, 1.0)
			_glow.emission_energy_multiplier = 2.5 * after if out else 0.1
		Kind.RADIOMETER:
			_vane_angle += spin * 14.0 * delta
			_vanes.rotation.y = _vane_angle
		_:
			_glow.emission_energy_multiplier = 2.5 if out else 0.1


## A brass lantern with a round lens and a hinged shutter over it.
func _build_lantern(brass: Material) -> void:
	var body := BoxMesh.new()
	body.size = Vector3(0.2, 0.22, 0.24)
	body.material = brass
	_add(body, Vector3.ZERO)
	var lens := CylinderMesh.new()
	lens.top_radius = 0.07
	lens.bottom_radius = 0.07
	lens.height = 0.02
	lens.material = _glow
	_add(lens, Vector3(0, 0, -0.125)).rotation.x = PI * 0.5
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = 0.13
	cap.height = 0.08
	cap.radial_segments = 4
	cap.material = brass
	_add(cap, Vector3(0, 0.15, 0)).rotation.y = PI * 0.25
	_shutter = Node3D.new()
	_shutter.position = Vector3(0, 0.085, -0.14)
	_head.add_child(_shutter)
	var flap := MeshInstance3D.new()
	var flap_mesh := BoxMesh.new()
	flap_mesh.size = Vector3(0.18, 0.17, 0.01)
	flap_mesh.material = brass
	flap.mesh = flap_mesh
	flap.position = Vector3(0, -0.085, 0)
	_shutter.add_child(flap)


## A crystal: a six-sided double point, its tip up or down for an edge
## trigger; a latch wears a brass ring.
func _build_crystal() -> void:
	var tall := 0.2
	for up: float in [1.0, -1.0]:
		var half := CylinderMesh.new()
		half.radial_segments = 6
		half.rings = 1
		half.bottom_radius = 0.09
		half.top_radius = 0.0
		half.height = tall * (1.4 if (kind == Kind.RISE and up > 0.0) or (kind == Kind.FALL and up < 0.0) else 0.8)
		half.material = _glow
		var view := _add(half, Vector3(0, up * half.height * 0.5, 0))
		if up < 0.0:
			view.rotation.x = PI
	if kind == Kind.LATCH:
		var ring := TorusMesh.new()
		ring.inner_radius = 0.1
		ring.outer_radius = 0.125
		var brass := StandardMaterial3D.new()
		brass.albedo_color = Color(0.7, 0.52, 0.22)
		brass.metallic = 0.8
		brass.roughness = 0.35
		ring.material = brass
		_add(ring, Vector3.ZERO)


## An hourglass in a brass frame: the sand in its upper and lower bulbs
## is two cones that shrink and grow as the time runs.
func _build_hourglass(brass: Material) -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.95, 1.0, 0.25)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	for up: float in [1.0, -1.0]:
		var bulb := CylinderMesh.new()
		bulb.top_radius = 0.09 if up > 0.0 else 0.012
		bulb.bottom_radius = 0.012 if up > 0.0 else 0.09
		bulb.height = 0.15
		bulb.material = glass
		_add(bulb, Vector3(0, up * 0.075, 0))
		var plate := CylinderMesh.new()
		plate.top_radius = 0.11
		plate.bottom_radius = 0.11
		plate.height = 0.02
		plate.material = brass
		_add(plate, Vector3(0, up * 0.16, 0))
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.95, 0.8, 0.45)
	sand.emission_enabled = true
	sand.emission = Color(0.45, 1.0, 0.45)
	sand.emission_energy_multiplier = 0.4
	var top := CylinderMesh.new()
	top.top_radius = 0.07
	top.bottom_radius = 0.0
	top.height = 0.1
	top.material = sand
	_sand_top = _add(top, Vector3(0, 0.06, 0))
	var bottom := CylinderMesh.new()
	bottom.top_radius = 0.0
	bottom.bottom_radius = 0.075
	bottom.height = 0.08
	bottom.material = sand
	_sand_bottom = _add(bottom, Vector3(0, -0.11, 0))
	# A small glowing bead on top shows the timer's output.
	var bead := SphereMesh.new()
	bead.radius = 0.035
	bead.height = 0.07
	bead.material = _glow
	_add(bead, Vector3(0, 0.2, 0))


## A Crookes radiometer: a glass bulb on a stem with four vanes, each
## black on one face and silvered on the other, on a pin.
func _build_radiometer() -> void:
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.85, 0.95, 1.0, 0.2)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.05
	var bulb := SphereMesh.new()
	bulb.radius = 0.13
	bulb.height = 0.26
	bulb.material = glass
	_add(bulb, Vector3.ZERO)
	var stem := CylinderMesh.new()
	stem.top_radius = 0.025
	stem.bottom_radius = 0.035
	stem.height = 0.08
	stem.material = glass
	_add(stem, Vector3(0, -0.15, 0))
	_vanes = Node3D.new()
	_head.add_child(_vanes)
	var black := StandardMaterial3D.new()
	black.albedo_color = Color(0.02, 0.02, 0.02)
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.9, 0.9, 0.9)
	silver.metallic = 1.0
	silver.roughness = 0.2
	for k in 4:
		var arm := Node3D.new()
		arm.rotation.y = TAU * k / 4.0
		_vanes.add_child(arm)
		for face: Array in [[black, 0.003], [silver, -0.003]]:
			var vane := MeshInstance3D.new()
			var plate := BoxMesh.new()
			plate.size = Vector3(0.05, 0.05, 0.004)
			plate.material = face[0]
			vane.mesh = plate
			vane.position = Vector3(0.07, 0, float(face[1]))
			arm.add_child(vane)


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	_head.add_child(view)
	return view
