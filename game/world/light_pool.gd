class_name LightPool
extends Node3D
## A closed room ten metres every way. Most of its floor is an opening
## 7.5 m square onto a dark chamber under the whole room, lit by one bare
## lamp on a stand. The lamp is the only light, so the room is lit from
## below through the opening: the ceiling brightest, the walls fading
## downward, the deck around the opening in the room's own reflected
## light. A stair along the south wall goes down into the chamber.
## Across the opening, 35 cm below the deck, lies one pane of glass 4 cm
## thick, set into the deck's sides all round, solid to walk on.
##
## Drawn by the engine's own lighting (an omni light with shadows and
## standard materials, in an environment with a black background, no
## ambient light, no sky reflections and no glow), with two stand-ins
## for the glass, described below: a custom shader that shows what lies
## behind the opaque pane, and an area light for the light through it.
##
## Controls in four panels (BenchPanel), with the mouse freed by Esc, as
## in the one-bulb scene. Lamp: its colour and energy (the glass's glow
## follows both) and its indirect energy, a multiplier on its light as it
## enters the bounce only. Light: the bounce method (None, SDFGI, or a
## VoxelGI box around the room and the chamber, baked each time it is
## chosen; VoxelGI to begin), the bounce traced at half the screen's
## resolution (on to begin), SDFGI's smallest cell (0.2 m to begin, the
## engine's default, which here gives no bounce), VoxelGI's quality (Low
## to begin, the engine's default), SSIL and SSAO, and the tone curve (AgX to begin).
## Viewport: dithering (1 key) and the shadow atlas (2 key: 4096, 8192,
## 16384 texels square). Glass: its opacity, tint, roughness and
## specular, its thickness (top fixed, growing downward), and whether the
## bounce methods see it. Light: also VoxelGI's cells along its box's
## longest side (64 to begin; light leaks through anything thinner than
## a cell).
##
## The glass is opaque: it casts a full shadow and blocks the lamp from
## the room. It is seen through by a second camera at the eye (`_portal`,
## a SubViewport sharing the world, matched to the eye's camera each
## frame) that renders the scene without the pane (the pane is on render
## layer PANE, which that camera does not see); the pane's shader
## (pool_glass.gdshader, custom) gives off that picture's light at each
## pixel, times 1 minus the opacity. The picture is untonemapped (the
## second camera's environment is the room's with the Linear curve), so
## the screen's tone curve applies once. The light the glass would let
## through is a rectangle area light over the pane facing up (`_through`),
## lighting everything but the pane, its energy the lamp's energy times 1
## minus the opacity times THROUGH_SCALE, measured so that the ceiling's
## middle gets what the lamp gave it through clear glass. It is soft
## and casts no shadows: a glowing rectangle, not the bulb's sharp
## shadows. The pane is in the
## bounce (GI mode Static) to begin, so the bounce methods too find the
## lamp's light blocked. Dithering, the atlas, half
## resolution and VoxelGI quality are engine-wide and put back as found
## when the scene closes. Settings are kept in user://light_pool.json.

const ROOM := 10.0                     # inside, every way
const OPENING_HALF := 3.75             # the opening is 7.5 m square
const OPENING_CENTRE := Vector2(0.0, -0.5) # x, z: north of centre, leaving the south walk for the stair
const SLAB_BOTTOM := -0.55             # the deck's underside, the chamber's ceiling
const TILE := 0.04                     # the stone facing on the deck
const CHAMBER_FLOOR := -3.2
const LAMP := Vector3(0.0, -2.4, -0.5) # under the opening's middle, 0.8 m over the chamber floor
const LAMP_COLOUR := Color(1.0, 0.96, 0.9)
const LAMP_ENERGY := 60.0
const BULB_GLOW := 40.0                # the glass's emission
const CHAMBER_ALBEDO := 0.12           # the chamber's paint, as its colour's channels (sRGB)
const WALL := 0.3
const START := Vector3(-2.5, 0.0, 4.3)
# The stair: 18 risers down the south wall, westward from x = STAIR_TOP.
const STAIR_TOP := 4.0
const STAIR_Z := 4.05                  # its north side; the room's wall is its south
const RISERS := 18
const GOING := 0.28                    # m, each tread front to back
const HOLE_WEST := -0.3                # the deck's stair opening ends here: 2 m headroom past it
const GLASS_TOP := -0.35               # the pane's upper face, below the deck
const GLASS_THICK := 0.04
const GLASS_TINT := Color(0.88, 0.95, 0.92) # the faint green of float glass
const GLASS_ALPHA := 0.1
const PANE := 2                        # render layer of the glass, unseen by the second camera
# The area light's energy for the lamp's light through clear glass, per
# unit of the lamp's energy: measured so the ceiling's middle gets the
# same direct light from either.
const THROUGH_SCALE := 0.80            # measured: lamp 0.0500, area light at the lamp's energy 0.0628

