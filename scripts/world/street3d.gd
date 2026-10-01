class_name Street3D
extends Node3D
## The street FIFI parks on, in blocks: a four-lane road with patched
## asphalt, faded lane lines and a zebra crossing, black-and-white painted
## kerbs, stone pavements, a front garden behind railings on our side, and a
## row of Cairo apartment blocks with shops across the road (shutters, lit
## shopfronts and signs, balconies, AC units, washing). Silver streetlights
## lean their cobra heads out over the road and pool sodium light on it
## after dusk. Static geometry is baked into a few meshes; set_time() only
## changes lights and glow levels.
##
## Lights are the expensive part on a phone: a light costs something on
## every pixel of every mesh it touches, and the road and pavements cover
## the whole screen. So the ground sits on its own render layer that the
## lamps (and FIFI's bulb) skip, and the lamps' pools on the ground are
## painted on instead: glowing discs that follow the road and kerbs.
##
## Laid out on the old tile grid: tile (u, v) sits at (u, 0, v) × TILE, so
## the lanes, spots and paths the traffic and customers use carry over.

const TILE := 0.6
const KERB_H := 0.15
## Road edges (z): the near kerb's road face and the far kerb's.
const ROAD_NEAR := 1.5
const ROAD_FAR := -6.9
## The render layer of the big ground meshes (road, pavements, garden,
## buildings), and the cull mask for lamps and bulbs that leaves them out.
const GROUND_LAYER := 2
const LIT_MASK := 1
## Near pavement runs to the garden railings; across the road the shops.
const PAVE_NEAR_END := 7.8
const FACADE_Z := -10.2
const X_MIN := -34.0
const X_MAX := 34.0
## Dashed lane lines (z) and the solid line down the middle.
const DASHES := [-0.75, -2.85]
const CENTRE_LINE := -4.95
## Streetlights: foot (x, z) and which way the arm reaches (-1 toward -z).
const LAMPS := [[Vector2(-1.8, 2.25), -1.0], [Vector2(5.4, 2.25), -1.0], [Vector2(-3.6, -7.65), 1.0],
	[Vector2(12.6, 2.25), -1.0], [Vector2(-10.8, -7.65), 1.0]]
const POLE_H := 6.4
const ARM_REACH := 1.5

const ROAD := Color("575962")
const ROAD_PATCH := Color("4d4f58")
const ROAD_OLD := Color("62646c")
const LANE := Color("dedcd4")
const KERB_DARK := Color("2c2c31")
const KERB_LIGHT := Color("e6e3dc")
const STONE_A := Color("a29d97")
const STONE_B := Color("99948e")
const STONE_C := Color("aba59e")
const GROUT := Color("7a7570")
const POLE := Color("a9adb5")
const SODIUM := Color("ffa94d")
const SHOP_NAMES := ["بقالة الأمل", "صيدلية الشفا", "عصير قصب", "حلاق الملوك", "مكوجي", "كشري التحرير", "موبايلات",
	"مخبز العيش", "فول وطعمية", "ورشة نجارة", "ستوديو فرح", "لوازم مدارس", "عطارة", "كوافير", "خردوات"]
const WALLS := ["e8d8b8", "d8c4a0", "c9b08a", "e0cfc0", "b8a898", "d8b8a8", "a8b0b8", "c8a888", "d0c0a0", "b89a7a"]
const SIGN_COLORS := ["c8322b", "2a6ab0", "3b8a5a", "e0a030", "7a3a8a", "1c1c24", "e07a2a"]

## While a drink is made the lamps' real light would only fall on FIFI's
## trunk (most of the screen there), which the work bulb already lights.
var lamps_lit := true:
	set(on):
		lamps_lit = on
		for light in _lamp_lights:
			light.visible = on and light.light_energy > 0.2
var _lamp_lights: Array[SpotLight3D] = []
var _pool_mat := Street3D.pool_material()
var _moths: Array[CPUParticles3D] = []
var _rng := RandomNumberGenerator.new()


static func tile(u: float, v: float, y := 0.0) -> Vector3:
	return Vector3(u * TILE, y, v * TILE)


func _ready() -> void:
	_rng.seed = 1127
	var v := Vox.new()
	_road(v)
	v.into(self, "Road").layers = GROUND_LAYER
	_kerbs_and_pavements(v)
	v.into(self, "Pavements").layers = GROUND_LAYER
	_garden(v)
	v.into(self, "Garden").layers = GROUND_LAYER
	var x := X_MIN
	var i := 0
	while x < X_MAX:
		var w := _rng.randf_range(6.5, 10.0)
		_building(v, x, x + w, i)
		v.into(self, "Building%d" % i).layers = GROUND_LAYER
		x += w + (_rng.randf_range(0.8, 1.4) if _rng.randf() < 0.25 else 0.0)
		i += 1
	for lamp in LAMPS:
		_streetlight(v, lamp[0], lamp[1])
	_props(v)
	v.into(self, "Furniture")


