class_name PrepRig
extends Node3D
## FIFI's tail and trunk up close, where the drinks are made. Mounted on
## FIFI (her local space: the tail at +x, her left side at +z) and shown
## only while Sayed works, it stands in for the plainer street version:
## lamp clusters with chrome bezels and ribbed lenses, the plate, a rounded
## chrome bumper with its rubber strip, stickers, and the raised hatch seen
## from below (pressed inner panel, seal, latch, struts, fairy lights).
## Inside: a wooden counter across the sill for the stove, the glass, the
## blender and the jars; storage on the floor behind; a shelf on the seat
## back; and Sayed's movable racks (the rail of كنكة, the lemon squeezer,
## the chalk menu board), hanging bulbs, LED strips, fringe and charms.
## The camera stands behind the car at hatch height looking down in.

const PAINT := Color("e9b42c")
const CHROME := Color("d4d9e1")
const RUBBER := Color("1b1b21")
const TRIM := Color("4a434d")
const CARPET := Color("463e46")
const SEAT := Color("6b4a3c")
const WOOD := Color("9a6a3e")
const METAL := Color("b3b9c2")
const METAL_DARK := Color("6f7682")
const GRIP := Color("5a3620")
const SQUEEZER := Color("f2c230")
const TOWEL := Color("efe9dc")
const BOARD := Color("22302a")

const REAR_X := 1.8
const COUNTER_Y := 0.72
const COUNTER_X := Vector2(1.26, 1.8)
## Where the kit stands on the counter.
const GLASS_AT := Vector3(1.6, COUNTER_Y, 0.14)
const STOVE_AT := Vector3(1.5, COUNTER_Y, -0.24)
const BLENDER_AT := Vector3(1.4, COUNTER_Y, -0.58)
## The jars along the counter's back and left: where each ingredient's
## spoonful comes from.
const JARS := {
	"sugar": Vector3(1.62, COUNTER_Y, 0.6),
	"ice": Vector3(1.64, COUNTER_Y, 0.42),
	"tea": Vector3(1.38, COUNTER_Y, 0.64),
	"coffee": Vector3(1.38, COUNTER_Y, 0.5),
	"karkade": Vector3(1.38, COUNTER_Y, 0.36),
	"teabag": Vector3(1.4, COUNTER_Y, 0.2),
	"mango": Vector3(1.36, COUNTER_Y, -0.3),
}
## The rail racks hang under the roof's rear edge, across the top of the
## opening (each at an x across); the chalk board is fixed flat on the
## hatch's inner panel (how far up it 0..1, across).
const RAIL := Vector2(1.36, Fifi3D.ROOF_Y - 0.1)
const RAIL_Z := Vector2(-0.44, 0.44)
const RACK_T := Vector2(0.3, 0.7)
const RACKS := {"hooks": Vector2(0.0, 0.3), "lemon": Vector2(0.0, -0.14), "board": Vector2(0.5, 0.0)}
## Camera: behind the tail at hatch height, looking down into the trunk.
const CAM_AT := Vector3(2.72, 2.12, 0.0)
const CAM_LOOK := Vector3(1.42, 0.95, 0.0)
## Horizontal field of view the car is framed to (degrees), and the design
## aspect it holds on wider screens.
const H_FOV := 43.0
const DESIGN_ASPECT := 0.75
const LED_COLORS := Fifi3D.LED_COLORS

var camera := Camera3D.new()
var racks := {}
## Racks' spots on the hatch: id -> Vector2(t, z).
var rack_spots := {}
var _hatch_node: Node3D
var arranging := false

var _t := 0.0
var _fan: Node3D
var _cam_home := Transform3D.IDENTITY
var _shake := 0.0
var _shake_t := 0.0


