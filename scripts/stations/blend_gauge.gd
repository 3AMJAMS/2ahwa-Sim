class_name BlendGauge
extends Node
## Cold blender mechanic. Blend progress fills on its own; holding runs the
## motor on turbo to finish faster but heats it. Staying in the motor's red
## zone longer than overheat_grace_sec trips its thermal cut-out: the motor
## stops until it cools to motor_resume_max, costing time (and tips) but never
## the drink. Blender3D shows it; the two slim bars are the readout.
## PrepStation builds the readouts and routes the holds here.

signal gauge_completed(accuracy: float)
## The motor's thermal cut-out just tripped.
signal motor_tripped

enum State { IDLE, BLENDING, TRIPPED, DONE }

const COLOR_MOTOR_OK := Color("4caf50")
const COLOR_MOTOR_WARM := Color("e6c33a")
const COLOR_MOTOR_RED := Color("e0452b")
const COLOR_TRACK := Color("1b1e3a")

@export var prep_time_sec := 10.0
@export var boost_multiplier := 2.5
@export var motor_heat_rate := 45.0   # per second while held
@export var motor_cool_rate := 30.0   # per second while released
@export_range(0.0, 100.0) var motor_warn_min := 55.0
@export_range(0.0, 100.0) var motor_red_min := 80.0
## Grace period in the red before the cut-out trips, so a brief overshoot is forgiven.
@export var overheat_grace_sec := 0.6
## A tripped motor restarts once it has cooled to this.
@export_range(0.0, 100.0) var motor_resume_max := 30.0
## Finishing at or under this fraction of prep_time_sec scores 1.0;
## accuracy falls to 0.5 at the full unboosted time.
@export_range(0.1, 1.0) var par_fraction := 0.6

var state := State.IDLE
var progress := 0.0
var motor_heat := 0.0
var holding := false
var elapsed := 0.0
var _red_time := 0.0
## Bumped on every start/reset so a pour that outlives its order is ignored.
var _run_id := 0

var _blend_fill := StyleBoxFlat.new()
var _motor_fill := StyleBoxFlat.new()

var status_label: Label
var blend_bar: ProgressBar
var motor_bar: ProgressBar
var hold_label: Label
var blender: Blender3D


func _ready() -> void:
	set_process(false)


func setup(the_blender: Blender3D, status: Label, progress_bar: ProgressBar, motor: ProgressBar, hold: Label) -> void:
	blender = the_blender
	status_label = status
	blend_bar = progress_bar
	motor_bar = motor
	hold_label = hold
	for pair in [[blend_bar, _blend_fill], [motor_bar, _motor_fill]]:
		var track := StyleBoxFlat.new()
		track.bg_color = COLOR_TRACK
		track.set_corner_radius_all(22)
		pair[1].set_corner_radius_all(22)
		pair[0].add_theme_stylebox_override("background", track)
		pair[0].add_theme_stylebox_override("fill", pair[1])
	reset()


## Recolours the blender contents from a menu item's "look" block.
func set_look(look: Dictionary) -> void:
	blender.set_look(look)
	_blend_fill.bg_color = Color(look.get("liquid", "#c2185b"))


func start(time_sec: float = prep_time_sec) -> void:
	prep_time_sec = maxf(time_sec, 0.1)
	progress = 0.0
	motor_heat = 0.0
	elapsed = 0.0
	_red_time = 0.0
	holding = false
	state = State.BLENDING
	_run_id += 1
	blender.reset()
	blender.running = true
	set_process(true)
	_refresh()


func reset() -> void:
	state = State.IDLE
	progress = 0.0
	motor_heat = 0.0
	holding = false
	_run_id += 1
	set_process(false)
	blender.reset()
	_refresh()


func _process(delta: float) -> void:
	elapsed += delta
	if state == State.TRIPPED:
		motor_heat = maxf(motor_heat - motor_cool_rate * delta, 0.0)
		if motor_heat <= motor_resume_max:
			state = State.BLENDING
			blender.running = true
		_refresh()
		return
	var rate := 100.0 / prep_time_sec * (boost_multiplier if holding else 1.0)
	progress = minf(progress + rate * delta, 100.0)
	if holding:
		motor_heat = minf(motor_heat + motor_heat_rate * delta, 100.0)
	else:
		motor_heat = maxf(motor_heat - motor_cool_rate * delta, 0.0)
	_red_time = _red_time + delta if motor_heat >= motor_red_min else 0.0
	_refresh()
	if _red_time > overheat_grace_sec:
		_trip()
	elif progress >= 100.0:
		_serve()


func score(time_taken: float) -> float:
	var par := prep_time_sec * par_fraction
	if time_taken <= par:
		return 1.0
	return clampf(remap(time_taken, par, prep_time_sec, 1.0, 0.5), 0.5, 1.0)


func is_blending() -> bool:
	return state == State.BLENDING or state == State.TRIPPED


func _unhandled_input(event: InputEvent) -> void:
	if state == State.BLENDING and event.is_action("ui_accept"):
		get_viewport().set_input_as_handled()
		set_holding(event.is_pressed())


func set_holding(value: bool) -> void:
	holding = value and state == State.BLENDING
	_refresh()


func _serve() -> void:
	var accuracy := score(elapsed)
	_finish()
	status_label.text = tr("PREP_BLEND_DONE")
	var run := _run_id
	await blender.pour()
	if run == _run_id:
		gauge_completed.emit(accuracy)


func _trip() -> void:
	state = State.TRIPPED
	holding = false
	_red_time = 0.0
	blender.running = false
	blender.trip()
	_refresh()
	motor_tripped.emit()


func _finish() -> void:
	state = State.DONE
	holding = false
	set_process(false)
	_refresh()


func _refresh() -> void:
	blend_bar.value = progress
	motor_bar.value = motor_heat
	if motor_heat >= motor_red_min:
		_motor_fill.bg_color = COLOR_MOTOR_RED
	elif motor_heat >= motor_warn_min:
		_motor_fill.bg_color = COLOR_MOTOR_WARM
	else:
		_motor_fill.bg_color = COLOR_MOTOR_OK
	blender.progress = progress
	blender.motor_heat = motor_heat
	blender.holding = holding
	blender.tripped = state == State.TRIPPED
	var blending := state == State.BLENDING
	hold_label.modulate.a = 1.0 if blending and not holding and motor_heat < motor_warn_min else 0.0
	if state == State.TRIPPED:
		status_label.text = tr("PREP_BLEND_OVERHEAT")
	elif blending:
		if motor_heat >= motor_red_min:
			status_label.text = tr("PREP_BLEND_TOO_HOT")
		elif motor_heat >= motor_warn_min:
			status_label.text = tr("PREP_BLEND_WARM")
		elif holding:
			status_label.text = tr("PREP_BLEND_TURBO")
		else:
			status_label.text = tr("PREP_BLEND_HOLD")
	elif state == State.IDLE:
		status_label.text = ""
