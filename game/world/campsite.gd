class_name Campsite
extends Node3D
## A small campsite on a beach: a ridge tent with its door toward a
## campfire in a ring of stones, two logs to sit on, a kettle on a flat
## stone, a chopping stump with an axe in it and a stack of split wood,
## a crate with a lantern on it, a cool box, a rolled bedroll, and a
## string of little lights from the tent's front pole to a stick. Every
## still part is one mesh painted in vertex colours (CozyMesh); the
## lantern's glass and the little lights are a second, glowing at night.
##
## Laid out in its own frame: x along the shore, z out to sea, y up. The
## ground's height is asked of the world (`build`).

const FIRE := Vector3(0.0, 0.0, 0.8)
const TENT := Vector3(-2.7, 0.0, -1.5)
const TENT_SIZE := Vector3(2.0, 1.35, 2.4)  # width, ridge height, length
const STRING_POLE := Vector3(2.4, 0.0, -2.4)
const BULBS := 11

var _mat: StandardMaterial3D
var _plain: StandardMaterial3D
var _glow_mat: StandardMaterial3D
var _lantern_light: OmniLight3D
var _string_light: OmniLight3D
var _height: Callable
var _fire: Campfire


## `mat` takes outlines, `plain` (for thin things) none.
func _init(mat: StandardMaterial3D, plain: StandardMaterial3D) -> void:
	name = "Campsite"
	_mat = mat
	_plain = plain


## Builds everything, standing on the ground `height(x, z)` (world
## coordinates); called once the site is placed.
func build(height: Callable) -> void:
	_height = height
	var m := CozyMesh.new()
	var thin := CozyMesh.new()
	var glow := CozyMesh.new()
	_fire_ring(m)
	_seats(m)
	_tent(m, thin)
	_wood(m)
	_crate_and_lantern(m, thin, glow)
	_cool_box(m)
	_bedroll(m)
	_lights(m, thin, glow)
	_view("Camp", m.commit(_mat))
	_view("CampThin", thin.commit(_plain))
	_glow_mat = StandardMaterial3D.new()
	_glow_mat.vertex_color_use_as_albedo = true
	_glow_mat.emission_enabled = true
	_glow_mat.emission = Color(1.0, 0.72, 0.38)
	_view("CampGlow", glow.commit(_glow_mat)).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_fire = Campfire.new()
	_fire.position = ground(FIRE) + Vector3(0, 0.08, 0)
	add_child(_fire)


## The lights by how dark it is, 0 by day to 1 at night.
func set_night(night: float) -> void:
	_glow_mat.emission_energy_multiplier = 0.2 + 3.0 * night
	_lantern_light.light_energy = 0.9 * night
	_lantern_light.visible = night > 0.01
	_string_light.light_energy = 0.5 * night
	_string_light.visible = night > 0.01


## A point of the site's frame on the ground there.
func ground(p: Vector3) -> Vector3:
	var g := to_global(Vector3(p.x, 0.0, p.z))
	return Vector3(p.x, float(_height.call(g.x, g.z)) - global_position.y, p.z)


func _view(title: String, mesh: Mesh) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.name = title
	view.mesh = mesh
	add_child(view)
	return view


## A solid for the player to bump into: a box `size` at `xf`.
func _block(size: Vector3, xf: Transform3D) -> void:
	var body := StaticBody3D.new()
	body.transform = xf
	var shape := BoxShape3D.new()
	shape.size = size
	var c := CollisionShape3D.new()
	c.shape = shape
	body.add_child(c)
	add_child(body)


## A log lying from a to b, bark round it and pale cut ends.
func _log(m: CozyMesh, a: Vector3, b: Vector3, radius: float, bark: Color) -> void:
	m.rod(a, b, radius, 9, bark)
	var dir := (b - a).normalized()
	for end: Vector3 in [a, b]:
		var out := dir if end == b else -dir
		m.cyl(radius * 0.86, radius * 0.86, 0.012, 9, CozyMesh.at(end + out * 0.004, CozyMesh.aligned(dir)),
				Color(0.86, 0.72, 0.5))


