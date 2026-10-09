class_name OpticBench
extends Node3D
## The exposition's proving ground for aimed beams, on the sand between
## the boardwalk and the sea: parts the player aims themselves.
##
## An aimed part's beam leaves its lens straight ahead and runs until it
## strikes something, at most REACH metres, fading toward its end. Landing
## on an intake ring of another aimed part it carries the signal in;
## striking anything else it is lost there. A mirror turns it (a tenth of
## its reach lost), a splitter sends half its reach on and half aside, a
## lens doubles what reach it has left; every crystal sends its own beam
## out at full reach, so a crystal is a relay. Dark beams are drawn as
## faint guide lines, so the player can see where everything points; lit
## ones glow in their colour. A beam is stopped by the player's body too.
##
## Aiming: look at a part, hold E and move the mouse (the player's view
## stays still meanwhile, `Player.look_held_by`). A beam that comes within
## SNAP metres of an intake, or of the middle of a mirror, splitter or
## lens, settles onto it with a click; a firm push frees it again. Aims
## are kept in SAVE_PATH.
##
## The line: a lantern at the north end, relay crystals about 22 m apart
## along the shore, a radiometer and bell at the far end, 85 m on. After
## the second relay a splitter can feed a mirror that turns the branch
## back along the water's edge into an AND crystal, whose second way in
## takes a beam from a second lantern; it rings a second bell. The
## splitter halves the line's reach, so the lens just past it is needed
## to reach the third relay; a lens bends no beam, so those four stand on
## one straight line and the second relay must be aimed down it. Every
## part starts aimed at nothing.

const REACH := 25.0
const SNAP := 0.35
const SAVE_PATH := "user://cozy_island_optics.json"
const HEIGHT := 1.15
const MAX_BOUNCES := 10

var expo: CrystalExpo
var island: CozyIsland
var parts: Array[LumenPart] = []
var elements: Array[OpticElement] = []
var _clocks: Array = []                  # [lantern, period, on, phase]
var _bells: Array = []                   # [radiometer, was spinning, speaker]
var _segments: Array = []                # [from, to, reach at from, reach at to, colour, lit]
var _arrivals := {}                      # element -> [point, incoming direction], this step
var _held: Node3D = null
var _snapped := false
var _snap_drag := 0.0
var _broken_from := Vector3.INF
var _mesh := ImmediateMesh.new()
var _beam_mat: StandardMaterial3D
var _click: AudioStreamPlayer3D
var _clock := 0.0


func _init(owner_expo: CrystalExpo) -> void:
	name = "OpticBench"
	expo = owner_expo
	island = owner_expo.island


