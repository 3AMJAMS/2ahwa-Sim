class_name CustomerQueue
extends Node2D
## Brings customers to FIFI, parked in the slow lane (البطيء) by the kerb.
## Most come by car, as they do at Cairo's coffee cars: a car pulls up behind
## FIFI or stops beside her in the next lane, winds the window down and
## orders. The rest walk up the pavement to a spot by the trunk. Y-sorted so
## nearer figures overlap farther ones; each customer's bubble and patience
## bar live here too (drawn over FIFI), following their car.
## While Sayed's first-serve tutorial is pending, a single patient customer
## pulls up behind FIFI and orders شاي كشري.

signal customer_ordered(customer: Customer)
signal customer_left(customer: Customer, angry: bool)
signal customer_tapped(customer: Customer)
## A drink was handed over (the tutorial waits on this).
signal customer_served

## Where walkers stand to order, along the pavement by the trunk (tiles).
const SLOTS := [Vector2(5.2, 4.7), Vector2(6.5, 4.7), Vector2(7.8, 4.7)]
## They walk in along the pavement from this far up the street.
const ENTRY_U := 17.0
## FIFI's lane (the slow lane) and where her rear bumper is along it.
const FIFI_LANE := 0.94
const FIFI_REAR_U := 4.15
## Car spots: pulled in behind FIFI in her lane, or stopped beside her
## trunk in the near traffic lane.
const CAR_BEHIND := 0
const CAR_BESIDE := 1
const TUTORIAL_ORDER := "tea_koshari"
const TUTORIAL_SUGAR := "mazboot"
const CAR_KINDS := [StreetVehicle.Kind.SEDAN, StreetVehicle.Kind.SEDAN, StreetVehicle.Kind.TAXI,
	StreetVehicle.Kind.PICKUP, StreetVehicle.Kind.SEDAN, StreetVehicle.Kind.MICROBUS]

## Seconds between arrivals, each customer's patience (Phase 3 swaps in
## per-archetype patience), and the share who come by car.
@export var arrival_gap := Vector2(9.0, 18.0)
@export var patience_range := Vector2(80.0, 110.0)
@export_range(0.0, 1.0) var by_car_share := 0.65

var open := true
## The street's traffic, which drives the customer cars (set by WorldHost).
var traffic: Traffic

var _rng := RandomNumberGenerator.new()
var _wait := 1.5
var _last_order := ""
var _car_spots := [null, null]   # Customer (or null) per car spot


func _ready() -> void:
	y_sort_enabled = true
	_rng.randomize()


func _process(delta: float) -> void:
	if not open:
		return
	_wait -= delta
	if _wait > 0.0:
		return
	_wait = _rng.randf_range(arrival_gap.x, arrival_gap.y)
	var tutorial := Tutorial.pending("first_serve")
	if tutorial and not customers().is_empty():
		return
	var order := TUTORIAL_ORDER if tutorial else GameData.pick_order(_rng, _last_order)
	if order.is_empty():
		return
	var car_spot := _free_car_spot()
	var slot := _free_slot()
	var by_car := car_spot != -1 and (tutorial or _rng.randf() < by_car_share or slot == -1)
	if tutorial:
		car_spot = CAR_BEHIND if _car_spots[CAR_BEHIND] == null else car_spot
	if by_car and car_spot != -1:
		if _spawn_car(order, car_spot, tutorial):
			_last_order = order
		else:
			_wait = 1.5
	elif slot != -1:
		_spawn_walker(order, slot, tutorial)
		_last_order = order


## The order in the customer's words, with their sugar grade worked in.
func _shout_for(order: String, sugar: String) -> String:
	var item := GameData.get_menu_item(order)
	var shouts: Array = item.get("shout_keys", [])
	var text: String = tr(shouts[_rng.randi() % shouts.size()]) if not shouts.is_empty() else tr(item.get("name_key", order))
	if sugar.is_empty():
		return text.replace(" {sugar}", "")
	if not "{sugar}" in text:
		return "%s %s" % [text, GameData.sugar_name(sugar)]
	return text.format({"sugar": GameData.sugar_name(sugar)})


