class_name SidewalkFurniture
extends Node2D
## Sayed's pitch on the pavement beside FIFI: his folding lawn chair with
## woven strips by the car, and for customers two monobloc plastic chairs
## round a little woven-look plastic stool doing duty as the table, with two
## glasses of tea on it. Drawn once in FIFI's projection (WorldHost places it
## on FIFI's origin) and redrawn only when the time of day changes.

## Matches FIFI's world axes and scale: x toward the car's rear, y toward the
## viewer, z up; one unit is about 1.2 cm.
const SCALE := 1.3
## Pavement height (WorldHost's PAVEMENT_RISE in these units).
const Z_GROUND := 8.0
const KEY_DIR := Vector3(-0.3, -0.25, 1.0)
const FILL_DIR := Vector3(0.35, 1.0, 0.45)

const COLOR_ALU := Color("c9ced6")
const WEB_A := Color("2f8a4c")
const WEB_B := Color("eeeae0")
const COLOR_CHAIR_RED := Color("c7362e")
const COLOR_CHAIR_WHITE := Color("e9e6df")
const COLOR_STOOL := Color("7a4a2a")
const COLOR_TEA := Color("a8461c")

var ambient := Color.WHITE:
	set(value):
		ambient = value
		queue_redraw()


func _draw() -> void:
	# Far to near, so nearer pieces overlap farther ones.
	_lawn_chair(Vector3(52, 150, Z_GROUND))
	_monobloc(Vector3(206, 160, Z_GROUND), 1.0, COLOR_CHAIR_RED)
	_stool(Vector3(240, 166, Z_GROUND))
	_monobloc(Vector3(276, 168, Z_GROUND), -1.0, COLOR_CHAIR_WHITE)


static func iso(p: Vector3) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5 - p.z) * SCALE


## Sayed's folding chair: aluminium tube frame, green-and-white woven strips,
## leaning back, side-on to us and facing his customers at the trunk (+x).
func _lawn_chair(at: Vector3) -> void:
	_shadow(at, Vector2(30, 22))
	# Local frame: a = forward (+x), b = across (+y, toward us), z up.
	var p := func(a: float, b: float, z: float) -> Vector3: return at + Vector3(a, b, z)
	# Reclined back first: it is the farthest part.
	var back := [p.call(-12, -17, 22), p.call(-12, 17, 22), p.call(-30, 17, 80), p.call(-30, -17, 80)]
	_webbing(back, 9, Vector3(1, 0, 0.35))
	_frame(back)
	# Far side of the X-frame, then the sagging woven seat, then the near side.
	_x_frame(p, -19.0)
	var seat := [p.call(16, -17, 28), p.call(16, 17, 28), p.call(-12, 17, 22), p.call(-12, -17, 22)]
	_webbing(seat, 7, Vector3(0, 0, 1))
	_frame(seat)
	_x_frame(p, 19.0)
	# His tea glass on the pavement by the chair.
	_tea_glass(at + Vector3(30, 14, 0))


## One side of the lawn chair's folding frame: crossed legs, armrest and post.
func _x_frame(p: Callable, b: float) -> void:
	_tube(p.call(18, b, 0), p.call(-8, b, 26), COLOR_ALU)
	_tube(p.call(-22, b, 0), p.call(12, b, 28), COLOR_ALU)
	_tube(p.call(-20, b, 50), p.call(16, b, 44), COLOR_ALU.darkened(0.08), 3.6)
	_tube(p.call(16, b, 44), p.call(16, b, 28), COLOR_ALU)


