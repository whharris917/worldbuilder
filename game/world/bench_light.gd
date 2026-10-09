class_name BenchLight
extends Node3D
## The light of the pieces the player builds (Workshop). Every piece that sends a beam
## sends it from its lens straight ahead, traced through the world each
## physics step as the beam range traces its own (OpticBench): turned by
## a mirror's face (a tenth of its reach lost; a mirror's back stops it),
## sent on and aside by a splitter (half its reach each), given twice its
## remaining reach by a lens it passes along the axis of, read by the
## built part it strikes, lost on anything else. A beam reaches REACH
## metres at most.
##
## Light here travels slowly, at SPEED, as along the works' fixed beams:
## a point s metres along a beam shows what the part sending it showed
## s / SPEED seconds before, so a signal is seen to run along a beam and
## a loop of beams takes time to go round. Each sending part's output is
## kept as a list of its changes for HISTORY seconds.
##
## What a part reads: every beam striking it, lit or dark, for an AND, an
## OR and a radiometer; for a latch, any lit beam striking it from its
## left sets it and any from its right resets it; the other kinds read
## one beam, lit if any beam striking them is.
##
## Drawn as flat ribbons turned to the eye: lit stretches bright in the
## sender's colour, dark ones a faint guide line (plainer for the piece
## being aimed), each dimming over the last 6 m of its reach.

const SPEED := 12.0
const REACH := 25.0
const MAX_BOUNCES := 10
const HISTORY := 30.0

var parts: Array[LumenPart] = []
var elements: Array[OpticElement] = []
## The first beam reaching each glass this step: glass -> [point, direction].
var arrivals := {}
## A piece whose beam's landing is wanted (the one being aimed), and
## where its beam (or for a glass, the beam it sends on) first strikes.
var held: Node3D = null
var struck := Vector3.INF
## A glowing spot drawn this frame, `spot_size` metres across.
var spot := Vector3.INF
var spot_size := 0.05

var _clock := 0.0
var _history := {}                      # part -> Array of [time, out]
var _landed := {}                       # part -> Array of OpticArrival, this step
var _segments: Array = []               # [a, b, s at a, s at b, reach at a, source, held's]
var _mesh := ImmediateMesh.new()
var _mat: StandardMaterial3D


func _ready() -> void:
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_mat.vertex_color_use_as_albedo = true
	_mat.albedo_color = Color(2.5, 2.5, 2.5)
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


func remove(piece: Node3D) -> void:
	if piece is LumenPart:
		parts.erase(piece)
	elif piece is OpticElement:
		elements.erase(piece)
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
	_landed.clear()
	for p in parts:
		p.evaluate(dt)
		_record(p)
	_segments.clear()
	arrivals.clear()
	struck = Vector3.INF
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


## The beam of `source` from `origin` along `dir`, `s` metres from the
## lens so far, with `reach` metres left.
func _trace(source: LumenPart, origin: Vector3, dir: Vector3, reach: float, exclude: Array[RID], s: float,
		depth: int, mark: bool) -> void:
	var hot := mark
	var space := get_world_3d().direct_space_state
	var skip := exclude
	while depth < MAX_BOUNCES and reach > 0.05:
		var q := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach)
		q.exclude = skip
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
		if c is LumenPart and parts.has(c):
			var part := c as LumenPart
			var right := part.global_transform.basis * (Basis.from_euler(Vector3(part.pitch, part.yaw, 0.0)) * Vector3.RIGHT)
			if not _landed.has(part):
				_landed[part] = []
			(_landed[part] as Array).append(OpticArrival.new(_shown(source, _clock - s / SPEED), dir.dot(right) > 0.0))
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
	for seg: Array in _segments:
		var a: Vector3 = seg[0]
		var b: Vector3 = seg[1]
		var s0: float = seg[2]
		var s1: float = seg[3]
		if s1 - s0 < 0.01:
			continue
		var source := seg[5] as LumenPart
		if not is_instance_valid(source):
			continue
		var colour := source.colour()
		for span: Array in _spans(source, s0, s1):
			var u0: float = span[0]
			var u1: float = span[1]
			var lit: bool = span[2]
			var pa := a.lerp(b, (u0 - s0) / (s1 - s0))
			var pb := a.lerp(b, (u1 - s0) / (s1 - s0))
			var cross := (pb - pa).cross(eye - pa)
			if cross.length_squared() < 1e-8:
				continue
			var hot: bool = seg[6]
			var tint := colour if lit else colour.lerp(Color.WHITE, 0.6) * (0.5 if hot else 0.18)
			var side := cross.normalized() * (0.024 if lit else (0.014 if hot else 0.008))
			var ca := tint * smoothstep(0.0, 6.0, float(seg[4]) - (u0 - s0))
			var cb := tint * smoothstep(0.0, 6.0, float(seg[4]) - (u1 - s0))
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
