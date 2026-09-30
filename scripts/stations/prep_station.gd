extends Control
## The prep station: Sayed at FIFI's tail, making the order. The 3D kit
## (PrepRig, Stove3D, Blender3D) sits in the street; this is the layer over
## it: the order at the top, the gauges' readouts, and the quick bar of
## ingredients along the bottom. The drink is made by doing its recipe (the
## "steps" list in menu_items.json) in order:
##   - tap an ingredient in the quick bar (or its jar) to add it now:
##     sugar once per spoon, tea, a tea bag, coffee, karkade, mango, ice;
##   - tap the كنكة to light the fire, and again to take it off when it boils;
##   - hold on the kanaka to pour gently (شاي على مية بيضا);
##   - swipe down on the glass to dunk the bag, circle on it to stir;
##   - tap the blender to start it, hold anywhere for turbo.
## A step in brackets in the JSON ([a, b]) can be done in either order.
## Doing something before its time is a mistake (the tip shrinks); after a
## pause Sayed hints at what's next. How it came out goes back to main via
## prep_complete.

signal prep_complete(result: Dictionary)
## A recipe step was finished (the tutorial waits on this).
signal step_done
## The explained action happened (the tutorial's "until").
signal tutorial_action
## The gauge finished (true) or the drink was ruined (false).
signal _brewed(ok: bool)

@export var result_hold_sec := 1.4
## Each mistake takes this share off the tip, down to half.
@export_range(0.0, 1.0) var mistake_penalty := 0.2

const SLOT_OF := {"sugar": "sugar", "sugar_pot": "sugar", "tea_leaves": "tea", "tea_pot": "tea", "teabag": "teabag",
	"coffee": "coffee", "karkade": "karkade", "mango": "mango", "ice": "ice"}
const HINT_KEYS := {"sugar": "PREP_HINT_SUGAR", "sugar_pot": "PREP_HINT_SUGAR_POT", "tea_leaves": "PREP_HINT_TEA",
	"tea_pot": "PREP_HINT_TEA_POT", "coffee": "PREP_HINT_COFFEE", "karkade": "PREP_HINT_KARKADE", "mango": "PREP_HINT_MANGO",
	"teabag": "PREP_HINT_TEABAG", "stir": "PREP_HINT_STIR", "boil": "PREP_HINT_LIGHT", "brew": "PREP_HINT_LIGHT",
	"pour_gentle": "PREP_HINT_POUR", "blend": "PREP_HINT_BLEND", "ice": "PREP_HINT_ICE"}
const STIR_TURNS := 4
const DUNKS := 3
## A press shorter than this, moving less than TAP_SLOP, is a tap.
const TAP_TIME := 0.35
const TAP_SLOP := 28.0

var rig: PrepRig
var stove: Stove3D
var blender: Blender3D
var heat_gauge := HeatGauge.new()
var blend_gauge := BlendGauge.new()
var quick_bar := QuickBar.new()
var arranging := false

var _item: Dictionary = {}
var _sugar := ""
var _mistakes := 0
var _accuracy := 1.0
## Sugar off by some spoons, or the sugar layer pierced: each docks quality.
var _sugar_factor := 1.0
var _pour_factor := 1.0
## Bumped per order so anything that outlives its order stops.
var _run := 0
## The recipe: each entry a group of step ids still to do (usually one).
var _steps: Array = []
var _si := 0
var _group: Array = []
var _sugar_count := 0
var _sugar_started := false
var _stir_left := 0
var _stir_part := 0.0
var _dunks_left := 0
var _ice_left := 0
var _bag_in := false
var _heating := false
var _blending := false
var _pouring := false
var _done := true
## Holds back Sayed's step tips while the first-order intro plays.
var _quiet := false
var _hint_t := 0.0
var _hinting := ""

# Gestures.
var _press := false
var _press_at := Vector2.ZERO
var _press_t := 0.0
var _press_target := ""
var _stir_prev := 0.0
var _stir_acc := 0.0
var _dunk_anchor := 0.0
var _hold := false
var _drag_rack := ""

var _order_title := Label.new()
var _order_display := Label.new()
var _status := Label.new()
var _result := Label.new()
var _pad := Control.new()
var _heat_bar := ProgressBar.new()
var _green_zone := ColorRect.new()
var _tap_label := Label.new()
var _blend_bar := ProgressBar.new()
var _motor_bar := ProgressBar.new()
var _hold_label := Label.new()
var _marks := Control.new()
var _arrange := Button.new()
var _arrange_done := Button.new()
var _t := 0.0


