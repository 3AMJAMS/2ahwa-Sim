class_name StreetVehicle
extends Node3D
## One vehicle on the street, in blocks: a Cairo white taxi with its
## chequered band and roof sign, a private saloon, a white microbus with
## luggage on the rack, a pickup piled with watermelons or crates, a
## Bajaj tuk-tuk dressed in fringe and stripes, or a delivery scooter.
## Cabins are open behind tinted glass, so the driver shows through; the
## near front window can wind down for drive-by customers. Built once in
## metres (nose toward -x), scaled a touch under FIFI so the traffic doesn't
## crowd the street. Traffic moves it by setting `u` along a lane.

enum Kind { TAXI, SEDAN, MICROBUS, PICKUP, TUKTUK, SCOOTER }

const SIZE := 0.82
const GLASS := Color(0.1, 0.13, 0.24, 0.62)
const GLASS_SOLID := Color("1c2346")
const RUBBER := Color("1a1a1f")
const TYRE := Color("17171c")
const RIM := Color("a8aeb8")
const CHROME := Color("d4d9e1")
const PLASTIC := Color("2c2d33")
const PLATE := Color("ece8dc")
const SEDAN_COLORS := [Color("c0c4ca"), Color("7a1f24"), Color("1f2e4d"), Color("26272c"), Color("c9b48f"),
	Color("f0efe9"), Color("3d5a45"), Color("8a8f96"), Color("5a2a4a"), Color("b86a2a")]
const TUKTUK_COLORS := [Color("c8322b"), Color("2f5fb3"), Color("1f7a4a"), Color("d99a1e"), Color("6a2a8a")]
const STRIPE_COLORS := [Color("2f6fb3"), Color("c8322b"), Color("e0a02a"), Color("3b8a5a")]
const FRINGE := [Color("f2c230"), Color("e8433a"), Color("3bb36a"), Color("2fa4e0"), Color("f06ab0")]

signal parked

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
		position = Street3D.tile(u, lane_v, bob * 0.01)

## Drive-by customers: where to stop (u, NAN when just passing), the lane to
## pull into, and how far the near front window is wound down (0..1).
var stop_u := NAN
var park_lane := NAN
var is_parked := false
var departing := false
var window_open := 0.0:
	set(value):
		window_open = value
		if _pane:
			_pane.position.y = -window_open * _pane_drop
		if driver and _pane:
			driver.raise_arm(0, 0.45 * smoothstep(0.7, 1.0, window_open))

var driver: VoxPerson

var _body := Node3D.new()
var _pane: MeshInstance3D
var _pane_drop := 0.5
var _paint := Color.WHITE
var _accent := Color.WHITE
var _melons := false
var _rng := RandomNumberGenerator.new()
var _yaw := 0.0
var _last := Vector3.ZERO
## Where the near front window's middle is, and the roof top (vehicle space, metres).
var _window_mid := Vector3.ZERO
var _roof := 1.5


func _ready() -> void:
	_rng.randomize()
	match kind:
		Kind.TAXI, Kind.MICROBUS:
			_paint = Color("f1f1ee")
		Kind.SEDAN:
			_paint = SEDAN_COLORS[_rng.randi() % SEDAN_COLORS.size()]
		Kind.PICKUP:
			_paint = [Color("2c5aa0"), Color("e9e6df"), Color("8a2a22"), Color("3a5a3a")][_rng.randi() % 4]
		Kind.TUKTUK:
			_paint = TUKTUK_COLORS[_rng.randi() % TUKTUK_COLORS.size()]
		Kind.SCOOTER:
			_paint = [Color("c8322b"), Color("2b2b30"), Color("e9e6df"), Color("2a6ab0")][_rng.randi() % 4]
	_accent = STRIPE_COLORS[_rng.randi() % STRIPE_COLORS.size()]
	_melons = _rng.randf() < 0.5
	cur_speed = speed
	_body.scale = Vector3.ONE * SIZE
	add_child(_body)
	var v := Vox.new()
	var pane := Vox.new()
	match kind:
		Kind.TAXI, Kind.SEDAN:
			_saloon(v, pane)
		Kind.MICROBUS:
			_microbus(v, pane)
		Kind.PICKUP:
			_pickup(v, pane)
		Kind.TUKTUK:
			_tuktuk(v)
		Kind.SCOOTER:
			_scooter(v)
	v.into(_body, "Body")
	if not pane.is_empty():
		_pane = pane.into(_body, "Window")
	_yaw = 0.0 if dir < 0 else PI
	_body.rotation.y = _yaw
	_last = position


func _process(delta: float) -> void:
	# Turn into lane changes a little, like a car steering.
	var move := position - _last
	_last = position
	if move.length() > 0.0005 and delta > 0.0:
		var head := atan2(move.z, -move.x)
		_yaw = lerp_angle(_yaw, head, minf(1.0, delta * 8.0))
	_body.rotation.y = _yaw


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


## Pull over: brake smoothly to a stop at `at_u`, drifting into `lane` first.
func pull_over(at_u: float, lane: float) -> void:
	stop_u = at_u
	park_lane = lane


## Winds the near front window to `to` (0 shut, 1 open) over `time` seconds.
func roll_window(to: float, time := 0.8) -> void:
	var t := create_tween()
	t.tween_property(self, "window_open", to, time).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await t.finished


