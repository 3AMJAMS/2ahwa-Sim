class_name Fifi3D
extends Node3D
## FIFI on the street, in blocks: Sayed's yellow Fiat 127, parked at the kerb
## with her hatch up so the day's kit shows in the trunk (gas ring and
## كنكة, jars on a wooden rack, the blender, a water jerrycan), LED strips
## round the opening and up the raised hatch, two work bulbs, and the fruit
## ice box down on the pavement. She faces -x; her rear (the trunk) is at
## +x and her left side (+z) faces the pavement and us.

const LENGTH := 3.6
const HALF_W := 0.8
const PAINT := Color("e9b42c")
const CHROME := Color("d4d9e1")
const RUBBER := Color("1b1b21")
const GLASS := Color("24305a")
const TYRE := Color("17171c")
const RIM := Color("a3a9b3")
const TAIL_RED := Color("c3372c")
const TAIL_AMBER := Color("e8962e")
const CARPET := Color("463e46")
const SEAT := Color("6b4a3c")
const TRIM := Color("4a434d")
const WOOD := Color("9a6a3e")
const LED_COLORS := [Color("ff3b3b"), Color("ff8a1f"), Color("ffd23a"), Color("3bff6a"), Color("2fe0ff"),
	Color("3b6bff"), Color("b45cff"), Color("ff4fb8")]
const WHEEL_X := 1.12
const WHEEL_R := 0.29
const SILL_Y := 0.68
const FLOOR_Y := 0.46
const ROOF_Y := 1.46
## The waistline along the doors.
const BELT_Y := 0.88
## Where the cargo area starts (the back of the rear seat).
const BULKHEAD_X := 0.78
## The raised hatch hinges here (x, y).
const HINGE := Vector2(1.42, 1.45)
## Closed, the hatch comes down to here (x, y), just over the sill.
const HATCH_FOOT := Vector2(1.8, 0.7)
const HATCH_OPEN_DEG := 112.0
## FIFI's number plate: the letters spaced apart like a real Egyptian plate
## (doubled spaces, as the font's spaces are narrow).
const PLATE_TEXT := "ش  ا  ي    ١٢٧"

## 0..1, pulsed by WorldHost to invite a tap on the trunk.
var trunk_glow := 0.0:
	set(value):
		trunk_glow = value
		Vox.set_glow("glow/tap", 0.3 + 2.2 * value)
		if _tap_ring:
			_tap_ring.visible = value > 0.01
var darkness := 0.0

var _t := 0.0
var _tap_ring: MeshInstance3D
var _street_parts: Array[Node3D] = []
var _bulb_light: OmniLight3D
var _led_light: OmniLight3D
var _prepping := false


func _ready() -> void:
	var v := Vox.new()
	_underside(v)
	_lower_body(v)
	_glasshouse(v)
	_wheels(v)
	_front(v)
	_side_details(v)
	_ice_box(v)
	v.into(self, "Body")
	# What the detailed prep rig takes over while a drink is made: the rear
	# lamps and bumper, the kit in the trunk, the hatch, the LEDs.
	_rear(v)
	_street_parts.append(v.into(self, "Rear"))
	_trunk(v)
	_street_parts.append(v.into(self, "Kit"))
	var hatch := Node3D.new()
	hatch.name = "Hatch"
	hatch.position = Vector3(HINGE.x, HINGE.y, 0)
	hatch.rotation_degrees.z = HATCH_OPEN_DEG
	add_child(hatch)
	_street_parts.append(hatch)
	_hatch(v)
	v.into(hatch, "HatchMesh")
	_leds(v, hatch)
	_street_parts.append(v.into(self, "Leds"))
	_tap_frame(v)
	_tap_ring = v.into(self, "TapGlow")
	_tap_ring.visible = false
	var plate := Label3D.new()
	plate.text = PLATE_TEXT
	plate.font = preload("res://assets/ui/main_theme.tres").default_font
	plate.font_size = 48
	# Shrink to fit across the plate's 0.48 m white face.
	var text_w := plate.font.get_string_size(PLATE_TEXT, HORIZONTAL_ALIGNMENT_LEFT, -1, plate.font_size).x
	plate.pixel_size = minf(0.0022, 0.42 / maxf(text_w, 1.0))
	plate.outline_size = 0
	plate.modulate = Color("1d1f28")
	plate.position = Vector3(LENGTH * 0.5 + 0.035, 0.34, 0)
	plate.rotation_degrees.y = 90
	add_child(plate)
	_street_parts.append(plate)
	_bulb_light = OmniLight3D.new()
	_bulb_light.position = Vector3(1.3, 1.15, 0)
	_bulb_light.light_color = Color("ffd9a0")
	_bulb_light.omni_range = 2.6
	add_child(_bulb_light)
	_street_parts.append(_bulb_light)
	_led_light = OmniLight3D.new()
	_led_light.position = Vector3(2.4, 0.6, 0.3)
	_led_light.light_color = Color(1.0, 0.55, 0.85)
	_led_light.omni_range = 3.5
	add_child(_led_light)
	set_time(0.0)


