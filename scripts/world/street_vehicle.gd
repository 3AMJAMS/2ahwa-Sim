class_name StreetVehicle
extends Node2D
## One passing vehicle on the street, built to FIFI's scale in the street's
## 2:1 projection: a Cairo white taxi with its chequered band, a private
## saloon, a white microbus, a fruit-laden pickup, a tuk-tuk or a delivery
## scooter. Bodies are side profiles extruded across the car and shaded like
## FIFI; everything is drawn once and tinted by the time of day through
## `self_modulate`. Lamps sit on a child layer that brightens after dusk.
## Traffic moves it by setting `u`.

enum Kind { TAXI, SEDAN, MICROBUS, PICKUP, TUKTUK, SCOOTER }

const TILE_W := 128.0
const TILE_H := 64.0
## Real-world scale, matched to FIFI: tiles per metre along the ground and
## screen pixels per metre of height.
const M_TILES := 1.67
const M_PX := 107.0
const KEY_DIR := Vector3(-0.3, -0.25, 1.0)
const FILL_DIR := Vector3(0.35, 1.0, 0.45)
const GLASS := Color("1c2346")
const GLASS_SKY := Color("5f7aa6")
const TYRE := Color("16161b")
const RIM := Color("9aa0aa")
const CHROME := Color("d4d9e1")
const SEDAN_COLORS := [Color("c0c4ca"), Color("7a1f24"), Color("1f2e4d"), Color("1d1e22"), Color("c9b48f"),
	Color("f0efe9"), Color("3d5a45")]
const TUKTUK_COLORS := [Color("c8322b"), Color("2f5fb3"), Color("1f7a4a"), Color("d99a1e")]
const STRIPE_COLORS := [Color("2f6fb3"), Color("c8322b"), Color("e0a02a")]

var kind := Kind.TAXI
## +1 drives toward +u (we see its front), -1 toward -u (we see its back).
var dir := -1.0
var lane_v := -3.0
## Cruising speed it wants, and the speed it is actually doing (tiles/s).
var speed := 4.0
var cur_speed := 4.0
## Small vertical jiggle for tuk-tuks and scooters on the rough asphalt.
var bob := 0.0
var u := 0.0:
	set(value):
		u = value
		position = _point(u, lane_v) + Vector2(0, bob)

var _lamps := Node2D.new()
var _soft := StationArt._make_soft_texture()
var _paint := Color.WHITE
var _accent := Color.WHITE
var _melons := false


func _ready() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	match kind:
		Kind.TAXI, Kind.MICROBUS:
			_paint = Color("f1f1ee")
		Kind.SEDAN:
			_paint = SEDAN_COLORS[rng.randi() % SEDAN_COLORS.size()]
		Kind.PICKUP:
			_paint = [Color("2c5aa0"), Color("e9e6df"), Color("8a2a22")][rng.randi() % 3]
		Kind.TUKTUK:
			_paint = TUKTUK_COLORS[rng.randi() % TUKTUK_COLORS.size()]
		Kind.SCOOTER:
			_paint = [Color("c8322b"), Color("2b2b30"), Color("e9e6df")][rng.randi() % 3]
	_accent = STRIPE_COLORS[rng.randi() % STRIPE_COLORS.size()]
	_melons = rng.randf() < 0.5
	cur_speed = speed
	add_child(_lamps)
	_lamps.draw.connect(_draw_lamps)


func set_light(ambient: Color, darkness: float) -> void:
	self_modulate = ambient
	_lamps.modulate.a = lerpf(0.2, 1.0, darkness)


## Length in tiles along the street, for Traffic's spacing.
func length_tiles() -> float:
	return _length() * M_TILES


func _length() -> float:
	match kind:
		Kind.MICROBUS:
			return 4.7
		Kind.PICKUP:
			return 4.9
		Kind.TUKTUK:
			return 2.7
		Kind.SCOOTER:
			return 1.8
	return 4.4


static func _point(pu: float, pv: float) -> Vector2:
	return Vector2((pu - pv) * TILE_W * 0.5, (pu + pv) * TILE_H * 0.5)


## Vehicle-local point in metres: f forward (toward its nose), b across
## (+ toward us), h up.
func _q(f: float, b: float, h: float) -> Vector2:
	return _point(f * dir * M_TILES, b * M_TILES) + Vector2(0, -h * M_PX)