## Order done: after `delay`, maybe wind the window back up, then pull out
## into the traffic lane and drive away.
func drive_off(keep_window_open: bool, delay: float) -> void:
	await get_tree().create_timer(delay).timeout
	if not keep_window_open:
		await roll_window(0.0, 0.7)
	stop_u = NAN
	is_parked = false
	departing = true
	if not is_equal_approx(lane_v, Traffic.LANES[0][0]):
		change_lane(Traffic.LANES[0][0])


## The whole vehicle (world space), for taps and the tutorial's spotlight.
func world_aabb() -> AABB:
	var half := _length() * 0.5 * SIZE
	var w := _half_width() * SIZE
	var box := AABB(Vector3(-half, 0, -w), Vector3(half * 2.0, _roof * SIZE, w * 2.0))
	return global_transform * box


## Just above the middle of the roof (world space).
func roof_top() -> Vector3:
	return global_position + Vector3(0, _roof * SIZE + 0.1, 0)


## Middle of the near front window (world space), where drinks are handed in.
func window_centre() -> Vector3:
	return _body.global_transform * _window_mid


## Kept for Traffic's API: tint follows the scene's own lights now.
func set_light(_ambient: Color, _darkness: float) -> void:
	pass


## Length in tiles along the street, for Traffic's spacing.
func length_tiles() -> float:
	return _length() * SIZE / Street3D.TILE


func _length() -> float:
	match kind:
		Kind.MICROBUS:
			return 4.7
		Kind.PICKUP:
			return 4.9
		Kind.TUKTUK:
			return 2.72
		Kind.SCOOTER:
			return 1.8
	return 4.4


func _half_width() -> float:
	match kind:
		Kind.TUKTUK:
			return 0.66
		Kind.SCOOTER:
			return 0.3
	return 0.85


#region Building blocks

## Side profile with the wheel arches cut in along the bottom: `pts` runs
## round the top from the tail (+x) to the nose (-x); arches at `wheels`.
func _body_profile(top: Array, wheels: Array, r: float, sill := 0.3) -> PackedVector2Array:
	var out := PackedVector2Array()
	var xs: Array = wheels.duplicate()
	xs.sort()
	var first: Vector2 = top[top.size() - 1]
	var last: Vector2 = top[0]
	out.append(Vector2(first.x, sill))
	for wx in xs:
		for k in 9:
			var a := PI - PI * k / 8.0
			out.append(Vector2(wx + cos(a) * (r + 0.05), r + sin(a) * (r + 0.05) * 0.95))
	out.append(Vector2(last.x, sill))
	for p in top:
		out.append(p)
	return out


## A wheel whose centre is `z` across: a black tyre with rounded shoulders
## and a bulging sidewall, a steel wheel set into it and a chrome hubcap,
## on the outer side. Callers put the outer face flush with the body side
## (wheel_z) so the tyre reads below the sill and in the arch.
func _wheel(v: Vox, x: float, z: float, r: float, w := 0.2) -> void:
	var s := signf(z)
	var h := w * 0.5
	v.push_at(Vector3(x, r, z), Vector3(90, 0, 0))
	v.lathe([Vector2(r * 0.6, -h), Vector2(r * 0.88, -h), Vector2(r * 0.97, -h + w * 0.14), Vector2(r, -h + w * 0.32),
		Vector2(r, h - w * 0.32), Vector2(r * 0.97, h - w * 0.14), Vector2(r * 0.88, h), Vector2(r * 0.6, h)], 14, TYRE)
	# Local y runs along +z here: the outer face is +h on the +z side.
	if s > 0:
		v.cyl(Vector3(0, h - 0.012, 0), r * 0.6, r * 0.6, 0.014, RIM.darkened(0.15), 14)
		v.cyl(Vector3(0, h - 0.006, 0), r * 0.48, r * 0.46, 0.012, RIM, 14)
		v.cyl(Vector3(0, h - 0.002, 0), r * 0.24, r * 0.2, 0.012, CHROME, 10)
	else:
		v.cyl(Vector3(0, -h - 0.002, 0), r * 0.6, r * 0.6, 0.014, RIM.darkened(0.15), 14)
		v.cyl(Vector3(0, -h - 0.006, 0), r * 0.46, r * 0.48, 0.012, RIM, 14)
		v.cyl(Vector3(0, -h - 0.01, 0), r * 0.2, r * 0.24, 0.012, CHROME, 10)
	v.pop()


## Across-position for a wheel `w` wide whose outer face sits flush with a
## body side at `half_w`.
static func wheel_z(half_w: float, w := 0.2) -> float:
	return half_w - w * 0.5 + 0.004


