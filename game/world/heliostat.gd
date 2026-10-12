class_name Heliostat
extends Node3D
## A heliostat for the burning glass (BurningGlass): a flat mirror of
## period glass panes, silvered with tin and mercury (REFLECT of the light
## back), in a wooden frame on a fork at the top of a mast tied to the
## house's wall, turned by hand from inside the workshop: two cranks on
## the stand by the table, their shafts back through the wall to bevel
## gears at the mast's foot and up the mast; one turns the fork round on
## its turntable (the mirror's bearing), the other tilts the mirror in the
## fork. Set right, the mirror throws the sun down the axis of the lens's
## barrel; the sun moves on, so the player sets it again every minute or
## two.
##
## Two centuries out of doors have left few of its panes: the tin and
## mercury behind the glass corrodes and the glazing bars' putty rots, so
## most have fallen (lying, whole or shattered, at the mast's foot), some
## hang cracked with part gone, and the few still whole are tarnished at
## their edges (`panes`, as FOUND). A gone pane sends nothing, a cracked
## one half; restoring the mirror is for the player.
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
# Its panes as found, across each row from the top: 2 whole (the backing
# tarnished at its edges), 1 cracked with part fallen away, 0 gone.
const FOUND := [0, 2, 0, 1, 0, 0, 2, 0, 1, 0, 0, 1, 2, 0, 0]
const PANE_LIGHT := [0.0, 0.5, 1.0]     # the share of a pane's light it still sends, by its state
const SIZE := Vector2(1.8, 3.0)         # m: the mirror, across and up its face
const PANES := Vector2i(3, 5)
const MAST_H := 7.9                     # m: the mirror's middle over the ground
const PIVOT := 1.7                      # m: its trunnions over the fork's foot, clear of the mirror's swing
const TURN_RATE := 1.5                  # degrees a second, a crank held
const BARREL := 1.0                     # m: the barrel's mouth from the lens, along its axis
const BARREL_R := 0.63                  # m: inside
const CRANK_Y := 1.22                   # m: the cranks over the ground, inside the wall

## The mirror's face: its bearing from north toward east and its tilt
## over level, degrees.
var bearing := 180.0
var tilt := 5.0
## Each pane's state, as FOUND.
var panes: Array[int] = []
var glass: BurningGlass
## The house's wall south of the mast: its inner and outer faces, metres
## along this node's z (set before it is added).
var wall_in := 1.6
var wall_out := 1.0
## How far into the room from the wall's inner face the cranks stand, their
## shafts run out to them (set before it is added).
var crank_out := 0.0

var _to_sun := Vector3.UP
var _sunlight := 0.0
var _fork := Node3D.new()
var _glass_node := Node3D.new()
var _fallen := Node3D.new()
var _silver: StandardMaterial3D
var _mirror := Node3D.new()
var _shafts: Array[Node3D] = []
var _beam: MeshInstance3D
var _beam_mat: StandardMaterial3D
var _wood: Material
var _out: Material


func _init(lens: BurningGlass, wood: Material, outside: Material) -> void:
	name = "Heliostat"
	panes.assign(FOUND)
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
	var across := rel.dot(frame.x.normalized())
	var up := rel.dot(frame.y.normalized())
	if absf(across) > SIZE.x * 0.5 or absf(up) > SIZE.y * 0.5:
		return 0.0
	# The pane it meets, and what is left of it.
	var col := clampi(floori((across + SIZE.x * 0.5) / SIZE.x * PANES.x), 0, PANES.x - 1)
	var row := clampi(floori((SIZE.y * 0.5 - up) / SIZE.y * PANES.y), 0, PANES.y - 1)
	return PANE_LIGHT[panes[row * PANES.x + col]]


## Sets every pane's state (whole, cracked, gone), as FOUND.
func set_panes(states: Array) -> void:
	panes.assign(states)
	_show_panes()