func _ready() -> void:
	var v := Vox.new()
	_rear(v)
	_counter(v)
	_trunk(v)
	_shelf(v)
	_floor_storage(v)
	_decor(v)
	v.into(self, "Rig")
	var hatch := Node3D.new()
	_hatch_node = hatch
	hatch.position = Vector3(Fifi3D.HINGE.x, Fifi3D.HINGE.y, 0)
	hatch.rotation_degrees.z = Fifi3D.HATCH_OPEN_DEG
	add_child(hatch)
	_hatch(v)
	v.into(hatch, "Hatch")
	_hatch_lights(v, hatch)
	v.into(self, "Lights")
	_fan = Node3D.new()
	_fan.position = Vector3(1.05, 1.18, -0.66)
	_fan.rotation_degrees.y = 30
	add_child(_fan)
	_build_fan(v)
	for id in RACKS:
		var r := Node3D.new()
		r.name = "Rack_" + id
		add_child(r)
		match id:
			"hooks":
				_rack_hooks(v)
			"lemon":
				_rack_lemon(v)
			"board":
				_rack_board(v, r)
		v.into(r, "Mesh")
		racks[id] = r
	_load_racks()
	_labels()
	for z in [-0.38, 0.38]:
		var bulb := OmniLight3D.new()
		bulb.position = Vector3(1.3, 1.22, z)
		bulb.light_color = Color("ffd9a0")
		bulb.light_energy = 0.45
		bulb.omni_range = 2.2
		bulb.omni_attenuation = 1.4
		add_child(bulb)
	camera.position = CAM_AT
	add_child(camera)
	camera.transform = Transform3D(Basis.looking_at(CAM_LOOK - CAM_AT, Vector3.UP), CAM_AT)
	_cam_home = camera.transform
	camera.near = 0.05
	camera.far = 120.0
	get_viewport().size_changed.connect(_fit_camera)
	_fit_camera()


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
	_fan.get_child(0).rotation.z += delta * 14.0
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
	# Lamp clusters: thick chrome bezels, ribbed red lenses, amber outboard,
	# white reversing lamp inboard.
	for s in [1.0, -1.0]:
		var z0: float = s * 0.44
		var z1: float = s * 0.77
		var lo := minf(z0, z1)
		var hi := maxf(z0, z1)
		v.rbox(Vector3(x - 0.01, 0.43, lo - 0.015), Vector3(x + 0.035, 0.62, hi + 0.015), 0.012, CHROME, "x", 1)
		v.use("glow/tail")
		v.box(Vector3(x + 0.035, 0.45, lo + 0.075), Vector3(x + 0.05, 0.6, hi - 0.075), Color("c3372c"))
		v.use("solid")
		for k in 5:
			var y := 0.46 + k * 0.028
			v.box(Vector3(x + 0.05, y, lo + 0.08), Vector3(x + 0.053, y + 0.008, hi - 0.08), Color("e0584a"))
		var amber_lo: float = z1 - s * 0.07
		v.box(Vector3(x + 0.035, 0.45, minf(amber_lo, z1 - s * 0.005)), Vector3(x + 0.052, 0.6, maxf(amber_lo, z1 - s * 0.005)),
			Color("e8962e"))
		var white_hi: float = z0 + s * 0.07
		v.box(Vector3(x + 0.035, 0.45, minf(z0 + s * 0.005, white_hi)), Vector3(x + 0.052, 0.6, maxf(z0 + s * 0.005, white_hi)),
			Color("f1ede4"))
		for zz in [amber_lo, white_hi]:
			v.box(Vector3(x + 0.035, 0.44, zz - 0.004), Vector3(x + 0.056, 0.61, zz + 0.004), CHROME)
	# Plate in a rubber frame with its screws and the blue مصر band.
	# (It sits clear of the bumper's top so the whole number reads.)
	v.box(Vector3(x - 0.005, 0.285, -0.27), Vector3(x + 0.03, 0.455, 0.27), RUBBER)
	v.box(Vector3(x + 0.03, 0.295, -0.255), Vector3(x + 0.036, 0.445, 0.255), Color("ece8dc"))
	v.box(Vector3(x + 0.036, 0.41, -0.255), Vector3(x + 0.038, 0.445, 0.255), Color("4b87c6"))
	for z in [-0.22, 0.22]:
		v.cyl(Vector3(x + 0.036, 0.43, z), 0.008, 0.008, 0.004, CHROME, 6)
	# The load sill: painted lip, rubber seal, chrome strip.
	v.box(Vector3(1.66, Fifi3D.SILL_Y - 0.02, -hw + 0.05), Vector3(x + 0.02, Fifi3D.SILL_Y + 0.02, hw - 0.05), PAINT.darkened(0.08))
	v.rbox(Vector3(x - 0.01, Fifi3D.SILL_Y - 0.03, -hw + 0.07), Vector3(x + 0.03, Fifi3D.SILL_Y + 0.025, hw - 0.07), 0.012,
		CHROME, "z", 2)
	v.box(Vector3(1.74, Fifi3D.SILL_Y + 0.02, -hw + 0.08), Vector3(1.8, Fifi3D.SILL_Y + 0.035, hw - 0.08), RUBBER)
	# Round-edged chrome bumper wrapping the corners, its rubber strip and
	# rounded overriders, the brackets under it.
	var sec := Vox.round_rect(Rect2(-0.065, -0.07, 0.13, 0.14), 0.055, 3)
	var path := [Vector3(x - 0.3, 0.22, -hw - 0.04), Vector3(x - 0.06, 0.22, -hw - 0.02), Vector3(x + 0.03, 0.22, -hw + 0.12),
		Vector3(x + 0.05, 0.22, -hw + 0.3), Vector3(x + 0.05, 0.22, hw - 0.3), Vector3(x + 0.03, 0.22, hw - 0.12),
		Vector3(x - 0.06, 0.22, hw + 0.02), Vector3(x - 0.3, 0.22, hw + 0.04)]
	v.sweep(sec, path, CHROME, Vector3.UP)
	v.rbox(Vector3(x + 0.1, 0.205, -hw + 0.28), Vector3(x + 0.125, 0.235, hw - 0.28), 0.01, RUBBER, "z", 1)
	v.box(Vector3(x + 0.108, 0.262, -hw + 0.3), Vector3(x + 0.112, 0.268, hw - 0.3), Color("f7f9fb"))
	for z in [-0.42, 0.42]:
		v.rbox(Vector3(x + 0.05, 0.14, z - 0.035), Vector3(x + 0.13, 0.31, z + 0.035), 0.03, RUBBER, "y", 2)
		v.box(Vector3(x - 0.05, 0.14, z - 0.03), Vector3(x + 0.02, 0.18, z + 0.03), Color("2a2a30"))
	# Tow eye and the exhaust's tip.
	v.rod(Vector3(x, 0.12, 0.3), Vector3(x + 0.08, 0.12, 0.3), 0.015, Color("3a3a40"), 6)
	v.push_at(Vector3(x - 0.02, 0.13, -0.45), Vector3(0, 0, 90))
	v.cyl(Vector3.ZERO, 0.035, 0.035, 0.12, Color("5a5a60"), 8)
	v.cyl(Vector3(0, 0.1, 0), 0.028, 0.028, 0.025, Color("1a1a1a"), 8)
	v.pop()
	# Stickers: a white oval, the FIFI script, a little flag.
	v.push_at(Vector3(x + 0.004, 0.52, 0.0), Vector3(0, 90, 0))
	v.extrude(Vox.circle(Vector2.ZERO, Vector2(0.12, 0.045), 16), "z", 0.0, 0.004, Color("f4f1ea"))
	v.pop()
	for k in 3:
		var c: Color = [Color("c8322b"), Color("f4f1ea"), Color("1c1c24")][k]
		v.box(Vector3(x, 0.64 - k * 0.016, -0.36), Vector3(x + 0.004, 0.656 - k * 0.016, -0.28), c)
	v.box(Vector3(x + 0.004, 0.622, -0.325), Vector3(x + 0.006, 0.634, -0.315), Color("c9a24a"))
	for k in 4:
		v.box(Vector3(x, 0.63, 0.24 + k * 0.035), Vector3(x + 0.008, 0.65, 0.265 + k * 0.035), CHROME)


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
	var sticker := Label3D.new()
	sticker.text = "صلّي على النبي"
	sticker.font = font
	sticker.font_size = 40
	sticker.pixel_size = 0.0013
	sticker.outline_size = 0
	sticker.modulate = Color("2a6a3a")
	sticker.position = Vector3(REAR_X + 0.009, 0.52, 0.0)
	sticker.rotation_degrees.y = 90
	add_child(sticker)

#endregion


#region Inside