## An open cabin behind glass: roof, pillars, windscreen, rear screen, side
## glass (the near front window goes in `pane` so it can wind down), seats
## and a dash. `base` = (windscreen foot x, rear screen foot x), `roof_x` =
## (roof front, roof back), `b_x` the B-pillar.
func _cabin(v: Vox, pane: Vox, base: Vector2, roof_x: Vector2, belt: float, roof_y: float, w: float, b_x: float,
		c_pillar := true, hip_y := 0.42) -> void:
	var gw := w - 0.02
	# Roof, rounded along its length.
	v.rbox(Vector3(roof_x.x - 0.02, roof_y - 0.06, -w), Vector3(roof_x.y + 0.02, roof_y + 0.02, w), 0.035, _paint, "x", 2)
	# Windscreen and rear screen.
	v.use("glass")
	v.quad(Vector3(base.x, belt, -gw), Vector3(base.x, belt, gw), Vector3(roof_x.x, roof_y - 0.05, gw),
		Vector3(roof_x.x, roof_y - 0.05, -gw), GLASS, Vector3(-(roof_y - belt), roof_x.x - base.x, 0))
	if c_pillar:
		v.quad(Vector3(base.y, belt, -gw), Vector3(base.y, belt, gw), Vector3(roof_x.y, roof_y - 0.05, gw),
			Vector3(roof_x.y, roof_y - 0.05, -gw), GLASS, Vector3(roof_y - belt, base.y - roof_x.y, 0))
	v.use("solid")
	# Pillars: A, B and C, each side.
	var sq := Vox.round_rect(Rect2(-0.035, -0.035, 0.07, 0.07), 0.015, 1)
	for s in [-1.0, 1.0]:
		var z: float = s * (w - 0.035)
		v.sweep(sq, [Vector3(base.x, belt, z), Vector3(roof_x.x, roof_y - 0.03, z)], _paint, Vector3.FORWARD)
		v.box(Vector3(b_x - 0.04, belt, z - 0.035), Vector3(b_x + 0.04, roof_y - 0.03, z + 0.035), _paint)
		if c_pillar:
			v.extrude(PackedVector2Array([Vector2(base.y - 0.25, belt), Vector2(base.y, belt), Vector2(roof_x.y, roof_y - 0.03),
				Vector2(roof_x.y - 0.22, roof_y - 0.03)]), "z", z - 0.035, z + 0.035, _paint)
		else:
			v.box(Vector3(base.y - 0.06, belt, z - 0.035), Vector3(base.y, roof_y - 0.03, z + 0.035), _paint)
		# Side glass; the near front pane (driver's, +z) goes in `pane`.
		var zz: float = s * gw
		var front := [Vector3(base.x + 0.06, belt + 0.02, zz), Vector3(b_x - 0.04, belt + 0.02, zz), Vector3(b_x - 0.04, roof_y - 0.06, zz),
			Vector3(roof_x.x + 0.03, roof_y - 0.06, zz)]
		var back_x := base.y - 0.25 if c_pillar else base.y - 0.06
		var rear := [Vector3(b_x + 0.04, belt + 0.02, zz), Vector3(back_x, belt + 0.02, zz),
			Vector3(roof_x.y - 0.22 if c_pillar else back_x, roof_y - 0.06, zz), Vector3(b_x + 0.04, roof_y - 0.06, zz)]
		if s > 0 and pane:
			pane.use("glass")
			pane.poly(front, GLASS, Vector3(0, 0, 1))
			pane.poly(front, GLASS, Vector3(0, 0, -1))
			_window_mid = (front[0] + front[2]) * 0.5
			_pane_drop = (roof_y - belt) * 0.95
		else:
			v.use("glass")
			v.poly(front, GLASS, Vector3(0, 0, s))
			v.use("solid")
		v.use("glass")
		v.poly(rear, GLASS, Vector3(0, 0, s))
		v.use("solid")
	# Inside: a dark cabin floor, the dash, seat backs.
	v.box(Vector3(base.x, belt - 0.02, -w + 0.05), Vector3(base.y, belt, w - 0.05), Color("1d1c21"))
	v.box(Vector3(base.x + 0.02, belt, -w + 0.06), Vector3(base.x + 0.28, belt + 0.12, w - 0.06), Color("26252b"))
	for z in [-0.35, 0.35]:
		v.box(Vector3(b_x - 0.02, belt, z - 0.22), Vector3(b_x + 0.12, belt + 0.45, z + 0.22), Color("3a3238"))
		v.box(Vector3(b_x + 0.0, belt + 0.45, z - 0.1), Vector3(b_x + 0.1, belt + 0.58, z + 0.1), Color("3a3238"))
	# Steering wheel in front of the driver (left-hand drive: the +z seat).
	v.push_at(Vector3(base.x + 0.34, belt + 0.18, 0.35), Vector3(0, 0, 60))
	v.cyl(Vector3(0, 0, 0), 0.15, 0.15, 0.025, Color("1a1a1e"), 10)
	v.pop()
	_seat_driver(Vector3(b_x - 0.18, hip_y, 0.35))


## The driver, sat with the hips at `at`.
func _seat_driver(at: Vector3) -> void:
	driver = VoxPerson.new()
	driver.rotation_degrees.y = -90
	driver.scale = Vector3.ONE * 0.9
	driver.position = at + Vector3(0, -VoxPerson.HIP * VoxPerson.U * 0.9, 0)
	_body.add_child(driver)
	var look := VoxPerson.random_look(_rng, 0.75)
	look.erase("companion")
	look.kid = false
	look.extra = []
	if look.get("head", "") in ["bread", "sunhat", "hardhat"]:
		look.head = ""
	driver.build(look, "drive")


