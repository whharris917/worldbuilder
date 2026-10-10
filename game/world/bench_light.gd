class_name BenchLight
extends Node3D
## The light of the pieces the player builds (Workshop). Every piece that sends a beam
## sends it from its lens straight ahead, traced through the world each
## physics step as the beam range traces its own (OpticBench): turned by
## a mirror's face (a tenth of its reach lost; a mirror's back stops it),
## sent on and aside by a splitter (half its reach each), given twice its
## remaining reach by a lens it passes along the axis of, read by the
## built part it strikes, lost on anything else. A beam reaches REACH
## metres at most. The player's body stops no beam, so building never
## breaks a circuit by standing in it.
##
## Light here travels slowly, at SPEED, as along the works' fixed beams:
## a point s metres along a beam shows what the part sending it showed
## s / SPEED seconds before, so a signal is seen to run along a beam and
## a loop of beams takes time to go round. Each sending part's output is
## kept as a list of its changes for HISTORY seconds.
##
## A light gate (LightGate) passes a beam through its ring while open and
## stops it while shut; a beam striking its sensor is read by it, and
## each step it opens or shuts at once on whether any lit beam struck it.
##
## Beams are of three kinds, by the meta "beam" of the part sending them:
## light (gold, the signal), push (red) and pull (green). Glass and gates
## treat all three alike; only light is read by parts and gates' bulbs.
## A push or pull beam striking a cart's handle (BeamCart) drives the
## cart along its track, away from the beam's source or toward it, by as
## much of the beam as runs along the track, while lit.
##
## What a part reads: every beam striking it, lit or dark, for an AND, an
## OR and a radiometer; for a latch, any lit beam striking it from its
## left sets it and any from its right resets it; the other kinds read
## one beam, lit if any beam striking them is.
##
## Sunlight (`sun_rules`, the test island's): no light comes from
## nowhere. Its only source is a sun collector, a lantern-bodied piece
## with meta "collector": a mirror reflecting the sun into a lens tube.
## Its beam carries power: the direct sunlight (`sunlight`, watts a
## square metre, set by the world from the sun's height) on the mirror's
## area (MIRROR_D across), less COLLECT, while its shutter is open,
## nothing while its mirror is in shadow (a ray toward the sun meets
## anything). The mirror is set for the sun as it stood when the
## collector was last aimed (meta "sun_set"); as the sun moves on, the
## gathered light slides off the tube, falling to nothing ACCEPT radians
## off.
##
## The beam stays a narrow, focused line (no spreading, unlike real
## sunlight: a choice for play) and fades with the distance it has run:
## its power falls by e every FADE metres, halving about every 5.5 m. A
## piece in its path catches all of it: a crystal, a gate's bulb or a
## radiometer responds while what reaches it is THRESHOLD watts or more.
## A gate's ring passes it whole; a mirror loses a tenth; a splitter
## sends half each way; past a lens the beam fades half as fast. Crystals
## and every other part only read light; none sends any. A beam is traced
## until it carries too little to matter.
##
## Drawn as flat ribbons turned to the eye, only where lit, in one warm
## gold (BEAM) laid over what is behind (not added to it, which turns a
## beam white against a bright sky); each fades over the last 6 m of its
## reach. The piece being aimed shows its path faintly
## while dark, so its landing can be seen.

const SPEED := 12.0
const REACH := 25.0
const MAX_BOUNCES := 10
const HISTORY := 30.0
const BEAM := Color(1.0, 0.72, 0.22)
const PUSH := Color(1.0, 0.24, 0.18)
const PULL := Color(0.3, 0.95, 0.4)
const MIRROR_D := 0.6                   # a collector's mirror, m across
const COLLECT := 0.8                    # the share of the light the mirror and lenses pass
const ACCEPT := 0.052                   # 3 degrees: the sun this far off its setting and the tube gets nothing
const THRESHOLD := 3.0                  # watts reaching a piece for it to respond
const FADE := 8.0                       # metres over which a beam's power falls by e

var parts: Array[LumenPart] = []
var elements: Array[OpticElement] = []
var gates: Array[LightGate] = []
var carts: Array[BeamCart] = []
## The first beam reaching each glass this step: glass -> [point, direction].
var arrivals := {}
## A piece whose beam's landing is wanted (the one being aimed), and
## where its beam (or for a glass, the beam it sends on) first strikes.
var held: Node3D = null
var struck := Vector3.INF
## A glowing spot drawn this frame, `spot_size` metres across.
var spot := Vector3.INF
var spot_size := 0.05
## Sunlight: on for the test island. Toward the sun, and the direct
## sunlight there, W/m² (0 with the sun down).
var sun_rules := false
var sun := Vector3.UP
var sunlight := 0.0

