@tool
extends Node2D
## Placeholder isometric FIFI: a Fiat 127-styled three-door hatchback built
## from primitives (2:1 dimetric, seen from the rear-left three-quarter).
## Swap for a Sprite2D once the real art lands; keep get_trunk_polygon() so
## the tap area still lines up.

# World axes: x runs toward the rear, y toward the viewer (the car's left
# side), z up. One unit = one screen pixel along each axis.
const HX := 148.0
const HY := 72.0
const Z_SILL := 20.0
const Z_BELT := 80.0
const Z_ROOF := 132.0
const WHEEL_R := 27.0
const ARCH_R := 33.0
const WHEEL_XS := [-94.0, 92.0]

## Lower-body side profile in (x, z), convex: short sloping bonnet, flat
## waist, near-vertical tail. Proportions are the 127's, shortened a little
## for the chunky house style.
const BODY_PROFILE := [
	Vector2(-148, 20), Vector2(148, 20), Vector2(149, 70), Vector2(146, 80),
	Vector2(-62, 80), Vector2(-140, 72), Vector2(-148, 64),
]
## Glasshouse tumbles in from the waist to the roof.
const GH_WAIST_Y := 68.0
const GH_ROOF_Y := 58.0
## x at the waist and at the roof line, for the windscreen and the hatch glass.
const GH_FRONT := Vector2(-62, -24)
const GH_REAR := Vector2(144, 106)

## Everything behind this x counts as the trunk for taps.
const TRUNK_X := 100.0
## Uniform size-up of the whole car (and its tap area) for phone screens.
const SCALE := 1.3
const TAP_PADDING := 14.0

const COLOR_PAINT := Color("3f9aa0")
const COLOR_GLASS := Color("1c2346")
const COLOR_GLINT := Color(1.0, 0.86, 0.6, 0.16)
const COLOR_CHROME := Color("d4d9e1")
const COLOR_RUBBER := Color("1b1b21")
const COLOR_TIRE := Color("16161b")
const COLOR_RIM := Color("a3a9b3")
const COLOR_WELL := Color("0d0e18")
const COLOR_TAIL_RED := Color("c3372c")
const COLOR_TAIL_AMBER := Color("e8962e")
const COLOR_PLATE := Color("ece8dc")
const COLOR_PLATE_BAND := Color("4b87c6")
const COLOR_SEAM := Color(0, 0, 0, 0.35)
const COLOR_TRUNK_GLOW := Color("ffc861")

const N_SIDE := Vector3(0, 1, 0)
const N_REAR := Vector3(1, 0, 0)
const N_TOP := Vector3(0, 0, 1)
const N_GLASS_SIDE := Vector3(0, 1, 0.19)
const N_HATCH := Vector3(1, 0, 0.8)
const VIEW_DIR := Vector3(1, 1, 1)
## Warm key from the string-light canopy above, cool night fill from the viewer's side.
const KEY_DIR := Vector3(-0.3, -0.25, 1.0)
const FILL_DIR := Vector3(0.35, 1.0, 0.45)

const THEME := preload("res://assets/ui/main_theme.tres")

## 0..1, pulsed by WorldHost to invite a tap on the trunk.
var trunk_glow := 0.0:
	set(value):
		trunk_glow = value
		queue_redraw()


## World to screen: 2:1 dimetric, matching the 128×64 tile grid.
static func iso(x: float, y: float, z: float) -> Vector2:
	return Vector2(x - y, (x + y) * 0.5 - z) * SCALE


static func iso3(p: Vector3) -> Vector2:
	return iso(p.x, p.y, p.z)


## Tap area: the whole tail — hatch glass, tailgate, bumper and rear
## quarters — padded so a thumb landing on the edge still counts.
func get_trunk_polygon() -> PackedVector2Array:
	var pts := PackedVector2Array()
	for x in [TRUNK_X, HX + 7.0]:
		for y in [-HY - 4.0, HY + 4.0]:
			pts.append(iso(x, y, 0.0))
			pts.append(iso(x, y, Z_BELT))
	for x in [TRUNK_X, GH_REAR.y]:
		for y in [-GH_ROOF_Y, GH_ROOF_Y]:
			pts.append(iso(x, y, Z_ROOF))
	var hull := _hull(pts)
	var padded := Geometry2D.offset_polygon(hull, TAP_PADDING, Geometry2D.JOIN_ROUND)
	return padded[0] if not padded.is_empty() else hull