func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE
	_build_ui()
	add_child(heat_gauge)
	add_child(blend_gauge)
	for gauge in [heat_gauge, blend_gauge]:
		gauge.gauge_completed.connect(_on_gauge_completed)
	heat_gauge.gauge_failed.connect(_on_gauge_failed)
	heat_gauge.boiled_over.connect(_jolt.bind(1.6, 160))
	blend_gauge.motor_tripped.connect(_jolt.bind(0.9, 80))
	quick_bar.slot_pressed.connect(func(id: String) -> void: _act("ing:" + id))


## Hooks the station up to the 3D kit on FIFI.
func attach(the_rig: PrepRig) -> void:
	rig = the_rig
	stove = Stove3D.new()
	stove.rig = rig
	rig.add_child(stove)
	blender = Blender3D.new()
	blender.rig = rig
	rig.add_child(blender)
	heat_gauge.setup(stove, _status, _heat_bar, _green_zone, _tap_label)
	blend_gauge.setup(blender, _status, _blend_bar, _motor_bar, _hold_label)


#region Layout

func _build_ui() -> void:
	# The touch pad under everything: gestures on the 3D kit land here.
	_pad.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_pad.mouse_filter = MOUSE_FILTER_STOP
	_pad.gui_input.connect(_on_pad_input)
	add_child(_pad)
	_marks.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	_marks.mouse_filter = MOUSE_FILTER_IGNORE
	_marks.draw.connect(_draw_marks)
	add_child(_marks)
	var box := VBoxContainer.new()
	box.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	box.offset_top = 40
	box.offset_bottom = 170
	box.add_theme_constant_override("separation", -6)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(box)
	_order_title.text = tr("PREP_ORDER_TITLE")
	_style_label(_order_title, 26, Color(1, 0.784, 0.38, 0.8), 8)
	box.add_child(_order_title)
	_style_label(_order_display, 54, Color(1, 0.784, 0.38), 12)
	box.add_child(_order_display)
	_status.set_anchors_and_offsets_preset(PRESET_TOP_WIDE)
	_status.offset_top = 170
	_status.offset_bottom = 290
	_status.offset_left = 40
	_status.offset_right = -40
	_style_label(_status, 42, Color.WHITE, 12)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.max_lines_visible = 2
	add_child(_status)
	# Heat readout: a slim bar with its green band, placed by the stove.
	_heat_bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
	_heat_bar.show_percentage = false
	_heat_bar.size = Vector2(44, 330)
	_heat_bar.mouse_filter = MOUSE_FILTER_IGNORE
	add_child(_heat_bar)
	_green_zone.color = Color(1, 1, 1, 0.22)
	_green_zone.anchor_right = 1.0
	_green_zone.mouse_filter = MOUSE_FILTER_IGNORE
	_heat_bar.add_child(_green_zone)
	_tap_label.text = tr("UI_TAP_TO_STOP")
	_style_label(_tap_label, 34, Color(0.298, 0.686, 0.314), 10)
	_tap_label.size = Vector2(300, 50)
	add_child(_tap_label)
	for bar in [_blend_bar, _motor_bar]:
		bar.fill_mode = ProgressBar.FILL_BOTTOM_TO_TOP
		bar.show_percentage = false
		bar.size = Vector2(40, 300)
		bar.mouse_filter = MOUSE_FILTER_IGNORE
		add_child(bar)
	_hold_label.text = tr("UI_HOLD_TO_BLEND")
	_style_label(_hold_label, 32, Color(1, 0.702, 0.278), 10)
	_hold_label.size = Vector2(420, 50)
	add_child(_hold_label)
	quick_bar.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	quick_bar.offset_top = -290
	quick_bar.offset_bottom = -24
	add_child(quick_bar)
	_result.set_anchors_preset(PRESET_FULL_RECT)
	_result.anchor_top = 0.3
	_result.anchor_bottom = 0.44
	_result.offset_left = 60
	_result.offset_right = -60
	_style_label(_result, 64, Color.WHITE, 18)
	_result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_result.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_result)
	for b in [_arrange, _arrange_done]:
		var st := StyleBoxFlat.new()
		st.bg_color = Color(0.1, 0.07, 0.1, 0.85)
		st.border_color = Color("e0a458")
		st.set_border_width_all(3)
		st.set_corner_radius_all(14)
		st.content_margin_left = 16
		st.content_margin_right = 16
		for state in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(state, st)
		b.add_theme_color_override("font_color", Color("ffd27a"))
		b.add_theme_font_size_override("font_size", 30)
		b.focus_mode = FOCUS_NONE
		add_child(b)
	_arrange.text = tr("UI_ARRANGE")
	_arrange.position = Vector2(24, 40)
	_arrange.custom_minimum_size = Vector2(120, 64)
	_arrange.pressed.connect(set_arranging.bind(true))
	_arrange_done.text = tr("UI_ARRANGE_DONE")
	_arrange_done.custom_minimum_size = Vector2(240, 90)
	_arrange_done.visible = false
	_arrange_done.pressed.connect(set_arranging.bind(false))