var _clock := 0.0
var _history := {}                      # part -> Array of [time, out]
var _landed := {}                       # part -> Array of OpticArrival, this step
var _forces := {}                       # cart -> the push and pull on its handle, this step
var _segments: Array = []               # [a, b, s at a, s at b, reach at a, source, held's]
var _mesh := ImmediateMesh.new()
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.albedo_color = Color.WHITE
	_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var view := MeshInstance3D.new()
	view.name = "Beams"
	view.mesh = _mesh
	view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	view.extra_cull_margin = 16384.0
	add_child(view)


func add(piece: Node3D) -> void:
	if piece is LumenPart:
		parts.append(piece as LumenPart)
	elif piece is OpticElement:
		elements.append(piece as OpticElement)
	elif piece is LightGate:
		gates.append(piece as LightGate)
	elif piece is BeamCart:
		carts.append(piece as BeamCart)


func remove(piece: Node3D) -> void:
	if piece is LumenPart:
		parts.erase(piece)
	elif piece is OpticElement:
		elements.erase(piece)
	elif piece is LightGate:
		gates.erase(piece)
	elif piece is BeamCart:
		carts.erase(piece)
		_forces.erase(piece)
	_history.erase(piece)
	_landed.erase(piece)
	arrivals.erase(piece)
	if held == piece:
		held = null


## One step: every part reads what struck it last step and works out its
## output, then every beam is traced again.
func step(dt: float) -> void:
	_clock += dt
	for p in parts:
		var hits: Array = _landed.get(p, [])
		p.inputs.clear()
		match p.kind:
			LumenPart.Kind.AND, LumenPart.Kind.OR, LumenPart.Kind.RADIOMETER:
				p.inputs.append_array(hits)
			LumenPart.Kind.LATCH:
				var set_on := false
				var reset_on := false
				for h: OpticArrival in hits:
					if h.from_left:
						set_on = set_on or h.delivered
					else:
						reset_on = reset_on or h.delivered
				p.inputs.append(OpticArrival.new(set_on, true))
				p.inputs.append(OpticArrival.new(reset_on, false))
			_:
				if not hits.is_empty():
					var any := false
					for h: OpticArrival in hits:
						any = any or h.delivered
					p.inputs.append(OpticArrival.new(any, false))
	for g in gates:
		var on := false
		for h: OpticArrival in _landed.get(g, []):
			on = on or h.delivered
		g.sense(on)
	_landed.clear()
	for cart in carts:
		cart.drive(float(_forces.get(cart, 0.0)), dt)
	_forces.clear()
	for p in parts:
		p.evaluate(dt)
		if sun_rules:
			_record_power(p, collector_power(p))
		else:
			_record(p)
	_segments.clear()
	arrivals.clear()
	struck = Vector3.INF
	if sun_rules:
		for p in parts:
			if p.has_meta("collector"):
				var skip: Array[RID] = [p.get_rid()]
				_trace_sun(p, p.lens_point(), p.forward(), 1.0, 0.0, 1.0 / FADE, 0.0, skip, 0, p == held)
		return
	for p in parts:
		if p.kind != LumenPart.Kind.RADIOMETER:
			var skip: Array[RID] = [p.get_rid()]
			_trace(p, p.lens_point(), p.forward(), REACH, skip, 0.0, 0, p == held)


func _record(p: LumenPart) -> void:
	if not _history.has(p):
		_history[p] = []
	var h: Array = _history[p]
	if h.is_empty() or bool(h[-1][1]) != p.out:
		h.append([_clock, p.out])
	while h.size() > 1 and float(h[1][0]) < _clock - HISTORY:
		h.remove_at(0)


## What `p` showed at time `t`: dark before anything is known of it.
func _shown(p: LumenPart, t: float) -> bool:
	var h: Array = _history.get(p, [])
	for i in range(h.size() - 1, -1, -1):
		if float(h[i][0]) <= t:
			return bool(h[i][1])
	return false


## ---- sunlight ----------------------------------------------------------------

