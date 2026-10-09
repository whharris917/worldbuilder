class_name CrystalExpo
extends BeachSite
## The exposition on the cozy island's wide west beach: the next age of
## light-beam devices shown as at a fair. A boardwalk promenade along the
## beach, an arch at each end, and eight booths inland of it, each a
## boarded stage under a striped awning with its name on a board, bunting
## strung between them. Each booth demonstrates one way of mounting the
## logic crystals, and new crystal cuts and settings in brass, copper and
## silver (LumenPart's `look`), as a small circuit that runs by itself:
## its lantern opens and closes on a clock, and the light is seen to walk
## through the crystals as their on-delays run.
##
## The booths, in order along the shore from the balloon works:
## - The Column: crystals stacked up a brass column on ring brackets.
## - The Branch: crystals in copper cups along a horizontal arm.
## - The Rail: crystals in silver cages hanging from clamps on a vertical
##   rail, the light falling down it.
## - The Chandelier: crystals hanging on chains under a brass ring, hung
##   from an arch; the lamp at the ring's middle lights them round in turn.
## - The Cabinet: a grid of crystal tablets on brass brackets against
##   velvet in a wooden case, the light winding through it.
## - The Retort Stand: crystals held in copper coils by iron laboratory
##   stands on a bench, by a glowing flask; a radiometer at the end.
## - The Armillary: crystals where the silver rings of an armillary sphere
##   meet, lit from its middle.
## - The Cutting Room: each new cut of crystal under its own glass dome.
## Behind them, along a second boardwalk, the hall of apparatus
## (ApparatusHall): vessels, pipes and mechanisms. The booth names and
## notes are drafts.

const BEARING := 203.0
const SPREAD := 14.0                    # degrees either side the booths span
const STAGE_IN := 19.0                  # a booth's middle, metres up from the shore
const WALK_IN := 9.5                    # the promenade's middle
const HALL_IN := 31.5                   # the second row's booths, for the apparatus hall
const WALK2_IN := 25.0                  # the second promenade, between the rows
const HALL_SPREAD := 13.0
const WALK_W := 2.4
const STAGE := Vector3(6.4, 0.6, 5.0)
const EXHIBIT_SCALE := 1.25
const FRONT_H := 3.5                    # the awning's height at the front, and at the back
const BACK_H := 3.9

const CREAM := Color(0.97, 0.93, 0.84)
const STRIPES := [Color(0.3, 0.66, 0.66), Color(0.93, 0.5, 0.42), Color(0.93, 0.74, 0.3), Color(0.55, 0.7, 0.48),
		Color(0.68, 0.56, 0.84), Color(0.45, 0.66, 0.9), Color(0.92, 0.56, 0.66), Color(0.3, 0.4, 0.62)]
const BOOTH_NAMES := ["THE COLUMN", "THE BRANCH", "THE RAIL", "THE CHANDELIER", "THE CABINET",
		"THE RETORT STAND", "THE ARMILLARY", "THE CUTTING ROOM"]
const BOOTH_NOTES := [
	"The Column\nCrystals stacked up one brass column on ring brackets: a whole rung of logic in one upright.",
	"The Branch\nCrystals sitting in copper cups along a single arm, the light spreading from the middle out.",
	"The Rail\nCrystals in silver cages hung from clamps that slide on a rail; move a clamp, move the crystal.",
	"The Chandelier\nCrystals hung on chains beneath a brass ring, lit in turn from the lamp at its heart.",
	"The Cabinet\nCrystal tablets on brass brackets against velvet, a circuit laid out as a collection.",
	"The Retort Stand\nCrystals held in copper coils by laboratory clamps, at whatever height the work needs.",
	"The Armillary\nCrystals where the rings of a silver armillary sphere cross, lit from its centre.",
	"The Cutting Room\nThe new cuts, each under its own glass: point, octahedron, orb, cluster, gem, obelisk, prism, tablet.",
]

var _copper: StandardMaterial3D
var _silver: StandardMaterial3D
var _iron: StandardMaterial3D
var _velvet: StandardMaterial3D
var _glass: StandardMaterial3D
var _potion: StandardMaterial3D
var _booths: Array[Node3D] = []
var _clocks: Array = []                  # [lantern, period, on, phase]
var _clock := 0.0


func _init(owner_island: CozyIsland) -> void:
	super(owner_island, BEARING)
	name = "CrystalExpo"


