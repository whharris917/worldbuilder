class_name TidePool
extends Node3D
## A raised tidepool at the lagoon wharf: a round stone basin of seawater
## standing on the lagoon's floor, home to one kind of creature. Fed with
## broth, the creatures thrive and make something that collects in a
## glass cup on the rim; unfed, they fade and stop.
##
## The model (per second): broth fed raises `nutrients`; the creatures eat
## it at a steady rate; their vigour follows how much there is; at full
## vigour they make a cupful (`product` 1) in one to two and a half
## minutes, by kind (APPETITE, PACE). The works reads
## `hungry` and `ripe` (each with a margin, so a lantern does not flicker)
## and empties the cup with `take`.
##
## The creatures are engine primitives moved by this script: anemones
## pulsing with light, pearl oysters opening, urchins turning, ribbon kelp
## swaying, starfish crawling, moon jellies pulsing as they bob. The pool's
## water is clear when hungry and richer coloured when fed.

enum Species { ANEMONE, OYSTER, URCHIN, KELP, STAR, JELLY }

const RADIUS := 2.2
const FLOOR := 0.02                     # above the basin's own floor
const WATER := 0.6                      # the water's depth in the basin
const NAMES := ["glow anemones", "pearl oysters", "sea urchins", "ribbon kelp", "starfish", "moon jellies"]
const PRODUCTS := ["glimmer", "pearls", "spine-chalk", "sea-silk", "star-salt", "jelly-light"]
# Each kind's appetite (broth eaten a second) and pace (cupfuls made a
# second at full vigour): kelp is hungry and quick, oysters slow.
const APPETITE := [0.011, 0.007, 0.009, 0.014, 0.008, 0.012]
const PACE := [0.013, 0.007, 0.010, 0.017, 0.009, 0.012]
const COLOURS := [Color(0.3, 1.0, 0.95), Color(0.95, 0.93, 0.88), Color(0.72, 0.4, 1.0),
		Color(1.0, 0.82, 0.3), Color(1.0, 0.5, 0.22), Color(1.0, 0.45, 0.8)]

var species: Species
var nutrients := 0.6
var product := 0.0
var vigour := 0.0
var hungry := false
var ripe := false
var base := 0.0                         # the basin floor's height (the pool's local y 0)
var night := 0.0                        # set by the works: 0 by day to 1 at night

var _clock := 0.0
var _phase := 0.0
var _creatures: Array[Node3D] = []
var _glows: Array[StandardMaterial3D] = []
var _water_mat: StandardMaterial3D
var _cup_fill: MeshInstance3D
var _cup_mat: StandardMaterial3D
var _sparkles: GPUParticles3D
var _urchin_spikes: MultiMeshInstance3D
var _glow_light: OmniLight3D
var _rng := RandomNumberGenerator.new()


