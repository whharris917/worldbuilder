class_name CrystalShed
extends Node3D
## A demonstration: a dark wooden shed, a table in it under a spotlight,
## and on the table one spinstone crystal lying loose, to see what light
## does to a crystal of a given size that is not held by anything.
##
## The crystal is a rigid body of the engine's physics (its weight, the
## table's friction and its rolling and tipping are the engine's), its
## solid the crystal's own faceted shape, its mass from its volume at
## photogyrite's density (as quartz), its inertia that of the box round
## it. On it, each physics step, the spinstone laws of the gimbal stones
## (SpinstoneGimbals), as a combination stone: while lit, its axis (its
## length, the crystal's seeking end) is drawn toward its body, straight
## up for an earthstone, the sun for a sunstone (through the roof: the
## stone answers to the sun, the lamp only lights it), PULL_PER_WATT for
## each watt of light on it, and it is spun about its axis TURN for each
## watt while that end faces its body; the air drags on its turning, the
## drag growing with its size to the fifth power. The light on it is the
## spotlight's, in suns (a thousand watts a square metre each), over the
## crystal's mean shadow, a quarter of its surface. Unlit it is an inert
## stone.
##
## Its sounds come from what it does, quiet: a dull knock of stone on
## wood each time it strikes the table or rolls on to a new facet (the
## engine reporting a new touch, or its speed jumping), louder the harder,
## a little higher the smaller the stone (crystal_tap_1..4.wav); while it
## spins fast on its point its small hops are not heard, only a blow
## harder than they are (SPIN_FAST, SPIN_BLOW); and while it spins, the
## soft swoosh of the air it stirs (the windmill's swoosh_loop.wav),
## louder and a little higher the faster it spins; and while a point of
## it slides on the table, the rasp of a sharp stone dragged on wood
## (crystal_scrape_loop.wav: the point bumping over the grain, the top
## ringing), louder and quicker the faster the fastest touching point
## slides (its speed from the
## engine's touch points: the crystal's motion at each, along the table).
##
## Its size runs from a twentieth of a whole stone's volume (a whole
## stone is the gimbal stones' crystal) to five times a whole stone's
## length. Larger, the light's twist grows as its surface and its weight's
## hold as its volume times its size, so a small crystal stands up and
## spins where a large one only rocks or lies still.

const DENSITY := 2650.0                 # kg/m³
const WHOLE := 1.9                      # a whole stone's scale on the grown crystal, as in the gimbals
const SMALLEST := 0.368                 # the smallest's length, as a share of a whole stone's: a twentieth of its volume
const LARGEST := 5.0
const W := 6.0                          # the shed, inside: across (x)
const D := 4.5                          # and deep (z); the door in the south wall
const H := 3.0
const TABLE_TOP := 0.8
const TABLE := Vector2(2.8, 1.4)
const LAMP_UP := 2.75                   # the spotlight's height over the floor
const DRAG := 1.4e-3                    # N m s²: the air's drag on a whole stone's turning
const SPIN_FAST := 10.0                 # rad/s: spinning on its point, its hops unheard
const SPIN_BLOW := 0.8                  # m/s: the blow that is heard then
const CONE := 40.0                      # degrees: its beam, half across

## Toward the sun, set by the world.
var to_sun := Vector3.UP
## The spotlight: on, and how bright on the table, in suns.
var lamp_on := true
var suns := 50.0
## "sun" or "earth".
var kind := "sun"
## The crystal's length as a share of a whole stone's.
var size := SMALLEST
## Its knocks, its swoosh and its scrape heard, each.
var knocks_heard := true
var swoosh_heard := true
var scrape_heard := true

var _world: Node
var _crystal: RigidBody3D
var _glow: StandardMaterial3D
var _lamp: SpotLight3D
var _lamp_lens: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _seed := 7
var _area := 0.0                        # m²: the crystal's mean shadow
var _scale := 1.0
var _watts := 0.0
var _taps: Array[AudioStream] = []
var _tap: AudioStreamPlayer3D
var _buzz: AudioStreamPlayer3D
var _drag: AudioStreamPlayer3D
var _slide := 0.0                       # m/s: the fastest touching point's sliding, eased
var _touching := 0                      # the table's touches on it last step
var _was_v := Vector3.ZERO
var _was_w := Vector3.ZERO
var _since_tap := 1.0


## `world` gives the shed its materials (`material`).
func _init(world: Node) -> void:
	name = "CrystalShed"
	_world = world
	_rng.randomize()


func _ready() -> void:
	_build()
	_build_sound()
	reset()


