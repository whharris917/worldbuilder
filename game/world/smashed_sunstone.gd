class_name SmashedSunstone
extends Node3D
## A demonstration: a sunstone smashed by a drop hammer, its pieces lying
## on a patch of slate in the sun, to see what the light does to them.
##
## Each piece is a whole sunstone, as each piece of a broken magnet is a
## whole magnet: its crystal's axis runs as the stone's did, so it lies in
## the piece some way the break did not choose (`axis`, fixed in the
## piece, any way to its shape). The sun's light on a piece works as on
## the gimbal stones (SpinstoneGimbals): it draws the axis's seeking end
## toward the sun (PULL_PER_WATT for each watt) and spins the piece about
## its axis while that end faces the sun (TURN for each watt); nothing
## unlit, in shade of night or eclipse. The light a piece catches goes as
## its area (a convex body's mean shadow is a quarter of its surface),
## its weight as its volume: halve a piece and the light's twist falls to
## a quarter, the weight holding it down to a sixteenth. So the finest
## pieces stand up on end and point at the sun, the finest of all
## tumbling as they are spun; middling ones tip and lean; the largest lie
## as they fell.
##
## A piece on the ground is ruled by friction, not by its swing: it turns
## at a rate in proportion to the twist on it (overdamped), measured
## against its own weight's twist (RELAX), and never faster than it can
## creep over the rough slate (CREEP), so a piece takes a few seconds to
## stand. Gravity is the twist toward
## its lowest resting: the height of its centre over the ground is the
## sum of its half-sizes along the up direction (a box's), rounded a
## little at the faces so a flat face is a smooth hollow. Static friction
## (GRIP) holds a piece until the light's twist on it is greater. Pieces
## are boxes to the sums, irregular shards to the eye; they do not touch
## one another, and the anvil and frame cast no shade on them.
##
## A lever drops the hammer (smash) or raises it, with a new stone set
## under it (mend); another swings a round sunshade on a jointed arm
## into the line between the sun and the slate, keeping it there as the
## sun moves, or folds it back, so the pieces can be watched lying down
## in its shade and standing again in the sun. A piece is in its shade
## where the line from it to the sun passes through the canvas.

const PIECES := 400
const SMALLEST := 0.001                 # m: the longest side of the smallest piece
const LARGEST := 0.03                   # m: and of the largest
const DENSITY := 2650.0                 # kg/m³, as quartz
const PATCH_R := 1.1                    # m: the slate patch round the anvil
const ANVIL_TOP := 0.36
const SLATE := 0.03                     # m: the slate's face over the ground
const ANVIL_HALF := 0.16
const HAMMER_UP := 1.25                 # m: the hammer's face raised, over the ground
const ROUND := 0.08                     # the rounding of the faces in the height sum
const RELAX := 0.15                     # s: how quickly a piece turns, against its own weight's twist
const GRIP := 0.5                       # static friction's share of the weight
const CREEP := 0.8                      # rad/s: the fastest a piece turns on the rough slate
const SHADE_R := 1.3                    # m: the sunshade's canvas, half across
const SHADE_OUT := 2.2                  # m: from the slate's middle toward the sun, when out
const POST := Vector3(0.0, 1.3, -1.45)  # the arm's shoulder, on its post north of the slate

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0

var _mats: Dictionary
var _pieces: Array[Dictionary] = []
var _view: MultiMeshInstance3D
var _stone: Node3D
var _hammer: Node3D
var _hammer_y := HAMMER_UP
var _smashed := false
var _falling := false
var _lever: WorksHandle
var _shade: Node3D
var _arm: MeshInstance3D
var _shaded := false
var _cover := 0.0                       # the canvas drawn over, 0 to 1
var _rng := RandomNumberGenerator.new()


## `materials`: "brass", "iron", "wood", as for the gimbals.
func _init(materials: Dictionary) -> void:
	name = "SmashedSunstone"
	_mats = materials
	_rng.seed = 1874


func _ready() -> void:
	_build()
	_mend()


