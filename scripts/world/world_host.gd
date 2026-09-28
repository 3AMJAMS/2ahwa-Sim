extends Node2D
## Isometric street view with FIFI. Emits trunk_tapped when the player taps
## the trunk. Placeholder street (asphalt, kerbs and pavements both sides,
## streetlights, string lights) is drawn procedurally and lit by DayClock.

signal trunk_tapped

const TILE_W := 128.0
const TILE_H := 64.0
## How many tiles the street bands run each way, far past any screen edge.
const EXTENT := 64
# Daylight colours; DayClock's ambient tints them through dusk and night.
const COLOR_ROAD_A := Color("595b66")
const COLOR_ROAD_B := Color("545661")
const COLOR_ROAD_SEAM := Color("4a4c57")
const COLOR_KERB := Color("b9b5ae")
const COLOR_STONE_A := Color("a29d97")
const COLOR_STONE_B := Color("99948e")
const COLOR_GROUT := Color("807b76")
## Grid rows given over to the kerb and pavement on FIFI's passenger side
## (KERB_ROW and beyond) and across the road (FAR_KERB_ROW and before).
const KERB_ROW := 3
const FAR_KERB_ROW := -4
## How far the kerbs and pavements stand above the road, in screen pixels.
const PAVEMENT_RISE := 10.4
const COLOR_BULB := Color("ffc861")
const COLOR_BULB_OFF := Color("6b6250")
const COLOR_WIRE := Color("0e1022")
const COLOR_POLE := Color("4a4a54")
const COLOR_LAMP := Color("ffb45a")
## Streetlights: the tile each stands on, and which way its arm reaches (toward the road).
const STREETLIGHTS := [[Vector2i(-2, 5), -1.0], [Vector2i(2, -6), 1.0]]
const POLE_H := 250.0

var interactive := true

var _pulse_t := 0.0

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
	get_viewport().size_changed.connect(_recenter)
	Economy.currency_changed.connect(_update_wallet.unbind(1))
	DayClock.minute_changed.connect(_relight)
	_recenter()
	_relight()


func _process(delta: float) -> void:
	_pulse_t += delta
	fifi.trunk_glow = (0.3 + 0.7 * (sin(_pulse_t * 3.0) * 0.5 + 0.5)) if interactive else 0.0


func set_interactive(value: bool) -> void:
	interactive = value
	hint_label.visible = value


func _recenter() -> void:
	position = get_viewport_rect().size * 0.5


func _relight() -> void:
	fifi.ambient = DayClock.ambient()
	fifi.darkness = DayClock.darkness()
	_update_wallet()
	queue_redraw()


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
	var amb := DayClock.ambient()
	var dark := DayClock.darkness()
	var rise := Vector2(0, -PAVEMENT_RISE)
	var e := float(EXTENT)
	# Road, then both raised kerb-and-pavement strips, each one long band
	# running off-screen, with the slab joints drawn as lines across it.
	draw_colored_polygon(_band(FAR_KERB_ROW + 1, KERB_ROW - 1, Vector2.ZERO), COLOR_ROAD_A * amb)
	_draw_seams(FAR_KERB_ROW + 1, KERB_ROW - 1, Vector2.ZERO, COLOR_ROAD_SEAM * amb, 1.0)
	draw_colored_polygon(_band(-EXTENT, FAR_KERB_ROW - 1, rise), COLOR_STONE_A * amb)
	_draw_seams(-EXTENT, FAR_KERB_ROW - 1, rise, COLOR_GROUT * amb, 2.0)
	draw_colored_polygon(_band(FAR_KERB_ROW, FAR_KERB_ROW, rise), COLOR_KERB * amb)
	var edge := FAR_KERB_ROW + 0.5
	draw_colored_polygon(PackedVector2Array([_point(-e, edge) + rise, _point(e, edge) + rise, _point(e, edge), _point(-e, edge)]),
		COLOR_KERB.darkened(0.3) * amb)
	draw_colored_polygon(_band(KERB_ROW, KERB_ROW, rise), COLOR_KERB * amb)
	draw_line(_point(-e, KERB_ROW - 0.5) + rise, _point(e, KERB_ROW - 0.5) + rise, COLOR_KERB.lightened(0.2) * amb, 2.0)
	draw_colored_polygon(_band(KERB_ROW + 1, EXTENT, rise), COLOR_STONE_B * amb)
	_draw_seams(KERB_ROW + 1, EXTENT, rise, COLOR_GROUT * amb, 2.0)
	for light in STREETLIGHTS:
		_draw_streetlight(light[0], light[1], amb, dark)
	# String-light canopy: one sagging wire with warm bulbs, lit after dusk.
	var a := Vector2(-520, -430)
	var b := Vector2(520, -330)
	var points := PackedVector2Array()
	for k in 25:
		var t := k / 24.0
		points.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 90.0))
	draw_polyline(points, COLOR_WIRE, 3.0, true)
	for k in range(1, 24, 2):
		draw_circle(points[k] + Vector2(0, 10), 16, Color(COLOR_BULB, 0.18 * dark))
		draw_circle(points[k] + Vector2(0, 10), 7, COLOR_BULB_OFF.lerp(COLOR_BULB, dark))


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
	draw_multiline(lines, color, width)


## Screen position of a point in tile coordinates (tile centres at integers).
func _point(u: float, v: float) -> Vector2:
	return Vector2((u - v) * TILE_W * 0.5, (u + v) * TILE_H * 0.5)


## A Cairo street lamp: concrete foot, tall pole, arm reaching over the road,
## sodium head; after dusk a warm pool on the ground below and a halo.
func _draw_streetlight(tile: Vector2i, reach: float, amb: Color, dark: float) -> void:
	var base := _point(tile.x, tile.y) + Vector2(0, -PAVEMENT_RISE)
	# Reaching toward -j (reach -1) runs up-right on screen, toward +j down-left.
	var arm := Vector2(-TILE_W * 0.5, TILE_H * 0.5) * -reach * 0.9
	var top := base + Vector2(0, -POLE_H)
	var head := top + arm + Vector2(0, 10)
	if dark > 0.0:
		var pool := base + arm
		draw_set_transform(pool, 0.0, Vector2(1.0, 0.5))
		draw_circle(Vector2.ZERO, 120, Color(COLOR_LAMP, 0.1 * dark))
		draw_circle(Vector2.ZERO, 70, Color(COLOR_LAMP, 0.12 * dark))
		draw_set_transform(Vector2.ZERO)
	draw_rect(Rect2(base + Vector2(-9, -12), Vector2(18, 12)), COLOR_KERB.darkened(0.2) * amb)
	draw_line(base, top, COLOR_POLE * amb, 7.0)
	draw_polyline(PackedVector2Array([top, top + arm * 0.35 + Vector2(0, -14), head + Vector2(0, -6)]), COLOR_POLE * amb, 5.0, true)
	draw_colored_polygon(PackedVector2Array([head + Vector2(-16, -4), head + Vector2(16, -4), head + Vector2(10, 6),
		head + Vector2(-10, 6)]), (Color("5a5a64") * amb).lerp(COLOR_LAMP.lightened(0.4), dark))
	if dark > 0.0:
		draw_circle(head + Vector2(0, 6), 34, Color(COLOR_LAMP, 0.16 * dark))
		draw_circle(head + Vector2(0, 6), 16, Color(COLOR_LAMP, 0.3 * dark))
