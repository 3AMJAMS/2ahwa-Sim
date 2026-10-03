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
##
## While they wait, walkers stand turned to FIFI's trunk and keep busy: every
## few seconds they pick something to do (check a phone or a watch, cross
## their arms, tap a foot as patience runs out, chat with whoever's next to
## them, look at a passing car, the cat on the roof or the shops across the
## road), glance over when someone else is served, wave when their drink is
## ready, and sip it as they walk off.

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
## What they're looking at (world point), for how much longer, and when
## they next change what they're doing.
var _look_at := Vector3.ZERO
var _looking := false
var _glance_left := 0.0
var _act_left := 0.0
var _body_yaw := 0.0


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
				_think(delta)
				person.idle(delta, 1.0 - patience / patience_max)
				_turn_to(_body_yaw, delta * 0.35)
				person.look_yaw = wrapf(_angle_to(_look_at) - _yaw, -PI, PI) if _looking else 0.0
			_bar.queue_redraw()
		State.LEAVING:
			if vehicle == null and _walk(delta):
				queue_free()
	_pin_overlay()


## Picks what to do next while waiting, weighted by how they feel.
func _think(delta: float) -> void:
	_glance_left -= delta
	_act_left -= delta
	if _glance_left > 0.0:
		return
	_body_yaw = _stance()
	if drink_ready:
		# Their drink's in Sayed's hand: eyes on the trunk, a wave now and then.
		_look(_trunk())
		if _act_left <= 0.0:
			person.activity = "wave" if person.activity != "wave" else ""
			_act_left = 1.6 if person.activity == "wave" else 2.5
		return
	if _act_left > 0.0:
		return
	_act_left = _rng.randf_range(2.5, 6.0)
	var u := 1.0 - patience / patience_max
	var mate := _neighbour()
	var car := _nearest_car()
	var options := [
		["", "trunk", 3.0 + (3.0 if being_made else 0.0)],
		["phone", "down", 2.0 if u < 0.75 else 0.3],
		["", "car", 1.5 if car else 0.0],
		["", "cat", 0.5],
		["", "shops", 1.0],
		["", "garden", 1.2],
		["", "sayed", 0.8],
		["chat", "mate", 2.5 if mate else 0.0],
		["arms_crossed", "trunk", 1.0 + 2.0 * u],
		["watch", "down", 3.0 * u],
		["tap_foot", "trunk", 3.0 * u],
		["hips", "trunk", 0.8],
		["scratch", "shops", 0.4],
		["stretch", "", 0.3 * (1.0 - u)],
	]
	var total := 0.0
	for o in options:
		total += float(o[2])
	var roll := _rng.randf() * total
	for o in options:
		roll -= float(o[2])
		if roll <= 0.0:
			person.activity = o[0]
			person.look_pitch = 0.0
			match o[1]:
				"trunk":
					_look(_trunk())
				"down":
					_looking = false
				"car":
					_look(car.global_position + Vector3(0, 0.8, 0))
				"cat":
					_look(host.fifi.global_transform * host.fifi.roof_spot() if host else _trunk())
					person.look_pitch = -0.25
				"shops":
					_look(Vector3(global_position.x + _rng.randf_range(-4.0, 4.0), 2.5, Street3D.FACADE_Z))
				"garden":
					# Over their shoulder at the garden and the people passing.
					_look(global_position + Vector3(_rng.randf_range(-3.0, 3.0), 1.2, 4.0))
				"sayed":
					_look(host.sayed_head() if host and host.has_method("sayed_head") else _trunk())
				"mate":
					_look(mate.global_position + Vector3(0, 1.4, 0))
					# Half turn toward them.
					_body_yaw = lerp_angle(_body_yaw, _angle_to(mate.global_position), 0.6)
				_:
					_looking = false
			return


## Look over at something for a moment (someone else being served).
func glance(at: Vector3, secs := 1.5) -> void:
	if state != State.WAITING or person == null:
		return
	_look(at)
	_glance_left = secs
	person.activity = ""
	_act_left = 0.0


func _look(at: Vector3) -> void:
	_look_at = at
	_looking = true


## How they stand while waiting: turned to the trunk, but opened up toward
## the street camera (three-quarters), so the player sees more than backs.
func _stance() -> float:
	var trunk := _angle_to(_trunk())
	var a := PI * 0.75
	var b := -PI * 0.25
	var side := a if absf(wrapf(trunk - a, -PI, PI)) < absf(wrapf(trunk - b, -PI, PI)) else b
	return lerp_angle(trunk, side, 0.55)


func _angle_to(at: Vector3) -> float:
	var d := at - global_position
	return atan2(d.x, d.z)


func _trunk() -> Vector3:
	return host.trunk_mouth() if host else global_position + Vector3(-1, 1, -1)


## Another walker waiting close by, to chat with.
func _neighbour() -> Customer:
	for c in get_parent().get_children():
		if c != self and c is Customer and c.person and c.state == State.WAITING \
				and c.global_position.distance_to(global_position) < 1.6:
			return c
	return null


func _nearest_car() -> Node3D:
	var traffic: Node = get_parent().get("traffic")
	if traffic == null:
		return null
	var best: Node3D = null
	var best_d := 9.0
	for v in traffic.get_children():
		if v is StreetVehicle:
			var d: float = (v as Node3D).global_position.distance_to(global_position)
			if d < best_d:
				best_d = d
				best = v
	return best


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
	if person:
		person.activity = "sip"
		person.look_yaw = 0.0
	# The others glance over.
	for c in get_parent().get_children():
		if c != self and c is Customer:
			(c as Customer).glance(global_position + Vector3(0, 1.2, 0), _rng.randf_range(1.0, 2.0))
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
	if person:
		person.activity = ""
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
