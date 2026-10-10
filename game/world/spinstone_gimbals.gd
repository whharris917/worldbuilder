class_name SpinstoneGimbals
extends Node3D
## A demonstration: a row of spinstones, each free in a gyroscope's
## gimbal, each lit by its own bullseye lantern, to see what light does to
## a crystal that may take any attitude. Two rows stand on the test
## island: the combination stones (COMBO: earthstone, sunstone, moonstone,
## each both drawn to point at its body and spun by light) and the pure
## stones (PURE): the gyres, only spun by light, about their length, as
## much as it points at their body and the other way while it points
## away, so that free they spin wherever they lie; and the tropes, only
## drawn to point at their body, and only while lit, harder the brighter
## their light, so that unlit they are inert stones and lit they swing
## round, wobbling, to point at it without spinning.
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
## At the row's west end a stand with two levers (WorksHandle): one lights
## or darkens all three lanterns (their caps swinging open and shut), one
## sets the stones still in fresh attitudes each time it is thrown. The
## world hears of the first by `lamps_thrown`.
##
## The gimbal: an outer ring on an upright pin in an arch, an inner ring
## pivoting inside it on a level pin, and the crystal on a spindle across
## the inner ring, its length along the spindle. The rings weigh nothing
## and turn freely: they follow the crystal, their angles read from its
## attitude (`_pose`). The earthstone comes to rest where the gimbal is
## locked, its length along the outer ring's upright pin; there the rings
## hold still and it spins on its spindle.

## The stones of each row: their body (what they answer to), name, tint,
## how light spins them ("combo": about their length as much as it points
## at their body, none while it points away; "signed": the same, and the
## other way while it points away; "none") and how they are drawn to
## point at their body ("always", whether lit or not; "lit", in
## proportion to their light; "none").
const COMBO := [
	["earth", "Earthstone", Color(0.74, 0.62, 0.95), "combo", "always"],
	["sun", "Sunstone", Color(1.0, 0.72, 0.32), "combo", "always"],
	["moon", "Moonstone", Color(0.74, 0.84, 1.0), "combo", "always"],
]
const PURE := [
	["earth", "Geogyre", Color(0.74, 0.62, 0.95), "signed", "none"],
	["sun", "Heliogyre", Color(1.0, 0.72, 0.32), "signed", "none"],
	["moon", "Lunagyre", Color(0.74, 0.84, 1.0), "signed", "none"],
	["earth", "Geotrope", Color(0.62, 0.5, 0.85), "none", "lit"],
	["sun", "Heliotrope", Color(0.9, 0.6, 0.22), "none", "lit"],
	["moon", "Lunatrope", Color(0.6, 0.72, 0.95), "none", "lit"],
]
## What a player inspecting each reads. Drafts.
const TEXTS := {
	"Earthstone": "Earthstone in a gimbal\nOne end seeks the sky straight above, as a compass needle seeks the north; light spins it on its length. Free in its gimbal, it swings round, wobbling, to point straight up.",
	"Sunstone": "Sunstone in a gimbal\nOne end seeks the sun, wherever it stands; light spins it on its length. Free in its gimbal, it swings round, wobbling, to point at the sun, and follows it across the sky.",
	"Moonstone": "Moonstone in a gimbal\nOne end seeks the moon, wherever it stands, by day or night; light spins it on its length. Free in its gimbal, it swings round, wobbling, to point at the moon.",
	"Geogyre": "Geogyre in a gimbal\nLight spins it on its length, hardest while it stands upright, not at all while it lies level, the other way while it hangs upside down. Unlit, an inert stone. Free in its gimbal, it spins wherever it lies.",
	"Heliogyre": "Heliogyre in a gimbal\nLight spins it on its length, hardest while it points at the sun, not at all square across it, the other way while it points away. Unlit, an inert stone. Free in its gimbal, it spins wherever it lies.",
	"Lunagyre": "Lunagyre in a gimbal\nLight spins it on its length, hardest while it points at the moon, not at all square across it, the other way while it points away. Unlit, an inert stone. Free in its gimbal, it spins wherever it lies.",
	"Geotrope": "Geotrope in a gimbal\nWhile lit, one end is drawn to point straight up, the harder the brighter its light; it does not spin. Unlit, an inert stone.",
	"Heliotrope": "Heliotrope in a gimbal\nWhile lit, one end is drawn to point at the sun, the harder the brighter its light; it does not spin. Unlit, an inert stone.",
	"Lunatrope": "Lunatrope in a gimbal\nWhile lit, one end is drawn to point at the moon, the harder the brighter its light; it does not spin. Unlit, an inert stone.",
}
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
const PULL_PER_WATT := 2.0e-4           # N m a watt: a trope's twist, by its light (50 W makes PULL)
const PIVOT_DAMP := 0.003               # N m s: the gimbal pivots' friction on the length's swinging
const STEPS := 16