## The monobloc plastic chair every ahwa has. `face` is ±1: the way the seat
## faces along x.
func _monobloc(at: Vector3, face: float, color: Color) -> void:
	_shadow(at, Vector2(24, 22))
	var p := func(a: float, b: float, z: float) -> Vector3: return at + Vector3(a * face, b, z)
	var legs := [[16.0, -17.0], [16.0, 17.0], [-16.0, -17.0], [-16.0, 17.0]]
	# Farther legs (−y) first, near ones after the seat.
	var back := [p.call(-16, -17, 36), p.call(-16, 17, 36), p.call(-23, 18, 76), p.call(-23, -18, 76)]
	if face > 0.0:
		_back(back, color, face)
	for l in legs:
		if l[1] < 0.0:
			_tube(p.call(l[0] * 1.12, l[1] * 1.08, 0), p.call(l[0], l[1], 35), color.darkened(0.12), 5.0)
	var seat := [p.call(17, -17, 37), p.call(17, 17, 37), p.call(-16, 17, 36), p.call(-16, -17, 36)]
	_face(seat, color.lightened(0.05), Vector3(0, 0, 1))
	# Rolled front lip of the seat.
	_line(p.call(17, -17, 36), p.call(17, 17, 36), color.darkened(0.2), 3.0)
	for l in legs:
		if l[1] > 0.0:
			_tube(p.call(l[0] * 1.12, l[1] * 1.08, 0), p.call(l[0], l[1], 35), color, 5.0)
	# Armrests sweep from the back down to the front of the seat.
	for b in [-18.0, 18.0]:
		_line(p.call(-19, b, 56), p.call(14, b, 50), color.darkened(0.05), 4.0)
		_line(p.call(14, b, 50), p.call(16, b, 37), color.darkened(0.1), 4.0)
	if face < 0.0:
		_back(back, color, face)


## Monobloc backrest with its moulded slots.
func _back(q: Array, color: Color, face: float) -> void:
	_face(q, color, Vector3(-face, 0, 0.3))
	var qa: Vector3 = q[0]
	var qb: Vector3 = q[1]
	var qc: Vector3 = q[2]
	var qd: Vector3 = q[3]
	for k in range(1, 5):
		var t := k / 5.0
		var lo := qa.lerp(qb, t).lerp(qd.lerp(qc, t), 0.3)
		var hi := qa.lerp(qb, t).lerp(qd.lerp(qc, t), 0.8)
		_line(lo, hi, color.darkened(0.55), 3.0)
	_line(qd, qc, color.lightened(0.15), 3.0)


## Brown plastic stool moulded to look like woven rattan, with a rounded
## hand-hole in each side; tapered, wider at the foot.
func _stool(at: Vector3) -> void:
	_shadow(at, Vector2(20, 16))
	var h := 28.0
	var lo := Vector2(17, 13)
	var hi := Vector2(14, 11)
	var b0 := [at + Vector3(-lo.x, -lo.y, 0), at + Vector3(lo.x, -lo.y, 0), at + Vector3(lo.x, lo.y, 0), at + Vector3(-lo.x, lo.y, 0)]
	var b1 := [at + Vector3(-hi.x, -hi.y, h), at + Vector3(hi.x, -hi.y, h), at + Vector3(hi.x, hi.y, h), at + Vector3(-hi.x, hi.y, h)]
	# Visible sides: +x (rear) and +y (near).
	_stool_side([b0[1], b0[2], b1[2], b1[1]], Vector3(1, 0, 0.1))
	_stool_side([b0[3], b0[2], b1[2], b1[3]], Vector3(0, 1, 0.1))
	_face(b1, COLOR_STOOL.lightened(0.08), Vector3(0, 0, 1))
	_weave(b1, Vector3(0, 0, 1), 6)
	var rim := _project(b1)
	rim.append(rim[0])
	draw_polyline(rim, _shade(COLOR_STOOL.lightened(0.3), Vector3(0, 0, 1)), 1.6, true)
	# Two glasses of tea on it.
	_tea_glass(at + Vector3(-5, -3, h))
	_tea_glass(at + Vector3(6, 3, h))


func _stool_side(q: Array, n: Vector3) -> void:
	_face(q, COLOR_STOOL, n)
	_weave(q, n, 7)
	# Rounded hand-hole, dark with the stool's shadowed inside.
	var qa: Vector3 = q[0]
	var qb: Vector3 = q[1]
	var qc: Vector3 = q[2]
	var qd: Vector3 = q[3]
	var hole := PackedVector2Array()
	for i in 20:
		var ang := TAU * i / 20.0
		# Superellipse: a rectangle with well-rounded corners.
		var cx := signf(cos(ang)) * pow(absf(cos(ang)), 0.5)
		var cy := signf(sin(ang)) * pow(absf(sin(ang)), 0.5)
		var s := 0.5 + cx * 0.28
		var t := 0.52 + cy * 0.14
		hole.append(iso(qa.lerp(qb, s).lerp(qd.lerp(qc, s), t)))
	draw_colored_polygon(hole, _shade(COLOR_STOOL.darkened(0.7), n))


