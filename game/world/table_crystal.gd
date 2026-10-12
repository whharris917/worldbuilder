class_name TableCrystal
extends Node3D
## One spinstone crystal lying loose on a table (CrystalTable), with its
## own kind, size and shape, its laws and its sounds; the table gives the
## light, the sun's direction and the sound settings.
##
## The crystal is a rigid body of the engine's physics (its weight, the
## table's friction, its rolling and tipping, its knocking into another
## crystal are the engine's), its solid the crystal's own faceted shape,
## its mass from its volume at photogyrite's density (as quartz), its
## inertia that of the box round it. On it, each physics step, the
## spinstone laws of the gimbal stones (SpinstoneGimbals), as a
## combination stone: while lit, its axis (its length, the crystal's
## seeking end) is drawn toward its body, straight up for an earthstone,
## the sun for a sunstone (through the roof: the stone answers to the
## sun's direction wherever its light comes from), PULL_PER_WATT for each watt of light on
## it, and it is spun about its axis TURN for each watt while that end
## faces its body; the air drags on its turning, the drag growing with
## its size to the fifth power. The light on it is the table's (its
## watts a square metre, `CrystalTable.light_at`) at five points along its
## length, averaged, over the crystal's mean shadow, a quarter of its
## surface: partly in a bright spot, it takes that share of it. Unlit it
## is an inert stone.
##
## Its sounds come from what it does, quiet: a dull knock of stone on
## wood each time it strikes the table, the other crystal, or rolls on to
## a new facet (the engine reporting a new touch, or its speed jumping),
## louder the harder (crystal_tap_1..4.wav), or where it strikes the
## other crystal a glassy clink of stone on stone (crystal_clink_1..4.wav,
## chosen when one of its touches is the other crystal); while it spins
## fast on its
## point its small hops are not heard, only a blow harder than they are
## (SPIN_FAST, SPIN_BLOW); and while a point of it slides, a scrape on
## wood (crystal_scrape_loop.wav, cut by tools/cut_scrape.py from
## F.M.Audio's recording, CC BY 4.0), louder and a little quicker the
## faster the fastest touching point slides (its speed from the engine's
## touch points: the crystal's motion at each, along the surface), or
## while it spins fast on its point, the faster it travels over the
## table, and at the least as a slow drag (SPIN_GRIND) for its point
## grinding round. Both lower for a larger stone (`_pitch`).

const DENSITY := 2650.0                 # kg/m³
const WHOLE := 1.9                      # a whole stone's scale on the grown crystal, as in the gimbals
const DRAG := 1.4e-3                    # N m s²: the air's drag on a whole stone's turning
const SPIN_FAST := 10.0                 # rad/s: spinning on its point, its hops unheard
const SPIN_BLOW := 0.8                  # m/s: the blow that is heard then
const SPIN_GRIND := 0.08                # m/s: the least drag heard while it spins on its point

## "sun" or "earth".
var kind := "sun"
## Its length as a share of a whole stone's.
var size := CrystalTable.SMALLEST
## Where on the table it is set down (in the table's frame).
var home := Vector3.ZERO
## Its purity (Photogyrite): impure, as the stones found so far.
var purity := 0.0

var _table: CrystalTable
var _crystal: RigidBody3D
var _glow: StandardMaterial3D
var _rng := RandomNumberGenerator.new()
var _seed := 7
var _area := 0.0                        # m²: its mean shadow
var _half := 0.0                        # m: half its length
var _scale := 1.0
var _watts := 0.0
var _taps: Array[AudioStream] = []
var _clinks: Array[AudioStream] = []
var _stone_touches := 0                 # touches on it by the other crystal last step
var _tap: AudioStreamPlayer3D
var _drag: AudioStreamPlayer3D
var _slide := 0.0                       # m/s: the fastest touching point's sliding, eased
var _travel := Vector2.ZERO             # m/s: its middle's motion over the table, averaged
var _touching := 0                      # touches on it last step
var _was_v := Vector3.ZERO
var _was_w := Vector3.ZERO
var _since_tap := 1.0


func _init(table: CrystalTable, seed_value: int, at: Vector3) -> void:
	name = "TableCrystal"
	_table = table
	_seed = seed_value
	home = at
	_rng.randomize()