func _ready() -> void:
	add_child(_site)
	_materials()
	_build_promenade(WALK_IN, SPREAD + 7.0)
	var builders: Array[Callable] = [_column, _branch, _rail, _chandelier, _cabinet, _retort, _armillary, _cutting_room]
	for i in builders.size():
		var b := deg_to_rad(BEARING - SPREAD + 2.0 * SPREAD * i / (builders.size() - 1))
		var booth := _booth(b, i, STAGE_IN, BOOTH_NAMES[i], BOOTH_NOTES[i])
		_booths.append(booth)
		# The demonstration stands forward on the stage, shown a quarter
		# larger than in a works, as a showpiece.
		var show := Node3D.new()
		show.position = Vector3(0, 0, -0.9)
		show.scale = Vector3.ONE * EXHIBIT_SCALE
		booth.add_child(show)
		builders[i].call(show)
	_build_bunting(_booths)
	for end: float in [-1.0, 1.0]:
		_build_arch(deg_to_rad(BEARING + end * (SPREAD + 5.0)))
	_place_beams()
	add_child(OpticBench.new(self))
	add_child(ApparatusHall.new(self))


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
	_velvet = island.surface("", 1.0, Color(0.08, 0.1, 0.26), 0.95, Color(0.24, 0.28, 0.56))
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(0.85, 0.95, 1.0, 0.18)
	_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glass.roughness = 0.05
	_glass.metallic_specular = 0.8
	_potion = StandardMaterial3D.new()
	_potion.albedo_color = Color(0.4, 0.95, 0.55)
	_potion.emission_enabled = true
	_potion.emission = Color(0.3, 1.0, 0.5)
	_potion.emission_energy_multiplier = 1.2


## ---- the fair --------------------------------------------------------------