func _draw() -> void:
	_draw_ground_shadow()
	_draw_box(Vector3(-HX - 6, -HY - 3, 24), Vector3(-HX, HY + 3, 32), COLOR_CHROME)
	_draw_lower_body()
	_draw_side_details()
	for xw in WHEEL_XS:
		_draw_wheel(xw)
	_draw_rear_details()
	_draw_bumpers()
	_draw_glasshouse()
	_draw_mirror()
	_draw_trunk_glow()


func _draw_ground_shadow() -> void:
	draw_colored_polygon(_project([
		Vector3(-HX - 16, -84, 0), Vector3(HX + 20, -84, 0), Vector3(HX + 20, 88, 0), Vector3(-HX - 16, 88, 0)]),
		Color(0, 0, 0, 0.16))
	draw_colored_polygon(_project([
		Vector3(-HX - 6, -76, 0), Vector3(HX + 10, -76, 0), Vector3(HX + 10, 78, 0), Vector3(-HX - 6, 78, 0)]),
		Color(0, 0, 0, 0.22))
	for xw in WHEEL_XS:
		var contact := PackedVector2Array()
		for i in 16:
			var a := TAU * i / 16.0
			contact.append(iso(xw + 30.0 * cos(a), HY - 8.0 + 12.0 * sin(a), 0.0))
		draw_colored_polygon(contact, Color(0, 0, 0, 0.3))


func _draw_lower_body() -> void:
	var inside := Vector3(0, 0, 50)
	var n := BODY_PROFILE.size()
	for i in n:
		var a: Vector2 = BODY_PROFILE[i]
		var b: Vector2 = BODY_PROFILE[(i + 1) % n]
		_solid_face([Vector3(a.x, -HY, a.y), Vector3(b.x, -HY, b.y),
			Vector3(b.x, HY, b.y), Vector3(a.x, HY, a.y)], COLOR_PAINT, inside)
	var side := []
	for p in BODY_PROFILE:
		side.append(Vector3(p.x, HY, p.y))
	_solid_face(side, COLOR_PAINT, inside)


func _draw_side_details() -> void:
	# Rocker shadow along the sill, then the 127's waist crease.
	_poly_on(_on_side, [Vector2(-HX + 2, 20), Vector2(HX + 1, 20), Vector2(HX + 1, 25), Vector2(-HX + 2, 25)],
		COLOR_PAINT.darkened(0.45), N_SIDE)
	_line_on(_on_side, Vector2(-HX + 2, 66.5), Vector2(HX + 1, 66.5), COLOR_PAINT.lightened(0.35), 2.0, N_SIDE)
	_line_on(_on_side, Vector2(-HX + 2, 64.5), Vector2(HX + 1, 64.5), COLOR_SEAM, 1.5)
	# Door shut lines and handle.
	for x in [-58.0, 44.0]:
		_line_on(_on_side, Vector2(x, 24), Vector2(x, 79), COLOR_SEAM, 1.5)
	_line_on(_on_side, Vector2(-58, 24), Vector2(44, 24), COLOR_SEAM, 1.5)
	_poly_on(_on_side, [Vector2(28, 69), Vector2(40, 69), Vector2(40, 72.5), Vector2(28, 72.5)], COLOR_CHROME, N_SIDE)
	# Side repeater on the front wing.
	_poly_on(_on_side, _ellipse(Vector2(-132, 58), Vector2(5, 2.5), 10), COLOR_TAIL_AMBER, N_SIDE)
	# Wheel wells with a painted lip.
	for xw in WHEEL_XS:
		_poly_on(_on_side, _arch(xw, ARCH_R), COLOR_WELL, N_SIDE)
		var lip := PackedVector2Array()
		for i in 13:
			var a := PI * i / 12.0
			lip.append(iso(xw + (ARCH_R + 1.5) * cos(a), HY, WHEEL_R + (ARCH_R + 1.5) * sin(a)))
		draw_polyline(lip, _shade(COLOR_PAINT.lightened(0.2), N_SIDE), 2.5, true)


