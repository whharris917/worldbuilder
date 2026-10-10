class_name BuildWorld
extends Node3D
## A world the player can build light-beam circuits in (Workshop): what
## the workshop asks of the world it stands in. The cozy island and the
## test island are each one.

var player: Player


## A material for a built piece in the world's look: `dir` a scanned
## texture set under textures/ (or ""), `scale` its repeats a metre,
## `real` the photographed tint, `rough` its roughness, `flat` its colour
## in a flat-painted look. `extra` carries the world's own keys
## ("no_line" for no outline).
func surface(_dir: String, _scale: float, _real: Color, _rough: float, flat: Color,
		_extra: Dictionary = {}) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = flat
	return m


## The ground's height at x, z.
func height(_x: float, _z: float) -> float:
	return 0.0


## Ground the world keeps clear of its own small things (flowers) under
## built floors, as [transform, half size].
func clear_ground(_areas: Array) -> void:
	pass