## Light reaching each stone, watts, while the lanterns are lit.
var light_watts := 50.0
var lit := true
## Toward the sun and the moon, set by the world each frame.
var to_sun := Vector3.UP
var to_moon := Vector3.UP

var _stones: Array[Dictionary] = []
var _lamps_lever: WorksHandle
var _open := 1.0                        # the lanterns' caps, 0 shut to 1 open

## The lanterns' lever thrown: lit or not.
signal lamps_thrown(on: bool)
var _beam_mat: StandardMaterial3D
var _mats: Dictionary
var _kinds: Array


## `mats`: "brass", "copper", "iron", "glass", "wood". `pure`: the row of
## pure stones (PURE) in place of the combination stones (COMBO).
func _init(materials: Dictionary, pure := false) -> void:
	name = "PureSpinstones" if pure else "SpinstoneGimbals"
	_kinds = PURE if pure else COMBO
	_mats = materials
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.72, 0.22, 0.9)
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	for k in _kinds.size():
		_build(k, rng)
	_build_levers()
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
		# Turning backward: about its length the other way, as a gyre does
		# pointing away from its body.
		var backward := _turning(s).dot(length) < -0.05
		lines.append("%s: %.1f turns a second%s; pointing %d degrees off %s." % [s["title"], turning / TAU,
				" backward" if backward else "", roundi(off), {"earth": "straight up", "sun": "the sun", "moon": "the moon"}[s["body"]]])
	return "\n".join(lines)


func _toward(s: Dictionary) -> Vector3:
	match str(s["body"]):
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


## The lanterns lit or not, from outside (the panel): the lever thrown to
## match.
func set_lit(on: bool) -> void:
	lit = on
	if _lamps_lever != null and _lamps_lever.on != on:
		_lamps_lever.on = on
		_lamps_lever.call("_show")


func _process(delta: float) -> void:
	_open = move_toward(_open, 1.0 if lit else 0.0, delta * 3.0)
	for s in _stones:
		LanternLook.animate(s["lamp"], _open)
		LanternLook.set_lit(s["lamp"], lit)


func _build_levers() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.27)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.22, 0.22, 0.22)
	var at := Vector3(-(_kinds.size() - 1) * 0.5 * SPACING - 1.0, 0.0, 0.9)
	var stand := CozyMesh.new()
	stand.box(Vector3(0.9, 0.08, 0.4), CozyMesh.at(at + Vector3(0, 0.04, 0)), Color(0.5, 0.36, 0.24))
	stand.box(Vector3(0.8, 0.5, 0.12), CozyMesh.at(at + Vector3(0, 0.33, 0)), Color(0.5, 0.36, 0.24))
	_view(self, stand, _mats["wood"])
	_lamps_lever = WorksHandle.new(WorksHandle.Kind.LEVER, at + Vector3(-0.2, 0.95, 0.0), wood, iron,
			"Lanterns\nA click lights all the lanterns, or darkens them.")
	_lamps_lever.on = lit
	_lamps_lever.call("_show")
	_lamps_lever.thrown.connect(func(on: bool) -> void:
		lit = on
		lamps_thrown.emit(on))
	add_child(_lamps_lever)
	var reset := WorksHandle.new(WorksHandle.Kind.LEVER, at + Vector3(0.2, 0.95, 0.0), wood, iron,
			"Reset\nA click sets the stones still, each lying a new way.")
	reset.thrown.connect(func(_on: bool) -> void: settle())
	add_child(reset)


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
			var half_momentum := momentum + _twist(s, att, w, toward, watts) * dt * 0.5
			var half_att := att
			if w.length() > 1e-9:
				half_att = (Basis(w.normalized(), w.length() * dt * 0.5) * att).orthonormalized()
			var w_mid := _turning_of(half_att, half_momentum)
			s["momentum"] = momentum + _twist(s, half_att, w_mid, toward, watts) * dt
			if w_mid.length() > 1e-9:
				s["attitude"] = (Basis(w_mid.normalized(), w_mid.length() * dt) * att).orthonormalized()
		_pose(s)
		(s["glow"] as StandardMaterial3D).emission_energy_multiplier = 0.1 + 0.8 * clampf(_turning(s).length() / 15.0, 0.0, 1.0)
		(s["beam"] as Node3D).visible = lit