func _draw_wheel(xw: float) -> void:
	var y_out := HY - 3.0
	# The tyre only shows through its well and below the sill.
	var well := PackedVector2Array()
	for p in _arch(xw, ARCH_R):
		well.append(iso(p.x, HY, p.y))
	well.append(iso(xw - ARCH_R, HY, -30.0))
	well.append(iso(xw + ARCH_R, HY, -30.0))
	var tyre := _hull(_ring(xw, y_out, WHEEL_R) + _ring(xw, y_out - 18.0, WHEEL_R))
	for piece in Geometry2D.intersect_polygons(tyre, _hull(well)):
		draw_colored_polygon(piece, COLOR_TIRE)
	draw_colored_polygon(_ring(xw, y_out, WHEEL_R), _shade(Color("26262e"), N_SIDE))
	draw_colored_polygon(_ring(xw, y_out + 0.5, 16.0), _shade(COLOR_RIM, N_SIDE))
	draw_colored_polygon(_ring(xw, y_out + 1.0, 11.0), _shade(COLOR_RIM.darkened(0.3), N_SIDE))
	for k in 4:
		var a := PI * 0.25 + k * PI * 0.5
		var c := Vector2(xw + 13.5 * cos(a), WHEEL_R + 13.5 * sin(a))
		draw_colored_polygon(_ring(c.x, y_out + 1.0, 2.2, c.y, 8), COLOR_WELL)
	draw_colored_polygon(_ring(xw, y_out + 1.5, 5.5), _shade(COLOR_CHROME, N_SIDE))


func _draw_rear_details() -> void:
	# Tailgate shut line between the lamps, lock, plate.
	_line_on(_on_rear, Vector2(-40, 46), Vector2(40, 46), COLOR_SEAM, 1.5)
	for y in [-40.0, 40.0]:
		_line_on(_on_rear, Vector2(y, 46), Vector2(y, 70), COLOR_SEAM, 1.5)
	_poly_on(_on_rear, [Vector2(-6, 49), Vector2(6, 49), Vector2(6, 52), Vector2(-6, 52)], COLOR_CHROME, N_REAR)
	# Egyptian plate: white with the pale-blue private-car band on top.
	_poly_on(_on_rear, [Vector2(-21, 33), Vector2(21, 33), Vector2(21, 45), Vector2(-21, 45)], COLOR_PLATE, N_REAR)
	_poly_on(_on_rear, [Vector2(-21, 41.5), Vector2(21, 41.5), Vector2(21, 45), Vector2(-21, 45)], COLOR_PLATE_BAND, N_REAR)
	for y in [-16.0, -11.0, -6.0, 5.0, 10.0, 15.0]:
		_poly_on(_on_rear, [Vector2(y - 1.5, 35), Vector2(y + 1.5, 35), Vector2(y + 1.5, 39.5), Vector2(y - 1.5, 39.5)],
			Color("30343f"), N_REAR)
	# Wide horizontal tail-lamp clusters, amber at the outer ends.
	for s in [-1.0, 1.0]:
		_poly_on(_on_rear, _rect_yz(s * 42.0, s * 69.0, 44.0, 63.0), COLOR_CHROME, N_REAR)
		_poly_on(_on_rear, _rect_yz(s * 44.0, s * 59.0, 46.0, 61.0), COLOR_TAIL_RED, N_REAR)
		_poly_on(_on_rear, _rect_yz(s * 60.0, s * 67.0, 46.0, 61.0), COLOR_TAIL_AMBER, N_REAR)
	# Badge on the tailgate, skewed onto the rear face.
	var origin := iso3(_on_rear(Vector2(0, 55)))
	draw_set_transform_matrix(Transform2D(Vector2(1, -0.5) * SCALE, Vector2(0, 1) * SCALE, origin))
	draw_string(THEME.default_font, Vector2(-40, 0), "فيفي", HORIZONTAL_ALIGNMENT_CENTER, 80, 16,
		_shade(COLOR_CHROME, N_REAR))
	draw_set_transform_matrix(Transform2D.IDENTITY)
	# Exhaust tip under the bumper.
	var tip := PackedVector2Array()
	for i in 12:
		var a := TAU * i / 12.0
		tip.append(iso(HX + 4.0, -42.0 + 4.5 * cos(a), 15.0 + 3.5 * sin(a)))
	draw_colored_polygon(tip, Color("3a3a42"))


