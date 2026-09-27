@tool
extends Node2D
## Placeholder isometric FIFI hatchback built from primitives (2:1 dimetric).
## Swap for a Sprite2D once the real FIFI art lands; keep get_trunk_polygon()
## so the tap area still lines up.

const LENGTH := 260.0
const WIDTH := 150.0
const BODY_H := 80.0
const CABIN_H := 62.0
const CLEARANCE := 22.0
const WHEEL_R := 26.0

const COLOR_BODY_SIDE := Color("2f7f86")
const COLOR_BODY_TOP := Color("4fa3a5")
const COLOR_TRUNK := Color("3a9098")
const COLOR_TRUNK_GLOW := Color("ffc861")
const COLOR_GLASS := Color("16213e")
const COLOR_CABIN_TOP := Color("5cb3b0")
const COLOR_WHEEL := Color("111111")
const COLOR_SHADOW := Color(0, 0, 0, 0.35)

## 0..1, pulsed by WorldHost to invite a tap on the trunk.
var trunk_glow := 0.0:
	set(value):
		trunk_glow = value
		queue_redraw()


## World (x = length toward the rear, y = width toward the viewer, z = up)
## to screen: 2:1 dimetric, matching the 128×64 tile grid.
static func iso(x: float, y: float, z: float) -> Vector2:
	return Vector2(x - y, (x + y) * 0.5 - z)


func get_trunk_polygon() -> PackedVector2Array:
	var x := LENGTH * 0.5
	var y := WIDTH * 0.5
	var z0 := CLEARANCE
	var z1 := CLEARANCE + BODY_H
	return PackedVector2Array([iso(x, -y, z0), iso(x, y, z0), iso(x, y, z1), iso(x, -y, z1)])


func _draw() -> void:
	var hx := LENGTH * 0.5
	var hy := WIDTH * 0.5
	var z0 := CLEARANCE
	var z1 := CLEARANCE + BODY_H
	var z2 := z1 + CABIN_H

	# Ground shadow.
	draw_colored_polygon(PackedVector2Array([
		iso(-hx - 10, -hy - 10, 0), iso(hx + 10, -hy - 10, 0),
		iso(hx + 10, hy + 10, 0), iso(-hx - 10, hy + 10, 0)]), COLOR_SHADOW)

	# Body: side (+y), rear/trunk (+x), top.
	draw_colored_polygon(PackedVector2Array([
		iso(-hx, hy, z0), iso(hx, hy, z0), iso(hx, hy, z1), iso(-hx, hy, z1)]), COLOR_BODY_SIDE)
	draw_colored_polygon(get_trunk_polygon(), COLOR_TRUNK.lerp(COLOR_TRUNK_GLOW, trunk_glow * 0.6))
	draw_colored_polygon(PackedVector2Array([
		iso(-hx, -hy, z1), iso(hx, -hy, z1), iso(hx, hy, z1), iso(-hx, hy, z1)]), COLOR_BODY_TOP)

	# Hatchback cabin: roof from -0.30L to 0.10L, sloped hatch down to 0.38L.
	var cf := -LENGTH * 0.34
	var rf := -LENGTH * 0.26
	var rr := LENGTH * 0.10
	var cr := LENGTH * 0.38
	var iy := hy * 0.85
	draw_colored_polygon(PackedVector2Array([
		iso(cf, iy, z1), iso(cr, iy, z1), iso(rr, iy, z2), iso(rf, iy, z2)]), COLOR_GLASS)
	draw_colored_polygon(PackedVector2Array([
		iso(cr, -iy, z1), iso(cr, iy, z1), iso(rr, iy, z2), iso(rr, -iy, z2)]), COLOR_GLASS.lightened(0.15))
	draw_colored_polygon(PackedVector2Array([
		iso(rf, -iy, z2), iso(rr, -iy, z2), iso(rr, iy, z2), iso(rf, iy, z2)]), COLOR_CABIN_TOP)

	# Trunk outline + near-side wheels.
	var trunk := get_trunk_polygon()
	trunk.append(trunk[0])
	draw_polyline(trunk, COLOR_TRUNK_GLOW.lerp(Color.WHITE, 0.3), 3.0 + trunk_glow * 3.0, true)
	for wx in [-LENGTH * 0.30, LENGTH * 0.28]:
		_draw_wheel(iso(wx, hy, WHEEL_R * 0.8))


func _draw_wheel(center: Vector2) -> void:
	draw_set_transform(center, 0.0, Vector2(0.75, 1.0))
	draw_circle(Vector2.ZERO, WHEEL_R, COLOR_WHEEL)
	draw_circle(Vector2.ZERO, WHEEL_R * 0.45, Color("777777"))
	draw_set_transform(Vector2.ZERO)
