class_name SunForge
extends BeachSite
## A second platform, beyond the Tideworks, reached by pontoons from its
## seaward side: the Sunforge, where sunlight and sea sand are made into
## glass orbs. Three great works stand on it:
## - The solar tower: an open lattice of iron and brass 18 m high with a
##   crucible at its top, and round it a field of tracking mirrors
##   (heliostats) that follow the sun, each turned so its face lies
##   halfway between the way to the sun and the way to the crucible, so
##   the sunlight it catches is thrown onto the crucible; their beams are
##   drawn converging there. At night, or with the sun too low, they
##   park face up.
## - The sand screw: an Archimedes screw 26 m long in an open cage on
##   trestles, from a sand hopper at the platform's edge (filled by a
##   bucket dredge from the sea) up to the crucible.
## - The noria: a water wheel 14 m across hung over the sea at the
##   platform's edge, turned by the current, its buckets lifting sea
##   water to a trough at the top; a raised channel on trestles carries it
##   down to the quench tank at the tower's foot.
##
## The process: the screw fills the crucible with sand; the mirrors heat
## it; hot and holding sand, with water in the tank, its tap opens and
## drops of molten glass fall the height of the tower, as at a shot tower,
## glowing orange and cooling as they fall, into the tank, where they set
## as glass orbs; a scoop wheel lifts the orbs into crates, and the tally
## goes up.
##
## The logic, each lantern opened by a sensor at its machine: a
## radiometer spinning in the sunlight lifts its collar (the sun shines);
## a pyrometer rod hung down the tower from the crucible moves a pointer
## at the foot as it lengthens with the heat (hot); a counterweight on a
## chain from the crucible's weigh-beam rises as sand fills it, working
## two lanterns (holds sand, full of sand); a float rod in the tank (has
## water). Crystals on a brass tree at the tower's foot:
##   TRACK = the sun shines                                        (the mirrors follow it, else park)
##   SCREW = NOT the crucible is full of sand                      (the screw and the dredge run)
##   POUR  = hot AND holds sand AND the tank has water             (the crucible's tap opens)
## The name board and notes are drafts.

const GAP := 46.0                        # from the Tideworks' seaward edge to the Sunforge's
const HALF := Vector2(22.0, 22.0)
const EXIT_X := 12.0                     # where along the Tideworks the walkway leaves
const TOWER_H := 18.0
const RECEIVER := Vector3(0.0, 17.2, 0.0)
const NORIA := Vector3(25.0, 6.0, 0.0)   # the wheel's axle; it turns in the y-z plane
const NORIA_R := 7.0
const HOPPER := Vector3(-20.0, 0.0, 0.0)
const SCREW_TOP := Vector3(-1.2, 16.6, 0.0)
const TANK_R := 1.25

var _copper: StandardMaterial3D
var _silver: StandardMaterial3D
var _iron: StandardMaterial3D
var _mirror: StandardMaterial3D
var _glass: StandardMaterial3D
var _water: StandardMaterial3D
var _sand: StandardMaterial3D
var _melt: StandardMaterial3D

var _pontoons: Array[AnimatableBody3D] = []
var _clock := 0.0
var _heliostats: Array[Array] = []       # [yaw node, tilt node, centre]
var _beams := ImmediateMesh.new()
var _beam_mat: StandardMaterial3D
var _screw: Node3D
var _screw_turn := 0.0
var _sand_clumps: Array[Node3D] = []
var _dredge_buckets: Array[Node3D] = []
var _dredge_turn := 0.0
var _noria: Node3D
var _noria_turn := 0.0
var _noria_spill: MeshInstance3D
var _slugs: Array[Node3D] = []
var _drops: Array[Node3D] = []
var _drop_mats: Array[StandardMaterial3D] = []
var _steam: Array[Node3D] = []
var _tank_level: Node3D
var _scoop: Node3D
var _orb_crates: Array[Node3D] = []
var _digits: Array[Label3D] = []
var _crucible_glow: StandardMaterial3D
var _radio_vanes: Node3D
var _radio_collar: Node3D
var _pyro_pointer: Node3D
var _weight: Node3D
var _float_rod: Node3D

var _sun := 0.0                          # sunlight on the mirrors, 0 to 1
var _track := 0.0                        # how far the mirrors have turned to the sun
var _heat := 0.1
var _sand_in := 0.2                      # the crucible's sand, 0 to 1
var _water_in := 0.5                     # the tank's
var _poured := 0.0                       # drops since the last orb
var _orbs := 0
var _crates := 0
var _drop_clock := 0.0

var _l := {}
var _r := {}
var _snd_splash: AudioStreamPlayer3D
var _snd_chime: AudioStreamPlayer3D
var _snd_creak: AudioStreamPlayer3D


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, TideWorks.BEARING)
	name = "SunForge"
	var a := deg_to_rad(TideWorks.BEARING)
	var d := Vector3(cos(a), 0.0, sin(a))
	var along := Vector3(-d.z, 0.0, d.x)
	var basis := Basis(-along, Vector3.UP, d)
	var tide := d * (island.coast(a, 0.0) + TideWorks.OUT)
	var centre := tide + basis * Vector3(EXIT_X, 0.0, TideWorks.HALF.y + GAP + HALF.y)
	_site.transform = Transform3D(basis, Vector3(centre.x, TideWorks.DECK_Y, centre.z))


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_walkway()
	_build_deck()
	_build_tower()
	_build_heliostats()
	_build_screw()
	_build_noria()
	_build_tank()
	_build_circuit()
	_place_beams()
	_build_sounds()


