class_name PoolCaustics
extends RefCounted
## Works out the light pool's caustics each frame on a rendering device of
## its own (pool_caustics.glsl, a compute shader), from the same two
## ripple maps the glass shows, and hands back the picture for the light
## through the glass to carry, one channel of grey, and, when asked, a
## finer one for a narrower light over the ceiling and the upper walls. Godot's projector takes
## up a new picture only when handed a different texture, so two
## alternate. Each frame's work is sent off and collected on the next
## frame, so the game never waits for it; the picture is a frame behind.
## Without a rendering device (headless runs) it gives nothing.

const SIZE := 512                       # the wide picture's side; at 1024, Godot's copying of each new projector picture cost about 15 ms a frame
const DROPS := 100                      # as many as the glass keeps
const FINE_ANGLE := 40.0                # degrees: the narrow light's half-angle, the ceiling and the walls above 3.5 m
const LAUNCH_MARGIN := 1.1              # the narrow pass's rays start this much wider than its picture

var rays_per_pixel := 4                 # on still water: 4, 16 or 64
var jitter := false
var core := 0.01
var fine_size := 0                      # the narrow picture's side; 0, none
var test := false                       # a marker in one quarter, to check the picture's way round

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _maps: Array[RID] = []
var _sampler: RID
var _drops: RID
var _passes: Array[Dictionary] = []     # {size, tally, picture, set, textures, shown}
var _pending: Array[int] = []           # sizes of the passes sent and not yet collected
var _frame := 0


## Ready to work once both ripple maps have their images.
func start(maps: Array[NoiseTexture2D]) -> bool:
	if _rd != null:
		return true
	var images: Array[Image] = []
	for map in maps:
		var img := map.get_image()
		if img == null:
			return false
		img = img.duplicate() as Image
		img.clear_mipmaps()
		img.convert(Image.FORMAT_RGBA8)
		images.append(img)
	_rd = RenderingServer.create_local_rendering_device()
	if _rd == null:
		return false
	var file := load("res://world/pool_caustics.glsl") as RDShaderFile
	_shader = _rd.shader_create_from_spirv(file.get_spirv())
	_pipeline = _rd.compute_pipeline_create(_shader)
	for img in images:
		var fmt := RDTextureFormat.new()
		fmt.width = img.get_width()
		fmt.height = img.get_height()
		fmt.format = RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM
		fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_SAMPLING_BIT | RenderingDevice.TEXTURE_USAGE_CAN_UPDATE_BIT
		_maps.append(_rd.texture_create(fmt, RDTextureView.new(), [img.get_data()]))
	var state := RDSamplerState.new()
	state.mag_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.min_filter = RenderingDevice.SAMPLER_FILTER_LINEAR
	state.repeat_u = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	state.repeat_v = RenderingDevice.SAMPLER_REPEAT_MODE_REPEAT
	_sampler = _rd.sampler_create(state)
	var none := PackedVector4Array()
	none.resize(DROPS)
	_drops = _rd.storage_buffer_create(DROPS * 16, none.to_byte_array())
	_passes.append(_make_pass(SIZE))
	_passes.append({})
	return true


## A tally, a picture and the two textures that take it in turn, at
## `size` square.
func _make_pass(size: int) -> Dictionary:
	var tally_fmt := RDTextureFormat.new()
	tally_fmt.width = size
	tally_fmt.height = size
	tally_fmt.format = RenderingDevice.DATA_FORMAT_R32_UINT
	tally_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	var tally := _rd.texture_create(tally_fmt, RDTextureView.new())
	var pic_fmt := RDTextureFormat.new()
	pic_fmt.width = size
	pic_fmt.height = size
	pic_fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	pic_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	var picture := _rd.texture_create(pic_fmt, RDTextureView.new())
	var uniforms: Array[RDUniform] = []
	for pair: Array in [[0, tally], [1, picture]]:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
		u.binding = int(pair[0])
		u.add_id(pair[1])
		uniforms.append(u)
	for i in 2:
		var u := RDUniform.new()
		u.uniform_type = RenderingDevice.UNIFORM_TYPE_SAMPLER_WITH_TEXTURE
		u.binding = 2 + i
		u.add_id(_sampler)
		u.add_id(_maps[i])
		uniforms.append(u)
	var drops := RDUniform.new()
	drops.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	drops.binding = 4
	drops.add_id(_drops)
	uniforms.append(drops)
	var textures: Array[ImageTexture] = []
	var blank := Image.create(size, size, true, Image.FORMAT_L8)
	for i in 2:
		textures.append(ImageTexture.create_from_image(blank))
	return {"size": size, "tally": tally, "picture": picture,
		"set": _rd.uniform_set_create(uniforms, _shader, 0), "textures": textures, "shown": 0}