func _style_label(l: Label, fs: int, col: Color, outline: int) -> void:
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08))
	l.add_theme_constant_override("outline_size", outline)
	l.mouse_filter = MOUSE_FILTER_IGNORE


## Keeps the readouts next to the kit they belong to.
func _place_readouts() -> void:
	if stove == null:
		return
	var right := size.x - 70.0
	var k := stove.kanaka_rect()
	_heat_bar.position = Vector2(right, clampf(k.position.y - 60.0, 300.0, size.y - 700.0))
	_tap_label.position = Vector2(k.get_center().x - 150.0, k.position.y - 110.0)
	var b := blender.blender_rect()
	_blend_bar.position = Vector2(right - 56.0, clampf(b.position.y - 40.0, 300.0, size.y - 700.0))
	_motor_bar.position = Vector2(right, _blend_bar.position.y)
	_hold_label.position = Vector2(size.x * 0.5 - 210.0, quick_bar.position.y - 70.0)
	_arrange_done.position = Vector2(size.x * 0.5 - 120.0, quick_bar.position.y - 120.0)

#endregion


#region The order

## Shows the order with the kit reset, without starting anything (called
## while the screen is still fading in).
func load_order(item_id: String, sugar := "") -> bool:
	_run += 1
	_item = GameData.get_menu_item(item_id)
	if _item.is_empty():
		push_error("PrepStation: unknown menu item '%s'" % item_id)
		return false
	_sugar = sugar
	_order_display.text = tr(_item.get("name_key", "")) if _item.has("name_key") else _item.get("name_ar", item_id)
	if not sugar.is_empty():
		_order_display.text += " " + GameData.sugar_name(sugar)
	_result.text = ""
	_status.text = ""
	_mistakes = 0
	_accuracy = 1.0
	_sugar_factor = 1.0
	_pour_factor = 1.0
	_done = true
	_heating = false
	_blending = false
	_pouring = false
	_hold = false
	var look: Dictionary = _item.get("look", {})
	var cold: bool = _item.get("station", "") == "blend"
	heat_gauge.reset()
	blend_gauge.reset()
	heat_gauge.set_look(look)
	if cold:
		blend_gauge.set_look(look)
	heat_gauge.water = look.get("pot", "") == "water"
	heat_gauge.manual_pour = _has_step("pour_gentle")
	stove.show_glass(not cold)
	blender.show_glass(cold)
	_heat_bar.visible = not cold
	_green_zone.visible = not cold
	_blend_bar.visible = cold
	_motor_bar.visible = cold
	_hold_label.modulate.a = 0.0
	_tap_label.modulate.a = 0.0
	quick_bar.set_slots(_slots())
	_steps = _recipe()
	_si = 0
	_group = []
	return true


## Starts taking the player's actions.
func start_order() -> void:
	var run := _run
	_done = false
	_hint_t = 0.0
	var intro := Tutorial.pending("first_quickbar")
	_quiet = intro
	_enter_group()
	_quiet = false
	if intro:
		await Tutorial.play([
			{"text": tr("TUT_ORDER").format({"order": _order_display.text}), "target": _order_rect},
			{"text": tr("TUT_QUICKBAR"), "target": quick_bar.get_global_rect},
		])
		Tutorial.mark("first_quickbar")
		if run == _run:
			_explain_current()


## The recipe as groups of step ids, with the ice to finish.
func _recipe() -> Array:
	var out := []
	for step in _item.get("steps", ["brew"]):
		if step is Array:
			out.append((step as Array).duplicate())
		elif step != "pour":
			out.append([step])
	var ice := int(_item.get("finish", {}).get("ice", 0))
	if ice > 0:
		out.append(["ice"])
	return out


