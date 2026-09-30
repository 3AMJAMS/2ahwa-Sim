extends Node
## Entry point. Runs the shift loop and the fades between the two views:
##   a customer walks up and shouts an order → it's clipped to the ticket rail
##   → tap the trunk (or the ticket) → fade to the prep station → make it
##   → fade back holding the drink → tap the customer to serve → tips.
## Customers who wait too long leave angry and the ticket is torn off.
## The day never ends on its own: "go home" fades out on the day's takings,
## sends everyone home, advances the day, and starts the clock again.

enum State { WORLD, TO_PREP, PREP, TO_WORLD, GOING_HOME }

## How long the end-of-day summary stays up.
@export var day_summary_sec := 2.2
## Tip multiplier from how much patience was left when served: from `x` for a
## customer who was about to walk off to `y` for one served straight away.
@export var speed_tip := Vector2(0.6, 1.0)

var state := State.WORLD
var _day_start_money := 0
## The customer whose drink is being made, and the drink in Sayed's hands
## ({customer, quality}), if any.
var _making: Customer
var _holding := {}

@onready var world_host: Node2D = $WorldHost
@onready var queue: CustomerQueue = $WorldHost.queue
@onready var prep_layer: Control = $PrepLayer
@onready var prep_station: Control = $PrepLayer/PrepStation
@onready var fade_rect: ColorRect = $FadeLayer/FadeRect
@onready var fade_label: Label = $FadeLayer/FadeRect/FadeLabel
@onready var anim: AnimationPlayer = $AnimationPlayer
@onready var go_home_button: Button = $Hud/GoHomeButton
@onready var vignette: ColorRect = $VignetteLayer/Vignette
var rail := TicketRail.new()


func _ready() -> void:
	world_host.trunk_tapped.connect(_on_trunk_tapped)
	prep_station.prep_complete.connect(_on_prep_complete)
	go_home_button.pressed.connect(go_home)
	DayClock.closing_time.connect(_on_closing_time)
	world_host.reset_requested.connect(_confirm_reset)
	queue.customer_ordered.connect(_on_customer_ordered)
	queue.customer_left.connect(_on_customer_left)
	queue.customer_tapped.connect(_on_customer_tapped)
	DayClock.minute_changed.connect(_relight)
	# Tickets clip along the top, under the day/money line.
	rail.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	rail.offset_top = 262
	rail.offset_bottom = 412
	rail.ticket_pressed.connect(_on_ticket_pressed)
	$Hud.add_child(rail)
	_day_start_money = Economy.currency_egp
	prep_layer.visible = false
	fade_rect.modulate.a = 0.0
	fade_label.visible = false
	_update_hint()
	_intro.call_deferred()


## Hidden "start over" (five taps on the day/money line): wipes the save
## and restarts, so the tutorial plays again. Handy for testers.
func _confirm_reset() -> void:
	if state != State.WORLD:
		return
	var dialog := ConfirmationDialog.new()
	dialog.dialog_text = tr("UI_RESET_CONFIRM")
	dialog.ok_button_text = tr("UI_RESET_YES")
	dialog.cancel_button_text = tr("UI_RESET_NO")
	add_child(dialog)
	dialog.confirmed.connect(func() -> void:
		Economy.reset()
		DayClock.start_day()
		get_tree().reload_current_scene())
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()


## First launch: Sayed shows round the street, waits for the first customer
## and ends on the trunk tap.
func _intro() -> void:
	if not Tutorial.pending("ui_intro"):
		return
	await Tutorial.play([
		{"text": tr("TUT_WELCOME")},
		{"text": tr("TUT_HUD"), "target": world_host.wallet_label.get_global_rect},
		{"text": tr("TUT_GO_HOME"), "target": go_home_button.get_global_rect},
	])
	if not Tutorial.pending("ui_intro"):
		return
	if queue.waiting().is_empty():
		await queue.customer_ordered
	var first: Customer = queue.waiting()[0]
	await Tutorial.play([
		{"text": tr("TUT_CUSTOMER"), "target": first.screen_rect},
		{"text": tr("TUT_TICKET"), "target": rail.ticket_rect.bind(first)},
		{"text": tr("TUT_TAP_TRUNK"), "target": world_host.trunk_screen_rect, "until": world_host.trunk_tapped},
	])
	Tutorial.mark("ui_intro")