## A booth at `bearing`, its middle `inland` metres up from the shore:
## its frame (x along the shore, y up from the stage's top, z inland),
## the stage, the awning in the stripes of `index`, the name board
## reading `title`, the backdrop, and `note` for the whole of it.
func _booth(bearing: float, index: int, inland: float, title: String, note: String) -> Node3D:
	var d := Vector3(cos(bearing), 0.0, sin(bearing))
	var along := Vector3(-d.z, 0.0, d.x)
	var centre := d * (island.coast(bearing, 0.0) - inland)
	var front := centre + d * STAGE.z * 0.5
	var back := centre - d * STAGE.z * 0.5
	var g_front := island.height(front.x, front.z)
	var g_back := island.height(back.x, back.z)
	var top := (g_front + g_back) * 0.5 + 0.08
	var booth := Node3D.new()
	booth.name = "Booth%d" % index
	_site.add_child(booth)
	booth.global_transform = Transform3D(Basis(along, Vector3.UP, -d), Vector3(centre.x, top, centre.z))
	var accent: Color = STRIPES[index % STRIPES.size()]
	var m := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 900 + index
	# The stage: boards front to back over a skirt reaching into the sand.
	var tones := [Color(0.84, 0.74, 0.6), Color(0.78, 0.68, 0.56), Color(0.88, 0.8, 0.66), Color(0.74, 0.64, 0.52)]
	m.box(Vector3(STAGE.x, STAGE.y - 0.05, STAGE.z), CozyMesh.at(Vector3(0, -STAGE.y * 0.5 - 0.025, 0)), Color(0.6, 0.5, 0.4))
	var boards := int(STAGE.x / 0.2)
	for k in boards:
		var x := -STAGE.x * 0.5 + 0.1 + k * 0.2
		m.box(Vector3(0.185, 0.05, STAGE.z), CozyMesh.at(Vector3(x, -0.025, 0)), (tones[rng.randi() % tones.size()] as Color).lightened(rng.randf_range(-0.05, 0.05)))
	# A step along the front, half the stage's height.
	m.box(Vector3(STAGE.x * 0.7, 0.05, 0.45), CozyMesh.at(Vector3(0, -(top - g_front) * 0.5, -STAGE.z * 0.5 - 0.22)), Color(0.8, 0.7, 0.56))
	# The awning: four slim poles, a striped canopy sloping to the front, a
	# scalloped valance.
	var poles := [Vector3(-3.0, 0, -2.3), Vector3(3.0, 0, -2.3), Vector3(-3.0, 0, 2.3), Vector3(3.0, 0, 2.3)]
	for p: Vector3 in poles:
		var h := FRONT_H if p.z < 0.0 else BACK_H
		_rod(p, p + Vector3(0, h, 0), 0.035, _brass, 8, booth)
		_ball(0.06, p + Vector3(0, h + 0.05, 0), _brass, booth)
	var slope := atan2(BACK_H - FRONT_H, 4.6)
	var strips := 9
	for k in strips:
		var w := 6.6 / strips
		var x := -3.3 + w * (k + 0.5)
		m.box(Vector3(w, 0.03, 5.0), CozyMesh.at(Vector3(x, (FRONT_H + BACK_H) * 0.5 + 0.02, 0.0), Basis(Vector3.RIGHT, -slope)), CREAM if k % 2 == 0 else accent)
	for k in 16:
		var x := -3.3 + 6.6 / 16.0 * (k + 0.5)
		m.prism(Vector3(0.38, 0.28, 0.03), CozyMesh.at(Vector3(x, FRONT_H - 0.14, -2.5), Basis(Vector3.FORWARD, PI)), accent if k % 2 == 0 else CREAM)
	# The backdrop: a painted board between the back poles.
	m.box(Vector3(5.9, 3.2, 0.06), CozyMesh.at(Vector3(0, 1.7, 2.35)), accent.lerp(CREAM, 0.6))
	m.box(Vector3(6.0, 0.1, 0.1), CozyMesh.at(Vector3(0, 3.32, 2.35)), Color(0.55, 0.42, 0.3))
	# The name board standing on the awning's front edge.
	m.box(Vector3(2.8, 0.46, 0.06), CozyMesh.at(Vector3(0, FRONT_H + 0.3, -2.5)), Color(0.5, 0.36, 0.26))
	m.box(Vector3(2.66, 0.36, 0.02), CozyMesh.at(Vector3(0, FRONT_H + 0.3, -2.535)), CREAM)
	var view := MeshInstance3D.new()
	view.name = "Stand"
	view.mesh = m.commit(island.cozy_material())
	booth.add_child(view)
	var sign := Label3D.new()
	sign.text = title
	sign.font_size = 72
	sign.pixel_size = 0.0042
	sign.outline_size = 0
	sign.modulate = Color(0.32, 0.2, 0.14)
	sign.double_sided = false
	sign.position = Vector3(0, FRONT_H + 0.3, -2.55)
	sign.rotation.y = PI
	booth.add_child(sign)
	# What the player walks on: the stage, and a gentle ramp up its step.
	var body := StaticBody3D.new()
	booth.add_child(body)
	var solid := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = STAGE
	solid.shape = box
	solid.position = Vector3(0, -STAGE.y * 0.5, 0)
	body.add_child(solid)
	var rise := top - g_front + 0.02
	var ramp := CollisionShape3D.new()
	var plank := BoxShape3D.new()
	plank.size = Vector3(STAGE.x * 0.7, 0.04, sqrt(1.0 + rise * rise))
	ramp.shape = plank
	ramp.transform = Transform3D(Basis(Vector3.RIGHT, -atan2(rise, 1.0)), Vector3(0, -rise * 0.5 - 0.02, -STAGE.z * 0.5 - 0.5))
	body.add_child(ramp)
	booth.add_child(HoverNote.new(Vector3(0, 1.4, 0.3), Vector3(3.2, 2.8, 3.0), note))
	return booth


## A promenade `inland` metres up from the shore, `spread` degrees either
## side of the fair's middle: a boardwalk following the shore, boards
## across it, each sitting on the sand.
func _build_promenade(inland: float, spread: float) -> void:
	var m := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 777
	var tones := [Color(0.82, 0.72, 0.58), Color(0.76, 0.66, 0.54), Color(0.86, 0.78, 0.64), Color(0.72, 0.62, 0.5)]
	var from := deg_to_rad(BEARING - spread)
	var to := deg_to_rad(BEARING + spread)
	var a := from
	while a < to:
		var d := Vector3(cos(a), 0.0, sin(a))
		var r := island.coast(a, 0.0) - inland
		var p := d * r
		var y := island.height(p.x, p.z) + 0.03
		var tone: Color = tones[rng.randi() % tones.size()]
		m.box(Vector3(WALK_W, 0.05, 0.17), CozyMesh.at(Vector3(p.x, y, p.z), Basis(Vector3.UP, -a)), tone.lightened(rng.randf_range(-0.05, 0.05)))
		a += 0.2 / r
	var view := MeshInstance3D.new()
	view.name = "Promenade"
	view.mesh = m.commit(island.cozy_material())
	add_child(view)


