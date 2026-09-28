class_name StreetVehicle
extends Node2D
## One passing vehicle on the street, in the street's 2:1 projection: a Cairo
## white taxi with its chequered band, a private saloon, a white microbus, a
## fruit-laden pickup, a tuk-tuk or a delivery scooter. Bodies are side
## profiles with rounded corners, extruded across the car and shaded like
## FIFI, then dressed with framed glass, door shut lines, handles, mirrors,
## spoked rims, grilles, lamps, bumpers and plates. Everything is drawn once
## and tinted by the time of day through `self_modulate`; lamps sit on a child
## layer that brightens after dusk. Traffic moves it by setting `u`.

enum Kind { TAXI, SEDAN, MICROBUS, PICKUP, TUKTUK, SCOOTER }

const TILE_W := 128.0
const TILE_H := 64.0
## A touch under FIFI's scale so the traffic doesn't crowd the street.
const SIZE := 0.8
## Tiles per metre along the ground and screen pixels per metre of height.
const M_TILES := 1.67 * SIZE
const M_PX := 107.0 * SIZE
const KEY_DIR := Vector3(-0.3, -0.25, 1.0)
const FILL_DIR := Vector3(0.35, 1.0, 0.45)
const GLASS := Color("1c2346")
const GLASS_SKY := Color("6f8cb8")
const RUBBER := Color("1a1a1f")
const TYRE := Color("17171c")
const RIM := Color("a8aeb8")
const CHROME := Color("d4d9e1")
const PLASTIC := Color("2c2d33")
const PLATE := Color("ece8dc")
const SEDAN_COLORS := [Color("c0c4ca"), Color("7a1f24"), Color("1f2e4d"), Color("26272c"), Color("c9b48f"),
	Color("f0efe9"), Color("3d5a45"), Color("8a8f96")]
const TUKTUK_COLORS := [Color("c8322b"), Color("2f5fb3"), Color("1f7a4a"), Color("d99a1e")]
const STRIPE_COLORS := [Color("2f6fb3"), Color("c8322b"), Color("e0a02a")]
const FRINGE := [Color("f2c230"), Color("e8433a"), Color("3bb36a"), Color("2fa4e0")]

var kind := Kind.TAXI
## +1 drives toward +u (we see its front), -1 toward -u (we see its back).
var dir := -1.0
var lane_v := -3.0
## The lane it's heading for when overtaking (== lane_v when not).
var target_lane := -3.0
var changing_lane := false
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
var _m: MeshCanvas
var _mesh: ArrayMesh
var _soft := StationArt._make_soft_texture()
var _paint := Color.WHITE
var _accent := Color.WHITE
var _melons := false
## f of the visible end (the one facing +u), a hair proud of the body.
var _end_f := 0.0


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
	_end_f = dir * (_length() * 0.5 + 0.01)
	add_child(_lamps)
	_lamps.draw.connect(_draw_lamps)


func change_lane(v: float) -> void:
	target_lane = v
	changing_lane = true


## Drifts sideways toward target_lane, about a lane per second.
func step_lane(delta: float) -> void:
	if not changing_lane:
		return
	lane_v = move_toward(lane_v, target_lane, 3.5 * delta)
	if is_equal_approx(lane_v, target_lane):
		lane_v = target_lane
		changing_lane = false


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


func _half_width() -> float:
	match kind:
		Kind.TUKTUK:
			return 0.58
		Kind.SCOOTER:
			return 0.3
	return 0.85


static func _point(pu: float, pv: float) -> Vector2:
	return Vector2((pu - pv) * TILE_W * 0.5, (pu + pv) * TILE_H * 0.5)


## Vehicle-local point in metres: f forward (toward its nose), b across
## (+ toward us), h up.
func _q(f: float, b: float, h: float) -> Vector2:
	return _point(f * dir * M_TILES, b * M_TILES) + Vector2(0, -h * M_PX)


## A point on the visible end face, by (across, up).
func _e(b: float, h: float) -> Vector2:
	return _q(_end_f, b, h)


func _draw() -> void:
	if _mesh == null:
		_m = MeshCanvas.new()
		_build()
		_mesh = _m.commit()
		_m = null
	if _mesh:
		draw_mesh(_mesh, null)


## Everything is baked into one mesh the first time it's drawn: one draw call
## per vehicle, however detailed.
func _build() -> void:
	var half := _length() * 0.5
	var w := _half_width()
	# Soft shadow: a wide faint one and a tighter dark core.
	for layer in [[0.35, 0.16], [0.12, 0.26]]:
		var grow: float = layer[0]
		var shadow := PackedVector2Array()
		for i in 20:
			var a := TAU * i / 20.0
			shadow.append(_q(cos(a) * (half + grow), sin(a) * (w + grow) + 0.12, 0))
		_m.colored_polygon(shadow, Color(0, 0, 0, layer[1]))
	match kind:
		Kind.TAXI, Kind.SEDAN:
			_draw_saloon()
		Kind.MICROBUS:
			_draw_microbus()
		Kind.PICKUP:
			_draw_pickup()
		Kind.TUKTUK:
			_draw_tuktuk()
		Kind.SCOOTER:
			_draw_scooter()


# --- Vehicles -------------------------------------------------------------