const ATLAS_SIZES: Array[int] = [4096, 8192, 16384]
const TONEMAPS := {"Linear": Environment.TONE_MAPPER_LINEAR, "Reinhard": Environment.TONE_MAPPER_REINHARDT,
	"Filmic": Environment.TONE_MAPPER_FILMIC, "ACES": Environment.TONE_MAPPER_ACES, "AgX": Environment.TONE_MAPPER_AGX}
const STATE_PATH := "user://light_pool.json"

@onready var player: Player = $Player
@onready var _env: Environment = ($WorldEnvironment as WorldEnvironment).environment

var _panel: BenchPanel
var _light: OmniLight3D
var _glass: StandardMaterial3D
var _voxel_gi: VoxelGI = null
var _bounce := "None"                   # None, SDFGI or VoxelGI
var _status: Label
var _bounce_box: VBoxContainer
var _indirect_box: VBoxContainer
var _sdfgi_box: VBoxContainer
var _voxel_box: VBoxContainer
var _atlas_button: Button
var _was: Dictionary = {}               # the engine-wide settings as found
var _glass_pane: MeshInstance3D
var _glass_mat: ShaderMaterial
var _glass_gi_box: VBoxContainer
var _portal: SubViewport
var _portal_cam: Camera3D
var _portal_env: Environment
var _through: AreaLight3D
var _opacity := GLASS_ALPHA
var _thickness := GLASS_THICK
var _glass_box: BoxMesh
var _glass_shape: BoxShape3D
var _glass_body: StaticBody3D
var _voxel_subdiv := VoxelGI.SUBDIV_64
var _rebake_in := -1.0                  # seconds to a VoxelGI re-bake; below 0, none due


func _ready() -> void:
	player.global_position = START
	for node in player.find_children("*", "GeometryInstance3D", true, false):
		(node as GeometryInstance3D).gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
	var vp := get_viewport()
	_was = {
		"debanding": vp.use_debanding,
		"atlas": vp.positional_shadow_atlas_size,
		"half": ProjectSettings.get_setting("rendering/global_illumination/gi/use_half_resolution", false),
		"quality": ProjectSettings.get_setting("rendering/global_illumination/voxel_gi/quality", 0),
	}
	_build_room()
	_build_deck()
	_build_lamp()
	_build_glass()
	_build_panels()
	RenderingServer.gi_set_use_half_resolution(true)
	RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_LOW)
	_set_bounce("VoxelGI")
	var extra := _panel.restore()
	var atlas := int(extra.get("atlas", vp.positional_shadow_atlas_size))
	if ATLAS_SIZES.has(atlas):
		vp.positional_shadow_atlas_size = atlas
	_show_atlas()
	_refresh()
	MouseMode.capture()


func _exit_tree() -> void:
	var vp := get_viewport()
	vp.use_debanding = _was["debanding"]
	vp.positional_shadow_atlas_size = _was["atlas"]
	RenderingServer.gi_set_use_half_resolution(_was["half"])
	RenderingServer.voxel_gi_set_quality(_was["quality"])


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and (event as InputEventKey).pressed \
			and not (event as InputEventKey).echo:
		match (event as InputEventKey).keycode:
			KEY_1:
				var dither := _panel.switches["Dithering (1)"] as CheckButton
				dither.button_pressed = not dither.button_pressed
			KEY_2:
				_next_atlas()


## ---- the controls ----------------------------------------------------------

