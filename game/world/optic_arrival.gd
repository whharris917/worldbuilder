class_name OpticArrival
extends RefCounted
## A beam striking an aimed lumen part this step: whether it is lit
## (`delivered`, read as a LumenBeam's is), and whether it came from the
## part's left (`from_left`, for a latch: from the left it sets, from the
## right it resets).

var delivered := false
var from_left := false


func _init(lit: bool, left: bool) -> void:
	delivered = lit
	from_left = left