## A wooden board across the trunk at sill height: everything is made on it.
func _counter(v: Vox) -> void:
	var hw := Fifi3D.HALF_W - 0.1
	v.box(Vector3(COUNTER_X.x, COUNTER_Y - 0.035, -hw), Vector3(COUNTER_X.y - 0.02, COUNTER_Y, hw), WOOD)
	for k in 5:
		var x := lerpf(COUNTER_X.x + 0.05, COUNTER_X.y - 0.06, k / 4.0)
		v.box(Vector3(x - 0.002, COUNTER_Y, -hw), Vector3(x + 0.002, COUNTER_Y + 0.001, hw), WOOD.darkened(0.15))
	v.box(Vector3(COUNTER_X.y - 0.03, COUNTER_Y - 0.04, -hw), Vector3(COUNTER_X.y - 0.01, COUNTER_Y + 0.012, hw), Color("c9ced6"))
	v.box(Vector3(COUNTER_X.x - 0.02, COUNTER_Y - 0.035, -hw), Vector3(COUNTER_X.x, COUNTER_Y + 0.06, hw), WOOD.darkened(0.2))
	# Rubber mat under the glass and the stove, a rag, a spoon or two.
	v.box(Vector3(1.5, COUNTER_Y, 0.02), Vector3(1.74, COUNTER_Y + 0.004, 0.3), Color("2a3a4a"))
	for k in 5:
		v.box(Vector3(1.5, COUNTER_Y + 0.004, 0.04 + k * 0.055), Vector3(1.74, COUNTER_Y + 0.006, 0.05 + k * 0.055), Color("35485a"))
	v.box(Vector3(1.68, COUNTER_Y, -0.52), Vector3(1.77, COUNTER_Y + 0.012, -0.36), TOWEL)
	for k in 3:
		v.box(Vector3(1.68, COUNTER_Y + 0.012, -0.5 + k * 0.05), Vector3(1.77, COUNTER_Y + 0.014, -0.49 + k * 0.05), Color("c23b2a"))
	v.rod(Vector3(1.72, COUNTER_Y + 0.006, -0.02), Vector3(1.66, COUNTER_Y + 0.006, -0.12), 0.004, METAL, 4)
	v.ball(Vector3(1.735, COUNTER_Y + 0.008, 0.0), Vector3(0.012, 0.005, 0.009), METAL, 6, 2)
	# The ingredient jars and tins.
	_sugar_tin(v, JARS.sugar)
	_ice_bucket(v, JARS.ice)
	_jar(v, JARS.tea, Color("2e1b0e"), Color("c9a24a"), 0.12)
	_tin(v, JARS.coffee, Color("4a2b1b"), Color("c9a24a"))
	_jar(v, JARS.karkade, Color("7a1428"), Color("c9a24a"), 0.11)
	_teabag_box(v, JARS.teabag)


func _jar(v: Vox, at: Vector3, fill: Color, lid: Color, h: float) -> void:
	v.cyl(at + Vector3(0, 0.003, 0), 0.042, 0.042, h * 0.8, fill, 10)
	v.use("glass")
	v.cyl(at, 0.048, 0.048, h, Color(0.86, 0.94, 1.0, 0.3), 10)
	v.use("solid")
	v.cyl(at + Vector3(0, h, 0), 0.05, 0.05, 0.025, lid, 10)
	v.cyl(at + Vector3(0, h + 0.025, 0), 0.03, 0.03, 0.006, lid.lightened(0.25), 10)
	v.box(at + Vector3(0.046, h * 0.35, -0.028), at + Vector3(0.05, h * 0.65, 0.028), Color("f1ede4"))


func _tin(v: Vox, at: Vector3, col: Color, band: Color) -> void:
	v.cyl(at, 0.045, 0.045, 0.12, col, 10)
	v.cyl(at + Vector3(0, 0.05, 0), 0.046, 0.046, 0.025, band, 10)
	v.cyl(at + Vector3(0, 0.12, 0), 0.047, 0.047, 0.015, col.lightened(0.2), 10)


## Enamel sugar tin, lid off beside it, a spoon standing in the sugar.
func _sugar_tin(v: Vox, at: Vector3) -> void:
	v.cyl(at, 0.055, 0.055, 0.1, Color("f1ede4"), 12)
	v.cyl(at + Vector3(0, 0.04, 0), 0.056, 0.056, 0.02, Color("2a6ab0"), 12)
	v.cyl(at + Vector3(0, 0.097, 0), 0.05, 0.05, 0.004, Color("f7f5f0"), 12)
	v.cyl(at + Vector3(0.0, 0.0, 0.1), 0.058, 0.058, 0.012, Color("f1ede4"), 12)
	v.cyl(at + Vector3(0.0, 0.012, 0.1), 0.02, 0.02, 0.01, Color("2a6ab0"), 8)
	v.rod(at + Vector3(0.01, 0.08, 0.0), at + Vector3(0.05, 0.19, -0.02), 0.004, METAL, 4)


func _ice_bucket(v: Vox, at: Vector3) -> void:
	var p := at
	v.push_at(p)
	v.lathe([Vector2(0.045, 0.0), Vector2(0.058, 0.1)], 12, Color("c9ced6"), false)
	v.lathe([Vector2(0.056, 0.1), Vector2(0.043, 0.004)], 12, Color("9aa0a8"), false, false)
	v.use("glass")
	for k in 5:
		var a := TAU * k / 5.0
		v.cube(Vector3(cos(a) * 0.025, 0.09 + (k % 2) * 0.012, sin(a) * 0.025), Vector3(0.024, 0.024, 0.024),
			Color(0.88, 0.96, 1.0, 0.8))
	v.use("solid")
	v.pop()


func _teabag_box(v: Vox, at: Vector3) -> void:
	v.box(at + Vector3(-0.04, 0, -0.06), at + Vector3(0.04, 0.09, 0.06), Color("f2c230"))
	v.box(at + Vector3(0.04, 0.02, -0.06), at + Vector3(0.042, 0.05, 0.06), Color("c23b2a"))
	v.box(at + Vector3(-0.035, 0.09, -0.055), at + Vector3(0.035, 0.1, 0.055), Color("e8b020"))
	# Tags of the bags sticking out of the open top.
	for k in 3:
		v.box(at + Vector3(-0.01 + k * 0.01, 0.1, -0.03 + k * 0.025), at + Vector3(k * 0.01, 0.13, -0.015 + k * 0.025), Color("c23b2a"))