## Bunting strung from each booth's front corner to the next booth's in
## `row`, a sagging line with little flags in turn.
func _build_bunting(row: Array[Node3D]) -> void:
	var m := CozyMesh.new()
	var flags := [Color(0.93, 0.5, 0.42), Color(0.93, 0.74, 0.3), Color(0.3, 0.66, 0.66), CREAM, Color(0.68, 0.56, 0.84)]
	var k := 0
	for i in row.size() - 1:
		var a := row[i].to_global(Vector3(3.0, FRONT_H + 0.02, -2.3))
		var b := row[i + 1].to_global(Vector3(-3.0, FRONT_H + 0.02, -2.3))
		var span := a.distance_to(b)
		var count := int(span / 0.38)
		var last := a
		for n in count + 1:
			var t := float(n) / count
			var p := a.lerp(b, t) + Vector3.DOWN * 0.7 * 4.0 * t * (1.0 - t)
			if n > 0:
				m.cyl(0.006, 0.006, last.distance_to(p), 3, CozyMesh.at((last + p) * 0.5, CozyMesh.aligned(p - last)), Color(0.4, 0.32, 0.26))
			if n > 0 and n < count:
				var across := (b - a).normalized()
				var flag := Basis(across, Vector3.UP, across.cross(Vector3.UP)) * Basis(Vector3.FORWARD, PI)
				m.prism(Vector3(0.22, 0.26, 0.01), CozyMesh.at(p + Vector3.DOWN * 0.13, flag), flags[k % flags.size()])
				k += 1
			last = p
	var view := MeshInstance3D.new()
	view.name = "Bunting"
	view.mesh = m.commit(island.cozy_material(false))
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(view)


## An arch over the promenade at `bearing`, its name on both faces.
func _build_arch(bearing: float) -> void:
	var d := Vector3(cos(bearing), 0.0, sin(bearing))
	var along := Vector3(-d.z, 0.0, d.x)
	var c := d * (island.coast(bearing, 0.0) - WALK_IN)
	var g := island.height(c.x, c.z)
	var arch := Node3D.new()
	add_child(arch)
	arch.global_transform = Transform3D(Basis(-d, Vector3.UP, -along), Vector3(c.x, g, c.z))
	var m := CozyMesh.new()
	for x: float in [-1.6, 1.6]:
		m.box(Vector3(0.22, 3.4, 0.22), CozyMesh.at(Vector3(x, 1.7, 0)), Color(0.55, 0.42, 0.3))
		m.ball(0.16, 10, CozyMesh.at(Vector3(x, 3.5, 0)), Color(0.92, 0.72, 0.34))
	m.box(Vector3(3.8, 0.7, 0.14), CozyMesh.at(Vector3(0, 3.05, 0)), Color(0.5, 0.36, 0.26))
	m.box(Vector3(3.6, 0.56, 0.16), CozyMesh.at(Vector3(0, 3.05, 0)), CREAM)
	for k in 10:
		var x := -1.8 + 3.6 / 10.0 * (k + 0.5)
		m.prism(Vector3(0.3, 0.22, 0.03), CozyMesh.at(Vector3(x, 2.6, 0), Basis(Vector3.FORWARD, PI)), STRIPES[k % 4] if k % 2 == 0 else CREAM)
	var view := MeshInstance3D.new()
	view.mesh = m.commit(island.cozy_material())
	arch.add_child(view)
	for face: float in [1.0, -1.0]:
		var sign := Label3D.new()
		sign.text = "THE EXPOSITION"
		sign.font_size = 72
		sign.pixel_size = 0.0045
		sign.modulate = Color(0.32, 0.2, 0.14)
		sign.double_sided = false
		sign.position = Vector3(0, 3.05, 0.085 * face)
		sign.rotation.y = 0.0 if face > 0.0 else PI
		arch.add_child(sign)


## ---- mounting -----------------------------------------------------------------

