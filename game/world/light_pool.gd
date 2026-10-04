class_name LightPool
extends Node3D
## A closed room ten metres every way. Most of its floor is an opening
## 7.5 m square onto a chamber under the whole room, lit by one bare
## lamp on a stand. The lamp is the only light, so the room is lit from
## below through the opening: the ceiling brightest, the walls fading
## downward, the deck around the opening in the room's own reflected
## light. A stair along the south wall goes down into the chamber.
## Across the opening, 35 cm below the deck, lies one pane of glass 4 cm
## thick, set into the deck's sides all round, solid to walk on. Two
## large panels, 8 m by 4.5 m, hang on the north and west walls, their
## bottom edges 3 m above the deck: a moving relief of gold ridges on
## matte metal (relief_panel.gdshader, custom), shown by shading alone on
## the north wall and by real moving geometry on the west. A bare bulb
## hangs from the room's ceiling on a cord, switched by a wall switch
## (WallSwitch, E to use) on the east wall by the stair. A reflection
## probe photographs the room for its shiny surfaces to reflect.
##
## Drawn by the engine's own lighting (an omni light with shadows and
## standard materials, in an environment with a black background, no
## ambient light, no sky reflections and no glow), with two stand-ins
## for the glass, described below: a custom shader that shows what lies
## behind the opaque pane, and a second spot light at the lamp for the
## light through it.
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
## specular, and its thickness (top fixed, growing downward); and the
## water on it: ripple strength, size and speed, and how far the picture
## behind bends. Light: also VoxelGI's cells along its box's
## longest side (64 to begin; light leaks through anything thinner than
## a cell).
##
## The glass is opaque: it casts a full shadow and blocks the lamp from
## the room. It is seen through by a second camera at the eye (`_portal`,
## a SubViewport sharing the world, matched to the eye's camera each
## frame) that renders the scene without the pane (the pane is on render
## layer PANE, which that camera does not see); the pane's shader
## (pool_glass.gdshader, custom) gives off that picture's light at each
## pixel, filtered by the tint, times 1 minus the opacity. The picture is untonemapped (the
## second camera's environment is the room's with the Linear curve), so
## the screen's tone curve applies once. Ripples, as of a thin film of
## water, tilt the pane's surface and shift the picture behind it (see the
## shader); two engine-made noise normal maps slide across it, moved here.
## The light the glass would let
## through is a second spot light at the lamp's own place, pointing up
## through the opening (`_through`): it lights only the room (the
## chamber's surfaces and the pane are on render layers it is told to
## leave alone, CHAMBER and PANE), and the pane casts no shadow for it
## (`shadow_caster_mask`), so it lights the room as the bulb would through
## clear glass, with the bulb's falloff and its sharp shadows; its colour
## is the lamp's times the tint, its energy the lamp's times 1 minus the
## opacity.
## shadows. The pane is always in the bounce (GI mode Static), so the
## bounce methods find the lamp's light blocked, as the shadow does; the
## picture it shows lights nothing. Dithering, the atlas, half
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
const BRICK := Vector2(1.8, 0.9)       # m of wall to one repeat of the old stone bricks, across and up
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
# Ripples on the glass: two noise normal maps sliding across it.
const RIPPLE_SIZE := 1.5               # m of pane to one repeat of a map
const RIPPLE_SPEED := 0.15             # m/s, the first map; the second at 0.8 of it
const RIPPLE_STRENGTH := 0.3
const RIPPLE_BEND := 0.02
const RIPPLE_DIRS: Array[Vector2] = [Vector2(0.8, 0.6), Vector2(-0.5, 0.87)]
# The relief panels.
const RELIEF_SIZE := Vector2(8.0, 4.5)
const RELIEF_BOTTOM := 3.0             # m above the deck
const RELIEF_GRID := Vector2i(400, 225) # vertices across and up the moving one
const RELIEF_SPEED := 0.15             # noise cells a second through time
# The ceiling bulb, its cord, and its switch.
const CEILING_BULB := Vector3(0.0, 8.0, -0.5)  # 2 m below the ceiling, over the opening's middle
const CEILING_BULB_ENERGY := 20.0
const SWITCH_AT := Vector3(4.97, 1.2, 2.6)    # on the east wall, beside the stair's top
const PANE := 2                        # render layer of the glass, unseen by the second camera
const CHAMBER := 4                     # render layer of what lies in the chamber, unlit by the light through the glass
const THROUGH_ANGLE := 72.0            # degrees: the spot's half-angle, past the opening's corners (69) seen from the lamp

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
var _portal: SubViewport
var _portal_cam: Camera3D
var _portal_env: Environment
var _through: SpotLight3D
var _layer := 1                         # the render layer _shape gives what it makes
var _opacity := GLASS_ALPHA
var _tint := GLASS_TINT
var _ripple_offsets: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]
var _ripple_speed := RIPPLE_SPEED
var _ripple_size := RIPPLE_SIZE
var _lamp_colour := LAMP_COLOUR
var _thickness := GLASS_THICK
var _glass_box: BoxMesh
var _glass_shape: BoxShape3D
var _glass_body: StaticBody3D
var _voxel_subdiv := VoxelGI.SUBDIV_64
var _bulb_light: OmniLight3D
var _bulb_glass: StandardMaterial3D
var _switch: WallSwitch
var _probe: ReflectionProbe
var _probe_frames := 0                  # frames left of a re-photograph; 0, none
var _relief_mats: Array[ShaderMaterial] = []
var _relief_phase := 0.0
var _relief_speed := RELIEF_SPEED
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
	_build_reliefs()
	_build_ceiling_bulb()
	_build_probe()
	_build_panels()
	RenderingServer.gi_set_use_half_resolution(true)
	RenderingServer.voxel_gi_set_quality(RenderingServer.VOXEL_GI_QUALITY_LOW)
	_set_bounce("VoxelGI")
	var extra := _panel.restore()
	_rephotograph()
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
		_lamp_colour = c
		_set_through_colour()
		_rephotograph())
	_panel.slider(lamp, "Energy", 0.0, 200.0, 1.0, LAMP_ENERGY, func(v: float) -> void:
		_light.light_energy = v
		_glass.emission_energy_multiplier = BULB_GLOW * v / LAMP_ENERGY
		_set_through()
		_rephotograph())
	_panel.note(lamp, "The light's strength, in its direct light and in the bounce alike. The glowing glass follows the colour and the energy; it is drawn and lights nothing.")
	_indirect_box = _panel.box(lamp)
	_panel.slider(_indirect_box, "Indirect energy", 0.0, 4.0, 0.01, 1.0, func(v: float) -> void:
		_light.light_indirect_energy = v)
	_panel.note(_indirect_box, "A second multiplier on the lamp's light as it enters the bounce only: the bounce starts from Energy times this. 1 is the physical value; 0 shows the direct light alone.")
	_panel.heading(lamp, "Ceiling bulb")
	_panel.switch(lamp, "Ceiling bulb on", false, func(on: bool) -> void:
		if _switch.on != on:
			_switch.set_on(on))
	_panel.note(lamp, "Also the switch on the east wall by the stair: look at it and press E.")
	_panel.colour(lamp, "Bulb colour", LAMP_COLOUR, func(c: Color) -> void:
		_bulb_light.light_color = c
		_bulb_glass.emission = c
		_rephotograph())
	_panel.slider(lamp, "Bulb energy", 0.0, 100.0, 1.0, CEILING_BULB_ENERGY, func(v: float) -> void:
		_bulb_light.light_energy = v
		_bulb_glass.emission_energy_multiplier = BULB_GLOW * v / LAMP_ENERGY
		_rephotograph())
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
	_panel.heading(light, "Reflections")
	_panel.switch(light, "Reflection probe", true, func(on: bool) -> void:
		_probe.visible = on)
	_panel.note(light, "A reflection probe photographs the room in every direction from its middle; shiny surfaces reflect that photograph, corrected for the room's box shape. Metal, which shows only what it reflects, needs it most.")
	_panel.choice(light, "Probe photographs", ["Once", "Always"], "Once", func(option: String) -> void:
		_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS if option == "Always" else ReflectionProbe.UPDATE_ONCE)
	_panel.note(light, "Once: taken when the lighting changes (a switch, a slider), so moving things, like the relief, reflect as they were then. Always: taken every frame, costly.")
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
		_set_through()
		_rephotograph())
	_panel.note(glass, "The pane is opaque. It gives off the second camera's picture of what lies behind it times 1 minus this, filtered by the tint, and shows its own colour times this. The light through it is a second light at the lamp that lights only the room, at the lamp's light filtered by the tint, times 1 minus this.")
	_panel.heading(glass, "Water on the glass")
	_panel.slider(glass, "Ripple strength", 0.0, 1.0, 0.01, RIPPLE_STRENGTH, func(v: float) -> void:
		_glass_mat.set_shader_parameter("ripple_strength", v))
	_panel.note(glass, "How steep the ripples are. 0 is still water. Their slope tilts the surface, so its highlights ripple, and shifts the picture behind it, as water bends what is seen through it.")
	_panel.slider(glass, "Ripple size (m)", 0.2, 5.0, 0.05, RIPPLE_SIZE, func(v: float) -> void:
		_ripple_size = v
		_glass_mat.set_shader_parameter("ripple_size", v))
	_panel.slider(glass, "Ripple speed (m/s)", 0.0, 1.0, 0.01, RIPPLE_SPEED, func(v: float) -> void:
		_ripple_speed = v)
	_panel.note(glass, "Two patterns of engine-made noise slide across the pane in different directions; size is metres to one repeat of a pattern.")
	_panel.slider(glass, "Picture bend", 0.0, 0.1, 0.001, RIPPLE_BEND, func(v: float) -> void:
		_glass_mat.set_shader_parameter("bend", v))
	_panel.note(glass, "How far the picture behind shifts per unit of slope, as a share of the screen. Real water bends far things further than near ones; the picture holds no depth, so here all shift alike.")
	_panel.heading(glass, "Glass")
	_panel.colour(glass, "Tint", GLASS_TINT, func(c: Color) -> void:
		_glass_mat.set_shader_parameter("tint", c)
		_tint = c
		_set_through_colour()
		_rephotograph())
	_panel.slider(glass, "Roughness", 0.0, 1.0, 0.01, 0.05, func(v: float) -> void:
		_glass_mat.set_shader_parameter("roughness", v))
	_panel.note(glass, "How widely its reflections spread; polished glass is near 0.")
	_panel.slider(glass, "Specular", 0.0, 1.0, 0.01, 0.5, func(v: float) -> void:
		_glass_mat.set_shader_parameter("specular", v))
	_panel.note(glass, "Reflection strength face on; 0.5 is about 4%, as for glass. Stronger toward grazing angles by the engine's Fresnel term.")
	_panel.slider(glass, "Thickness (m)", 0.01, 0.5, 0.01, GLASS_THICK, func(v: float) -> void:
		_set_thickness(v))
	_panel.note(glass, "Its top stays where it is; it grows downward, past the deck's underside beyond 0.20 m. Real glass floors are about 4 cm. The bounce methods leak light through anything thinner than their cells; VoxelGI is baked again when this comes to rest.")

	var relief := _panel.panel("Relief")
	_panel.note(relief, "Two panels with the same moving relief. North wall: the panel is flat and only its shading follows the hills, so it looks raised in the light but has a flat outline and casts no shadows. West wall: the panel is a fine mesh moved out by the hills, so the outline and shadows are real.")
	_panel.slider(relief, "Speed", 0.0, 1.0, 0.01, RELIEF_SPEED, func(v: float) -> void:
		_relief_speed = v)
	_panel.note(relief, "How fast the hills change: noise cells a second, moving through time.")
	_panel.slider(relief, "Feature size (m)", 0.1, 2.0, 0.01, 0.6, func(v: float) -> void:
		_set_relief("feature_size", v))
	_panel.slider(relief, "Height (cm)", 0.0, 20.0, 0.1, 5.0, func(v: float) -> void:
		_set_relief("height", v / 100.0))
	_panel.note(relief, "From the lowest point to the highest. On the west panel it moves the surface; on both it sets how steep the shading's slopes are.")
	_panel.slider(relief, "Gold above", 0.0, 1.0, 0.01, 0.6, func(v: float) -> void:
		_set_relief("threshold", v))
	_panel.note(relief, "The height, 0 lowest to 1 highest, above which the surface is gold.")
	_panel.slider(relief, "Gold roughness", 0.0, 1.0, 0.01, 0.15, func(v: float) -> void:
		_set_relief("gold_roughness", v))
	_panel.slider(relief, "Base roughness", 0.0, 1.0, 0.01, 0.6, func(v: float) -> void:
		_set_relief("base_roughness", v))
	_panel.note(relief, "Both are metal: they show almost no colour of their own, only what they reflect, tinted. With nothing bright to reflect, they look dark.")

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
	(_panel.sliders["Ripple strength"] as HSlider).value = RIPPLE_STRENGTH
	(_panel.sliders["Ripple size (m)"] as HSlider).value = RIPPLE_SIZE
	(_panel.sliders["Ripple speed (m/s)"] as HSlider).value = RIPPLE_SPEED
	(_panel.sliders["Picture bend"] as HSlider).value = RIPPLE_BEND
	(_panel.sliders["Speed"] as HSlider).value = RELIEF_SPEED
	(_panel.switches["Ceiling bulb on"] as CheckButton).button_pressed = false
	var bulb_picker := _panel.pickers["Bulb colour"] as ColorPickerButton
	bulb_picker.color = LAMP_COLOUR
	bulb_picker.color_changed.emit(LAMP_COLOUR)
	(_panel.sliders["Bulb energy"] as HSlider).value = CEILING_BULB_ENERGY
	(_panel.switches["Reflection probe"] as CheckButton).button_pressed = true
	_panel.pick("Probe photographs", "Once")
	(_panel.sliders["Feature size (m)"] as HSlider).value = 0.6
	(_panel.sliders["Height (cm)"] as HSlider).value = 5.0
	(_panel.sliders["Gold above"] as HSlider).value = 0.6
	(_panel.sliders["Gold roughness"] as HSlider).value = 0.15
	(_panel.sliders["Base roughness"] as HSlider).value = 0.6
	_panel.pick("Curve", "AgX")
	_panel.pick("Bounce", "VoxelGI")
	(_panel.sliders["Opacity"] as HSlider).value = GLASS_ALPHA
	var tint := _panel.pickers["Tint"] as ColorPickerButton
	tint.color = GLASS_TINT
	tint.color_changed.emit(GLASS_TINT)
	(_panel.sliders["Roughness"] as HSlider).value = 0.05
	(_panel.sliders["Specular"] as HSlider).value = 0.5
	_refresh()