## Lamps, bumpers and plates on both ends. `bumper` is chrome or plastic.
func _ends(v: Vox, half: float, w: float, lamp_h: float, bumper_h: float, bumper: Color, plate_band: Color) -> void:
	# Nose (-x): headlamps, indicators, grille, bumper, plate.
	var fx := -half
	for s in [-1.0, 1.0]:
		var z: float = s * (w - 0.2)
		v.box(Vector3(fx - 0.01, lamp_h - 0.08, z - 0.13), Vector3(fx + 0.02, lamp_h + 0.08, z + 0.13), CHROME)
		v.use("glow/head")
		v.box(Vector3(fx - 0.025, lamp_h - 0.06, z - 0.11), Vector3(fx - 0.01, lamp_h + 0.06, z + 0.11), Color("fff4d8"))
		v.use("solid")
		v.box(Vector3(fx - 0.02, lamp_h - 0.15, z - 0.08), Vector3(fx, lamp_h - 0.1, z + 0.08), Color("e8962e"))
	v.box(Vector3(fx - 0.015, lamp_h - 0.07, -w + 0.4), Vector3(fx, lamp_h + 0.07, w - 0.4), Color("1d1c21"))
	for k in 3:
		v.box(Vector3(fx - 0.02, lamp_h - 0.05 + k * 0.045, -w + 0.42), Vector3(fx - 0.014, lamp_h - 0.035 + k * 0.045, w - 0.42), Color("5a5a62"))
	v.rbox(Vector3(fx - 0.1, bumper_h - 0.07, -w - 0.02), Vector3(fx + 0.02, bumper_h + 0.07, w + 0.02), 0.03, bumper, "z", 1)
	v.box(Vector3(fx - 0.11, bumper_h - 0.05, -0.2), Vector3(fx - 0.1, bumper_h + 0.05, 0.2), PLATE)
	v.box(Vector3(fx - 0.112, bumper_h + 0.03, -0.2), Vector3(fx - 0.11, bumper_h + 0.05, 0.2), plate_band)
	# Tail (+x): lamps, bumper, plate.
	var rx := half
	for s in [-1.0, 1.0]:
		var z: float = s * (w - 0.18)
		v.use("glow/tail")
		v.box(Vector3(rx - 0.01, lamp_h - 0.07, z - 0.14), Vector3(rx + 0.02, lamp_h + 0.07, z + 0.14), Color("c3372c"))
		v.use("solid")
		v.box(Vector3(rx + 0.02, lamp_h - 0.07, z - s * 0.14 - 0.03), Vector3(rx + 0.025, lamp_h + 0.07, z - s * 0.14 + 0.03), Color("e8962e"))
	v.rbox(Vector3(rx - 0.02, bumper_h - 0.07, -w - 0.02), Vector3(rx + 0.1, bumper_h + 0.07, w + 0.02), 0.03, bumper, "z", 1)
	v.box(Vector3(rx, bumper_h + 0.1, -0.2), Vector3(rx + 0.02, bumper_h + 0.24, 0.2), PLATE)
	v.box(Vector3(rx + 0.02, bumper_h + 0.21, -0.2), Vector3(rx + 0.022, bumper_h + 0.24, 0.2), plate_band)


func _shadow(v: Vox, half: float, w: float) -> void:
	v.box(Vector3(-half - 0.1, 0.001, -w - 0.08), Vector3(half + 0.1, 0.004, w + 0.08), Color("3a3b42"))
	v.box(Vector3(-half + 0.1, 0.004, -w + 0.05), Vector3(half - 0.1, 0.007, w - 0.05), Color("2c2d33"))


## True when [x0, x1] misses every wheel arch's span along the car.
func _clear_of(x0: float, x1: float, arches: Array) -> bool:
	for a: Vector2 in arches:
		if x1 > a.x and x0 < a.y:
			return false
	return true


func _mirror(v: Vox, x: float, y: float, w: float) -> void:
	for s in [-1.0, 1.0]:
		v.box(Vector3(x - 0.04, y, s * w - 0.02), Vector3(x + 0.04, y + 0.03, s * (w + 0.1)), PLASTIC)
		v.box(Vector3(x - 0.06, y + 0.02, s * (w + 0.06) - 0.05), Vector3(x + 0.03, y + 0.13, s * (w + 0.06) + 0.05), PLASTIC)

#endregion


#region Kinds

