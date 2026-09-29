class_name SkyArt
## The sky over the prep station, painted into any canvas item: stars after
## dusk, the sun on its arc by day, the moon at night in the phase for the
## current game day, and a scatter of clouds that changes from day to day
## (some days clear, some overcast enough to hide the sun). Static: callers
## repaint it when the game minute ticks, so it costs nothing per frame.
## Everything is clipped to `clip` (e.g. the rear windscreen) when given.

## Game days per lunar cycle; day 1 opens on a young waxing crescent.
const LUNAR_DAYS := 29.5
const SUNRISE := 6.0
const SUNSET := 18.6
const SUN := Color("fff0c2")
const SUN_LOW := Color("ffb45e")
const MOON := Color("f1ecd8")
const CLOUD_DAY := Color("f4f6fa")
const CLOUD_DUSK := Color("f2a58a")
## Cairo's night clouds catch the city's orange glow from below.
const CLOUD_NIGHT := Color("7d6f86")


## Paints the sky's bodies into `rect` of `ci` (the gradient is the caller's).
static func paint(ci: CanvasItem, rect: Rect2, clip: PackedVector2Array, soft: Texture2D) -> void:
	var hour := DayClock.hour()
	var dark := DayClock.darkness()
	var sky := DayClock.sky()
	var day := maxi(Economy.day_number, 1)
	var rng := RandomNumberGenerator.new()
	# Stars sit still (fixed seed); only their brightness follows the dusk.
	if dark > 0.05:
		rng.seed = 7
		var count := int(rect.size.x * rect.size.y / 2600.0)
		for k in count:
			var p := rect.position + Vector2(rng.randf(), rng.randf()) * rect.size
			var r := rng.randf_range(0.8, 2.0)
			if _inside(p, clip):
				ci.draw_circle(p, r, Color(1, 1, 1, dark * rng.randf_range(0.35, 0.9)))
				if r > 1.8:
					ci.draw_line(p - Vector2(r * 2.2, 0), p + Vector2(r * 2.2, 0), Color(1, 1, 1, 0.3 * dark), 1.0)
					ci.draw_line(p - Vector2(0, r * 2.2), p + Vector2(0, r * 2.2), Color(1, 1, 1, 0.3 * dark), 1.0)
	var body_r := clampf(rect.size.y * 0.13, 14.0, 44.0)
	# Sun: rises on the left, arcs over, sets on the right; warmer when low.
	if hour > SUNRISE - 0.3 and hour < SUNSET + 0.3:
		var t := clampf((hour - SUNRISE) / (SUNSET - SUNRISE), 0.0, 1.0)
		var c := _arc_point(rect, t)
		var warm := SUN.lerp(SUN_LOW, clampf(1.0 - sin(PI * t) * 2.2, 0.0, 1.0))
		for ring in [[3.2, 0.12], [2.2, 0.18], [1.5, 0.28]]:
			_fill(ci, PrepIcons._ellipse(c, Vector2.ONE * body_r * ring[0], 0.0, 28), clip, Color(warm, ring[1]))
		_fill(ci, PrepIcons._ellipse(c, Vector2.ONE * body_r, 0.0, 28), clip, StationArt.hdr(warm, 1.4))
	# Moon: up through the night, in tonight's phase.
	if dark > 0.2:
		var t := fmod(hour - (SUNSET - 0.5) + 24.0, 24.0) / (24.0 - (SUNSET - 0.5) + SUNRISE + 0.5)
		if t <= 1.0:
			_draw_moon(ci, _arc_point(rect, t), body_r * 0.8, phase(day), clip, soft, dark)
	# Clouds: how many and where are rolled per day.
	rng.seed = day * 7919 + 13
	var cloud_col := CLOUD_DAY.lerp(sky, 0.25)
	if hour > 16.5 and hour < 19.5 or hour > 5.0 and hour < 7.5:
		cloud_col = cloud_col.lerp(CLOUD_DUSK, 0.6)
	cloud_col = cloud_col.lerp(CLOUD_NIGHT, dark)
	var clouds := rng.randi_range(0, 5)
	for i in clouds:
		var at := rect.position + Vector2(rng.randf_range(-0.1, 1.0), rng.randf_range(0.1, 0.75)) * rect.size
		_draw_cloud(ci, at, rng.randf_range(0.6, 1.3) * rect.size.y * 0.16, rng, cloud_col, clip)


