class_name Campfire
extends Node3D
## A small campfire: flames, embers and a wisp of smoke as the engine's
## GPU particles, and an orange point light at the flames with shadows,
## its brightness flickering. No custom shader.
##
## Each kind of particle is a camera-facing square (billboard) carrying a
## soft round dot, born in a small volume at the fire's base and pushed
## up as warm air pushes a flame: an upward acceleration in place of
## gravity, a little sideways turbulence, a colour and size over its
## life from a gradient and a curve. Flames are drawn additively (light
## added to what is behind, so overlapping ones grow brighter, as real
## flames do), in colours brighter than white so the glow picks them
## up; smoke is drawn mixed, grey and faint, and lit like a surface, so
## it shows only where the fire or the sky lights it.
##
## The light's flicker follows two noises read at different speeds, the
## fast one small: a flame's brightness wavers a few times a second and
## surges more slowly.

const LIGHT_ENERGY := 1.6

var _light: OmniLight3D
var _flicker := FastNoiseLite.new()
var _clock := 0.0
var _level := 1.0


func _init() -> void:
	name = "Campfire"
	_flicker.seed = 9
	_flicker.frequency = 1.0
	add_child(_particles("Flames", 70, 0.9, 0.3,
			[Color(1.4, 1.0, 0.5, 0.0), Color(1.4, 0.7, 0.2, 0.8), Color(1.2, 0.35, 0.07, 0.5), Color(0.5, 0.08, 0.02, 0.0)],
			[0.0, 0.06, 0.45, 1.0], 0.13, Vector2(0.4, 0.8), 2.5, true))
	add_child(_particles("Embers", 10, 2.2, 0.035,
			[Color(4.0, 1.8, 0.5, 1.0), Color(3.0, 0.9, 0.2, 1.0), Color(1.0, 0.2, 0.05, 0.0)],
			[0.0, 0.6, 1.0], 0.15, Vector2(0.8, 1.6), 0.6, true))
	var smoke := _particles("Smoke", 14, 4.5, 0.7,
			[Color(0.22, 0.22, 0.22, 0.0), Color(0.2, 0.2, 0.2, 0.1), Color(0.24, 0.24, 0.25, 0.0)],
			[0.0, 0.25, 1.0], 0.15, Vector2(0.5, 0.8), 0.25, false)
	smoke.position.y = 1.0
	add_child(smoke)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.58, 0.28)
	# Falling off faster than the engine's default, so the glow stays
	# round the fire.
	_light.omni_range = 7.0
	_light.omni_attenuation = 2.0
	_light.shadow_enabled = true
	# Two half-sphere shadow maps instead of six faces of a cube: a third
	# of the drawing, slightly less exact.
	_light.omni_shadow_mode = OmniLight3D.SHADOW_DUAL_PARABOLOID
	_light.position.y = 0.6
	add_child(_light)


## One kind of particle: `amount` alive at once, each living `life`
## seconds, a square `size` across, coloured along its life by `colours`
## at `stops`, born within `spread` of the base, rising at `speed`
## (least, most) metres a second and pushed up by `lift`.
func _particles(title: String, amount: int, life: float, size: float, colours: Array, stops: Array,
		spread: float, speed: Vector2, lift: float, additive: bool) -> GPUParticles3D:
	var process := ParticleProcessMaterial.new()
	# Born in a flat square on the logs.
	process.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	process.emission_box_extents = Vector3(spread, 0.03, spread)
	process.direction = Vector3.UP
	process.spread = 12.0
	process.initial_velocity_min = speed.x
	process.initial_velocity_max = speed.y
	process.gravity = Vector3(0.0, lift, 0.0)
	process.damping_min = 0.5
	process.damping_max = 1.0
	process.turbulence_enabled = true
	process.turbulence_noise_strength = 0.4
	process.turbulence_noise_scale = 2.0
	process.turbulence_influence_min = 0.05
	process.turbulence_influence_max = 0.15
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array(stops)
	ramp.colors = PackedColorArray(colours)
	var ramp_tex := GradientTexture1D.new()
	ramp_tex.gradient = ramp
	ramp_tex.use_hdr = true
	process.color_ramp = ramp_tex
	# Flames shrink as they rise; smoke spreads.
	var curve := Curve.new()
	if additive:
		curve.add_point(Vector2(0.0, 0.6))
		curve.add_point(Vector2(0.25, 1.0))
		curve.add_point(Vector2(1.0, 0.2))
	else:
		curve.add_point(Vector2(0.0, 0.4))
		curve.add_point(Vector2(1.0, 1.6))
	var curve_tex := CurveTexture.new()
	curve_tex.curve = curve
	process.scale_curve = curve_tex
	var mat := StandardMaterial3D.new()
	if additive:
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if additive else BaseMaterial3D.BLEND_MODE_MIX
	mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	mat.vertex_color_use_as_albedo = true
	mat.albedo_texture = _soft_dot()
	mat.disable_receive_shadows = true
	var quad := QuadMesh.new()
	quad.size = Vector2(size, size)
	quad.material = mat
	var p := GPUParticles3D.new()
	p.name = title
	p.amount = amount
	p.lifetime = life
	p.preprocess = life
	p.process_material = process
	p.draw_pass_1 = quad
	p.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.visibility_aabb = AABB(Vector3(-2, -0.5, -2), Vector3(4, 8, 4))
	return p


func _soft_dot() -> GradientTexture2D:
	var dot := GradientTexture2D.new()
	dot.width = 64
	dot.height = 64
	dot.fill = GradientTexture2D.FILL_RADIAL
	dot.fill_from = Vector2(0.5, 0.5)
	dot.fill_to = Vector2(1.0, 0.5)
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.4, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0.45), Color(1, 1, 1, 0)])
	dot.gradient = fade
	return dot


## How strongly it burns, 0 to 1: fewer flames and less light below 1.
func set_level(level: float) -> void:
	_level = clampf(level, 0.0, 1.0)
	_light.visible = _level > 0.01
	for p in get_children():
		if p is GPUParticles3D:
			(p as GPUParticles3D).amount_ratio = maxf(_level, 0.05)


func _process(delta: float) -> void:
	_clock += delta
	var waver := _flicker.get_noise_1d(_clock * 9.0) * 0.12 + _flicker.get_noise_1d(_clock * 1.7 + 50.0) * 0.18
	_light.light_energy = LIGHT_ENERGY * (1.0 + waver) * _level
	_light.position = Vector3(_flicker.get_noise_1d(_clock * 5.0 + 20.0) * 0.06, 0.6, _flicker.get_noise_1d(_clock * 5.0 + 90.0) * 0.06)