func _draw() -> void:
	var half := _length() * 0.5
	var w := 0.85 if kind != Kind.TUKTUK else 0.65
	if kind == Kind.SCOOTER:
		w = 0.3
	# Soft shadow under it.
	var shadow := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		shadow.append(_q(cos(a) * (half + 0.15), sin(a) * (w + 0.15) + 0.1, 0))
	draw_colored_polygon(shadow, Color(0, 0, 0, 0.3))
	match kind:
		Kind.TAXI, Kind.SEDAN:
			_draw_saloon(half)
		Kind.MICROBUS:
			_draw_microbus(half)
		Kind.PICKUP:
			_draw_pickup(half)
		Kind.TUKTUK:
			_draw_tuktuk(half)
		Kind.SCOOTER:
			_draw_scooter()


func _draw_saloon(half: float) -> void:
	for f in [-1.35, 1.35]:
		_wheel(f, -0.78, 0.31)
	_prism([Vector2(-2.2, 0.3), Vector2(2.2, 0.3), Vector2(2.25, 0.62), Vector2(2.05, 0.8), Vector2(1.0, 0.86),
		Vector2(-1.5, 0.9), Vector2(-2.2, 0.85), Vector2(-2.25, 0.6)], -0.85, 0.85, _paint)
	var cabin := [Vector2(-1.5, 0.88), Vector2(1.0, 0.84), Vector2(0.35, 1.42), Vector2(-0.9, 1.45)]
	_prism(cabin, -0.7, 0.7, _paint, [1, 3])
	_side_windows(cabin, 0.7, [0.0])
	_arches([-1.35, 1.35], 0.85, 0.36)
	for f in [-1.35, 1.35]:
		_wheel(f, 0.86, 0.31)
	_side_line(-2.1, 2.1, 0.85, 0.5, Color(0, 0, 0, 0.25), 2.0)
	_side_line(-0.05, -0.05, 0.85, 0.35, Color(0, 0, 0, 0.3), 1.5, 0.85)
	if kind == Kind.TAXI:
		# Cairo taxi: black-and-white chequered band, and the roof sign.
		for k in 22:
			var f0 := lerpf(-2.1, 2.1, k / 22.0)
			var f1 := lerpf(-2.1, 2.1, (k + 1) / 22.0)
			for row in 2:
				if (k + row) % 2 == 0:
					var h0 := 0.62 + row * 0.06
					draw_colored_polygon(PackedVector2Array([_q(f0, 0.86, h0), _q(f1, 0.86, h0), _q(f1, 0.86, h0 + 0.06),
						_q(f0, 0.86, h0 + 0.06)]), Color("1e1e22"))
		_prism([Vector2(-0.45, 1.44), Vector2(-0.05, 1.44), Vector2(-0.05, 1.6), Vector2(-0.45, 1.6)], -0.25, 0.25, Color("f2d24a"))
	_end_lamps(half, 0.7, 0.62, 0.75)


func _draw_microbus(half: float) -> void:
	for f in [-1.5, 1.6]:
		_wheel(f, -0.78, 0.32)
	var body := [Vector2(-2.35, 0.3), Vector2(2.35, 0.3), Vector2(2.4, 0.75), Vector2(2.2, 1.2), Vector2(1.7, 1.95),
		Vector2(-2.3, 1.98), Vector2(-2.38, 1.0)]
	_prism(body, -0.85, 0.85, _paint, [3])
	# Long side glass split by pillars, and the coloured stripe under it.
	draw_colored_polygon(PackedVector2Array([_q(-2.15, 0.86, 1.25), _q(1.75, 0.86, 1.25), _q(1.55, 0.86, 1.82),
		_q(-2.15, 0.86, 1.82)]), GLASS)
	for f in [-1.3, -0.4, 0.5, 1.3]:
		_side_line(f, f, 0.86, 1.25, _paint.darkened(0.15), 4.0, 1.82)
	_side_line(-2.1, 1.4, 0.86, 1.62, Color(1, 1, 1, 0.12), 3.0, 1.35)
	draw_colored_polygon(PackedVector2Array([_q(-2.38, 0.86, 1.02), _q(2.38, 0.86, 1.02), _q(2.36, 0.86, 1.12),
		_q(-2.38, 0.86, 1.12)]), _accent)
	_side_line(0.6, 0.6, 0.86, 0.35, Color(0, 0, 0, 0.3), 1.5, 1.2)
	# Roof rack with a strapped bundle.
	_prism([Vector2(-1.8, 1.98), Vector2(0.6, 1.98), Vector2(0.6, 2.25), Vector2(-1.8, 2.25)], -0.55, 0.55, Color("8a6a4a"))
	_side_line(-1.2, -1.2, 0.56, 1.98, Color("3a2a1c"), 2.0, 2.25)
	_arches([-1.5, 1.6], 0.85, 0.37)
	for f in [-1.5, 1.6]:
		_wheel(f, 0.86, 0.32)
	_end_lamps(half, 0.7, 0.7, 0.85)