func set_time(dark: float) -> void:
	darkness = dark
	Vox.set_glow("glow/bulb", lerpf(1.1, 2.2, dark))
	Vox.set_glow("glow/tail", lerpf(0.0, 1.4, dark))
	_bulb_light.light_energy = lerpf(0.3, 1.6, dark)
	_led_light.light_energy = 1.2 * dark
	# The pink wash on the pavement behind her; in the prep view it would sit
	# between the camera and the trunk and tint everything.
	_led_light.visible = dark > 0.02 and not _prepping


func _process(delta: float) -> void:
	_t += delta
	var lit := lerpf(0.9, 2.6, darkness)
	for g in LED_COLORS.size():
		var breath := 0.5 + 0.5 * sin(_t * 1.4 - g * TAU / LED_COLORS.size())
		Vox.set_glow("glow/led%d" % g, (0.35 + 0.65 * breath * breath) * lit)


## While a drink is made the detailed rig stands in for the tail and the
## trunk; `rig` is shown and the street versions hidden.
func set_prep(on: bool, rig: Node3D) -> void:
	_prepping = on
	set_time(darkness)
	for n in _street_parts:
		n.visible = not on
	if rig:
		rig.visible = on


## Where drinks leave the trunk for the customer (local space).
func trunk_mouth() -> Vector3:
	return Vector3(LENGTH * 0.5 + 0.1, 1.0, 0.3)


## Box round the whole tail, for taps and the tutorial's spotlight (local).
func trunk_aabb() -> AABB:
	return AABB(Vector3(0.9, 0.0, -HALF_W - 0.1), Vector3(1.6, 2.3, HALF_W * 2.0 + 0.2))


## Where the cat curls up (local).
func roof_spot() -> Vector3:
	return Vector3(0.1, ROOF_Y + 0.03, 0.12)


#region Body

func _underside(v: Vox) -> void:
	# Dark asphalt under the car and a softer patch round it.
	v.box(Vector3(-1.95, 0.001, -0.95), Vector3(1.95, 0.004, 0.95), Color("3a3b42"))
	v.box(Vector3(-1.75, 0.004, -0.8), Vector3(1.75, 0.007, 0.8), Color("2c2d33"))
	v.box(Vector3(-1.7, 0.16, -0.72), Vector3(1.7, 0.24, 0.72), Color("1d1c21"))
	# Exhaust out the back under the bumper.
	v.rod(Vector3(1.3, 0.16, -0.45), Vector3(1.9, 0.16, -0.45), 0.03, Color("5a5a60"), 6)


## Side profile with the wheel arches cut in, extruded across the car.
func _profile_front() -> PackedVector2Array:
	var pts := PackedVector2Array([Vector2(BULKHEAD_X + 0.02, 0.22)])
	_arch(pts, -WHEEL_X, true)
	pts.append_array([Vector2(-1.7, 0.22), Vector2(-1.79, 0.34), Vector2(-1.8, 0.58), Vector2(-1.76, 0.7),
		Vector2(-1.3, 0.79), Vector2(-0.7, 0.86), Vector2(BULKHEAD_X + 0.02, 0.88)])
	return pts


func _arch(pts: PackedVector2Array, cx: float, backwards: bool) -> void:
	var r := WHEEL_R + 0.06
	for k in 9:
		var a := PI * k / 8.0
		var x := cx + cos(a) * r * (1.0 if backwards else -1.0)
		pts.append(Vector2(x, 0.3 + sin(a) * r * 0.95))