func _trunk(v: Vox) -> void:
	var zi := Fifi3D.HALF_W - 0.08
	var bx := Fifi3D.BULKHEAD_X
	var roof := Fifi3D.ROOF_Y
	var fy := Fifi3D.FLOOR_Y
	v.box(Vector3(bx, fy, -zi), Vector3(1.74, fy + 0.03, zi), CARPET)
	# Seat back, upholstered in panels with piping.
	v.box(Vector3(bx - 0.05, fy, -zi), Vector3(bx, roof - 0.08, zi), SEAT)
	v.box(Vector3(bx, fy + 0.02, -zi), Vector3(bx + 0.035, roof - 0.12, zi), SEAT.darkened(0.08))
	for k in 7:
		var z := -zi + 0.1 + k * 0.205
		v.box(Vector3(bx + 0.035, 0.52, z - 0.005), Vector3(bx + 0.04, roof - 0.14, z + 0.005), SEAT.darkened(0.3))
	for y in [0.62, 0.86, 1.1]:
		v.box(Vector3(bx + 0.035, y, -zi), Vector3(bx + 0.04, y + 0.008, zi), SEAT.darkened(0.25))
	# Trim walls, wheel-arch humps, C-pillar trim round the opening.
	for s in [1.0, -1.0]:
		v.box(Vector3(bx, fy, s * 0.66 - 0.02), Vector3(1.72, Fifi3D.BELT_Y, s * 0.66 + 0.02), TRIM)
		v.rbox(Vector3(0.96, fy, s * 0.6 - 0.12), Vector3(1.38, fy + 0.2, s * 0.6), 0.07, TRIM.lightened(0.08), "z", 3)
		v.box(Vector3(1.0, 0.72, s * 0.575), Vector3(1.45, 0.98, s * 0.579), TRIM.darkened(0.2))
		# Speaker grille on the side trim.
		v.push_at(Vector3(1.2, 0.85, s * 0.572), Vector3(90, 0, 0))
		v.cyl(Vector3.ZERO, 0.06, 0.06, 0.01 * s, Color("26252b"), 10)
		v.pop()
		v.extrude(PackedVector2Array([Vector2(1.5, Fifi3D.SILL_Y), Vector2(1.79, Fifi3D.SILL_Y), Vector2(1.79, Fifi3D.SILL_Y + 0.12),
			Vector2(Fifi3D.HINGE.x - 0.01, roof - 0.05), Vector2(Fifi3D.HINGE.x - 0.12, roof - 0.05)]), "z",
			minf(s * 0.6, s * 0.645), maxf(s * 0.6, s * 0.645), Color("3a3440"))
		v.box(Vector3(bx, fy, s * 0.6 - 0.02), Vector3(1.5, roof - 0.06, s * 0.6 + 0.02), TRIM)
	# Headliner with its padded seams, and the rear edge the fringe hangs from.
	v.box(Vector3(bx, roof - 0.09, -zi), Vector3(Fifi3D.HINGE.x, roof - 0.05, zi), Color("5a534c"))
	for k in 4:
		var x := lerpf(bx + 0.1, Fifi3D.HINGE.x - 0.08, k / 3.0)
		v.box(Vector3(x - 0.004, roof - 0.095, -zi), Vector3(x + 0.004, roof - 0.09, zi), Color("48423c"))
	v.box(Vector3(Fifi3D.HINGE.x - 0.04, roof - 0.12, -zi), Vector3(Fifi3D.HINGE.x + 0.02, roof - 0.05, zi), PAINT.darkened(0.3))


## A plank shelf on the seat back: glasses, cups, spare jars, the kettle,
## water bottles, a vase of plastic flowers.
func _shelf(v: Vox) -> void:
	var sx := Fifi3D.BULKHEAD_X + 0.035
	var y := 0.82
	v.box(Vector3(sx, y, -0.66), Vector3(sx + 0.2, y + 0.022, 0.66), WOOD)
	v.box(Vector3(sx + 0.18, y - 0.03, -0.66), Vector3(sx + 0.2, y + 0.045, 0.66), WOOD.darkened(0.12))
	for z in [-0.5, 0.0, 0.5]:
		v.extrude(PackedVector2Array([Vector2(sx, y), Vector2(sx + 0.16, y), Vector2(sx, y - 0.12)]), "z", z - 0.012, z + 0.012,
			Color("3a3a40"))
	var top := y + 0.022
	# Tea glasses stacked upside down in pairs of towers.
	for t in 2:
		for k in 4:
			var at := Vector3(sx + 0.08, top + k * 0.03, -0.6 + t * 0.07)
			v.use("glass")
			v.cyl(at, 0.028, 0.022, 0.05, Color(0.86, 0.94, 1.0, 0.45), 8)
			v.use("solid")
			v.cyl(at + Vector3(0, 0.0, 0), 0.029, 0.029, 0.004, Color("e8eef2"), 8)
	# Cups on saucers.
	for k in 3:
		var at := Vector3(sx + 0.08, top + k * 0.04, -0.4)
		v.cyl(at, 0.05, 0.05, 0.008, Color("ebe6dc"), 10)
		v.cyl(at + Vector3(0, 0.008, 0), 0.025, 0.032, 0.03, Color("f4f1ea"), 10)
		v.cyl(at + Vector3(0, 0.03, 0), 0.033, 0.033, 0.004, Color("c9a24a"), 10)
	# Spare jars.
	for k in 3:
		var at := Vector3(sx + 0.09, top, -0.26 + k * 0.08)
		_jar(v, at, [Color("3b2412"), Color("f1ede4"), Color("7a1428")][k], Color("c9a24a"), 0.08)
	# The kettle.
	var kt := Vector3(sx + 0.09, top, 0.08)
	v.push_at(kt)
	v.lathe([Vector2(0.06, 0.0), Vector2(0.07, 0.03), Vector2(0.065, 0.1), Vector2(0.03, 0.13), Vector2(0.0, 0.135)], 12, METAL)
	v.pop()
	v.rod(kt + Vector3(0, 0.06, 0.06), kt + Vector3(0, 0.11, 0.11), 0.01, METAL, 5)
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.008, 0.008), 5), [kt + Vector3(0, 0.13, -0.04), kt + Vector3(0, 0.18, -0.02),
		kt + Vector3(0, 0.18, 0.02), kt + Vector3(0, 0.13, 0.04)], Color("2a2a30"))
	# Water bottles with blue caps.
	for k in 3:
		var at := Vector3(sx + 0.09, top, 0.24 + k * 0.06)
		v.use("glass")
		v.cyl(at, 0.028, 0.028, 0.16, Color(0.8, 0.9, 1.0, 0.45), 8)
		v.use("solid")
		v.cyl(at + Vector3(0, 0.02, 0), 0.029, 0.029, 0.05, Color("2a6ab0"), 8)
		v.cyl(at + Vector3(0, 0.16, 0), 0.012, 0.012, 0.02, Color("2a6ab0"), 6)
	# Plastic flowers in a little vase.
	var vase := Vector3(sx + 0.09, top, 0.5)
	v.cyl(vase, 0.025, 0.035, 0.09, Color("2a8a8a"), 8)
	for k in 5:
		var a := TAU * k / 5.0
		var tip := vase + Vector3(cos(a) * 0.04, 0.17 + (k % 2) * 0.03, sin(a) * 0.05)
		v.rod(vase + Vector3(0, 0.08, 0), tip, 0.003, Color("3b8a3a"), 4)
		v.ball(tip, Vector3(0.022, 0.018, 0.022), [Color("e8433a"), Color("f2c230"), Color("f06ab0")][k % 3], 6, 2)


