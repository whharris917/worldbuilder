class_name BeamBalance
extends Node3D
## A water gauge read by light: one sun collector's beam split in two,
## one half sent up through a glass column of dark water, the other round
## it, both to a balance of two geotropes on one shaft whose needle reads
## the column's level from the ratio of the two beams, whatever the sun's
## strength.
##
## The beams follow the island's building rules (BenchLight): the
## collector sends the sunlight on its dish (`sunlight` times its area
## times BenchLight.COLLECT, nothing with the sun down; shade is not
## counted) from its focus; a beam's power falls by e every
## BenchLight.FADE metres; the splitter sends half on each way; the
## mirrors lose nothing and send their beams where they are set. The
## water is peat-dark, taking away all but 1/e of the light for each
## ABSORB metres of it the beam crosses.
##
## The balance: a level shaft in two bearings, square to the beams, with
## two geotropes fixed across it at its two beams, a quarter turn apart.
## Each pulls its own seeking end toward the upright by the light on it
## (Photogyrite.pull, purity 0), so the first (the reference beam's)
## twists the shaft one way and the second (the water's) the other, and
## the shaft settles where the two balance: the needle's angle from
## upright is the angle whose tangent is the water beam's power over the
## reference's. No spring; the pivots' friction holds it where it is while
## the twist on it is less than 3 W's pull (so in dim light it sticks,
## and in the dark it stays where it last stood). The dial's marks are the
## needle's angles for the column empty, a quarter, half, three quarters
## and full, worked out from the same rules.
##
## Built in its own frame: x along the beams from the collector to the
## balance, z across toward the water's side, y up, the origin on the
## ground under the collector.

const DISH_AT := Vector3(0, 1.0, 0)     # the collector's middle, on its legs
const SPLIT := Vector3(3.2, 0.5, 0)
const REF_LOW := Vector3(4.2, 0.5, 0)   # the reference's mirror turning it up
const REF_HIGH := Vector3(4.2, 1.9, 0)  # and turning it on to the balance
const TANK_LOW := Vector3(3.2, 0.5, 0.6)     # the mirror under the column turning its beam up through it
const TANK_HIGH := Vector3(3.2, 1.9, 0.6)    # and over it, turning it on to the balance
const BALANCE := Vector3(6.2, 1.9, 0)   # the shaft's middle at the reference stone
const GAP := 0.6                        # m: the two beams apart, and the two stones
const COLUMN_R := 0.16                  # m: the glass column's inside radius
const COLUMN_FOOT := 0.75               # m: its glass floor over the ground
const COLUMN_HIGH := 0.95               # m: its height
const MOST := 0.9                       # m: the water at full
const ABSORB := 0.39                    # m of the water that takes all but 1/e of the light: full leaves a tenth
const FILL := 0.06                      # m/s: the water rising or falling toward its setting
const INERTIA := 6.0e-4                 # kg m²: the two stones and the needle about the shaft
const PIVOT := 0.03                     # N m s: the bearings' drag
const STICK := 3.0                      # W: the pull of this much light is what the pivots' friction holds
const STEPS := 8

## Toward the sun and its direct light, W/m², set by the world.
var to_sun := Vector3.UP
var sunlight := 0.0
## The water's setting, m (the panel's), and its level now.
var level_set := 0.45
var level := 0.45

var _dish: SunDish
var _shaft := Node3D.new()
var _turn := 0.0                        # rad: the shaft, the reference stone's seeking end from upright
var _rate := 0.0
var _beams: Array[MeshInstance3D] = []
var _beam_mat: StandardMaterial3D
var _dim_mat: StandardMaterial3D
var _water: MeshInstance3D
var _glows: Array[StandardMaterial3D] = []
var _note: HoverNote
var _watts := [0.0, 0.0, 0.0]           # the collector's, the reference's and the water beam's at the balance