## A pool of `kind` with its floor at `floor_y` above the lagoon floor
## `seabed` (its walls reach down to it), facing its cup toward `cup_dir`
## (local, flat). `stone` is the rim's, `glass` the cup's.
func _init(kind: Species, floor_y: float, seabed: float, stone: Material, glass: Material, cup_dir: Vector3) -> void:
	species = kind
	name = "TidePool"
	base = floor_y
	_rng.seed = 400 + kind
	_phase = kind * 1.7
	var wall_h := floor_y + WATER + 0.15 - seabed
	var wall := CylinderMesh.new()
	wall.top_radius = RADIUS + 0.25
	wall.bottom_radius = RADIUS + 0.4
	wall.height = wall_h
	wall.cap_top = false
	wall.radial_segments = 28
	wall.material = stone
	_mesh(wall, Vector3(0, seabed + wall_h * 0.5 - floor_y, 0), self)
	var lip := TorusMesh.new()
	lip.inner_radius = RADIUS
	lip.outer_radius = RADIUS + 0.35
	lip.rings = 28
	lip.material = stone
	var lip_view := _mesh(lip, Vector3(0, WATER + 0.15, 0), self)
	lip_view.scale = Vector3(1, 0.6, 1)
	var bottom := CylinderMesh.new()
	bottom.top_radius = RADIUS + 0.2
	bottom.bottom_radius = RADIUS + 0.2
	bottom.height = 0.05
	bottom.radial_segments = 28
	var sand := StandardMaterial3D.new()
	sand.albedo_color = Color(0.82, 0.74, 0.58)
	sand.roughness = 0.95
	bottom.material = sand
	_mesh(bottom, Vector3(0, -0.02, 0), self)
	_water_mat = StandardMaterial3D.new()
	_water_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_water_mat.roughness = 0.05
	_water_mat.metallic_specular = 0.7
	var water := CylinderMesh.new()
	water.top_radius = RADIUS + 0.05
	water.bottom_radius = RADIUS + 0.05
	water.height = 0.02
	water.radial_segments = 28
	water.material = _water_mat
	_mesh(water, Vector3(0, WATER, 0), self)
	# The cup on the rim, toward the wharf.
	var cup_at := cup_dir.normalized() * (RADIUS + 0.12) + Vector3(0, WATER + 0.35, 0)
	var cup := CylinderMesh.new()
	cup.top_radius = 0.16
	cup.bottom_radius = 0.12
	cup.height = 0.3
	cup.material = glass
	_mesh(cup, cup_at, self)
	_cup_mat = StandardMaterial3D.new()
	_cup_mat.albedo_color = COLOURS[kind]
	_cup_mat.emission_enabled = true
	_cup_mat.emission = COLOURS[kind]
	_cup_mat.emission_energy_multiplier = 1.2
	var fill := CylinderMesh.new()
	fill.top_radius = 0.14
	fill.bottom_radius = 0.11
	fill.height = 1.0
	fill.material = _cup_mat
	_cup_fill = _mesh(fill, cup_at, self)
	_cup_fill.set_meta("rest", cup_at)
	_build_creatures()
	_build_sparkles()
	# The creatures' own light in the water, seen after dark.
	_glow_light = OmniLight3D.new()
	_glow_light.light_color = COLOURS[kind]
	_glow_light.omni_range = 4.5
	_glow_light.position = Vector3(0, WATER * 0.6, 0)
	add_child(_glow_light)


func _mesh(mesh: Mesh, at: Vector3, parent: Node3D) -> MeshInstance3D:
	var view := MeshInstance3D.new()
	view.mesh = mesh
	view.position = at
	parent.add_child(view)
	return view