func _draw_saloon() -> void:
	for f in [-1.35, 1.35]:
		_wheel(f, -0.74, 0.31)
	_prism([Vector2(-2.2, 0.3), Vector2(2.2, 0.3), Vector2(2.25, 0.62), Vector2(2.05, 0.8), Vector2(1.0, 0.86),
		Vector2(-1.5, 0.9), Vector2(-2.2, 0.85), Vector2(-2.25, 0.6)], -0.85, 0.85, _paint, 0.12)
	_prism([Vector2(-1.5, 0.88), Vector2(1.0, 0.84), Vector2(0.35, 1.42), Vector2(-0.9, 1.45)], -0.7, 0.7, _paint,
		0.07, [1, 3])
	# Rubber-framed door glass either side of the B-pillar.
	_window([Vector2(-0.02, 0.93), Vector2(0.84, 0.93), Vector2(0.4, 1.36), Vector2(-0.02, 1.36)], 0.7)
	_window([Vector2(-1.36, 0.93), Vector2(-0.14, 0.93), Vector2(-0.14, 1.36), Vector2(-0.92, 1.36)], 0.7)
	# Rocker sill, shut lines, handles, fuel flap and the waist crease.
	_side_poly([Vector2(-2.05, 0.3), Vector2(2.05, 0.3), Vector2(2.05, 0.37), Vector2(-2.05, 0.37)], 0.85,
		_paint.darkened(0.35))
	_side_line([Vector2(-2.15, 0.7), Vector2(2.15, 0.68)], 0.86, Color(1, 1, 1, 0.18), 1.5)
	for seam in [[Vector2(1.02, 0.38), Vector2(1.0, 0.86)], [Vector2(-0.06, 0.38), Vector2(-0.06, 0.9)],
			[Vector2(-1.3, 0.38), Vector2(-1.45, 0.9)]]:
		_side_line(seam, 0.86, Color(0, 0, 0, 0.3), 1.5)
	for hx in [0.62, -0.72]:
		_side_poly(_rrect(Vector2(hx, 0.78), Vector2(0.11, 0.025)), 0.87, CHROME.darkened(0.15))
	_side_poly(_rrect(Vector2(-1.72, 0.74), Vector2(0.07, 0.05)), 0.86, _paint.darkened(0.12))
	_mirror(0.95, 0.72, 0.96)
	_arches([-1.35, 1.35], 0.86, 0.36)
	for f in [-1.35, 1.35]:
		_wheel(f, 0.86, 0.31)
	if kind == Kind.TAXI:
		_taxi_band()
		# Roof sign.
		_prism([Vector2(-0.5, 1.44), Vector2(0.0, 1.44), Vector2(0.0, 1.58), Vector2(-0.5, 1.6)], -0.28, 0.28,
			Color("f2d24a"), 0.04)
		_side_poly([Vector2(-0.45, 1.49), Vector2(-0.05, 1.49), Vector2(-0.05, 1.54), Vector2(-0.45, 1.54)], 0.29, Color("1e1e22"))
	else:
		# Whip aerial at the back of the roof.
		_m.line(_q(-0.8, -0.4, 1.45), _q(-1.05, -0.4, 1.95), PLASTIC, 1.2, true)
	_end_details(0.85, 0.3, 0.62, Color("e8962e") if kind == Kind.TAXI else Color("4b87c6"))


## Cairo taxi: two rows of black-and-white checks along the flanks.
func _taxi_band() -> void:
	for k in 24:
		var f0 := lerpf(-2.1, 2.1, k / 24.0)
		var f1 := lerpf(-2.1, 2.1, (k + 1) / 24.0)
		for row in 2:
			if (k + row) % 2 == 0:
				var h0 := 0.56 + row * 0.055
				_side_poly([Vector2(f0, h0), Vector2(f1, h0), Vector2(f1, h0 + 0.055), Vector2(f0, h0 + 0.055)], 0.865,
					Color("1e1e22"))


func _draw_microbus() -> void:
	for f in [-1.5, 1.6]:
		_wheel(f, -0.74, 0.32)
	_prism([Vector2(-2.35, 0.3), Vector2(2.35, 0.3), Vector2(2.4, 0.75), Vector2(2.2, 1.2), Vector2(1.7, 1.95),
		Vector2(-2.3, 1.98), Vector2(-2.38, 1.0)], -0.85, 0.85, _paint, 0.14, [3])
	# Four side windows, rounded, and the cab's door glass.
	for win in [[-2.15, -1.4], [-1.3, -0.55], [-0.45, 0.35], [0.45, 1.0]]:
		_window(_rrect_pts(Vector2(win[0], 1.26), Vector2(win[1], 1.82), 0.06), 0.86)
	_window([Vector2(1.12, 1.26), Vector2(1.95, 1.26), Vector2(1.62, 1.82), Vector2(1.12, 1.82)], 0.86)
	# Coloured stripe, sliding-door rail and shut lines, handle, step.
	_side_poly([Vector2(-2.38, 1.02), Vector2(2.38, 1.02), Vector2(2.34, 1.12), Vector2(-2.38, 1.12)], 0.865, _accent)
	_side_poly([Vector2(-2.38, 0.9), Vector2(2.38, 0.9), Vector2(2.38, 0.94), Vector2(-2.38, 0.94)], 0.865,
		_accent.darkened(0.25))
	_side_line([Vector2(-1.35, 1.88), Vector2(0.4, 1.88)], 0.87, PLASTIC, 2.0)
	for f in [-1.35, 0.4, 1.05]:
		_side_line([Vector2(f, 0.36), Vector2(f, 1.86)], 0.87, Color(0, 0, 0, 0.28), 1.5)
	_side_poly(_rrect(Vector2(0.28, 1.0), Vector2(0.09, 0.03)), 0.875, CHROME.darkened(0.15))
	_side_poly([Vector2(-0.9, 0.3), Vector2(0.2, 0.3), Vector2(0.2, 0.36), Vector2(-0.9, 0.36)], 0.87, PLASTIC)
	_mirror(1.85, 0.78, 1.35)
	# Roof rack with rails and a roped bundle.
	for b in [-0.55, 0.55]:
		_m.line(_q(-2.0, b, 2.06), _q(1.4, b, 2.06), PLASTIC, 2.0, true)
		for f in [-1.8, -0.6, 0.6]:
			_m.line(_q(f, b, 1.98), _q(f, b, 2.06), PLASTIC, 2.0, true)
	_prism([Vector2(-1.7, 2.06), Vector2(0.5, 2.06), Vector2(0.45, 2.34), Vector2(-1.65, 2.36)], -0.5, 0.5,
		Color("8a6a4a"), 0.08)
	for f in [-1.2, -0.3]:
		_side_line([Vector2(f, 2.06), Vector2(f + 0.02, 2.35)], 0.51, Color("3a2a1c"), 2.0)
	_arches([-1.5, 1.6], 0.86, 0.37)
	for f in [-1.5, 1.6]:
		_wheel(f, 0.86, 0.32)
	_end_details(0.85, 0.3, 0.72, Color("c8322b"))
	if dir < 0:
		# Ladder up the back to the roof rack.
		for b in [-0.62, -0.4]:
			_m.line(_e(b, 0.9), _e(b, 1.98), PLASTIC, 2.0, true)
		for k in 6:
			var h := 1.0 + k * 0.17
			_m.line(_e(-0.62, h), _e(-0.4, h), PLASTIC, 1.5, true)