## A line for the panel: how the pieces lie.
func report() -> String:
	if not _smashed:
		return "Sunstone under the hammer: whole."
	var standing := 0
	var leaning := 0
	var turning := 0
	for p in _pieces:
		if p["flying"]:
			continue
		var axis := (p["att"] as Basis) * (p["axis"] as Vector3)
		var off := rad_to_deg(acos(clampf(axis.dot(to_sun), -1.0, 1.0)))
		if off < 20.0:
			standing += 1
		elif off < 70.0 and (p["att"] as Basis) != (p["landed"] as Basis):
			leaning += 1
		if (p["rate"] as float) > CREEP * 0.5:
			turning += 1
	return "Smashed sunstone, %d pieces: %d pointing at the sun, %d leaning toward it, %d turning." % [
			_pieces.size(), standing, leaning, turning]


func _process(delta: float) -> void:
	if _falling:
		_hammer_y = maxf(_hammer_y - delta * 6.0, ANVIL_TOP + 0.035)
		if _hammer_y <= ANVIL_TOP + 0.035:
			_falling = false
			_smash()
	elif not _smashed:
		_hammer_y = move_toward(_hammer_y, HAMMER_UP, delta * 0.8)
	_hammer.position.y = _hammer_y
	_cover = move_toward(_cover, 1.0 if _shaded else 0.0, delta * 0.5)
	_place_shade()


func _physics_process(delta: float) -> void:
	if not _smashed:
		return
	var up := Vector3.UP
	var lit := sunlight > 0.0 and to_sun.y > 0.0
	var mm := _view.multimesh
	for k in _pieces.size():
		var p := _pieces[k]
		var att: Basis = p["att"]
		var e: Vector3 = p["half"]
		if p["flying"]:
			var v: Vector3 = p["v"]
			v.y -= 9.8 * delta
			p["v"] = v
			var w: Vector3 = p["spin"]
			att = (Basis(w.normalized(), w.length() * delta) * att).orthonormalized()
			var at: Vector3 = p["at"] + v * delta
			var floor_y := _rest_height(att, e)
			if at.y <= floor_y and v.y < 0.0:
				at.y = floor_y
				p["flying"] = false
				p["landed"] = att
				# Kept on the slate.
				var flat := Vector2(at.x, at.z)
				if flat.length() > PATCH_R - 0.05:
					flat = flat.normalized() * (PATCH_R - 0.05)
				if flat.length() < ANVIL_HALF + 0.02:
					flat = flat.normalized() * (ANVIL_HALF + 0.02)
				at = Vector3(flat.x, at.y, flat.y)
			p["at"] = at
			p["att"] = att
			mm.set_instance_transform(k, Transform3D(att.scaled(e), at))
			continue
		var weight := float(p["mass"]) * 9.8
		var twist := Vector3.ZERO
		if lit and not _in_shade(p["at"]):
			var watts := sunlight * float(p["area"])
			var axis := att * (p["axis"] as Vector3)
			twist = axis.cross(to_sun) * SpinstoneGimbals.PULL_PER_WATT * watts \
					+ axis * SpinstoneGimbals.TURN * watts * maxf(axis.dot(to_sun), 0.0)
			# Static friction holds it until the light's twist is greater.
			var hold := GRIP * weight * (e.x + e.y + e.z) / 3.0
			twist = twist.normalized() * maxf(twist.length() - hold, 0.0) if twist.length() > 0.0 else twist
		# Gravity: the twist toward a lower resting.
		var u := att.transposed() * up
		var lean := Vector3(e.x * u.x / sqrt(u.x * u.x + ROUND * ROUND), e.y * u.y / sqrt(u.y * u.y + ROUND * ROUND),
				e.z * u.z / sqrt(u.z * u.z + ROUND * ROUND))
		twist += up.cross(att * lean) * weight
		var rate := twist / (weight * maxf(e.x, maxf(e.y, e.z)) * RELAX)
		if rate.length() > CREEP:
			rate = rate.normalized() * CREEP
		p["rate"] = rate.length()
		if rate.length() > 1e-4:
			att = (Basis(rate.normalized(), rate.length() * delta) * att).orthonormalized()
			p["att"] = att
			var at: Vector3 = p["at"]
			at.y = _rest_height(att, e)
			p["at"] = at
			mm.set_instance_transform(k, Transform3D(att.scaled(e), at))
		# Brighter as it turns, as a spinstone glows.
		var glow := clampf(float(p["rate"]) / (CREEP * 0.8), 0.0, 1.0)
		mm.set_instance_color(k, Color(1.0, 0.7, 0.28).lerp(Color(1.0, 0.92, 0.6), glow) * (1.3 + 6.0 * glow))