func _draw_bumpers() -> void:
	_draw_box(Vector3(HX, -HY - 3, 24), Vector3(HX + 6, HY + 3, 32), COLOR_CHROME)
	_draw_box(Vector3(HX - 22, HY, 24), Vector3(HX + 6, HY + 3, 32), COLOR_CHROME)
	for y in [-38.0, 38.0]:
		_draw_box(Vector3(HX + 5, y - 3, 22), Vector3(HX + 8, y + 3, 36), COLOR_RUBBER)
	_draw_box(Vector3(-HX - 6, HY, 24), Vector3(-HX + 20, HY + 3, 32), COLOR_CHROME)


func _draw_glasshouse() -> void:
	var fw_n := Vector3(GH_FRONT.x, GH_WAIST_Y, Z_BELT)
	var fw_f := Vector3(GH_FRONT.x, -GH_WAIST_Y, Z_BELT)
	var rw_n := Vector3(GH_REAR.x, GH_WAIST_Y, Z_BELT)
	var rw_f := Vector3(GH_REAR.x, -GH_WAIST_Y, Z_BELT)
	var fr_n := Vector3(GH_FRONT.y, GH_ROOF_Y, Z_ROOF)
	var fr_f := Vector3(GH_FRONT.y, -GH_ROOF_Y, Z_ROOF)
	var rr_n := Vector3(GH_REAR.y, GH_ROOF_Y, Z_ROOF)
	var rr_f := Vector3(GH_REAR.y, -GH_ROOF_Y, Z_ROOF)
	var inside := Vector3(50, 0, 106)
	_solid_face([fw_f, fw_n, fr_n, fr_f], COLOR_GLASS, inside)
	_solid_face([fr_f, rr_f, rr_n, fr_n], COLOR_PAINT, inside)
	_solid_face([rw_f, rw_n, rr_n, rr_f], COLOR_PAINT, inside)
	_solid_face([fw_n, rw_n, rr_n, fr_n], COLOR_PAINT, inside)

	# Side glass: long door window, B-pillar, then the quarter light that
	# leaves the 127's broad C-pillar.
	var door_glass := PackedVector2Array([Vector2(-52, 85), Vector2(-21, 127), Vector2(38, 127), Vector2(38, 85)])
	var quarter_glass := PackedVector2Array([Vector2(48, 85), Vector2(48, 127), Vector2(84, 127), Vector2(114, 85)])
	for glass in [door_glass, quarter_glass]:
		_poly_on(_on_glass_side, glass, COLOR_GLASS, N_GLASS_SIDE)
		var frame: PackedVector2Array = glass.duplicate()
		frame.append(frame[0])
		_polyline_on(_on_glass_side, frame, Color(COLOR_CHROME, 0.55), 1.5)
	_glint_on(_on_glass_side, door_glass, [Vector2(10, 80), Vector2(24, 80), Vector2(-4, 132), Vector2(-18, 132)])
	_glint_on(_on_glass_side, quarter_glass, [Vector2(72, 80), Vector2(80, 80), Vector2(62, 132), Vector2(54, 132)])
	# The windscreen faces away from this camera, so the cabin's front edge
	# sits straight against the bonnet: outline it, and park the wipers.
	draw_polyline(_project([fw_n, fr_n, fr_f]), Color(0, 0, 0, 0.35), 2.5, true)
	for y in [-46.0, 2.0]:
		draw_line(iso(GH_FRONT.x - 3, y, Z_BELT), iso(GH_FRONT.x - 3, y + 38, Z_BELT), COLOR_RUBBER, 2.0, true)
	_line_on(_on_glass_side, Vector2(GH_FRONT.x, 80.5), Vector2(GH_REAR.x, 80.5), COLOR_CHROME, 2.0, N_SIDE)
	_line_on(_on_glass_side, Vector2(GH_FRONT.y + 2, Z_ROOF - 0.5), Vector2(GH_REAR.y - 2, Z_ROOF - 0.5), Color(COLOR_CHROME, 0.7), 2.0, N_TOP)

	# Hatch glass.
	var rear_glass := PackedVector2Array([Vector2(0.07, 0.1), Vector2(0.93, 0.1), Vector2(0.94, 0.9), Vector2(0.06, 0.9)])
	_poly_on(_on_hatch, rear_glass, COLOR_GLASS, N_HATCH)
	_glint_on(_on_hatch, rear_glass, [Vector2(0.18, 0), Vector2(0.3, 0), Vector2(0.44, 1), Vector2(0.32, 1)])


