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
## - RADIOMETER: an output coil, the luminous rotor. A spinstone (a
##   crystal of photogyrite, which turns when light falls on it) upright
##   on a spindle between two jewel bearings in an open brass frame.
##   Light pushes it round in proportion to its power and the air's drag
##   holds it back with the square of its speed, so it runs up to a
##   speed growing with the square root of the light: `spin` (0 to 1)
##   eases toward the root of the power reaching it over FULL_SPIN watts,
##   or toward 1 while lit where beams carry no power; the machine it
##   drives reads it, or `powered`.
##
## A right click on a part reads its name and what it does (`describe`,
## `inspect_text`).
##
## Its look, optional (`look`): "post" false leaves out its own post and
## cradle, for a part held by some other mounting; "design" cuts its
## crystal another way (point, the six-sided double point; octa, orb,
## cluster, gem, obelisk, prism, tablet), and an on-delay given a design
## is a crystal rather than an hourglass; "setting" holds the crystal
## (prongs, cage, cup, coil, collar, hook) in "metal"; "lamp" is the
## lantern's body (box, or drum: a round drum with a round shutter);
## "colour" is its light's colour in place of its kind's; "aimed" makes
## it a part the player aims (see OpticBench): a brass lens on its front
## that its beam leaves from, straight ahead; it reads whatever beams
## strike it, from any side, in place of fixed LumenBeams, within a
## round body "catch" metres in radius (0.32).

enum Kind { LANTERN, AND, OR, NOT, LATCH, TON, TOF, RISE, FALL, RADIOMETER }

const PULSE := 0.4
const FULL_SPIN := 2000.0               # watts of light that run a rotor at full speed
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
var inputs: Array = []                  # LumenBeams, or the OpticArrivals of beams striking an aimed part: each has `delivered`
var aimed := false
var yaw := 0.0                          # an aimed part's head
var pitch := 0.0

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
var _look := {}


## A part of `kind` at `at` (the head's centre), its post down to
## `ground`. `wood` and `brass` are the post's and fittings' materials.
func _init(part_kind: Kind, part_title: String, at: Vector3, ground: float,
		wood: Material, brass: Material, part_delay := 0.0, look := {}) -> void:
	kind = part_kind
	title = part_title
	delay = part_delay
	_look = look
	# An off-delay starts long since run out, dark until its beam first
	# lights.
	if kind == Kind.TOF:
		_acc = delay
	name = Kind.keys()[kind].capitalize() + "Part"
	position = at
	set_meta("view", self)
	add_child(_head)
	if look.get("post", true):
		_build_post(at.y - ground, wood, brass)
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.36, 0.42, 0.36)
	shape.shape = box
	add_child(shape)
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = colour().darkened(0.35)
	_glow.roughness = 0.15
	_glow.emission_enabled = true
	_glow.emission = colour()
	var metal: Material = look.get("metal", brass)
	match kind:
		Kind.LANTERN:
			# "none": its head built by someone else (LanternLook).
			if look.get("lamp", "box") == "drum":
				_build_drum(metal)
			elif look.get("lamp", "box") != "none":
				_build_lantern(brass)
		Kind.TON when not look.has("design"):
			_build_hourglass(brass)
		Kind.RADIOMETER:
			_build_radiometer()
		_:
			_build_crystal(look.get("design", "point"))
			_build_setting(look.get("setting", ""), metal)
	if look.get("aimed", false):
		_build_lens(metal)
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


## Its own wooden post down `drop` metres to the ground, a brass cradle
## under the head.
func _build_post(drop: float, wood: Material, brass: Material) -> void:
	var post := CylinderMesh.new()
	post.top_radius = 0.045
	post.bottom_radius = 0.06
	post.height = maxf(drop - 0.12, 0.1)
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
	var post_shape := CollisionShape3D.new()
	var rod := CylinderShape3D.new()
	rod.radius = 0.06
	rod.height = post.height
	post_shape.shape = rod
	post_shape.position.y = post_view.position.y
	add_child(post_shape)


func colour() -> Color:
	return _look.get("colour", COLOURS[kind])


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


## What a right click on it reads: its name, then what it does.
func inspect_text() -> String:
	return _label.text