func _draw_pickup() -> void:
	for f in [-1.55, 1.5]:
		_wheel(f, -0.74, 0.33)
	# Chassis-high body the full length, the bed floor, then its walls round the load.
	_prism([Vector2(-2.45, 0.35), Vector2(2.45, 0.35), Vector2(2.5, 0.7), Vector2(2.3, 0.78), Vector2(-2.45, 0.74)],
		-0.85, 0.85, _paint, 0.1)
	var back := -2.4
	var front := -0.15
	_m.colored_polygon(PackedVector2Array([_q(back, -0.78, 0.74), _q(front, -0.78, 0.74), _q(front, 0.78, 0.74),
		_q(back, 0.78, 0.74)]), _shade(_paint.darkened(0.6), Vector3(0, 0, 1)))
	_prism([Vector2(back, 0.74), Vector2(front, 0.74), Vector2(front, 1.04), Vector2(back, 1.04)], -0.85, -0.78,
		_paint.darkened(0.08))
	# Cab behind the load when it drives toward us, in front of it otherwise.
	if dir > 0:
		_draw_cargo(back, front)
		_pickup_cab()
	else:
		_pickup_cab()
		_draw_cargo(back, front)
	_prism([Vector2(back, 0.74), Vector2(front, 0.74), Vector2(front, 1.04), Vector2(back, 1.04)], 0.78, 0.85, _paint)
	_prism([Vector2(back - 0.05, 0.74), Vector2(back + 0.03, 0.74), Vector2(back + 0.03, 1.04), Vector2(back - 0.05, 1.04)],
		-0.85, 0.85, _paint.darkened(0.05))
	_side_line([Vector2(back, 1.04), Vector2(front, 1.04)], 0.86, _paint.lightened(0.25), 2.0)
	for f in [-1.8, -0.9]:
		_side_line([Vector2(f, 0.76), Vector2(f, 1.02)], 0.86, Color(0, 0, 0, 0.22), 1.5)
	_side_poly([Vector2(-2.3, 0.35), Vector2(2.3, 0.35), Vector2(2.3, 0.42), Vector2(-2.3, 0.42)], 0.86, _paint.darkened(0.35))
	_arches([-1.55, 1.5], 0.86, 0.38)
	for f in [-1.55, 1.5]:
		_wheel(f, 0.86, 0.33)
	_end_details(0.85, 0.35, 0.66, Color("c8322b"))


func _pickup_cab() -> void:
	_prism([Vector2(-0.1, 0.76), Vector2(1.35, 0.76), Vector2(0.8, 1.72), Vector2(-0.1, 1.74)], -0.8, 0.8, _paint,
		0.07, [1])
	_window([Vector2(0.05, 1.1), Vector2(1.05, 1.1), Vector2(0.72, 1.64), Vector2(0.05, 1.64)], 0.8)
	_side_line([Vector2(-0.08, 0.78), Vector2(-0.08, 1.7)], 0.81, Color(0, 0, 0, 0.3), 1.5)
	_side_line([Vector2(1.3, 0.78), Vector2(1.2, 1.0)], 0.81, Color(0, 0, 0, 0.3), 1.5)
	_side_poly(_rrect(Vector2(0.2, 1.02), Vector2(0.09, 0.025)), 0.82, CHROME.darkened(0.15))
	_mirror(1.1, 0.72, 1.18)