## A collector's power now, watts: the sunlight on its mirror while its
## shutter is open, the mirror is in the sun and still near enough its
## setting; 0 for anything else.
func collector_power(p: LumenPart) -> float:
	if not p.has_meta("collector") or not p.condition or sunlight <= 0.0:
		return 0.0
	var setting: Vector3 = p.get_meta("sun_set", sun)
	var align := clampf(1.0 - setting.angle_to(sun) / ACCEPT, 0.0, 1.0)
	if align <= 0.0:
		return 0.0
	var mirror: Vector3 = p.get_meta("mirror_at", p.global_position)
	var q := PhysicsRayQueryParameters3D.create(mirror + sun * 0.4, mirror + sun * 400.0, 1 | 4)
	q.exclude = [p.get_rid()]
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return 0.0
	return sunlight * PI * MIRROR_D * MIRROR_D * 0.25 * COLLECT * align


func _record_power(p: LumenPart, power: float) -> void:
	if not _history.has(p):
		_history[p] = []
	var h: Array = _history[p]
	if h.is_empty() or absf(float(h[-1][1]) - power) > maxf(0.5, 0.02 * power):
		h.append([_clock, power])
	while h.size() > 1 and float(h[1][0]) < _clock - HISTORY:
		h.remove_at(0)


## What a collector sent at time `t`, watts.
func power_at(p: LumenPart, t: float) -> float:
	var h: Array = _history.get(p, [])
	for i in range(h.size() - 1, -1, -1):
		if float(h[i][0]) <= t:
			return float(h[i][1])
	return 0.0


## A collector's beam from `origin` along `dir`, `s` metres along it so
## far: `gain` the share of its power the glass has left it, `faded` how
## far it has faded already (the exponent), `rate` how fast it fades
## from here, per metre. Straight on until it strikes something.
func _trace_sun(source: LumenPart, origin: Vector3, dir: Vector3, gain: float, faded: float, rate: float,
		s: float, exclude: Array[RID], depth: int, mark: bool) -> void:
	var hot := mark
	var space := get_world_3d().direct_space_state
	var skip := exclude
	var strongest := 0.0
	for e: Array in _history.get(source, []):
		strongest = maxf(strongest, float(e[1]))
	while depth < MAX_BOUNCES:
		# As far as it still carries a third of what anything needs.
		var reach := 0.0
		if strongest * gain > THRESHOLD * 0.3:
			reach = clampf((log(strongest * gain / (THRESHOLD * 0.3)) - faded) / rate, 0.0, 200.0)
		elif hot:
			# A dark beam is traced only to show where a held piece would send it.
			reach = 25.0
		if reach <= 0.05:
			return
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
		q.collision_mask = 0xFFFFFFFF & ~Workshop.ROD_LAYER
		var ex: Array[RID] = skip.duplicate()
		ex.append_array(_player())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			_segments.append([origin, origin + dir * reach, s, s + reach, gain, faded, rate, source, hot])
			return
		var p: Vector3 = hit["position"]
		var d := origin.distance_to(p)
		_segments.append([origin, p, s, s + d, gain, faded, rate, source, hot])
		if mark:
			struck = p
			mark = false
		s += d
		faded += rate * d
		var power := power_at(source, _clock - s / SPEED) * gain * exp(-faded)
		var c: Object = hit["collider"]
		if c is LumenPart and parts.has(c):
			var part := c as LumenPart
			var right := part.global_transform.basis * (Basis.from_euler(Vector3(part.pitch, part.yaw, 0.0)) * Vector3.RIGHT)
			if not _landed.has(part):
				_landed[part] = []
			(_landed[part] as Array).append(OpticArrival.new(power >= THRESHOLD, dir.dot(right) > 0.0))
			return
		if c is LightGate and gates.has(c):
			# Through the ring while the gate is open.
			if not (c as LightGate).open:
				return
			origin = p
			skip = [(c as LightGate).get_rid()]
			depth += 1
			continue
		if c is StaticBody3D and (c as Node).has_meta("part_of"):
			var gate: Object = (c as Node).get_meta("part_of")
			if gates.has(gate):
				if not _landed.has(gate):
					_landed[gate] = []
				(_landed[gate] as Array).append(OpticArrival.new(power >= THRESHOLD, false))
			return
		if not (c is OpticElement and elements.has(c)):
			return
		var e := c as OpticElement
		var n := e.normal()
		if not arrivals.has(e):
			arrivals[e] = [p, dir]
		match e.kind:
			OpticElement.Kind.MIRROR:
				if dir.dot(n) >= 0.0:
					return
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				gain *= 0.9
			OpticElement.Kind.SPLITTER:
				var through: Array[RID] = [e.get_rid()]
				_trace_sun(source, p, dir, gain * 0.5, faded, rate, s, through, depth + 1, e == held)
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				gain *= 0.5
			OpticElement.Kind.LENS:
				if absf(dir.dot(n)) < 0.5:
					return
				gain *= 0.95
				rate *= 0.5
		if e == held:
			mark = true
			hot = true
		origin = p
		skip = [e.get_rid()]
		depth += 1