func _lower_body(v: Vox) -> void:
	v.extrude(_profile_front(), "z", -HALF_W, HALF_W, PAINT)
	# The rear quarters: two side walls round the cargo area with the arch.
	var rear := PackedVector2Array([Vector2(1.72, 0.22)])
	_arch(rear, WHEEL_X, false)
	rear.reverse()
	var side := PackedVector2Array([Vector2(BULKHEAD_X, 0.22)])
	for p in rear:
		side.append(p)
	side.append_array([Vector2(1.72, 0.22), Vector2(1.79, 0.3), Vector2(1.8, SILL_Y), Vector2(BULKHEAD_X, BELT_Y)])
	v.extrude(side, "z", HALF_W - 0.06, HALF_W, PAINT)
	v.extrude(side, "z", -HALF_W, -HALF_W + 0.06, PAINT.darkened(0.05))
	# Rear panel under the opening, and the floor pan.
	v.box(Vector3(1.72, 0.22, -HALF_W + 0.06), Vector3(1.8, SILL_Y, HALF_W - 0.06), PAINT)
	v.box(Vector3(BULKHEAD_X, 0.22, -HALF_W + 0.06), Vector3(1.72, FLOOR_Y, HALF_W - 0.06), Color("2a2528"))
	# Sill: a rubber-lipped chrome strip along the load edge.
	v.box(Vector3(1.66, SILL_Y, -HALF_W + 0.04), Vector3(1.82, SILL_Y + 0.04, HALF_W - 0.04), PAINT.darkened(0.1))
	v.box(Vector3(1.8, SILL_Y - 0.02, -HALF_W + 0.06), Vector3(1.83, SILL_Y + 0.03, HALF_W - 0.06), CHROME)
	# The rubber strip down each flank and the waistline crease, dipping to
	# the tail with the belt.
	for z in [HALF_W, -HALF_W]:
		var s := signf(z)
		v.box(Vector3(-1.72, 0.52, z - s * 0.01), Vector3(1.74, 0.56, z + s * 0.015), RUBBER)
		v.box(Vector3(-1.6, 0.84, z - s * 0.005), Vector3(BULKHEAD_X, 0.86, z + s * 0.008), PAINT.lightened(0.18))
		v.sweep(Vox.round_rect(Rect2(-0.006, -0.01, 0.012, 0.02), 0.0), [Vector3(BULKHEAD_X, 0.85, z + s * 0.002),
			Vector3(1.78, SILL_Y - 0.04, z + s * 0.002)], PAINT.lightened(0.18), Vector3.UP)


func _glasshouse(v: Vox) -> void:
	var gz := HALF_W - 0.1
	# Cabin: windscreen raked back, roof, then the C-pillars down to the tail.
	var cabin := PackedVector2Array([Vector2(-0.7, 0.86), Vector2(BULKHEAD_X, 0.88), Vector2(BULKHEAD_X, ROOF_Y - 0.04),
		Vector2(-0.12, ROOF_Y - 0.04)])
	v.extrude(cabin, "z", -gz, gz, PAINT)
	# Windscreen and side glass.
	v.push_at(Vector3.ZERO)
	var ws := [Vector3(-0.68, 0.9, -gz + 0.06), Vector3(-0.68, 0.9, gz - 0.06), Vector3(-0.15, ROOF_Y - 0.08, gz - 0.08),
		Vector3(-0.15, ROOF_Y - 0.08, -gz + 0.08)]
	var n := Vector3(-0.48, 0.53, 0).normalized()
	var off := n * 0.004
	v.poly([ws[0] + off, ws[1] + off, ws[2] + off, ws[3] + off], GLASS, n)
	v.pop()
	for z in [gz, -gz]:
		var s := signf(z)
		var o := Vector3(0, 0, s * 0.004)
		# Front door glass, B-pillar, rear quarter glass.
		v.poly([Vector3(-0.58, 0.92, z) + o, Vector3(0.3, 0.92, z) + o, Vector3(0.3, ROOF_Y - 0.1, z) + o,
			Vector3(-0.12, ROOF_Y - 0.1, z) + o], GLASS, Vector3(0, 0, s))
		v.poly([Vector3(0.4, 0.92, z) + o, Vector3(1.05, 0.92, z) + o, Vector3(1.05, 1.1, z) + o,
			Vector3(0.9, ROOF_Y - 0.1, z) + o, Vector3(0.4, ROOF_Y - 0.1, z) + o], GLASS, Vector3(0, 0, s))
		# A streak of sky on the glass.
		v.poly([Vector3(-0.3, 0.95, z) + o * 2.0, Vector3(-0.2, 0.95, z) + o * 2.0, Vector3(0.0, ROOF_Y - 0.12, z) + o * 2.0,
			Vector3(-0.1, ROOF_Y - 0.12, z) + o * 2.0], GLASS.lerp(Color("8fb0d8"), 0.35), Vector3(0, 0, s))
		v.box(Vector3(-0.6, 0.9, z - 0.01), Vector3(1.07, 0.93, z + 0.01), RUBBER)
	# C-pillars: from the roof's rear edge down to the tail, hollow behind.
	for s in [1.0, -1.0]:
		var zi: float = s * (gz - 0.05)
		var zo: float = s * gz
		var pill := PackedVector2Array([Vector2(BULKHEAD_X, BELT_Y), Vector2(1.8, SILL_Y), Vector2(1.8, SILL_Y + 0.1),
			Vector2(HINGE.x, ROOF_Y - 0.04), Vector2(BULKHEAD_X, ROOF_Y - 0.04)])
		v.extrude(pill, "z", minf(zi, zo), maxf(zi, zo), PAINT if s > 0 else PAINT.darkened(0.05))
		v.push_at(Vector3(0, 0, s * 0.004))
		v.poly([Vector3(1.05, BELT_Y + 0.02, zo), Vector3(1.5, 0.8, zo), Vector3(HINGE.x - 0.02, ROOF_Y - 0.1, zo),
			Vector3(1.05, ROOF_Y - 0.1, zo)], GLASS, Vector3(0, 0, s))
		v.pop()
	# Roof with rounded edges, drip rails and a gutter.
	v.rbox(Vector3(-0.16, ROOF_Y - 0.05, -gz - 0.02), Vector3(HINGE.x + 0.02, ROOF_Y + 0.02, gz + 0.02), 0.04, PAINT, "x", 2)
	for z in [gz + 0.02, -gz - 0.02]:
		v.box(Vector3(-0.14, ROOF_Y - 0.06, z - 0.012), Vector3(HINGE.x, ROOF_Y - 0.03, z + 0.012), PAINT.darkened(0.15))