func _build_panels() -> void:
	_panel = BenchPanel.new(STATE_PATH)
	add_child(_panel)
	var vp := get_viewport()

	var lamp := _panel.panel("Lamp")
	_panel.colour(lamp, "Colour", LAMP_COLOUR, func(c: Color) -> void:
		_light.light_color = c
		_glass.emission = c
		_through.light_color = c)
	_panel.slider(lamp, "Energy", 0.0, 200.0, 1.0, LAMP_ENERGY, func(v: float) -> void:
		_light.light_energy = v
		_glass.emission_energy_multiplier = BULB_GLOW * v / LAMP_ENERGY
		_set_through())
	_panel.note(lamp, "The light's strength, in its direct light and in the bounce alike. The glowing glass follows the colour and the energy; it is drawn and lights nothing.")
	_indirect_box = _panel.box(lamp)
	_panel.slider(_indirect_box, "Indirect energy", 0.0, 4.0, 0.01, 1.0, func(v: float) -> void:
		_light.light_indirect_energy = v)
	_panel.note(_indirect_box, "A second multiplier on the lamp's light as it enters the bounce only: the bounce starts from Energy times this. 1 is the physical value; 0 shows the direct light alone.")
	_panel.button(lamp, "Reset all", _reset)

	var light := _panel.panel("Light")
	_status = _panel.note(light, "")
	_status.add_theme_color_override("font_color", Color(1.0, 0.92, 0.7))
	_panel.choice(light, "Bounce", ["None", "SDFGI", "VoxelGI"], "VoxelGI", _set_bounce)
	_bounce_box = _panel.box(light)
	_panel.switch(_bounce_box, "Half resolution", true, func(on: bool) -> void:
		RenderingServer.gi_set_use_half_resolution(on))
	_panel.note(_bounce_box, "Traces the bounce for every other pixel each way and fills in between: about a quarter of the cost, softer at edges.")
	_sdfgi_box = _panel.box(light)
	_panel.slider(_sdfgi_box, "SDFGI smallest cell (m)", 0.05, 1.0, 0.01, 0.2, func(v: float) -> void:
		_env.sdfgi_min_cell_size = v)
	_panel.note(_sdfgi_box, "SDFGI divides the space round the camera into cells, each further ring of them twice the size of the last. This is the size nearest the camera: smaller is finer and reaches less far. In this room the engine's default, 0.2 m, gives no bounce at all; every wall, the deck and the ceiling lie on 0.2 m multiples. Any other size works.")
	_voxel_box = _panel.box(light)
	_panel.choice(_voxel_box, "VoxelGI cells", ["64", "128", "256", "512"], "64", func(option: String) -> void:
		_voxel_subdiv = {"64": VoxelGI.SUBDIV_64, "128": VoxelGI.SUBDIV_128,
			"256": VoxelGI.SUBDIV_256, "512": VoxelGI.SUBDIV_512}[option]
		if _bounce == "VoxelGI":
			_set_bounce("VoxelGI"))
	_panel.note(_voxel_box, "Cells along the box's longest side, 14.2 m: about 22, 11, 5.5 or 2.8 cm each. Light leaks through anything thinner than a cell, as through the glass. Finer takes longer to bake and more memory; the box is baked again on a change.")
	_panel.choice(_voxel_box, "VoxelGI quality", ["Low", "High"], "Low", func(option: String) -> void:
		RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_HIGH if option == "High"
			else RenderingServer.VOXEL_GI_QUALITY_LOW))
	_panel.note(_voxel_box, "How many cones each pixel traces through the voxels: High traces more, smoother and dearer.")
	_panel.heading(light, "On screen, added to any of the above")
	_panel.switch(light, "SSIL", false, func(on: bool) -> void:
		_env.ssil_enabled = on
		_refresh())
	_panel.note(light, "Light from the surfaces around each pixel on screen, taken from the last frame's image, so bounces build up over a few frames. Only surfaces in view contribute. It also dims the bounce where it finds it blocked.")
	_panel.switch(light, "SSAO", false, func(on: bool) -> void:
		_env.ssao_enabled = on
		_refresh())
	_panel.note(light, "Darkens bounce light in corners, SSIL's light included; leaves the lamp's direct light alone.")
	_panel.heading(light, "Tone curve")
	_panel.choice(light, "Curve", ["Linear", "Reinhard", "Filmic", "ACES", "AgX"], "AgX", func(option: String) -> void:
		_env.tonemap_mode = TONEMAPS[option])
	_panel.note(light, "How light, which has no upper limit, is mapped to the screen's 0 to 1. Linear clips everything brighter than white; the others roll it off, each with its own shape.")
	_env.tonemap_mode = Environment.TONE_MAPPER_AGX

	var glass := _panel.panel("Glass")
	_panel.slider(glass, "Opacity", 0.0, 1.0, 0.01, GLASS_ALPHA, func(v: float) -> void:
		_opacity = v
		_glass_mat.set_shader_parameter("opacity", v)
		_set_through())
	_panel.note(glass, "The pane is opaque. It gives off the second camera's picture of what lies behind it times 1 minus this, and shows its own colour times this. The light through it is an area light over the pane, at the lamp's light times 1 minus this.")
	_panel.colour(glass, "Tint", GLASS_TINT, func(c: Color) -> void:
		_glass_mat.set_shader_parameter("tint", c))
	_panel.slider(glass, "Roughness", 0.0, 1.0, 0.01, 0.05, func(v: float) -> void:
		_glass_mat.set_shader_parameter("roughness", v))
	_panel.note(glass, "How widely its reflections spread; polished glass is near 0.")
	_panel.slider(glass, "Specular", 0.0, 1.0, 0.01, 0.5, func(v: float) -> void:
		_glass_mat.set_shader_parameter("specular", v))
	_panel.note(glass, "Reflection strength face on; 0.5 is about 4%, as for glass. Stronger toward grazing angles by the engine's Fresnel term.")
	_panel.slider(glass, "Thickness (m)", 0.01, 0.5, 0.01, GLASS_THICK, func(v: float) -> void:
		_set_thickness(v))
	_panel.note(glass, "Its top stays where it is; it grows downward, past the deck's underside beyond 0.20 m. Real glass floors are about 4 cm. The bounce methods leak light through anything thinner than their cells; VoxelGI is baked again when this comes to rest.")
	_glass_gi_box = _panel.box(glass)
	_panel.switch(_glass_gi_box, "In the bounce", true, func(on: bool) -> void:
		_glass_pane.gi_mode = GeometryInstance3D.GI_MODE_STATIC if on else GeometryInstance3D.GI_MODE_DYNAMIC
		if _bounce == "VoxelGI":
			_set_bounce("VoxelGI"))
	_panel.note(_glass_gi_box, "Whether VoxelGI and SDFGI see the pane. On, they find it solid and the lamp's light blocked, as the shadows do; off, the lamp's light still bounces in the room as if there were no glass. VoxelGI is baked again when this changes.")

	var view := _panel.panel("Viewport")
	_panel.note(view, "Settings of the viewport, the image the camera renders into, not of the scene.")
	_panel.switch(view, "Dithering (1)", vp.use_debanding, func(on: bool) -> void: vp.use_debanding = on)
	_panel.note(view, "Adds a faint noise to each pixel before it is stored at 8 bits a channel, which breaks the rings in smooth gradients into grain too fine to see.")
	_atlas_button = _panel.button(view, "", _next_atlas)
	_panel.note(view, "The texture all point and spot lights' shadow maps share. Larger gives the lamp's shadows finer edges and costs video memory.")


