class_name PrepRig
extends Node3D
## FIFI's tail and trunk up close, where the drinks are made. Mounted on
## FIFI (her local space: the tail at +x, her left side at +z) and shown
## only while Sayed works, it stands in for the plainer street version:
## lamp clusters with chrome bezels and ribbed lenses, the plate, a rounded
## chrome bumper with its rubber strip, and the raised hatch seen from below
## (pressed inner panel, seal, latch, struts). Inside: a wooden counter
## across the sill for the stove, the glass and the jars, two work bulbs,
## and Sayed's movable racks (the rail of كنكة and the ladle, the chalk menu
## board). Kept plain on purpose: decorations and the racks Sayed buys come
## with the Phase B upgrade shop. The camera stands behind the car at hatch
## height looking down in.

const PAINT := Color("e9b42c")
const CHROME := Color("d4d9e1")
## What baked chrome is toned from: a touch darker, so the sun at the car's
## back doesn't burn it white.
const CHROME_TONE := Color("a4abb5")
const RUBBER := Color("1b1b21")
const TRIM := Color("4a434d")
const CARPET := Color("463e46")
const SEAT := Color("6b4a3c")
const WOOD := Color("9a6a3e")
const METAL := Color("b3b9c2")
const METAL_DARK := Color("6f7682")
const GRIP := Color("5a3620")
const BOARD := Color("22302a")

const REAR_X := 1.8
const COUNTER_Y := 0.72
const COUNTER_X := Vector2(1.26, 1.8)
## Where the kit stands on the counter.
const GLASS_AT := Vector3(1.6, COUNTER_Y, 0.14)
const STOVE_AT := Vector3(1.5, COUNTER_Y, -0.24)
## Where the kanaka that isn't on the fire rests.
const IDLE_POT_AT := Vector3(1.34, COUNTER_Y, -0.5)
## The jars along the counter's back and left: where each ingredient's
## spoonful comes from.
const JARS := {
	"sugar": Vector3(1.62, COUNTER_Y, 0.6),
	"ice": Vector3(1.64, COUNTER_Y, 0.42),
	"tea": Vector3(1.38, COUNTER_Y, 0.64),
	"coffee": Vector3(1.38, COUNTER_Y, 0.5),
	"karkade": Vector3(1.38, COUNTER_Y, 0.36),
	"teabag": Vector3(1.4, COUNTER_Y, 0.2),
	"mint": Vector3(1.7, COUNTER_Y, -0.4),
	"milk": Vector3(1.47, COUNTER_Y, -0.52),
	"anise": Vector3(1.36, COUNTER_Y, 0.04),
	"cinnamon": Vector3(1.6, COUNTER_Y, -0.5),
}
## The rail racks hang under the roof's rear edge, across the top of the
## opening (each at an x across); the chalk board is fixed flat on the
## hatch's inner panel (how far up it 0..1, across).
const RAIL := Vector2(1.36, Fifi3D.ROOF_Y - 0.1)
const RAIL_Z := Vector2(-0.44, 0.44)
const RACK_T := Vector2(0.3, 0.7)
const RACKS := {"hooks": Vector2(0.0, 0.16), "board": Vector2(0.5, 0.0)}
## Camera: behind the tail at hatch height, looking down into the trunk.
const CAM_AT := Vector3(2.72, 2.12, 0.0)
const CAM_LOOK := Vector3(1.42, 0.95, 0.0)
## Horizontal field of view the car is framed to (degrees), and the design
## aspect it holds on wider screens.
const H_FOV := 43.0
const DESIGN_ASPECT := 0.75

var camera := Camera3D.new()
var racks := {}
## Racks' spots on the hatch: id -> Vector2(t, z).
var rack_spots := {}
var _hatch_node: Node3D
var arranging := false

var _t := 0.0
var _cam_home := Transform3D.IDENTITY
var _shake := 0.0
var _shake_t := 0.0
var _work_light := OmniLight3D.new()


func _ready() -> void:
	var v := Vox.new()
	_rear(v)
	_counter(v)
	_trunk(v)
	_bulbs(v)
	v.into(self, "Rig")
	var hatch := Node3D.new()
	_hatch_node = hatch
	hatch.position = Vector3(Fifi3D.HINGE.x, Fifi3D.HINGE.y, 0)
	hatch.rotation_degrees.z = Fifi3D.HATCH_OPEN_DEG
	add_child(hatch)
	# The hatch fills the top of the screen and the bulb only grazes it:
	# per-vertex shading there looks the same and costs far less.
	v.vertex_lit = true
	_hatch(v)
	# It only ever shadowed itself (speckled acne along its ribs); FIFI's
	# roof already shades the trunk.
	v.into(hatch, "Hatch").cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	v.vertex_lit = false
	_struts(v, hatch)
	v.into(self, "Struts")
	for id in RACKS:
		var r := Node3D.new()
		r.name = "Rack_" + id
		add_child(r)
		match id:
			"hooks":
				_rack_hooks(v)
			"board":
				_rack_board(v, r)
		v.into(r, "Mesh")
		racks[id] = r
	_load_racks()
	_labels()
	# The work bulb's light, per pixel for its soft falloff over the counter.
	# It sits a little forward of the two bulbs, over the kit, so the fronts
	# of the kanakas and jars (the side we see) catch it too. One light only:
	# each costs on every pixel of every mesh it reaches.
	_work_light.position = Vector3(1.4, 1.2, 0.0)
	_work_light.light_color = Color("ffd9a0")
	_work_light.omni_range = 2.5
	_work_light.omni_attenuation = 1.0
	_work_light.light_cull_mask = Street3D.LIT_MASK
	add_child(_work_light)
	DayClock.minute_changed.connect(_light_for_time)
	_light_for_time()
	camera.position = CAM_AT
	add_child(camera)
	camera.transform = Transform3D(Basis.looking_at(CAM_LOOK - CAM_AT, Vector3.UP), CAM_AT)
	_cam_home = camera.transform
	camera.near = 0.05
	camera.far = 120.0
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


## The work bulb counts for more once the street is dark.
func _light_for_time() -> void:
	var dark := DayClock.darkness()
	_work_light.light_energy = lerpf(1.0, 1.45, dark)


## Holds the car's width on tall screens and the design height on wide ones.
func _fit_camera() -> void:
	var vis := get_viewport().get_visible_rect().size
	if vis.y <= 0.0:
		return
	var aspect := vis.x / vis.y
	if aspect <= DESIGN_ASPECT:
		camera.keep_aspect = Camera3D.KEEP_WIDTH
		camera.fov = H_FOV
	else:
		camera.keep_aspect = Camera3D.KEEP_HEIGHT
		camera.fov = rad_to_deg(2.0 * atan(tan(deg_to_rad(H_FOV) * 0.5) / DESIGN_ASPECT))


func _process(delta: float) -> void:
	if not is_visible_in_tree():
		return
	_t += delta
	if _shake > 0.0:
		_shake_t += delta
		_shake = maxf(_shake - delta, 0.0)
		var k := _shake * 0.02
		camera.transform = _cam_home.translated(Vector3(sin(_shake_t * 71.0), sin(_shake_t * 53.0), 0) * k)
	else:
		camera.transform = _cam_home


## Something went wrong: a jolt of the view.
func jolt(strength := 1.0) -> void:
	_shake = 0.35 * strength
	_shake_t = 0.0


## World point to screen (overlay) coordinates.
func screen_point(world: Vector3) -> Vector2:
	return camera.unproject_position(world)


