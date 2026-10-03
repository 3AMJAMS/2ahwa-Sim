class_name HeatGauge
extends Node
## Stove heat mechanic: heat climbs 0 → 100 over prep_time_sec while the
## كنكة boils on the ring (Stove3D shows it; the slim bar beside the kanaka
## is the readout). Tap the kanaka to take it off the fire inside the green
## zone for a perfect brew — it pours into the glass before the result is
## reported. Reaching 100 boils over. PrepStation builds the readouts and
## routes the taps here.

signal gauge_completed(accuracy: float)
signal gauge_failed()
## The pot just started foaming over (the failure lands after the animation).
signal boiled_over

enum State { IDLE, HEATING, DONE }

const COLOR_WARM := Color("d9a441")
const COLOR_GREEN := Color("4caf50")
const COLOR_HOT := Color("e0452b")
const COLOR_TRACK := Color("1b1e3a")

@export var prep_time_sec := 12.0
## Taps below this heat are ignored, so mashing early can't score.
@export_range(0.0, 100.0) var warm_min := 40.0
@export_range(0.0, 100.0) var green_min := 65.0
@export_range(0.0, 100.0) var green_max := 85.0
## Accuracy awarded for a tap outside the green zone (lukewarm or too hot).
@export_range(0.0, 1.0) var off_zone_accuracy := 0.5

var state := State.IDLE
var heat := 0.0
## The kanaka holds plain water (tea made in the glass): the prompts talk
## about the water boiling rather than the foam rising.
var water := false
## Milk boils in the kanaka (شاي بلبن, قرفة باللبن): it's the milk rising.
var milk := false
## The player pours it themselves (شاي على مية بيضا): a tap in time lifts the
## kanaka over the glass and reports; PrepStation runs the pour.
var manual_pour := false

var _fill := StyleBoxFlat.new()
## Bumped on every start/reset so a pour that outlives its order is ignored.
var _run_id := 0

var status_label: Label
var bar: ProgressBar
var green_zone: ColorRect
var tap_label: Label
var stove: Stove3D


func _ready() -> void:
	set_process(false)


func setup(the_stove: Stove3D, status: Label, heat_bar: ProgressBar, zone: ColorRect, tap: Label) -> void:
	stove = the_stove
	status_label = status
	bar = heat_bar
	green_zone = zone
	tap_label = tap
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_TRACK
	track.set_corner_radius_all(22)
	_fill.set_corner_radius_all(22)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", _fill)
	# Bar fills bottom-to-top, so zone anchors are measured from the bottom.
	green_zone.anchor_top = 1.0 - green_max / 100.0
	green_zone.anchor_bottom = 1.0 - green_min / 100.0
	reset()


## Recolours the stove's drink from a menu item's "look" block.
func set_look(look: Dictionary) -> void:
	stove.set_look(look)


func start(time_sec: float = prep_time_sec) -> void:
	prep_time_sec = maxf(time_sec, 0.1)
	heat = 0.0
	state = State.HEATING
	_run_id += 1
	set_process(true)
	stove.reset_pot()
	stove.ignite()
	_refresh()


func reset() -> void:
	state = State.IDLE
	heat = 0.0
	_run_id += 1
	set_process(false)
	stove.reset()
	_refresh()


func _process(delta: float) -> void:
	heat += delta / prep_time_sec * 100.0
	if heat >= 100.0:
		_boil_over()
		return
	_refresh()


func is_heating() -> bool:
	return state == State.HEATING


func _unhandled_input(event: InputEvent) -> void:
	if state == State.HEATING and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		stop()


## Player tap. Ignored while idle or before the tea is at least warm.
func stop() -> void:
	if state != State.HEATING or heat < warm_min:
		return
	state = State.DONE
	set_process(false)
	var accuracy := score(heat)
	_refresh()
	var pour := Stove3D.Pour.PERFECT
	if is_in_green(heat):
		status_label.text = tr("PREP_PERFECT")
	elif heat < green_min:
		status_label.text = tr("PREP_LUKEWARM")
		pour = Stove3D.Pour.LUKEWARM
	else:
		status_label.text = tr("PREP_TOO_HOT")
		pour = Stove3D.Pour.TOO_HOT
	var run := _run_id
	if manual_pour:
		stove._pour_kind = pour
		await stove.lift_for_pour()
	else:
		await stove.pour(pour)
	if run == _run_id:
		gauge_completed.emit(accuracy)


func _boil_over() -> void:
	heat = 100.0
	state = State.DONE
	set_process(false)
	_refresh()
	status_label.text = tr("PREP_BURNT")
	boiled_over.emit()
	var run := _run_id
	await stove.boil_over()
	if run == _run_id:
		gauge_failed.emit()


func score(value: float) -> float:
	return 1.0 if is_in_green(value) else off_zone_accuracy


func is_in_green(value: float) -> bool:
	return value >= green_min and value <= green_max


func _refresh() -> void:
	bar.value = heat
	stove.heat = heat
	if heat < green_min:
		_fill.bg_color = COLOR_WARM
	elif heat <= green_max:
		_fill.bg_color = COLOR_GREEN
	else:
		_fill.bg_color = COLOR_HOT
	var heating := state == State.HEATING
	tap_label.modulate.a = 1.0 if heating and is_in_green(heat) else 0.0
	if heating:
		if heat < green_min:
			status_label.text = tr("PREP_WATER_WAITING" if water else "PREP_WAITING")
		elif heat <= green_max:
			status_label.text = tr("PREP_WATER_BOILING" if water else ("PREP_MILK_RISING" if milk else "PREP_WOSH_RISING"))
		else:
			status_label.text = tr("PREP_TOO_HOT")
	elif state == State.IDLE:
		status_label.text = ""
