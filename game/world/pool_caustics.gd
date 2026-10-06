class_name PoolCaustics
extends RefCounted
## Works out the light pool's caustics each frame on a rendering device of
## its own (pool_caustics.glsl, a compute shader), from the same two
## ripple maps the glass shows, and hands back the picture for the light
## through the glass to carry, one channel of grey. Godot's projector takes
## up a new picture only when handed a different texture, so two
## alternate. Each frame's work is sent off and collected on the next
## frame, so the game never waits for it; the picture is a frame behind.
## Without a rendering device (headless runs) it gives nothing.

const SIZE := 512                       # the picture's side; at 1024, Godot's copying of each new projector picture cost about 15 ms a frame
const DROPS := 32                       # as many as the glass keeps
const RAYS := 1024                      # rays per side of the cone: four a pixel

var _rd: RenderingDevice
var _shader: RID
var _pipeline: RID
var _tally: RID
var _picture: RID
var _maps: Array[RID] = []
var _sampler: RID
var _drops: RID
var _set: RID
var _textures: Array[ImageTexture] = []
var _shown := 0
var _pending := false                   # work sent and not yet collected
var test := false                        # a marker in one quarter, to check the picture's way round


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
	var tally_fmt := RDTextureFormat.new()
	tally_fmt.width = SIZE
	tally_fmt.height = SIZE
	tally_fmt.format = RenderingDevice.DATA_FORMAT_R32_UINT
	tally_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT
	_tally = _rd.texture_create(tally_fmt, RDTextureView.new())
	var pic_fmt := RDTextureFormat.new()
	pic_fmt.width = SIZE
	pic_fmt.height = SIZE
	pic_fmt.format = RenderingDevice.DATA_FORMAT_R8_UNORM
	pic_fmt.usage_bits = RenderingDevice.TEXTURE_USAGE_STORAGE_BIT | RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	_picture = _rd.texture_create(pic_fmt, RDTextureView.new())
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
	var uniforms: Array[RDUniform] = []
	for pair: Array in [[0, _tally], [1, _picture]]:
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
	_set = _rd.uniform_set_create(uniforms, _shader, 0)
	var blank := Image.create(SIZE, SIZE, true, Image.FORMAT_L8)
	for i in 2:
		_textures.append(ImageTexture.create_from_image(blank))
	return true


func free_device() -> void:
	if _rd == null:
		return
	if _pending:
		_rd.sync()
	for rid: RID in [_set, _drops, _sampler, _tally, _picture, _pipeline, _shader] + _maps:
		if rid.is_valid():
			_rd.free_rid(rid)
	_rd.free()
	_rd = null


## The last frame's picture, collected now, and this frame's work sent
## off; null on the first frame. For a light at `lamp` pointing straight up with
## half-angle `angle` degrees; water at `water` height, ceiling at
## `ceiling`; the ripples and the drops (where, when, how hard, on the
## clock `now`) as the glass has them; `blur_px` the bulb's blur in pixels
## of the picture.
func render(lamp: Vector3, angle: float, water: float, ceiling: float, strength: float,
		ripple_size: float, offsets: Array[Vector2], drops: PackedVector4Array, now: float,
		drip_strength: float, blur_px: float) -> ImageTexture:
	if _rd == null:
		return null
	var picture: ImageTexture = null
	if _pending:
		_rd.sync()
		_pending = false
		var img := Image.create_from_data(SIZE, SIZE, false, Image.FORMAT_L8, _rd.texture_get_data(_picture, 0))
		img.generate_mipmaps()
		_shown = 1 - _shown
		_textures[_shown].update(img)
		picture = _textures[_shown]
	var params := PackedByteArray()
	params.resize(80)
	params.encode_s32(4, SIZE)
	params.encode_s32(8, RAYS)
	params.encode_s32(12, 1 if test else 0)
	params.encode_float(16, lamp.x)
	params.encode_float(20, lamp.y)
	params.encode_float(24, lamp.z)
	params.encode_float(28, water)
	params.encode_float(32, ceiling)
	params.encode_float(36, tan(deg_to_rad(angle)))
	params.encode_float(40, strength)
	params.encode_float(44, ripple_size)
	params.encode_float(48, offsets[0].x)
	params.encode_float(52, offsets[0].y)
	params.encode_float(56, offsets[1].x)
	params.encode_float(60, offsets[1].y)
	params.encode_float(64, blur_px)
	params.encode_float(68, now)
	params.encode_float(72, drip_strength)
	_rd.buffer_update(_drops, 0, DROPS * 16, drops.to_byte_array())
	var list := _rd.compute_list_begin()
	_rd.compute_list_bind_compute_pipeline(list, _pipeline)
	_rd.compute_list_bind_uniform_set(list, _set, 0)
	for stage: int in [0, 1, 2]:
		params.encode_s32(0, stage)
		_rd.compute_list_set_push_constant(list, params, params.size())
		var groups := ceili((RAYS if stage == 1 else SIZE) / 8.0)
		_rd.compute_list_dispatch(list, groups, groups, 1)
		_rd.compute_list_add_barrier(list)
	_rd.compute_list_end()
	_rd.submit()
	_pending = true
	return picture