func screen_rect_of(box: AABB) -> Rect2:
	var r := Rect2(screen_point(box.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(screen_point(box.get_endpoint(i)))
	return r


## Screen rect round a jar (for pulses and the tutorial).
func jar_rect(id: String) -> Rect2:
	var at: Vector3 = JARS.get(id, GLASS_AT)
	return screen_rect_of(global_transform * AABB(at + Vector3(-0.06, 0, -0.06), Vector3(0.12, 0.16, 0.12)))


#region The tail

func _rear(v: Vox) -> void:
	var x := REAR_X
	var hw := Fifi3D.HALF_W
	for s in [1.0, -1.0]:
		_lamp(v, s)
	_plate(v)
	# The load sill: painted lip, chrome strip, rubber seal.
	v.rbox(Vector3(1.66, Fifi3D.SILL_Y - 0.02, -hw + 0.05), Vector3(x + 0.02, Fifi3D.SILL_Y + 0.02, hw - 0.05), 0.012,
		PAINT.darkened(0.08), "z", 2)
	var m := v.mark()
	v.rbox(Vector3(x - 0.01, Fifi3D.SILL_Y - 0.03, -hw + 0.07), Vector3(x + 0.03, Fifi3D.SILL_Y + 0.025, hw - 0.07), 0.016,
		CHROME, "z", 3)
	v.chrome(m, CHROME_TONE)
	v.rbox(Vector3(1.74, Fifi3D.SILL_Y + 0.015, -hw + 0.08), Vector3(1.8, Fifi3D.SILL_Y + 0.037, hw - 0.08), 0.009, RUBBER, "z", 2)
	_bumper(v)
	# Tow eye and the exhaust's tip (rolled lip, sooty inside).
	v.rod(Vector3(x, 0.12, 0.3), Vector3(x + 0.07, 0.12, 0.3), 0.012, Color("3a3a40"), 8)
	v.push_at(Vector3(x + 0.076, 0.12, 0.3), Vector3(0, 0, 90))
	v.torus(Vector3.ZERO, 0.016, 0.006, Color("3a3a40"), 10, 8)
	v.pop()
	v.push_at(Vector3(x - 0.12, 0.13, -0.45), Vector3(0, 0, -90))
	v.lathe([Vector2(0.035, 0.0), Vector2(0.035, 0.12)], 10, Color("5a5a60"), false, false)
	v.lathe([Vector2(0.03, 0.12), Vector2(0.03, 0.04)], 10, Color("1a1a1a"), false, false)
	v.cyl(Vector3(0, 0.04, 0), 0.03, 0.03, 0.002, Color("101010"), 10)
	v.torus(Vector3(0, 0.12, 0), 0.0325, 0.005, Color("6a6a70"), 10, 8)
	v.pop()


## One lamp cluster: a rounded chrome bezel with a rolled rim round three
## lenses (the ribbed red tail, the amber indicator outboard, the white
## reversing lamp inboard) split by chrome bars.
func _lamp(v: Vox, s: float) -> void:
	var x := REAR_X
	var outer: float = s * 0.77
	var inner: float = s * 0.44
	var lo := minf(inner, outer)
	var hi := maxf(inner, outer)
	var m := v.mark()
	v.rbox(Vector3(x - 0.01, 0.43, lo - 0.015), Vector3(x + 0.03, 0.62, hi + 0.015), 0.03, CHROME, "x", 3)
	v.loop(Vox.circle(Vector2.ZERO, Vector2(0.007, 0.007), 6),
		Vox.rect_path(Rect2(lo - 0.006, 0.437, hi - lo + 0.012, 0.176), 0.026, "x", x + 0.03, 3), CHROME, Vector3.RIGHT)
	v.chrome(m, CHROME_TONE)
	# The red lens glows; its moulded ribs catch the light.
	var r0 := lo + 0.077
	var r1 := hi - 0.077
	v.use("glow/tail")
	v.rbox(Vector3(x + 0.022, 0.452, r0), Vector3(x + 0.044, 0.598, r1), 0.014, Color("c3372c"), "x", 2)
	v.use("solid")
	for k in 6:
		var y := 0.459 + k * 0.0225
		v.rbox(Vector3(x + 0.042, y, r0 + 0.008), Vector3(x + 0.05, y + 0.012, r1 - 0.008), 0.0038, Color("e0584a"), "z", 1)
	# Amber and white, each with fine upright ribs.
	for part in [[outer - s * 0.07, outer - s * 0.008, Color("e8962e")], [inner + s * 0.008, inner + s * 0.07, Color("f1ede4")]]:
		var a: float = minf(part[0], part[1])
		var b: float = maxf(part[0], part[1])
		var col: Color = part[2]
		v.rbox(Vector3(x + 0.022, 0.452, a), Vector3(x + 0.046, 0.598, b), 0.012, col, "x", 2)
		for k in 3:
			var z := lerpf(a + 0.014, b - 0.014, k / 2.0)
			v.rbox(Vector3(x + 0.044, 0.462, z - 0.005), Vector3(x + 0.051, 0.588, z + 0.005), 0.003, col.lightened(0.15), "y", 1)
	m = v.mark()
	for zz in [outer - s * 0.07, inner + s * 0.07]:
		v.rbox(Vector3(x + 0.03, 0.445, zz - 0.0045), Vector3(x + 0.055, 0.605, zz + 0.0045), 0.004, CHROME, "y", 1)
	v.chrome(m, CHROME_TONE)


## The plate in its rounded rubber frame: pressed rim, blue مصر band,
## domed screws.
func _plate(v: Vox) -> void:
	var x := REAR_X
	v.rbox(Vector3(x - 0.005, 0.285, -0.27), Vector3(x + 0.03, 0.455, 0.27), 0.02, RUBBER, "x", 2)
	v.rbox(Vector3(x + 0.026, 0.295, -0.255), Vector3(x + 0.036, 0.445, 0.255), 0.01, Color("ece8dc"), "x", 2)
	v.loop(Vox.circle(Vector2.ZERO, Vector2(0.0025, 0.0025), 5),
		Vox.rect_path(Rect2(-0.247, 0.302, 0.494, 0.136), 0.008, "x", x + 0.036, 2), Color("d6d1c3"), Vector3.RIGHT)
	v.box(Vector3(x + 0.036, 0.41, -0.243), Vector3(x + 0.038, 0.438, 0.243), Color("4b87c6"))
	for z in [-0.22, 0.22]:
		v.push_at(Vector3(x + 0.037, 0.424, z), Vector3(0, 0, -90))
		v.lathe([Vector2(0.008, 0.0), Vector2(0.0075, 0.0018), Vector2(0.005, 0.0033), Vector2(0.0, 0.0038)], 8, CHROME)
		v.pop()
		v.box(Vector3(x + 0.0405, 0.4225, z - 0.005), Vector3(x + 0.0415, 0.4255, z + 0.005), Color("6a6e76"))


## Round-edged chrome bumper wrapping the corners on true arcs, its rubber
## strip and pinstripe, the rounded overriders, the brackets under it.
func _bumper(v: Vox) -> void:
	var x := REAR_X
	var hw := Fifi3D.HALF_W
	var sec := Vox.round_rect(Rect2(-0.065, -0.07, 0.13, 0.14), 0.055, 4)
	var rad := 0.17
	var path: Array = [Vector3(x - 0.3, 0.22, -hw - 0.03)]
	for k in 9:
		var a := PI * 0.5 * (1.0 - k / 8.0)
		path.append(Vector3(x + 0.05 - rad + cos(a) * rad, 0.22, -(hw + 0.03 - rad + sin(a) * rad)))
	for k in 9:
		var a := PI * 0.5 * k / 8.0
		path.append(Vector3(x + 0.05 - rad + cos(a) * rad, 0.22, hw + 0.03 - rad + sin(a) * rad))
	path.append(Vector3(x - 0.3, 0.22, hw + 0.03))
	var m := v.mark()
	v.sweep(sec, path, CHROME, Vector3.UP)
	v.chrome(m, CHROME_TONE)
	v.rbox(Vector3(x + 0.1, 0.203, -hw + 0.26), Vector3(x + 0.126, 0.237, hw - 0.26), 0.012, RUBBER, "z", 2)
	v.box(Vector3(x + 0.108, 0.262, -hw + 0.3), Vector3(x + 0.112, 0.268, hw - 0.3), Color("f7f9fb"))
	for z in [-0.42, 0.42]:
		v.rbox(Vector3(x + 0.05, 0.15, z - 0.035), Vector3(x + 0.13, 0.3, z + 0.035), 0.03, RUBBER, "y", 3)
		for yy in [0.15, 0.3]:
			v.ball(Vector3(x + 0.09, yy, z), Vector3(0.037, 0.012, 0.032), RUBBER, 10, 3)
		v.rbox(Vector3(x - 0.05, 0.14, z - 0.03), Vector3(x + 0.02, 0.18, z + 0.03), 0.008, Color("2a2a30"), "z", 1)


func _labels() -> void:
	var font: Font = preload("res://assets/ui/main_theme.tres").default_font
	var plate := Label3D.new()
	plate.text = Fifi3D.PLATE_TEXT
	plate.font = font
	plate.font_size = 64
	plate.pixel_size = 0.00105
	plate.outline_size = 0
	plate.modulate = Color("1d1f28")
	plate.position = Vector3(REAR_X + 0.04, 0.352, 0)
	plate.rotation_degrees.y = 90
	add_child(plate)
	var egypt := Label3D.new()
	egypt.text = "مصر"
	egypt.font = font
	egypt.font_size = 32
	egypt.pixel_size = 0.0009
	egypt.outline_size = 0
	egypt.modulate = Color("f4f1ea")
	egypt.position = Vector3(REAR_X + 0.041, 0.428, 0.12)
	egypt.rotation_degrees.y = 90
	add_child(egypt)

#endregion


#region Inside

## A wooden board across the trunk at sill height: everything is made on it.
## Six planks with rounded edges, grain, knots and nail heads, a steel nosing
## at the front and a batten at the back.
func _counter(v: Vox) -> void:
	var hw := Fifi3D.HALF_W - 0.1
	var w := (COUNTER_X.y - COUNTER_X.x) / 6.0
	for i in 6:
		var x0 := COUNTER_X.x + i * w + 0.0015
		var x1 := x0 + w - 0.003
		var col := WOOD.lightened(0.05) if i % 3 == 0 else (WOOD.darkened(0.06) if i % 3 == 1 else WOOD)
		v.rbox(Vector3(x0, COUNTER_Y - 0.03, -hw), Vector3(x1, COUNTER_Y, hw), 0.006, col, "z", 1)
		# Grain: long dark streaks of uneven length.
		for g in 3:
			var xc := lerpf(x0 + 0.014, x1 - 0.014, g / 2.0) + sin(i * 3.1 + g * 1.7) * 0.006
			var za := -hw + 0.04 + absf(sin(i * 1.3 + g * 2.9)) * 0.35
			var zb := hw - 0.04 - absf(cos(i * 2.1 + g * 1.1)) * 0.35
			v.box(Vector3(xc - 0.0012, COUNTER_Y, za), Vector3(xc + 0.0012, COUNTER_Y + 0.0006, zb), col.darkened(0.16))
		for z in [-hw + 0.025, hw - 0.025]:
			for xx in [x0 + w * 0.25, x1 - w * 0.25]:
				v.cyl(Vector3(xx, COUNTER_Y, z), 0.0035, 0.0035, 0.0009, Color("3a3430"), 6)
	for k in [Vector3(1.33, 0, -0.66), Vector3(1.55, 0, 0.5), Vector3(1.7, 0, -0.08)]:
		v.push_at(Vector3(k.x, COUNTER_Y, k.z), Vector3.ZERO, Vector3(1.0, 1.0, 1.8))
		v.cyl(Vector3.ZERO, 0.009, 0.009, 0.0008, WOOD.darkened(0.35), 8)
		v.cyl(Vector3.ZERO, 0.004, 0.004, 0.0011, WOOD.darkened(0.5), 6)
		v.pop()
	var m := v.mark()
	v.rbox(Vector3(COUNTER_X.y - 0.03, COUNTER_Y - 0.04, -hw), Vector3(COUNTER_X.y - 0.008, COUNTER_Y + 0.012, hw), 0.009,
		Color("c9ced6"), "z", 2)
	v.chrome(m, CHROME_TONE)
	v.rbox(Vector3(COUNTER_X.x - 0.022, COUNTER_Y - 0.035, -hw), Vector3(COUNTER_X.x, COUNTER_Y + 0.06, hw), 0.008,
		WOOD.darkened(0.2), "z", 2)
	# Ribbed rubber mat under the glass.
	v.rbox(Vector3(1.5, COUNTER_Y, 0.02), Vector3(1.74, COUNTER_Y + 0.003, 0.3), 0.018, Color("2a3a4a"), "y", 2)
	for k in 9:
		var mx := 1.515 + k * 0.026
		v.rbox(Vector3(mx, COUNTER_Y + 0.002, 0.035), Vector3(mx + 0.01, COUNTER_Y + 0.0045, 0.285), 0.002, Color("324456"), "z", 1)
	# The ingredient jars and tins.
	_sugar_tin(v, JARS.sugar)
	_ice_bucket(v, JARS.ice)
	_jar(v, JARS.tea, Color("2e1b0e"), Color("c9a24a"), 0.12)
	_tin(v, JARS.coffee, Color("4a2b1b"), Color("c9a24a"))
	_jar(v, JARS.karkade, Color("7a1428"), Color("c9a24a"), 0.11)
	_teabag_box(v, JARS.teabag)
	_mint_glass(v, JARS.mint)
	_milk_bottle(v, JARS.milk)
	_jar(v, JARS.anise, Color("8a7a4a"), Color("c9a24a"), 0.1)
	_cinnamon_jar(v, JARS.cinnamon)


## A glass jar with shoulders and a neck, the contents heaped inside, a
## paper label round the belly and a rounded screw lid.
func _jar(v: Vox, at: Vector3, fill: Color, lid: Color, h: float) -> void:
	v.push_at(at)
	v.lathe([Vector2(0.041, 0.004), Vector2(0.043, 0.012), Vector2(0.043, h * 0.72), Vector2(0.03, h * 0.77), Vector2(0.0, h * 0.79)],
		12, fill)
	v.use("glass")
	v.lathe([Vector2(0.042, 0.0), Vector2(0.047, 0.004), Vector2(0.048, 0.012), Vector2(0.048, h * 0.8), Vector2(0.045, h * 0.9),
		Vector2(0.041, h * 0.94), Vector2(0.041, h)], 12, Color(0.86, 0.94, 1.0, 0.3), false)
	v.use("solid")
	v.lathe([Vector2(0.0488, h * 0.3), Vector2(0.0488, h * 0.62)], 12, Color("f1ede4"), false, false)
	v.lathe([Vector2(0.0492, h * 0.5), Vector2(0.0492, h * 0.56)], 12, lid.darkened(0.25), false, false)
	v.use("shiny")
	v.lathe([Vector2(0.044, h - 0.004), Vector2(0.046, h), Vector2(0.046, h + 0.02), Vector2(0.043, h + 0.026), Vector2(0.034, h + 0.028),
		Vector2(0.0, h + 0.028)], 12, lid)
	v.torus(Vector3(0, h + 0.004, 0), 0.046, 0.0025, lid.lightened(0.15), 12, 6)
	v.use("solid")
	v.pop()


## A coffee tin: rolled foot bead, printed band, a push-on lid with its
## own bead.
func _tin(v: Vox, at: Vector3, col: Color, band: Color) -> void:
	v.push_at(at)
	v.lathe([Vector2(0.043, 0.0), Vector2(0.045, 0.004), Vector2(0.045, 0.112)], 12, col, false)
	v.torus(Vector3(0, 0.004, 0), 0.0448, 0.003, col.darkened(0.25), 12, 6)
	v.lathe([Vector2(0.0456, 0.045), Vector2(0.0456, 0.075)], 12, band, false, false)
	v.lathe([Vector2(0.044, 0.106), Vector2(0.047, 0.108), Vector2(0.047, 0.124), Vector2(0.045, 0.127), Vector2(0.03, 0.127),
		Vector2(0.028, 0.125), Vector2(0.0, 0.125)], 12, col.lightened(0.2))
	v.torus(Vector3(0, 0.124, 0), 0.0465, 0.0025, col.lightened(0.3), 12, 6)
	v.pop()


## Enamel sugar tin with a blue rolled rim, heaped with sugar, its domed lid
## off beside it and a spoon standing in it.
func _sugar_tin(v: Vox, at: Vector3) -> void:
	var enamel := Color("f1ede4")
	var blue := Color("2a6ab0")
	v.push_at(at)
	v.lathe([Vector2(0.05, 0.0), Vector2(0.054, 0.004), Vector2(0.056, 0.012), Vector2(0.056, 0.094)], 14, enamel, false)
	v.torus(Vector3(0, 0.096, 0), 0.0555, 0.004, blue, 14, 6)
	v.lathe([Vector2(0.0565, 0.04), Vector2(0.0565, 0.06)], 14, blue, false, false)
	v.lathe([Vector2(0.052, 0.096), Vector2(0.052, 0.07)], 14, enamel.darkened(0.1), false, false)
	v.lathe([Vector2(0.052, 0.078), Vector2(0.036, 0.086), Vector2(0.0, 0.09)], 14, Color("f7f5f0"))
	v.push_at(Vector3(0, 0, 0.1))
	v.lathe([Vector2(0.058, 0.0), Vector2(0.06, 0.003), Vector2(0.058, 0.008), Vector2(0.046, 0.014), Vector2(0.02, 0.017),
		Vector2(0.0, 0.017)], 14, enamel)
	v.torus(Vector3(0, 0.003, 0), 0.059, 0.003, blue, 14, 6)
	v.lathe([Vector2(0.012, 0.016), Vector2(0.014, 0.021), Vector2(0.01, 0.027), Vector2(0.0, 0.028)], 8, blue)
	v.pop()
	v.rod(Vector3(0.01, 0.08, 0.0), Vector3(0.05, 0.19, -0.02), 0.0035, METAL, 6)
	v.ball(Vector3(0.05, 0.19, -0.02), Vector3(0.006, 0.009, 0.005), METAL, 8, 3)
	v.pop()


## Steel ice bucket: rolled rim, ears and a wire bail laid back, rounded
## cubes heaped inside.
func _ice_bucket(v: Vox, at: Vector3) -> void:
	v.push_at(at)
	v.lathe([Vector2(0.044, 0.0), Vector2(0.046, 0.003), Vector2(0.057, 0.097)], 12, Color("c9ced6"), false)
	v.torus(Vector3(0, 0.098, 0), 0.0565, 0.0035, Color("dfe3e8"), 12, 6)
	v.lathe([Vector2(0.054, 0.098), Vector2(0.042, 0.006)], 12, Color("9aa0a8"), false, false)
	v.cyl(Vector3(0, 0.005, 0), 0.043, 0.043, 0.002, Color("8a9098"), 12)
	for sd in [-1.0, 1.0]:
		v.rbox(Vector3(-0.008, 0.075, sd * 0.054 - 0.005), Vector3(0.008, 0.092, sd * 0.054 + 0.005), 0.003, Color("b3b9c2"), "z", 1)
	var bail: Array = []
	for k in 11:
		var a := PI * k / 10.0
		bail.append(Vector3(-0.075 * sin(a), 0.085 - 0.012 * sin(a), -0.06 * cos(a)))
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.0018, 0.0018), 4), bail, Color("8a8e96"), Vector3.UP)
	v.use("glass")
	for k in 5:
		var a := TAU * k / 5.0
		v.push_at(Vector3(cos(a) * 0.025, 0.09 + (k % 2) * 0.012, sin(a) * 0.025), Vector3(k * 23.0, k * 41.0, k * 17.0))
		v.rbox(Vector3(-0.012, -0.012, -0.012), Vector3(0.012, 0.012, 0.012), 0.004, Color(0.88, 0.96, 1.0, 0.8), "x", 1)
		v.pop()
	v.use("solid")
	v.pop()