func _free_pass(p: Dictionary) -> void:
	for key: String in ["set", "tally", "picture"]:
		if p.has(key) and (p[key] as RID).is_valid():
			_rd.free_rid(p[key])


func free_device() -> void:
	if _rd == null:
		return
	if not _pending.is_empty():
		_rd.sync()
	for p in _passes:
		_free_pass(p)
	for rid: RID in [_drops, _sampler, _pipeline, _shader] + _maps:
		if rid.is_valid():
			_rd.free_rid(rid)
	_rd.free()
	_rd = null


## The last frame's pictures, collected now, and this frame's work sent
## off: [the wide light's, the narrow light's], each null when there is
## none yet or none wanted. For lights at `lamp` pointing straight up,
## the wide one with half-angle `angle` degrees; water at `water` height,
## ceiling at `ceiling`, walls `half_room` either way from x 0, z 0; the
## ripples and the drops (where, when, how hard, on the clock `now`) as
## the glass has them; `blur` the bulb's blur as a tangent.
func render(lamp: Vector3, angle: float, water: float, ceiling: float, half_room: float, strength: float,
		ripple_size: float, offsets: Array[Vector2], drops: PackedVector4Array, now: float,
		drip_strength: float, blur: float) -> Array[ImageTexture]:
	var out: Array[ImageTexture] = [null, null]
	if _rd == null:
		return out
	if not _pending.is_empty():
		_rd.sync()
		for i in _passes.size():
			var p := _passes[i]
			if p.is_empty() or _pending[i] != int(p["size"]):
				continue
			var size := int(p["size"])
			var img := Image.create_from_data(size, size, false, Image.FORMAT_L8, _rd.texture_get_data(p["picture"], 0))
			img.generate_mipmaps()
			p["shown"] = 1 - int(p["shown"])
			var tex := (p["textures"] as Array)[p["shown"]] as ImageTexture
			tex.update(img)
			out[i] = tex
		_pending.clear()
	# The narrow pass made afresh when its size changes.
	var fine := _passes[1]
	if (fine.is_empty() and fine_size > 0) or (not fine.is_empty() and int(fine["size"]) != fine_size):
		if not fine.is_empty():
			_free_pass(fine)
		_passes[1] = _make_pass(fine_size) if fine_size > 0 else {}
	var wide_tan := tan(deg_to_rad(angle))
	var fine_tan := tan(deg_to_rad(FINE_ANGLE)) if fine_size > 0 else 0.0
	var side := sqrt(float(rays_per_pixel))
	_frame += 1
	_rd.buffer_update(_drops, 0, DROPS * 16, drops.to_byte_array())
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	for i in _passes.size():
		var p := _passes[i]
		if p.is_empty():
			_pending.append(0)
			continue
		var size := int(p["size"])
		var span := wide_tan if i == 0 else fine_tan
		var launch := span if i == 0 else span * LAUNCH_MARGIN
		var rays := roundi(size * side * launch / span)
		var params := PackedByteArray()
		params.resize(112)
		params.encode_s32(4, size)
		params.encode_s32(8, rays)
		params.encode_s32(12, 1 if test else 0)
		params.encode_float(16, lamp.x)
		params.encode_float(20, lamp.y)
		params.encode_float(24, lamp.z)
		params.encode_float(28, water)
		params.encode_float(32, ceiling)
		params.encode_float(36, span)
		params.encode_float(40, strength)
		params.encode_float(44, ripple_size)
		params.encode_float(48, offsets[0].x)
		params.encode_float(52, offsets[0].y)
		params.encode_float(56, offsets[1].x)
		params.encode_float(60, offsets[1].y)
		params.encode_float(64, blur / (2.0 * span) * size)
		params.encode_float(68, now)
		params.encode_float(72, drip_strength)
		params.encode_float(76, half_room)
		params.encode_float(80, core)
		params.encode_float(84, launch)
		params.encode_float(88, fine_tan)
		params.encode_float(92, 1.0 if jitter else 0.0)
		params.encode_s32(96, i)
		params.encode_s32(100, _frame)
		_rd.compute_list_bind_uniform_set(list, p["set"], 0)
		for stage: int in [0, 1, 2]:
			params.encode_s32(0, stage)
			_rd.compute_list_set_push_constant(list, params, params.size())
			var groups := ceili((rays if stage == 1 else size) / 8.0)
			_rd.compute_list_dispatch(list, groups, groups, 1)
			_rd.compute_list_add_barrier(list)
		_pending.append(size)
	_rd.compute_list_end()
	_rd.submit()
	return out