## A heap of striped watermelons in the bed, or crates of oranges.
func _draw_cargo(back: float, front: float) -> void:
	for k in 9:
		var row := floori(k / 3.0)
		var f := lerpf(back + 0.35, front - 0.35, (k % 3) / 2.0) + (0.15 if row == 1 else 0.0)
		var b := -0.45 + row * 0.45
		var h := 0.95 + (0.22 if row == 1 else 0.0)
		var c := _q(f, b, h)
		if _melons:
			var r := 0.22 * M_PX
			_m.set_transform(c, 0.0, Vector2(1.3, 1.0))
			_m.circle(Vector2.ZERO, r, Color("2f6a2c"))
			for s in [-0.55, -0.2, 0.2, 0.55]:
				var x: float = s * r
				_m.line(Vector2(x, -r * 0.9), Vector2(x * 1.15, r * 0.9), Color("1f4a1e"), 2.0)
			_m.circle(Vector2(-r * 0.35, -r * 0.4), r * 0.28, Color(1, 1, 1, 0.12))
			_m.set_transform(Vector2.ZERO)
		else:
			var hw := 0.2 * M_PX
			_m.rect(Rect2(c - Vector2(hw, hw * 0.4), Vector2(hw * 2.0, hw * 0.9)), Color("b88a4a"))
			_m.rect(Rect2(c - Vector2(hw, hw * 0.4), Vector2(hw * 2.0, hw * 0.9)), Color("7a5a2e"), false, 1.5)
			_m.line(c + Vector2(-hw, hw * 0.05), c + Vector2(hw, hw * 0.05), Color("7a5a2e"), 1.2)
			for o in 4:
				var at := c + Vector2(-hw * 0.75 + o * hw * 0.5, -hw * 0.5)
				_m.circle(at, hw * 0.3, Color("f28c1e"))
				_m.circle(at + Vector2(-hw * 0.08, -hw * 0.1), hw * 0.1, Color(1, 1, 1, 0.25))


func _draw_tuktuk() -> void:
	var canopy := _paint.darkened(0.45)
	_wheel(-0.8, -0.5, 0.22)
	# Low body tub first: its floor is under everything inside.
	_prism([Vector2(-1.15, 0.28), Vector2(0.8, 0.28), Vector2(1.3, 0.45), Vector2(1.35, 0.72), Vector2(1.0, 0.76),
		Vector2(-1.15, 0.7)], -0.56, 0.56, _paint, 0.12)
	_prism([Vector2(0.98, 0.14), Vector2(1.3, 0.14), Vector2(1.38, 0.42), Vector2(0.98, 0.42)], -0.1, 0.1,
		_paint.darkened(0.25), 0.06)
	# Through the open side: the far canvas wall, the rear bench, the driver.
	_side_poly([Vector2(-1.05, 0.72), Vector2(0.95, 0.74), Vector2(1.0, 1.5), Vector2(-0.95, 1.62)], -0.5, Color("2a2830"))
	_prism([Vector2(-1.0, 0.7), Vector2(-0.45, 0.7), Vector2(-0.45, 0.95), Vector2(-1.0, 0.95)], -0.48, 0.48,
		Color("7a2e22"), 0.04)
	_prism([Vector2(-1.08, 0.95), Vector2(-0.96, 0.95), Vector2(-0.98, 1.36), Vector2(-1.1, 1.36)], -0.48, 0.48,
		Color("7a2e22"), 0.03)
	var hip := _q(0.4, 0.0, 0.95)
	var neck := _q(0.46, 0.0, 1.34)
	_m.line(hip, _q(0.75, 0.1, 0.78), Color("2b3350"), 8.0)
	_m.line(hip, neck, Color("e9e6df"), 14.0)
	_m.line(neck, _q(0.84, 0.2, 1.12), Color("e9e6df"), 6.0)
	_m.circle(_q(0.47, 0.0, 1.45), 0.1 * M_PX, Color("b97a52"))
	_m.circle(_q(0.46, 0.0, 1.5), 0.075 * M_PX, Color("1d1612"))
	_m.line(_q(0.86, -0.28, 1.12), _q(0.86, 0.28, 1.12), PLASTIC, 3.0)
	# Dashboard nose up to the windscreen.
	_prism([Vector2(0.92, 0.72), Vector2(1.34, 0.72), Vector2(1.3, 1.05), Vector2(1.04, 1.22), Vector2(0.92, 1.22)],
		-0.54, 0.54, _paint.lightened(0.05), 0.06)
	# Rounded rear: a low back panel, then the canopy curving down over it.
	_prism([Vector2(-1.22, 0.7), Vector2(-1.1, 0.7), Vector2(-1.1, 1.2), Vector2(-1.22, 1.2)], -0.56, 0.56,
		_paint.lightened(0.08))
	# Windscreen and the front canopy posts.
	_m.colored_polygon(PackedVector2Array([_q(1.04, 0.48, 1.22), _q(1.04, -0.48, 1.22), _q(1.14, -0.48, 1.5),
		_q(1.14, 0.48, 1.5)]), Color(GLASS.lerp(GLASS_SKY, 0.45), 0.85))
	_m.line(_q(1.07, 0.18, 1.27), _q(1.12, -0.1, 1.46), Color(1, 1, 1, 0.2), 2.0)
	for b in [-0.52, 0.52]:
		_m.line(_q(1.0, b, 0.76), _q(1.13, b, 1.52), Color("1c1c20"), 3.0)
	# Canopy: slopes down to the windscreen, rounds off over the back, where
	# it carries a small rear window.
	_prism([Vector2(-1.24, 1.12), Vector2(-1.1, 1.12), Vector2(-1.1, 1.5), Vector2(1.14, 1.48), Vector2(1.2, 1.54),
		Vector2(0.95, 1.66), Vector2(-0.8, 1.74), Vector2(-1.24, 1.5)], -0.6, 0.6, canopy, 0.28)
	if dir < 0:
		var fr := -1.25
		_m.colored_polygon(PackedVector2Array([_q(fr, -0.32, 1.22), _q(fr, 0.32, 1.22), _q(fr, 0.28, 1.46),
			_q(fr, -0.28, 1.46)]), _shade(GLASS.lerp(GLASS_SKY, 0.4), Vector3(1, 0, 0)))
		_m.colored_polygon(PackedVector2Array([_q(-1.17, -0.18, 0.4), _q(-1.17, 0.18, 0.4), _q(-1.17, 0.18, 0.52),
			_q(-1.17, -0.18, 0.52)]), PLATE)
		for side in [-0.44, 0.44]:
			_m.circle(_q(-1.17, side, 0.56), 0.045 * M_PX, Color("c3372c"))
	_side_poly([Vector2(-1.1, 1.5), Vector2(1.14, 1.48), Vector2(1.14, 1.53), Vector2(-1.1, 1.56)], 0.61, _accent)
	for k in 14:
		var f := lerpf(-1.05, 1.08, k / 13.0)
		var top := _q(f, 0.61, lerpf(1.5, 1.48, k / 13.0))
		_m.colored_polygon(PackedVector2Array([top + Vector2(-4, 0), top + Vector2(4, 0), top + Vector2(0, 9)]),
			FRINGE[k % FRINGE.size()])
		_m.circle(top + Vector2(0, 10), 1.8, FRINGE[(k + 1) % FRINGE.size()])
	# Stripe and chrome trim on the tub, mirror, headlamp, wheels.
	_side_poly([Vector2(-1.05, 0.48), Vector2(0.85, 0.48), Vector2(0.95, 0.56), Vector2(-1.05, 0.56)], 0.57, _accent)
	_side_poly([Vector2(-1.05, 0.62), Vector2(0.95, 0.62), Vector2(0.98, 0.65), Vector2(-1.05, 0.65)], 0.57, CHROME)
	_mirror(1.06, 0.5, 1.26)
	_m.circle(_q(1.35, 0.0, 0.95), 0.06 * M_PX, CHROME)
	_m.circle(_q(1.36, 0.0, 0.95), 0.04 * M_PX, Color("f5f0dc"))
	_wheel(1.12, 0.0, 0.2)
	_arches([-0.8], 0.57, 0.26)
	_wheel(-0.8, 0.57, 0.22)