func _draw_pickup(half: float) -> void:
	for f in [-1.55, 1.5]:
		_wheel(f, -0.78, 0.33)
	# Load bed first, with its cargo, then the cab in front of it.
	_prism([Vector2(-2.45, 0.35), Vector2(2.45, 0.35), Vector2(2.5, 0.7), Vector2(2.3, 1.0), Vector2(-2.45, 1.02)],
		-0.85, 0.85, _paint)
	# Open bed: dark floor inside the side walls, then the load on it.
	var fb := -2.35 if dir > 0 else -0.15
	var ff := -0.15 if dir > 0 else -2.35
	draw_colored_polygon(PackedVector2Array([_q(fb, -0.74, 1.02), _q(ff, -0.74, 1.02), _q(ff, 0.74, 1.02),
		_q(fb, 0.74, 1.02)]), _shade(_paint.darkened(0.6), Vector3(0, 0, 1)))
	_draw_cargo()
	var cab := [Vector2(-0.1, 1.0), Vector2(1.35, 1.0), Vector2(0.8, 1.72), Vector2(-0.1, 1.74)]
	_prism(cab, -0.8, 0.8, _paint, [1])
	_side_windows(cab, 0.8, [])
	# Tailgate chains and the bed rail.
	_side_line(-2.45, -0.1, 0.86, 1.02, _paint.lightened(0.2), 3.0)
	_arches([-1.55, 1.5], 0.85, 0.38)
	for f in [-1.55, 1.5]:
		_wheel(f, 0.86, 0.33)
	_end_lamps(half, 0.72, 0.7, 0.8)


## A heap of watermelons in the bed, or crates of oranges.
func _draw_cargo() -> void:
	for k in 7:
		var row := floori(k / 4.0)
		var f := lerpf(-2.2, -0.5, (k % 4) / 3.0)
		var c := _q(f, -0.45 + row * 0.7, 1.1 + row * 0.18)
		if _melons:
			draw_set_transform(c, 0.0, Vector2(1.3, 1.0))
			draw_circle(Vector2.ZERO, 16, Color("2f6a2c"))
			for s in [-8.0, 0.0, 8.0]:
				draw_line(Vector2(s, -14), Vector2(s * 1.2, 14), Color("1f4a1e"), 2.0)
			draw_set_transform(Vector2.ZERO)
		else:
			draw_rect(Rect2(c - Vector2(20, 14), Vector2(40, 22)), Color("b88a4a"))
			for o in 3:
				draw_circle(c + Vector2(-12 + o * 12, -16), 7, Color("f28c1e"))


func _draw_tuktuk(half: float) -> void:
	_wheel(-0.8, -0.62, 0.22)
	var body := [Vector2(-1.2, 0.25), Vector2(0.85, 0.25), Vector2(1.35, 0.45), Vector2(1.35, 1.0), Vector2(1.0, 1.25),
		Vector2(-1.2, 1.25)]
	_prism(body, -0.65, 0.65, _paint)
	# Windscreen, canopy posts and the roof, with a tasselled fringe.
	draw_colored_polygon(PackedVector2Array([_q(1.0, 0.55, 1.25), _q(1.0, -0.55, 1.25), _q(1.15, -0.55, 1.62),
		_q(1.15, 0.55, 1.62)]), Color(GLASS.lerp(GLASS_SKY, 0.4), 0.85))
	for f in [-1.15, 0.95]:
		_side_line(f, f, 0.62, 1.25, Color("1c1c20"), 3.0, 1.64)
	_prism([Vector2(-1.25, 1.62), Vector2(1.2, 1.62), Vector2(1.25, 1.72), Vector2(-1.25, 1.76)], -0.68, 0.68, Color("1c1c20"))
	for k in 14:
		var f := lerpf(-1.2, 1.15, k / 13.0)
		var top := _q(f, 0.69, 1.62)
		draw_colored_polygon(PackedVector2Array([top + Vector2(-5, 0), top + Vector2(5, 0), top + Vector2(0, 10)]),
			[Color("f2c230"), Color("e8433a"), Color("3bb36a")][k % 3])
	# Rear bench and the stripe on the panel.
	draw_colored_polygon(PackedVector2Array([_q(-1.1, 0.66, 0.6), _q(0.8, 0.66, 0.6), _q(0.8, 0.66, 0.7),
		_q(-1.1, 0.66, 0.7)]), _accent)
	_wheel(1.05, 0.0, 0.2)
	_wheel(-0.8, 0.66, 0.22)
	_end_lamps(half, 0.45, 0.55, 0.6)


