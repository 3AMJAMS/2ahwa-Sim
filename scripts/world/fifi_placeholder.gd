@tool
extends Node2D
## Placeholder isometric FIFI: a Fiat 127-styled three-door hatchback built
## from primitives (2:1 dimetric, seen from the rear-left three-quarter),
## parked at the kerb with its hatch up so Sayed's Day-1 kit shows in the
## trunk, LED strips round the opening, and the fruit ice box on the pavement.
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
## The hatch hinges at the back of the roof, in (x, z), and stands open by this much.
const HINGE := Vector2(106, 132)
const HATCH_OPEN := 2.18
## Trunk opening, sill to roof, as seen once the hatch is up.
const OPENING := [
	Vector3(148.5, -40, 46), Vector3(148.5, 40, 46), Vector3(147.5, 40, 66), Vector3(145, 48, 80),
	Vector3(107, 50, 131), Vector3(107, -50, 131), Vector3(145, -48, 80), Vector3(147.5, -40, 66),
]
const Z_FLOOR := 34.0
## Uniform size-up of the whole car (and its tap area) for phone screens.
const SCALE := 1.3
const TAP_PADDING := 14.0

const COLOR_PAINT := Color("e9b42c")
const COLOR_GLASS := Color("1c2346")
const COLOR_GLINT := Color(1.0, 0.86, 0.6, 0.16)
## What the rear windscreen reflects when seen from below: the sky.
const COLOR_SKY_GLASS := Color("7f9cc4")
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
const COLOR_CABIN := Color("1d181d")
const COLOR_TRIM := Color("4a434d")
const COLOR_CARPET := Color("463e46")
const COLOR_SEAT := Color("6b4a3c")
const COLOR_CYLINDER := Color("b8452f")
const COLOR_STEEL := Color("b3b9c2")
const COLOR_BLENDER := Color("e8e0cc")
## Day-1 jars at the back of the trunk: tea, sugar, dried hibiscus, coffee.
const JAR_COLORS := [Color("3b2412"), Color("f1ede4"), Color("7a1428"), Color("4a2b1b")]
const COLOR_WOOD := Color("9a6a3e")
## LED strip colours in short repeating bands; each colour breathes in turn.
const LED_COLORS := [Color("ff3b3b"), Color("ff8a1f"), Color("ffd23a"), Color("3bff6a"),
	Color("2fe0ff"), Color("3b6bff"), Color("b45cff"), Color("ff4fb8")]
const LED_BAND := 3
## Height of the pavement kerb the ice box stands on (WorldHost draws it).
const Z_PAVEMENT := 8.0
const COLOR_ICEBOX := Color("2f6fb3")
const COLOR_ICEBOX_LID := Color("eef1f4")

const N_SIDE := Vector3(0, 1, 0)
const N_REAR := Vector3(1, 0, 0)
const N_TOP := Vector3(0, 0, 1)
const N_GLASS_SIDE := Vector3(0, 1, 0.19)
const VIEW_DIR := Vector3(1, 1, 1)
## Warm key from the streetlights above, cool night fill from the viewer's side.
const KEY_DIR := Vector3(-0.3, -0.25, 1.0)
const FILL_DIR := Vector3(0.35, 1.0, 0.45)

## 0..1, pulsed by WorldHost to invite a tap on the trunk.
var trunk_glow := 0.0:
	set(value):
		trunk_glow = value
		if _glow:
			_glow.modulate.a = value
## Time-of-day tint for everything lit by the sun/streetlights (DayClock).
var ambient := Color.WHITE:
	set(value):
		ambient = value
		queue_redraw()
## 0 by day, 1 at night: how strongly the LED strips glow.
var darkness := 1.0:
	set(value):
		darkness = value
		if _led_light:
			_led_light.energy = 0.9 * value

## The tap glow and each LED colour are drawn once on their own layers and
## animated only through modulate, so nothing redraws per frame.
var _glow: Node2D
var _led_groups: Array[Node2D] = []
var _t := 0.0
## The LED strips' coloured spill onto the road and pavement round the trunk.
var _led_light: PointLight2D