func _has_step(id: String) -> bool:
	for step in _item.get("steps", []):
		if step is Array and id in step:
			return true
		if step is String and step == id:
			return true
	return false


## The ingredients any orderable drink needs, so the dock never gives away
## the recipe.
func _slots() -> Array:
	var out := []
	for id in GameData.menu_items:
		var item: Dictionary = GameData.menu_items[id]
		if int(item.get("unlock_tier", 0)) > Economy.current_venue_tier or not Economy.owns_slot(item.get("station", "")):
			continue
		for step in item.get("steps", []):
			var ids: Array = step if step is Array else [step]
			for s in ids:
				if SLOT_OF.has(s) and not SLOT_OF[s] in out:
					out.append(SLOT_OF[s])
		if int(item.get("finish", {}).get("ice", 0)) > 0 and not "ice" in out:
			out.append("ice")
	return out


func _enter_group() -> void:
	if _si >= _steps.size():
		_group = []
		_complete()
		return
	_group = (_steps[_si] as Array).duplicate()
	_sugar_count = 0
	_sugar_started = false
	_stir_part = 0.0
	_bag_in = false
	for id in _group:
		match id:
			"stir":
				_stir_left = STIR_TURNS
			"teabag":
				_dunks_left = DUNKS
			"ice":
				_ice_left = int(_item.get("finish", {}).get("ice", 3))
			"pour_gentle":
				stove.show_flow = true
	_hint_t = 0.0
	_clear_hint()
	if not _quiet and not Tutorial.is_playing():
		_explain_current()


func _finish_step(id: String) -> void:
	_group.erase(id)
	_hint_t = 0.0
	_clear_hint()
	step_done.emit()
	if _group.is_empty():
		_si += 1
		_enter_group()

#endregion


#region Actions

## Everything the player does comes through here: "ing:<id>" (a slot or a
## jar), "kanaka", "glass", "blender", "stir" (a full turn), "dunk".
func _act(action: String) -> void:
	if _done or arranging or _heating and action != "kanaka" or _blending or _pouring:
		if _heating and action.begins_with("ing:"):
			_wrong(action)
		return
	_hint_t = 0.0
	_clear_hint()
	var sugar_id := _sugar_step()
	# Another step in the same group first (Turkish coffee: coffee or sugar).
	for id in _group:
		if id != sugar_id and _accepts(id, action):
			_do(id, action)
			return
	if sugar_id != "":
		if action == "ing:sugar":
			_add_spoon(sugar_id == "sugar_pot")
			return
		# Anything else ends the sugar and moves on.
		_end_sugar(sugar_id)
		if _done:
			return
		for id in _group:
			if _accepts(id, action):
				_do(id, action)
				return
	if action == "glass" or action == "stir" or action == "dunk":
		return
	_wrong(action)


func _sugar_step() -> String:
	for id in _group:
		if id == "sugar" or id == "sugar_pot":
			return id
	return ""


func _accepts(id: String, action: String) -> bool:
	match id:
		"tea_leaves", "tea_pot":
			return action == "ing:tea"
		"coffee", "karkade", "mango":
			return action == "ing:" + id
		"teabag":
			return action == "ing:teabag" or (_bag_in and (action == "dunk" or action == "glass"))
		"stir":
			return action == "stir" or action == "glass"
		"boil", "brew":
			return action == "kanaka"
		"pour_gentle":
			return action == "kanaka"
		"blend":
			return action == "blender"
		"ice":
			return action == "ing:ice"
	return false