## A box of tea bags, its lid flap folded back, the bags' tags poking out.
func _teabag_box(v: Vox, at: Vector3) -> void:
	v.rbox(at + Vector3(-0.04, 0, -0.06), at + Vector3(0.04, 0.09, 0.06), 0.004, Color("f2c230"), "y", 1)
	v.box(at + Vector3(0.04, 0.02, -0.056), at + Vector3(0.0415, 0.05, 0.056), Color("c23b2a"))
	v.box(at + Vector3(-0.036, 0.06, -0.056), at + Vector3(0.036, 0.0905, 0.056), Color("5a3a1a"))
	# The torn-open top: the cardboard's edge folded in.
	v.box(at + Vector3(-0.04, 0.088, -0.06), at + Vector3(-0.034, 0.096, 0.06), Color("e8b020"))
	v.box(at + Vector3(0.034, 0.088, -0.06), at + Vector3(0.04, 0.096, 0.06), Color("e8b020"))
	for k in 4:
		var p := at + Vector3(-0.02 + k * 0.012, 0.086, -0.035 + k * 0.022)
		v.rbox(p + Vector3(-0.008, 0.0, -0.012), p + Vector3(0.008, 0.008, 0.012), 0.003, Color("efe6d0"), "z", 1)
		v.rod(p + Vector3(0, 0.008, 0), p + Vector3(0.004, 0.03, 0.004), 0.0008, Color("f4f1ea"), 3)
		v.box(p + Vector3(0.0, 0.03, -0.006), p + Vector3(0.008, 0.045, 0.006), Color("c23b2a"))