## Behind the counter, on the trunk floor: the water jerrycan, a crate of
## lemons and mangoes, a box of paper cups, a spare gas bottle, the power
## strip and its cables.
func _floor_storage(v: Vox) -> void:
	var fy := Fifi3D.FLOOR_Y + 0.03
	var j := Vector3(1.05, fy, -0.42)
	v.rbox(j + Vector3(-0.12, 0, -0.16), j + Vector3(0.12, 0.36, 0.16), 0.03, Color("2f6fb3"), "x", 2)
	v.box(j + Vector3(-0.04, 0.36, -0.12), j + Vector3(0.04, 0.4, 0.02), Color("2f6fb3"))
	v.cyl(j + Vector3(0, 0.36, 0.09), 0.03, 0.03, 0.05, Color("f2c230"), 8)
	var crate := Vector3(1.06, fy, 0.38)
	v.box(crate + Vector3(-0.14, 0, -0.18), crate + Vector3(0.14, 0.18, 0.18), Color("b88a4a"))
	for k in 3:
		v.box(crate + Vector3(-0.145, 0.04 + k * 0.05, -0.185), crate + Vector3(0.145, 0.06 + k * 0.05, 0.185), Color("8a6232"))
	for k in 8:
		var col := Color("f2a324") if k % 3 == 0 else Color("e8d84a")
		var r := 0.045 if k % 3 == 0 else 0.032
		v.ball(crate + Vector3(-0.09 + (k % 4) * 0.06, 0.2, -0.12 + (k / 4) * 0.14 + (k % 2) * 0.02), Vector3(r, r * 0.85, r), col, 6, 3)
	var cups := Vector3(1.06, fy, 0.0)
	v.box(cups + Vector3(-0.1, 0, -0.1), cups + Vector3(0.1, 0.22, 0.1), Color("c8a878"))
	v.box(cups + Vector3(-0.1, 0.22, -0.1), cups + Vector3(0.1, 0.23, 0.02), Color("b89868"))
	for k in 3:
		v.cyl(cups + Vector3(0.0, 0.23, 0.05), 0.03, 0.025, 0.02 + k * 0.03, Color("f4f1ea"), 8)
	var gas := Vector3(1.45, fy, 0.62)
	v.cyl(gas, 0.07, 0.07, 0.16, Color("2a6ab0"), 10)
	v.lathe([Vector2(0.07, 0.16), Vector2(0.03, 0.2)], 10, Color("2a6ab0"))
	# Power strip on the floor with its cables up to the bulbs and blender.
	var ps := Vector3(1.2, fy, -0.2)
	v.box(ps + Vector3(-0.03, 0, -0.12), ps + Vector3(0.03, 0.03, 0.12), Color("f1ede4"))
	for k in 3:
		v.box(ps + Vector3(-0.01, 0.03, -0.09 + k * 0.07), ps + Vector3(0.01, 0.032, -0.07 + k * 0.07), Color("2a2a30"))
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.006, 0.006), 4), [ps + Vector3(0, 0.02, 0.1), ps + Vector3(0.1, 0.01, 0.3),
		Vector3(1.0, Fifi3D.FLOOR_Y + 0.04, 0.66), Vector3(0.9, Fifi3D.ROOF_Y - 0.12, 0.66)], Color("1d1b20"))
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.006, 0.006), 4), [ps + Vector3(0, 0.02, -0.1), ps + Vector3(0.12, 0.01, -0.3),
		BLENDER_AT + Vector3(-0.12, -0.02, 0.0)], Color("1d1b20"))


## Hanging bulbs, charms from the headliner, fringe along its edge, a
## prayer-bead string, a hand of Fatima with the blue eye.
func _decor(v: Vox) -> void:
	var roof := Fifi3D.ROOF_Y
	for z in [-0.38, 0.38]:
		v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.004, 0.004), 4), [Vector3(1.3, roof - 0.09, z), Vector3(1.3, 1.25, z)],
			Color("1d1b20"))
		v.cyl(Vector3(1.3, 1.235, z), 0.012, 0.012, 0.02, Color("8a8579"), 6)
		v.use("glow/bulb")
		v.ball(Vector3(1.3, 1.2, z), Vector3(0.028, 0.036, 0.028), Color("fff1d6"), 8, 4)
		v.use("solid")
	# Hand of Fatima and a nazar on a string from the middle of the headliner.
	var c := Vector3(1.2, roof - 0.09, 0.02)
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.002, 0.002), 3), [c, c + Vector3(0, -0.14, 0)], Color("c9a24a"))
	v.box(c + Vector3(-0.004, -0.22, -0.03), c + Vector3(0.004, -0.14, 0.03), Color("2a6ab0"))
	for k in 5:
		v.box(c + Vector3(-0.004, -0.14, -0.028 + k * 0.012), c + Vector3(0.004, -0.12, -0.02 + k * 0.012), Color("2a6ab0"))
	v.cyl(c + Vector3(0.004, -0.185, 0), 0.012, 0.012, 0.002, Color("f4f1ea"), 8)
	v.cyl(c + Vector3(0.006, -0.185, 0), 0.006, 0.006, 0.002, Color("1c1c24"), 6)
	for k in 6:
		v.ball(c + Vector3(0, -0.24 - k * 0.018, 0), Vector3(0.008, 0.008, 0.008), Color("2a6ab0") if k % 2 else Color("c9a24a"), 5, 2)
	# A short fringe of coloured tassels along the roof's rear edge.
	var fringe := [Color("f2c230"), Color("e8433a"), Color("3bb36a"), Color("2fa4e0"), Color("f06ab0")]
	var zi := Fifi3D.HALF_W - 0.14
	for k in 26:
		var z := lerpf(-zi, zi, k / 25.0)
		var x := Fifi3D.HINGE.x - 0.005
		v.box(Vector3(x - 0.003, roof - 0.14, z - 0.007), Vector3(x + 0.003, roof - 0.09, z + 0.007), fringe[k % fringe.size()])
		v.ball(Vector3(x, roof - 0.146, z), Vector3(0.009, 0.009, 0.009), fringe[(k + 2) % fringe.size()], 5, 2)