func _ready() -> void:
	var wood: Material = expo.get("_wood")
	var brass: Material = expo.get("_brass")
	var copper: Material = expo.get("_copper")
	var silver: Material = expo.get("_silver")
	var glass: Material = expo.get("_glass")
	var lamp1 := _part("North lantern", LumenPart.Kind.LANTERN, _at(184.5, 4.5), {"lamp": "drum", "metal": copper})
	_clocks.append([lamp1, 8.0, 5.5, 0.0])
	var relay := {"design": "orb", "setting": "cage", "metal": silver, "colour": Color(0.6, 0.9, 1.0), "intake_metal": copper}
	_part("First relay", LumenPart.Kind.OR, _at(193.5, 4.5), relay)
	var second := _at(202.5, 4.5)
	_part("Second relay", LumenPart.Kind.OR, second, relay)
	# A lens bends no beam: the second relay, the splitter, the lens and
	# the third relay stand on one straight line.
	var line := _at(212.0, 4.5) - second
	line.y = 0.0
	line = line.normalized()
	_element("Splitter", OpticElement.Kind.SPLITTER, _on_line(second, line, 5.8), wood, copper, silver, glass)
	_element("Lens", OpticElement.Kind.LENS, _on_line(second, line, 10.6), wood, brass, silver, glass)
	_part("Third relay", LumenPart.Kind.OR, _on_line(second, line, 19.0), relay)
	var far := _part("Far radiometer", LumenPart.Kind.RADIOMETER, _at(219.5, 4.5), {"metal": brass, "intake_metal": copper})
	# The branch: the mirror 3.3 m seaward of the splitter, the gate 5 m on
	# from it along the water's edge, the shore lantern 1.8 m inland of
	# the gate, the shore radiometer 2.6 m past it.
	var sea := _seaward(205.0)
	var mirror_at := _on_line(second, line, 5.8) + sea * 3.3
	_element("Mirror", OpticElement.Kind.MIRROR, mirror_at, wood, brass, silver, glass)
	var gate_at := _on_line(mirror_at, line, 5.0)
	_part("Gate", LumenPart.Kind.AND, gate_at, {"design": "gem", "setting": "prongs", "metal": brass,
			"intake_metal": copper, "second_metal": silver})
	var lamp2 := _part("Shore lantern", LumenPart.Kind.LANTERN, _on_line(gate_at - sea * 1.8, line, 0.0), {"lamp": "drum", "metal": brass})
	_clocks.append([lamp2, 5.0, 3.5, 1.0])
	var near := _part("Shore radiometer", LumenPart.Kind.RADIOMETER, _on_line(gate_at, line, 2.6), {"metal": brass, "intake_metal": copper})
	for r: LumenPart in [far, near]:
		var bell := AudioStreamPlayer3D.new()
		bell.stream = load("res://audio/chime.wav") if DisplayServer.get_name() != "headless" else null
		bell.unit_size = 8.0
		r.add_child(bell)
		_bells.append([r, false, bell])
	_click = AudioStreamPlayer3D.new()
	_click.stream = load("res://audio/ratchet.wav") if DisplayServer.get_name() != "headless" else null
	_click.unit_size = 3.0
	_click.top_level = true
	add_child(_click)
	_beam_mat = StandardMaterial3D.new()
	_beam_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_beam_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_beam_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_beam_mat.vertex_color_use_as_albedo = true
	_beam_mat.albedo_color = Color(2.5, 2.5, 2.5)
	_beam_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_beam_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var view := MeshInstance3D.new()
	view.name = "Beams"
	view.mesh = _mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 16384.0
	add_child(view)
	# Every part starts aimed at nothing in particular, or as the player
	# left it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1666
	for a: Node3D in _aimables():
		a.call("aim", rng.randf_range(-PI, PI), rng.randf_range(-0.15, 0.15))
	if not MouseMode.probe:
		_load()


## `along` metres from `from` along the flat direction `line`, at the
## bench's height over the sand there.
func _on_line(from: Vector3, line: Vector3, along: float) -> Vector3:
	var p := from + line * along
	p.y = island.height(p.x, p.z) + HEIGHT
	return p


## Toward the sea at `bearing` (degrees), flat.
func _seaward(bearing: float) -> Vector3:
	var a := deg_to_rad(bearing)
	return Vector3(cos(a), 0.0, sin(a))


## A point `inland` metres up from the shore at `bearing` (degrees), at
## the bench's height over the sand.
func _at(bearing: float, inland: float) -> Vector3:
	var a := deg_to_rad(bearing)
	var p := Vector3(cos(a), 0.0, sin(a)) * (island.coast(a, 0.0) - inland)
	p.y = island.height(p.x, p.z) + HEIGHT
	return p


func _part(title: String, kind: LumenPart.Kind, at: Vector3, look: Dictionary) -> LumenPart:
	var l := look.duplicate()
	l["aimed"] = true
	var p := LumenPart.new(kind, title, at, at.y - HEIGHT, expo.get("_wood"), expo.get("_brass"), 0.0, l)
	p.name = title.replace(" ", "")
	add_child(p)
	parts.append(p)
	return p


