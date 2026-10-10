class_name LanternLook
extends RefCounted
## Oil lanterns' heads, in two designs, each built into a lantern's
## turning head (LumenPart.head_node): the beam leaves from a lens at the
## front of the body, LENS_Z ahead of the head's middle (where LumenPart
## sends it from), and the shutter, open, stands wholly out of the beam's
## way.
##
## - "bullseye": a police bullseye lantern. A tin drum with a chimney cap,
##   a domed bullseye lens on a collar; a cap on a side hinge closes over
##   the lens and swings outward, away from the drum, to lie open beside
##   the lens.
## - "globe": an alchemist's globe lamp. A glass globe with the flame
##   inside, in brass rings, a condenser tube at its front; an iris of six
##   blades slides in over the tube's mouth to close it.
##
## Each design gives its lens and flame a glow of their own (`set_lit`)
## and moves its shutter (`animate`, 0 shut to 1 open).

const LENS_Z := -0.2
const STYLES := ["bullseye", "globe"]


## Builds `style` into `head`. `mats`: "brass", "copper", "iron", "glass".
## What it returns is passed back to `animate` and `set_lit`.
static func build(style: String, head: Node3D, mats: Dictionary) -> Dictionary:
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.86, 0.6)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.72, 0.36)
	glow.emission_energy_multiplier = 0.0
	var flame_mat := StandardMaterial3D.new()
	flame_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flame_mat.albedo_color = Color(1.0, 0.75, 0.3)
	var look := {"style": style, "glow": glow, "flame": null, "parts": []}
	match style:
		"bullseye":
			_bullseye(head, mats, glow, look)
		"globe":
			_globe(head, mats, glow, flame_mat, look)
	return look


## The shutter moved, 0 shut to 1 open.
static func animate(look: Dictionary, open: float) -> void:
	var parts: Array = look["parts"]
	match str(look["style"]):
		"bullseye":
			(parts[0] as Node3D).rotation.y = lerpf(0.0, -2.9, open)
		"globe":
			for blade: Node3D in parts:
				blade.position = blade.get_meta("out") * lerpf(0.026, 0.072, open)


## The lens and the flame aglow while it burns.
static func set_lit(look: Dictionary, lit: bool) -> void:
	(look["glow"] as StandardMaterial3D).emission_energy_multiplier = 2.5 if lit else 0.0
	if look["flame"] != null:
		(look["flame"] as Node3D).visible = lit


## ---- the designs ------------------------------------------------------------

static func _mesh(parent: Node3D, m: CozyMesh, mat: Material) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = m.commit(mat)
	parent.add_child(view)
	return view


## A primitive's MeshInstance with its own material.
static func _one(parent: Node3D, mesh: PrimitiveMesh, mat: Material, xf: Transform3D) -> MeshInstance3D:
	mesh.material = mat
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.transform = xf
	parent.add_child(view)
	return view


static func _disc(r: float, h: float) -> CylinderMesh:
	var d := CylinderMesh.new()
	d.top_radius = r
	d.bottom_radius = r
	d.height = h
	d.radial_segments = 24
	d.rings = 1
	return d


## Basis turning a primitive's y axis to the head's forward (-z).
static func _facing() -> Basis:
	return Basis(Vector3.RIGHT, PI * 0.5)


