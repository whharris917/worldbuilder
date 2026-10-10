class_name OpticBench
extends Node3D
## The exposition's proving ground for aimed beams, on the sand between
## the boardwalk and the sea: parts the player aims themselves.
##
## An aimed part's beam leaves its lens straight ahead and runs until it
## strikes something, at most REACH metres, fading toward its end. A beam
## striking an aimed part, from any side, is read by it (every beam that
## strikes it, lit or dark: an AND shines while all of them are lit; a
## latch is set by beams from its left, reset by beams from its right);
## striking anything else it is lost there. A mirror turns it (a tenth of
## its reach lost), a splitter sends half its reach on and half aside, a
## lens doubles what reach it has left; every crystal sends its own beam
## out at full reach, so a crystal is a relay. Dark beams are drawn as
## faint guide lines; lit ones glow in their colour. A beam is stopped by
## the player's body too.
##
## Aiming: a right click on a part looks through it, in a scope: from a crystal's or
## lantern's lens along its beam; from a mirror or splitter along the beam
## it turns, so steering the view turns the glass to send the beam there;
## from a lens along its axis. The mouse aims (finer as the view zooms),
## the wheel zooms, a glowing spot marks where the beam strikes; a right
## click again, E or Esc looks out through the player's own eyes. The player stands
## still meanwhile (`Player.look_held_by`). A beam passing within SNAP
## metres of the middle of a part or a glass settles there with a click;
## a firm push frees it. Aims are kept in SAVE_PATH.
##
## The line: a lantern at the north end, relay crystals about 22 m apart
## along the shore, a radiometer and bell at the far end, 85 m on. After
## the second relay a splitter can feed a mirror that turns the branch
## back along the water's edge into an AND crystal, which also takes a
## second lantern's beam; it rings a second bell. The splitter halves the
## line's reach, so the lens just past it is needed to reach the third
## relay; a lens bends no beam, so those four stand on one straight line
## and the second relay must be aimed down it. Every part starts aimed at
## nothing.

const REACH := 25.0
const SNAP := 0.35
const SAVE_PATH := "user://cozy_island_optics.json"
const HEIGHT := 1.15
const MAX_BOUNCES := 10
const FOV_START := 30.0

var _right_was := false                # the right button held last frame
var expo: CrystalExpo
var island: CozyIsland
var parts: Array[LumenPart] = []
var elements: Array[OpticElement] = []
var _clocks: Array = []                  # [lantern, period, on, phase]
var _bells: Array = []                   # [radiometer, was spinning, speaker]
var _segments: Array = []                # [from, to, reach at from, reach at to, colour, lit]
var _landed := {}                        # aimed part -> Array of OpticArrival, this step
var _arrivals := {}                      # glass -> [point, incoming direction], first beam this step
var _held: Node3D = null
var _marker := Vector3.INF               # where the held part's beam strikes
var _snapped := false
var _snap_drag := 0.0
var _broken_from := Vector3.INF
var _fov := FOV_START
var _scope: Camera3D
var _overlay: CanvasLayer
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
	var relay := {"design": "orb", "setting": "cage", "metal": silver, "colour": Color(0.6, 0.9, 1.0)}
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
	var far := _part("Far radiometer", LumenPart.Kind.RADIOMETER, _at(219.5, 4.5), {"metal": brass})
	# The branch: the mirror 3.3 m seaward of the splitter, the gate 5 m on
	# from it along the water's edge, the shore lantern 1.8 m inland of
	# the gate, the shore radiometer 2.6 m past it.
	var sea := _seaward(205.0)
	var mirror_at := _on_line(second, line, 5.8) + sea * 3.3
	_element("Mirror", OpticElement.Kind.MIRROR, mirror_at, wood, brass, silver, glass)
	var gate_at := _on_line(mirror_at, line, 5.0)
	_part("Gate", LumenPart.Kind.AND, gate_at, {"design": "gem", "setting": "prongs", "metal": brass})
	var lamp2 := _part("Shore lantern", LumenPart.Kind.LANTERN, _on_line(gate_at - sea * 1.8, line, 0.0), {"lamp": "drum", "metal": brass})
	_clocks.append([lamp2, 5.0, 3.5, 1.0])
	var near := _part("Shore radiometer", LumenPart.Kind.RADIOMETER, _on_line(gate_at, line, 2.6), {"metal": brass})
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
	_build_scope()
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
	# Seen and aimed by the player's look (layer 4) and struck by beams,
	# but no solid to walk into: a part turned against the player cannot
	# trap them.
	p.collision_layer = 4
	add_child(p)
	parts.append(p)
	return p