## `mats`: "polish", "iron", "brass", "copper", "glass", "wood".
func _init(mats: Dictionary) -> void:
	name = "BeamBalance"
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.albedo_color = Color(1.0, 0.72, 0.22, 0.9)
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_dim_mat = _beam_mat.duplicate() as StandardMaterial3D
	_dim_mat.albedo_color = Color(1.0, 0.72, 0.22, 0.25)
	_dish = SunDish.new(mats["polish"], mats["iron"], mats["brass"], mats["copper"])
	_dish.position = DISH_AT
	add_child(_dish)
	_build_optics(mats)
	_build_column(mats)
	_build_balance(mats)
	for k in 7:
		var beam := MeshInstance3D.new()
		var bar := CylinderMesh.new()
		bar.top_radius = 0.01
		bar.bottom_radius = 0.01
		bar.height = 1.0
		bar.radial_segments = 6
		bar.rings = 1
		beam.mesh = bar
		beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(beam)
		_beams.append(beam)
	# What a player inspecting reads (drafts).
	add_child(HoverNote.new(Vector3(3.2, 1.2, 0.6), Vector3(0.45, 1.1, 0.45),
			"A column of dark water\nA glass column of peat-dark water on a stand. A beam from the collector's splitter is sent up through it from below; the deeper the water, the less of the beam comes out at the top."))
	_note = HoverNote.new(BALANCE + Vector3(0, 0, GAP * 0.5), Vector3(0.5, 0.6, GAP + 0.5), "")
	add_child(_note)


## The splitter and the four mirrors, each on a brass post from the
## ground, its glass turned to send its beam on.
func _build_optics(mats: Dictionary) -> void:
	var silver := StandardMaterial3D.new()
	silver.albedo_color = Color(0.88, 0.9, 0.95)
	silver.metallic = 0.95
	silver.roughness = 0.08
	var glass: Material = mats["glass"]
	var brass: Material = mats["brass"]
	var into_split := Vector3(1, 0, 0)
	# Each: where, the beam in, the beam out, its glass, its post's side
	# (clear of the beams and the column).
	var parts := [
		[SPLIT, into_split, Vector3(0, 0, 1), glass, Vector3(0, 0, -0.12)],
		[REF_LOW, Vector3(1, 0, 0), Vector3.UP, silver, Vector3(0, 0, -0.12)],
		[REF_HIGH, Vector3.UP, Vector3(1, 0, 0), silver, Vector3(0, 0, -0.12)],
		[TANK_LOW, Vector3(0, 0, 1), Vector3.UP, silver, Vector3(-0.12, 0, 0)],
		[TANK_HIGH, Vector3.UP, Vector3(1, 0, 0), silver, Vector3(0, 0, 0.24)],
	]
	for p: Array in parts:
		var at: Vector3 = p[0]
		var normal := ((p[2] as Vector3) - (p[1] as Vector3)).normalized()
		var holder := Node3D.new()
		holder.position = at
		holder.basis = CozyMesh.aligned(normal)
		add_child(holder)
		var face := CylinderMesh.new()
		face.top_radius = 0.07
		face.bottom_radius = 0.07
		face.height = 0.01
		face.radial_segments = 16
		face.material = p[3]
		var face_view := MeshInstance3D.new()
		face_view.mesh = face
		holder.add_child(face_view)
		var rim := TorusMesh.new()
		rim.inner_radius = 0.068
		rim.outer_radius = 0.08
		rim.rings = 16
		rim.ring_segments = 6
		rim.material = brass
		var rim_view := MeshInstance3D.new()
		rim_view.mesh = rim
		holder.add_child(rim_view)
		# The post up from the ground beside it, and a bracket to its rim.
		var side: Vector3 = p[4]
		var post_at := at + side
		_bar(post_at - Vector3(0, at.y, 0), post_at, 0.015, brass)
		_bar(post_at, at + side.normalized() * 0.07, 0.008, brass)