func _do(id: String, action: String) -> void:
	var run := _run
	match id:
		"tea_leaves":
			stove.sugar_on_top = _has_step("sugar") and _item.steps.find("sugar") > _item.steps.find("tea_leaves")
			quick_bar.flash("tea", true)
			stove.add_leaves()
			tutorial_action.emit()
			_finish_step(id)
		"tea_pot", "coffee", "karkade":
			quick_bar.flash(SLOT_OF[id], true)
			stove.add_to_pot("tea" if id == "tea_pot" else id)
			tutorial_action.emit()
			_finish_step(id)
		"mango":
			quick_bar.flash("mango", true)
			blender.add_fruit()
			tutorial_action.emit()
			_finish_step(id)
		"teabag":
			if not _bag_in:
				_bag_in = true
				quick_bar.flash("teabag", true)
			_dunks_left -= 1
			stove.dunk_bag()
			tutorial_action.emit()
			if _dunks_left <= 0:
				_finish_step(id)
		"stir":
			var turn := 1.0 if action == "stir" else 0.34
			_stir_part += turn
			if action == "glass":
				stove.stir_angle += 2.0
			while _stir_part >= 1.0 and _stir_left > 0:
				_stir_part -= 1.0
				stove.stir(_stir_left, 0.92 if _has_step("teabag") else 1.0)
				_stir_left -= 1
				tutorial_action.emit()
			if _stir_left <= 0:
				stove.stirring = false
				_finish_step(id)
		"boil", "brew":
			if heat_gauge.is_heating():
				heat_gauge.stop()
				return
			_heating = true
			tutorial_action.emit()
			heat_gauge.start(float(_item.get("prep_time_sec", 10)))
			_explain_hot()
			var ok: bool = await _brewed
			if run != _run:
				return
			_heating = false
			if ok:
				_finish_step(id)
		"pour_gentle":
			pass
		"blend":
			_blending = true
			tutorial_action.emit()
			blend_gauge.start(float(_item.get("prep_time_sec", 10)))
			_explain_cold()
			var ok: bool = await _brewed
			if run != _run:
				return
			_blending = false
			if ok:
				_finish_step(id)
		"ice":
			quick_bar.flash("ice", true)
			if _item.get("station", "") == "blend":
				blender.add_ice_cube()
			else:
				stove.add_ice_cube()
			_ice_left -= 1
			tutorial_action.emit()
			if _ice_left <= 0:
				_finish_step(id)


func _add_spoon(into_pot: bool) -> void:
	if _sugar_count >= 8:
		return
	_sugar_started = true
	_sugar_count += 1
	quick_bar.set_badge("sugar", _sugar_count)
	quick_bar.flash("sugar", true)
	stove.add_sugar(into_pot)
	tutorial_action.emit()


## The sugar's done (the player moved on): each spoon off the order docks it.
func _end_sugar(id: String) -> void:
	var target := GameData.sugar_taps(_item.id, _sugar)
	var off := absi(_sugar_count - target)
	if off > 0:
		_sugar_factor = maxf(0.4, 1.0 - 0.25 * off)
		_flash_result(tr("PREP_SUGAR_MORE" if _sugar_count > target else "PREP_SUGAR_LESS"))
	quick_bar.set_badge("sugar", 0)
	_finish_step(id)


## Doing something before its time: the tip shrinks, and Sayed shows what's next.
func _wrong(action: String) -> void:
	_mistakes += 1
	if action.begins_with("ing:"):
		quick_bar.flash(action.substr(4), false)
	_flash_result(tr("PREP_NOT_YET"))
	_jolt(0.6, 40)
	_hint_t = 99.0

#endregion


#region Gestures

func _on_pad_input(e: InputEvent) -> void:
	if arranging:
		_arrange_input(e)
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_press_at = e.position
			_press_t = _t
			_press_target = _target_at(e.position)
			_stir_acc = 0.0
			_stir_prev = _angle_round_glass(e.position)
			_dunk_anchor = e.position.y
			if "stir" in _group and _press_target == "glass":
				stove.stirring = true
			_set_hold(true)
		else:
			_press = false
			_set_hold(false)
			stove.stirring = false
			var moved: float = e.position.distance_to(_press_at)
			if _t - _press_t <= TAP_TIME and moved <= TAP_SLOP:
				_tap(_press_target)
	elif e is InputEventMouseMotion and _press:
		if "stir" in _group and (_press_target == "glass" or _press_target == ""):
			var a := _angle_round_glass(e.position)
			var d := wrapf(a - _stir_prev, -PI, PI)
			_stir_prev = a
			if e.position.distance_to(stove.glass_centre()) > 20.0:
				_stir_acc += d
				stove.stir_angle += d
				stove.stirring = true
				if absf(_stir_acc) >= TAU * 0.9:
					_stir_acc = 0.0
					_act("stir")
		elif "teabag" in _group and _bag_in and e.position.y - _dunk_anchor > 70.0:
			_dunk_anchor = e.position.y
			_act("dunk")
		elif e.position.y < _dunk_anchor:
			_dunk_anchor = e.position.y


func _tap(target: String) -> void:
	match target:
		"":
			pass
		"kanaka", "glass", "blender":
			_act(target)
		_:
			_act("ing:" + target)