## 0 = new moon, 0.5 = full, for the given game day.
static func phase(day: int) -> float:
	return fmod((day + 3.0) / LUNAR_DAYS, 1.0)


## Point along the day's arc across `rect`: low at both ends, high mid-way.
static func _arc_point(rect: Rect2, t: float) -> Vector2:
	return rect.position + Vector2(0.1 + 0.8 * t, 0.85 - 0.62 * sin(PI * t)) * rect.size


static func _draw_moon(ci: CanvasItem, c: Vector2, r: float, p: float, clip: PackedVector2Array,
		soft: Texture2D, dark: float) -> void:
	var lit := cos(TAU * p)
	var glow := 0.5 * (1.0 - lit) * dark
	if soft != null and _inside(c, clip):
		ci.draw_texture_rect(soft, Rect2(c - Vector2.ONE * r * 3.0, Vector2.ONE * r * 6.0), false,
			Color(MOON, 0.18 * glow))
	# The unlit part faintly visible (earthshine), then the lit shape: the
	# bright limb on one side and the terminator's half-ellipse back.
	_fill(ci, PrepIcons._ellipse(c, Vector2.ONE * r, 0.0, 28), clip, Color(0.18, 0.2, 0.3, 0.55 * dark))
	if lit > 0.97:
		return
	var side := 1.0 if p < 0.5 else -1.0
	var shape := PackedVector2Array()
	for i in 15:
		var a := -PI * 0.5 + PI * i / 14.0
		shape.append(c + Vector2(side * r * cos(a), r * sin(a)))
	for i in 15:
		var a := PI * 0.5 - PI * i / 14.0
		shape.append(c + Vector2(side * lit * r * cos(a), r * sin(a)))
	if absf(lit) < 0.03:
		shape.remove_at(15)
	_fill(ci, shape, clip, StationArt.hdr(MOON, 1.2))
	# Near full, the dark maria show.
	if lit < -0.6:
		for m in [[Vector2(-0.25, -0.2), 0.22], [Vector2(0.2, 0.15), 0.18], [Vector2(-0.05, 0.4), 0.12]]:
			_fill(ci, PrepIcons._ellipse(c + m[0] * r, Vector2.ONE * r * m[1], 0.0, 12), clip, Color(0.72, 0.7, 0.62, 0.45))


## A flat-bottomed cumulus: a row of puffs over a base, shaded underneath.
static func _draw_cloud(ci: CanvasItem, at: Vector2, s: float, rng: RandomNumberGenerator, col: Color,
		clip: PackedVector2Array) -> void:
	var puffs := rng.randi_range(3, 5)
	var width := s * (1.2 + puffs * 0.7)
	var shade := col.darkened(0.14)
	_fill(ci, PrepIcons._rrect(Rect2(at + Vector2(-width * 0.5, -s * 0.5), Vector2(width, s * 0.5)), s * 0.24), clip, shade)
	for i in puffs:
		var t := (i + 0.5) / puffs
		var pr := s * rng.randf_range(0.45, 0.75) * (1.0 - absf(t - 0.5) * 0.8)
		var pc := at + Vector2((t - 0.5) * width * 0.8, -s * 0.45 - pr * 0.35)
		_fill(ci, PrepIcons._ellipse(pc, Vector2.ONE * pr, 0.0, 18), clip, col)
	_fill(ci, PrepIcons._rrect(Rect2(at + Vector2(-width * 0.45, -s * 0.52), Vector2(width * 0.9, s * 0.3)), s * 0.14), clip, col)


static func _inside(p: Vector2, clip: PackedVector2Array) -> bool:
	return clip.is_empty() or Geometry2D.is_point_in_polygon(p, clip)


static func _fill(ci: CanvasItem, poly: PackedVector2Array, clip: PackedVector2Array, col: Color) -> void:
	if clip.is_empty():
		ci.draw_colored_polygon(poly, col)
		return
	for piece in Geometry2D.intersect_polygons(poly, clip):
		ci.draw_colored_polygon(piece, col)