## The glass column on its stand, its glass floor and the water in it.
func _build_column(mats: Dictionary) -> void:
	var at := Vector3(TANK_LOW.x, 0, TANK_LOW.z)
	var wood: Material = mats["wood"]
	var brass: Material = mats["brass"]
	var stand := CozyMesh.new()
	var oak := Color(0.5, 0.36, 0.24)
	for k in 4:
		var a := TAU * (k + 0.5) / 4.0
		var foot := at + Vector3(cos(a) * 0.3, 0, sin(a) * 0.3)
		stand.rod(foot, at + Vector3(cos(a) * 0.2, COLUMN_FOOT, sin(a) * 0.2), 0.025, 6, oak)
	stand.torus(COLUMN_R + 0.01, COLUMN_R + 0.07, 20, 6, CozyMesh.at(at + Vector3(0, COLUMN_FOOT - 0.01, 0)), oak)
	var stand_view := MeshInstance3D.new()
	stand_view.mesh = stand.commit(wood)
	add_child(stand_view)
	var tube := CylinderMesh.new()
	tube.top_radius = COLUMN_R + 0.006
	tube.bottom_radius = COLUMN_R + 0.006
	tube.height = COLUMN_HIGH
	tube.cap_top = false
	tube.radial_segments = 24
	tube.material = mats["glass"]
	var tube_view := MeshInstance3D.new()
	tube_view.mesh = tube
	tube_view.position = at + Vector3(0, COLUMN_FOOT + COLUMN_HIGH * 0.5, 0)
	tube_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(tube_view)
	var band := TorusMesh.new()
	band.inner_radius = COLUMN_R + 0.004
	band.outer_radius = COLUMN_R + 0.016
	band.rings = 24
	band.ring_segments = 6
	band.material = brass
	for y: float in [COLUMN_FOOT, COLUMN_FOOT + COLUMN_HIGH]:
		var b := MeshInstance3D.new()
		b.mesh = band
		b.position = at + Vector3(0, y, 0)
		add_child(b)
	var water_mat := StandardMaterial3D.new()
	water_mat.albedo_color = Color(0.36, 0.2, 0.08, 0.7)
	water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water_mat.roughness = 0.1
	var water := CylinderMesh.new()
	water.top_radius = COLUMN_R
	water.bottom_radius = COLUMN_R
	water.height = 1.0
	water.radial_segments = 24
	water.material = water_mat
	_water = MeshInstance3D.new()
	_water.mesh = water
	_water.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_water)