func _draw_mirror() -> void:
	var head := Vector3(-54, HY + 9, 88)
	draw_line(iso(-48, HY, Z_BELT + 1), iso3(head), _shade(COLOR_CHROME, N_SIDE), 3.0, true)
	var rim := PackedVector2Array()
	var glass := PackedVector2Array()
	for i in 14:
		var a := TAU * i / 14.0
		rim.append(iso(head.x, head.y + 6.5 * cos(a), head.z + 5.0 * sin(a)))
		glass.append(iso(head.x + 0.5, head.y + 5.0 * cos(a), head.z + 3.6 * sin(a)))
	draw_colored_polygon(rim, _shade(COLOR_CHROME, N_REAR))
	draw_colored_polygon(glass, _shade(COLOR_GLASS.lightened(0.25), N_REAR))


func _draw_trunk_glow() -> void:
	if trunk_glow <= 0.0:
		return
	var pts := PackedVector2Array()
	for y in [-HY, HY]:
		pts.append(iso(HX + 1.0, y, 33.0))
		pts.append(iso(HX + 1.0, y, 70.0))
		pts.append(iso(GH_REAR.x + 2.0, y, Z_BELT))
		pts.append(iso(GH_REAR.y, y * GH_ROOF_Y / HY, Z_ROOF))
	var outline := _hull(pts)
	draw_colored_polygon(outline, Color(COLOR_TRUNK_GLOW, 0.14 * trunk_glow))
	outline.append(outline[0])
	draw_polyline(outline, Color(COLOR_TRUNK_GLOW.lerp(Color.WHITE, 0.3), 0.4 + 0.6 * trunk_glow),
		2.0 + trunk_glow * 3.0, true)


## Visible faces of an axis-aligned box: top, rear (+x) and near side (+y).
func _draw_box(lo: Vector3, hi: Vector3, color: Color) -> void:
	draw_colored_polygon(_project([Vector3(lo.x, lo.y, hi.z), Vector3(hi.x, lo.y, hi.z),
		Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]), _shade(color, N_TOP))
	draw_colored_polygon(_project([Vector3(hi.x, lo.y, lo.z), Vector3(hi.x, hi.y, lo.z),
		Vector3(hi.x, hi.y, hi.z), Vector3(hi.x, lo.y, hi.z)]), _shade(color, N_REAR))
	draw_colored_polygon(_project([Vector3(lo.x, hi.y, lo.z), Vector3(hi.x, hi.y, lo.z),
		Vector3(hi.x, hi.y, hi.z), Vector3(lo.x, hi.y, hi.z)]), _shade(color, N_SIDE))


## Draws a planar face of a convex solid if it faces the camera.
## `inside` is any point inside that solid, used to orient the normal.
func _solid_face(points: Array, base: Color, inside: Vector3) -> void:
	var n := _newell(points)
	var centre := Vector3.ZERO
	for p in points:
		centre += p
	centre /= points.size()
	if n.dot(centre - inside) < 0.0:
		n = -n
	if n.normalized().dot(VIEW_DIR.normalized()) <= 0.02:
		return
	draw_colored_polygon(_project(points), _shade(base, n))


# Face mappings from 2D face coordinates to world space.
func _on_side(p: Vector2) -> Vector3:
	return Vector3(p.x, HY, p.y)


func _on_rear(p: Vector2) -> Vector3:
	return Vector3(HX + 0.5 + clampf((p.y - Z_SILL) / 50.0, 0.0, 1.0), p.x, p.y)