## What's under the finger: the kanaka, the glass, the blender or a jar.
func _target_at(p: Vector2) -> String:
	if stove == null:
		return ""
	if stove.kanaka_rect().grow(16).has_point(p):
		return "kanaka"
	if stove.focus_rect().has_point(p) and not stove.glass_rect().has_point(p):
		return "kanaka"
	if stove.glass_rect().grow(30).has_point(p):
		return "glass"
	if blender.blender_rect().grow(10).has_point(p):
		return "blender"
	for id in PrepRig.JARS:
		if quick_bar.has_slot(id) and rig.jar_rect(id).grow(8).has_point(p):
			return id
	return ""


func _angle_round_glass(p: Vector2) -> float:
	var c := stove.glass_centre()
	return atan2(p.y - c.y, p.x - c.x)


## Holding: the gentle pour, or the blender's turbo.
func _set_hold(on: bool) -> void:
	_hold = on and not _done
	if _blending:
		blend_gauge.set_holding(_hold)

#endregion


func _process(delta: float) -> void:
	_t += delta
	if not is_visible_in_tree():
		return
	_place_readouts()
	_marks.queue_redraw()
	if _done or Tutorial.is_playing():
		return
	if "pour_gentle" in _group and not _pouring:
		_step_pour(delta)
	if not _heating and not _blending:
		_hint_t += delta
		var wait := 2.5 if Economy.day_number <= 3 else 6.0
		if _hint_t >= wait and _hinting == "":
			_show_hint()


## شاي على مية بيضا: hold to pour the water down the side of the glass.
## Holding speeds the flow up; too strong and it punches through the sugar.
var _over := 0.0


func _step_pour(delta: float) -> void:
	var holding := _hold or Input.is_action_pressed("ui_accept")
	if holding:
		_hint_t = 0.0
		if _hinting != "":
			_clear_hint()
	stove.pour_flow = move_toward(stove.pour_flow, 1.0 if holding else 0.0, delta * (0.8 if holding else 2.2))
	if stove.pour_flow > Stove3D.FLOW_PIERCE:
		_over += delta
		if _over > 0.15 and not stove.pierced:
			stove.pierce()
			_pour_factor = 0.6
			_status.text = tr("PREP_PIERCED")
			_jolt(0.5, 40)
	else:
		_over = 0.0
	if stove.pour_step(delta):
		_pouring = true
		var run := _run
		_status.text = tr("PREP_PERFECT") if not stove.pierced else tr("PREP_PIERCED")
		await stove.end_pour()
		if run != _run:
			return
		_pouring = false
		_finish_step("pour_gentle")


#region Hints and Sayed's tips

## What the player should do next (for hints and Sayed's tips): sugar
## that's already enough points on to the step after it.
func _next_id() -> String:
	for id in _group:
		if (id == "sugar" or id == "sugar_pot") and GameData.sugar_taps(_item.id, _sugar) <= _sugar_count:
			continue
		return id
	if _si + 1 < _steps.size() and not _group.is_empty():
		return (_steps[_si + 1] as Array)[0]
	if _group.size() > 0:
		return _group[0]
	return ""


func _show_hint() -> void:
	var id := _next_id()
	if id == "":
		return
	_hinting = id
	if SLOT_OF.has(id) and not (id == "teabag" and _bag_in):
		quick_bar.pulse(SLOT_OF[id])
	var key: String = HINT_KEYS.get(id, "")
	if id == "teabag" and _bag_in:
		key = "PREP_HINT_DUNK"
	if (id == "sugar" or id == "sugar_pot") and _sugar_started:
		key = "PREP_HINT_SUGAR_MORE"
	if key != "":
		_status.text = tr(key).format({"hint": GameData.sugar_hint(_item.id, _sugar)})


func _clear_hint() -> void:
	if _hinting == "":
		return
	_hinting = ""
	quick_bar.pulse("")
	if not _heating and not _blending and not _pouring:
		_status.text = ""


