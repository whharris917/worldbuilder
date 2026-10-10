class_name SpinstoneGimbals
extends Node3D
## A demonstration: three spinstones, each free in a gyroscope's gimbal,
## each lit by its own bullseye lantern, to see what light does to a
## crystal that may take any attitude.
##
## The kinds of spinstone differ in what they answer to: an earthstone
## to the upright (as gravity points), a sunstone to the line to the sun,
## a moonstone to the line to the moon (where they stand in the sky at
## that moment). Each is polarised along its length, one end seeking its
## body as a compass needle's north end seeks the north.
##
## The physics, with those two laws: each crystal is a rigid body, longer
## than it is wide, so it turns more easily about its length than across
## it (INERTIA_ALONG, INERTIA_ACROSS). Its polarity twists its seeking end
## toward its body, PULL newton metres at a right angle, less as it comes
## round. Light reaching it spins it about its own length, TURN newton
## metres a watt, as much as its length points at its body (none while it
## points away). The air holds back all its turning, with the square of
## the turning (DRAG); the friction of the gimbal's pivots holds back the
## swinging of its length, not its spin on the spindle (PIVOT_DAMP).
## Angular momentum is conserved between those: so the stone does not
## swing straight round but precesses as a gyroscope does, its wobble
## dying away. Its turning is its angular momentum through its inertia as
## it lies; momentum and attitude are carried forward together by the
## midpoint rule, STEPS steps a frame (checked against much finer steps).
##
## What happens: from any start each stone swings round, wobbling, and
## settles with its length pointing at its body, spinning about it as
## fast as its light allows: within half a minute or so in a lantern's
## light or none, a couple of minutes in a sun collector's, where the
## faster spin holds it stiffer. (Without the polarity it would end lying
## square across its direction, twirling end over end: a spinning body
## losing energy ends turning about its axis of greatest inertia.)
##
## The gimbal: an outer ring on an upright pin in an arch, an inner ring
## pivoting inside it on a level pin, and the crystal on a spindle across
## the inner ring, its length along the spindle. The rings weigh nothing
## and turn freely: they follow the crystal, their angles read from its
## attitude (yaw, then tilt, then spin about its length). Where the inner
## ring stands square to the outer, the gimbal locks, and the rings swing
## through at once, as a real gimbal cannot.

const KINDS := [
	["earth", "Earthstone", Color(0.74, 0.62, 0.95)],
	["sun", "Sunstone", Color(1.0, 0.72, 0.32)],
	["moon", "Moonstone", Color(0.74, 0.84, 1.0)],
]
const SPACING := 2.4                    # m between the gimbals
const HEIGHT := 1.35                    # the crystals' middles over the ground
const LAMP_OFF := 1.7                   # the lanterns stand this far south of their stones
const OUTER_R := 0.42
const INNER_R := 0.34
const INERTIA_ALONG := 0.0006           # kg m², about its length
const INERTIA_ACROSS := 0.004           # kg m², across it
const TURN := 1.0e-5                    # N m of spin for each watt of light
const DRAG := 6.0e-6                    # N m s² of the air's drag on the turning
const PULL := 0.01                      # N m: the polarity's twist, the length at a right angle to its body
const PIVOT_DAMP := 0.003               # N m s: the gimbal pivots' friction on the length's swinging
const STEPS := 16

## Light reaching each stone, watts, while the lanterns are lit.
var light_watts := 50.0
var lit := true
## Toward the sun and the moon, set by the world each frame.
var to_sun := Vector3.UP
var to_moon := Vector3.UP

var _stones: Array[Dictionary] = []
var _beam_mat: StandardMaterial3D
var _mats: Dictionary


## `mats`: "brass", "copper", "iron", "glass", "wood".
func _init(materials: Dictionary) -> void:
	name = "SpinstoneGimbals"
	_mats = materials
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.72, 0.22, 0.9)
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for k in KINDS.size():
		_build(k, rng)
	settle()


## The stones set still, each in an attitude of its own.
func settle() -> void:
	var rng := RandomNumberGenerator.new()
	for s in _stones:
		s["momentum"] = Vector3.ZERO
		s["attitude"] = Basis.from_euler(Vector3(rng.randf_range(-1.0, 1.0), rng.randf() * TAU, rng.randf() * TAU))
		_pose(s)


## A line for each stone: how fast it turns and how its length lies to
## its kind's direction.
func report() -> String:
	var lines: Array[String] = []
	for s in _stones:
		var att: Basis = s["attitude"]
		var turning := _turning(s).length()
		var length := (att * Vector3.BACK).normalized()
		var off := rad_to_deg(acos(clampf(length.dot(_toward(s)), -1.0, 1.0)))
		lines.append("%s: %.1f turns a second; pointing %d degrees off %s." % [s["title"], turning / TAU, roundi(off),
				{"earth": "straight up", "sun": "the sun", "moon": "the moon"}[s["kind"]]])
	return "\n".join(lines)