## Two estimates of the same bounce light, so one at a time.
func _set_bounce(option: String) -> void:
	_bounce = option
	_env.sdfgi_enabled = option == "SDFGI"
	if _voxel_gi != null:
		_voxel_gi.queue_free()
		_voxel_gi = null
	if option == "VoxelGI":
		_voxel_gi = VoxelGI.new()
		_voxel_gi.subdiv = _voxel_subdiv
		_voxel_gi.size = Vector3(ROOM + 1.0, ROOM - CHAMBER_FLOOR + 1.0, ROOM + 1.0)
		_voxel_gi.position.y = (ROOM + CHAMBER_FLOOR) * 0.5
		add_child(_voxel_gi)
		_voxel_gi.bake()
	_refresh()


## Dim what has no effect now, and say where the light comes from.
func _refresh() -> void:
	if _status == null:
		return
	_panel.enable(_bounce_box, _bounce != "None")
	_panel.enable(_indirect_box, _bounce != "None")
	_panel.enable(_sdfgi_box, _bounce == "SDFGI")
	_panel.enable(_voxel_box, _bounce == "VoxelGI")
	_panel.enable(_glass_gi_box, _bounce != "None")
	var text := ""
	match _bounce:
		"None":
			text = "Only the lamp lights the room; what it cannot reach is black."
		"SDFGI":
			text = "SDFGI: the lamp's light bounces off every surface."
		"VoxelGI":
			text = "VoxelGI: the lamp's light bounces inside the box around the room and the chamber."
	if _env.ssil_enabled:
		text += " SSIL adds light from what is in view."
	if _env.ssao_enabled:
		text += " SSAO has nothing to darken." if _bounce == "None" else " SSAO darkens it in corners."
	_status.text = text


