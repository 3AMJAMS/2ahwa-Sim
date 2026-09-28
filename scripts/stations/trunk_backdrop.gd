class_name TrunkBackdrop
extends Control
## Full-screen backdrop for the prep station: standing behind FIFI with the
## hatch up. The raised hatch fills the top in perspective, its rear
## windscreen showing the sky (and a streetlight) through the glass; two work
## bulbs hang under the roof; painted pillars run down the sides,
## the trunk (headliner, rear seat back, side trim, carpet) with a wooden rack
## of supplies across it, and the rear panel with lamps, plate and bumper
## below the sill. LED strips line the opening and the hatch, their colours
## breathing in and out in a slow wave. The idle appliance (blender while
## brewing, stove while blending) waits at the back of the trunk.
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
const GLASS_SKY := Color("5f7aa6")
const TAIL_RED := Color("c3372c")
const TAIL_AMBER := Color("e8962e")
const PLATE := Color("ece8dc")
const PLATE_BAND := Color("4b87c6")
## Day-1 jars on the rack: tea, sugar, dried hibiscus, coffee.
const JAR_COLORS := [Color("3b2412"), Color("f1ede4"), Color("7a1428"), Color("4a2b1b")]
const WOOD := Color("9a6a3e")
## LED strip colours, repeating in short bands; each colour breathes in turn.
const LED_COLORS := [Color("ff3b3b"), Color("ff8a1f"), Color("ffd23a"), Color("3bff6a"),
	Color("2fe0ff"), Color("3b6bff"), Color("b45cff"), Color("ff4fb8")]
const LED_SPACING := 13.0
const LED_BAND := 4
const HATCH_H := 190.0
const ROOF_TOP := 200.0
const ROOF_BOTTOM := 226.0
const SODIUM := Color("ffa94d")
const BULB := Color("fff1d6")

## Screen y of the front edge of the trunk floor (top of the art's carpet band).
var floor_y := 1400.0
## Screen y of the sill, where the carpet meets the rear panel.
var sill_y := 1426.0
## Left/right edges of the trunk opening (the art's control bounds).
var inner := Vector2(60, 1020)
var art_scale := 1.0

## Which appliance is idle at the back of the trunk: "blend" or "heat".
var idle_station := "blend":
	set(value):
		idle_station = value
		queue_redraw()

var _font: Font = preload("res://assets/ui/main_theme.tres").default_font
var _t := 0.0
## One layer per LED colour, each drawn once; the breathing is just their
## modulate, so animating the strips costs nothing to redraw.
var _led_groups: Array[Control] = []
var _soft := StationArt._make_soft_texture()


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	for g in LED_COLORS.size():
		var layer := Control.new()
		layer.mouse_filter = MOUSE_FILTER_IGNORE
		layer.set_anchors_preset(PRESET_FULL_RECT)
		add_child(layer)
		layer.draw.connect(_draw_leds.bind(g))
		_led_groups.append(layer)
	# The sky through the rear windscreen follows the time of day.
	DayClock.minute_changed.connect(queue_redraw)


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	for g in _led_groups.size():
		var breath := 0.5 + 0.5 * sin(_t * 1.4 - g * TAU / _led_groups.size())
		_led_groups[g].modulate = Color(1, 1, 1, 0.25 + 0.75 * breath * breath)


func set_frame(new_floor: float, new_sill: float, new_inner: Vector2, new_scale: float) -> void:
	if is_equal_approx(new_floor, floor_y) and is_equal_approx(new_sill, sill_y) \
			and new_inner.is_equal_approx(inner) and is_equal_approx(new_scale, art_scale):
		return
	floor_y = new_floor
	sill_y = new_sill
	inner = new_inner
	art_scale = new_scale
	queue_redraw()
	for layer in _led_groups:
		layer.queue_redraw()


func _draw() -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), NIGHT)
	# Until the first layout pass the panel may be narrower than the opening.
	if w < inner.y or inner.y <= inner.x:
		return
	_draw_hatch(w)
	_draw_interior(w)
	_draw_pillars(w)
	_draw_rear_panel(w, h)