## Lamps on after dusk, windows and shop signs lit.
func set_time(darkness: float) -> void:
	Vox.set_glow("glow/lamp", lerpf(0.0, 3.2, darkness))
	Vox.set_glow("glow/window", lerpf(0.0, 1.6, darkness))
	Vox.set_glow("glow/sign", lerpf(0.4, 2.2, darkness))
	_pool_mat.albedo_color = Color(SODIUM * (1.15 * darkness), 1.0)
	for light in _lamp_lights:
		light.light_energy = 12.0 * darkness
		light.visible = darkness > 0.02 and lamps_lit
	for m in _moths:
		m.emitting = darkness > 0.5


#region Road

func _road(v: Vox) -> void:
	v.box(Vector3(X_MIN - 10, -0.3, ROAD_FAR), Vector3(X_MAX + 10, 0.0, ROAD_NEAR), ROAD)
	# Resurfaced patches and older, paler stretches, a hair above the road.
	for p in [Vector4(-6.0, -1.8, 3.2, 1.6), Vector4(3.0, -5.2, 2.2, 1.1), Vector4(9.0, -1.0, 4.0, 1.4),
			Vector4(-12.0, -4.0, 2.6, 2.0), Vector4(-2.0, -3.6, 1.4, 0.9), Vector4(15.0, -5.6, 3.0, 1.2),
			Vector4(-18.0, -0.8, 3.4, 1.3)]:
		v.box(Vector3(p.x - p.z * 0.5, 0.0, p.y - p.w * 0.5), Vector3(p.x + p.z * 0.5, 0.004, p.y + p.w * 0.5), ROAD_PATCH)
		v.box(Vector3(p.x - p.z * 0.3, 0.0, p.y - p.w * 0.35), Vector3(p.x + p.z * 0.2, 0.006, p.y + p.w * 0.2),
			ROAD_PATCH.darkened(0.06))
	for p in [Vector4(-9.0, -5.8, 5.0, 1.4), Vector4(6.0, -3.4, 3.5, 0.8), Vector4(20.0, -2.2, 6.0, 1.0)]:
		v.box(Vector3(p.x - p.z * 0.5, 0.0, p.y - p.w * 0.5), Vector3(p.x + p.z * 0.5, 0.003, p.y + p.w * 0.5), ROAD_OLD)
	# Cracks: thin dark zigzags.
	for c in [[Vector3(-4, 0, -4.2), 7], [Vector3(7.5, 0, -6.0), 5], [Vector3(1.5, 0, -1.4), 4], [Vector3(-15, 0, -2.5), 6]]:
		var at: Vector3 = c[0]
		for k in int(c[1]):
			var nx := at + Vector3(_rng.randf_range(0.2, 0.45), 0, _rng.randf_range(-0.2, 0.2))
			v.rod(at + Vector3(0, 0.004, 0), nx + Vector3(0, 0.004, 0), 0.012, Color("3c3d44"), 4)
			at = nx
	# Lane lines, worn in places.
	for z in DASHES:
		var x := X_MIN
		while x < X_MAX:
			var worn := _rng.randf() < 0.2
			v.box(Vector3(x, 0.0, z - 0.06), Vector3(x + 1.6, 0.008, z + 0.06), LANE.darkened(0.25) if worn else LANE)
			x += 3.2
	v.box(Vector3(X_MIN, 0.0, CENTRE_LINE - 0.07), Vector3(X_MAX, 0.008, CENTRE_LINE + 0.07), LANE)
	v.box(Vector3(X_MIN, 0.0, CENTRE_LINE - 0.27), Vector3(X_MAX, 0.008, CENTRE_LINE - 0.15), LANE)
	# A faded zebra crossing up the street.
	for k in 12:
		var z := ROAD_FAR + 0.35 + k * 0.7
		if z + 0.4 > ROAD_NEAR:
			break
		v.box(Vector3(-15.5, 0.0, z), Vector3(-13.3, 0.007, z + 0.4), LANE.darkened(0.12 if k % 3 else 0.3))
	# Manhole covers and kerbside drain grates.
	for m in [Vector2(-3.3, -0.3), Vector2(8.0, -4.2), Vector2(-9.0, -2.0)]:
		v.cyl(Vector3(m.x, 0.0, m.y), 0.36, 0.36, 0.012, Color("3c3d43"), 12)
		v.cyl(Vector3(m.x, 0.0, m.y), 0.28, 0.28, 0.018, Color("46474e"), 12)
		for k in 3:
			v.box(Vector3(m.x - 0.22, 0.018, m.y - 0.12 + k * 0.12), Vector3(m.x + 0.22, 0.022, m.y - 0.09 + k * 0.12), Color("3a3b41"))
	for dx in [-8.0, 3.8, 11.0, -20.0, 18.0]:
		v.box(Vector3(dx - 0.35, 0.0, ROAD_NEAR - 0.3), Vector3(dx + 0.35, 0.01, ROAD_NEAR - 0.02), Color("2a2a30"))
		for k in 6:
			v.box(Vector3(dx - 0.3 + k * 0.11, 0.01, ROAD_NEAR - 0.27), Vector3(dx - 0.26 + k * 0.11, 0.014, ROAD_NEAR - 0.05),
				Color("4a4a50"))
	# Oil stains where cars wait, and a dark shadow line along the kerbs.
	for s in [Vector2(3.9, 0.6), Vector2(-6.5, 0.4), Vector2(12, -2.9)]:
		v.cyl(Vector3(s.x, 0.0, s.y), 0.4, 0.4, 0.003, Color("4a4b53"), 8)
	v.box(Vector3(X_MIN, 0.0, ROAD_NEAR - 0.12), Vector3(X_MAX, 0.002, ROAD_NEAR), Color("45464d"))
	v.box(Vector3(X_MIN, 0.0, ROAD_FAR), Vector3(X_MAX, 0.002, ROAD_FAR + 0.12), Color("45464d"))

