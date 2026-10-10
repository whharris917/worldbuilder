class_name LanternLook
extends RefCounted
## Oil lanterns' heads, in five designs for the director to choose
## among, each built into a lantern's turning head (LumenPart.head_node):
## the beam leaves from a lens at the front of the body, LENS_Z ahead of
## the head's middle (where LumenPart sends it from), and the shutter,
## open, stands wholly out of the beam's way.
##
## - "bullseye": a police bullseye lantern. A tin drum with a chimney cap,
##   a domed bullseye lens on a collar; a cap on a side hinge closes over
##   the lens and swings round against the drum to open.
## - "signal": a ship's signal lamp. A brass tube, the lens in its front
##   bezel, a chimney; a venetian shutter of five slats before the lens
##   turns edge-on to open.
## - "lighthouse": a lighthouse lamp. A copper housing with a domed
##   reflector behind, a stepped (Fresnel) lens in front; two doors meet
##   over the lens and swing back to the sides to open.
## - "carriage": a carriage lamp. A square lantern in a brass frame with
##   glass sides, the flame seen burning within; the lens in a short hood
##   at the front, closed by a flap hinged above it that lifts up and back.
## - "globe": an alchemist's globe lamp. A glass globe with the flame
##   inside, in brass rings, a condenser tube at its front; an iris of six
##   blades slides in over the tube's mouth to close it.
##
## Each design gives its lens and flame a glow of their own (`set_lit`)
## and moves its shutter (`animate`, 0 shut to 1 open).

const LENS_Z := -0.2
const STYLES := ["bullseye", "signal", "lighthouse", "carriage", "globe"]


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
		"signal":
			_signal(head, mats, glow, look)
		"lighthouse":
			_lighthouse(head, mats, glow, look)
		"carriage":
			_carriage(head, mats, glow, flame_mat, look)
		"globe":
			_globe(head, mats, glow, flame_mat, look)
	return look


## The shutter moved, 0 shut to 1 open.
static func animate(look: Dictionary, open: float) -> void:
	var parts: Array = look["parts"]
	match str(look["style"]):
		"bullseye":
			(parts[0] as Node3D).rotation.y = lerpf(0.0, 2.5, open)
		"signal":
			for slat: Node3D in parts:
				slat.rotation.x = lerpf(0.0, PI * 0.5, open)
		"lighthouse":
			(parts[0] as Node3D).rotation.y = lerpf(0.0, -1.95, open)
			(parts[1] as Node3D).rotation.y = lerpf(0.0, 1.95, open)
		"carriage":
			(parts[0] as Node3D).rotation.x = lerpf(0.0, -1.8, open)
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


static func _signal(head: Node3D, mats: Dictionary, glow: Material, look: Dictionary) -> void:
	var body := CozyMesh.new()
	var gold := Color(0.85, 0.66, 0.32)
	var dark := Color(0.2, 0.2, 0.21)
	body.cyl(0.075, 0.075, 0.3, 24, CozyMesh.at(Vector3(0, 0, -0.04), _facing()), gold)
	body.torus(0.07, 0.088, 24, 6, CozyMesh.at(Vector3(0, 0, -0.19), _facing()), gold)
	body.cyl(0.078, 0.078, 0.012, 24, CozyMesh.at(Vector3(0, 0, 0.11), _facing()), gold)
	body.cyl(0.028, 0.028, 0.12, 12, CozyMesh.at(Vector3(0, 0.12, 0.03)), gold)
	body.cyl(0.0, 0.05, 0.035, 12, CozyMesh.at(Vector3(0, 0.2, 0.03)), dark)
	body.torus(0.035, 0.048, 16, 6, CozyMesh.at(Vector3(0, 0.08, -0.07), Basis(Vector3.FORWARD, PI * 0.5)), gold)
	# The shutter's frame before the lens.
	for s: float in [-1.0, 1.0]:
		body.box(Vector3(0.012, 0.19, 0.02), CozyMesh.at(Vector3(s * 0.085, 0, -0.215)), gold)
		body.box(Vector3(0.18, 0.012, 0.02), CozyMesh.at(Vector3(0, s * 0.095, -0.215)), gold)
	_mesh(head, body, mats["brass"])
	_one(head, _disc(0.068, 0.006), glow, Transform3D(_facing(), Vector3(0, 0, -0.196)))
	var slats: Array = []
	for k in 5:
		var slat := Node3D.new()
		slat.position = Vector3(0, -0.07 + 0.035 * k, -0.215)
		head.add_child(slat)
		var m := CozyMesh.new()
		m.box(Vector3(0.158, 0.036, 0.004), Transform3D.IDENTITY, dark)
		m.cyl(0.004, 0.004, 0.17, 6, CozyMesh.at(Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5)), gold)
		_mesh(slat, m, mats["iron"])
		slats.append(slat)
	look["parts"] = slats


