class_name SayedPortrait
extends Control
## Sayed's head-and-shoulders portrait for the tutorial bubble: a round badge
## with his face (thick moustache, stubble, heavy brows), short black hair,
## the checked shirt and the قهوجي's towel over his shoulder. A placeholder
## until the character art is drawn.

const SKIN := Color("b97a52")
const SKIN_SHADE := Color("9a5f3c")
const HAIR := Color("1d1612")
const SHIRT := Color("2f5f8a")
const TOWEL := Color("f1ede4")


func _ready() -> void:
	custom_minimum_size = Vector2(150, 150)
	mouse_filter = MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	var r := minf(size.x, size.y) * 0.5
	var s := r / 75.0
	draw_circle(c, r, Color("7a5a2e"))
	draw_circle(c, r - 4 * s, Color("e8b86a"))
	draw_circle(c + Vector2(0, -8) * s, r * 0.72, Color("f2cf8a"))
	# Everything below is clipped to the badge.
	var badge := PrepIcons._ellipse(c, Vector2(r - 4 * s, r - 4 * s), 0.0, 40)
	var p := func(x: float, y: float) -> Vector2: return c + Vector2(x, y) * s
	# Shoulders in a checked shirt, towel over the left shoulder.
	var shirt := PackedVector2Array([p.call(-70, 80), p.call(-62, 44), p.call(-30, 30), p.call(30, 30), p.call(62, 44),
		p.call(70, 80)])
	_clip(badge, shirt, SHIRT)
	for k in 7:
		var x := -60.0 + k * 20.0
		_clip(badge, PackedVector2Array([p.call(x, 30), p.call(x + 6, 30), p.call(x + 6, 80), p.call(x, 80)]),
			SHIRT.lightened(0.18))
	for k in 3:
		var y := 40.0 + k * 14.0
		_clip(badge, PackedVector2Array([p.call(-70, y), p.call(70, y), p.call(70, y + 5), p.call(-70, y + 5)]),
			Color(SHIRT.darkened(0.3), 0.6))
	_clip(badge, PackedVector2Array([p.call(22, 30), p.call(46, 34), p.call(58, 80), p.call(30, 80)]), TOWEL)
	for k in 2:
		var y := 52.0 + k * 10.0
		_clip(badge, PackedVector2Array([p.call(28, y), p.call(52, y - 3), p.call(53, y + 1), p.call(29, y + 4)]),
			Color("c8322b"))
	# Neck and collar.
	draw_colored_polygon(PackedVector2Array([p.call(-12, 14), p.call(12, 14), p.call(14, 34), p.call(-14, 34)]), SKIN_SHADE)
	draw_colored_polygon(PackedVector2Array([p.call(-16, 30), p.call(0, 40), p.call(-6, 46), p.call(-24, 34)]), Color("e9e6df"))
	draw_colored_polygon(PackedVector2Array([p.call(16, 30), p.call(0, 40), p.call(6, 46), p.call(24, 34)]), Color("e9e6df"))
	# Ears, head, stubble along the jaw.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PrepIcons._ellipse(p.call(side * 29, -8), Vector2(6, 9) * s, 0.0, 12), SKIN_SHADE)
		draw_colored_polygon(PrepIcons._ellipse(p.call(side * 29, -8), Vector2(3, 5) * s, 0.0, 10), SKIN.darkened(0.3))
	var head := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		var jaw := 1.0 + 0.12 * maxf(sin(a), 0.0)
		head.append(p.call(cos(a) * 28 * (1.0 - 0.1 * maxf(sin(a), 0.0)), -10 + sin(a) * 32 * jaw))
	draw_colored_polygon(head, SKIN)
	var stubble := PackedVector2Array()
	for i in 15:
		var a := PI * i / 14.0
		stubble.append(p.call(cos(a) * 26 * 0.92, -2 + sin(a) * 26))
	draw_colored_polygon(stubble, Color(HAIR, 0.22))
	draw_colored_polygon(PrepIcons._ellipse(p.call(-12, -18), Vector2(8, 12) * s, 0.4, 12), Color(1, 1, 1, 0.08))
	# Short hair with a side part.
	var hair := PackedVector2Array([p.call(-29, -14), p.call(-30, -30), p.call(-20, -42), p.call(-4, -46), p.call(14, -44),
		p.call(27, -34), p.call(29, -14), p.call(24, -26), p.call(8, -32), p.call(-10, -30), p.call(-24, -24)])
	draw_colored_polygon(hair, HAIR)
	draw_line(p.call(-8, -44), p.call(-12, -32), Color(1, 1, 1, 0.12), 1.5 * s)
	# Heavy brows, eyes with a glint, nose.
	for side in [-1.0, 1.0]:
		draw_colored_polygon(PackedVector2Array([p.call(side * 4, -17), p.call(side * 19, -19), p.call(side * 20, -15),
			p.call(side * 5, -13)]), HAIR)
		draw_colored_polygon(PrepIcons._ellipse(p.call(side * 11, -8), Vector2(4.5, 3) * s, 0.0, 10), Color("f4efe6"))
		draw_circle(p.call(side * 11, -8), 2.4 * s, Color("2a1a10"))
		draw_circle(p.call(side * 11 - 0.8, -9), 0.8 * s, Color.WHITE)
	draw_colored_polygon(PackedVector2Array([p.call(0, -6), p.call(4, 6), p.call(0, 8), p.call(-4, 6)]), SKIN_SHADE)
	# The moustache, then a grin under it.
	var tache := PackedVector2Array([p.call(-17, 13), p.call(-9, 9), p.call(0, 11), p.call(9, 9), p.call(17, 13),
		p.call(13, 17), p.call(0, 15), p.call(-13, 17)])
	draw_colored_polygon(tache, HAIR)
	draw_polyline(PackedVector2Array([p.call(-9, 19), p.call(-4, 22), p.call(4, 22), p.call(9, 19)]), Color("6a2e22"), 2.0 * s, true)
	draw_arc(c, r - 2 * s, 0.0, TAU, 48, Color("5a3a1e"), 3.0 * s, true)


func _clip(badge: PackedVector2Array, poly: PackedVector2Array, color: Color) -> void:
	for piece in Geometry2D.intersect_polygons(badge, poly):
		draw_colored_polygon(piece, color)