func _wheels(v: Vox) -> void:
	for x in [-WHEEL_X, WHEEL_X]:
		for z in [HALF_W - 0.1, -HALF_W + 0.1]:
			var s := signf(z)
			v.push_at(Vector3(x, WHEEL_R, z), Vector3(90, 0, 0))
			v.cyl(Vector3(0, -0.09, 0), WHEEL_R, WHEEL_R, 0.18, TYRE, 12)
			v.cyl(Vector3(0, -0.095 if s < 0 else 0.07, 0), 0.17, 0.17, 0.025, RIM, 10)
			v.cyl(Vector3(0, -0.1 if s < 0 else 0.09, 0), 0.08, 0.08, 0.015, CHROME, 8)
			for k in 4:
				var a := TAU * k / 4.0
				v.cube(Vector3(cos(a) * 0.11, 0.08 * s, sin(a) * 0.11), Vector3(0.03, 0.02, 0.03), Color("6a6e76"))
			v.pop()


func _front(v: Vox) -> void:
	# Chrome bumper with rubber overriders, grille, round headlamps.
	v.rbox(Vector3(-1.9, 0.2, -HALF_W - 0.02), Vector3(-1.79, 0.32, HALF_W + 0.02), 0.035, CHROME, "z", 2)
	for z in [-0.4, 0.4]:
		v.box(Vector3(-1.93, 0.18, z - 0.05), Vector3(-1.86, 0.36, z + 0.05), RUBBER)
	v.box(Vector3(-1.81, 0.44, -0.45), Vector3(-1.79, 0.62, 0.45), Color("1d1c21"))
	for k in 4:
		v.box(Vector3(-1.815, 0.47 + k * 0.04, -0.43), Vector3(-1.8, 0.485 + k * 0.04, 0.43), Color("4a4a52"))
	for z in [-0.6, 0.6]:
		v.push_at(Vector3(-1.8, 0.56, z), Vector3(0, 0, 90))
		v.cyl(Vector3(0, -0.01, 0), 0.1, 0.1, 0.03, CHROME, 10)
		v.use("glow/head")
		v.cyl(Vector3(0, 0.015, 0), 0.08, 0.08, 0.01, Color("fff4d8"), 10)
		v.use("solid")
		v.pop()
		v.box(Vector3(-1.81, 0.38, z - 0.08), Vector3(-1.79, 0.43, z + 0.08), TAIL_AMBER)
	# Badge.
	v.box(Vector3(-1.815, 0.65, -0.06), Vector3(-1.8, 0.69, 0.06), CHROME)


