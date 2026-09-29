extends Node2D
## Isometric street view with FIFI. Emits trunk_tapped when the player taps
## the trunk. Placeholder street: FIFI parked in the kerb lane of a wide
## four-lane road, black-and-white painted kerbs, pavements both sides and
## Cairo sodium streetlights. Drawn procedurally and lit by DayClock.

signal trunk_tapped
## Five quick taps on the day/clock/money line: the hidden "start over".
signal reset_requested

const TILE_W := 128.0
const TILE_H := 64.0
## How many tiles the street bands run each way, far past any screen edge.
const EXTENT := 64
# Daylight colours; DayClock's ambient tints them through dusk and night.
const COLOR_ROAD := Color("575962")
const COLOR_ROAD_PATCH := Color("53555e")
const COLOR_LANE := Color("e8e6de")
const COLOR_KERB := Color("b9b5ae")
## Egyptian kerbs are painted in alternating black and white blocks.
const COLOR_KERB_DARK := Color("2c2c31")
const COLOR_KERB_LIGHT := Color("e6e3dc")
const COLOR_STONE_A := Color("a29d97")
const COLOR_STONE_B := Color("99948e")
const COLOR_GROUT := Color("807b76")
## Grid rows given over to the kerb and pavement on FIFI's passenger side
## (KERB_ROW and beyond) and across the road (FAR_KERB_ROW and before):
## fourteen rows of asphalt, about four lanes, with FIFI in the kerb lane.
const KERB_ROW := 3
const FAR_KERB_ROW := -12
## Dashed lane lines, as rows along the street.
const LANE_LINES := [-1.25, -4.75, -8.25]
## How far the kerbs and pavements stand above the road, in screen pixels.
const PAVEMENT_RISE := 10.4
## Streetlights are galvanised silver from foot to lantern.
const COLOR_POLE := Color("a9adb5")
const COLOR_POLE_SHINE := Color("e9ecf1")
const COLOR_HEAD := Color("9a9ea6")
const COLOR_SODIUM := Color("ffa94d")
## Streetlights along the kerb edges: where each stands (tile coords) and which
## way its arm reaches over the road (-1 toward -j, +1 toward +j).
const STREETLIGHTS := [[Vector2(-3, 3.75), -1.0], [Vector2(9, 3.75), -1.0], [Vector2(-6, -12.75), 1.0]]
const POLE_H := 260.0
## How far each arm reaches out over the road, in tiles.
const ARM_REACH := 1.25
## The street sits a little left of centre so FIFI and the customers pulled
## up behind and beside her all fit on a phone screen.
const VIEW_SHIFT := Vector2(-170, 0)

var interactive := true

var _pulse_t := 0.0
var _soft := StationArt._make_soft_texture()
## Per streetlight: the real 2D light on the road, and the moths and dust
## in its beam. Switched on and scaled with DayClock's darkness.
var _lamp_lights: Array[PointLight2D] = []
var _lamp_moths: Array[CPUParticles2D] = []
var _lamp_dust: Array[CPUParticles2D] = []
var _traffic := Traffic.new()
var _m: MeshCanvas
var _street_mesh: ArrayMesh
var _lamp_mesh: ArrayMesh
var _furniture := SidewalkFurniture.new()
## Customers walking up to the trunk; main.gd drives the orders.
var queue := CustomerQueue.new()

@onready var fifi: Node2D = $FIFISprite
@onready var trunk_area: Area2D = $TrunkArea
@onready var trunk_shape: CollisionPolygon2D = $TrunkArea/TrunkShape
@onready var hint_label: Label = $HintLabel
@onready var wallet_label: Label = $WalletLabel


func _ready() -> void:
	# Area2D taps need physics picking on the viewport.
	get_viewport().physics_object_picking = true
	trunk_shape.polygon = fifi.get_trunk_polygon()
	trunk_area.position = fifi.position
	trunk_area.input_event.connect(_on_trunk_input_event)
	# The labels are UI, not scenery: keep the streetlights off them.
	hint_label.light_mask = 0
	wallet_label.light_mask = 0
	# The labels stay centred on screen, not on the shifted street.
	for label in [hint_label, wallet_label]:
		label.position.x -= VIEW_SHIFT.x
	wallet_label.mouse_filter = Control.MOUSE_FILTER_STOP
	wallet_label.gui_input.connect(_on_wallet_input)
	for lamp in STREETLIGHTS:
		_build_lamp_effects(lamp[0], lamp[1])
	# Passing traffic drives in the lanes behind FIFI, so it goes under her.
	add_child(_traffic)
	move_child(_traffic, 0)
	# Sayed's chairs stand on the pavement, nearer us than FIFI.
	_furniture.position = fifi.position
	fifi.add_sibling(_furniture)
	# Customers stand on the pavement, in front of FIFI and the chair.
	_furniture.add_sibling(queue)
	queue.traffic = _traffic
	Economy.currency_changed.connect(_pop_wallet.unbind(1))
	get_viewport().size_changed.connect(_recenter)
	Economy.currency_changed.connect(_update_wallet.unbind(1))
	DayClock.minute_changed.connect(_relight)
	_recenter()
	_relight()