func _draw_scooter() -> void:
	_wheel(-0.62, 0.0, 0.26)
	_wheel(0.65, 0.0, 0.26)
	# Frame, seat and the delivery box on the back (plain, no branding).
	_prism([Vector2(-0.75, 0.35), Vector2(0.55, 0.35), Vector2(0.75, 0.75), Vector2(0.5, 0.95), Vector2(-0.8, 0.8)],
		-0.18, 0.18, _paint)
	_prism([Vector2(-1.0, 0.85), Vector2(-0.35, 0.85), Vector2(-0.35, 1.35), Vector2(-1.0, 1.35)], -0.26, 0.26, Color("d8d4cc"))
	_side_line(-0.95, -0.4, 0.27, 1.12, _accent, 5.0)
	# Handlebar post and the rider in a helmet.
	_side_line(0.55, 0.45, 0.05, 0.9, Color("2a2a30"), 4.0, 1.3)
	var hip := _q(-0.15, 0.1, 1.0)
	var shoulder := _q(0.05, 0.1, 1.55)
	draw_line(hip, _q(0.35, 0.18, 0.6), Color("2b3350"), 9.0)
	draw_line(hip, shoulder, Color("5a6a7a"), 16.0)
	draw_line(shoulder, _q(0.5, 0.15, 1.25), Color("5a6a7a"), 7.0)
	draw_circle(_q(0.1, 0.1, 1.75), 13, Color("1c1c20"))
	draw_circle(_q(0.13, 0.1, 1.76) + Vector2(3 * dir, -2), 6, Color(1, 1, 1, 0.18))
	if dir > 0:
		draw_circle(_q(0.8, 0.0, 0.85), 5, Color("f5f0dc"))
	else:
		draw_circle(_q(-1.02, 0.0, 0.8), 4, Color("c3372c"))


## A side profile (f, h) extruded from b0 to b1: the faces toward the camera,
## then the near side. Edges listed in `glass` are drawn as glass.
func _prism(profile: Array, b0: float, b1: float, color: Color, glass: Array = []) -> void:
	var c := Vector2.ZERO
	for p in profile:
		c += p
	c /= profile.size()
	var n := profile.size()
	for i in n:
		var p: Vector2 = profile[i]
		var q: Vector2 = profile[(i + 1) % n]
		var d := q - p
		var nrm := Vector2(d.y, -d.x)
		if nrm.dot((p + q) * 0.5 - c) < 0.0:
			nrm = -nrm
		# In world terms the face normal is (f*dir, 0, h); visible if it points at us.
		var world := Vector3(nrm.x * dir, 0.0, nrm.y).normalized()
		if world.x + world.z <= 0.01:
			continue
		var col := GLASS.lerp(GLASS_SKY, 0.35 + 0.3 * world.z) if glass.has(i) else color
		draw_colored_polygon(PackedVector2Array([_q(p.x, b0, p.y), _q(q.x, b0, q.y), _q(q.x, b1, q.y), _q(p.x, b1, p.y)]),
			_shade(col, world))
	var side := PackedVector2Array()
	for p in profile:
		side.append(_q(p.x, b1, p.y))
	draw_colored_polygon(side, _shade(color, Vector3(0, 1, 0)))


## Side windows inset in a cabin profile, with pillars at the listed f.
func _side_windows(cabin: Array, b: float, pillars: Array) -> void:
	var c := Vector2.ZERO
	for p in cabin:
		c += p
	c /= cabin.size()
	var glass := PackedVector2Array()
	for p in cabin:
		var inset: Vector2 = c + (p - c) * 0.84
		glass.append(_q(inset.x, b + 0.01, maxf(inset.y, c.y - 0.12)))
	draw_colored_polygon(glass, _shade(GLASS.lerp(GLASS_SKY, 0.2), Vector3(0, 1, 0)))
	for f in pillars:
		_side_line(f, f, b + 0.02, c.y - 0.2, _paint.darkened(0.1), 5.0, c.y + 0.3)
	draw_line(glass[0].lerp(glass[1], 0.35), glass[3].lerp(glass[2], 0.45), Color(1, 1, 1, 0.14), 4.0)