func _saloon(v: Vox, pane: Vox) -> void:
	var half := 2.2
	var w := 0.85
	_shadow(v, half, w)
	var top := [Vector2(2.25, 0.6), Vector2(2.2, 0.8), Vector2(1.5, 0.86), Vector2(-1.0, 0.88), Vector2(-2.2, 0.8),
		Vector2(-2.27, 0.6), Vector2(-2.22, 0.36)]
	var prof := _body_profile(top, [-1.35, 1.35], 0.31)
	v.extrude(prof, "z", -w, w, _paint)
	for x in [-1.35, 1.35]:
		for z in [wheel_z(w), -wheel_z(w)]:
			_wheel(v, x, z, 0.31)
	_cabin(v, pane, Vector2(-1.0, 1.5), Vector2(-0.35, 0.9), 0.88, 1.45, 0.72, 0.02)
	_roof = 1.45
	# Sills (between the arches, so they don't cross the wheels), the waist
	# crease, door shut lines and handles.
	var arches := [Vector2(-1.35 - 0.37, -1.35 + 0.37), Vector2(1.35 - 0.37, 1.35 + 0.37)]
	for s in [-1.0, 1.0]:
		var z: float = s * w
		for seg in [Vector2(-2.0, arches[0].x), Vector2(arches[0].y, arches[1].x), Vector2(arches[1].y, 2.0)]:
			v.box(Vector3(seg.x, 0.3, z - s * 0.01), Vector3(seg.y, 0.37, z + s * 0.012), _paint.darkened(0.35))
		v.box(Vector3(-2.15, 0.7, z - s * 0.005), Vector3(2.15, 0.72, z + s * 0.008), _paint.lightened(0.2))
		for dx in [-1.02, 0.06, 1.25]:
			var foot := 0.38 if _clear_of(dx, dx, arches) else 0.7
			v.box(Vector3(dx - 0.006, foot, z - s * 0.004), Vector3(dx + 0.006, 0.87, z + s * 0.006), _paint.darkened(0.4))
		for hx in [-0.62, 0.72]:
			v.box(Vector3(hx - 0.1, 0.77, z), Vector3(hx + 0.1, 0.8, z + s * 0.025), CHROME.darkened(0.1))
	_mirror(v, -0.95, 0.92, w)
	if kind == Kind.TAXI:
		# Two rows of black-and-white checks along the flanks, and the roof sign.
		for s in [-1.0, 1.0]:
			var z: float = s * (w + 0.004)
			# Big enough to stay checks at the street camera's distance.
			for k in 14:
				for row in 2:
					var x0 := lerpf(-2.1, 2.1, k / 14.0)
					var x1 := lerpf(-2.1, 2.1, (k + 1) / 14.0)
					if (k + row) % 2 == 0 and _clear_of(x0, x1, arches):
						var y0 := 0.48 + row * 0.1
						v.box(Vector3(x0, y0, z - s * 0.004), Vector3(x1, y0 + 0.1, z + s * 0.003), Color("1e1e22"))
		v.rbox(Vector3(0.1, 1.46, -0.26), Vector3(0.5, 1.62, 0.26), 0.04, Color("f2d24a"), "x", 1)
		v.use("glow/sign")
		v.box(Vector3(0.14, 1.5, 0.26), Vector3(0.46, 1.58, 0.265), Color("fff2b0"))
		v.box(Vector3(0.14, 1.5, -0.265), Vector3(0.46, 1.58, -0.26), Color("fff2b0"))
		v.use("solid")
		_ends(v, half + 0.02, w, 0.62, 0.38, Color("d8d8d4"), Color("e8962e"))
	else:
		v.rod(Vector3(0.8, 1.44, -0.45), Vector3(1.1, 1.95, -0.45), 0.006, PLASTIC, 4)
		_ends(v, half + 0.02, w, 0.62, 0.38, CHROME if _rng.randf() < 0.5 else PLASTIC, Color("4b87c6"))