#endregion


#region Kerbs and pavements

func _kerbs_and_pavements(v: Vox) -> void:
	# Kerb stones painted in alternating black and white blocks.
	var x := X_MIN
	var k := 0
	while x < X_MAX:
		var col := KERB_DARK if k % 2 == 0 else KERB_LIGHT
		v.box(Vector3(x, 0.0, ROAD_NEAR), Vector3(x + TILE, KERB_H + 0.01, ROAD_NEAR + 0.3), col)
		v.box(Vector3(x, 0.0, ROAD_FAR - 0.3), Vector3(x + TILE, KERB_H + 0.01, ROAD_FAR), col)
		x += TILE
		k += 1
	# Paving slabs, a few tones, grout showing between them.
	v.box(Vector3(X_MIN, -0.3, ROAD_NEAR + 0.3), Vector3(X_MAX, KERB_H, PAVE_NEAR_END), GROUT)
	v.box(Vector3(X_MIN, -0.3, FACADE_Z - 0.5), Vector3(X_MAX, KERB_H, ROAD_FAR - 0.3), GROUT)
	_slabs(v, ROAD_NEAR + 0.3, PAVE_NEAR_END)
	_slabs(v, FACADE_Z - 0.5, ROAD_FAR - 0.3)


func _slabs(v: Vox, z0: float, z1: float) -> void:
	var s := TILE
	var z := z0
	var row := 0
	while z < z1 - 0.05:
		var x := X_MIN
		while x < X_MAX:
			var roll := _rng.randf()
			var col := STONE_A if roll < 0.45 else (STONE_B if roll < 0.85 else STONE_C)
			if _rng.randf() < 0.04:
				col = col.darkened(0.12)
			var zz := minf(z + s - 0.03, z1)
			var lift := 0.004 + (0.006 if _rng.randf() < 0.05 else 0.0)
			# Only the top: the few millimetres of side never show, and the
			# pavement is thousands of slabs.
			var y := KERB_H + lift
			v.quad(Vector3(x + 0.015, y, z + 0.015), Vector3(x + s - 0.015, y, z + 0.015),
				Vector3(x + s - 0.015, y, zz), Vector3(x + 0.015, y, zz), col, Vector3.UP)
			x += s
		z += s
		row += 1

#endregion


#region Near side: the garden behind its railings

func _garden(v: Vox) -> void:
	var z0 := PAVE_NEAR_END
	# Low rendered wall with a cap, iron railings on top, square piers.
	v.box(Vector3(X_MIN, 0.0, z0), Vector3(X_MAX, 0.55, z0 + 0.3), Color("d8ccb4"))
	v.box(Vector3(X_MIN, 0.55, z0 - 0.03), Vector3(X_MAX, 0.62, z0 + 0.33), Color("e8e0d0"))
	v.box(Vector3(X_MIN, 0.0, z0 - 0.01), Vector3(X_MAX, 0.12, z0 + 0.31), Color("a89c88"))
	var x := X_MIN + 0.1
	while x < X_MAX:
		if int(round(x / 0.13)) % 23 == 0:
			v.box(Vector3(x - 0.14, 0.0, z0 - 0.04), Vector3(x + 0.14, 1.55, z0 + 0.34), Color("d8ccb4"))
			v.box(Vector3(x - 0.17, 1.55, z0 - 0.07), Vector3(x + 0.17, 1.63, z0 + 0.37), Color("e8e0d0"))
			v.cube(Vector3(x, 1.7, z0 + 0.15), Vector3(0.14, 0.14, 0.14), Color("e8e0d0"))
		else:
			v.box(Vector3(x - 0.012, 0.62, z0 + 0.13), Vector3(x + 0.012, 1.4, z0 + 0.17), Color("2e3a34"))
			v.cube(Vector3(x, 1.43, z0 + 0.15), Vector3(0.04, 0.06, 0.04), Color("2e3a34"))
		x += 0.13
	for y in [0.75, 1.3]:
		v.box(Vector3(X_MIN, y, z0 + 0.12), Vector3(X_MAX, y + 0.03, z0 + 0.18), Color("2e3a34"))
	# Grass and earth beyond, bushes along the wall, a few trees.
	v.box(Vector3(X_MIN, -0.3, z0 + 0.3), Vector3(X_MAX, 0.1, z0 + 9.0), Color("5a7a3a"))
	for k in 60:
		var gx := _rng.randf_range(X_MIN, X_MAX)
		var gz := _rng.randf_range(z0 + 0.5, z0 + 8.5)
		v.box(Vector3(gx, 0.1, gz), Vector3(gx + _rng.randf_range(0.4, 1.2), 0.106, gz + _rng.randf_range(0.3, 0.8)),
			Color("62843f") if k % 2 else Color("4f6e33"))
	var bx := X_MIN
	while bx < X_MAX:
		var r := _rng.randf_range(0.35, 0.6)
		v.ball(Vector3(bx, 0.3 + r * 0.6, z0 + 0.75), Vector3(r, r * 0.9, r), Color("3e6a2e") if _rng.randf() < 0.6 else Color("4a7a34"), 7, 3)
		bx += _rng.randf_range(0.7, 1.3)
	for t in [Vector2(-2.5, 11.0), Vector2(6.0, 10.2), Vector2(14.0, 11.5), Vector2(-10.0, 10.5), Vector2(22.0, 10.0),
			Vector2(1.5, 14.0), Vector2(10.0, 15.0)]:
		_tree(v, Vector3(t.x, 0.1, t.y), _rng.randf_range(0.9, 1.25))