## The raised hatch seen from below: painted frame with thickness, the
## pressed inner panel with its ribs and lightening holes, the seal, the
## latch, the glass (the sky shows through), struts and hinges.
func _hatch(v: Vox) -> void:
	var foot := Fifi3D.HATCH_FOOT - Fifi3D.HINGE
	var along := foot.normalized()
	# Outward when shut (to the rear and up); the inner panel is at -n.
	var n := Vector2(-along.y, along.x)
	var len := foot.length()
	var zo := Fifi3D.HALF_W - 0.06
	var th := 0.06
	var inner := -n * th
	var nn := Vector3(n.x, n.y, 0)
	var p := func(t: float, depth: float, z: float) -> Vector3:
		var q := along * t + n * depth
		return Vector3(q.x, q.y, z)
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
	v.use("glass")
	v.poly([p.call(g0, 0.006, -gz), p.call(g1, 0.006, -gz), p.call(g1, 0.006, gz), p.call(g0, 0.006, gz)],
		Color(0.14, 0.2, 0.36, 0.6), nn)
	v.poly([p.call(g0, -th - 0.004, -gz), p.call(g1, -th - 0.004, -gz), p.call(g1, -th - 0.004, gz), p.call(g0, -th - 0.004, gz)],
		Color(0.14, 0.2, 0.36, 0.6), -nn)
	v.use("solid")
	for k in range(1, 7):
		var t := lerpf(g0 + 0.03, g1 - 0.03, k / 7.0)
		v.poly([p.call(t, -th - 0.006, -gz + 0.05), p.call(t + 0.004, -th - 0.006, -gz + 0.05), p.call(t + 0.004, -th - 0.006, gz - 0.05),
			p.call(t, -th - 0.006, gz - 0.05)], Color("7a4a3a"), -nn)
	# Rubber seal round the glass.
	for z in [-gz, gz]:
		v.poly([p.call(g0, -th - 0.007, z - 0.012), p.call(g1, -th - 0.007, z - 0.012), p.call(g1, -th - 0.007, z + 0.012),
			p.call(g0, -th - 0.007, z + 0.012)], RUBBER, -nn)
	for t in [g0, g1]:
		v.poly([p.call(t - 0.012, -th - 0.007, -gz), p.call(t + 0.012, -th - 0.007, -gz), p.call(t + 0.012, -th - 0.007, gz),
			p.call(t - 0.012, -th - 0.007, gz)], RUBBER, -nn)
	# Inner panel below the glass: pressed ribs and oval lightening holes.
	var pa := g1 + 0.02
	v.poly([p.call(pa, -th - 0.003, -zo + 0.02), p.call(len - 0.02, -th - 0.003, -zo + 0.02), p.call(len - 0.02, -th - 0.003, zo - 0.02),
		p.call(pa, -th - 0.003, zo - 0.02)], PAINT.darkened(0.12), -nn)
	for zz in [-0.42, -0.21, 0.21, 0.42]:
		var holes := Vox.circle(Vector2.ZERO, Vector2(0.06, 0.035), 10)
		var pts: Array = []
		for h in holes:
			pts.append(p.call(pa + 0.1 + h.y, -th - 0.006, zz + h.x))
		v.poly(pts, PAINT.darkened(0.55), -nn)
	for t in [pa + 0.03, len - 0.05]:
		v.poly([p.call(t, -th - 0.008, -zo + 0.04), p.call(t + 0.012, -th - 0.008, -zo + 0.04), p.call(t + 0.012, -th - 0.008, zo - 0.04),
			p.call(t, -th - 0.008, zo - 0.04)], PAINT.lightened(0.15), -nn)
	# Latch in the middle of the lip, and the chrome striker.
	v.poly([p.call(len - 0.1, -th - 0.01, -0.07), p.call(len - 0.02, -th - 0.01, -0.07), p.call(len - 0.02, -th - 0.01, 0.07),
		p.call(len - 0.1, -th - 0.01, 0.07)], Color("2c2a30"), -nn)
	v.poly([p.call(len - 0.06, -th - 0.014, -0.025), p.call(len - 0.02, -th - 0.014, -0.025), p.call(len - 0.02, -th - 0.014, 0.025),
		p.call(len - 0.06, -th - 0.014, 0.025)], CHROME, -nn)
	# Seal round the whole edge, and the hinges.
	v.box(Vector3(foot.x - 0.02, foot.y - 0.02, -zo), Vector3(foot.x + 0.01, foot.y + 0.01, zo), RUBBER)
	for z in [-0.45, 0.45]:
		v.box(Vector3(-0.04, -0.03, z - 0.04), Vector3(0.04, 0.02, z + 0.04), Color("2c2a30"))
	# A sticker on the inside of the frame.
	v.poly([p.call(pa + 0.2, -th - 0.009, -0.12), p.call(pa + 0.26, -th - 0.009, -0.12), p.call(pa + 0.26, -th - 0.009, 0.12),
		p.call(pa + 0.2, -th - 0.009, 0.12)], Color("f4f1ea"), -nn)


## LEDs round the opening and along the hatch, fairy lights draped under
## it, gas struts (their ends move with the hatch, so built in car space).
func _hatch_lights(v: Vox, hatch: Node3D) -> void:
	var xf := hatch.transform
	var zi := Fifi3D.HALF_W - 0.1
	var sill := Fifi3D.SILL_Y
	var roof := Fifi3D.ROOF_Y
	var loop := [Vector3(1.81, sill + 0.045, -zi), Vector3(1.81, sill + 0.045, zi), Vector3(1.79, sill + 0.13, zi),
		Vector3(Fifi3D.HINGE.x + 0.02, roof - 0.06, zi - 0.04), Vector3(Fifi3D.HINGE.x + 0.02, roof - 0.06, -zi + 0.04),
		Vector3(1.79, sill + 0.13, -zi), Vector3(1.81, sill + 0.045, -zi)]
	var k := _led_run(v, loop, 0, 0.035)
	var foot := Fifi3D.HATCH_FOOT - Fifi3D.HINGE
	var along := foot.normalized()
	var n := Vector2(-along.y, along.x)
	var e := -n * 0.066
	var zo := Fifi3D.HALF_W - 0.1
	var edge := [Vector3(e.x, e.y, -zo), Vector3(foot.x + e.x, foot.y + e.y, -zo), Vector3(foot.x + e.x, foot.y + e.y, zo),
		Vector3(e.x, e.y, zo)]
	var pts: Array = []
	for q in edge:
		pts.append(xf * (q as Vector3))
	_led_run(v, pts, k, 0.035)
	# Fairy lights hanging in a swag across under the hatch.
	var a: Vector3 = xf * Vector3(foot.x * 0.7 + e.x, foot.y * 0.7 + e.y, -zo + 0.05)
	var b: Vector3 = xf * Vector3(foot.x * 0.7 + e.x, foot.y * 0.7 + e.y, zo - 0.05)
	var wire: Array = []
	for i in 13:
		var t := i / 12.0
		wire.append(a.lerp(b, t) + Vector3(0, -0.12 * sin(PI * t), 0))
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.003, 0.003), 3), wire, Color("2a4a2a"), Vector3.RIGHT, false)
	for i in range(1, 12):
		var g := i % LED_COLORS.size()
		v.use("glow/led%d" % g)
		v.ball(wire[i] + Vector3(0, -0.018, 0), Vector3(0.011, 0.016, 0.011), LED_COLORS[g], 6, 2)
	v.use("solid")
	# Gas struts from the pillars up to the hatch.
	for z in [-zo + 0.03, zo - 0.03]:
		var low := Vector3(1.7, sill + 0.28, z)
		var high: Vector3 = xf * Vector3(foot.x * 0.42 - n.x * 0.06, foot.y * 0.42 - n.y * 0.06, z)
		var mid := low.lerp(high, 0.55)
		v.rod(low, mid, 0.016, Color("2a2a30"), 6)
		v.rod(mid, high, 0.008, CHROME, 6)
		v.cube(low, Vector3(0.03, 0.03, 0.03), Color("2a2a30"))