func _draw_scooter() -> void:
	_wheel(-0.62, 0.08, 0.26)
	_wheel(0.65, 0.08, 0.26)
	# Frame, footboard, seat and the delivery box on the back (plain, no branding).
	_prism([Vector2(-0.75, 0.35), Vector2(0.55, 0.35), Vector2(0.75, 0.75), Vector2(0.5, 0.95), Vector2(-0.8, 0.8)],
		-0.18, 0.18, _paint, 0.08)
	_prism([Vector2(0.6, 0.5), Vector2(0.9, 0.75), Vector2(0.75, 0.82), Vector2(0.52, 0.62)], -0.12, 0.12,
		_paint.darkened(0.15), 0.04)
	_prism([Vector2(-0.6, 0.8), Vector2(0.0, 0.8), Vector2(0.0, 0.88), Vector2(-0.6, 0.9)], -0.14, 0.14, PLASTIC, 0.03)
	_prism([Vector2(-1.0, 0.88), Vector2(-0.35, 0.88), Vector2(-0.35, 1.38), Vector2(-1.0, 1.38)], -0.26, 0.26,
		Color("d8d4cc"), 0.05)
	_side_poly([Vector2(-0.95, 1.08), Vector2(-0.4, 1.08), Vector2(-0.4, 1.16), Vector2(-0.95, 1.16)], 0.27, _accent)
	_side_line([Vector2(-1.0, 1.36), Vector2(-0.35, 1.36)], 0.27, Color(1, 1, 1, 0.3), 1.5)
	# Front forks and handlebar.
	_side_line([Vector2(0.65, 0.26), Vector2(0.52, 1.2)], 0.0, Color("2a2a30"), 4.0)
	_m.line(_q(0.52, -0.3, 1.2), _q(0.52, 0.3, 1.2), PLASTIC, 3.0, true)
	# The rider in a jacket and helmet.
	var hip := _q(-0.15, 0.1, 1.0)
	var knee := _q(0.3, 0.2, 0.95)
	var shoulder := _q(0.05, 0.1, 1.55)
	_m.line(hip, knee, Color("2b3350"), 9.0, true)
	_m.line(knee, _q(0.35, 0.2, 0.55), Color("2b3350"), 8.0, true)
	_m.line(hip, shoulder, Color("5a6a7a"), 17.0, true)
	_m.line(shoulder, _q(0.45, 0.2, 1.25), Color("5a6a7a"), 7.0, true)
	_m.circle(_q(0.48, 0.2, 1.22), 3.5, Color("c89a74"))
	var head := _q(0.1, 0.1, 1.77)
	_m.circle(head, 0.13 * M_PX, Color("1c1c20"))
	_m.colored_polygon(PackedVector2Array([head + Vector2(4 * dir, -3), head + Vector2(12 * dir, -2),
		head + Vector2(12 * dir, 5), head + Vector2(4 * dir, 6)]), Color(GLASS_SKY, 0.8))
	_m.circle(head + Vector2(-2 * dir, -5), 3.0, Color(1, 1, 1, 0.2))
	if dir > 0:
		_m.circle(_q(0.9, 0.0, 0.8), 5, CHROME)
		_m.circle(_q(0.91, 0.0, 0.8), 3.5, Color("f5f0dc"))
	else:
		_m.rect(Rect2(_q(-1.02, 0.0, 0.9) - Vector2(4, 2), Vector2(8, 4)), Color("c3372c"))


# --- Building blocks -------------------------------------------------------