## A glass of water with a bunch of mint standing in it.
func _mint_glass(v: Vox, at: Vector3) -> void:
	v.push_at(at)
	v.lathe([Vector2(0.034, 0.008), Vector2(0.038, 0.066)], 12, Color(0.62, 0.78, 0.86))
	v.pop()
	for k in 5:
		var a := TAU * k / 5.0 + 0.3
		var top := at + Vector3(cos(a) * 0.03, 0.15 + (k % 2) * 0.03, sin(a) * 0.03)
		v.rod(at + Vector3(cos(a) * 0.01, 0.01, sin(a) * 0.01), top, 0.003, Color("5a7a2a"), 4)
		for j in 3:
			var c := at.lerp(top, 0.55 + j * 0.2) + Vector3(cos(a) * 0.012, 0, sin(a) * 0.012)
			v.ball(c, Vector3(0.016, 0.007, 0.012), Color("3f8a3a") if (k + j) % 2 else Color("4c9a44"), 6, 3)
	v.use("glass")
	v.push_at(at)
	v.lathe([Vector2(0.038, 0.0), Vector2(0.04, 0.003), Vector2(0.04, 0.01), Vector2(0.044, 0.1)], 12, Color(0.86, 0.94, 1.0, 0.3), false)
	v.cyl(Vector3.ZERO, 0.037, 0.036, 0.008, Color(0.9, 0.96, 1.0, 0.4), 12)
	v.torus(Vector3(0, 0.1, 0), 0.0435, 0.0015, Color(1, 1, 1, 0.5), 12, 6)
	v.pop()
	v.use("solid")