func _build_sound() -> void:
	_tap = AudioStreamPlayer3D.new()
	_tap.unit_size = 3.0
	_tap.max_polyphony = 4
	add_child(_tap)
	_buzz = AudioStreamPlayer3D.new()
	_buzz.unit_size = 3.0
	_buzz.volume_db = -80.0
	add_child(_buzz)
	_drag = AudioStreamPlayer3D.new()
	_drag.unit_size = 3.0
	_drag.volume_db = -80.0
	add_child(_drag)
	if DisplayServer.get_name() == "headless":
		return
	for k in range(1, 5):
		_taps.append(load("res://audio/crystal_tap_%d.wav" % k))
	var loop := (load("res://audio/swoosh_loop.wav") as AudioStreamWAV).duplicate() as AudioStreamWAV
	loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	loop.loop_begin = 0
	loop.loop_end = int(loop.get_length() * loop.mix_rate)
	_buzz.stream = loop
	_buzz.autoplay = true
	_buzz.play()
	var drag_loop := load("res://audio/crystal_scrape_loop.wav") as AudioStreamWAV
	drag_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drag_loop.loop_begin = 0
	drag_loop.loop_end = int(drag_loop.get_length() * drag_loop.mix_rate)
	_drag.stream = drag_loop
	_drag.autoplay = true
	_drag.play()


## A new crystal, its own shape, set lying on the table.
func new_shape() -> void:
	_seed = _rng.randi()
	reset()


## The crystal made again at `size`, of the current shape, set down
## lying on the table, still.
func reset() -> void:
	if _crystal != null:
		_crystal.queue_free()
	_scale = WHOLE * size
	var grow := RandomNumberGenerator.new()
	grow.seed = _seed
	var cm := CozyMesh.new()
	LumenPart.grow_spinstone(cm, grow)
	var arrays := cm.commit(_glow).surface_get_arrays(0)
	var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
	var index: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
	for k in verts.size():
		verts[k] *= _scale
	# Its volume, middle (of mass) and surface, from its faces.
	var volume := 0.0
	var middle := Vector3.ZERO
	var surface := 0.0
	for k in range(0, index.size(), 3):
		var a := verts[index[k]]
		var b := verts[index[k + 1]]
		var c := verts[index[k + 2]]
		var v := a.dot(b.cross(c)) / 6.0
		volume += v
		middle += (a + b + c) * 0.25 * v
		surface += (b - a).cross(c - a).length() * 0.5
	# (Signed sums: the ratio is the middle whichever way the faces wind.)
	middle /= volume
	volume = absf(volume)
	for k in verts.size():
		verts[k] -= middle
	_area = surface * 0.25
	var box := AABB(verts[0], Vector3.ZERO)
	for v in verts:
		box = box.expand(v)
	_crystal = RigidBody3D.new()
	_crystal.name = "Crystal"
	_crystal.mass = DENSITY * volume
	var s := box.size
	_crystal.inertia = Vector3(s.y * s.y + s.z * s.z, s.x * s.x + s.z * s.z, s.x * s.x + s.y * s.y) * _crystal.mass / 12.0
	_crystal.can_sleep = false
	_crystal.continuous_cd = true
	_crystal.contact_monitor = true
	_crystal.max_contacts_reported = 4
	var friction := PhysicsMaterial.new()
	friction.friction = 0.6
	friction.bounce = 0.05
	_crystal.physics_material_override = friction
	var shape := ConvexPolygonShape3D.new()
	shape.points = verts
	var c := CollisionShape3D.new()
	c.shape = shape
	_crystal.add_child(c)
	var view_arrays := arrays.duplicate()
	view_arrays[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, view_arrays)
	mesh.surface_set_material(0, _glow)
	var view := MeshInstance3D.new()
	view.mesh = mesh
	_crystal.add_child(view)
	# Lying on its side across the table, a little above it, turned
	# at random about the upright.
	_crystal.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5),
			Vector3(0, TABLE_TOP + s.x * 0.5 + 0.02, 0))
	add_child(_crystal)


## A line for the panel.
func report() -> String:
	if _crystal == null:
		return ""
	var axis := _crystal.global_basis.y.normalized()
	var off := rad_to_deg(acos(clampf(axis.dot(_toward()), -1.0, 1.0)))
	var spin := _crystal.angular_velocity.dot(axis) / TAU
	return "%s %d cm long, %.1f kg; %d W of light on it; its seeking end %d degrees off %s; spinning %.1f turns a second." % [
			"Sunstone" if kind == "sun" else "Earthstone", roundi(_length() * 100.0), _crystal.mass, roundi(_watts), roundi(off),
			"the sun" if kind == "sun" else "straight up", absf(spin)]


func _length() -> float:
	return 0.223 * _scale


func _toward() -> Vector3:
	return to_sun if kind == "sun" else Vector3.UP