func _materials() -> void:
	_wood = island.surface("weathered_wood", 0.8, Color(0.9, 0.88, 0.86), 0.9, Color(0.66, 0.56, 0.46))
	_brass = island.surface("", 1.0, Color(0.62, 0.46, 0.2), 0.3, Color(0.92, 0.72, 0.34))
	_brass.metallic = 0.85
	_copper = island.surface("", 1.0, Color(0.62, 0.32, 0.2), 0.32, Color(0.9, 0.52, 0.34))
	_copper.metallic = 0.9
	_silver = island.surface("", 1.0, Color(0.78, 0.78, 0.8), 0.22, Color(0.88, 0.9, 0.95))
	_silver.metallic = 0.9
	_iron = island.surface("", 1.0, Color(0.12, 0.12, 0.13), 0.5, Color(0.34, 0.34, 0.42))
	_iron.metallic = 0.5
	# Silvered glass: bright and pale in both looks (wholly metallic, the
	# cartoon look draws it dark), glinting as it catches the sun.
	_mirror = island.surface("", 1.0, Color(0.86, 0.9, 0.96), 0.08, Color(0.88, 0.94, 1.0), {"no_line": true})
	_mirror.metallic = 0.5
	_mirror.emission_enabled = true
	_mirror.emission = Color(0.85, 0.92, 1.0)
	_sand = island.surface("sand", 0.5, Color(1.0, 0.97, 0.92), 0.9, Color(0.98, 0.87, 0.64))
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.85, 0.95, 1.0, 0.18)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.05
	_glass.metallic_specular = 0.8
	_water = TideWorks._glowing(Color(0.35, 0.7, 0.75), 0.25)
	_melt = TideWorks._glowing(Color(1.0, 0.55, 0.15), 3.0)
	_crucible_glow = TideWorks._glowing(Color(1.0, 0.8, 0.45), 0.5)


## ---- helpers --------------------------------------------------------------------

func _pivot(at: Vector3, parent: Node3D = null) -> Node3D:
	var n := Node3D.new()
	n.position = at
	n.set_meta(StaticMerge.MOVES, true)
	(parent if parent != null else _site).add_child(n)
	return n


func _sphere(r: float, at: Vector3, mat: Material, parent: Node3D = null, squash := Vector3.ONE) -> MeshInstance3D:
	var view := _ball(r, at, mat, parent)
	view.basis = Basis.from_scale(squash)
	return view