## A side profile (f, h) with its corners rounded by `radius`, extruded from
## b0 to b1: the faces toward the camera, then the near side. Original edges
## listed in `glass` get a framed pane of glass.
func _prism(profile: Array, b0: float, b1: float, color: Color, radius := 0.0, glass: Array = []) -> void:
	var pts: Array = profile
	var tags: Array = range(profile.size())
	if radius > 0.0:
		var rounded := _round(profile, radius)
		pts = rounded[0]
		tags = rounded[1]
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var n := pts.size()
	for i in n:
		var p: Vector2 = pts[i]
		var q: Vector2 = pts[(i + 1) % n]
		var d := q - p
		if d.length() < 0.0001:
			continue
		var nrm := Vector2(d.y, -d.x)
		if nrm.dot((p + q) * 0.5 - c) < 0.0:
			nrm = -nrm
		# In world terms the face normal is (f*dir, 0, h); visible if it points at us.
		var world := Vector3(nrm.x * dir, 0.0, nrm.y).normalized()
		if world.x + world.z <= 0.03:
			continue
		_m.colored_polygon(PackedVector2Array([_q(p.x, b0, p.y), _q(q.x, b0, q.y), _q(q.x, b1, q.y), _q(p.x, b1, p.y)]),
			_shade(color, world))
		if glass.has(tags[i]):
			_pane(p, q, b0, b1, world)
	var side := PackedVector2Array()
	for p in pts:
		side.append(_q(p.x, b1, p.y))
	_m.colored_polygon(side, _shade(color, Vector3(0, 1, 0)))
	side.append(side[0])
	_m.polyline(side, Color(0, 0, 0, 0.12), 1.0, true)


## Framed glass across a windscreen-type face, with a light streak.
func _pane(p: Vector2, q: Vector2, b0: float, b1: float, world: Vector3) -> void:
	var p0 := p.lerp(q, 0.07)
	var p1 := p.lerp(q, 0.93)
	var lo := b0 + 0.07
	var hi := b1 - 0.07
	var dark := _shade(GLASS, world)
	var light := _shade(GLASS.lerp(GLASS_SKY, 0.6), world)
	var top_first := p1.y > p0.y
	_m.polygon(PackedVector2Array([_q(p0.x, lo, p0.y), _q(p1.x, lo, p1.y), _q(p1.x, hi, p1.y), _q(p0.x, hi, p0.y)]),
		PackedColorArray([dark, light, light, dark] if top_first else [light, dark, dark, light]))
	var s0 := lerpf(lo, hi, 0.3)
	var s1 := lerpf(lo, hi, 0.42)
	_m.colored_polygon(PackedVector2Array([_q(p0.x, s0, p0.y), _q(p1.x, s0 + 0.1, p1.y), _q(p1.x, s1 + 0.1, p1.y),
		_q(p0.x, s1, p0.y)]), Color(1, 1, 1, 0.1))


## Rounds a convex profile's corners. Returns [points, tags]: tags[k] is the
## original edge index for the straight edge from point k, -1 on the arcs.
static func _round(profile: Array, r: float, steps := 3) -> Array:
	var n := profile.size()
	var pts: Array[Vector2] = []
	var tags: Array[int] = []
	for i in n:
		var prev: Vector2 = profile[(i - 1 + n) % n]
		var c: Vector2 = profile[i]
		var next: Vector2 = profile[(i + 1) % n]
		var a := c + (prev - c).normalized() * minf(r, prev.distance_to(c) * 0.45)
		var b := c + (next - c).normalized() * minf(r, next.distance_to(c) * 0.45)
		for s in steps + 1:
			var t := float(s) / steps
			pts.append(a.lerp(c, t).lerp(c.lerp(b, t), t))
			tags.append(-1)
		tags[tags.size() - 1] = i
	return [pts, tags]


## A window on the near side: black rubber surround, glass shading from sky
## at the top to dark, and a light streak.
func _window(pts: Array, b: float) -> void:
	var c := Vector2.ZERO
	for p in pts:
		c += p
	c /= pts.size()
	var frame := PackedVector2Array()
	var glass := PackedVector2Array()
	var cols := PackedColorArray()
	var hmin := INF
	var hmax := -INF
	for p in pts:
		hmin = minf(hmin, p.y)
		hmax = maxf(hmax, p.y)
	for p in pts:
		var out: Vector2 = c + (p - c) * 1.06
		frame.append(_q(out.x, b + 0.005, out.y))
		glass.append(_q(p.x, b + 0.01, p.y))
		var t: float = (p.y - hmin) / maxf(hmax - hmin, 0.01)
		cols.append(_shade(GLASS.lerp(GLASS_SKY, 0.15 + 0.45 * t), Vector3(0, 1, 0)))
	_m.colored_polygon(frame, RUBBER)
	_m.polygon(glass, cols)
	var f0 := lerpf(pts[0].x, pts[1].x, 0.3)
	var streak := PackedVector2Array([_q(f0, b + 0.012, hmin), _q(f0 + 0.12, b + 0.012, hmin),
		_q(f0 + 0.3, b + 0.012, hmax), _q(f0 + 0.18, b + 0.012, hmax)])
	for piece in Geometry2D.intersect_polygons(glass, streak):
		_m.colored_polygon(piece, Color(1, 1, 1, 0.12))


## Polygon given in (f, h) on the side plane at b.
func _side_poly(pts: Array, b: float, color: Color) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_q(p.x, b, p.y))
	_m.colored_polygon(out, _shade(color, Vector3(0, 1, 0)))