func _microbus(v: Vox, pane: Vox) -> void:
	var half := 2.37
	var w := 0.85
	_shadow(v, half, w)
	var cab_x := -1.25
	# Passenger box: solid, with its windows, the sliding door and a stripe.
	var top := [Vector2(2.38, 1.0), Vector2(2.3, 1.98), Vector2(cab_x, 1.98), Vector2(cab_x, 1.1)]
	v.extrude(_body_profile(top, [1.5], 0.32), "z", -w, w, _paint)
	# Cab: a flat, upright front (lamps and grille sit flush on it), a short
	# sloping bonnet up to a big windscreen, the front wheel arch.
	var nose_x := -2.37
	var cab_prof := PackedVector2Array([Vector2(cab_x + 0.01, 0.3)])
	for k in 9:
		var a := PI * k / 8.0
		cab_prof.append(Vector2(-1.6 + cos(a) * 0.37, 0.32 + sin(a) * 0.35))
	cab_prof.append_array([Vector2(nose_x + 0.05, 0.3), Vector2(nose_x, 0.38), Vector2(nose_x, 0.92), Vector2(nose_x + 0.06, 1.0),
		Vector2(-2.12, 1.1), Vector2(cab_x + 0.01, 1.1)])
	v.extrude(cab_prof, "z", -w, w, _paint)
	_cabin(v, pane, Vector2(-2.12, cab_x), Vector2(-1.82, cab_x), 1.1, 1.98, 0.82, -1.45, false, 0.85)
	_roof = 2.3
	for x in [-1.6, 1.5]:
		for z in [wheel_z(w), -wheel_z(w)]:
			_wheel(v, x, z, 0.32)
	for s in [-1.0, 1.0]:
		var z: float = s * (w + 0.004)
		for win in [[-1.1, -0.35], [-0.25, 0.5], [0.6, 1.35], [1.45, 2.15]]:
			v.box(Vector3(win[0], 1.26, z - s * 0.006), Vector3(win[1], 1.82, z + s * 0.002), GLASS_SOLID)
			v.box(Vector3(win[0] + 0.05, 1.7, z), Vector3(win[0] + 0.15, 1.78, z + s * 0.003), GLASS_SOLID.lerp(Color("8fb0d8"), 0.4))
			# Passengers' heads in the windows.
			if _rng.randf() < 0.6:
				var hx: float = lerpf(win[0], win[1], _rng.randf_range(0.3, 0.7))
				v.box(Vector3(hx - 0.1, 1.42, z - s * 0.2), Vector3(hx + 0.1, 1.66, z - s * 0.01),
					Color(VoxPerson.SKINS[_rng.randi() % VoxPerson.SKINS.size()]).darkened(0.35))
		v.box(Vector3(-2.3, 1.02, z - s * 0.005), Vector3(2.38, 1.08, z + s * 0.004), _accent)
		v.box(Vector3(-2.32, 0.88, z - s * 0.005), Vector3(2.38, 0.92, z + s * 0.004), _accent.darkened(0.25))
		for x in [-1.2, 0.4, 1.4]:
			var foot := 0.36 if _clear_of(x, x, [Vector2(-1.97, -1.23), Vector2(1.13, 1.87)]) else 0.7
			v.box(Vector3(x - 0.006, foot, z - s * 0.004), Vector3(x + 0.006, 1.86, z + s * 0.006), _paint.darkened(0.3))
		v.box(Vector3(-0.35, 0.3, z - s * 0.01), Vector3(0.4, 0.36, z + s * 0.03), PLASTIC)
	_mirror(v, -2.0, 1.25, w)
	# Roof rack with rails and a roped bundle of luggage.
	for zz in [-0.55, 0.55]:
		v.box(Vector3(-1.2, 2.04, zz - 0.02), Vector3(2.0, 2.07, zz + 0.02), PLASTIC)
		for x in [-1.0, 0.2, 1.4]:
			v.box(Vector3(x - 0.02, 1.98, zz - 0.02), Vector3(x + 0.02, 2.06, zz + 0.02), PLASTIC)
	v.rbox(Vector3(-0.6, 2.07, -0.48), Vector3(1.3, 2.36, 0.48), 0.06, Color("8a6a4a"), "x", 1)
	v.box(Vector3(0.2, 2.36, -0.3), Vector3(0.9, 2.5, 0.3), Color("2a4a8a"))
	for x in [-0.2, 0.6]:
		v.box(Vector3(x - 0.015, 2.07, -0.49), Vector3(x + 0.015, 2.38, 0.49), Color("3a2a1c"))
	# Ladder up the back.
	for z in [-0.62, -0.4]:
		v.box(Vector3(2.38, 0.9, z - 0.015), Vector3(2.42, 1.98, z + 0.015), PLASTIC)
	for k in 6:
		v.box(Vector3(2.38, 1.0 + k * 0.17, -0.62), Vector3(2.42, 1.02 + k * 0.17, -0.4), PLASTIC)
	_ends(v, half, w, 0.72, 0.36, Color("d8d8d4"), Color("c8322b"))


func _pickup(v: Vox, pane: Vox) -> void:
	var half := 2.45
	var w := 0.85
	_shadow(v, half, w)
	var top := [Vector2(2.5, 0.72), Vector2(2.45, 0.76), Vector2(-2.3, 0.78), Vector2(-2.5, 0.7), Vector2(-2.47, 0.4)]
	v.extrude(_body_profile(top, [-1.55, 1.5], 0.33, 0.35), "z", -w, w, _paint)
	for x in [-1.55, 1.5]:
		for z in [wheel_z(w), -wheel_z(w)]:
			_wheel(v, x, z, 0.33)
	# Cab over the front half.
	v.extrude(PackedVector2Array([Vector2(0.15, 0.76), Vector2(-1.3, 0.76), Vector2(-1.3, 1.1), Vector2(0.15, 1.1)]), "z", -w, w, _paint)
	_cabin(v, pane, Vector2(-1.3, 0.15), Vector2(-0.75, 0.12), 1.1, 1.74, 0.8, -0.1, false, 0.62)
	_roof = 1.74
	# The bed: floor, walls, tailgate, and the load.
	var back := 2.42
	var front := 0.2
	v.box(Vector3(front, 0.76, -w + 0.06), Vector3(back, 0.8, w - 0.06), _paint.darkened(0.6))
	for s in [-1.0, 1.0]:
		v.box(Vector3(front, 0.76, s * w - 0.06 * (1.0 + s) * 0.5), Vector3(back, 1.06, s * w + 0.06 * (1.0 - s) * 0.5 - 0.06 * s),
			_paint)
	v.box(Vector3(back - 0.06, 0.76, -w), Vector3(back, 1.06, w), _paint.darkened(0.05))
	v.box(Vector3(front - 0.02, 0.76, -w), Vector3(front + 0.04, 1.14, w), _paint.darkened(0.1))
	for s in [-1.0, 1.0]:
		v.box(Vector3(front, 1.04, s * w - 0.01), Vector3(back, 1.07, s * w + 0.01), _paint.lightened(0.2))
		var p_arches := [Vector2(-1.55 - 0.39, -1.55 + 0.39), Vector2(1.5 - 0.39, 1.5 + 0.39)]
		for seg in [Vector2(-2.3, p_arches[0].x), Vector2(p_arches[0].y, p_arches[1].x), Vector2(p_arches[1].y, 2.3)]:
			v.box(Vector3(seg.x, 0.35, s * w - 0.01), Vector3(seg.y, 0.42, s * w + s * 0.012), _paint.darkened(0.35))
	for k in 9:
		var row := floori(k / 3.0)
		var x := lerpf(back - 0.4, front + 0.4, (k % 3) / 2.0) + (0.15 if row == 1 else 0.0)
		var z := -0.45 + row * 0.45
		var y := 0.98 + (0.22 if row == 1 else 0.0)
		if _melons:
			v.ball(Vector3(x, y, z), Vector3(0.3, 0.2, 0.22), Color("2f6a2c"), 8, 4)
			for st in [-0.12, 0.0, 0.12]:
				v.box(Vector3(x - 0.28, y + 0.1, z + st - 0.015), Vector3(x + 0.28, y + 0.2, z + st + 0.015), Color("1f4a1e"))
		else:
			v.box(Vector3(x - 0.24, y - 0.18, z - 0.2), Vector3(x + 0.24, y + 0.08, z + 0.2), Color("b88a4a"))
			v.box(Vector3(x - 0.245, y - 0.08, z - 0.205), Vector3(x + 0.245, y - 0.06, z + 0.205), Color("7a5a2e"))
			for o in 4:
				v.ball(Vector3(x - 0.12 + (o % 2) * 0.24, y + 0.12, z - 0.09 + (o / 2) * 0.18), Vector3(0.1, 0.09, 0.1),
					Color("f28c1e"), 6, 3)
	_mirror(v, -1.15, 1.18, w)
	_ends(v, half + 0.03, w, 0.62, 0.42, CHROME, Color("c8322b"))