## ---- the room --------------------------------------------------------------

## The room's ceiling and four walls and the chamber's walls in old
## stone bricks, the chamber's floor in wet pebbles. The bricks are laid
## in world space (triplanar), 1.8 m of the texture across and 0.9 m up
## the walls; a ceiling's material turns that the other way, since a
## horizontal face reads the texture's second axis along z.
func _build_room() -> void:
	var h := ROOM * 0.5
	var bricks := _textured("old_stone_bricks", BRICK, false, false)
	var overhead := _textured("old_stone_bricks", BRICK, false, true)
	_slab_between(Vector3(-h - WALL, ROOM, -h - WALL), Vector3(h + WALL, ROOM + WALL, h + WALL), overhead)
	_slab_between(Vector3(h, 0.0, -h), Vector3(h + WALL, ROOM, h), bricks)
	_slab_between(Vector3(-h - WALL, 0.0, -h), Vector3(-h, ROOM, h), bricks)
	_slab_between(Vector3(-h - WALL, 0.0, h), Vector3(h + WALL, ROOM, h + WALL), bricks)
	_slab_between(Vector3(-h - WALL, 0.0, -h - WALL), Vector3(h + WALL, ROOM, -h), bricks)

	var pebbles := _textured("pebbles", Vector2(1.0, 1.0), true, false)
	_layer = CHAMBER
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR - WALL, -h - WALL), Vector3(h + WALL, CHAMBER_FLOOR, h + WALL), pebbles)
	_slab_between(Vector3(h, CHAMBER_FLOOR, -h - WALL), Vector3(h + WALL, 0.0, h + WALL), bricks)
	_slab_between(Vector3(-h - WALL, CHAMBER_FLOOR, -h - WALL), Vector3(-h, 0.0, h + WALL), bricks)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, h), Vector3(h, 0.0, h + WALL), bricks)
	_slab_between(Vector3(-h, CHAMBER_FLOOR, -h - WALL), Vector3(h, 0.0, -h), bricks)
	_layer = 1