static func _bullseye(head: Node3D, mats: Dictionary, glow: Material, look: Dictionary) -> void:
	var tin := CozyMesh.new()
	var brass := CozyMesh.new()
	var black := Color(0.18, 0.18, 0.19)
	var gold := Color(0.85, 0.66, 0.32)
	tin.cyl(0.085, 0.085, 0.22, 20, CozyMesh.at(Vector3(0, 0, 0.02)), black)
	tin.cyl(0.03, 0.09, 0.06, 20, CozyMesh.at(Vector3(0, 0.14, 0.02)), black)
	tin.cyl(0.035, 0.035, 0.06, 12, CozyMesh.at(Vector3(0, 0.2, 0.02)), black)
	tin.cyl(0.055, 0.055, 0.01, 16, CozyMesh.at(Vector3(0, 0.235, 0.02)), black)
	brass.cyl(0.062, 0.07, 0.09, 20, CozyMesh.at(Vector3(0, 0, -0.125), _facing()), gold)
	brass.torus(0.07, 0.085, 20, 6, CozyMesh.at(Vector3(0, 0, -0.168), _facing()), gold)
	brass.torus(0.04, 0.052, 16, 6, CozyMesh.at(Vector3(0, 0.04, 0.11), Basis(Vector3.FORWARD, PI * 0.5)), gold)
	for y: float in [-0.1, 0.105]:
		brass.cyl(0.088, 0.088, 0.012, 20, CozyMesh.at(Vector3(0, y, 0.02)), gold)
	_mesh(head, tin, mats["iron"])
	_mesh(head, brass, mats["brass"])
	var lens := SphereMesh.new()
	lens.radius = 0.068
	lens.height = 0.06
	lens.radial_segments = 20
	lens.rings = 8
	_one(head, lens, glow, Transform3D(_facing(), Vector3(0, 0, -0.175)))
	# The cap, on a hinge at the collar's side.
	var hinge := Node3D.new()
	hinge.position = Vector3(0.078, 0, -0.19)
	head.add_child(hinge)
	var cap := CozyMesh.new()
	cap.cyl(0.078, 0.078, 0.012, 20, CozyMesh.at(Vector3(-0.078, 0, -0.012), _facing()), black)
	cap.ball(0.012, 8, CozyMesh.at(Vector3(-0.078, 0, -0.022)), gold)
	cap.cyl(0.008, 0.008, 0.05, 6, CozyMesh.at(Vector3.ZERO), gold)
	_mesh(hinge, cap, mats["iron"])
	look["parts"] = [hinge]


static func _globe(head: Node3D, mats: Dictionary, glow: Material, flame_mat: Material, look: Dictionary) -> void:
	var gold := Color(0.85, 0.66, 0.32)
	_one(head, SphereMesh.new(), mats["glass"], Transform3D(Basis.from_scale(Vector3.ONE * 0.2), Vector3(0, 0, 0.03)))
	var flame := SphereMesh.new()
	flame.radius = 0.024
	flame.height = 0.085
	look["flame"] = _one(head, flame, flame_mat, Transform3D(Basis.IDENTITY, Vector3(0, -0.005, 0.03)))
	var brass := CozyMesh.new()
	for b: Basis in [Basis.IDENTITY, Basis(Vector3.FORWARD, PI * 0.5), Basis(Vector3.RIGHT, PI * 0.5)]:
		brass.torus(0.104, 0.114, 28, 6, CozyMesh.at(Vector3(0, 0, 0.03), b), gold)
	brass.cyl(0.02, 0.03, 0.04, 10, CozyMesh.at(Vector3(0, -0.06, 0.03)), gold)
	brass.cyl(0.03, 0.04, 0.03, 12, CozyMesh.at(Vector3(0, -0.11, 0.03)), gold)
	brass.cyl(0.02, 0.02, 0.06, 10, CozyMesh.at(Vector3(0, 0.14, 0.03)), gold)
	brass.cyl(0.0, 0.04, 0.025, 12, CozyMesh.at(Vector3(0, 0.18, 0.03)), gold)
	# The condenser tube from the globe's front, its mouth's ring.
	brass.cyl(0.04, 0.046, 0.13, 20, CozyMesh.at(Vector3(0, 0, -0.125), _facing()), gold)
	brass.torus(0.045, 0.072, 24, 6, CozyMesh.at(Vector3(0, 0, -0.19), _facing()), gold)
	_mesh(head, brass, mats["brass"])
	_one(head, _disc(0.04, 0.006), glow, Transform3D(_facing(), Vector3(0, 0, -0.186)))
	var blades: Array = []
	for k in 6:
		var a := TAU * k / 6.0
		var out := Vector3(cos(a), sin(a), 0)
		var blade := Node3D.new()
		blade.set_meta("out", out)
		head.add_child(blade)
		blade.position = out * 0.026
		var m := CozyMesh.new()
		m.box(Vector3(0.036, 0.05, 0.003), CozyMesh.at(Vector3(0, 0, -0.197 - 0.0012 * k), Basis(Vector3.BACK, a + PI * 0.5)), Color(0.2, 0.2, 0.21))
		_mesh(blade, m, mats["iron"])
		blades.append(blade)
	look["parts"] = blades