func _ready() -> void:
	_glow = StandardMaterial3D.new()
	_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_glow.roughness = 0.08
	_glow.metallic_specular = 0.9
	_glow.emission_enabled = true
	set_kind(kind)
	_tap = AudioStreamPlayer3D.new()
	_tap.unit_size = 3.0
	_tap.max_polyphony = 4
	add_child(_tap)
	_drag = AudioStreamPlayer3D.new()
	_drag.unit_size = 3.0
	_drag.volume_db = -80.0
	add_child(_drag)
	if DisplayServer.get_name() != "headless":
		for k in range(1, 5):
			_taps.append(load("res://audio/crystal_tap_%d.wav" % k))
			_clinks.append(load("res://audio/crystal_clink_%d.wav" % k))
		var drag_loop := load("res://audio/crystal_scrape_loop.wav") as AudioStreamWAV
		drag_loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		drag_loop.loop_begin = 0
		drag_loop.loop_end = int(drag_loop.get_length() * drag_loop.mix_rate)
		_drag.stream = drag_loop
		_drag.autoplay = true
		_drag.play()
	reset()


## Its tint for its kind.
func set_kind(k: String) -> void:
	kind = k
	if _glow == null:
		return
	_glow.albedo_color = Color(1.0, 0.72, 0.32, 0.9) if k == "sun" else Color(0.74, 0.62, 0.95, 0.9)
	_glow.emission = Color(0.75, 0.42, 0.1) if k == "sun" else Color(0.5, 0.36, 0.85)


## A new shape, set lying on the table.
func new_shape() -> void:
	_seed = _rng.randi()
	reset()


## Made again at `size`, of the current shape, set down lying at its
## place on the table, still.
func reset() -> void:
	if _crystal != null:
		_crystal.queue_free()
		_crystal = null
	if not visible:
		return
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
	_half = s.y * 0.5
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
	# Lying on its side at its place, a little above the table, turned at
	# random about the upright.
	_crystal.transform = Transform3D(Basis(Vector3.UP, _rng.randf() * TAU) * Basis(Vector3.BACK, PI * 0.5),
			home + Vector3(0, CrystalTable.TABLE_TOP + s.x * 0.5 + 0.02, 0))
	add_child(_crystal)


## On the table or taken off it.
func set_present(on: bool) -> void:
	visible = on
	reset()


## A line for the panel.
func report() -> String:
	if _crystal == null:
		return ""
	var axis := _crystal.global_basis.y.normalized()
	var off := rad_to_deg(acos(clampf(axis.dot(_toward()), -1.0, 1.0)))
	var spin := _crystal.angular_velocity.dot(axis) / TAU
	return "%s %d cm long, %.1f kg; %d W of light on it; its seeking end %d degrees off %s; spinning %.1f turns a second." % [
			"Sunstone" if kind == "sun" else "Earthstone", roundi(0.223 * _scale * 100.0), _crystal.mass, roundi(_watts), roundi(off),
			"the sun" if kind == "sun" else "straight up", absf(spin)]


func _toward() -> Vector3:
	return _table.to_sun if kind == "sun" else Vector3.UP


func _physics_process(delta: float) -> void:
	if _crystal == null:
		return
	var lit := 0.0
	for k in 5:
		lit += _table.light_at(_crystal.global_position + _crystal.global_basis.y.normalized() * _half * (k - 2) * 0.5)
	_watts = lit / 5.0 * _area
	var axis := _crystal.global_basis.y.normalized()
	var toward := _toward()
	var w := _crystal.angular_velocity
	var grown := pow(_scale / WHOLE, 5.0)
	var twist := axis.cross(toward) * Photogyrite.pull(_watts, purity) \
			+ axis * Photogyrite.spin(_watts, maxf(axis.dot(toward), 0.0), w.dot(axis), purity) \
			- w * w.length() * DRAG * grown
	_crystal.apply_torque(twist)
	_glow.emission_energy_multiplier = 0.1 + 0.8 * clampf(absf(w.dot(axis)) / 15.0, 0.0, 1.0)
	_sound(delta, axis)


