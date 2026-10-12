class_name Heliostat
extends Node3D
## A heliostat for the burning glass (BurningGlass): a flat mirror of
## period glass panes, silvered with tin and mercury (REFLECT of the light
## back), in a wooden frame on a fork at the top of a mast, turned by hand
## from the mast's foot: one crank turns the fork round on its turntable
## (the mirror's bearing), the other tilts the mirror in the fork, each by
## its own shaft up the mast. Set right, the mirror throws the sun down
## the axis of the lens's barrel; the sun moves on, so the player sets it
## again every minute or two.
##
## A mirror turns light well only through a wide angle: here the sun, high
## in the south, is thrown back down toward the south, so the mirror
## stands nearly upright facing south and meets the sun at about 60
## degrees; its height is foreshortened by half seen from the lens, so the
## mirror is SIZE.y tall to fill a lens 1.2 m across.
##
## The light it sends: the sun's, REFLECT of it, along the sun's direction
## reflected in the mirror. A point of the lens is lit when the line back
## from it along that light passes inside the barrel's mouth and meets
## the mirror's glass (`reaches`), so a mirror set a little off fills part
## of the lens and one set well off misses it. The barrel's walls keep the
## sun's direct light off the lens.
##
## Built in the house's frame: this node at the mast's foot, the mirror's
## middle MAST_H over it.

const REFLECT := 0.7                    # tin and mercury behind glass
const SIZE := Vector2(1.8, 3.0)         # m: the mirror, across and up its face
const PANES := Vector2i(3, 5)
const MAST_H := 7.9                     # m: the mirror's middle over the ground
const PIVOT := 1.7                      # m: its trunnions over the fork's foot, clear of the mirror's swing
const TURN_RATE := 1.5                  # degrees a second, a crank held
const BARREL := 1.0                     # m: the barrel's mouth from the lens, along its axis
const BARREL_R := 0.63                  # m: inside

## The mirror's face: its bearing from north toward east and its tilt
## over level, degrees.
var bearing := 180.0
var tilt := 5.0
var glass: BurningGlass

var _to_sun := Vector3.UP
var _sunlight := 0.0
var _fork := Node3D.new()
var _mirror := Node3D.new()
var _shafts: Array[Node3D] = []
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _wood: Material
var _out: Material


func _init(lens: BurningGlass, wood: Material, outside: Material) -> void:
	name = "Heliostat"
	glass = lens
	_wood = wood
	_out = outside


func _ready() -> void:
	_build()
	glass.reaches = reaches
	_place()


## The mirror's face, its normal (global).
func face() -> Vector3:
	var b := deg_to_rad(bearing)
	var t := deg_to_rad(tilt)
	return global_basis * Vector3(sin(b) * cos(t), sin(t), -cos(b) * cos(t))


## The mirror's middle (global).
func middle() -> Vector3:
	return to_global(Vector3(0, MAST_H, 0))


## The sun's direction and direct light, from the world: what the mirror
## sends the lens follows.
func set_sun(to_sun: Vector3, sunlight: float) -> void:
	_to_sun = to_sun
	_sunlight = sunlight
	var n := face()
	var lit := _to_sun.dot(n) > 0.0 and _sunlight > 0.0
	# The light leaves the mirror along the sun's light reflected; the
	# lens sees it come from the mirror's side.
	var going := (-_to_sun).bounce(n)
	glass.source = -going
	glass.light = _sunlight * REFLECT if lit else 0.0


## How far the mirror is from sending the sun down the barrel's axis,
## degrees.
func off_axis() -> float:
	return rad_to_deg(glass.source.angle_to(glass.global_basis.y))


## Whether the light reaches the lens point `at` (global): back along the
## light, inside the barrel's mouth and on the mirror's glass.
func reaches(at: Vector3) -> float:
	var back := glass.source
	var axis := glass.global_basis.y.normalized()
	var along := back.dot(axis)
	if along <= 0.01:
		return 0.0
	var mouth := at + back * ((BARREL - (at - glass.global_position).dot(axis)) / along)
	var off := mouth - glass.global_position - axis * BARREL
	if off.length() > BARREL_R:
		return 0.0
	# The lens in front of the glass: the line back to the mirror meets
	# its face against its normal.
	var n := face()
	var facing := back.dot(n)
	if facing >= -0.01:
		return 0.0
	var hit := at + back * ((middle() - at).dot(n) / facing)
	var frame := _mirror.global_basis
	var rel := hit - middle()
	if absf(rel.dot(frame.x.normalized())) > SIZE.x * 0.5 or absf(rel.dot(frame.y.normalized())) > SIZE.y * 0.5:
		return 0.0
	return 1.0