func _tree(v: Vox, at: Vector3, s: float) -> void:
	v.cyl(at, 0.16 * s, 0.11 * s, 2.2 * s, Color("5a3a24"), 6)
	v.rod(at + Vector3(0, 1.6 * s, 0), at + Vector3(0.5 * s, 2.3 * s, 0.2 * s), 0.06 * s, Color("5a3a24"), 5)
	var greens := [Color("2f5a26"), Color("3a6a2c"), Color("457a32"), Color("2a4e22")]
	for k in 7:
		var off := Vector3(_rng.randf_range(-0.8, 0.8), _rng.randf_range(2.2, 3.4), _rng.randf_range(-0.8, 0.8)) * s
		var r := _rng.randf_range(0.6, 0.95) * s
		v.ball(at + off, Vector3(r, r * 0.85, r), greens[k % greens.size()], 7, 4)

#endregion


#region The shops and flats across the road

func _building(v: Vox, x0: float, x1: float, index: int) -> void:
	var floors := _rng.randi_range(4, 7)
	var wall := Color(WALLS[_rng.randi() % WALLS.size()])
	var trim := wall.lightened(0.2)
	var f := FACADE_Z
	var ground_h := 3.6
	var fh := 3.0
	var top := ground_h + fh * (floors - 1)
	var depth := 12.0
	v.box(Vector3(x0, 0.0, f - depth), Vector3(x1, top, f), wall)
	# Grime along the foot of the wall and a parapet on top.
	v.box(Vector3(x0, 0.0, f - 0.02), Vector3(x1, 0.45, f + 0.01), wall.darkened(0.25))
	v.box(Vector3(x0, top, f - depth), Vector3(x1, top + 0.9, f + 0.05), wall.darkened(0.05))
	v.box(Vector3(x0 - 0.05, top + 0.9, f - depth), Vector3(x1 + 0.05, top + 1.0, f + 0.1), trim)
	# Floor bands.
	for k in floors:
		var y := ground_h + fh * k - 0.12
		if k < floors - 1:
			v.box(Vector3(x0, y, f), Vector3(x1, y + 0.18, f + 0.12), trim)
	_shopfronts(v, x0, x1, f, ground_h, index)
	# Upper floors: windows, some with balconies.
	var bays := maxi(2, int((x1 - x0) / 2.4))
	var bay_w := (x1 - x0) / bays
	for k in range(1, floors):
		var y0 := ground_h + fh * (k - 1)
		for b in bays:
			var cx := x0 + bay_w * (b + 0.5)
			var balcony := (b % 2 == 1) and _rng.randf() < 0.7
			_window(v, cx, y0, f, balcony, wall)
	# The side wall shows where the next block steps back.
	v.box(Vector3(x1 - 0.02, 0.0, f - depth), Vector3(x1, top, f), wall.darkened(0.12))