func _side_line(pts: Array, b: float, color: Color, width: float) -> void:
	var out := PackedVector2Array()
	for p in pts:
		out.append(_q(p.x, b, p.y))
	_m.polyline(out, color, width, true)


## Rounded rectangle (f, h) around a centre with half-size.
static func _rrect(c: Vector2, half: Vector2) -> Array:
	return _rrect_pts(c - half, c + half, minf(half.x, half.y) * 0.9)


static func _rrect_pts(lo: Vector2, hi: Vector2, r: float) -> Array:
	var pts := []
	var corners := [[Vector2(hi.x - r, lo.y + r), -PI * 0.5], [Vector2(hi.x - r, hi.y - r), 0.0],
		[Vector2(lo.x + r, hi.y - r), PI * 0.5], [Vector2(lo.x + r, lo.y + r), PI]]
	for corner in corners:
		for s in 4:
			var a: float = corner[1] + PI * 0.5 * s / 3.0
			pts.append(corner[0] + Vector2(cos(a), sin(a)) * r)
	return pts


## Door mirror on a stalk, standing out from the near side.
func _mirror(f: float, b: float, h: float) -> void:
	var root := _q(f, b, h - 0.02)
	var head := _q(f - 0.04, b + 0.14, h + 0.02)
	_m.line(root, head, PLASTIC, 3.0, true)
	var shell := PackedVector2Array()
	for i in 10:
		var a := TAU * i / 10.0
		shell.append(_q(f - 0.04 + cos(a) * 0.08, b + 0.16, h + 0.04 + sin(a) * 0.06))
	_m.colored_polygon(shell, _shade(_paint, Vector3(0, 1, 0)))
	_m.colored_polygon(PackedVector2Array([shell[1], shell[3], shell[6], shell[8]]),
		_shade(GLASS.lerp(GLASS_SKY, 0.5), Vector3(0, 1, 0)))


## Dark wheel-arch openings with a painted lip on the near side.
func _arches(fs: Array, b: float, r: float) -> void:
	for f in fs:
		var pts := PackedVector2Array()
		var lip := PackedVector2Array()
		for i in 15:
			var a := PI * i / 14.0
			pts.append(_q(f + r * cos(a), b + 0.01, 0.33 + r * sin(a)))
			lip.append(_q(f + (r + 0.02) * cos(a), b + 0.012, 0.33 + (r + 0.02) * sin(a)))
		_m.colored_polygon(pts, Color("0d0e14"))
		_m.polyline(lip, _shade(_paint.lightened(0.15), Vector3(0, 1, 0)), 2.0, true)


## A wheel standing across the car at b: tyre with its tread depth, dished
## rim with five spokes, brake disc behind and a hub cap.
func _wheel(f: float, b: float, r: float) -> void:
	var outer := PackedVector2Array()
	var inner := PackedVector2Array()
	for i in 22:
		var a := TAU * i / 22.0
		outer.append(_q(f + r * cos(a), b, r + r * sin(a)))
		inner.append(_q(f + r * cos(a), b - 0.18, r + r * sin(a)))
	var hull := Geometry2D.convex_hull(outer + inner)
	_m.colored_polygon(hull, TYRE)
	_m.colored_polygon(outer, TYRE.lightened(0.06))
	if b < 0.0:
		return
	var ring := func(k: float, db: float) -> PackedVector2Array:
		var pts := PackedVector2Array()
		for i in 22:
			var a := TAU * i / 22.0
			pts.append(_q(f + r * k * cos(a), b + db, r + r * k * sin(a)))
		return pts
	_m.colored_polygon(ring.call(0.66, 0.005), _shade(RIM.darkened(0.25), Vector3(0, 1, 0)))
	_m.colored_polygon(ring.call(0.6, 0.008), _shade(Color("3a3c44"), Vector3(0, 1, 0)))
	_m.colored_polygon(ring.call(0.42, 0.009), _shade(Color("6a6e76"), Vector3(0, 1, 0)))
	for k in 5:
		var a0 := TAU * k / 5.0
		var spoke := PackedVector2Array()
		for pair in [[0.16, -0.32], [0.58, -0.14], [0.58, 0.14], [0.16, 0.32]]:
			var rr: float = pair[0] * r
			var a: float = a0 + pair[1]
			spoke.append(_q(f + rr * cos(a), b + 0.012, r + rr * sin(a)))
		_m.colored_polygon(spoke, _shade(RIM, Vector3(0, 1, 0)))
	_m.colored_polygon(ring.call(0.18, 0.014), _shade(CHROME, Vector3(0, 1, 0)))
	_m.circle(_q(f - r * 0.05, b + 0.016, r * 1.05), r * 0.05 * M_PX, Color(1, 1, 1, 0.5))


