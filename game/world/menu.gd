class_name MainMenu
extends Control
## The title screen: pick a world. Worlds are scenes the editor can Play
## directly, so nothing here is required. An entry with "last_look"
## opens that world in the look it was last seen in.

## Every button's width, in pixels.
const BUTTON_W := 940

const WORLDS: Array[Dictionary] = [
	{"title": "HARBOR TOWN", "note": "A 1940s Maine harbour town on the coast, in whatever weather you choose.",
		"scene": "res://world/town.tscn"},
	{"title": "MONROE COURTHOUSE", "note": "The Union County courthouse of 1886 on its square in Monroe, North Carolina, outside and in.",
		"scene": "res://world/courthouse.tscn"},
	{"title": "MARK TWAIN HOUSE", "note": "The Clemens house of 1874 on Farmington Avenue in Hartford, Connecticut, outside and in, as the family knew it in the 1880s.",
		"scene": "res://world/twain.tscn"},
	{"title": "MARK TWAIN HOUSE, FROM ITS DATA", "note": "The same house built by the general builder from its data file, for comparison; its outside only so far.",
		"scene": "res://world/twain_data.tscn"},
	{"title": "MIDDAUGH HOUSE", "note": "The Middaugh house of 1888 in Clarendon Hills, Illinois, built by the general builder from its survey drawings while the work is under way; its outside only so far.",
		"scene": "res://world/middaugh.tscn"},
	{"title": "FOREST MEADOW", "note": "A meadow in a summer wood with a brook running through it, from dawn mist to fireflies; a study in mood. Seen as it is, as a cartoon, painted, or as a model on a board: choose in the options (O).",
		"scene": "res://world/meadow.tscn", "last_look": "meadow"},
	{"title": "OPEN HILLS", "note": "Rolling hills of long grass under a wide sky, the wind running over them in gusts; a study in wind.",
		"scene": "res://world/grass_hills.tscn", "last_look": "hills"},
	{"title": "ONE BULB", "note": "A gray floor in the dark under a single bare bulb.",
		"scene": "res://world/bulb_void.tscn"},
	{"title": "LIGHT POOL", "note": "A closed white room open in its floor onto a dark chamber, lit only by a lamp below.",
		"scene": "res://world/light_pool.tscn"},
	{"title": "MOVEMENT", "note": "Open grassy hills under a clear sky, with nothing else in them; for trying out how you move.",
		"scene": "res://world/movement.tscn"},
]


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var back := ColorRect.new()
	back.color = Color(0.05, 0.055, 0.065)
	back.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	add_child(back)

	var column := VBoxContainer.new()
	column.set_anchors_and_offsets_preset(PRESET_CENTER)
	column.grow_horizontal = GROW_DIRECTION_BOTH
	column.grow_vertical = GROW_DIRECTION_BOTH
	column.add_theme_constant_override("separation", 2)
	add_child(column)

	var title := Label.new()
	title.text = "WORLDBUILDER"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 44)
	title.add_theme_color_override("font_color", Color(0.88, 0.90, 0.86))
	column.add_child(title)
	var sub := Label.new()
	sub.text = "real buildings, generated and checked"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(0.55, 0.58, 0.55))
	column.add_child(sub)
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 6)
	column.add_child(gap)

	var first: Button = null
	for world: Dictionary in WORLDS:
		var button := _world_button(world)
		column.add_child(button)
		if first == null:
			first = button
	var quit := Button.new()
	quit.text = "QUIT"
	quit.custom_minimum_size = Vector2(BUTTON_W, 34)
	quit.add_theme_font_size_override("font_size", 14)
	quit.pressed.connect(func() -> void: get_tree().quit())
	column.add_child(quit)
	var hint := Label.new()
	hint.text = "WASD walk · Shift run · E use · O options · F7 graphics · F5/F9 save/load"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 11)
	hint.add_theme_color_override("font_color", Color(0.45, 0.47, 0.45))
	column.add_child(hint)
	if first != null:
		first.grab_focus()
	# Headless smoke runs boot the menu as the default scene: leave at
	# once, there is nothing to check here.
	if DisplayServer.get_name() == "headless":
		print("[worldbuilder] menu: %d worlds" % WORLDS.size())
		get_tree().quit()


func _world_button(world: Dictionary) -> Button:
	var button := Button.new()
	button.text = "%s\n%s" % [world["title"], world["note"]]
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# A long note wraps within the button's width.
	button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	button.custom_minimum_size = Vector2(BUTTON_W, 0)
	button.add_theme_font_size_override("font_size", 14)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.10, 0.11, 0.13)
	style.border_color = Color(0.35, 0.37, 0.40)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.set_content_margin_all(7)
	style.content_margin_top = 4.0
	style.content_margin_bottom = 4.0
	button.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.13, 0.20, 0.15)
	hover.border_color = Color(0.35, 0.90, 0.50)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("focus", hover)
	button.add_theme_stylebox_override("pressed", hover)
	button.pressed.connect(func() -> void:
		var scene := str(world["scene"])
		match str(world.get("last_look", "")):
			"meadow":
				scene = MeadowMap.last_look_scene()
			"hills":
				scene = GrassHills.last_look_scene()
		get_tree().change_scene_to_file(scene))
	return button
