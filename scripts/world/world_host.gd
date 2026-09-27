extends Node2D
## Isometric street view with FIFI. Emits trunk_tapped when the player taps
## the trunk. Placeholder street + string lights are drawn procedurally.

signal trunk_tapped

const TILE_W := 128.0
const TILE_H := 64.0
const GRID_RADIUS := 7
const COLOR_STONE_A := Color("3b3d52")
const COLOR_STONE_B := Color("34364a")
const COLOR_GROUT := Color("26283a")
const COLOR_BULB := Color("ffc861")
const COLOR_WIRE := Color("0e1022")

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
	_recenter()
	_update_wallet()


func _process(delta: float) -> void:
	_pulse_t += delta
	fifi.trunk_glow = (sin(_pulse_t * 3.0) * 0.5 + 0.5) if interactive else 0.0


func set_interactive(value: bool) -> void:
	interactive = value
	hint_label.visible = value


func _recenter() -> void:
	position = get_viewport_rect().size * 0.5


func _update_wallet() -> void:
	wallet_label.text = "%s   ·   %s" % [
		tr("UI_DAY").format({"day": GameData.ar_digits(Economy.day_number)}),
		tr("UI_WALLET").format({"amount": GameData.ar_digits(Economy.currency_egp)}),
	]


func _on_trunk_input_event(_viewport: Node, event: InputEvent, _shape_idx: int) -> void:
	if not interactive or not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		trunk_tapped.emit()


func _draw() -> void:
	# Pavement: 2:1 diamond tiles centred on the stand.
	for i in range(-GRID_RADIUS, GRID_RADIUS + 1):
		for j in range(-GRID_RADIUS, GRID_RADIUS + 1):
			var c := Vector2((i - j) * TILE_W * 0.5, (i + j) * TILE_H * 0.5)
			var diamond := PackedVector2Array([
				c + Vector2(0, -TILE_H * 0.5), c + Vector2(TILE_W * 0.5, 0),
				c + Vector2(0, TILE_H * 0.5), c + Vector2(-TILE_W * 0.5, 0)])
			draw_colored_polygon(diamond, COLOR_STONE_A if (i + j) % 2 == 0 else COLOR_STONE_B)
			diamond.append(diamond[0])
			draw_polyline(diamond, COLOR_GROUT, 2.0)
	# String-light canopy: one sagging wire with warm bulbs.
	var a := Vector2(-520, -430)
	var b := Vector2(520, -330)
	var points := PackedVector2Array()
	for k in 25:
		var t := k / 24.0
		points.append(a.lerp(b, t) + Vector2(0, sin(t * PI) * 90.0))
	draw_polyline(points, COLOR_WIRE, 3.0, true)
	for k in range(1, 24, 2):
		draw_circle(points[k] + Vector2(0, 10), 16, Color(COLOR_BULB, 0.18))
		draw_circle(points[k] + Vector2(0, 10), 7, COLOR_BULB)