func _shopfronts(v: Vox, x0: float, x1: float, f: float, h: float, index: int) -> void:
	var units := 2 if x1 - x0 < 8.5 else 3
	var uw := (x1 - x0) / units
	for u in units:
		var a := x0 + uw * u + 0.25
		var b := x0 + uw * (u + 1) - 0.25
		# Pillars between the shops.
		v.box(Vector3(a - 0.25, 0.0, f), Vector3(a, h, f + 0.15), Color("cfc3ae"))
		var open := _rng.randf() < 0.7
		var sign_col := Color(SIGN_COLORS[_rng.randi() % SIGN_COLORS.size()])
		var door_top := h - 0.9
		# Recessed shop: dark inside, shelves of goods, a counter.
		v.box(Vector3(a, 0.0, f - 1.8), Vector3(b, door_top, f - 1.75), Color("3a3230"))
		v.box(Vector3(a, 0.0, f - 1.8), Vector3(a + 0.05, door_top, f), Color("4a403a"))
		v.box(Vector3(a, door_top - 0.05, f - 1.8), Vector3(b, door_top, f), Color("2a2422"))
		v.box(Vector3(a, 0.0, f - 1.8), Vector3(b, 0.02, f), Color("8a8078"))
		if open:
			for s in 3:
				var sy := 0.5 + s * 0.65
				v.box(Vector3(a + 0.1, sy, f - 1.75), Vector3(b - 0.1, sy + 0.04, f - 1.45), Color("6a5040"))
				var gx := a + 0.15
				while gx < b - 0.25:
					var gc := Color(["c8322b", "f2d24a", "2a6ab0", "3b8a5a", "e07a2a", "f1ede4", "8a3a8a"][_rng.randi() % 7])
					var gh := _rng.randf_range(0.15, 0.4)
					v.box(Vector3(gx, sy + 0.04, f - 1.7), Vector3(gx + 0.16, sy + 0.04 + gh, f - 1.52), gc)
					gx += _rng.randf_range(0.18, 0.3)
			v.box(Vector3(a + 0.3, 0.0, f - 0.9), Vector3(b - 0.8, 0.95, f - 0.5), Color("7a5a3a"))
			v.box(Vector3(a + 0.25, 0.95, f - 0.95), Vector3(b - 0.75, 1.0, f - 0.45), Color("9a7a5a"))
			# Warm light spilling from inside at night.
			v.use("glow/window")
			v.box(Vector3(a + 0.1, door_top - 0.12, f - 1.2), Vector3(b - 0.1, door_top - 0.06, f - 0.6), Color("fff0c8"))
			v.use("solid")
			# Rolled-up shutter box.
			v.box(Vector3(a, door_top, f - 0.05), Vector3(b, door_top + 0.25, f + 0.12), Color("8a8e96"))
			# Goods out on the pavement: crates of fruit or a drinks fridge.
			if _rng.randf() < 0.5:
				for c in 2:
					var cx := a + 0.2 + c * 0.55
					v.box(Vector3(cx, KERB_H, f + 0.2), Vector3(cx + 0.5, KERB_H + 0.3, f + 0.6), Color("b08a5a"))
					for q in 4:
						v.ball(Vector3(cx + 0.1 + (q % 2) * 0.28, KERB_H + 0.34, f + 0.3 + (q / 2) * 0.2), Vector3(0.09, 0.08, 0.09),
							Color(["f2a324", "e8c33a", "c8322b", "3b8a3a"][_rng.randi() % 4]), 6, 3)
			else:
				v.box(Vector3(b - 0.7, KERB_H, f + 0.1), Vector3(b - 0.1, KERB_H + 1.7, f + 0.6), Color("c8322b"))
				v.use("glow/sign")
				v.box(Vector3(b - 0.64, KERB_H + 0.2, f + 0.6), Vector3(b - 0.16, KERB_H + 1.5, f + 0.61), Color("d8f0ff"))
				v.use("solid")
		else:
			# Pulled-down corrugated shutter, a padlock at the foot.
			v.box(Vector3(a, 0.0, f - 0.05), Vector3(b, door_top, f + 0.04), Color("8a8e96"))
			var sy := 0.1
			while sy < door_top:
				v.box(Vector3(a, sy, f + 0.04), Vector3(b, sy + 0.03, f + 0.06), Color("6e727a"))
				sy += 0.14
			v.box(Vector3((a + b) * 0.5 - 0.05, 0.05, f + 0.06), Vector3((a + b) * 0.5 + 0.05, 0.18, f + 0.1), Color("c9a24a"))
			v.box(Vector3(a, door_top, f - 0.05), Vector3(b, door_top + 0.25, f + 0.12), Color("7a7e86"))
			# Graffiti and old posters.
			if _rng.randf() < 0.5:
				v.box(Vector3(a + 0.3, 0.8, f + 0.061), Vector3(a + 0.9, 1.4, f + 0.065), Color("e8e0c8"))
		# The sign over the shop, lit at night.
		v.box(Vector3(a - 0.05, door_top + 0.25, f), Vector3(b + 0.05, h - 0.1, f + 0.18), sign_col.darkened(0.3))
		v.use("glow/sign")
		v.box(Vector3(a + 0.02, door_top + 0.3, f + 0.18), Vector3(b - 0.02, h - 0.15, f + 0.2), sign_col)
		v.use("solid")
		var label := Label3D.new()
		label.text = SHOP_NAMES[(index * 3 + u) % SHOP_NAMES.size()]
		label.font = preload("res://assets/ui/main_theme.tres").default_font
		label.font_size = 64
		label.pixel_size = 0.0055
		label.outline_size = 0
		label.modulate = Color(1, 0.97, 0.9)
		label.position = Vector3((a + b) * 0.5, (door_top + 0.25 + h - 0.1) * 0.5, f + 0.215)
		label.shaded = false
		label.double_sided = false
		add_child(label)
		# An awning over some.
		if open and _rng.randf() < 0.5:
			var aw := Color(["2a6ab0", "c8322b", "3b8a5a", "e0a030"][_rng.randi() % 4])
			for s in 6:
				var sx := a + (b - a) * s / 6.0
				v.push_at(Vector3(sx, door_top + 0.2, f + 0.1), Vector3(-25, 0, 0))
				v.box(Vector3(0, 0, 0), Vector3((b - a) / 6.0, 0.04, 0.9), aw if s % 2 == 0 else Color("f1ede4"))
				v.pop()
	v.box(Vector3(x1 - 0.25, 0.0, f), Vector3(x1, h, f + 0.15), Color("cfc3ae"))


