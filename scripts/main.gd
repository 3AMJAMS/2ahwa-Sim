extends Node
## Entry point. Owns the WORLD ↔ PREP state machine and the fade between them:
## trunk_tapped → fade out → prep station → prep_complete → fade out → street.
## The day never ends on its own: "go home" fades out on the day's takings,
## advances the day, and starts the clock again in the afternoon.

enum State { WORLD, TO_PREP, PREP, TO_WORLD, GOING_HOME }

## How long the end-of-day summary stays up.
@export var day_summary_sec := 2.2

## The first order of a session is always شاي كشري; after that orders are
## picked at random from what's unlocked. Phase 2 replaces this with the ticket rail.
@export var first_order_id := "tea_koshari"

var state := State.WORLD
var _last_order := ""
var _rng := RandomNumberGenerator.new()
var _day_start_money := 0

@onready var world_host: Node2D = $WorldHost
@onready var prep_layer: Control = $PrepLayer
@onready var prep_station: Control = $PrepLayer/PrepStation
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var fade_label: Label = $FadeLayer/FadeRect/FadeLabel
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var go_home_button: Button = $Hud/GoHomeButton
@onready var vignette: ColorRect = $VignetteLayer/Vignette


func _ready() -> void:
	world_host.trunk_tapped.connect(transition_to_prep)
	prep_station.prep_complete.connect(_on_prep_complete)
	go_home_button.pressed.connect(go_home)
	DayClock.minute_changed.connect(_relight)
	_day_start_money = Economy.currency_egp
	prep_layer.visible = false
	fade_rect.modulate.a = 0.0
	fade_label.visible = false
	_intro.call_deferred()


## First launch: Sayed shows round the street, ending on the trunk tap.
func _intro() -> void:
	if not Tutorial.pending("ui_intro"):
		return
	await Tutorial.play([
		{"text": tr("TUT_WELCOME")},
		{"text": tr("TUT_HUD"), "target": world_host.wallet_label.get_global_rect},
		{"text": tr("TUT_GO_HOME"), "target": go_home_button.get_global_rect},
		{"text": tr("TUT_TAP_TRUNK"), "target": world_host.trunk_screen_rect, "until": world_host.trunk_tapped},
	])
	Tutorial.mark("ui_intro")


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard shortcut for desktop testing: Space/Enter opens the trunk.
	if state == State.WORLD and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		transition_to_prep()


func transition_to_prep() -> void:
	if state != State.WORLD:
		return
	state = State.TO_PREP
	world_host.set_interactive(false)
	go_home_button.visible = false
	await _fade("fade_out")
	world_host.visible = false
	prep_layer.visible = true
	_last_order = first_order_id if _last_order.is_empty() else GameData.pick_order(_rng, _last_order)
	prep_station.load_order(_last_order)
	await _fade("fade_in")
	state = State.PREP
	prep_station.start_order()


func transition_to_world() -> void:
	if state != State.PREP:
		return
	state = State.TO_WORLD
	fade_label.text = tr("UI_RETURNING")
	fade_label.visible = true
	await _fade("fade_out")
	prep_layer.visible = false
	world_host.visible = true
	await _fade("fade_in")
	fade_label.visible = false
	world_host.set_interactive(true)
	go_home_button.visible = true
	state = State.WORLD


func go_home() -> void:
	if state != State.WORLD:
		return
	state = State.GOING_HOME
	world_host.set_interactive(false)
	go_home_button.visible = false
	fade_label.text = tr("UI_DAY_OVER").format({
		"day": GameData.ar_digits(Economy.day_number),
		"amount": GameData.ar_digits(Economy.currency_egp - _day_start_money)})
	fade_label.visible = true
	await _fade("fade_out")
	await get_tree().create_timer(day_summary_sec).timeout
	Economy.end_day()
	DayClock.start_day()
	_day_start_money = Economy.currency_egp
	fade_label.visible = false
	await _fade("fade_in")
	world_host.set_interactive(true)
	go_home_button.visible = true
	state = State.WORLD


## The vignette closes in after dusk.
func _relight() -> void:
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.22 + 0.28 * DayClock.darkness())


func _on_prep_complete(_result: Dictionary) -> void:
	transition_to_world()


func _fade(anim_name: String) -> void:
	anim.play(anim_name)
	await anim.animation_finished
