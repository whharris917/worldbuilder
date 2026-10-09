class_name OpticIntake
extends RefCounted
## One way into an aimed lumen part: a ring on one of its faces that
## takes a beam arriving through it. `enter` is the direction (in the
## part's head) a beam must be travelling to come in through it, give or
## take sixty degrees; `at` its centre in the head. It reads as lit
## (`delivered`, as a LumenBeam does) for a step after a lit beam landed
## on it (`pending`, set as the beams are traced).

var enter := Vector3.FORWARD
var at := Vector3.ZERO
var delivered := false
var pending := false


func _init(enter_dir: Vector3, centre: Vector3) -> void:
	enter = enter_dir
	at = centre