## Its label made to read `text` in place of its own description.
func relabel(text: String) -> void:
	_label.text = text


## What a player looking at it is told. Drafts.
func describe() -> String:
	if aimed:
		var how := "\nA right click aims it; E looks through its lens." if kind != Kind.RADIOMETER else ""
		if kind == Kind.LATCH:
			how += " A beam from its left lights it, from its right puts it out."
		return _describe_kind() + how
	return _describe_kind()


func _describe_kind() -> String:
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
			return "Luminous rotor: %s\nIts spinstone turns in the light and drives the machine." % title


## ---- aiming ------------------------------------------------------------------

## The head turned to `y` (about the upright) and `p` (up and down).
func aim(y: float, p: float) -> void:
	yaw = y
	pitch = clampf(p, -1.5, 1.5)
	_head.basis = Basis.from_euler(Vector3(pitch, yaw, 0.0))


## Turned by the mouse while held.
func turn_by(motion: Vector2) -> void:
	aim(yaw - motion.x * 0.004, pitch - motion.y * 0.004)


## The head turned to look along `dir` (world).
func aim_along(dir: Vector3) -> void:
	var local := global_transform.basis.inverse() * dir.normalized()
	aim(atan2(-local.x, -local.z), asin(clampf(local.y, -1.0, 1.0)))


## The head (and the solids the player and beams meet) moved to `local`
## in its own frame: a sun collector's, to its dish's focus.
func set_head_at(local: Vector3) -> void:
	_head.position = local
	for c in get_children():
		if c is CollisionShape3D:
			(c as CollisionShape3D).position = local


## The turning head, for a head built from outside.
func head_node() -> Node3D:
	return _head


## Which way its beam leaves.
func forward() -> Vector3:
	return -(_head.global_transform.basis.z).normalized()


## Where its beam leaves: the lens.
func lens_point() -> Vector3:
	return _head.to_global(Vector3(0, 0, -0.2))


## The lens of an aimed part, and a generous round body for beams to
## strike (layer 4, so the player's look and beams find it, never the
## player's own body).
func _build_lens(lens_metal: Material) -> void:
	aimed = true
	# The head turns: kept out of the island's joining of still pieces.
	_head.set_meta(StaticMerge.MOVES, true)
	inputs.clear()
	var catch := CollisionShape3D.new()
	var ball := SphereShape3D.new()
	ball.radius = float(_look.get("catch", 0.32))
	catch.shape = ball
	add_child(catch)
	if kind == Kind.RADIOMETER:
		return
	var tube := CylinderMesh.new()
	tube.top_radius = 0.045
	tube.bottom_radius = 0.055
	tube.height = 0.08
	tube.material = lens_metal
	_add(tube, Vector3(0, 0, -0.17)).rotation.x = PI * 0.5
	var glass := CylinderMesh.new()
	glass.top_radius = 0.038
	glass.bottom_radius = 0.038
	glass.height = 0.01
	glass.material = _glow
	_add(glass, Vector3(0, 0, -0.215)).rotation.x = PI * 0.5


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
			var want := 1.0 if powered else 0.0
			var watts := 0.0
			var measured := false
			for b in inputs:
				if b is OpticArrival and (b as OpticArrival).power >= 0.0:
					measured = true
					watts += (b as OpticArrival).power
			if measured:
				want = sqrt(clampf(watts / FULL_SPIN, 0.0, 1.0))
			spin = move_toward(spin, want, dt * 1.2)
			out = false
	_last_in = first


func _process(delta: float) -> void:
	match kind:
		Kind.LANTERN:
			if _shutter != null:
				_shutter.rotation.x = lerp_angle(_shutter.rotation.x, -1.4 if out else 0.0, 1.0 - exp(-10.0 * delta))
			_glow.emission_energy_multiplier = 3.0 if out else 0.0
		Kind.TON:
			if _sand_top != null:
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
			_glow.emission_energy_multiplier = 0.15 + 2.2 * spin
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
	_shutter.set_meta(StaticMerge.MOVES, true)
	_shutter.position = Vector3(0, 0.085, -0.14)
	_head.add_child(_shutter)
	var flap := MeshInstance3D.new()
	var flap_mesh := BoxMesh.new()
	flap_mesh.size = Vector3(0.18, 0.17, 0.01)
	flap_mesh.material = brass
	flap.mesh = flap_mesh
	flap.position = Vector3(0, -0.085, 0)
	_shutter.add_child(flap)


