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
	heat_gauge.boiled_over.connect(_jolt.bind(16.0, 0.45, 160))
	blend_gauge.motor_tripped.connect(_jolt.bind(9.0, 0.3, 80))
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
	backdrop.idle_station = "heat" if active == blend_gauge else "blend"
	return active != null


## Starts the loaded order's gauge.
func start_order() -> void:
	var gauge := _gauge_for(_item.get("station", ""))
	if gauge:
		gauge.start(float(_item.get("prep_time_sec", 10)))


## Keeps the car drawn round the station art: carpet, sill and trunk sides
## follow wherever the active gauge's art sits on screen.
func _process(_delta: float) -> void:
	var art := _active_art()
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
	_celebrate(tips, accuracy >= 1.0)
	_finish({"success": true, "item_id": _item.id, "accuracy": accuracy, "tips": tips})


func _on_gauge_failed() -> void:
	result_label.text = tr("RESULT_FAIL")
	_finish({"success": false, "item_id": _item.id, "accuracy": 0.0, "tips": 0})


## Payday feedback at the glass: a burst of gold sparks and the tip floating
## up; a perfect brew gets a bigger burst and a short buzz.
func _celebrate(tips: int, perfect: bool) -> void:
	var car := backdrop.get_parent() as Control
	var at := car.get_global_transform().affine_inverse() * _active_art().scene_to_global(Vector2(250, 440))
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 36 if perfect else 18
	sparks.lifetime = 0.9
	sparks.texture = StationArt._make_soft_texture()
	sparks.spread = 180.0
	sparks.initial_velocity_min = 160.0
	sparks.initial_velocity_max = 360.0
	sparks.gravity = Vector2(0, 520)
	sparks.scale_amount_min = 0.12
	sparks.scale_amount_max = 0.22
	sparks.color = StationArt.hdr(Color(1.0, 0.82, 0.35), 2.2)
	car.add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.6).timeout.connect(sparks.queue_free)
	var pop := Label.new()
	pop.text = "+%s %s" % [GameData.ar_digits(tips), tr("UI_CURRENCY")]
	pop.add_theme_font_size_override("font_size", 64)
	pop.add_theme_color_override("font_color", StationArt.hdr(Color(1.0, 0.84, 0.4), 1.3))
	pop.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	pop.add_theme_constant_override("outline_size", 14)
	car.add_child(pop)
	pop.position = at - Vector2(120, 60)
	var t := pop.create_tween()
	t.tween_property(pop, "position:y", pop.position.y - 170.0, 1.1).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(pop, "modulate:a", 0.0, 0.5).set_delay(0.6)
	t.tween_callback(pop.queue_free)
	if perfect:
		Input.vibrate_handheld(35)


## Something went wrong on the stove or blender: shake the car and buzz.
func _jolt(strength: float, duration: float, vibrate_ms: int) -> void:
	var car := backdrop.get_parent() as Control
	var home := car.position
	var t := car.create_tween()
	var steps := 8
	for i in steps:
		var fade := 1.0 - float(i) / steps
		t.tween_property(car, "position", home + Vector2(randf_range(-1, 1), randf_range(-1, 1)) * strength * fade,
			duration / steps)
	t.tween_property(car, "position", home, 0.05)
	Input.vibrate_handheld(vibrate_ms)


func _active_art() -> StationArt:
	return blend_gauge.blender if blend_gauge.visible else heat_gauge.stove


func _finish(result: Dictionary) -> void:
	await get_tree().create_timer(result_hold_sec).timeout
	prep_complete.emit(result)


func _refresh_espresso() -> void:
	var unlocked := Economy.owns("espresso_basic")
	espresso_slot.modulate.a = 1.0 if unlocked else 0.55
	if not unlocked:
		var cost := int(GameData.get_equipment("espresso_basic").get("cost_egp", 0))
		espresso_label.text = "🔒 %s · %s %s" % [tr("PREP_ESPRESSO_LOCKED"), GameData.ar_digits(cost), tr("UI_CURRENCY")]