func _physics_process(delta: float) -> void:
	_lamp.visible = lamp_on
	_lamp.light_energy = 2.0 + 2.5 * log(1.0 + suns) / log(10.0)
	_lamp_lens.emission_energy_multiplier = 3.0 if lamp_on else 0.0
	if _crystal == null:
		return
	# The light on it: the spotlight's, within its beam.
	var from_lamp := _crystal.global_position - _lamp.global_position
	var off_beam := rad_to_deg(from_lamp.angle_to(-_lamp.global_basis.z))
	var irradiance := suns * 1000.0 * (1.0 - smoothstep(CONE - 3.0, CONE + 3.0, off_beam)) if lamp_on else 0.0
	_watts = irradiance * _area
	var axis := _crystal.global_basis.y.normalized()
	var toward := _toward()
	var w := _crystal.angular_velocity
	var grown := pow(_scale / WHOLE, 5.0)
	var twist := axis.cross(toward) * SpinstoneGimbals.PULL_PER_WATT * _watts \
			+ axis * SpinstoneGimbals.TURN * _watts * maxf(axis.dot(toward), 0.0) \
			- w * w.length() * DRAG * grown
	_crystal.apply_torque(twist)
	_glow.emission_energy_multiplier = 0.1 + 0.8 * clampf(absf(w.dot(axis)) / 15.0, 0.0, 1.0)
	_sound(delta, axis)


## The knocks and the buzz, from the crystal's touches and turning.
func _sound(delta: float, axis: Vector3) -> void:
	_tap.global_position = _crystal.global_position
	_buzz.global_position = _crystal.global_position
	var v := _crystal.linear_velocity
	var w := _crystal.angular_velocity
	var touching := _crystal.get_contact_count()
	# How hard it struck: the sudden change in the speed of its surface
	# (its middle's, and its turning's at its reach), less gravity's share.
	var reach := 0.07 * _scale
	var jolt := maxf((v - _was_v).length() - 9.8 * delta * 1.5, 0.0) + (w - _was_w).length() * reach * 0.5
	_since_tap += delta
	var spin := absf(w.dot(axis))
	var heard := false
	if spin > SPIN_FAST:
		heard = jolt > SPIN_BLOW
	else:
		heard = jolt > 0.25 or (touching > _touching and v.length() + w.length() * reach > 0.15)
	if touching > 0 and _since_tap > 0.03 and heard:
		_knock(maxf(jolt, (v.length() + w.length() * reach) * 0.5))
	_touching = touching
	_was_v = v
	_was_w = w
	var swoosh := clampf(spin / 60.0, 0.0, 1.0) if swoosh_heard else 0.0
	_buzz.volume_db = linear_to_db(maxf(swoosh * 0.4, 0.0001)) - 18.0 + 2.0 * log(_crystal.mass + 1.0) / log(10.0)
	_buzz.pitch_scale = clampf(0.8 + spin / 150.0, 0.6, 1.4)
	# The scrape: how fast the touching points slide along the table.
	var slide := 0.0
	var state := PhysicsServer3D.body_get_direct_state(_crystal.get_rid())
	if state != null:
		for k in state.get_contact_count():
			var at := state.get_contact_local_position(k) - state.transform.origin
			var moving := v + w.cross(at)
			var normal := state.get_contact_local_normal(k)
			slide = maxf(slide, (moving - normal * moving.dot(normal)).length())
	_slide = lerpf(_slide, slide, clampf(delta * 20.0, 0.0, 1.0))
	_drag.global_position = _crystal.global_position
	var drag := clampf(_slide / 0.8, 0.0, 1.0) if scrape_heard else 0.0
	_drag.volume_db = linear_to_db(maxf(drag, 0.0001)) - 8.0 + 2.0 * log(_crystal.mass + 1.0) / log(10.0)
	# Quicker as it slides faster: the bumps over the grain come closer.
	_drag.pitch_scale = clampf(0.7 + _slide * 0.6, 0.7, 1.5)


func _knock(speed: float) -> void:
	if _taps.is_empty() or not knocks_heard:
		return
	_since_tap = 0.0
	_tap.stream = _taps[_rng.randi() % _taps.size()]
	_tap.pitch_scale = _pitch() * _rng.randf_range(0.92, 1.08)
	_tap.volume_db = linear_to_db(clampf(speed / 1.2, 0.03, 1.0)) - 16.0 + 3.0 * log(_crystal.mass + 1.0) / log(10.0)
	_tap.play()


## Smaller stones ring higher: the pitch as the crystal's size's inverse
## square root, a small stone's at one.
func _pitch() -> float:
	return clampf(sqrt(SMALLEST / size), 0.35, 1.2)


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
	# The crystal's look: a spinstone's glass, glowing as it spins.
	_glow = StandardMaterial3D.new()
	_glow.albedo_color = Color(1.0, 0.72, 0.32, 0.9)
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	_glow.emission = Color(0.75, 0.42, 0.1)
	add_child(HoverNote.new(Vector3(0, TABLE_TOP * 0.5, 0), Vector3(TABLE.x, TABLE_TOP, TABLE.y),
			"A crystal under a spotlight\nA spinstone lying loose on the table. The Shed panel sets the lamp, the crystal's size and shape, and whether it is a sunstone or an earthstone."))


## The crystal's tint for its kind.
func set_kind(k: String) -> void:
	kind = k
	_glow.albedo_color = Color(1.0, 0.72, 0.32, 0.9) if k == "sun" else Color(0.74, 0.62, 0.95, 0.9)
	_glow.emission = Color(0.75, 0.42, 0.1) if k == "sun" else Color(0.5, 0.36, 0.85)