## ---- the fire --------------------------------------------------------------

func _fire_ring(m: CozyMesh) -> void:
	var at := ground(FIRE)
	var greys := [Color(0.63, 0.61, 0.58), Color(0.55, 0.54, 0.57), Color(0.7, 0.66, 0.6)]
	for k in 10:
		var t := TAU * k / 10.0 + 0.2
		var size := Vector3(0.2, 0.13, 0.16) * (1.0 + 0.15 * sin(k * 2.3))
		var b := Basis(Vector3.UP, -t + 0.4 * sin(k * 1.7)) * Basis.from_scale(size)
		m.ball(1.0, 8, CozyMesh.at(at + Vector3(cos(t), 0.05, sin(t)) * 0.62, b), greys[k % 3])
	# Ash in the ring, and three charred logs leaning in a low cone.
	m.cyl(0.5, 0.52, 0.04, 14, CozyMesh.at(at + Vector3(0, 0.01, 0)), Color(0.3, 0.28, 0.27))
	for k in 3:
		var out := Vector3(cos(TAU * k / 3.0 + 0.5), 0.0, sin(TAU * k / 3.0 + 0.5))
		m.rod(at + out * 0.42 + Vector3(0, 0.04, 0), at + Vector3(0, 0.32, 0) + out * 0.04, 0.065, 7, Color(0.24, 0.18, 0.15))
	# A flat stone outside the ring and a kettle on it.
	var stone := ground(FIRE + Vector3(0.95, 0.0, 0.35))
	m.cyl(0.2, 0.24, 0.08, 9, CozyMesh.at(stone + Vector3(0, 0.03, 0)), Color(0.58, 0.56, 0.55))
	var k0 := stone + Vector3(0, 0.07, 0)
	var enamel := Color(0.74, 0.24, 0.19)
	m.cyl(0.1, 0.13, 0.15, 14, CozyMesh.at(k0 + Vector3(0, 0.075, 0)), enamel)
	m.ball(0.1, 14, CozyMesh.at(k0 + Vector3(0, 0.15, 0)), enamel, true, 0.06)
	m.cyl(0.03, 0.04, 0.03, 8, CozyMesh.at(k0 + Vector3(0, 0.2, 0)), Color(0.15, 0.13, 0.12))
	m.rod(k0 + Vector3(-0.1, 0.05, 0), k0 + Vector3(-0.2, 0.15, 0), 0.016, 6, enamel)
	m.torus(0.085, 0.1, 10, 6, CozyMesh.at(k0 + Vector3(0, 0.17, 0), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.2, 0.18, 0.17))


## Two logs to sit on facing the fire, and a stump.
func _seats(m: CozyMesh) -> void:
	var bark := Color(0.5, 0.36, 0.25)
	for t: float in [deg_to_rad(15.0), deg_to_rad(-62.0)]:
		var at := FIRE + Vector3(cos(t), 0.0, sin(t)) * 1.8
		var along := Vector3(-sin(t), 0.0, cos(t)) * 0.78
		var a := ground(at - along) + Vector3(0, 0.17, 0)
		var b := ground(at + along) + Vector3(0, 0.17, 0)
		_log(m, a, b, 0.18, bark)
		var mid := (a + b) * 0.5
		_block(Vector3(0.36, 1.56, 0.36), Transform3D(CozyMesh.aligned(b - a), mid))


## ---- the tent --------------------------------------------------------------

