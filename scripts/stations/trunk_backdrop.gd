class_name TrunkBackdrop
extends Control
## Full-screen backdrop for the prep station: standing behind FIFI with the
## hatch up. Raised hatch across the top, painted pillars down the sides,
## the trunk (headliner, rear seat back, side trim, carpet) in between, and
## the rear panel with lamps, plate and bumper below the sill.
## PrepStation feeds it where the station art's trunk floor sits on screen,
## so the carpet and the sill line up with whatever the gauge is drawing.

const PAINT := Color("e9b42c")
const SEAL := Color("17151a")
const CHROME := Color("d4d9e1")
const NIGHT := Color("141226")
const HEADLINER := Color("4d463f")
const TRIM := Color("3f3943")
const SEAT := Color("5b3d33")
const CARPET := Color("463e46")
const GLASS := Color("1c2346")
const TAIL_RED := Color("c3372c")
const TAIL_AMBER := Color("e8962e")
const PLATE := Color("ece8dc")
const PLATE_BAND := Color("4b87c6")
## Day-1 jars at the back of the trunk: tea, sugar, dried hibiscus, coffee.
const JAR_COLORS := [Color("3b2412"), Color("f1ede4"), Color("7a1428"), Color("4a2b1b")]
const HATCH_H := 100.0
const ROOF_TOP := 112.0
const ROOF_BOTTOM := 140.0

## Screen y of the front edge of the trunk floor (top of the art's carpet band).
var floor_y := 1400.0
## Screen y of the sill, where the carpet meets the rear panel.
var sill_y := 1426.0
## Left/right edges of the trunk opening (the art's control bounds).
var inner := Vector2(60, 1020)
var art_scale := 1.0

var _font: Font = preload("res://assets/ui/main_theme.tres").default_font
var _soft := StationArt._make_soft_texture()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE


func set_frame(new_floor: float, new_sill: float, new_inner: Vector2, new_scale: float) -> void:
	if is_equal_approx(new_floor, floor_y) and is_equal_approx(new_sill, sill_y) \
			and new_inner.is_equal_approx(inner) and is_equal_approx(new_scale, art_scale):
		return
	floor_y = new_floor
	sill_y = new_sill
	inner = new_inner
	art_scale = new_scale
	queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), NIGHT)
	_draw_hatch(w)
	_draw_interior(w)
	_draw_pillars(w)
	_draw_rear_panel(w, h)


## Underside of the lifted hatch: trim frame round the glass, painted lip, latch.
func _draw_hatch(w: float) -> void:
	draw_rect(Rect2(0, 0, w, HATCH_H), TRIM.darkened(0.2))
	draw_rect(Rect2(110, 10, w - 220, HATCH_H - 34), GLASS)
	draw_colored_polygon(PackedVector2Array([Vector2(w * 0.3, 10), Vector2(w * 0.36, 10),
		Vector2(w * 0.3, HATCH_H - 24), Vector2(w * 0.24, HATCH_H - 24)]), Color(1.0, 0.86, 0.6, 0.12))
	draw_rect(Rect2(0, HATCH_H - 14, w, 14), PAINT.darkened(0.2))
	draw_rect(Rect2(w * 0.5 - 22, HATCH_H - 12, 44, 8), CHROME)
	# Night sky shows between the hatch and the roof, with the string lights' glow.
	_soft_blob(Vector2(w * 0.5, ROOF_TOP - 6), Vector2(w * 0.6, 40), Color(1.0, 0.78, 0.38, 0.12))