## The raised hatch seen from below: nearer (higher on screen) is wider, so it
## fans out from the roof's hinge line toward the top of the screen. Trim
## frames the rear windscreen, through which the sky shows (stars and a
## streetlight at night), with the heater lines and the wiper on the glass.
func _draw_hatch(w: float) -> void:
	var l := inner.x
	var r := inner.y
	var sky := DayClock.sky()
	var dark := DayClock.darkness()
	draw_polygon(PackedVector2Array([Vector2(0, 0), Vector2(w, 0), Vector2(w, ROOF_TOP), Vector2(0, ROOF_TOP)]),
		PackedColorArray([sky.darkened(0.3), sky.darkened(0.3), sky, sky]))
	var hatch := PackedVector2Array([Vector2(-60, 0), Vector2(w + 60, 0), Vector2(r + 4, HATCH_H), Vector2(l - 4, HATCH_H)])
	draw_colored_polygon(hatch, TRIM.darkened(0.25))
	# Rear windscreen: what's behind it is sky, tinted by the glass.
	var pane := PackedVector2Array([Vector2(70, 34), Vector2(w - 70, 34), Vector2(r - 44, HATCH_H - 28),
		Vector2(l + 44, HATCH_H - 28)])
	var top_col := sky.darkened(0.25).lerp(GLASS, 0.3)
	var low_col := sky.lightened(0.08).lerp(GLASS_SKY, 0.3)
	draw_polygon(pane, PackedColorArray([top_col, top_col, low_col, low_col]))
	if dark > 0.05:
		for k in 14:
			var p := Vector2(110 + float((k * 173) % 860), 44 + float((k * 67) % 100))
			if Geometry2D.is_point_in_polygon(p, pane):
				draw_circle(p, 1.6, Color(1, 1, 1, 0.6 * dark))
		# The streetlight overhead, seen through the glass.
		var lamp := Vector2(w * 0.8, 70)
		_soft_blob(lamp, Vector2(150, 110), Color(SODIUM, 0.35 * dark))
		draw_line(lamp + Vector2(120, -60), lamp + Vector2(20, -6), Color("2a2a32"), 6.0, true)
		draw_colored_polygon(PackedVector2Array([lamp + Vector2(-34, -8), lamp + Vector2(30, -8), lamp + Vector2(24, 6),
			lamp + Vector2(-28, 6)]), Color("2a2a32"))
		draw_line(lamp + Vector2(-26, 5), lamp + Vector2(22, 5), StationArt.hdr(SODIUM.lightened(0.4), 1.0 + 2.2 * dark), 5.0)
	# Reflections and the heater element's lines, following the perspective.
	for band in [[0.18, 0.26], [0.3, 0.33]]:
		var streak := PackedVector2Array([pane[3].lerp(pane[2], band[0]), pane[3].lerp(pane[2], band[1]),
			pane[0].lerp(pane[1], band[1] + 0.1), pane[0].lerp(pane[1], band[0] + 0.1)])
		draw_colored_polygon(streak, Color(1, 1, 1, 0.07))
	for k in range(1, 8):
		var t := k / 8.0
		var a := pane[0].lerp(pane[3], t)
		var b := pane[1].lerp(pane[2], t)
		draw_line(a.lerp(b, 0.04), b.lerp(a, 0.04), Color(0.6, 0.32, 0.2, 0.55), 1.5 + t)
	var pivot := Vector2(w * 0.22, 48)
	draw_line(pivot, pivot + Vector2(-60, 100), SEAL, 6.0, true)
	draw_line(pivot + Vector2(-14, 24), pivot + Vector2(-70, 118), Color("2c2c30"), 4.0, true)
	draw_circle(pivot, 9, SEAL)
	var seal := pane.duplicate()
	seal.append(pane[0])
	draw_polyline(seal, SEAL, 5.0, true)
	# Painted lip nearest us with the latch, and the trim's hinge edge.
	draw_colored_polygon(PackedVector2Array([Vector2(-60, 0), Vector2(w + 60, 0), Vector2(w + 40, 22), Vector2(-40, 22)]),
		PAINT.darkened(0.25))
	draw_rect(Rect2(w * 0.5 - 30, 8, 60, 12), CHROME)
	draw_line(Vector2(l - 4, HATCH_H - 2), Vector2(r + 4, HATCH_H - 2), SEAL, 4.0)