## Everything turning stone `s` lying `att`, turning `w`, by its laws:
## its polarity's twist toward its body, the light's spin about its
## length, the air's drag, the pivots' friction on its length's swinging.
static func _twist(s: Dictionary, att: Basis, w: Vector3, toward: Vector3, watts: float) -> Vector3:
	var length := (att * Vector3.BACK).normalized()
	var swing := w - length * w.dot(length)
	var lined := length.dot(toward)
	var spin := 0.0
	match str(s["spin"]):
		"combo":
			spin = maxf(lined, 0.0)
		"signed":
			spin = lined
	var pull := 0.0
	match str(s["pull"]):
		"always":
			pull = PULL
		"lit":
			pull = PULL_PER_WATT * watts
	return length.cross(toward) * pull + length * TURN * watts * spin - w * w.length() * DRAG - swing * PIVOT_DAMP


## The rings read from where the crystal's length points: the outer ring
## turned to its bearing, the inner ring tilted to its height, and what
## is left of its attitude its spin on the spindle. Where the length lies
## along the outer ring's upright pin the bearing means nothing (the
## gimbal is locked), and the outer ring stays where it was, so the spin
## goes to the spindle as in a real gimbal.
func _pose(s: Dictionary) -> void:
	var att: Basis = s["attitude"]
	var length := (att * Vector3.BACK).normalized()
	var yaw: float = s.get("yaw", 0.0)
	if Vector2(length.x, length.z).length() > 0.02:
		yaw = atan2(length.x, length.z)
	s["yaw"] = yaw
	var tilt := asin(clampf(-length.y, -1.0, 1.0))
	var rings := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, tilt)
	var rest := rings.transposed() * att
	(s["outer"] as Node3D).rotation = Vector3(0, yaw, 0)
	(s["inner"] as Node3D).rotation = Vector3(tilt, 0, 0)
	(s["rotor"] as Node3D).rotation = Vector3(0, 0, atan2(rest.x.y, rest.x.x))


## ---- building ----------------------------------------------------------------

func _view(parent: Node3D, m: CozyMesh, mat: Material) -> void:
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	parent.add_child(view)


func _build(k: int, rng: RandomNumberGenerator) -> void:
	var kind: Array = _kinds[k]
	var at := Vector3((k - (_kinds.size() - 1) * 0.5) * SPACING, 0.0, 0.0)
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
	lamp.set_meta("look", look)
	var beam := MeshInstance3D.new()
	var bar := BoxMesh.new()
	bar.size = Vector3(0.03, 0.03, LAMP_OFF - 0.2 - 0.1)
	bar.material = _beam_mat
	beam.mesh = bar
	beam.position = at + Vector3(0, HEIGHT, (LAMP_OFF - 0.2 + 0.1) * 0.5)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(beam)
	# Something to inspect: what this stone is.
	var text: String = TEXTS[kind[1]]
	var body := HoverNote.new(at + Vector3(0, HEIGHT, 0), Vector3.ONE * OUTER_R * 2.0, text)
	add_child(body)
	_stones.append({"body": kind[0], "title": kind[1], "spin": kind[3], "pull": kind[4], "outer": outer, "inner": inner, "rotor": rotor,
			"glow": glow, "beam": beam, "lamp": look, "note": body, "momentum": Vector3.ZERO, "attitude": Basis.IDENTITY})