static func _lighthouse(head: Node3D, mats: Dictionary, glow: Material, look: Dictionary) -> void:
	var body := CozyMesh.new()
	var copper := Color(0.72, 0.42, 0.26)
	var gold := Color(0.85, 0.66, 0.32)
	body.cyl(0.1, 0.1, 0.16, 24, CozyMesh.at(Vector3(0, 0, -0.09), _facing()), copper)
	body.ball(0.1, 20, CozyMesh.at(Vector3(0, 0, -0.01), Basis(Vector3.RIGHT, -PI * 0.5)), copper, true)
	body.cyl(0.03, 0.03, 0.1, 12, CozyMesh.at(Vector3(0, 0.14, -0.05)), copper)
	body.cyl(0.0, 0.065, 0.05, 16, CozyMesh.at(Vector3(0, 0.215, -0.05)), copper)
	_mesh(head, body, mats["copper"])
	var trim := CozyMesh.new()
	trim.torus(0.095, 0.112, 24, 6, CozyMesh.at(Vector3(0, 0, -0.172), _facing()), gold)
	trim.torus(0.095, 0.108, 24, 6, CozyMesh.at(Vector3(0, 0, -0.02), _facing()), gold)
	for s: float in [-1.0, 1.0]:
		trim.cyl(0.007, 0.007, 0.2, 6, CozyMesh.at(Vector3(s * 0.112, 0, -0.185)), gold)
	_mesh(head, trim, mats["brass"])
	# The stepped lens: rings stepping forward to its middle.
	for k in 4:
		_one(head, _disc(0.092 - 0.02 * k, 0.006), glow, Transform3D(_facing(), Vector3(0, 0, -0.176 - 0.007 * k)))
	var doors: Array = []
	for s: float in [-1.0, 1.0]:
		var hinge := Node3D.new()
		hinge.position = Vector3(s * 0.112, 0, -0.205)
		head.add_child(hinge)
		var m := CozyMesh.new()
		m.box(Vector3(0.11, 0.21, 0.008), CozyMesh.at(Vector3(-s * 0.056, 0, 0)), copper)
		m.ball(0.01, 8, CozyMesh.at(Vector3(-s * 0.095, 0, -0.01)), gold)
		_mesh(hinge, m, mats["copper"])
		doors.append(hinge)
	look["parts"] = doors


static func _carriage(head: Node3D, mats: Dictionary, glow: Material, flame_mat: Material, look: Dictionary) -> void:
	var frame := CozyMesh.new()
	var gold := Color(0.85, 0.66, 0.32)
	for x: float in [-0.09, 0.09]:
		for z: float in [-0.08, 0.08]:
			frame.box(Vector3(0.018, 0.22, 0.018), CozyMesh.at(Vector3(x, 0, z)), gold)
	frame.box(Vector3(0.2, 0.02, 0.18), CozyMesh.at(Vector3(0, -0.11, 0)), gold)
	frame.box(Vector3(0.2, 0.02, 0.18), CozyMesh.at(Vector3(0, 0.11, 0)), gold)
	frame.cyl(0.02, 0.15, 0.09, 4, CozyMesh.at(Vector3(0, 0.165, 0), Basis(Vector3.UP, PI * 0.25)), gold)
	frame.ball(0.018, 8, CozyMesh.at(Vector3(0, 0.22, 0)), gold)
	# The front plate, the hood and its lens; the burner.
	frame.box(Vector3(0.18, 0.2, 0.008), CozyMesh.at(Vector3(0, 0, -0.082)), gold)
	frame.cyl(0.062, 0.062, 0.1, 20, CozyMesh.at(Vector3(0, 0, -0.135), _facing()), gold)
	frame.cyl(0.02, 0.03, 0.04, 10, CozyMesh.at(Vector3(0, -0.08, 0.01)), gold)
	_mesh(head, frame, mats["brass"])
	var back := CozyMesh.new()
	back.box(Vector3(0.18, 0.2, 0.008), CozyMesh.at(Vector3(0, 0, 0.082)), Color(0.72, 0.42, 0.26))
	_mesh(head, back, mats["copper"])
	for s: float in [-1.0, 1.0]:
		_one(head, BoxMesh.new(), mats["glass"], Transform3D(Basis.from_scale(Vector3(0.006, 0.2, 0.16)), Vector3(s * 0.09, 0, 0)))
	_one(head, _disc(0.058, 0.008), glow, Transform3D(_facing(), Vector3(0, 0, -0.188)))
	var flame := SphereMesh.new()
	flame.radius = 0.022
	flame.height = 0.08
	look["flame"] = _one(head, flame, flame_mat, Transform3D(Basis.IDENTITY, Vector3(0, -0.025, 0.01)))
	# The flap, hinged above the hood's mouth.
	var hinge := Node3D.new()
	hinge.position = Vector3(0, 0.068, -0.19)
	head.add_child(hinge)
	var m := CozyMesh.new()
	m.cyl(0.068, 0.068, 0.008, 20, CozyMesh.at(Vector3(0, -0.068, -0.006), _facing()), gold)
	m.cyl(0.006, 0.006, 0.06, 6, CozyMesh.at(Vector3.ZERO, Basis(Vector3.FORWARD, PI * 0.5)), gold)
	m.ball(0.01, 8, CozyMesh.at(Vector3(0, -0.12, -0.012)), gold)
	_mesh(hinge, m, mats["brass"])
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