## A Bajaj RE-style tuk-tuk: narrow nose over the single front wheel, open
## sides, a tall windscreen, a vinyl roof with a coloured band and fringe.
func _tuktuk(v: Vox) -> void:
	var roof := Color("1f1f24")
	var trim := _paint.lightened(0.12)
	var w := 0.64
	_shadow(v, 1.4, w)
	_wheel(v, -1.12, 0.0, 0.2, 0.14)
	for z in [0.6, -0.6]:
		_wheel(v, 0.78, z, 0.2, 0.14)
	# Floor pan tapering to the nose, the cowl up to the windscreen.
	v.extrude(PackedVector2Array([Vector2(1.32, 0.28), Vector2(-0.95, 0.28), Vector2(-1.2, 0.42), Vector2(-1.18, 0.56),
		Vector2(1.32, 0.56)]), "z", -w, w, _paint)
	v.extrude(PackedVector2Array([Vector2(-0.9, 0.5), Vector2(-1.22, 0.42), Vector2(-1.34, 0.62), Vector2(-1.3, 0.95),
		Vector2(-1.12, 1.04), Vector2(-0.9, 1.04)]), "z", -0.3, 0.3, _paint)
	v.box(Vector3(-1.36, 0.72, -0.08), Vector3(-1.32, 0.88, 0.08), CHROME)
	v.use("glow/head")
	v.box(Vector3(-1.37, 0.75, -0.06), Vector3(-1.36, 0.85, 0.06), Color("fff4d8"))
	v.use("solid")
	v.box(Vector3(-1.34, 0.9, -0.28), Vector3(-1.3, 0.94, -0.2), Color("e8962e"))
	v.box(Vector3(-1.34, 0.9, 0.2), Vector3(-1.3, 0.94, 0.28), Color("e8962e"))
	# Windscreen in its black frame, roof posts.
	v.box(Vector3(-1.2, 1.04, -0.5), Vector3(-1.1, 1.08, 0.5), PLASTIC)
	v.use("glass")
	v.quad(Vector3(-1.14, 1.08, -0.46), Vector3(-1.14, 1.08, 0.46), Vector3(-1.2, 1.52, 0.46), Vector3(-1.2, 1.52, -0.46),
		GLASS, Vector3(-1, 0.1, 0))
	v.use("solid")
	for s in [-1.0, 1.0]:
		v.rod(Vector3(-1.13, 1.04, s * 0.5), Vector3(-1.2, 1.56, s * 0.52), 0.02, PLASTIC, 4)
		v.rod(Vector3(0.35, 0.56, s * 0.64), Vector3(0.3, 1.52, s * 0.6), 0.015, CHROME, 4)
	# Bench seat and backrest at the back, the driver's seat forward.
	v.box(Vector3(0.4, 0.56, -0.56), Vector3(1.05, 0.86, 0.56), Color("6e2a22"))
	v.box(Vector3(1.02, 0.86, -0.56), Vector3(1.14, 1.3, 0.56), Color("6e2a22"))
	v.box(Vector3(-0.55, 0.56, -0.18), Vector3(-0.2, 0.82, 0.18), PLASTIC)
	v.box(Vector3(-0.95, 1.0, -0.3), Vector3(-0.88, 1.03, 0.3), PLASTIC)
	# Back panel with tail lamps and plate; vinyl wrapping down over it.
	v.box(Vector3(1.16, 0.56, -w), Vector3(1.34, 1.0, w), trim)
	v.box(Vector3(1.18, 1.0, -w), Vector3(1.36, 1.56, w), roof)
	v.use("glass")
	v.quad(Vector3(1.365, 1.18, -0.3), Vector3(1.365, 1.18, 0.3), Vector3(1.365, 1.42, 0.26), Vector3(1.365, 1.42, -0.26),
		GLASS, Vector3.RIGHT)
	v.use("solid")
	for s in [-1.0, 1.0]:
		v.use("glow/tail")
		v.box(Vector3(1.34, 0.7, s * 0.49 - 0.07), Vector3(1.35, 0.84, s * 0.49 + 0.07), Color("a3261f"))
		v.use("solid")
	v.box(Vector3(1.34, 0.62, -0.2), Vector3(1.35, 0.74, 0.2), PLATE)
	v.box(Vector3(1.34, 0.88, -0.3), Vector3(1.35, 0.96, 0.3), _accent.lightened(0.2))
	# Roof with its band and the fringe.
	v.rbox(Vector3(-1.34, 1.52, -0.66), Vector3(1.36, 1.7, 0.66), 0.06, roof, "x", 2)
	for s in [-1.0, 1.0]:
		v.box(Vector3(-1.3, 1.53, s * 0.665 - 0.005), Vector3(1.3, 1.6, s * 0.665 + 0.005), _accent)
		for k in 16:
			var x := lerpf(-1.25, 1.2, k / 15.0)
			v.box(Vector3(x - 0.03, 1.44, s * 0.67 - 0.01), Vector3(x + 0.03, 1.53, s * 0.67 + 0.01), FRINGE[k % FRINGE.size()])
			v.cube(Vector3(x, 1.42, s * 0.67), Vector3(0.035, 0.035, 0.035), FRINGE[(k + 2) % FRINGE.size()])
	# Side stripes and chrome strip, a sticker.
	for s in [-1.0, 1.0]:
		v.box(Vector3(-0.95, 0.36, s * w - 0.005), Vector3(1.28, 0.45, s * w + s * 0.008), _accent)
		v.box(Vector3(-1.1, 0.5, s * w - 0.005), Vector3(1.28, 0.53, s * w + s * 0.01), CHROME)
	_roof = 1.72
	# The driver at the handlebar.
	driver = VoxPerson.new()
	driver.rotation_degrees.y = -90
	driver.scale = Vector3.ONE * 0.85
	driver.position = Vector3(-0.38, 0.62 - VoxPerson.HIP * VoxPerson.U * 0.85, 0)
	_body.add_child(driver)
	var look := VoxPerson.random_look(_rng, 1.0)
	look.erase("companion")
	look.kid = false
	look.extra = []
	look.head = ""
	driver.build(look, "drive")
	driver.raise_arm(0, 0.5)
	driver.raise_arm(1, 0.5)


