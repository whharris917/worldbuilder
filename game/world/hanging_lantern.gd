class_name HangingLantern
extends Node3D
## A lantern hanging on a cord from a branch, swaying a little in the
## breeze: a small square lantern with glass sides that glow when lit and
## a warm point light inside (no shadows: several of them would cost
## too much). The node stands at the cord's top; the lantern swings
## about it.

const CORD := 0.6                      # before the lantern's scale
const ENERGY := 0.35

var _swing: Node3D
var _light: OmniLight3D
var _glass: StandardMaterial3D
var _phase := 0.0
var _clock := 0.0


## `frame` and `cord` are the metal and the cord's materials.
func _init(frame: Material, cord: Material, phase: float) -> void:
	name = "Lantern"
	set_meta(StaticMerge.MOVES, true)
	_phase = phase
	_swing = Node3D.new()
	add_child(_swing)
	_swing.scale = Vector3.ONE * 1.4       # read better at a distance than true size
	var string := CylinderMesh.new()
	string.top_radius = 0.008
	string.bottom_radius = 0.008
	string.height = CORD
	string.radial_segments = 6
	string.material = cord
	_add(string, Vector3(0, -CORD * 0.5, 0))
	var cap := CylinderMesh.new()
	cap.top_radius = 0.02
	cap.bottom_radius = 0.13
	cap.height = 0.08
	cap.radial_segments = 4
	cap.material = frame
	_add(cap, Vector3(0, -CORD - 0.04, 0)).rotation.y = PI * 0.25
	_glass = StandardMaterial3D.new()
	_glass.albedo_color = Color(1.0, 0.9, 0.7)
	_glass.emission = Color(1.0, 0.75, 0.4)
	var body := BoxMesh.new()
	body.size = Vector3(0.16, 0.22, 0.16)
	body.material = _glass
	_add(body, Vector3(0, -CORD - 0.19, 0))
	var base := BoxMesh.new()
	base.size = Vector3(0.19, 0.03, 0.19)
	base.material = frame
	_add(base, Vector3(0, -CORD - 0.315, 0))
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.72, 0.42)
	_light.omni_range = 5.0
	_light.position = Vector3(0, -CORD - 0.19, 0)
	_swing.add_child(_light)


func _add(mesh: Mesh, at: Vector3) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	_swing.add_child(view)
	return view


## Lit from 0 (out) to 1 (full).
func set_lit(level: float) -> void:
	_light.visible = level > 0.01
	_light.light_energy = ENERGY * level
	_glass.emission_enabled = level > 0.01
	_glass.emission_energy_multiplier = 3.0 * level


func _process(delta: float) -> void:
	# A slow sway in two directions at unrelated rates, a few degrees.
	_clock += delta
	_swing.rotation = Vector3(0.05 * sin(_clock * 1.3 + _phase), 0.0, 0.04 * sin(_clock * 0.9 + _phase * 2.1))