## A glass bottle of milk with a crimped blue cap and a label.
func _milk_bottle(v: Vox, at: Vector3) -> void:
	v.push_at(at)
	v.lathe([Vector2(0.038, 0.0), Vector2(0.043, 0.004), Vector2(0.045, 0.015), Vector2(0.045, 0.095), Vector2(0.042, 0.11),
		Vector2(0.034, 0.128), Vector2(0.026, 0.145), Vector2(0.022, 0.157), Vector2(0.022, 0.162)], 14, Color("f6f3ec"))
	v.lathe([Vector2(0.0458, 0.045), Vector2(0.0458, 0.085)], 14, Color("2f6fb3"), false, false)
	v.lathe([Vector2(0.0462, 0.06), Vector2(0.0462, 0.07)], 14, Color("f6f3ec"), false, false)
	v.lathe([Vector2(0.024, 0.156), Vector2(0.026, 0.16), Vector2(0.026, 0.178), Vector2(0.023, 0.183), Vector2(0.0, 0.184)], 12,
		Color("2f6fb3"))
	v.torus(Vector3(0, 0.161, 0), 0.026, 0.002, Color("3a7cc0"), 12, 6)
	v.pop()


## A glass jar of cinnamon sticks standing up out of it.
func _cinnamon_jar(v: Vox, at: Vector3) -> void:
	for k in 6:
		var a := TAU * k / 6.0
		var foot := at + Vector3(cos(a) * 0.018, 0.005, sin(a) * 0.018)
		var tip := foot + Vector3(cos(a) * 0.012, 0.15 + (k % 3) * 0.015, sin(a) * 0.012)
		var col := Color("9a5a2c") if k % 2 else Color("8a4e24")
		v.rod(foot, tip, 0.007, col, 8)
		v.rod(tip - (tip - foot).normalized() * 0.002, tip + (tip - foot).normalized() * 0.001, 0.0055, col.darkened(0.3), 8)
	v.use("glass")
	v.push_at(at)
	v.lathe([Vector2(0.04, 0.0), Vector2(0.045, 0.004), Vector2(0.046, 0.012), Vector2(0.046, 0.082), Vector2(0.043, 0.09)], 12,
		Color(0.86, 0.94, 1.0, 0.3), false)
	v.torus(Vector3(0, 0.09, 0), 0.043, 0.002, Color(1, 1, 1, 0.5), 12, 6)
	v.pop()
	v.use("solid")
	v.push_at(at)
	v.lathe([Vector2(0.0468, 0.028), Vector2(0.0468, 0.062)], 12, Color("f1ede4"), false, false)
	v.lathe([Vector2(0.0472, 0.05), Vector2(0.0472, 0.055)], 12, Color("8a4e24"), false, false)
	v.pop()


func _trunk(v: Vox) -> void:
	var zi := Fifi3D.HALF_W - 0.08
	var bx := Fifi3D.BULKHEAD_X
	var roof := Fifi3D.ROOF_Y
	var fy := Fifi3D.FLOOR_Y
	v.box(Vector3(bx, fy, -zi), Vector3(1.74, fy + 0.03, zi), CARPET)
	# Seat back: the frame, then stitched rolls of padding.
	v.box(Vector3(bx - 0.05, fy, -zi), Vector3(bx, roof - 0.08, zi), SEAT)
	var rolls := 6
	for k in rolls:
		var y0 := lerpf(fy + 0.02, roof - 0.12, float(k) / rolls)
		var y1 := lerpf(fy + 0.02, roof - 0.12, float(k + 1) / rolls)
		v.rbox(Vector3(bx, y0 + 0.002, -zi + 0.02), Vector3(bx + 0.04, y1 - 0.002, zi - 0.02), 0.018,
			SEAT.darkened(0.04 if k % 2 else 0.1), "z", 2)
	# Trim walls, wheel-arch humps, C-pillar trim round the opening.
	for s in [1.0, -1.0]:
		v.box(Vector3(bx, fy, s * 0.66 - 0.02), Vector3(1.72, Fifi3D.BELT_Y, s * 0.66 + 0.02), TRIM)
		v.rbox(Vector3(0.96, fy, s * 0.6 - 0.12), Vector3(1.38, fy + 0.2, s * 0.6), 0.07, TRIM.lightened(0.08), "z", 4)
		v.extrude(PackedVector2Array([Vector2(1.5, Fifi3D.SILL_Y), Vector2(1.79, Fifi3D.SILL_Y), Vector2(1.79, Fifi3D.SILL_Y + 0.12),
			Vector2(Fifi3D.HINGE.x - 0.01, roof - 0.05), Vector2(Fifi3D.HINGE.x - 0.12, roof - 0.05)]), "z",
			minf(s * 0.6, s * 0.645), maxf(s * 0.6, s * 0.645), Color("3a3440"))
		v.box(Vector3(bx, fy, s * 0.6 - 0.02), Vector3(1.5, roof - 0.06, s * 0.6 + 0.02), TRIM)
		# The rubber seal round the pillar's edge.
		v.rod(Vector3(1.79, Fifi3D.SILL_Y + 0.1, s * 0.6), Vector3(Fifi3D.HINGE.x, roof - 0.06, s * 0.6), 0.011, RUBBER, 8)
	# Headliner in three padded panels, and the roof's rounded rear edge
	# with its seal.
	v.box(Vector3(bx, roof - 0.07, -zi), Vector3(Fifi3D.HINGE.x, roof - 0.05, zi), Color("4a443e"))
	for k in 3:
		var x0 := lerpf(bx, Fifi3D.HINGE.x - 0.04, k / 3.0)
		var x1 := lerpf(bx, Fifi3D.HINGE.x - 0.04, (k + 1) / 3.0)
		v.rbox(Vector3(x0 + 0.004, roof - 0.095, -zi + 0.01), Vector3(x1 - 0.004, roof - 0.065, zi - 0.01), 0.014, Color("5a534c"), "z", 2)
	v.rbox(Vector3(Fifi3D.HINGE.x - 0.05, roof - 0.125, -zi), Vector3(Fifi3D.HINGE.x + 0.02, roof - 0.05, zi), 0.028,
		PAINT.darkened(0.3), "z", 3)
	v.rod(Vector3(Fifi3D.HINGE.x - 0.005, roof - 0.128, -zi), Vector3(Fifi3D.HINGE.x - 0.005, roof - 0.128, zi), 0.011, RUBBER, 8)


