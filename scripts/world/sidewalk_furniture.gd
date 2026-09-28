class_name SidewalkFurniture
extends Node2D
## Sayed's spot on the pavement beside FIFI: his folding lawn chair (aluminium
## tube frame, green-and-white woven plastic strips, plastic armrest pads),
## a glass of tea on its saucer and his little transistor radio. Customer
## seating (plastic chairs, stool table) comes later as an upgrade.
## Drawn once in FIFI's projection (WorldHost places it on FIFI's origin) and
## redrawn only when the time of day changes.

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
const COLOR_PAD := Color("2a2a30")
const COLOR_TEA := Color("a8461c")
const COLOR_RADIO := Color("7a2e22")
const CHROME_KNOB := Color("d4d9e1")

var ambient := Color.WHITE:
	set(value):
		ambient = value
		queue_redraw()


func _draw() -> void:
	_lawn_chair(Vector3(52, 150, Z_GROUND))


static func iso(p: Vector3) -> Vector2:
	return Vector2(p.x - p.y, (p.x + p.y) * 0.5 - p.z) * SCALE


## Sayed's folding chair, side-on to us and facing the trunk (+x).
func _lawn_chair(at: Vector3) -> void:
	_shadow(at, Vector2(32, 24), 0.18)
	_shadow(at, Vector2(22, 16), 0.14)
	var p := func(a: float, b: float, z: float) -> Vector3: return at + Vector3(a, b, z)
	# Radio on the pavement behind the chair, farthest from us.
	_radio(at + Vector3(-34, -10, 0))
	# Reclined back first: it is the farthest part.
	var back := [p.call(-12, -17, 22), p.call(-12, 17, 22), p.call(-30, 17, 80), p.call(-30, -17, 80)]
	_webbing(back, 10, 6, Vector3(1, 0, 0.35))
	_frame(back)
	# Far side of the X-frame, then the sagging woven seat, then the near side.
	_x_frame(p, -19.0)
	var seat := [p.call(16, -17, 28), p.call(16, 17, 28), p.call(-12, 17, 22), p.call(-12, -17, 22)]
	_webbing(seat, 7, 6, Vector3(0, 0, 1))
	_frame(seat)
	# Cross bar under the seat front.
	_tube(p.call(16, -19, 26), p.call(16, 19, 26), COLOR_ALU)
	_x_frame(p, 19.0)
	# Tea on a saucer beside it.
	_tea_glass(at + Vector3(30, 16, 0))


## One side of the chair's folding frame: crossed legs with a rivet where they
## pivot, rubber feet, the armrest with its pad, and the front post.
func _x_frame(p: Callable, b: float) -> void:
	var leg_a: Array = [p.call(18, b, 0), p.call(-8, b, 26)]
	var leg_b: Array = [p.call(-22, b, 0), p.call(12, b, 28)]
	_tube(leg_a[0], leg_a[1], COLOR_ALU)
	_tube(leg_b[0], leg_b[1], COLOR_ALU)
	for foot in [leg_a[0], leg_b[0]]:
		draw_circle(iso(foot), 2.6, COLOR_PAD * Color(ambient, 1.0))
	draw_circle(iso(p.call(1, b, 12.5)), 1.8, _shade(COLOR_ALU.darkened(0.3), Vector3(0, 1, 0)))
	_tube(p.call(16, b, 44), p.call(16, b, 28), COLOR_ALU)
	_tube(p.call(-20, b, 50), p.call(16, b, 44), COLOR_ALU.darkened(0.08), 3.6)
	# Plastic pad along the armrest.
	var pad := [p.call(-12, b - 2.5, 49.5), p.call(12, b - 2.5, 45.5), p.call(12, b + 2.5, 45.5), p.call(-12, b + 2.5, 49.5)]
	_face(pad, COLOR_PAD, Vector3(0, 0, 1))
	_line(pad[3], pad[2], COLOR_PAD.lightened(0.3), 1.2)


## Plastic strips over a frame: bands one way in alternating colours, then
## thinner cross strips woven over them.
func _webbing(q: Array, bands: int, cross: int, n: Vector3) -> void:
	var qa: Vector3 = q[0]
	var qb: Vector3 = q[1]
	var qc: Vector3 = q[2]
	var qd: Vector3 = q[3]
	for k in bands:
		var t0 := float(k) / bands
		var t1 := float(k + 1) / bands
		_face([qa.lerp(qd, t0), qb.lerp(qc, t0), qb.lerp(qc, t1), qa.lerp(qd, t1)], WEB_A if k % 2 == 0 else WEB_B, n)
		_line(qa.lerp(qd, t1), qb.lerp(qc, t1), Color(0, 0, 0, 0.18), 1.0)
	for k in cross:
		var s0 := (k + 0.3) / cross
		var s1 := (k + 0.7) / cross
		for j in bands:
			if (j + k) % 2 != 0:
				continue
			var t0 := float(j) / bands
			var t1 := float(j + 1) / bands
			_face([qa.lerp(qb, s0).lerp(qd.lerp(qc, s0), t0), qa.lerp(qb, s1).lerp(qd.lerp(qc, s1), t0),
				qa.lerp(qb, s1).lerp(qd.lerp(qc, s1), t1), qa.lerp(qb, s0).lerp(qd.lerp(qc, s0), t1)],
				WEB_B if k % 2 == 0 else WEB_A.lightened(0.1), n)