func _toward(s: Dictionary) -> Vector3:
	match str(s["kind"]):
		"sun":
			return to_sun
		"moon":
			return to_moon
	return Vector3.UP


## Its turning, radians a second (world): its angular momentum through
## its inertia as it lies.
func _turning(s: Dictionary) -> Vector3:
	return _turning_of(s["attitude"], s["momentum"])


static func _turning_of(att: Basis, momentum: Vector3) -> Vector3:
	var body := att.transposed() * momentum
	return att * Vector3(body.x / INERTIA_ACROSS, body.y / INERTIA_ACROSS, body.z / INERTIA_ALONG)


func _physics_process(delta: float) -> void:
	var dt := delta / STEPS
	for s in _stones:
		var toward := _toward(s)
		var watts := light_watts if lit else 0.0
		for i in STEPS:
			# Half a step to the middle, then the whole step by the middle's
			# turning and pull.
			var att: Basis = s["attitude"]
			var momentum: Vector3 = s["momentum"]
			var w := _turning_of(att, momentum)
			var half_momentum := momentum + _twist(att, w, toward, watts) * dt * 0.5
			var half_att := att
			if w.length() > 1e-9:
				half_att = (Basis(w.normalized(), w.length() * dt * 0.5) * att).orthonormalized()
			var w_mid := _turning_of(half_att, half_momentum)
			s["momentum"] = momentum + _twist(half_att, w_mid, toward, watts) * dt
			if w_mid.length() > 1e-9:
				s["attitude"] = (Basis(w_mid.normalized(), w_mid.length() * dt) * att).orthonormalized()
		_pose(s)
		(s["glow"] as StandardMaterial3D).emission_energy_multiplier = 0.1 + 0.8 * clampf(_turning(s).length() / 15.0, 0.0, 1.0)
		(s["beam"] as Node3D).visible = lit


## Everything turning a stone lying `att`, turning `w`: its polarity's
## twist toward its body, the light's spin about its length, the air's
## drag, the pivots' friction on its length's swinging.
static func _twist(att: Basis, w: Vector3, toward: Vector3, watts: float) -> Vector3:
	var length := (att * Vector3.BACK).normalized()
	var swing := w - length * w.dot(length)
	return length.cross(toward) * PULL + length * TURN * watts * maxf(length.dot(toward), 0.0) 			- w * w.length() * DRAG - swing * PIVOT_DAMP


## The rings and the crystal set to the stone's attitude.
func _pose(s: Dictionary) -> void:
	var e := (s["attitude"] as Basis).get_euler(EULER_ORDER_YXZ)
	(s["outer"] as Node3D).rotation = Vector3(0, e.y, 0)
	(s["inner"] as Node3D).rotation = Vector3(e.x, 0, 0)
	(s["rotor"] as Node3D).rotation = Vector3(0, 0, e.z)


## ---- building ----------------------------------------------------------------

func _view(parent: Node3D, m: CozyMesh, mat: Material) -> void:
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	parent.add_child(view)