func _ready() -> void:
	_glow = Node2D.new()
	add_child(_glow)
	_glow.draw.connect(_draw_trunk_glow)
	_glow.modulate.a = trunk_glow
	for g in LED_COLORS.size():
		var layer := Node2D.new()
		add_child(layer)
		layer.draw.connect(_draw_leds.bind(g))
		_led_groups.append(layer)
	_led_light = PointLight2D.new()
	_led_light.texture = _spill_texture()
	_led_light.texture_scale = 1.4
	_led_light.scale = Vector2(1.0, 0.5)
	_led_light.position = iso(HX + 24, 0, 0)
	_led_light.color = Color(1.0, 0.55, 0.85)
	_led_light.energy = 0.9 * darkness
	add_child(_led_light)


static func _spill_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 0.8))
	gradient.set_color(1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 128
	tex.height = 128
	return tex


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
	for p in _hatch_outline():
		pts.append(iso3(p))
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
	_draw_trunk_interior()
	_draw_open_hatch()
	_draw_mirror()
	_draw_ice_box()


func _process(delta: float) -> void:
	_t += delta
	var lit := lerpf(0.45, 1.0, darkness)
	for g in _led_groups.size():
		var breath := 0.5 + 0.5 * sin(_t * 1.4 - g * TAU / _led_groups.size())
		_led_groups[g].modulate = Color(1, 1, 1, (0.25 + 0.75 * breath * breath) * lit)


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


## Drawn at full strength once; WorldHost's pulse fades it via modulate.
func _draw_trunk_glow() -> void:
	var outline := _hull(_project(OPENING))
	_glow.draw_colored_polygon(outline, Color(COLOR_TRUNK_GLOW, 0.14))
	outline.append(outline[0])
	_glow.draw_polyline(outline, Color(COLOR_TRUNK_GLOW.lerp(Color.WHITE, 0.3), 1.0), 4.0, true)


## Looking in through the open hatch: cabin shadow, far trim, seat back and
## floor, then the stand's kit. Everything is clipped to the opening.
func _draw_trunk_interior() -> void:
	var clip := _hull(_project(OPENING))
	draw_colored_polygon(clip, COLOR_CABIN * ambient)
	_clipped(clip, _project([Vector3(60, -48, Z_FLOOR), Vector3(150, -48, Z_FLOOR),
		Vector3(150, -48, 131), Vector3(60, -48, 131)]), _shade(COLOR_TRIM, N_SIDE))
	_clipped(clip, _project([Vector3(72, -48, Z_FLOOR), Vector3(72, 48, Z_FLOOR),
		Vector3(72, 48, 104), Vector3(72, -48, 104)]), _shade(COLOR_SEAT, N_REAR))
	_clipped(clip, _project([Vector3(72, -48, 104), Vector3(72, 48, 104),
		Vector3(80, 48, 104), Vector3(80, -48, 104)]), _shade(COLOR_SEAT.lightened(0.1), N_TOP))
	_clipped(clip, _project([Vector3(72, -48, Z_FLOOR), Vector3(150, -48, Z_FLOOR),
		Vector3(150, 48, Z_FLOOR), Vector3(72, 48, Z_FLOOR)]), _shade(COLOR_CARPET, N_TOP))
	# Wooden rack across the trunk with the jars lined up on it.
	for y in [-44.0, 40.0]:
		_clipped(clip, _project([Vector3(88, y, Z_FLOOR), Vector3(92, y, Z_FLOOR), Vector3(92, y, 62),
			Vector3(88, y, 62)]), _shade(COLOR_WOOD.darkened(0.3), N_REAR))
	_clipped(clip, _project([Vector3(80, -48, 64), Vector3(98, -48, 64), Vector3(98, 48, 64), Vector3(80, 48, 64)]),
		_shade(COLOR_WOOD, N_TOP))
	_clipped(clip, _project([Vector3(98, -48, 60), Vector3(98, 48, 60), Vector3(98, 48, 64), Vector3(98, -48, 64)]),
		_shade(COLOR_WOOD, N_REAR))
	for i in JAR_COLORS.size():
		var c := Vector3(88, -36 + i * 13, 64.0)
		_cylinder(clip, c, 4.5, 4.5, 11, Color(JAR_COLORS[i], 0.95), Color(JAR_COLORS[i]).lightened(0.15))
		_cylinder(clip, c + Vector3(0, 0, 11), 4.8, 4.8, 2.5, Color("c9a24a"), Color("e0bf6a"))
	# Blender: squat base, glass jar with a splash of karkade, black lid.
	var b := Vector3(118, -26, Z_FLOOR)
	_cylinder(clip, b, 9, 8, 12, COLOR_BLENDER, COLOR_BLENDER.lightened(0.1))
	_cylinder(clip, b + Vector3(0, 0, 12), 6, 8, 20, Color(0.8, 0.92, 1.0, 0.35), Color(0.3, 0.3, 0.35, 0.6))
	_cylinder(clip, b + Vector3(0, 0, 12), 6, 6.8, 8, Color("a3183a", 0.85), Color("c43a58"))
	_cylinder(clip, b + Vector3(0, 0, 32), 8.4, 8.4, 3, Color("2f2d34"), Color("45434b"))
	# Gas cylinder with the burner and the كنكة on top, handle out to the side.
	var g := Vector3(120, 12, Z_FLOOR)
	_cylinder(clip, g, 11, 11, 22, COLOR_CYLINDER, COLOR_CYLINDER.lightened(0.15))
	_cylinder(clip, g + Vector3(0, 0, 22), 6, 6, 4, Color("2c2a30"), Color("3a383f"))
	_cylinder(clip, g + Vector3(0, 0, 26), 8, 9, 12, COLOR_STEEL, Color("2a211d"))
	for piece in Geometry2D.intersect_polygons(clip, PackedVector2Array([iso3(g + Vector3(0, 7, 33)),
			iso3(g + Vector3(0, 24, 36)), iso3(g + Vector3(0, 24, 39)), iso3(g + Vector3(0, 7, 36))])):
		draw_colored_polygon(piece, Color("5a3620"))


## The raised hatch: glass over a short painted tailgate, with its gas struts.
func _draw_open_hatch() -> void:
	var o := _hatch_outline()
	var hinge_n: Vector3 = o[0]
	var hinge_f: Vector3 = o[1]
	var glass_f: Vector3 = o[2]
	var tail_f: Vector3 = o[3]
	var tail_n: Vector3 = o[4]
	var glass_n: Vector3 = o[5]
	# Raised this far we see the hatch's underside: trim panel round the glass.
	var out2 := _swing(HINGE + Vector2(1, 0.8)) - HINGE
	var n := Vector3(out2.x, 0, out2.y)
	var outside := n.dot(VIEW_DIR) > 0.0
	var skin := COLOR_PAINT if outside else COLOR_TRIM
	if not outside:
		n = -n
	var inward := -n.normalized() * 4.0
	# Near edge and bottom edge show the panel's thickness.
	draw_colored_polygon(_project([hinge_n, glass_n, tail_n, tail_n + inward, glass_n + inward, hinge_n + inward]),
		_shade(COLOR_PAINT.darkened(0.25), N_SIDE))
	draw_colored_polygon(_project([tail_f, tail_n, tail_n + inward, tail_f + inward]),
		_shade(COLOR_PAINT.darkened(0.35), N_REAR))
	draw_colored_polygon(_project([hinge_f, glass_f, glass_n, hinge_n]), _shade(skin, n))
	draw_colored_polygon(_project([glass_f, tail_f, tail_n, glass_n]), _shade(skin, n))
	draw_polyline(_project([hinge_n, glass_n, tail_n, tail_f]), _shade(COLOR_PAINT, N_SIDE), 2.5, true)
	var pane := [hinge_f.lerp(glass_f, 0.12).lerp(hinge_n.lerp(glass_n, 0.12), 0.06),
		hinge_f.lerp(glass_f, 0.9).lerp(hinge_n.lerp(glass_n, 0.9), 0.06),
		hinge_n.lerp(glass_n, 0.9).lerp(hinge_f.lerp(glass_f, 0.9), 0.06),
		hinge_n.lerp(glass_n, 0.12).lerp(hinge_f.lerp(glass_f, 0.12), 0.06)]
	var pane_2d := _project(pane)
	# Rear windscreen: sky reflected toward its raised top edge, darker by the
	# hinge, with the heater element lines, the wiper and two light streaks.
	var low := _shade(COLOR_GLASS.lerp(COLOR_SKY_GLASS, 0.25), n)
	var high := _shade(COLOR_GLASS.lerp(COLOR_SKY_GLASS, 0.7), n)
	draw_polygon(pane_2d, PackedColorArray([low, high, high, low]))
	var heater := PackedVector2Array()
	for k in range(1, 7):
		var t := k / 7.0
		heater.append(pane_2d[0].lerp(pane_2d[1], t).lerp(pane_2d[3].lerp(pane_2d[2], t), 0.04))
		heater.append(pane_2d[3].lerp(pane_2d[2], t).lerp(pane_2d[0].lerp(pane_2d[1], t), 0.04))
	draw_multiline(heater, Color(0.55, 0.3, 0.2, 0.45), 1.0)
	for band in [[0.2, 0.3], [0.42, 0.47]]:
		var glint := PackedVector2Array([pane_2d[0].lerp(pane_2d[3], band[0]), pane_2d[0].lerp(pane_2d[3], band[1]),
			pane_2d[1].lerp(pane_2d[2], band[1] + 0.15), pane_2d[1].lerp(pane_2d[2], band[0] + 0.15)])
		for piece in Geometry2D.intersect_polygons(pane_2d, glint):
			draw_colored_polygon(piece, COLOR_GLINT)
	var pivot := pane_2d[0].lerp(pane_2d[3], 0.5).lerp(pane_2d[1].lerp(pane_2d[2], 0.5), 0.08)
	draw_line(pivot, pivot.lerp(pane_2d[1].lerp(pane_2d[2], 0.2), 0.8), COLOR_RUBBER, 2.0, true)
	var seal := pane_2d.duplicate()
	seal.append(pane_2d[0])
	draw_polyline(seal, COLOR_RUBBER, 2.0, true)
	# Lock on the tailgate's lip.
	var lock := tail_f.lerp(tail_n, 0.5).lerp(glass_f.lerp(glass_n, 0.5), 0.2)
	draw_line(iso3(lock + Vector3(0, -5, 0)), iso3(lock + Vector3(0, 5, 0)), _shade(COLOR_CHROME, n), 2.5)
	for side in [-1.0, 1.0]:
		var foot := Vector3(142, side * 50.0, 78)
		var top := Vector3(hinge_n.x, side * 50.0, hinge_n.z).lerp(Vector3(glass_n.x, side * 50.0, glass_n.z), 0.55) + inward
		draw_line(iso3(foot), iso3(foot.lerp(top, 0.55)), Color("2a2a30"), 3.0, true)
		draw_line(iso3(foot.lerp(top, 0.5)), iso3(top), COLOR_CHROME, 1.8, true)


## LED strip round the trunk opening and along the raised hatch's edge, in
## short bands of every colour; layer `group` draws only its colour's LEDs.
func _draw_leds(group: int) -> void:
	var loop: Array = OPENING.duplicate()
	loop.append(OPENING[0])
	var i := _led_run(loop, 0, group)
	var o := _hatch_outline()
	_led_run([o[0], o[5], o[4], o[3], o[2], o[1]], i, group)


func _led_run(path: Array, start: int, group: int) -> int:
	var layer := _led_groups[group]
	var c: Color = LED_COLORS[group]
	var k := start
	for seg in path.size() - 1:
		var a: Vector3 = path[seg]
		var b: Vector3 = path[seg + 1]
		var n := maxi(1, int(a.distance_to(b) / 6.0))
		for j in n:
			if posmod(floori(k / float(LED_BAND)), LED_COLORS.size()) == group:
				var p := iso3(a.lerp(b, j / float(n)))
				layer.draw_circle(p, 6.0, Color(c, 0.25))
				layer.draw_circle(p, 2.3, StationArt.hdr(c.lerp(Color.WHITE, 0.5), 2.2))
			k += 1
	return k


## Sayed's ice box of fruit, set down on the pavement beside the trunk.
func _draw_ice_box() -> void:
	var lo := Vector3(146, HY + 60, Z_PAVEMENT)
	var hi := Vector3(176, HY + 82, Z_PAVEMENT + 20)
	draw_colored_polygon(_project([lo + Vector3(-2, -2, 0), Vector3(hi.x + 6, lo.y - 2, lo.z),
		Vector3(hi.x + 6, hi.y + 4, lo.z), Vector3(lo.x - 2, hi.y + 4, lo.z)]), Color(0, 0, 0, 0.25))
	_draw_box(lo, hi, COLOR_ICEBOX)
	_draw_box(Vector3(lo.x - 1, lo.y - 1, hi.z - 5), Vector3(hi.x + 1, hi.y + 1, hi.z + 1), COLOR_ICEBOX_LID)
	draw_line(iso(lo.x + 8, hi.y + 1.5, hi.z - 9), iso(hi.x - 8, hi.y + 1.5, hi.z - 9), _shade(COLOR_ICEBOX_LID, N_SIDE), 2.5)
	# A couple of mangoes and lemons on the lid.
	for f in [[Vector3(156, HY + 68, hi.z + 3), 4.2, Color("f2a324")], [Vector3(163, HY + 74, hi.z + 3), 4.0, Color("e8c33a")],
			[Vector3(168, HY + 67, hi.z + 2.5), 3.0, Color("f4e04d")]]:
		var at := iso3(f[0])
		draw_circle(at, f[1] * SCALE, f[2] * ambient)
		draw_circle(at + Vector2(-1.2, -1.2) * SCALE, f[1] * 0.35 * SCALE, Color(1, 1, 1, 0.35))


## Corners of the open hatch: hinge (near, far), glass foot (far), tailgate
## foot (far, near), glass foot (near).
func _hatch_outline() -> Array:
	var glass := _swing(Vector2(GH_REAR.x, Z_BELT))
	var tail := _swing(Vector2(HX + 0.5, 46))
	return [Vector3(HINGE.x, 54, HINGE.y), Vector3(HINGE.x, -54, HINGE.y),
		Vector3(glass.x, -60, glass.y), Vector3(tail.x, -46, tail.y),
		Vector3(tail.x, 46, tail.y), Vector3(glass.x, 60, glass.y)]


## A point on the shut hatch, in (x, z), swung open about the hinge.
func _swing(p: Vector2) -> Vector2:
	var d := p - HINGE
	return HINGE + Vector2(d.x * cos(HATCH_OPEN) - d.y * sin(HATCH_OPEN), d.x * sin(HATCH_OPEN) + d.y * cos(HATCH_OPEN))


## Upright (optionally tapered) cylinder standing at c, clipped to a region.
func _cylinder(clip: PackedVector2Array, c: Vector3, r0: float, r1: float, h: float, side: Color, top: Color) -> void:
	var bottom := _flat_ring(c, r0)
	var lid := _flat_ring(c + Vector3(0, 0, h), r1)
	_clipped(clip, _hull(bottom + lid), _shade(side, N_SIDE))
	# Darker rear-facing strip of the body, so it reads round.
	_clipped(clip, _hull(PackedVector2Array([iso3(c + Vector3(r0 * 0.7, -r0 * 0.7, 0)), iso3(c + Vector3(r1 * 0.7, -r1 * 0.7, h)),
		iso3(c + Vector3(r1, 0, h)), iso3(c + Vector3(r0, 0, 0))])), Color(0, 0, 0, 0.18))
	_clipped(clip, lid, _shade(top, N_TOP))


## Circle lying flat (in x-y) at c, projected.
func _flat_ring(c: Vector3, r: float, segments := 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segments:
		var a := TAU * i / segments
		pts.append(iso(c.x + r * cos(a), c.y + r * sin(a), c.z))
	return pts


func _clipped(clip: PackedVector2Array, poly: PackedVector2Array, color: Color) -> void:
	for piece in Geometry2D.intersect_polygons(clip, poly):
		draw_colored_polygon(piece, color)


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


func _shade(base: Color, normal: Vector3) -> Color:
	var n := normal.normalized()
	var key := maxf(n.dot(KEY_DIR.normalized()), 0.0)
	var fill := maxf(n.dot(FILL_DIR.normalized()), 0.0)
	return Color(
		base.r * (0.46 + 0.55 * key + 0.36 * fill) * ambient.r,
		base.g * (0.46 + 0.50 * key + 0.38 * fill) * ambient.g,
		base.b * (0.50 + 0.38 * key + 0.50 * fill) * ambient.b,
		base.a)