func _ring(inner: float, outer: float, at: Vector3, mat: Material, parent: Node3D = null, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 48
	mesh.ring_segments = 8
	mesh.material = mat
	var view := _put(mesh, at, false, Vector3.ZERO, parent)
	view.basis = basis
	return view


func _link(radius: float, mat: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 1.0
	mesh.radial_segments = 8
	mesh.rings = 1
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.set_meta(StaticMerge.MOVES, true)
	_site.add_child(view)
	return view


func _note(at: Vector3, size: Vector3, text: String) -> void:
	_site.add_child(HoverNote.new(at, size, text))


func _mount(kind: LumenPart.Kind, title: String, pos: Vector3, look: Dictionary, delay := 0.0) -> LumenPart:
	var l := look.duplicate()
	l["post"] = false
	var p := LumenPart.new(kind, title, pos, 0.0, _wood, _brass, delay, l)
	_site.add_child(p)
	parts.append(p)
	return p


## A trestle: two legs and a cross-bar holding up a point at `top`.
func _trestle(top: Vector3, across: Vector3, mat: Material) -> void:
	for side: float in [-1.0, 1.0]:
		_rod(Vector3(top.x, 0.0, top.z) + across * side * 0.7, top + across * side * 0.25, 0.06, mat, 6)
	_rod(top - across * 0.35, top + across * 0.35, 0.05, mat, 6)


## ---- the walkway and the deck -------------------------------------------------

## Pontoons from the Tideworks' seaward edge to the Sunforge's entrance,
## bobbing on the swell, with gangways at each end and walls along their
## sides (out here there is no shore to keep anyone off the sea).
func _build_walkway() -> void:
	var basis := _site.global_transform.basis
	var o := _site.global_position
	var from := o + basis * Vector3(0, 0, -HALF.y - GAP)
	var to := o + basis * Vector3(0, 0, -HALF.y)
	var d := basis.z
	var across := basis.x
	var start := from + d * 2.6
	var stop := to - d * 2.6
	var length := Vector2(start.x, start.z).distance_to(Vector2(stop.x, stop.z))
	var count := int(length / 3.0)
	var pitch := length / count
	var rng := RandomNumberGenerator.new()
	rng.seed = 6262
	var tones := [Color(0.84, 0.74, 0.6), Color(0.78, 0.68, 0.56), Color(0.88, 0.8, 0.66), Color(0.74, 0.64, 0.52)]
	for i in count:
		var mid := start + d * pitch * (i + 0.5)
		var body := AnimatableBody3D.new()
		body.name = "Pontoon%d" % i
		body.set_meta(StaticMerge.MOVES, true)
		body.transform = Transform3D(basis, Vector3(mid.x, TideWorks.PONTOON_Y, mid.z))
		add_child(body)
		var shape := BoxShape3D.new()
		shape.size = Vector3(2.2, 0.16, pitch - 0.08)
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position.y = -0.08
		body.add_child(c)
		var m := CozyMesh.new()
		for k in int((pitch - 0.08) / 0.2):
			var z := -(pitch - 0.08) * 0.5 + 0.1 + k * 0.2
			m.box(Vector3(2.2, 0.05, 0.18), CozyMesh.at(Vector3(0, -0.025, z)), (tones[rng.randi() % tones.size()] as Color).lightened(rng.randf_range(-0.05, 0.05)))
		for x: float in [-0.75, 0.75]:
			m.cyl(0.24, 0.24, pitch - 0.3, 14, CozyMesh.at(Vector3(x, -0.3, 0), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.72, 0.42, 0.28))
		for x: float in [-1.05, 1.05]:
			for z: float in [-(pitch - 0.2) * 0.5, (pitch - 0.2) * 0.5]:
				m.cyl(0.035, 0.04, 1.0, 8, CozyMesh.at(Vector3(x, 0.5, z)), Color(0.55, 0.42, 0.3))
			m.cyl(0.018, 0.018, pitch - 0.2, 6, CozyMesh.at(Vector3(x, 0.92, 0), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.82, 0.74, 0.58))
		var view := MeshInstance3D.new()
		view.mesh = m.commit(island.cozy_material())
		body.add_child(view)
		_pontoons.append(body)
	_gangway(Vector3(from.x, TideWorks.DECK_Y, from.z), Vector3(start.x, TideWorks.PONTOON_Y, start.z))
	_gangway(Vector3(stop.x, TideWorks.PONTOON_Y, stop.z), Vector3(to.x, TideWorks.DECK_Y, to.z))
	var walls := StaticBody3D.new()
	add_child(walls)
	for side: float in [-1.0, 1.0]:
		var a := from + across * side * 1.2
		var b := to + across * side * 1.2
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.1, 1.6, a.distance_to(b))
		wall.shape = box
		wall.transform = Transform3D(basis, (a + b) * 0.5 + Vector3(0, 0.6, 0))
		walls.add_child(wall)


func _gangway(a: Vector3, b: Vector3) -> void:
	var run := b - a
	var fwd := run.normalized()
	var x0 := Vector3.UP.cross(fwd).normalized()
	var basis := Basis(x0, fwd.cross(x0).normalized(), fwd)
	var m := CozyMesh.new()
	for k in int(run.length() / 0.2):
		m.box(Vector3(2.2, 0.05, 0.18), CozyMesh.at(Vector3(0, -0.025, -run.length() * 0.5 + 0.1 + k * 0.2)), Color(0.8, 0.7, 0.56))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(island.cozy_material())
	view.transform = Transform3D(basis, (a + b) * 0.5)
	add_child(view)
	var body := StaticBody3D.new()
	body.transform = view.transform
	var shape := BoxShape3D.new()
	shape.size = Vector3(2.2, 0.1, run.length())
	var c := CollisionShape3D.new()
	c.shape = shape
	c.position.y = -0.05
	body.add_child(c)
	add_child(body)


func _build_deck() -> void:
	var m := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7171
	var tones := [Color(0.84, 0.74, 0.6), Color(0.78, 0.68, 0.56), Color(0.88, 0.8, 0.66), Color(0.74, 0.64, 0.52)]
	for k in int(HALF.y * 2.0 / 0.22):
		var z := -HALF.y + 0.11 + k * 0.22
		m.box(Vector3(HALF.x * 2.0, 0.06, 0.2), CozyMesh.at(Vector3(0, -0.03, z)), (tones[rng.randi() % tones.size()] as Color).lightened(rng.randf_range(-0.05, 0.05)))
	m.box(Vector3(HALF.x * 2.0 + 0.2, 0.9, HALF.y * 2.0 + 0.2), CozyMesh.at(Vector3(0, -0.51, 0)), Color(0.36, 0.28, 0.22))
	for side: float in [-1.0, 1.0]:
		for k in 7:
			var x := -HALF.x + 3.0 + k * (HALF.x * 2.0 - 6.0) / 6.0
			m.cyl(0.6, 0.6, 3.2, 18, CozyMesh.at(Vector3(x, -0.95, side * (HALF.y - 1.6)), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.72, 0.42, 0.28))
	for x: float in [-1.4, 1.4]:
		m.box(Vector3(0.18, 3.0, 0.18), CozyMesh.at(Vector3(x, 1.5, -HALF.y + 0.15)), Color(0.55, 0.42, 0.3))
	m.box(Vector3(3.4, 0.6, 0.12), CozyMesh.at(Vector3(0, 2.85, -HALF.y + 0.15)), Color(0.5, 0.36, 0.26))
	m.box(Vector3(3.2, 0.46, 0.14), CozyMesh.at(Vector3(0, 2.85, -HALF.y + 0.15)), CrystalExpo.CREAM)
	var view := MeshInstance3D.new()
	view.name = "Deck"
	view.mesh = m.commit(island.cozy_material())
	_site.add_child(view)
	for face: float in [1.0, -1.0]:
		var sign := Label3D.new()
		sign.text = "THE SUNFORGE"
		sign.font_size = 72
		sign.pixel_size = 0.004
		sign.modulate = Color(0.32, 0.2, 0.14)
		sign.double_sided = false
		sign.position = Vector3(0, 2.85, -HALF.y + 0.15 - 0.075 * face)
		sign.rotation.y = PI if face > 0.0 else 0.0
		_site.add_child(sign)
	_note(Vector3(0, 2.85, -HALF.y + 0.15), Vector3(3.2, 0.6, 0.3), "The Sunforge\nSunlight and sea sand made into glass orbs, by mirror, screw and wheel.")
	var body := StaticBody3D.new()
	var deck := BoxShape3D.new()
	deck.size = Vector3(HALF.x * 2.0, 0.3, HALF.y * 2.0)
	var c := CollisionShape3D.new()
	c.shape = deck
	c.position.y = -0.15
	body.add_child(c)
	_site.add_child(body)
	var edge: Array[Array] = [[Vector3(-HALF.x, 0, -HALF.y), Vector3(-1.3, 0, -HALF.y)], [Vector3(1.3, 0, -HALF.y), Vector3(HALF.x, 0, -HALF.y)],
			[Vector3(HALF.x, 0, -HALF.y), Vector3(HALF.x, 0, HALF.y)], [Vector3(HALF.x, 0, HALF.y), Vector3(-HALF.x, 0, HALF.y)],
			[Vector3(-HALF.x, 0, HALF.y), Vector3(-HALF.x, 0, -HALF.y)]]
	for e: Array in edge:
		var p: Vector3 = e[0]
		var q: Vector3 = e[1]
		var posts := maxi(int(p.distance_to(q) / 2.0), 1)
		for k in posts + 1:
			_cyl(0.035, 0.045, 1.05, p.lerp(q, float(k) / posts) + Vector3(0, 0.525, 0), _brass, 8, false)
		_rod(p + Vector3(0, 1.0, 0), q + Vector3(0, 1.0, 0), 0.02, _brass, 6)
		_rod(p + Vector3(0, 0.55, 0), q + Vector3(0, 0.55, 0), 0.015, _brass, 6)
		var wall := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(p.distance_to(q), 1.4, 0.1)
		wall.shape = box
		wall.transform = Transform3D(Basis(Vector3.UP, atan2(-(q - p).z, (q - p).x)), (p + q) * 0.5 + Vector3(0, 0.7, 0))
		body.add_child(wall)


## ---- the solar tower ---------------------------------------------------------

func _build_tower() -> void:
	var base := 2.2
	var top := 1.0
	var bays := 6
	var corners := [Vector2(1, 1), Vector2(-1, 1), Vector2(-1, -1), Vector2(1, -1)]
	var at := func(k: int, y: float) -> Vector3:
		var w := lerpf(base, top, y / TOWER_H)
		var c: Vector2 = corners[k % 4]
		return Vector3(c.x * w, y, c.y * w)
	for k in 4:
		_rod(at.call(k, 0.0), at.call(k, TOWER_H), 0.12, _iron, 8)
		_box(Vector3(0.6, 0.3, 0.6), at.call(k, 0.0) + Vector3(0, 0.15, 0), _iron, true)
	for b in bays + 1:
		var y := TOWER_H * b / bays
		for k in 4:
			_rod(at.call(k, y), at.call(k + 1, y), 0.06, _brass, 6)
		if b < bays:
			var y2 := TOWER_H * (b + 1) / bays
			for k in 4:
				_rod(at.call(k, y), at.call(k + 1, y2), 0.035, _iron, 4)
				_rod(at.call(k + 1, y), at.call(k, y2), 0.035, _iron, 4)
	# The top: a round gallery with rails, the crucible, the receiver ring.
	_cyl(2.4, 2.4, 0.2, Vector3(0, TOWER_H, 0), _iron, 32, false)
	for k in 16:
		var a := TAU * k / 16.0
		_rod(Vector3(cos(a), 0, sin(a)) * 2.35 + Vector3(0, TOWER_H, 0), Vector3(cos(a), 0, sin(a)) * 2.35 + Vector3(0, TOWER_H + 1.0, 0), 0.03, _brass, 6)
	_ring(2.3, 2.4, Vector3(0, TOWER_H + 1.0, 0), _brass)
	_sphere(1.0, Vector3(0, TOWER_H - 0.9, 0), _copper, null, Vector3(1, 0.85, 1))
	_ring(1.05, 1.25, RECEIVER, _brass)
	var aperture := _cyl(0.8, 0.8, 0.05, RECEIVER + Vector3(0, -0.02, 0), _crucible_glow, 24, false)
	aperture.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_cyl(0.08, 0.15, 0.5, Vector3(0, TOWER_H - 1.9, 0), _copper, 10, false)
	# A brass finial and pennant.
	_rod(Vector3(0, TOWER_H + 0.1, 0), Vector3(0, TOWER_H + 3.5, 0), 0.05, _brass, 6)
	_sphere(0.15, Vector3(0, TOWER_H + 3.55, 0), _brass)
	# The falling drops of glass, and the steam where they meet the water.
	for k in 4:
		var drop := _pivot(Vector3(0, TOWER_H - 2.2, 0))
		var mat := TideWorks._glowing(Color(1.0, 0.55, 0.15), 3.0)
		_sphere(0.07, Vector3.ZERO, mat, drop)
		drop.visible = false
		_drops.append(drop)
		_drop_mats.append(mat)
	var steam_mat := StandardMaterial3D.new()
	steam_mat.albedo_color = Color(1, 1, 1, 0.3)
	steam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for k in 6:
		var puff := _pivot(Vector3(0, 1.4, 0))
		_sphere(0.2, Vector3.ZERO, steam_mat, puff)
		puff.visible = false
		_steam.append(puff)
	_note(Vector3(0, 3.0, 0), Vector3(3.2, 4.0, 3.2), "The solar tower\nThe mirrors throw the sun onto the crucible at its top; molten glass falls its height and sets as orbs in the tank.")


## ---- the mirrors ----------------------------------------------------------------

## Heliostats in two rings round the tower, leaving the ways clear for
## the walk in (-z), the screw (-x) and the channel from the wheel (+x).
func _build_heliostats() -> void:
	var spots: Array[Vector3] = []
	for ring: Array in [[9.0, 16], [14.5, 24]]:
		var r: float = ring[0]
		var n: int = ring[1]
		for k in n:
			var a := TAU * (k + 0.5) / n
			var p := Vector3(cos(a), 0, sin(a)) * r
			if absf(p.z) < 3.0 or (p.z < 0.0 and absf(p.x) < 3.5):
				continue
			spots.append(p)
	for p in spots:
		_cyl(0.25, 0.32, 0.12, p + Vector3(0, 0.06, 0), _iron, 12, true)
		_cyl(0.07, 0.09, 1.6, p + Vector3(0, 0.8, 0), _iron, 8, false)
		var yaw := _pivot(p + Vector3(0, 1.7, 0))
		_box(Vector3(0.9, 0.08, 0.1), Vector3.ZERO, _brass, false, yaw)
		for side: float in [-1.0, 1.0]:
			_box(Vector3(0.06, 0.4, 0.08), Vector3(side * 0.45, 0.2, 0), _brass, false, yaw)
		var tilt := _pivot(Vector3(0, 0.35, 0), yaw)
		_box(Vector3(1.7, 1.3, 0.04), Vector3.ZERO, _mirror, false, tilt)
		_box(Vector3(1.76, 1.36, 0.03), Vector3(0, 0, 0.035), _brass, false, tilt)
		_heliostats.append([yaw, tilt, p + Vector3(0, 2.05, 0)])
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.vertex_color_use_as_albedo = true
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var view := MeshInstance3D.new()
	view.name = "SunBeams"
	view.mesh = _beams
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 16384.0
	_site.add_child(view)
	_note(Vector3(0, 1.8, -9.5), Vector3(2.0, 1.4, 1.0), "The heliostats\nEach mirror turns to lie halfway between the sun and the crucible, throwing the sunlight it catches onto it.")


## ---- the sand screw and its dredge ---------------------------------------------

func _build_screw() -> void:
	var low := HOPPER + Vector3(1.6, 1.2, 0)
	var axis := SCREW_TOP - low
	var length := axis.length()
	var dir := axis / length
	var basis := BeachSite._aligned(dir)
	# The cage: four rods along it and rings round it every 3 m, on trestles.
	var side := dir.cross(Vector3.UP).normalized()
	var up := side.cross(dir).normalized()
	for k in 4:
		var a := TAU * k / 4.0 + PI * 0.25
		var off := (side * cos(a) + up * sin(a)) * 0.62
		_rod(low + off, SCREW_TOP + off, 0.03, _brass, 6)
	var rings := int(length / 3.0)
	for k in rings + 1:
		var p := low + dir * length * k / rings
		_ring(0.6, 0.66, p, _copper, null, basis)
		if p.y > 1.5 and k < rings:
			_trestle(p - up * 0.66, Vector3.FORWARD, _iron)
	# The screw itself: a shaft and a helix of flights, turning.
	_screw = _pivot(low)
	_screw.basis = basis
	_cyl(0.08, 0.08, length, Vector3(0, length * 0.5, 0), _iron, 8, false, _screw)
	var m := CozyMesh.new()
	var turns := int(length / 0.9)
	var steps := turns * 16
	for k in steps:
		var t := float(k) / steps
		var a := TAU * k / 16.0
		var p := Vector3(cos(a) * 0.32, t * length, sin(a) * 0.32)
		m.box(Vector3(0.52, 0.04, 0.16), CozyMesh.at(p, Basis(Vector3.UP, -a) * Basis(Vector3.FORWARD, 0.35)), Color(0.82, 0.5, 0.32))
	var flights := MeshInstance3D.new()
	flights.mesh = m.commit(_copper)
	_screw.add_child(flights)
	# Sand riding up it.
	for k in 10:
		var clump := _pivot(low)
		_box(Vector3(0.22, 0.14, 0.22), Vector3.ZERO, _sand, false, clump)
		_sand_clumps.append(clump)
	# The hopper at its foot, and the bucket dredge out over the edge.
	_box(Vector3(2.2, 0.15, 2.2), HOPPER + Vector3(0, 0.6, 0), _wood, true)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_box(Vector3(0.12, 1.8, 0.12), HOPPER + Vector3(sx * 1.0, 0.9, sz * 1.0), _wood, false)
	var cone := CylinderMesh.new()
	cone.top_radius = 1.3
	cone.bottom_radius = 0.3
	cone.height = 1.0
	cone.radial_segments = 4
	cone.material = _copper
	_put(cone, HOPPER + Vector3(0, 1.8, 0), false, Vector3.ZERO, null).rotation.y = PI * 0.25
	_sphere(0.9, HOPPER + Vector3(0, 2.15, 0), _sand, null, Vector3(1, 0.4, 1))
	var dredge_top := HOPPER + Vector3(-0.6, 3.2, 0)
	var dredge_low := Vector3(-HALF.x - 3.0, -2.0, 0)
	_rod(dredge_top, dredge_low, 0.06, _iron, 8)
	_rod(dredge_top + Vector3(0, 0, 0.4), dredge_low + Vector3(0, 0, 0.4), 0.04, _iron, 6)
	_rod(dredge_top - Vector3(0, 0, 0.4), dredge_low - Vector3(0, 0, 0.4), 0.04, _iron, 6)
	_box(Vector3(0.25, 3.3, 0.25), Vector3(-HALF.x + 0.3, 1.6, 0), _iron, false)
	for k in 10:
		var bucket := _pivot(dredge_top)
		_box(Vector3(0.3, 0.22, 0.34), Vector3.ZERO, _copper, false, bucket)
		_box(Vector3(0.24, 0.08, 0.28), Vector3(0, 0.09, 0), _sand, false, bucket)
		_dredge_buckets.append(bucket)
	_note(HOPPER + Vector3(1.6, 1.6, 0), Vector3(2.4, 3.0, 2.4), "The sand screw\nThe dredge lifts wet sand from the sea floor into the hopper; the Archimedes screw carries it up to the crucible.")


## ---- the noria --------------------------------------------------------------------

func _build_noria() -> void:
	# Two great trestles at the platform's edge hold the axle out over the sea.
	for z: float in [-1.4, 1.4]:
		_rod(Vector3(HALF.x - 0.4, 0, z - 1.5), NORIA + Vector3(-1.2, 0, z * 0.4), 0.14, _iron, 8)
		_rod(Vector3(HALF.x - 0.4, 0, z + 1.5), NORIA + Vector3(-1.2, 0, z * 0.4), 0.14, _iron, 8)
	_rod(NORIA + Vector3(-1.6, 0, 0), NORIA + Vector3(0.6, 0, 0), 0.16, _iron, 10)
	_noria = _pivot(NORIA)
	var face := Basis(Vector3.BACK, PI * 0.5)
	for x: float in [-0.5, 0.5]:
		_ring(NORIA_R - 0.15, NORIA_R + 0.15, Vector3(x, 0, 0), _copper, _noria, face)
		_ring(2.0, 2.25, Vector3(x, 0, 0), _brass, _noria, face)
	_cyl(0.6, 0.6, 1.4, Vector3.ZERO, _brass, 16, false, _noria).basis = face
	for k in 16:
		var a := TAU * k / 16.0
		var out := Vector3(0, sin(a), cos(a))
		for x: float in [-0.5, 0.5]:
			_rod(Vector3(x, 0, 0) + out * 0.5, Vector3(x, 0, 0) + out * NORIA_R, 0.07, _wood, 6)
	for k in 24:
		var a := TAU * k / 24.0
		var bucket := _pivot(Vector3(0, sin(a), cos(a)) * (NORIA_R + 0.25), _noria)
		_box(Vector3(1.2, 0.5, 0.45), Vector3.ZERO, _copper, false, bucket)
		bucket.rotation.x = -a
		var paddle := _box(Vector3(1.25, 0.08, 0.9), Vector3(0, sin(a), cos(a)) * (NORIA_R + 0.5), _wood, false, _noria)
		paddle.rotation.x = -a
	# The trough at the top, the channel down to the tank on trestles.
	var trough := NORIA + Vector3(-1.4, NORIA_R + 0.3, 0)
	_box(Vector3(2.0, 0.3, 0.7), trough, _copper, false)
	var tank_top := Vector3(TANK_R + 0.6, 2.0, 0)
	var run := tank_top - trough
	var steps := 8
	for k in steps:
		var a := trough + run * float(k) / steps
		var b := trough + run * float(k + 1) / steps
		var seg := _box(Vector3(a.distance_to(b) + 0.02, 0.2, 0.55), (a + b) * 0.5, _copper, false)
		seg.basis = Basis(Vector3.BACK, atan2(b.y - a.y, b.x - a.x))
		var fill := _box(Vector3(a.distance_to(b), 0.04, 0.4), (a + b) * 0.5 + Vector3(0, 0.1, 0), _water, false)
		fill.basis = seg.basis
		if b.y > 1.0:
			_trestle(b - Vector3(0, 0.15, 0), Vector3.BACK, _wood)
	_noria_spill = _link(0.12, _water)
	TideWorks._place(_noria_spill, trough + Vector3(0.6, 0.6, 0), trough + Vector3(0.2, 0.1, 0))
	for k in 6:
		var slug := _pivot(trough)
		_sphere(0.12, Vector3.ZERO, _water, slug, Vector3(1.6, 0.6, 1))
		_slugs.append(slug)
	_note(Vector3(HALF.x - 1.5, 2.0, 0), Vector3(2.0, 3.0, 4.0), "The noria\nTurned by the current, its buckets lift sea water to the trough at the top; the channel carries it down to the quench tank.")


## ---- the quench tank and the orbs -------------------------------------------

func _build_tank() -> void:
	_cyl(TANK_R + 0.1, TANK_R + 0.15, 0.2, Vector3(0, 0.1, 0), _brass, 24, true)
	_cyl(TANK_R, TANK_R, 1.4, Vector3(0, 0.9, 0), _glass, 24, false)
	_ring(TANK_R - 0.02, TANK_R + 0.08, Vector3(0, 1.6, 0), _brass)
	_tank_level = _pivot(Vector3(0, 0.2, 0))
	_cyl(TANK_R - 0.05, TANK_R - 0.05, 1.0, Vector3(0, 0.5, 0), _water, 24, false, _tank_level)
	# The scoop wheel lifting orbs out over the rim into a chute.
	_scoop = _pivot(Vector3(TANK_R + 0.1, 1.0, -0.9))
	_ring(0.75, 0.82, Vector3.ZERO, _brass, _scoop, Basis(Vector3.BACK, PI * 0.5))
	for k in 6:
		var a := TAU * k / 6.0
		_rod(Vector3.ZERO, Vector3(0, sin(a), cos(a)) * 0.78, 0.03, _brass, 4, _scoop)
		_box(Vector3(0.18, 0.08, 0.18), Vector3(0, sin(a), cos(a)) * 0.8, _copper, false, _scoop)
	_rod(Vector3(TANK_R + 0.1, 1.85, -0.9), Vector3(TANK_R + 1.8, 0.8, -2.4), 0.06, _copper, 8)
	var orb := TideWorks._glowing(Color(0.6, 0.95, 1.0), 1.2)
	for k in 6:
		var crate := _pivot(Vector3(TANK_R + 2.2 + 0.5 * (k % 3), 0.36 * (k / 3), -2.8))
		var m := CozyMesh.new()
		m.box(Vector3(0.46, 0.34, 0.46), CozyMesh.at(Vector3(0, 0.17, 0)), Color(0.72, 0.56, 0.38))
		var v := MeshInstance3D.new()
		v.mesh = m.commit(island.cozy_material())
		crate.add_child(v)
		for bx: float in [-0.1, 0.1]:
			for bz: float in [-0.1, 0.1]:
				_sphere(0.08, Vector3(bx, 0.4, bz), orb, crate)
		crate.visible = false
		_orb_crates.append(crate)
	var plate_at := Vector3(TANK_R + 2.7, 1.3, -3.2)
	_box(Vector3(0.46, 0.2, 0.04), plate_at, _brass, false)
	for k in 3:
		var dgt := Label3D.new()
		dgt.text = "0"
		dgt.font_size = 64
		dgt.pixel_size = 0.0018
		dgt.modulate = Color(0.1, 0.08, 0.06)
		dgt.position = plate_at + Vector3(-0.12 + 0.12 * k, 0, -0.025)
		dgt.rotation.y = PI
		_site.add_child(dgt)
		_digits.append(dgt)


## ---- the logic -------------------------------------------------------------------

func _build_circuit() -> void:
	var lamp := {"lamp": "drum", "metal": _brass}
	# The sun shines: a radiometer in a glass bell, its vanes lifting a
	# collar as they spin, the collar a lever to the lantern.
	var sun_at := Vector3(-3.5, 0, -7.0)
	_cyl(0.06, 0.08, 1.3, sun_at + Vector3(0, 0.65, 0), _brass, 8, true)
	_sphere(0.28, sun_at + Vector3(0, 1.55, 0), _glass)
	_radio_vanes = _pivot(sun_at + Vector3(0, 1.55, 0))
	for k in 4:
		var vane := _box(Vector3(0.18, 0.14, 0.01), Vector3(cos(TAU * k / 4.0), 0, sin(TAU * k / 4.0)) * 0.13, _silver, false, _radio_vanes)
		vane.rotation.y = -TAU * k / 4.0
	_radio_collar = _pivot(sun_at + Vector3(0, 1.85, 0))
	_ring(0.03, 0.06, Vector3.ZERO, _brass, _radio_collar)
	_box(Vector3(0.05, 2.2, 0.05), sun_at + Vector3(0.45, 1.1, 0), _iron, false)
	_l["sun"] = _mount(LumenPart.Kind.LANTERN, "the sun shines", sun_at + Vector3(0.45, 2.35, 0), lamp)
	# Hot: the pyrometer rod hung down the tower lengthens with the heat
	# and swings a pointer at its foot.
	var foot := Vector3(-1.6, 0, -1.9)
	_rod(Vector3(foot.x, TOWER_H - 1.6, foot.z), Vector3(foot.x, 1.6, foot.z), 0.02, _brass, 6)
	_box(Vector3(0.3, 0.3, 0.05), Vector3(foot.x, 1.3, foot.z - 0.1), _iron, false)
	_pyro_pointer = _pivot(Vector3(foot.x, 1.3, foot.z - 0.14))
	_box(Vector3(0.02, 0.2, 0.01), Vector3(0, 0.1, 0), _brass, false, _pyro_pointer)
	_l["hot"] = _mount(LumenPart.Kind.LANTERN, "the crucible is hot", Vector3(foot.x - 0.35, 1.75, foot.z - 0.25), lamp)
	_box(Vector3(0.05, 1.6, 0.05), Vector3(foot.x - 0.35, 0.8, foot.z - 0.25), _iron, false)
	# Sand: a counterweight on a chain from the crucible's weigh-beam,
	# rising as the sand weighs the beam down; two lanterns beside it.
	var cw := Vector3(1.6, 0, -1.9)
	_rod(Vector3(cw.x, TOWER_H - 1.6, cw.z), Vector3(cw.x, 3.6, cw.z), 0.012, _iron, 4)
	_weight = _pivot(Vector3(cw.x, 1.4, cw.z))
	_box(Vector3(0.22, 0.3, 0.22), Vector3.ZERO, _iron, false, _weight)
	_box(Vector3(0.05, 2.6, 0.05), Vector3(cw.x + 0.35, 1.3, cw.z - 0.2), _iron, false)
	_l["holds"] = _mount(LumenPart.Kind.LANTERN, "the crucible holds sand", Vector3(cw.x + 0.35, 1.7, cw.z - 0.2), lamp)
	_l["full"] = _mount(LumenPart.Kind.LANTERN, "the crucible is full of sand", Vector3(cw.x + 0.35, 2.6, cw.z - 0.2), lamp)
	# The tank has water: a float rod out of the tank's rim.
	_float_rod = _pivot(Vector3(-0.9, 1.0, -0.9))
	_cyl(0.012, 0.012, 1.0, Vector3(0, 0.2, 0), _brass, 6, false, _float_rod)
	_box(Vector3(0.05, 2.2, 0.05), Vector3(-1.25, 1.1, -1.25), _iron, false)
	_l["water"] = _mount(LumenPart.Kind.LANTERN, "the quench tank has water", Vector3(-1.25, 2.3, -1.25), lamp)
	# The crystal tree at the tower's foot.
	var tree := Vector3(0, 0, -4.2)
	_cyl(0.07, 0.1, 2.6, tree + Vector3(0, 1.3, 0), _brass, 10, true)
	for k in 3:
		var a := TAU * k / 3.0 + PI * 0.5
		_rod(tree + Vector3(0, 2.0 + 0.25 * k, 0), tree + Vector3(cos(a) * 0.6, 2.3 + 0.25 * k, sin(a) * 0.6), 0.02, _brass, 6)
	var track_or := _mount(LumenPart.Kind.OR, "follow the sun", tree + Vector3(cos(PI * 0.5) * 0.6, 2.48, sin(PI * 0.5) * 0.6), {"design": "gem", "setting": "prongs", "metal": _brass})
	var not_full := _mount(LumenPart.Kind.NOT, "not full of sand", tree + Vector3(cos(PI * 0.5 + TAU / 3.0) * 0.6, 2.73, sin(PI * 0.5 + TAU / 3.0) * 0.6), {"design": "obelisk", "setting": "collar", "metal": _copper})
	var pour_and := _mount(LumenPart.Kind.AND, "tap the crucible", tree + Vector3(cos(PI * 0.5 + TAU * 2.0 / 3.0) * 0.6, 2.98, sin(PI * 0.5 + TAU * 2.0 / 3.0) * 0.6), {"design": "octa", "setting": "cage", "metal": _silver})
	_r["track"] = _mount(LumenPart.Kind.RADIOMETER, "turns the mirrors to the sun", tree + Vector3(0.9, 1.2, 0), {})
	_r["screw"] = _mount(LumenPart.Kind.RADIOMETER, "runs the screw and the dredge", HOPPER + Vector3(1.4, 2.2, 1.4), {})
	_r["pour"] = _mount(LumenPart.Kind.RADIOMETER, "opens the crucible's tap", tree + Vector3(-0.9, 1.2, 0), {})
	_wire(_l["sun"], track_or)
	_wire(track_or, _r["track"])
	_wire(_l["full"], not_full)
	_wire(not_full, _r["screw"])
	_wire(_l["hot"], pour_and)
	_wire(_l["holds"], pour_and)
	_wire(_l["water"], pour_and)
	_wire(pour_and, _r["pour"])


func _build_sounds() -> void:
	_snd_splash = _speaker("res://audio/hiss_loop.wav", true, Vector3(0, 1.5, 0), 6.0)
	_snd_chime = _speaker("res://audio/chime.wav", false, Vector3(TANK_R + 2.5, 1.0, -2.8), 6.0)
	_snd_creak = _speaker("res://audio/ratchet.wav", false, NORIA, 12.0)


## ---- running ------------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	_clock += dt
	var t := _clock
	for i in _pontoons.size():
		var p := _pontoons[i]
		p.position.y = TideWorks.PONTOON_Y + 0.035 * sin(TAU * t / TideWorks.SWELL - i * 0.55)
		p.rotation.z = 0.012 * sin(TAU * t / TideWorks.SWELL - i * 0.55 + 0.8)
	# Sunlight on the mirrors: the sun's height and the day.
	var to_sun := island.sky.sun.global_transform.basis.z
	_sun = clampf(to_sun.y / 0.25, 0.0, 1.0) * island.sky.daylight if island.sky.sun.visible else 0.0
	_track = move_toward(_track, (_r["track"] as LumenPart).spin, dt * 0.3)
	_heat = clampf(_heat + (0.06 * _sun * _track - 0.02) * dt, 0.0, 1.0)
	# The screw and the dredge fill the crucible while they run.
	var screw := (_r["screw"] as LumenPart).spin
	_screw_turn += screw * 1.5 * dt
	_dredge_turn += screw * 0.4 * dt
	_sand_in = minf(_sand_in + 0.02 * screw * dt, 1.0)
	# The noria turns with the current, always; the tank fills to its rim.
	var before := floorf(_noria_turn * 24.0 / TAU)
	_noria_turn += 0.09 * dt
	if floorf(_noria_turn * 24.0 / TAU) != before:
		_play(_snd_creak, randf_range(0.5, 0.6))
	_water_in = minf(_water_in + 0.01 * dt, 1.0)
	# The tap: hot, holding sand, water to quench: drops fall.
	var pour := (_r["pour"] as LumenPart).spin > 0.5 and _heat > 0.6 and _sand_in > 0.05
	if pour:
		_drop_clock += dt
		if _drop_clock > 1.4:
			_drop_clock = 0.0
			_sand_in = maxf(_sand_in - 0.03, 0.0)
			_water_in = maxf(_water_in - 0.015, 0.0)
			_poured += 1.0
			_launch_drop()
			if _poured >= 16.0:
				_poured = 0.0
				_crates = (_crates + 1) % 1000
				_play(_snd_chime, 1.1)
				for k in 3:
					_digits[k].text = str(_crates / int(pow(10, 2 - k)) % 10)
	# The lanterns, each opened by its sensor.
	(_l["sun"] as LumenPart).condition = _sun > 0.3
	(_l["hot"] as LumenPart).condition = _heat > 0.75 or ((_l["hot"] as LumenPart).out and _heat > 0.6)
	(_l["holds"] as LumenPart).condition = _sand_in > 0.08
	(_l["full"] as LumenPart).condition = _sand_in >= 0.98 or ((_l["full"] as LumenPart).out and _sand_in > 0.6)
	(_l["water"] as LumenPart).condition = _water_in > 0.3
	_step_circuit(dt)


## A drop leaving the crucible's spout.
func _launch_drop() -> void:
	for d in _drops:
		if not d.visible:
			d.visible = true
			d.set_meta("age", 0.0)
			return


func _process(delta: float) -> void:
	var t := _clock
	# The mirrors: halfway between the sun and the receiver, or parked.
	var basis_inv := _site.global_transform.basis.inverse()
	var to_sun := (basis_inv * island.sky.sun.global_transform.basis.z).normalized()
	var aim := _track if to_sun.y > 0.02 else 0.0
	_beams.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	var eye := _site.to_local(cam.global_position) if cam != null else Vector3.ZERO
	var drew := false
	for h: Array in _heliostats:
		var yaw := h[0] as Node3D
		var tilt := h[1] as Node3D
		var c: Vector3 = h[2]
		var to_rx := (RECEIVER - c).normalized()
		var n := (to_sun + to_rx).normalized().lerp(Vector3.UP, 1.0 - aim).normalized()
		yaw.rotation.y = atan2(n.x, n.z)
		tilt.rotation.x = -asin(clampf(n.y, -1.0, 1.0))
		if _sun * aim > 0.05 and cam != null:
			if not drew:
				_beams.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _beam_mat)
				drew = true
			# In the platform's own frame, as the mesh hangs in it.
			var a := c
			var b := RECEIVER
			var side := (b - a).cross(eye - a).normalized() * 0.18
			var glow := Color(1.0, 0.92, 0.7) * 0.22 * _sun * aim
			for v: Vector3 in [a - side, a + side, b, a - side, b, b]:
				_beams.surface_set_color(glow if v != b else glow * 1.6)
				_beams.surface_add_vertex(v)
	if drew:
		_beams.surface_end()
	_crucible_glow.emission_energy_multiplier = 0.4 + 6.0 * _heat
	_mirror.emission_energy_multiplier = 0.15 + 0.6 * _sun * aim
	# The screw, its sand, the dredge.
	_screw.rotation.y = 0.0
	_screw.basis = BeachSite._aligned(SCREW_TOP - (HOPPER + Vector3(1.6, 1.2, 0))) * Basis(Vector3.UP, _screw_turn)
	var low := HOPPER + Vector3(1.6, 1.2, 0)
	for k in _sand_clumps.size():
		var f := fposmod(_screw_turn * 0.05 + k / 10.0, 1.0)
		_sand_clumps[k].position = low.lerp(SCREW_TOP, f) + Vector3(0, -0.25, 0)
	var dredge_top := HOPPER + Vector3(-0.6, 3.2, 0)
	var dredge_low := Vector3(-HALF.x - 3.0, -2.0, 0)
	for k in _dredge_buckets.size():
		var f := fposmod(_dredge_turn + k / 10.0, 1.0)
		var up := f < 0.5
		var along := f * 2.0 if up else (1.0 - f) * 2.0
		_dredge_buckets[k].position = dredge_low.lerp(dredge_top, along) + (Vector3(0, 0.25, 0) if up else Vector3(0, -0.25, 0))
	# The noria and its water.
	_noria.rotation.x = _noria_turn
	for k in _slugs.size():
		var f := fposmod(t * 0.12 + k / 6.0, 1.0)
		var trough := NORIA + Vector3(-1.4, NORIA_R + 0.3, 0)
		_slugs[k].position = trough.lerp(Vector3(TANK_R + 0.6, 2.0, 0), f) + Vector3(0, 0.15, 0)
	_tank_level.scale = Vector3(1, maxf(_water_in * 1.25, 0.01), 1)
	if _snd_splash.stream != null:
		_level(_snd_splash, 0.4 if _drop_any() else 0.0, -14.0)
	# The drops: falling under gravity, cooling from orange to pale blue.
	var spout := TOWER_H - 2.2
	var water_top := 0.2 + 1.25 * _water_in
	for k in _drops.size():
		var d := _drops[k]
		if not d.visible:
			continue
		var age: float = float(d.get_meta("age")) + delta
		d.set_meta("age", age)
		var y := spout - 0.5 * 9.8 * age * age
		d.position = Vector3(sin(k * 1.3) * 0.15, maxf(y, water_top - 0.3), cos(k * 1.3) * 0.15)
		var cool := clampf((spout - y) / (spout - water_top), 0.0, 1.0)
		var colour := Color(1.0, 0.55, 0.15).lerp(Color(0.6, 0.95, 1.0), cool * cool)
		_drop_mats[k].emission = colour
		_drop_mats[k].albedo_color = colour.darkened(0.3)
		if y < water_top - 0.3:
			d.visible = false
			for p in _steam:
				if not p.visible:
					p.visible = true
					p.set_meta("age", 0.0)
					break
	for p in _steam:
		if p.visible:
			var age: float = float(p.get_meta("age")) + delta
			p.set_meta("age", age)
			p.position = Vector3(sin(age * 3.0) * 0.3, water_top + age * 1.2, cos(age * 2.0) * 0.3)
			p.scale = Vector3.ONE * (0.6 + age)
			if age > 1.5:
				p.visible = false
	_scoop.rotation.x = t * 0.4
	for k in _orb_crates.size():
		_orb_crates[k].visible = k < (_crates % 7)
	# The sensors.
	_radio_vanes.rotation.y += _sun * 9.0 * delta
	_radio_collar.position.y = 1.85 + 0.25 * _sun
	_pyro_pointer.rotation.z = 1.2 - 2.4 * _heat
	_weight.position.y = 1.4 + 1.6 * _sand_in
	_float_rod.position.y = 0.6 + 0.9 * _water_in


func _drop_any() -> bool:
	for d in _drops:
		if d.visible:
			return true
	return false