## A part held by a mounting rather than on its own post, at `pos` in
## the booth.
func _mount(booth: Node3D, kind: LumenPart.Kind, title: String, pos: Vector3, look: Dictionary, delay := 0.0) -> LumenPart:
	var l := look.duplicate()
	l["post"] = false
	var p := LumenPart.new(kind, title, pos, 0.0, _wood, _brass, delay, l)
	booth.add_child(p)
	parts.append(p)
	return p


## A drum lantern in `metal` opening for `on` seconds of every `period`.
func _lamp(booth: Node3D, pos: Vector3, metal: Material, period: float, on: float, phase: float) -> LumenPart:
	var p := _mount(booth, LumenPart.Kind.LANTERN, "the demonstration's clock", pos, {"lamp": "drum", "metal": metal})
	_clocks.append([p, period, on, phase])
	return p


func _ring(inner: float, outer: float, pos: Vector3, mat: Material, parent: Node3D, basis := Basis.IDENTITY) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner
	mesh.outer_radius = outer
	mesh.rings = 32
	mesh.ring_segments = 8
	mesh.material = mat
	var view := _put(mesh, pos, false, Vector3.ZERO, parent)
	view.basis = basis
	return view


## ---- the booths' demonstrations -------------------------------------------

func _column(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.6)
	_cyl(0.22, 0.27, 0.12, c + Vector3(0, 0.06, 0), _brass, 16, false, booth)
	_cyl(0.06, 0.075, 2.4, c + Vector3(0, 1.26, 0), _brass, 12, true, booth)
	_ball(0.11, c + Vector3(0, 2.52, 0), _brass, booth)
	_rod(c + Vector3(0, 0.55, 0), c + Vector3(0, 0.55, -0.2), 0.02, _brass, 6, booth)
	var lamp := _lamp(booth, c + Vector3(0, 0.55, -0.3), _brass, 7.0, 4.5, 0.0)
	var hues := [Color(1.0, 0.86, 0.3), Color(1.0, 0.68, 0.3), Color(1.0, 0.52, 0.42), Color(1.0, 0.42, 0.62), Color(0.88, 0.42, 0.95)]
	var last := lamp
	for k in 5:
		var y := 0.9 + 0.36 * k
		var side := -1.0 if k % 2 == 0 else 1.0
		var at := c + Vector3(side * 0.26, y, 0)
		_ring(0.07, 0.095, c + Vector3(0, y - 0.1, 0), _brass, booth)
		_rod(c + Vector3(0, y - 0.1, 0), at + Vector3(0, -0.1, 0), 0.015, _brass, 6, booth)
		var p := _mount(booth, LumenPart.Kind.TON, "a step up the column", at, {"design": "octa", "setting": "collar", "metal": _brass, "colour": hues[k]}, 0.45)
		_wire(last, p)
		last = p


func _branch(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.5)
	_cyl(0.2, 0.24, 0.06, c + Vector3(0, 0.03, 0), _copper, 16, false, booth)
	_cyl(0.05, 0.065, 1.85, c + Vector3(0, 0.925, 0), _copper, 10, true, booth)
	for k in 6:
		_ring(0.06, 0.075, c + Vector3(0, 0.3 + k * 0.08, 0), _copper, booth)
	_rod(c + Vector3(-1.32, 1.85, 0), c + Vector3(1.32, 1.85, 0), 0.032, _copper, 8, booth)
	for x: float in [-1.36, 1.36]:
		_ball(0.05, c + Vector3(x, 1.85, 0), _copper, booth)
	_rod(c + Vector3(0, 1.2, 0), c + Vector3(0, 1.2, -0.2), 0.02, _copper, 6, booth)
	var lamp := _lamp(booth, c + Vector3(0, 1.2, -0.3), _copper, 6.0, 3.8, 1.3)
	var hues := [Color(0.3, 0.95, 0.9), Color(0.35, 0.75, 1.0), Color(0.55, 0.55, 1.0)]
	var middle := _mount(booth, LumenPart.Kind.TON, "the branch's heart", c + Vector3(0, 2.05, 0), {"design": "gem", "setting": "cup", "metal": _copper, "colour": hues[0]}, 0.4)
	_wire(lamp, middle)
	for side: float in [-1.0, 1.0]:
		var last := middle
		for k in 2:
			var p := _mount(booth, LumenPart.Kind.TON, "out along the branch", c + Vector3(side * 0.55 * (k + 1), 2.05, 0),
					{"design": "gem", "setting": "cup", "metal": _copper, "colour": hues[k + 1]}, 0.4)
			_wire(last, p)
			last = p