## A crystal cut as `design`. The point is a six-sided double point, its
## tip up or down for an edge trigger, a latch's wearing a brass ring.
func _build_crystal(design: String) -> void:
	match design:
		"octa":
			var m := SphereMesh.new()
			m.radial_segments = 4
			m.rings = 2
			m.radius = 0.1
			m.height = 0.3
			m.material = _glow
			_add(m, Vector3.ZERO).rotation.y = PI * 0.25
			return
		"orb":
			var m := SphereMesh.new()
			m.radial_segments = 12
			m.rings = 6
			m.radius = 0.085
			m.height = 0.17
			m.material = _glow
			_add(m, Vector3.ZERO)
			return
		"cluster":
			for k in 5:
				var c := CylinderMesh.new()
				c.radial_segments = 6
				c.rings = 1
				c.top_radius = 0.0
				c.bottom_radius = 0.04 if k > 0 else 0.05
				c.height = 0.17 if k > 0 else 0.26
				c.material = _glow
				var lean := Basis.IDENTITY
				if k > 0:
					var a := TAU * k / 4.0
					lean = Basis(Vector3(cos(a), 0, sin(a)).cross(Vector3.UP).normalized(), -0.55)
				var view := _add(c, Vector3.ZERO)
				view.basis = lean
				view.position = lean * Vector3(0, c.height * 0.5 - 0.06, 0)
			return
		"gem":
			var crown := CylinderMesh.new()
			crown.radial_segments = 8
			crown.rings = 1
			crown.top_radius = 0.06
			crown.bottom_radius = 0.1
			crown.height = 0.05
			crown.material = _glow
			_add(crown, Vector3(0, 0.025, 0))
			var pavilion := CylinderMesh.new()
			pavilion.radial_segments = 8
			pavilion.rings = 1
			pavilion.top_radius = 0.1
			pavilion.bottom_radius = 0.0
			pavilion.height = 0.11
			pavilion.material = _glow
			_add(pavilion, Vector3(0, -0.055, 0))
			return
		"obelisk":
			var shaft := CylinderMesh.new()
			shaft.radial_segments = 4
			shaft.rings = 1
			shaft.top_radius = 0.04
			shaft.bottom_radius = 0.055
			shaft.height = 0.24
			shaft.material = _glow
			_add(shaft, Vector3(0, -0.02, 0)).rotation.y = PI * 0.25
			var tip := CylinderMesh.new()
			tip.radial_segments = 4
			tip.rings = 1
			tip.top_radius = 0.0
			tip.bottom_radius = 0.04
			tip.height = 0.07
			tip.material = _glow
			_add(tip, Vector3(0, 0.135, 0)).rotation.y = PI * 0.25
			return
		"prism":
			var m := CylinderMesh.new()
			m.radial_segments = 3
			m.rings = 1
			m.top_radius = 0.075
			m.bottom_radius = 0.075
			m.height = 0.22
			m.material = _glow
			_add(m, Vector3.ZERO)
			return
		"tablet":
			var m := CylinderMesh.new()
			m.radial_segments = 6
			m.rings = 1
			m.top_radius = 0.11
			m.bottom_radius = 0.11
			m.height = 0.035
			m.material = _glow
			_add(m, Vector3.ZERO).rotation.x = PI * 0.5
			return
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