func _led_run(v: Vox, path: Array, start: int, step: float) -> int:
	var k := start
	for i in path.size() - 1:
		var a: Vector3 = path[i]
		var b: Vector3 = path[i + 1]
		var n := maxi(1, int(a.distance_to(b) / step))
		v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.004, 0.004), 3), [a, b], Color("26252b"), Vector3.RIGHT, false)
		for j in n:
			var g := posmod(floori(k / 3.0), LED_COLORS.size())
			v.use("glow/led%d" % g)
			v.cube(a.lerp(b, j / float(n)), Vector3(0.014, 0.014, 0.014), LED_COLORS[g])
			k += 1
	v.use("solid")
	return k


## A little clip-on fan on the side trim, blades turning.
func _build_fan(v: Vox) -> void:
	v.box(Vector3(-0.02, -0.12, -0.03), Vector3(0.02, 0.0, 0.03), Color("e8e4dc"))
	v.cyl(Vector3(0, -0.14, 0), 0.03, 0.03, 0.02, Color("e8e4dc"), 8)
	v.box(Vector3(-0.03, -0.02, -0.03), Vector3(0.03, 0.02, 0.05), Color("e8e4dc"))
	for k in 8:
		var a := TAU * k / 8.0
		v.rod(Vector3(cos(a) * 0.09, sin(a) * 0.09, 0.07), Vector3(cos(a + 0.4) * 0.09, sin(a + 0.4) * 0.09, 0.07), 0.003,
			Color("c9ced6"), 3)
	v.into(_fan, "Body")
	var blades := Node3D.new()
	blades.position = Vector3(0, 0, 0.06)
	_fan.add_child(blades)
	_fan.move_child(blades, 0)
	for k in 3:
		var a := TAU * k / 3.0
		v.push_at(Vector3.ZERO, Vector3(0, 0, rad_to_deg(a)))
		v.box(Vector3(0.01, -0.02, -0.003), Vector3(0.08, 0.02, 0.003), Color("5ab0c8"))
		v.pop()
	v.cyl(Vector3(0, 0, -0.01), 0.018, 0.018, 0.02, Color("e8e4dc"), 8)
	v.into(blades, "Blades")

#endregion


#region Racks

## Sayed's rail of spare كنكة in three sizes, the ladle, the milk pan and
## the tongs, on S-hooks. Local space: the rail's middle at the origin on
## the seat back, hanging toward +x.
func _rack_hooks(v: Vox) -> void:
	var half := 0.26
	v.rod(Vector3(0.03, 0, -half), Vector3(0.03, 0, half), 0.006, CHROME, 6)
	for z in [-half, half]:
		v.box(Vector3(0.0, -0.015, z - 0.012), Vector3(0.035, 0.012, z + 0.012), Color("2c2a30"))
	var items := [[-0.2, 1.0], [-0.08, 0.8], [0.02, 0.62]]
	for it in items:
		var z: float = it[0]
		var s: float = it[1]
		_s_hook(v, z)
		_kanaka_hanging(v, Vector3(0.05, -0.05, z), s)
	_s_hook(v, 0.1)
	v.rod(Vector3(0.035, -0.045, 0.1), Vector3(0.035, -0.2, 0.1), 0.004, METAL, 4)
	v.push_at(Vector3(0.05, -0.23, 0.1), Vector3(0, 0, 90))
	v.lathe([Vector2(0.0, -0.012), Vector2(0.03, 0.0), Vector2(0.032, 0.02)], 10, METAL)
	v.pop()
	_s_hook(v, 0.17)
	v.rod(Vector3(0.035, -0.045, 0.17), Vector3(0.035, -0.12, 0.17), 0.006, GRIP, 4)
	v.push_at(Vector3(0.06, -0.17, 0.17), Vector3(0, 0, 90))
	v.cyl(Vector3(0, -0.025, 0), 0.045, 0.045, 0.05, METAL_DARK, 12)
	v.cyl(Vector3(0, 0.024, 0), 0.04, 0.04, 0.002, Color("26221e"), 12)
	v.pop()
	_s_hook(v, 0.23)
	for d in [-0.008, 0.008]:
		v.rod(Vector3(0.035, -0.045, 0.23), Vector3(0.035, -0.17, 0.23 + d * 3.0), 0.004, METAL, 4)


func _s_hook(v: Vox, z: float) -> void:
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.003, 0.003), 3), [Vector3(0.03, 0.01, z), Vector3(0.05, 0.0, z), Vector3(0.04, -0.02, z),
		Vector3(0.03, -0.035, z), Vector3(0.04, -0.05, z)], Color("8a8e96"))


## A كنكة hanging by its handle: belly, pinched neck, flared lip, spout.
func _kanaka_hanging(v: Vox, at: Vector3, s: float) -> void:
	v.rod(at, at + Vector3(0.0, -0.12 * s, 0.0), 0.008 * s, GRIP, 5)
	v.push_at(at + Vector3(0.05 * s, -0.16 * s, 0), Vector3(0, 0, -90))
	v.lathe([Vector2(0.045 * s, -0.05 * s), Vector2(0.05 * s, -0.02 * s), Vector2(0.038 * s, 0.03 * s), Vector2(0.046 * s, 0.05 * s)],
		10, METAL, false)
	v.cyl(Vector3(0, -0.052 * s, 0), 0.045 * s, 0.045 * s, 0.004, METAL_DARK, 10)
	v.pop()


