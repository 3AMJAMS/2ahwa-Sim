class_name HeatGauge
extends Control
## Sand-bath / stove heat gauge: heat climbs 0 → 100 over prep_time_sec.
## Tap to stop inside the green zone for a perfect brew; reaching 100 boils over.

signal gauge_completed(accuracy: float)
signal gauge_failed()

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

var _fill := StyleBoxFlat.new()

@onready var status_label: Label = %StatusLabel
@onready var bar: ProgressBar = %ProgressBar
@onready var green_zone: ColorRect = %GreenZone
@onready var tap_label: Label = %TapToStopLabel


func _ready() -> void:
	var track := StyleBoxFlat.new()
	track.bg_color = COLOR_TRACK
	track.set_corner_radius_all(24)
	_fill.set_corner_radius_all(24)
	bar.add_theme_stylebox_override("background", track)
	bar.add_theme_stylebox_override("fill", _fill)
	# Bar fills bottom-to-top, so zone anchors are measured from the bottom.
	green_zone.anchor_top = 1.0 - green_max / 100.0
	green_zone.anchor_bottom = 1.0 - green_min / 100.0
	reset()


func start(time_sec: float = prep_time_sec) -> void:
	prep_time_sec = maxf(time_sec, 0.1)
	heat = 0.0
	state = State.HEATING
	set_process(true)
	_refresh()


func reset() -> void:
	state = State.IDLE
	heat = 0.0
	set_process(false)
	_refresh()


func _process(delta: float) -> void:
	heat += delta / prep_time_sec * 100.0
	if heat >= 100.0:
		heat = 100.0
		state = State.DONE
		set_process(false)
		_refresh()
		status_label.text = tr("PREP_BURNT")
		gauge_failed.emit()
		return
	_refresh()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		stop()


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
	if is_in_green(heat):
		status_label.text = tr("PREP_PERFECT")
	elif heat < green_min:
		status_label.text = tr("PREP_LUKEWARM")
	else:
		status_label.text = tr("PREP_TOO_HOT")
	gauge_completed.emit(accuracy)


func score(value: float) -> float:
	return 1.0 if is_in_green(value) else off_zone_accuracy


func is_in_green(value: float) -> bool:
	return value >= green_min and value <= green_max


func _refresh() -> void:
	bar.value = heat
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
			status_label.text = tr("PREP_WAITING")
		elif heat <= green_max:
			status_label.text = tr("PREP_WOSH_RISING")
		else:
			status_label.text = tr("PREP_TOO_HOT")
	elif state == State.IDLE:
		status_label.text = ""