func _element(title: String, kind: OpticElement.Kind, at: Vector3, wood: Material, frame: Material,
		silver: Material, glass: Material) -> OpticElement:
	var e := OpticElement.new(kind, at, at.y - HEIGHT, wood, frame, silver, glass)
	e.name = title.replace(" ", "")
	e.collision_layer = 4
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
	# What struck each part last step is what it reads now.
	for p in parts:
		var hits: Array = _landed.get(p, [])
		p.inputs.clear()
		if p.kind == LumenPart.Kind.LATCH:
			var set_on := false
			var reset_on := false
			for h: OpticArrival in hits:
				if h.from_left:
					set_on = set_on or h.delivered
				else:
					reset_on = reset_on or h.delivered
			p.inputs.append(OpticArrival.new(set_on, true))
			p.inputs.append(OpticArrival.new(reset_on, false))
		else:
			p.inputs.append_array(hits)
	_landed.clear()
	for c: Array in _clocks:
		(c[0] as LumenPart).condition = fmod(_clock + float(c[3]), float(c[1])) < float(c[2])
	for p in parts:
		p.evaluate(dt)
	_segments.clear()
	_arrivals.clear()
	_marker = Vector3.INF
	for p in parts:
		if p.kind != LumenPart.Kind.RADIOMETER:
			var skip: Array[RID] = [p.get_rid()]
			_trace(p.lens_point(), p.forward(), REACH, skip, p.out, p.colour(), 0, p == _held)
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
## focused by lenses, read by the aimed part it strikes. `mark` records
## where it next strikes (the held part's own beam, or the beam a held
## glass sends on).
func _trace(origin: Vector3, dir: Vector3, reach: float, exclude: Array[RID], lit: bool, colour: Color,
		depth: int, mark: bool) -> void:
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
		if mark:
			_marker = p
			mark = false
		reach -= d
		var c: Object = hit["collider"]
		if c is LumenPart and (c as LumenPart).aimed:
			var part := c as LumenPart
			var right := part.global_transform.basis * (Basis.from_euler(Vector3(part.pitch, part.yaw, 0.0)) * Vector3.RIGHT)
			if not _landed.has(part):
				_landed[part] = []
			(_landed[part] as Array).append(OpticArrival.new(lit, dir.dot(right) > 0.0))
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
				_trace(p, dir, reach * 0.5, through, lit, colour, depth + 1, false)
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				reach *= 0.5
			OpticElement.Kind.LENS:
				if absf(dir.dot(n)) < 0.5:
					return
				reach = minf(reach * 2.0, REACH * 2.0)
		if e == _held:
			mark = true
		origin = p
		skip = [e.get_rid()]
		depth += 1


## ---- the scope ----------------------------------------------------------------

func _build_scope() -> void:
	_scope = Camera3D.new()
	_scope.near = 0.03
	_scope.top_level = true
	add_child(_scope)
	_overlay = CanvasLayer.new()
	_overlay.layer = 20
	_overlay.visible = false
	add_child(_overlay)
	var frame := TextureRect.new()
	frame.texture = scope_picture()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	frame.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.add_child(frame)
	var hint := Label.new()
	hint.text = "Right click: done"
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.95, 0.9, 0.78))
	hint.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hint.position.y -= 46.0
	hint.grow_horizontal = Control.GROW_DIRECTION_BOTH
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_overlay.add_child(hint)


