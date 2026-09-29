extends Control
## Flat "Right Mix" prep station. Shows the order, then the player makes it:
## pick the ingredients from the tray, pick the tool to make it with, then
## work through the drink's own steps (its "steps" list in menu_items.json):
## sugar by the spoon, leaves or a bag in the glass, the gauge, a gentle
## hand pour, stirring. Reports how good it came out back to main via
## prep_complete. Sayed's tutorials hook in at each step.

signal prep_complete(result: Dictionary)
## The gauge finished (true) or the drink was ruined (false).
signal _brewed(ok: bool)

@export var result_hold_sec := 1.4
## Each wrong pick takes this share off the tip, down to half.
@export_range(0.0, 1.0) var mistake_penalty := 0.2

var _item: Dictionary = {}
var _sugar := ""
var _mistakes := 0
var _accuracy := 1.0
## Sugar off by some spoons, or the sugar layer pierced: each docks quality.
var _sugar_factor := 1.0
var _pour_factor := 1.0
## Bumped per order so a flow that outlives its order stops.
var _run := 0

@onready var order_display: Label = %OrderDisplay
@onready var order_box: Control = $Frame/Car/OrderBox
@onready var heat_gauge: HeatGauge = %HeatGauge
@onready var blend_gauge: BlendGauge = %BlendGauge
@onready var result_label: Label = %ResultLabel
@onready var backdrop: TrunkBackdrop = %Backdrop
@onready var picker: PrepPicker = %Picker


func _ready() -> void:
	for gauge in [heat_gauge, blend_gauge]:
		gauge.gauge_completed.connect(_on_gauge_completed)
	heat_gauge.gauge_failed.connect(_on_gauge_failed)
	heat_gauge.boiled_over.connect(_jolt.bind(16.0, 0.45, 160))
	blend_gauge.motor_tripped.connect(_jolt.bind(9.0, 0.3, 80))
	picker.wrong_pick.connect(_on_wrong_pick)
	DayClock.minute_changed.connect(_relight)
	_relight()


## Shows the order with the stove idle in front and the blender behind,
## without starting anything (called while the screen is still fading in).
func load_order(item_id: String, sugar := "") -> bool:
	_run += 1
	_item = GameData.get_menu_item(item_id)
	if _item.is_empty():
		push_error("PrepStation: unknown menu item '%s'" % item_id)
		return false
	_sugar = sugar
	order_display.text = tr(_item.get("name_key", "")) if _item.has("name_key") else _item.get("name_ar", item_id)
	if not sugar.is_empty():
		order_display.text += " " + GameData.sugar_name(sugar)
	result_label.text = ""
	_mistakes = 0
	_accuracy = 1.0
	_sugar_factor = 1.0
	_pour_factor = 1.0
	var active := _gauge_for(_item.get("station", ""))
	for gauge in [heat_gauge, blend_gauge]:
		gauge.reset()
		gauge.visible = gauge == heat_gauge
		gauge.modulate.a = 1.0
	if active:
		active.call("set_look", _item.get("look", {}))
	var look: Dictionary = _item.get("look", {})
	heat_gauge.water = look.get("pot", "") == "water"
	heat_gauge.manual_pour = "pour_gentle" in _item.get("steps", [])
	backdrop.idle_station = "blend"
	picker.hide_now()
	return active != null