## A ridge tent of orange canvas, its door toward the fire with the flaps
## rolled back, a pole at each end standing a little over the ridge, guy
## lines to pegs fore and aft and along the sides, a groundsheet.
func _tent(m: CozyMesh, thin: CozyMesh) -> void:
	var at := ground(TENT)
	var to_fire := FIRE - TENT
	to_fire.y = 0.0
	# The tent's own frame: z toward the door.
	var b := Basis.looking_at(-to_fire.normalized(), Vector3.UP)
	var tf := Transform3D(b, at)
	var w := TENT_SIZE.x
	var h := TENT_SIZE.y
	var l := TENT_SIZE.z
	var canvas := Color(0.86, 0.5, 0.28)
	var dark := Color(0.2, 0.15, 0.12)
	m.box(Vector3(w + 0.3, 0.03, l + 0.25), tf * CozyMesh.at(Vector3(0, 0.0, 0.05)), Color(0.33, 0.37, 0.27))
	m.prism(Vector3(w, h, l), tf * CozyMesh.at(Vector3(0, h * 0.5 + 0.015, 0)), canvas)
	# A seam strip along the ridge, and one down each end.
	m.box(Vector3(0.07, 0.035, l + 0.02), tf * CozyMesh.at(Vector3(0, h + 0.005, 0)), canvas.darkened(0.25))
	# The door: the dark inside, two-thirds of the end's height, with
	# rolled flaps along its edges.
	var dh := h * 0.82
	m.prism(Vector3(w * 0.62, dh, 0.02), tf * CozyMesh.at(Vector3(0, dh * 0.5 + 0.02, l * 0.5 + 0.005)), dark)
	for s: float in [-1.0, 1.0]:
		var top := Vector3(0, dh + 0.02, l * 0.5 + 0.03)
		var foot := Vector3(s * w * 0.31, 0.06, l * 0.5 + 0.03)
		m.rod(tf * top.lerp(foot, 0.08), tf * foot, 0.045, 8, canvas.darkened(0.08))
		# A tie holding the roll back.
		m.torus(0.04, 0.06, 8, 6, tf * CozyMesh.at(top.lerp(foot, 0.6), CozyMesh.aligned(foot - top)), Color(0.85, 0.8, 0.68))
	# Poles, each with a knob over the ridge.
	var wood := Color(0.62, 0.46, 0.3)
	for e: float in [-1.0, 1.0]:
		var foot := Vector3(0, 0.0, e * (l * 0.5 + 0.02))
		var top := Vector3(0, h + 0.16, e * (l * 0.5 + 0.02))
		m.rod(tf * foot, tf * top, 0.025, 6, wood)
		m.ball(0.04, 8, tf * CozyMesh.at(top), wood.darkened(0.2))
		# Guy line from the pole's top to a peg out along the ridge's line.
		var peg := Vector3(0, 0.0, e * (l * 0.5 + 1.1))
		peg = tf.affine_inverse() * ground(tf * peg)
		thin.rod(tf * (top - Vector3(0, 0.04, 0)), tf * (peg + Vector3(0, 0.08, 0)), 0.006, 4, Color(0.92, 0.88, 0.78))
		_peg(thin, tf * peg)
	# Pegs at the canvas's foot, and a guy line from each side's middle.
	for s: float in [-1.0, 1.0]:
		for e: float in [-1.0, 1.0]:
			var corner := Vector3(s * (w * 0.5 + 0.05), 0.0, e * l * 0.48)
			_peg(thin, tf * corner)
		var hold := Vector3(s * w * 0.27, h * 0.45, 0)
		var peg := tf.affine_inverse() * ground(tf * Vector3(s * (w * 0.5 + 0.8), 0.0, 0))
		thin.rod(tf * hold, tf * (peg + Vector3(0, 0.08, 0)), 0.006, 4, Color(0.92, 0.88, 0.78))
		_peg(thin, tf * peg)
	_block(Vector3(w, h, l), tf * CozyMesh.at(Vector3(0, h * 0.5, 0)))


func _peg(thin: CozyMesh, p: Vector3) -> void:
	var at := ground(p)
	thin.box(Vector3(0.025, 0.14, 0.025), CozyMesh.at(at + Vector3(0, 0.04, 0), Basis(Vector3.RIGHT, 0.25)), Color(0.55, 0.42, 0.28))
	thin.box(Vector3(0.06, 0.02, 0.03), CozyMesh.at(at + Vector3(0, 0.1, 0.02)), Color(0.55, 0.42, 0.28))


## ---- the wood --------------------------------------------------------------