## Aluminium frame tube round a panel, with a highlight along it.
func _frame(q: Array) -> void:
	var pts := _project(q)
	pts.append(pts[0])
	draw_polyline(pts, _shade(COLOR_ALU.darkened(0.2), Vector3(0, 0.6, 1)), 3.2, true)
	draw_polyline(pts, _shade(COLOR_ALU.lightened(0.2), Vector3(0, 0.6, 1)), 1.2, true)


## An Egyptian tea glass on a small saucer: tea two-thirds up, a spoon in it.
func _tea_glass(at: Vector3) -> void:
	var saucer := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		saucer.append(iso(at + Vector3(cos(a) * 6.5, sin(a) * 6.5, 1)))
	draw_colored_polygon(saucer, _shade(Color("eeeae2"), Vector3(0, 0, 1)))
	var top := iso(at + Vector3(0, 0, 12))
	var base := iso(at + Vector3(0, 0, 1))
	var w := 3.6 * SCALE
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.85, 0), base + Vector2(w * 0.85, 0),
		top + Vector2(w, 0), top + Vector2(-w, 0)]), Color(0.85, 0.92, 1.0, 0.35))
	var tea := base.lerp(top, 0.7)
	draw_colored_polygon(PackedVector2Array([base + Vector2(-w * 0.8, 0), base + Vector2(w * 0.8, 0),
		tea + Vector2(w * 0.95, 0), tea + Vector2(-w * 0.95, 0)]), COLOR_TEA * ambient)
	draw_line(tea + Vector2(1, 0), top + Vector2(3, -5), Color(0.8, 0.82, 0.86) * ambient, 1.2)
	draw_line(top + Vector2(-w, 0), top + Vector2(w, 0), Color(1, 1, 1, 0.5), 1.0)
	draw_line(base.lerp(top, 0.2) + Vector2(-w * 0.5, 0), base.lerp(top, 0.9) + Vector2(-w * 0.6, 0), Color(1, 1, 1, 0.3), 1.0)


## A small leatherette transistor radio with a chrome grille and aerial.
func _radio(at: Vector3) -> void:
	var lo := at + Vector3(-9, -4, 0)
	var hi := at + Vector3(9, 4, 12)
	_box(lo, hi, COLOR_RADIO)
	# Speaker grille and tuning dial on the face toward us (+y).
	var fy := hi.y + 0.2
	var grille := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		grille.append(iso(Vector3(at.x - 3 + cos(a) * 4, fy, at.z + 6 + sin(a) * 4)))
	draw_colored_polygon(grille, _shade(Color("b7bcc4"), Vector3(0, 1, 0)))
	for k in 3:
		_line(Vector3(at.x - 6, fy, at.z + 4 + k * 2), Vector3(at.x, fy, at.z + 4 + k * 2), Color(0, 0, 0, 0.35), 1.0)
	_face([Vector3(at.x + 2, fy, at.z + 8), Vector3(at.x + 8, fy, at.z + 8), Vector3(at.x + 8, fy, at.z + 10),
		Vector3(at.x + 2, fy, at.z + 10)], Color("e8d8a0"), Vector3(0, 1, 0))
	draw_circle(iso(Vector3(at.x + 5, fy, at.z + 4)), 2.2, _shade(CHROME_KNOB, Vector3(0, 1, 0)))
	# Carry strap and telescopic aerial.
	_line(Vector3(lo.x + 2, at.y, hi.z), Vector3(at.x, at.y, hi.z + 6), Color("3a2a20"), 1.5)
	_line(Vector3(at.x, at.y, hi.z + 6), Vector3(hi.x - 2, at.y, hi.z), Color("3a2a20"), 1.5)
	_line(Vector3(hi.x - 2, lo.y + 1, hi.z), Vector3(hi.x + 10, lo.y - 6, hi.z + 28), Color("d4d9e1"), 1.2)



## Visible faces of an axis-aligned box: top, rear (+x) and near side (+y).
func _box(lo: Vector3, hi: Vector3, color: Color) -> void:
	_face([Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)],
		color.lightened(0.05), Vector3(0, 0, 1))
	_face([Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)],
		color, Vector3(1, 0, 0))
	_face([Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z), Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)],
		color, Vector3(0, 1, 0))


func _tube(a: Vector3, b: Vector3, color: Color, width := 3.0) -> void:
	draw_line(iso(a), iso(b), _shade(color.darkened(0.2), Vector3(0, 0.6, 0.8)), width, true)
	draw_line(iso(a) + Vector2(-0.4, -0.4), iso(b) + Vector2(-0.4, -0.4), _shade(color.lightened(0.25), Vector3(0, 0.6, 0.8)),
		width * 0.35, true)


## A line in an unshaded colour, tinted by the time of day.
func _line(a: Vector3, b: Vector3, color: Color, width: float) -> void:
	draw_line(iso(a), iso(b), color * Color(ambient, 1.0), width, true)


func _face(q: Array, color: Color, n: Vector3) -> void:
	draw_colored_polygon(_project(q), _shade(color, n))


func _shadow(at: Vector3, r: Vector2, alpha: float) -> void:
	var pts := PackedVector2Array()
	for i in 18:
		var a := TAU * i / 18.0
		pts.append(iso(at + Vector3(cos(a) * r.x, sin(a) * r.y, 0)))
	draw_colored_polygon(pts, Color(0, 0, 0, alpha))


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