func _next_atlas() -> void:
	var vp := get_viewport()
	var i := ATLAS_SIZES.find(vp.positional_shadow_atlas_size)
	vp.positional_shadow_atlas_size = ATLAS_SIZES[(i + 1) % ATLAS_SIZES.size()]
	_show_atlas()
	_panel.extra["atlas"] = vp.positional_shadow_atlas_size
	_panel.changed()


func _show_atlas() -> void:
	_atlas_button.text = "Shadow atlas: %d (2)" % get_viewport().positional_shadow_atlas_size


## Every control back as the scene opened.
func _reset() -> void:
	var vp := get_viewport()
	(_panel.switches["Dithering (1)"] as CheckButton).button_pressed = _was["debanding"]
	vp.positional_shadow_atlas_size = _was["atlas"]
	_panel.extra["atlas"] = _was["atlas"]
	_show_atlas()
	var picker := _panel.pickers["Colour"] as ColorPickerButton
	picker.color = LAMP_COLOUR
	picker.color_changed.emit(LAMP_COLOUR)
	(_panel.sliders["Energy"] as HSlider).value = LAMP_ENERGY
	(_panel.sliders["Indirect energy"] as HSlider).value = 1.0
	(_panel.switches["Half resolution"] as CheckButton).button_pressed = true
	(_panel.sliders["SDFGI smallest cell (m)"] as HSlider).value = 0.2
	(_panel.switches["SSIL"] as CheckButton).button_pressed = false
	(_panel.switches["SSAO"] as CheckButton).button_pressed = false
	_panel.pick("VoxelGI quality", "Low")
	_panel.pick("VoxelGI cells", "64")
	(_panel.sliders["Thickness (m)"] as HSlider).value = GLASS_THICK
	_panel.pick("Curve", "AgX")
	_panel.pick("Bounce", "VoxelGI")
	(_panel.sliders["Opacity"] as HSlider).value = GLASS_ALPHA
	var tint := _panel.pickers["Tint"] as ColorPickerButton
	tint.color = GLASS_TINT
	tint.color_changed.emit(GLASS_TINT)
	(_panel.sliders["Roughness"] as HSlider).value = 0.05
	(_panel.sliders["Specular"] as HSlider).value = 0.5
	(_panel.switches["In the bounce"] as CheckButton).button_pressed = true
	_refresh()


## ---- the room --------------------------------------------------------------

## The ceiling and four walls in matte plaster, and the chamber under the
## whole room, its walls continuing the room's down to its floor, painted
## dark.
func _build_room() -> void:
	var h := ROOM * 0.5
	var plaster := StandardMaterial3D.new()
	plaster.albedo_color = Color(0.80, 0.78, 0.74)
	plaster.roughness = 0.9
	_slab_between(Vector3(-h - WALL, ROOM, -h - WALL), Vector3(h + WALL, ROOM + WALL, h + WALL), plaster)
	_slab_between(Vector3(h, 0.0, -h), Vector3(h + WALL, ROOM, h), plaster)
	_slab_between(Vector3(-h - WALL, 0.0, -h), Vector3(-h, ROOM, h), plaster)
	_slab_between(Vector3(-h - WALL, 0.0, h), Vector3(h + WALL, ROOM, h + WALL), plaster)
	_slab_between(Vector3(-h - WALL, 0.0, -h - WALL), Vector3(h + WALL, ROOM, -h), plaster)

	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(CHAMBER_ALBEDO, CHAMBER_ALBEDO, CHAMBER_ALBEDO)
	dark.roughness = 0.9
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR - WALL, -h - WALL), Vector3(h + WALL, CHAMBER_FLOOR, h + WALL), dark)
	_slab_between(Vector3(h, CHAMBER_FLOOR, -h - WALL), Vector3(h + WALL, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR, -h - WALL), Vector3(-h, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, h), Vector3(h, 0.0, h + WALL), dark)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, -h - WALL), Vector3(h, 0.0, -h), dark)


## ---- the deck --------------------------------------------------------------