## A chopping stump with an axe in its top, and split wood stacked in
## three rows beside it.
func _wood(m: CozyMesh) -> void:
	var stump := ground(Vector3(3.3, 0.0, -1.0))
	m.cyl(0.27, 0.31, 0.46, 12, CozyMesh.at(stump + Vector3(0, 0.21, 0)), Color(0.46, 0.33, 0.23))
	m.cyl(0.265, 0.265, 0.02, 12, CozyMesh.at(stump + Vector3(0, 0.445, 0)), Color(0.84, 0.7, 0.5))
	var top := stump + Vector3(0.05, 0.47, 0.0)
	var lean := Basis(Vector3.FORWARD, 0.5)
	m.box(Vector3(0.05, 0.16, 0.13), CozyMesh.at(top + lean * Vector3(0, 0.02, 0), lean), Color(0.5, 0.52, 0.55))
	m.rod(top + lean * Vector3(0, 0.08, 0), top + lean * Vector3(0, 0.72, 0), 0.02, 6, Color(0.72, 0.55, 0.36))
	_block(Vector3(0.56, 0.46, 0.56), CozyMesh.at(stump + Vector3(0, 0.23, 0)))
	var pile := ground(Vector3(3.6, 0.0, 0.2))
	var bark := Color(0.48, 0.35, 0.24)
	for row in 3:
		for k in 3 - row:
			var x := (k - (2 - row) * 0.5) * 0.19
			var y := 0.085 + row * 0.155
			var a := pile + Vector3(x, y, -0.32 + 0.02 * sin(k * 3.1 + row))
			var b := pile + Vector3(x, y, 0.32 + 0.02 * cos(k * 2.3 + row))
			_log(m, a, b, 0.085, bark)
	_block(Vector3(0.6, 0.45, 0.66), CozyMesh.at(pile + Vector3(0, 0.22, 0)))


## ---- the crate, the lantern, the cool box, the bedroll ---------------------

func _crate_and_lantern(m: CozyMesh, thin: CozyMesh, glow: CozyMesh) -> void:
	var at := ground(Vector3(-0.7, 0.0, -2.4))
	var turn := Basis(Vector3.UP, 0.3)
	var plank := Color(0.74, 0.57, 0.38)
	var size := Vector3(0.62, 0.44, 0.46)
	m.box(size, CozyMesh.at(at + Vector3(0, size.y * 0.5, 0), turn), plank)
	# Slats on its sides: darker boards proud of the box.
	for y: float in [0.1, 0.34]:
		m.box(Vector3(size.x + 0.02, 0.07, size.z + 0.02), CozyMesh.at(at + Vector3(0, y, 0), turn), plank.darkened(0.15))
	for s: float in [-1.0, 1.0]:
		m.box(Vector3(0.06, size.y, size.z + 0.03), CozyMesh.at(at + turn * Vector3(s * (size.x * 0.5 - 0.02), size.y * 0.5, 0), turn), plank.darkened(0.22))
	_block(size, CozyMesh.at(at + Vector3(0, size.y * 0.5, 0), turn))
	# The lantern: a base, a glass, a hood, a wire handle.
	var l0 := at + Vector3(0.1, size.y, 0.02)
	var iron := Color(0.22, 0.24, 0.22)
	m.cyl(0.075, 0.085, 0.04, 12, CozyMesh.at(l0 + Vector3(0, 0.02, 0)), iron)
	glow.cyl(0.055, 0.06, 0.14, 12, CozyMesh.at(l0 + Vector3(0, 0.11, 0)), Color(1.0, 0.86, 0.6))
	for k in 4:
		var t := TAU * k / 4.0 + 0.4
		thin.rod(l0 + Vector3(cos(t) * 0.066, 0.04, sin(t) * 0.066), l0 + Vector3(cos(t) * 0.06, 0.18, sin(t) * 0.06), 0.006, 4, iron)
	m.cyl(0.02, 0.08, 0.05, 12, CozyMesh.at(l0 + Vector3(0, 0.205, 0)), iron)
	thin.torus(0.068, 0.078, 12, 4, CozyMesh.at(l0 + Vector3(0, 0.23, 0), Basis(Vector3.RIGHT, PI * 0.5)), iron)
	_lantern_light = OmniLight3D.new()
	_lantern_light.light_color = Color(1.0, 0.72, 0.4)
	_lantern_light.omni_range = 5.0
	_lantern_light.omni_attenuation = 2.0
	_lantern_light.position = l0 + Vector3(0, 0.12, 0)
	add_child(_lantern_light)