## The shaft in its two bearings, the two geotropes on it, the needle and
## its dial.
func _build_balance(mats: Dictionary) -> void:
	var brass: Material = mats["brass"]
	var iron: Material = mats["iron"]
	var near := GAP + 0.12                  # the dial's bearing, between the second stone and the dial
	for z: float in [-0.12, near]:
		var foot := Vector3(BALANCE.x, 0, z)
		_bar(foot, foot + Vector3(0, BALANCE.y + 0.02, 0), 0.02, brass)
		var bearing := CylinderMesh.new()
		bearing.top_radius = 0.03
		bearing.bottom_radius = 0.03
		bearing.height = 0.03
		bearing.material = brass
		var b := MeshInstance3D.new()
		b.mesh = bearing
		b.position = Vector3(BALANCE.x, BALANCE.y, z)
		b.rotation.x = PI * 0.5
		add_child(b)
	_shaft.position = BALANCE
	add_child(_shaft)
	_bar(Vector3(0, 0, -0.16), Vector3(0, 0, near + 0.12), 0.006, brass, _shaft)
	# The two stones, grown alike, the second a quarter turn ahead.
	for k in 2:
		var glow := StandardMaterial3D.new()
		glow.albedo_color = Color(0.5, 0.8, 0.48, 0.9)
		glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glow.roughness = 0.08
		glow.metallic_specular = 0.9
		glow.emission_enabled = true
		glow.emission = Color(0.24, 0.62, 0.26)
		glow.emission_energy_multiplier = 0.1
		_glows.append(glow)
		var grown := CozyMesh.new()
		var rng := RandomNumberGenerator.new()
		rng.seed = 911 + k
		LumenPart.grow_spinstone(grown, rng)
		var stone := MeshInstance3D.new()
		stone.mesh = grown.commit(glow)
		stone.transform = Transform3D(Basis(Vector3.BACK, -PI * 0.5 * k).scaled(Vector3.ONE * 0.55), Vector3(0, 0, GAP * k))
		_shaft.add_child(stone)
	# The needle along the first stone's seeking end, a counterweight
	# behind; the dial behind it, facing out along the shaft.
	var needle := CozyMesh.new()
	needle.box(Vector3(0.012, 0.24, 0.006), CozyMesh.at(Vector3(0, 0.12, near + 0.1)), Color(0.15, 0.15, 0.16))
	needle.ball(0.03, 10, CozyMesh.at(Vector3(0, -0.04, near + 0.1)), Color(0.15, 0.15, 0.16))
	var needle_view := MeshInstance3D.new()
	needle_view.mesh = needle.commit(iron)
	_shaft.add_child(needle_view)
	var face := CozyMesh.new()
	var dial_z := near + 0.06
	face.cyl(0.29, 0.29, 0.01, 32, CozyMesh.at(Vector3(BALANCE.x, BALANCE.y, dial_z), Basis(Vector3.RIGHT, PI * 0.5)), Color(0.93, 0.88, 0.74))
	for k in 5:
		var f := k / 4.0
		var a := atan(_ratio(f * MOST))
		var out := Vector3(-sin(a), cos(a), 0)
		var long := 0.07 if k == 0 or k == 4 else 0.045
		var mid := out * (0.27 - long * 0.5)
		face.box(Vector3(0.008, long, 0.004), CozyMesh.at(Vector3(BALANCE.x, BALANCE.y, dial_z + 0.007) + mid,
				Basis(Vector3.BACK, a)), Color(0.12, 0.1, 0.08))
	var face_mat := StandardMaterial3D.new()
	face_mat.vertex_color_use_as_albedo = true
	face_mat.roughness = 0.8
	var face_view := MeshInstance3D.new()
	face_view.mesh = face.commit(face_mat)
	add_child(face_view)
	_bar(Vector3(BALANCE.x, 0, dial_z - 0.01), Vector3(BALANCE.x, BALANCE.y - 0.29, dial_z - 0.01), 0.015, brass)


## The water beam's power over the reference's with `depth` of water.
func _ratio(depth: float) -> float:
	var ref := SPLIT.distance_to(REF_LOW) + REF_LOW.distance_to(REF_HIGH) + REF_HIGH.distance_to(BALANCE)
	var wet := SPLIT.distance_to(TANK_LOW) + TANK_LOW.distance_to(TANK_HIGH) + TANK_HIGH.distance_to(BALANCE + Vector3(0, 0, GAP))
	return exp(-(wet - ref) / BenchLight.FADE - depth / ABSORB)


func _bar(a: Vector3, b: Vector3, r: float, mat: Material, parent: Node3D = null) -> void:
	var c := CylinderMesh.new()
	c.top_radius = r
	c.bottom_radius = r
	c.height = a.distance_to(b)
	c.radial_segments = 8
	c.rings = 1
	c.material = mat
	var m := MeshInstance3D.new()
	m.mesh = c
	m.transform = Transform3D(CozyMesh.aligned((b - a).normalized()), (a + b) * 0.5)
	(parent if parent != null else self).add_child(m)


