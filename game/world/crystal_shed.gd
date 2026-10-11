class_name CrystalShed
extends Node3D
## A demonstration: a dark wooden shed, a table in it under a spotlight,
## and on the table one or two spinstone crystals lying loose
## (ShedCrystal, each with its own kind, size and shape), to see what
## light does to a crystal of a given size that is not held by anything,
## and to two together. The shed gives them the spotlight's light, the
## sun's direction and the sound settings.
##
## A crystal's size runs from a twentieth of a whole stone's volume (a
## whole stone is the gimbal stones' crystal) to five times a whole
## stone's length. Larger, the light's twist grows as its surface and its
## weight's hold as its volume times its size, so a small crystal stands
## up and spins where a large one only rocks or lies still.

const SMALLEST := 0.368                 # the smallest's length, as a share of a whole stone's: a twentieth of its volume
const LARGEST := 5.0
const W := 6.0                          # the shed, inside: across (x)
const D := 4.5                          # and deep (z); the door in the south wall
const H := 3.0
const TABLE_TOP := 0.8
const TABLE := Vector2(2.8, 1.4)
const LAMP_UP := 2.75                   # the spotlight's height over the floor
const CONE := 40.0                      # degrees: its beam, half across

## Toward the sun, set by the world.
var to_sun := Vector3.UP
## The spotlight: on, and how bright on the table, in suns.
var lamp_on := true
var suns := 50.0
## The crystals' knocks and scrapes heard, each; how much lower a larger
## stone sounds (ShedCrystal._pitch).
var knocks_heard := true
var scrape_heard := true
var pitch_drop := 0.7
## The crystals: the first, and the second, on the table when chosen.
var crystals: Array[ShedCrystal] = []

var _world: Node
var _lamp: SpotLight3D
var _lamp_lens: StandardMaterial3D


## `world` gives the shed its materials (`material`).
func _init(world: Node) -> void:
	name = "CrystalShed"
	_world = world


func _ready() -> void:
	_build()
	# The first a little west of the table's middle, the second east.
	for k in 2:
		var c := ShedCrystal.new(self, 7 + k * 31, Vector3(-0.45 if k == 0 else 0.45, 0, 0))
		c.visible = k == 0
		# The second an earthstone to begin, as its panel row says.
		c.kind = "sun" if k == 0 else "earth"
		crystals.append(c)
		add_child(c)


## The spotlight's light, W/m², at `at` (global): within its beam.
func light_at(at: Vector3) -> float:
	if not lamp_on:
		return 0.0
	var off_beam := rad_to_deg((at - _lamp.global_position).angle_to(-_lamp.global_basis.z))
	return suns * 1000.0 * (1.0 - smoothstep(CONE - 3.0, CONE + 3.0, off_beam))


## Lines for the panel, one for each crystal on the table.
func report() -> String:
	var lines: Array[String] = []
	for k in crystals.size():
		if crystals[k].visible:
			lines.append("%s: %s" % ["First" if k == 0 else "Second", crystals[k].report()])
	return "\n".join(lines)


func _physics_process(_delta: float) -> void:
	_lamp.visible = lamp_on
	_lamp.light_energy = 2.0 + 2.5 * log(1.0 + suns) / log(10.0)
	_lamp_lens.emission_energy_multiplier = 3.0 if lamp_on else 0.0


## ---- building ----------------------------------------------------------------

func _inside_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.metallic_specular = 0.0
	# Little of the sky's light inside: the shed is dark but for its lamp.
	var grey := Image.create(1, 1, false, Image.FORMAT_RGB8)
	grey.fill(Color(0.1, 0.1, 0.1))
	m.ao_enabled = true
	m.ao_texture = ImageTexture.create_from_image(grey)
	m.ao_light_affect = 0.0
	return m