func _window(v: Vox, cx: float, y0: float, f: float, balcony: bool, wall: Color) -> void:
	var w := 1.1
	var h := 1.5
	var sill := y0 + 0.9
	# Frame and sill.
	v.box(Vector3(cx - w * 0.5 - 0.1, sill - 0.08, f), Vector3(cx + w * 0.5 + 0.1, sill, f + 0.12), wall.lightened(0.25))
	v.box(Vector3(cx - w * 0.5 - 0.08, sill + h, f), Vector3(cx + w * 0.5 + 0.08, sill + h + 0.1, f + 0.08), wall.lightened(0.25))
	var lit := _rng.randf() < 0.45
	if lit:
		v.use("glow/window")
		v.box(Vector3(cx - w * 0.5, sill, f - 0.12), Vector3(cx + w * 0.5, sill + h, f - 0.1),
			Color(["ffe0a0", "fff0d0", "d0e8ff", "ffd8a8"][_rng.randi() % 4]))
		v.use("solid")
		# Curtains half drawn.
		var cc := Color(["c8322b", "e0c8a8", "5a8aa8", "8a6ab0", "f1ede4"][_rng.randi() % 5])
		v.box(Vector3(cx - w * 0.5, sill + 0.1, f - 0.1), Vector3(cx - w * 0.2, sill + h, f - 0.08), cc)
		v.box(Vector3(cx + w * 0.3, sill + 0.1, f - 0.1), Vector3(cx + w * 0.5, sill + h, f - 0.08), cc)
	else:
		v.box(Vector3(cx - w * 0.5, sill, f - 0.12), Vector3(cx + w * 0.5, sill + h, f - 0.1), Color("2a2e3a"))
	v.box(Vector3(cx - 0.02, sill, f - 0.1), Vector3(cx + 0.02, sill + h, f - 0.05), wall.lightened(0.3))
	# Wooden louvred shutters, one or both folded back.
	var shutter := Color(["6a4a2a", "3a5a3a", "5a3a2a", "2a4a5a", "7a6a4a"][_rng.randi() % 5])
	for side in [-1.0, 1.0]:
		if _rng.randf() < 0.6:
			var sx: float = cx + side * (w * 0.5 + 0.28)
			v.box(Vector3(sx - 0.27, sill, f), Vector3(sx + 0.27, sill + h, f + 0.05), shutter)
			var ly := sill + 0.1
			while ly < sill + h - 0.1:
				v.box(Vector3(sx - 0.24, ly, f + 0.05), Vector3(sx + 0.24, ly + 0.04, f + 0.07), shutter.darkened(0.25))
				ly += 0.12
	if balcony:
		var bw := w + 0.9
		v.box(Vector3(cx - bw * 0.5, y0 - 0.02, f), Vector3(cx + bw * 0.5, y0 + 0.12, f + 0.9), wall.lightened(0.1))
		v.box(Vector3(cx - bw * 0.5, y0 + 0.12, f + 0.82), Vector3(cx + bw * 0.5, y0 + 1.0, f + 0.9), wall.lightened(0.15))
		for side in [-1.0, 1.0]:
			v.box(Vector3(cx + side * bw * 0.5 - 0.04, y0 + 0.12, f), Vector3(cx + side * bw * 0.5 + 0.04, y0 + 1.0, f + 0.9),
				wall.lightened(0.15))
		# Washing on a line across the balcony.
		if _rng.randf() < 0.5:
			v.box(Vector3(cx - bw * 0.5, y0 + 1.7, f + 0.8), Vector3(cx + bw * 0.5, y0 + 1.71, f + 0.81), Color("d8d8d8"))
			var lx := cx - bw * 0.45
			while lx < cx + bw * 0.4:
				var lc := Color(["c8322b", "2a6ab0", "f1ede4", "f2d24a", "3b8a5a", "e0a0b0"][_rng.randi() % 6])
				var lw := _rng.randf_range(0.2, 0.4)
				v.box(Vector3(lx, y0 + 1.2 + _rng.randf_range(0.0, 0.25), f + 0.79), Vector3(lx + lw, y0 + 1.7, f + 0.83), lc)
				lx += lw + 0.06
		# A potted plant.
		if _rng.randf() < 0.5:
			v.box(Vector3(cx + bw * 0.3, y0 + 1.0, f + 0.72), Vector3(cx + bw * 0.42, y0 + 1.14, f + 0.86), Color("b0603a"))
			v.ball(Vector3(cx + bw * 0.36, y0 + 1.26, f + 0.79), Vector3(0.12, 0.14, 0.12), Color("3e6a2e"), 6, 3)
	elif _rng.randf() < 0.55:
		# Split-unit AC under the window, dripping a stain down the wall.
		var ax := cx + _rng.randf_range(-0.3, 0.3)
		v.box(Vector3(ax - 0.4, sill - 0.65, f), Vector3(ax + 0.4, sill - 0.15, f + 0.35), Color("e8e8e4"))
		v.box(Vector3(ax - 0.3, sill - 0.6, f + 0.35), Vector3(ax + 0.3, sill - 0.2, f + 0.36), Color("b8b8b4"))
		v.box(Vector3(ax - 0.03, sill - 2.2, f), Vector3(ax + 0.03, sill - 0.65, f + 0.01), wall.darkened(0.15))

#endregion


#region Streetlights