func _rail(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.7)
	_box(Vector3(0.7, 0.08, 0.4), c + Vector3(0, 0.04, 0), _iron, true, booth)
	for x: float in [-0.06, 0.06]:
		_rod(c + Vector3(x, 0.08, 0), c + Vector3(x, 2.45, 0), 0.018, _silver, 8, booth)
	_box(Vector3(0.26, 0.08, 0.14), c + Vector3(0, 2.47, 0), _silver, false, booth)
	var lamp := _lamp(booth, c + Vector3(0, 2.66, -0.05), _silver, 6.5, 4.0, 2.6)
	var hues := [Color(0.92, 0.96, 1.0), Color(0.75, 0.88, 1.0), Color(0.6, 0.8, 1.0), Color(0.55, 0.65, 1.0), Color(0.7, 0.55, 1.0)]
	var last := lamp
	for k in 5:
		var y := 2.2 - 0.36 * k
		_box(Vector3(0.22, 0.1, 0.1), c + Vector3(0, y, 0), _silver, false, booth)
		_rod(c + Vector3(0, y, -0.05), c + Vector3(0, y, -0.3), 0.012, _silver, 6, booth)
		_rod(c + Vector3(0, y, -0.3), c + Vector3(0, y - 0.08, -0.3), 0.006, _silver, 4, booth)
		var p := _mount(booth, LumenPart.Kind.TON, "a clamp on the rail", c + Vector3(0, y - 0.23, -0.3),
				{"design": "orb", "setting": "cage", "metal": _silver, "colour": hues[k]}, 0.45)
		_wire(last, p)
		last = p


func _chandelier(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.6)
	for x: float in [-1.5, 1.5]:
		_cyl(0.06, 0.08, 2.8, c + Vector3(x, 1.4, 0), _brass, 10, true, booth)
		_ball(0.09, c + Vector3(x, 2.88, 0), _brass, booth)
	_rod(c + Vector3(-1.55, 2.78, 0), c + Vector3(1.55, 2.78, 0), 0.05, _brass, 10, booth)
	_rod(c + Vector3(0, 2.78, 0), c + Vector3(0, 2.0, 0), 0.01, _brass, 4, booth)
	_ring(0.66, 0.72, c + Vector3(0, 2.0, 0), _brass, booth)
	for k in 3:
		var a := TAU * k / 3.0
		_rod(c + Vector3(cos(a) * 0.69, 2.0, sin(a) * 0.69), c + Vector3(0, 2.45, 0), 0.006, _brass, 4, booth)
	var lamp := _lamp(booth, c + Vector3(0, 1.82, 0), _brass, 8.0, 5.0, 0.7)
	var hues := [Color(1.0, 0.5, 0.5), Color(1.0, 0.75, 0.4), Color(0.95, 0.95, 0.45), Color(0.5, 0.95, 0.6), Color(0.45, 0.75, 1.0), Color(0.8, 0.55, 1.0)]
	for k in 6:
		var a := TAU * k / 6.0
		var hang := c + Vector3(cos(a) * 0.69, 2.0, sin(a) * 0.69)
		_rod(hang, hang + Vector3(0, -0.22, 0), 0.006, _brass, 4, booth)
		var p := _mount(booth, LumenPart.Kind.TON, "a drop of the chandelier", hang + Vector3(0, -0.43, 0),
				{"design": "cluster", "setting": "hook", "metal": _brass, "colour": hues[k]}, 0.25 + 0.3 * k)
		_wire(lamp, p)


