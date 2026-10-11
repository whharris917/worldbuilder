class_name MoonOrbit
extends RefCounted
## The test island's moon on its orbit, and the eclipses of the sun it
## makes: a small world's sky, kept to geometry so that what the stones
## point at is what the sky shows and an eclipse can be foreseen.
##
## Time is counted in days from the world's first morning (`t`: the day
## plus the hour over 24). The sun stands still among the stars at the
## place on its yearly path where its declination is CozyTest.DECLINATION
## (a summer that does not end), so its day is the same each day. The
## moon goes round in a circle tilted TILT to the sun's path, coming back
## to the sun every MONTH days; the line where its circle crosses the
## sun's path (the nodes) turns backward once in NODES days. The moon
## passes in front of the sun when it comes round to the sun near a node.
## Every eclipse is total and central, the island under the middle of the
## shadow (the director's choice, against the real sky): about each new
## moon the path is drawn on to the sun's centre, or off clear of its
## disc, as `moon_vector` says; the moon's disc (MOON_R) is a quarter
## larger than the sun's (SUN_R), so the whole sun is hidden for some
## minutes of the island's time. A
## month of a few days and a small tilt make eclipses come every few days
## to a few weeks of the island's time; a month that is not a whole
## number of days moves each new moon to another hour, so an eclipse may
## fall by day, where it is seen, or by night.
##
## Directions: equatorial (x toward the sun's meridian at the spring
## point, z toward the celestial pole); turned to the island's sky by the
## hour angle, as the sun is (`place`).

const MONTH := 4.587                      # days from new moon to new moon
const NODES := 41.7                     # days for the nodes to turn once, backward
const TILT := 0.8                       # degrees between the moon's path and the sun's
const SUN_R := 0.266                    # degrees: the sun's disc, half across
const MOON_R := 0.333                   # degrees: the moon's, a quarter larger than the sun's
const ECLIPSE_REACH := 0.538            # degrees: a new moon this near the sun's path is drawn on to it
const CLEAR := 0.75                     # degrees: one farther, but nearer than this, is drawn off to it
const OBLIQUITY := 23.44                # degrees between the sun's path and the equator
const START_LONGITUDE := 200.0          # degrees: the moon along the sun's path on the first morning
const START_NODE := 100.0               # degrees: its rising node then


## The sun's place along its yearly path, degrees, fixed.
static func sun_longitude() -> float:
	return rad_to_deg(asin(sin(deg_to_rad(CozyTest.DECLINATION)) / sin(deg_to_rad(OBLIQUITY))))


## The sun's place among the stars (equatorial).
static func sun_vector() -> Vector3:
	var lon := deg_to_rad(sun_longitude())
	return _equatorial(Vector3(cos(lon), sin(lon), 0.0))


## The moon's place among the stars at time `t` (equatorial): on its
## circle, then drawn north or south about each new moon (`_new_moon`)
## so that a new moon either passes through the sun's centre or clears
## its disc. The pull grows and fades over the month (cos², nothing at
## half a month either side), so the path stays smooth.
static func moon_vector(t: float) -> Vector3:
	var p := _on_circle(t)
	var lon := atan2(p.y, p.x)
	var lat := asin(clampf(p.z, -1.0, 1.0))
	var k := roundi((t - _new_moon(0)) / MONTH)
	var t_k := _new_moon(k)
	var at_new := rad_to_deg(asin(clampf(_on_circle(t_k).z, -1.0, 1.0)))
	var w := pow(cos(PI * (t - t_k) / MONTH), 2.0)
	if absf(at_new) < ECLIPSE_REACH:
		lat -= deg_to_rad(at_new) * w
	elif absf(at_new) < CLEAR:
		lat += deg_to_rad(signf(at_new) * (CLEAR - absf(at_new))) * w
	return _equatorial(Vector3(cos(lat) * cos(lon), cos(lat) * sin(lon), sin(lat)))


## The moon on its plain tilted circle (ecliptic).
static func _on_circle(t: float) -> Vector3:
	var node := deg_to_rad(START_NODE - 360.0 * t / NODES)
	var along := deg_to_rad(START_LONGITUDE + 360.0 * t / MONTH) - node
	return Basis(Vector3(0, 0, 1), node) * Basis(Vector3(1, 0, 0), deg_to_rad(TILT)) * Vector3(cos(along), sin(along), 0.0)


## The time of the `k`th new moon: the moon's mean place along the sun's
## path at the sun's.
static func _new_moon(k: int) -> float:
	return (fposmod(sun_longitude() - START_LONGITUDE, 360.0) + 360.0 * k) / (360.0 / MONTH)