func _glow(colour: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour.darkened(0.3)
	m.roughness = 0.4
	m.emission_enabled = true
	m.emission = colour
	m.emission_energy_multiplier = energy
	_glows.append(m)
	return m


func _plain(colour: Color, rough := 0.6) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = colour
	m.roughness = rough
	return m


## Somewhere on the basin's floor, clear of the wall.
func _spot(margin := 0.4) -> Vector3:
	var a := _rng.randf() * TAU
	var r := sqrt(_rng.randf()) * (RADIUS - margin)
	return Vector3(cos(a) * r, FLOOR, sin(a) * r)


func _build_creatures() -> void:
	match species:
		Species.ANEMONE:
			var stalk_mat := _plain(Color(0.85, 0.55, 0.6))
			for i in 10:
				var c := Node3D.new()
				c.position = _spot()
				add_child(c)
				var stalk := CylinderMesh.new()
				stalk.top_radius = 0.06
				stalk.bottom_radius = 0.09
				stalk.height = 0.22
				stalk.material = stalk_mat
				_mesh(stalk, Vector3(0, 0.11, 0), c)
				var crown := Node3D.new()
				crown.position.y = 0.22
				c.add_child(crown)
				var colour: Color = [Color(0.2, 1.0, 0.9), Color(1.0, 0.3, 0.8), Color(0.5, 0.6, 1.0)][i % 3]
				var glow := _glow(colour, 1.0)
				for k in 10:
					var t := CylinderMesh.new()
					t.top_radius = 0.008
					t.bottom_radius = 0.02
					t.height = 0.18
					t.radial_segments = 5
					t.material = glow
					var tv := _mesh(t, Vector3.ZERO, crown)
					var a := TAU * k / 10.0
					tv.basis = Basis(Vector3(cos(a + PI * 0.5), 0, sin(a + PI * 0.5)), 0.7)
					tv.position = Vector3(cos(a) * 0.08, 0.07, sin(a) * 0.08)
				_creatures.append(c)
		Species.OYSTER:
			var shell := _plain(Color(0.55, 0.52, 0.48), 0.8)
			var nacre := _plain(Color(0.9, 0.88, 0.95), 0.25)
			for i in 7:
				var c := Node3D.new()
				c.position = _spot()
				c.rotation.y = _rng.randf() * TAU
				add_child(c)
				var lower := SphereMesh.new()
				lower.radius = 0.18
				lower.height = 0.12
				lower.is_hemisphere = true
				lower.material = shell
				_mesh(lower, Vector3(0, 0.06, 0), c).rotation.x = PI
				var lid := Node3D.new()
				lid.position = Vector3(0, 0.06, -0.16)
				c.add_child(lid)
				var upper := SphereMesh.new()
				upper.radius = 0.18
				upper.height = 0.12
				upper.is_hemisphere = true
				upper.material = shell
				_mesh(upper, Vector3(0, 0, 0.16), lid)
				var inner := CylinderMesh.new()
				inner.top_radius = 0.16
				inner.bottom_radius = 0.16
				inner.height = 0.005
				inner.material = nacre
				_mesh(inner, Vector3(0, 0.002, 0.16), lid)
				var pearl := SphereMesh.new()
				pearl.radius = 0.035
				pearl.height = 0.07
				pearl.material = _glow(Color(1.0, 0.97, 0.9), 0.2)
				_mesh(pearl, Vector3(0, 0.08, 0), c)
				_creatures.append(c)
		Species.URCHIN:
			var body := _glow(Color(0.5, 0.2, 0.75), 0.15)
			var spike := CylinderMesh.new()
			spike.top_radius = 0.0
			spike.bottom_radius = 0.012
			spike.height = 0.22
			spike.radial_segments = 4
			spike.material = _plain(Color(0.35, 0.12, 0.5), 0.4)
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = spike
			var count := 8
			var per := 36
			mm.instance_count = count * per
			for i in count:
				var c := Node3D.new()
				c.position = _spot() + Vector3(0, 0.1, 0)
				add_child(c)
				var ball := SphereMesh.new()
				ball.radius = 0.11
				ball.height = 0.2
				ball.material = body
				_mesh(ball, Vector3.ZERO, c)
				for k in per:
					# Spikes spread evenly over the ball (a Fibonacci spiral).
					var y := 1.0 - 2.0 * (k + 0.5) / per
					var r := sqrt(1.0 - y * y)
					var a := k * 2.39996
					var d := Vector3(cos(a) * r, y, sin(a) * r)
					var b := Basis.looking_at(d, Vector3.UP if absf(d.y) < 0.99 else Vector3.FORWARD) * Basis(Vector3.RIGHT, -PI * 0.5)
					mm.set_instance_transform(i * per + k, Transform3D(b, c.position + d * 0.18))
				_creatures.append(c)
			_urchin_spikes = MultiMeshInstance3D.new()
			_urchin_spikes.multimesh = mm
			add_child(_urchin_spikes)
		Species.KELP:
			var frond := _plain(Color(0.55, 0.6, 0.18), 0.6)
			var glint := _glow(Color(1.0, 0.85, 0.3), 0.3)
			for i in 12:
				var c := Node3D.new()
				c.position = _spot(0.5)
				c.rotation.y = _rng.randf() * TAU
				add_child(c)
				var parent := c
				for k in 4:
					var seg := Node3D.new()
					seg.position.y = 0.0 if k == 0 else 0.14
					parent.add_child(seg)
					var leaf := BoxMesh.new()
					leaf.size = Vector3(0.09 - k * 0.012, 0.15, 0.01)
					leaf.material = glint if k == 3 else frond
					_mesh(leaf, Vector3(0, 0.07, 0), seg)
					parent = seg
				_creatures.append(c)
		Species.STAR:
			var skin: Array[StandardMaterial3D] = [_plain(Color(0.95, 0.42, 0.15)), _plain(Color(0.9, 0.2, 0.25)), _plain(Color(0.95, 0.65, 0.2))]
			for i in 7:
				var c := Node3D.new()
				c.position = _spot()
				c.rotation.y = _rng.randf() * TAU
				add_child(c)
				for k in 5:
					var arm := CylinderMesh.new()
					arm.top_radius = 0.012
					arm.bottom_radius = 0.045
					arm.height = 0.2
					arm.radial_segments = 6
					arm.material = skin[i % 3]
					var av := _mesh(arm, Vector3.ZERO, c)
					var a := TAU * k / 5.0
					av.basis = Basis(Vector3(-sin(a), 0, cos(a)), PI * 0.5).scaled(Vector3(1, 1, 0.5))
					av.position = Vector3(cos(a) * 0.1, 0.02, sin(a) * 0.1)
				var disc := SphereMesh.new()
				disc.radius = 0.06
				disc.height = 0.05
				disc.material = skin[i % 3]
				_mesh(disc, Vector3(0, 0.025, 0), c)
				_creatures.append(c)
		Species.JELLY:
			for i in 7:
				var c := Node3D.new()
				c.position = _spot(0.6) + Vector3(0, 0.25, 0)
				add_child(c)
				var bell := SphereMesh.new()
				bell.radius = 0.16
				bell.height = 0.2
				bell.is_hemisphere = true
				var m := _glow(Color(1.0, 0.5, 0.85), 0.8)
				m.albedo_color = Color(1.0, 0.75, 0.95, 0.45)
				m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				bell.material = m
				_mesh(bell, Vector3.ZERO, c)
				for k in 6:
					var t := CylinderMesh.new()
					t.top_radius = 0.006
					t.bottom_radius = 0.002
					t.height = 0.22
					t.radial_segments = 4
					t.material = m
					var a := TAU * k / 6.0
					_mesh(t, Vector3(cos(a) * 0.09, -0.12, sin(a) * 0.09), c)
				_creatures.append(c)


func _build_sparkles() -> void:
	var process := ParticleProcessMaterial.new()
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(RADIUS * 0.7, 0.05, RADIUS * 0.7)
	process.direction = Vector3.UP
	process.spread = 20.0
	process.initial_velocity_min = 0.1
	process.initial_velocity_max = 0.3
	process.gravity = Vector3(0, 0.05, 0)
	var colour: Color = COLOURS[species]
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.3, 1.0])
	ramp.colors = PackedColorArray([Color(colour * 2.0, 0.0), Color(colour * 2.5, 1.0), Color(colour, 0.0)])
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	ramp_tex.use_hdr = true
	process.color_ramp = ramp_tex
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	var dot := GradientTexture2D.new()
	dot.width = 32
	dot.height = 32
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	dot.gradient = fade
	mat.albedo_texture = dot
	var quad := QuadMesh.new()
	quad.size = Vector2(0.05, 0.05)
	quad.material = mat
	_sparkles = GPUParticles3D.new()
	_sparkles.amount = 16
	_sparkles.lifetime = 2.0
	_sparkles.process_material = process
	_sparkles.draw_pass_1 = quad
	_sparkles.position = Vector3(0, WATER - 0.1, 0)
	_sparkles.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_sparkles)