## The deck is a concrete slab faced with stone tiles, round the opening
## and open also over the stair along the south wall.
func _build_deck() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.30, 0.30, 0.29)
	concrete.roughness = 0.9
	_deck_layer(-TILE, 0.0, _stone())
	_deck_layer(SLAB_BOTTOM, -TILE, concrete)
	_build_stair(concrete)


## One layer of the deck, from y0 to y1.
func _deck_layer(y0: float, y1: float, mat: Material) -> void:
	var h := ROOM * 0.5
	var x0 := OPENING_CENTRE.x - OPENING_HALF
	var x1 := OPENING_CENTRE.x + OPENING_HALF
	var z0 := OPENING_CENTRE.y - OPENING_HALF
	var z1 := OPENING_CENTRE.y + OPENING_HALF
	_slab_between(Vector3(-h, y0, -h), Vector3(x0, y1, z1), mat)
	_slab_between(Vector3(x1, y0, -h), Vector3(h, y1, z1), mat)
	_slab_between(Vector3(x0, y0, -h), Vector3(x1, y1, z0), mat)
	_slab_between(Vector3(-h, y0, z1), Vector3(h, y1, STAIR_Z), mat)
	_slab_between(Vector3(-h, y0, STAIR_Z), Vector3(HOLE_WEST, y1, h), mat)
	_slab_between(Vector3(STAIR_TOP, y0, STAIR_Z), Vector3(h, y1, h), mat)


## The stair down to the chamber: solid concrete steps against the south
## wall, a railing up their open side, and a railing round the opening
## above. The steps are drawn; what the player walks on is a ramp through
## their front edges, since a body that slides cannot climb a step.
func _build_stair(concrete: Material) -> void:
	var h := ROOM * 0.5
	var rise := -CHAMBER_FLOOR / RISERS
	var width := h - STAIR_Z
	for i in range(1, RISERS):
		var x1 := STAIR_TOP - (i - 1) * GOING
		var y1 := -i * rise
		_shape(Vector3(x1 - GOING * 0.5, (CHAMBER_FLOOR + y1) * 0.5, STAIR_Z + width * 0.5),
			Vector3(GOING, y1 - CHAMBER_FLOOR, width), concrete)
	var foot := STAIR_TOP - (RISERS - 1) * GOING
	var run := STAIR_TOP - foot
	var angle := atan2(-CHAMBER_FLOOR, run)
	var dir := Vector3(cos(angle), sin(angle), 0.0)
	var normal := Vector3(-sin(angle), cos(angle), 0.0)
	# From the deck's edge to 0.3 m past the foot, buried in the floor
	# there, so the walk off is smooth.
	var length := Vector2(run, -CHAMBER_FLOOR).length() + 0.3
	var mid := Vector3((STAIR_TOP + foot) * 0.5, CHAMBER_FLOOR * 0.5, STAIR_Z + width * 0.5) - dir * 0.15
	_solid(mid - normal * 0.1, Vector3(length, 0.2, width), Basis(Vector3.BACK, angle))
	var steel := _steel()
	_stair_rail(Vector3(STAIR_TOP, 0.0, STAIR_Z + 0.03), Vector3(foot, CHAMBER_FLOOR, STAIR_Z + 0.03), steel)
	_railing(Vector3(HOLE_WEST, 0.0, STAIR_Z - 0.03), Vector3(STAIR_TOP, 0.0, STAIR_Z - 0.03), steel)
	_railing(Vector3(HOLE_WEST - 0.03, 0.0, STAIR_Z), Vector3(HOLE_WEST - 0.03, 0.0, h), steel)


## A railing a metre high from a to b on the deck: posts no more than
## 1.2 m apart, a top rail and a middle rail, solid to its full height.
func _railing(a: Vector3, b: Vector3, mat: Material) -> void:
	var along := b - a
	var length := along.length()
	var across := along.x == 0.0
	var posts := int(ceil(length / 1.2)) + 1
	for i in posts:
		var p := a + along * (float(i) / (posts - 1))
		_shape(p + Vector3(0.0, 0.5, 0.0), Vector3(0.04, 1.0, 0.04), mat)
	for y: float in [0.5, 1.0]:
		var size := Vector3(0.04, 0.04, length) if across else Vector3(length, 0.04, 0.04)
		_shape((a + b) * 0.5 + Vector3(0.0, y, 0.0), size, mat)
	var wall := Vector3(0.05, 1.0, length) if across else Vector3(length, 1.0, 0.05)
	_solid((a + b) * 0.5 + Vector3(0.0, 0.5, 0.0), wall, Basis.IDENTITY)


