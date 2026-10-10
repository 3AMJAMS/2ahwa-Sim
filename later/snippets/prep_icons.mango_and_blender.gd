# PARKED — not compiled (later/ has a .gdignore). Cut from scripts/stations/prep_icons.gd
# (as of commit 0906979). The mango icon returns in Phase D (fruit drinks: quick-bar slot and
# the order ticket's icon); the blender icon in Phase E (it drew the blender as a tool card).
#
# To restore: put the painters back in PrepIcons (ingredients after _cinnamon(), tools in the
# Tools section) and the two branches back into draw_icon()'s match:
#		"mango":
#			_mango(ci, o, s)
#		"blender":
#			_blender(ci, o, s)
# They use the shared helpers _shadow(), _leaf(), _ellipse() and _rrect(), which stay live.

## Two ripe mangoes with a leaf.
static func _mango(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 36) * s, Vector2(42, 8) * s)
	_one_mango(ci, o + Vector2(14, 6) * s, s * 0.9, -0.5)
	_one_mango(ci, o + Vector2(-12, 12) * s, s, 0.35)
	_leaf(ci, o + Vector2(10, -30) * s, 15 * s, -0.9, Color("3f8a3a"))


static func _one_mango(ci: CanvasItem, c: Vector2, s: float, rot: float) -> void:
	var body := PackedVector2Array()
	for i in 28:
		var a := TAU * i / 28.0
		# Kidney shape: one side fuller than the other.
		var r := Vector2(24 + 3 * cos(a), 17 + 3 * sin(a) * cos(a))
		body.append(c + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot) * s)
	ci.draw_colored_polygon(body, Color("f2a324"))
	for piece in Geometry2D.intersect_polygons(body, _ellipse(c + Vector2(10, -6).rotated(rot) * s, Vector2(18, 13) * s, rot, 16)):
		ci.draw_colored_polygon(piece, Color("e8632a", 0.75))
	for piece in Geometry2D.intersect_polygons(body, _ellipse(c + Vector2(-16, 4).rotated(rot) * s, Vector2(12, 10) * s, rot, 16)):
		ci.draw_colored_polygon(piece, Color("b8c43a", 0.6))
	for piece in Geometry2D.intersect_polygons(body, _ellipse(c + Vector2(4, 9).rotated(rot) * s, Vector2(22, 8) * s, rot, 16)):
		ci.draw_colored_polygon(piece, Color(0, 0, 0, 0.12))
	ci.draw_colored_polygon(_ellipse(c + Vector2(-6, -8).rotated(rot) * s, Vector2(7, 3.5) * s, rot - 0.3, 10), Color(1, 1, 1, 0.35))
	var stem := c + Vector2(-23, -2).rotated(rot) * s
	ci.draw_line(stem, stem + Vector2(-5, -4).rotated(rot) * s, Color("5a3a1a"), 2.5 * s, true)
	for k in 5:
		ci.draw_circle(c + Vector2(-8 + k * 5, 2 - k % 2 * 4).rotated(rot) * s, 0.7 * s, Color(1, 1, 0.8, 0.5))


## The blender: base with buttons and dial, ribbed jug of karkade, black lid.
static func _blender(ci: CanvasItem, o: Vector2, s: float) -> void:
	_shadow(ci, o + Vector2(0, 44) * s, Vector2(32, 6) * s)
	var base := PackedVector2Array([o + Vector2(-24, 42) * s, o + Vector2(24, 42) * s, o + Vector2(19, 16) * s,
		o + Vector2(-19, 16) * s])
	ci.draw_colored_polygon(base, Color("e8e0cc"))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(12, 42) * s, o + Vector2(24, 42) * s, o + Vector2(19, 16) * s,
		o + Vector2(10, 16) * s]), Color("c8bfa8"))
	ci.draw_rect(Rect2(o + Vector2(-22, 40) * s, Vector2(44, 3) * s), Color("2c2a30"))
	for k in 3:
		ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-15 + k * 8, 30) * s, Vector2(6, 5) * s), 1.5 * s),
			[Color("4caf50"), Color("e6c33a"), Color("e0452b")][k])
	ci.draw_circle(o + Vector2(12, 28) * s, 4.5 * s, Color("3a383f"))
	ci.draw_line(o + Vector2(12, 28) * s, o + Vector2(14, 25) * s, Color("e8e0cc"), 1.2 * s)
	# Jug: collar, glass with contents, ribs, blades, handle.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-17, 11) * s, Vector2(34, 6) * s), 2 * s), Color("3a383f"))
	var jug := PackedVector2Array([o + Vector2(-15, 11) * s, o + Vector2(15, 11) * s, o + Vector2(20, -34) * s,
		o + Vector2(-20, -34) * s])
	ci.draw_colored_polygon(jug, Color(0.8, 0.92, 1.0, 0.25))
	ci.draw_colored_polygon(PackedVector2Array([o + Vector2(-15, 11) * s, o + Vector2(15, 11) * s, o + Vector2(17.6, -12) * s,
		o + Vector2(-17.6, -12) * s]), Color("a3183a", 0.85))
	ci.draw_colored_polygon(_ellipse(o + Vector2(0, -12) * s, Vector2(17.6, 2.5) * s, 0.0, 14), Color("c43a58"))
	for k in 4:
		var x := -12.0 + k * 8.0
		ci.draw_line(o + Vector2(x, 9) * s, o + Vector2(x * 1.3, -31) * s, Color(1, 1, 1, 0.18), 1.2 * s)
	ci.draw_line(o + Vector2(-8, 6) * s, o + Vector2(8, 3) * s, Color("d4d9e1"), 2.0 * s)
	ci.draw_line(o + Vector2(-6, 2) * s, o + Vector2(6, 8) * s, Color("d4d9e1"), 2.0 * s)
	var jug_outline := jug.duplicate()
	jug_outline.append(jug[0])
	ci.draw_polyline(jug_outline, Color(0.85, 0.93, 1.0, 0.6), 1.5 * s, true)
	ci.draw_polyline(PackedVector2Array([o + Vector2(18, -26) * s, o + Vector2(28, -24) * s, o + Vector2(27, 0) * s,
		o + Vector2(16, 2) * s]), Color(0.85, 0.93, 1.0, 0.7), 3.5 * s, true)
	for k in 5:
		var y := 4.0 - k * 7.0
		ci.draw_line(o + Vector2(-17 - k * 0.5, y) * s, o + Vector2(-13 - k * 0.5, y) * s, Color(1, 1, 1, 0.5), 1.0 * s)
	# Lid and its filler cap.
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-22, -40) * s, Vector2(44, 8) * s), 3 * s), Color("2f2d34"))
	ci.draw_colored_polygon(_rrect(Rect2(o + Vector2(-7, -46) * s, Vector2(14, 7) * s), 2 * s), Color("45434b"))
	ci.draw_line(o + Vector2(-20, -39) * s, o + Vector2(20, -39) * s, Color(1, 1, 1, 0.2), 1.2 * s)