func _cabinet(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.9)
	_box(Vector3(2.0, 1.7, 0.05), c + Vector3(0, 1.35, 0.15), _velvet, false, booth)
	for x: float in [-1.04, 1.04]:
		_box(Vector3(0.08, 1.85, 0.4), c + Vector3(x, 1.38, 0), _wood, false, booth)
		_box(Vector3(0.08, 0.45, 0.08), c + Vector3(x, 0.225, -0.12), _wood, false, booth)
		_box(Vector3(0.08, 0.45, 0.08), c + Vector3(x, 0.225, 0.12), _wood, false, booth)
	for y: float in [0.46, 2.27]:
		_box(Vector3(2.16, 0.08, 0.42), c + Vector3(0, y, 0), _wood, false, booth)
	_box(Vector3(2.24, 0.05, 0.46), c + Vector3(0, 2.33, 0), _brass, false, booth)
	_box(Vector3(2.1, 1.9, 0.5), c + Vector3(0, 1.38, 0.0), _wood, true, booth).visible = false
	var lamp := _mount(booth, LumenPart.Kind.LANTERN, "the demonstration's clock", c + Vector3(0, 2.52, -0.05), {})
	_clocks.append([lamp, 9.0, 6.0, 3.1])
	var hues := [Color(1.0, 0.82, 0.35), Color(1.0, 0.55, 0.65), Color(0.35, 0.95, 0.85)]
	var last := lamp
	for row in 3:
		var y := 1.95 - 0.5 * row
		for col in 3:
			var x := (-0.6 + 0.6 * col) * (1.0 if row % 2 == 0 else -1.0)
			_cyl(0.07, 0.07, 0.02, c + Vector3(x, y, 0.12), _brass, 12, false, booth).rotation.x = PI * 0.5
			_rod(c + Vector3(x, y, 0.12), c + Vector3(x, y, -0.02), 0.012, _brass, 6, booth)
			var p := _mount(booth, LumenPart.Kind.TON, "a tablet in the case", c + Vector3(x, y, -0.06),
					{"design": "tablet", "colour": hues[row]}, 0.35)
			_wire(last, p)
			last = p


func _retort(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.7)
	var top := 0.86
	_box(Vector3(2.3, 0.06, 0.8), c + Vector3(0, top - 0.03, 0), _wood, true, booth)
	for x: float in [-1.05, 1.05]:
		for z: float in [-0.32, 0.32]:
			_box(Vector3(0.07, top - 0.06, 0.07), c + Vector3(x, (top - 0.06) * 0.5, z), _wood, false, booth)
	var hues := [Color(0.8, 0.45, 1.0), Color(1.0, 0.4, 0.8), Color(0.45, 1.0, 0.55), Color(1.0, 0.8, 0.35)]
	var lamp := _lamp(booth, c + Vector3(-0.95, top + 0.13, 0.05), _copper, 7.5, 4.5, 4.2)
	var last := lamp
	var k := 0
	for stand: Vector2 in [Vector2(-0.45, 1.25), Vector2(0.45, 1.45)]:
		var foot := c + Vector3(stand.x, top, 0.18)
		_box(Vector3(0.3, 0.03, 0.2), foot + Vector3(0, 0.015, 0), _iron, false, booth)
		_rod(foot, foot + Vector3(0, 1.2, 0), 0.012, _iron, 6, booth)
		for j in 2:
			var y := stand.y + 0.4 * j
			var boss := c + Vector3(stand.x, y, 0.18)
			_box(Vector3(0.05, 0.05, 0.05), boss, _iron, false, booth)
			_rod(boss, boss + Vector3(0, 0, -0.24), 0.008, _iron, 4, booth)
			var p := _mount(booth, LumenPart.Kind.TON, "held in a clamp", boss + Vector3(0, 0.04, -0.3),
					{"design": "prism", "setting": "coil", "metal": _copper, "colour": hues[k]}, 0.5)
			_wire(last, p)
			last = p
			k += 1
	# The flask, glowing, in a copper ring on its own little stand.
	var flask := c + Vector3(0.05, top + 0.18, -0.15)
	_ball(0.12, flask, _glass, booth)
	_ball(0.095, flask + Vector3(0, -0.015, 0), _potion, booth)
	_cyl(0.025, 0.035, 0.16, flask + Vector3(0, 0.18, 0), _glass, 10, false, booth)
	_ring(0.12, 0.135, flask + Vector3(0, -0.03, 0), _copper, booth)
	var out := _mount(booth, LumenPart.Kind.RADIOMETER, "what the stand drives", c + Vector3(0.95, top + 0.2, 0.0), {})
	_wire(last, out)