## Criss-cross moulded weave over a face.
func _weave(q: Array, n: Vector3, lines: int) -> void:
	var qa: Vector3 = q[0]
	var qb: Vector3 = q[1]
	var qc: Vector3 = q[2]
	var qd: Vector3 = q[3]
	var col := _shade(COLOR_STOOL.darkened(0.3), n)
	var pts := PackedVector2Array()
	for k in range(1, lines):
		var t := float(k) / lines
		pts.append(iso(qa.lerp(qb, t)))
		pts.append(iso(qd.lerp(qc, t)))
		pts.append(iso(qa.lerp(qd, t)))
		pts.append(iso(qb.lerp(qc, t)))
	draw_multiline(pts, Color(col, 0.55), 1.2)


## Plastic strips woven over a frame, alternating colours.
func _webbing(q: Array, strips: int, n: Vector3) -> void:
	var qa: Vector3 = q[0]
	var qb: Vector3 = q[1]
	var qc: Vector3 = q[2]
	var qd: Vector3 = q[3]
	for k in strips:
		var t0 := float(k) / strips
		var t1 := float(k + 1) / strips
		_face([qa.lerp(qd, t0), qb.lerp(qc, t0), qb.lerp(qc, t1), qa.lerp(qd, t1)], WEB_A if k % 2 == 0 else WEB_B, n)
	for k in range(1, 4):
		var t := k / 4.0
		_line(qa.lerp(qb, t), qd.lerp(qc, t), Color(0, 0, 0, 0.2), 1.0)


func _frame(q: Array) -> void:
	var pts := _project(q)
	pts.append(pts[0])
	draw_polyline(pts, _shade(COLOR_ALU, Vector3(0, 0.6, 1)), 2.6, true)


## An Egyptian tea glass: small, clear, tea two-thirds up, a spoon in it.
func _tea_glass(at: Vector3) -> void:
	var top := iso(at + Vector3(0, 0, 11))
	var base := iso(at)
	var w := 3.6 * SCALE
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.85, 0), base + Vector2(w * 0.85, 0),
		top + Vector2(w, 0), top + Vector2(-w, 0)]), Color(0.85, 0.92, 1.0, 0.35))
	var tea := base.lerp(top, 0.7)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.8, 0), base + Vector2(w * 0.8, 0),
		tea + Vector2(w * 0.95, 0), tea + Vector2(-w * 0.95, 0)]), COLOR_TEA * ambient)
	draw_line(tea + Vector2(1, 0), top + Vector2(3, -5), Color(0.8, 0.82, 0.86) * ambient, 1.2)
	draw_line(top + Vector2(-w, 0), top + Vector2(w, 0), Color(1, 1, 1, 0.5), 1.0)


func _tube(a: Vector3, b: Vector3, color: Color, width := 3.0) -> void:
	draw_line(iso(a), iso(b), _shade(color, Vector3(0, 0.6, 0.8)), width, true)


## A line in an unshaded colour, tinted by the time of day.
func _line(a: Vector3, b: Vector3, color: Color, width: float) -> void:
	draw_line(iso(a), iso(b), color * Color(ambient, 1.0), width, true)


func _face(q: Array, color: Color, n: Vector3) -> void:
	draw_colored_polygon(_project(q), _shade(color, n))


func _shadow(at: Vector3, r: Vector2) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(iso(at + Vector3(cos(a) * r.x, sin(a) * r.y, 0)))
	draw_colored_polygon(pts, Color(0, 0, 0, 0.22))


static func _project(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(iso(p))
	return out


## Same lighting as FIFI: warm key from the streetlights, cool fill.
func _shade(base: Color, normal: Vector3) -> Color:
	var n := normal.normalized()
	var key := maxf(n.dot(KEY_DIR.normalized()), 0.0)
	var fill := maxf(n.dot(FILL_DIR.normalized()), 0.0)
	return Color(
		base.r * (0.46 + 0.55 * key + 0.36 * fill) * ambient.r,
		base.g * (0.46 + 0.50 * key + 0.38 * fill) * ambient.g,
		base.b * (0.50 + 0.38 * key + 0.50 * fill) * ambient.b,
		base.a)