## A crank held: `which` "bearing" or "tilt", `way` 1 or -1, for `delta`.
func crank(which: String, way: float, delta: float) -> void:
	if which == "bearing":
		bearing = fposmod(bearing + TURN_RATE * way * delta, 360.0)
		_shafts[0].rotate_y(way * delta * 6.0)
	else:
		tilt = clampf(tilt + TURN_RATE * way * delta, -60.0, 80.0)
		_shafts[1].rotate_y(way * delta * 6.0)
	_place()
	set_sun(_to_sun, _sunlight)


func _process(_delta: float) -> void:
	_show_beam()


## The fork turned to the bearing, the mirror tilted in it.
func _place() -> void:
	_fork.rotation = Vector3(0, PI - deg_to_rad(bearing), 0)
	_mirror.rotation = Vector3(-deg_to_rad(tilt), 0, 0)


## The light leaving the mirror, a faint shaft in the air to where it
## meets something.
func _show_beam() -> void:
	if glass.light <= 0.0:
		_beam.visible = false
		return
	var going := -glass.source
	var from := middle() + going * 0.1
	var ray := PhysicsRayQueryParameters3D.create(from, from + going * 20.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	var reach := 20.0 if hit.is_empty() else from.distance_to(hit["position"])
	_beam.visible = true
	_beam.global_transform = Transform3D(CozyMesh.aligned(going).scaled_local(Vector3(1, reach, 1)), from + going * reach * 0.5)
	_beam_mat.albedo_color.a = 0.02 * clampf(glass.light / 600.0, 0.0, 1.0)


func _build() -> void:
	var m := CozyMesh.new()
	var timber := Color(0.42, 0.32, 0.22)
	var iron := Color(0.22, 0.21, 0.2)
	var brass := Color(0.76, 0.58, 0.3)
	var top := MAST_H - PIVOT - 0.08
	# The mast: a squared timber on a stone footing, four raking stays,
	# rungs up its north face.
	m.box(Vector3(0.8, 0.3, 0.8), CozyMesh.at(Vector3(0, 0.15, 0)), Color(0.55, 0.52, 0.46))
	m.box(Vector3(0.26, top, 0.26), CozyMesh.at(Vector3(0, top * 0.5, 0)), timber)
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var foot := Vector3(cos(a), 0.05, sin(a)) * 1.6
		m.rod(foot, Vector3(0, top * 0.45, 0), 0.06, 6, timber.darkened(0.1))
		m.box(Vector3(0.3, 0.2, 0.3), CozyMesh.at(foot), Color(0.55, 0.52, 0.46))
	var y := 0.6
	while y < top - 0.2:
		m.rod(Vector3(-0.22, y, -0.16), Vector3(0.22, y, -0.16), 0.02, 5, timber.darkened(0.2))
		y += 0.35
	for side: float in [-1.0, 1.0]:
		m.rod(Vector3(side * 0.22, 0.4, -0.16), Vector3(side * 0.22, top - 0.2, -0.16), 0.025, 5, timber.darkened(0.2))
		m.rod(Vector3(side * 0.22, 0.4, -0.16), Vector3(side * 0.13, 0.4, -0.13), 0.025, 5, timber.darkened(0.2))
	# The turntable at the top.
	m.cyl(0.4, 0.4, 0.08, 20, CozyMesh.at(Vector3(0, top + 0.04, 0)), brass.darkened(0.2))
	# The two shafts up its east face, from the cranks at its foot to the
	# gearing at its top.
	for k in 2:
		var shaft := Node3D.new()
		shaft.position = Vector3(0.18, 0, 0.06 - k * 0.12)
		add_child(shaft)
		var s := CozyMesh.new()
		s.cyl(0.022, 0.022, top - 1.0, 6, CozyMesh.at(Vector3(0, 1.0 + (top - 1.0) * 0.5, 0)), iron)
		s.box(Vector3(0.03, 0.03, 0.09), CozyMesh.at(Vector3(0, top - 0.3, 0)), iron)
		var view := MeshInstance3D.new()
		view.mesh = s.commit(_out)
		shaft.add_child(view)
		_shafts.append(shaft)
		for yb: float in [1.2, top * 0.5, top - 0.15]:
			m.box(Vector3(0.1, 0.06, 0.06), CozyMesh.at(Vector3(0.15, yb, 0.06 - k * 0.12)), iron)
	m.box(Vector3(0.2, 0.16, 0.3), CozyMesh.at(Vector3(0.18, top - 0.05, 0)), iron)
	var view := MeshInstance3D.new()
	view.mesh = m.commit(_out)
	add_child(view)
	# The fork, turning on the turntable; the mirror in it on trunnions.
	_fork.position = Vector3(0, top + 0.08, 0)
	add_child(_fork)
	var f := CozyMesh.new()
	f.cyl(0.32, 0.36, 0.1, 16, CozyMesh.at(Vector3(0, 0.05, 0)), timber)
	for side: float in [-1.0, 1.0]:
		f.box(Vector3(0.14, PIVOT + 0.1, 0.18), CozyMesh.at(Vector3(side * (SIZE.x * 0.5 + 0.14), (PIVOT + 0.1) * 0.5, 0)), timber)
		f.box(Vector3(SIZE.x * 0.5 + 0.2, 0.14, 0.2), CozyMesh.at(Vector3(side * (SIZE.x * 0.25 + 0.1), 0.1, 0)), timber)
		f.cyl(0.07, 0.07, 0.08, 10, CozyMesh.at(Vector3(side * (SIZE.x * 0.5 + 0.23), PIVOT, 0), Basis(Vector3.BACK, PI * 0.5)), brass)
	f.cyl(0.18, 0.18, 0.04, 16, CozyMesh.at(Vector3(SIZE.x * 0.5 + 0.25, PIVOT, 0), Basis(Vector3.BACK, PI * 0.5)), brass.darkened(0.15))
	var fork_view := MeshInstance3D.new()
	fork_view.mesh = f.commit(_out)
	_fork.add_child(fork_view)
	_mirror.position = Vector3(0, PIVOT, 0)
	_fork.add_child(_mirror)
	var frame := CozyMesh.new()
	frame.box(Vector3(SIZE.x + 0.12, SIZE.y + 0.12, 0.08), CozyMesh.at(Vector3(0, 0, -0.06)), timber.darkened(0.15))
	for i in PANES.x + 1:
		var x := -SIZE.x * 0.5 + SIZE.x * i / PANES.x
		frame.box(Vector3(0.04, SIZE.y, 0.03), CozyMesh.at(Vector3(x, 0, 0.012)), timber)
	for j in PANES.y + 1:
		var yj := -SIZE.y * 0.5 + SIZE.y * j / PANES.y
		frame.box(Vector3(SIZE.x, 0.04, 0.03), CozyMesh.at(Vector3(0, yj, 0.012)), timber)
	var frame_view := MeshInstance3D.new()
	frame_view.mesh = frame.commit(_out)
	_mirror.add_child(frame_view)
	# The glass: a mirror's silvered face, a little dulled.
	var face_mat := StandardMaterial3D.new()
	face_mat.albedo_color = Color(0.72, 0.74, 0.72)
	face_mat.metallic = 1.0
	face_mat.roughness = 0.12
	var glass_box := BoxMesh.new()
	glass_box.size = Vector3(SIZE.x - 0.02, SIZE.y - 0.02, 0.01)
	glass_box.material = face_mat
	var panes := MeshInstance3D.new()
	panes.mesh = glass_box
	panes.position = Vector3(0, 0, 0.0)
	_mirror.add_child(panes)
	# The light it sends, faint in the open air.
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_beam_mat.albedo_color = Color(1.0, 0.94, 0.8, 0.0)
	var tube := CylinderMesh.new()
	tube.top_radius = 0.75
	tube.bottom_radius = 0.75
	tube.height = 1.0
	tube.radial_segments = 20
	tube.cap_top = false
	tube.cap_bottom = false
	tube.material = _beam_mat
	_beam = MeshInstance3D.new()
	_beam.mesh = tube
	_beam.top_level = true
	_beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_beam.visible = false
	add_child(_beam)
	# The cranks at its foot, on its east side.
	for k in 2:
		var which := "bearing" if k == 0 else "tilt"
		var handle := HeliostatCrank.new(self, which, _out, _shafts[k])
		handle.position = Vector3(0.45, 1.0, 0.06 - k * 0.12 + (0.25 if k == 0 else -0.25))
		add_child(handle)