func _armillary(booth: Node3D) -> void:
	var c := Vector3(0, 0, 0.6)
	var mid := c + Vector3(0, 1.8, 0)
	_cyl(0.24, 0.3, 0.1, c + Vector3(0, 0.05, 0), _brass, 16, false, booth)
	_cyl(0.07, 0.1, 0.9, c + Vector3(0, 0.5, 0), _brass, 12, true, booth)
	_cyl(0.16, 0.07, 0.08, c + Vector3(0, 0.98, 0), _brass, 12, false, booth)
	_ring(0.73, 0.77, mid, _silver, booth)
	_ring(0.73, 0.77, mid, _silver, booth, Basis(Vector3.RIGHT, PI * 0.5))
	_ring(0.73, 0.77, mid, _silver, booth, Basis(Vector3.FORWARD, deg_to_rad(23.0)) * Basis(Vector3.RIGHT, PI * 0.5) * Basis(Vector3.FORWARD, PI * 0.5))
	_rod(mid + Vector3(0, -0.82, 0), mid + Vector3(0, 0.95, 0), 0.015, _brass, 6, booth)
	var lamp := _lamp(booth, mid, _silver, 8.0, 5.5, 5.0)
	var hues := [Color(0.5, 0.65, 1.0), Color(0.95, 0.85, 0.45), Color(0.6, 0.5, 1.0), Color(0.95, 0.85, 0.45), Color(0.75, 0.9, 1.0), Color(0.75, 0.9, 1.0)]
	var points := [Vector3(0.75, 0, 0), Vector3(0, 0, -0.75), Vector3(-0.75, 0, 0), Vector3(0, 0, 0.75), Vector3(0, 0.75, 0), Vector3(0, -0.75, 0)]
	for k in points.size():
		var p := _mount(booth, LumenPart.Kind.TON, "where the rings meet", mid + (points[k] as Vector3),
				{"design": "octa", "setting": "collar", "metal": _silver, "colour": hues[k]}, 0.3 + 0.35 * k)
		_wire(lamp, p)


func _cutting_room(booth: Node3D) -> void:
	var cuts := [["point", "prongs", _brass], ["octa", "cage", _silver], ["orb", "cup", _copper], ["cluster", "collar", _brass],
			["gem", "prongs", _silver], ["obelisk", "coil", _copper], ["prism", "collar", _silver], ["tablet", "", _brass]]
	var hues := [Color(1.0, 0.8, 0.25), Color(0.4, 0.8, 1.0), Color(1.0, 0.45, 0.45), Color(0.55, 1.0, 0.55),
			Color(0.9, 0.5, 1.0), Color(1.0, 0.65, 0.3), Color(0.5, 1.0, 0.9), Color(1.0, 0.55, 0.8)]
	var lamp := _mount(booth, LumenPart.Kind.LANTERN, "the demonstration's clock", Vector3(0, 1.75, 1.6), {})
	_rod(Vector3(0, 0, 1.6), Vector3(0, 1.62, 1.6), 0.025, _brass, 8, booth)
	_clocks.append([lamp, 10.0, 7.5, 0.0])
	for k in cuts.size():
		var t := float(k) / (cuts.size() - 1) * 2.0 - 1.0
		var base := Vector3(t * 2.5, 0, 0.2 + 0.7 * t * t)
		_box(Vector3(0.34, 0.92, 0.34), base + Vector3(0, 0.46, 0), _wood, true, booth)
		_box(Vector3(0.38, 0.06, 0.38), base + Vector3(0, 0.95, 0), _velvet, false, booth)
		_ring(0.2, 0.225, base + Vector3(0, 0.99, 0), _brass, booth)
		var cut: Array = cuts[k]
		var look := {"design": cut[0], "setting": cut[1], "metal": cut[2], "colour": hues[k]}
		var p := _mount(booth, LumenPart.Kind.OR, "a %s, set in %s" % [cut[0], cut[1] if cut[1] != "" else "nothing"], base + Vector3(0, 1.2, 0), look)
		_wire(lamp, p)
		# Its glass dome.
		var dome := CylinderMesh.new()
		dome.top_radius = 0.21
		dome.bottom_radius = 0.21
		dome.height = 0.34
		dome.cap_top = false
		dome.cap_bottom = false
		dome.material = _glass
		_put(dome, base + Vector3(0, 1.15, 0), false, Vector3.ZERO, booth)
		var cap := SphereMesh.new()
		cap.radius = 0.21
		cap.height = 0.21
		cap.is_hemisphere = true
		cap.material = _glass
		_put(cap, base + Vector3(0, 1.32, 0), false, Vector3.ZERO, booth)


## ---- running ------------------------------------------------------------------

func _physics_process(dt: float) -> void:
	_clock += dt
	for c: Array in _clocks:
		(c[0] as LumenPart).condition = fmod(_clock + float(c[3]), float(c[1])) < float(c[2])
	_step_circuit(dt)