## Whether the sunshade's canvas stands between a piece at `at` and the
## sun.
func _in_shade(at: Vector3) -> bool:
	var face := _shade.basis.z
	var across := to_sun.dot(face)
	if absf(across) < 1e-4:
		return false
	var t := (_shade.position - at).dot(face) / across
	return t > 0.0 and (at + to_sun * t).distance_to(_shade.position) < SHADE_R


## The sunshade between folded by its post (`_cover` 0) and out in the
## line from the slate's middle to the sun, square to it (1).
func _place_shade() -> void:
	var folded := Transform3D(Basis.IDENTITY.rotated(Vector3.RIGHT, -PI * 0.5), POST + Vector3(0, 0.5, 0))
	var toward := to_sun if to_sun.y > 0.05 else Vector3.UP
	var out_at := Vector3(0, SLATE, 0) + toward * SHADE_OUT
	var out := Transform3D(Basis.looking_at(-toward, Vector3.UP if absf(toward.y) < 0.99 else Vector3.FORWARD), out_at)
	var k := smoothstep(0.0, 1.0, _cover)
	var head := Transform3D(Basis(folded.basis.get_rotation_quaternion().slerp(out.basis.get_rotation_quaternion(), k)),
			folded.origin.lerp(out.origin, k))
	_shade.transform = head
	# The arm from the shoulder to the canvas's middle.
	var span := head.origin - POST
	_arm.transform = Transform3D(CozyMesh.aligned(span.normalized()).scaled(Vector3(1.0, span.length(), 1.0)), POST + span * 0.5)


## The height of a piece's centre resting on the slate as it lies.
func _rest_height(att: Basis, e: Vector3) -> float:
	var u := att.transposed() * Vector3.UP
	return SLATE + e.x * absf(u.x) + e.y * absf(u.y) + e.z * absf(u.z)


func _smash() -> void:
	_smashed = true
	_stone.visible = false
	_view.visible = true
	_lever.on = false
	_lever.call("_show")
	var mm := _view.multimesh
	for k in _pieces.size():
		var p := _pieces[k]
		p["flying"] = true
		p["rate"] = 0.0
		var out := Vector2.from_angle(_rng.randf() * TAU)
		var speed := _rng.randf_range(0.2, 1.5)
		p["at"] = Vector3(out.x * 0.05, ANVIL_TOP + 0.03, out.y * 0.05)
		p["v"] = Vector3(out.x * speed, _rng.randf_range(0.5, 2.5), out.y * speed)
		p["spin"] = Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized() * _rng.randf_range(5.0, 40.0)
		p["att"] = Basis.from_euler(Vector3(_rng.randf() * TAU, _rng.randf() * TAU, _rng.randf() * TAU))
		mm.set_instance_transform(k, Transform3D((p["att"] as Basis).scaled(p["half"]), p["at"]))
		mm.set_instance_color(k, Color(1.0, 0.7, 0.28) * 1.3)


## A new stone set under the hammer, which rises.
func _mend() -> void:
	_smashed = false
	_falling = false
	_stone.visible = true
	_view.visible = false
	_pieces.clear()
	for k in PIECES:
		# Many small pieces, few large.
		var longest := SMALLEST * pow(LARGEST / SMALLEST, pow(_rng.randf(), 1.5))
		var half := Vector3(longest, longest * _rng.randf_range(0.35, 0.85), longest * _rng.randf_range(0.2, 0.6)) * 0.5
		var surface := 8.0 * (half.x * half.y + half.y * half.z + half.z * half.x)
		_pieces.append({"half": half, "mass": DENSITY * 8.0 * half.x * half.y * half.z, "area": surface * 0.25,
				"axis": Vector3(_rng.randf_range(-1, 1), _rng.randf_range(-1, 1), _rng.randf_range(-1, 1)).normalized(),
				"att": Basis.IDENTITY, "landed": Basis.IDENTITY, "at": Vector3.ZERO, "v": Vector3.ZERO,
				"spin": Vector3.ZERO, "flying": false, "rate": 0.0})


## ---- building ----------------------------------------------------------------