## ---- the deck --------------------------------------------------------------

## The deck is a slab faced with the generated tiles, round the opening
## and open also over the stair along the south wall. Below the facing
## it is old stone bricks, so the chamber's ceiling and the opening's
## sides are brick, laid as for a ceiling; the stair stays concrete.
func _build_deck() -> void:
	var concrete := StandardMaterial3D.new()
	concrete.albedo_color = Color(0.30, 0.30, 0.29)
	concrete.roughness = 0.9
	_deck_layer(-TILE, 0.0, _textured("generated_tiles", Vector2(2.0, 2.0), false, false))
	var bricks := _textured("old_stone_bricks", BRICK, false, true)
	_deck_layer(GLASS_TOP, -TILE, bricks)
	_layer = CHAMBER
	_deck_layer(SLAB_BOTTOM, GLASS_TOP, bricks)
	_layer = 1
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
	_layer = CHAMBER
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
	_layer = 1
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


## A texture set from textures/<dir> (albedo, normal, roughness and AO,
## as the one-bulb scene's library has them), laid in world space so
## neighbouring slabs line up, `size` metres of world to one repeat:
## across and up a wall, or, `overhead`, across x and along z on a
## horizontal face. Wet, as the one-bulb scene's wet pebbles: the colour
## darkened to 0.65 and the roughness times 0.3.
func _textured(dir: String, size: Vector2, wet: bool, overhead: bool) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	var base := "res://textures/%s/" % dir
	var ext := "png" if ResourceLoader.exists(base + "albedo.png") else "jpg"
	m.albedo_texture = load(base + "albedo." + ext)
	m.normal_enabled = true
	m.normal_texture = load(base + "normal." + ext)
	m.roughness_texture = load(base + "roughness." + ext)
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	if ResourceLoader.exists(base + "ao." + ext):
		m.ao_enabled = true
		m.ao_texture = load(base + "ao." + ext)
		m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.y) if overhead \
		else Vector3(1.0 / size.x, 1.0 / size.y, 1.0 / size.x)
	if wet:
		m.albedo_color = Color(0.65, 0.65, 0.65)
		m.roughness = 0.3
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
	mi.layers = _layer
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
## solid; the second camera that sees past it; the spot light that
## stands for the lamp's light through it.
func _build_glass() -> void:
	_glass_mat = ShaderMaterial.new()
	_glass_mat.shader = load("res://world/pool_glass.gdshader")
	_glass_mat.set_shader_parameter("tint", GLASS_TINT)
	_glass_mat.set_shader_parameter("opacity", GLASS_ALPHA)
	_glass_mat.set_shader_parameter("ripple_size", RIPPLE_SIZE)
	_glass_mat.set_shader_parameter("ripple_strength", RIPPLE_STRENGTH)
	_glass_mat.set_shader_parameter("bend", RIPPLE_BEND)
	for i in 2:
		var noise := FastNoiseLite.new()
		noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		noise.seed = 7 + i
		noise.frequency = 0.01
		noise.fractal_octaves = 3
		var tex := NoiseTexture2D.new()
		tex.width = 512
		tex.height = 512
		tex.seamless = true
		tex.as_normal_map = true
		tex.bump_strength = 4.0
		tex.generate_mipmaps = true
		tex.noise = noise
		_glass_mat.set_shader_parameter("ripple_a" if i == 0 else "ripple_b", tex)
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

	_through = SpotLight3D.new()
	_through.spot_angle = THROUGH_ANGLE
	_through.spot_angle_attenuation = 0.01
	_through.spot_range = 40.0
	_through.spot_attenuation = 2.0
	_through.light_cull_mask = 0xFFFFF & ~(PANE | CHAMBER)
	_through.shadow_enabled = true
	_through.shadow_caster_mask = 0xFFFFF & ~PANE
	add_child(_through)
	_through.global_transform = Transform3D(Basis.looking_at(Vector3.UP, Vector3.BACK), LAMP)
	_set_through()
	_set_through_colour()