## What holds a crystal, in `metal`: prongs (four claws from below),
## cage (two crossed rings round it), cup (a cup under it), coil (wire
## wound round its lower half), collar (a band round its middle), hook (a
## loop over it to hang by).
func _build_setting(setting: String, metal: Material) -> void:
	match setting:
		"prongs":
			var foot := CylinderMesh.new()
			foot.top_radius = 0.03
			foot.bottom_radius = 0.05
			foot.height = 0.04
			foot.material = metal
			_add(foot, Vector3(0, -0.17, 0))
			for k in 4:
				var a := TAU * k / 4.0 + PI * 0.25
				var claw := CylinderMesh.new()
				claw.top_radius = 0.008
				claw.bottom_radius = 0.012
				claw.height = 0.16
				claw.radial_segments = 6
				claw.material = metal
				var out_dir := Vector3(cos(a), 0, sin(a))
				var view := _add(claw, out_dir * 0.05 + Vector3(0, -0.09, 0))
				view.basis = Basis(out_dir.cross(Vector3.UP).normalized(), -0.45)
		"cage":
			for k in 2:
				var ring := TorusMesh.new()
				ring.inner_radius = 0.125
				ring.outer_radius = 0.14
				ring.rings = 24
				ring.ring_segments = 6
				ring.material = metal
				var view := _add(ring, Vector3.ZERO)
				view.rotation = Vector3(PI * 0.5, PI * 0.5 * k, 0)
			var cap := SphereMesh.new()
			cap.radius = 0.025
			cap.height = 0.05
			cap.material = metal
			_add(cap, Vector3(0, 0.14, 0))
			_add(cap, Vector3(0, -0.14, 0))
		"cup":
			var cup := CylinderMesh.new()
			cup.top_radius = 0.085
			cup.bottom_radius = 0.045
			cup.height = 0.07
			cup.material = metal
			_add(cup, Vector3(0, -0.1, 0))
			var stem := CylinderMesh.new()
			stem.top_radius = 0.015
			stem.bottom_radius = 0.03
			stem.height = 0.06
			stem.material = metal
			_add(stem, Vector3(0, -0.165, 0))
		"coil":
			for k in 4:
				var turn := TorusMesh.new()
				turn.inner_radius = 0.085 - k * 0.008
				turn.outer_radius = 0.097 - k * 0.008
				turn.rings = 20
				turn.ring_segments = 5
				turn.material = metal
				_add(turn, Vector3(0, -0.11 + k * 0.03, 0)).rotation.z = 0.08
		"collar":
			var band := CylinderMesh.new()
			band.top_radius = 0.105
			band.bottom_radius = 0.105
			band.height = 0.035
			band.radial_segments = 12
			band.material = metal
			_add(band, Vector3.ZERO)
		"hook":
			var cap := CylinderMesh.new()
			cap.top_radius = 0.02
			cap.bottom_radius = 0.06
			cap.height = 0.05
			cap.material = metal
			_add(cap, Vector3(0, 0.15, 0))
			var loop := TorusMesh.new()
			loop.inner_radius = 0.022
			loop.outer_radius = 0.034
			loop.rings = 12
			loop.ring_segments = 5
			loop.material = metal
			_add(loop, Vector3(0, 0.205, 0)).rotation.x = PI * 0.5