func _lamp_points(at: Vector2, reach: float) -> Dictionary:
	var base := Vector3(at.x, KERB_H, at.y)
	var top := base + Vector3(0, POLE_H, 0)
	var head := top + Vector3(0, 0.25, reach * ARM_REACH)
	return {"base": base, "top": top, "head": head, "ground": Vector3(at.x, 0.0, at.y + reach * ARM_REACH * 1.3)}


## A Cairo street lamp: concrete foot, tapered galvanised pole, a swan-neck
## arm reaching over the road and a cobra-head sodium lantern.
func _streetlight(v: Vox, at: Vector2, reach: float) -> void:
	var g := _lamp_points(at, reach)
	var base: Vector3 = g.base
	var top: Vector3 = g.top
	var head: Vector3 = g.head
	v.box(base + Vector3(-0.17, 0, -0.17), base + Vector3(0.17, 0.22, 0.17), Color("a8a49c"))
	v.box(base + Vector3(-0.19, 0.2, -0.19), base + Vector3(0.19, 0.24, 0.19), Color("c4c0b8"))
	v.cyl(base + Vector3(0, 0.24, 0), 0.085, 0.05, POLE_H - 0.24, POLE, 8)
	for y in [0.3, 2.2]:
		v.cyl(base + Vector3(0, y, 0), 0.1, 0.1, 0.08, POLE.darkened(0.12), 8)
	v.box(base + Vector3(-0.04, 1.0, 0.07), base + Vector3(0.04, 1.3, 0.09), POLE.darkened(0.3))
	# Swan-neck arm.
	var pts: Array = []
	for k in 9:
		var t := k / 8.0
		var p0 := top
		var p1 := top + Vector3(0, 0.7, 0)
		var p2 := head + Vector3(0, 0.1, -reach * 0.3)
		pts.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	pts.append(head)
	v.sweep(Vox.circle(Vector2.ZERO, Vector2(0.035, 0.035), 6), pts, POLE.darkened(0.05))
	# Cobra head with its lens underneath.
	v.push_at(head + Vector3(0, -0.02, reach * 0.18), Vector3.ZERO)
	v.ball(Vector3.ZERO, Vector3(0.16, 0.08, 0.38), Color("9a9ea6"), 8, 3)
	v.box(Vector3(-0.1, -0.08, -0.25), Vector3(0.1, -0.06, 0.25), Color("7a7e86"))
	v.use("glow/lamp")
	v.box(Vector3(-0.08, -0.095, -0.2), Vector3(0.08, -0.075, 0.2), Color("ffd9a0"))
	v.use("solid")
	v.pop()
	var light := SpotLight3D.new()
	light.position = head + Vector3(0, -0.12, reach * 0.18)
	light.rotation_degrees = Vector3(-90, 0, 0)
	light.light_color = SODIUM
	light.spot_range = 9.5
	light.spot_angle = 55.0
	light.spot_attenuation = 1.0
	light.spot_angle_attenuation = 1.2
	light.light_energy = 0.0
	light.shadow_enabled = false
	# Only people, cars and FIFI; the ground gets the painted pool.
	light.light_cull_mask = LIT_MASK
	add_child(light)
	_lamp_lights.append(light)
	var pool := MeshInstance3D.new()
	pool.mesh = pool_mesh(Vector2(head.x, head.z + reach * 0.18), 5.6, 0.85)
	pool.material_override = _pool_mat
	pool.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(pool)
	var moths := CPUParticles3D.new()
	moths.position = head + Vector3(0, -0.2, reach * 0.18)
	moths.amount = 6
	moths.lifetime = 1.8
	moths.preprocess = 2.0
	var q := QuadMesh.new()
	q.size = Vector2(0.03, 0.03)
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.albedo_color = Color(2.2, 2.0, 1.6)
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	q.material = mm
	moths.mesh = q
	moths.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	moths.emission_sphere_radius = 0.3
	moths.gravity = Vector3.ZERO
	moths.spread = 180.0
	moths.initial_velocity_min = 0.3
	moths.initial_velocity_max = 0.7
	moths.orbit_velocity_min = 0.6
	moths.orbit_velocity_max = 1.3
	moths.emitting = false
	add_child(moths)
	_moths.append(moths)



## Glowing ground light: added on top of whatever is under it, so it reads
## as light without costing a real one. Its colour sets the brightness.
static func pool_material() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = Color(0, 0, 0, 1)
	return m