func _on_glass_side(p: Vector2) -> Vector3:
	var t := (p.y - Z_BELT) / (Z_ROOF - Z_BELT)
	return Vector3(p.x, GH_WAIST_Y - t * (GH_WAIST_Y - GH_ROOF_Y) + 0.5, p.y)


## (s, t) across and up the hatch glass, s = 0 on the near (+y) side.
func _on_hatch(p: Vector2) -> Vector3:
	var bottom := Vector3(GH_REAR.x, GH_WAIST_Y, Z_BELT).lerp(Vector3(GH_REAR.x, -GH_WAIST_Y, Z_BELT), p.x)
	var top := Vector3(GH_REAR.y, GH_ROOF_Y, Z_ROOF).lerp(Vector3(GH_REAR.y, -GH_ROOF_Y, Z_ROOF), p.x)
	return bottom.lerp(top, p.y) + Vector3(0.5, 0, 0.25)


func _poly_on(mapper: Callable, local, color: Color, normal: Vector3) -> void:
	draw_colored_polygon(_map(mapper, local), _shade(color, normal))


func _line_on(mapper: Callable, a: Vector2, b: Vector2, color: Color, width: float, normal := Vector3.ZERO) -> void:
	var c := color if normal == Vector3.ZERO else _shade(color, normal)
	draw_line(iso3(mapper.call(a)), iso3(mapper.call(b)), c, width, true)


func _polyline_on(mapper: Callable, local, color: Color, width: float) -> void:
	draw_polyline(_map(mapper, local), color, width, true)


## A warm reflection of the string lights, clipped to a pane of glass.
func _glint_on(mapper: Callable, pane: PackedVector2Array, band: Array) -> void:
	for piece in Geometry2D.intersect_polygons(pane, PackedVector2Array(band)):
		draw_colored_polygon(_map(mapper, piece), COLOR_GLINT)


func _map(mapper: Callable, local) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in local:
		out.append(iso3(mapper.call(p)))
	return out


## Wheel-well opening on the side panel, in (x, z).
func _arch(xw: float, r: float) -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(xw + r, Z_SILL)])
	for i in 13:
		var a := PI * i / 12.0
		pts.append(Vector2(xw + r * cos(a), WHEEL_R + r * sin(a)))
	pts.append(Vector2(xw - r, Z_SILL))
	return pts


## A circle standing in the x-z plane at depth y, projected.
func _ring(xc: float, y: float, r: float, zc := WHEEL_R, segments := 22) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(iso(xc + r * cos(a), y, zc + r * sin(a)))
	return pts


static func _rect_yz(y0: float, y1: float, z0: float, z1: float) -> Array:
	return [Vector2(y0, z0), Vector2(y1, z0), Vector2(y1, z1), Vector2(y0, z1)]


static func _ellipse(c: Vector2, r: Vector2, segments: int) -> Array:
	var pts := []
	for i in segments:
		var a := TAU * i / segments
		pts.append(c + Vector2(r.x * cos(a), r.y * sin(a)))
	return pts


static func _project(points: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for p in points:
		out.append(iso3(p))
	return out


static func _hull(points: PackedVector2Array) -> PackedVector2Array:
	var hull := Geometry2D.convex_hull(points)
	hull.remove_at(hull.size() - 1)
	return hull


static func _newell(points: Array) -> Vector3:
	var n := Vector3.ZERO
	for i in points.size():
		var a: Vector3 = points[i]
		var b: Vector3 = points[(i + 1) % points.size()]
		n.x += (a.y - b.y) * (a.z + b.z)
		n.y += (a.z - b.z) * (a.x + b.x)
		n.z += (a.x - b.x) * (a.y + b.y)
	return n


static func _shade(base: Color, normal: Vector3) -> Color:
	var n := normal.normalized()
	var key := maxf(n.dot(KEY_DIR.normalized()), 0.0)
	var fill := maxf(n.dot(FILL_DIR.normalized()), 0.0)
	return Color(
		base.r * (0.46 + 0.55 * key + 0.36 * fill),
		base.g * (0.46 + 0.50 * key + 0.38 * fill),
		base.b * (0.50 + 0.38 * key + 0.50 * fill),
		base.a)
