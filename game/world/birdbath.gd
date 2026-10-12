class_name Birdbath
extends Node3D
## For the teaser: an old stone birdbath, and a small earthstone in its
## water that stands up and spins in the sun and falls over in shadow.
##
## The stone is a combination stone: lit, its seeking end is drawn
## toward its body, the upright (Photogyrite.pull, PULL times the game's
## law), and it is spun about its length as much as it points there
## (Photogyrite.spin, FORCE times the game's law: the teaser's licence).
## It rocks about its foot in the middle of the bowl as one swinging
## body: gravity tips it over (its weight at its middle), the pull rights
## it, the water damps its swing; lying, it rests on its side on the
## bowl's floor. So in the sun it rises, stands and spins up; when a
## sail's shadow takes its light, nothing holds it, it topples into the
## water and its spin is soon spent against the bowl, and when the sun
## comes back it rises again, each time falling a new way. It is lit
## while nothing stands between it and the sun: the house and the mill's
## tower by a ray toward the sun, the turning sails by their own
## reckoning (Windmill.sail_shades). It glows the brighter the faster it
## turns, brighter than the game's stones (also the teaser's licence),
## with a small violet light of its own.
##
## Built at the bath's foot on the ground.

const FORCE := 2.5                      # times the spin law's strength
const PULL := 20.0                      # times the pull law's strength
const AREA := 0.0016                    # m²: the light it catches, a quarter of its surface
const MASS := 0.08                      # kg
const SPIN_INERTIA := 6.0e-6            # kg m²: about its length
const WET := 7.0e-5                     # N m s: the water's drag on its spin
const LYING := 2.0e-3                   # N m: the bowl's drag on its spin while it lies
const SWING_DAMP := 1.5e-3              # N m s: the water's and air's drag on its rocking
const BOUNCE := 0.2
const WOBBLE := 0.04                    # rad: its least lean standing
const BOWL_Y := 0.92                    # m: the bowl's floor over the ground
const STONE_LONG := 0.1                 # m
const THICK := 0.012                    # m: its half thickness, lying on its side

## Toward the sun and its direct light, W/m², set by the teaser.
var to_sun := Vector3.UP
var sunlight := 0.0
var mill: Windmill
## Turns a second now, how far it leans from upright (rad), and whether
## it is lit.
var rate := 0.0
var lean := PI * 0.5
var lit := false

var _stone := Node3D.new()
var _glow: StandardMaterial3D
var _light: OmniLight3D
var _mat: Material
var _lean_rate := 0.0
var _toward := 0.4                      # rad: the way it leans, round the upright
var _spun := 0.0                        # rad: its turn about its length
var _rng := RandomNumberGenerator.new()


func _init(world_mat: Material, windmill: Windmill) -> void:
	name = "Birdbath"
	_mat = world_mat
	mill = windmill
	_rng.seed = 1817


func _ready() -> void:
	_build()
	_place()


func _physics_process(delta: float) -> void:
	var axis := _stone.global_basis.y.normalized()
	var middle := _stone.global_position + axis * STONE_LONG * 0.5
	lit = sunlight > 0.0 and to_sun.y > 0.0
	if lit:
		var ray := PhysicsRayQueryParameters3D.create(middle, middle + to_sun * 80.0, 1)
		lit = get_world_3d().direct_space_state.intersect_ray(ray).is_empty()
	if lit and mill != null:
		lit = not mill.sail_shades(middle, to_sun)
	var watts := sunlight * AREA if lit else 0.0
	# Its rocking about its foot: its weight tips it, the pull rights it.
	var swing_inertia := MASS * STONE_LONG * STONE_LONG / 3.0
	var tip_over := MASS * 9.8 * STONE_LONG * 0.5 * sin(lean)
	var right := PULL * Photogyrite.pull(watts, 0.0) * sin(lean)
	_lean_rate += (tip_over - right - SWING_DAMP * _lean_rate) / swing_inertia * delta
	lean += _lean_rate * delta
	if lean >= PI * 0.5:
		lean = PI * 0.5
		if _lean_rate > 0.0:
			_lean_rate = -_lean_rate * BOUNCE
	# Upright it balances on nothing and its spin wobbles it a little off
	# true: the least lean WOBBLE, and a new way to fall each time it has
	# stood.
	if lean < WOBBLE + 0.02:
		if lean <= WOBBLE:
			_toward = _rng.randf() * TAU
			_lean_rate = maxf(_lean_rate, 0.0)
		lean = maxf(lean, WOBBLE)
	# Its spin: driven as much as it points up, spent against the water
	# and, lying, the bowl.
	var omega := rate * TAU
	var twist := FORCE * Photogyrite.spin(watts, cos(lean), omega, 0.0) - WET * omega
	var drag := LYING * smoothstep(0.8, 1.4, lean)
	var next := omega + (twist - signf(omega) * drag) / SPIN_INERTIA * delta
	if omega != 0.0 and signf(next) != signf(omega) and absf(twist) <= drag:
		next = 0.0
	rate = next / TAU
	_spun = wrapf(_spun + next * delta, 0.0, TAU)
	_place()
	var bright := clampf(absf(next) / 12.0, 0.0, 1.0) * 0.8 + (0.2 if lit else 0.0)
	_glow.emission_energy_multiplier = 0.3 + 5.0 * bright
	_light.light_energy = 0.1 + 1.6 * bright