## A ring round the thing to touch next, and the flow meter while pouring.
func _draw_marks() -> void:
	if stove == null:
		return
	if _hinting != "":
		var r := Rect2()
		match _hinting:
			"boil", "brew", "pour_gentle":
				r = stove.kanaka_rect()
			"stir":
				r = stove.glass_rect()
			"teabag":
				if _bag_in:
					r = stove.glass_rect()
			"blend":
				r = blender.blender_rect()
		if r.has_area():
			var k := 0.5 + 0.5 * sin(_t * 6.0)
			var c := r.get_center()
			var rad := maxf(r.size.x, r.size.y) * 0.55 + 10.0 * k
			_marks.draw_arc(c, rad, 0, TAU, 40, Color(1, 0.84, 0.48, 0.5 + 0.4 * k), 6.0, true)
			if _hinting == "stir":
				for i in 3:
					var a := _t * 3.0 + i * TAU / 3.0
					_marks.draw_circle(c + Vector2(cos(a), sin(a)) * rad * 0.8, 9, Color(1, 0.84, 0.48, 0.9))
			elif _hinting == "teabag":
				var y := fmod(_t * 160.0, 120.0)
				_marks.draw_circle(c + Vector2(0, -60 + y), 12, Color(1, 0.84, 0.48, 0.9 * (1.0 - y / 120.0)))
	if "pour_gentle" in _group and not _done:
		var g := stove.glass_rect()
		var m := Rect2(g.position.x - 60.0, g.position.y, 26.0, g.size.y)
		_marks.draw_rect(m.grow(5), Color(0.05, 0.05, 0.1, 0.75))
		var red_y := m.end.y - m.size.y * Stove3D.FLOW_PIERCE
		_marks.draw_rect(Rect2(m.position, Vector2(m.size.x, red_y - m.position.y)), Color(0.88, 0.27, 0.17, 0.5))
		_marks.draw_rect(Rect2(Vector2(m.position.x, red_y), Vector2(m.size.x, m.size.y * (Stove3D.FLOW_PIERCE - 0.2))),
			Color(0.3, 0.69, 0.31, 0.5))
		var h := m.size.y * stove.pour_flow
		_marks.draw_rect(Rect2(m.position.x + 4, m.end.y - h, m.size.x - 8, h),
			Color("4caf50") if stove.pour_flow < Stove3D.FLOW_PIERCE else Color("e0452b"))


## First time each kind of step comes up, Sayed explains it.
func _explain_current() -> void:
	var id := _next_id()
	var run := _run
	var steps := []
	var tut := ""
	match id:
		"sugar", "sugar_pot":
			tut = "first_sugar"
			steps = [{"text": tr("TUT_SUGAR_POT" if id == "sugar_pot" else "TUT_SUGAR").format(
				{"order": _order_display.text, "hint": GameData.sugar_hint(_item.id, _sugar)}),
				"target": _slot_rect.bind("sugar"),
				"until": tutorial_action}]
		"tea_leaves":
			tut = "first_leaves"
			steps = [{"text": tr("TUT_ADD_TEA"), "target": _slot_rect.bind("tea"), "until": tutorial_action}]
		"coffee", "karkade", "tea_pot":
			tut = "first_pot"
			steps = [{"text": tr("TUT_ADD_POT").format({"item": tr(QuickBar.NAMES[SLOT_OF[id]])}),
				"target": _slot_rect.bind(SLOT_OF[id]), "until": tutorial_action}]
		"boil", "brew":
			tut = "first_light"
			steps = [{"text": tr("TUT_LIGHT"), "target": stove.kanaka_rect, "until": tutorial_action}]
		"teabag":
			tut = "first_teabag"
			steps = [{"text": tr("TUT_TEABAG"), "target": _slot_rect.bind("teabag"), "until": tutorial_action},
				{"text": tr("TUT_DUNK").format({"count": GameData.ar_digits(DUNKS - 1)}), "target": stove.glass_rect,
				"until": step_done}]
		"stir":
			tut = "first_stir"
			steps = [{"text": tr("TUT_STIR").format({"count": GameData.ar_digits(STIR_TURNS)}),
				"target": func() -> Rect2: return stove.glass_rect().grow(60), "until": step_done}]
		"pour_gentle":
			tut = "first_gentle"
			steps = [{"text": tr("TUT_POUR_GENTLE"), "target": stove.glass_rect}]
		"mango":
			tut = "first_blend"
			steps = [{"text": tr("TUT_ADD_POT").format({"item": tr("ING_MANGO")}), "target": _slot_rect.bind("mango"),
				"until": tutorial_action}]
		"blend":
			tut = "first_blend_start"
			steps = [{"text": tr("TUT_BLEND"), "target": blender.blender_rect, "until": tutorial_action}]
		"ice":
			tut = "first_ice"
			steps = [{"text": tr("TUT_ADD_ICE").format({"order": _order_display.text,
				"count": GameData.ar_digits(_ice_left)}), "target": _slot_rect.bind("ice"), "until": tutorial_action}]
	if tut == "" or not Tutorial.pending(tut):
		return
	await Tutorial.play(steps)
	Tutorial.mark(tut)
	if run == _run:
		_hint_t = 0.0