func _build(k: int, rng: RandomNumberGenerator) -> void:
	var kind: Array = KINDS[k]
	var at := Vector3((k - 1) * SPACING, 0.0, 0.0)
	var gold := Color(0.85, 0.66, 0.32)
	var oak := Color(0.5, 0.36, 0.24)
	# A stand: a wooden plinth, an arch of brass over the gimbal, the
	# outer ring's pins below and above.
	var stand := CozyMesh.new()
	var wood := CozyMesh.new()
	wood.box(Vector3(1.2, 0.12, 0.6), CozyMesh.at(at + Vector3(0, 0.06, 0)), oak)
	wood.box(Vector3(0.24, 0.36, 0.24), CozyMesh.at(at + Vector3(0, 0.3, 0)), oak.darkened(0.1))
	var top := HEIGHT + OUTER_R + 0.12
	for sx: float in [-1.0, 1.0]:
		stand.rod(at + Vector3(sx * 0.52, 0.12, 0), at + Vector3(sx * 0.52, top, 0), 0.025, 8, gold)
		stand.ball(0.035, 8, CozyMesh.at(at + Vector3(sx * 0.52, top, 0)), gold)
	stand.rod(at + Vector3(-0.52, top, 0), at + Vector3(0.52, top, 0), 0.025, 8, gold)
	stand.cyl(0.012, 0.012, 0.12, 8, CozyMesh.at(at + Vector3(0, HEIGHT - OUTER_R - 0.07, 0)), gold)
	stand.cyl(0.03, 0.04, 0.05, 10, CozyMesh.at(at + Vector3(0, HEIGHT - OUTER_R - 0.13, 0)), gold)
	stand.cyl(0.012, 0.012, 0.12, 8, CozyMesh.at(at + Vector3(0, HEIGHT + OUTER_R + 0.06, 0)), gold)
	_view(self, stand, _mats["brass"])
	_view(self, wood, _mats["wood"])
	# The outer ring, upright, turning on the upright pins.
	var outer := Node3D.new()
	outer.position = at + Vector3(0, HEIGHT, 0)
	add_child(outer)
	var o := CozyMesh.new()
	o.torus(OUTER_R - 0.02, OUTER_R + 0.02, 40, 8, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), gold)
	for sx: float in [-1.0, 1.0]:
		o.cyl(0.018, 0.018, OUTER_R - INNER_R, 8, CozyMesh.at(Vector3(sx * (OUTER_R + INNER_R) * 0.5, 0, 0), Basis(Vector3.FORWARD, PI * 0.5)), gold)
	_view(outer, o, _mats["brass"])
	# The inner ring, level at rest, pivoting on the outer ring's pins.
	var inner := Node3D.new()
	outer.add_child(inner)
	var n := CozyMesh.new()
	n.torus(INNER_R - 0.016, INNER_R + 0.016, 40, 8, Transform3D.IDENTITY, Color(0.72, 0.42, 0.26))
	for sz: float in [-1.0, 1.0]:
		n.cyl(0.022, 0.022, 0.04, 10, CozyMesh.at(Vector3(0, 0, sz * (INNER_R - 0.02)), Basis(Vector3.RIGHT, PI * 0.5)), gold)
	_view(inner, n, _mats["copper"])
	# The crystal on its spindle across the inner ring, its length along
	# the spindle.
	var rotor := Node3D.new()
	inner.add_child(rotor)
	var spindle := CozyMesh.new()
	spindle.cyl(0.006, 0.006, INNER_R * 2.0 - 0.06, 8, CozyMesh.at(Vector3.ZERO, Basis(Vector3.RIGHT, PI * 0.5)), Color(0.75, 0.77, 0.8))
	_view(rotor, spindle, _mats["iron"])
	var glow := StandardMaterial3D.new()
	var tint: Color = kind[2]
	glow.albedo_color = Color(tint, 0.85)
	glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glow.roughness = 0.08
	glow.metallic_specular = 0.9
	glow.emission_enabled = true
	glow.emission = Color.from_hsv(tint.h, minf(tint.s * 1.6, 1.0), tint.v * 0.75)
	var stone := CozyMesh.new()
	var grow := RandomNumberGenerator.new()
	grow.seed = rng.randi()
	LumenPart.grow_spinstone(stone, grow)
	var crystal := MeshInstance3D.new()
	crystal.mesh = stone.commit(glow)
	# Grown upright round its spindle; laid along this one, made larger.
	crystal.transform = Transform3D(Basis(Vector3.RIGHT, PI * 0.5).scaled(Vector3.ONE * 1.9), Vector3(0, 0, -0.016 * 1.9))
	rotor.add_child(crystal)
	# Its lantern to the south, lit, aimed at it, and its beam.
	var lamp := Node3D.new()
	lamp.position = at + Vector3(0, HEIGHT, LAMP_OFF)
	add_child(lamp)
	var post := CozyMesh.new()
	post.cyl(0.02, 0.025, HEIGHT - 0.12, 8, CozyMesh.at(Vector3(0, -(HEIGHT - 0.12) * 0.5 - 0.12, 0)), gold)
	post.cyl(0.12, 0.14, 0.04, 16, CozyMesh.at(Vector3(0, -HEIGHT + 0.02, 0)), gold)
	_view(lamp, post, _mats["brass"])
	var head := Node3D.new()
	lamp.add_child(head)
	var look := LanternLook.build("bullseye", head, _mats)
	LanternLook.animate(look, 1.0)
	LanternLook.set_lit(look, true)
	var beam := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.03, 0.03, LAMP_OFF - 0.2 - 0.1)
	bar.material = _beam_mat
	beam.mesh = bar
	beam.position = at + Vector3(0, HEIGHT, (LAMP_OFF - 0.2 + 0.1) * 0.5)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	# Something to inspect: what this stone is.
	var text: String = {
		"earth": "Earthstone in a gimbal
One end seeks the sky straight above, as a compass needle seeks the north; light spins it on its length. Free in its gimbal, it swings round, wobbling, to point straight up.",
		"sun": "Sunstone in a gimbal
One end seeks the sun, wherever it stands; light spins it on its length. Free in its gimbal, it swings round, wobbling, to point at the sun, and follows it across the sky.",
		"moon": "Moonstone in a gimbal
One end seeks the moon, wherever it stands, by day or night; light spins it on its length. Free in its gimbal, it swings round, wobbling, to point at the moon.",
	}[kind[0]]
	var body := HoverNote.new(at + Vector3(0, HEIGHT, 0), Vector3.ONE * OUTER_R * 2.0, text)
	add_child(body)
	_stones.append({"kind": kind[0], "title": kind[1], "outer": outer, "inner": inner, "rotor": rotor,
			"glow": glow, "beam": beam, "body": body, "momentum": Vector3.ZERO, "attitude": Basis.IDENTITY})