## The railing up the stair's open side, from a at the top to b at the
## foot along the line of the steps' front edges: posts no more than
## 1.2 m apart, a handrail 0.9 m over that line, solid a metre up.
func _stair_rail(a: Vector3, b: Vector3, mat: Material) -> void:
	var along := a - b
	var length := along.length()
	var angle := atan2(along.y, along.x)
	var basis := Basis(Vector3.BACK, angle)
	var posts := int(ceil(length / 1.2)) + 1
	for i in posts:
		var p := b + along * (float(i) / (posts - 1))
		_shape(p + Vector3(0.0, 0.45, 0.0), Vector3(0.04, 0.9, 0.04), mat)
	var rail := _shape((a + b) * 0.5 + Vector3(0.0, 0.9, 0.0), Vector3(length, 0.04, 0.04), mat)
	rail.basis = basis
	_solid((a + b) * 0.5 + Vector3(0.0, 0.5, 0.0), Vector3(length, 1.0, 0.05), basis)


func _steel() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.18, 0.18, 0.19)
	m.metallic = 0.7
	m.roughness = 0.4
	return m


## Limestone tiles, laid in world space so the slabs' tiles line up.
func _stone() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://textures/ambientcg_tiles142/albedo.png")
	m.normal_enabled = true
	m.normal_texture = load("res://textures/ambientcg_tiles142/normal.png")
	m.roughness_texture = load("res://textures/ambientcg_tiles142/roughness.png")
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / 2.0
	return m


## ---- boxes -----------------------------------------------------------------