func _element(title: String, kind: OpticElement.Kind, at: Vector3, wood: Material, frame: Material,
		silver: Material, glass: Material) -> OpticElement:
	var e := OpticElement.new(kind, at, at.y - HEIGHT, wood, frame, silver, glass)
	e.name = title.replace(" ", "")
	add_child(e)
	elements.append(e)
	return e


func _aimables() -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p in parts:
		out.append(p)
	for e in elements:
		out.append(e)
	return out


## ---- the light ------------------------------------------------------------

func _physics_process(dt: float) -> void:
	_clock += dt
	for p in parts:
		for it in p.intakes:
			it.delivered = it.pending
			it.pending = false
	for c: Array in _clocks:
		(c[0] as LumenPart).condition = fmod(_clock + float(c[3]), float(c[1])) < float(c[2])
	for p in parts:
		p.evaluate(dt)
	_segments.clear()
	_arrivals.clear()
	for p in parts:
		if p.kind != LumenPart.Kind.RADIOMETER:
			var skip: Array[RID] = [p.get_rid()]
			_trace(p.lens_point(), p.forward(), REACH, skip, p.out, p.colour(), 0)
	for b: Array in _bells:
		var r := b[0] as LumenPart
		var on := r.powered
		if on and not bool(b[1]):
			BeachSite._play(b[2] as AudioStreamPlayer3D, 1.0)
		b[1] = on
	if _held != null and not _snapped:
		_try_snap()


## A beam from `origin` along `dir` with `reach` metres left: straight on
## until it strikes something, turned by mirrors, split by splitters,
## focused by lenses, delivered to an intake when lit.
func _trace(origin: Vector3, dir: Vector3, reach: float, exclude: Array[RID], lit: bool, colour: Color, depth: int) -> void:
	var space := get_world_3d().direct_space_state
	var skip := exclude
	while depth < MAX_BOUNCES and reach > 0.05:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
		q.exclude = skip
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			_segments.append([origin, origin + dir * reach, reach, 0.0, colour, lit])
			return
		var p: Vector3 = hit["position"]
		var d := origin.distance_to(p)
		_segments.append([origin, p, reach, reach - d, colour, lit])
		reach -= d
		var c: Object = hit["collider"]
		if c is LumenPart and (c as LumenPart).aimed:
			var it := (c as LumenPart).intake_for(dir)
			if it != null and lit:
				it.pending = true
			return
		if not (c is OpticElement):
			return
		var e := c as OpticElement
		var n := e.normal()
		if not _arrivals.has(e):
			_arrivals[e] = [p, dir]
		match e.kind:
			OpticElement.Kind.MIRROR:
				if dir.dot(n) >= 0.0:
					return
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				reach *= 0.9
			OpticElement.Kind.SPLITTER:
				var through: Array[RID] = [e.get_rid()]
				_trace(p, dir, reach * 0.5, through, lit, colour, depth + 1)
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				reach *= 0.5
			OpticElement.Kind.LENS:
				if absf(dir.dot(n)) < 0.5:
					return
				reach = minf(reach * 2.0, REACH * 2.0)
		origin = p
		skip = [e.get_rid()]
		depth += 1


## ---- aiming -----------------------------------------------------------------

func _process(_delta: float) -> void:
	var player := island.player
	if Input.is_action_pressed("interact"):
		if _held == null and player.look_held_by == null:
			var v := player.look_view()
			if v != null and (parts.has(v) or elements.has(v)):
				_held = v
				_snapped = false
				player.look_held_by = self
	elif _held != null:
		_held = null
		player.look_held_by = null
		_save()
	_draw_beams()


## Mouse movement while a part is held: it turns, unless it has just
## settled onto something and the push is not yet firm enough.
func turn_by(motion: Vector2) -> void:
	if _held == null:
		return
	if _snapped:
		_snap_drag += motion.length()
		if _snap_drag < 45.0:
			return
		_snapped = false
	_held.call("turn_by", motion)