## Two bare work bulbs hanging from the roof edge into the trunk.
func _draw_bulbs(l: float, r: float) -> void:
	for x in [l + 70.0, r - 70.0]:
		var hook := Vector2(x, ROOF_BOTTOM + 4)
		var bulb := hook + Vector2(0, 40)
		_soft_blob(bulb + Vector2(0, 60), Vector2(260, 220), Color(BULB, 0.1))
		draw_line(hook, bulb + Vector2(0, -16), Color("1d1b20"), 3.0)
		draw_rect(Rect2(bulb + Vector2(-7, -22), Vector2(14, 12)), Color("8a8579"))
		_soft_blob(bulb, Vector2(70, 70), StationArt.hdr(Color(BULB, 0.55), 1.4))
		draw_circle(bulb, 14, StationArt.hdr(BULB, 2.6))


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
	_draw_idle_appliance(Vector2(br - 110.0 * art_scale, back + 4.0), art_scale * 0.62)
	_draw_rack(l, r, bl, br, back, seat_top)
	_draw_bulbs(l, r)


## Wooden rack across the trunk, stocked with the stand's supplies.
func _draw_rack(l: float, r: float, bl: float, br: float, back: float, seat_top: float) -> void:
	var s := art_scale
	var y := maxf(floor_y - 480.0 * s, seat_top + 170.0)
	var x0 := lerpf(l, bl, 0.5)
	var x1 := lerpf(r, br, 0.5)
	var post_foot := lerpf(floor_y, back, 0.5)
	for x in [x0 + 10.0 * s, x1 - 26.0 * s]:
		draw_rect(Rect2(x, y, 16.0 * s, post_foot - y), WOOD.darkened(0.35))
	draw_rect(Rect2(x0, y - 12.0 * s, x1 - x0, 12.0 * s), WOOD.lightened(0.12))
	if s <= 0.05:
		return
	# Supplies, left to right, standing on the plank.
	var base := y - 10.0 * s
	var x := x0 + 40.0 * s
	# A tall stack of paper cups.
	for k in 9:
		var cy := base - k * 11.0 * s
		draw_colored_polygon(PackedVector2Array([Vector2(x, cy), Vector2(x + 30 * s, cy),
			Vector2(x + 34 * s, cy - 14 * s), Vector2(x - 4 * s, cy - 14 * s)]), Color("f3efe6").darkened(0.04 * (k % 2)))
	x += 58.0 * s
	# Upturned tea glasses.
	for k in 3:
		var gx := x + k * 30.0 * s
		draw_colored_polygon(PackedVector2Array([Vector2(gx - 2 * s, base), Vector2(gx + 26 * s, base),
			Vector2(gx + 22 * s, base - 40 * s), Vector2(gx + 2 * s, base - 40 * s)]), Color(0.8, 0.92, 1.0, 0.3))
		draw_line(Vector2(gx + 5 * s, base - 4 * s), Vector2(gx + 7 * s, base - 36 * s), Color(1, 1, 1, 0.45), 2.0)
	x += 100.0 * s
	_draw_straw_cup(Vector2(x, base), s)
	x += 50.0 * s
	var jw := 30.0 * s
	for i in JAR_COLORS.size():
		_draw_jar(Vector2(x, base), jw, 46.0 * s, JAR_COLORS[i])
		x += jw + 10.0 * s
	x += 14.0 * s
	# Plain boxes of tea and coffee grounds.
	for box in [[Color("b8322a"), "شاي"], [Color("3b6fb3"), "بن"]]:
		var rect := Rect2(x, base - 74 * s, 62 * s, 74 * s)
		draw_rect(rect, box[0])
		draw_rect(Rect2(x, base - 50 * s, 62 * s, 22 * s), Color(1, 1, 1, 0.85))
		draw_string(_font, Vector2(x, base - 32 * s), box[1], HORIZONTAL_ALIGNMENT_CENTER, 62 * s, int(20 * s), box[0])
		draw_rect(Rect2(x + 50 * s, base - 74 * s, 12 * s, 74 * s), Color(0, 0, 0, 0.18))
		x += 72.0 * s
	# A water bottle at the end.
	draw_rect(Rect2(x + 4 * s, base - 80 * s, 28 * s, 80 * s), Color(0.7, 0.85, 1.0, 0.45))
	draw_rect(Rect2(x + 4 * s, base - 50 * s, 28 * s, 20 * s), Color("4b87c6"))
	draw_rect(Rect2(x + 11 * s, base - 92 * s, 14 * s, 12 * s), Color("2f6fb3"))
	# The plank's front edge and its grain.
	draw_rect(Rect2(x0, y, x1 - x0, 22.0 * s), WOOD)
	for k in 3:
		var gy := y + (5.0 + k * 6.0) * s
		draw_line(Vector2(x0 + 6, gy), Vector2(x1 - 6, gy + sin(k * 2.0) * 2.0), Color(0, 0, 0, 0.12), 1.5)
	draw_rect(Rect2(x0, y + 22.0 * s, x1 - x0, 5.0 * s), Color(0, 0, 0, 0.3))


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
		var foot := Vector2(l + 10 if side < 0 else r - 10, ROOF_BOTTOM + 260)
		var head := Vector2(l + 40 if side < 0 else r - 40, HATCH_H - 40)
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