## A drum lantern: a round metal drum lying on its side, a lens in its
## face, a round shutter hinged over it, a little dome on top.
func _build_drum(metal: Material) -> void:
	var drum := CylinderMesh.new()
	drum.top_radius = 0.11
	drum.bottom_radius = 0.11
	drum.height = 0.18
	drum.radial_segments = 16
	drum.material = metal
	_add(drum, Vector3.ZERO).rotation.x = PI * 0.5
	var lens := CylinderMesh.new()
	lens.top_radius = 0.075
	lens.bottom_radius = 0.075
	lens.height = 0.02
	lens.material = _glow
	_add(lens, Vector3(0, 0, -0.095)).rotation.x = PI * 0.5
	var dome := SphereMesh.new()
	dome.radius = 0.05
	dome.height = 0.05
	dome.is_hemisphere = true
	dome.material = metal
	_add(dome, Vector3(0, 0.1, 0))
	_shutter = Node3D.new()
	_shutter.set_meta(StaticMerge.MOVES, true)
	_shutter.position = Vector3(0, 0.08, -0.11)
	_head.add_child(_shutter)
	var flap := MeshInstance3D.new()
	var flap_mesh := CylinderMesh.new()
	flap_mesh.top_radius = 0.085
	flap_mesh.bottom_radius = 0.085
	flap_mesh.height = 0.008
	flap_mesh.material = metal
	flap.mesh = flap_mesh
	flap.rotation.x = PI * 0.5
	flap.position = Vector3(0, -0.08, 0)
	_shutter.add_child(flap)


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
## The luminous rotor: a round brass base, two posts and a bridge over
## the top, a jewel bearing in each, a steel spindle between them, and on
## it the spinstone: a crystal of photogyrite, six-sided and pointed at
## both ends, with three fins winding round it, glowing faintly as it
## turns.
func _build_radiometer() -> void:
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.82, 0.62, 0.3)
	brass.metallic = 0.85
	brass.roughness = 0.3
	var ruby := StandardMaterial3D.new()
	ruby.albedo_color = Color(0.75, 0.08, 0.12)
	ruby.roughness = 0.1
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.75, 0.77, 0.8)
	steel.metallic = 0.9
	steel.roughness = 0.25
	var frame := CozyMesh.new()
	var gold := Color(0.82, 0.62, 0.3)
	frame.cyl(0.11, 0.12, 0.025, 24, CozyMesh.at(Vector3(0, -0.15, 0)), gold)
	frame.cyl(0.03, 0.04, 0.03, 12, CozyMesh.at(Vector3(0, -0.125, 0)), gold)
	for s: float in [-1.0, 1.0]:
		frame.cyl(0.009, 0.011, 0.33, 8, CozyMesh.at(Vector3(s * 0.095, 0.015, 0)), gold)
		frame.ball(0.016, 8, CozyMesh.at(Vector3(s * 0.095, 0.18, 0)), gold)
	frame.box(Vector3(0.2, 0.016, 0.026), CozyMesh.at(Vector3(0, 0.17, 0)), gold)
	frame.cyl(0.018, 0.022, 0.025, 10, CozyMesh.at(Vector3(0, 0.155, 0)), gold)
	var held := MeshInstance3D.new()
	held.mesh = frame.commit(brass)
	_head.add_child(held)
	for y: float in [-0.11, 0.142]:
		var jewel := SphereMesh.new()
		jewel.radius = 0.009
		jewel.height = 0.018
		jewel.material = ruby
		_add(jewel, Vector3(0, y, 0))
	_vanes = Node3D.new()
	_vanes.set_meta(StaticMerge.MOVES, true)
	_head.add_child(_vanes)
	var spindle := CylinderMesh.new()
	spindle.top_radius = 0.004
	spindle.bottom_radius = 0.004
	spindle.height = 0.25
	spindle.material = steel
	var sv := MeshInstance3D.new()
	sv.mesh = spindle
	sv.position.y = 0.015
	_vanes.add_child(sv)
	# The spinstone, glowing as it turns (its own glow, `_glow`).
	_glow.albedo_color = Color(0.78, 0.66, 0.95, 0.85)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.emission = Color(0.85, 0.7, 1.0)
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	var stone := CozyMesh.new()
	var lilac := Color(1, 1, 1)
	stone.cyl(0.032, 0.032, 0.12, 6, CozyMesh.at(Vector3(0, 0.015, 0)), lilac)
	stone.cyl(0.0, 0.032, 0.05, 6, CozyMesh.at(Vector3(0, 0.1, 0)), lilac)
	stone.cyl(0.032, 0.0, 0.05, 6, CozyMesh.at(Vector3(0, -0.07, 0)), lilac)
	# Three thin fins winding a third of a turn up the stone, each a
	# smooth twisted blade from the stone's side outward.
	var steps := 12
	for f in 3:
		var prev: Array = []
		for k in steps + 1:
			var t := float(k) / steps
			var a := TAU * f / 3.0 + t * TAU / 3.0
			var y := lerpf(-0.055, 0.085, t)
			var out := Vector3(cos(a), 0, -sin(a))
			# Narrower toward the ends, as the crystal's own fins taper.
			var reach := 0.03 + 0.032 * sin(t * PI)
			var row: Array[Vector3] = [out * 0.026 + Vector3.UP * y, out * reach + Vector3.UP * (y + 0.01)]
			if not prev.is_empty():
				var back: Vector3 = prev[0]
				var n := (row[0] - back).cross(row[1] - row[0]).normalized()
				stone.quad(prev[0], prev[1], row[1], row[0], n, lilac)
				stone.quad(prev[0], prev[1], row[1], row[0], -n, lilac)
			prev = row
	var sm := MeshInstance3D.new()
	sm.mesh = stone.commit(_glow)
	_vanes.add_child(sm)


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	_head.add_child(view)
	return view
