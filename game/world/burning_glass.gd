class_name BurningGlass
extends Node3D
## A burning glass set in a roof: a great lens of thick green glass in an
## oak frame in an opening in the slope, gathering the light sent down its
## barrel (by the heliostat's mirror) into a bright spot below, and under
## it a row of curtains on rails, each drawn across its strip of the lens
## by a cord.
##
## Built in its own frame: the lens's middle at the origin, y its axis out
## of the roof, x along the roof (the ridge's way), z across it.
##
## The light is worked out from the lens, not from the engine's sun: the
## frame and glass cast the sun's shadow, so the engine draws the room
## dark under it, and the spot is a spot light placed where the lens's
## light lands (`_physics_process`), its shape a picture of the lens's
## uncovered part (`light_projector`).
##
## The optics, thin lens: every ray through the lens bends toward its
## focus, FOCUS along the light's direction, so the light through it is a
## cone narrowing to the sun's image there and widening past it. At a
## distance s along the beam its cross-section is the lens's shape as the
## source sees it (foreshortened by the angle between them) scaled by
## k = 1 - s/FOCUS (turned over past the focus), blurred by the sun's own
## width (s times the sun's angle). All the power through it,
## light x CLEAR x the lens's area as the source sees it, falls on that
## cross-section, so its light there is that power over the cross-section's
## area (`irradiance`). A point in the cone is lit by one point of the
## lens, found by scaling back by k: where a curtain covers that point,
## the light does not reach it, so a strip covered darkens a strip of the
## spot.

const RADIUS := 0.6                     # m: the lens
const FOCUS := 5.5                      # m
const CLEAR := 0.65                     # the share of the light it passes: green glass 1 to 7 cm thick, its two faces' reflections
const SUN_HALF := 0.00465               # rad: the sun's half width
const OPENING := 1.3                    # m: the square opening in the roof
const CURTAINS := 4
const DRAW_SPEED := 0.5                 # m/s: a curtain drawn along its rail
const BACK := 0.6                       # m: the spot light short of where the light lands
const PICTURE := 32                     # texels across the spot light's picture of the lens

## Toward where its light comes from (the heliostat's mirror, or the
## sun) and that light, W/m², set by the world.
var source := Vector3.UP
var light := 0.0
## Whether the light reaches a point of the lens (global), 0 to 1: what
## lies between it and the source (Heliostat.reaches); all of it if unset.
var reaches: Callable
## Each curtain's place: 0 drawn back off the lens, 1 across its strip.
var drawn: Array[float] = []
var _target: Array[float] = []
var _cloth: Array[MeshInstance3D] = []
var _toggles: Array[Node3D] = []
var _spot: SpotLight3D
var _shaft: MeshInstance3D
var _shaft_mat: StandardMaterial3D
var _shaft_cone: CylinderMesh
var _picture: Image
var _pictures: Array[ImageTexture] = []
var _shown := 0
var _open_share := 1.0
var _moved := true                      # the curtains moved since the lens's open share was counted
var _paint_left := 0.0                  # s: till the spot's picture is painted again
var _mats: Dictionary
var _seeds: StandardMaterial3D
var _floor_y := 0.0                     # the room's floor, in this frame's parent, for the cords


## `floor_y`: the room's floor below, in the parent's frame; `mats`: "wood",
## "cloth" materials (the wood vertex coloured; the lens makes its own glass).
func _init(mats: Dictionary, floor_y: float, shut := true) -> void:
	name = "BurningGlass"
	_floor_y = floor_y
	for k in CURTAINS:
		drawn.append(1.0 if shut else 0.0)
		_target.append(1.0 if shut else 0.0)
	_mats = mats


func _ready() -> void:
	_build()


## The light, W/m², at `at` (global) from the lens.
func irradiance(at: Vector3) -> float:
	var n := global_basis.y.normalized()
	var facing := source.dot(n)
	if light <= 0.0 or facing < 0.05:
		return 0.0
	var d := -source
	var rel := at - global_position
	var s := rel.dot(d)
	if s < 0.05:
		return 0.0
	var k := 1.0 - s / FOCUS
	var blur := s * SUN_HALF
	var area := PI * RADIUS * RADIUS * facing
	var bright := light * CLEAR * area / (area * k * k + PI * blur * blur)
	return bright * _passed(rel - d * s, k, blur)