func _process(delta: float) -> void:
	_pulse_t += delta
	fifi.trunk_glow = (0.3 + 0.7 * (sin(_pulse_t * 3.0) * 0.5 + 0.5)) if interactive else 0.0


## Screen rect round the trunk's tap area, for the tutorial's spotlight.
func trunk_screen_rect() -> Rect2:
	var xf := trunk_shape.get_global_transform()
	var r := Rect2(xf * trunk_shape.polygon[0], Vector2.ZERO)
	for p in trunk_shape.polygon:
		r = r.expand(xf * p)
	return r


## The line of guidance under FIFI ("tap the trunk", "serve the customer"...).
func set_hint(text: String) -> void:
	hint_label.text = text


func set_interactive(value: bool) -> void:
	interactive = value
	hint_label.visible = value


func _recenter() -> void:
	position = get_viewport_rect().size * 0.5 + VIEW_SHIFT


func _relight() -> void:
	var dark := DayClock.darkness()
	fifi.ambient = DayClock.ambient()
	fifi.darkness = dark
	_furniture.ambient = DayClock.ambient()
	queue.modulate = Color.WHITE.lerp(DayClock.ambient(), 0.8)
	_traffic.set_light(DayClock.ambient(), dark)
	for light in _lamp_lights:
		light.energy = 1.25 * dark
		light.visible = dark > 0.01
	for p in _lamp_moths + _lamp_dust:
		p.emitting = dark > 0.4
	_update_wallet()
	queue_redraw()