## Runs the order: ingredients → tool → gauge.
func start_order() -> void:
	var run := _run
	var order_name := order_display.text
	var needs: Array = _item.get("ingredients", [])
	var tool_id := GameData.tool_for_station(_item.get("station", ""))
	var guided := Tutorial.pending("first_prep")

	# 1. Ingredients.
	picker.show_step(tr("PREP_PICK_INGREDIENTS"), GameData.menu_ingredients(), needs)
	if guided and not needs.is_empty():
		var steps := [{"text": tr("TUT_ORDER").format({"order": order_name}), "target": order_box.get_global_rect}]
		for i in needs.size():
			var key := "TUT_PICK_INGREDIENTS" if i == 0 else "TUT_PICK_MORE"
			steps.append({"text": tr(key).format({"order": order_name, "item": GameData.prep_item_name(needs[i])}),
				"target": picker.card_rect.bind(needs[i]), "until": picker.picked_right})
		await Tutorial.play(steps)
	if run != _run:
		return
	if not picker.step_complete:
		await picker.step_done
	if run != _run:
		return

	# 2. The tool.
	picker.show_step(tr("PREP_PICK_TOOL"), GameData.owned_tools(), [tool_id])
	if guided and Tutorial.pending("first_prep"):
		await Tutorial.play([{"text": tr("TUT_PICK_TOOL_" + tool_id.to_upper()), "target": picker.card_rect.bind(tool_id),
			"until": picker.picked_right}])
		Tutorial.mark("first_prep")
	if run != _run:
		return
	if not picker.step_complete:
		await picker.step_done
	if run != _run:
		return
	await picker.slide_away()
	if run != _run:
		return

	# 3. Bring the chosen tool forward.
	var gauge := _gauge_for(_item.get("station", ""))
	if gauge == null:
		return
	if not gauge.visible:
		heat_gauge.visible = false
		gauge.visible = true
		gauge.modulate.a = 0.0
		create_tween().tween_property(gauge, "modulate:a", 1.0, 0.3)
		backdrop.idle_station = "heat"

	# 4. The drink's own steps, in order (untyped: the step callbacks are
	# the stove's, which the blender doesn't have).
	var art = _active_art()
	for step in _item.get("steps", ["brew"]):
		if run != _run:
			return
		match step:
			"sugar", "sugar_pot":
				await _sugar_step(step == "sugar_pot")
			"tea_leaves":
				if art is KanakaStove:
					(art as KanakaStove).sugar_on_top = "sugar" in _item.get("steps", []) \
						and _item.steps.find("sugar") > _item.steps.find("tea_leaves")
				await _tap_step("PREP_ADD_TEA", {"id": "tea", "name_key": "ING_TEA"}, 1, art.add_leaves, "first_leaves",
					"TUT_ADD_TEA")
			"brew", "boil":
				await _explain_station(gauge)
				if run != _run:
					return
				gauge.start(float(_item.get("prep_time_sec", 10)))
				if not await _brewed:
					return
			"pour":
				pass  # the gauge pours as soon as it's taken off the fire
			"pour_gentle":
				await _gentle_pour(art as KanakaStove)
			"teabag":
				await _tap_step("PREP_DUNK", {"id": "teabag", "name_key": "ING_TEABAG"}, 3, art.dunk_bag, "first_teabag",
					"TUT_DUNK")
			"stir":
				var turns := 4
				var left := [turns]
				await _tap_step("PREP_STIR", {"id": "spoon", "name_key": "ING_STIR"}, turns, func() -> void:
					art.stir(left[0], 0.92 if "teabag" in _item.steps else 1.0)
					left[0] -= 1, "first_stir", "TUT_STIR")
	if run != _run:
		return
	await _finish_steps()
	if run != _run:
		return
	_complete()


## Sugar by the spoon: tap the sugar as many times as the grade takes, then
## "done". Each spoon off the order docks the drink.
func _sugar_step(into_pot: bool) -> void:
	var art = _active_art()
	var target := GameData.sugar_taps(_item.id, _sugar)
	var hint := GameData.sugar_hint(_item.id, _sugar)
	# The first few days the title spells out what the grade means.
	var title := tr("PREP_SUGAR").format({"grade": GameData.sugar_name(_sugar)})
	if Economy.day_number <= 3:
		title = "%s (%s)" % [tr("PREP_SUGAR_TITLE"), hint]
	var half: bool = _item.get("sugar_unit", "") == "half"
	picker.show_counter(title, {"id": "sugar", "name_key": "ING_SUGAR_HALF" if half else "ING_SUGAR"},
		{"id": "done", "name_key": "ING_DONE"}, art.add_sugar.bind(into_pot))
	if Tutorial.pending("first_sugar"):
		await Tutorial.play([{"text": tr("TUT_SUGAR_POT" if into_pot else "TUT_SUGAR").format({"order": order_display.text, "hint": hint}),
			"target": picker.get_global_rect, "until": picker.step_done}])
		Tutorial.mark("first_sugar")
	if not picker.step_complete:
		await picker.step_done
	var off := absi(picker.count - target)
	if off > 0:
		_sugar_factor = maxf(0.4, 1.0 - 0.25 * off)
		result_label.text = tr("PREP_SUGAR_MORE" if picker.count > target else "PREP_SUGAR_LESS")
		get_tree().create_timer(1.4).timeout.connect(func() -> void: result_label.text = "")
	await picker.slide_away()


## One card tapped `count` times (leaves in, dunks of the bag, turns of the
## spoon), with Sayed's tip the first time.
func _tap_step(title_key: String, option: Dictionary, count: int, each: Callable, tut_id: String, tut_key: String) -> void:
	picker.show_repeat(tr(title_key), option, count, each)
	if Tutorial.pending(tut_id):
		await Tutorial.play([{"text": tr(tut_key).format({"order": order_display.text, "count": GameData.ar_digits(count)}),
			"target": picker.card_rect.bind(option.id), "until": picker.step_done}])
		Tutorial.mark(tut_id)
	if not picker.step_complete:
		await picker.step_done
	await picker.slide_away()