## The colour of the light through the glass: the lamp's filtered by the
## tint, multiplied in linear light.
func _set_through_colour() -> void:
	if _through == null:
		return
	var lamp := _lamp_colour.srgb_to_linear()
	var tint := _tint.srgb_to_linear()
	_through.light_color = Color(lamp.r * tint.r, lamp.g * tint.g, lamp.b * tint.b).linear_to_srgb()


## The ripple maps slide on, each by its speed this frame, the distance
## summed here so a change of speed never sends them back.
func _slide_ripples(delta: float) -> void:
	for i in 2:
		var speed := _ripple_speed * (1.0 if i == 0 else 0.8)
		_ripple_offsets[i] = (_ripple_offsets[i] + RIPPLE_DIRS[i] * speed * delta / _ripple_size).posmod(1.0)
	_glass_mat.set_shader_parameter("offset_a", _ripple_offsets[0])
	_glass_mat.set_shader_parameter("offset_b", _ripple_offsets[1])


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
	_through.light_energy = _light.light_energy * (1.0 - _opacity)


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
	_slide_ripples(delta)
	_relief_phase += _relief_speed * delta
	_set_relief("phase", _relief_phase)
	if _probe_frames > 0:
		_probe_frames -= 1
		if _probe_frames == 0 and (_panel.choices["Probe photographs"]["Once"] as CheckBox).button_pressed:
			_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	if _rebake_in >= 0.0:
		_rebake_in -= delta
		if _rebake_in < 0.0 and _bounce == "VoxelGI":
			_set_bounce("VoxelGI")