## The lemon squeezer, as it hangs on its hook: two long yellow handles
## hinged at the bottom round a round perforated cup with the press dome
## nested in it, the cup's mouth toward us. A tea strainer and the towel
## hang beside it, and a net bag of lemons.
func _rack_lemon(v: Vox) -> void:
	v.rod(Vector3(0.03, 0, -0.14), Vector3(0.03, 0, 0.14), 0.006, CHROME, 6)
	for z in [-0.14, 0.14]:
		v.box(Vector3(0.0, -0.015, z - 0.012), Vector3(0.035, 0.012, z + 0.012), Color("2c2a30"))
	# The squeezer.
	var z := -0.07
	_s_hook(v, z)
	var top := Vector3(0.045, -0.05, z)
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.008, 0.008), 6), [top + Vector3(0, 0.0, 0), top + Vector3(0.0, -0.01, 0.01),
		top + Vector3(0, -0.02, 0), top + Vector3(0, -0.01, -0.01), top], Color("8a8e96"), Vector3.RIGHT, false)
	var cup := top + Vector3(0.0, -0.21, 0)
	for side in [-1.0, 1.0]:
		# Flat handles, one in front of the other, opening a touch at the cup.
		var h0 := top + Vector3(side * 0.006, -0.02, 0)
		var h1 := cup + Vector3(side * 0.035, 0.05, side * 0.02)
		v.sweep(Vox.round_rect(Rect2(-0.009, -0.004, 0.018, 0.008), 0.003, 1), [h0, h0.lerp(h1, 0.6) + Vector3(side * 0.006, 0, 0), h1],
			SQUEEZER, Vector3.RIGHT)
		v.cube(h0 + Vector3(0, -0.01, 0), Vector3(0.012, 0.02, 0.022), SQUEEZER.darkened(0.2))
	# The cup: a yellow bowl facing us with holes in its floor.
	v.push_at(cup + Vector3(0.035, 0, 0), Vector3(0, 0, -90))
	v.lathe([Vector2(0.0, -0.02), Vector2(0.035, -0.012), Vector2(0.045, 0.01), Vector2(0.047, 0.02)], 14, SQUEEZER, false)
	v.lathe([Vector2(0.043, 0.02), Vector2(0.041, 0.01), Vector2(0.03, -0.008), Vector2(0.0, -0.014)], 14, SQUEEZER.darkened(0.12),
		false, false)
	v.pop()
	for k in 7:
		var a := TAU * k / 7.0
		v.cube(cup + Vector3(0.023, sin(a) * 0.02, cos(a) * 0.02), Vector3(0.004, 0.006, 0.006), Color("5a4a1a"))
	v.cube(cup + Vector3(0.023, 0, 0), Vector3(0.004, 0.006, 0.006), Color("5a4a1a"))
	# The hinge pin under the cup, and the press dome's edge showing behind.
	v.push_at(cup + Vector3(0.0, -0.055, 0), Vector3(0, 0, 90))
	v.cyl(Vector3(0, -0.02, 0), 0.008, 0.008, 0.04, Color("8a8e96"), 6)
	v.pop()
	v.push_at(cup + Vector3(0.0, 0, 0), Vector3(0, 0, -90))
	v.lathe([Vector2(0.046, -0.002), Vector2(0.04, 0.02), Vector2(0.0, 0.03)], 14, SQUEEZER.lightened(0.08))
	v.pop()
	# Tea strainer on the next hook.
	var sz := 0.03
	_s_hook(v, sz)
	v.rod(Vector3(0.035, -0.045, sz), Vector3(0.035, -0.13, sz), 0.004, METAL, 4)
	v.push_at(Vector3(0.05, -0.16, sz), Vector3(0, 0, -90))
	v.lathe([Vector2(0.032, 0.0), Vector2(0.025, 0.015), Vector2(0.0, 0.02)], 12, Color("4a4850"))
	v.cyl(Vector3(0, -0.003, 0), 0.034, 0.034, 0.005, METAL, 12)
	v.pop()
	# The checked towel over the rail's end.
	var tz := 0.11
	v.box(Vector3(0.028, -0.2, tz - 0.035), Vector3(0.045, 0.012, tz + 0.035), TOWEL)
	for k in 5:
		v.box(Vector3(0.044, -0.19 + k * 0.04, tz - 0.035), Vector3(0.047, -0.175 + k * 0.04, tz + 0.035), Color("c23b2a"))
	for k in 2:
		v.box(Vector3(0.044, -0.2, tz - 0.02 + k * 0.03), Vector3(0.047, 0.012, tz - 0.012 + k * 0.03), Color("c23b2a"))
	# A net bag of lemons hanging off the end.
	var nz := 0.17
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.002, 0.002), 3), [Vector3(0.03, 0, nz), Vector3(0.05, -0.08, nz)], Color("3a8a3a"))
	for k in 6:
		var lc := Color("e8d84a") if k % 2 else Color("b8c83a")
		v.ball(Vector3(0.06, -0.1 - (k / 2) * 0.035, nz - 0.02 + (k % 2) * 0.035), Vector3(0.02, 0.018, 0.018), lc, 6, 3)


## The chalk menu board: wooden frame, dark green board, today's drinks
## and prices in chalk (Label3D), a chalk stub on the ledge.
func _rack_board(v: Vox, node: Node3D) -> void:
	var w := 0.36
	var h := 0.26
	v.box(Vector3(-0.015, -h * 0.5, -w * 0.5), Vector3(0.0, h * 0.5, w * 0.5), Color("8a5a32"))
	v.box(Vector3(0.0, -h * 0.5 + 0.015, -w * 0.5 + 0.015), Vector3(0.003, h * 0.5 - 0.015, w * 0.5 - 0.015), BOARD)
	v.box(Vector3(0.0, -h * 0.5 - 0.005, -w * 0.5), Vector3(0.025, -h * 0.5 + 0.01, w * 0.5), Color("8a5a32"))
	v.box(Vector3(0.005, -h * 0.5 + 0.01, 0.08), Vector3(0.015, -h * 0.5 + 0.02, 0.12), Color(0.95, 0.94, 0.88))
	for c in [Vector3(0.004, h * 0.5 - 0.01, -w * 0.5 + 0.01), Vector3(0.004, h * 0.5 - 0.01, w * 0.5 - 0.01)]:
		v.cube(c, Vector3(0.006, 0.01, 0.01), Color("c9ced6"))
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


func _load_racks() -> void:
	var saved: Dictionary = Economy.data.settings.get("rack_spots", {})
	for id in RACKS:
		var at: Vector2 = RACKS[id]
		if saved.has(id):
			at = Vector2(float(saved[id][0]), float(saved[id][1]))
		_place_rack(id, at)


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


func save_racks() -> void:
	var out := {}
	for id in rack_spots:
		var s: Vector2 = rack_spots[id]
		out[id] = [s.x, s.y]
	Economy.data.settings["rack_spots"] = out
	Economy.save()

#endregion