## Lamps, grille, bumper and plate on the visible end: a front if it faces
## us, a tail otherwise.
func _end_details(w: float, bumper_h: float, lamp_h: float, plate_band: Color) -> void:
	var bw := w - 0.02
	# Bumper across the end.
	_m.colored_polygon(PackedVector2Array([_e(-bw, bumper_h), _e(bw, bumper_h), _e(bw, bumper_h + 0.14),
		_e(-bw, bumper_h + 0.14)]), _shade(PLASTIC, Vector3(1, 0, 0)))
	_m.line(_e(-bw, bumper_h + 0.14), _e(bw, bumper_h + 0.14), Color(1, 1, 1, 0.15), 1.5)
	# Plate: white with the coloured band on top.
	var pb := 0.24
	var ph := bumper_h + 0.16
	_m.colored_polygon(PackedVector2Array([_e(-pb, ph), _e(pb, ph), _e(pb, ph + 0.12), _e(-pb, ph + 0.12)]), PLATE)
	_m.colored_polygon(PackedVector2Array([_e(-pb, ph + 0.085), _e(pb, ph + 0.085), _e(pb, ph + 0.12),
		_e(-pb, ph + 0.12)]), plate_band)
	for k in 5:
		var b := -0.18 + k * 0.09
		_m.line(_e(b, ph + 0.02), _e(b, ph + 0.07), Color("30343f"), 1.5)
	if dir > 0:
		# Grille with slats and a badge, then the headlights.
		var gb := w * 0.5
		_m.colored_polygon(PackedVector2Array([_e(-gb, lamp_h - 0.1), _e(gb, lamp_h - 0.1), _e(gb, lamp_h + 0.06),
			_e(-gb, lamp_h + 0.06)]), Color("15161b"))
		for k in 3:
			var h := lamp_h - 0.07 + k * 0.045
			_m.line(_e(-gb, h), _e(gb, h), Color(CHROME, 0.5), 1.2)
		_m.circle(_e(0, lamp_h - 0.02), 3.0, CHROME)
		for s in [-1.0, 1.0]:
			var c: float = s * (w - 0.2)
			var lamp := _rrect(Vector2(c, lamp_h), Vector2(0.14, 0.055))
			var outer := PackedVector2Array()
			for p in lamp:
				outer.append(_e(p.x, p.y))
			_m.colored_polygon(outer, CHROME.darkened(0.1))
			_m.circle(_e(c - s * 0.05, lamp_h), 0.045 * M_PX, Color("f4f0de"))
			_m.circle(_e(c + s * 0.07, lamp_h), 0.03 * M_PX, Color("e8962e"))
	else:
		# Tail lamps (red with an amber indicator and a white reverse light).
		for s in [-1.0, 1.0]:
			var c: float = s * (w - 0.18)
			var lamp := _rrect(Vector2(c, lamp_h), Vector2(0.15, 0.06))
			var outer := PackedVector2Array()
			for p in lamp:
				outer.append(_e(p.x, p.y))
			_m.colored_polygon(outer, Color("8e1f1a"))
			_m.colored_polygon(PackedVector2Array([_e(c - 0.12, lamp_h - 0.04), _e(c + 0.12, lamp_h - 0.04),
				_e(c + 0.12, lamp_h + 0.01), _e(c - 0.12, lamp_h + 0.01)]), Color("c3372c"))
			_m.colored_polygon(PackedVector2Array([_e(c + s * 0.04, lamp_h + 0.015), _e(c + s * 0.12, lamp_h + 0.015),
				_e(c + s * 0.12, lamp_h + 0.05), _e(c + s * 0.04, lamp_h + 0.05)]), Color("e8962e"))
		# Exhaust tail pipe under the bumper.
		_m.set_transform(_e(-w * 0.55, bumper_h - 0.02), 0.0, Vector2(1.0, 0.7))
		_m.circle(Vector2.ZERO, 3.5, Color("5a5a62"))
		_m.circle(Vector2.ZERO, 2.0, Color("15151a"))
		_m.set_transform(Vector2.ZERO)


func _draw_lamps() -> void:
	if kind == Kind.SCOOTER:
		_lamp_glow(_q(0.9 if dir > 0 else -1.02, 0.0, 0.85), 0.8)
		return
	if kind == Kind.TUKTUK:
		if dir > 0:
			_lamp_glow(_q(1.36, 0.0, 0.98), 0.9)
		else:
			for side in [-0.44, 0.44]:
				_lamp_glow(_q(-1.18, side, 0.56), 0.7)
	else:
		var w := _half_width()
		var lamp_h := 0.62
		match kind:
			Kind.MICROBUS:
				lamp_h = 0.72
			Kind.PICKUP:
				lamp_h = 0.66
		for s in [-1.0, 1.0]:
			_lamp_glow(_e(s * (w - (0.2 if dir > 0 else 0.18)), lamp_h), 1.0)
	if dir > 0:
		# Headlight beam spilling onto the road ahead.
		var ahead := _q(_length() * 0.5 + 1.8, 0, 0)
		_lamps.draw_texture_rect(_soft, Rect2(ahead - Vector2(150, 75), Vector2(300, 150)), false, Color(1, 0.95, 0.8, 0.16))


func _lamp_glow(at: Vector2, k: float) -> void:
	if dir > 0:
		_lamps.draw_texture_rect(_soft, Rect2(at - Vector2(24, 24) * k, Vector2(48, 48) * k), false, Color(1, 0.95, 0.8, 0.5))
		_lamps.draw_circle(at, 4.0 * k, StationArt.hdr(Color(1, 0.96, 0.85), 2.4))
	else:
		_lamps.draw_texture_rect(_soft, Rect2(at - Vector2(18, 18) * k, Vector2(36, 36) * k), false, Color(1, 0.15, 0.1, 0.45))
		_lamps.draw_circle(at, 3.0 * k, StationArt.hdr(Color(1, 0.2, 0.15), 2.0))


## FIFI's lighting: warm key from above-left, cool fill from our side.
func _shade(base: Color, normal: Vector3) -> Color:
	var n := normal.normalized()
	var key := maxf(n.dot(KEY_DIR.normalized()), 0.0)
	var fill := maxf(n.dot(FILL_DIR.normalized()), 0.0)
	return Color(base.r * (0.46 + 0.55 * key + 0.36 * fill), base.g * (0.46 + 0.50 * key + 0.38 * fill),
		base.b * (0.50 + 0.38 * key + 0.50 * fill), base.a)