## How much of the light reaching the point `off` from the beam's middle
## (at a distance where the cone is scaled by k, blurred by `blur`) gets
## through: the lens point it comes from inside the lens and uncovered.
func _passed(off: Vector3, k: float, blur: float) -> float:
	if absf(k) < 0.01:
		# At the focus the whole lens lights the sun's image.
		return _open_share * (1.0 - smoothstep(blur * 0.8, blur * 1.2, off.length()))
	var d := -source
	var n := global_basis.y.normalized()
	var back := off / k
	# Along the beam to the lens's plane.
	var lens := back - d * (back.dot(n) / d.dot(n))
	var x := lens.dot(global_basis.x.normalized())
	var z := lens.dot(global_basis.z.normalized())
	var soft := maxf(blur / absf(k), 0.004)
	var through := (1.0 - smoothstep(RADIUS - soft, RADIUS + soft, Vector2(x, z).length())) * _uncovered(x, z, soft)
	if through > 0.0 and reaches.is_valid():
		through *= float(reaches.call(global_position + lens))
	return through


## Whether the lens point (x, z) in its own frame is clear of the
## curtains, softened over `soft`.
func _uncovered(x: float, z: float, soft: float) -> float:
	var strip := clampi(floori((x + OPENING * 0.5) / OPENING * CURTAINS), 0, CURTAINS - 1)
	# A curtain drawn right across covers its whole strip, softening and all.
	if drawn[strip] >= 1.0:
		return 0.0
	var edge := -OPENING * 0.5 + drawn[strip] * OPENING
	return smoothstep(edge - soft, edge + soft, z)


## Where the beam's middle meets the level plane at height `y` (global),
## or null when the sun is not on the lens.
func spot_at(y: float) -> Variant:
	if light <= 0.0 or source.dot(global_basis.y) < 0.05 or source.y < 0.02:
		return null
	var s := (global_position.y - y) / source.y
	return global_position - source * s


## Draws curtain `k` across its strip, or back.
func pull(k: int) -> void:
	_target[k] = 0.0 if _target[k] > 0.5 else 1.0


func _physics_process(delta: float) -> void:
	for k in CURTAINS:
		if drawn[k] != _target[k]:
			drawn[k] = move_toward(drawn[k], _target[k], DRAW_SPEED / OPENING * delta)
			_moved = true
			_place_curtain(k)
	_paint_left -= delta
	if _moved:
		_moved = false
		_paint_left = 0.0
		var open := 0.0
		var count := 0
		for i in 12:
			for j in 12:
				var x := (i + 0.5) / 12.0 * 2.0 - 1.0
				var z := (j + 0.5) / 12.0 * 2.0 - 1.0
				if x * x + z * z <= 1.0:
					open += _uncovered(x * RADIUS, z * RADIUS, 0.001)
					count += 1
		_open_share = open / count
	_aim_spot()
	_sunlit()


## The seeds' sparkle with the sun on the lens.
func _sunlit() -> void:
	var on := clampf(light * source.dot(global_basis.y.normalized()) / 900.0, 0.0, 1.0)
	_seeds.emission_energy_multiplier = 3.0 * on


