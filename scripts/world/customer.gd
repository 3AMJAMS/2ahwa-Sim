class_name Customer
extends Node3D
## One customer, on foot or at the wheel.
##  - On foot: walks up the pavement to a spot by FIFI's trunk (legs and arms
##    swinging), shouts the order, waits, then walks off.
##  - By car: a passing car pulls up behind or beside FIFI, winds the window
##    down and the driver shouts the order; once served they take the drink,
##    wind the window back up (or leave it down) and drive off.
## Either way it follows the blueprint's patience state machine:
##   ARRIVING → ORDER_PLACED (waiting for the drink) → SERVED | LEFT_ANGRY
## Walkers are a random VoxPerson (skin tone, build, outfit, hair, things
## they carry); the speech bubble and patience bar ride on the street's
## overlay, pinned over the head or the car roof.

signal ordered
signal tapped
signal left(angry: bool)

enum State { ARRIVING, WAITING, LEAVING }

const WALK_SPEED := 2.2
## The kerbside path along the pavement, and where walkers leave the scene.
const PATH_V := 5.6
const EXIT_U := -18.0

var state := State.ARRIVING
var item_id := ""
## Sugar grade ordered ("mazboot", "ziyada", ...; "" for drinks without one).
var sugar := ""
var shout := ""
## Seconds of patience at the start, and what's left.
var patience_max := 90.0
var patience := 90.0
## Set during the tutorial: patience doesn't run down.
var patient := false
## Where a walker stands to order (tile coords); set by CustomerQueue.
var slot := Vector2.ZERO
## The car they came in (null for walkers).
var vehicle: StreetVehicle
## The drink is on the stove for them / ready in Sayed's hands.
var being_made := false
var drink_ready := false
## The street (camera and overlay); set by CustomerQueue.
var host: Node3D
var person: VoxPerson

var _rng := RandomNumberGenerator.new()
var _pos := Vector2.ZERO
var _path: Array[Vector2] = []
var _t := 0.0
var _bar := Control.new()
var _bubble := PanelContainer.new()
var _bubble_label := Label.new()
var _yaw := 0.0


## A walker heading for `stand_at`, entering the pavement at `from_u`.
func setup(order_id: String, shout_text: String, patience_sec: float, stand_at: Vector2, from_u: float) -> void:
	item_id = order_id
	shout = shout_text
	patience_max = patience_sec
	patience = patience_sec
	slot = stand_at
	_pos = Vector2(from_u, PATH_V)
	_path = [Vector2(slot.x, PATH_V), slot]


## A driver: the car is already on its way; arrive() is called once it stops.
func setup_car(order_id: String, shout_text: String, patience_sec: float, car: StreetVehicle) -> void:
	item_id = order_id
	shout = shout_text
	patience_max = patience_sec
	patience = patience_sec
	vehicle = car


func _ready() -> void:
	_rng.randomize()
	var layer: Control = host.ui if host else null
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.draw.connect(_draw_bar)
	_bar.visible = false
	_build_bubble()
	if layer:
		layer.add_child(_bar)
		layer.add_child(_bubble)
	tree_exiting.connect(func() -> void:
		_bar.queue_free()
		_bubble.queue_free())
	if vehicle:
		_follow_car()
	else:
		person = VoxPerson.new()
		add_child(person)
		person.build(VoxPerson.random_look(_rng))
		_place()


func _build_bubble() -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = Color("f6ecd6")
	style.border_color = Color("7a5a2e")
	style.set_border_width_all(3)
	style.set_corner_radius_all(18)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	_bubble.add_theme_stylebox_override("panel", style)
	_bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bubble_label.add_theme_font_size_override("font_size", 26)
	_bubble_label.add_theme_color_override("font_color", Color("3a2412"))
	_bubble_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bubble.add_child(_bubble_label)
	_bubble.visible = false


func _process(delta: float) -> void:
	_t += delta
	if vehicle:
		if not is_instance_valid(vehicle):
			queue_free()
			return
		_follow_car()
	match state:
		State.ARRIVING:
			if vehicle == null and _walk(delta):
				arrive()
		State.WAITING:
			if not patient and not drink_ready:
				patience = maxf(patience - delta, 0.0)
				if patience <= 0.0:
					leave(true)
			if person:
				# Shift from foot to foot; more impatient, more fidgety.
				person.idle(delta, 1.0 - patience / patience_max)
				_turn_to(deg_to_rad(15.0), delta)
			_bar.queue_redraw()
		State.LEAVING:
			if vehicle == null and _walk(delta):
				queue_free()
	_pin_overlay()


## Keeps the bubble and the bar over the head (or the car roof).
func _pin_overlay() -> void:
	if host == null:
		return
	var p: Vector2 = host.screen_point(head_point())
	_bar.position = p + Vector2(0, -8)
	if _bubble.visible:
		_bubble.reset_size()
		_bubble.position = p + Vector2(-_bubble.size.x * 0.5, -_bubble.size.y - 34)