func _rear(v: Vox) -> void:
	var x := LENGTH * 0.5
	# Tail lamps: chrome surrounds, red with an amber indicator outboard.
	for s in [1.0, -1.0]:
		var z0: float = s * 0.45
		var z1: float = s * 0.76
		v.box(Vector3(x - 0.01, 0.44, minf(z0, z1) - 0.01), Vector3(x + 0.02, 0.61, maxf(z0, z1) + 0.01), CHROME)
		v.use("glow/tail")
		v.box(Vector3(x + 0.02, 0.46, minf(z0, z1)), Vector3(x + 0.035, 0.59, maxf(z0, z1)), TAIL_RED)
		v.use("solid")
		var za: float = s * 0.66
		v.box(Vector3(x + 0.035, 0.46, minf(za, z1)), Vector3(x + 0.04, 0.59, maxf(za, z1)), TAIL_AMBER)
		v.box(Vector3(x + 0.035, 0.46, minf(z0, z0 + s * 0.08)), Vector3(x + 0.04, 0.59, maxf(z0, z0 + s * 0.08)), Color("f1ede4"))
	# Plate: white with the blue band (the text is a Label3D).
	v.box(Vector3(x, 0.27, -0.24), Vector3(x + 0.03, 0.41, 0.24), Color("ece8dc"))
	v.box(Vector3(x + 0.03, 0.38, -0.24), Vector3(x + 0.032, 0.41, 0.24), Color("4b87c6"))
	v.box(Vector3(x - 0.01, 0.26, -0.26), Vector3(x + 0.025, 0.42, 0.26), RUBBER)
	# Chrome bumper, rounded, wrapping round the corners, rubber overriders.
	var bar := Vox.round_rect(Rect2(-0.06, 0.2, 0.14, 0.12), 0.04, 2)
	var sec := PackedVector2Array()
	for p in bar:
		sec.append(Vector2(p.x, p.y - 0.26))
	v.sweep(sec, [Vector3(x - 0.25, 0.22, -HALF_W - 0.03), Vector3(x - 0.02, 0.22, -HALF_W + 0.04),
		Vector3(x + 0.02, 0.22, -HALF_W + 0.2), Vector3(x + 0.02, 0.22, HALF_W - 0.2), Vector3(x - 0.02, 0.22, HALF_W - 0.04),
		Vector3(x - 0.25, 0.22, HALF_W + 0.03)], CHROME, Vector3.UP)
	v.box(Vector3(x + 0.06, 0.25, -HALF_W + 0.25), Vector3(x + 0.09, 0.27, HALF_W - 0.25), Color("f4f6f8"))
	for z in [-0.42, 0.42]:
		v.rbox(Vector3(x + 0.02, 0.12, z - 0.05), Vector3(x + 0.12, 0.34, z + 0.05), 0.025, RUBBER, "z", 1)


func _side_details(v: Vox) -> void:
	var z := HALF_W
	# Door shut lines, handle, mirror, fuel filler, side repeater.
	for dx in [-0.62, 0.32]:
		v.box(Vector3(dx - 0.006, 0.24, z), Vector3(dx + 0.006, 0.88, z + 0.004), PAINT.darkened(0.35))
	v.box(Vector3(-0.62, 0.24, z), Vector3(0.32, 0.252, z + 0.004), PAINT.darkened(0.35))
	v.box(Vector3(0.12, 0.76, z), Vector3(0.26, 0.79, z + 0.03), CHROME)
	v.box(Vector3(-0.66, 0.92, z), Vector3(-0.6, 0.96, z + 0.08), RUBBER)
	v.box(Vector3(-0.7, 0.93, z + 0.08), Vector3(-0.56, 1.03, z + 0.14), RUBBER)
	v.box(Vector3(-0.69, 0.94, z + 0.14), Vector3(-0.57, 1.02, z + 0.145), Color("5a6a8a"))
	v.push_at(Vector3(1.3, 0.64, z), Vector3(90, 0, 0))
	v.cyl(Vector3.ZERO, 0.045, 0.045, 0.012, CHROME, 8)
	v.pop()
	v.box(Vector3(-1.35, 0.66, z), Vector3(-1.28, 0.69, z + 0.012), TAIL_AMBER)
	# A strip of stickers: the Fiat script and a hand of Fatima on the rear glass.
	v.box(Vector3(-1.05, 0.62, z), Vector3(-0.8, 0.66, z + 0.004), Color("f1ede4"))
	for zz in [HALF_W, -HALF_W]:
		var s := signf(zz)
		v.box(Vector3(-1.66, 0.5, zz - s * 0.01), Vector3(1.66, 0.51, zz + s * 0.003), PAINT.darkened(0.2))