## A second of life: `fed` broth a second comes in.
func step(dt: float, fed: float) -> void:
	nutrients = clampf(nutrients + fed * dt - float(APPETITE[species]) * dt, 0.0, 1.0)
	vigour = move_toward(vigour, smoothstep(0.03, 0.35, nutrients), dt * 0.3)
	product = minf(product + float(PACE[species]) * vigour * dt, 1.0)
	hungry = nutrients < (0.75 if hungry else 0.3)
	ripe = product >= (0.95 if ripe else 1.0)


## The cup emptied into the cart; how much it held.
func take() -> float:
	var got := product
	product = 0.0
	ripe = false
	return got


func _process(delta: float) -> void:
	_clock += delta
	var t := _clock + _phase
	var lively := 0.25 + 0.75 * vigour
	var clear := Color(0.55, 0.78, 0.85, 0.3)
	var rich := Color(0.25, 0.6, 0.45, 0.55).lerp(Color(COLOURS[species], 0.55), 0.25)
	_water_mat.albedo_color = clear.lerp(rich, nutrients)
	for g in _glows:
		g.emission_energy_multiplier = (0.15 + 1.8 * vigour) * (0.75 + 0.25 * sin(t * 2.0 + g.get_instance_id() % 7))
	for i in _creatures.size():
		var c := _creatures[i]
		var p := t * lively + i * 1.3
		match species:
			Species.ANEMONE:
				(c.get_child(1) as Node3D).rotation = Vector3(sin(p * 1.3) * 0.25, p * 0.2, cos(p * 1.1) * 0.25)
				(c.get_child(1) as Node3D).scale = Vector3.ONE * (0.85 + 0.25 * vigour + 0.05 * sin(p * 3.0))
			Species.OYSTER:
				(c.get_child(1) as Node3D).rotation.x = -maxf(sin(p * 0.6), 0.0) * 0.6 * vigour
				var pearl := c.get_child(2) as MeshInstance3D
				pearl.scale = Vector3.ONE * (0.3 + product)
			Species.URCHIN:
				pass
			Species.KELP:
				var seg := c.get_child(0) as Node3D
				var k := 0
				while seg != null:
					seg.rotation.z = sin(p * 1.4 - k * 0.6) * 0.18 * (0.5 + vigour)
					seg.rotation.x = cos(p * 1.1 - k * 0.5) * 0.1
					seg = seg.get_child(1) as Node3D if seg.get_child_count() > 1 else null
					k += 1
			Species.STAR:
				c.rotation.y += delta * 0.15 * lively * (1.0 if i % 2 == 0 else -1.0)
				var heading := Vector3(sin(c.rotation.y), 0, cos(c.rotation.y))
				c.position += heading * delta * 0.02 * lively
				if Vector2(c.position.x, c.position.z).length() > RADIUS - 0.4:
					c.position = Vector3(c.position.x * 0.98, c.position.y, c.position.z * 0.98)
					c.rotation.y += PI * 0.5
			Species.JELLY:
				var pulse := 0.5 + 0.5 * sin(p * 2.2)
				c.scale = Vector3(1.0 + 0.12 * pulse, 1.0 - 0.15 * pulse, 1.0 + 0.12 * pulse)
				c.position.y = FLOOR + 0.25 + 0.12 * sin(p * 0.5) * lively
	if _urchin_spikes != null:
		_urchin_spikes.rotation.y += delta * 0.03 * lively
	# The cup filling.
	var rest: Vector3 = _cup_fill.get_meta("rest")
	var h := 0.26 * product
	_cup_fill.visible = product > 0.02
	_cup_fill.position = rest + Vector3(0, -0.13 + h * 0.5, 0)
	_cup_fill.scale = Vector3(1, maxf(h, 0.005), 1)
	_cup_mat.emission_energy_multiplier = 0.8 + 1.5 * product
	_glow_light.visible = night > 0.1 and vigour > 0.05
	_glow_light.light_energy = night * vigour * (0.7 + 0.15 * sin(t * 1.3))
	_sparkles.emitting = vigour > 0.4
	_sparkles.amount_ratio = clampf(vigour, 0.1, 1.0)