func _build() -> void:
	var outside: StandardMaterial3D = _world.call("material", true, false)
	var inside := _inside_mat()
	var plank := Color(0.52, 0.38, 0.26)
	var dark := Color(0.36, 0.27, 0.2)
	var t := 0.1
	var out := CozyMesh.new()
	var lining := CozyMesh.new()
	var body := StaticBody3D.new()
	add_child(body)
	var solid := func(extent: Vector3, at: Vector3) -> void:
		var shape := BoxShape3D.new()
		shape.size = extent
		var c := CollisionShape3D.new()
		c.shape = shape
		c.position = at
		body.add_child(c)
	# Walls, the south one with a doorway 1.1 m wide by 2.1 high.
	var door_w := 1.1
	var door_h := 2.1
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * (W * 0.5 + t * 0.5), H * 0.5, 0)
		out.box(Vector3(t, H, D + t * 2.0), CozyMesh.at(at), plank)
		lining.box(Vector3(0.01, H, D), CozyMesh.at(at - Vector3(side * (t * 0.5 + 0.006), 0, 0)), dark)
		solid.call(Vector3(t, H, D + t * 2.0), at)
	var north := Vector3(0, H * 0.5, -D * 0.5 - t * 0.5)
	out.box(Vector3(W, H, t), CozyMesh.at(north), plank)
	lining.box(Vector3(W, H, 0.01), CozyMesh.at(north + Vector3(0, 0, t * 0.5 + 0.006)), dark)
	solid.call(Vector3(W, H, t), north)
	var piece := (W - door_w) * 0.5
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * (door_w * 0.5 + piece * 0.5), H * 0.5, D * 0.5 + t * 0.5)
		out.box(Vector3(piece, H, t), CozyMesh.at(at), plank)
		lining.box(Vector3(piece, H, 0.01), CozyMesh.at(at - Vector3(0, 0, t * 0.5 + 0.006)), dark)
		solid.call(Vector3(piece, H, t), at)
	var lintel := Vector3(0, door_h + (H - door_h) * 0.5, D * 0.5 + t * 0.5)
	out.box(Vector3(door_w, H - door_h, t), CozyMesh.at(lintel), plank)
	solid.call(Vector3(door_w, H - door_h, t), lintel)
	# Roof and floor.
	var roof := Vector3(0, H + t * 0.5, 0)
	out.box(Vector3(W + 0.6, t, D + 0.6), CozyMesh.at(roof), Color(0.3, 0.26, 0.24))
	lining.box(Vector3(W, 0.01, D), CozyMesh.at(roof - Vector3(0, t * 0.5 + 0.006, 0)), dark)
	solid.call(Vector3(W + 0.6, t, D + 0.6), roof)
	lining.box(Vector3(W, 0.04, D), CozyMesh.at(Vector3(0, 0.02, 0)), Color(0.4, 0.3, 0.22))
	solid.call(Vector3(W, 0.04, D), Vector3(0, 0.02, 0))
	# The table, a lip round its top to keep the crystal on it.
	var top := Vector3(0, TABLE_TOP - 0.03, 0)
	lining.box(Vector3(TABLE.x, 0.06, TABLE.y), CozyMesh.at(top), Color(0.55, 0.42, 0.3))
	solid.call(Vector3(TABLE.x, 0.06, TABLE.y), top)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			lining.box(Vector3(0.08, TABLE_TOP - 0.06, 0.08), CozyMesh.at(Vector3(sx * (TABLE.x * 0.5 - 0.1), (TABLE_TOP - 0.06) * 0.5, sz * (TABLE.y * 0.5 - 0.1))), dark)
		var lip := Vector3(sx * (TABLE.x * 0.5 - 0.02), TABLE_TOP + 0.06, 0)
		lining.box(Vector3(0.04, 0.12, TABLE.y), CozyMesh.at(lip), dark)
		solid.call(Vector3(0.04, 0.12, TABLE.y), lip)
		var lip_z := Vector3(0, TABLE_TOP + 0.06, sx * (TABLE.y * 0.5 - 0.02))
		lining.box(Vector3(TABLE.x, 0.12, 0.04), CozyMesh.at(lip_z), dark)
		solid.call(Vector3(TABLE.x, 0.12, 0.04), lip_z)
	# The spotlight hanging from the roof over the table's middle.
	var brass := Color(0.85, 0.66, 0.32)
	lining.rod(Vector3(0, H, 0), Vector3(0, LAMP_UP + 0.18, 0), 0.015, 6, Color(0.2, 0.2, 0.2))
	lining.cyl(0.07, 0.14, 0.2, 16, CozyMesh.at(Vector3(0, LAMP_UP + 0.08, 0)), brass, false)
	for m: Array in [[out, outside], [lining, inside]]:
		var view := MeshInstance3D.new()
		view.mesh = (m[0] as CozyMesh).commit(m[1])
		add_child(view)
	_lamp_lens = StandardMaterial3D.new()
	_lamp_lens.albedo_color = Color(1.0, 0.95, 0.85)
	_lamp_lens.emission_enabled = true
	_lamp_lens.emission = Color(1.0, 0.92, 0.75)
	var lens := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = 0.12
	disc.bottom_radius = 0.12
	disc.height = 0.01
	disc.material = _lamp_lens
	lens.mesh = disc
	lens.position = Vector3(0, LAMP_UP - 0.02, 0)
	add_child(lens)
	_lamp = SpotLight3D.new()
	_lamp.position = Vector3(0, LAMP_UP - 0.03, 0)
	_lamp.rotation = Vector3(-PI * 0.5, 0, 0)
	_lamp.spot_angle = CONE
	_lamp.spot_range = 6.0
	_lamp.spot_attenuation = 0.0
	_lamp.shadow_enabled = true
	_lamp.light_color = Color(1.0, 0.94, 0.82)
	add_child(_lamp)
	# Its door, hung at the doorway's west jamb, opening inward.
	var door := MillDoor.new(door_w - 0.04, door_h - 0.03, Color(0.42, 0.3, 0.2), outside, "Door\nThe shed's door. A click opens and shuts it.")
	door.position = Vector3(-door_w * 0.5 + 0.02, 0.01, D * 0.5 + t * 0.5)
	add_child(door)
	add_child(HoverNote.new(Vector3(0, TABLE_TOP * 0.5, 0), Vector3(TABLE.x, TABLE_TOP, TABLE.y),
			"Crystals under a spotlight\nOne or two spinstones lying loose on the table. The Shed panel sets the lamp and, for each crystal, its size and shape and whether it is a sunstone or an earthstone."))
