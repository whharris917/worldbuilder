class_name Photogyrite
extends RefCounted
## The laws of photogyrite (spinstone) by its purity, shared by every
## stone in the game: how hard light on a stone draws its axis toward its
## body, and how hard it spins it about its axis, and the ceiling on the
## spin's power.
##
## Purity runs from 0, the cloudy stones found so far, to 1, flawless.
## It scales both actions together: a pure stone pulls and spins
## PURE_STRENGTH times as hard for each watt of light as an impure one,
## the strength rising evenly in proportion (a stone of purity 0.5 is ten
## times as strong). And light is its fuel: a stone never turns more of
## the light it catches into the power of its spin than its efficiency,
## 2% for an impure stone to 80% for a pure one. So the spin drives hard
## from rest and eases as it speeds up, as an engine of a given power
## does: the twist is the lesser of its strength's (TURN for each watt)
## and its power's share of the light over its spin's speed. Where the
## stone is turned against its spin's drive, the light only brakes it and
## no ceiling applies.

const PURE_STRENGTH := 100.0
const IMPURE_EFFICIENCY := 0.02
const PURE_EFFICIENCY := 0.8


## How many times an impure stone's strength, for `purity`.
static func strength(purity: float) -> float:
	return pow(PURE_STRENGTH, clampf(purity, 0.0, 1.0))


## The share of the light it catches that its spin may turn into power.
static func efficiency(purity: float) -> float:
	return lerpf(IMPURE_EFFICIENCY, PURE_EFFICIENCY, clampf(purity, 0.0, 1.0))


## The twist drawing its axis toward its body, N m for its light `watts`
## (times the sine of its angle off its body, as the cross product gives).
static func pull(watts: float, purity: float) -> float:
	return SpinstoneGimbals.PULL_PER_WATT * strength(purity) * watts


## The spin's twist about its axis, N m: `lined` how much the light drives
## it (its axis's cosine with its body, as the stone's kind takes it:
## none, only forward, or either way), `rate` its spin about its axis now,
## rad/s.
static func spin(watts: float, lined: float, rate: float, purity: float) -> float:
	var drive := SpinstoneGimbals.TURN * strength(purity) * watts * lined
	if drive * rate <= 0.0:
		return drive
	var most := efficiency(purity) * watts * absf(lined) / maxf(absf(rate), 0.5)
	return signf(drive) * minf(absf(drive), most)