## Looking in over the sill: carpet, seat back, trim walls, headliner, the
## wooden rack of jars, the gas ring with the كنكة, the blender, a jerrycan.
func _trunk(v: Vox) -> void:
	var zi := HALF_W - 0.08
	v.box(Vector3(BULKHEAD_X, FLOOR_Y, -zi), Vector3(1.74, FLOOR_Y + 0.03, zi), CARPET)
	v.box(Vector3(BULKHEAD_X - 0.05, FLOOR_Y, -zi), Vector3(BULKHEAD_X, ROOF_Y - 0.08, zi), SEAT)
	v.box(Vector3(BULKHEAD_X, FLOOR_Y + 0.02, -zi), Vector3(BULKHEAD_X + 0.03, 1.28, zi), SEAT.darkened(0.12))
	for k in 6:
		var zz := -zi + 0.12 + k * 0.23
		v.box(Vector3(BULKHEAD_X + 0.03, 0.6, zz - 0.004), Vector3(BULKHEAD_X + 0.035, 1.18, zz + 0.004), SEAT.darkened(0.3))
	for s in [1.0, -1.0]:
		v.box(Vector3(BULKHEAD_X, FLOOR_Y, s * zi - 0.02), Vector3(1.72, ROOF_Y - 0.06, s * zi + 0.02), TRIM)
		# Wheel-arch humps.
		v.rbox(Vector3(0.95, FLOOR_Y, s * zi - 0.15), Vector3(1.35, FLOOR_Y + 0.18, s * zi), 0.06, TRIM.lightened(0.08), "z", 2)
	v.box(Vector3(BULKHEAD_X, ROOF_Y - 0.08, -zi), Vector3(HINGE.x, ROOF_Y - 0.05, zi), Color("4d463f"))
	# Rubber mat.
	v.box(Vector3(1.0, FLOOR_Y + 0.03, -0.5), Vector3(1.66, FLOOR_Y + 0.036, 0.5), Color("26232a"))
	# Wooden rack across the seat back with the day's jars and cups.
	var ry := 0.84
	v.box(Vector3(BULKHEAD_X + 0.02, ry, -zi + 0.02), Vector3(BULKHEAD_X + 0.24, ry + 0.025, zi - 0.02), WOOD)
	v.box(Vector3(BULKHEAD_X + 0.22, ry - 0.03, -zi + 0.02), Vector3(BULKHEAD_X + 0.24, ry + 0.04, zi - 0.02), WOOD.darkened(0.15))
	for zz in [-zi + 0.05, zi - 0.05]:
		v.box(Vector3(BULKHEAD_X + 0.1, FLOOR_Y, zz - 0.015), Vector3(BULKHEAD_X + 0.13, ry, zz + 0.015), WOOD.darkened(0.35))
	var jars := [Color("3b2412"), Color("f1ede4"), Color("7a1428"), Color("4a2b1b"), Color("c8a060")]
	for i in jars.size():
		var jz := -0.5 + i * 0.13
		v.cyl(Vector3(BULKHEAD_X + 0.12, ry + 0.025, jz), 0.045, 0.045, 0.12, jars[i], 8)
		v.cyl(Vector3(BULKHEAD_X + 0.12, ry + 0.145, jz), 0.048, 0.048, 0.025, Color("c9a24a"), 8)
		v.box(Vector3(BULKHEAD_X + 0.164, ry + 0.06, jz - 0.03), Vector3(BULKHEAD_X + 0.168, ry + 0.1, jz + 0.03), Color("f1ede4"))
	for i in 6:
		v.cyl(Vector3(BULKHEAD_X + 0.12, ry + 0.025 + i * 0.018, 0.25), 0.04, 0.032, 0.02, Color("f1ede4"), 8)
	for i in 3:
		v.cyl(Vector3(BULKHEAD_X + 0.12, ry + 0.025, 0.36 + i * 0.07), 0.028, 0.022, 0.09, Color("b8d0e0"), 8)
	# Gas cylinder with the ring and the كنكة on top.
	var g := Vector3(1.42, FLOOR_Y + 0.03, 0.3)
	v.cyl(g, 0.15, 0.15, 0.3, Color("b8452f"), 10)
	v.lathe([Vector2(0.15, 0.3), Vector2(0.11, 0.37), Vector2(0.05, 0.4)], 10, Color("b8452f"))
	v.cyl(g + Vector3(0, 0.12, 0), 0.152, 0.152, 0.04, Color("efe6d2"), 10)
	v.cyl(g + Vector3(0, 0.4, 0), 0.05, 0.04, 0.04, Color("2c2a30"), 8)
	v.use("glow/flame")
	for k in 6:
		var a := TAU * k / 6.0
		v.cube(g + Vector3(cos(a) * 0.035, 0.46, sin(a) * 0.035), Vector3(0.018, 0.04, 0.018), Color("4a7aff"))
	v.use("solid")
	v.lathe([Vector2(0.075, 0.47), Vector2(0.085, 0.5), Vector2(0.08, 0.58), Vector2(0.065, 0.62), Vector2(0.08, 0.66)],
		10, Color("b3b9c2"), false)
	v.cyl(g + Vector3(0, 0.0, 0) + Vector3(0, 0.6, 0), 0.066, 0.066, 0.01, Color("3a2016"), 10)
	v.rod(g + Vector3(0, 0.6, -0.07), g + Vector3(-0.02, 0.64, -0.26), 0.012, Color("5a3620"))
	# Blender at the back, squat base, jar and lid.
	var b := Vector3(1.05, FLOOR_Y + 0.03, -0.45)
	v.box(b + Vector3(-0.1, 0, -0.09), b + Vector3(0.1, 0.13, 0.09), Color("e8e0cc"))
	v.box(b + Vector3(0.1, 0.03, -0.05), b + Vector3(0.105, 0.09, 0.05), Color("2b2a30"))
	v.use("glass")
	v.cyl(b + Vector3(0, 0.13, 0), 0.07, 0.09, 0.26, Color(0.8, 0.92, 1.0, 0.35), 8)
	v.use("solid")
	v.cyl(b + Vector3(0, 0.14, 0), 0.068, 0.075, 0.09, Color("a3183a"), 8)
	v.cyl(b + Vector3(0, 0.39, 0), 0.095, 0.095, 0.035, Color("2f2d34"), 8)
	# Water jerrycan and a crate of glasses.
	var j := Vector3(1.5, FLOOR_Y + 0.03, -0.35)
	v.rbox(j + Vector3(-0.1, 0, -0.15), j + Vector3(0.1, 0.32, 0.15), 0.03, Color("2f6fb3"), "x", 1)
	v.cyl(j + Vector3(0, 0.32, 0.08), 0.03, 0.03, 0.04, Color("f2c230"), 6)
	v.box(j + Vector3(-0.03, 0.32, -0.1), j + Vector3(0.03, 0.36, 0.02), Color("2f6fb3"))
	# Two work bulbs hanging from the roof.
	for zz in [-0.35, 0.35]:
		v.rod(Vector3(1.3, ROOF_Y - 0.08, zz), Vector3(1.3, 1.2, zz), 0.006, Color("1d1b20"), 4)
		v.use("glow/bulb")
		v.ball(Vector3(1.3, 1.17, zz), Vector3(0.035, 0.045, 0.035), Color("fff1d6"), 6, 3)
		v.use("solid")
	# A string of prayer beads and a hand of Fatima charm off the roof.
	for k in 8:
		v.cube(Vector3(1.05, 1.24 - k * 0.025, 0.05), Vector3(0.02, 0.02, 0.02), Color("2e5a3a") if k % 3 else Color("c9a24a"))
	v.box(Vector3(1.04, 1.02, 0.02), Vector3(1.06, 1.06, 0.08), Color("2a6ab0"))