## The knocks and the scrape, from its touches and turning.
func _sound(delta: float, axis: Vector3) -> void:
	_tap.global_position = _crystal.global_position
	var v := _crystal.linear_velocity
	var w := _crystal.angular_velocity
	var touching := _crystal.get_contact_count()
	# How hard it struck: the sudden change in the speed of its surface
	# (its middle's, and its turning's at its reach), less gravity's share.
	var reach := 0.07 * _scale
	var jolt := maxf((v - _was_v).length() - 9.8 * delta * 1.5, 0.0) + (w - _was_w).length() * reach * 0.5
	_since_tap += delta
	var spin := absf(w.dot(axis))
	# Which of its touches are the other crystal's.
	var state := PhysicsServer3D.body_get_direct_state(_crystal.get_rid())
	var stone_touches := 0
	if state != null:
		for k in state.get_contact_count():
			if state.get_contact_collider_object(k) is RigidBody3D:
				stone_touches += 1
	var heard := false
	if spin > SPIN_FAST:
		heard = jolt > SPIN_BLOW
	else:
		heard = jolt > 0.25 or (touching > _touching and v.length() + w.length() * reach > 0.15)
	# A new touch of the other crystal is heard as a clink however it spins.
	var new_stone := stone_touches > _stone_touches and v.length() + w.length() * reach > 0.1
	if touching > 0 and _since_tap > 0.03 and (heard or new_stone):
		_knock(maxf(jolt, (v.length() + w.length() * reach) * 0.5), stone_touches > 0)
	_touching = touching
	_stone_touches = stone_touches
	_was_v = v
	_was_w = w
	# The scrape: how fast the touching points slide along the surface;
	# while it spins fast on its point, how fast it travels over the
	# table, its point's grinding round in place heard as a slow drag.
	var slide := 0.0
	# (Its travel averaged over about a third of a second: its wobbling
	# about cancels out, its wandering stays.)
	_travel = _travel.lerp(Vector2(v.x, v.z), clampf(delta * 3.0, 0.0, 1.0))
	if spin >= SPIN_FAST:
		# Its point grinding round in place is heard as a slow drag at the
		# least, a little more the faster it spins.
		slide = maxf(_travel.length(), SPIN_GRIND + spin * 0.001) if touching > 0 else 0.0
	elif state != null:
		for k in state.get_contact_count():
			var at := state.get_contact_local_position(k) - state.transform.origin
			var moving := v + w.cross(at)
			var normal := state.get_contact_local_normal(k)
			slide = maxf(slide, (moving - normal * moving.dot(normal)).length())
	_slide = lerpf(_slide, slide, clampf(delta * 20.0, 0.0, 1.0))
	_drag.global_position = _crystal.global_position
	var drag := clampf(_slide / 0.8, 0.0, 1.0) if _table.scrape_heard else 0.0
	_drag.volume_db = linear_to_db(maxf(drag, 0.0001)) - 16.0 + 2.0 * log(_crystal.mass + 1.0) / log(10.0)
	_drag.pitch_scale = clampf(0.85 + _slide * 0.3, 0.85, 1.2) * _pitch()


## A knock on wood, or a clink where it struck the other crystal
## (`on_stone`).
func _knock(speed: float, on_stone: bool) -> void:
	if _taps.is_empty() or not _table.knocks_heard:
		return
	_since_tap = 0.0
	var set: Array[AudioStream] = _clinks if on_stone else _taps
	_tap.stream = set[_rng.randi() % set.size()]
	_tap.pitch_scale = _pitch() * _rng.randf_range(0.92, 1.08)
	_tap.volume_db = linear_to_db(clampf(speed / 1.2, 0.03, 1.0)) - 16.0 + 3.0 * log(_crystal.mass + 1.0) / log(10.0)
	_tap.play()


## Larger stones sound lower: the pitch as the smallest stone's size over
## this one's, to the power of the table's `pitch_drop` (0 the same for
## all, 1 in inverse proportion to its length, as a solid's ringing
## goes), the smallest's at one.
func _pitch() -> float:
	return clampf(pow(CrystalTable.SMALLEST / size, _table.pitch_drop), 0.1, 1.0)