## The stone leaning `lean` toward `_toward`, turned `_spun` about its
## length, its foot in the bowl's middle, raised by its thickness as it
## lies.
func _place() -> void:
	var across := Vector3(cos(_toward), 0, sin(_toward)).cross(Vector3.UP).normalized()
	_stone.basis = Basis(across, lean) * Basis(Vector3.UP, _spun)
	_stone.position = Vector3(0, BOWL_Y - 0.004 + THICK * sin(lean), 0)
	if _light != null:
		_light.position = _stone.position + _stone.basis.y * STONE_LONG * 0.5 + Vector3(0, 0.06, 0)


func _build() -> void:
	var m := CozyMesh.new()
	var stone := Color(0.62, 0.6, 0.54)
	# A square foot, a turned column, the bowl on it, its lip chipped.
	m.box(Vector3(0.42, 0.1, 0.42), CozyMesh.at(Vector3(0, 0.05, 0)), stone.darkened(0.1))
	m.cyl(0.11, 0.14, 0.62, 12, CozyMesh.at(Vector3(0, 0.41, 0)), stone)
	m.cyl(0.16, 0.12, 0.06, 12, CozyMesh.at(Vector3(0, 0.75, 0)), stone.darkened(0.05))
	m.cyl(0.36, 0.2, 0.16, 20, CozyMesh.at(Vector3(0, 0.84, 0)), stone)
	m.torus(0.32, 0.37, 20, 5, CozyMesh.at(Vector3(0, 0.92, 0)), stone.lightened(0.05))
	m.box(Vector3(0.1, 0.06, 0.08), CozyMesh.at(Vector3(0.34, 0.93, 0.08), Basis(Vector3.UP, 0.4)), stone.darkened(0.2))
	# Lichen and moss on it, a crust of green at the foot.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1809
	for k in 14:
		var a := rng.randf() * TAU
		var y := rng.randf_range(0.15, 0.85)
		var r := 0.12 + (0.2 if y > 0.78 else 0.0)
		var spot := Vector3(cos(a) * r, y, sin(a) * r)
		m.ball(rng.randf_range(0.02, 0.05), 6, CozyMesh.at(spot, CozyMesh.aligned(Vector3(cos(a), 0, sin(a))) * Basis.from_scale(Vector3(1.0, 0.25, 1.0))), [Color(0.7, 0.7, 0.44), Color(0.82, 0.58, 0.24), Color(0.4, 0.5, 0.28)][rng.randi() % 3])
	for k in 8:
		var a := rng.randf() * TAU
		m.ball(rng.randf_range(0.04, 0.08), 6, CozyMesh.at(Vector3(cos(a) * 0.22, 0.1, sin(a) * 0.22), Basis.from_scale(Vector3(1.0, 0.4, 1.0))), Color(0.32, 0.44, 0.22))
	var view := MeshInstance3D.new()
	view.mesh = m.commit(_mat)
	add_child(view)
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 0.3
	cyl.height = 0.95
	shape.shape = cyl
	shape.position = Vector3(0, 0.475, 0)
	body.add_child(shape)
	add_child(body)
	# The water, rain held in the bowl, a hollow worn in its floor.
	var water := StandardMaterial3D.new()
	water.albedo_color = Color(0.42, 0.5, 0.48, 0.55)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.04
	water.metallic_specular = 0.9
	var pool := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.33
	disc.bottom_radius = 0.33
	disc.height = 0.004
	disc.radial_segments = 24
	disc.material = water
	pool.mesh = disc
	pool.position = Vector3(0, BOWL_Y - 0.005, 0)
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	# The stone, lying in the water to begin.
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(0.74, 0.62, 0.95, 0.92)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	_glow.emission = Color(0.55, 0.38, 0.95)
	var grown := CozyMesh.new()
	var grow := RandomNumberGenerator.new()
	grow.seed = 61
	LumenPart.grow_spinstone(grown, grow)
	var crystal := MeshInstance3D.new()
	crystal.mesh = grown.commit(_glow)
	var aabb := crystal.mesh.get_aabb()
	var scale_by := STONE_LONG / aabb.size.y
	crystal.transform = Transform3D(Basis.from_scale(Vector3.ONE * scale_by), Vector3(0, -aabb.position.y * scale_by, 0))
	_stone.add_child(crystal)
	# A pale flaw down one face, so its turning can be followed.
	var flaw := MeshInstance3D.new()
	var streak := BoxMesh.new()
	streak.size = Vector3(0.006, STONE_LONG * 0.55, 0.004)
	var flaw_mat := StandardMaterial3D.new()
	flaw_mat.albedo_color = Color(0.95, 0.92, 1.0)
	flaw_mat.emission_enabled = true
	flaw_mat.emission = Color(0.9, 0.85, 1.0)
	flaw_mat.emission_energy_multiplier = 0.6
	streak.material = flaw_mat
	flaw.mesh = streak
	var reach := maxf(aabb.size.x, aabb.size.z) * scale_by * 0.42
	flaw.position = Vector3(reach, STONE_LONG * 0.5, 0)
	_stone.add_child(flaw)
	add_child(_stone)
	_light = OmniLight3D.new()
	_light.light_color = Color(0.62, 0.45, 1.0)
	_light.omni_range = 1.4
	_light.position = Vector3(0, BOWL_Y + 0.08, 0)
	add_child(_light)