## Dark wheel-arch openings on the near side.
func _arches(fs: Array, b: float, r: float) -> void:
	for f in fs:
		var pts := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			pts.append(_q(f + r * cos(a), b + 0.01, 0.33 + r * sin(a)))
		draw_colored_polygon(pts, Color("0d0e14"))


## A wheel standing across the car at b.
func _wheel(f: float, b: float, r: float) -> void:
	var tyre := PackedVector2Array()
	var rim := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		tyre.append(_q(f + r * cos(a), b, r + r * sin(a)))
		rim.append(_q(f + r * 0.58 * cos(a), b + 0.01, r + r * 0.58 * sin(a)))
	draw_colored_polygon(tyre, TYRE)
	if b >= 0.0:
		draw_colored_polygon(rim, _shade(RIM, Vector3(0, 1, 0)))
		draw_circle(_q(f, b + 0.02, r), r * 0.16 * M_PX, CHROME.darkened(0.2))


func _side_line(f0: float, f1: float, b: float, h: float, color: Color, width: float, h1 := -1.0) -> void:
	draw_line(_q(f0, b, h), _q(f1, b, h if h1 < 0.0 else h1), color, width, true)


## Lamp housings on the visible end: headlights if it faces us, else tail lamps.
func _end_lamps(half: float, b: float, h0: float, h1: float) -> void:
	var f := half if dir > 0 else -half
	for s in [-1.0, 1.0]:
		var col := Color("e8e4d4") if dir > 0 else Color("a3261f")
		draw_colored_polygon(PackedVector2Array([_q(f, s * b - 0.14, h0), _q(f, s * b + 0.14, h0), _q(f, s * b + 0.14, h1),
			_q(f, s * b - 0.14, h1)]), col)
	# Plate between them.
	draw_colored_polygon(PackedVector2Array([_q(f, -0.25, h0 - 0.18), _q(f, 0.25, h0 - 0.18), _q(f, 0.25, h0 - 0.05),
		_q(f, -0.25, h0 - 0.05)]), Color("ece8dc"))


func _draw_lamps() -> void:
	if kind == Kind.SCOOTER:
		var at := _q(0.8 if dir > 0 else -1.02, 0.0, 0.82)
		_lamp_glow(at, 1.0)
		return
	var half := _length() * 0.5
	var f := half + 0.02
	var spread := 0.45 if kind == Kind.TUKTUK else 0.7
	for s in [-1.0, 1.0]:
		var at := _q(f if dir > 0 else -f, s * spread, 0.68)
		_lamp_glow(at, 1.0)
	if dir > 0:
		# Headlight beam spilling onto the road ahead.
		var ahead := _q(half + 2.0, 0, 0)
		_lamps.draw_texture_rect(_soft, Rect2(ahead - Vector2(170, 85), Vector2(340, 170)), false, Color(1, 0.95, 0.8, 0.16))


func _lamp_glow(at: Vector2, k: float) -> void:
	if dir > 0:
		_lamps.draw_texture_rect(_soft, Rect2(at - Vector2(26, 26) * k, Vector2(52, 52) * k), false, Color(1, 0.95, 0.8, 0.5))
		_lamps.draw_circle(at, 4.5 * k, StationArt.hdr(Color(1, 0.96, 0.85), 2.4))
	else:
		_lamps.draw_texture_rect(_soft, Rect2(at - Vector2(20, 20) * k, Vector2(40, 40) * k), false, Color(1, 0.15, 0.1, 0.45))
		_lamps.draw_circle(at, 3.5 * k, StationArt.hdr(Color(1, 0.2, 0.15), 2.0))


## FIFI's lighting: warm key from above-left, cool fill from our side.
func _shade(base: Color, normal: Vector3) -> Color:
	var n := normal.normalized()
	var key := maxf(n.dot(KEY_DIR.normalized()), 0.0)
	var fill := maxf(n.dot(FILL_DIR.normalized()), 0.0)
	return Color(base.r * (0.46 + 0.55 * key + 0.36 * fill), base.g * (0.46 + 0.50 * key + 0.38 * fill),
		base.b * (0.50 + 0.38 * key + 0.50 * fill), base.a)