## LED strips down the raised hatch's sides and along its hinge edge, then
## round the roof edge, both pillars and the sill. Layer `group` draws only
## the LEDs of its colour; bands of LED_BAND LEDs cycle through the colours.
func _draw_leds(group: int) -> void:
	var w := size.x
	if w < inner.y or inner.y <= inner.x:
		return
	var layer := _led_groups[group]
	var l := inner.x - 3.0
	var r := inner.y + 3.0
	var i := _led_run(layer, group, Vector2(-40, 0), Vector2(l - 2, HATCH_H - 3), 0)
	i = _led_run(layer, group, Vector2(l - 2, HATCH_H - 3), Vector2(r + 2, HATCH_H - 3), i)
	i = _led_run(layer, group, Vector2(r + 2, HATCH_H - 3), Vector2(w + 40, 0), i)
	i = _led_run(layer, group, Vector2(l, sill_y - 2), Vector2(l, ROOF_BOTTOM + 3), i)
	i = _led_run(layer, group, Vector2(l, ROOF_BOTTOM + 3), Vector2(r, ROOF_BOTTOM + 3), i)
	i = _led_run(layer, group, Vector2(r, ROOF_BOTTOM + 3), Vector2(r, sill_y - 2), i)
	_led_run(layer, group, Vector2(r, sill_y + 3), Vector2(l, sill_y + 3), i)


## One straight run of strip; draws this group's bands as a soft wide stroke
## plus a bright core, with the individual LEDs dotted along them.
func _led_run(layer: Control, group: int, a: Vector2, b: Vector2, start: int) -> int:
	var n := maxi(1, int(a.distance_to(b) / LED_SPACING))
	var c: Color = LED_COLORS[group]
	for k in n:
		if posmod(floori((start + k) / float(LED_BAND)), LED_COLORS.size()) != group:
			continue
		var p0 := a.lerp(b, k / float(n))
		var p1 := a.lerp(b, (k + 1) / float(n))
		layer.draw_line(p0, p1, Color(c, 0.18), 20.0)
		layer.draw_line(p0, p1, StationArt.hdr(c, 1.5), 6.0)
		layer.draw_rect(Rect2(p0 - Vector2(2.5, 2.5), Vector2(5, 5)), StationArt.hdr(c.lerp(Color.WHITE, 0.6), 1.7))
	return start + n