## The raised hatch, built closed in its own space (hinge at the origin)
## then swung up: painted frame, rear glass with heater lines, wiper, the
## lock on its lip, the rubber seal, struts.
func _hatch(v: Vox) -> void:
	# Closed it runs from the hinge down to the tail's top corner.
	var foot := HATCH_FOOT - HINGE
	var along := foot.normalized()
	var n := Vector2(along.y, -along.x)  # outward (rear/up) when closed
	var len := foot.length()
	var zo := HALF_W - 0.08
	var th := 0.05
	var pts := PackedVector2Array([Vector2.ZERO, foot, foot - n * th, -n * th])
	v.extrude(pts, "z", -zo, zo, PAINT)
	# Glass pane on the outer face, framed in paint, heater lines and wiper.
	var g0 := along * 0.06 + n * 0.004
	var g1 := along * (len - 0.14) + n * 0.004
	var gz := zo - 0.08
	var nn := Vector3(n.x, n.y, 0)
	v.poly([Vector3(g0.x, g0.y, -gz), Vector3(g1.x, g1.y, -gz), Vector3(g1.x, g1.y, gz), Vector3(g0.x, g0.y, gz)], GLASS, nn)
	for k in range(1, 6):
		var p := along * lerpf(0.1, len - 0.18, k / 6.0) + n * 0.006
		v.poly([Vector3(p.x, p.y, -gz + 0.04), Vector3(p.x + along.x * 0.006, p.y + along.y * 0.006, -gz + 0.04),
			Vector3(p.x + along.x * 0.006, p.y + along.y * 0.006, gz - 0.04), Vector3(p.x, p.y, gz - 0.04)],
			Color("6a4a3a"), nn)
	var w0 := along * (len - 0.16) + n * 0.02
	v.rod(Vector3(w0.x, w0.y, 0.0), Vector3(w0.x - along.x * 0.3, w0.y - along.y * 0.3, 0.35), 0.008, RUBBER, 4)
	# Underside (what we see raised): bare painted steel with pressed holes.
	var u0 := -n * (th + 0.003)
	for zz in [-0.35, -0.15, 0.15, 0.35]:
		var c := along * (len * 0.55) + u0
		v.poly([Vector3(c.x - along.x * 0.08, c.y - along.y * 0.08, zz - 0.06), Vector3(c.x + along.x * 0.08, c.y + along.y * 0.08, zz - 0.06),
			Vector3(c.x + along.x * 0.08, c.y + along.y * 0.08, zz + 0.06), Vector3(c.x - along.x * 0.08, c.y - along.y * 0.08, zz + 0.06)],
			PAINT.darkened(0.45), -nn)
	# Lock plate on the lip, the seal round the edge.
	var lock := along * (len - 0.04) + u0
	v.poly([Vector3(lock.x, lock.y, -0.08), Vector3(lock.x - along.x * 0.06, lock.y - along.y * 0.06, -0.08),
		Vector3(lock.x - along.x * 0.06, lock.y - along.y * 0.06, 0.08), Vector3(lock.x, lock.y, 0.08)], Color("2c2a30"), -nn)
	v.box(Vector3(foot.x - 0.02, foot.y - 0.02, -zo), Vector3(foot.x + 0.01, foot.y + 0.01, zo), RUBBER)
	# Gas struts back down to the body.
	for zz in [-zo + 0.05, zo - 0.05]:
		var top := along * (len * 0.45) - n * th
		v.rod(Vector3(top.x, top.y, zz), Vector3(top.x + along.x * 0.3, top.y + along.y * 0.3, zz), 0.014, Color("2a2a30"), 5)