func _build() -> void:
	var gold := Color(0.85, 0.66, 0.32)
	var painted := StandardMaterial3D.new()
	painted.vertex_color_use_as_albedo = true
	painted.roughness = 0.85
	var slate := CozyMesh.new()
	slate.cyl(PATCH_R, PATCH_R, 0.1, 40, CozyMesh.at(Vector3(0, SLATE - 0.05, 0)), Color(0.16, 0.17, 0.2))
	_add(slate, painted)
	# The anvil, and over it the hammer's frame.
	var iron := CozyMesh.new()
	iron.box(Vector3(ANVIL_HALF * 2.0, ANVIL_TOP - 0.02, ANVIL_HALF * 2.0), CozyMesh.at(Vector3(0, 0.02 + (ANVIL_TOP - 0.02) * 0.5, 0)), Color(0.24, 0.24, 0.26))
	_add(iron, painted)
	var frame := CozyMesh.new()
	var top := HAMMER_UP + 0.45
	for sx: float in [-1.0, 1.0]:
		frame.rod(Vector3(sx * 0.32, 0.02, 0), Vector3(sx * 0.32, top, 0), 0.025, 8, gold)
	frame.rod(Vector3(-0.32, top, 0), Vector3(0.32, top, 0), 0.025, 8, gold)
	frame.rod(Vector3(-0.32, 0.6, 0), Vector3(-0.2, 0.6, 0), 0.015, 6, gold)
	frame.rod(Vector3(0.32, 0.6, 0), Vector3(0.2, 0.6, 0), 0.015, 6, gold)
	_add(frame, _mats["brass"])
	_hammer = Node3D.new()
	add_child(_hammer)
	var head := CozyMesh.new()
	head.box(Vector3(0.22, 0.16, 0.16), CozyMesh.at(Vector3(0, 0.08, 0)), Color(0.3, 0.3, 0.32))
	for sx: float in [-1.0, 1.0]:
		head.rod(Vector3(sx * 0.11, 0.08, 0), Vector3(sx * 0.3, 0.08, 0), 0.02, 6, Color(0.3, 0.3, 0.32))
	var rope := CozyMesh.new()
	rope.rod(Vector3(0, 0.16, 0), Vector3(0, 1.4, 0), 0.008, 6, Color(0.6, 0.5, 0.35))
	var head_view := MeshInstance3D.new()
	head_view.mesh = head.commit(_mats["iron"])
	_hammer.add_child(head_view)
	var rope_view := MeshInstance3D.new()
	rope_view.mesh = rope.commit(_mats["wood"])
	_hammer.add_child(rope_view)
	# The stone lying on the anvil.
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.72, 0.32, 0.85)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.roughness = 0.08
	glow.emission_enabled = true
	glow.emission = Color(0.75, 0.42, 0.1)
	glow.emission_energy_multiplier = 0.15
	var crystal := CozyMesh.new()
	var grow := RandomNumberGenerator.new()
	grow.seed = 77
	LumenPart.grow_spinstone(crystal, grow)
	var stone := MeshInstance3D.new()
	stone.mesh = crystal.commit(glow)
	_stone = Node3D.new()
	_stone.position = Vector3(0, ANVIL_TOP + 0.035, 0)
	_stone.rotation = Vector3(0, 0, PI * 0.5)
	_stone.scale = Vector3.ONE * 1.2
	add_child(_stone)
	_stone.add_child(stone)
	# The pieces: one shard shape, each drawn at its own size.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = _shard()
	mm.instance_count = PIECES
	_view = MultiMeshInstance3D.new()
	_view.multimesh = mm
	_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_view)
	# The lever, and what a player inspecting reads (drafts).
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.27)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.22, 0.22, 0.22)
	var stand := CozyMesh.new()
	var at := Vector3(-0.35, 0.0, -2.4)
	stand.box(Vector3(0.5, 0.08, 0.4), CozyMesh.at(at + Vector3(0, 0.04, 0)), Color(0.5, 0.36, 0.24))
	stand.box(Vector3(0.4, 0.5, 0.12), CozyMesh.at(at + Vector3(0, 0.33, 0)), Color(0.5, 0.36, 0.24))
	stand.box(Vector3(0.5, 0.08, 0.4), CozyMesh.at(at + Vector3(0.7, 0.04, 0)), Color(0.5, 0.36, 0.24))
	stand.box(Vector3(0.4, 0.5, 0.12), CozyMesh.at(at + Vector3(0.7, 0.33, 0)), Color(0.5, 0.36, 0.24))
	_add(stand, _mats["wood"])
	_lever = WorksHandle.new(WorksHandle.Kind.LEVER, at + Vector3(0, 0.95, 0), wood, dark,
			"Hammer\nA click drops the hammer on the sunstone; another raises it and sets a new stone.")
	_lever.on = true
	_lever.call("_show")
	_lever.thrown.connect(func(on: bool) -> void:
		if on:
			_mend()
		elif not _smashed and not _falling:
			_falling = true)
	add_child(_lever)
	var shade := WorksHandle.new(WorksHandle.Kind.LEVER, at + Vector3(0.7, 0.95, 0), wood, dark,
			"Shade\nA click swings the sunshade between the sun and the slate, or folds it back.")
	shade.on = false
	shade.call("_show")
	shade.thrown.connect(func(on: bool) -> void: _shaded = on)
	add_child(shade)
	# The sunshade: a post north of the slate, a jointed arm, a round
	# canvas on a brass hoop.
	var post := CozyMesh.new()
	post.rod(Vector3(POST.x, 0.0, POST.z), POST, 0.035, 8, Color(0.5, 0.36, 0.24))
	post.ball(0.06, 8, CozyMesh.at(POST), gold)
	_add(post, _mats["wood"])
	var rod := CozyMesh.new()
	rod.cyl(0.018, 0.018, 1.0, 6, Transform3D.IDENTITY, gold)
	_arm = MeshInstance3D.new()
	_arm.mesh = rod.commit(_mats["brass"])
	add_child(_arm)
	_shade = Node3D.new()
	add_child(_shade)
	var canvas := CozyMesh.new()
	canvas.cyl(SHADE_R, SHADE_R, 0.015, 32, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), Color(0.86, 0.8, 0.66))
	var cloth := StandardMaterial3D.new()
	cloth.vertex_color_use_as_albedo = true
	cloth.roughness = 0.95
	var canvas_view := MeshInstance3D.new()
	canvas_view.mesh = canvas.commit(cloth)
	_shade.add_child(canvas_view)
	var hoop := CozyMesh.new()
	hoop.torus(SHADE_R - 0.02, SHADE_R + 0.02, 40, 6, Transform3D.IDENTITY.rotated(Vector3.RIGHT, PI * 0.5), gold)
	_add_to(_shade, hoop, _mats["brass"])
	_place_shade()
	add_child(HoverNote.new(Vector3(0, 0.15, 0), Vector3(PATCH_R * 1.6, 0.3, PATCH_R * 1.6),
			"A smashed sunstone\nEach piece is a whole sunstone, its axis running as the stone's did. In the sun the smallest stand on end and point at it, the finest tumbling; larger ones lean; the largest lie as they fell."))