func _physics_process(delta: float) -> void:
	level = move_toward(level, level_set, FILL * delta)
	_dish.point_at(to_sun if to_sun.y > 0.0 else Vector3(0, 0.3, 1).normalized())
	var source := sunlight * PI * SunDish.DISH_D * SunDish.DISH_D * 0.25 * BenchLight.COLLECT if to_sun.y > 0.0 else 0.0
	var focus := to_local(_dish.focus())
	var half := source * exp(-focus.distance_to(SPLIT) / BenchLight.FADE) * 0.5
	var ref_path := SPLIT.distance_to(REF_LOW) + REF_LOW.distance_to(REF_HIGH) + REF_HIGH.distance_to(BALANCE)
	var ref := half * exp(-ref_path / BenchLight.FADE)
	var wet := half * _ratio(level) * exp(-ref_path / BenchLight.FADE)
	_watts = [source, ref, wet]
	# The shaft: each stone's pull toward the upright about the shaft, the
	# bearings' drag, and their friction holding it below STICK's pull.
	var axis := global_basis.z.normalized()
	var stick := Photogyrite.pull(STICK, 0.0)
	var h := delta / STEPS
	for k in STEPS:
		var twist := 0.0
		for s in 2:
			var seeking := global_basis * (Basis(Vector3.BACK, _turn - PI * 0.5 * s) * Vector3.UP)
			twist += Photogyrite.pull(ref if s == 0 else wet, 0.0) * seeking.cross(Vector3.UP).dot(axis)
		if absf(_rate) < 0.05 and absf(twist) <= stick:
			_rate = 0.0
			continue
		twist -= signf(_rate if _rate != 0.0 else twist) * stick
		_rate += (twist - PIVOT * _rate) / INERTIA * h
		_turn += _rate * h
	_shaft.rotation.z = _turn
	_show(focus, source, half, ref, wet)


## The beams, the stones' glow, the water and the note.
func _show(focus: Vector3, source: float, half: float, ref: float, wet: float) -> void:
	var legs := [[focus, SPLIT, source], [SPLIT, REF_LOW, half], [REF_LOW, REF_HIGH, half], [REF_HIGH, BALANCE, ref],
			[SPLIT, TANK_LOW, half], [TANK_LOW, TANK_HIGH, half], [TANK_HIGH, BALANCE + Vector3(0, 0, GAP), wet]]
	for k in legs.size():
		var leg: Array = legs[k]
		var a: Vector3 = leg[0]
		var b: Vector3 = leg[1]
		var beam := _beams[k]
		beam.visible = float(leg[2]) > 0.0
		if not beam.visible:
			continue
		beam.material_override = _beam_mat if float(leg[2]) >= BenchLight.THRESHOLD else _dim_mat
		beam.transform = Transform3D(CozyMesh.aligned((b - a).normalized()).scaled_local(Vector3(1, a.distance_to(b), 1)), (a + b) * 0.5)
	for s in 2:
		_glows[s].emission_energy_multiplier = 0.1 + 0.9 * clampf((ref if s == 0 else wet) / 100.0, 0.0, 1.0)
	_water.visible = level > 0.005
	_water.scale = Vector3(1, maxf(level, 0.005), 1)
	_water.position = Vector3(TANK_LOW.x, COLUMN_FOOT + 0.004 + level * 0.5, TANK_LOW.z)
	var read := 0.0
	var at_empty := atan(_ratio(0.0))
	var at_full := atan(_ratio(MOST))
	if _turn >= at_empty:
		read = 0.0
	elif _turn <= at_full:
		read = 1.0
	else:
		# The level whose needle angle is the shaft's.
		read = clampf(-ABSORB * log(tan(_turn) / _ratio(0.0)) / MOST, 0.0, 1.0)
	_note.set_text("A beam balance\nTwo geotropes on one shaft a quarter turn apart, the first lit by half the collector's beam, the second by the other half after it has crossed the water. Each pulls the shaft its own way; it settles where they balance, and the needle reads the water's depth on the dial from the ratio of the two beams, whatever the sun.\nThe collector sends %d W; %d W reach the first stone and %d W the second. The needle reads %d%% full; the column is %d%% full." % [
			roundi(source), roundi(ref), roundi(wet), roundi(read * 100.0), roundi(level / MOST * 100.0)])