## A box drawn and solid.
func _slab(centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := _shape(centre, size, mat)
	_solid(centre, size, Basis.IDENTITY)
	return mi


## A slab between two corners.
func _slab_between(lo: Vector3, hi: Vector3, mat: Material) -> void:
	_slab((lo + hi) * 0.5, hi - lo, mat)


## A box drawn only.
func _shape(centre: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var box := BoxMesh.new()
	box.size = size
	var mi := MeshInstance3D.new()
	mi.mesh = box
	mi.material_override = mat
	mi.position = centre
	add_child(mi)
	return mi


## A box solid only.
func _solid(centre: Vector3, size: Vector3, basis: Basis) -> void:
	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	shape.shape = bs
	body.add_child(shape)
	body.transform = Transform3D(basis, centre)
	add_child(body)


## ---- the glass -------------------------------------------------------------

## One opaque pane across the opening, its edges in the deck's sides,
## solid; the second camera that sees past it; the area light that stands
## for the lamp's light through it.
func _build_glass() -> void:
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = load("res://world/pool_glass.gdshader")
	_glass_mat.set_shader_parameter("tint", GLASS_TINT)
	_glass_mat.set_shader_parameter("opacity", GLASS_ALPHA)
	var size := Vector3(2.0 * OPENING_HALF, GLASS_THICK, 2.0 * OPENING_HALF)
	var centre := Vector3(OPENING_CENTRE.x, GLASS_TOP - GLASS_THICK * 0.5, OPENING_CENTRE.y)
	_glass_pane = _shape(centre, size, _glass_mat)
	_glass_box = _glass_pane.mesh as BoxMesh
	_glass_body = StaticBody3D.new()
	var shape := CollisionShape3D.new()
	_glass_shape = BoxShape3D.new()
	_glass_shape.size = size
	shape.shape = _glass_shape
	_glass_body.add_child(shape)
	_glass_body.position = centre
	add_child(_glass_body)
	_glass_pane.layers = PANE
	_glass_pane.gi_mode = GeometryInstance3D.GI_MODE_STATIC

	_portal = SubViewport.new()
	_portal.use_hdr_2d = true
	_portal.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	_portal_cam = Camera3D.new()
	_portal_cam.cull_mask = 0xFFFFF & ~PANE
	_portal_env = _env.duplicate() as Environment
	_portal_env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	_portal_env.tonemap_exposure = 1.0
	_portal_cam.environment = _portal_env
	_portal.add_child(_portal_cam)
	add_child(_portal)
	_portal_cam.current = true
	_glass_mat.set_shader_parameter("behind", _portal.get_texture())

	_through = AreaLight3D.new()
	_through.area_size = Vector2(2.0 * OPENING_HALF, 2.0 * OPENING_HALF)
	_through.area_range = 40.0
	_through.area_attenuation = 2.0
	_through.light_color = LAMP_COLOUR
	_through.light_cull_mask = 0xFFFFF & ~PANE
	# No shadows: Godot's area-light shadows drew wing-shaped dark patches
	# in the room's corners. Without them the foot of the walls gets a
	# little light the deck's rim would block.
	_through.shadow_enabled = false
	add_child(_through)
	_through.global_transform = Transform3D(Basis.looking_at(Vector3.UP, Vector3.BACK),
		Vector3(OPENING_CENTRE.x, GLASS_TOP + 0.01, OPENING_CENTRE.y))
	_set_through()


## The pane's thickness, its top fixed: drawn, solid and, coming to rest,
## baked again into VoxelGI.
func _set_thickness(t: float) -> void:
	_thickness = t
	_glass_box.size.y = t
	_glass_shape.size.y = t
	var y := GLASS_TOP - t * 0.5
	_glass_pane.position.y = y
	_glass_body.position.y = y
	if _bounce == "VoxelGI":
		_rebake_in = 0.5


## The light through the glass: the lamp's energy times what the glass
## lets through.
func _set_through() -> void:
	if _through == null or _light == null:
		return
	_through.light_energy = _light.light_energy * (1.0 - _opacity) * THROUGH_SCALE


## Each frame: the second camera where the eye is, with the same lens, at
## the screen's size, its environment following the room's lighting
## choices (the tone curve stays Linear).
func _follow_eye() -> void:
	var eye := get_viewport().get_camera_3d()
	if eye == null:
		return
	var screen := Vector2i(get_viewport().get_visible_rect().size)
	if _portal.size != screen:
		_portal.size = screen
	_portal.positional_shadow_atlas_size = get_viewport().positional_shadow_atlas_size
	_portal_cam.global_transform = eye.global_transform
	_portal_cam.fov = eye.fov
	_portal_cam.near = eye.near
	_portal_cam.far = eye.far
	_portal_env.sdfgi_enabled = _env.sdfgi_enabled
	_portal_env.sdfgi_min_cell_size = _env.sdfgi_min_cell_size
	_portal_env.ssil_enabled = _env.ssil_enabled
	_portal_env.ssao_enabled = _env.ssao_enabled


func _process(delta: float) -> void:
	_follow_eye()
	if _rebake_in >= 0.0:
		_rebake_in -= delta
		if _rebake_in < 0.0 and _bounce == "VoxelGI":
			_set_bounce("VoxelGI")


## ---- the lamp --------------------------------------------------------------

## The lamp: a bare bulb on a slim steel stand from the chamber floor.
func _build_lamp() -> void:
	var steel := _steel()
	var stem_h := LAMP.y - 0.06 - CHAMBER_FLOOR
	var stem := CylinderMesh.new()
	stem.top_radius = 0.012
	stem.bottom_radius = 0.012
	stem.height = stem_h
	var base := CylinderMesh.new()
	base.top_radius = 0.14
	base.bottom_radius = 0.15
	base.height = 0.02
	for part: Array in [[stem, CHAMBER_FLOOR + stem_h * 0.5], [base, CHAMBER_FLOOR + 0.01]]:
		var mesh: CylinderMesh = part[0]
		mesh.material = steel
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.position = Vector3(LAMP.x, part[1], LAMP.z)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	_solid(Vector3(LAMP.x, CHAMBER_FLOOR + 0.5, LAMP.z), Vector3(0.3, 1.0, 0.3), Basis.IDENTITY)
	var light := OmniLight3D.new()
	_light = light
	light.position = LAMP
	light.light_color = LAMP_COLOUR
	light.light_energy = LAMP_ENERGY
	light.omni_range = 40.0
	light.omni_attenuation = 2.0
	light.shadow_enabled = true
	add_child(light)
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1, 1, 1)
	glow.emission_enabled = true
	glow.emission = LAMP_COLOUR
	glow.emission_energy_multiplier = BULB_GLOW
	_glass = glow
	var bulb := SphereMesh.new()
	bulb.radius = 0.06
	bulb.height = 0.12
	bulb.material = glow
	var mi := MeshInstance3D.new()
	mi.mesh = bulb
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	light.add_child(mi)