## The panes drawn as they are, and those gone lying at the mast's foot,
## some whole in the grass, some shattered.
func _show_panes() -> void:
	for child in _glass_node.get_children():
		child.queue_free()
	for child in _fallen.get_children():
		child.queue_free()
	var w := SIZE.x / PANES.x
	var h := SIZE.y / PANES.y
	var silver := CozyMesh.new()
	var tarnish := CozyMesh.new()
	var lying := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1702
	for i in panes.size():
		var col := i % PANES.x
		var row := i / PANES.x
		var at := Vector3(-SIZE.x * 0.5 + (col + 0.5) * w, SIZE.y * 0.5 - (row + 0.5) * h, 0.0)
		match panes[i]:
			2:
				silver.box(Vector3(w - 0.03, h - 0.03, 0.01), CozyMesh.at(at), Color.WHITE)
				for k in 5:
					var spot := at + Vector3(rng.randf_range(-0.5, 0.5) * w, rng.randf_range(-0.5, 0.5) * h, 0.006)
					tarnish.ball(rng.randf_range(0.02, 0.06), 8, CozyMesh.at(spot, Basis(Vector3.RIGHT, PI * 0.5)), Color(0.3, 0.28, 0.24), false, 0.002)
			1:
				# The upper part still held, its lower edge broken off
				# jagged, cracks across it.
				var kept := h * rng.randf_range(0.4, 0.6)
				silver.box(Vector3(w - 0.03, kept, 0.01), CozyMesh.at(at + Vector3(0, (h - kept) * 0.5 - 0.015, 0)), Color.WHITE)
				silver.prism(Vector3(w * 0.5, 0.12, 0.01), CozyMesh.at(at + Vector3(rng.randf_range(-0.1, 0.1), h * 0.5 - kept - 0.07, 0), Basis(Vector3.BACK, PI)), Color.WHITE)
				for k in 3:
					tarnish.box(Vector3(0.006, kept * 0.9, 0.004), CozyMesh.at(at + Vector3(rng.randf_range(-0.3, 0.3) * w, (h - kept) * 0.5, 0.007), Basis(Vector3.BACK, rng.randf_range(-0.6, 0.6))), Color(0.2, 0.2, 0.2))
			_:
				# Gone: lying below, whole or in pieces.
				var foot := Vector3(rng.randf_range(-2.2, 2.2), 0.012, rng.randf_range(-2.4, -0.4))
				if rng.randf() < 0.4:
					lying.box(Vector3(w - 0.03, 0.01, h - 0.03), CozyMesh.at(foot, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, rng.randf_range(-0.06, 0.06))), Color(0.6, 0.62, 0.6))
				else:
					for k in rng.randi_range(4, 7):
						var shard := foot + Vector3(rng.randf_range(-0.35, 0.35), 0, rng.randf_range(-0.35, 0.35))
						lying.prism(Vector3(rng.randf_range(0.06, 0.18), 0.006, rng.randf_range(0.06, 0.2)), CozyMesh.at(shard, Basis(Vector3.UP, rng.randf() * TAU) * Basis(Vector3.RIGHT, PI * 0.5)), Color(0.6, 0.62, 0.6))
	if not silver.is_empty():
		var view := MeshInstance3D.new()
		view.mesh = silver.commit(_silver)
		_glass_node.add_child(view)
	if not tarnish.is_empty():
		var spots := MeshInstance3D.new()
		spots.mesh = tarnish.commit(_out)
		_glass_node.add_child(spots)
	if not lying.is_empty():
		var shards := MeshInstance3D.new()
		shards.mesh = lying.commit(_silver)
		_fallen.add_child(shards)


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
	# Down the barrel it ends on the lens: what passes is the lens's light.
	var axis := glass.global_basis.y.normalized()
	var toward := going.dot(axis)
	if toward < -0.01:
		var t := (glass.global_position - from).dot(axis) / toward
		if t > 0.0 and t < reach and (from + going * t).distance_to(glass.global_position) < BARREL_R + 0.3:
			reach = t
	_beam.visible = true
	_beam.global_transform = Transform3D(CozyMesh.aligned(going).scaled_local(Vector3(1, reach, 1)), from + going * reach * 0.5)
	_beam_mat.albedo_color.a = 0.02 * clampf(glass.light / 600.0, 0.0, 1.0)