func _add(m: CozyMesh, mat: Material) -> void:
	_add_to(self, m, mat)


func _add_to(parent: Node3D, m: CozyMesh, mat: Material) -> void:
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	parent.add_child(view)


## A shard a unit box across (each side 2), its corners chipped unevenly
## and its faces flat.
func _shard() -> ArrayMesh:
	var r := RandomNumberGenerator.new()
	r.seed = 5
	var corners: Array[Vector3] = []
	for k in 8:
		var c := Vector3(1 if k & 1 else -1, 1 if k & 2 else -1, 1 if k & 4 else -1)
		corners.append(c * r.randf_range(0.7, 1.0))
	var faces := [[0, 2, 3, 1], [4, 5, 7, 6], [0, 1, 5, 4], [2, 6, 7, 3], [0, 4, 6, 2], [1, 3, 7, 5]]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for f: Array in faces:
		var a: Vector3 = corners[f[0]]
		var b: Vector3 = corners[f[1]]
		var c: Vector3 = corners[f[2]]
		var d: Vector3 = corners[f[3]]
		var n := (b - a).cross(c - a).normalized()
		if n.dot((a + b + c + d) * 0.25) < 0.0:
			n = -n
		for tri: Array in [[a, b, c], [a, c, d]]:
			for v: Vector3 in tri:
				st.set_normal(n)
				st.add_vertex(v)
	var mesh := st.commit()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	mat.roughness = 0.3
	mat.metallic_specular = 0.6
	mat.emission_enabled = true
	mat.emission = Color(0.8, 0.45, 0.12)
	mat.emission_energy_multiplier = 0.5
	mesh.surface_set_material(0, mat)
	return mesh