## Two work bulbs hanging from the headliner on their flex: a ceiling rose,
## a ribbed lampholder, a pear-shaped bulb.
func _bulbs(v: Vox) -> void:
	var roof := Fifi3D.ROOF_Y
	for z in [-0.38, 0.38]:
		v.push_at(Vector3(1.3, 0.0, z))
		v.lathe([Vector2(0.0, roof - 0.112), Vector2(0.012, roof - 0.111), Vector2(0.022, roof - 0.104), Vector2(0.026, roof - 0.095)],
			10, Color("e6e0d4"))
		v.pop()
		v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.004, 0.004), 6), [Vector3(1.3, roof - 0.11, z), Vector3(1.3, 1.26, z)],
			Color("1d1b20"))
		v.push_at(Vector3(1.3, 0.0, z))
		v.lathe([Vector2(0.011, 1.228), Vector2(0.0135, 1.231), Vector2(0.012, 1.235), Vector2(0.0135, 1.239), Vector2(0.012, 1.243),
			Vector2(0.0145, 1.247), Vector2(0.0145, 1.256), Vector2(0.009, 1.264), Vector2(0.004, 1.267)], 10, Color("8a8579"))
		v.use("glow/bulb")
		v.lathe([Vector2(0.0, 1.164), Vector2(0.014, 1.167), Vector2(0.024, 1.177), Vector2(0.029, 1.193), Vector2(0.027, 1.208),
			Vector2(0.018, 1.22), Vector2(0.011, 1.23)], 12, Color("fff1d6"))
		v.use("solid")
		v.pop()


## The raised hatch seen from below: painted frame with thickness, the
## glass in a round rubber seal, the pressed inner panel with its ribs and
## flanged lightening holes, the latch, the lip seal and the hinges.
func _hatch(v: Vox) -> void:
	var foot := Fifi3D.HATCH_FOOT - Fifi3D.HINGE
	var along := foot.normalized()
	# Outward when shut (to the rear and up); the inner panel is at -n.
	var n := Vector2(-along.y, along.x)
	var len := foot.length()
	var zo := Fifi3D.HALF_W - 0.06
	var th := 0.06
	# Frame round the glass: a bar by the hinge, the tailgate below the glass,
	# and the two sides, all with the panel's thickness.
	var g0 := 0.07
	var g1 := len - 0.24
	var gz := zo - 0.09
	var bar := func(t0: float, t1: float) -> PackedVector2Array:
		var a := along * t0
		var b := along * t1
		return PackedVector2Array([a, b, b - n * th, a - n * th])
	v.extrude(bar.call(0.0, g0), "z", -zo, zo, PAINT)
	v.extrude(bar.call(g1, len), "z", -zo, zo, PAINT)
	v.extrude(bar.call(g0, g1), "z", -zo, -gz, PAINT)
	v.extrude(bar.call(g0, g1), "z", gz, zo, PAINT)
	# Everything on the panel in its own frame: x up the hatch (hinge to lip),
	# y off the outer skin toward the trunk (the inner face is at th), z across.
	v.push(Transform3D(Basis(Vector3(along.x, along.y, 0), Vector3(-n.x, -n.y, 0), Vector3(0, 0, -1)), Vector3.ZERO))
	var opening := Vox.round_rect(Rect2(g0, -gz, g1 - g0, gz * 2.0), 0.045, 3)
	v.use("glass")
	for side in [[-0.006, Vector3.DOWN], [th + 0.004, Vector3.UP]]:
		var pts: Array = []
		for q in opening:
			pts.append(Vector3(q.x, side[0], q.y))
		v.poly(pts, Color(0.14, 0.2, 0.36, 0.6) if side[0] < 0.0 else Color(0.32, 0.44, 0.62, 0.42), side[1])
	v.use("solid")
	# The demister's lines printed on the glass.
	for k in range(1, 7):
		var t := lerpf(g0 + 0.03, g1 - 0.03, k / 7.0)
		v.box(Vector3(t, th + 0.005, -gz + 0.05), Vector3(t + 0.002, th + 0.0056, gz - 0.05), Color("6a4038"))
	# Round rubber seal round the glass.
	v.loop(Vox.circle(Vector2.ZERO, Vector2(0.011, 0.011), 6), Vox.rect_path(Rect2(g0, -gz, g1 - g0, gz * 2.0), 0.045, "y", th, 3),
		RUBBER, Vector3.UP)
	# Inner panel below the glass: pressed ribs and flanged oval holes.
	var pa := g1 + 0.02
	v.box(Vector3(pa, th, -zo + 0.02), Vector3(len - 0.02, th + 0.003, zo - 0.02), PAINT.darkened(0.12))
	for t in [pa + 0.025, len - 0.055]:
		v.rbox(Vector3(t, th, -zo + 0.045), Vector3(t + 0.022, th + 0.013, zo - 0.045), 0.008, PAINT.darkened(0.02), "z", 2)
	for zz in [-0.42, -0.21, 0.21, 0.42]:
		var c := Vector3(pa + 0.105, th + 0.003, zz)
		var rim: Array = []
		for k in 18:
			var a := TAU * k / 18.0
			rim.append(c + Vector3(sin(a) * 0.04, 0.003, cos(a) * 0.066))
		v.loop(Vox.circle(Vector2.ZERO, Vector2(0.0055, 0.0055), 5), rim, PAINT.darkened(0.06), Vector3.UP)
		v.push_at(c + Vector3(0, 0.0006, 0), Vector3.ZERO, Vector3(0.036, 1.0, 0.062))
		v.cyl(Vector3.ZERO, 1.0, 1.0, 0.0004, PAINT.darkened(0.5), 12)
		v.pop()
		v.push_at(c + Vector3(-0.006, 0.0012, 0), Vector3.ZERO, Vector3(0.028, 1.0, 0.052))
		v.cyl(Vector3.ZERO, 1.0, 1.0, 0.0004, PAINT.darkened(0.68), 12)
		v.pop()
	# Latch in the middle of the lip: the housing, the chrome striker, the
	# lock barrel.
	v.rbox(Vector3(len - 0.105, th, -0.07), Vector3(len - 0.02, th + 0.02, 0.07), 0.008, Color("2c2a30"), "z", 2)
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.004, 0.004), 5), Vox.smooth_path([Vector3(len - 0.03, th + 0.018, -0.022),
		Vector3(len - 0.05, th + 0.03, -0.018), Vector3(len - 0.055, th + 0.032, 0.0), Vector3(len - 0.05, th + 0.03, 0.018),
		Vector3(len - 0.03, th + 0.018, 0.022)], 2), CHROME.darkened(0.15), Vector3.UP)
	v.push_at(Vector3(len - 0.088, th + 0.02, 0.0))
	v.lathe([Vector2(0.011, 0.0), Vector2(0.011, 0.004), Vector2(0.009, 0.007), Vector2(0.0, 0.007)], 10, CHROME)
	v.pop()
	v.box(Vector3(len - 0.093, th + 0.0272, -0.0015), Vector3(len - 0.083, th + 0.0278, 0.0015), Color("1a1a1e"))
	v.pop()
	# Seal round the lip, and the hinges with their pins.
	v.rod(Vector3(foot.x - 0.006, foot.y - 0.004, -zo), Vector3(foot.x - 0.006, foot.y - 0.004, zo), 0.014, RUBBER, 8)
	for z in [-0.45, 0.45]:
		v.rbox(Vector3(-0.04, -0.03, z - 0.04), Vector3(0.04, 0.02, z + 0.04), 0.01, Color("2c2a30"), "z", 2)
		v.rod(Vector3(0.0, -0.005, z - 0.046), Vector3(0.0, -0.005, z + 0.046), 0.009, Color("8a8e96"), 8)