func _cool_box(m: CozyMesh) -> void:
	var at := ground(Vector3(-4.4, 0.0, -0.2))
	var turn := Basis(Vector3.UP, -0.5)
	var blue := Color(0.32, 0.54, 0.72)
	m.box(Vector3(0.68, 0.34, 0.4), CozyMesh.at(at + Vector3(0, 0.17, 0), turn), blue)
	m.box(Vector3(0.7, 0.07, 0.42), CozyMesh.at(at + Vector3(0, 0.37, 0), turn), Color(0.94, 0.93, 0.88))
	for s: float in [-1.0, 1.0]:
		m.box(Vector3(0.03, 0.04, 0.14), CozyMesh.at(at + turn * Vector3(s * 0.355, 0.3, 0), turn), Color(0.9, 0.9, 0.86))
	_block(Vector3(0.7, 0.41, 0.42), CozyMesh.at(at + Vector3(0, 0.2, 0), turn))


func _bedroll(m: CozyMesh) -> void:
	var a := ground(Vector3(-4.0, 0.0, -1.3)) + Vector3(0, 0.15, 0)
	var b := ground(Vector3(-4.2, 0.0, -2.0)) + Vector3(0, 0.15, 0)
	var wool := Color(0.66, 0.24, 0.2)
	m.rod(a, b, 0.15, 12, wool)
	for f: float in [0.0, 1.0]:
		var end := a.lerp(b, f)
		m.cyl(0.12, 0.12, 0.01, 12, CozyMesh.at(end + (b - a).normalized() * (0.002 if f > 0.5 else -0.002), CozyMesh.aligned(b - a)), Color(0.88, 0.78, 0.6))
	for f: float in [0.22, 0.78]:
		m.torus(0.15, 0.17, 12, 4, CozyMesh.at(a.lerp(b, f), CozyMesh.aligned(b - a)), Color(0.38, 0.25, 0.16))


## ---- the little lights ------------------------------------------------------

## A stick driven into the sand, and a string of little bulbs hanging
## from the tent's front pole to it.
func _lights(m: CozyMesh, thin: CozyMesh, glow: CozyMesh) -> void:
	var stick := ground(STRING_POLE)
	var stick_top := stick + Vector3(0, 1.75, 0)
	m.rod(stick + Vector3(0, -0.1, 0), stick_top + Vector3(0.03, 0.08, 0), 0.03, 6, Color(0.6, 0.5, 0.38))
	var to_fire := FIRE - TENT
	to_fire.y = 0.0
	var front := ground(TENT) + to_fire.normalized() * (TENT_SIZE.z * 0.5 + 0.02) + Vector3(0, TENT_SIZE.y + 0.08, 0)
	var sag := 0.35
	var prev := front
	var mid := Vector3.ZERO
	for k in range(1, BULBS + 2):
		var f := float(k) / float(BULBS + 1)
		var p := front.lerp(stick_top, f) - Vector3(0, sag * 4.0 * f * (1.0 - f), 0)
		thin.rod(prev, p, 0.005, 4, Color(0.18, 0.18, 0.16))
		if k <= BULBS:
			glow.ball(0.028, 8, CozyMesh.at(p + Vector3(0, -0.035, 0)), Color(1.0, 0.85, 0.6))
		if k == (BULBS + 1) / 2:
			mid = p
		prev = p
	_string_light = OmniLight3D.new()
	_string_light.light_color = Color(1.0, 0.75, 0.45)
	_string_light.omni_range = 4.5
	_string_light.omni_attenuation = 2.0
	_string_light.shadow_enabled = false
	_string_light.position = mid
	add_child(_string_light)
