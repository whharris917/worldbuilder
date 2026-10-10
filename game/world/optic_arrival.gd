class_name OpticArrival
extends RefCounted
## A beam striking an aimed lumen part this step: whether it is lit
## (`delivered`, read as a LumenBeam's is), and whether it came from the
## part's left (`from_left`, for a latch: from the left it sets, from the
## right it resets); under sunlight also its power reaching the part, watts
## (`power`; -1 where beams are only lit or dark).

var delivered := false
var from_left := false
var power := -1.0


func _init(lit: bool, left: bool, watts := -1.0) -> void:
	delivered = lit
	from_left = left
	power = watts