## The spot light where the lens's light lands, sized and pictured to its
## cross-section there, and the faint shaft from the lens to it.
func _aim_spot() -> void:
	var n := global_basis.y.normalized()
	var facing := source.dot(n)
	if light <= 0.0 or facing < 0.05:
		_spot.visible = false
		_shaft.visible = false
		return
	var d := -source
	var from := global_position + d * 0.15
	var ray := PhysicsRayQueryParameters3D.create(from, from + d * 14.0, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if hit.is_empty():
		_spot.visible = false
		_shaft.visible = false
		return
	var landing: Vector3 = hit["position"]
	var s := (landing - global_position).dot(d)
	var k := 1.0 - s / FOCUS
	var blur := s * SUN_HALF
	var reach := RADIUS * absf(k) + blur * 1.3 + 0.01
	var mean := light * CLEAR * PI * RADIUS * RADIUS * facing / (PI * RADIUS * RADIUS * facing * k * k + PI * blur * blur) * _open_share
	_spot.visible = mean > 1.0
	_shaft.visible = _spot.visible
	if not _spot.visible:
		return
	var side := global_basis.x.normalized()
	side = (side - d * side.dot(d)).normalized()
	var frame := Basis(side, (-d).cross(side), -d)
	_spot.global_transform = Transform3D(frame, landing - d * BACK)
	_spot.spot_angle = rad_to_deg(atan(reach / BACK))
	_spot.spot_range = BACK * 2.0
	_spot.light_energy = clampf(2.2 * sqrt(mean / 1000.0), 0.0, 16.0)
	if _paint_left <= 0.0:
		_paint_left = 0.25
		_paint(frame, k, blur, reach)
	# The shaft: the cone from the lens to the landing, the dust in the
	# room's air lit faintly.
	var wide := RADIUS * absf(k) + blur
	if absf(_shaft_cone.bottom_radius - wide) > 0.01:
		_shaft_cone.bottom_radius = wide
	# Begun a little below the glass, so the lit air does not veil the
	# lens seen from the room.
	var start := minf(0.6, s * 0.5)
	_shaft_cone.top_radius = RADIUS * absf(1.0 - start / FOCUS)
	_shaft.global_transform = Transform3D(CozyMesh.aligned(-d).scaled_local(Vector3(1, s - start, 1)), global_position + d * (s + start) * 0.5)
	_shaft_mat.albedo_color.a = 0.03 * _open_share * clampf(light / 900.0, 0.0, 1.0)


## The spot light's picture: each texel the share of light the lens
## passes to that point of the cross-section.
func _paint(frame: Basis, k: float, blur: float, reach: float) -> void:
	for i in PICTURE:
		for j in PICTURE:
			var a := ((i + 0.5) / PICTURE * 2.0 - 1.0) * reach
			var b := (1.0 - (j + 0.5) / PICTURE * 2.0) * reach
			var off := frame.x * a + frame.y * b
			var v := _passed(off, k, blur) if Vector2(a, b).length() <= reach else 0.0
			_picture.set_pixel(i, j, Color(v, v, v))
	_picture.generate_mipmaps()
	# Two textures, the one not shown updated and then set on the light:
	# the engine's store of light pictures takes in a picture when it is
	# set on the light.
	_shown = 1 - _shown
	_pictures[_shown].update(_picture)
	_spot.light_projector = _pictures[_shown]


## ---- building ------------------------------------------------------------------

func _build() -> void:
	var wood: Material = _mats["wood"]
	var m := CozyMesh.new()
	var oak := Color(0.4, 0.29, 0.19)
	var half := OPENING * 0.5
	# The board round the lens: a square with a round hole, on the roof's
	# underside and outside alike, fanned from the lens's rim.
	var sides := 32
	for face: float in [1.0, -1.0]:
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var r0 := Vector3(cos(a0), 0, sin(a0))
			var r1 := Vector3(cos(a1), 0, sin(a1))
			var sq0 := r0 / maxf(absf(r0.x), absf(r0.z)) * half
			var sq1 := r1 / maxf(absf(r1.x), absf(r1.z)) * half
			var y := Vector3(0, face * 0.03, 0)
			m.quad(r0 * RADIUS + y, r1 * RADIUS + y, sq1 + y, sq0 + y, Vector3(0, face, 0), oak)
	m.torus(RADIUS - 0.02, RADIUS + 0.03, 32, 6, CozyMesh.at(Vector3.ZERO), oak.darkened(0.2))
	# The rails under the opening, a pair to each curtain, and a pulley at
	# each rail pair's lower end.
	var strip := OPENING / CURTAINS
	var under := -0.16
	for k in CURTAINS + 1:
		var x := -half + k * strip
		m.rod(Vector3(x, under, -half - 0.25), Vector3(x, under, half + 0.05), 0.012, 6, Color(0.3, 0.3, 0.3))
	for k in CURTAINS:
		var x := -half + (k + 0.5) * strip
		m.cyl(0.035, 0.035, 0.02, 10, CozyMesh.at(Vector3(x, under - 0.04, half + 0.05), Basis(Vector3.BACK, PI * 0.5)), oak.darkened(0.3))
	for k in [-1.0, 1.0]:
		m.box(Vector3(0.06, 0.12, OPENING + 0.35), CozyMesh.at(Vector3(k * (half + 0.03), under + 0.07, -0.1)), oak)
	var view := MeshInstance3D.new()
	view.mesh = m.commit(wood)
	add_child(view)
	# The lens: ground to its focus it is 7 cm thick in the middle (each
	# face a sphere of radius twice the focus times the glass's index less
	# one, 5.8 m, rising 3 cm over the rim), thick green glass shining at
	# its curved faces; deeper green round its edge, where a look crosses
	# more glass; held in a brass ring each side. Glass of the period is
	# strongly green with iron (a third of the light taken in this
	# thickness, as CLEAR) and full of small bubbles (seeds), which sparkle
	# with the sun on the lens (`_sunlit`). The engine's refraction is left
	# off: the sky behind is even, so it bent nothing visible, and it drew
	# the sky over the seeds.
	var lens := CozyMesh.new()
	lens.ball(RADIUS, 48, CozyMesh.at(Vector3.ZERO), Color.WHITE, false, 0.07)
	var glass := StandardMaterial3D.new()
	glass.albedo_color = Color(0.4, 0.66, 0.44, 0.94)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = 0.03
	glass.metallic_specular = 1.0
	glass.rim_enabled = true
	glass.rim = 0.7
	glass.rim_tint = 0.6
	var glass_view := MeshInstance3D.new()
	glass_view.mesh = lens.commit(glass)
	glass_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	add_child(glass_view)
	var edge := CozyMesh.new()
	edge.torus(RADIUS - 0.05, RADIUS + 0.005, 48, 8, CozyMesh.at(Vector3.ZERO), Color.WHITE)
	var edge_glass := glass.duplicate() as StandardMaterial3D
	edge_glass.albedo_color = Color(0.3, 0.55, 0.38, 0.75)
	var edge_view := MeshInstance3D.new()
	edge_view.mesh = edge.commit(edge_glass)
	add_child(edge_view)
	# The seeds, small bubbles through the glass.
	var seeds := CozyMesh.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = 1652
	for k in 90:
		var r := sqrt(rng.randf()) * (RADIUS - 0.04)
		var a := rng.randf() * TAU
		var thick := 0.035 * (1.0 - r * r / (RADIUS * RADIUS))
		seeds.ball(rng.randf_range(0.004, 0.01), 5, CozyMesh.at(Vector3(cos(a) * r, rng.randf_range(-thick, thick) * 0.8, sin(a) * r)), Color.WHITE)
	_seeds = StandardMaterial3D.new()
	_seeds.albedo_color = Color(0.9, 0.95, 0.9, 0.5)
	_seeds.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_seeds.emission_enabled = true
	_seeds.emission = Color(1.0, 0.97, 0.88)
	_seeds.emission_energy_multiplier = 0.0
	var seed_view := MeshInstance3D.new()
	seed_view.mesh = seeds.commit(_seeds)
	seed_view.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(seed_view)
	var ring := CozyMesh.new()
	for face: float in [1.0, -1.0]:
		ring.torus(RADIUS - 0.035, RADIUS + 0.02, 48, 6, CozyMesh.at(Vector3(0, face * 0.035, 0)), Color(0.78, 0.6, 0.3))
		for k in 8:
			var a := TAU * k / 8.0
			ring.ball(0.012, 6, CozyMesh.at(Vector3(cos(a) * (RADIUS + 0.0), face * 0.045, sin(a) * RADIUS)), Color(0.7, 0.54, 0.28))
	var ring_view := MeshInstance3D.new()
	ring_view.mesh = ring.commit(wood)
	add_child(ring_view)
	# The curtains, each a heavy cloth gathered at the top of its strip
	# and drawn down the rails, a batten along its lower edge; its cord
	# from the batten round the pulley and down into the room, a toggle on
	# it.
	var down := global_basis.inverse() * Vector3.DOWN
	var floor_at := (get_parent() as Node3D).to_global(Vector3(0, _floor_y, 0)).y
	for k in CURTAINS:
		var cloth := MeshInstance3D.new()
		var body := BoxMesh.new()
		body.size = Vector3.ONE
		body.material = _mats["cloth"]
		cloth.mesh = body
		add_child(cloth)
		_cloth.append(cloth)
		var x := -half + (k + 0.5) * strip
		var pulley := Vector3(x, under - 0.04, half + 0.05)
		var cord_low := to_local(Vector3(to_global(pulley).x, floor_at + 0.9, to_global(pulley).z))
		var cord := CozyMesh.new()
		cord.rod(pulley + Vector3(0.03, 0, 0), cord_low + Vector3(0.03, 0, 0), 0.006, 5, Color(0.72, 0.62, 0.44))
		cord.rod(pulley - Vector3(0.03, 0, 0), cord_low - Vector3(0.03, 0, 0), 0.006, 5, Color(0.72, 0.62, 0.44))
		cord.cyl(0.015, 0.015, 0.06, 8, CozyMesh.at(cord_low + Vector3(0, -0.02, 0)), Color(0.72, 0.62, 0.44))
		var cord_view := MeshInstance3D.new()
		cord_view.mesh = cord.commit(wood)
		add_child(cord_view)
		var toggle := CurtainCord.new(self, k, down, wood)
		toggle.position = pulley + Vector3(0.03, 0, 0)
		# Met by the player's crosshair, not walked into, and out of the
		# beam's way.
		toggle.collision_layer = 4
		add_child(toggle)
		toggle.hang(pulley.distance_to(cord_low))
		_toggles.append(toggle)
		_place_curtain(k)
	# The spot light and its picture.
	# With its mipmaps: the engine's store of light pictures reads them.
	_picture = Image.create(PICTURE, PICTURE, true, Image.FORMAT_RGB8)
	for k in 2:
		_pictures.append(ImageTexture.create_from_image(_picture))
	_spot = SpotLight3D.new()
	_spot.light_color = Color(1.0, 0.96, 0.86)
	_spot.spot_attenuation = 0.0
	_spot.shadow_enabled = true
	_spot.light_projector = _pictures[0]
	_spot.visible = false
	add_child(_spot)
	_shaft_mat = StandardMaterial3D.new()
	_shaft_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_shaft_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_shaft_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	_shaft_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shaft_mat.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_shaft_mat.albedo_color = Color(1.0, 0.92, 0.75, 0.0)
	_shaft_cone = CylinderMesh.new()
	_shaft_cone.top_radius = RADIUS
	_shaft_cone.bottom_radius = 0.1
	_shaft_cone.height = 1.0
	_shaft_cone.radial_segments = 24
	_shaft_cone.cap_top = false
	_shaft_cone.cap_bottom = false
	_shaft_cone.material = _shaft_mat
	_shaft = MeshInstance3D.new()
	_shaft.mesh = _shaft_cone
	_shaft.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shaft.top_level = true
	_shaft.visible = false
	add_child(_shaft)


## Curtain `k` and its toggle where it is drawn to.
func _place_curtain(k: int) -> void:
	var half := OPENING * 0.5
	var strip := OPENING / CURTAINS
	var x := -half + (k + 0.5) * strip
	var length := maxf(drawn[k] * OPENING, 0.06)
	# Gathered, the cloth bunches thicker.
	var thick := lerpf(0.09, 0.02, clampf(drawn[k] * 3.0, 0.0, 1.0))
	_cloth[k].transform = Transform3D(Basis.IDENTITY.scaled(Vector3(strip - 0.02, thick, length)),
			Vector3(x, -0.12 - thick * 0.5, -half + length * 0.5 - 0.06 * (1.0 - drawn[k])))
	if k < _toggles.size():
		(_toggles[k] as CurtainCord).set_drawn(drawn[k])