## A quick bounce on the wallet whenever the money changes.
func _pop_wallet() -> void:
	wallet_label.pivot_offset = wallet_label.size * 0.5
	var t := create_tween()
	t.tween_property(wallet_label, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(wallet_label, "scale", Vector2.ONE, 0.25)


func _update_wallet() -> void:
	wallet_label.text = "%s   ·   %s   ·   %s" % [
		tr("UI_DAY").format({"day": GameData.ar_digits(Economy.day_number)}),
		DayClock.clock_text(),
		tr("UI_WALLET").format({"amount": GameData.ar_digits(Economy.currency_egp)}),
	]


func _on_trunk_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not interactive or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		trunk_tapped.emit()


func _draw() -> void:
	_m = MeshCanvas.new()
	var amb := DayClock.ambient()
	var dark := DayClock.darkness()
	var rise := Vector2(0, -PAVEMENT_RISE)
	# Asphalt: one long band with a few darker patches and dashed lane lines.
	_m.colored_polygon(_band(FAR_KERB_ROW + 1, KERB_ROW - 1, Vector2.ZERO), COLOR_ROAD * amb)
	# Resurfaced patches: a few overlapping blobs each, so they read as repairs, not holes.
	for patch in [Vector3(-6, -3, 1.4), Vector3(4, -9, 1.0), Vector3(12, -2, 1.8), Vector3(-2, -6.5, 0.8)]:
		for k in 3:
			var c := _point(patch.x + (k - 1) * 0.5 * patch.z, patch.y + sin(k * 2.3) * 0.3)
			_ground_ellipse(c, Vector2(patch.z * (40.0 + k * 9.0), patch.z * (20.0 + k * 4.0)), COLOR_ROAD_PATCH * amb)
	var dashes := PackedVector2Array()
	for v in LANE_LINES:
		for u in range(-EXTENT, EXTENT, 3):
			dashes.append(_point(u, v))
			dashes.append(_point(u + 1.3, v))
	_m.multiline(dashes, Color(COLOR_LANE, 0.75) * amb, 3.0)
	# A manhole cover in the lane beside FIFI.
	_ground_ellipse(_point(-5.5, -0.5), Vector2(34, 17), Color("3c3d43") * amb)
	_ground_ellipse(_point(-5.5, -0.5), Vector2(26, 13), Color("45464d") * amb)
	# Far pavement and kerb (its road-facing side faces us), then the near ones.
	_m.colored_polygon(_band(-EXTENT, FAR_KERB_ROW - 1, rise), COLOR_STONE_A * amb)
	_draw_seams(-EXTENT, FAR_KERB_ROW - 1, rise, COLOR_GROUT * amb, 2.0)
	_draw_kerb(FAR_KERB_ROW, true, amb)
	_draw_kerb(KERB_ROW, false, amb)
	_m.colored_polygon(_band(KERB_ROW + 1, EXTENT, rise), COLOR_STONE_B * amb)
	_draw_seams(KERB_ROW + 1, EXTENT, rise, COLOR_GROUT * amb, 2.0)
	# The street and the lamp posts are baked into two meshes (one draw call
	# each), with the textured light pools and glows drawn between and after.
	_street_mesh = _m.commit()
	draw_mesh(_street_mesh, null)
	for light in STREETLIGHTS:
		_draw_light_pool(light[0], light[1], dark)
	_m = MeshCanvas.new()
	for light in STREETLIGHTS:
		_draw_streetlight(light[0], light[1], amb, dark)
	_lamp_mesh = _m.commit()
	_m = null
	draw_mesh(_lamp_mesh, null)
	for light in STREETLIGHTS:
		_draw_lamp_glow(light[0], light[1], amb, dark)


## Kerb row j, painted in alternating black and white blocks along the street;
## `face` also draws its road-facing side, when that side faces the camera.
func _draw_kerb(j: int, face: bool, amb: Color) -> void:
	var rise := Vector2(0, -PAVEMENT_RISE)
	var near := j + 0.5 if face else j - 0.5
	for u in range(-EXTENT, EXTENT):
		var col := (COLOR_KERB_DARK if posmod(u, 2) == 0 else COLOR_KERB_LIGHT) * amb
		_m.colored_polygon(PackedVector2Array([_point(u - 0.5, j - 0.5) + rise, _point(u + 0.5, j - 0.5) + rise,
			_point(u + 0.5, j + 0.5) + rise, _point(u - 0.5, j + 0.5) + rise]), col)
		if face:
			_m.colored_polygon(PackedVector2Array([_point(u - 0.5, near) + rise, _point(u + 0.5, near) + rise,
				_point(u + 0.5, near), _point(u - 0.5, near)]), col.darkened(0.3))
	var e := float(EXTENT)
	_m.line(_point(-e, near) + rise, _point(e, near) + rise, Color(1, 1, 1, 0.12) * amb, 2.0)


## Rows j0..j1 as one strip running EXTENT tiles each way along the street.
func _band(j0: int, j1: int, offset: Vector2) -> PackedVector2Array:
	var e := float(EXTENT)
	return PackedVector2Array([_point(-e, j0 - 0.5) + offset, _point(e, j0 - 0.5) + offset,
		_point(e, j1 + 0.5) + offset, _point(-e, j1 + 0.5) + offset])


## Slab joints for rows j0..j1: one line per tile edge, not an outline per tile.
func _draw_seams(j0: int, j1: int, offset: Vector2, color: Color, width: float) -> void:
	var lines := PackedVector2Array()
	for i in range(-EXTENT, EXTENT + 1):
		lines.append(_point(i - 0.5, j0 - 0.5) + offset)
		lines.append(_point(i - 0.5, j1 + 0.5) + offset)
	for j in range(j0, j1 + 2):
		lines.append(_point(-EXTENT, j - 0.5) + offset)
		lines.append(_point(EXTENT, j - 0.5) + offset)
	_m.multiline(lines, color, width)


## Screen position of a point in tile coordinates (tile centres at integers).
func _point(u: float, v: float) -> Vector2:
	return Vector2((u - v) * TILE_W * 0.5, (u + v) * TILE_H * 0.5)


## Where a streetlight's head hangs, and the patch of road under it.
func _lamp_geometry(at: Vector2, reach: float) -> Dictionary:
	var base := _point(at.x, at.y) + Vector2(0, -PAVEMENT_RISE)
	var out := _point(0, reach * ARM_REACH) - _point(0, 0)
	var top := base + Vector2(0, -POLE_H)
	return {"base": base, "top": top, "head": top + out + Vector2(0, -8), "dir": out.normalized(),
		"ground": _point(at.x, at.y + reach * ARM_REACH)}


## After dusk: the cone of sodium light under the head and its pool on the road.
func _draw_light_pool(at: Vector2, reach: float, dark: float) -> void:
	if dark <= 0.01:
		return
	var g := _lamp_geometry(at, reach)
	var ground: Vector2 = g.ground
	var head: Vector2 = g.head
	# The light itself is a PointLight2D; this is just the haze where the beam lands.
	draw_texture_rect(_soft, Rect2(ground - Vector2(150, 75), Vector2(300, 150)), false, Color(COLOR_SODIUM, 0.14 * dark))
	var lens := head + Vector2(0, 6)
	draw_polygon(PackedVector2Array([lens + Vector2(-10, 0), lens + Vector2(10, 0), ground + Vector2(110, 0), ground + Vector2(-110, 0)]),
		PackedColorArray([Color(COLOR_SODIUM, 0.22 * dark), Color(COLOR_SODIUM, 0.22 * dark),
			Color(COLOR_SODIUM, 0.0), Color(COLOR_SODIUM, 0.0)]))


## A Cairo street lamp: concrete foot, tapered all-silver galvanised pole, a
## swan-neck arm reaching over the road and a cobra-head sodium lantern.
func _draw_streetlight(at: Vector2, reach: float, amb: Color, dark: float) -> void:
	var g := _lamp_geometry(at, reach)
	var base: Vector2 = g.base
	var top: Vector2 = g.top
	var head: Vector2 = g.head
	var dir: Vector2 = g.dir
	# Foundation block and the pole, lit from the left.
	_ground_ellipse(base + Vector2(0, 2), Vector2(16, 8), Color(0, 0, 0, 0.25))
	_m.rect(Rect2(base + Vector2(-10, -10), Vector2(20, 10)), Color("a8a49c") * amb)
	_m.rect(Rect2(base + Vector2(-10, -10), Vector2(20, 3)), Color("c4c0b8") * amb)
	var hb := 5.5
	var ht := 3.0
	var y0 := base.y - 10.0
	_m.colored_polygon(PackedVector2Array([Vector2(base.x - hb, y0), Vector2(base.x, y0), Vector2(top.x, top.y),
		Vector2(top.x - ht, top.y)]), COLOR_POLE.lightened(0.15) * amb)
	_m.colored_polygon(PackedVector2Array([Vector2(base.x, y0), Vector2(base.x + hb, y0), Vector2(top.x + ht, top.y),
		Vector2(top.x, top.y)]), COLOR_POLE.darkened(0.2) * amb)
	# Specular streak down the lit side, and collars where the sections join.
	_m.line(Vector2(base.x - hb * 0.45, y0), Vector2(top.x - ht * 0.45, top.y), COLOR_POLE_SHINE * amb, 1.2)
	for ya in [y0 - 4.0, y0 - 100.0]:
		var w := lerpf(hb, ht, (y0 - ya) / (y0 - top.y)) + 1.0
		_m.rect(Rect2(base.x - w, ya - 4.0, w * 2.0, 4.0), COLOR_POLE.darkened(0.12) * amb)
		_m.line(Vector2(base.x - w, ya - 4.0), Vector2(base.x + w, ya - 4.0), COLOR_POLE_SHINE * amb, 1.0)
	# Access hatch low on the pole.
	_m.rect(Rect2(base.x - 2.5, y0 - 70, 5, 12), COLOR_POLE.darkened(0.3) * amb)
	# Swan-neck arm: up off the pole top, curving out over the road.
	var arm := PackedVector2Array()
	var c1 := top + Vector2(0, -34)
	var c2 := head + Vector2(-dir.x * 18.0, -10)
	for k in 13:
		var t := k / 12.0
		arm.append(top.lerp(c1, t).lerp(c1.lerp(c2, t), t).lerp(c1.lerp(c2, t).lerp(c2.lerp(head, t), t), t))
	_m.polyline(arm, COLOR_POLE.darkened(0.1) * amb, 4.5, true)
	_m.polyline(arm, COLOR_POLE.lightened(0.25) * amb, 1.5, true)
	_m.circle(top + Vector2(0, -3), 4.0, COLOR_POLE * amb)
	# Cobra head: a long rounded shell along the arm, glowing lens underneath.
	var side := Vector2(-dir.y, dir.x)
	if side.y < 0.0:
		side = -side
	var shell := PackedVector2Array()
	for k in 14:
		var a := TAU * k / 14.0
		shell.append(head + dir * (cos(a) * 20.0 + 6.0) + side * sin(a) * 7.0 + Vector2(0, -2))
	_m.colored_polygon(shell, COLOR_HEAD * amb)
	_m.line(head + dir * -8.0 + Vector2(0, -6), head + dir * 20.0 + Vector2(0, -6), COLOR_HEAD.lightened(0.35) * amb, 2.0)


## The lantern's lens and its bloom after dusk: drawn after the baked meshes,
## unbaked so the lens keeps its brighter-than-white glow colour.
func _draw_lamp_glow(at: Vector2, reach: float, amb: Color, dark: float) -> void:
	var g := _lamp_geometry(at, reach)
	var head: Vector2 = g.head
	var dir: Vector2 = g.dir
	var lens := PackedVector2Array([head + dir * -8.0 + Vector2(0, 2), head + dir * 20.0 + Vector2(0, 2),
		head + dir * 16.0 + Vector2(0, 6), head + dir * -4.0 + Vector2(0, 6)])
	draw_colored_polygon(lens, (Color("d8d4c8") * amb).lerp(StationArt.hdr(COLOR_SODIUM.lightened(0.5), 3.0), dark))
	if dark > 0.01:
		var glow := head + dir * 6.0 + Vector2(0, 6)
		draw_texture_rect(_soft, Rect2(glow - Vector2(60, 60), Vector2(120, 120)), false, Color(COLOR_SODIUM, 0.45 * dark))
		draw_texture_rect(_soft, Rect2(glow - Vector2(22, 22), Vector2(44, 44)), false,
			StationArt.hdr(Color(1.0, 0.92, 0.75, 0.8 * dark), 2.2))


## A streetlight's real light (squashed to lie flat on the road), a few moths
## circling the lantern and dust drifting down its beam.
func _build_lamp_effects(at: Vector2, reach: float) -> void:
	var g := _lamp_geometry(at, reach)
	var light := PointLight2D.new()
	light.texture = _light_texture()
	light.texture_scale = 2.4
	light.scale = Vector2(1.0, 0.5)
	light.position = g.ground
	light.color = COLOR_SODIUM
	light.energy = 0.0
	add_child(light)
	_lamp_lights.append(light)
	var moths := CPUParticles2D.new()
	moths.position = g.head + Vector2(0, 8)
	moths.amount = 6
	moths.lifetime = 1.8
	moths.preprocess = 2.0
	moths.texture = _soft
	moths.emission_shape = CPUParticles2D.EMISSION_SHAPE_SPHERE
	moths.emission_sphere_radius = 16.0
	moths.gravity = Vector2.ZERO
	moths.spread = 180.0
	moths.initial_velocity_min = 18.0
	moths.initial_velocity_max = 40.0
	moths.orbit_velocity_min = 0.6
	moths.orbit_velocity_max = 1.3
	moths.scale_amount_min = 0.05
	moths.scale_amount_max = 0.08
	moths.color = StationArt.hdr(Color(1.0, 0.93, 0.8, 0.9), 1.6)
	moths.emitting = false
	add_child(moths)
	_lamp_moths.append(moths)
	var dust := CPUParticles2D.new()
	dust.position = g.head.lerp(g.ground, 0.55)
	dust.amount = 14
	dust.lifetime = 5.0
	dust.preprocess = 5.0
	dust.texture = _soft
	dust.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	dust.emission_rect_extents = Vector2(55, 70)
	dust.gravity = Vector2(0, 3)
	dust.direction = Vector2(1, 0)
	dust.spread = 180.0
	dust.initial_velocity_min = 2.0
	dust.initial_velocity_max = 6.0
	dust.scale_amount_min = 0.03
	dust.scale_amount_max = 0.05
	var fade := Gradient.new()
	fade.set_color(0, Color(COLOR_SODIUM, 0.0))
	fade.add_point(0.5, Color(COLOR_SODIUM.lightened(0.4), 0.6))
	fade.set_color(fade.get_point_count() - 1, Color(COLOR_SODIUM, 0.0))
	dust.color_ramp = fade
	dust.emitting = false
	add_child(dust)
	_lamp_dust.append(dust)


static func _light_texture() -> GradientTexture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color.WHITE)
	gradient.add_point(0.45, Color(1, 1, 1, 0.45))
	gradient.set_color(gradient.get_point_count() - 1, Color(1, 1, 1, 0))
	var tex := GradientTexture2D.new()
	tex.gradient = gradient
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(1.0, 0.5)
	tex.width = 256
	tex.height = 256
	return tex


## Flat ellipse lying on the ground (already squashed 2:1 for the view).
func _ground_ellipse(c: Vector2, r: Vector2, color: Color) -> void:
	var pts := PackedVector2Array()
	for k in 20:
		var a := TAU * k / 20.0
		pts.append(c + Vector2(cos(a) * r.x, sin(a) * r.y))
	_m.colored_polygon(pts, color)


var _wallet_taps := 0
var _wallet_tap_at := 0


func _on_wallet_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now := Time.get_ticks_msec()
	_wallet_taps = _wallet_taps + 1 if now - _wallet_tap_at < 600 else 1
	_wallet_tap_at = now
	if _wallet_taps >= 5:
		_wallet_taps = 0
		reset_requested.emit()