## The held part's beam (or, for a mirror or splitter, the beam it turns)
## passing close by an intake or another piece of glass settles onto it.
func _try_snap() -> void:
	var origin: Vector3
	var out_dir: Vector3
	var incoming := Vector3.ZERO
	if _held is LumenPart:
		var p := _held as LumenPart
		if p.kind == LumenPart.Kind.RADIOMETER:
			return
		origin = p.lens_point()
		out_dir = p.forward()
	elif _held is OpticElement and (_held as OpticElement).kind != OpticElement.Kind.LENS and _arrivals.has(_held):
		var e := _held as OpticElement
		var arrival: Array = _arrivals[e]
		origin = arrival[0]
		incoming = arrival[1]
		var n := e.normal()
		out_dir = (incoming - 2.0 * incoming.dot(n) * n).normalized()
	else:
		return
	var best := Vector3.INF
	var best_perp := SNAP
	for target in _targets(origin):
		var to := target - origin
		var t := to.dot(out_dir)
		if t < 0.3 or t > REACH * 2.0:
			continue
		var perp := (origin + out_dir * t).distance_to(target)
		if perp < best_perp:
			best_perp = perp
			best = target
	if _broken_from != Vector3.INF:
		var away := INF
		var t2 := (_broken_from - origin).dot(out_dir)
		if t2 > 0.0:
			away = (origin + out_dir * t2).distance_to(_broken_from)
		if away > SNAP * 1.5:
			_broken_from = Vector3.INF
	if best == Vector3.INF or best.is_equal_approx(_broken_from):
		return
	var want := (best - origin).normalized()
	if _held is LumenPart:
		# The lens swings with the head: aimed again from where it now is
		# until it holds still.
		var p := _held as LumenPart
		for k in 4:
			p.aim_along(best - p.lens_point())
	else:
		# The face set halfway between the way the beam comes and the way
		# it should leave.
		(_held as OpticElement).aim_along((want - incoming).normalized())
	_snapped = true
	_snap_drag = 0.0
	_broken_from = best
	_click.global_position = _held.global_position
	BeachSite._play(_click, 1.6)


## What a beam from `origin` can be settled onto: every intake it could
## come in through from there, and the middle of every piece of glass,
## but the held one's own.
func _targets(origin: Vector3) -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in parts:
		if p == _held:
			continue
		for it in p.intakes:
			var point := p.intake_point(it)
			if p.intake_for((point - origin).normalized()) == it:
				out.append(point)
	for e in elements:
		if e != _held:
			out.append(e.global_position)
	return out


## Every beam as a flat ribbon turned to the eye: lit ones bright in their
## colour, dark ones a faint guide; each dimming over its last 6 m.
func _draw_beams() -> void:
	_mesh.clear_surfaces()
	if _segments.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var eye := cam.global_position
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _beam_mat)
	for s: Array in _segments:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		if a.distance_squared_to(b) < 0.0001:
			continue
		var lit: bool = s[5]
		var colour: Color = s[4]
		var tint := colour if lit else colour.lerp(Color.WHITE, 0.6) * 0.18
		var width := 0.028 if lit else 0.01
		var side := (b - a).cross(eye - a).normalized() * width
		var ca := tint * smoothstep(0.0, 6.0, float(s[2]))
		var cb := tint * smoothstep(0.0, 6.0, float(s[3]))
		for v: Array in [[a - side, ca], [a + side, ca], [b + side, cb], [a - side, ca], [b + side, cb], [b - side, cb]]:
			_mesh.surface_set_color(v[1])
			_mesh.surface_add_vertex(v[0])
	_mesh.surface_end()


## ---- keeping the aims -----------------------------------------------------

func _save() -> void:
	if MouseMode.probe:
		return
	var data := {}
	for a in _aimables():
		data[String(a.name)] = [float(a.get("yaw")), float(a.get("pitch"))]
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(data))


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if not parsed is Dictionary:
		return
	for a in _aimables():
		var v: Variant = (parsed as Dictionary).get(String(a.name))
		if v is Array and (v as Array).size() >= 2:
			a.call("aim", float(v[0]), float(v[1]))