## شاي على مية بيضا: hold to pour the boiling water down the side of the
## glass. Holding speeds the flow up; let it get too strong and it punches
## through the sugar and the tea darkens straight away.
func _gentle_pour(stove: KanakaStove) -> void:
	if stove == null:
		return
	var run := _run
	if Tutorial.pending("first_gentle"):
		await Tutorial.play([{"text": tr("TUT_POUR_GENTLE"), "target": stove.glass_rect}])
		Tutorial.mark("first_gentle")
	heat_gauge.status_label.text = tr("PREP_POUR_HOLD")
	var pad := Control.new()
	pad.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	pad.mouse_filter = MOUSE_FILTER_STOP
	var held := [false]
	pad.gui_input.connect(func(e: InputEvent) -> void:
		if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
			held[0] = e.pressed)
	add_child(pad)
	var over := 0.0
	while run == _run:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		var holding: bool = held[0] or Input.is_action_pressed("ui_accept")
		stove.pour_flow = move_toward(stove.pour_flow, 1.0 if holding else 0.0, delta * (0.8 if holding else 2.2))
		if stove.pour_flow > KanakaStove.FLOW_PIERCE:
			over += delta
			if over > 0.15 and not stove.pierced:
				stove.pierce()
				_pour_factor = 0.6
				heat_gauge.status_label.text = tr("PREP_PIERCED")
				_jolt(5.0, 0.2, 40)
		else:
			over = 0.0
		if stove.pour_step(delta):
			break
	pad.queue_free()
	if run != _run:
		return
	heat_gauge.status_label.text = tr("PREP_PERFECT") if not stove.pierced else tr("PREP_PIERCED")
	await stove.end_pour()


## First time on each tool, Sayed shows what to watch.
func _explain_station(gauge: Control) -> void:
	if gauge == heat_gauge and Tutorial.pending("hot_station"):
		await Tutorial.play([
			{"text": tr("TUT_HOT_GAUGE"), "target": func() -> Rect2: return heat_gauge.green_zone.get_global_rect().grow_individual(30, 10, 30, 10)},
			{"text": tr("TUT_HOT_WARN"), "target": heat_gauge.stove.focus_rect},
		])
		Tutorial.mark("hot_station")
	elif gauge == blend_gauge and Tutorial.pending("cold_station"):
		await Tutorial.play([
			{"text": tr("TUT_COLD_GAUGE"), "target": blend_gauge.blender.focus_rect},
			{"text": tr("TUT_COLD_WARN"), "target": blend_gauge.motor_bar.get_global_rect},
		])
		Tutorial.mark("cold_station")


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


func _on_wrong_pick(_id: String) -> void:
	_mistakes += 1
	_jolt(5.0, 0.2, 40)


## The drink's done. Tips are paid when it's handed over on the street, so
## this only reports how good it came out: brew accuracy × the pick penalty.
func _on_gauge_completed(accuracy: float) -> void:
	_accuracy = accuracy
	_brewed.emit(true)


## Every step done: how it came out is brew accuracy × sugar × pour × picks.
func _complete() -> void:
	var accuracy := _accuracy * _sugar_factor * _pour_factor
	var penalty := maxf(0.5, 1.0 - mistake_penalty * _mistakes)
	var perfect := accuracy >= 1.0 and _mistakes == 0
	var headline := tr("RESULT_SUCCESS") if perfect else tr("RESULT_OK")
	result_label.text = "%s\n%s" % [headline, tr("RESULT_READY")]
	_celebrate(perfect)
	_finish({"success": true, "item_id": _item.id, "accuracy": accuracy, "quality": accuracy * penalty,
		"mistakes": _mistakes})


## After the pour: iced drinks get their cubes dropped in, one tap each
## (brewed or blended first, never blended with the ice).
func _finish_steps() -> void:
	var ice := int(_item.get("finish", {}).get("ice", 0))
	if ice <= 0:
		return
	var art := _active_art()
	picker.show_repeat(tr("PREP_ADD_ICE"), {"id": "ice", "name_key": "ING_ICE"}, ice, art.add_ice_cube)
	if Tutorial.pending("first_ice"):
		await Tutorial.play([{"text": tr("TUT_ADD_ICE").format({"order": order_display.text, "count": GameData.ar_digits(ice)}),
			"target": picker.card_rect.bind("ice"), "until": picker.step_done}])
		Tutorial.mark("first_ice")
	if not picker.step_complete:
		await picker.step_done
	await picker.slide_away()


func _on_gauge_failed() -> void:
	_brewed.emit(false)
	result_label.text = tr("RESULT_FAIL")
	_finish({"success": false, "item_id": _item.id, "accuracy": 0.0, "quality": 0.0, "mistakes": _mistakes})


## A good pour: a burst of gold sparks at the glass; a perfect one gets a
## bigger burst and a short buzz. (The tip pops up when it's served.)
func _celebrate(perfect: bool) -> void:
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
	if perfect:
		Input.vibrate_handheld(35)


## Something went wrong: shake the car and buzz.
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