## The sunlit beams drawn: thin ribbons, as bright as their light is
## strong, fading out as it falls below what anything can read.
func _draw_sun(eye: Vector3, points: PackedVector3Array, colours: PackedColorArray) -> void:
	for seg: Array in _segments:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var s0: float = seg[2]
		var s1: float = seg[3]
		var gain: float = seg[4]
		var faded: float = seg[5]
		var rate: float = seg[6]
		var source := seg[7] as LumenPart
		var hot: bool = seg[8]
		if s1 - s0 < 0.01 or not is_instance_valid(source):
			continue
		var pieces := ceili((s1 - s0) / 1.5)
		for k in pieces:
			var f0 := float(k) / pieces
			var f1 := float(k + 1) / pieces
			var pa := a.lerp(b, f0)
			var pb := a.lerp(b, f1)
			var cross := (pb - pa).cross(eye - pa)
			if cross.length_squared() < 1e-8:
				continue
			var side := cross.normalized() * 0.022
			var alphas: Array[float] = []
			for f: float in [f0, f1]:
				var d := (s1 - s0) * f
				var power := power_at(source, _clock - (s0 + d) / SPEED) * gain * exp(-(faded + rate * d))
				var alpha := clampf(0.35 + 0.6 * power / 150.0, 0.0, 0.95) * smoothstep(THRESHOLD * 0.3, THRESHOLD, power)
				if hot:
					alpha = maxf(alpha, 0.3)
				alphas.append(alpha)
			if alphas[0] <= 0.0 and alphas[1] <= 0.0:
				continue
			var ca := Color(BEAM, alphas[0])
			var cb := Color(BEAM, alphas[1])
			points.append_array([pa - side, pa + side, pb + side, pa - side, pb + side, pb - side])
			colours.append_array([ca, ca, cb, ca, cb, cb])


## The player's body, for the beams to pass through.
func _player() -> Array[RID]:
	var shop := get_parent() as Workshop
	if shop == null or shop.island == null or shop.island.player == null:
		return []
	return [shop.island.player.get_rid()]


func _trace(source: LumenPart, origin: Vector3, dir: Vector3, reach: float, exclude: Array[RID], s: float,
		depth: int, mark: bool) -> void:
	var hot := mark
	var space := get_world_3d().direct_space_state
	var skip := exclude
	while depth < MAX_BOUNCES and reach > 0.05:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
		# Everything stops a beam but the pieces' rods, which are solid only
		# to the crosshair.
		q.collision_mask = 0xFFFFFFFF & ~Workshop.ROD_LAYER
		var ex: Array[RID] = skip.duplicate()
		ex.append_array(_player())
		q.exclude = ex
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			_segments.append([origin, origin + dir * reach, s, s + reach, reach, source, hot])
			return
		var p: Vector3 = hit["position"]
		var d := origin.distance_to(p)
		_segments.append([origin, p, s, s + d, reach, source, hot])
		if mark:
			struck = p
			mark = false
		reach -= d
		s += d
		var c: Object = hit["collider"]
		var kind: String = source.get_meta("beam", "light")
		if c is LumenPart and parts.has(c):
			if kind != "light":
				return
			var part := c as LumenPart
			var right := part.global_transform.basis * (Basis.from_euler(Vector3(part.pitch, part.yaw, 0.0)) * Vector3.RIGHT)
			if not _landed.has(part):
				_landed[part] = []
			(_landed[part] as Array).append(OpticArrival.new(_shown(source, _clock - s / SPEED), dir.dot(right) > 0.0))
			return
		if c is LightGate and gates.has(c):
			# Through the ring while the gate is open.
			if not (c as LightGate).open:
				return
			origin = p
			skip = [(c as LightGate).get_rid()]
			depth += 1
			continue
		if c is StaticBody3D and (c as Node).has_meta("part_of"):
			var owner_part: Object = (c as Node).get_meta("part_of")
			if owner_part is BeamCart and carts.has(owner_part):
				if kind != "light" and _shown(source, _clock - s / SPEED):
					var along := dir.dot((owner_part as BeamCart).axis())
					_forces[owner_part] = float(_forces.get(owner_part, 0.0)) + (along if kind == "push" else -along)
				return
			var gate: Object = owner_part
			if kind == "light" and gates.has(gate):
				if not _landed.has(gate):
					_landed[gate] = []
				(_landed[gate] as Array).append(OpticArrival.new(_shown(source, _clock - s / SPEED), false))
			return
		if not (c is OpticElement and elements.has(c)):
			return
		var e := c as OpticElement
		var n := e.normal()
		if not arrivals.has(e):
			arrivals[e] = [p, dir]
		match e.kind:
			OpticElement.Kind.MIRROR:
				if dir.dot(n) >= 0.0:
					return
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				reach *= 0.9
			OpticElement.Kind.SPLITTER:
				var through: Array[RID] = [e.get_rid()]
				_trace(source, p, dir, reach * 0.5, through, s, depth + 1, e == held)
				dir = (dir - 2.0 * dir.dot(n) * n).normalized()
				reach *= 0.5
			OpticElement.Kind.LENS:
				if absf(dir.dot(n)) < 0.5:
					return
				reach = minf(reach * 2.0, REACH * 2.0)
		if e == held:
			mark = true
			hot = true
		origin = p
		skip = [e.get_rid()]
		depth += 1