## ---- the relief panels ---------------------------------------------------

## The north wall's panel, flat with its shading following the relief,
## and the west wall's, a fine mesh the shader moves out by it; both 3 cm
## off their walls and lit by the bounce at their own places but not
## baked into it.
func _build_reliefs() -> void:
	var h := ROOM * 0.5
	var y := RELIEF_BOTTOM + RELIEF_SIZE.y * 0.5
	for moving in [false, true]:
		var mesh := PlaneMesh.new()
		mesh.orientation = PlaneMesh.FACE_Z
		mesh.size = RELIEF_SIZE
		if moving:
			mesh.subdivide_width = RELIEF_GRID.x - 2
			mesh.subdivide_depth = RELIEF_GRID.y - 2
		var mat := ShaderMaterial.new()
		mat.shader = load("res://world/relief_panel.gdshader")
		mat.set_shader_parameter("displace", moving)
		_relief_mats.append(mat)
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = mat
		mi.gi_mode = GeometryInstance3D.GI_MODE_DYNAMIC
		# The moving one's outline reaches past the flat mesh's bounds.
		mi.extra_cull_margin = 0.25
		add_child(mi)
		if moving:
			mi.position = Vector3(-h + 0.03, y, 0.0)
			mi.rotation_degrees.y = 90.0
		else:
			mi.position = Vector3(0.0, y, -h + 0.03)