func _unhandled_input(event: InputEvent) -> void:
	# Keyboard shortcut for desktop testing: Space/Enter opens the trunk.
	if state == State.WORLD and event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_on_trunk_tapped()


# --- Orders ------------------------------------------------------------------

func _on_customer_ordered(c: Customer) -> void:
	rail.add_order(c)
	_update_hint()


func _on_customer_left(c: Customer, angry: bool) -> void:
	rail.remove_order(c)
	if angry:
		Economy.record_order(false)
		if _holding.get("customer") == c:
			_holding = {}
			_flash_hint(tr("UI_CUSTOMER_GONE"))
	_update_hint()


## The trunk makes the most urgent order (or nudges if there's nothing to do).
func _on_trunk_tapped() -> void:
	if state != State.WORLD:
		return
	if not _holding.is_empty():
		_flash_hint(tr("UI_SERVE_FIRST"))
		return
	var c := queue.most_urgent()
	if c == null:
		_flash_hint(tr("UI_NO_ORDERS"))
		return
	transition_to_prep(c)


func _on_ticket_pressed(c: Customer) -> void:
	if state != State.WORLD:
		return
	if c.drink_ready:
		_on_customer_tapped(c)
	elif _holding.is_empty():
		transition_to_prep(c)
	else:
		_flash_hint(tr("UI_SERVE_FIRST"))


func _on_customer_tapped(c: Customer) -> void:
	if state != State.WORLD or not c.is_waiting():
		return
	if _holding.get("customer") == c:
		_serve(c)
	elif not _holding.is_empty():
		_flash_hint(tr("UI_WRONG_CUSTOMER"))
	else:
		transition_to_prep(c)


## Hand over the drink: tips = price × venue × quality × how quickly it came.
func _serve(c: Customer) -> void:
	var quality: float = _holding.quality
	_holding = {}
	await _hand_over(c)
	if not is_instance_valid(c) or not c.is_waiting():
		_update_hint()
		return
	var price := GameData.price_for(c.item_id, Economy.current_venue_tier)
	var speed := lerpf(speed_tip.x, speed_tip.y, c.patience / c.patience_max)
	var tips := maxi(1, roundi(price * quality * speed))
	Economy.add_tips(tips)
	Economy.record_order(true)
	_tip_pop(c, tips)
	queue.served(c)
	_update_hint()
	if Tutorial.pending("first_tips"):
		await get_tree().create_timer(0.9).timeout
		await Tutorial.play([{"text": tr("TUT_FIRST_TIPS"), "target": world_host.wallet_label.get_global_rect}])
		Tutorial.mark("first_tips")


## The drink travels from FIFI's trunk to the customer's hand or car window.
func _hand_over(c: Customer) -> void:
	var item := GameData.get_menu_item(c.item_id)
	var look: Dictionary = item.get("look", {})
	var drink := Color(look.get("liquid", "#9c3d16"))
	var cup := Node2D.new()
	cup.light_mask = 0
	cup.draw.connect(func() -> void:
		cup.draw_colored_polygon(PackedVector2Array([Vector2(-9, 0), Vector2(9, 0), Vector2(11, -26), Vector2(-11, -26)]),
			Color(0.85, 0.93, 1.0, 0.5))
		cup.draw_colored_polygon(PackedVector2Array([Vector2(-8, -1), Vector2(8, -1), Vector2(9.5, -18), Vector2(-9.5, -18)]), drink)
		cup.draw_line(Vector2(-11, -26), Vector2(11, -26), Color(1, 1, 1, 0.8), 1.5))
	world_host.add_child(cup)
	var from: Vector2 = world_host.fifi.position + world_host.fifi.trunk_mouth()
	var to := c.handoff_point()
	cup.position = from
	var t := create_tween()
	t.tween_method(func(k: float) -> void:
		cup.position = from.lerp(to, k) + Vector2(0, -90.0 * sin(PI * k)), 0.0, 1.0, 0.45) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	t.tween_callback(cup.queue_free)
	await t.finished