## LED strip round the opening and along the raised hatch's edges, in short
## bands of every colour; each colour breathes in turn (glow/ledN).
func _leds(v: Vox, hatch: Node3D) -> void:
	var zi := HALF_W - 0.09
	var loop := [Vector3(1.82, SILL_Y + 0.05, -zi), Vector3(1.82, SILL_Y + 0.05, zi), Vector3(1.8, SILL_Y + 0.12, zi),
		Vector3(HINGE.x + 0.02, ROOF_Y - 0.05, zi - 0.05), Vector3(HINGE.x + 0.02, ROOF_Y - 0.05, -zi + 0.05),
		Vector3(1.8, SILL_Y + 0.12, -zi), Vector3(1.82, SILL_Y + 0.05, -zi)]
	var k := _led_run(v, loop, 0)
	# The hatch edges, carried into car space through the hinge.
	var xf := hatch.transform
	var foot := HATCH_FOOT - HINGE
	var along := foot.normalized()
	var n := Vector2(along.y, -along.x)
	var e := -n * 0.056
	var zo := HALF_W - 0.1
	var edge := [Vector3(e.x, e.y, -zo), Vector3(foot.x + e.x, foot.y + e.y, -zo), Vector3(foot.x + e.x, foot.y + e.y, zo),
		Vector3(e.x, e.y, zo)]
	var pts: Array = []
	for p in edge:
		pts.append(xf * (p as Vector3))
	_led_run(v, pts, k)


func _led_run(v: Vox, path: Array, start: int) -> int:
	var k := start
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var n := maxi(1, int(a.distance_to(b) / 0.05))
		for j in n:
			var g := posmod(floori(k / 3.0), LED_COLORS.size())
			v.use("glow/led%d" % g)
			v.cube(a.lerp(b, j / float(n)), Vector3(0.022, 0.022, 0.022), LED_COLORS[g])
			k += 1
	v.use("solid")
	return k


## The golden frame that pulses round the opening to invite a tap.
func _tap_frame(v: Vox) -> void:
	v.use("glow/tap")
	var zi := HALF_W - 0.02
	var c := Color("ffc861")
	var pts := [Vector3(1.86, SILL_Y, -zi), Vector3(1.86, SILL_Y, zi), Vector3(1.82, SILL_Y + 0.12, zi), Vector3(HINGE.x + 0.04, ROOF_Y + 0.02, zi),
		Vector3(HINGE.x + 0.04, ROOF_Y + 0.02, -zi), Vector3(1.82, SILL_Y + 0.12, -zi), Vector3(1.86, SILL_Y, -zi)]
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.018, 0.018), 4), pts, c, Vector3.RIGHT, false)
	v.use("solid")


## Sayed's ice box of fruit, down on the pavement beside the trunk.
func _ice_box(v: Vox) -> void:
	var at := Vector3(2.0, Street3D.KERB_H, 1.75)
	v.box(at + Vector3(-0.26, 0, -0.18), at + Vector3(0.26, 0.3, 0.18), Color("2f6fb3"))
	v.rbox(at + Vector3(-0.28, 0.3, -0.2), at + Vector3(0.28, 0.37, 0.2), 0.02, Color("eef1f4"), "x", 1)
	v.box(at + Vector3(-0.12, 0.33, 0.2), at + Vector3(0.12, 0.35, 0.22), Color("c9ced6"))
	for s in [-1.0, 1.0]:
		v.box(at + Vector3(s * 0.26, 0.2, -0.05), at + Vector3(s * 0.28, 0.24, 0.05), Color("c9ced6"))
	for f in [[Vector3(-0.1, 0.42, -0.05), 0.06, Color("f2a324")], [Vector3(0.05, 0.42, 0.06), 0.055, Color("e8c33a")],
			[Vector3(0.14, 0.41, -0.08), 0.045, Color("f4e04d")], [Vector3(-0.02, 0.41, -0.1), 0.045, Color("f4e04d")]]:
		v.ball(at + (f[0] as Vector3), Vector3.ONE * float(f[1]), f[2], 6, 3)

#endregion