func _scooter(v: Vox) -> void:
	_shadow(v, 0.9, 0.3)
	_wheel(v, -0.65, 0.0, 0.26, 0.1)
	_wheel(v, 0.62, 0.0, 0.26, 0.1)
	v.extrude(PackedVector2Array([Vector2(0.75, 0.35), Vector2(-0.55, 0.35), Vector2(-0.75, 0.75), Vector2(-0.5, 0.95),
		Vector2(0.8, 0.8)]), "z", -0.17, 0.17, _paint)
	v.extrude(PackedVector2Array([Vector2(-0.6, 0.5), Vector2(-0.9, 0.75), Vector2(-0.75, 0.82), Vector2(-0.52, 0.62)]), "z", -0.12, 0.12,
		_paint.darkened(0.15))
	v.box(Vector3(0.0, 0.8, -0.14), Vector3(0.6, 0.9, 0.14), PLASTIC)
	# Delivery box on the back.
	v.box(Vector3(0.35, 0.88, -0.26), Vector3(1.0, 1.38, 0.26), Color("d8d4cc"))
	v.box(Vector3(0.35, 1.08, -0.265), Vector3(1.0, 1.16, 0.265), _accent)
	v.rod(Vector3(-0.65, 0.26, 0), Vector3(-0.52, 1.2, 0), 0.025, Color("2a2a30"), 5)
	v.box(Vector3(-0.54, 1.18, -0.3), Vector3(-0.5, 1.22, 0.3), PLASTIC)
	v.use("glow/head")
	v.box(Vector3(-0.92, 0.76, -0.05), Vector3(-0.9, 0.84, 0.05), Color("fff4d8"))
	v.use("glow/tail")
	v.box(Vector3(1.0, 0.95, -0.06), Vector3(1.02, 1.0, 0.06), Color("c3372c"))
	v.use("solid")
	_roof = 1.85
	driver = VoxPerson.new()
	driver.rotation_degrees.y = -90
	driver.position = Vector3(0.12, 0.9 - VoxPerson.HIP * VoxPerson.U, 0)
	_body.add_child(driver)
	var look := VoxPerson.random_look(_rng, 1.0)
	look.erase("companion")
	look.kid = false
	look.extra = []
	look.head = "moto"
	look.top = "jacket"
	look.robe = ""
	look.cloth = _accent
	driver.build(look, "sit")
	driver.raise_arm(0, 0.55)
	driver.raise_arm(1, 0.55)

#endregion