func _set_relief(param: String, value: Variant) -> void:
	for mat in _relief_mats:
		mat.set_shader_parameter(param, value)


## ---- the ceiling bulb and its switch ----------------------------------------

## A bare bulb on a cord from the ceiling's middle, off to begin; its
## switch on the east wall.
func _build_ceiling_bulb() -> void:
	_bulb_light = OmniLight3D.new()
	_bulb_light.position = CEILING_BULB
	_bulb_light.light_color = LAMP_COLOUR
	_bulb_light.light_energy = CEILING_BULB_ENERGY
	_bulb_light.omni_range = 40.0
	_bulb_light.omni_attenuation = 2.0
	_bulb_light.shadow_enabled = true
	_bulb_light.light_cull_mask = 0xFFFFF & ~CHAMBER
	_bulb_light.visible = false
	add_child(_bulb_light)
	_bulb_glass = StandardMaterial3D.new()
	_bulb_glass.albedo_color = Color(1, 1, 1)
	_bulb_glass.emission_enabled = true
	_bulb_glass.emission = LAMP_COLOUR
	_bulb_glass.emission_energy_multiplier = BULB_GLOW * CEILING_BULB_ENERGY / LAMP_ENERGY
	var glass := SphereMesh.new()
	glass.radius = 0.06
	glass.height = 0.12
	glass.material = _bulb_glass
	var bulb := MeshInstance3D.new()
	bulb.mesh = glass
	bulb.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bulb.gi_mode = GeometryInstance3D.GI_MODE_DISABLED
	bulb.position = CEILING_BULB
	add_child(bulb)
	var cord_len := ROOM - CEILING_BULB.y - 0.06
	var cord := MeshInstance3D.new()
	var cord_mesh := CylinderMesh.new()
	cord_mesh.top_radius = 0.004
	cord_mesh.bottom_radius = 0.004
	cord_mesh.height = cord_len
	cord_mesh.material = _steel()
	cord.mesh = cord_mesh
	cord.position = CEILING_BULB + Vector3(0.0, 0.06 + cord_len * 0.5, 0.0)
	cord.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(cord)
	_switch = WallSwitch.new()
	_switch.position = SWITCH_AT
	_switch.rotation_degrees.y = -90.0
	add_child(_switch)
	_switch.toggled.connect(func(on: bool) -> void:
		_bulb_light.visible = on
		_bulb_glass.emission_energy_multiplier = (BULB_GLOW * _bulb_light.light_energy / LAMP_ENERGY) if on else 0.0
		(_panel.switches["Ceiling bulb on"] as CheckButton).set_pressed_no_signal(on)
		_panel.changed()
		_rephotograph())
	_bulb_glass.emission_energy_multiplier = 0.0


