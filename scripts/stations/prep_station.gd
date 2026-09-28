extends Control
## Flat "Right Mix" prep station. Shows the order, routes it to the matching
## gauge, pays out tips, then reports back to main via prep_complete.

signal prep_complete(result: Dictionary)

@export var result_hold_sec := 1.4

var _item: Dictionary = {}

@onready var order_display: Label = %OrderDisplay
@onready var heat_gauge: HeatGauge = %HeatGauge
@onready var blend_gauge: BlendGauge = %BlendGauge
@onready var espresso_slot: Control = %EspressoSlot
@onready var espresso_label: Label = %EspressoLabel
@onready var result_label: Label = %ResultLabel
@onready var backdrop: TrunkBackdrop = %Backdrop


func _ready() -> void:
	for gauge in [heat_gauge, blend_gauge]:
		gauge.gauge_completed.connect(_on_gauge_completed)
	heat_gauge.gauge_failed.connect(_on_gauge_failed)
	DayClock.minute_changed.connect(_relight)
	_refresh_espresso()
	_relight()


## Shows the order and resets gauges without starting the clock
## (called while the screen is still fading in).
func load_order(item_id: String) -> bool:
	_item = GameData.get_menu_item(item_id)
	if _item.is_empty():
		push_error("PrepStation: unknown menu item '%s'" % item_id)
		return false
	order_display.text = tr(_item.get("name_key", "")) if _item.has("name_key") else _item.get("name_ar", item_id)
	result_label.text = ""
	var active := _gauge_for(_item.get("station", ""))
	for gauge in [heat_gauge, blend_gauge]:
		gauge.reset()
		gauge.visible = gauge == active
	if active:
		active.call("set_look", _item.get("look", {}))
	return active != null


## Starts the loaded order's gauge.
func start_order() -> void:
	var gauge := _gauge_for(_item.get("station", ""))
	if gauge:
		gauge.start(float(_item.get("prep_time_sec", 10)))


## Keeps the car drawn round the station art: carpet, sill and trunk sides
## follow wherever the active gauge's art sits on screen.
func _process(_delta: float) -> void:
	var art: StationArt = blend_gauge.blender if blend_gauge.visible else heat_gauge.stove
	var inv := backdrop.get_global_transform().affine_inverse()
	var rect := art.get_global_rect()
	backdrop.set_frame(
		(inv * art.scene_to_global(Vector2(0, StationArt.COUNTER_Y - 8.0))).y,
		(inv * art.scene_to_global(Vector2(0, StationArt.SILL_Y))).y,
		Vector2((inv * rect.position).x, (inv * rect.end).x),
		art.get_global_transform().get_scale().x * art._scene_scale())


## The car's paintwork follows the time of day; its LEDs and the kit don't.
func _relight() -> void:
	backdrop.self_modulate = Color.WHITE.lerp(DayClock.ambient(), 0.5)


func _gauge_for(station: String) -> Control:
	match station:
		"heat":
			return heat_gauge
		"blend":
			return blend_gauge
	push_error("PrepStation: no gauge for station '%s'" % station)
	return null


func _on_gauge_completed(accuracy: float) -> void:
	var price := GameData.price_for(_item.id, Economy.current_venue_tier)
	var tips := maxi(1, roundi(price * accuracy))
	Economy.add_tips(tips)
	var headline := tr("RESULT_SUCCESS") if accuracy >= 1.0 else tr("RESULT_OK")
	result_label.text = "%s\n%s" % [headline, tr("RESULT_TIPS").format({"amount": GameData.ar_digits(tips)})]
	_finish({"success": true, "item_id": _item.id, "accuracy": accuracy, "tips": tips})


func _on_gauge_failed() -> void:
	result_label.text = tr("RESULT_FAIL")
	_finish({"success": false, "item_id": _item.id, "accuracy": 0.0, "tips": 0})


func _finish(result: Dictionary) -> void:
	await get_tree().create_timer(result_hold_sec).timeout
	prep_complete.emit(result)


func _refresh_espresso() -> void:
	var unlocked := Economy.owns("espresso_basic")
	espresso_slot.modulate.a = 1.0 if unlocked else 0.55
	if not unlocked:
		var cost := int(GameData.get_equipment("espresso_basic").get("cost_egp", 0))
		espresso_label.text = "🔒 %s · %s %s" % [tr("PREP_ESPRESSO_LOCKED"), GameData.ar_digits(cost), tr("UI_CURRENCY")]