static func _equatorial(ecliptic: Vector3) -> Vector3:
	return Basis(Vector3(1, 0, 0), deg_to_rad(OBLIQUITY)) * ecliptic


## Height over the horizon and bearing from north toward east, degrees,
## of a body at declination `dec` and hour angle `ha` (degrees, westward
## from the meridian), from CozyTest.LATITUDE.
static func place(dec: float, ha: float) -> Vector2:
	var lat := deg_to_rad(CozyTest.LATITUDE)
	var d := deg_to_rad(dec)
	var angle := deg_to_rad(ha)
	var east := -cos(d) * sin(angle)
	var north := sin(d) * cos(lat) - cos(d) * cos(angle) * sin(lat)
	var up := sin(d) * sin(lat) + cos(d) * cos(angle) * cos(lat)
	return Vector2(rad_to_deg(asin(clampf(up, -1.0, 1.0))), fposmod(rad_to_deg(atan2(east, north)), 360.0))


## The moon's height and bearing at time `t`: its hour angle the sun's
## (by the hour) less how far east of the sun it stands.
static func moon_at(t: float) -> Vector2:
	var s := sun_vector()
	var m := moon_vector(t)
	var ahead := rad_to_deg(atan2(m.y, m.x) - atan2(s.y, s.x))
	var hour := fposmod(t, 1.0) * 24.0
	return place(rad_to_deg(asin(clampf(m.z, -1.0, 1.0))), (hour - 12.0) * 15.0 - ahead)


## Degrees between the sun's centre and the moon's at time `t`.
static func apart(t: float) -> float:
	return rad_to_deg(acos(clampf(sun_vector().dot(moon_vector(t)), -1.0, 1.0)))


## The share of the sun's disc the moon covers at time `t`, 0 to 1.
static func covered(t: float) -> float:
	return covered_at(apart(t))


static func covered_at(d: float) -> float:
	var r1 := SUN_R
	var r2 := MOON_R
	if d >= r1 + r2:
		return 0.0
	if d <= absf(r2 - r1):
		return 1.0 if r2 >= r1 else (r2 * r2) / (r1 * r1)
	var a1 := r1 * r1 * acos(clampf((d * d + r1 * r1 - r2 * r2) / (2.0 * d * r1), -1.0, 1.0))
	var a2 := r2 * r2 * acos(clampf((d * d + r2 * r2 - r1 * r1) / (2.0 * d * r2), -1.0, 1.0))
	var k := 0.5 * sqrt(maxf((-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2), 0.0))
	return clampf((a1 + a2 - k) / (PI * r1 * r1), 0.0, 1.0)


## Days since the last new moon at time `t`.
static func age(t: float) -> float:
	var s := sun_vector()
	var m := moon_vector(t)
	return fposmod(rad_to_deg(atan2(m.y, m.x) - atan2(s.y, s.x)), 360.0) / 360.0 * MONTH


## The first eclipse beginning after time `t` with the sun up at its
## deepest: {"start", "end", "deepest", "total_from", "total_to" (times),
## "share" (most of the sun covered)}; empty if none in `months` months.
static func next_eclipse(t: float, months := 400) -> Dictionary:
	# New moons fall where the moon's mean place along the sun's path
	# reaches the sun's; each is searched a little either side.
	var sun_lon := sun_longitude()
	var rate := 360.0 / MONTH
	var first := ceili((t - 0.2 - fposmod(sun_lon - START_LONGITUDE, 360.0) / rate) / MONTH)
	for k in range(first, first + months):
		var new_moon := (fposmod(sun_lon - START_LONGITUDE, 360.0) + 360.0 * k) / rate
		if apart(new_moon) > SUN_R + MOON_R + 1.0:
			continue
		var start := -1.0
		var end := -1.0
		var deepest := 0.0
		var share := 0.0
		var total_from := -1.0
		var total_to := -1.0
		var at := new_moon - 0.15
		while at < new_moon + 0.15:
			var c := covered(at)
			if c > 0.0:
				if start < 0.0:
					start = at
				end = at
				if c > share:
					share = c
					deepest = at
				if c >= 0.9999:
					if total_from < 0.0:
						total_from = at
					total_to = at
			at += 0.0002
		if start > t and CozyTest.sun_at(fposmod(deepest, 1.0) * 24.0).x > 0.0:
			return {"start": start, "end": end, "deepest": deepest, "share": share,
					"total_from": total_from, "total_to": total_to}
	return {}