## "+12 ج.م" floating up off the customer, and a buzz on a big tip.
func _tip_pop(c: Customer, tips: int) -> void:
	var pop := Label.new()
	pop.text = "+%s %s" % [GameData.ar_digits(tips), tr("UI_CURRENCY")]
	pop.add_theme_font_size_override("font_size", 52)
	pop.add_theme_color_override("font_color", StationArt.hdr(Color(1.0, 0.84, 0.4), 1.3))
	pop.add_theme_color_override("font_outline_color", Color(0.1, 0.06, 0.02))
	pop.add_theme_constant_override("outline_size", 12)
	pop.light_mask = 0
	world_host.add_child(pop)
	pop.position = c.position + Vector2(-90, -300)
	var t := pop.create_tween()
	t.tween_property(pop, "position:y", pop.position.y - 150.0, 1.2).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	t.parallel().tween_property(pop, "modulate:a", 0.0, 0.5).set_delay(0.7)
	t.tween_callback(pop.queue_free)
	if tips >= 10:
		Input.vibrate_handheld(30)


func _update_hint() -> void:
	if not _holding.is_empty():
		world_host.set_hint(tr("UI_TAP_CUSTOMER"))
	elif queue.most_urgent() != null:
		world_host.set_hint(tr("UI_TAP_TRUNK"))
	else:
		world_host.set_hint(tr("UI_WAITING_CUSTOMERS"))


func _flash_hint(text: String) -> void:
	world_host.set_hint(text)
	var label: Label = world_host.hint_label
	label.pivot_offset = label.size * 0.5
	var t := create_tween()
	t.tween_property(label, "scale", Vector2(1.1, 1.1), 0.1)
	t.tween_property(label, "scale", Vector2.ONE, 0.2)
	t.tween_interval(1.6)
	t.tween_callback(_update_hint)


# --- The two views -----------------------------------------------------------

func transition_to_prep(c: Customer) -> void:
	if state != State.WORLD or c == null:
		return
	state = State.TO_PREP
	_making = c
	c.being_made = true
	world_host.set_interactive(false)
	go_home_button.visible = false
	rail.visible = false
	await _fade("fade_out")
	world_host.visible = false
	prep_layer.visible = true
	prep_station.load_order(c.item_id, c.sugar)
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
	rail.visible = true
	await _fade("fade_in")
	fade_label.visible = false
	world_host.set_interactive(true)
	go_home_button.visible = true
	state = State.WORLD
	_update_hint()
	# First drink in hand: show how to hand it over.
	if not _holding.is_empty() and Tutorial.pending("first_serve"):
		var c: Customer = _holding.customer
		await Tutorial.play([{"text": tr("TUT_SERVE"), "target": c.screen_rect, "until": queue.customer_served}])
		Tutorial.mark("first_serve")


func _on_prep_complete(result: Dictionary) -> void:
	var c := _making
	_making = null
	if is_instance_valid(c):
		c.being_made = false
		if result.get("success", false) and c.is_waiting():
			c.drink_ready = true
			_holding = {"customer": c, "quality": float(result.get("quality", 0.5))}
		elif result.get("success", false):
			_flash_hint.call_deferred(tr("UI_CUSTOMER_GONE"))
	transition_to_world()


## 4 am: the shift's over. If an order is being made, finish handing it
## over first, then close.
func _on_closing_time() -> void:
	while state != State.WORLD and state != State.GOING_HOME:
		await get_tree().create_timer(0.5).timeout
	if state == State.WORLD:
		go_home()


func go_home() -> void:
	if state != State.WORLD:
		return
	state = State.GOING_HOME
	world_host.set_interactive(false)
	go_home_button.visible = false
	rail.visible = false
	fade_label.text = tr("UI_DAY_OVER").format({
		"day": GameData.ar_digits(Economy.day_number),
		"amount": GameData.ar_digits(Economy.currency_egp - _day_start_money),
		"served": GameData.ar_digits(Economy.served_today),
		"failed": GameData.ar_digits(Economy.failed_today)})
	fade_label.visible = true
	await _fade("fade_out")
	_holding = {}
	rail.clear()
	queue.clear()
	await get_tree().create_timer(day_summary_sec).timeout
	Economy.end_day()
	DayClock.start_day()
	_day_start_money = Economy.currency_egp
	fade_label.visible = false
	await _fade("fade_in")
	world_host.set_interactive(true)
	go_home_button.visible = true
	rail.visible = true
	state = State.WORLD
	_update_hint()


## The vignette closes in after dusk.
func _relight() -> void:
	(vignette.material as ShaderMaterial).set_shader_parameter("strength", 0.22 + 0.28 * DayClock.darkness())


func _fade(anim_name: String) -> void:
	anim.play(anim_name)
	await anim.animation_finished