## The scope's frame: dark brass round a clear circle, a fine reticle.
static func scope_picture() -> ImageTexture:
	var w := 1280
	var h := 720
	var img := Image.create(w, h, false, Image.FORMAT_RGBA8)
	var r_view := h * 0.44
	for y in h:
		for x in w:
			var dx := x - w * 0.5
			var dy := y - h * 0.5
			var r := sqrt(dx * dx + dy * dy)
			var c := Color(0, 0, 0, 0)
			if r > r_view:
				var rim := clampf((r - r_view) / 14.0, 0.0, 1.0)
				c = Color(0.14, 0.1, 0.06, 1.0).lerp(Color(0.04, 0.035, 0.03, 1.0), rim)
				c.a = smoothstep(r_view - 1.0, r_view + 2.0, r)
			elif r > r_view - 5.0:
				c = Color(0.6, 0.45, 0.2, 0.9)
			else:
				var line := (absf(dx) < 0.8 or absf(dy) < 0.8) and r > 16.0 and r < r_view - 30.0
				var ring := absf(r - 9.0) < 0.9
				if line or ring:
					c = Color(0.05, 0.04, 0.03, 0.7)
				else:
					# A faint darkening toward the edge of the glass.
					c = Color(0, 0, 0, 0.35 * smoothstep(r_view * 0.6, r_view, r))
			img.set_pixel(x, y, c)
	return ImageTexture.create_from_image(img)


func _process(_delta: float) -> void:
	var player := island.player
	var right := Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	var pressed := right and not _right_was
	_right_was = right
	if pressed or (_held != null and Input.is_action_just_pressed("interact")):
		if _held == null:
			var v := player.look_view()
			if v != null and player.look_held_by == null and (parts.has(v) or elements.has(v)) \
					and not (v is LumenPart and (v as LumenPart).kind == LumenPart.Kind.RADIOMETER):
				_enter(v)
		else:
			_leave()
	elif _held != null and Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		_leave()
	if _held != null:
		_place_scope()
	_draw_beams()


func _enter(v: Node3D) -> void:
	_held = v
	island.player.look_held_by = self
	_fov = FOV_START
	_snapped = false
	_broken_from = Vector3.INF
	_scope.current = true
	_overlay.visible = true


func _leave() -> void:
	_held = null
	island.player.look_held_by = null
	island.player.camera.current = true
	_overlay.visible = false
	_save()


## Which way the held part sends its beam: a crystal or lantern along its
## lens; a mirror or splitter the beam reaching it turned off its face (or
## its face's direction when none reaches it); a lens along its axis.
func _sending_dir() -> Vector3:
	if _held is OpticElement:
		var e := _held as OpticElement
		var n := e.normal()
		if e.kind != OpticElement.Kind.LENS and _arrivals.has(e):
			var incoming: Vector3 = (_arrivals[e] as Array)[1]
			return (incoming - 2.0 * incoming.dot(n) * n).normalized()
		return n
	return (_held as LumenPart).forward()


## The scope's eye: at the lens looking along the beam; for a mirror or
## splitter where the beam strikes it, looking along the beam it sends.
func _place_scope() -> void:
	var dir := _sending_dir()
	var from: Vector3
	if _held is LumenPart:
		from = (_held as LumenPart).lens_point()
	else:
		var e := _held as OpticElement
		if e.kind != OpticElement.Kind.LENS and _arrivals.has(e):
			from = (_arrivals[e] as Array)[0]
		else:
			from = e.global_position + dir * 0.06
	from += dir * 0.04
	var up := Vector3.UP if absf(dir.y) < 0.98 else Vector3.FORWARD
	_scope.global_transform = Transform3D(Basis.looking_at(dir, up), from)
	_scope.fov = _fov


