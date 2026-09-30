extends Node3D
## The street view: FIFI parked at the kerb of a four-lane Cairo road, in
## blocks, seen from above in isometric. Owns the camera, the day/night
## light, the traffic, the customers, Sayed and the cat, and the overlay the
## HUD labels, speech bubbles and patience bars sit on. Emits trunk_tapped
## when the player taps the trunk; customers report their own taps.

signal trunk_tapped
## Five quick taps on the day/clock/money line: the hidden "start over".
signal reset_requested

## Screen pixels per metre (the old 2D street's scale: a tile is 128 px wide).
const PX_PER_M := 150.85
## The ground point at the centre of the screen: the street sits a little
## left of centre so FIFI and the customers behind her all fit on a phone.
const CAM_TARGET := Vector3(0.8, 0.0, -0.8)
## FIFI's spot in the kerb lane, and where Sayed's chair stands.
const FIFI_TILE := Vector2(0.94, 0.94)
const CHAIR_AT := Vector3(1.05, Street3D.KERB_H, 2.55)

var interactive := true
var camera := Camera3D.new()
## The 2D layer over the street: HUD labels, bubbles and patience bars.
var overlay := CanvasLayer.new()
var ui := Control.new()
var hint_label := Label.new()
var wallet_label := Label.new()
var street := Street3D.new()
var fifi := Fifi3D.new()
## Customers walking up to the trunk; main.gd drives the orders.
var queue := CustomerQueue.new()
## FIFI's tail up close, where drinks are made (shown while prepping).
var prep_rig := PrepRig.new()
var prepping := false

var _traffic := Traffic.new()
var _furniture := SidewalkFurniture.new()
var _cat := StreetCat.new()
var _daylight := DayLight3D.new()
var _pulse_t := 0.0
var _wallet_taps := 0
var _wallet_tap_at := 0


func _ready() -> void:
	add_child(_daylight)
	add_child(street)
	fifi.position = Street3D.tile(FIFI_TILE.x, FIFI_TILE.y)
	add_child(fifi)
	# The street's cat, asleep on FIFI's roof, lying along the car.
	_cat.position = fifi.roof_spot()
	_cat.rotation_degrees.y = -70
	fifi.add_child(_cat)
	prep_rig.visible = false
	fifi.add_child(prep_rig)
	_furniture.position = CHAIR_AT
	_furniture.rotation_degrees.y = 40
	add_child(_furniture)
	add_child(_traffic)
	queue.traffic = _traffic
	queue.host = self
	add_child(queue)
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.keep_aspect = Camera3D.KEEP_WIDTH
	camera.rotation_degrees = Vector3(-30, 45, 0)
	camera.near = 1.0
	camera.far = 90.0
	add_child(camera)
	_build_overlay()
	Economy.currency_changed.connect(_pop_wallet.unbind(1))
	Economy.currency_changed.connect(_update_wallet.unbind(1))
	DayClock.minute_changed.connect(_relight)
	get_viewport().size_changed.connect(_recenter)
	visibility_changed.connect(_on_visibility_changed)
	_recenter()
	_relight()
	camera.make_current()


func _build_overlay() -> void:
	overlay.layer = 1
	add_child(overlay)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	overlay.add_child(ui)
	for label in [hint_label, wallet_label]:
		label.set_anchors_preset(Control.PRESET_CENTER)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.add_theme_color_override("font_outline_color", Color(0.05, 0.04, 0.08, 0.9))
		label.add_theme_constant_override("outline_size", 12)
		overlay.add_child(label)
	hint_label.offset_left = -480
	hint_label.offset_right = 480
	hint_label.offset_top = 540
	hint_label.offset_bottom = 680
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_color_override("font_color", Color(1, 0.784, 0.38))
	hint_label.text = tr("UI_TAP_TRUNK")
	wallet_label.offset_left = -480
	wallet_label.offset_right = 480
	wallet_label.offset_top = -820
	wallet_label.offset_bottom = -720
	wallet_label.add_theme_color_override("font_color", Color(0.95, 0.93, 0.88))
	wallet_label.mouse_filter = Control.MOUSE_FILTER_STOP
	wallet_label.gui_input.connect(_on_wallet_input)


