extends Node
## Entry point. Owns the WORLD ↔ PREP state machine and the fade between them:
## trunk_tapped → fade out → prep station → prep_complete → fade out → street.

enum State { WORLD, TO_PREP, PREP, TO_WORLD }

## The first order of a session is always شاي كشري; after that orders are
## picked at random from what's unlocked. Phase 2 replaces this with the ticket rail.
@export var first_order_id := "tea_koshari"

var state := State.WORLD
var _last_order := ""
var _rng := RandomNumberGenerator.new()

@onready var world_host: Node2D = $WorldHost
@onready var prep_layer: Control = $PrepLayer
@onready var prep_station: Control = $PrepLayer/PrepStation
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var fade_label: Label = $FadeLayer/FadeRect/FadeLabel
@onready var anim: AnimationPlayer = $AnimationPlayer


func _ready() -> void:
	world_host.trunk_tapped.connect(transition_to_prep)
	prep_station.prep_complete.connect(_on_prep_complete)
	prep_layer.visible = false
	fade_rect.modulate.a = 0.0
	fade_label.visible = false


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
	fade_label.visible = true
	await _fade("fade_out")
	prep_layer.visible = false
	world_host.visible = true
	await _fade("fade_in")
	fade_label.visible = false
	world_host.set_interactive(true)
	state = State.WORLD


func _on_prep_complete(_result: Dictionary) -> void:
	transition_to_world()


func _fade(anim_name: String) -> void:
	anim.play(anim_name)
	await anim.animation_finished