## Walks along the path, legs and arms swinging; true when it's used up.
func _walk(delta: float) -> bool:
	if _path.is_empty():
		return true
	var target: Vector2 = _path[0]
	var step := WALK_SPEED * delta
	var to := target - _pos
	if to.length() <= step:
		_pos = target
		_path.remove_at(0)
	else:
		_pos += to.normalized() * step
		_turn_to(atan2(to.x, to.y), delta * 2.0)
	if person:
		person.walk(delta)
	_place()
	return _path.is_empty()


func _turn_to(yaw: float, delta: float) -> void:
	_yaw = lerp_angle(_yaw, yaw, minf(1.0, delta * 8.0))
	if person:
		person.rotation.y = _yaw


## Standing (or parked) at the truck: shout the order.
func arrive() -> void:
	state = State.WAITING
	_bar.visible = true
	_show_bubble(shout, 4.0)
	ordered.emit()


func _show_bubble(text: String, hold: float) -> void:
	_bubble_label.text = text
	_bubble.visible = true
	_bubble.modulate.a = 0.0
	_pin_overlay()
	var t := create_tween()
	t.tween_property(_bubble, "modulate:a", 1.0, 0.2)
	t.tween_interval(hold)
	t.tween_property(_bubble, "modulate:a", 0.0, 0.3)
	t.tween_callback(func() -> void: _bubble.visible = false)


## Served: a quick "thank you", then off down the pavement or the road.
func serve() -> void:
	drink_ready = false
	_bar.visible = false
	_show_bubble(tr("CUST_THANKS_%d" % (_rng.randi() % 3 + 1)), 1.4)
	_set_mood(1.0)
	if vehicle:
		state = State.LEAVING
		vehicle.drive_off(_rng.randf() < 0.5, 1.2)
	else:
		_leave_path()
	left.emit(false)


func leave(angry: bool) -> void:
	if state == State.LEAVING:
		return
	_bar.visible = false
	if angry:
		_set_mood(-1.0)
		_show_bubble(tr("CUST_ANGRY_%d" % (_rng.randi() % 2 + 1)), 1.4)
	if vehicle:
		state = State.LEAVING
		# Angry drivers wind the window straight back up; the rest may not.
		vehicle.drive_off(not angry and _rng.randf() < 0.5, 0.8)
	else:
		_leave_path()
	left.emit(angry)


func _set_mood(mood: float) -> void:
	var who: VoxPerson = person if person else (vehicle.driver if vehicle else null)
	if who:
		who.set_mood(mood)


func _leave_path() -> void:
	state = State.LEAVING
	_path = [Vector2(_pos.x, PATH_V), Vector2(EXIT_U, PATH_V)]


func is_waiting() -> bool:
	return state == State.WAITING


## Where the drink is handed over (world space): the hand, or the car window.
func handoff_point() -> Vector3:
	if vehicle:
		return vehicle.window_centre()
	var fwd := Vector3(sin(_yaw), 0, cos(_yaw))
	return global_position + Vector3(0, 0.95, 0) + fwd * 0.25


## Over the head, or over the car's roof (world space).
func head_point() -> Vector3:
	if vehicle:
		return vehicle.roof_top()
	if person:
		return global_position + person.head_top() + Vector3(0, 0.12, 0)
	return global_position + Vector3(0, 1.9, 0)


## The figure or the car (world space), for taps.
func world_aabb() -> AABB:
	if vehicle:
		return vehicle.world_aabb()
	var h := person.head_top().y if person else 1.8
	return AABB(global_position + Vector3(-0.3, 0, -0.3), Vector3(0.6, h, 0.6))


## Screen rect round the figure or the car, for the tutorial's spotlight.
func screen_rect() -> Rect2:
	if host == null:
		return Rect2()
	return host.screen_rect_of(world_aabb())


func _place() -> void:
	position = Street3D.tile(_pos.x, _pos.y, Street3D.KERB_H)


func _follow_car() -> void:
	position = vehicle.position


## Patience over the head (or the car): green → amber → red; a pot icon
## while the drink is on the stove and a tick once it's ready.
func _draw_bar() -> void:
	var f := patience / patience_max
	var w := 70.0
	_bar.draw_rect(Rect2(-w * 0.5 - 3, -8, w + 6, 16), Color(0.05, 0.04, 0.07, 0.8))
	var col := Color("4caf50").lerp(Color("e6c33a"), smoothstep(0.6, 0.35, f)).lerp(Color("e0452b"), smoothstep(0.3, 0.1, f))
	_bar.draw_rect(Rect2(-w * 0.5, -5, w * f, 10), col)
	if drink_ready:
		_bar.draw_circle(Vector2(w * 0.5 + 18, 0), 13, Color("4caf50"))
		_bar.draw_polyline(PackedVector2Array([Vector2(w * 0.5 + 12, 0), Vector2(w * 0.5 + 16, 5), Vector2(w * 0.5 + 24, -5)]),
			Color.WHITE, 3.0, true)
	elif being_made:
		_bar.draw_circle(Vector2(w * 0.5 + 18, 0), 13, Color("e0a458"))
		_bar.draw_rect(Rect2(w * 0.5 + 11, -3, 14, 9), Color("5a3620"))
