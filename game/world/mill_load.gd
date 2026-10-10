class_name MillLoad
extends Node3D
## A machine driven from a windmill's take-off spindle: the vertical
## spindle on the ground floor whose pinion the great spur wheel turns,
## with a belt pulley on it (Windmill.SPINDLE, PULLEY_Y, PULLEY_R). A
## machine is belted to that pulley and asks of the spindle a torque
## that depends on how fast it turns. Each kind of machine extends this;
## the mill holds one (Windmill.attach) and builds nothing of it.
##
## Built in the mill's own frame (the sails' side +z, y up from the
## plinth's foot), as the mill's child.

var mill: Windmill


## The torque the machine holds against the spindle, in newton metres,
## at `omega` radians a second (positive turns it the spindle's way).
func torque(_omega: float) -> float:
	return 0.0


## The machine's own state carried on by `delta` seconds at `omega`.
func advance(_omega: float, _delta: float) -> void:
	pass


## A line or two for the panel: what the machine is doing.
func report() -> String:
	return ""


## What is kept between visits, and putting it back.
func state() -> Dictionary:
	return {}


func restore(_saved: Dictionary) -> void:
	pass