## The gas struts from the pillars up to the hatch (their ends move with
## the hatch, so they're built in car space): a black body, a chrome rod,
## ball joints at both ends.
func _struts(v: Vox, hatch: Node3D) -> void:
	var xf := hatch.transform
	var sill := Fifi3D.SILL_Y
	var foot := Fifi3D.HATCH_FOOT - Fifi3D.HINGE
	var n := Vector2(-foot.normalized().y, foot.normalized().x)
	var zo := Fifi3D.HALF_W - 0.1
	for z in [-zo + 0.03, zo - 0.03]:
		var low := Vector3(1.7, sill + 0.28, z)
		var high: Vector3 = xf * Vector3(foot.x * 0.42 - n.x * 0.06, foot.y * 0.42 - n.y * 0.06, z)
		var mid := low.lerp(high, 0.55)
		var dir := (high - low).normalized()
		v.rod(low + dir * 0.02, mid, 0.016, Color("2a2a30"), 10)
		v.push(Transform3D(Vox._basis_up(dir), mid))
		v.lathe([Vector2(0.016, 0.0), Vector2(0.013, 0.008), Vector2(0.009, 0.012)], 10, Color("2a2a30"), false, false)
		v.pop()
		v.use("shiny")
		v.rod(mid + dir * 0.01, high - dir * 0.015, 0.0075, CHROME, 10)
		v.use("solid")
		for e in [low, high]:
			v.ball(e, Vector3(0.016, 0.016, 0.016), Color("2a2a30"), 10, 4)
		v.rbox(low + Vector3(-0.02, -0.02, -0.012), low + Vector3(0.02, 0.02, 0.012), 0.006, Color("2a2a30"), "z", 1)

#endregion


#region Racks

## Sayed's rail of spare كنكة in three sizes and the ladle, on S-hooks. Local space: the rail's middle at the origin on
## the seat back, hanging toward +x.
func _rack_hooks(v: Vox) -> void:
	var half := 0.21
	_rail(v, -half, half)
	var items := [[-0.15, 1.0], [-0.03, 0.8], [0.07, 0.62]]
	for it in items:
		var z: float = it[0]
		var s: float = it[1]
		_s_hook(v, z)
		_kanaka_hanging(v, Vector3(0.05, -0.05, z), s)
	_s_hook(v, 0.15)
	v.rod(Vector3(0.035, -0.045, 0.15), Vector3(0.035, -0.2, 0.15), 0.004, METAL, 6)
	v.push_at(Vector3(0.05, -0.23, 0.15), Vector3(0, 0, -90))
	v.lathe([Vector2(0.0, -0.012), Vector2(0.018, -0.009), Vector2(0.028, -0.003), Vector2(0.032, 0.006), Vector2(0.033, 0.016)],
		10, METAL, false)
	v.lathe([Vector2(0.03, 0.016), Vector2(0.029, 0.006), Vector2(0.025, -0.001), Vector2(0.016, -0.006), Vector2(0.0, -0.009)],
		10, METAL_DARK, false, false)
	v.torus(Vector3(0, 0.016, 0), 0.0315, 0.0018, METAL, 10, 6)
	v.pop()


## A chrome rail between two rounded wall brackets, with end knobs.
func _rail(v: Vox, z0: float, z1: float) -> void:
	v.rod(Vector3(0.03, 0, z0 - 0.01), Vector3(0.03, 0, z1 + 0.01), 0.006, CHROME, 8)
	for z in [z0, z1]:
		v.rbox(Vector3(0.0, -0.015, z - 0.012), Vector3(0.035, 0.012, z + 0.012), 0.006, Color("2c2a30"), "z", 2)
	for z in [z0 - 0.012, z1 + 0.012]:
		v.ball(Vector3(0.03, 0, z), Vector3(0.009, 0.009, 0.009), CHROME, 8, 3)


## An S-hook over the rail: a smooth wire curve.
func _s_hook(v: Vox, z: float) -> void:
	var pts := [Vector3(0.018, 0.004, z), Vector3(0.03, 0.011, z), Vector3(0.045, 0.006, z), Vector3(0.048, -0.008, z),
		Vector3(0.036, -0.022, z), Vector3(0.03, -0.036, z), Vector3(0.038, -0.05, z), Vector3(0.05, -0.048, z)]
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.0028, 0.0028), 4), Vox.smooth_path(pts, 3), Color("8a8e96"), Vector3.BACK)


## A كنكة hanging by its handle: belly, pinched neck, flared lip with a
## rolled rim, the inside showing, a riveted handle.
func _kanaka_hanging(v: Vox, at: Vector3, s: float) -> void:
	v.rod(at, at + Vector3(0.0, -0.12 * s, 0.0), 0.008 * s, GRIP, 8)
	v.ball(at, Vector3(0.009, 0.009, 0.009) * s, GRIP, 8, 3)
	v.push_at(at + Vector3(0.05 * s, -0.16 * s, 0), Vector3(0, 0, -90))
	var prof := [Vector2(0.042 * s, -0.05 * s), Vector2(0.048 * s, -0.045 * s), Vector2(0.051 * s, -0.025 * s),
		Vector2(0.049 * s, -0.005 * s), Vector2(0.04 * s, 0.025 * s), Vector2(0.039 * s, 0.035 * s), Vector2(0.046 * s, 0.05 * s)]
	v.lathe(prof, 12, METAL, false)
	var inner: Array = []
	for i in range(prof.size() - 1, -1, -1):
		var p: Vector2 = prof[i]
		inner.append(Vector2(p.x - 0.003, maxf(p.y, -0.047 * s)))
	v.lathe(inner, 12, METAL_DARK.darkened(0.2), true, false)
	v.torus(Vector3(0, 0.05 * s, 0), 0.0445 * s, 0.002, METAL.lightened(0.1), 12, 6)
	v.pop()
	v.rbox(at + Vector3(-0.006, -0.125 * s, -0.008 * s), at + Vector3(0.012, -0.105 * s, 0.008 * s), 0.003, METAL_DARK, "z", 1)