## A paper cup of striped straws on the rack.
func _draw_straw_cup(base: Vector2, s: float) -> void:
	var straws := [Color("e8433a"), Color("3b8fe0"), Color("f2c230"), Color("4cc26a"), Color("ff6fb5")]
	for k in straws.size():
		var foot := base + Vector2((8 + k * 5) * s, -30 * s)
		var tip := foot + Vector2((k - 2) * 7 * s, -58 * s + (k % 2) * 8 * s)
		draw_line(foot, tip, straws[k], 4.0 * s)
		draw_line(foot.lerp(tip, 0.3), foot.lerp(tip, 0.4), Color.WHITE, 4.0 * s)
		draw_line(foot.lerp(tip, 0.65), foot.lerp(tip, 0.75), Color.WHITE, 4.0 * s)
	draw_colored_polygon(PackedVector2Array([base, base + Vector2(34 * s, 0), base + Vector2(38 * s, -36 * s),
		base + Vector2(-4 * s, -36 * s)]), Color("f3efe6"))
	draw_rect(Rect2(base + Vector2(-2 * s, -26 * s), Vector2(38 * s, 9 * s)), Color("c8322b"))
	draw_line(base + Vector2(-4 * s, -36 * s), base + Vector2(38 * s, -36 * s), Color("d8d2c6"), 3.0 * s)


## The appliance not in use, waiting at the back of the trunk (smaller and a
## touch darker, since it sits further away).
func _draw_idle_appliance(base: Vector2, k: float) -> void:
	if k <= 0.05:
		return
	var dim := Color(0.82, 0.8, 0.85)
	if idle_station == "heat":
		# Gas cylinder, burner and the كنكة resting on it, flame off.
		draw_rect(Rect2(base + Vector2(-86, -16) * k, Vector2(172, 16) * k), Color("2c2a30") * dim)
		var body := PackedVector2Array([base + Vector2(-100, -14) * k, base + Vector2(100, -14) * k])
		for i in 9:
			var a := PI * i / 8.0
			body.append(base + Vector2(100 * cos(a), -112 - 26 * sin(a)) * k)
		draw_colored_polygon(body, Color("b8452f") * dim)
		draw_rect(Rect2(base + Vector2(-100, -66) * k, Vector2(200, 16) * k), Color("efe6d2") * dim)
		draw_rect(Rect2(base + Vector2(-20, -162) * k, Vector2(40, 24) * k), Color("c9a24a") * dim)
		draw_rect(Rect2(base + Vector2(-50, -176) * k, Vector2(100, 12) * k), Color("2c2a30") * dim)
		var pot := PackedVector2Array([base + Vector2(-76, -176) * k, base + Vector2(76, -176) * k,
			base + Vector2(62, -300) * k, base + Vector2(-62, -300) * k])
		draw_colored_polygon(pot, Color("b3b9c2") * dim)
		draw_rect(Rect2(base + Vector2(-66, -306) * k, Vector2(132, 10) * k), Color("e6e9ee") * dim)
		draw_line(base + Vector2(60, -260) * k, base + Vector2(220, -290) * k, Color("5a3620") * dim, 14.0 * k)
	else:
		# The blender: cream motor base, button panel, empty glass jar, black lid.
		draw_colored_polygon(PackedVector2Array([base + Vector2(-116, 0) * k, base + Vector2(116, 0) * k,
			base + Vector2(92, -130) * k, base + Vector2(-92, -130) * k]), Color("e8e0cc") * dim)
		draw_rect(Rect2(base + Vector2(-70, -104) * k, Vector2(140, 60) * k), Color("2b2a30") * dim)
		for i in 3:
			draw_circle(base + Vector2(-40 + i * 40, -64) * k, 11 * k, Color("55535c"))
		draw_rect(Rect2(base + Vector2(-80, -148) * k, Vector2(160, 18) * k), Color("2f2d34") * dim)
		draw_colored_polygon(PackedVector2Array([base + Vector2(-66, -148) * k, base + Vector2(66, -148) * k,
			base + Vector2(98, -410) * k, base + Vector2(-98, -410) * k]), Color(0.8, 0.92, 1.0, 0.22))
		draw_line(base + Vector2(-66, -148) * k, base + Vector2(-98, -410) * k, Color(1, 1, 1, 0.4), 3.0 * k)
		draw_line(base + Vector2(66, -148) * k, base + Vector2(98, -410) * k, Color(1, 1, 1, 0.4), 3.0 * k)
		draw_rect(Rect2(base + Vector2(-102, -436) * k, Vector2(204, 26) * k), Color("2f2d34") * dim)


func _soft_blob(c: Vector2, r: Vector2, color: Color) -> void:
	draw_texture_rect(_soft, Rect2(c - r, r * 2.0), false, color)