func _build() -> void:
	var m := CozyMesh.new()
	var timber := Color(0.42, 0.32, 0.22)
	var iron := Color(0.22, 0.21, 0.2)
	var brass := Color(0.76, 0.58, 0.3)
	var top := MAST_H - PIVOT - 0.08
	# The mast: a squared timber on a stone footing, raking stays east,
	# west and north, two iron straps bolting it to the house's wall on
	# the south, rungs up its north face.
	m.box(Vector3(0.8, 0.3, 0.8), CozyMesh.at(Vector3(0, 0.15, 0)), Color(0.55, 0.52, 0.46))
	m.box(Vector3(0.26, top, 0.26), CozyMesh.at(Vector3(0, top * 0.5, 0)), timber)
	for foot: Vector3 in [Vector3(1.6, 0.05, 0), Vector3(-1.6, 0.05, 0), Vector3(0, 0.05, -1.6)]:
		m.rod(foot, Vector3(0, top * 0.45, 0), 0.06, 6, timber.darkened(0.1))
		m.box(Vector3(0.3, 0.2, 0.3), CozyMesh.at(foot), Color(0.55, 0.52, 0.46))
	for h: float in [1.9, 2.55]:
		m.box(Vector3(0.06, 0.03, wall_out - 0.13), CozyMesh.at(Vector3(0, h, (wall_out + 0.13) * 0.5)), iron)
		m.box(Vector3(0.3, 0.06, 0.02), CozyMesh.at(Vector3(0, h, 0.14)), iron)
		m.box(Vector3(0.22, 0.22, 0.02), CozyMesh.at(Vector3(0, h, wall_out - 0.01)), iron)
	var y := 0.6
	while y < top - 0.2:
		m.rod(Vector3(-0.22, y, -0.16), Vector3(0.22, y, -0.16), 0.02, 5, timber.darkened(0.2))
		y += 0.35
	for side: float in [-1.0, 1.0]:
		m.rod(Vector3(side * 0.22, 0.4, -0.16), Vector3(side * 0.22, top - 0.2, -0.16), 0.025, 5, timber.darkened(0.2))
		m.rod(Vector3(side * 0.22, 0.4, -0.16), Vector3(side * 0.13, 0.4, -0.13), 0.025, 5, timber.darkened(0.2))
	# The turntable at the top.
	m.cyl(0.4, 0.4, 0.08, 20, CozyMesh.at(Vector3(0, top + 0.04, 0)), brass.darkened(0.2))
	# The two shafts up its south face to the gearing at its top, each
	# turned at its foot by bevel gears from a shaft out through the wall
	# from its crank inside.
	for k in 2:
		var x := -0.07 if k == 0 else 0.07
		var shaft := Node3D.new()
		shaft.position = Vector3(x, 0, 0.17)
		add_child(shaft)
		var s := CozyMesh.new()
		s.cyl(0.022, 0.022, top - CRANK_Y, 6, CozyMesh.at(Vector3(0, CRANK_Y + (top - CRANK_Y) * 0.5, 0)), iron)
		s.box(Vector3(0.03, 0.03, 0.09), CozyMesh.at(Vector3(0, top - 0.3, 0)), iron)
		var view := MeshInstance3D.new()
		view.mesh = s.commit(_out)
		shaft.add_child(view)
		_shafts.append(shaft)
		for yb: float in [top * 0.5, top - 0.15]:
			m.box(Vector3(0.06, 0.06, 0.1), CozyMesh.at(Vector3(x, yb, 0.15)), iron)
		var through := Vector3(-0.25 if k == 0 else 0.25, CRANK_Y, wall_in)
		m.rod(through, Vector3(x, CRANK_Y, 0.2), 0.02, 6, iron)
		m.box(Vector3(0.1, 0.12, 0.1), CozyMesh.at(Vector3(x, CRANK_Y, 0.2)), iron)
	m.box(Vector3(0.3, 0.16, 0.2), CozyMesh.at(Vector3(0, top - 0.05, 0.14)), iron)
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
	# The glass: a mirror's silvered face, a little dulled, pane by pane
	# as it is now (`_show_panes`).
	_silver = StandardMaterial3D.new()
	_silver.vertex_color_use_as_albedo = true
	_silver.albedo_color = Color(0.72, 0.74, 0.72)
	_silver.metallic = 1.0
	_silver.roughness = 0.12
	_mirror.add_child(_glass_node)
	add_child(_fallen)
	_show_panes()
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
	# The cranks inside, CRANK_OUT from the wall on their shafts, a post
	# with a bearing for each shaft halfway.
	var inside := CozyMesh.new()
	for k in 2:
		var x := -0.25 if k == 0 else 0.25
		inside.rod(Vector3(x, CRANK_Y, wall_in), Vector3(x, CRANK_Y, wall_in + crank_out), 0.02, 6, iron)
		var which := "bearing" if k == 0 else "tilt"
		var handle := HeliostatCrank.new(self, which, _out)
		handle.position = Vector3(x, CRANK_Y, wall_in + crank_out)
		add_child(handle)
	if crank_out > 0.5:
		var half := wall_in + crank_out * 0.45
		inside.box(Vector3(0.08, CRANK_Y + 0.05, 0.08), CozyMesh.at(Vector3(0, (CRANK_Y + 0.05) * 0.5, half)), timber)
		inside.box(Vector3(0.62, 0.07, 0.07), CozyMesh.at(Vector3(0, CRANK_Y, half)), timber)
		inside.box(Vector3(0.3, 0.05, 0.3), CozyMesh.at(Vector3(0, 0.05, half)), timber.darkened(0.15))
	var inside_view := MeshInstance3D.new()
	inside_view.mesh = inside.commit(_out)
	add_child(inside_view)
