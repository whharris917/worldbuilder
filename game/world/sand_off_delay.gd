class_name SandOffDelay
extends ValveShutter
## An off-delay sandglass in the ring: the flap sandglass (ValveShutter)
## with its flaps' funnel on the other side of the waist, so the glass is
## open while lit and timed while dark.
##
## The flaps swing toward whichever end is lower, as the flap sandglass's
## do, but their stops are on B's side: with B (the bulb holding the
## beam's point, P) below, they fall into a funnel pointing down into B,
## a small hole at its point; with B above, they hang flat against the
## wall on A's side and the glass is open its whole width. At rest, dark,
## B is below and full to P: the beam is stopped. Lit, the geotrope turns
## the glass over, the flaps fall open and B's sand pours out into A at
## once: the beam passes as soon as B's sand no longer reaches P. Dark
## again, the glass turns back, the flaps fall into the funnel, and the
## sand runs back from A into B through the hole; the beam is stopped once
## B is full to P again, the glass's run after the light left. Lit again
## before then, the glass turns over and whatever sand is in B pours out:
## the count starts again from nothing.
##
## Its proportions are its own: P lies nearer B's end than its waist
## (B_END from it, WAIST beyond), so B full to P is less than half the
## bulb: lying level, the sand stays below the axis, and with B above it
## never reaches P. So the beam passes the moment the glass tips past
## level, and nothing flickers as it turns.

const FUNNEL_B := 0.7854                # rad: the flaps' funnel stop, 45 degrees from the wall toward B
const OPEN_A := PI                      # rad: hanging flat on the wall toward A
const WAIST := 0.04                     # m: the waist above P
const B_END := 0.03                     # m: B's far end below P, and B's sand at full
const BULB_LEN := 0.07                  # m: each bulb
const TURN_BACK := 0.63                    # s: the glass turning back before its sand runs, and the last of it settling


func _init(at: Vector3, brass: Material, leaf_metal: Material, glass: Material, wait: float) -> void:
	_petal_turn = FUNNEL_B
	super(at, brass, leaf_metal, glass, wait)
	name = "SandOffDelay"


## The delay, seconds: a glass whose neck runs all its sand back in the
## delay less the glass's turning (TURN_BACK); the flaps shut before the sand
## slides, so none slips through.
func set_delay(seconds: float) -> void:
	delay = clampf(seconds, 0.5, LONGEST)
	_rest = REST_S
	_run = maxf(delay - TURN_BACK, 0.3)
	_hole = 0.004 * pow(_run / 10.0, -0.4)
	var plate := _plate()
	for view in _plates:
		view.mesh = plate


func _waist() -> float:
	return WAIST


func _b_end() -> float:
	return -B_END


func _a_end() -> float:
	return WAIST + BULB_LEN


func _full_len() -> float:
	return B_END


## Whether B's sand covers P: only with B below and full to P.
func _covered() -> bool:
	return cos(_flip()) > 0.25 and _sand > 0.985


## How shut the funnel is, 0 open to 1 on its stops.
func _shut() -> float:
	return clampf(((FUNNEL_B + 0.35) - _petal_turn) / 0.35, 0.0, 1.0)


## The flaps and the sand over one step: the flaps toward the lower end,
## onto the funnel stops with B below, flat on A's side with A below;
## sand from the upper end once the glass is tipped past its angle of
## repose, through the hole while the funnel is shut, freely while open.
func _run_sand(h: float) -> void:
	var c := cos(_flip())
	var target := FUNNEL_B if c > 0.0 else OPEN_A
	if absf(c) > 0.05:
		_petal_turn = move_toward(_petal_turn, target, SWING * h)
	var into_b := signf(c) * clampf((absf(c) - REPOSE) * 5.0, 0.0, 1.0)
	var rate := lerpf(1.0 / BYPASS_RUN, 1.0 / _run, _shut())
	_sand = clampf(_sand + into_b * h * rate, 0.0, 1.0)


func _place() -> void:
	super()
	if _petals.is_empty():
		return
	var wide := lerpf(12.0, 1.0, _shut())
	_stream.scale = Vector3(wide, _stream.scale.y, wide)