func _draw_interior(w: float) -> void:
	var l := inner.x
	var r := inner.y
	var top := ROOF_BOTTOM + 6.0
	var depth := 110.0 * art_scale
	var back := floor_y - depth
	var bl := l + depth
	var br := r - depth
	var seat_top := top + 120.0
	draw_rect(Rect2(l, top, r - l, floor_y - top), Color("221c21"))
	draw_colored_polygon(PackedVector2Array([Vector2(l, top), Vector2(r, top), Vector2(br, seat_top - 30), Vector2(bl, seat_top - 30)]),
		HEADLINER)
	# Rear seat back, split 60/40, with its stitched ribs.
	var seat := Rect2(bl, seat_top, br - bl, back - seat_top)
	draw_rect(seat, SEAT)
	draw_rect(Rect2(bl, seat_top, br - bl, 16), SEAT.lightened(0.12))
	for i in range(1, 12):
		var x := lerpf(bl, br, i / 12.0)
		draw_line(Vector2(x, seat_top + 22), Vector2(x, back - 14), Color(0, 0, 0, 0.14), 2.0)
	var split := lerpf(bl, br, 0.6)
	draw_line(Vector2(split, seat_top), Vector2(split, back), Color(0, 0, 0, 0.4), 4.0)
	_soft_blob(Vector2(w * 0.5, seat_top + 60), Vector2(w * 0.55, 260), Color(1.0, 0.78, 0.38, 0.08))
	# Side trim walls, each with a carpeted wheel-arch hump at the floor.
	for side in [-1.0, 1.0]:
		var edge := l if side < 0 else r
		var deep := bl if side < 0 else br
		var wall := PackedVector2Array([Vector2(edge, top), Vector2(deep, seat_top - 30), Vector2(deep, back), Vector2(edge, floor_y)])
		draw_colored_polygon(wall, TRIM.lightened(0.06) if side < 0 else TRIM.darkened(0.1))
		var hump := PackedVector2Array()
		for i in 13:
			var a := PI + PI * i / 12.0
			hump.append(Vector2(lerpf(edge, deep, 0.5) + cos(a) * depth * 0.55, lerpf(floor_y, back, 0.5) + sin(a) * 70.0 * art_scale))
		for piece in Geometry2D.intersect_polygons(wall, hump):
			draw_colored_polygon(piece, CARPET.lightened(0.05))
	# Floor running back to the seat, and the jars stood against it.
	draw_colored_polygon(PackedVector2Array([Vector2(l, floor_y + 1), Vector2(r, floor_y + 1), Vector2(br, back), Vector2(bl, back)]),
		CARPET)
	for i in 60:
		var t := float((i * 37) % 100) / 100.0
		var d := float((i * 61) % 100) / 100.0
		var y := lerpf(back, floor_y, d)
		var x := lerpf(lerpf(bl, l, d), lerpf(br, r, d), t)
		draw_circle(Vector2(x, y), 1.5, Color(1, 1, 1, 0.05))
	var jw := 30.0 * art_scale
	for i in JAR_COLORS.size():
		var x := br - 20.0 * art_scale - (JAR_COLORS.size() - i) * (jw + 8.0 * art_scale)
		_draw_jar(Vector2(x, back + 6.0 * art_scale), jw, 46.0 * art_scale, JAR_COLORS[i])


func _draw_jar(base: Vector2, jw: float, jh: float, fill: Color) -> void:
	draw_rect(Rect2(base.x, base.y - jh, jw, jh), Color(fill, 0.95))
	draw_rect(Rect2(base.x, base.y - jh, jw, jh), Color(0.8, 0.9, 1.0, 0.25), false, 2.0)
	draw_rect(Rect2(base.x + jw * 0.15, base.y - jh + 6, jw * 0.14, jh - 12), Color(1, 1, 1, 0.22))
	draw_rect(Rect2(base.x - 2, base.y - jh - 9 * art_scale, jw + 4, 10 * art_scale), Color("c9a24a"))


## Roof edge over the opening and the painted pillars either side, with the
## hatch's gas struts running down to them.
func _draw_pillars(w: float) -> void:
	var l := inner.x
	var r := inner.y
	draw_rect(Rect2(0, ROOF_TOP, w, ROOF_BOTTOM - ROOF_TOP), PAINT)
	draw_rect(Rect2(0, ROOF_TOP, w, 5), PAINT.lightened(0.2))
	draw_rect(Rect2(l, ROOF_BOTTOM, r - l, 6), SEAL)
	draw_rect(Rect2(0, ROOF_TOP, l, sill_y - ROOF_TOP), PAINT)
	draw_rect(Rect2(r, ROOF_TOP, w - r, sill_y - ROOF_TOP), PAINT.darkened(0.14))
	draw_rect(Rect2(l - 6, ROOF_BOTTOM, 6, sill_y - ROOF_BOTTOM), SEAL)
	draw_rect(Rect2(r, ROOF_BOTTOM, 6, sill_y - ROOF_BOTTOM), SEAL)
	draw_rect(Rect2(8, ROOF_TOP + 10, 8, sill_y - ROOF_TOP - 20), Color(1, 1, 1, 0.18))
	for side in [-1.0, 1.0]:
		var foot := Vector2(l + 10 if side < 0 else r - 10, ROOF_BOTTOM + 380)
		var head := Vector2(130 if side < 0 else w - 130, HATCH_H - 16)
		draw_line(foot, foot.lerp(head, 0.55), Color("2a2a30"), 11.0, true)
		draw_line(foot.lerp(head, 0.5), head, CHROME, 5.0, true)