func _process(delta: float) -> void:
	_pulse_t += delta
	fifi.trunk_glow = (0.3 + 0.7 * (sin(_pulse_t * 3.0) * 0.5 + 0.5)) if interactive and visible else 0.0


## World point to overlay (logical screen) coordinates.
func screen_point(world: Vector3) -> Vector2:
	return camera.unproject_position(world)


## Screen rect round a world-space box, for taps and the tutorial's spotlight.
func screen_rect_of(box: AABB) -> Rect2:
	var r := Rect2(screen_point(box.position), Vector2.ZERO)
	for i in 8:
		r = r.expand(screen_point(box.get_endpoint(i)))
	return r


## Screen rect round the trunk, for the tutorial's spotlight.
func trunk_screen_rect() -> Rect2:
	return screen_rect_of(fifi.global_transform * fifi.trunk_aabb())


## Where drinks leave the trunk (world space).
func trunk_mouth() -> Vector3:
	return fifi.global_transform * fifi.trunk_mouth()


## The line of guidance under FIFI ("tap the trunk", "serve the customer"...).
func set_hint(text: String) -> void:
	hint_label.text = text


func set_interactive(value: bool) -> void:
	interactive = value
	hint_label.visible = value


func _on_visibility_changed() -> void:
	overlay.visible = visible and not prepping
	if visible and not prepping:
		camera.make_current()
		_daylight.apply()


## Behind FIFI to make a drink: the camera moves to the trunk, the detailed
## tail takes over, and the street's overlay and Sayed (he's working) hide.
func enter_prep() -> void:
	prepping = true
	set_interactive(false)
	overlay.visible = false
	_furniture.sayed.visible = false
	fifi.set_prep(true, prep_rig)
	prep_rig.camera.make_current()


func exit_prep() -> void:
	prepping = false
	fifi.set_prep(false, prep_rig)
	_furniture.sayed.visible = true
	overlay.visible = visible
	camera.make_current()
	_daylight.apply()


func _recenter() -> void:
	var vis := get_viewport().get_visible_rect().size
	camera.size = vis.x / PX_PER_M
	camera.position = CAM_TARGET + camera.basis.z * 40.0


func _relight() -> void:
	var dark := DayClock.darkness()
	street.set_time(dark)
	fifi.set_time(dark)
	Vox.set_glow("glow/head", lerpf(0.0, 2.2, dark))
	Vox.set_glow("glow/flame", 2.5)
	_update_wallet()


## Taps on the street: the nearest customer or car under the finger, else
## the trunk.
func _unhandled_input(event: InputEvent) -> void:
	if not interactive or not visible:
		return
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var from := camera.project_ray_origin(event.position)
	var dir := camera.project_ray_normal(event.position)
	var best: Customer = null
	var best_d := INF
	for c in queue.customers():
		var hit: Variant = c.world_aabb().grow(0.12).intersects_ray(from, dir)
		if hit != null:
			var d := from.distance_to(hit)
			if d < best_d:
				best_d = d
				best = c
	var trunk: Variant = (fifi.global_transform * fifi.trunk_aabb()).grow(0.15).intersects_ray(from, dir)
	if best and (trunk == null or best_d <= from.distance_to(trunk) + 0.6):
		get_viewport().set_input_as_handled()
		best.tapped.emit()
	elif trunk != null:
		get_viewport().set_input_as_handled()
		trunk_tapped.emit()


## A quick bounce on the wallet whenever the money changes.
func _pop_wallet() -> void:
	wallet_label.pivot_offset = wallet_label.size * 0.5
	var t := create_tween()
	t.tween_property(wallet_label, "scale", Vector2(1.18, 1.18), 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	t.tween_property(wallet_label, "scale", Vector2.ONE, 0.25)


func _update_wallet() -> void:
	wallet_label.text = "%s   ·   %s   ·   %s" % [
		tr("UI_DAY").format({"day": GameData.ar_digits(Economy.day_number)}),
		DayClock.clock_text(),
		tr("UI_WALLET").format({"amount": GameData.ar_digits(Economy.currency_egp)}),
	]


func _on_wallet_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var now := Time.get_ticks_msec()
	_wallet_taps = _wallet_taps + 1 if now - _wallet_tap_at < 600 else 1
	_wallet_tap_at = now
	if _wallet_taps >= 5:
		_wallet_taps = 0
		reset_requested.emit()