## ---- the reflection probe ----------------------------------------------------

## A probe the size of the room, taking its photograph from the middle
## at eye height and correcting reflections for the room's box (box
## projection); the room is closed, so nothing outside it is used
## (interior). It does not see the pane, whose picture is made for the
## eye's camera, so through the opening it photographs the chamber.
func _build_probe() -> void:
	_probe = ReflectionProbe.new()
	_probe.size = Vector3(ROOM, ROOM, ROOM)
	_probe.position = Vector3(0.0, ROOM * 0.5, 0.0)
	_probe.origin_offset = Vector3(0.0, 1.6 - ROOM * 0.5, 0.0)
	_probe.box_projection = true
	_probe.interior = true
	# No fading toward the box's faces: the box is the room, and the panels
	# sit 3 cm from its walls, where the default 1 m fade leaves almost
	# no reflection.
	_probe.blend_distance = 0.0
	_probe.cull_mask = 0xFFFFF & ~PANE
	_probe.update_mode = ReflectionProbe.UPDATE_ONCE
	add_child(_probe)


## Take the probe's photograph again after a lighting change, a few
## frames on so the change has reached the lighting: Godot has no call
## to retake a probe set to Once, so it is set to Always for those frames
## and back.
func _rephotograph() -> void:
	if _probe == null or _panel == null:
		return
	_probe.update_mode = ReflectionProbe.UPDATE_ALWAYS
	_probe_frames = 4


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
		mi.layers = CHAMBER
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