## The chalk menu board: a moulded wooden frame with rounded edges and
## corner screws, the dark green board, today's drinks and prices in chalk
## (Label3D), a chalk stub on the ledge.
func _rack_board(v: Vox, node: Node3D) -> void:
	var w := 0.36
	var h := 0.26
	var fw := 0.02
	var frame := Color("8a5a32")
	v.box(Vector3(-0.015, -h * 0.5, -w * 0.5), Vector3(-0.004, h * 0.5, w * 0.5), frame.darkened(0.2))
	v.box(Vector3(-0.004, -h * 0.5 + fw, -w * 0.5 + fw), Vector3(0.002, h * 0.5 - fw, w * 0.5 - fw), BOARD)
	for sy in [-1.0, 1.0]:
		v.rbox(Vector3(-0.012, sy * (h * 0.5 - fw * 0.5) - fw * 0.5, -w * 0.5), Vector3(0.007, sy * (h * 0.5 - fw * 0.5) + fw * 0.5, w * 0.5),
			0.006, frame, "z", 2)
	for sz in [-1.0, 1.0]:
		v.rbox(Vector3(-0.012, -h * 0.5 + fw, sz * (w * 0.5 - fw * 0.5) - fw * 0.5), Vector3(0.007, h * 0.5 - fw, sz * (w * 0.5 - fw * 0.5) + fw * 0.5),
			0.006, frame.darkened(0.06), "y", 2)
	# The ledge and the chalk on it.
	v.rbox(Vector3(0.0, -h * 0.5 - 0.006, -w * 0.5 + 0.01), Vector3(0.028, -h * 0.5 + 0.008, w * 0.5 - 0.01), 0.005, frame.lightened(0.05),
		"z", 2)
	v.rod(Vector3(0.014, -h * 0.5 + 0.0135, 0.08), Vector3(0.014, -h * 0.5 + 0.0135, 0.12), 0.005, Color(0.95, 0.94, 0.88), 8)
	for c in [Vector3(0.007, h * 0.5 - fw * 0.5, -w * 0.5 + fw * 0.5), Vector3(0.007, h * 0.5 - fw * 0.5, w * 0.5 - fw * 0.5),
			Vector3(0.007, -h * 0.5 + fw * 0.5, -w * 0.5 + fw * 0.5), Vector3(0.007, -h * 0.5 + fw * 0.5, w * 0.5 - fw * 0.5)]:
		v.push_at(c, Vector3(0, 0, -90))
		v.lathe([Vector2(0.0045, 0.0), Vector2(0.004, 0.0015), Vector2(0.0025, 0.0027), Vector2(0.0, 0.003)], 6, Color("c9ced6"))
		v.pop()
	var font: Font = preload("res://assets/ui/main_theme.tres").default_font
	var lines := PackedStringArray([tr("UI_MENU_BOARD")])
	for row in _menu_lines():
		lines.append("%s  %s" % [row[0], row[1]])
	var label := Label3D.new()
	label.text = "\n".join(lines)
	label.font = font
	label.font_size = 32
	label.pixel_size = 0.00068
	label.outline_size = 0
	label.line_spacing = -8
	label.modulate = Color(0.95, 0.94, 0.88)
	label.position = Vector3(0.006, 0.0, 0.0)
	label.rotation_degrees.y = 90
	label.shaded = false
	node.add_child(label)


## Today's orderable drinks, [name, "٨ ج"], cheapest first.
func _menu_lines() -> Array:
	var rows := []
	for id in GameData.menu_items:
		var item: Dictionary = GameData.menu_items[id]
		if int(item.get("unlock_tier", 0)) > Economy.current_venue_tier or not Economy.owns_slot(item.get("station", "")):
			continue
		var price := roundi(GameData.price_for(id, Economy.current_venue_tier))
		rows.append([tr(item.get("name_key", id)), "%s ج" % GameData.ar_digits(price), price])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return a[2] < b[2])
	return rows.slice(0, 6)


## Each rack at its saved spot, or its default. Spots saved for racks this
## build doesn't have (a rack parked for a later phase) are left alone, and
## anything malformed falls back to the default.
func _load_racks() -> void:
	var saved = Economy.data.settings.get("rack_spots", {})
	if not saved is Dictionary:
		saved = {}
	for id in RACKS:
		var at: Vector2 = RACKS[id]
		var spot = saved.get(id)
		if spot is Array and spot.size() >= 2 and _is_number(spot[0]) and _is_number(spot[1]):
			at = Vector2(float(spot[0]), float(spot[1]))
		_place_rack(id, at)


static func _is_number(x: Variant) -> bool:
	return x is float or x is int


## The hatch's inner face: a point `t` (0 hinge .. 1 lip) up it and `z`
## across, stood off it by `off` (car space).
func _on_hatch(t: float, z: float, off := 0.012) -> Vector3:
	var foot := Fifi3D.HATCH_FOOT - Fifi3D.HINGE
	var along := foot.normalized()
	var n := Vector2(-along.y, along.x)
	var q := along * foot.length() * t - n * (0.06 + off)
	return _hatch_node.transform * Vector3(q.x, q.y, z)


## Flat on the hatch's inner panel, facing the view, top toward the lip.
func _hatch_basis() -> Basis:
	var foot := Fifi3D.HATCH_FOOT - Fifi3D.HINGE
	var along := foot.normalized()
	var n := Vector2(-along.y, along.x)
	var x := _hatch_node.transform.basis * Vector3(-n.x, -n.y, 0)
	var y := _hatch_node.transform.basis * Vector3(along.x, along.y, 0)
	return Basis(x, y, x.cross(y))


func _place_rack(id: String, at: Vector2) -> void:
	var r: Node3D = racks[id]
	if id == "board":
		var spot := Vector2(clampf(at.x, RACK_T.x, RACK_T.y), clampf(at.y, -0.4, 0.4))
		rack_spots[id] = spot
		r.transform = Transform3D(_hatch_basis(), _on_hatch(spot.x, spot.y))
	else:
		var z := clampf(at.y, RAIL_Z.x, RAIL_Z.y)
		rack_spots[id] = Vector2(0.0, z)
		r.position = Vector3(RAIL.x, RAIL.y, z)


## Arrange mode: the rack under the finger.
func rack_at(screen: Vector2) -> String:
	var best := ""
	var best_d := INF
	for id in racks:
		var r: Node3D = racks[id]
		var box := AABB(r.global_position + Vector3(-0.05, -0.26, -0.18), Vector3(0.15, 0.3, 0.36))
		if id == "board":
			box = AABB(r.global_position + Vector3(-0.1, -0.12, -0.2), Vector3(0.2, 0.24, 0.4))
		var rect := screen_rect_of(box)
		if rect.grow(20).has_point(screen):
			var d := rect.get_center().distance_to(screen)
			if d < best_d:
				best_d = d
				best = id
	return best


## Slides the rails' racks across the opening, the board over the hatch.
func drag_rack(id: String, screen: Vector2) -> void:
	var from := camera.project_ray_origin(screen)
	var dir := camera.project_ray_normal(screen)
	if id == "board":
		var a := global_transform * _on_hatch(0.0, 0.0, 0.0)
		var b := global_transform * _on_hatch(1.0, 0.0, 0.0)
		var c := global_transform * _on_hatch(0.0, 1.0, 0.0)
		var hit: Variant = Plane(a, b, c).intersects_ray(from, dir)
		if hit == null:
			return
		var p: Vector3 = hit
		_place_rack(id, Vector2((p - a).dot((b - a).normalized()) / a.distance_to(b), (p - a).dot((c - a).normalized())))
		return
	var plane := Plane(global_transform.basis.x.normalized(), global_transform * Vector3(RAIL.x, 0, 0))
	var h: Variant = plane.intersects_ray(from, dir)
	if h == null:
		return
	var local: Vector3 = global_transform.affine_inverse() * (h as Vector3)
	_place_rack(id, Vector2(0.0, local.z))


## Writes the racks' spots into the save, keeping any saved for racks this
## build doesn't have so they're still there when that rack comes back.
func save_racks() -> void:
	var old = Economy.data.settings.get("rack_spots", {})
	var out: Dictionary = old.duplicate() if old is Dictionary else {}
	for id in rack_spots:
		var s: Vector2 = rack_spots[id]
		out[id] = [s.x, s.y]
	Economy.data.settings["rack_spots"] = out
	Economy.save()

#endregion