## The mouse while looking through the scope: the view (and with it the
## part, or a glass's face) turns, the finer the narrower the view; held
## where it has settled until the push is firm.
func turn_by(motion: Vector2) -> void:
	if _held == null:
		return
	if _snapped:
		_snap_drag += motion.length()
		if _snap_drag < 45.0:
			return
		_snapped = false
	var fine := motion * (_fov / 60.0)
	if _held is LumenPart:
		(_held as LumenPart).turn_by(fine)
		return
	var e := _held as OpticElement
	if e.kind != OpticElement.Kind.LENS and _arrivals.has(e):
		# Steer the sent beam; the face sits halfway between it and the
		# beam coming in.
		var d := _sending_dir()
		var yaw := atan2(-d.x, -d.z) - fine.x * 0.004
		var pitch := clampf(asin(clampf(d.y, -1.0, 1.0)) - fine.y * 0.004, -1.2, 1.2)
		var out := Basis.from_euler(Vector3(pitch, yaw, 0.0)) * Vector3.FORWARD
		var incoming: Vector3 = (_arrivals[e] as Array)[1]
		e.aim_along((out - incoming).normalized())
	else:
		e.turn_by(fine)


func zoom_by(step: int) -> void:
	_fov = clampf(_fov * (0.8 if step > 0 else 1.25), 1.5, 60.0)


## The beam passing close by the middle of a part or a glass settles
## there.
func _try_snap() -> void:
	var origin: Vector3
	var out_dir: Vector3
	var incoming := Vector3.ZERO
	if _held is LumenPart:
		var p := _held as LumenPart
		origin = p.lens_point()
		out_dir = p.forward()
	elif (_held as OpticElement).kind != OpticElement.Kind.LENS and _arrivals.has(_held):
		var arrival: Array = _arrivals[_held]
		origin = arrival[0]
		incoming = arrival[1]
		out_dir = _sending_dir()
	else:
		return
	var best := Vector3.INF
	var best_perp := SNAP
	for target in _targets():
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
	if _held is LumenPart:
		# The lens swings with the head: aimed again from where it now is
		# until it holds still.
		var p := _held as LumenPart
		for k in 4:
			p.aim_along(best - p.lens_point())
	else:
		(_held as OpticElement).aim_along(((best - origin).normalized() - incoming).normalized())
	_snapped = true
	_snap_drag = 0.0
	_broken_from = best
	_click.global_position = _held.global_position
	BeachSite._play(_click, 1.6)


## The middle of every other part and glass.
func _targets() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for p in parts:
		if p != _held:
			out.append(p.global_position)
	for e in elements:
		if e != _held:
			out.append(e.global_position)
	return out


## Every beam as a flat ribbon turned to the eye: lit ones bright in their
## colour, dark ones a faint guide; each dimming over its last 6 m. While
## a part is aimed, a glowing spot where its beam strikes.
func _draw_beams() -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or (_segments.is_empty() and _marker == Vector3.INF):
		return
	var eye := cam.global_position
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _beam_mat)
	for s: Array in _segments:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		if a.distance_squared_to(b) < 0.0001:
			continue
		var cross := (b - a).cross(eye - a)
		if cross.length_squared() < 1e-8:
			continue
		var lit: bool = s[5]
		var colour: Color = s[4]
		var tint := colour if lit else colour.lerp(Color.WHITE, 0.6) * 0.18
		var side := cross.normalized() * (0.028 if lit else 0.01)
		var ca := tint * smoothstep(0.0, 6.0, float(s[2]))
		var cb := tint * smoothstep(0.0, 6.0, float(s[3]))
		for v: Array in [[a - side, ca], [a + side, ca], [b + side, cb], [a - side, ca], [b + side, cb], [b - side, cb]]:
			_mesh.surface_set_color(v[1])
			_mesh.surface_add_vertex(v[0])
	if _held != null and _marker != Vector3.INF:
		# A spot a fixed share of the scope's view across, so it shows at
		# any zoom and distance.
		var size := eye.distance_to(_marker) * tan(deg_to_rad(_fov * 0.5)) * 0.025
		var right := cam.global_transform.basis.x * size
		var up := cam.global_transform.basis.y * size
		var glow := Color(1.0, 0.95, 0.75)
		for q: Array in [[right, up], [up, -right]]:
			var r: Vector3 = q[0]
			var u: Vector3 = q[1]
			var corners := [_marker - r * 0.25 - u, _marker + r * 0.25 - u, _marker + r * 0.25 + u, _marker - r * 0.25 + u]
			for k: int in [0, 1, 2, 0, 2, 3]:
				_mesh.surface_set_color(glow)
				_mesh.surface_add_vertex(corners[k])
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