## A disc of light `radius` across, centred at (x, z) on the ground, its
## brightness falling off to nothing at the edge. It follows the street's
## levels (road, kerbs, pavements) and stops at the shopfronts.
static func pool_mesh(centre: Vector2, radius: float, core := 1.0) -> ArrayMesh:
	var cell := 0.3
	var zs: Array[float] = []
	var z := centre.y - radius
	while z < centre.y + radius:
		zs.append(z)
		z += cell
	zs.append(centre.y + radius)
	# Every level change gets two rows, one each side of the step.
	for edge in [ROAD_NEAR, ROAD_NEAR + 0.3, ROAD_FAR, ROAD_FAR - 0.3]:
		if edge > centre.y - radius and edge < centre.y + radius:
			zs.append(edge - 0.001)
			zs.append(edge + 0.001)
	zs.sort()
	var verts := PackedVector3Array()
	var cols := PackedColorArray()
	var n := ceili(radius * 2.0 / cell)
	for j in zs.size() - 1:
		var z0: float = maxf(zs[j], FACADE_Z)
		var z1: float = maxf(zs[j + 1], FACADE_Z)
		if z1 - z0 < 0.0005 and absf(_ground_y(z0) - _ground_y(z1)) < 0.01:
			continue
		for i in n:
			var x0 := centre.x - radius + i * cell
			var x1 := x0 + cell
			var corners := [Vector2(x0, z0), Vector2(x1, z0), Vector2(x1, z1), Vector2(x0, z1)]
			var a := []
			var lit := false
			for c: Vector2 in corners:
				var k := clampf(1.0 - c.distance_to(centre) / radius, 0.0, 1.0)
				k = pow(k, 1.6) * core
				a.append(k)
				lit = lit or k > 0.0
			if not lit:
				continue
			var p := []
			for c: Vector2 in corners:
				p.append(Vector3(c.x, _ground_y(c.y) + 0.02, c.y))
			for t in [[0, 2, 1], [0, 3, 2]]:
				for idx: int in t:
					verts.append(p[idx])
					cols.append(Color(1, 1, 1, a[idx]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_COLOR] = cols
	var mesh := ArrayMesh.new()
	if not verts.is_empty():
		mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


## Height of the street surface at depth z (road, kerb tops, pavements).
static func _ground_y(z: float) -> float:
	if z > ROAD_NEAR or z < ROAD_FAR:
		return KERB_H + 0.01
	return 0.0

#endregion


#region Street furniture

func _props(v: Vox) -> void:
	# An orange municipal bin, an electricity cabinet, a no-parking sign.
	var bin := Vector3(7.8, KERB_H, 2.35)
	v.cyl(bin, 0.22, 0.25, 0.8, Color("e07a2a"), 8)
	v.cyl(bin + Vector3(0, 0.8, 0), 0.27, 0.27, 0.06, Color("c8601a"), 8)
	v.box(bin + Vector3(-0.05, 0.3, 0.22), bin + Vector3(0.05, 0.6, 0.27), Color("f1ede4"))
	var cab := Vector3(10.2, KERB_H, 6.9)
	v.box(cab + Vector3(-0.45, 0, -0.2), cab + Vector3(0.45, 1.2, 0.2), Color("8a9a8a"))
	v.box(cab + Vector3(-0.42, 0.05, 0.2), cab + Vector3(-0.02, 1.15, 0.21), Color("7a8a7a"))
	v.box(cab + Vector3(0.02, 0.05, 0.2), cab + Vector3(0.42, 1.15, 0.21), Color("7a8a7a"))
	v.box(cab + Vector3(-0.1, 0.8, 0.21), cab + Vector3(0.1, 0.95, 0.215), Color("f2d24a"))
	var sign := Vector3(-4.8, KERB_H, 2.0)
	v.cyl(sign, 0.03, 0.03, 2.3, Color("9a9ea6"), 6)
	v.cyl(sign + Vector3(0, 2.3, 0), 0.25, 0.25, 0.03, Color("c8322b"), 12)
	v.push_at(sign + Vector3(0, 2.3, 0.02), Vector3(90, 0, 0))
	v.cyl(Vector3(0, 0, 0), 0.25, 0.25, 0.03, Color("c8322b"), 12)
	v.cyl(Vector3(0, 0.005, 0), 0.19, 0.19, 0.03, Color("2a6ab0"), 12)
	v.pop()
	# A tree in a pit by the kerb, its trunk painted white.
	var pit := Vector3(9.4, KERB_H, 2.6)
	v.box(pit + Vector3(-0.5, -0.02, -0.5), pit + Vector3(0.5, 0.01, 0.5), Color("5a4a38"))
	v.box(pit + Vector3(-0.55, 0, -0.55), pit + Vector3(0.55, 0.06, -0.45), Color("c4c0b8"))
	v.box(pit + Vector3(-0.55, 0, 0.45), pit + Vector3(0.55, 0.06, 0.55), Color("c4c0b8"))
	v.cyl(pit, 0.14, 0.14, 0.9, Color("ece8e0"), 6)
	_tree(v, pit, 1.1)
	# A parked motorbike up on the pavement.
	var bike := Vector3(12.0, KERB_H, 5.4)
	v.push_at(bike, Vector3(0, 20, 0))
	for x in [-0.55, 0.55]:
		v.push_at(Vector3(x, 0.28, 0), Vector3(0, 0, 90))
		v.cyl(Vector3(0, -0.04, 0), 0.28, 0.28, 0.08, Color("1a1a1f"), 10)
		v.cyl(Vector3(0, -0.05, 0), 0.14, 0.14, 0.1, Color("a8aeb8"), 8)
		v.pop()
	v.box(Vector3(-0.5, 0.45, -0.1), Vector3(0.4, 0.65, 0.1), Color("2a6ab0"))
	v.box(Vector3(-0.6, 0.65, -0.12), Vector3(0.0, 0.75, 0.12), Color("1c1c22"))
	v.rod(Vector3(0.4, 0.5, 0), Vector3(0.55, 0.95, 0), 0.03, Color("a8aeb8"))
	v.box(Vector3(0.5, 0.95, -0.3), Vector3(0.58, 0.98, 0.3), Color("1c1c22"))
	v.pop()

#endregion