func _sugar_for(order: String, tutorial: bool) -> String:
	if tutorial:
		return TUTORIAL_SUGAR
	return GameData.pick_sugar(order, _rng)


func _patience() -> float:
	return _rng.randf_range(patience_range.x, patience_range.y)


func _spawn_walker(order: String, slot: int, tutorial: bool) -> void:
	var c := Customer.new()
	var sugar := _sugar_for(order, tutorial)
	c.setup(order, _shout_for(order, sugar), _patience(), SLOTS[slot], ENTRY_U + slot * 1.3)
	c.sugar = sugar
	c.patient = tutorial
	c.set_meta("slot", slot)
	_register(c)
	c.left.connect(func(_angry: bool) -> void: c.set_meta("slot", -1))


func _spawn_car(order: String, spot: int, tutorial: bool) -> bool:
	if traffic == null:
		return false
	var kind: StreetVehicle.Kind = CAR_KINDS[_rng.randi() % CAR_KINDS.size()]
	if tutorial:
		kind = StreetVehicle.Kind.SEDAN
	var probe := StreetVehicle.new()
	probe.kind = kind
	var half := probe.length_tiles() * 0.5
	probe.free()
	var at_u := FIFI_REAR_U + 0.7 + half if spot == CAR_BEHIND else FIFI_REAR_U + 1.0
	var lane := FIFI_LANE if spot == CAR_BEHIND else Traffic.LANES[0][0]
	var car := traffic.spawn_customer_car(kind, at_u, lane)
	if car == null:
		return false
	var c := Customer.new()
	var sugar := _sugar_for(order, tutorial)
	c.setup_car(order, _shout_for(order, sugar), _patience(), car)
	c.sugar = sugar
	c.patient = tutorial
	_car_spots[spot] = c
	_register(c)
	car.parked.connect(func() -> void:
		await car.roll_window(1.0, 0.9)
		if is_instance_valid(c) and c.state == Customer.State.ARRIVING:
			c.arrive())
	# The spot frees up once the car has pulled away.
	c.left.connect(func(_angry: bool) -> void:
		await get_tree().create_timer(4.0).timeout
		if _car_spots[spot] == c:
			_car_spots[spot] = null)
	return true


func _register(c: Customer) -> void:
	add_child(c)
	c.ordered.connect(func() -> void: customer_ordered.emit(c))
	c.tapped.connect(func() -> void: customer_tapped.emit(c))
	c.left.connect(func(angry: bool) -> void: customer_left.emit(c, angry))


## Everyone here who isn't on their way out.
func customers() -> Array[Customer]:
	var out: Array[Customer] = []
	for c in get_children():
		if c is Customer and c.state != Customer.State.LEAVING:
			out.append(c)
	return out


## Customers who have ordered and are still waiting for their drink.
func waiting() -> Array[Customer]:
	var out: Array[Customer] = []
	for c in customers():
		if c.is_waiting():
			out.append(c)
	return out


## The order to make next: whoever has the least patience left.
func most_urgent() -> Customer:
	var best: Customer = null
	for c in waiting():
		if c.drink_ready:
			continue
		if best == null or c.patience < best.patience:
			best = c
	return best


## Day's over: everyone still here goes (no penalty).
func clear() -> void:
	for c in customers():
		c.leave(false)
	_wait = 2.0


func served(c: Customer) -> void:
	c.serve()
	customer_served.emit()


func _free_slot() -> int:
	var taken := {}
	for c in get_children():
		if c is Customer and c.vehicle == null:
			taken[int(c.get_meta("slot", -1))] = true
	for i in SLOTS.size():
		if not taken.has(i):
			return i
	return -1


func _free_car_spot() -> int:
	var free: Array[int] = []
	for i in _car_spots.size():
		if _car_spots[i] == null or not is_instance_valid(_car_spots[i]):
			_car_spots[i] = null
			free.append(i)
	if free.is_empty():
		return -1
	return free[_rng.randi() % free.size()]