## The stretches of a beam of `source` from s0 to s1 metres along it, as
## [from, to, lit]: the point s shows the source as it was s / SPEED
## seconds ago.
func _spans(source: LumenPart, s0: float, s1: float) -> Array:
	var h: Array = _history.get(source, [])
	var t0 := _clock - s0 / SPEED
	var i := h.size() - 1
	while i >= 0 and float(h[i][0]) > t0:
		i -= 1
	var lit := bool(h[i][1]) if i >= 0 else false
	var out: Array = []
	var start := s0
	while i >= 0:
		var change := (_clock - float(h[i][0])) * SPEED
		if change >= s1:
			break
		if change > start:
			out.append([start, change, lit])
			start = change
		i -= 1
		lit = bool(h[i][1]) if i >= 0 else false
	out.append([start, s1, lit])
	return out


func _process(_delta: float) -> void:
	_mesh.clear_surfaces()
	var cam := get_viewport().get_camera_3d()
	if cam == null or (_segments.is_empty() and spot == Vector3.INF):
		return
	var eye := cam.global_position
	var points := PackedVector3Array()
	var colours := PackedColorArray()
	if sun_rules:
		_draw_sun(eye, points, colours)
	for seg: Array in ([] if sun_rules else _segments):
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var s0: float = seg[2]
		var s1: float = seg[3]
		if s1 - s0 < 0.01:
			continue
		var source := seg[5] as LumenPart
		if not is_instance_valid(source):
			continue
		for span: Array in _spans(source, s0, s1):
			var u0: float = span[0]
			var u1: float = span[1]
			var lit: bool = span[2]
			var pa := a.lerp(b, (u0 - s0) / (s1 - s0))
			var pb := a.lerp(b, (u1 - s0) / (s1 - s0))
			var hot: bool = seg[6]
			if not lit and not hot:
				continue
			var cross := (pb - pa).cross(eye - pa)
			if cross.length_squared() < 1e-8:
				continue
			var opacity := 0.95 if lit else 0.3
			var side := cross.normalized() * (0.022 if lit else 0.01)
			var hue: Color = {"push": PUSH, "pull": PULL}.get(source.get_meta("beam", "light"), BEAM)
			var ca := Color(hue, opacity * smoothstep(0.0, 6.0, float(seg[4]) - (u0 - s0)))
			var cb := Color(hue, opacity * smoothstep(0.0, 6.0, float(seg[4]) - (u1 - s0)))
			points.append_array([pa - side, pa + side, pb + side, pa - side, pb + side, pb - side])
			colours.append_array([ca, ca, cb, ca, cb, cb])
	if spot != Vector3.INF:
		var right := cam.global_transform.basis.x * spot_size
		var up := cam.global_transform.basis.y * spot_size
		var glow := Color(1.0, 0.95, 0.75)
		for q: Array in [[right, up], [up, -right]]:
			var r: Vector3 = q[0]
			var u: Vector3 = q[1]
			var corners := [spot - r * 0.25 - u, spot + r * 0.25 - u, spot + r * 0.25 + u, spot - r * 0.25 + u]
			for k: int in [0, 1, 2, 0, 2, 3]:
				points.append(corners[k])
				colours.append(glow)
	if points.is_empty():
		return
	_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLES, _mat)
	for k in points.size():
		_mesh.surface_set_color(colours[k])
		_mesh.surface_add_vertex(points[k])
	_mesh.surface_end()