func _slot_rect(id: String) -> Rect2:
	var r := quick_bar.slot_rect(id)
	return Rect2(quick_bar.get_global_transform() * r.position, r.size)


func _order_rect() -> Rect2:
	var r := Rect2(Vector2(size.x * 0.15, 40), Vector2(size.x * 0.7, 130))
	return r


func _explain_hot() -> void:
	if not Tutorial.pending("hot_station"):
		return
	await Tutorial.play([
		{"text": tr("TUT_HOT_GAUGE"), "target": func() -> Rect2: return _heat_bar.get_global_rect().merge(stove.kanaka_rect())},
		{"text": tr("TUT_HOT_WARN"), "target": stove.focus_rect},
	])
	Tutorial.mark("hot_station")


func _explain_cold() -> void:
	if not Tutorial.pending("cold_station"):
		return
	await Tutorial.play([
		{"text": tr("TUT_COLD_GAUGE"), "target": blender.blender_rect},
		{"text": tr("TUT_COLD_WARN"), "target": _motor_bar.get_global_rect},
	])
	Tutorial.mark("cold_station")

#endregion


#region Racks

func set_arranging(on: bool) -> void:
	arranging = on
	_arrange_done.visible = on
	_arrange.visible = not on
	quick_bar.visible = not on
	_status.text = tr("UI_ARRANGE_HINT") if on else ""
	if not on and rig:
		rig.save_racks()


func _arrange_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag_rack = rig.rack_at(e.position) if e.pressed else ""
	elif e is InputEventMouseMotion and _drag_rack != "":
		rig.drag_rack(_drag_rack, e.position)

#endregion


#region Results

func _on_gauge_completed(accuracy: float) -> void:
	_accuracy = accuracy
	_brewed.emit(true)


func _on_gauge_failed() -> void:
	_brewed.emit(false)
	_done = true
	_heating = false
	_result.text = tr("RESULT_FAIL")
	_finish({"success": false, "item_id": _item.id, "accuracy": 0.0, "quality": 0.0, "mistakes": _mistakes})


## Every step done: how it came out is brew accuracy × sugar × pour × mistakes.
func _complete() -> void:
	if _done:
		return
	_done = true
	var accuracy := _accuracy * _sugar_factor * _pour_factor
	var penalty := maxf(0.5, 1.0 - mistake_penalty * _mistakes)
	var perfect := accuracy >= 1.0 and _mistakes == 0
	var headline := tr("RESULT_SUCCESS") if perfect else tr("RESULT_OK")
	_status.text = ""
	_result.text = "%s\n%s" % [headline, tr("RESULT_READY")]
	_celebrate(perfect)
	_finish({"success": true, "item_id": _item.id, "accuracy": accuracy, "quality": accuracy * penalty,
		"mistakes": _mistakes})


func _flash_result(text: String) -> void:
	_result.text = text
	var run := _run
	get_tree().create_timer(1.3).timeout.connect(func() -> void:
		if run == _run and not _done:
			_result.text = "")


## A good pour: a burst of gold sparks at the glass; a perfect one gets a
## bigger burst and a short buzz.
func _celebrate(perfect: bool) -> void:
	var at := stove.glass_centre() if _item.get("station", "") != "blend" else blender.screen_of(PrepRig.GLASS_AT + Vector3(0, 0.2, 0))
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.one_shot = true
	sparks.explosiveness = 0.9
	sparks.amount = 36 if perfect else 18
	sparks.lifetime = 0.9
	sparks.texture = Station3D.soft_texture()
	sparks.spread = 180.0
	sparks.initial_velocity_min = 160.0
	sparks.initial_velocity_max = 360.0
	sparks.gravity = Vector2(0, 520)
	sparks.scale_amount_min = 0.25
	sparks.scale_amount_max = 0.45
	sparks.color = Color(1.0, 0.82, 0.35)
	add_child(sparks)
	sparks.emitting = true
	get_tree().create_timer(1.6).timeout.connect(sparks.queue_free)
	if perfect:
		Input.vibrate_handheld(35)


## Something went wrong: shake the view and buzz.
func _jolt(strength: float, vibrate_ms: int) -> void:
	if rig:
		rig.jolt(strength)
	Input.vibrate_handheld(vibrate_ms)


func _finish(result: Dictionary) -> void:
	await get_tree().create_timer(result_hold_sec).timeout
	prep_complete.emit(result)

#endregion