## Below the sill: seal and chrome trim, the painted rear panel with the
## 127's wide lamp clusters and the Egyptian plate, then the bumper and road.
func _draw_rear_panel(w: float, h: float) -> void:
	var bumper_top := h - 170.0
	draw_rect(Rect2(0, sill_y, w, bumper_top - sill_y), PAINT.darkened(0.06))
	draw_rect(Rect2(0, sill_y, w, 7), SEAL)
	draw_rect(Rect2(0, sill_y + 7, w, 6), CHROME)
	draw_rect(Rect2(0, sill_y + 13, w, 5), PAINT.lightened(0.15))
	var panel := bumper_top - sill_y
	var lamp_h := clampf(panel * 0.3, 40.0, 84.0)
	var lamp_y := sill_y + 32.0
	for side in [-1.0, 1.0]:
		var outer := 18.0 if side < 0 else w - 18.0
		var x0 := minf(outer, outer - side * 240.0)
		draw_rect(Rect2(x0 - 6, lamp_y - 6, 252, lamp_h + 12), CHROME)
		var amber := Rect2(outer - (0.0 if side < 0 else 70.0), lamp_y, 70, lamp_h)
		var red := Rect2(outer + (70.0 if side < 0 else -240.0), lamp_y, 170, lamp_h)
		draw_rect(amber, TAIL_AMBER)
		draw_rect(red, TAIL_RED)
		for k in range(1, 4):
			var y := lamp_y + lamp_h * k / 4.0
			draw_line(Vector2(red.position.x, y), Vector2(red.end.x, y), Color(0, 0, 0, 0.15), 2.0)
		draw_rect(Rect2(red.position.x, lamp_y + 4, red.size.x, 6), Color(1, 1, 1, 0.2))
	# Egyptian plate: white, pale-blue band on top reading مصر / EGYPT.
	var plate_w := 320.0
	var plate_h := clampf(panel - lamp_h - 70.0, 70.0, 110.0)
	var plate := Rect2(w * 0.5 - plate_w * 0.5, bumper_top - plate_h - 14.0, plate_w, plate_h)
	draw_rect(plate.grow(4), SEAL)
	draw_rect(plate, PLATE)
	var band := Rect2(plate.position, Vector2(plate_w, plate_h * 0.3))
	draw_rect(band, PLATE_BAND)
	draw_string(_font, Vector2(plate.position.x + 16, band.end.y - 6), "EGYPT", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color.WHITE)
	draw_string(_font, Vector2(plate.end.x - 16 - 60, band.end.y - 4), "مصر", HORIZONTAL_ALIGNMENT_RIGHT, 60, 24, Color.WHITE)
	# Numbers on the left half, letters on the right, split by a rule.
	var text_y := plate.end.y - plate_h * 0.14
	var text_size := int(plate_h * 0.44)
	draw_string(_font, Vector2(plate.position.x, text_y), "١٢٧", HORIZONTAL_ALIGNMENT_CENTER, plate_w * 0.5,
		text_size, Color("1d1f28"))
	draw_string(_font, Vector2(plate.position.x + plate_w * 0.5, text_y), "ق  ه  و", HORIZONTAL_ALIGNMENT_CENTER,
		plate_w * 0.5, text_size, Color("1d1f28"))
	draw_line(Vector2(w * 0.5, band.end.y + 6), Vector2(w * 0.5, plate.end.y - 6), Color("1d1f28"), 2.0)
	# Chrome bumper with rubber overriders, then the road in shadow.
	draw_rect(Rect2(0, bumper_top, w, 48), CHROME.darkened(0.08))
	draw_rect(Rect2(0, bumper_top + 4, w, 10), Color(1, 1, 1, 0.45))
	draw_rect(Rect2(0, bumper_top + 40, w, 8), Color(0, 0, 0, 0.25))
	for x in [w * 0.27, w * 0.73]:
		draw_rect(Rect2(x - 16, bumper_top - 10, 32, 68), SEAL)
	draw_rect(Rect2(0, bumper_top + 48, w, h - bumper_top - 48), Color("100e19"))
	_soft_blob(Vector2(w * 0.5, bumper_top + 60), Vector2(w * 0.6, 40), Color(0, 0, 0, 0.5))
	draw_circle(Vector2(w * 0.3, bumper_top + 66), 14, Color("3a3a42"))
	draw_circle(Vector2(w * 0.3, bumper_top + 66), 8, Color("121016"))


func _soft_blob(c: Vector2, r: Vector2, color: Color) -> void:
	draw_texture_rect(_soft, Rect2(c - r, r * 2.0), false, color)

